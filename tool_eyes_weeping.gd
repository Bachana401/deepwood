extends Node
# EYES: THE WEEPING HOUR (2026-07-28). The night seen with eyes: the urgent
# word, pale weepers walking the roads, and the dawn tally. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_weeping.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
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
		say("EYES-W: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()

	# hold every other story off the stage
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0
	GameState.live_siege_active = false
	GameState.deepest_level_reached = maxi(GameState.deepest_level_reached, 10)
	GameState.hours_since_weeping = 200.0
	GameState.game_hours = 22.5   # deep night

	# the night begins
	GameState.start_weeping()
	p.global_position = Vector2(5400.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.2)
	await _shot("w1_weeping_word")
	# let the trickle walk a couple of sobs in
	await _settle(8.0)
	p.global_position = Vector2(6100.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.5)
	await _shot("w2_pale_ones")

	# dawn: force the crossing and read the tally
	GameState.weeping_kills = 11
	GameState.game_hours = 31.1        # time_of_day 5.1 -- first light
	GameState._weep_last_tod = 4.9
	GameState.tick_weeping(0.0)
	await _settle(1.0)
	await _shot("w3_dawn_tally")

	say("EYES-W: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-W: shot %s" % name)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); found = true
		get_tree().paused = false
		await _settle(0.2)
		if not found and not get_tree().paused:
			return
