local _, sc = ...;

local L                    = sc.L;
local config               = sc.config;
local spells               = sc.spells;
local spell_flags          = sc.spell_flags;
local fight_types          = sc.calc.fight_types;
local highest_learned_rank = sc.utils.highest_learned_rank;
local client_matches       = sc.utils.client_matches;
local client_flags         = sc.client_flags;

local ui = sc.ui;
local compared_spells_changed = ui.compared_spells_changed;
local ehp_tex                = ui.ehp_tex;
local font                   = ui.font;
local create_subtabs         = ui.create_subtabs;
local libDD                  = ui.libDD;
local make_divider           = ui.make_divider;
local make_frame_scrollable  = ui.make_frame_scrollable;
local make_help_icon_tooltip = ui.make_help_icon_tooltip;
local multi_row_checkbutton  = ui.multi_row_checkbutton;
local make_dodge_drag_button = ui.make_dodge_drag_button;

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
            id = "tooltip_display_res_details",
            txt = L["Resistance & armor details"],
            color_tag = "avoidance_info"
        },
        {
            id = "tooltip_display_partial_resists",
            txt = L["Partial resists & pierce"],
            color_tag = "avoidance_info"
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
            id = "tooltip_display_ehp",
            txt = L["Effective health"],
            color_tag = "expectation",
            tooltip = sc.overlay.label_handler.overlay_display_ehp.tooltip,
        },
        {
            id = "tooltip_display_resource_regen",
            txt = L["Resource restoration"],
            tooltip = sc.overlay.label_handler.overlay_display_resource_regen.tooltip,
            color_tag = "cost",
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
        getglobal("__sc_frame_setting_tooltip_display_res_details"):Click();
        getglobal("__sc_frame_setting_tooltip_display_partial_resists"):Click();
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

    -- the last two (effective health, resource restoration) are not about a spell's effect: below a divider
    local num_separate = 2;
    local groups = { {}, {} };
    for i, v in ipairs(tooltip_components) do
        local g = groups[1];
        if i > #tooltip_components - num_separate then
            g = groups[2];
        end
        g[#g + 1] = v;
    end
    pframe.y_offset = pframe.y_offset - 10;
    for k, group in ipairs(groups) do
        if k > 1 then
            if #groups[k - 1] % 2 == 1 then
                pframe.y_offset = pframe.y_offset - 20;
            end
            pframe.y_offset = pframe.y_offset - 5;
            make_divider(pframe);
            pframe.y_offset = pframe.y_offset - 8;
        end
        for _, v in pairs(multi_row_checkbutton(group, pframe, k == 1 and 2 or 1, tooltip_toggle)) do
            tsfs[#tsfs + 1] = v;
        end
    end

    -- clicks on the Dodge icon next to it must not toggle the option
    local ehp_check = getglobal("__sc_frame_setting_tooltip_display_ehp");
    local ehp_text = getglobal(ehp_check:GetName().."Text");
    ehp_check:SetHitRectInsets(0, -ehp_text:GetStringWidth(), 0, 0);
    make_dodge_drag_button(pframe, ehp_check:GetFrameLevel() + 2):SetPoint("LEFT", ehp_text, "RIGHT", 10, 0);
    pframe.y_offset = pframe.y_offset - 25;

    make_frame_scrollable(pframe);
end


-- the comparison list at the frame's y offset: icon, name, move up / down and remove per entry, scrolls past num_rows
local function create_compared_spells_list(pframe)
    local row_height = 16;
    local num_rows = 6;
    local area = CreateFrame("Frame", nil, pframe);
    area:SetPoint("TOPLEFT", 0, pframe.y_offset);
    area:SetPoint("RIGHT", pframe, "RIGHT", -20, 0);
    area:SetHeight(num_rows * row_height + 4);
    pframe.y_offset = pframe.y_offset - num_rows * row_height - 4;
    local rows = {};
    local entries = {};
    local offset = 0;

    local bg = area:CreateTexture(nil, "BACKGROUND");
    bg:SetPoint("TOPLEFT", 8, 0);
    bg:SetPoint("BOTTOMRIGHT", 0, 0);
    bg:SetColorTexture(0, 0, 0, 0.3);

    -- area.flash(): a gold glow pulsing twice, where links to the list land
    local glow = area:CreateTexture(nil, "OVERLAY");
    glow:SetAllPoints(bg);
    glow:SetColorTexture(1, 0.8, 0, 1);
    glow:SetBlendMode("ADD");
    glow:SetAlpha(0);
    local flash = glow:CreateAnimationGroup();
    for i, v in ipairs({ { 0, 0.25, 0.15 }, { 0.25, 0, 0.35 }, { 0, 0.25, 0.15 }, { 0.25, 0, 0.5 } }) do
        local a = flash:CreateAnimation("Alpha");
        a:SetFromAlpha(v[1]);
        a:SetToAlpha(v[2]);
        a:SetDuration(v[3]);
        a:SetOrder(i);
    end
    area.flash = function()
        flash:Stop();
        flash:Play();
    end;

    local slider = CreateFrame("Slider", nil, area, "UIPanelScrollBarTrimTemplate");
    slider:SetOrientation('VERTICAL');
    slider:SetPoint("TOPLEFT", area, "TOPRIGHT", 0, -16);
    slider:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 0, 16);
    slider:SetWidth(20);
    local show_rows;
    -- replaces the template's script, which scrolls the parent as a ScrollFrame, before any value is set
    slider:SetScript("OnValueChanged", function(_, val)
        local new_offset = math.max(0, math.floor(val + 0.5));
        if new_offset ~= offset then
            offset = new_offset;
            show_rows();
        end
    end);
    slider.scrollStep = 1;
    slider:SetValueStep(1);
    slider:SetMinMaxValues(0, 0);
    slider:SetValue(0);
    slider:Hide();
    local slider_bg = slider:CreateTexture(nil, "BACKGROUND");
    slider_bg:SetAllPoints(slider);
    slider_bg:SetColorTexture(0, 0, 0, 0.5);

    area:EnableMouseWheel(true);
    area:SetScript("OnMouseWheel", function(_, delta)
        slider:SetValue(slider:GetValue() - delta);
    end);

    -- swaps the list positions of entries i and j, entries the list UI hides keep their place
    local function swap_entries(i, j)
        local list = config.compared_spell_list();
        local a, b = entries[i].list_index, entries[j].list_index;
        list[a], list[b] = list[b], list[a];
        compared_spells_changed();
    end

    local function make_arrow_button(dir)
        local btn = CreateFrame("Button", nil, area);
        btn:SetSize(16, 16);
        local tex = "Interface\\Buttons\\UI-ScrollBar-Scroll"..dir.."Button-";
        btn:SetNormalTexture(tex.."Up");
        btn:SetPushedTexture(tex.."Down");
        btn:SetDisabledTexture(tex.."Disabled");
        btn:SetHighlightTexture(tex.."Highlight", "ADD");
        for _, v in ipairs({btn:GetNormalTexture(), btn:GetPushedTexture(), btn:GetDisabledTexture(), btn:GetHighlightTexture()}) do
            v:SetTexCoord(0.2, 0.8, 0.25, 0.75);
        end
        return btn;
    end

    local function make_row(r)
        local y = -2 - row_height * (r - 1);
        local row = {};

        row.stripe = area:CreateTexture(nil, "BACKGROUND", nil, 1);
        row.stripe:SetPoint("TOPLEFT", 8, y);
        row.stripe:SetPoint("RIGHT", area, "RIGHT", 0, 0);
        row.stripe:SetHeight(row_height);
        row.stripe:SetColorTexture(1, 1, 1, 0.06);

        row.highlight = area:CreateTexture(nil, "BORDER");
        row.highlight:SetPoint("TOPLEFT", 8, y);
        row.highlight:SetPoint("RIGHT", area, "RIGHT", 0, 0);
        row.highlight:SetHeight(row_height);
        row.highlight:SetColorTexture(1, 1, 1, 0.08);
        row.highlight:Hide();

        row.icon = area:CreateTexture(nil, "ARTWORK");
        row.icon:SetSize(15, 15);
        row.icon:SetPoint("TOPLEFT", 12, y);

        row.name_str = area:CreateFontString(nil, "OVERLAY");
        row.name_str:SetFontObject(font);
        row.name_str:SetPoint("TOPLEFT", 32, y - 2);

        row.remove = CreateFrame("Button", nil, area, "UIPanelButtonTemplate");
        row.remove:SetPoint("TOPRIGHT", -4, y);
        row.remove:SetSize(16, 16);
        row.remove:SetText("x");
        local fontstr = row.remove:GetFontString();
        if fontstr then
            fontstr:ClearAllPoints();
            fontstr:SetPoint("CENTER", row.remove, "CENTER");
            fontstr:SetIgnoreParentAlpha(true);
            fontstr:SetMouseClickEnabled(false);
        end
        row.remove:SetScript("OnClick", function(self)
            table.remove(config.compared_spell_list(), entries[self.entry].list_index);
            compared_spells_changed();
        end);

        row.down = make_arrow_button("Down");
        row.down:SetPoint("RIGHT", row.remove, "LEFT", -4, 0);
        row.down:SetScript("OnClick", function(self)
            swap_entries(self.entry, self.entry + 1);
        end);
        row.up = make_arrow_button("Up");
        row.up:SetPoint("RIGHT", row.down, "LEFT", 0, 0);
        row.up:SetScript("OnClick", function(self)
            swap_entries(self.entry, self.entry - 1);
        end);

        row.hover = CreateFrame("Frame", nil, area);
        row.hover:SetPoint("TOPLEFT", 8, y);
        row.hover:SetPoint("RIGHT", row.up, "LEFT", -4, 0);
        row.hover:SetHeight(row_height);
        row.hover:EnableMouse(true);
        row.hover:SetScript("OnEnter", function(self)
            row.highlight:Show();
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetSpellByID(self.spell_id);
            GameTooltip:Show();
        end);
        row.hover:SetScript("OnLeave", function()
            row.highlight:Hide();
            GameTooltip:Hide();
        end);
        return row;
    end

    show_rows = function()
        local max_offset = math.max(0, #entries - num_rows);
        slider:SetMinMaxValues(0, max_offset);
        slider:SetShown(max_offset > 0);
        if offset > max_offset then
            offset = max_offset;
            slider:SetValue(max_offset);
        end
        for r = 1, num_rows do
            local i = offset + r;
            local e = entries[i];
            local row = rows[r];
            if e then
                if not row then
                    row = make_row(r);
                    rows[r] = row;
                end
                row.icon:SetTexture(e.tex);
                row.name_str:SetText(e.disp);
                if e.compared then
                    row.name_str:SetTextColor(222/255, 192/255, 40/255);
                else
                    row.name_str:SetTextColor(0.5, 0.5, 0.5);
                end
                row.hover.spell_id = e.id;
                row.remove.entry = i;
                row.up.entry = i;
                row.down.entry = i;
                for k, v in pairs(row) do
                    if k ~= "highlight" then
                        v:Show();
                    end
                end
                row.stripe:SetShown(i % 2 == 1);
                row.up:SetEnabled(i > 1);
                row.down:SetEnabled(i < #entries);
            elseif row then
                for _, v in pairs(row) do
                    v:Hide();
                end
            end
        end
    end

    -- entries as the tooltips compare them: the highest learned rank when set, greyed when no rank is learned
    local function refresh()
        entries = {};
        for list_index, k in ipairs(config.compared_spell_list()) do
            local spell = spells[k];
            if spell and bit.band(spell.flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0 then
                local id = k;
                if config.settings.calc_list_use_highest_rank then
                    id = highest_learned_rank(spell.base_id);
                end
                local e = { list_index = list_index, id = id or k, compared = id ~= nil };
                spell = spells[e.id];
                if bit.band(spell.flags, spell_flags.eval) ~= 0 then
                    e.name = C_Spell.GetSpellName(e.id);
                    e.tex = C_Spell.GetSpellTexture(e.id);
                    e.disp = e.name;
                    if spell.rank ~= 0 then
                        e.disp = string.format("%s|cFFA9A9A9 %s %d|r", e.name, L["Rank"], spell.rank);
                    end
                else
                    e.name = L["Effective Health"];
                    e.tex = ehp_tex;
                    e.disp = e.name;
                end
                entries[#entries + 1] = e;
            end
        end
        show_rows();
    end

    area:SetScript("OnShow", refresh);
    return area, refresh;
end

local function create_tooltip_items_frame(pframe)

    local f_txt;
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

    pframe.y_offset = pframe.y_offset - 8;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 2;

    local function section(title)
        pframe.y_offset = pframe.y_offset - 4;
        local txt = pframe:CreateFontString(nil, "OVERLAY");
        txt:SetFontObject(GameFontNormal);
        txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
        txt:SetText(title);
        txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
        pframe.y_offset = pframe.y_offset - 18;
        tifs[#tifs + 1] = txt;
        return txt;
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

    -- a setting's name on its own line, its control placed right of it
    local function label(text)
        local txt = pframe:CreateFontString(nil, "OVERLAY");
        txt:SetFontObject(GameFontNormal);
        txt:SetPoint("TOPLEFT", 15, pframe.y_offset - 5);
        txt:SetText(text);
        txt:SetTextColor(1.0, 1.0, 1.0);
        tifs[#tifs + 1] = txt;
        return txt;
    end

    section(L["Tooltip display"]);
    checks({
        {
            id = "tooltip_item_key_hints",
            txt = L["Modifier key hints"],
            tooltip = L["SHIFT: Stats | ALT: Switch mode"],
        },
        {
            id = "tooltip_item_smart",
            txt = L["Smarter tooltip"],
            tooltip = L["Adds/removes some sensible aspects of the tooltip. Examples: Never showing Attack for caster classes or for cloth items; Show wand spell for wands; etc"],
        },
        {
            id = "tooltip_item_weapon_skill",
            txt = L["Show skill levels for weapons"],
        },
    }, 2);


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
    f_txt = label(L["Quality threshold"]);

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

    pframe.y_offset = pframe.y_offset - 25;

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

    section(L["Compared spells"]);
    f_txt = label(L["Evaluation mode:"]);
    pframe.fight_type_dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_calc_fight_type", pframe);
    pframe.fight_type_dd._type = "DropDownMenu";
    pframe.fight_type_dd:SetPoint("LEFT", f_txt, "RIGHT", -5, -3);
    pframe.fight_type_dd.init_func = function()
        if config.settings.calc_fight_type == fight_types.repeated_casts then
            libDD:UIDropDownMenu_SetText(pframe.fight_type_dd, L["Repeated casts"]);
        elseif config.settings.calc_fight_type == fight_types.cast_until_oom then
            libDD:UIDropDownMenu_SetText(pframe.fight_type_dd, L["Cast until OOM"]);
        end
    end;
    libDD:UIDropDownMenu_SetWidth(pframe.fight_type_dd, 120);
    libDD:UIDropDownMenu_SetInitializeFunction(pframe.fight_type_dd, function()
        for _, v in ipairs({
            { fight_types.repeated_casts, L["Repeated casts"] },
            { fight_types.cast_until_oom, L["Cast until OOM"] },
        }) do
            libDD:UIDropDownMenu_AddButton(
                {
                    text = v[2],
                    checked = config.settings.calc_fight_type == v[1],
                    func = function()
                        config.settings.calc_fight_type = v[1];
                        sc.loadouts.force_update = true;
                        pframe.fight_type_dd.init_func();
                    end
                }
            );
        end
    end);
    tifs[#tifs + 1] = pframe.fight_type_dd;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("LEFT", pframe.fight_type_dd, "RIGHT", -8, 3);
    f_txt:SetText(L["ALT switches it in tooltips"]);
    f_txt:SetTextColor(0.6, 0.6, 0.6);
    tifs[#tifs + 1] = f_txt;
    pframe.y_offset = pframe.y_offset - 25;

    local refresh_list;
    checks({
        {
            id = "calc_list_use_highest_rank",
            txt = L["Use highest learned rank"],
            func = function()
                refresh_list();
            end,
        },
        {
            id = "tooltip_item_leveling_skill_normalize",
            txt = L["Use skill as clvl*5 for weapon comparisons when not at maximum level"],
            tooltip = L["More intuitive weapon upgrade results when leveling since lower weapon skill type is not punished"],
            func = function()
                sc.loadouts.force_update = true;
            end,
        },
    }, 1);

    pframe.y_offset = pframe.y_offset - 2;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 12, pframe.y_offset);
    f_txt:SetText(L["Abilities can be added from the Spells tab"]);
    f_txt:SetTextColor(0.6, 0.6, 0.6);
    tifs[#tifs + 1] = f_txt;
    pframe.y_offset = pframe.y_offset - 13;

    local list_area;
    list_area, refresh_list = create_compared_spells_list(pframe);
    tifs[#tifs + 1] = list_area;
    pframe.compared_list = list_area;
    ui.refresh_compared_spells = refresh_list;

    make_frame_scrollable(pframe);
end


local function create_tooltip_stat_lines_frame(pframe)
    local stat_lines = sc.stat_lines;
    local boxes = {};
    local refresh;

    local function available(id)
        return stat_lines.cell_names[id] ~= nil and
            not (id == "def.resilience" and client_matches(bit.bor(client_flags.vanilla, client_flags.forever)));
    end

    local function set_cells(ids, on)
        for _, id in ipairs(ids) do
            stat_lines.set_cell(id, on);
        end
        sc.loadouts.force_update = true;
        __sc_frame.calculator_frame.calculator_plan_changed = true;
        refresh();
    end

    local function toggle_all(ids)
        local shown = stat_lines.shown_cells();
        local all_on = true;
        for _, id in ipairs(ids) do
            all_on = all_on and shown[id];
        end
        set_cells(ids, not all_on);
    end

    local header_r, header_g, header_b = 232.0/255, 225.0/255, 32.0/255;

    local function cell_box(id, txt, title)
        local f = CreateFrame("CheckButton", "__sc_frame_stat_line_"..id:gsub("%.", "_"), pframe,
            "ChatConfigCheckButtonTemplate");
        local fstr = getglobal(f:GetName().."Text");
        fstr:SetText(txt or "");
        f:SetHitRectInsets(0, txt and -fstr:GetStringWidth() or 0, 0, 0);
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(title or txt, 1, 0.82, 0);
            for _, name in ipairs(stat_lines.cell_names[id]) do
                GameTooltip:AddLine("- "..name, 1, 1, 1);
            end
            GameTooltip:Show();
        end);
        f:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
        f:SetScript("OnClick", function(self)
            set_cells({id}, self:GetChecked() and true or false);
        end);
        boxes[id] = f;
        return f, txt and fstr:GetStringWidth() or 0;
    end

    local function toggle_label(text, x, y, ids, title, width, justify)
        local btn = CreateFrame("Button", nil, pframe);
        btn:SetPoint("TOPLEFT", x, y);
        local fstr = btn:CreateFontString(nil, "OVERLAY");
        fstr:SetFontObject(title and GameFontNormal or GameFontHighlight);
        fstr:SetText(text);
        fstr:SetAllPoints(btn);
        fstr:SetJustifyH(justify or "LEFT");
        btn:SetSize(width or fstr:GetStringWidth() + 4, 18);
        local r, g, b = 1, 1, 1;
        if title then
            r, g, b = header_r, header_g, header_b;
        end
        fstr:SetTextColor(r, g, b);
        btn:SetScript("OnClick", function()
            toggle_all(ids);
        end);
        btn:SetScript("OnEnter", function(self)
            if title then
                fstr:SetTextColor(1, 1, 1);
            else
                fstr:SetTextColor(header_r, header_g, header_b);
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(L["Click to toggle all"], 1, 1, 1);
            GameTooltip:Show();
        end);
        btn:SetScript("OnLeave", function()
            fstr:SetTextColor(r, g, b);
            GameTooltip:Hide();
        end);
        return btn;
    end

    pframe.y_offset = pframe.y_offset - 8;
    local header = pframe:CreateFontString(nil, "OVERLAY");
    header:SetFontObject(GameFontNormal);
    header:SetPoint("TOPLEFT", 5, pframe.y_offset);
    local defaults_btn = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    defaults_btn:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -20, pframe.y_offset + 4);
    defaults_btn:SetSize(120, 22);
    defaults_btn:SetText(L["Class defaults"]);
    defaults_btn:SetScript("OnClick", function()
        stat_lines.reset_class_cells();
        sc.loadouts.force_update = true;
        __sc_frame.calculator_frame.calculator_plan_changed = true;
        refresh();
    end);
    pframe.y_offset = pframe.y_offset - 22;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 2;

    local box_x = 10;
    local box_width = 24;
    local right_edge = pframe:GetWidth() - 8;

    local function section_title(title, ids)
        pframe.y_offset = pframe.y_offset - 2;
        toggle_label(title, 0, pframe.y_offset, ids, true);
        pframe.y_offset = pframe.y_offset - 18;
    end

    local lists = {};
    local list_col_w = 0;
    local function list_block(title, prefix, keys, labels)
        local list = { title = title, entries = {}, ids = {} };
        for _, k in ipairs(keys) do
            local id = prefix..k;
            if available(id) then
                local f, w = cell_box(id, labels[k]);
                list.entries[#list.entries + 1] = f;
                list.ids[#list.ids + 1] = id;
                list_col_w = math.max(list_col_w, box_width + w + 8);
            end
        end
        lists[#lists + 1] = list;
        return list;
    end

    local function place_list(list)
        section_title(list.title, list.ids);
        local per_row = math.max(1, math.floor((right_edge - box_x) / list_col_w));
        if list.per_row then
            per_row = math.min(per_row, list.per_row);
        end
        for i, f in ipairs(list.entries) do
            local col = (i - 1) % per_row;
            f:SetPoint("TOPLEFT", box_x + col * list_col_w, pframe.y_offset);
            if col == per_row - 1 or i == #list.entries then
                pframe.y_offset = pframe.y_offset - 20;
            end
        end
        pframe.y_offset = pframe.y_offset - 2;
    end

    -- Strength, Agility, Intellect on one row, Stamina and Spirit below
    local attributes = list_block(L["Attributes"], "attr.", { "str", "agi", "int", "sta", "spi" }, {
        str = L["Strength"], agi = L["Agility"], sta = L["Stamina"], int = L["Intellect"], spi = L["Spirit"],
    });
    attributes.per_row = 3;
    local resources = list_block(L["Resources"], "res.", stat_lines.resource_keys, {
        health = L["Health"], mana = L["Mana"], regen = L["Mana regen"],
    });
    local defense = list_block(L["Defense"], "def.", stat_lines.defense_keys, {
        armor = L["Armor"], defense = L["Defense"], dodge = L["Dodge"], parry = L["Parry"], block = L["Block"],
        resilience = L["Resilience"],
    });
    local abilities = list_block(L["Abilities"], "abil.", stat_lines.ability_keys, {
        mod = L["Modifiers"], hit = L["Hit"], crit = L["Critical"], cost = L["Cost"], cast = L["Cast time"],
        dur = L["Duration"], threat = L["Threat"],
    });

    place_list(attributes);
    place_list(resources);

    local row_labels = {
        power = L["Power"], hit = L["Hit"], crit = L["Critical"], haste = L["Haste"], pen = L["Penetration"],
        dmg = L["Damage %"], threat = L["Threat"], weapon = L["Weapon"], procs = L["On hit procs"],
    };
    local column_labels = { melee = L["Melee"], ranged = L["Ranged"], spell = L["Spell damage"], heal = L["Healing"] };
    local measure = pframe:CreateFontString(nil, "OVERLAY");
    measure:SetFontObject(GameFontHighlight);
    local function text_width(text)
        measure:SetText(text);
        return measure:GetStringWidth();
    end
    local label_w = 0;
    for _, row in ipairs(stat_lines.rows) do
        label_w = math.max(label_w, text_width(row_labels[row[1]]));
    end
    local col_w = 60;
    for _, col in ipairs(stat_lines.columns) do
        col_w = math.max(col_w, text_width(column_labels[col]) + 12);
    end
    measure:SetText("");
    local col_x0 = math.max(box_x + label_w + 16, right_edge - #stat_lines.columns * col_w);
    local row_h = 17;

    pframe.y_offset = pframe.y_offset - 4;
    local header_y = pframe.y_offset;
    pframe.y_offset = pframe.y_offset - 20;
    local all_ids = {};
    local column_ids = {};
    for _, col in ipairs(stat_lines.columns) do
        column_ids[col] = {};
    end
    local n_rows = 0;
    for _, row in ipairs(stat_lines.rows) do
        local row_ids = {};
        local row_boxes = {};
        for c, col in ipairs(stat_lines.columns) do
            local id = col.."."..row[1];
            if row[2][col] and available(id) then
                local f = cell_box(id, nil, column_labels[col]..": "..row_labels[row[1]]);
                f:SetPoint("TOPLEFT", col_x0 + (c - 1) * col_w + col_w / 2 - box_width / 2, pframe.y_offset + 3);
                row_ids[#row_ids + 1] = id;
                all_ids[#all_ids + 1] = id;
                column_ids[col][#column_ids[col] + 1] = id;
            end
        end
        if #row_ids > 0 then
            n_rows = n_rows + 1;
            if n_rows % 2 == 1 then
                local stripe = pframe:CreateTexture(nil, "BACKGROUND");
                stripe:SetColorTexture(1, 1, 1, 0.06);
                stripe:SetSize(col_x0 + #stat_lines.columns * col_w - (box_x - 4), row_h);
                stripe:SetPoint("TOPLEFT", box_x - 4, pframe.y_offset);
            end
            toggle_label(row_labels[row[1]], box_x, pframe.y_offset, row_ids, false, col_x0 - box_x);
            pframe.y_offset = pframe.y_offset - row_h;
        end
    end
    toggle_label(L["Combat"], 0, header_y, all_ids, true);
    for c, col in ipairs(stat_lines.columns) do
        toggle_label(column_labels[col], col_x0 + (c - 1) * col_w, header_y, column_ids[col], false, col_w, "CENTER");
    end
    pframe.y_offset = pframe.y_offset - 4;

    place_list(defense);
    place_list(abilities);

    pframe.y_offset = pframe.y_offset - 2;
    make_divider(pframe);
    pframe.y_offset = pframe.y_offset - 4;
    multi_row_checkbutton({
        {
            id = "tooltip_item_stat_diff",
            txt = L["Always show stat changes"],
            tooltip = L["Item tooltips show stat changes without holding SHIFT"],
        },
    }, pframe, 1, nil, 5);

    refresh = function()
        local shown = stat_lines.shown_cells();
        for id, f in pairs(boxes) do
            f:SetChecked(shown[id]);
        end
        local class_name = UnitClass("player");
        header:SetText(string.format("|c%s%s|r  |cFFA9A9A9%s: %s|r",
            RAID_CLASS_COLORS[sc.class].colorStr, class_name, L["Profile"], config.active_profile_name or ""));
    end;
    pframe.on_show = refresh;
    ui.refresh_stat_lines = refresh;

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
        {"stat_lines", L["Stat lines"]},
    });
    create_tooltip_spells_frame(pframe.spells);
    create_tooltip_items_frame(pframe.items);
    create_tooltip_stat_lines_frame(pframe.stat_lines);
    pframe.stat_lines_tab:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(L["Stats listed in item tooltip stat changes and the calculator"], 1, 1, 1, 1, true);
        GameTooltip:Show();
    end);
    pframe.stat_lines_tab:HookScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    pframe.spells_tab:Click();
end

ui.create_sw_ui_tooltip_frame = create_sw_ui_tooltip_frame;
