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
local talent_idx                    = sc.talent_idx;
local lookups                       = sc.lookups;

local spell_coef_lvl_adjusted       = sc.utils.spell_coef_lvl_adjusted;
local add_threat_flat_by_rank       = sc.utils.add_threat_flat_by_rank;
local add_threat_mod_all_ranks      = sc.utils.add_threat_mod_all_ranks;
---------------------------------------------------------------------------------------------------

spids.curse_of_agony = spids.bane_of_agony;


sc.dual_wield_class =
    sc.class == sc.classes.warrior or
    sc.class == sc.classes.rogue;


-- Threat data for special abilities needs some fixing

if sc.class == sc.classes.mage then
    for _, v in pairs(rank_seqs[spids.ice_lance]) do
        spells[v].direct.coef = 0.429;
    end

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
        if not sc.class_buffs[lookups.fingers_of_frost] then
            sc.class_buffs[lookups.fingers_of_frost] = {};
        end
        table.insert(sc.class_buffs[lookups.fingers_of_frost], freeze_detection_aura);
    end

    -- THREAT
    --add_threat_flat_by_rank({
    --    { spids.counterspell, {300} },
    --    { spids.remove_lesser_curse, {14} },
    --});
elseif sc.class == sc.classes.druid then
    lookups.wild_growth_lname = C_Spell.GetSpellName(spids.wild_growth);

    -- DISABLE JUNK
    spells[spids.swiftmend].flags = bit.band(spells[spids.swiftmend].flags, bit.bnot(spell_flags.eval));
    for _, v in pairs(rank_seqs[spids.frenzied_regeneration]) do
        spells[v].flags = bit.band(spells[v].flags, bit.bnot(spell_flags.eval));
    end

    -- COEF ADJUSTMENTS
    for _, v in pairs(rank_seqs[spids.lifebloom]) do
        spells[v].periodic.coef = 0.051;
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
        spells[v].periodic.per_cp_dur = 0.0;

    end
    if bit.band(sc.game_mode, sc.game_modes.season_of_discovery) ~= 0 then

        -- in SoD rip has special ap scaling
        for _, v in pairs(rank_seqs[spids.rip]) do
            spells[v].periodic.coef_ap_by_cp = {0.01, 0.02, 0.03, 0.04, 0.04};
        end

    else
        -- new moonkin passive id in SOD, no way to detect if this is active or not at runtime
        sc.shapeshift_passives[443359] = nil;

        -- TODO: unclear if vanilla rip should have SoD's rip scaling or not
        for _, v in pairs(rank_seqs[spids.rip]) do
            spells[v].periodic.coef_ap_min = 0.04;
        end
    end

    do
        -- Heart of the wild shapeshift specials hacked in by blizzard as dummies instead of being
        -- added to shapeshift passive effects so needs to be hacked in here too
        -- (without this stat weights would be inaccurate for shapeshifts)

        local cat_passive = sc.shapeshift_passives[3025];
        local new_cat_effect_iid = cat_passive[#cat_passive][sc.aura_idx_iid] + 1;
        cat_passive[#cat_passive + 1] = {"by_attr", "stat_mod", 0.0, {attr.strength,}, 32, new_cat_effect_iid};

        local bear_passive = sc.shapeshift_passives[1178];
        local new_bear_effect_iid = bear_passive[#bear_passive][sc.aura_idx_iid] + 1;
        bear_passive[#bear_passive + 1] = {"by_attr", "stat_mod", 0.0, {attr.stamina,}, 32, new_bear_effect_iid};

        local dire_bear_passive = sc.shapeshift_passives[9635];
        local new_dire_bear_effect_iid = dire_bear_passive[#dire_bear_passive][sc.aura_idx_iid] + 1;
        dire_bear_passive[#dire_bear_passive + 1] = {"by_attr", "stat_mod", 0.0, {attr.stamina,}, 32, new_dire_bear_effect_iid};

        local stamina_curve = sc.dummies[lookups.heart_of_the_wild][2][4];
        local strength_curve = sc.dummies[lookups.heart_of_the_wild][3][4];

        local effects = sc.talent_effects[lookups.heart_of_the_wild];
        -- add to aura points to our fake new effects
        local iid_next = effects[#effects][sc.aura_idx_iid] + 1;

        effects[#effects + 1] = {"aura_pts_flat", new_cat_effect_iid, 0.0, {3025}, 0, iid_next, 0.01, strength_curve};
        iid_next = iid_next + 1;

        effects[#effects + 1] = {"aura_pts_flat", new_bear_effect_iid, 0.0, {1178}, 0, iid_next, 0.01, stamina_curve};
        iid_next = iid_next + 1;

        effects[#effects + 1] = {"aura_pts_flat", new_dire_bear_effect_iid, 0.0, {9635}, 0, iid_next, 0.01, stamina_curve};
    end

    do
        -- use class_misc to track forms required for special feral attack power effects
        for _, v in ipairs({
            {spids.moonkin_form,    5}, -- shapeshift idx 5
            {spids.cat_form,        3},
            {spids.bear_form,       1},
            {spids.dire_bear_form,  1},
        }) do

            local spid = v[1];
            local idx = v[2];

            local effects = sc.class_buffs[spid];
            effects[#effects + 1] = {"raw", "class_misc", idx, nil, 0, -1};
        end
    end



    lookups.averaged_procs = {
        16870, -- clearcast
        16886, -- nature's grace
    };

    -- THREAT
    --add_threat_flat_by_rank({
    --    { spids.demoralizing_roar, {9, 15, 20, 30, 39} },
    --    { spids.faerie_fire_feral, {108, 108, 108, 108} },
    --    { spids.faerie_fire, {108, 108, 108, 108} },
    --});
    --add_threat_mod_all_ranks({
    --    {spids.maul, 0.75},
    --    {spids.swipe, 0.75},
    --});

elseif sc.class == sc.classes.priest then

    --for _, v in pairs(rank_seqs[spids.mana_burn]) do
    --    spells[v].direct.coef = 0.1;
    --end

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.mind_blast, 1.0}
    });
    for _, v in pairs(rank_seqs[spids.holy_nova]) do
        spells[v].flags = bit.bor(spells[v].flags, spell_flags.no_threat);
        spells[v].healing_version.flags = bit.bor(spells[v].healing_version.flags, spell_flags.no_threat);
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

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.searing_pain, 1.0}
    });

elseif sc.class == sc.classes.rogue then

    -- rogue has a few spells with AP coef not found in game client
    for _, v in pairs(rank_seqs[spids.rupture]) do
        spells[v].periodic.coef_ap_by_cp = {0.01, 0.02, 0.03, 0.03, 0.03}; -- scuffed scaling
        spells[v].periodic.per_cp_dur = 2;
    end
    for _, v in pairs(rank_seqs[spids.eviscerate]) do
        spells[v].direct.per_cp_coef_ap = 0.03;
    end
    for _, v in pairs(rank_seqs[spids.garrote]) do
        spells[v].periodic.coef_ap_min = 0.03;
    end
    -- TODO: between the eyes coef unknown
    --spells[spids.between_the_eyes].direct.per_cp_coef_ap = 0.03;
    for _, v in pairs(rank_seqs[spids.slice_and_dice]) do
        spells[v].periodic.per_cp_dur = 3;
    end

    spells[spids.main_gauche].direct.flags =
        bit.band(spells[spids.main_gauche].direct.flags, bit.bnot(comp_flags.applies_mh));


elseif sc.class == sc.classes.paladin then

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

    -- THREAT
    add_threat_mod_all_ranks({
        {spids.execute, 0.25},
        {spids.thunder_clap, 1.5},
    });

    add_threat_flat_by_rank({
        { spids.revenge, {155, 195, 235, 275, 315, 355} },
        { spids.shield_slam, {160, 190, 220, 250} },
        { spids.shield_bash, {180, 180, 180} },
        { spids.battle_shout, {5, 11, 17, 26, 39, 55, 70} },
        { spids.cleave, {10, 40, 60, 70, 100} },
        { spids.demoralizing_shout, {11, 17, 21, 32, 43} },
        { spids.heroic_strike, {20, 39, 59, 78, 98, 118, 137, 145, 175} },
        { spids.hamstring, {61, 101, 141} },
    });
elseif sc.class == sc.classes.hunter then

end


