local _, sc = ...;

--------------------------------------------------------------------------------
local calc = {};
-- minimal defs needed both by client specific mechanics and general calc

local effect_flags = {
    is_periodic             = bit.lshift(1, 0),
    triggers_on_crit        = bit.lshift(1, 1),
    use_flat                = bit.lshift(1, 2),
    add_flat                = bit.lshift(1, 3),
    base_on_periodic_effect = bit.lshift(1, 4),
    should_track_crit_mod   = bit.lshift(1, 5),
    glance                  = bit.lshift(1, 6),
    no_crit                 = bit.lshift(1, 7),
    can_be_blocked          = bit.lshift(1, 8),
    always_hits             = bit.lshift(1, 9),
    shares_periodic_type    = bit.lshift(1, 10),
};

-- flexible way to add custom effects that behave according to flags
-- that both go into expectation calculation and tooltip
local function add_extra_effect(stats, flags,  utilization, description, value, ticks, freq)
    stats.num_extra_effects = stats.num_extra_effects + 1;
    local i = stats.num_extra_effects;

    stats["extra_effect_flags" .. i] = flags;
    stats["extra_effect_val" .. i] = value;
    stats["extra_effect_desc" .. i] = description;
    stats["extra_effect_util" .. i] = utilization;
    if bit.band(flags, effect_flags.is_periodic) ~= 0 then
        stats["extra_effect_ticks" .. i] = ticks;
        stats["extra_effect_tick_time" .. i] = freq;
    end
    if bit.band(flags, effect_flags.should_track_crit_mod) ~= 0 then
        stats.num_special_crit_mod_tracked = stats.num_special_crit_mod_tracked + 1;
        stats["special_crit_mod_tracked"..stats.num_special_crit_mod_tracked] = i;
    end
end
--------------------------------------------------------------------------------

calc.effect_flags                   = effect_flags;
calc.add_extra_effect               = add_extra_effect;

sc.calc = calc;


