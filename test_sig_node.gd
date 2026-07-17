extends Node

# The teaching-tier signature abilities (BOSSES.md §6, floors 5-30). Each must
# measurably DO its distinct thing to the player -- the whole point is that the
# bosses threaten differently. Uses real boss.tscn instances (collision) and the
# player CC substrate proven in test_cc_node.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break
	p.god_mode = false
	get_tree().paused = false

	var BSCN = load("res://boss.tscn")
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# helper: spawn a boss, aim it at the player, run one signature
	var mk := func(bid: String) -> Node:
		var b = BSCN.instantiate()
		b.boss_id = bid
		host.add_child(b)
		return b

	var pin := Vector2(1500.0, -100.0)
	p.global_position = pin
	for i in range(4):
		await get_tree().physics_frame

	# ---------------- GRAVE GRASP (root) ----------------
	var gw = mk.call("gravewarden")
	await get_tree().process_frame
	gw.player = p
	gw.global_position = pin + Vector2(160, 0)
	p.global_position = pin
	p.clear_crowd_control()
	await gw.do_grave_grasp()
	check("Gravewarden Grave Grasp: ROOTS a standing player", p.cc_move_locked())
	check("Grave Grasp: root still lets you attack (not a hard stun)", not p.cc_action_locked())
	p.clear_crowd_control()
	gw.queue_free()

	# ---------------- RIME LANCE (freeze) ----------------
	var fm = mk.call("frost_monarch")
	await get_tree().process_frame
	fm.player = p
	fm.global_position = pin + Vector2(200, 0)
	p.global_position = pin
	p.velocity = Vector2.ZERO
	p.clear_crowd_control()
	await fm.do_rime_lance()
	check("Frost Monarch Rime Lance: FREEZES a player who held still", p.cc_action_locked())
	p.clear_crowd_control()
	fm.queue_free()

	# ---------------- MAGMA WAKE (lingering fire zone) ----------------
	var cc = mk.call("cinder_colossus")
	await get_tree().process_frame
	cc.player = p
	cc.global_position = pin + Vector2(300, 0)
	p.global_position = pin
	await cc.do_magma_wake()
	var hazards := host.get_tree().root.find_children("*", "Node2D", true, false).filter(
		func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("hazard_zone.gd"))
	check("Cinder Colossus Magma Wake: leaves lingering fire hazards", hazards.size() >= 3,
		"%d hazards" % hazards.size())
	# stand in one and confirm it burns
	p.health = p.get_max_health()
	p.invincible = false; p.monarch_iframes_until = 0.0
	if hazards.size() > 0:
		var hp0: int = p.health
		p.global_position = hazards[0].global_position
		for i in range(50):
			p.global_position = hazards[0].global_position
			await get_tree().physics_frame
			if p.health < hp0:
				break
		check("Magma Wake: standing in the fire burns you", p.health < hp0, "%d -> %d" % [hp0, p.health])
	cc.queue_free()

	# ---------------- WEB SNARE (root zone) ----------------
	var wv = mk.call("weaver")
	await get_tree().process_frame
	wv.player = p
	wv.global_position = pin + Vector2(180, 0)
	p.global_position = pin
	p.clear_crowd_control()
	await wv.do_web_snare()
	# stand in the web a moment; it should re-root
	for i in range(40):
		await get_tree().physics_frame
		if p.cc_move_locked():
			break
	check("Weaver Web Snare: the patch ROOTS a player standing in it", p.cc_move_locked())
	p.clear_crowd_control()
	wv.queue_free()

	# ---------------- THUNDERSTRIKE (delayed + stun) ----------------
	var sc = mk.call("stormcaller")
	await get_tree().process_frame
	sc.player = p
	sc.global_position = pin + Vector2(240, 0)
	p.global_position = pin
	p.velocity = Vector2.ZERO
	p.clear_crowd_control()
	await sc.do_thunderstrike()
	check("Stormcaller Thunderstrike: STUNS a player who didn't move off the mark", p.cc_action_locked())
	p.clear_crowd_control()
	sc.queue_free()

	# ---------------- VOID RIFT (pull) ----------------
	var vs = mk.call("void_sovereign")
	await get_tree().process_frame
	vs.player = p
	vs.global_position = pin + Vector2(-260, 0)
	p.global_position = pin
	p.velocity = Vector2.ZERO
	var before_x: float = p.global_position.x
	# run the rift; it opens ~220px to the player's side and drags them
	await vs.do_void_rift()
	check("Void Sovereign Void Rift: its pull MOVED the player", absf(p.global_position.x - before_x) > 15.0,
		"%.0f -> %.0f" % [before_x, p.global_position.x])
	vs.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
