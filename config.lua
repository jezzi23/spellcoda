local _, sc               = ...;

local config               = {};

local spell_filter_options = {
    spells_filter_already_known              = true,
    spells_filter_available                  = true,
    spells_filter_unavailable                = true,
    spells_filter_missing_requirement        = true,
    spells_filter_innate                     = true,
    spells_filter_weapon_skills              = true,
    spells_filter_trainer                    = true,
    spells_filter_talent                     = true,
    spells_filter_learned_from_item          = true,
    spells_filter_pet                        = true,
    spells_filter_other_spells               = false,
    spells_filter_ignored_spells             = false,
    spells_filter_hide_replaced_ranks        = false,
};

local combat_unseen_buffs = { keep = 1, expire = 2, drop = 3 };

-- Fairly flat settings structure to simplify transitions between versions
local default_settings     = {
    -- tooltip
    tooltip_display_addon_name                                  = true,
    tooltip_display_target_info                                 = true,
    tooltip_display_spell_rank                                  = false,
    tooltip_display_avoidance_info                              = true,
    tooltip_display_normal                                      = true,
    tooltip_display_crit                                        = true,
    tooltip_display_res_details                                 = false,
    tooltip_display_partial_resists                             = false,
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
    tooltip_display_sp_effect_calc                              = true,
    tooltip_display_sp_effect_ratio                             = false,
    tooltip_display_spell_id                                    = false,
    tooltip_display_eval_options                                = true,
    tooltip_display_resource_regen                              = true,
    tooltip_display_ehp                                         = true,

    tooltip_disable                                             = false,
    tooltip_shift_to_show                                       = false,
    tooltip_double_line                                         = false,
    tooltip_clear_original                                      = false,
    tooltip_hide_cd_coom                                        = false,

    tooltip_disable_item                                        = false,
    tooltip_item_leveling_skill_normalize                       = true,
    tooltip_item_weapon_skill                                   = true,
    tooltip_item_smart                                          = true,
    tooltip_item_quality_threshold                              = 2,

    tooltip_item_apply_set_bonuses                              = false,
    tooltip_item_apply_gems                                     = true,
    tooltip_item_apply_enchant                                  = false,

    tooltip_item_key_hints                                      = true,
    tooltip_item_ignore_unequippable                            = false,
    tooltip_item_ignore_cloth                                   = false,
    tooltip_item_ignore_leather                                 = false,
    tooltip_item_ignore_mail                                    = false,
    tooltip_item_ignore_plate                                   = false,
    tooltip_item_stat_diff                                      = false,
    -- shown stat line cells per class token, filled from the class defaults on first use (stat_lines.lua)
    stat_lines                                                  = {},

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

    overlay_disable_in_combat                                   = false,
    overlay_disable_in_raid                                     = false,
    overlay_disable                                             = false,
    overlay_old_rank                                            = false,
    overlay_old_rank_limit_to_known                             = true,
    overlay_no_decimals                                         = false,
    overlay_hide_macro_names                                    = false,
    overlay_resource_regen                                      = true,
    overlay_resource_regen_display_idx                          = 3,
    overlay_ehp                                                 = true,
    overlay_ehp_display_idx                                     = 3,

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
    overlay_cc_only_eval                                        = false,
    overlay_cc_horizontal                                       = false,
    overlay_cc_info_scale                                       = 1.0,
    overlay_cc_info_region                                      = "CENTER",
    overlay_cc_info_x                                           = 350,
    overlay_cc_info_y                                           = 0,
    overlay_cc_font                                             = {"Fonts\\FRIZQT__.TTF", "OUTLINE"},
    overlay_cc_move_adjacent_on_empty                           = true,
    overlay_cc_hanging_time                                     = 3,
    overlay_cc_transition_time                                  = 0.3,
    overlay_cc_transition_length                                = 100,
    overlay_cc_transition_nocd                                  = false,

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
    -- the old comparison list of all classes, only read for profiles saved before compared_spells
    spell_calc_list                                             = {},
    -- ordered spell ids per class token: Attack, Dodge for EHP, then a few basic spells of the class
    compared_spells                                             = {
        WARRIOR = { 6603, 81, 78, 12294, 23881 },     -- heroic strike, mortal strike, bloodthirst
        PALADIN = { 6603, 81, 635, 19750 },           -- holy light, flash of light
        HUNTER  = { 6603, 81, 75, 19434, 2643 },      -- auto shot, aimed shot, multi shot
        ROGUE   = { 6603, 81, 1752, 53, 2098 },       -- sinister strike, backstab, eviscerate
        PRIEST  = { 6603, 81, 8092, 15407, 2054 },    -- mind blast, mind flay, heal
        SHAMAN  = { 6603, 81, 403, 331, 17364 },      -- lightning bolt, healing wave, stormstrike
        MAGE    = { 6603, 81, 133, 116, 5143 },       -- fireball, frostbolt, arcane missiles
        WARLOCK = { 6603, 81, 686, 172, 5676 },       -- shadow bolt, corruption, searing pain
        DRUID   = { 6603, 81, 5176, 5185 },           -- wrath, healing touch
    },
    calc_list_use_highest_rank                                  = true,
    calc_fight_type                                             = 1,

    -- general settings
    general_libstub_minimap_icon                                = true,
    general_spellbook_button                                    = true,
    spellbook_catalogue_compact                                 = true,
    general_version_mismatch_notify                             = true,

    -- general spell settings
    general_prio_heal                                           = true,
    general_prio_multiplied_effect                              = true,
    general_average_proc_effects                                = true,
    general_on_hit_procs                                        = true,

    -- general calc settings
    general_calc_secondary_tooltip                              = true,
    general_calc_stats_raw_dump                                 = false,
    general_calc_global_compare                                 = false,

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

    -- loadout settings
    loadout_use_custom_lvl                                      = false,
    loadout_lvl                                                 = 1,
    loadout_default_target_lvl_diff                             = 3,
    loadout_default_target_hp_perc                              = 100.0,
    loadout_default_target_creature_type                        = 0,
    loadout_target_res                                          = 0,
    loadout_target_pvpres                                       = 0,
    loadout_target_automatic_armor                              = true,
    loadout_target_automatic_armor_heavy                        = true,
    loadout_target_automatic_armor_medium                       = false,
    loadout_target_automatic_armor_light                        = false,
    loadout_target_armor                                        = 0,
    loadout_target_facing                                       = false,
    loadout_unbounded_aoe_targets                               = 1,
    loadout_always_max_resource                                 = false,
    loadout_combat_unseen_buffs                                 = combat_unseen_buffs.expire,
    loadout_assume_buffs                                        = false,
    loadout_assume_buffs_only_combat                            = false,
    loadout_assume_buffs_only_raid                              = false,
    loadout_assumed_buffs                                       = { player_buffs = {}, target_buffs = {} },
    -- class token -> creature family id of the pet assumed while none is out, missing means none
    loadout_assumed_pet                                         = {},
    loadout_behind_target                                       = false,

    libstub_icon_conf                                           = { hide = false },
};

-- the spellbook catalogue (forever) keeps its own filters
for k, v in pairs(spell_filter_options) do
    default_settings[k] = v;
    default_settings[(string.gsub(k, "^spells_filter_", "spellbook_catalogue_filter_"))] = v;
end

-- general_color_<tag>_<r|g|b> = {tag, rgb index}
local color_settings = {};
for k in pairs(default_settings) do
    local tag, comp = k:match("^general_color_(.+)_([rgb])$");
    if tag then
        color_settings[k] = {tag, ({r = 1, g = 2, b = 3})[comp]};
    end
end

local function load_persistent_data(persistent_data, template_data)
    if not persistent_data then
        persistent_data = {};
    end

    -- purge obsolete settings
    for k, v in pairs(persistent_data) do

        if template_data[k] == nil then
            persistent_data[k] = nil;
        end
    end
    -- load defaults for new settings
    for k, v in pairs(template_data) do
        if persistent_data[k] == nil then
            if type(v) == "table" then
                persistent_data[k] = sc.utils.deep_table_copy(v);
            else
                persistent_data[k] = v
            end
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
        },
        localization_use = false,
        localization_notified = false,
        window_scale = sc.utils.client_matches(sc.client_flags.forever) and 1.25 or 1.0,
    };
end

local default_calculator_save_config = {
    items = {},
    stats = {},
    talents = {},
    buffs = {},
};

local function default_p_char()
    local data = {
        main_spec_profile = "Primary",
        second_spec_profile = "Primary",
        calculator_saves = {},
    };
    return data;
end

-- migrations[n] takes a profile's settings from settings_rev n - 1 to n. They run before load_persistent_data drops
-- the keys that left default_settings, so a migration can still read them. Only append: profiles store the rev
-- they reached, an entry that moves or goes away runs on the wrong profiles.
local migrations = {
    function(settings)
        if settings.loadout_combat_ignore_buffs and settings.loadout_combat_unseen_buffs == nil then
            settings.loadout_combat_unseen_buffs = combat_unseen_buffs.drop;
        end
    end,
    -- profiles saved before compared_spells keep their own lists, each class builds it from spell_calc_list
    function(settings)
        if settings.spell_calc_list and settings.compared_spells == nil then
            settings.compared_spells = {};
        end
    end,
};
default_settings.settings_rev = #migrations;

local function migrate_settings(settings)
    for rev = (settings.settings_rev or 0) + 1, #migrations do
        migrations[rev](settings);
    end
    settings.settings_rev = #migrations;
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
        migrate_settings(v.settings);
        load_persistent_data(v.settings, default_settings);
        -- saved data can come from another client, keep values bound by client data in range
        v.settings.loadout_lvl = math.min(v.settings.loadout_lvl, sc.max_lvl);
    end

    -- load settings
    if not __sc_p_char then
        --sc.core.use_char_defaults = true;
        __sc_p_char = {};
    end
    load_persistent_data(__sc_p_char, default_p_char());

    for _, v in pairs(__sc_p_char.calculator_saves) do
        load_persistent_data(v, default_calculator_save_config);
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
    for k, v in pairs(color_settings) do
        sc.utils.assign_color_tag(v[1], v[2], config.settings[k]);
    end
end

local function activate_config(config_type, prefix)
    for k, v in pairs(config[config_type]) do
        local f = getglobal(prefix .. k);
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
                end

            elseif ft == "DropDownMenu" then
                f:init_func();
            else
                if f:GetText() ~= v then
                    f:SetText(v);
                end
            end
        end
    end
end

local function activate_settings()

    config.activating = true;
    activate_config("settings", "__sc_frame_setting_");
    config.activating = false;
    for k in pairs(sc.overlay.ccf_labels) do
        sc.overlay.ccf_label_reconfig(k);
    end
    sc.overlay.overlay_reconfig();
    sc.ui.apply_colors();
    sc.ui.refresh_compared_spells();
    sc.ui.refresh_stat_lines();

    sc.overlay.ccf_parent:ClearAllPoints();
    sc.overlay.ccf_parent:SetPoint(
        config.settings.overlay_cc_info_region,
        config.settings.overlay_cc_info_x,
        config.settings.overlay_cc_info_y
    );
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

-- the active profile's comparison list of this class, in order; ids may repeat (several ranks of a spell)
local function compared_spell_list()
    local lists = config.settings.compared_spells;
    local list = lists[sc.class];
    if not list then
        list = {};
        for k in pairs(config.settings.spell_calc_list) do
            if sc.spells[k] then
                list[#list + 1] = k;
            end
        end
        -- Attack, then EHP, then by name
        local group = {};
        local names = {};
        for _, k in ipairs(list) do
            if k == sc.spids.attack then
                group[k] = 1;
            elseif bit.band(sc.spells[k].flags, sc.spell_flags.ehp) ~= 0 then
                group[k] = 2;
            else
                group[k] = 3;
            end
            names[k] = C_Spell.GetSpellName(k) or "";
        end
        table.sort(list, function(a, b)
            if group[a] ~= group[b] then
                return group[a] < group[b];
            end
            if names[a] ~= names[b] then
                return names[a] < names[b];
            end
            return a < b;
        end);
        lists[sc.class] = list;
    end
    return list;
end

-- with the highest learned rank compared, every rank of a spell is the same entry
local function compared_entry_matches(k, spell_id)
    if k == spell_id then
        return true;
    end
    return config.settings.calc_list_use_highest_rank and
        sc.spells[k] ~= nil and sc.spells[spell_id] ~= nil and
        sc.spells[k].base_id == sc.spells[spell_id].base_id;
end

local function compared_spells_contains(spell_id)
    for _, k in ipairs(compared_spell_list()) do
        if compared_entry_matches(k, spell_id) then
            return true;
        end
    end
    return false;
end

local function add_compared_spell(spell_id)
    if not compared_spells_contains(spell_id) then
        local list = compared_spell_list();
        list[#list + 1] = spell_id;
    end
end

local function remove_compared_spell(spell_id)
    local list = compared_spell_list();
    for i = #list, 1, -1 do
        if compared_entry_matches(list[i], spell_id) then
            table.remove(list, i);
        end
    end
end

--------------------------------------------------------------------------------
config.compared_spell_list = compared_spell_list;
config.compared_spells_contains = compared_spells_contains;
config.add_compared_spell = add_compared_spell;
config.remove_compared_spell = remove_compared_spell;
config.delete_profile = delete_profile;
config.reset_profile = reset_profile;
config.new_profile_from_default = new_profile_from_default;
config.new_profile_from_active_copy = new_profile_from_active_copy;
config.load_config = load_config;
config.save_config = save_config;
config.set_active_settings = set_active_settings;
config.activate_settings = activate_settings;
config.spec_keys = spec_keys;
config.spell_filter_options = spell_filter_options;
config.default_settings = default_settings;
config.combat_unseen_buffs = combat_unseen_buffs;

sc.config = config;
