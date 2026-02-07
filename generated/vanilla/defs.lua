-- THIS FILE IS GENERATED
local _, sc = ...;
sc.addon_build_id = 1914;
sc.client_name_src = "wow_classic_era";
sc.client_version_src = "1.15.8.65300";
_, sc.class = UnitClass("player");
_, _, sc.race = UnitRace("player");
sc.faction = UnitFactionGroup("player");
local build, version, date = GetBuildInfo();
sc.client_version_loaded = build.."."..version;
sc.client_date_loaded = date;
sc.max_lvl = 60;
sc.expansions = {
	vanilla = 0,
	tbc = 1,
};
sc.expansion = sc.expansions.vanilla;
sc.game_modes = {
    hardcore = bit.lshift(1, 0),
    season_of_discovery = bit.lshift(1, 2),
};
sc.game_mode = 0;
if C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() then
    sc.game_mode = bit.bor(sc.game_mode, sc.game_modes.hardcore);
end
if C_Engraving and C_Engraving.IsEngravingEnabled() then
    sc.game_mode = bit.bor(sc.game_mode, sc.game_modes.season_of_discovery);
end
sc.lookups = {};
sc.classes = {
	warrior = "WARRIOR",
	paladin = "PALADIN",
	hunter = "HUNTER",
	rogue = "ROGUE",
	priest = "PRIEST",
	shaman = "SHAMAN",
	mage = "MAGE",
	warlock = "WARLOCK",
	druid = "DRUID",
	fake = "FAKE",
};
sc.aura_idx_category = 1;
sc.aura_idx_effect = 2;
sc.aura_idx_value = 3;
sc.aura_idx_subject = 4;
sc.aura_idx_flags = 5;
sc.aura_idx_iid = 6;
sc.races = {
	human = 1,
	orc = 2,
	dwarf = 3,
	nightelf = 4,
	scourge = 5,
	tauren = 6,
	gnome = 7,
	troll = 8,
	goblin = 9,
};
sc.schools = {
	physical = 1,
	holy = 2,
	fire = 3,
	nature = 4,
	frost = 5,
	shadow = 6,
	arcane = 7,
};
sc.attr = {
	strength = 1,
	agility = 2,
	stamina = 3,
	intellect = 4,
	spirit = 5,
};
sc.powers = {
	mana = 0,
	rage = 1,
	focus = 2,
	energy = 3,
	combopoints = 4,
	happiness = 27,
};
sc.power_mod = {
	[0] = 1,
	[1] = 0.1,
	[2] = 1,
	[3] = 1,
	[4] = 1,
	[27] = 0.001,
};
sc.spell_flags = {
	heal = bit.lshift(1, 0),
	absorb = bit.lshift(1, 1),
	channel = bit.lshift(1, 2),
	cd = bit.lshift(1, 3),
	base_mana_cost = bit.lshift(1, 4),
	instant = bit.lshift(1, 5),
	binary = bit.lshift(1, 6),
	eval = bit.lshift(1, 7),
	resource_regen = bit.lshift(1, 8),
	regen_pct = bit.lshift(1, 9),
	regen_max_pct = bit.lshift(1, 10),
	weapon_enchant = bit.lshift(1, 11),
	on_next_attack = bit.lshift(1, 12),
	uses_attack_speed = bit.lshift(1, 13),
	finishing_move_dmg = bit.lshift(1, 14),
	finishing_move_dur = bit.lshift(1, 15),
	pet = bit.lshift(1, 16),
	talent = bit.lshift(1, 17),
	refund_on_miss = bit.lshift(1, 18),
	only_threat = bit.lshift(1, 19),
	no_threat = bit.lshift(1, 20),
	behind_target = bit.lshift(1, 21),
	uses_all_power = bit.lshift(1, 22),
	alias = bit.lshift(1, 23),
	requires_ranged_slot = bit.lshift(1, 24),
	ot_haste_improved = bit.lshift(1, 25),
	ehp = bit.lshift(1, 26),
};
sc.comp_flags = {
	cant_crit = bit.lshift(1, 0),
	always_hit = bit.lshift(1, 1),
	ignores_mitigation = bit.lshift(1, 2),
	periodic = bit.lshift(1, 3),
	unbounded_aoe = bit.lshift(1, 4),
	dot_resi_pen = bit.lshift(1, 5),
	applies_mh = bit.lshift(1, 6),
	applies_oh = bit.lshift(1, 7),
	applies_ranged = bit.lshift(1, 8),
	magic_scaling_as_ap = bit.lshift(1, 9),
	full_oh = bit.lshift(1, 10),
	normalized_weapon = bit.lshift(1, 11),
	base_weapon_dmg = bit.lshift(1, 12),
	heal_to_full = bit.lshift(1, 13),
	no_active_defense = bit.lshift(1, 14),
	no_attack = bit.lshift(1, 15),
	native_jumps = bit.lshift(1, 16),
	jump_amp_as_per_extra_power = bit.lshift(1, 17),
	bleed = bit.lshift(1, 18),
	weapon_pct = bit.lshift(1, 19),
	coef_applied_to_avg_weapon_dmg = bit.lshift(1, 20),
};
sc.aura_flags = {
	mul = bit.lshift(1, 0),
	inactive_forced = bit.lshift(1, 1),
	requires_ownership = bit.lshift(1, 2),
	weapon_subclass = bit.lshift(1, 3),
	apply_aura = bit.lshift(1, 4),
	forced_separated = bit.lshift(1, 5),
	stacks_as_charges = bit.lshift(1, 6),
	weapon_slot_dependent = bit.lshift(1, 7),
	requires_feral_shapeshift = bit.lshift(1, 8),
};
sc.feral_skill_as_wpn_subclass_hack = 28;
sc.wep_subclass_to_normalized_speed = {
	[1] = 3.3,
	[16] = 2.8,
	[6] = 3.3,
	[28] = 0,
	[13] = 2.4,
	[2] = 2.8,
	[3] = 2.8,
	[4] = 2.4,
	[18] = 2.8,
	[19] = 2.8,
	[15] = 1.7,
	[10] = 3.3,
	[5] = 3.3,
	[0] = 2.4,
	[8] = 3.3,
	[7] = 2.4,
};
sc.two_handed_wep_subclasses = {
	[1] = 1,
	[6] = 1,
	[10] = 1,
	[5] = 1,
	[8] = 1,
};
sc.gem_type_flags = {
	meta =  1,
	red =  2,
	yellow =  4,
	blue =  8,
}
