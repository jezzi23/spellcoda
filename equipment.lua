local _, sc = ...;

local attr                             = sc.attr;
local special_item_properties          = sc.special_item_properties;
local apply_effect                     = sc.loadouts.apply_effect;
local cpy_effects                      = sc.loadouts.cpy_effects;
---------------------------------------------------------------------------------------------------
local equipment = {};

local slots = {};
for _, v in ipairs({
    "AmmoSlot",
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot",
    "Bag0Slot",
    "Bag1Slot",
    "Bag2Slot",
    "Bag3Slot"
}) do
    slots[v] = GetInventorySlotInfo(v);
end

local inv_type_to_slot_ids = {
    INVTYPE_AMMO = { slots.AmmoSlot },
    INVTYPE_HEAD = { slots.HeadSlot },
    INVTYPE_NECK = { slots.NeckSlot },
    INVTYPE_SHOULDER = { slots.ShoulderSlot },
    INVTYPE_BODY = { slots.ShirtSlot },
    INVTYPE_CHEST = { slots.ChestSlot },
    INVTYPE_ROBE = { slots.ChestSlot },
    INVTYPE_WAIST = { slots.WaistSlot },
    INVTYPE_LEGS = { slots.LegsSlot },
    INVTYPE_FEET = { slots.FeetSlot },
    INVTYPE_WRIST = { slots.WristSlot },
    INVTYPE_HAND = { slots.HandsSlot },
    INVTYPE_FINGER = { slots.Finger0Slot, slots.Finger1Slot },
    INVTYPE_TRINKET = { slots.Trinket0Slot, slots.Trinket1Slot },
    INVTYPE_CLOAK = { slots.BackSlot },
    INVTYPE_WEAPON = { slots.MainHandSlot, slots.SecondaryHandSlot },
    INVTYPE_2HWEAPON = { slots.MainHandSlot },
    INVTYPE_WEAPONMAINHAND = { slots.MainHandSlot },
    INVTYPE_WEAPONOFFHAND = { slots.SecondaryHandSlot },
    INVTYPE_SHIELD = { slots.SecondaryHandSlot },
    INVTYPE_HOLDABLE = { slots.SecondaryHandSlot },
    INVTYPE_TABARD = { slots.TabardSlot },
    INVTYPE_RANGED = { slots.RangedSlot },
    INVTYPE_RANGEDRIGHT = { slots.RangedSlot },
    INVTYPE_RELIC = { slots.RangedSlot },
};


local wpn_strs = {
    [slots.MainHandSlot] = "mh",
    [slots.SecondaryHandSlot] = "oh",
    [slots.RangedSlot] = "ranged"
};

local function add_item_set_piece(num_set_pieces, item_id)
    local set_id = sc.set_items[item_id];
    if set_id then
        if not num_set_pieces[set_id] then
            num_set_pieces[set_id] = 0;
        end
        num_set_pieces[set_id] = num_set_pieces[set_id] + 1;
    end
end

local function detect_sets(loadout)

    for k, _ in pairs(sc.set_bonuses) do
        loadout.num_set_pieces[k] = 0;
    end

    for _, id in pairs(loadout.items) do
        add_item_set_piece(loadout.num_set_pieces, id);
    end
end

local function num_set_pieces(loadout, set_id)
    if loadout.num_set_pieces[set_id] then
        return loadout.num_set_pieces[set_id];
    else
        return 0;
    end
end

local GetItemStats = GetItemStats or C_Item.GetItemStats;

local function flat_add(val, forced, undo, attr_table, attr)
    if not forced then
        return;
    end
    if undo then
        val = -val;
    end
    attr_table[attr] = attr_table[attr] + val;
end

-- Generated spell effects handle most item effects but some require special handling
local item_stats_handler = {
    ITEM_MOD_INTELLECT_SHORT = function(effects, val, _, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.intellect);
    end,
    ITEM_MOD_SPIRIT_SHORT = function(effects, val, _, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.spirit);
    end,
    ITEM_MOD_STRENGTH_SHORT = function(effects, val, _, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.strength);
    end,
    ITEM_MOD_AGILITY_SHORT = function(effects, val, _, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.agility);
    end,
    ITEM_MOD_STAMINA_SHORT = function(effects, val, _, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.stamina);
    end,
};


local function apply_weapon(effects, id, slot, subclass_id, undo)

    local mod;
    if undo then
        mod = -1;
    else
        mod = 1;
    end

    -- Defaults to Fist weapon subclass which Unarmed skill line picks up on
    subclass_id = subclass_id or 13;
    effects.raw["wpn_subclass_"..wpn_strs[slot]] = effects.raw["wpn_subclass_"..wpn_strs[slot]] + mod*subclass_id;

    local wpn_effect = sc.weapons[id];
    if not wpn_effect then
        return;
    end

    effects.raw["wpn_min_"..wpn_strs[slot]] = effects.raw["wpn_min_"..wpn_strs[slot]] + mod*wpn_effect[1];
    effects.raw["wpn_max_"..wpn_strs[slot]] = effects.raw["wpn_max_"..wpn_strs[slot]] + mod*wpn_effect[2];
    effects.raw["wpn_delay_"..wpn_strs[slot]] = effects.raw["wpn_delay_"..wpn_strs[slot]] + mod*wpn_effect[3];
    if slot == slots.RangedSlot then
        effects.raw["wpn_school_"..wpn_strs[slot]] = effects.raw["wpn_school_"..wpn_strs[slot]] + mod*wpn_effect[4];
    end
end

local function apply_damage_enchant(effects, dmg_effect, slot, undo)
    local mod;
    if undo then
        mod = -1;
    else
        mod = 1;
    end
    effects.raw["wpn_min_"..wpn_strs[slot]] = effects.raw["wpn_min_"..wpn_strs[slot]] + mod*dmg_effect[1];
    effects.raw["wpn_max_"..wpn_strs[slot]] = effects.raw["wpn_max_"..wpn_strs[slot]] + mod*dmg_effect[2];
end

local function apply_ammo(effects, ammo_effect, undo)
    if not ammo_effect then
        return;
    end
    local mod;
    if undo then
        mod = -1;
    else
        mod = 1;
    end
    effects.raw.ammo_dps = effects.raw.ammo_dps + mod*ammo_effect[1];
end

local function apply_item_stats(effects, item_info, forced, undo)

    if not item_info.link then
        return;
    end
    local item_stats = GetItemStats(item_info.link);

    if item_stats then
        for k, v in pairs(item_stats) do
            if item_stats_handler[k] then
                item_stats_handler[k](effects, v, property, forced, undo);
            end
        end
    end
end

local gems_buffer = {};

local function apply_enchant(effects, enchant_id, forced, undo, slot)

    -- check for special +Damage enchant towards weapon slot which are not treated as aura effects
    if slot and wpn_strs[slot] and sc.damage_enchants[enchant_id] then
        apply_damage_enchant(effects, sc.damage_enchants[enchant_id], slot, undo);
    end

    if sc.enchants[enchant_id] then
        for _, effect_id in pairs(sc.enchants[enchant_id]) do
            apply_effect(effects, effect_id, sc.enchant_effects[effect_id], forced, 1.0, undo, false);
        end
    end
end

local function apply_gems(effects, forced, undo, item_id, gem1, gem2, gem3, gem4)

    local item_sockets = sc.item_sockets[item_id];
    if not item_sockets then
        return;
    end

    gems_buffer[1] = gem1;
    gems_buffer[2] = gem2;
    gems_buffer[3] = gem3;
    gems_buffer[4] = gem4;

    local socket_bonus_matched = true;

    for i = 1, 4 do
        local socket = item_sockets[i+1]; -- first index reserved for bonus id
        if not socket then
            break;
        end
        if not gems_buffer[i] then
            socket_bonus_matched = false;
        end

        local gem_item_id = gems_buffer[i];
        local gem_id = gem_item_id and sc.gem_items[gem_item_id];
        local gem = gem_id and sc.gems[gem_id];
        local ench = gem and sc.enchants[gem[1]];

        local gem_type = (gem and gem[2]) or 0;
        if bit.band(item_sockets[i+1], gem_type) == 0 then
            -- gem and socket color mismatch
            socket_bonus_matched = false;
        end
        if ench then
            for _, effect_id in pairs(ench) do
                apply_effect(effects, effect_id, sc.enchant_effects[effect_id], forced, 1.0, undo, false);
            end
        end
    end

    if socket_bonus_matched then
        local ench = sc.enchants[item_sockets[1]];
        if ench then
            for _, effect_id in pairs(ench) do
                apply_effect(effects, effect_id, sc.enchant_effects[effect_id], forced, 1.0, undo, false);
            end
        end
    end
end

local function wpn_skill_for_slot(loadout, effects, slot, weapon_subclass_id)

    local wpn_skill = 0;

    if not wpn_strs[slot] then
        return wpn_skill;
    end

    if weapon_subclass_id and loadout.wpn_skills[weapon_subclass_id] then
        wpn_skill = loadout.wpn_skills[weapon_subclass_id];
        for mask, v in pairs(effects.wpn_subclass.skill_flat) do
            if bit.band(mask, bit.lshift(1, weapon_subclass_id)) ~= 0 then
                wpn_skill = wpn_skill + v;
            end
        end
    end
    return wpn_skill;
end

local function apply_item_cmp(effects, item_info, slot, undo, should_apply_gems, should_apply_enchant)

    item_info.wpn_skill = 0;

    if sc.items[item_info.id] then
        for _, id in pairs(sc.items[item_info.id]) do
            if sc.item_effects[id] then
                apply_effect(effects, id, sc.item_effects[id], true, 1, undo, false)
            end
        end
    end

    apply_item_stats(effects, item_info, true, undo);

    if should_apply_gems then
        apply_gems(effects, true, undo, item_info.id,
                   item_info.gem1, item_info.gem2, item_info.gem3, item_info.gem4);
    end
    if should_apply_enchant and item_info.enchant_id then
        apply_enchant(effects, item_info.enchant_id, true, undo, slot);
    end

    if item_info.suffix_id and sc.suffix_ids[item_info.suffix_id] then
        for _, ench_id in pairs(sc.suffix_ids[item_info.suffix_id]) do
            if sc.enchants[ench_id] then
                for _, effect_id in pairs(sc.enchants[ench_id]) do
                    apply_effect(effects, effect_id, sc.enchant_effects[effect_id], true, 1, undo, false);
                end
            end
        end
    end

    if wpn_strs[slot] then
        apply_weapon(effects, item_info.id, slot, item_info.subclass_id, undo);

    elseif slot == slots.AmmoSlot then
        -- ammo
        apply_ammo(effects, sc.weapons[item_info.id], undo);
    end
end

local function apply_set_bonuses(num_set_pieces, effects, force, undo)

    for set_id, num in pairs(num_set_pieces) do
        if num > 1 then
            local bonuses = sc.set_bonuses[set_id];
            if bonuses then -- remove this check when old sets handling is gone
                for _, v in pairs(bonuses) do
                    local threshold = v[1];
                    local effect_id = v[2];
                    if num < threshold then
                        break;
                    end
                    apply_effect(effects, effect_id, sc.set_effects[effect_id], force, 1.0, undo);
                end
            end
        end
    end
end

local function apply_items_cmp(loadout, effects, new_items, old_items,
                               should_apply_gems, should_apply_enchant, should_apply_set_bonuses)

    for slot, new_info in pairs(new_items) do

        local old_info = old_items[slot];

        if old_info and old_info.id then
            -- Force undo on old item
            apply_item_cmp(effects, old_info, slot, true, should_apply_gems, should_apply_enchant)
        end
        -- Force apply new item
        apply_item_cmp(effects, new_info, slot, false, should_apply_gems, should_apply_enchant)
    end

    if should_apply_set_bonuses then

        local num_set_pieces_tmp = {};
        for slot, new_info in pairs(new_items) do

            local old_info = old_items[slot];
            if old_info and old_info.id then
                add_item_set_piece(num_set_pieces_tmp, old_info.id);
            end
        end
        -- negate old
        for set_id, num_pieces in pairs(num_set_pieces_tmp) do
            num_set_pieces_tmp[set_id] = -num_pieces;
        end
        -- add new
        for _, new_info in pairs(new_items) do

            add_item_set_piece(num_set_pieces_tmp, new_info.id);
        end

        -- combine with loadout set pieces
        for set_id, num_pieces_diff in pairs(loadout.num_set_pieces) do
            if not num_set_pieces_tmp[set_id] then
                num_set_pieces_tmp[set_id] = 0;
            end
            num_set_pieces_tmp[set_id] = num_set_pieces_tmp[set_id] + num_pieces_diff;
        end

        -- force undo active
        apply_set_bonuses(loadout.num_set_pieces, effects, true, true);
        -- force apply with changes
        apply_set_bonuses(num_set_pieces_tmp, effects, true, false);
    end
end

-- set through /sc force set [Set ID] [Number of pieces]
local force_item_sets = {};
-- set through /sc force item [Item ID]
local force_items = {};

local function apply_equipment(loadout, effects)

    for _, slot in pairs(slots) do
        loadout.items[slot] = GetInventoryItemID("player", slot);
        loadout.item_links[slot] = GetInventoryItemLink("player", slot);
    end
    detect_sets(loadout);

    local found_anything = false;

    apply_set_bonuses(loadout.num_set_pieces, effects, false, false);

    for force_set_id, force_threshold in pairs(force_item_sets) do
        local bonuses = sc.set_bonuses[force_set_id];
        local equipped_num_pieces = loadout.num_set_pieces[force_set_id];
        if bonuses then -- remove this check when old sets handling is gone
            for _, v in pairs(bonuses) do
                local threshold = v[1];
                local effect_id = v[2];
                if force_threshold < threshold then
                    break;
                end
                if not equipped_num_pieces or equipped_num_pieces < threshold then
                    apply_effect(effects, effect_id, sc.set_effects[effect_id], true, 1.0);
                end
            end
        end
        loadout.num_set_pieces[force_set_id] = force_threshold;
    end

    -- NOTE: Enchant changes might not force an equipment update
    -- enchants are tracked here because im some edge cases they may be hard referenced by id
    for k, v in pairs(loadout.enchants) do
        loadout.enchants[k] = nil;
    end

    -- NOTE: shortly after logging in, the equipment querying API won't work
    --       (but does for /reload). Track if we get nothing so we can signal
    --       that equipment scanning needs to be done again on next update

    for _, item in pairs(slots) do
        local item_link = loadout.item_links[item];
        local id = loadout.items[item];
        if item_link then
            if id and sc.items[id] then
                for _, effect_id in pairs(sc.items[id]) do
                    apply_effect(effects, effect_id, sc.item_effects[effect_id], false, 1.0);
                    --apply_item_stats(effects, item_info, false, false);
                end
            end
            found_anything = true;
            local _, enchant_id, gem1, gem2, gem3, gem4, suffix_id =
                strsplit(":", item_link:match("|Hitem:(.+)|h"));

            enchant_id = tonumber(enchant_id);
            if enchant_id then
                loadout.enchants[enchant_id] = 1;
                apply_enchant(effects, enchant_id, false, false, item);
            end

            apply_gems(effects, false, false, id,
                       tonumber(gem1), tonumber(gem2), tonumber(gem3), tonumber(gem4));

            suffix_id = tonumber(suffix_id);
            if suffix_id and sc.suffix_ids[suffix_id] then
                for _, ench_id in pairs(sc.suffix_ids[suffix_id]) do
                    apply_enchant(effects, ench_id, false, false, item);
                end
            end
        end
        if wpn_strs[item] then
            apply_weapon(effects,
                         id,
                         item,
                         item_link and select(13, GetItemInfo(item_link)),
                         false);
        end
    end
    if loadout.items[slots.AmmoSlot] and sc.weapons[loadout.items[slots.AmmoSlot]] then
        -- ammo equipped
        apply_ammo(effects, sc.weapons[loadout.items[slots.AmmoSlot]], false);
    end

    for id, _ in pairs(force_items) do
        if sc.items[id] then
            for _, effect_id in pairs(sc.items[id]) do
                apply_effect(effects, effect_id, sc.item_effects[effect_id], true, 1.0);
                --local lname, link = GetItemInfo(id);
                --apply_item_stats(effects, link, lname, false, false);
            end
        end
    end

    -- just do weapon enchants for now, are others even needed?
    local _, _, _, enchant_id = GetWeaponEnchantInfo();
    if sc.enchants[enchant_id] then
        loadout.enchants[enchant_id] = 1;

         -- may need to deal with weapon slots here instead of nil
        local slot = nil;
        apply_enchant(effects, enchant_id, false, false, slot);
    end

    if bit.band(sc.game_mode, sc.game_modes.season_of_discovery) ~= 0 then
        for _, i in pairs(slots) do
            local rune_slot = C_Engraving.GetRuneForEquipmentSlot(i);
            if rune_slot then
                local ench_id = rune_slot.itemEnchantmentID;
                if ench_id then
                    loadout.enchants[ench_id] = 1;
                    apply_enchant(effects, ench_id, false, false, nil);
                end
            end
        end
    end

    if __spellcoda_test_all_data__ then

        -- Testing all items
        local items_applied = 0;
        for _, v in pairs(sc.items) do
            for _, id in pairs(v) do
                apply_effect(effects, id, sc.item_effects[id], true, 1.0);
                items_applied = items_applied + 1;
            end
        end
        print(items_applied, "gen items applied");
        local sets_applied = 0;
        for k, v in pairs(sc.set_bonuses) do
            for _, bonus in pairs(v) do
                local id = bonus[2];

                apply_effect(effects, id, sc.set_effects[id], true, 1.0);
                sets_applied = sets_applied + 1;
            end
            loadout.num_set_pieces[k] = 100;
        end
        print(sets_applied, "gen sets applied");

        local enchants_applied = 0;
        for _, v in pairs(sc.enchants) do
            for _, id in pairs(v) do

                apply_effect(effects, id, sc.enchant_effects[id], true, 1.0);
                enchants_applied = enchants_applied + 1;
            end
        end
        print(enchants_applied, "gen enchants applied");

    end

    return found_anything;
end

---------------------------------------------------------------------------------------------------
equipment.num_set_pieces                = num_set_pieces;
equipment.apply_equipment               = apply_equipment;
equipment.force_item_sets               = force_item_sets;
equipment.force_items                   = force_items;
equipment.apply_items_cmp               = apply_items_cmp;
equipment.wpn_skill_for_slot            = wpn_skill_for_slot;
equipment.slots                         = slots;
equipment.inv_type_to_slot_ids          = inv_type_to_slot_ids;
equipment.write_item_info_from_link     = write_item_info_from_link;

sc.equipment = equipment;
