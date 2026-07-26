extends Node
# CONTINUE MUST NOT SPAWN YOU UNDERGROUND (dev report 2026-07-22: "pressed Continue,
# spawned underground, fell forever"). The Underdark lives inside the village scene,
# so a save made in the caves -- or the floor-cleared auto-save, which records the
# deep Underdark DOOR -- would drop the player into the deep, and into the void
# before its collision is built. Three guards, all proven here:
#   1. save_game never PERSISTS a deep position (surface spawn instead),
#   2. apply_save_data never LOADS one (rescues already-broken saves),
#   3. the player has a void safety net (falls far below solid ground -> recover).

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
	for i in range(20):
		await get_tree().process_frame

	# ---- 1. the SAVE never persists an underground position ----
	GameState.in_dungeon = false
	p.global_position = Vector2(5000.0, 9000.0)      # deep in the Underdark
	GameState.save_game(p)
	var d1: Dictionary = GameState.load_game()
	check("a save made in the caves persists a SURFACE spawn, not the deep",
		float(d1.get("position_y", 0.0)) <= 250.0, "saved y=%.0f" % float(d1.get("position_y", 0.0)))
	# ...and the floor-cleared auto-save (in_dungeon -> the deep door) is safe too
	GameState.in_dungeon = true
	GameState.pre_dungeon_position = Vector2(6000.0, 8000.0)
	GameState.save_game(p)
	var d2: Dictionary = GameState.load_game()
	GameState.in_dungeon = false
	check("the floor-cleared save (a deep door) also persists a surface spawn",
		float(d2.get("position_y", 0.0)) <= 250.0, "saved y=%.0f" % float(d2.get("position_y", 0.0)))

	# ---- 3. the void safety net recovers a fall out of the world ----
	# the player must actually physics-process, so clear any opening dialogue pause
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
	get_tree().paused = false
	p.god_mode = true                                    # don't let anything kill it mid-test
	p.has_touched_ground = true
	p._last_ground_pos = Vector2(100.0, -39.0)
	p.global_position = Vector2(100.0, -39.0 + 3000.0)   # fell 3000px below solid ground
	p.velocity = Vector2.ZERO
	for i in range(4):
		await get_tree().physics_frame
	check("falling far below the last ground snaps you back to it (no fall-forever)",
		p.global_position.distance_to(Vector2(100.0, -39.0)) < 80.0,
		"landed at %s" % str(p.global_position))

	# ---- 2. LOADING an already-broken underground save lands you on the surface ----
	# craft a valid save, then force its position deep (as an old pre-fix save would
	# have), and Continue into it.
	GameState.in_dungeon = false
	p.global_position = Vector2(-300.0, -150.0)
	GameState.save_game(p)                             # a complete, valid save file
	var raw := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	var save: Dictionary = JSON.parse_string(raw.get_as_text())
	raw.close()
	save["position_x"] = 0.0
	save["position_y"] = 0.0                            # the ACTUAL bug: a (0,0) origin save,
	                                                    # below the village floor (surface y=-39)
	var w := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	w.store_string(JSON.stringify(save))
	w.close()
	GameState.pending_load = true
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	for i in range(360):        # let the old scene free and the new one boot + apply_save_data
		await get_tree().process_frame
	var np: Node = get_tree().get_first_node_in_group("player")
	# must land ON the surface (y <= -50), not merely shallower than the deep -- a (0,0)
	# origin is well above 250 yet still under the floor, so the old >250 clamp missed it.
	check("Continue on a below-ground (0,0) save lands you SAFE on the surface", np != null and np.global_position.y <= -50.0,
		"player at %s" % (str(np.global_position) if np else "null"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
