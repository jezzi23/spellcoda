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
    tooltip_display_addon_name                                  = true,
    tooltip_display_target_info                                 = true,
    tooltip_display_spell_rank                                  = false,
    tooltip_display_avoidance_info                              = true,
    tooltip_display_normal                                      = true,
    tooltip_display_crit                                        = true,
    tooltip_display_expected                                    = true,
    tooltip_display_effect_per_sec                              = true,
    tooltip_display_effect_per_cost                             = true,
    tooltip_display_threat                                      = false,
    tooltip_display_threat_per_sec                              = false,
    tooltip_display_threat_per_cost                             = false,
    tooltip_display_cost_per_sec                                = false,
    tooltip_display_stat_weights_effect                         = false,
    tooltip_display_stat_weights_effect_per_sec                 = false,
    tooltip_display_stat_weights_effect_until_oom               = false,
    tooltip_display_avg_cost                                    = true,
    tooltip_display_avg_cast                                    = true,
    tooltip_display_cast_until_oom                              = false,
    tooltip_display_cast_and_tap                                = false,
    tooltip_display_sp_effect_calc                              = false,
    tooltip_display_sp_effect_ratio                             = false,
    tooltip_display_base_mod                                    = false,
    tooltip_display_spell_id                                    = false,
    tooltip_display_eval_options                                = true,
    tooltip_display_resource_regen                              = true,

    tooltip_disable                                             = false,
    tooltip_shift_to_show                                       = false,
    tooltip_double_line                                         = false,
    tooltip_clear_original                                      = false,
    tooltip_hide_cd_coom                                        = false,

    tooltip_disable_item                                        = false,
    tooltip_item_leveling_skill_normalize                       = true,

    -- overlay
    overlay_display_normal                                      = false,
    overlay_display_crit                                        = false,
    overlay_display_expected                                    = false,
    overlay_display_effect_per_sec                              = true,
    overlay_display_effect_per_cost                             = false,
    overlay_display_threat                                      = false,
    overlay_display_threat_per_sec                              = false,
    overlay_display_threat_per_cost                             = false,
    overlay_display_avg_cost                                    = false,
    overlay_display_actual_cost                                 = false,
    overlay_display_avg_cast                                    = false,
    overlay_display_actual_cast                                 = false,
    overlay_display_hit_chance                                  = false,
    overlay_display_miss_chance                                 = false,
    overlay_display_crit_chance                                 = false,
    overlay_display_casts_until_oom                             = false,
    overlay_display_effect_until_oom                            = false,
    overlay_display_time_until_oom                              = false,

    overlay_disable                                             = false,
    overlay_old_rank                                            = false,
    overlay_old_rank_limit_to_known                             = true,
    overlay_no_decimals                                         = false,
    overlay_resource_regen                                      = true,
    overlay_resource_regen_display_idx                          = 3,

    overlay_update_freq                                         = 3,
    overlay_font                                                = {"Interface\\AddOns\\SpellCoda\\font\\Oswald-Bold.ttf", "THICKOUTLINE"},
    overlay_top_enabled                                         = false,
    overlay_top_x                                               = 1.0,
    overlay_top_y                                               = -3.0,
    overlay_top_fsize                                           = 8,
    overlay_top_selection                                       = "overlay_display_effect_per_cost",

    overlay_center_enabled                                      = false,
    overlay_center_x                                            = 1.0,
    overlay_center_y                                            = -1.5,
    overlay_center_fsize                                        = 8,
    overlay_center_selection                                    = "overlay_display_normal",

    overlay_bottom_enabled                                      = true,
    overlay_bottom_x                                            = 1.0,
    overlay_bottom_y                                            = 0.0,
    overlay_bottom_fsize                                        = 8,
    overlay_bottom_selection                                    = "overlay_display_effect_per_sec",

    overlay_disable_cc_info                                     = true,
    overlay_cc_only_eval                                        = true,
    overlay_cc_horizontal                                       = false,
    overlay_cc_info_scale                                       = 1.0,
    overlay_cc_info_region                                      = "CENTER",
    overlay_cc_info_x                                           = 350,
    overlay_cc_info_y                                           = 0,
    overlay_cc_font                                             = {"Fonts\\FRIZQT__.TTF", "OUTLINE"},
    overlay_cc_animate                                          = true,
    overlay_cc_move_adjacent_on_empty                           = true,

    -- Currently casting frame labels
    overlay_cc_outside_right_upper_enabled                      = true,
    overlay_cc_outside_right_upper_x                            = 0,
    overlay_cc_outside_right_upper_y                            = -15,
    overlay_cc_outside_right_upper_fsize                        = 13,
    overlay_cc_outside_right_upper_selection                    = "overlay_display_direct_normal",

    overlay_cc_outside_right_lower_enabled                      = true,
    overlay_cc_outside_right_lower_x                            = 0,
    overlay_cc_outside_right_lower_y                            = 15,
    overlay_cc_outside_right_lower_fsize                        = 13,
    overlay_cc_outside_right_lower_selection                    = "overlay_display_direct_crit",

    overlay_cc_outside_left_upper_enabled                       = true,
    overlay_cc_outside_left_upper_x                             = 0,
    overlay_cc_outside_left_upper_y                             = -15,
    overlay_cc_outside_left_upper_fsize                         = 13,
    overlay_cc_outside_left_upper_selection                     = "overlay_display_ot_normal",

    overlay_cc_outside_left_lower_enabled                       = true,
    overlay_cc_outside_left_lower_x                             = 0,
    overlay_cc_outside_left_lower_y                             = 15,
    overlay_cc_outside_left_lower_fsize                         = 13,
    overlay_cc_outside_left_lower_selection                     = "overlay_display_ot_crit",

    overlay_cc_outside_top_left_enabled                         = true,
    overlay_cc_outside_top_left_x                               = -2,
    overlay_cc_outside_top_left_y                               = 4,
    overlay_cc_outside_top_left_fsize                           = 9,
    overlay_cc_outside_top_left_selection                       = "overlay_display_mitigation",

    overlay_cc_outside_top_right_enabled                        = true,
    overlay_cc_outside_top_right_x                              = 2,
    overlay_cc_outside_top_right_y                              = 4,
    overlay_cc_outside_top_right_fsize                          = 9,
    overlay_cc_outside_top_right_selection                      = "overlay_display_effect_per_sec",

    overlay_cc_outside_bottom_left_enabled                      = true,
    overlay_cc_outside_bottom_left_x                            = -2,
    overlay_cc_outside_bottom_left_y                            = -4,
    overlay_cc_outside_bottom_left_fsize                        = 9,
    overlay_cc_outside_bottom_left_selection                    = "overlay_display_time_until_oom",

    overlay_cc_outside_bottom_right_enabled                     = true,
    overlay_cc_outside_bottom_right_x                           = 2,
    overlay_cc_outside_bottom_right_y                           = -4,
    overlay_cc_outside_bottom_right_fsize                       = 9,
    overlay_cc_outside_bottom_right_selection                   = "overlay_display_effect_per_cost",

    overlay_cc_inside_top_enabled                               = true,
    overlay_cc_inside_top_x                                     = 1,
    overlay_cc_inside_top_y                                     = 0,
    overlay_cc_inside_top_fsize                                 = 7,
    overlay_cc_inside_top_selection                             = "overlay_display_hit_chance",

    overlay_cc_inside_bottom_enabled                            = true,
    overlay_cc_inside_bottom_x                                  = 1,
    overlay_cc_inside_bottom_y                                  = 0,
    overlay_cc_inside_bottom_fsize                              = 7,
    overlay_cc_inside_bottom_selection                          = "overlay_display_crit_chance",

    overlay_cc_inside_left_enabled                              = true,
    overlay_cc_inside_left_x                                    = 3,
    overlay_cc_inside_left_y                                    = 0,
    overlay_cc_inside_left_fsize                                = 7,
    overlay_cc_inside_left_selection                            = "overlay_display_rank",

    overlay_cc_inside_right_enabled                             = false,
    overlay_cc_inside_right_x                                   = 0,
    overlay_cc_inside_right_y                                   = 0,
    overlay_cc_inside_right_fsize                               = 7,
    overlay_cc_inside_right_selection                           = "overlay_display_avoid_chance",

    -- profiles
    profiles_dual_spec                                          = false,

    -- spell catalogue
    spells_ignore_list                                          = {},

    -- calculator
    spell_calc_list                                             = {
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
    calc_list_use_highest_rank                                  = true,
    calc_fight_type                                             = 1,

    -- general settings
    general_libstub_minimap_icon                                = true,
    general_spellbook_button                                    = true,
    general_version_mismatch_notify                             = true,

    -- general spell settings
    general_prio_heal                                           = true,
    general_prio_multiplied_effect                              = true,
    general_average_proc_effects                                = true,

    -- general color palette settings
    general_color_normal_r                                      = 232,
    general_color_normal_g                                      = 225,
    general_color_normal_b                                      = 32,
    general_color_crit_r                                        = 252,
    general_color_crit_g                                        = 69,
    general_color_crit_b                                        = 3,
    general_color_old_rank_r                                    = 252,
    general_color_old_rank_g                                    = 69,
    general_color_old_rank_b                                    = 3,
    general_color_target_info_r                                 = 70,
    general_color_target_info_g                                 = 130,
    general_color_target_info_b                                 = 180,
    general_color_avoidance_info_r                              = 70,
    general_color_avoidance_info_g                              = 130,
    general_color_avoidance_info_b                              = 180,
    general_color_expectation_r                                 = 255,
    general_color_expectation_g                                 = 128,
    general_color_expectation_b                                 = 0,
    general_color_effect_per_sec_r                              = 255,
    general_color_effect_per_sec_g                              = 128,
    general_color_effect_per_sec_b                              = 0,
    general_color_execution_time_r                              = 149,
    general_color_execution_time_g                              = 53,
    general_color_execution_time_b                              = 83,
    general_color_cost_r                                        = 0,
    general_color_cost_g                                        = 255,
    general_color_cost_b                                        = 255,
    general_color_effect_per_cost_r                             = 0,
    general_color_effect_per_cost_g                             = 255,
    general_color_effect_per_cost_b                             = 255,
    general_color_cost_per_sec_r                                = 0,
    general_color_cost_per_sec_g                                = 255,
    general_color_cost_per_sec_b                                = 255,
    general_color_effect_until_oom_r                            = 255,
    general_color_effect_until_oom_g                            = 128,
    general_color_effect_until_oom_b                            = 0,
    general_color_casts_until_oom_r                             = 0,
    general_color_casts_until_oom_g                             = 255,
    general_color_casts_until_oom_b                             = 0,
    general_color_time_until_oom_r                              = 0,
    general_color_time_until_oom_g                              = 255,
    general_color_time_until_oom_b                              = 0,
    general_color_sp_effect_r                                   = 138,
    general_color_sp_effect_g                                   = 134,
    general_color_sp_effect_b                                   = 125,
    general_color_stat_weights_r                                = 0,
    general_color_stat_weights_g                                = 255,
    general_color_stat_weights_b                                = 0,
    general_color_spell_rank_r                                  = 138,
    general_color_spell_rank_g                                  = 134,
    general_color_spell_rank_b                                  = 125,
    general_color_threat_r                                      = 150,
    general_color_threat_g                                      = 105,
    general_color_threat_b                                      = 25,

    libstub_icon_conf                                           = { hide = false },
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
                f:SetValue(v);
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

    sc.overlay.ccf_parent:ClearAllPoints();
    sc.overlay.ccf_parent:SetPoint(
        config.settings.overlay_cc_info_region,
        config.settings.overlay_cc_info_x,
        config.settings.overlay_cc_info_y
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

--------------------------------------------------------------------------------
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
