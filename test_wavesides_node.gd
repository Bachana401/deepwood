extends Node

# WAVES FROM THE DUNGEON + THE ORIN GATE (dev 2026-07-22): before Orin is freed
# (floor 15) every wave pours out of the DUNGEON -- the west/pit side ONLY -- and
# the game is gentler. Once Orin is out, the EAST road opens too, same as the
# left, UNANNOUNCED. Locks: pre-Orin one flank, post-Orin two, plus the gating.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func count_sides(west_x: float, east_x: float) -> Dictionary:
	var w := 0
	var e := 0
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r):
			continue
		if r.global_position.x < west_x:
			w += 1
		elif r.global_position.x > east_x:
			e += 1
	return {"w": w, "e": e}

func clear_sieges() -> void:
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if is_instance_valid(r):
			r.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	get_tree().paused = false

	var mgr = get_tree().get_first_node_in_group("siege_manager")
	var west_wall: Node = null
	var east_wall: Node = null
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == "west": west_wall = w
		elif "flank" in w and w.flank == "east": east_wall = w
	if mgr == null or west_wall == null or east_wall == null:
		check("siege_manager + both walls present in the village", false, "mgr/walls missing")
		printerr("test_wavesides : RESULT: 1 FAILURES  (FAILs=1)")
		get_tree().quit(1)
		return

	var s_depth: int = GameState.highest_unlocked_level
	var s_live: bool = GameState.live_siege_active
	var wx: float = west_wall.global_position.x
	var ex: float = east_wall.global_position.x

	await clear_sieges()

	# ---- PRE-ORIN: waves from the dungeon (west) ONLY ----
	GameState.highest_unlocked_level = 5
	GameState.live_siege_active = false
	mgr.start_live_siege(6, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var pre := count_sides(wx, ex)
	check("pre-Orin: the wave comes ONLY from the dungeon/west side", pre.e == 0 and pre.w > 0, str(pre))

	await clear_sieges()

	# ---- POST-ORIN: the east front opens too ----
	GameState.highest_unlocked_level = 20
	GameState.live_siege_active = false
	mgr.start_live_siege(6, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var post := count_sides(wx, ex)
	check("post-Orin: the wave ALSO strikes from the east", post.e > 0 and post.w > 0, str(post))

	await clear_sieges()

	# ---- the gating + gentler start, in source ----
	var sm := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the east front is gated on freeing Orin",
		sm.contains("GameState.orin_arrived()") and sm.contains("two_fronts"))
	check("the announcement never names the flanks (a silent second front)",
		not sm.contains("BOTH flanks"))
	check("the west wave approaches from the deep, further out",
		sm.contains("DUNGEON_APPROACH"))
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the pre-Orin waves are dampened (gentler start)",
		gs.contains("if not orin_arrived():") and gs.contains("* 0.6"))
	check("Black Tides hold off until Orin (min depth 15)",
		gs.contains("BLACK_TIDE_MIN_DEPTH := 15"))

	GameState.highest_unlocked_level = s_depth
	GameState.live_siege_active = s_live
	printerr("test_wavesides : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
