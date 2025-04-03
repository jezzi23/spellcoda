local _, sc = ...;

local spell_cost                                    = sc.utils.spell_cost;
local spell_cast_time                               = sc.utils.spell_cast_time;
local effect_color                                  = sc.utils.effect_color;
local format_number                                 = sc.utils.format_number;
local format_dur                                    = sc.utils.format_dur;

local spells                                        = sc.spells;
local spell_flags                                   = sc.spell_flags;
local highest_learned_rank                          = sc.utils.highest_learned_rank;

local update_loadout_and_effects                    = sc.loadouts.update_loadout_and_effects;
local update_loadout_and_effects_diffed_from_ui     = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local active_loadout                                = sc.loadouts.active_loadout;

local cast_until_oom                                = sc.calc.cast_until_oom;
local calc_spell_eval                               = sc.calc.calc_spell_eval;
local calc_spell_threat                             = sc.calc.calc_spell_threat;
local calc_spell_resource_regen                     = sc.calc.calc_spell_resource_regen;

local config                                        = sc.config;
--------------------------------------------------------------------------------
local overlay = {};

local initialized = false;
local active_overlays = {};
local action_bar_frame_names = {};
local action_id_frames = {};
local spell_book_frames = {};
local action_bar_addon_name = "Default";
local overlay_component_id_to_overlay_slot_idx = {};
local externally_registered_spells = {};
local external_overlay_frames = {};

local mana_cost_overlay, cast_speed_overlay, mana_restoration_overlay, threat_overlay;

sc.ext.register_spell = function(spell_id)
    if spells[spell_id] and bit.band(spell.flags, spell_flags.eval) ~= 0 then
        if not externally_registered_spells[spell_id] then
            externally_registered_spells[spell_id] = 0;
        end
        externally_registered_spells[spell_id] = externally_registered_spells[spell_id] + 1;
    end
end

sc.ext.unregister_spell = function(spell_id)
    if spells[spell_id] and externally_registered_spells[spell_id] then
        externally_registered_spells[spell_id] = math.max(0, externally_registered_spells[spell_id] - 1);
    end
end


local function init_frame_overlay(frame_info)

    local offsets = {-3, -1.5, 0};
    local anchors = {"TOP", "CENTER", "BOTTOM"};

    if not frame_info.overlay_frames then
        frame_info.overlay_frames = {};

        for i = 1, 3 do
            frame_info.overlay_frames[i] = frame_info.frame:CreateFontString(nil, "OVERLAY");
            frame_info.overlay_frames[i]:SetFont(
                config.settings.overlay_font[1], config.settings.overlay_font_size, config.settings.overlay_font[2]);
            frame_info.overlay_frames[i]:SetPoint(anchors[i], config.settings.overlay_offset + 1.0, offsets[i]);
        end
    end
end


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
end

sc.ext.unregister_overlay_frame = function(frame)

    if external_overlay_frames[frame] and external_overlay_frames[frame].overlay_frames then
        for i = 1, 3 do
            external_overlay_frames[frame].overlay_frames[i]:Hide();
        end
    end
    external_overlay_frames[frame] = nil;
end

local function check_old_rank(frame_info, spell_id, clvl)

    local spell = spells[spell_id]
    if not spell then
        return;
    end
    -- spell_id must be valid here
    for i = 1, 3 do
        frame_info.overlay_frames[i]:Hide();
    end
    if not config.settings.overlay_disable and
        config.settings.overlay_old_rank and
        ((config.settings.overlay_old_rank_limit_to_known and spell_id ~= highest_learned_rank(spell.base_id))
         or
         (not config.settings.overlay_old_rank_limit_to_known and clvl > spell.lvl_outdated)) then

        frame_info.overlay_frames[1]:SetText("OLD");
        frame_info.overlay_frames[2]:SetText("RANK");
        frame_info.overlay_frames[3]:SetText("!!!");
        for i = 1, 3 do
            frame_info.overlay_frames[i]:SetTextColor(252.0/255, 69.0/255, 3.0/255);
            frame_info.overlay_frames[i]:Show();
        end
        frame_info.old_rank_marked = true;
    else
        frame_info.old_rank_marked = false;
    end
end

local function old_rank_warning_traversal(clvl)

    if config.settings.overlay_disable then
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

    local offsets = {-3, -1.5, 0};
    local anchors = {"TOP", "CENTER", "BOTTOM"};

    for i = 1, 12 do
        if spell_book_frames[i] then
            for j = 1, 3 do
                spell_book_frames[i].overlay_frames[j]:SetFont(
                config.settings.overlay_font[1], config.settings.overlay_font_size, config.settings.overlay_font[2]);
                spell_book_frames[i].overlay_frames[j]:SetPoint(anchors[j], config.settings.overlay_offset + 1.0, offsets[j]);
            end
        end
    end
    for _, v in pairs(action_id_frames) do
        if v.frame then
            for j = 1, 3 do
                v.overlay_frames[j]:SetFont(
                config.settings.overlay_font[1], config.settings.overlay_font_size, config.settings.overlay_font[2]);
                v.overlay_frames[j]:SetPoint(anchors[j], config.settings.overlay_offset + 1.0, offsets[j]);
            end
        end
    end
    for _, v in pairs(external_overlay_frames) do
        if v.frame then
            for j = 1, 3 do
                v.overlay_frames[j]:SetFont(
                config.settings.overlay_font[1], config.settings.overlay_font_size, config.settings.overlay_font[2]);
                v.overlay_frames[j]:SetPoint(anchors[j], config.settings.overlay_offset + 1.0, offsets[j]);
            end
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
    if action_bar_addon_name == "Default" then
        return button.action;
    else
        -- Dominos seems to set GetAttribute function for the 1-6 default blizz bars
        return button:GetAttribute("action");
    end
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
        (mana_cost_overlay and not spell_cost(spell_id)) and
        (cast_speed_overlay and not spell_cast_time(spell_id)) and
        (mana_restoration_overlay and bit.band(spells[spell_id].flags, spell_flags.resource_regen) == 0) and
        (threat_overlay and bit.band(spells[spell_id].flags, spell_flags.threat_only) == 0) then
        spell_id = 0;
    end

    return spell_id;
end

local function try_register_frame(action_id, frame_name)
    -- creates it if it suddenly exists but not registered
    local frame = _G[frame_name];
    if frame then
        action_id_frames[action_id].frame = frame;
        local spell_id = spell_id_of_action(action_id);
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

        if not action_id_frames[action_id] then
            action_id_frames[action_id] = {};

            local button_frame = _G[v];
            if button_frame then
                button_frame:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);
            end
        end
        try_register_frame(action_id, v);
    end
end

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
    local index = 1;
    if IsAddOnLoaded("Bartender4") then -- check for some common addons if they overrite spellbook frames

        for i = 1, 120 do
            action_bar_frame_names[i] = "BT4Button"..i;
        end
        action_bar_addon_name = "Bartender4";

    elseif IsAddOnLoaded("ElvUI") then -- check for some common addons if they overrite spellbook frames

        for i = 1, 10 do
            for j = 1, 12 do
                action_bar_frame_names[index] = 
                    "ElvUI_Bar"..i.."Button"..j;

                index = index + 1;
            end
        end
        action_bar_addon_name = "ElvUI";

    elseif IsAddOnLoaded("Dominos") then -- check for some common addons if they overrite spellbook frames

        local bars = {
            "ActionButton", "DominosActionButton", "MultiBarRightButton",
            "MultiBarLeftButton", "MultiBarBottomRightButton", "MultiBarBottomLeftButton"
        };
        for k, v in pairs(bars) do
            for j = 1, 12 do
                action_bar_frame_names[index] = v..j;

                index = index + 1;
            end
        end

        for i = index, 120 do
            action_bar_frame_names[i] = "DominosActionButton"..i;
        end
        for i = 13, 24 do
            action_bar_frame_names[i] = "DominosActionButton"..i;
        end
        action_bar_addon_name = "Dominos";

    else -- default action bars

        local bars = {
            "ActionButton", "BonusActionButton", "MultiBarRightButton",
            "MultiBarLeftButton", "MultiBarBottomRightButton", "MultiBarBottomLeftButton"
        };
        index = 1;
        for k, v in pairs(bars) do
            for j = 1, 12 do
                action_bar_frame_names[index] = v..j;

                index = index + 1;
            end
        end
        action_bar_addon_name = "Default";
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
        action_id_frames[action_id].spell_id = spell_id;
    end
end

local function reassign_overlay_icon(action_id)

    --action_id might not have a named frame (e.g. blizzard bars) at high IDs
    --but still be mirrored to named frames 1-12
    if action_id > 120 or action_id <= 0 then
        return;
    end
    if action_bar_frame_names[action_id] then
        try_register_frame(action_id, action_bar_frame_names[action_id]);
    end

    local spell_id = spell_id_of_action(action_id);

    -- NOTE: any action_id > 12 we might have mirrored action ids
    -- with Bar 1 due to shapeshifts, and forms taking over Bar 1
    -- so check if the action slot in bar 1 is the same
    if action_id > 12 then
        local mirrored_bar_id = (action_id-1)%12 + 1;
        local mirrored_action = action_id_frames[mirrored_bar_id];
        if mirrored_action then
            local mirrored_action_id = action_id_of_button(mirrored_action.frame);
            if mirrored_action_id and mirrored_action_id == action_id then
                -- was mirrored, update that as well
                reassign_overlay_icon_spell(mirrored_bar_id, spell_id)
            end
        end
    end

    if action_bar_frame_names[action_id] then
        local button_frame = action_id_frames[action_id].frame;
        if button_frame then
            reassign_overlay_icon_spell(action_id, spell_id)
        end
    end
end

local function on_special_action_bar_changed()

    for i = 1, 12 do

        -- Hopefully the Actionbar host has updated the new action id of its 1-12 action id bar
        local frame = action_id_frames[i].frame;
        if frame then

            local action_id = action_id_of_button(frame);

            local spell_id = 0;
            if action_id then
                spell_id = spell_id_of_action(action_id);
            end
            --if spell_id ~= 0 then
            --    active_overlays[i] = spell_id;
            --    --check_old_rank(action_id_frames[action_id], spell_id, active_loadout().lvl);
            --else
            --    active_overlays[i] = nil;
            --end
            reassign_overlay_icon_spell(i, spell_id);
        end
    end
end

local function update_icon_overlay_settings()

    mana_cost_overlay = config.settings.overlay_display_avg_cost or config.settings.overlay_display_casts_until_oom or config.settings.overlay_display_time_until_oom;
    cast_speed_overlay = config.settings.overlay_display_avg_cast;
    mana_restoration_overlay = config.settings.overlay_resource_regen;
    threat_overlay = config.settings.overlay_display_threat or config.settings.overlay_display_threat_per_sec or config.settings.overlay_display_threat_per_cost;

    __sc_frame.overlay_frame.icon_overlay = {};

    local index = 1;

    for k, v in pairs(__sc_frame.overlay_frame.overlay_components) do
        if config.settings[k] then
            __sc_frame.overlay_frame.icon_overlay[index] = {
                label_type = k,
                color = v.color,
                optional_evaluation = v.optional_evaluation,
            };
            index = index + 1;
        end
    end

    -- if 1, do bottom
    if not __sc_frame.overlay_frame.icon_overlay[2] then
        __sc_frame.overlay_frame.icon_overlay[3] = __sc_frame.overlay_frame.icon_overlay[1];
        __sc_frame.overlay_frame.icon_overlay[1] = nil;
    -- if 2, do top and bottom
    elseif not __sc_frame.overlay_frame.icon_overlay[3] then
        __sc_frame.overlay_frame.icon_overlay[3] = __sc_frame.overlay_frame.icon_overlay[2];
        __sc_frame.overlay_frame.icon_overlay[2] = nil;
    end

    if config.settings.overlay_icon_bottom_clearance then
        __sc_frame.overlay_frame.icon_overlay[2] = __sc_frame.overlay_frame.icon_overlay[1];
        __sc_frame.overlay_frame.icon_overlay[1] = __sc_frame.overlay_frame.icon_overlay[3];
        __sc_frame.overlay_frame.icon_overlay[3] = nil;
    end

    if config.settings.overlay_icon_top_clearance then
        if config.settings.overlay_icon_bottom_clearance then
            __sc_frame.overlay_frame.icon_overlay[2] = __sc_frame.overlay_frame.icon_overlay[1];
        else
            __sc_frame.overlay_frame.icon_overlay[3] = __sc_frame.overlay_frame.icon_overlay[3] or __sc_frame.overlay_frame.icon_overlay[1];
            __sc_frame.overlay_frame.icon_overlay[2] = __sc_frame.overlay_frame.icon_overlay[2] or __sc_frame.overlay_frame.icon_overlay[1];
        end
        __sc_frame.overlay_frame.icon_overlay[1] = nil;
    end

    --sw_num_icon_overlay_fields_active = index - 1;

    -- hide existing overlay frames that should no longer exist
    for _, v in pairs(spell_book_frames) do
        if v.overlay_frames then
            for i = 1, 3 do
                if not __sc_frame.overlay_frame.icon_overlay[i] then
                    v.overlay_frames[i]:Hide();
                end
            end
        end
    end
    for _, v in pairs(action_id_frames) do
        if v.frame then
            for i = 1, 3 do
                if not __sc_frame.overlay_frame.icon_overlay[i] then
                    v.overlay_frames[i]:Hide();
                end
            end
        end
    end
    for _, v in pairs(external_overlay_frames) do
        if v.frame then
            for i = 1, 3 do
                if not __sc_frame.overlay_frame.icon_overlay[i] then
                    v.overlay_frames[i]:Hide();
                end
            end
        end
    end
    -- for only_threat spells, find the indices of these for eval spells so that
    -- the numbers are in the same place

    overlay_component_id_to_overlay_slot_idx = {};
    for i, v in pairs( __sc_frame.overlay_frame.icon_overlay) do
        for id, _ in pairs(__sc_frame.overlay_frame.overlay_components) do
            if id == v.label_type then
                overlay_component_id_to_overlay_slot_idx[id] = i;
                break;
            end
        end
    end

    active_overlays = {};
    scan_action_frames();
    on_special_action_bar_changed();
    initialized = true;
end

local function setup_action_bars()
    gather_spell_icons();
    update_icon_overlay_settings();
end
local function update_action_bars()
    update_icon_overlay_settings();
end

local spell_cache = {};

local overlay_label_handler = {
    overlay_display_normal = function(frame_overlay, info)
        local val = 0.0;
        if info.num_direct_effects > 0 then
            val = val + 0.5*(info.total_min_noncrit_if_hit + info.total_max_noncrit_if_hit);
        end
        if info.num_periodic_effects > 0 then
            val = val + 0.5*(info.total_ot_min_noncrit_if_hit + info.total_ot_max_noncrit_if_hit);
        end
        frame_overlay:SetText(format_number(val, 1));
    end,
    overlay_display_crit = function(frame_overlay, info, _, stats)
        local crit_sum = 0;

        if info.num_direct_effects > 0 then
            crit_sum = crit_sum + 0.5*(info.total_min_crit_if_hit + info.total_max_crit_if_hit);
        end
        if info.num_periodic_effects > 0 then
            crit_sum = crit_sum + 0.5*(info.total_ot_min_crit_if_hit + info.total_ot_max_crit_if_hit);
        end
        if stats.crit > 0 and crit_sum > 0 then
            frame_overlay:SetText(format_number(crit_sum, 1));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_expected = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.expected, 1));
    end,
    overlay_display_effect_per_sec = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.effect_per_sec, 1));
    end,
    overlay_display_effect_per_cost = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.effect_per_cost, 2));
    end,
    overlay_display_threat = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.threat, 1));
    end,
    overlay_display_threat_per_sec = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.threat_per_sec, 1));
    end,
    overlay_display_threat_per_cost = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.threat_per_cost, 2));
    end,
    overlay_display_avg_cost = function(frame_overlay, _, _, stats)
        if stats.cost >= 0 then
            frame_overlay:SetText(string.format("%.1f", stats.cost));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_actual_cost = function(frame_overlay, _, _, stats)
        if stats.cost >= 0 then
            frame_overlay:SetText(string.format("%.0f", stats.cost));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_avg_cast = function(frame_overlay, _, _, stats)
        if stats.cast_time > 0 then
            frame_overlay:SetText(format_number(stats.cast_time, 2));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_actual_cast = function(frame_overlay, _, _, stats)
        if stats.cast_time > 0 then
            frame_overlay:SetText(format_number(stats.cast_time, 2));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_hit_chance = function(frame_overlay, _, spell, stats)
         if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
            frame_overlay:SetText(string.format("%d%%", 100*stats.hit));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_crit_chance = function(frame_overlay, info, _, stats)

        if stats.crit ~= 0 and info.total_ot_min_crit_if_hit + info.total_min_crit_if_hit > 0 then
            frame_overlay:SetText(string.format("%.1f%%", 100*max(0, min(1, stats.crit))));
        else
            frame_overlay:SetText("");
        end
    end,
    overlay_display_casts_until_oom = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.num_casts_until_oom, 1));
    end,
    overlay_display_effect_until_oom = function(frame_overlay, info)
        frame_overlay:SetText(format_number(info.effect_until_oom, 0));
    end,
    overlay_display_time_until_oom = function(frame_overlay, info)
        frame_overlay:SetText(format_dur(info.time_until_oom));
    end,
};

local only_threat_label_types = {
    "overlay_display_threat",
    "overlay_display_threat_per_sec",
    "overlay_display_threat_per_cost"
};

local function update_spell_icon_frame(frame_info, spell, spell_id, loadout, effects, eval_flags)

    if bit.band(spell.flags, spell_flags.resource_regen) ~= 0 and
        config.settings.overlay_resource_regen then
        local spell_effect = calc_spell_resource_regen(spell, spell_id, loadout, effects, eval_flags);

        for i = 1, 3 do
            frame_info.overlay_frames[i]:Hide();
        end
        local idx = 3;
        if config.settings.overlay_icon_bottom_clearance and config.settings.overlay_icon_top_clearance then
            idx = 2;
        elseif config.settings.overlay_icon_bottom_clearance then
            idx = 1;
        end
        frame_info.overlay_frames[idx]:SetText(string.format("%.0f", math.ceil(spell_effect.total_restored)));
        frame_info.overlay_frames[idx]:SetTextColor(effect_color("avg_cost"));
        frame_info.overlay_frames[idx]:Show();

    elseif __sc_frame.overlay_frame.num_overlay_components_toggled > 0 then 
        local spell_effect, stats;

        if bit.band(spell.flags, spell_flags.eval) ~= 0 then
            spell_effect, stats = calc_spell_eval(spell, loadout, effects, eval_flags, spell_id);
            cast_until_oom(spell_effect, spell, stats, loadout, effects);

            for i = 1, 3 do
                if __sc_frame.overlay_frame.icon_overlay[i] then

                    overlay_label_handler[__sc_frame.overlay_frame.icon_overlay[i].label_type](
                        frame_info.overlay_frames[i],
                        spell_effect,
                        spell,
                        stats
                     );

                    frame_info.overlay_frames[i]:SetTextColor(__sc_frame.overlay_frame.icon_overlay[i].color[1],
                                                              __sc_frame.overlay_frame.icon_overlay[i].color[2],
                                                              __sc_frame.overlay_frame.icon_overlay[i].color[3]);

                    frame_info.overlay_frames[i]:Show();
                end
            end

        elseif bit.band(spell.flags, spell_flags.only_threat) ~= 0 and threat_overlay then
            spell_effect, stats = calc_spell_threat(spell, loadout, effects, eval_flags);

            for _, id in pairs(only_threat_label_types) do
                local idx = overlay_component_id_to_overlay_slot_idx[id];
                if idx then
                    overlay_label_handler[id](
                        frame_info.overlay_frames[idx],
                        spell_effect,
                        spell,
                        stats
                     );

                    frame_info.overlay_frames[idx]:SetTextColor(__sc_frame.overlay_frame.icon_overlay[idx].color[1],
                                                                __sc_frame.overlay_frame.icon_overlay[idx].color[2],
                                                                __sc_frame.overlay_frame.icon_overlay[idx].color[3]);

                    frame_info.overlay_frames[idx]:Show();
                end
            end
        end

    end
end

-- for spells that are not evaluated but cast time & mana cost can be extracted from lua api
-- to be displayed as overlays
local function update_non_evaluated_spell(frame_info, spell_id, loadout, effects)

    local cost, resource_name = spell_cost(spell_id);
    if not cost then
        cost = -1.0;
    end
    local cast_time = spell_cast_time(spell_id) or -1.0;

    if not spell_cache[spell_id] then
        spell_cache[spell_id] = {};
        spell_cache[spell_id].dmg = {};
    end
    local spell_variant = spell_cache[spell_id].dmg;
    --if not spell_cache[spell_id].seq then
    if not spell_variant.seq then

        spell_variant.seq = -1;
        spell_variant.stats = {};
        spell_variant.spell_effect = {};
    end
    local spell_effect = spell_variant.spell_effect;
    local stats = spell_variant.stats;

    if spell_variant.seq ~= sc.sequence_counter then
        spell_variant.seq = sc.sequence_counter;
        -- fill dummy stats
        stats.cost = cost;
        stats.cast_time = cast_time;
        stats.regen_while_casting = effects.raw.regen_while_casting;
        spell_effect.cost_per_sec = cost/cast_time;
        spell_effect.expected = 0
        if not spells[spell_id] or resource_name ~= "MANA" then
            stats.cast_time = 0.0;
            spell_effect.time_until_oom = nil;
            spell_effect.num_casts_until_oom = nil;
        else
            cast_until_oom(spell_effect, spells[spell_id], stats, loadout, effects);
        end
    end

    if __sc_frame.overlay_frame.num_overlay_components_toggled > 0 then
        for i = 1, 3 do
            if __sc_frame.overlay_frame.icon_overlay[i] and __sc_frame.overlay_frame.icon_overlay[i].optional_evaluation then

                overlay_label_handler[__sc_frame.overlay_frame.icon_overlay[i].label_type](
                    frame_info.overlay_frames[i],
                    spell_effect,
                    spell,
                    stats
                );

                frame_info.overlay_frames[i]:SetTextColor(__sc_frame.overlay_frame.icon_overlay[i].color[1],
                                                          __sc_frame.overlay_frame.icon_overlay[i].color[2],
                                                          __sc_frame.overlay_frame.icon_overlay[i].color[3]);

                frame_info.overlay_frames[i]:Show();
            end
        end
    end
end

local function update_overlay_frame(frame, loadout, effects, id, eval_flags)

    if frame.old_rank_marked then
        return;
    end
    if bit.band(spells[id].flags, bit.bor(spell_flags.eval, spell_flags.resource_regen, spell_flags.only_threat)) ~= 0 then
        -- TODO: icon overlay not working for healing version checkbox
        if spells[id].healing_version and config.settings.general_prio_heal then
            update_spell_icon_frame(frame, spells[id].healing_version, id, loadout, effects, eval_flags);
        else
            update_spell_icon_frame(frame, spells[id], id, loadout, effects, eval_flags);
        end
    end
end

local currently_casting_frame_parent = CreateFrame("Frame", nil, UIParent);
currently_casting_frame_parent:RegisterForDrag("LeftButton");
currently_casting_frame_parent:SetSize(250, 100);
currently_casting_frame_parent:SetScript("OnDragStart", currently_casting_frame_parent.StartMoving);
currently_casting_frame_parent:SetScript("OnDragStop", function(self)
    currently_casting_frame_parent:StopMovingOrSizing();
    local region, _, _, x, y = self:GetPoint()
    config.settings.overlay_currently_casting_info_region = region;
    config.settings.overlay_currently_casting_info_x = x;
    config.settings.overlay_currently_casting_info_y = y;
end);
currently_casting_frame_parent.config_mode = false;
currently_casting_frame_parent:Show();

local border = CreateFrame("Frame", nil, currently_casting_frame_parent, "BackdropTemplate");
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

border.disabled_txt = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
border.disabled_txt:SetPoint("TOP", 0, -10);
border.disabled_txt:SetText("DISABLED: Currently casting spell info");

currently_casting_frame_parent.border = border;

local function create_currently_casting_frame()

    local frames = {};

    frames.spell_id = 0;
    frames.txts = {};  -- Table to hold all fontstrings

    frames.icon_frame = CreateFrame("Frame", nil, currently_casting_frame_parent);
    frames.icon_frame:SetPoint("CENTER", 0, 0);
    -- Create animation group for the transition
    frames.icon_frame.anim_new_spell_vertical = frames.icon_frame:CreateAnimationGroup();
    frames.icon_frame.anim_new_spell_horiz = frames.icon_frame:CreateAnimationGroup();
    frames.icon_frame.slide_offset = 100;
    frames.icon_frame.slide_dur = 0.3;

    local make_alpha_anim_fade_in = function(anim_group)
        local fade_in = anim_group:CreateAnimation("Alpha");
        fade_in:SetDuration(frames.icon_frame.slide_dur);
        fade_in:SetFromAlpha(0);
        fade_in:SetToAlpha(1);
        fade_in:SetSmoothing("OUT");
        anim_group:SetScript("OnFinished", function()
            frames.icon_frame.animating = false;
            frames.icon_frame:SetAlpha(1);
            frames.icon_frame:SetPoint("CENTER", 0, 0);
        end);
    end;
    local make_alpha_anim_fade_out = function(anim_group)
        local fade_out = anim_group:CreateAnimation("Alpha");
        fade_out:SetDuration(frames.icon_frame.slide_dur);
        fade_out:SetFromAlpha(1);
        fade_out:SetToAlpha(0);
        fade_out:SetSmoothing("OUT");
        anim_group:SetScript("OnFinished", function()
            frames.icon_frame.animating = false;
            frames.icon_frame:SetAlpha(0);
            frames.icon_frame:ClearAllPoints();
            frames.icon_frame:SetPoint("CENTER", 0, 0);
        end);

    end;

    local slide_in_v = frames.icon_frame.anim_new_spell_vertical:CreateAnimation("Translation");
    slide_in_v:SetDuration(frames.icon_frame.slide_dur);
    slide_in_v:SetOffset(0, -frames.icon_frame.slide_offset);
    slide_in_v:SetSmoothing("OUT");

    local slide_in_h = frames.icon_frame.anim_new_spell_horiz:CreateAnimation("Translation");
    slide_in_h:SetDuration(frames.icon_frame.slide_dur);
    slide_in_h:SetOffset(frames.icon_frame.slide_offset, 0);
    slide_in_h:SetSmoothing("OUT");

    make_alpha_anim_fade_in(frames.icon_frame.anim_new_spell_vertical);
    make_alpha_anim_fade_in(frames.icon_frame.anim_new_spell_horiz);

    frames.icon_frame.anim_old_spell_vertical = frames.icon_frame:CreateAnimationGroup();
    frames.icon_frame.anim_old_spell_horiz = frames.icon_frame:CreateAnimationGroup();

    local slide_out_v = frames.icon_frame.anim_old_spell_vertical:CreateAnimation("Translation");
    slide_out_v:SetDuration(frames.icon_frame.slide_dur);
    slide_out_v:SetOffset(0, -frames.icon_frame.slide_offset);
    slide_out_v:SetSmoothing("OUT");

    local slide_out_h = frames.icon_frame.anim_old_spell_horiz:CreateAnimation("Translation");
    slide_out_h:SetDuration(frames.icon_frame.slide_dur);
    slide_out_h:SetOffset(frames.icon_frame.slide_offset, 0);
    slide_out_h:SetSmoothing("OUT");

    make_alpha_anim_fade_out(frames.icon_frame.anim_old_spell_vertical);
    make_alpha_anim_fade_out(frames.icon_frame.anim_old_spell_horiz);

    frames.icon_frame:Hide();
    frames.icon_frame:SetAlpha(0);

    frames.icon_frame:SetSize(32, 32);

    frames.icon_texture = frames.icon_frame:CreateTexture(nil, "ARTWORK");
    frames.icon_texture:SetAllPoints(frames.icon_frame);
    frames.icon_texture:SetTexture("Interface\\Icons\\Spell_Nature_Thorns");

    frames.txts.right_top_text = frames.icon_frame:CreateFontString(nil, "OVERLAY");
    frames.txts.right_top_text.size = 13;
    frames.txts.right_top_text:SetPoint("BOTTOMLEFT", frames.icon_frame, "TOPRIGHT", 0, -15);
    frames.txts.right_top_text:SetTextColor(effect_color("normal"));

    frames.txts.right_bottom_text = frames.icon_frame:CreateFontString(nil, "OVERLAY");
    frames.txts.right_bottom_text.size = 13;
    frames.txts.right_bottom_text:SetPoint("TOPLEFT", frames.icon_frame, "BOTTOMRIGHT", 0, 15);
    frames.txts.right_bottom_text:SetTextColor(effect_color("crit"));

    frames.txts.left_top_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.left_top_text.size = 13;
    frames.txts.left_top_text:SetPoint("BOTTOMRIGHT", frames.icon_frame, "TOPLEFT", 0, -15);
    frames.txts.left_top_text:SetTextColor(effect_color("normal"));

    frames.txts.left_bottom_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.left_bottom_text.size = 13;
    frames.txts.left_bottom_text:SetPoint("TOPRIGHT", frames.icon_frame, "BOTTOMLEFT", 0, 15);
    frames.txts.left_bottom_text:SetTextColor(effect_color("crit"));

    frames.txts.inside_top_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.inside_top_text.size = 7;
    frames.txts.inside_top_text:SetPoint("TOP", frames.icon_frame, "TOP", 0, 0);
    frames.txts.inside_top_text:SetTextColor(effect_color("normal"));

    frames.txts.inside_bottom_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.inside_bottom_text.size = 7;
    frames.txts.inside_bottom_text:SetPoint("BOTTOM", frames.icon_frame, "BOTTOM", 0, 0);
    frames.txts.inside_bottom_text:SetTextColor(effect_color("crit"));

    frames.txts.inside_left_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.inside_left_text.size = 9;
    frames.txts.inside_left_text:SetPoint("LEFT", frames.icon_frame, "LEFT", 2, 0);
    frames.txts.inside_left_text:SetTextColor(effect_color("spell_rank"));

    frames.txts.top_right_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.top_right_text.size = 9;
    frames.txts.top_right_text:SetPoint("LEFT", frames.icon_frame, "TOP", 2, 4);
    frames.txts.top_right_text:SetTextColor(effect_color("effect_per_sec"));

    frames.txts.top_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.top_text.size = 9;
    frames.txts.top_text:SetPoint("CENTER", frames.icon_frame, "TOP", 0, 4);
    frames.txts.top_text:SetTextColor(effect_color("effect_per_sec"));

    frames.txts.top_left_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.top_left_text.size = 9;
    frames.txts.top_left_text:SetPoint("RIGHT", frames.icon_frame, "TOP", -2, 4);
    frames.txts.top_left_text:SetTextColor(effect_color("avoidance_info"));

    frames.txts.bottom_right_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.bottom_right_text.size = 9;
    frames.txts.bottom_right_text:SetPoint("LEFT", frames.icon_frame, "BOTTOM", 2, -4);
    frames.txts.bottom_right_text:SetTextColor(effect_color("effect_per_cost"));

    frames.txts.bottom_left_text = frames.icon_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frames.txts.bottom_left_text.size = 9;
    frames.txts.bottom_left_text:SetPoint("RIGHT", frames.icon_frame, "BOTTOM", -2, -4);
    frames.txts.bottom_left_text:SetTextColor(effect_color("time_until_oom"));

    return frames;
end

local currently_casting_frames;

local function currently_casting_config_mode_spell_id()

    if sc.class == sc.classes.mage then
        return sc.spids.fireball;
    elseif sc.class == sc.classes.druid then
        return sc.spids.regrowth;
    elseif sc.class == sc.classes.priest then
        return sc.spids.holy_fire;
    elseif sc.class == sc.classes.shaman then
        return sc.spids.flame_shock;
    elseif sc.class == sc.classes.warlock then
        return sc.spids.immolate;
    elseif sc.class == sc.classes.rogue then
        return sc.spids.sinister_strike;
    elseif sc.class == sc.classes.paladin then
        return sc.spids.holy_light;
    elseif sc.class == sc.classes.warrior then
        return sc.spids.overpower;
    elseif sc.class == sc.classes.hunter then
        return sc.spids.aimed_shot;
    end
    return sc.auto_attack_spell_id;
end

local overlay_effects_update_id = 0;
local loadout, effects;

local function update_currently_casting_frame(frame, spell, info, stats)

    if config.settings.overlay_disable_currently_casting_info and
        not currently_casting_frame_parent.config_mode then
        return;
    end
    frame.icon_texture:SetTexture(GetSpellTexture(spell.base_id));
    local texts = frame.txts;

    if bit.band(spell.flags, spell_flags.eval) == 0 then
        for _, v in pairs(texts) do
            v:SetText("");
        end

        if spell.rank > 0 then
            texts.inside_left_text:SetText(tostring(spell.rank));
        else
            texts.inside_left_text:SetText("");
        end
        return;
    end

    local crit_p;
    local normal_hit_p;
    local dr_p;
    if spell.periodic then
        crit_p = info.ot_crit1;
        normal_hit_p = info.ot_hit_normal1;
        if spell.periodic.school1 == sc.schools.physical then
            dr_p = stats.armor_dr_ot;
        else
            dr_p = stats.target_avg_resi_ot;
        end

        if info.ot_min_noncrit_if_hit1 ~= info.ot_max_noncrit_if_hit1 then
            texts.left_top_text:SetText(string.format("%.0f x %.0f-%.0f",
                info.ot_ticks1, info.ot_min_noncrit_if_hit1/info.ot_ticks1, info.ot_max_noncrit_if_hit1/info.ot_ticks1)
            );
        else
            texts.left_top_text:SetText(string.format("%.0f x %.1f",
                info.ot_ticks1, info.ot_min_noncrit_if_hit1/info.ot_ticks1)
            );
        end
        if crit_p ~= 0 then
            if info.ot_min_crit_if_hit1 ~= info.ot_max_crit_if_hit1 then
                texts.left_bottom_text:SetText(string.format("%.0f x %.0f-%.0f",
                    info.ot_ticks1, info.ot_min_crit_if_hit1/info.ot_ticks1, info.ot_max_crit_if_hit1/info.ot_ticks1)
                );
            else
                texts.left_bottom_text:SetText(string.format("%.0f x %.1f",
                    info.ot_ticks1, info.ot_min_crit_if_hit1/info.ot_ticks1)
                );
            end
        else
            texts.left_bottom_text:SetText("");
        end
    else
        texts.left_top_text:SetText("");
        texts.left_bottom_text:SetText("");
    end
    if spell.direct then
        crit_p = info.crit1;
        normal_hit_p = info.hit_normal1;
        if spell.direct.school1 == sc.schools.physical then
            dr_p = stats.armor_dr_ot;
        else
            dr_p = stats.target_avg_resi_ot;
        end

        if info.min_noncrit_if_hit1 ~= info.max_noncrit_if_hit1 then
            texts.right_top_text:SetText(string.format("%.0f-%.0f",
                info.min_noncrit_if_hit1, info.max_noncrit_if_hit1)
            );
        else
            texts.right_top_text:SetText(string.format("%.1f",
                info.min_noncrit_if_hit1)
            );
        end
        if crit_p ~= 0 then
            if info.min_crit_if_hit1 ~= info.max_crit_if_hit1 then
                texts.right_bottom_text:SetText(string.format("%.0f-%.0f",
                    info.min_crit_if_hit1, info.max_crit_if_hit1)
                );
            else
                texts.right_bottom_text:SetText(string.format("%.1f",
                    info.min_crit_if_hit1)
                );
            end
        else
            texts.right_bottom_text:SetText("");
        end
    else
        texts.right_top_text:SetText("");
        texts.right_bottom_text:SetText("");
    end

    if normal_hit_p ~= 1 then
        texts.inside_top_text:SetText(string.format("%.1f%%", 100*normal_hit_p));
    else
        texts.inside_top_text:SetText("");
    end
    if crit_p ~= 0 then
        texts.inside_bottom_text:SetText(string.format("%.1f%%", 100*crit_p));
    else
        texts.inside_bottom_text:SetText("");
    end

    if dr_p ~= 0 then
        texts.top_text:SetText("");
        texts.top_left_text:SetText(string.format("%.1f%%", 100*dr_p));
        texts.top_right_text:SetText(format_number(info.effect_per_sec, 1));
    else
        texts.top_left_text:SetText("");
        texts.top_right_text:SetText("");
        texts.top_text:SetText(format_number(info.effect_per_sec, 1));
    end

    texts.bottom_left_text:SetText(format_dur(info.time_until_oom));
    texts.bottom_right_text:SetText(format_number(info.effect_per_cost, 2));
end

local function update_currently_casting()

    for _, v in pairs(currently_casting_frames) do

        local k = v.spell_id;
        if spells[k] then

            local spell = spells[k];
            local info, stats;
            if bit.band(spells[k].flags, spell_flags.eval) ~= 0 then

                if spells[k].healing_version and config.settings.general_prio_heal then
                    spell = spells[k].healing_version;
                end

                info, stats = calc_spell_eval(spell, loadout, effects, eval_flags, k);
                cast_until_oom(info, spell, stats, loadout, effects);
            end
            update_currently_casting_frame(v, spell, info, stats);
            v.icon_frame:Show();
        else
            v.icon_frame:Hide();
        end
    end
end

local function currently_casting_new_spell(spell_id)
    if config.settings.overlay_disable_currently_casting_info and
        not currently_casting_frame_parent.config_mode then

        return;
    end
    if config.settings.overlay_disable then
        loadout, _, effects = update_loadout_and_effects();
    end

    -- update immediately the current casting frame

    local new, old;
    if overlay.currently_casting_active == overlay.currently_casting_f1 then
        new = overlay.currently_casting_f2;
        old = overlay.currently_casting_f1;
    else
        new = overlay.currently_casting_f1;
        old = overlay.currently_casting_f2;
    end

    new.spell_id = spell_id;

    update_currently_casting();


    old.icon_frame:SetPoint("CENTER", 0, 0);
    new.icon_frame:SetAlpha(0);
    old.icon_frame:SetAlpha(1);
    new.icon_frame.animating = true;
    old.icon_frame.animating = true;
    if config.settings.overlay_currently_casting_horizontal then
        new.icon_frame:SetPoint("CENTER", -new.icon_frame.slide_offset, 0);

        new.icon_frame.anim_new_spell_horiz:Play();
        old.icon_frame.anim_old_spell_horiz:Play();
    else
        new.icon_frame:SetPoint("CENTER", 0, new.icon_frame.slide_offset);

        new.icon_frame.anim_new_spell_vertical:Play();
        old.icon_frame.anim_old_spell_vertical:Play();
    end

    if new.spell_id ~= 0  then
        new.icon_frame:Show();
    end
    if old.spell_id ~= 0  then
        old.icon_frame:Show();
    end
    overlay.currently_casting_active = new;
end

local function set_currently_casting_frames_font()
    for _, v in pairs(currently_casting_frames) do
        for _, text in pairs(v.txts) do
            text:SetFont(
                config.settings.overlay_currently_casting_font[1],
                text.size,
                config.settings.overlay_currently_casting_font[2]
            );
        end

        
    end
end

local function init_currently_casting_frames()
    overlay.currently_casting_f1 = create_currently_casting_frame();
    overlay.currently_casting_f2 = create_currently_casting_frame();

    overlay.currently_casting_active = overlay.currently_casting_f1;

    currently_casting_frames = {overlay.currently_casting_f1, overlay.currently_casting_f2};

    __sc_frame.overlay_frame:SetScript("OnShow", function()
        currently_casting_frame_parent.config_mode = true;
        currently_casting_frame_parent.border:Show();
        if config.settings.overlay_disable_currently_casting_info then
            currently_casting_frame_parent.border.disabled_txt:Show();
        else
            currently_casting_frame_parent.border.disabled_txt:Hide();
        end
        currently_casting_frame_parent.border:Show();
        currently_casting_frame_parent.border.flash:Play();
        currently_casting_frame_parent:SetMovable(true);
        currently_casting_frame_parent:EnableMouse(true);
        currently_casting_new_spell(currently_casting_config_mode_spell_id());
    end);
    __sc_frame.overlay_frame:SetScript("OnHide", function()
        currently_casting_new_spell(0);
        currently_casting_frame_parent.border.flash:Stop();
        currently_casting_frame_parent:SetMovable(false);
        currently_casting_frame_parent:EnableMouse(false);
        currently_casting_frame_parent.border.disabled_txt:Hide();
        currently_casting_frame_parent.border:Hide();
        overlay.currently_casting_f1.icon_frame:Hide();
        overlay.currently_casting_f2.icon_frame:Hide();
        currently_casting_frame_parent.config_mode = false;
    end);
end

local special_action_bar_changed_id = 0;

local function update_spell_icons(loadout, effects, eval_flags)

    if sc.core.setup_action_bar_needed then
        setup_action_bars();
        sc.core.setup_action_bar_needed = false;
    end
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
    local num_evals = 0;
    for k, _ in pairs(active_overlays) do
        local v = action_id_frames[k];
        if v.frame and v.frame:IsShown() and spells[v.spell_id] then
            num_evals = num_evals + 1;
            update_overlay_frame(v, loadout, effects, v.spell_id, eval_flags);
        end
    end

    if mana_cost_overlay or cast_speed_overlay then
        for _, v in pairs(action_id_frames) do
            if v.frame and v.spell_id and not spells[v.spell_id] then
                update_non_evaluated_spell(v, v.spell_id, loadout, effects);
            end
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

    --local loadout, effects_before, effects, update_id;
    local effects_before, update_id;
    local updated = true;
    local eval_flags = overlay_eval_flags();

    local spells_frame_open = __sc_frame:IsShown() and __sc_frame.spells_frame:IsShown();
    local calc_frame_open = __sc_frame:IsShown() and __sc_frame.calculator_frame:IsShown();

    if not config.settings.overlay_disable then
        if not calc_frame_open then

            loadout, _, effects, update_id = update_loadout_and_effects();
            updated = update_id > overlay_effects_update_id;
            overlay_effects_update_id = update_id;
        else
            loadout, effects_before, effects =
                update_loadout_and_effects_diffed_from_ui();
        end
    end

    if updated then
        if calc_frame_open then
            if config.settings.overlay_disable then
                sc.ui.update_calc_list(nil, nil, nil, eval_flags);
            else
                sc.ui.update_calc_list(loadout, effects_before, effects, eval_flags);
            end
        elseif spells_frame_open then
            if config.settings.overlay_disable then
                sc.ui.update_spells_frame(nil, nil, eval_flags);
            else
                sc.ui.update_spells_frame(loadout, effects, eval_flags);
            end
        end

        if not config.settings.overlay_disable then
            update_spell_icons(loadout, effects, eval_flags);
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


    if not config.settings.overlay_disable_currently_casting_info then

        if config.settings.overlay_disable then

            -- action bar overlay disabled, need to update loadout
            loadout, _, effects, update_id = update_loadout_and_effects();
            updated = update_id > overlay_effects_update_id;
            overlay_effects_update_id = update_id;
        end
        if updated then
            update_currently_casting();
        end
    end
end

overlay.spell_book_frames                   = spell_book_frames;
overlay.action_id_frames                    = action_id_frames;
overlay.setup_action_bars                   = setup_action_bars;
overlay.update_overlay                      = update_overlay;
overlay.update_icon_overlay_settings        = update_icon_overlay_settings;
overlay.reassign_overlay_icon               = reassign_overlay_icon;
overlay.clear_overlays                      = clear_overlays;
overlay.old_rank_warning_traversal          = old_rank_warning_traversal;
overlay.overlay_eval_flags                  = overlay_eval_flags;
overlay.overlay_reconfig                    = overlay_reconfig;
overlay.init_currently_casting_frames       = init_currently_casting_frames;
overlay.currently_casting_new_spell         = currently_casting_new_spell;
overlay.currently_casting_frame_parent      = currently_casting_frame_parent;
overlay.set_currently_casting_frames_font   = set_currently_casting_frames_font

sc.overlay = overlay;
sc.ext.spell_cache = spell_cache;

