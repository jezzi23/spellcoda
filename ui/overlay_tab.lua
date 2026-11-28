local _, sc = ...;

local L              = sc.L;
local client_matches = sc.utils.client_matches;
local client_flags   = sc.client_flags;
local effect_color   = sc.utils.effect_color;
local config         = sc.config;

local ui = sc.ui;
local create_subtabs            = ui.create_subtabs;
local editbox_config            = ui.editbox_config;
local font                      = ui.font;
local libDD                     = ui.libDD;
local make_frame_scrollable     = ui.make_frame_scrollable;
local multi_row_checkbutton     = ui.multi_row_checkbutton;
local make_dodge_drag_button    = ui.make_dodge_drag_button;
local register_text_frame_color = ui.register_text_frame_color;


local fonts = {
    "Fonts\\FRIZQT__.TTF",
    "Fonts\\ARIALN.TTF",
    "Fonts\\MORPHEUS.TTF",
    "Fonts\\SKURRI.TTF",
    "Fonts\\2002.TTF",
    "Interface\\AddOns\\SpellCoda\\font\\Oswald-Bold.ttf",
};

local font_dropdowns = {};
local font_dropdown_font_objects = {};

local external_fonts_found = {};

local function get_font(font_id)
    -- font_id's are typically paths but fonts from LibSharedMedia identified from name
    return external_fonts_found[font_id] or font_id;
end

local function fonts_setup()

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true);
    if lsm then
        local external_fonts = lsm:List("font");
        for _, font_name in ipairs(external_fonts) do
            external_fonts_found[font_name] = lsm:Fetch("font", font_name);
            fonts[#fonts+1] = font_name;
        end
    end
    for _, font_path in ipairs(fonts) do
        font_dropdowns[#font_dropdowns + 1] = { font_path, "OUTLINE" };
        font_dropdowns[#font_dropdowns + 1] = { font_path, "THICKOUTLINE" };
    end
end

local function create_font_dropdown(parent_frame, dropdown_name, font_config_key, callback_fn)

    local dropdown_frame = libDD:Create_UIDropDownMenu(dropdown_name, parent_frame);
    local page_size = 30;

    dropdown_frame._type = "DropDownMenu";
    dropdown_frame.font_page = 1;

    local function selected_font_index()
        local current_font_id = config.settings[font_config_key][1];
        local current_font_flags = config.settings[font_config_key][2];
        for idx, font_entry in ipairs(font_dropdowns) do
            if current_font_id == font_entry[1]
                and current_font_flags == font_entry[2] then
                return idx;
            end
        end
    end

    dropdown_frame.init_func = function()
        local current_font_id = config.settings[font_config_key][1];
        local current_font_flags = config.settings[font_config_key][2];
        local selected_index = selected_font_index();

        if selected_index then
            local selected_entry = font_dropdowns[selected_index];
            libDD:UIDropDownMenu_SetText(
                dropdown_frame,
                (selected_entry[1]:match("([^\\]+)$") or selected_entry[1]) .. "   0123456789  " .. selected_entry[2]
            );
        end

        if not current_font_id:find("\\") then

            -- SharedMedia fonts are stored by id/name rather than path.
            -- If the id no longer resolves, fall back to the configured default.
            if not external_fonts_found[current_font_id] then
                config.settings[font_config_key][1] = config.default_settings[font_config_key][1];
                config.settings[font_config_key][2] = config.default_settings[font_config_key][2];
                current_font_id = config.settings[font_config_key][1];
                current_font_flags = config.settings[font_config_key][2];
            end
            local txt = (current_font_id:match("([^\\]+)$") or current_font_id) .. "   0123456789  " .. current_font_flags;
            libDD:UIDropDownMenu_SetText(dropdown_frame, txt);
        end
    end;

    libDD:UIDropDownMenu_SetInitializeFunction(dropdown_frame, function()
        local num_font_entries = #font_dropdowns;
        local num_pages = math.max(1, math.ceil(num_font_entries / page_size));
        local selected_index = selected_font_index();

        if selected_index and not dropdown_frame.keep_page then
            dropdown_frame.font_page = math.ceil(selected_index / page_size);
        end

        dropdown_frame.keep_page = nil;
        dropdown_frame.font_page = math.min(math.max(dropdown_frame.font_page or 1, 1), num_pages);

        local page_start = (dropdown_frame.font_page - 1) * page_size + 1;
        local page_end = math.min(page_start + page_size - 1, num_font_entries);

        if dropdown_frame.font_page > 1 then
            libDD:UIDropDownMenu_AddButton({
                text = "   ...",
                notCheckable = true,
                func = function()
                    dropdown_frame.font_page = dropdown_frame.font_page - 1;
                    dropdown_frame.keep_page = true;
                    libDD:CloseDropDownMenus();
                    libDD:ToggleDropDownMenu(1, nil, dropdown_frame, dropdown_frame, 0, 0);
                end,
            });
        end

        for k = page_start, page_end do
            local v = font_dropdowns[k];
            local txt = (v[1]:match("([^\\]+)$") or v[1]) .. "   0123456789  " .. v[2];
            if not font_dropdown_font_objects[k] then
                local font_object = CreateFont("__sc_font_dropdown_font_" .. k);
                font_object:SetFont(get_font(v[1]), 12, v[2]);
                font_dropdown_font_objects[k] = font_object;
            end

            local btn = {
                text = txt,
                fontObject = font_dropdown_font_objects[k],
                checked = false,
                func = function()
                    libDD:UIDropDownMenu_SetText(dropdown_frame, txt);
                    config.settings[font_config_key][1] = v[1];
                    config.settings[font_config_key][2] = v[2];
                    callback_fn();
                end,
            };

            if selected_index == k then
                btn.checked = true;
            end
            libDD:UIDropDownMenu_AddButton(btn);
        end

        if page_end < num_font_entries then
            libDD:UIDropDownMenu_AddButton({
                text = "   ...",
                notCheckable = true,
                func = function()
                    dropdown_frame.font_page = dropdown_frame.font_page + 1;
                    dropdown_frame.keep_page = true;
                    libDD:CloseDropDownMenus();
                    libDD:ToggleDropDownMenu(1, nil, dropdown_frame, dropdown_frame, 0, 0);
                end,
            });
        end
    end);

    libDD:UIDropDownMenu_SetWidth(dropdown_frame, 200);
    libDD:UIDropDownMenu_SetButtonWidth(dropdown_frame, 224);
    libDD:UIDropDownMenu_JustifyText(dropdown_frame, "LEFT");

    return dropdown_frame;
end;

local label_menu;

local function colored(text, color_tag)
    local r, g, b = effect_color(color_tag);
    return CreateColor(r, g, b, 1.0):WrapTextInColorCode(text);
end

local function label_selection_dropdown(pframe, option_key, on_change)
    if not label_menu then
        local total_section = {
            title = L["Total"],
            tooltip = L["Aggregate of all direct and periodic components of a spell"],
        };
        local main_section = {
            title = L["Main effect"],
            tooltip = L["First direct component of a spell, or its first periodic component if it has no direct one"],
        };
        label_menu = {
            {
                name = L["Normal hit"],
                color_tag = "normal",
                keys = {
                    total_section,
                    "overlay_display_normal",
                    "overlay_display_normal_total_min",
                    "overlay_display_normal_total_max",
                    main_section,
                    "overlay_display_normal_avg",
                    "overlay_display_normal_min",
                    "overlay_display_normal_max",
                    "overlay_display_direct_normal",
                    "overlay_display_ot_normal",
                    "overlay_display_hit_chance",
                },
            },
            {
                name = L["Critical hit"],
                color_tag = "crit",
                keys = {
                    total_section,
                    "overlay_display_crit",
                    "overlay_display_crit_total_min",
                    "overlay_display_crit_total_max",
                    main_section,
                    "overlay_display_crit_avg",
                    "overlay_display_crit_min",
                    "overlay_display_crit_max",
                    "overlay_display_direct_crit",
                    "overlay_display_ot_crit",
                    "overlay_display_crit_chance",
                },
            },
            {
                name = L["Expected effect"],
                color_tag = "expectation",
                keys = {
                    "overlay_display_expected",
                    "overlay_display_effect_per_sec",
                },
            },
            {
                name = L["Threat"],
                color_tag = "threat",
                keys = {
                    "overlay_display_threat",
                    "overlay_display_threat_per_sec",
                    "overlay_display_threat_per_cost",
                },
            },
            {
                name = L["Cost & mana"],
                color_tag = "cost",
                keys = {
                    "overlay_display_avg_cost",
                    "overlay_display_actual_cost",
                    "overlay_display_effect_per_cost",
                    "overlay_display_effect_until_oom",
                    "overlay_display_casts_until_oom",
                    "overlay_display_time_until_oom",
                },
            },
            {
                name = L["Timing"],
                color_tag = "execution_time",
                keys = {
                    "overlay_display_avg_cast",
                    "overlay_display_actual_cast",
                },
            },
            {
                name = L["Against target"],
                color_tag = "avoidance_info",
                keys = {
                    "overlay_display_miss_chance",
                    "overlay_display_avoid_chance",
                    "overlay_display_mitigation",
                },
            },
            "overlay_display_rank",
        };
    end

    local handlers = sc.overlay.label_handler;
    local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);
    dd._type = "DropDownMenu";
    dd._settings_id = option_key;

    local function show_selected()
        local sel = handlers[config.settings[option_key]];
        libDD:UIDropDownMenu_SetText(dd, sel.short);
        dd.Text:SetTextColor(effect_color(sel.color_tag));
        register_text_frame_color(dd.Text, sel.color_tag);
    end

    dd.init_func = function()
        if not handlers[config.settings[option_key]] then
            config.settings[option_key] = next(handlers);
        end
        show_selected();
        on_change();
    end;
    libDD:UIDropDownMenu_SetWidth(dd, 120);

    local function add_entry(key, level)
        local h = handlers[key];
        libDD:UIDropDownMenu_AddButton(
            {
                text = colored(h.desc, h.color_tag),
                checked = function() return config.settings[option_key] == key; end,
                func = function()
                    config.settings[option_key] = key;
                    show_selected();
                    on_change();
                    libDD:CloseDropDownMenus();
                end,
                tooltipTitle = "",
                tooltipText = h.tooltip,
                tooltipOnButton = h.tooltip ~= nil,
            },
            level
        );
    end

    libDD:UIDropDownMenu_SetInitializeFunction(dd, function(_, level, menu_list)
        if level == 2 then
            for _, key in ipairs(menu_list) do
                if type(key) == "table" then
                    libDD:UIDropDownMenu_AddButton(
                        {
                            text = key.title,
                            isTitle = true,
                            notCheckable = true,
                            tooltipTitle = key.title,
                            tooltipText = key.tooltip,
                            tooltipOnButton = true,
                            tooltipWhileDisabled = true,
                        },
                        2
                    );
                else
                    add_entry(key, 2);
                end
            end
            return;
        end
        for _, item in ipairs(label_menu) do
            if type(item) == "string" then
                add_entry(item, 1);
            else
                libDD:UIDropDownMenu_AddButton(
                    {
                        text = colored(item.name, item.color_tag),
                        hasArrow = true,
                        menuList = item.keys,
                        keepShownOnClick = true,
                        noClickSound = true,
                        checked = function()
                            local sel = config.settings[option_key];
                            for _, key in ipairs(item.keys) do
                                if key == sel then
                                    return true;
                                end
                            end
                            return false;
                        end,
                        func = function()
                            libDD:UIDropDownMenu_Refresh(dd, nil, 1);
                            show_selected();
                        end,
                    },
                    1
                );
            end
        end
    end);

    return dd;
end


local function create_overlay_spells_frame(pframe)

    local f, f_txt;
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
                sc.core.overlay_refresh_config(true);
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
            id = "overlay_hide_macro_names",
            txt = L["Hide macro names"],
            func = function()
                sc.overlay.update_macro_names();
            end,
            tooltip = L["Hides the macro name on action bar buttons that show a SpellCoda overlay."],
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

    pframe.y_offset = pframe.y_offset - 7;

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
            local dd = label_selection_dropdown(pframe, label_frame_setting_subkey.."_selection", function()
                sc.core.update_action_bar_needed = true;
                sc.loadouts.force_update = true;
            end);
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            ofs[#ofs + 1] = dd;
        end
        pframe.y_offset = pframe.y_offset - 20;
    end

    pframe.y_offset = pframe.y_offset - 7;

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
        f.tooltip = handler.tooltip;
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
            sc.core.update_action_bar_needed = true;
            sc.loadouts.force_update = true;

            for i, disp in ipairs(selections) do
                if config.settings[dd._settings_id] == i then
                    libDD:UIDropDownMenu_SetText(dd, disp);
                end
            end
        end;
        libDD:UIDropDownMenu_SetWidth(dd, 120);
        libDD:UIDropDownMenu_SetInitializeFunction(dd, function(self)
            for i, disp in ipairs(selections) do
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
        ofs[#ofs + 1] = dd;
    end
    pframe.y_offset = pframe.y_offset - 26;

    do
        local option_key = "overlay_ehp";
        f = CreateFrame("CheckButton", "__sc_frame_setting_"..option_key, pframe, "ChatConfigCheckButtonTemplate");
        f._type = "CheckButton";
        f._settings_id = option_key;
        f:SetPoint("TOPLEFT", 10, pframe.y_offset);
        f:SetScript("OnClick", function(self)
            config.settings[self._settings_id] = self:GetChecked();
            sc.core.update_action_bar_needed = true;
            sc.loadouts.force_update = true;
        end);
        local handler = sc.overlay.label_handler.overlay_display_ehp;
        f.tooltip = handler.tooltip;
        local text_frame = getglobal(f:GetName()..'Text');
        text_frame:SetText(handler.desc);
        register_text_frame_color(text_frame, handler.color_tag);
        ofs[#ofs + 1] = f;
    end
    do
        local option_key = "overlay_ehp_display_idx";
        local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);
        make_dodge_drag_button(pframe, dd:GetFrameLevel() + 2):SetPoint("LEFT", dd, "RIGHT", -6, 2);

        dd._type = "DropDownMenu";
        dd._settings_id = option_key;
        dd:SetPoint("TOPLEFT", 165, pframe.y_offset+3);
        local selections =  {L["Top label"], L["Center label"], L["Bottom label"]};
        dd.init_func = function()
            sc.core.update_action_bar_needed = true;
            sc.loadouts.force_update = true;

            for i, disp in ipairs(selections) do
                if config.settings[dd._settings_id] == i then
                    libDD:UIDropDownMenu_SetText(dd, disp);
                end
            end
        end;
        libDD:UIDropDownMenu_SetWidth(dd, 120);
        libDD:UIDropDownMenu_SetInitializeFunction(dd, function(self)
            for i, disp in ipairs(selections) do
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
        ofs[#ofs + 1] = dd;
    end
    pframe.y_offset = pframe.y_offset - 26;

    make_frame_scrollable(pframe);
end


local function create_overlay_cast_info_frame(pframe)

    local f, f_txt;
    local slider_frame_type = "Slider";
    pframe.y_offset = pframe.y_offset - 5;

    local cfs = {}

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

                    if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
                        sc.overlay.ccf_parent.border.txt:Show();
                        sc.overlay.ccf_parent.border:Show();
                        sc.overlay.cc_demo();
                    else
                        sc.overlay.ccf_parent.border.txt:Hide();
                        sc.overlay.ccf_parent.border:Hide();
                    end

                    local alpha = 1.0;
                    if self:GetChecked() then
                        sc.overlay.ccf_hook_events(false);
                        alpha = 0.2;
                    else
                        sc.overlay.ccf_hook_events(true);
                    end
                    for _, v in ipairs(cfs) do
                        v:SetAlpha(alpha);
                    end
                    sc.core.overlay_refresh_config();
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

                    if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
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
                    if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
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
        if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
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
        if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
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
        if sc.overlay.ccf_parent.config_mode and not config.settings.overlay_disable_cc_info then
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
            local dd = label_selection_dropdown(pframe, label_frame_setting_subkey.."_selection", function()
                sc.overlay.ccf_label_reconfig(k);
            end);
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            cfs[#cfs + 1] = dd;
        end
        pframe.y_offset = pframe.y_offset - 20;

    end

    make_frame_scrollable(pframe);
end


local function create_sw_ui_overlay_frame(pframe)

    pframe.y_offset = pframe.y_offset - 5;

    multi_row_checkbutton({
        {
            id = "overlay_disable_in_combat",
            txt = L["Disable in combat"],
            tooltip = client_matches(client_flags.forever) and
                L["Buffs can not be read in combat, so overlay numbers may not be accurate during combat."] or nil,
            func = function()
                sc.core.overlay_refresh_config();
            end
        },
        {
            id = "overlay_disable_in_raid",
            txt = L["Disable in raids"],
            func = function()
                sc.core.overlay_refresh_config();
            end
        },
    }, pframe, 2);

    pframe.y_offset = pframe.y_offset - 30;

    create_subtabs(pframe, {
        {"overlay", L["Spell overlay"]},
        {"cast_info", L["Cast info frame"]},
    });
    create_overlay_spells_frame(pframe.overlay);
    create_overlay_cast_info_frame(pframe.cast_info);
    pframe.overlay_tab:Click();
end

ui.create_sw_ui_overlay_frame = create_sw_ui_overlay_frame;
ui.fonts_setup                = fonts_setup;
ui.get_font                   = get_font;
