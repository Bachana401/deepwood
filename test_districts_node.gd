extends Node
# DISTRICTS (settlement-depth roadmap Phase 2). The second spatial axis: adjacency
# asks WHO you stand beside, a district asks WHERE ON THE ROAD you stand. Three
# quarters run west->east from the gate the sieges come from:
#   gatefront  the war quarter (soldiers, arms, the ward that takes the wounded)
#   heart      the civic quarter (rule, coin, trade, learning, company)
#   outskirts  the working land (fields, water, seams, timber, a quiet shrine)
#
# Pins: the boundaries are absolute from the GATE (so growing the town east can
# never silently move a building out of its quarter), every building has exactly
# one home quarter, the bonus is positive-only, it feeds the real producers, and
# it survives a save.

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
	var saved_dist: Dictionary = GameState.building_districts.duplicate(true)
	var saved_nb: Dictionary = GameState.building_neighbors.duplicate(true)
	var saved_roster: Array = GameState.rescued_villagers.duplicate(true)

	# ---- the table itself ----
	check("every roster building has exactly one home quarter",
		GameState.DISTRICT_HOME.size() == GameState.STARTING_BUILDINGS.size(),
		"%d homes vs %d buildings" % [GameState.DISTRICT_HOME.size(), GameState.STARTING_BUILDINGS.size()])
	var unknown := []
	for bn in GameState.DISTRICT_HOME.keys():
		if not (str(bn) in GameState.STARTING_BUILDINGS):
			unknown.append(str(bn))
		if not GameState.DISTRICT_LABEL.has(str(GameState.DISTRICT_HOME[bn])):
			unknown.append("bad-quarter:" + str(bn))
	check("...and no home names a building or quarter that doesn't exist", unknown.is_empty(), str(unknown))

	# ---- the ground reads west -> east off the GATE ----
	var gate: float = GameState.SURFACE_WEST_FALLBACK_X
	check("ground at the gate is the war quarter",
		GameState.district_at(gate) == "gatefront", GameState.district_at(gate))
	check("...and so is ground WEST of it (outside is the exposed edge)",
		GameState.district_at(gate - 500.0) == "gatefront", GameState.district_at(gate - 500.0))
	check("the middle of the road is the Heart",
		GameState.district_at(gate + GameState.DISTRICT_GATEFRONT_DEPTH + 100.0) == "heart",
		GameState.district_at(gate + GameState.DISTRICT_GATEFRONT_DEPTH + 100.0))
	check("the far east is the working land",
		GameState.district_at(gate + GameState.DISTRICT_HEART_DEPTH + 100.0) == "outskirts",
		GameState.district_at(gate + GameState.DISTRICT_HEART_DEPTH + 100.0))
	check("the quarters are ordered and non-overlapping",
		GameState.DISTRICT_GATEFRONT_DEPTH < GameState.DISTRICT_HEART_DEPTH)

	# ---- the bonus is earned by standing in the right quarter, and only then ----
	for b in ["Barracks", "Farm", "Bank"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
	GameState.building_neighbors = {}          # isolate the district term from adjacency
	GameState.building_districts = {"Barracks": "gatefront", "Farm": "heart", "Bank": "heart"}
	check("a Barracks at the gate earns its quarter",
		GameState.in_home_district("Barracks")
		and is_equal_approx(GameState.district_bonus("Barracks"), GameState.DISTRICT_BONUS),
		"%.2f" % GameState.district_bonus("Barracks"))
	check("a Farm in the town square earns NOTHING extra (never a penalty)",
		not GameState.in_home_district("Farm")
		and is_equal_approx(GameState.district_bonus("Farm"), 0.0)
		and GameState.building_output_multiplier("Farm") >= 1.0,
		"%.2f" % GameState.building_output_multiplier("Farm"))
	check("a Bank in the Heart earns its quarter", GameState.in_home_district("Bank"))
	GameState.building_stage["Barracks"] = 0
	check("a RUINED building earns no quarter bonus",
		is_equal_approx(GameState.district_bonus("Barracks"), 0.0))
	GameState.building_stage["Barracks"] = GameState.TOTAL_BUILD_STAGES

	# ---- it reaches a REAL producer ----
	GameState.rescued_villagers = [
		{"id": "d_f", "name": "Sower", "sex": "Female", "is_kid": false, "stat_name": "Farm",
			"stat_value": 3, "role_key": "Farm", "role_title": "Farmer"}]
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_districts["Farm"] = "heart"          # wrong quarter
	var food_wrong: float = GameState.food_production_per_hour()
	GameState.building_districts["Farm"] = "outskirts"      # its own land
	var food_right: float = GameState.food_production_per_hour()
	check("a Farm on the working land really feeds the town faster",
		food_right > food_wrong, "%.4f -> %.4f" % [food_wrong, food_right])

	# ---- the two axes STACK, and the cap only governs adjacency ----
	GameState.building_districts["Mine"] = "outskirts"
	GameState.building_districts["Builderhouse"] = "outskirts"
	GameState.building_stage["Mine"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_neighbors = {"Mine": ["", "Builderhouse"], "Builderhouse": ["Mine", ""]}
	var both: float = GameState.building_output_multiplier("Mine")
	check("quarter AND neighbour stack on the same building",
		both > 1.0 + GameState.DISTRICT_BONUS, "%.3f" % both)

	# ---- derived from real ground, and persisted ----
	GameState.refresh_layout()
	check("refresh reads every standing building's quarter off its ground",
		not GameState.building_districts.is_empty(), str(GameState.building_districts.size()))
	var live_ok := true
	for bn in GameState.building_districts.keys():
		if not GameState.DISTRICT_LABEL.has(str(GameState.building_districts[bn])):
			live_ok = false
	check("...and every cached quarter is a real one", live_ok, str(GameState.building_districts))
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the quarters survive the save (away ticks still know the town)",
		gs.contains('"building_districts": building_districts'))
	check("boundaries are ABSOLUTE from the gate, not fractions of the row",
		gs.contains("DISTRICT_GATEFRONT_DEPTH") and not gs.contains("row.size() / 3"))
	var ui := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("the E-panel names the quarter and where it belongs",
		ui.contains("in_home_district") and ui.contains("DISTRICT_LABEL"))
	check("placing/moving says when the ground suits it",
		FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("in_home_district")
		and FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("in_home_district"))

	# ---- restore ----
	GameState.building_stage = saved_stage
	GameState.building_districts = saved_dist
	GameState.building_neighbors = saved_nb
	GameState.rescued_villagers = saved_roster

	printerr("test_districts : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
