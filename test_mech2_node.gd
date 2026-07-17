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
	await get_tree().process_frame
	check("a player arrow is FINDABLE in flight (the silent-no-op trap)",
		probe.is_in_group("player_projectile"),
		"nothing could find it -> mirror would reflect nothing, forever")
	probe.queue_free()
	var a = arrow_scene.instantiate()
	a.direction = Vector2.RIGHT
	a.position = mi.position + Vector2(20, 0)
	host.add_child(a)
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

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
