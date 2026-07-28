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

	# ============ increment B: the machine around the water ============
	# a probe player the GameState hooks can find (the caravan test's trick)
	var probe := FishProbe.new()
	probe.add_to_group("player")
	add_child(probe)

	# ---- the starter rod: raising the Dock leaves ONE willow rod ----
	GameState.building_stage["Fishing Dock"] = GameState.TOTAL_BUILD_STAGES
	GameState.removed_buildings.erase("Fishing Dock")
	GameState.willow_rod_granted = false
	GameState.tick_fishing()
	check("raising the Dock leaves a willow rod", probe.inventory.get_count("tool_rod_willow") == 1)
	GameState.tick_fishing()
	check("...and never a second", probe.inventory.get_count("tool_rod_willow") == 1)
	# a bag already carrying a rod (a Rewound Hour keeps everything) gets none
	GameState.willow_rod_granted = false
	probe.inventory.remove_item("tool_rod_willow", 1)
	probe.inventory.add_item("tool_rod_moonline", 1)
	GameState.tick_fishing()
	check("a bag already holding a rod is never handed another",
		probe.inventory.get_count("tool_rod_willow") == 0 and GameState.willow_rod_granted)

	# ---- the Harbormaster's daily: one posting per day, staffed only ----
	GameState.fishing_quest = {}
	GameState.fishing_last_post_day = -1
	GameState.fishing_quests_done = 0
	GameState.game_hours = 30.0        # day 1
	GameState.tick_fishing()
	check("an unstaffed dock posts nothing", GameState.fishing_quest.is_empty())
	GameState.rescued_villagers.append({"name": "Test Fisher", "role_key": "Fishing Dock", "role_title": "Fisherman"})
	GameState.tick_fishing()
	var first_odd := GameState.fishing_quest_oddity()
	check("a staffed dock posts the day's oddity", first_odd.begins_with("odd_"))
	# turn-in without the catch is refused with a reason
	check("turn-in without the catch is refused", GameState.fishing_turn_in(probe) != "")
	# land it, hand it over: gold + a crate, ledger grows, quest clears
	probe.inventory.add_item(first_odd, 1)
	var gold_before: int = probe.currency
	check("turn-in with the catch pays", GameState.fishing_turn_in(probe) == "")
	check("...in gold", probe.currency > gold_before)
	check("...and a crate", probe.inventory.get_count("crate_driftwood") == 1)
	check("...the oddity is taken", probe.inventory.get_count(first_odd) == 0)
	check("...the ledger grows and the ask clears",
		GameState.fishing_quests_done == 1 and GameState.fishing_quest.is_empty())
	# no second posting the same day; a new day posts a DIFFERENT oddity
	GameState.tick_fishing()
	check("one posting per day, turned in or not", GameState.fishing_quest.is_empty())
	GameState.game_hours = 50.0        # day 2
	GameState.tick_fishing()
	check("a new day posts a new ask, never the same twice running",
		GameState.fishing_quest_oddity().begins_with("odd_") and GameState.fishing_quest_oddity() != first_odd)
	# escalation: the 5th landed oddity pays the pearlbound crate
	GameState.fishing_quests_done = 4
	var odd5 := GameState.fishing_quest_oddity()
	probe.inventory.add_item(odd5, 1)
	check("the fifth oddity pays the pearlbound crate",
		GameState.fishing_turn_in(probe) == "" and probe.inventory.get_count("crate_pearlbound") == 1)
	# escalating pay caps where promised
	check("the pay ladder caps", GameState.FISHING_QUEST_BASE_GOLD + GameState.FISHING_QUEST_GOLD_STEP * 100 > GameState.FISHING_QUEST_GOLD_CAP)

	# ---- a new game forgets the whole ledger (the reset-leak lesson) ----
	GameState.reset_for_new_game()
	check("reset forgets the water's ledger",
		GameState.fishing_quest.is_empty() and GameState.fishing_quests_done == 0
		and GameState.fishing_last_post_day == -1 and GameState.fishing_last_oddity == ""
		and not GameState.willow_rod_granted)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# The probe: just enough player for GameState's fishing hooks -- a bag, a
# purse, and (Node2D) a position, because the village's per-frame ticks ask
# the "player" group where it is standing.
class FishProbe extends Node2D:
	var inventory = Inventory.new(8)
	var currency := 0
	# the shop UI's _owns() peeks at these on any refresh it catches
	var has_dash := false
	var has_double_jump := false
