local _, sc = ...;

local L                                 = sc.L;

local attr                              = sc.attr;
local classes                           = sc.classes;
local powers                            = sc.powers;
local class                             = sc.class;
local schools                           = sc.schools;

local category_idx                      = sc.aura_idx_category;
local effect_idx                        = sc.aura_idx_effect;
local value_idx                         = sc.aura_idx_value;
local subject_idx                       = sc.aura_idx_subject;
local flags_idx                         = sc.aura_idx_flags;
local iid_idx                           = sc.aura_idx_iid; -- internal index within this spell id

local mana_per_int                      = sc.scaling.mana_per_int;
local hp_per_stam                       = sc.scaling.hp_per_stam;
local ap_per_str                        = sc.scaling.ap_per_str;
local ap_per_agi                        = sc.scaling.ap_per_agi;
local rap_per_agi                       = sc.scaling.rap_per_agi;
local armor_per_agi                     = sc.scaling.armor_per_agi;
local cr_weights                        = sc.scaling.cr_weights;
local spirit_mana_regen                 = sc.scaling.spirit_mana_regen;

local write_item_info_from_link         = sc.utils.write_item_info_from_link;
local combat_ratings                    = sc.utils.combat_ratings;
local spell_lname                       = sc.utils.spell_lname;

local config                            = sc.config;

--------------------------------------------------------------------------------
local loadouts = {};

local loadout_flags = {
    has_target                          = bit.lshift(1, 1),
    target_friendly                     = bit.lshift(1, 2),
    target_pvp                          = bit.lshift(1, 3),
};

-- Loadout and Effects split into sections by types to make comparing, iterating, merging
-- not need a slower general purpose recursive implementation
local loadout_numbers = {
    "target_armor",
    "player_hp_max",
    "player_hp",
    "enemy_hp_perc",
    "flags",
    "lvl",
    "target_lvl",
    --"phys_hit",
    "spell_dmg",
    "healing_power",
    "spell_power",
    "base_mana",
    "ap",
    "rap",
    "ranged_skill",
    "m1_skill",
    "m2_skill",
    "melee_crit",
    "ranged_crit",
    "block",
    "dodge",
    "parry",
    "r_speed",
    "r_min",
    "r_max",
    "r_pos",
    "r_neg",
    "r_mod",
    "m1_min",
    "m1_max",
    "m2_min",
    "m2_max",
    "m_pos",
    "m_neg",
    "m_mod",
    "m1_speed",
    "m2_speed",
    "shapeshift",
    "shapeshift_no_weapon",
    "target_defense",
    "target_creature_mask",
    "target_res",
};

local ratings = {
    {combat_ratings.CR_DEFENSE_SKILL,                   "defense_skill_rating"},
    {combat_ratings.CR_DODGE,                           "dodge_rating"},
    {combat_ratings.CR_PARRY,                           "parry_rating"},
    {combat_ratings.CR_BLOCK,                           "block_rating"},
    {combat_ratings.CR_HASTE_SPELL,                     "spell_haste_rating"},
    {combat_ratings.CR_HASTE_MELEE,                     "melee_haste_rating"},
    {combat_ratings.CR_HASTE_RANGED,                    "ranged_haste_rating"},
    {combat_ratings.CR_HIT_SPELL,                       "spell_hit_rating"},
    {combat_ratings.CR_HIT_MELEE,                       "melee_hit_rating"},
    {combat_ratings.CR_HIT_RANGED,                      "ranged_hit_rating"},
    {combat_ratings.CR_CRIT_SPELL,                      "spell_crit_rating"},
    {combat_ratings.CR_CRIT_MELEE,                      "melee_crit_rating"},
    {combat_ratings.CR_CRIT_RANGED,                     "ranged_crit_rating"},
    {combat_ratings.CR_EXPERTISE,                       "expertise_rating"},
    {combat_ratings.CR_RESILIENCE_CRIT_TAKEN,           "resilience_crit_taken_rating"},
    {combat_ratings.CR_RESILIENCE_PLAYER_DAMAGE_TAKEN,  "resilience_dmg_taken_rating"},
};
for _, v in ipairs(ratings) do
    loadout_numbers[#loadout_numbers + 1] = v[2];
end


local loadout_tables = {
    stats = {0, 0, 0, 0, 0},
    resources = {
        [sc.powers.mana] = 0,
        [sc.powers.rage] = 0,
        [sc.powers.energy] = 0,
        [sc.powers.combopoints] = 0,
    },
    resources_max = {
        [sc.powers.mana] = 0,
        [sc.powers.rage] = 0,
        [sc.powers.energy] = 0,
        [sc.powers.combopoints] = 0,
    },
    spell_dmg_by_school     = {0, 0, 0, 0, 0, 0, 0},
    spell_dmg_hit_by_school = {0, 0, 0, 0, 0, 0, 0},
    spell_crit_by_school    = {0, 0, 0, 0, 0, 0, 0},
};

local loadout_strs = {
    "player_name",
    "target_name",
    "hostile_towards",
    "friendly_towards",
    "target_creature_type",
};

local loadout_units = {
    "player", "target", "mouseover"
};

local function loadout_zero()
    local empty = {};

    for _, v in ipairs(loadout_numbers) do
        empty[v] = 0;
    end
    for _, v in ipairs(loadout_strs) do
        empty[v] = "";
    end
    for k, v in pairs(loadout_tables) do
        empty[k] = {};
        for kk, vv in pairs(v) do
            empty[k][kk] = vv;
        end
    end
    empty.dynamic_buffs = {};
    empty.dynamic_buffs_lname = {};
    for _, v in ipairs(loadout_units) do
        empty.dynamic_buffs[v] = {};
        empty.dynamic_buffs_lname[v] = {};
    end

    return empty;
end

local function loadout_eql(lhs, rhs)

    for _, v in ipairs(loadout_numbers) do
        if lhs[v] ~= rhs[v] then
            return false;
        end
    end
    for _, v in ipairs(loadout_strs) do
        if lhs[v] ~= rhs[v] then
            return false;
        end
    end

    for k, v in pairs(loadout_tables) do
        for kk, vv in pairs(v) do
            if lhs[k][kk] ~= rhs[k][kk] then
                return false;
            end
        end
    end

    for _, v in ipairs(loadout_units) do
        for id, _ in pairs(lhs.dynamic_buffs[v]) do
            if not rhs.dynamic_buffs[v][id] then
                return false;
            end
        end
        for id, buff_data in pairs(rhs.dynamic_buffs[v]) do
            if not lhs.dynamic_buffs[v][id] then
                return false;
            else
                for kk, vv in pairs(buff_data) do
                    if lhs.dynamic_buffs[v][id][kk] ~= vv then
                        return false;
                    end
                end
            end
        end
    end
    return true;
end

local effect_categories = {
    "by_school",
    "by_attr",
    "raw",
    "ability",
    "aura_pts",
    "aura_pts_flat",
    "wpn_subclass",
    "creature",

    "num_set_pieces",
    "enchants",
    "talent_pts",
};

local effects_additive = {
    by_school = {
        "spell_hit",
        "crit_mod",
        "sp_dmg_flat",
        "crit",
        "crit_forced",
        "target_res",
        "target_res_flat",
        "threat",
        "cost_mod",
        "res_flat",
    },
    by_attr = {
        "stat_flat",
        "stat_mod",
        "stat_mod_forced",
        "sd_of_stat_pct",
        "sd_of_stat_pct_forced",
        "hp_of_stat_pct",
        "hp_of_stat_pct_forced",
    },
    ability = {
        "threat",
        "threat_flat",
        "crit",
        "ignore_cant_crit",
        "effect_mod",
        "effect_mod_flat",
        "effect_mod_ot",
        "effect_mod_ot_flat",
        "base_mod",
        "base_mod_flat",
        "base_mod_ot",
        "base_mod_ot_flat",
        "cast_mod_flat",
        "cast_mod",
        "extra_dur_flat",
        "extra_dur",
        "extra_tick_time_flat",
        "cost_mod",
        "cost_mod_flat",
        "crit_mod",
        "hit",
        "sp_flat",
        "flat_add",
        "flat_add_ot",
        "refund",
        "coef_mod",
        "coef_mod_flat",
        "effect_mod_only_heal",
        "jumps_flat",
        "jump_amp",
        "gcd_flat",
    },
    -- effects that affects the base value (points) of other subauras
    -- indexed by the aura internal idx
    aura_pts = {
        -1, 0, 1, 2, 3, 4
    },
    aura_pts_flat = {
        -1, 0, 1, 2, 3, 4
    },
    wpn_subclass = {
        "phys_crit",
        "phys_crit_forced",
        "phys_crit_mod",
        "phys_hit",
        "phys_dmg",
        "phys_dmg_flat",
        "skill_flat",
    },
    creature = {
        "crit_mod"
    },
    raw = {
        "mana_mod",
        "mana_mod_forced",
        "mana",
        "hp_flat",
        "hp_mod",
        "hp_mod_forced",
        "mp5_from_int_mod",
        "mp5_flat",
        "perc_max_mana_as_mp5",
        "regen_while_casting",
        "healing_power_flat",
        "phys_dmg_flat",
        "ap_flat",
        "ap_mod",
        "ap_mod_forced",
        "rap_flat",
        "rap_mod",
        "rap_mod_forced",
        "cost_mod",
        "phys_hit",
        "phys_crit",
        "phys_crit_forced",
        "offhand_mod",
        "extra_hits_flat",
        "skill",
        "class_misc",
        "base_res_phys_flat",
        "base_res_phys_mod",
        "base_res_phys_mod_forced",
        "res_phys_mod",
        "res_phys_mod_forced",
        "base_phys_res_flat",
        "phys_res_flat",
        "block",
        "dodge",
        "parry",
        "can_block",
        "attacker_melee_crit",

        "wpn_subclass_mh",
        "wpn_subclass_oh",
        "wpn_subclass_ranged",
        "wpn_min_mh",
        "wpn_max_mh",
        "wpn_min_oh",
        "wpn_max_oh",
        "wpn_min_ranged",
        "wpn_max_ranged",
        "wpn_delay_mh",
        "wpn_delay_oh",
        "wpn_delay_ranged",
        "wpn_school_ranged",
        "ammo_dps",
    },
};


for _, v in ipairs(ratings) do
    local raw = effects_additive.raw;
    raw[#raw + 1] = v[2].."_flat";
end

local effects_multiplicative = {
    by_school = {
        "vuln_mod",
        "dmg_mod",
    },
    ability = {
        "vuln_mod",
        "cast_haste",
        "heal_mod",
        "thp_based_vuln_mod",
    },
    wpn_subclass = {
        "phys_mod",
        "spell_mod", -- Wand mods apply this
    },
    creature = {
        "dmg_mod",
    },
    raw = {
        "phys_mod",
        "heal_mod",
        "vuln_heal",
        "vuln_phys",
        "melee_haste",
        "melee_haste_forced",
        "ranged_haste",
        "ranged_haste_forced",
        "cast_haste",
        "vuln_bleed",

        "player_vuln_phys",
    },
};

local function empty_effects(effects)

    effects.mul = {};
    for _, v in ipairs(effect_categories) do
        effects[v] = {};
        effects.mul[v] = {};
    end

    for _, v in pairs(effects_additive.by_school) do
        effects.by_school[v] = {0, 0, 0, 0, 0, 0, 0};
    end
    for _, v in pairs(effects_additive.by_attr) do
        effects.by_attr[v] = {0, 0, 0, 0, 0};
    end
    for _, v in pairs(effects_additive.ability) do
        effects.ability[v] = {};
    end
    for _, v in pairs(effects_additive.aura_pts) do
        effects.aura_pts[v] = {};
    end
    for _, v in pairs(effects_additive.aura_pts_flat) do
        effects.aura_pts_flat[v] = {};
    end
    for _, v in pairs(effects_additive.wpn_subclass) do
        effects.wpn_subclass[v] = {};
    end
    for _, v in pairs(effects_additive.creature) do
        effects.creature[v] = {};
    end
    for _, v in pairs(effects_additive.raw) do
        effects.raw[v] = 0;
    end

    effects.enchants = {};
    effects.num_set_pieces = {};
    effects.talent_pts = {};

    for _, v in pairs(effects_multiplicative.by_school) do
        effects.mul.by_school[v] = {1, 1, 1, 1, 1, 1, 1};
    end
    for _, v in pairs(effects_multiplicative.ability) do
        effects.mul.ability[v] = {};
    end
    for _, v in pairs(effects_multiplicative.wpn_subclass) do
        effects.mul.wpn_subclass[v] = {};
    end
    for _, v in pairs(effects_multiplicative.creature) do
        effects.mul.creature[v] = {};
    end
    for _, v in pairs(effects_multiplicative.raw) do
        effects.mul.raw[v] = 1;
    end

    effects.finalized = false;
end

local function zero_effects(effects)

    for _, cat in ipairs(effect_categories) do
        local effect_cat = effects[cat];
        for i, e in pairs(effect_cat) do
            if type(e) == "table" then
                for j, _ in pairs(e) do
                    e[j] = 0.0;
                end
            else
                effect_cat[i] = 0.0;
            end
        end
    end

    for _, cat in ipairs(effect_categories) do
        local effect_cat = effects.mul[cat]
        for i, e in pairs(effect_cat) do
            if type(e) == "table" then
                for j, _ in pairs(e) do
                    e[j] = 1.0;
                end
            else
                effect_cat[i] = 1.0;
            end
        end
    end
    effects.finalized = false;
end

local function zero_effects_dynamic_fields(effects)
    -- a few specific fields are dynamic
    for k, v in pairs(effects.enchants) do
        effects.enchants[k] = 0;
    end
    for k, v in pairs(effects.num_set_pieces) do
        effects.num_set_pieces[k] = 0;
    end
    for k, v in pairs(effects.talent_pts) do
        effects.talent_pts[k] = 0;
    end
end

local function cpy_effects(dst, src)

    zero_effects_dynamic_fields(dst);

    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst[cat];
        local src_cat = src[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, _ in pairs(dst_e) do
                    if not src_e[j] then
                        -- zero values in dst that are not in src
                        dst_e[j] = 0.0;
                    end
                end

                for j, _ in pairs(src_e) do
                    dst_e[j] = src_e[j];
                end
            else

                dst_cat[i] = src_cat[i];
            end
        end

    end

    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst.mul[cat];
        local src_cat = src.mul[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, _ in pairs(dst_e) do
                    if not src_e[j] then
                        -- prevent values in src that are not in dst
                        dst_e[j] = 1.0;
                    end
                end

                for j, _ in pairs(src_e) do
                    dst_e[j] = src_e[j];
                end
            else
                dst_cat[i] = src_cat[i];
            end
        end
    end

    dst.finalized = src.finalized;
end

local function effects_add(dst, src)


    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst[cat];
        local src_cat = src[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, v in pairs(src_e) do
                    dst_e[j] = (dst_e[j] or 0.0) + v;
                end
            else
                dst_cat[i] = (dst_cat[i] or 0.0) + src_cat[i];
            end
        end
    end
    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst.mul[cat];
        local src_cat = src.mul[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, v in pairs(src_e) do
                    dst_e[j] = (dst_e[j] or 1.0) * v;
                end
            else
                dst_cat[i] = dst_cat[i] * src_cat[i];
            end
        end
    end
    if __spellcoda_debug__ and (dst.finalized or src.finalized) then
        print("FAILURE: Adding effects with finalized");
        --print ("\nCall stack: \n" .. debugstack(2, 3, 2));
    end
end

local function effects_negate_for_diff(dst, src)

    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst[cat];
        local src_cat = src[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, v in pairs(src_e) do
                    dst_e[j] = (dst_e[j] or 0.0) - v;
                end
            else
                dst_cat[i] = dst_cat[i] - src_cat[i];
            end
        end
    end
    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst.mul[cat];
        local src_cat = src.mul[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, v in pairs(src_e) do
                    dst_e[j] = (dst_e[j] or 1.0) / v;
                end
            else
                dst_cat[i] = dst_cat[i] / src_cat[i];
            end
        end
    end
end

local function add_field_line(info, val, txt, diff, perc, mul, raw, extras)
    local red = (diff and "|cFFC32C0B") or "|cFFFFFFFF";
    local green = (diff and "|cFF21B915") or "|cFFFFFFFF";
    local stat_color = "|cFFFFD100";

    if diff and extras then
        stat_color = "|cFFB5B09B";
    end

    local force_add = false;
    local val_str;
    if type(val) == "number" then
        local perc_symbol = "";
        local val_disp = val;
        if not raw then
            if mul then
                perc = true;
                val_disp = val_disp - 1;
            end
            if perc then
                val_disp = 100*val_disp;
                perc_symbol = "%";
            end
        end
        local abs_val = math.abs(val_disp);
        if abs_val == math.floor(abs_val) then
            val_str = string.format("%.0f", abs_val)
        else
            val_str = string.format("%.3f", abs_val):gsub("%.?0+$", "");
        end

        val_str = val_str..perc_symbol;
    elseif type(val) == "string" then
        val_str = val;
        force_add = true;
    else
        return false;
    end

    if force_add or (mul and val > 1) or (not mul and val > 0) then
        info.num_in = info.num_in + 1;
        info.str = info.str..string.format("%s+ %s|r %s%s|r\n", green, val_str, stat_color, txt);
        return true;
    elseif (mul and val < 1) or (not mul and val < 0) then
        info.num_out = info.num_out + 1;
        info.str = info.str..string.format("%s-  %s|r %s%s|r\n", red, val_str, stat_color, txt);
        return true;
    end
end

local stat_diff_flags = {

    tank          = bit.lshift(1, 1),
    melee         = bit.lshift(1, 2),
    ranged        = bit.lshift(1, 3),
    caster        = bit.lshift(1, 4),
    healer        = bit.lshift(1, 5),

    spells        = bit.lshift(1, 6),
};

local lnames;
local function init_lnames()
    -- this function is called once after localized strings have been loaded

    lnames = {
        schools =
            {L["Physical"], L["Holy"], L["Fire"], L["Nature"], L["Frost"], L["Shadow"], L["Arcane"]},
        attributes =
            {L["Strength"], L["Agility"], L["Stamina"], L["Intellect"], L["Spirit"]},
            -- some selected ability fields to show
        ability_additive_fields = {      -- lname,                      -is percentage
            {"threat",                  L["Threat"],                        true},
            {"threat_flat",             L["Threat"],                            },
            {"crit",                    L["Critical"],                      true},
            {"ignore_cant_crit",        L["Can crit"],                          },
            {"effect_mod",              L["Effect modifier"],               true},
            {"effect_mod_flat",         L["Effect modifier"],                   },
            {"effect_mod_ot",           L["Periodic effect modifier"],      true},
            {"effect_mod_ot_flat",      L["Periodic effect modifier"],          },
            {"base_mod",                L["Base effect modifier"],          true},
            {"base_mod_flat",           L["Base effect modifier"],              },
            {"base_mod_ot",             L["Base periodic effect modifier"], true},
            {"base_mod_ot_flat",        L["Base periodic effect modifier"],     },
            {"cast_mod_flat",           L["Cast time modifier"],                },
            {"cast_mod",                L["Cast time modifier"],            true},
            {"extra_dur_flat",          L["Extra duration"],                    },
            {"extra_dur",               L["Extra duration"],                    },
            {"extra_tick_time_flat",    L["Extra tick time"],                   },
            {"cost_mod",                L["Cost modifier"],                 true},
            {"cost_mod_flat",           L["Cost modifier"],                     },
            {"crit_mod",                L["Critical damage modifier"],      true},
            {"hit",                     L["Hit"],                           true},
            {"sp_flat",                 L["Spell power"],                       },
            {"flat_add",                L["Additional effect"],                 },
            {"flat_add_ot",             L["Additional periodic effect"],        },
            {"refund",                  L["Refunds"],                           },
            {"coef_mod",                L["Coefficient modifier"],          true},
            {"coef_mod_flat",           L["Coefficient modifier"],              },
            {"effect_mod_only_heal",    L["Healing modifier"],              true},
            {"jumps_flat",              L["Extra jumps"],                       },
            {"jump_amp",                L["Jump amplifier"],                true},
            {"gcd_flat",                L["GCD modifier"],                      },
        },
        ability_multiplicative_fields = { -- lname,                  -is percentage
            {"vuln_mod",                  L["Threat"],                      true},
            {"cast_haste",                L["Spell cast haste"],            true},
            {"heal_mod",                  L["Healing modifier"],            true},
        };
    };
    local rating_lnames = {
        [combat_ratings.CR_DEFENSE_SKILL                    ]   = { L["Defense skill rating"],              stat_diff_flags.tank, true},
        [combat_ratings.CR_DODGE                            ]   = { L["Dodge rating"],                      stat_diff_flags.tank },
        [combat_ratings.CR_PARRY                            ]   = { L["Parry rating"],                      stat_diff_flags.tank },
        [combat_ratings.CR_BLOCK                            ]   = { L["Block rating"],                      stat_diff_flags.tank },
        [combat_ratings.CR_HASTE_SPELL                      ]   = { L["Spell haste rating"],                bit.bor(stat_diff_flags.caster, stat_diff_flags.healer) },
        [combat_ratings.CR_HASTE_MELEE                      ]   = { L["Melee haste rating"],                stat_diff_flags.melee },
        [combat_ratings.CR_HASTE_RANGED                     ]   = { L["Ranged haste rating"],               stat_diff_flags.ranged },
        [combat_ratings.CR_HIT_SPELL                        ]   = { L["Spell hit rating"],                  stat_diff_flags.caster },
        [combat_ratings.CR_HIT_MELEE                        ]   = { L["Melee hit rating"],                  stat_diff_flags.melee },
        [combat_ratings.CR_HIT_RANGED                       ]   = { L["Ranged hit rating"],                 stat_diff_flags.ranged },
        [combat_ratings.CR_CRIT_SPELL                       ]   = { L["Spell critical rating"],             bit.bor(stat_diff_flags.caster, stat_diff_flags.healer) },
        [combat_ratings.CR_CRIT_MELEE                       ]   = { L["Melee critical rating"],             stat_diff_flags.melee },
        [combat_ratings.CR_CRIT_RANGED                      ]   = { L["Ranged critical rating"],            stat_diff_flags.ranged },
        [combat_ratings.CR_EXPERTISE                        ]   = { L["Expertise critical rating"],         stat_diff_flags.melee, true},

        [combat_ratings.CR_RESILIENCE_CRIT_TAKEN            ]   = { L["Resilience critical chance rating"], bit.bnot(0) },
        [combat_ratings.CR_RESILIENCE_PLAYER_DAMAGE_TAKEN   ]   = { L["Resilience critical damage rating"], bit.bnot(0) },
    };
    for k, _ in pairs(ratings) do
        ratings[k][3] =  rating_lnames[ratings[k][1]][1] or ""; -- lname
        ratings[k][4] =  rating_lnames[ratings[k][1]][2]; -- stat_diff_flags
        ratings[k][5] =  rating_lnames[ratings[k][1]][3]; -- is percentage
    end
end

local stat_diff_flag_options = {
    tooltip_item_stat_diff_tank             = "tank",
    tooltip_item_stat_diff_melee            = "melee",
    tooltip_item_stat_diff_ranged           = "ranged",
    tooltip_item_stat_diff_caster           = "caster",
    tooltip_item_stat_diff_healer           = "healer",
    tooltip_item_stat_diff_spells           = "spells",
};
local attribute_flags_req = {
    stat_diff_flags.melee,                                   -- str
    bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged),  -- agi
    bit.bor(
        stat_diff_flags.tank,
        stat_diff_flags.melee,
        stat_diff_flags.ranged,
        stat_diff_flags.caster,
        stat_diff_flags.healer),                            -- stam
    bit.bor(stat_diff_flags.caster, stat_diff_flags.healer), -- int
    bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)  -- spirit
};

local function human_friendly_fields(loadout, effects, is_diff, loadout_data, effects_before, effects_after)
    -- if is_diff is true, loadout should be nil and effects is the diffed effects
    -- loadout_data, effects_before and effects_after need to be supplied for edge cases when doing diffs

    local stat_flags = 0;
    for conf_key, flag_name in pairs(stat_diff_flag_options) do
        if config.settings[conf_key] then
            stat_flags = bit.bor(stat_flags, stat_diff_flags[flag_name]);
        end
    end


    local cr_scaling = loadout_data.cr_scaling;

    local info = {
        str = "",
        num_in = 0;
        num_out = 0;
    };

    if stat_flags == 0 then

        return info.str, info.num_in + info.num_out, info.num_in, info.num_out;
    end

    -- When diffed, attributes and ratings are grayed out a bit as to indicate
    -- that when e.g. +1 agility is not additive to the consequent + crit%, dodge% and armor which is also displayed

    ---------------------------------
    --- Attributes
    ---------------------------------
    for i, v in ipairs(lnames.attributes) do
        if bit.band(stat_flags, attribute_flags_req[i]) ~= 0 then
            local val = ((loadout and loadout.stats[i]) or 0)
                +
                effects.by_attr.stat_flat[i];

            add_field_line(info, val, v, is_diff, nil, nil, nil, true);
        end
    end
    ---------------------------------
    --- Ratings
    ---------------------------------
    for _, v in ipairs(ratings) do
        local req_flags = v[4];
        if bit.band(stat_flags, req_flags) ~= 0 then
            local val = ((loadout and loadout[v[2]]) or 0)
                +
                effects.raw[v[2].."_flat"];
            local is_percentage = not v[5];
            local rating_type = v[1];
            local val_resolved = val/(cr_scaling * cr_weights[rating_type]);

            if is_percentage then
                add_field_line(info, val, string.format("(%s%%) %s",string.format("%.2f", val_resolved):gsub("%.?0+$", ""), v[3]), is_diff, nil, nil, nil, true);
            else
                add_field_line(info, val, string.format("(%.1f) %s", val_resolved, v[3]), is_diff, nil, nil, nil, true);
            end
        end
    end

    ---------------------------------
    --- Attack power
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.melee) ~= 0 then
        local val = ((loadout and loadout.ap) or 0)
            +
            effects.raw.ap_flat;
        add_field_line(info, val, L["Melee attack power"], is_diff);
    end
    ---------------------------------
    --- Ranged attack power
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.ranged) ~= 0 then
        local val = ((loadout and loadout.rap) or 0)
            +
            effects.raw.rap_flat;
        add_field_line(info, val, L["Ranged attack power"], is_diff);
    end
    ---------------------------------
    --- Health
    ---------------------------------
    if bit.band(stat_flags,
        bit.bor(
            stat_diff_flags.tank,
            stat_diff_flags.melee,
            stat_diff_flags.ranged,
            stat_diff_flags.caster,
            stat_diff_flags.healer)
        ) ~= 0 then
        local val = ((loadout and loadout.player_hp_max) or 0)
            +
            effects.raw.hp_flat;
        add_field_line(info, val, L["Health"], is_diff);
    end
    ---------------------------------
    --- Mana
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local val = ((loadout and loadout.resources_max[powers.mana]) or 0)
            +
            effects.raw.mana;
        add_field_line(info, val, L["Mana"], is_diff);
    end
    ---------------------------------
    --- Armor
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.tank) ~= 0 then
        local val = ((loadout and loadout.armor) or 0)
            +
            effects.by_school.res_flat[schools.physical];
        add_field_line(info, val, L["Armor"], is_diff);
    end
    ---------------------------------
    --- Spell damage
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.caster) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do
            local val = ((loadout and loadout.spell_dmg_by_school[i]) or 0)
                +
                effects.by_school.sp_dmg_flat[i];
                school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = ((loadout and loadout.spell_dmg_by_school[i]) or 0)
                    +
                    effects.by_school.sp_dmg_flat[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell damage"], is_diff);
            end
        else
            add_field_line(info, school_prev, L["Spell damage"], is_diff);
        end
    end

    ---------------------------------
    --- Healing power
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.healer) ~= 0 then
        local val = ((loadout and loadout.healing_power) or 0)
            +
            effects.raw.healing_power_flat;
        add_field_line(info, val, L["Healing power"], is_diff);
    end

    ---------------------------------
    --- Melee crit
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.melee) ~= 0 then
        local val = ((loadout and loadout.melee_crit) or 0)
            +
            0.01*effects.raw.melee_crit_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_CRIT_MELEE])
            +
            effects.raw.phys_crit_forced;
        add_field_line(info, val, L["Physical critical chance"], is_diff, true);
    end
    ---------------------------------
    --- Ranged crit
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.ranged) ~= 0 then
        local val = ((loadout and loadout.ranged_crit) or 0)
            +
            0.01*effects.raw.ranged_crit_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_CRIT_RANGED])
            +
            effects.raw.phys_crit_forced;
        add_field_line(info, val, L["Ranged critical chance"], is_diff, true);
    end
    ---------------------------------
    --- Spell crit
    ---------------------------------

    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = ((loadout and loadout.spell_crit_by_school[i]) or 0)
                +
                effects.by_school.crit_forced[i]
                +
                0.01*effects.raw.spell_crit_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_CRIT_SPELL]);

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = ((loadout and loadout.spell_crit_by_school[i]) or 0)
                    +
                    effects.by_school.crit_forced[i]
                    +
                    0.01*effects.raw.spell_crit_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_CRIT_SPELL]);
                add_field_line(info, val, lnames.schools[i].." "..L["spell critical chance"], is_diff, true);
            end
        else
            add_field_line(info, school_prev, L["Spell critical chance"], is_diff, true);
        end
    end

    ---------------------------------
    --- Melee hit
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.melee) ~= 0 then
        local val = 
            effects.raw.phys_hit
            +
            0.01*(((loadout and loadout.melee_hit_rating) or 0) + effects.raw.melee_hit_rating_flat)/
                (cr_scaling * cr_weights[combat_ratings.CR_HIT_MELEE]);
        add_field_line(info, val, L["Melee hit chance"], is_diff, true);
    end
    ---------------------------------
    --- Ranged hit
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.ranged) ~= 0 then
        local val =
            effects.raw.phys_hit
            +
            0.01*(((loadout and loadout.ranged_hit_rating) or 0) + effects.raw.ranged_hit_rating_flat)/
                (cr_scaling * cr_weights[combat_ratings.CR_HIT_RANGED]);
        add_field_line(info, val, L["Ranged hit chance"], is_diff, true);
    end
    ---------------------------------
    --- Spell hit
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.caster) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = ((loadout and loadout.spell_dmg_hit_by_school[i]) or 0)
                +
                effects.by_school.spell_hit[i]
                +
                0.01*(((loadout and loadout.spell_hit_rating) or 0) + effects.raw.spell_hit_rating_flat)/
                    (cr_scaling * cr_weights[combat_ratings.CR_HIT_SPELL]);

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = ((loadout and loadout.spell_dmg_hit_by_school[i]) or 0)
                    +
                    effects.by_school.spell_hit[i]
                    +
                    0.01*(((loadout and loadout.spell_hit_rating) or 0) + effects.raw.spell_hit_rating_flat)/
                        (cr_scaling * cr_weights[combat_ratings.CR_HIT_SPELL]);
                add_field_line(info, val, lnames.schools[i].." "..L["spell hit chance"], is_diff, true);
            end
        else
            add_field_line(info, school_prev, L["Spell hit chance"], is_diff, true);
        end
    end

    ---------------------------------
    --- Melee haste multiplier
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.melee) ~= 0 then
        local haste_mul_from_rating = 1.0 +
            0.01*(((loadout and loadout.melee_haste_rating) or 0)+effects.raw.melee_haste_rating_flat)/
                (cr_scaling * cr_weights[combat_ratings.CR_HASTE_MELEE]);
        add_field_line(info,
            effects.mul.raw.melee_haste*effects.mul.raw.melee_haste_forced*haste_mul_from_rating,
            L["Melee haste"], is_diff, true, true);
    end
    ---------------------------------
    --- Ranged haste multiplier
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.ranged) ~= 0 then
        local haste_mul_from_rating = 1.0 +
            0.01*(((loadout and loadout.ranged_haste_rating) or 0)+effects.raw.ranged_haste_rating_flat)/
                (cr_scaling * cr_weights[combat_ratings.CR_HASTE_RANGED]);
        add_field_line(info,
            effects.mul.raw.ranged_haste*effects.mul.raw.ranged_haste_forced*haste_mul_from_rating,
            L["Ranged haste"], is_diff, true, true);
    end
    ---------------------------------
    --- Spell haste multiplier
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local haste_mul_from_rating = 1.0 +
            0.01*(((loadout and loadout.spell_haste_rating) or 0)+effects.raw.spell_haste_rating_flat)/
                (cr_scaling * cr_weights[combat_ratings.CR_HASTE_SPELL]);
        add_field_line(info,
            effects.mul.raw.cast_haste*haste_mul_from_rating,
            L["Spell cast haste"], is_diff, true, true);
    end
    ---------------------------------
    --- Mana regen
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        -- Don't show mp5 stat since it's already baked into other field
        --add_field_line(info, effects.raw.mp5_flat, L["mana every 5 sec"], is_diff);
        add_field_line(info, effects.raw.regen_while_casting, L["Mana regen while casting"], is_diff, true);

        -- Some problems here: in tbc spirit_mana_regen is non linear and cannot be used on simple diff
        -- split into two cases if we are doing diff or not

        local mp1_casting;
        local mp1_not_casting;
        if is_diff then
            -- must do mana regen calc from the ground up with
            local spirit = loadout_data.stats[attr.spirit];
            local intellect = loadout_data.stats[attr.intellect];

            local spirit_before = spirit + effects_before.by_attr.stat_flat[attr.spirit];
            local intellect_before = intellect + effects_before.by_attr.stat_flat[attr.intellect];

            local spirit_after = spirit + effects_after.by_attr.stat_flat[attr.spirit];
            local intellect_after = intellect + effects_after.by_attr.stat_flat[attr.intellect];

            local mp2_not_casting_before = spirit_mana_regen(spirit_before, intellect_before);
            local mp2_not_casting_after = spirit_mana_regen(spirit_after, intellect_after);

            local mp2_not_casting = mp2_not_casting_after - mp2_not_casting_before;

            local mp5 = effects.raw.mp5_flat
                +
                effects.raw.mana * effects_after.raw.perc_max_mana_as_mp5
                +
                effects.by_attr.stat_flat[attr.intellect] * effects_after.raw.mp5_from_int_mod;

            mp1_casting =
                0.2 * mp5 +
                0.5 * mp2_not_casting * math.max(0, math.min(1.0, effects_after.raw.regen_while_casting));
            mp1_not_casting =
                0.2 * mp5 +
                0.5 * mp2_not_casting;

        else
            local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];
            local intellect = loadout.stats[attr.intellect] + effects.by_attr.stat_flat[attr.intellect];
            local mp2_not_casting = spirit_mana_regen(spirit, intellect);

            local mp5 = effects.raw.mp5_flat
                +
                (effects.raw.mana + loadout.resources_max[powers.mana])  * effects.raw.perc_max_mana_as_mp5
                +
                effects.raw.mp5_from_int_mod * intellect;

            mp1_casting =
                0.2 * mp5 +
                0.5 * mp2_not_casting * math.max(0, math.min(1.0, effects.raw.regen_while_casting));
            mp1_not_casting =
                0.2 * mp5 +
                0.5 * mp2_not_casting;
        end

        add_field_line(info, mp1_casting, L["Mana regen per sec while casting"], is_diff);
        add_field_line(info, mp1_not_casting, L["Mana regen per sec while not casting"], is_diff);
    end
    ---------------------------------
    --- Dodge chance
    ---------------------------------

    if bit.band(stat_flags, stat_diff_flags.tank) ~= 0 then
        local val = ((loadout and loadout.dodge) or 0)
            +
            effects.raw.dodge
            +
            0.0004*effects.raw.defense_skill_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_DEFENSE_SKILL])
            +
            0.01*effects.raw.dodge_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_DODGE]);
        add_field_line(info, val, L["Dodge"], is_diff, true);
    end

    ---------------------------------
    --- Parry chance
    ---------------------------------

    if bit.band(stat_flags, stat_diff_flags.tank) ~= 0 then
        if loadout_data.parry ~= 0 then
            local val = ((loadout and loadout.parry) or 0)
                +
                effects.raw.parry
                +
                0.0004*effects.raw.defense_skill_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_DEFENSE_SKILL])
                +
                0.01*effects.raw.parry_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_PARRY]);
            add_field_line(info, val, L["Parry"], is_diff, true);
        end
    end

    ---------------------------------
    --- Block chance
    ---------------------------------

    if bit.band(stat_flags, stat_diff_flags.tank) ~= 0 then
        if effects.raw.can_block > 0 then

            local val = ((loadout and loadout.block) or 0)
                +
                effects.raw.block
                +
                0.0004*effects.raw.defense_skill_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_DEFENSE_SKILL])
                +
                0.01*effects.raw.block_rating_flat/(cr_scaling * cr_weights[combat_ratings.CR_BLOCK]);

            if loadout_data.block then
                add_field_line(info, val, L["Block"], is_diff, true);
            end
        end
    end

    ---------------------------------
    --- Armor penetration
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, -effects.by_school.target_res_flat[schools.physical], L["Armor penetration"], is_diff);
        add_field_line(info, effects.by_school.target_res[schools.physical], L["Armor penetration"], is_diff, true);
    end
    ---------------------------------
    --- Spell peneteration
    ---------------------------------

    if bit.band(stat_flags, stat_diff_flags.caster) ~= 0 then
        local can_compact = true;
        local school_prev;
        -- Holy (i=2) spell pen not included in most spell penetration stats effects?
        -- ignore 2 in order to be able to compact the other magical spells into one field
        for i = 3, 7 do

            local val = -effects.by_school.target_res_flat[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 3, 7 do
                local val = -effects.by_school.target_res_flat[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell penetration"], is_diff);
            end
        else
            add_field_line(info, school_prev, L["Spell penetration"], is_diff);
        end
    end

    ---------------------------------
    --- Spell critical effect modifier
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = effects.by_school.crit_mod[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = effects.by_school.crit_mod[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell critical damage modifier"], is_diff, true);
            end
        else
            add_field_line(info, school_prev, L["Spell critical damage modifier"], is_diff, true);
        end
    end
    ---------------------------------
    --- Spell cost modifier
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = effects.by_school.cost_mod[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = effects.by_school.cost_mod[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell cost"], is_diff, true);
            end
        else
            add_field_line(info, school_prev, L["Spell cost"], is_diff, true);
        end
    end

    ---------------------------------
    --- Physical threat
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.tank, stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, effects.by_school.threat[schools.physical], L["Physical threat"], is_diff, true);
    end

    ---------------------------------
    --- Spell threat
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.tank, stat_diff_flags.caster, stat_diff_flags.healer)) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = effects.by_school.threat[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = effects.by_school.threat[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell threat"], is_diff, true);
            end
        else
            add_field_line(info, school_prev, L["Spell threat"], is_diff, true);
        end
    end
    ---------------------------------
    --- % Stats
    ---------------------------------
    if stat_flags ~= 0 then
        local can_compact = true;
        local attr_prev;
        for i = 1, 5 do

            local val = effects.by_attr.stat_mod[i] + effects.by_attr.stat_mod_forced[i];

            attr_prev = attr_prev or val;

            if val ~= attr_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 1, 5 do
                local val = effects.by_attr.stat_mod[i] + effects.by_attr.stat_mod_forced[i];
                if bit.band(stat_flags, attribute_flags_req[i]) ~= 0 then
                    add_field_line(info, val, lnames.attributes[i], is_diff, true);
                end
            end
        else
            add_field_line(info, attr_prev, L["All stats"], is_diff, true);
        end
    end

    ---------------------------------
    --- Weapon slots
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, effects.raw.wpn_min_mh, L["Main hand minimum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_max_mh, L["Main hand maximum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_delay_mh, L["Main hand delay"], is_diff);
        add_field_line(info, effects.raw.wpn_min_oh, L["Offhand minimum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_max_oh, L["Offhand maximum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_delay_oh, L["Offhand attack delay"], is_diff);
    end
    if bit.band(stat_flags, stat_diff_flags.ranged) ~= 0 then
        add_field_line(info, effects.raw.wpn_min_ranged, L["Ranged minimum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_max_ranged, L["Ranged maximum damage"], is_diff);
        add_field_line(info, effects.raw.wpn_delay_ranged, L["Ranged attack delay"], is_diff);
    end
    ---------------------------------
    --- Physical damage
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, effects.raw.phys_dmg_flat, L["Physical damage"], is_diff);
    end

    ---------------------------------
    --- Physical damage modifier
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, effects.mul.raw.phys_mod, L["Physical damage"], is_diff, true, true);
    end
    ---------------------------------
    --- Physical damage taken (target)
    ---------------------------------
    if bit.band(stat_flags, bit.bor(stat_diff_flags.melee, stat_diff_flags.ranged)) ~= 0 then
        add_field_line(info, effects.mul.raw.vuln_phys, L["Target physical damage taken"], is_diff, true, true);
    end

    ---------------------------------
    --- Spell damage multiplier
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.caster) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = effects.mul.by_school.dmg_mod[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = effects.mul.by_school.dmg_mod[i];
                add_field_line(info, val, lnames.schools[i].." "..L["spell damage"], is_diff, true, true);
            end
        else
            add_field_line(info, school_prev, L["Spell damage"], is_diff, true, true);
        end
    end
    ---------------------------------
    --- Spell damage taken (target)
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.caster) ~= 0 then
        local can_compact = true;
        local school_prev;
        for i = 2, 7 do

            local val = effects.mul.by_school.vuln_mod[i];

            school_prev = school_prev or val;

            if val ~= school_prev then
                can_compact = false;
                break;
            end
        end
        if not can_compact then
            for i = 2, 7 do
                local val = effects.mul.by_school.vuln_mod[i];
                add_field_line(info, val, L["Target"].." "..lnames.schools[i].." "..L["spell damage taken"], is_diff, true, true);
            end
        else
            add_field_line(info, school_prev, L["Target spell damage taken"], is_diff, true, true);
        end
    end

    ---------------------------------
    --- Healing modifier
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.healer) ~= 0 then
        add_field_line(info, effects.mul.raw.heal_mod, L["Healing"], is_diff, true, true);
    end
    ---------------------------------
    --- Healing taken (target)
    ---------------------------------
    if bit.band(stat_flags, stat_diff_flags.healer) ~= 0 then
        add_field_line(info, effects.mul.raw.vuln_heal, L["Target healing taken"], is_diff, true, true);
    end

    ---------------------------------
    --- Ability effects
    ---------------------------------

    if bit.band(stat_flags, stat_diff_flags.spells) ~= 0 then
        for k, v in ipairs(lnames.ability_additive_fields) do
            local val_last;
            for spell_id, val in pairs(effects.ability[v[1]]) do

                if val_last == val then
                    -- same value as previous thing, just add append this spell name
                    -- info.str now ends with "\n", need to move it to appended string
                    info.str = info.str:sub(1, -2)..", "..spell_lname(spell_id).."\n";
                else
                    if (add_field_line(info, val, v[2]..": "..spell_lname(spell_id), is_diff, v[3])) then
                        val_last = val;
                    end
                end

            end
        end

        for k, v in ipairs(lnames.ability_multiplicative_fields) do

            local val_last;
            for spell_id, val in pairs(effects.mul.ability[v[1]]) do

                if val_last == val then
                    -- same value as previous thing, just add append this spell name
                    -- info.str now ends with "\n", need to move it to appended string
                    info.str = info.str:sub(1, -2)..", "..spell_lname(spell_id).."\n";
                else
                    if (add_field_line(info, val, v[2]..": "..spell_lname(spell_id), is_diff, v[3], true)) then
                        val_last = val;
                    end
                end
            end
        end
    end

    return info.str, info.num_in + info.num_out, info.num_in, info.num_out;
end



local function loadout_raw_dump(loadout, diff)

    local info = {
        str = "",
        num_in = 0;
        num_out = 0;
    };

    for _, v in ipairs(loadout_numbers) do
        add_field_line(info, loadout[v], v, diff, false)
    end
    for _, v in ipairs(loadout_strs) do
        add_field_line(info, loadout[v], v, diff, false)
    end
    for k, _ in pairs(loadout_tables) do
        for kk in pairs(loadout[k]) do
            add_field_line(info, loadout[k][kk], k..":"..kk, diff, false)
        end
    end
    return info.str, info.num_in + info.num_out, info.num_in, info.num_out;
end

local function effects_raw_dump(effects, diff)
    local info = {
        str = "",
        num_in = 0;
        num_out = 0;
    };

    for _, cat in ipairs(effect_categories) do
        local effect_cat = effects[cat];
        for i, e in pairs(effect_cat) do
            if type(e) == "table" then
                for j, _ in pairs(e) do
                    add_field_line(info, e[j], cat..":"..i..":"..j, diff, false, false, true);
                end
            else
                add_field_line(info, effect_cat[i], cat..":"..i, diff, false, false, true);
            end
        end
    end

    for _, cat in ipairs(effect_categories) do
        local effect_cat = effects.mul[cat]
        for i, e in pairs(effect_cat) do
            if type(e) == "table" then
                for j, _ in pairs(e) do
                    add_field_line(info, e[j], "mul:"..cat..":"..i..":"..j, diff, false, true, true);
                end
            else
                add_field_line(info, effect_cat[i], "mul:"..cat..":"..i, diff, false, true, true);
            end
        end
    end

    return info.str, info.num_in + info.num_out, info.num_in, info.num_out;
end

local effects_diff_buffer = {};
empty_effects(effects_diff_buffer);

local function stats_diff_format(loadout, effects_before, effects_after)

    if __spellcoda_debug__ and (not effects_before.finalized or not effects_after.finalized) then
        print("FAILURE: Stat diff formatting without finalized effects");
        --print ("\nCall stack: \n" .. debugstack(2, 3, 2));
    end

    cpy_effects(effects_diff_buffer, effects_after);
    effects_negate_for_diff(effects_diff_buffer, effects_before);

    if config.settings.general_calc_stats_raw_dump then
        return effects_raw_dump(effects_diff_buffer, true);
    else
        return human_friendly_fields(nil, effects_diff_buffer, true, loadout, effects_before, effects_after);
    end
end

local function stats_format(loadout, effects)
    if __spellcoda_debug__ and not effects.finalized then
        print("FAILURE: Stat formatting without finalized effects");
        --print ("\nCall stack: \n" .. debugstack(2, 3, 2));
    end

    if config.settings.general_calc_stats_raw_dump then
        local lstr, ltotal, lnum_in, lnum_out = loadout_raw_dump(loadout, true);
        local str, total, num_in, num_out = effects_raw_dump(effects, true);
        return
            "Loadout\n"..lstr.."Effects\n"..str,
            ltotal + total,
            lnum_in + num_in,
            lnum_out + num_out;
    else
        return human_friendly_fields(loadout, effects, false, loadout, effects, effects);
    end
end

local function manual_effects_zero_diff()
    return {
        int = 0,
        agi = 0,
        spirit = 0,
        str = 0,
        stam = 0,
        mp5 = 0,
        sp = 0,
        sd = 0,
        hp = 0,
        ap = 0,
        rap = 0,
        hit_rating = 0,
        haste_rating = 0,
        crit_rating = 0,
        expertise_rating = 0,
        dodge_rating = 0,
        parry_rating = 0,
        defense_skill_rating = 0,
        pen = 0,
        weapon_skill = 0,
        extra_mana = 0,
        armor = 0,
        resilience_rating = 0,
    };
end

local function effects_add_manual_diff(effects, diff)

    effects.by_attr.stat_flat[attr.stamina] = effects.by_attr.stat_flat[attr.stamina] + diff.stam;
    effects.by_attr.stat_flat[attr.strength] = effects.by_attr.stat_flat[attr.strength] + diff.str;
    effects.by_attr.stat_flat[attr.agility] = effects.by_attr.stat_flat[attr.agility] + diff.agi;
    effects.by_attr.stat_flat[attr.intellect] = effects.by_attr.stat_flat[attr.intellect] + diff.int;
    effects.by_attr.stat_flat[attr.spirit] = effects.by_attr.stat_flat[attr.spirit] + diff.spirit;

    for i = 1, 7 do
        effects.by_school.sp_dmg_flat[i] = effects.by_school.sp_dmg_flat[i] + diff.sd + diff.sp;
    end
    effects.raw.healing_power_flat = effects.raw.healing_power_flat + diff.hp + diff.sp;

    effects.raw.mp5_flat = effects.raw.mp5_flat + diff.mp5;

    effects.raw.spell_haste_rating_flat = effects.raw.spell_haste_rating_flat + diff.haste_rating;
    effects.raw.melee_haste_rating_flat = effects.raw.melee_haste_rating_flat + diff.haste_rating;
    effects.raw.ranged_haste_rating_flat = effects.raw.ranged_haste_rating_flat + diff.haste_rating;
    effects.raw.spell_crit_rating_flat = effects.raw.spell_crit_rating_flat + diff.crit_rating;
    effects.raw.melee_crit_rating_flat = effects.raw.melee_crit_rating_flat + diff.crit_rating;
    effects.raw.ranged_crit_rating_flat = effects.raw.ranged_crit_rating_flat + diff.crit_rating;
    effects.raw.spell_hit_rating_flat = effects.raw.spell_hit_rating_flat + diff.hit_rating;
    effects.raw.melee_hit_rating_flat = effects.raw.melee_hit_rating_flat + diff.hit_rating;
    effects.raw.ranged_hit_rating_flat = effects.raw.ranged_hit_rating_flat + diff.hit_rating;
    effects.raw.expertise_rating_flat = effects.raw.expertise_rating_flat + diff.expertise_rating;
    effects.raw.dodge_rating_flat = effects.raw.dodge_rating_flat + diff.dodge_rating;
    effects.raw.parry_rating_flat = effects.raw.parry_rating_flat + diff.parry_rating;
    effects.raw.defense_skill_rating_flat = effects.raw.defense_skill_rating_flat + diff.defense_skill_rating;
    effects.raw.resilience_crit_taken_rating_flat = effects.raw.resilience_crit_taken_rating_flat + diff.resilience_rating;
    effects.raw.resilience_dmg_taken_rating_flat = effects.raw.resilience_dmg_taken_rating_flat + diff.resilience_rating;

    for i = 1, 7 do
        effects.by_school.target_res_flat[i] = effects.by_school.target_res_flat[i] - diff.pen;
    end

    effects.by_school.res_flat[schools.physical] = effects.by_school.res_flat[schools.physical] + diff.armor;

    effects.raw.mana = effects.raw.mana + diff.extra_mana;

    -- physical stuff
    effects.raw.ap_flat = effects.raw.ap_flat + diff.ap;
    effects.raw.rap_flat = effects.raw.rap_flat + diff.rap;

    local all_weps_mask = bit.bnot(0);
    if effects.wpn_subclass.skill_flat[all_weps_mask] then
        effects.wpn_subclass.skill_flat[all_weps_mask] = effects.wpn_subclass.skill_flat[all_weps_mask] + diff.weapon_skill;
    else
        effects.wpn_subclass.skill_flat[all_weps_mask] = diff.weapon_skill;
    end
    if __spellcoda_debug__ and effects.finalized then
        print("FAILURE: Adding effects diff with finalized");
        --print ("\nCall stack: \n" .. debugstack(2, 3, 2));
    end
end

-- final step, deals with finalizing addition of many forced things like:
--      attack power from strength,
--      spell power from % of spirit,
--      mp5 from % of intellect
--
--      while also handling % stat mod, % max mana etc
local function effects_finalize_forced(loadout, effects)

    if effects.finalized then
        return;
    end

    for i = 1, 5 do
        effects.by_attr.stat_flat[i] =
            (1.0 + effects.by_attr.stat_mod[i] + effects.by_attr.stat_mod_forced[i])
                *
                loadout.stats[i]/(1.0 + effects.by_attr.stat_mod[i])
            -
            loadout.stats[i]
            +
            effects.by_attr.stat_flat[i] *
                (1.0 + effects.by_attr.stat_mod[i] + effects.by_attr.stat_mod_forced[i]);

    end

    local sd_from_stats = 0;
    local hp_from_stats = 0;

    for i = 1, 5 do
        sd_from_stats = sd_from_stats +
            (effects.by_attr.sd_of_stat_pct[i] + effects.by_attr.sd_of_stat_pct_forced[i]) * effects.by_attr.stat_flat[i] +
            effects.by_attr.sd_of_stat_pct_forced[i] * loadout.stats[i];
    end
    for i = 1, 7 do
        effects.by_school.sp_dmg_flat[i] = effects.by_school.sp_dmg_flat[i] + sd_from_stats;
    end

    for i = 1, 5 do
        hp_from_stats = hp_from_stats +
            (effects.by_attr.hp_of_stat_pct[i] + effects.by_attr.hp_of_stat_pct_forced[i]) * effects.by_attr.stat_flat[i] +
            effects.by_attr.hp_of_stat_pct_forced[i] * loadout.stats[i];
    end

    effects.raw.healing_power_flat = effects.raw.healing_power_flat + hp_from_stats;

    local spell_crit_from_int = 0.01*(sc.spell_crit_to_int[loadout.lvl] or 0)*effects.by_attr.stat_flat[attr.intellect];
    for i = 1, 7 do
        effects.by_school.crit_forced[i] = effects.by_school.crit_forced[i] + spell_crit_from_int;
    end

    effects.raw.mana =
        (1.0 + effects.raw.mana_mod + effects.raw.mana_mod_forced)
            * ((effects.by_attr.stat_flat[attr.intellect] * mana_per_int))
        +
        effects.raw.mana; -- only added from custom stats as of now

    effects.raw.hp_flat =
        (1.0 + effects.raw.hp_mod + effects.raw.hp_mod_forced)
        *
        (
         (effects.by_attr.stat_flat[attr.stamina] * hp_per_stam)
         +
         effects.raw.hp_flat
        );

    effects.by_school.res_flat[schools.physical] = effects.by_school.res_flat[schools.physical] +
        effects.by_attr.stat_flat[attr.agility]*armor_per_agi;

    local actual_base_armor = loadout.base_armor - loadout.stats[attr.agility] * armor_per_agi;
    local equip_armor_increase =
        (1.0 + effects.raw.base_res_phys_mod + effects.raw.base_res_phys_mod_forced) *
            actual_base_armor / (1.0 + effects.raw.base_res_phys_mod)
        -
        actual_base_armor
        +
        effects.raw.base_res_phys_flat -- only from forced item diffs
            *
            (1.0 + effects.raw.base_res_phys_mod + effects.raw.base_res_phys_mod_forced);

    effects.by_school.res_flat[schools.physical] =
        (1.0 + effects.raw.res_phys_mod + effects.raw.res_phys_mod_forced) *
            loadout.armor/(1.0 + effects.raw.res_phys_mod)
        -
        loadout.armor
        +
        (1.0 + effects.raw.res_phys_mod + effects.raw.res_phys_mod_forced) *
            (effects.by_school.res_flat[schools.physical] + equip_armor_increase);

    local dodge_from_agi = 0.01*(sc.dodge_to_agi[loadout.lvl] or 0)*effects.by_attr.stat_flat[attr.agility];
    effects.raw.dodge = effects.raw.dodge + dodge_from_agi;

    local agi_ap_class = class;
    if class == classes.druid and loadout.shapeshift == 3 then
        -- cat form
        agi_ap_class = classes.rogue;
    end

    local added_ap =
        effects.by_attr.stat_flat[attr.strength] * ap_per_str[class] +
        effects.by_attr.stat_flat[attr.agility] * ap_per_agi[agi_ap_class];

    effects.raw.ap_flat = 
        (1.0 + effects.raw.ap_mod + effects.raw.ap_mod_forced)
        *
        (
         (added_ap)
         +
         (effects.raw.ap_flat /(1.0 + effects.raw.ap_mod_forced))
        );


    local added_rap = effects.by_attr.stat_flat[attr.agility] * rap_per_agi[class];
    effects.raw.rap_flat = 
        (1.0 + effects.raw.rap_mod + effects.raw.rap_mod_forced)
        *
        (
         (added_rap)
         +
         (effects.raw.rap_flat /(1.0 + effects.raw.rap_mod_forced))
        );


    local crit_from_agi = 0.01*(sc.physical_crit_to_agi[loadout.lvl] or 0)*effects.by_attr.stat_flat[attr.agility];

    effects.raw.phys_crit_forced = effects.raw.phys_crit_forced + crit_from_agi;

    effects.finalized = true;
end

local function dynamic_loadout(loadout)
    if not config.settings.loadout_use_custom_lvl then
        loadout.lvl = UnitLevel("player");
    else
        loadout.lvl = config.settings.loadout_lvl;
    end

    for i = 1, 5 do
        local _, s, _, _ = UnitStat("player", i);
        loadout.stats[i] = s;
    end

    for pwr, _ in pairs(loadout.resources_max) do
        loadout.resources_max[pwr] = math.max(1, UnitPowerMax("player", pwr));
    end
    if config.settings.loadout_always_max_resource then
        for pwr, _ in pairs(loadout.resources) do
            loadout.resources[pwr] = loadout.resources_max[pwr];
        end
    else
        for pwr, _ in pairs(loadout.resources) do
            loadout.resources[pwr] = UnitPower("player", pwr);
        end
    end
    -- always put at least 1 combo point to at least resemble spell descriptions
    loadout.resources[powers.combopoints] = math.max(1, loadout.resources[powers.combopoints]);

    loadout.base_mana = 0;
    if sc.base_mana_by_lvl then
        loadout.base_mana = sc.base_mana_by_lvl[loadout.lvl];
    end

    if sc.expansion ~= sc.expansions.vanilla then
        for _, v in ipairs(ratings) do
            loadout[v[2]] = GetCombatRating(v[1]);
        end

        if loadout.lvl <= 60 then
            loadout.cr_scaling = (math.max(loadout.lvl, 10) - 8) / 52
        elseif loadout.lvl <= 70 then
            loadout.cr_scaling = 82 / (262 - 3 * loadout.lvl)
        else
            loadout.cr_scaling = (41/26) * ((131/63)^((loadout.lvl - 70) / 10))
        end
    else
        for _, v in ipairs(ratings) do
            loadout[v[2]] = 0;
        end
        -- dummy combat rating 1 always yield 1% in vanilla
        loadout.cr_scaling = 1;
    end


    --loadout.phys_hit = 0;
    --local phys_hit = GetHitModifier();
    --if phys_hit then
    --    loadout.phys_hit = 0.01*phys_hit;
    --end

    if sc.expansion ~= sc.expansions.wotlk then
        loadout.healing_power = GetSpellBonusHealing();
        for i = 1, 7 do
            loadout.spell_dmg_by_school[i] = GetSpellBonusDamage(i);
        end
        loadout.spell_dmg_by_school[1] = loadout.spell_dmg_by_school[2];
        -- use holy as +all schools baseline, write to physical so singular sp by schools can be 
        -- detected for multischool spells

        -- right after load GetSpellHitModifier seems to sometimes returns a nil.... so check first I guess
       local spell_hit = 0;
       local api_hit = GetSpellHitModifier();
       if api_hit then
           spell_hit = 0.01*api_hit;
       end
       for i = 1, 7 do
           loadout.spell_dmg_hit_by_school[i] = spell_hit;
       end
    else
        -- in wotlk, healing power will equate to spell power
        loadout.spell_power = GetSpellBonusHealing();
        for i = 1, 7 do
            loadout.spell_dmg_by_school[i] = GetSpellBonusDamage(i) - loadout.spell_power;
        end
    end

    for i = 1, 7 do
        loadout.spell_crit_by_school[i] = GetSpellCritChance(i)*0.01;
    end
    local ap_src1, ap_src2, ap_src3 = UnitAttackPower("player");
    loadout.ap = ap_src1 + ap_src2 + ap_src3;
    local rap_src1, rap_src2, rap_src3 = UnitRangedAttackPower("player");
    loadout.rap = rap_src1 + rap_src2 + rap_src3;

    local r_skill_base, r_skill_mod = UnitRangedAttack("player");
    loadout.ranged_skill = r_skill_base + r_skill_mod;
    local m1_skill_base, m1_skill_mod, m2_skill_base, m2_skill_mod = UnitAttackBothHands("player");
    loadout.m1_skill = m1_skill_base + m1_skill_mod;
    loadout.m2_skill = m2_skill_base + m2_skill_mod;

    loadout.melee_crit = GetCritChance()*0.01;
    loadout.ranged_crit = GetRangedCritChance()*0.01;
    loadout.block = GetBlockChance()*0.01;

    --loadout.r_speed, loadout.r_min, loadout.r_max, loadout.r_pos, loadout.r_neg, loadout.r_mod = UnitRangedDamage("player");

    loadout.attack_min_mh, loadout.attack_max_mh, _, _, loadout.attack_pos, loadout.attack_neg, loadout.attack_mod = UnitDamage("player");

    loadout.attack_delay_mh, loadout.attack_delay_oh = UnitAttackSpeed("player");

    loadout.shapeshift = GetShapeshiftForm();
    if class == classes.druid and loadout.shapeshift ~= 0 and loadout.shapeshift ~= 5 then
        loadout.shapeshift_no_weapon = 1;
    else
        loadout.shapeshift_no_weapon = 0;
    end

    loadout.player_name = UnitName("player");
    loadout.target_name = UnitName("target");
    loadout.mouseover_name = UnitName("mouseover");

    loadout.dodge = 0.01*(GetDodgeChance() or 0);
    loadout.parry = 0.01*(GetParryChance() or 0);
    local def_base, def_bonus = UnitDefense("player");
    loadout.defense = def_base + def_bonus;

    loadout.target_res = config.settings.loadout_target_res;

    loadout.hostile_towards = "";
    loadout.friendly_towards = "player";

    loadout.flags =
        bit.band(loadout.flags, bit.band(bit.bnot(loadout_flags.has_target),
                                         --bit.bnot(loadout_flags.target_snared),
                                         --bit.bnot(loadout_flags.target_frozen),
                                         bit.bnot(loadout_flags.target_friendly),
                                         bit.bnot(loadout_flags.target_pvp)));

    loadout.player_hp_max = math.max(UnitHealthMax("player"), 1);
    loadout.player_hp = UnitHealth("player");

    loadout.enemy_hp_perc = config.settings.loadout_default_target_hp_perc*0.01;

    if config.settings.loadout_default_target_creature_type > 0 then
        loadout.target_creature_mask = bit.lshift(1, config.settings.loadout_default_target_creature_type-1);
    else
        loadout.target_creature_mask = 0;
    end

    loadout.target_lvl = config.settings.loadout_default_target_lvl_diff + loadout.lvl;

    if UnitExists("target") then

        loadout.flags = bit.bor(loadout.flags, loadout_flags.has_target);
        loadout.hostile_towards = "target";

        if UnitIsFriend("player", "target") then
            loadout.flags = bit.bor(loadout.flags, loadout_flags.target_friendly);
            loadout.friendly_towards = "target";
        elseif UnitIsPlayer("target") then
            loadout.flags = bit.bor(loadout.flags, loadout_flags.target_pvp);
        end

        if bit.band(loadout.flags, loadout_flags.target_friendly) == 0 then
            local target_lvl = UnitLevel("target");
            if target_lvl == -1 then
                loadout.target_lvl = loadout.lvl + 3;
            else
                loadout.target_lvl = target_lvl;
            end

            local creature = UnitCreatureType("target");
            if creature then
                local creature_id = sc.creature_lname_to_id[creature];
                if creature_id then
                    loadout.target_creature_mask = bit.lshift(1, creature_id-1);
                end
            end
        end
    end

    if UnitExists("mouseover") and UnitIsFriend("player", "mouseover") then
        loadout.friendly_towards = "mouseover";
    end
    if loadout.hostile_towards == "target" and bit.band(loadout.flags, loadout_flags.target_friendly) == 0 then
        loadout.enemy_hp_perc = UnitHealth("target")/math.max(UnitHealthMax("target"), 1);
    end

    loadout.friendly_hp_max = math.max(UnitHealthMax(loadout.friendly_towards), 1);
    loadout.friendly_hp_perc = UnitHealth(loadout.friendly_towards)/loadout.friendly_hp_max;

    loadout.target_defense = 5*loadout.target_lvl;

    loadout.base_armor, loadout.armor = UnitArmor("player");

    loadout.target_pvpres = config.settings.loadout_target_pvpres;

    loadout.target_armor = config.settings.loadout_target_armor;
    if config.settings.loadout_target_automatic_armor then
        if sc.npc_armor_by_lvl[loadout.target_lvl] then
            local armor_pct;
            if config.settings.loadout_target_automatic_armor_heavy then
                armor_pct = 100;
            elseif config.settings.loadout_target_automatic_armor_medium then
                armor_pct = 80;
            elseif config.settings.loadout_target_automatic_armor_light then
                armor_pct = 50;
            else
                armor_pct = 100;
            end
            loadout.target_armor = sc.npc_armor_by_lvl[loadout.target_lvl] * armor_pct * 0.01;
        end
    end

    sc.buffs.detect_buffs(loadout);

    loadout.calculator_mode = false;
end

local function apply_effect(effects, spid, auras, forced, stacks, undo, player_owned, shapeshift)
    if not auras then
        --if __spellcoda_debug__ then
        --    print("Missing aura", spid);
        --end
        return;
    end
    local add_all = 0.0;
    local mul_all = 1.0;
    -- affects all internal ids
    if effects.aura_pts_flat[-1][spid] then
        add_all = add_all + effects.aura_pts_flat[-1][spid];
    end
    if effects.aura_pts[-1][spid] then
        mul_all = mul_all + effects.aura_pts[-1][spid];
    end

    for _, aura in pairs(auras) do

        if bit.band(aura[flags_idx], sc.aura_flags.apply_aura) ~= 0 then
            for _, k in pairs(aura[subject_idx]) do
                if sc[aura[effect_idx]][k] then
                    apply_effect(effects, k, sc[aura[effect_idx]][k], forced, stacks, undo);
                end
            end
        elseif bit.band(aura[flags_idx], sc.aura_flags.requires_ownership) ~= 0 and not player_owned then
            -- skip
        elseif bit.band(aura[flags_idx], sc.aura_flags.requires_feral_shapeshift) ~= 0 and not shapeshift then
            -- skip
        else
            local add;
            local mul;
            if aura[iid_idx] == -1 then
                -- iid_idx == -1 on effect aura means it is a "fake aura", not from client generator
                add = 0;
                mul = 1.0;
            else
                add = add_all;
                mul = mul_all;
            end
            -- affects specific iids
            if effects.aura_pts_flat[aura[iid_idx]] and effects.aura_pts_flat[aura[iid_idx]][spid] then
                add = add + effects.aura_pts_flat[aura[iid_idx]][spid];
            end
            if effects.aura_pts[aura[iid_idx]] and effects.aura_pts[aura[iid_idx]][spid] then
                mul = mul + effects.aura_pts[aura[iid_idx]][spid];
            end
            local val;
            if stacks > 1 and bit.band(aura[flags_idx], sc.aura_flags.stacks_as_charges) == 0 then
                val = (aura[value_idx] + add) * mul * stacks;
            else
                val = (aura[value_idx] + add) * mul;
            end

            if bit.band(aura[flags_idx], sc.aura_flags.inactive_forced) == 0 or forced then
                local aura_effect = aura[effect_idx];
                if forced and bit.band(aura[flags_idx], sc.aura_flags.forced_separated) ~= 0 then
                    aura_effect = aura_effect.."_forced";
                end
                if bit.band(aura[flags_idx], sc.aura_flags.mul) ~= 0 then
                    --if __spellcoda_debug__ then
                    --    if not effects["mul"][aura[category_idx]][aura_effect] then
                    --        print("Missing effects.mul."..aura[category_idx].."."..aura_effect);
                    --    end
                    --end

                    val = 1.0 + val;
                    if undo then
                        val = 1/val;
                    end
                    if aura[category_idx] == "raw" then
                        effects["mul"][aura[category_idx]][aura_effect] = effects["mul"][aura[category_idx]][aura_effect] * val;
                    else
                        for _, i in pairs(aura[subject_idx]) do
                            effects["mul"][aura[category_idx]][aura_effect][i] = (effects["mul"][aura[category_idx]][aura_effect][i] or 1.0) * val;
                        end
                    end
                else
                    --if __spellcoda_debug__ then
                    --    if not effects[aura[category_idx]] then
                    --        print("Missing effects."..aura[category_idx]);
                    --    end
                    --    if not effects[aura[category_idx]][aura_effect] then
                    --        print("Missing effects."..aura[category_idx].."."..aura_effect);
                    --    end
                    --end
                    if undo then
                        val = -val;
                    end
                    if aura[category_idx] == "raw" then
                        effects[aura[category_idx]][aura_effect] = effects[aura[category_idx]][aura_effect] + val;
                    else
                        for _, i in pairs(aura[subject_idx]) do
                            effects[aura[category_idx]][aura_effect][i] = (effects[aura[category_idx]][aura_effect][i] or 0.0) + val;
                        end
                    end
                end
            end
        end
    end
end

-- double buffered loadout
local loadout_base1 = loadout_zero();
local loadout_base2 = loadout_zero();
local loadout_front = loadout_base1;

-- singular tables shared in both loadout buffers, not to be compared 
local loadout_shared = {
    "wpn_skills",
    "talents",
    "items",
    "item_links",
};
for _, v in ipairs(loadout_shared) do
    loadout_base1[v] = {};
    loadout_base2[v] = loadout_base1[v];
end
loadout_base1.talents.code = "";

local equipped = {};
local talented = {};
local buffed = {};
local final = {};
empty_effects(equipped);
empty_effects(talented);
empty_effects(buffed);
empty_effects(final);

local function active_loadout()
    return loadout_front;
end

loadouts.force_update = true;
local effects_update_id = 0;
local effects_update_timestamp = -1;


local function update_loadout_and_effects(relaxed_update_dt)

    local now_timestamp = GetTime();

    relaxed_update_dt = relaxed_update_dt or 0;

    if now_timestamp - effects_update_timestamp <= relaxed_update_dt then

        effects_update_timestamp = now_timestamp;
        return loadout_front, buffed, final, effects_update_id;
    end
    effects_update_timestamp = now_timestamp;

    local other;
    if loadout_front == loadout_base1 then
        other = loadout_base2;
    else
        other = loadout_base1;
    end
    dynamic_loadout(other);

    if not SpellBookFrame:IsShown() and
        not loadouts.force_update and
        not sc.core.equipment_update_needed and
        not sc.core.talents_update_needed and
            loadout_eql(loadout_front, other) then

        loadout_front = other;

        -- No interesting change, early exit here and Overlay
        -- will benefit from not having to update icons
        return loadout_front, buffed, final, effects_update_id;
    end

    loadouts.force_update = false;
    loadout_front = other;

    if sc.core.talents_update_needed then

        zero_effects(talented);
        -- NOTE: these special passives may change aura_pts of other effects, thus applied first
        for k, v in pairs(sc.passives) do
            if IsPlayerSpell(k) then
                apply_effect(talented, k, v, false, 1);
            end
        end

        local success = sc.talents.loadout_talents_info(loadout_front);
        sc.talents.apply_talents(loadout_front, talented, loadout_front.talents.code, false, false);

        sc.core.talents_update_needed = not success;
        sc.core.equipment_update_needed = true;
    end

    if sc.core.equipment_update_needed then
        zero_effects(equipped);
        effects_add(equipped, talented);
        local success = sc.equipment.apply_equipment(loadout_front, equipped);
        -- need eq update again next because api failed
        sc.core.equipment_update_needed = not success;
    end

    -- equipment and talents updates above are rare

    zero_effects(buffed);
    effects_add(buffed, equipped);

    sc.buffs.apply_buffs(loadout_front, buffed, false, false);

    cpy_effects(final, buffed);
    effects_finalize_forced(loadout_front, final);

    effects_update_id = effects_update_id + 1;

    return loadout_front, buffed, final, effects_update_id;
end

local function item_plan_slot_ui_diffs(loadout, old_items, new_items)

    local planned_items = __sc_frame.calculator_frame.items.working;

    for slot in pairs(__sc_frame.calculator_frame.items.slots) do
        if planned_items[slot] then
            if not new_items[slot] then
                new_items[slot] = {};
            end
            write_item_info_from_link(new_items[slot], planned_items[slot].link);

            -- old item might not exist
            if not old_items[slot] then
                old_items[slot] = {};
            end
            if loadout.item_links[slot] then
                write_item_info_from_link(old_items[slot], loadout.item_links[slot]);
            end

        else
            old_items[slot] = nil;
            new_items[slot] = nil;
        end
    end
end

local old_items_buffer = {};
local new_items_buffer = {};
local stats_diff_last;
local buffs_cfg;
local talents_cfg;

local diffed = {};
local diffed_finalized = {};
empty_effects(diffed);
empty_effects(diffed_finalized);

local last_ui_diff_update_id = 0;

local function update_loadout_and_effects_diffed_from_ui()

    local loadout, effects, effects_finalized, update_id = update_loadout_and_effects();

    local updated = update_id > last_ui_diff_update_id;

    loadout.calculator_mode = true;

    local calc_frame = __sc_frame.calculator_frame;
    if calc_frame.calculator_plan_changed then

        stats_diff_last = sc.ui.effects_from_ui_stats_diff();
        item_plan_slot_ui_diffs(loadout, old_items_buffer, new_items_buffer);
        buffs_cfg = calc_frame.buffs.working;
        talents_cfg = calc_frame.talents.working;

        calc_frame.calculator_plan_changed = false;

    elseif not updated then

        -- early exit possible
        last_ui_diff_update_id = update_id;
        return loadout, effects, diffed, effects_finalized, diffed_finalized, update_id;
    end

    cpy_effects(diffed, effects);

    -- Items
    sc.equipment.apply_items_cmp(loadout, diffed, new_items_buffer, old_items_buffer, true, true, true);

    -- Manual stat changes
    effects_add_manual_diff(diffed, stats_diff_last);

    -- Buffs
    if buffs_cfg.use_custom then
        sc.buffs.apply_fake_buffs(loadout, diffed, buffs_cfg);
    end

    -- Talents
    if talents_cfg.use_custom then
        sc.talents.apply_talents(loadout, diffed, loadout.talents.code, true, true);
        sc.talents.apply_talents(loadout, diffed, talents_cfg.custom_code, true, false);
    end

    cpy_effects(diffed_finalized, diffed);
    effects_finalize_forced(loadout, diffed_finalized);

    effects_update_id = effects_update_id + 1;
    last_ui_diff_update_id = effects_update_id;

    return loadout, effects, diffed, effects_finalized, diffed_finalized, effects_update_id;
end

---------------------------------------------------------------------------------------------------
loadouts.equipped                                     = equipped;
loadouts.talented                                     = talented;
loadouts.empty_effects                                = empty_effects;
loadouts.effects_add                                  = effects_add;
loadouts.effects_add_manual_diff                      = effects_add_manual_diff;
loadouts.effects_finalize_forced                      = effects_finalize_forced;
loadouts.cpy_effects                                  = cpy_effects;
loadouts.manual_effects_zero_diff                     = manual_effects_zero_diff;
loadouts.active_loadout                               = active_loadout;
loadouts.update_loadout_and_effects                   = update_loadout_and_effects;
loadouts.update_loadout_and_effects_diffed_from_ui    = update_loadout_and_effects_diffed_from_ui;
loadouts.loadout_flags                                = loadout_flags;
loadouts.apply_effect                                 = apply_effect;
loadouts.stats_diff_format                            = stats_diff_format;
loadouts.stats_format                                 = stats_format;
loadouts.init_lnames                                  = init_lnames;

sc.loadouts = loadouts;

