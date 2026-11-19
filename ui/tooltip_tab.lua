local _, sc = ...;

local L      = sc.L;
local config = sc.config;

local ui = sc.ui;
local create_subtabs         = ui.create_subtabs;
local libDD                  = ui.libDD;
local make_divider           = ui.make_divider;
local make_frame_scrollable  = ui.make_frame_scrollable;
local make_help_icon_tooltip = ui.make_help_icon_tooltip;
local multi_row_checkbutton  = ui.multi_row_checkbutton;
local sw_activate_frame      = ui.sw_activate_frame;

local function create_tooltip_spells_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    pframe.num_tooltip_toggled = 0;

    local tsfs = {};

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

    pframe.y_offset = pframe.y_offset - 10;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 10;

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
            txt = L["Mode and key hints"],
            tooltip = L["Shows the current evaluation mode and how to switch it: CTRL for healing or damage on spells that do both, ALT for single target effect, scroll wheel for other modes."];
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
        --{
        --    id = "tooltip_display_base_mod",
        --    txt = L["Base effect mod"],
        --    color_tag = "sp_effect",
        --    tooltip = L["Intended for debugging."]
        --},
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
        {
            id = "tooltip_display_ehp",
            txt = L["Effective health"],
            color_tag = "expectation",
            tooltip = sc.overlay.label_handler.overlay_display_ehp.tooltip,
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
        getglobal("__sc_frame_setting_tooltip_display_ehp"):Click();

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
        getglobal("__sc_frame_setting_tooltip_display_ehp"):Click();
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

    make_frame_scrollable(pframe);
end


local function create_tooltip_items_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    local tifs = {};

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
    local help_icon = make_help_icon_tooltip(
        nil,
        pframe,
        L["Item comparison in tooltips"],
            " * "..L["Hold SHIFT key to show stat changes"].."\n"..
            " * "..L["Hold ALT key to switch between evaluation modes"].."\n"..
            " * "..L["Evaluation is fully computed, not extrapolated from stat weights"].."\n"..
            " * "..L["Item tooltips are never parsed for its text, making this localization agnostic"]
    );
    help_icon:SetPoint("LEFT", getglobal("__sc_frame_setting_tooltip_disable_itemText"), "RIGHT", 5, 0);

    pframe.y_offset = pframe.y_offset - 10;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 2;

    local function section(title)
        pframe.y_offset = pframe.y_offset - 12;
        local txt = pframe:CreateFontString(nil, "OVERLAY");
        txt:SetFontObject(GameFontNormal);
        txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
        txt:SetText(title);
        txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
        pframe.y_offset = pframe.y_offset - 20;
        tifs[#tifs + 1] = txt;
    end

    local function checks(list, num_columns)
        local frames = multi_row_checkbutton(list, pframe, num_columns);
        for _, v in ipairs(frames) do
            tifs[#tifs + 1] = v;
        end
        if #list % num_columns ~= 0 then
            pframe.y_offset = pframe.y_offset - 20;
        end
        return frames;
    end

    section(L["Tooltip display"]);
    checks({
        {
            id = "tooltip_item_key_hints",
            txt = L["Modifier key hints"],
            tooltip = L["SHIFT: Stats | ALT: Switch mode"],
        },
    }, 1);
    checks({
        {
            id = "tooltip_item_stat_diff",
            txt = L["Always show stat changes"],
        },
        {
            id = "tooltip_item_weapon_skill",
            txt = L["Show skill levels for weapons"],
        },
    }, 2);

    section(L["Compared spells"]);
    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        sw_activate_frame("calculator_frame");
    end);

    f:SetPoint("TOPLEFT", 12, pframe.y_offset);
    f:SetHeight(20);
    f:SetWidth(200);
    f:SetText(L["Configure spell list"]);
    tifs[#tifs + 1] = f;
    pframe.y_offset = pframe.y_offset - 26;
    checks({
        {
            id = "tooltip_item_smart",
            txt = L["Smarter tooltip"],
            tooltip = L["Adds/removes some sensible aspects of the tooltip. Examples: Never showing Attack for caster classes or for cloth items; Show wand spell for wands; etc"],
        },
        {
            id = "tooltip_item_leveling_skill_normalize",
            txt = L["Use skill as clvl*5 for weapon comparisons when not at maximum level"],
            tooltip = L["More intuitive weapon upgrade results when leveling since lower weapon skill type is not punished"],
        },
    }, 1);

    section(L["Included item changes"]);
    checks({
        {
            id = "tooltip_item_apply_enchant",
            txt = L["Apply enchant changes"],
        },
        {
            id = "tooltip_item_apply_gems",
            txt = L["Apply gem changes"],
        },
        {
            id = "tooltip_item_apply_set_bonuses",
            txt = L["Apply set bonus changes"],
        },
    }, 2);

    section(L["Items to compare"]);
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset - 5);
    f_txt:SetText(L["Quality threshold"]);
    f_txt:SetTextColor(1.0, 1.0, 1.0);
    tifs[#tifs + 1] = f_txt;

    pframe.quality_dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_tooltip_item_quality_threshold", pframe);
    pframe.quality_dd._type = "DropDownMenu";
    pframe.quality_dd:SetPoint("LEFT", f_txt, "RIGHT", -5, -3);
    local qualities = {
        [0] = L["Poor"],
        [1] = L["Common"],
        [2] = L["Uncommon"],
        [3] = L["Rare"],
        [4] = L["Epic"],
        [5] = L["Legendary"],
    };
    -- init_func only refreshes the shown text, the menu is built when it opens
    pframe.quality_dd.init_func = function()
        if config.settings.tooltip_item_quality_threshold < 0 or
            config.settings.tooltip_item_quality_threshold > 5 then
            config.settings.tooltip_item_quality_threshold = 2;
        end
        local idx = config.settings.tooltip_item_quality_threshold;
        libDD:UIDropDownMenu_SetText(
            pframe.quality_dd,
            ITEM_QUALITY_COLORS[idx].color:WrapTextInColorCode(qualities[idx])
        );
    end;
    libDD:UIDropDownMenu_SetWidth(pframe.quality_dd, 120);
    libDD:UIDropDownMenu_SetInitializeFunction(pframe.quality_dd, function()
        for i = 0, 5 do
            libDD:UIDropDownMenu_AddButton({
                text = ITEM_QUALITY_COLORS[i].color:WrapTextInColorCode(qualities[i]),
                checked = config.settings.tooltip_item_quality_threshold == i,
                func = function()
                    config.settings.tooltip_item_quality_threshold = i;
                    pframe.quality_dd.init_func();
                end
            })
        end
    end);
    tifs[#tifs + 1] = pframe.quality_dd;

    pframe.y_offset = pframe.y_offset - 28;

    checks({
        {
            id = "tooltip_item_ignore_unequippable",
            txt = L["Ignore unequippable by class"],
        },
    }, 1);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontHighlight);
    f_txt:SetPoint("TOPLEFT", 15, pframe.y_offset - 5);
    f_txt:SetText(L["Ignore armor type:"]);
    tifs[#tifs + 1] = f_txt;
    local armor_checks = checks({
        {
            id = "tooltip_item_ignore_cloth",
            txt = L["Cloth"],
        },
        {
            id = "tooltip_item_ignore_leather",
            txt = L["Leather"],
        },
        {
            id = "tooltip_item_ignore_mail",
            txt = L["Mail"],
        },
        {
            id = "tooltip_item_ignore_plate",
            txt = L["Plate"],
        },
    }, 4);
    -- one row after the label, each box right after the previous text, clickable on its own text only
    local x = 30 + f_txt:GetStringWidth();
    for _, v in ipairs(armor_checks) do
        local w = getglobal(v:GetName() .. "Text"):GetStringWidth();
        local _, _, _, _, y = v:GetPoint(1);
        v:ClearAllPoints();
        v:SetPoint("TOPLEFT", x, y);
        v:SetHitRectInsets(0, -w, 0, 0);
        x = x + w + 40;
    end

    pframe.y_offset = pframe.y_offset - 10;

    make_frame_scrollable(pframe);
end


local function create_sw_ui_tooltip_frame(pframe)

    pframe.y_offset = pframe.y_offset - 5;

    local tooltip_general_checks = {
        {
            id = "tooltip_shift_to_show",
            txt = L["Require SHIFT to show tooltips"]
        },
    };

    multi_row_checkbutton(tooltip_general_checks, pframe, 2);
    pframe.y_offset = pframe.y_offset - 50;

    create_subtabs(pframe, {
        {"spells", L["Spells"]},
        {"items", L["Items"]},
    });
    create_tooltip_spells_frame(pframe.spells);
    create_tooltip_items_frame(pframe.items);
    pframe.spells_tab:Click();
end

ui.create_sw_ui_tooltip_frame = create_sw_ui_tooltip_frame;
