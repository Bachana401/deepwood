extends Node

# The last four mechanics: mirror, skyfall, dread_ward, covenant (+ tether,
# famine, traps). These were the ones sitting on boss entries as NAMES with no
# behaviour -- the fights claimed them and nothing happened.
#
# Each check proves the mechanic bites AND that its counter-play works.

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

	var BS = load("res://boss.gd")
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# ---------------- DREAD WARD ----------------
	var dw = BS.new()
	dw.boss_id = "gravewarden"
	host.add_child(dw)
	await get_tree().process_frame
	dw.has_dread_ward = true
	dw.player = p
	# Move the BOSS around the player, never the player around the boss: the
	# ground surface is at y=-39, so parking him at a bare boss's y=0 drops him
	# under the map and he falls forever (which is what silently voided the
	# grounded check below).
	# player in FRONT (boss faces +x by default, player to its right = front)
	dw.global_position = p.global_position + Vector2(-60, 0)
	var h0: int = dw.health
	dw.take_damage(80)
	check("dread_ward: hitting its FACE does nothing", dw.health == h0, "%d -> %d" % [h0, dw.health])
	# player BEHIND it
	dw.global_position = p.global_position + Vector2(60, 0)
	dw.take_damage(80)
	check("dread_ward: flanking it WORKS", dw.health < h0, "%d -> %d" % [h0, dw.health])

	# ---------------- SKYFALL ----------------
	var sk = BS.new()
	sk.boss_id = "stormcaller"
	host.add_child(sk)
	await get_tree().process_frame
	sk.player = p
	# Let the player actually LAND before arming it. Skipping this check when he
	# happened to still be falling is how "grounded is safe" would quietly stop
	# being tested the day it broke.
	var landed := false
	for i in range(240):
		await get_tree().physics_frame
		if p.is_on_floor():
			landed = true
			break
	sk.has_skyfall = true
	sk.skyfall_ready_at = 0.0
	sk.global_position = p.global_position
	# on the ground -> safe
	p.health = p.get_max_health()
	p.invincible = false
	p.monarch_iframes_until = 0.0
	var ghp: int = p.health
	for i in range(6):
		await get_tree().physics_frame
	check("skyfall: standing on the GROUND is safe", landed and p.health == ghp,
		"landed=%s  %d -> %d" % [landed, ghp, p.health])
	# airborne -> punished
	p.global_position.y -= 200.0
	p.velocity.y = -50.0
	sk.global_position = p.global_position
	sk.skyfall_ready_at = 0.0
	p.invincible = false
	p.monarch_iframes_until = 0.0
	var ahp: int = p.health
	for i in range(6):
		await get_tree().physics_frame
		if p.health < ahp:
			break
	check("skyfall: being AIRBORNE near it is punished", p.health < ahp,
		"%d -> %d" % [ahp, p.health])
	check("skyfall: the punish is survivable", not p.is_dead and p.health > 0)

	# ---------------- MIRROR ----------------
	# The trap this nearly shipped as: nothing was in a findable group, so the
	# mechanic would have looked implemented and silently reflected nothing.
	var arrow_scene := load("res://arrow.tscn")   # arrows need their HitArea child -- .gd.new() makes a bare node
	var mi = BS.new()
	mi.boss_id = "gravewarden"
	host.add_child(mi)
	await get_tree().process_frame
	mi.has_mirror = true
	mi.mirror_ready_at = 0.0
	mi.player = p
	# check findability on an arrow FAR from the mirror, or the boss reflects it
	# before we can look (which is what happened first time round)
	# high in open air: at ground level (y=0) the test arrow buries itself in the
	# terrain and break_arrow()s before the mirror ever sees it.
	mi.position = Vector2(4000, -1500)
	var probe = arrow_scene.instantiate()
	probe.direction = Vector2.RIGHT
	# position BEFORE add_child: an arrow records its start point in _ready and
	# despawns once it is max_range from it, so teleporting it after adding it
	# reads as "flew 4000px" and it deletes itself.
	probe.position = Vector2(-4000, -1500)
	host.add_child(probe)
	# Real player arrows are tagged "player_projectile" in setup() (2026-07-25: the tag
	# moved there and is gated so enemy/boss arrows aren't mislabelled and reflected by
	# their own mirror). Call setup() as the game does so the probe is a real player shot.
	probe.setup(Vector2.RIGHT, 10, 5.0, 10.0)
	await get_tree().process_frame
	check("a player arrow is FINDABLE in flight (the silent-no-op trap)",
		probe.is_in_group("player_projectile"),
		"nothing could find it -> mirror would reflect nothing, forever")
	probe.queue_free()
	var a = arrow_scene.instantiate()
	a.direction = Vector2.RIGHT
	a.position = mi.position + Vector2(20, 0)
	host.add_child(a)
	a.setup(Vector2.RIGHT, 10, 5.0, 10.0)   # tag it a player projectile (see above) so the mirror can find + reflect it
	for i in range(4):
		await get_tree().physics_frame
		if a.is_in_group("hostile_projectile"):
			break
	check("mirror: the shot is turned around and is now HOSTILE",
		is_instance_valid(a) and a.is_in_group("hostile_projectile")
		and not a.is_in_group("player_projectile"))

	# ---------------- COVENANT ----------------
	var c1 = BS.new(); c1.boss_id = "twin_despair"
	var c2 = BS.new(); c2.boss_id = "twin_despair"
	host.add_child(c1); host.add_child(c2)
	await get_tree().process_frame
	c1.has_covenant = true; c2.has_covenant = true
	c1.covenant_partner = c2; c2.covenant_partner = c1
	c1.player = p; c2.player = p
	c2.health = int(c2.max_health * 0.5)
	var wounded: int = c2.health
	c1._last_hurt_at = 0.0        # c1 is being left alone -> it heals its twin
	for i in range(70):
		await get_tree().physics_frame
	check("covenant: an unpressured twin HEALS its partner", c2.health > wounded,
		"%d -> %d" % [wounded, c2.health])
	# pressure it -> it stops healing
	c2.health = int(c2.max_health * 0.5)
	c1._last_hurt_at = c1._time_now()       # pressure it BEFORE the first tick,
	c1._covenant_accum = 0.0                # or a partial heal slips through
	await get_tree().physics_frame
	var held: int = c2.health
	for i in range(70):
		c1._last_hurt_at = c1._time_now()   # keep it under pressure every frame
		await get_tree().physics_frame
	check("covenant: PRESSURING the twin stops the healing (counter-play)",
		c2.health == held, "%d -> %d" % [held, c2.health])

	# ---------------- FALSE TWIN ----------------
	# Real boss.tscn from here on, and the flags are NOT set by hand: that is the
	# point. A mechanic can only be trusted if the boss's own passive list turns
	# it on -- "soulbind" sat in three passive lists for weeks with nothing
	# reading the name at all.
	var BSCN = load("res://boss.tscn")
	var real = BSCN.instantiate()
	real.boss_id = "hollow_choir"
	real.position = p.position + Vector2(900, -400)
	host.add_child(real)
	await get_tree().process_frame
	check("false_twin: the passive list actually switches it on", real.has_false_twin)
	var split := false
	for i in range(180):
		await get_tree().physics_frame
		if real.living_twins() > 0:
			split = true
			break
	check("false_twin: it splits into copies on its own", split and real.living_twins() == real.TWIN_COUNT,
		"twins=%d" % real.living_twins())
	var fake = real._twins[0] if real._twins.size() > 0 else null
	check("false_twin: a copy is a copy, and cannot split again",
		fake != null and fake.is_false_copy and not fake.has_false_twin)
	check("false_twin: the TELL -- only the real one casts a shadow",
		real.true_shadow != null and fake != null and fake.true_shadow == null)
	# the whole point: swinging at a fake buys you nothing
	var rhp: int = real.health
	fake.take_damage(200)
	check("false_twin: hurting a copy does NOT hurt the real one", real.health == rhp,
		"%d -> %d" % [rhp, real.health])
	check("false_twin: but the copy itself is killable", fake.health < fake.max_health)
	# clear the floor -> it binds new fakes rather than staying alone
	for t in real._twins:
		if is_instance_valid(t):
			t.take_damage(999999)
	for i in range(30):
		await get_tree().physics_frame
	real.twin_ready_at = 0.0     # skip the real 9s wait, keep the code path
	var resplit := false
	for i in range(180):
		await get_tree().physics_frame
		if real.living_twins() > 0:
			resplit = true
			break
	check("false_twin: killing every copy just makes it split again", resplit)

	# ---------------- SOULBIND ----------------
	var sb = BSCN.instantiate()
	sb.boss_id = "weaver"
	sb.position = p.position + Vector2(1600, -400)
	host.add_child(sb)
	await get_tree().process_frame
	check("soulbind: the passive list actually switches it on", sb.has_soulbind)
	var bound := false
	for i in range(180):
		await get_tree().physics_frame
		if sb.living_rune_adds() > 0:
			bound = true
			break
	check("soulbind: it binds rune adds on its own", bound, "adds=%d" % sb.living_rune_adds())
	sb.health = int(sb.max_health * 0.5)
	var fed: int = sb.health
	sb.take_damage(60)
	check("soulbind: while the runes are lit your hits FEED it", sb.health > fed,
		"%d -> %d" % [fed, sb.health])
	# break the runes -> the window opens
	for rune in sb.rune_adds:
		if is_instance_valid(rune):
			rune.take_damage(999999)
	# Wait in REAL seconds, not physics frames. A rune's death runs through an
	# animation and wall-clock timers, so under battery load 90 frames could
	# elapse with a rune still counted alive -- the boss was then still bound,
	# the next blow HEALED it (390 -> 420), and both checks below failed while
	# the mechanic was working perfectly. Same lesson test_arena already learned.
	# Keep swinging, the way a player would. enemy.take_damage() returns early
	# while a creature is inside its `_split_until` window ("scattered light --
	# untouchable"), so a single 999999 can simply be ignored, and then the boss
	# is still bound and the next blow HEALS it (390 -> 420). One rune surviving
	# a lone hit is correct behaviour, not a broken mechanic.
	var waited := 0.0
	while waited < 4.0 and sb.living_rune_adds() > 0:
		for rune2 in sb.rune_adds:
			if is_instance_valid(rune2):
				rune2.take_damage(999999)
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	await get_tree().physics_frame
	# say so out loud if the precondition never held, instead of blaming the mechanic
	check("soulbind: the runes actually died (test precondition)", sb.living_rune_adds() == 0,
		"%d still lit after %.1fs" % [sb.living_rune_adds(), waited])
	var openhp: int = sb.health
	sb.take_damage(60)
	check("soulbind: breaking the runes lets damage LAND (counter-play)", sb.health < openhp,
		"%d -> %d" % [openhp, sb.health])
	check("soulbind: the burst window is real, not instantly rebound",
		sb.living_rune_adds() == 0 and sb.soulbind_ready_at > sb._time_now())

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
