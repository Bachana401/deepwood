class_name SkillTreeData
extends RefCounted

# One tree per class. Node fields:
#   id: unique across ALL trees (prefixed by class)
#   name/desc: shown in the tree UI
#   tier: 1-5 -- visibility is gated by tier (you can only see 2 tiers past
#         your deepest unlocked tier, per the progressive-reveal design)
#   cost: skill points to unlock
#   prereq: node id that must be unlocked first ("" = a tree root)
#   materials: {item_id: count} consumed from the player inventory on unlock.
#              Tiers 1-2 are points-only (the "in the start, points are
#              enough" rule); materials appear from tier 3 up and escalate.
#   effect: {effect_key: value} -- summed by GameState.get_skill_total().
# Effect keys: melee_damage / melee_cooldown (Sword class covers sword+spear),
# bow_damage / bow_cooldown, wand_cooldown, max_health, move_speed,
# gold_gain, xp_gain. Values are additive fractions (0.1 = +10%), except
# max_health which is flat HP.
const TREES = {
	"Sword": [
		{"id": "sw_dmg1", "name": "Sharpened Edge", "desc": "+10% melee damage", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"melee_damage": 0.10}},
		{"id": "sw_hp1", "name": "Toughness", "desc": "+15 max health", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"max_health": 15.0}},
		{"id": "sw_spd1", "name": "Quick Swings", "desc": "-10% melee cooldown", "tier": 2, "cost": 1, "prereq": "sw_dmg1", "materials": {}, "effect": {"melee_cooldown": 0.10}},
		{"id": "sw_hp2", "name": "Iron Skin", "desc": "+25 max health", "tier": 2, "cost": 1, "prereq": "sw_hp1", "materials": {}, "effect": {"max_health": 25.0}},
		{"id": "sw_dmg2", "name": "Brutal Blows", "desc": "+20% melee damage", "tier": 3, "cost": 2, "prereq": "sw_spd1", "materials": {"slime": 3}, "effect": {"melee_damage": 0.20}},
		{"id": "sw_mob1", "name": "Battle Stride", "desc": "+10% move speed", "tier": 3, "cost": 2, "prereq": "sw_hp2", "materials": {"slime": 2}, "effect": {"move_speed": 0.10}},
		{"id": "sw_dmg3", "name": "Executioner", "desc": "+30% melee damage", "tier": 4, "cost": 3, "prereq": "sw_dmg2", "materials": {"iron_shard": 3}, "effect": {"melee_damage": 0.30}},
		{"id": "sw_spd2", "name": "Blade Flurry", "desc": "-20% melee cooldown", "tier": 4, "cost": 3, "prereq": "sw_mob1", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"melee_cooldown": 0.20}},
		{"id": "sw_cap", "name": "Warlord", "desc": "+40% melee damage, +40 max health", "tier": 5, "cost": 5, "prereq": "sw_dmg3", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"melee_damage": 0.40, "max_health": 40.0}},
	],
	"Archer": [
		{"id": "ar_dmg1", "name": "Barbed Arrows", "desc": "+10% bow damage", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"bow_damage": 0.10}},
		{"id": "ar_mob1", "name": "Light Feet", "desc": "+8% move speed", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"move_speed": 0.08}},
		{"id": "ar_spd1", "name": "Fast Nocking", "desc": "-10% bow cooldown", "tier": 2, "cost": 1, "prereq": "ar_dmg1", "materials": {}, "effect": {"bow_cooldown": 0.10}},
		{"id": "ar_gold1", "name": "Scavenger", "desc": "+15% gold from kills", "tier": 2, "cost": 1, "prereq": "ar_mob1", "materials": {}, "effect": {"gold_gain": 0.15}},
		{"id": "ar_dmg2", "name": "Piercing Shots", "desc": "+20% bow damage", "tier": 3, "cost": 2, "prereq": "ar_spd1", "materials": {"slime": 3}, "effect": {"bow_damage": 0.20}},
		{"id": "ar_xp1", "name": "Hunter's Instinct", "desc": "+15% XP from kills", "tier": 3, "cost": 2, "prereq": "ar_gold1", "materials": {"slime": 2}, "effect": {"xp_gain": 0.15}},
		{"id": "ar_spd2", "name": "Rapid Volley", "desc": "-20% bow cooldown", "tier": 4, "cost": 3, "prereq": "ar_dmg2", "materials": {"iron_shard": 3}, "effect": {"bow_cooldown": 0.20}},
		{"id": "ar_mob2", "name": "Windrunner", "desc": "+15% move speed", "tier": 4, "cost": 3, "prereq": "ar_xp1", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"move_speed": 0.15}},
		{"id": "ar_cap", "name": "Deadeye", "desc": "+45% bow damage, -15% bow cooldown", "tier": 5, "cost": 5, "prereq": "ar_spd2", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"bow_damage": 0.45, "bow_cooldown": 0.15}},
	],
	"Mage": [
		{"id": "mg_cd1", "name": "Focused Mind", "desc": "-10% wand cooldown", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"wand_cooldown": 0.10}},
		{"id": "mg_hp1", "name": "Arcane Ward", "desc": "+10 max health", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {"max_health": 10.0}},
		{"id": "mg_xp1", "name": "Scholar", "desc": "+15% XP from kills", "tier": 2, "cost": 1, "prereq": "mg_cd1", "materials": {}, "effect": {"xp_gain": 0.15}},
		{"id": "mg_gold1", "name": "Transmutation", "desc": "+15% gold from kills", "tier": 2, "cost": 1, "prereq": "mg_hp1", "materials": {}, "effect": {"gold_gain": 0.15}},
		{"id": "mg_cd2", "name": "Channeling", "desc": "-15% wand cooldown", "tier": 3, "cost": 2, "prereq": "mg_xp1", "materials": {"slime": 3}, "effect": {"wand_cooldown": 0.15}},
		{"id": "mg_mob1", "name": "Blink Step", "desc": "+10% move speed", "tier": 3, "cost": 2, "prereq": "mg_gold1", "materials": {"slime": 2}, "effect": {"move_speed": 0.10}},
		{"id": "mg_cd3", "name": "Overcharge", "desc": "-20% wand cooldown", "tier": 4, "cost": 3, "prereq": "mg_cd2", "materials": {"iron_shard": 3}, "effect": {"wand_cooldown": 0.20}},
		{"id": "mg_xp2", "name": "Sage", "desc": "+25% XP from kills", "tier": 4, "cost": 3, "prereq": "mg_mob1", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"xp_gain": 0.25}},
		{"id": "mg_cap", "name": "Archmage", "desc": "-30% wand cooldown, +30 max health", "tier": 5, "cost": 5, "prereq": "mg_cd3", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"wand_cooldown": 0.30, "max_health": 30.0}},
	],
	# Unlockable only after finishing the game -- which isn't possible yet, so
	# this stays a locked teaser in the class-choice screen for now.
	"Necromancer": [
		{"id": "nc_placeholder", "name": "Death's Pact", "desc": "???", "tier": 1, "cost": 1, "prereq": "", "materials": {}, "effect": {}},
	],
}

const CLASS_COLORS = {
	"Sword": Color(0.78, 0.28, 0.18),
	"Archer": Color(0.28, 0.65, 0.3),
	"Mage": Color(0.5, 0.35, 0.85),
	"Necromancer": Color(0.2, 0.55, 0.4),
}

static func get_node_by_id(node_id: String) -> Dictionary:
	for tree in TREES.values():
		for node in tree:
			if node.id == node_id:
				return node
	return {}
