extends Node
# EYES (dev 2026-07-23: "you keep saying you checked every angle, but i find bugs
# in literally 5 seconds of play"). Static sweeps cannot SEE the game; this can.
# Boots the REAL rendered game (run WINDOWED, not --headless -- screenshots need a
# live viewport), plays through beats on real input, and saves a screenshot at each
# for visual inspection.
#
#   MONARCH_TEST="res://tool_eyes.gd" Godot.exe --path .        (no --headless!)
#
# v2: robustly clears dialog + forces opening_done before opening the menus (they
# were blocked by the arrival banter in v1), and covers build/inventory/skill/log.

var shot_dir := "user://eyes"
var _n := 0

func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("EYES: no player"); get_tree().quit(1); return

	# ---- beat 1: the opening as first seen (dialog up, HUD hidden) ----
	await _settle(1.0)
	await _shot("01_opening")

	# ---- fully leave the opening: finish every box, mark it done, unpause ----
	await _clear_dialog()
	GameState.opening_done = true

	# ---- put us in the village proper, mid-game feel ----
	var vx := 5600.0
	for b in get_tree().get_nodes_in_group("building"):
		vx = b.global_position.x; break
	p.global_position = Vector2(vx - 120.0, -120.0)
	await _settle(1.2)
	await _shot("02_village")

	# ---- the MENUS, each on a clean (dialog-free, unpaused) frame ----
	await _menu_shot("03_build_menu", "build_menu")
	await _menu_shot("04_inventory", "toggle_inventory")
	await _menu_shot("05_village_log", "log_toggle")

	# skill tree toggles on a raw key -> open its panel node directly
	await _clear_dialog()
	var st = _find_by_method("build_xp_bar")
	if st != null and "panel" in st:
		st.panel.visible = true
		if st.has_method("refresh"):
			st.refresh()
		await _settle(1.0)
		await _shot("06_skill_tree")
		st.panel.visible = false

	# ---- assign panel: click a building to see the worker UI (open by proximity) ----
	await _clear_dialog()
	var bld = get_tree().get_first_node_in_group("building")
	if bld != null:
		p.global_position = bld.global_position + Vector2(0, -40)
		await _settle(0.6)
		_tap("interact")
		await _settle(1.0)
		await _shot("07_building_interact")

	say("EYES: done, %d shots in %s" % [_n, shot_dir])
	get_tree().quit(0)

# ------------------------------------------------------------------ helpers
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
	_n += 1
	say("EYES: shot %s" % name)

func _menu_shot(name: String, action: String) -> void:
	await _clear_dialog()
	_tap(action)
	await _settle(1.0)
	await _shot(name)
	_tap(action)                 # close
	await _settle(0.3)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

# finish EVERY dialogue box on screen, then unpause -- repeat, since finishing
# one box can chain to the next (the opening is a chain of them)
func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish()
				found = true
		get_tree().paused = false
		await _settle(0.2)
		if not found and not get_tree().paused:
			return

func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press(action)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action; up.pressed = false
	Input.parse_input_event(up)
	Input.action_release(action)

func _find_by_method(m: String) -> Node:
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method(m):
			return n
	return null
