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

	# ---- death in the dungeon: the loop nobody had tested ----
	GameState.pending_player_state = GameState.capture_player_state(vp)
	GameState.pre_dungeon_position = vp.global_position
	GameState.active_dungeon_level = 1
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	var dp2: Node = null
	for i in range(1200):
		await get_tree().process_frame
		if GameState.in_dungeon:
			dp2 = get_tree().get_first_node_in_group("player")
			if dp2 != null and dp2 != vp:
				break
	for i in range(40):
		await get_tree().physics_frame
	GameState.TEST_INSTANT_RESPAWN = true
	GameState.difficulty = "Medium"
	var villagers_pre_death: int = GameState.rescued_villagers.size()
	dp2.currency = 100
	dp2.god_mode = false
	var spawn_ref: Vector2 = dp2.spawn_position
	dp2.die()
	for i in range(60):
		await get_tree().physics_frame
	check("death in the dungeon respawns AT the dungeon entry, alive",
		not dp2.is_dead and dp2.global_position.distance_to(spawn_ref) < 120.0,
		"%.0f px from entry" % dp2.global_position.distance_to(spawn_ref))
	check("...at full health", dp2.health == dp2.get_max_health())
	check("...having dropped 77%% of carried gold", dp2.currency == 23, "%d left" % dp2.currency)
	check("...and Medium's price was paid: one villager taken",
		GameState.rescued_villagers.size() == villagers_pre_death - 1,
		"%d -> %d" % [villagers_pre_death, GameState.rescued_villagers.size()])
	GameState.TEST_INSTANT_RESPAWN = false

	# ---- the admin Proving Grounds round trip (the reported spawn bug's path) ----
	get_tree().current_scene.exit_dungeon()
	var vp2: Node = null
	for i in range(1200):
		await get_tree().process_frame
		if not GameState.in_dungeon:
			vp2 = get_tree().get_first_node_in_group("player")
			if vp2 != null and vp2 != dp2:
				break
	for i in range(40):
		await get_tree().physics_frame
	var panel: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("_enter_proving_grounds"):
			panel = n
			break
	check("the admin panel is reachable", panel != null)
	if panel != null:
		var before_pg: Vector2 = vp2.global_position
		panel._enter_proving_grounds()
		var pg: Node = null
		for i in range(1200):
			await get_tree().process_frame
			if GameState.proving_grounds and GameState.in_dungeon:
				pg = get_tree().get_first_node_in_group("player")
				if pg != null and pg != vp2:
					break
		check("the Proving Grounds opens via the panel", pg != null and GameState.proving_grounds)
		if pg != null:
			for i in range(40):
				await get_tree().physics_frame
			check("the arena floor holds you", pg.is_on_floor())
			get_tree().current_scene.exit_dungeon()
			var vp3: Node = null
			for i in range(1200):
				await get_tree().process_frame
				if not GameState.in_dungeon:
					vp3 = get_tree().get_first_node_in_group("player")
					if vp3 != null and vp3 != pg:
						break
			for i in range(40):
				await get_tree().physics_frame
			check("leaving the arena returns you WHERE YOU WERE (the reported bug)",
				vp3 != null and vp3.global_position.distance_to(before_pg) < 80.0,
				"%.0f px away" % (vp3.global_position.distance_to(before_pg) if vp3 else -1.0))
			check("...on solid ground, not inside it", vp3 != null and vp3.is_on_floor())
			check("the arena flag never leaks home", not GameState.proving_grounds)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
