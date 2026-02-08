local _, sc = ...;

---------------------------------------------------------------------------------------------------
-- Public interface for other addons to tap into SpellCoda calculations
---------------------------------------------------------------------------------------------------

---@class SpellCoda
SpellCoda = {}

---@return number
function SpellCoda:GetVersion()
    return sc.core.version_id
end

---------------------------------------------------------------------------------------------------
--- Data
---------------------------------------------------------------------------------------------------

--- Bit flag definitions for spells.
---@type table<string, number>
SpellCoda.spell_flags = sc.spell_flags

--- Bit flag definitions for the direct or periodic component of a spells
---@type table<string, number>
SpellCoda.comp_flags = sc.comp_flags

--- Raw data for spells by ID (class-dependent)
---@type table<number, table>
SpellCoda.spells = sc.spells

--- English names map to spell ID written out like this: battle_shout (class-dependent)
---@type table<string, number>
SpellCoda.spids = sc.spids

--- Bit flag definitions for calculation evaluation flags
---@type table<string, number>
SpellCoda.evaluation_flags = sc.calc.evaluation_flags

---@private
SpellCoda.__internals = sc

---------------------------------------------------------------------------------------------------
--- Utilities
---------------------------------------------------------------------------------------------------

---@param spell_id number
---@return number|nil
function SpellCoda:HighestSpellRankLearned(spell_id)
    return sc.spells[spell_id]
        and sc.utils.highest_learned_rank(sc.spells[spell_id].base_id)
end

---@return boolean overlay_muted, boolean overlay_disabled
function SpellCoda:GetConfig()
    return sc.core.external_config()
end

---------------------------------------------------------------------------------------------------
--- Overlay
---------------------------------------------------------------------------------------------------

--- May be called multiple times with already registered frame to change spellId
---@param frame table Frame which Spellcoda will render spell overlay onto in the same way as with action bar slots
---@param spellId number Spell ID of the spell to track
function SpellCoda:RegisterFrameAsSpellOverlay(frame, spell_id)
    sc.ext.register_overlay_frame(frame, spell_id)
end

---@param frame table
function SpellCoda:UnregisterFrameAsSpellOverlay(frame)
    sc.ext.unregister_overlay_frame(frame)
end

---------------------------------------------------------------------------------------------------
--- Currently casting frame spell data
--- Directly tied, and limited to the configuration and behaviour of currently casting frame
---------------------------------------------------------------------------------------------------

---@class CurrentlyCastingSpellData
---@field spell_id number Spell ID. = 0 if SpellCoda does not care for this spell
---@field spell table|nil Raw base data for spell. = nil if spell_id is 0.
---     Table structure can be seen in e.g. generated/vanilla/mage.lua
---@field info table|nil Calculated spell data. = nil if not evaluable spell
---     May contain any amount direct and periodic (ot for "over time") subcomponents.
---@field stats table|nil Calculated spell stats. = nil if not evaluable spell
---     Contains more general spell stats for spell which info is computed from.
---
--- NOTE: info and stats have many fields and should only be accessed conditionally,
---       e.g. based on spell_flags, comp_flags and more
---       For typical usage of info and stats fields, look at "overlay_label_handler" definition in overlay.lua

---@param callback_fn function Function is called every time SpellCoda has updated currently casting spell data
---@param info_schema? string[] Optional array of keys to control what gets updated in "info" of returned table
---@param stats_schema? string[] Optional array of keys to control what gets updated in "stats" of returned table
---@return CurrentlyCastingSpellData
function SpellCoda:RegisterCurrentlyCastingSpellOnUpdate(callback_fn, info_schema, stats_schema)
    return sc.overlay.register_cc_on_update(callback_fn, info_schema, stats_schema)
end

---@param callback_fn function
function SpellCoda:UnregisterCurrentlyCastingSpellOnUpdate(callback_fn)
    sc.overlay.unregister_cc_on_update(callback_fn)
end

---------------------------------------------------------------------------------------------------
--- General-purpose spell calculation feed.
---------------------------------------------------------------------------------------------------

---@class SpellsFeed
---@field spells table<number, SpellFeedEntry>             -- Maps SpellID -> spell data (read-only)
---@field highest_rank_spells table<number, SpellFeedEntry> -- Maps SpellID -> highest learned rank (read-only)

---@class SpellFeedEntry
---@field spell table        -- Raw spell data
---     Table structure can be seen in e.g. generated/vanilla/mage.lua
---@field info table         -- Calculated info fields (filtered by info_schema)
---     May contain any amount direct and periodic (ot for "over time") subcomponents.
---@field stats table        -- Calculated stat fields (filtered by stats_schema)
---     Contains more general spell stats for spell which info is computed from.
---
--- NOTE: info and stats have many fields and should only be accessed conditionally,
---       e.g. based on spell_flags, comp_flags and more
---       For typical usage of info and stats fields, look at "overlay_label_handler" definition in overlay.lua
---
---------------------------------------------------------------------------------------------------
--- Creates a new SpellsFeed.
---
--- The returned feed object exposes methods for managing which spells are tracked
--- and for triggering updates to their calculated data.
---
---@param info_schema? string[] Optional list of keys to populate in `entry.info`
---     Example:
---     {
---         "min_noncrit_if_hit1",
---         "max_noncrit_if_hit1",
---         "min_crit_if_hit1",
---         "max_crit_if_hit1",
---     }
---
---@param stats_schema? string[] Optional list of keys to populate in `entry.stats`
---
---@param on_overlay_updated_feed_fn? fun(feed: SpellsFeed)
---     Optional callback invoked when SpellCoda's overlay update routine updates this feed
---
---@param on_config_changed_fn? fun(feed: SpellsFeed, overlay_muted: boolean, overlay_disabled: boolean)
---     Optional callback invoked when SpellCoda-specific configuration changes
---
---@return SpellsFeed feed The newly created spells feed
---
--- ### Feed Methods
---
--- **Update control**
--- * `feed:Update()`  
---   Updates all tracked spells and populates their calculated data.
---
--- * `feed:UpdateRelaxed()`  
---   Same as `Update`, but may use slightly outdated data from potential previous overlay updates.
---
--- **Spell management**
--- * `feed:AddSpell(spell_id: number)`
--- * `feed:RemoveSpell(spell_id: number)`
---
--- * `feed:AddSpellHighestRankLearned(spell_id: number)`  
---   Tracks the highest learned rank of this spell in `highest_rank_spells`.
---
--- * `feed:RemoveSpellHighestRankLearned(spell_id: number)`
---
--- **Lifecycle**
--- * `feed:Pause()`  
---   Prevents further automatic or manual updates.
---
--- * `feed:Resume()`
--- * `feed:IsPaused(): boolean`
---
--- **Evaluation behavior**
--- * `feed:SetEvalFlags(flags: number)`  
---   Sets evaluation flags used during calculations.  
---   Requires an update to take effect.  
---   See `SpellCoda.evaluation_flags`.
---
--- * `feed:GetEvalFlags(): number`
---
--- * `feed:PrioritizeHeal()`  
---   If a spell has both healing and damage components, the healing variant is fed.
---   Requires an update to take effect.
---
--- * `feed:PrioritizeDamage()`  
---   Same as above, but favors damage.
---------------------------------------------------------------------------------------------------
function SpellCoda:CreateSpellsFeed(info_schema, stats_schema, on_overlay_updated_feed_fn, on_config_changed_fn)
    return sc.spells_feed.create(
        info_schema,
        stats_schema,
        on_overlay_updated_feed_fn,
        on_config_changed_fn
    )
end

---------------------------------------------------------------------------------------------------
--- Deletes a previously created SpellsFeed.
---
---@param feed SpellsFeed
---------------------------------------------------------------------------------------------------
function SpellCoda:DeleteSpellsFeed(feed)
    sc.spells_feed.delete(feed)
end

---------------------------------------------------------------------------------------------------
-- Demo usage of SpellsFeed for mage class:
--   Tracks some instant spells (highest ranks) and the spell being casted
---------------------------------------------------------------------------------------------------
--[[
if not SpellCoda or select(2, UnitClass("player")) ~= "MAGE" then return end

local function print_spell_feed(feed)
   -- Spells from IDs
   print("Spells:")
   for spell_id, data in pairs(feed.spells) do
      local spell_txt = string.format("%s (%d) Rank %d ", GetSpellInfo(spell_id), spell_id, (data.spell and data.spell.rank) or 0, data.info, data.stats)
      
      
      if bit.band(data.spell.flags, SpellCoda.spell_flags.eval) ~= 0 then
         spell_txt = spell_txt..string.format("Effect %.1f", data.info.expected)
      end
      print("      ", spell_txt)
   end
   -- Highest ranks of spell ID
   print("Highest rank spells:")
   for spell_id, data in pairs(feed.highest_rank_spells) do
      -- here spell_id is the key the spell was added as (not the best rank id)
      -- data.spell may be nil if no rank of this spell is learned!
      local spell_txt = ""
      if data.spell then
         spell_txt = spell_txt..string.format("%s Rank %d ", GetSpellInfo(spell_id), data.spell.rank, data.info, data.stats)
         
         if bit.band(data.spell.flags, SpellCoda.spell_flags.eval) ~= 0 then
            spell_txt = spell_txt..string.format("Effect %.1f", data.info.expected)
         end
         
      else
         spell_txt = string.format("%s (%d) no rank learned!", GetSpellInfo(spell_id), spell_id)
         
      end
      print("       ", spell_txt)
      
   end
   print("-----------------------------------------")
end

local function on_config_changed(self, overlay_muted, overlay_disabled)
   
   local feed = self
   -- Can act on SpellCoda overlay configuration changes
   print("SpellCoda overlay config change:", overlay_muted, overlay_disabled)
   
   if overlay_muted then
      feed:Pause()
   else
      feed:Resume()
   end
end

local function on_feed_updated_by_overlay(self)
   
   local feed = self
   print("SpellCoda has updated feed from overlay update:")
   print_spell_feed(feed)
   
end

my_feed = SpellCoda:CreateSpellsFeed(
   nil, -- or e.g. {"expected", "effect_per_sec"}
   nil, -- or e.g. {"crit"},
   on_feed_updated_by_overlay, -- optional
   on_config_changed -- optional
)

-- track some instant spells
for _, base_spell_id in ipairs({
      SpellCoda.spids.fire_blast,
      SpellCoda.spids.cone_of_cold,
      SpellCoda.spids.blast_wave
}) do
   -- when my_feed updates it always uses best rank learned
   my_feed:AddSpellHighestRankLearned(base_spell_id)
end

my_feed:SetEvalFlags(bit.bor(
      -- set some random flags, by default it uses overlay flags
      SpellCoda.evaluation_flags.assume_single_effect,
      SpellCoda.evaluation_flags.fix_weapon_skill_to_level
))
print("Feed flags:", my_feed:GetEvalFlags())

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_START")

local spell_id_casting
frame:SetScript("OnEvent", function(_, _, unit_target, _, new_spell_id)
      if unit_target ~= "player" then return end
      
      if spell_id_casting and spell_id_casting ~= new_spell_id and my_feed.spells[spell_id_casting] then
         my_feed:RemoveSpell(spell_id_casting)
      end
      
      my_feed:AddSpell(new_spell_id)
      spell_id_casting = new_spell_id
      
      
      if UnitIsEnemy("player", "target") then
         my_feed:PrioritizeDamage()
      else
         -- when spell is hybrid (Penance), the healing variant is fed
         -- through and spell.flags will have SpellCoda:spell_flags.heal set
         my_feed:PrioritizeHeal()
      end
      
      -- bad idea to call this Update very frequently, use for major events like
      -- spell cast changes / target switch etc
      local did_update = my_feed:Update()
      if did_update then
         print("Feed has been updated directly")
         print_spell_feed(my_feed)
      else
         print("Feed not updated")
      end
      -- or my_feed:UpdateRelaxed() which may use a previous update from overlay but could be outdated
      
end)
--]]
---------------------------------------------------------------------------------------------------
