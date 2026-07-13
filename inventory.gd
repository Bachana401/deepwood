class_name Inventory
extends RefCounted

# Shared item catalog -- every item type in the game (currency included) is
# defined here so both the player's inventory and any chest's inventory read
# from the same source. gold/silver/bronze are independent items with no
# fixed conversion rate between them -- only coin_gold drives the shop,
# death-drop, and passive income (see player.gd's currency property). Future
# gear/skill-material items get added here too, not as special cases elsewhere.
# Every item declares a "category": currency / material / armor / relic /
# weapon. armor & relic items carry an "equip_effect" dict (stat bonuses
# folded into GameState.get_bonus_total once equipped); armor also has a
# "slot" (helmet/chest/pants). "weapon" items here are the classless
# "Excellent" weapons (excellent=true) -- equipped via the gear panel and
# used on key 5, they trade skill-tree stat scaling for a one-of-a-kind
# "unique_effect" (see player.gd). The base sword/spear/bow/wand are NOT
# items -- they stay the purchasable 1-4 kit.
const ITEM_DEFS = {
	"coin_gold": {"name": "Gold Coin", "category": "currency", "max_stack": 999, "color": Color(1.0, 0.85, 0.2, 1.0)},
	"coin_silver": {"name": "Silver Coin", "category": "currency", "max_stack": 999, "color": Color(0.78, 0.8, 0.84, 1.0)},
	"coin_bronze": {"name": "Bronze Coin", "category": "currency", "max_stack": 999, "color": Color(0.72, 0.45, 0.22, 1.0)},
	# Skill-tree materials, dropped rarely in the dungeon by level bracket
	# (see dungeon_interior.gd) -- their names stay hidden ("Unknown
	# Substance") until researched at the Science Lab, see
	# GameState.researched_materials and get_display_name() below.
	"slime": {"name": "Slime", "category": "material", "max_stack": 99, "color": Color(0.35, 0.75, 0.35, 1.0), "is_material": true},
	"iron_shard": {"name": "Iron Shard", "category": "material", "max_stack": 99, "color": Color(0.6, 0.62, 0.68, 1.0), "is_material": true},
	"ember_crystal": {"name": "Ember Crystal", "category": "material", "max_stack": 99, "color": Color(0.95, 0.45, 0.15, 1.0), "is_material": true},
	"void_essence": {"name": "Void Essence", "category": "material", "max_stack": 99, "color": Color(0.4, 0.2, 0.6, 1.0), "is_material": true},
	"ancient_relic": {"name": "Ancient Relic", "category": "material", "max_stack": 99, "color": Color(0.85, 0.75, 0.4, 1.0), "is_material": true},
	# --- Construction materials: gathered from enemies (low drop rate) and used
	# to repair ruined village buildings (see building.gd). Plainly named, NOT
	# research-gated like the skill-tree substances above (no "is_material").
	"wood": {"name": "Wood", "category": "material", "max_stack": 99, "color": Color(0.52, 0.34, 0.18, 1.0), "is_construction": true},
	"stone": {"name": "Stone", "category": "material", "max_stack": 99, "color": Color(0.6, 0.6, 0.63, 1.0), "is_construction": true},
	"resin": {"name": "Resin", "category": "material", "max_stack": 99, "color": Color(0.88, 0.62, 0.22, 1.0), "is_construction": true},
	# --- Armor (the "Leather" set; dungeon loot will add more later) ---
	"helm_leather": {"name": "Leather Helm", "category": "armor", "slot": "helmet", "set": "leather", "max_stack": 1, "color": Color(0.55, 0.4, 0.25, 1.0), "equip_effect": {"max_health": 15.0}},
	"armor_leather": {"name": "Leather Vest", "category": "armor", "slot": "chest", "set": "leather", "max_stack": 1, "color": Color(0.5, 0.36, 0.22, 1.0), "equip_effect": {"max_health": 25.0}},
	"pants_leather": {"name": "Leather Pants", "category": "armor", "slot": "pants", "set": "leather", "max_stack": 1, "color": Color(0.45, 0.32, 0.2, 1.0), "equip_effect": {"max_health": 10.0, "move_speed": 0.04}},
	# --- Class armor sets. Each one leans into a class's skill tree (Bulwark =
	# Sword's Might/Endurance/Frenzy, Windstalker = Archer's Precision/Agility/
	# Plunder, Runeweave = Mage's Spellcraft/Vitality + the mana pool). Wearing
	# all 3 pieces grants the set bonus; ALSO wielding the set's weapon stacks
	# the greater full_bonus on top (see SET_DEFS + GameState set logic). ---
	"helm_bulwark": {"name": "Bulwark Warhelm", "category": "armor", "slot": "helmet", "set": "bulwark", "max_stack": 1, "color": Color(0.66, 0.3, 0.2, 1.0), "equip_effect": {"max_health": 25.0, "melee_damage": 0.05}},
	"armor_bulwark": {"name": "Bulwark Breastplate", "category": "armor", "slot": "chest", "set": "bulwark", "max_stack": 1, "color": Color(0.58, 0.26, 0.17, 1.0), "equip_effect": {"max_health": 40.0}},
	"pants_bulwark": {"name": "Bulwark Greaves", "category": "armor", "slot": "pants", "set": "bulwark", "max_stack": 1, "color": Color(0.5, 0.23, 0.15, 1.0), "equip_effect": {"max_health": 20.0, "melee_cooldown": 0.05}},
	"helm_windstalker": {"name": "Windstalker Hood", "category": "armor", "slot": "helmet", "set": "windstalker", "max_stack": 1, "color": Color(0.3, 0.62, 0.32, 1.0), "equip_effect": {"bow_damage": 0.08}},
	"armor_windstalker": {"name": "Windstalker Cloak", "category": "armor", "slot": "chest", "set": "windstalker", "max_stack": 1, "color": Color(0.26, 0.55, 0.28, 1.0), "equip_effect": {"max_health": 10.0, "move_speed": 0.06}},
	"pants_windstalker": {"name": "Windstalker Striders", "category": "armor", "slot": "pants", "set": "windstalker", "max_stack": 1, "color": Color(0.22, 0.48, 0.25, 1.0), "equip_effect": {"move_speed": 0.05, "bow_cooldown": 0.05}},
	"helm_runeweave": {"name": "Runeweave Circlet", "category": "armor", "slot": "helmet", "set": "runeweave", "max_stack": 1, "color": Color(0.55, 0.4, 0.88, 1.0), "equip_effect": {"max_mana": 20.0, "xp_gain": 0.08}},
	"armor_runeweave": {"name": "Runeweave Robe", "category": "armor", "slot": "chest", "set": "runeweave", "max_stack": 1, "color": Color(0.48, 0.34, 0.8, 1.0), "equip_effect": {"max_mana": 25.0, "max_health": 15.0}},
	"pants_runeweave": {"name": "Runeweave Leggings", "category": "armor", "slot": "pants", "set": "runeweave", "max_stack": 1, "color": Color(0.42, 0.3, 0.72, 1.0), "equip_effect": {"max_mana": 15.0, "wand_cooldown": 0.06}},
	# --- Relics ---
	"relic_vigor": {"name": "Relic of Vigor", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.25, 0.3, 1.0), "equip_effect": {"max_health": 30.0}},
	"relic_swiftness": {"name": "Relic of Swiftness", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.3, 0.8, 0.85, 1.0), "equip_effect": {"move_speed": 0.10}},
	"relic_greed": {"name": "Relic of Greed", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.75, 0.2, 1.0), "equip_effect": {"gold_gain": 0.20}},
	"relic_wisdom": {"name": "Relic of Wisdom", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.55, 0.9, 1.0), "equip_effect": {"xp_gain": 0.20}},
	# Class-aligned relics (one per tree) + the mana wellspring.
	"relic_berserker": {"name": "Relic of the Berserker", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.8, 0.2, 0.12, 1.0), "equip_effect": {"melee_damage": 0.10, "melee_cooldown": 0.05}},
	"relic_hawk": {"name": "Relic of the Hawk", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.35, 0.7, 0.3, 1.0), "equip_effect": {"bow_damage": 0.10, "bow_cooldown": 0.05}},
	"relic_archon": {"name": "Relic of the Archon", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.4, 0.95, 1.0), "equip_effect": {"wand_cooldown": 0.08, "max_mana": 20.0}},
	"relic_wellspring": {"name": "Relic of the Wellspring", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.25, 0.55, 0.95, 1.0), "equip_effect": {"max_mana": 25.0, "mana_regen": 0.5}},
	# Gathering-exclusive relics: never drop in the dungeon -- rare finds while
	# mining rocks (Mountain) or felling trees (Sylvan). See harvest_node.gd.
	"relic_mountain": {"name": "Heart of the Mountain", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.55, 0.5, 0.6, 1.0), "equip_effect": {"max_health": 30.0, "gold_gain": 0.10}},
	"relic_sylvan": {"name": "Sylvan Charm", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.4, 0.75, 0.4, 1.0), "equip_effect": {"move_speed": 0.08, "xp_gain": 0.10}},
	# Movement/utility relics with boolean-flag effects (flight, fall_immunity):
	# the value is just a 1.0 marker read via GameState.get_bonus_total > 0 in
	# player.gd. Aetherwing grants FLIGHT (hold Space -- 10s budget) and also
	# negates fall damage; the Featherfall Charm only negates fall damage.
	"relic_wings": {"name": "Aetherwing", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.9, 1.0, 1.0), "equip_effect": {"flight": 1.0, "fall_immunity": 1.0, "move_speed": 0.05}},
	"relic_feather": {"name": "Featherfall Charm", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.95, 0.85, 1.0), "equip_effect": {"fall_immunity": 1.0, "max_health": 10.0}},
	# --- Weapons. Every weapon is an inventory item now; you wield one by
	# selecting its inventory slot with the hotbar keys (1-9, 0). "weapon_type"
	# tells the player how it attacks: melee / spear / bow / wand. The Excellent
	# ones are just melee weapons that also carry a "unique_effect". ---
	"wpn_sword": {
		"name": "Sword", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.75, 0.75, 0.8, 1.0),
		"weapon_stats": {"damage": 8, "cooldown": 0.3, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.75, 0.75, 0.8), "icon_offset": 20.0},
	},
	"wpn_spear": {
		"name": "Spear", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.55, 0.35, 0.15, 1.0),
		"weapon_stats": {"damage": 24, "cooldown": 0.9, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 60.0, "knockback_max": 90.0, "icon_size": Vector2(114, 8), "icon_color": Color(0.55, 0.35, 0.15), "icon_offset": 16.0},
	},
	"wpn_bow": {
		"name": "Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.45, 0.28, 0.1, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.5, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.45, 0.28, 0.1), "icon_offset": 18.0},
	},
	"wpn_wand": {
		"name": "Magic Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.65, 0.2, 0.85, 1.0), "mana_cost": 30,
		"weapon_stats": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.65, 0.2, 0.85), "icon_offset": 20.0},
		"unique_desc": "Obliterates every enemy on screen.",
	},
	# --- Set weapons: the 4th piece of each class set. Wielding one while the
	# 3 armor pieces are worn stacks the set's full_bonus on top. ---
	"wpn_claymore": {
		"name": "Bulwark Claymore", "category": "weapon", "weapon_type": "melee", "set": "bulwark", "max_stack": 1, "color": Color(0.85, 0.45, 0.3, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.45, "range_offset": 50, "area_size": Vector2(68, 40), "knockback_min": 45.0, "knockback_max": 80.0, "icon_size": Vector2(62, 13), "icon_color": Color(0.85, 0.5, 0.35), "icon_offset": 20.0},
	},
	"wpn_recurve": {
		"name": "Windstalker Recurve", "category": "weapon", "weapon_type": "bow", "set": "windstalker", "max_stack": 1, "color": Color(0.3, 0.6, 0.3, 1.0),
		"weapon_stats": {"damage": 19, "cooldown": 0.42, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 26.0, "knockback_max": 50.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.3, 0.6, 0.3), "icon_offset": 18.0},
	},
	"wpn_scepter": {
		"name": "Runeweave Scepter", "category": "weapon", "weapon_type": "wand", "set": "runeweave", "max_stack": 1, "color": Color(0.52, 0.36, 0.92, 1.0), "mana_cost": 20,
		"weapon_stats": {"damage": 0, "cooldown": 0.8, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.52, 0.36, 0.92), "icon_offset": 20.0},
		"unique_desc": "Obliterates every enemy on screen -- woven runes cut its mana cost.",
	},
	# --- Class variant weapons: each has a "special" attack handled by
	# player.gd (projectiles live in weapon_projectile.gd). They scale with
	# their class's skill tree exactly like the basic kit: melee/spear specials
	# with melee_damage, arrows with bow_damage, wand projectiles with the
	# Mage tree's wand_damage. Dungeon boss loot from L10 (dungeon_interior).
	"wpn_windcutter": {
		"name": "Windcutter", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.7, 0.92, 1.0, 1.0),
		"weapon_stats": {"damage": 11, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 28.0, "knockback_max": 55.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.7, 0.92, 1.0), "icon_offset": 20.0},
		"special": {"type": "flying_slash", "damage": 10, "speed": 520.0, "range": 420.0},
		"unique_desc": "Every swing also hurls a slash of wind that flies ahead, cutting through everyone in its path.",
	},
	"wpn_sunderer": {
		"name": "Sunderer", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.8, 0.5, 0.25, 1.0),
		"weapon_stats": {"damage": 20, "cooldown": 0.85, "range_offset": 52, "area_size": Vector2(74, 44), "knockback_min": 55.0, "knockback_max": 95.0, "icon_size": Vector2(58, 15), "icon_color": Color(0.8, 0.5, 0.25), "icon_offset": 20.0},
		"special": {"type": "cleave"},
		"unique_desc": "So heavy it cleaves through EVERY enemy in the arc, not just the nearest.",
	},
	"wpn_stormlance": {
		"name": "Stormlance", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.85, 0.8, 0.5, 1.0),
		"weapon_stats": {"damage": 10, "cooldown": 1.0, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 40.0, "knockback_max": 70.0, "icon_size": Vector2(110, 8), "icon_color": Color(0.85, 0.8, 0.5), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 3, "spread_deg": 10.0, "damage": 10, "speed": 700.0, "range": 520.0},
		"unique_desc": "Instead of thrusting, conjures 3 spectral javelins and hurls them all at once -- they pierce clean through.",
	},
	"wpn_stormvolley": {
		"name": "Stormvolley Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.55, 0.42, 0.7, 1.0),
		"weapon_stats": {"damage": 9, "cooldown": 0.6, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 22.0, "knockback_max": 44.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.55, 0.42, 0.7), "icon_offset": 18.0},
		"special": {"type": "multi_shot", "count": 3, "spread_deg": 12.0},
		"unique_desc": "Looses a fan of 3 arrows with every draw.",
	},
	"wpn_seeker": {
		"name": "Seeker Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.3, 0.75, 0.55, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.55, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.3, 0.75, 0.55), "icon_offset": 18.0},
		"special": {"type": "homing"},
		"unique_desc": "Its enchanted arrows bend mid-flight, hunting the nearest enemy on their own.",
	},
	"wpn_emberstaff": {
		"name": "Emberstaff", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.95, 0.5, 0.15, 1.0), "mana_cost": 12,
		"weapon_stats": {"damage": 0, "cooldown": 0.7, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.95, 0.5, 0.15), "icon_offset": 20.0},
		"special": {"type": "fireball", "damage": 24, "aoe": 110.0, "speed": 460.0, "range": 600.0},
		"unique_desc": "Launches a fireball that detonates on impact, scorching everything within 110px.",
	},
	"wpn_iciclewand": {
		"name": "Icicle Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.85, 1.0, 1.0), "mana_cost": 8,
		"weapon_stats": {"damage": 0, "cooldown": 0.5, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.6, 0.85, 1.0), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 14, "speed": 640.0, "range": 560.0, "pierce": true},
		"unique_desc": "Fires a razor icicle that skewers every enemy along its line.",
	},
	# --- Admin test wand (dev only, granted with the starter kit, hotbar 7).
	# RIGHT-click, no aiming: sears 5% of MAX HP off every enemy within 280px,
	# ignoring all scaling -- so ~20 casts fell ANYTHING, sized exactly for
	# walking a final boss through all of its phases. Costs no mana.
	"wpn_admin_ruin": {
		"name": "Ruin Wand (Admin)", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.9, 0.2, 0.25, 1.0), "mana_cost": 0,
		"weapon_stats": {"damage": 0, "cooldown": 0.4, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.9, 0.2, 0.25), "icon_offset": 20.0},
		"special": {"type": "percent_burst", "percent": 0.05, "radius": 280.0},
		"unique_desc": "ADMIN: right-click (no aim needed) to sear 5% of MAX HP off every enemy within 280px. 20 casts fell anything.",
	},
	# --- Gathering tools: wielded from the hotbar like any weapon. Weak in a
	# fight, but swinging one at a matching harvest node (tree/rock -- see
	# harvest_node.gd) gathers materials. tool_type gates which node it works on.
	"tool_axe": {
		"name": "Woodsman's Axe", "category": "weapon", "weapon_type": "melee", "tool_type": "axe", "max_stack": 1, "color": Color(0.72, 0.5, 0.3, 1.0),
		"weapon_stats": {"damage": 5, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(40, 10), "icon_color": Color(0.6, 0.42, 0.24), "icon_offset": 18.0},
		"unique_desc": "Chops trees for Wood and Resin.",
	},
	"tool_pickaxe": {
		"name": "Miner's Pickaxe", "category": "weapon", "weapon_type": "melee", "tool_type": "pickaxe", "max_stack": 1, "color": Color(0.6, 0.6, 0.66, 1.0),
		"weapon_stats": {"damage": 5, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(40, 10), "icon_color": Color(0.55, 0.55, 0.6), "icon_offset": 18.0},
		"unique_desc": "Mines rocks for Stone and rare minerals.",
	},
	# --- Excellent weapons (classless, unique effects, no skill scaling) ---
	"exc_vampiric": {
		"name": "Vampiric Fang", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.7, 0.1, 0.2, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.4, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.7, 0.1, 0.2), "icon_offset": 20.0},
		"unique_effect": "lifesteal", "unique_value": 0.35,
		"unique_desc": "Heals you for 35% of the melee damage it deals.",
	},
	"exc_thunder": {
		"name": "Thundercaller", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.4, 0.6, 1.0, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.5, "range_offset": 50, "area_size": Vector2(66, 38), "knockback_min": 35.0, "knockback_max": 65.0, "icon_size": Vector2(56, 12), "icon_color": Color(0.4, 0.6, 1.0), "icon_offset": 20.0},
		"unique_effect": "chain", "unique_value": 12, "unique_radius": 150.0,
		"unique_desc": "Each hit also zaps every enemy within 150px for 12 damage.",
	},
	"exc_midas": {
		"name": "Midas Edge", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.95, 0.78, 0.2, 1.0),
		"weapon_stats": {"damage": 10, "cooldown": 0.35, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.95, 0.78, 0.2), "icon_offset": 20.0},
		"unique_effect": "gold_touch", "unique_value": 0.5,
		"unique_desc": "Turns pain into profit: each hit grants gold worth 50% of the damage dealt.",
	},
	"exc_echo": {
		"name": "Echo Rift", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.4, 0.85, 0.9, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.45, "range_offset": 48, "area_size": Vector2(64, 38), "knockback_min": 32.0, "knockback_max": 62.0, "icon_size": Vector2(54, 12), "icon_color": Color(0.4, 0.85, 0.9), "icon_offset": 20.0},
		"unique_effect": "echo", "unique_value": 1.0,
		"unique_desc": "Every 3rd strike tears open a rift that repeats the blow's full damage.",
	},
	"exc_soul": {
		"name": "Soulthirst", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.45, 0.3, 0.9, 1.0),
		"weapon_stats": {"damage": 11, "cooldown": 0.4, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.55, 0.38, 0.95), "icon_offset": 20.0},
		"unique_effect": "manasteal", "unique_value": 12,
		"unique_desc": "Drinks the struck foe's spirit: restores 12 Mana per hit.",
	},
	"exc_hook": {
		"name": "Leviathan Hook", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.55, 0.65, 0.72, 1.0),
		"weapon_stats": {"damage": 8, "cooldown": 0.8, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(44, 12), "icon_color": Color(0.6, 0.68, 0.75), "icon_offset": 20.0},
		"special": {"type": "hook", "damage": 8, "speed": 780.0, "range": 420.0},
		"unique_desc": "Hurls a barbed hook on a rope -- the first enemy struck is DRAGGED to your feet.",
	},
	"exc_boomerang": {
		"name": "Galewing Glaive", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.35, 0.8, 0.75, 1.0),
		"weapon_stats": {"damage": 11, "cooldown": 0.9, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 26.0, "knockback_max": 50.0, "icon_size": Vector2(46, 12), "icon_color": Color(0.35, 0.8, 0.75), "icon_offset": 20.0},
		"special": {"type": "boomerang", "damage": 11, "speed": 520.0, "range": 380.0},
		"unique_desc": "A whirling glaive that flies out and RETURNS -- striking every enemy on both passes.",
	},
	"exc_chrono": {
		"name": "Chrono Edge", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.9, 0.85, 0.45, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.9, 0.85, 0.45), "icon_offset": 20.0},
		"unique_effect": "chrono", "unique_value": 0.25,
		"unique_desc": "Each hit has a 25% chance to rewind time, instantly resetting your attack cooldown.",
	},
	# The boss-killer: a rune-etched greatblade forged to end the Fallen Wizard.
	# Deals +150% damage to BOSSES (and their echoes) -- which also punches
	# through the Wizard's Soul Ward -- and drinks 8 Mana on every hit so you can
	# keep flying and casting through the long fight. Rare deep-dungeon drop.
	"exc_wizardsbane": {
		"name": "Wizardsbane", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.85, 0.9, 0.75, 1.0),
		"weapon_stats": {"damage": 22, "cooldown": 0.45, "range_offset": 52, "area_size": Vector2(70, 40), "knockback_min": 40.0, "knockback_max": 75.0, "icon_size": Vector2(64, 14), "icon_color": Color(0.88, 0.92, 0.72), "icon_offset": 20.0},
		"unique_effect": "bossbane", "unique_value": 1.5, "mana_on_hit": 8,
		"unique_desc": "Forged to slay the undying: +150% damage to bosses (cuts their wards), and drinks 8 Mana on every hit.",
	},
	# The showpiece: a builder-into-ultimate greatblade. Every hit throws a
	# flying slash AND charges the storm; the 8th hit ERUPTS -- a 12-way slash
	# nova, a meteor barrage, and a shockwave. A screen-clearing spectacle.
	"exc_ragnarok": {
		"name": "Ragnarok Blade", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(1.0, 0.55, 0.15, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.4, "range_offset": 50, "area_size": Vector2(66, 40), "knockback_min": 35.0, "knockback_max": 70.0, "icon_size": Vector2(60, 13), "icon_color": Color(1.0, 0.6, 0.2), "icon_offset": 20.0},
		"unique_effect": "ragnarok", "unique_value": 8,
		"unique_desc": "Every strike hurls a slash and stokes the storm; every 8th strike erupts into a 12-way slash nova, a meteor barrage, and a shockwave.",
	},
}

# Materials masquerade as "Unknown Substance" until the Science Lab has
# researched that type -- the lookup lives here so every UI (inventory,
# skill tree, notifications) shows the same thing.
static func get_display_name(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		return "Unknown Substance"
	return def.get("name", item_id)

# Item sets. Wearing every armor piece of a set at once grants its "bonus"
# (checked via GameState.is_set_complete / folded into GameState.
# get_bonus_total). A set may also name a "weapon": WIELDING it (hotbar) while
# the armor set is complete stacks the greater "full_bonus" on top -- so a
# full 4-piece class set pays out both tiers at once.
const SET_DEFS = {
	"leather": {
		"name": "Leather Set",
		"pieces": ["helm_leather", "armor_leather", "pants_leather"],
		"bonus": {"max_health": 20.0, "move_speed": 0.05},
		"bonus_desc": "+20 Max HP, +5% Move Speed",
	},
	"bulwark": {
		"name": "Bulwark of the Warlord",
		"pieces": ["helm_bulwark", "armor_bulwark", "pants_bulwark"],
		"bonus": {"max_health": 35.0, "melee_damage": 0.10},
		"bonus_desc": "+35 Max HP, +10% Melee DMG",
		"weapon": "wpn_claymore",
		"full_bonus": {"melee_damage": 0.15, "melee_cooldown": 0.10, "max_health": 25.0},
		"full_bonus_desc": "+15% Melee DMG, -10% Melee CD, +25 Max HP",
	},
	"windstalker": {
		"name": "Windstalker's Garb",
		"pieces": ["helm_windstalker", "armor_windstalker", "pants_windstalker"],
		"bonus": {"bow_damage": 0.12, "move_speed": 0.08},
		"bonus_desc": "+12% Bow DMG, +8% Move Speed",
		"weapon": "wpn_recurve",
		"full_bonus": {"bow_damage": 0.15, "bow_cooldown": 0.12, "gold_gain": 0.15},
		"full_bonus_desc": "+15% Bow DMG, -12% Bow CD, +15% Gold",
	},
	"runeweave": {
		"name": "Runeweave Vestments",
		"pieces": ["helm_runeweave", "armor_runeweave", "pants_runeweave"],
		"bonus": {"max_mana": 30.0, "mana_regen": 0.5},
		"bonus_desc": "+30 Max Mana, +50% Mana Regen",
		"weapon": "wpn_scepter",
		"full_bonus": {"wand_cooldown": 0.15, "max_mana": 40.0, "mana_regen": 0.5},
		"full_bonus_desc": "-15% Wand CD, +40 Max Mana, +50% Mana Regen",
	},
}

const CATEGORY_LABELS = {
	"currency": "Currency", "material": "Material", "armor": "Armor",
	"relic": "Relic", "weapon": "Weapon", "misc": "Item",
}
const EFFECT_LABELS = {
	"max_health": "Max HP", "move_speed": "Move Speed", "gold_gain": "Gold",
	"xp_gain": "XP", "melee_damage": "Melee DMG", "bow_damage": "Bow DMG",
	"melee_cooldown": "Melee CD", "bow_cooldown": "Bow CD", "wand_cooldown": "Wand CD",
	"max_mana": "Max Mana", "mana_regen": "Mana Regen", "wand_damage": "Wand DMG",
}
# Cooldown effects REDUCE the cooldown, so their lines read "-12% Bow CD".
const COOLDOWN_EFFECT_KEYS = ["melee_cooldown", "bow_cooldown", "wand_cooldown"]
# Boolean-flag effects: shown as a plain phrase, not a "+N%" stat line.
const FLAG_EFFECT_TEXT = {
	"flight": "Flight: hold Space to soar (10s)",
	"fall_immunity": "Negates fall damage",
}

static func get_set(item_id: String) -> String:
	return get_item_def(item_id).get("set", "")

# Multi-line hover description used by the shared item tooltip (item_tooltip.gd)
# in the inventory, chest, and equipment panels.
static func build_tooltip_text(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.is_empty():
		return item_id
	var lines = []
	lines.append(get_display_name(item_id))
	var cat = get_category(item_id)
	var cat_line = CATEGORY_LABELS.get(cat, "Item")
	if cat == "armor":
		cat_line += " · " + _slot_word(def.get("slot", ""))
	elif cat == "weapon":
		cat_line += " · " + str(def.get("weapon_type", "")).capitalize()
		if def.get("excellent", false):
			cat_line += " · Excellent"
	lines.append(cat_line)

	var set_id = get_set(item_id)
	if set_id != "" and SET_DEFS.has(set_id):
		var sd = SET_DEFS[set_id]
		var have = GameStateRef().set_pieces_equipped(set_id)
		lines.append("Set: %s (%d/%d worn)" % [sd.name, have, sd.pieces.size()])

	if cat == "weapon":
		var ws = def.get("weapon_stats", {})
		if not ws.is_empty():
			var stat_line = "DMG %d · CD %.2fs" % [int(ws.get("damage", 0)), ws.get("cooldown", 0.0)]
			if def.has("mana_cost"):
				stat_line += " · %d Mana" % int(def.mana_cost)
			lines.append(stat_line)
		if def.has("unique_desc"):
			lines.append("Unique: " + def.unique_desc)
		lines.append("Wield from your hotbar (keys 1-0).")
	else:
		for key in def.get("equip_effect", {}).keys():
			lines.append(_effect_line(key, def.equip_effect[key]))

	if set_id != "" and SET_DEFS.has(set_id):
		lines.append("Set bonus (3 armor): " + SET_DEFS[set_id].bonus_desc)
		if SET_DEFS[set_id].has("weapon"):
			var wpn_name = get_item_def(SET_DEFS[set_id].weapon).get("name", "set weapon")
			lines.append("+ wield %s: %s" % [wpn_name, SET_DEFS[set_id].get("full_bonus_desc", "")])

	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		lines.append("Unidentified -- research it at the Science Lab.")
	return "\n".join(lines)

static func _slot_word(slot: String) -> String:
	match slot:
		"helmet": return "Helmet"
		"chest": return "Chest"
		"pants": return "Legs"
	return slot.capitalize()

static func _effect_line(key: String, val) -> String:
	if FLAG_EFFECT_TEXT.has(key):
		return FLAG_EFFECT_TEXT[key]
	var label = EFFECT_LABELS.get(key, key.replace("_", " ").capitalize())
	if key == "max_health" or key == "max_mana":
		return "+%d %s" % [int(val), label]
	if key in COOLDOWN_EFFECT_KEYS:
		return "-%d%% %s" % [int(round(val * 100)), label]
	return "+%d%% %s" % [int(round(val * 100)), label]

static func get_category(item_id: String) -> String:
	return get_item_def(item_id).get("category", "misc")

# Weapons are NOT gear-equippable anymore -- they're wielded from the hotbar
# (see player.gd). Only armor and relics go in the gear panel.
static func is_equippable(item_id: String) -> bool:
	return get_category(item_id) in ["armor", "relic"]

# Which equipment slot an item goes in: "helmet"/"chest"/"pants" for armor,
# "relic" for relics, "weapon" for excellent weapons.
static func get_equip_slot(item_id: String) -> String:
	return get_item_def(item_id).get("slot", "")

static func GameStateRef() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")

# ---------------------------------------------------------------------------
# Procedural item icons. Instead of a flat coloured square, each item draws a
# little symbol that hints at its name -- a sword looks like a sword, a coin
# like a coin, wood like a log. `target` is the slot's icon ColorRect used by
# inventory_ui / hotbar_ui / chest_ui; the symbol is painted as its children.
# A stopgap until real art (art/weapon_*.png ...) replaces these. Cheap to call
# every frame: it no-ops unless the slot's item actually changed.
# ---------------------------------------------------------------------------
static func paint_icon(target: ColorRect, item_id: String) -> void:
	if str(target.get_meta("painted_id", "￿")) == item_id:
		return
	target.set_meta("painted_id", item_id)
	for c in target.get_children():
		target.remove_child(c)
		c.queue_free()
	target.color = Color(0, 0, 0, 0)   # transparent tile; the symbol carries colour
	if item_id == "":
		return

	var w = target.size.x
	var h = target.size.y
	var col: Color = get_item_def(item_id).get("color", Color.WHITE)
	match item_id:
		"wpn_sword": _icon_sword(target, w, h, Color(0.82, 0.85, 0.9), Color(0.85, 0.68, 0.25))
		"exc_thunder": _icon_thunder(target, w, h)
		"exc_vampiric": _icon_fang(target, w, h)
		"wpn_spear": _icon_spear(target, w, h)
		"wpn_bow": _icon_bow(target, w, h)
		"wpn_wand": _icon_wand(target, w, h)
		"tool_axe": _icon_axe(target, w, h)
		"tool_pickaxe": _icon_pickaxe(target, w, h)
		"exc_hook": _icon_hook(target, w, h)
		"exc_boomerang": _icon_boomerang(target, w, h)
		"exc_wizardsbane": _icon_runeblade(target, w, h)
		"exc_ragnarok": _icon_ragnarok(target, w, h)
		"relic_wings", "relic_feather": _icon_wing(target, w, h, get_item_def(item_id).get("color", Color.WHITE))
		"coin_gold", "coin_silver", "coin_bronze": _icon_coin(target, w, h, col)
		"wood": _icon_wood(target, w, h)
		"stone": _icon_stone(target, w, h)
		"resin": _icon_resin(target, w, h)
		_:
			if get_category(item_id) == "relic":
				_icon_gem(target, w, h, col)
			elif get_category(item_id) == "weapon":
				# any weapon without a bespoke icon draws by its type, tinted
				# to the item colour (set weapons, new Excellents, ...)
				match get_item_def(item_id).get("weapon_type", "melee"):
					"bow": _icon_bow(target, w, h)
					"wand": _icon_wand(target, w, h)
					"spear": _icon_spear(target, w, h)
					_: _icon_blade(target, w, h, col, col.darkened(0.35))
			else:
				target.color = col   # armour / research mats keep the coloured tile

# --- tiny drawing primitives (children of the icon ColorRect) ---
static func _ipoly(t: Control, pts: PackedVector2Array, color: Color) -> void:
	var p = Polygon2D.new(); p.polygon = pts; p.color = color; t.add_child(p)
static func _irect(t: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var r = ColorRect.new(); r.position = pos; r.size = size; r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.add_child(r)
static func _iline(t: Control, pts: PackedVector2Array, width: float, color: Color) -> void:
	var l = Line2D.new(); l.points = pts; l.width = width; l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND; t.add_child(l)
static func _icircle(t: Control, c: Vector2, rad: float, color: Color, sides := 16) -> void:
	var pts = PackedVector2Array()
	for i in range(sides):
		var a = TAU * float(i) / sides
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	_ipoly(t, pts, color)

# --- per-item symbols (drawn in the target's 0..w / 0..h local space) ---
static func _icon_blade(t: Control, w: float, h: float, steel: Color, guard: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.10), Vector2(w * 0.60, h * 0.30),
		Vector2(w * 0.56, h * 0.60), Vector2(w * 0.44, h * 0.60),
		Vector2(w * 0.40, h * 0.30)]), steel)
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.16), Vector2(w * 0.5, h * 0.58)]), max(1.0, w * 0.02), steel.lightened(0.25))
	_irect(t, Vector2(w * 0.28, h * 0.58), Vector2(w * 0.44, h * 0.07), guard)      # crossguard
	_irect(t, Vector2(w * 0.45, h * 0.65), Vector2(w * 0.10, h * 0.20), Color(0.4, 0.28, 0.16))  # grip
	_icircle(t, Vector2(w * 0.5, h * 0.88), w * 0.06, guard)                        # pommel

static func _icon_sword(t: Control, w: float, h: float, steel: Color, guard: Color) -> void:
	_icon_blade(t, w, h, steel, guard)

static func _icon_thunder(t: Control, w: float, h: float) -> void:
	_icon_blade(t, w, h, Color(0.5, 0.72, 1.0), Color(0.55, 0.6, 0.72))
	_iline(t, PackedVector2Array([
		Vector2(w * 0.53, h * 0.16), Vector2(w * 0.44, h * 0.34),
		Vector2(w * 0.56, h * 0.40), Vector2(w * 0.46, h * 0.58)]),
		max(1.2, w * 0.03), Color(0.9, 0.97, 1.0))
	_icircle(t, Vector2(w * 0.5, h * 0.72), w * 0.055, Color(0.35, 0.6, 1.0))       # sapphire

static func _icon_fang(t: Control, w: float, h: float) -> void:
	# a curved crimson fang / dagger
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.52, h * 0.10), Vector2(w * 0.66, h * 0.38),
		Vector2(w * 0.58, h * 0.60), Vector2(w * 0.46, h * 0.58),
		Vector2(w * 0.45, h * 0.34)]), Color(0.72, 0.11, 0.16))
	_iline(t, PackedVector2Array([Vector2(w * 0.53, h * 0.16), Vector2(w * 0.5, h * 0.52)]), max(1.0, w * 0.02), Color(0.95, 0.4, 0.45))
	_irect(t, Vector2(w * 0.3, h * 0.58), Vector2(w * 0.4, h * 0.06), Color(0.3, 0.1, 0.1))
	_icircle(t, Vector2(w * 0.5, h * 0.62), w * 0.16, Color(0.9, 0.1, 0.15, 0.28))  # blood glow
	_ipoly(t, PackedVector2Array([                                                  # ruby
		Vector2(w * 0.5, h * 0.66), Vector2(w * 0.58, h * 0.74),
		Vector2(w * 0.5, h * 0.84), Vector2(w * 0.42, h * 0.74)]), Color(0.95, 0.15, 0.2))

static func _icon_spear(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.28), Vector2(w * 0.08, h * 0.62), Color(0.5, 0.34, 0.18))  # shaft
	_ipoly(t, PackedVector2Array([                                                  # leaf tip
		Vector2(w * 0.5, h * 0.08), Vector2(w * 0.63, h * 0.34),
		Vector2(w * 0.5, h * 0.42), Vector2(w * 0.37, h * 0.34)]), Color(0.82, 0.85, 0.9))
	_irect(t, Vector2(w * 0.43, h * 0.42), Vector2(w * 0.14, h * 0.04), Color(0.35, 0.24, 0.12))  # binding

static func _icon_bow(t: Control, w: float, h: float) -> void:
	_iline(t, PackedVector2Array([                                                  # limb (C arc)
		Vector2(w * 0.64, h * 0.12), Vector2(w * 0.44, h * 0.26),
		Vector2(w * 0.36, h * 0.5), Vector2(w * 0.44, h * 0.74),
		Vector2(w * 0.64, h * 0.88)]), max(1.5, w * 0.06), Color(0.5, 0.34, 0.18))
	_iline(t, PackedVector2Array([Vector2(w * 0.64, h * 0.12), Vector2(w * 0.64, h * 0.88)]), max(1.0, w * 0.02), Color(0.85, 0.85, 0.8))  # string

static func _icon_wand(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.4), Vector2(w * 0.08, h * 0.5), Color(0.42, 0.3, 0.16))  # handle
	_icircle(t, Vector2(w * 0.5, h * 0.28), w * 0.21, Color(0.7, 0.35, 0.95, 0.3))  # glow
	_icircle(t, Vector2(w * 0.5, h * 0.28), w * 0.13, Color(0.72, 0.38, 0.96))      # orb
	_icircle(t, Vector2(w * 0.45, h * 0.23), w * 0.04, Color(1, 1, 1, 0.85))        # highlight

static func _icon_axe(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.2), Vector2(w * 0.09, h * 0.68), Color(0.48, 0.33, 0.18))  # haft
	_ipoly(t, PackedVector2Array([                                                  # axe head
		Vector2(w * 0.5, h * 0.14), Vector2(w * 0.78, h * 0.2),
		Vector2(w * 0.82, h * 0.4), Vector2(w * 0.5, h * 0.42)]), Color(0.78, 0.8, 0.85))
	_iline(t, PackedVector2Array([Vector2(w * 0.78, h * 0.22), Vector2(w * 0.8, h * 0.38)]), max(1.0, w * 0.03), Color(0.95, 0.96, 1.0))  # edge shine

static func _icon_pickaxe(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.18), Vector2(w * 0.09, h * 0.7), Color(0.48, 0.33, 0.18))  # haft
	_ipoly(t, PackedVector2Array([                                                  # curved pick head
		Vector2(w * 0.16, h * 0.3), Vector2(w * 0.5, h * 0.12),
		Vector2(w * 0.84, h * 0.3), Vector2(w * 0.78, h * 0.36),
		Vector2(w * 0.5, h * 0.24), Vector2(w * 0.22, h * 0.36)]), Color(0.72, 0.74, 0.8))

static func _icon_ragnarok(t: Control, w: float, h: float) -> void:
	# a fiery blade ringed by little flame-sparks (the storm it carries)
	_icon_blade(t, w, h, Color(1.0, 0.62, 0.22), Color(0.85, 0.35, 0.1))
	for i in range(5):
		var a = TAU * float(i) / 5.0 - 0.4
		_icircle(t, Vector2(w * 0.5, h * 0.4) + Vector2(cos(a), sin(a)) * w * 0.3, w * 0.035, Color(1.0, 0.75, 0.3, 0.9))

static func _icon_runeblade(t: Control, w: float, h: float) -> void:
	# a pale greatblade with a glowing rune notch -- the Wizardsbane
	_icon_blade(t, w, h, Color(0.9, 0.94, 0.8), Color(0.7, 0.66, 0.4))
	_icircle(t, Vector2(w * 0.5, h * 0.34), w * 0.055, Color(0.6, 1.0, 0.85, 0.9))  # rune glow
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.5)]), max(1.0, w * 0.02), Color(0.85, 1.0, 0.9, 0.7))

static func _icon_hook(t: Control, w: float, h: float) -> void:
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.55)]), max(1.5, w * 0.05), Color(0.55, 0.45, 0.32))  # rope
	var pts = PackedVector2Array()   # J-curve hook
	for i in range(8):
		var a = lerp(-PI * 0.1, PI * 1.05, i / 7.0)
		pts.append(Vector2(w * 0.5, h * 0.62) + Vector2(cos(a), sin(a)) * w * 0.2)
	_iline(t, pts, max(1.8, w * 0.07), Color(0.72, 0.76, 0.82))

static func _icon_wing(t: Control, w: float, h: float, col: Color) -> void:
	# a single feathered wing, tinted to the relic colour
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.28, h * 0.34), Vector2(w * 0.74, h * 0.28),
		Vector2(w * 0.7, h * 0.44), Vector2(w * 0.78, h * 0.46),
		Vector2(w * 0.66, h * 0.58), Vector2(w * 0.74, h * 0.6),
		Vector2(w * 0.56, h * 0.72), Vector2(w * 0.34, h * 0.56)]), col)
	_iline(t, PackedVector2Array([Vector2(w * 0.32, h * 0.4), Vector2(w * 0.66, h * 0.4)]), max(1.0, w * 0.02), col.darkened(0.25))
	_iline(t, PackedVector2Array([Vector2(w * 0.36, h * 0.5), Vector2(w * 0.62, h * 0.5)]), max(1.0, w * 0.02), col.darkened(0.25))

static func _icon_boomerang(t: Control, w: float, h: float) -> void:
	var teal = Color(0.35, 0.8, 0.75)
	_ipoly(t, PackedVector2Array([                                                  # blade 1
		Vector2(w * 0.3, h * 0.68), Vector2(w * 0.42, h * 0.3), Vector2(w * 0.52, h * 0.34),
		Vector2(w * 0.42, h * 0.7)]), teal)
	_ipoly(t, PackedVector2Array([                                                  # blade 2
		Vector2(w * 0.42, h * 0.3), Vector2(w * 0.78, h * 0.42), Vector2(w * 0.74, h * 0.52),
		Vector2(w * 0.46, h * 0.4)]), teal.lightened(0.12))

static func _icon_coin(t: Control, w: float, h: float, col: Color) -> void:
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.34, col.darkened(0.2))
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.27, col)
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.18, col.lightened(0.12))
	_icircle(t, Vector2(w * 0.42, h * 0.42), w * 0.05, Color(1, 1, 1, 0.6))         # shine

static func _icon_wood(t: Control, w: float, h: float) -> void:
	var brown = Color(0.5, 0.34, 0.18)
	_irect(t, Vector2(w * 0.22, h * 0.4), Vector2(w * 0.56, h * 0.28), brown)       # log body
	_icircle(t, Vector2(w * 0.22, h * 0.54), h * 0.14, brown)                       # left end
	_icircle(t, Vector2(w * 0.78, h * 0.54), h * 0.14, brown.lightened(0.1))        # right end (rings)
	_icircle(t, Vector2(w * 0.78, h * 0.54), h * 0.08, brown.darkened(0.15))
	_iline(t, PackedVector2Array([Vector2(w * 0.3, h * 0.44), Vector2(w * 0.7, h * 0.44)]), max(1.0, h * 0.02), brown.darkened(0.2))  # bark

static func _icon_stone(t: Control, w: float, h: float) -> void:
	var grey = Color(0.6, 0.6, 0.63)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.24, h * 0.66), Vector2(w * 0.32, h * 0.4),
		Vector2(w * 0.5, h * 0.32), Vector2(w * 0.68, h * 0.4),
		Vector2(w * 0.78, h * 0.62), Vector2(w * 0.62, h * 0.76),
		Vector2(w * 0.36, h * 0.76)]), grey)
	_ipoly(t, PackedVector2Array([                                                  # top facet
		Vector2(w * 0.32, h * 0.4), Vector2(w * 0.5, h * 0.32),
		Vector2(w * 0.54, h * 0.46), Vector2(w * 0.36, h * 0.5)]), grey.lightened(0.15))

static func _icon_resin(t: Control, w: float, h: float) -> void:
	_ipoly(t, PackedVector2Array([                                                  # amber droplet
		Vector2(w * 0.5, h * 0.16), Vector2(w * 0.63, h * 0.5),
		Vector2(w * 0.6, h * 0.7), Vector2(w * 0.5, h * 0.8),
		Vector2(w * 0.4, h * 0.7), Vector2(w * 0.37, h * 0.5)]), Color(0.88, 0.62, 0.22))
	_icircle(t, Vector2(w * 0.44, h * 0.46), w * 0.05, Color(1, 1, 1, 0.7))         # highlight

static func _icon_gem(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.18), Vector2(w * 0.72, h * 0.44),
		Vector2(w * 0.5, h * 0.82), Vector2(w * 0.28, h * 0.44)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.18), Vector2(w * 0.72, h * 0.44),
		Vector2(w * 0.28, h * 0.44)]), col.lightened(0.22))
	_icircle(t, Vector2(w * 0.42, h * 0.34), w * 0.04, Color(1, 1, 1, 0.7))

const DEFAULT_MAX_STACK = 99

var capacity: int
var slots: Array = []  # each entry: null, or {"item_id": String, "count": int}

func _init(cap: int = 15) -> void:
	capacity = cap
	slots.resize(cap)

static func get_item_def(item_id: String) -> Dictionary:
	return ITEM_DEFS.get(item_id, {})

static func get_max_stack(item_id: String) -> int:
	return get_item_def(item_id).get("max_stack", DEFAULT_MAX_STACK)

func get_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot != null and slot.item_id == item_id:
			total += slot.count
	return total

# Adds up to `count` of item_id: tops up existing partial stacks first, then
# fills empty slots. Returns how much did NOT fit (0 if it all fit).
func add_item(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var remaining = count
	var max_stack = get_max_stack(item_id)
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item_id == item_id and slot.count < max_stack:
			var space = max_stack - slot.count
			var added = min(space, remaining)
			slot.count += added
			remaining -= added
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i] == null:
			var added = min(max_stack, remaining)
			slots[i] = {"item_id": item_id, "count": added}
			remaining -= added
	return remaining

# Removes up to `count` of item_id. If fewer than `count` are available,
# removes nothing and returns false (all-or-nothing, so callers never need
# to reconcile a partial spend).
func remove_item(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if get_count(item_id) < count:
		return false
	var remaining = count
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item_id == item_id:
			var taken = min(slot.count, remaining)
			slot.count -= taken
			remaining -= taken
			if slot.count <= 0:
				slots[i] = null
	return true

# Moves up to `count` of item_id from this inventory into `other`. Returns
# how much was actually moved (may be less than requested if `other` doesn't
# have room, or this inventory doesn't have that much).
func transfer_to(other: Inventory, item_id: String, count: int) -> int:
	var available = min(get_count(item_id), count)
	if available <= 0:
		return 0
	var leftover = other.add_item(item_id, available)
	var moved = available - leftover
	if moved > 0:
		remove_item(item_id, moved)
	return moved

# Drag-and-drop primitive: moves the SPECIFIC stack sitting in from_index
# into to_index (which may be a slot in this same inventory, for reordering,
# or a slot in a different Inventory, for chest<->player transfers). Empty
# destination -> move outright. Same item_id -> merge up to max_stack,
# leaving any remainder behind in the source slot. Different item -> swap
# the two stacks. No-op if the source slot is empty or from==to on self.
func transfer_slot(from_index: int, other: Inventory, to_index: int) -> void:
	if other == self and from_index == to_index:
		return
	var from_slot = slots[from_index]
	if from_slot == null:
		return
	var to_slot = other.slots[to_index]
	if to_slot == null:
		other.slots[to_index] = from_slot
		slots[from_index] = null
	elif to_slot.item_id == from_slot.item_id:
		var max_stack = get_max_stack(from_slot.item_id)
		var space = max_stack - to_slot.count
		var moved = min(space, from_slot.count)
		to_slot.count += moved
		from_slot.count -= moved
		if from_slot.count <= 0:
			slots[from_index] = null
	else:
		slots[from_index] = to_slot
		other.slots[to_index] = from_slot

func to_save_data() -> Array:
	var data = []
	for slot in slots:
		if slot == null:
			data.append(null)
		else:
			data.append({"item_id": slot.item_id, "count": slot.count})
	return data

func from_save_data(data: Array) -> void:
	slots = []
	slots.resize(capacity)
	for i in range(min(data.size(), capacity)):
		var entry = data[i]
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			slots[i] = {"item_id": entry.get("item_id", ""), "count": entry.get("count", 0)}
