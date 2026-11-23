local _, sc = ...;

local L              = sc.L;
local client_matches = sc.utils.client_matches;
local client_flags   = sc.client_flags;
local fight_types    = sc.calc.fight_types;
local config         = sc.config;

local ui = sc.ui;
local create_buffs_list      = ui.create_buffs_list;
local create_subtabs         = ui.create_subtabs;
local editbox_config         = ui.editbox_config;
local font                   = ui.font;
local libDD                  = ui.libDD;
local make_help_icon_tooltip = ui.make_help_icon_tooltip;
local update_buffs_frame     = ui.update_buffs_frame;

local function create_sw_ui_loadout_frame(pframe)
    local f, f_txt;
    local has_resilience = bit.bnot(bit.bor(client_flags.vanilla, client_flags.forever));

    pframe.y_offset = pframe.y_offset - 5;
    local x_pad = 5;

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(GameFontNormal);
    f_txt:SetPoint("TOPLEFT", 0, pframe.y_offset);
    f_txt:SetText(L["Spell calculation parameters"]);
    f_txt:SetTextColor(232.0/255, 225.0/255, 32.0/255);

    f_txt = pframe:CreateFontString(nil, "OVERLAY");
    f_txt:SetFontObject(font);
    f_txt:SetPoint("TOPRIGHT", 0, pframe.y_offset-1);
    f_txt:SetText(L["Active profile: "]);
    pframe.profile_name_label = f_txt;

    pframe.y_offset = pframe.y_offset - 40;

    local tab_frame = pframe;
    create_subtabs(tab_frame, {
        {"general", L["Loadout"]},
        {"buffs", L["Buffs"]},
    });

    pframe = tab_frame.general;
    pframe.y_offset = pframe.y_offset - 5;

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
        L["Displays ability information as if the character were this level."];

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

    if sc.pet_families then
        pframe.y_offset = pframe.y_offset - 25;

        f_txt = pframe:CreateFontString(nil, "OVERLAY");
        f_txt:SetFontObject(GameFontNormal);
        f_txt:SetPoint("TOPLEFT", pframe, x_pad+5, pframe.y_offset);
        f_txt:SetText(L["Default pet when none is out:"]);
        f_txt:SetTextColor(1.0,  1.0,  1.0);

        local function family_name(id)
            if id == 0 then
                return L["None"];
            end
            local info = C_CreatureInfo.GetCreatureFamilyInfo(id);
            local name = info and info.name or tostring(id);
            for alias, same_as in pairs(sc.pet_family_alias or {}) do
                local alias_info = same_as == id and C_CreatureInfo.GetCreatureFamilyInfo(alias);
                if alias_info then
                    name = name .. " / " .. alias_info.name;
                end
            end
            return name;
        end
        local families = {};
        for _, id in ipairs(sc.pet_families) do
            if C_CreatureInfo.GetCreatureFamilyInfo(id) then
                families[#families + 1] = id;
            end
        end
        table.sort(families, function(a, b) return family_name(a) < family_name(b); end);
        table.insert(families, 1, 0);

        local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_loadout_assumed_pet", pframe);
        dd._type = "DropDownMenu";
        dd:SetPoint("LEFT", f_txt, "RIGHT", -5, -3);
        libDD:UIDropDownMenu_SetWidth(dd, 130);
        dd.init_func = function()
            libDD:UIDropDownMenu_SetText(dd, family_name(config.settings.loadout_assumed_pet[sc.class] or 0));
        end;
        libDD:UIDropDownMenu_SetInitializeFunction(dd, function()
            local current = config.settings.loadout_assumed_pet[sc.class] or 0;
            for _, id in ipairs(families) do
                libDD:UIDropDownMenu_AddButton({
                        text = family_name(id),
                        checked = current == id,
                        func = function()
                            sc.loadouts.force_update = true;
                            config.settings.loadout_assumed_pet[sc.class] = id ~= 0 and id or nil;
                            tab_frame.update_indicators();
                            libDD:UIDropDownMenu_SetText(dd, family_name(id));
                        end
                    }
                );
            end
        end);
        dd.init_func();

        local help_icon = make_help_icon_tooltip(nil, pframe, L["Pet effects use this pet while none is summoned"]);
        help_icon:SetPoint("LEFT", dd, "RIGHT", 0, 3);
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
            self:SetText(""..config.settings.loadout_default_target_hp_perc);
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
        if config.settings.loadout_default_target_creature_type == 0 then
            libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, L["None"]);
        end
        for lname, id in pairs(sc.creature_lname_to_id) do
            if config.settings.loadout_default_target_creature_type == id then
                libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, lname);
            end
        end
    end;
    libDD:UIDropDownMenu_SetInitializeFunction(pframe.creature_type_dd, function()
        libDD:UIDropDownMenu_AddButton({
                text = L["None"],
                checked = config.settings.loadout_default_target_creature_type == 0,
                func = function()
                    sc.loadouts.force_update = true;
                    config.settings.loadout_default_target_creature_type = 0;
                    tab_frame.update_indicators();

                    libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, L["None"]);
                end
            }
        );
        for lname, id in pairs(sc.creature_lname_to_id) do
            libDD:UIDropDownMenu_AddButton({
                    text = lname,
                    checked = config.settings.loadout_default_target_creature_type == id,
                    func = function()
                        sc.loadouts.force_update = true;
                        config.settings.loadout_default_target_creature_type = id;
                        config.settings.calc_fight_type = fight_types.repeated_casts;
                        tab_frame.update_indicators();

                        libDD:UIDropDownMenu_SetText(pframe.creature_type_dd, lname);
                    end
                }
            );
        end
    end);
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

    if client_matches(has_resilience) then
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
    end


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

    local bf = tab_frame.buffs;
    bf.buffs_cfg = function()
        return config.settings.loadout_assumed_buffs;
    end;
    bf.list_enabled = function()
        return config.settings.loadout_assume_buffs;
    end;
    bf.on_update = function()
        tab_frame.update_indicators();
    end;
    bf.list_height = 410;
    bf.name_prefix = "__sc_frame_assumed_buffs_";
    bf.on_show = function()
        bf.refresh();
    end;

    bf.y_offset = bf.y_offset - 5;

    if client_matches(client_flags.forever) then
        f_txt = bf:CreateFontString(nil, "OVERLAY");
        f_txt:SetFontObject(GameFontNormal);
        f_txt:SetPoint("TOPLEFT", bf, 5, bf.y_offset - 3);
        f_txt:SetText(L["Buffs in combat handling"]);
        f_txt:SetTextColor(1.0, 1.0, 1.0);

        local unseen = config.combat_unseen_buffs;
        local unseen_options = {
            { unseen.keep, L["Keep from combat start"], L["Buffs up when combat starts count for the whole fight."] },
            { unseen.expire, L["Keep until they expire"],
                L["Buffs up when combat starts count until they run out. Your own casts on yourself refresh them."] },
            { unseen.drop, L["Drop"], L["Buffs do not count in combat, except shapeshift forms."] },
        };
        local dd = libDD:Create_UIDropDownMenu("__sc_frame_setting_loadout_combat_unseen_buffs", bf);
        dd._type = "DropDownMenu";
        dd:SetPoint("LEFT", f_txt, "RIGHT", -5, -3);
        libDD:UIDropDownMenu_SetWidth(dd, 170);
        dd.init_func = function()
            for _, v in ipairs(unseen_options) do
                if config.settings.loadout_combat_unseen_buffs == v[1] then
                    libDD:UIDropDownMenu_SetText(dd, v[2]);
                end
            end
        end;
        libDD:UIDropDownMenu_SetInitializeFunction(dd, function()
            for _, v in ipairs(unseen_options) do
                libDD:UIDropDownMenu_AddButton({
                        text = v[2],
                        checked = config.settings.loadout_combat_unseen_buffs == v[1],
                        tooltipTitle = v[2],
                        tooltipText = v[3],
                        tooltipOnButton = true,
                        func = function()
                            sc.loadouts.force_update = true;
                            config.settings.loadout_combat_unseen_buffs = v[1];
                            tab_frame.update_indicators();
                            libDD:UIDropDownMenu_SetText(dd, v[2]);
                        end
                    }
                );
            end
        end);
        dd.init_func();

        local help_icon = make_help_icon_tooltip(nil, bf, L["Most buffs cannot be read while in combat"],
            L["Buffs tracked in Blizzard's Cooldown Manager are still followed."]);
        help_icon:SetPoint("LEFT", dd, "RIGHT", 0, 3);

        bf.y_offset = bf.y_offset - 30;
        bf.list_height = bf.list_height - 30;
    end

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_assume_buffs", bf, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", bf, 0, bf.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Always assume selected buffs"]);
    getglobal(f:GetName()).tooltip =
        L["Treats the selected buffs as active."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.settings.loadout_assume_buffs = self:GetChecked();
        update_buffs_frame(bf);
    end);
    bf.legend_y_offset = bf.y_offset - 8;

    bf.y_offset = bf.y_offset - 25;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_assume_buffs_only_combat", bf, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", bf, 0, bf.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Only in combat"]);
    getglobal(f:GetName()).tooltip =
        L["Treats them as active only while in combat."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.settings.loadout_assume_buffs_only_combat = self:GetChecked();
    end);
    local only_combat_btn = f;

    f = CreateFrame("CheckButton", "__sc_frame_setting_loadout_assume_buffs_only_raid", bf, "ChatConfigCheckButtonTemplate");
    f._type = "CheckButton";
    f:SetPoint("TOPLEFT", bf, 173, bf.y_offset);
    getglobal(f:GetName()..'Text'):SetText(L["Only in raid"]);
    getglobal(f:GetName()).tooltip =
        L["Treats them as active only inside raid instances."];
    f:SetScript("OnClick", function(self)
        sc.loadouts.force_update = true;
        config.settings.loadout_assume_buffs_only_raid = self:GetChecked();
    end);
    local only_raid_btn = f;

    bf.y_offset = bf.y_offset - 25;

    create_buffs_list(bf);
    bf.fadeable_checkboxes[#bf.fadeable_checkboxes + 1] = only_combat_btn;
    bf.fadeable_checkboxes[#bf.fadeable_checkboxes + 1] = only_raid_btn;

    -- settings that change results from the defaults, the armor estimate shares count only while estimating
    local result_keys = {
        "loadout_use_custom_lvl", "loadout_always_max_resource", "loadout_target_automatic_armor",
        "loadout_behind_target", "loadout_default_target_lvl_diff", "loadout_default_target_hp_perc",
        "loadout_default_target_creature_type", "loadout_target_res",
        "loadout_unbounded_aoe_targets",
    };
    if client_matches(has_resilience) then
        result_keys[#result_keys + 1] = "loadout_target_pvpres";
    end
    local armor_estimate_keys = {
        "loadout_target_automatic_armor_heavy", "loadout_target_automatic_armor_medium",
        "loadout_target_automatic_armor_light",
    };
    tab_frame.update_indicators = function()
        local settings = config.settings;
        local defaults = config.default_settings;
        local changed = (settings.loadout_assumed_pet[sc.class] or 0) ~= 0;
        for _, k in ipairs(result_keys) do
            if settings[k] ~= defaults[k] then
                changed = true;
            end
        end
        if settings.loadout_target_automatic_armor then
            for _, k in ipairs(armor_estimate_keys) do
                if settings[k] ~= defaults[k] then
                    changed = true;
                end
            end
        end
        tab_frame.general_tab:set_changed(changed);

        local assumed = settings.loadout_assumed_buffs;
        tab_frame.buffs_tab:set_changed(settings.loadout_assume_buffs and
            (next(assumed.player_buffs) ~= nil or next(assumed.target_buffs) ~= nil) or
            client_matches(client_flags.forever) and
            settings.loadout_combat_unseen_buffs ~= defaults.loadout_combat_unseen_buffs or false);
    end;
    local refresh_indicators = function()
        tab_frame.update_indicators();
    end;
    for _, keys in ipairs({result_keys, armor_estimate_keys}) do
        for _, k in ipairs(keys) do
            local w = getglobal("__sc_frame_setting_"..k);
            if w and w._type == "CheckButton" then
                w:HookScript("OnClick", refresh_indicators);
            elseif w and w._type == "EditBox" then
                w:HookScript("OnTextChanged", refresh_indicators);
            end
        end
    end

    tab_frame:HookScript("OnShow", function()
        if bf:IsShown() then
            bf.refresh();
        end
    end);
    tab_frame.general_tab:Click();
end

ui.create_sw_ui_loadout_frame = create_sw_ui_loadout_frame;
