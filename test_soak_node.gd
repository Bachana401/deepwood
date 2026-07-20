extends Node

# THE SOAK (built for the marathon playtest): a long session in miniature.
#
# A 4-5 hour sitting is not one big moment -- it is thousands of small
# ones: scene changes, autosave ticks, sieges resolving, days rolling
# over, the same systems drummed on until something slow-burn gives out.
# This suite compresses that: TEN village->dungeon->village round trips
# (the transition suite does one), then SIX simulated game-days of the
# real master tick over a staffed, living town with sieges landing.
# The harness greps the output: any SCRIPT ERROR during the soak is a
# finding, whether or not an assertion fires.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _await_player(frames := 1200) -> Node:
	for i in range(frames):
		await get_tree().process_frame
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			return pl
	return null

func _ready() -> void:
	var p: Node = await _await_player()
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(90):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false
	for i in range(10):
		await get_tree().physics_frame

	# a living town for the whole soak
	GameState.reset_for_new_game()
	GameState.village_food = 100000.0
	for b in ["Farm", "Tavern", "Hospital", "Barracks", "Government"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100
	for i in range(8):
		GameState.rescue_villager({"id": "soak_%d" % i, "name": "Soul %d" % i,
			"sex": "Male" if i % 2 == 0 else "Female", "is_kid": i >= 6,
			"stat_name": "Farm", "stat_value": 3,
			"role_key": "Farm" if i < 3 else "", "role_title": "Farmer" if i < 3 else ""})

	# ---------- 1. TEN ROUND TRIPS ----------
	var trips_ok := 0
	for trip in range(10):
		GameState.active_dungeon_level = 1 + (trip % 5)
		get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
		p = await _await_player()
		if p == null: break
		for i in range(15):
			await get_tree().physics_frame
		var di = get_tree().current_scene
		if di == null or not GameState.in_dungeon: break
		di.exit_dungeon()
		p = await _await_player()
		if p == null: break
		for i in range(15):
			await get_tree().physics_frame
		if GameState.in_dungeon: break
		trips_ok += 1
	check("ten village->dungeon->village round trips survive", trips_ok == 10,
		"%d/10" % trips_ok)
	check("the roster survives the churn", GameState.rescued_villagers.size() >= 8,
		str(GameState.rescued_villagers.size()))

	# ---------- 2. SIX GAME-DAYS OF THE REAL TICK ----------
	p = get_tree().get_first_node_in_group("player")
	p.currency = 3000
	var start_hours: float = GameState.game_hours
	# the master tick IS GameState._process; a game day is 600 real seconds,
	# so six days = 1440 ticks of 2.5s
	for step in range(1440):
		GameState._process(2.5)
		if step % 120 == 0:
			await get_tree().process_frame
	var days: float = (GameState.game_hours - start_hours) / 24.0
	check("six days actually pass on the clock", days >= 5.0, "%.1f days" % days)
	check("the world stays finite: gold sane", p.currency >= 0 and p.currency < 10_000_000, str(p.currency))
	check("...food sane", GameState.village_food >= 0.0 and not is_nan(GameState.village_food))
	check("...morale sane", GameState.village_morale() >= 0 and GameState.village_morale() <= 100)
	check("...roster free of ghosts",
		(func():
			for v in GameState.rescued_villagers:
				if str(v.get("id", "")) == "" or str(v.get("name", "")) == "":
					return false
			return true).call())
	check("the log kept the days' stories without overflowing",
		GameState.village_log.size() <= GameState.LOG_MAX_ENTRIES)

	# ---------- 3. THE JOURNAL RIDES IN BOTH SCENES ----------
	check("the F8 field journal is mounted in the village",
		get_tree().get_first_node_in_group("playtest_journal") != null)
	check("...and in the dungeon scene's source",
		FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text().contains("playtest_journal.gd"))
	check("crash file-logging is armed for the marathon",
		FileAccess.open("res://project.godot", FileAccess.READ).get_as_text().contains("enable_file_logging=true"))
	# a note actually lands on disk, context attached
	var journal = get_tree().get_first_node_in_group("playtest_journal")
	if journal != null:
		var had_file: bool = FileAccess.file_exists(journal.NOTES_PATH)
		var before_txt := ""
		if had_file:
			before_txt = FileAccess.open(journal.NOTES_PATH, FileAccess.READ).get_as_text()
		journal._append_note("soak self-test")
		var after_txt := FileAccess.open(journal.NOTES_PATH, FileAccess.READ).get_as_text()
		check("an F8 note lands in the file with its context stamp",
			after_txt.contains("soak self-test") and after_txt.contains("day "))
		if had_file:
			var wf := FileAccess.open(journal.NOTES_PATH, FileAccess.WRITE)
			wf.store_string(before_txt)         # leave no trace
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(journal.NOTES_PATH))

	GameState.reset_for_new_game()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
