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
local config                                        = sc.config;

local auto_attack_spell_id                          = sc.auto_attack_spell_id;

local spell_lname                                   = sc.utils.spell_lname;
local dummy_value                                   = sc.utils.dummy_value;

local num_set_pieces                                = sc.equipment.num_set_pieces;
local has_enchant                                   = sc.equipment.has_enchant;
local talent_pts                                    = sc.talents.talent_pts;
local talent_idx                                    = sc.talent_idx;

local effect_flags                                  = sc.calc.effect_flags;
local add_extra_effect                              = sc.calc.add_extra_effect;
local add_extra_effect_own                          = sc.calc.add_extra_effect_own;
local get_buff                                      = sc.buffs.get_buff;
local get_buff_by_lname                             = sc.buffs.get_buff_by_lname;

---------------------------------------------------------------------------------------------------
local mechanics = {};
-- Vanilla specific behaviour uncompatible with other version
mechanics.gcd = 1.5;
mechanics.gcd_min = 1.0;
mechanics.haste_reduces_gcd = true;
mechanics.gcd_uses_cast_haste = true;


local class_stats_spell = (function()
    if class == classes.warrior then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.paladin then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then

                local pts = talent_pts(effects, talent_idx.illumination);
                if pts ~= 0 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + pts * 0.2 * 0.5 * stats.original_base_cost;
                end
            end
        end
    elseif class == classes.hunter then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.rogue then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bid == spids.mutilate and effects.raw.class_misc ~= 0 then
                -- class_misc counts poisons on the target
                stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * (1 + 0.01 * dummy_value(bid, 3));
            end
            if effects.raw.wpn_subclass_mh == 15 then
                if bid == spids.ghostly_strike then
                    stats.base_mod = stats.base_mod * dummy_value(bid, 3) / dummy_value(bid, 0);
                elseif bid == spids.hemorrhage then
                    stats.base_mod = stats.base_mod * dummy_value(bid, 4) / dummy_value(bid, 3);
                end
            end
        end
    elseif class == classes.priest then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell_flags.heal, spell.flags) ~= 0 then
                local pts = talent_pts(effects, talent_idx.divine_aegis);
                if pts ~= 0 and spell.direct then
                    local aegis = 0.01*dummy_value(lookups.divine_aegis, 0, pts);
                    local aegis_flags = bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod);
                    add_extra_effect(stats,
                        aegis_flags,
                        1.0,
                        spell_lname(lookups.divine_aegis),
                        aegis
                    );
                    if bid == spids.penance then
                        aegis_flags = bit.bor(aegis_flags, effect_flags.base_on_periodic_effect, effect_flags.is_periodic, effect_flags.shares_periodic_type);
                        add_extra_effect(stats,
                            aegis_flags,
                            1.0,
                            spell_lname(lookups.divine_aegis),
                            aegis
                        );
                    end
                end
            end
        end
    elseif class == classes.shaman then
        return function(anycomp, bid, stats, spell, loadout, effects)

            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                -- clearcast
                local pts = talent_pts(effects, talent_idx.elemental_focus);
                if pts ~= 0 then
                    stats.clearcast_p = stats.clearcast_p + 0.1;
                end
            end

            if bit.band(spell_flags.heal, spell.flags) ~= 0 and
                spell.direct and
                get_buff(loadout, "player", lookups.water_shield, true) then

                stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.01*dummy_value(408511, 0) * loadout.resources_max[powers.mana];
            end
            local overload_pts = talent_pts(effects, talent_idx.lightning_overload);
            if overload_pts ~= 0 and
                   (bid == spids.chain_lightning or bid == spids.lightning_bolt) then

                sc.calc.add_extra_effect(
                    stats,
                    0,
                    0.01*dummy_value(lookups.lightning_overload, 0, overload_pts),
                    spell_lname(lookups.lightning_overload),
                    0.5
                );
            end
            if bid == spids.healing_wave or
                bid == spids.lesser_healing_wave or
                bid == spids.riptide then
                if num_set_pieces(effects, 207) >= 5 or num_set_pieces(effects, 1713) >= 4 then
                    stats.resource_refund = stats.resource_refund + 0.25 * 0.35 * stats.original_base_cost;
                end
            end

        end
    elseif class == classes.mage then
        return function(anycomp, bid, stats, spell, loadout, effects)

            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then

                if num_set_pieces(effects, 1807) >= 6 and bid == spids.fireball then
                    add_extra_effect(stats,
                        effect_flags.is_periodic,
                        1.0,
                        spell_lname(lookups.t2_mage_damage_6p),
                        0.01*dummy_value(lookups.t2_mage_damage_6p, 0),
                        4,
                        2);
                end

                if num_set_pieces(effects, 1808) >= 2 and bid == spids.arcane_missiles then
                    stats.resource_refund = stats.resource_refund + 0.5 * stats.original_base_cost;
                end

                if bid == spids.arcane_wrath then
                    stats.extra_spell_power = stats.extra_spell_power +
                        0.01*dummy_value(spids.arcane_wrath, 1) * (loadout.resources_max[powers.mana] + effects.raw.mana);
                end

                -- shatter against frozen targets, class_misc tracks freeze effects, crit per rank from a curve
                if effects.raw.class_misc > 0 then
                    local pts = talent_pts(effects, talent_idx.shatter);
                    if pts > 0 then
                        stats.extra_crit = 0.01*dummy_value(lookups.shatter, 0, pts);
                    end
                end
            end
        end
    elseif class == classes.warlock then
        -- Demonic Brand: the Imp's brand is Fire, every other demon's Shadow (in game knowledge, 2026-11-23);
        -- Master Demonologist adds its Fire % to the Imp's, its Shadow % to the Succubus / Incubus' (vars 1017 / 1018)
        local imp_family, succubus_family = 23, 17;
        local brand_flags = bit.bor(effect_flags.optimistic, effect_flags.no_threat, effect_flags.scales_with_hit);
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bid ~= spids.searing_pain or loadout.pet_family == 0 then
                return;
            end
            local pts = talent_pts(effects, talent_idx.demonic_brand);
            if pts == 0 then
                return;
            end
            local brand_id, md_iid = lookups.demonic_brand_shadow, 2;
            if loadout.pet_family == imp_family then
                brand_id, md_iid = lookups.demonic_brand_fire, 0;
            end
            local brand = sc.desc_damage[brand_id];
            local school = brand.school;

            local mul = effects.mul.by_school.vuln_mod[school];
            local unholy_pts = talent_pts(effects, talent_idx.unholy_power);
            if unholy_pts ~= 0 then
                mul = mul * (1 + 0.01 * dummy_value(lookups.unholy_power, 0, unholy_pts));
            end
            local md_pts = talent_pts(effects, talent_idx.master_demonologist);
            if md_pts ~= 0 and (loadout.pet_family == imp_family or loadout.pet_family == succubus_family) then
                mul = mul * (1 + 0.01 * dummy_value(lookups.master_demonologist, md_iid, md_pts));
            end

            local sp = loadout.spell_dmg_by_school[school] + effects.by_school.sp_dmg_flat[school];
            local lvl = math.max(brand.lvl_min, math.min(loadout.lvl, brand.lvl_max));
            local scaled = brand.per_lvl * lvl + brand.coef * sp;
            -- no hit roll: the brand's damage always hits and a missed pet attack keeps its charge;
            -- crit is the warlock's baseline school crit, which pets are meant to inherit, for 150% -- unconfirmed
            local _, crit, avg_resi = sc.calc.school_stats(school, loadout, effects);
            local min = (brand.min + scaled) * mul * (1 - avg_resi);
            local max = (brand.max + scaled) * mul * (1 - avg_resi);
            add_extra_effect_own(stats, 1.0, spell_lname(lookups.demonic_brand), min, max, 1.5 * min, 1.5 * max,
                                 1.0 - crit, crit, school, 1.0, 0, 1.0,
                                 dummy_value(lookups.demonic_brand, 1, pts), brand_flags);
        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then

                if bid == spids.lifebloom then
                    stats.resource_refund_mul_hit = stats.resource_refund + 0.5 * stats.cost_actual;
                end

                -- assumes the hot runs its full duration and the heal crits like the spell
                if talent_pts(effects, talent_idx.bloom) ~= 0 and
                    (bid == spids.rejuvenation or bid == spids.rejuvenation_2 or bid == spids.regrowth or bid == spids.regrowth_2) then
                    local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];
                    add_extra_effect(
                        stats,
                        bit.bor(effect_flags.use_flat, effect_flags.flat_crits),
                        1.0,
                        spell_lname(lookups.bloom),
                        0.01*dummy_value(lookups.bloom, 0)*spirit);
                end

                if num_set_pieces(effects, 1835) >= 4 and
                    (bid == spids.healing_touch or bid == spids.nourish or bid == spids.regrowth or bid == spids.regrowth_2) then
                        add_extra_effect(
                            stats,
                            bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                            1.0,
                            spell_lname(lookups.taq_druid_restoration_4p),
                            0.01*dummy_value(lookups.taq_druid_restoration_4p, 0));
                end
            else
                if num_set_pieces(effects, 1838) >= 4 and
                    (bid == spids.shred or bid == spids.ferocious_bite or bid == spids.mangle or bid == spids.mangle_2 or bid == spids.mangle_3) then
                        add_extra_effect(
                            stats,
                            bit.bor(effect_flags.is_periodic, effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                            1.0,
                            spell_lname(lookups.taq_druid_feral_4p),
                            0.01*dummy_value(lookups.taq_druid_feral_4p, 0),
                            4,
                            1
                            );
                end
            end
        end
    end
end)();

local special_abilities;
if class == classes.shaman then
    special_abilities = {
    };
elseif class == classes.priest then
    special_abilities = {
    };
--elseif class == classes.druid then
--    special_abilities = {
--    };
--elseif class == classes.warlock then
--    special_abilities = {
--    };
--elseif class == classes.paladin then
--    special_abilities = {
--    };
elseif class == classes.mage then
    special_abilities = {
        [spids.mana_shield] = function(spell, info, loadout, stats, effects)
            local pts = talent_pts(effects, talent_idx.arcane_shielding);
            local drain_mod = 0;
            if pts ~= 0 then
                drain_mod = 0.01*dummy_value(lookups.arcane_shielding, 0, pts);
            end
            stats.cost = stats.cost + 2 * info.min_noncrit_if_hit1 * (1.0 + drain_mod);
        end,
    };
--elseif class == classes.rogue then
--    special_abilities = {
--    };
--elseif class == classes.warrior then
--    special_abilities = {
--    };
--elseif class == classes.hunter then
--    special_abilities = {
--    };
else
    special_abilities = {};
end

local class_cast_time = (function()
    if class == classes.druid then
        return function(bid, spell, stats, cast_time, gcd, loadout, effects)
            if config.settings.general_average_proc_effects and
                talent_pts(effects, talent_idx.natures_grace) ~= 0 and
                spell.direct and
                bit.band(spell.flags, spell_flags.channel) == 0 then

                local haste = 0.1;
                local dur = 3.0;
                local casts_in_dur = math.max(1, math.ceil(dur / math.max(cast_time, gcd)));
                local p = 1.0 - (1.0 - stats.crit)^casts_in_dur;

                local hasted_gcd = math.max(mechanics.gcd_min, gcd * (1.0 - haste));
                local hasted_cast_time = hasted_gcd;
                if bit.band(spell.flags, spell_flags.instant) == 0 then
                    hasted_cast_time = math.max(hasted_gcd, cast_time / (1.0 + haste));
                end

                cast_time = (1.0 - p) * cast_time + p * hasted_cast_time;
                gcd = (1.0 - p) * gcd + p * hasted_gcd;
            end
            return cast_time, gcd;
        end
    else
        return function(bid, spell, stats, cast_time, gcd, loadout, effects)
            return cast_time, gcd;
        end
    end
end)();

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

-- heal spell power share by levels past the rank's learn level + 5, the last entry holds beyond
local heal_downrank_coef = sc.heal_downrank_coef;
local heal_downrank_last = #heal_downrank_coef;
-- damage spells keep their full spell power on low ranks
local heal_downrank_flags = bit.bor(spell_flags.heal, spell_flags.absorb);

local function caster_coef_multiplier(slvl, mlvl, clvl, flags)
    if bit.band(flags, heal_downrank_flags) == 0 then
        return 1;
    end
    return heal_downrank_coef[math.max(0, math.min(clvl - slvl - 5, heal_downrank_last))];
end

-- loadout_changes bits the mechanics in this file read for a spell
local function changing_reads(spell, effects)
    return 0;
end

-- Spell resistance after wowsims forever (sim/core/spell_resistances.go, fit to combat logs, unconfirmed): no level
-- based resistance, debuffs stop at 0, Spell Piercing (creatures only) takes the resistance below 0 for a bonus,
-- dot_resi_pen parts take a tenth of a positive share and no bonus, binary spells miss instead. wowsims finds no bonus
-- under 1%, likely a mistake that may get patched, assumed absent here since it would make stat weights misleading
local school_keys = sc.calc.indexed_keys.school;
local target_pvp_flag = sc.loadouts.loadout_flags.target_pvp;
local no_spell_piercing = sc.no_spell_piercing;

local function school_res(school, res_scale, pierces, loadout, by_school)
    local resi = math.max(0, res_scale * (loadout.target_res + by_school.target_res_flat[school]));
    if pierces then
        resi = resi + by_school.pierce_flat[school];
    end
    return resi;
end

-- chance of t tenths resisted around a share of size x (a bonus rolls the same steps), 8 to 10 tenths take 75%
local function tenth_chance(t, x)
    if x <= 0.1 then
        if t == 1 then
            return 5 * x;
        elseif t == 2 then
            return 2.5 * x;
        end
        return 0;
    elseif x >= 0.9 then
        if t == 10 then
            return 1 - 7.5 * (1 - x);
        elseif t == 9 then
            return 5 * (1 - x);
        elseif t == 8 then
            return 2.5 * (1 - x);
        end
        return 0;
    end
    return math.max(0, 0.5 - 2.5 * math.abs(0.1 * t - x));
end

-- the steps other than none: chances and damage multipliers, returns their count
local function resist_steps(a, chances, muls)
    local x = math.abs(a);
    local sign = -1;
    if a < 0 then
        sign = 1;
    end
    local n = 0;
    local capped = 0;
    for t = 1, 10 do
        local p = tenth_chance(t, x);
        if t >= 8 then
            capped = capped + p;
        elseif p > 0 then
            n = n + 1;
            chances[n] = p;
            muls[n] = 1 + sign * 0.1 * t;
        end
    end
    if capped > 0 then
        n = n + 1;
        chances[n] = capped;
        muls[n] = 1 + sign * 0.75;
    end
    return n;
end

-- the roll's mean, below the share once steps above 75% can come up (share over 0.6)
local function roll_mean(a)
    local x = math.abs(a);
    if x <= 0.6 then
        return a;
    end
    local mean = 0;
    for t = 1, 10 do
        mean = mean + tenth_chance(t, x) * math.min(0.1 * t, 0.75);
    end
    if a < 0 then
        return -mean;
    end
    return mean;
end

-- resistance against the component and the average share resisted (negative: a bonus), terms gets its parts
local function spell_res(comp, spell, loadout, effects, terms)
    if comp.school1 == schools.holy then
        return 0, 0;
    end
    local pierces = not no_spell_piercing[spell.base_id] and bit.band(loadout.flags, target_pvp_flag) == 0;
    local by_school = effects.by_school;
    local res_scale = 1.0 + by_school.target_res[comp.school1];
    local resi = school_res(comp.school1, res_scale, pierces, loadout, by_school);
    local school = comp.school1;
    local i = 2;
    while comp[school_keys[i]] do
        local r = school_res(comp[school_keys[i]], res_scale, pierces, loadout, by_school);
        if r > resi then
            resi = r;
            school = comp[school_keys[i]];
        end
        i = i + 1;
    end
    local share = resi / (math.abs(resi) + 8 * loadout.lvl + 19);
    local tenth = bit.band(comp.flags, comp_flags.dot_resi_pen) ~= 0;
    local no_bonus = false;
    if bit.band(spell.flags, spell_flags.binary) ~= 0 then
        if share < 0 and tenth then
            no_bonus = true;
            share = 0;
        end
        tenth = false;
    elseif tenth then
        no_bonus = share < 0;
        share = math.max(0, share) * 0.1;
    end
    if terms then
        terms.res = loadout.target_res;
        terms.debuff = by_school.target_res_flat[school];
        terms.pierce = 0;
        if pierces then
            terms.pierce = by_school.pierce_flat[school];
        end
        terms.scale = res_scale;
        terms.pierce_after_floor = true;
        terms.lvl_res = 0;
        terms.roll = share;
        terms.tenth = tenth;
        terms.no_bonus = no_bonus;
    end
    return resi, roll_mean(share);
end


-- rage per swing is weapon speed x 3.46 (4.5 two handed, off hand 1.73), none on misses, dodges and parries,
-- unconfirmed (warrior compendium, pre october beta logs), feral forms assumed one handed; crits +100% (blizzard
-- dev notes, warrior 2026-10-01, bear 2026-10-08), dual wield specialization no longer adds off hand rage (2026-10-01)
local function white_swing_rage(stats, dmg, wpn_speed, oh, loadout, effects)
    local rate = 3.46;
    if oh then
        rate = 1.73;
    elseif loadout.shapeshift_feral_skill == 0 and sc.two_handed_wep_subclasses[effects.raw.wpn_subclass_mh] then
        rate = 4.5;
    end
    return rate * wpn_speed * (stats.hit + stats.crit);
end

--------------------------------------------------------------------------------
mechanics.client_class_stats_spell          = class_stats_spell;
mechanics.client_special_abilities          = special_abilities;
mechanics.client_class_cast_time           = class_cast_time;
mechanics.stats_glance                      = stats_glance;
mechanics.caster_coef_multiplier            = caster_coef_multiplier;
mechanics.client_changing_reads             = changing_reads;
mechanics.client_white_swing_rage           = white_swing_rage;
mechanics.client_spell_res                  = spell_res;
mechanics.client_resist_steps               = resist_steps;

sc.mechanics = mechanics;

