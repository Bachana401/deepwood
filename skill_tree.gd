class_name SkillTreeData
extends RefCounted

# Each class is ONE tree: a single root node (the trunk) that splits into 3
# named branches, each branch a 5-tier chain that keeps expanding. Node fields:
#   id: unique across ALL trees
#   branch: -1 for the root, else 0/1/2 (index into BRANCH_NAMES[class])
#   tier: 0 for the root, 1-5 within a branch. Progressive reveal is
#         per-branch: only 2 tiers past that branch's deepest unlock show.
#   cost: skill points to unlock
#   prereq: node id required first (branch tier-1 nodes all require the root)
#   materials: {item_id: count} consumed on unlock. Tiers 1-2 are points-only;
#              tier 3 wants Slime (dungeon L1-5), tier 4 Iron Shards/Ember
#              Crystals (L6-20), tier 5 capstones Void Essence + an Ancient
#              Relic (L21+). Materials must be RESEARCHED at the Science Lab.
#   effect: {effect_key: value} summed by GameState.get_skill_total().
# Effect keys: melee_damage/melee_cooldown (Sword covers sword+spear),
# bow_damage/bow_cooldown, wand_cooldown, max_health (flat HP), move_speed,
# gold_gain, xp_gain -- fractions unless noted (0.1 = +10%).
const BRANCH_NAMES = {
	"Sword": ["Might", "Endurance", "Frenzy"],
	"Archer": ["Precision", "Agility", "Plunder"],
	"Mage": ["Spellcraft", "Knowledge", "Vitality"],
	"Necromancer": ["???", "???", "???"],
}

const TREES = {
	"Sword": [
		{"id": "sw_root", "branch": -1, "name": "Way of the Blade", "desc": "+5% melee damage", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"melee_damage": 0.05}},
		# Might -- raw melee damage
		{"id": "sw_m1", "branch": 0, "name": "Sharpened Edge", "desc": "+10% melee damage", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"melee_damage": 0.10}},
		{"id": "sw_m2", "branch": 0, "name": "Heavy Strikes", "desc": "+15% melee damage", "tier": 2, "cost": 1, "prereq": "sw_m1", "materials": {}, "effect": {"melee_damage": 0.15}},
		{"id": "sw_m3", "branch": 0, "name": "Brutal Blows", "desc": "+20% melee damage", "tier": 3, "cost": 2, "prereq": "sw_m2", "materials": {"slime": 3}, "effect": {"melee_damage": 0.20}},
		{"id": "sw_m4", "branch": 0, "name": "Executioner", "desc": "+30% melee damage", "tier": 4, "cost": 3, "prereq": "sw_m3", "materials": {"iron_shard": 3}, "effect": {"melee_damage": 0.30}},
		{"id": "sw_m5", "branch": 0, "name": "Warlord", "desc": "+40% melee damage, +40 max health", "tier": 5, "cost": 5, "prereq": "sw_m4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"melee_damage": 0.40, "max_health": 40.0}},
		# Endurance -- health and staying power
		{"id": "sw_e1", "branch": 1, "name": "Toughness", "desc": "+15 max health", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"max_health": 15.0}},
		{"id": "sw_e2", "branch": 1, "name": "Iron Skin", "desc": "+25 max health", "tier": 2, "cost": 1, "prereq": "sw_e1", "materials": {}, "effect": {"max_health": 25.0}},
		{"id": "sw_e3", "branch": 1, "name": "Stone Body", "desc": "+35 max health", "tier": 3, "cost": 2, "prereq": "sw_e2", "materials": {"slime": 2}, "effect": {"max_health": 35.0}},
		{"id": "sw_e4", "branch": 1, "name": "Battle Stride", "desc": "+10% move speed, +20 max health", "tier": 4, "cost": 3, "prereq": "sw_e3", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"move_speed": 0.10, "max_health": 20.0}},
		{"id": "sw_e5", "branch": 1, "name": "Juggernaut", "desc": "+60 max health", "tier": 5, "cost": 5, "prereq": "sw_e4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"max_health": 60.0}},
		# Frenzy -- attack speed
		{"id": "sw_f1", "branch": 2, "name": "Quick Swings", "desc": "-8% melee cooldown", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"melee_cooldown": 0.08}},
		{"id": "sw_f2", "branch": 2, "name": "Fluid Combat", "desc": "-10% melee cooldown", "tier": 2, "cost": 1, "prereq": "sw_f1", "materials": {}, "effect": {"melee_cooldown": 0.10}},
		{"id": "sw_f3", "branch": 2, "name": "Flurry", "desc": "-12% melee cooldown", "tier": 3, "cost": 2, "prereq": "sw_f2", "materials": {"slime": 2}, "effect": {"melee_cooldown": 0.12}},
		{"id": "sw_f4", "branch": 2, "name": "Blade Dance", "desc": "-15% melee cooldown", "tier": 4, "cost": 3, "prereq": "sw_f3", "materials": {"iron_shard": 3}, "effect": {"melee_cooldown": 0.15}},
		{"id": "sw_f5", "branch": 2, "name": "Blade Tempest", "desc": "-20% melee cooldown, +15% melee damage", "tier": 5, "cost": 5, "prereq": "sw_f4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"melee_cooldown": 0.20, "melee_damage": 0.15}},
	],
	"Archer": [
		{"id": "ar_root", "branch": -1, "name": "Way of the Hunt", "desc": "+5% bow damage", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"bow_damage": 0.05}},
		# Precision -- bow damage
		{"id": "ar_p1", "branch": 0, "name": "Barbed Arrows", "desc": "+10% bow damage", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"bow_damage": 0.10}},
		{"id": "ar_p2", "branch": 0, "name": "Steady Aim", "desc": "+15% bow damage", "tier": 2, "cost": 1, "prereq": "ar_p1", "materials": {}, "effect": {"bow_damage": 0.15}},
		{"id": "ar_p3", "branch": 0, "name": "Piercing Shots", "desc": "+20% bow damage", "tier": 3, "cost": 2, "prereq": "ar_p2", "materials": {"slime": 3}, "effect": {"bow_damage": 0.20}},
		{"id": "ar_p4", "branch": 0, "name": "Deadshot", "desc": "+30% bow damage", "tier": 4, "cost": 3, "prereq": "ar_p3", "materials": {"iron_shard": 3}, "effect": {"bow_damage": 0.30}},
		{"id": "ar_p5", "branch": 0, "name": "Deadeye", "desc": "+45% bow damage, -10% bow cooldown", "tier": 5, "cost": 5, "prereq": "ar_p4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"bow_damage": 0.45, "bow_cooldown": 0.10}},
		# Agility -- movement and fire rate
		{"id": "ar_a1", "branch": 1, "name": "Light Feet", "desc": "+8% move speed", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"move_speed": 0.08}},
		{"id": "ar_a2", "branch": 1, "name": "Fast Nocking", "desc": "-10% bow cooldown", "tier": 2, "cost": 1, "prereq": "ar_a1", "materials": {}, "effect": {"bow_cooldown": 0.10}},
		{"id": "ar_a3", "branch": 1, "name": "Nimble", "desc": "+10% move speed", "tier": 3, "cost": 2, "prereq": "ar_a2", "materials": {"slime": 2}, "effect": {"move_speed": 0.10}},
		{"id": "ar_a4", "branch": 1, "name": "Rapid Volley", "desc": "-15% bow cooldown", "tier": 4, "cost": 3, "prereq": "ar_a3", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"bow_cooldown": 0.15}},
		{"id": "ar_a5", "branch": 1, "name": "Windrunner", "desc": "+15% move speed, -10% bow cooldown", "tier": 5, "cost": 5, "prereq": "ar_a4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"move_speed": 0.15, "bow_cooldown": 0.10}},
		# Plunder -- gold and XP
		{"id": "ar_l1", "branch": 2, "name": "Scavenger", "desc": "+15% gold from kills", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"gold_gain": 0.15}},
		{"id": "ar_l2", "branch": 2, "name": "Keen Eye", "desc": "+10% XP from kills", "tier": 2, "cost": 1, "prereq": "ar_l1", "materials": {}, "effect": {"xp_gain": 0.10}},
		{"id": "ar_l3", "branch": 2, "name": "Treasure Sense", "desc": "+20% gold from kills", "tier": 3, "cost": 2, "prereq": "ar_l2", "materials": {"slime": 2}, "effect": {"gold_gain": 0.20}},
		{"id": "ar_l4", "branch": 2, "name": "Hunter's Instinct", "desc": "+20% XP from kills", "tier": 4, "cost": 3, "prereq": "ar_l3", "materials": {"iron_shard": 3}, "effect": {"xp_gain": 0.20}},
		{"id": "ar_l5", "branch": 2, "name": "Fortune Hunter", "desc": "+25% gold, +25% XP", "tier": 5, "cost": 5, "prereq": "ar_l4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"gold_gain": 0.25, "xp_gain": 0.25}},
	],
	"Mage": [
		{"id": "mg_root", "branch": -1, "name": "Way of the Arcane", "desc": "-5% wand cooldown", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"wand_cooldown": 0.05}},
		# Spellcraft -- wand power
		{"id": "mg_s1", "branch": 0, "name": "Focused Mind", "desc": "-10% wand cooldown", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"wand_cooldown": 0.10}},
		{"id": "mg_s2", "branch": 0, "name": "Channeling", "desc": "-12% wand cooldown", "tier": 2, "cost": 1, "prereq": "mg_s1", "materials": {}, "effect": {"wand_cooldown": 0.12}},
		{"id": "mg_s3", "branch": 0, "name": "Overcharge", "desc": "-15% wand cooldown", "tier": 3, "cost": 2, "prereq": "mg_s2", "materials": {"slime": 3}, "effect": {"wand_cooldown": 0.15}},
		{"id": "mg_s4", "branch": 0, "name": "Arcane Surge", "desc": "-20% wand cooldown", "tier": 4, "cost": 3, "prereq": "mg_s3", "materials": {"iron_shard": 3}, "effect": {"wand_cooldown": 0.20}},
		{"id": "mg_s5", "branch": 0, "name": "Archmage", "desc": "-30% wand cooldown, +20 max health", "tier": 5, "cost": 5, "prereq": "mg_s4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"wand_cooldown": 0.30, "max_health": 20.0}},
		# Knowledge -- XP and learning
		{"id": "mg_k1", "branch": 1, "name": "Scholar", "desc": "+10% XP from kills", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"xp_gain": 0.10}},
		{"id": "mg_k2", "branch": 1, "name": "Studious", "desc": "+15% XP from kills", "tier": 2, "cost": 1, "prereq": "mg_k1", "materials": {}, "effect": {"xp_gain": 0.15}},
		{"id": "mg_k3", "branch": 1, "name": "Researcher", "desc": "+20% XP from kills", "tier": 3, "cost": 2, "prereq": "mg_k2", "materials": {"slime": 2}, "effect": {"xp_gain": 0.20}},
		{"id": "mg_k4", "branch": 1, "name": "Sage", "desc": "+25% XP from kills", "tier": 4, "cost": 3, "prereq": "mg_k3", "materials": {"iron_shard": 2, "ember_crystal": 1}, "effect": {"xp_gain": 0.25}},
		{"id": "mg_k5", "branch": 1, "name": "Omniscient", "desc": "+35% XP, +15% gold", "tier": 5, "cost": 5, "prereq": "mg_k4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"xp_gain": 0.35, "gold_gain": 0.15}},
		# Vitality -- survival and mobility
		{"id": "mg_v1", "branch": 2, "name": "Arcane Ward", "desc": "+10 max health", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"max_health": 10.0}},
		{"id": "mg_v2", "branch": 2, "name": "Mana Shield", "desc": "+15 max health", "tier": 2, "cost": 1, "prereq": "mg_v1", "materials": {}, "effect": {"max_health": 15.0}},
		{"id": "mg_v3", "branch": 2, "name": "Blink Step", "desc": "+10% move speed", "tier": 3, "cost": 2, "prereq": "mg_v2", "materials": {"slime": 2}, "effect": {"move_speed": 0.10}},
		{"id": "mg_v4", "branch": 2, "name": "Fortified Mind", "desc": "+25 max health", "tier": 4, "cost": 3, "prereq": "mg_v3", "materials": {"iron_shard": 3}, "effect": {"max_health": 25.0}},
		{"id": "mg_v5", "branch": 2, "name": "Ascendant", "desc": "+30 max health, +10% move speed", "tier": 5, "cost": 5, "prereq": "mg_v4", "materials": {"void_essence": 2, "ancient_relic": 1}, "effect": {"max_health": 30.0, "move_speed": 0.10}},
	],
	# Unlockable only after finishing the game (no ending exists yet) -- shown
	# as a locked teaser: one shadowy root and three unknown branches.
	"Necromancer": [
		{"id": "nc_root", "branch": -1, "name": "Death's Pact", "desc": "???", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {}},
		{"id": "nc_b1", "branch": 0, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
		{"id": "nc_b2", "branch": 1, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
		{"id": "nc_b3", "branch": 2, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
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
