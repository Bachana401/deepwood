extends Node
# ADJACENCY SYNERGY (settlement-depth roadmap Phase 1). The village is a 1-D strip,
# so WHERE a building stands matters: its immediate left/right neighbour can lift
# its output. Every pair is a City Machine supply link made physical (ore beside the
# forge, the counting house beside the carts). POSITIVE ONLY -- a plain row is never
# punished, so no existing save is retroactively fined.
#
# This pins: the row is read from real positions, a synergy needs BOTH halves
# operational, the bonus is capped, it feeds the real producers (food/ore/timber),
# it survives a save, and moving a building re-earns it.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func _ready() -> void:
	var p: Node = null
	for i in range(600):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false

	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_nb: Dictionary = GameState.building_neighbors.duplicate(true)
	var saved_roster: Array = GameState.rescued_villagers.duplicate(true)
	var saved_store: Dictionary = GameState.village_stockpile.duplicate(true)

	# ---- the pair table is sane ----
	check("the pair table is non-empty and positive-only", GameState.ADJACENCY_PAIRS.size() > 0)
	var all_positive := true
	for pair in GameState.ADJACENCY_PAIRS:
		if float(pair["bonus"]) <= 0.0:
			all_positive = false
	check("...every pair is a BONUS, never a penalty (no save is retro-fined)", all_positive)

	# ---- hand-set a row: Mine next to Blacksmith, Farm far away ----
	GameState.building_neighbors = {
		"Mine": ["", "Blacksmith"],
		"Blacksmith": ["Mine", "Barracks"],
		"Barracks": ["Blacksmith", ""],
		"Farm": ["", ""],
	}
	for b in ["Mine", "Blacksmith", "Barracks", "Farm"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES

	var links: Array = GameState.adjacency_links("Mine")
	check("the Mine sees its forge neighbour", links.size() == 1
		and str(links[0]["partner"]) == "Blacksmith", str(links))
	check("...and the bonus lands on output",
		GameState.building_output_multiplier("Mine") > 1.0,
		"%.2f" % GameState.building_output_multiplier("Mine"))
	check("a building with no neighbours earns nothing (never a penalty)",
		is_equal_approx(GameState.adjacency_bonus("Farm"), 0.0)
		and is_equal_approx(GameState.building_output_multiplier("Farm"), 1.0),
		"%.2f" % GameState.building_output_multiplier("Farm"))
	check("the smith between mine and yard earns BOTH sides",
		GameState.adjacency_links("Blacksmith").size() == 2,
		str(GameState.adjacency_links("Blacksmith")))

	# ---- both halves must actually WORK ----
	GameState.building_stage["Blacksmith"] = 0            # raze the forge
	check("a RUINED neighbour pays nothing (rubble forges no ore)",
		GameState.adjacency_links("Mine").is_empty(),
		str(GameState.adjacency_links("Mine")))
	check("...and a ruined building earns nothing itself",
		GameState.adjacency_links("Blacksmith").is_empty())
	GameState.building_stage["Blacksmith"] = GameState.TOTAL_BUILD_STAGES

	# ---- the cap holds ----
	GameState.building_neighbors["Blacksmith"] = ["Mine", "Barracks"]
	check("the total bonus never exceeds the cap",
		GameState.adjacency_bonus("Blacksmith") <= GameState.ADJACENCY_BONUS_CAP + 0.0001,
		"%.2f" % GameState.adjacency_bonus("Blacksmith"))

	# ---- it reaches the REAL producers, not just a display number ----
	GameState.rescued_villagers = [
		{"id": "adj_m", "name": "Digger", "sex": "Male", "is_kid": false, "stat_name": "Mine",
			"stat_value": 3, "role_key": "Mine", "role_title": "Miner"}]
	# ...measured over TEN days: a 20% lift on a one-miner seam is a fifth of a stone
	# a day, which only shows up once the banked remainder lands (see _add_to_store --
	# int rounding used to eat the whole bonus at small scale).
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._mine_accum = 0.0
	GameState.tick_mine_yield(24.0 * 10.0 + 0.5)
	var paired_haul: int = int(GameState.village_stockpile["stone"])
	GameState.building_neighbors["Mine"] = ["", ""]        # same crew, lonely mine
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._mine_accum = 0.0
	GameState.tick_mine_yield(24.0 * 10.0 + 0.5)
	var lonely_haul: int = int(GameState.village_stockpile["stone"])
	check("a Mine beside the forge really hauls MORE into the stores",
		paired_haul > lonely_haul, "paired=%d lonely=%d" % [paired_haul, lonely_haul])
	# ...and the mechanism that makes a small-crew bonus survive at all: fractions are
	# BANKED between cycles instead of rounded away (three 0.4 hauls owe one stone).
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	var d1: int = GameState._add_to_store("stone", 0.4)
	var d2: int = GameState._add_to_store("stone", 0.4)
	var d3: int = GameState._add_to_store("stone", 0.4)
	check("fractional yields are BANKED, never rounded away",
		d1 == 0 and d2 == 0 and d3 == 1 and int(GameState.village_stockpile["stone"]) == 1,
		"%d/%d/%d store=%d" % [d1, d2, d3, int(GameState.village_stockpile["stone"])])

	# ---- food feels it too (Farm beside the Dock) ----
	GameState.rescued_villagers = [
		{"id": "adj_f", "name": "Sower", "sex": "Female", "is_kid": false, "stat_name": "Farm",
			"stat_value": 3, "role_key": "Farm", "role_title": "Farmer"}]
	GameState.building_stage["Fishing Dock"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_neighbors["Farm"] = ["", ""]
	var food_alone: float = GameState.food_production_per_hour()
	GameState.building_neighbors["Farm"] = ["", "Fishing Dock"]
	var food_paired: float = GameState.food_production_per_hour()
	check("a Farm beside the Dock feeds the town faster",
		food_paired > food_alone, "%.4f -> %.4f" % [food_alone, food_paired])

	# ---- the row is DERIVED from real positions, and survives a save ----
	GameState.refresh_adjacency()
	check("refresh reads the row off the standing village",
		not GameState.building_neighbors.is_empty(), str(GameState.building_neighbors.size()))
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the neighbour row is saved (away ticks still know the layout)",
		gs.contains('"building_neighbors": building_neighbors'))
	check("...and rebuilt when the village generates",
		FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("refresh_adjacency"))
	check("moving a building re-reads the row",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("refresh_adjacency"))
	var ui := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("the E-panel names the live synergies (and the level term stays separate)",
		ui.contains("adjacency_links") and ui.contains("BUILDING_OUTPUT_PER_LEVEL"))
	check("placing a building announces what the ground earned",
		FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("adjacency_links"))

	# ---- restore ----
	GameState.building_stage = saved_stage
	GameState.building_neighbors = saved_nb
	GameState.rescued_villagers = saved_roster
	GameState.village_stockpile = saved_store

	printerr("test_adjacency : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
