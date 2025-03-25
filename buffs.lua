local _, sc               = ...;

local class               = sc.class;
local classes             = sc.classes;
local apply_effect        = sc.loadouts.apply_effect;

local config              = sc.config;

-------------------------------------------------------------------------------
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
            lname = GetSpellInfo(k),
            cat = buff_category.class,
        };
    end
end
for k, _ in pairs(sc.player_buffs) do
    if not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            lname = GetSpellInfo(k),
            cat = buff_category.player,
        };
    end
end
-- allows weapon enchant buffs to be registered as buffs
for k, _ in pairs(sc.enchant_effects) do
    if not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            --lname = GetSpellInfo(sc.enchant_effects[k]),
            lname = GetSpellInfo(k),
            cat = buff_category.enchant,
        };
    end
end
for k, _ in pairs(sc.hostile_buffs) do
    if not unique_target_buffs[k] then
        unique_target_buffs[k] = {
            id = k,
            lname = GetSpellInfo(k),
            cat = buff_category.hostile,
        };
    end
end
for k, _ in pairs(sc.friendly_buffs) do
    if not unique_target_buffs[k] then
        unique_target_buffs[k] = {
            id = k,
            lname = GetSpellInfo(k),
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

local function detect_buffs(loadout)
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

    for k, v in pairs(loadout.dynamic_buffs) do
        local i = 1;
        while true do
            local lname, _, count, _, _, exp_time, src, _, _, spell_id = UnitBuff(k, i);
            if not spell_id then
                break;
            end
            if not exp_time then
                exp_time = 0.0;
            end
            -- player owned takes priority
            local player_owned = src == "player";
            if not v[spell_id] or player_owned then
                local buff_info = { count = count, id = spell_id, player_owned = player_owned };
                v[spell_id] = buff_info
                loadout.dynamic_buffs_lname[k][lname] = buff_info;
            end
            i = i + 1;
        end
        local i = 1;
        while true do
            local lname, _, count, _, _, exp_time, src, _, _, spell_id = UnitDebuff(k, i);
            if not spell_id then
                break;
            end
            if not exp_time then
                exp_time = 0.0;
            end
            local player_owned = src == "player";
            if not v[spell_id] or player_owned then
                local buff_info = { count = count, id = spell_id, player_owned = player_owned };
                v[spell_id] = buff_info;
                loadout.dynamic_buffs_lname[k][lname] = buff_info;
            end
            i = i + 1;
        end
    end
end

local function apply_buffs(loadout, effects)
    for k, v in pairs(loadout.dynamic_buffs["player"]) do
        if sc.class_buffs[k] then
            apply_effect(effects, k, sc.class_buffs[k], false, v.count, false, v.player_owned);
        elseif sc.player_buffs[k] then
            apply_effect(effects, k, sc.player_buffs[k], false, v.count, false, v.player_owned);
        end
    end
    for k, v in pairs(loadout.dynamic_buffs[loadout.friendly_towards]) do
        if sc.friendly_buffs[k] then
            apply_effect(effects, k, sc.friendly_buffs[k], false, v.count, false, v.player_owned);
        end
    end
    if loadout.hostile_towards ~= "" then
        for k, v in pairs(loadout.dynamic_buffs[loadout.hostile_towards]) do
            if sc.hostile_buffs[k] then
                apply_effect(effects, k, sc.hostile_buffs[k], false, v.count, false, v.player_owned);
            end
        end
    end

    local beacon_duration = 60;
    if class == classes.paladin and loadout.enchants[407613] and
        sc.core.beacon_snapshot_time + beacon_duration >= sc.core.addon_running_time then
        loadout.beacon = true;
    else
        loadout.beacon = nil
    end

    -- some shapeshifts like stances cannot be detected as buff
    -- assigned from data override
    if sc.shapeshift_id_to_effects and sc.shapeshift_id_to_effects[loadout.shapeshift] then
        for _, k in pairs(sc.shapeshift_id_to_effects[loadout.shapeshift]) do
            apply_effect(effects, k, sc.shapeshift_passives[k], false, 1);
        end
    end


    if config.loadout.force_apply_buffs then
        for k, cnt in pairs(config.loadout.buffs) do
            if not loadout.dynamic_buffs["player"][k] then
                if sc.class_buffs[k] then
                    apply_effect(effects, k, sc.class_buffs[k], true, cnt, false, true);
                elseif sc.player_buffs[k] then
                    apply_effect(effects, k, sc.player_buffs[k], true, cnt, false, true);
                elseif sc.enchant_effects[k] and not loadout.enchants[k] then
                    apply_effect(effects, k, sc.enchant_effects[k], true, cnt, false, true);
                end
            end
        end
        for k, cnt in pairs(config.loadout.target_buffs) do
            if not loadout.dynamic_buffs[loadout.friendly_towards][k] and
                (loadout.hostile_towards == "" or not loadout.dynamic_buffs[loadout.hostile_towards][k])
            then
                if sc.friendly_buffs[k] then
                    apply_effect(effects, k, sc.friendly_buffs[k], true, cnt, false, true);
                end
                if sc.hostile_buffs[k] then
                    apply_effect(effects, k, sc.hostile_buffs[k], true, cnt, false, true);
                end
            end
        end

        if class == classes.paladin and config.loadout.target_buffs[407613] then
            loadout.beacon = true;
        end
    end

    if sc.core.__sw__test_all_codepaths then
        -- Testing all buffs
        local buffs_applied = 0;
        for k, v in pairs(sc.player_buffs) do
            apply_effect(effects, k, v, true, 1, false, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.class_buffs) do
            apply_effect(effects, k, v, true, 1, false, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.friendly_buffs) do
            apply_effect(effects, k, v, true, 1, false, true);
            buffs_applied = buffs_applied + 1;
        end
        for k, v in pairs(sc.hostile_buffs) do
            apply_effect(effects, k, v, true, 1, false, true);
            buffs_applied = buffs_applied + 1;
        end
        print(buffs_applied, "gen buffs applied");
    end
end

local function get_buff_by_lname(loadout, unit, lname, only_self_buff, require_ownership)
    if unit ~= "" then
        local buff = loadout.dynamic_buffs_lname[unit][lname];
        if buff and (not require_ownership or buff.player_owned) then
            return buff.id;
        end
    else
        if config.loadout.force_apply_buffs and sc.ui.forced_buffs_lname_to_id[lname] then
            if only_self_buff and
                config.loadout.buffs[sc.ui.forced_buffs_lname_to_id[lname]] then
                return sc.ui.forced_buffs_lname_to_id[lname]
            elseif config.loadout.target_buffs[sc.ui.forced_buffs_lname_to_id[lname]] then
                return sc.ui.forced_buffs_lname_to_id[lname]
            end
        end
    end
    return nil;
end

local function get_buff(loadout, unit, id, only_self_buff, require_ownership)
    if unit ~= "" then
        local buff = loadout.dynamic_buffs[unit][id];
        if buff and (not require_ownership or buff.player_owned) then
            return buff.id;
        end
    else
        if config.loadout.force_apply_buffs then
            if only_self_buff and config.loadout.buffs[id] then
                return id;
            elseif config.loadout.target_buffs[id] then
                return id;
            end
        end
    end

    return nil;
end

buffs_export.buff_filters = buff_filters;
buffs_export.filter_flags_active = filter_flags_active;
buffs_export.buff_category = buff_category;
buffs_export.buffs = buffs;
buffs_export.target_buffs = target_buffs;
buffs_export.detect_buffs = detect_buffs;
buffs_export.apply_buffs = apply_buffs;
buffs_export.non_stackable_effects = non_stackable_effects;
buffs_export.get_buff = get_buff;
buffs_export.get_buff_by_lname = get_buff_by_lname;

sc.buffs = buffs_export;
