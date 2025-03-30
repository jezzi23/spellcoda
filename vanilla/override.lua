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

-- Lookups for things that need special handling
--
-- Rune enchant IDs
lookups.rune_fanaticism             = 7088;
lookups.rune_wrath                  = 7089;
lookups.rune_infusion_of_light      = 7051;
lookups.rune_infusion_of_light      = 7051;
lookups.rune_overload               = 6878;
lookups.rune_divine_aegis           = 7109;
lookups.rune_ancestral_awakening    = 7048;
lookups.rune_dance_of_the_wicked    = 6957;
lookups.rune_soul_siphon            = 7590;
lookups.rune_living_seed            = 6975;
lookups.rune_advanced_warding       = 6726;

lookups.exorcist                    = 415076;
lookups.sacred_shield               = 412019;
lookups.rapid_healing               = 468531;
lookups.water_shield                = 408510;
lookups.fingers_of_frost            = 400669;
lookups.living_seed                 = 414677;
lookups.fanaticism                  = 429142;
lookups.divine_aegis                = 431622;
lookups.overload                    = 408438;
lookups.ancestral_awakening         = 425858;

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
    for _, v in pairs(rank_seqs[spids.ice_lance]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.429, spells[v].lvl_req);
    end

    spells[spids.arcane_surge].direct.per_resource = 0.03;
    spells[spids.arcane_surge].flags = bit.bor(spells[spids.arcane_surge].flags, spell_flags.uses_all_power);

    lookups.averaged_procs = {
        12536, -- clearcast
        22008, -- tier 2 instant cast proc
    };

    do
        -- Shatter and ice lance effect
        -- Having generator generate all frozen effects would be a lot of bloat
        -- instead just track it through common mage spells through class_misc value
        local freeze_detection_aura = {"raw", "class_misc", 1, nil, 0, -1};
        local affecters = {"deep_freeze", "frost_nova"};
        for _, v in ipairs(affecters) do
            for _, id in ipairs(rank_seqs[spids[v]]) do
                if not sc.hostile_buffs[id] then
                    sc.hostile_buffs[id] = {};
                end
                table.insert(sc.hostile_buffs[id], freeze_detection_aura);
            end
        end
        -- add fingers of frost as well
        if not sc.class_buffs[lookups.fingers_of_frost] then
            sc.class_buffs[lookups.fingers_of_frost] = {};
        end
        table.insert(sc.class_buffs[lookups.fingers_of_frost], freeze_detection_aura);
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

    -- COEF ADJUSTMENTS
    for _, v in pairs(rank_seqs[spids.lifebloom]) do
        spells[v].periodic.coef = spell_coef_lvl_adjusted(0.051, spells[v].lvl_req);
    end
    -- cat has a few spells with AP coef not found in game client
    for _, v in pairs(rank_seqs[spids.ferocious_bite]) do
        spells[v].direct.per_cp_coef_ap = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.rake]) do
        --TODO: Did SOD turbo charge some of these ap scalings?
        spells[v].periodic.coef_ap_min = 0.02;
        --spells[v].periodic.coef_ap = 0.11215;
    end
    for _, v in pairs(rank_seqs[spids.rip]) do
        spells[v].periodic.coef_ap_min = 0.04;
    end
    if bit.band(sc.game_mode, sc.game_modes.season_of_discovery) == 0 then
        -- new moonkin passive id in SOD, no way to detect if this is active or not at runtime
        sc.shapeshift_passives[443359] = nil;
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
    for _, v in pairs(rank_seqs[spids.power_word_shield]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.1, spells[v].lvl_req);
    end
    for _, v in pairs(rank_seqs[spids.penance]) do
        -- first tick missing from generator, use direct portion as one tick of periodic
        spells[v].direct = spells[v].periodic;
        if spells[v].healing_version  then
            spells[v].healing_version.direct = spells[v].healing_version.periodic;
        end
    end

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.mind_blast, 1.0}
    });
    for _, v in pairs(rank_seqs[spids.holy_nova]) do
        spells[v].flags = bit.bor(spells[v].flags, spell_flags.no_threat);
        spells[v].healing_version.flags = bit.bor(spells[v].healing_version.flags, spell_flags.no_threat);
    end

    for _, talent_id in pairs(talent_ranks[214]) do
        for _, auras in pairs(sc.talent_effects[talent_id]) do
            if auras[sc.aura_idx_category] == "by_attr" then
                auras[sc.aura_idx_subject] = {attr.spirit};
            end
        end
    end

elseif sc.class == sc.classes.shaman then
    for _, v in pairs(rank_seqs[spids.earth_shield]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.271, spells[v].lvl_req);
    end

    spells[spids.shamanistic_rage].flags =
        bit.bor(spells[spids.shamanistic_rage].flags, spell_flags.regen_max_pct);
    spells[spids.shamanistic_rage].periodic.min = spells[spids.shamanistic_rage].periodic.min * 0.01;

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


    do
        if bit.band(sc.game_mode, sc.game_modes.season_of_discovery) ~= 0 then
            -- Soul siphon rune shadow debuffs detection using class_misc value
            local shadow_detection_aura = {"raw", "class_misc", 1, nil, sc.aura_flags.requires_ownership, -1};
            local affecters = {"corruption", "curse_of_agony", "curse_of_doom", "curse_of_recklessness", "curse_of_shadow", "curse_of_the_elements", "curse_of_weakness", "curse_of_tongues", "fear", "haunt", "howl_of_terror" };
            for _, v in ipairs(affecters) do
                for _, id in ipairs(rank_seqs[spids[v]]) do
                    if not sc.hostile_buffs[id] then
                        sc.hostile_buffs[id] = {};
                    end
                    table.insert(sc.hostile_buffs[id], shadow_detection_aura);
                end
            end
        end
    end

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.searing_pain, 1.0}
    });
    for rank, talent_id in pairs(talent_ranks[105]) do
        -- Life tap talent effect is a dummy, needs manual adding
        sc.talent_effects[talent_id] = {
            {"ability", "base_mod", rank*0.1, {spids.life_tap}, 0, 0},
        };
    end
elseif sc.class == sc.classes.rogue then
    -- rogue has a few spells with AP coef not found in game client
    for _, v in pairs(rank_seqs[spids.rupture]) do
        spells[v].periodic.coef_ap_by_cp = {0.01, 0.02, 0.03, 0.03, 0.03}; -- scuffed scaling
    end
    for _, v in pairs(rank_seqs[spids.eviscerate]) do
        spells[v].direct.per_cp_coef_ap = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.garrote]) do
        spells[v].periodic.coef_ap_min = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.garrote_2]) do
        spells[v].periodic.coef_ap_min = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.slice_and_dice]) do
        spells[v].periodic.per_cp_dur = 3;
    end

    spells[spids.fan_of_knives].direct.flags =
        bit.bor(spells[spids.fan_of_knives].direct.flags, comp_flags.applies_oh, comp_flags.full_oh);
    spells[spids.mutilate].direct.flags =
        bit.bor(spells[spids.mutilate].direct.flags, comp_flags.applies_oh, comp_flags.full_oh);
    spells[spids.main_gauche].direct.flags =
        bit.bor(spells[spids.main_gauche].direct.flags, comp_flags.applies_oh, comp_flags.full_oh);
    spells[spids.main_gauche].direct.flags =
        bit.band(spells[spids.main_gauche].direct.flags, bit.bnot(comp_flags.applies_mh));

    -- Disable broken spells
    spells[spids.envenom].flags =
        bit.band(spells[spids.envenom].flags, bit.bnot(spell_flags.eval));
    spells[spids.between_the_eyes].flags =
        bit.band(spells[spids.between_the_eyes].flags, bit.bnot(spell_flags.eval));

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
    -- Holy light and flash of light are treated as dummies in vanilla client data, coef missing
    for _, v in pairs(rank_seqs[spids.flash_of_light]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.429, spells[v].lvl_req);
    end
    for _, v in pairs(rank_seqs[spids.holy_light]) do
        spells[v].direct.coef = spell_coef_lvl_adjusted(0.714, spells[v].lvl_req);
    end

    sc.passives[lookups.exorcist] = {
		{"ability", "crit", 1.0, {spids.exorcism, spids.exorcism_2}, 0, 0},
    };

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
        [4] = {413479}, -- gladiator
    }

    for _, v in pairs(rank_seqs[spids.shield_slam]) do
        spells[v].direct.per_resource = 0.05; -- hacked in as per strength
    end
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

