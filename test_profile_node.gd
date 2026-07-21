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

# THE FIXTURE WAS MEASURING BODY-BLOCKING, NOT MOVEMENT (2026-07-21).
# The assignment loop above spawns 11 REAL bosses with their real kits, and this
# file disposes of every boss with queue_free() -- which skips die(), and die()
# is what kills a boss's summoned minions. So each phase left live Enemy bodies
# standing in _host, exactly where the next mover spawns. The movers then had
# velocity but nowhere to go: weave read -36 px/s and travelled 2px pinned
# against a corpse, and pouncer sat on top of one with is_on_floor() false.
# Which profiles "failed" depended purely on spawn order, which is why the
# failure count wandered between runs. All three profiles move correctly with a
# clear floor -- verified at -96 / -64 / -94 px net. Sweep the stage first.
func clear_host() -> void:
	for c in _host.get_children():
		c.free()                       # immediate, not queued: the next spawn is NOW
	await get_tree().physics_frame

# ...AND THE STAGE KEPT PAUSING ITSELF. The village goes on living while this
# test runs, and a story beat opening a dialogue box PAUSES THE TREE. A paused
# tree delivers no _physics_process, so a mover just hung at its spawn y --
# no gravity, no velocity, is_on_floor() false -- and measured as "moved 0"
# while every other reading (not dead, full HP, not busy, in tree, physics
# processing on) looked perfectly healthy. Whichever profile happened to be
# running when the beat fired was the one that "failed", which is why the
# count wandered 1-4 between identical runs. Dismiss and resume every frame.
func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

# spawn a fresh gravewarden (non-combo) with a forced profile + no attacks, so we
# measure pure movement of that profile
func spawn_mover(prof: String) -> Node:
	await clear_host()
	var b = _bscn.instantiate()
	b.boss_id = "gravewarden"
	_host.add_child(b)
	b.profile = prof
	b.abilities = []
	b.player = _p
	return b

# TOTAL ground covered (path length), not net displacement. The three profiles
# below are judged on being ACTIVE, and erratic deliberately feints and pauses
# -- 60% toward you, 22% away, 18% stop -- so its NET travel is a random walk
# that can land under any threshold by luck (seen: 17px against a 20px bar).
# Summing per-frame movement measures what the check actually claims.
func run_path(b: Node, ppos: Vector2, bpos: Vector2, frames: int) -> float:
	b.global_position = bpos
	var last: float = b.global_position.x
	var total := 0.0
	for i in range(frames):
		keep_running()
		_p.global_position = ppos
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
		total += absf(b.global_position.x - last)
		last = b.global_position.x
	return total

# net horizontal travel of a mover over `frames`, player pinned at `ppos`
func run_move(b: Node, ppos: Vector2, bpos: Vector2, frames: int) -> float:
	b.global_position = bpos
	var x0: float = b.global_position.x
	for i in range(frames):
		keep_running()
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
	var r = await spawn_mover("rusher")
	await get_tree().process_frame
	var rmove: float = await run_move(r, pin, pin + Vector2(700, 0), 90)
	check("rusher: closes toward the player", rmove < -80.0, "moved %.0f" % rmove)
	r.queue_free()

	# ---------------- KITER: backs off when crowded ----------------
	var k = await spawn_mover("kiter")
	await get_tree().process_frame
	var kmove: float = await run_move(k, pin, pin + Vector2(90, 0), 90)   # start inside its range
	check("kiter: retreats when the player is inside its range", kmove > 60.0, "moved %.0f" % kmove)
	k.queue_free()

	# ---------------- TURTLE: barely moves ----------------
	var t = await spawn_mover("turtle")
	await get_tree().process_frame
	var tmove: float = absf(await run_move(t, pin, pin + Vector2(600, 0), 90))
	# a rusher would cover ~hundreds of px in the same window; the turtle creeps
	check("turtle: barely moves (wants you to come to it)", tmove < 200.0, "moved %.0f" % tmove)
	t.queue_free()

	# ---------------- PURSUER: accelerates while chasing ----------------
	var pu = await spawn_mover("pursuer")
	await get_tree().process_frame
	pu.global_position = pin + Vector2(700, 0)
	for i in range(70):
		keep_running()
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	check("pursuer: ramps up speed the longer it chases", pu._chase_ramp > 1.3,
		"ramp %.2f" % pu._chase_ramp)
	pu.queue_free()

	# ---------------- HOPPER: moves in jumps ----------------
	var h = await spawn_mover("hopper")
	await get_tree().process_frame
	h.global_position = pin + Vector2(500, 0)
	var hopped := false
	for i in range(120):
		keep_running()
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
		if h.velocity.y < -100.0:      # a jump was launched
			hopped = true
			break
	check("hopper: approaches in jumps", hopped)
	h.queue_free()

	# ---------------- MIRROR: moves only while the player moves ----------------
	var m = await spawn_mover("mirror")
	await get_tree().process_frame
	m.global_position = pin + Vector2(400, 0)
	# player still -> mirror should hold
	var mx0: float = m.global_position.x
	for i in range(40):
		keep_running()
		_p.global_position = pin
		_p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	var held: float = absf(m.global_position.x - mx0)
	# player MOVING (real position change) -> mirror should close
	var mx1: float = m.global_position.x
	for i in range(60):
		keep_running()
		_p.global_position.x -= 4.0     # the player is genuinely moving
		await get_tree().physics_frame
	var moved: float = absf(m.global_position.x - mx1)
	check("mirror: holds still while you're still", held < 60.0, "drifted %.0f" % held)
	check("mirror: moves once YOU move", moved > held + 40.0, "held %.0f, moved %.0f" % [held, moved])
	m.queue_free()

	# ---------------- ERRATIC / WEAVE / POUNCER: they DO move (nonzero) --------
	for prof in ["erratic", "weave", "pouncer"]:
		var b = await spawn_mover(prof)
		await get_tree().process_frame
		# 260 frames, not 120: pouncer idles up to 2.0s BETWEEN bursts, and the
		# old window was exactly 2.0s -- so a run could legitimately contain
		# barely one burst and read as "not moving". A window has to be longer
		# than the pause the behaviour is allowed to take, or it measures luck.
		var mv: float = await run_path(b, pin, pin + Vector2(500, 0), 260)
		check("%s: is an active, moving profile" % prof, mv > 60.0, "covered %.0f" % mv)
		b.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
