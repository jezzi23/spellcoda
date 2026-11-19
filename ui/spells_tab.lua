local _, sc = ...;

local L           = sc.L;
local spells      = sc.spells;
local spell_flags = sc.spell_flags;
local config      = sc.config;

local ui = sc.ui;
local compared_spells_changed        = ui.compared_spells_changed;
local create_arrow_button            = ui.create_arrow_button;
local font                           = ui.font;
local libDD                          = ui.libDD;
local pickup_known_spell             = ui.pickup_known_spell;
local populate_scrollable_spell_view = ui.populate_scrollable_spell_view;
local register_text_frame_color      = ui.register_text_frame_color;
local role_icons                     = ui.role_icons;
local spell_ignore_text              = ui.spell_ignore_text;
local spells_catalogue               = ui.spells_catalogue;
local toggle_spell_ignored           = ui.toggle_spell_ignored;
local training                       = ui.training;
local update_spells_frame            = ui.update_spells_frame;

local spell_filter_listing;
local spell_browser_sort_options;

local function create_sw_ui_spells_frame(pframe)

    pframe:HookScript("OnHide", function()
        sc.core.deactivate_tooltip_refresh();
    end);

    spell_filter_listing = {
        {
            header = L["Show"],
            id = "already_known",
            disp = L["Already known"],
        },
        {
            id = "available",
            disp = L["Available"],
        },
        {
            id = "missing_requirement",
            disp = L["Available, missing requirement"],
        },
        {
            id = "unavailable",
            disp = L["Unavailable"],
        },
        {
            header = L["Sources"],
            id = "innate",
            disp = L["Innate abilities"],
        },
        {
            id = "weapon_skills",
            disp = L["Weapon skills"],
        },
        {
            id = "trainer",
            disp = L["Class trainer"],
        },
        {
            id = "talent",
            disp = L["Talent spells"],
        },
        {
            id = "learned_from_item",
            disp = L["Quests and items"],
        },
        {
            id = "pet",
            disp = L["Pet spells"],
        },
        {
            id = "other_spells",
            disp = L["Other spells"],
            tooltip = L["Uncategorized spells. Contains seasonal spells and junk."]
        },
        {
            header = L["Options"],
            id = "ignored_spells",
            disp = L["Ignored spells"],
        },
        {
            id = "hide_replaced_ranks",
            disp = L["Hide replaced ranks"],
            tooltip = L["Hides learned ranks that a higher learned rank replaces."]
        },
    };
    ui.spell_filter_listing = spell_filter_listing;

    spell_browser_sort_options = {
        "Level",
        "|cFFFF8000"..L["Damage per second"],
        "|cFFFF8000"..L["Healing per second"],
        "|cFF00FFFF"..L["Damage per cost"],
        "|cFF00FFFF"..L["Healing per cost"],
    };
    ui.spell_browser_sort_options = spell_browser_sort_options;

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 8;

    f = CreateFrame("EditBox", "__sc_frame_spells_search", pframe, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);
    f:SetSize(100, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        spells_catalogue.name_filter = txt;
        update_spells_frame(nil, nil, nil, true);
        if txt == "" then
            pframe.search_empty_label:Show();
        else
            pframe.search_empty_label:Hide();
        end
    end);
    pframe.search = f;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Search"]);
    f:SetPoint("LEFT", pframe.search, 5, 0);
    pframe.search_empty_label = f;

    -- Sorted by dropdown
    pframe.sort_by =
        --CreateFrame("Button", "pframe_sort_by", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu("pframe_sort_by", pframe);
    pframe.sort_by:SetPoint("TOPLEFT", 150, pframe.y_offset+6);
    pframe.sort_by.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.sort_by, L["Order by "]..spell_browser_sort_options[spells_catalogue.sort_key]);
        libDD:UIDropDownMenu_Initialize(pframe.sort_by, function()

            libDD:UIDropDownMenu_SetWidth(pframe.sort_by, 160);

            for k, v in pairs(spell_browser_sort_options) do
                libDD:UIDropDownMenu_AddButton({
                        text = v;
                        checked = k == spells_catalogue.sort_key;
                        func = function()
                            libDD:UIDropDownMenu_SetText(pframe.sort_by, L["Order by "]..spell_browser_sort_options[k]);
                            spells_catalogue.sort_key = k;
                            update_spells_frame(nil, nil, nil, true);
                            pframe.slider:SetValue(1);
                        end
                    }
                );
            end
        end);
    end;
    pframe.sort_by.init_func();

    -- Filter dropdown
    pframe.filter =
        --CreateFrame("Button", "pframe_filter", pframe, "UIDropDownMenuTemplate");
        libDD:Create_UIDropDownMenu(nil, pframe);
    pframe.filter:SetPoint("TOPLEFT", 340, pframe.y_offset+6);
    pframe.filter.init_func = function()

        libDD:UIDropDownMenu_SetText(pframe.filter, L["Filters"]);
        libDD:UIDropDownMenu_Initialize(pframe.filter, function()

            libDD:UIDropDownMenu_SetWidth(pframe.filter, 80);

            for _, v in ipairs(spell_filter_listing) do
                if v.header then
                    libDD:UIDropDownMenu_AddButton({text = v.header, isTitle = true, notCheckable = true});
                end
                local txt = v.disp;
                if v.id == "already_known" then
                    txt = "|cFF8a867d"..txt;
                elseif v.id == "available" then
                    txt = "|cFF00FF00"..txt;
                elseif v.id == "unavailable" then
                    txt = "|cFFFF0000"..txt;
                elseif v.id == "missing_requirement" then
                    txt = "|cFFCC99FF"..txt;
                end
                local key = spells_catalogue.filter_prefix..v.id;
                local is_checked = config.settings[key];

                libDD:UIDropDownMenu_AddButton({
                        text = txt,
                        checked = is_checked,
                        func = function(self)
                            config.settings[key] = not config.settings[key];
                            update_spells_frame(nil, nil, nil, true);
                        end,
                        keepShownOnClick = true,
                        notCheckable = false,
                        tooltipTitle = "",
                        tooltipText = v.tooltip,
                        tooltipOnButton = v.tooltip ~= nil,
                    }
                );
            end
        end);
    end;
    pframe.filter.init_func();

    pframe.y_offset = pframe.y_offset - 25;
    -- Headers
    local icon_x_offset = 0;
    local name_x_offset = 20;
    local lvl_x_offset = 200;
    local effect_x_offset = 230;
    local per_sec_x_offset = 255;
    local per_cost_x_offset;
    local dropdown_x_offset = 440;
    local acquisition_r = dropdown_x_offset - 4;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Spell name"]);
    f:SetPoint("TOPLEFT", name_x_offset, pframe.y_offset);

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Level"]);
    f:SetPoint("TOPLEFT", lvl_x_offset, pframe.y_offset);
    pframe.header_level = f;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Per second"]);
    f:SetPoint("TOPLEFT", per_sec_x_offset, pframe.y_offset);
    register_text_frame_color(f, "effect_per_sec");

    local per_sec_header = f;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Per cost"]);
    register_text_frame_color(f, "effect_per_cost");
    local per_cost_header = f;

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Acquisition"]);
    f:SetPoint("TOPRIGHT", pframe, "TOPLEFT", acquisition_r, pframe.y_offset);

    local free_l = per_sec_x_offset + per_sec_header:GetStringWidth();
    local free_r = acquisition_r - f:GetStringWidth();
    per_cost_x_offset = math.floor(free_l + (free_r - free_l - per_cost_header:GetStringWidth()) / 2);
    per_cost_header:SetPoint("TOPLEFT", per_cost_x_offset, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 23;
    local num_view_list_entries = 29;
    local entry_y_offset = 16;

    -- sliders
    f = CreateFrame("Slider", nil, pframe, "UIPanelScrollBarTrimTemplate");
    f:SetOrientation('VERTICAL');
    f:SetPoint("RIGHT", pframe, "RIGHT", 10, -6);
    f:SetHeight(pframe:GetHeight()-81);
    f:SetScript("OnValueChanged", function(self, val)
        pframe.slider_val = val;
        populate_scrollable_spell_view(spells_catalogue, math.floor(val));
    end);
    pframe.slider = f;
    pframe.slider_val = 1;
    f:SetValue(pframe.slider_val);
    f:SetValueStep(1);

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f);
    bg:SetColorTexture(0, 0, 0, 0.5);

    pframe:EnableMouseWheel(true)
    pframe:SetScript("OnMouseWheel", function(_, delta)
        local scrollbar = pframe.slider;
        scrollbar:SetValue(scrollbar:GetValue() - delta*5);
    end);

    local function mouse_focus()
        if GetMouseFoci then
            return GetMouseFoci()[1];
        end
        return GetMouseFocus();
    end

    -- Spell list
    pframe.scroll_view = {};
    for i = 1, num_view_list_entries do

        -- below the line's own frames, by mouse focus as a menu over the line still counts as over it
        local hover_f = CreateFrame("Frame", nil, pframe);
        hover_f:SetPoint("TOPLEFT", -10, pframe.y_offset+4);
        hover_f:SetPoint("TOPRIGHT", -30, pframe.y_offset+4);
        hover_f:SetHeight(entry_y_offset);
        hover_f:SetFrameLevel(pframe:GetFrameLevel());
        hover_f:EnableMouse(true);
        hover_f:SetScript("OnMouseWheel", function(_, delta)
            pframe:GetScript("OnMouseWheel")(pframe, delta);
        end);
        local hover_tex = hover_f:CreateTexture(nil, "BACKGROUND");
        hover_tex:SetAllPoints();
        hover_tex:SetColorTexture(1, 1, 1, 0.08);
        hover_tex:Hide();

        local tooltip_area_f = CreateFrame("Frame", nil, pframe);
        tooltip_area_f:SetSize(220, 16);
        tooltip_area_f:SetPoint("TOPLEFT", 0, pframe.y_offset+4);
        tooltip_area_f:EnableMouse(true);
        tooltip_area_f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetSpellByID(self.__id);
            GameTooltip:Show();
        end);
        tooltip_area_f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        tooltip_area_f:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);
        tooltip_area_f:RegisterForDrag("LeftButton");
        tooltip_area_f:SetScript("OnDragStart", function(self)
            pickup_known_spell(self.__id);
        end);


        local icon = CreateFrame("Frame", nil, pframe);
        icon:SetSize(15, 15);
        icon:SetPoint("TOPLEFT", icon_x_offset, pframe.y_offset+2);
        local icon_texture = icon:CreateTexture(nil);
        icon_texture:SetAllPoints(icon);

        local book = CreateFrame("Frame", nil, pframe);
        book:SetSize(15, 15);
        book:SetPoint("TOPRIGHT", pframe, "TOPLEFT", acquisition_r, pframe.y_offset+2);
        local book_texture = book:CreateTexture(nil);
        book_texture:SetAllPoints(book);
        book:SetScript("OnEnter", function(self)
            if self.__taming then
                training.show_taming_hint(self, self.__taming, "ANCHOR_BOTTOMRIGHT");
                return;
            end
            if self.__req then
                training.show_tooltip(self, self.__req, "ANCHOR_BOTTOMRIGHT");
                return;
            end
            if self.__quest then
                training.show_quest_hint(self, "ANCHOR_BOTTOMRIGHT");
                return;
            end
            if self.__id then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
                GameTooltip:SetItemByID(self.__id);
                GameTooltip:Show();
            end
        end);
        book:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local spell_str = pframe:CreateFontString(nil, "OVERLAY");
        spell_str:SetFontObject(font);
        spell_str:SetText("");
        spell_str:SetPoint("TOPLEFT", name_x_offset, pframe.y_offset);

        local level_str = pframe:CreateFontString(nil, "OVERLAY");
        level_str:SetFontObject(font);
        level_str:SetText("");
        level_str:SetPoint("TOPLEFT", lvl_x_offset, pframe.y_offset);

        local effect_type_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_type_str:SetFontObject(font);
        effect_type_str:SetText("");
        effect_type_str:SetPoint("TOPLEFT", effect_x_offset, pframe.y_offset);

        local role_icon = CreateFrame("Frame", nil, pframe);
        role_icon:SetSize(15, 15);
        role_icon:SetPoint("TOPLEFT", effect_x_offset, pframe.y_offset+2);
        local role_icon_texture = role_icon:CreateTexture(nil, "ARTWORK");
        role_icon_texture:SetTexture(role_icons);


        local effect_per_sec_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_per_sec_str:SetFontObject(font);
        effect_per_sec_str:SetText("");
        effect_per_sec_str:SetPoint("TOPLEFT", per_sec_x_offset, pframe.y_offset);
        register_text_frame_color(effect_per_sec_str, "effect_per_sec");

        local effect_per_cost_str = pframe:CreateFontString(nil, "OVERLAY");
        effect_per_cost_str:SetFontObject(font);
        effect_per_cost_str:SetText("");
        effect_per_cost_str:SetPoint("TOPLEFT", per_cost_x_offset, pframe.y_offset);
        register_text_frame_color(effect_per_cost_str, "effect_per_cost");

        local cost = pframe:CreateFontString(nil, "OVERLAY");
        cost:SetFontObject(font);
        cost:SetText("");
        cost:SetWordWrap(false);

        local mark_str = pframe:CreateFontString(nil, "OVERLAY");
        mark_str:SetFontObject(font);

        local acquisition_y = pframe.y_offset - 5;
        local function acquisition_at(region)
            region:SetPoint("RIGHT", pframe, "TOPLEFT", acquisition_r, acquisition_y);
        end
        acquisition_at(cost);
        cost.acquisition_at = acquisition_at;

        local cost_area = CreateFrame("Frame", nil, pframe);
        cost_area:SetSize(acquisition_r - tooltip_area_f:GetWidth(), 15);
        cost_area:SetPoint("TOPRIGHT", pframe, "TOPLEFT", acquisition_r, pframe.y_offset+2);
        book:SetFrameLevel(cost_area:GetFrameLevel() + 1);
        cost_area:EnableMouse(true);
        cost_area:SetScript("OnEnter", function(self)
            training.show_tooltip(self, self.__id, "ANCHOR_BOTTOMRIGHT");
        end);
        cost_area:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        -- spell option dropdown
        local spell_options =
            --CreateFrame("Button", "pframe_dropdown"..i, pframe, "UIDropDownMenuTemplate");
            libDD:Create_UIDropDownMenu("pframe_dropdown"..i, pframe);
        spell_options:SetPoint("TOPLEFT", dropdown_x_offset, pframe.y_offset+15);
        spell_options.init_func = function()

            libDD:UIDropDownMenu_Initialize(spell_options, function()

                libDD:UIDropDownMenu_SetWidth(spell_options, 15);

                local id = spell_options.__spid;
                if not id then
                    return;
                end
                libDD:UIDropDownMenu_AddButton({text = training.spell_title(id), isTitle = true, notCheckable = true});
                if bit.band(spells[id].flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0 then
                    libDD:UIDropDownMenu_AddButton({
                            text = L["Add to comparison list"],
                            notCheckable = true,
                            func = function()
                                config.add_compared_spell(id);
                                compared_spells_changed();
                            end,
                        }
                    );
                    libDD:UIDropDownMenu_AddSpace();
                end
                libDD:UIDropDownMenu_AddButton({
                        text = spell_ignore_text(id),
                        notCheckable = true,
                        func = function()
                            toggle_spell_ignored(id);
                        end,
                    }
                );
            end);
        end;
        spell_options.init_func();
        spell_options.Button:SetSize(20, 20);
        spell_options.Button:Hide();
        spell_options.Text:Hide();

        local f = create_arrow_button(pframe, 15);
        if not f then
            f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
            f:SetText(":");
            f:SetSize(15, 15);
        end
        f:SetPoint("TOPLEFT", dropdown_x_offset, pframe.y_offset+3);
        f:SetScript("OnClick", function()
            libDD:ToggleDropDownMenu(1, nil, spell_options, spell_options, 0, 0)
        end);
        -- the library keeps the menu open on a mouse down over .Button, so a click here can close it
        spell_options.Button = f;

        hover_f.update = function()
            local focus = mouse_focus();
            hover_tex:SetShown(hover_f:IsShown() and focus ~= nil and
                (focus == hover_f or focus == tooltip_area_f or focus == book or focus == cost_area or focus == f));
        end;
        hover_f:SetScript("OnEnter", hover_f.update);
        hover_f:SetScript("OnLeave", hover_f.update);
        for _, frame in ipairs({tooltip_area_f, book, cost_area, f}) do
            frame:HookScript("OnEnter", hover_f.update);
            frame:HookScript("OnLeave", hover_f.update);
        end

        local ignore_line_f = pframe:CreateTexture(nil, "OVERLAY")
        ignore_line_f:SetColorTexture(1.0, 0.0, 0.0, 1.0);
        ignore_line_f:SetDrawLayer("OVERLAY");
        -- 0.5 rounded to no pixel at smaller frame scales
        ignore_line_f:SetHeight(1);
        ignore_line_f:SetPoint("TOPLEFT", -10, pframe.y_offset-5);
        ignore_line_f:SetPoint("TOPRIGHT", -30, pframe.y_offset-5);


        pframe.scroll_view[i] = {
            tooltip_area = tooltip_area_f,
            spell_icon = icon,
            spell_tex = icon_texture,
            spell_name = spell_str,
            lvl_str = level_str,
            type_str = effect_type_str,
            effect_type_icon = role_icon,
            effect_type_tex = role_icon_texture,
            per_sec_str = effect_per_sec_str,
            per_cost_str = effect_per_cost_str,
            book_icon = book,
            book_tex = book_texture,
            mark_str = mark_str,
            cost_str = cost,
            cost_area = cost_area,
            dropdown_menu = spell_options,
            dropdown_button = f,
            ignore_line = ignore_line_f,
            hover = hover_f,
        };
        pframe.y_offset = pframe.y_offset - entry_y_offset;
    end
    local footer_cost = pframe:CreateFontString(nil, "OVERLAY");
    footer_cost:SetFontObject(font);
    footer_cost:SetPoint("BOTTOMRIGHT", pframe, "BOTTOMRIGHT", -15, 5);

    pframe.footer_cost = footer_cost;

    local header_divider = pframe:CreateTexture(nil, "ARTWORK")
    header_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    header_divider:SetHeight(1);
    header_divider:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, -48);
    header_divider:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, -48);

    local footer_divider = pframe:CreateTexture(nil, "ARTWORK")
    footer_divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    footer_divider:SetHeight(1)
    footer_divider:SetPoint("BOTTOMLEFT", pframe, "BOTTOMLEFT", 0, 20)
    footer_divider:SetPoint("BOTTOMRIGHT", pframe, "BOTTOMRIGHT", 0, 20)
end

ui.create_sw_ui_spells_frame = create_sw_ui_spells_frame;
