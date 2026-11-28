local _, sc = ...;

local L                  = sc.L;
local format_locale_dump = sc.loc.format_locale_dump;
local assign_color_tag   = sc.utils.assign_color_tag;
local effect_color       = sc.utils.effect_color;
local config             = sc.config;

local ui = sc.ui;
local average_proc_sidebuffer   = ui.average_proc_sidebuffer;
local dump_text                 = ui.dump_text;
local libDD                     = ui.libDD;
local libstub_icon              = ui.libstub_icon;
local make_divider              = ui.make_divider;
local make_frame_scrollable     = ui.make_frame_scrollable;
local multi_row_checkbutton     = ui.multi_row_checkbutton;
local register_text_frame_color = ui.register_text_frame_color;

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

        make_divider(pframe);
        pframe.y_offset = pframe.y_offset - 10;
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

    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 10;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    local spell_settings = {
        {
            id = "general_prio_heal",
            txt = L["Default to healing for hybrid spells with both damage and healing"],
        },
        {
            id = "general_prio_multiplied_effect",
            txt = L["Default to optimistic effect over single effect"],
        },
        {
            id = "general_average_proc_effects",
            txt = L["Average out class proc effects"],
            tooltip = L["Instead of counting these buffs only while they are up, their effect is averaged into every evaluation, so the stats that trigger them get their real value. Example: Nature's Grace lowers the expected cast time by your chance to crit, Clearcasting lowers the expected cost."],
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
        {
            id = "general_on_hit_procs",
            txt = L["On hit procs (items, enchants, seals)"],
            tooltip = L["Adds the expected damage of on hit effects to attacks and the abilities that trigger them. Example: Windfury, Hand of Justice, chance on hit weapons and weapon enchants."],
        },
    };

    multi_row_checkbutton(spell_settings, pframe, 1);

    pframe.y_offset = pframe.y_offset - 10;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 10;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Calculator settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

    local calc_settings = {
        {
            id = "general_calc_secondary_tooltip",
            txt = L["Before and after comparison tooltips"],
        },
        {
            id = "general_calc_global_compare",
            txt = L["Enable calculator mode globally, even if tab is closed"],
        },
        {
            id = "general_calc_stats_raw_dump",
            txt = L["Debug: Effect diffs visualizations as raw dump"],
        },
    };
    multi_row_checkbutton(calc_settings, pframe, 1);

    pframe.y_offset = pframe.y_offset - 10;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 10;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Color palette RGB"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 20;

    local color_tags = {
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
        {"cost_per_sec", L["Cost per second"]},
        {"effect_until_oom", L["Effect until OOM"]},
        {"casts_until_oom", L["Casts until OOM"]},
        {"time_until_oom", L["Time until OOM"]},
        {"sp_effect", L["Spell info internals (coefs etc)"]},
        {"stat_weights", L["Stat weights"]},
        {"spell_rank", L["Spell rank"]},
    };
    local color_comps = {"_r", "_g", "_b"};
    local selected_color = 1;

    -- settings is the profile the edit started on, a profile switch while the picker is open leaves the new one alone
    local function set_color(settings, tag, r, g, b)
        for i, c in ipairs({r, g, b}) do
            local val = math.floor(c * 255 + 0.5);
            settings["general_color_"..tag..color_comps[i]] = val;
            if settings == config.settings then
                assign_color_tag(tag, i, val);
            end
        end
        if settings == config.settings then
            sc.ui.apply_colors(tag);
        end
    end

    local function set_default_color(tag)
        local d = config.default_settings;
        local key = "general_color_"..tag;
        set_color(config.settings, tag, d[key.."_r"]/255, d[key.."_g"]/255, d[key.."_b"]/255);
    end

    local color_dd = libDD:Create_UIDropDownMenu("__sc_frame_color_tag", pframe);
    color_dd:SetPoint("TOPLEFT", -6, pframe.y_offset+3);

    local swatch = CreateFrame("Button", nil, pframe);
    swatch:SetSize(20, 20);
    swatch:SetPoint("TOPLEFT", 225, pframe.y_offset);
    local swatch_border = swatch:CreateTexture(nil, "BACKGROUND");
    swatch_border:SetAllPoints();
    swatch_border:SetColorTexture(0.8, 0.8, 0.8, 1.0);
    swatch.tex = swatch:CreateTexture(nil, "ARTWORK");
    swatch.tex:SetPoint("TOPLEFT", 2, -2);
    swatch.tex:SetPoint("BOTTOMRIGHT", -2, 2);
    local swatch_hl = swatch:CreateTexture(nil, "HIGHLIGHT");
    swatch_hl:SetAllPoints(swatch.tex);
    swatch_hl:SetColorTexture(1.0, 1.0, 1.0, 0.25);

    local function show_selected_color()
        local tag = color_tags[selected_color][1];
        libDD:UIDropDownMenu_SetText(color_dd, color_tags[selected_color][2]);
        color_dd.Text:SetTextColor(effect_color(tag));
        register_text_frame_color(color_dd.Text, tag);
        swatch.tex:SetColorTexture(effect_color(tag));
        register_text_frame_color(swatch.tex, tag);
    end

    libDD:UIDropDownMenu_SetWidth(color_dd, 190);
    libDD:UIDropDownMenu_SetInitializeFunction(color_dd, function()
        for i, v in ipairs(color_tags) do
            local r, g, b = effect_color(v[1]);
            libDD:UIDropDownMenu_AddButton({
                text = CreateColor(r, g, b, 1.0):WrapTextInColorCode(v[2]),
                checked = i == selected_color,
                func = function()
                    selected_color = i;
                    show_selected_color();
                end,
            });
        end
    end);

    swatch:SetScript("OnClick", function()
        local tag = color_tags[selected_color][1];
        local settings = config.settings;
        local r, g, b = effect_color(tag);
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            hasOpacity = false,
            swatchFunc = function()
                set_color(settings, tag, ColorPickerFrame:GetColorRGB());
            end,
            cancelFunc = function()
                set_color(settings, tag, ColorPickerFrame:GetPreviousValues());
            end,
        });
    end);

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", 255, pframe.y_offset+1);
    f:SetText(L["Default"]);
    f:SetWidth(80);
    f:SetScript("OnClick", function()
        set_default_color(color_tags[selected_color][1]);
    end);

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetPoint("TOPLEFT", 10, pframe.y_offset+1);
    f:SetText(L["Reset all colors to default"]);
    f:SetWidth(200);
    f:SetScript("OnClick", function()
        for _, v in ipairs(color_tags) do
            set_default_color(v[1]);
        end
    end);

    show_selected_color();
    pframe.y_offset = pframe.y_offset - 25;

    make_frame_scrollable(pframe);
end

ui.create_sw_ui_settings_frame = create_sw_ui_settings_frame;
