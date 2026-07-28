extends Node

# FISHING, increment A (pillar 3, 2026-07-28): the water's ledger, headless.
# Every id the water can owe is REAL and graded; the rod tiers gate the rich
# half of each table without hiding it; the Harbormaster's oddity joins the
# roll only while his quest names it; crates hold what they claim; and the
# one secret answers only to the best line.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# ---- every id in every table is a real, graded item ----
	var bad := []
	for kind in Fishing.TABLES:
		for e in Fishing.TABLES[kind]:
			var id := str(e.get("id", ""))
			if Inventory.get_item_def(id).is_empty() or Inventory.get_grade(id) == "":
				bad.append(id)
	for odd in Fishing.QUEST_ODDITIES:
		var oid := str(odd.get("id", ""))
		if Inventory.get_item_def(oid).is_empty():
			bad.append(oid)
	check("every catch and oddity is a real, graded item", bad.is_empty(), ", ".join(bad))

	# ---- rods carry their tiers, and the ladder climbs ----
	check("the rod ladder climbs willow -> wyrmbone -> moonline",
		Fishing.rod_tier("tool_rod_willow") == 1
		and Fishing.rod_tier("tool_rod_wyrmbone") == 2
		and Fishing.rod_tier("tool_rod_moonline") == 3)
	check("a better rod bites faster",
		float(Fishing.bite_gap("tool_rod_moonline")[1]) < float(Fishing.bite_gap("tool_rod_willow")[1]))

	# ---- the rod gates hold across five hundred casts ----
	GameState.fishing_quest = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var leak := false
	var caught_common := false
	for i in range(500):
		var got := Fishing.roll_catch("cave", 1, rng)
		for e in Fishing.TABLES["cave"]:
			if str(e.get("id", "")) == got and int(e.get("min_rod", 1)) > 1:
				leak = true
		if got == "fish_lanterneel":
			caught_common = true
	check("a tier-1 rod never lands a gated catch (500 casts)", not leak)
	check("...but the open water still bites", caught_common)
	# the secret answers only the best line
	var secret_at_3 := false
	for i in range(4000):
		if Fishing.roll_catch("cave", 3, rng) == "relic_tidewalker":
			secret_at_3 = true
			break
	check("the deep's one secret answers a tier-3 line (4000 casts)", secret_at_3)

	# ---- the oddity joins the roll ONLY while the quest names it ----
	var odd_free := false
	for i in range(400):
		if str(Fishing.roll_catch("village", 3, rng)).begins_with("odd_"):
			odd_free = true
	check("no oddity ever bites unbidden", not odd_free)
	GameState.fishing_quest = {"id": "odd_glassfin", "name": "the Glassfin", "posted_day": 0}
	var odd_bites := false
	for i in range(400):
		if Fishing.roll_catch("village", 1, rng) == "odd_glassfin":
			odd_bites = true
			break
	check("the named oddity bites while the quest is live", odd_bites)
	GameState.fishing_quest = {}

	# ---- crates hold what they claim, in real ids ----
	for cid in ["crate_driftwood", "crate_pearlbound"]:
		var loot := Fishing.crate_loot(cid)
		var ok := not loot.is_empty()
		var has_gold := false
		for l in loot:
			var lid := str(l.get("id", ""))
			if lid == "gold":
				has_gold = true
			elif Inventory.get_item_def(lid).is_empty():
				ok = false
		check("%s holds real goods and gold" % cid, ok and has_gold)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
