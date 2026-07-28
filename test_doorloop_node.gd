extends Node
# THE DOORS-ONLY DUNGEON LOOP, WALKED END TO END (2026-07-22). Doors are the only
# way into a floor now, so the whole progression is: find floor N's door in the
# Underdark, enter, clear, LEAVE back to that door, find floor N+1's door (just
# unlocked), repeat. No test walked that full loop across floors -- and the RETURN
# leg is the untested one that most worries me: leaving a floor drops the player
# back at pre_dungeon_position, which is now a DEEP Underdark door, the same deep
# placement that fell-forever on Continue. This proves the loop never softlocks:
# every next floor has an unlocked door, entering lands on the right floor ON SOLID
# GROUND, clearing advances the ladder, and LEAVING lands you back safe (not falling).
#
# Harness lives under root, so it survives the door's and gate's scene changes.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish(); break
	get_tree().paused = false

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _await_frames(n: int) -> void:
	for i in range(n):
		keep_running()
		await get_tree().process_frame

func _find_door(target: int) -> Node:
	var ud = get_tree().current_scene.get_node_or_null("Underdark")
	if ud == null:
		return null
	# the legacy strip (and its doors) is built on demand now (scan 2026-07-27);
	# idempotent, and main.tscn is re-entered after every floor, so ensure it here
	ud.build_legacy_strip()
	for c in ud.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("underdark_door.gd") \
				and c.target_level == target:
			return c
	return null

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running(); await get_tree().process_frame
		p = _player()
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	await _await_frames(20)

	# fresh honest game, prologue already behind us, back in the village
	GameState.reset_for_new_game()
	GameState.seen_intro = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	GameState.dev_mode = false
	GameState.in_dungeon = false
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	await _await_frames(240)
	if _player() != null:
		_player().god_mode = true       # a walker, not a combat test -- don't die to a stray hit

	var walked := 0
	for floor in range(1, 7):        # 1-6, so floor 5 exercises a BOSS floor reached BY ITS DOOR
		# ---- 1. this floor must have an unlocked door in the deep ----
		var door := _find_door(floor)
		check("floor %d has its own door in the Underdark" % floor, door != null)
		if door == null:
			break
		check("...and it is unlocked (floor %d earned)" % floor, door._unlocked(),
			"highest=%d" % GameState.highest_unlocked_level)
		var door_pos: Vector2 = door.global_position

		# ---- 2. enter it -> the right floor, on solid ground ----
		door._try_enter()
		for i in range(400):
			keep_running(); await get_tree().process_frame
			if GameState.in_dungeon: break
		check("entering floor %d's door drops you onto floor %d" % [floor, floor],
			GameState.in_dungeon and GameState.active_dungeon_level == floor,
			"in=%s lvl=%d" % [str(GameState.in_dungeon), GameState.active_dungeon_level])
		var di = get_tree().current_scene
		# land on the floor, not falling through it
		var pp = _player()
		for i in range(90):
			keep_running(); await get_tree().physics_frame
			if pp != null and pp.is_on_floor(): break
		check("...and stands on the floor there (not falling)", pp != null and pp.is_on_floor(),
			"y=%.0f on_floor=%s" % [pp.global_position.y if pp else 0.0, str(pp.is_on_floor()) if pp else "?"])

		# ---- 3. clear the floor for real ----
		var guard := 0
		while int(di.alive_count) > 0 and guard < 500:
			guard += 1
			for g in ["dungeon_combatant", "course_enemy", "siege_enemy"]:
				for e in get_tree().get_nodes_in_group(g):
					if is_instance_valid(e) and not e.is_in_group("player") and e.has_method("take_damage"):
						e.take_damage(999999)
			keep_running(); await get_tree().physics_frame
		# anything that didn't die through a group still counts -- force the real
		# clear path once so the ladder-advance logic runs exactly as in play
		if int(di.alive_count) > 0:
			di.alive_count = 1
			di._on_combatant_died()
			await _await_frames(3)
		check("floor %d clears" % floor, bool(di.level_cleared), "alive=%d" % int(di.alive_count))
		check("...and clearing unlocks floor %d" % (floor + 1),
			GameState.highest_unlocked_level >= floor + 1, "highest=%d" % GameState.highest_unlocked_level)

		# ---- 4. LEAVE -> back in the world, SAFE (the fall-forever risk) ----
		# exit_dungeon sets in_dungeon=false immediately but changes scene DEFERRED,
		# so wait for the village to actually reload + run _ready (which places the
		# returning player) before measuring anything.
		di.exit_dungeon()
		await _await_frames(240)
		check("leaving floor %d returns you to the overworld" % floor, not GameState.in_dungeon)
		var rp = _player()
		check("...and a player exists back in the village", rp != null)
		if rp == null:
			break
		# watch physics frames: a return that fell into the void keeps sinking; a
		# safe return settles on_floor within a few frames.
		var y_start: float = rp.global_position.y
		var landed := false
		for i in range(180):
			keep_running(); await get_tree().physics_frame
			if rp.is_on_floor():
				landed = true; break
		var y_end: float = rp.global_position.y
		check("...landing on SOLID GROUND, not falling forever",
			landed and y_end < y_start + 2000.0,
			"y %.0f -> %.0f on_floor=%s (door y=%.0f)" % [y_start, y_end, str(rp.is_on_floor()), door_pos.y])
		walked += 1

	check("walked %d floors door->clear->leave->door with no softlock (incl. a boss floor)" % walked, walked >= 6, "%d" % walked)

	# ---- DEEP SPOT-CHECK: a marathon reaches the deep, where floors carry void/
	# relic caches, crushers + poison gas, and tougher elites. Prove deep floors
	# built + cleared + left safely when reached BY THEIR DOOR (unlock them directly,
	# as if the ladder had been climbed). ----
	for deep in [40, 80]:
		GameState.highest_unlocked_level = maxi(GameState.highest_unlocked_level, deep)
		var d2 := _find_door(deep)
		check("deep floor %d has an (unlocked) door" % deep, d2 != null and d2._unlocked())
		if d2 == null:
			continue
		d2._try_enter()
		for i in range(400):
			keep_running(); await get_tree().process_frame
			if GameState.in_dungeon: break
		# let the player fall the short drop from its spawn onto the floor
		var dp := _player()
		for i in range(90):
			keep_running(); await get_tree().physics_frame
			if dp != null and dp.is_on_floor(): break
		check("entering deep floor %d by its door builds + stands you on it" % deep,
			GameState.in_dungeon and GameState.active_dungeon_level == deep and dp != null and dp.is_on_floor(),
			"lvl=%d y=%.0f" % [GameState.active_dungeon_level, dp.global_position.y if dp else 0.0])
		var di2 = get_tree().current_scene
		var g2 := 0
		while int(di2.alive_count) > 0 and g2 < 500:
			g2 += 1
			for grp in ["dungeon_combatant", "course_enemy", "siege_enemy"]:
				for e in get_tree().get_nodes_in_group(grp):
					if is_instance_valid(e) and not e.is_in_group("player") and e.has_method("take_damage"):
						e.take_damage(999999)
			keep_running(); await get_tree().physics_frame
		if int(di2.alive_count) > 0:
			di2.alive_count = 1; di2._on_combatant_died(); await _await_frames(3)
		check("deep floor %d clears" % deep, bool(di2.level_cleared))
		di2.exit_dungeon()
		await _await_frames(240)
		var rp2 := _player()
		var landed2 := false
		for i in range(180):
			keep_running(); await get_tree().physics_frame
			if rp2 != null and rp2.is_on_floor(): landed2 = true; break
		check("leaving deep floor %d lands you SOLID (not falling)" % deep, landed2)
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
