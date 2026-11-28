local _, sc = ...;

local L                                 = sc.L;
local attr                              = sc.attr;
local powers                            = sc.powers;
local schools                           = sc.schools;
local cr_weights                        = sc.scaling.cr_weights;
local spirit_mana_regen                 = sc.scaling.spirit_mana_regen;
local combat_ratings                    = sc.utils.combat_ratings;
local client_matches                    = sc.utils.client_matches;
local client_flags                      = sc.client_flags;
local spell_lname                       = sc.utils.spell_lname;
local config                            = sc.config;

local stat_lines = {};
sc.stat_lines = stat_lines;

local function add_field_line(info, val, txt, diff, perc, mul, raw, extras)
    local red = (diff and "|cFFC32C0B") or "|cFFFFFFFF";
    local green = (diff and "|cFF21B915") or "|cFFFFFFFF";
    local stat_color = "|cFFFFD100";

    if diff and extras then
        stat_color = "|cFFB5B09B";
    end

    local force_add = false;
    local val_str;
    if type(val) == "number" then
        if not raw and
            ((mul and math.abs(val - 1) <= 0.000000001) or (not mul and math.abs(val) <= 0.000000001)) then
            return false;
        end
        local perc_symbol = "";
        local val_disp = val;
        if not raw then
            if mul then
                perc = true;
                val_disp = val_disp - 1;
            end
            if perc then
                val_disp = 100*val_disp;
                perc_symbol = "%";
            end
        end
        local abs_val = math.abs(val_disp);
        if abs_val == math.floor(abs_val) then
            val_str = string.format("%.0f", abs_val)
        else
            val_str = string.format("%.3f", abs_val):gsub("%.?0+$", "");
        end

        val_str = val_str..perc_symbol;
    elseif type(val) == "string" then
        val_str = val;
        force_add = true;
    else
        return false;
    end

    if force_add or (mul and val > 1) or (not mul and val > 0) then
        info.num_in = info.num_in + 1;
        info.str = info.str..string.format("%s+ %s|r %s%s|r\n", green, val_str, stat_color, txt);
        return true;
    elseif (mul and val < 1) or (not mul and val < 0) then
        info.num_out = info.num_out + 1;
        info.str = info.str..string.format("%s-  %s|r %s%s|r\n", red, val_str, stat_color, txt);
        return true;
    end
end

local columns = { "melee", "ranged", "spell", "heal" };
local rows = {
    { "power",      { melee = true, ranged = true, spell = true, heal = true } },
    { "hit",        { melee = true, ranged = true, spell = true } },
    { "crit",       { melee = true, ranged = true, spell = true, heal = true } },
    { "haste",      { melee = true, ranged = true, spell = true, heal = true } },
    { "pen",        { melee = true, ranged = true, spell = true } },
    { "dmg",        { melee = true, ranged = true, spell = true, heal = true } },
    { "threat",     { melee = true, ranged = true, spell = true, heal = true } },
    { "weapon",     { melee = true, ranged = true } },
    { "procs",      { melee = true, ranged = true } },
};
local attribute_keys = { "str", "agi", "sta", "int", "spi" };
local resource_keys = { "health", "mana", "regen" };
local defense_keys = { "armor", "defense", "dodge", "parry", "block", "resilience" };
local ability_keys = { "mod", "hit", "crit", "cost", "cast", "dur", "threat" };

local all_cells = {};
for _, k in ipairs(attribute_keys) do
    all_cells[#all_cells + 1] = "attr."..k;
end
for _, k in ipairs(resource_keys) do
    all_cells[#all_cells + 1] = "res."..k;
end
for _, row in ipairs(rows) do
    for _, col in ipairs(columns) do
        if row[2][col] then
            all_cells[#all_cells + 1] = col.."."..row[1];
        end
    end
end
for _, k in ipairs(defense_keys) do
    all_cells[#all_cells + 1] = "def."..k;
end
for _, k in ipairs(ability_keys) do
    all_cells[#all_cells + 1] = "abil."..k;
end

local class_default_specs = {
    WARRIOR = { attr = "str agi sta",           res = "health",             cols = "melee",             def = "armor defense dodge parry block" },
    ROGUE   = { attr = "str agi sta",           res = "health",             cols = "melee",             def = "dodge" },
    HUNTER  = { attr = "agi sta int",           res = "health mana regen",  cols = "melee ranged",      def = "" },
    MAGE    = { attr = "int spi sta",           res = "health mana regen",  cols = "spell",             def = "" },
    WARLOCK = { attr = "int spi sta",           res = "health mana regen",  cols = "spell",             def = "" },
    PRIEST  = { attr = "int spi sta",           res = "health mana regen",  cols = "spell heal",        def = "" },
    SHAMAN  = { attr = "str agi sta int spi",   res = "health mana regen",  cols = "melee spell heal",  def = "block" },
    PALADIN = { attr = "str agi sta int spi",   res = "health mana regen",  cols = "melee spell heal",  def = "armor defense dodge parry block" },
    DRUID   = { attr = "str agi sta int spi",   res = "health mana regen",  cols = "melee spell heal",  def = "armor defense dodge" },
};

local function class_defaults(class)
    local spec = class_default_specs[class];
    local t = {};
    for _, id in ipairs(all_cells) do
        t[id] = spec == nil and id ~= "def.resilience";
    end
    if spec then
        for k in spec.attr:gmatch("%S+") do
            t["attr."..k] = true;
        end
        for k in spec.res:gmatch("%S+") do
            t["res."..k] = true;
        end
        for col in spec.cols:gmatch("%S+") do
            for _, row in ipairs(rows) do
                if row[2][col] then
                    t[col.."."..row[1]] = true;
                end
            end
        end
        for k in spec.def:gmatch("%S+") do
            t["def."..k] = true;
        end
        for _, k in ipairs(ability_keys) do
            t["abil."..k] = true;
        end
    end
    return t;
end

local settings_id = 0;
local filled = setmetatable({}, { __mode = "k" });

local function shown_cells()
    local store = config.settings.stat_lines;
    local t = store[sc.class];
    if not t then
        t = class_defaults(sc.class);
        store[sc.class] = t;
    end
    if not filled[t] then
        local defaults = class_defaults(sc.class);
        for _, id in ipairs(all_cells) do
            if t[id] == nil then
                t[id] = defaults[id];
            end
        end
        filled[t] = true;
    end
    return t;
end

local function set_cell(id, on)
    shown_cells()[id] = on;
    settings_id = settings_id + 1;
end

local function reset_class_cells()
    config.settings.stat_lines[sc.class] = class_defaults(sc.class);
    settings_id = settings_id + 1;
end

-- the category of a line's first shown cell: a line of several columns sits under one the player shows
local function shown_category(shown, cells)
    for i = 1, #cells do
        if shown[cells[i]] then
            return (cells[i]:match("^[^.]+"));
        end
    end
    return (cells[1]:match("^[^.]+"));
end

local function any_on(shown, cells)
    for i = 1, #cells do
        if shown[cells[i]] then
            return true;
        end
    end
    return false;
end

local function lv(s, key)
    return (s.loadout and s.loadout[key]) or 0;
end

local function from_rating(s, factor, val, cr)
    return factor*val/(s.cr * cr_weights[cr]);
end

local function mana_regen(s)
    local effects = s.effects;
    local loadout = s.loadout;
    local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];
    local intellect = loadout.stats[attr.intellect] + effects.by_attr.stat_flat[attr.intellect];
    local mp2_not_casting = spirit_mana_regen(spirit, intellect);

    local mp5 = effects.raw.mp5_flat
        +
        (effects.raw.mana + loadout.resources_max[powers.mana])  * effects.raw.perc_max_mana_as_mp5
        +
        effects.raw.mp5_from_int_mod * intellect;

    local mp1_casting =
        0.2 * mp5 +
        0.5 * mp2_not_casting * math.max(0, math.min(1.0, effects.raw.regen_while_casting));
    local mp1_not_casting =
        0.2 * mp5 +
        0.5 * mp2_not_casting;
    return mp1_casting, mp1_not_casting;
end

local lines = {};
local lnames;
local cell_names = {};
local categories = { "attr", "res", "melee", "ranged", "spell", "heal", "def", "abil" };
local category_names;

local function init(ratings)
    category_names = {
        attr = L["Attributes"], res = L["Resources"], melee = L["Melee"], ranged = L["Ranged"], spell = L["Spell"], heal = L["Healing"],
        def = L["Defense"], abil = L["Abilities"],
    };
    lnames = {
        schools =
            {L["Physical"], L["Holy"], L["Fire"], L["Nature"], L["Frost"], L["Shadow"], L["Arcane"]},
        spell_pen = client_matches(client_flags.forever) and L["Spell piercing"] or L["Spell penetration"],
        school_spell_pen = client_matches(client_flags.forever) and L["spell piercing"] or L["spell penetration"],
        attributes =
            {L["Strength"], L["Agility"], L["Stamina"], L["Intellect"], L["Spirit"]},
    };
    local school_name = function(suffix)
        return function(i) return lnames.schools[i].." "..suffix; end;
    end;

    local rating_lnames = {
        [combat_ratings.CR_DEFENSE_SKILL                    ]   = { L["Defense skill rating"],              {"def.defense"}, true},
        [combat_ratings.CR_DODGE                            ]   = { L["Dodge rating"],                      {"def.dodge"} },
        [combat_ratings.CR_PARRY                            ]   = { L["Parry rating"],                      {"def.parry"} },
        [combat_ratings.CR_BLOCK                            ]   = { L["Block rating"],                      {"def.block"} },
        [combat_ratings.CR_HASTE_SPELL                      ]   = { L["Spell haste rating"],                {"spell.haste", "heal.haste"} },
        [combat_ratings.CR_HASTE_MELEE                      ]   = { L["Melee haste rating"],                {"melee.haste"} },
        [combat_ratings.CR_HASTE_RANGED                     ]   = { L["Ranged haste rating"],               {"ranged.haste"} },
        [combat_ratings.CR_HIT_SPELL                        ]   = { L["Spell hit rating"],                  {"spell.hit"} },
        [combat_ratings.CR_HIT_MELEE                        ]   = { L["Melee hit rating"],                  {"melee.hit"} },
        [combat_ratings.CR_HIT_RANGED                       ]   = { L["Ranged hit rating"],                 {"ranged.hit"} },
        [combat_ratings.CR_CRIT_SPELL                       ]   = { L["Spell critical rating"],             {"spell.crit", "heal.crit"} },
        [combat_ratings.CR_CRIT_MELEE                       ]   = { L["Melee critical rating"],             {"melee.crit"} },
        [combat_ratings.CR_CRIT_RANGED                      ]   = { L["Ranged critical rating"],            {"ranged.crit"} },
        [combat_ratings.CR_EXPERTISE                        ]   = { L["Expertise rating"],                  {"melee.hit"}, true},

        [combat_ratings.CR_RESILIENCE_CRIT_TAKEN            ]   = { L["Resilience critical chance rating"], {"def.resilience"} },
        [combat_ratings.CR_RESILIENCE_PLAYER_DAMAGE_TAKEN   ]   = { L["Resilience critical damage rating"], {"def.resilience"} },
    };
    local rating_groups = {
        {L["Hit rating"],       {combat_ratings.CR_HIT_MELEE, combat_ratings.CR_HIT_RANGED, combat_ratings.CR_HIT_SPELL}},
        {L["Critical rating"],  {combat_ratings.CR_CRIT_MELEE, combat_ratings.CR_CRIT_RANGED, combat_ratings.CR_CRIT_SPELL}},
        {L["Haste rating"],     {combat_ratings.CR_HASTE_MELEE, combat_ratings.CR_HASTE_RANGED, combat_ratings.CR_HASTE_SPELL}},
    };

    local n = 0;
    local function add(e)
        n = n + 1;
        lines[n] = e;
        return e;
    end
    local function scalar(cells, name, value, perc, mul, extras)
        return add({ kind = "scalar", cells = cells, name = name, value = value, perc = perc, mul = mul, extras = extras });
    end
    local function indexed(cells, name, index_name, from, to, value, perc, mul, index_cells)
        return add({ kind = "indexed", cells = cells, name = name, index_name = index_name, from = from, to = to,
                     value = value, perc = perc, mul = mul, index_cells = index_cells });
    end

    local attribute_cells = { "attr.str", "attr.agi", "attr.sta", "attr.int", "attr.spi" };
    for i = 1, 5 do
        scalar({attribute_cells[i]}, lnames.attributes[i], function(s)
            return ((s.loadout and s.loadout.stats[i]) or 0) + s.effects.by_attr.stat_flat[i];
        end, nil, nil, true).key = "attr"..i;
    end

    -- greyed: they act through the attribute lines; one attribute's change also names what it adds to that attribute
    -- (an attribute is (1 + mod) x (base + added) once the effects are finalized)
    local function stat_mod(s, i)
        return s.effects.by_attr.stat_mod[i] + s.effects.by_attr.stat_mod_forced[i];
    end
    local stat_mods = indexed(attribute_cells, L["All stats bonus"],
        function(i) return string.format(L["%s bonus"], lnames.attributes[i]); end, 1, 5,
        stat_mod, true, nil, attribute_cells);
    stat_mods.extras = true;
    stat_mods.index_under = function(i) return "attr"..i; end;
    -- only the forced part moves the attribute, the rest is already in the sheet's stats
    stat_mods.yield = function(sb, sa, i)
        local mod_after = stat_mod(sa, i);
        if 1 + mod_after <= 0 then
            return nil;
        end
        local total_after = ((sa.loadout and sa.loadout.stats[i]) or 0) + sa.effects.by_attr.stat_flat[i];
        local forced_change = sa.effects.by_attr.stat_mod_forced[i] - sb.effects.by_attr.stat_mod_forced[i];
        return total_after * forced_change / (1 + mod_after);
    end;

    -- Vanilla and Forever show players only what ratings result in, their lines already hold it
    if client_matches(bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever))) then
        local rating_entries = {};
        for _, v in ipairs(ratings) do
            local info = rating_lnames[v[1]];
            rating_entries[v[1]] = add({ kind = "rating", cells = info[2], cr = v[1], field = v[2],
                                         name = info[1] or "", not_pct = info[3] });
        end
        for _, g in ipairs(rating_groups) do
            local group = { name = g[1], members = {}, cells = {} };
            for _, cr in ipairs(g[2]) do
                local e = rating_entries[cr];
                group.members[#group.members + 1] = e;
                for _, c in ipairs(e.cells) do
                    group.cells[#group.cells + 1] = c;
                end
                e.group = group;
            end
        end
    end

    scalar({"melee.power"}, L["Melee attack power"], function(s)
        return lv(s, "ap") + s.effects.raw.ap_flat;
    end);
    scalar({"ranged.power"}, L["Ranged attack power"], function(s)
        return lv(s, "rap") + s.effects.raw.rap_flat;
    end);
    scalar({"res.health"}, L["Health"], function(s)
        return lv(s, "player_hp_max") + s.effects.raw.hp_flat;
    end);
    scalar({"res.mana"}, L["Mana"], function(s)
        return ((s.loadout and s.loadout.resources_max[powers.mana]) or 0) + s.effects.raw.mana;
    end);
    scalar({"def.armor"}, L["Armor"], function(s)
        return lv(s, "armor") + s.effects.by_school.res_flat[schools.physical];
    end);
    scalar({"def.armor"}, L["Physical damage taken"], function(s)
        return s.effects.mul.raw.player_vuln_phys;
    end, true, true);
    indexed({"spell.power"}, L["Spell damage"], school_name(L["spell damage"]), 2, 7, function(s, i)
        return ((s.loadout and s.loadout.spell_dmg_by_school[i]) or 0) + s.effects.by_school.sp_dmg_flat[i];
    end);
    scalar({"heal.power"}, L["Healing power"], function(s)
        return lv(s, "healing_power") + s.effects.raw.healing_power_flat;
    end);
    scalar({"melee.crit"}, L["Physical critical chance"], function(s)
        return lv(s, "melee_crit")
            +
            from_rating(s, 0.01, s.effects.raw.melee_crit_rating_flat, combat_ratings.CR_CRIT_MELEE)
            +
            s.effects.raw.phys_crit_forced;
    end, true);
    scalar({"ranged.crit"}, L["Ranged critical chance"], function(s)
        return lv(s, "ranged_crit")
            +
            from_rating(s, 0.01, s.effects.raw.ranged_crit_rating_flat, combat_ratings.CR_CRIT_RANGED)
            +
            s.effects.raw.phys_crit_forced;
    end, true);
    indexed({"spell.crit", "heal.crit"}, L["Spell critical chance"], school_name(L["spell critical chance"]), 2, 7, function(s, i)
        return ((s.loadout and s.loadout.spell_crit_by_school[i]) or 0)
            +
            s.effects.by_school.crit_forced[i]
            +
            from_rating(s, 0.01, s.effects.raw.spell_crit_rating_flat, combat_ratings.CR_CRIT_SPELL);
    end, true);
    scalar({"melee.hit"}, L["Melee hit chance"], function(s)
        return s.effects.raw.phys_hit
            +
            from_rating(s, 0.01, lv(s, "melee_hit_rating") + s.effects.raw.melee_hit_rating_flat,
                combat_ratings.CR_HIT_MELEE);
    end, true);
    scalar({"ranged.hit"}, L["Ranged hit chance"], function(s)
        return s.effects.raw.phys_hit
            +
            from_rating(s, 0.01, lv(s, "ranged_hit_rating") + s.effects.raw.ranged_hit_rating_flat,
                combat_ratings.CR_HIT_RANGED);
    end, true);
    scalar({"melee.hit"}, L["Expertise"], function(s)
        return s.effects.raw.expertise/0.0025;
    end);
    indexed({"spell.hit"}, L["Spell hit chance"], school_name(L["spell hit chance"]), 2, 7, function(s, i)
        return ((s.loadout and s.loadout.spell_dmg_hit_by_school[i]) or 0)
            +
            s.effects.by_school.spell_hit[i]
            +
            from_rating(s, 0.01, lv(s, "spell_hit_rating") + s.effects.raw.spell_hit_rating_flat,
                combat_ratings.CR_HIT_SPELL);
    end, true);
    scalar({"melee.haste"}, L["Melee haste"], function(s)
        local haste_mul_from_rating = 1.0 +
            from_rating(s, 0.01, lv(s, "melee_haste_rating") + s.effects.raw.melee_haste_rating_flat,
                combat_ratings.CR_HASTE_MELEE);
        return s.effects.mul.raw.melee_haste*s.effects.mul.raw.melee_haste_forced*haste_mul_from_rating;
    end, true, true);
    scalar({"ranged.haste"}, L["Ranged haste"], function(s)
        local haste_mul_from_rating = 1.0 +
            from_rating(s, 0.01, lv(s, "ranged_haste_rating") + s.effects.raw.ranged_haste_rating_flat,
                combat_ratings.CR_HASTE_RANGED);
        return s.effects.mul.raw.ranged_haste*s.effects.mul.raw.ranged_haste_forced*haste_mul_from_rating;
    end, true, true);
    scalar({"spell.haste", "heal.haste"}, L["Spell cast haste"], function(s)
        local haste_mul_from_rating = 1.0 +
            from_rating(s, 0.01, lv(s, "spell_haste_rating") + s.effects.raw.spell_haste_rating_flat,
                combat_ratings.CR_HASTE_SPELL);
        return s.effects.mul.raw.cast_haste*haste_mul_from_rating;
    end, true, true);
    scalar({"res.regen"}, L["Mana regen while casting"], function(s)
        return s.effects.raw.regen_while_casting;
    end, true);
    scalar({"res.regen"}, L["Mana regen per sec while casting"], function(s)
        return (mana_regen(s));
    end);
    scalar({"res.regen"}, L["Mana regen per sec while not casting"], function(s)
        local _, mp1_not_casting = mana_regen(s);
        return mp1_not_casting;
    end);
    scalar({"def.dodge"}, L["Dodge"], function(s)
        return lv(s, "dodge")
            +
            s.effects.raw.dodge
            +
            from_rating(s, 0.0004, s.effects.raw.defense_skill_rating_flat, combat_ratings.CR_DEFENSE_SKILL)
            +
            from_rating(s, 0.01, s.effects.raw.dodge_rating_flat, combat_ratings.CR_DODGE);
    end, true);
    scalar({"def.parry"}, L["Parry"], function(s)
        if s.loadout.parry == 0 then
            return nil;
        end
        return lv(s, "parry")
            +
            s.effects.raw.parry
            +
            from_rating(s, 0.0004, s.effects.raw.defense_skill_rating_flat, combat_ratings.CR_DEFENSE_SKILL)
            +
            from_rating(s, 0.01, s.effects.raw.parry_rating_flat, combat_ratings.CR_PARRY);
    end, true);
    scalar({"def.block"}, L["Block"], function(s)
        if s.effects.raw.can_block <= 0 or not s.loadout.block then
            return nil;
        end
        return lv(s, "block")
            +
            s.effects.raw.block
            +
            from_rating(s, 0.0004, s.effects.raw.defense_skill_rating_flat, combat_ratings.CR_DEFENSE_SKILL)
            +
            from_rating(s, 0.01, s.effects.raw.block_rating_flat, combat_ratings.CR_BLOCK);
    end, true);
    scalar({"def.block"}, L["Block value"], function(s)
        if s.effects.raw.can_block <= 0 then
            return nil;
        end
        return lv(s, "block_value") + s.effects.raw.block_value_flat;
    end);
    scalar({"def.defense"}, L["Chance to be critically hit"], function(s)
        return s.effects.raw.attacker_melee_crit;
    end, true);
    scalar({"melee.pen", "ranged.pen"}, L["Armor penetration"], function(s)
        return -s.effects.by_school.target_res_flat[schools.physical];
    end);
    scalar({"melee.pen", "ranged.pen"}, L["Armor penetration"], function(s)
        local ignored = s.effects.by_school.target_res[schools.physical];
        local mh_subclass_bit = bit.lshift(1, s.effects.raw.wpn_subclass_mh);
        for mask, v in pairs(s.effects.wpn_subclass.target_res) do
            if bit.band(mask, mh_subclass_bit) ~= 0 then
                ignored = ignored + v;
            end
        end
        return -ignored;
    end, true);
    indexed({"spell.pen"}, lnames.spell_pen, school_name(lnames.school_spell_pen), 3, 7, function(s, i)
        return -s.effects.by_school.pierce_flat[i];
    end);
    indexed({"spell.pen"}, L["Target resistance reduction"],
        function(i) return L["Target"].." "..lnames.schools[i].." "..L["resistance reduction"]; end, 3, 7,
        function(s, i)
            return -s.effects.by_school.target_res_flat[i];
        end);
    scalar({"melee.crit", "ranged.crit"}, L["Physical critical damage modifier"], function(s)
        return s.effects.by_school.crit_mod[schools.physical];
    end, true);
    indexed({"spell.crit"}, L["Spell critical damage modifier"], school_name(L["spell critical damage modifier"]), 2, 7,
        function(s, i)
            return s.effects.by_school.crit_mod[i];
        end, true);
    indexed({"heal.crit"}, L["Critical healing modifier"], school_name(L["critical healing modifier"]), 2, 7,
        function(s, i)
            return s.effects.by_school.heal_crit_mod[i];
        end, true);
    indexed({"abil.cost"}, L["Spell cost"], school_name(L["spell cost"]), 2, 7, function(s, i)
        return s.effects.by_school.cost_mod[i];
    end, true);
    indexed({"abil.cost"}, L["Spell cost"], school_name(L["spell cost"]), 2, 7, function(s, i)
        return s.effects.by_school.cost_mod_flat[i];
    end);
    scalar({"melee.threat", "ranged.threat"}, L["Physical threat"], function(s)
        return s.effects.by_school.threat[schools.physical];
    end, true);
    indexed({"spell.threat", "heal.threat"}, L["Spell threat"], school_name(L["spell threat"]), 2, 7, function(s, i)
        return s.effects.by_school.threat[i];
    end, true);

    local function raw(cells, field, name, perc, mul)
        scalar(cells, name, function(s)
            return (mul and s.effects.mul.raw or s.effects.raw)[field];
        end, perc, mul);
    end
    raw({"melee.weapon"}, "wpn_min_mh", L["Main hand weapon minimum damage"]);
    raw({"melee.weapon"}, "wpn_max_mh", L["Main hand weapon maximum damage"]);
    raw({"melee.weapon"}, "wpn_delay_mh", L["Main hand weapon speed"]);
    raw({"melee.weapon"}, "wpn_min_oh", L["Off hand weapon minimum damage"]);
    raw({"melee.weapon"}, "wpn_max_oh", L["Off hand weapon maximum damage"]);
    raw({"melee.weapon"}, "wpn_delay_oh", L["Off hand weapon speed"]);
    raw({"melee.weapon"}, "offhand_mod", L["Offhand damage"], true);
    raw({"ranged.weapon"}, "wpn_min_ranged", L["Ranged weapon minimum damage"]);
    raw({"ranged.weapon"}, "wpn_max_ranged", L["Ranged weapon maximum damage"]);
    raw({"ranged.weapon"}, "wpn_delay_ranged", L["Ranged weapon speed"]);
    raw({"ranged.weapon"}, "ammo_dps", L["Ammo damage per second"]);
    raw({"melee.dmg", "ranged.dmg"}, "phys_dmg_flat", L["Physical damage"]);
    raw({"melee.dmg", "ranged.dmg"}, "phys_mod", L["Physical damage bonus"], true, true);
    raw({"melee.dmg", "ranged.dmg"}, "vuln_phys", L["Target physical damage taken"], true, true);
    raw({"melee.dmg"}, "vuln_bleed", L["Target bleed damage taken"], true, true);

    local wpn_names = {};
    for lname, subclass in pairs(sc.wpn_skill_lname_to_subclass) do
        wpn_names[subclass] = lname;
    end
    local creature_names = {};
    for lname, id in pairs(sc.creature_lname_to_id) do
        creature_names[id - 1] = lname;
    end
    local function mask_names(names, mask, all_text)
        local list, all = {}, true;
        for b = 0, 31 do
            if names[b] then
                if bit.band(mask, bit.lshift(1, b)) ~= 0 then
                    list[#list + 1] = names[b];
                else
                    all = false;
                end
            end
        end
        if all then
            return all_text;
        end
        if #list == 0 then
            return tostring(mask);
        end
        return table.concat(list, ", ");
    end
    local ranged_subclasses = 0;
    for _, subclass in ipairs({ 2, 3, 16, 18, 19 }) do
        ranged_subclasses = bit.bor(ranged_subclasses, bit.lshift(1, subclass));
    end
    local function per_mask(fmt, names, all_text, mask_cells, cells, map, perc, mul)
        add({ kind = "per_mask", cells = cells, name = string.format(fmt, all_text), fmt = fmt, map = map,
              perc = perc, mul = mul, mask_cells = mask_cells, mask_text = function(mask)
                  return mask_names(names, mask, all_text);
              end });
    end
    for _, v in ipairs({
        { "phys_crit_forced",   L["Critical chance with %s"],   "crit",     true },
        { "phys_hit",           L["Hit chance with %s"],        "hit",      true },
        { "phys_crit_mod",      L["Critical damage with %s"],   "crit",     true },
        { "phys_dmg_flat",      L["Weapon damage with %s"],     "weapon" },
        { "skill_flat",         L["Weapon skill with %s"],      "weapon" },
        { "phys_mod",           L["Damage with %s"],            "dmg",      true, true },
        { "spell_mod",          L["Magic damage with %s"],      "dmg",      true, true },
    }) do
        local melee_cell, ranged_cell = "melee."..v[3], "ranged."..v[3];
        per_mask(v[2], wpn_names, L["all weapons"],
            function(mask)
                local cells = {};
                if bit.band(mask, bit.bnot(ranged_subclasses)) ~= 0 then
                    cells[#cells + 1] = melee_cell;
                end
                if bit.band(mask, ranged_subclasses) ~= 0 then
                    cells[#cells + 1] = ranged_cell;
                end
                return cells;
            end,
            { melee_cell, ranged_cell },
            function(s)
                return (v[5] and s.effects.mul.wpn_subclass or s.effects.wpn_subclass)[v[1]];
            end, v[4], v[5]);
    end
    for _, v in ipairs({
        { "ap_flat",        L["Attack power vs %s"],        { "melee.power" } },
        { "rap_flat",       L["Ranged attack power vs %s"], { "ranged.power" } },
        { "sp_dmg_flat",    L["Spell damage vs %s"],        { "spell.power" } },
        { "crit_mod",       L["Critical damage vs %s"],     { "melee.crit", "ranged.crit", "spell.crit" }, true },
        { "dmg_mod",        L["Damage vs %s"],              { "melee.dmg", "ranged.dmg", "spell.dmg" }, true, true },
    }) do
        per_mask(v[2], creature_names, L["all creature types"],
            function() return v[3]; end,
            v[3],
            function(s)
                return (v[5] and s.effects.mul.creature or s.effects.creature)[v[1]];
            end, v[4], v[5]);
    end
    indexed({"spell.dmg"}, L["Spell damage bonus"], school_name(L["spell damage bonus"]), 2, 7, function(s, i)
        return s.effects.mul.by_school.dmg_mod[i];
    end, true, true);
    indexed({"spell.dmg"}, L["Target spell damage taken"],
        function(i) return L["Target"].." "..lnames.schools[i].." "..L["spell damage taken"]; end, 2, 7,
        function(s, i)
            return s.effects.mul.by_school.vuln_mod[i];
        end, true, true);
    raw({"heal.dmg"}, "heal_mod", L["Healing bonus"], true, true);
    raw({"heal.dmg"}, "vuln_heal", L["Target healing taken"], true, true);

    local ability_additive_fields = {
        {"threat",                 L["Threat"],                        true, "threat"},
        {"threat_flat",            L["Threat"],                        nil,  "threat"},
        {"crit",                   L["Critical"],                      true, "crit"},
        {"effect_mod",             L["Effect modifier"],               true, "mod"},
        {"effect_mod_flat",        L["Effect modifier"],               nil,  "mod"},
        {"effect_mod_ot",          L["Periodic effect modifier"],      true, "mod"},
        {"effect_mod_ot_flat",     L["Periodic effect modifier"],      nil,  "mod"},
        {"base_mod",               L["Base effect modifier"],          true, "mod"},
        {"base_mod_flat",          L["Base effect modifier"],          nil,  "mod"},
        {"base_mod_ot",            L["Base periodic effect modifier"], true, "mod"},
        {"base_mod_ot_flat",       L["Base periodic effect modifier"], nil,  "mod"},
        {"cast_mod_flat",          L["Cast time modifier"],            nil,  "cast"},
        {"cast_mod",               L["Cast time modifier"],            true, "cast"},
        {"extra_dur_flat",         L["Extra duration"],                nil,  "dur"},
        {"extra_dur",              L["Extra duration"],                nil,  "dur"},
        {"extra_tick_time_flat",   L["Extra tick time"],               nil,  "dur"},
        {"cost_mod",               L["Cost modifier"],                 true, "cost"},
        {"cost_mod_flat",          L["Cost modifier"],                 nil,  "cost"},
        {"crit_mod",               L["Critical damage modifier"],      true, "crit"},
        {"hit",                    L["Hit"],                           true, "hit"},
        {"sp_flat",                L["Spell power"],                   nil,  "mod"},
        {"flat_add",               L["Additional effect"],             nil,  "mod"},
        {"flat_add_ot",            L["Additional periodic effect"],    nil,  "mod"},
        {"refund",                 L["Refunds"],                       nil,  "cost"},
        {"coef_mod",               L["Coefficient modifier"],          true, "mod"},
        {"coef_mod_flat",          L["Coefficient modifier"],          nil,  "mod"},
        {"effect_mod_only_heal",   L["Healing modifier"],              true, "mod"},
        {"jumps_flat",             L["Extra jumps"],                   nil,  "mod"},
        {"jump_amp",               L["Jump amplifier"],                true, "mod"},
        {"gcd_flat",               L["GCD modifier"],                  nil,  "cast"},
        {"gcd",                    L["GCD modifier"],                  true, "cast"},
    };
    local ability_multiplicative_fields = {
        {"vuln_mod",               L["Target damage taken"],           true, "mod"},
        {"cast_haste",             L["Spell cast haste"],              true, "cast"},
        {"heal_mod",               L["Healing modifier"],              true, "mod"},
        {"cost_mod",               L["Cost modifier"],                 true, "cost"},
    };
    for _, v in ipairs(ability_additive_fields) do
        add({ kind = "per_spell", cells = {"abil."..v[4]}, name = v[2], perc = v[3], map = function(s)
            return s.effects.ability[v[1]];
        end });
    end
    for _, v in ipairs(ability_multiplicative_fields) do
        add({ kind = "per_spell", cells = {"abil."..v[4]}, name = v[2], perc = v[3], mul = true, map = function(s)
            return s.effects.mul.ability[v[1]];
        end });
    end

    for _, v in ipairs({
        {"any", L["On hit"], {"melee.procs", "ranged.procs"}},
        {"mh", L["On hit, main hand"], {"melee.procs"}},
        {"oh", L["On hit, off hand"], {"melee.procs"}},
        {"ranged", L["On hit, ranged"], {"ranged.procs"}},
    }) do
        add({ kind = "per_proc", cells = v[3], name = v[2], map = function(s)
            return s.effects.procs[v[1]];
        end });
    end

    local function add_name(cell, name)
        local names = cell_names[cell];
        if not names then
            names = {};
            cell_names[cell] = names;
        end
        for _, v in ipairs(names) do
            if v == name then
                return;
            end
        end
        names[#names + 1] = name;
    end
    for _, e in ipairs(lines) do
        e.category = (e.index_cells or e.cells)[1]:match("^[^.]+");
        if e.index_cells then
            for i = e.from, e.to do
                add_name(e.index_cells[i], e.index_name(i).." %");
            end
        else
            for _, c in ipairs(e.cells) do
                add_name(c, e.name);
            end
        end
    end
end

local function near(a, b)
    return math.abs(a - b) <= 0.000000001;
end

local function change(a, b, mul)
    if mul then
        return a / b;
    end
    return a - b;
end

local before_side = {};
local after_side = {};
local groups_done = {};
local rows_by_category = {};
for _, c in ipairs(categories) do
    rows_by_category[c] = {};
end

local kinds = {};

kinds.scalar = function(e, sb, sa, sheet, push)
    local b, a = e.value(sb), e.value(sa);
    if b == nil and a == nil then
        return;
    end
    local none = e.mul and 1 or 0;
    push({ name = e.name, b = b or none, a = a or none, perc = e.perc, mul = e.mul, extras = e.extras, key = e.key });
end

kinds.indexed = function(e, sb, sa, sheet, push)
    local vb, va = {}, {};
    for i = e.from, e.to do
        vb[i] = e.value(sb, i);
        va[i] = e.value(sa, i);
    end
    local first = e.from;
    local compact = true;
    for i = e.from + 1, e.to do
        if sheet then
            compact = near(vb[i], vb[first]) and near(va[i], va[first]);
        else
            compact = near(change(va[i], vb[i], e.mul), change(va[first], vb[first], e.mul));
        end
        if not compact then
            break;
        end
    end
    if compact then
        push({ name = e.name, b = vb[first], a = va[first], perc = e.perc, mul = e.mul, extras = e.extras, key = e.key });
        return;
    end
    local index_cells = e.index_cells;
    for i = e.from, e.to do
        if not index_cells or sb.shown[index_cells[i]] then
            push({ name = e.index_name(i), b = vb[i], a = va[i], perc = e.perc, mul = e.mul, extras = e.extras,
                   yield = not sheet and e.yield and e.yield(sb, sa, i) or nil, key = e.key,
                   under = e.index_under and e.index_under(i) });
        end
    end
end

local function rating_val(s, e)
    return lv(s, e.field) + s.effects.raw[e.field.."_flat"];
end
kinds.rating = function(e, sb, sa, sheet, push)
    local group = e.group;
    local merged = false;
    if group and not groups_done[group] then
        local first = group.members[1];
        local b, a = rating_val(sb, first), rating_val(sa, first);
        merged = true;
        for _, m in ipairs(group.members) do
            local mb, ma = rating_val(sb, m), rating_val(sa, m);
            local same;
            if sheet then
                same = near(mb, b) and near(ma, a);
            else
                same = near(ma - mb, a - b);
            end
            if not same or cr_weights[m.cr] ~= cr_weights[first.cr] then
                merged = false;
                break;
            end
        end
        if merged then
            groups_done[group] = true;
            if any_on(sb.shown, group.cells) then
                push({ name = group.name, b = b, a = a, cr = first.cr, not_pct = first.not_pct, extras = true });
            end
        end
    end
    if not merged and not groups_done[group or 0] and any_on(sb.shown, e.cells) then
        push({ name = e.name, b = rating_val(sb, e), a = rating_val(sa, e), cr = e.cr, not_pct = e.not_pct,
               extras = true });
    end
end

-- spells with the same values share one line
-- a list of more than two spells shows the first and how many more ("A +1 more" would hide a name for nothing)
local collapsed_spells = 1;
kinds.per_spell = function(e, sb, sa, sheet, push)
    local mb, ma = e.map(sb), e.map(sa);
    local none = e.mul and 1 or 0;
    local ids, names, vals = {}, {}, {};
    for _, m in ipairs({ mb, ma }) do
        for id in pairs(m) do
            if not names[id] then
                local b, a = mb[id] or none, ma[id] or none;
                if not near(b, none) or not near(a, none) then
                    ids[#ids + 1] = id;
                    names[id] = spell_lname(id) or tostring(id);
                    vals[id] = { b, a, change(a, b, e.mul) };
                end
            end
        end
    end
    local key = sheet and 2 or 3;
    table.sort(ids, function(x, y)
        if vals[x][key] ~= vals[y][key] then
            return vals[x][key] > vals[y][key];
        end
        if vals[x][1] ~= vals[y][1] then
            return vals[x][1] > vals[y][1];
        end
        if names[x] ~= names[y] then
            return names[x] < names[y];
        end
        return x < y;
    end);
    local i = 1;
    while i <= #ids do
        local v = vals[ids[i]];
        local group = { names[ids[i]] };
        local in_group = { [names[ids[i]]] = true };
        local j = i + 1;
        while j <= #ids do
            local w = vals[ids[j]];
            if not (near(w[1], v[1]) and near(w[2], v[2])) and not (not sheet and near(w[3], v[3])) then
                break;
            end
            -- ranks or variants of one spell share a name
            if not in_group[names[ids[j]]] then
                in_group[names[ids[j]]] = true;
                group[#group + 1] = names[ids[j]];
            end
            j = j + 1;
        end
        local short_name;
        if #group > collapsed_spells + 1 then
            short_name = string.format(L["%s +%d more"],
                e.name..": "..table.concat(group, ", ", 1, collapsed_spells), #group - collapsed_spells);
        end
        push({ name = e.name..": "..table.concat(group, ", "), short_name = short_name, b = v[1], a = v[2],
               perc = e.perc, mul = e.mul });
        i = j;
    end
end

kinds.per_proc = function(e, sb, sa, sheet, push)
    local mb, ma = e.map(sb), e.map(sa);
    local ids, names = {}, {};
    for _, m in ipairs({ mb, ma }) do
        for id in pairs(m) do
            if not names[id] and ((mb[id] or 0) ~= 0 or (ma[id] or 0) ~= 0) then
                ids[#ids + 1] = id;
                names[id] = spell_lname(id) or tostring(id);
            end
        end
    end
    table.sort(ids, function(x, y)
        if names[x] ~= names[y] then
            return names[x] < names[y];
        end
        return x < y;
    end);
    for _, id in ipairs(ids) do
        push({ name = e.name..": "..names[id], b = mb[id] or 0, a = ma[id] or 0 });
    end
end

kinds.per_mask = function(e, sb, sa, sheet, push)
    local mb, ma = e.map(sb), e.map(sa);
    local none = e.mul and 1 or 0;
    local masks, texts = {}, {};
    for _, m in ipairs({ mb, ma }) do
        for mask in pairs(m) do
            if not texts[mask] and (not near(mb[mask] or none, none) or not near(ma[mask] or none, none)) then
                masks[#masks + 1] = mask;
                texts[mask] = e.mask_text(mask);
            end
        end
    end
    table.sort(masks, function(x, y)
        if texts[x] ~= texts[y] then
            return texts[x] < texts[y];
        end
        return x < y;
    end);
    for _, mask in ipairs(masks) do
        local cells = e.mask_cells(mask);
        if any_on(sb.shown, cells) then
            push({ name = string.format(e.fmt, texts[mask]), b = mb[mask] or none, a = ma[mask] or none,
                   perc = e.perc, mul = e.mul }, shown_category(sb.shown, cells));
        end
    end
end

-- a row with `under` moves right below the last row with that `key` in its category (an attribute's bonus under the
-- attribute), else it stays where the registry put it
local placed = {};
local moving = {};
local function place_under(list)
    local keys = 0;
    for _, r in ipairs(list) do
        if r.under then
            keys = keys + 1;
        end
    end
    if keys == 0 then
        return;
    end
    for k in pairs(moving) do
        moving[k] = nil;
    end
    for _, r in ipairs(list) do
        if r.key then
            moving[r.key] = moving[r.key] or {};
        end
    end
    for _, r in ipairs(list) do
        local to = r.under and moving[r.under];
        if to then
            to[#to + 1] = r;
        end
    end
    local n = #list;
    for i = 1, n do
        placed[i] = list[i];
    end
    local j = 0;
    for i = 1, n do
        local r = placed[i];
        if not (r.under and moving[r.under]) then
            j = j + 1;
            list[j] = r;
            local next_row = placed[i + 1];
            if r.key and not (next_row and next_row.key == r.key) then
                for _, m in ipairs(moving[r.key]) do
                    j = j + 1;
                    list[j] = m;
                end
            end
        end
        placed[i] = nil;
    end
end

-- rows per category of both sides, false when nothing is shown
local function collect(loadout, effects_before, effects_after, sheet)
    local shown = shown_cells();
    if not any_on(shown, all_cells) then
        return false;
    end
    for _, side in ipairs({ before_side, after_side }) do
        side.loadout = loadout;
        side.cr = loadout.cr_scaling;
        side.shown = shown;
    end
    before_side.effects = effects_before;
    after_side.effects = effects_after;
    for k in pairs(groups_done) do
        groups_done[k] = nil;
    end
    for _, c in ipairs(categories) do
        local list = rows_by_category[c];
        for i = #list, 1, -1 do
            list[i] = nil;
        end
    end

    local list;
    local function push(row, category)
        local l = category and rows_by_category[category] or list;
        l[#l + 1] = row;
    end
    for _, e in ipairs(lines) do
        if e.kind == "rating" or any_on(shown, e.cells) then
            list = rows_by_category[e.index_cells and e.category or shown_category(shown, e.cells)];
            kinds[e.kind](e, before_side, after_side, sheet, push);
        end
    end
    for _, c in ipairs(categories) do
        place_under(rows_by_category[c]);
    end
    return true;
end

local function rating_text(val, row, cr_scaling)
    local resolved = val/(cr_scaling * cr_weights[row.cr]);
    if row.not_pct then
        return string.format("%.1f", resolved);
    end
    return string.format("%s%%", (string.format("%.2f", resolved):gsub("%.?0+$", "")));
end

-- the text, the number of lines, the lines in and out, and the text with long spell lists shortened (nil when
-- nothing was shortened)
local function format_changes(loadout, effects_before, effects_after)
    local info = {
        str = "",
        num_in = 0;
        num_out = 0;
    };
    if not collect(loadout, effects_before, effects_after, false) then
        return info.str, 0, 0, 0, nil;
    end
    local short_str = "";
    local shortened = false;
    local cat_info = {};
    local cat_short = {};
    for _, c in ipairs(categories) do
        cat_info.str, cat_info.num_in, cat_info.num_out = "", 0, 0;
        cat_short.str, cat_short.num_in, cat_short.num_out = "", 0, 0;
        for _, row in ipairs(rows_by_category[c]) do
            local val = change(row.a, row.b, row.mul);
            local name = row.name;
            if row.cr then
                name = string.format("(%s) %s", rating_text(val, row, loadout.cr_scaling), name);
            end
            if row.yield and math.abs(row.yield) >= 0.5 then
                name = string.format("%s (%s%.0f)", name, row.yield > 0 and "+" or "-", math.abs(row.yield));
            end
            add_field_line(cat_info, val, name, true, row.perc, row.mul, nil, row.extras);
            if add_field_line(cat_short, val, row.short_name or name, true, row.perc, row.mul, nil, row.extras) and
                row.short_name then
                shortened = true;
            end
        end
        if cat_info.str ~= "" then
            local header = "|cFFFFFFFF"..category_names[c].."|r\n";
            info.str = info.str..header..cat_info.str;
            short_str = short_str..header..cat_short.str;
            info.num_in = info.num_in + cat_info.num_in;
            info.num_out = info.num_out + cat_info.num_out;
        end
    end
    return info.str, info.num_in + info.num_out, info.num_in, info.num_out, shortened and short_str or nil;
end

local function value_text(val, perc, mul, signed)
    local disp = val;
    local suffix = "";
    if mul then
        disp = 100*(disp - 1);
        suffix = "%";
    elseif perc then
        disp = 100*disp;
        suffix = "%";
    end
    local abs_val = math.abs(disp);
    local str;
    if abs_val == math.floor(abs_val) then
        str = string.format("%.0f", abs_val);
    else
        str = string.format("%.3f", abs_val):gsub("%.?0+$", "");
    end
    if disp < 0 and not near(disp, 0) then
        str = "-"..str;
    elseif signed then
        str = "+"..str;
    end
    return str..suffix;
end

-- the character sheet: { header = name } or { left = stat name, right = value text } per row
local function format_sheet(loadout, effects_before, effects_after)
    local out = {};
    if not collect(loadout, effects_before, effects_after, true) then
        return out;
    end
    for _, c in ipairs(categories) do
        local header_added = false;
        for _, row in ipairs(rows_by_category[c]) do
            local none = row.mul and 1 or 0;
            if not (near(row.b, none) and near(row.a, none)) then
                if not header_added then
                    out[#out + 1] = { header = category_names[c] };
                    header_added = true;
                end
                local b_str = value_text(row.b, row.perc, row.mul);
                local a_str = value_text(row.a, row.perc, row.mul);
                if row.cr then
                    b_str = b_str.." ("..rating_text(row.b, row, loadout.cr_scaling)..")";
                    a_str = a_str.." ("..rating_text(row.a, row, loadout.cr_scaling)..")";
                end
                local right = b_str;
                if not near(row.a, row.b) then
                    local val = change(row.a, row.b, row.mul);
                    local up = (row.mul and val > 1) or (not row.mul and val > 0);
                    local color = up and "|cFF21B915" or "|cFFC32C0B";
                    right = string.format("%s |cFF909090->|r %s%s (%s)|r", b_str, color, a_str,
                        value_text(val, row.perc, row.mul, true));
                end
                out[#out + 1] = { left = row.name, short_left = row.short_name, right = right, extras = row.extras };
            end
        end
    end
    return out;
end

local function sheet_text(sheet_rows)
    local parts = {};
    for _, r in ipairs(sheet_rows) do
        if r.header then
            parts[#parts + 1] = r.header;
        else
            parts[#parts + 1] = "    "..r.left..": "..r.right;
        end
    end
    return table.concat(parts, "\n");
end

stat_lines.add_field_line                         = add_field_line;
stat_lines.all_cells                              = all_cells;
stat_lines.rows                                   = rows;
stat_lines.columns                                = columns;
stat_lines.attribute_keys                         = attribute_keys;
stat_lines.resource_keys                          = resource_keys;
stat_lines.defense_keys                           = defense_keys;
stat_lines.ability_keys                           = ability_keys;
stat_lines.cell_names                             = cell_names;
stat_lines.shown_cells                            = shown_cells;
stat_lines.set_cell                               = set_cell;
stat_lines.reset_class_cells                      = reset_class_cells;
stat_lines.settings_id                            = function() return settings_id; end;
stat_lines.init                                   = init;
stat_lines.format_changes                         = format_changes;
stat_lines.format_sheet                           = format_sheet;
stat_lines.sheet_text                             = sheet_text;
