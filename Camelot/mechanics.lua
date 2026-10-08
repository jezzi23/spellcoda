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
local get_buff                                      = sc.buffs.get_buff;
local get_buff_by_lname                             = sc.buffs.get_buff_by_lname;

---------------------------------------------------------------------------------------------------
local mechanics = {};
-- Vanilla specific behaviour uncompatible with other version
mechanics.gcd = 1.5;
mechanics.gcd_min = 1.0;


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
        return function(stats, spell, loadout, effects)
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
            end
        end
    elseif class == classes.warlock then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then

                if bid == spids.lifebloom then
                    stats.resource_refund_mul_hit = stats.resource_refund + 0.5 * stats.cost_actual;
                end

                if num_set_pieces(effects, 1835) >= 4 and
                    (bid == spids.healing_touch or bid == spids.nourish and bid == spids.regrowth or bid == spids.regrowth_2) then
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
            if pts ~= 0 then
                local drain_mod = 0.01*dummy_value(lookups.arcane_shielding, 0, pts);
                stats.cost = stats.cost + 2 * info.min_noncrit_if_hit1 * (1.0 + drain_mod);
            end
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
                local p = 1.0 - math.pow(1.0 - stats.crit, casts_in_dur);

                local hasted_gcd = gcd * (1.0 - haste);
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

local function caster_coef_multiplier(slvl, mlvl, clvl)

    --return 1;

    -- this formula is speculated, and likely subject to change
    local mod = 1 - (((clvl - 17) - slvl) * 0.05);

    return math.max(0, math.min(1, mod));
end

--------------------------------------------------------------------------------
mechanics.client_class_stats_spell          = class_stats_spell;
mechanics.client_special_abilities          = special_abilities;
mechanics.client_class_cast_time           = class_cast_time;
mechanics.stats_glance                      = stats_glance;
mechanics.caster_coef_multiplier            = caster_coef_multiplier;

sc.mechanics = mechanics;

