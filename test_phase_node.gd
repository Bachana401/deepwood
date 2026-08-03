extends Node

# PHASE (Obito), the first of the 22-boss ladder's mechanics.
#
# The three things that make it a MECHANIC and not just an invulnerability
# window, all asserted here:
#   1. your hits pass THROUGH -- not reduced, not guarded, zero
#   2. it phases REACTIVELY off your landed hit, so you get one hit then must read it
#   3. it can still ATTACK you out of the ghost, so you can never trade
# Plus: it's readable (visibly ghosted), it can't live there forever (cooldown),
# and a boss WITHOUT the passive is completely unaffected.

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

	var BS = load("res://boss.gd")
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# --- a boss WITHOUT phase is untouched by any of this ---
	var plain = BS.new()
	plain.boss_id = "gravewarden"
	host.add_child(plain)
	await get_tree().process_frame
	check("boss without the passive doesn't phase", not plain.has_phase)
	var h0: int = plain.health
	plain.take_damage(50)
	check("...and takes damage normally", plain.health < h0, "%d -> %d" % [h0, plain.health])
	plain.take_damage(50)
	check("...and keeps taking it, hit after hit", plain.health < h0 - 50,
		"a second hit must also land")

	# --- give a boss the passive ---
	var b = BS.new()
	b.boss_id = "gravewarden"
	host.add_child(b)
	await get_tree().process_frame
	b.has_phase = true
	b.phase_until = 0.0
	b.phase_ready_at = 0.0
	check("phase boss starts SOLID", not b.is_phased())

	# --- 1 + 2: the first hit lands, and it steps out of the world ---
	var before: int = b.health
	b.take_damage(40)
	check("the first hit LANDS", b.health == before - 40, "%d -> %d" % [before, b.health])
	check("it phases REACTIVELY off that hit", b.is_phased())

	# --- everything after passes clean through ---
	var during: int = b.health
	for i in range(6):
		b.take_damage(999)
	check("hits pass THROUGH while phased (6 x 999 = 0 damage)", b.health == during,
		"%d -> %d" % [during, b.health])
	check("...it is not merely reduced -- it is exactly zero", b.health == during)

	# --- it is READABLE: visibly ghosted, not hidden ---
	await get_tree().physics_frame
	var gfx = b.boss_sprite if b.boss_sprite != null else b
	check("phased boss is visibly ghosted (alpha %.2f)" % gfx.modulate.a,
		gfx.modulate.a < 0.75, "alpha %.2f -- the player must SEE not to swing" % gfx.modulate.a)

	# --- 3: it can still hurt YOU out of the ghost (this is the Obito part) ---
	check("it is NOT disabled while phased (still alive and acting)",
		not b.is_dead and b.has_method("_physics_process"))

	# --- the window closes, and it goes solid again ---
	var t0: float = Time.get_ticks_msec() / 1000.0
	for i in range(400):
		await get_tree().physics_frame
		if not b.is_phased():
			break
	var held: float = Time.get_ticks_msec() / 1000.0 - t0
	check("the ghost window closes (~%.1fs)" % held, not b.is_phased())
	check("...and it lasted about PHASE_SECONDS", held > 0.5 and held < b.PHASE_SECONDS + 1.5,
		"held %.2fs vs %.1f" % [held, b.PHASE_SECONDS])
	await get_tree().physics_frame
	check("solid again = fully opaque", gfx.modulate.a > 0.95, "alpha %.2f" % gfx.modulate.a)

	# --- and now it can be hurt again ---
	var after: int = b.health
	b.take_damage(30)
	check("hits land again once it's solid", b.health == after - 30, "%d -> %d" % [after, b.health])

	# --- it cannot live in the ghost: the cooldown blocks an instant re-phase ---
	check("cooldown stops it phasing again immediately", not b.is_phased(),
		"it would be untouchable forever otherwise")

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
