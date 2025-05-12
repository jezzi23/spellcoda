local _, sc = ...;

local classes   = sc.classes;
local class     = sc.class;
---------------------------------------------------------------------------------------------------
local scaling = {};

local dps_per_ap = 1/14;
local mana_per_int = 15;

local function get_combat_rating_effect(rating_id, level)
    -- for vanilla, treat rating as same as percentage
    return 1;
end

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


-- NOTE: intellect to spell crit and agi to physical crit
--       is not a linear scale by level. However we approximate here
--       with linear interpolation between lvl 1 and 60.
--       We may want better accuracy here
local class_int_to_spell_crit = {
    [classes.warrior] = {
        [1] = 0.0,
        [60] = 0.0,
    },
    [classes.paladin] = {
        [1] = 13.333,
        [60] = 59.880,
    },
    [classes.hunter] = {
        [1] = 14.286,
        [60] = 60.606,
    },
    [classes.rogue] = {
        [1] = 0.0,
        [60] = 0.0,
    },
    [classes.priest] = {
        [1] = 5.238,
        [60] = 59.524,
    },
    [classes.shaman] = {
        [1] = 7.776,
        [60] = 59.172,
    },
    [classes.mage] = {
        [1] = 5.208,
        [60] = 59.524,
    },
    [classes.warlock] = {
        [1] = 6.666,
        [60] = 60.606,
    },
    [classes.druid] = {
        [1] = 6.873,
        [60] = 59.880,
    },
};

local class_agi_to_physical_crit = {
    [classes.warrior] = {
        [1] = 4.000,
        [60] = 20.000,
    },
    [classes.paladin] = {
        [1] = 4.651,
        [60] = 19.763,
    },
    [classes.hunter] = {
        [1] = 5.600,
        [60] = 52.910,
    },
    [classes.rogue] = {
        [1] = 2.300,
        [60] = 28.986,
    },
    [classes.priest] = {
        [1] = 10.000,
        [60] = 20.000,
    },
    [classes.shaman] = {
        [1] = 6.061,
        [60] = 19.685,
    },
    [classes.mage] = {
        [1] = 11.111,
        [60] = 19.455,
    },
    [classes.warlock] = {
        [1] = 6.666,
        [60] = 20.000,
    },
    [classes.druid] = {
        [1] = 4.878,
        [60] = 20.000,
    },
};

local function lerp_by_lvl(by_lvl, lvl, min, max)

    local range = max-min;
    return by_lvl[min] + (by_lvl[max] - by_lvl[min])*(lvl-min)/range;
end

local function int_to_spell_crit(int, lvl)
    local int_to_crit = lerp_by_lvl(class_int_to_spell_crit[class], lvl, 1, 60);
    if int_to_crit == 0 then
        return 0;
    else
        return 0.01*int/int_to_crit;
    end
end

local function agi_to_physical_crit(agi, lvl)
    local agi_to_crit = lerp_by_lvl(class_agi_to_physical_crit[class], lvl, 1, 60);
    if agi_to_crit == 0 then
        return 0;
    else
        return 0.01*agi/agi_to_crit;
    end
end

scaling.dps_per_ap                       = dps_per_ap;
scaling.get_combat_rating_effect         = get_combat_rating_effect;
scaling.spirit_mana_regen                = spirit_mana_regen;
scaling.mana_per_int                     = mana_per_int;
scaling.int_to_spell_crit                = int_to_spell_crit;
scaling.agi_to_physical_crit             = agi_to_physical_crit;
scaling.ap_per_str                       = ap_per_str;
scaling.ap_per_agi                       = ap_per_agi;
scaling.rap_per_agi                      = rap_per_agi;

sc.scaling = scaling;

