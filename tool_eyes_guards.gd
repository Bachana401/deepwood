extends Node
# EYES: THE WALKED WATCH (dev 2026-07-23, follow-up to the NPC AI pass). Raises the
# west rampart, stations every adventurer on the wall, and photographs the watch over
# ~14s -- plus a ground-truth line per beat (each guard's x + paused state) so the
# per-guard rhythm (different spans, ambles, pause habits) is provable in numbers,
# not just eyeballed. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_guards.gd" Godot.exe --path .

var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	if await _await_player() == null:
		say("EYES-G: no player"); get_tree().quit(1); return
	# clean, unpaused village (the opening otherwise pauses the tree)
	GameState.dev_mode = true
	GameState.seen_arrival_battle = true
	GameState.seen_intro = true
	GameState.opening_done = true
	get_tree().paused = false
	get_tree().reload_current_scene()
	for i in range(20):
		await get_tree().process_frame
	var p := await _await_player()
	if p == null:
		say("EYES-G: no player after reload"); get_tree().quit(1); return
	await _settle(0.5)
	get_tree().paused = false
	# daylight for a readable photograph, and no dialogue shade over the scene
	GameState.game_hours += 14.0            # 22:00 boot -> midday
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			if "_on_finished" in n: n._on_finished = Callable()
			n.queue_free()
	get_tree().paused = false
	await get_tree().process_frame

	# ---- raise the west rampart, then post the corps on the wall ----
	var wall = preload("res://wall.tscn").instantiate()
	wall.flank = "west"
	wall.position = Vector2(4700.0, -39.0)
	get_tree().current_scene.add_child(wall)
	await get_tree().process_frame

	var guards := []
	for a in get_tree().get_nodes_in_group("adventurer"):
		if not is_instance_valid(a) or a.is_dead:
			continue
		a.station = "wall"
		a.home_x = 0.0                    # re-derive the anchor from the new wall
		if a.has_method("_apply_station_groups"):
			a._apply_station_groups()
		guards.append(a)
	say("EYES-G: %d guards posted on the wall" % guards.size())
	if guards.is_empty():
		say("EYES-G: no guards"); get_tree().quit(1); return

	# frame the rampart: the player stands just inside the gate
	p.global_position = Vector2(4780.0, -100.0)
	await _settle(1.0)

	# ---- photograph the watch: 7 beats, 2s apart, positions logged each beat ----
	for beat in range(7):
		await _shot("g%d_watch" % beat)
		var line := "EYES-G: beat %d  " % beat
		for a in guards:
			if is_instance_valid(a):
				line += "%s x=%.0f%s  " % [str(a.adventurer_id).replace("adv_", ""),
					a.global_position.x, "(paused)" if a._pausing else ""]
		say(line)
		await _settle(2.0)

	say("EYES-G: done, %d shots" % _n)
	get_tree().quit(0)

# ------------------------------------------------------------------ helpers
func _await_player() -> Node:
	for i in range(1400):
		await get_tree().process_frame
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			return p
	return null

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	_n += 1

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout
