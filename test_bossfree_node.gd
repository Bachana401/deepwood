extends Node
# SAFETY LOCK: freeing a boss mid-telegraph must never crash the run (dev
# 2026-07-23). I HYPOTHESISED that a boss freed while awaiting
# create_timer().timeout (e.g. exit a dungeon mid-fight) would resume its
# coroutine on the freed node and segfault -- so I wrote this to PROVE it before
# doing ~20 speculative guards in boss.gd. It does NOT crash: Godot 4 safely
# drops a coroutine whose object was freed. So no guard hardening was needed, and
# this stays as a regression lock that the property holds. (The test_sig exit-139
# flake was a DIFFERENT free-time interaction with the live boss AI process, fixed
# there by not running the AI the test never needed -- NOT by the coroutines.)
# It fires every telegraph on every boss, frees each mid-await, then lets all the
# timers fire; any unguarded resume would exit != 0 before RESULT.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	var BSCN = load("res://boss.tscn")
	var host := Node2D.new()
	get_tree().root.add_child(host)
	p.global_position = Vector2(1500.0, -100.0)

	# Every boss id, so every ability list's telegraph awaits get exercised.
	var ids := ["gravewarden", "frost_monarch", "cinder_colossus", "weaver", "stormcaller",
		"void_sovereign", "hollow_choir", "ashen_penitent", "gaoler", "sablefang",
		"effigy", "mourncaller"]
	var started := 0
	for bid in ids:
		var b = BSCN.instantiate()
		b.boss_id = bid
		host.add_child(b)
		b.player = p
		b.global_position = Vector2(1520.0, -100.0)
		await get_tree().process_frame
		# kick off EVERY telegraph coroutine this boss has, then free it while they
		# are all still awaiting their create_timer.timeout
		for m in ["do_slam", "do_charge", "do_barrage", "do_nova", "do_meteor_rain",
				"do_summon", "do_pillars", "do_volley", "do_rhythm_counter", "do_judgment",
				"do_soul_split", "do_skyfall"]:
			if b.has_method(m):
				b.call(m)     # fire-and-forget: starts the coroutine, we do not await it
				started += 1
		b.queue_free()        # FREED mid-telegraph
	check("started telegraph coroutines on every boss", started > 0, str(started))

	# let all the create_timer.timeout signals fire onto the (now freed) bosses.
	# If any resumes unguarded, the process dies here and never reaches RESULT.
	for i in range(90):
		await get_tree().process_frame
	check("no coroutine resumed on a freed boss (survived the timers)", true)

	if is_instance_valid(host):
		host.queue_free()
	await get_tree().process_frame
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
