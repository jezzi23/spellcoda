local _, sc = ...;

local L                                         = sc.L;
local client_matches                            = sc.utils.client_matches;
local effect_color                              = sc.utils.effect_color;
local evaluation_flags                          = sc.calc.evaluation_flags;
local update_loadout_and_effects_diffed_from_ui = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local stat_diffs_included_effects_str           = sc.tooltip.stat_diffs_included_effects_str;
local plan_spells_counts                        = sc.tooltip.plan_spells_counts;

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

    local diffs, _, diffs_in, diffs_out, diffs_short = sc.loadouts.diffed_stats_diff_format(loadout, effects,
        effects_diffed);
    frame.diffs_txt = diffs;
    frame.diffs_txt_short = diffs_short;
    -- Before / After are only shown on hover or click and built then, these effects tables keep the latest values
    frame.stats_effects = effects;
    frame.stats_effects_diffed = effects_diffed;

    frame.diffs_fontstr:SetText(L["Stats"].." |cFF00FF00+"..diffs_in.."|r |cFFFF0000-"..diffs_out.."|r");

    if frame.diffs_txt ~= "" then
        local included = stat_diffs_included_effects_str(true, true, true);
        frame.diffs_txt = included..frame.diffs_txt;
        if diffs_short then
            frame.diffs_txt_short = included..diffs_short;
        end
    end

    local better, worse, spells_result = plan_spells_counts(loadout, effects, effects_diffed, eval_flags);
    frame.spells_fontstr:SetText(L["Spells"].." |cFF00FF00+"..better.."|r |cFFFF0000-"..worse.."|r");

    -- the sheet flashes with the stat text, spell numbers do not change it
    local stats_changed = frame.shown_stats_result and frame.shown_stats_result ~= frame.diffs_txt;
    local spells_changed = frame.shown_spells_result and frame.shown_spells_result ~= spells_result;
    if stats_changed then
        frame.diffs_area.flash();
        frame.sheet_area.flash();
    end
    if spells_changed then
        frame.spells_area.flash();
    end
    frame.shown_stats_result = frame.diffs_txt;
    frame.shown_spells_result = spells_result;

    -- a shown box tooltip follows the new numbers
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner();
    if owner and (owner == frame.diffs_area or owner == frame.sheet_area or
                  owner == frame.spells_area) then
        owner:GetScript("OnEnter")(owner);
    end
end

-- the comparison list changed: the calculator's Spells box and the list in Tooltip -> Items
local function compared_spells_changed()
    update_calc_list(true);
    ui.refresh_compared_spells();
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

ui.compared_spells_changed   = compared_spells_changed;
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
ui.update_calc_list          = update_calc_list;
