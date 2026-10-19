local _, sc = ...;

local L                                         = sc.L;

local spells                                    = sc.spells;
local spids                                     = sc.spids;
local spell_flags                               = sc.spell_flags;

local format_locale_dump                        = sc.loc.format_locale_dump;

local clear_table                               = sc.utils.clear_table;
local assign_color_tag                          = sc.utils.assign_color_tag;
local client_matches                            = sc.utils.client_matches;
local is_secret                                 = sc.utils.is_secret;
local client_flags                              = sc.client_flags;
local highest_learned_rank                      = sc.utils.highest_learned_rank;
local effect_color                              = sc.utils.effect_color;
local write_item_info_from_link                 = sc.utils.write_item_info_from_link;
local request_item_data                         = sc.utils.request_item_data;

local wowhead_talent_link                       = sc.talents.wowhead_talent_link;
local wowhead_talent_code_from_url              = sc.talents.wowhead_talent_code_from_url;

local inv_type_to_slot_ids                      = sc.equipment.inv_type_to_slot_ids;
local apply_items_cmp                           = sc.equipment.apply_items_cmp;
local slots                                     = sc.equipment.slots;

local fight_types                               = sc.calc.fight_types;
local evaluation_flags                          = sc.calc.evaluation_flags;

local format_number                             = sc.utils.format_number;
local color_by_lvl_diff                         = sc.utils.color_by_lvl_diff;

local update_loadout_and_effects_diffed_from_ui = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local update_loadout_and_effects                = sc.loadouts.update_loadout_and_effects;
local active_loadout                            = sc.loadouts.active_loadout
local stats_diff_format                         = sc.loadouts.stats_diff_format;
local stats_format                              = sc.loadouts.stats_format;
local cpy_effects                               = sc.loadouts.cpy_effects;
local effects_finalize_forced                   = sc.loadouts.effects_finalize_forced;
local empty_effects                             = sc.loadouts.empty_effects;

local spell_diff                                = sc.calc.spell_diff;
local ehp_diff                                  = sc.calc.ehp_diff;
local calc_spell_eval                           = sc.calc.calc_spell_eval;

local buff_category                             = sc.buffs.buff_category;
local buffs                                     = sc.buffs.buffs;
local target_buffs                              = sc.buffs.target_buffs;

local stat_diffs_included_effects_str           = sc.tooltip.stat_diffs_included_effects_str;
local colored_diff_str                          = sc.tooltip.colored_diff_str;

local config                                    = sc.config;

-------------------------------------------------------------------------
local ui = {};

local __sc_frame = {};

local role_icons = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES";
local font = "GameFontHighlightSmall";
local libstub_data_broker = LibStub("LibDataBroker-1.1", true);
local libstub_icon = libstub_data_broker and LibStub("LibDBIcon-1.0", true);
local libstub_launcher;

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

local function display_spell_diff(i, calc_list, diff, frame)
    if not calc_list[i] then
        calc_list[i] = {};

        frame.y_offset = frame.y_offset - 15;

        calc_list[i].spell_icon = CreateFrame("Frame", nil, frame);
        calc_list[i].spell_icon:SetSize(15, 15);
        calc_list[i].spell_icon:SetPoint("TOPLEFT", 0, frame.y_offset+2);
        calc_list[i].spell_icon.tex = calc_list[i].spell_icon:CreateTexture(nil, "ARTWORK");
        calc_list[i].spell_icon.tex:SetAllPoints(calc_list[i].spell_icon);

        calc_list[i].tooltip_area = CreateFrame("Frame", nil, frame);
        calc_list[i].tooltip_area:SetSize(100, 16);
        calc_list[i].tooltip_area:SetPoint("TOPLEFT", 0, frame.y_offset+2);
        calc_list[i].tooltip_area.spell_id = 0;
        calc_list[i].tooltip_area:EnableMouse(true);
        calc_list[i].tooltip_area:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetSpellByID(self.spell_id);
            GameTooltip:Show();

        end);
        calc_list[i].tooltip_area:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        calc_list[i].tooltip_area:HookScript("OnMouseWheel", sc.tooltip.eval_mode_scroll_fn);

        calc_list[i].name_str = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].name_str:SetFontObject(font);
        calc_list[i].name_str:SetPoint("TOPLEFT", 20, frame.y_offset);

        calc_list[i].role_icon = CreateFrame("Frame", nil, frame);
        calc_list[i].role_icon:SetSize(15, 15);
        calc_list[i].role_icon:SetPoint("TOPLEFT", 225, frame.y_offset+2);
        calc_list[i].role_icon.tex = calc_list[i].role_icon:CreateTexture(nil, "ARTWORK");
        calc_list[i].role_icon.tex:SetTexture(role_icons);

        calc_list[i].first = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].first:SetFontObject(font);
        calc_list[i].first:SetPoint("LEFT", frame, "TOPLEFT", 260, frame.y_offset-4);
        calc_list[i].second = frame:CreateFontString(nil, "OVERLAY");
        calc_list[i].second:SetFontObject(font);
        calc_list[i].second:SetPoint("LEFT", frame, "TOPLEFT", 360, frame.y_offset-4);


        calc_list[i].cancel_button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
        calc_list[i].cancel_button:SetScript("OnClick", function(self)
            config.settings.spell_calc_list[self.__id_src] = nil;
            for k, v in pairs(calc_list[frame.num_spells]) do
                v:Hide();
            end
            ui.update_calc_list(true);
        end);

        calc_list[i].cancel_button:SetPoint("TOPRIGHT", -10, frame.y_offset + 4);
        calc_list[i].cancel_button:SetSize(17, 17);
        calc_list[i].cancel_button:SetText("x");
        local fontstr = calc_list[i].cancel_button:GetFontString();
        if fontstr then
            fontstr:ClearAllPoints();
            fontstr:SetPoint("CENTER", calc_list[i].cancel_button, "CENTER");
            fontstr:SetIgnoreParentAlpha(true);
            fontstr:SetMouseClickEnabled(false);
        end
        calc_list[i].cancel_button:SetFrameLevel(calc_list[i].cancel_button:GetFrameLevel() + 1);
    end
    local v = calc_list[i];

    v.cancel_button.__id_src = diff.original_id;

    v.tooltip_area.spell_id = diff.id;
    v.spell_icon.tex:SetTexture(diff.tex);

    v.name_str:SetText(diff.disp);

    v.name_str:SetTextColor(222/255, 192/255, 40/255);

    v.first:SetText(colored_diff_str(diff.effect, diff.effect_changed_perc, 2));
    v.second:SetText(colored_diff_str(diff.effect_timed, diff.effect_timed_changed_perc, 2));

    if diff.heal_like then
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.0, 0.25);
    elseif diff.tank_like then
        v.role_icon.tex:SetTexCoord(0.0, 0.25, 0.25, 0.5);
        v.second:SetText(" ");
    else
        v.role_icon.tex:SetTexCoord(0.25, 0.5, 0.25, 0.5);
    end
    v.role_icon.tex:SetAllPoints(v.role_icon);


    for _, f in pairs(v) do
        f:Show();
    end
    if diff.is_dual_spell then
        calc_list[i].cancel_button:Hide();
    end
end

local cached_spells_cmp_diffs = {};

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

    for _, v in pairs(frame.calc_list) do
        for _, f in pairs(v) do
            f:Hide();
        end
    end

    eval_flags = bit.bor(eval_flags, evaluation_flags.expectation_of_self);

    local diffs, _, diffs_in, diffs_out = stats_diff_format(loadout, effects, effects_diffed);
    frame.diffs_txt = diffs;
    frame.before_txt = stats_format(loadout, effects);
    frame.after_txt = stats_format(loadout, effects_diffed);

    frame.diffs_fontstr:SetText(L["Changes"].."\n|cFF00FF00 +"..diffs_in.." |r|cFFFF0000 -"..diffs_out.."|r");

    if frame.diffs_txt ~= "" then
        frame.diffs_txt = stat_diffs_included_effects_str(true, true, true)..frame.diffs_txt;
    end

    local i = 0;
    for k, _ in pairs(config.settings.spell_calc_list) do

        local original_k = k;
        if config.settings.calc_list_use_highest_rank and spells[k] then
            k = highest_learned_rank(spells[k].base_id);
        end
        if k and spells[k] then
            if bit.band(spells[k].flags, spell_flags.eval) ~= 0 then

                i = i + 1;
                cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

                spell_diff(cached_spells_cmp_diffs[i],
                           config.settings.calc_fight_type,
                           spells[k],
                           k,
                           loadout,
                           effects,
                           effects_diffed,
                           eval_flags);

                cached_spells_cmp_diffs[i].is_dual_spell = spells[k].healing_version ~= nil;
                cached_spells_cmp_diffs[i].original_id = original_k;

                -- for spells with both heal and dmg
                if spells[k].healing_version then

                    i = i + 1;
                    cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

                    spell_diff(cached_spells_cmp_diffs[i],
                               config.settings.calc_fight_type,
                               spells[k].healing_version,
                               k,
                               loadout,
                               effects,
                               effects_diffed,
                               eval_flags);
                    cached_spells_cmp_diffs[i].is_dual_spell = false;
                    cached_spells_cmp_diffs[i].original_id = original_k;
                end
            elseif bit.band(spells[k].flags, spell_flags.ehp) ~= 0 then

                i = i + 1;
                cached_spells_cmp_diffs[i] = cached_spells_cmp_diffs[i] or {};

                ehp_diff(cached_spells_cmp_diffs[i],
                         loadout,
                         effects,
                         effects_diffed,
                         eval_flags);

                cached_spells_cmp_diffs[i].is_dual_spell = false;
                cached_spells_cmp_diffs[i].original_id = original_k;
            end
        end
    end
    __sc_frame.calculator_frame.num_spells = i;

    for j = 1, i do
        ui.display_spell_diff(j, frame.calc_list, cached_spells_cmp_diffs[j], frame);
    end
    frame.spells_add_tip:SetPoint("TOPLEFT", 5, frame.y_offset-20);

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
    frame:SetScript("OnTextChanged", update_func);
    frame:SetScript("OnTextSet", update_func);
end

local filtered_buffs = {};
local filtered_target_buffs = {};
local buffs_views = {
    {side = "lhs", subject = "self", buffs = buffs, filtered = filtered_buffs},
    {side = "rhs", subject = "target_buffs", buffs = target_buffs, filtered = filtered_target_buffs}
};

local buff_categories_colors = {
    [buff_category.class]       = {0/255,   204/255, 255/255},
    [buff_category.player]      = {225/255, 235/255, 52/255 },
    [buff_category.enchant]     = {103/255, 52/255,  235/255},
    [buff_category.hostile]     = {235/255, 52/255,  88/255 },
    [buff_category.friendly]    = {0/255,   153/255, 51/255 },
};

local spell_filter_listing;
local spell_browser_sort_options;
local spell_browser_sort_keys = {
    lvl = 1,
    dps = 2,
    hps = 3,
    dpc = 4,
    hpc = 5,
};

-- config keys are a catalogue's filter_prefix followed by the id, the first three indices double as triggers
local spell_filter_ids = {
    "already_known",
    "available",
    "unavailable",
    "learned_from_item",
    "talent",
    "pet",
    "ignored_spells",
    "other_spells",
    "only_highest_learned_ranks",
};
local spell_filters = {};
for k, id in ipairs(spell_filter_ids) do
    spell_filters[id] = k;
end

-- meant to happen only the first time
local spell_browser_scroll_to_lvl = true;

-- learned state only changes with SPELLS_CHANGED / LEARNED_SPELL_IN_SKILL_LINE
local spells_known_cache = {};
local highest_learned_cache = {};
local spells_known_dirty = true;

local function spells_known_changed()
    spells_known_dirty = true;
end

local function cached_highest_learned_rank(base_id)
    local highest = highest_learned_cache[base_id];
    if highest == nil then
        highest = highest_learned_rank(base_id) or false;
        highest_learned_cache[base_id] = highest;
    end
    return highest or nil;
end

local function spell_known(id)
    local known = spells_known_cache[id];
    if known == nil then
        known = IsSpellKnownOrOverridesKnown(id) or IsSpellKnownOrOverridesKnown(id, true);
        if not known then
            -- deal with spells that you unlearn when you have a higher rank
            local highest = cached_highest_learned_rank(spells[id].base_id);
            known = spells[highest] ~= nil and spells[highest].rank > spells[id].rank;
        end
        spells_known_cache[id] = known;
    end
    return known;
end

local pickup_spell = C_Spell.PickupSpell or PickupSpell;

local function pickup_known_spell(id)
    if id and IsSpellKnownOrOverridesKnown(id) then
        pickup_spell(id);
    end
end

-- art of blizzard's arrow dropdown button (UIPanelArrowDropdownButtonTemplate), nil on clients without the atlas
local function create_arrow_button(parent, size)
    if not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-dropdown-a-button")) then
        return nil;
    end
    local btn = CreateFrame("Button", nil, parent);
    btn:SetSize(size, size);
    btn.icon = btn:CreateTexture(nil, "ARTWORK");
    btn.icon:SetAtlas("common-dropdown-a-button");
    btn.icon:SetSize(size + 2, size + 2);
    btn.icon:SetPoint("CENTER");
    local hl = btn:CreateTexture(nil, "HIGHLIGHT");
    hl:SetAtlas("common-dropdown-a-button");
    hl:SetBlendMode("ADD");
    hl:SetAlpha(0.4);
    hl:SetAllPoints(btn.icon);
    btn:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1); end);
    btn:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0); end);
    return btn;
end

local spell_lower_names = {};

local function spell_lower_name(id)
    local lname = spell_lower_names[id];
    if not lname then
        lname = string.lower(C_Spell.GetSpellName(id));
        spell_lower_names[id] = lname;
    end
    return lname;
end

local function spell_view_trigger(filters, id, lvl, name_filter)
    local spell = spells[id];

    if name_filter ~= "" and not string.find(spell_lower_name(id), name_filter, 1, true) then
        return nil;
    end
    local known = spell_known(id);
    local trigger;
    if filters.already_known and known then
        trigger = spell_filters.already_known;
    elseif filters.available and lvl >= spell.lvl_req and not known then
        trigger = spell_filters.available;
    elseif filters.unavailable and lvl < spell.lvl_req then
        trigger = spell_filters.unavailable;
    else
        return nil;
    end

    if not filters.learned_from_item and spell.train < -1 then
        return nil;
    end
    if not filters.pet and bit.band(spell.flags, spell_flags.pet) ~= 0 then
        return nil;
    end
    if not filters.talent and bit.band(spell.flags, spell_flags.talent) ~= 0 then
        return nil;
    end
    if not filters.ignored_spells and config.settings.spells_ignore_list[id] then
        return nil;
    end
    if not filters.other_spells and spell.train == 0 then
        return nil;
    end
    if filters.only_highest_learned_ranks and
        cached_highest_learned_rank(spell.base_id) ~= id then
        return nil;
    end
    if spell.race_flags and bit.band(spell.race_flags, bit.lshift(1, sc.race-1)) == 0 then
        return nil;
    end
    return trigger;
end

-- each catalogue has its own filters, sort and view, the ignore and calculator lists are shared
local spell_catalogues = {};

local function new_spell_catalogue(filter_prefix, is_visible, render)
    local cat = {
        filter_prefix = filter_prefix,
        filters = {},
        name_filter = "",
        sort_key = spell_browser_sort_keys.lvl,
        -- entries are reused between updates, the view only holds references to them
        view = {},
        pool = {},
        len = 0,
        -- rows are evaluated when they are displayed, with the inputs of the last update
        eval = {},
        eval_id = 0,
        update_id = 0,
        next_lvl = 0,
        avail_cost = 0,
        next_cost = 0,
        total_cost = 0,
        is_visible = is_visible,
        render = render,
    };
    table.insert(spell_catalogues, cat);
    return cat;
end

local function spell_view_entry(cat, i)
    local v = cat.pool[i];
    if not v then
        v = {};
        cat.pool[i] = v;
    end
    v.spell_id = nil;
    v.lvl_barrier = nil;
    v.trigger = nil;
    v.is_dual = false;
    v.evaluable = false;
    v.eval_id = -1;
    v.effect_per_sec = nil;
    v.effect_per_cost = nil;
    v.dps = 0;
    v.hps = 0;
    v.dpc = 0;
    v.hpc = 0;
    cat.view[i] = v;
    return v;
end

local function eval_spell_view_entry(cat, v)
    local spell = spells[v.spell_id];
    if v.is_dual then
        spell = spell.healing_version;
    end
    local info = calc_spell_eval(spell,
                                 cat.eval.loadout,
                                 cat.eval.effects,
                                 cat.eval.eval_flags,
                                 v.spell_id);
    v.effect_per_sec = info.effect_per_sec;
    v.effect_per_cost = info.effect_per_cost;
    if v.is_dual or bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
        v.hps = info.effect_per_sec;
        v.hpc = info.effect_per_cost;
    else
        v.dps = info.effect_per_sec;
        v.dpc = info.effect_per_cost;
    end
    v.eval_id = cat.eval_id;
end

local function filtered_spell_view(cat, spell_ids)

    if spells_known_dirty then
        clear_table(spells_known_cache);
        clear_table(highest_learned_cache);
        spells_known_dirty = false;
    end

    local settings = config.settings;
    local filters = cat.filters;
    for _, id in ipairs(spell_filter_ids) do
        filters[id] = settings[cat.filter_prefix..id];
    end

    local lvl = active_loadout().lvl;
    local next_lvl = lvl + 1;
    if lvl % 2 == 0 then
        next_lvl = lvl + 2;
    end
    local avail_cost = 0;
    local next_cost = 0;
    local total_cost = 0;

    local name_filter = string.lower(cat.name_filter);
    local by_lvl = cat.sort_key == spell_browser_sort_keys.lvl;
    local prev_lvl = -1;
    local n = 0;

    for _, id in ipairs(spell_ids) do
        local trigger = spell_view_trigger(filters, id, lvl, name_filter);
        if trigger then
            local spell = spells[id];
            if spell.train > 0 then
                if spell.lvl_req == next_lvl then
                    next_cost = next_cost + spell.train;
                end
                if trigger == spell_filters.available then
                    avail_cost = avail_cost + spell.train;
                end
                if trigger ~= spell_filters.already_known then
                    total_cost = total_cost + spell.train;
                end
            end
            if by_lvl and spell.lvl_req ~= prev_lvl then
                n = n + 1;
                spell_view_entry(cat, n).lvl_barrier = spell.lvl_req;
                prev_lvl = spell.lvl_req;
            end
            n = n + 1;
            local v = spell_view_entry(cat, n);
            v.spell_id = id;
            v.trigger = trigger;
            v.evaluable = bit.band(spell.flags, spell_flags.eval) ~= 0;
            if spell.healing_version then
                n = n + 1;
                local dual = spell_view_entry(cat, n);
                dual.spell_id = id;
                dual.trigger = trigger;
                dual.is_dual = true;
                dual.evaluable = true;
            end
        end
    end
    local view = cat.view;
    for i = n + 1, cat.len do
        view[i] = nil;
    end
    cat.len = n;
    cat.next_lvl = next_lvl;
    cat.avail_cost = avail_cost;
    cat.next_cost = next_cost;
    cat.total_cost = total_cost;

    if not by_lvl then
        -- sorting needs every entry evaluated
        for i = 1, n do
            if view[i].evaluable then
                eval_spell_view_entry(cat, view[i]);
            end
        end
        if cat.sort_key == spell_browser_sort_keys.dps then
            table.sort(view, function(lhs, rhs) return lhs.dps > rhs.dps; end);
        elseif cat.sort_key == spell_browser_sort_keys.hps then
            table.sort(view, function(lhs, rhs) return lhs.hps > rhs.hps; end);
        elseif cat.sort_key == spell_browser_sort_keys.dpc then
            table.sort(view, function(lhs, rhs) return lhs.dpc > rhs.dpc; end);
        elseif cat.sort_key == spell_browser_sort_keys.hpc then
            table.sort(view, function(lhs, rhs) return lhs.hpc > rhs.hpc; end);
        end
    end

    return view;
end

local function spell_catalogue_cost_str(cat)
    local cost_str = "";
    if cat.avail_cost ~= 0 then
        cost_str = cost_str.."   |cFF00FF00"..L["Available cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.avail_cost);
    end
    if cat.next_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF8C00"..L["Next level"].." "..cat.next_lvl..L[" cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.next_cost);
    end
    if cat.total_cost ~= 0 then
        cost_str = cost_str.."   |cFFFF0000"..L["Total cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.total_cost);
    end
    return cost_str;
end

local ehp_tex = "Interface\\Icons\\Spell_Nature_Reincarnation";

local function populate_scrollable_spell_view(cat, starting_idx)
    local view = cat.view;
    local by_lvl = cat.sort_key == spell_browser_sort_keys.lvl;
    local cnt = 1;
    local n = #__sc_frame.spells_frame.scroll_view;
    local list_len = #view;
    local i = starting_idx;
    local lvl = active_loadout().lvl;

    -- clear previous
    for _, v in pairs(__sc_frame.spells_frame.scroll_view) do
        for _, e in pairs(v) do
            e:Hide();
        end
    end
    while cnt <= n and i <= list_len do
        local v = view[i];
        local line = __sc_frame.spells_frame.scroll_view[cnt];
        if v.spell_id then
            --line.spell_icon.__id = v.spell_id;
            line.tooltip_area.__id = v.spell_id;
            line.spell_tex:SetTexture((C_Spell.GetSpellTexture(v.spell_id)));
            local known = v.trigger == spell_filters.already_known or v.is_dual;
            line.spell_tex:SetDesaturated(not known);
            if not known and SPELLBOOK_UNLEARNED_TINT_COLOR then
                line.spell_tex:SetVertexColor(SPELLBOOK_UNLEARNED_TINT_COLOR:GetRGB());
            else
                line.spell_tex:SetVertexColor(1, 1, 1);
            end
            line.spell_icon:Show();
            line.hover:Show();
            line.spell_tex:Show();
            line.tooltip_area:Show();
            line.dropdown_menu.__spid = v.spell_id;
            line.dropdown_button:Show();

            if spells[v.spell_id].rank ~= 0 then
                line.spell_name:SetText(string.format("%s ("..L["Rank"].." %d)",
                    C_Spell.GetSpellName(v.spell_id),
                    spells[v.spell_id].rank
                ));
            else
                line.spell_name:SetText(C_Spell.GetSpellName(v.spell_id));
            end
            if v.trigger == spell_filters.already_known then
                line.spell_name:SetTextColor(138 / 255, 134 / 255, 125 / 255);
            elseif v.trigger == spell_filters.available then
                line.spell_name:SetTextColor(0 / 255, 255 / 255,   0 / 255);
            elseif v.trigger == spell_filters.unavailable then
                line.spell_name:SetTextColor(252 / 255,  69 / 255,   3 / 255);
            end
            line.spell_name:Show();
            -- do level per line if not sorting by lvl
            if not by_lvl then
                line.lvl_str:SetText(color_by_lvl_diff(lvl, spells[v.spell_id].lvl_req)..spells[v.spell_id].lvl_req);
                line.lvl_str:Show();
            end
            -- write in currency/book cost column
            if spells[v.spell_id].train > 0 then
                if v.trigger == spell_filters.already_known or v.is_dual then
                    line.cost_str:SetText("");
                else
                    line.cost_str:SetText(C_CurrencyInfo.GetCoinTextureString(spells[v.spell_id].train));
                end
                line.cost_str:Show();
            elseif spells[v.spell_id].train < -1 then
                if v.trigger == spell_filters.already_known or v.is_dual then
                else
                    line.book_icon.__id = -spells[v.spell_id].train;
                    line.book_tex:SetTexture(C_Item.GetItemIconByID(-spells[v.spell_id].train));
                    line.book_tex:Show();
                    line.book_icon:Show();
                end
            else
                if v.trigger == spell_filters.already_known or v.is_dual then
                elseif bit.band(spells[v.spell_id].flags, spell_flags.talent) ~= 0 then
                    line.cost_str:SetText(L["Talent"]);
                    line.cost_str:Show();
                else
                    line.cost_str:SetText(L["Unknown"]);
                    line.cost_str:Show();
                end
            end
            if bit.band(spells[v.spell_id].flags, spell_flags.eval) ~= 0 then
                if v.eval_id ~= cat.eval_id then
                    eval_spell_view_entry(cat, v);
                end
                if v.is_dual or bit.band(spells[v.spell_id].flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
                    line.effect_type_tex:SetTexCoord(0.25, 0.5, 0.0, 0.25);
                else
                    line.effect_type_tex:SetTexCoord(0.25, 0.5, 0.25, 0.5);
                end
                line.effect_type_tex:SetAllPoints(line.effect_type_icon);
                line.effect_type_tex:Show();
                line.effect_type_icon:Show();
                line.per_sec_str:SetText(format_number(v.effect_per_sec, 1));
                line.per_cost_str:SetText(format_number(v.effect_per_cost, 2));
                line.type_str:Show();
                line.per_sec_str:Show();
                line.per_cost_str:Show();
            elseif bit.band(spells[v.spell_id].flags, spell_flags.ehp) ~= 0 then
                line.spell_name:SetText(L["Effective Health"]);
                line.spell_tex:SetTexture(ehp_tex);
                line.effect_type_tex:SetTexCoord(0.0, 0.25, 0.25, 0.5);
                line.effect_type_tex:SetAllPoints(line.effect_type_icon);
                line.effect_type_tex:Show();
                line.effect_type_icon:Show();
            end
            if config.settings.spells_ignore_list[v.spell_id] then
                line.ignore_line:Show();
            end

        elseif v.lvl_barrier then
            line.spell_name:SetText("<<< "..L["Level"].." "..color_by_lvl_diff(lvl, v.lvl_barrier)..v.lvl_barrier.."|cFFFFFFFF >>>");
            line.spell_name:SetTextColor(1.0, 1.0, 1.0);
            line.spell_name:Show();
        end
        i = i + 1;
        cnt = cnt + 1;
    end
    for _, line in pairs(__sc_frame.spells_frame.scroll_view) do
        line.hover.update();
    end
end

local function render_spells_frame(cat)
    local frame = __sc_frame.spells_frame;
    local view = cat.view;

    frame.footer_cost:SetText(spell_catalogue_cost_str(cat));
    if cat.sort_key == spell_browser_sort_keys.lvl then
        frame.header_level:Hide();
    else
        frame.header_level:Show();
    end

    frame.slider:SetMinMaxValues(
        1,
        math.max(1, #view - math.floor(#frame.scroll_view/2))
    );
    if spell_browser_scroll_to_lvl then
        local suitable_idx = 1;
        local lvl = active_loadout().lvl;
        for k, v in pairs(view) do
            if v.spell_id and lvl <= spells[v.spell_id].lvl_req then
                suitable_idx = k;
                break;
            end
        end
        suitable_idx = math.max(1, suitable_idx-10);
        frame.slider_val = suitable_idx;
        spell_browser_scroll_to_lvl = false;
    end
    frame.slider:SetValue(frame.slider_val);
    populate_scrollable_spell_view(cat, math.floor(frame.slider_val));
end

local function update_spell_catalogue(cat, loadout, effects, eval_flags, force_refresh)

    if not loadout then
        local calc_mode = __sc_frame:IsShown() and __sc_frame.calculator_frame:IsShown() or
            config.settings.general_calc_global_compare;

        local update_id;
        eval_flags = sc.overlay.overlay_eval_flags();
        if calc_mode then
            loadout, _, _, _, effects, update_id = update_loadout_and_effects_diffed_from_ui();
        else
            loadout, _, effects, update_id = update_loadout_and_effects();
        end

        if update_id > cat.update_id then
            cat.update_id = update_id;
        else
            if not force_refresh then
                return;
            end
        end
    end

    cat.eval.loadout = loadout;
    cat.eval.effects = effects;
    cat.eval.eval_flags = eval_flags;
    cat.eval_id = cat.eval_id + 1;

    filtered_spell_view(cat, sc.spells_lvl_ordered);
    cat.render(cat);
end

local function spell_catalogue_visible()
    for _, cat in ipairs(spell_catalogues) do
        if cat.is_visible() then
            return true;
        end
    end
    return false;
end

local function update_spell_catalogues(loadout, effects, eval_flags, force_refresh)
    for _, cat in ipairs(spell_catalogues) do
        if cat.is_visible() then
            update_spell_catalogue(cat, loadout, effects, eval_flags, force_refresh);
        end
    end
end

local spells_catalogue = new_spell_catalogue(
    "spells_filter_",
    function()
        return __sc_frame:IsShown() and __sc_frame.spells_frame:IsShown();
    end,
    render_spells_frame
);

local function update_spells_frame(loadout, effects, eval_flags, force_refresh)
    update_spell_catalogue(spells_catalogue, loadout, effects, eval_flags, force_refresh);
end

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

local function sw_activate_frame(frame_name)
    sw_activate_tab(__sc_frame.tabs[ui_tabs_idx[frame_name]]);
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

local function create_sw_ui_spells_frame(pframe)

    pframe:HookScript("OnHide", function()
        sc.core.deactivate_tooltip_refresh();
    end);

    spell_filter_listing = {
        {
            id = "already_known",
            disp = L["Already known"],
        },
        {
            id = "available",
            disp = L["Available"],
        },
        {
            id = "unavailable",
            disp = L["Unavailable"],
        },
        {
            id = "learned_from_item",
            disp = L["Learned from item"],
        },
        {
            id = "talent",
            disp = L["Talent spells"],
        },
        {
            id = "pet",
            disp = L["Pet spells"],
        },
        {
            id = "ignored_spells",
            disp = L["Ignored spells"],
        },
        {
            id = "other_spells",
            disp = L["Other spells"],
            tooltip = L["Uncategorized spells. Contains seasonal spells and junk."]
        },
        {
            id = "only_highest_learned_ranks",
            disp = L["Only highest, learned spell ranks"],
        },
    };

    spell_browser_sort_options = {
        "Level",
        "|cFFFF8000"..L["Damage per second"],
        "|cFFFF8000"..L["Healing per second"],
        "|cFF00FFFF"..L["Damage per cost"],
        "|cFF00FFFF"..L["Healing per cost"],
    };

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

        libDD:UIDropDownMenu_SetText(pframe.filter, L["Includes"]);
        libDD:UIDropDownMenu_Initialize(pframe.filter, function()

            libDD:UIDropDownMenu_SetWidth(pframe.filter, 80);

            for _, v in pairs(spell_filter_listing) do
                local txt = v.disp;
                if v.id == "already_known" then
                    txt = "|cFF8a867d"..txt;
                elseif v.id == "available" then
                    txt = "|cFF00FF00"..txt;
                elseif v.id == "unavailable" then
                    txt = "|cFFFF0000"..txt;
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
    local per_sec_x_offset = 260;
    local per_cost_x_offset = 325;
    local acquisition_x_offset = 380;
    local dropdown_x_offset = 440;

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

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Per cost"]);
    f:SetPoint("TOPLEFT", per_cost_x_offset, pframe.y_offset);
    register_text_frame_color(f, "effect_per_cost");

    local f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Acquisition"]);
    f:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset);

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
        book:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset+2);
        local book_texture = book:CreateTexture(nil);
        book_texture:SetAllPoints(book);
        book:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(self.__id);
            GameTooltip:Show();
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
        cost:SetPoint("TOPLEFT", acquisition_x_offset, pframe.y_offset+1);

        -- spell option dropdown
        local spell_options =
            --CreateFrame("Button", "pframe_dropdown"..i, pframe, "UIDropDownMenuTemplate");
            libDD:Create_UIDropDownMenu("pframe_dropdown"..i, pframe);
        spell_options:SetPoint("TOPLEFT", dropdown_x_offset, pframe.y_offset+15);
        spell_options.init_func = function()

            libDD:UIDropDownMenu_Initialize(spell_options, function()

                libDD:UIDropDownMenu_SetWidth(spell_options, 15);

                libDD:UIDropDownMenu_AddButton({
                        text = L["Add to calculator list"],
                        func = function()

                            local id = spell_options.__spid;
                            if spells[id] and bit.band(spells[id].flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0 then

                                config.settings.spell_calc_list[spell_options.__spid] = 1;
                                update_calc_list(true);
                            end

                        end,
                    }
                );
                libDD:UIDropDownMenu_AddButton({
                        text = L["Add/remove to spell ignore list"],
                        func = function(self)
                            if config.settings.spells_ignore_list[spell_options.__spid] then
                                config.settings.spells_ignore_list[spell_options.__spid] = nil;
                            else
                                config.settings.spells_ignore_list[spell_options.__spid] = 1;
                            end
                            update_spell_catalogues(nil, nil, nil, true);
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

        hover_f.update = function()
            local focus = mouse_focus();
            hover_tex:SetShown(hover_f:IsShown() and focus ~= nil and
                (focus == hover_f or focus == tooltip_area_f or focus == book or focus == f));
        end;
        hover_f:SetScript("OnEnter", hover_f.update);
        hover_f:SetScript("OnLeave", hover_f.update);
        for _, frame in ipairs({tooltip_area_f, book, f}) do
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
            cost_str = cost,
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

local function create_sw_ui_tooltip_frame(pframe)

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    pframe.num_tooltip_toggled = 0;

    pframe.checkboxes = {};


    local tooltip_general_checks = {
        {
            id = "tooltip_shift_to_show",
            txt = L["Require SHIFT to show tooltips"]
        },
    };

    multi_row_checkbutton(tooltip_general_checks, pframe, 2);

    pframe.y_offset = pframe.y_offset - 25;

    local tsfs = {};

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Tooltip spell settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;

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
            txt = L["Evaluation modes"],
            tooltip = L["Some spells may have different evaluation modes. This shows the mode and how to dynamically switch between. Example: Switch between healing and damage component of Holy shock."];
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

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 5;

    local tifs = {};

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Tooltip item comparison settings"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        sw_activate_frame("calculator_frame");
    end);

    f:SetPoint("TOPRIGHT", -40, pframe.y_offset+2);
    f:SetHeight(20);
    f:SetWidth(200);
    f:SetText(L["Configure spell list"]);

    local help_icon = make_help_icon_tooltip(
        nil,
        pframe,
        L["Item comparison in tooltips"],
            " * ".."Hold ALT key to switch between evaluation modes".."\n"..
            " * ".."Evaluation is fully computed, not extrapolated from stat weights".."\n"..
            " * ".."Item tooltips are never parsed for its text, making this localization agnostic"
    );
    help_icon:SetPoint("TOPRIGHT", -20, pframe.y_offset);

    tifs[#tifs + 1] = f;

    pframe.y_offset = pframe.y_offset - 15;
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

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_stat_diff",
            txt = L["Always show stat changes"],
        },
        {
            id = "tooltip_item_smart",
            txt = L["Smarter tooltip"],
            tooltip = L["Adds/removes some sensible aspects of the tooltip. Examples: Never showing Attack for caster classes or for cloth items; Show wand spell for wands; etc"],
        },

    }, pframe, 2, nil)) do
        tifs[#tifs + 1] = v;
    end

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_leveling_skill_normalize",
            txt = L["Use skill as clvl*5 for weapon comparisons when not at maximum level"],
            tooltip = L["More intuitive weapon upgrade results when leveling since lower weapon skill type is not punished"],
        },
    }, pframe, 1, nil)) do
        tifs[#tifs + 1] = v;
    end

    pframe.quality_dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_tooltip_item_quality_threshold", pframe);
    pframe.quality_dd._type = "DropDownMenu";
    pframe.quality_dd:SetPoint("TOPLEFT", 225, pframe.y_offset+2);
    local qualities = {
        [0] = L["Poor"],
        [1] = L["Common"],
        [2] = L["Uncommon"],
        [3] = L["Rare"],
        [4] = L["Epic"],
        [5] = L["Legendary"],
    };
    pframe.quality_dd.init_func = function()
        libDD:UIDropDownMenu_Initialize(pframe.quality_dd, function()

            if config.settings.tooltip_item_quality_threshold < 0 or
                config.settings.tooltip_item_quality_threshold > 5 then
                config.settings.tooltip_item_quality_threshold = 2;
            end
            local idx = config.settings.tooltip_item_quality_threshold;
            libDD:UIDropDownMenu_SetText(
                pframe.quality_dd,
                ITEM_QUALITY_COLORS[idx].color:WrapTextInColorCode(L["Quality threshold"])
            );
            libDD:UIDropDownMenu_SetWidth(
                pframe.quality_dd,
                180
            );

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
    end;
    tifs[#tifs + 1] = pframe.quality_dd;

    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_weapon_skill",
            txt = L["Show skill levels for weapons"],
        },
    }, pframe, 2, nil)) do
        tifs[#tifs + 1] = v;
    end

    pframe.y_offset = pframe.y_offset - 25;


    for _, v in ipairs(multi_row_checkbutton({
        {
            id = "tooltip_item_apply_enchant",
            txt = L["Apply enchant changes"],
            tooltip = "Includes enchant changes for tooltip comparison",
        },
        {
            id = "tooltip_item_apply_gems",
            txt = L["Apply gem changes"],
            tooltip = "Includes gem changes for tooltip comparison",
        },
        {
            id = "tooltip_item_apply_set_bonuses",
            txt = L["Apply set bonus changes"],
            tooltip = "Includes set bonus changes for tooltip comparison",
        },
        {
            id = "tooltip_item_show_evaluation_modes",
            txt = L["Show evaluation mode switch"],
        },
        {
            id = "tooltip_item_ignore_unequippable",
            txt = L["Ignore unequippable by class"],
        },
        {
            id = "tooltip_item_ignore_cloth",
            txt = L["Ignore armor type: cloth"],
        },
        {
            id = "tooltip_item_ignore_leather",
            txt = L["Ignore armor type: leather"],
        },
        {
            id = "tooltip_item_ignore_mail",
            txt = L["Ignore armor type: mail"],
        },
        {
            id = "tooltip_item_ignore_plate",
            txt = L["Ignore armor type: plate"],
        },
    }, pframe, 2, nil)) do
        tifs[#tifs + 1] = v;
    end

    make_frame_scrollable(pframe);
end


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

    dropdown_frame.init_func = function()
        libDD:UIDropDownMenu_Initialize(dropdown_frame, function()
            local current_font_id = config.settings[font_config_key][1];
            local current_font_flags = config.settings[font_config_key][2];
            local using_external_font = not current_font_id:find("\\");
            local num_font_entries = #font_dropdowns;
            local num_pages = math.max(1, math.ceil(num_font_entries / page_size));
            local selected_index = nil;

            for idx, font_entry in ipairs(font_dropdowns) do
                if current_font_id == font_entry[1]
                    and current_font_flags == font_entry[2] then
                    selected_index = idx;
                    break;
                end
            end

            if selected_index then
                if not dropdown_frame.keep_page then
                    dropdown_frame.font_page = math.ceil(selected_index / page_size);
                end
                local selected_entry = font_dropdowns[selected_index];
                libDD:UIDropDownMenu_SetText(
                    dropdown_frame,
                    (selected_entry[1]:match("([^\\]+)$") or selected_entry[1]) .. "   0123456789  " .. selected_entry[2]
                );
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

            if using_external_font then

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
        end);

        libDD:UIDropDownMenu_SetWidth(dropdown_frame, 200);
        libDD:UIDropDownMenu_SetButtonWidth(dropdown_frame, 224);
        libDD:UIDropDownMenu_JustifyText(dropdown_frame, "LEFT");
    end;

    return dropdown_frame;
end;

local overlay_components_selection_display = {
    "overlay_display_normal",
    "overlay_display_direct_normal",
    "overlay_display_ot_normal",
    "overlay_display_hit_chance",

    "overlay_display_crit",
    "overlay_display_direct_crit",
    "overlay_display_ot_crit",
    "overlay_display_crit_chance",

    "overlay_display_expected",
    "overlay_display_effect_per_sec",

    "overlay_display_threat",
    "overlay_display_threat_per_sec",

    "overlay_display_avg_cost",
    "overlay_display_actual_cost",
    "overlay_display_effect_per_cost",
    "overlay_display_threat_per_cost",

    "overlay_display_miss_chance",
    "overlay_display_avoid_chance",
    "overlay_display_mitigation",

    "overlay_display_avg_cast",
    "overlay_display_actual_cast",

    "overlay_display_effect_until_oom",
    "overlay_display_time_until_oom",
    "overlay_display_casts_until_oom",

    "overlay_display_rank",
};


local function create_sw_ui_overlay_frame(pframe)

    local f, f_txt;

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

    pframe.y_offset = pframe.y_offset - 5;

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);

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

    pframe.y_offset = pframe.y_offset - 27;

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
            local option_key = label_frame_setting_subkey.."_selection";
            local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);

            dd._type = "DropDownMenu";
            dd._settings_id = option_key;
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            dd.init_func = function()
                libDD:UIDropDownMenu_Initialize(dd, function(self)

                    if not sc.overlay.label_handler[config.settings[self._settings_id]] then
                        config.settings[self._settings_id] = next(sc.overlay.label_handler);
                    end
                    local active_sel = sc.overlay.label_handler[config.settings[self._settings_id]];
                    sc.core.update_action_bar_needed = true;
                    sc.loadouts.force_update = true;

                    libDD:UIDropDownMenu_SetText(self, active_sel.desc);
                    self.Text:SetTextColor(effect_color(active_sel.color_tag));
                    register_text_frame_color(self.Text, active_sel.color_tag);

                    libDD:UIDropDownMenu_SetWidth(self, 120);

                    for _, sel_k in ipairs(overlay_components_selection_display) do
                        local sel_v = sc.overlay.label_handler[sel_k];
                        local r, g, b = effect_color(sel_v.color_tag);
                        local txt = CreateColor(r, g, b, 1.0):WrapTextInColorCode(sel_v.desc);
                        libDD:UIDropDownMenu_AddButton(
                            {
                                text = txt,
                                checked = sel_k == config.settings[self._settings_id],
                                func = function()
                                    config.settings[self._settings_id] = sel_k;
                                    sc.core.update_action_bar_needed = true;
                                    sc.loadouts.force_update = true;
                                    libDD:UIDropDownMenu_SetText(self, txt);
                                end,
                                tooltipTitle = "",
                                tooltipText = sel_v.tooltip,
                                tooltipOnButton = sel_v.tooltip ~= nil,
                            }
                        );
                    end
                end);
            end;
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
            libDD:UIDropDownMenu_Initialize(dd, function(self)

                sc.core.update_action_bar_needed = true;
                sc.loadouts.force_update = true;

                libDD:UIDropDownMenu_SetWidth(self, 120);

                for i, disp in ipairs(selections) do
                    if config.settings[self._settings_id] == i then
                        libDD:UIDropDownMenu_SetText(self, disp);
                    end
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
        end;
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

        dd._type = "DropDownMenu";
        dd._settings_id = option_key;
        dd:SetPoint("TOPLEFT", 165, pframe.y_offset+3);
        local selections =  {L["Top label"], L["Center label"], L["Bottom label"]};
        dd.init_func = function()
            libDD:UIDropDownMenu_Initialize(dd, function(self)

                sc.core.update_action_bar_needed = true;
                sc.loadouts.force_update = true;

                libDD:UIDropDownMenu_SetWidth(self, 120);

                for i, disp in ipairs(selections) do
                    if config.settings[self._settings_id] == i then
                        libDD:UIDropDownMenu_SetText(self, disp);
                    end
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
        end;
        ofs[#ofs + 1] = dd;
    end
    pframe.y_offset = pframe.y_offset - 26;

    local cfs = {}

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", -10, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 5;

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
            local option_key = label_frame_setting_subkey.."_selection";
            local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_"..option_key, pframe);

            dd._type = "DropDownMenu";
            dd._settings_id = option_key;
            dd:SetPoint("TOPLEFT", 300, pframe.y_offset+3);
            dd.init_func = function()
                libDD:UIDropDownMenu_Initialize(dd, function(self)

                    if not sc.overlay.label_handler[config.settings[self._settings_id]] then
                        config.settings[self._settings_id] = next(sc.overlay.label_handler);
                    end
                    local active_sel = sc.overlay.label_handler[config.settings[self._settings_id]];
                    sc.overlay.ccf_label_reconfig(k);
                    libDD:UIDropDownMenu_SetText(self, active_sel.desc);
                    self.Text:SetTextColor(effect_color(active_sel.color_tag));
                    register_text_frame_color(self.Text, active_sel.color_tag);

                    libDD:UIDropDownMenu_SetWidth(self, 120);

                    for _, sel_k in ipairs(overlay_components_selection_display) do
                        local sel_v = sc.overlay.label_handler[sel_k];
                        local r, g, b = effect_color(sel_v.color_tag);
                        local txt = CreateColor(r, g, b, 1.0):WrapTextInColorCode(sel_v.desc);
                        libDD:UIDropDownMenu_AddButton(
                            {
                                text = txt,
                                checked = sel_k == config.settings[self._settings_id],
                                func = function()
                                    config.settings[self._settings_id] = sel_k;
                                    sc.overlay.ccf_label_reconfig(k);
                                    libDD:UIDropDownMenu_SetText(self, txt);
                                end,
                                tooltipTitle = "",
                                tooltipText = sel_v.tooltip,
                                tooltipOnButton = sel_v.tooltip ~= nil,
                            }
                        );
                    end
                end);
            end;
            cfs[#cfs + 1] = dd;
        end
        pframe.y_offset = pframe.y_offset - 20;

    end

    make_frame_scrollable(pframe);
end

local default_talents_plan = {
    use_custom = false,
    custom_code = "_",
};
local default_buffs_plan = {
    use_custom = false,
    preserve_active = true,
    player_buffs = {},
    target_buffs = {},
};

local working_item_plan = {};
local working_stats = sc.loadouts.manual_effects_zero_diff();
local working_talents = sc.utils.deep_table_copy(default_talents_plan);
local working_buffs = sc.utils.deep_table_copy(default_buffs_plan);
local working_name = "";

local function item_planner_add_slot(item_link)

    local inv_loc = select(4, C_Item.GetItemInfoInstant(item_link));
    if not inv_loc then
        return false;
    end
    local item_slots = inv_type_to_slot_ids[inv_loc];
    if not item_slots then
        return false;
    end
    local viable_slots = __sc_frame.calculator_frame.items.slots;

    local dst_slot;
    if viable_slots[item_slots[1]] then -- index 1 should always exist
        dst_slot = item_slots[1];
    end
    if item_slots[2] and
        viable_slots[item_slots[2]] and
        working_item_plan[item_slots[1]] and
        not working_item_plan[item_slots[2]] then

        dst_slot = item_slots[2];
    end

    if dst_slot then


        working_item_plan[dst_slot] = working_item_plan[dst_slot] or {};
        if not write_item_info_from_link(working_item_plan[dst_slot], item_link) then
            working_item_plan[dst_slot] = nil;
            return false;
        end
        if inv_loc == "INVTYPE_2HWEAPON" then
            -- 2H knocks out offhand
            working_item_plan[slots.SecondaryHandSlot] = {};
        elseif
            inv_loc == "INVTYPE_WEAPONOFFHAND" or
            inv_loc == "INVTYPE_SHIELD"  or
            inv_loc == "INVTYPE_HOLDABLE"  or
            (inv_loc == "INVTYPE_WEAPON" and dst_slot == slots.SecondaryHandSlot) then

            -- offhand knocks out 2H

            local mh = working_item_plan[slots.MainHandSlot];
            if mh and mh.link and select(4, C_Item.GetItemInfoInstant(mh.link)) == "INVTYPE_2HWEAPON" then

                working_item_plan[slots.MainHandSlot] = {};
            end
        end

        return true;
    end
    return false
end

local function update_calculator_item_frame(frame, allow_empty)

    local link = frame.link;
    local quality, tex, ilvl;

    if link then
        _, _, quality, ilvl, _, _, _, _, _, tex = C_Item.GetItemInfo(link);
    end

    if tex and quality then
        frame.icon:SetTexture(tex);
        frame.ilvl_fstr:SetText(tostring(ilvl or 0));
        frame.icon:Show();
        frame.ilvl_fstr:Show();

        if quality and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality];
            --frame.bg:SetVertexColor(c.r, c.g, c.b, 1);
            frame.border:SetVertexColor(c.r, c.g, c.b, 1);
            frame.ilvl_fstr:SetTextColor(c.r, c.g, c.b, 1);
        else
            --frame.bg:SetVertexColor(1, 1, 1, 1);
            frame.border:Hide();
            frame.ilvl_fstr:SetTextColor(1, 1, 1, 1);
        end
    else
        frame.icon:Hide();
        frame.ilvl_fstr:Hide();
        if allow_empty then
            local c = ITEM_QUALITY_COLORS[0];
            frame.border:SetVertexColor(c.r, c.g, c.b, 1);
        else
            frame.border:Hide();
        end
        --frame.border:SetVertexColor(1, 1, 1, 1);
        --frame.bg:Show();
    end
end

local function update_calculator_character_items(slot)

    __sc_frame.calculator_frame.calculator_plan_changed = true;
    if not slot then
        for s, v in pairs(__sc_frame.calculator_frame.items.slots) do

            v.old.link = GetInventoryItemLink("player", s);
            update_calculator_item_frame(v.old);
            if not v.new.link then
                if v.old.link then
                    v.cancel:Show();
                    v.cancel:SetText("-");
                else
                    v.cancel:Hide();
                    v.cancel:SetText("x");
                end
            end
        end
    else
        local v = __sc_frame.calculator_frame.items.slots[slot];
        v.old.link = GetInventoryItemLink("player", slot);
        update_calculator_item_frame(v.old);
        if not v.new.link then
            if v.old.link then
                v.cancel:Show();
                v.cancel:SetText("-");
            else
                v.cancel:Hide();
                v.cancel:SetText("x");
            end
        end
    end
end

-- gems
local function update_item_plan_slot_gems(frames, slot_info)

    for _, v in pairs(frames.gems) do
        v.gem_item_id = 0;
        v:Hide();
    end
    frames.gems_match.id = 0;
    frames.gems_match:Hide();

    -- Update gem frames
    local item_sockets = sc.item_sockets[slot_info.id];
    if not item_sockets then
        return;
    end

    local socket_bonus_matched = true;

    for i = 1, 3 do
        local socket_color = item_sockets[i+1]; -- first index reserved for bonus id
        if not socket_color then
            break;
        end

        if socket_color == sc.gem_type_flags.red then
            frames.gems[i].bg:SetVertexColor(1.0, 0.0, 0.0);
        elseif socket_color == sc.gem_type_flags.yellow then
            frames.gems[i].bg:SetVertexColor(1.0, 1.0, 0.0);
        elseif socket_color == sc.gem_type_flags.blue then
            frames.gems[i].bg:SetVertexColor(0.0, 0.5, 1.0);
        else
            -- meta
            frames.gems[i].bg:SetVertexColor(0.6, 0.6, 0.6);
        end

        frames.gems[i]:Show();

        local gem_item_id = slot_info["gem"..i];
        if not gem_item_id then
            socket_bonus_matched = false;
            frames.gems[i].icon:Hide();
        else
            frames.gems[i].gem_item_id = gem_item_id;
            local tex = select(10, C_Item.GetItemInfo(gem_item_id));
            frames.gems[i].icon:SetTexture(tex);
            frames.gems[i].icon:Show();
        end

        local gem_id = gem_item_id and sc.gem_items[gem_item_id];
        local gem = gem_id and sc.gems[gem_id];

        local gem_type = (gem and gem[2]) or 0;
        if bit.band(socket_color, gem_type) == 0 then
            -- gem and socket color mismatch
            socket_bonus_matched = false;
        end
    end

    if socket_bonus_matched and item_sockets[1] then
        frames.gems_match.id = item_sockets[1];
        frames.gems_match:Show();
    else
        frames.gems_match:Hide();
    end
end

-- bridge between active item plan and corresponding UI elements
local function update_calculator_item_planner()

    local pframe = __sc_frame.calculator_frame;
    pframe.calculator_plan_changed = true;

    local frame_slots = pframe.items.slots;

    local anything = false;
    for slot, v in pairs(frame_slots)  do

        if working_item_plan[slot] then
            local slot_info = working_item_plan[slot];
            anything = true;
            v.new.link = slot_info.link;
            update_calculator_item_frame(v.new, true);

            v.arrow:Show();
            v.new:Show();
            v.cancel:Show();
            v.cancel:SetText("x");
            v.enchant:Show();

            update_item_plan_slot_gems(v, slot_info);

            if slot_info.enchant_id then
                v.enchant.enchant_id = slot_info.enchant_id;
                v.enchant.icon:Show();
            elseif v.new.link then
                v.enchant.enchant_id = 0;
                v.enchant.icon:Hide();
            else
                v.enchant:Hide();
            end

            v.old.icon:SetAlpha(0.2);
            if v.old.link then
                v.old.bg:Hide();
            else
                v.old.bg:Show();
            end
        else
            v.new.link = nil;
            v.arrow:Hide();
            v.new:Hide();

            if v.old.link then
                v.cancel:Show();
                v.cancel:SetText("-");
            else
                v.cancel:Hide();
            end

            for k, vv in pairs(v.gems) do
                vv:Hide();
            end
            v.enchant:Hide();

            v.old.icon:SetAlpha(1);
            v.old.bg:Show();
        end
    end
    if anything then
        pframe.items_tab.changed_indicator:Show();
        pframe.items.item_add_tip:Hide();
    else
        pframe.items_tab.changed_indicator:Hide();
        pframe.items.item_add_tip:Show();
    end
end

local function update_talents_frame()

    local pframe =  __sc_frame.calculator_frame;
    local talents_frame =  pframe.talents;

    talents_frame.custom_talents_chk:SetChecked(working_talents.use_custom);
    if working_talents.use_custom then
        pframe.talents_tab.changed_indicator:Show();
    else
        pframe.talents_tab.changed_indicator:Hide();
    end

    -- trigger editbox update
    talents_frame.talent_editbox:SetText("");
    talents_frame.talent_editbox:SetText(wowhead_talent_link(working_talents.custom_code));
end

local function update_buffs_frame()

    local pframe =  __sc_frame.calculator_frame;
    local buffs_frame =  pframe.buffs;

    sc.loadouts.force_update = true;

    local buffs_list_alpha;

    if not working_buffs.use_custom then
        pframe.buffs_tab.changed_indicator:Hide();
        buffs_list_alpha = 0.2;
    else
        pframe.buffs_tab.changed_indicator:Show();
        buffs_list_alpha = 1.0;
    end

    buffs_frame.custom_buffs_btn:SetChecked(working_buffs.use_custom);
    buffs_frame.preserve_buffs_btn:SetChecked(working_buffs.preserve_active);

    for _, view in ipairs(buffs_views) do

        local n = #view.filtered;

        for _, v in ipairs(buffs_frame[view.side].buffs) do
            v.checkbutton:Hide();
            v.checkbutton.__stacks_str:Hide();
            v.icon:Hide();
        end

        local buff_frame_idx = math.floor(buffs_frame[view.side].slider:GetValue());

        for _, v in ipairs(buffs_frame[view.side].buffs) do

            if buff_frame_idx > n then
                break;
            end
            local buff_info = view.buffs[view.filtered[buff_frame_idx]];
            v.checkbutton.buff_id = buff_info.id;

            if v.checkbutton.side == "lhs" then
                if working_buffs.player_buffs[buff_info.id] then
                    v.checkbutton:SetChecked(true);
                    v.checkbutton.__stacks_str:SetText(tostring(working_buffs.player_buffs[buff_info.id]));
                else
                    v.checkbutton:SetChecked(false);
                    v.checkbutton.__stacks_str:SetText("0");
                end
            else
                if working_buffs.target_buffs[buff_info.id] then
                    v.checkbutton:SetChecked(true);
                    v.checkbutton.__stacks_str:SetText(tostring(working_buffs.target_buffs[buff_info.id]));
                else
                    v.checkbutton:SetChecked(false);
                    v.checkbutton.__stacks_str:SetText("0");
                end
            end

            v.icon.tex:SetTexture((C_Spell.GetSpellTexture(buff_info.id)));

            local buff_name_max_len = 28;
            local name_appear =  buff_info.lname;
            getglobal(v.checkbutton:GetName() .. 'Text'):SetText(name_appear:sub(1, buff_name_max_len));
            local checkbutton_txt = getglobal(v.checkbutton:GetName() .. 'Text');

            local color = buff_categories_colors[buff_info.cat];
            checkbutton_txt:SetTextColor(color[1], color[2], color[3]);

            v.checkbutton:Show();
            v.checkbutton.__stacks_str:Show();
            v.icon:Show();

            buff_frame_idx = buff_frame_idx + 1;
        end
        buffs_frame[view.side].frame:SetAlpha(buffs_list_alpha);
    end
    for _, v in ipairs(buffs_frame.fadeable_checkboxes) do
        v:SetAlpha(buffs_list_alpha);
    end
end

local function effects_from_ui_stats_diff()

    local pframe = __sc_frame.calculator_frame;
    local frame = pframe.stats;
    local stats = frame.stat_fields;

    for k, v in pairs(stats) do
        working_stats[k] = 0;
    end

    -- Manual stats diff

    -- verify validity and run input expr 
    for _, v in pairs(stats) do

        local expr_str = v.editbox:GetText();

        local is_whitespace_expr = expr_str and string.match(expr_str, "%S") == nil;
        local is_valid_expr = string.match(expr_str, "[^-+0123456789. ()]") == nil

        local expr = nil;
        if is_valid_expr then
            expr = loadstring("return "..expr_str..";");
            if expr then
                v.editbox_val = expr();
                frame.is_valid = true;
            end
        end
        if is_whitespace_expr or not is_valid_expr or not expr then

            v.editbox_val = 0;
            if not is_whitespace_expr then
                frame.is_valid = false;
                return working_stats;
            end
        end
    end

    local anything = false;
    for k, v in pairs(stats) do
        local val = v.editbox_val;
        if val ~= 0 then
            anything = true;
        end
        working_stats[k] = val;
    end
    if anything then
        pframe.stats_tab.changed_indicator:Show();
    else
        pframe.stats_tab.changed_indicator:Hide();
    end

    frame.is_valid = true;

    return working_stats;
end

local function load_calculator_plan(plan)

    local pframe = __sc_frame.calculator_frame;

    clear_table(working_item_plan);
    for slot, v in pairs(plan.items) do
        -- do deep copy
        working_item_plan[slot] = {};
        for kk, vv in pairs(v) do
            working_item_plan[slot][kk] = vv;
        end
    end

    for stats_key, v in pairs(pframe.stats.stat_fields) do
        if plan.stats[stats_key] then
            v.editbox:SetText(plan.stats[stats_key]);
        else
            v.editbox:SetText("");
        end
    end

    for k, v in pairs(default_talents_plan) do
        if not plan.talents[k] then
            working_talents[k] = v;
        else
            working_talents[k] = plan.talents[k];
        end
    end
    for k, v in pairs(default_buffs_plan) do
        if type(v) == "table" then
            working_buffs[k] = {};
            if plan.buffs[k] then
                for kk, vv in pairs(plan.buffs[k]) do
                    working_buffs[k][kk] = vv;
                end
            end
        else
            if plan.buffs[k] == nil then
                working_buffs[k] = v;
            else
                working_buffs[k] = plan.buffs[k];
            end
        end
    end
    update_talents_frame();
    update_buffs_frame();
end

local function save_calculator_plan(plan_name)
    if plan_name == "" then
        return;
    end
    local pframe = __sc_frame.calculator_frame;

    local plan = {items = {}, stats = {}, talents = {}, buffs = {}};

    -- items
    for k, v in pairs(working_item_plan) do
        plan.items[k] = {};
        for kk, vv in pairs(v) do
            plan.items[k][kk] = vv;
        end
    end
    -- stats
    for k, v in pairs(pframe.stats.stat_fields) do
        local txt = v.editbox:GetText();
        if txt ~= "" then
            plan.stats[k] = txt;
        end
    end
    -- talents
    plan.talents.use_custom = working_talents.use_custom;
    plan.talents.custom_code = working_talents.custom_code;

    -- buffs
    plan.buffs.use_custom = working_buffs.use_custom;
    plan.buffs.preserve_active = working_buffs.preserve_active;
    plan.buffs.player_buffs = {};
    for k, v in pairs(working_buffs.player_buffs) do
        plan.buffs.player_buffs[k] = v;
    end
    plan.buffs.target_buffs = {};
    for k, v in pairs(working_buffs.target_buffs) do
        plan.buffs.target_buffs[k] = v;
    end

    __sc_p_char.calculator_saves[plan_name] = plan;

    pframe.plan_dd.init_func(plan_name);
end


local effects_diff_on_arrow_tooltip = {};
empty_effects(effects_diff_on_arrow_tooltip);
local new_item_buffer = {};
local old_item_buffer = {};

local item_planner_gem_enchant_dropdown;
local item_planner_gem_enchant_dropdown_entries = {};
local item_planner_gem_enchant_dropdown_filtered = {};
local item_planner_gem_enchant_dropdown_rows_count = 12;
local item_planner_enchant_icon_tex = "Interface\\Icons\\Trade_Engraving";
local item_planner_dropdown_check_tex = "Interface\\Buttons\\UI-CheckBox-Check";
local item_planner_dropdown_none_tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up";
local item_planner_dropdown_missing_tex = "Interface\\Icons\\INV_Misc_QuestionMark";

-- Set i'th colon-separated field in item links while preserving everything else.
local function item_link_set_field(link, field_idx, field_value)
    if type(link) ~= "string" or type(field_idx) ~= "number" or field_idx < 1 then
        return link;
    end

    local prefix, fields_str, suffix = link:match("^(.-item:)([^|]*)(.*)$");
    if not prefix then
        return link;
    end

    local fields = {};
    local start_idx = 1;
    while true do
        local split_idx = string.find(fields_str, ":", start_idx, true);
        if not split_idx then
            fields[#fields + 1] = string.sub(fields_str, start_idx);
            break;
        end
        fields[#fields + 1] = string.sub(fields_str, start_idx, split_idx - 1);
        start_idx = split_idx + 1;
    end

    while #fields < field_idx do
        fields[#fields + 1] = "";
    end
    fields[field_idx] = field_value or "";

    return prefix..table.concat(fields, ":")..suffix;
end

local function item_planner_gem_enchant_dropdown_refresh_rows()
    local frame = item_planner_gem_enchant_dropdown;

    local offset = math.floor(frame.slider:GetValue() or 0);
    for i, row in ipairs(frame.rows) do
        local entry = item_planner_gem_enchant_dropdown_filtered[offset + i];
        if entry then
            row.entry_id = entry.id;
            if entry.is_none then
                row.label:SetText(entry.lname);
            else
                row.label:SetText(entry.lname.." ("..entry.id..")");
            end
            row.label:SetTextColor(entry.r or 1, entry.g or 1, entry.b or 1, 1);
            row.icon:SetTexture(entry.tex or item_planner_dropdown_missing_tex);
            row.icon:Show();
            local is_active =
                (entry.is_none and frame.active_id == 0) or
                (not entry.is_none and frame.active_id == entry.id);
            if is_active then
                row.check:Show();
            else
                row.check:Hide();
            end
            row:Show();
        else
            row.entry_id = nil;
            row.icon:Hide();
            row.check:Hide();
            row:Hide();
        end
    end
end

local function item_planner_gem_enchant_dropdown_filter()
    local frame = item_planner_gem_enchant_dropdown;

    clear_table(item_planner_gem_enchant_dropdown_filtered);
    query = string.lower(frame.search:GetText() or "");

    if query == "" then
        for i, v in ipairs(item_planner_gem_enchant_dropdown_entries) do
            item_planner_gem_enchant_dropdown_filtered[i] = v;
        end
    else
        local n = 0;
        if item_planner_gem_enchant_dropdown_entries[1] and item_planner_gem_enchant_dropdown_entries[1].is_none then
            n = 1;
            item_planner_gem_enchant_dropdown_filtered[1] = item_planner_gem_enchant_dropdown_entries[1];
        end
        for i = 2, #item_planner_gem_enchant_dropdown_entries do
            local v = item_planner_gem_enchant_dropdown_entries[i];
            if string.find(v.search_lname, query, 1, true) or
                string.find(v.search_id, query, 1, true) then
                n = n + 1;
                item_planner_gem_enchant_dropdown_filtered[n] = v;
            end
        end
    end

    local max_offset = math.max(0, #item_planner_gem_enchant_dropdown_filtered - item_planner_gem_enchant_dropdown_rows_count);
    frame.slider:SetMinMaxValues(0, max_offset);
    frame.slider:SetValue(math.min(frame.slider:GetValue() or 0, max_offset));
    item_planner_gem_enchant_dropdown_refresh_rows();
end

local function item_planner_gem_enchant_dropdown_build_entries(mode, active_id)

    clear_table(item_planner_gem_enchant_dropdown_entries);

    local frame = item_planner_gem_enchant_dropdown;
    frame.active_id = tonumber(active_id) or 0;
    if frame.active_id < 0 then
        frame.active_id = 0;
    end

    local n = 0;
    local retry_needed = false;
    if mode == "gem" then
        for item_id in pairs(sc.gem_items) do
            local lname, _, quality, _, _, _, _, _, _, tex = C_Item.GetItemInfo(item_id);
            if not lname then
                retry_needed = true;
            end
            lname = tostring(lname or item_id);
            local color = ITEM_QUALITY_COLORS[quality or 0] or ITEM_QUALITY_COLORS[1];
            n = n + 1;
            item_planner_gem_enchant_dropdown_entries[n] = {
                id = item_id,
                lname = lname,
                search_lname = string.lower(lname),
                search_id = tostring(item_id),
                tex = tex,
                r = color.r,
                g = color.g,
                b = color.b,
            };
        end
    else
        for enchant_id, lname in pairs(sc.enchant_id_to_lname) do
            -- filter out some enchants intended as ilvl based suffix scaling effect
            if sc.enchants[enchant_id] and
                sc.enchant_effects[sc.enchants[enchant_id][1]] and
                sc.enchant_effects[sc.enchants[enchant_id][1]][1][sc.aura_idx_value] ~= 0 then

                n = n + 1;
                item_planner_gem_enchant_dropdown_entries[n] = {
                    id = enchant_id,
                    lname = lname,
                    search_lname = string.lower(lname),
                    search_id = tostring(enchant_id),
                    tex = item_planner_enchant_icon_tex,
                    r = 1,
                    g = 1,
                    b = 1,
                };
            end
        end
    end

    table.sort(item_planner_gem_enchant_dropdown_entries, function(a, b)
        if a.search_lname == b.search_lname then
            return a.id < b.id;
        end
        return a.search_lname < b.search_lname;
    end);

    table.insert(item_planner_gem_enchant_dropdown_entries, 1, {
        id = 0,
        lname = "None",
        search_lname = "none",
        search_id = "0",
        tex = item_planner_dropdown_none_tex,
        r = 1, g = 1, b = 1,
        is_none = true,
    });
    return retry_needed;
end

local function item_planner_gem_enchant_dropdown_create(parent)

    local click_catcher = CreateFrame("Frame", nil, UIParent);
    click_catcher:SetAllPoints(UIParent);
    click_catcher:EnableMouse(true);
    click_catcher:SetFrameStrata("DIALOG");
    click_catcher:Hide();

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate");
    frame:SetSize(262, 250);
    frame:SetFrameStrata("DIALOG");
    frame:SetClampedToScreen(true);
    frame:EnableMouse(true);
    frame:SetScript("OnMouseDown", function()
        -- Consume clicks inside dropdown so only outside clicks close it.
    end);
    frame:Hide();
    frame.click_catcher = click_catcher;
    click_catcher:SetFrameLevel(frame:GetFrameLevel() - 1);
    click_catcher:SetScript("OnMouseDown", function()
        frame:Hide();
    end);
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    frame:SetBackdropColor(0, 0, 0, 0.95);
    frame:SetBackdropBorderColor(1, 0.82, 0, 1);
    frame:SetScript("OnHide", function(self)
        self.click_catcher:Hide();
        self.search:ClearFocus();
        GameTooltip:Hide();
    end);
    frame:SetScript("OnShow", function(self)
        self.click_catcher:Show();
    end);

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    title:SetPoint("TOPLEFT", 8, -7);
    title:SetText("Select");
    frame.title = title;

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2);
    close:SetScript("OnClick", function()
        frame:Hide();
    end);

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");
    search:SetPoint("TOPLEFT", 8, -24);
    search:SetSize(160, 15);
    search:SetAutoFocus(false);
    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or "";
        if txt == "" then
            frame.search_empty_label:Show();
        else
            frame.search_empty_label:Hide();
        end
        item_planner_gem_enchant_dropdown_filter();
    end);
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus();
        frame:Hide();
    end);
    frame.search = search;

    local search_empty = frame:CreateFontString(nil, "OVERLAY", font);
    search_empty:SetPoint("LEFT", search, 5, 0);
    search_empty:SetText(L["Search name or ID"]);
    frame.search_empty_label = search_empty;

    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate");
    list:SetPoint("TOPLEFT", 8, -45);
    list:SetSize(246, 197);
    list:EnableMouseWheel(true);
    list:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    });
    list:SetBackdropColor(0, 0, 0, 0.6);
    list:SetBackdropBorderColor(0.4, 0.4, 0.4, 1);
    frame.list = list;

    local slider = CreateFrame("Slider", "__sc_frame_item_planner_dropdown_slider", list, "UIPanelScrollBarTrimTemplate");
    -- template handler scrolls the parent as a ScrollFrame, list is a plain Frame
    slider:SetScript("OnValueChanged", nil);
    slider:SetOrientation("VERTICAL");
    slider:SetPoint("RIGHT", list, "RIGHT", 0, 0);
    slider:SetHeight(list:GetHeight() - 34);
    slider.scrollStep = 1;
    slider:SetValueStep(1);
    slider:SetMinMaxValues(0, 0);
    slider:SetValue(0);
    slider:SetObeyStepOnDrag(true);
    slider:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor(value + 0.5);
        if snapped ~= value then
            self:SetValue(snapped);
            return;
        end
        item_planner_gem_enchant_dropdown_refresh_rows();
    end);
    local slider_bg = slider:CreateTexture(nil, "BACKGROUND");
    slider_bg:SetAllPoints(slider);
    slider_bg:SetColorTexture(0, 0, 0, 0.5);
    frame.slider = slider;

    list:SetScript("OnMouseWheel", function(self, delta)
        local min_val, max_val = frame.slider:GetMinMaxValues();
        local val = frame.slider:GetValue() - delta;
        val = math.max(min_val, math.min(max_val, val));
        if val ~= frame.slider:GetValue() then
            frame.slider:SetValue(val);
        end
    end);

    frame.rows = {};
    for i = 1, item_planner_gem_enchant_dropdown_rows_count do
        local row = CreateFrame("Button", nil, list);
        row:SetSize(214, 15);
        row:SetPoint("TOPLEFT", list, 3, -2 - (i - 1) * 15);
        row:EnableMouse(true);

        local bg = row:CreateTexture(nil, "BACKGROUND");
        bg:SetAllPoints(row);
        bg:SetColorTexture(1, 1, 1, 0.02);
        row.bg = bg;

        local hl = row:CreateTexture(nil, "HIGHLIGHT");
        hl:SetAllPoints(row);
        hl:SetColorTexture(1, 1, 1, 0.18);

        local icon = row:CreateTexture(nil, "ARTWORK");
        icon:SetSize(13, 13);
        icon:SetPoint("LEFT", row, "LEFT", 1, 0);
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        row.icon = icon;

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        label:SetPoint("LEFT", icon, "RIGHT", 3, 0);
        label:SetWidth(182);
        label:SetJustifyH("LEFT");
        label:SetWordWrap(false);
        row.label = label;

        local check = row:CreateTexture(nil, "OVERLAY");
        check:SetTexture(item_planner_dropdown_check_tex);
        check:SetSize(12, 12);
        check:SetPoint("RIGHT", row, "RIGHT", -2, 0);
        check:SetVertexColor(0.2, 1.0, 0.2, 1.0);
        check:Hide();
        row.check = check;

        row:SetScript("OnClick", function(self)
            if self.entry_id == nil then
                return;
            end

            local selected_id = tonumber(self.entry_id) or 0;
            local slot_id = frame.slot_id;
            local changed = false;

            if slot_id and working_item_plan[slot_id] then
                local slot_info = working_item_plan[slot_id];
                if frame.mode == "gem" and frame.gem_index then
                    local gem_key = "gem"..frame.gem_index;
                    local old_id = tonumber(slot_info[gem_key]) or 0;
                    if old_id ~= selected_id then
                        if selected_id == 0 then
                            slot_info[gem_key] = nil;
                        else
                            slot_info[gem_key] = selected_id;
                        end
                        if slot_info.link then
                            slot_info.link = item_link_set_field(
                                slot_info.link,
                                2 + frame.gem_index,
                                selected_id == 0 and "" or tostring(selected_id)
                            );
                        end
                        changed = true;
                    end
                elseif frame.mode == "enchant" then
                    local old_id = tonumber(slot_info.enchant_id) or 0;
                    if old_id ~= selected_id then
                        if selected_id == 0 then
                            slot_info.enchant_id = nil;
                        else
                            slot_info.enchant_id = selected_id;
                        end
                        if slot_info.link then
                            slot_info.link = item_link_set_field(
                                slot_info.link,
                                2,
                                selected_id == 0 and "" or tostring(selected_id)
                            );
                        end
                        changed = true;
                    end
                end
            end

            if changed then
                update_calculator_item_planner();
            end
            frame:Hide();
        end);
        row:SetScript("OnEnter", function(self)
            if not self.entry_id then
                return;
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            if frame.mode == "gem" then
                GameTooltip:SetItemByID(self.entry_id);
            else
                local title = sc.enchant_id_to_lname[self.entry_id];
                if title then
                    title = title.." ("..self.entry_id..")";
                else
                    title = tostring(self.entry_id);
                end
                GameTooltip:SetText(title);
                local spell_ids = sc.enchants[self.entry_id];
                if spell_ids then
                    for _, spell_id in ipairs(spell_ids) do
                        if spell_id > 0 then
                            local spell_name = C_Spell.GetSpellName(spell_id);
                            if spell_name then
                                GameTooltip:AddLine(spell_name.." ("..spell_id..")");
                            else
                                GameTooltip:AddLine(tostring(spell_id));
                            end
                        end
                    end
                end
            end
            GameTooltip:Show();
        end);
        row:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        frame.rows[i] = row;
    end

    item_planner_gem_enchant_dropdown = frame;
    return frame;
end


local failed_retries = 0;
local max_retries = 5;
-- C_Timer cannot call with arguments
local gem_enchant_dd_mode, gem_enchant_dd_active_id;
local function item_planner_gem_enchant_dropdown_refresh()

    local mode = gem_enchant_dd_mode;
    local active_id = gem_enchant_dd_active_id;

    local retry_needed = item_planner_gem_enchant_dropdown_build_entries(mode, active_id);
    item_planner_gem_enchant_dropdown_filter();
    if retry_needed and failed_retries < max_retries then
        failed_retries = failed_retries + 1;
        C_Timer.After(0.5, item_planner_gem_enchant_dropdown_refresh);
        item_planner_gem_enchant_dropdown.title:SetText(L["Loading gems ..."]);
    else
        failed_retries = 0;
        if mode == "gem" then
            item_planner_gem_enchant_dropdown.title:SetText(L["Select gem"]);
        else
            item_planner_gem_enchant_dropdown.title:SetText(L["Select enchant"]);
        end
    end

end

local function item_planner_gem_enchant_dropdown_open(anchor, mode, active_id, slot_id, gem_index)

    local frame = item_planner_gem_enchant_dropdown;
    frame.mode = mode;
    frame.slot_id = slot_id;
    frame.gem_index = gem_index;
    frame:ClearAllPoints();
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2);

    frame.search:SetText("");
    frame.search_empty_label:Show();
    frame.slider:SetValue(0);

    gem_enchant_dd_mode = mode;
    gem_enchant_dd_active_id = active_id;
    item_planner_gem_enchant_dropdown_refresh();

    frame:Show();
end

local function create_calculator_items_subframe(pframe)

    item_planner_gem_enchant_dropdown_create(pframe.items);

    local f, f_txt;

    -- Item upgrade planner tabbed subframe
    local slots_order = {
        "HeadSlot",
        "NeckSlot",
        "ShoulderSlot",
        "BackSlot",
        "ChestSlot",
        "ShirtSlot",
        "TabardSlot",
        "WristSlot",
        "HandsSlot",
        "WaistSlot",
        "LegsSlot",
        "FeetSlot",
        "Finger0Slot",
        "Finger1Slot",
        "Trinket0Slot",
        "Trinket1Slot",
        "MainHandSlot",
        "SecondaryHandSlot",
        "RangedSlot",
        "AmmoSlot",
    };

    local slot_padding = 2;
    local slot_size = 28;
    local slots_realign_to = {
        HeadSlot = {
            align_from = "LEFT", panchor = "TOPLEFT",
            px_offset = 10, py_offset = -30,
            x_between = 0, y_between = -(slot_size + slot_padding)
        },
        HandsSlot = {
            align_from = "RIGHT", panchor = "TOPRIGHT",
            px_offset = -130, py_offset = -30,
            x_between = 0, y_between = -(slot_size + slot_padding)
        },
        MainHandSlot = {
            align_from = "BOTTOM", panchor = "BOTTOMLEFT",
            px_offset = 130, py_offset = 45,
            x_between = slot_size + slot_padding, y_between = 0
        },
    };

    local items_max_y_offset = 0;

    pframe.items.slots = {};
    pframe.items:HookScript("OnShow", function()
        update_calculator_character_items();
    end);
    pframe.items:HookScript("OnHide", function()
        if item_planner_gem_enchant_dropdown then
            item_planner_gem_enchant_dropdown:Hide();
        end
    end);

    local arrow_tex_path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up";
    local x_offset, y_offset, pos;
    for _, slot in ipairs(slots_order) do

        if slots_realign_to[slot] then
            pos = slots_realign_to[slot];
            x_offset = 0;
            y_offset = 0;
        end

        -- SOURCE ITEM SLOT FRAME
        local slotf = CreateFrame("Frame", nil, pframe.items);

        slotf:SetSize(slot_size, slot_size);
        slotf:SetPoint(
            pos.align_from,
            pframe.items,
            pos.panchor,
            pos.px_offset + x_offset,
            pos.py_offset + y_offset
        );

        x_offset = x_offset + pos.x_between;
        y_offset = y_offset + pos.y_between;
        items_max_y_offset = math.min(items_max_y_offset, y_offset+pos.py_offset);

        local slot_id, empty_tex = GetInventorySlotInfo(slot);

        slotf.slot = slot_id;

        slotf.bg = slotf:CreateTexture(nil, "BACKGROUND");
        slotf.bg:SetAllPoints(slotf);
        slotf.bg:SetTexture(empty_tex);
        slotf.bg:SetVertexColor(0.6, 0.6, 0.6, 1);

        slotf.icon = slotf:CreateTexture(nil, "ARTWORK");
        slotf.icon:SetAllPoints(slotf);
        slotf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
        --slotf.icon:SetAlpha(0.4);

        slotf.ilvl_fstr = slotf:CreateFontString(nil, "OVERLAY");
        slotf.ilvl_fstr:SetFontObject(NumberFontNormalSmall)
        local fp, _, flags = slotf.ilvl_fstr:GetFont();
        slotf.ilvl_fstr:SetFont(fp, 10, "THICKOUTLINE");
        slotf.ilvl_fstr:SetPoint("TOP", 0, -1);

        slotf.border = slotf:CreateTexture(nil, "OVERLAY");
        slotf.border:SetTexture("Interface\\Common\\WhiteIconFrame");
        slotf.border:SetBlendMode("BLEND");
        slotf.border:SetSize(slot_size+2, slot_size+2);
        slotf.border:SetPoint("TOPLEFT", -1, 1);

        slotf:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetHyperlink(self.link);
                GameTooltip:Show();
            end
        end);
        slotf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        slotf:SetScript("OnMouseDown", function(self, btn)
            if not self.link or not IsModifiedClick("CHATLINK") or btn ~= "LeftButton" then
                return;
            end
            HandleModifiedItemClick(self.link);
        end);

        f = slotf:CreateTexture(nil, "OVERLAY");
        f:SetTexture(arrow_tex_path);
        f:SetTexCoord(0.3, 0.7, 0.3, 0.7);
        f:SetSize(8, 8);
        f.slot = slot_id;
        if pos.align_from == "LEFT" then
            slotf.expand_point = "RIGHT";
            slotf.expand_y_dir = 0;
            slotf.expand_x_dir = 1;
        elseif pos.align_from == "RIGHT" then
            slotf.expand_point = "LEFT";
            slotf.expand_y_dir = 0;
            slotf.expand_x_dir = -1;
            f:SetRotation(3.14592);
        else
            slotf.expand_point = "TOP";
            slotf.expand_y_dir = 1;
            slotf.expand_x_dir = 0;
            f:SetRotation(3.14592/2);
        end
        local arrowf = f;

        f:SetPoint(slotf.expand_point, 13*slotf.expand_x_dir, 12*slotf.expand_y_dir);
        f:SetScript("OnEnter", function(self)

            if not self.slot or not working_item_plan[self.slot] then
                return;
            end

            local loadout, effects, effects_finalized, update_id = update_loadout_and_effects();

            cpy_effects(effects_diff_on_arrow_tooltip, effects);

            new_item_buffer[self.slot] = {};
            write_item_info_from_link(new_item_buffer[self.slot], working_item_plan[self.slot].link);

            if loadout.item_links[self.slot] then
                old_item_buffer[self.slot] = {};
                write_item_info_from_link(old_item_buffer[self.slot], loadout.item_links[self.slot]);
            end
            apply_items_cmp(
                loadout, effects_diff_on_arrow_tooltip, new_item_buffer, old_item_buffer,
                true, true, true
            );
            new_item_buffer[self.slot] = nil;
            old_item_buffer[self.slot] = nil;

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

            if config.settings.general_calc_stats_raw_dump then
                GameTooltip:SetText(L["Changes"]);
            else
                GameTooltip:SetText(L["Changes (simplified)"]);
            end

            effects_finalize_forced(loadout, effects_diff_on_arrow_tooltip);
            local stat_diffs = stats_diff_format(loadout, effects_finalized, effects_diff_on_arrow_tooltip);
            if stat_diffs ~= "" then
                stat_diffs = stat_diffs_included_effects_str(true, true, true)..stat_diffs;
            end

            GameTooltip:AddLine(stat_diffs);
            GameTooltip:Show();
        end);
        f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);


        -- DESTINATION ITEM SLOT FRAME
        local new_itemf = CreateFrame("Frame", nil, slotf);

        new_itemf:SetSize(slot_size, slot_size);
        new_itemf:SetPoint(
            slotf.expand_point,
            slotf,
            45*slotf.expand_x_dir,
            45*slotf.expand_y_dir
        );

        new_itemf.bg = new_itemf:CreateTexture(nil, "BACKGROUND");
        new_itemf.bg:SetAllPoints(new_itemf);
        new_itemf.bg:SetTexture(empty_tex);
        new_itemf.bg:SetVertexColor(0.6, 0.6, 0.6, 1);

        new_itemf.icon = new_itemf:CreateTexture(nil, "ARTWORK");
        new_itemf.icon:SetAllPoints(new_itemf);
        new_itemf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);

        new_itemf.ilvl_fstr = new_itemf:CreateFontString(nil, "OVERLAY");
        new_itemf.ilvl_fstr:SetFontObject(NumberFontNormalSmall)
        local fp, _, flags = new_itemf.ilvl_fstr:GetFont();
        new_itemf.ilvl_fstr:SetFont(fp, 10, "THICKOUTLINE");
        new_itemf.ilvl_fstr:SetPoint("TOP", 0, -1);

        new_itemf.border = new_itemf:CreateTexture(nil, "OVERLAY");
        new_itemf.border:SetAllPoints(new_itemf);
        new_itemf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

        new_itemf.border = new_itemf:CreateTexture(nil, "OVERLAY");
        new_itemf.border:SetTexture("Interface\\Common\\WhiteIconFrame");
        new_itemf.border:SetBlendMode("BLEND");
        new_itemf.border:SetSize(
            slot_size+4 + slot_size*math.abs(slotf.expand_x_dir),
            slot_size+4 + slot_size*math.abs(slotf.expand_y_dir)
        );
        new_itemf.border:SetPoint(
            pos.align_from,
            -3*slotf.expand_x_dir,
            -3*slotf.expand_y_dir
        );

        new_itemf:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetHyperlink(self.link);
                GameTooltip:Show();
            end
        end);
        new_itemf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local plus_tex = "Interface\\Buttons\\UI-PlusButton-Up";
        local gem_icon_size = 10;
        -- Gem slot frames
        local gemsf = {};
        for i = 1, 3 do

            local gemf = CreateFrame("Frame", nil, new_itemf);

            gemf:SetSize(gem_icon_size, gem_icon_size);
            gemf:SetPoint(
                slotf.expand_point,
                12*slotf.expand_x_dir - 18*slotf.expand_y_dir + i*9*slotf.expand_y_dir,
                12*slotf.expand_y_dir + 18*math.abs(slotf.expand_x_dir) - i*9*math.abs(slotf.expand_x_dir)
            );

            gemf.bg = gemf:CreateTexture(nil, "BACKGROUND");
            gemf.bg:SetAllPoints(gemf);
            gemf.bg:SetTexture(plus_tex);
            --gemf.bg:SetAlpha(0.45);
            gemf.bg:SetDesaturated(true);

            gemf.icon = gemf:CreateTexture(nil, "ARTWORK");
            gemf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
            gemf.icon:SetSize(gem_icon_size-2, gem_icon_size-2);
            --gemf.icon:SetAllPoints(gemf);
            gemf.icon:SetPoint("TOPLEFT", 1, -1);

            gemf.border = gemf:CreateTexture(nil, "OVERLAY");
            gemf.border:SetAllPoints(gemf);
            gemf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

            gemf.gem_item_id = 0;
            gemf:SetScript("OnEnter", function(self)
                if self.gem_item_id ~= 0 then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                    GameTooltip:SetItemByID(self.gem_item_id);
                    GameTooltip:AddLine(" ");
                    GameTooltip:AddLine(L["Click to change gem"], 1.0, 0.2, 0.2);
                    GameTooltip:Show();
                else
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                    GameTooltip:SetText(L["Click to add gem"], 1.0, 0.2, 0.2);
                    GameTooltip:Show();
                end
            end);
            gemf:SetScript("OnLeave", function(self)
                GameTooltip:Hide();
            end);
            gemf:SetScript("OnMouseDown", function(self, btn)
                if btn ~= "LeftButton" then
                    return;
                end
                if not working_item_plan[self.slot_id] or not working_item_plan[self.slot_id].link then
                    return;
                end
                item_planner_gem_enchant_dropdown_open(self, "gem", self.gem_item_id, self.slot_id, self.gem_index);
            end);

            gemf.slot_id = slot_id;
            gemf.gem_index = i;
            gemsf[i] = gemf;
        end

        local f = new_itemf:CreateTexture(nil, "OVERLAY");
        f:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
        f:SetVertexColor(0, 1, 0, 1);
        f:SetSize(10, 10);
        f:SetPoint(
            slotf.expand_point,
            new_itemf,
            25*slotf.expand_x_dir + 10*slotf.expand_y_dir,
            -10*math.abs(slotf.expand_x_dir) + 25*slotf.expand_y_dir
        );
        f.id = 0;

        f:SetScript("OnEnter", function(self)
            if self.id ~= 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetText(L["Socket match bonus"].." ("..self.id..")");
                GameTooltip:Show();
            end
        end);
        f:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);

        local gem_match_indicator = f;

        local enchantf = CreateFrame("Frame", nil, new_itemf);
        enchantf:SetSize(gem_icon_size, gem_icon_size);

        enchantf:SetPoint(
            slotf.expand_point,
            25*slotf.expand_x_dir - 9*slotf.expand_y_dir,
            9*math.abs(slotf.expand_x_dir) + 25*slotf.expand_y_dir
        );

        enchantf.bg = enchantf:CreateTexture(nil, "BACKGROUND");
        enchantf.bg:SetAllPoints(enchantf);
        enchantf.bg:SetTexture(plus_tex);
        enchantf.bg:SetDesaturated(true);

        enchantf.icon = enchantf:CreateTexture(nil, "ARTWORK");
        enchantf.icon:SetTexture("Interface\\Icons\\Trade_Engraving");
        enchantf.icon:SetSize(gem_icon_size -2, gem_icon_size - 2);
        enchantf.icon:SetPoint("TOPLEFT", 1, -1);
        enchantf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);

        enchantf.border = enchantf:CreateTexture(nil, "OVERLAY");
        enchantf.border:SetAllPoints(enchantf);
        enchantf.border:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Border");

        enchantf.enchant_id = 0;
        enchantf:SetScript("OnEnter", function(self)
            if self.enchant_id ~= 0  then

                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                local title = sc.enchant_id_to_lname[self.enchant_id];
                if title then
                    title = title.." ("..self.enchant_id..")";
                else
                    title = tostring(self.enchant_id);
                end

                GameTooltip:SetText(title);


                local spell_ids = sc.enchants[self.enchant_id];
                if spell_ids then
                    for _, spell_id in ipairs(spell_ids) do
                        if spell_id > 0 then
                            GameTooltip:AddLine(C_Spell.GetSpellName(spell_id).." ("..spell_id..")");
                        end
                    end
                end
                GameTooltip:AddLine(" ");
                GameTooltip:AddLine(L["Click to change enchant"], 1.0, 0.2, 0.2);
                GameTooltip:Show();

            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                GameTooltip:SetText(L["Click to add enchant"], 1.0, 0.2, 0.2);
                GameTooltip:Show();
            end
        end);
        enchantf:SetScript("OnLeave", function(self)
            GameTooltip:Hide();
        end);
        enchantf:SetScript("OnMouseDown", function(self, btn)
            if btn ~= "LeftButton" then
                return;
            end
            if not working_item_plan[self.slot_id] or not working_item_plan[self.slot_id].link then
                return;
            end
            item_planner_gem_enchant_dropdown_open(self, "enchant", self.enchant_id, self.slot_id, nil);
        end);
        enchantf.slot_id = slot_id;

        local cancelf = CreateFrame("Button", nil, slotf, "UIPanelButtonTemplate");
        cancelf:SetScript("OnClick", function(self)
            if working_item_plan[self.slot_id] then
                working_item_plan[self.slot_id] = nil;
            else
                -- add empty as to unequip old item with no replacement
                working_item_plan[self.slot_id] = {};
            end
            update_calculator_item_planner();
        end);

        local cancel_offset = -17;
        cancelf:SetPoint(pos.align_from, cancel_offset * slotf.expand_x_dir, cancel_offset * slotf.expand_y_dir);
        cancelf:SetSize(17, 17);
        cancelf:SetText("x");
        local fontstr = cancelf:GetFontString();
        if fontstr then
            fontstr:ClearAllPoints();
            fontstr:SetPoint("CENTER", cancelf, "CENTER");
            fontstr:SetIgnoreParentAlpha(true);
            fontstr:SetMouseClickEnabled(false);
        end
        cancelf:SetFrameLevel(cancelf:GetFrameLevel() + 1);

        cancelf.slot_id = slot_id;

        pframe.items.slots[slot_id] = {
            old = slotf,
            arrow = arrowf,
            new = new_itemf,
            gems = gemsf,
            gems_match = gem_match_indicator,
            enchant = enchantf,
            cancel = cancelf,

        };
    end

    local handle_player_links = function(link)
        if __sc_frame:IsShown() and __sc_frame.calculator_frame:IsShown() then
            item_planner_add_slot(link);
            update_calculator_item_planner();
            __sc_frame.calculator_frame.items_tab:Click();
        end;
    end

    --

    -- ChatEdit_InsertLink only works on era client
    -- HandleModifiedItemClick seems to work on all clients,
    -- but other addon's shift clickables might only call ChatEdit_InsertLink
    --
    -- Workaround to use both without duplicate links
    local handle_modified_item_click_link;
    local chatedit_insertlink_link;

    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and not is_secret(link) then
            if link ~= handle_modified_item_click_link then

                handle_player_links(link);
                chatedit_insertlink_link = link;
            else
                handle_modified_item_click_link = nil;
            end
        end
    end);

    hooksecurefunc("HandleModifiedItemClick", function(link)
        if link and not is_secret(link) then
            if link ~= chatedit_insertlink_link then

                handle_player_links(link);
                handle_modified_item_click_link = link;
            else
                chatedit_insertlink_link = nil;
            end
        end
    end);

    f_txt = pframe.items:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 100, -150);
    f_txt:SetText(L["SHIFT click on any item\n to add to plan!"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    pframe.items.item_add_tip = f_txt;


    local use_target_equipment;

    local same_target = function(self)
        local guid = UnitGUID("target");
        return not is_secret(guid) and guid == self.target_guid;
    end

    local target_item_data_received = function(_, success)
        local self = pframe.items.targets_item_btn;
        if success and same_target(self) then
            use_target_equipment(self);
        end
    end

    local target_items_retry = function()
        local self = pframe.items.targets_item_btn;
        self.retry_scheduled = false;
        if self.num_retries < 5 and same_target(self) then
            self.num_retries = self.num_retries + 1;
            use_target_equipment(self);
        end
    end

    use_target_equipment = function(self)
        local found_anything = false;
        local link_missing_when_cached = false;

        clear_table(working_item_plan);
        for slot in pairs(pframe.items.slots) do
            local link = GetInventoryItemLink("target", slot);
            local id = GetInventoryItemID("target", slot);
            if not link and id and request_item_data(id, target_item_data_received) then
                -- no load event will follow, the link may still come with the inspect data
                link_missing_when_cached = true;
            end
            if link then
                found_anything = true;

                working_item_plan[slot] = working_item_plan[slot] or {};
                if not write_item_info_from_link(working_item_plan[slot], link) then
                    working_item_plan[slot] = nil;
                end
            elseif GetInventoryItemLink("player", slot) then
                -- also equip empty slots
                working_item_plan[slot] = {};
            end
        end

        if link_missing_when_cached and not self.retry_scheduled then
            self.retry_scheduled = true;
            C_Timer.After(0.5, target_items_retry);
        end

        if found_anything then
            update_calculator_item_planner();
        end
    end

    pframe.items.y_offset = pframe.items.y_offset - 18;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 5, pframe.y_offset+2);
    f_txt:SetText(L["Active profile: "]);
    pframe.profile_name_label = f_txt;


    local rhs_y_offset = pframe.y_offset - 10;

    f_txt = pframe.items:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPRIGHT", 0, rhs_y_offset);
    f_txt:SetText(L["Rename selected"]);
    f_txt:SetTextColor(1, 1, 1);
    f_txt:Hide();
    pframe.items.plan_rename_fstr = f_txt;

    rhs_y_offset = rhs_y_offset - 20;

    f = CreateFrame("EditBox", nil, pframe.items, "InputBoxTemplate");
    f:SetPoint("TOPRIGHT", 5, rhs_y_offset);
    f:SetSize(97, 15);
    f:SetAutoFocus(false);
    local editbox_save = function(self)

        local new_name = self:GetText();

        if new_name ~= "" and working_name ~= new_name then

            __sc_p_char.calculator_saves[new_name] = __sc_p_char.calculator_saves[working_name];
            __sc_p_char.calculator_saves[working_name] = nil;

            pframe.plan_dd.init_func(new_name);

            working_name = new_name;
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
    f:Hide();
    pframe.items.plan_rename_editbox = f;

    rhs_y_offset = rhs_y_offset - 80;

    f = CreateFrame("Button", nil, pframe.items, "UIPanelButtonTemplate");
    f:SetPoint("TOPRIGHT", 5, rhs_y_offset+5);
    f:SetHeight(40);
    f:SetWidth(105);
    f:SetText(L["Save\nplan as"]);
    f:SetScript("OnClick", function(self)

        local plan_name = pframe.items.new_plan_name_editbox:GetText();
        if plan_name ~= "" then

            working_name = plan_name;
            save_calculator_plan(plan_name);
            pframe.plan_dd.init_func(plan_name);
            pframe.items.new_plan_name_editbox:SetText("");

            pframe.items.plan_rename_editbox:SetText(plan_name);
            pframe.items.plan_rename_editbox:Show();
            pframe.items.plan_rename_fstr:Show();
            pframe.save_plan_btn:Enable();
        end
    end);
    pframe.items.save_plan_as_btn = f;

    rhs_y_offset = rhs_y_offset - 40;

    f = CreateFrame("EditBox", nil, pframe.items, "InputBoxTemplate");
    f:SetPoint("TOPRIGHT", 5, rhs_y_offset);
    f:SetSize(97, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            pframe.items.plan_name_empty:Show();
            pframe.items.save_plan_as_btn:Disable();
        else
            pframe.items.plan_name_empty:Hide();
            pframe.items.save_plan_as_btn:Enable();
        end
    end);
    pframe.items.new_plan_name_editbox = f;

    f = pframe.items:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["New plan name"]);
    f:SetPoint("LEFT", pframe.items.new_plan_name_editbox, 5, 0);
    pframe.items.plan_name_empty = f;


    rhs_y_offset = rhs_y_offset - 40;

    f = CreateFrame("Button", nil, pframe.items, "UIPanelButtonTemplate");
    f:SetPoint("TOPRIGHT", 5, rhs_y_offset+5);
    f:SetHeight(40);
    f:SetWidth(105);
    f:SetText(L["Delete\nselected"]);
    f:SetScript("OnClick", function(self)
        if working_name ~= "" then

            __sc_p_char.calculator_saves[working_name] = nil;
            pframe.save_plan_btn:Disable();

            pframe.items.plan_rename_fstr:Hide();
            pframe.items.plan_rename_editbox:Hide();
            working_name = "";
            pframe.plan_dd.init_func(L["Saved plans"]);

            self:Disable();
        end
    end);
    f:Disable();
    pframe.items.delete_plan_btn = f;

    f = CreateFrame("Button", nil, pframe.items, "UIPanelButtonTemplate");
    f:SetPoint("BOTTOMLEFT", 5, -2);
    f:SetHeight(25);
    f:SetWidth(140);
    f:SetText(L["Clear items"]);
    f:SetScript("OnClick", function()
        clear_table(working_item_plan);
        update_calculator_item_planner();
    end);
    local clear_btn = f;

    f = CreateFrame("Button", nil, pframe.items, "UIPanelButtonTemplate");
    f:SetPoint("BOTTOMLEFT", 150, -2);
    f:SetHeight(25);
    f:SetWidth(220);
    f:SetText(L["Use target's equipment"]);
    f:SetScript("OnClick", function(self)

        if not CheckInteractDistance("target", 1) or not CanInspect("target") then
            return;
        end
        self.target_guid = UnitGUID("target");
        if is_secret(self.target_guid) then
            self.target_guid = nil;
            return;
        end

        self.num_retries = 0;

        -- visible gear may already be known, the rest only arrives with the inspect
        use_target_equipment(self);
        self:RegisterEvent("INSPECT_READY");
        NotifyInspect("target");
    end);
    pframe.items.targets_item_btn = f;

    f:SetScript("OnEvent", function(self, e)
        if e == "INSPECT_READY" then
            self:UnregisterEvent("INSPECT_READY");
            if same_target(self) then
                use_target_equipment(self);
            end
        end
    end);

end

local function create_calculator_stats_subframe(pframe)

    local x_pad = 5;
    local f, f_txt;


    pframe.stats.y_offset = pframe.stats.y_offset - 70;

    -- NOTE: the keys here are important and serves as template for other manual style stat-changes
    pframe.stats.stat_fields = {
        int = {
            label_str = L["Intellect"]
        },
        spirit = {
            label_str = L["Spirit"]
        },
        str = {
            label_str = L["Strength"]
        },
        agi = {
            label_str = L["Agility"]
        },
        stam = {
            label_str = L["Stamina"]
        },
        armor = {
            label_str = L["Armor"]
        },
        dodge_rating = {
            label_str = L["Dodge"]
        },
        parry_rating = {
            label_str = L["Parry"]
        },
        defense_skill_rating = {
            label_str = L["Defense"]
        },
        sp = {
            label_str = L["Spell Power"]
        },
        sd = {
            label_str = L["Spell Damage"]
        },
        hp = {
            label_str = L["Healing Power"]
        },
        ap = {
            label_str = L["Melee Attack Power"]
        },
        rap = {
            label_str = L["Ranged Attack Power"]
        },
        weapon_skill = {
            label_str = L["All Weapon Skill"]
        },
        crit_rating = {
            label_str = L["Critical"]
        },
        hit_rating = {
            label_str = L["Hit"]
        },
        haste_rating = {
            label_str = L["Haste"]
        },
        mp5 = {
            label_str = L["MP5"]
        },
        pen = {
            label_str = L["Penetration"]
        },
        expertise_rating = {
            label_str = L["Expertise"],
            clients = bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever)),
        },
        extra_mana = {
            label_str = L["Extra mana"],
        },
        resilience_rating = {
            label_str = L["Resilience"],
            clients = bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever)),
        },
    };

    local comparison_stats_listing_order = {};
    for _, k in ipairs({
        "str", "agi", "stam", "int", "spirit", "mp5", "extra_mana", "armor", "defense_skill_rating", "dodge_rating", "parry_rating", "resilience_rating",
        "crit_rating", "hit_rating", "haste_rating", "expertise_rating", "ap", "rap", "weapon_skill", "sp", "sd", "hp", "pen",
    }) do
        local clients = pframe.stats.stat_fields[k].clients;
        if not clients or client_matches(clients) then
            table.insert(comparison_stats_listing_order, k);
        else
            pframe.stats.stat_fields[k] = nil;
        end
    end

    local new_column_breakpoint = "crit_rating";

    local num_stats = #comparison_stats_listing_order;

    local y_offset_stats = pframe.stats.y_offset;
    local max_y_offset_stats = 0;
    local i = 1;
    local x_offset = 0;
    local editbox_x_pad = 0;
    while i <= num_stats do

        local k = comparison_stats_listing_order[i];
        if k == new_column_breakpoint then
            -- split column special, skip
            y_offset_stats = pframe.stats.y_offset;
            x_offset = x_offset + 210;
            editbox_x_pad = 50;
        end

        local v = pframe.stats.stat_fields[k];
        y_offset_stats = y_offset_stats - 17;

        v.label = pframe.stats:CreateFontString(nil, "OVERLAY");

        v.label:SetFontObject(font);
        v.label:SetPoint("TOPLEFT", x_pad + x_offset, y_offset_stats);
        v.label:SetText(v.label_str);
        v.label:SetTextColor(222/255, 192/255, 40/255);

        v.editbox = CreateFrame("EditBox", v.label_str.."editbox"..k, pframe.stats, "InputBoxTemplate");
        v.editbox:SetPoint("TOPLEFT", 100 + editbox_x_pad + x_offset, y_offset_stats-2);
        v.editbox:SetText("");
        v.editbox:SetAutoFocus(false);
        v.editbox:SetSize(100, 10);
        v.editbox.index = i;
        if sc.loadouts.manual_diff_in_pct(k) then
            local pct = v.editbox:CreateFontString(nil, "OVERLAY");
            pct:SetFontObject(font);
            pct:SetPoint("RIGHT", v.editbox, "RIGHT", -2, 0);
            pct:SetText("%");
            v.editbox:SetTextInsets(0, pct:GetStringWidth() + 4, 0, 0);
        end
        v.editbox:SetScript("OnTextChanged", function(self)

            if string.match(self:GetText(), "[^-+0123456789. ()]") ~= nil then
                self:ClearFocus();
                self:SetText("");
                self:SetFocus();
            else 
                --update_calc_list(true);
            end

            pframe.calculator_plan_changed = true;
        end);

        v.editbox:SetScript("OnEnterPressed", function(self)

        	self:ClearFocus()
        end);

        v.editbox:SetScript("OnEscapePressed", function(self)
        	self:ClearFocus()
        end);

        v.editbox:SetScript("OnTabPressed", function(self)

            local next_index = 0;
            if IsShiftKeyDown() then
                next_index = 1 + ((self.index-2) %num_stats);
            else
                next_index = 1 + (self.index %num_stats);
            end
        	self:ClearFocus()
            pframe.stats.stat_fields[comparison_stats_listing_order[next_index]].editbox:SetFocus();
        end);

        max_y_offset_stats = math.min(max_y_offset_stats, y_offset_stats);
        i = i + 1;
    end

    max_y_offset_stats = max_y_offset_stats - 20;
    f = CreateFrame("Button", nil, pframe.stats, "UIPanelButtonTemplate");
    f:SetScript("OnClick", function()

        for _, v in pairs(pframe.stats.stat_fields) do
            v.editbox:SetText("");
        end
        --update_calc_list(true);
    end);

    f:SetPoint("TOPRIGHT", 5, max_y_offset_stats);
    f:SetHeight(20);
    f:SetWidth(120);
    f:SetText(L["Clear stats"]);

    if __spellcoda_test_all_data__ then
        for _, v in pairs(pframe.stats.stat_fields) do
            v.editbox:SetText("1");
        end
    end
end

local function create_calculator_talents_subframe(pframe)

    local x_pad = 5;


    pframe.talents.y_offset = pframe.talents.y_offset - 80;

    local f = CreateFrame("CheckButton", "__sc_frame_calculator_talents_custom_talents_chk", pframe.talents, "ChatConfigCheckButtonTemplate");
    f:SetPoint("TOPLEFT", x_pad, pframe.talents.y_offset);

    getglobal(f:GetName()..'Text'):SetText(L["Use custom talents"]);
    getglobal(f:GetName()).tooltip =
        L["Accepts a valid wowhead talents link. Its talents & glyphs are used instead of your active ones."];
    f:SetScript("OnClick", function(self)

        working_talents.use_custom = self:GetChecked();
        update_talents_frame();
    end);
    pframe.talents.custom_talents_chk = f;

    pframe.talents.y_offset = pframe.talents.y_offset - 23;

    f = CreateFrame("EditBox", nil, pframe.talents, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", x_pad+25, pframe.talents.y_offset);
    f:SetSize(437, 15);
    f:SetAutoFocus(false);
    editbox_config(f, function(self)

        pframe.calculator_plan_changed = true;
        sc.core.talents_update_needed = true;
        sc.core.equipment_update_needed = true;
        local txt = self:GetText();

        if working_talents.use_custom then
            if txt ~= "" then
                working_talents.custom_code = wowhead_talent_code_from_url(txt);
            end
            pframe.talents.talent_editbox:SetText(
                wowhead_talent_link(working_talents.custom_code)
            );
            pframe.talents.talent_editbox:SetAlpha(1.0);
        else

            pframe.talents.talent_editbox:SetText(
                wowhead_talent_link(active_loadout().talents.code)
            );
            pframe.talents.talent_editbox:SetAlpha(0.2);
            pframe.talents.talent_editbox:SetCursorPosition(0);
        end
        self:ClearFocus();
    end);

    pframe.talents.talent_editbox = f;
end

local forced_buffs_lname_to_id = {};

local function create_calculator_buffs_subframe(pframe)

    pframe.buffs.y_offset = pframe.buffs.y_offset - 65;
    local f, f_txt;

    f = CreateFrame("CheckButton", "__sc_frame_calculator_custom_buffs", pframe.buffs, "ChatConfigCheckButtonTemplate");
    f:SetPoint("TOPLEFT", pframe.buffs, 0, pframe.buffs.y_offset);
    getglobal(f:GetName() .. 'Text'):SetText(L["Apply selected"]);
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        pframe.calculator_plan_changed = true;
        working_buffs.use_custom = self:GetChecked();
        update_buffs_frame();
    end);
    pframe.buffs.custom_buffs_btn = f;

    f = CreateFrame("CheckButton", "__sc_frame_calculator_preserve_buffs", pframe.buffs, "ChatConfigCheckButtonTemplate");
    f:SetPoint("TOPLEFT", pframe.buffs, 173, pframe.buffs.y_offset);
    getglobal(f:GetName() .. 'Text'):SetText(L["Preserve active"]);
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        pframe.calculator_plan_changed = true;
        working_buffs.preserve_active = self:GetChecked();
    end);
    pframe.buffs.preserve_buffs_btn = f;

    f_txt = pframe.buffs:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPRIGHT", 0, pframe.buffs.y_offset-8);
    f_txt:SetText(
        "|cFF9CD6DE"..L["Left click"]..":|r "..L["(De)select"].."\n"..
        "|cFF9CD6DE"..L["Right click"]..":|r "..L["+1 stack"].."\n"..
        "|cFF9CD6DE"..L["Middle click"]..":|r "..L["-1 stack"].."\n"
    );
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.buffs.y_offset = pframe.buffs.y_offset - 25;

    local filter_buffs = function(search_txt, only_selected, categories_mask)

        local num = tonumber(search_txt);
        for _, view in ipairs(buffs_views) do
            view.filtered = {};
            local config_buffs;
            if view.side == "lhs" then
                config_buffs = working_buffs.player_buffs;
            else
                config_buffs = working_buffs.target_buffs;
            end
            for k, v in ipairs(view.buffs) do
                local search_match =
                    search_txt == "" or
                        (v.lname and string.find(string.lower(v.lname), string.lower(search_txt)) or
                            (num and num == v.id));
                if search_match and
                    bit.band(categories_mask, bit.lshift(1, v.cat)) ~= 0 and
                    (not only_selected or config_buffs[v.id]) then

                    table.insert(view.filtered, k);
                end
            end
        end

        for _, view in ipairs(buffs_views) do
            pframe.buffs[view.side].slider:SetMinMaxValues(1, max(1, #view.filtered - math.floor(pframe.buffs[view.side].num_buffs_can_fit/2)));
        end

        update_buffs_frame();
    end;

    f = CreateFrame("EditBox", "__sc_frame_buffs_search", pframe.buffs, "InputBoxTemplate");
    f:SetPoint("TOPLEFT", 8, pframe.buffs.y_offset);
    f:SetSize(160, 15);
    f:SetAutoFocus(false);
    f:SetScript("OnTextChanged", function(self)
        local txt = self:GetText();
        if txt == "" then
            pframe.buffs.search_empty_label:Show();
            for _, view in ipairs(buffs_views) do
                for k, _ in ipairs(view.buffs) do
                    view.filtered[k] = k;
                end
            end
        else
            pframe.buffs.search_empty_label:Hide();
        end
        filter_buffs(pframe.buffs.search:GetText(), pframe.buffs.show_only_selected, pframe.buffs.category_filters_mask);
    end);
    pframe.buffs.search = f;

    f = pframe.buffs:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(font);
    f:SetText(L["Search name or ID"]);
    f:SetPoint("LEFT", pframe.buffs.search, 5, 0);
    pframe.buffs.search_empty_label = f;

    pframe.buffs.show_only_selected = false;
    pframe.buffs.category_filters_mask = bit.bnot(0);
    local categories_display_options = {
        { id = "class",     lname = L["Class"]},
        { id = "player",    lname = L["Player"]},
        { id = "enchant",   lname = L["Enchant"]},
        { id = "hostile",   lname = L["Hostile"]},
        { id = "friendly",  lname = L["Friendly"]},
    };

    local f = CreateFrame("CheckButton", nil, pframe.buffs, "ChatConfigCheckButtonTemplate");
    f:SetPoint("LEFT", pframe.buffs.search, "RIGHT", 5, 0);
    f.Text:SetText("Only show selected auras");

    f:SetScript("OnClick", function(self)
        pframe.buffs.show_only_selected = self:GetChecked();
        filter_buffs(pframe.buffs.search:GetText(), pframe.buffs.show_only_selected, pframe.buffs.category_filters_mask);
    end);


    pframe.buffs.y_offset = pframe.buffs.y_offset - 18;

    pframe.buffs.fadeable_checkboxes = {f, pframe.buffs.preserve_buffs_btn};

    local x_offset = 5;
    for k, v in ipairs(categories_display_options) do
        local f = CreateFrame("CheckButton", nil, pframe.buffs, "ChatConfigCheckButtonTemplate");
        f.Text:SetText(v.lname);
        local color = buff_categories_colors[buff_category[v.id]];
        f.Text:SetTextColor(color[1], color[2], color[3]);
        f:SetPoint("TOPLEFT", x_offset, pframe.buffs.y_offset);

        local w = f.Text:GetStringWidth() or 0;
        x_offset = x_offset + w + 30;
        f:SetChecked(true);
        f:SetHitRectInsets(0, -w, 0, 0);

        f:SetScript("OnClick", function(self)
            if self:GetChecked() then
                pframe.buffs.category_filters_mask =
                    bit.bor(
                        pframe.buffs.category_filters_mask,
                        bit.lshift(1, buff_category[v.id])
                    );
            else
                pframe.buffs.category_filters_mask =
                    bit.band(
                        pframe.buffs.category_filters_mask,
                        bit.bnot(bit.lshift(1, buff_category[v.id]))
                    );
            end
            filter_buffs(pframe.buffs.search:GetText(), pframe.buffs.show_only_selected, pframe.buffs.category_filters_mask);
        end);

        pframe.buffs.fadeable_checkboxes[#pframe.buffs.fadeable_checkboxes + 1] = f;
    end

    pframe.buffs.y_offset = pframe.buffs.y_offset - 18;

    for view_idx, view in ipairs(buffs_views) do

        -- init without any filter, 1 to 1
        for k, _ in ipairs(view.buffs) do
            view.filtered[k] = k;
        end

        local y_offset = pframe.buffs.y_offset;

        local h = 200;
        f = CreateFrame("ScrollFrame", nil, pframe.buffs);
        f:SetWidth(235);
        f:SetHeight(h);
        f:SetPoint("TOPLEFT", pframe.buffs, 240*(view_idx-1), y_offset);
        pframe.buffs[view.side] = {}
        pframe.buffs[view.side].frame = f;

        f = CreateFrame("ScrollFrame", nil, pframe.buffs[view.side].frame);
        f:SetWidth(235);
        f:SetHeight(h-50);
        f:SetPoint("TOPLEFT", pframe.buffs[view.side].frame, 0, -35);
        pframe.buffs[view.side].buffs_list_frame = f;

        pframe.buffs[view.side].num_checked = 0;
        pframe.buffs[view.side].buffs = {};
        pframe.buffs[view.side].buffs_num = 0;

        y_offset = -5;

        f = pframe.buffs[view.side].frame:CreateFontString(nil, "OVERLAY");
        f:SetFontObject(GameFontNormal);
        local fp, _, flags = f:GetFont();
        f:SetFont(fp, 17, flags);
        if (view_idx == 1) then
            f:SetText(L["Player auras"]);
        else
            f:SetText(L["Subject auras"]);
        end
        f:SetPoint("TOPLEFT", 5, y_offset);

        y_offset = y_offset - 15;
        f = CreateFrame("CheckButton", "__sc_frame_check_all_"..view.side, pframe.buffs[view.side].frame, "ChatConfigCheckButtonTemplate");
        f:SetPoint("TOPLEFT", 20, y_offset);
        getglobal(f:GetName() .. 'Text'):SetText(L["Select all/none"]);
        getglobal(f:GetName() .. 'Text'):SetTextColor(1, 0, 0);

        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;
            
            if self:GetChecked() then
                if view.side == "lhs" then
                    for _, v in ipairs(view.buffs) do
                        working_buffs.player_buffs[v.id] = 1;
                        forced_buffs_lname_to_id[C_Spell.GetSpellName(v.id)] = v.id;
                    end
                else
                    for _, v in ipairs(view.buffs) do
                        working_buffs.target_buffs[v.id] = 1;
                        forced_buffs_lname_to_id[C_Spell.GetSpellName(v.id)] = v.id;
                    end
                end
            else
                if view.side == "lhs" then
                    working_buffs.player_buffs = {};
                else
                    working_buffs.target_buffs = {};
                end
            end

            filter_buffs(pframe.buffs.search:GetText(), pframe.buffs.show_only_selected, pframe.buffs.category_filters_mask);
        end);
        pframe.buffs[view.side].select_all_buffs_checkbutton = f;

        -- named, the template anchors its Middle texture by "$parentTop" which otherwise collides between sliders
        f = CreateFrame("Slider", "__sc_frame_buffs_slider_"..view.side, pframe.buffs[view.side].buffs_list_frame, "UIPanelScrollBarTrimTemplate");
        f:SetOrientation('VERTICAL');
        f:SetPoint("RIGHT", pframe.buffs[view.side].buffs_list_frame, "RIGHT", 0, 2);
        f:SetHeight(pframe.buffs[view.side].buffs_list_frame:GetHeight()-30);
        pframe.buffs[view.side].num_buffs_can_fit =
            math.floor(pframe.buffs[view.side].buffs_list_frame:GetHeight()/15);
        f:SetMinMaxValues( 1, max(1, #view.filtered - math.floor(pframe.buffs[view.side].num_buffs_can_fit/2)));
        f:SetValue(1);
        f:SetValueStep(1);
        f:SetScript("OnValueChanged", function(self, val)
            update_buffs_frame();
        end);

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f);
        bg:SetColorTexture(0, 0, 0, 0.5);

        pframe.buffs[view.side].slider = f;

        pframe.buffs[view.side].buffs_list_frame:SetScript("OnMouseWheel", function(self, dir)
            local min_val, max_val = pframe.buffs[view.side].slider:GetMinMaxValues();
            local val = pframe.buffs[view.side].slider:GetValue();
            if val - dir >= min_val and val - dir <= max_val then
                pframe.buffs[view.side].slider:SetValue(val - dir);
                update_buffs_frame();
            end
        end);


        y_offset = 0;
        for i = 1, pframe.buffs[view.side].num_buffs_can_fit do
            pframe.buffs[view.side].buffs[i] = {};

            local checkbtn = CreateFrame("CheckButton", "loadout_buffs_checkbutton"..view.side..i, pframe.buffs[view.side].buffs_list_frame, "ChatConfigCheckButtonTemplate");
            checkbtn.side = view.side;
            checkbtn:SetScript("OnMouseDown", function(self, btn)

                sc.loadouts.force_update = true;
                local config_buffs;
                if view.side == "lhs" then
                    config_buffs = working_buffs.player_buffs;
                else
                    config_buffs = working_buffs.target_buffs;
                end
                if btn == "LeftButton" then
                    if not config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = 1;

                        forced_buffs_lname_to_id[C_Spell.GetSpellName(self.buff_id)] = self.buff_id;
                        pframe.buffs[view.side].num_checked = pframe.buffs[view.side].num_checked + 1;
                    else
                        config_buffs[self.buff_id] = nil;
                        forced_buffs_lname_to_id[C_Spell.GetSpellName(self.buff_id)] = nil;
                        pframe.buffs[view.side].num_checked = pframe.buffs[view.side].num_checked - 1;
                    end

                    if pframe.buffs[view.side].num_checked == 0 then
                        pframe.buffs[view.side].select_all_buffs_checkbutton:SetChecked(false);
                    else
                        pframe.buffs[view.side].select_all_buffs_checkbutton:SetChecked(true);
                    end
                elseif btn == "MiddleButton" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = math.max(1, config_buffs[self.buff_id] - 1);
                    end
                elseif btn == "RightButton" then
                    if config_buffs[self.buff_id] then
                        config_buffs[self.buff_id] = config_buffs[self.buff_id] + 1;
                    end
                end
                self.__stacks_str:SetText(tostring(config_buffs[self.buff_id] or 0));

                filter_buffs(pframe.buffs.search:GetText(), pframe.buffs.show_only_selected, pframe.buffs.category_filters_mask);
            end);
            local icon = CreateFrame("Frame", "loadout_buffs_icon"..view.side..i, pframe.buffs[view.side].buffs_list_frame);
            icon:SetSize(15, 15);
            local tex = icon:CreateTexture(nil);
            icon.tex = tex;
            tex:SetAllPoints(icon);

            checkbtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
                GameTooltip:SetSpellByID(self.buff_id);
                GameTooltip:Show();
            end);
            checkbtn:SetScript("OnLeave", function()
                GameTooltip:Hide();
            end);

            local stacks_str = icon:CreateFontString(nil, "OVERLAY");
            stacks_str:SetFontObject(font);
            stacks_str:SetPoint("BOTTOMRIGHT", 0, 0);
            checkbtn.__stacks_str = stacks_str;

            checkbtn:SetPoint("TOPLEFT", 20, y_offset);
            icon:SetPoint("TOPLEFT", 5, y_offset -4);
            y_offset = y_offset - 15;

            pframe.buffs[view.side].buffs[i].checkbutton = checkbtn;
            pframe.buffs[view.side].buffs[i].icon = icon;
        end
    end
end

local function create_sw_ui_calculator_frame(pframe)

    local x_pad = 5;
    pframe.calculator_plan_changed = true;

    pframe:HookScript("OnHide", function()
        sc.loadouts.force_update = true;
        sc.core.deactivate_tooltip_refresh();
    end);

    local f, f_txt;
    pframe.y_offset = pframe.y_offset - 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["While this tab is open, ability overlay & tooltips reflect the change below"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 40;

    local tabs = {
        {"items", L["Item planner"]},
        {"stats", L["Stat changes"]},
        {"talents", L["Talents"]},
        {"buffs", L["Buffs"]},
    };

    local subframe_height = 315;
    do
        for k, v in pairs(tabs) do
            local tab = create_tab_button(pframe);

            tab:SetText(v[2]);
            tab:SetScript("OnClick", function(self)
                for _, vv in ipairs(tabs) do

                    select_tab(pframe[vv[1].."_tab"], false);
                    pframe[vv[1]]:Hide();
                end

                select_tab(self, true);
                pframe[v[1]]:Show();
                if pframe[v[1]].on_show then
                    pframe[v[1]].on_show();
                end
                if self == pframe.items_tab then
                    pframe.after_area:ClearAllPoints();
                    pframe.before_area:ClearAllPoints();
                    pframe.before_area:SetPoint("TOP", pframe.diffs_area, "BOTTOM", 0, -5);
                    pframe.after_area:SetPoint("TOP", pframe.before_area, "BOTTOM", 0, -5);
                else
                    pframe.after_area:ClearAllPoints();
                    pframe.before_area:ClearAllPoints();
                    pframe.after_area:SetPoint("LEFT", pframe.diffs_area, "RIGHT", 5, 0);
                    pframe.before_area:SetPoint("RIGHT", pframe.diffs_area, "LEFT", -5, 0);
                end
            end);

            local f = CreateFrame("Frame", nil, tab);
            f:SetSize(6, 6);
            f:SetPoint("RIGHT", -8, -6);
            f:Hide();

            f.dot = f:CreateTexture(nil, "OVERLAY");
            f.dot:SetColorTexture(0.2, 1, 0.2, 1);
            f.dot:SetSize(6, 6);
            f.dot:SetPoint("CENTER", 0, 0);
            tab.changed_indicator = f;

            local subframe = CreateFrame("ScrollFrame", nil, pframe);
            subframe:SetPoint("TOPLEFT", 0, pframe.y_offset);
            subframe:SetWidth(pframe:GetWidth());
            subframe:SetHeight(subframe_height);
            subframe.y_offset = 0;

            pframe[v[1]] = subframe;
            pframe[v[1].."_tab"] = tab;
        end

        local row = {};
        for _, v in ipairs(tabs) do
            table.insert(row, pframe[v[1].."_tab"]);
        end
        layout_tabs(row, -7, pframe.y_offset+34, pframe:GetWidth()+14);
    end

    pframe.items.working = working_item_plan;
    pframe.stats.working = working_stats;
    pframe.talents.working = working_talents;
    pframe.buffs.working = working_buffs;

    pframe.buffs.on_show = update_buffs_frame;
    pframe.talents.on_show = update_talents_frame;

    pframe.y_offset = pframe.y_offset - 5;

    pframe.diffs_txt = "";

    local diffs_area = CreateFrame("Frame", nil, pframe, "BackdropTemplate");
    diffs_area:SetSize(110, 40);
    diffs_area:SetPoint("TOPLEFT", 119, pframe.y_offset-17);
    diffs_area:EnableMouse(true);
    diffs_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["Changes"]);
        else
            GameTooltip:SetText(L["Changes (simplified)"]);
        end
        GameTooltip:AddLine(pframe.diffs_txt);
        GameTooltip:Show();
    end);
    diffs_area:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    diffs_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["Effect changes"],
            pframe.diffs_txt,
            300,
            400
        );
    end);

    diffs_area:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 2; -- thickness of the border
    });
    diffs_area:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
    diffs_area:SetBackdropBorderColor(1, 0.8, 0, 1);

    pframe.diffs_area = diffs_area;

    f = diffs_area:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetPoint("CENTER");
    pframe.diffs_fontstr = f;

    local arrow_tex_path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up";

    local f = diffs_area:CreateTexture(nil, "ARTWORK");
    f:SetTexture(arrow_tex_path);
    f:SetPoint("BOTTOMRIGHT", -2, 2);
    f:SetTexCoord(0.3, 0.7, 0.3, 0.7);
    f:SetSize(8, 8);
    f:SetRotation(-3.14592/4);


    local before_area = CreateFrame("Frame", nil, pframe, "BackdropTemplate");
    before_area:SetSize(110, 30);
    before_area:EnableMouse(true);
    before_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["Before"]);
        else
            GameTooltip:SetText(L["Before (simplified)"]);
        end

        GameTooltip:AddLine(pframe.before_txt);
        GameTooltip:Show();
    end);
    before_area:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    before_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["Before"],
            pframe.before_txt,
            300,
            400
        );
    end);

    before_area:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 2; -- thickness of the border
    });
    before_area:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
    before_area:SetBackdropBorderColor(1, 0.8, 0, 1);

    f = before_area:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetPoint("CENTER");
    f:SetText(L["Before"]);

    local f = before_area:CreateTexture(nil, "ARTWORK");
    f:SetTexture(arrow_tex_path);
    f:SetPoint("BOTTOMRIGHT", -2, 2);
    f:SetTexCoord(0.3, 0.7, 0.3, 0.7);
    f:SetSize(8, 8);
    f:SetRotation(-3.14592/4);
    pframe.before_area = before_area;


    local after_area = CreateFrame("Frame", nil, pframe, "BackdropTemplate");
    after_area:SetSize(110, 30);
    after_area:EnableMouse(true);
    after_area:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        if config.settings.general_calc_stats_raw_dump then
            GameTooltip:SetText(L["After"]);
        else
            GameTooltip:SetText(L["After (simplified)"]);
        end
        GameTooltip:AddLine(pframe.after_txt);
        GameTooltip:Show();
    end);
    after_area:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    after_area:SetScript("OnMouseDown", function(self)
        dump_text(
            L["After"],
            pframe.after_txt,
            300,
            400
        );
    end);

    after_area:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 2; -- thickness of the border
    });
    after_area:SetBackdropColor(0.2, 0.2, 0.2, 0.8);
    after_area:SetBackdropBorderColor(1, 0.8, 0, 1);
    pframe.after_area = after_area;

    f = after_area:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetPoint("CENTER");
    f:SetText(L["After"]);

    local f = after_area:CreateTexture(nil, "ARTWORK");
    f:SetTexture(arrow_tex_path);
    f:SetPoint("BOTTOMRIGHT", -2, 2);
    f:SetTexCoord(0.3, 0.7, 0.3, 0.7);
    f:SetSize(8, 8);
    f:SetRotation(-3.14592/4);

    pframe.plan_dd = libDD:Create_UIDropDownMenu(nil, pframe);
    pframe.plan_dd:SetPoint("TOPRIGHT", 20, pframe.y_offset);
    pframe.plan_dd.init_func = function(plan_name)
        libDD:UIDropDownMenu_Initialize(pframe.plan_dd, function()

            libDD:UIDropDownMenu_SetWidth(pframe.plan_dd, 90);
            libDD:UIDropDownMenu_SetText(pframe.plan_dd, plan_name);

            for name, plan in pairs(__sc_p_char.calculator_saves) do

                libDD:UIDropDownMenu_AddButton({
                    text = name,
                    checked = name == working_name,
                    func = function()

                        pframe.save_plan_btn:Enable();
                        pframe.items.plan_rename_editbox:SetText(name);
                        pframe.items.plan_rename_editbox:Show();
                        pframe.items.plan_rename_fstr:Show();
                        pframe.items.delete_plan_btn:Enable();

                        load_calculator_plan(plan);
                        working_name = name;
                        pframe.plan_dd.init_func(name);
                        --libDD:UIDropDownMenu_SetText(pframe.plan_dd, name);
                        update_calculator_item_planner();
                        -- Texture may be unavailable when loaded cold
                        -- Try again in 1 second
                        C_Timer.After(1.0, update_calculator_item_planner);
                    end
                });
            end
        end);
    end;
    pframe.plan_dd.init_func(L["Saved plans"]);

    f = CreateFrame("Button", nil, pframe, "UIPanelButtonTemplate");
    f:SetPoint("TOPRIGHT", 5, pframe.y_offset-28);
    f:SetHeight(20);
    f:SetWidth(105);
    f:SetText(L["Save"]);
    f:SetScript("OnClick", function(self)
        save_calculator_plan(working_name);
        pframe.plan_dd.init_func(working_name);
    end);
    f:Disable();
    pframe.save_plan_btn = f;

    -- Item planner subframe
    create_calculator_items_subframe(pframe);


    -- Manual stats tabbed subframe
    create_calculator_stats_subframe(pframe);

    -- Talents tabbed subframe
    create_calculator_talents_subframe(pframe);

    -- Buffs tabbed subframe
    create_calculator_buffs_subframe(pframe);

    pframe.y_offset = pframe.y_offset - subframe_height;

    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 3;

    multi_row_checkbutton(
        {{id = "calc_list_use_highest_rank", txt = L["Use highest learned rank"]}},
        pframe,
        2,
        function()
            if __sc_frame:IsShown() and pframe:IsShown() then
                update_calc_list(true);
            end
        end,
        -5);


    pframe.stat_diff_dd = libDD:Create_UIDropDownMenu(nil, pframe);

    local stat_diff_opts = {
        { "tooltip_item_stat_diff_tank",   L["Tank"]            },
        { "tooltip_item_stat_diff_melee",  L["Melee"]           },
        { "tooltip_item_stat_diff_ranged", L["Ranged"]          },
        { "tooltip_item_stat_diff_caster", L["Caster"]          },
        { "tooltip_item_stat_diff_healer", L["Healer"]          },
        { "tooltip_item_stat_diff_spells", L["Ability effects"] },
    };
    pframe.stat_diff_dd:SetPoint("TOPLEFT", 200, pframe.y_offset+2);
    pframe.stat_diff_dd.init_func = function()
        libDD:UIDropDownMenu_Initialize(pframe.stat_diff_dd, function()

            libDD:UIDropDownMenu_SetText(pframe.stat_diff_dd, L["Stats display"]);
            libDD:UIDropDownMenu_SetWidth(pframe.stat_diff_dd, 100);

            for _, v in ipairs(stat_diff_opts) do
                local opt = v[1];
                local lname = v[2];

                libDD:UIDropDownMenu_AddButton(
                    {
                        text = lname,
                        checked = config.settings[opt],
                        keepShownOnClick = true,
                        notCheckable = false,
                        func = function()

                            config.settings[opt] = not config.settings[opt];
                            __sc_frame.calculator_frame.calculator_plan_changed = true;
                        end
                    }
                );
            end
        end);
    end;

    pframe.stat_diff_dd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(L["Tooltips show stats relevant to these categories."], 1, 1, 1);
        GameTooltip:Show();
    end);

    pframe.stat_diff_dd:SetScript("OnLeave", function(self)
        GameTooltip:Hide();
    end);
    pframe.stat_diff_dd.init_func();

    -- sim type button
    pframe.sim_type_button = libDD:Create_UIDropDownMenu("__sc_frame_setting_calc_fight_type", pframe);

    pframe.sim_type_button._type = "DropDownMenu";
    pframe.sim_type_button:SetPoint("TOPRIGHT", 20, pframe.y_offset+2);
    pframe.sim_type_button.init_func = function()
        libDD:UIDropDownMenu_Initialize(pframe.sim_type_button, function()

            if config.settings.calc_fight_type == fight_types.repeated_casts then
                libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Repeated casts"]);
                pframe.spell_diff_header_center:SetText(L["Effect"]);
                pframe.spell_diff_header_right:SetText(L["Per sec"]);
            elseif config.settings.calc_fight_type == fight_types.cast_until_oom then
                libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Cast until OOM"]);
                pframe.spell_diff_header_center:SetText(L["Effect"]);
                pframe.spell_diff_header_right:SetText(L["Duration (sec)"]);
            end
            libDD:UIDropDownMenu_SetWidth(pframe.sim_type_button, 120);

            libDD:UIDropDownMenu_AddButton(
                {
                    text = L["Repeated cast"],
                    checked = config.settings.calc_fight_type == fight_types.repeated_casts,
                    func = function()

                        config.settings.calc_fight_type = fight_types.repeated_casts;
                        libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Repeated casts"]);
                        pframe.spell_diff_header_center:SetText(L["Effect"]);
                        pframe.spell_diff_header_right:SetText(L["Per sec"]);
                        update_calc_list(true);
                    end
                }
            );
            libDD:UIDropDownMenu_AddButton(
                {
                    text = L["Cast until OOM"],
                    checked = config.settings.calc_fight_type == fight_types.cast_until_oom,
                    func = function()

                        config.settings.calc_fight_type = fight_types.cast_until_oom;
                        libDD:UIDropDownMenu_SetText(pframe.sim_type_button, L["Cast until OOM"]);
                        pframe.spell_diff_header_center:SetText(L["Effect"]);
                        pframe.spell_diff_header_right:SetText(L["Duration (sec)"]);
                        update_calc_list(true);
                    end
                }
            );
        end);
    end;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    f:SetText(L["Abilities can be added from Spells tab"]);
    f:SetTextColor(232.0/255, 225.0/255, 32.0/255);
    pframe.spells_add_tip = f;

    pframe.y_offset = pframe.y_offset - 27;

    pframe.spell_diff_header_spell = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_spell:SetFontObject(font);
    pframe.spell_diff_header_spell:SetPoint("TOPLEFT", x_pad, pframe.y_offset);
    pframe.spell_diff_header_spell:SetText(L["Spell difference"]);

    pframe.spell_diff_header_center = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_center:SetFontObject(font);
    pframe.spell_diff_header_center:SetPoint("LEFT", pframe, "TOPLEFT", x_pad + 255, pframe.y_offset-4);
    pframe.spell_diff_header_center:SetText("");

    pframe.spell_diff_header_right = pframe:CreateFontString(nil, "OVERLAY");
    pframe.spell_diff_header_right:SetFontObject(font);
    pframe.spell_diff_header_right:SetPoint("LEFT", pframe, "TOPLEFT", x_pad + 356, pframe.y_offset-4);
    pframe.spell_diff_header_right:SetText("");


    update_calculator_item_planner();
    pframe.items_tab:Click();
    pframe.calc_list = {};
end

local function create_sw_ui_loadout_frame(pframe)
    local f, f_txt;

    pframe.y_offset = pframe.y_offset - 5;
    local x_pad = 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell calculation parameters"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", x_pad, pframe.y_offset+2);
    f_txt:SetText(L["Active profile: "]);
    pframe.profile_name_label = f_txt;

    pframe.y_offset = pframe.y_offset - 25;

    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText(L["Player"]);
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 20;


    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_use_custom_lvl", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    f:SetHitRectInsets(0, 0, 0, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Custom player level"]);
    getglobal(f:GetName()).tooltip =
        L["Displays ability information as if character is a custom level (attributes from levels are not accounted for)."];

    f:SetScript("OnClick", function(self)

        sc.loadouts.force_update = true;
        config.settings.loadout_use_custom_lvl = self:GetChecked();
        sc.core.old_ranks_checks_needed = true;
        if config.settings.loadout_use_custom_lvl then
            pframe.loadout_clvl_editbox:Show();
        else
            pframe.loadout_clvl_editbox:Hide();
        end
    end);
    pframe.custom_lvl_checkbutton = f;

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_lvl", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", getglobal(pframe.custom_lvl_checkbutton:GetName()..'Text'), "RIGHT", 10, 0);
    f:SetSize(50, 15);
    f:SetAutoFocus(false);
    f:Hide();
    f.number_editbox = true;
    local clvl_editbox_update = function(self)
        sc.loadouts.force_update = true;
        local lvl = tonumber(self:GetText());
        local valid = lvl and lvl >= 1 and lvl <= sc.max_lvl;
        sc.core.old_ranks_checks_needed = true;
        if valid then
            config.settings.loadout_lvl = lvl;
        end
        return valid;
    end
    local clvl_editbox_close = function(self)
        if not clvl_editbox_update(self) then
            local clvl = UnitLevel("player");
            self:SetText(""..clvl);
        end

    	self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, clvl_editbox_update, clvl_editbox_close);
    pframe.loadout_clvl_editbox = f;

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_always_max_resource", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Always at maximum resources"]);
    getglobal(f:GetName()).tooltip = 
        L["Assumes you are casting from maximum mana, energy, rage or combo points."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.settings.loadout_always_max_resource = self:GetChecked();
    end)
    pframe.max_mana_checkbutton = f;

    if client_matches(client_flags.forever) then
        pframe.y_offset = pframe.y_offset - 25;

        f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_combat_ignore_buffs", pframe, "ChatConfigCheckButtonTemplate");
        f._type = "CheckButton";
        f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
        getglobal(f:GetName()..'Text'):SetText(L["Ignore buffs in combat"]);
        getglobal(f:GetName()).tooltip =
            L["Removes buffs from calculations while in combat, except shapeshift forms."];
        f:SetScript("OnClick", function(self)
            sc.loadouts.force_update = true;
            config.settings.loadout_combat_ignore_buffs = self:GetChecked();
        end)

        local help_icon = make_help_icon_tooltip(nil, pframe, L["Buffs can not be read in combat"],
            L["Unchecked, buffs active when entering combat are assumed throughout combat."]);
        help_icon:SetPoint("LEFT", getglobal(f:GetName()..'Text'), "RIGHT", 10, 0);
    end


    pframe.y_offset = pframe.y_offset - 30;
    local div = pframe:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.5, 0.5, 0.5, 0.6);
    div:SetHeight(1);
    div:SetPoint("TOPLEFT", pframe, "TOPLEFT", 0, pframe.y_offset);
    div:SetPoint("TOPRIGHT", pframe, "TOPRIGHT", 0, pframe.y_offset);

    pframe.y_offset = pframe.y_offset - 5;
    f = pframe:CreateFontString(nil, "OVERLAY");
    f:SetFontObject(GameFontNormal);
    local fp, _, flags = f:GetFont();
    f:SetFont(fp, 17, flags);
    f:SetText(L["Target"]);
    f:SetPoint("TOPLEFT", 5, pframe.y_offset);
    pframe.y_offset = pframe.y_offset - 25;

    pframe.auto_armor_frames = {};
    pframe.custom_armor_frames = {};

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_target_automatic_armor", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Estimate armor:"]);
    getglobal(f:GetName()).tooltip = 
        L["Estimates armor from target level."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        local checked = self:GetChecked();
        config.settings.loadout_target_automatic_armor = checked;
        if checked then
            for _, v in pairs(pframe.auto_armor_frames) do
                v:Show();
            end
            for _, v in pairs(pframe.custom_armor_frames) do
                v:Hide();
            end
        else
            for _, v in pairs(pframe.auto_armor_frames) do
                v:Hide();
            end
            for _, v in pairs(pframe.custom_armor_frames) do
                v:Show();
            end
        end
    end);
    f:SetHitRectInsets(0, 0, 0, 0);
    pframe.automatic_armor = f;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", getglobal(f:GetName()..'Text'), "RIGHT", 50, 0);
    f_txt:SetText(L["Custom armor value"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);
    pframe.custom_armor_frames[1] = f_txt;


    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_target_armor", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_target_armor_update = function(self)
        sc.loadouts.force_update = true;
        local target_armor = tonumber(self:GetText());
        local valid = target_armor and target_armor >= 0;
        if valid then
            config.settings.loadout_target_armor = target_armor;
        end
        return valid;
    end
    local editbox_target_armor_close = function(self)

        sc.loadouts.force_update = true;
        if not editbox_target_armor_update(self) then
            self:SetText("0");
            config.settings.loadout_target_armor = 0;
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_target_armor_update, editbox_target_armor_close);
    pframe.custom_armor_frames[2] = f;

    local armor_pct_fn = function(self)
        sc.loadouts.force_update = true;

        local checked = self:GetChecked();
        config.settings["loadout_target_automatic_armor_"..self._armor] = checked;
        if checked then
            for i, v in ipairs(pframe.auto_armor_frames) do
                if self ~= v and v:GetChecked() then
                    v:Click();
                end
            end
        else
            local others_unchecked = true;
            for i, v in ipairs(pframe.auto_armor_frames) do
                if v:GetChecked() then
                    others_unchecked = false;
                end
            end
            if others_unchecked then
                self:Click();
            end
        end
    end;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_target_automatic_armor_heavy", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._armor = "heavy";
    f:SetPoint("LEFT", getglobal(pframe.automatic_armor:GetName()..'Text'), "RIGHT", 40, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Heavy"].." 100%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[1] = f;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_target_automatic_armor_medium", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._armor = "medium";
    f:SetPoint("LEFT", getglobal(pframe.auto_armor_frames[1]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Medium"].." 80%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[2] = f;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_target_automatic_armor_light", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f._armor = "light";
    f:SetPoint("LEFT", getglobal(pframe.auto_armor_frames[2]:GetName()..'Text'), "RIGHT", 10, 0);
    getglobal(f:GetName()..'Text'):SetText(L["Light"].." 50%");
    f:SetHitRectInsets(0, 0, 0, 0);
    f:SetScript("OnClick", armor_pct_fn);
    pframe.auto_armor_frames[3] = f;

    for _, v in pairs(pframe.auto_armor_frames) do
        v:Hide();
    end
    for _, v in pairs(pframe.custom_armor_frames) do
        v:Show();
    end

    pframe.y_offset = pframe.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_behind_target", pframe, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", pframe, x_pad, pframe.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Attacked from behind, eliminating parry and block"]);
    f:SetScript("OnClick", function(self)
        config.settings.loadout_behind_target = self:GetChecked();
        sc.loadouts.force_update = true;
    end)

    pframe.y_offset = pframe.y_offset - 30;


    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Default level difference"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_default_target_lvl_diff", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_update = function(self)
        sc.loadouts.force_update = true;
        -- silently try to apply valid changes but don't panic while focus is on
        local lvl_diff = tonumber(self:GetText());
        local valid = lvl_diff and lvl_diff == math.floor(lvl_diff) and config.settings.loadout_lvl + lvl_diff >= 1 and config.settings.loadout_lvl + lvl_diff <= 83;
        if valid then

            config.settings.loadout_default_target_lvl_diff = lvl_diff;
        end
        return valid;
    end;
    local editbox_close = function(self)

        if not editbox_update(self) then
            self:SetText(""..config.settings.loadout_default_target_lvl_diff);
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_update, editbox_close);
    pframe.level_editbox = f;

    local help_icon = make_help_icon_tooltip(nil, pframe, L["Used when no hostile target is available"]);
    help_icon:SetPoint("LEFT", pframe.level_editbox, "RIGHT", 10, 0);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Default health"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_default_target_hp_perc", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_hp_perc_update = function(self)
        sc.loadouts.force_update = true;
        local hp_perc = tonumber(self:GetText());
        local valid = hp_perc and hp_perc >= 0;
        if valid then
            config.settings.loadout_default_target_hp_perc = hp_perc;
        end
        return valid;
    end
    local editbox_hp_perc_close = function(self)

        if not editbox_hp_perc_update(self) then
            self:SetText(""..loadout.default_target_hp_perc);
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end
    editbox_config(f, editbox_hp_perc_update, editbox_hp_perc_close);
    pframe.hp_perc_label_editbox = f;
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("LEFT", f, "RIGHT", 5, 0);
    f_txt:SetText("%");
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    local help_icon = make_help_icon_tooltip(nil, pframe, L["Used when no target is available"]);
    help_icon:SetPoint("LEFT", pframe.hp_perc_label_editbox, "RIGHT", 20, 0);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Default hostile target creature type:"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    pframe.creature_type_dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_loadout_default_target_creature_type", pframe);

    --f:SetPoint("LEFT", pframe.level_editbox, "RIGHT", 10, 0);
    pframe.creature_type_dd._type = "DropDownMenu";
    pframe.creature_type_dd:SetPoint("RIGHT", f_txt, "RIGHT", 40, -3);
    pframe.creature_type_dd.init_func = function()
        libDD:UIDropDownMenu_Initialize(pframe.creature_type_dd, function()
            
            if config.settings.loadout_default_target_creature_type == 0 then
                libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, L["None"]);
            end
            libDD:UIDropDownMenu_AddButton({
                    text = L["None"],
                    checked = config.settings.loadout_default_target_creature_type == 0,
                    func = function()
                        sc.loadouts.force_update = true;
                        config.settings.loadout_default_target_creature_type = 0;

                        libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, L["None"]);
                    end
                }
            );
            for lname, id in pairs(sc.creature_lname_to_id) do
                if config.settings.loadout_default_target_creature_type == id then
                    libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, lname);
                end
                libDD:UIDropDownMenu_AddButton({
                        text = lname,
                        checked = config.settings.loadout_default_target_creature_type == id,
                        func = function()
                            sc.loadouts.force_update = true;
                            config.settings.loadout_default_target_creature_type = id;
                            config.settings.calc_fight_type = fight_types.repeated_casts;

                            libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, lname);
                        end
                    }
                );

            end

        end);
    end;
    pframe.creature_type_dd.init_func();

    local help_icon = make_help_icon_tooltip(nil, pframe, L["Used when no hostile target is available"]);
    help_icon:SetPoint("LEFT", pframe.creature_type_dd, "RIGHT", 120, 0);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Resistance"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_target_res", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_target_res_update = function(self)
        sc.loadouts.force_update = true;
        local target_res = tonumber(self:GetText());
        local valid = target_res and target_res >= 0;
        if valid then
            config.settings.loadout_target_res = target_res;
        end
        return valid;
    end
    local editbox_target_res_close = function(self)

        if not editbox_target_res_update(self) then
            self:SetText("0");
            config.settings.loadout_target_res = 0;
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, editbox_target_res_update, editbox_target_res_close);

    pframe.y_offset = pframe.y_offset - 25;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Resilience"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_target_pvpres", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetText("");
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local editbox_target_pvpres_update = function(self)
        sc.loadouts.force_update = true;
        local target_pvpres = tonumber(self:GetText());
        local valid = target_pvpres and target_pvpres >= 0;
        if valid then
            config.settings.loadout_target_pvpres = target_pvpres;
        end
        return valid;
    end
    local editbox_target_pvpres_close = function(self)

        if not editbox_target_pvpres_update(self) then
            self:SetText("0");
            config.settings.loadout_target_pvpres = 0;
        end
        self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, editbox_target_pvpres_update, editbox_target_pvpres_close);

    pframe.y_offset = pframe.y_offset - 25;


    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
    f_txt:SetText(L["Number of targets for unbounded AOE spells"]);
    f_txt:SetTextColor(1.0,  1.0,  1.0);

    f = CreateFrame("EditBox", "__sc_frame_setting_loadout_unbounded_aoe_targets", pframe, "InputBoxTemplate");
    f._type = "EditBox";
    f:SetPoint("LEFT", f_txt, "RIGHT", 10, 0);
    f:SetSize(40, 15);
    f:SetAutoFocus(false);
    f.number_editbox = true;
    local aoe_targets_editbox_update = function(self)
        sc.loadouts.force_update = true;
        local targets = tonumber(self:GetText());
        local valid = targets and targets >= 1;
        if valid then
            config.settings.loadout_unbounded_aoe_targets = math.floor(targets);
        end
        return valid;
    end
    local aoe_targets_editbox_close = function(self)
        if not aoe_targets_editbox_update(self) then
            self:SetText("1");
            config.settings.loadout_unbounded_aoe_targets = 1;
        end
    	self:ClearFocus();
        self:HighlightText(0,0);
    end

    editbox_config(f, aoe_targets_editbox_update, aoe_targets_editbox_close);
    pframe.loadout_unbounded_aoe_targets_editbox = f;
end

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
            txt = L["Average out proc effects"],
            tooltip = L["Removes many proc effects and instead averages out its effect, giving more meaning to the spell evaluation. Example: Nature's grace modifies expected cast time to scale with crit, giving crit higher stat weight. Clearcasts etc."],
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
    };

    multi_row_checkbutton(spell_settings, pframe, 1);

    pframe.y_offset = pframe.y_offset - 5;
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

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Color palette RGB"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    pframe.y_offset = pframe.y_offset - 15;
    -- headers
    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset);
    f_txt:SetText(L["Tag"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 230, pframe.y_offset);
    f_txt:SetText(L["Red"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 310, pframe.y_offset);
    f_txt:SetText(L["Green"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPLEFT", 390, pframe.y_offset);
    f_txt:SetText(L["Blue"]);
    f_txt:SetTextColor(222/255, 192/255, 40/255);

    pframe.y_offset = pframe.y_offset - 15;
    for _, v in ipairs({
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
        {"cost_per_sec", L["Effect per sec"]},
        {"effect_until_oom", L["Effect until OOM"]},
        {"casts_until_oom", L["Casts until OOM"]},
        {"time_until_oom", L["Time until OOM"]},
        {"sp_effect", L["Spell info internals (coefs etc)"]},
        {"stat_weights", L["Stat weights"]},
        {"spell_rank", L["Spell rank"]},

    }) do
        local label_frame_setting_subkey = "general_color_"..v[1];
        do
            f_txt = pframe:CreateFontString(nil, "OVERLAY");
            f_txt:SetFontObject(GameFontNormal);
            f_txt:SetPoint("TOPLEFT", 10, pframe.y_offset-4);
            f_txt:SetText(v[2]);
            register_text_frame_color(f_txt, v[1]);
        end

        for i, rgb_comp in pairs({"_r", "_g", "_b"}) do
            local option_key = label_frame_setting_subkey..rgb_comp;
            f = CreateFrame("EditBox", "__sc_frame_setting_"..option_key, pframe, "InputBoxTemplate");
            f._type = "EditBox";
            f._settings_id = option_key;
            f.number_editbox = true;
            f:SetPoint("TOPLEFT", 230 + (i-1)*80, pframe.y_offset-2);
            f:SetSize(35, 15);
            f:SetAutoFocus(false);
            local update = function(self)
                local val = tonumber(self:GetText());
                local valid = val and val >= 0 and val <= 255
                if valid then
                    config.settings[self._settings_id] = val;
                    assign_color_tag(v[1], i, val);
                    for frame, color_tag in pairs(colored_text_frames) do
                        if color_tag == v[1] then
                            frame:SetTextColor(effect_color(v[1]));
                        end
                    end
                    sc.core.update_action_bar_needed = true;
                    sc.loadouts.force_update = true;
                    for label in pairs(sc.overlay.ccf_labels) do
                        sc.overlay.ccf_label_reconfig(label);
                    end
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

            f_txt = pframe:CreateFontString(nil, "OVERLAY");
            f_txt:SetFontObject(GameFontNormal);
            f_txt:SetPoint("TOPLEFT", 230+(i-1)*80 + 38, pframe.y_offset-4);
            f_txt:SetText("/255");
            f_txt:SetTextColor(1, 1, 1);
        end
        pframe.y_offset = pframe.y_offset - 16;
    end

    make_frame_scrollable(pframe);
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
            tooltip:AddLine("|cFF9CD6DE"..L["Addon data generated from"]..":|r");
            tooltip:AddLine("    "..sc.client_name_src.." "..sc.client_version_src);
            tooltip:AddLine("|cFF9CD6DE"..L["Current client build"]..":|r "..sc.client_version_loaded);
            tooltip:AddLine("|cFF9CD6DE"..L["Factory reset (reloads UI)"]..":|r /sc reset");
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

---------------------------------------------------------------------------------------------------
-- spell catalogue on the spellbook's pages (forever)
local function create_book_catalogue(sb, container, open_sc_tab)

    local book = {};
    local view_w = 680;
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
    local content_r = 614;
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
    -- the configured colors are for a dark background, darkened for parchment
    local per_sec_color = {};
    local per_cost_color = {};
    local function on_parchment(r, g, b)
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
        if sb:GetWidth() < 1200 then
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
        fs:SetShadowColor(0.25, 0.12, 0.0, 1.0);
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
            root:CreateTitle(C_Spell.GetSpellName(spell_id));
            if spells[spell_id] and bit.band(spells[spell_id].flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0 then
                root:CreateButton(L["Add to calculator list"], function()
                    config.settings.spell_calc_list[spell_id] = 1;
                    update_calc_list(true);
                end);
            end
            root:CreateButton(L["Add/remove to spell ignore list"], function()
                if config.settings.spells_ignore_list[spell_id] then
                    config.settings.spells_ignore_list[spell_id] = nil;
                else
                    config.settings.spells_ignore_list[spell_id] = 1;
                end
                update_spell_catalogues(nil, nil, nil, true);
            end);
        end);
    end

    -- by mouse focus, IsMouseOver is true under a menu covering the row
    local function has_mouse(f)
        return f:IsMouseMotionFocus();
    end

    local function update_hover(row)
        local over = row.spell_id ~= nil and
            (has_mouse(row) or has_mouse(row.area) or has_mouse(row.item) or has_mouse(row.menu_button));
        row.hl:SetShown(over);
        row.menu_button:SetShown(over);
        if row.icon_hl then
            row.icon_hl:SetShown(over);
        end
    end

    local function layout_columns()
        local measure = container:CreateFontString(nil, "ARTWORK", "GameFontBlackMedium");
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
        col("cost", L["Acquisition"], 84, 16);
        col("per_cost", L["Per cost"], 56, 16, 16);
        col("per_sec", L["Per second"], 64, 6, 16);
        col("type", nil, 14, 16);
        col("lvl", L["Level"], 28, 12);
        cols.name.w = x - cols.name.x;
    end

    local function create_row(parent, mode)
        local row = CreateFrame("Button", nil, parent);
        row:SetWidth(view_w);
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
        row.hl:SetColorTexture(0.35, 0.2, 0.05, 0.12);
        row.hl:Hide();

        local area = CreateFrame("Button", nil, row);
        area:SetPoint("TOPLEFT");
        area:SetPoint("BOTTOMLEFT");
        area:SetWidth(cols.name.x + cols.name.w);
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

            local name_w = cols.name.x + cols.name.w - full_name_x;
            row.name = area:CreateFontString(nil, "ARTWORK", "SystemFont_Large");
            row.name:SetWidth(name_w);
            row.name:SetJustifyH("LEFT");
            row.name:SetWordWrap(false);
            row.sub_name = area:CreateFontString(nil, "ARTWORK", "SystemFont_Med1");
            row.sub_name:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2);
            row.sub_name:SetWidth(name_w);
            row.sub_name:SetJustifyH("LEFT");
            row.sub_name:SetWordWrap(false);
            row.sub_name:SetTextColor(unpack(base_color));
        else
            row.icon = area:CreateTexture(nil, "ARTWORK");
            row.icon:SetSize(16, 16);
            row.icon:SetPoint("LEFT", 1, 0);

            row.name = area:CreateFontString(nil, "ARTWORK", "GameFontBlack");
            row.name:SetPoint("LEFT", cols.name.x, 0);
            row.name:SetWidth(cols.name.w);
            row.name:SetJustifyH("LEFT");
            row.name:SetWordWrap(false);
        end

        row.lvl = lvl_font_string(row, mode.value_font);
        row.lvl:SetPoint("LEFT", cols.lvl.x, 0);
        row.lvl:SetWidth(cols.lvl.w);
        row.lvl:SetJustifyH("CENTER");
        row.lvl:SetTextColor(unpack(base_color));

        row.type_icon = row:CreateTexture(nil, "ARTWORK");
        row.type_icon:SetSize(mode.type_icon, mode.type_icon);
        row.type_icon:SetPoint("CENTER", row, "LEFT", cols.type.x + cols.type.w/2, 0);
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
        row.cost:SetPoint("LEFT", cols.cost.x, 0);
        row.cost:SetWidth(cols.cost.w);
        row.cost:SetJustifyH("RIGHT");
        row.cost:SetTextColor(unpack(base_color));

        local item = CreateFrame("Frame", nil, row);
        item:SetSize(16, 16);
        item:EnableMouseMotion(true);
        item:SetPoint("RIGHT", row, "LEFT", content_r, 0);
        item:SetScript("OnEnter", function(self)
            hover();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetItemByID(self.item_id);
            GameTooltip:Show();
        end);
        item:SetScript("OnLeave", function()
            hover();
            GameTooltip:Hide();
        end);
        item.tex = item:CreateTexture(nil, "ARTWORK");
        item.tex:SetAllPoints();
        row.item = item;

        local menu_button = create_arrow_button(row, 16);
        menu_button:SetPoint("LEFT", row, "LEFT", content_r + 8, 0);
        menu_button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        -- the row owns the menu, the button hides under it
        menu_button:SetScript("OnClick", function()
            if row.spell_id then
                spell_menu(row, row.spell_id);
            end
        end);
        menu_button:SetScript("OnEnter", hover);
        menu_button:SetScript("OnLeave", hover);
        menu_button:Hide();
        row.menu_button = menu_button;

        -- over the icon, which is on a child frame
        local ignore_f = CreateFrame("Frame", nil, row);
        ignore_f:SetAllPoints();
        ignore_f:SetFrameLevel(area:GetFrameLevel() + 3);
        row.ignore_line = ignore_f:CreateTexture(nil, "OVERLAY");
        row.ignore_line:SetColorTexture(0.62, 0.1, 0.02, 0.8);
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
        btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontBlackMedium");
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
            btn.hl:SetColorTexture(0.35, 0.2, 0.05, 0.15);
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
        divider:SetPoint("TOPLEFT", -32, y);
        divider:SetPoint("TOPRIGHT", -60, y);
        return divider;
    end

    local function create_title(page)
        local backplate = page:CreateTexture(nil, "BACKGROUND");
        backplate:SetAtlas("spellbook-list-backplate");
        backplate:SetSize(416, 106);
        backplate:SetAlpha(0.65);
        backplate:SetPoint("LEFT", page, "TOPLEFT", -85, -51/2 + 10);

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
        page:SetSize(view_w, full_rows_bottom);
        if i == 1 then
            page:SetPoint("TOPLEFT", 85, -45);
            page.header_h = title_header_h;
            page.header_y = -26;
            create_title(page);
        else
            page:SetPoint("TOPRIGHT", -50, -45);
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
            row.item:Hide();
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

        local known = v.trigger == spell_filters.already_known or v.is_dual;
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
            row.name:SetTextColor(0.0, 0.42, 0.0);
        elseif v.trigger == spell_filters.unavailable then
            row.name:SetTextColor(0.62, 0.1, 0.02);
        else
            row.name:SetTextColor(unpack(base_color));
        end

        if by_lvl then
            row.lvl:Hide();
        else
            set_lvl_text(row.lvl, lvl, spell.lvl_req);
            row.lvl:Show();
        end

        row.item:Hide();
        row.cost:Hide();
        if spell.train > 0 then
            if not known then
                row.cost:SetText(C_CurrencyInfo.GetCoinTextureString(spell.train));
                row.cost:Show();
            end
        elseif spell.train < -1 then
            if not known then
                row.item.item_id = -spell.train;
                row.item.tex:SetTexture(C_Item.GetItemIconByID(-spell.train));
                row.item:Show();
            end
        elseif not known then
            if bit.band(spell.flags, spell_flags.talent) ~= 0 then
                row.cost:SetText(L["Talent"]);
            else
                row.cost:SetText(L["Unknown"]);
            end
            row.cost:Show();
        end

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
        footer.avail:SetText("|cFF006B00"..L["Available cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.avail_cost));
        if cat.next_cost ~= 0 then
            set_lvl_colored_text(footer.next_label, lvl, cat.next_lvl, L["Next level"].." "..cat.next_lvl..L[" cost:"]);
        end
        footer.next_amount:SetText(C_CurrencyInfo.GetCoinTextureString(cat.next_cost));
        footer.total:SetText("|cFF9E1A05"..L["Total cost:"].."|r "..C_CurrencyInfo.GetCoinTextureString(cat.total_cost));

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

        local left_x = 85;
        if views ~= 1 then
            left_x = container:GetWidth() - 50 - view_w;
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
                if v.spell_id and lvl <= spells[v.spell_id].lvl_req then
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
        settings:SetupMenu(function(_, root)
            root:CreateTitle(L["Includes"]);
            for _, f in ipairs(spell_filter_listing) do
                local key = cat.filter_prefix..f.id;
                local txt = f.disp;
                if f.id == "available" then
                    txt = "|cFF00FF00"..txt.."|r";
                elseif f.id == "unavailable" then
                    txt = "|cFFFF0000"..txt.."|r";
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
            for k, txt in ipairs(spell_browser_sort_options) do
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
-- state lives in closures, ui.lua is close to the main chunk's 200 locals
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

    local function fit_search_box()
        local search = sb.SearchBox;
        local tab_right = tab:IsShown() and tab:GetRight();
        local search_left, search_right = search:GetLeft(), search:GetRight();
        if tab_right and search_left and search_right and search_left < tab_right + 10 then
            search:SetWidth(math.max(60, search_right - tab_right - 10));
        end
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
        if offset > 0 then
            offset = offset + 2;
        end
        tab:ClearAllPoints();
        -- extra spacing after blizzard's tabs marks the addon tabs, room for another addon's button is kept before ours
        tab:SetPoint("TOPLEFT", tab_row, "TOPRIGHT", offset + 12 + 38, 0);
        fit_search_box();
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
    hooksecurefunc(sb, "ResizeSearchBox", fit_search_box);

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

local function post_login_load()
    -- some things must be done after PLAYER_LOGIN event
    add_spell_book_button();
    add_to_options();
end

--------------------------------------------------------------------------------
ui.font                                 = font;
ui.load_sw_ui                           = load_sw_ui;
ui.create_sw_base_ui                    = create_sw_base_ui;
ui.display_spell_diff                   = display_spell_diff;
ui.update_calc_list                     = update_calc_list;
ui.sw_activate_frame                    = sw_activate_frame;
ui.update_profile_frame                 = update_profile_frame;
ui.update_spells_frame                  = update_spells_frame;
ui.update_spell_catalogues              = update_spell_catalogues;
ui.spell_catalogue_visible              = spell_catalogue_visible;
ui.init_spellbook_tab                   = init_spellbook_tab;
ui.spellbook_tab_undock_sc_frame        = spellbook_tab_undock_sc_frame;
-- fn(icon_frame, spell_id) for the spellbook catalogue's shown icons (non compact mode, forever)
ui.for_each_book_icon                   = function(fn)
    if spellbook_tab.for_each_icon then
        spellbook_tab.for_each_icon(fn);
    end
end;
ui.spells_known_changed                 = spells_known_changed;
ui.post_login_load                      = post_login_load;
ui.forced_buffs_lname_to_id             = forced_buffs_lname_to_id;
ui.get_font                             = get_font;
ui.locale_warning_popup                 = locale_warning_popup;
ui.update_calculator_character_items    = update_calculator_character_items;
ui.effects_from_ui_stats_diff           = effects_from_ui_stats_diff;
ui.update_talents_frame                 = update_talents_frame;
ui.ehp_tex                              = ehp_tex;

sc.ui = ui;
