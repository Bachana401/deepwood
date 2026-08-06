extends Node
# EYES: THE ECLIPSE (2026-08-06). The dev handed over a reference image -- black
# silhouettes under one hot red ring -- and asked for that sky. Nothing so far has
# actually LOOKED at what we built: the eclipse test only greps the source for the
# right identifiers, which proves the wiring and says nothing at all about how it
# reads. Per this project's own rule, a static sweep cannot see the game.
#
# Walks the eclipse from first contact to totality to release, a shot at each step,
# plus an ordinary noon for comparison so the difference is judgeable rather than
# imagined.
#
#   MONARCH_TEST="res://tool_eyes_eclipse.gd" Godot.exe --path .   (NOT --headless)

var shot_dir := "user://eyes_eclipse"
var _steps := 0

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

	# the opening is a CHAIN of boxes and finishing one can raise the next, so keep
	# clearing until the screen is genuinely empty (a leftover box pauses the tree)
	GameState.opening_done = true
	for _pass in range(6):
		await _clear_dialog()
		await _settle(0.3)
	if get_tree().paused:
		get_tree().paused = false

	# stand in the village, looking at buildings -- the eclipse has to be judged
	# against things that can go to silhouette, not against empty sky
	var vx := 5600.0
	for b in get_tree().get_nodes_in_group("building"):
		vx = b.global_position.x
		break
	p.global_position = Vector2(vx - 120.0, -120.0)
	await _settle(1.2)

	# ---- an ordinary noon, for comparison ----
	GameState.eclipse_at_hours = -1.0
	_set_clock_to(12.0)
	await _settle(1.0)
	await _shot("00_ordinary_noon")

	# ---- the eclipse, walked from first contact to release ----
	# it always opens at sunrise and runs the daylight span, so stepping the clock
	# across that window steps the whole event
	var start: float = GameState.game_hours + GameState.hours_until_time_of_day(GameState.ECLIPSE_START_HOUR)
	GameState.eclipse_at_hours = start
	var names := ["01_first_contact", "02_quarter", "03_half", "04_TOTALITY",
		"05_past_peak", "06_releasing", "07_last_light"]
	var fracs := [0.02, 0.25, 0.4, 0.5, 0.62, 0.8, 0.97]
	for i2 in range(names.size()):
		GameState.game_hours = start + GameState.ECLIPSE_DURATION_HOURS * float(fracs[i2])
		# the sky redraws off game_hours, so give it frames to catch up
		await _settle(0.6)
		await _shot("%s_p%.2f" % [names[i2], GameState.eclipse_progress()])
		_steps += 1

	# ---- and after, to prove it lets go cleanly ----
	GameState.game_hours = start + GameState.ECLIPSE_DURATION_HOURS + 2.0
	GameState.eclipse_at_hours = -1.0
	_set_clock_to(12.0)
	await _settle(1.0)
	await _shot("08_after_noon")

	say("EYES: %d eclipse steps written to %s" % [_steps, ProjectSettings.globalize_path(shot_dir)])
	get_tree().quit(0)

# Move the visible clock to a given hour of day without disturbing the eclipse
# window we just set up (time_of_day = START_TIME_OF_DAY + game_hours, mod 24).
func _set_clock_to(hour: float) -> void:
	GameState.game_hours += GameState.hours_until_time_of_day(hour)

func _shot(name: String) -> void:
	# DRIVE THE SKY DIRECTLY. day_night_cycle mirrors the clock from _process, which
	# does not run while the tree is paused -- and the opening chain can leave a box
	# up. Without this the walker photographs the paused sky and reports a blue night
	# at totality, which looks exactly like a broken eclipse and is not one.
	for n in get_tree().get_nodes_in_group("day_night_cycle"):
		if n.has_method("update_visuals"):
			n.time_of_day = fposmod(GameState.START_TIME_OF_DAY + GameState.game_hours, 24.0)
			n.total_hours_elapsed = GameState.game_hours
			n.update_visuals()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
	# ...and a 3x crop centred on where the ring is supposed to be. A full frame at
	# 1152 wide makes a 60px corona look like a smudge; judging "is the ring there"
	# off the wide shot is how you talk yourself into shipping an invisible feature.
	var cam := get_viewport().get_camera_2d()
	var dn = get_tree().get_first_node_in_group("day_night_cycle")
	if cam != null and dn != null and GameState.eclipse_progress() > 0.0:
		var sp: float = dn.get_sun_progress()
		if sp >= 0.0:
			var world: Vector2 = dn._eclipse_sky_pos(
				dn.arc_position(sp, dn.get_parallax_anchor_x()), GameState.eclipse_progress())
			var s: Vector2 = (world - cam.get_screen_center_position()) * cam.zoom \
				+ get_viewport().get_visible_rect().size * 0.5
			var r := Rect2i(int(s.x) - 110, int(s.y) - 110, 220, 220)
			r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			if r.size.x > 8 and r.size.y > 8:
				var crop := img.get_region(r)
				crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
				crop.save_png(shot_dir.path_join(name + "_RINGZOOM.png"))
	say("EYES: shot %s" % name)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish()
				found = true
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame
		if not found:
			break
