
local _, sc = ...;

local classes               = sc.classes;
local class                 = sc.class;

local combat_ratings        = sc.utils.combat_ratings;
---------------------------------------------------------------------------------------------------
local scaling = {};

local dps_per_ap = 1/14;
local mana_per_int = 15;
local hp_per_stam = 10;
local armor_per_agi = 2;

local function spirit_mana_regen(spirit)
    -- src: https://wowwiki-archive.fandom.com/wiki/Spirit
    -- without mp5
    local mp2 = 0;
    if class == "PRIEST" or class == "MAGE" then
        mp2 = (13 + spirit / 4);
    elseif class == "DRUID" or class == "SHAMAN" or class == "PALADIN" then
        mp2 = (15 + spirit / 5);
    elseif class == "WARLOCK" then
        mp2 = (8 + spirit / 4);
    end
    return mp2;
end

if class == classes.warrior then
    sc.ap_per_str = 2;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 1;
elseif class == classes.paladin then
    sc.ap_per_str = 2;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
elseif class == classes.hunter then
    sc.ap_per_str = 1;
    sc.ap_per_agi = 1;
    sc.rap_per_agi = 2;
elseif class == classes.rogue then
    sc.ap_per_str = 1;
    sc.ap_per_agi = 1;
    sc.rap_per_agi = 1;
elseif class == classes.priest then
    sc.ap_per_str = 1;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
elseif class == classes.shaman then
    sc.ap_per_str = 2;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
elseif class == classes.mage then
    sc.ap_per_str = 1;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
elseif class == classes.warlock then
    sc.ap_per_str = 1;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
elseif class == classes.druid then
    sc.ap_per_str = 2;
    sc.ap_per_agi = 0;
    sc.rap_per_agi = 0;
    sc.cat_form_ap_per_agi = 1;
end

-- combat rating weights are multiplied by the general combat rating level scaling formula
local cr_weights = {
    -- in vanilla we treat this as 1:1 for generality
    [combat_ratings.CR_DEFENSE_SKILL]                  = 1,
    [combat_ratings.CR_BLOCK]                          = 1,
    [combat_ratings.CR_DODGE]                          = 1,
    [combat_ratings.CR_PARRY]                          = 1,
    [combat_ratings.CR_HIT_MELEE]                      = 1,
    [combat_ratings.CR_HIT_RANGED]                     = 1,
    [combat_ratings.CR_CRIT_MELEE]                     = 1,
    [combat_ratings.CR_CRIT_RANGED]                    = 1,
    [combat_ratings.CR_HASTE_MELEE]                    = 1,
    [combat_ratings.CR_HASTE_RANGED]                   = 1,
    [combat_ratings.CR_EXPERTISE]                      = 1,

    [combat_ratings.CR_HIT_SPELL]                      = 1,
    [combat_ratings.CR_CRIT_SPELL]                     = 1,
    [combat_ratings.CR_HASTE_SPELL]                    = 1,

    [combat_ratings.CR_RESILIENCE_CRIT_TAKEN]          = 1,
    [combat_ratings.CR_RESILIENCE_PLAYER_DAMAGE_TAKEN] = 1,
};

scaling.dps_per_ap                       = dps_per_ap;
scaling.spirit_mana_regen                = spirit_mana_regen;
scaling.mana_per_int                     = mana_per_int;
scaling.hp_per_stam                      = hp_per_stam;
scaling.armor_per_agi                    = armor_per_agi;
scaling.cr_weights                       = cr_weights;

sc.scaling = scaling;

