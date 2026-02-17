
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
scaling.ap_per_str                       = ap_per_str;
scaling.ap_per_agi                       = ap_per_agi;
scaling.rap_per_agi                      = rap_per_agi;
scaling.armor_per_agi                    = armor_per_agi;
scaling.cr_weights                       = cr_weights;

sc.scaling = scaling;

