local _, sc = ...;

local classes   = sc.classes;
local class     = sc.class;
----------------------------------------------------------------------------------------------------
local scaling = {};

local dps_per_ap = 1/14;
local mana_per_int = 15;
local hp_per_stam = 10;
local armor_per_agi = 2;

local function spirit_mana_regen(spirit, intellect)
    -- src: https://www.wowhead.com/tbc/guide/classic-the-burning-crusade-stats-overview
    local mp2 = math.sqrt(intellect)*spirit*0.018654 + 0.002;
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
    sc.rap_per_agi = 1;
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
    [CR_DEFENSE_SKILL]                  = 1.5,
    [CR_BLOCK]                          = 5,
    [CR_DODGE]                          = 12,
    [CR_PARRY]                          = 15,
    [CR_HIT_MELEE]                      = 10,
    [CR_HIT_RANGED]                     = 10,
    [CR_CRIT_MELEE]                     = 14,
    [CR_CRIT_RANGED]                    = 14,
    [CR_HASTE_MELEE]                    = 10,
    [CR_HASTE_RANGED]                   = 10,
    [CR_EXPERTISE]                      = 2.5,

    [CR_HIT_SPELL]                      = 8,
    [CR_CRIT_SPELL]                     = 14,
    [CR_HASTE_SPELL]                    = 10,

    [CR_RESILIENCE_CRIT_TAKEN]          = 25,
    [CR_RESILIENCE_PLAYER_DAMAGE_TAKEN] = 11.36363636,
};


----------------------------------------------------------------------------------------------------
scaling.dps_per_ap                       = dps_per_ap;
scaling.spirit_mana_regen                = spirit_mana_regen;
scaling.mana_per_int                     = mana_per_int;
scaling.hp_per_stam                      = hp_per_stam;
scaling.armor_per_agi                    = armor_per_agi;
scaling.cr_weights                       = cr_weights;

sc.scaling = scaling;

