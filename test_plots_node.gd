extends Node
# SPECIAL PLOTS (settlement-depth roadmap Phase 3). The third spatial rule, and the
# first where the MAP has an opinion: one exact patch of ground that suits exactly
# one building -- the seam the Mine wants, the soil the Farm wants, the spring the
# boats want.
#
# The invariants this pins are the DESIGN rules, not just the code:
#   * purely additive (no plot ever costs a building anything)
#   * every plot sits INSIDE the quarter its building already belongs to, so the
#     two spatial rules never fight -- adjacency stays the thing you trade away
#   * the "perfect corners" really are reachable: Farm+Dock and Mine+Builderhouse
#     can each stand on their own ground AND stay neighbours
#   * the Mine's forge pairing genuinely CANNOT be combined with its vein
#   * the ground is visible, and the bonus reaches a real producer

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
	var saved_plots: Dictionary = GameState.building_plots.duplicate(true)
	var saved_dist: Dictionary = GameState.building_districts.duplicate(true)
	var saved_nb: Dictionary = GameState.building_neighbors.duplicate(true)
	var saved_roster: Array = GameState.rescued_villagers.duplicate(true)

	# ---- the registry is sane ----
	check("there are special plots at all", GameState.SPECIAL_PLOTS.size() > 0)
	var ids := {}
	var bad := []
	for plot in GameState.SPECIAL_PLOTS:
		var bn := str(plot["building"])
		if not (bn in GameState.STARTING_BUILDINGS):
			bad.append("no such building: " + bn)
		if ids.has(str(plot["id"])):
			bad.append("duplicate id: " + str(plot["id"]))
		ids[str(plot["id"])] = true
		if str(plot["name"]) == "" or str(plot["desc"]) == "":
			bad.append("unnamed plot: " + str(plot["id"]))
	check("every plot names a real building, has a unique id, and is described", bad.is_empty(), str(bad))
	var one_each := true
	for plot2 in GameState.SPECIAL_PLOTS:
		var seen := 0
		for q in GameState.SPECIAL_PLOTS:
			if str(q["building"]) == str(plot2["building"]):
				seen += 1
		if seen != 1:
			one_each = false
	check("no building has two plots to choose between", one_each)

	# ---- THE DESIGN INVARIANT: a plot never fights its building's quarter ----
	var mismatched := []
	for plot3 in GameState.SPECIAL_PLOTS:
		var bn3 := str(plot3["building"])
		var home_q := str(GameState.DISTRICT_HOME.get(bn3, ""))
		var plot_q := GameState.district_at(float(plot3["x"]))
		if home_q != plot_q:
			mismatched.append("%s: plot in %s, belongs in %s" % [bn3, plot_q, home_q])
	check("EVERY plot lies inside its building's own quarter (the rules never fight)",
		mismatched.is_empty(), str(mismatched))

	# ---- plots are far enough apart not to overlap ----
	var overlap := []
	for i2 in range(GameState.SPECIAL_PLOTS.size()):
		for j in range(i2 + 1, GameState.SPECIAL_PLOTS.size()):
			var dx: float = absf(float(GameState.SPECIAL_PLOTS[i2]["x"]) - float(GameState.SPECIAL_PLOTS[j]["x"]))
			if dx < GameState.PLOT_RADIUS * 2.0:
				overlap.append("%s/%s" % [str(GameState.SPECIAL_PLOTS[i2]["id"]), str(GameState.SPECIAL_PLOTS[j]["id"])])
	check("no two plots overlap (one patch of ground is never two things)", overlap.is_empty(), str(overlap))

	# ---- reading the ground ----
	var vein: Dictionary = GameState.plot_for_building("Mine")
	check("the Mine has a seam of its own", not vein.is_empty() and str(vein["id"]) == "vein")
	check("standing ON it is recognised",
		str(GameState.plot_at(float(vein["x"])).get("id", "")) == "vein")
	check("...and a step too far reads as open ground",
		GameState.plot_at(float(vein["x"]) + GameState.PLOT_RADIUS + 40.0).is_empty())

	# ---- the bonus is earned, and never a penalty ----
	for b in ["Mine", "Farm", "Fishing Dock", "Builderhouse", "Blacksmith"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
	GameState.building_neighbors = {}
	GameState.building_districts = {}
	GameState.building_plots = {"Mine": "vein", "Farm": ""}
	check("a Mine on its vein earns the plot bonus",
		GameState.on_home_plot("Mine")
		and is_equal_approx(GameState.plot_bonus("Mine"), GameState.PLOT_BONUS),
		"%.2f" % GameState.plot_bonus("Mine"))
	check("a Farm on plain ground earns NOTHING extra (never a penalty)",
		not GameState.on_home_plot("Farm")
		and is_equal_approx(GameState.plot_bonus("Farm"), 0.0)
		and GameState.building_output_multiplier("Farm") >= 1.0,
		"%.2f" % GameState.building_output_multiplier("Farm"))
	GameState.building_plots["Mine"] = "soil"          # the Farm's ground, not the Mine's
	check("the WRONG plot pays a building nothing",
		is_equal_approx(GameState.plot_bonus("Mine"), 0.0))
	GameState.building_plots["Mine"] = "vein"
	GameState.building_stage["Mine"] = 0
	check("a ruined building works no ground", is_equal_approx(GameState.plot_bonus("Mine"), 0.0))
	GameState.building_stage["Mine"] = GameState.TOTAL_BUILD_STAGES

	# ---- THE PERFECT CORNERS: plot + plot + neighbours, all at once ----
	var soil_x := 0.0
	var spring_x := 0.0
	var quarry_x := 0.0
	var vein_x := 0.0
	for plot4 in GameState.SPECIAL_PLOTS:
		match str(plot4["id"]):
			"soil": soil_x = float(plot4["x"])
			"spring": spring_x = float(plot4["x"])
			"quarry": quarry_x = float(plot4["x"])
			"vein": vein_x = float(plot4["x"])
	# two buildings can be neighbours only if nothing else fits between them; the
	# yardstick is the clearance the placer itself enforces
	var reach := 1200.0
	check("Farm and Dock CAN hold both their plots and still be neighbours (an earned corner)",
		absf(spring_x - soil_x) <= reach, "%.0f apart" % absf(spring_x - soil_x))
	check("Builderhouse and Mine likewise",
		absf(vein_x - quarry_x) <= reach, "%.0f apart" % absf(vein_x - quarry_x))
	# ...but the forge belongs at the GATE, so the Mine cannot have both
	check("the Mine's forge pairing genuinely cannot be combined with its vein",
		GameState.district_at(vein_x) != str(GameState.DISTRICT_HOME.get("Blacksmith", "")),
		"vein sits in %s, the forge belongs in %s" % [GameState.district_at(vein_x),
			str(GameState.DISTRICT_HOME.get("Blacksmith", ""))])

	# ---- it reaches a REAL producer ----
	GameState.rescued_villagers = [
		{"id": "pl_m", "name": "Digger", "sex": "Male", "is_kid": false, "stat_name": "Mine",
			"stat_value": 3, "role_key": "Mine", "role_title": "Miner"}]
	GameState.building_plots = {"Mine": ""}
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._mine_accum = 0.0
	GameState.tick_mine_yield(24.0 * 10.0 + 0.5)
	var plain: int = int(GameState.village_stockpile["stone"])
	GameState.building_plots = {"Mine": "vein"}
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._mine_accum = 0.0
	GameState.tick_mine_yield(24.0 * 10.0 + 0.5)
	var seam: int = int(GameState.village_stockpile["stone"])
	check("a Mine worked ON the vein really hauls more stone",
		seam > plain, "vein=%d plain=%d over 10 days" % [seam, plain])

	# ---- EVERY PLOT IS ACTUALLY REACHABLE (the check the arithmetic can't make) ----
	# A plot whose building physically cannot fit on it is decoration. Ask the LIVE
	# placer, with the real clearance rules -- this caught three plots buried under
	# the starter ruins and one under a surface chest that reserves its ground.
	var unbuildable := []
	var main_scene := get_tree().current_scene
	for plot5 in GameState.SPECIAL_PLOTS:
		var bn5 := str(plot5["building"])
		var bdef: Dictionary = main_scene.building_def(bn5) if main_scene.has_method("building_def") else {}
		if bdef.is_empty():
			continue
		var bw: float = float(bdef.get("width", 100.0)) * float(bdef.get("scale", 2.0)) * 1.3
		if not GameState.can_place_building(get_tree(), bw, float(plot5["x"])):
			unbuildable.append("%s @%.0f" % [bn5, float(plot5["x"])])
	check("every plot's building can actually STAND on it in a fresh village",
		unbuildable.is_empty(), str(unbuildable))
	# ...and the builders must never pave the special ground with cottages
	var cott_x: float = GameState._next_cottage_x()
	check("the auto-raised cottage row steps AROUND the plots",
		GameState.plot_at(cott_x).is_empty(), "cottage would land at %.0f" % cott_x)

	# ---- the ground is VISIBLE, and the layout reads it ----
	var markers := get_tree().get_nodes_in_group("special_plot")
	check("every plot is drawn on the ground (a plot you can't see is a guess)",
		markers.size() == GameState.SPECIAL_PLOTS.size(),
		"%d drawn of %d" % [markers.size(), GameState.SPECIAL_PLOTS.size()])
	var not_structures := true
	for m in markers:
		if m.is_in_group("village_structure"):
			not_structures = false
	check("...and no marker reserves the ground against building on it", not_structures)
	# This asked only "is building_plots a Dictionary?" -- and it is declared
	# `var building_plots: Dictionary = {}`, so that could never be anything else:
	# a check that was true before refresh_layout() ever ran. The claim in its own
	# name is that refresh READS THE GROUND, so read the ground independently and
	# demand the same answer. The hand-forced {"Mine": "vein"} above (set with no
	# Mine anywhere near the vein) must be gone by the time this passes.
	GameState.refresh_layout()
	var expected := {}
	for b in get_tree().get_nodes_in_group("building"):
		if not is_instance_valid(b) or not ("building_name" in b):
			continue
		var pl: Dictionary = GameState.plot_at(b.global_position.x)
		expected[str(b.building_name)] = str(pl["id"]) if not pl.is_empty() else ""
	check("refresh reads which building works which ground (recomputed from where the buildings actually stand)",
		GameState.building_plots == expected,
		"cached %s vs ground %s" % [str(GameState.building_plots), str(expected)])
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("plot claims survive the save", gs.contains('"building_plots": building_plots'))
	check("the E-panel names the ground and what it wants",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("plot_for_building"))
	check("placing/moving onto it says so",
		FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("on_home_plot")
		and FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("on_home_plot"))

	# ---- restore ----
	GameState.building_stage = saved_stage
	GameState.building_plots = saved_plots
	GameState.building_districts = saved_dist
	GameState.building_neighbors = saved_nb
	GameState.rescued_villagers = saved_roster

	printerr("test_plots : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
