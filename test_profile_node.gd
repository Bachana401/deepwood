extends Node

# Boss MOVEMENT profiles (boss.gd `_drive_profile`): every boss should cross the
# floor differently -- rusher / kiter / pursuer / pouncer / erratic / weave /
# turtle / hopper / mirror, plus hover for flyers. This proves (1) each real boss
# has its intended profile and (2) the distinctive profiles actually move the way
# they claim. Behaviour is driven on a NON-combo boss (gravewarden), whose walk
# branch calls _drive_profile every frame, with the profile overridden.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

var _host: Node2D
var _bscn
var _p: Node

# spawn a fresh gravewarden (non-combo) with a forced profile + no attacks, so we
# measure pure movement of that profile
func spawn_mover(prof: String) -> Node:
	var b = _bscn.instantiate()
	b.boss_id = "gravewarden"
	_host.add_child(b)
	b.profile = prof
	b.abilities = []
	b.player = _p
	return b

# net horizontal travel of a mover over `frames`, player pinned at `ppos`
func run_move(b: Node, ppos: Vector2, bpos: Vector2, frames: int) -> float:
	b.global_position = bpos
	var x0: float = b.global_position.x
	for i in range(frames):
		_p.global_position = ppos
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	return b.global_position.x - x0

func _ready() -> void:
	_p = null
	for i in range(1200):
		await get_tree().process_frame
		_p = get_tree().get_first_node_in_group("player")
		if _p != null:
			break
	if _p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break
	_p.god_mode = true      # testing boss movement; don't let it kill us
	get_tree().paused = false

	_bscn = load("res://boss.tscn")
	_host = Node2D.new()
	get_tree().root.add_child(_host)
	var pin := Vector2(1500.0, -100.0)
	_p.global_position = pin

	# ---------------- ASSIGNMENT: the real bosses have distinct profiles -------
	var want := {
		"gravewarden": "rusher", "frost_monarch": "kiter", "cinder_colossus": "pursuer",
		"weaver": "erratic", "stormcaller": "weave", "void_sovereign": "pouncer",
		"ashen_penitent": "turtle", "effigy": "hopper", "last_man": "mirror",
		"eclipse": "turtle", "glass_saint": "kiter",
	}
	var seen := {}
	for bid in want.keys():
		var b = _bscn.instantiate()
		b.boss_id = bid
		_host.add_child(b)
		await get_tree().process_frame
		check("%s uses the %s profile" % [bid, want[bid]], b.profile == want[bid],
			"got '%s'" % b.profile)
		seen[b.profile] = true
		b.queue_free()
	check("the roster spreads across MANY movement profiles", seen.size() >= 7,
		"%d distinct in the sample" % seen.size())

	# ---------------- RUSHER: closes the gap ----------------
	var r = spawn_mover("rusher")
	await get_tree().process_frame
	var rmove: float = await run_move(r, pin, pin + Vector2(700, 0), 90)
	check("rusher: closes toward the player", rmove < -80.0, "moved %.0f" % rmove)
	r.queue_free()

	# ---------------- KITER: backs off when crowded ----------------
	var k = spawn_mover("kiter")
	await get_tree().process_frame
	var kmove: float = await run_move(k, pin, pin + Vector2(90, 0), 90)   # start inside its range
	check("kiter: retreats when the player is inside its range", kmove > 60.0, "moved %.0f" % kmove)
	k.queue_free()

	# ---------------- TURTLE: barely moves ----------------
	var t = spawn_mover("turtle")
	await get_tree().process_frame
	var tmove: float = absf(await run_move(t, pin, pin + Vector2(600, 0), 90))
	# a rusher would cover ~hundreds of px in the same window; the turtle creeps
	check("turtle: barely moves (wants you to come to it)", tmove < 200.0, "moved %.0f" % tmove)
	t.queue_free()

	# ---------------- PURSUER: accelerates while chasing ----------------
	var pu = spawn_mover("pursuer")
	await get_tree().process_frame
	pu.global_position = pin + Vector2(700, 0)
	for i in range(70):
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	check("pursuer: ramps up speed the longer it chases", pu._chase_ramp > 1.3,
		"ramp %.2f" % pu._chase_ramp)
	pu.queue_free()

	# ---------------- HOPPER: moves in jumps ----------------
	var h = spawn_mover("hopper")
	await get_tree().process_frame
	h.global_position = pin + Vector2(500, 0)
	var hopped := false
	for i in range(120):
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
		if h.velocity.y < -100.0:      # a jump was launched
			hopped = true
			break
	check("hopper: approaches in jumps", hopped)
	h.queue_free()

	# ---------------- MIRROR: moves only while the player moves ----------------
	var m = spawn_mover("mirror")
	await get_tree().process_frame
	m.global_position = pin + Vector2(400, 0)
	# player still -> mirror should hold
	var mx0: float = m.global_position.x
	for i in range(40):
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	var held: float = absf(m.global_position.x - mx0)
	# player MOVING (real position change) -> mirror should close
	var mx1: float = m.global_position.x
	for i in range(60):
		_p.global_position.x -= 4.0     # the player is genuinely moving
		await get_tree().physics_frame
	var moved: float = absf(m.global_position.x - mx1)
	check("mirror: holds still while you're still", held < 60.0, "drifted %.0f" % held)
	check("mirror: moves once YOU move", moved > held + 40.0, "held %.0f, moved %.0f" % [held, moved])
	m.queue_free()

	# ---------------- ERRATIC / WEAVE / POUNCER: they DO move (nonzero) --------
	for prof in ["erratic", "weave", "pouncer"]:
		var b = spawn_mover(prof)
		await get_tree().process_frame
		var mv: float = absf(await run_move(b, pin, pin + Vector2(500, 0), 120))
		check("%s: is an active, moving profile" % prof, mv > 20.0, "moved %.0f" % mv)
		b.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
