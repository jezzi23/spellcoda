local _, sc               = ...;

local apply_effect        = sc.loadouts.apply_effect;
local is_secret           = sc.utils.is_secret;
local client_matches      = sc.utils.client_matches;
local client_flags        = sc.client_flags;

----------------------------------------------------------------------------------------------------
local buffs_export        = {};
local buff_category       = {
    class    = 1,
    player   = 2,
    hostile  = 3,
    friendly = 4,
    enchant  = 5,
};

local unique_buffs        = {};
local unique_target_buffs = {};

for k, _ in pairs(sc.class_buffs) do
    if not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            lname = C_Spell.GetSpellName(k),
            cat = buff_category.class,
        };
    end
end
for k, _ in pairs(sc.player_buffs) do
    if not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            lname = C_Spell.GetSpellName(k),
            cat = buff_category.player,
        };
    end
end
-- allows weapon enchant buffs to be registered as buffs
for k, _ in pairs(sc.enchant_effects) do

    if k > 0 and not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            --lname = C_Spell.GetSpellName(sc.enchant_effects[k]),
            lname = C_Spell.GetSpellName(k),
            cat = buff_category.enchant,
        };
    end
end
for k, _ in pairs(sc.hostile_buffs) do
    if not unique_target_buffs[k] then
        unique_target_buffs[k] = {
            id = k,
            lname = C_Spell.GetSpellName(k),
            cat = buff_category.hostile,
        };
    end
end
for k, _ in pairs(sc.friendly_buffs) do
    if not unique_target_buffs[k] then
        unique_target_buffs[k] = {
            id = k,
            lname = C_Spell.GetSpellName(k),
            cat = buff_category.friendly,
        };
    end
end

local buffs        = {};
local target_buffs = {};

for k, v in pairs(unique_buffs) do
    table.insert(buffs, v);
end
for k, v in pairs(unique_target_buffs) do
    table.insert(target_buffs, v);
end

unique_buffs = nil;
unique_target_buffs = nil;

local aura_getters = {
    { get = C_UnitAuras.GetBuffDataByIndex, filter = "HELPFUL" },
    { get = C_UnitAuras.GetDebuffDataByIndex, filter = "HARMFUL" },
};
local should_auras_be_secret = C_Secrets and C_Secrets.ShouldAurasBeSecret;

local is_player_owned;
if client_matches(client_flags.forever) then
    -- AuraData has no sourceUnit on Forever
    is_player_owned = function(aura) return aura.isFromPlayerOrPlayerPet; end;
else
    is_player_owned = function(aura) return aura.sourceUnit == "player"; end;
end

-- keeps the unit's buffs of the last unrestricted read while it is the same unit
local function keep_restricted_buffs(loadout, prev, unit)
    local guid = UnitGUID(unit);
    if is_secret(guid) or guid ~= prev.aura_guids[unit] then
        return;
    end
    loadout.aura_guids[unit] = guid;
    local kept = loadout.dynamic_buffs[unit];
    for id, buff_info in pairs(prev.dynamic_buffs[unit]) do
        kept[id] = buff_info;
    end
    for lname, buff_info in pairs(prev.dynamic_buffs_lname[unit]) do
        if kept[buff_info.id] == buff_info then
            loadout.dynamic_buffs_lname[unit][lname] = buff_info;
        end
    end
end

-- the form stays readable while restricted, the form aura follows it
local function restricted_form_buffs(loadout)
    local kept = loadout.dynamic_buffs["player"];
    local kept_lname = loadout.dynamic_buffs_lname["player"];
    for i = 1, GetNumShapeshiftForms() do
        local spell_id = select(4, GetShapeshiftFormInfo(i));
        if i == loadout.shapeshift and spell_id then
            if not kept[spell_id] then
                local buff_info = { count = 1, id = spell_id, player_owned = true };
                kept[spell_id] = buff_info;
                local lname = C_Spell.GetSpellName(spell_id);
                if lname then
                    kept_lname[lname] = buff_info;
                end
            end
        elseif kept[spell_id] then
            kept[spell_id] = nil;
            for lname, buff_info in pairs(kept_lname) do
                if buff_info.id == spell_id then
                    kept_lname[lname] = nil;
                end
            end
        end
    end
end

local function detect_buffs(loadout, prev)
    loadout.dynamic_buffs["player"] = {};
    loadout.dynamic_buffs["target"] = {};
    loadout.dynamic_buffs["mouseover"] = {};
    loadout.dynamic_buffs_lname["player"] = {};
    loadout.dynamic_buffs_lname["target"] = {};
    loadout.dynamic_buffs_lname["mouseover"] = {};
    if loadout.player_name == loadout.target_name then
        loadout.dynamic_buffs["target"] = loadout.dynamic_buffs["player"]
        loadout.dynamic_buffs_lname["target"] = loadout.dynamic_buffs_lname["player"]
    end
    if loadout.player_name == loadout.mouseover_name then
        loadout.dynamic_buffs["mouseover"] = loadout.dynamic_buffs["player"]
        loadout.dynamic_buffs_lname["mouseover"] = loadout.dynamic_buffs_lname["player"]
    end
    if loadout.target_name == loadout.mouseover_name then
        loadout.dynamic_buffs["mouseover"] = loadout.dynamic_buffs["target"]
        loadout.dynamic_buffs_lname["mouseover"] = loadout.dynamic_buffs_lname["target"]
    end

    wipe(loadout.aura_guids);
    if should_auras_be_secret and should_auras_be_secret() then
        -- ignoring buffs leaves only the form, apply_snapshot_deltas takes the snapshot buffs out of the sheet stats
        if not (sc.config.settings.loadout_combat_ignore_buffs and client_matches(client_flags.forever)) then
            for k, _ in pairs(loadout.dynamic_buffs) do
                keep_restricted_buffs(loadout, prev, k);
            end
        end
        restricted_form_buffs(loadout);
        loadout.snapshot_buffs = prev.snapshot_buffs;
        return;
    end

    for k, v in pairs(loadout.dynamic_buffs) do
        loadout.aura_guids[k] = UnitGUID(k);
        for _, getter in ipairs(aura_getters) do
            local i = 1;
            while true do
                local aura = getter.get(k, i);
                if not aura then
                    break;
                end
                local spell_id = aura.spellId;
                -- skips auras of spells flagged always secret
                if not is_secret(spell_id) then
                    -- player owned takes priority
                    local player_owned = is_player_owned(aura);
                    if not v[spell_id] or player_owned then
                        local buff_info = { count = aura.applications, id = spell_id, player_owned = player_owned };
                        v[spell_id] = buff_info;
                        loadout.dynamic_buffs_lname[k][aura.name] = buff_info;
                    end
                end
                i = i + 1;
            end
        end
    end

    if __spellcoda_test_all_data__ then
        for k, v in pairs(loadout.dynamic_buffs) do
            for _, list in ipairs({buffs, target_buffs}) do
                for _, b in ipairs(list) do
                    if not v[b.id] then
                        local buff_info = { count = 1, id = b.id, player_owned = true };
                        v[b.id] = buff_info;
                        if b.lname then
                            loadout.dynamic_buffs_lname[k][b.lname] = buff_info;
                        end
                    end
                end
            end
        end
    end

    loadout.snapshot_buffs = loadout.dynamic_buffs["player"];
end

-- the forced application minus the regular one, the part of a buff that is in the sheet stats
local function apply_sheet_part(effects, id, buff_info, undo)
    local auras = sc.class_buffs[id] or sc.player_buffs[id];
    if auras then
        apply_effect(effects, id, auras, true, buff_info.count, undo, buff_info.player_owned);
        apply_effect(effects, id, auras, false, buff_info.count, not undo, buff_info.player_owned);
    end
end

-- sheet stats are kept from the last unrestricted read, move the sheet part of player buffs lost or gained since
local function apply_snapshot_deltas(loadout, effects)
    local snapshot = loadout.snapshot_buffs;
    local current = loadout.dynamic_buffs["player"];
    if snapshot == current then
        return;
    end
    for id, buff_info in pairs(snapshot) do
        if not current[id] then
            apply_sheet_part(effects, id, buff_info, true);
        end
    end
    for id, buff_info in pairs(current) do
        if not snapshot[id] then
            apply_sheet_part(effects, id, buff_info, false);
        end
    end
end

local function apply_buffs(loadout, effects, forced, undo)

    if __spellcoda_test_all_data__ then
        -- Testing all buffs
        local buffs_applied = 0;
        for k, v in pairs(sc.player_buffs) do
            apply_effect(effects, k, v, true, 1, undo, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.class_buffs) do
            apply_effect(effects, k, v, true, 1, undo, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.friendly_buffs) do
            apply_effect(effects, k, v, true, 1, undo, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.hostile_buffs) do
            apply_effect(effects, k, v, true, 1, undo, true);
            buffs_applied = buffs_applied + 1;
        end
        print(buffs_applied, "gen buffs applied");
    else
        for k, v in pairs(loadout.dynamic_buffs["player"]) do
            if sc.class_buffs[k] then
                apply_effect(effects, k, sc.class_buffs[k], forced, v.count, undo, v.player_owned);
            elseif sc.player_buffs[k] then
                apply_effect(effects, k, sc.player_buffs[k], forced, v.count, undo, v.player_owned);
            end
        end
        for k, v in pairs(loadout.dynamic_buffs[loadout.friendly_towards]) do
            if sc.friendly_buffs[k] then
                apply_effect(effects, k, sc.friendly_buffs[k], forced, v.count, undo, v.player_owned);
            end
        end
        if loadout.hostile_towards ~= "" then
            for k, v in pairs(loadout.dynamic_buffs[loadout.hostile_towards]) do
                if sc.hostile_buffs[k] then
                    apply_effect(effects, k, sc.hostile_buffs[k], forced, v.count, undo, v.player_owned);
                end
            end
        end
    end

    -- some shapeshifts like stances cannot be detected as buff
    -- assigned from data override
    if sc.shapeshift_id_to_effects and sc.shapeshift_id_to_effects[loadout.shapeshift] then
        for _, k in pairs(sc.shapeshift_id_to_effects[loadout.shapeshift]) do
            apply_effect(effects, k, sc.shapeshift_passives[k], forced, 1, undo);
        end
    end
end

local function apply_fake_buffs(loadout, effects, buffs_cfg)

    local preserve = buffs_cfg.preserve_active;
    if not preserve then
        apply_buffs(loadout, effects, true, true);
    end

    for k, cnt in pairs(buffs_cfg.player_buffs) do
        if not preserve or not loadout.dynamic_buffs["player"][k] then
            if sc.class_buffs[k] then
                apply_effect(effects, k, sc.class_buffs[k], true, cnt, false, true);
            elseif sc.player_buffs[k] then
                apply_effect(effects, k, sc.player_buffs[k], true, cnt, false, true);
            elseif sc.enchant_effects[k] then
                apply_effect(effects, k, sc.enchant_effects[k], true, cnt, false, true);
            end
        end
    end
    for k, cnt in pairs(buffs_cfg.target_buffs) do
        if not preserve or
            (not loadout.dynamic_buffs[loadout.friendly_towards][k]
            and
            (loadout.hostile_towards == "" or not loadout.dynamic_buffs[loadout.hostile_towards][k])) then
            if sc.friendly_buffs[k] then
                apply_effect(effects, k, sc.friendly_buffs[k], true, cnt, false, true);
            end
            if sc.hostile_buffs[k] then
                apply_effect(effects, k, sc.hostile_buffs[k], true, cnt, false, true);
            end
        end
    end
end

local sandbox_buffs_cfg;
local function post_login_load()
    sandbox_buffs_cfg = __sc_frame.calculator_frame.buffs.working;
end

local function get_buff_by_lname(loadout, unit, lname, only_self_buff, require_ownership)

    if __spellcoda_debug__ and not lname then
        print("SpellCoda: buff lookup with nil name at", ((debugstack(2, 1, 0) or ""):gsub("\n", "")));
    end
    if unit ~= "" and
        (not loadout.calculator_mode or not sandbox_buffs_cfg.use_custom or sandbox_buffs_cfg.preserve_active) then

        local buff = loadout.dynamic_buffs_lname[unit][lname];
        if buff and (not require_ownership or buff.player_owned) then
            return buff.id;
        end
    end
    if loadout.calculator_mode and
        sandbox_buffs_cfg.use_custom and
        sc.ui.forced_buffs_lname_to_id[lname] and
         ((only_self_buff and
            sandbox_buffs_cfg.player_buffs[sc.ui.forced_buffs_lname_to_id[lname]])
            or
            sandbox_buffs_cfg.target_buffs[sc.ui.forced_buffs_lname_to_id[lname]]) then

        return sc.ui.forced_buffs_lname_to_id[lname]
    end

    return nil;
end

local function get_buff(loadout, unit, id, only_self_buff, require_ownership)

    if __spellcoda_debug__ and not id then
        print("SpellCoda: buff lookup with nil id at", ((debugstack(2, 1, 0) or ""):gsub("\n", "")));
    end
    if unit ~= "" and
        (not loadout.calculator_mode or not sandbox_buffs_cfg.use_custom or sandbox_buffs_cfg.preserve_active) then

        local buff = loadout.dynamic_buffs[unit][id];
        if buff and (not require_ownership or buff.player_owned) then
            return buff.id;
        end
    end

    if loadout.calculator_mode and
        sandbox_buffs_cfg.use_custom and
         ((only_self_buff and sandbox_buffs_cfg.player_buffs[id]) or
            sandbox_buffs_cfg.target_buffs[id]) then

        return id;
    end

    return nil;
end

----------------------------------------------------------------------------------------------------
buffs_export.buff_category                      = buff_category;
buffs_export.buffs                              = buffs;
buffs_export.target_buffs                       = target_buffs;
buffs_export.detect_buffs                       = detect_buffs;
buffs_export.apply_buffs                        = apply_buffs;
buffs_export.apply_snapshot_deltas              = apply_snapshot_deltas;
buffs_export.apply_fake_buffs                   = apply_fake_buffs;
buffs_export.get_buff                           = get_buff;
buffs_export.get_buff_by_lname                  = get_buff_by_lname;
buffs_export.post_login_load                    = post_login_load;

sc.buffs = buffs_export;
