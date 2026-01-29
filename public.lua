local _, sc = ...;

-- Limited public interface for other addons to interact with SpellCoda
SpellCoda = {};

function SpellCoda:GetVersion()
    return sc.core.version_id;
end
---------------------------------------------------------------------------------------------------
--- Data
---------------------------------------------------------------------------------------------------

--- Bit flag definitions for spells.
---@type table<string, number>
SpellCoda.spell_flags = sc.spell_flags;

--- Bit flag definitions for the direct or periodic component of a spells
---@type table<string, number>
SpellCoda.comp_flags = sc.comp_flags;

SpellCoda.__internals = sc;

---------------------------------------------------------------------------------------------------
--- Overlay
---------------------------------------------------------------------------------------------------

--- May be called multiple times with already registered frame to change spellId
---@param frame table Frame which Spellcoda will render spell overlay onto in the same way as with action bar slots
---@param spellId number Spell ID of the spell to track
function SpellCoda:RegisterFrameAsSpellOverlay(frame, spellId)
    sc.ext.register_overlay_frame(frame, spellId);
end
function SpellCoda:UnregisterFrameAsSpellOverlay(frame)
    sc.ext.unregister_overlay_frame(frame);
end

---------------------------------------------------------------------------------------------------
--- Currently casting spell data
---------------------------------------------------------------------------------------------------

---@param callbackFunc function Function is called every time SpellCoda has updated currently casting spell data
---@param infoSchema? table Optional array of keys to control what gets updated in "info" of returned table
---     Example: infoSchema = {
---         "min_noncrit_if_hit1",
---         "max_noncrit_if_hit1",
---         "min_crit_if_hit1"
---         "max_crit_if_hit1"
---    };
---@param statsSchema? table Optional array of keys to control what gets updated in "stats" of returned table
---@return table Table of currently casting spell data which SpellCoda updates, with the following fields:
---{
---     spell_id  : number (Spell ID. = 0 if SpellCoda does not care for this spell)
---
---     spell     : table  (Raw base data for spell. = nil if spell_id is 0.
---         Useful to to check for spell.flags against SpellCoda.spell_flags and
---         if spell has spell.direct or spell.periodic component.
---         Table structure can be seen in e.g. generated/vanilla/mage.lua
---     )
---
---     info      : table  (Calculated spell data. = nil if not evaluable spell
---         May contain any amount direct and periodic (ot for "over time") subcomponents. 
---         For typical examples of usage of "info" table, look at table "overlay_label_handler" defined in overlay.lua
---         NOTE: there are many info fields and should only be used conditionally,
---             e.g. info.ot_min_noncrit_if_hit1 will contain junk if the spell does not have at least 1 periodic component
---     )
---
---     stats     : table  (Calculated spell stats. = nil if not evaluable spell
---         Contains more general spell stats for spell which info is computed from.
---         For typical examples of usage of "stats" table, look at table "overlay_label_handler" defined in overlay.lua
---     )
---}
function SpellCoda:RegisterCurrentlyCastingSpellOnUpdate(callbackFunc, infoSchema, statsSchema)
    return sc.overlay.register_cc_on_update(callbackFunc, infoSchema, statsSchema);
end
function SpellCoda:UnregisterCurrentlyCastingSpellOnUpdate(callbackFunc)
    sc.overlay.unregister_cc_on_update(callbackFunc);
end

