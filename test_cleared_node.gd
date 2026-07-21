extends Node
# "MOBS NEVER RESPAWN AS LONG AS PLAYER KILLED THAT LEVEL" (dev rule
# 2026-07-21). A swept floor stays swept -- across a walk home, across a
# save/load, across any amount of time. Only a NEW GAME unsweeps the deep.

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _await_player() -> Node:
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			return pl
	return null

func _ready() -> void:
	var p: Node = await _await_player()
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		keep_running()
		await get_tree().process_frame
	p.god_mode = true
	GameState.highest_unlocked_level = 5

	# ---- 1. a fresh floor is populated ----
	GameState.active_dungeon_level = 2
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	p = await _await_player()
	for i in range(30):
		keep_running()
		await get_tree().physics_frame
	var di = get_tree().current_scene
	check("an unswept floor spawns its holders", di.alive_count > 0, "%d alive" % di.alive_count)
	check("...and is not marked cleared yet", not GameState.floor_is_cleared(2))

	# ---- 2. clear it the way a player does: kill everything ----
	for e in get_tree().get_nodes_in_group("dungeon_combatant"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(999999)
	for i in range(180):
		keep_running()
		await get_tree().physics_frame
		if di.level_cleared:
			break
	check("killing the floor clears it", di.level_cleared, "alive %d" % di.alive_count)
	check("...and the clear is RECORDED, not just local", GameState.floor_is_cleared(2))

	# ---- 3. leave, come back: it must still be empty ----
	di.exit_dungeon()
	p = await _await_player()
	for i in range(20):
		keep_running()
		await get_tree().physics_frame
	GameState.active_dungeon_level = 2
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	p = await _await_player()
	for i in range(40):
		keep_running()
		await get_tree().physics_frame
	di = get_tree().current_scene
	check("walking back in finds it STILL empty", di.alive_count == 0, "%d respawned" % di.alive_count)
	check("...and it reads as cleared on arrival", di.level_cleared)
	var live := 0
	for e in get_tree().get_nodes_in_group("dungeon_combatant"):
		if is_instance_valid(e) and not ("is_dead" in e and e.is_dead):
			live += 1
	check("...with not one living body in the level", live == 0, "%d bodies" % live)

	# ---- 4. an UNcleared floor still fights ----
	di.go_to_level(3, false)
	for i in range(40):
		keep_running()
		await get_tree().physics_frame
	check("a floor you never swept still holds its mobs", di.alive_count > 0,
		"%d alive on 3" % di.alive_count)

	# ---- 5. the record survives a save/load round trip ----
	GameState.save_game(p)
	var before: bool = GameState.floor_is_cleared(2)
	GameState.floors_cleared = {}
	GameState.load_game()
	check("a save/load keeps the swept floors swept",
		before and GameState.floor_is_cleared(2))
	check("...and does not invent clears for floors you never touched",
		not GameState.floor_is_cleared(3))

	# ---- 6. a NEW GAME unsweeps the deep ----
	GameState.reset_for_new_game()
	check("New Game starts with an unswept deep", not GameState.floor_is_cleared(2),
		"%d floors still marked" % GameState.floors_cleared.size())

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
