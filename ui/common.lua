local _, sc = ...;

local L                                         = sc.L;
local spells                                    = sc.spells;
local spell_flags                               = sc.spell_flags;
local client_matches                            = sc.utils.client_matches;
local highest_learned_rank                      = sc.utils.highest_learned_rank;
local effect_color                              = sc.utils.effect_color;
local evaluation_flags                          = sc.calc.evaluation_flags;
local update_loadout_and_effects_diffed_from_ui = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local spell_diff                                = sc.calc.spell_diff;
local ehp_diff                                  = sc.calc.ehp_diff;
local stat_diffs_included_effects_str           = sc.tooltip.stat_diffs_included_effects_str;
local colored_diff_str                          = sc.tooltip.colored_diff_str;
local config                                    = sc.config;

-------------------------------------------------------------------------
local ui = {};
sc.ui = ui;

local role_icons = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES";
local font = "GameFontHighlightSmall";
local libstub_data_broker = LibStub("LibDataBroker-1.1", true);
local libstub_icon = libstub_data_broker and LibStub("LibDBIcon-1.0", true);

local function fix_minimap_button()
    local button = libstub_icon:GetMinimapButton(sc.core.addon_name);
    if client_matches(sc.client_flags.forever) then
        -- forever has the retail minimap border art, lay it out like LibDBIcon does on retail
        for _, region in ipairs({button:GetRegions()}) do
            if region:IsObjectType("Texture") then
                local layer = region:GetDrawLayer();
                if layer == "OVERLAY" then
                    region:SetSize(50, 50);
                    region:ClearAllPoints();
                    region:SetPoint("TOPLEFT", button, "TOPLEFT");
                elseif layer == "BACKGROUND" then
                    region:SetSize(24, 24);
                    region:ClearAllPoints();
                    region:SetPoint("CENTER", button, "CENTER");
                end
            end
        end
        button.icon:SetSize(18, 18);
        button.icon:ClearAllPoints();
        button.icon:SetPoint("CENTER", button, "CENTER");
    end
    -- the square icon relies on the border art to hide its corners
    local mask = button:CreateMaskTexture();
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
    mask:SetAllPoints(button.icon);
    button.icon:AddMaskTexture(mask);
end

local libDD = LibStub("LibUIDropDownMenu-4.0", true);

local colored_text_frames = {};
local function register_text_frame_color(frame, color_tag)
    colored_text_frames[frame] = color_tag;
end


-- Dump frame for things like getting missing strings for localization
local dump_frame = CreateFrame("Frame", "__sc_dump_frame", UIParent, "BasicFrameTemplate, BasicFrameTemplateWithInset");
dump_frame:SetSize(600, 400);
dump_frame:SetFrameStrata("DIALOG");
dump_frame:SetPoint("CENTER");
dump_frame:EnableMouse(true);
dump_frame:SetMovable(true);
dump_frame:RegisterForDrag("LeftButton");
dump_frame:SetScript("OnDragStart", dump_frame.StartMoving);
dump_frame:SetScript("OnDragStop", dump_frame.StopMovingOrSizing);
dump_frame:Hide();

local title_text = dump_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title_text:SetPoint("TOP", 0, -5);
title_text:SetText("");

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

local function dump_text(title, text, width, height)
    local w = width or 600;
    local h = height or 400;

    dump_frame:SetSize(w, h);
    title_text:SetText(title);
    edit_box:SetText(text);
    dump_frame:Show();
    edit_box:HighlightText();
end

local function make_help_icon_tooltip(name, parent, title, txt)

    local icon = CreateFrame("Button", name, parent);
    icon:SetSize(20, 20);

    local tex = icon:CreateTexture(nil, "ARTWORK");
    tex:SetAllPoints();
    tex:SetTexture("Interface\\Common\\help-i");
    icon.texture = tex;

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(title);
        if txt then
            GameTooltip:AddLine(txt);
        end
        GameTooltip:Show()
    end);

    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    icon:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");

    return icon;
end

-- row i of the calculator's spell list, rows are reused for whichever entries the scroll offset shows
local function display_spell_diff(i, calc_list, diff, frame)
    if not calc_list[i] then
        calc_list[i] = {};

        local area = frame.calc_list_area;
        local y = -frame.calc_list_row_height * i;

        calc_list[i].spell_icon = CreateFrame("Frame", nil, area);
        calc_list[i].spell_icon:SetSize(15, 15);
        calc_list[i].spell_icon:SetPoint("TOPLEFT", 0, y+2);
        calc_list[i].spell_icon.tex = calc_list[i].spell_icon:CreateTexture(nil, "ARTWORK");
        calc_list[i].spell_icon.tex:SetAllPoints(calc_list[i].spell_icon);

        calc_list[i].tooltip_area = CreateFrame("Frame", nil, area);
        calc_list[i].tooltip_area:SetSize(100, 16);
        calc_list[i].tooltip_area:SetPoint("TOPLEFT", 0, y+2);
        calc_list[i].tooltip_area.spell_id = 0;
        calc_list[i].tooltip_area:EnableMouse(true);
        calc_list[i].tooltip_area:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetSpellByID(self.spell_id);
            GameTooltip:Show();

        end);
        calc_list[i].tooltip_area:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        calc_list[i].tooltip_area:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);

        calc_list[i].name_str = area:CreateFontString(nil, "OVERLAY");
        calc_list[i].name_str:SetFontObject(font);
        calc_list[i].name_str:SetPoint("TOPLEFT", 20, y);

        calc_list[i].role_icon = CreateFrame("Frame", nil, area);
        calc_list[i].role_icon:SetSize(15, 15);
        calc_list[i].role_icon:SetPoint("TOPLEFT", 225, y+2);
        calc_list[i].role_icon.tex = calc_list[i].role_icon:CreateTexture(nil, "ARTWORK");
        calc_list[i].role_icon.tex:SetTexture(role_icons);

        calc_list[i].first = area:CreateFontString(nil, "OVERLAY");
        calc_list[i].first:SetFontObject(font);
        calc_list[i].first:SetPoint("LEFT", area, "TOPLEFT", 260, y-4);
        calc_list[i].second = area:CreateFontString(nil, "OVERLAY");
        calc_list[i].second:SetFontObject(font);
        calc_list[i].second:SetPoint("LEFT", area, "TOPLEFT", 360, y-4);


        calc_list[i].cancel_button = CreateFrame("Button", nil, area, "UIPanelButtonTemplate");
        calc_list[i].cancel_button:SetScript("OnClick", function(self)
            config.settings.spell_calc_list[self.__id_src] = nil;
            ui.update_calc_list(true);
        end);

        calc_list[i].cancel_button:SetPoint("TOPRIGHT", -10, y + 4);
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

    v.tooltip_area.spell_id = diff.id;
    v.spell_icon.tex:SetTexture(diff.tex);

    v.name_str:SetText(diff.disp);

    v.name_str:SetTextColor(222/255, 192/255, 40/255);

    v.first:SetText(colored_diff_str(diff.effect, diff.effect_changed_perc, 2));
    v.second:SetText(colored_diff_str(diff.effect_timed, diff.effect_timed_changed_perc, 2));

    if diff.heal_like then
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.0, 0.25);
    elseif diff.tank_like then
        v.role_icon.tex:SetTexCoord(0.0, 0.25, 0.25, 0.5);
        v.second:SetText(" ");
    else
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.25, 0.5);
    end
    v.role_icon.tex:SetAllPoints(v.role_icon);


    for _, f in pairs(v) do
        f:Show();
    end
    if diff.is_dual_spell then
        calc_list[i].cancel_button:Hide();
    end
end

local cached_spells_cmp_diffs = {};

-- the rows that fit the list area, from the scroll offset on; the slider only shows when there are more entries
local function show_calc_list_rows(frame)
    local n = frame.num_spells or 0;
    local max_offset = math.max(0, n - frame.calc_list_num_rows);
    local slider = frame.calc_list_slider;
    slider:SetMinMaxValues(0, max_offset);
    slider:SetShown(max_offset > 0);
    if frame.calc_list_offset > max_offset then
        frame.calc_list_offset = max_offset;
        slider:SetValue(max_offset);
    end

    for _, v in pairs(frame.calc_list) do
        for _, f in pairs(v) do
            f:Hide();
        end
    end
    local offset = frame.calc_list_offset;
    for r = 1, math.min(frame.calc_list_num_rows, n - offset) do
        display_spell_diff(r, frame.calc_list, cached_spells_cmp_diffs[offset + r], frame);
    end
end

local calc_list_update_id = 0;

local function update_calc_list(was_rearranged, loadout, effects, effects_diffed, eval_flags)

    local frame = __sc_frame.calculator_frame;

    local update_id;
    if not loadout then
        loadout, _, _, effects, effects_diffed, update_id = update_loadout_and_effects_diffed_from_ui();

        local updated = update_id > calc_list_update_id;
        calc_list_update_id = update_id;

        if not updated and not was_rearranged then
            return;
        end

        eval_flags = sc.overlay.overlay_eval_flags();
    end

    eval_flags = bit.bor(eval_flags, evaluation_flags.expectation_of_self);

    local diffs, _, diffs_in, diffs_out = sc.loadouts.diffed_stats_diff_format(loadout, effects, effects_diffed);
    frame.diffs_txt = diffs;
    -- Before / After are only shown on hover or click and built then, these effects tables keep the latest values
    frame.stats_effects = effects;
    frame.stats_effects_diffed = effects_diffed;

    frame.diffs_fontstr:SetText(L["Changes"].."\n|cFF00FF00 +"..diffs_in.." |r|cFFFF0000 -"..diffs_out.."|r");

    if frame.diffs_txt ~= "" then
        frame.diffs_txt = stat_diffs_included_effects_str(true, true, true)..frame.diffs_txt;
    end

    -- a shown Changes / Before / After tooltip follows the new texts
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner();
    if owner and (owner == frame.diffs_area or owner == frame.before_area or owner == frame.after_area) then
        owner:GetScript("OnEnter")(owner);
    end

    local i = 0;
    for k, _ in pairs(config.settings.spell_calc_list) do

        local original_k = k;
        if config.settings.calc_list_use_highest_rank and spells[k] then
            k = highest_learned_rank(spells[k].base_id);
        end
        if k and spells[k] then
            if bit.band(spells[k].flags, spell_flags.eval) ~= 0 then

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
            elseif bit.band(spells[k].flags, spell_flags.ehp) ~= 0 then

                i = i + 1;
                cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

                ehp_diff(cached_spells_cmp_diffs[i],
                         loadout,
                         effects,
                         effects_diffed,
                         eval_flags);

                cached_spells_cmp_diffs[i].is_dual_spell = false;
                cached_spells_cmp_diffs[i].original_id = original_k;
            end
        end
    end
    frame.num_spells = i;
    show_calc_list_rows(frame);
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
    -- OnTextSet runs for SetText, a programmatic change also fires OnTextChanged one frame later
    frame:SetScript("OnTextChanged", function(self, user_input)
        if user_input then
            update_func(self);
        end
    end);
    frame:SetScript("OnTextSet", update_func);
end


-- nil tag recolors everything, registered textures are color swatches
ui.apply_colors = function(tag)
    for frame, frame_tag in pairs(colored_text_frames) do
        if not tag or frame_tag == tag then
            if frame.SetTextColor then
                frame:SetTextColor(effect_color(frame_tag));
            else
                frame:SetColorTexture(effect_color(frame_tag));
            end
        end
    end
    sc.overlay.ccf_labels_recolor();
    sc.core.update_action_bar_needed = true;
    sc.loadouts.force_update = true;
end;

ui.display_spell_diff        = display_spell_diff;
ui.dump_text                 = dump_text;
ui.editbox_config            = editbox_config;
ui.fix_minimap_button        = fix_minimap_button;
ui.font                      = font;
ui.libDD                     = libDD;
ui.libstub_data_broker       = libstub_data_broker;
ui.libstub_icon              = libstub_icon;
ui.make_help_icon_tooltip    = make_help_icon_tooltip;
ui.register_text_frame_color = register_text_frame_color;
ui.role_icons                = role_icons;
ui.show_calc_list_rows       = show_calc_list_rows;
ui.update_calc_list          = update_calc_list;
