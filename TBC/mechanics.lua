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

local talent_pts                                    = sc.talents.talent_pts;
local talent_idx                                    = sc.talent_idx;

local effect_flags                                  = sc.calc.effect_flags;
local add_extra_effect                              = sc.calc.add_extra_effect;
local get_buff                                      = sc.buffs.get_buff;
local get_buff_by_lname                             = sc.buffs.get_buff_by_lname;

---------------------------------------------------------------------------------------------------
local mechanics = {};
-- TBC specific behaviour uncompatible with other version

mechanics.gcd = 1.5;
mechanics.gcd_min = 1.0;

local class_stats_spell = (function()
    if class == classes.warrior then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.paladin then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then
                -- illumination
                local pts = talent_pts(effects, talent_idx.illumination);
                if pts ~= 0 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.6 * pts * 0.2 * stats.original_base_cost;
                end
                if bid == spids.holy_light and config.settings.general_average_proc_effects then
                    local pts = talent_pts(effects, talent_idx.lights_grace);
                    stats.extra_cast_time_flat = stats.extra_cast_time_flat - pts * 0.5/3;

                end
            end
        end
    elseif class == classes.hunter then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.rogue then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bid == spids.mutilate and effects.raw.class_misc ~= 0 then
                -- class_misc has non zero if poison is active
                stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * 1.5;
            end
        end
    elseif class == classes.priest then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.shaman then
        return function(anycomp, bid, stats, spell, loadout, effects)

            local pts = talent_pts(effects, talent_idx.lightning_overload);
            if pts ~= 0 and (bid == spids.chain_lightning or bid == spids.lightning_bolt) then
                local spid = sc.talent_ranks[talent_idx.lightning_overload][pts];
                if spid then
                    -- proc chance is the rank spell's dummy effect 0 (4 per talent point: 4, 8, 12, 16, 20)
                    local proc = 0.01*dummy_value(spid, 0);
                    sc.calc.add_extra_effect(
                        stats,
                        0,
                        proc,
                        spell_lname(spid),
                        0.5
                    );
                end
            end

            -- clearcast
            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 and
                talent_pts(effects, talent_idx.elemental_focus) ~= 0 then

                stats.clearcast_p = 0.4;
                stats.clearcast_on_crit_lookback_len = 2;
            end
        end
    elseif class == classes.mage then
        return function(anycomp, bid, stats, spell, loadout, effects)
            local pts = talent_pts(effects, talent_idx.molten_fury);
            if pts ~= 0 and loadout.enemy_hp_perc <= 0.2 then
                local vuln = effects.mul.ability.thp_based_vuln_mod[bid];
                if vuln then
                    stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * vuln;
                end
            end
        end
    elseif class == classes.warlock then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)

            if bit.band(spell.flags, spell_flags.heal) ~= 0 then

                if get_buff(loadout, "player", spids.tree_of_life, true) and
                    get_buff(loadout, loadout.friendly_towards, lookups.tree_of_life_friendly_aura, false, false) then

                    local spirit = loadout.stats[attr.spirit] + effects.by_attr.stat_flat[attr.spirit];
                    stats.extra_spell_power = stats.extra_spell_power + 0.25*spirit;
                end
            end

            -- clearcast
            local pts = talent_pts(effects, talent_idx.omen_of_clarity);
            if pts and pts ~= 0 then
                if anycomp.school1 == schools.physical then
                    stats.clearcast_p = stats.clearcast_p + 0.1*pts;

                elseif bit.band(sc.game_mode, sc.game_modes.season_of_discovery) ~= 0 and
                       bit.band(spell_flags.instant, spell.flags) == 0 then

                    stats.clearcast_p = stats.clearcast_p + 0.1*pts;
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
        [spids.mana_burn] = function(_, _, _, _, effects)
        end,
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
            local pts = talent_pts(effects, talent_idx.improved_mana_shield);
            local drain_mod = 0.1 * pts;
            stats.cost = stats.cost + 2 * info.min_noncrit_if_hit1 * (1.0 - drain_mod);
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
                bit.band(spell.flags, bit.bor(spell_flags.instant, spell_flags.channel)) == 0 then

                if bid == spids.wrath then
                    gcd = gcd - 0.5;
                end

                cast_time = (1.0 - stats.crit) * cast_time + stats.crit * (math.max(gcd, cast_time-0.5));
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
    local glance_p = 0.06 + (loadout.target_lvl*5-stats.attack_skill)*0.012;
    local glance_min, glance_max;
    if loadout.target_lvl*5-stats.attack_skill >= 11 then
        glance_min =
            math.max(0.01, math.min(0.91, 1.4 - 0.05*(loadout.target_defense-loadout.lvl*5)))
        glance_max =
            math.max(0.2, math.min(0.99, 1.3 - 0.03*(loadout.target_defense-loadout.lvl*5)))
    else
        glance_min =
            math.max(0.01, math.min(0.91, 1.3 - 0.05*(loadout.target_defense-loadout.lvl*5)))
        glance_max =
            math.max(0.2, math.min(0.99, 1.2 - 0.03*(loadout.target_defense-loadout.lvl*5)))
    end

    return math.max(0.0, math.min(1.0, glance_p)), glance_min, glance_max;
end

local function caster_coef_multiplier(slvl, mlvl, clvl)
    local mod = math.min(1, (slvl + 11)/clvl);
    return mod;
end

--------------------------------------------------------------------------------
mechanics.client_class_stats_spell          = class_stats_spell;
mechanics.client_special_abilities          = special_abilities;
mechanics.client_class_cast_time           = class_cast_time;
mechanics.stats_glance                      = stats_glance;
mechanics.caster_coef_multiplier            = caster_coef_multiplier;

sc.mechanics = mechanics;

