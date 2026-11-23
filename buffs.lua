local _, sc               = ...;

local apply_effect        = sc.loadouts.apply_effect;
local apply_proc          = sc.loadouts.apply_proc;
local apply_procs         = sc.loadouts.apply_procs;
local apply_enchant       = sc.equipment.apply_enchant;
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
-- seals that only proc (Vanilla / TBC Seal of Command) have no class_buffs entry, nor do Forever totem auras
for k, proc in pairs(sc.procs) do
    if (sc.spells[k] or proc.aura) and not sc.temp_enchant_spells[k] and not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
            lname = C_Spell.GetSpellName(k),
            cat = (proc.aura and buff_category.player) or buff_category.class,
        };
    end
end
for k, _ in pairs(sc.temp_enchant_spells) do
    if not unique_buffs[k] then
        unique_buffs[k] = {
            id = k,
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
local tracks_expiry = should_auras_be_secret ~= nil;
local unseen_buffs = sc.config.combat_unseen_buffs;
-- our own player auras: id -> duration as of the last unrestricted read
local pull_durations = {};

local function suppressed_in_raid(spell_id)
    local flag = sc.aura_flags.not_in_raid;
    local auras = sc.player_buffs[spell_id];
    if not flag or not auras or not sc.core.in_raid_instance then
        return false;
    end
    for _, aura in pairs(auras) do
        if bit.band(aura[sc.aura_idx_flags], flag) ~= 0 then
            return true;
        end
    end
    return false;
end

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

-- keeps the unit's buffs of the last unrestricted read while it is the same unit, with expire drops those whose time
-- ran out: every one on us, only our own on others
local function keep_restricted_buffs(loadout, prev, unit, expire)
    local guid = UnitGUID(unit);
    if is_secret(guid) or guid ~= prev.aura_guids[unit] then
        return;
    end
    loadout.aura_guids[unit] = guid;
    local kept = loadout.dynamic_buffs[unit];
    local on_player = kept == loadout.dynamic_buffs["player"];
    local expires = loadout.aura_expires[unit];
    local prev_expires = prev.aura_expires[unit];
    local now = GetTime();
    for id, buff_info in pairs(prev.detected_buffs[unit]) do
        local t = prev_expires[id];
        if not (expire and t and t ~= 0 and now >= t and (on_player or buff_info.player_owned)) then
            kept[id] = buff_info;
            expires[id] = t;
        end
    end
    for lname, buff_info in pairs(prev.detected_buffs_lname[unit]) do
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
-- entries of our own buffs per count, shared between reads and never changed
local own_buff_infos = {};
-- stacking auras our own casts add (aura_info stack_cast): base id of the cast -> aura, aura -> unit it is on
local stack_aura_of_cast = {};
local stack_aura_units = {};
-- stacks counted from our casts per aura, and the time of the last cast
local cast_stacks = {};
local cast_stacks_time = {};
local own_lnames = {};
local cdm_present = { player = {}, target = {} };
local cdm_absent = { player = {}, target = {} };

if client_matches(client_flags.forever) and C_CooldownViewer then
    for id, info in pairs(sc.aura_info) do
        if info.stack_cast then
            local unit = (sc.class_buffs[id] or sc.player_buffs[id]) and "player" or
                (sc.hostile_buffs[id] and "target");
            if unit then
                stack_aura_of_cast[info.stack_cast] = id;
                stack_aura_units[id] = unit;
            end
        end
    end
    local f = CreateFrame("Frame");
    f:RegisterEvent("SPELLS_CHANGED");
    f:RegisterEvent("PLAYER_TARGET_CHANGED");
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
    f:SetScript("OnEvent", function(_, event, _, _, spell_id)
        if event == "SPELLS_CHANGED" then
            wipe(cdm_candidates);
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- the new target's stacks are not known
            for id, unit in pairs(stack_aura_units) do
                if unit == "target" then
                    cast_stacks[id] = 0;
                end
            end
        elseif not is_secret(spell_id) then
            if sc.class_buffs[spell_id] or sc.player_buffs[spell_id] or
                sc.hostile_buffs[spell_id] or sc.friendly_buffs[spell_id] then
                cdm_last_cast[spell_id] = GetTime();
            end
            local spell = sc.spells[spell_id];
            local aura = spell and stack_aura_of_cast[spell.base_id];
            if aura then
                cast_stacks[aura] = math.min((cast_stacks[aura] or 0) + 1, sc.aura_info[aura].stacks);
                cast_stacks_time[aura] = GetTime();
            end
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

local function own_lname(id)
    local lname = own_lnames[id];
    if lname == nil then
        lname = C_Spell.GetSpellName(id) or false;
        own_lnames[id] = lname;
    end
    return lname;
end

local function add_own_buff(loadout, unit, id, count)
    count = count or 1;
    local infos = own_buff_infos[id];
    if not infos then
        infos = {};
        own_buff_infos[id] = infos;
    end
    local buff_info = infos[count];
    if not buff_info then
        buff_info = { count = count, id = id, player_owned = true };
        infos[count] = buff_info;
    end
    loadout.dynamic_buffs[unit][id] = buff_info;
    local lname = own_lname(id);
    if lname then
        loadout.dynamic_buffs_lname[unit][lname] = buff_info;
    end
end

-- our casts of player buffs that landed on us, applied by the next restricted read: { id, expires (0 = never) }
local own_casts = {};
-- the cast sent last, until it succeeds: guid, id, duration
local sent_guid, sent_id, sent_dur;

if tracks_expiry then
    local f = CreateFrame("Frame");
    f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player");
    f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
    f:SetScript("OnEvent", function(_, event, _, a, b, c)
        if event == "UNIT_SPELLCAST_SENT" then
            local target, cast_guid, id = a, b, c;
            sent_guid = nil;
            -- no target or our name is a cast on us, a secret target is unknown
            if any_secret(target, cast_guid, id) or (target and target ~= UnitName("player")) or
                not (sc.class_buffs[id] or sc.player_buffs[id]) then
                return;
            end
            local info = sc.aura_info[id];
            local dur;
            if info and info.dur_per_cp then
                local cp = UnitPower("player", sc.powers.combopoints);
                if is_secret(cp) then
                    cp = 0;
                end
                dur = (info.dur or 0) + info.dur_per_cp * cp;
            else
                dur = pull_durations[id] or (info and info.dur) or 0;
            end
            sent_guid, sent_id, sent_dur = cast_guid, id, dur;
        elseif sent_guid and not any_secret(a, b) and a == sent_guid and b == sent_id then
            sent_guid = nil;
            own_casts[#own_casts + 1] = { sent_id, sent_dur ~= 0 and GetTime() + sent_dur or 0 };
        end
    end);
end

-- a cast refreshes the entry of its rank chain (same name), another rank takes its place
local function apply_own_casts(loadout)
    local kept = loadout.dynamic_buffs["player"];
    local expires = loadout.aura_expires["player"];
    for _, cast in ipairs(own_casts) do
        local id = cast[1];
        local lname = own_lname(id);
        local same = lname and loadout.dynamic_buffs_lname["player"][lname];
        if same and same.id ~= id then
            remove_buff(loadout, "player", same.id);
            expires[same.id] = nil;
        end
        if not kept[id] then
            add_own_buff(loadout, "player", id);
        end
        expires[id] = cast[2];
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
            add_own_buff(loadout, unit, id);
        end
    end
end

-- stacks from our own casts on the auras the cooldown manager shows active; an inactive item resets the count, unless
-- a cast came within the last second (its aura may not be on the item yet)
local function apply_cast_stacks(loadout, unit)
    local now = GetTime();
    for _, ids in ipairs(cdm_absent[unit]) do
        for _, id in ipairs(ids) do
            if cast_stacks[id] and now - (cast_stacks_time[id] or 0) > 1 then
                cast_stacks[id] = 0;
            end
        end
    end
    local kept = loadout.dynamic_buffs[unit];
    for id, u in pairs(stack_aura_units) do
        local n = cast_stacks[id];
        if u == unit and n and n > 0 and kept[id] and kept[id].count ~= n then
            add_own_buff(loadout, unit, id, n);
        end
    end
end

-- the count of each stacking aura as read, the start for counting casts once auras turn secret
local function sync_cast_stacks(loadout)
    for id, unit in pairs(stack_aura_units) do
        local buff_info = loadout.dynamic_buffs[unit][id];
        cast_stacks[id] = buff_info and math.max(buff_info.count, 1) or 0;
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
    apply_cast_stacks(loadout, "player");
    if target_list then
        cdm_apply(loadout, "target");
        apply_cast_stacks(loadout, "target");
    end
end

local scanned_units = { "player", "target" };
local scanned_units_mouseover = { "player", "target", "mouseover" };

-- buffs the user assumes always up, merged over the detected ones; the next read copies only detected ones
local assumed_player_infos = {};
local assumed_target_infos = {};
local assumed_lnames = {};
local assumed_target_owned = {};
local assumed_was_active = false;
local merged_copies = {};

do
    local f = CreateFrame("Frame");
    f:RegisterEvent("SPELLS_CHANGED");
    f:SetScript("OnEvent", function()
        wipe(assumed_target_owned);
    end);
end

local function assumed_buffs_active()
    local settings = sc.config.settings;
    return settings.loadout_assume_buffs and
        (not settings.loadout_assume_buffs_only_combat or sc.core.in_combat) and
        (not settings.loadout_assume_buffs_only_raid or sc.core.in_raid_instance);
end

-- a changed entry is a new table, prev loadouts and the effects inputs compare against the old one
local function assumed_info(cache, id, count, player_owned)
    local buff_info = cache[id];
    if not buff_info or buff_info.count ~= count or buff_info.player_owned ~= player_owned then
        buff_info = { count = count, id = id, player_owned = player_owned };
        cache[id] = buff_info;
    end
    return buff_info;
end

local function assume_buff(loadout, unit, cache, id, count, player_owned)
    local present = loadout.dynamic_buffs[unit][id];
    if present and math.max(present.count or 0, 1) >= count then
        return;
    end
    local buff_info = assumed_info(cache, id, count, present and present.player_owned or player_owned);
    loadout.dynamic_buffs[unit][id] = buff_info;
    local lname = assumed_lnames[id];
    if lname == nil then
        lname = C_Spell.GetSpellName(id) or false;
        assumed_lnames[id] = lname;
    end
    if lname then
        loadout.dynamic_buffs_lname[unit][lname] = buff_info;
    end
end

local function target_owned(id)
    local owned = assumed_target_owned[id];
    if owned == nil then
        owned = IsPlayerSpell and IsPlayerSpell(id) and true or false;
        assumed_target_owned[id] = owned;
    end
    return owned;
end

local function merge_assumed_buffs(loadout)
    for _, k in ipairs(scanned_units_mouseover) do
        loadout.detected_buffs[k] = loadout.dynamic_buffs[k];
        loadout.detected_buffs_lname[k] = loadout.dynamic_buffs_lname[k];
    end
    loadout.assumed_hostile = nil;

    local active = assumed_buffs_active() and true or false;
    if active ~= assumed_was_active then
        assumed_was_active = active;
        sc.loadouts.force_update = true;
    end
    if not active then
        return;
    end

    -- one copy per detected table, units sharing one stay shared
    for _, k in ipairs(scanned_units_mouseover) do
        local detected = loadout.detected_buffs[k];
        local copy = merged_copies[detected];
        if not copy then
            copy = { {}, {} };
            for id, buff_info in pairs(detected) do
                copy[1][id] = buff_info;
            end
            for lname, buff_info in pairs(loadout.detected_buffs_lname[k]) do
                copy[2][lname] = buff_info;
            end
            merged_copies[detected] = copy;
        end
        loadout.dynamic_buffs[k] = copy[1];
        loadout.dynamic_buffs_lname[k] = copy[2];
    end
    wipe(merged_copies);

    local cfg = sc.config.settings.loadout_assumed_buffs;
    for id, count in pairs(cfg.player_buffs) do
        assume_buff(loadout, "player", assumed_player_infos, id, count, sc.class_buffs[id] ~= nil);
    end

    -- a friendly target gets no hostile ones, no target gets them on the default enemy
    local hostile_unit;
    if loadout.hostile_towards ~= "" and
        bit.band(loadout.flags, sc.loadouts.loadout_flags.target_friendly) == 0 then
        hostile_unit = loadout.hostile_towards;
    end
    for id, count in pairs(cfg.target_buffs) do
        if sc.friendly_buffs[id] then
            assume_buff(loadout, loadout.friendly_towards, assumed_target_infos, id, count, target_owned(id));
        end
        if sc.hostile_buffs[id] then
            if hostile_unit then
                assume_buff(loadout, hostile_unit, assumed_target_infos, id, count, target_owned(id));
            elseif loadout.hostile_towards == "" then
                loadout.assumed_hostile = loadout.assumed_hostile or {};
                loadout.assumed_hostile[id] = assumed_info(assumed_target_infos, id, count, target_owned(id));
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
    for _, k in ipairs(scanned_units_mouseover) do
        wipe(loadout.aura_expires[k]);
    end
    if should_auras_be_secret and should_auras_be_secret() then
        -- dropping buffs leaves the cooldown manager's and the form, apply_snapshot_deltas takes the snapshot buffs
        -- out of the sheet stats
        local mode = sc.config.settings.loadout_combat_unseen_buffs;
        if mode ~= unseen_buffs.drop then
            for _, k in ipairs(units) do
                keep_restricted_buffs(loadout, prev, k, mode == unseen_buffs.expire);
            end
            if mode == unseen_buffs.expire then
                apply_own_casts(loadout);
            end
        end
        wipe(own_casts);
        if C_CooldownViewer then
            cdm_restricted_buffs(loadout);
        end
        restricted_form_buffs(loadout);
        loadout.snapshot_buffs = prev.snapshot_buffs;
        last_read_scanned = false;
        merge_assumed_buffs(loadout);
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

            for id, buff_info in pairs(prev.detected_buffs[k]) do
                v[id] = buff_info;
            end
            for lname, buff_info in pairs(prev.detected_buffs_lname[k]) do
                loadout.dynamic_buffs_lname[k][lname] = buff_info;
            end
            for id, t in pairs(prev.aura_expires[k]) do
                loadout.aura_expires[k][id] = t;
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
                    if not is_secret(spell_id) and not suppressed_in_raid(spell_id) then
                        -- player owned takes priority
                        local player_owned = is_player_owned(aura);
                        if not v[spell_id] or player_owned then
                            local buff_info = { count = aura.applications, id = spell_id, player_owned = player_owned };
                            v[spell_id] = buff_info;
                            loadout.dynamic_buffs_lname[k][aura.name] = buff_info;
                            if tracks_expiry then
                                loadout.aura_expires[k][spell_id] = aura.expirationTime;
                                if k == "player" and player_owned then
                                    pull_durations[spell_id] = aura.duration;
                                end
                            end
                        end
                    end
                    i = i + 1;
                end
            end
        end
    end
    last_read_scanned = true;
    wipe(own_casts);
    sync_cast_stacks(loadout);

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
    merge_assumed_buffs(loadout);
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

-- an assumed weapon enchant (Windfury Weapon) as if on the main hand; a weapon enchant is no aura, the real one is
-- read from the weapon (equipment.lua), so the same enchant there is not added again
local function apply_assumed_temp_enchant(loadout, effects, spell_id, forced, undo)
    local enchant_id = sc.temp_enchant_spells[spell_id];
    if not enchant_id or enchant_id == loadout.temp_enchant_mh then
        return;
    end
    apply_enchant(effects, enchant_id, forced, undo, nil);
    apply_procs(effects, sc.enchant_procs[enchant_id], "mh", undo);
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
            -- seals and Forever totem auras only, the Windfury Totem buff 8516 also has a proc entry
            local proc = sc.procs[k];
            if proc and (sc.spells[k] or proc.aura) and not sc.temp_enchant_spells[k] then
                apply_proc(effects, k, proc.aura or "any", undo);
            end
            apply_assumed_temp_enchant(loadout, effects, k, forced, undo);
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
        elseif loadout.assumed_hostile then
            for k, v in pairs(loadout.assumed_hostile) do
                apply_effect(effects, k, sc.hostile_buffs[k], forced, v.count, undo, v.player_owned);
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
            if sc.temp_enchant_spells[k] then
                apply_assumed_temp_enchant(loadout, effects, k, true, false);
            elseif sc.procs[k] and (sc.spells[k] or sc.procs[k].aura) then
                apply_proc(effects, k, sc.procs[k].aura or "any", false);
            end
        end
    end
    for k, cnt in pairs(buffs_cfg.target_buffs) do
        if not preserve or
            (not loadout.dynamic_buffs[loadout.friendly_towards][k]
            and
            (loadout.hostile_towards == "" and not (loadout.assumed_hostile and loadout.assumed_hostile[k]) or
                loadout.hostile_towards ~= "" and not loadout.dynamic_buffs[loadout.hostile_towards][k])) then
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
