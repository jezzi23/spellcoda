local _, sc = ...;

local attr                              = sc.attr;
local classes                           = sc.classes;
local powers                            = sc.powers;
local class                             = sc.class;

local category_idx                      = sc.aura_idx_category;
local effect_idx                        = sc.aura_idx_effect;
local value_idx                         = sc.aura_idx_value;
local subject_idx                       = sc.aura_idx_subject;
local flags_idx                         = sc.aura_idx_flags;
local iid_idx                           = sc.aura_idx_iid; -- internal index within this spell id

local mana_per_int                      = sc.scaling.mana_per_int;
local int_to_spell_crit                 = sc.scaling.int_to_spell_crit;
local agi_to_physical_crit              = sc.scaling.agi_to_physical_crit;
local ap_per_str                        = sc.scaling.ap_per_str;
local ap_per_agi                        = sc.scaling.ap_per_agi;
local rap_per_agi                       = sc.scaling.rap_per_agi;

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
    "armor",
    "player_hp_perc",
    "enemy_hp_perc",
    "flags",
    "lvl",
    "target_lvl",
    "haste_rating",
    "crit_rating",
    "hit_rating",
    "phys_hit",
    "spell_dmg",
    "healing_power",
    "spell_power",
    "attack_power",
    "extra_mana",
    "base_mana",
    "ap",
    "rap",
    "ranged_skill",
    "m1_skill",
    "m2_skill",
    "melee_crit",
    "ranged_crit",
    "block_value",
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
        "mp5_from_int_mod",
        "mp5_flat",
        "perc_max_mana_as_mp5",
        "regen_while_casting",
        "healing_power_flat",
        "phys_dmg_flat",
        "ap_flat",
        "rap_flat",
        "cast_haste",
        "cost_mod",
        "phys_hit",
        "phys_crit",
        "phys_crit_forced",
        "offhand_mod",
        "extra_hits_flat",
        "haste_rating",
        "crit_rating",
        "hit_rating",
        "skill",
        "class_misc",

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

local effects_multiplicative = {
    by_school = {
        "vuln_mod",
        "dmg_mod",
    },
    ability = {
        "vuln_mod",
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

local function cpy_effects(dst, src)

    for _, cat in ipairs(effect_categories) do
        local dst_cat = dst[cat];
        local src_cat = src[cat];
        for i, src_e in pairs(src_cat) do
            if type(src_e) == "table" then
                local dst_e = dst_cat[i];
                for j, _ in pairs(dst_e) do
                    if not src_e[j] then
                        -- prevent values in src that are not in dst
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
                dst_cat[i] = dst_cat[i] + src_cat[i];
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
    if sc.core.__sw__debug__ and dst.finalized or src.final then
        print("FAILURE: Adding effects with finalized");
        --print ("\nCall stack: \n" .. debugstack(2, 3, 2));
    end

end

local function effects_zero_diff()
    return {
        stats = {0, 0, 0, 0, 0},
        mp5 = 0,
        sp = 0,
        sd = 0,
        hp = 0,
        ap = 0,
        rap = 0,
        hit_rating = 0,
        haste_rating = 0,
        crit_rating = 0,
        spell_pen = 0,

        weapon_skill = 0,
    };
end

local function effects_from_ui_diff(frame)

    local stats = frame.stats;
    local diff = effects_zero_diff();

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
                return diff;
            end
        end
    end

    diff.stats[attr.intellect] = stats.int.editbox_val;
    diff.stats[attr.spirit] = stats.spirit.editbox_val;
    diff.stats[attr.strength] = stats.str.editbox_val;
    diff.stats[attr.agility] = stats.agi.editbox_val;
    diff.mp5 = stats.mp5.editbox_val;

    diff.crit_rating = stats.crit_rating.editbox_val;
    diff.hit_rating = stats.hit_rating.editbox_val;
    diff.haste_rating = stats.haste_rating.editbox_val;

    diff.sp = stats.sp.editbox_val;
    diff.sd = stats.sd.editbox_val;
    diff.hp = stats.hp.editbox_val;
    diff.ap = stats.ap.editbox_val;
    diff.rap = stats.rap.editbox_val;
    diff.weapon_skill = stats.wep.editbox_val;
    diff.spell_pen = stats.spell_pen.editbox_val;

    frame.is_valid = true;

    return diff;
end

local function effects_add_diff(effects, diff)

    for i = 1, 5 do
        effects.by_attr.stat_flat[i] = effects.by_attr.stat_flat[i] + diff.stats[i];
    end

    for i = 1, 7 do
        effects.by_school.sp_dmg_flat[i] = effects.by_school.sp_dmg_flat[i] + diff.sd + diff.sp;
    end
    effects.raw.healing_power_flat = effects.raw.healing_power_flat + diff.hp + diff.sp;

    effects.raw.mp5_flat = effects.raw.mp5_flat + diff.mp5;

    effects.raw.haste_rating = effects.raw.haste_rating + diff.haste_rating;
    effects.raw.crit_rating = effects.raw.crit_rating + diff.crit_rating;
    effects.raw.hit_rating = effects.raw.hit_rating + diff.hit_rating;

    for i = 2, 7 do
        effects.by_school.target_res_flat[i] = effects.by_school.target_res_flat[i] - diff.spell_pen;
    end

    -- physical stuff

    effects.raw.ap_flat = effects.raw.ap_flat + diff.ap;
    effects.raw.rap_flat = effects.raw.rap_flat + diff.rap;

    local all_weps_mask = bit.bnot(0);
    if effects.wpn_subclass.skill_flat[all_weps_mask] then
        effects.wpn_subclass.skill_flat[all_weps_mask] = effects.wpn_subclass.skill_flat[all_weps_mask] + diff.weapon_skill;
    else
        effects.wpn_subclass.skill_flat[all_weps_mask] = diff.weapon_skill;
    end
    if sc.core.__sw__debug__ and effects.finalized then
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
            (effects.by_attr.stat_mod[i] + effects.by_attr.stat_mod_forced[i]) *
                loadout.stats[i]/(1.0 + effects.by_attr.stat_mod[i])
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

    local crit_from_int = int_to_spell_crit(effects.by_attr.stat_flat[attr.intellect], loadout.lvl);
    for i = 1, 7 do
        effects.by_school.crit_forced[i] = effects.by_school.crit_forced[i] + crit_from_int;
    end

    effects.raw.mana = 
        (1.0 + effects.raw.mana_mod + effects.raw.mana_mod_forced)
        *
        (
         (effects.by_attr.stat_flat[attr.intellect] * mana_per_int)
         +
         (effects.raw.mana/(1.0 + effects.raw.mana_mod_forced))
        );

    local agi_ap_class = class;
    if class == classes.druid and loadout.shapeshift == 3 then
        -- cat form
        agi_ap_class = classes.rogue;
    end

    local added_ap =
        effects.by_attr.stat_flat[attr.strength] * ap_per_str[class] +
        effects.by_attr.stat_flat[attr.agility] * ap_per_agi[agi_ap_class];
    effects.raw.ap_flat = effects.raw.ap_flat + added_ap;

    local added_rap = effects.by_attr.stat_flat[attr.agility] * rap_per_agi[class];
    effects.raw.rap_flat = effects.raw.rap_flat + added_rap;

    effects.raw.phys_crit_forced = effects.raw.phys_crit_forced +
        agi_to_physical_crit(effects.by_attr.stat_flat[attr.agility], loadout.lvl);

    effects.finalized = true;
end

local function dynamic_loadout(loadout)
    if not config.loadout.use_custom_lvl then
        loadout.lvl = UnitLevel("player");
    else
        loadout.lvl = config.loadout.lvl;
    end

    for i = 1, 5 do
        local _, s, _, _ = UnitStat("player", i);
        loadout.stats[i] = s;
    end

    for pwr, _ in pairs(loadout.resources_max) do
        loadout.resources_max[pwr] = math.max(1, UnitPowerMax("player", pwr));
    end
    if config.loadout.always_max_resource then
        for pwr, _ in pairs(loadout.resources) do
            loadout.resources[pwr] = loadout.resources_max[pwr];
        end
    else
        for pwr, _ in pairs(loadout.resources) do
            loadout.resources[pwr] = UnitPower("player", pwr);
        end
    end
    loadout.extra_mana = config.loadout.extra_mana;
    -- always put at least 1 combo point to at least resemble spell descriptions
    loadout.resources[powers.combopoints] = math.max(1, loadout.resources[powers.combopoints]);

    loadout.base_mana = 0;
    if sc.base_mana_by_lvl then
        loadout.base_mana = sc.base_mana_by_lvl[loadout.lvl];
    end


    loadout.haste_rating = 0;
    loadout.hit_rating = 0;
    loadout.phys_hit = 0;
    local phys_hit = GetSpellHitModifier();
    if phys_hit then
        loadout.phys_hit = 0.01*phys_hit;
    end

    if sc.expansion == sc.expansions.vanilla then
        loadout.healing_power = GetSpellBonusHealing();
        for i = 1, 7 do
            loadout.spell_dmg_by_school[i] = GetSpellBonusDamage(i);
        end
        loadout.spell_dmg_by_school[1] = loadout.spell_dmg_by_school[2];
        -- use holy as +all schools baseline, write to physical so singular sp by schools can be 
        -- detected for multischool spells
        --for i = 3, 7 do
        --    loadout.spell_dmg_by_school[i] = math.min(loadout.spell_dmg_by_school[1],
        --                                              loadout.spell_dmg_by_school[i]);
        --end

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

        -- crit and hit is already gathered indirectly from rating, but not haste
        loadout.haste_rating = GetCombatRating(CR_HASTE_SPELL);
        loadout.hit_rating = GetCombatRating(CR_HIT_SPELL);
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
    loadout.block_value = GetShieldBlock();

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

    loadout.target_res = config.loadout.target_res;

    loadout.hostile_towards = "";
    loadout.friendly_towards = "player";

    loadout.flags =
        bit.band(loadout.flags, bit.band(bit.bnot(loadout_flags.has_target),
                                         --bit.bnot(loadout_flags.target_snared),
                                         --bit.bnot(loadout_flags.target_frozen),
                                         bit.bnot(loadout_flags.target_friendly),
                                         bit.bnot(loadout_flags.target_pvp)));

    loadout.player_hp_perc = UnitHealth("player")/math.max(UnitHealthMax("player"), 1);

    loadout.enemy_hp_perc = config.loadout.default_target_hp_perc*0.01;

    loadout.target_creature_mask = 0;

    loadout.target_lvl = config.loadout.default_target_lvl_diff + loadout.lvl;

    if UnitExists("target") then

        loadout.flags = bit.bor(loadout.flags, loadout_flags.has_target);
        loadout.hostile_towards = "target";

        if UnitIsFriend("player", "target") then
            loadout.flags = bit.bor(loadout.flags, loadout_flags.target_friendly);
            loadout.friendly_towards = "target";
        elseif UnitIsPlayer("target") then
            loadout.flags = bit.bor(loadout.flags, loadout_flags.target_pvp);
        end

        local creature = UnitCreatureType("target");
        if creature then
            local creature_id = sc.creature_lname_to_id[creature];
            if creature_id then
                loadout.target_creature_mask = bit.lshift(1, creature_id-1);
            end
        end

        if bit.band(loadout.flags, loadout_flags.target_friendly) == 0 then
            local target_lvl = UnitLevel("target");
            if target_lvl == -1 then
                loadout.target_lvl = loadout.lvl + 3;
            else
                loadout.target_lvl = target_lvl;
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

    loadout.armor = config.loadout.target_armor;
    if config.loadout.target_automatic_armor then
        if sc.npc_armor_by_lvl[loadout.target_lvl] then
            loadout.armor = sc.npc_armor_by_lvl[loadout.target_lvl] * config.loadout.target_automatic_armor_pct * 0.01;
        end
    end

    sc.buffs.detect_buffs(loadout);
end

local function apply_effect(effects, spid, auras, forced, stacks, undo, player_owned)
    if not auras then
        --print("Missing aura", spid);
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
                apply_effect(effects, k, sc[aura[effect_idx]][k], forced, stacks, undo);
            end
        elseif bit.band(aura[flags_idx], sc.aura_flags.requires_ownership) ~= 0 and not player_owned then
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
                    --if not effects["mul"][aura[category_idx]][aura_effect] then
                    --    print("Missing effects.mul."..aura[category_idx].."."..aura_effect);
                    --end
                    if undo then
                        val = 1/val;
                    end
                    if aura[category_idx] == "raw" then
                        effects["mul"][aura[category_idx]][aura_effect] = effects["mul"][aura[category_idx]][aura_effect] * (1.0 + val);
                    else
                        for _, i in pairs(aura[subject_idx]) do
                            effects["mul"][aura[category_idx]][aura_effect][i] = (effects["mul"][aura[category_idx]][aura_effect][i] or 1.0) * (1.0 + val);
                        end
                    end
                else
                    --if not effects[aura[category_idx]] then
                    --    print("Missing effects."..aura[category_idx]);
                    --end
                    --if not effects[aura[category_idx]][aura_effect] then
                    --    print("Missing effects."..aura[category_idx].."."..aura_effect);
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
    "num_set_pieces",
    "enchants",
    "talents",
    "items",
};
for _, v in ipairs(loadout_shared) do
    loadout_base1[v] = {};
    loadout_base2[v] = loadout_base1[v];
end
loadout_base1.talents.code = "";
loadout_base1.talents.pts = {};

local equipped = {};
local talented = {};
local buffed = {};
local final = {};
local diffed = {};
empty_effects(equipped);
empty_effects(talented);
empty_effects(buffed);
empty_effects(final);
empty_effects(diffed);


local function active_loadout()
    return loadout_front;
end

loadouts.force_update = true;
local effects_update_id = 0;

local function update_loadout_and_effects()

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

        loadout_front.talents.code = sc.talents.wowhead_talent_code();

        zero_effects(talented);
        -- NOTE: these special passives may change aura_pts of other effects, thus applied first
        for k, v in pairs(sc.passives) do
            if IsPlayerSpell(k) then
                apply_effect(talented, k, v, false, 1);
            end
        end

        local success = sc.talents.apply_talents(loadout_front, talented);

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

    sc.buffs.apply_buffs(loadout_front, buffed);

    cpy_effects(final, buffed);
    effects_finalize_forced(loadout_front, final);

    effects_update_id = effects_update_id + 1;

    return loadout_front, buffed, final, effects_update_id;
end

local function update_loadout_and_effects_diffed_from_ui(dont_finalize)

    local loadout, effects, effects_finalized = update_loadout_and_effects();

    local diff = effects_from_ui_diff(__sc_frame.calculator_frame);

    cpy_effects(diffed, effects);
    effects_add_diff(diffed, diff);

    if not dont_finalize then
        effects_finalize_forced(loadout, diffed);

        return loadout, effects_finalized, diffed;
    else
        return loadout, effects, diffed;
    end

end

loadouts.equipped                                     = equipped;
loadouts.talented                                     = talented;
loadouts.empty_effects                                = empty_effects;
loadouts.diffed                                       = diffed;
loadouts.effects_add                                  = effects_add;
loadouts.effects_add_diff                             = effects_add_diff;
loadouts.effects_finalize_forced                      = effects_finalize_forced;
loadouts.cpy_effects                                  = cpy_effects;
loadouts.effects_zero_diff                            = effects_zero_diff;
loadouts.active_loadout                               = active_loadout;
loadouts.update_loadout_and_effects                   = update_loadout_and_effects;
loadouts.update_loadout_and_effects_diffed_from_ui    = update_loadout_and_effects_diffed_from_ui;
loadouts.loadout_flags                                = loadout_flags;
loadouts.apply_effect                                 = apply_effect;

sc.loadouts = loadouts;

