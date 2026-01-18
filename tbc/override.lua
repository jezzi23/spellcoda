-- Manual overrides, additions or removals to generated data goes in here
-- Things that:
--     * are not available in parsed client data
--     * fixes problematic generated data
--     * removes unwanted behaviour 
--     * introduces new dummy behaviour
local _, sc = ...;

local attr                          = sc.attr;
local spells                        = sc.spells;
local spids                         = sc.spids;
local spell_flags                   = sc.spell_flags;
local comp_flags                    = sc.comp_flags;
local rank_seqs                     = sc.rank_seqs;
local talent_ranks                  = sc.talent_ranks;
local lookups                       = sc.lookups;

local spell_coef_lvl_adjusted       = sc.utils.spell_coef_lvl_adjusted;
local add_threat_flat_by_rank       = sc.utils.add_threat_flat_by_rank;
local add_threat_mod_all_ranks      = sc.utils.add_threat_mod_all_ranks;
---------------------------------------------------------------------------------------------------
-- NOTE: This was copied from vanilla/override.lua and stripped down and will
--       probably need more tbc overrides
--       Threat data for special abilities needs some fixing

sc.dual_wield_class =
    sc.class == sc.classes.warrior or
    sc.class == sc.classes.rogue or
    sc.class == sc.classes.shaman;

sc.npc_armor_by_lvl = {
    -- "Intended as typical 100% of Heavy armor values"
    20,     21,     46,     82,     126,    180,    245,    322,    412,    518,    -- npc level 1-10
    545,    580,    615,    650,    685,    721,    756,    791,    826,    861,    -- npc level 11-20
    897,    932,    967,    1002,   1037,   1072,   1108,   1142,   1172,   1212,   -- npc level 21-30
    1247,   1283,   1317,   1353,   1387,   1494,   1607,   1724,   1849,   1980,   -- npc level 31-40
    2117,   2262,   2414,   2574,   2742,   2798,   2853,   2907,   2963,   3018,   -- npc level 41-50
    3072,   3128,   3183,   3237,   3292,   3348,   3402,   3457,   3512,   3566,   -- npc level 51-60
    3622,   3677,   3731,   4870,   5050,   5230,   5410,   5590,   5770,   5950,   -- npc level 61-70
    6533,   7116,   7700, --8000,   8300,   8600,   8900,   9200,   9500,   9729,   -- npc level 71-80
--  10033, 10338, 10643,                                                            -- npc level 81-90
};

-- Class data modification
if sc.class == sc.classes.mage then

    lookups.averaged_procs = {
        12536, -- clearcast
        22008, -- tier 2 instant cast proc
    };

    do
        -- Shatter and ice lance effect
        -- Having generator generate all frozen effects would be a lot of bloat
        -- instead just track it through common mage spells through class_misc value
        local freeze_detection_aura = {"raw", "class_misc", 1, nil, 0, -1};
        local affecters = {"frost_nova"};
        for _, v in ipairs(affecters) do
            for _, id in ipairs(rank_seqs[spids[v]]) do
                if not sc.hostile_buffs[id] then
                    sc.hostile_buffs[id] = {};
                end
                table.insert(sc.hostile_buffs[id], freeze_detection_aura);
            end
        end
    end

    -- THREAT
    add_threat_flat_by_rank({
        { spids.counterspell, {300} },
        { spids.remove_lesser_curse, {14} },
    });
elseif sc.class == sc.classes.druid then
    -- DISABLE JUNK
    spells[spids.swiftmend].flags = bit.band(spells[spids.swiftmend].flags, bit.bnot(spell_flags.eval));
    for _, v in pairs(rank_seqs[spids.frenzied_regeneration]) do
        spells[v].flags = bit.band(spells[v].flags, bit.bnot(spell_flags.eval));
    end

    lookups.averaged_procs = {
        16870, -- clearcast
        16886, -- nature's grace
    };

    -- COEF ADJUSTMENTS
    for _, v in pairs(rank_seqs[spids.lifebloom]) do
        -- life bloom direct is a dummy effect in tbc client, thus no coefficient was scraped
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.343434, spells[v].lvl_req);
    end
    -- feral has a few spells with AP coef not found in game client
    for _, v in pairs(rank_seqs[spids.ferocious_bite]) do
        spells[v].direct.per_cp_coef_ap = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.lacerate]) do
        spells[v].periodic.coef_ap_min = 0.01;
        spells[v].direct.coef_ap_min = 0.01;
        spells[v].direct.flags = bit.bor(spells[v].direct.flags, comp_flags.bleed);
    end
    for _, v in pairs(rank_seqs[spids.pounce]) do
        spells[v].periodic.coef_ap_min = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.rake]) do
        spells[v].direct.coef_ap_min = 0.01;
        spells[v].direct.coef_ap_max = 0.01;
        spells[v].periodic.coef_ap_min = 0.02;
        spells[v].periodic.coef_ap_max = 0.02;
        spells[v].direct.flags = bit.bor(spells[v].direct.flags, comp_flags.bleed);
    end
    for _, v in pairs(rank_seqs[spids.rip]) do
        spells[v].periodic.per_cp_dur = 0.0;
        spells[v].periodic.coef_ap_min = 0.04;
    end

    -- THREAT
    add_threat_flat_by_rank({
        { spids.demoralizing_roar, {9, 15, 20, 30, 39, 49} },
        { spids.faerie_fire_feral, {108, 108, 108, 108, 108} },
        { spids.faerie_fire, {108, 108, 108, 108, 108} },
    });
    add_threat_mod_all_ranks({
        {spids.maul, 0.75},
        {spids.swipe, 0.75},
    });
    -- "Dire Bear Form" has a problem with applying "Bear Form" threat passive so add it
    local bear_threat_passive = 21178;
    for _, v in pairs(sc.class_buffs[spids.dire_bear_form]) do
        if v[sc.aura_idx_category] == "applies_aura" and v[sc.aura_idx_effect] == "shapeshift_passives" then
            table.insert(v[sc.aura_idx_subject], bear_threat_passive);
            break;
        end
    end

elseif sc.class == sc.classes.priest then


    -- THREAT
    add_threat_mod_all_ranks({
        {spids.mind_blast, 1.0}
    });
    for _, v in pairs(rank_seqs[spids.holy_nova]) do
        spells[v].flags = bit.bor(spells[v].flags, spell_flags.no_threat);
        spells[v].healing_version.flags = bit.bor(spells[v].healing_version.flags, spell_flags.no_threat);
    end

    for _, v in pairs(rank_seqs[spids.power_word_shield]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.1, spells[v].lvl_req);
    end

    for _, v in pairs(rank_seqs[spids.lightwell]) do
        spells[v].periodic.coef = spell_coef_lvl_adjusted(1/3, spells[v].lvl_req);
    end

    -- Spiritual Healing not affecting selected spells
    for _, talent_id in pairs(talent_ranks[216]) do
        for _, auras in pairs(sc.talent_effects[talent_id]) do
            if auras[sc.aura_idx_category] == "ability" then
                table.insert(auras[sc.aura_idx_subject], spids.circle_of_healing);
                table.insert(auras[sc.aura_idx_subject], spids.holy_nova);
            end
        end
    end


elseif sc.class == sc.classes.shaman then

    lookups.averaged_procs = {
    };



    -- THREAT
    add_threat_mod_all_ranks({
        {spids.earth_shock, 1.0}
    });

elseif sc.class == sc.classes.warlock then

    -- Lifetap ranks 1 and 2 unusual in client data
    spells[rank_seqs[spids.life_tap][1]].direct.min = 30;
    spells[rank_seqs[spids.life_tap][2]].direct.min = 75;

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.searing_pain, 1.0}
    });

    -- ?
    --for rank, talent_id in pairs(talent_ranks[105]) do
    --    -- Life tap talent effect is a dummy, needs manual adding
    --    sc.talent_effects[talent_id] = {
    --        {"ability", "base_mod", rank*0.1, {spids.life_tap}, 0, 0},
    --    };
    --end
elseif sc.class == sc.classes.rogue then
    for _, v in pairs(rank_seqs[spids.eviscerate]) do
        spells[v].direct.coef_ap_min = nil;
        spells[v].direct.coef_ap_max = nil;
        spells[v].direct.per_cp_coef_ap = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.rupture]) do
        spells[v].periodic.coef_ap_by_cp = {0.01, 0.02, 0.03, 0.03, 0.03};
    end
    for _, v in pairs(rank_seqs[spids.garrote]) do
        spells[v].periodic.coef_ap_min = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.slice_and_dice]) do
        spells[v].periodic.per_cp_dur = 3;
    end

    for _, v in pairs(rank_seqs[spids.envenom]) do
      spells[v].direct.coef_ap_min = nil;
      spells[v].direct.coef_ap_max = nil;
      spells[v].direct.per_cp_coef_ap = 0.03;
      spells[v].direct.flags =
            bit.bor(spells[v].direct.flags, comp_flags.magic_scaling_as_ap);
    end

elseif sc.class == sc.classes.paladin then
    sc.friendly_buffs[407613] = {}; -- beacon of light, dummy value - handled manually

    -- Blessing of light needs special handling. Added here and 
    -- adjusted later for downranked holy lights
    sc.friendly_buffs[rank_seqs[spids.blessing_of_light][1]] = {
		{"ability", "effect_mod_flat", 210, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 60, {spids.flash_of_light}, 0, 1},
    };
    sc.friendly_buffs[rank_seqs[spids.blessing_of_light][2]] = {
		{"ability", "effect_mod_flat", 300, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 85, {spids.flash_of_light}, 0, 1},
    };
    sc.friendly_buffs[rank_seqs[spids.blessing_of_light][3]] = {
		{"ability", "effect_mod_flat", 400, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 115, {spids.flash_of_light}, 0, 1},
    };
    sc.friendly_buffs[rank_seqs[spids.blessing_of_light][4]] = {
		{"ability", "effect_mod_flat", 580, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 185, {spids.flash_of_light}, 0, 1},
    };

    sc.friendly_buffs[rank_seqs[spids.greater_blessing_of_light][1]] = {
		{"ability", "effect_mod_flat", 400, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 115, {spids.flash_of_light}, 0, 1},
    };
    sc.friendly_buffs[rank_seqs[spids.greater_blessing_of_light][2]] = {
		{"ability", "effect_mod_flat", 580, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 185, {spids.flash_of_light}, 0, 1},
    };

    lookups.averaged_procs = {
        31834, -- light's grace talent
    };

    -- THREAT
    add_threat_flat_by_rank({
        { spids.holy_shield, {20, 30, 40, 50} },
        { spids.cleanse, {40} },
    });

elseif sc.class == sc.classes.warrior then

    sc.shapeshift_id_to_effects = {
        [1] = {21156}, -- battle
        [2] = {7376}, -- defensive
        [3] = {7381}, -- berserker
    }

    -- ?
    --for _, v in pairs(rank_seqs[spids.shield_slam]) do
    --    spells[v].direct.per_resource = 0.05; -- hacked in as per strength
    --end
    for _, v in pairs(rank_seqs[spids.rend]) do
        spells[v].periodic.flags =
            bit.bor(spells[v].periodic.flags, comp_flags.coef_applied_to_avg_weapon_dmg);
        spells[v].periodic.coef_ap_min = nil;
        spells[v].periodic.coef_ap_max = nil;
        -- special coef applied to weapn damage
        spells[v].periodic.min = 0.00743;
        spells[v].periodic.max = 0.00743;
    end

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.execute, 0.25},
        {spids.thunder_clap, 0.75},
        {spids.whirlwind, 0.25},
        {spids.overpower, -0.25},
    });

    add_threat_flat_by_rank({
        { spids.devastate, {361, 361, 401.5} },
        { spids.revenge, {155, 195, 235, 275, 315, 355, 355, 355} },
        { spids.shield_slam, {160, 190, 220, 250, 278, 305} },
        { spids.sunder_armor, {100, 140, 180, 220, 260, 301.5} },
        { spids.shield_bash, {180, 180, 180, 192} },
        { spids.battle_shout, {5, 11, 17, 26, 39, 55, 60, 69} },
        { spids.cleave, {10, 40, 60, 70, 100, 125} },
        { spids.demoralizing_shout, {11, 17, 21, 32, 43, 50, 56} },
        { spids.heroic_strike, {20, 39, 59, 78, 98, 118, 137, 145, 175} },
        { spids.hamstring, {61, 101, 141, 167.5} },
    });
elseif sc.class == sc.classes.hunter then

    for _, v in pairs(rank_seqs[spids.arcane_shot]) do
        spells[v].direct.flags = 
            bit.bor(spells[v].direct.flags, comp_flags.magic_scaling_as_ap);
    end
    for _, v in pairs(rank_seqs[spids.serpent_sting]) do
        spells[v].periodic.flags = 
            bit.bor(spells[v].periodic.flags, comp_flags.magic_scaling_as_ap);

        -- generator has coef for entire duration instead of per tick, divide by ticks
        if spells[v].periodic.coef_ap_min then
            spells[v].periodic.coef_ap_min =
                spells[v].periodic.tick_time*spells[v].periodic.coef_ap_min
                /
                spells[v].periodic.dur;
            spells[v].periodic.coef_ap_max =
                spells[v].periodic.tick_time*spells[v].periodic.coef_ap_max
                /
                spells[v].periodic.dur;
        end
    end
    for _, v in pairs(rank_seqs[spids.steady_shot]) do
        spells[v].direct.flags =
            bit.bor(spells[v].direct.flags, comp_flags.base_weapon_dmg);
    end
    for _, v in pairs(rank_seqs[spids.explosive_trap]) do
        spells[v].direct.coef_ap_min = 0.1;
        spells[v].direct.flags = 
            bit.bor(spells[v].direct.flags, comp_flags.magic_scaling_as_ap);
    end
    for _, v in pairs(rank_seqs[spids.immolation_trap]) do
        spells[v].periodic.coef_ap_min = 0.02;
        spells[v].periodic.flags = 
            bit.bor(spells[v].periodic.flags, comp_flags.magic_scaling_as_ap);
    end

    -- DISABLE JUNK
    for _, v in pairs(rank_seqs[spids.aspect_of_the_viper]) do
        spells[v].flags =
            bit.band(spells[v].flags, bit.bnot(spell_flags.eval));
    end
end

