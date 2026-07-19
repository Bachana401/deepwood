extends Node

# Scene-TRANSITION integrity: the real village -> dungeon -> village loop, via
# the same calls the portal makes. This layer had no direct test, and it is
# exactly where the underground-spawn bug lived (a return position nothing set,
# below the floor). The harness node lives under root, so it survives both
# scene changes and can assert on each side.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _await_player(timeout_frames := 1200) -> Node:
	for i in range(timeout_frames):
		await get_tree().process_frame
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			return p
	return null

func _ready() -> void:
	var p: Node = await _await_player()
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false
	for i in range(30):
		await get_tree().physics_frame

	# ---- village side: seed a recognisable state ----
	p.inventory.add_item("wpn_katana", 1)
	var katana_count: int = p.inventory.get_count("wpn_katana")
	var hp_seed := maxi(1, int(p.get_max_health() * 0.6))
	p.health = hp_seed
	var village_pos: Vector2 = p.global_position
	var roster_size: int = GameState.rescued_villagers.size()
	check("village boot: the player stands on ground", p.is_on_floor())

	# ---- the portal, exactly as level_select_ui makes it ----
	GameState.pending_player_state = GameState.capture_player_state(p)
	GameState.pre_dungeon_position = p.global_position
	GameState.active_dungeon_level = 1
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	var dp: Node = null
	for i in range(1200):
		await get_tree().process_frame
		if GameState.in_dungeon:
			dp = get_tree().get_first_node_in_group("player")
			if dp != null and dp != p:
				break
	check("the dungeon takes over (in_dungeon set, fresh player)", dp != null and GameState.in_dungeon)
	if dp == null: printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return
	for i in range(40):
		await get_tree().physics_frame
	check("dungeon arrival: the player lands ON the floor, not in it", dp.is_on_floor(),
		"y=%.0f" % dp.global_position.y)
	check("the bag crossed the transition (katana intact)",
		dp.inventory.get_count("wpn_katana") == katana_count)
	check("wounds crossed the transition (health carried)", dp.health == hp_seed,
		"hp=%d want %d" % [dp.health, hp_seed])

	# ---- straight back out, as the exit button does ----
	var dungeon = get_tree().current_scene
	check("the dungeon root is the manager", dungeon != null and dungeon.has_method("exit_dungeon"))
	dungeon.exit_dungeon()
	var vp: Node = null
	for i in range(1200):
		await get_tree().process_frame
		if not GameState.in_dungeon:
			vp = get_tree().get_first_node_in_group("player")
			if vp != null and vp != dp:
				break
	check("the village takes back over", vp != null and not GameState.in_dungeon)
	if vp == null: printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return
	for i in range(40):
		await get_tree().physics_frame
	check("the return lands EXACTLY where you left (the underground-spawn bug)",
		vp.global_position.distance_to(village_pos) < 80.0,
		"returned %.0f px away" % vp.global_position.distance_to(village_pos))
	check("and on solid ground", vp.is_on_floor(), "y=%.0f" % vp.global_position.y)
	check("the bag survived the round trip", vp.inventory.get_count("wpn_katana") == katana_count)
	check("the roster survived the round trip", GameState.rescued_villagers.size() == roster_size,
		"%d -> %d" % [roster_size, GameState.rescued_villagers.size()])
	check("no stale carry-over state remains",
		GameState.pending_player_state.is_empty() and not GameState.returning_from_dungeon
		and not GameState.proving_grounds)
	check("the corps re-mustered in the village",
		get_tree().get_nodes_in_group("adventurer").size() >= 1)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
