extends Node

# THE VILLAGE LOG (GAME_BIBLE 5.9). The diary's contract: timestamped in-game
# (day + hour), newest first, ring-buffered, written in plain language from
# every event worth surfacing, and readable in BOTH scenes with L.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	var saved_log: Array = GameState.village_log
	var saved_hours: float = GameState.game_hours

	# ---- the entry itself: stamp, order, ring ----
	GameState.village_log = []
	GameState.game_hours = 50.0   # day 3, 02:00
	GameState.log_event("people", "first")
	GameState.log_event("combat", "second")
	check("newest first", str(GameState.village_log[0].get("text", "")) == "second")
	check("stamped with the in-game day and hour",
		int(GameState.village_log[0].get("day", 0)) == 3
		and int(GameState.village_log[0].get("hour", -1)) == 2)
	for i in range(GameState.LOG_MAX_ENTRIES + 30):
		GameState.log_event("village", "spam %d" % i)
	check("the diary is a ring, not a landfill",
		GameState.village_log.size() == GameState.LOG_MAX_ENTRIES)

	# ---- every event worth surfacing writes a line ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("rescues are written", gs.contains("freed from the dark, reached the village"))
	check("births are written (hero and common)",
		gs.contains("had a child — welcome") and gs.contains("was born a HERO"))
	check("graduations are written", gs.contains("finished school — a"))
	check("a couple making a home is written", gs.contains("made a cottage their home"))
	check("deaths are written", gs.contains("Deepwood grieves"))
	check("away sieges are written, both outcomes",
		gs.contains("the defense held") and gs.contains("could not hold it all"))
	check("a live wall holding is written", gs.contains("The wave broke against the wall"))
	check("a fallen adventurer is written by NAME", gs.contains("fell holding the line"))
	check("a freed legend is written", gs.contains("walks free of Orin's vaults"))
	check("a corruption turning is written", gs.contains("hope broke — they turned"))
	check("spirit milestones are written, both edges",
		gs.contains("spirit is failing") and gs.contains("Hope returns to Deepwood"))
	var bg := FileAccess.open("res://building.gd", FileAccess.READ).get_as_text()
	check("a building rising again is written", bg.contains("stands again"))
	var cp := FileAccess.open("res://cottage_plot.gd", FileAccess.READ).get_as_text()
	check("a raised cottage is written", cp.contains("A new cottage was raised"))

	# ---- the reader ----
	check("the diary survives the save", gs.contains('"village_log": village_log'))
	var ui := FileAccess.open("res://village_log_ui.gd", FileAccess.READ).get_as_text()
	check("L opens it, ESC closes it like any window",
		ui.contains("log_toggle") and ui.contains("esc_window")
		and ui.contains("func esc_is_open") and ui.contains("func esc_close"))
	var pg := FileAccess.open("res://project.godot", FileAccess.READ).get_as_text()
	check("the L key is a real input action", pg.contains("log_toggle={"))
	var mn := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	var di := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the diary rides along in BOTH scenes",
		mn.contains("village_log_ui.gd") and di.contains("village_log_ui.gd"))
	var live_ui = get_tree().root.find_children("*", "CanvasLayer", true, false)
	var found_log_ui := false
	for c in live_ui:
		if c.has_method("esc_is_open") and c.has_method("toggle") and "filter_buttons" in c:
			found_log_ui = true
	check("the log UI is alive in the running scene", found_log_ui)

	# ---- THE HOMECOMING: unseen entries are COUNTED and pointed at ----
	var saved_unread: int = GameState.log_unread
	var saved_dungeon2: bool = GameState.in_dungeon
	var saved_skills2 = GameState.unlocked_skills.duplicate(true)
	var log_p = get_tree().get_first_node_in_group("player")
	var saved_pos2: Vector2 = log_p.global_position
	GameState.unlocked_skills = []
	GameState.log_unread = 0
	GameState.in_dungeon = true               # the fog is down
	GameState.log_event("people", "something happened while away")
	check("what you cannot see is counted as unread", GameState.log_unread == 1)
	# NB the world spawn sits ~5000px WEST of the village, so "not in the
	# dungeon" is not the same as "at home" -- stand in the village itself
	GameState.in_dungeon = false
	log_p.global_position = Vector2(5000.0, -100.0)
	GameState.log_event("people", "something you witnessed")
	check("what you witness at home is NOT unread", GameState.log_unread == 1)
	GameState.unlocked_skills = ["mg_t1"]     # Telepathy
	GameState.in_dungeon = true
	log_p.global_position = saved_pos2
	GameState.log_event("people", "watched live by telepathy")
	check("with Telepathy nothing accumulates -- you saw it all live",
		GameState.log_unread == 1)
	check("the homecoming points at the diary",
		FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("press L to read the diary"))
	check("opening the diary marks it read",
		FileAccess.open("res://village_log_ui.gd", FileAccess.READ).get_as_text().contains("log_unread = 0"))
	check("the unread count survives the save",
		gs.contains('"log_unread": log_unread'))
	GameState.unlocked_skills = saved_skills2
	GameState.in_dungeon = saved_dungeon2
	GameState.log_unread = saved_unread
	log_p.global_position = saved_pos2

	GameState.village_log = saved_log
	GameState.game_hours = saved_hours
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
