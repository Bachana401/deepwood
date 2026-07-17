extends Node

# The petrify primitive (WEAPONS.md §6 batch 1): the shared "turn to stone"
# status that Gorgon's Gaze and future stone items use. A stoned regular enemy
# is rooted, can't act, and takes BONUS damage; it wears off. Apex/undying
# bosses RESIST (that's "works on some bosses, not others"); a normal boss is
# stunned by it.

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

	# ---------------- ENEMY petrify ----------------
	var ENEMY = load("res://enemy.tscn")
	var e = ENEMY.instantiate()
	host.add_child(e)
	await get_tree().physics_frame
	check("enemy starts un-petrified", not e.is_petrified())
	e.apply_status("petrify", 1.0, 0.0)
	check("petrify: the enemy is stoned", e.is_petrified())
	# bonus damage while stoned: 20 dmg -> 30 (x1.5)
	var hp0: int = e.health
	e.take_damage(20)
	check("petrify: a stoned enemy takes BONUS damage (x1.5)",
		hp0 - e.health >= 29, "%d -> %d (expected -30)" % [hp0, e.health])
	# it wears off
	for i in range(80):
		await get_tree().physics_frame
		if not e.is_petrified(): break
	check("petrify: wears off on its own", not e.is_petrified())
	e.queue_free()

	# ---------------- BOSS resist / land ----------------
	var BOSS = load("res://boss.tscn")
	var normal = BOSS.instantiate(); normal.boss_id = "gravewarden"   # not apex
	host.add_child(normal); await get_tree().process_frame
	var landed: bool = normal.apply_petrify(2.0)
	check("petrify: a normal boss IS stoned (stun applied)", landed and normal.stun_timer > 0.0)
	normal.queue_free()

	var apex = BOSS.instantiate(); apex.boss_id = "eclipse"           # apex / undying
	host.add_child(apex); await get_tree().process_frame
	var apex_landed: bool = apex.apply_petrify(2.0)
	check("petrify: an APEX/undying boss RESISTS it (works on some, not others)",
		not apex_landed and apex.stun_timer == 0.0)
	apex.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
