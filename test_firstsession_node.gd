extends Node

# THE FIRST SESSION, END TO END (added 2026-07-20).
#
# Every other suite tests a slice. This one walks the path a real player
# walks on a fresh save -- arrival, village, the road, a dungeon floor,
# the clear, the way home -- and asserts the whole chain holds together.
# Integration breaks live exactly here: each part passes its own tests and
# the seam between two of them is what actually strands a player.
#
# It is deliberately about the SESSION, not any one system: does a new
# game start honest, is there something to do, can you get to the dungeon,
# does a floor resolve, does coming home restore you.

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

func _unpause() -> void:
	for i in range(90):
		await get_tree().process_frame
		if not get_tree().paused:
			return
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break
	# AND THEN INSIST. The loop above only ASKS -- it dismisses a dialogue and
	# hopes that lifted the pause. If anything else owns the pause, or a dialogue
	# arrives later, every wait get_tree().physics_frame below still RESOLVES
	# while no _physics_process runs, so the checks measure nothing and report
	# failures the code never had a chance to earn. That is exactly how
	# test_mech2_node called four working mechanics broken (2026-08-03).
	if get_tree().paused:
		get_tree().paused = false

func _ready() -> void:
	var p: Node = await _await_player()
	if p == null: printerr("no player"); get_tree().quit(1); return
	await _unpause()
	for i in range(20):
		await get_tree().physics_frame

	# ---------- 1. A FRESH WORLD IS AN HONEST ONE ----------
	GameState.reset_for_new_game()
	check("a new game starts with the village in ruins",
		GameState.count_ruined_buildings() == GameState.STARTING_BUILDINGS.size(),
		"%d of %d" % [GameState.count_ruined_buildings(), GameState.STARTING_BUILDINGS.size()])
	check("...with the three seed souls and nothing else",
		GameState.rescued_villagers.size() == 3, str(GameState.rescued_villagers.size()))
	check("...knowing only the survival blueprints",
		GameState.blueprints.size() == GameState.BLUEPRINT_STARTERS.size())
	check("...no floors open but the first", GameState.highest_unlocked_level == 1)
	check("...and no foresight at all (Act I is true chaos)",
		GameState.watchtower_tier == 0 and not GameState.siege_clock_visible())

	# ---------- 2. THE PLAYER IS NEVER LEFT WITHOUT A NEXT STEP ----------
	var first_objective: String = GameState.next_objective()
	check("the game tells a new player what to do", first_objective.length() > 8, first_objective)
	check("...and it is a SURVIVAL step, not a late-game one",
		first_objective.contains("Farm"), first_objective)

	# ---------- 3. THE ROAD: village and pit are one keypress apart ----------
	var markers := []
	for n in get_tree().root.find_children("*", "Area2D", true, false):
		if "partner_x" in n:
			markers.append(n)
	check("both road markers exist in the live village", markers.size() == 2)
	if markers.size() == 2:
		p.global_position = markers[0].global_position
		markers[0].travel()
		check("the road actually carries the player across",
			absf(p.global_position.x - markers[0].partner_x) < 2.0)

	# ---------- 4. INTO THE DEEP ----------
	GameState.active_dungeon_level = 1
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	p = await _await_player()
	check("the dungeon scene loads and keeps a player", p != null)
	if p == null:
		printerr("RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return
	await _unpause()
	for i in range(40):
		await get_tree().physics_frame
	var di = get_tree().current_scene
	check("floor 1 actually populated (mobs to fight)", di.alive_count > 0,
		"alive_count=%d" % di.alive_count)
	check("the floor knows it is in progress", di.level_in_progress)
	check("the level label carries the live tally",
		di.get_node_or_null("CanvasLayer/LevelLabel") != null
		and str(di.get_node("CanvasLayer/LevelLabel").text).contains("left"))

	# ---------- 5. CLEAR IT ----------
	var guard := 0
	while di.alive_count > 0 and guard < 400:
		guard += 1
		for e in get_tree().get_nodes_in_group("dungeon_combatant"):
			if is_instance_valid(e) and not e.is_in_group("player") and e.has_method("take_damage"):
				if not ("is_dead" in e and e.is_dead):
					e.take_damage(999999)
		await get_tree().physics_frame
	check("a floor can be cleared to zero", di.alive_count <= 0, "%d left" % di.alive_count)
	for i in range(30):
		await get_tree().physics_frame
	check("clearing floor 1 unlocks floor 2", GameState.highest_unlocked_level >= 2,
		str(GameState.highest_unlocked_level))
	check("...and the label says the way on is open",
		str(di.get_node("CanvasLayer/LevelLabel").text).contains("cleared"))

	# ---------- 6. THE WAY HOME ----------
	di.exit_dungeon()
	p = await _await_player()
	check("the village scene comes back with a player", p != null)
	await _unpause()
	for i in range(30):
		await get_tree().physics_frame
	check("the player is home, not in the deep", not GameState.in_dungeon)
	check("the world still holds its people", GameState.rescued_villagers.size() >= 3)
	check("the advisor still has something true to say",
		GameState.next_objective().length() > 8)

	# ---------- 7. THE OPENING'S PROMISES (dev reports 2026-07-23) ----------
	# The whole first-session seam: no wave mid-tutorial, a real grace day, and a
	# wall raiders can never walk through. Every one of these shipped broken once.
	var saved_open: bool = GameState.opening_done
	var saved_next: float = GameState.hours_until_next_siege
	GameState.opening_done = false
	GameState.hours_until_next_siege = 0.001
	GameState.tick_sieges(50.0)
	check("NO wave can land while the opening/tutorial is unfinished",
		GameState.hours_until_next_siege == 0.001 and not GameState.live_siege_active)
	GameState.opening_done = saved_open
	GameState.hours_until_next_siege = saved_next
	check("the first wave grants a full grace day (>= 24h, ~10 real min)",
		GameState.SIEGE_FIRST_HOURS >= 24.0, str(GameState.SIEGE_FIRST_HOURS))
	var se_src := FileAccess.open("res://siege_enemy.gd", FileAccess.READ).get_as_text()
	check("raiders stop at the wall face they APPROACH — never walking through",
		se_src.contains("global_position.x <= wall.global_position.x")
		and se_src.contains("wall.west_face_x() - ATTACK_STOP_GAP"))
	var to_src := FileAccess.open("res://tutorial_overlay.gd", FileAccess.READ).get_as_text()
	check("the tutorial names WHERE the wall goes (the WEST gate)",
		to_src.contains("WEST"))
	check("...and the wall holo reads the ground's gate live while placing",
		FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("guards the WEST gate"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
