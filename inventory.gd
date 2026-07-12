class_name Inventory
extends RefCounted

# Shared item catalog -- every item type in the game (currency included) is
# defined here so both the player's inventory and any chest's inventory read
# from the same source. gold/silver/bronze are independent items with no
# fixed conversion rate between them -- only coin_gold drives the shop,
# death-drop, and passive income (see player.gd's currency property). Future
# gear/skill-material items get added here too, not as special cases elsewhere.
const ITEM_DEFS = {
	"coin_gold": {"name": "Gold Coin", "max_stack": 999, "color": Color(1.0, 0.85, 0.2, 1.0)},
	"coin_silver": {"name": "Silver Coin", "max_stack": 999, "color": Color(0.78, 0.8, 0.84, 1.0)},
	"coin_bronze": {"name": "Bronze Coin", "max_stack": 999, "color": Color(0.72, 0.45, 0.22, 1.0)},
	# Skill-tree materials, dropped rarely in the dungeon by level bracket
	# (see dungeon_interior.gd) -- their names stay hidden ("Unknown
	# Substance") until researched at the Science Lab, see
	# GameState.researched_materials and get_display_name() below.
	"slime": {"name": "Slime", "max_stack": 99, "color": Color(0.35, 0.75, 0.35, 1.0), "is_material": true},
	"iron_shard": {"name": "Iron Shard", "max_stack": 99, "color": Color(0.6, 0.62, 0.68, 1.0), "is_material": true},
	"ember_crystal": {"name": "Ember Crystal", "max_stack": 99, "color": Color(0.95, 0.45, 0.15, 1.0), "is_material": true},
	"void_essence": {"name": "Void Essence", "max_stack": 99, "color": Color(0.4, 0.2, 0.6, 1.0), "is_material": true},
	"ancient_relic": {"name": "Ancient Relic", "max_stack": 99, "color": Color(0.85, 0.75, 0.4, 1.0), "is_material": true},
}

# Materials masquerade as "Unknown Substance" until the Science Lab has
# researched that type -- the lookup lives here so every UI (inventory,
# skill tree, notifications) shows the same thing.
static func get_display_name(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		return "Unknown Substance"
	return def.get("name", item_id)

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
