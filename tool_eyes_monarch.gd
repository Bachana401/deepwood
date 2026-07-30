extends Node
# EYES: MONARCH (weapon overhaul, 2026-07-29).
# One walker per tier -- see the note at the top of tool_eyes_t7.gd for why.
#   MONARCH_TEST="res://tool_eyes_t6.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

class Dummy extends StaticBody2D:
	var health := 999999
	var max_health := 999999
	var is_dead := false
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 60)
		cs.shape = sh
		add_child(cs)
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

var _home := Vector2(6000.0, -80.0)

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
		say("EYES-M8: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0

	p.global_position = _home
	if "velocity" in p: p.velocity = Vector2.ZERO
	var scene = get_tree().current_scene
	for dx in [150.0, 240.0, 330.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 20.0)
	await _settle(0.8)

	# id, shot name, settle before the shot, swings
	for spec in [
			["wpn_patientknife", "m01_patient",  0.50, 1],
			["wpn_kingdomwheel", "m02_kingdom",  0.50, 1],
			["wpn_therumor",     "m03_rumor",    0.70, 1],
			["wpn_skymeasure",   "m04_measure",  0.50, 1],
			["wpn_unbentcolumn", "m05_colonnade", 0.34, 1],
			["wpn_choirofone",   "m06_choir",    0.26, 1],
			["wpn_thronestrings", "m07_harp",    0.22, 1],
			["wpn_worldsgrief",  "m08_tears",    0.40, 1],
			["wpn_skysfare",     "m09_bolts",    0.80, 1],
			["wpn_worldslash",   "m10_worldcut", 0.08, 1],
			["wpn_deepcrown",    "m11_court",    0.90, 1]]:# it caught someone
		p.global_position = _home
		if "velocity" in p: p.velocity = Vector2.ZERO
		p.inventory.add_item(spec[0], 1)
		p.wield_weapon(spec[0])
		p.mana = p.get_max_mana()
		await _aim_right(p)
		for s in range(int(spec[3])):
			p.attack_cooldown_remaining = 0.0
			p.perform_attack()
			if int(spec[3]) > 1:
				await _settle(0.13)
		await _settle(float(spec[2]))
		await _shot(str(spec[1]))
		await _settle(0.35)

	say("EYES-M8: done")
	get_tree().quit(0)

# perform_attack aims at the CURSOR; a walker has none, so every swing-driven
# weapon fires LEFT and lands off-frame unless the pointer is parked first.
func _aim_right(p: Node) -> void:
	var at: Vector2 = (p as Node2D).global_position + Vector2(240.0, 10.0)
	Input.warp_mouse(get_viewport().get_canvas_transform() * at)
	await get_tree().process_frame
	await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-M8: shot %s" % name)

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
