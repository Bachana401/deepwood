extends Node
# EYES: THE CROWN TEN (weapon overhaul wave, 2026-07-29). Each approved crown
# weapon gets shots here as it is built, so the apex tier is judged on film
# rather than on description.
#   MONARCH_TEST="res://tool_eyes_crown.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

# a REAL body on the enemy layer (4): projectiles find targets by physics
# overlap, so a plain Node2D dummy is invisible to them (walker lesson)
class Dummy extends StaticBody2D:
	var health := 99999
	var max_health := 99999
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
		say("EYES-CROWN: no player"); get_tree().quit(1); return
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
	for dx in [150.0, 240.0, 330.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 20.0)
	await _settle(1.0)

	# ---- THE WHOLE COURT, SPINNING: the rank arrives, then sweeps ----
	p.inventory.add_item("wpn_courtwheel", 1)
	p.wield_weapon("wpn_courtwheel")
	var cs: Dictionary = p.active_def.get("special", {})
	p.unleash_court(cs, Vector2.RIGHT)
	await _settle(0.10)
	await _shot("c1_court_materialise")   # the shades draw themselves up
	await _settle(0.14)
	await _shot("c2_court_sweep")         # all of them cutting at once
	await _settle(0.30)
	await _shot("c3_court_after")         # the field after the court passes
	# a second call: the tints must CYCLE, so the next rank is different people
	p.unleash_court(cs, Vector2.RIGHT)
	await _settle(0.20)
	await _shot("c4_court_second_rank")

	await _settle(0.8)

	# ---- THE FINAL EDICT: the arm of the law unfolds down the hall ----
	p.inventory.add_item("wpn_edictpike", 1)
	p.wield_weapon("wpn_edictpike")
	var es: Dictionary = p.active_def.get("special", {})
	p.launch_projectile(es, Vector2.RIGHT, int(es.get("damage", 26)))
	await _settle(0.13)
	await _shot("e1_edict_unfolding")   # mid-extension
	await _settle(0.16)
	await _shot("e2_edict_full")        # full reach, blooms along the row
	await _settle(0.22)
	await _shot("e3_edict_withdraw")    # the sentence ends

	say("EYES-CROWN: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-CROWN: shot %s" % name)

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
