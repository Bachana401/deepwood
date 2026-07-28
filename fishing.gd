class_name Fishing
extends RefCounted

# ============================ FISHING ============================
# (renewability pillar 3, dev-chosen 2026-07-28: the FULL loop, reforging
# rejected.) Cast off the Dock's water or an underground pool, wait for the
# BITE, strike inside the window, and the water decides what you're owed.
# Terraria-angler-INSPIRED, never a copy: tables by water KIND and rod TIER,
# fish that feed the premium-food identity, crates that hold the road's
# leavings, a rod ladder fished out of the water itself, and one secret the
# deep only surrenders to the best line.
#
# This file is pure data + rolls (headless-testable); the cast/bite/strike
# choreography lives in player.gd (_tick_fishing), the water zones register
# themselves in the "fish_water" group (the Dock's pond, the underground's
# calm pools), and the Harbormaster's daily quest rides GameState.

# --- the rod ladder: tier gates the richer half of every table ---
const RODS = {
	"tool_rod_willow":   {"tier": 1, "bite_gap": [3.0, 7.0]},
	"tool_rod_wyrmbone": {"tier": 2, "bite_gap": [2.2, 5.5]},
	"tool_rod_moonline": {"tier": 3, "bite_gap": [1.6, 4.2]},
}

static func rod_tier(item_id: String) -> int:
	return int(RODS.get(item_id, {}).get("tier", 0))

static func bite_gap(item_id: String) -> Array:
	return RODS.get(item_id, {}).get("bite_gap", [3.0, 7.0])

# --- the tables: {id, w (weight), min_rod} per water kind ---
# village = the Dock's pond; cave = the underground's calm pools (lava never
# bites). Weights are integers; min_rod gates without hiding the dream.
const TABLES = {
	"village": [
		{"id": "fish_silverfin", "w": 42, "min_rod": 1},
		{"id": "fish_mudwhisker", "w": 30, "min_rod": 1},
		{"id": "junk_boot", "w": 12, "min_rod": 1},
		{"id": "crate_driftwood", "w": 9, "min_rod": 1},
		{"id": "fish_kingsjaw", "w": 4, "min_rod": 2},
		{"id": "tool_rod_wyrmbone", "w": 2, "min_rod": 1},
		{"id": "crate_pearlbound", "w": 1, "min_rod": 2},
	],
	"cave": [
		{"id": "fish_lanterneel", "w": 40, "min_rod": 1},
		{"id": "fish_mudwhisker", "w": 20, "min_rod": 1},
		{"id": "crate_driftwood", "w": 12, "min_rod": 1},
		{"id": "fish_palegulper", "w": 12, "min_rod": 2},
		{"id": "crate_pearlbound", "w": 6, "min_rod": 2},
		{"id": "tool_rod_moonline", "w": 2, "min_rod": 2},
		{"id": "relic_tidewalker", "w": 1, "min_rod": 3},   # the one secret
	],
}

# The Harbormaster's daily oddities: only ever bite while HIS quest names
# them (injected into the roll, never in the standing tables).
const QUEST_ODDITIES = [
	{"id": "odd_glassfin", "name": "the Glassfin"},
	{"id": "odd_inkmaw", "name": "the Inkmaw"},
	{"id": "odd_bellsnail", "name": "the Bell-Snail"},
	{"id": "odd_twicefish", "name": "the Twice-Caught Fish"},
	{"id": "odd_sorrowcarp", "name": "the Sorrow-Carp"},
]

# Roll a catch for a water kind + rod tier. The daily oddity, when live for
# this water, joins the roll at a fair weight. Returns an item id.
static func roll_catch(kind: String, rod: int, rng: RandomNumberGenerator = null) -> String:
	var table: Array = TABLES.get(kind, TABLES["village"])
	var pool := []
	var total := 0
	for e in table:
		if rod >= int(e.get("min_rod", 1)):
			pool.append(e)
			total += int(e.get("w", 1))
	# the quest oddity bites anywhere, at a seeker's weight
	var oddity := GameState.fishing_quest_oddity()
	if oddity != "":
		pool.append({"id": oddity, "w": maxi(6, total / 8)})
		total += maxi(6, total / 8)
	if pool.is_empty() or total <= 0:
		return "junk_boot"
	var r: int
	if rng != null:
		r = rng.randi_range(1, total)
	else:
		r = randi_range(1, total)
	for e in pool:
		r -= int(e.get("w", 1))
		if r <= 0:
			return str(e.get("id", "junk_boot"))
	return str(pool.back().get("id", "junk_boot"))

# What a crate holds when opened (player.use_item "open_crate").
static func crate_loot(crate_id: String) -> Array:
	if crate_id == "crate_pearlbound":
		return [{"id": "gold", "count": 90 + randi_range(0, 60)},
			{"id": "ember_crystal", "count": 1},
			{"id": "iron_shard", "count": 2}]
	return [{"id": "gold", "count": 25 + randi_range(0, 25)},
		{"id": "iron_shard", "count": 1},
		{"id": "wood", "count": 3}]
