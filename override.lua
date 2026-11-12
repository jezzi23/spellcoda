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

local alias_all_ranks               = sc.utils.alias_all_ranks;
---------------------------------------------------------------------------------------------------

if sc.class == classes.mage then

    for _, v in pairs(rank_seqs[spids.fireball]) do
        if spells[v].periodic then
            -- empowered fireball talent was giving the periodic part an incorrect boost in coef
            -- this is never intended in any client
            spells[v].periodic.flags = bit.bor(spells[v].periodic.flags, comp_flags.no_coef);
        end
    end

elseif class == classes.warlock then

    lookups.isb_lname = C_Spell.GetSpellName(lookups.shadow_vulnerability);

elseif class == classes.shaman then

elseif class == classes.druid then

    lookups.rejuvenation_lname = C_Spell.GetSpellName(spids.rejuvenation);
    lookups.regrowth_lname = C_Spell.GetSpellName(spids.regrowth);
    lookups.lifebloom_lname = C_Spell.GetSpellName(spids.lifebloom);

    alias_all_ranks(spids.tigers_fury, sc.auto_attack_spell_id);
elseif class == classes.priest then

    lookups.priest_t3 = 525;
elseif class == classes.rogue then

    alias_all_ranks(spids.slice_and_dice, sc.auto_attack_spell_id);

end

for k, v in pairs({"shoot", "throw", "shoot_bow", "shoot_gun", "shoot_crossbow"}) do
    if spids[v] then
        spells[spids[v]].flags = bit.bor(spells[spids[v]].flags, spell_flags.uses_attack_speed);
    end
end

