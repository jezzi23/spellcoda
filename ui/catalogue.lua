local _, sc = ...;

local L                                         = sc.L;
local spells                                    = sc.spells;
local spell_flags                               = sc.spell_flags;
local clear_table                               = sc.utils.clear_table;
local client_matches                            = sc.utils.client_matches;
local client_flags                              = sc.client_flags;
local highest_learned_rank                      = sc.utils.highest_learned_rank;
local format_number                             = sc.utils.format_number;
local color_by_lvl_diff                         = sc.utils.color_by_lvl_diff;
local update_loadout_and_effects_diffed_from_ui = sc.loadouts.update_loadout_and_effects_diffed_from_ui;
local update_loadout_and_effects                = sc.loadouts.update_loadout_and_effects;
local active_loadout                            = sc.loadouts.active_loadout
local calc_spell_eval                           = sc.calc.calc_spell_eval;
local buff_category                             = sc.buffs.buff_category;
local config                                    = sc.config;

local ui = sc.ui;
local compared_spells_changed = ui.compared_spells_changed;

local buff_categories_colors = {
    [buff_category.class]       = {0/255,   204/255, 255/255},
    [buff_category.player]      = {225/255, 235/255, 52/255 },
    [buff_category.enchant]     = {103/255, 52/255,  235/255},
    [buff_category.hostile]     = {235/255, 52/255,  88/255 },
    [buff_category.friendly]    = {0/255,   153/255, 51/255 },
};

local spell_browser_sort_keys = {
    lvl = 1,
    dps = 2,
    hps = 3,
    dpc = 4,
    hpc = 5,
};

-- the first four double as spell_filters triggers
local spell_filter_ids = {
    "already_known",
    "available",
    "unavailable",
    "missing_requirement",
    "innate",
    "weapon_skills",
    "trainer",
    "talent",
    "learned_from_item",
    "pet",
    "other_spells",
    "ignored_spells",
    "hide_replaced_ranks",
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
        if bit.band(spells[id].flags, spell_flags.weapon_skill) ~= 0 then
            known = IsPlayerSpell(id);
        else
            known = IsSpellKnownOrOverridesKnown(id) or IsSpellKnownOrOverridesKnown(id, true);
        end
        if not known and spells[id].train == -1 and spells[id].learned_with then
            for _, summon in ipairs(spells[id].learned_with) do
                known = known or IsPlayerSpell(summon);
            end
        end
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

local function spell_source_included(filters, spell)
    local flags = spell.flags;
    if bit.band(flags, spell_flags.pet) ~= 0 then
        return filters.pet;
    elseif bit.band(flags, spell_flags.weapon_skill) ~= 0 then
        return filters.weapon_skills;
    elseif spell.learned_with and spells[spell.learned_with[1]] then
        return spell_source_included(filters, spells[spell.learned_with[1]]);
    elseif bit.band(flags, spell_flags.talent) ~= 0 then
        return filters.talent;
    elseif spell.train < -1 or bit.band(flags, spell_flags.quest) ~= 0 then
        return filters.learned_from_item;
    elseif spell.train > 0 then
        return filters.trainer;
    elseif spell.train == -1 then
        return filters.innate;
    end
    return filters.other_spells;
end

-- true: a talent point, id: a talent or rank, list: one of these spells, false: nothing missing
local function missing_requirement(spell)
    if spell.learned_with then
        for _, skill in ipairs(spell.learned_with) do
            if IsPlayerSpell(skill) then
                return false;
            end
        end
        return spell.learned_with;
    end
    if spell.requires then
        local known = false;
        for _, id in ipairs(spell.requires) do
            known = known or spell_known(id);
        end
        if not known then
            return spell.requires;
        end
    end
    if spell.rank < 2 then
        return bit.band(spell.flags, spell_flags.talent) ~= 0;
    end
    local ranks = sc.rank_seqs[spell.base_id];
    local needed;
    if client_matches(client_flags.forever) then
        needed = ranks[spell.rank - 1];
    elseif bit.band(spell.flags, spell_flags.talent) ~= 0 then
        needed = ranks[1];
    end
    if needed and not spell_known(needed) then
        return needed;
    end
    return false;
end

local training = {
    -- faction id -> percent off
    pct = {},
    -- spell id -> trainers of the player's side: {faction = id} or a weapon master
    sources = {},
    beast_training_id = 5149,
    quest_texture = "Interface\\GossipFrame\\AvailableQuestIcon",
};

function training.show_quest_hint(owner, anchor)
    GameTooltip:SetOwner(owner, anchor);
    GameTooltip:SetText(L["Quest reward"]);
    GameTooltip:Show();
end

function training.tamed(spell)
    return sc.class == sc.classes.hunter and (spell.train == 0 or spell.train == -1) and
        bit.band(spell.flags, spell_flags.pet) ~= 0;
end

function training.taming_hint(spell_id)
    local spell = spells[spell_id];
    if spell_known(spell_id) or missing_requirement(spell) then
        return false;
    end
    local first = sc.rank_seqs[spell.base_id][1];
    return first == spell_id or not spell_known(first);
end

function training.widest_cell_w(measure, icon_w)
    local w, has_book = 0, false;
    local function fit(str)
        measure:SetText(str);
        w = math.max(w, math.ceil(measure:GetUnboundedStringWidth()));
    end
    fit(L["Talent"]);
    fit(L["Unknown"]);
    local measured = {};
    for _, spell in pairs(spells) do
        if not spell.race_flags or bit.band(spell.race_flags, bit.lshift(1, sc.race-1)) ~= 0 then
            has_book = has_book or spell.book_price ~= nil;
            local base = training.base_price(spell);
            if base > 0 then
                for _, pct in pairs(sc.rep_discount_pct) do
                    local cost = math.floor(base * (100 - pct) / 100 + 0.5);
                    if not measured[cost] then
                        measured[cost] = true;
                        fit(C_CurrencyInfo.GetCoinTextureString(cost));
                    end
                end
                if not measured[base] then
                    measured[base] = true;
                    fit(C_CurrencyInfo.GetCoinTextureString(base));
                end
            end
        end
    end
    measure:SetText("! ");
    w = w + math.ceil(measure:GetUnboundedStringWidth());
    return has_book and w + icon_w or w;
end

function training.place_cell(text, icon, mark, at)
    local left;
    if text:IsShown() and text:GetText() ~= "" then
        text:ClearAllPoints();
        at(text);
        left = text;
    end
    if icon:IsShown() then
        icon:ClearAllPoints();
        if left then
            icon:SetPoint("RIGHT", left, "LEFT", -2, 0);
        else
            at(icon);
        end
        left = icon;
    end
    if mark:IsShown() then
        mark:ClearAllPoints();
        if left then
            mark:SetPoint("RIGHT", left, "LEFT", -2, 0);
        else
            at(mark);
        end
    end
end

function training.show_taming_hint(owner, spell_id, anchor)
    if training.taming_hint(spell_id) then
        GameTooltip:SetOwner(owner, anchor);
        GameTooltip:SetText(L["Unlocked by taming a beast that knows it"]);
        GameTooltip:Show();
    end
end

function training.faction_pct(id)
    local pct = training.pct[id];
    if not pct then
        local _, standing = sc.utils.faction_standing(id);
        pct = standing and sc.rep_discount_pct[standing] or 0;
        training.pct[id] = pct;
    end
    return pct;
end

function training.trainers(spell_id)
    local list = training.sources[spell_id];
    if list then
        return list;
    end
    list = {};
    local spell = spells[spell_id];
    if bit.band(spell.flags, spell_flags.weapon_skill) ~= 0 then
        for _, m in ipairs(sc.weapon_masters) do
            if m.side == sc.faction then
                for _, skill in ipairs(m.skills) do
                    if skill == spell_id then
                        table.insert(list, m);
                    end
                end
            end
        end
    elseif spell.trainer_faction then
        table.insert(list, {faction = spell.trainer_faction});
    elseif not (spell.book_price and client_matches(client_flags.forever)) then
        local role = sc.class;
        if bit.band(spell.flags, spell_flags.pet) ~= 0 and sc.class == sc.classes.hunter then
            role = "PET";
        end
        for _, t in ipairs(sc.trainer_factions) do
            if t.role == role and t.side == sc.faction then
                for _, f in ipairs(t.factions) do
                    table.insert(list, {faction = f});
                end
                for _, p in ipairs(t.places) do
                    table.insert(list, p);
                end
            end
        end
    end
    training.sources[spell_id] = list;
    return list;
end

function training.price_at(cost, faction)
    return math.floor(cost * (100 - training.faction_pct(faction)) / 100 + 0.5);
end

function training.base_price(spell)
    if spell.train > 0 then
        return spell.train;
    end
    return spell.book_price or 0;
end

function training.cheapest(spell_id)
    local cost = training.base_price(spells[spell_id]);
    local best = cost;
    for _, t in ipairs(training.trainers(spell_id)) do
        best = math.min(best, training.price_at(cost, t.faction));
    end
    return best;
end

function training.price_str(spell_id, discount_code)
    local cost = training.cheapest(spell_id);
    local str = C_CurrencyInfo.GetCoinTextureString(cost);
    if cost < training.base_price(spells[spell_id]) then
        str = discount_code..str.."|r";
    end
    return str;
end

function training.row_cmp(lhs, rhs)
    if lhs.price ~= rhs.price then
        return lhs.price < rhs.price;
    end
    return lhs.where < rhs.where;
end

function training.spell_title(spell_id)
    if spells[spell_id].rank ~= 0 then
        return string.format("%s ("..L["Rank"].." %d)", C_Spell.GetSpellName(spell_id), spells[spell_id].rank);
    end
    return C_Spell.GetSpellName(spell_id);
end

function training.show_tooltip(owner, spell_id, anchor)
    local spell = spells[spell_id];
    GameTooltip:SetOwner(owner, anchor);
    GameTooltip:SetText(training.spell_title(spell_id));
    local needed = not spell_known(spell_id) and missing_requirement(spell);
    if needed == true then
        GameTooltip:AddLine(L["Requires a talent point"], 0.8, 0.6, 1);
    elseif type(needed) == "table" then
        local skills = {};
        for i, skill in ipairs(needed) do
            skills[i] = spells[skill] and training.spell_title(skill) or C_Spell.GetSpellName(skill);
        end
        GameTooltip:AddLine(L["Requires"].." "..table.concat(skills, " / "), 0.8, 0.6, 1);
    elseif needed then
        GameTooltip:AddLine(L["Requires"].." "..training.spell_title(needed), 0.8, 0.6, 1);
    end
    local base = training.base_price(spell);
    if base > 0 then
        local rows = {};
        for _, t in ipairs(training.trainers(spell_id)) do
            local faction, standing = sc.utils.faction_standing(t.faction);
            if faction then
                local where = faction.." (".._G["FACTION_STANDING_LABEL"..standing]..")";
                if t.area then
                    where = (C_Map.GetAreaInfo(t.area) or "").." ("..faction..", ".._G["FACTION_STANDING_LABEL"..standing]..")";
                    if t.name then
                        where = t.name..", "..where;
                    end
                end
                table.insert(rows, {where = where, price = training.price_at(base, t.faction)});
            end
        end
        table.sort(rows, training.row_cmp);
        for _, r in ipairs(rows) do
            GameTooltip:AddDoubleLine(r.where, C_CurrencyInfo.GetCoinTextureString(r.price), 1, 1, 1, 1, 1, 1);
        end
        GameTooltip:AddDoubleLine(L["Base price"], C_CurrencyInfo.GetCoinTextureString(base), 0.6, 0.6, 0.6, 1, 1, 1);
    end
    GameTooltip:Show();
end

local function spell_view_trigger(filters, id, lvl, name_filter)
    local spell = spells[id];

    if name_filter ~= "" and not string.find(spell_lower_name(id), name_filter, 1, true) then
        return nil;
    end
    local known = spell_known(id);
    local trigger;
    if known then
        if not filters.already_known then
            return nil;
        end
        trigger = spell_filters.already_known;
    elseif lvl < (spell.lvl_learn or spell.lvl_req) then
        if not filters.unavailable then
            return nil;
        end
        trigger = spell_filters.unavailable;
    elseif missing_requirement(spell) then
        if not filters.missing_requirement then
            return nil;
        end
        trigger = spell_filters.missing_requirement;
    elseif filters.available then
        trigger = spell_filters.available;
    else
        return nil;
    end

    if not spell_source_included(filters, spell) then
        return nil;
    end
    if not filters.ignored_spells and config.settings.spells_ignore_list[id] then
        return nil;
    end
    if filters.hide_replaced_ranks and known then
        local highest = cached_highest_learned_rank(spell.base_id);
        if highest and spells[highest] and spells[highest].rank > spell.rank then
            return nil;
        end
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
    clear_table(training.pct);

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
            if training.base_price(spell) > 0 then
                local price = training.cheapest(id);
                if (spell.lvl_learn or spell.lvl_req) == next_lvl then
                    next_cost = next_cost + price;
                end
                if trigger == spell_filters.available then
                    avail_cost = avail_cost + price;
                end
                if trigger ~= spell_filters.already_known then
                    total_cost = total_cost + price;
                end
            end
            local spell_lvl = spell.lvl_learn or spell.lvl_req;
            if by_lvl and spell_lvl ~= prev_lvl then
                n = n + 1;
                spell_view_entry(cat, n).lvl_barrier = spell_lvl;
                prev_lvl = spell_lvl;
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
            local known = v.trigger == spell_filters.already_known;
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
            elseif v.trigger == spell_filters.missing_requirement then
                line.spell_name:SetTextColor(0.8, 0.6, 1);
            end
            line.spell_name:Show();
            -- do level per line if not sorting by lvl
            if not by_lvl then
                local spell_lvl = spells[v.spell_id].lvl_learn or spells[v.spell_id].lvl_req;
                line.lvl_str:SetText(color_by_lvl_diff(lvl, spell_lvl)..spell_lvl);
                line.lvl_str:Show();
            end
            -- write in currency/book cost column
            local unlearned = v.trigger ~= spell_filters.already_known and not v.is_dual;
            local mark = "";
            if v.trigger == spell_filters.unavailable and missing_requirement(spells[v.spell_id]) then
                mark = "|cFFCC99FF!|r";
            end
            local book_price = spells[v.spell_id].train < -1 and spells[v.spell_id].book_price;
            if unlearned and (book_price or spells[v.spell_id].train >= -1 and
                (spells[v.spell_id].train > 0 or missing_requirement(spells[v.spell_id]))) then
                line.cost_area.__id = v.spell_id;
                line.cost_area:Show();
            end
            line.book_icon.__id = nil;
            line.book_icon.__taming = nil;
            line.book_icon.__req = nil;
            line.book_icon.__quest = nil;
            if spells[v.spell_id].train > 0 then
                if unlearned then
                    line.cost_str:SetText(training.price_str(v.spell_id, "|cFF66FF66"));
                else
                    line.cost_str:SetText("");
                end
                line.cost_str:Show();
            elseif spells[v.spell_id].train < -1 then
                if v.trigger == spell_filters.already_known or v.is_dual then
                else
                    line.book_icon.__id = -spells[v.spell_id].train;
                    line.book_tex:SetTexture(C_Item.GetItemIconByID(-spells[v.spell_id].train));
                    line.book_tex:Show();
                    line.book_icon:Show();
                    if book_price then
                        line.cost_str:SetText(training.price_str(v.spell_id, "|cFF66FF66"));
                        line.cost_str:Show();
                    end
                end
            else
                if v.trigger == spell_filters.already_known or v.is_dual then
                elseif bit.band(spells[v.spell_id].flags, spell_flags.talent) ~= 0 then
                    line.cost_str:SetText(L["Talent"]);
                    line.cost_str:Show();
                elseif training.tamed(spells[v.spell_id]) then
                    line.book_icon.__taming = v.spell_id;
                    line.book_tex:SetTexture((C_Spell.GetSpellTexture(training.beast_training_id)));
                    line.book_tex:Show();
                    line.book_icon:Show();
                elseif bit.band(spells[v.spell_id].flags, spell_flags.quest) ~= 0 then
                    line.book_icon.__quest = true;
                    line.book_tex:SetTexture(training.quest_texture);
                    line.book_tex:Show();
                    line.book_icon:Show();
                elseif spells[v.spell_id].learned_with then
                    line.book_icon.__req = v.spell_id;
                    line.book_tex:SetTexture((C_Spell.GetSpellTexture(spells[v.spell_id].learned_with[1])));
                    line.book_tex:Show();
                    line.book_icon:Show();
                else
                    line.cost_str:SetText(L["Unknown"]);
                    line.cost_str:Show();
                end
            end
            if mark ~= "" then
                line.mark_str:SetText(mark);
                line.mark_str:Show();
            end
            training.place_cell(line.cost_str, line.book_icon, line.mark_str, line.cost_str.acquisition_at);
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
    frame.update_headers(cat.sort_key);

    frame.slider:SetMinMaxValues(
        1,
        math.max(1, #view - math.floor(#frame.scroll_view/2))
    );
    if spell_browser_scroll_to_lvl then
        local suitable_idx = 1;
        local lvl = active_loadout().lvl;
        for k, v in pairs(view) do
            if v.spell_id and lvl <= (spells[v.spell_id].lvl_learn or spells[v.spell_id].lvl_req) then
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

local function spell_ignore_text(id)
    if config.settings.spells_ignore_list[id] then
        return "|cFFFF4040"..L["Unignore spell"].."|r";
    end
    return "|cFFFF4040"..L["Ignore spell"].."|r";
end

local function toggle_spell_ignored(id)
    if config.settings.spells_ignore_list[id] then
        config.settings.spells_ignore_list[id] = nil;
    else
        config.settings.spells_ignore_list[id] = 1;
    end
    update_spell_catalogues(nil, nil, nil, true);
end

-- the row menu of both catalogues in one layout for every spell, false is a space; disabled entries stay greyed
local function spell_menu_entries(id, open_compared_list)
    local comparable = bit.band(spells[id].flags, bit.bor(spell_flags.eval, spell_flags.ehp)) ~= 0;
    local compared = comparable and config.compared_spells_contains(id);
    return {
        {
            text = L["Add to compared spells list"],
            enabled = comparable and not compared,
            func = function()
                config.add_compared_spell(id);
                compared_spells_changed();
            end,
        },
        {
            text = L["Remove from compared spells list"],
            enabled = compared,
            func = function()
                config.remove_compared_spell(id);
                compared_spells_changed();
            end,
        },
        false,
        {
            text = L["Edit compared spells list"],
            enabled = true,
            func = function()
                open_compared_list();
            end,
        },
        false,
        {
            text = spell_ignore_text(id),
            enabled = true,
            func = function()
                toggle_spell_ignored(id);
            end,
        },
    };
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

ui.buff_categories_colors         = buff_categories_colors;
ui.create_arrow_button            = create_arrow_button;
ui.ehp_tex                        = ehp_tex;
ui.eval_spell_view_entry          = eval_spell_view_entry;
ui.missing_requirement            = missing_requirement;
ui.new_spell_catalogue            = new_spell_catalogue;
ui.pickup_known_spell             = pickup_known_spell;
ui.populate_scrollable_spell_view = populate_scrollable_spell_view;
ui.spell_browser_sort_keys        = spell_browser_sort_keys;
ui.spell_catalogue_visible        = spell_catalogue_visible;
ui.spell_filters                  = spell_filters;
ui.spell_menu_entries             = spell_menu_entries;
ui.spells_catalogue               = spells_catalogue;
ui.spells_known_changed           = spells_known_changed;
ui.training                       = training;
ui.update_spell_catalogue         = update_spell_catalogue;
ui.update_spell_catalogues        = update_spell_catalogues;
ui.update_spells_frame            = update_spells_frame;
