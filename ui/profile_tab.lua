local _, sc = ...;

local L      = sc.L;
local config = sc.config;

local ui = sc.ui;
local libDD = ui.libDD;

local function update_profile_frame()

    sc.config.set_active_settings();
    local pframe = __sc_frame.profile_frame;

    pframe.primary_spec.init_func();
    pframe.second_spec.init_func();

    pframe.active_main_spec:Hide();
    pframe.active_second_spec:Hide();
    if sc.core.active_spec == 1 then
        pframe.active_main_spec:Show();
    else
        pframe.active_second_spec:Show();
    end

    pframe.delete_profile_button:Hide();
    pframe.delete_profile_label:Hide();

    local cnt = 0;
    for _, _ in pairs(__sc_p_acc.profiles) do
        cnt = cnt + 1;
        if cnt > 1 then
            break;
        end
    end
    if cnt > 1 then

        pframe.delete_profile_button:Show();
        pframe.delete_profile_label:Show();
    end

    pframe.rename_editbox:SetText(config.active_profile_name);

    __sc_frame.calculator_frame.profile_name_label:SetText(
        L["Active profile: "]..config.active_profile_name
    );
    __sc_frame.loadout_frame.profile_name_label:SetText(
        L["Active profile: "]..config.active_profile_name
    );
    __sc_frame.loadout_frame.update_indicators();
end

local function create_sw_ui_profile_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    local rhs_offset = 250;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Profiles are shared across characters and retain most settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 30;

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
    pframe.active_second_spec:SetPoint("TOPLEFT", rhs_offset+150, pframe.y_offset);
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

ui.average_proc_sidebuffer    = average_proc_sidebuffer;
ui.create_sw_ui_profile_frame = create_sw_ui_profile_frame;
ui.update_profile_frame       = update_profile_frame;
