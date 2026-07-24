extends Node
# EYES: THE DEEP (dev 2026-07-23). Descends into a real dungeon floor and
# screenshots the floor, a mob encounter, and a swing -- the combat surface the
# village walker can't reach. Run WINDOWED (screenshots need a live viewport):
#   MONARCH_TEST="res://tool_eyes_dungeon.gd" Godot.exe --path .

var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p := await _await_player()
	if p == null:
		say("EYES-D: no village player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true

	# ---- descend to a floor (EYES_LEVEL, default 3 = early mobbed room) ----
	var lvl := 3
	var lvl_env := OS.get_environment("EYES_LEVEL")
	if lvl_env != "":
		lvl = int(lvl_env)
	GameState.pending_player_state = GameState.capture_player_state(p)
	GameState.pre_dungeon_position = p.global_position
	GameState.active_dungeon_level = lvl
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")

	# ---- wait for the dungeon scene + its player ----
	var dp := await _await_player()
	if dp == null:
		say("EYES-D: no dungeon player"); get_tree().quit(1); return
	await _clear_dialog()
	await _settle(1.5)
	await _shot("d1_floor")                     # the floor as you arrive

	var boss = await _find_boss()
	if boss != null:
		# ---- BOSS FLOOR: watch the bespoke arena + a live telegraph ----
		var pfx := "b%d" % lvl
		dp.global_position = boss.global_position + Vector2(-260, -40)
		await _settle(0.6)
		await _shot(pfx + "_1_arena")           # the arena + boss on entry
		# GROUND TRUTH: force the boss to 40% and drive the update, then read BOTH
		# bars -- the overhead red fill AND the top HUD banner -- to prove they agree.
		if "max_health" in boss and "health" in boss:
			boss.health = int(boss.max_health * 0.4)
			if boss.has_method("update_health_bar"):
				boss.update_health_bar()
			await _settle(1.6)                   # let the banner ease down
			await _shot(pfx + "_2_drain")
			var overhead := -1.0
			var f = boss.get_node_or_null("HealthBarFill")
			if f != null and "health_bar_w" in boss and boss.health_bar_w > 0.0:
				overhead = f.size.x / boss.health_bar_w
			var banner := -1.0
			var hud = get_tree().get_first_node_in_group("boss_hud")
			if hud != null and "_hp_shown" in hud:
				banner = hud._hp_shown
			say("EYES-D: HP-BARS boss=%.2f overhead=%.2f banner=%.2f" % [
				float(boss.health) / float(boss.max_health), overhead, banner])
		# let the boss AI run and take a burst of shots to catch a telegraph/attack
		if "player" in boss: boss.player = dp
		for i in range(4):
			await _settle(0.7)
			await _shot(pfx + "_seq_%d" % i)
		say("EYES-D: boss floor %d, %d shots" % [lvl, _n])
		get_tree().quit(0)
		return

	# ---- walk into the room toward whatever's there ----
	Input.action_press("move_right")
	await _settle(3.0)
	await _shot("d2_advance")
	Input.action_release("move_right")

	# ---- pull the nearest mob onto us + swing, to see the fight ----
	var mob = _nearest_mob(dp)
	if mob != null and is_instance_valid(mob):
		mob.global_position = dp.global_position + Vector2(90, 0)
		if "instant_aggro" in mob: mob.instant_aggro = true
		await _settle(0.8)
		for i in range(3):
			_tap("attack")
			await _settle(0.4)
		await _shot("d3_combat")
	else:
		await _shot("d3_no_mob")

	# ---- the deep, one more angle after a beat of fighting ----
	await _settle(1.5)
	await _shot("d4_after")

	say("EYES-D: done, %d shots" % _n)
	get_tree().quit(0)

# The boss is the dungeon_combatant that carries a boss_id.
func _find_boss() -> Node2D:
	for i in range(120):
		await get_tree().process_frame
		for m in get_tree().get_nodes_in_group("dungeon_combatant"):
			if is_instance_valid(m) and ("boss_id" in m) and String(m.boss_id) != "":
				return m
	return null

# ------------------------------------------------------------------ helpers
func _await_player() -> Node:
	for i in range(1400):
		await get_tree().process_frame
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			return p
	return null

func _nearest_mob(from: Node2D) -> Node2D:
	var best: Node2D = null
	var bd := 1.0e12
	for g in ["dungeon_combatant", "course_enemy"]:
		for m in get_tree().get_nodes_in_group(g):
			if is_instance_valid(m) and not (("is_dead" in m) and m.is_dead):
				var d: float = from.global_position.distance_to(m.global_position)
				if d < bd:
					bd = d; best = m
	return best

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	_n += 1
	say("EYES-D: shot %s" % name)

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

func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action; ev.pressed = true
	Input.parse_input_event(ev); Input.action_press(action)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action; up.pressed = false
	Input.parse_input_event(up); Input.action_release(action)
