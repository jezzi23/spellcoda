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

local spell_lname                                   = sc.utils.spell_lname;
local dummy_value                                   = sc.utils.dummy_value;

local num_set_pieces                                = sc.equipment.num_set_pieces;

local effect_flags                                  = sc.calc.effect_flags;
local add_extra_effect                              = sc.calc.add_extra_effect;
local get_buff                                      = sc.buffs.get_buff;
local get_buff_by_lname                             = sc.buffs.get_buff_by_lname;

---------------------------------------------------------------------------------------------------
local mechanics = {};
-- Vanilla specific behaviour uncompatible with other version

local class_stats_spell = (function()
    if class == classes.warrior then
        return function(anycomp, bid, stats, spell, loadout, effects)
        end
    elseif class == classes.paladin then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then
                if loadout.enchants[lookups.rune_fanaticism] and spell.direct then
                    add_extra_effect(
                        stats,
                        bit.bor(effect_flags.is_periodic, effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                        1.0,
                        spell_lname(lookups.fanaticism),
                        0.01*dummy_value(lookups.fanaticism, 1),
                        4,
                        3
                        );
                end
                if bid == spids.flash_of_light and get_buff(loadout, loadout.friendly_towards, lookups.sacred_shield, false) then
                    add_extra_effect(stats,
                        effect_flags.is_periodic,
                        1.0,
                        spell_lname(lookups.sacred_shield),
                        0.01*dummy_value(lookups.sacred_shield, 2),
                        12,
                        1);
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
                if loadout.enchants[lookups.rune_divine_aegis] then
                    if spell.direct then
                        local aegis_flags = bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod);
                        add_extra_effect(stats,
                            aegis_flags,
                            1.0,
                            spell_lname(lookups.divine_aegis),
                            0.01*dummy_value(lookups.divine_aegis, 0)
                        );
                        if bid == spids.penance then
                            aegis_flags = bit.bor(aegis_flags, effect_flags.base_on_periodic_effect, effect_flags.is_periodic, effect_flags.shares_periodic_type);
                            add_extra_effect(stats,
                                aegis_flags,
                                1.0,
                                spell_lname(lookups.divine_aegis),
                                0.01*dummy_value(lookups.divine_aegis, 0)
                            );
                        end
                    end
                end
            end
        end
    elseif class == classes.shaman then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if num_set_pieces(loadout, 1816) >= 2 and spell.direct and get_buff(loadout, "player", lookups.water_shield, true) then

                stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.04 * loadout.resources_max[powers.mana];
            end
            if loadout.enchants[lookups.rune_overload] and
                   (bid == spids.chain_heal or
                    bid == spids.chain_lightning or
                    bid == spids.healing_wave or
                    bid == spids.lightning_bolt or
                    bid == spids.lava_burst) then

                local proc = 0.01*dummy_value(lookups.overload, 1);
                sc.calc.add_extra_effect(
                    stats,
                    0,
                    proc,
                    spell_lname(lookups.overload),
                    0.01*dummy_value(lookups.overload, 0)/proc
                );
            end

        end
    elseif class == classes.mage then
        return function(anycomp, bid, stats, spell, loadout, effects)

            if bit.band(spell.flags, bit.bor(spell_flags.heal, spell_flags.absorb)) == 0 then
                if loadout.enchants[lookups.rune_burnout] and spell.direct then
                    stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.01 * base_mana;
                end

                if num_set_pieces(loadout, 1807) >= 6 and bid == spids.fireball then
                    add_extra_effect(stats,
                        effect_flags.is_periodic,
                        1.0,
                        spell_lname(467399),
                        0.01*dummy_value(467399, 0),
                        4,
                        2);
                end

                if num_set_pieces(loadout, 1808) >= 2 and bid == spids.arcane_missiles then
                    stats.resource_refund = stats.resource_refund + 0.5 * stats.original_base_cost;
                end
                if bid == spids.arcane_surge then
                    stats.spell_dmg_mod_mul = stats.spell_dmg_mod_mul *
                        (1.0 + 100*spell.direct.per_resource * loadout.resources[powers.mana] / loadout.resources_max[powers.mana]);
                end
            end
        end
    elseif class == classes.warlock then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if loadout.enchants[lookups.rune_dance_of_the_wicked] and spell.direct then
                stats.resource_refund_mul_crit = stats.resource_refund_mul_crit + 0.02 * loadout.resources_max[powers.mana];
            end
            if loadout.enchants[lookups.rune_soul_siphon] then
                if bid == spids.drain_soul and loadout.enemy_hp_perc and loadout.enemy_hp_perc <= 0.2 then
                    stats.target_vuln_mod_mul =
                        stats.target_vuln_mod_mul * math.min(2.5, 1.0 + 0.5 * effects.raw.class_misc);
                elseif bid == spids.drain_soul or bid == spids.drain_life or bid == spids.drain_life_2 then
                    stats.target_vuln_mod_mul =
                        stats.target_vuln_mod_mul * math.min(1.18, 1.0 + 0.06 * effects.raw.class_misc);
                end
            end
            if bid == spids.shadow_bolt and num_set_pieces(loadout, 1820) >= 6 then
                stats.target_vuln_mod_mul =
                    stats.target_vuln_mod_mul * math.min(1.3, 1.1 + 0.05 * effects.raw.class_misc);
            end
        end
    elseif class == classes.druid then
        return function(anycomp, bid, stats, spell, loadout, effects)
            if bit.band(spell.flags, spell_flags.heal) ~= 0 then
                if loadout.enchants[lookups.rune_living_seed] then
                    if spell.direct or bid == spids.swiftmend then
                        add_extra_effect(stats,
                                         bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                                         1.0, spell_lname(lookups.living_seed), 0.01 * dummy_value(lookups.living_seed, 0));
                    end
                end
                if bid == spids.nourish and
                    (get_buff_by_lname(loadout, loadout.friendly_towards, lookups.rejuvenation_lname, false, true) or
                    get_buff_by_lname(loadout, loadout.friendly_towards, lookups.regrowth_lname, false, true) or
                    get_buff_by_lname(loadout, loadout.friendly_towards, lookups.lifebloom_lname, false, true) or
                    get_buff_by_lname(loadout, loadout.friendly_towards, lookups.wild_growth_lname, false, true)) then

                    stats.target_vuln_mod_mul = stats.target_vuln_mod_mul * 1.2;
                end
                if num_set_pieces(loadout, 1835) >= 4 and
                    (bid == spids.healing_touch or bid == spids.nourish and bid == spids.regrowth or bid == spids.regrowth_2) then
                        add_extra_effect(
                            stats,
                            bit.bor(effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                            1.0,
                            spell_lname(1213160),
                            0.01*dummy_value(1213160, 0));
                end
            else
                if num_set_pieces(loadout, 1838) >= 4 and
                    (bid == spids.shred or bid == spids.ferocious_bite or bid == spids.mangle or bid == spids.mangle_2 or bid == spids.mangle_3) then
                        add_extra_effect(
                            stats,
                            bit.bor(effect_flags.is_periodic, effect_flags.triggers_on_crit, effect_flags.should_track_crit_mod),
                            1.0,
                            spell_lname(1213174),
                            0.01*dummy_value(1213174, 0),
                            4,
                            1
                            );
                end
            end
        end
    end
end)();

mechanics.client_class_stats_spell = class_stats_spell;

sc.mechanics = mechanics;

