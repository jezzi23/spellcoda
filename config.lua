local _, sc               = ...;

local config               = {};

local spell_filter_options = {
    spells_filter_already_known              = true,
    spells_filter_available                  = true,
    spells_filter_unavailable                = true,
    spells_filter_learned_from_item          = true,
    spells_filter_pet                        = true,
    spells_filter_ignored_spells             = false,
    spells_filter_other_spells               = false,
    spells_filter_only_highest_learned_ranks = false
};

-- Avoiding all bit flags here simply any changes between versions
local default_settings     = {
    -- tooltip
    tooltip_display_addon_name                      = true,
    tooltip_display_target_info                     = true,
    tooltip_display_spell_rank                      = false,
    tooltip_display_avoidance_info                  = true,
    tooltip_display_normal                          = true,
    tooltip_display_crit                            = true,
    tooltip_display_expected                        = true,
    tooltip_display_effect_per_sec                  = true,
    tooltip_display_effect_per_cost                 = true,
    tooltip_display_threat                          = false,
    tooltip_display_threat_per_sec                  = false,
    tooltip_display_threat_per_cost                 = false,
    tooltip_display_cost_per_sec                    = false,
    tooltip_display_stat_weights_effect             = false,
    tooltip_display_stat_weights_effect_per_sec     = false,
    tooltip_display_stat_weights_effect_until_oom   = false,
    tooltip_display_avg_cost                        = true,
    tooltip_display_avg_cast                        = true,
    tooltip_display_cast_until_oom                  = false,
    tooltip_display_cast_and_tap                    = false,
    tooltip_display_sp_effect_calc                  = false,
    tooltip_display_sp_effect_ratio                 = false,
    tooltip_display_base_mod                        = false,
    tooltip_display_spell_id                        = false,
    tooltip_display_eval_options                    = true,
    tooltip_display_resource_regen                  = true,

    tooltip_disable                                 = false,
    tooltip_shift_to_show                           = false,
    tooltip_double_line                             = false,
    tooltip_clear_original                          = false,
    tooltip_hide_cd_coom                            = false,

    tooltip_disable_item                            = false,
    tooltip_item_leveling_skill_normalize           = true,

    -- overlay
    overlay_display_normal                          = false,
    overlay_display_crit                            = false,
    overlay_display_expected                        = false,
    overlay_display_effect_per_sec                  = true,
    overlay_display_effect_per_cost                 = false,
    overlay_display_threat                          = false,
    overlay_display_threat_per_sec                  = false,
    overlay_display_threat_per_cost                 = false,
    overlay_display_avg_cost                        = false,
    overlay_display_actual_cost                     = false,
    overlay_display_avg_cast                        = false,
    overlay_display_actual_cast                     = false,
    overlay_display_hit_chance                      = false,
    overlay_display_crit_chance                     = false,
    overlay_display_casts_until_oom                 = false,
    overlay_display_effect_until_oom                = false,
    overlay_display_time_until_oom                  = false,

    overlay_disable                                 = false,
    overlay_resource_regen                          = true,
    overlay_old_rank                                = false,
    overlay_old_rank_limit_to_known                 = true,
    overlay_icon_top_clearance                      = false,
    overlay_icon_bottom_clearance                   = false,

    overlay_update_freq                             = 3,
    overlay_font                                    = {"Interface\\AddOns\\SpellCoda\\font\\Oswald-Bold.ttf", "THICKOUTLINE"},
    overlay_font_size                               = 8,
    overlay_offset                                  = 0.0,

    overlay_disable_currently_casting_info          = true,
    overlay_currently_casting_only_eval             = true,
    overlay_currently_casting_horizontal            = false,
    overlay_currently_casting_info_scale            = 1.0,
    overlay_currently_casting_info_region           = "CENTER",
    overlay_currently_casting_info_x                = 350,
    overlay_currently_casting_info_y                = 0,
    overlay_currently_casting_font                  = {"Fonts\\FRIZQT__.TTF", "OUTLINE"},

    -- profiles
    profiles_dual_spec                              = false,

    -- spell catalogue
    spells_ignore_list                              = {},

    -- calculator
    spell_calc_list                                 = {
        -- a few basic spells for each class
        [6603] = 6603,
        -- warrior
        [78] = 78, -- heroic strik
        [23881] = 23881, -- bloodthirst
        [12294] = 12294, -- mortal strike
        -- hunter
        [75] = 75, -- auto shot
        [19434] = 19434, -- aimed shot
        [2643] = 2643, -- multi shot
        -- mage
        [133] = 133, --fireball
        [116] = 116, --frostbolt
        [1449] = 1449, --arcane explosion
        -- druid
        [5176] = 5176, -- wrath
        [5185] = 5185, -- healing touch
        [774] = 774, -- rejuv
        -- shaman
        [403] = 403, -- lightning bolt
        [331] = 331, -- healing wave
        [17364] = 17364, -- stormstrike
        --paladin
        [635] = 635, -- holy light
        [19750] = 19750, -- flash of light
        -- priest
        [8092] = 8092, -- mind blast
        [15407] = 15407, -- mind flay
        [139] = 139, -- renew
        [2054] = 2054, -- heal
        -- rogue
        [1752] = 1752, -- sinister strike
        [53] = 53, -- backstab
        [2098] = 2098, -- eviscerate
        -- warlock
        [686] = 686, -- shadow bolt
        [172] = 172, -- corruption
        [5676] = 5676, -- searing pain
    },
    calc_list_use_highest_rank                     = true,
    calc_fight_type                                = 1,

    -- general settings
    general_libstub_minimap_icon                   = true,
    general_spellbook_button                       = true,
    general_version_mismatch_notify                = true,

    -- general spell settings
    general_prio_heal                              = true,
    general_prio_multiplied_effect                 = true,
    general_average_proc_effects                   = true,

    libstub_icon_conf                              = { hide = false },
};

for k, v in pairs(spell_filter_options) do
    default_settings[k] = v;
end

local function load_persistent_data(persistent_data, template_data)
    if not persistent_data then
        persistent_data = {};
    end

    -- purge obsolete settings
    for k, v in pairs(persistent_data) do

        if k ~= "swc_to_sc_transition_popup_shown" then -- TEMPORARY: delete this when popup is removed later on
            if template_data[k] == nil then
                persistent_data[k] = nil;
            end
        end
    end
    -- load defaults for new settings
    for k, v in pairs(template_data) do
        if persistent_data[k] == nil then
            persistent_data[k] = v
        end
    end
end

local function default_profile()
    return {
        settings = sc.utils.deep_table_copy(default_settings)
    };
end

-- persistent account data template
local function default_p_acc()
    return {
        profiles = {
            ["Primary"] = default_profile()
        }
    };
end

local default_loadout_config = {

    name = "Main",

    use_custom_talents = false,
    custom_talents_code = "",
    force_apply_buffs = false,
    use_custom_lvl = false,
    lvl = 1,
    default_target_lvl_diff = 3,
    default_target_hp_perc = 100.0,
    target_res = 0,
    target_automatic_armor = true,
    target_automatic_armor_pct = 100,
    target_armor = 0,
    target_facing = false,
    unbounded_aoe_targets = 1,
    always_max_resource = false,
    behind_target = false,
    extra_mana = 0,

    buffs = {},
    target_buffs = {}
};

local function default_p_char()
    local data = {
        main_spec_profile = "Primary",
        second_spec_profile = "Primary",
        active_loadout = 1,
        loadouts = {
            sc.utils.deep_table_copy(default_loadout_config),
        },
    };
    return data;
end

local function load_config()
    if not __sc_p_acc then
        --sc.core.use_acc_defaults = true;
        __sc_p_acc = {};
    end
    load_persistent_data(__sc_p_acc, default_p_acc());
    for _, v in pairs(__sc_p_acc.profiles) do
        load_persistent_data(v, default_profile());
    end
    for _, v in pairs(__sc_p_acc.profiles) do
        load_persistent_data(v.settings, default_settings);
    end

    -- load settings
    if not __sc_p_char then
        --sc.core.use_char_defaults = true;
        __sc_p_char = {};
    end
    load_persistent_data(__sc_p_char, default_p_char());
    for _, v in pairs(__sc_p_char.loadouts) do
        load_persistent_data(v, default_loadout_config);
    end
end

local spec_keys = {
    [1] = "main_spec_profile",
    [2] = "second_spec_profile",
};

local function set_active_settings()
    for k, v in pairs(spec_keys) do
        if not __sc_p_acc.profiles[__sc_p_char[v]] then
            __sc_p_char[v] = next(__sc_p_acc.profiles);
        end

        if sc.core.active_spec == k then
            config.settings = __sc_p_acc.profiles[__sc_p_char[v]].settings;
        end
    end
    config.active_profile_name = __sc_p_char[spec_keys[sc.core.active_spec]];
end

local function activate_settings()
    for k, v in pairs(config.settings) do
        local f = getglobal("__sc_frame_setting_" .. k);
        if f then
            local ft = f._type;
            if ft == "CheckButton" then
                if f:GetChecked() ~= v then
                    f:Click();
                end
            elseif ft == "Slider" then
                if f:GetValue() ~= v then
                    f:SetValue(v);
                end
            elseif ft == "EditBox" then
                if f.number_editbox then
                    if tonumber(f:GetText()) ~= v then
                        f:SetText(tostring(v));
                    end
                else
                    if f:GetText() ~= v then
                        f:SetText(v);
                    end
                end
            elseif ft == "DropDownMenu" then
                f:init_func();
            end
        end
    end

    sc.overlay.currently_casting_frame_parent:ClearAllPoints();
    sc.overlay.currently_casting_frame_parent:SetPoint(
        config.settings.overlay_currently_casting_info_region,
        config.settings.overlay_currently_casting_info_x,
        config.settings.overlay_currently_casting_info_y
    );
end

local function set_active_loadout(idx)
    __sc_p_char.active_loadout = idx;
    config.loadout = __sc_p_char.loadouts[idx];
end

local function activate_loadout_config()
    for k, v in pairs(config.loadout) do
        local f = getglobal("__sc_frame_loadout_" .. k);
        if f and f._type then
            local ft = f._type;
            if ft == "CheckButton" then
                if f:GetChecked() ~= v then
                    f:Click();
                end
            elseif ft == "Slider" then
                if f:GetValue() ~= v then
                    f:SetValue(v);
                end
            elseif ft == "EditBox" then
                if f.number_editbox then
                    if tonumber(f:GetText()) ~= v then
                        f:SetText(tostring(v));
                    end
                else
                    if f:GetText() ~= v then
                        f:SetText(v);
                    end
                end
            end
        end
    end
end

local function save_config()

    __sc_p_acc.version_saved = sc.core.version_id;
    __sc_p_char.version_saved = sc.core.version_id;
    if sc.core.use_acc_defaults then
        __sc_p_acc = nil;
    end
    if sc.core.use_char_defaults then
        __sc_p_char = nil;
    end
end

local function new_profile(profile_name, profile_to_copy)
    if __sc_p_acc.profiles[profile_name] or profile_name == "" then
        return false;
    end
    __sc_p_acc.profiles[profile_name] = {};
    load_persistent_data(__sc_p_acc.profiles[profile_name], profile_to_copy);
    __sc_p_acc.profiles[profile_name].settings = sc.utils.deep_table_copy(profile_to_copy.settings);
    -- switch to new profile
    __sc_p_char[spec_keys[sc.core.active_spec]] = profile_name;
    set_active_settings()
    activate_settings();
    return true;
end

local function delete_profile()

        local cnt = 0;
        for _, _ in pairs(__sc_p_acc.profiles) do
            cnt = cnt + 1;
            if cnt > 1 then
                break;
            end
        end
        if cnt > 1 then
            __sc_p_acc.profiles[__sc_p_char[sc.config.spec_keys[sc.core.active_spec]]] = nil;
        end
end
local function reset_profile()

    local profile_name = __sc_p_char[sc.config.spec_keys[sc.core.active_spec]];
    __sc_p_acc.profiles[profile_name].settings = {};
    load_persistent_data(__sc_p_acc.profiles[profile_name].settings, default_settings);
    set_active_settings()
    activate_settings();
end

local function new_profile_from_default(profile_name)
    return new_profile(profile_name, sc.utils.deep_table_copy(default_profile()));
end

local function new_profile_from_active_copy(profile_name)
    return new_profile(profile_name, __sc_p_acc.profiles[config.active_profile_name]);
end

local function delete_loadout()
        local n = #__sc_p_char.loadouts;
        if n == 1 then
            return;
        end

        if n ~= active_loadout then
            for i = __sc_p_char.active_loadout, n-1 do
                __sc_p_char.loadouts[i] = __sc_p_char.loadouts[i+1];
            end
        end
        __sc_p_char.loadouts[n] = nil;

        config.set_active_loadout(1);
end

local function reset_loadout()

    local idx = __sc_p_char.active_loadout;
    local name = __sc_p_char.loadouts[idx].name;
    __sc_p_char.loadouts[idx] = {name = name};
    load_persistent_data(__sc_p_char.loadouts[idx], default_loadout_config);

    config.set_active_loadout(idx);
end

local function new_loadout(name, loadout_to_copy)
    if name == "" then
        return false;
    end
    for _, v in pairs(__sc_p_char.loadouts) do
        if v.name == name then
            return false;
        end
    end

    local n = #__sc_p_char.loadouts + 1;
    __sc_p_char.loadouts[n] = {};
    load_persistent_data(__sc_p_char.loadouts[n], loadout_to_copy);
    __sc_p_char.active_loadout = n;
    __sc_p_char.loadouts[n].name = name;

    set_active_loadout(n);

    return true;
end

local function new_loadout_from_active_copy(name)
    return new_loadout(name, sc.utils.deep_table_copy(__sc_p_char.loadouts[__sc_p_char.active_loadout]));
end

local function new_loadout_from_default(name)
    return new_loadout(name, sc.utils.deep_table_copy(default_loadout_config));
end


config.delete_profile = delete_profile;
config.reset_profile = reset_profile;
config.reset_loadout = reset_loadout;
config.delete_loadout = delete_loadout;
config.new_profile_from_default = new_profile_from_default;
config.new_profile_from_active_copy = new_profile_from_active_copy;
config.load_settings = load_settings;
config.load_config = load_config;
config.save_config = save_config;
config.set_active_settings = set_active_settings;
config.activate_settings = activate_settings;
config.activate_loadout_config = activate_loadout_config;
config.set_active_loadout = set_active_loadout;
config.new_loadout_from_active_copy = new_loadout_from_active_copy;
config.new_loadout_from_default = new_loadout_from_default;
config.active_profile_name = active_profile_name;
config.spec_keys = spec_keys;
config.spell_filter_options = spell_filter_options;
config.default_settings = default_settings;

sc.config = config;
