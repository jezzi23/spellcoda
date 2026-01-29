local _, sc = ...;

local L                                     = sc.L;

local spells                                = sc.spells;
local spell_flags                           = sc.spell_flags;

local load_localization                     = sc.loc.load_localization;

local load_sw_ui                            = sc.ui.load_sw_ui;
local create_sw_base_ui                     = sc.ui.create_sw_base_ui;
local sw_activate_frame                     = sc.ui.sw_activate_frame;
local update_profile_frame                  = sc.ui.update_profile_frame;
local locale_warning_popup                  = sc.ui.locale_warning_popup;
local update_calculator_character_items     = sc.ui.update_calculator_character_items;
local update_talents_frame                  = sc.ui.update_talents_frame;

local config                                = sc.config;
local load_config                           = sc.config.load_config;
local save_config                           = sc.config.save_config;
local set_active_settings                   = sc.config.set_active_settings;
local set_active_loadout                    = sc.config.set_active_loadout;
local activate_settings                     = sc.config.activate_settings;

local reassign_overlay_icon                 = sc.overlay.reassign_overlay_icon;
local update_overlay                        = sc.overlay.update_overlay;
local spell_tracking                        = sc.overlay.spell_tracking;

local update_tooltip                        = sc.tooltip.update_tooltip;
local write_spell_tooltip                   = sc.tooltip.write_spell_tooltip;
local write_item_tooltip                    = sc.tooltip.write_item_tooltip;
local on_clear_tooltip                      = sc.tooltip.on_clear_tooltip;
local on_show_tooltip                       = sc.tooltip.on_show_tooltip;

-------------------------------------------------------------------------
local core                      = {};
sc.core                         = core;

core.addon_name                 = "SpellCoda";

local version_major             = 0;
local version_minor             = 7;
local version_build             = sc.addon_build_id;

core.version_id                 = version_build + version_minor*1000 + version_major*1000000;
core.version                    = tostring(version_major) .. "." ..
                                  tostring(version_minor) .. "." ..
                                  tostring(version_build);

core.sw_addon_loaded            = false;

sc.sequence_counter             = 0;
core.addon_running_time         = 0;
core.active_spec                = 1;
core.doing_raid                 = false;
core.mute_overlay               = false;

core.talents_update_needed      = true;
core.equipment_update_needed    = true;
core.special_action_bar_changed = true;
core.setup_action_bar_needed    = true;
core.update_action_bar_needed   = false;
core.old_ranks_checks_needed    = true;
core.rescan_action_bar_needed   = false;

local function generated_data_is_outdated(loaded_version, gen_version)
    local loaded = string.gmatch(loaded_version, "[^.]+");
    local gen = string.gmatch(gen_version, "[^.]+");
    for _ = 1, 4 do
        local l = loaded();
        local g = gen();
        if l and g then
            local l_num = tonumber(l);
            local g_num = tonumber(g);
            if g_num < l_num then
                return true;
            end
        end
    end
    return false;
end

local function client_age_days()
    local months = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
        Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
    };

    local client_month_str, client_day, client_year = sc.client_date_loaded:match("(%a+)%s+(%d+)%s+(%d+)");
    local month_str, day, year = date("%b %d %Y"):match("(%a+)%s+(%d+)%s+(%d+)");

    if not client_month_str or not client_day or not client_year or not month_str or not day or not year then
        return 0;
    end
    local client_month = months[client_month_str] or 1;
    local month = months[month_str] or 1;

    local client_build_time = time({year = tonumber(client_year), month = client_month, day = tonumber(client_day)});
    local now = time({year = tonumber(year), month = month, day = tonumber(day)});

    local diff_seconds = math.abs(now - client_build_time);
    local diff_days = diff_seconds / 86400;

    return diff_days;
end


local function doing_raid_update()
    local in_instance, instance_type = IsInInstance();
    sc.core.doing_raid = in_instance and (instance_type == "pvp" or (IsInRaid() and instance_type == "raid"));
    local should_mute_overlay = config.settings.overlay_disable_in_raid and sc.core.doing_raid;
    if not sc.core.mute_overlay and should_mute_overlay then
        sc.overlay.clear_overlays();
        sc.core.old_ranks_checks_needed = true;
    end
    sc.core.mute_overlay = should_mute_overlay;
end
core.doing_raid_update = doing_raid_update;

local timestamp = 0.0;
local pname = UnitName("player");

local function main_update()
    local dt = 1.0 / sc.config.settings.overlay_update_freq;

    local t = GetTime();

    local t_elapsed = t - timestamp;

    core.addon_running_time = core.addon_running_time + t_elapsed;

    spell_tracking(t_elapsed);

    update_overlay();

    sc.sequence_counter = sc.sequence_counter + 1;
    timestamp = t;

    C_Timer.After(dt, main_update);
end

local function key_mod_flags()

    local mod = 0;
    if IsAltKeyDown() then
        mod = bit.bor(mod, sc.tooltip_mod_flags.ALT);
    end
    if IsControlKeyDown() then
        mod = bit.bor(mod, sc.tooltip_mod_flags.CTRL);
    end
    if IsShiftKeyDown() then
        mod = bit.bor(mod, sc.tooltip_mod_flags.SHIFT);
    end
    mod = bit.bor(mod, bit.lshift(sc.tooltip.eval_mode, 3));

    return mod;
end

local tooltip_timestamp = 0.0;
sc.tooltip_mod = 0;
sc.tooltip_mod_flags = {
    ALT =   bit.lshift(1, 0),
    CTRL =  bit.lshift(1, 1),
    SHIFT = bit.lshift(1, 2),
};

local tooltip_time = 1.0/2.0;

local function refresh_tooltip()
    local dt = 0.1;

    local spells_frame_open = false;
    local calc_frame_open = false;
    if __sc_frame:IsShown() then
        spells_frame_open = __sc_frame.spells_frame:IsShown();
        calc_frame_open = __sc_frame.calculator_frame:IsShown();
    end

    if config.settings.overlay_disable or sc.core.mute_overlay then
        -- overlay is off, trigger updates which may exit early if nothing changed
        if calc_frame_open then
            sc.ui.update_calc_list(false);
        elseif spells_frame_open then
            sc.ui.update_spells_frame();
        end
    elseif calc_frame_open and __sc_frame.calculator_frame.calculator_plan_changed then
        -- lower response time of calc updates when plan changed
        sc.ui.update_calc_list(false);
    end

    if config.settings.tooltip_disable then

        C_Timer.After(dt, refresh_tooltip);
        return;
    end
    local mod = key_mod_flags();
    if __spellcoda_test_all_spells__ then
        dt = 0.01;
        sc.tooltip_mod = mod;
        update_tooltip(GameTooltip, true);
    else
        local t = GetTime();
        local t_elapsed = t - tooltip_timestamp;
        if t_elapsed > tooltip_time or sc.tooltip_mod ~= mod then
            update_tooltip(GameTooltip, sc.tooltip_mod ~= mod);
            sc.tooltip_mod = mod;
            tooltip_timestamp = t;
        end
    end

    C_Timer.After(dt, refresh_tooltip);
end

local event_dispatch = {
    ["ADDON_LOADED"] = function(_, arg)
        if arg == "SpellCoda" then
            load_config();
            load_localization();
        end
    end,
    ["PLAYER_LOGOUT"] = function()
        save_config();
    end,
    ["PLAYER_LOGIN"] = function()

        local login_grace_period = 10;
        core.login_grace_time = GetTime() + login_grace_period;

        -- initialize tables with localized strings
        sc.loadouts.init_lnames();
        sc.overlay.init_label_handler();
        sc.overlay.init_ccfs();
        core.active_spec = GetActiveTalentGroup();
        set_active_settings();
        load_sw_ui();
        activate_settings();
        update_profile_frame();

        -- force setup action bar to hook scroll script
        -- even if overlays are disabled
        sc.overlay.setup_action_bars();
        core.sw_addon_loaded = true;
        table.insert(UISpecialFrames, __sc_frame:GetName()) -- Allows ESC to close frame
        if sc.expansion == sc.expansions.vanilla and C_Engraving.IsEngravingEnabled then
            --after fresh login the runes cannot be queried until
            --character frame has been opened!!!

            if CharacterFrame then
                ShowUIPanel(CharacterFrame);
                if CharacterFrameTab1 then
                    CharacterFrameTab1:Click();
                end
                HideUIPanel(CharacterFrame);
            end
        end
        sc.ui.post_login_load();
        sc.buffs.post_login_load();
        if __spellcoda_debug__ or __spellcoda_test_all_data__ or __spellcoda_test_all_spells__ then
            print("WARNING: SC DEBUG TOOLS ARE ON!!!");
            for _ = 1, 10 do
                print("WARNING: SC DEBUG TOOLS ARE ON!!!");
            end
            local num_spells = 0;
            for _, _ in pairs(sc.spells) do
                num_spells = num_spells + 1;
            end
            print("Spells in data:", num_spells);
        end
        -- don't warn about updates when build is relatively fresh
        local version_warning_build_threshold_days = 14;
        if __spellcoda_debug__ then
            version_warning_build_threshold_days = 0;
        end
        if config.settings.general_version_mismatch_notify and
            generated_data_is_outdated(sc.client_version_loaded, sc.client_version_src) and
            client_age_days() > version_warning_build_threshold_days then
            print(core.addon_name..": "..L["detected client and addon data mismatch for over 2 weeks. Consider checking for an update."]);
        end

        if not __sc_p_acc.localization_notified and sc.loc.locale_found then
            locale_warning_popup();
        end

        sw_activate_frame("spells_frame");
        __sc_frame:Hide();

        C_Timer.After(1.0, main_update);
        C_Timer.After(1.0, refresh_tooltip);
    end,
    ["ACTIONBAR_SLOT_CHANGED"] = function(_, slot)
        if not core.sw_addon_loaded or config.settings.overlay_disable then
            return;
        end

        -- rescanning action bar here seems like bad idea,
        -- commenting out until it turns out that this was needed
        --core.rescan_action_bar_needed = true;

        reassign_overlay_icon(slot);
        sc.loadouts.force_update = true;
    end,
    ["UPDATE_STEALTH"] = function()
        if not core.sw_addon_loaded then
            return;
        end
        core.special_action_bar_changed = true;
        sc.loadouts.force_update = true;
    end,
    ["UPDATE_BONUS_ACTIONBAR"] = function()
        if not core.sw_addon_loaded then
            return;
        end

        core.special_action_bar_changed = true;
        sc.loadouts.force_update = true;
    end,
    ["ACTIONBAR_PAGE_CHANGED"] = function()
        if not core.sw_addon_loaded then
            return;
        end

        core.special_action_bar_changed = true;
        sc.loadouts.force_update = true;
    end,
    ["UNIT_EXITED_VEHICLE"] = function(_, arg)
        if not core.sw_addon_loaded or config.settings.overlay_disable then
            return;
        end

        if arg == "player" then
            core.special_action_bar_changed = true;
            sc.loadouts.force_update = true;
        end
    end,
    ["ACTIVE_TALENT_GROUP_CHANGED"] = function()

        if not core.sw_addon_loaded then
            return;
        end

        core.active_spec = GetActiveTalentGroup();
        update_profile_frame();
        activate_settings();
        core.update_action_bar_needed = true;
        core.talents_update_needed = true;
    end,
    ["CHARACTER_POINTS_CHANGED"] = function()

        sc.loadouts.force_update = true;
        update_talents_frame();
    end,
    ["PLAYER_EQUIPMENT_CHANGED"] = function(_, slot)
        core.equipment_update_needed = true;
        update_calculator_character_items(slot);
    end,
    ["PLAYER_LEVEL_UP"] = function()
        core.old_ranks_checks_needed = true;
        sc.loadouts.force_update = true;
    end,
    ["LEARNED_SPELL_IN_TAB"] = function()
        core.old_ranks_checks_needed = true;
        sc.loadouts.force_update = true;
    end,
    ["SOCKET_INFO_UPDATE"] = function()
        core.equipment_update_needed = true;
        sc.loadouts.force_update = true;
    end,
    ["GLYPH_ADDED"] = function()
        core.talents_update_needed = true;
    end,
    ["GLYPH_REMOVED"] = function()
        core.talents_update_needed = true;
    end,
    ["GLYPH_UPDATED"] = function()
        core.talents_update_needed = true;
    end,
    ["CHAT_MSG_SKILL"] = function()
        core.talents_update_needed = true;
    end,
    ["ENGRAVING_MODE_CHANGED"] = function()
        core.equipment_update_needed = true;
    end,
    ["RUNE_UPDATED"] = function()
        core.equipment_update_needed = true;
    end,
    ["PLAYER_REGEN_DISABLED"] = function()
        -- Currently only registered when in Hardcore mode
        -- Hide addon UI when in combat
        __sc_frame:Hide();
    end,
    ["PLAYER_ENTERING_WORLD"] = function()
        doing_raid_update();
    end,
    ["GROUP_ROSTER_UPDATE"] = function()
        doing_raid_update();
    end,
};

local event_dispatch_client_exceptions = {
    ["ENGRAVING_MODE_CHANGED"] = sc.expansions.vanilla,
    ["RUNE_UPDATED"]           = sc.expansions.vanilla,
};

core.event_dispatch = event_dispatch;
core.event_dispatch_client_exceptions = event_dispatch_client_exceptions;


GameTooltip:HookScript("OnTooltipSetSpell", function()
    if not config.settings.tooltip_disable then
        sc.tooltip_mod = key_mod_flags()
        write_spell_tooltip();
    end
end);

local item_tooltip_mod = 0;
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    if not config.settings.tooltip_disable_item then
        local mod = key_mod_flags();
        local mod_change = mod ~= item_tooltip_mod;
        item_tooltip_mod = mod;
        write_item_tooltip(self, mod, mod_change);
    end
end);

hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
    if not config.settings.tooltip_disable_item then
        local mod = key_mod_flags();
        local mod_change = mod ~= item_tooltip_mod;
        item_tooltip_mod = mod;
        write_item_tooltip(self, mod, mod_change, link);
    end
end);

GameTooltip:HookScript("OnTooltipCleared", function(self)
    on_clear_tooltip(self);
end);
ItemRefTooltip:HookScript("OnTooltipCleared", function(self)
    on_clear_tooltip(self);
end);
GameTooltip:HookScript("OnShow", function(self)
    on_show_tooltip(self);
end);


local function command(arg)
    arg = string.lower(arg);

    if arg == "spell" or arg == "spells" then
        sw_activate_frame("spells_frame");
    elseif arg == "compare" or arg == "stat" or arg == "calc" or arg == "calculator" then
        sw_activate_frame("calculator_frame");
    elseif arg == "tooltip" then
        sw_activate_frame("tooltip_frame");
    elseif arg == "overlay" then
        sw_activate_frame("overlay_frame");
    elseif arg == "profile" or arg == "profiles" then
        sw_activate_frame("profile_frame");
    elseif arg == "loadout" or arg == "loadouts" then
        sw_activate_frame("loadout_frame");
    elseif arg == "settings" or arg == "opt" or arg == "options" or arg == "conf" or arg == "config" or arg == "configure" then
        sw_activate_frame("settings_frame");
    elseif arg == "reset" then
        core.use_char_defaults = 1;
        core.use_acc_defaults = 1;
        ReloadUI();
    else
        sw_activate_frame("spells_frame");
    end
end

SLASH_SPELL_CODA1 = "/sc"
SLASH_SPELL_CODA3 = "/SC"
SLASH_SPELL_CODA2 = "/spellcoda"
SLASH_SPELL_CODA3 = "/SpellCoda"
SlashCmdList["SPELL_CODA"] = command

sc.ext.version_id = core.version_id;

-- __SC and sc.ext should be deleted in favor of new public API at some point
-- but remains due to external things relying on it
__SC = sc.ext;

--__spellcoda_debug__ = 1;
--__spellcoda_test_all_data__ = 1;
--__spellcoda_test_all_spells__ = 1;


create_sw_base_ui();

