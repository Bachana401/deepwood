extends Node

# PILLAR 3a — the village TIME ECONOMY, made legible (dev vision 2026-07-22).
# The plumbing (staffed farm/dock, builder crew, seated Chancellor...) already
# removes real chores; this locks the FELT layer on top of it:
#   * village_self_sufficiency() reports how much of the day the town runs itself
#   * each chore domain is celebrated ONCE, the first time it starts running
#     itself -- and only when the player is HOME to see it (the village fog)
# So a fresh town celebrates 0 chores (the early block); each automation earned
# lights one up ("your mornings are your own"); and it never double-fires.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	# unpause past any opening dialogue the village scene may hold
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# ---- save every knob this suite paints ----
	var saved_roster: Array = GameState.rescued_villagers
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_celeb: Array = GameState.selfsuf_celebrated.duplicate()
	var saved_dev: bool = GameState.dev_mode
	var saved_dungeon: bool = GameState.in_dungeon
	var saved_pos: Vector2 = p.global_position

	# ---- make the village PERCEIVABLE (at home, not the sandbox) ----
	GameState.dev_mode = false
	GameState.in_dungeon = false
	p.global_position.x = GameState.VILLAGE_PRESENCE_X + 200.0
	check("with the player home the village is knowable (fog open)",
		GameState.village_info_available())

	# ---- baseline: a fresh town in ruins runs NOTHING itself ----
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_stage[b] = 0
	var roster: Array = []
	for i in range(6):
		roster.append({"id": "ss_%d" % i, "name": "Soul %d" % i, "sex": "Male",
			"is_kid": false, "stat_name": "Farm", "stat_value": 5})
	GameState.rescued_villagers = roster
	GameState.selfsuf_celebrated = []
	var ss0: Dictionary = GameState.village_self_sufficiency()
	check("a ruined, unstaffed town is 0%% self-reliant",
		int(ss0["handled"]) == 0, str(ss0))
	GameState.tick_self_sufficiency()
	check("...so nothing is celebrated yet",
		GameState.selfsuf_celebrated.is_empty(), str(GameState.selfsuf_celebrated))

	# ---- FOOD: a staffed farm feeds the town -> the first chore runs itself ----
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	roster[0]["role_key"] = "Farm"; roster[0]["role_title"] = "Farmer"
	roster[1]["role_key"] = "Farm"; roster[1]["role_title"] = "Farmer"
	check("staffed fields out-produce the mouths that eat",
		GameState.food_production_per_hour() >= GameState.food_consumption_per_hour())
	GameState.tick_self_sufficiency()
	check("the FOOD chore is celebrated the moment the fields self-feed",
		GameState.selfsuf_celebrated.has("food"), str(GameState.selfsuf_celebrated))
	check("self-reliance climbed off zero", int(GameState.village_self_sufficiency()["handled"]) == 1)

	# ---- never twice: the reward is a one-time beat ----
	GameState.tick_self_sufficiency()
	var food_hits := 0
	for k in GameState.selfsuf_celebrated:
		if str(k) == "food": food_hits += 1
	check("a chore already freed is never celebrated again", food_hits == 1, str(GameState.selfsuf_celebrated))

	# ---- STAFFING: a seated Chancellor seats the rest for you ----
	roster.append({"id": "ss_gov", "name": "Chancellor", "sex": "Male", "is_kid": false,
		"stat_name": "Chancellor", "stat_value": 9, "role_key": "Government", "role_title": "Chancellor"})
	check("the Chancellor is seated", GameState.seated_leaders("Government") > 0)
	GameState.tick_self_sufficiency()
	check("seating the Chancellor lights the LABOUR chore",
		GameState.selfsuf_celebrated.has("staffing"), str(GameState.selfsuf_celebrated))

	# ---- THE FOG: a chore that automates while you're DEEP waits for homecoming ----
	GameState.in_dungeon = true
	roster.append({"id": "ss_bld", "name": "Hand", "sex": "Male", "is_kid": false,
		"stat_name": "Builderhouse", "stat_value": 4, "role_key": "Builderhouse", "role_title": "Worker"})
	check("the builder crew is on the books", GameState.count_workers("Builderhouse") > 0)
	GameState.tick_self_sufficiency()
	check("away in the deep, no reward pops (the village fog holds it)",
		not GameState.selfsuf_celebrated.has("repair"), str(GameState.selfsuf_celebrated))
	GameState.in_dungeon = false
	GameState.tick_self_sufficiency()
	check("...and it is celebrated the moment you walk back home",
		GameState.selfsuf_celebrated.has("repair"), str(GameState.selfsuf_celebrated))

	# ---- the loop is wired into the clock + survives the save ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the celebration ticks with the village clock",
		gs.contains("tick_self_sufficiency()"))
	check("which chores have been freed survives the save",
		gs.contains('"selfsuf_celebrated": selfsuf_celebrated')
		and gs.contains('selfsuf_celebrated = parsed.get("selfsuf_celebrated"'))
	check("a fresh run earns every beat again",
		gs.contains("selfsuf_celebrated = []"))
	var mm := FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text()
	check("the glance panel shows the self-reliance readout",
		mm.contains("Self-reliance") and mm.contains("village_self_sufficiency"))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.building_stage = saved_stage
	GameState.selfsuf_celebrated = saved_celeb
	GameState.dev_mode = saved_dev
	GameState.in_dungeon = saved_dungeon
	p.global_position = saved_pos
	printerr("test_selfsuf : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
