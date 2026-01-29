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

local ap_per_str = {
    [classes.warrior] = 2,
    [classes.paladin] = 2,
    [classes.hunter]  = 1,
    [classes.rogue]   = 1,
    [classes.priest]  = 1,
    [classes.shaman]  = 2,
    [classes.mage]    = 1,
    [classes.warlock] = 1,
    [classes.druid]   = 2,
};

local ap_per_agi = {
    [classes.warrior] = 0,
    [classes.paladin] = 0,
    [classes.hunter]  = 1,
    [classes.rogue]   = 1,
    [classes.priest]  = 0,
    [classes.shaman]  = 0,
    [classes.mage]    = 0,
    [classes.warlock] = 0,
    [classes.druid]   = 0, -- when in cat form, druid is treated as rogue
};

local rap_per_agi = {
    [classes.warrior] = 1,
    [classes.paladin] = 0,
    [classes.hunter]  = 2,
    [classes.rogue]   = 1,
    [classes.priest]  = 0,
    [classes.shaman]  = 0,
    [classes.mage]    = 0,
    [classes.warlock] = 0,
    [classes.druid]   = 0,
};

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
};


----------------------------------------------------------------------------------------------------
scaling.dps_per_ap                       = dps_per_ap;
scaling.spirit_mana_regen                = spirit_mana_regen;
scaling.mana_per_int                     = mana_per_int;
scaling.hp_per_stam                      = hp_per_stam;
scaling.ap_per_str                       = ap_per_str;
scaling.ap_per_agi                       = ap_per_agi;
scaling.rap_per_agi                      = rap_per_agi;
scaling.armor_per_agi                    = armor_per_agi;
scaling.cr_weights                       = cr_weights;

sc.scaling = scaling;

