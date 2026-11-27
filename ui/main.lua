local _, sc = ...;

local L              = sc.L;
local client_matches = sc.utils.client_matches;
local config         = sc.config;

local ui = sc.ui;
local create_sw_item_id_viewer      = ui.create_sw_item_id_viewer;
local create_sw_spell_id_viewer     = ui.create_sw_spell_id_viewer;
local create_sw_ui_calculator_frame = ui.create_sw_ui_calculator_frame;
local create_sw_ui_loadout_frame    = ui.create_sw_ui_loadout_frame;
local create_sw_ui_overlay_frame    = ui.create_sw_ui_overlay_frame;
local create_sw_ui_profile_frame    = ui.create_sw_ui_profile_frame;
local create_sw_ui_settings_frame   = ui.create_sw_ui_settings_frame;
local create_sw_ui_spells_frame     = ui.create_sw_ui_spells_frame;
local create_sw_ui_tooltip_frame    = ui.create_sw_ui_tooltip_frame;
local create_tab_button             = ui.create_tab_button;
local fix_minimap_button            = ui.fix_minimap_button;
local font                          = ui.font;
local fonts_setup                   = ui.fonts_setup;
local layout_tabs                   = ui.layout_tabs;
local libstub_data_broker           = ui.libstub_data_broker;
local libstub_icon                  = ui.libstub_icon;
local set_tab_icon                  = ui.set_tab_icon;
local sw_activate_frame             = ui.sw_activate_frame;
local sw_activate_tab               = ui.sw_activate_tab;
local ui_tabs_idx                   = ui.ui_tabs_idx;
local ui_tabs_order                 = ui.ui_tabs_order;

local libstub_launcher;

-- the data's client build against the running client: -1 data older, 0 same build, 1 data newer
local function data_build_cmp()
    return sc.utils.compare_builds(sc.client_version_src, sc.client_version_loaded);
end

-- a small red X in the minimap button's lower right corner while the data is for another client build. The
-- tooltip's check / X markup draws late when nothing keeps its texture loaded, so the button also holds both atlases
-- in invisible textures
local function mark_minimap_button_mismatch()
    local button = libstub_icon:GetMinimapButton(sc.core.addon_name);
    if not button then
        return;
    end
    for _, atlas in ipairs({"UI-LFG-ReadyMark", "UI-LFG-DeclineMark"}) do
        local keep = button:CreateTexture(nil, "BACKGROUND");
        keep:SetAtlas(atlas);
        keep:SetSize(1, 1);
        keep:SetPoint("CENTER", button, "CENTER");
        keep:SetAlpha(0);
    end
    if data_build_cmp() == 0 then
        return;
    end
    local mark = button:CreateTexture(nil, "OVERLAY", nil, 7);
    mark:SetAtlas("UI-LFG-DeclineMark");
    mark:SetSize(11, 11);
    mark:SetPoint("CENTER", button.icon, "BOTTOMRIGHT", -1, 1);
end

local function create_sw_base_ui()

    __sc_frame = CreateFrame("Frame", "__sc_frame", UIParent, "BasicFrameTemplate, BasicFrameTemplateWithInset");

    __sc_frame:SetFrameStrata("HIGH");
    __sc_frame:SetMovable(true);
    __sc_frame:EnableMouse(true);
    __sc_frame:RegisterForDrag("LeftButton");
    __sc_frame:SetScript("OnDragStart", __sc_frame.StartMoving);
    __sc_frame:SetScript("OnDragStop", __sc_frame.StopMovingOrSizing);
    __sc_frame:HookScript("OnHide", function()
        __sc_frame.hidden_time = GetTime();
        sc.core.deactivate_tooltip_refresh();
    end);
    __sc_frame:HookScript("OnShow", function()
        sc.core.activate_tooltip_refresh();
    end);

    local width = 500;
    local height = 600;

    __sc_frame:SetWidth(width);
    __sc_frame:SetHeight(height);
    __sc_frame:SetPoint("TOPLEFT", 400, -30);

    local scale_grip = CreateFrame("Button", nil, __sc_frame);
    scale_grip:SetSize(20, 20);
    scale_grip:SetPoint("BOTTOMRIGHT", -4, 4);
    scale_grip:SetFrameLevel(__sc_frame:GetFrameLevel() + 20);
    scale_grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up");
    scale_grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight");
    scale_grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down");
    scale_grip:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", function()
            local scale = __sc_frame:GetScale();
            local left = __sc_frame:GetLeft() * scale;
            local top = __sc_frame:GetTop() * scale;
            local cursor_x, cursor_y = GetCursorPosition();
            local ui_scale = UIParent:GetEffectiveScale();
            cursor_x = cursor_x / ui_scale;
            cursor_y = cursor_y / ui_scale;

            local new_scale = 0.5 * ((cursor_x - left) / width + (top - cursor_y) / height);
            new_scale = math.max(0.5, math.min(2.5, new_scale));
            __sc_frame:SetScale(new_scale);
            __sc_frame:ClearAllPoints();
            __sc_frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / new_scale, top / new_scale);
        end);
    end);
    scale_grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil);
        __sc_p_acc.window_scale = __sc_frame:GetScale();
    end);

    __sc_frame.title = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.title:SetFontObject(font)
    __sc_frame.title:SetText(sc.core.addon_name.." v"..sc.core.version);
    __sc_frame.title:SetPoint("CENTER", __sc_frame.TitleBg, "CENTER", 0, 0);

    __sc_frame:Hide();

    local tabbed_child_frames_y_offset = 20;
    local x_margin = 15;

    __sc_frame.tabs = {};

    local i = 1;

    for _, v in pairs(ui_tabs_order) do
        __sc_frame[v] = CreateFrame("ScrollFrame", "__sc_frame_"..v, __sc_frame);
        __sc_frame[v]:SetPoint("TOP", __sc_frame, 0, -tabbed_child_frames_y_offset-35);
        __sc_frame[v]:SetWidth(width-x_margin*2);
        __sc_frame[v]:SetHeight(height-tabbed_child_frames_y_offset-35-5);
        __sc_frame[v].y_offset = 0;

        __sc_frame.tabs[i] = create_tab_button(__sc_frame, "__sc_frame_tab_button"..i);
        __sc_frame.tabs[i].frame_to_open = __sc_frame[v];

        i = i + 1;
    end

    for k, _ in pairs(sc.core.event_dispatch) do
        local client_filter = sc.core.event_client_filters[k];
        if not client_filter or client_matches(client_filter) then

            __sc_frame:RegisterEvent(k);
        end
    end

    __sc_frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
        sc.core.event_dispatch[event](self, arg1, arg2, arg3);
        end
    );
end

local function load_sw_ui()

    __sc_frame:SetScale(__sc_p_acc.window_scale);

    local tab_display_names = {
        spells_frame = L["Spells"],
        calculator_frame = L["Calculator"],
        loadout_frame = L["Loadout"],
        tooltip_frame = L["Tooltip"],
        overlay_frame = L["Overlay"],
        settings_frame = "",
        profile_frame = L["Profile"]
    };

    for k, tab_name in ipairs(ui_tabs_order) do

        local v = __sc_frame.tabs[k];
        v:SetText(tab_display_names[tab_name]);
        v:SetScript("OnClick", function(self)
            sw_activate_tab(self);
        end);
        v:SetID(k);
    end

    local spell_book_texture = set_tab_icon(__sc_frame.tabs[1], 12);
    spell_book_texture:SetTexture("Interface\\Icons\\INV_Misc_Book_09");
    spell_book_texture:SetTexCoord(0.08, 0.92, 0.08, 0.92);

    local calc_tab =  __sc_frame.tabs[2];
    local character_portrait = set_tab_icon(calc_tab, 16);
    SetPortraitTexture(character_portrait, "player");
    calc_tab:RegisterEvent("UNIT_PORTRAIT_UPDATE");
    calc_tab:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            SetPortraitTexture(character_portrait, "player");
        end
    end);

    local loadout_texture = set_tab_icon(__sc_frame.tabs[3], 12);
    loadout_texture:SetTexture("Interface\\Icons\\Ability_Warrior_OffensiveStance");
    loadout_texture:SetTexCoord(0.08, 0.92, 0.08, 0.92);

    local settings_tab = __sc_frame.tabs[ui_tabs_idx.settings_frame];
    set_tab_icon(settings_tab, 14):SetTexture("Interface\\Buttons\\UI-OptionsButton");
    settings_tab.fixed_width = 40;

    layout_tabs(__sc_frame.tabs, 8, -20, __sc_frame:GetWidth()-16);

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
            local cmp = data_build_cmp();
            local mark = cmp == 0 and CreateAtlasMarkup("UI-LFG-ReadyMark", 14, 14) or
                CreateAtlasMarkup("UI-LFG-DeclineMark", 14, 14);
            tooltip:AddLine("|cFF9CD6DE"..L["Addon data generated from"]..":|r");
            tooltip:AddLine("    "..sc.client_name_src.." "..sc.client_version_src.."  "..mark);
            if sc.hotfixes_fetched_utc then
                local fetched = sc.hotfixes_fetched_utc:gsub("^(%d+%-%d+%-%d+)T(%d+:%d+).*$", "%1 %2 UTC");
                tooltip:AddLine("    "..L["Hotfixes fetched"].." "..fetched);
            else
                tooltip:AddLine("    |cFF808080"..L["Hotfixes: not included"].."|r");
            end
            tooltip:AddLine("|cFF9CD6DE"..L["Current client build"]..":|r "..sc.client_version_loaded);
            if cmp < 0 and sc.utils.client_age_days > 7 then
                tooltip:AddLine("    |cFFFF4040"..L["Data is from an older client build, check for an update"].."|r");
            elseif cmp > 0 then
                tooltip:AddLine("    |cFFFF4040"..L["Data is from a newer client build"].."|r");
            end
            tooltip:AddLine(" ");
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
                        __sc_frame:Show();
                        --sw_activate_frame("spells_frame");
                    end
                end
            end,
            OnTooltipShow = tooltip_show_fn
        });
        -- LibDBIcon 55 creates the button on Register
        libstub_icon:Register(sc.core.addon_name, libstub_launcher, config.settings.libstub_icon_conf);
        fix_minimap_button();
        mark_minimap_button_mismatch();
    end


    create_sw_ui_spells_frame(__sc_frame.spells_frame);
    create_sw_ui_tooltip_frame(__sc_frame.tooltip_frame);
    create_sw_ui_overlay_frame(__sc_frame.overlay_frame);
    create_sw_ui_loadout_frame(__sc_frame.loadout_frame);
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
                sw_activate_frame("spells_frame");
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
        sw_activate_frame("settings_frame");
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
            text:SetText("SpellCoda has localization support but is turned off by default.\n\n\n\nTurn on localization in settings:\n\n            |cFF00FF00/spellcoda config|r \n\n There may be missing or unfortunate translations");

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

ui.create_sw_base_ui    = create_sw_base_ui;
ui.load_sw_ui           = load_sw_ui;
ui.locale_warning_popup = locale_warning_popup;
ui.post_login_load      = post_login_load;
