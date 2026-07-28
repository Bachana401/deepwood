extends Node
# PHASE TWO (dev 2026-07-28: "build phases for all of them, each unique").
# Proves the second forms are REAL for all 22 bosses:
#   1. the registry names all 22, and every name is unique
#   2. phase_two() APPLIES for every id (phase2_applied is set only by the
#      per-boss branch, so a named-but-never-read entry fails here -- the
#      ladder's oldest trap, guarded forever)
#   3. the threshold actually fires it (integration via take_damage)
#   4. spot-checks that flagship transformations change real machinery
#      (profile flips, budgets grow, covenant suspends, the choir's tell
#      inverts) rather than being banner text

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

	var BS = load("res://boss.gd")
	var ids: Array = BS.BOSSES.keys()

	# ---- 1. the registry covers all 22, each name unique ----
	check("every boss has a phase-2 entry", ids.size() == BS.PHASE_TWO.size()
		and ids.all(func(id): return BS.PHASE_TWO.has(id)),
		"%d bosses vs %d entries" % [ids.size(), BS.PHASE_TWO.size()])
	var names := {}
	for id in ids:
		names[BS.PHASE_TWO.get(id, "")] = true
	check("every phase-2 name is unique", names.size() == ids.size(),
		"%d unique names" % names.size())

	var host := Node2D.new()
	get_tree().root.add_child(host)

	# ---- 2. every branch APPLIES (no named-but-never-read phase) ----
	var unapplied := []
	for id in ids:
		var b = BS.new()
		b.boss_id = id
		host.add_child(b)
		b.set_physics_process(false)   # the harness drives every tick by hand
		await get_tree().process_frame
		b.player = p
		b.phase_two()
		if not (b.phase2_active and b.phase2_applied):
			unapplied.append(id)
		# ...and the living half must run one tick without erroring
		b.tick_phase_two(0.05)
		b.queue_free()
		await get_tree().process_frame
	check("phase_two APPLIES for all 22 (branch exists and is consumed)",
		unapplied.is_empty(), str(unapplied))

	# ---- 3. the threshold fires it through real damage ----
	var tb = BS.new()
	tb.boss_id = "gravewarden"
	host.add_child(tb)
	await get_tree().process_frame
	tb.player = p
	tb.global_position = p.global_position + Vector2(60, 0)
	tb.health = int(tb.max_health * 0.55)
	tb.take_damage(int(tb.max_health * 0.1))
	check("crossing the threshold transforms (not just enrages)",
		tb.is_enraged and tb.phase2_active)
	check("...and the graves opened (summon budget grew)", tb.summon_room_bonus == 2)
	tb.queue_free()

	# ---- 4. flagship spot-checks: the change is MACHINERY, not text ----
	# PENANCE ENDS: the turtle stands up and hunts
	var ap = BS.new()
	ap.boss_id = "ashen_penitent"
	host.add_child(ap)
	await get_tree().process_frame
	ap.player = p
	var pre_speed: float = ap.base_move_speed
	ap.phase_two()
	check("PENANCE ENDS: turtle becomes pursuer", ap.profile == "pursuer")
	check("...and it moves like it means it", ap.base_move_speed > pre_speed * 2.0)
	ap.queue_free()

	# NEVER THERE: longer phases, faster traps -- and the knobs are CONSUMED
	var un = BS.new()
	un.boss_id = "unseen"
	host.add_child(un)
	await get_tree().process_frame
	un.player = p
	un.phase_two()
	check("NEVER THERE: intangibility stretches", un.phase_seconds_mult > 1.0)
	check("...traps arm faster", un.trap_period_mult < 1.0)
	un.enter_phase()
	check("...and enter_phase actually consumes the stretch",
		un.phase_until - un._time_now() > un.PHASE_SECONDS * 1.05)
	un.queue_free()

	# ONE SOUL: fusing suspends covenant healing -- the opening is real
	var td = BS.new()
	td.boss_id = "twin_despair"
	host.add_child(td)
	await get_tree().process_frame
	td.player = p
	td.phase_two()
	td._p2_next_fuse_at = 0.0          # force the fuse window open NOW
	td._tick_one_soul(0.05)
	check("ONE SOUL: the fused window opens", td._p2_fused_until > 0.0)
	check("...and a fused soul cannot mend", td.covenant_suspended_until >= td._p2_fused_until)
	var partner = BS.new()
	partner.boss_id = "twin_despair"
	host.add_child(partner)
	await get_tree().process_frame
	td.has_covenant = true
	td.covenant_partner = partner
	td._last_hurt_at = 0.0
	partner.health = 1
	var before: int = partner.health
	for i in range(30):
		td.tick_covenant(0.1)
	check("...covenant healing is DEAD during the window", partner.health == before,
		"%d -> %d" % [before, partner.health])
	td.queue_free()
	partner.queue_free()

	# THE FULL CHOIR: one more fake, and the tell inverts
	var hc = BS.new()
	hc.boss_id = "hollow_choir"
	host.add_child(hc)
	hc.set_physics_process(false)   # ONE split, by hand -- phase_two arms an
	# immediate auto-resplit and the live tick was double-splitting the choir
	await get_tree().process_frame
	hc.player = p
	hc.phase_two()
	hc._do_false_split()
	await get_tree().process_frame
	check("THE FULL CHOIR: the choir grows", hc.living_twins() == hc.TWIN_COUNT + 1,
		"%d twins" % hc.living_twins())
	check("...and the REAL one hides its shadow",
		hc.true_shadow == null or not hc.true_shadow.visible)
	for t in hc._twins:
		if is_instance_valid(t):
			t.queue_free()
	hc.queue_free()

	# quickened kits actually quicken (cooldown_mult consumes phase2_cd_mult)
	var ec = BS.new()
	ec.boss_id = "eclipse"
	host.add_child(ec)
	await get_tree().process_frame
	ec.player = p
	var cd0: float = ec.cooldown_mult()
	ec.phase_two()
	check("TOTALITY: the kit quickens through cooldown_mult",
		ec.cooldown_mult() < cd0, "%.2f -> %.2f" % [cd0, ec.cooldown_mult()])
	ec.queue_free()

	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
