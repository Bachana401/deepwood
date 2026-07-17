extends Node

# The reactive-mechanic vocabulary (BOSSES.md 2). The dev's forever rule: every
# boss must differ in many ways, and difficulty must come from MECHANICS, never
# from one-shots.
#
# So every check here proves two things about each mechanic:
#   1. it actually fires and changes how the fight goes
#   2. its punish is survivable -- it stings, it does not delete you
# and that a boss WITHOUT the passive is completely unaffected by it.

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
	var host := Node2D.new()
	get_tree().root.add_child(host)
	p.god_mode = false

	# ---------------- SIDESTEP ----------------
	var ss = BS.new()
	ss.boss_id = "gravewarden"
	host.add_child(ss)
	await get_tree().process_frame
	ss.has_sidestep = true
	ss.sidestep_ready_at = 0.0
	ss.player = p
	# player standing in melee range -> it should read the swing and leave
	ss.global_position = p.global_position + Vector2(40, 0)
	var hp0: int = ss.health
	var x0: float = ss.global_position.x
	ss.take_damage(60)
	check("sidestep: the melee swing MISSES", ss.health == hp0, "%d -> %d" % [hp0, ss.health])
	check("sidestep: it actually moved away", absf(ss.global_position.x - x0) > 10.0,
		"moved %.1fpx" % absf(ss.global_position.x - x0))
	# ...but it can't dodge forever: the cooldown means the next hit lands
	ss.take_damage(60)
	check("sidestep: the FOLLOW-UP lands (cooldown = counter-play)", ss.health < hp0,
		"%d -> %d" % [hp0, ss.health])
	# and it cannot dodge what it can't read: a hit from range
	ss.sidestep_ready_at = 0.0
	ss.global_position = p.global_position + Vector2(900, 0)
	var hp1: int = ss.health
	ss.take_damage(60)
	check("sidestep: cannot dodge a hit from RANGE", ss.health < hp1, "ranged hit must land")

	# ---------------- STAGGER ARMOUR ----------------
	var sa = BS.new()
	sa.boss_id = "gravewarden"
	host.add_child(sa)
	await get_tree().process_frame
	sa.has_stagger_armour = true
	sa.player = p
	var sh0: int = sa.health
	sa.take_damage(5)                                    # chip
	check("stagger: chip damage rings off the guard", sa.health == sh0, "%d" % sa.health)
	var heavy: int = int(sa.max_health * 0.10)           # a committed blow
	sa.take_damage(heavy)
	check("stagger: a HEAVY blow breaks it", sa.health < sh0, "%d -> %d" % [sh0, sa.health])

	# ---------------- RIPOSTE ----------------
	var rp = BS.new()
	rp.boss_id = "gravewarden"
	host.add_child(rp)
	await get_tree().process_frame
	rp.has_riposte = true
	rp.riposte_ready_at = 0.0
	rp.player = p
	p.health = p.get_max_health()
	p.invincible = false
	p.monarch_iframes_until = 0.0
	# hit it in the RECOVERY (not telegraphing) -> no counter
	rp.telegraphing = false
	var php0: int = p.health
	rp.take_damage(20)
	check("riposte: hitting the RECOVERY is safe", p.health == php0, "%d -> %d" % [php0, p.health])
	# hit it during the WIND-UP -> it counters
	rp.telegraphing = true
	p.invincible = false
	p.monarch_iframes_until = 0.0
	rp.take_damage(20)
	check("riposte: hitting the WIND-UP is punished", p.health < php0,
		"%d -> %d" % [php0, p.health])
	check("riposte: the punish is survivable, not a one-shot",
		p.health > 0 and not p.is_dead and (php0 - p.health) < p.get_max_health() / 2,
		"took %d of %d max" % [php0 - p.health, p.get_max_health()])

	# ---------------- RHYTHM PUNISH ----------------
	var rh = BS.new()
	rh.boss_id = "gravewarden"
	host.add_child(rh)
	await get_tree().process_frame
	rh.has_rhythm_punish = true
	rh.player = p
	p.health = p.get_max_health()
	var rhp0: int = p.health
	# mash: four in a row, inside the window
	for i in range(4):
		p.invincible = false
		p.monarch_iframes_until = 0.0
		rh.take_damage(10)
	check("rhythm: mashing the same beat gets answered", p.health < rhp0,
		"%d -> %d after 4 consecutive" % [rhp0, p.health])
	check("rhythm: the punish is survivable", not p.is_dead and p.health > 0)
	# vary the rhythm -> streak resets, no punish
	rh.rhythm_streak = 0
	rh.rhythm_last_hit = 0.0
	p.health = p.get_max_health()
	var rhp1: int = p.health
	for i in range(3):
		p.invincible = false
		rh.take_damage(10)
		rh.rhythm_last_hit = rh._time_now() - 10.0    # a deliberate pause
	check("rhythm: varying the rhythm avoids it entirely", p.health == rhp1,
		"%d -> %d" % [rhp1, p.health])

	# ---------------- a plain boss is untouched by all of it ----------------
	var plain = BS.new()
	plain.boss_id = "gravewarden"
	host.add_child(plain)
	await get_tree().process_frame
	check("a boss without the passives has none of them",
		not plain.has_sidestep and not plain.has_riposte and not plain.has_stagger_armour
		and not plain.has_rhythm_punish and not plain.has_phase)
	var pl0: int = plain.health
	plain.player = p
	plain.global_position = p.global_position + Vector2(40, 0)
	plain.take_damage(5)
	check("...and takes even chip damage normally", plain.health == pl0 - 5,
		"%d -> %d" % [pl0, plain.health])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
