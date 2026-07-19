extends Node

# Statuses across every entity. Bosses, special mobs and siege enemies had NO
# apply_status at all -- and every thrower guards with has_method -- so burn,
# poison and slow silently vanished against them. That killed two whole class
# specs at every boss fight: the Warden is PURE DoT, the Elementalist's keystone
# is Ignite. The rule now: DoT lands in full everywhere; hard control is
# resisted where it would break the fight (a boss slows but never stops).

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
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# ---------------- BOSS: DoT yes, hard CC no ----------------
	var boss = load("res://boss.tscn").instantiate()
	host.add_child(boss)
	await get_tree().process_frame
	boss.is_dead = false
	boss.max_health = 5000
	boss.health = 5000
	check("a boss now ACCEPTS statuses at all", boss.has_method("apply_status"))
	boss.apply_status("burn", 3.0, 10.0)
	var hp0: int = boss.health
	for i in range(90):                      # ~1.5s of physics
		await get_tree().physics_frame
	check("burn genuinely ticks a boss's health down (Warden/Ignite work on bosses)",
		boss.health < hp0, "hp %d -> %d" % [hp0, boss.health])
	# DoT must not trigger the reactive phase -- that would leave it intangible
	check("DoT does not trip the reactive phase", not boss.is_phased())
	# slow lands, but capped -- a boss never crawls below the floor
	boss.apply_status("slow", 3.0, 0.9)      # a 90% slow request
	check("a boss slow is capped at the floor (never below %.2fx)" % boss.BOSS_SLOW_FLOOR,
		boss.boss_status_slow_mult() >= boss.BOSS_SLOW_FLOOR,
		"%.2f" % boss.boss_status_slow_mult())
	check("...but the slow does land", boss.boss_status_slow_mult() < 1.0)
	# freeze can never stop a boss -- it converts to that same capped slow
	boss.status_slow_until = 0.0
	boss.apply_status("freeze", 5.0, 1.0)
	check("freeze on a boss is a brief slow, not a stop",
		boss.boss_status_slow_mult() >= boss.BOSS_SLOW_FLOOR and boss.boss_status_slow_mult() < 1.0)
	check("its movement choke point respects the slow",
		boss.effective_speed() < boss.base_move_speed * boss.speed_multiplier)
	boss.queue_free()

	# ---------------- SPECIAL MOB: full DoT + slow, freeze = hard slow ----------------
	var mob = load("res://special_mob.gd").new()
	mob.kind = "charger"
	host.add_child(mob)
	await get_tree().process_frame
	mob.max_health = 500
	mob.health = 500
	check("special mobs accept statuses", mob.has_method("apply_status"))
	mob.apply_status("poison", 3.0, 12.0)
	var mhp0: int = mob.health
	for i in range(90):
		await get_tree().physics_frame
	check("poison ticks an elite down", mob.health < mhp0, "hp %d -> %d" % [mhp0, mob.health])
	mob.apply_status("freeze", 2.0, 1.0)
	check("freeze on a special mob is a hard slow (0.25x), never a full stop",
		abs(mob.status_slow_mult() - 0.25) < 0.001, "%.2f" % mob.status_slow_mult())
	mob.queue_free()

	# ---------------- SIEGE ENEMY: the DoT kit works during sieges ----------------
	var raider = load("res://siege_enemy.gd").new()
	host.add_child(raider)
	await get_tree().process_frame
	raider.max_health = 500
	raider.health = 500
	check("siege enemies accept statuses", raider.has_method("apply_status"))
	raider.apply_status("burn", 3.0, 15.0)
	var rhp0: int = raider.health
	for i in range(90):
		await get_tree().physics_frame
	check("burn ticks a raider down mid-siege", raider.health < rhp0, "hp %d -> %d" % [rhp0, raider.health])
	raider.apply_status("slow", 2.0, 0.5)
	check("a slowed raider marches at half pace", abs(raider.status_slow_mult() - 0.5) < 0.01,
		"%.2f" % raider.status_slow_mult())
	raider.queue_free()

	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
