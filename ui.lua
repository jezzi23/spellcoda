local _, sc = ...;

local L                                         = sc.L;

local spells                                    = sc.spells;
local spids                                     = sc.spids;
local spell_flags                               = sc.spell_flags;

local format_locale_dump                        = sc.loc.format_locale_dump;

local assign_color_tag                          = sc.utils.assign_color_tag;
local highest_learned_rank                      = sc.utils.highest_learned_rank;
local effect_color                              = sc.utils.effect_color;

local wowhead_talent_link                       = sc.talents.wowhead_talent_link;
local wowhead_talent_code_from_url              = sc.talents.wowhead_talent_code_from_url;

local fight_types                               = sc.calc.fight_types;
local evaluation_flags                          = sc.calc.evaluation_flags;

local format_number                             = sc.utils.format_number;
local color_by_lvl_diff                         = sc.utils.color_by_lvl_diff;

local update_loadout_and_effects_diffed_from_ui = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local update_loadout_and_effects                = sc.loadouts.update_loadout_and_effects;
local active_loadout                            = sc.loadouts.active_loadout

local spell_diff                                = sc.calc.spell_diff;
local calc_spell_eval                           = sc.calc.calc_spell_eval;

local buff_category                             = sc.buffs.buff_category;
local buffs                                     = sc.buffs.buffs;
local target_buffs                              = sc.buffs.target_buffs;

local config                                    = sc.config;

-------------------------------------------------------------------------
local ui = {};

local __sc_frame = {};

local role_icons = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES";
local font = "GameFontHighlightSmall";
local libstub_data_broker = LibStub("LibDataBroker-1.1", true);
local libstub_icon = libstub_data_broker and LibStub("LibDBIcon-1.0", true);
local libstub_launcher;
local libDD = LibStub("LibUIDropDownMenu-4.0", true);

local colored_text_frames = {};
local function register_text_frame_color(frame, color_tag)
    colored_text_frames[frame] = color_tag;
end


-- Dump frame for things like getting missing strings for localization
local dump_frame = CreateFrame("Frame", "__sc_dump_frame", UIParent, "BackdropTemplate");
dump_frame:SetSize(600, 400);
dump_frame:SetPoint("CENTER");
dump_frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
});
dump_frame:SetBackdropColor(0, 0, 0, 0.8);
dump_frame:EnableMouse(true);
dump_frame:SetMovable(true);
dump_frame:RegisterForDrag("LeftButton");
dump_frame:SetScript("OnDragStart", dump_frame.StartMoving);
dump_frame:SetScript("OnDragStop", dump_frame.StopMovingOrSizing);
dump_frame:Hide();

local title_text = dump_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title_text:SetPoint("TOP", 0, -10);
title_text:SetText("");

local close_button = CreateFrame("Button", nil, dump_frame, "UIPanelCloseButton");
close_button:SetPoint("TOPRIGHT", dump_frame, "TOPRIGHT", -5, -5);

local scroll_frame = CreateFrame("ScrollFrame", nil, dump_frame, "UIPanelScrollFrameTemplate");
scroll_frame:SetPoint("TOPLEFT", 10, -30);
scroll_frame:SetPoint("BOTTOMRIGHT", -30, 10);

local edit_box = CreateFrame("EditBox", nil, scroll_frame);
edit_box:SetMultiLine(true);
edit_box:SetFontObject(ChatFontNormal);
edit_box:SetWidth(550);
edit_box:SetAutoFocus(false);
edit_box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
scroll_frame:SetScrollChild(edit_box);

local function dump_text(title, text)
    title_text:SetText(title);
    edit_box:SetText(text);
    dump_frame:Show();
    edit_box:HighlightText();
end


local function display_spell_diff(i, calc_list, diff, frame)
    if not calc_list[i] then
        calc_list[i] = {};

        frame.y_offset = frame.y_offset - 15;
        calc_list[i].name_str = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].name_str:SetFontObject(font);
        calc_list[i].name_str:SetPoint("TOPLEFT", 5, frame.y_offset);

        calc_list[i].role_icon = CreateFrame("Frame", nil, frame);
        calc_list[i].role_icon:SetSize(15, 15);
        calc_list[i].role_icon:SetPoint("TOPLEFT", 225, frame.y_offset+2);
        calc_list[i].role_icon.tex = calc_list[i].role_icon:CreateTexture(nil, "ARTWORK");
        calc_list[i].role_icon.tex:SetTexture(role_icons);

        calc_list[i].change = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].change:SetFontObject(font);
        calc_list[i].change:SetPoint("TOPLEFT", 255, frame.y_offset);
        calc_list[i].first = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].first:SetFontObject(font);
        calc_list[i].first:SetPoint("TOPLEFT", 325, frame.y_offset);
        calc_list[i].second = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].second:SetFontObject(font);
        calc_list[i].second:SetPoint("TOPLEFT", 390, frame.y_offset);


        calc_list[i].cancel_button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
        calc_list[i].cancel_button:SetScript("OnClick", function(self)
            config.settings.spell_calc_list[self.__id_src] = nil;
            for k, v in pairs(calc_list[frame.num_spells]) do
                v:Hide();
            end
            ui.update_calc_list();
        end);

        calc_list[i].cancel_button:SetPoint("TOPRIGHT", -10, frame.y_offset + 4);
        calc_list[i].cancel_button:SetSize(17, 17);
        calc_list[i].cancel_button:SetText("x");
        local fontstr = calc_list[i].cancel_button:GetFontString();
        if fontstr then
            fontstr:ClearAllPoints();
            fontstr:SetPoint("CENTER", calc_list[i].cancel_button, "CENTER");
            fontstr:SetIgnoreParentAlpha(true);
            fontstr:SetMouseClickEnabled(false);
        end
        calc_list[i].cancel_button:SetFrameLevel(calc_list[i].cancel_button:GetFrameLevel() + 1);
    end
    local v = calc_list[i];

    v.cancel_button.__id_src = diff.original_id;

    v.name_str:SetText(diff.disp);

    v.name_str:SetTextColor(222/255, 192/255, 40/255);

    if diff.heal_like then
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.0, 0.25);
    else
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.25, 0.5);
    end
    v.role_icon.tex:SetAllPoints(v.role_icon);

    local change_fmt = format_number(diff.diff_ratio, 2);
    local change = change_fmt.."%";
    if not diff.diff_ratio  then
        change = "";
    elseif change_fmt == "∞" then
        v.change:SetTextColor(1, 1, 1);
    elseif diff.diff_ratio < 0 then
        v.change:SetTextColor(195/255, 44/255, 11/255);
        change = change;
    elseif diff.diff_ratio > 0 then
        v.change:SetTextColor(33/255, 185/255, 21/255);
        change = "+"..change;
    else
        v.change:SetTextColor(1, 1, 1);
    end
    v.change:SetText(change);

    local first = format_number(diff.first, 2);
    if not diff.first then
        first = "";
    elseif first == "∞" then
        v.first:SetTextColor(1, 1, 1);
    elseif diff.first < 0 then
        v.first:SetTextColor(195/255, 44/255, 11/255);
    elseif diff.first > 0 then
        v.first:SetTextColor(33/255, 185/255, 21/255);
        first = "+"..first;
    else
        v.first:SetTextColor(1, 1, 1);
    end
    v.first:SetText(first);

    local second = format_number(diff.second, 2);
    if not diff.second then
        second = "";
    elseif second == "∞" then
        v.second:SetTextColor(1, 1, 1);
    elseif diff.second < 0 then
        v.second:SetTextColor(195/255, 44/255, 11/255);
    elseif diff.second > 0 then
        v.second:SetTextColor(33/255, 185/255, 21/255);
        second = "+"..second;
    else
        v.second:SetTextColor(1, 1, 1);
    end
    v.second:SetText(second);
    ------------------

    for _, f in pairs(v) do
        f:Show();
    end
    if diff.is_dual_spell then
        calc_list[i].cancel_button:Hide();
    end
end


local cached_spells_cmp_diffs = {};

local function update_calc_list(loadout, effects, effects_diffed, eval_flags)

    local frame = __sc_frame.calculator_frame;
    for _, v in pairs(frame.calc_list) do
        for _, f in pairs(v) do
            f:Hide();
        end
    end
    if not loadout then
        loadout, effects, effects_diffed = update_loadout_and_effects_diffed_from_ui();
        eval_flags = sc.overlay.overlay_eval_flags();
    end

    eval_flags = bit.bor(eval_flags, evaluation_flags.expectation_of_self);

    local i = 0;
    for k, _ in pairs(config.settings.spell_calc_list) do

        local original_k = k;
        if config.settings.calc_list_use_highest_rank and spells[k] then
            k = highest_learned_rank(spells[k].base_id);
        end
        if k and spells[k] and bit.band(spells[k].flags, spell_flags.eval) ~= 0 then

            i = i + 1;
            cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

            spell_diff(cached_spells_cmp_diffs[i],
                       config.settings.calc_fight_type,
                       spells[k],
                       k,
                       loadout,
                       effects,
                       effects_diffed,
                       eval_flags);

            cached_spells_cmp_diffs[i].is_dual_spell = spells[k].healing_version ~= nil;
            cached_spells_cmp_diffs[i].original_id = original_k;


            -- for spells with both heal and dmg
            if spells[k].healing_version then

                i = i + 1;
                cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

                spell_diff(cached_spells_cmp_diffs[i],
                           config.settings.calc_fight_type,
                           spells[k].healing_version,
                           k,
                           loadout,
                           effects,
                           effects_diffed,
                           eval_flags);
                cached_spells_cmp_diffs[i].is_dual_spell = false;
                cached_spells_cmp_diffs[i].original_id = original_k;
            end
        end
    end
    __sc_frame.calculator_frame.num_spells = i;

    for j = 1, i do
        ui.display_spell_diff(j, frame.calc_list, cached_spells_cmp_diffs[j], frame);
    end
    frame.spells_add_tip:SetPoint("TOPLEFT", 5, frame.y_offset-20);

end

-- generalize some reasonable editbox config that need to update on change
-- that is easy to exit / lose focus
local function editbox_config(frame, update_func, close_func)
    close_func = close_func or update_func;
    frame:SetScript("OnEnterPressed", function(self)
        close_func(self);
        self:ClearFocus();
    end);
    frame:SetScript("OnEscapePressed", function(self)
        close_func(self);
        self:ClearFocus();
    end);
    frame:SetScript("OnEditFocusLost", close_func);
    frame:SetScript("OnTextChanged", update_func);
    frame:SetScript("OnTextSet", update_func);
end

local filtered_buffs = {};
local filtered_target_buffs = {};
local buffs_views = {
    {side = "lhs", subject = "self", buffs = buffs, filtered = filtered_buffs},
    {side = "rhs", subject = "target_buffs", buffs = target_buffs, filtered = filtered_target_buffs}
};

local function update_buffs_frame()

    sc.loadouts.force_update = true;

    local buffs_list_alpha = 1.0;

    if not config.loadout.force_apply_buffs then
        buffs_list_alpha = 0.2;
    end

    for _, view in ipairs(buffs_views) do

        local n = #view.filtered;

        for _, v in ipairs(__sc_frame.buffs_frame[view.side].buffs) do
            v.checkbutton:Hide();
            v.checkbutton.__stacks_str:Hide();
            v.icon:Hide();
        end

        local buff_frame_idx = math.floor(__sc_frame.buffs_frame[view.side].slider:GetValue());

        for _, v in ipairs(__sc_frame.buffs_frame[view.side].buffs) do

            if buff_frame_idx > n then
                break;
            end
            local buff_info = view.buffs[view.filtered[buff_frame_idx]];
            v.checkbutton.buff_id = buff_info.id;

            if v.checkbutton.side == "lhs" then
                if config.loadout.buffs[buff_info.id] then
                    v.checkbutton:SetChecked(true);
                    v.checkbutton.__stacks_str:SetText(tostring(config.loadout.buffs[buff_info.id]));
                else
                    v.checkbutton:SetChecked(false);
                    v.checkbutton.__stacks_str:SetText("0");
                end
            else
                if config.loadout.target_buffs[buff_info.id] then
                    v.checkbutton:SetChecked(true);
                    v.checkbutton.__stacks_str:SetText(tostring(config.loadout.target_buffs[buff_info.id]));
                else
                    v.checkbutton:SetChecked(false);
                    v.checkbutton.__stacks_str:SetText("0");
                end
            end

            v.icon.tex:SetTexture(GetSpellTexture(buff_info.id));

            local buff_name_max_len = 28;
            local name_appear =  buff_info.lname;
            getglobal(v.checkbutton:GetName() .. 'Text'):SetText(name_appear:sub(1, buff_name_max_len));
            local checkbutton_txt = getglobal(v.checkbutton:GetName() .. 'Text');
            if buff_info.cat == buff_category.class  then
                checkbutton_txt:SetTextColor(0/255, 204/255, 255/255);
            elseif buff_info.cat == buff_category.player  then
                checkbutton_txt:SetTextColor(225/255, 235/255, 52/255);
            elseif buff_info.cat == buff_category.friendly  then
                checkbutton_txt:SetTextColor(0/255, 153/255, 51/255);
            elseif buff_info.cat == buff_category.hostile  then
                checkbutton_txt:SetTextColor(235/255, 52/255, 88/255);
            elseif buff_info.cat == buff_category.enchant  then
                checkbutton_txt:SetTextColor(103/255, 52/255, 235/255);
            end

            v.checkbutton:Show();
            v.checkbutton.__stacks_str:Show();
            v.icon:Show();

            buff_frame_idx = buff_frame_idx + 1;
        end
        __sc_frame.buffs_frame[view.side].frame:SetAlpha(buffs_list_alpha);
    end

end

local function update_loadout_frame()

    sc.loadouts.force_update = true;

    sc.config.activate_loadout_config();

    __sc_frame.loadout_frame.loadout_dropdown.init_func();

    if #__sc_p_char.loadouts == 1 then
        __sc_frame.loadout_frame.delete_button:Hide();
    else
        __sc_frame.loadout_frame.delete_button:Show();
    end

    if __sc_frame.loadout_frame.new_loadout_name_editbox:GetText() == "" then
        for _, v in pairs(__sc_frame.loadout_frame.new_loadout_section) do
            v:Hide();
        end
    else
        for _, v in pairs(__sc_frame.loadout_frame.new_loadout_section) do
            v:Show();
        end
    end

    __sc_frame.calculator_frame.loadout_name_label:SetText(
        L["Active loadout: "]..config.loadout.name
    );
    for _, v in pairs(__sc_frame.loadout_frame.auto_armor_frames) do
        if config.loadout.target_automatic_armor_pct == v._value then
            v:Click();
        end
    end

    __sc_frame.loadout_frame.talent_editbox:SetText(""); -- forces editbox to update

    update_buffs_frame();

    update_calc_list();
end

local spell_filter_listing;
local spell_filters;
local spell_browser_sort_options;
local spell_browser_sort_keys = {
    lvl = 1,
    dps = 2,
    hps = 3,
    dpc = 4,
    hpc = 5,
};

local spell_browser_active_sort_key = spell_browser_sort_keys.lvl;
-- meant to happen only the first time
local spell_browser_scroll_to_lvl = true;

local function filtered_spell_view(spell_ids, name_filter, loadout, effects, eval_flags)

    local lvl = active_loadout().lvl;
    local next_lvl = lvl + 1;
    if lvl % 2 == 0 then
        next_lvl = lvl + 2;
    end
    local avail_cost = 0;
    local next_cost = 0;
    local total_cost = 0;
    local filtered = {};
    local i = 1
    for _, id in pairs(spell_ids) do
        --local known = IsSpellKnown(id);
        local known = IsSpellKnownOrOverridesKnown(id);
        if not known then
            known = IsSpellKnownOrOverridesKnown(id, true);
        end
        if not known then
            -- deal with spells that you unlearn when you have a higher rank
            local highest = highest_learned_rank(spells[id].base_id);
            if spells[highest] then
                known = spells[highest].rank > spells[id].rank;
            end
        end
        if name_filter ~= "" and not string.find(string.lower(GetSpellInfo(id)), string.lower(name_filter)) then
        elseif config.settings.spells_filter_already_known and known then
            filtered[i] = {spell_id = id, trigger = spell_filters.spells_filter_already_known};
        elseif config.settings.spells_filter_available and
            lvl >= spells[id].lvl_req and not known then
            filtered[i] = {spell_id = id, trigger = spell_filters.spells_filter_available};
        elseif config.settings.spells_filter_unavailable and
            lvl < spells[id].lvl_req then
            filtered[i] = {spell_id = id, trigger = spell_filters.spells_filter_unavailable};
        end

        if not config.settings.spells_filter_learned_from_item and
            spells[id].train < 0 then
            filtered[i] = nil;
        end
        if not config.settings.spells_filter_pet and
            bit.band(spells[id].flags, spell_flags.pet) ~= 0 then
            filtered[i] = nil;
        end
        if not config.settings.spells_filter_ignored_spells and
            config.settings.spells_ignore_list[id] then
            filtered[i] = nil;
        end
        if not config.settings.spells_filter_other_spells and
            spells[id].train == 0 then
            filtered[i] = nil;
        end
        if config.settings.spells_filter_only_highest_learned_ranks then
            local highest_learned = highest_learned_rank(spells[id].base_id);
            if not highest_learned or highest_learned ~= id then
                filtered[i] = nil;
            end
        end
        if spells[id].race_flags and bit.band(spells[id].race_flags, bit.lshift(1, sc.race-1)) == 0 then
            filtered[i] = nil;
        end
        if filtered[i] then
            -- spell i is in list
            if spells[id].train > 0 then
                if spells[id].lvl_req == next_lvl then
                    next_cost = next_cost + spells[id].train;
                end
                if filtered[i].trigger == spell_filters.spells_filter_available then
                    avail_cost = avail_cost + spells[id].train;
                end
                if filtered[i].trigger ~= spell_filters.spells_filter_already_known then
                    total_cost = total_cost + spells[id].train;
                end
            end
            -- comparable fields
            filtered[i].dps = 0;
            filtered[i].hps = 0;
            filtered[i].dpc = 0;
            filtered[i].hpc = 0;
            if bit.band(spells[id].flags, spell_flags.eval) ~= 0 then
                local info = calc_spell_eval(spells[id], loadout, effects, eval_flags, id);
                filtered[i].effect_per_sec = info.effect_per_sec;
                filtered[i].effect_per_cost = info.effect_per_cost;
                if bit.band(spells[id].flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                    filtered[i].dps = info.effect_per_sec;
                    filtered[i].dpc = info.effect_per_cost;
                else
                    filtered[i].hps = info.effect_per_sec;
                    filtered[i].hpc = info.effect_per_cost;
                end
            end
            i = i + 1;
            if spells[id].healing_version then
                filtered[i] = {};
                for k, v in pairs(filtered[i-1]) do
                    filtered[i][k] = v;
                end
                filtered[i].is_dual = true;

                local info = calc_spell_eval(spells[id].healing_version, loadout, effects, eval_flags, id);
                filtered[i].effect_per_sec = info.effect_per_sec;
                filtered[i].effect_per_cost = info.effect_per_cost;
                filtered[i].hps = info.effect_per_sec;
                filtered[i].hpc = info.effect_per_cost;
                filtered[i].dps = 0;
                filtered[i].dpc = 0;

                i = i + 1;
            end
        end
    end
    local cost_str = "";
    if avail_cost ~= 0 then
        cost_str = cost_str.."   |cFF00FF00"..L["Available cost:"].."|r "..GetCoinTextureString(avail_cost);
    end
    if next_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF8C00"..L["Next level"].." "..next_lvl..L[" cost:"].."|r "..GetCoinTextureString(next_cost);
    end
    if total_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF0000"..L["Total cost:"].."|r "..GetCoinTextureString(total_cost);
    end
    __sc_frame.spells_frame.footer_cost:SetText(cost_str);

    if spell_browser_active_sort_key == spell_browser_sort_keys.lvl then
        __sc_frame.spells_frame.header_level:Hide();
        local filtered_with_level_barriers = {};
        -- injects level brackets into the filtered list
        local prev_lvl = -1;
        local i = 1;
        for _, v in pairs(filtered) do
            if spells[v.spell_id].lvl_req ~= prev_lvl then
                filtered_with_level_barriers[i] = {lvl_barrier = spells[v.spell_id].lvl_req, trigger_flag = 0};
                prev_lvl = spells[v.spell_id].lvl_req;
                i = i + 1;
            end
            filtered_with_level_barriers[i] = v;
            i = i + 1;
        end
        filtered = filtered_with_level_barriers;
    else
        -- filtered only contains spell ids from here
        __sc_frame.spells_frame.header_level:Show();

        if spell_browser_active_sort_key == spell_browser_sort_keys.dps then
            table.sort(filtered, function(lhs, rhs) return lhs.dps > rhs.dps; end);
        elseif spell_browser_active_sort_key == spell_browser_sort_keys.hps then
            table.sort(filtered, function(lhs, rhs) return lhs.hps > rhs.hps; end);
        elseif spell_browser_active_sort_key == spell_browser_sort_keys.dpc then
            table.sort(filtered, function(lhs, rhs) return lhs.dpc > rhs.dpc; end);
        elseif spell_browser_active_sort_key == spell_browser_sort_keys.hpc then
            table.sort(filtered, function(lhs, rhs) return lhs.hpc > rhs.hpc; end);
        end
    end

    return filtered;
end


local function populate_scrollable_spell_view(view, starting_idx)
    local cnt = 1;
    local n = #__sc_frame.spells_frame.scroll_view;
    local list_len = #view;
    local i = starting_idx;
    local lvl = active_loadout().lvl;

    -- clear previous
    for _, v in pairs(__sc_frame.spells_frame.scroll_view) do
        for _, e in pairs(v) do
            e:Hide();
        end
    end
    while cnt <= n and i <= list_len do
        local v = view[i];
        local line = __sc_frame.spells_frame.scroll_view[cnt];
        if v.spell_id then
            --line.spell_icon.__id = v.spell_id;
            line.tooltip_area.__id = v.spell_id;
            line.spell_tex:SetTexture(GetSpellTexture(v.spell_id));
            line.spell_icon:Show();
            line.spell_tex:Show();
            line.tooltip_area:Show();
            line.dropdown_menu.__spid = v.spell_id;
            line.dropdown_button:Show();

            if spells[v.spell_id].rank ~= 0 then
                line.spell_name:SetText(string.format("%s ("..L["Rank"].." %d)",
                    GetSpellInfo(v.spell_id),
                    spells[v.spell_id].rank
                ));
            else
                line.spell_name:SetText(GetSpellInfo(v.spell_id));
            end
            if v.trigger == spell_filters.spells_filter_already_known then
                line.spell_name:SetTextColor(138 / 255, 134 / 255, 125 / 255);
            elseif v.trigger == spell_filters.spells_filter_available then
                line.spell_name:SetTextColor(0 / 255, 255 / 255,   0 / 255);
            elseif v.trigger == spell_filters.spells_filter_unavailable then
                line.spell_name:SetTextColor(252 / 255,  69 / 255,   3 / 255);
            end
            line.spell_name:Show();
            -- do level per line if not sorting by lvl
            if spell_browser_active_sort_key ~= spell_browser_sort_keys.lvl then
                line.lvl_str:SetText(color_by_lvl_diff(lvl, spells[v.spell_id].lvl_req)..spells[v.spell_id].lvl_req);
                line.lvl_str:Show();
            end
            -- write in currency/book cost column
            if spells[v.spell_id].train > 0 then
                if v.trigger == spell_filters.spells_filter_already_known or v.is_dual then
                    line.cost_str:SetText("");
                else
                    line.cost_str:SetText(GetCoinTextureString(spells[v.spell_id].train));
                end
                line.cost_str:Show();
            elseif spells[v.spell_id].train < 0 then
                if v.trigger == spell_filters.spells_filter_already_known or v.is_dual then
                else
                    line.book_icon.__id = -spells[v.spell_id].train;
                    line.book_tex:SetTexture(GetItemIcon(-spells[v.spell_id].train));
                    line.book_tex:Show();
                    line.book_icon:Show();
                end
            else
                if v.trigger == spell_filters.spells_filter_already_known or v.is_dual then
                else
                    line.cost_str:SetText(L["Unknown"]);
                    line.cost_str:Show();
                end
            end
            if bit.band(spells[v.spell_id].flags, spell_flags.eval) ~= 0 then
                if v.is_dual or bit.band(spells[v.spell_id].flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
                    line.effect_type_tex:SetTexCoord(0.25, 0.5, 0.0, 0.25);
                else
                    line.effect_type_tex:SetTexCoord(0.25, 0.5, 0.25, 0.5);
                end
                line.effect_type_tex:SetAllPoints(line.effect_type_icon);
                line.effect_type_tex:Show();
                line.effect_type_icon:Show();
                line.per_sec_str:SetText(format_number(v.effect_per_sec, 1));
                line.per_cost_str:SetText(format_number(v.effect_per_cost, 2));
                line.type_str:Show();
                line.per_sec_str:Show();
                line.per_cost_str:Show();
            end
            if config.settings.spells_ignore_list[v.spell_id] then
                line.ignore_line:Show();
            end

        elseif v.lvl_barrier then
            line.spell_name:SetText("<<< "..L["Level"].." "..color_by_lvl_diff(lvl, v.lvl_barrier)..v.lvl_barrier.."|cFFFFFFFF >>>");
            line.spell_name:SetTextColor(1.0, 1.0, 1.0);
            line.spell_name:Show();
        end
        i = i + 1;
        cnt = cnt + 1;
    end
end

local spell_view_update_id = 0;

local function update_spells_frame(loadout, effects, eval_flags, force_refresh)

    if not loadout then
        local update_id;
        eval_flags = sc.overlay.overlay_eval_flags();
        loadout, _, effects, update_id = update_loadout_and_effects();

        if update_id > spell_view_update_id then
            spell_view_update_id = update_id;
        else
            if not force_refresh then
                return;
            end
        end
    end

    local view = filtered_spell_view(
        sc.spells_lvl_ordered,
        __sc_frame.spells_frame.search:GetText(),
        loadout,
        effects,
        eval_flags
    );
    __sc_frame.spells_frame.filtered_list = view;
    __sc_frame.spells_frame.slider:SetMinMaxValues(
        1,
        math.max(1, #view - math.floor(#__sc_frame.spells_frame.scroll_view/2))
    );
    if spell_browser_scroll_to_lvl then
        local suitable_idx = 1;
        local lvl = active_loadout().lvl;
        for k, v in pairs(view) do
            if v.spell_id and lvl <= spells[v.spell_id].lvl_req then
                suitable_idx = k;
                break;
            end
        end
        suitable_idx = math.max(1, suitable_idx-10);
        __sc_frame.spells_frame.slider_val = suitable_idx;
        spell_browser_scroll_to_lvl = false;
    end
    __sc_frame.spells_frame.slider:SetValue(__sc_frame.spells_frame.slider_val);
    populate_scrollable_spell_view(view, math.floor(__sc_frame.spells_frame.slider_val));
end


local function sw_activate_tab(tab_window)

    __sc_frame:Show();

    for _, v in pairs(__sc_frame.tabs) do
        v.frame_to_open:Hide();
        v:UnlockHighlight();
        v:SetButtonState("NORMAL");
    end

    if tab_window.frame_to_open == __sc_frame.spells_frame then
        update_spells_frame(nil, nil, nil, true);
    elseif tab_window.frame_to_open == __sc_frame.calculator_frame then
        update_calc_list();
    end

    tab_window.frame_to_open:Show();
    tab_window:LockHighlight();
    tab_window:SetButtonState("PUSHED");
end

local function create_sw_spell_id_viewer()

    __sc_frame.spell_id_viewer_editbox = CreateFrame("EditBox", "sw_spell_id_viewer_editbox", __sc_frame, "InputBoxTemplate");
    __sc_frame.spell_id_viewer_editbox:SetPoint("TOPLEFT", __sc_frame, 40, -6);
    __sc_frame.spell_id_viewer_editbox:SetText("");
    __sc_frame.spell_id_viewer_editbox:SetSize(100, 10);
    __sc_frame.spell_id_viewer_editbox:SetAutoFocus(false);


    local tooltip_overwrite_editbox = function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.spell_id_viewer_editbox_label:Show();
        else
            __sc_frame.spell_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if GetSpellInfo(id) or spells[id] then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
        end
        self:ClearFocus();
    end

    __sc_frame.spell_viewer_invalid_spell_id = 204;

    __sc_frame.spell_id_viewer_editbox:SetScript("OnEnterPressed", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnEscapePressed", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnEditFocusLost", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.spell_id_viewer_editbox_label:Show();
        else
            __sc_frame.spell_id_viewer_editbox_label:Hide();
        end
        if spids[txt] then
            self:SetText(tostring(spids[txt]));
        end
        local id = tonumber(txt);
        if id and id <= bit.lshift(1, 31) and (GetSpellInfo(id) or spells[id]) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
            id = 0;
        end

        if id == 0 then
            __sc_frame.spell_icon_tex:SetTexture(GetSpellTexture(265));
        elseif not GetSpellInfo(id) then
            __sc_frame.spell_icon_tex:SetTexture(135791);
        else
            __sc_frame.spell_icon_tex:SetTexture(GetSpellTexture(id));
        end
        GameTooltip:SetOwner(__sc_frame.spell_icon, "ANCHOR_BOTTOMRIGHT");
        if not GetSpellInfo(id) and spells[id] then

            GameTooltip:SetSpellByID(__sc_frame.spell_viewer_invalid_spell_id);
        else
            GameTooltip:SetSpellByID(id);
        end
    end);

    if sc.core.__sw__test_all_spells then
        __sc_frame.spell_id_viewer_editbox:SetText(pairs(spells)(spells));
    end

    __sc_frame.spell_id_viewer_editbox_label = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.spell_id_viewer_editbox_label:SetFontObject(font);
    __sc_frame.spell_id_viewer_editbox_label:SetText(L["Spell ID viewer"]);
    __sc_frame.spell_id_viewer_editbox_label:SetPoint("CENTER", __sc_frame.spell_id_viewer_editbox, 0, 0);

    __sc_frame.spell_icon = CreateFrame("Frame", "__sc_custom_spell_id", __sc_frame);
    __sc_frame.spell_icon:SetSize(17, 17);
    __sc_frame.spell_icon:SetPoint("RIGHT", __sc_frame.spell_id_viewer_editbox, 17, 0);

    local tex = __sc_frame.spell_icon:CreateTexture(nil);
    tex:SetAllPoints(__sc_frame.spell_icon);
    tex:SetTexture(GetSpellTexture(265));
    __sc_frame.spell_icon_tex = tex;


    local tooltip_viewer_on = function(self)
        local txt = __sc_frame.spell_id_viewer_editbox:GetText();
        local id = tonumber(txt);
        if txt == "" then
            id = 265;
        elseif not id then
            id = 0;
        end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
        if not GetSpellInfo(id) and spells[id] then

            GameTooltip:SetSpellByID(__sc_frame.spell_viewer_invalid_spell_id);
        else
            GameTooltip:SetSpellByID(id);
        end
        GameTooltip:Show();
    end
    local tooltip_viewer_off = function(self)
        GameTooltip:Hide();
    end

    __sc_frame.spell_icon:SetScript("OnEnter", tooltip_viewer_on);
    __sc_frame.spell_icon:SetScript("OnLeave", tooltip_viewer_off);
end

local function create_sw_item_id_viewer()

    __sc_frame.item_id_viewer_editbox = CreateFrame("EditBox", "sw_item_id_viewer_editbox", __sc_frame, "InputBoxTemplate");
    __sc_frame.item_id_viewer_editbox:SetPoint("TOPLEFT", __sc_frame, 325, -6);
    __sc_frame.item_id_viewer_editbox:SetText("");
    __sc_frame.item_id_viewer_editbox:SetSize(100, 10);
    __sc_frame.item_id_viewer_editbox:SetAutoFocus(false);

    __sc_frame.item_id_viewer_editbox:SetScript("OnEvent", function(self, event, ...)
        __sc_frame.item_id_viewer_editbox:GetScript("OnTextChanged")(__sc_frame.item_id_viewer_editbox);
    end);


    local tooltip_overwrite_editbox = function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.item_id_viewer_editbox_label:Show();
        else
            __sc_frame.item_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if id and GetItemInfo(id) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
        end
        self:ClearFocus();
    end

    local invalid_item_id = 1728;
    local invalid_item_tex = GetItemIcon(1728);

    __sc_frame.item_id_viewer_editbox:SetScript("OnEnterPressed", tooltip_overwrite_editbox);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEscapePressed", tooltip_overwrite_editbox);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEditFocusLost", function(self)
        tooltip_overwrite_editbox(self);
        __sc_frame.item_id_viewer_editbox:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
    end);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEditFocusGained", function()
        __sc_frame.item_id_viewer_editbox:RegisterEvent("GET_ITEM_INFO_RECEIVED");
    end);
    __sc_frame.item_id_viewer_editbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.item_id_viewer_editbox_label:Show();
        else
            __sc_frame.item_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if id and id <= bit.lshift(1, 31) and GetItemInfo(id) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
            id = 0;
        end

        if id == 0 then
            __sc_frame.item_icon_tex:SetTexture(invalid_item_tex);
            GameTooltip:Hide();
        else
            __sc_frame.item_icon_tex:SetTexture(GetItemIcon(id));

            GameTooltip:SetOwner(__sc_frame.item_icon, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(id);
            GameTooltip:Show();
        end
    end);

    __sc_frame.item_id_viewer_editbox_label = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.item_id_viewer_editbox_label:SetFontObject(font);
    __sc_frame.item_id_viewer_editbox_label:SetText(L["Item ID viewer"]);
    __sc_frame.item_id_viewer_editbox_label:SetPoint("CENTER", __sc_frame.item_id_viewer_editbox, 0, 0);

    __sc_frame.item_icon = CreateFrame("Frame", "__sc_custom_item_id", __sc_frame);
    __sc_frame.item_icon:SetSize(17, 17);
    __sc_frame.item_icon:SetPoint("RIGHT", __sc_frame.item_id_viewer_editbox, 17, 0);

    local tex = __sc_frame.item_icon:CreateTexture(nil);
    tex:SetAllPoints(__sc_frame.item_icon);
    tex:SetTexture(invalid_item_tex);
    __sc_frame.item_icon_tex = tex;

    local tooltip_viewer_on = function(self)
        local txt = __sc_frame.item_id_viewer_editbox:GetText();
        local id = tonumber(txt);
        if txt == "" then
            id = invalid_item_id;
        elseif not id then
            id = 0;
        end
        if GetItemInfo(id) then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(id);
            GameTooltip:Show();
        else
            GameTooltip:Hide();
        end
    end
    local tooltip_viewer_off = function(self)
        GameTooltip:Hide();
    end

    __sc_frame.item_icon:SetScript("OnEnter", tooltip_viewer_on);
    __sc_frame.item_icon:SetScript("OnLeave", tooltip_viewer_off);
end

local function multi_row_checkbutton(buttons_info, parent_frame, num_columns, func, x_pad)
    x_pad = x_pad or 10;
    local column_offset = 230;
    --  assume max 2 columns
    local check_button_type = "CheckButton";
    local frames = {};
    for i, v in pairs(buttons_info) do
        local f = CreateFrame(check_button_type, "__sc_frame_setting_"..v.id, parent_frame, "ChatConfigCheckButtonTemplate");
        frames[#frames + 1] = f;
        f._settings_id = v.id;
        f._type = check_button_type;

        local x_spacing = column_offset*((i-1)%num_columns);
        local x = x_pad + x_spacing;
        f:SetPoint("TOPLEFT", x, parent_frame.y_offset);
        local txt = getglobal(f:GetName() .. 'Text');
        txt:SetText(v.txt);
        if v.color then
            txt:SetTextColor(v.color[1], v.color[2], v.color[3]);
        end
        if v.color_tag then
            register_text_frame_color(txt, v.color_tag);
        end
        if v.tooltip then
            getglobal(f:GetName()).tooltip = v.tooltip;
        end
        f:SetScript("OnClick", function(self)
            config.settings[self._settings_id] = self:GetChecked();
            sc.loadouts.force_update = true;
            if v.func then
                v.func(self);
            end
            if func then
                func(self);
            end
        end);
        if (i-1)%num_columns == num_columns - 1 then
            parent_frame.y_offset = parent_frame.y_offset - 20;
        end
    end
    return frames;
end

local function make_frame_scrollable(frame)

    local height = frame:GetHeight();
    local restrict_bottom_space = -25;

    if -frame.y_offset - restrict_bottom_space <= height then
        return;
    end


    for _, grp in ipairs({{frame:GetChildren()}, {frame:GetRegions()}}) do
        for _, v in ipairs(grp) do
            local _, rel_to, _, _, y = v:GetPoint(1);
            if rel_to == frame then
                v.original_y_offset = y;
            end
        end
    end
    local f = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTrimTemplate");
    f:SetOrientation('VERTICAL');
    f:SetPoint("RIGHT", frame, "RIGHT", 10, 0);
    f:SetWidth(20);
    f:SetHeight(height-25);
    f:SetScript("OnValueChanged", function(self, val)
        for _, grp in ipairs({{frame:GetChildren()}, {frame:GetRegions()}}) do
            for _, v in ipairs(grp) do
                if v.original_y_offset then
                    local p, rel_to, rel_p, x = v:GetPoint(1);
                    local new_y = v.original_y_offset + val;
                    v:SetPoint(p, rel_to, rel_p, x, new_y);
                    if -v.original_y_offset >= val and -v.original_y_offset -restrict_bottom_space <= height+val then
                        v:Show();
                    else
                        v:Hide();
                    end
                end
            end
        end
    end);
    frame.slider = f;
    f:SetMinMaxValues(0, -frame.y_offset-height+100);
    f:SetValue(0);
    f:SetValueStep(15);

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f);
    bg:SetColorTexture(0, 0, 0, 0.5);

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local scrollbar = frame.slider;

        local val = math.max(0, scrollbar:GetValue() - delta*15);
        scrollbar:SetValue(val);
        scrollbar:GetScript("OnValueChanged")(scrollbar, val);
    end);
end

local function create_sw_ui_spells_frame(pframe)

    spell_filter_listing = {
        {
            id = "spells_filter_already_known",
            disp = L["Already known"],
        },
        {
            id = "spells_filter_available",
            disp = L["Available"],
        },
        {
            id = "spells_filter_unavailable",
            disp = L["Unavailable"],
        },
        {
            id = "spells_filter_learned_from_item",
            disp = L["Learned from item"],
        },
        {
            id = "spells_filter_pet",
            disp = L["Pet spells"],
        },
        {
            id = "spells_filter_ignored_spells",
            disp = L["Ignored spells"],
        },
        {
            id = "spells_filter_other_spells",
            disp = L["Other spells"],
            tooltip = L["Uncategorized spells. Contains seasonal spells and junk."]
        },
        {
            id = "spells_filter_only_highest_learned_ranks",
            disp = L["Only highest, learned spell ranks"],
        },
    };

    spell_filters = {};
    for k, v in pairs(spell_filter_listing) do
        spell_filters[v.id] = k;
    end
    spell_browser_sort_options = {
        "Level",
        "|cFFFF8000"..L["Damage per second"],
        "|cFFFF8000"..L["Healing per second"],
        "|cFF00FFFF"..L["Damage per cost"],
        "|cFF00FFFF"..L["Healing per cost"],
    };

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 8;

    f = CreateFrame("EditBox", "__sc_frame_spells_search", pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);
    f:SetSize(100, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        update_spells_frame(nil, nil, nil, true);
        local txt =self:GetText();
        if txt == "" then
            pframe.search_empty_label:Show();
        else
            pframe.search_empty_label:Hide();
        end
    end);
    pframe.search = f;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Search"]);
    f:SetPoint("LEFT", pframe.search, 5, 0);
    pframe.search_empty_label = f;

    -- Sorted by dropdown
    pframe.sort_by =
        --CreateFrame("Button", "pframe_sort_by", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("pframe_sort_by", pframe);
    pframe.sort_by:SetPoint("TOPLEFT", 150, pframe.y_offset+6);
    pframe.sort_by.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.sort_by, L["Order by "]..spell_browser_sort_options[spell_browser_active_sort_key]);
        libDD:UIDropDownMenu_Initialize(pframe.sort_by, function()

            libDD:UIDropDownMenu_SetWidth(pframe.sort_by, 160);

            for k, v in pairs(spell_browser_sort_options) do
                libDD:UIDropDownMenu_AddButton({
                        text = v;
                        checked = k == spell_browser_active_sort_key;
                        func = function()
                            libDD:UIDropDownMenu_SetText(pframe.sort_by, L["Order by "]..spell_browser_sort_options[k]);
                            spell_browser_active_sort_key = k;
                            update_spells_frame(nil, nil, nil, true);
                            pframe.slider:SetValue(1);
                        end
                    }
                );
            end
        end);
    end;
    pframe.sort_by.init_func();

    -- Filter dropdown
    pframe.filter =
        --CreateFrame("Button", "pframe_filter", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("pframe_filter", pframe);
    pframe.filter:SetPoint("TOPLEFT", 340, pframe.y_offset+6);
    pframe.filter.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.filter, L["Includes"]);
        libDD:UIDropDownMenu_Initialize(pframe.filter, function()

            libDD:UIDropDownMenu_SetWidth(pframe.filter, 80);

            for _, v in pairs(spell_filter_listing) do
                local txt = v.disp;
                if v.id == "spells_filter_already_known" then
                    txt = "|cFF8a867d"..txt;
                elseif v.id == "spells_filter_available" then
                    txt = "|cFF00FF00"..txt;
                elseif v.id == "spells_filter_unavailable" then
                    txt = "|cFFFF0000"..txt;
                end
                local is_checked = config.settings[v.id];

                libDD:UIDropDownMenu_AddButton({
                        text = txt,
                        checked = is_checked,
                        func = function(self)
                            if config.settings[v.id] then
                                config.settings[v.id] = false;
                            else
                                config.settings[v.id] = true;
                            end
                            update_spells_frame(nil, nil, nil, true);
                        end,
                        keepShownOnClick = true,
                        notCheckable = false,
                        tooltipTitle = "",
                        tooltipText = v.tooltip,
                        tooltipOnButton = v.tooltip ~= nil,
                    }
                );
            end
        end);
    end;
    pframe.filter.init_func();

    pframe.y_offset = pframe.y_offset - 25;
    -- Headers
    local icon_x_offset = 0;
    local name_x_offset = 20;
    local lvl_x_offset = 200;
    local effect_x_offset = 230;
    local per_sec_x_offset = 260;
    local per_cost_x_offset = 325;
    local acquisition_x_offset = 380;
    local dropdown_x_offset = 440;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Spell name"]);
    f:SetPoint("TOPLEFT", name_x_offset, pframe.y_offset);

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Level"]);
    f:SetPoint("TOPLEFT", lvl_x_offset, pframe.y_offset);
    pframe.header_level = f;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Per second"]);
    f:SetPoint("TOPLEFT", per_sec_x_offset, pframe.y_offset);
    register_text_frame_color(f, "effect_per_sec");

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Per cost"]);
    f:SetPoint("TOPLEFT", per_cost_x_offset, pframe.y_offset);
    register_text_frame_color(f, "effect_per_cost");

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Acquisition"]);
    f:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 23;
    local num_view_list_entries = 29;
    local entry_y_offset = 16;

    -- sliders
    f = CreateFrame("Slider", nil, pframe, "UIPanelScrollBarTrimTemplate");
    f:SetOrientation('VERTICAL');
    f:SetPoint("RIGHT", pframe, "RIGHT", 10, -15);
    f:SetHeight(pframe:GetHeight()-63);
    f:SetScript("OnValueChanged", function(self, val)
        pframe.slider_val = val;
        populate_scrollable_spell_view(pframe.filtered_list, math.floor(val));
    end);
    pframe.slider = f;
    pframe.slider_val = 1;
    f:SetValue(pframe.slider_val);
    f:SetValueStep(1);

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f);
    bg:SetColorTexture(0, 0, 0, 0.5);

    pframe:EnableMouseWheel(true)
    pframe:SetScript("OnMouseWheel", function(_, delta)
        local scrollbar = pframe.slider;
        scrollbar:SetValue(scrollbar:GetValue() - delta*5);
    end);

    -- Spell list
    pframe.filtered_list = {};
    pframe.scroll_view = {};
    for i = 1, num_view_list_entries do

        local tooltip_area_f = CreateFrame("Frame", nil, pframe);
        tooltip_area_f:SetSize(220, 16);
        tooltip_area_f:SetPoint("TOPLEFT", 0, pframe.y_offset+4);
        tooltip_area_f:EnableMouse(true);
        tooltip_area_f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetSpellByID(self.__id);
            GameTooltip:Show();
        end);
        tooltip_area_f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        tooltip_area_f:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);


        local icon = CreateFrame("Frame", nil, pframe);
        icon:SetSize(15, 15);
        icon:SetPoint("TOPLEFT", icon_x_offset, pframe.y_offset+2);
        local icon_texture = icon:CreateTexture(nil);
        icon_texture:SetAllPoints(icon);

        local book = CreateFrame("Frame", nil, pframe);
        book:SetSize(15, 15);
        book:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset+2);
        local book_texture = book:CreateTexture(nil);
        book_texture:SetAllPoints(book);
        book:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(self.__id);
            GameTooltip:Show();
        end);
        book:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local spell_str = pframe:CreateFontString(nil, "OVERLAY");
        spell_str:SetFontObject(font);
        spell_str:SetText("");
        spell_str:SetPoint("TOPLEFT", name_x_offset, pframe.y_offset);

        local level_str = pframe:CreateFontString(nil, "OVERLAY");
        level_str:SetFontObject(font);
        level_str:SetText("");
        level_str:SetPoint("TOPLEFT", lvl_x_offset, pframe.y_offset);

        local effect_type_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_type_str:SetFontObject(font);
        effect_type_str:SetText("");
        effect_type_str:SetPoint("TOPLEFT", effect_x_offset, pframe.y_offset);

        local role_icon = CreateFrame("Frame", nil, pframe);
        role_icon:SetSize(15, 15);
        role_icon:SetPoint("TOPLEFT", effect_x_offset, pframe.y_offset+2);
        local role_icon_texture = role_icon:CreateTexture(nil, "ARTWORK");
        role_icon_texture:SetTexture(role_icons);


        local effect_per_sec_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_per_sec_str:SetFontObject(font);
        effect_per_sec_str:SetText("");
        effect_per_sec_str:SetPoint("TOPLEFT", per_sec_x_offset, pframe.y_offset);
        register_text_frame_color(effect_per_sec_str, "effect_per_sec");

        local effect_per_cost_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_per_cost_str:SetFontObject(font);
        effect_per_cost_str:SetText("");
        effect_per_cost_str:SetPoint("TOPLEFT", per_cost_x_offset, pframe.y_offset);
        register_text_frame_color(effect_per_cost_str, "effect_per_cost");

        local cost = pframe:CreateFontString(nil, "OVERLAY");
        cost:SetFontObject(font);
        cost:SetText("");
        cost:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset+1);

        -- spell option dropdown
        local spell_options =
            --CreateFrame("Button", "pframe_dropdown"..i, pframe, "UIDropDownMenuTemplate");
            libDD:Create_UIDropDownMenu("pframe_dropdown"..i, pframe);
        spell_options:SetPoint("TOPLEFT", dropdown_x_offset, pframe.y_offset+15);
        spell_options.init_func = function()

            libDD:UIDropDownMenu_Initialize(spell_options, function()

                libDD:UIDropDownMenu_SetWidth(spell_options, 15);

                libDD:UIDropDownMenu_AddButton({
                        text = L["Add to calculator list"],
                        func = function()

                            local id = spell_options.__spid;
                            if spells[id] and bit.band(spells[id].flags, spell_flags.eval) ~= 0 then

                                config.settings.spell_calc_list[spell_options.__spid] = 1;
                                update_calc_list();
                            end

                        end,
                    }
                );
                libDD:UIDropDownMenu_AddButton({
                        text = L["Add/remove to spell ignore list"],
                        func = function(self)
                            if config.settings.spells_ignore_list[spell_options.__spid] then
                                config.settings.spells_ignore_list[spell_options.__spid] = nil;
                            else
                                config.settings.spells_ignore_list[spell_options.__spid] = 1;
                            end
                            update_spells_frame(nil, nil, nil, true);
                        end,
                    }
                );
            end);
        end;
        spell_options.init_func();
        spell_options.Button:SetSize(20, 20);
        spell_options.Button:Hide();
        spell_options.Text:Hide();

        local f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
        f:SetText(":");
        f:SetSize(15, 15);
        f:SetPoint("TOPLEFT", dropdown_x_offset, pframe.y_offset+3);
        f:SetScript("OnClick", function()
            libDD:ToggleDropDownMenu(1, nil, spell_options, spell_options, 0, 0)
        end);

        local ignore_line_f = pframe:CreateTexture(nil, "OVERLAY")
        ignore_line_f:SetColorTexture(1.0, 0.0, 0.0, 1.0);
        ignore_line_f:SetDrawLayer("OVERLAY");
        ignore_line_f:SetHeight(0.5);
        ignore_line_f:SetPoint("TOPLEFT", -10, pframe.y_offset-5);
        ignore_line_f:SetPoint("TOPRIGHT", -30, pframe.y_offset-5);


        pframe.scroll_view[i] = {
            tooltip_area = tooltip_area_f,
            spell_icon = icon,
            spell_tex = icon_texture,
            spell_name = spell_str,
            lvl_str = level_str,
            type_str = effect_type_str,
            effect_type_icon = role_icon,
            effect_type_tex = role_icon_texture,
            per_sec_str = effect_per_sec_str,
            per_cost_str = effect_per_cost_str,
            book_icon = book,
            book_tex = book_texture,
            cost_str = cost,
            dropdown_menu = spell_options,
            dropdown_button = f,
            ignore_line = ignore_line_f,
        };
        pframe.y_offset = pframe.y_offset - entry_y_offset;
    end
    local footer_cost = pframe:CreateFontString(nil, "OVERLAY");
    footer_cost:SetFontObject(font);
    footer_cost:SetPoint("BOTTOMRIGHT", pframe, "BOTTOMRIGHT", -15, 5);

    pframe.footer_cost = footer_cost;

    local header_divider = pframe:CreateTexture(nil, "ARTWORK")
    header_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    header_divider:SetHeight(1);
    header_divider:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, -48);
    header_divider:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, -48);

    local footer_divider = pframe:CreateTexture(nil, "ARTWORK")
    footer_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    footer_divider:SetHeight(1)
    footer_divider:SetPoint("BOTTOMLEFT", pframe, "BOTTOMLEFT", 0, 20)
    footer_divider:SetPoint("BOTTOMRIGHT", pframe, "BOTTOMRIGHT", 0, 20)
end

local function create_sw_ui_tooltip_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    pframe.num_tooltip_toggled = 0;

    pframe.checkboxes = {};


    local tooltip_general_checks = {
        {
            id = "tooltip_shift_to_show",
            txt = L["Require SHIFT to show tooltips"]
        },
    };

    multi_row_checkbutton(tooltip_general_checks, pframe, 2);

    pframe.y_offset = pframe.y_offset - 25;

    local tsfs = {};

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Tooltip spell settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    multi_row_checkbutton({{
        id = "tooltip_disable",
        txt = L["Disable spell tooltip"],
        func = function(self)
            local alpha = 1.0;
            if self:GetChecked() then
                alpha = 0.2;
            end
            for _, v in ipairs(tsfs) do
                v:SetAlpha(alpha);
            end
        end
    }}, pframe, 1, nil, 0);


    for _, v in ipairs(multi_row_checkbutton({
        --{
        --    id = "tooltip_clear_original",
        --    txt = "Clear original tooltip",
        --},
        {
            id = "tooltip_double_line",
            txt = L["Field values on right-hand side"],
        },
        {
            id = "tooltip_hide_cd_coom",
            txt = L["Disable casts until OOM for CDs"],
            tooltip = L["Hides casts until OOM for spells with cooldowns."]
        }
    }, pframe, 2)) do

        tsfs[#tsfs + 1] = v;
    end

    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Tooltip spell display options:"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    tsfs[#tsfs + 1] = f_txt;

    pframe.y_offset = pframe.y_offset - 20;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Presets:"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    tsfs[#tsfs + 1] = f_txt;

    local tooltip_components = {
        {
            id = "tooltip_display_addon_name",
            txt = L["Addon & loadout name"]
        },
        {
            id = "tooltip_display_eval_options",
            txt = L["Evaluation modes"],
            tooltip = L["Some spells may have different evaluation modes. This shows the mode and how to dynamically switch between. Example: Switch between healing and damage component of Holy shock."];
        },
        {
            id = "tooltip_display_target_info",
            txt = L["Target info"],
            color_tag = "target_info",
            tooltip = L["Target level, armor and resistance assumed in calculation."]
        },
        {
            id = "tooltip_display_avoidance_info",
            txt = L["Miss, avoidance & mitigation"],
            color_tag = "avoidance_info",
            tooltip = L["Avoidance based on weapon skill & target level. Mitigation based on target armor or resistance."]
        },
        {
            id = "tooltip_display_normal",
            txt = L["Normal effect"],
            color_tag = "normal"
        },
        {
            id = "tooltip_display_crit",
            txt = L["Critical effect"],
            color_tag = "crit"
        },
        {
            id = "tooltip_display_expected",
            txt = L["Expected effect"],
            color_tag = "expectation",
            tooltip = sc.overlay.label_handler.overlay_display_expected.tooltip,
        },
        {
            id = "tooltip_display_effect_per_sec",
            txt = L["Effect per second"],
            color_tag = "effect_per_sec",
            tooltip = sc.overlay.label_handler.overlay_display_effect_per_sec.tooltip,
        },
        {
            id = "tooltip_display_threat",
            txt = L["Expected threat"],
            color_tag = "threat",
        },
        {
            id = "tooltip_display_threat_per_sec",
            txt = L["Threat per second"],
            color_tag = "threat"
        },
        {
            id = "tooltip_display_threat_per_cost",
            txt = L["Threat per cost"],
            color_tag = "effect_per_cost",
        },
        {
            id = "tooltip_display_effect_per_cost",
            txt = L["Effect per cost"],
            color_tag = "effect_per_cost",
            tooltip = sc.overlay.label_handler.overlay_display_effect_per_cost.tooltip,
        },
        {
            id = "tooltip_display_cost_per_sec",
            txt = L["Cost per second"] ,
            color_tag = "cost_per_sec"
        },
        {
            id = "tooltip_display_avg_cost",
            txt = L["Expected cost"],
            color_tag = "cost",
            tooltip = L["Shown when different from actual cost."],
        },
        {
            id = "tooltip_display_avg_cast",
            txt = L["Expected execution time"],
            color_tag = "execution_time",
            tooltip = L["Shown when different from actual cast time."],
        },
        {
            id = "tooltip_display_cast_until_oom",
            txt = L["Casting until OOM"],
            color_tag = "normal",
            tooltip = L["Assumes you cast a particular ability until you are OOM with no cooldowns."]
        },
        {
            id = "tooltip_display_base_mod",
            txt = L["Base effect mod"],
            color_tag = "sp_effect",
            tooltip = L["Intended for debugging."]
        },
        {
            id = "tooltip_display_sp_effect_calc",
            txt = L["Coef & SP/AP effect"],
            color_tag = "sp_effect",
        },
        {
            id = "tooltip_display_sp_effect_ratio",
            txt = L["SP/AP to base effect ratio"],
            color_tag = "sp_effect",
        },
        {
            id = "tooltip_display_spell_rank",
            txt = L["Spell rank info"],
            color_tag = "spell_rank",
        },
        {
            id = "tooltip_display_spell_id",
            txt = L["Spell id"],
            color_tag = "spell_rank",
        },
        {
            id = "tooltip_display_stat_weights_effect",
            txt = L["Stat weights: Effect"],
            color_tag = "stat_weights",
        },
        {
            id = "tooltip_display_stat_weights_effect_per_sec",
            txt = L["Stat weights: Effect per sec"],
            color_tag = "stat_weights",
        },
        {
            id = "tooltip_display_stat_weights_effect_until_oom",
            txt = L["Stat weights: Effect until OOM"],
            color_tag = "stat_weights",
        },
        {
            id = "tooltip_display_resource_regen",
            txt = L["Resource restoration"],
            tooltip = sc.overlay.label_handler.overlay_display_resource_regen.tooltip,
            color_tag = "cost",
        },
    };

    pframe.y_offset = pframe.y_offset - 10;
    pframe.preset_minimalistic_button =
        CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");

    pframe.preset_minimalistic_button:SetScript("OnClick", function(self)

        for _, v in pairs(tooltip_components) do
            local f = getglobal("__sc_frame_setting_"..v.id);
            if f:GetChecked() then
                f:Click();
            end
        end
        getglobal("__sc_frame_setting_tooltip_display_expected"):Click();
        getglobal("__sc_frame_setting_tooltip_display_effect_per_sec"):Click();
        getglobal("__sc_frame_setting_tooltip_display_effect_per_cost"):Click();
        getglobal("__sc_frame_setting_tooltip_display_eval_options"):Click();
        getglobal("__sc_frame_setting_tooltip_display_resource_regen"):Click();

    end);

    pframe.preset_minimalistic_button:SetPoint("TOPLEFT", 80, pframe.y_offset+16);
    pframe.preset_minimalistic_button:SetText(L["Minimalistic"]);
    pframe.preset_minimalistic_button:SetWidth(120);

    pframe.preset_default_button =
        CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    pframe.preset_default_button:SetScript("OnClick", function(self)

        for _, v in pairs(tooltip_components) do
            local f = getglobal("__sc_frame_setting_"..v.id);
            if config.default_settings[v.id] ~= f:GetChecked() then
                f:Click();
            end
        end
    end);
    pframe.preset_default_button:SetPoint("TOPLEFT", 200, pframe.y_offset+16);
    pframe.preset_default_button:SetText(L["Default"]);
    pframe.preset_default_button:SetWidth(120);

    pframe.preset_detailed_button =
        CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    pframe.preset_detailed_button:SetScript("OnClick", function(self)

        for _, v in pairs(tooltip_components) do
            local f = getglobal("__sc_frame_setting_"..v.id);
            if f:GetChecked() then
                f:Click();
            end
        end

        getglobal("__sc_frame_setting_tooltip_display_addon_name"):Click();
        getglobal("__sc_frame_setting_tooltip_display_target_info"):Click();
        getglobal("__sc_frame_setting_tooltip_display_avoidance_info"):Click();
        getglobal("__sc_frame_setting_tooltip_display_spell_rank"):Click();
        getglobal("__sc_frame_setting_tooltip_display_normal"):Click();
        getglobal("__sc_frame_setting_tooltip_display_crit"):Click();
        getglobal("__sc_frame_setting_tooltip_display_avg_cost"):Click();
        getglobal("__sc_frame_setting_tooltip_display_avg_cast"):Click();
        getglobal("__sc_frame_setting_tooltip_display_expected"):Click();
        getglobal("__sc_frame_setting_tooltip_display_effect_per_sec"):Click();
        getglobal("__sc_frame_setting_tooltip_display_effect_per_cost"):Click();
        getglobal("__sc_frame_setting_tooltip_display_threat"):Click();
        getglobal("__sc_frame_setting_tooltip_display_threat_per_sec"):Click();
        getglobal("__sc_frame_setting_tooltip_display_threat_per_cost"):Click();
        getglobal("__sc_frame_setting_tooltip_display_cost_per_sec"):Click();
        getglobal("__sc_frame_setting_tooltip_display_cast_until_oom"):Click();
        getglobal("__sc_frame_setting_tooltip_display_sp_effect_calc"):Click();
        getglobal("__sc_frame_setting_tooltip_display_sp_effect_ratio"):Click();
        getglobal("__sc_frame_setting_tooltip_display_stat_weights_effect_per_sec"):Click();
        getglobal("__sc_frame_setting_tooltip_display_stat_weights_effect_until_oom"):Click();
        getglobal("__sc_frame_setting_tooltip_display_eval_options"):Click();
        getglobal("__sc_frame_setting_tooltip_display_resource_regen"):Click();
    end);
    pframe.preset_detailed_button:SetPoint("TOPLEFT", 320, pframe.y_offset+16);
    pframe.preset_detailed_button:SetText(L["Detailed"]);
    pframe.preset_detailed_button:SetWidth(120);
    local tooltip_toggle = function(self)

        local checked = self:GetChecked();
        if checked then

            if pframe.num_tooltip_toggled == 0 then
                if __sc_frame_setting_tooltip_disable:GetChecked() then
                    __sc_frame_setting_tooltip_disable:Click();
                end
            end
            pframe.num_tooltip_toggled = pframe.num_tooltip_toggled + 1;
        else
            pframe.num_tooltip_toggled = pframe.num_tooltip_toggled - 1;
            if pframe.num_tooltip_toggled == 0 then
                if not __sc_frame_setting_tooltip_disable:GetChecked() then
                    __sc_frame_setting_tooltip_disable:Click();
                end
            end
        end
        config.settings[self._settings_id] = self:GetChecked();
    end;

    tsfs[#tsfs + 1] = pframe.preset_minimalistic_button;
    tsfs[#tsfs + 1] = pframe.preset_default_button;
    tsfs[#tsfs + 1] = pframe.preset_detailed_button;

    pframe.y_offset = pframe.y_offset - 10;
    for _, v in pairs(multi_row_checkbutton(tooltip_components, pframe, 2, tooltip_toggle)) do
        tsfs[#tsfs + 1] = v;
    end
    pframe.y_offset = pframe.y_offset - 25;

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 5;

    local tifs = {};

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Tooltip item comparison settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);


    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        sw_activate_tab(__sc_frame.tabs[4]);
    end);

    f:SetPoint("TOPRIGHT", -40, pframe.y_offset);
    f:SetHeight(20);
    f:SetWidth(200);
    f:SetText(L["Configure spell list"]);

    tifs[#tifs + 1] = f;

    pframe.y_offset = pframe.y_offset - 15;
    multi_row_checkbutton({{
            id = "tooltip_disable_item",
            txt = L["Disable item upgrade evaluation in tooltip"],
            func = function(self)
                local alpha = 1.0;
                if self:GetChecked() then
                    alpha = 0.2;
                end
                for _, v in ipairs(tifs) do
                    v:SetAlpha(alpha);
                end
            end
        }}, pframe, 1, nil, 0);

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_smart",
            txt = L["Smarter tooltip"],
            tooltip = L["Adds/removes some sensible aspects of the tooltip. Examples: Never showing Attack for caster classes or for cloth items; Show wand spell for wands; etc"],
        },
        {
            id = "tooltip_item_show_evaluation_modes",
            txt = L["Show evaluation mode switch"],
        },

    }, pframe, 2, nil)) do 
        tifs[#tifs + 1] = v;
    end

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_leveling_skill_normalize",
            txt = L["Use skill as clvl*5 for weapon comparisons when not at maximum level"],
            tooltip = L["More intuitive weapon upgrade results when leveling since lower weapon skill type is not punished"],
        },
    }, pframe, 1, nil)) do
        tifs[#tifs + 1] = v;
    end

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_weapon_skill",
            txt = L["Show skill levels for weapons"],
        },
        {
            id = "tooltip_item_ignore_unequippable",
            txt = L["Ignore unequippable by class"],
        },
        {
            id = "tooltip_item_ignore_cloth",
            txt = L["Ignore armor type: cloth"],
        },
        {
            id = "tooltip_item_ignore_leather",
            txt = L["Ignore armor type: leather"],
        },
        {
            id = "tooltip_item_ignore_mail",
            txt = L["Ignore armor type: mail"],
        },
        {
            id = "tooltip_item_ignore_plate",
            txt = L["Ignore armor type: plate"],
        },
    }, pframe, 2, nil)) do
        tifs[#tifs + 1] = v;
    end

    make_frame_scrollable(pframe);
end

local fonts = {
    "Fonts\\FRIZQT__.TTF",
    "Fonts\\ARIALN.TTF",
    "Fonts\\MORPHEUS.TTF",
    "Fonts\\SKURRI.TTF",
    "Fonts\\2002.TTF",
    "Interface\\AddOns\\SpellCoda\\font\\Oswald-Bold.ttf",
};

local font_dropdowns = {};

local external_fonts_found = {};

local function get_font(font_id)
    -- font_id's are typically paths but fonts from LibSharedMedia identified from name
    return external_fonts_found[font_id] or font_id;
end

local function fonts_setup()

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true);
    if lsm then
        local external_fonts = lsm:List("font");
        local external_fonts_max = 18;
        local external_fonts_num = math.min(external_fonts_max, #external_fonts);
        for _, font_name in ipairs(external_fonts) do
            external_fonts_found[font_name] = lsm:Fetch("font", font_name);
        end
        for i = 1, external_fonts_num do
            fonts[#fonts+1] = external_fonts[i];
        end
    end
    for _, font_path in ipairs(fonts) do
        font_dropdowns[#font_dropdowns + 1] = { font_path, "OUTLINE" };
        font_dropdowns[#font_dropdowns + 1] = { font_path, "THICKOUTLINE" };
    end
end

local function create_font_dropdown(parent_frame, dropdown_name, font_config_key, callback_fn)
    local dropdown_frame = libDD:Create_UIDropDownMenu(dropdown_name, parent_frame);

    dropdown_frame._type = "DropDownMenu";

    dropdown_frame.init_func = function()
        libDD:UIDropDownMenu_Initialize(dropdown_frame, function()
            local using_external_font = true;
            for k, v in pairs(font_dropdowns) do
                local txt = (v[1]:match("([^\\]+)$") or v[1]) .. "   0123456789  " .. v[2];
                local font_object = CreateFont("__sc_font_dropdown_font_" .. k);
                font_object:SetFont(get_font(v[1]), 12, v[2]);

                local btn = {
                    text = txt,
                    fontObject = font_object,
                    checked = false,
                    func = function(self)
                        self.checked = true;
                        libDD:UIDropDownMenu_SetText(dropdown_frame, txt);
                        config.settings[font_config_key][1] = v[1];
                        config.settings[font_config_key][2] = v[2];
                        callback_fn();
                    end,
                };

                if config.settings[font_config_key][1] == v[1] and config.settings[font_config_key][2] == v[2] then
                    using_external_font = false;
                    libDD:UIDropDownMenu_SetText(dropdown_frame, txt);
                    btn.checked = true;
                    callback_fn();
                end
                libDD:UIDropDownMenu_AddButton(btn);

            end
            if using_external_font then

                -- to show font used not in addon fonts list but either
                --  1) set manually through SpellCoda SavedVariables
                --  or
                --  2) originates from LibSharedMedia but path no longer existing
                --
                --  There appears to be no way to safely test for bad font paths

                if not config.settings[font_config_key][1]:find("\\") and not external_fonts_found[config.settings[font_config_key][1]] then
                    -- font id should have been a name key into external fonts but no longer exists
                    config.settings[font_config_key][1] = config.default_settings[font_config_key][1];
                    config.settings[font_config_key][2] = config.default_settings[font_config_key][2];
                end
                local txt = (config.settings[font_config_key][1]:match(
                    "([^\\]+)$") or v[1]) .. "   0123456789  " .. config.settings[font_config_key][2];
                libDD:UIDropDownMenu_SetText(dropdown_frame, txt);

            end
        end);

        -- Configure dropdown appearance
        libDD:UIDropDownMenu_SetWidth(dropdown_frame, 200);
        libDD:UIDropDownMenu_SetButtonWidth(dropdown_frame, 224);
        libDD:UIDropDownMenu_JustifyText(dropdown_frame, "LEFT");
    end;

    return dropdown_frame;
end;

local overlay_components_selection_display = {
    "overlay_display_normal",
    "overlay_display_direct_normal",
    "overlay_display_ot_normal",
    "overlay_display_hit_chance",

    "overlay_display_crit",
    "overlay_display_direct_crit",
    "overlay_display_ot_crit",
    "overlay_display_crit_chance",

    "overlay_display_expected",
    "overlay_display_effect_per_sec",

    "overlay_display_threat",
    "overlay_display_threat_per_sec",

    "overlay_display_avg_cost",
    "overlay_display_actual_cost",
    "overlay_display_effect_per_cost",
    "overlay_display_threat_per_cost",

    "overlay_display_miss_chance",
    "overlay_display_avoid_chance",
    "overlay_display_mitigation",

    "overlay_display_avg_cast",
    "overlay_display_actual_cast",

    "overlay_display_effect_until_oom",
    "overlay_display_time_until_oom",
    "overlay_display_casts_until_oom",

    "overlay_display_rank",
};


local function create_sw_ui_overlay_frame(pframe)

    local f, f_txt;

    pframe.y_offset = pframe.y_offset - 5;

    multi_row_checkbutton({
        {
            id = "overlay_disable_in_raid",
            txt = L["Disable all overlays in raid instances"],
            tooltip = L["Eliminates dynamic overlay calculations making CPU usage negligible"],
            func = function()
                sc.core.doing_raid_update();
            end
        },
    }, pframe, 1);

    pframe.y_offset = pframe.y_offset - 5;

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell overlay settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    local ofs = {};

    multi_row_checkbutton({{
            id = "overlay_disable",
            txt = L["Disable action bar overlay"],
            func = function(self)
                sc.overlay.clear_overlays();
                sc.core.old_ranks_checks_needed = true;

                local alpha = 1.0;
                if self:GetChecked() then
                    alpha = 0.2;
                end
                for _, v in ipairs(ofs) do
                    v:SetAlpha(alpha);
                end
            end
        }}, pframe, 1, nil, 0);

    for _, v in pairs(multi_row_checkbutton({
        {
            id = "overlay_old_rank",
            txt = L["Old rank warning"],
            color_tag = "old_rank",
            func = function()
                sc.core.old_ranks_checks_needed = true;
            end
        },
        {
            id = "overlay_old_rank_limit_to_known",
            txt = L["Restrict rank warning to learned"],
            color_tag = "old_rank",
            func = function()
                sc.core.old_ranks_checks_needed = true;
            end,
            tooltip = L["Does not warn about old rank when the higher rank is not learned/known by player. Requires old rank warning option to be toggled."],
        },
        {
            id = "overlay_no_decimals",
            txt = L["Never show decimals"],
            func = function(self)
                if self:GetChecked() then
                    sc.overlay.decimals_cap = 0;
                else
                    sc.overlay.decimals_cap = 3;
                end
            end,
        },
    }, pframe, 2)) do
        ofs[#ofs + 1] = v;
    end

    pframe.y_offset = pframe.y_offset - 27;

    local slider_frame_type = "Slider";
    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_update_freq", pframe, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 235, pframe.y_offset+4);
    f:SetMinMaxValues(1, 30)
    f:SetValueStep(1)
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetHitRectInsets(0, 0, 3, 3)
    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_update_freq = val;
        self.val_txt:SetText(string.format("%.1f Hz", val));
    end);
    ofs[#ofs + 1] = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset)
    f_txt:SetText(L["Update frequency (responsiveness)"]);
    ofs[#ofs + 1] = f_txt;

    f.val_txt = pframe:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 415, pframe.y_offset)
    ofs[#ofs + 1] = f.val_txt;

    pframe.y_offset = pframe.y_offset - 23;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset);
    f_txt:SetText(L["Font"]);
    ofs[#ofs + 1] = f_txt;

    local overlay_font_dropdown_f = create_font_dropdown(
        pframe,
        "__sc_frame_setting_overlay_font",
        "overlay_font",
        sc.overlay.overlay_reconfig
    );
    overlay_font_dropdown_f:SetPoint("TOPLEFT", 217, pframe.y_offset+6);
    ofs[#ofs + 1] = overlay_font_dropdown_f;

    pframe.y_offset = pframe.y_offset - 25;

    -- headers
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 35, pframe.y_offset);
    f_txt:SetText(L["Label"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    ofs[#ofs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 175, pframe.y_offset);
    f_txt:SetText(L["Font size"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    ofs[#ofs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 240, pframe.y_offset);
    f_txt:SetText("x");
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    ofs[#ofs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 280, pframe.y_offset);
    f_txt:SetText("y");
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    ofs[#ofs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 320, pframe.y_offset);
    f_txt:SetText(L["Display"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    ofs[#ofs + 1] = f_txt;

    local overlay_labels = {
        {
            config_subkey = "overlay_top",
            desc = L["Top"],
        },
        {
            config_subkey = "overlay_center",
            desc = L["Center"],
        },
        {
            config_subkey = "overlay_bottom",
            desc = L["Bottom"],
        },
    };

    pframe.y_offset = pframe.y_offset - 13;
    for _, v in ipairs(overlay_labels) do
        local k = v.config_subkey;
        local label_frame_setting_subkey = k;

        do
            -- enable button
            local option_key = label_frame_setting_subkey.."_enabled";
            f = CreateFrame("CheckButton", "__sc_frame_setting_"..option_key, pframe, "ChatConfigCheckButtonTemplate");
            f._type = "CheckButton";
            f._settings_id = option_key;
            f:SetPoint("TOPLEFT", 10, pframe.y_offset);
            f:SetScript("OnClick", function(self)
                config.settings[self._settings_id] = self:GetChecked();
                sc.loadouts.force_update = true;
                sc.core.update_action_bar_needed = true;
            end);
            getglobal(f:GetName()..'Text'):SetText(v.desc);
            ofs[#ofs + 1] = f;
        end

        do
            -- font size
            local option_key = label_frame_setting_subkey.."_fsize";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 185, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                local valid = val and val > 1;
                if valid then
                    config.settings[self._settings_id] = val;
                    sc.loadouts.force_update = true;
                    sc.core.update_action_bar_needed = true;
                    sc.overlay.overlay_reconfig();
                end
                return valid;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end

            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            editbox_config(f, update, close);
            ofs[#ofs + 1] = f;
        end

        do
            -- x offset
            local option_key = label_frame_setting_subkey.."_x";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 230, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                if val then
                    config.settings[self._settings_id] = val;
                    sc.loadouts.force_update = true;
                    sc.core.update_action_bar_needed = true;
                    sc.overlay.overlay_reconfig();
                end
                return val;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end
            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            editbox_config(f, update, close);
            ofs[#ofs + 1] = f;
        end

        do

            local option_key = label_frame_setting_subkey.."_y";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 275, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                if val then
                    config.settings[self._settings_id] = val;
                    sc.core.update_action_bar_needed = true;
                    sc.loadouts.force_update = true;
                    sc.overlay.overlay_reconfig();
                    for label in pairs(sc.overlay.ccf_labels) do
                        sc.overlay.ccf_label_reconfig(label);
                    end
                end
                return val;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end
            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            editbox_config(f, update, close);
            ofs[#ofs + 1] = f;
        end

        do
            local option_key = label_frame_setting_subkey.."_selection";
            local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);

            dd._type = "DropDownMenu";
            dd._settings_id = option_key;
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            dd.init_func = function()
                libDD:UIDropDownMenu_Initialize(dd, function(self)

                    if not sc.overlay.label_handler[config.settings[self._settings_id]] then
                        config.settings[self._settings_id] = next(sc.overlay.label_handler);
                    end
                    local active_sel = sc.overlay.label_handler[config.settings[self._settings_id]];
                    sc.core.update_action_bar_needed = true;
                    sc.loadouts.force_update = true;

                    libDD:UIDropDownMenu_SetText(self, active_sel.desc);
                    self.Text:SetTextColor(effect_color(active_sel.color_tag));
                    register_text_frame_color(self.Text, active_sel.color_tag);

                    libDD:UIDropDownMenu_SetWidth(self, 120);

                    for _, sel_k in ipairs(overlay_components_selection_display) do
                        local sel_v = sc.overlay.label_handler[sel_k];
                        local r, g, b = effect_color(sel_v.color_tag);
                        local txt = CreateColor(r, g, b, 1.0):WrapTextInColorCode(sel_v.desc);
                        libDD:UIDropDownMenu_AddButton(
                            {
                                text = txt,
                                checked = sel_k == config.settings[self._settings_id],
                                func = function()
                                    config.settings[self._settings_id] = sel_k;
                                    sc.core.update_action_bar_needed = true;
                                    sc.loadouts.force_update = true;
                                    libDD:UIDropDownMenu_SetText(self, txt);
                                end,
                                tooltipTitle = "",
                                tooltipText = sel_v.tooltip,
                                tooltipOnButton = sel_v.tooltip ~= nil,
                            }
                        );
                    end
                end);
            end;
            ofs[#ofs + 1] = dd;
        end
        pframe.y_offset = pframe.y_offset - 20;
    end

    pframe.y_offset = pframe.y_offset - 10;

    do
        local option_key = "overlay_resource_regen";
        f = CreateFrame("CheckButton", "__sc_frame_setting_"..option_key, pframe, "ChatConfigCheckButtonTemplate");
        f._type = "CheckButton";
        f._settings_id = option_key;
        f:SetPoint("TOPLEFT", 10, pframe.y_offset);
        f:SetScript("OnClick", function(self)
            config.settings[self._settings_id] = self:GetChecked();
            sc.core.update_action_bar_needed = true;
            sc.loadouts.force_update = true;
        end);
        local handler = sc.overlay.label_handler.overlay_display_resource_regen;
        local text_frame = getglobal(f:GetName()..'Text');
        text_frame:SetText(handler.desc);
        register_text_frame_color(text_frame, handler.color_tag);
        ofs[#ofs + 1] = f;
    end
    do
        local option_key = "overlay_resource_regen_display_idx";
        local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);

        dd._type = "DropDownMenu";
        dd._settings_id = option_key;
        dd:SetPoint("TOPLEFT", 165, pframe.y_offset+3);
        local selections =  {L["Top label"], L["Center label"], L["Bottom label"]};
        dd.init_func = function()
            libDD:UIDropDownMenu_Initialize(dd, function(self)

                sc.core.update_action_bar_needed = true;
                sc.loadouts.force_update = true;

                libDD:UIDropDownMenu_SetWidth(self, 120);

                for i, disp in ipairs(selections) do
                    if config.settings[self._settings_id] == i then
                        libDD:UIDropDownMenu_SetText(self, disp);
                    end
                    libDD:UIDropDownMenu_AddButton(
                        {
                            text = disp,
                            checked = i == config.settings[self._settings_id],
                            func = function()
                                config.settings[self._settings_id] = i;
                                sc.core.update_action_bar_needed = true;
                                sc.loadouts.force_update = true;
                                libDD:UIDropDownMenu_SetText(self, disp);
                            end,
                        }
                    );
                end
            end);
        end;
        ofs[#ofs + 1] = dd;
    end
    pframe.y_offset = pframe.y_offset - 30;

    local cfs = {}

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell cast info frame"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    multi_row_checkbutton(
        {
            {
                id = "overlay_disable_cc_info",
                txt = L["Disable spell cast info frame"],
                func = function(self)
                    if sc.overlay.ccf_parent.config_mode then
                        if self:GetChecked() then
                            sc.overlay.ccf_parent.border.disabled_txt:Show();
                        else
                            sc.overlay.ccf_parent.border.disabled_txt:Hide();
                        end
                        sc.overlay.cc_demo();
                    end

                    local alpha = 1.0;
                    if self:GetChecked() then
                        alpha = 0.2;
                    end
                    for _, v in ipairs(cfs) do
                        v:SetAlpha(alpha);
                    end
                end
            },
        },
        pframe, 1, nil, 0);

    for _, v in ipairs(multi_row_checkbutton(
        {
            {
                id = "overlay_cc_only_eval",
                txt = L["Only show for evaluable spells"],
            },
            {
                id = "overlay_cc_transition_nocd",
                txt = L["Remove transition cooldown"],
                func = function()

                    if sc.overlay.ccf_parent.config_mode then
                        sc.overlay.cc_demo();
                    end
                end,
                tooltip = L["Transitions otherwise have a cooldown equal to transition time to prevent multiple transitions at once. This removal may look weird unless transition slide length is set to 0"],
            },
            {
                id = "overlay_cc_horizontal",
                txt = L["Horizontal transition"],
                func = function()
                    sc.overlay.ccf_anim_reconfig();
                    if sc.overlay.ccf_parent.config_mode then
                        sc.overlay.cc_demo();
                    end
                end
            },
        },
        pframe, 2)) do

        cfs[#cfs + 1] = v;
    end

    pframe.y_offset = pframe.y_offset - 20;

    for _, v in ipairs(multi_row_checkbutton(
        {
            {
                id = "overlay_cc_move_adjacent_on_empty",
                txt = L["Move neighbouring labels closer when other is empty"],
                func = function(self)

                    for k in pairs(sc.overlay.ccf_labels) do
                        sc.overlay.ccf_label_reconfig(k);
                    end
                end
            },
        },
        pframe, 1)) do

        cfs[#cfs + 1] = v;
    end

    pframe.y_offset = pframe.y_offset - 5;

    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_cc_info_scale", pframe, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 235, pframe.y_offset+4);
    f:SetMinMaxValues(0.1, 3.0);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.05);
    f:SetHitRectInsets(0, 0, 3, 3)
    cfs[#cfs + 1] = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset)
    f_txt:SetText(L["Scale"])
    cfs[#cfs + 1] = f_txt;

    f.val_txt = pframe:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 415, pframe.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));
    cfs[#cfs + 1] = f.val_txt;

    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_cc_info_scale = val;
        self.val_txt:SetText(string.format("%.2f", val))
        sc.overlay.cc_f1.icon_frame:SetScale(val);
        sc.overlay.cc_f2.icon_frame:SetScale(val);
        sc.overlay.ccf_parent.border:SetScale(val);
    end);

    pframe.y_offset = pframe.y_offset - 18;
    -----

    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_cc_hanging_time", pframe, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 235, pframe.y_offset+4);
    f:SetMinMaxValues(0.0, 10);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.05);
    f:SetHitRectInsets(0, 0, 3, 3)
    cfs[#cfs + 1] = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset)
    f_txt:SetText(L["Hanging time until transition start"])
    cfs[#cfs + 1] = f_txt;

    f.val_txt = pframe:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 415, pframe.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));
    cfs[#cfs + 1] = f.val_txt;

    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_cc_hanging_time = val;
        self.val_txt:SetText(string.format("%.2fs", val))
        sc.overlay.ccf_anim_reconfig();
        if sc.overlay.ccf_parent.config_mode then
            sc.overlay.cc_demo();
        end
    end);

    pframe.y_offset = pframe.y_offset - 18;
    -----

    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_cc_transition_time", pframe, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 235, pframe.y_offset+4);
    f:SetMinMaxValues(0.0, 3.0);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.05);
    f:SetHitRectInsets(0, 0, 3, 3)
    cfs[#cfs + 1] = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset)
    f_txt:SetText(L["Transition time"])
    cfs[#cfs + 1] = f_txt;

    f.val_txt = pframe:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 415, pframe.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));
    cfs[#cfs + 1] = f.val_txt;

    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_cc_transition_time = val;
        self.val_txt:SetText(string.format("%.2fs", val))
        sc.overlay.ccf_anim_reconfig();
        if sc.overlay.ccf_parent.config_mode then
            sc.overlay.cc_demo();
        end
    end);
    -----
    pframe.y_offset = pframe.y_offset - 18;

    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_cc_transition_length", pframe, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 235, pframe.y_offset+4);
    f:SetMinMaxValues(0.0, 300.0);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.05);
    f:SetHitRectInsets(0, 0, 3, 3)
    cfs[#cfs + 1] = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset)
    f_txt:SetText(L["Transition slide length"])
    cfs[#cfs + 1] = f_txt;

    f.val_txt = pframe:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 415, pframe.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));
    cfs[#cfs + 1] = f.val_txt;

    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_cc_transition_length = val;
        self.val_txt:SetText(string.format("%.1f", val))
        sc.overlay.ccf_anim_reconfig();
        if sc.overlay.ccf_parent.config_mode then
            sc.overlay.cc_demo();
        end
    end);

    pframe.y_offset = pframe.y_offset - 20;

    f_txt = pframe:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset);
    f_txt:SetText(L["Font"]);
    cfs[#cfs + 1] = f_txt;

    local overlay_cc_font_dropdown_f = create_font_dropdown(
        pframe,
        "__sc_frame_setting_overlay_cc_font",
        "overlay_cc_font",
        function()
            for k in pairs(sc.overlay.ccf_labels) do
                sc.overlay.ccf_label_reconfig(k);
            end
        end
    );
    overlay_cc_font_dropdown_f:SetPoint("TOPLEFT", 217, pframe.y_offset+6);
    cfs[#cfs + 1] = overlay_cc_font_dropdown_f;

    pframe.y_offset = pframe.y_offset - 22;

    -- headers
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 35, pframe.y_offset);
    f_txt:SetText(L["Label"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    cfs[#cfs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 175, pframe.y_offset);
    f_txt:SetText(L["Font size"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    cfs[#cfs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 240, pframe.y_offset);
    f_txt:SetText("x");
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    cfs[#cfs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 280, pframe.y_offset);
    f_txt:SetText("y");
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    cfs[#cfs + 1] = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 320, pframe.y_offset);
    f_txt:SetText(L["Display"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);
    cfs[#cfs + 1] = f_txt;

    pframe.y_offset = pframe.y_offset - 13;
    for _, k in ipairs({
        "outside_right_upper",
        "outside_right_lower",
        "outside_left_upper",
        "outside_left_lower",
        "outside_top_left",
        "outside_top_right",
        "outside_bottom_left",
        "outside_bottom_right",
        "inside_top",
        "inside_bottom",
        "inside_left",
        "inside_right",
    }) do
        local v = sc.overlay.ccf_labels[k];

        local label_frame_setting_subkey = "overlay_cc_"..k;

        do
            -- enable button
            local option_key = label_frame_setting_subkey.."_enabled";
            f = CreateFrame("CheckButton", "__sc_frame_setting_"..option_key, pframe, "ChatConfigCheckButtonTemplate");
            f._type = "CheckButton";
            f._settings_id = option_key;
            f:SetPoint("TOPLEFT", 10, pframe.y_offset);
            f:SetScript("OnClick", function(self)
                config.settings[self._settings_id] = self:GetChecked();
                sc.overlay.ccf_label_reconfig(k);
            end);
            cfs[#cfs + 1] = f;

            getglobal(f:GetName()..'Text'):SetText(v.desc);
        end

        do
            -- font size
            local option_key = label_frame_setting_subkey.."_fsize";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 185, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                local valid = val and val > 1;
                if valid then
                    config.settings[self._settings_id] = val;
                    sc.overlay.ccf_label_reconfig(k);
                end
                return valid;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end

            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            cfs[#cfs + 1] = f;
            editbox_config(f, update, close);
        end

        do
            -- x offset
            local option_key = label_frame_setting_subkey.."_x";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 230, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                if val then
                    config.settings[self._settings_id] = val;
                    sc.overlay.ccf_label_reconfig(k);
                end
                return val;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end
            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            cfs[#cfs + 1] = f;
            editbox_config(f, update, close);
        end

        do

            local option_key = label_frame_setting_subkey.."_y";
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 275, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                if val then
                    config.settings[self._settings_id] = val;
                    sc.overlay.ccf_label_reconfig(k);
                end
                return val;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end
            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            cfs[#cfs + 1] = f;
            editbox_config(f, update, close);
        end

        do
            local option_key = label_frame_setting_subkey.."_selection";
            local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);

            dd._type = "DropDownMenu";
            dd._settings_id = option_key;
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            dd.init_func = function()
                libDD:UIDropDownMenu_Initialize(dd, function(self)

                    if not sc.overlay.label_handler[config.settings[self._settings_id]] then
                        config.settings[self._settings_id] = next(sc.overlay.label_handler);
                    end
                    local active_sel = sc.overlay.label_handler[config.settings[self._settings_id]];
                    sc.overlay.ccf_label_reconfig(k);
                    libDD:UIDropDownMenu_SetText(self, active_sel.desc);
                    self.Text:SetTextColor(effect_color(active_sel.color_tag));
                    register_text_frame_color(self.Text, active_sel.color_tag);

                    libDD:UIDropDownMenu_SetWidth(self, 120);

                    for _, sel_k in ipairs(overlay_components_selection_display) do
                        local sel_v = sc.overlay.label_handler[sel_k];
                        local r, g, b = effect_color(sel_v.color_tag);
                        local txt = CreateColor(r, g, b, 1.0):WrapTextInColorCode(sel_v.desc);
                        libDD:UIDropDownMenu_AddButton(
                            {
                                text = txt,
                                checked = sel_k == config.settings[self._settings_id],
                                func = function()
                                    config.settings[self._settings_id] = sel_k;
                                    sc.overlay.ccf_label_reconfig(k);
                                    libDD:UIDropDownMenu_SetText(self, txt);
                                end,
                                tooltipTitle = "",
                                tooltipText = sel_v.tooltip,
                                tooltipOnButton = sel_v.tooltip ~= nil,
                            }
                        );
                    end
                end);
            end;
            cfs[#cfs + 1] = dd;
        end
        pframe.y_offset = pframe.y_offset - 20;

    end

    make_frame_scrollable(pframe);
end

local function create_sw_ui_calculator_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;
    local x_pad = 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["While this tab is open, ability overlay & tooltips reflect the change below"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", x_pad, pframe.y_offset);
    f_txt:SetText(L["Active Loadout: "]);
    pframe.loadout_name_label = f_txt;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 355, pframe.y_offset);
    f_txt:SetText(L["Delta"]);

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        for _, v in pairs(pframe.stats) do
            v.editbox:SetText("");
        end
        update_calc_list();
    end);

    f:SetPoint("TOPLEFT", 385, pframe.y_offset+5);
    f:SetHeight(20);
    f:SetWidth(70);
    f:SetText(L["Clear"]);

     pframe.stats = {
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
         wep = {
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
         spell_pen = {
             label_str = L["Spell Penetration"]
         },
     };
     local comparison_stats_listing_order = {
         "str", "agi", "int", "spirit", "crit_rating", "hit_rating", "haste_rating",
         "", -- split column delimiter
         "ap", "rap", "wep", "sp", "sd", "hp", "mp5", "spell_pen",
     };

    local num_stats = 0;
    for _ in pairs(pframe.stats) do
        num_stats = num_stats + 1;
    end

    local y_offset_stats = pframe.y_offset;
    local max_y_offset_stats = 0;
    local i = 1;
    local x_offset = 0;
    local editbox_x_pad = 0;
    while i <= #comparison_stats_listing_order do

        local k = comparison_stats_listing_order[i];
        if k == "" then
            i = i + 1;
            -- split column special, skip
            k = comparison_stats_listing_order[i];
            y_offset_stats = pframe.y_offset;
            x_offset = x_offset + 210;
            editbox_x_pad = 50;
        end

        local v = pframe.stats[k];
        y_offset_stats = y_offset_stats - 17;

        v.label = pframe:CreateFontString(nil, "OVERLAY");

        v.label:SetFontObject(font);
        v.label:SetPoint("TOPLEFT", x_pad + x_offset, y_offset_stats);
        v.label:SetText(v.label_str);
        v.label:SetTextColor(222/255, 192/255, 40/255);

        v.editbox = CreateFrame("EditBox", v.label_str.."editbox"..k, pframe, "InputBoxTemplate");
        v.editbox:SetPoint("TOPLEFT", 100 + editbox_x_pad + x_offset, y_offset_stats-2);
        v.editbox:SetText("");
        v.editbox:SetAutoFocus(false);
        v.editbox:SetSize(100, 10);
        v.editbox:SetScript("OnTextChanged", function(self)

            if string.match(self:GetText(), "[^-+0123456789. ()]") ~= nil then
                self:ClearFocus();
                self:SetText("");
                self:SetFocus();
            else 
                update_calc_list();
            end
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
                next_index = 1 + ((i-2) %num_stats);
            else
                next_index = 1 + (i %num_stats);

            end
        	self:ClearFocus()
            pframe.stats[comparison_stats_listing_order[next_index]].editbox:SetFocus();
        end);

        max_y_offset_stats = math.min(max_y_offset_stats, y_offset_stats);
        i = i + 1;
    end

    pframe.y_offset = pframe.y_offset + max_y_offset_stats;

    pframe.stats.sp.editbox:SetText("1");
    pframe.stats.ap.editbox:SetText("1");
    pframe.stats.rap.editbox:SetText("1");
    if sc.core.__sw__test_all_codepaths then
        for _, v in pairs(pframe.stats) do
            v.editbox:SetText("1");
        end
    end

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;

    multi_row_checkbutton(
        {{id = "calc_list_use_highest_rank", txt = L["Use highest learned rank of spell"]}},
        pframe,
        2,
        function()
            update_calc_list();
        end,
        5);

    -- sim type button
    pframe.sim_type_button = libDD:Create_UIDropDownMenu("__sc_frame_setting_calc_fight_type", pframe);

    pframe.sim_type_button._type = "DropDownMenu";
    pframe.sim_type_button:SetPoint("TOPRIGHT", 10, pframe.y_offset);
    pframe.sim_type_button.init_func = function()
        libDD:UIDropDownMenu_Initialize(pframe.sim_type_button, function()
            
            if config.settings.calc_fight_type == fight_types.repeated_casts then
                libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Repeated casts"]);
                pframe.spell_diff_header_center:SetText(L["Per sec"]);
                pframe.spell_diff_header_right:SetText(L["Effect"]);
            elseif config.settings.calc_fight_type == fight_types.cast_until_oom then
                libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Cast until OOM"]);
                pframe.spell_diff_header_center:SetText(L["Effect"]);
                pframe.spell_diff_header_right:SetText(L["Duration (sec)"]);
            end
            libDD:UIDropDownMenu_SetWidth(pframe.sim_type_button, 130);

            libDD:UIDropDownMenu_AddButton(
                {
                    text = L["Repeated cast"],
                    checked = config.settings.calc_fight_type == fight_types.repeated_casts,
                    func = function()

                        config.settings.calc_fight_type = fight_types.repeated_casts;
                        libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Repeated casts"]);
                        pframe.spell_diff_header_center:SetText(L["Per sec"]);
                        pframe.spell_diff_header_right:SetText(L["Effect"]);
                        update_calc_list();
                    end
                }
            );
            libDD:UIDropDownMenu_AddButton(
                {
                    text = L["Cast until OOM"],
                    checked = config.settings.calc_fight_type == fight_types.cast_until_oom,
                    func = function()

                        config.settings.calc_fight_type = fight_types.cast_until_oom;
                        libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Cast until OOM"]);
                        pframe.spell_diff_header_center:SetText(L["Effect"]);
                        pframe.spell_diff_header_right:SetText(L["Duration (sec)"]);
                        update_calc_list();
                    end
                }
            );
        end);
    end;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Abilities can be added from Spells tab"]);
    f:SetTextColor(1.0,  1.0,  1.0);
    pframe.spells_add_tip = f;

    pframe.y_offset = pframe.y_offset - 17;
    pframe.y_offset = pframe.y_offset - 17;

    pframe.spell_diff_header_spell = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_spell:SetFontObject(font);
    pframe.spell_diff_header_spell:SetPoint("TOPLEFT", x_pad, pframe.y_offset);
    pframe.spell_diff_header_spell:SetText(L["Spell"]);

    pframe.spell_diff_header_left = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_left:SetFontObject(font);
    pframe.spell_diff_header_left:SetPoint("TOPLEFT", x_pad + 245, pframe.y_offset);
    pframe.spell_diff_header_left:SetText(L["Change"]);

    pframe.spell_diff_header_center = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_center:SetFontObject(font);
    pframe.spell_diff_header_center:SetPoint("TOPLEFT", x_pad + 320, pframe.y_offset);
    pframe.spell_diff_header_center:SetText("");

    pframe.spell_diff_header_right = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_right:SetFontObject(font);
    pframe.spell_diff_header_right:SetPoint("TOPLEFT", x_pad + 380, pframe.y_offset);
    pframe.spell_diff_header_right:SetText("");


    pframe.calc_list = {};
end

local function create_sw_ui_loadout_frame(pframe)
    local f, f_txt;

    pframe.y_offset = pframe.y_offset - 5;
    local x_pad = 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Loadouts are character specific, consisting of spell calculation parameters"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad, pframe.y_offset);
    f_txt:SetText(L["Active loadout"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = libDD:Create_UIDropDownMenu("pframe_loadout_dropdown", pframe);
    f:SetPoint("TOPLEFT", x_pad + 80, pframe.y_offset+7);
    f.init_func = function()
        libDD:UIDropDownMenu_SetText(pframe.loadout_dropdown, config.loadout.name);
        libDD:UIDropDownMenu_Initialize(pframe.loadout_dropdown, function()

            libDD:UIDropDownMenu_SetWidth(pframe.loadout_dropdown, 100);

            for k, v in pairs(__sc_p_char.loadouts) do
                libDD:UIDropDownMenu_AddButton({
                        text = v.name,
                        checked = __sc_p_char.active_loadout == k,
                        func = function()
                            sc.core.talents_update_needed = true;
                            sc.core.equipment_update_needed = true;

                            config.set_active_loadout(k);
                            update_loadout_frame();
                        end
                    }
                );
            end
        end);
    end;
    pframe.loadout_dropdown = f;

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", pframe, x_pad + 300, pframe.y_offset+6);
    f:SetText(L["Reset to defaults"]);
    f:SetSize(140, 25);
    f:SetScript("OnClick", function(self)


        config.reset_loadout();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);

    pframe.y_offset = pframe.y_offset - 25;
    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    f:SetText(L["Rename"]);
    f:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_name", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("TOPLEFT", pframe, x_pad + 105, pframe.y_offset+2);
    f:SetSize(90, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)

        local txt = self:GetText();
        config.loadout.name = txt;
        update_loadout_frame();
    end
    f:SetScript("OnEnterPressed", function(self)
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnEscapePressed", function(self)
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnTextChanged", editbox_save);
    pframe.name_editbox = f;

    f = CreateFrame("Button", "__sc_frame_loadouts_delete_button", pframe, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", pframe, x_pad + 300, pframe.y_offset+6);
    f:SetText(L["Delete"]);
    f:SetSize(140, 25);
    f:SetScript("OnClick", function(self)

        config.delete_loadout();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);
    pframe.delete_button = f;

    pframe.y_offset = pframe.y_offset - 25;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    f:SetText(L["New loadout"]);
    f:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", nil, pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", pframe, x_pad + 105, pframe.y_offset+3);
    f:SetSize(90, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)

        local txt = self:GetText();
        if txt ~= "" then

            for _, v in pairs(pframe.new_loadout_section) do
                v:Show();
            end
        else
            for _, v in pairs(pframe.new_loadout_section) do
                v:Hide();
            end
        end
    end
    editbox_config(f, editbox_save);
    pframe.new_loadout_name_editbox = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad + 200, pframe.y_offset);
    f_txt:SetText(L["from"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.new_loadout_txt1 = f_txt;

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        if config.new_loadout_from_default(pframe.new_loadout_name_editbox:GetText()) then
            pframe.new_loadout_name_editbox:SetText("");
            sc.core.talents_update_needed = true;
            update_loadout_frame();
        end
    end);
    f:SetPoint("TOPLEFT", x_pad + 250, pframe.y_offset+6);
    f:SetText(L["Default"]);
    f:SetWidth(100);
    pframe.new_loadout_button1 = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad + 360, pframe.y_offset);
    f_txt:SetText(L["or"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.new_loadout_txt2 = f_txt;

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        if config.new_loadout_from_active_copy(pframe.new_loadout_name_editbox:GetText()) then
            pframe.new_loadout_name_editbox:SetText("");
            sc.core.talents_update_needed = true;
            update_loadout_frame();
        end
    end);
    f:SetPoint("TOPLEFT", x_pad + 380, pframe.y_offset+6);
    f:SetText(L["Copy"]);
    f:SetWidth(80);
    pframe.new_loadout_button2 = f;

    pframe.new_loadout_section = {
        pframe.new_loadout_txt1,
        pframe.new_loadout_txt2,
        pframe.new_loadout_button1,
        pframe.new_loadout_button2
    };

    pframe.y_offset = pframe.y_offset - 20;
    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 5;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText(L["Player"]);
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 20;


    f = CreateFrame("CheckButton", "__sc_frame_loadout_use_custom_lvl", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    f:SetHitRectInsets(0, 0, 0, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Custom player level"]);
    getglobal(f:GetName()).tooltip =
        L["Displays ability information as if character is a custom level (attributes from levels are not accounted for)."];

    f:SetScript("OnClick", function(self)

        config.loadout.use_custom_lvl = self:GetChecked();
        sc.core.old_ranks_checks_needed = true;
        if config.loadout.use_custom_lvl then
            pframe.loadout_clvl_editbox:Show();
        else
            pframe.loadout_clvl_editbox:Hide();
        end
    end);
    pframe.custom_lvl_checkbutton = f;

    f = CreateFrame("EditBox", "__sc_frame_loadout_lvl", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", getglobal(pframe.custom_lvl_checkbutton:GetName()..'Text'), "RIGHT", 10, 0);
    f:SetSize(50, 15);
    f:SetAutoFocus(false);
    f:Hide();
    f.number_editbox = true;
    local clvl_editbox_update = function(self)
        local lvl = tonumber(self:GetText());
        local valid = lvl and lvl >= 1 and lvl <= 100;
        sc.core.old_ranks_checks_needed = true;
        if valid then
            config.loadout.lvl = lvl;
        end
        return valid;
    end
    local clvl_editbox_close = function(self)
        if not clvl_editbox_update(self) then
            local clvl = UnitLevel("player");
            self:SetText(""..clvl);
        end

    	self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, clvl_editbox_update, clvl_editbox_close);
    pframe.loadout_clvl_editbox = f;

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_always_max_resource", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Always at maximum resources"]);
    getglobal(f:GetName()).tooltip = 
        L["Assumes you are casting from maximum mana, energy, rage or combo points."];
    f:SetScript("OnClick", function(self)
        config.loadout.always_max_resource = self:GetChecked();
    end)
    pframe.max_mana_checkbutton = f;


    pframe.y_offset = pframe.y_offset - 25;


    f = CreateFrame("CheckButton", "__sc_frame_loadout_use_custom_talents", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);

    getglobal(f:GetName()..'Text'):SetText(L["Custom talents"]);
    getglobal(f:GetName()).tooltip =
        L["Accepts a valid wowhead talents link, your loadout will use its talents & glyphs instead of your active ones."];
    f:SetScript("OnClick", function(self)

       config.loadout.use_custom_talents = self:GetChecked();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);
    pframe.y_offset = pframe.y_offset - 23;

    f = CreateFrame("EditBox", "__sc_frame_loadout_talent_editbox", pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", pframe, x_pad+25, pframe.y_offset);
    f:SetSize(437, 15);
    f:SetAutoFocus(false);
    editbox_config(f, function(self)

        local txt = self:GetText();
        sc.core.talents_update_needed = true;

        if config.loadout.use_custom_talents then
            if txt ~= "" then
                config.loadout.custom_talents_code = wowhead_talent_code_from_url(txt);
            end

            pframe.talent_editbox:SetText(
                wowhead_talent_link(config.loadout.custom_talents_code)
            );
            pframe.talent_editbox:SetAlpha(1.0);
        else

            pframe.talent_editbox:SetText(
                wowhead_talent_link(active_loadout().talents.code)
            );
            pframe.talent_editbox:SetAlpha(0.2);
            pframe.talent_editbox:SetCursorPosition(0);
        end
        self:ClearFocus();
    end);

    pframe.talent_editbox = f;
    pframe.y_offset = pframe.y_offset - 23;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+4, pframe.y_offset);
    f_txt:SetText(L["Extra mana for casts until OOM"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_extra_mana", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local mana_editbox_update = function(self)

        sc.loadouts.force_update = true;
        local mana = tonumber(self:GetText());
        local valid = mana ~= nil;
        if valid then
            config.loadout.extra_mana = mana;
        end
        return valid;
    end
    local mana_editbox_close = function(self)
        if not mana_editbox_update(self) then
            self:SetText("0");
            config.loadout.extra_mana = 0;
        end
    	self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, mana_editbox_update, mana_editbox_close);
    pframe.loadout_extra_mana_editbox = f;


    pframe.y_offset = pframe.y_offset - 20;
    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;
    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText(L["Target"]);
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 25;

    pframe.auto_armor_frames = {};
    pframe.custom_armor_frames = {};

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Estimate armor"]);
    getglobal(f:GetName()).tooltip = 
        L["Estimates armor from target level."];
    f:SetScript("OnClick", function(self)
        local checked = self:GetChecked();
        config.loadout.target_automatic_armor = checked;
        if checked then
            for _, v in pairs(pframe.auto_armor_frames) do
                v:Show();
            end
            for _, v in pairs(pframe.custom_armor_frames) do
                v:Hide();
            end
        else
            for _, v in pairs(pframe.auto_armor_frames) do
                v:Hide();
            end
            for _, v in pairs(pframe.custom_armor_frames) do
                v:Show();
            end
        end
    end);
    f:SetHitRectInsets(0, 0, 0, 0);
    pframe.automatic_armor = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", getglobal(f:GetName()..'Text'), "RIGHT", 50, 0);
    f_txt:SetText(L["Custom armor value"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.custom_armor_frames[1] = f_txt;


    f = CreateFrame("EditBox", "__sc_frame_loadout_target_armor", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_target_armor_update = function(self)
        sc.loadouts.force_update = true;
        local target_armor = tonumber(self:GetText());
        local valid = target_armor and target_armor >= 0;
        if valid then
            config.loadout.target_armor = target_armor;
        end
        return valid;
    end
    local editbox_target_armor_close = function(self)

        if not editbox_target_armor_update(self) then
            self:SetText("0");
            config.loadout.target_armor = 0;
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_target_armor_update, editbox_target_armor_close);
    pframe.custom_armor_frames[2] = f;

    local armor_pct_fn = function(self)
        if self:GetChecked() then
            config.loadout.target_automatic_armor_pct = self._value;
        end
        for _, v in pairs(pframe.auto_armor_frames) do
            v:SetChecked(config.loadout.target_automatic_armor_pct == v._value);
        end
    end;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_100", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 100;
    f:SetPoint("LEFT", getglobal(pframe.automatic_armor:GetName()..'Text'), "RIGHT", 40, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Heavy"].." 100%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[1] = f;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_80", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 80;
    f:SetPoint("LEFT", getglobal(pframe.auto_armor_frames[1]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Medium"].." 80%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[2] = f;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_50", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 50;
    f:SetPoint("LEFT", getglobal(pframe.auto_armor_frames[2]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Light"].." 50%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[3] = f;

    for _, v in pairs(pframe.auto_armor_frames) do
        v:Hide();
    end
    for _, v in pairs(pframe.custom_armor_frames) do
        v:Show();
    end

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_behind_target", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Attacked from behind, eliminating parry and block"]);
    f:SetScript("OnClick", function(self)
        config.loadout.behind_target = self:GetChecked();
    end)

    pframe.y_offset = pframe.y_offset - 30;


    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Level difference"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_default_target_lvl_diff", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_update = function(self)
        -- silently try to apply valid changes but don't panic while focus is on
        local lvl_diff = tonumber(self:GetText());
        local valid = lvl_diff and lvl_diff == math.floor(lvl_diff) and config.loadout.lvl + lvl_diff >= 1 and config.loadout.lvl + lvl_diff <= 83;
        if valid then

            config.loadout.default_target_lvl_diff = lvl_diff;
        end
        return valid;
    end;
    local editbox_close = function(self)

        if not editbox_update(self) then
            self:SetText(""..config.loadout.default_target_lvl_diff);
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_update, editbox_close);
    pframe.level_editbox = f;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("LEFT", pframe.level_editbox, "RIGHT", 10, 0);
    f:SetText(L["(when no hostile target available)"]);
    f:SetTextColor(1.0,  1.0,  1.0);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Resistance"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_target_res", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_target_res_update = function(self)
        local target_res = tonumber(self:GetText());
        local valid = target_res and target_res >= 0;
        if valid then
            config.loadout.target_res = target_res;
        end
        return valid;
    end
    local editbox_target_res_close = function(self)

        if not editbox_target_res_update(self) then
            self:SetText("0");
            config.loadout.target_res = 0;
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, editbox_target_res_update, editbox_target_res_close);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Default health"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_default_target_hp_perc", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_hp_perc_update = function(self)
        local hp_perc = tonumber(self:GetText());
        local valid = hp_perc and hp_perc >= 0;
        if valid then
            config.loadout.default_target_hp_perc = hp_perc;
        end
        return valid;
    end
    local editbox_hp_perc_close = function(self)

        if not editbox_hp_perc_update(self) then
            self:SetText(""..loadout.default_target_hp_perc);
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_hp_perc_update, editbox_hp_perc_close);
    pframe.hp_perc_label_editbox = f;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", f, "RIGHT", 5, 0);
    f_txt:SetText("%");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Number of targets for unbounded AOE spells"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_unbounded_aoe_targets", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local aoe_targets_editbox_update = function(self)
        local targets = tonumber(self:GetText());
        local valid = targets and targets >= 1;
        if valid then
            config.loadout.unbounded_aoe_targets = math.floor(targets);
        end
        return valid;
    end
    local aoe_targets_editbox_close = function(self)
        if not aoe_targets_editbox_update(self) then
            self:SetText("1");
            config.loadout.unbounded_aoe_targets = 1;
        end
    	self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, aoe_targets_editbox_update, aoe_targets_editbox_close);
    pframe.loadout_unbounded_aoe_targets_editbox = f;

end

local forced_buffs_lname_to_id = {};

local function create_sw_ui_buffs_frame(pframe)

    local f, f_txt;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_force_apply_buffs", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, 0, pframe.y_offset);
    getglobal(f:GetName() .. 'Text'):SetText(L["Enable selected auras even when inactive"]);
    getglobal(f:GetName()).tooltip = 
        L["The selected buffs will be applied behind the scenes to the spell calculations."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.loadout.force_apply_buffs = self:GetChecked();
        update_buffs_frame();
    end);
    pframe.always_apply_buffs_button = f;

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("EditBox", "__sc_frame_buffs_search", pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 8, pframe.y_offset);
    f:SetSize(160, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            pframe.search_empty_label:Show();
            for _, view in ipairs(buffs_views) do
                for k, _ in ipairs(view.buffs) do
                    view.filtered[k] = k;
                end
            end
        else
            pframe.search_empty_label:Hide();
            local num = tonumber(txt);
            for _, view in ipairs(buffs_views) do
                view.filtered = {};
                for k, v in ipairs(view.buffs) do
                    if string.find(string.lower(v.lname), string.lower(txt)) or 
                        (num and num == v.id) then
                        table.insert(view.filtered, k);
                    end
                end
            end
        end
        for _, view in ipairs(buffs_views) do
            pframe[view.side].slider:SetMinMaxValues(1, max(1, #view.filtered - math.floor(pframe[view.side].num_buffs_can_fit/2)));
        end
        update_buffs_frame();
    end);
    pframe.search = f;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Search name or ID"]);
    f:SetPoint("LEFT", pframe.search, 5, 0);
    pframe.search_empty_label = f;

    for view_idx, view in ipairs(buffs_views) do

        -- init without any filter, 1 to 1
        for k, _ in ipairs(view.buffs) do
            view.filtered[k] = k;
        end

        local y_offset = pframe.y_offset;

        y_offset = y_offset - 20;

        f = CreateFrame("ScrollFrame", "pframe_"..view.side, pframe);
        f:SetWidth(235);
        f:SetHeight(490);
        f:SetPoint("TOPLEFT", pframe, 240*(view_idx-1), y_offset);
        pframe[view.side] = {}
        pframe[view.side].frame = f;

        f = CreateFrame("ScrollFrame", "__sc_frame_buffs_list_"..view.side, pframe[view.side].frame);
        f:SetWidth(235);
        f:SetHeight(455);
        f:SetPoint("TOPLEFT", pframe[view.side].frame, 0, -35);
        pframe[view.side].buffs_list_frame = f;

        pframe[view.side].num_checked = 0;
        pframe[view.side].buffs = {};
        pframe[view.side].buffs_num = 0;

        y_offset = -5;

        f = pframe[view.side].frame:CreateFontString(nil, "OVERLAY");
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
        f = CreateFrame("CheckButton", "__sc_frame_check_all_"..view.side, pframe[view.side].frame, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", 20, y_offset);
        getglobal(f:GetName() .. 'Text'):SetText(L["Select all/none"]);
        getglobal(f:GetName() .. 'Text'):SetTextColor(1, 0, 0);

        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;

            if self:GetChecked() then
                if view.side == "lhs" then
                    for _, v in ipairs(view.buffs) do
                        config.loadout.buffs[v.id] = 1;
                        forced_buffs_lname_to_id[GetSpellInfo(v.id)] = v.id;
                    end
                else
                    for _, v in ipairs(view.buffs) do
                        config.loadout.target_buffs[v.id] = 1;
                        forced_buffs_lname_to_id[GetSpellInfo(v.id)] = v.id;
                    end
                end
            else
                if view.side == "lhs" then
                    config.loadout.buffs = {};
                else
                    config.loadout.target_buffs = {};
                end
            end

            update_buffs_frame();
        end);
        pframe[view.side].select_all_buffs_checkbutton = f;

        f = CreateFrame("Slider", nil, pframe[view.side].buffs_list_frame, "UIPanelScrollBarTrimTemplate");
        f:SetOrientation('VERTICAL');
        f:SetPoint("RIGHT", pframe[view.side].buffs_list_frame, "RIGHT", 0, 2);
        f:SetHeight(pframe[view.side].buffs_list_frame:GetHeight()-30);
        pframe[view.side].num_buffs_can_fit =
            math.floor(pframe[view.side].buffs_list_frame:GetHeight()/15);
        f:SetMinMaxValues( 1, max(1, #view.filtered - math.floor(pframe[view.side].num_buffs_can_fit/2)));
        f:SetValue(1);
        f:SetValueStep(1);
        f:SetScript("OnValueChanged", function(self, val)
            update_buffs_frame();
        end);

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f);
        bg:SetColorTexture(0, 0, 0, 0.5);

        pframe[view.side].slider = f;

        pframe[view.side].buffs_list_frame:SetScript("OnMouseWheel", function(self, dir)
            local min_val, max_val = pframe[view.side].slider:GetMinMaxValues();
            local val = pframe[view.side].slider:GetValue();
            if val - dir >= min_val and val - dir <= max_val then
                pframe[view.side].slider:SetValue(val - dir);
                update_buffs_frame();
            end
        end);


        y_offset = 0;
        for i = 1, pframe[view.side].num_buffs_can_fit do
            pframe[view.side].buffs[i] = {};

            local checkbtn = CreateFrame("CheckButton", "loadout_buffs_checkbutton"..view.side..i, pframe[view.side].buffs_list_frame, "ChatConfigCheckButtonTemplate");
            checkbtn.side = view.side;
            checkbtn:SetScript("OnMouseDown", function(self, btn)

                sc.loadouts.force_update = true;
                local config_buffs;
                if view.side == "lhs" then
                    config_buffs = config.loadout.buffs;
                else
                    config_buffs = config.loadout.target_buffs;
                end
                if btn == "LeftButton" then
                    if not config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = 1;

                        forced_buffs_lname_to_id[GetSpellInfo(self.buff_id)] = self.buff_id;
                        pframe[view.side].num_checked = pframe[view.side].num_checked + 1;
                    else
                        config_buffs[self.buff_id] = nil;
                        forced_buffs_lname_to_id[GetSpellInfo(self.buff_id)] = nil;
                        pframe[view.side].num_checked = pframe[view.side].num_checked - 1;
                    end

                    if pframe[view.side].num_checked == 0 then
                        pframe[view.side].select_all_buffs_checkbutton:SetChecked(false);
                    else
                        pframe[view.side].select_all_buffs_checkbutton:SetChecked(true);
                    end
                elseif btn == "Button4" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = math.max(1, config_buffs[self.buff_id] - 1);
                    end
                elseif btn == "Button5"  or btn == "RightButton" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = config_buffs[self.buff_id] + 1;
                    end
                end
                self.__stacks_str:SetText(tostring(config_buffs[self.buff_id] or 0));
            end);
            local icon = CreateFrame("Frame", "loadout_buffs_icon"..view.side..i, pframe[view.side].buffs_list_frame);
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

            pframe[view.side].buffs[i].checkbutton = checkbtn;
            pframe[view.side].buffs[i].icon = icon;
        end
    end
end

local function update_profile_frame()

    sc.config.set_active_settings();

    __sc_frame.profile_frame.primary_spec.init_func();
    __sc_frame.profile_frame.second_spec.init_func();

    __sc_frame.profile_frame.active_main_spec:Hide();
    __sc_frame.profile_frame.active_second_spec:Hide();
    if sc.core.active_spec == 1 then
        __sc_frame.profile_frame.active_main_spec:Show();
    else
        __sc_frame.profile_frame.active_second_spec:Show();
    end

    __sc_frame.profile_frame.delete_profile_button:Hide();
    __sc_frame.profile_frame.delete_profile_label:Hide();

    local cnt = 0;
    for _, _ in pairs(__sc_p_acc.profiles) do
        cnt = cnt + 1;
        if cnt > 1 then
            break;
        end
    end
    if cnt > 1 then

        __sc_frame.profile_frame.delete_profile_button:Show();
        __sc_frame.profile_frame.delete_profile_label:Show();
    end

    __sc_frame.profile_frame.rename_editbox:SetText(config.active_profile_name);
end

local function create_sw_ui_profile_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    local rhs_offset = 250;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Profiles are shared across characters and retain all settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 12;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["  except for Loadouts and Buffs"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    pframe.y_offset = pframe.y_offset - 35;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Main spec profile"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    pframe.primary_spec = 
        --CreateFrame("Button", "__sc_frame_profile_main_spec", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_profile_main_spec", pframe);
    pframe.primary_spec:SetPoint("TOPLEFT", rhs_offset-20, pframe.y_offset+6);
    pframe.primary_spec.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.primary_spec, __sc_p_char.main_spec_profile);
        libDD:UIDropDownMenu_Initialize(pframe.primary_spec, function()

            libDD:UIDropDownMenu_SetWidth(pframe.primary_spec, 130);

            for k, _ in pairs(__sc_p_acc.profiles) do
                libDD:UIDropDownMenu_AddButton({
                        text = k,
                        checked = __sc_p_char.main_spec_profile == k,
                        func = function()
                            __sc_p_char.main_spec_profile = k;
                            libDD:UIDropDownMenu_SetText(pframe.primary_spec, k);
                            update_profile_frame();
                            sc.config.activate_settings();
                        end
                    }
                );
            end
        end);
    end;

    pframe.active_main_spec = pframe:CreateFontString(nil, "OVERLAY");
    pframe.active_main_spec:SetFontObject(GameFontNormal);
    pframe.active_main_spec:SetPoint("TOPLEFT", rhs_offset+150, pframe.y_offset);
    pframe.active_main_spec:SetText("<--- ".. L["Active"]);
    pframe.active_main_spec:SetTextColor(1.0,  0.0,  0.0);


    pframe.y_offset = pframe.y_offset - 25;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Secondary spec profile"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    pframe.second_spec = 
        --CreateFrame("Button", "__sc_frame_profile_second_spec", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_profile_second_spec", pframe);
    pframe.second_spec:SetPoint("TOPLEFT", rhs_offset-20, pframe.y_offset+6);
    pframe.second_spec.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.second_spec, __sc_p_char.second_spec_profile);
        libDD:UIDropDownMenu_Initialize(pframe.second_spec, function()

            libDD:UIDropDownMenu_SetWidth(pframe.second_spec, 130);

            for k, _ in pairs(__sc_p_acc.profiles) do

                libDD:UIDropDownMenu_AddButton({
                        text = k,
                        checked = __sc_p_char.second_spec_profile == k,
                        func = function()
                            __sc_p_char.second_spec_profile = k;
                            libDD:UIDropDownMenu_SetText(pframe.second_spec, k);
                            update_profile_frame();
                            sc.config.activate_settings();
                        end
                    }
                );
            end
        end);
    end;

    pframe.active_second_spec = pframe:CreateFontString(nil, "OVERLAY");
    pframe.active_second_spec:SetFontObject(GameFontNormal);
    pframe.active_second_spec:SetPoint("TOPLEFT", 350, pframe.y_offset);
    pframe.active_second_spec:SetText("<--- "..L["Active"]);
    pframe.active_second_spec:SetTextColor(1.0,  0.0,  0.0);

    pframe.y_offset = pframe.y_offset - 35;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Rename active profile"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", "__sc_frame_profile_name_editbox", pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", pframe, rhs_offset+5, pframe.y_offset+3);
    f:SetSize(195, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)

        local txt = self:GetText();
        local k = sc.config.spec_keys[sc.core.active_spec];

        if __sc_p_char[k] ~= txt then

            __sc_p_acc.profiles[txt] = __sc_p_acc.profiles[__sc_p_char[k]];
            __sc_p_acc.profiles[__sc_p_char[k]] = nil
            __sc_p_char[k] = txt;
        end
        update_profile_frame()

    end
    f:SetScript("OnEnterPressed", function(self) 
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnEscapePressed", function(self) 
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnTextChanged", editbox_save);
    pframe.rename_editbox = f;

    pframe.y_offset = pframe.y_offset - 35;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Reset active profile"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        config.reset_profile();
    end);
    f:SetPoint("TOPLEFT", rhs_offset, pframe.y_offset+4);
    f:SetText(L["Reset to defaults"]);
    f:SetWidth(200);

    pframe.y_offset = pframe.y_offset - 35;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Delete active profile"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    pframe.delete_profile_label = f_txt;

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        config.delete_profile();
        update_profile_frame();
        sc.config.activate_settings();
    end);
    f:SetPoint("TOPLEFT", rhs_offset, pframe.y_offset+4);
    f:SetText(L["Delete"]);
    f:SetWidth(200);
    pframe.delete_profile_button = f;

    pframe.y_offset = pframe.y_offset - 35;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["New profile name"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", nil, pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", pframe, rhs_offset+5, pframe.y_offset+3);
    f:SetSize(195, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)
        local txt = self:GetText();
        if txt ~= "" then

            for _, v in pairs(pframe.new_profile_section) do
                v:Show();
            end
        else
            for _, v in pairs(pframe.new_profile_section) do
                v:Hide();
            end
        end
    end
    f:SetScript("OnEnterPressed", function(self)
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnEscapePressed", function(self)
        editbox_save(self);
        self:ClearFocus();
    end);
    f:SetScript("OnTextChanged", editbox_save);
    pframe.new_profile_name_editbox = f;


    pframe.y_offset = pframe.y_offset - 35;
    pframe.new_profile_section = {};
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Create new profile as:"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.new_profile_section.txt1 = f_txt;


    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        if config.new_profile_from_default(pframe.new_profile_name_editbox:GetText()) then
            pframe.new_profile_name_editbox:SetText("");
        end
        update_profile_frame();
        sc.config.activate_settings();
    end);
    f:SetPoint("TOPLEFT", rhs_offset, pframe.y_offset+4);
    f:SetText(L["Default preset"]);
    f:SetWidth(200);
    pframe.new_profile_section.button1 = f;

    pframe.y_offset = pframe.y_offset - 25;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", rhs_offset, pframe.y_offset);
    f_txt:SetText(L["or"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.new_profile_section.txt2 = f_txt;

    pframe.y_offset = pframe.y_offset - 25;
    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        if config.new_profile_from_active_copy(pframe.new_profile_name_editbox:GetText()) then
            pframe.new_profile_name_editbox:SetText("");
        end
        update_profile_frame();
        sc.config.activate_settings();
    end);
    f:SetPoint("TOPLEFT", rhs_offset, pframe.y_offset+4);
    f:SetText(L["Copy of active profile"]);
    f:SetWidth(200);
    pframe.new_profile_section.button2 = f;
end

local average_proc_sidebuffer = {};

local function create_sw_ui_settings_frame(pframe)

    local f, f_txt;

    pframe.y_offset = pframe.y_offset - 5;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["General settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    local general_settings = {
        {
            id = "general_libstub_minimap_icon",
            txt = L["Minimap icon"],
            func = function(self)

                local checked = self:GetChecked();
                if checked then
                    libstub_icon:Show(sc.core.addon_name);
                else
                    libstub_icon:Hide(sc.core.addon_name);
                end
                config.settings.libstub_icon_conf.hide = not checked;
            end,
        },
        {
            id = "general_spellbook_button",
            txt = L["Spellbook tab button"],
            func = function(self)
                if __sc_frame_spellbook_tab then
                    if self:GetChecked() then
                        __sc_frame_spellbook_tab:Show();
                    else
                        __sc_frame_spellbook_tab:Hide();
                    end
                end
            end,
        },
        {
            id = "general_version_mismatch_notify",
            txt = L["Notify about addon and client version mismatch"],
        },
    };

    multi_row_checkbutton(general_settings, pframe, 1);

    pframe.y_offset = pframe.y_offset - 10;

    if sc.loc.locale_found then

        f_txt = pframe:CreateFontString(nil, "OVERLAY");
        f_txt:SetFontObject(GameFontNormal);
        f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
        f_txt:SetText(string.format("%s | %s", L["Localization"], sc.locale));
        f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

        if #sc.loc.missing_strings > 0 then
            f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
            f:SetScript("OnClick", function()

                dump_text(
                    "Missing strings need to go into SpellCoda/locale/"..sc.locale..".lua",
                    format_locale_dump(sc.loc.missing_strings)
                );
            end);

            f:SetPoint("TOPLEFT", 130, pframe.y_offset+5);
            f:SetHeight(20);
            f:SetWidth(170);
            f:SetText(L["Show missing"]..": "..#sc.loc.missing_strings);
        end

        if #sc.loc.obsolete_strings > 0 then
            f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
            f:SetScript("OnClick", function()

                dump_text(
                    "Obsolete strings should be removed from SpellCoda/locale/"..sc.locale..".lua",
                    format_locale_dump(sc.loc.obsolete_strings)
                );
            end);

            f:SetPoint("TOPLEFT", 300, pframe.y_offset+5);
            f:SetHeight(20);
            f:SetWidth(170);
            f:SetText(L["Show obsolete"]..": "..#sc.loc.obsolete_strings);
        end

        pframe.y_offset = pframe.y_offset - 15;

        f = CreateFrame("CheckButton", "__spellcoda_localization_btn", pframe, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", pframe, 5, pframe.y_offset);
        getglobal(f:GetName()..'Text'):SetText(L["Localization (requires /reload)"]);

        -- bypass profile storage for this one, make account wide
        if __sc_p_acc.localization_use then
            f:SetChecked(true);
        else
            f:SetChecked(false);
        end
        f:SetScript("OnClick", function(self)
            __sc_p_acc.localization_use = self:GetChecked();
        end);

        pframe.y_offset = pframe.y_offset - 25;
    end

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    local spell_settings = {
        {
            id = "general_prio_heal",
            txt = L["Prioritize healing for hybrid spells with both damage and healing"],
        },
        {
            id = "general_prio_multiplied_effect",
            txt = L["Prioritize optimistic effect over single effect"],
        },
        {
            id = "general_average_proc_effects",
            txt = L["Average out proc effects"],
            tooltip = L["Removes many proc effects and instead averages out its effect, giving more meaning to the spell evaluation. Example: Nature's grace modifies expected cast time to scale with crit, giving crit higher stat weight. Clearcasts and such."],
            func = function(self)

                if self:GetChecked() then

                    if sc.lookups.averaged_procs then
                        -- move average procs into sidebuffer
                        for _, v in ipairs(sc.lookups.averaged_procs) do
                            if sc.class_buffs[v] then
                                average_proc_sidebuffer[v] = sc.class_buffs[v];
                                sc.class_buffs[v] = nil;
                            end
                        end
                    end
                else
                    if sc.lookups.averaged_procs then
                        -- move average procs from side buffer into applicable buffs
                        for _, v in ipairs(sc.lookups.averaged_procs) do
                            if average_proc_sidebuffer[v] then
                                sc.class_buffs[v] = average_proc_sidebuffer[v];
                                average_proc_sidebuffer[v] = nil;
                            end
                        end
                    end
                end
            end
        },
    };

    multi_row_checkbutton(spell_settings, pframe, 1);

    pframe.y_offset = pframe.y_offset - 10;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Color palette RGB"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;
    -- headers
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Tag"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 230, pframe.y_offset);
    f_txt:SetText(L["Red"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 310, pframe.y_offset);
    f_txt:SetText(L["Green"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 390, pframe.y_offset);
    f_txt:SetText(L["Blue"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    pframe.y_offset = pframe.y_offset - 15;
    for _, v in ipairs({
        {"normal", L["Normal"]},
        {"crit", L["Critical"]},
        {"old_rank", L["Old rank"]},
        {"target_info", L["Target info"]},
        {"avoidance_info", L["Avoidance/mitigation info"]},
        {"expectation", L["Effect expectation"]},
        {"effect_per_sec", L["Effect per sec"]},
        {"threat", L["Threat"]},
        {"execution_time", L["Execution time"]},
        {"cost", L["Cost"]},
        {"effect_per_cost", L["Effect per cost"]},
        {"cost_per_sec", L["Effect per sec"]},
        {"effect_until_oom", L["Effect until OOM"]},
        {"casts_until_oom", L["Casts until OOM"]},
        {"time_until_oom", L["Time until OOM"]},
        {"sp_effect", L["Spell info internals (coefs etc)"]},
        {"stat_weights", L["Stat weights"]},
        {"spell_rank", L["Spell rank"]},

    }) do
        local label_frame_setting_subkey = "general_color_"..v[1];
        do
            f_txt = pframe:CreateFontString(nil, "OVERLAY");
            f_txt:SetFontObject(GameFontNormal);
            f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset-4);
            f_txt:SetText(v[2]);
            register_text_frame_color(f_txt, v[1]);
        end

        for i, rgb_comp in pairs({"_r", "_g", "_b"}) do
            local option_key = label_frame_setting_subkey..rgb_comp;
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 230 + (i-1)*80, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                local valid = val and val >= 0 and val <= 255
                if valid then
                    config.settings[self._settings_id] = val;
                    assign_color_tag(v[1], i, val);
                    for frame, color_tag in pairs(colored_text_frames) do
                        if color_tag == v[1] then
                            frame:SetTextColor(effect_color(v[1]));
                        end
                    end
                    sc.core.update_action_bar_needed = true;
                    sc.loadouts.force_update = true;
                    for label in pairs(sc.overlay.ccf_labels) do
                        sc.overlay.ccf_label_reconfig(label);
                    end
                end
                return valid;
            end
            local close = function(self)
                if not update(self) then
                    self:SetText(""..config.default_settings[self._settings_id]);
                end

            	self:ClearFocus();
                self:HighlightText(0,0);
            end
            editbox_config(f, update, close);

            f_txt = pframe:CreateFontString(nil, "OVERLAY");
            f_txt:SetFontObject(GameFontNormal);
            f_txt:SetPoint("TOPLEFT", 230+(i-1)*80 + 38, pframe.y_offset-4);
            f_txt:SetText("/255");
            f_txt:SetTextColor(1, 1, 1);
        end
        pframe.y_offset = pframe.y_offset - 16;
    end
end

local function create_sw_base_ui()

    __sc_frame = CreateFrame("Frame", "__sc_frame", UIParent, "BasicFrameTemplate, BasicFrameTemplateWithInset");

    __sc_frame:SetFrameStrata("HIGH");
    __sc_frame:SetMovable(true);
    __sc_frame:EnableMouse(true);
    __sc_frame:RegisterForDrag("LeftButton");
    __sc_frame:SetScript("OnDragStart", __sc_frame.StartMoving);
    __sc_frame:SetScript("OnDragStop", __sc_frame.StopMovingOrSizing);

    local width = 500;
    local height = 600;

    __sc_frame:SetWidth(width);
    __sc_frame:SetHeight(height);
    __sc_frame:SetPoint("TOPLEFT", 400, -30);

    __sc_frame.title = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.title:SetFontObject(font)
    __sc_frame.title:SetText(sc.core.addon_name.." v"..sc.core.version);
    __sc_frame.title:SetPoint("CENTER", __sc_frame.TitleBg, "CENTER", 0, 0);

    __sc_frame:Hide();

    local tabbed_child_frames_y_offset = 20;
    local x_margin = 15;

    for _, v in pairs({"spells_frame", "tooltip_frame", "overlay_frame", "loadout_frame", "buffs_frame", "calculator_frame", "profile_frame", "settings_frame"}) do
        __sc_frame[v] = CreateFrame("ScrollFrame", "__sc_frame_"..v, __sc_frame);
        __sc_frame[v]:SetPoint("TOP", __sc_frame, 0, -tabbed_child_frames_y_offset-35);
        __sc_frame[v]:SetWidth(width-x_margin*2);
        __sc_frame[v]:SetHeight(height-tabbed_child_frames_y_offset-35-5);
        __sc_frame[v].y_offset = 0;
    end

    for k, _ in pairs(sc.core.event_dispatch) do
        if not sc.core.event_dispatch_client_exceptions[k] or
                sc.core.event_dispatch_client_exceptions[k] == sc.expansion then
            __sc_frame:RegisterEvent(k);
        end
    end

    if bit.band(sc.game_mode, sc.game_modes.hardcore) == 0 then
        __sc_frame:UnregisterEvent("PLAYER_REGEN_DISABLED");
    end

    __sc_frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
        sc.core.event_dispatch[event](self, arg1, arg2, arg3);
        end
    );

    __sc_frame.tabs = {};

    local i = 1;

    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetID(1);
    __sc_frame.tabs[i]:SetScript("OnClick", function(self)
        sw_activate_tab(self);
    end);
    __sc_frame.tabs[i].frame_to_open = __sc_frame.spells_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.tooltip_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.overlay_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.calculator_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.profile_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.loadout_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.buffs_frame;

    i = i + 1;
    -- Set settings cogwheel button
    local btn = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame);
    btn:SetSize(16, 16);

    local tex = btn:CreateTexture(nil, "ARTWORK");
    tex:SetTexture("Interface\\Buttons\\UI-OptionsButton");
    tex:SetSize(16, 16);
    tex:SetAllPoints();
    btn:SetNormalTexture(tex);

    local hl_tex = btn:CreateTexture(nil, "HIGHLIGHT");
    hl_tex:SetTexture("Interface\\Buttons\\UI-OptionsButton");
    hl_tex:SetSize(16, 16);
    hl_tex:SetAllPoints();
    hl_tex:SetAlpha(0.5);
    btn:SetHighlightTexture(hl_tex);

    btn:SetPoint("TOPLEFT", 5, -4);

    btn:SetScript("OnClick", function(self, button)
        sw_activate_tab(__sc_frame.tabs[8])
    end);
    __sc_frame.tabs[i] = btn;
    __sc_frame.tabs[i].frame_to_open = __sc_frame.settings_frame;

end

local function load_sw_ui()

    local x = 5;
    for k, tab_name in ipairs({L["Spells"], L["Tooltip"], L["Overlay"], L["Calculator"], L["Profile"], L["Loadout"], L["Buffs"]}) do
        local v = __sc_frame.tabs[k];

        v:SetText(tab_name);
        PanelTemplates_TabResize(v, -10);

        local w = v:GetWidth();
        v:SetPoint("TOPLEFT", x, -20);
        x = x + w;

        v:SetScript("OnClick", function(self)
            sw_activate_tab(self);
        end);
        v:SetID(k);
    end
    PanelTemplates_SetNumTabs(__sc_frame, #__sc_frame.tabs);

    create_sw_spell_id_viewer();
    create_sw_item_id_viewer();

    if libstub_data_broker then
        local tooltip_show_fn = function(tooltip)
            tooltip:AddLine(sc.core.addon_name.." v"..sc.core.version);
            tooltip:AddLine("|cFF9CD6DE"..L["Left click"]..":|r "..L["Interact with addon"]);
            tooltip:AddLine("|cFF9CD6DE"..L["Middle click"]..":|r "..L["Hide this button"]);
            if config.settings.overlay_old_rank then
                tooltip:AddLine("|cFF9CD6DE"..L["Right click"]..":|r |cFF00FF00("..L["IS ON"]..")|r "..L["Toggle old rank warning overlay"]);
            else
                tooltip:AddLine("|cFF9CD6DE"..L["Right click"]..":|r |cFFFF0000("..L["IS OFF"]..")|r "..L["Toggle old rank warning overlay"]);
            end
            tooltip:AddLine(" ");
            tooltip:AddLine("|cFF9CD6DE"..L["Addon data generated from"]..":|r");
            tooltip:AddLine("    "..sc.client_name_src.." "..sc.client_version_src);
            tooltip:AddLine("|cFF9CD6DE"..L["Current client build"]..":|r "..sc.client_version_loaded);
            tooltip:AddLine("|cFF9CD6DE"..L["Factory reset (reloads UI)"]..":|r /sc reset");
            tooltip:AddLine("https://discord.gg/9ATBkzRQ74");
            tooltip:AddLine("https://www.curseforge.com/wow/addons/spellcoda");
        end;

        libstub_launcher = libstub_data_broker:NewDataObject(sc.core.addon_name, {
            type = "launcher",
            icon = "Interface\\Icons\\spell_fire_elementaldevastation",
            OnClick = function(self, button)
                if button == "MiddleButton" then
                    __sc_frame_setting_general_libstub_minimap_icon:Click();
                elseif button == "RightButton" then

                    __sc_frame_setting_overlay_old_rank:Click();
                    if __sc_frame_setting_overlay_disable:GetChecked() then
                        __sc_frame_setting_overlay_disable:Click();
                    end
                    libstub_icon.tooltip:ClearLines();
                    tooltip_show_fn(libstub_icon.tooltip);
                else
                    if __sc_frame:IsShown() then
                        __sc_frame:Hide();
                    else
                        sw_activate_tab(__sc_frame.tabs[1]);
                    end
                end
            end,
            OnTooltipShow = tooltip_show_fn
        });
        libstub_icon:Register(sc.core.addon_name, libstub_launcher, config.settings.libstub_icon_conf);
    end

    create_sw_ui_spells_frame(__sc_frame.spells_frame);
    create_sw_ui_tooltip_frame(__sc_frame.tooltip_frame);
    create_sw_ui_overlay_frame(__sc_frame.overlay_frame);
    create_sw_ui_loadout_frame(__sc_frame.loadout_frame);
    create_sw_ui_buffs_frame(__sc_frame.buffs_frame);
    create_sw_ui_calculator_frame(__sc_frame.calculator_frame);
    create_sw_ui_settings_frame(__sc_frame.settings_frame);
    create_sw_ui_profile_frame(__sc_frame.profile_frame);

    __sc_frame:Hide();

    fonts_setup();
end

local function add_spell_book_button()
    -- add button to SpellBookFrame
    if SpellBookFrame and SpellBookSkillLineTab1 then
        local button = CreateFrame("Button", "__sc_frame_spellbook_tab", SpellBookFrame);
        button.background = button:CreateTexture(nil, "BACKGROUND");
        button:ClearAllPoints();
        button:SetSize(32, 32);
        button:SetNormalTexture("Interface\\Icons\\spell_fire_elementaldevastation");
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");

        button.background:ClearAllPoints()
        button.background:SetPoint("TOPLEFT", -3, 11)
        button.background:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        button:SetScript("OnClick", function() 
            if __sc_frame:IsShown() then
                __sc_frame:Hide();
            else
                sw_activate_tab(__sc_frame.tabs[1]);
            end
        end);

        local n = GetNumSpellTabs();
        local y_padding = 17;
        local y_tab_offsets = SpellBookSkillLineTab1:GetHeight() + y_padding;
        -- Clique is right after last slot, put after where clique could be
        button:SetPoint("TOPLEFT", _G["SpellBookSkillLineTab1"], "BOTTOMLEFT", 0, -(y_tab_offsets*math.max(n, 4) + y_padding));
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT");
            GameTooltip:ClearLines();
            GameTooltip:SetText(L["SpellCoda ability catalogue"]);
        end);
        button:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        if config.settings.general_spellbook_button then
            button:Show();
        else
            button:Hide();
        end
    end
end

local function add_to_options()

    local frame = CreateFrame("Frame");
    frame.name = sc.core.addon_name;

    local header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
    header:SetPoint("TOPLEFT", 32, -16);
    header:SetText(sc.core.addon_name);

    -- Add a description (optional)
    local txt1 = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
    txt1:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -16);
    txt1:SetText("/sc")

    local txt2 = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
    txt2:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -32);
    txt2:SetText("/spellcoda");

    local btn = CreateFrame("Button", nil, frame);
    btn:SetSize(16, 16);

    local tex = btn:CreateTexture(nil, "ARTWORK");
    tex:SetTexture("Interface\\Buttons\\UI-OptionsButton");
    tex:SetSize(16, 16);
    tex:SetAllPoints();
    btn:SetNormalTexture(tex);

    local hl_tex = btn:CreateTexture(nil, "HIGHLIGHT");
    hl_tex:SetTexture("Interface\\Buttons\\UI-OptionsButton");
    hl_tex:SetSize(16, 16);
    hl_tex:SetAllPoints();
    hl_tex:SetAlpha(0.5);
    btn:SetHighlightTexture(hl_tex);

    btn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -60)

    btn:SetScript("OnClick", function(self, button)
        sw_activate_tab(__sc_frame.tabs[8]);
    end);

    local category = Settings.RegisterCanvasLayoutCategory(frame, sc.core.addon_name);
    Settings.RegisterAddOnCategory(category)
end

local function locale_warning_popup()
            local frame = CreateFrame("Frame", "__sc__localization_notified", UIParent, "DialogBoxFrame")
            frame:SetSize(470, 240);
            frame:SetPoint("CENTER", 0, 100);

            local icon = frame:CreateTexture(nil, "ARTWORK");
            icon:SetSize(24, 24);
            icon:SetPoint("TOPLEFT", 0, 0);
            icon:SetTexture("Interface\\Icons\\spell_fire_elementaldevastation");

            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
            text:SetPoint("TOPLEFT", 25, -30);
            text:SetPoint("RIGHT", -10, 0);
            text:SetJustifyH("LEFT");
            text:SetJustifyV("TOP");
            text:SetText("SpellCoda has localization support but is turned off by default.\n\nStrings have been translated using an AI LLM model and may be terribly wrong.\n\nIf you are interested in improving some string translations you can make a pull request on GitHub or upload a modified localization lua file on Discord.\n\nTurn on localization in settings:\n\n            |cFF00FF00/spellcoda config|r");

            __sc__localization_notifiedButton:SetSize(180, 24);
            __sc__localization_notifiedButton:SetPoint("BOTTOM", 0, 20);
            __sc__localization_notifiedButton:SetText("Okay! Don't show again");
            __sc__localization_notifiedButton:SetNormalFontObject("GameFontNormal");
            __sc__localization_notifiedButton:SetDisabledFontObject("GameFontDisable");
            __sc__localization_notifiedButton:SetHighlightFontObject("GameFontHighlight");
            __sc__localization_notifiedButton:SetScript("OnClick", function()
                __sc_p_acc.localization_notified = true;
                frame:Hide();
            end)
            frame:Show()
end

local function post_login_load()
    -- some things must be done after PLAYER_LOGIN event
    add_spell_book_button();
    add_to_options();
end

--------------------------------------------------------------------------------
ui.font                                 = font;
ui.load_sw_ui                           = load_sw_ui;
ui.create_sw_base_ui                    = create_sw_base_ui;
ui.effects_from_ui                      = effects_from_ui;
ui.display_spell_diff                   = display_spell_diff;
ui.update_calc_list                     = update_calc_list;
ui.sw_activate_tab                      = sw_activate_tab;
ui.update_buffs_frame                   = update_buffs_frame;
ui.update_profile_frame                 = update_profile_frame;
ui.update_loadout_frame                 = update_loadout_frame;
ui.update_spells_frame                  = update_spells_frame;
ui.post_login_load                      = post_login_load;
ui.forced_buffs_lname_to_id             = forced_buffs_lname_to_id;
ui.get_font                             = get_font;
ui.locale_warning_popup                 = locale_warning_popup;

sc.ui = ui;

