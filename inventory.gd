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
	# --- Relics ---
	"relic_vigor": {"name": "Relic of Vigor", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.25, 0.3, 1.0), "equip_effect": {"max_health": 30.0}},
	"relic_swiftness": {"name": "Relic of Swiftness", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.3, 0.8, 0.85, 1.0), "equip_effect": {"move_speed": 0.10}},
	"relic_greed": {"name": "Relic of Greed", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.75, 0.2, 1.0), "equip_effect": {"gold_gain": 0.20}},
	"relic_wisdom": {"name": "Relic of Wisdom", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.55, 0.9, 1.0), "equip_effect": {"xp_gain": 0.20}},
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
		"name": "Magic Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.65, 0.2, 0.85, 1.0),
		"weapon_stats": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.65, 0.2, 0.85), "icon_offset": 20.0},
		"unique_desc": "Obliterates every enemy on screen.",
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
}

# Materials masquerade as "Unknown Substance" until the Science Lab has
# researched that type -- the lookup lives here so every UI (inventory,
# skill tree, notifications) shows the same thing.
static func get_display_name(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		return "Unknown Substance"
	return def.get("name", item_id)

# Item sets. Wearing every piece of a set at once grants its bonus (checked
# via GameState.is_set_complete / folded into GameState.get_bonus_total). A
# set's "pieces" can be any equippable items -- armor AND weapons -- so a
# future set could require a matching weapon too; the Leather set below is
# armor-only for now.
const SET_DEFS = {
	"leather": {
		"name": "Leather Set",
		"pieces": ["helm_leather", "armor_leather", "pants_leather"],
		"bonus": {"max_health": 20.0, "move_speed": 0.05},
		"bonus_desc": "+20 Max HP, +5% Move Speed",
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
			lines.append("DMG %d · CD %.2fs" % [int(ws.get("damage", 0)), ws.get("cooldown", 0.0)])
		if def.has("unique_desc"):
			lines.append("Unique: " + def.unique_desc)
		lines.append("Wield from your hotbar (keys 1-0).")
	else:
		for key in def.get("equip_effect", {}).keys():
			lines.append(_effect_line(key, def.equip_effect[key]))

	if set_id != "" and SET_DEFS.has(set_id):
		lines.append("Set bonus (full): " + SET_DEFS[set_id].bonus_desc)

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
	var label = EFFECT_LABELS.get(key, key.replace("_", " ").capitalize())
	if key == "max_health":
		return "+%d %s" % [int(val), label]
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
