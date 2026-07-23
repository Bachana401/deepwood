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

# Free leftover gameplay nodes (hazards, homing wisps, projectiles, their
# tweens) between tiers so they don't pile up -- a big orphan backlog under
# headless can crash the engine at teardown even when every check is correct.
# THE STAGE PAUSES ITSELF MID-TEST (2026-07-21). The village keeps living while
# this suite runs, and a story beat opening a dialogue box PAUSES THE TREE. A
# paused tree delivers no _physics_process and freezes every ability coroutine,
# so a telegraphed attack simply never lands and the check reads "165 -> 165" --
# indistinguishable from a broken ability. Whichever ability was mid-flight when
# the beat fired was the one that "failed", which is why the count wandered
# 3-4 between identical runs. Dismiss the beat and resume, every frame.
func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func cleanup() -> void:
	for n in get_tree().root.find_children("*", "Node2D", true, false):
		var s = n.get_script()
		if s != null and (s.resource_path.ends_with("hazard_zone.gd") or s.resource_path.ends_with("homing_bolt.gd")):
			n.queue_free()
	for grp in ["hostile_projectile", "player_projectile"]:
		for n in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n):
				n.queue_free()
	await get_tree().process_frame

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
		keep_running()
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
			keep_running()
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
		keep_running()
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

	await cleanup()
	# ============ DEEP TIER (floors 35-60) ============

	# ---------------- DISSONANT SCREAM (disorient cone) ----------------
	var hc = mk.call("hollow_choir")
	await get_tree().process_frame
	hc.player = p
	hc.global_position = pin + Vector2(-200, 0)   # boss left, player right = in its cone
	p.global_position = pin
	p.clear_crowd_control()
	await hc.do_dissonant_scream()
	check("Hollow Choir Dissonant Scream: DISORIENTS a player in the cone",
		p._now() < p.disorient_until)
	p.clear_crowd_control()
	hc.queue_free()

	# ---------------- PRAYER PYRE (expanding flame front) ----------------
	var ap = mk.call("ashen_penitent")
	await get_tree().process_frame
	ap.player = p
	ap.global_position = pin
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	var php0: int = p.health
	# stand ~200px out: the expanding ring will sweep over this
	p.global_position = pin + Vector2(200, 0)
	await ap.do_prayer_pyre()
	check("Ashen Penitent Prayer Pyre: the flame front burns you", p.health < php0,
		"%d -> %d" % [php0, p.health])
	ap.queue_free()

	# ---------------- IRON MAIDEN (delayed cage, root + heavy hit) ----------------
	var ga = mk.call("gaoler")
	await get_tree().process_frame
	ga.player = p
	ga.global_position = pin + Vector2(160, 0)
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	p.global_position = pin
	p.clear_crowd_control()
	var ghp0: int = p.health
	await ga.do_iron_maiden()
	check("Gaoler Iron Maiden: cages (ROOTS) a standing player", p.cc_move_locked())
	check("Iron Maiden: and it hits hard", p.health < ghp0, "%d -> %d" % [ghp0, p.health])
	p.clear_crowd_control()
	ga.queue_free()

	# ---------------- POUNCE (gap-closer leap) ----------------
	var sf = mk.call("sablefang")
	await get_tree().process_frame
	sf.player = p
	p.global_position = pin
	sf.global_position = pin + Vector2(520, 0)     # far away
	var boss_x0: float = sf.global_position.x
	await sf.do_pounce()
	check("Sablefang Pounce: LEAPS the gap toward the player", sf.global_position.x < boss_x0 - 100.0,
		"%.0f -> %.0f (player at %.0f)" % [boss_x0, sf.global_position.x, p.global_position.x])
	sf.queue_free()

	# ---------------- SPLINTER BURST (radial + embers) ----------------
	var ef = mk.call("effigy")
	await get_tree().process_frame
	ef.player = p
	ef.global_position = pin + Vector2(300, 0)
	var arrows_before := get_tree().get_nodes_in_group("hostile_projectile").size() + get_tree().get_nodes_in_group("course_enemy").size()
	await ef.do_splinter_burst()
	await get_tree().process_frame
	var embers := host.get_tree().root.find_children("*", "Node2D", true, false).filter(
		func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("hazard_zone.gd"))
	check("Effigy Splinter Burst: leaves burning embers behind", embers.size() >= 2,
		"%d embers" % embers.size())
	ef.queue_free()

	# ---------------- KEENING (homing swarm) ----------------
	var mc = mk.call("mourncaller")
	await get_tree().process_frame
	mc.player = p
	mc.global_position = pin + Vector2(-300, 0)
	await mc.do_keening()
	await get_tree().process_frame
	var wisps := host.get_tree().root.find_children("*", "Node2D", true, false).filter(
		func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("homing_bolt.gd"))
	check("Mourncaller Keening: releases a homing swarm", wisps.size() >= 3,
		"%d wisps" % wisps.size())
	# and a wisp steers toward the player over a moment
	if wisps.size() > 0:
		var w = wisps[0]
		p.global_position = pin
		var d0: float = w.global_position.distance_to(p.global_position)
		# up to ~2.3s: enough for a wisp that spawned pointing AWAY to turn a full
		# 180 at 2.6 rad/s and then close in (or hit and free itself)
		var closed := false
		for i in range(140):
			p.global_position = pin
			keep_running()
			await get_tree().physics_frame
			if not is_instance_valid(w) or w.global_position.distance_to(p.global_position) < d0 - 20.0:
				closed = true
				break
		check("Keening: a wisp homes in (closes distance or hits)", closed)
	mc.queue_free()

	await cleanup()
	# ============ DEEP TIER (floors 65-90) ============

	# ---------------- AMBUSH (blink behind + stun) ----------------
	var un = mk.call("unseen")
	await get_tree().process_frame
	un.player = p
	un.global_position = pin + Vector2(400, 0)
	p.global_position = pin
	p.clear_crowd_control()
	await un.do_ambush()
	check("Unseen Ambush: blinks in from far to right beside the player",
		un.global_position.distance_to(p.global_position) < 200.0,   # started 400px away
		"dist %.0f" % un.global_position.distance_to(p.global_position))
	check("Ambush: and stuns on the strike", p.cc_action_locked())
	p.clear_crowd_control()
	un.queue_free()

	# ---------------- IMPALE (tracking overhead + knockback) ----------------
	var wn = mk.call("warden_of_nails")
	await get_tree().process_frame
	wn.player = p
	wn.global_position = pin + Vector2(180, 0)
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	p.global_position = pin
	var whp0: int = p.health
	await wn.do_impale()
	check("Warden of Nails Impale: the tracked nail hits a still player", p.health < whp0,
		"%d -> %d" % [whp0, p.health])
	wn.queue_free()

	# ---------------- PINCER LUNGE (cross-leap) ----------------
	var td = mk.call("twin_despair")
	await get_tree().process_frame
	td.player = p
	p.global_position = pin
	td.global_position = pin + Vector2(-260, 0)     # left of player
	await td.do_pincer_lunge()
	check("Twin Despair Pincer Lunge: leaps THROUGH to the far side",
		td.global_position.x > p.global_position.x + 60.0,
		"boss ended at %.0f, player at %.0f" % [td.global_position.x, p.global_position.x])
	td.queue_free()

	# ---------------- ERUPTION (a grounded player in the crack's path is hit) ----------------
	var ck = mk.call("cinderking")
	await get_tree().process_frame
	ck.player = p
	# let the player settle onto real ground so is_on_floor() is genuinely true
	p.global_position = Vector2(1500.0, -100.0)
	var grounded := false
	for i in range(240):
		keep_running()
		await get_tree().physics_frame
		if p.is_on_floor():
			grounded = true
			break
	var g: Vector2 = p.global_position
	# boss 270px to the LEFT at the same ground line: its rightward crack (step 2 =
	# 2*135) reaches the standing player's x
	ck.global_position = Vector2(g.x - 270.0, g.y)
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	var ehp0: int = p.health
	# do_eruption doesn't move the player; with no input he stays grounded on the
	# spot, so a plain await is enough (no fire-and-forget coroutine).
	await ck.do_eruption()
	check("Cinderking Eruption: a grounded player in the wave's path is hit",
		grounded and p.health < ehp0, "grounded=%s  %d -> %d" % [grounded, ehp0, p.health])
	ck.queue_free()

	# ---------------- REFRACTION (multi-beam) ----------------
	# ground both at the same floor line so neither falls during the 0.5s
	# telegraph (a falling dummy would drop out of the beam -- realistic in-game,
	# but flaky for a fixed test).
	var gs = mk.call("glass_saint")
	await get_tree().process_frame
	gs.player = p
	gs.global_position = Vector2(g.x - 300.0, g.y)
	p.global_position = Vector2(g.x, g.y)
	for i in range(6):
		keep_running()
		await get_tree().physics_frame
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	var rhp0: int = p.health
	await gs.do_refraction()
	check("Glass Saint Refraction: a fanned beam catches the player dead ahead", p.health < rhp0,
		"%d -> %d" % [rhp0, p.health])
	gs.queue_free()

	# ---------------- RIPOSTE STANCE (active counter) ----------------
	# Test the parry GATE in take_damage directly (arm the stance state), rather
	# than fire-and-forget the blocking do_riposte_stance coroutine.
	var lm = mk.call("last_man")
	await get_tree().process_frame
	lm.player = p
	lm.global_position = pin + Vector2(120, 0)
	p.global_position = pin
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	p.clear_crowd_control()
	# The dev-kit bag holds the Aegis Ward ("blocks one hit every 6s", wall-clock).
	# Under suite CPU load >6 real seconds pass between phases, the ward comes off
	# cooldown and SWALLOWS the riposte counter -- 160 -> 160 with the stun still
	# landing (suiteC flake 2026-07-23). Park it far in the future so the counter
	# hit always reaches health.
	p.aegis_ready_at = p._now() + 999.0
	lm.parry_until = lm._time_now() + 30.0     # arm the guard WIDE (load-proof: these
	                                           # awaited frames can eat wall-clock seconds)
	lm._parry_consumed = false
	keep_running()
	await get_tree().physics_frame
	var boss_hp_before: int = lm.health
	var my_hp_before: int = p.health
	lm.take_damage(40)   # swing at it during the guard
	check("Last Man Riposte Stance: the parried blow deals NO damage", lm.health == boss_hp_before,
		"boss %d -> %d" % [boss_hp_before, lm.health])
	check("Riposte Stance: and it counters you (damage + stun)",
		p.health < my_hp_before and p.cc_action_locked(),
		"player %d -> %d, stunned=%s" % [my_hp_before, p.health, p.cc_action_locked()])
	# after the counter is consumed, the NEXT hit lands normally
	p.clear_crowd_control()
	keep_running()
	await get_tree().physics_frame
	var boss_hp2: int = lm.health
	lm.take_damage(40)
	check("Riposte Stance: only the FIRST hit is parried (next one lands)", lm.health < boss_hp2,
		"boss %d -> %d" % [boss_hp2, lm.health])
	lm.queue_free()

	await cleanup()
	# ============ APEX TIER (floors 95-100) ============

	# ---------------- JUDGMENT (sweeping light wall) ----------------
	var se = mk.call("seraph")
	await get_tree().process_frame
	se.player = p
	se.global_position = pin
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	p.global_position = pin + Vector2(300, 0)   # off to one side; the wall sweeps through
	var jhp0: int = p.health
	var jdone := false
	# Drive Judgment DIRECTLY, the way the Black Sun and Tidal Crush sections
	# below already do. This used to just wait 120 frames and hope: Seraphiel is
	# a COMBO boss, so it never picks single attacks off its `abilities` list --
	# judgment only ever arrives inside a three-ability sentence, and might be
	# the last word of it. So the check passed whenever some OTHER ability (dive,
	# volley, rain, nova) happened to clip the player first, and failed whenever
	# the sentence ran long. It was never testing the wall of light at all.
	se.start_attack("judgment")
	for i in range(200):
		p.global_position = pin + Vector2(300, 0)   # hold still; the wall comes to you
		p.velocity = Vector2.ZERO
		keep_running()
		await get_tree().physics_frame
		if p.health < jhp0:
			jdone = true
			break
		if not se.is_busy and i > 5:
			break
	check("Seraphiel Judgment: the sweeping wall of light hits a still player", jdone,
		"%d -> %d" % [jhp0, p.health])
	# the do_judgment coroutine is still sweeping; let it finish
	for i in range(30):
		keep_running()
		await get_tree().physics_frame
	se.queue_free()

	# ---------------- BLACK SUN (shrinking safe ring) ----------------
	var ec = mk.call("eclipse")
	await get_tree().process_frame
	ec.player = p
	ec.global_position = pin
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	# stand FAR from the Titan: as the light ring shrinks, being outside it bites
	p.global_position = pin + Vector2(560, 0)
	var bhp0: int = p.health
	var bdone := false
	var brun := false
	# run black_sun and hold the player out in the dark
	ec.start_attack("black_sun")
	for i in range(200):
		p.global_position = pin + Vector2(560, 0)
		p.velocity = Vector2.ZERO
		keep_running()
		await get_tree().physics_frame
		if p.health < bhp0:
			bdone = true
			break
		if not ec.is_busy and i > 5:
			break
	check("Eclipse Black Sun: standing outside the shrinking light is bitten", bdone,
		"%d -> %d" % [bhp0, p.health])
	ec.queue_free()

	# ---------------- TIDAL CRUSH (low wave; airborne is safe) ----------------
	var lev = mk.call("leviathan")
	await get_tree().process_frame
	lev.player = p
	# ground the player, put boss at same floor line, player near the floor in the path
	p.global_position = Vector2(g.x, g.y)
	for i in range(60):
		keep_running()
		await get_tree().physics_frame
		if p.is_on_floor():
			break
	var g2: Vector2 = p.global_position
	lev.global_position = Vector2(g2.x - 300.0, g2.y - 40.0)
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	var thp0: int = p.health
	var tdone := false
	lev.start_attack("tidal_crush")
	for i in range(160):
		p.velocity.x = 0.0
		keep_running()
		await get_tree().physics_frame
		if p.health < thp0:
			tdone = true
			break
		if not lev.is_busy and i > 5:
			break
	check("Leviathan Tidal Crush: a low, grounded player is swept", tdone,
		"%d -> %d" % [thp0, p.health])
	lev.queue_free()

	# ---------------- UNWRITING (void tears open, one under you) ----------------
	await cleanup()
	var wz = mk.call("wizard")
	await get_tree().process_frame
	wz.player = p
	wz.global_position = pin + Vector2(-200, 0)
	p.global_position = pin
	await wz.do_unwriting()
	await get_tree().process_frame
	var voids := host.get_tree().root.find_children("*", "Node2D", true, false).filter(
		func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("hazard_zone.gd"))
	check("Fallen Wizard Unwriting: void zones tear open across the arena", voids.size() >= 4,
		"%d void zones" % voids.size())
	# one opens under the player -> standing still, it should hurt
	p.health = p.get_max_health(); p.invincible = false; p.monarch_iframes_until = 0.0
	var uhp0: int = p.health
	for i in range(60):
		p.global_position = pin
		keep_running()
		await get_tree().physics_frame
		if p.health < uhp0:
			break
	check("Unwriting: the void under you erases your footing (damages)", p.health < uhp0,
		"%d -> %d" % [uhp0, p.health])
	wz.queue_free()

	await cleanup()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
