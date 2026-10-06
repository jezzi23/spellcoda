-- Overrides on generator data shared for all clients go here if any
-- Most are client specific, under e.g ./Vanilla/override.lua
local _, sc = ...;

local spells                        = sc.spells;
local lookups                       = sc.lookups;
local class                         = sc.class;
local classes                       = sc.classes;
local spids                         = sc.spids;
local spell_flags                   = sc.spell_flags;
local comp_flags                    = sc.comp_flags;
local rank_seqs                     = sc.rank_seqs;
---------------------------------------------------------------------------------------------------

if sc.class == classes.mage then

    for _, v in pairs(rank_seqs[spids.fireball]) do
        if spells[v].periodic then
            -- empowered fireball talent was giving the periodic part an incorrect boost in coef
            -- this is never intended in any client
            spells[v].periodic.flags = bit.bor(spells[v].periodic.flags, comp_flags.no_coef);
        end
    end

elseif class == classes.paladin then
    lookups.greater_bol_lname = C_Spell.GetSpellName(spids.greater_blessing_of_light);
    lookups.bol_lname = C_Spell.GetSpellName(spids.blessing_of_light);
    lookups.bol_rank_to_hl_coef_subtract = {
        [1] = 1.0 - (1 - (20 - 1) * 0.0375) * 2.5 / 3.5, -- lvl 1 hl coef used
        [2] = 1.0 - 0.4,
        [3] = 1.0 - 0.7,
    };
elseif class == classes.warlock then

    lookups.isb_lname = C_Spell.GetSpellName(17800);
elseif class == classes.shaman then

elseif class == classes.druid then

    lookups.rejuvenation_lname = C_Spell.GetSpellName(spids.rejuvenation);
    lookups.regrowth_lname = C_Spell.GetSpellName(spids.regrowth);
    lookups.lifebloom_lname = C_Spell.GetSpellName(spids.lifebloom);
elseif class == classes.priest then

    lookups.priest_t3 = 525;
elseif class == classes.rogue then

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

for k, v in pairs({"shoot", "throw", "shoot_bow", "shoot_gun", "shoot_crossbow"}) do
    if spids[v] then
        spells[spids[v]].flags = bit.bor(spells[spids[v]].flags, spell_flags.uses_attack_speed);
    end
end

