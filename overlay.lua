local _, sc = ...;

local L                                             = sc.L;

local spell_cost                                    = sc.utils.spell_cost;
local spell_cast_time                               = sc.utils.spell_cast_time;
local effect_color                                  = sc.utils.effect_color;
local format_number                                 = sc.utils.format_number;
local format_dur                                    = sc.utils.format_dur;
local table_from_schema                             = sc.utils.table_from_schema;

local spells                                        = sc.spells;
local spids                                         = sc.spids;
local spell_flags                                   = sc.spell_flags;

local highest_learned_rank                          = sc.utils.highest_learned_rank;

local update_loadout_and_effects                    = sc.loadouts.update_loadout_and_effects;
local update_loadout_and_effects_diffed_from_ui     = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local active_loadout                                = sc.loadouts.active_loadout;

local cast_until_oom                                = sc.calc.cast_until_oom;
local calc_spell_eval                               = sc.calc.calc_spell_eval;
local calc_spell_threat                             = sc.calc.calc_spell_threat;
local calc_spell_resource_regen                     = sc.calc.calc_spell_resource_regen;
local calc_effective_hp                             = sc.calc.calc_effective_hp;
local calc_spell_dummy_cast_until_oom               = sc.calc.calc_spell_dummy_cast_until_oom;

local config                                        = sc.config;
--------------------------------------------------------------------------------
local overlay = {};

local initialized = false;
local active_overlays = {};
local action_bar_frame_names = {};
local spell_book_frames = {};
local num_overlay_components_toggled = 0;
local action_id_frames = {};
local num_actions = 120;
local external_overlay_frames = {};
local action_bar_paging_overrides = {};

local loadout, effects;

overlay.decimals_cap = 3;

local anyspell_overlay, anyspell_cast_until_oom_overlay, mana_restoration_overlay, only_threat_overlay, effective_hp_overlay;

local function overlay_frames_config(overlay_frames)

    local font = sc.ui.get_font(config.settings.overlay_font[1]);

    overlay_frames[1]:SetPoint("TOP", config.settings.overlay_top_x, config.settings.overlay_top_y);
    overlay_frames[1]:SetFont(font, config.settings.overlay_top_fsize, config.settings.overlay_font[2]);

    overlay_frames[2]:SetPoint("CENTER", config.settings.overlay_center_x, config.settings.overlay_center_y);
    overlay_frames[2]:SetFont(font, config.settings.overlay_center_fsize, config.settings.overlay_font[2]);

    overlay_frames[3]:SetPoint("BOTTOM", config.settings.overlay_bottom_x, config.settings.overlay_bottom_y);
    overlay_frames[3]:SetFont(font, config.settings.overlay_bottom_fsize, config.settings.overlay_font[2]);
end

local function init_frame_overlay(frame_info)

    if not frame_info.overlay_frames then
        frame_info.overlay_frames = {};

        for i = 1, 3 do
            frame_info.overlay_frames[i] = frame_info.frame:CreateFontString(nil, "OVERLAY");
        end
        overlay_frames_config(frame_info.overlay_frames);
    end
end

--  sc.ext scope should be deleted at some point but remains for now
sc.ext.register_overlay_frame = function(frame, spell_id)

    sc.loadouts.force_update = true;
    if external_overlay_frames[frame] then
        external_overlay_frames[frame].spell_id = spell_id;
    else
        external_overlay_frames[frame] = {frame = frame, spell_id = spell_id};
        init_frame_overlay(external_overlay_frames[frame]);
    end

    for i = 1, 3 do
        external_overlay_frames[frame].overlay_frames[i]:Hide();
    end
    sc.core.old_ranks_checks_needed = true;
end

sc.ext.unregister_overlay_frame = function(frame)

    if external_overlay_frames[frame] and external_overlay_frames[frame].overlay_frames then
        for i = 1, 3 do
            external_overlay_frames[frame].overlay_frames[i]:Hide();
        end
    end
    external_overlay_frames[frame] = nil;
end

local external_ccf_callbacks = {};

local function register_cc_on_update(callback_fn, info_schema, stats_schema)
    local ccf_data = {};
    external_ccf_callbacks[callback_fn] = {
        data = ccf_data,
        info = {},
        stats = {},
        info_schema = info_schema,
        stats_schema = stats_schema,
    };
    return ccf_data;
end

local function unregister_cc_on_update(callback_fn)
    external_ccf_callbacks[callback_fn] = nil;
end

local function check_old_rank(frame_info, spell_id, clvl)

    local spell = spells[spell_id]
    if not spell then
        return;
    end

    for i = 1, 3 do
        frame_info.overlay_frames[i]:Hide();
    end

    if not config.settings.overlay_disable and not sc.core.mute_overlay and
        config.settings.overlay_old_rank and
        ((config.settings.overlay_old_rank_limit_to_known and spell_id ~= highest_learned_rank(spell.base_id))
         or
         (not config.settings.overlay_old_rank_limit_to_known and clvl > spell.lvl_outdated)) then

        frame_info.overlay_frames[1]:SetText(L["OLD"]);
        frame_info.overlay_frames[2]:SetText(L["RANK"]);
        frame_info.overlay_frames[3]:SetText("!!!");
        for i = 1, 3 do
            frame_info.overlay_frames[i]:SetTextColor(effect_color("old_rank"));
            frame_info.overlay_frames[i]:Show();
        end
        frame_info.old_rank_marked = true;
    else
        frame_info.old_rank_marked = false;
    end
end

local function old_rank_warning_traversal(clvl)

    if config.settings.overlay_disable or sc.core.mute_overlay then
        return;
    end
    for _, v in pairs(action_id_frames) do
        if v.frame then
            if spells[v.spell_id] then
                check_old_rank(v, v.spell_id, clvl);
            end
        end
    end
    for _, v in pairs(external_overlay_frames) do
        if v.frame then
            if spells[v.spell_id] then
                check_old_rank(v, v.spell_id, clvl);
            end
        end
    end
end

local function overlay_reconfig()

    if not initialized then
        return;
    end

    for i = 1, 12 do
        if spell_book_frames[i] then
            overlay_frames_config(spell_book_frames[i].overlay_frames);
        end
    end
    for _, v in pairs(action_id_frames) do
        if v.frame then
            overlay_frames_config(v.overlay_frames);
        end
    end
    for _, v in pairs(external_overlay_frames) do
        if v.frame then
            overlay_frames_config(v.overlay_frames);
        end
    end
end

local function clear_overlays()

    for _, v in pairs(action_id_frames) do
        v.old_rank_marked = false;
        if v.frame then
            for i = 1, 3 do
                v.overlay_frames[i]:SetText("");
                v.overlay_frames[i]:Hide();
            end
        end
    end
    for _, v in pairs(spell_book_frames) do
        v.old_rank_marked = false;
        if v.frame then
            for i = 1, 3 do
                v.overlay_frames[i]:SetText("");
                v.overlay_frames[i]:Hide();
            end
        end
    end
    for _, v in pairs(external_overlay_frames) do
        v.old_rank_marked = false;
        if v.frame then
            for i = 1, 3 do
                v.overlay_frames[i]:SetText("");
                v.overlay_frames[i]:Hide();
            end
        end
    end
end

local function action_id_of_button(button)

    if not button then
        return nil;
    end
    if button.action then
        return button.action;
    end
    if button.GetAttribute then
        return button:GetAttribute("action");
    end
    return nil;
end

local function spell_id_of_action(action_id)

    local spell_id = 0;
    local action_type, id, _ = GetActionInfo(action_id);
    if action_type == "macro" then
         spell_id, _ = GetMacroSpell(id);
    elseif action_type == "spell" then
         spell_id = id;
    end

    if not spells[spell_id] then
        spell_id = 0;
    elseif (bit.band(spells[spell_id].flags, spell_flags.eval) == 0) and
        (mana_restoration_overlay and bit.band(spells[spell_id].flags, spell_flags.resource_regen) == 0) and
        (effective_hp_overlay and bit.band(spells[spell_id].flags, spell_flags.ehp) == 0) and
        (only_threat_overlay and bit.band(spells[spell_id].flags, spell_flags.only_threat) == 0) and
        (anyspell_overlay and not spell_cost(spell_id) and not spell_cast_time(spell_id)) then
        spell_id = 0;
    end


    return spell_id;
end

local function try_register_frame(action_id, frame_name, spell_id)
    -- creates it if it suddenly exists but not registered
    local frame = _G[frame_name];
    if frame then
        action_id_frames[action_id].frame = frame;
        spell_id = spell_id or spell_id_of_action(action_id);
        if spell_id ~= 0 then
            active_overlays[action_id] = spell_id;
        else
            active_overlays[action_id] = nil;
        end
        action_id_frames[action_id].spell_id = spell_id;
        init_frame_overlay(action_id_frames[action_id]);
    end
end

local function scan_action_frames()

    for action_id, v in pairs(action_bar_frame_names) do
        try_register_frame(action_id, v);
    end
end

local IsAddOnLoaded = IsAddOnLoaded or function(addon_name)

    -- If for whatever reason IsAddOnLoaded is not defined, have some backup, and this can happen in clients builds...
    if addon_name == "Bartender4" then
        return BT4Button1 ~= nil;
    elseif addon_name == "ElvUI" then
        return ElvUI_Bar1Button1 ~= nil;
    elseif addon_name == "Dominos" then
        return DominosActionButton1 ~= nil;
    elseif addon_name == "DragonflightUI" then
        return DragonflightUI ~= nil;
    else
        return false;
    end
end;

local function use_base_bars()

    local index = 1;

    local highest_action_found = 0;
    for k, v in pairs({
        "Action",               -- 1-12
        "Bonus",                -- 13-24
        "MultiBarRight",        -- 25-36
        "MultiBarLeft",         -- 37-48
        "MultiBarBottomRight",  -- 49-60
        "MultiBarBottomLeft",   -- 61-72
        "",                     -- 73-84
        "MultiBar0",            -- 85-96
        "MultiBar1",            -- 97-108
        "MultiBar2",            -- 109-120
        "MultiBar3",            -- 121-132
        "MultiBar4",            -- 133-144
        "MultiBar5",            -- 145-156
        "MultiBar6",            -- 157-168
        "MultiBar7",            -- 169-180
    }) do
        for j = 1, 12 do
            if v ~= "" then
                if _G[v.."ActionButton"..j] then
                    action_bar_frame_names[index] = v.."ActionButton"..j;
                    highest_action_found = index;
                elseif _G[v.."Button"..j] then
                    action_bar_frame_names[index] = v.."Button"..j;
                    highest_action_found = index;
                end
            end
            index = index + 1;
        end
    end

    return highest_action_found;
end

local set_paging_override;

local function gather_spell_icons()

    active_overlays = {};

    -- gather spell book icons
    if false then -- check for some common addons if they overrite spellbook frames

    else -- default spellbook frames
        for i = 1, 12 do

            if not spell_book_frames[i] then
                spell_book_frames[i] = {
                    frame = _G["SpellButton"..i];
                };
                if spell_book_frames[i].frame then
                    spell_book_frames[i].frame:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);
                end
            end
        end
    end
    for i = 1, 12 do
        init_frame_overlay(spell_book_frames[i]);
    end

    -- gather action bar icons

    -- check for some common addons if they overrite spellbook frames
    if IsAddOnLoaded("Bartender4") then

        num_actions = 120;
        for i = 1, num_actions do
            action_bar_frame_names[i] = "BT4Button"..i;
        end

        set_paging_override = function(overrides)

            for k = 2, 10 do
                local bar = _G["BT4Bar".. k];
                if bar and bar.config and bar.config.states and bar.config.states.stance and
                    bar.config.states.stance[sc.class] and next(bar.config.states.stance[sc.class]) then
                    overrides[k] = 1;
                else
                    overrides[k] = nil;
                end
            end
        end

    elseif IsAddOnLoaded("ElvUI") then

        local highest_action_found = 0;
        for i = 1, 15 do
            for j = 1, 12 do
                local btn_name = "ElvUI_Bar"..i.."Button"..j;
                local slotf = _G[btn_name];

                if slotf then
                    local idx;
                    if slotf.action and slotf.action > 0 and i > 12 then
                        idx = slotf.action;
                    else
                        idx = (i-1)*12 + j;
                    end

                    action_bar_frame_names[idx] = btn_name;
                    highest_action_found = math.max(highest_action_found, idx);
                end
            end
        end
        num_actions = math.max(num_actions, highest_action_found);

        set_paging_override = function(overrides)

            for k = 2, 15 do
                local bar = _G["ElvUI_Bar".. k];
                if bar and bar.db and bar.db.paging and bar.db.paging[sc.class] then
                    overrides[k] = 1;
                else
                    overrides[k] = nil;
                end
            end
        end


    elseif IsAddOnLoaded("Dominos") then

        local highest_action_found = use_base_bars();

        -- Overwrite default bar names where DominosActionButtons are defined
        for i = 1, 180 do
            local btn_name = "DominosActionButton"..i;
            local slotf = _G[btn_name];
            if slotf then
                local idx;
                if slotf.action and slotf.action > 0 and i > 12 then
                    idx = slotf.action;
                else
                    idx = i;
                end

                action_bar_frame_names[idx] = btn_name;
                highest_action_found = math.max(highest_action_found, idx);
            end
        end
        num_actions = math.max(num_actions, highest_action_found);

    elseif IsAddOnLoaded("DragonflightUI") then
        local highest_action_found = use_base_bars();

        -- Overwrite default bar names where DragonflightUI buttons are defined
        local action_id = 145;
        for bar = 6, 8 do
            for btn = 1, 12 do
                local bar_name = "DragonflightUIMultiactionBar"..bar.."Button"..btn;
                local slotf = _G[bar_name];
                if slotf then

                    local idx = action_id;
                    action_bar_frame_names[idx] = bar_name;
                    highest_action_found = math.max(highest_action_found, idx);
                end
                action_id = action_id + 1;
            end
        end
        num_actions = math.max(num_actions, highest_action_found);

    else -- default action bars

        local highest_action_found = use_base_bars();

        num_actions = math.max(num_actions, highest_action_found);
    end

    for k, v in pairs(action_bar_frame_names) do
        if v ~= "" and _G[v] then
            _G[v]:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);
        end
    end

    for i = 1, num_actions do
        action_id_frames[i] = {};
    end
end

local function reassign_overlay_icon_spell(action_id, spell_id)

    if action_id_frames[action_id].frame then
        if spell_id == 0 then
            for i = 1, 3 do
                action_id_frames[action_id].overlay_frames[i]:SetText("");
                action_id_frames[action_id].overlay_frames[i]:Hide();
            end
            active_overlays[action_id] = nil;
        else
            check_old_rank(action_id_frames[action_id], spell_id, active_loadout().lvl);
            active_overlays[action_id] = spell_id;
        end
    end
    action_id_frames[action_id].spell_id = spell_id;
end

local function handle_mirrored_action_button(bar_id, action_id, spell_id)

    local mirrored_action_location = (action_id-1)%12 + (bar_id - 1)*12 + 1;
    local mirrored_action = action_id_frames[mirrored_action_location];
    if mirrored_action then
        local mirrored_action_id = action_id_of_button(mirrored_action.frame);
        if mirrored_action_id and mirrored_action_id == action_id then
            -- was mirrored, update that as well
            reassign_overlay_icon_spell(mirrored_action_location, spell_id)
        end
    end
end

local function reassign_overlay_icon(action_id)

    --action_id might not have a named frame (e.g. blizzard bars) at high IDs
    --but still be mirrored to named frames 1-12
    --if action_id > 120 or action_id <= 0 then
    if action_id > num_actions or action_id <= 0 then
        return;
    end

    local spell_id = spell_id_of_action(action_id);
    if action_id_frames[action_id].spell_id == spell_id then
        -- no change since last
        return;
    end
    action_id_frames[action_id].spell_id = spell_id;

    if action_bar_frame_names[action_id] then
        try_register_frame(action_id, action_bar_frame_names[action_id], spell_id);
    end

    -- NOTE: any action_id > 12 we might have mirrored action ids
    -- with Bar 1 due to shapeshifts, and forms taking over Bar 1
    -- so check if the action slot in bar 1 is the same
    if action_id > 12 then
        handle_mirrored_action_button(1, action_id, spell_id);
    end
    for bar in pairs(action_bar_paging_overrides) do
        handle_mirrored_action_button(bar, action_id, spell_id);
    end

    if action_bar_frame_names[action_id] then
        local button_frame = action_id_frames[action_id].frame;
        if button_frame then
            reassign_overlay_icon_spell(action_id, spell_id)
        end
    end
end

local function recheck_action_bar(bar_id)

    local action_id_button_first = (bar_id-1)*12 + 1;
    local action_id_button_last = action_id_button_first + 11;
    for i = action_id_button_first, action_id_button_last do

        -- Hopefully the Actionbar host has updated the new action id of its 1-12 action id bar
        local frame = action_id_frames[i].frame;
        if frame then

            local action_id = action_id_of_button(frame);

            local spell_id = 0;
            if action_id then
                spell_id = spell_id_of_action(action_id);
            end
            reassign_overlay_icon_spell(i, spell_id);
        end

    end

end

local function on_special_action_bar_changed()

    recheck_action_bar(1); -- always do bar 1
    for bar in pairs(action_bar_paging_overrides) do
        recheck_action_bar(bar);
    end
end

local active_overlay_indices = {};

local only_threat_label_types = {
    "overlay_display_threat",
    "overlay_display_threat_per_sec",
    "overlay_display_threat_per_cost"
};

local non_eval_cast_until_oom_label_types = {
    "overlay_display_time_until_oom",
    "overlay_display_casts_until_oom"
};
local non_eval_label_types = {
    "overlay_display_actual_cost",
    "overlay_display_actual_cast",
};

local function update_icon_overlay_settings()

    anyspell_overlay, anyspell_cast_until_oom_overlay, mana_restoration_overlay, only_threat_overlay, effective_hp_overlay =
        false, false, false, false, false;

    num_overlay_components_toggled = 0;
    if config.settings.overlay_top_enabled then
        active_overlay_indices[1] = config.settings.overlay_top_selection
        num_overlay_components_toggled = num_overlay_components_toggled + 1;
    else
        active_overlay_indices[1] = nil;
    end
    if config.settings.overlay_center_enabled then
        active_overlay_indices[2] = config.settings.overlay_center_selection
        num_overlay_components_toggled = num_overlay_components_toggled + 1;
    else
        active_overlay_indices[2] = nil;
    end
    if config.settings.overlay_bottom_enabled then
        active_overlay_indices[3] = config.settings.overlay_bottom_selection
        num_overlay_components_toggled = num_overlay_components_toggled + 1;
    else
        active_overlay_indices[3] = nil;
    end

    for _, label in pairs(active_overlay_indices) do
        for _, v in ipairs(only_threat_label_types) do
            if v == label then
                only_threat_overlay = true;
            end
        end
        for _, v in ipairs(non_eval_cast_until_oom_label_types) do
            if v == label then
                anyspell_cast_until_oom_overlay = true;
                anyspell_overlay = true;
            end
        end
        for _, v in ipairs(non_eval_label_types) do
            if v == label then
                anyspell_overlay = true;
            end
        end
    end

    mana_restoration_overlay = config.settings.overlay_resource_regen;
    effective_hp_overlay = config.settings.overlay_ehp;

    -- hide existing overlay frames that should no longer exist
    clear_overlays();

    if set_paging_override then
        set_paging_override(action_bar_paging_overrides)
    end
    active_overlays = {};
    sc.core.old_ranks_checks_needed = true;
    scan_action_frames();
    on_special_action_bar_changed();
    sc.loadouts.force_update = true;
    initialized = true;
end

local function setup_action_bars()
    gather_spell_icons();
    update_icon_overlay_settings();
end
local function update_action_bars()
    update_icon_overlay_settings();
end

local overlay_label_handler;
local function init_label_handler()
    -- delayed init to allow for config based localization
    overlay_label_handler = {
        overlay_display_normal = {
            func = function(frame_overlay, info)
                local val = 0.0;
                if info.num_direct_effects > 0 then
                    val = val + 0.5*(info.total_min_noncrit_if_hit + info.total_max_noncrit_if_hit);
                end
                if info.num_periodic_effects > 0 then
                    val = val + 0.5*(info.total_ot_min_noncrit_if_hit + info.total_ot_max_noncrit_if_hit);
                end
                frame_overlay:SetText(format_number(val, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Normal effect aggregate"],
            color_tag = "normal",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_crit = {
            func = function(frame_overlay, info, stats)
                local crit_sum = 0;

                if info.num_direct_effects > 0 then
                    crit_sum = crit_sum + 0.5*(info.total_min_crit_if_hit + info.total_max_crit_if_hit);
                end
                if info.num_periodic_effects > 0 then
                    crit_sum = crit_sum + 0.5*(info.total_ot_min_crit_if_hit + info.total_ot_max_crit_if_hit);
                end
                if stats.crit > 0 and crit_sum > 0 then
                    frame_overlay:SetText(format_number(crit_sum, math.min(1, overlay.decimals_cap)));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Critical effect aggregate"],
            color_tag = "crit",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_expected = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.expected, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Effect expectation"],
            color_tag = "expectation",
            requires_spell_flags = spell_flags.eval,
            tooltip = L["Effect for a single cast considering all possible outcomes such as failed/diminished attacks, critical hits etc."],
        },
        overlay_display_effect_per_sec = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.effect_per_sec, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Effect per sec"],
            color_tag = "effect_per_sec",
            requires_spell_flags = spell_flags.eval,
            tooltip = L["Expected effect divided by expected execution time"],
        },
        overlay_display_effect_per_cost = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.effect_per_cost, math.min(2, overlay.decimals_cap)));
            end,
            desc = L["Effect per cost"],
            color_tag = "effect_per_cost",
            requires_spell_flags = spell_flags.eval,
            tooltip = L["Expected effect divided by expected cost"],
        },
        overlay_display_threat = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.threat, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Threat expectation"],
            color_tag = "threat",
            requires_spell_flags = bit.bor(spell_flags.eval, spell_flags.only_threat),
        },
        overlay_display_threat_per_sec = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.threat_per_sec, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Threat per sec"],
            color_tag = "threat",
            requires_spell_flags = bit.bor(spell_flags.eval, spell_flags.only_threat),
        },
        overlay_display_threat_per_cost = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.threat_per_cost, math.min(2, overlay.decimals_cap)));
            end,
            desc = L["Threat per cost"],
            color_tag = "effect_per_cost",
            requires_spell_flags = bit.bor(spell_flags.eval, spell_flags.only_threat),
        },
        overlay_display_avg_cost = {
            func = function(frame_overlay, _, stats)
                if stats.cost >= 0 then
                    frame_overlay:SetText(format_number(stats.cost, math.min(1, overlay.decimals_cap)));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Cost expected"],
            color_tag = "cost",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_avg_cast = {
            func = function(frame_overlay, _, stats)
                if stats.cast_time > 0 then
                    frame_overlay:SetText(format_number(stats.cast_time, math.min(2, overlay.decimals_cap)));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Execution time expected"],
            color_tag = "execution_time",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_actual_cost = {
            func = function(frame_overlay, _, _, _, spell_id)
                frame_overlay:SetText(format_number(spell_cost(spell_id), 0));
            end,
            desc = L["Actual cost"],
            color_tag = "cost",
            tooltip = L["Not computed but queried through game API"],
        },
        overlay_display_actual_cast = {
            func = function(frame_overlay, _, _, _, spell_id)
                frame_overlay:SetText(format_number(spell_cast_time(spell_id), math.min(2, overlay.decimals_cap)));
            end,
            desc = L["Actual cast time"],
            color_tag = "execution_time",
            tooltip = L["Not computed but queried through game API and GCD capped"],
        },
        overlay_display_hit_chance = {
            func = function(frame_overlay, _, stats, spell)
                if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                    if spell.direct then
                        frame_overlay:SetText(string.format("%s%%",
                            format_number(100*stats.hit_normal, math.min(1, overlay.decimals_cap))));
                    else
                        frame_overlay:SetText(string.format("%s%%",
                            format_number(100*stats.hit_normal_ot, math.min(1, overlay.decimals_cap))));
                    end
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Normal hit chance"],
            color_tag = "normal",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_crit_chance = {
            func = function(frame_overlay, info, stats, spell)
                local crit;
                if spell.direct then
                    crit = stats.crit;
                else
                    crit = stats.crit_ot;
                end
                if crit ~= 0 and info.total_ot_min_crit_if_hit + info.total_min_crit_if_hit > 0 then
                    frame_overlay:SetText(string.format("%s%%", format_number(100*crit, math.min(1, overlay.decimals_cap))));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Critical hit chance"],
            color_tag = "crit",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_miss_chance = {
            func = function(frame_overlay, _, stats, spell)
                if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                    local miss;
                    if spell.direct then
                        miss = stats.miss;
                    else
                        miss = stats.miss_ot;
                    end
                    frame_overlay:SetText(string.format("%s%%", format_number(100*miss, math.min(1, overlay.decimals_cap))));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Miss chance"],
            color_tag = "avoidance_info",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_avoid_chance = {
            func = function(frame_overlay, _, stats, spell)
                local miss, dodge, parry;
                if spell.direct then
                    miss = stats.miss;
                    dodge = stats.dodge;
                    parry = stats.parry;
                else
                    miss = stats.miss_ot;
                    dodge = stats.dodge_ot;
                    parry = stats.parry_ot;
                end
                if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                    frame_overlay:SetText(string.format("%s%%",
                        format_number(100*(miss+dodge+parry), math.min(1, overlay.decimals_cap))));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Avoid chance"],
            color_tag = "avoidance_info",
            requires_spell_flags = spell_flags.eval,
            tooltip = L["Chance to miss, parry or dodge"]
        },
        overlay_display_effect_until_oom = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.effect_until_oom, 0));
            end,
            desc = L["Effect until OOM"],
            color_tag = "effect_until_oom",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_time_until_oom = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_dur(info.time_until_oom));
            end,
            desc = L["Time until OOM"],
            color_tag = "time_until_oom",
        },
        overlay_display_casts_until_oom = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.num_casts_until_oom, math.min(1, overlay.decimals_cap), true));
            end,
            desc = L["Casts until OOM"],
            color_tag = "casts_until_oom",
        },
        overlay_display_direct_normal = {
            func = function(frame_overlay, info)
                if info.num_direct_effects == 0 or info.hit_normal1 == 0 then
                    return;
                end

                if info.min_noncrit_if_hit1 ~= info.max_noncrit_if_hit1 then
                    frame_overlay:SetText(string.format("%.0f-%.0f",
                        info.min_noncrit_if_hit1, info.max_noncrit_if_hit1)
                    );
                else
                    frame_overlay:SetText(string.format("%.1f",
                        info.min_noncrit_if_hit1)
                    );
                end
            end,
            desc = L["Direct normal effect component 1"],
            color_tag = "normal",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_direct_crit = {
            func = function(frame_overlay, info)
                if info.num_direct_effects == 0 or info.crit1 == 0 then
                    return;
                end

                if info.min_crit_if_hit1 ~= info.max_crit_if_hit1 then
                    frame_overlay:SetText(string.format("%.0f-%.0f",
                        info.min_crit_if_hit1, info.max_crit_if_hit1)
                    );
                else
                    frame_overlay:SetText(string.format("%.1f",
                        info.min_crit_if_hit1)
                    );
                end
            end,
            desc = L["Direct critical effect component 1"],
            color_tag = "crit",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_ot_normal = {
            func = function(frame_overlay, info)
                if info.num_periodic_effects == 0 or info.ot_hit_normal1 == 0 then
                    return;
                end

                if info.ot_min_noncrit_if_hit1 ~= info.ot_max_noncrit_if_hit1 then
                    frame_overlay:SetText(string.format("%.0f x %.0f-%.0f",
                        info.ot_ticks1, info.ot_min_noncrit_if_hit1/info.ot_ticks1, info.ot_max_noncrit_if_hit1/info.ot_ticks1)
                    );
                else
                    frame_overlay:SetText(string.format("%.0f x %.1f",
                        info.ot_ticks1, info.ot_min_noncrit_if_hit1/info.ot_ticks1)
                    );
                end
            end,
            desc = L["Periodic normal effect component 1"],
            color_tag = "normal",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_ot_crit = {
            func = function(frame_overlay, info)
                if info.num_periodic_effects == 0 or info.ot_crit1 == 0 then
                    return;
                end

                if info.ot_min_crit_if_hit1 ~= info.ot_max_crit_if_hit1 then
                    frame_overlay:SetText(string.format("%.0f x %.0f-%.0f",
                        info.ot_ticks1, info.ot_min_crit_if_hit1/info.ot_ticks1, info.ot_max_crit_if_hit1/info.ot_ticks1)
                    );
                else
                    frame_overlay:SetText(string.format("%.0f x %.1f",
                        info.ot_ticks1, info.ot_min_crit_if_hit1/info.ot_ticks1)
                    );
                end
            end,
            desc = L["Periodic critical effect component 1"],
            color_tag = "crit",
            requires_spell_flags = spell_flags.eval,
        },
        overlay_display_rank = {
            func = function(frame_overlay, _, _, spell)
               if spell.rank > 0 then
                   frame_overlay:SetText(tostring(spell.rank));
               else
                   frame_overlay:SetText("");
               end
            end,
            desc = L["Rank"],
            color_tag = "spell_rank",
        },
        overlay_display_mitigation = {
            func = function(frame_overlay, info, stats, spell)
                local mit;
                if spell.direct then
                    if spell.direct.school1 == sc.schools.physical then
                        mit = stats.target_dr;
                    else
                        mit = stats.target_avg_resi;
                    end
                else
                    if spell.periodic.school1 == sc.schools.physical then
                        mit = stats.target_dr_ot;
                    else
                        mit = stats.target_avg_resi_ot;
                    end
                end

                if mit ~= 0 then
                    frame_overlay:SetText(string.format("%s%%",
                        format_number(100*mit, math.min(1, overlay.decimals_cap))));
                else
                    frame_overlay:SetText("");
                end
            end,
            desc = L["Mitigation"],
            color_tag = "avoidance_info",
            requires_spell_flags = spell_flags.eval,
            tooltip = L["Through armor or resistance"],
        },
        overlay_display_resource_regen = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.total_restored, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Resource regeneration"],
            color_tag = "cost",
            requires_spell_flags = spell_flags.resource_regen,
            non_standard = true,
            tooltip = L["Shows resource gained from spells like Evocation, Mana tide totem, etc."],
        },
        overlay_display_ehp = {
            func = function(frame_overlay, info)
                frame_overlay:SetText(format_number(info.ehp, math.min(1, overlay.decimals_cap)));
            end,
            desc = L["Effective health"],
            color_tag = "expectation",
            requires_spell_flags = spell_flags.ehp,
            non_standard = true,
            tooltip = L["Puts effective health calculation into passive spell "]..select(1, GetSpellInfo(spids.dodge)),
        },
    };
    sc.overlay.label_handler = overlay_label_handler;
end

local function update_spell_icon_frame(frame_info, spell, spell_id, loadout, effects, eval_flags)

    local spell_effect, stats;
    if bit.band(spell.flags, spell_flags.resource_regen) ~= 0 and
        config.settings.overlay_resource_regen then

        spell_effect = calc_spell_resource_regen(spell, spell_id, loadout, effects, eval_flags);

        local handler = overlay_label_handler.overlay_display_resource_regen;

        local resource_restore_disp_index = config.settings.overlay_resource_regen_display_idx;
        handler.func(frame_info.overlay_frames[resource_restore_disp_index], spell_effect);

        frame_info.overlay_frames[resource_restore_disp_index]:SetTextColor(effect_color(handler.color_tag));
        frame_info.overlay_frames[resource_restore_disp_index]:Show();

    elseif bit.band(spell.flags, spell_flags.ehp) ~= 0 and
        config.settings.overlay_ehp then

        spell_effect = calc_effective_hp(loadout, effects, eval_flags);

        local handler = overlay_label_handler.overlay_display_ehp;

        local ehp_disp_index = config.settings.overlay_ehp_display_idx;
        handler.func(frame_info.overlay_frames[ehp_disp_index], spell_effect);

        frame_info.overlay_frames[ehp_disp_index]:SetTextColor(effect_color(handler.color_tag));
        frame_info.overlay_frames[ehp_disp_index]:Show();

    elseif num_overlay_components_toggled > 0 then

        if bit.band(spell.flags, spell_flags.eval) ~= 0 then
            spell_effect, stats = calc_spell_eval(spell, loadout, effects, eval_flags, spell_id);
            cast_until_oom(spell_effect, spell, stats, loadout, effects, false, 0);

        elseif bit.band(spell.flags, spell_flags.only_threat) ~= 0 and only_threat_overlay then
            spell_effect, stats = calc_spell_threat(spell, loadout, effects, eval_flags);

        elseif anyspell_cast_until_oom_overlay then
            spell_effect, stats = calc_spell_dummy_cast_until_oom(spell_id, loadout, effects);
        end


        for i, v in pairs(active_overlay_indices) do
            local handler = overlay_label_handler[v];
            if not handler.requires_spell_flags or
                bit.band(spell.flags, handler.requires_spell_flags) ~= 0 then

                handler.func(
                    frame_info.overlay_frames[i],
                    spell_effect,
                    stats,
                    spell,
                    spell_id
                );

                frame_info.overlay_frames[i]:SetTextColor(effect_color(handler.color_tag));

                frame_info.overlay_frames[i]:Show();
            end
        end
    end
end

local function update_overlay_frame(frame, loadout, effects, id, eval_flags)

    if frame.old_rank_marked then
        return;
    end
    if spells[id].healing_version and config.settings.general_prio_heal then
        update_spell_icon_frame(frame, spells[id].healing_version, id, loadout, effects, eval_flags);
    else
        update_spell_icon_frame(frame, spells[id], id, loadout, effects, eval_flags);
    end
end


local ccf_parent = CreateFrame("Frame", nil, UIParent);
ccf_parent:RegisterForDrag("LeftButton");
ccf_parent:SetSize(250, 100);
ccf_parent:SetScript("OnDragStart", ccf_parent.StartMoving);
ccf_parent:SetScript("OnDragStop", function(self)
    ccf_parent:StopMovingOrSizing();
    local region, _, _, x, y = self:GetPoint()
    config.settings.overlay_cc_info_region = region;
    config.settings.overlay_cc_info_x = x;
    config.settings.overlay_cc_info_y = y;
end);
ccf_parent.config_mode = false;
ccf_parent:Show();

local border = CreateFrame("Frame", nil, ccf_parent, "BackdropTemplate");
border:SetPoint("CENTER", 0, 0);
border:SetSize(250, 100);
border:SetBackdrop({edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16});
border:SetBackdropBorderColor(1, 1, 1, 1);
border:Hide();

border.flash = border:CreateAnimationGroup();
border.flash.anim = border.flash:CreateAnimation("Alpha");
border.flash.anim:SetFromAlpha(1);
border.flash.anim:SetToAlpha(0);
border.flash.anim:SetDuration(0.5);
border.flash.anim:SetSmoothing("IN_OUT");

border.flash:SetScript("OnFinished", function(self)
    self:Play();
end);

border.txt = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
border.txt:SetPoint("TOP", 0, -10);

ccf_parent.border = border;
local ccf_labels;

local function cc_config_mode_spell_id()

    if sc.class == sc.classes.mage then
        return sc.spids.flamestrike;
    elseif sc.class == sc.classes.druid then
        return sc.spids.moonfire;
    elseif sc.class == sc.classes.priest then
        return sc.spids.holy_fire;
    elseif sc.class == sc.classes.shaman then
        return sc.spids.flame_shock;
    elseif sc.class == sc.classes.warlock then
        return sc.spids.immolate;
    elseif sc.class == sc.classes.rogue then
        return sc.spids.sinister_strike;
    elseif sc.class == sc.classes.paladin then
        return sc.spids.exorcism;
    elseif sc.class == sc.classes.warrior then
        return sc.spids.overpower;
    elseif sc.class == sc.classes.hunter then
        return sc.spids.aimed_shot;
    end
    return sc.auto_attack_spell_id;
end

local cc_new_spell;
local function cc_demo()
    cc_new_spell(cc_config_mode_spell_id());
end

local function cc_demo_dummy_fill(info, stats)

    -- display something in all fields for config demo
    info.num_direct_effects = 1;
    info.num_periodic_effects = 1;
    info.min_noncrit_if_hit1 = 1234;
    info.max_noncrit_if_hit1 = 2345;
    info.min_crit_if_hit1 = 4321;
    info.max_crit_if_hit1 = 5432;
    info.ot_min_noncrit_if_hit1 = 1234;
    info.ot_max_noncrit_if_hit1 = 2345;
    info.ot_min_crit_if_hit1 = 4321;
    info.ot_max_crit_if_hit1 = 5432;
    info.ot_ticks1 = 4;
    info.total_min_noncrit_if_hit = 1234;
    info.total_max_noncrit_if_hit = 2345;
    info.total_min_crit_if_hit = 4321;
    info.total_max_crit_if_hit = 5432;
    info.expected = 1234;
    info.effect_per_sec = 123;
    info.effect_per_cost = 123;
    info.threat = 1234;
    info.threat_per_sec = 123;
    info.threat_per_cost = 123;
    stats.cost = 123;
    stats.cast_time = 1.23;
    stats.hit_normal = 1/3;
    stats.hit_normal_ot = 1/3;
    stats.crit = 1/3;
    stats.crit_ot = 1/3;
    stats.miss = 1/9;
    stats.miss_ot = 1/9;
    stats.dodge = 1/9;
    stats.dodge_ot = 1/9;
    stats.parry = 1/9;
    stats.parry_ot = 1/9;
    info.effect_until_oom = 12345;
    info.time_until_oom = 90;
    info.num_casts_until_oom = 42;
    info.hit_normal1 = 1/3;
    info.ot_hit_normal1 = 1/3;
    info.crit1 = 1/3;
    info.ot_crit1 = 1/3;
    stats.target_dr = 0.2;
    stats.target_dr_ot = 0.2;
    stats.target_avg_resi = 0.2;
    stats.target_avg_resi_ot = 0.2;
end

local cc_spell_id           = 0;
local cc_noexpire           = false;
local cc_channel            = true;
local cc_expire_timer       = 0;
local cc_waiting_on_anim    = false;
local cc_enqueued_spell_id  = 0;

local function cc_enqueue(spell_id)

    if sc.overlay.cc_f1.icon_frame.animating and not config.settings.overlay_cc_transition_nocd then
        cc_waiting_on_anim = true;
        cc_enqueued_spell_id = spell_id;
    else
        cc_spell_id = spell_id;
        cc_new_spell(spell_id);
        cc_waiting_on_anim = false;
        cc_enqueued_spell_id = 0;
    end
end

local function set_cc_spell(spell_id)

    if spells[spell_id] and
        (not config.settings.overlay_cc_only_eval or
        bit.band(spells[spell_id].flags, spell_flags.eval) ~= 0) then

        cc_expire_timer = config.settings.overlay_cc_hanging_time;
        if cc_spell_id ~= spell_id then
            cc_enqueue(spell_id);
        end
    end
end

local auto_repeat_spells_tracking = {};
for _, v in pairs({"attack", "shoot", "auto_shot"}) do
    if sc.spids[v] then
        table.insert(auto_repeat_spells_tracking, sc.spids[v]);
    end
end

local function spell_tracking(dt)
    cc_expire_timer = cc_expire_timer - dt;
    if cc_noexpire then
        return;
    end
    if cc_expire_timer < 0.0 then

        -- degrade to autorepeat or 0
        local is_repeating = false;
        for _, id in pairs(auto_repeat_spells_tracking) do
            if IsCurrentSpell(id) then
                is_repeating = true;
                set_cc_spell(id);
                break;
            end
        end

        if not is_repeating then

            if cc_spell_id ~= 0 then
                cc_enqueue(0);
            end
            cc_spell_id = 0;
        end
    end

    if cc_waiting_on_anim then
        cc_enqueue(cc_enqueued_spell_id);
    end
end

local cc_event_dispatch = {
    ["UNIT_SPELLCAST_SUCCEEDED"] = function(self, caster, _, spell_id)
        if caster == "player" then
            set_cc_spell(spell_id);
            if not cc_channel then
                cc_noexpire = false;
            end
        end
    end,
    ["UNIT_SPELLCAST_CHANNEL_START"] = function(_, caster, _, spell_id)
        if caster == "player" then
            set_cc_spell(spell_id);
            cc_noexpire = true;
            cc_channel = true;
        end
    end,
    ["UNIT_SPELLCAST_CHANNEL_STOP"] = function(_, caster, _, spell_id)
        if caster == "player" then
            cc_noexpire = false;
            cc_channel = false;
            cc_expire_timer = config.settings.overlay_cc_hanging_time;
        end
    end,
    ["UNIT_SPELLCAST_START"] = function(self, caster, _, spell_id)
        if caster == "player" then
            set_cc_spell(spell_id);
            cc_noexpire = true;
        end
    end,
    ["UNIT_SPELLCAST_STOP"] = function(self, caster, _, spell_id)
        if caster == "player" then
            cc_noexpire = false;
            cc_expire_timer = config.settings.overlay_cc_hanging_time;
        end
    end,
    ["UNIT_SPELLCAST_FAILED"] = function(self, caster, _, spell_id)
        if caster == "player" then
            cc_noexpire = false;
            cc_expire_timer = config.settings.overlay_cc_hanging_time;
        end
    end,
    ["START_AUTOREPEAT_SPELL"] = function(self, arg1, arg2, arg4)
        cc_noexpire = false;
        for _, id in pairs(auto_repeat_spells_tracking) do
            if IsCurrentSpell(id) then
                set_cc_spell(id);
                return;
            end
        end
    end,
};


ccf_parent:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    cc_event_dispatch[event](self, arg1, arg2, arg3);
end);

local function ccf_hook_events(should_hook)
    if should_hook then
        for k, v in pairs(cc_event_dispatch) do
            ccf_parent:RegisterEvent(k);
        end
    else
        for k, v in pairs(cc_event_dispatch) do
            ccf_parent:UnregisterEvent(k);
        end
        cc_noexpire = false;
        cc_expire_timer = 0;
        overlay.cc_f1.icon_frame:Hide();
        overlay.cc_f2.icon_frame:Hide();
    end
end

ccf_hook_events(true);


local active_ccf_labels = {};
local ccfs;

local function update_ccf(frame, spell, info, stats, spell_id)

    if (config.settings.overlay_disable_cc_info or sc.core.mute_overlay) and
        not ccf_parent.config_mode then
        return;
    end
    frame.icon_texture:SetTexture(GetSpellTexture(spell.base_id));

    if ccf_parent.config_mode then
        cc_demo_dummy_fill(info, stats);
    end

    for _, v in pairs(active_ccf_labels) do
        local label = frame.labels[v];
        frame.labels[v]:SetText("");
        local req_flag = overlay_label_handler[label.sel_id].requires_spell_flags;
        if not req_flag or bit.band(spell.flags, req_flag) ~= 0 then

            overlay_label_handler[label.sel_id].func(frame.labels[v], info, stats, spell, spell_id);
        end
    end
    if config.settings.overlay_cc_move_adjacent_on_empty then
        for _, v in pairs(active_ccf_labels) do
            local label_info = ccf_labels[v];
            local adjacent = label_info.adjacent_to;
            if adjacent then
                local p = frame.labels[v]:GetPoint();
                local should_move = frame.labels[v]:GetText() ~= "" and not frame.labels[adjacent[1]]:GetText();

                if label_info.p == p and should_move then
                    local x_1 = config.settings["overlay_cc_"..v.."_x"];
                    local x_2 = config.settings["overlay_cc_"..adjacent[1].."_x"];
                    local y_1 = config.settings["overlay_cc_"..v.."_y"];
                    local y_2 = config.settings["overlay_cc_"..adjacent[1].."_y"];

                    local x_min = math.min(x_1, x_2);
                    local y_min = math.min(y_1, y_2);
                    local x_max = math.max(x_1, x_2);
                    local y_max = math.max(y_1, y_2);
                    local x = math.max(x_min, math.min(x_max, x_1 + x_2));
                    local y = math.max(y_min, math.min(y_max, y_1 + y_2));

                    frame.labels[v]:ClearAllPoints();
                    frame.labels[v]:SetPoint(
                        adjacent[2],
                        frame.icon_frame,
                        adjacent[3],
                        x,
                        y
                    );
                elseif label_info.p ~= p and not should_move then

                    frame.labels[v]:ClearAllPoints();
                    frame.labels[v]:SetPoint(
                        label_info.p,
                        frame.icon_frame,
                        label_info.rel_p,
                        config.settings["overlay_cc_"..v.."_x"],
                        config.settings["overlay_cc_"..v.."_y"]
                    );
                end
            end
        end
    end
end

local function update_cc()

    for _, v in pairs(ccfs) do
        if overlay.cc_active == v then

            local k = v.spell_id;
            local spell = spells[k];
            local info, stats;
            if spells[k] then
                if bit.band(spells[k].flags, spell_flags.eval) ~= 0 then

                    if spells[k].healing_version and config.settings.general_prio_heal then
                        spell = spells[k].healing_version;
                    end

                    info, stats = calc_spell_eval(spell, loadout, effects, eval_flags, k);
                    cast_until_oom(info, spell, stats, loadout, effects, false, 0);
                elseif bit.band(spells[k].flags, spell_flags.only_threat) ~= 0 then
                    info, stats = calc_spell_threat(spell, loadout, effects, eval_flags);
                    info, stats = calc_spell_dummy_cast_until_oom(k, loadout, effects);
                else
                    info, stats = calc_spell_dummy_cast_until_oom(k, loadout, effects);
                end
                update_ccf(v, spell, info, stats, k);
            end

            for fn, cc in pairs(external_ccf_callbacks) do

                cc.data.spell_id = k;
                cc.data.spell = spells[k];

                if info then
                    table_from_schema(cc.info, info, cc.info_schema)

                    cc.data.info = cc.info;
                else
                    cc.data.info = nil;
                end
                if stats then
                    table_from_schema(cc.stats, stats, cc.stats_schema)
                    cc.data.stats = cc.stats;
                else
                    cc.data.stats = nil;
                end

                fn();
            end
        end
    end
end

local function ccf_anim_reconfig()

    for _, v in pairs(ccfs) do
        if config.settings.overlay_cc_horizontal then
            v.icon_frame.anim_new_spell.slide_in:SetDuration(config.settings.overlay_cc_transition_time);
            v.icon_frame.anim_new_spell.slide_in:SetOffset(config.settings.overlay_cc_transition_length, 0);

            v.icon_frame.anim_old_spell.slide_out:SetDuration(config.settings.overlay_cc_transition_time);
            v.icon_frame.anim_old_spell.slide_out:SetOffset(config.settings.overlay_cc_transition_length, 0);

        else
            v.icon_frame.anim_new_spell.slide_in:SetDuration(config.settings.overlay_cc_transition_time);
            v.icon_frame.anim_new_spell.slide_in:SetOffset(0, -config.settings.overlay_cc_transition_length);

            v.icon_frame.anim_old_spell.slide_out:SetDuration(config.settings.overlay_cc_transition_time);
            v.icon_frame.anim_old_spell.slide_out:SetOffset(0, -config.settings.overlay_cc_transition_length);
        end
        v.icon_frame.anim_new_spell.fade_in:SetDuration(config.settings.overlay_cc_transition_time);
        v.icon_frame.anim_new_spell.fade_in:SetFromAlpha(0);
        v.icon_frame.anim_new_spell.fade_in:SetToAlpha(1);

        v.icon_frame.anim_old_spell.fade_out:SetDuration(config.settings.overlay_cc_transition_time);
        v.icon_frame.anim_old_spell.fade_out:SetFromAlpha(1);
        v.icon_frame.anim_old_spell.fade_out:SetToAlpha(0);
    end
end

local function ccf_label_reconfig(label_id)

    local font = sc.ui.get_font(config.settings.overlay_cc_font[1]);
    for _, v in pairs(ccfs) do
        local label = v.labels[label_id];
        label:SetFont(
            font,
            config.settings["overlay_cc_"..label_id.."_fsize"],
            config.settings.overlay_cc_font[2]
        );
        label:ClearAllPoints();
        label:SetPoint(
            ccf_labels[label_id].p,
            v.icon_frame,
            ccf_labels[label_id].rel_p,
            config.settings["overlay_cc_"..label_id.."_x"],
            config.settings["overlay_cc_"..label_id.."_y"]
        );
        label.sel_id = config.settings["overlay_cc_"..label_id.."_selection"];
        label:SetTextColor(effect_color(overlay_label_handler[label.sel_id].color_tag));

        if config.settings["overlay_cc_"..label_id.."_enabled"] then
            active_ccf_labels[label_id] = label_id;
        else
            active_ccf_labels[label_id] = nil;
            label:SetText("");
        end
    end
    if (not config.settings.overlay_disable_cc_info and not sc.core.mute_overlay) or ccf_parent.config_mode then
        update_cc();
    end
end

local function create_ccf()

    local frames = {};

    frames.spell_id = 0;
    frames.labels = {};

    frames.icon_frame = CreateFrame("Frame", nil, ccf_parent);
    frames.icon_frame:SetPoint("CENTER", 0, 0);
    frames.icon_frame:SetSize(32, 32);

    --frames.icon_frame.cooldown_frame = CreateFrame("Cooldown", "$parentCooldown", frames.icon_frame, "CooldownFrameTemplate");
    --frames.icon_frame.cooldown_frame:SetAllPoints(frames.icon_frame)
    --frames.icon_frame.cooldown_frame:SetDrawEdge(true);
    --frames.icon_frame.cooldown_frame:SetSwipeColor(0, 0, 0, 0.7);

    frames.icon_frame.anim_new_spell = frames.icon_frame:CreateAnimationGroup();

    local slide_in = frames.icon_frame.anim_new_spell:CreateAnimation("Translation");
    slide_in:SetSmoothing("OUT");
    frames.icon_frame.anim_new_spell.slide_in = slide_in;

    local fade_in = frames.icon_frame.anim_new_spell:CreateAnimation("Alpha");
    fade_in:SetSmoothing("OUT");
    frames.icon_frame.anim_new_spell:SetScript("OnFinished", function()
        frames.icon_frame.animating = false;
        frames.icon_frame:SetAlpha(1);
        frames.icon_frame:SetPoint("CENTER", 0, 0);
    end);
    frames.icon_frame.anim_new_spell.fade_in = fade_in;

    frames.icon_frame.anim_old_spell = frames.icon_frame:CreateAnimationGroup();

    local slide_out = frames.icon_frame.anim_old_spell:CreateAnimation("Translation");
    slide_out:SetSmoothing("OUT");
    frames.icon_frame.anim_old_spell.slide_out = slide_out;

    local fade_out = frames.icon_frame.anim_old_spell:CreateAnimation("Alpha");
    fade_out:SetSmoothing("OUT");
    frames.icon_frame.anim_old_spell:SetScript("OnFinished", function()
        frames.icon_frame.animating = false;
        frames.icon_frame:SetAlpha(0);
        frames.icon_frame:ClearAllPoints();
        frames.icon_frame:SetPoint("CENTER", 0, 0);
    end);
    frames.icon_frame.anim_old_spell.fade_out = fade_out;

    frames.icon_frame:Hide();
    frames.icon_frame:SetAlpha(0);

    frames.icon_texture = frames.icon_frame:CreateTexture(nil, "ARTWORK");
    frames.icon_texture:SetAllPoints(frames.icon_frame);
    frames.icon_texture:SetTexture("Interface\\Icons\\Spell_Nature_Thorns");

    for k in pairs(ccf_labels) do
        frames.labels[k] = frames.icon_frame:CreateFontString(nil, "OVERLAY");
    end

    return frames;
end

local overlay_effects_update_id = 0;

cc_new_spell = function(spell_id)
    if (config.settings.overlay_disable_cc_info or sc.core.mute_overlay) and
        not ccf_parent.config_mode then
        return;
    end
    if config.settings.overlay_disable or sc.core.mute_overlay or not effects then
        loadout, _, effects = update_loadout_and_effects();
    end

    -- update immediately the current casting frame

    local new, old;
    if overlay.cc_active == overlay.cc_f1 then
        new = overlay.cc_f2;
        old = overlay.cc_f1;
    else
        new = overlay.cc_f1;
        old = overlay.cc_f2;
    end
    new.spell_id = spell_id;

    overlay.cc_active = new;

    update_cc();

    if new.spell_id ~= 0  then
        --local start, duration, enable = GetSpellCooldown(new.spell_id)
        --CooldownFrame_Set(new.icon_frame.cooldown_frame, start, duration, enable)

        new.icon_frame:Show();
    else
        new.icon_frame:Hide();
    end
    if old.spell_id ~= 0  then
        old.icon_frame:Show();
    else
        old.icon_frame:Hide();
    end

    old.icon_frame:SetPoint("CENTER", 0, 0);
    new.icon_frame:SetAlpha(0);
    old.icon_frame:SetAlpha(1);
    new.icon_frame.animating = true;
    old.icon_frame.animating = true;
    if config.settings.overlay_cc_horizontal then
        new.icon_frame:SetPoint("CENTER", -config.settings.overlay_cc_transition_length, 0);
    else
        new.icon_frame:SetPoint("CENTER", 0, config.settings.overlay_cc_transition_length);
    end
    new.icon_frame.anim_new_spell:Play();
    old.icon_frame.anim_old_spell:Play();
end

local function init_ccfs()

    ccf_labels = {
        outside_right_upper = {
            desc = L["Outside: right - upper"],
            p = "BOTTOMLEFT",
            rel_p = "TOPRIGHT",
            adjacent_to = {"outside_right_lower", "LEFT", "RIGHT"}
        },
        outside_right_lower = {
            desc = L["Outside: right - lower"],
            p = "TOPLEFT",
            rel_p = "BOTTOMRIGHT",
            adjacent_to = {"outside_right_upper", "LEFT", "RIGHT"};
        },
        outside_left_upper = {
            desc = L["Outside: left - upper"],
            p = "BOTTOMRIGHT",
            rel_p = "TOPLEFT",
            adjacent_to = {"outside_left_lower", "RIGHT", "LEFT"}
        },
        outside_left_lower = {
            desc = L["Outside: left - lower"],
            p = "TOPRIGHT",
            rel_p = "BOTTOMLEFT",
            adjacent_to = {"outside_left_upper", "RIGHT", "LEFT"}
        },
        outside_top_left = {
            desc = L["Outside: top - left"],
            p = "RIGHT",
            rel_p = "TOP",
            adjacent_to = {"outside_top_right", "CENTER", "TOP"}
        },
        outside_top_right = {
            desc = L["Outside: top - right"],
            p = "LEFT",
            rel_p = "TOP",
            adjacent_to = {"outside_top_left", "CENTER", "TOP"}
        },
        outside_bottom_left = {
            desc = L["Outside: bottom - left"],
            p = "RIGHT",
            rel_p = "BOTTOM",
            adjacent_to = {"outside_bottom_right", "CENTER", "BOTTOM"}
        },
        outside_bottom_right = {
            desc = L["Outside: bottom - right"],
            p = "LEFT",
            rel_p = "BOTTOM",
            adjacent_to = {"outside_bottom_left", "CENTER", "BOTTOM"}
        },
        inside_top = {
            desc = L["Inside: top"],
            p = "TOP",
            rel_p = "TOP",
        },
        inside_bottom = {
            desc = L["Inside: bottom"],
            p = "BOTTOM",
            rel_p = "BOTTOM",
        },
        inside_left = {
            desc = L["Inside: left"],
            p = "LEFT",
            rel_p = "LEFT",
        },
        inside_right = {
            desc = L["Inside: right"],
            p = "RIGHT",
            rel_p = "RIGHT",
        },
    };
    overlay.ccf_labels = ccf_labels;

    overlay.cc_f1 = create_ccf();
    overlay.cc_f2 = create_ccf();

    overlay.cc_active = overlay.cc_f1;

    ccfs = {overlay.cc_f1, overlay.cc_f2};

    border.txt:SetText(L["Currently casting spell info. Move me!"]);
    __sc_frame.overlay_frame:SetScript("OnShow", function()
        ccf_parent.config_mode = true;
        ccf_parent:SetMovable(true);
        ccf_parent:EnableMouse(true);
        ccf_parent.border.flash:Play();
        if __sc_frame:IsShown() and not config.settings.overlay_disable_cc_info then
            ccf_parent.border:Show();
            ccf_parent.border.txt:Show();
            cc_demo();
        else
            ccf_parent.border:Hide();
            ccf_parent.border.txt:Hide();
        end
    end);
    __sc_frame.overlay_frame:SetScript("OnHide", function()
        cc_new_spell(0);
        ccf_parent.border.flash:Stop();
        ccf_parent:SetMovable(false);
        ccf_parent:EnableMouse(false);
        ccf_parent.border.txt:Hide();
        ccf_parent.border:Hide();
        overlay.cc_f1.icon_frame:Hide();
        overlay.cc_f2.icon_frame:Hide();
        ccf_parent.config_mode = false;
    end);
end

local special_action_bar_changed_id = 0;

local function update_spell_icons(loadout, effects, eval_flags)

    if sc.core.update_action_bar_needed then
        update_action_bars();
        sc.core.update_action_bar_needed = false;
    end
    if sc.core.rescan_action_bar_needed then

        active_overlays = {};
        scan_action_frames();
        on_special_action_bar_changed();
        sc.loadouts.force_update = true;
        sc.core.rescan_action_bar_needed = false;
    end

    --NOTE: sometimes the Action buttons 1-12 haven't been updated
    --      to reflect the new action id's for forms that change the action bar
    --      Schedule for this to be executed the next update as well to catch late updates
    if sc.core.special_action_bar_changed then
        on_special_action_bar_changed();
        special_action_bar_changed_id = special_action_bar_changed_id + 1;
        if special_action_bar_changed_id%2 == 0 then
            sc.core.special_action_bar_changed = false;
        end
    end

    if sc.core.old_ranks_checks_needed then

        old_rank_warning_traversal(loadout.lvl);
        sc.core.old_ranks_checks_needed = false;
    end

    -- update spell book icons
    local current_tab = SpellBookFrame.selectedSkillLine;
    local num_spells_in_tab = select(4, GetSpellTabInfo(current_tab));
    local page, page_max = SpellBook_GetCurrentPage(current_tab);
    if SpellBookFrame:IsShown() then

        for k, v in pairs(spell_book_frames) do

            if v.frame then
                for _, ov in pairs(v.overlay_frames) do
                    ov:Hide();
                end
                local spell_name = v.frame.SpellName:GetText();
                local spell_rank_name = v.frame.SpellSubName:GetText();

                local _, _, _, _, _, _, id = GetSpellInfo(spell_name, spell_rank_name);

                local remaining_spells_in_page = 12;
                if page == page_max then
                    remaining_spells_in_page = 1 + (num_spells_in_tab-1)%12;
                end
                local rearranged_k = 1 + 5*(1-k%2) + (k-k%2)/2;

                if id and spells[id] and v.frame:IsShown() and rearranged_k <= remaining_spells_in_page then
                    update_overlay_frame(v, loadout, effects, id, eval_flags);
                end
            end
        end
    end

    -- update action bar icons
    for k, _ in pairs(active_overlays) do
        local v = action_id_frames[k];
        if v.frame and v.frame:IsShown() and spells[v.spell_id] then
            update_overlay_frame(v, loadout, effects, v.spell_id, eval_flags);
        end
    end
    for _, v in pairs(external_overlay_frames) do
        if v.frame and v.frame:IsShown() and spells[v.spell_id] then
            update_overlay_frame(v, loadout, effects, v.spell_id, eval_flags);
        end
    end
end

local function overlay_eval_flags()
    local eval_flags = 0;
    if not config.settings.general_prio_multiplied_effect then
        eval_flags = bit.bor(eval_flags, sc.calc.evaluation_flags.assume_single_effect);
    end
    return eval_flags;
end

local function update_overlay()

    local effects_before, update_id;
    local updated = false;
    local eval_flags = overlay_eval_flags();

    local spells_frame_open = __sc_frame:IsShown() and __sc_frame.spells_frame:IsShown();
    local calc_frame_open = __sc_frame:IsShown() and __sc_frame.calculator_frame:IsShown();

    if not config.settings.overlay_disable and not sc.core.mute_overlay then
        if not calc_frame_open and not config.settings.general_calc_global_compare then

            loadout, _, effects, update_id = update_loadout_and_effects(0.7 / sc.config.settings.overlay_update_freq);

        else
            loadout, _, _, effects_before, effects, update_id =
                update_loadout_and_effects_diffed_from_ui();
        end
        updated = update_id > overlay_effects_update_id;
        overlay_effects_update_id = update_id;
    end

    if updated then
        if calc_frame_open then
            if not config.settings.overlay_disable and not sc.core.mute_overlay then
                sc.ui.update_calc_list(false, loadout, effects_before, effects, eval_flags);
            end
        elseif spells_frame_open then
            if not config.settings.overlay_disable and not sc.core.mute_overlay then
                sc.ui.update_spells_frame(loadout, effects, eval_flags);
            end
        end

        if not config.settings.overlay_disable and not sc.core.mute_overlay then
            update_spell_icons(loadout, effects, eval_flags);
        end

        for feed, feed_data in pairs(sc.spells_feed.external_feeds) do
            if not feed_data.paused then
                sc.spells_feed.external_feed_calc(feed, feed_data, loadout, effects);
                sc.spells_feed.external_feed_calc(feed, feed_data,  loadout, effects);

                if feed_data.callback_fn then
                    feed_data.callback_fn(feed);
                end
            end
        end
    end


    --for k, count in pairs(externally_registered_spells) do
    --    if count > 0 then
    --        cache_spell(spells[k], k, loadout, effects, eval_flags);
    --        if spells[k].healing_version then
    --            cache_spell(spells[k].healing_version, k, loadout, effects, eval_flags);
    --        end
    --    end
    --end

    if not config.settings.overlay_disable_cc_info and not sc.core.mute_overlay then

        if config.settings.overlay_disable or sc.core.mute_overlay then

            -- action bar overlay disabled, need to update loadout
            loadout, _, effects, update_id = update_loadout_and_effects();
            updated = update_id > overlay_effects_update_id;
            overlay_effects_update_id = update_id;
        end
        if updated then
            update_cc();
        end
    end
end

--------------------------------------------------------------------------------
overlay.spell_book_frames                           = spell_book_frames;
overlay.action_id_frames                            = action_id_frames;
overlay.setup_action_bars                           = setup_action_bars;
overlay.update_overlay                              = update_overlay;
overlay.update_icon_overlay_settings                = update_icon_overlay_settings;
overlay.reassign_overlay_icon                       = reassign_overlay_icon;
overlay.clear_overlays                              = clear_overlays;
overlay.old_rank_warning_traversal                  = old_rank_warning_traversal;
overlay.overlay_eval_flags                          = overlay_eval_flags;
overlay.overlay_reconfig                            = overlay_reconfig;
overlay.init_ccfs                                   = init_ccfs;
overlay.cc_new_spell                                = cc_new_spell;
overlay.ccf_parent                                  = ccf_parent;
overlay.spell_tracking                              = spell_tracking;
overlay.ccf_hook_events                             = ccf_hook_events;
overlay.cc_demo                                     = cc_demo;
overlay.ccf_label_reconfig                          = ccf_label_reconfig;
overlay.ccf_anim_reconfig                           = ccf_anim_reconfig;
overlay.init_label_handler                          = init_label_handler;
overlay.register_cc_on_update                       = register_cc_on_update
overlay.unregister_cc_on_update                     = unregister_cc_on_update

sc.overlay = overlay;

