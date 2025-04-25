local _, sc = ...;

local attr                                          = sc.attr;
local spells                                        = sc.spells;
local spids                                         = sc.spids;
local schools                                       = sc.schools;
local class                                         = sc.class;
local classes                                       = sc.classes;
local powers                                        = sc.powers;
local spell_flags                                   = sc.spell_flags;
local comp_flags                                    = sc.comp_flags;
local lookups                                       = sc.lookups;
local class_buffs                                   = sc.class_buffs;
local auto_attack_spell_id                          = sc.auto_attack_spell_id;
local auto_wand_spell_id                            = sc.auto_wand_spell_id;

local spell_cost                                    = sc.utils.spell_cost;
local spell_cast_time                               = sc.utils.spell_cast_time;
local best_rank_by_lvl                              = sc.utils.best_rank_by_lvl;
local spell_lname                                   = sc.utils.spell_lname;
local dummy_value                                   = sc.utils.dummy_value;

local config                                        = sc.config;

local effects_zero_diff                             = sc.loadouts.effects_zero_diff;
local effects_add_diff                              = sc.loadouts.effects_add_diff;
local effects_finalize_forced                       = sc.loadouts.effects_finalize_forced;
local empty_effects                                 = sc.loadouts.empty_effects;
local cpy_effects                                   = sc.loadouts.cpy_effects;
local loadout_flags                                 = sc.loadouts.loadout_flags;

-- l_talents will always point to the same table, avoiding further dereferencing
local l_talents                                     = sc.loadouts.active_loadout().talents;

local num_set_pieces                                = sc.equipment.num_set_pieces;

local get_buff                                      = sc.buffs.get_buff;
local get_buff_by_lname                             = sc.buffs.get_buff_by_lname;

local dps_per_ap                                    = sc.scaling.dps_per_ap;
local get_combat_rating_effect                      = sc.scaling.get_combat_rating_effect;
local spirit_mana_regen                             = sc.scaling.spirit_mana_regen;

--------------------------------------------------------------------------------
local calc              = {};

local info_buffer = {};
local stats_buffer = {};

local secondary_info = {};
local secondary_stats = {};

local fight_types   = {
    repeated_casts = 1,
    cast_until_oom = 2
};

local evaluation_flags = {
    assume_single_effect                    = bit.lshift(1, 1),
    isolate_periodic                        = bit.lshift(1, 2),
    isolate_direct                          = bit.lshift(1, 3),
    isolate_mh                              = bit.lshift(1, 4),
    isolate_oh                              = bit.lshift(1, 5),
    stat_weights                            = bit.lshift(1, 6),

    -- To ignore when e.g. heroic strike normally uses expectation as gains over normal attack
    expectation_of_self                     = bit.lshift(1, 7),

    fix_weapon_skill_to_level               = bit.lshift(1, 8),
    at_max_mana                             = bit.lshift(1, 9),

    -- combo points value shifted, reserve 3 bits for max 5 points
    num_combo_points_bit_start              = 20,
    --COMBO_POINT_RESERVED                  = 21,
    --COMBO_POINT_RESERVED                  = 22
};

local function mandatory_flags_by_spell(comp)
    local flags = 0;
    if bit.band(comp.flags, comp_flags.applies_mh) == 0 and
        bit.band(comp.flags, comp_flags.applies_oh) ~= 0 then

        flags = bit.bor(flags, evaluation_flags.isolate_oh);
    end

    return flags;
end

local function spell_hit(lvl, lvl_target, hit, pvp)
    local base_hit = 0;
    local each_lvl_miss = 0.11;
    if pvp then
        each_lvl_miss = 0.07;
    end

    if lvl_target - lvl > 2 then
        base_hit = 0.94 - each_lvl_miss * (lvl_target - lvl - 2);
    else
        base_hit = 0.96 - 0.01 * (lvl_target - lvl);
    end

    return math.max(0.01, math.min(0.99, base_hit + hit));
end

local function npc_lvl_resi_base(self_lvl, target_lvl)
    -- higher lvl npcs always have impenetrable base resistance for non binary spells
    return math.floor(self_lvl * math.max(0, target_lvl - self_lvl) * 2 / 15);
end

local function target_avg_magical_res_binary(self_lvl, target_res)
    return math.min(0.75, 0.75 * (target_res / (math.max(self_lvl * 5, 100))))
end

local function target_avg_magical_mitigation_non_binary(self_lvl, target_res)
    -- adjusted according to @src: https://royalgiraffe.github.io/resist-guide
    local resi_to_cap_ratio = target_res / (math.max(self_lvl * 5, 100));
    local beyond_half_resist_falloff = (3 / 16) * math.max(0, resi_to_cap_ratio - 2 / 3);
    return math.min(0.75, 0.75 * resi_to_cap_ratio - beyond_half_resist_falloff)
end

local function est_coef_from_rank(spell)
    -- Strange item effects behind a server script that varies effect by rank
    -- on "up to x effect" descriptions. Approximate this with interpolation between 1st and nth rank
    local coef_est;
    local max_rank = spells[sc.rank_seqs[spell.base_id][#sc.rank_seqs[spell.base_id]]].rank;
    if spell.rank > 0 then
        coef_est = spell.rank / max_rank;
    end
    return coef_est;
end

local function spell_hit_calc(extra_hit, avg_resi, loadout, spell)
    local final_hit = 0;
    local final_avg_resi = avg_resi;

    local target_is_pvp = bit.band(loadout.flags, loadout_flags.target_pvp) ~= 0;
    final_hit = spell_hit(loadout.lvl, loadout.target_lvl, extra_hit, target_is_pvp);
    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
        final_hit = 1.0;
    elseif bit.band(spell.flags, spell_flags.binary) ~= 0 then
        -- @src: https://royalgiraffe.github.io/resist-guide
        -- binary spells will have lower hit chance against higher resistances
        -- rather than partial resists
        local base_hit = spell_hit(loadout.lvl, loadout.target_lvl, 0.0, target_is_pvp);
        final_hit = math.min(0.99, base_hit * (1.0 - avg_resi) + extra_hit);
        final_avg_resi = 0.0;
    else
        final_hit = math.min(0.99, final_hit);
    end

    return final_hit, final_avg_resi;
end

local special_abilities;

local effect_flags = {
    is_periodic             = bit.lshift(1, 0),
    triggers_on_crit        = bit.lshift(1, 1),
    use_flat                = bit.lshift(1, 2),
    add_flat                = bit.lshift(1, 3),
    base_on_periodic_effect = bit.lshift(1, 4),
    should_track_crit_mod   = bit.lshift(1, 5),
    glance                  = bit.lshift(1, 6),
    no_crit                 = bit.lshift(1, 7),
    can_be_blocked          = bit.lshift(1, 8),
    always_hits             = bit.lshift(1, 9),
    shares_periodic_type    = bit.lshift(1, 10),
};

-- flexible way to add custom effects that behave according to flags
-- that both go into expectation calculation and tooltip
local function add_extra_effect(stats, flags,  utilization, description, value, ticks, freq)
    stats.num_extra_effects = stats.num_extra_effects + 1;
    local i = stats.num_extra_effects;

    stats["extra_effect_flags" .. i] = flags;
    stats["extra_effect_val" .. i] = value;
    stats["extra_effect_desc" .. i] = description;
    stats["extra_effect_util" .. i] = utilization;
    if bit.band(flags, effect_flags.is_periodic) ~= 0 then
        stats["extra_effect_ticks" .. i] = ticks;
        stats["extra_effect_tick_time" .. i] = freq;
    end
    if bit.band(flags, effect_flags.should_track_crit_mod) ~= 0 then
        stats.num_special_crit_mod_tracked = stats.num_special_crit_mod_tracked + 1;
        stats["special_crit_mod_tracked"..stats.num_special_crit_mod_tracked] = i;
    end
end

-- For physical mechanics, formulas are based on this
-- @src: https://github.com/magey/classic-warrior/wiki/Attack-table
local function stats_attack_skill(comp, spell, loadout, effects, eval_flags)
    if comp.school1 ~= schools.physical and
        bit.band(spell.flags, spell_flags.requires_ranged_slot) == 0 then
        return 0, nil;
    end

    local skill = 0;

    local subclass = nil;
    if loadout.shapeshift_no_weapon ~= 0 then
        subclass = sc.feral_skill_as_wpn_subclass_hack;
    elseif bit.band(eval_flags, evaluation_flags.isolate_oh) ~= 0 and
        bit.band(comp.flags, comp_flags.applies_oh) ~= 0 then
        subclass = effects.raw.wpn_subclass_oh;
    elseif bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 then
        --if bit.band(comp.flags, comp_flags.applies_ranged) == 0 then
        --end
        subclass = effects.raw.wpn_subclass_ranged;
    else
        subclass = effects.raw.wpn_subclass_mh;
    end

    local wpn_skill = loadout.wpn_skills[subclass];

    if wpn_skill then
        skill = skill + wpn_skill;
    else
        --skill = skill +  loadout.lvl * 5;
        wpn_skill = 0;
    end

    for mask, v in pairs(effects.wpn_subclass.skill_flat) do
        if bit.band(mask, bit.lshift(1, subclass)) ~= 0 then
            skill = skill + v;
        end
    end

    if loadout.shapeshift_no_weapon ~= 0 then
        subclass = nil;
    elseif bit.band(eval_flags, evaluation_flags.fix_weapon_skill_to_level) ~= 0 then
        skill = loadout.lvl * 5;
    end
    return skill, subclass;
end

local function stats_crit(extra, attack_skill, attack_subclass, bid, comp, spell, loadout, effects)

    -- rating may come from diffed loadout
    local crit_rating_per_perc = get_combat_rating_effect(CR_CRIT_SPELL, loadout.lvl);
    local crit_from_rating = 0.01 * (loadout.crit_rating + effects.raw.crit_rating) / crit_rating_per_perc;

    local crit = crit_from_rating + (effects.ability.crit[bid] or 0) + extra;

    if bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 or
        (comp.school1 == schools.physical and bit.band(comp.flags, comp_flags.no_attack) == 0) then

        if bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 then
            if comp.school1 ~= schools.physical then
                crit = crit + effects.by_school.crit[comp.school1] +
                    effects.by_school.crit_forced[comp.school1];
            end
            crit = crit + loadout.ranged_crit;
        else
            crit = crit + loadout.melee_crit;
        end
        local wpn_subclass_crit_active = 0.0;
        local wpn_subclass_crit_forced = 0.0;
        if attack_subclass then
            for mask, v in pairs(effects.wpn_subclass.phys_crit) do
                if bit.band(mask, bit.lshift(1, attack_subclass)) ~= 0 then
                    wpn_subclass_crit_active = wpn_subclass_crit_active + v;
                end
            end
            for mask, v in pairs(effects.wpn_subclass.phys_crit_forced) do
                if bit.band(mask, bit.lshift(1, attack_subclass)) ~= 0 then
                    wpn_subclass_crit_forced = wpn_subclass_crit_forced + v;
                end
            end
        end

        crit = crit + effects.raw.phys_crit_forced + wpn_subclass_crit_forced;

        if bit.band(loadout.flags, loadout_flags.target_pvp) == 0 then
            local base_skill = math.min(attack_skill, loadout.lvl*5);
            local diff = base_skill - loadout.target_defense;
            if diff < 0 then
                crit = crit + diff * 0.002;
            else
                crit = crit + diff * 0.0004;
            end
        else
            crit = crit + (attack_skill - loadout.target_defense) * 0.0004;
        end
    else
        crit = crit + loadout.spell_crit_by_school[comp.school1] + effects.by_school.crit_forced[comp.school1];
        local i = 2;
        while (comp["school"..i]) do
            local s = comp["school"..i];
            crit = crit + loadout.spell_crit_by_school[s] + effects.by_school.crit_forced[s]
                - (loadout.spell_crit_by_school[schools.physical] + effects.by_school.crit_forced[schools.physical])
            i = i + 1;
        end
    end
    if bit.band(comp.flags, comp_flags.cant_crit) ~= 0 and
        (not effects.ability.ignore_cant_crit[bid] or
         effects.ability.ignore_cant_crit[bid] == 0) then
        crit = 0;
    end
    return math.min(math.max(crit, 0.0), 1.0);
end

local function stats_crit_mod(bid, comp, spell, loadout, effects)

    local base_crit_mod = 0.5;
    if comp.school1 == schools.physical or
        bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 then
        base_crit_mod = 1.0;
    end

    local crit_mod_extra = 0;
    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
        crit_mod_extra = effects.by_school.crit_mod[comp.school1];
        local i = 2;
        while (comp["school"..i]) do
            crit_mod_extra = crit_mod_extra + effects.by_school.crit_mod[comp["school"..i]] -
                effects.by_school.crit_mod[schools.physical];
            i = i + 1;
        end

        if loadout.target_creature_mask then
            for mask, v in pairs(effects.creature.crit_mod) do
                if bit.band(mask, loadout.target_creature_mask) ~= 0 then
                    crit_mod_extra = crit_mod_extra + v;
                end
            end
        end
    end

    base_crit_mod = (1.0 + base_crit_mod) * (1.0 + crit_mod_extra) - 1.0;
    return 1.0 + base_crit_mod * (1.0 + (effects.ability.crit_mod[bid] or 0.0));
end

local function stats_res(comp, spell, loadout, effects)

    local target_resi = 0;
    local target_avg_mitigated = 0;

    if comp.school1 == schools.physical or
        bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then

        return target_resi, target_avg_mitigated;
    end

    local base_resi = 0;
    if bit.band(loadout.flags, loadout_flags.target_pvp) == 0 and
        bit.band(spell.flags, spell_flags.requires_ranged_slot) == 0 then
        base_resi = npc_lvl_resi_base(loadout.lvl, loadout.target_lvl);
    end
    local res_pen_flat = effects.by_school.target_res_flat[comp.school1];
    local i = 2;
    while (comp["school"..i]) do
        res_pen_flat = math.max(res_pen_flat, effects.by_school.target_res_flat[comp["school"..i]]);
        i = i + 1;
    end
    local resi = (1.0 + effects.by_school.target_res[comp.school1]) * (loadout.target_res + res_pen_flat);

    if bit.band(spell.flags, spell_flags.binary) ~= 0 then
        target_resi = math.min(loadout.lvl * 5,
            math.max(0, resi));
        target_avg_mitigated = target_avg_magical_res_binary(loadout.lvl, target_resi);
    else
        target_resi = math.min(loadout.lvl * 5,
            math.max(base_resi, resi + base_resi));
        target_avg_mitigated = target_avg_magical_mitigation_non_binary(loadout.lvl, target_resi);
    end
    if bit.band(comp.flags, comp_flags.dot_resi_pen) ~= 0 then
        -- some dots penetrate 9/10th of resi
        target_avg_mitigated = target_avg_mitigated * 0.1;
    end

    return target_resi, target_avg_mitigated;
end

local function stats_hit(res_mitigation, attack_skill, attack_subclass, bid, comp, spell, loadout, effects)

    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
        return 0.0, 0, 0;
    end

    local hit_extra = effects.ability.hit[bid] or 0.0;

    local hit_rating_per_perc = get_combat_rating_effect(CR_HIT_SPELL, loadout.lvl);
    local hit_from_rating = 0.01 * (loadout.hit_rating + effects.raw.hit_rating) / hit_rating_per_perc
    hit_extra = hit_extra + hit_from_rating;

    if comp.school1 == schools.physical and
        bit.band(comp.flags, comp_flags.no_attack) == 0 then

        hit_extra = hit_extra + loadout.phys_hit + effects.raw.phys_hit;
        if attack_subclass then
            for mask, v in pairs(effects.wpn_subclass.phys_hit) do
                if bit.band(mask, bit.lshift(1, attack_subclass)) ~= 0 then
                    hit_extra = hit_extra + v;
                end
            end
        end

        local miss;
        if loadout.target_defense - attack_skill >= 11 then
            miss = 0.05 + (loadout.target_defense - attack_skill) * 0.002;
        else
            miss = 0.05 + (loadout.target_defense - attack_skill) * 0.001;
        end
        if bit.band(loadout.flags, loadout_flags.target_pvp) ~= 0 then
            miss = 0.05 + (loadout.target_defense - attack_skill) * 0.04;
        elseif loadout.target_lvl < 10 then
            miss = miss * loadout.target_lvl * 0.1;
        end
        if effects.raw.wpn_delay_oh > 0 and bid == auto_attack_spell_id then
            miss = miss + 0.19;
        end
        miss = math.min(math.max(miss - hit_extra, 0.0), 1);

        if bit.band(comp.flags, comp_flags.always_hit) ~= 0 then
            miss = 0.0;
        end
        return miss, hit_extra, 0;
    else
        hit_extra = hit_extra +
            loadout.spell_dmg_hit_by_school[comp.school1] +
            effects.by_school.spell_hit[comp.school1];

        local i = 2;
        while (comp["school"..i]) do
            hit_extra = hit_extra + effects.by_school.spell_hit[comp["school"..i]] -
            effects.by_school.spell_hit[schools.physical];
            i = i + 1;
        end

        local hit, new_res_mitigation = spell_hit_calc(hit_extra, res_mitigation, loadout, spell);
        hit = math.min(math.max(hit, 0.0), 0.99);
        if bit.band(comp.flags, comp_flags.always_hit) ~= 0 then
            hit = 1.0;
        end
        if bit.band(comp.flags, comp_flags.ignores_mitigation) ~= 0 then
            new_res_mitigation = 0.0;
        end
        return 1.0 - hit, hit_extra, new_res_mitigation;
    end
end

local function stats_threat_mod(bid, comp, spell, effects)

    local threat_mod_flat = effects.ability.threat_flat[bid] or 0.0;
    local threat_mod = effects.ability.threat[bid] or 0.0;

    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
        threat_mod = threat_mod + effects.by_school.threat[comp.school1];
    end

    return threat_mod_flat, threat_mod;
end

local function stats_avoidances(attack_skill, comp, spell, loadout)
    if comp.school1 ~= schools.physical or
        bit.band(comp.flags, bit.bor(comp_flags.no_active_defense, comp_flags.no_attack)) ~= 0 then
        return 0.0, 0.0, 0.0, 0.0, 0.0;
    end
    local block, block_amount, parry;
    if config.loadout.behind_target or bit.band(spell.flags, spell_flags.behind_target) ~= 0 then
        block = 0.0;
        block_amount = 0.0;
        parry = 0.0;
    else
        block = math.min(0.05, 0.05 + (loadout.target_defense - attack_skill)*0.001);
        block_amount = math.floor(loadout.target_lvl*0.5);

        parry = 0.05;
        local lvl_diff = loadout.target_lvl - loadout.lvl;
        if lvl_diff >= 3 then
            parry = 0.14;
        elseif lvl_diff >= 1 and lvl_diff <= 2 then
            parry = parry + lvl_diff*0.01;
        end
    end
    local dodge;
    if bit.band(loadout.flags, loadout_flags.target_pvp) ~= 0 then
        block = 0.0;
        block_amount = 0.0;
        dodge = (loadout.target_defense - attack_skill) * 0.0004;
    else
        dodge = 0.05 + (loadout.target_defense - attack_skill) * 0.001;
    end
    if bit.band(comp.flags, comp_flags.applies_ranged) ~= 0 then
        dodge = 0.0;
        parry = 0.0;
    end

    return math.max(0.0, dodge), math.max(0.0, parry), math.max(0.0, block), block_amount;
end

local function stats_sp(bid, comp, spell, loadout, effects)

    local sp;

    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
        sp = loadout.healing_power + effects.raw.healing_power_flat;
    elseif comp.school1 == schools.physical then
        if bit.band(comp.flags, comp_flags.applies_ranged) ~= 0 then
            sp = loadout.rap + effects.raw.rap_flat;
        else
            sp = loadout.ap + effects.raw.ap_flat;
        end
    else
        if bid == auto_wand_spell_id then
            return 0;
        end

        local sp_school = loadout.spell_dmg_by_school[comp.school1] + effects.by_school.sp_dmg_flat[comp.school1];
        local i = 2;
        while (comp["school"..i]) do
            sp_school = sp_school +
                (loadout.spell_dmg_by_school[comp["school"..i]] - loadout.spell_dmg_by_school[schools.physical])
                +
                (effects.by_school.sp_dmg_flat[comp.school1] - effects.by_school.sp_dmg_flat[schools.physical]);
            i = i + 1;
        end
        sp = sp_school + (effects.ability.sp_flat[bid] or 0);
    end

    return sp;
end

local function stats_coef(combo_pts, bid, comp, spell, loadout, effects, eval_flags)

    local coef, coef_max;
    if comp.school1 == schools.physical then

        if effects.raw.wpn_delay_oh > 0 and
            bit.band(comp.flags, comp_flags.applies_oh) ~= 0 and
            bit.band(eval_flags, evaluation_flags.isolate_oh) ~= 0 then
            local speed;
            if bit.band(comp.flags, comp_flags.normalized_weapon) ~= 0 then
                speed = sc.wep_subclass_to_normalized_speed[effects.raw.wpn_subclass_oh] or 2.4;
            else
                speed = effects.raw.wpn_delay_oh;
            end
            if bit.band(comp.flags, comp_flags.full_oh) == 0 then
                coef = 0.5*(1.0 + effects.raw.offhand_mod)*dps_per_ap*speed;
            else
                coef = (1.0 + effects.raw.offhand_mod)*dps_per_ap*speed;
            end
        elseif bit.band(comp.flags, comp_flags.applies_mh) ~= 0 then

            local speed;
            if loadout.shapeshift_no_weapon ~= 0 then
                -- shapeshifts with no weapon, base on sheet speed
                speed = loadout.attack_delay_mh/effects.mul.raw.melee_haste;
            else
                if bit.band(comp.flags, comp_flags.normalized_weapon) ~= 0 then
                    speed = sc.wep_subclass_to_normalized_speed[effects.raw.wpn_subclass_mh] or 2.4;
                else
                    speed = effects.raw.wpn_delay_mh;
                end
            end
            coef = dps_per_ap*speed;
        elseif bit.band(comp.flags, comp_flags.applies_ranged) ~= 0 then
            local speed;
            if bit.band(comp.flags, comp_flags.normalized_weapon) ~= 0 then
                speed = sc.wep_subclass_to_normalized_speed[effects.raw.wpn_subclass_ranged] or 2.8;
            else
                speed = effects.raw.wpn_delay_ranged;
            end
            coef = dps_per_ap*speed;

        elseif bit.band(spell.flags, spell_flags.finishing_move_dmg) ~= 0 then

            local extra = (comp.per_cp_coef_ap or 0) * combo_pts;
            if comp.coef_ap_by_cp then
                extra = extra + comp.coef_ap_by_cp[combo_pts];
            end
            coef = (comp.coef_ap_min or 0) + extra;
            if comp.coef_ap_max then
                coef_max = comp.coef_ap_max + extra;
            end
        else
            coef = comp.coef_ap_min or 0;
            coef_max = comp.coef_ap_max;
        end
    else
        if bid == auto_wand_spell_id then
            coef = 0;
        else
            coef = (comp.coef + (effects.ability.coef_mod_flat[bid] or 0.0))
                * (1.0 + (effects.ability.coef_mod[bid] or 0.0));
        end
    end
    return coef, coef_max or coef;
end

local function stats_armor_dr(armor, comp, loadout)

    local dr = 0.0;
    if comp.school1 ~= schools.physical then
        return dr;

    elseif bit.band(comp.flags, comp_flags.ignores_mitigation) == 0 then
        dr = armor/(armor + 400 + 85 * (loadout.lvl + 4.5*(math.max(0, loadout.lvl-59))));
    end
    return dr;
end

local function stats_spell_mod(armor_dr, attack_subclass, comp, spell, effects, stats)

    local effect_mod = stats.effect_mod;
    if bit.band(comp.flags, comp_flags.periodic) ~= 0 then
        --effect_mod = effect_mod + stats.effect_mod_ot;
        effect_mod = stats.effect_mod_ot;
    end
    local spell_mod;
    if bit.band(spell.flags, spell_flags.heal) ~= 0 then

        spell_mod =
            (stats.target_vuln_mod_mul * effects.mul.raw.vuln_heal)
            *
            effects.mul.raw.heal_mod
            *
            effect_mod;

    elseif bit.band(spell.flags, spell_flags.absorb) ~= 0 then

        spell_mod = stats.target_vuln_mod_mul * effect_mod;

    elseif comp.school1 == schools.physical then
        local mod = effects.mul.raw.phys_mod * effects.mul.raw.vuln_phys;
        if attack_subclass then
            for mask, v in pairs(effects.mul.wpn_subclass.phys_mod) do
                if bit.band(mask, bit.lshift(1, attack_subclass)) ~= 0 then
                    mod = mod * v;
                end
            end
        end
        -- add phys mod that affects weapon subclasses

        spell_mod =
            (1.0 - armor_dr)
            *
            stats.target_vuln_mod_mul
            *
            stats.spell_dmg_mod_mul
            *
            mod
            *
            effect_mod;
    else

        local mod_mul = stats.spell_dmg_mod_mul * effects.mul.by_school.dmg_mod[comp.school1];
        local vuln_mul = stats.target_vuln_mod_mul * effects.mul.by_school.vuln_mod[comp.school1];
        local i = 2;
        while (comp["school"..i]) do
            local s = comp["school"..i];
            mod_mul = mod_mul *
                (1.0 + effects.mul.by_school.dmg_mod[s] - effects.mul.by_school.dmg_mod[schools.physical]);

            vuln_mul = vuln_mul *
                (1.0 + effects.mul.by_school.vuln_mod[s] - effects.mul.by_school.vuln_mod[schools.physical])
            i = i + 1;
        end

        if bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 then

            if attack_subclass then
                -- may also apply to ranged weapons, wands and presumably arcane shot etc
                for mask, v in pairs(effects.mul.wpn_subclass.spell_mod) do
                    if bit.band(mask, bit.lshift(1, attack_subclass)) ~= 0 then
                        mod_mul = mod_mul * v;
                    end
                end
            end
        end

        spell_mod =
            vuln_mul
            *
            mod_mul
            *
            effect_mod;
    end

    return spell_mod;
end

local function stats_glance(stats, bid, loadout)
    if bid ~= auto_attack_spell_id then
        return 0.0, 0.0, 0.0;
    end
    local glance_p = 0.1 + (loadout.target_lvl*5 - math.min(loadout.lvl*5, stats.attack_skill)) * 0.02;
    local glance_min =
        math.max(0.01, math.min(0.91, 1.3 - 0.05*(loadout.target_defense-stats.attack_skill)))
    local glance_max = 
        math.max(0.2, math.min(0.99, 1.3 - 0.03*(loadout.target_defense-stats.attack_skill)))

    return math.max(0.0, math.min(1.0, glance_p)), glance_min, glance_max;
end

-- Execution time of spell
local function stats_cast_time(stats, bid, comp, spell, loadout, effects, eval_flags)

    local gcd = math.min(spell.gcd, 1.5) + (effects.ability.gcd_flat[bid] or 0.0);

    local cast_time;
    if bit.band(spell.flags, spell_flags.uses_attack_speed) ~= 0 then

        if effects.raw.wpn_delay_oh > 0 and
            bit.band(comp.flags, comp_flags.applies_oh) ~= 0 and
            bit.band(eval_flags, evaluation_flags.isolate_oh) ~= 0 then
            cast_time = effects.raw.wpn_delay_oh / (effects.mul.raw.melee_haste*effects.mul.raw.melee_haste_forced);
        elseif bit.band(comp.flags, comp_flags.applies_mh) ~= 0 then
            if loadout.shapeshift_no_weapon ~= 0 then
                cast_time = loadout.attack_delay_mh / effects.mul.raw.melee_haste_forced;
            else
                cast_time = effects.raw.wpn_delay_mh / (effects.mul.raw.melee_haste*effects.mul.raw.melee_haste_forced);
            end
        elseif bit.band(comp.flags, comp_flags.applies_ranged) ~= 0 then
            cast_time = effects.raw.wpn_delay_ranged / (effects.mul.raw.ranged_haste*effects.mul.raw.ranged_haste_forced);
        end
        return cast_time, cast_time;
    end

    if bit.band(spell.flags, spell_flags.instant) ~= 0 then
        cast_time = gcd;
    elseif bit.band(spell.flags, spell_flags.channel) ~= 0 then
        cast_time = stats.dur_ot;
    else
        cast_time = spell.cast_time;
    end

    if comp.school1 == schools.physical then
        return cast_time, cast_time;
    end
    cast_time = cast_time + (effects.ability.cast_mod_flat[bid] or 0.0);

    local haste_rating_per_perc = get_combat_rating_effect(CR_HASTE_SPELL, loadout.lvl);
    local haste_from_rating = 0.01 * max(0.0, loadout.haste_rating + effects.raw.haste_rating) / haste_rating_per_perc;


    if bit.band(spell.flags, spell_flags.channel) == 0 then
        -- TODO: Needs to be changed for non vanilla
        local cast_mod =
            -effects.raw.cast_haste +
            -haste_from_rating +
            (effects.ability.cast_mod[bid] or 0.0);
        cast_time = cast_time * (1.0 + cast_mod);

        if config.settings.general_average_proc_effects then
            stats.cast_time = (1.0 - stats.becomes_instant_p) * cast_time +
                stats.becomes_instant_p * gcd;
        end
    elseif bit.band(spell.flags, spell_flags.binary) ~= 0 then
        -- channeled, binary spells will either miss on the entire cast or fully hit
        -- thus expected cast time changes with hit chance with misses only taking up one gcd
        cast_time = cast_time * (1.0 - stats.miss_ot) + gcd * stats.miss_ot;
    end
    if class == classes.druid and config.settings.general_average_proc_effects then
         --nature's grace
        if l_talents.pts[113] ~= 0 and spell.direct and bit.band(spell.flags, bit.bor(spell_flags.instant, spell_flags.channel)) == 0 then
            if bid == spids.wrath then
                gcd = gcd - 0.5;
            end

            cast_time = (1.0 - stats.crit) * cast_time + stats.crit * (math.max(gcd, cast_time-0.5));
        end
    end

    local cast_time_nogcd = cast_time;
    cast_time = math.max(cast_time, gcd);

    return cast_time, cast_time_nogcd, gcd;
end

local function stats_cost(bid, spell, loadout, effects)

    -- not clear exactly how cost rounding is done
    local base_cost = spell.cost;
    if bit.band(spell.flags, spell_flags.base_mana_cost) ~= 0 then
        base_cost = math.floor(base_cost * loadout.base_mana);
    end

    local mod_flat = effects.ability.cost_mod_flat[bid];
    if mod_flat then
        mod_flat = mod_flat * sc.power_mod[spell.power_type];
    else
        mod_flat = 0.0;
    end
    local cost =
        (base_cost + mod_flat)
        *
        (1.0 + (effects.ability.cost_mod[bid] or 0.0));

    cost = math.floor(cost + 0.5);

    return cost, base_cost;
end

-- Execution time of spell
local function stats_avg_cost(cost, stats, bid, spell, loadout, effects)

    if config.settings.general_average_proc_effects then
        cost = cost * (1.0 - (stats.clearcast_p or 0.0));
    end

    if bit.band(spell.flags, spell_flags.uses_all_power) ~= 0 then
        cost = loadout.resources[spell.power_type];
    end
    -- Assemble refunds
    local resource_refund = 0.0;
    if bit.band(spell.flags, spell_flags.only_threat) == 0 then
        resource_refund = resource_refund +
            stats.resource_refund
            +
            stats.resource_refund_mul_crit * stats.crit * (1.0 - stats.miss)
            +
            stats.resource_refund_mul_hit * (1.0 - stats.miss);

        if effects.ability.refund[bid] and effects.ability.refund[bid] ~= 0 then
            local refund = effects.ability.refund[bid];
            resource_refund = resource_refund + refund * est_coef_from_rank(spell);
        end
    end
    if bit.band(spell.flags, spell_flags.refund_on_miss) ~= 0 then
        resource_refund = resource_refund + cost*stats.miss;
    end

    cost = cost - resource_refund;
    cost = math.max(cost, 0);

    return cost, cost_actual;
end

local attack_table =  {
    "miss",
    "dodge",
    "parry",
    "glance",
    "block",
    "crit",
};

local function write_attack_table(stats, is_direct)

    local comp_substr;
    if is_direct then
        comp_substr = "";
    else
        comp_substr = "_ot";
    end
    local p_sum = 0.0;
    local crit = stats["crit"..comp_substr];
    for _, v in ipairs(attack_table) do
        local key = v..comp_substr;
        stats[key] = math.min(stats[key], 1.0 - p_sum);
        p_sum = p_sum + stats[key];
    end
    -- normal hit becomes remainder
    stats["hit_normal"..comp_substr] = 1.0 - p_sum;
    stats["crit_excess"..comp_substr] = crit - stats["crit"..comp_substr];
end

local function spell_stats_direct(stats, spell, loadout, effects, eval_flags)

    local bid = spell.base_id;

    local benefit_id = spell.beneficiary_id or bid;

    local direct = spell.direct;

    stats.attack_skill, stats.attack_subclass = stats_attack_skill(direct, spell, loadout, effects, eval_flags);

    stats.crit = stats_crit(stats.extra_crit,
                            stats.attack_skill,
                            stats.attack_subclass,
                            benefit_id,
                            direct,
                            spell,
                            loadout,
                            effects);

    stats.crit_mod = stats_crit_mod(benefit_id, direct, spell, loadout, effects);

    stats.target_resi, stats.target_avg_resi = stats_res(direct, spell, loadout, effects);
    stats.miss, stats.extra_hit, stats.target_avg_resi = stats_hit(stats.target_avg_resi,
                                                                    stats.attack_skill,
                                                                    stats.attack_subclass,
                                                                    bid,
                                                                    direct,
                                                                    spell,
                                                                    loadout,
                                                                    effects);

    stats.threat_mod_flat, stats.threat_mod = stats_threat_mod(bid, direct, spell, effects);
    stats.glance, stats.glance_min, stats.glance_max = stats_glance(stats, bid, loadout);
    stats.dodge, stats.parry, stats.block, stats.block_amount = stats_avoidances(stats.attack_skill, direct, spell, loadout);
    stats.spell_power = stats_sp(benefit_id, direct, spell, loadout, effects);
    stats.coef, stats.coef_max = stats_coef(stats.combo_pts, benefit_id, direct, spell, loadout, effects, eval_flags);
    stats.armor_dr = stats_armor_dr(stats.armor, direct, loadout);
    stats.spell_mod = stats_spell_mod(stats.armor_dr, stats.attack_subclass, direct, spell, effects, stats);

    write_attack_table(stats, true);
    -- hit used as probability to do any kind of damage, allowing procs of attack
    stats.hit = 1.0 - stats.miss - stats.dodge - stats.parry;
    if bid ~= auto_attack_spell_id then
        -- adjust to become a two roll table: if we roll a "hit",
        local crit = stats.crit + stats.crit_excess;
        stats.crit = stats.hit * crit;
        stats.hit_normal = stats.hit * (1.0 - crit);
        stats.crit_excess = 0;
    else
        if stats.glance ~= 0 then
            add_extra_effect(stats,
                             bit.bor(effect_flags.no_crit, effect_flags.glance, effect_flags.always_hits),
                             stats.glance,
                             "Glance",
                             0.5*(stats.glance_min+stats.glance_max)
                             );
        end
        if stats.block ~= 0 then
            add_extra_effect(stats,
                             bit.bor(effect_flags.no_crit, effect_flags.always_hits, effect_flags.add_flat),
                             stats.block,
                             "Block",
                             -stats.block_amount
                             );
        end

    end


    local extra_jumps;
    if effects.ability.jumps_flat[bid] then
        extra_jumps = effects.ability.jumps_flat[bid];
        if bit.band(direct.flags, comp_flags.native_jumps) == 0 and
            extra_jumps ~= 0 then 

            extra_jumps = extra_jumps - 1;
        end
    else 
        extra_jumps = 0;
    end
    stats.direct_jumps = (direct.jumps or 0) + extra_jumps;
    stats.direct_jump_amp = (direct.jump_amp or 1.0) * (1.0 + (effects.ability.jump_amp[bid] or 0.0));
end

local function spell_stats_periodic(stats, spell, loadout, effects, eval_flags)

    local bid = spell.base_id;
    local benefit_id = spell.beneficiary_id or bid;
    local periodic = spell.periodic;

    stats.attack_skill_ot, stats.attack_subclass_ot = stats_attack_skill(periodic, spell, loadout, effects, eval_flags);

    stats.crit_ot = stats_crit(stats.extra_crit,
                               stats.attack_skill_ot,
                               stats.attack_subclass_ot,
                               benefit_id,
                               periodic,
                               spell,
                               loadout,
                               effects);

    stats.crit_mod_ot = stats_crit_mod(benefit_id, periodic, spell, loadout, effects);

    stats.target_resi_ot, stats.target_avg_resi_ot = stats_res(periodic, spell, loadout, effects);

    stats.miss_ot, stats.extra_hit_ot, stats.target_avg_resi_ot = stats_hit(stats.target_avg_resi_ot,
                                                                            stats.attack_skill_ot,
                                                                            stats.attack_subclass_ot,
                                                                            bid,
                                                                            periodic,
                                                                            spell,
                                                                            loadout,
                                                                            effects);

    stats.threat_mod_flat_ot, stats.threat_mod_ot = stats_threat_mod(bid, periodic, spell, effects);
    stats.glance_ot, stats.glance_min_ot, stats.glance_max_ot = stats_glance(stats, bid, loadout);

    stats.dodge_ot, stats.parry_ot, stats.block_ot, stats.block_amount_ot = stats_avoidances(stats.attack_skill_ot, periodic, spell, loadout);
    stats.spell_power_ot = stats_sp(benefit_id, periodic, spell, loadout, effects);
    stats.coef_ot, stats.coef_ot_max = stats_coef(stats.combo_pts, benefit_id, periodic, spell, loadout, effects, eval_flags);
    stats.armor_dr_ot = stats_armor_dr(stats.armor, periodic, loadout);
    stats.spell_mod_ot = stats_spell_mod(stats.armor_dr_ot, stats.attack_subclass_ot, periodic, spell, effects, stats);

    write_attack_table(stats, false);
    -- hit used as probability to do any kind of damage, allowing procs of attack
    stats.hit_ot = 1.0 - stats.miss_ot - stats.dodge_ot - stats.parry_ot;
    if bid ~= auto_attack_spell_id then
        -- adjust to become a two roll table: if we roll a "hit",
        local crit = stats.crit_ot + stats.crit_excess_ot;
        stats.crit_ot = stats.hit_ot * crit;
        stats.hit_normal_ot = stats.hit_ot * (1.0 - crit);
        stats.crit_excess_ot = 0;
    end

    local extra_jumps;
    if effects.ability.jumps_flat[bid] then
        extra_jumps = effects.ability.jumps_flat[bid];
        if bit.band(periodic.flags, comp_flags.native_jumps) == 0 and
            extra_jumps ~= 0 then
            extra_jumps = extra_jumps - 1;
        end
    else
        extra_jumps = 0;
    end
    stats.periodic_jumps = (periodic.jumps or 0) + extra_jumps
    stats.periodic_jump_amp = (periodic.jump_amp or 1.0) * (1.0 + (effects.ability.jump_amp[bid] or 0.0));

    -- prematurely calculate final ot duration here so that channels can set cast_time to this
    -- before moving onto spell info calculation
    stats.dur_ot =
        (periodic.dur + (effects.ability.extra_dur_flat[bid] or 0.0))
        *
        (1.0 + (effects.ability.extra_dur[bid] or 0.0));

    if bit.band(spell.flags, bit.bor(spell_flags.finishing_move_dur, spell_flags.finishing_move_dmg)) ~= 0 and
        periodic.per_cp_dur then

        stats.dur_ot = stats.dur_ot + periodic.per_cp_dur * stats.combo_pts;
    end
    stats.tick_time_ot =
        periodic.tick_time + (effects.ability.extra_tick_time_flat[bid] or 0.0);
end


local stats_needing_both_components = {
    "hit",
    "hit_normal",
    "crit_mod",
    "crit",
    "miss",
    "target_avg_resi",
    "threat_mod",
    "threat_mod_flat",
    "armor_dr",
};

local spell_stats_info;

local class_stats_spell = (function()
    if class == classes.warrior then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bid == spids.shield_slam then
                stats.effect_mod_flat = stats.effect_mod_flat
                    +
                    spell.direct.per_resource *
                        (loadout.stats[attr.strength] + effects.by_attr.stat_flat[attr.strength])
                    + loadout.block_value;
            end
        end
    elseif class == classes.paladin then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then
                -- illumination
                local pts = l_talents.pts[109];
                if pts ~= 0 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + pts * 0.2 * stats.original_base_cost;
                end

                if bid == spids.holy_light and spell.rank < 4 then
                    -- Subtract healing to account for blessing of light coef for low rank holy light
                    local bol_hl_val = nil;
                    local bol = get_buff_by_lname(loadout, loadout.friendly_towards, lookups.bol_lname, false) or
                                get_buff_by_lname(loadout, loadout.friendly_towards, lookups.greater_bol_lname, false);
                    if bol then
                        -- manually configured to be at index 1
                        bol_hl_val = sc.friendly_buffs[bol][1][sc.aura_idx_value];
                    end

                    if bol_hl_val then
                        stats.effect_mod_flat = stats.effect_mod_flat
                            - bol_hl_val * lookups.bol_rank_to_hl_coef_subtract[spell.rank];
                    end
                end
            else
                if loadout.enchants[lookups.rune_wrath] then
                    stats.extra_crit = stats.extra_crit + loadout.melee_crit;
                end
                if loadout.enchants[lookups.rune_infusion_of_light] and bid == spids.holy_shock then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + stats.cost_actual;
                end
            end
        end
    elseif class == classes.hunter then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.rogue then
        return function(stats, spell, loadout, effects)
        end
    elseif class == classes.priest then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell_flags.heal, spell.flags) ~= 0 then
                if bid == spids.greater_heal then
                    if num_set_pieces(loadout, 525) >= 4 then
                        add_extra_effect(stats,
                                         bit.bor(effect_flags.triggers_on_crit, effect_flags.use_flat),
                                         1.0,
                                         "Absorb",
                                         500);
                    end
                    if num_set_pieces(loadout, 211) >= 8 then
                        local renew5 = sc.rank_seqs[spids.renew][5];
                        spell_stats_info(secondary_info,
                                         secondary_stats,
                                         spells[renew5],
                                         loadout,
                                         effects,
                                         eval_flags,
                                         spell_id);

                        add_extra_effect(stats,
                                         bit.bor(effect_flags.is_periodic, effect_flags.use_flat, effect_flags.no_crit),
                                         1.0,
                                         string.format("%s|cFFA9A9A9 %d|r:",
                                                       spell_lname(renew5),
                                                       spells[renew5].rank),
                                         secondary_info.ot_min_noncrit_if_hit1,
                                         secondary_info.ot_ticks1,
                                         secondary_info.ot_tick_time1);
                    end
                end
                if num_set_pieces(loadout, 1812) >= 6 then
                    if bid == spids.circle_of_healing then
                        add_extra_effect(stats,
                            effect_flags.is_periodic,
                            1.0,
                            spell_lname(467586),
                            0.01*dummy_value(467586, 0),
                            5,
                            3
                        );
                    elseif bid == spids.penance then
                        local lname = spell_lname(467586);
                        local val = 0.01*dummy_value(467586, 0);
                        add_extra_effect(stats, effect_flags.is_periodic, 1.0, lname, val, 5, 3 );
                        add_extra_effect(
                            stats,
                            bit.bor(effect_flags.base_on_periodic_effect, effect_flags.is_periodic),
                            1.0,
                            lname,
                            val,
                            5,
                            3
                        );
                    end
                end
            end
        end
    elseif class == classes.shaman then
        return function(anycomp, bid, stats, spell, loadout, effects)
            -- shaman clearcast
            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                -- clearcast
                local pts = l_talents.pts[106];
                if pts ~= 0 then
                    stats.clearcast_p = stats.clearcast_p + 0.1;
                end
            end

            if bid == spids.healing_wave or
                bid == spids.lesser_healing_wave or
                bid == spids.riptide then
                if num_set_pieces(loadout, 207) >= 5 or num_set_pieces(loadout, 1713) >= 4 then
                    stats.resource_refund = stats.resource_refund + 0.25 * 0.35 * stats.original_base_cost;
                end
                if loadout.enchants[lookups.rune_ancestral_awakening] then
                    add_extra_effect(
                        stats,
                        bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                        1.0,
                        spell_lname(lookups.ancestral_awakening),
                        0.01*dummy_value(lookups.ancestral_awakening, 0)
                    );
                end
            end
        end
    elseif class == classes.mage then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                -- clearcast
                local pts = l_talents.pts[106];
                if pts ~= 0 then
                    stats.clearcast_p = stats.clearcast_p + 0.02 * pts;
                end

                local pts = l_talents.pts[212];
                if pts ~= 0 and spell.direct and 
                    (spell.direct.school1 == schools.fire or spell.direct.school1 == schools.frost) then
                    -- master of elements
                    local mana_refund = pts * 0.1 * stats.original_base_cost;
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + mana_refund;
                end

                -- ignite
                local pts = l_talents.pts[203];
                if pts ~= 0 and spell.direct and spell.direct.school1 == schools.fire then
                    -- % ignite double dips in % multipliers
                    local double_dip = stats.spell_dmg_mod_mul *
                    effects.mul.by_school.dmg_mod[schools.fire] *
                    effects.mul.by_school.vuln_mod[schools.fire];

                    add_extra_effect(
                        stats,
                        bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod, effect_flags.is_periodic),
                        1.0,
                        "Ignite",
                        (pts * 0.08) * double_dip,
                        2,
                        2
                     );
                end
                if num_set_pieces(loadout, 210) >= 8 and
                    (bid == spids.frostbolt or bid == spids.fireball or bid == spids.frostfire_bolt) then
                    stats.becomes_instant_p = stats.becomes_instant_p + 0.1;
                end

                -- class_misc tracking freeze effects
                if effects.raw.class_misc > 0 then

                    stats.extra_crit = l_talents.pts[313] * 0.1;

                    if bid == spids.ice_lance then
                        stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * 3;
                    end
                end
            end
        end
    elseif class == classes.warlock then
        return function(anycomp, bid, stats, spell, loadout, effects)

        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)
            -- clearcast
            local pts = l_talents.pts[109];
            if pts and pts ~= 0 then
                if anycomp.school1 == schools.physical then
                    stats.clearcast_p = stats.clearcast_p + 0.1*pts;

                elseif bit.band(sc.game_mode, sc.game_modes.season_of_discovery) ~= 0 and
                       bit.band(spell_flags.instant, spell.flags) == 0 then

                    stats.clearcast_p = stats.clearcast_p + 0.1*pts;
                end
            end

            if (bid == spids.healing_touch or bid == spids.nourish) then
                if num_set_pieces(loadout, 521) >= 8 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.3 * stats.original_base_cost;
                end
                if num_set_pieces(loadout, 1700) >= 4 then
                    stats.resource_refund = stats.resource_refund + 0.25 * 0.35 * stats.original_base_cost;
                end
            end
            if bid == spids.lifebloom then
                stats.resource_refund_mul_hit = stats.resource_refund + 0.5 * stats.cost_actual;
            end

        end
    end
end)();

local function post_process_stats(comp, spell, stats, loadout)

    if bit.band(comp.flags, comp_flags.heal_to_full) ~= 0 then
        comp.spell_mod = 1.0;
        comp.spell_mod_ot = 1.0;
        stats.effect_mod = 1.0;
        stats.effect_mod_ot = 1.0;
        stats.effect_mod_flat = 0.0;
        stats.effect_mod_ot_flat = 0.0;
        stats.base_mod = 1.0;
        stats.base_mod_ot = 1.0;
        stats.crit = 0.0;

        local amount = (1.0 - loadout.friendly_hp_perc) * loadout.friendly_hp_max;
        stats.base_mod_flat = amount;
        stats.base_mod_ot_flat = amount;
    end

    if spell.base_id == spids.shadow_bolt and config.settings.general_average_proc_effects then
        -- Averages out ISB effect uptime based on crit for expectation
        -- but hit values displayed use the full buff if present
        local isb_pts = l_talents.pts[301];
        if isb_pts ~= 0 then
            local isb_buff_val = nil;

            local isb = get_buff_by_lname(loadout, loadout.hostile_towards, lookups.isb_lname, false, false);
            if isb then
                isb_buff_val = sc.hostile_buffs[isb][1][sc.aura_idx_value];
            end

            local isb_uptime = 1.0 - math.pow(1.0 - stats.crit, 4);

            if isb_buff_val then

                stats.spell_mod = stats.spell_mod / (1.0 + isb_buff_val);

                stats.hit_inflation = stats.hit_inflation + (1.0 + isb_buff_val)/(1.0 + isb_pts*0.04*isb_uptime) - 1;
            else
                stats.hit_inflation = stats.hit_inflation / (1.0 + isb_pts*0.04*isb_uptime);
            end
            stats.spell_mod = stats.spell_mod * (1.0 + isb_pts*0.04*isb_uptime);
        end
    end
end

local function stats_for_spell(stats, spell, loadout, effects, eval_flags)
    if not effects.finalized and sc.core.__sw__debug__ then
        print("CALLING STATS FOR SPELL WITHOUT FINALIZED EFFECTS");
    end

    local anycomp = spell.direct or spell.periodic;
    eval_flags = eval_flags or 0;
    eval_flags = bit.bor(eval_flags, mandatory_flags_by_spell(anycomp));

    local bid = spell.base_id;
    -- benefit id may be different than base id in rare cases
    -- such as where hybrid spells' (holy shock) effect benefits 
    -- only on healing part which is not on base id
    local benefit_id = spell.beneficiary_id or bid;

    stats.num_special_crit_mod_tracked = 0;
    stats.num_extra_effects = 0;
    stats.num_periodic_effects = 0;
    stats.hit_inflation = 1.0; -- inflate hit value visually while not contributing to expectation
    stats.wpn_school = anycomp.school1;
    if bid == auto_wand_spell_id then
        anycomp.school1 = math.max(1, effects.raw.wpn_school_ranged);
    end

    stats.target_vuln_mod_mul = effects.mul.ability.vuln_mod[bid] or 1.0;
    if loadout.target_creature_mask ~= 0 then
        for mask, v in pairs(effects.mul.creature.dmg_mod) do
            if bit.band(mask, loadout.target_creature_mask) ~= 0 then
                stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * v;
            end
        end
    end

    stats.spell_dmg_mod_mul = 1.0;
    stats.effect_mod = 1.0 + (effects.ability.effect_mod[benefit_id] or 0.0);
    stats.effect_mod_ot = 1.0 + (effects.ability.effect_mod_ot[benefit_id] or 0.0);
    stats.effect_mod_flat = effects.ability.effect_mod_flat[benefit_id] or 0.0;
    stats.effect_mod_ot_flat = effects.ability.effect_mod_ot_flat[benefit_id] or 0.0;
    stats.base_mod = 1.0 + (effects.ability.base_mod[benefit_id] or 0.0);
    stats.base_mod_ot = 1.0 + (effects.ability.base_mod_ot[benefit_id] or 0.0);
    stats.base_mod_flat = effects.ability.base_mod_flat[benefit_id] or 0.0;
    stats.base_mod_ot_flat = effects.ability.base_mod_ot_flat[benefit_id] or 0.0;

    stats.extra_crit = 0.0;

    stats.armor = math.max(0, (loadout.armor + effects.by_school.target_res_flat[schools.physical]) * (1.0 + effects.by_school.target_res[schools.physical]));

    stats.cost_actual, stats.original_base_cost = stats_cost(bid, spell, loadout, effects);

    if bit.band(spell.flags, bit.bor(spell_flags.finishing_move_dmg, spell_flags.finishing_move_dur)) ~= 0 then
        local combo_pts = bit.rshift(eval_flags, evaluation_flags.num_combo_points_bit_start);
        if combo_pts < 1 or combo_pts > 5 then
            combo_pts = loadout.resources[powers.combopoints];
        end
        stats.combo_pts = combo_pts;
    end

    -- generalized spell handling that may be applied
    stats.clearcast_p = 0.0;
    stats.becomes_instant_p = 0.0; -- spell is instant with probability
    stats.resource_refund = 0.0;
    stats.resource_refund_mul_crit = 0.0; -- resource refunded to be multiplied by crit
    stats.resource_refund_mul_hit = 0.0; -- resource refunded to be multiplied by hit
    -- resource refunded to be multiplied by pontentially modified spell cost and by hit

    if bit.band(anycomp.flags, comp_flags.jump_amp_as_per_extra_power) ~= 0 then
        stats.effect_mod_flat = stats.effect_mod_flat +
            anycomp.jump_amp*math.max(loadout.resources[spell.power_type] - stats.cost_actual, 0);
    end

    -- shared behavior
    class_stats_spell(anycomp, bid, stats, spell, loadout, effects);
    -- client specific behaviour injected
    sc.mechanics.client_class_stats_spell(anycomp, bid, stats, spell, loadout, effects);

    if spell.direct then
        spell_stats_direct(stats, spell, loadout, effects, eval_flags);

    else
        for _, v in pairs(stats_needing_both_components) do
            stats[v] = nil;
        end
    end
    if spell.periodic then
        spell_stats_periodic(stats, spell, loadout, effects, eval_flags);
    else
        for _, v in pairs(stats_needing_both_components) do
            stats[v.."_ot"] = nil;
        end
    end

    -- special things may need to be added at this final stage
    post_process_stats(anycomp, spell, stats, loadout)

    -- Temporary workaround:
    -- Direct or OT counterpart my need to be defined for tooltips
    -- when secondary components are dynamically added like ignite
    for _, v in pairs(stats_needing_both_components) do
        stats[v] = stats[v] or stats[v.."_ot"];
        stats[v.."_ot"] = stats[v.."_ot"] or stats[v];
    end

    stats.cast_time, stats.cast_time_nogcd, stats.gcd =
        stats_cast_time(stats, bid, anycomp, spell, loadout, effects, eval_flags);

    stats.cost = stats_avg_cost(stats.cost_actual, stats, bid, spell, loadout, effects);

    stats.cost_per_sec = stats.cost / stats.cast_time;
end

local function resolve_extra_spell_effects(info, stats)

    info.glance_index = -1;
    for k = 1, stats.num_extra_effects do

        local flags = stats["extra_effect_flags" .. k];

        local hit_normal = stats.hit_normal;
        local hit_normal_ot = stats.hit_normal_ot;

        local crit_cap = 1.0;
        if bit.band(flags, effect_flags.no_crit) ~= 0 then
            crit_cap = 0.0;
            -- cant crit but effect needs to reclaim hit % from ignored crit %
            hit_normal = stats.hit_normal + stats.crit;
            hit_normal_ot = stats.hit_normal_ot + stats.crit_ot;
        end
        local hit_min = 0.0;
        if bit.band(flags, effect_flags.always_hits) ~= 0 then
            hit_min = 1.0;
        end

        local val = stats["extra_effect_val" .. k];
        local flat = 0;
        if bit.band(flags, bit.bor(effect_flags.use_flat, effect_flags.add_flat)) ~= 0 then
            flat = val;
            val = 1.0;
        end

        if bit.band(flags, effect_flags.is_periodic) ~= 0 then
            info.num_periodic_effects = info.num_periodic_effects + 1;
            local i = info.num_periodic_effects;

            info["ot_flags" .. i] = flags;

            if bit.band(flags, effect_flags.base_on_periodic_effect) ~= 0 then
                info["ot_min_noncrit_if_hit" .. i] = val * info.ot_min_noncrit_if_hit1;
                info["ot_max_noncrit_if_hit" .. i] = val * info.ot_max_noncrit_if_hit1;
                info["ot_min_crit_if_hit" .. i] = val * info.ot_min_crit_if_hit1;
                info["ot_max_crit_if_hit" .. i] = val * info.ot_max_crit_if_hit1;

                info["ot_hit_normal" .. i] = math.max(hit_min, hit_normal_ot);

            else
                info["ot_min_noncrit_if_hit" .. i] = val * info.min_noncrit_if_hit1;
                info["ot_max_noncrit_if_hit" .. i] = val * info.max_noncrit_if_hit1;
                info["ot_min_crit_if_hit" .. i] = val * info.min_crit_if_hit1;
                info["ot_max_crit_if_hit" .. i] = val * info.max_crit_if_hit1;

                info["ot_hit_normal" .. i] = math.max(hit_min, hit_normal);
            end
            if bit.band(flags, effect_flags.use_flat) ~= 0 then
                info["ot_min_noncrit_if_hit" .. i] = flat;
                info["ot_max_noncrit_if_hit" .. i] = flat;
                info["ot_min_crit_if_hit" .. i] = flat;
                info["ot_max_crit_if_hit" .. i] = flat;
            end
            if bit.band(flags, effect_flags.shares_periodic_type) ~= 0 then
                info["ot_ticks" .. i] = info.ot_ticks1;
                info["ot_tick_time" .. i] = info.ot_tick_time1;
                info["ot_dur" .. i] = info.ot_dur1;
            else
                info["ot_ticks" .. i] = stats["extra_effect_ticks" .. k];
                info["ot_tick_time" .. i] = stats["extra_effect_tick_time" .. k];
                info["ot_dur" .. i] = stats["extra_effect_ticks" .. k] * stats["extra_effect_tick_time" .. k];
            end

            info["ot_description" .. i] = stats["extra_effect_desc" .. k];
            info["ot_crit" .. i] = math.min(stats.crit, crit_cap);
            info["ot_utilization" .. i] = stats["extra_effect_util" .. k];
            if bit.band(flags, effect_flags.triggers_on_crit) ~= 0 then
                info["ot_min_noncrit_if_hit" .. i] = 0;
                info["ot_max_noncrit_if_hit" .. i] = 0;
            end
        else
            info.num_direct_effects = info.num_direct_effects + 1;
            local i = info.num_direct_effects;

            if bit.band(flags, effect_flags.glance) ~= 0 then
                info.glance_index = i;
            end
            info["direct_flags" .. i] = flags;
            info["direct_description" .. i] = stats["extra_effect_desc" .. k];
            info["direct_utilization" .. i] = stats["extra_effect_util" .. k];

            info["crit" .. i] = math.min(stats.crit, crit_cap);

            if bit.band(flags, effect_flags.base_on_periodic_effect) ~= 0 then
                info["min_noncrit_if_hit" .. i] = val * info.ot_min_noncrit_if_hit1;
                info["max_noncrit_if_hit" .. i] = val * info.ot_max_noncrit_if_hit1;
                info["min_crit_if_hit" .. i] = val * info.ot_min_crit_if_hit1;
                info["max_crit_if_hit" .. i] = val * info.ot_max_crit_if_hit1;
                info["hit_normal" .. i] = math.max(hit_min, hit_normal_ot);
            else
                info["min_noncrit_if_hit" .. i] = math.max(0, val * info.min_noncrit_if_hit1 + flat);
                info["max_noncrit_if_hit" .. i] = math.max(0, val * info.max_noncrit_if_hit1 + flat);
                info["min_crit_if_hit" .. i] = math.max(0, val * info.min_crit_if_hit1 + flat);
                info["max_crit_if_hit" .. i] = math.max(0, val * info.max_crit_if_hit1 + flat);
                info["hit_normal" .. i] = math.max(hit_min, hit_normal);
            end
            if bit.band(flags, effect_flags.use_flat) ~= 0 then
                info["min_noncrit_if_hit" .. i] = flat;
                info["max_noncrit_if_hit" .. i] = flat;
                info["min_crit_if_hit" .. i] = flat;
                info["max_crit_if_hit" .. i] = flat;
            end
            if bit.band(flags, effect_flags.triggers_on_crit) ~= 0 then
                info["min_noncrit_if_hit" .. i] = 0;
                info["max_noncrit_if_hit" .. i] = 0;
            end
        end
    end

    -- accumulate periodics 
    info.total_ot_min_noncrit_if_hit = 0;
    info.total_ot_max_noncrit_if_hit = 0;
    info.total_ot_min_crit_if_hit = 0;
    info.total_ot_max_crit_if_hit = 0;
    for i = 1, info.num_periodic_effects do
        local p                   = info["ot_utilization" .. i];
        info.total_ot_min_noncrit_if_hit = info.total_ot_min_noncrit_if_hit + p * info["ot_min_noncrit_if_hit" .. i];
        info.total_ot_max_noncrit_if_hit = info.total_ot_max_noncrit_if_hit + p * info["ot_max_noncrit_if_hit" .. i];
        if info["ot_crit" .. i] ~= 0 then
            info.total_ot_min_crit_if_hit    = info.total_ot_min_crit_if_hit    + p * info["ot_min_crit_if_hit" .. i];
            info.total_ot_max_crit_if_hit    = info.total_ot_max_crit_if_hit    + p * info["ot_max_crit_if_hit" .. i];
        end
    end

    -- accumulate directs
    info.total_min_noncrit_if_hit = 0;
    info.total_max_noncrit_if_hit = 0;
    info.total_min_crit_if_hit    = 0;
    info.total_max_crit_if_hit    = 0;
    for i = 1, info.num_direct_effects do
        local p                       = info["direct_utilization" .. i];
        info.total_min_noncrit_if_hit = info.total_min_noncrit_if_hit + p * info["min_noncrit_if_hit" .. i];
        info.total_max_noncrit_if_hit = info.total_max_noncrit_if_hit + p * info["max_noncrit_if_hit" .. i];
        if info["crit" .. i] ~= 0 then
            info.total_min_crit_if_hit    = info.total_min_crit_if_hit + p * info["min_crit_if_hit" .. i];
            info.total_max_crit_if_hit    = info.total_max_crit_if_hit + p * info["max_crit_if_hit" .. i];
        end
    end
end

local function add_expectation_direct_st(info, num_to_add)
    local added = info.expected_direct_st * num_to_add;
    info.expected_direct = info.expected_direct + added;
    info.expected = info.expected + added;

    local threat_added = info.threat_direct_st * num_to_add;
    info.threat_direct = info.threat_direct + threat_added;
    info.threat = info.threat + threat_added;
end

local function add_expectation_ot_st(info, num_to_add)
    local added = info.expected_ot_st * num_to_add;
    info.expected_ot = info.expected_ot + added;
    info.expected = info.expected + added;

    local threat_added = info.threat_ot_st * num_to_add;
    info.threat_ot = info.threat_ot + threat_added;
    info.threat = info.threat + threat_added;
end

local function calc_expectation(info, spell, stats, loadout, num_unbounded_targets)

    -- direct
    local expected_direct_sum = 0;
    for i = 1, info.num_direct_effects do

        local effect_expected = 0.5 * info["direct_utilization"..i] *
            (info["hit_normal"..i] *
                (info["min_noncrit_if_hit" .. i] + info["max_noncrit_if_hit"..i])
            +
            info["crit"..i] *
                (info["min_crit_if_hit"..i] + info["max_crit_if_hit"..i])
            );
            -- for two roll table where normal hits and crits can be blocked
            if bit.band(info["direct_flags"..i], effect_flags.can_be_blocked) ~= 0 then
                effect_expected = math.max(0, effect_expected - stats.block * stats.block_amount);
            end
        expected_direct_sum = expected_direct_sum + effect_expected;
    end

    if info.num_direct_effects > 0 then
        --info.expected_direct_st = stats.hit * expected_direct_if_hit * (1 - stats.target_avg_resi);
        info.expected_direct_st = expected_direct_sum * (1 - stats.target_avg_resi);
        info.expected_direct = info.expected_direct_st;

        local flat_threat = stats.threat_mod_flat;
        local threat_mod_of_expected = 1.0;
        if spell.direct then
            flat_threat = flat_threat + (spell.direct.threat_mod_flat or 0.0);
            threat_mod_of_expected = threat_mod_of_expected + (spell.direct.threat_mod or 0.0);
        end
        info.threat_direct_st = (1.0 + stats.threat_mod) *
            ((info.expected_direct_st * threat_mod_of_expected) + ((1.0 - stats.miss) * flat_threat));
        info.threat_direct = info.threat_direct_st;

        if spell.direct and bit.band(spell.direct.flags, comp_flags.unbounded_aoe) ~= 0 then
            info.expected_direct = info.expected_direct_st * num_unbounded_targets;

            info.threat_direct = info.threat_direct_st * num_unbounded_targets;
        end
    else
        info.expected_direct_st = 0;
        info.expected_direct = 0;

        info.threat_direct_st = 0;
        info.threat_direct = 0;
    end

    -- over time
    local expected_ot_sum = 0;
    for i = 1, info.num_periodic_effects do

        local effect_expected = 0.5 * info["ot_utilization"..i] *
            (info["ot_hit_normal"..i] *
                (info["ot_min_noncrit_if_hit" .. i] + info["ot_max_noncrit_if_hit"..i])
            +
            info["ot_crit"..i] *
                (info["ot_min_crit_if_hit"..i] + info["ot_max_crit_if_hit"..i])
            );
            if bit.band(info["ot_flags"..i], effect_flags.can_be_blocked) ~= 0 then
                effect_expected = effect_expected - stats.block_ot * stats.block_amount_ot;
            end

        expected_ot_sum = expected_ot_sum + effect_expected;
    end

    if info.num_periodic_effects > 0 then
        info.expected_ot_st = expected_ot_sum * (1 - stats.target_avg_resi_ot);
        info.expected_ot = info.expected_ot_st;

        local flat_threat = stats.threat_mod_flat_ot;
        local threat_mod_of_expected = 1.0;
        if spell.periodic then
            flat_threat = (flat_threat + (spell.periodic.threat_mod_flat or 0.0)) * info.ot_ticks1;
            threat_mod_of_expected = threat_mod_of_expected + (spell.periodic.threat_mod or 0.0);
        end

        info.threat_ot_st = (1.0 + stats.threat_mod_ot) *
            ((info.expected_ot_st * threat_mod_of_expected) + ((1.0 - stats.miss_ot) * flat_threat));
        info.threat_ot = info.threat_ot_st;

        if spell.periodic and bit.band(spell.periodic.flags, comp_flags.unbounded_aoe) ~= 0 then
            info.expected_ot = info.expected_ot_st * num_unbounded_targets;
            info.threat_ot = info.threat_ot_st * num_unbounded_targets;
        end
    else
        info.expected_ot_st = 0;
        info.expected_ot = 0;

        info.threat_ot_st = 0;
        info.threat_ot = 0;
    end

    -- combine
    info.expected_st = info.expected_direct_st + info.expected_ot_st
    info.expected = info.expected_direct + info.expected_ot

    info.threat_st = info.threat_direct_st + info.threat_ot_st
    info.threat = info.threat_direct + info.threat_ot

    if loadout.beacon and bit.band(spell.flags, spell_flags.heal) ~= 0 then
        add_expectation_direct_st(info, 0.75);
    end
end

local function direct_info(info, spell, loadout, stats, effects, eval_flags)
    local direct = spell.direct;
    local clvl = loadout.lvl;

    local base_min = direct.min;
    local base_max = direct.max;

    if direct.per_lvl_sq == 0 then
        local lvl_diff_applicable = math.max(0,
            math.min(clvl - spell.lvl_req, spell.lvl_max - spell.lvl_req));
        base_min = base_min + direct.per_lvl * lvl_diff_applicable;
        base_max = base_max + direct.per_lvl * lvl_diff_applicable;
    else
        local added_effect = direct.per_lvl * clvl + direct.per_lvl_sq * clvl * clvl;
        base_min = direct.min * (direct.base_min + added_effect);
        base_max = direct.max * (direct.base_max + added_effect);
    end

    local phys_dmg_flat = effects.raw.phys_dmg_flat;
    if direct.school1 == schools.physical then
        if stats.attack_subclass then
            for mask, v in pairs(effects.wpn_subclass.phys_dmg_flat) do
                if bit.band(mask, bit.lshift(1, stats.attack_subclass)) ~= 0 then
                    phys_dmg_flat = phys_dmg_flat + v;
                end
            end
        end
    end

    if effects.raw.wpn_delay_oh > 0 and
        bit.band(direct.flags, comp_flags.applies_oh) ~= 0 and
        bit.band(eval_flags, evaluation_flags.isolate_oh) ~= 0 then

        local mod_oh;
        if bit.band(direct.flags, comp_flags.full_oh) == 0 then
            mod_oh = 0.5*(1.0 + effects.raw.offhand_mod);
        else
            mod_oh = 1.0 + effects.raw.offhand_mod;
        end

        base_min = (direct.base_min + phys_dmg_flat + effects.raw.wpn_min_oh*mod_oh) * base_min;
        base_max = (direct.base_max + phys_dmg_flat + effects.raw.wpn_max_oh*mod_oh) * base_max;
    elseif bit.band(direct.flags, comp_flags.applies_mh) ~= 0 then
        -- Not sure about cat/bear form base damage, reverse engineer from sheet dmg
        if loadout.shapeshift_no_weapon ~= 0 then
            local ap_reduce = loadout.ap*stats.coef;
            local m1_min_base = (loadout.attack_min_mh/loadout.attack_mod) - ap_reduce;--loadout.m_pos + loadout.m_neg;
            local m1_max_base = (loadout.attack_max_mh/loadout.attack_mod) - ap_reduce;--loadout.m_pos + loadout.m_neg;
            base_min = (direct.base_min + m1_min_base) * base_min;
            base_max = (direct.base_max + m1_max_base) * base_max;
        else
            base_min = (direct.base_min + phys_dmg_flat + effects.raw.wpn_min_mh) * base_min;
            base_max = (direct.base_max + phys_dmg_flat + effects.raw.wpn_max_mh) * base_max;
        end
    elseif bit.band(direct.flags, comp_flags.applies_ranged) ~= 0 then
        local ammo_flat = effects.raw.ammo_dps * effects.raw.wpn_delay_ranged;

        base_min = (direct.base_min + phys_dmg_flat + effects.raw.wpn_min_ranged + ammo_flat) * base_min;
        base_max = (direct.base_max + phys_dmg_flat + effects.raw.wpn_max_ranged + ammo_flat) * base_max;

    elseif bit.band(spell.flags, spell_flags.finishing_move_dmg) ~= 0 then
        -- seems like finishing moves are never weapon damage based
        base_min = base_min + direct.per_resource * stats.combo_pts;
        base_max = base_max + direct.per_resource * stats.combo_pts;
    end

    info.base_min = base_min;
    info.base_max = base_max;

    info.min_noncrit_if_hit_base1 =
        (stats.base_mod * (base_min + stats.base_mod_flat) + stats.effect_mod_flat) * stats.spell_mod;
    info.max_noncrit_if_hit_base1 =
        (stats.base_mod * (base_max + stats.base_mod_flat) + stats.effect_mod_flat) * stats.spell_mod;
    info.min_noncrit_if_hit1 =
        info.min_noncrit_if_hit_base1 + (stats.spell_power * stats.coef) * stats.spell_mod;
    info.max_noncrit_if_hit1 =
        info.max_noncrit_if_hit_base1 + (stats.spell_power * stats.coef_max) * stats.spell_mod;

    info.min_crit_if_hit1 = info.min_noncrit_if_hit1 * stats.crit_mod;
    info.max_crit_if_hit1 = info.max_noncrit_if_hit1 * stats.crit_mod;

    -- needed to fit generalized template for expectation
    info.crit1 = stats.crit;
    info.hit_normal1 = stats.hit_normal;
    info.direct_flags1 = 0;
    if spell.base_id ~= auto_attack_spell_id then
        info.direct_flags1 = bit.bor(info.direct_flags1, effect_flags.can_be_blocked);
    end
    info.direct_utilization1 = 1.0;

    info.num_direct_effects = info.num_direct_effects + 1;
end

local function periodic_info(info, spell, loadout, stats, effects, eval_flags)
    local periodic = spell.periodic;
    local clvl = loadout.lvl;

    local base_tick_min = periodic.min;
    local base_tick_max = periodic.max;

    if periodic.per_lvl_sq == 0 then
        local lvl_diff_applicable = math.max(0,
            math.min(clvl - spell.lvl_req, spell.lvl_max - spell.lvl_req));
        base_tick_min = base_tick_min + periodic.per_lvl * lvl_diff_applicable;
        base_tick_max = base_tick_max + periodic.per_lvl * lvl_diff_applicable;

    else
        local added_effect = periodic.per_lvl * clvl + periodic.per_lvl_sq * clvl * clvl;
        base_tick_min = periodic.min * (periodic.base_min + added_effect);
        base_tick_max = periodic.max * (periodic.base_max + added_effect);
    end

    info.ot_dur1 = stats.dur_ot;
    info.ot_tick_time1 = stats.tick_time_ot;

    -- Might want to deal with some weapon based spells as periodic here later


    if bit.band(spell.flags, spell_flags.finishing_move_dmg) ~= 0 then
        base_tick_min = base_tick_min + periodic.per_resource * stats.combo_pts;
        base_tick_max = base_tick_max + periodic.per_resource * stats.combo_pts;
    end
    if bit.band(spell.flags, bit.bor(spell_flags.finishing_move_dur, spell_flags.finishing_move_dmg)) ~= 0 and not periodic.per_cp_dur then
        -- finishing move with assigned periodic.per_cp_dur has already been added,
        -- this is the other case
        info.ot_dur1 = info.ot_dur1 + info.ot_tick_time1 * stats.combo_pts;
    end

    -- round so tooltip is displayed nicely
    --info.ot_ticks1 = math.floor(0.5 + (info.ot_dur1 / info.ot_tick_time1));
    info.ot_ticks1 = info.ot_dur1 / info.ot_tick_time1;
    info.longest_ot_duration = info.ot_dur1;

    info.ot_base_min = base_tick_min;
    info.ot_base_max = base_tick_max;

    local mod = info.ot_ticks1 * stats.spell_mod_ot;

    info.ot_min_noncrit_if_hit_base1 =
        (stats.base_mod_ot * (base_tick_min + stats.base_mod_ot_flat) + stats.effect_mod_ot_flat) * mod;
    info.ot_max_noncrit_if_hit_base1 =
        (stats.base_mod_ot * (base_tick_max + stats.base_mod_ot_flat) + stats.effect_mod_ot_flat) * mod;

    info.ot_min_noncrit_if_hit1 = info.ot_min_noncrit_if_hit_base1 + (stats.coef_ot * stats.spell_power_ot) * mod;
    info.ot_max_noncrit_if_hit1 = info.ot_max_noncrit_if_hit_base1 + (stats.coef_ot_max * stats.spell_power_ot) * mod;

    info.ot_min_crit_if_hit1 = info.ot_min_noncrit_if_hit1 * stats.crit_mod_ot;
    info.ot_max_crit_if_hit1 = info.ot_max_noncrit_if_hit1 * stats.crit_mod_ot;

    -- needed to fit generalized template for expectation
    info.ot_crit1 = stats.crit_ot;
    info.ot_hit_normal1 = stats.hit_normal_ot;
    info.ot_flags1 = 0;
    info.ot_utilization1 = 1.0;
    info.ot_flags1 = bit.bor(info.ot_flags1, effect_flags.can_be_blocked);

    info.num_periodic_effects = info.num_periodic_effects + 1;
end

local expectation_variations = {
    "expected", "expected_st", "expected_ot", "expected_ot_st", "expected_direct", "expected_direct_st", "threat", "threat_st", "threat_ot", "threat_ot_st", "threat_direct", "threat_direct_st"
};

local function spell_info(info, spell, stats, loadout, effects, eval_flags, spell_id)

    if not effects.finalized and sc.core.__sw__debug__ then
        print("CALLING SPELL INFO FOR SPELL WITHOUT FINALIZED EFFECTS");
    end
    local anycomp = spell.direct or spell.periodic;

    eval_flags = eval_flags or 0;

    eval_flags = bit.bor(eval_flags, mandatory_flags_by_spell(anycomp));

    info.num_periodic_effects = 0;
    info.num_direct_effects = 0;

    if spell.direct then
        direct_info(info, spell, loadout, stats, effects, eval_flags);
    end
    if spell.periodic then
        periodic_info(info, spell, loadout, stats, effects, eval_flags);
    end

    local num_unbounded_targets = config.loadout.unbounded_aoe_targets;

    resolve_extra_spell_effects(info, stats);

    calc_expectation(info, spell, stats, loadout, num_unbounded_targets);

    if stats.direct_jumps then
        if (stats.direct_jump_amp ~= 1.0) then
            local jmp_sum = 0;
            for i = 1, stats.direct_jumps do
                local jmp_effect = 1;
                for _ = 1, i do
                    jmp_effect = jmp_effect * stats.direct_jump_amp;
                end
                jmp_sum = jmp_sum + jmp_effect;
            end
            add_expectation_direct_st(info, jmp_sum);
        else
            add_expectation_direct_st(info, stats.direct_jumps);
        end
    end
    if stats.periodic_jumps then
        if (stats.periodic_jump_amp ~= 1.0) then
            local jmp_sum = 0;
            for i = 1, stats.periodic_jumps do
                local jmp_effect = 1;
                for _ = 1, i do
                    jmp_effect = jmp_effect * stats.periodic_jump_amp;
                end
                jmp_sum = jmp_sum + jmp_effect;
            end
            add_expectation_ot_st(info, jmp_sum);
        else
            add_expectation_ot_st(info, stats.periodic_jumps);
        end
    end
    if special_abilities[spell.base_id] then
        special_abilities[spell.base_id](spell, info, loadout, stats, effects);
    end

    if bit.band(eval_flags, evaluation_flags.isolate_periodic) ~= 0 then
        info.expected_st = info.expected_st - info.expected_direct_st;
        info.expected = info.expected - info.expected_direct;
        info.expected_direct_st = 0;
        info.expected_direct = 0;

        info.threat_st = info.threat_st - info.threat_direct_st;
        info.threat = info.threat - info.threat_direct;
        info.threat_direct_st = 0;
        info.threat_direct = 0;

    end
    if bit.band(eval_flags, evaluation_flags.isolate_direct) ~= 0 then
        info.expected_st = info.expected_st - info.expected_ot_st;
        info.expected = info.expected - info.expected_ot;
        info.expected_ot_st = 0;
        info.expected_ot = 0;

        info.threat_st = info.threat_st - info.threat_ot_st;
        info.threat = info.threat - info.threat_ot;
        info.threat_ot_st = 0;
        info.threat_ot = 0;
    end

    info.aoe_to_single_ratio = info.expected/info.expected_st;
    if info.expected < info.expected_st or
        bit.band(eval_flags, evaluation_flags.assume_single_effect) ~= 0 then


        info.expected = info.expected_st;
        info.expected_ot = info.expected_ot_st;
        info.expected_direct = info.expected_direct_st
    end

    if info.threat < info.threat_st or
        bit.band(eval_flags, evaluation_flags.assume_single_effect) ~= 0 then

        info.threat = info.threat_st;
        info.threat_ot = info.threat_ot_st;
        info.threat_direct = info.threat_direct_st
    end

    if bit.band(spell.flags, spell_flags.on_next_attack) ~= 0 and
        bit.band(eval_flags, evaluation_flags.expectation_of_self) == 0 then

        spell_stats_info(secondary_info,
                         secondary_stats,
                         spells[auto_attack_spell_id],
                         loadout,
                         effects,
                         bit.bor(eval_flags, evaluation_flags.isolate_mh),
                         spell_id);

        local atk = secondary_info;
        for _, v in pairs(expectation_variations) do
            info[v] = info[v] - atk[v];
        end
    end
    if bit.band(spell.flags, spell_flags.no_threat) ~= 0 then
        info.threat = 0;
    end

    if stats.cast_time == 0 then
        info.effect_per_sec = math.huge;
        info.threat_per_sec = math.huge
    else
        info.effect_per_sec = info.expected / stats.cast_time;
        info.threat_per_sec = info.threat / stats.cast_time;
    end

    local dual_wield_flags = bit.bor(comp_flags.applies_mh, comp_flags.applies_oh);

    if effects.raw.wpn_delay_oh > 0 and
        bit.band(anycomp.flags, dual_wield_flags) == dual_wield_flags and
        bit.band(eval_flags, bit.bor(evaluation_flags.isolate_mh, evaluation_flags.isolate_oh)) == 0 then
        -- evaluate dual wield combined weapons

        spell_stats_info(secondary_info,
                         secondary_stats,
                         spell,
                         loadout,
                         effects,
                         bit.bor(eval_flags, evaluation_flags.isolate_oh),
                         spell_id);

        info.oh_info = secondary_info;
        info.oh_stats = secondary_stats;

        for _, v in pairs(expectation_variations) do
            info[v] = info[v] + info.oh_info[v];
        end

        info.effect_per_sec = info.effect_per_sec + info.oh_info.effect_per_sec;
        info.threat_per_sec = info.threat_per_sec + info.oh_info.threat_per_sec;
    else
        info.oh_info, info.oh_stats = nil, nil;
    end

    if stats.cost == 0 then
        info.effect_per_cost = math.huge;
        info.threat_per_cost = math.huge;
    else
        info.effect_per_cost = info.expected / stats.cost;
        info.threat_per_cost = info.threat / stats.cost;
    end

    info.cost_per_sec = stats.cost / stats.cast_time;

    if info.num_direct_effects > 0 then

        info.min_noncrit_if_hit1 = info.min_noncrit_if_hit1 * stats.hit_inflation;
        info.max_noncrit_if_hit1 = info.max_noncrit_if_hit1 * stats.hit_inflation;
        info.min_crit_if_hit1 = info.min_crit_if_hit1 * stats.hit_inflation;
        info.max_crit_if_hit1 = info.max_crit_if_hit1 * stats.hit_inflation;
    end

    if info.num_periodic_effects > 0 then
        info.longest_ot_duration = info.longest_ot_duration or 0;
        for i = 2, info.num_periodic_effects do
            info.longest_ot_duration = math.max(info.longest_ot_duration, info["ot_dur" .. i]);
        end
        info.effect_per_dur = 0;
        if info.longest_ot_duration ~= 0 then
            info.effect_per_dur = info.expected_ot / info.longest_ot_duration;
        end

        info.ot_min_noncrit_if_hit1 = info.ot_min_noncrit_if_hit1 * stats.hit_inflation;
        info.ot_max_noncrit_if_hit1 = info.ot_max_noncrit_if_hit1 * stats.hit_inflation;
        info.ot_min_crit_if_hit1 = info.ot_min_crit_if_hit1 * stats.hit_inflation;
        info.ot_max_crit_if_hit1 = info.ot_max_crit_if_hit1 * stats.hit_inflation;
    end

end

local function cast_until_oom(spell_effect, spell, stats, loadout, effects, calculating_weights, eval_flags)

    if spell.power_type ~= powers.mana then
        spell_effect.num_casts_until_oom = nil;
        spell_effect.effect_until_oom = nil;
        spell_effect.time_until_oom = nil;
        spell_effect.mp1 = nil;
        return;
    end

    local mana = config.loadout.extra_mana + effects.raw.mana;
    if bit.band(eval_flags, evaluation_flags.at_max_mana) ~= 0 then
        mana = mana + loadout.resources_max[powers.mana];
    else
        mana = mana + loadout.resources[powers.mana];
    end

    local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];

    local mp2_not_casting = spirit_mana_regen(spirit);

    if not calculating_weights then
        mp2_not_casting = math.ceil(mp2_not_casting);
    end
    local mp5 = effects.raw.mp5_flat
        +
        loadout.resources_max[powers.mana] * effects.raw.perc_max_mana_as_mp5
        +
        effects.raw.mp5_from_int_mod * (loadout.stats[attr.intellect] +
            effects.by_attr.stat_flat[attr.intellect]);

    local mp1_casting =
        0.2 * mp5 +
        0.5 * mp2_not_casting * math.max(0, math.min(1.0, effects.raw.regen_while_casting));

    --  don't use dynamic mana regen lua api for now
    calculating_weights = true;

    if not config.loadout.use_custom_talents and not calculating_weights then
        local _, x = GetManaRegen()
        mp1_casting = x;
    end

    local resource_loss_per_sec = spell_effect.cost_per_sec - mp1_casting;
    spell_effect.mana = mana;

    if resource_loss_per_sec <= 0 then
        spell_effect.num_casts_until_oom = math.huge;
        spell_effect.effect_until_oom = math.huge;
        spell_effect.time_until_oom = math.huge;
        spell_effect.mp1 = mp1_casting;
    else
        spell_effect.time_until_oom = mana / resource_loss_per_sec;
        spell_effect.num_casts_until_oom = spell_effect.time_until_oom / stats.cast_time;
        spell_effect.effect_until_oom = spell_effect.num_casts_until_oom * spell_effect.expected;
        spell_effect.mp1 = mp1_casting;
    end
end

if class == "SHAMAN" then
    special_abilities = {
    };
elseif class == "PRIEST" then
    special_abilities = {
    };
elseif class == "DRUID" then
    special_abilities = {
    };
elseif class == "WARLOCK" then
    special_abilities = {
    };
elseif class == "PALADIN" then
    special_abilities = {
    };
elseif class == "MAGE" then
    special_abilities = {
        [spids.mana_shield] = function(spell, info, loadout, stats)
            local pts = l_talents.pts[110];
            local drain_mod = 0.1 * pts;
            if loadout.enchants[lookups.rune_advanced_warding] then
                drain_mod = drain_mod + 0.5;
            end
            stats.cost = stats.cost + 2 * info.min_noncrit_if_hit1 * (1.0 - drain_mod);
        end,
        [spids.mana_shield_2] = function(spell, info, loadout, stats)
            local pts = l_talents.pts[110];
            local drain_mod = 0.1 * pts;
            if loadout.enchants[lookups.rune_advanced_warding] then
                drain_mod = drain_mod + 0.5;
            end
            stats.cost = stats.cost + 1 * info.min_noncrit_if_hit1 * (1.0 - drain_mod);
        end,
    };
else
    special_abilities = {};
end

local function resource_regen_info(info, spell, spell_id, loadout, effects, _)

    if not effects.finalized and sc.core.__sw__debug__ then
        print("CALLING SPELL INFO FOR SPELL WITHOUT FINALIZED EFFECTS");
    end

    local min;
    local bid = spell.base_id;
    local direct = spell.direct;
    local periodic = spell.periodic;
    local clvl = loadout.lvl;

    info.tick_restored = 0;
    info.restored = 0;
    info.ticks = 0;

    if direct then

        if direct.per_lvl_sq == 0 then
            local lvl_diff_applicable = math.max(0,
                math.min(clvl - spell.lvl_req, spell.lvl_max - spell.lvl_req));
            min = direct.min + direct.per_lvl * lvl_diff_applicable;
        else
            local added_effect = direct.per_lvl * clvl + direct.per_lvl_sq * clvl * clvl;
            min = direct.min * (direct.base_min + added_effect);
        end
        min =
            (
                (
                    (min + (effects.ability.base_mod_flat[bid] or 0.0))
                    *
                    (1.0 + (effects.ability.base_mod[bid] or 0.0))
                )
                +
                (effects.ability.effect_mod_flat[bid] or 0.0)
            )
            *
            (1.0 + (effects.ability.effect_mod[bid] or 0.0));

        info.restored = min;
    end
    if periodic then

        if periodic.per_lvl_sq == 0 then
            local lvl_diff_applicable = math.max(0,
                math.min(clvl - spell.lvl_req, spell.lvl_max - spell.lvl_req));
            min = periodic.min + periodic.per_lvl * lvl_diff_applicable;
        else
            local added_effect = periodic.per_lvl * clvl + periodic.per_lvl_sq * clvl * clvl;
            min = periodic.min * (periodic.base_min + added_effect);
        end
        min =
            (
                (
                    (min + (effects.ability.base_mod_ot_flat[bid] or 0.0))
                    *
                    (1.0 + (effects.ability.base_mod_ot[bid] or 0.0))
                )
                +
                (effects.ability.effect_mod_ot_flat[bid] or 0.0)
            )
            *
            (1.0 + (effects.ability.effect_mod_ot[bid] or 0.0));

        info.dur =
            (periodic.dur + (effects.ability.extra_dur_flat[bid] or 0.0))
            *
            (1.0 + (effects.ability.extra_dur[bid] or 0.0));
        info.tick_time =
            periodic.tick_time + (effects.ability.extra_tick_time_flat[bid] or 0.0);
        info.ticks = info.dur / info.tick_time;

        info.tick_restored = min;
    end

    if bit.band(spell.flags, spell_flags.regen_pct) ~= 0 then
        -- percentage off mana regen

        local casting_regen = effects.raw.regen_while_casting;
        if get_buff(loadout, "player", spell_id, true) then
            casting_regen = casting_regen - 1.0;
        end
        casting_regen = math.max(0, math.min(1.0, casting_regen));

        -- evocate, innervate etc
        local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];
        -- Prevents combat casting regen % gained from this ability affecting this evaluation
        -- This becomes mana restored otherwise not gained from normal % regen while casting
        info.tick_restored =
            (1.0 - casting_regen + info.tick_restored) * spirit_mana_regen(spirit)
            +
            info.tick_restored * 0.4*effects.raw.mp5_flat; -- NOTE: mp5 does benefit from the modifier too

    elseif bit.band(spell.flags, spell_flags.regen_max_pct) ~= 0 then
        info.tick_restored = info.tick_restored * loadout.resources_max[powers.mana];
        info.restored = info.restored * loadout.resources_max[powers.mana];
    end

    info.total_restored = info.restored + info.tick_restored * info.ticks;
end

local function only_threat_info(info, stats, spell, loadout, effects, eval_flags)

    if not effects.finalized and sc.core.__sw__debug__ then
        print("CALLING SPELL INFO FOR SPELL WITHOUT FINALIZED EFFECTS");
    end
    local bid = spell.base_id;
    local anycomp = spell.direct or spell.periodic;

    eval_flags = eval_flags or 0;
    eval_flags = bit.bor(eval_flags, mandatory_flags_by_spell(anycomp));

    local num_unbounded_targets = config.loadout.unbounded_aoe_targets;
    local direct = spell.direct;
    if direct then

        stats.attack_skill, stats.attack_subclass = stats_attack_skill(direct, spell, loadout, effects, eval_flags);
        stats.miss, stats.extra_hit, stats.target_avg_resi =
            stats_hit(0, stats.attack_skill, stats.attack_subclass, bid, direct, spell, loadout, effects);
        stats.threat_mod_flat, stats.threat_mod = stats_threat_mod(bid, direct, spell, effects);
        stats.block = 0;
        stats.crit = 0;
        stats.block_amount = 0;
        stats.armor_dr = 0;
        stats.dodge, stats.parry = stats_avoidances(stats.attack_skill, direct, spell, loadout);
        stats.hit = 1.0 - stats.miss - stats.dodge - stats.parry;
        -- TODO: avoidances

        local extra_jumps;
        if effects.ability.jumps_flat[bid] then
            extra_jumps = effects.ability.jumps_flat[bid];
            if bit.band(direct.flags, comp_flags.native_jumps) == 0 and
                extra_jumps ~= 0 then 

                extra_jumps = extra_jumps - 1;
            end
        else 
            extra_jumps = 0;
        end
        stats.direct_jumps = (direct.jumps or 0) + extra_jumps;

        local flat_threat = stats.threat_mod_flat;
        if spell.direct then
            flat_threat = flat_threat + (spell.direct.threat_mod_flat or 0.0);
        end
        info.threat_direct_st = (1.0 + stats.threat_mod) *
             (stats.hit * (flat_threat));
        info.threat_direct = info.threat_direct_st;

        if bit.band(spell.direct.flags, comp_flags.unbounded_aoe) ~= 0 then
            info.threat_direct = info.threat_direct_st * num_unbounded_targets;
        end
    else
        info.threat_direct_st = 0;
        info.threat_direct = 0;
    end

    -- Assume there are no periodic such spells
    info.threat_ot_st = 0;
    info.threat_ot = 0;

    info.threat_st = info.threat_direct_st + info.threat_ot_st
    info.threat = info.threat_direct + info.threat_ot

    if stats.direct_jumps then
        local threat_added = info.threat_direct_st * stats.direct_jumps;
        info.threat_direct = info.threat_direct + threat_added;
        info.threat = info.threat + threat_added;
    end

    if info.threat < info.threat_st or
        bit.band(eval_flags, evaluation_flags.assume_single_effect) ~= 0 then

        info.threat = info.threat_st;
        info.threat_ot = info.threat_ot_st;
        info.threat_direct = info.threat_direct_st
    end

    stats.cost_actual, stats.original_base_cost = stats_cost(bid, spell, loadout, effects);
    stats.cost = stats_avg_cost(stats.cost_actual, stats, bid, spell, loadout, effects);
    stats.cast_time, stats.cast_time_nogcd, stats.gcd =
        stats_cast_time(stats, bid, anycomp, spell, loadout, effects, eval_flags);

    info.threat_per_cost = info.threat/stats.cost;
    info.threat_per_sec = info.threat/stats.cast_time;
end

local function dummy_cast_until_oom_info(info, stats, spell_id, loadout, effects)
    -- spells we don't extensively compute but should show ingame available cost or cast time
    local cost, resource_name = spell_cost(spell_id);
    cost = cost or 0.0;
    local cast_time = spell_cast_time(spell_id);
    cast_time = cast_time or 0.0;
    stats.cast_time = cast_time;

    -- filling with dummies to fit cast until oom signature
    stats.cost = cost;
    stats.cast_time = cast_time;
    stats.regen_while_casting = effects.raw.regen_while_casting;
    info.cost_per_sec = cost/cast_time;
    info.expected = 0
    if not spells[spell_id] or resource_name ~= "MANA" then
        stats.cast_time = 0.0;
        info.time_until_oom = nil;
        info.num_casts_until_oom = nil;
    else
        cast_until_oom(info, spells[spell_id], stats, loadout, effects, false, 0);
    end
end

local dmg_magic_stat_weights = {
    { display = "SP", key = "sp", normalize_to = true},
    { display = "Int", key = "stats", key2 = attr.intellect},
    { display = "Spirit", key = "stats", key2 = attr.spirit},
    { display = "Crit", key = "crit_rating"},
    { display = "Hit", key = "hit_rating"},
    { display = "Spell Pen", key = "spell_pen"},
    { display = "MP5", key = "mp5"},
};

local heal_stat_weights = {
    { display = "HP", key = "sp", normalize_to = true},
    { display = "Int", key = "stats", key2 = attr.intellect},
    { display = "Spirit", key= "stats", key2 = attr.spirit},
    { display = "MP5", key = "mp5"},
    { display = "Crit", key = "crit_rating"},
};

local melee_stat_weights = {
    { display = "AP", key = "ap", normalize_to = true},
    { display = "Str", key = "stats", key2 = attr.strength},
    { display = "Agi", key= "stats", key2 = attr.agility},
    { display = "Crit", key = "crit_rating"},
    { display = "Hit", key = "hit_rating"},
    { display = "Wep skill", key = "weapon_skill"},
};
local ranged_stat_weights = {
    { display = "RAP", key = "rap", normalize_to = true},
    { display = "Agi", key= "stats", key2 = attr.agility},
    { display = "Crit", key = "crit_rating"},
    { display = "Hit", key = "hit_rating"},
    { display = "Wep skill", key = "weapon_skill"},
};

local info_diff = {};
local spell_stats_diffed = {};
local diff = effects_zero_diff();
local effects_diffed = {};
empty_effects(effects_diffed);

local function stat_weights(normal_info, spell, loadout, effects, eval_flags, spell_id)

    local weights;
    local anycomp = spell.direct or spell.periodic;
    if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0 then
        weights = heal_stat_weights;
    elseif bit.band(spell.flags, spell_flags.requires_ranged_slot) ~= 0 then
    --elseif bit.band(anycomp.flags, comp_flags.applies_ranged) ~= 0 then
        weights = ranged_stat_weights;
    elseif anycomp.school1 ~= schools.physical then
        weights = dmg_magic_stat_weights;
    else
        weights = melee_stat_weights;
    end
    local normalize_table;

    for _, v in ipairs(weights) do
        if v.normalize_to then
            normalize_table = v;
        end
        if v.key2 then
            diff[v.key][v.key2] = 1;
        else
            diff[v.key] = 1;
        end

        cpy_effects(effects_diffed, effects);
        effects_add_diff(effects_diffed, diff);
        effects_finalize_forced(loadout, effects_diffed)

        spell_stats_info(info_diff, spell_stats_diffed, spell, loadout, effects_diffed, eval_flags, spell_id);
        cast_until_oom(info_diff, spell, spell_stats_diffed, loadout, effects_diffed, true, 0);
        if v.key2 then
            diff[v.key][v.key2] = 0;
        else
            diff[v.key] = 0;
        end

        v.effect_per_sec_delta = info_diff.effect_per_sec - normal_info.effect_per_sec;
        v.effect_delta = info_diff.expected - normal_info.expected;
        if not normal_info.effect_until_oom then
            v.effect_until_oom_delta = nil;
        else
            v.effect_until_oom_delta = info_diff.effect_until_oom - normal_info.effect_until_oom;
        end
    end
    local normalize_table_preferred = normalize_table;

    local eps = 0.000000001;
    if normalize_table.effect_per_sec_delta < eps then
        normalize_table = nil;
        local lowest = math.huge;
        -- need to find any other field to normalize to
        for _, v in ipairs(weights) do
            if v.effect_per_sec_delta > eps and v.effect_per_sec_delta < lowest then
                lowest = v.effect_per_sec_delta;
                normalize_table = v;
            end
        end
    end

    if not normalize_table or normalize_table.effect_per_sec_delta < eps then
        -- effect per sec still has no gains, execution time is likely 0
        --   find new normalize field by expectation
        normalize_table = normalize_table_preferred;
        if normalize_table.effect_delta < eps then
            local lowest = math.huge;
            -- need to find any other field to normalize to
            for _, v in ipairs(weights) do
                if v.effect_delta > eps and v.effect_delta < lowest then
                    lowest = v.effect_delta;
                    normalize_table = v;
                end
            end
        end
    end
    if normalize_table then
        -- Normalize to first weight
        for _, v in ipairs(weights) do
            v.effect_per_sec_weight = v.effect_per_sec_delta/normalize_table.effect_per_sec_delta;
            v.effect_weight = v.effect_delta/normalize_table.effect_delta;
        end
        for _, v in ipairs(weights) do
            if v.effect_until_oom_delta then
                v.effect_until_oom_weight = v.effect_until_oom_delta/normalize_table.effect_until_oom_delta;
            end
        end
    end

    return weights, normalize_table;
end

-- evaluate spell with and without stat change coming from a buff spell aliased such as Slice and Dice
local function eval_spell_buff_diffed(alias_info, alias_spell_id, table_to_change, table_key, buff_value, buff_is_mul, info, stats, spell, loadout, effects, eval_flags, spell_id)
    for _, v in pairs(expectation_variations) do
        info[v] = 0;
    end
    info.num_periodic_effects = 0;
    info.num_direct_effects = 0;

    spell_stats_info(alias_info, stats, spells[alias_spell_id], loadout, effects, eval_flags, alias_spell_id);

    local table_val_prev = table_to_change[table_key];

    if get_buff(loadout, "player", spell_id, true) then
        info.effect_per_sec = alias_info.effect_per_sec;
        info.threat_per_sec = alias_info.threat_per_sec;
        if buff_is_mul then
            table_to_change[table_key] = (table_to_change[table_key] or 1.0)/(1.0 + buff_value);
        else
            table_to_change[table_key] = (table_to_change[table_key] or 0.0)-buff_value;
        end
        spell_stats_info(alias_info, stats, spells[alias_spell_id], loadout, effects, eval_flags, alias_spell_id);
        info.effect_per_sec = info.effect_per_sec - alias_info.effect_per_sec;
        info.threat_per_sec = info.threat_per_sec - alias_info.threat_per_sec;
    else
        info.effect_per_sec = -alias_info.effect_per_sec;
        info.threat_per_sec = -alias_info.threat_per_sec;
        if buff_is_mul then
            table_to_change[table_key] = (table_to_change[table_key] or 1.0)*(1.0 + buff_value);
        else                                            
            table_to_change[table_key] = (table_to_change[table_key] or 0.0)+buff_value;
        end
        spell_stats_info(alias_info, stats, spells[alias_spell_id], loadout, effects, eval_flags, alias_spell_id);
        info.effect_per_sec = info.effect_per_sec + alias_info.effect_per_sec;
        info.threat_per_sec = info.threat_per_sec + alias_info.threat_per_sec;
    end
    table_to_change[table_key] = table_val_prev;
    stats_for_spell(stats, spell, loadout, effects, eval_flags);

    info.expected_ot_st = info.effect_per_sec*stats.dur_ot;
    info.expected_ot = info.expected_ot_st;
    info.expected_st = info.expected_ot;
    info.expected = info.expected_st;

    info.threat_ot_st = info.threat_per_sec*stats.dur_ot;
    info.threat_ot = info.threat_ot_st;
    info.threat_st = info.threat_ot;
    info.threat = info.threat_st;

    if stats.cast_time == 0 then
        info.effect_per_sec = math.huge;
        info.threat_per_sec = math.huge
    else
        info.effect_per_sec = info.expected / stats.cast_time;
        info.threat_per_sec = info.threat / stats.cast_time;
    end

    if stats.cost == 0 then
        info.effect_per_cost = math.huge;
        info.threat_per_cost = math.huge;
    else
        info.effect_per_cost = info.expected / stats.cost;
        info.threat_per_cost = info.threat / stats.cost;
    end

    info.cost_per_sec = stats.cost / stats.cast_time;
end

local alias_info = {};

spell_stats_info = function(info, stats, spell, loadout, effects, eval_flags, spell_id)
    if bit.band(spell.flags, spell_flags.alias) == 0 then
        stats_for_spell(stats, spell, loadout, effects, eval_flags);
        spell_info(info, spell, stats, loadout, effects, eval_flags, spell_id);

    else
        -- handle spells that fully or partially alias other spells
        if spell.base_id == spids.swiftmend then
            
        elseif spell.base_id == spids.slice_and_dice then
            eval_spell_buff_diffed(alias_info,
                                   spell.alias,
                                   effects.mul.raw,
                                   "melee_haste_forced",
                                   class_buffs[spell_id][1][sc.aura_idx_value],
                                   true,
                                   info, stats, spell, loadout, effects, eval_flags, spell_id);
        elseif spell.base_id == spids.tigers_fury then
            eval_spell_buff_diffed(alias_info,
                                   spell.alias,
                                   effects.ability.base_mod_flat,
                                   spell.alias,
                                   class_buffs[spell_id][1][sc.aura_idx_value],
                                   false,
                                   info, stats, spell, loadout, effects, eval_flags, spell_id);
        elseif spell.base_id == spids.tigers_fury_2 then
            eval_spell_buff_diffed(alias_info,
                                   spell.alias,
                                   effects.mul.raw,
                                   "phys_mod",
                                   class_buffs[spell_id][1][sc.aura_idx_value],
                                   true,
                                   info, stats, spell, loadout, effects, eval_flags, spell_id);
        end
    end
end

local function calc_spell_eval(spell, loadout, effects, eval_flags, spell_id)
    spell_stats_info(info_buffer, stats_buffer, spell, loadout, effects, eval_flags, spell_id);
    return info_buffer, stats_buffer;
end

local function calc_spell_threat(spell, loadout, effects, eval_flags)
    only_threat_info(info_buffer, stats_buffer, spell, loadout, effects, eval_flags);
    return info_buffer, stats_buffer;
end

local function calc_spell_resource_regen(spell, spell_id, loadout, effects, eval_flags)
   resource_regen_info(info_buffer, spell, spell_id, loadout, effects, eval_flags)
   return info_buffer;
end

local function calc_spell_dummy_cast_until_oom(spell_id, loadout, effects)
    dummy_cast_until_oom_info(info_buffer, stats_buffer, spell_id, loadout, effects);
    return info_buffer, stats_buffer;
end

local function spell_diff(out, fight_type, spell, spell_id, loadout, effects_finalized, effects_d, eval_flags)

    out.name = GetSpellInfo(spell_id);

    if bit.band(spell.flags, bit.bor(spell_flags.finishing_move_dmg, spell_flags.finishing_move_dur)) ~= 0 then
        if spell.rank == 0 then
            out.extra = string.format("|cFFA9A9A9 CP: %d|r", loadout.resources[powers.combopoints]);
        else
            out.extra = string.format("|cFFA9A9A9 R%d | CP: %d|r", spell.rank, loadout.resources[powers.combopoints]);
        end
    else
        if spell.rank == 0 then
            out.extra = "";
        else
            out.extra = string.format("|cFFA9A9A9 Rank %d|r", spell.rank);
        end
    end

    out.disp = out.name..out.extra;
    out.id = spell_id;
    out.tex = GetSpellTexture(spell_id);

    out.heal_like = bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) ~= 0;

    if fight_types.repeated_casts == fight_type then

        local info = calc_spell_eval(spell, loadout, effects_finalized, eval_flags, spell_id);
        local normal_eps = info.effect_per_sec;
        local normal_exp = info.expected;

        effects_finalize_forced(loadout, effects_d);
        info = calc_spell_eval(spell, loadout, effects_d, eval_flags, spell_id);

        out.diff_ratio = 100 * (info.effect_per_sec / normal_eps - 1);
        out.first = info.effect_per_sec - normal_eps;
        out.second = info.expected - normal_exp;
    else
        eval_flags = bit.bor(eval_flags, evaluation_flags.at_max_mana);
        local info, stats = calc_spell_eval(spell, loadout, effects_finalized, eval_flags, spell_id);
        cast_until_oom(info, spell, stats, loadout, effects_finalized, true, eval_flags);

        local normal_exp_until_oom = info.effect_until_oom;
        local normal_time_until_oom = info.time_until_oom;

        effects_finalize_forced(loadout, effects_d);
        info = calc_spell_eval(spell, loadout, effects_d, eval_flags, spell_id);
        cast_until_oom(info, spell, stats, loadout, effects_d, true, eval_flags);

        if not info.effect_until_oom then
            out.diff_ratio = nil;
            out.first = nil;
            out.second = nil;
        else
            out.diff_ratio = 100 * (info.effect_until_oom / normal_exp_until_oom - 1);
            out.first = info.effect_until_oom - normal_exp_until_oom;
            out.second = info.time_until_oom - normal_time_until_oom;
        end
    end
end

--------------------------------------------------------------------------------
calc.fight_types                        = fight_types;
calc.evaluation_flags                   = evaluation_flags;
calc.stats_for_spell                    = stats_for_spell;
calc.spell_info                         = spell_info;
calc.cast_until_oom                     = cast_until_oom;
calc.stat_weights                       = stat_weights;
calc.get_combat_rating_effect           = get_combat_rating_effect;
calc.spell_diff                         = spell_diff;
calc.resource_regen_info                = resource_regen_info;
calc.only_threat_info                   = only_threat_info;
calc.add_extra_effect                   = add_extra_effect;
calc.effect_flags                       = effect_flags;
calc.calc_spell_eval                    = calc_spell_eval;
calc.calc_spell_threat                  = calc_spell_threat;
calc.calc_spell_resource_regen          = calc_spell_resource_regen;
calc.calc_spell_dummy_cast_until_oom    = calc_spell_dummy_cast_until_oom;

sc.calc                      = calc;
