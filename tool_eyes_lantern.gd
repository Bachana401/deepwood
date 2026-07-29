extends Node
# EYES: THE LANTERN NIGHT (2026-07-28). The festival seen with eyes: the
# word, sky lanterns rising over the roofs, and the gentle dawn. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_lantern.gd" Godot.exe --path .   (no --headless!)

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
		say("EYES-L: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()

	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0
	GameState.game_hours = 22.5        # deep night, lantern hour
	GameState.morale_admin_offset = 100
	if GameState.rescued_villagers.is_empty():
		GameState.rescued_villagers.append({"name": "Eyes Fest", "id": "eyes_fest"})

	GameState.start_lantern()
	p.global_position = Vector2(6000.0, -80.0)   # the village row: the heart of the fleet
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.0)
	await _shot("l1_lantern_word")
	# let a real fleet climb
	await _settle(12.0)
	await _shot("l2_sky_lanterns")

	# dawn: the crossing eases the grief
	GameState.morale_death_shock = 30.0
	GameState.game_hours = 31.1        # time_of_day 5.1
	GameState._lantern_last_tod = 4.9
	GameState.tick_lantern(0.0)
	await _settle(1.0)
	await _shot("l3_gentle_dawn")

	say("EYES-L: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-L: shot %s" % name)

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
