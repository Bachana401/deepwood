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

	await _settle(0.8)

	# ---- A SMALL PERSONAL SUN: the fan closes into a column ----
	p.inventory.add_item("wpn_smallsun", 1)
	p.wield_weapon("wpn_smallsun")
	p.mana = p.get_max_mana()
	# the channel aims at the CURSOR and a walker has none, so put the pointer
	# exactly on the far dummy (world -> screen through the canvas transform)
	var aim_world: Vector2 = p.global_position + Vector2(300.0, 10.0)
	Input.warp_mouse(get_viewport().get_canvas_transform() * aim_world)
	await get_tree().process_frame
	# HOLD the real attack action -- calling channel_prism() by hand is a lie:
	# the player's own loop calls stop_prism() on every frame the button is up,
	# so a hand-driven channel is reset to zero focus before it can converge
	Input.action_press("attack")
	await _settle(0.35)
	await _shot("s1_sun_fan")        # wide open, searching
	await _settle(1.0)
	await _shot("s2_sun_closing")    # drawing together
	await _settle(1.4)
	await _shot("s3_sun_column")     # all six through one body
	Input.action_release("attack")
	await _settle(0.2)
	await _shot("s4_sun_released")

	await _settle(0.8)

	# ---- REGICIDE: the spears STAY IN, and the sixth shoves the first out ----
	p.inventory.add_item("wpn_regicide", 1)
	p.wield_weapon("wpn_regicide")
	# step back: the T8 spear's held sprite is long enough to sit on top of the
	# nearest dummy, and the whole point of this weapon is SEEING the stack
	p.global_position.x -= 150.0
	await _settle(0.2)
	var rs: Dictionary = p.active_def.get("special", {})
	for throw_i in range(6):
		p.launch_projectile(rs, Vector2.RIGHT, int(rs.get("damage", 21)))
		await _settle(0.22)
		if throw_i == 1:
			await _shot("r1_regicide_two")     # a pair standing in them
		elif throw_i == 4:
			await _shot("r2_regicide_five")    # the full countable stack
	await _settle(0.3)
	await _shot("r3_regicide_overflow")        # the sixth pushed the first out
	await _settle(1.2)
	await _shot("r4_regicide_biting")          # the stack still eating

	await _settle(0.8)

	# ---- THRONE OF EMBERS: whirl, hurl, and then it SITS and burns ----
	p.global_position = Vector2(6000.0, -80.0)
	p.inventory.add_item("wpn_emberthrone", 1)
	p.wield_weapon("wpn_emberthrone")
	var bs: Dictionary = p.active_def.get("special", {})
	p.launch_projectile(bs, Vector2.RIGHT, int(bs.get("damage", 30)))
	await _settle(0.35)
	await _shot("b1_throne_whirl")      # the head opens its spiral
	await _settle(0.45)
	await _shot("b2_throne_hurl")       # out along the aim
	await _settle(0.7)
	await _shot("b3_throne_seated")     # it found the floor and lit
	await _settle(1.4)
	await _shot("b4_throne_burning")    # embers going out to the row

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
