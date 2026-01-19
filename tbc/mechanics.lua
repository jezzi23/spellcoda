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
                local pts = talent_pts(effects, 109);
                if pts ~= 0 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.6 * pts * 0.2 * stats.original_base_cost;
                end
                if bid == spids.holy_light and config.settings.general_average_proc_effects then
                    local pts = talent_pts(effects, 116);
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

            local pts = talent_pts(effects, 119);
            if pts ~= 0 and (bid == spids.chain_lightning or bid == spids.lightning_bolt) then
                local spid = sc.talent_ranks[119][pts];
                if spid then
                    local proc = 0.01*dummy_value(spid, 1);
                    sc.calc.add_extra_effect(
                        stats,
                        0,
                        proc,
                        spell_lname(spid),
                        0.5
                    );
                end

            end
        end
    elseif class == classes.mage then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.warlock then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    end
end)();

local special_abilities;
if class == classes.shaman then
    special_abilities = {
    };
--elseif class == classes.priest then
--    special_abilities = {
--    };
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
            local pts = talent_pts(effects, 110);
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
mechanics.stats_glance                      = stats_glance;
mechanics.caster_coef_multiplier            = caster_coef_multiplier;

sc.mechanics = mechanics;

