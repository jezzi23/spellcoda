local _, sc = ...;

local L                               = sc.L;
local clear_table                     = sc.utils.clear_table;
local client_matches                  = sc.utils.client_matches;
local is_secret                       = sc.utils.is_secret;
local client_flags                    = sc.client_flags;
local write_item_info_from_link       = sc.utils.write_item_info_from_link;
local request_item_data               = sc.utils.request_item_data;
local wowhead_talent_link             = sc.talents.wowhead_talent_link;
local wowhead_talent_code_from_url    = sc.talents.wowhead_talent_code_from_url;
local inv_type_to_slot_ids            = sc.equipment.inv_type_to_slot_ids;
local apply_items_cmp                 = sc.equipment.apply_items_cmp;
local slots                           = sc.equipment.slots;
local update_loadout_and_effects      = sc.loadouts.update_loadout_and_effects;
local active_loadout                  = sc.loadouts.active_loadout
local stats_diff_format               = sc.loadouts.stats_diff_format;
local stats_format                    = sc.loadouts.stats_format;
local cpy_effects                     = sc.loadouts.cpy_effects;
local effects_finalize_forced         = sc.loadouts.effects_finalize_forced;
local empty_effects                   = sc.loadouts.empty_effects;
local buff_category                   = sc.buffs.buff_category;
local buffs                           = sc.buffs.buffs;
local target_buffs                    = sc.buffs.target_buffs;
local stat_diffs_included_effects_str = sc.tooltip.stat_diffs_included_effects_str;
local plan_spells_text                = sc.tooltip.plan_spells_text;
local write_plan_spells_tooltip       = sc.tooltip.write_plan_spells_tooltip;
local config                          = sc.config;

local ui = sc.ui;
local buff_categories_colors = ui.buff_categories_colors;
local create_subtabs         = ui.create_subtabs;
local dump_text              = ui.dump_text;
local editbox_config         = ui.editbox_config;
local font                   = ui.font;
local libDD                  = ui.libDD;
local make_divider           = ui.make_divider;


local default_talents_plan = {
    use_custom = false,
    custom_code = "_",
};
local default_buffs_plan = {
    use_custom = false,
    preserve_active = true,
    player_buffs = {},
    target_buffs = {},
};

local working_item_plan = {};
local working_stats = sc.loadouts.manual_effects_zero_diff();
local working_talents = sc.utils.deep_table_copy(default_talents_plan);
local working_buffs = sc.utils.deep_table_copy(default_buffs_plan);
local forced_buffs_lname_to_id = {};
local working_name = "";

local function item_planner_add_slot(item_link)

    local inv_loc = select(4, C_Item.GetItemInfoInstant(item_link));
    if not inv_loc then
        return false;
    end
    local item_slots = inv_type_to_slot_ids[inv_loc];
    if not item_slots then
        return false;
    end
    local viable_slots = __sc_frame.calculator_frame.items.slots;

    local dst_slot;
    if viable_slots[item_slots[1]] then -- index 1 should always exist
        dst_slot = item_slots[1];
    end
    if item_slots[2] and
        viable_slots[item_slots[2]] and
        working_item_plan[item_slots[1]] and
        not working_item_plan[item_slots[2]] then

        dst_slot = item_slots[2];
    end

    if dst_slot then


        working_item_plan[dst_slot] = working_item_plan[dst_slot] or {};
        if not write_item_info_from_link(working_item_plan[dst_slot], item_link) then
            working_item_plan[dst_slot] = nil;
            return false;
        end
        if inv_loc == "INVTYPE_2HWEAPON" then
            -- 2H knocks out offhand
            working_item_plan[slots.SecondaryHandSlot] = {};
        elseif
            inv_loc == "INVTYPE_WEAPONOFFHAND" or
            inv_loc == "INVTYPE_SHIELD"  or
            inv_loc == "INVTYPE_HOLDABLE"  or
            (inv_loc == "INVTYPE_WEAPON" and dst_slot == slots.SecondaryHandSlot) then

            -- offhand knocks out 2H

            local mh = working_item_plan[slots.MainHandSlot];
            if mh and mh.link and select(4, C_Item.GetItemInfoInstant(mh.link)) == "INVTYPE_2HWEAPON" then

                working_item_plan[slots.MainHandSlot] = {};
            end
        end

        return true;
    end
    return false
end

local function update_calculator_item_frame(frame, allow_empty)

    local link = frame.link;
    local quality, tex, ilvl;

    if link then
        _, _, quality, ilvl, _, _, _, _, _, tex = C_Item.GetItemInfo(link);
    end

    if tex and quality then
        frame.icon:SetTexture(tex);
        frame.ilvl_fstr:SetText(tostring(ilvl or 0));
        frame.icon:Show();
        frame.ilvl_fstr:Show();

        if quality and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality];
            --frame.bg:SetVertexColor(c.r, c.g, c.b, 1);
            frame.border:SetVertexColor(c.r, c.g, c.b, 1);
            frame.ilvl_fstr:SetTextColor(c.r, c.g, c.b, 1);
        else
            --frame.bg:SetVertexColor(1, 1, 1, 1);
            frame.border:Hide();
            frame.ilvl_fstr:SetTextColor(1, 1, 1, 1);
        end
    else
        frame.icon:Hide();
        frame.ilvl_fstr:Hide();
        if allow_empty then
            local c = ITEM_QUALITY_COLORS[0];
            frame.border:SetVertexColor(c.r, c.g, c.b, 1);
        else
            frame.border:Hide();
        end
        --frame.border:SetVertexColor(1, 1, 1, 1);
        --frame.bg:Show();
    end
end

local plan_model_hands = {
    { slot = slots.MainHandSlot, name = "MAINHANDSLOT" },
    { slot = slots.SecondaryHandSlot, name = "SECONDARYHANDSLOT" },
};
local plan_model_weapon_slots = {
    [slots.MainHandSlot] = true,
    [slots.SecondaryHandSlot] = true,
    [slots.RangedSlot] = true,
    [slots.AmmoSlot] = true,
};

-- the weapon in a slot with the plan applied, nil when the slot ends up empty
local function plan_weapon_link(slot)
    local info = working_item_plan[slot];
    if info then
        return info.link;
    end
    return GetInventoryItemLink("player", slot);
end

local function is_two_hand(link)
    return link ~= nil and select(4, C_Item.GetItemInfoInstant(link)) == "INVTYPE_2HWEAPON";
end

-- the plan on the character: the worn gear, then each planned item tried on or its slot emptied; the weapons last,
-- the hands as they end up and the ranged weapon only with both hands empty (trying it on takes a hand)
local function update_plan_model(model, anything)
    model:SetShown(anything);
    if not anything then
        return;
    end
    model:SetUnit("player");
    for slot, info in pairs(working_item_plan) do
        if not plan_model_weapon_slots[slot] then
            if info.link then
                model:TryOn(info.link);
            else
                model:UndressSlot(slot);
            end
        end
    end

    local hand_links = {
        plan_weapon_link(slots.MainHandSlot),
        plan_weapon_link(slots.SecondaryHandSlot),
    };
    -- a planned 2H knocks out the off hand, a planned off hand knocks out a worn 2H
    if working_item_plan[slots.MainHandSlot] and not working_item_plan[slots.SecondaryHandSlot] and
        is_two_hand(hand_links[1]) then
        hand_links[2] = nil;
    elseif working_item_plan[slots.SecondaryHandSlot] and hand_links[2] and
        not working_item_plan[slots.MainHandSlot] and is_two_hand(hand_links[1]) then
        hand_links[1] = nil;
    end
    for i, hand in ipairs(plan_model_hands) do
        if hand_links[i] then
            model:TryOn(hand_links[i], hand.name);
        else
            model:UndressSlot(hand.slot);
        end
    end
    if not hand_links[1] and not hand_links[2] then
        local ranged_link = plan_weapon_link(slots.RangedSlot);
        if ranged_link then
            model:TryOn(ranged_link);
        end
    end
end

local function update_calculator_character_items(slot)

    __sc_frame.calculator_frame.calculator_plan_changed = true;
    if not slot then
        for s, v in pairs(__sc_frame.calculator_frame.items.slots) do

            v.old.link = GetInventoryItemLink("player", s);
            update_calculator_item_frame(v.old);
            if not v.new.link then
                if v.old.link then
                    v.cancel:Show();
                    v.cancel:SetText("-");
                else
                    v.cancel:Hide();
                    v.cancel:SetText("x");
                end
            end
        end
    else
        local v = __sc_frame.calculator_frame.items.slots[slot];
        v.old.link = GetInventoryItemLink("player", slot);
        update_calculator_item_frame(v.old);
        if not v.new.link then
            if v.old.link then
                v.cancel:Show();
                v.cancel:SetText("-");
            else
                v.cancel:Hide();
                v.cancel:SetText("x");
            end
        end
    end
    -- the worn gear under the plan changed
    update_plan_model(__sc_frame.calculator_frame.items.plan_model, next(working_item_plan) ~= nil);
end

-- gems
local function update_item_plan_slot_gems(frames, slot_info)

    for _, v in pairs(frames.gems) do
        v.gem_item_id = 0;
        v:Hide();
    end
    frames.gems_match.id = 0;
    frames.gems_match:Hide();

    -- Update gem frames
    local item_sockets = sc.item_sockets[slot_info.id];
    if not item_sockets then
        return;
    end

    local socket_bonus_matched = true;

    for i = 1, 3 do
        local socket_color = item_sockets[i+1]; -- first index reserved for bonus id
        if not socket_color then
            break;
        end

        if socket_color == sc.gem_type_flags.red then
            frames.gems[i].bg:SetVertexColor(1.0, 0.0, 0.0);
        elseif socket_color == sc.gem_type_flags.yellow then
            frames.gems[i].bg:SetVertexColor(1.0, 1.0, 0.0);
        elseif socket_color == sc.gem_type_flags.blue then
            frames.gems[i].bg:SetVertexColor(0.0, 0.5, 1.0);
        else
            -- meta
            frames.gems[i].bg:SetVertexColor(0.6, 0.6, 0.6);
        end

        frames.gems[i]:Show();

        local gem_item_id = slot_info["gem"..i];
        if not gem_item_id then
            socket_bonus_matched = false;
            frames.gems[i].icon:Hide();
        else
            frames.gems[i].gem_item_id = gem_item_id;
            local tex = select(10, C_Item.GetItemInfo(gem_item_id));
            frames.gems[i].icon:SetTexture(tex);
            frames.gems[i].icon:Show();
        end

        local gem_id = gem_item_id and sc.gem_items[gem_item_id];
        local gem = gem_id and sc.gems[gem_id];

        local gem_type = (gem and gem[2]) or 0;
        if bit.band(socket_color, gem_type) == 0 then
            -- gem and socket color mismatch
            socket_bonus_matched = false;
        end
    end

    if socket_bonus_matched and item_sockets[1] then
        frames.gems_match.id = item_sockets[1];
        frames.gems_match:Show();
    else
        frames.gems_match:Hide();
    end
end

-- bridge between active item plan and corresponding UI elements
local function update_calculator_item_planner()

    local pframe = __sc_frame.calculator_frame;
    pframe.calculator_plan_changed = true;

    local frame_slots = pframe.items.slots;

    local anything = false;
    for slot, v in pairs(frame_slots)  do

        if working_item_plan[slot] then
            local slot_info = working_item_plan[slot];
            anything = true;
            v.new.link = slot_info.link;
            update_calculator_item_frame(v.new, true);

            v.arrow:Show();
            v.new:Show();
            v.cancel:Show();
            v.cancel:SetText("x");
            v.enchant:Show();

            update_item_plan_slot_gems(v, slot_info);

            if slot_info.enchant_id then
                v.enchant.enchant_id = slot_info.enchant_id;
                v.enchant.icon:Show();
            elseif v.new.link then
                v.enchant.enchant_id = 0;
                v.enchant.icon:Hide();
            else
                v.enchant:Hide();
            end

            v.old.icon:SetAlpha(0.2);
            if v.old.link then
                v.old.bg:Hide();
            else
                v.old.bg:Show();
            end
        else
            v.new.link = nil;
            v.arrow:Hide();
            v.new:Hide();

            if v.old.link then
                v.cancel:Show();
                v.cancel:SetText("-");
            else
                v.cancel:Hide();
            end

            for k, vv in pairs(v.gems) do
                vv:Hide();
            end
            v.enchant:Hide();

            v.old.icon:SetAlpha(1);
            v.old.bg:Show();
        end
    end
    pframe.items_tab:set_changed(anything);
    pframe.items.item_add_tip:SetShown(not anything);
    update_plan_model(pframe.items.plan_model, anything);
end

local function update_talents_frame()

    local pframe =  __sc_frame.calculator_frame;
    local talents_frame =  pframe.talents;

    talents_frame.custom_talents_chk:SetChecked(working_talents.use_custom);
    pframe.talents_tab:set_changed(working_talents.use_custom);

    -- trigger editbox update
    talents_frame.talent_editbox:SetText("");
    talents_frame.talent_editbox:SetText(wowhead_talent_link(working_talents.custom_code));
end

local function update_buffs_frame(buffs_frame)

    sc.loadouts.force_update = true;

    local buffs_list_alpha;

    if buffs_frame.list_enabled() then
        buffs_list_alpha = 1.0;
    else
        buffs_list_alpha = 0.2;
    end
    if buffs_frame.on_update then
        buffs_frame.on_update();
    end

    local cfg = buffs_frame.buffs_cfg();

    for _, view in ipairs(buffs_frame.views) do

        local n = #view.filtered;
        local config_buffs = cfg[view.cfg_key];

        buffs_frame[view.side].select_all_buffs_checkbutton:SetChecked(next(config_buffs) ~= nil);

        for _, v in ipairs(buffs_frame[view.side].buffs) do
            v.checkbutton:Hide();
            v.checkbutton.__stacks_str:Hide();
            v.icon:Hide();
        end

        local buff_frame_idx = math.floor(buffs_frame[view.side].slider:GetValue());

        for _, v in ipairs(buffs_frame[view.side].buffs) do

            if buff_frame_idx > n then
                break;
            end
            local buff_info = view.buffs[view.filtered[buff_frame_idx]];
            v.checkbutton.buff_id = buff_info.id;

            if config_buffs[buff_info.id] then
                v.checkbutton:SetChecked(true);
                v.checkbutton.__stacks_str:SetText(tostring(config_buffs[buff_info.id]));
            else
                v.checkbutton:SetChecked(false);
                v.checkbutton.__stacks_str:SetText("0");
            end

            v.icon.tex:SetTexture((C_Spell.GetSpellTexture(buff_info.id)));

            local buff_name_max_len = 28;
            local name_appear =  buff_info.lname;
            getglobal(v.checkbutton:GetName() .. 'Text'):SetText(name_appear:sub(1, buff_name_max_len));
            local checkbutton_txt = getglobal(v.checkbutton:GetName() .. 'Text');

            local color = buff_categories_colors[buff_info.cat];
            checkbutton_txt:SetTextColor(color[1], color[2], color[3]);

            v.checkbutton:Show();
            v.checkbutton.__stacks_str:Show();
            v.icon:Show();

            buff_frame_idx = buff_frame_idx + 1;
        end
        buffs_frame[view.side].frame:SetAlpha(buffs_list_alpha);
    end
    for _, v in ipairs(buffs_frame.fadeable_checkboxes) do
        v:SetAlpha(buffs_list_alpha);
    end
end

local function effects_from_ui_stats_diff()

    local pframe = __sc_frame.calculator_frame;
    local frame = pframe.stats;
    local stats = frame.stat_fields;

    for k, v in pairs(stats) do
        working_stats[k] = 0;
    end

    -- Manual stats diff

    -- verify validity and run input expr 
    for _, v in pairs(stats) do

        local expr_str = v.editbox:GetText();

        local is_whitespace_expr = expr_str and string.match(expr_str, "%S") == nil;
        local is_valid_expr = string.match(expr_str, "[^-+0123456789. ()]") == nil

        local expr = nil;
        if is_valid_expr then
            expr = loadstring("return "..expr_str..";");
            if expr then
                v.editbox_val = expr();
                frame.is_valid = true;
            end
        end
        if is_whitespace_expr or not is_valid_expr or not expr then

            v.editbox_val = 0;
            if not is_whitespace_expr then
                frame.is_valid = false;
                return working_stats;
            end
        end
    end

    local anything = false;
    for k, v in pairs(stats) do
        local val = v.editbox_val;
        if val ~= 0 then
            anything = true;
        end
        working_stats[k] = val;
    end
    pframe.stats_tab:set_changed(anything);

    frame.is_valid = true;

    return working_stats;
end

local function load_calculator_plan(plan)

    local pframe = __sc_frame.calculator_frame;

    clear_table(working_item_plan);
    for slot, v in pairs(plan.items) do
        -- do deep copy
        working_item_plan[slot] = {};
        for kk, vv in pairs(v) do
            working_item_plan[slot][kk] = vv;
        end
    end

    for stats_key, v in pairs(pframe.stats.stat_fields) do
        if plan.stats[stats_key] then
            v.editbox:SetText(plan.stats[stats_key]);
        else
            v.editbox:SetText("");
        end
    end

    for k, v in pairs(default_talents_plan) do
        if not plan.talents[k] then
            working_talents[k] = v;
        else
            working_talents[k] = plan.talents[k];
        end
    end
    for k, v in pairs(default_buffs_plan) do
        if type(v) == "table" then
            working_buffs[k] = {};
            if plan.buffs[k] then
                for kk, vv in pairs(plan.buffs[k]) do
                    working_buffs[k][kk] = vv;
                end
            end
        else
            if plan.buffs[k] == nil then
                working_buffs[k] = v;
            else
                working_buffs[k] = plan.buffs[k];
            end
        end
    end
    wipe(forced_buffs_lname_to_id);
    for _, cfg_key in ipairs({"player_buffs", "target_buffs"}) do
        for id in pairs(working_buffs[cfg_key]) do
            local lname = C_Spell.GetSpellName(id);
            if lname then
                forced_buffs_lname_to_id[lname] = id;
            end
        end
    end
    update_talents_frame();
    update_buffs_frame(pframe.buffs);
end

local function save_calculator_plan(plan_name)
    if plan_name == "" then
        return;
    end
    local pframe = __sc_frame.calculator_frame;

    local plan = {items = {}, stats = {}, talents = {}, buffs = {}};

    -- items
    for k, v in pairs(working_item_plan) do
        plan.items[k] = {};
        for kk, vv in pairs(v) do
            plan.items[k][kk] = vv;
        end
    end
    -- stats
    for k, v in pairs(pframe.stats.stat_fields) do
        local txt = v.editbox:GetText();
        if txt ~= "" then
            plan.stats[k] = txt;
        end
    end
    -- talents
    plan.talents.use_custom = working_talents.use_custom;
    plan.talents.custom_code = working_talents.custom_code;

    -- buffs
    plan.buffs.use_custom = working_buffs.use_custom;
    plan.buffs.preserve_active = working_buffs.preserve_active;
    plan.buffs.player_buffs = {};
    for k, v in pairs(working_buffs.player_buffs) do
        plan.buffs.player_buffs[k] = v;
    end
    plan.buffs.target_buffs = {};
    for k, v in pairs(working_buffs.target_buffs) do
        plan.buffs.target_buffs[k] = v;
    end

    __sc_p_char.calculator_saves[plan_name] = plan;

    pframe.plan_dd.init_func(plan_name);
end


local effects_diff_on_arrow_tooltip = {};
empty_effects(effects_diff_on_arrow_tooltip);
local new_item_buffer = {};
local old_item_buffer = {};

local item_planner_gem_enchant_dropdown;
local item_planner_gem_enchant_dropdown_entries = {};
local item_planner_gem_enchant_dropdown_filtered = {};
local item_planner_gem_enchant_dropdown_rows_count = 12;
local item_planner_enchant_icon_tex = "Interface\\Icons\\Trade_Engraving";
local item_planner_dropdown_check_tex = "Interface\\Buttons\\UI-CheckBox-Check";
local item_planner_dropdown_none_tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up";
local item_planner_dropdown_missing_tex = "Interface\\Icons\\INV_Misc_QuestionMark";

-- Set i'th colon-separated field in item links while preserving everything else.
local function item_link_set_field(link, field_idx, field_value)
    if type(link) ~= "string" or type(field_idx) ~= "number" or field_idx < 1 then
        return link;
    end

    local prefix, fields_str, suffix = link:match("^(.-item:)([^|]*)(.*)$");
    if not prefix then
        return link;
    end

    local fields = {};
    local start_idx = 1;
    while true do
        local split_idx = string.find(fields_str, ":", start_idx, true);
        if not split_idx then
            fields[#fields + 1] = string.sub(fields_str, start_idx);
            break;
        end
        fields[#fields + 1] = string.sub(fields_str, start_idx, split_idx - 1);
        start_idx = split_idx + 1;
    end

    while #fields < field_idx do
        fields[#fields + 1] = "";
    end
    fields[field_idx] = field_value or "";

    return prefix..table.concat(fields, ":")..suffix;
end

local function item_planner_gem_enchant_dropdown_refresh_rows()
    local frame = item_planner_gem_enchant_dropdown;

    local offset = math.floor(frame.slider:GetValue() or 0);
    for i, row in ipairs(frame.rows) do
        local entry = item_planner_gem_enchant_dropdown_filtered[offset + i];
        if entry then
            row.entry_id = entry.id;
            if entry.is_none then
                row.label:SetText(entry.lname);
            else
                row.label:SetText(entry.lname.." ("..entry.id..")");
            end
            row.label:SetTextColor(entry.r or 1, entry.g or 1, entry.b or 1, 1);
            row.icon:SetTexture(entry.tex or item_planner_dropdown_missing_tex);
            row.icon:Show();
            local is_active =
                (entry.is_none and frame.active_id == 0) or
                (not entry.is_none and frame.active_id == entry.id);
            if is_active then
                row.check:Show();
            else
                row.check:Hide();
            end
            row:Show();
        else
            row.entry_id = nil;
            row.icon:Hide();
            row.check:Hide();
            row:Hide();
        end
    end
end

local function item_planner_gem_enchant_dropdown_filter()
    local frame = item_planner_gem_enchant_dropdown;

    clear_table(item_planner_gem_enchant_dropdown_filtered);
    local query = string.lower(frame.search:GetText() or "");

    if query == "" then
        for i, v in ipairs(item_planner_gem_enchant_dropdown_entries) do
            item_planner_gem_enchant_dropdown_filtered[i] = v;
        end
    else
        local n = 0;
        if item_planner_gem_enchant_dropdown_entries[1] and item_planner_gem_enchant_dropdown_entries[1].is_none then
            n = 1;
            item_planner_gem_enchant_dropdown_filtered[1] = item_planner_gem_enchant_dropdown_entries[1];
        end
        for i = 2, #item_planner_gem_enchant_dropdown_entries do
            local v = item_planner_gem_enchant_dropdown_entries[i];
            if string.find(v.search_lname, query, 1, true) or
                string.find(v.search_id, query, 1, true) then
                n = n + 1;
                item_planner_gem_enchant_dropdown_filtered[n] = v;
            end
        end
    end

    local max_offset = math.max(0, #item_planner_gem_enchant_dropdown_filtered - item_planner_gem_enchant_dropdown_rows_count);
    frame.slider:SetMinMaxValues(0, max_offset);
    frame.slider:SetValue(math.min(frame.slider:GetValue() or 0, max_offset));
    item_planner_gem_enchant_dropdown_refresh_rows();
end

local function item_planner_gem_enchant_dropdown_build_entries(mode, active_id)

    clear_table(item_planner_gem_enchant_dropdown_entries);

    local frame = item_planner_gem_enchant_dropdown;
    frame.active_id = tonumber(active_id) or 0;
    if frame.active_id < 0 then
        frame.active_id = 0;
    end

    local n = 0;
    local retry_needed = false;
    if mode == "gem" then
        for item_id in pairs(sc.gem_items) do
            local lname, _, quality, _, _, _, _, _, _, tex = C_Item.GetItemInfo(item_id);
            if not lname then
                retry_needed = true;
            end
            lname = tostring(lname or item_id);
            local color = ITEM_QUALITY_COLORS[quality or 0] or ITEM_QUALITY_COLORS[1];
            n = n + 1;
            item_planner_gem_enchant_dropdown_entries[n] = {
                id = item_id,
                lname = lname,
                search_lname = string.lower(lname),
                search_id = tostring(item_id),
                tex = tex,
                r = color.r,
                g = color.g,
                b = color.b,
            };
        end
    else
        for enchant_id, lname in pairs(sc.enchant_id_to_lname) do
            -- filter out some enchants intended as ilvl based suffix scaling effect
            if sc.enchants[enchant_id] and
                sc.enchant_effects[sc.enchants[enchant_id][1]] and
                sc.enchant_effects[sc.enchants[enchant_id][1]][1][sc.aura_idx_value] ~= 0 then

                n = n + 1;
                item_planner_gem_enchant_dropdown_entries[n] = {
                    id = enchant_id,
                    lname = lname,
                    search_lname = string.lower(lname),
                    search_id = tostring(enchant_id),
                    tex = item_planner_enchant_icon_tex,
                    r = 1,
                    g = 1,
                    b = 1,
                };
            end
        end
    end

    table.sort(item_planner_gem_enchant_dropdown_entries, function(a, b)
        if a.search_lname == b.search_lname then
            return a.id < b.id;
        end
        return a.search_lname < b.search_lname;
    end);

    table.insert(item_planner_gem_enchant_dropdown_entries, 1, {
        id = 0,
        lname = "None",
        search_lname = "none",
        search_id = "0",
        tex = item_planner_dropdown_none_tex,
        r = 1, g = 1, b = 1,
        is_none = true,
    });
    return retry_needed;
end

local function item_planner_gem_enchant_dropdown_create(parent)

    local click_catcher = CreateFrame("Frame", nil, UIParent);
    click_catcher:SetAllPoints(UIParent);
    click_catcher:EnableMouse(true);
    click_catcher:SetFrameStrata("DIALOG");
    click_catcher:Hide();

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate");
    frame:SetSize(262, 250);
    frame:SetFrameStrata("DIALOG");
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:SetScript("OnMouseDown", function()
        -- Consume clicks inside dropdown so only outside clicks close it.
    end);
    frame:Hide();
    frame.click_catcher = click_catcher;
    click_catcher:SetFrameLevel(frame:GetFrameLevel() - 1);
    click_catcher:SetScript("OnMouseDown", function()
        frame:Hide();
    end);
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    frame:SetBackdropColor(0, 0, 0, 0.95);
    frame:SetBackdropBorderColor(1, 0.82, 0, 1);
    frame:SetScript("OnHide", function(self)
        self.click_catcher:Hide();
        self.search:ClearFocus();
        GameTooltip:Hide();
    end);
    frame:SetScript("OnShow", function(self)
        self.click_catcher:Show();
    end);

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    title:SetPoint("TOPLEFT", 8, -7);
    title:SetText("Select");
    frame.title = title;

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2);
    close:SetScript("OnClick", function()
        frame:Hide();
    end);

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");
    search:SetPoint("TOPLEFT", 8, -24);
    search:SetSize(160, 15);
    search:SetAutoFocus(false);
    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or "";
        if txt == "" then
            frame.search_empty_label:Show();
        else
            frame.search_empty_label:Hide();
        end
        item_planner_gem_enchant_dropdown_filter();
    end);
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus();
        frame:Hide();
    end);
    frame.search = search;

    local search_empty = frame:CreateFontString(nil, "OVERLAY", font);
    search_empty:SetPoint("LEFT", search, 5, 0);
    search_empty:SetText(L["Search name or ID"]);
    frame.search_empty_label = search_empty;

    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate");
    list:SetPoint("TOPLEFT", 8, -45);
    list:SetSize(246, 197);
    list:EnableMouseWheel(true);
    list:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    });
    list:SetBackdropColor(0, 0, 0, 0.6);
    list:SetBackdropBorderColor(0.4, 0.4, 0.4, 1);
    frame.list = list;

    local slider = CreateFrame("Slider", "__sc_frame_item_planner_dropdown_slider", list, "UIPanelScrollBarTrimTemplate");
    -- template handler scrolls the parent as a ScrollFrame, list is a plain Frame
    slider:SetScript("OnValueChanged", nil);
    slider:SetOrientation("VERTICAL");
    slider:SetPoint("RIGHT", list, "RIGHT", 0, 0);
    slider:SetHeight(list:GetHeight() - 34);
    slider.scrollStep = 1;
    slider:SetValueStep(1);
    slider:SetMinMaxValues(0, 0);
    slider:SetValue(0);
    slider:SetObeyStepOnDrag(true);
    slider:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor(value + 0.5);
        if snapped ~= value then
            self:SetValue(snapped);
            return;
        end
        item_planner_gem_enchant_dropdown_refresh_rows();
    end);
    local slider_bg = slider:CreateTexture(nil, "BACKGROUND");
    slider_bg:SetAllPoints(slider);
    slider_bg:SetColorTexture(0, 0, 0, 0.5);
    frame.slider = slider;

    list:SetScript("OnMouseWheel", function(self, delta)
        local min_val, max_val = frame.slider:GetMinMaxValues();
        local val = frame.slider:GetValue() - delta;
        val = math.max(min_val, math.min(max_val, val));
        if val ~= frame.slider:GetValue() then
            frame.slider:SetValue(val);
        end
    end);

    frame.rows = {};
    for i = 1, item_planner_gem_enchant_dropdown_rows_count do
        local row = CreateFrame("Button", nil, list);
        row:SetSize(214, 15);
        row:SetPoint("TOPLEFT", list, 3, -2 - (i - 1) * 15);
        row:EnableMouse(true);

        local bg = row:CreateTexture(nil, "BACKGROUND");
        bg:SetAllPoints(row);
        bg:SetColorTexture(1, 1, 1, 0.02);
        row.bg = bg;

        local hl = row:CreateTexture(nil, "HIGHLIGHT");
        hl:SetAllPoints(row);
        hl:SetColorTexture(1, 1, 1, 0.18);

        local icon = row:CreateTexture(nil, "ARTWORK");
        icon:SetSize(13, 13);
        icon:SetPoint("LEFT", row, "LEFT", 1, 0);
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        row.icon = icon;

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        label:SetPoint("LEFT", icon, "RIGHT", 3, 0);
        label:SetWidth(182);
        label:SetJustifyH("LEFT");
        label:SetWordWrap(false);
        row.label = label;

        local check = row:CreateTexture(nil, "OVERLAY");
        check:SetTexture(item_planner_dropdown_check_tex);
        check:SetSize(12, 12);
        check:SetPoint("RIGHT", row, "RIGHT", -2, 0);
        check:SetVertexColor(0.2, 1.0, 0.2, 1.0);
        check:Hide();
        row.check = check;

        row:SetScript("OnClick", function(self)
            if self.entry_id == nil then
                return;
            end

            local selected_id = tonumber(self.entry_id) or 0;
            local slot_id = frame.slot_id;
            local changed = false;

            if slot_id and working_item_plan[slot_id] then
                local slot_info = working_item_plan[slot_id];
                if frame.mode == "gem" and frame.gem_index then
                    local gem_key = "gem"..frame.gem_index;
                    local old_id = tonumber(slot_info[gem_key]) or 0;
                    if old_id ~= selected_id then
                        if selected_id == 0 then
                            slot_info[gem_key] = nil;
                        else
                            slot_info[gem_key] = selected_id;
                        end
                        if slot_info.link then
                            slot_info.link = item_link_set_field(
                                slot_info.link,
                                2 + frame.gem_index,
                                selected_id == 0 and "" or tostring(selected_id)
                            );
                        end
                        changed = true;
                    end
                elseif frame.mode == "enchant" then
                    local old_id = tonumber(slot_info.enchant_id) or 0;
                    if old_id ~= selected_id then
                        if selected_id == 0 then
                            slot_info.enchant_id = nil;
                        else
                            slot_info.enchant_id = selected_id;
                        end
                        if slot_info.link then
                            slot_info.link = item_link_set_field(
                                slot_info.link,
                                2,
                                selected_id == 0 and "" or tostring(selected_id)
                            );
                        end
                        changed = true;
                    end
                end
            end

            if changed then
                update_calculator_item_planner();
            end
            frame:Hide();
        end);
        row:SetScript("OnEnter", function(self)
            if not self.entry_id then
                return;
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            if frame.mode == "gem" then
                GameTooltip:SetItemByID(self.entry_id);
            else
                local title = sc.enchant_id_to_lname[self.entry_id];
                if title then
                    title = title.." ("..self.entry_id..")";
                else
                    title = tostring(self.entry_id);
                end
                GameTooltip:SetText(title);
                local spell_ids = sc.enchants[self.entry_id];
                if spell_ids then
                    for _, spell_id in ipairs(spell_ids) do
                        if spell_id > 0 then
                            local spell_name = C_Spell.GetSpellName(spell_id);
                            if spell_name then
                                GameTooltip:AddLine(spell_name.." ("..spell_id..")");
                            else
                                GameTooltip:AddLine(tostring(spell_id));
                            end
                        end
                    end
                end
            end
            GameTooltip:Show();
        end);
        row:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        frame.rows[i] = row;
    end

    item_planner_gem_enchant_dropdown = frame;
    return frame;
end


local failed_retries = 0;
local max_retries = 5;
-- C_Timer cannot call with arguments
local gem_enchant_dd_mode, gem_enchant_dd_active_id;
local function item_planner_gem_enchant_dropdown_refresh()

    local mode = gem_enchant_dd_mode;
    local active_id = gem_enchant_dd_active_id;

    local retry_needed = item_planner_gem_enchant_dropdown_build_entries(mode, active_id);
    item_planner_gem_enchant_dropdown_filter();
    if retry_needed and failed_retries < max_retries then
        failed_retries = failed_retries + 1;
        C_Timer.After(0.5, item_planner_gem_enchant_dropdown_refresh);
        item_planner_gem_enchant_dropdown.title:SetText(L["Loading gems ..."]);
    else
        failed_retries = 0;
        if mode == "gem" then
            item_planner_gem_enchant_dropdown.title:SetText(L["Select gem"]);
        else
            item_planner_gem_enchant_dropdown.title:SetText(L["Select enchant"]);
        end
    end

end

local function item_planner_gem_enchant_dropdown_open(anchor, mode, active_id, slot_id, gem_index)

    local frame = item_planner_gem_enchant_dropdown;
    frame.mode = mode;
    frame.slot_id = slot_id;
    frame.gem_index = gem_index;
    frame:ClearAllPoints();
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2);

    frame.search:SetText("");
    frame.search_empty_label:Show();
    frame.slider:SetValue(0);

    gem_enchant_dd_mode = mode;
    gem_enchant_dd_active_id = active_id;
    item_planner_gem_enchant_dropdown_refresh();

    frame:Show();
end

local function create_calculator_items_subframe(pframe)

    item_planner_gem_enchant_dropdown_create(pframe.items);

    local f, f_txt;

    -- Item upgrade planner tabbed subframe
    local slots_order = {
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
        "AmmoSlot",
    };

    local slot_padding = 6;
    local slot_size = 30;
    -- between a slot and its planned item, the arrow sits in it
    local plan_gap = 14;
    local gem_icon_size = 10;
    local cancel_size = 16;
    -- the strip below the divider at the bottom
    local bottom_strip_height = 36;
    local slots_realign_to = {
        HeadSlot = {
            align_from = "LEFT", panchor = "TOPLEFT",
            px_offset = cancel_size + 2, py_offset = -26,
            x_between = 0, y_between = -(slot_size + slot_padding)
        },
        HandsSlot = {
            align_from = "RIGHT", panchor = "TOPRIGHT",
            px_offset = -(cancel_size + 2), py_offset = -26,
            x_between = 0, y_between = -(slot_size + slot_padding)
        },
        -- centred between the columns: the middle of the four slots
        MainHandSlot = {
            align_from = "BOTTOM", panchor = "BOTTOM",
            px_offset = -1.5 * (slot_size + slot_padding), py_offset = bottom_strip_height + cancel_size + 4,
            x_between = slot_size + slot_padding, y_between = 0
        },
    };

    local items_max_y_offset = 0;

    -- between the columns like on the character sheet, under the slots (the weapons row covers its feet); shown
    -- instead of the tip once the plan has changes, drag to rotate
    local model_inset = cancel_size + 2 + 3 * slot_size + plan_gap + 5;
    -- the top of the weapons' planned item boxes; the camera leaves about 40 empty below the feet and above the head,
    -- the model starts at the top of the subframe (higher would cover the subtabs)
    local weapons_plan_top = bottom_strip_height + cancel_size + 4 + slot_size + plan_gap + 2 * slot_size + 1;
    local model = CreateFrame("DressUpModel", nil, pframe.items);
    model:SetPoint("TOPLEFT", model_inset, 0);
    model:SetPoint("BOTTOMRIGHT", -model_inset, weapons_plan_top - 24);
    model:SetFrameLevel(pframe.items:GetFrameLevel());
    model.rotation = 0;
    model:EnableMouse(true);
    model:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            self.drag_x = GetCursorPosition();
            self.drag_rotation = self.rotation;
        end
    end);
    model:SetScript("OnUpdate", function(self)
        if not self.drag_x then
            return;
        end
        if not IsMouseButtonDown("LeftButton") then
            self.drag_x = nil;
            return;
        end
        self.rotation = self.drag_rotation + (GetCursorPosition() - self.drag_x) * 0.02;
        self:SetRotation(self.rotation);
    end);
    model:Hide();
    pframe.items.plan_model = model;

    pframe.items.slots = {};
    pframe.items:HookScript("OnShow", function()
        update_calculator_character_items();
    end);
    pframe.items:HookScript("OnHide", function()
        if item_planner_gem_enchant_dropdown then
            item_planner_gem_enchant_dropdown:Hide();
        end
    end);

    local arrow_tex_path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up";
    local x_offset, y_offset, pos;
    for _, slot in ipairs(slots_order) do

        if slots_realign_to[slot] then
            pos = slots_realign_to[slot];
            x_offset = 0;
            y_offset = 0;
        end

        -- SOURCE ITEM SLOT FRAME
        local slotf = CreateFrame("Frame", nil, pframe.items);

        slotf:SetSize(slot_size, slot_size);
        slotf:SetPoint(
            pos.align_from,
            pframe.items,
            pos.panchor,
            pos.px_offset + x_offset,
            pos.py_offset + y_offset
        );

        x_offset = x_offset + pos.x_between;
        y_offset = y_offset + pos.y_between;
        items_max_y_offset = math.min(items_max_y_offset, y_offset+pos.py_offset);

        local slot_id, empty_tex = GetInventorySlotInfo(slot);

        slotf.slot = slot_id;

        slotf.bg = slotf:CreateTexture(nil, "BACKGROUND");
        slotf.bg:SetAllPoints(slotf);
        slotf.bg:SetTexture(empty_tex);
        slotf.bg:SetVertexColor(0.6, 0.6, 0.6, 1);

        slotf.icon = slotf:CreateTexture(nil, "ARTWORK");
        slotf.icon:SetAllPoints(slotf);
        slotf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        --slotf.icon:SetAlpha(0.4);

        slotf.ilvl_fstr = slotf:CreateFontString(nil, "OVERLAY");
        slotf.ilvl_fstr:SetFontObject(NumberFontNormalSmall)
        local fp, _, flags = slotf.ilvl_fstr:GetFont();
        slotf.ilvl_fstr:SetFont(fp, 10, "THICKOUTLINE");
        slotf.ilvl_fstr:SetPoint("TOP", 0, -1);

        slotf.border = slotf:CreateTexture(nil, "OVERLAY");
        slotf.border:SetTexture("Interface\\Common\\WhiteIconFrame");
        slotf.border:SetBlendMode("BLEND");
        slotf.border:SetSize(slot_size+2, slot_size+2);
        slotf.border:SetPoint("TOPLEFT", -1, 1);

        slotf:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetHyperlink(self.link);
                GameTooltip:Show();
            end
        end);
        slotf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        slotf:SetScript("OnMouseDown", function(self, btn)
            if not self.link or not IsModifiedClick("CHATLINK") or btn ~= "LeftButton" then
                return;
            end
            HandleModifiedItemClick(self.link);
        end);

        f = slotf:CreateTexture(nil, "OVERLAY");
        f:SetTexture(arrow_tex_path);
        f:SetTexCoord(0.3, 0.7, 0.3, 0.7);
        f:SetSize(8, 8);
        f.slot = slot_id;
        if pos.align_from == "LEFT" then
            slotf.expand_point = "RIGHT";
            slotf.expand_y_dir = 0;
            slotf.expand_x_dir = 1;
        elseif pos.align_from == "RIGHT" then
            slotf.expand_point = "LEFT";
            slotf.expand_y_dir = 0;
            slotf.expand_x_dir = -1;
            f:SetRotation(3.14592);
        else
            slotf.expand_point = "TOP";
            slotf.expand_y_dir = 1;
            slotf.expand_x_dir = 0;
            f:SetRotation(3.14592/2);
        end
        local arrowf = f;

        f:SetPoint(slotf.expand_point, 11*slotf.expand_x_dir, 11*slotf.expand_y_dir);
        f:SetScript("OnEnter", function(self)

            if not self.slot or not working_item_plan[self.slot] then
                return;
            end

            local loadout, effects, effects_finalized, update_id = update_loadout_and_effects();

            cpy_effects(effects_diff_on_arrow_tooltip, effects);

            new_item_buffer[self.slot] = {};
            write_item_info_from_link(new_item_buffer[self.slot], working_item_plan[self.slot].link);

            if loadout.item_links[self.slot] then
                old_item_buffer[self.slot] = {};
                write_item_info_from_link(old_item_buffer[self.slot], loadout.item_links[self.slot]);
            end
            apply_items_cmp(
                loadout, effects_diff_on_arrow_tooltip, new_item_buffer, old_item_buffer,
                true, true, true
            );
            new_item_buffer[self.slot] = nil;
            old_item_buffer[self.slot] = nil;

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

            if config.settings.general_calc_stats_raw_dump then
                GameTooltip:SetText(L["Changes"]);
            else
                GameTooltip:SetText(L["Changes (simplified)"]);
            end

            effects_finalize_forced(loadout, effects_diff_on_arrow_tooltip);
            local stat_diffs = stats_diff_format(loadout, effects_finalized, effects_diff_on_arrow_tooltip);
            if stat_diffs ~= "" then
                stat_diffs = stat_diffs_included_effects_str(true, true, true)..stat_diffs;
            end

            GameTooltip:AddLine(stat_diffs);
            GameTooltip:Show();
        end);
        f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);


        -- DESTINATION ITEM SLOT FRAME
        local new_itemf = CreateFrame("Frame", nil, slotf);

        new_itemf:SetSize(slot_size, slot_size);
        new_itemf:SetPoint(
            slotf.expand_point,
            slotf,
            (slot_size + plan_gap)*slotf.expand_x_dir,
            (slot_size + plan_gap)*slotf.expand_y_dir
        );

        new_itemf.bg = new_itemf:CreateTexture(nil, "BACKGROUND");
        new_itemf.bg:SetAllPoints(new_itemf);
        new_itemf.bg:SetTexture(empty_tex);
        new_itemf.bg:SetVertexColor(0.6, 0.6, 0.6, 1);

        new_itemf.icon = new_itemf:CreateTexture(nil, "ARTWORK");
        new_itemf.icon:SetAllPoints(new_itemf);
        new_itemf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);

        new_itemf.ilvl_fstr = new_itemf:CreateFontString(nil, "OVERLAY");
        new_itemf.ilvl_fstr:SetFontObject(NumberFontNormalSmall)
        local fp, _, flags = new_itemf.ilvl_fstr:GetFont();
        new_itemf.ilvl_fstr:SetFont(fp, 10, "THICKOUTLINE");
        new_itemf.ilvl_fstr:SetPoint("TOP", 0, -1);

        new_itemf.border = new_itemf:CreateTexture(nil, "OVERLAY");
        new_itemf.border:SetAllPoints(new_itemf);
        new_itemf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

        new_itemf.border = new_itemf:CreateTexture(nil, "OVERLAY");
        new_itemf.border:SetTexture("Interface\\Common\\WhiteIconFrame");
        new_itemf.border:SetBlendMode("BLEND");
        new_itemf.border:SetSize(
            slot_size+4 + slot_size*math.abs(slotf.expand_x_dir),
            slot_size+4 + slot_size*math.abs(slotf.expand_y_dir)
        );
        new_itemf.border:SetPoint(
            pos.align_from,
            -3*slotf.expand_x_dir,
            -3*slotf.expand_y_dir
        );

        new_itemf:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetHyperlink(self.link);
                GameTooltip:Show();
            end
        end);
        new_itemf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local plus_tex = "Interface\\Buttons\\UI-PlusButton-Up";
        -- Gem slot frames
        local gemsf = {};
        for i = 1, 3 do

            local gemf = CreateFrame("Frame", nil, new_itemf);

            gemf:SetSize(gem_icon_size, gem_icon_size);
            gemf:SetPoint(
                slotf.expand_point,
                13*slotf.expand_x_dir - 18*slotf.expand_y_dir + i*9*slotf.expand_y_dir,
                13*slotf.expand_y_dir + 18*math.abs(slotf.expand_x_dir) - i*9*math.abs(slotf.expand_x_dir)
            );

            gemf.bg = gemf:CreateTexture(nil, "BACKGROUND");
            gemf.bg:SetAllPoints(gemf);
            gemf.bg:SetTexture(plus_tex);
            --gemf.bg:SetAlpha(0.45);
            gemf.bg:SetDesaturated(true);

            gemf.icon = gemf:CreateTexture(nil, "ARTWORK");
            gemf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
            gemf.icon:SetSize(gem_icon_size-2, gem_icon_size-2);
            --gemf.icon:SetAllPoints(gemf);
            gemf.icon:SetPoint("TOPLEFT", 1, -1);

            gemf.border = gemf:CreateTexture(nil, "OVERLAY");
            gemf.border:SetAllPoints(gemf);
            gemf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

            gemf.gem_item_id = 0;
            gemf:SetScript("OnEnter", function(self)
                if self.gem_item_id ~= 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                    GameTooltip:SetItemByID(self.gem_item_id);
                    GameTooltip:AddLine(" ");
                    GameTooltip:AddLine(L["Click to change gem"], 1.0, 0.2, 0.2);
                    GameTooltip:Show();
                else
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                    GameTooltip:SetText(L["Click to add gem"], 1.0, 0.2, 0.2);
                    GameTooltip:Show();
                end
            end);
            gemf:SetScript("OnLeave", function(self)
                GameTooltip:Hide();
            end);
            gemf:SetScript("OnMouseDown", function(self, btn)
                if btn ~= "LeftButton" then
                    return;
                end
                if not working_item_plan[self.slot_id] or not working_item_plan[self.slot_id].link then
                    return;
                end
                item_planner_gem_enchant_dropdown_open(self, "gem", self.gem_item_id, self.slot_id, self.gem_index);
            end);

            gemf.slot_id = slot_id;
            gemf.gem_index = i;
            gemsf[i] = gemf;
        end

        local f = new_itemf:CreateTexture(nil, "OVERLAY");
        f:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
        f:SetVertexColor(0, 1, 0, 1);
        f:SetSize(10, 10);
        f:SetPoint(
            slotf.expand_point,
            new_itemf,
            26*slotf.expand_x_dir + 10*slotf.expand_y_dir,
            -10*math.abs(slotf.expand_x_dir) + 26*slotf.expand_y_dir
        );
        f.id = 0;

        f:SetScript("OnEnter", function(self)
            if self.id ~= 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetText(L["Socket match bonus"].." ("..self.id..")");
                GameTooltip:Show();
            end
        end);
        f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local gem_match_indicator = f;

        local enchantf = CreateFrame("Frame", nil, new_itemf);
        enchantf:SetSize(gem_icon_size, gem_icon_size);

        enchantf:SetPoint(
            slotf.expand_point,
            26*slotf.expand_x_dir - 9*slotf.expand_y_dir,
            9*math.abs(slotf.expand_x_dir) + 26*slotf.expand_y_dir
        );

        enchantf.bg = enchantf:CreateTexture(nil, "BACKGROUND");
        enchantf.bg:SetAllPoints(enchantf);
        enchantf.bg:SetTexture(plus_tex);
        enchantf.bg:SetDesaturated(true);

        enchantf.icon = enchantf:CreateTexture(nil, "ARTWORK");
        enchantf.icon:SetTexture("Interface\\Icons\\Trade_Engraving");
        enchantf.icon:SetSize(gem_icon_size -2, gem_icon_size - 2);
        enchantf.icon:SetPoint("TOPLEFT", 1, -1);
        enchantf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);

        enchantf.border = enchantf:CreateTexture(nil, "OVERLAY");
        enchantf.border:SetAllPoints(enchantf);
        enchantf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

        enchantf.enchant_id = 0;
        enchantf:SetScript("OnEnter", function(self)
            if self.enchant_id ~= 0  then

                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                local title = sc.enchant_id_to_lname[self.enchant_id];
                if title then
                    title = title.." ("..self.enchant_id..")";
                else
                    title = tostring(self.enchant_id);
                end

                GameTooltip:SetText(title);


                local spell_ids = sc.enchants[self.enchant_id];
                if spell_ids then
                    for _, spell_id in ipairs(spell_ids) do
                        if spell_id > 0 then
                            GameTooltip:AddLine(C_Spell.GetSpellName(spell_id).." ("..spell_id..")");
                        end
                    end
                end
                GameTooltip:AddLine(" ");
                GameTooltip:AddLine(L["Click to change enchant"], 1.0, 0.2, 0.2);
                GameTooltip:Show();

            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetText(L["Click to add enchant"], 1.0, 0.2, 0.2);
                GameTooltip:Show();
            end
        end);
        enchantf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        enchantf:SetScript("OnMouseDown", function(self, btn)
            if btn ~= "LeftButton" then
                return;
            end
            if not working_item_plan[self.slot_id] or not working_item_plan[self.slot_id].link then
                return;
            end
            item_planner_gem_enchant_dropdown_open(self, "enchant", self.enchant_id, self.slot_id, nil);
        end);
        enchantf.slot_id = slot_id;

        local cancelf = CreateFrame("Button", nil, slotf, "UIPanelButtonTemplate");
        cancelf:SetScript("OnClick", function(self)
            if working_item_plan[self.slot_id] then
                working_item_plan[self.slot_id] = nil;
            else
                -- add empty as to unequip old item with no replacement
                working_item_plan[self.slot_id] = {};
            end
            update_calculator_item_planner();
        end);

        local cancel_offset = -(cancel_size + 2);
        cancelf:SetPoint(pos.align_from, cancel_offset * slotf.expand_x_dir, cancel_offset * slotf.expand_y_dir);
        cancelf:SetSize(cancel_size, cancel_size);
        cancelf:SetText("x");
        local fontstr = cancelf:GetFontString();
        if fontstr then
            fontstr:ClearAllPoints();
            fontstr:SetPoint("CENTER", cancelf, "CENTER");
            fontstr:SetIgnoreParentAlpha(true);
            fontstr:SetMouseClickEnabled(false);
        end
        cancelf:SetFrameLevel(cancelf:GetFrameLevel() + 1);

        cancelf.slot_id = slot_id;

        pframe.items.slots[slot_id] = {
            old = slotf,
            arrow = arrowf,
            new = new_itemf,
            gems = gemsf,
            gems_match = gem_match_indicator,
            enchant = enchantf,
            cancel = cancelf,

        };
    end

    local handle_player_links = function(link)
        if __sc_frame:IsShown() and __sc_frame.calculator_frame:IsShown() then
            item_planner_add_slot(link);
            update_calculator_item_planner();
            __sc_frame.calculator_frame.items_tab:Click();
        end;
    end

    --

    -- ChatEdit_InsertLink only works on era client
    -- HandleModifiedItemClick seems to work on all clients,
    -- but other addon's shift clickables might only call ChatEdit_InsertLink
    --
    -- Workaround to use both without duplicate links
    local handle_modified_item_click_link;
    local chatedit_insertlink_link;

    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and not is_secret(link) then
            if link ~= handle_modified_item_click_link then

                handle_player_links(link);
                chatedit_insertlink_link = link;
            else
                handle_modified_item_click_link = nil;
            end
        end
    end);

    hooksecurefunc("HandleModifiedItemClick", function(link)
        if link and not is_secret(link) then
            if link ~= chatedit_insertlink_link then

                handle_player_links(link);
                handle_modified_item_click_link = link;
            else
                chatedit_insertlink_link = nil;
            end
        end
    end);

    f_txt = pframe.items:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormalLarge);
    f_txt:SetPoint("TOP", 0, -130);
    f_txt:SetText(L["SHIFT click on any item\n to add to plan!"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    pframe.items.item_add_tip = f_txt;


    local use_target_equipment;

    local same_target = function(self)
        local guid = UnitGUID("target");
        return not is_secret(guid) and guid == self.target_guid;
    end

    local target_item_data_received = function(_, success)
        local self = pframe.items.targets_item_btn;
        if success and same_target(self) then
            use_target_equipment(self);
        end
    end

    local target_items_retry = function()
        local self = pframe.items.targets_item_btn;
        self.retry_scheduled = false;
        if self.num_retries < 5 and same_target(self) then
            self.num_retries = self.num_retries + 1;
            use_target_equipment(self);
        end
    end

    use_target_equipment = function(self)
        local found_anything = false;
        local link_missing_when_cached = false;

        clear_table(working_item_plan);
        for slot in pairs(pframe.items.slots) do
            local link = GetInventoryItemLink("target", slot);
            local id = GetInventoryItemID("target", slot);
            if not link and id and request_item_data(id, target_item_data_received) then
                -- no load event will follow, the link may still come with the inspect data
                link_missing_when_cached = true;
            end
            if link then
                found_anything = true;

                working_item_plan[slot] = working_item_plan[slot] or {};
                if not write_item_info_from_link(working_item_plan[slot], link) then
                    working_item_plan[slot] = nil;
                end
            elseif GetInventoryItemLink("player", slot) then
                -- also equip empty slots
                working_item_plan[slot] = {};
            end
        end

        if link_missing_when_cached and not self.retry_scheduled then
            self.retry_scheduled = true;
            C_Timer.After(0.5, target_items_retry);
        end

        if found_anything then
            update_calculator_item_planner();
        end
    end


    f = pframe.items:CreateTexture(nil, "ARTWORK");
    f:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    f:SetHeight(1);
    f:SetPoint("BOTTOMLEFT", 0, bottom_strip_height);
    f:SetPoint("BOTTOMRIGHT", 0, bottom_strip_height);

    -- the two buttons above the divider, either side of the weapons row and level with it
    local weapons_row_width = 4 * slot_size + 3 * slot_padding;
    local side_button_max_width = (pframe.items:GetWidth() - weapons_row_width) / 2 - 10;
    local side_button_y = bottom_strip_height + cancel_size + 4 + (slot_size - 22) / 2;
    local function side_button(text)
        local btn = CreateFrame("Button", nil, pframe.items, "UIPanelButtonTemplate");
        btn:SetHeight(22);
        btn:SetNormalFontObject(GameFontNormalSmall);
        btn:SetHighlightFontObject(GameFontHighlightSmall);
        btn:SetDisabledFontObject(GameFontDisableSmall);
        btn:SetText(text);
        btn:SetWidth(math.min(side_button_max_width, math.ceil(btn:GetFontString():GetStringWidth()) + 24));
        return btn;
    end
    f = side_button(L["Clear all items"]);
    f:SetPoint("BOTTOMLEFT", 4, side_button_y);
    f:SetScript("OnClick", function()
        clear_table(working_item_plan);
        update_calculator_item_planner();
    end);
    local clear_btn = f;

    f = side_button(L["Use target's equipment"]);
    f:SetPoint("BOTTOMRIGHT", -4, side_button_y);
    f:SetScript("OnClick", function(self)

        if not CheckInteractDistance("target", 1) or not CanInspect("target") then
            return;
        end
        self.target_guid = UnitGUID("target");
        if is_secret(self.target_guid) then
            self.target_guid = nil;
            return;
        end

        self.num_retries = 0;

        -- visible gear may already be known, the rest only arrives with the inspect
        use_target_equipment(self);
        self:RegisterEvent("INSPECT_READY");
        NotifyInspect("target");
    end);
    pframe.items.targets_item_btn = f;

    f:SetScript("OnEvent", function(self, e)
        if e == "INSPECT_READY" then
            self:UnregisterEvent("INSPECT_READY");
            if same_target(self) then
                use_target_equipment(self);
            end
        end
    end);

end

local function create_calculator_stats_subframe(pframe)

    local x_pad = 5;
    local f, f_txt;


    pframe.stats.y_offset = pframe.stats.y_offset - 10;

    -- NOTE: the keys here are important and serves as template for other manual style stat-changes
    pframe.stats.stat_fields = {
        int = {
            label_str = L["Intellect"]
        },
        spirit = {
            label_str = L["Spirit"]
        },
        str = {
            label_str = L["Strength"]
        },
        agi = {
            label_str = L["Agility"]
        },
        stam = {
            label_str = L["Stamina"]
        },
        armor = {
            label_str = L["Armor"]
        },
        dodge_rating = {
            label_str = L["Dodge"]
        },
        parry_rating = {
            label_str = L["Parry"]
        },
        defense_skill_rating = {
            label_str = L["Defense"]
        },
        sp = {
            label_str = L["Spell Power"]
        },
        sd = {
            label_str = L["Spell Damage"]
        },
        hp = {
            label_str = L["Healing Power"]
        },
        ap = {
            label_str = L["Melee Attack Power"]
        },
        rap = {
            label_str = L["Ranged Attack Power"]
        },
        weapon_skill = {
            label_str = L["All Weapon Skill"]
        },
        crit_rating = {
            label_str = L["Critical"]
        },
        hit_rating = {
            label_str = L["Hit"]
        },
        haste_rating = {
            label_str = L["Haste"]
        },
        mp5 = {
            label_str = L["MP5"]
        },
        pen = {
            label_str = L["Penetration"]
        },
        expertise_rating = {
            label_str = L["Expertise"],
            clients = bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever)),
        },
        extra_mana = {
            label_str = L["Extra mana"],
        },
        resilience_rating = {
            label_str = L["Resilience"],
            clients = bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever)),
        },
    };

    local comparison_stats_listing_order = {};
    for _, k in ipairs({
        "str", "agi", "stam", "int", "spirit", "mp5", "extra_mana", "armor", "defense_skill_rating", "dodge_rating", "parry_rating", "resilience_rating",
        "crit_rating", "hit_rating", "haste_rating", "expertise_rating", "ap", "rap", "weapon_skill", "sp", "sd", "hp", "pen",
    }) do
        local clients = pframe.stats.stat_fields[k].clients;
        if not clients or client_matches(clients) then
            table.insert(comparison_stats_listing_order, k);
        else
            pframe.stats.stat_fields[k] = nil;
        end
    end

    local new_column_breakpoint = "crit_rating";

    local num_stats = #comparison_stats_listing_order;

    local y_offset_stats = pframe.stats.y_offset;
    local max_y_offset_stats = 0;
    local i = 1;
    local x_offset = 0;
    local editbox_x_pad = 0;
    while i <= num_stats do

        local k = comparison_stats_listing_order[i];
        if k == new_column_breakpoint then
            -- split column special, skip
            y_offset_stats = pframe.stats.y_offset;
            x_offset = x_offset + 210;
            editbox_x_pad = 50;
        end

        local v = pframe.stats.stat_fields[k];
        y_offset_stats = y_offset_stats - 17;

        v.label = pframe.stats:CreateFontString(nil, "OVERLAY");

        v.label:SetFontObject(font);
        v.label:SetPoint("TOPLEFT", x_pad + x_offset, y_offset_stats);
        v.label:SetText(v.label_str);
        v.label:SetTextColor(222/255, 192/255, 40/255);

        v.editbox = CreateFrame("EditBox", v.label_str.."editbox"..k, pframe.stats, "InputBoxTemplate");
        v.editbox:SetPoint("TOPLEFT", 100 + editbox_x_pad + x_offset, y_offset_stats-2);
        v.editbox:SetText("");
        v.editbox:SetAutoFocus(false);
        v.editbox:SetSize(100, 10);
        v.editbox.index = i;
        if sc.loadouts.manual_diff_in_pct(k) then
            local pct = v.editbox:CreateFontString(nil, "OVERLAY");
            pct:SetFontObject(font);
            pct:SetPoint("RIGHT", v.editbox, "RIGHT", -2, 0);
            pct:SetText("%");
            v.editbox:SetTextInsets(0, pct:GetStringWidth() + 4, 0, 0);
        end
        v.editbox:SetScript("OnTextChanged", function(self)

            if string.match(self:GetText(), "[^-+0123456789. ()]") ~= nil then
                self:ClearFocus();
                self:SetText("");
                self:SetFocus();
            else 
                --update_calc_list(true);
            end

            pframe.calculator_plan_changed = true;
        end);

        v.editbox:SetScript("OnEnterPressed", function(self)

        	self:ClearFocus()
        end);

        v.editbox:SetScript("OnEscapePressed", function(self)
        	self:ClearFocus()
        end);

        v.editbox:SetScript("OnTabPressed", function(self)

            local next_index = 0;
            if IsShiftKeyDown() then
                next_index = 1 + ((self.index-2) %num_stats);
            else
                next_index = 1 + (self.index %num_stats);
            end
        	self:ClearFocus()
            pframe.stats.stat_fields[comparison_stats_listing_order[next_index]].editbox:SetFocus();
        end);

        max_y_offset_stats = math.min(max_y_offset_stats, y_offset_stats);
        i = i + 1;
    end

    max_y_offset_stats = max_y_offset_stats - 20;
    f = CreateFrame("Button", nil, pframe.stats, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        for _, v in pairs(pframe.stats.stat_fields) do
            v.editbox:SetText("");
        end
        --update_calc_list(true);
    end);

    f:SetPoint("TOPRIGHT", 5, max_y_offset_stats);
    f:SetHeight(20);
    f:SetWidth(120);
    f:SetText(L["Clear stats"]);

    if __spellcoda_test_all_data__ then
        for _, v in pairs(pframe.stats.stat_fields) do
            v.editbox:SetText("1");
        end
    end
end

local function create_calculator_talents_subframe(pframe)

    local x_pad = 5;


    pframe.talents.y_offset = pframe.talents.y_offset - 10;

    local f = CreateFrame("CheckButton", "__sc_frame_calculator_talents_custom_talents_chk", pframe.talents, "ChatConfigCheckButtonTemplate");
    f:SetPoint("TOPLEFT", x_pad, pframe.talents.y_offset);

    getglobal(f:GetName()..'Text'):SetText(L["Use custom talents"]);
    getglobal(f:GetName()).tooltip =
        L["Accepts a valid wowhead talents link. Its talents & glyphs are used instead of your active ones."];
    f:SetScript("OnClick", function(self)

        working_talents.use_custom = self:GetChecked();
        update_talents_frame();
    end);
    pframe.talents.custom_talents_chk = f;

    pframe.talents.y_offset = pframe.talents.y_offset - 23;

    f = CreateFrame("EditBox", nil, pframe.talents, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", x_pad+25, pframe.talents.y_offset);
    f:SetSize(437, 15);
    f:SetAutoFocus(false);
    editbox_config(f, function(self)

        pframe.calculator_plan_changed = true;
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;
        local txt = self:GetText();

        if working_talents.use_custom then
            if txt ~= "" then
                working_talents.custom_code = wowhead_talent_code_from_url(txt);
            end
            pframe.talents.talent_editbox:SetText(
                wowhead_talent_link(working_talents.custom_code)
            );
            pframe.talents.talent_editbox:SetAlpha(1.0);
        else

            pframe.talents.talent_editbox:SetText(
                wowhead_talent_link(active_loadout().talents.code)
            );
            pframe.talents.talent_editbox:SetAlpha(0.2);
            pframe.talents.talent_editbox:SetCursorPosition(0);
        end
        self:ClearFocus();
    end);

    pframe.talents.talent_editbox = f;
end

-- bf (a subframe) holds the instance: buffs_cfg(), list_enabled(), list_height, name_prefix, legend_y_offset,
-- optional on_update() and lname_to_id
local function create_buffs_list(bf)

    local f, f_txt;

    f_txt = bf:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPRIGHT", 0, bf.legend_y_offset);
    f_txt:SetText(
        "|cFF9CD6DE"..L["Left click"]..":|r "..L["(De)select"].."\n"..
        "|cFF9CD6DE"..L["Right click"]..":|r "..L["+1 stack"].."\n"..
        "|cFF9CD6DE"..L["Middle click"]..":|r "..L["-1 stack"].."\n"
    );
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    bf.views = {
        {side = "lhs", cfg_key = "player_buffs", buffs = buffs, filtered = {}},
        {side = "rhs", cfg_key = "target_buffs", buffs = target_buffs, filtered = {}},
    };

    local filter_buffs = function(search_txt, only_selected, categories_mask)

        local num = tonumber(search_txt);
        local cfg = bf.buffs_cfg();
        for _, view in ipairs(bf.views) do
            view.filtered = {};
            local config_buffs = cfg[view.cfg_key];
            for k, v in ipairs(view.buffs) do
                local search_match =
                    search_txt == "" or
                        (v.lname and string.find(string.lower(v.lname), string.lower(search_txt)) or
                            (num and num == v.id));
                if search_match and
                    bit.band(categories_mask, bit.lshift(1, v.cat)) ~= 0 and
                    (not only_selected or config_buffs[v.id]) then

                    table.insert(view.filtered, k);
                end
            end
        end

        for _, view in ipairs(bf.views) do
            bf[view.side].slider:SetMinMaxValues(1, max(1, #view.filtered - math.floor(bf[view.side].num_buffs_can_fit/2)));
        end

        update_buffs_frame(bf);
    end;
    bf.refresh = function()
        filter_buffs(bf.search:GetText(), bf.show_only_selected, bf.category_filters_mask);
    end;

    f = CreateFrame("EditBox", bf.name_prefix.."search", bf, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 8, bf.y_offset);
    f:SetSize(160, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            bf.search_empty_label:Show();
            for _, view in ipairs(bf.views) do
                for k, _ in ipairs(view.buffs) do
                    view.filtered[k] = k;
                end
            end
        else
            bf.search_empty_label:Hide();
        end
        bf.refresh();
    end);
    bf.search = f;

    f = bf:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Search name or ID"]);
    f:SetPoint("LEFT", bf.search, 5, 0);
    bf.search_empty_label = f;

    bf.show_only_selected = false;
    bf.category_filters_mask = bit.bnot(0);
    local categories_display_options = {
        { id = "class",     lname = L["Class"]},
        { id = "player",    lname = L["Player"]},
        { id = "enchant",   lname = L["Enchant"]},
        { id = "hostile",   lname = L["Hostile"]},
        { id = "friendly",  lname = L["Friendly"]},
    };

    f = CreateFrame("CheckButton", nil, bf, "ChatConfigCheckButtonTemplate");
    f:SetPoint("LEFT", bf.search, "RIGHT", 5, 0);
    f.Text:SetText("Only show selected auras");

    f:SetScript("OnClick", function(self)
        bf.show_only_selected = self:GetChecked();
        bf.refresh();
    end);


    bf.y_offset = bf.y_offset - 18;

    bf.fadeable_checkboxes = {f};

    local x_offset = 5;
    for k, v in ipairs(categories_display_options) do
        local f = CreateFrame("CheckButton", nil, bf, "ChatConfigCheckButtonTemplate");
        f.Text:SetText(v.lname);
        local color = buff_categories_colors[buff_category[v.id]];
        f.Text:SetTextColor(color[1], color[2], color[3]);
        f:SetPoint("TOPLEFT", x_offset, bf.y_offset);

        local w = f.Text:GetStringWidth() or 0;
        x_offset = x_offset + w + 30;
        f:SetChecked(true);
        f:SetHitRectInsets(0, -w, 0, 0);

        f:SetScript("OnClick", function(self)
            if self:GetChecked() then
                bf.category_filters_mask =
                    bit.bor(
                        bf.category_filters_mask,
                        bit.lshift(1, buff_category[v.id])
                    );
            else
                bf.category_filters_mask =
                    bit.band(
                        bf.category_filters_mask,
                        bit.bnot(bit.lshift(1, buff_category[v.id]))
                    );
            end
            bf.refresh();
        end);

        bf.fadeable_checkboxes[#bf.fadeable_checkboxes + 1] = f;
    end

    bf.y_offset = bf.y_offset - 18;

    for view_idx, view in ipairs(bf.views) do

        -- init without any filter, 1 to 1
        for k, _ in ipairs(view.buffs) do
            view.filtered[k] = k;
        end

        local y_offset = bf.y_offset;

        local h = bf.list_height;
        f = CreateFrame("ScrollFrame", nil, bf);
        f:SetWidth(235);
        f:SetHeight(h);
        f:SetPoint("TOPLEFT", bf, 240*(view_idx-1), y_offset);
        bf[view.side] = {}
        bf[view.side].frame = f;

        f = CreateFrame("ScrollFrame", nil, bf[view.side].frame);
        f:SetWidth(235);
        f:SetHeight(h-50);
        f:SetPoint("TOPLEFT", bf[view.side].frame, 0, -35);
        bf[view.side].buffs_list_frame = f;

        bf[view.side].buffs = {};
        bf[view.side].buffs_num = 0;

        y_offset = -5;

        f = bf[view.side].frame:CreateFontString(nil, "OVERLAY");
        f:SetFontObject(GameFontNormal);
        local fp, _, flags = f:GetFont();
        f:SetFont(fp, 17, flags);
        if (view_idx == 1) then
            f:SetText(L["Player auras"]);
        else
            f:SetText(L["Subject auras"]);
        end
        f:SetPoint("TOPLEFT", 5, y_offset);

        y_offset = y_offset - 15;
        f = CreateFrame("CheckButton", bf.name_prefix.."check_all_"..view.side, bf[view.side].frame, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", 20, y_offset);
        getglobal(f:GetName() .. 'Text'):SetText(L["Select all/none"]);
        getglobal(f:GetName() .. 'Text'):SetTextColor(1, 0, 0);

        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;

            local cfg = bf.buffs_cfg();
            if self:GetChecked() then
                for _, v in ipairs(view.buffs) do
                    cfg[view.cfg_key][v.id] = 1;
                    if bf.lname_to_id then
                        bf.lname_to_id[C_Spell.GetSpellName(v.id)] = v.id;
                    end
                end
            else
                cfg[view.cfg_key] = {};
            end

            bf.refresh();
        end);
        bf[view.side].select_all_buffs_checkbutton = f;

        -- named, the template anchors its Middle texture by "$parentTop" which otherwise collides between sliders
        f = CreateFrame("Slider", bf.name_prefix.."slider_"..view.side, bf[view.side].buffs_list_frame, "UIPanelScrollBarTrimTemplate");
        f:SetOrientation('VERTICAL');
        f:SetPoint("RIGHT", bf[view.side].buffs_list_frame, "RIGHT", 0, 2);
        f:SetHeight(bf[view.side].buffs_list_frame:GetHeight()-30);
        bf[view.side].num_buffs_can_fit =
            math.floor(bf[view.side].buffs_list_frame:GetHeight()/15);
        f:SetMinMaxValues( 1, max(1, #view.filtered - math.floor(bf[view.side].num_buffs_can_fit/2)));
        f:SetValue(1);
        f:SetValueStep(1);
        f:SetScript("OnValueChanged", function(self, val)
            update_buffs_frame(bf);
        end);

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f);
        bg:SetColorTexture(0, 0, 0, 0.5);

        bf[view.side].slider = f;

        bf[view.side].buffs_list_frame:SetScript("OnMouseWheel", function(self, dir)
            local min_val, max_val = bf[view.side].slider:GetMinMaxValues();
            local val = bf[view.side].slider:GetValue();
            if val - dir >= min_val and val - dir <= max_val then
                bf[view.side].slider:SetValue(val - dir);
                update_buffs_frame(bf);
            end
        end);


        y_offset = 0;
        for i = 1, bf[view.side].num_buffs_can_fit do
            bf[view.side].buffs[i] = {};

            local checkbtn = CreateFrame("CheckButton", bf.name_prefix.."checkbutton"..view.side..i, bf[view.side].buffs_list_frame, "ChatConfigCheckButtonTemplate");
            checkbtn.side = view.side;
            checkbtn:SetScript("OnMouseDown", function(self, btn)

                sc.loadouts.force_update = true;
                local config_buffs = bf.buffs_cfg()[view.cfg_key];
                if btn == "LeftButton" then
                    if not config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = 1;
                        if bf.lname_to_id then
                            bf.lname_to_id[C_Spell.GetSpellName(self.buff_id)] = self.buff_id;
                        end
                    else
                        config_buffs[self.buff_id] = nil;
                        if bf.lname_to_id then
                            bf.lname_to_id[C_Spell.GetSpellName(self.buff_id)] = nil;
                        end
                    end
                elseif btn == "MiddleButton" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = math.max(1, config_buffs[self.buff_id] - 1);
                    end
                elseif btn == "RightButton" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = config_buffs[self.buff_id] + 1;
                    end
                end
                self.__stacks_str:SetText(tostring(config_buffs[self.buff_id] or 0));

                bf.refresh();
            end);
            local icon = CreateFrame("Frame", bf.name_prefix.."icon"..view.side..i, bf[view.side].buffs_list_frame);
            icon:SetSize(15, 15);
            local tex = icon:CreateTexture(nil);
            icon.tex = tex;
            tex:SetAllPoints(icon);

            checkbtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
                GameTooltip:SetSpellByID(self.buff_id);
                GameTooltip:Show();
            end);
            checkbtn:SetScript("OnLeave", function()
                GameTooltip:Hide();
            end);

            local stacks_str = icon:CreateFontString(nil, "OVERLAY");
            stacks_str:SetFontObject(font);
            stacks_str:SetPoint("BOTTOMRIGHT", 0, 0);
            checkbtn.__stacks_str = stacks_str;

            checkbtn:SetPoint("TOPLEFT", 20, y_offset);
            icon:SetPoint("TOPLEFT", 5, y_offset -4);
            y_offset = y_offset - 15;

            bf[view.side].buffs[i].checkbutton = checkbtn;
            bf[view.side].buffs[i].icon = icon;
        end
    end
end

local function create_sw_ui_calculator_frame(pframe)

    pframe.calculator_plan_changed = true;

    pframe:HookScript("OnHide", function()
        sc.loadouts.force_update = true;
        sc.core.deactivate_tooltip_refresh();
    end);

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["While this tab is open, ability overlay & tooltips reflect the change below"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 22;

    -- plan row: everything above the subtabs is about the whole plan
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset - 9);
    f_txt:SetText(L["Plan:"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    local plan_label = f_txt;

    local function plan_button(text)
        local btn = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
        btn:SetHeight(22);
        btn:SetText(text);
        btn:SetWidth(math.max(50, math.ceil(btn:GetFontString():GetStringWidth()) + 20));
        return btn;
    end

    -- the buttons are placed from the right edge
    f = plan_button(L["Delete"]);
    f:SetPoint("TOPRIGHT", 0, pframe.y_offset - 4);
    f:SetScript("OnClick", function(self)
        if working_name ~= "" then

            __sc_p_char.calculator_saves[working_name] = nil;
            pframe.save_plan_btn:Disable();

            working_name = "";
            pframe.plan_dd.init_func(L["Saved plans"]);

            self:Disable();
        end
    end);
    f:Disable();
    pframe.delete_plan_btn = f;

    f = CreateFrame("EditBox", nil, pframe, "InputBoxTemplate");
    f:SetPoint("RIGHT", pframe.delete_plan_btn, "LEFT", -8, 0);
    f:SetSize(90, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            pframe.plan_name_empty:Show();
            pframe.save_plan_as_btn:Disable();
        else
            pframe.plan_name_empty:Hide();
            pframe.save_plan_as_btn:Enable();
        end
    end);
    pframe.new_plan_name_editbox = f;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["New plan name"]);
    f:SetPoint("LEFT", pframe.new_plan_name_editbox, 5, 0);
    pframe.plan_name_empty = f;

    f = plan_button(L["Save as"]);
    f:SetPoint("RIGHT", pframe.new_plan_name_editbox, "LEFT", -10, 0);
    f:SetScript("OnClick", function(self)

        local plan_name = pframe.new_plan_name_editbox:GetText();
        if plan_name ~= "" then

            working_name = plan_name;
            save_calculator_plan(plan_name);
            pframe.plan_dd.init_func(plan_name);
            pframe.new_plan_name_editbox:SetText("");

            pframe.save_plan_btn:Enable();
            pframe.delete_plan_btn:Enable();
        end
    end);
    f:Disable();
    pframe.save_plan_as_btn = f;

    f = plan_button(L["Save"]);
    f:SetPoint("RIGHT", pframe.save_plan_as_btn, "LEFT", -4, 0);
    f:SetScript("OnClick", function(self)
        save_calculator_plan(working_name);
        pframe.plan_dd.init_func(working_name);
    end);
    f:Disable();
    pframe.save_plan_btn = f;

    -- the dropdown gets the width the buttons leave, its art reaches about 45 beyond the set width
    local buttons_width = pframe.delete_plan_btn:GetWidth() + 8 + pframe.new_plan_name_editbox:GetWidth() + 10 +
        pframe.save_plan_as_btn:GetWidth() + 4 + pframe.save_plan_btn:GetWidth();
    local plan_dd_width = math.max(60, math.min(120,
        pframe:GetWidth() - buttons_width - plan_label:GetStringWidth() - 55));

    pframe.plan_dd = libDD:Create_UIDropDownMenu(nil, pframe);
    pframe.plan_dd:SetPoint("LEFT", plan_label, "RIGHT", -5, -3);
    pframe.plan_dd.init_func = function(plan_name)
        libDD:UIDropDownMenu_Initialize(pframe.plan_dd, function()

            libDD:UIDropDownMenu_SetWidth(pframe.plan_dd, plan_dd_width);
            libDD:UIDropDownMenu_SetText(pframe.plan_dd, plan_name);

            for name, plan in pairs(__sc_p_char.calculator_saves) do

                libDD:UIDropDownMenu_AddButton({
                    text = name,
                    checked = name == working_name,
                    func = function()

                        pframe.save_plan_btn:Enable();
                        pframe.delete_plan_btn:Enable();

                        load_calculator_plan(plan);
                        working_name = name;
                        pframe.plan_dd.init_func(name);
                        update_calculator_item_planner();
                        -- Texture may be unavailable when loaded cold
                        -- Try again in 1 second
                        C_Timer.After(1.0, update_calculator_item_planner);
                    end
                });
            end
        end);
    end;
    pframe.plan_dd.init_func(L["Saved plans"]);

    pframe.y_offset = pframe.y_offset - 32;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 8;

    -- result row: Before -> Spells, Stats -> After, hover for the text, click to copy it
    pframe.diffs_txt = "";

    local function stats_txt(effects)
        return effects and (stats_format(active_loadout(), effects));
    end

    local arrow_tex_path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up";
    local box_spacing = 5;
    local flow_arrow_size = 20;
    local flow_arrow_space = flow_arrow_size + 2 * box_spacing;
    local end_box_width = 90;
    local change_box_width = math.floor((pframe:GetWidth() - 2 * end_box_width - 2 * flow_arrow_space - box_spacing) / 2);
    local box_x = 0;
    local function flow_arrow()
        local arrow = pframe:CreateTexture(nil, "ARTWORK");
        arrow:SetTexture(arrow_tex_path);
        arrow:SetTexCoord(0.3, 0.7, 0.3, 0.7);
        arrow:SetSize(flow_arrow_size, flow_arrow_size);
        arrow:SetPoint("TOPLEFT", box_x + box_spacing, pframe.y_offset - (30 - flow_arrow_size) / 2);
        box_x = box_x + flow_arrow_space;
        return arrow;
    end
    local function result_box(text, width)
        local box = CreateFrame("Frame", nil, pframe, "BackdropTemplate");
        box:SetSize(width, 30);
        box:SetPoint("TOPLEFT", box_x, pframe.y_offset);
        box_x = box_x + width;
        box:EnableMouse(true);
        box:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
        box:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 2; -- thickness of the border
        });
        box:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
        box:SetBackdropBorderColor(1, 0.8, 0, 1);

        local fstr = box:CreateFontString(nil, "OVERLAY");
        fstr:SetFontObject(GameFontNormal);
        local fp, _, flags = fstr:GetFont();
        fstr:SetFont(fp, 15, flags);
        fstr:SetPoint("CENTER");
        fstr:SetText(text);
        box.fontstr = fstr;

        local arrow = box:CreateTexture(nil, "ARTWORK");
        arrow:SetTexture(arrow_tex_path);
        arrow:SetPoint("BOTTOMRIGHT", -2, 2);
        arrow:SetTexCoord(0.3, 0.7, 0.3, 0.7);
        arrow:SetSize(8, 8);
        arrow:SetRotation(-3.14592/4);

        -- box.flash(): a gold glow pulsing twice, for a result that just changed
        local glow = box:CreateTexture(nil, "OVERLAY");
        glow:SetAllPoints(box);
        glow:SetColorTexture(1, 0.8, 0, 1);
        glow:SetBlendMode("ADD");
        glow:SetAlpha(0);
        local flash = glow:CreateAnimationGroup();
        for i, v in ipairs({ { 0, 0.4, 0.12 }, { 0.4, 0, 0.3 }, { 0, 0.4, 0.12 }, { 0.4, 0, 0.45 } }) do
            local a = flash:CreateAnimation("Alpha");
            a:SetFromAlpha(v[1]);
            a:SetToAlpha(v[2]);
            a:SetDuration(v[3]);
            a:SetOrder(i);
        end
        box.flash = function()
            flash:Stop();
            flash:Play();
        end;
        return box;
    end

    local before_area = result_box(L["Before"], end_box_width);
    before_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["Before"]);
        else
            GameTooltip:SetText(L["Before (simplified)"]);
        end

        GameTooltip:AddLine(stats_txt(pframe.stats_effects));
        GameTooltip:Show();
    end);
    before_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["Before"],
            stats_txt(pframe.stats_effects),
            300,
            400
        );
    end);
    pframe.before_area = before_area;

    pframe.flow_arrow_before = flow_arrow();
    local spells_area = result_box(L["Spells"], change_box_width);
    spells_area:SetScript("OnEnter", function(self)
        self.tooltip_mod = sc.core.key_mod_flags();
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(L["Spells"]);
        write_plan_spells_tooltip(GameTooltip, self.tooltip_mod);
    end);
    -- the shown tooltip calls its owner's UpdateTooltip every 0.2 s: redrawn when a modifier key changed,
    -- update_calc_list redraws it when the numbers change
    spells_area.UpdateTooltip = function(self)
        if sc.core.key_mod_flags() ~= self.tooltip_mod then
            self:GetScript("OnEnter")(self);
        end
    end;
    spells_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["Spells"],
            plan_spells_text(sc.core.key_mod_flags()),
            400,
            400
        );
    end);
    pframe.spells_area = spells_area;
    pframe.spells_fontstr = spells_area.fontstr;

    box_x = box_x + box_spacing;
    local diffs_area = result_box(L["Stats"], change_box_width);
    diffs_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["Changes"]);
        else
            GameTooltip:SetText(L["Changes (simplified)"]);
        end
        GameTooltip:AddLine(pframe.diffs_txt);
        GameTooltip:Show();
    end);
    diffs_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["Effect changes"],
            pframe.diffs_txt,
            300,
            400
        );
    end);
    pframe.diffs_area = diffs_area;
    pframe.diffs_fontstr = diffs_area.fontstr;

    pframe.flow_arrow_after = flow_arrow();
    local after_area = result_box(L["After"], end_box_width);
    after_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["After"]);
        else
            GameTooltip:SetText(L["After (simplified)"]);
        end
        GameTooltip:AddLine(stats_txt(pframe.stats_effects_diffed));
        GameTooltip:Show();
    end);
    after_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["After"],
            stats_txt(pframe.stats_effects_diffed),
            300,
            400
        );
    end);
    pframe.after_area = after_area;

    -- the subtab row takes the 34 above the subframes
    pframe.y_offset = pframe.y_offset - 30 - 38;

    local tabs = {
        {"items", L["Item planner"]},
        {"stats", L["Custom stats"]},
        {"talents", L["Talents"]},
        {"buffs", L["Buffs"]},
    };

    create_subtabs(pframe, tabs);
    local subframe_height = pframe:GetHeight() + pframe.y_offset;

    pframe.items.working = working_item_plan;
    pframe.stats.working = working_stats;
    pframe.talents.working = working_talents;
    pframe.buffs.working = working_buffs;

    pframe.buffs.on_show = function()
        update_buffs_frame(pframe.buffs);
    end;
    pframe.talents.on_show = update_talents_frame;

    -- Item planner subframe
    create_calculator_items_subframe(pframe);


    -- Manual stats tabbed subframe
    create_calculator_stats_subframe(pframe);

    -- Talents tabbed subframe
    create_calculator_talents_subframe(pframe);

    -- Buffs tabbed subframe
    do
        local bf = pframe.buffs;
        bf.buffs_cfg = function()
            return working_buffs;
        end;
        bf.list_enabled = function()
            return working_buffs.use_custom;
        end;
        bf.on_update = function()
            pframe.buffs_tab:set_changed(working_buffs.use_custom);
            bf.custom_buffs_btn:SetChecked(working_buffs.use_custom);
            bf.preserve_buffs_btn:SetChecked(working_buffs.preserve_active);
        end;
        bf.lname_to_id = forced_buffs_lname_to_id;
        bf.name_prefix = "__sc_frame_buffs_";

        bf.y_offset = bf.y_offset - 5;

        f = CreateFrame("CheckButton", "__sc_frame_calculator_custom_buffs", bf, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", bf, 0, bf.y_offset);
        getglobal(f:GetName() .. 'Text'):SetText(L["Apply selected"]);
        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;
            pframe.calculator_plan_changed = true;
            working_buffs.use_custom = self:GetChecked();
            update_buffs_frame(bf);
        end);
        bf.custom_buffs_btn = f;

        f = CreateFrame("CheckButton", "__sc_frame_calculator_preserve_buffs", bf, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", bf, 173, bf.y_offset);
        getglobal(f:GetName() .. 'Text'):SetText(L["Preserve active"]);
        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;
            pframe.calculator_plan_changed = true;
            working_buffs.preserve_active = self:GetChecked();
        end);
        bf.preserve_buffs_btn = f;

        bf.legend_y_offset = bf.y_offset - 8;
        bf.y_offset = bf.y_offset - 25;

        -- create_buffs_list puts the two lists 36 below its y offset, they reach down to the bottom
        bf.list_height = subframe_height + bf.y_offset - 36 - 5;
        create_buffs_list(bf);
        bf.fadeable_checkboxes[#bf.fadeable_checkboxes + 1] = bf.preserve_buffs_btn;
    end

    update_calculator_item_planner();
    pframe.items_tab:Click();
end

ui.create_buffs_list                 = create_buffs_list;
ui.create_sw_ui_calculator_frame     = create_sw_ui_calculator_frame;
ui.effects_from_ui_stats_diff        = effects_from_ui_stats_diff;
ui.forced_buffs_lname_to_id          = forced_buffs_lname_to_id;
ui.update_buffs_frame                = update_buffs_frame;
ui.update_calculator_character_items = update_calculator_character_items;
ui.update_talents_frame              = update_talents_frame;
