local _, sc = ...;

local L                                     = sc.L;

local spells                                = sc.spells;
local spell_flags                           = sc.spell_flags;

local clear_table                           = sc.utils.clear_table;
local table_from_schema                     = sc.utils.table_from_schema;

local update_loadout_and_effects            = sc.loadouts.update_loadout_and_effects;

local cast_until_oom                        = sc.calc.cast_until_oom;
local calc_spell_eval                       = sc.calc.calc_spell_eval;
local calc_spell_threat                     = sc.calc.calc_spell_threat;

local config                                = sc.config;

---------------------------------------------------------------------------------------------------
-- General purpose spells feed implementation for external uses
local spells_feed_export = {};

local SpellsFeed = {};
SpellsFeed.__index = SpellsFeed;

local external_feeds = {};

local info, stats;

local function external_feed_calc_spells(feed, feed_data, spells_feed, spells_feed_data, loadout, effects)

    for spell_id_key, data in pairs(spells_feed_data) do

        local spell = data.spell;
        if spell then
            if spell.healing_version and feed_data.prio_heal then
                spell = spell.healing_version;
            end
            if bit.band(spell.flags, spell_flags.eval) ~= 0 then
                info, stats = calc_spell_eval(spell, loadout, effects, feed_data.eval_flags, data.spell_id);
                cast_until_oom(info, spell, stats, loadout, effects, false, feed_data.eval_flags);

            elseif bit.band(spell.flags, spell_flags.only_threat) ~= 0 then
                info, stats = calc_spell_threat(spell, loadout, effects, feed_data.eval_flags);
            end

            if bit.band(spell.flags, bit.bor(spell_flags.eval, spell_flags.only_threat)) ~= 0 then
                table_from_schema(data.info, info, feed_data.info_schema);
                spells_feed[spell_id_key].info = data.info;
                table_from_schema(data.stats, stats, feed_data.stats_schema);
                spells_feed[spell_id_key].stats = data.stats;
            else
                spells_feed[spell_id_key].info = nil
                spells_feed[spell_id_key].stats = nil
            end


        end

        spells_feed[spell_id_key].spell = spell;
    end
end

local function external_feed_calc(feed, feed_data, loadout, effects)
    external_feed_calc_spells(feed, feed_data, feed.spells, feed_data.spells_data, loadout, effects);
    external_feed_calc_spells(feed, feed_data, feed.highest_rank_spells, feed_data.highest_rank_spells_data, loadout, effects);
end

--local feed_update_id = 0;
local function external_spells_update(feed, relaxed_dt)

    local feed_data = external_feeds[feed];

    if feed_data.paused then
        return false;
    end

    local loadout, _, effects, _ = update_loadout_and_effects(relaxed_dt);

    --local updated = update_id > feed_update_id;
    --feed_update_id = update_id;
    --if updated then
    --end

    external_feed_calc(feed, feed_data, loadout, effects);

    return true;
end

local function external_feed_highest_ranks_update()
    for _, feed_data in pairs(external_feeds) do
        for spell_id, v in pairs(feed_data.highest_rank_spells_data) do
            local highest_id = sc.utils.highest_learned_rank(sc.spells[spell_id].base_id);
            v.spell_id = highest_id;
            v.spell = highest_id and spells[highest_id];
        end
    end
end

local function external_feed_reconfig(overlay_muted, overlay_disabled)
    for feed, feed_data in pairs(external_feeds) do
        if feed_data.config_fn then
            feed_data.config_fn(feed, overlay_muted, overlay_disabled);
        end
    end
end

function SpellsFeed:Update()

    return external_spells_update(self, 0);
end

function SpellsFeed:UpdateRelaxed()

    if config.settings.overlay_disable or sc.core.mute_overlay then
        return self:Update();
    end
    return external_spells_update(self, math.huge);
end

function SpellsFeed:Pause()
    external_feeds[self].paused = true;
end

function SpellsFeed:Resume()
    external_feeds[self].paused = false;
end

function SpellsFeed:IsPaused()
    return external_feeds[self].paused;
end

function SpellsFeed:SetEvalFlags(eval_flags)
    external_feeds[self].eval_flags = eval_flags;
end

function SpellsFeed:GetEvalFlags()
    return external_feeds[self].eval_flags;
end

function SpellsFeed:PrioritizeHeal()
    external_feeds[self].prio_heal = true;
end

function SpellsFeed:PrioritizeDamage()
    external_feeds[self].prio_heal = false;
end

local function feed_add_spell(feed_data, spells_feed, spells_data, spell_id_key, spell_id_value)

    if spells_data[spell_id_key] or not spells[spell_id_key] then
        return;
    end

    spells_data[spell_id_key] = feed_data.spells_data_free[#feed_data.spells_data_free] or {
        info = {},
        stats = {},
    };
    feed_data.spells_data_free[#feed_data.spells_data_free] = nil;

    spells_data[spell_id_key].spell_id = spell_id_value;
    spells_data[spell_id_key].spell = spells[spell_id_value];

    spells_feed[spell_id_key] = {};
end

function SpellsFeed:AddSpell(spell_id)

    local feed_data = external_feeds[self];
    feed_add_spell(feed_data, self.spells, feed_data.spells_data, spell_id, spell_id);
end

function SpellsFeed:AddSpellHighestRankLearned(spell_id)

    local feed_data = external_feeds[self];
    feed_add_spell(
        feed_data,
        self.highest_rank_spells,
        feed_data.highest_rank_spells_data,
        spell_id,
        sc.utils.highest_learned_rank(sc.spells[spell_id].base_id)
    );
end

function SpellsFeed:RemoveSpell(spell_id)

    local feed_data = external_feeds[self];
    if feed_data.spells_data[spell_id] then

        feed_data.spells_data_free[#feed_data.spells_data_free + 1] = feed_data.spells_data[spell_id];
        feed_data.spells_data[spell_id] = nil;
    end
    self.spells[spell_id] = nil;
end

function SpellsFeed:RemoveSpellHighestRankLearned(spell_id)

    local feed_data = external_feeds[self];
    if feed_data.highest_rank_spells_data[spell_id] then

        feed_data.spells_data_free[#feed_data.spells_data_free + 1] = feed_data.highest_rank_spells_data[spell_id];
        feed_data.highest_rank_spells_data[spell_id] = nil;
    end
    self.highest_rank_spells[spell_id] = nil;
end

function SpellsFeed:RemoveAllSpells()

    local feed_data = external_feeds[self];
    for k, _ in pairs(feed_data.spells_data) do
        self:RemoveSpell(k);
    end
    for k, _ in pairs(feed_data.highest_rank_spells_data) do
        self:RemoveSpellHighestRankLearned(k);
    end
end

local function create_spells_feed(info_schema,
                                  stats_schema,
                                  on_overlay_updated_feed_fn,
                                  on_config_changed_fn)

    local new_feed = {
        spells = {},
        highest_rank_spells = {},
    };
    setmetatable(new_feed, SpellsFeed);
    external_feeds[new_feed] = {
        spells_data = {},
        highest_rank_spells_data = {},
        paused = false,
        prio_heal = true,
        eval_flags = sc.overlay.overlay_eval_flags(),
        callback_fn = on_overlay_updated_feed_fn,
        config_fn = on_config_changed_fn,
        info_schema = info_schema,
        stats_schema = stats_schema,
        spells_data_free = {},
    };

    return new_feed;
end

local function delete_spells_feed(spells_feed)

    if not spells_feed or not external_feeds[spells_feed] then
        return;
    end

    external_feeds[spells_feed] = nil;
    spells_feed.spells = nil;
end
---------------------------------------------------------------------------------------------------
spells_feed_export.create                             = create_spells_feed;
spells_feed_export.delete                             = delete_spells_feed;
spells_feed_export.external_feed_highest_ranks_update = external_feed_highest_ranks_update;
spells_feed_export.external_feed_reconfig             = external_feed_reconfig;
spells_feed_export.external_feed_calc                 = external_feed_calc;
spells_feed_export.external_feeds                     = external_feeds;

sc.spells_feed = spells_feed_export;
