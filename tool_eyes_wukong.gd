extends Node
# EYES: THE WUKONG + BEHAVIOR SHOWCASE (2026-07-28). Every new mechanic
# DEMONSTRATED and photographed mid-motion -- the "is it working AND
# creative?" pass, with eyes. Shots:
#   k1 somersault mid-FLIP (the body turning over)   k2 pillar planted
#   k3 golden-gaze mark glowing   k4 stillness (frozen foe)
#   k5 mirror-mage standing   k6 splitting dark (two splinters)
#   k7 sanctuary ring eating a shot
#   b1 orbiter wheel   b2 lash ribbon   b3 cluster blossom
#   b4 storm cloud raining   b5 sentry sniping   b6 chain maul whirl
# Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_wukong.gd" Godot.exe --path .  (no --headless!)

const WP = preload("res://weapon_projectile.gd")
const ENEMY_SCENE = preload("res://enemy.tscn")

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

func _dummy(host: Node, pos: Vector2) -> Node:
	var e = ENEMY_SCENE.instantiate()
	e.respawns = false
	host.add_child(e)
	e.global_position = pos
	e.set_physics_process(false)
	e.add_to_group("course_enemy")
	return e

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
		say("EYES-K: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _settle(0.8)
	var host := Node2D.new()
	get_tree().root.add_child(host)
	var saved_skills = GameState.unlocked_skills.duplicate()
	var saved_relics = GameState.equipment.relics.duplicate()

	# ---- k1: the somersault, mid-flip ----
	GameState.unlocked_skills = ["sw_root", "sw_b1", "sw_wk1"]
	p.somersault_ready_at = 0.0
	p.jumps_used = 1
	p.velocity.y = -200.0
	p.perform_somersault()
	await _settle(0.14)   # halfway through the 0.28s spin
	await _shot("k1_somersault_flip")
	await _settle(0.8)

	# ---- k2: the pillar, planted (raw S key injected) ----
	GameState.unlocked_skills = ["sw_root", "sw_g1", "sw_g2", "sw_wk2"]
	var near = _dummy(host, p.global_position + Vector2(80, 0))
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_S
	ev.keycode = KEY_S
	ev.pressed = true
	Input.parse_input_event(ev)
	await _settle(1.2)   # hold half a second + a counter beat
	await _shot("k2_pillar_planted")
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_S
	ev2.keycode = KEY_S
	ev2.pressed = false
	Input.parse_input_event(ev2)
	near.queue_free()
	await _settle(0.4)

	# ---- k3: the golden gaze mark ----
	var gz = _dummy(host, p.global_position + Vector2(140, -10))
	gz.set_meta("gold_mark_until", Time.get_ticks_msec() / 1000.0 + 30.0)
	gz.show_gold_mark(30.0)
	await _settle(0.4)
	await _shot("k3_golden_gaze")
	gz.queue_free()

	# ---- k4: stillness (the stopping word) ----
	var st = _dummy(host, p.global_position + Vector2(-140, -10))
	st.apply_status("freeze", 8.0, 0.0)
	await _settle(0.4)
	await _shot("k4_stillness_frozen")
	st.queue_free()

	# ---- k5: the mirror-mage stands ----
	GameState.unlocked_skills = ["mg_root", "mg_s1", "mg_s2", "mg_wk2"]
	p.hair_ready_at = 0.0
	var press = _dummy(host, p.global_position + Vector2(200, 0))
	await _settle(1.2)
	await _shot("k5_mirror_mage")
	var m = get_tree().get_first_node_in_group("player_mirror")
	if m != null:
		m.queue_free()
	press.queue_free()

	# ---- k6: the splitting dark ----
	GameState.unlocked_skills = ["nc_root", "nc_l1", "nc_l2", "nc_wk1"]
	var shade = load("res://shade.gd").new()
	shade.owner_player = p
	shade.damage = 10
	host.add_child(shade)
	shade.global_position = p.global_position + Vector2(0, -70)
	await _settle(0.3)
	shade.dissolve()
	await _settle(0.35)   # splinters torn free, bursts still in the air
	await _shot("k6_splitting_dark")
	for c in host.get_children():
		if "is_splinter" in c and c.is_splinter:
			c.queue_free()

	# ---- k7: sanctuary eats a shot ----
	GameState.unlocked_skills = []
	GameState.equipment.relics[0] = "rune_sanctuary"
	var shot2 := Node2D.new()
	shot2.add_to_group("enemy_projectile")
	var dot := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	dot.polygon = pts
	dot.color = Color(1.0, 0.4, 0.3)
	shot2.add_child(dot)
	host.add_child(shot2)
	for i in range(10):
		p.velocity = Vector2.ZERO
		p._still_t = 5.0
		if is_instance_valid(shot2):
			shot2.global_position = p.global_position + Vector2(70, -20)
		await get_tree().physics_frame
	await _shot("k7_sanctuary_pop")
	GameState.equipment.relics[0] = ""

	# ---- b-series: the behavior library in flight ----
	var base: Vector2 = p.global_position + Vector2(0, -40)
	var t1 = _dummy(host, base + Vector2(230, 0))
	var op = _fire(host, "orbiter", base, Vector2.RIGHT, {"range": 200.0, "dwell": 3.0, "speed": 650.0})
	await _settle(0.5)
	await _shot("b1_orbiter_wheel")
	if is_instance_valid(op): op.queue_free()

	var lp = _fire(host, "lash", base, Vector2.RIGHT, {"range": 340.0, "speed": 620.0})
	await _settle(0.35)
	await _shot("b2_lash_ribbon")
	if is_instance_valid(lp): lp.queue_free()

	var cp = _fire(host, "cluster", base + Vector2(0, -60), Vector2.RIGHT, {"range": 150.0, "shards": 7})
	await _settle(0.35)
	await _shot("b3_cluster_blossom")

	var storm = load("res://storm_cloud.gd").new()
	storm.duration = 5.0
	storm.strike_gap = 0.25
	host.add_child(storm)
	storm.global_position = t1.global_position
	await _settle(1.0)
	await _shot("b4_storm_raining")
	storm.queue_free()

	var totem = load("res://sentry_totem.gd").new()
	totem.lifetime = 8.0
	totem.fire_gap = 0.5
	host.add_child(totem)
	totem.global_position = base + Vector2(-60, 40)
	await _settle(1.1)
	await _shot("b5_sentry_sniping")
	totem.queue_free()

	var mp = _fire(host, "chain_maul", p.global_position, Vector2.RIGHT, {"range": 240.0, "speed": 650.0})
	mp.source = p
	await _settle(0.4)
	await _shot("b6_chainmaul_whirl")
	if is_instance_valid(mp): mp.queue_free()
	if is_instance_valid(t1): t1.queue_free()

	GameState.unlocked_skills = saved_skills
	GameState.equipment.relics = saved_relics
	host.queue_free()
	say("EYES-K: done, %s" % shot_dir)
	get_tree().quit(0)

func _fire(host: Node, kind: String, from: Vector2, dir: Vector2, cfg := {}) -> Node:
	var pr = WP.new()
	pr.kind = kind
	pr.direction = dir.normalized()
	pr.speed = float(cfg.get("speed", 600.0))
	pr.damage = int(cfg.get("damage", 10))
	pr.max_distance = float(cfg.get("range", 300.0))
	for k in ["dwell", "bounces", "shards", "aoe_radius"]:
		if cfg.has(k):
			pr.set(k, cfg[k])
	pr.source = get_tree().get_first_node_in_group("player")
	host.add_child(pr)
	pr.global_position = from
	return pr

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-K: shot %s" % name)

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
