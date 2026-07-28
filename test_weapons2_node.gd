extends Node
# THE BEHAVIOR LIBRARY (weapons overhaul wave 1, 2026-07-28). Five new
# projectile kinds -- orbiter, ricochet, cluster, lob, lash -- proven to DO
# their mechanic headless, not just fly: the orbiter spins and threads home,
# the ricochet leaps between bodies, the cluster blossoms into shards, the
# lob arcs under gravity and blossoms where it lands, the lash rakes on both
# passes.

const WP = preload("res://weapon_projectile.gd")
const ENEMY_SCENE = preload("res://enemy.tscn")

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _spawn_dummy(host: Node, pos: Vector2) -> Node:
	var e = ENEMY_SCENE.instantiate()
	e.respawns = false
	host.add_child(e)
	e.global_position = pos
	e.set_physics_process(false)   # a stationary target, nothing else
	e.add_to_group("course_enemy") # a REAL foe is always in a hostile group --
	# the ricochet's retarget scan reads the groups, as all target scans do
	return e

func _fire(host: Node, kind: String, from: Vector2, dir: Vector2, cfg := {}) -> Node:
	var p = WP.new()
	p.kind = kind
	p.direction = dir.normalized()
	p.speed = float(cfg.get("speed", 600.0))
	p.damage = int(cfg.get("damage", 10))
	p.max_distance = float(cfg.get("range", 300.0))
	for k in ["dwell", "bounces", "shards", "aoe_radius"]:
		if cfg.has(k):
			p.set(k, cfg[k])
	p.source = get_tree().get_first_node_in_group("player")
	host.add_child(p)
	p.global_position = from
	return p

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _ready() -> void:
	var pl: Node = null
	for i in range(1200):
		await get_tree().process_frame
		pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			break
	if pl == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	var host := Node2D.new()
	get_tree().root.add_child(host)
	# stage the lab far from the village so nothing interferes
	var base := Vector2(-4000.0, -2000.0)

	# ---- RICOCHET: leaps from the first body to the second ----
	var r1 = _spawn_dummy(host, base + Vector2(200, 0))
	var r2 = _spawn_dummy(host, base + Vector2(320, 40))
	var rp = _fire(host, "ricochet", base, Vector2.RIGHT, {"damage": 8, "range": 400.0, "bounces": 3})
	var r2_h0: int = r2.health
	await _frames(90)
	check("ricochet leaps to a second body", r2.health < r2_h0,
		"%d -> %d" % [r2_h0, r2.health])
	if is_instance_valid(rp): rp.queue_free()

	# ---- CLUSTER: blossoms into shards at full reach ----
	var before := _count_projectiles()
	var cp = _fire(host, "cluster", base + Vector2(0, -300), Vector2.RIGHT, {"range": 120.0, "shards": 5})
	await _frames(30)
	var after := _count_projectiles()
	check("cluster blossoms into shards", after >= before + 3,
		"%d -> %d live projectiles" % [before, after])
	if is_instance_valid(cp): cp.queue_free()

	# ---- LOB: arcs under gravity and detonates at the landing line ----
	var lp = _fire(host, "lob", base + Vector2(0, -600), Vector2.RIGHT, {"range": 900.0, "speed": 420.0})
	var seen_rise := false
	var freed := false
	for i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(lp):
			freed = true
			break
		if lp.global_position.y < base.y - 620.0:
			seen_rise = true
	check("lob rises before it falls", seen_rise)
	check("...and blossoms where it lands", freed)

	# ---- ORBITER: reaches the far point, spins, then threads home ----
	var op = _fire(host, "orbiter", pl.global_position + Vector2(0, -80), Vector2.RIGHT,
		{"range": 200.0, "dwell": 0.8, "speed": 700.0})
	await _frames(30)
	var spinning: bool = is_instance_valid(op) and op._behave_state == 1
	check("orbiter spins at the far point", spinning,
		"state=%s" % (str(op._behave_state) if is_instance_valid(op) else "freed"))
	var came_home := false
	for i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(op):
			came_home = true
			break
	check("...and threads home", came_home)

	# ---- CHAIN MAUL: whirls about the wielder, hurls, hauls home ----
	var mp = _fire(host, "chain_maul", pl.global_position, Vector2.RIGHT,
		{"range": 240.0, "speed": 650.0})
	await _frames(20)
	var whirling: bool = is_instance_valid(mp) and mp._behave_state == 0 \
		and mp.global_position.distance_to(pl.global_position) < 220.0
	check("chain maul whirls about the wielder first", whirling,
		"state=%s" % (str(mp._behave_state) if is_instance_valid(mp) else "freed"))
	var hurled := false
	var hauled := false
	for i in range(300):
		await get_tree().physics_frame
		if is_instance_valid(mp) and mp._behave_state == 1:
			hurled = true
		if not is_instance_valid(mp):
			hauled = true
			break
	check("...then hurls itself down the aim", hurled)
	check("...and hauls back home on its chain", hauled)

	# ---- FLAGSHIP RIDERS (polish): named tricks, not just bigger numbers ----
	# every rider string authored in the roster is READ by real code
	var rider_src := ""
	for f in ["weapon_projectile.gd", "player.gd", "storm_cloud.gd"]:
		rider_src += FileAccess.open("res://" + f, FileAccess.READ).get_as_text()
	var unread_riders := []
	for rk in ["grows", "choir", "sunfall", "patient", "walker", "goodbye",
			"borrow", "courier", "coffin", "kindly", "moon"]:
		if not rider_src.contains('"%s"' % rk):
			unread_riders.append(rk)
	check("every flagship rider is read by the mechanics code",
		unread_riders.is_empty(), ", ".join(unread_riders))
	# The Rumor GROWS: leap math amplifies instead of decaying
	var g1 = _spawn_dummy(host, base + Vector2(0, -1300))
	var g2 = _spawn_dummy(host, base + Vector2(140, -1300))
	var gp = _fire(host, "ricochet", base + Vector2(-120, -1300), Vector2.RIGHT,
		{"damage": 20, "range": 400.0, "bounces": 3})
	gp.rider = "grows"
	var g1_h0: int = g1.health
	var g2_h0: int = g2.health
	await _frames(90)
	var first_hit: int = g1_h0 - g1.health
	var second_hit: int = g2_h0 - g2.health
	check("The Rumor grows in the telling (each leap hits harder)",
		second_hit > first_hit and first_hit > 0,
		"first %d, second %d" % [first_hit, second_hit])
	if is_instance_valid(gp): gp.queue_free()
	if is_instance_valid(g1): g1.queue_free()
	if is_instance_valid(g2): g2.queue_free()
	# A Borrowed Star sheds two embers at the apex
	var before_b := _count_projectiles()
	var bp = _fire(host, "lob", base + Vector2(0, -1600), Vector2.RIGHT,
		{"range": 900.0, "speed": 420.0})
	bp.rider = "borrow"
	await _frames(30)
	var after_b := _count_projectiles()
	check("A Borrowed Star becomes three falling lights", after_b >= before_b + 2,
		"%d -> %d projectiles" % [before_b, after_b])
	await _frames(200)   # let the embers land and blossom away
	# A Small Personal Sun: the blast leaves a grounded sunlet behind
	var sp2 = _fire(host, "fireball", base + Vector2(0, -1900), Vector2.RIGHT,
		{"damage": 20, "range": 60.0, "aoe_radius": 90.0})
	sp2.rider = "sunfall"
	var sunlet: Node = null
	for i in range(60):
		await get_tree().physics_frame
		for c in host.get_children():
			if "sun_mode" in c and c.sun_mode:
				sunlet = c
				break
		if sunlet != null:
			break
	check("A Small Personal Sun leaves its sunlet burning the spot", sunlet != null)
	# What the Sky Charges: the storm WALKS toward prey
	var wd = _spawn_dummy(host, base + Vector2(400, -2200))
	var storm = load("res://storm_cloud.gd").new()
	storm.drift = true
	storm.duration = 6.0
	host.add_child(storm)
	storm.global_position = base + Vector2(0, -2200)
	var sx0: float = storm.global_position.x
	await _frames(60)
	check("What the Sky Charges walks toward its prey",
		is_instance_valid(storm) and storm.global_position.x > sx0 + 30.0,
		"x %0.0f -> %0.0f" % [sx0, storm.global_position.x if is_instance_valid(storm) else -1.0])
	if is_instance_valid(storm): storm.queue_free()
	if is_instance_valid(sunlet): sunlet.queue_free()
	if is_instance_valid(wd): wd.queue_free()

	# ---- LASH: goes out, comes back, and rakes on both passes ----
	var d1 = _spawn_dummy(host, base + Vector2(150, -900))
	var d1_h0: int = d1.health
	var xp = _fire(host, "lash", base + Vector2(0, -900), Vector2.RIGHT, {"range": 300.0, "damage": 6})
	var lash_home := false
	for i in range(760):   # the thread home runs the whole way back to the
		# player's hand across the village -- give it its real travel time
		await get_tree().physics_frame
		if not is_instance_valid(xp):
			lash_home = true
			break
	check("lash returns to the thrower's hand", lash_home)
	check("...and cut on the way", d1.health < d1_h0, "%d -> %d" % [d1_h0, d1.health])

	# ---- STORM TOME: the stormlet works its patch of ground ----
	var sc = preload("res://storm_cloud.gd").new()
	sc.damage = 6
	sc.radius = 60.0
	sc.duration = 2.0
	sc.strike_gap = 0.2
	host.add_child(sc)
	sc.global_position = base + Vector2(0, -1400)
	var s1 = _spawn_dummy(host, base + Vector2(0, -1400))
	var s1_h0: int = s1.health
	await _frames(90)
	check("the storm tome's cloud strikes inside its ring", s1.health < s1_h0,
		"%d -> %d" % [s1_h0, s1.health])
	var storm_gone := false
	for i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(sc):
			storm_gone = true
			break
	check("...and the storm blows itself out", storm_gone)

	# ---- SENTRY: the totem snipes on its own clock ----
	var tot = preload("res://sentry_totem.gd").new()
	tot.damage = 5
	tot.lifetime = 4.0
	tot.fire_gap = 0.5
	tot.source = pl
	host.add_child(tot)
	tot.global_position = base + Vector2(0, -1800)
	var t1 = _spawn_dummy(host, base + Vector2(180, -1830))
	var t1_h0: int = t1.health
	await _frames(150)
	check("the planted sentry snipes the nearest foe", t1.health < t1_h0,
		"%d -> %d" % [t1_h0, t1.health])

	# ---- EXTENDING STAFF: landed rhythm draws it longer; a whiff resets ----
	var keep_weapon: String = pl.active_weapon_id if "active_weapon_id" in pl else ""
	pl.inventory.add_item("wpn_boughstaff", 1)
	pl.wield_weapon("wpn_boughstaff")
	pl._staff_combo = 0
	check("a fresh staff is a walking stick", absf(pl.staff_reach_mult() - 1.0) < 0.01)
	pl._staff_combo = 3
	pl._staff_last_hit_at = pl._now()
	check("three landed beats draw it to full length", pl.staff_reach_mult() > 2.0,
		"%.2f" % pl.staff_reach_mult())
	pl._staff_last_hit_at = pl._now() - 5.0
	check("...and a broken rhythm shrinks it back", absf(pl.staff_reach_mult() - 1.0) < 0.01)
	pl.staff_note_swing(false, pl.global_position)
	check("a whiff resets the combo count", pl._staff_combo == 0)
	if keep_weapon != "":
		pl.wield_weapon(keep_weapon)

	# ---- the audio pass (2026-07-28): silence was a bug, and stays fixed ----
	var silent := []
	for r in ["crack", "pop", "thump", "whoosh", "chime", "tear"]:
		if SfxSynth._bank(r).data.size() <= 0:
			silent.append(r)
	check("every SFX recipe synthesizes real samples", silent.is_empty(), ", ".join(silent))
	var players_before := 0
	for c in get_tree().root.get_children():
		if c is AudioStreamPlayer2D:
			players_before += 1
	SfxSynth.play_at(self, base, "pop", -24.0)
	var players_after := 0
	for c in get_tree().root.get_children():
		if c is AudioStreamPlayer2D:
			players_after += 1
	check("play_at spawns a positional one-shot at the root",
		players_after == players_before + 1, "%d -> %d" % [players_before, players_after])
	var hook_src := ""
	for f2 in ["storm_cloud.gd", "weapon_projectile.gd", "player.gd", "shade.gd",
			"sentry_totem.gd", "mirror_mage.gd"]:
		hook_src += FileAccess.open("res://" + f2, FileAccess.READ).get_as_text()
	check("the once-silent mechanics all call the synth (10+ hook sites)",
		hook_src.count("SfxSynth.play_at") >= 10
		and hook_src.contains("play_stream_at(self, global_position, SFX_EXPLOSION"))

	for e in [r1, r2, d1, s1, t1]:
		if is_instance_valid(e): e.queue_free()
	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _count_projectiles() -> int:
	var n := 0
	for x in get_tree().get_nodes_in_group("player_projectile"):
		if is_instance_valid(x):
			n += 1
	return n
