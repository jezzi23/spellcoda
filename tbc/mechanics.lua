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

local l_talents                                     = sc.loadouts.active_loadout().talents;

local auto_attack_spell_id                          = sc.auto_attack_spell_id;

local spell_lname                                   = sc.utils.spell_lname;
local dummy_value                                   = sc.utils.dummy_value;

local num_set_pieces                                = sc.equipment.num_set_pieces;

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
                local pts = l_talents.pts[109];
                if pts ~= 0 then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.6 * pts * 0.2 * stats.original_base_cost;
                end
            end
        end
    elseif class == classes.hunter then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.rogue then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.priest then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.shaman then
        return function(anycomp, bid, stats, spell, loadout, effects)
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
--elseif class == classes.mage then
--    special_abilities = {
--    };
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

