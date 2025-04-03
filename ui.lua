local _, sc = ...;

local spells                                    = sc.spells;
local spids                                     = sc.spids;
local spell_flags                               = sc.spell_flags;
local highest_learned_rank                      = sc.utils.highest_learned_rank;

local wowhead_talent_link                       = sc.talents.wowhead_talent_link;
local wowhead_talent_code_from_url              = sc.talents.wowhead_talent_code_from_url;

local fight_types                               = sc.calc.fight_types;
local evaluation_flags                          = sc.calc.evaluation_flags;

local effect_colors                             = sc.utils.effect_colors;
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

    --local change_fmt = format_number(diff.diff_ratio, 2);
    --local change = change_fmt.."%";
    --if not diff.diff_ratio then
    --    change = "";
    --elseif diff.diff_ratio < 0 then
    --    v.change:SetTextColor(195/255, 44/255, 11/255);
    --    change = change;
    --elseif diff.diff_ratio > 0 then
    --    v.change:SetTextColor(33/255, 185/255, 21/255);
    --    change = "+"..change;
    --else
    --    v.change:SetTextColor(1, 1, 1);
    --end
    --v.change:SetText(change);

    --local first = format_number(diff.first, 2);
    --if diff.first < 0 then
    --    v.first:SetTextColor(195/255, 44/255, 11/255);
    --elseif diff.first > 0 then
    --    v.first:SetTextColor(33/255, 185/255, 21/255);
    --    first = "+"..first;
    --else
    --    v.first:SetTextColor(1, 1, 1);
    --end
    --v.first:SetText(first);

    --local second = format_number(diff.second, 2);
    --if diff.second < 0 then
    --    v.second:SetTextColor(195/255, 44/255, 11/255);
    --elseif diff.second > 0 then
    --    v.second:SetTextColor(33/255, 185/255, 21/255);
    --    second = "+"..second;
    --else
    --    v.second:SetTextColor(1, 1, 1);
    --end
    --v.second:SetText(second);
    ------------------
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
        "Active loadout: "..config.loadout.name
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

local spell_filter_listing = {
    {
        id = "spells_filter_already_known",
        disp = "Already known",
    },
    {
        id = "spells_filter_available",
        disp = "Available",
    },
    {
        id = "spells_filter_unavailable",
        disp = "Unavailable",
    },
    {
        id = "spells_filter_learned_from_item",
        disp = "Learned from item",
    },
    {
        id = "spells_filter_pet",
        disp = "Pet spells",
    },
    {
        id = "spells_filter_ignored_spells",
        disp = "Ignored spells",
    },
    {
        id = "spells_filter_other_spells",
        disp = "Other spells",
        tooltip = "Uncategorized spells. Contains seasonal spells and junk."
    },
    {
        id = "spells_filter_only_highest_learned_ranks",
        disp = "Only highest, learned spell ranks",
    },
};
local spell_filters = {};
for k, v in pairs(spell_filter_listing) do
    spell_filters[v.id] = k;
end

local spell_browser_sort_options = {
    "Level",
    "|cFFFF8000".."Damage per second",
    "|cFFFF8000".."Healing per second",
    "|cFF00FFFF".."Damage per cost",
    "|cFF00FFFF".."Healing per cost",
};
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
        cost_str = cost_str.."   |cFF00FF00Available cost:|r "..GetCoinTextureString(avail_cost);
    end
    if next_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF8C00Next level "..next_lvl.." cost:|r "..GetCoinTextureString(next_cost);
    end
    if total_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF0000Total cost:|r "..GetCoinTextureString(total_cost);
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
                line.spell_name:SetText(string.format("%s (Rank %d)",
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
                    line.cost_str:SetText("Unknown");
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
            line.spell_name:SetText("<<< ".."Level".." "..color_by_lvl_diff(lvl, v.lvl_barrier)..v.lvl_barrier.."|cFFFFFFFF >>>");
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
    __sc_frame.spell_id_viewer_editbox_label:SetText("Spell ID viewer");
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

local function multi_row_checkbutton(buttons_info, parent_frame, num_columns, func, x_pad)
    x_pad = x_pad or 10;
    local column_offset = 230;
    --  assume max 2 columns
    local check_button_type = "CheckButton";
    for i, v in pairs(buttons_info) do
        local f = CreateFrame(check_button_type, "__sc_frame_setting_"..v.id, parent_frame, "ChatConfigCheckButtonTemplate");
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
end

local function create_sw_ui_spells_frame()

    local f, f_txt;
    __sc_frame.spells_frame.y_offset = __sc_frame.spells_frame.y_offset - 8;

    f = CreateFrame("EditBox", "__sc_frame_spells_search", __sc_frame.spells_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 5, __sc_frame.spells_frame.y_offset);
    f:SetSize(100, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        update_spells_frame(nil, nil, nil, true);
        local txt =self:GetText();
        if txt == "" then
            __sc_frame.spells_frame.search_empty_label:Show();
        else
            __sc_frame.spells_frame.search_empty_label:Hide();
        end
    end);
    __sc_frame.spells_frame.search = f;

    f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Search");
    f:SetPoint("LEFT", __sc_frame.spells_frame.search, 5, 0);
    __sc_frame.spells_frame.search_empty_label = f;

    -- Sorted by dropdown
    __sc_frame.spells_frame.sort_by =
        --CreateFrame("Button", "__sc_frame_spells_frame_sort_by", __sc_frame.spells_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_spells_frame_sort_by", __sc_frame.spells_frame);
    __sc_frame.spells_frame.sort_by:SetPoint("TOPLEFT", 150, __sc_frame.spells_frame.y_offset+6);
    __sc_frame.spells_frame.sort_by.init_func = function()

        libDD:UIDropDownMenu_SetText(__sc_frame.spells_frame.sort_by, "Order by "..spell_browser_sort_options[spell_browser_active_sort_key]);
        libDD:UIDropDownMenu_Initialize(__sc_frame.spells_frame.sort_by, function()

            libDD:UIDropDownMenu_SetWidth(__sc_frame.spells_frame.sort_by, 160);

            for k, v in pairs(spell_browser_sort_options) do
                libDD:UIDropDownMenu_AddButton({
                        text = v;
                        checked = k == spell_browser_active_sort_key;
                        func = function()
                            libDD:UIDropDownMenu_SetText(__sc_frame.spells_frame.sort_by, "Order by "..spell_browser_sort_options[k]);
                            spell_browser_active_sort_key = k;
                            update_spells_frame(nil, nil, nil, true);
                            __sc_frame.spells_frame.slider:SetValue(1);
                        end
                    }
                );
            end
        end);
    end;
    __sc_frame.spells_frame.sort_by.init_func();

    -- Filter dropdown
    __sc_frame.spells_frame.filter =
        --CreateFrame("Button", "__sc_frame_spells_frame_filter", __sc_frame.spells_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_spells_frame_filter", __sc_frame.spells_frame);
    __sc_frame.spells_frame.filter:SetPoint("TOPLEFT", 340, __sc_frame.spells_frame.y_offset+6);
    __sc_frame.spells_frame.filter.init_func = function()

        libDD:UIDropDownMenu_SetText(__sc_frame.spells_frame.filter, "Includes");
        libDD:UIDropDownMenu_Initialize(__sc_frame.spells_frame.filter, function()

            libDD:UIDropDownMenu_SetWidth(__sc_frame.spells_frame.filter, 80);

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
    __sc_frame.spells_frame.filter.init_func();

    __sc_frame.spells_frame.y_offset = __sc_frame.spells_frame.y_offset - 25;
    -- Headers
    local icon_x_offset = 0;
    local name_x_offset = 20;
    local lvl_x_offset = 200;
    local effect_x_offset = 230;
    local per_sec_x_offset = 260;
    local per_cost_x_offset = 325;
    local acquisition_x_offset = 380;
    local dropdown_x_offset = 440;

    local f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Spell name");
    f:SetPoint("TOPLEFT", name_x_offset, __sc_frame.spells_frame.y_offset);

    local f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Level");
    f:SetPoint("TOPLEFT", lvl_x_offset, __sc_frame.spells_frame.y_offset);
    __sc_frame.spells_frame.header_level = f;

    local f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Per second");
    f:SetPoint("TOPLEFT", per_sec_x_offset, __sc_frame.spells_frame.y_offset);
    f:SetTextColor(effect_colors.effect_per_sec[1],
                   effect_colors.effect_per_sec[2],
                   effect_colors.effect_per_sec[3]);

    local f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Per cost");
    f:SetPoint("TOPLEFT", per_cost_x_offset, __sc_frame.spells_frame.y_offset);
    f:SetTextColor(effect_colors.effect_per_cost[1],
                   effect_colors.effect_per_cost[2],
                   effect_colors.effect_per_cost[3]);

    local f = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Acquisition");
    f:SetPoint("TOPLEFT", acquisition_x_offset, __sc_frame.spells_frame.y_offset);

    __sc_frame.spells_frame.y_offset = __sc_frame.spells_frame.y_offset - 23;
    local num_view_list_entries = 29;
    local entry_y_offset = 16;

    -- sliders
    f = CreateFrame("Slider", nil, __sc_frame.spells_frame, "UIPanelScrollBarTrimTemplate");
    f:SetOrientation('VERTICAL');
    f:SetPoint("RIGHT", __sc_frame.spells_frame, "RIGHT", 10, -15);
    f:SetHeight(__sc_frame.spells_frame:GetHeight()-63);
    f:SetScript("OnValueChanged", function(self, val)
        __sc_frame.spells_frame.slider_val = val;
        populate_scrollable_spell_view(__sc_frame.spells_frame.filtered_list, math.floor(val));
    end);
    __sc_frame.spells_frame.slider = f;
    __sc_frame.spells_frame.slider_val = 1;
    f:SetValue(__sc_frame.spells_frame.slider_val);
    f:SetValueStep(1);

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f);
    bg:SetColorTexture(0, 0, 0, 0.5);

    __sc_frame.spells_frame:EnableMouseWheel(true)
    __sc_frame.spells_frame:SetScript("OnMouseWheel", function(_, delta)
        local scrollbar = __sc_frame.spells_frame.slider;
        scrollbar:SetValue(scrollbar:GetValue() - delta*5);
    end);

    -- Spell list
    __sc_frame.spells_frame.filtered_list = {};
    __sc_frame.spells_frame.scroll_view = {};
    for i = 1, num_view_list_entries do

        local tooltip_area_f = CreateFrame("Frame", nil, __sc_frame.spells_frame);
        tooltip_area_f:SetSize(220, 16);
        tooltip_area_f:SetPoint("TOPLEFT", 0, __sc_frame.spells_frame.y_offset+4);
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


        local icon = CreateFrame("Frame", nil, __sc_frame.spells_frame);
        icon:SetSize(15, 15);
        icon:SetPoint("TOPLEFT", icon_x_offset, __sc_frame.spells_frame.y_offset+2);
        local icon_texture = icon:CreateTexture(nil);
        icon_texture:SetAllPoints(icon);

        local book = CreateFrame("Frame", nil, __sc_frame.spells_frame);
        book:SetSize(15, 15);
        book:SetPoint("TOPLEFT", acquisition_x_offset, __sc_frame.spells_frame.y_offset+2);
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

        local spell_str = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        spell_str:SetFontObject(font);
        spell_str:SetText("");
        spell_str:SetPoint("TOPLEFT", name_x_offset, __sc_frame.spells_frame.y_offset);

        local level_str = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        level_str:SetFontObject(font);
        level_str:SetText("");
        level_str:SetPoint("TOPLEFT", lvl_x_offset, __sc_frame.spells_frame.y_offset);

        local effect_type_str = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        effect_type_str:SetFontObject(font);
        effect_type_str:SetText("");
        effect_type_str:SetPoint("TOPLEFT", effect_x_offset, __sc_frame.spells_frame.y_offset);

        local role_icon = CreateFrame("Frame", nil, __sc_frame.spells_frame);
        role_icon:SetSize(15, 15);
        role_icon:SetPoint("TOPLEFT", effect_x_offset, __sc_frame.spells_frame.y_offset+2);
        local role_icon_texture = role_icon:CreateTexture(nil, "ARTWORK");
        role_icon_texture:SetTexture(role_icons);


        local effect_per_sec_str = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        effect_per_sec_str:SetFontObject(font);
        effect_per_sec_str:SetText("");
        effect_per_sec_str:SetPoint("TOPLEFT", per_sec_x_offset, __sc_frame.spells_frame.y_offset);
        effect_per_sec_str:SetTextColor(effect_colors.effect_per_sec[1],
                                        effect_colors.effect_per_sec[2],
                                        effect_colors.effect_per_sec[3]);

        local effect_per_cost_str = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        effect_per_cost_str:SetFontObject(font);
        effect_per_cost_str:SetText("");
        effect_per_cost_str:SetPoint("TOPLEFT", per_cost_x_offset, __sc_frame.spells_frame.y_offset);
        effect_per_cost_str:SetTextColor(effect_colors.effect_per_cost[1],
                                         effect_colors.effect_per_cost[2],
                                         effect_colors.effect_per_cost[3]);

        local cost = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
        cost:SetFontObject(font);
        cost:SetText("");
        cost:SetPoint("TOPLEFT", acquisition_x_offset, __sc_frame.spells_frame.y_offset+1);

        -- spell option dropdown
        local spell_options =
            --CreateFrame("Button", "__sc_frame_spells_frame_dropdown"..i, __sc_frame.spells_frame, "UIDropDownMenuTemplate");
            libDD:Create_UIDropDownMenu("__sc_frame_spells_frame_dropdown"..i, __sc_frame.spells_frame);
        spell_options:SetPoint("TOPLEFT", dropdown_x_offset, __sc_frame.spells_frame.y_offset+15);
        spell_options.init_func = function()

            libDD:UIDropDownMenu_Initialize(spell_options, function()

                libDD:UIDropDownMenu_SetWidth(spell_options, 15);

                libDD:UIDropDownMenu_AddButton({
                        text = "Add/remove to spell ignore list",
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
                libDD:UIDropDownMenu_AddButton({
                        text = "Add to calculator list",
                        func = function()

                            local id = spell_options.__spid;
                            if spells[id] and bit.band(spells[id].flags, spell_flags.eval) ~= 0 then

                                config.settings.spell_calc_list[spell_options.__spid] = 1;
                                update_calc_list();
                            end

                        end,
                    }
                );
            end);
        end;
        spell_options.init_func();
        spell_options.Button:SetSize(20, 20);
        spell_options.Button:Hide();
        spell_options.Text:Hide();

        local f = CreateFrame("Button", nil, __sc_frame.spells_frame, "UIPanelButtonTemplate");
        f:SetText(":");
        f:SetSize(15, 15);
        f:SetPoint("TOPLEFT", dropdown_x_offset, __sc_frame.spells_frame.y_offset+3);
        f:SetScript("OnClick", function()
            libDD:ToggleDropDownMenu(1, nil, spell_options, spell_options, 0, 0)
        end);

        local ignore_line_f = __sc_frame.spells_frame:CreateTexture(nil, "OVERLAY")
        ignore_line_f:SetColorTexture(1.0, 0.0, 0.0, 1.0);
        ignore_line_f:SetDrawLayer("OVERLAY");
        ignore_line_f:SetHeight(0.5);
        ignore_line_f:SetPoint("TOPLEFT", -10, __sc_frame.spells_frame.y_offset-5);
        ignore_line_f:SetPoint("TOPRIGHT", -30, __sc_frame.spells_frame.y_offset-5);


        __sc_frame.spells_frame.scroll_view[i] = {
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
        __sc_frame.spells_frame.y_offset = __sc_frame.spells_frame.y_offset - entry_y_offset;
    end
    local footer_cost = __sc_frame.spells_frame:CreateFontString(nil, "OVERLAY");
    footer_cost:SetFontObject(font);
    footer_cost:SetPoint("BOTTOMRIGHT", __sc_frame.spells_frame, "BOTTOMRIGHT", -15, 5);

    __sc_frame.spells_frame.footer_cost = footer_cost;

    local header_divider = __sc_frame.spells_frame:CreateTexture(nil, "ARTWORK")
    header_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    header_divider:SetHeight(1);
    header_divider:SetPoint("TOPLEFT", __sc_frame.spells_frame, "TOPLEFT", 0, -48);
    header_divider:SetPoint("TOPRIGHT", __sc_frame.spells_frame, "TOPRIGHT", 0, -48);

    local footer_divider = __sc_frame.spells_frame:CreateTexture(nil, "ARTWORK")
    footer_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    footer_divider:SetHeight(1)
    footer_divider:SetPoint("BOTTOMLEFT", __sc_frame.spells_frame, "BOTTOMLEFT", 0, 20)
    footer_divider:SetPoint("BOTTOMRIGHT", __sc_frame.spells_frame, "BOTTOMRIGHT", 0, 20)
end

local function create_sw_ui_tooltip_frame()

    local f, f_txt;
    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 5;

    __sc_frame.tooltip_frame.num_tooltip_toggled = 0;

    __sc_frame.tooltip_frame.checkboxes = {};

    local tooltip_general_checks = {
        {
            id = "tooltip_shift_to_show",
            txt = "Require SHIFT to show tooltip"
        },
    };

    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Tooltip general settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 15;
    multi_row_checkbutton(tooltip_general_checks, __sc_frame.tooltip_frame, 2);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 25;

    local div = __sc_frame.tooltip_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.tooltip_frame, "TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.tooltip_frame, "TOPRIGHT", 0, __sc_frame.tooltip_frame.y_offset);

    local tooltip_spell_checks = {
        {
            id = "tooltip_disable",
            txt = "Disable spell tooltip",
        },
        --{
        --    id = "tooltip_clear_original",
        --    txt = "Clear original tooltip",
        --},
        {
            id = "tooltip_double_line",
            txt = "Field values on right-hand side",
        },
        {
            id = "tooltip_hide_cd_coom",
            txt = "Disable casts until OOM for CDs",
            tooltip = "Hides casts until OOM for spells with cooldowns."
        }
    };

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 5;

    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Tooltip spell settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 15;
    multi_row_checkbutton(tooltip_spell_checks, __sc_frame.tooltip_frame, 2);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 25;

    local div = __sc_frame.tooltip_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.tooltip_frame, "TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.tooltip_frame, "TOPRIGHT", 0, __sc_frame.tooltip_frame.y_offset);
    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 5;

    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Tooltip spell display options:");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 20;
    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Presets:");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    local tooltip_components = {
        {
            id = "tooltip_display_addon_name",
            txt = "Addon & loadout name"
        },
        {
            id = "tooltip_display_eval_options",
            txt = "Evaluation modes",
            tooltip = "Some spells may have different evaluation modes. This shows the mode and how to dynamically switch between. Example: Switch between healing and damage component of Holy shock.";
        },
        {
            id = "tooltip_display_target_info",
            txt = "Target info",
            color = effect_colors.target_info,
            tooltip = "Target level, armor and resistance assumed in calculation."
        },
        {
            id = "tooltip_display_avoidance_info",
            txt = "Miss, avoidance & mitigation",
            color = effect_colors.avoidance_info,
            tooltip = "Avoidance based on weapon skill & target level. Mitigation based on target armor or resistance."
        },
        {
            id = "tooltip_display_normal",
            txt = "Normal effect",
            color = effect_colors.normal
        },
        {
            id = "tooltip_display_crit",
            txt = "Critical effect",
            color = effect_colors.crit
        },
        {
            id = "tooltip_display_expected",
            txt = "Expected effect",
            color = effect_colors.expectation,
            tooltip = "This average considers all kinds of outcomes like critical, miss, resist, dodge, parry, glance etc.",
        },
        {
            id = "tooltip_display_effect_per_sec",
            txt = "Effect per second",
            color = effect_colors.effect_per_sec
        },
        {
            id = "tooltip_display_threat",
            txt = "Expected threat",
            color = effect_colors.threat,
        },
        {
            id = "tooltip_display_threat_per_sec",
            txt = "Threat per second",
            color = effect_colors.threat
        },
        {
            id = "tooltip_display_threat_per_cost",
            txt = "Threat per cost",
            color = effect_colors.effect_per_cost
        },
        {
            id = "tooltip_display_effect_per_cost",
            txt = "Effect per cost",
            color = effect_colors.effect_per_cost
        },
        {
            id = "tooltip_display_cost_per_sec",
            txt = "Cost per second" ,
            color = effect_colors.cost_per_sec
        },
        {
            id = "tooltip_display_avg_cost",
            txt = "Expected cost",
            color = effect_colors.avg_cost,
            tooltip = "Shown when different from tooltip's cost.",
        },
        {
            id = "tooltip_display_avg_cast",
            txt = "Expected execution time",
            color = effect_colors.avg_cast,
            tooltip = "Shown when different from tooltip's cast time.",
        },
        {
            id = "tooltip_display_cast_until_oom",
            txt = "Casting until OOM",
            color = effect_colors.normal,
            tooltip = "Assumes you cast a particular ability until you are OOM with no cooldowns."
        },
        {
            id = "tooltip_display_base_mod",
            txt = "Base effect mod",
            color = effect_colors.sp_effect,
            tooltip = "Intended for debugging."
        },
        {
            id = "tooltip_display_sp_effect_calc",
            txt = "Coef & SP/AP effect",
            color = effect_colors.sp_effect,
        },
        {
            id = "tooltip_display_sp_effect_ratio",
            txt = "SP/AP to base effect ratio",
            color = effect_colors.sp_effect,
        },
        {
            id = "tooltip_display_spell_rank",
            txt = "Spell rank info",
            color = effect_colors.spell_rank,
        },
        {
            id = "tooltip_display_spell_id",
            txt = "Spell id",
            color = effect_colors.spell_rank,
        },
        {
            id = "tooltip_display_stat_weights_effect",
            txt = "Stat weights: Effect",
            color = effect_colors.stat_weights
        },
        {
            id = "tooltip_display_stat_weights_effect_per_sec",
            txt = "Stat weights: Effect per sec",
            color = effect_colors.stat_weights
        },
        {
            id = "tooltip_display_stat_weights_effect_until_oom",
            txt = "Stat weights: Effect until OOM",
            color = effect_colors.stat_weights
        },
        {
            id = "tooltip_display_resource_regen",
            txt = "Resource restoration",
            tooltip = "Shows resource gained from spells like Evocation, Mana tide totem, etc.",
            color = effect_colors.avg_cost
        },
        --tooltip_display_cast_and_tap       
    };

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 10;
    __sc_frame.tooltip_frame.preset_minimalistic_button =
        CreateFrame("Button", nil, __sc_frame.tooltip_frame, "UIPanelButtonTemplate");
    __sc_frame.tooltip_frame.preset_minimalistic_button:SetScript("OnClick", function(self)

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

    __sc_frame.tooltip_frame.preset_minimalistic_button:SetPoint("TOPLEFT", 80, __sc_frame.tooltip_frame.y_offset+16);
    __sc_frame.tooltip_frame.preset_minimalistic_button:SetText("Minimalistic");
    __sc_frame.tooltip_frame.preset_minimalistic_button:SetWidth(120);

    __sc_frame.tooltip_frame.preset_default_button =
        CreateFrame("Button", nil, __sc_frame.tooltip_frame, "UIPanelButtonTemplate");
    __sc_frame.tooltip_frame.preset_default_button:SetScript("OnClick", function(self)

        for _, v in pairs(tooltip_components) do
            local f = getglobal("__sc_frame_setting_"..v.id);
            if config.default_settings[v.id] ~= f:GetChecked() then
                f:Click();
            end
        end
    end);
    __sc_frame.tooltip_frame.preset_default_button:SetPoint("TOPLEFT", 200, __sc_frame.tooltip_frame.y_offset+16);
    __sc_frame.tooltip_frame.preset_default_button:SetText("Default");
    __sc_frame.tooltip_frame.preset_default_button:SetWidth(120);

    __sc_frame.tooltip_frame.preset_detailed_button =
        CreateFrame("Button", nil, __sc_frame.tooltip_frame, "UIPanelButtonTemplate");
    __sc_frame.tooltip_frame.preset_detailed_button:SetScript("OnClick", function(self)

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
    __sc_frame.tooltip_frame.preset_detailed_button:SetPoint("TOPLEFT", 320, __sc_frame.tooltip_frame.y_offset+16);
    __sc_frame.tooltip_frame.preset_detailed_button:SetText("Detailed");
    __sc_frame.tooltip_frame.preset_detailed_button:SetWidth(120);
    local tooltip_toggle = function(self)

        local checked = self:GetChecked();
        if checked then

            if __sc_frame.tooltip_frame.num_tooltip_toggled == 0 then
                if __sc_frame_setting_tooltip_disable:GetChecked() then
                    __sc_frame_setting_tooltip_disable:Click();
                end
            end
            __sc_frame.tooltip_frame.num_tooltip_toggled = __sc_frame.tooltip_frame.num_tooltip_toggled + 1;
        else
            __sc_frame.tooltip_frame.num_tooltip_toggled = __sc_frame.tooltip_frame.num_tooltip_toggled - 1;
            if __sc_frame.tooltip_frame.num_tooltip_toggled == 0 then
                if not __sc_frame_setting_tooltip_disable:GetChecked() then
                    __sc_frame_setting_tooltip_disable:Click();
                end
            end
        end
        config.settings[self._settings_id] = self:GetChecked();
    end;


    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 10;
    multi_row_checkbutton(tooltip_components, __sc_frame.tooltip_frame, 2, tooltip_toggle);
    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 25;

    local div = __sc_frame.tooltip_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.tooltip_frame, "TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.tooltip_frame, "TOPRIGHT", 0, __sc_frame.tooltip_frame.y_offset);
    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 5;


    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Tooltip item comparison settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);


    local tooltip_item_checks = {
        {
            id = "tooltip_disable_item",
            txt = "Disable item upgrade evaluation in tooltip"
        },
        {
            id = "tooltip_item_leveling_skill_normalize",
            txt = "Use all weapon skills as clvl*5 when not maximum level",
            tooltip = "More intuitive weapon upgrade results when leveling since lower weapon skill type is not punished",
        },
    };

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 15;
    multi_row_checkbutton(tooltip_item_checks, __sc_frame.tooltip_frame, 1);
    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 5;

    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Spell list in item tooltip is configured under Calculator tab");
    f_txt:SetTextColor(1, 1, 1);

    __sc_frame.tooltip_frame.y_offset = __sc_frame.tooltip_frame.y_offset - 20;
    f_txt = __sc_frame.tooltip_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.tooltip_frame.y_offset);
    f_txt:SetText("Switch between evaluation modes holding ALT key");
    f_txt:SetTextColor(1, 1, 1);
    f_txt:SetWordWrap(true);
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
for _, font_path in ipairs(fonts) do
    font_dropdowns[#font_dropdowns + 1] = {font_path, "OUTLINE"};
    font_dropdowns[#font_dropdowns + 1] = {font_path, "THICKOUTLINE"};
end

local function create_font_dropdown(parent_frame, dropdown_name, font_config_key, callback_fn)
    local dropdown_frame = libDD:Create_UIDropDownMenu(dropdown_name, parent_frame);

    dropdown_frame._type = "DropDownMenu";

    dropdown_frame.init_func = function()
        libDD:UIDropDownMenu_Initialize(dropdown_frame, function()

            for k, v in pairs(font_dropdowns) do
                local txt = (v[1]:match("([^\\]+)$") or v[1]).."   0123456789  " .. v[2];
                local font_object = CreateFont("__sc_font_dropdown_font_"..k);
                font_object:SetFont(v[1], 12, v[2]);

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
                    end;
                };

                if config.settings[font_config_key][1] == v[1] and config.settings[font_config_key][2] == v[2] then
                    libDD:UIDropDownMenu_SetText(dropdown_frame, txt);
                    btn.checked = true;
                    callback_fn();
                end

                libDD:UIDropDownMenu_AddButton(btn);
            end
        end);

        -- Configure dropdown appearance
        libDD:UIDropDownMenu_SetWidth(dropdown_frame, 200);
        libDD:UIDropDownMenu_SetButtonWidth(dropdown_frame, 224);
        libDD:UIDropDownMenu_JustifyText(dropdown_frame, "LEFT");

    end;

    return dropdown_frame;
end;


local function create_sw_ui_overlay_frame()

    local f, f_txt;

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 5;

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.overlay_frame.y_offset);
    f_txt:SetText("Spell overlay settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 15;

    local overlay_settings_checks = {
        {
            id = "overlay_disable",
            txt = "Disable action bar overlay",
            func = function(self)
                sc.overlay.clear_overlays();
                sc.core.old_ranks_checks_needed = true;
            end
        },
        {
            id = "overlay_resource_regen",
            txt = "Resource restoration spells ",
            color = effect_colors.avg_cost,
            tooltip = "Puts mana restoration amount on overlay for spells like Evocation.",
            func = function()
                sc.core.update_action_bar_needed = true;
            end,
        },
        {
            id = "overlay_old_rank",
            txt = "Old rank warning",
            color = effect_colors.crit,
            func = function()
                sc.core.old_ranks_checks_needed = true;
            end
        },
        {
            id = "overlay_old_rank_limit_to_known",
            txt = "Restrict rank warning to learned",
            color = effect_colors.crit,
            func = function()
                sc.core.old_ranks_checks_needed = true;
            end,
            tooltip = "Does not warn about old rank when the higher rank is not learned/known by player. Requires old rank warning option to be toggled.",
        },
        {
            id = "overlay_icon_top_clearance",
            txt = "Icon top clearance",
            func = function()
                sc.core.update_action_bar_needed = true;
            end,
        },
        {
            id = "overlay_icon_bottom_clearance",
            txt = "Icon bottom clearance",
            func = function()
                sc.core.update_action_bar_needed = true;
            end,
        },
    };

    multi_row_checkbutton(overlay_settings_checks, __sc_frame.overlay_frame, 2);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 20;

    local slider_frame_type = "Slider";
    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_update_freq", __sc_frame.overlay_frame, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 250, __sc_frame.overlay_frame.y_offset+4);
    f:SetMinMaxValues(1, 30)
    f:SetValueStep(1)
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_update_freq = val;
        self.val_txt:SetText(string.format("%.1f Hz", val));
    end);

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset)
    f_txt:SetText("Update frequency (responsiveness)");

    f.val_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 430, __sc_frame.overlay_frame.y_offset)
    f.val_txt:SetText(string.format("%.1f Hz", 3));

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 25;

    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_font_size", __sc_frame.overlay_frame, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 250, __sc_frame.overlay_frame.y_offset+4);
    f:SetMinMaxValues(2, 24)
    f:SetValueStep(1)
    f:SetWidth(175)
    f:SetHeight(20)

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset)
    f_txt:SetText("Font size")

    f.val_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 430, __sc_frame.overlay_frame.y_offset)
    f.val_txt:SetText(string.format("%.2fx", 0.0));
    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_font_size = val;

        self.val_txt:SetText(string.format("%.2fx", config.settings.overlay_font_size));


        sc.overlay.overlay_reconfig();
    end);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 25;
    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_offset", __sc_frame.overlay_frame, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 250, __sc_frame.overlay_frame.y_offset+4);
    f:SetMinMaxValues(-15, 15);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.1);

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset)
    f_txt:SetText("Horizontal offset")


    f.val_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 430, __sc_frame.overlay_frame.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));

    f:SetValue(config.settings.overlay_offset);
    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_offset = val;
        self.val_txt:SetText(string.format("%.1f", val))
        sc.overlay.overlay_reconfig();
    end);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 30;


    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset);
    f_txt:SetText("Font");

    local overlay_font_dropdown_f = create_font_dropdown(
        __sc_frame.overlay_frame,
        "__sc_frame_setting_overlay_font",
        "overlay_font",
        sc.overlay.overlay_reconfig
    );
    overlay_font_dropdown_f:SetPoint("TOPLEFT", 232, __sc_frame.overlay_frame.y_offset+6);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 25;

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.overlay_frame.y_offset);
    f_txt:SetText("Spell overlay components (max 3)");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 15;

    __sc_frame.overlay_frame.num_overlay_components_toggled = 0;
    __sc_frame.overlay_frame.num_overlay_special_toggled = 0;

    local overlay_components = {
        {
            id = "overlay_display_normal",
            txt = "Normal effect",
            color = effect_colors.normal,
        },
        {
            id = "overlay_display_crit",
            txt = "Critical effect",
            color = effect_colors.crit,
        },
        {
            id = "overlay_display_hit_chance",
            txt = "Hit chance",
            color = effect_colors.hit_chance,
            tooltip = "Probability of not missing, parrying or dodging."
        },
        {
            id = "overlay_display_crit_chance",
            txt = "Critical chance",
            color = effect_colors.crit
        },
        {
            id = "overlay_display_expected",
            txt = "Expected effect",
            color = effect_colors.expectation,
            tooltip = "Expected effect is the DMG or Heal dealt on average for a single cast considering miss chance, crit chance, spell power etc. This equates to your DPS or HPS number multiplied by the ability's execution time"
        },
        {
            id = "overlay_display_effect_per_sec",
            txt = "Effect per sec",
            color = effect_colors.effect_per_sec,
        },
        {
            id = "overlay_display_threat",
            txt = "Expected threat",
            color = effect_colors.threat,
        },
        {
            id = "overlay_display_threat_per_sec",
            txt = "Threat per sec",
            color = effect_colors.threat,
        },
        {
            id = "overlay_display_threat_per_cost",
            txt = "Threat per cost",
            color = effect_colors.effect_per_cost
        },
        {
            id = "overlay_display_effect_per_cost",
            txt = "Effect per cost",
            color = effect_colors.effect_per_cost
        },
        {
            id = "overlay_display_avg_cost",
            txt = "Expected cost",
            color = effect_colors.avg_cost,
            optional_evaluation = true,
        },
        --{
        --    id = "overlay_display_actual_cost",
        --    txt = "Actual cost",
        --    color = effect_colors.avg_cost,
        --    optional_evaluation = true,
        --},
        {
            id = "overlay_display_avg_cast",
            txt = "Expected execution time",
            color = effect_colors.avg_cast,
            optional_evaluation = true,
        },
        --{
        --    id = "overlay_display_actual_cast",
        --    txt = "Actual execution time",
        --    color = effect_colors.avg_cast,
        --    optional_evaluation = true,
        --},
        {
            id = "overlay_display_effect_until_oom",
            txt = "Effect until OOM" ,
            color = effect_colors.effect_until_oom,
            optional_evaluation = true,
        },
        {
            id = "overlay_display_casts_until_oom",
            txt = "Casts until OOM",
            color = effect_colors.casts_until_oom,
            optional_evaluation = true,
        },
        {
            id = "overlay_display_time_until_oom",
            txt = "Time until OOM",
            color = effect_colors.time_until_oom,
            optional_evaluation = true,
        },
    };

    local icon_checkbox_func = function(self)

        local checked = self:GetChecked();
        if checked then

            __sc_frame.overlay_frame.num_overlay_components_toggled = __sc_frame.overlay_frame.num_overlay_components_toggled + 1;
        else
            __sc_frame.overlay_frame.num_overlay_components_toggled = __sc_frame.overlay_frame.num_overlay_components_toggled - 1;
        end

        if __sc_frame.overlay_frame.num_overlay_components_toggled > 3 then
            checked = false;
            self:SetChecked(false);
            __sc_frame.overlay_frame.num_overlay_components_toggled = 3;
        end
        config.settings[self._settings_id] = checked;

        sc.core.update_action_bar_needed = true;
    end;

    multi_row_checkbutton(overlay_components, __sc_frame.overlay_frame, 2, icon_checkbox_func);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 15;

    __sc_frame.overlay_frame.overlay_components = {};
    for k, v in pairs(overlay_components) do
        __sc_frame.overlay_frame.overlay_components[v.id] = {
            color = v.color,
            optional_evaluation = v.optional_evaluation,
        }
    end

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 15;
    local div = __sc_frame.overlay_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.overlay_frame, "TOPLEFT", 0, __sc_frame.overlay_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.overlay_frame, "TOPRIGHT", 0, __sc_frame.overlay_frame.y_offset);
    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 5;

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.overlay_frame.y_offset);
    f_txt:SetText("Spell cast info frame");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 15;

    multi_row_checkbutton(
        {
            {
                id = "overlay_disable_currently_casting_info",
                txt = "Disable spell cast info frame",
                func = function(self)
                    if self:GetChecked() then
                        sc.overlay.currently_casting_frame_parent.border.disabled_txt:Show();
                    else
                        sc.overlay.currently_casting_frame_parent.border.disabled_txt:Hide();
                    end
                end
            },
            {
                id = "overlay_currently_casting_only_eval",
                txt = "Only show for evaluable spells",
            },
            {
                id = "overlay_currently_casting_horizontal",
                txt = "Horizontal animation",
            },
        },
        __sc_frame.overlay_frame, 2);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 25;
    f = CreateFrame(slider_frame_type, "__sc_frame_setting_overlay_currently_casting_info_scale", __sc_frame.overlay_frame, "UISliderTemplate");
    f._type = slider_frame_type;
    f:SetOrientation('HORIZONTAL');
    f:SetPoint("TOPLEFT", 250, __sc_frame.overlay_frame.y_offset+4);
    f:SetMinMaxValues(0.1, 3.0);
    f:SetWidth(175)
    f:SetHeight(20)
    f:SetValueStep(0.05);

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset)
    f_txt:SetText("Scale")

    f.val_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f.val_txt:SetFontObject(font)
    f.val_txt:SetPoint("TOPLEFT", 430, __sc_frame.overlay_frame.y_offset)
    f.val_txt:SetText(string.format("%.1f", 0));

    f:SetScript("OnValueChanged", function(self, val)
        config.settings.overlay_currently_casting_info_scale = val;
        self.val_txt:SetText(string.format("%.2f", val))
        sc.overlay.currently_casting_f1.icon_frame:SetScale(val);
        sc.overlay.currently_casting_f2.icon_frame:SetScale(val);
        sc.overlay.currently_casting_frame_parent.border:SetScale(val);
    end);

    __sc_frame.overlay_frame.y_offset = __sc_frame.overlay_frame.y_offset - 30;

    f_txt = __sc_frame.overlay_frame:CreateFontString(nil, "OVERLAY")
    f_txt:SetFontObject(GameFontNormal)
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    f_txt:SetPoint("TOPLEFT", 15, __sc_frame.overlay_frame.y_offset);
    f_txt:SetText("Font");

    local overlay_currently_casting_font_dropdown_f = create_font_dropdown(
        __sc_frame.overlay_frame,
        "__sc_frame_setting_overlay_currently_casting_font",
        "overlay_currently_casting_font",
        sc.overlay.set_currently_casting_frames_font
    );
    overlay_currently_casting_font_dropdown_f:SetPoint("TOPLEFT", 232, __sc_frame.overlay_frame.y_offset+6);
end

local function create_sw_ui_calculator_frame()

    local f, f_txt;
    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset - 5;
    local x_pad = 5;

    f_txt = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.calculator_frame.y_offset);
    f_txt:SetText("While this tab is open, ability overlay & tooltips reflect the change below");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset - 25;

    f_txt = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", x_pad, __sc_frame.calculator_frame.y_offset);
    f_txt:SetText("Active Loadout: ");
    __sc_frame.calculator_frame.loadout_name_label = f_txt;

    f_txt = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 355, __sc_frame.calculator_frame.y_offset);
    f_txt:SetText("Delta");

    f = CreateFrame("Button", "nil", __sc_frame.calculator_frame, "UIPanelButtonTemplate"); 
    f:SetScript("OnClick", function()

        for _, v in pairs(__sc_frame.calculator_frame.stats) do
            v.editbox:SetText("");
        end
        update_calc_list();
    end);

    f:SetPoint("TOPLEFT", 385, __sc_frame.calculator_frame.y_offset+5);
    f:SetHeight(20);
    f:SetWidth(70);
    f:SetText("Clear");

     __sc_frame.calculator_frame.stats = {
         int = {
             label_str = "Intellect"
         },
         spirit = {
             label_str = "Spirit"
         },
         str = {
             label_str = "Strength"
         },
         agi = {
             label_str = "Agility"
         },
         sp = {
             label_str = "Spell Power"
         },
         sd = {
             label_str = "Spell Damage"
         },
         hp = {
             label_str = "Healing Power"
         },
         ap = {
             label_str = "Melee Attack Power"
         },
         rap = {
             label_str = "Ranged Attack Power"
         },
         wep = {
             label_str = "All Weapon Skill"
         },
         crit_rating = {
             label_str = "Critical"
         },
         hit_rating = {
             label_str = "Hit"
         },
         haste_rating = {
             label_str = "Haste"
         },
         mp5 = {
             label_str = "MP5"
         },
         spell_pen = {
             label_str = "Spell Penetration"
         },
     };
     local comparison_stats_listing_order = {
         "str", "agi", "int", "spirit", "crit_rating", "hit_rating", "haste_rating",
         "", -- split column delimiter
         "ap", "rap", "wep", "sp", "sd", "hp", "mp5", "spell_pen",
     };

    local num_stats = 0;
    for _ in pairs(__sc_frame.calculator_frame.stats) do
        num_stats = num_stats + 1;
    end

    local y_offset_stats = __sc_frame.calculator_frame.y_offset;
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
            y_offset_stats = __sc_frame.calculator_frame.y_offset;
            x_offset = x_offset + 210;
            editbox_x_pad = 50;
        end

        local v = __sc_frame.calculator_frame.stats[k];
        y_offset_stats = y_offset_stats - 17;

        v.label = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");

        v.label:SetFontObject(font);
        v.label:SetPoint("TOPLEFT", x_pad + x_offset, y_offset_stats);
        v.label:SetText(v.label_str);
        v.label:SetTextColor(222/255, 192/255, 40/255);

        v.editbox = CreateFrame("EditBox", v.label_str.."editbox"..k, __sc_frame.calculator_frame, "InputBoxTemplate");
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
            __sc_frame.calculator_frame.stats[comparison_stats_listing_order[next_index]].editbox:SetFocus();
        end);

        max_y_offset_stats = math.min(max_y_offset_stats, y_offset_stats);
        i = i + 1;
    end

    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset + max_y_offset_stats;

    __sc_frame.calculator_frame.stats.sp.editbox:SetText("1");
    __sc_frame.calculator_frame.stats.ap.editbox:SetText("1");
    __sc_frame.calculator_frame.stats.rap.editbox:SetText("1");
    if sc.core.__sw__test_all_codepaths then
        for _, v in pairs(__sc_frame.calculator_frame.stats) do
            v.editbox:SetText("1");
        end
    end

    local div = __sc_frame.calculator_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.calculator_frame, "TOPLEFT", 0, __sc_frame.calculator_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.calculator_frame, "TOPRIGHT", 0, __sc_frame.calculator_frame.y_offset);

    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset - 5;

    multi_row_checkbutton(
        {{id = "calc_list_use_highest_rank", txt = "Use highest learned rank of spell"}},
        __sc_frame.calculator_frame,
        2,
        function()
            update_calc_list();
        end,
        5);

    -- sim type button
    __sc_frame.calculator_frame.sim_type_button = 
        --CreateFrame("Button", "__sc_frame_setting_calc_fight_type", __sc_frame.calculator_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_setting_calc_fight_type", __sc_frame.calculator_frame);

    __sc_frame.calculator_frame.sim_type_button._type = "DropDownMenu";
    __sc_frame.calculator_frame.sim_type_button:SetPoint("TOPRIGHT", 10, __sc_frame.calculator_frame.y_offset);
    __sc_frame.calculator_frame.sim_type_button.init_func = function()
        libDD:UIDropDownMenu_Initialize(__sc_frame.calculator_frame.sim_type_button, function()
            
            if config.settings.calc_fight_type == fight_types.repeated_casts then
                libDD:UIDropDownMenu_SetText(__sc_frame.calculator_frame.sim_type_button, "Repeated casts");
                __sc_frame.calculator_frame.spell_diff_header_center:SetText("Per sec");
                __sc_frame.calculator_frame.spell_diff_header_right:SetText("Effect");
            elseif config.settings.calc_fight_type == fight_types.cast_until_oom then
                libDD:UIDropDownMenu_SetText(__sc_frame.calculator_frame.sim_type_button, "Cast until OOM");
                __sc_frame.calculator_frame.spell_diff_header_center:SetText("Effect");
                __sc_frame.calculator_frame.spell_diff_header_right:SetText("Duration (sec)");
            end
            libDD:UIDropDownMenu_SetWidth(__sc_frame.calculator_frame.sim_type_button, 130);

            libDD:UIDropDownMenu_AddButton(
                {
                    text = "Repeated cast",
                    checked = config.settings.calc_fight_type == fight_types.repeated_casts,
                    func = function()

                        config.settings.calc_fight_type = fight_types.repeated_casts;
                        libDD:UIDropDownMenu_SetText(__sc_frame.calculator_frame.sim_type_button, "Repeated casts");
                        __sc_frame.calculator_frame.spell_diff_header_center:SetText("Per sec");
                        __sc_frame.calculator_frame.spell_diff_header_right:SetText("Effect");
                        update_calc_list();
                    end
                }
            );
            libDD:UIDropDownMenu_AddButton(
                {
                    text = "Cast until OOM",
                    checked = config.settings.calc_fight_type == fight_types.cast_until_oom,
                    func = function()

                        config.settings.calc_fight_type = fight_types.cast_until_oom;
                        libDD:UIDropDownMenu_SetText(__sc_frame.calculator_frame.sim_type_button, "Cast until OOM");
                        __sc_frame.calculator_frame.spell_diff_header_center:SetText("Effect");
                        __sc_frame.calculator_frame.spell_diff_header_right:SetText("Duration (sec)");
                        update_calc_list();
                    end
                }
            );
        end);
    end;

    f = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Abilities can be added from Spells tab");
    f:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.calculator_frame.spells_add_tip = f;

    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset - 17;
    __sc_frame.calculator_frame.y_offset = __sc_frame.calculator_frame.y_offset - 17;

    __sc_frame.calculator_frame.spell_diff_header_spell = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.calculator_frame.spell_diff_header_spell:SetFontObject(font);
    __sc_frame.calculator_frame.spell_diff_header_spell:SetPoint("TOPLEFT", x_pad, __sc_frame.calculator_frame.y_offset);
    __sc_frame.calculator_frame.spell_diff_header_spell:SetText("Spell");

    __sc_frame.calculator_frame.spell_diff_header_left = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.calculator_frame.spell_diff_header_left:SetFontObject(font);
    __sc_frame.calculator_frame.spell_diff_header_left:SetPoint("TOPLEFT", x_pad + 245, __sc_frame.calculator_frame.y_offset);
    __sc_frame.calculator_frame.spell_diff_header_left:SetText("Change");

    __sc_frame.calculator_frame.spell_diff_header_center = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.calculator_frame.spell_diff_header_center:SetFontObject(font);
    __sc_frame.calculator_frame.spell_diff_header_center:SetPoint("TOPLEFT", x_pad + 320, __sc_frame.calculator_frame.y_offset);
    __sc_frame.calculator_frame.spell_diff_header_center:SetText("");

    __sc_frame.calculator_frame.spell_diff_header_right = __sc_frame.calculator_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.calculator_frame.spell_diff_header_right:SetFontObject(font);
    __sc_frame.calculator_frame.spell_diff_header_right:SetPoint("TOPLEFT", x_pad + 380, __sc_frame.calculator_frame.y_offset);
    __sc_frame.calculator_frame.spell_diff_header_right:SetText("");


    __sc_frame.calculator_frame.calc_list = {};
end

local function create_sw_ui_loadout_frame()
    local f, f_txt;

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 5;
    local x_pad = 5;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Loadouts are character specific, consisting of spell calculation parameters");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Active loadout");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = --CreateFrame("Button", nil, __sc_frame.loadout_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_loadout_frame_loadout_dropdown", __sc_frame.loadout_frame);
    f:SetPoint("TOPLEFT", x_pad + 80, __sc_frame.loadout_frame.y_offset+7);
    f.init_func = function()
        libDD:UIDropDownMenu_SetText(__sc_frame.loadout_frame.loadout_dropdown, config.loadout.name);
        libDD:UIDropDownMenu_Initialize(__sc_frame.loadout_frame.loadout_dropdown, function()

            libDD:UIDropDownMenu_SetWidth(__sc_frame.loadout_frame.loadout_dropdown, 100);

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
    __sc_frame.loadout_frame.loadout_dropdown = f;

    f = CreateFrame("Button", nil, __sc_frame.loadout_frame, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad + 300, __sc_frame.loadout_frame.y_offset+6);
    f:SetText("Reset to defaults");
    f:SetSize(140, 25);
    f:SetScript("OnClick", function(self)


        config.reset_loadout();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;
    f = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    f:SetText("Rename");
    f:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_name", __sc_frame.loadout_frame, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad + 105, __sc_frame.loadout_frame.y_offset+2);
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
    __sc_frame.loadout_frame.name_editbox = f;

    f = CreateFrame("Button", "__sc_frame_loadouts_delete_button", __sc_frame.loadout_frame, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad + 300, __sc_frame.loadout_frame.y_offset+6);
    f:SetText("Delete");
    f:SetSize(140, 25);
    f:SetScript("OnClick", function(self)

        config.delete_loadout();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);
    __sc_frame.loadout_frame.delete_button = f;

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    f:SetText("New loadout");
    f:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", nil, __sc_frame.loadout_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad + 105, __sc_frame.loadout_frame.y_offset+3);
    f:SetSize(90, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)

        local txt = self:GetText();
        if txt ~= "" then

            for _, v in pairs(__sc_frame.loadout_frame.new_loadout_section) do
                v:Show();
            end
        else
            for _, v in pairs(__sc_frame.loadout_frame.new_loadout_section) do
                v:Hide();
            end
        end
    end
    editbox_config(f, editbox_save);
    __sc_frame.loadout_frame.new_loadout_name_editbox = f;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad + 200, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("from");
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.loadout_frame.new_loadout_txt1 = f_txt;

    f = CreateFrame("Button", nil, __sc_frame.loadout_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        if config.new_loadout_from_default(__sc_frame.loadout_frame.new_loadout_name_editbox:GetText()) then
            __sc_frame.loadout_frame.new_loadout_name_editbox:SetText("");
            sc.core.talents_update_needed = true;
            update_loadout_frame();
        end
    end);
    f:SetPoint("TOPLEFT", x_pad + 250, __sc_frame.loadout_frame.y_offset+6);
    f:SetText("Default");
    f:SetWidth(100);
    __sc_frame.loadout_frame.new_loadout_button1 = f;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", x_pad + 360, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("or");
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.loadout_frame.new_loadout_txt2 = f_txt;

    f = CreateFrame("Button", nil, __sc_frame.loadout_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        if config.new_loadout_from_active_copy(__sc_frame.loadout_frame.new_loadout_name_editbox:GetText()) then
            __sc_frame.loadout_frame.new_loadout_name_editbox:SetText("");
            sc.core.talents_update_needed = true;
            update_loadout_frame();
        end
    end);
    f:SetPoint("TOPLEFT", x_pad + 380, __sc_frame.loadout_frame.y_offset+6);
    f:SetText("Copy");
    f:SetWidth(80);
    __sc_frame.loadout_frame.new_loadout_button2 = f;

    __sc_frame.loadout_frame.new_loadout_section = {
        __sc_frame.loadout_frame.new_loadout_txt1,
        __sc_frame.loadout_frame.new_loadout_txt2,
        __sc_frame.loadout_frame.new_loadout_button1,
        __sc_frame.loadout_frame.new_loadout_button2
    };

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 20;
    local div = __sc_frame.loadout_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.loadout_frame, "TOPLEFT", 0, __sc_frame.loadout_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.loadout_frame, "TOPRIGHT", 0, __sc_frame.loadout_frame.y_offset);
    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 5;

    f = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText("Player");
    f:SetPoint("TOPLEFT", 5, __sc_frame.loadout_frame.y_offset);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 20;


    f = CreateFrame("CheckButton", "__sc_frame_loadout_use_custom_lvl", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    f:SetHitRectInsets(0, 0, 0, 0);
    getglobal(f:GetName()..'Text'):SetText("Custom player level");
    getglobal(f:GetName()).tooltip =
        "Displays ability information as if character is a custom level (attributes from levels are not accounted for).";

    f:SetScript("OnClick", function(self)

        config.loadout.use_custom_lvl = self:GetChecked();
        sc.core.old_ranks_checks_needed = true;
        if config.loadout.use_custom_lvl then
            __sc_frame.loadout_frame.loadout_clvl_editbox:Show();
        else
            __sc_frame.loadout_frame.loadout_clvl_editbox:Hide();
        end
    end);
    __sc_frame.loadout_frame.custom_lvl_checkbutton = f;

    f = CreateFrame("EditBox", "__sc_frame_loadout_lvl", __sc_frame.loadout_frame, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", getglobal(__sc_frame.loadout_frame.custom_lvl_checkbutton:GetName()..'Text'), "RIGHT", 10, 0);
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
    __sc_frame.loadout_frame.loadout_clvl_editbox = f;

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_always_max_resource", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    getglobal(f:GetName()..'Text'):SetText("Always at maximum resources");
    getglobal(f:GetName()).tooltip = 
        "Assumes you are casting from maximum mana, energy, rage or combo points.";
    f:SetScript("OnClick", function(self)
        config.loadout.always_max_resource = self:GetChecked();
    end)
    __sc_frame.loadout_frame.max_mana_checkbutton = f;


    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;


    f = CreateFrame("CheckButton", "__sc_frame_loadout_use_custom_talents", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);

    getglobal(f:GetName()..'Text'):SetText("Custom talents");
    getglobal(f:GetName()).tooltip =
        "Accepts a valid wowhead talents link, your loadout will use its talents & glyphs instead of your active ones.";
    f:SetScript("OnClick", function(self)

       config.loadout.use_custom_talents = self:GetChecked();
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;

        update_loadout_frame();
    end);
    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 23;

    f = CreateFrame("EditBox", "__sc_frame_loadout_talent_editbox", __sc_frame.loadout_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+25, __sc_frame.loadout_frame.y_offset);
    f:SetSize(437, 15);
    f:SetAutoFocus(false);
    editbox_config(f, function(self)

        local txt = self:GetText();
        sc.core.talents_update_needed = true;

        if config.loadout.use_custom_talents then
            if txt ~= "" then
                config.loadout.custom_talents_code = wowhead_talent_code_from_url(txt);
            end

            __sc_frame.loadout_frame.talent_editbox:SetText(
                wowhead_talent_link(config.loadout.custom_talents_code)
            );
            __sc_frame.loadout_frame.talent_editbox:SetAlpha(1.0);
        else

            __sc_frame.loadout_frame.talent_editbox:SetText(
                wowhead_talent_link(active_loadout().talents.code)
            );
            __sc_frame.loadout_frame.talent_editbox:SetAlpha(0.2);
            __sc_frame.loadout_frame.talent_editbox:SetCursorPosition(0);
        end
        self:ClearFocus();
    end);

    __sc_frame.loadout_frame.talent_editbox = f;
    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 23;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+4, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Extra mana for casts until OOM");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_extra_mana", __sc_frame.loadout_frame, "InputBoxTemplate");
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
    __sc_frame.loadout_frame.loadout_extra_mana_editbox = f;


    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 20;
    local div = __sc_frame.loadout_frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", __sc_frame.loadout_frame, "TOPLEFT", 0, __sc_frame.loadout_frame.y_offset);
    div:SetPoint("TOPRIGHT", __sc_frame.loadout_frame, "TOPRIGHT", 0, __sc_frame.loadout_frame.y_offset);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 5;
    f = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText("Target");
    f:SetPoint("TOPLEFT", 5, __sc_frame.loadout_frame.y_offset);
    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    __sc_frame.loadout_frame.auto_armor_frames = {};
    __sc_frame.loadout_frame.custom_armor_frames = {};

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    getglobal(f:GetName()..'Text'):SetText("Estimate armor");
    getglobal(f:GetName()).tooltip = 
        "Estimates armor from target level.";
    f:SetScript("OnClick", function(self)
        local checked = self:GetChecked();
        config.loadout.target_automatic_armor = checked;
        if checked then
            for _, v in pairs(__sc_frame.loadout_frame.auto_armor_frames) do
                v:Show();
            end
            for _, v in pairs(__sc_frame.loadout_frame.custom_armor_frames) do
                v:Hide();
            end
        else
            for _, v in pairs(__sc_frame.loadout_frame.auto_armor_frames) do
                v:Hide();
            end
            for _, v in pairs(__sc_frame.loadout_frame.custom_armor_frames) do
                v:Show();
            end
        end
    end);
    f:SetHitRectInsets(0, 0, 0, 0);
    __sc_frame.loadout_frame.automatic_armor = f;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", getglobal(f:GetName()..'Text'), "RIGHT", 50, 0);
    f_txt:SetText("Custom armor value");
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.loadout_frame.custom_armor_frames[1] = f_txt;


    f = CreateFrame("EditBox", "__sc_frame_loadout_target_armor", __sc_frame.loadout_frame, "InputBoxTemplate");
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
    __sc_frame.loadout_frame.custom_armor_frames[2] = f;

    local armor_pct_fn = function(self)
        if self:GetChecked() then
            config.loadout.target_automatic_armor_pct = self._value;
        end
        for _, v in pairs(__sc_frame.loadout_frame.auto_armor_frames) do
            v:SetChecked(config.loadout.target_automatic_armor_pct == v._value);
        end
    end;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_100", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 100;
    f:SetPoint("LEFT", getglobal(__sc_frame.loadout_frame.automatic_armor:GetName()..'Text'), "RIGHT", 40, 0);
    getglobal(f:GetName()..'Text'):SetText("Heavy 100%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    __sc_frame.loadout_frame.auto_armor_frames[1] = f;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_80", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 80;
    f:SetPoint("LEFT", getglobal(__sc_frame.loadout_frame.auto_armor_frames[1]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText("Medium 80%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    __sc_frame.loadout_frame.auto_armor_frames[2] = f;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_target_automatic_armor_50", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._value = 50;
    f:SetPoint("LEFT", getglobal(__sc_frame.loadout_frame.auto_armor_frames[2]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText("Light 50%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    __sc_frame.loadout_frame.auto_armor_frames[3] = f;

    for _, v in pairs(__sc_frame.loadout_frame.auto_armor_frames) do
        v:Hide();
    end
    for _, v in pairs(__sc_frame.loadout_frame.custom_armor_frames) do
        v:Show();
    end

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_behind_target", __sc_frame.loadout_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad, __sc_frame.loadout_frame.y_offset);
    getglobal(f:GetName()..'Text'):SetText("Attacked from behind, eliminating parry and block");
    f:SetScript("OnClick", function(self)
        config.loadout.behind_target = self:GetChecked();
    end)

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 30;


    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+5, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Level difference");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_default_target_lvl_diff", __sc_frame.loadout_frame, "InputBoxTemplate");
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
    __sc_frame.loadout_frame.level_editbox = f;

    f = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetPoint("LEFT", __sc_frame.loadout_frame.level_editbox, "RIGHT", 10, 0);
    f:SetText("(when no hostile target available)");
    f:SetTextColor(1.0,  1.0,  1.0);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+5, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Resistance");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_target_res", __sc_frame.loadout_frame, "InputBoxTemplate");
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

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+5, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Default health");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_default_target_hp_perc", __sc_frame.loadout_frame, "InputBoxTemplate");
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
    __sc_frame.loadout_frame.hp_perc_label_editbox = f;
    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", f, "RIGHT", 5, 0);
    f_txt:SetText("%");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    __sc_frame.loadout_frame.y_offset = __sc_frame.loadout_frame.y_offset - 25;

    f_txt = __sc_frame.loadout_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", __sc_frame.loadout_frame, x_pad+5, __sc_frame.loadout_frame.y_offset);
    f_txt:SetText("Number of targets for unbounded AOE spells");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_loadout_unbounded_aoe_targets", __sc_frame.loadout_frame, "InputBoxTemplate");
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
    __sc_frame.loadout_frame.loadout_unbounded_aoe_targets_editbox = f;

end

local forced_buffs_lname_to_id = {};

local function create_sw_ui_buffs_frame()

    local f, f_txt;

    f = CreateFrame("CheckButton", "__sc_frame_loadout_force_apply_buffs", __sc_frame.buffs_frame, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", __sc_frame.buffs_frame, 0, __sc_frame.buffs_frame.y_offset);
    getglobal(f:GetName() .. 'Text'):SetText("Enable selected auras even when inactive");
    getglobal(f:GetName()).tooltip = 
        "The selected buffs will be applied behind the scenes to the spell calculations.";
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.loadout.force_apply_buffs = self:GetChecked();
        update_buffs_frame();
    end);
    __sc_frame.buffs_frame.always_apply_buffs_button = f;

    __sc_frame.buffs_frame.y_offset = __sc_frame.buffs_frame.y_offset - 25;

    f = CreateFrame("EditBox", "__sc_frame_buffs_search", __sc_frame.buffs_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 8, __sc_frame.buffs_frame.y_offset);
    f:SetSize(160, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.buffs_frame.search_empty_label:Show();
            for _, view in ipairs(buffs_views) do
                for k, _ in ipairs(view.buffs) do
                    view.filtered[k] = k;
                end
            end
        else
            __sc_frame.buffs_frame.search_empty_label:Hide();
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
            __sc_frame.buffs_frame[view.side].slider:SetMinMaxValues(1, max(1, #view.filtered - math.floor(__sc_frame.buffs_frame[view.side].num_buffs_can_fit/2)));
        end
        update_buffs_frame();
    end);
    __sc_frame.buffs_frame.search = f;

    f = __sc_frame.buffs_frame:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText("Search name or ID");
    f:SetPoint("LEFT", __sc_frame.buffs_frame.search, 5, 0);
    __sc_frame.buffs_frame.search_empty_label = f;

    for view_idx, view in ipairs(buffs_views) do

        -- init without any filter, 1 to 1
        for k, _ in ipairs(view.buffs) do
            view.filtered[k] = k;
        end

        local y_offset = __sc_frame.buffs_frame.y_offset;

        y_offset = y_offset - 20;

        f = CreateFrame("ScrollFrame", "__sc_frame_buffs_frame_"..view.side, __sc_frame.buffs_frame);
        f:SetWidth(235);
        f:SetHeight(490);
        f:SetPoint("TOPLEFT", __sc_frame.buffs_frame, 240*(view_idx-1), y_offset);
        __sc_frame.buffs_frame[view.side] = {}
        __sc_frame.buffs_frame[view.side].frame = f;

        f = CreateFrame("ScrollFrame", "__sc_frame_buffs_list_"..view.side, __sc_frame.buffs_frame[view.side].frame);
        f:SetWidth(235);
        f:SetHeight(455);
        f:SetPoint("TOPLEFT", __sc_frame.buffs_frame[view.side].frame, 0, -35);
        __sc_frame.buffs_frame[view.side].buffs_list_frame = f;

        __sc_frame.buffs_frame[view.side].num_checked = 0;
        __sc_frame.buffs_frame[view.side].buffs = {};
        __sc_frame.buffs_frame[view.side].buffs_num = 0;

        y_offset = -5;

        f = __sc_frame.buffs_frame[view.side].frame:CreateFontString(nil, "OVERLAY");
        f:SetFontObject(GameFontNormal);
        local fp, _, flags = f:GetFont();
        f:SetFont(fp, 17, flags);
        if (view_idx == 1) then
            f:SetText("Player auras");
        else
            f:SetText("Subject auras");
        end
        f:SetPoint("TOPLEFT", 5, y_offset);

        y_offset = y_offset - 15;
        f = CreateFrame("CheckButton", "__sc_frame_check_all_"..view.side, __sc_frame.buffs_frame[view.side].frame, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", 20, y_offset);
        getglobal(f:GetName() .. 'Text'):SetText("Select all/none");
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
        __sc_frame.buffs_frame[view.side].select_all_buffs_checkbutton = f;

        f = CreateFrame("Slider", nil, __sc_frame.buffs_frame[view.side].buffs_list_frame, "UIPanelScrollBarTrimTemplate");
        f:SetOrientation('VERTICAL');
        f:SetPoint("RIGHT", __sc_frame.buffs_frame[view.side].buffs_list_frame, "RIGHT", 0, 2);
        f:SetHeight(__sc_frame.buffs_frame[view.side].buffs_list_frame:GetHeight()-30);
        __sc_frame.buffs_frame[view.side].num_buffs_can_fit =
            math.floor(__sc_frame.buffs_frame[view.side].buffs_list_frame:GetHeight()/15);
        f:SetMinMaxValues( 1, max(1, #view.filtered - math.floor(__sc_frame.buffs_frame[view.side].num_buffs_can_fit/2)));
        f:SetValue(1);
        f:SetValueStep(1);
        f:SetScript("OnValueChanged", function(self, val)
            update_buffs_frame();
        end);

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f);
        bg:SetColorTexture(0, 0, 0, 0.5);

        __sc_frame.buffs_frame[view.side].slider = f;

        __sc_frame.buffs_frame[view.side].buffs_list_frame:SetScript("OnMouseWheel", function(self, dir)
            local min_val, max_val = __sc_frame.buffs_frame[view.side].slider:GetMinMaxValues();
            local val = __sc_frame.buffs_frame[view.side].slider:GetValue();
            if val - dir >= min_val and val - dir <= max_val then
                __sc_frame.buffs_frame[view.side].slider:SetValue(val - dir);
                update_buffs_frame();
            end
        end);


        y_offset = 0;
        for i = 1, __sc_frame.buffs_frame[view.side].num_buffs_can_fit do
            __sc_frame.buffs_frame[view.side].buffs[i] = {};

            local checkbtn = CreateFrame("CheckButton", "loadout_buffs_checkbutton"..view.side..i, __sc_frame.buffs_frame[view.side].buffs_list_frame, "ChatConfigCheckButtonTemplate");
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
                        __sc_frame.buffs_frame[view.side].num_checked = __sc_frame.buffs_frame[view.side].num_checked + 1;
                    else
                        config_buffs[self.buff_id] = nil;
                        forced_buffs_lname_to_id[GetSpellInfo(self.buff_id)] = nil;
                        __sc_frame.buffs_frame[view.side].num_checked = __sc_frame.buffs_frame[view.side].num_checked - 1;
                    end

                    if __sc_frame.buffs_frame[view.side].num_checked == 0 then
                        __sc_frame.buffs_frame[view.side].select_all_buffs_checkbutton:SetChecked(false);
                    else
                        __sc_frame.buffs_frame[view.side].select_all_buffs_checkbutton:SetChecked(true);
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
            local icon = CreateFrame("Frame", "loadout_buffs_icon"..view.side..i, __sc_frame.buffs_frame[view.side].buffs_list_frame);
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

            __sc_frame.buffs_frame[view.side].buffs[i].checkbutton = checkbtn;
            __sc_frame.buffs_frame[view.side].buffs[i].icon = icon;
        end
    end
end

local function update_profile_frame()

    sc.config.set_active_settings();
    sc.config.activate_settings();

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

local function create_sw_ui_profile_frame()

    local f, f_txt;
    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 5;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Profiles are shared across characters and retain all settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 12;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("  except for Loadouts and Buffs");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Main spec profile");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    __sc_frame.profile_frame.primary_spec = 
        --CreateFrame("Button", "__sc_frame_profile_main_spec", __sc_frame.profile_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_profile_main_spec", __sc_frame.profile_frame);
    __sc_frame.profile_frame.primary_spec:SetPoint("TOPLEFT", 170, __sc_frame.profile_frame.y_offset+6);
    __sc_frame.profile_frame.primary_spec.init_func = function()

        libDD:UIDropDownMenu_SetText(__sc_frame.profile_frame.primary_spec, __sc_p_char.main_spec_profile);
        libDD:UIDropDownMenu_Initialize(__sc_frame.profile_frame.primary_spec, function()

            libDD:UIDropDownMenu_SetWidth(__sc_frame.profile_frame.primary_spec, 130);

            for k, _ in pairs(__sc_p_acc.profiles) do
                libDD:UIDropDownMenu_AddButton({
                        text = k,
                        checked = __sc_p_char.main_spec_profile == k,
                        func = function()
                            __sc_p_char.main_spec_profile = k;
                            libDD:UIDropDownMenu_SetText(__sc_frame.profile_frame.primary_spec, k);
                            update_profile_frame();
                        end
                    }
                );
            end
        end);
    end;

    __sc_frame.profile_frame.active_main_spec = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.profile_frame.active_main_spec:SetFontObject(GameFontNormal);
    __sc_frame.profile_frame.active_main_spec:SetPoint("TOPLEFT", 350, __sc_frame.profile_frame.y_offset);
    __sc_frame.profile_frame.active_main_spec:SetText("<--- Active");
    __sc_frame.profile_frame.active_main_spec:SetTextColor(1.0,  0.0,  0.0);


    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 25;
    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Secondary spec profile");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    __sc_frame.profile_frame.second_spec = 
        --CreateFrame("Button", "__sc_frame_profile_second_spec", __sc_frame.profile_frame, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("__sc_frame_profile_second_spec", __sc_frame.profile_frame);
    __sc_frame.profile_frame.second_spec:SetPoint("TOPLEFT", 170, __sc_frame.profile_frame.y_offset+6);
    __sc_frame.profile_frame.second_spec.init_func = function()

        libDD:UIDropDownMenu_SetText(__sc_frame.profile_frame.second_spec, __sc_p_char.second_spec_profile);
        libDD:UIDropDownMenu_Initialize(__sc_frame.profile_frame.second_spec, function()

            libDD:UIDropDownMenu_SetWidth(__sc_frame.profile_frame.second_spec, 130);

            for k, _ in pairs(__sc_p_acc.profiles) do

                libDD:UIDropDownMenu_AddButton({
                        text = k,
                        checked = __sc_p_char.second_spec_profile == k,
                        func = function()
                            __sc_p_char.second_spec_profile = k;
                            libDD:UIDropDownMenu_SetText(__sc_frame.profile_frame.second_spec, k);
                            update_profile_frame();
                        end
                    }
                );
            end
        end);
    end;

    __sc_frame.profile_frame.active_second_spec = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.profile_frame.active_second_spec:SetFontObject(GameFontNormal);
    __sc_frame.profile_frame.active_second_spec:SetPoint("TOPLEFT", 350, __sc_frame.profile_frame.y_offset);
    __sc_frame.profile_frame.active_second_spec:SetText("<--- Active");
    __sc_frame.profile_frame.active_second_spec:SetTextColor(1.0,  0.0,  0.0);

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Rename active profile");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", "__sc_frame_profile_name_editbox", __sc_frame.profile_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.profile_frame, 195, __sc_frame.profile_frame.y_offset+3);
    f:SetSize(140, 15);
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
    __sc_frame.profile_frame.rename_editbox = f;

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Reset active profile");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("Button", nil, __sc_frame.profile_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        config.reset_profile();
    end);
    f:SetPoint("TOPLEFT", 190, __sc_frame.profile_frame.y_offset+4);
    f:SetText("Reset to defaults");
    f:SetWidth(145);

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;

    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Delete active profile");
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    __sc_frame.profile_frame.delete_profile_label = f_txt;

    f = CreateFrame("Button", nil, __sc_frame.profile_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        config.delete_profile();
        update_profile_frame();
    end);
    f:SetPoint("TOPLEFT", 190, __sc_frame.profile_frame.y_offset+4);
    f:SetText("Delete");
    f:SetWidth(145);
    __sc_frame.profile_frame.delete_profile_button = f;

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;
    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("New profile name");
    f_txt:SetTextColor(1.0, 1.0, 1.0);

    f = CreateFrame("EditBox", nil, __sc_frame.profile_frame, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", __sc_frame.profile_frame, 195, __sc_frame.profile_frame.y_offset+3);
    f:SetSize(140, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)
        local txt = self:GetText();
        if txt ~= "" then

            for _, v in pairs(__sc_frame.profile_frame.new_profile_section) do
                v:Show();
            end
        else
            for _, v in pairs(__sc_frame.profile_frame.new_profile_section) do
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
    __sc_frame.profile_frame.new_profile_name_editbox = f;


    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 35;
    __sc_frame.profile_frame.new_profile_section = {};
    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 30, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("Create new profile as:");
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.profile_frame.new_profile_section.txt1 = f_txt;


    f = CreateFrame("Button", nil, __sc_frame.profile_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)

        if config.new_profile_from_default(__sc_frame.profile_frame.new_profile_name_editbox:GetText()) then
            __sc_frame.profile_frame.new_profile_name_editbox:SetText("");
        end
        update_profile_frame();
    end);
    f:SetPoint("TOPLEFT", 190, __sc_frame.profile_frame.y_offset+4);
    f:SetText("Default preset");
    f:SetWidth(200);
    __sc_frame.profile_frame.new_profile_section.button1 = f;

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 25;
    f_txt = __sc_frame.profile_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 190, __sc_frame.profile_frame.y_offset);
    f_txt:SetText("or");
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    __sc_frame.profile_frame.new_profile_section.txt2 = f_txt;

    __sc_frame.profile_frame.y_offset = __sc_frame.profile_frame.y_offset - 25;
    f = CreateFrame("Button", nil, __sc_frame.profile_frame, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function(self)
        if config.new_profile_from_active_copy(__sc_frame.profile_frame.new_profile_name_editbox:GetText()) then
            __sc_frame.profile_frame.new_profile_name_editbox:SetText("");
        end
        update_profile_frame();
    end);
    f:SetPoint("TOPLEFT", 190, __sc_frame.profile_frame.y_offset+4);
    f:SetText("Copy of active profile");
    f:SetWidth(200);
    __sc_frame.profile_frame.new_profile_section.button2 = f;
end

local average_proc_sidebuffer = {};

local function create_sw_ui_settings_frame()

    local f, f_txt;

    __sc_frame.settings_frame.y_offset = __sc_frame.settings_frame.y_offset - 5;
    f_txt = __sc_frame.settings_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.settings_frame.y_offset);
    f_txt:SetText("General settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.settings_frame.y_offset = __sc_frame.settings_frame.y_offset - 15;

    local general_settings = {
        {
            id = "general_libstub_minimap_icon",
            txt = "Minimap icon",
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
            txt = "Spellbook tab button",
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
            txt = "Outdated addon notification",
        },
    };

    multi_row_checkbutton(general_settings, __sc_frame.settings_frame, 1);

    __sc_frame.settings_frame.y_offset = __sc_frame.settings_frame.y_offset - 10;

    f_txt = __sc_frame.settings_frame:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, __sc_frame.settings_frame.y_offset);
    f_txt:SetText("Spell settings");
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    __sc_frame.settings_frame.y_offset = __sc_frame.settings_frame.y_offset - 15;

    local spell_settings = {
        {
            id = "general_prio_heal",
            txt = "Prioritize healing for hybrid spells with both damage and healing",
        },
        {
            id = "general_prio_multiplied_effect",
            txt = "Prioritize optimistic effect over single effect",
        },
        {
            id = "general_average_proc_effects",
            txt = "Average out proc effects",
            tooltip = "Removes many proc effects and instead averages out its effect, giving more meaning to the spell evaluation. Example: Nature's grace modifies expected cast time to scale with crit, giving crit higher stat weight. Clearcasts and such.",
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

    multi_row_checkbutton(spell_settings, __sc_frame.settings_frame, 1);
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
        __sc_frame[v] = CreateFrame("ScrollFrame", "sw_"..v, __sc_frame);
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

    create_sw_spell_id_viewer();

    __sc_frame.tabs = {};

    local i = 1;

    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetHeight(25);
    __sc_frame.tabs[i]:SetText("Spells");
    __sc_frame.tabs[i]:SetID(1);
    __sc_frame.tabs[i]:SetScript("OnClick", function(self)
        sw_activate_tab(self);
    end);
    __sc_frame.tabs[i].frame_to_open = __sc_frame.spells_frame;
    PanelTemplates_TabResize(__sc_frame.tabs[i], 0)

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Tooltip");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.tooltip_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Overlay");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.overlay_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Calculator");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.calculator_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Profile");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.profile_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Loadout");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.loadout_frame;

    i = i + 1;
    __sc_frame.tabs[i] = CreateFrame("Button", "__sc_frame_tab_button"..i, __sc_frame, "PanelTopTabButtonTemplate");
    __sc_frame.tabs[i]:SetText("Buffs");
    __sc_frame.tabs[i].frame_to_open = __sc_frame.buffs_frame;

    local x = 5;
    for k, v in pairs(__sc_frame.tabs) do

        local w = v:GetFontString():GetStringWidth() + 33;
        v:SetPoint("TOPLEFT", x, -25);
        v:SetWidth(w);
        v:SetHeight(25);
        x = x + w;

        v:SetScript("OnClick", function(self)
            sw_activate_tab(self);
        end);
        v:SetID(k);
        PanelTemplates_TabResize(v, 0);
    end
    PanelTemplates_SetNumTabs(__sc_frame, i);

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

    if libstub_data_broker then
        local tooltip_show_fn = function(tooltip)
            tooltip:AddLine(sc.core.addon_name.." v"..sc.core.version);
            tooltip:AddLine("|cFF9CD6DELeft click:|r Interact with addon");
            tooltip:AddLine("|cFF9CD6DEMiddle click:|r Hide this button");
            if config.settings.overlay_old_rank then
                tooltip:AddLine("|cFF9CD6DERight click:|r |cFF00FF00(IS ON)|r Toggle old rank warning overlay");
            else
                tooltip:AddLine("|cFF9CD6DERight click:|r |cFFFF0000(IS OFF)|r Toggle old rank warning overlay");
            end
            tooltip:AddLine(" ");
            tooltip:AddLine("|cFF9CD6DEAddon data generated from:|r");
            tooltip:AddLine("    "..sc.client_name_src.." "..sc.client_version_src);
            tooltip:AddLine("|cFF9CD6DECurrent client build:|r "..sc.client_version_loaded);
            tooltip:AddLine("|cFF9CD6DEFactory reset (reloads UI):|r /sc reset");
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

    create_sw_ui_spells_frame();
    create_sw_ui_tooltip_frame();
    create_sw_ui_overlay_frame();
    create_sw_ui_loadout_frame();
    create_sw_ui_buffs_frame();
    create_sw_ui_calculator_frame();
    create_sw_ui_profile_frame();
    create_sw_ui_settings_frame();

    --__sc_frame.calculator_frame.sim_type = fight_types.repeated_casts;
    --__sc_frame.calculator_frame.sim_type_button.init_func();

    sw_activate_tab(__sc_frame.tabs[1]);
    __sc_frame:Hide();
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
            GameTooltip:SetText("SpellCoda ability catalogue");
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

local function post_login_load()
    -- some things must be done after PLAYER_LOGIN event
    add_spell_book_button();
    add_to_options();
end

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

sc.ui = ui;

