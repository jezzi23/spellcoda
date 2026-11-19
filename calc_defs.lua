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
    -- with use_flat, a crit multiplies the flat value by the spell's crit mod
    flat_crits              = bit.lshift(1, 11),
    own_stats               = bit.lshift(1, 12),
    -- counts in the expectation, not shown
    hidden                  = bit.lshift(1, 13),
};

-- indexed_keys.x[i] is "x"..i, built once
local indexed_keys = setmetatable({}, {
    __index = function(prefixes, prefix)
        local keys = setmetatable({}, {
            __index = function(list, i)
                local key = prefix..i;
                list[i] = key;
                return key;
            end
        });
        prefixes[prefix] = keys;
        return keys;
    end
});

-- flexible way to add custom effects that behave according to flags
-- that both go into expectation calculation and tooltip
local function add_extra_effect(stats, flags,  utilization, description, value, ticks, freq)
    stats.num_extra_effects = stats.num_extra_effects + 1;
    local i = stats.num_extra_effects;

    stats[indexed_keys.extra_effect_flags[i]] = flags;
    stats[indexed_keys.extra_effect_val[i]] = value;
    stats[indexed_keys.extra_effect_desc[i]] = description;
    stats[indexed_keys.extra_effect_util[i]] = utilization;
    if bit.band(flags, effect_flags.is_periodic) ~= 0 then
        stats[indexed_keys.extra_effect_ticks[i]] = ticks;
        stats[indexed_keys.extra_effect_tick_time[i]] = freq;
    end
    if bit.band(flags, effect_flags.should_track_crit_mod) ~= 0 then
        stats.num_special_crit_mod_tracked = stats.num_special_crit_mod_tracked + 1;
        stats[indexed_keys.special_crit_mod_tracked[stats.num_special_crit_mod_tracked]] = i;
    end
end

-- targets: expectation over all targets relative to one, counted only when not evaluated as a single effect
local function add_extra_effect_own(stats, utilization, description, min, max, crit_min, crit_max, hit_normal, crit,
                                    school, targets, jumps, jump_amp, hidden)
    stats.num_extra_effects = stats.num_extra_effects + 1;
    local i = stats.num_extra_effects;

    stats[indexed_keys.extra_effect_school[i]] = school;
    stats[indexed_keys.extra_effect_targets[i]] = targets;
    stats[indexed_keys.extra_effect_jumps[i]] = jumps;
    stats[indexed_keys.extra_effect_jump_amp[i]] = jump_amp;

    stats[indexed_keys.extra_effect_flags[i]] =
        (hidden and bit.bor(effect_flags.own_stats, effect_flags.hidden)) or effect_flags.own_stats;
    stats[indexed_keys.extra_effect_val[i]] = min;
    stats[indexed_keys.extra_effect_max[i]] = max;
    stats[indexed_keys.extra_effect_crit_min[i]] = crit_min;
    stats[indexed_keys.extra_effect_crit_max[i]] = crit_max;
    stats[indexed_keys.extra_effect_hit[i]] = hit_normal;
    stats[indexed_keys.extra_effect_crit[i]] = crit;
    stats[indexed_keys.extra_effect_desc[i]] = description;
    stats[indexed_keys.extra_effect_util[i]] = utilization;
end
--------------------------------------------------------------------------------

calc.effect_flags                   = effect_flags;
calc.add_extra_effect               = add_extra_effect;
calc.add_extra_effect_own           = add_extra_effect_own;
calc.indexed_keys                   = indexed_keys;

sc.calc = calc;


