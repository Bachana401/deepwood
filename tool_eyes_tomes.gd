extends Node
# EYES: TOME VERBS BATCH 1 (2026-07-28). The Mire Pages' creeping bog and the
# Coven's Ledger's closing circle, seen with eyes over a dummy row. Zones are
# spawned directly so the shots are deterministic.
#   MONARCH_TEST="res://tool_eyes_tomes.gd" Godot.exe --path .  (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

class Dummy extends Node2D:
	var health := 99999
	var max_health := 99999
	var is_dead := false
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

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
		say("EYES-T: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0

	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	var scene = get_tree().current_scene
	for dx in [120.0, 200.0, 280.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 40.0)
	await _settle(1.0)

	# ---- t1: THE MIRE PAGES -- the bog soaks the row ----
	var SC = load("res://storm_cloud.gd")
	var mire = SC.new()
	mire.mire_mode = true
	mire.damage = 9
	mire.radius = 130.0
	mire.duration = 6.0
	mire.strike_gap = 0.5
	scene.add_child(mire)
	mire.global_position = p.global_position + Vector2(200.0, 44.0)
	await _settle(1.4)
	await _shot("t1_mire_bog")

	# ---- t2: THE COVEN'S LEDGER -- the circle closes ----
	var coven = SC.new()
	coven.coven_mode = true
	coven.damage = 12
	coven.radius = 140.0
	coven.duration = 5.0
	scene.add_child(coven)
	coven.global_position = p.global_position + Vector2(200.0, 30.0)
	await _settle(0.7)
	await _shot("t2_coven_circle")

	# ---- t3: THE DELUGE -- marching columns ----
	var col = SC.new()
	col.column_mode = true
	col.damage = 14
	col.radius = 170.0
	col.duration = 4.5
	col.facing = 1
	scene.add_child(col)
	col.global_position = p.global_position + Vector2(200.0, 40.0)
	await _settle(1.6)
	await _shot("t3_deluge_columns")

	# ---- t4: THE SIREN'S APPENDIX -- the gathering ring ----
	var lure = SC.new()
	lure.lure_mode = true
	lure.damage = 10
	lure.radius = 140.0
	lure.duration = 5.0
	lure.strike_gap = 0.4
	scene.add_child(lure)
	lure.global_position = p.global_position + Vector2(200.0, 30.0)
	await _settle(1.2)
	await _shot("t4_siren_lure")

	# ---- t5: THE TIDAL CODEX -- the travelling wall ----
	var tide = SC.new()
	tide.tide_mode = true
	tide.damage = 16
	tide.radius = 90.0
	tide.duration = 4.0
	tide.strike_gap = 0.2
	tide.facing = 1
	scene.add_child(tide)
	tide.global_position = p.global_position + Vector2(60.0, 40.0)
	await _settle(1.1)
	await _shot("t5_tide_wall")

	say("EYES-T: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-T: shot %s" % name)

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
