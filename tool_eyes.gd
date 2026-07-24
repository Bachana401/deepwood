extends Node
# EYES (dev 2026-07-23: "you keep saying you checked every angle, but i find bugs
# in literally 5 seconds of play"). Static sweeps cannot SEE the game; this can.
# It boots the REAL rendered game (run WINDOWED, not --headless -- screenshots
# need a live viewport), plays the first minutes through the REAL input actions,
# and saves a screenshot at every beat for visual inspection.
#
#   MONARCH_TEST="res://tool_eyes.gd" Godot.exe --path .        (no --headless!)
#
# Shots land in EYES_DIR. Each beat is time-boxed so a stuck beat can never hang
# the run -- worst case the shot just shows the stuck state, which is the point.

var shot_dir := "user://eyes"       # overridden by EYES_DIR env if set
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

	# ---- beat 1: the opening as the player first sees it (dialog up, HUD hidden)
	await _settle(1.2)
	await _shot("01_opening")

	# ---- advance the prologue the way tests do (finish each box), then look again
	for i in range(12):
		_finish_dialog()
		await _settle(0.3)
		if not get_tree().paused:
			break
	get_tree().paused = false
	await _shot("02_after_prologue")

	# ---- beat 2: WALK east on the real input action for a while -- the road
	Input.action_press("move_right")
	await _settle(6.0)
	await _shot("03_road_east")

	# keep walking toward the wall until the arrival scene arms or ~14s pass
	var t := 0.0
	while t < 14.0 and not GameState.seen_arrival_battle:
		if get_tree().paused:
			break                       # banter began -- stop walking, look at it
		await _settle(0.5); t += 0.5
	Input.action_release("move_right")
	await _shot("04_arrival_scene")

	# ---- the staged fight -> real fight (finish the banter, watch the brawl)
	for i in range(8):
		_finish_dialog()
		await _settle(0.3)
		if not get_tree().paused:
			break
	get_tree().paused = false
	await _settle(2.0)
	await _shot("05_gate_fight")

	# ---- beat 3: stand in the village proper and look at it
	var vx := 5600.0
	for b in get_tree().get_nodes_in_group("building"):
		vx = b.global_position.x; break
	p.global_position = Vector2(vx - 200.0, -120.0)
	await _settle(1.5)
	await _shot("06_village")

	# ---- beat 4: the build menu, as the player opens it
	_tap("build_menu")
	await _settle(1.0)
	await _shot("07_build_menu")
	_tap("build_menu")                  # close

	# ---- beat 5: the inventory
	_tap("toggle_inventory")
	await _settle(1.0)
	await _shot("08_inventory")
	_tap("toggle_inventory")

	# ---- beat 6: the village log (L)
	_tap("log_toggle")
	await _settle(1.0)
	await _shot("09_village_log")
	_tap("log_toggle")

	say("EYES: done, %d shots in %s" % [_n, shot_dir])
	get_tree().quit(0)

# ------------------------------------------------------------------ helpers
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_dir.path_join(name + ".png")
	img.save_png(path)
	_n += 1
	say("EYES: shot %s" % path)

# create_timer(process_always=true) so waits keep ticking through pauses
func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

# fire an action through BOTH input paths: the polled API (is_action_pressed)
# and the event pipeline (_input / _unhandled_input handlers)
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press(action)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.action_release(action)

func _finish_dialog() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			return
