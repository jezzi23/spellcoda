local _, sc = ...;

local attr                             = sc.attr;
local aura_idx_effect                  = sc.aura_idx_effect;
local aura_idx_value                   = sc.aura_idx_value;
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

local one_hand_slots;
if sc.dual_wield_class then
    one_hand_slots = { slots.MainHandSlot, slots.SecondaryHandSlot };
else
    one_hand_slots = { slots.MainHandSlot };
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
    INVTYPE_WEAPON = one_hand_slots,
    INVTYPE_2HWEAPON = { slots.MainHandSlot },
    INVTYPE_WEAPONMAINHAND = { slots.MainHandSlot },
    INVTYPE_WEAPONOFFHAND = { slots.SecondaryHandSlot },
    INVTYPE_SHIELD = { slots.SecondaryHandSlot },
    INVTYPE_HOLDABLE = { slots.SecondaryHandSlot },
    INVTYPE_TABARD = { slots.TabardSlot },
    INVTYPE_RANGED = { slots.RangedSlot },
    INVTYPE_RANGEDRIGHT = { slots.RangedSlot },
    INVTYPE_RELIC = { slots.RangedSlot },
    INVTYPE_THROWN = { slots.RangedSlot },
};

local inv_type_to_rand_prop_points_index = {
    INVTYPE_HEAD           = 1,
    INVTYPE_CHEST          = 1,
    INVTYPE_ROBE           = 1,
    INVTYPE_LEGS           = 1,
    INVTYPE_2HWEAPON       = 1,
    INVTYPE_SHOULDER       = 2,
    INVTYPE_WAIST          = 2,
    INVTYPE_FEET           = 2,
    INVTYPE_HAND           = 2,
    INVTYPE_NECK           = 3,
    INVTYPE_WRIST          = 3,
    INVTYPE_FINGER         = 3,
    INVTYPE_CLOAK          = 3,
    INVTYPE_HOLDABLE       = 3,
    INVTYPE_SHIELD         = 3,
    INVTYPE_WEAPON         = 4,
    INVTYPE_WEAPONMAINHAND = 4,
    INVTYPE_WEAPONOFFHAND  = 4,
    INVTYPE_RANGED         = 5,
    INVTYPE_RANGEDRIGHT    = 5,
    INVTYPE_RELIC          = 5,
    INVTYPE_THROWN         = 5,
}


local wpn_strs = {
    [slots.MainHandSlot] = "mh",
    [slots.SecondaryHandSlot] = "oh",
    [slots.RangedSlot] = "ranged"
};

local function add_item_set_piece(effects, item_id, undo)

    local num_set_pieces = effects.num_set_pieces;
    local set_id = sc.set_items[item_id];
    if set_id then
        num_set_pieces[set_id] = num_set_pieces[set_id] or 0;
        if undo then
            num_set_pieces[set_id] = num_set_pieces[set_id] - 1;
        else
            num_set_pieces[set_id] = num_set_pieces[set_id] + 1;
        end
    end
end

local function num_set_pieces(effects, set_id)
    if effects.num_set_pieces[set_id] then
        return effects.num_set_pieces[set_id];
    else
        return 0;
    end
end

local function has_enchant(effects, enchant_id)
    local ench = effects.enchants[enchant_id];
    return ench and ench ~= 0;
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
    ITEM_MOD_INTELLECT_SHORT = function(effects, val, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.intellect);
    end,
    ITEM_MOD_SPIRIT_SHORT = function(effects, val, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.spirit);
    end,
    ITEM_MOD_STRENGTH_SHORT = function(effects, val, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.strength);
    end,
    ITEM_MOD_AGILITY_SHORT = function(effects, val, forced, undo)
        flat_add(val, forced, undo, effects.by_attr.stat_flat, attr.agility);
    end,
    ITEM_MOD_STAMINA_SHORT = function(effects, val, forced, undo)
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


    --if not subclass_id then
    --    if wpn_effect then
    --        -- defaults to Fist weapon subclass which Unarmed skill line picks up on
    --        subclass_id = 13;
    --    else
    --        -- empty slot
    --        subclass_id = 0;
    --    end
    --end
    subclass_id = subclass_id or 13;
    effects.raw["wpn_subclass_"..wpn_strs[slot]] = effects.raw["wpn_subclass_"..wpn_strs[slot]] + mod*subclass_id;

    if not id then
        return;
    end

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

local function apply_armor(effects, item_id, undo)
    local armor = sc.armor[item_id];
    if not armor then
        return;
    end
    local mod
    if undo then
        mod = -1;
    else
        mod = 1;
    end
    effects.raw.base_res_phys_flat = effects.raw.base_res_phys_flat + mod*armor;
end

local function apply_item_stats(effects, item_info, forced, undo)

    if not item_info.link then
        return nil;
    end
    local item_stats = GetItemStats(item_info.link);

    if item_stats then
        for k, v in pairs(item_stats) do
            if item_stats_handler[k] then
                item_stats_handler[k](effects, v, forced, undo);
            end
        end
    end
    return item_stats;
end

local gems_buffer = {};

local function apply_enchant(effects, enchant_id, forced, undo, slot)
    if not enchant_id then
        return;
    end

    effects.enchants[enchant_id] = effects.enchants[enchant_id] or 0;
    if undo then
        effects.enchants[enchant_id] = effects.enchants[enchant_id] - 1;
    else
        effects.enchants[enchant_id] = effects.enchants[enchant_id] + 1;
    end

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

local function apply_item_cmp(effects, item_info, slot, undo, should_apply_gems, should_apply_enchant, shapeshift)

    item_info.wpn_skill = 0;

    if wpn_strs[slot] then
        -- need to be able to reset unarmed subclass here even if no item id
        apply_weapon(effects, item_info.id, slot, item_info.subclass_id, undo);
    end

    if not item_info.id then
        return;
    end

    if item_info.class_id == 4 and item_info.subclass_id == 6 then
        -- shields
        if undo then
            effects.raw.can_block = effects.raw.can_block - 1;
        else
            effects.raw.can_block = effects.raw.can_block + 1;
        end
    end

    if sc.items[item_info.id] then
        for _, id in pairs(sc.items[item_info.id]) do
            if sc.item_effects[id] then
                apply_effect(
                    effects,
                    id,
                    sc.item_effects[id],
                    true,
                    1,
                    undo,
                    false,
                    shapeshift
                );
            end
        end
    end

    local item_stats = apply_item_stats(effects, item_info, true, undo);

    if should_apply_gems then
        apply_gems(effects, true, undo, item_info.id,
                   item_info.gem1, item_info.gem2, item_info.gem3, item_info.gem4);
    end
    if should_apply_enchant and item_info.enchant_id then
        apply_enchant(effects, item_info.enchant_id, true, undo, slot);
    end

    if item_info.suffix_id and sc.suffix_ids[item_info.suffix_id] then
        for ench_idx, ench_id in pairs(sc.suffix_ids[item_info.suffix_id]) do
            if sc.enchants[ench_id] then
                for _, effect_id in pairs(sc.enchants[ench_id]) do

                    local enchant_effects = sc.enchant_effects[effect_id];

                    -- suffix auras always have only 1 entry if any

                    if item_info.suffix_id < 0 and #enchant_effects > 0 then

                        -- suffixes with negative ID behave differently and scale with ilvl depending on
                        -- item type, ilvl and quality

                        -- various checks needed which could theoretically fail out in the wild
                        local value = (
                            item_info.inv_type and
                            item_info.ilvl and
                            item_info.quality and
                            sc.ilvl_to_quality_rand_prop_points[item_info.ilvl] and
                            sc.ilvl_to_quality_rand_prop_points[item_info.ilvl][item_info.quality] and
                            inv_type_to_rand_prop_points_index[item_info.inv_type] and
                                math.floor(
                                    sc.ilvl_to_quality_rand_prop_points[item_info.ilvl][math.max(2, math.min(4, item_info.quality))][
                                        inv_type_to_rand_prop_points_index[item_info.inv_type]
                                    ]
                                    *
                                    sc.random_suffix_allocation_pct[item_info.suffix_id][ench_idx]
                                )
                        ) or 0;

                        local prev_values = {};
                        for i, aura in ipairs(enchant_effects) do
                            if aura[aura_idx_effect] ~= "stat_flat" then
                                -- flat stats gets populated in GetItems, deal with others
                                prev_values[i] = aura[aura_idx_value];
                                aura[aura_idx_value] = value;
                            end
                        end
                        apply_effect(effects, effect_id, enchant_effects, true, 1, undo, false);
                        for i, prev in pairs(prev_values) do
                            enchant_effects[i][aura_idx_value] = prev;
                        end

                    else
                        apply_effect(effects, effect_id, enchant_effects, true, 1, undo, false);
                    end


                end
            end
        end
    end
    apply_armor(effects, item_info.id, undo);

    if slot == slots.AmmoSlot then
        -- ammo
        apply_ammo(effects, sc.weapons[item_info.id], undo);
    end
end

local function apply_set_bonuses(effects, force, undo, shapeshift)

    for set_id, num in pairs(effects.num_set_pieces) do
        if num > 1 then
            local bonuses = sc.set_bonuses[set_id];
            if bonuses then -- remove this check when old sets handling is gone
                for _, v in pairs(bonuses) do
                    local threshold = v[1];
                    local effect_id = v[2];
                    if num < threshold then
                        break;
                    end

                    apply_effect(
                        effects,
                        effect_id,
                        sc.set_effects[effect_id],
                        force,
                        1.0,
                        undo,
                        nil,
                        shapeshift
                    );
                end
            end
        end
    end
end

local function apply_items_cmp(loadout, effects, new_items, old_items,
                               should_apply_gems, should_apply_enchant, should_apply_set_bonuses)


    local shapeshift = sc.class == sc.classes.druid and effects.raw.class_misc ~= 0;

    for slot, new_info in pairs(new_items) do

        local old_info = old_items[slot];

        --if old_info and old_info.id then
        if old_info then
            -- Force undo on old item
            apply_item_cmp(effects, old_info, slot, true, should_apply_gems, should_apply_enchant, shapeshift)
        end
        -- Force apply new item
        --if new_info.id then
        --    apply_item_cmp(effects, new_info, slot, false, should_apply_gems, should_apply_enchant, shapeshift)
        --end
        apply_item_cmp(effects, new_info, slot, false, should_apply_gems, should_apply_enchant, shapeshift)
    end

    if should_apply_set_bonuses then

        -- force undo active
        apply_set_bonuses(effects, true, true, shapeshift);

        for slot, new_info in pairs(new_items) do
            local old_info = old_items[slot];
            if old_info and old_info.id then
                add_item_set_piece(effects, old_info.id, true);
            end
        end

        for _, new_info in pairs(new_items) do
            if new_info.id then
                add_item_set_piece(effects, new_info.id, false);
            end
        end

        -- force apply with changes
        apply_set_bonuses(effects, true, false, shapeshift);
    end
end

local function apply_equipment(loadout, effects)

    for _, slot in pairs(slots) do
        loadout.items[slot] = GetInventoryItemID("player", slot);
        loadout.item_links[slot] = GetInventoryItemLink("player", slot);
    end

    for _, id in pairs(loadout.items) do
        add_item_set_piece(effects, id, false);
    end

    local found_anything = false;

    apply_set_bonuses(effects, false, false);

    -- NOTE: Enchant changes might not force an equipment update
    -- enchants are tracked here because im some edge cases they may be hard referenced by id

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
            apply_enchant(effects, enchant_id, false, false, item);

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
            local wpn_subclass = item_link and select(7, GetItemInfoInstant(item_link));
            if item_link and not wpn_subclass then
                found_anything = false;
            end

            apply_weapon(effects,
                         id,
                         item,
                         wpn_subclass,
                         false);
        end
    end
    if loadout.items[slots.AmmoSlot] and sc.weapons[loadout.items[slots.AmmoSlot]] then
        -- ammo equipped
        apply_ammo(effects, sc.weapons[loadout.items[slots.AmmoSlot]], false);
    end
    local offhand_link = loadout.item_links[slots.SecondaryHandSlot];
    if offhand_link then
        local _, _, _, _, _, class_id, subclass_id = GetItemInfoInstant(offhand_link);
        if class_id == 4 and subclass_id == 6 then
            -- shield
            effects.raw.can_block = effects.raw.can_block + 1;
        end
    end

    local _, _, _, enchant_id = GetWeaponEnchantInfo();
    if sc.enchants[enchant_id] then
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
                apply_effect(effects, id, sc.item_effects[id], true, 1.0, false, true, true);
                items_applied = items_applied + 1;
            end
        end
        print(items_applied, "gen items applied");
        local sets_applied = 0;
        for k, v in pairs(sc.set_bonuses) do
            for _, bonus in pairs(v) do
                local id = bonus[2];

                apply_effect(effects, id, sc.set_effects[id], true, 1.0, false, true, true);
                sets_applied = sets_applied + 1;
            end
        end
        print(sets_applied, "gen sets applied");

        local enchants_applied = 0;
        for k, v in pairs(sc.enchants) do
            for _, id in pairs(v) do

                effects.enchants[k] = 1;
                apply_effect(effects, id, sc.enchant_effects[id], true, 1.0, false, true, true);
                enchants_applied = enchants_applied + 1;
            end
        end
        print(enchants_applied, "gen enchants applied");
    end

    return found_anything;
end

---------------------------------------------------------------------------------------------------
equipment.num_set_pieces                = num_set_pieces;
equipment.has_enchant                   = has_enchant;
equipment.apply_equipment               = apply_equipment;
equipment.apply_items_cmp               = apply_items_cmp;
equipment.wpn_skill_for_slot            = wpn_skill_for_slot;
equipment.slots                         = slots;
equipment.inv_type_to_slot_ids          = inv_type_to_slot_ids;
equipment.write_item_info_from_link     = write_item_info_from_link;

sc.equipment = equipment;
