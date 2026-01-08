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

-- Lookups for things that need special handling

-- NOTE:
--  THREAT: Client data does not contain special threat information
--          added to many spells like Sunder armor, Heroic Strike, Mind Blast etc
--          For what it's worth, some threat info is added in this file according to
--          https://www.wowhead.com/classic/guide/threat-overview-classic-wow
--          Treat flat threat values from threat guide as extra threat regardless of
--          threat % modifiers and damage done by ability
--          (may be a faulty assumption since presumably threat data from
--          spell like Revenge was gathered in defensive stance with threat modifier)

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

    -- THREAT
    add_threat_flat_by_rank({
        { spids.demoralizing_roar, {9, 15, 20, 30, 39} },
        { spids.faerie_fire_feral, {108, 108, 108, 108} },
        { spids.faerie_fire, {108, 108, 108, 108} },
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
        16246, -- clearcast
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
    -- rogue has a few spells with AP coef not found in game client
    --for _, v in pairs(rank_seqs[spids.rupture]) do
    --    spells[v].periodic.coef_ap_by_cp = {0.01, 0.02, 0.03, 0.03, 0.03}; -- scuffed scaling
    --end
    --for _, v in pairs(rank_seqs[spids.eviscerate]) do
    --    spells[v].direct.per_cp_coef_ap = 0.03;
    --end
    --for _, v in pairs(rank_seqs[spids.garrote]) do
    --    spells[v].periodic.coef_ap_min = 0.03;
    --end
    --for _, v in pairs(rank_seqs[spids.garrote_2]) do
    --    spells[v].periodic.coef_ap_min = 0.03;
    --end
    for _, v in pairs(rank_seqs[spids.slice_and_dice]) do
        spells[v].periodic.per_cp_dur = 3;
    end

    spells[spids.mutilate].direct.flags =
        bit.bor(spells[spids.mutilate].direct.flags, comp_flags.applies_oh, comp_flags.full_oh);

    -- Disable broken spells
    spells[spids.envenom].flags =
        bit.band(spells[spids.envenom].flags, bit.bnot(spell_flags.eval));

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
    sc.friendly_buffs[spids.greater_blessing_of_light] = {
		{"ability", "effect_mod_flat", 400, {spids.holy_light}, 0, 0},
		{"ability", "effect_mod_flat", 115, {spids.flash_of_light}, 0, 1},
    };
    -- ??
    -- Holy light and flash of light are treated as dummies in vanilla client data, coef missing
    --for _, v in pairs(rank_seqs[spids.flash_of_light]) do
    --    spells[v].direct.coef = spell_coef_lvl_adjusted(0.429, spells[v].lvl_req);
    --end
    --for _, v in pairs(rank_seqs[spids.holy_light]) do
    --    spells[v].direct.coef = spell_coef_lvl_adjusted(0.714, spells[v].lvl_req);
    --end

    -- THREAT
    add_threat_flat_by_rank({
        { spids.holy_shield, {20, 30, 40} },
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
    -- THREAT
    add_threat_mod_all_ranks({
        {spids.execute, 0.25}
    });

    add_threat_flat_by_rank({
        { spids.revenge, {155, 195, 235, 275, 315, 355} },
        { spids.shield_slam, {160, 190, 220, 250} },
        { spids.sunder_armor, {100, 140, 180, 220, 260} },
        { spids.shield_bash, {180, 180, 180} },
        { spids.thunder_clap, {17, 40, 64, 96, 143, 180} },
        { spids.battle_shout, {5, 11, 17, 26, 39, 55, 70} },
        { spids.cleave, {10, 40, 60, 70, 100} },
        { spids.demoralizing_shout, {11, 17, 21, 32, 43} },
        { spids.heroic_strike, {20, 39, 59, 78, 98, 118, 137, 145, 175} },
        { spids.hamstring, {61, 101, 141} },
    });
elseif sc.class == sc.classes.hunter then

    if spids.shoot_bow then
        spells[spids.shoot_bow].flags = bit.band(spells[spids.shoot_bow].flags, bit.bnot(spell_flags.eval));
    end
    if spids.shoot_gun then
        spells[spids.shoot_bow].flags = bit.band(spells[spids.shoot_bow].flags, bit.bnot(spell_flags.eval));
    end
    if spids.shoot_crossbow then
        spells[spids.shoot_bow].flags = bit.band(spells[spids.shoot_bow].flags, bit.bnot(spell_flags.eval));
    end
end

