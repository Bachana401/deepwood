extends Node

# The player crowd-control substrate (player.gd apply_stun/freeze/root/disorient/
# poison/pull). Bosses' signature abilities are built ON this, so it has to be
# proven first: each CC must (1) do exactly its thing, (2) leave the OTHER verbs
# alone (root still lets you attack; stun doesn't), and (3) ALWAYS expire — a
# boss must never be able to lock control forever.

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
	# AND THEN INSIST. The loop above only ASKS -- it dismisses a dialogue and
	# hopes that lifted the pause. If anything else owns the pause, or a dialogue
	# arrives later, every wait get_tree().physics_frame below still RESOLVES
	# while no _physics_process runs, so the checks measure nothing and report
	# failures the code never had a chance to earn. That is exactly how
	# test_mech2_node called four working mechanics broken (2026-08-03).
	if get_tree().paused:
		get_tree().paused = false
	p.god_mode = false

	# ---------------- STUN ----------------
	p.apply_stun(0.4)
	check("stun: locks ALL action (attack + move)", p.cc_action_locked() and p.cc_move_locked())
	for i in range(40):
		await get_tree().physics_frame
	check("stun: wears off on its own", not p.cc_action_locked(), "still locked after 0.4s")

	# ---------------- ROOT ----------------
	p.apply_root(0.4)
	check("root: blocks movement", p.cc_move_locked())
	check("root: but does NOT block attacks (you can still swing)", not p.cc_action_locked())
	for i in range(40):
		await get_tree().physics_frame
	check("root: wears off", not p.cc_move_locked())

	# ---------------- FREEZE ----------------
	p.apply_freeze(0.4)
	check("freeze: hard-locks like stun", p.cc_action_locked() and p.cc_move_locked())
	# frozen solid: even a shove can't slide you
	p.velocity.x = 400.0
	await get_tree().physics_frame
	check("freeze: velocity is pinned (can't be slid)", absf(p.velocity.x) < 1.0,
		"vx=%.1f" % p.velocity.x)
	for i in range(40):
		await get_tree().physics_frame
	check("freeze: wears off", not p.cc_action_locked())

	# ---------------- DISORIENT ----------------
	p.apply_disorient(0.5)
	check("disorient: is active", p._now() < p.disorient_until)
	for i in range(50):
		await get_tree().physics_frame
	check("disorient: wears off", p._now() >= p.disorient_until)

	# ---------------- POISON ----------------
	p.health = p.get_max_health()
	p.invincible = false
	p.monarch_iframes_until = 0.0
	var hp0: int = p.health
	p.apply_poison(1.0, 20.0)   # ~20 dmg over a second
	var ticked := false
	for i in range(40):
		await get_tree().physics_frame
		if p.health < hp0:
			ticked = true
			break
	check("poison: ticks damage over time", ticked, "%d -> %d" % [hp0, p.health])
	# wait out the FULL poison duration, then a few frames to drain the accumulator
	while p._now() < p.poison_until:
		await get_tree().physics_frame
	for i in range(10):
		await get_tree().physics_frame
	var settled: int = p.health
	for i in range(90):
		await get_tree().physics_frame
	check("poison: stops after its duration (not infinite)", p.health == settled,
		"kept draining after expiry: %d -> %d" % [settled, p.health])
	check("poison: total was survivable (didn't nuke from full)", not p.is_dead and hp0 - settled < hp0)

	# ---------------- PULL ----------------
	p.global_position.x = 1000.0
	p.velocity = Vector2.ZERO
	var before_x: float = p.global_position.x
	# pull toward a point far to the LEFT for several frames
	for i in range(20):
		p.apply_pull(0.0, 600.0)
		await get_tree().physics_frame
	check("pull: drags the player toward the source", p.global_position.x < before_x - 10.0,
		"%.0f -> %.0f" % [before_x, p.global_position.x])

	# ---------------- GOD MODE IMMUNITY ----------------
	p.god_mode = true
	p.apply_stun(1.0); p.apply_freeze(1.0); p.apply_root(1.0)
	check("god_mode: immune to all CC", not p.cc_action_locked() and not p.cc_move_locked())
	p.god_mode = false

	# ---------------- SURVIVES A RESPAWN CLEAN ----------------
	p.apply_freeze(5.0)
	p.clear_crowd_control()
	check("clear_crowd_control: wipes a long freeze (respawn safety)", not p.cc_action_locked())

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
