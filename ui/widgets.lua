local _, sc = ...;

local L      = sc.L;
local spells = sc.spells;
local spids  = sc.spids;
local config = sc.config;

local ui = sc.ui;
local font                      = ui.font;
local register_text_frame_color = ui.register_text_frame_color;
local spells_known_changed      = ui.spells_known_changed;
local update_calc_list          = ui.update_calc_list;
local update_spells_frame       = ui.update_spells_frame;

local ui_tabs_order = {
    "spells_frame", "calculator_frame", "loadout_frame",
     "tooltip_frame", "overlay_frame", "settings_frame", "profile_frame"
};

local ui_tabs_idx = {};
for k, v in ipairs(ui_tabs_order) do
    ui_tabs_idx[v] = k;
end

local tab_atlases = {
    normal = {"uiframe-tab-left", "_uiframe-tab-center", "uiframe-tab-right"},
    active = {"uiframe-activetab-left", "_uiframe-activetab-center", "uiframe-activetab-right"},
};
local tab_overhang_left = 3;
local tab_overhang_right = 8;
local tab_spacing = 3;
local tab_min_padding = 12;

-- the art is made for tabs hanging below a frame, flip it and cut to 3/4 height like PanelTopTabButtonMixin
local function create_tab_art(tab, layer, atlases, left_x)
    local art = {left_x = left_x};
    for i, atlas in ipairs(atlases) do
        local info = C_Texture.GetAtlasInfo(atlas);
        local l, r = info.leftTexCoord, info.rightTexCoord;
        if i == 2 then
            l, r = l + 0.45 * (r - l), l + 0.55 * (r - l);
        end
        local t = tab:CreateTexture(nil, layer);
        t:SetTexture(info.file);
        t:SetTexCoord(l, r, info.bottomTexCoord, info.topTexCoord + 0.25 * (info.bottomTexCoord - info.topTexCoord));
        t:SetSize(info.width, 0.75 * info.height);
        t.natural_width = info.width;
        art[i] = t;
    end
    art[2]:SetPoint("BOTTOMLEFT", art[1], "BOTTOMRIGHT");
    art[2]:SetPoint("BOTTOMRIGHT", art[3], "BOTTOMLEFT");
    return art;
end

local function fit_tab_art(tab, art, width)
    local k = math.min(1, width / (art[1].natural_width + art[3].natural_width));
    art[1]:SetWidth(k * art[1].natural_width);
    art[3]:SetWidth(k * art[3].natural_width);
    art[1]:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", k * art.left_x, 0);
    art[3]:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", k * tab_overhang_right, 0);
end

local function select_tab(tab, selected)
    for i = 1, 3 do
        tab.art[i]:SetShown(not selected);
        tab.active_art[i]:SetShown(selected);
    end
    local icon_shift = tab.icon:IsShown() and 0.5 * (tab.icon:GetWidth() + 3) or 0;
    tab.Text:ClearAllPoints();
    tab.Text:SetPoint("CENTER", tab, "CENTER", icon_shift, selected and -4 or -8);
    tab:SetNormalFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall);
end

local function create_tab_button(parent, name)
    local tab = CreateFrame("Button", name, parent);
    tab:SetHeight(32);
    tab.art = create_tab_art(tab, "BACKGROUND", tab_atlases.normal, -tab_overhang_left);
    tab.active_art = create_tab_art(tab, "BACKGROUND", tab_atlases.active, 1 - tab_overhang_left);
    tab.highlight_art = create_tab_art(tab, "HIGHLIGHT", tab_atlases.normal, -tab_overhang_left);
    for i = 1, 3 do
        tab.highlight_art[i]:SetBlendMode("ADD");
        tab.highlight_art[i]:SetAlpha(0.4);
    end
    tab:SetNormalFontObject(GameFontNormalSmall);
    tab:SetHighlightFontObject(GameFontHighlightSmall);
    tab:SetText(" ");
    tab.Text = tab:GetFontString();
    tab.icon = tab:CreateTexture(nil, "ARTWORK");
    tab.icon:SetPoint("RIGHT", tab.Text, "LEFT", -3, 0);
    tab.icon:Hide();

    local dot = CreateFrame("Frame", nil, tab);
    dot:SetSize(6, 6);
    dot:SetPoint("RIGHT", -8, -6);
    dot:Hide();
    dot.dot = dot:CreateTexture(nil, "OVERLAY");
    dot.dot:SetColorTexture(0.2, 1, 0.2, 1);
    dot.dot:SetSize(6, 6);
    dot.dot:SetPoint("CENTER", 0, 0);
    tab.changed_indicator = dot;
    tab.set_changed = function(self, changed)
        self.changed_indicator:SetShown(changed);
    end;

    select_tab(tab, false);
    return tab;
end

local function set_tab_icon(tab, size)
    tab.icon:SetSize(size, size);
    tab.icon:Show();
    select_tab(tab, false);
    return tab.icon;
end

-- tabs share the row width, a tab with fixed_width keeps it and the others get equal padding around their text
local function layout_tabs(tabs, x, y, row_width)
    local free = row_width - tab_overhang_left - tab_overhang_right - tab_spacing * (#tabs - 1);
    local num_flexible = 0;
    for _, tab in ipairs(tabs) do
        if tab.fixed_width then
            free = free - tab.fixed_width;
        else
            tab.Text:SetWidth(0);
            tab.icon_width = tab.icon:IsShown() and tab.icon:GetWidth() + 3 or 0;
            tab.content_width = tab.Text:GetStringWidth() + tab.icon_width;
            free = free - tab.content_width;
            num_flexible = num_flexible + 1;
        end
    end
    local padding = free / num_flexible;

    x = x + tab_overhang_left;
    for _, tab in ipairs(tabs) do
        local w = tab.fixed_width or tab.content_width + padding;
        if not tab.fixed_width and padding < tab_min_padding then
            tab.Text:SetWidth(math.max(1, w - tab_min_padding - tab.icon_width));
        end
        tab:SetWidth(w);
        for _, art in ipairs({tab.art, tab.active_art, tab.highlight_art}) do
            fit_tab_art(tab, art, w);
        end
        tab:SetPoint("TOPLEFT", x, y);
        x = x + w + tab_spacing;
    end
end

-- tabs: { {key, label}, ... } in row order; makes parent[key], a frame below the row at parent.y_offset, and
-- parent[key.."_tab"]; height nil fills the rest of parent; on_select(tab) runs after the tab's frame is shown
local function create_subtabs(parent, tabs, height, on_select)
    for _, v in ipairs(tabs) do
        local tab = create_tab_button(parent);
        tab:SetText(v[2]);
        tab:SetScript("OnClick", function(self)
            for _, vv in ipairs(tabs) do
                select_tab(parent[vv[1].."_tab"], false);
                parent[vv[1]]:Hide();
            end
            select_tab(self, true);
            parent[v[1]]:Show();
            if parent[v[1]].on_show then
                parent[v[1]].on_show();
            end
            if on_select then
                on_select(self);
            end
        end);

        local subframe = CreateFrame("ScrollFrame", nil, parent);
        subframe:SetPoint("TOPLEFT", 0, parent.y_offset);
        subframe:SetWidth(parent:GetWidth());
        subframe:SetHeight(height or parent:GetHeight() + parent.y_offset);
        subframe.y_offset = 0;

        parent[v[1]] = subframe;
        parent[v[1].."_tab"] = tab;
    end
    parent.subtabs = tabs;
    local row = {};
    for _, v in ipairs(tabs) do
        row[#row + 1] = parent[v[1].."_tab"];
    end
    layout_tabs(row, -7, parent.y_offset+34, parent:GetWidth()+14);
end

local function sw_activate_tab(tab_window)

    __sc_frame:Show();

    for _, v in pairs(__sc_frame.tabs) do
        v.frame_to_open:Hide();
        select_tab(v, false);
    end

    if tab_window.frame_to_open == __sc_frame.spells_frame then
        -- in case a change of learned spells came without an event
        spells_known_changed();
        update_spells_frame(nil, nil, nil, true);
        sc.core.activate_tooltip_refresh();
    elseif tab_window.frame_to_open == __sc_frame.calculator_frame then
        update_calc_list(true);
        sc.core.activate_tooltip_refresh();
    end

    tab_window.frame_to_open:Show();
    select_tab(tab_window, true);
end

local function starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix;
end

-- the subtab button whose key, label or a word of the label starts with name, case, spaces and _ ignored
local function find_subtab(frame, name)
    name = string.gsub(string.lower(name), "[%s_]", "");
    if name == "" or not frame.subtabs then
        return nil;
    end
    for _, v in ipairs(frame.subtabs) do
        local label = string.lower(v[2]);
        local found = starts_with((string.gsub(v[1], "_", "")), name) or
            starts_with((string.gsub(label, "%s", "")), name);
        for word in string.gmatch(label, "%S+") do
            found = found or starts_with(word, name);
        end
        if found then
            return frame[v[1].."_tab"];
        end
    end
    return nil;
end

-- subtab_name optional, see find_subtab; an unknown one prints the frame's subtabs
local function sw_activate_frame(frame_name, subtab_name)
    sw_activate_tab(__sc_frame.tabs[ui_tabs_idx[frame_name]]);
    if not subtab_name or subtab_name == "" then
        return;
    end
    local frame = __sc_frame[frame_name];
    local tab = find_subtab(frame, subtab_name);
    if tab then
        tab:Click();
    elseif frame.subtabs then
        local keys = {};
        for i, v in ipairs(frame.subtabs) do
            keys[i] = v[1];
        end
        print(sc.core.addon_name..": "..L["Unknown subtab"].." \""..subtab_name.."\", "..table.concat(keys, ", "));
    end
end

-- Tooltip -> Items with its compared spells list flashing; open_tab(frame_name) defaults to sw_activate_frame
local function open_compared_spells_list(open_tab)
    (open_tab or sw_activate_frame)("tooltip_frame");
    local tooltip_frame = __sc_frame.tooltip_frame;
    tooltip_frame.items_tab:Click();
    tooltip_frame.items.compared_list.flash();
end

local function open_stat_lines()
    sw_activate_frame("tooltip_frame");
    __sc_frame.tooltip_frame.stat_lines_tab:Click();
end

local function create_sw_spell_id_viewer()

    __sc_frame.spell_id_viewer_editbox = CreateFrame("EditBox", "sw_spell_id_viewer_editbox", __sc_frame, "InputBoxTemplate");
    __sc_frame.spell_id_viewer_editbox:SetPoint("TOPLEFT", __sc_frame, 40, -6);
    __sc_frame.spell_id_viewer_editbox:SetText("");
    __sc_frame.spell_id_viewer_editbox:SetSize(100, 10);
    __sc_frame.spell_id_viewer_editbox:SetAutoFocus(false);


    local tooltip_overwrite_editbox = function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.spell_id_viewer_editbox_label:Show();
        else
            __sc_frame.spell_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if id and C_Spell.DoesSpellExist(id) or spells[id] then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
        end
        self:ClearFocus();
    end

    __sc_frame.spell_viewer_invalid_spell_id = 204;

    __sc_frame.spell_id_viewer_editbox:SetScript("OnEnterPressed", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnEscapePressed", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnEditFocusLost", tooltip_overwrite_editbox);
    __sc_frame.spell_id_viewer_editbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.spell_id_viewer_editbox_label:Show();
        else
            __sc_frame.spell_id_viewer_editbox_label:Hide();
        end
        if spids[txt] then
            self:SetText(tostring(spids[txt]));
        end
        local id = tonumber(txt);
        if id and id <= bit.lshift(1, 31) and (C_Spell.DoesSpellExist(id) or spells[id]) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
            id = 0;
        end

        if id == 0 then
            __sc_frame.spell_icon_tex:SetTexture((C_Spell.GetSpellTexture(265)));
        elseif not C_Spell.DoesSpellExist(id) then
            __sc_frame.spell_icon_tex:SetTexture(135791);
        else
            __sc_frame.spell_icon_tex:SetTexture((C_Spell.GetSpellTexture(id)));
        end
        GameTooltip:SetOwner(__sc_frame.spell_icon, "ANCHOR_BOTTOMRIGHT");
        if not C_Spell.DoesSpellExist(id) and spells[id] then

            GameTooltip:SetSpellByID(__sc_frame.spell_viewer_invalid_spell_id);
        else
            GameTooltip:SetSpellByID(id);
        end
    end);

    if __spellcoda_test_all_spells__ then
        __sc_frame.spell_id_viewer_editbox:SetText(pairs(spells)(spells));
    end

    __sc_frame.spell_id_viewer_editbox_label = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.spell_id_viewer_editbox_label:SetFontObject(font);
    __sc_frame.spell_id_viewer_editbox_label:SetText(L["Spell ID viewer"]);
    __sc_frame.spell_id_viewer_editbox_label:SetPoint("CENTER", __sc_frame.spell_id_viewer_editbox, 0, 0);

    __sc_frame.spell_icon = CreateFrame("Frame", "__sc_custom_spell_id", __sc_frame);
    __sc_frame.spell_icon:SetSize(17, 17);
    __sc_frame.spell_icon:SetPoint("RIGHT", __sc_frame.spell_id_viewer_editbox, 17, 0);

    local tex = __sc_frame.spell_icon:CreateTexture(nil);
    tex:SetAllPoints(__sc_frame.spell_icon);
    tex:SetTexture((C_Spell.GetSpellTexture(265)));
    __sc_frame.spell_icon_tex = tex;

    local tooltip_viewer_on = function(self)
        local txt = __sc_frame.spell_id_viewer_editbox:GetText();
        local id = tonumber(txt);
        if txt == "" then
            id = 265;
        elseif not id then
            id = 0;
        end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
        if not C_Spell.DoesSpellExist(id) and spells[id] then

            GameTooltip:SetSpellByID(__sc_frame.spell_viewer_invalid_spell_id);
        else
            GameTooltip:SetSpellByID(id);
        end
        GameTooltip:Show();
    end
    local tooltip_viewer_off = function(self)
        GameTooltip:Hide();
    end

    __sc_frame.spell_icon:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);

    __sc_frame.spell_icon:SetScript("OnEnter", tooltip_viewer_on);
    __sc_frame.spell_icon:SetScript("OnLeave", tooltip_viewer_off);
end

local function create_sw_item_id_viewer()

    __sc_frame.item_id_viewer_editbox = CreateFrame("EditBox", "sw_item_id_viewer_editbox", __sc_frame, "InputBoxTemplate");
    __sc_frame.item_id_viewer_editbox:SetPoint("TOPLEFT", __sc_frame, 325, -6);
    __sc_frame.item_id_viewer_editbox:SetText("");
    __sc_frame.item_id_viewer_editbox:SetSize(100, 10);
    __sc_frame.item_id_viewer_editbox:SetAutoFocus(false);

    __sc_frame.item_id_viewer_editbox:SetScript("OnEvent", function(self, event, ...)
        __sc_frame.item_id_viewer_editbox:GetScript("OnTextChanged")(__sc_frame.item_id_viewer_editbox);
    end);


    local tooltip_overwrite_editbox = function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.item_id_viewer_editbox_label:Show();
        else
            __sc_frame.item_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if id and C_Item.GetItemInfo(id) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
        end
        self:ClearFocus();
    end

    local invalid_item_id = 1728;
    local invalid_item_tex = C_Item.GetItemIconByID(1728);

    __sc_frame.item_id_viewer_editbox:SetScript("OnEnterPressed", tooltip_overwrite_editbox);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEscapePressed", tooltip_overwrite_editbox);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEditFocusLost", function(self)
        tooltip_overwrite_editbox(self);
        __sc_frame.item_id_viewer_editbox:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
    end);
    __sc_frame.item_id_viewer_editbox:SetScript("OnEditFocusGained", function()
        __sc_frame.item_id_viewer_editbox:RegisterEvent("GET_ITEM_INFO_RECEIVED");
    end);
    __sc_frame.item_id_viewer_editbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            __sc_frame.item_id_viewer_editbox_label:Show();
        else
            __sc_frame.item_id_viewer_editbox_label:Hide();
        end
        local id = tonumber(txt);
        if id and id <= bit.lshift(1, 31) and C_Item.GetItemInfo(id) then
            self:SetTextColor(0, 1, 0);
        else
            self:SetTextColor(1, 0, 0);
            id = 0;
        end

        if id == 0 then
            __sc_frame.item_icon_tex:SetTexture(invalid_item_tex);
            __sc_frame.item_icon.id = invalid_item_id;
            GameTooltip:Hide();
        else
            __sc_frame.item_icon_tex:SetTexture(C_Item.GetItemIconByID(id));

            __sc_frame.item_icon.id = id;
            GameTooltip:SetOwner(__sc_frame.item_icon, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(id);
            GameTooltip:Show();
        end
    end);

    __sc_frame.item_id_viewer_editbox_label = __sc_frame:CreateFontString(nil, "OVERLAY");
    __sc_frame.item_id_viewer_editbox_label:SetFontObject(font);
    __sc_frame.item_id_viewer_editbox_label:SetText(L["Item ID viewer"]);
    __sc_frame.item_id_viewer_editbox_label:SetPoint("CENTER", __sc_frame.item_id_viewer_editbox, 0, 0);

    __sc_frame.item_icon = CreateFrame("Frame", "__sc_custom_item_id", __sc_frame);
    __sc_frame.item_icon:SetSize(17, 17);
    __sc_frame.item_icon:SetPoint("RIGHT", __sc_frame.item_id_viewer_editbox, 17, 0);
    __sc_frame.item_icon:SetScript("OnMouseDown", function(self, btn)
        if not self.id or not IsModifiedClick("CHATLINK") or btn ~= "LeftButton" then
            return;
        end
        local _, link = C_Item.GetItemInfo(self.id);
        if not link then
            return;
        end
        HandleModifiedItemClick(link);
    end);

    local tex = __sc_frame.item_icon:CreateTexture(nil);
    tex:SetAllPoints(__sc_frame.item_icon);
    tex:SetTexture(invalid_item_tex);
    __sc_frame.item_icon_tex = tex;

    local tooltip_viewer_on = function(self)
        local txt = __sc_frame.item_id_viewer_editbox:GetText();
        local id = tonumber(txt);
        if txt == "" then
            id = invalid_item_id;
        elseif not id then
            id = 0;
        end
        if C_Item.GetItemInfo(id) then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(id);
            GameTooltip:Show();
        else
            GameTooltip:Hide();
        end
    end
    local tooltip_viewer_off = function(self)
        GameTooltip:Hide();
    end

    __sc_frame.item_icon:SetScript("OnEnter", tooltip_viewer_on);
    __sc_frame.item_icon:SetScript("OnLeave", tooltip_viewer_off);
end

local function multi_row_checkbutton(buttons_info, parent_frame, num_columns, func, x_pad)
    x_pad = x_pad or 10;
    local column_offset = 230;
    --  assume max 2 columns
    local check_button_type = "CheckButton";
    local frames = {};
    for i, v in pairs(buttons_info) do
        local f = CreateFrame(check_button_type, "__sc_frame_setting_"..v.id, parent_frame, "ChatConfigCheckButtonTemplate");
        frames[#frames + 1] = f;
        f._settings_id = v.id;
        f._type = check_button_type;

        local x_spacing = column_offset*((i-1)%num_columns);
        local x = x_pad + x_spacing;
        f:SetPoint("TOPLEFT", x, parent_frame.y_offset);
        local txt = getglobal(f:GetName() .. 'Text');
        txt:SetText(v.txt);
        if v.color then
            txt:SetTextColor(v.color[1], v.color[2], v.color[3]);
        end
        if v.color_tag then
            register_text_frame_color(txt, v.color_tag);
        end
        if v.tooltip then
            getglobal(f:GetName()).tooltip = v.tooltip;
        end
        f:SetScript("OnClick", function(self)
            config.settings[self._settings_id] = self:GetChecked();
            sc.loadouts.force_update = true;
            if v.func then
                v.func(self);
            end
            if func then
                func(self);
            end
        end);
        if (i-1)%num_columns == num_columns - 1 then
            parent_frame.y_offset = parent_frame.y_offset - 20;
        end
    end
    return frames;
end

-- a line across the frame at its y offset, one anchor so make_frame_scrollable can move it
local function make_divider(frame)
    local div = frame:CreateTexture(nil, "ARTWORK");
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetWidth(frame:GetWidth());
    div:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, frame.y_offset);
    return div;
end

local function make_frame_scrollable(frame)

    local height = frame:GetHeight();
    local restrict_bottom_space = -25;

    if -frame.y_offset - restrict_bottom_space <= height then
        return;
    end


    for _, grp in ipairs({{frame:GetChildren()}, {frame:GetRegions()}}) do
        for _, v in ipairs(grp) do
            local _, rel_to, _, _, y = v:GetPoint(1);
            if rel_to == frame then
                v.original_y_offset = y;
            end
        end
    end
    local f = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTrimTemplate");
    f:SetOrientation('VERTICAL');
    f:SetPoint("RIGHT", frame, "RIGHT", 10, 9);
    f:SetWidth(20);
    f:SetHeight(height-43);
    f:SetScript("OnValueChanged", function(self, val)
        for _, grp in ipairs({{frame:GetChildren()}, {frame:GetRegions()}}) do
            for _, v in ipairs(grp) do
                if v.original_y_offset then
                    local p, rel_to, rel_p, x = v:GetPoint(1);
                    local new_y = v.original_y_offset + val;
                    v:SetPoint(p, rel_to, rel_p, x, new_y);
                    if -v.original_y_offset >= val and -v.original_y_offset -restrict_bottom_space <= height+val then
                        v:Show();
                    else
                        v:Hide();
                    end
                end
            end
        end
    end);
    frame.slider = f;
    f:SetMinMaxValues(0, -frame.y_offset-height+100);
    f:SetValue(0);
    f:SetValueStep(15);

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f);
    bg:SetColorTexture(0, 0, 0, 0.5);

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local scrollbar = frame.slider;

        local val = math.max(0, scrollbar:GetValue() - delta*15);
        scrollbar:SetValue(val);
        scrollbar:GetScript("OnValueChanged")(scrollbar, val);
    end);
end

-- Dodge is the spell effective health is shown on
local function make_dodge_drag_button(parent, level)
    local btn = CreateFrame("Button", nil, parent);
    btn:SetSize(18, 18);
    btn:SetFrameLevel(level);
    btn:SetNormalTexture(C_Spell.GetSpellTexture(spids.dodge) or ui.ehp_tex);
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
    btn:RegisterForDrag("LeftButton");
    btn:SetScript("OnDragStart", function()
        ui.pickup_known_spell(spids.dodge);
    end);
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetSpellByID(spids.dodge);
        GameTooltip:Show();
    end);
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    local label = parent:CreateFontString(nil, "OVERLAY");
    label:SetFontObject(font);
    label:SetPoint("LEFT", btn, "RIGHT", 6, 0);
    label:SetText(L["Drag to an action bar"]);
    label:SetTextColor(0.6, 0.6, 0.6);
    return btn;
end

ui.create_sw_item_id_viewer  = create_sw_item_id_viewer;
ui.create_sw_spell_id_viewer = create_sw_spell_id_viewer;
ui.create_subtabs            = create_subtabs;
ui.create_tab_button         = create_tab_button;
ui.layout_tabs               = layout_tabs;
ui.make_divider              = make_divider;
ui.make_dodge_drag_button    = make_dodge_drag_button;
ui.make_frame_scrollable     = make_frame_scrollable;
ui.multi_row_checkbutton     = multi_row_checkbutton;
ui.open_compared_spells_list = open_compared_spells_list;
ui.select_tab                = select_tab;
ui.set_tab_icon              = set_tab_icon;
ui.sw_activate_frame         = sw_activate_frame;
ui.sw_activate_tab           = sw_activate_tab;
ui.open_stat_lines           = open_stat_lines;
ui.ui_tabs_idx               = ui_tabs_idx;
ui.ui_tabs_order             = ui_tabs_order;
