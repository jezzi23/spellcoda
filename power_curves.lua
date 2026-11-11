local _, sc = ...;

local is_secret                                     = sc.utils.is_secret;
local calc_spell_eval                               = sc.calc.calc_spell_eval;
local spell_cost_actual                             = sc.calc.spell_cost_actual;
local spell_changing_reads                          = sc.calc.spell_changing_reads;
local powers                                        = sc.powers;
local config                                        = sc.config;
--------------------------------------------------------------------------------
-- Reclaiming some of the lost dynamic functionality on modern clients for calculations
-- that can be expressed as a secret linear curve with respect to current mana/energy/rage resource powers
-- The secret result only ever goes on to a font string and must not be meddled with.
local power_curves = {};

local secret = {};
local secret_time = -1;

-- one power read per power type and frame
local function power_secret(pwr)
    local t = GetTime();
    if secret_time ~= t then
        for k in pairs(secret) do
            secret[k] = nil;
        end
        secret_time = t;
    end
    local s = secret[pwr];
    if s == nil then
        s = is_secret(UnitPower("player", pwr));
        secret[pwr] = s;
    end
    return s;
end

local function copy_into(dst, src)
    for k in pairs(dst) do
        dst[k] = nil;
    end
    for k, v in pairs(src) do
        dst[k] = v;
    end
end

local function new_context()
    return {
        active = false,
        pwr = 0,
        -- power fraction of the low end point, for spells whose evaluation reads their power
        x0 = nil,
        steps = 1,
        -- the evaluation at the cost
        low_info = {},
        low_stats = {},
        low_oh_info = {},
        low_oh_stats = {},
        -- until oom values at no power relative to max power
        oom_frac = nil,
    };
end

-- how the values of the spell about to be evaluated follow its power, before its evaluation at max power
local function begin(ctx, spell, spell_id, loadout, effects, eval_flags, evaluated)
    ctx.active, ctx.x0, ctx.oom_frac = false, nil, nil;
    local pwr = spell.power_type;
    -- the loadout fell back to max power, the curve's x is the real power over max
    if not pwr or config.settings.loadout_always_max_resource or not power_secret(pwr) or
        loadout.resources[pwr] ~= loadout.resources_max[pwr] then
        return;
    end
    ctx.pwr = pwr;
    if evaluated and bit.band(spell_changing_reads(spell, effects), bit.lshift(1, pwr)) ~= 0 then
        -- linear in the power above the cost, held at the cost below it
        local pmax = loadout.resources[pwr];
        local cost = spell_cost_actual(spell, loadout, effects);
        if cost < 0 or cost >= pmax then
            return;
        end
        loadout.resources[pwr] = cost;
        local info, stats = calc_spell_eval(spell, loadout, effects, eval_flags, spell_id);
        loadout.resources[pwr] = pmax;
        copy_into(ctx.low_info, info);
        copy_into(ctx.low_stats, stats);
        -- the off hand buffers are reused by the next evaluation
        if info.oh_info then
            copy_into(ctx.low_oh_info, info.oh_info);
            copy_into(ctx.low_oh_stats, info.oh_stats);
            ctx.low_info.oh_info, ctx.low_info.oh_stats = ctx.low_oh_info, ctx.low_oh_stats;
        end
        ctx.x0 = cost / pmax;
        ctx.steps = math.max(1, math.min(100, math.floor(pmax - cost)));
        ctx.active = true;
    elseif pwr == powers.mana then
        -- until oom values are proportional to the mana including the extra mana from effects
        local total = effects.raw.mana + loadout.resources[pwr];
        if total > 0 then
            ctx.oom_frac = effects.raw.mana / total;
            ctx.active = true;
        end
    end
end

-- format_number's format at the largest end point, its scale goes into the curve
local function number_format(v, digits)
    if v < 100.0 and digits >= 2 then
        return "%.2f", 1;
    elseif v < 1000.0 and digits >= 1 then
        return "%.1f", 1;
    elseif v < 10000.0 then
        return "%.0f", 1;
    elseif v < 1000000.0 then
        return "%.1fk", 0.001;
    elseif v < 10000000000.0 then
        return "%.1fm", 0.000001;
    end
end

local function new_slot()
    local curve = C_CurveUtil.CreateCurve();
    curve:SetType(Enum.LuaCurveType.Linear);
    return { curve = curve, k = {} };
end

-- true when the curve already holds these points, remembers them otherwise
local function same_points(slot, a, b, c, d, e, f)
    local k = slot.k;
    if k[1] == a and k[2] == b and k[3] == c and k[4] == d and k[5] == e and k[6] == f then
        return true;
    end
    k[1], k[2], k[3], k[4], k[5], k[6] = a, b, c, d, e, f;
    return false;
end

-- line from (x0, y0) to (1, y1), the client holds y0 below x0, cut at 0 where it would go below
local function fill_line(slot, x0, y0, y1)
    if same_points(slot, x0, y0, y1) then
        return;
    end
    local curve = slot.curve;
    curve:ClearPoints();
    if y0 < 0 and y1 > 0 then
        x0 = x0 + (1 - x0) * y0 / (y0 - y1);
        y0 = 0;
    end
    curve:AddPoint(x0, y0);
    curve:AddPoint(1, y1);
end

-- num / den of two lines from x0 to 1, one point per power step
local function fill_ratio(slot, x0, steps, n0, n1, d0, d1)
    if same_points(slot, x0, n0, n1, d0, d1, steps) then
        return slot.ratio_ok;
    end
    local curve = slot.curve;
    curve:ClearPoints();
    local n = 0;
    for i = 0, steps do
        local t = i / steps;
        local d = d0 + t * (d1 - d0);
        if d > 0 then
            curve:AddPoint(x0 + t * (1 - x0), (n0 + t * (n1 - n0)) / d);
            n = n + 1;
        end
    end
    slot.ratio_ok = n >= 2;
    return slot.ratio_ok;
end

-- fills the slot for the value spec.value(info, stats) and returns its format, nil when it stays a plain value
-- spec: value(info, stats), optional num / den for ratios, dur, uses_until_oom, fixed format
local function fill(ctx, slot, spec, v, info, stats, digits)
    if not ctx.active or v == nil or v ~= v or v == math.huge then
        return;
    end
    local x0, y0;
    if spec.uses_until_oom then
        if ctx.oom_frac then
            x0, y0 = 0, v * ctx.oom_frac;
        end
    elseif ctx.x0 then
        x0, y0 = ctx.x0, spec.value(ctx.low_info, ctx.low_stats);
    end
    if not y0 or y0 ~= y0 or y0 == math.huge then
        return;
    end
    local fmt, scale;
    if spec.fixed then
        fmt, scale = spec.fixed, 1;
    elseif spec.dur then
        if v < 0 or v > 10000000 then
            return;
        end
        if v > 60 then
            fmt, scale = "%.1fm", 1/60;
        else
            fmt, scale = "%.0fs", 1;
        end
    else
        fmt, scale = number_format(math.max(math.abs(v), math.abs(y0)), digits);
        if not fmt then
            return;
        end
    end
    if spec.num then
        local n0, d0 = spec.num(ctx.low_info, ctx.low_stats), spec.den(ctx.low_info, ctx.low_stats);
        local n1, d1 = spec.num(info, stats), spec.den(info, stats);
        if not (n0 and d0 and n1 and d1 and
            fill_ratio(slot, x0, ctx.steps, n0 * scale, n1 * scale, d0, d1)) then
            return;
        end
    else
        fill_line(slot, x0, y0 * scale, v * scale);
    end
    slot.pwr = ctx.pwr;
    return fmt;
end

-- the secret result, only ever passed straight on to a font string
local function value(slot)
    return UnitPowerPercent("player", slot.pwr, true, slot.curve);
end

-- the format pieces go into a format string, plain text around them must not hold format codes
local function escape(text)
    return (text:gsub("%%", "%%%%"));
end

--------------------------------------------------------------------------------
power_curves.power_secret                           = power_secret;
power_curves.new_context                            = new_context;
power_curves.begin                                  = begin;
power_curves.new_slot                               = new_slot;
power_curves.fill                                   = fill;
power_curves.value                                  = value;
power_curves.escape                                 = escape;

sc.power_curves = power_curves;
