local _, sc               = ...;

local apply_effect        = sc.loadouts.apply_effect;
local is_secret           = sc.utils.is_secret;
local any_secret          = sc.utils.any_secret;
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

-- player and target are scanned again only after UNIT_AURA, a unit change or an unscanned read,
-- a friendly mouseover on every read
local aura_changed = { player = true, target = true };
local last_read_scanned = false;

for unit, _ in pairs(aura_changed) do
    local f = CreateFrame("Frame");
    f:RegisterEvent("PLAYER_ENTERING_WORLD");
    if f.RegisterUnitEvent then
        f:RegisterUnitEvent("UNIT_AURA", unit);
        f:SetScript("OnEvent", function()
            aura_changed[unit] = true;
        end);
    else
        f:RegisterEvent("UNIT_AURA");
        f:SetScript("OnEvent", function(_, event, event_unit)
            if event ~= "UNIT_AURA" or event_unit == unit then
                aura_changed[unit] = true;
            end
        end);
    end
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

-- buffs tracked in blizzard's cooldown manager stay known while restricted: its viewers read our own auras on
-- player and target untainted and leave plain isActive / auraDataUnit on their item frames
local cdm_viewers = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" };
-- cooldown id -> { player = ids, hostile = ids, friendly = ids } of our buffs, false when it has none
local cdm_candidates = {};
-- spell id -> time of our last cast, picks the rank of an item linking several
local cdm_last_cast = {};
local cdm_buff_infos = {};
local cdm_lnames = {};
local cdm_present = { player = {}, target = {} };
local cdm_absent = { player = {}, target = {} };

if client_matches(client_flags.forever) and C_CooldownViewer then
    local f = CreateFrame("Frame");
    f:RegisterEvent("SPELLS_CHANGED");
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
    f:SetScript("OnEvent", function(_, event, _, _, spell_id)
        if event == "SPELLS_CHANGED" then
            wipe(cdm_candidates);
        elseif not is_secret(spell_id) and
            (sc.class_buffs[spell_id] or sc.player_buffs[spell_id] or
             sc.hostile_buffs[spell_id] or sc.friendly_buffs[spell_id]) then
            cdm_last_cast[spell_id] = GetTime();
        end
    end);
end

local function cdm_candidates_of(cooldown_id)
    local c = cdm_candidates[cooldown_id];
    if c ~= nil then
        return c;
    end
    c = false;
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldown_id);
    if info then
        local ids = {};
        for _, id in pairs({ info.spellID, info.overrideSpellID, info.overrideTooltipSpellID }) do
            ids[#ids + 1] = id;
        end
        for _, id in ipairs(info.linkedSpellIDs or {}) do
            ids[#ids + 1] = id;
        end
        local lists = { player = {}, hostile = {}, friendly = {} };
        local seen = {};
        for _, id in ipairs(ids) do
            if not is_secret(id) and not seen[id] then
                seen[id] = true;
                if sc.class_buffs[id] or sc.player_buffs[id] then
                    table.insert(lists.player, id);
                end
                if sc.hostile_buffs[id] then
                    table.insert(lists.hostile, id);
                end
                if sc.friendly_buffs[id] then
                    table.insert(lists.friendly, id);
                end
            end
        end
        if #lists.player + #lists.hostile + #lists.friendly > 0 then
            c = lists;
        end
    end
    cdm_candidates[cooldown_id] = c;
    return c;
end

local function remove_buff(loadout, unit, id)
    local buff_info = loadout.dynamic_buffs[unit][id];
    loadout.dynamic_buffs[unit][id] = nil;
    for lname, v in pairs(loadout.dynamic_buffs_lname[unit]) do
        if v == buff_info then
            loadout.dynamic_buffs_lname[unit][lname] = nil;
        end
    end
end

-- the rank of an active item: the one already known, else our last cast, else the only candidate we know
local function cdm_rank(kept, ids)
    local best, best_time;
    local known, n_known = nil, 0;
    for _, id in ipairs(ids) do
        if kept[id] then
            return nil;
        end
        local t = cdm_last_cast[id];
        if t and (not best_time or t > best_time) then
            best, best_time = id, t;
        end
        if IsPlayerSpell(id) then
            known, n_known = id, n_known + 1;
        end
    end
    if best then
        return best;
    end
    if #ids == 1 then
        return ids[1];
    end
    if n_known == 1 then
        return known;
    end
    return nil;
end

local function cdm_apply(loadout, unit)
    local kept = loadout.dynamic_buffs[unit];
    for _, ids in ipairs(cdm_absent[unit]) do
        for _, id in ipairs(ids) do
            if kept[id] and kept[id].player_owned then
                remove_buff(loadout, unit, id);
            end
        end
    end
    for _, ids in ipairs(cdm_present[unit]) do
        local id = cdm_rank(kept, ids);
        if id then
            local buff_info = cdm_buff_infos[id];
            if not buff_info then
                buff_info = { count = 1, id = id, player_owned = true };
                cdm_buff_infos[id] = buff_info;
            end
            kept[id] = buff_info;
            local lname = cdm_lnames[id];
            if lname == nil then
                lname = C_Spell.GetSpellName(id) or false;
                cdm_lnames[id] = lname;
            end
            if lname then
                loadout.dynamic_buffs_lname[unit][lname] = buff_info;
            end
        end
    end
end

-- player is scanned before target, an item active on the target has no aura on the player
local function cdm_restricted_buffs(loadout)
    local target_list;
    if UnitExists("target") and loadout.dynamic_buffs["target"] ~= loadout.dynamic_buffs["player"] then
        target_list = UnitIsFriend("player", "target") and "friendly" or "hostile";
    end
    for _, t in pairs(cdm_present) do
        wipe(t);
    end
    for _, t in pairs(cdm_absent) do
        wipe(t);
    end
    for _, name in ipairs(cdm_viewers) do
        local viewer = _G[name];
        if viewer and viewer.itemFramePool and viewer:IsVisible() then
            for item in viewer.itemFramePool:EnumerateActive() do
                local cooldown_id, active, unit = item.cooldownID, item.isActive, item.auraDataUnit;
                if cooldown_id and not any_secret(cooldown_id, active, unit) then
                    local c = cdm_candidates_of(cooldown_id);
                    if c then
                        local target_ids = target_list and c[target_list];
                        if not active then
                            table.insert(cdm_absent.player, c.player);
                            if target_ids then
                                table.insert(cdm_absent.target, target_ids);
                            end
                        elseif unit == "player" then
                            table.insert(cdm_present.player, c.player);
                        elseif unit == "target" then
                            table.insert(cdm_absent.player, c.player);
                            if target_ids then
                                table.insert(cdm_present.target, target_ids);
                            end
                        end
                    end
                end
            end
        end
    end
    cdm_apply(loadout, "player");
    if target_list then
        cdm_apply(loadout, "target");
    end
end

local scanned_units = { "player", "target" };
local scanned_units_mouseover = { "player", "target", "mouseover" };

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
    -- only a friendly mouseover's auras are used
    local units = scanned_units;
    if loadout.friendly_towards == "mouseover" then
        units = scanned_units_mouseover;
        if loadout.player_name == loadout.mouseover_name then
            loadout.dynamic_buffs["mouseover"] = loadout.dynamic_buffs["player"]
            loadout.dynamic_buffs_lname["mouseover"] = loadout.dynamic_buffs_lname["player"]
        end
        if loadout.target_name == loadout.mouseover_name then
            loadout.dynamic_buffs["mouseover"] = loadout.dynamic_buffs["target"]
            loadout.dynamic_buffs_lname["mouseover"] = loadout.dynamic_buffs_lname["target"]
        end
    end

    wipe(loadout.aura_guids);
    if should_auras_be_secret and should_auras_be_secret() then
        -- ignoring buffs leaves the cooldown manager's and the form, apply_snapshot_deltas takes the snapshot buffs
        -- out of the sheet stats
        if not (sc.config.settings.loadout_combat_ignore_buffs and client_matches(client_flags.forever)) then
            for _, k in ipairs(units) do
                keep_restricted_buffs(loadout, prev, k);
            end
        end
        if C_CooldownViewer then
            cdm_restricted_buffs(loadout);
        end
        restricted_form_buffs(loadout);
        loadout.snapshot_buffs = prev.snapshot_buffs;
        last_read_scanned = false;
        return;
    end

    for _, k in ipairs(units) do
        local v = loadout.dynamic_buffs[k];
        local guid = UnitGUID(k);
        -- a stored secret guid errors on the next compare
        if is_secret(guid) then
            guid = nil;
        end
        loadout.aura_guids[k] = guid;
        local shared = k ~= "player" and
            (v == loadout.dynamic_buffs["player"] or (k == "mouseover" and v == loadout.dynamic_buffs["target"]));
        if aura_changed[k] == false and last_read_scanned and not shared and
            guid and guid == prev.aura_guids[k] and not __spellcoda_test_all_data__ then

            for id, buff_info in pairs(prev.dynamic_buffs[k]) do
                v[id] = buff_info;
            end
            for lname, buff_info in pairs(prev.dynamic_buffs_lname[k]) do
                loadout.dynamic_buffs_lname[k][lname] = buff_info;
            end
        else
            if aura_changed[k] then
                aura_changed[k] = false;
            end
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
    end
    last_read_scanned = true;

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
