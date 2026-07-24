extends Node
# EYES: THE HARVEST, IN THE STREETS (dev 2026-07-23). The finale is the game's most
# complex render -- the transformed town streams in wearing its own names, the Shadow
# Monarch eats the living, the Ten + Roland hold lanes -- and nothing static can SEE
# it. This stages the RESUME path (harvest_director.resume_fight), which spawns the
# monarch + allies + the turned horde directly, and screenshots the battle. Also logs
# ground truth (monarch present? ally count? live combatants?) so a blank stage can't
# read as "fine". Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_finale.gd" Godot.exe --path .

var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	if await _await_player() == null:
		say("EYES-F: no player"); get_tree().quit(1); return
	# clean, unpaused village (see tool_eyes_siege: the opening otherwise pauses us)
	GameState.dev_mode = true
	GameState.seen_arrival_battle = true
	GameState.seen_intro = true
	GameState.opening_done = true
	GameState.arrival_battle_active = false
	get_tree().paused = false
	get_tree().reload_current_scene()
	for i in range(20):
		await get_tree().process_frame
	var p := await _await_player()
	if p == null:
		say("EYES-F: no player after reload"); get_tree().quit(1); return
	await _settle(0.5)
	get_tree().paused = false

	# a turned town to raise: give the harvest pool names to wear
	GameState.harvested_villagers = []
	for i in range(14):
		GameState.harvested_villagers.append({"id": "harv_%d" % i, "name": "Villager %d" % i, "sex": "Male"})

	# mount the director on the RESUME road: its _ready plays HARVEST_RESUME, whose
	# finish() callback fires resume_fight() -> monarch + the Ten + Roland + waves.
	var d = preload("res://harvest_director.gd").new()
	d.resume = true
	get_tree().current_scene.add_child(d)
	await _settle(0.6)
	# Drive the fight the PROVEN-SAFE way (tool_finale_probe): neutralise every
	# dialogue callback + free the boxes, then call resume_fight() DIRECTLY. Firing it
	# through finish()'s callback from inside a coroutine's find_children loop segfaults
	# the WINDOWED run (a tool re-entrancy artifact -- the finale logic itself is fine,
	# proven headless), and would just abort the screenshots.
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			if "_on_finished" in n: n._on_finished = Callable()
			n.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	if d.has_method("resume_fight"):
		d.resume_fight()
	await _settle(1.2)

	# frame the fight on the monarch (the director stores him in _monarch)
	var mon = _monarch_of(d)
	if mon != null and is_instance_valid(mon):
		p.global_position = mon.global_position + Vector2(-260, -30)
	await _settle(0.6)
	await _shot("f1_streets")
	_report(d)

	# let the waves stream + the devour tick, catch the spectacle over a few beats
	for i in range(6):
		await _settle(1.1)
		if i % 2 == 0:
			await _shot("f%d_wave" % (i + 2))
		_report(d)

	say("EYES-F: done, %d shots" % _n)
	get_tree().quit(0)

func _monarch_of(d: Node) -> Node:
	return d._monarch if ("_monarch" in d) else null

func _report(d: Node) -> void:
	var mon = _monarch_of(d)
	var horde := 0
	for e in get_tree().get_nodes_in_group("transformed"):
		if is_instance_valid(e) and not (("is_dead" in e) and e.is_dead):
			horde += 1
	var allies := get_tree().get_nodes_in_group("ten_ally").size()
	var fight_on: bool = ("_fight_on" in d) and bool(d._fight_on)
	say("EYES-F: HARVEST paused=%s monarch=%s allies=%d horde=%d fight_on=%s" % [
		str(get_tree().paused), str(mon != null and is_instance_valid(mon)), allies, horde, str(fight_on)])

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
	say("EYES-F: shot %s" % name)

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
