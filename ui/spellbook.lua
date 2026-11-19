local _, sc = ...;

local L                 = sc.L;
local spells            = sc.spells;
local spell_flags       = sc.spell_flags;
local clear_table       = sc.utils.clear_table;
local effect_color      = sc.utils.effect_color;
local format_number     = sc.utils.format_number;
local color_by_lvl_diff = sc.utils.color_by_lvl_diff;
local active_loadout    = sc.loadouts.active_loadout
local config            = sc.config;

local ui = sc.ui;
local compared_spells_changed = ui.compared_spells_changed;
local create_arrow_button     = ui.create_arrow_button;
local ehp_tex                 = ui.ehp_tex;
local eval_spell_view_entry   = ui.eval_spell_view_entry;
local missing_requirement     = ui.missing_requirement;
local new_spell_catalogue     = ui.new_spell_catalogue;
local pickup_known_spell      = ui.pickup_known_spell;
local role_icons              = ui.role_icons;
local spell_browser_sort_keys = ui.spell_browser_sort_keys;
local spell_filters           = ui.spell_filters;
local spell_ignore_text       = ui.spell_ignore_text;
local spells_known_changed    = ui.spells_known_changed;
local sw_activate_frame       = ui.sw_activate_frame;
local toggle_spell_ignored    = ui.toggle_spell_ignored;
local training                = ui.training;
local update_spell_catalogue  = ui.update_spell_catalogue;

-- spell catalogue on the spellbook's pages (forever)
local function create_book_catalogue(sb, container, open_sc_tab)

    local book = {};
    -- wider than blizzard's 448 views, into the empty margins of each page's art
    local page_x = 40;
    local page_w = 508;
    local modes = {
        compact = {spell_h = 18, heading_h = 18, value_font = "GameFontBlack", type_icon = 14, ignore_line = 1.5},
        full = {spell_h = 44, heading_h = 24, value_font = "GameFontBlackMedium", type_icon = 20, ignore_line = 3, full = true},
    };
    -- SpellBookItemMixin.ArtSet.Square
    local icon_border = {
        known = {atlas = "spellbook-item-iconframe", tl = {-11, 1}, br = {1, -7}},
        unlearned = {atlas = "spellbook-item-iconframe-inactive", tl = {-10, 1}, br = {2, -5}},
    };
    local full_name_x = 60;
    local title_header_h = 55;
    local plain_header_h = 33;
    local plain_divider_y = -21;
    local paging_rows_bottom = 523;
    local full_rows_bottom = 585;
    -- the row menu button is right of it
    local content_r = page_w - 24;
    local bottom_bar_y = 56;


    local cols = {name = {x = 22}};

    local base_color = {SPELLBOOK_FONT_COLOR:GetRGB()};
    local lvl_diff_colors = {
        ["|cFFA9A9A9"] = "|cFF5C5852",
        ["|cFF00FF00"] = "|cFF1E7A00",
        ["|cFFFFFF00"] = "|cFFFFD100",
        ["|cFFFF4500"] = "|cFFB33000",
        ["|cFFFF0000"] = "|cFFA81000",
    };
    -- tweak for dark skinned spell books, keeps the embedded page readable
    local ink = {
        available = {0.0, 0.42, 0.0},
        unavailable = {0.62, 0.1, 0.02},
        missing_requirement = {0.42, 0.12, 0.62},
        available_code = "|cFF006B00",
        unavailable_code = "|cFF9E1A05",
        missing_requirement_code = "|cFF6B1F9E",
        shadow = {0.25, 0.12, 0.0},
        row_hl = {0.35, 0.2, 0.05, 0.12},
        button_hl = {0.35, 0.2, 0.05, 0.15},
    };
    -- skins lighten blizzard's spell names, so check those
    local function choose_ink()
        local lum;
        sb:ForEachDisplayedSpell(function(entry)
            if not lum and entry.Name then
                local r, g, b = entry.Name:GetTextColor();
                lum = 0.299*r + 0.587*g + 0.114*b;
            end
        end);
        if not lum or lum < 0.5 then
            return;
        end
        ink.light = true;
        base_color[1], base_color[2], base_color[3] = 0.9, 0.9, 0.9;
        wipe(lvl_diff_colors);
        ink.available = {0.65, 1, 0.4};
        ink.unavailable = {1, 0.55, 0.45};
        ink.missing_requirement = {0.8, 0.6, 1};
        ink.available_code = "|cFFA6FF66";
        ink.unavailable_code = "|cFFFF8C73";
        ink.missing_requirement_code = "|cFFCC99FF";
        ink.shadow = {0, 0, 0};
        ink.row_hl = {1, 1, 1, 0.06};
        ink.button_hl = {1, 1, 1, 0.08};
    end
    -- the configured colors are for a dark background, darkened for parchment
    local per_sec_color = {};
    local per_cost_color = {};
    local function on_parchment(r, g, b)
        if ink.light then
            return r, g, b;
        end
        local max_lum = 0.3;
        -- yellow to orange is the paper's own hue
        if r > b and g > b then
            g = b + (g - b) * 0.7;
            max_lum = 0.22;
        end
        local lum = 0.299*r + 0.587*g + 0.114*b;
        if lum > max_lum then
            local f = max_lum/lum;
            return r*f, g*f, b*f;
        end
        return r, g, b;
    end

    local cat;
    local pages = {};
    local page_starts = {};
    local num_pages = 1;
    local first_page = 1;
    local top_entry = 1;
    local jump_to_lvl = true;
    local rendering = false;
    local created = false;
    local paging;
    local footer = {};

    local function views_shown()
        if sb.isMinimized then
            return 1;
        end
        return 2;
    end

    local function current_mode()
        if config.settings.spellbook_catalogue_compact then
            return modes.compact;
        end
        return modes.full;
    end

    local function page_height(page_idx, views)
        if views == 1 then
            return paging_rows_bottom - title_header_h;
        elseif page_idx % 2 == 1 then
            return full_rows_bottom - title_header_h;
        end
        return paging_rows_bottom - plain_header_h;
    end

    local function entry_h(mode, v)
        if v.lvl_barrier then
            return mode.heading_h;
        end
        return mode.spell_h;
    end

    local function set_lvl_colored_text(fs, clvl, lvl, txt)
        local code = color_by_lvl_diff(clvl, lvl);
        fs:SetText((lvl_diff_colors[code] or code)..txt.."|r");
        if code == "|cFFFFFF00" then
            fs:SetShadowOffset(1, -1);
        else
            fs:SetShadowOffset(0, 0);
        end
    end

    local function set_lvl_text(fs, clvl, lvl)
        set_lvl_colored_text(fs, clvl, lvl, lvl);
    end

    local function lvl_font_string(parent, font_obj)
        local fs = parent:CreateFontString(nil, "ARTWORK", font_obj);
        fs:SetShadowColor(ink.shadow[1], ink.shadow[2], ink.shadow[3], 1.0);
        return fs;
    end

    local function set_sort(key)
        cat.sort_key = key;
        top_entry = 1;
        jump_to_lvl = key == spell_browser_sort_keys.lvl;
        update_spell_catalogue(cat, nil, nil, nil, true);
    end

    local function spell_menu(owner, spell_id)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle(training.spell_title(spell_id));
            if bit.band(spells[spell_id].flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0 then
                root:CreateButton(L["Add to comparison list"], function()
                    config.settings.spell_calc_list[spell_id] = 1;
                    compared_spells_changed();
                end);
                root:CreateSpacer();
            end
            root:CreateButton(spell_ignore_text(spell_id), function()
                toggle_spell_ignored(spell_id);
            end);
        end);
    end

    -- by mouse focus, IsMouseOver is true under a menu covering the row
    local function has_mouse(f)
        return f:IsMouseMotionFocus();
    end

    local function update_hover(row)
        local over = row.spell_id ~= nil and
            (has_mouse(row) or has_mouse(row.area) or has_mouse(row.item) or has_mouse(row.cost_area) or
            has_mouse(row.menu_button));
        row.hl:SetShown(over);
        row.menu_button:SetShown(row.spell_id ~= nil);
        if row.icon_hl then
            row.icon_hl:SetShown(over);
        end
    end

    local function layout_columns()
        local measure = container:CreateFontString(nil, "ARTWORK", "GameFontBlack");
        measure:Hide();
        local x = content_r;
        -- extra for the sort icon left of a header
        local function col(key, txt, min_w, gap, extra)
            local w = min_w;
            if txt then
                measure:SetText(txt);
                w = math.max(w, math.ceil(measure:GetUnboundedStringWidth()) + (extra or 0));
            end
            x = x - w;
            cols[key] = {x = x, w = w};
            x = x - gap;
        end
        local measure_cell = container:CreateFontString(nil, "ARTWORK", "GameFontBlackMedium");
        measure_cell:Hide();
        col("cost", L["Acquisition"], math.max(64, training.widest_cell_w(measure_cell, 18)), 10);
        col("per_cost", L["Per cost"], 48, 10, 16);
        -- the damage / heal icon is in the empty left part of this column
        col("per_sec", L["Per second"], 56, 10, 16);
        -- by level the level column is hidden and the name takes its room
        cols.name.wide_w = x - cols.name.x;
        col("lvl", L["Level"], 28, 8);
        cols.name.w = x - cols.name.x;
    end

    local function set_name_width(row, mode, by_lvl)
        local w = by_lvl and cols.name.wide_w or cols.name.w;
        if row.name_w == w then
            return;
        end
        row.name_w = w;
        row.area:SetWidth(cols.name.x + w);
        if mode.full then
            row.name:SetWidth(cols.name.x + w - full_name_x);
            row.sub_name:SetWidth(cols.name.x + w - full_name_x);
        else
            row.name:SetWidth(w);
        end
    end

    local function create_row(parent, mode)
        local row = CreateFrame("Button", nil, parent);
        row:SetWidth(page_w);
        row:RegisterForClicks("RightButtonUp");
        row:SetScript("OnClick", function(self)
            if self.spell_id then
                spell_menu(self, self.spell_id);
            end
        end);
        local function hover() update_hover(row); end
        row:SetScript("OnEnter", hover);
        row:SetScript("OnLeave", hover);

        row.hl = row:CreateTexture(nil, "BACKGROUND");
        row.hl:SetAllPoints();
        row.hl:SetColorTexture(unpack(ink.row_hl));
        row.hl:Hide();

        local area = CreateFrame("Button", nil, row);
        area:SetPoint("TOPLEFT");
        area:SetPoint("BOTTOMLEFT");
        area:RegisterForClicks("RightButtonUp");
        area:RegisterForDrag("LeftButton");
        area:SetScript("OnClick", function(self)
            spell_menu(self, self.spell_id);
        end);
        area:SetScript("OnDragStart", function(self)
            pickup_known_spell(self.spell_id);
        end);
        area:SetScript("OnEnter", function(self)
            hover();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetSpellByID(self.spell_id);
            GameTooltip:Show();
        end);
        area:SetScript("OnLeave", function()
            hover();
            GameTooltip:Hide();
        end);
        area:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);
        row.area = area;

        if mode.full then
            -- the overlay's parent
            local icon_frame = CreateFrame("Frame", nil, area);
            icon_frame:SetSize(40, 40);
            icon_frame:SetPoint("LEFT", 10, 0);
            row.icon_frame = icon_frame;

            local shadow = icon_frame:CreateTexture(nil, "BACKGROUND");
            shadow:SetAtlas("spellbook-item-iconframe-shadow");
            shadow:SetPoint("TOPLEFT", -12, 3);
            shadow:SetPoint("BOTTOMRIGHT", 2, -8);

            row.icon = icon_frame:CreateTexture(nil, "ARTWORK");
            row.icon:SetSize(36, 36);
            row.icon:SetPoint("CENTER");
            local mask = icon_frame:CreateMaskTexture();
            mask:SetAtlas("spellbook-item-spellicon-mask", false);
            mask:SetAllPoints(row.icon);
            row.icon:AddMaskTexture(mask);

            -- below the overlay's font strings on OVERLAY
            row.icon_border = icon_frame:CreateTexture(nil, "ARTWORK", nil, 2);
            row.icon_hl = icon_frame:CreateTexture(nil, "ARTWORK", nil, 3);
            row.icon_hl:SetAtlas("spellbook-item-iconframe-hover", false);
            row.icon_hl:SetAllPoints();
            row.icon_hl:SetBlendMode("ADD");
            row.icon_hl:SetAlpha(0.25);
            row.icon_hl:Hide();

            row.name = area:CreateFontString(nil, "ARTWORK", "SystemFont_Large");
            row.name:SetJustifyH("LEFT");
            row.name:SetWordWrap(false);
            row.sub_name = area:CreateFontString(nil, "ARTWORK", "SystemFont_Med1");
            row.sub_name:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2);
            row.sub_name:SetJustifyH("LEFT");
            row.sub_name:SetWordWrap(false);
            row.sub_name:SetTextColor(unpack(base_color));
        else
            row.icon = area:CreateTexture(nil, "ARTWORK");
            row.icon:SetSize(16, 16);
            row.icon:SetPoint("LEFT", 1, 0);

            row.name = area:CreateFontString(nil, "ARTWORK", "GameFontBlack");
            row.name:SetPoint("LEFT", cols.name.x, 0);
            row.name:SetJustifyH("LEFT");
            row.name:SetWordWrap(false);
        end
        set_name_width(row, mode, false);

        row.lvl = lvl_font_string(row, mode.value_font);
        row.lvl:SetPoint("LEFT", cols.lvl.x, 0);
        row.lvl:SetWidth(cols.lvl.w);
        row.lvl:SetJustifyH("CENTER");
        row.lvl:SetTextColor(unpack(base_color));

        row.type_icon = row:CreateTexture(nil, "ARTWORK");
        row.type_icon:SetSize(mode.type_icon, mode.type_icon);
        row.type_icon:SetPoint("CENTER", row, "LEFT", cols.per_sec.x + mode.type_icon/2, 0);
        row.type_icon:SetTexture(role_icons);

        row.per_sec = row:CreateFontString(nil, "ARTWORK", mode.value_font);
        row.per_sec:SetPoint("LEFT", cols.per_sec.x, 0);
        row.per_sec:SetWidth(cols.per_sec.w);
        row.per_sec:SetJustifyH("RIGHT");

        row.per_cost = row:CreateFontString(nil, "ARTWORK", mode.value_font);
        row.per_cost:SetPoint("LEFT", cols.per_cost.x, 0);
        row.per_cost:SetWidth(cols.per_cost.w);
        row.per_cost:SetJustifyH("RIGHT");

        row.cost = row:CreateFontString(nil, "ARTWORK", mode.value_font);
        row.cost:SetWordWrap(false);
        row.cost:SetTextColor(unpack(base_color));

        local item = CreateFrame("Frame", nil, row);
        item:SetSize(16, 16);
        item:EnableMouseMotion(true);
        item:SetPoint("RIGHT", row, "LEFT", content_r, 0);
        item:SetScript("OnEnter", function(self)
            hover();
            if self.taming then
                training.show_taming_hint(self, self.taming, "ANCHOR_RIGHT");
                return;
            end
            if self.req then
                training.show_tooltip(self, self.req, "ANCHOR_RIGHT");
                return;
            end
            if self.quest then
                training.show_quest_hint(self, "ANCHOR_RIGHT");
                return;
            end
            if self.item_id then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetItemByID(self.item_id);
                GameTooltip:Show();
            end
        end);
        item:SetScript("OnLeave", function()
            hover();
            GameTooltip:Hide();
        end);
        item.tex = item:CreateTexture(nil, "ARTWORK");
        item.tex:SetAllPoints();
        item.backing = item:CreateTexture(nil, "BACKGROUND");
        item.backing:SetAllPoints();
        item.backing:SetColorTexture(0, 0, 0, 0.6);
        item.backing:Hide();
        row.item = item;
        row.mark = row:CreateFontString(nil, "ARTWORK", mode.value_font);
        function row.acquisition_at(region)
            region:SetPoint("RIGHT", row, "LEFT", content_r, 0);
        end

        local cost_area = CreateFrame("Frame", nil, row);
        cost_area:SetHeight(16);
        cost_area:SetPoint("LEFT", area, "RIGHT");
        cost_area:SetPoint("RIGHT", row, "LEFT", cols.cost.x + cols.cost.w, 0);
        item:SetFrameLevel(cost_area:GetFrameLevel() + 1);
        cost_area:EnableMouseMotion(true);
        cost_area:SetScript("OnEnter", function(self)
            hover();
            training.show_tooltip(self, self.spell_id, "ANCHOR_RIGHT");
        end);
        cost_area:SetScript("OnLeave", function()
            hover();
            GameTooltip:Hide();
        end);
        row.cost_area = cost_area;

        local menu_button = create_arrow_button(row, 16);
        menu_button:SetPoint("LEFT", row, "LEFT", content_r + 8, 0);
        menu_button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        -- the row owns the menu, it closes with the row
        menu_button:SetScript("OnClick", function()
            local open = Menu.GetManager():GetOpenMenu();
            if open and open:GetOwnerRegion() == row then
                open:Close();
            elseif row.spell_id then
                spell_menu(row, row.spell_id);
            end
        end);
        -- keeps the menu from closing on the mouse down, the click then toggles it
        function menu_button:HandlesGlobalMouseEvent(button_name, event)
            return event == "GLOBAL_MOUSE_DOWN" and (button_name == "LeftButton" or button_name == "RightButton");
        end
        menu_button:SetScript("OnEnter", hover);
        menu_button:SetScript("OnLeave", hover);
        menu_button:Hide();
        row.menu_button = menu_button;

        -- over the icon, which is on a child frame
        local ignore_f = CreateFrame("Frame", nil, row);
        ignore_f:SetAllPoints();
        ignore_f:SetFrameLevel(area:GetFrameLevel() + 3);
        row.ignore_line = ignore_f:CreateTexture(nil, "OVERLAY");
        row.ignore_line:SetColorTexture(ink.unavailable[1], ink.unavailable[2], ink.unavailable[3], 0.8);
        row.ignore_line:SetHeight(mode.ignore_line);
        row.ignore_line:SetPoint("LEFT", -6, 0);
        row.ignore_line:SetPoint("RIGHT", row, "LEFT", content_r, 0);

        row.barrier = row:CreateFontString(nil, "ARTWORK", "GameFontBlackMedium");
        row.barrier:SetPoint("LEFT", 1, 0);
        row.barrier:SetTextColor(unpack(base_color));
        row.barrier:SetText(L["Level"]);
        row.barrier_lvl = lvl_font_string(row, "GameFontBlackMedium");
        row.barrier_lvl:SetPoint("LEFT", row.barrier, "RIGHT", 4, 0);
        row.barrier_line = row:CreateTexture(nil, "ARTWORK");
        row.barrier_line:SetColorTexture(base_color[1], base_color[2], base_color[3], 0.35);
        row.barrier_line:SetHeight(1);
        row.barrier_line:SetPoint("LEFT", row.barrier_lvl, "RIGHT", 6, 0);
        row.barrier_line:SetPoint("RIGHT", row, "LEFT", content_r, 0);

        return row;
    end

    local function header_button(page, text, col, justify, on_click)
        local btn = CreateFrame("Button", nil, page);
        btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontBlack");
        btn.text:SetWordWrap(false);
        btn.text:SetText(text);
        btn.text:SetPoint("LEFT", 4, 0);
        btn.text:SetPoint("RIGHT", -4, 0);
        btn.text:SetTextColor(unpack(base_color));
        btn:SetSize(math.min(col.w, math.ceil(btn.text:GetUnboundedStringWidth())) + 8, 16);
        local y = page.header_y;
        if justify == "RIGHT" then
            btn:SetPoint("TOPRIGHT", page, "TOPLEFT", col.x + col.w + 4, y);
        else
            btn:SetPoint("TOP", page, "TOPLEFT", col.x + col.w/2, y);
        end
        if on_click then
            btn.hl = btn:CreateTexture(nil, "BACKGROUND");
            btn.hl:SetPoint("TOPLEFT", 0, 2);
            btn.hl:SetPoint("BOTTOMRIGHT", 0, -2);
            btn.hl:SetColorTexture(unpack(ink.button_hl));
            btn.hl:Hide();
            btn:SetScript("OnClick", on_click);
            btn:SetScript("OnEnter", function(self)
                self.hl:Show();
            end);
            btn:SetScript("OnLeave", function(self)
                self.hl:Hide();
            end);
        end
        return btn;
    end

    local function create_divider(page, y)
        local divider = page:CreateTexture(nil, "ARTWORK");
        divider:SetAtlas("spellbook-divider");
        divider:SetHeight(11);
        divider:SetPoint("TOPLEFT", -20, y);
        divider:SetPoint("TOPRIGHT", page, "TOPLEFT", content_r + 6, y);
        return divider;
    end

    local function create_title(page)
        local backplate = page:CreateTexture(nil, "BACKGROUND");
        backplate:SetAtlas("spellbook-list-backplate");
        backplate:SetSize(416, 106);
        backplate:SetAlpha(0.65);
        backplate:SetPoint("LEFT", page, "TOPLEFT", -page_x, -51/2 + 10);
        -- looks off on a dark book
        backplate:SetShown(not ink.light);

        local title = page:CreateFontString(nil, "ARTWORK", "SystemFont_Huge2");
        title:SetPoint("LEFT", page, "TOPLEFT", -8, -13);
        title:SetText("SpellCoda");
        title:SetTextColor(unpack(base_color));

        local settings_button = CreateFrame("Button", nil, page);
        settings_button:SetSize(20, 20);
        settings_button:SetPoint("RIGHT", page, "TOPLEFT", content_r, -5);
        settings_button:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton");
        settings_button:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD");
        settings_button:GetHighlightTexture():SetAlpha(0.5);
        settings_button:SetScript("OnMouseDown", function(self) self:GetNormalTexture():SetPoint("TOPLEFT", 1, -1); end);
        settings_button:SetScript("OnMouseUp", function(self) self:GetNormalTexture():SetPoint("TOPLEFT", 0, 0); end);
        settings_button:SetScript("OnClick", function()
            open_sc_tab("settings_frame");
        end);
        settings_button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(L["Settings"]);
            GameTooltip:Show();
        end);
        settings_button:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        local calc_button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate");
        calc_button:SetText(L["Calculator"]);
        calc_button:SetSize(math.max(90, math.ceil(calc_button:GetFontString():GetUnboundedStringWidth()) + 30), 22);
        calc_button:SetPoint("RIGHT", settings_button, "LEFT", -8, 0);
        calc_button:SetScript("OnClick", function()
            open_sc_tab("calculator_frame");
        end);

        -- named and typed for activate_config, which syncs it on profile changes
        local compact = CreateFrame("CheckButton", "__sc_frame_setting_spellbook_catalogue_compact", page, "UICheckButtonTemplate");
        compact._type = "CheckButton";
        compact._settings_id = "spellbook_catalogue_compact";
        compact:SetSize(24, 24);
        compact.label = compact:CreateFontString(nil, "ARTWORK", "GameFontBlack");
        compact.label:SetPoint("RIGHT", calc_button, "LEFT", -14, 0);
        compact.label:SetText(L["Compact"]);
        compact:SetPoint("RIGHT", compact.label, "LEFT", -2, 0);
        compact.label:SetTextColor(unpack(base_color));
        compact:SetHitRectInsets(0, -math.ceil(compact.label:GetUnboundedStringWidth()) - 4, 0, 0);
        compact:SetChecked(config.settings.spellbook_catalogue_compact);
        compact:SetScript("OnClick", function(self)
            config.settings[self._settings_id] = self:GetChecked();
            book.on_resize();
        end);

        -- snapped it lands a pixel off blizzard's
        local divider = create_divider(page, -40.9);
        divider:SetSnapToPixelGrid(false);
        divider:SetTexelSnappingBias(0);
    end

    local function create_page(i)
        local page = CreateFrame("Frame", nil, container);
        page:SetSize(page_w, full_rows_bottom);
        -- both pages of an open book use the art of a single page
        if i == 1 then
            page:SetPoint("TOPLEFT", page_x, -45);
            page.header_h = title_header_h;
            page.header_y = -26;
            create_title(page);
        else
            page:SetPoint("TOPLEFT", container, "TOP", page_x, -45);
            page.header_h = plain_header_h;
            page.header_y = plain_divider_y + 17;
            create_divider(page, plain_divider_y);
        end
        page.footer_divider = create_divider(page, -(paging_rows_bottom + 1));

        local sort_keys = spell_browser_sort_keys;
        page.header_lvl = header_button(page, L["Level"], cols.lvl, "CENTER", function()
            set_sort(sort_keys.lvl);
        end);
        page.header_per_sec = header_button(page, L["Per second"], cols.per_sec, "RIGHT", function()
            set_sort(cat.sort_key == sort_keys.dps and sort_keys.hps or sort_keys.dps);
        end);
        page.header_per_cost = header_button(page, L["Per cost"], cols.per_cost, "RIGHT", function()
            set_sort(cat.sort_key == sort_keys.dpc and sort_keys.hpc or sort_keys.dpc);
        end);
        header_button(page, L["Acquisition"], cols.cost, "RIGHT");

        page.sort_icon = page:CreateTexture(nil, "ARTWORK");
        page.sort_icon:SetSize(14, 14);
        page.sort_icon:SetTexture(role_icons);
        page.sort_icon:Hide();

        page.content = CreateFrame("Frame", nil, page);
        page.content:SetAllPoints();
        page.turn = page.content:CreateAnimationGroup();
        page.turn_fade = page.turn:CreateAnimation("Alpha");
        page.turn_fade:SetFromAlpha(0.15);
        page.turn_fade:SetToAlpha(1);
        page.turn_fade:SetDuration(0.18);
        page.turn_fade:SetSmoothing("OUT");

        page.max_rows_h = i == 1 and (full_rows_bottom - title_header_h) or (paging_rows_bottom - plain_header_h);
        page.row_sets = {};
        return page;
    end

    local function page_rows(page, mode)
        local set = page.row_sets[mode];
        if not set then
            set = {frame = CreateFrame("Frame", nil, page.content), rows = {}};
            set.frame:SetAllPoints();
            for r = 1, math.floor(page.max_rows_h / math.min(mode.spell_h, mode.heading_h)) do
                set.rows[r] = create_row(set.frame, mode);
            end
            page.row_sets[mode] = set;
        end
        for m, other in pairs(page.row_sets) do
            other.frame:SetShown(m == mode);
        end
        return set.rows;
    end

    local function update_headers(page)
        local sort_keys = spell_browser_sort_keys;
        local key = cat.sort_key;
        page.header_lvl:SetShown(key ~= sort_keys.lvl);
        page.header_per_sec.text:SetTextColor(unpack(per_sec_color));
        page.header_per_cost.text:SetTextColor(unpack(per_cost_color));
        local active, heal;
        if key == sort_keys.dps or key == sort_keys.hps then
            active = page.header_per_sec;
            heal = key == sort_keys.hps;
        elseif key == sort_keys.dpc or key == sort_keys.hpc then
            active = page.header_per_cost;
            heal = key == sort_keys.hpc;
        end
        if not active then
            page.sort_icon:Hide();
            return;
        end
        if heal then
            page.sort_icon:SetTexCoord(0.25, 0.5, 0.0, 0.25);
        else
            page.sort_icon:SetTexCoord(0.25, 0.5, 0.25, 0.5);
        end
        page.sort_icon:ClearAllPoints();
        page.sort_icon:SetPoint("RIGHT", active, "LEFT", 2, 0);
        page.sort_icon:Show();
    end

    local function render_row(row, v, by_lvl, lvl, mode)
        row:Show();
        if v.lvl_barrier then
            row.spell_id = nil;
            row.area:Hide();
            row.lvl:Hide();
            row.type_icon:Hide();
            row.per_sec:Hide();
            row.per_cost:Hide();
            row.cost:Hide();
            row.cost_area:Hide();
            row.item:Hide();
            row.mark:Hide();
            row.ignore_line:Hide();
            set_lvl_text(row.barrier_lvl, lvl, v.lvl_barrier);
            row.barrier:Show();
            row.barrier_lvl:Show();
            row.barrier_line:Show();
            update_hover(row);
            return;
        end
        row.barrier:Hide();
        row.barrier_lvl:Hide();
        row.barrier_line:Hide();

        local id = v.spell_id;
        local spell = spells[id];
        row.spell_id = id;
        row.area.spell_id = id;
        row.area:Show();
        set_name_width(row, mode, by_lvl);

        local known = v.trigger == spell_filters.already_known;
        row.icon:SetTexture((C_Spell.GetSpellTexture(id)));
        row.icon:SetDesaturated(not known);
        if not known and SPELLBOOK_UNLEARNED_TINT_COLOR then
            row.icon:SetVertexColor(SPELLBOOK_UNLEARNED_TINT_COLOR:GetRGB());
        else
            row.icon:SetVertexColor(1, 1, 1);
        end
        if mode.full then
            local border = known and icon_border.known or icon_border.unlearned;
            row.icon_border:SetAtlas(border.atlas, false);
            row.icon_border:ClearAllPoints();
            row.icon_border:SetPoint("TOPLEFT", border.tl[1], border.tl[2]);
            row.icon_border:SetPoint("BOTTOMRIGHT", border.br[1], border.br[2]);

            row.name:SetText(C_Spell.GetSpellName(id));
            row.name:ClearAllPoints();
            if spell.rank ~= 0 then
                row.sub_name:SetText(L["Rank"].." "..spell.rank);
                row.sub_name:Show();
                row.name:SetPoint("BOTTOMLEFT", row.area, "LEFT", full_name_x, 1);
            else
                row.sub_name:Hide();
                row.name:SetPoint("LEFT", row.area, "LEFT", full_name_x, 0);
            end
        elseif spell.rank ~= 0 then
            row.name:SetText(string.format("%s ("..L["Rank"].." %d)", C_Spell.GetSpellName(id), spell.rank));
        else
            row.name:SetText(C_Spell.GetSpellName(id));
        end
        if v.trigger == spell_filters.available then
            row.name:SetTextColor(unpack(ink.available));
        elseif v.trigger == spell_filters.unavailable then
            row.name:SetTextColor(unpack(ink.unavailable));
        elseif v.trigger == spell_filters.missing_requirement then
            row.name:SetTextColor(unpack(ink.missing_requirement));
        else
            row.name:SetTextColor(unpack(base_color));
        end

        if by_lvl then
            row.lvl:Hide();
        else
            set_lvl_text(row.lvl, lvl, spell.lvl_learn or spell.lvl_req);
            row.lvl:Show();
        end

        row.item:Hide();
        row.mark:Hide();
        row.cost:Hide();
        row.cost_area:Hide();
        local mark = "";
        if v.trigger == spell_filters.unavailable and missing_requirement(spell) then
            mark = ink.missing_requirement_code.."!|r";
        end
        local book_price = spell.train < -1 and spell.book_price;
        if not known and (book_price or spell.train >= -1 and (spell.train > 0 or missing_requirement(spell))) then
            row.cost_area.spell_id = id;
            row.cost_area:Show();
        end
        row.item.item_id = nil;
        row.item.taming = nil;
        row.item.req = nil;
        row.item.quest = nil;
        row.item.backing:Hide();
        if spell.train > 0 then
            if not known then
                row.cost:SetText(training.price_str(id, ink.available_code));
                row.cost:Show();
            end
        elseif spell.train < -1 then
            if not known then
                row.item.item_id = -spell.train;
                row.item.tex:SetTexture(C_Item.GetItemIconByID(-spell.train));
                row.item:Show();
                if book_price then
                    row.cost:SetText(training.price_str(id, ink.available_code));
                    row.cost:Show();
                end
            end
        elseif not known then
            if bit.band(spell.flags, spell_flags.talent) ~= 0 then
                row.cost:SetText(L["Talent"]);
                row.cost:Show();
            elseif training.tamed(spell) then
                row.item.taming = id;
                row.item.tex:SetTexture((C_Spell.GetSpellTexture(training.beast_training_id)));
                row.item:Show();
            elseif bit.band(spell.flags, spell_flags.quest) ~= 0 then
                row.item.quest = true;
                row.item.tex:SetTexture(training.quest_texture);
                row.item.backing:Show();
                row.item:Show();
            elseif spell.learned_with then
                row.item.req = id;
                row.item.tex:SetTexture((C_Spell.GetSpellTexture(spell.learned_with[1])));
                row.item:Show();
            else
                row.cost:SetText(L["Unknown"]);
                row.cost:Show();
            end
        end
        if mark ~= "" then
            row.mark:SetText(mark);
            row.mark:Show();
        end
        training.place_cell(row.cost, row.item, row.mark, row.acquisition_at);

        row.type_icon:Hide();
        row.per_sec:Hide();
        row.per_cost:Hide();
        if bit.band(spell.flags, spell_flags.eval) ~= 0 then
            if v.eval_id ~= cat.eval_id then
                eval_spell_view_entry(cat, v);
            end
            if v.is_dual or bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
                row.type_icon:SetTexCoord(0.25, 0.5, 0.0, 0.25);
            else
                row.type_icon:SetTexCoord(0.25, 0.5, 0.25, 0.5);
            end
            row.type_icon:Show();
            row.per_sec:SetText(format_number(v.effect_per_sec, 1));
            row.per_cost:SetText(format_number(v.effect_per_cost, 2));
            row.per_sec:SetTextColor(unpack(per_sec_color));
            row.per_cost:SetTextColor(unpack(per_cost_color));
            row.per_sec:Show();
            row.per_cost:Show();
        elseif bit.band(spell.flags, spell_flags.ehp) ~= 0 then
            row.name:SetText(L["Effective Health"]);
            row.icon:SetTexture(ehp_tex);
            if mode.full then
                row.sub_name:Hide();
                row.name:ClearAllPoints();
                row.name:SetPoint("LEFT", row.area, "LEFT", full_name_x, 0);
            end
            row.type_icon:SetTexCoord(0.0, 0.25, 0.25, 0.5);
            row.type_icon:Show();
        end

        row.ignore_line:SetShown(config.settings.spells_ignore_list[id] ~= nil);
        -- the wheel turns pages under a resting mouse
        update_hover(row);
    end

    local function render_page(page, page_idx, mode)
        update_headers(page);
        local rows = page_rows(page, mode);
        local by_lvl = cat.sort_key == spell_browser_sort_keys.lvl;
        local lvl = active_loadout().lvl;
        local first = page_starts[page_idx];
        local last = -1;
        if first then
            last = (page_starts[page_idx + 1] or (cat.len + 1)) - 1;
        end
        local r = 0;
        local y = page.header_h;
        for i = first or 1, last do
            r = r + 1;
            local v = cat.view[i];
            local h = entry_h(mode, v);
            local row = rows[r];
            row:ClearAllPoints();
            row:SetPoint("TOPLEFT", 0, -y);
            row:SetHeight(h);
            render_row(row, v, by_lvl, lvl, mode);
            y = y + h;
        end
        for k = r + 1, #rows do
            rows[k].spell_id = nil;
            rows[k].hl:Hide();
            rows[k].menu_button:Hide();
            rows[k]:Hide();
        end
    end

    local function render_pages()
        local views = views_shown();
        local mode = current_mode();
        pages[1].footer_divider:SetShown(views == 1);
        for i = 1, 2 do
            if i <= views then
                pages[i]:Show();
                render_page(pages[i], first_page + i - 1, mode);
            else
                pages[i]:Hide();
            end
        end
        -- these rows changed without a loadout update
        if mode.full then
            sc.overlay.update_book_icons();
        end
    end

    local function render_footer(views)
        local lvl = active_loadout().lvl;
        footer.avail:SetText(ink.available_code..L["Available cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.avail_cost));
        if cat.next_cost ~= 0 then
            set_lvl_colored_text(footer.next_label, lvl, cat.next_lvl, L["Next level"].." "..cat.next_lvl..L[" cost:"]);
        end
        footer.next_amount:SetText(C_CurrencyInfo.GetCoinTextureString(cat.next_cost));
        footer.total:SetText(ink.unavailable_code..L["Total cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.total_cost));

        local groups = {};
        for _, g in ipairs({
            {shown = cat.avail_cost ~= 0, footer.avail},
            {shown = cat.next_cost ~= 0, footer.next_label, footer.next_amount},
            {shown = cat.total_cost ~= 0, footer.total},
        }) do
            for _, fs in ipairs(g) do
                fs:SetShown(g.shown);
            end
            if g.shown then
                table.insert(groups, g);
            end
        end

        local left_x = page_x;
        if views ~= 1 then
            left_x = container:GetWidth()/2 + page_x;
        end
        local max_x = math.huge;
        if paging:GetLeft() and container:GetLeft() then
            max_x = paging:GetLeft() - container:GetLeft() - 16;
        end
        local group_gap, part_gap, line_h = 16, 4, 13;
        local lines = {{}};
        local x = left_x;
        for _, g in ipairs(groups) do
            local w = -part_gap;
            for _, fs in ipairs(g) do
                w = w + math.ceil(fs:GetUnboundedStringWidth()) + part_gap;
            end
            if x > left_x and x + w > max_x then
                table.insert(lines, {});
                x = left_x;
            end
            table.insert(lines[#lines], {g = g, x = x});
            x = x + w + group_gap;
        end
        for l, line in ipairs(lines) do
            local y = bottom_bar_y + ((#lines + 1)/2 - l) * line_h;
            for _, e in ipairs(line) do
                local px = e.x;
                for _, fs in ipairs(e.g) do
                    fs:ClearAllPoints();
                    fs:SetPoint("LEFT", container, "BOTTOMLEFT", px, y);
                    px = px + math.ceil(fs:GetUnboundedStringWidth()) + part_gap;
                end
            end
        end
    end

    local function paginate(views, mode)
        clear_table(page_starts);
        local view = cat.view;
        local i = 1;
        while i <= cat.len do
            local p = #page_starts + 1;
            page_starts[p] = i;
            local room = page_height(p, views);
            local start = i;
            while i <= cat.len do
                local h = entry_h(mode, view[i]);
                if h > room or
                    (view[i].lvl_barrier and i < cat.len and h + entry_h(mode, view[i + 1]) > room) then
                    break;
                end
                room = room - h;
                i = i + 1;
            end
            if i == start then
                i = i + 1;
            end
        end
        num_pages = math.max(1, #page_starts);
    end

    local function render(_)
        rendering = true;
        per_sec_color[1], per_sec_color[2], per_sec_color[3] = on_parchment(effect_color("effect_per_sec"));
        per_cost_color[1], per_cost_color[2], per_cost_color[3] = on_parchment(effect_color("effect_per_cost"));
        local views = views_shown();
        paginate(views, current_mode());

        if jump_to_lvl and cat.sort_key == spell_browser_sort_keys.lvl then
            jump_to_lvl = false;
            local lvl = active_loadout().lvl;
            for k, v in ipairs(cat.view) do
                if v.spell_id and lvl <= (spells[v.spell_id].lvl_learn or spells[v.spell_id].lvl_req) then
                    top_entry = k;
                    break;
                end
            end
        end

        local top_page = 1;
        for p = #page_starts, 1, -1 do
            if page_starts[p] <= top_entry then
                top_page = p;
                break;
            end
        end
        local spreads = math.ceil(num_pages / views);
        local spread = math.min(math.floor((top_page - 1) / views) + 1, spreads);
        first_page = (spread - 1) * views + 1;
        paging:SetMaxPages(spreads);
        paging:SetCurrentPage(spread);

        render_footer(views);
        render_pages();
        rendering = false;
    end

    local function create()
        created = true;
        choose_ink();
        layout_columns();
        pages[1] = create_page(1);
        pages[2] = create_page(2);

        paging = CreateFrame("Frame", nil, container, "PagingControlsHorizontalTemplate");
        paging:SetPoint("BOTTOMRIGHT", -75, bottom_bar_y - 16);
        paging.spacing = 8;
        paging.canUseShiftKey = true;
        paging.prevPageSound = SOUNDKIT.IG_ABILITY_PAGE_TURN;
        paging.nextPageSound = SOUNDKIT.IG_ABILITY_PAGE_TURN;
        paging.PageText:SetFontObject("SystemFont_Med3");
        paging.PageText:SetTextColor(unpack(base_color));
        container.OnPageChanged = function()
            if rendering then
                return;
            end
            local views = views_shown();
            local prev_first = first_page;
            first_page = (paging:GetCurrentPage() - 1) * views + 1;
            top_entry = page_starts[first_page] or 1;
            render_pages();
                local forward = first_page > prev_first;
            for i = 1, views do
                local first_to_turn = (i == 1) == forward;
                pages[i].turn_fade:SetDuration((views == 2 and not first_to_turn) and 0.3 or 0.18);
                pages[i].turn:Restart();
            end
        end;
        container:EnableMouseWheel(true);
        container:SetScript("OnMouseWheel", function(_, delta)
            paging:OnMouseWheel(delta);
        end);

        for _, k in ipairs({"avail", "next_label", "next_amount", "total"}) do
            footer[k] = lvl_font_string(container, "GameFontBlackSmall");
            footer[k]:SetTextColor(unpack(base_color));
        end

        local settings = CreateFrame("DropdownButton", nil, container, "UIPanelArrowDropdownButtonTemplate");
        settings:SetPoint("TOPRIGHT", sb.SettingsDropdown, "TOPRIGHT", 0, 0);
        -- the template's frame is smaller than its arrow art
        do
            local w, h = settings:GetSize();
            local icon_w, icon_h = settings.Icon:GetSize();
            local dx = math.max(0, (icon_w - w) / 2) + 2;
            local dy = math.max(0, (icon_h - h) / 2) + 2;
            settings:SetHitRectInsets(-dx, -dx, -dy, -dy);
        end
        settings:SetupMenu(function(_, root)
            for i, f in ipairs(ui.spell_filter_listing) do
                if f.header then
                    if i > 1 then
                        root:CreateDivider();
                    end
                    root:CreateTitle(f.header);
                end
                local key = cat.filter_prefix..f.id;
                local txt = f.disp;
                if f.id == "available" then
                    txt = "|cFF00FF00"..txt.."|r";
                elseif f.id == "unavailable" then
                    txt = "|cFFFF0000"..txt.."|r";
                elseif f.id == "missing_requirement" then
                    txt = "|cFFCC99FF"..txt.."|r";
                end
                local checkbox = root:CreateCheckbox(txt,
                    function()
                        return config.settings[key];
                    end,
                    function()
                        config.settings[key] = not config.settings[key];
                        update_spell_catalogue(cat, nil, nil, nil, true);
                    end
                );
                if f.tooltip then
                    checkbox:SetTooltip(function(tooltip)
                        GameTooltip_AddNormalLine(tooltip, f.tooltip);
                    end);
                end
            end
            root:CreateDivider();
            root:CreateTitle(L["Order by "]);
            for k, txt in ipairs(ui.spell_browser_sort_options) do
                root:CreateRadio(txt,
                    function()
                        return cat.sort_key == k;
                    end,
                    function()
                        set_sort(k);
                    end
                );
            end
        end);
        container.settings = settings;

        -- blizzard's hidden one keeps its place and width
        local search = CreateFrame("EditBox", nil, container, "SearchBoxTemplate");
        search:SetAllPoints(sb.SearchBox);
        search:SetMaxLetters(40);
        search:SetAutoFocus(false);
        search:HookScript("OnTextChanged", function(self)
            cat.name_filter = self:GetText();
            top_entry = 1;
            jump_to_lvl = cat.name_filter == "";
            update_spell_catalogue(cat, nil, nil, nil, true);
        end);
        container.search = search;
    end

    -- the order is not saved, each session starts by level on the player's level page
    cat = new_spell_catalogue(
        "spellbook_catalogue_filter_",
        function()
            return container:IsVisible();
        end,
        render
    );

    function book.on_open()
        if not created then
            create();
        end
        -- in case a change of learned spells came without an event
        spells_known_changed();
        update_spell_catalogue(cat, nil, nil, nil, true);
    end

    function book.on_resize()
        if created and container:IsVisible() then
            render(cat);
        end
    end

    function book.for_each_icon(fn)
        if not created or not container:IsVisible() then
            return;
        end
        local mode = current_mode();
        if not mode.full then
            return;
        end
        for i = 1, views_shown() do
            local set = pages[i].row_sets[mode];
            if set then
                for _, row in ipairs(set.rows) do
                    if row.spell_id and row:IsShown() then
                        fn(row.icon_frame, row.spell_id);
                    end
                end
            end
        end
    end

    return book;
end

---------------------------------------------------------------------------------------------------
-- spell catalogue as an addon tab of the modern spellbook (forever)
-- blizzard rebuilds its tabs on every show and spell change, so this is an own button next to them,
-- only hooks and show / hide of blizzard frames, never writes to blizzard tables (taint)
local spellbook_tab = {};

local function init_spellbook_tab()
    if spellbook_tab.sb or not (PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame) then
        return;
    end
    local sb = PlayerSpellsFrame.SpellBookFrame;
    local tab_row = sb.CategoryTabSystem;
    spellbook_tab.sb = sb;


    local tab, cover, container, book;
    local is_open = false;
    -- open again with the spellbook, as blizzard's tabs are
    local reopen = false;
    local open_tab_id;
    local covered_tab;
    local restore_shown = {};
    local docked_points;

    local blizzard_row_frames = {};
    for _, k in ipairs({"SearchBox", "SearchBoxIcon", "SearchPreviewContainer", "SettingsDropdown", "SettingsTopFaceIcon",
                        "AssistedCombatRotationSpellFrame", "HelpPlateButton", "PreviousCategoryIcon", "NextCategoryIcon",
                        "PagedSpellsFrame"}) do
        if sb[k] then
            blizzard_row_frames[sb[k]] = true;
        end
    end

    local function make_square_tab(name, parent)
        local btn = CreateFrame("Button", name, parent);
        btn:SetSize(44, 32);

        btn.icon = btn:CreateTexture(nil, "ARTWORK");
        btn.icon:SetSize(36, 35);
        btn.icon:SetPoint("BOTTOM");
        btn.icon:SetPoint("CENTER");

        btn.icon_mask = btn:CreateMaskTexture();
        btn.icon_mask:SetAtlas("SquareMask");
        btn.icon_mask:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, -2);
        btn.icon_mask:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", -2, 0);
        btn.icon:AddMaskTexture(btn.icon_mask);

        btn.frame_tex = btn:CreateTexture(nil, "ARTWORK", nil, 1);
        btn.frame_tex:SetAtlas("spellbook-Tab-Frame-C60", true);
        btn.frame_tex:SetPoint("BOTTOM", 0, 1);

        btn.active_tex = btn:CreateTexture(nil, "ARTWORK", nil, 1);
        btn.active_tex:SetAtlas("spellbook-Tab-Frame-Glow-C60", true);
        btn.active_tex:SetPoint("BOTTOM", 0, 1);
        btn.active_tex:Hide();

        btn.glow_tex = btn:CreateTexture(nil, "ARTWORK", nil, 1);
        btn.glow_tex:SetAtlas("spellbook-Tab-Frame-glow-gradient-C60", true);
        btn.glow_tex:SetPoint("BOTTOM", 0, 0);
        btn.glow_tex:Hide();

        return btn;
    end

    local function set_square_tab_selected(btn, selected)
        btn.frame_tex:SetShown(not selected);
        btn.active_tex:SetShown(selected);
        btn.glow_tex:SetShown(selected);
    end

    local function uncover_tab()
        if covered_tab then
            covered_tab.SquareBackgroundActive:SetAlpha(1);
            covered_tab.SquareBackgroundActiveGlow:SetAlpha(1);
            covered_tab = nil;
        end
        cover:Hide();
    end

    -- while the catalogue is open, blizzard's selected tab is drawn unselected and clicking it returns to it
    local function update_cover()
        uncover_tab();
        if not is_open then
            return;
        end
        local selected;
        for _, btn in ipairs(tab_row.tabs) do
            if btn.isSelected and btn:IsShown() then
                selected = btn;
                break;
            end
        end
        if not selected or not selected.SquareBackgroundActive then
            return;
        end
        covered_tab = selected;
        selected.SquareBackgroundActive:SetAlpha(0);
        selected.SquareBackgroundActiveGlow:SetAlpha(0);
        cover:ClearAllPoints();
        cover:SetAllPoints(selected);
        cover:SetFrameLevel(selected:GetFrameLevel() + 5);
        cover:Show();
    end

    -- other addons' tabs right of blizzard's are found by position, ours goes after the last of them
    local function addon_tabs_right()
        local row_right, row_top, row_bottom = tab_row:GetRight(), tab_row:GetTop(), tab_row:GetBottom();
        if not row_right or not row_top or not row_bottom then
            return nil;
        end
        local scale = tab_row:GetEffectiveScale();
        local candidates = {};
        local function collect(...)
            for i = 1, select("#", ...) do
                local f = select(i, ...);
                if f ~= tab and f ~= cover and f ~= container and not blizzard_row_frames[f] and
                    not f.layoutIndex and f:IsShown() and f:GetLeft() and f:GetTop() then

                    local s = f:GetEffectiveScale() / scale;
                    local left, right = f:GetLeft() * s, f:GetRight() * s;
                    local top, bottom = f:GetTop() * s, f:GetBottom() * s;
                    local anchored_to_us = false;
                    for p = 1, f:GetNumPoints() do
                        local _, relative = f:GetPoint(p);
                        if relative == tab then
                            anchored_to_us = true;
                        end
                    end
                    if not anchored_to_us and right - left <= 64 and bottom < row_top and top > row_bottom then
                        table.insert(candidates, {left = left, right = right});
                    end
                end
            end
        end
        collect(sb:GetChildren());
        collect(tab_row:GetChildren());

        local cursor = row_right;
        local found = true;
        while found do
            found = false;
            for _, c in ipairs(candidates) do
                if not c.used and c.left >= cursor - 2 and c.left <= cursor + 24 then
                    c.used = true;
                    cursor = math.max(cursor, c.right);
                    found = true;
                end
            end
        end
        return cursor - row_right;
    end

    local function layout_tab()
        local offset = addon_tabs_right() or 0;
        -- move our tab to avoid conflict with other addons
        if C_AddOns.IsAddOnLoaded("WhatsTraining") then
            offset = math.max(offset, 8 + 44 - 8);
        end
        tab:ClearAllPoints();
        -- extra spacing after blizzard's tabs marks the addon tabs, after another addon's tab ours sits right against it
        tab:SetPoint("TOPLEFT", tab_row, "TOPRIGHT", offset > 0 and offset or 12, 0);
    end

    local function set_blizzard_shown(shown)
        for _, f in ipairs({sb.PagedSpellsFrame, sb.SearchBox, sb.SettingsDropdown}) do
            if shown then
                f:SetShown(restore_shown[f]);
            else
                restore_shown[f] = f:IsShown();
                f:Hide();
            end
        end
        if not shown then
            sb.SearchPreviewContainer:Hide();
        end
    end

    local function close()
        if not is_open then
            return;
        end
        is_open = false;
        container:Hide();
        set_square_tab_selected(tab, false);
        uncover_tab();
        set_blizzard_shown(true);
        -- spellbook buttons show again with stale overlays
        sc.loadouts.force_update = true;
        sc.core.deactivate_tooltip_refresh();
    end

    local function open()
        if is_open then
            return;
        end
        is_open = true;
        open_tab_id = sb:GetTab();
        set_blizzard_shown(false);
        container:Show();
        set_square_tab_selected(tab, true);
        update_cover();
        book.on_open();
        sc.core.activate_tooltip_refresh();
    end

    local function undock_sc_frame()
        if docked_points then
            __sc_frame:ClearAllPoints();
            for _, p in ipairs(docked_points) do
                __sc_frame:SetPoint(unpack(p));
            end
            docked_points = nil;
        end
    end

    local function dock_sc_frame()
        local ui_scale = UIParent:GetEffectiveScale();
        local right = PlayerSpellsFrame:GetRight();
        if not right or
            right * PlayerSpellsFrame:GetEffectiveScale() + __sc_frame:GetWidth() * __sc_frame:GetEffectiveScale() >
            GetScreenWidth() * ui_scale then
            return;
        end
        if not spellbook_tab.sc_frame_hooked then
            spellbook_tab.sc_frame_hooked = true;
            __sc_frame:HookScript("OnHide", undock_sc_frame);
            __sc_frame:HookScript("OnDragStart", function()
                docked_points = nil;
            end);
        end
        docked_points = {};
        for i = 1, __sc_frame:GetNumPoints() do
            docked_points[i] = {__sc_frame:GetPoint(i)};
        end
        __sc_frame:ClearAllPoints();
        __sc_frame:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 4, 0);
    end

    -- named so the "Spellbook tab button" setting shows and hides it, as the legacy spellbook button
    tab = make_square_tab("__sc_frame_spellbook_tab", sb);
    tab.icon:SetTexture("Interface\\Icons\\spell_fire_elementaldevastation");
    tab:SetScript("OnClick", function()
        if not is_open then
            open();
            PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN);
        end
    end);
    tab:SetScript("OnShow", layout_tab);
    -- the setting hid it, not the spellbook closing
    tab:SetScript("OnHide", function(self)
        if not self:IsShown() then
            close();
        end
    end);
    if not config.settings.general_spellbook_button then
        tab:Hide();
    end

    cover = make_square_tab(nil, sb);
    cover:Hide();
    cover.icon:Hide();
    cover:SetScript("OnClick", function()
        close();
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN);
    end);
    cover:SetScript("OnEnter", function(self)
        if covered_tab and covered_tab.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -12, -6);
            GameTooltip:AddLine(covered_tab.tooltipText);
            GameTooltip:Show();
        end
    end);
    cover:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);

    container = CreateFrame("Frame", nil, sb);
    container:SetPoint("TOPLEFT", 0, -50);
    container:SetPoint("BOTTOMRIGHT");
    container:Hide();

    book = create_book_catalogue(sb, container, function(frame_name)
        -- next to a single page book, a two page one leaves no room
        local dock = not __sc_frame:IsShown() and sb.isMinimized;
        sw_activate_frame(frame_name);
        if dock then
            dock_sc_frame();
        end
    end);

    tab_row:HookScript("OnSizeChanged", layout_tab);
    sb:HookScript("OnShow", function()
        layout_tab();
        if is_open then
            book.on_open();
        elseif reopen and tab:IsShown() then
            open();
        end
        reopen = false;
    end);
    -- switching between one and two pages hides and shows the spellbook in the same frame
    local function close_if_hidden()
        if not sb:IsVisible() then
            reopen = is_open;
            close();
        end
    end
    sb:HookScript("OnHide", function()
        C_Timer.After(0, close_if_hidden);
    end);

    -- tab clicks, gamepad and spec changes all pass here, spell updates set the same tab again
    hooksecurefunc(sb, "OnActiveCategoryChanged", function()
        if is_open and sb:GetTab() ~= open_tab_id then
            close();
        end
    end);
    hooksecurefunc(sb, "GoToSpell", function()
        reopen = false;
        close();
    end);
    hooksecurefunc(sb, "SetMinimized", function()
        -- docked right of a single page, an open book would push it off screen
        if not sb.isMinimized then
            undock_sc_frame();
        end
        book.on_resize();
    end);
    -- tabs are rebuilt from a pool, the selected one may be another button now
    hooksecurefunc(tab_row, "SetTabVisuallySelected", update_cover);
    -- opened alone the spellbook is a center panel, showing one closes UISpecialFrames (the addon frame's escape close)
    hooksecurefunc("ShowUIPanel", function(frame)
        if frame == PlayerSpellsFrame and __sc_frame.hidden_time == GetTime() then
            __sc_frame:Show();
        end
    end);

    layout_tab();

    spellbook_tab.container = container;
    spellbook_tab.for_each_icon = book.for_each_icon;
    spellbook_tab.close = close;
    spellbook_tab.undock_sc_frame = undock_sc_frame;
    spellbook_tab.is_open = function()
        return is_open;
    end;
end

-- the client may save the addon frame's position at logout
local function spellbook_tab_undock_sc_frame()
    if spellbook_tab.undock_sc_frame then
        spellbook_tab.undock_sc_frame();
    end
end

-- fn(icon_frame, spell_id) for the spellbook catalogue's shown icons (non compact mode, forever)
ui.for_each_book_icon = function(fn)
    if spellbook_tab.for_each_icon then
        spellbook_tab.for_each_icon(fn);
    end
end;

ui.init_spellbook_tab            = init_spellbook_tab;
ui.spellbook_tab_undock_sc_frame = spellbook_tab_undock_sc_frame;
