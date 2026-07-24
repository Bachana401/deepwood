extends Node
# EYES: THE WALL HOLDS (dev 2026-07-23). The player reported "placed a wall, the
# wave passed through it like nothing." test_wavesides + test_firstsession lock the
# MATH (approach-face stop); this WATCHES a live siege hit a placed wall and, more
# importantly, logs GROUND TRUTH every beat -- the closest raider's x against the
# wall's west face -- so a raider that crosses INTO the village is caught by numbers,
# not by eyeballing a screenshot. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_siege.gd" Godot.exe --path .

var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	if await _await_player() == null:
		say("EYES-S: no player"); get_tree().quit(1); return
	# The village opens on the SCRIPTED arrival (forced walk, banter, staged fight)
	# which PAUSES the tree -- a live siege can't march in a paused world, and the
	# seen_* flags alone don't stop a later story beat re-pausing it (proven: after a
	# plain reload the tree came back paused=true with the raiders frozen mid-march).
	# dev_mode bypasses the WHOLE opening apparatus (main._ready lines 230/561 both
	# no-op on it); we drive the siege by hand, so dev_mode's auto-siege gate is moot.
	GameState.dev_mode = true
	GameState.seen_arrival_battle = true
	GameState.seen_intro = true
	GameState.opening_done = true
	GameState.arrival_battle_active = false
	get_tree().paused = false
	get_tree().reload_current_scene()
	for i in range(20):                           # let the old scene tear down first
		await get_tree().process_frame
	var p := await _await_player()
	if p == null:
		say("EYES-S: no player after reload"); get_tree().quit(1); return
	await _settle(0.5)
	get_tree().paused = false
	GameState.live_siege_active = false
	GameState.highest_unlocked_level = 5          # pre-Orin: west (dungeon) front only

	# ---- raise a west rampart the way the build placer does ----
	var wall = _wall_or_build("west", 4700.0)
	await get_tree().process_frame                # let wall._ready join "village_wall"
	if wall == null:
		say("EYES-S: no wall"); get_tree().quit(1); return

	# frame the wall + the western approach the raiders climb
	p.global_position = Vector2(wall.global_position.x + 40.0, -100.0)
	await _settle(0.8)
	await _shot("s0_wall")

	var mgr = get_tree().get_first_node_in_group("siege_manager")
	if mgr == null or not mgr.has_method("start_live_siege"):
		say("EYES-S: no siege manager"); get_tree().quit(1); return
	mgr.start_live_siege(4, false)
	say("EYES-S: siege started")

	# ---- watch the horde climb the road and break on the wall ----
	for i in range(16):
		await _settle(0.9)
		if i % 2 == 0:
			await _shot("s%d_wave" % (i + 1))
		_report_wall(wall)

	say("EYES-S: done, %d shots" % _n)
	get_tree().quit(0)

# The raiders come from the WEST (x < wall) marching EAST toward the west face.
# They must STOP at/just-west of the face; any raider whose x is meaningfully EAST
# of the face (deeper into the village) has passed THROUGH -- the reported bug.
func _report_wall(wall: Node) -> void:
	if not is_instance_valid(wall) or not wall.has_method("west_face_x"):
		return
	var face: float = wall.west_face_x()
	var alive := 0
	var deepest := -1.0e12       # furthest-east raider x
	var breached := 0
	var sample_vx := 0.0
	var sample_floor := false
	var sample_target := "?"
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r):
			continue
		# only count the WEST attackers (this is a west-only, pre-Orin siege)
		alive += 1
		if r.global_position.x > deepest:
			deepest = r.global_position.x
			sample_vx = r.velocity.x if "velocity" in r else 0.0
			sample_floor = r.is_on_floor() if r.has_method("is_on_floor") else false
			if r.has_method("current_target"):
				var t = r.current_target()
				sample_target = ("null" if t == null else String(t.name))
		if r.global_position.x > face + 20.0:   # 20px tolerance past the face
			breached += 1
	say("EYES-S: WALL paused=%s face=%.0f alive=%d deepest_x=%.0f vx=%.0f floor=%s tgt=%s breached=%d" % [
		str(get_tree().paused), face, alive, deepest, sample_vx, str(sample_floor), sample_target, breached])

func _wall_or_build(flank: String, x: float) -> Node:
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == flank:
			return w
	var wall = preload("res://wall.tscn").instantiate()
	wall.flank = flank
	wall.position = Vector2(x, -39.0)
	get_tree().current_scene.add_child(wall)
	return wall

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
	say("EYES-S: shot %s" % name)

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
