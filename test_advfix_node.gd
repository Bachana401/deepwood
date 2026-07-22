extends Node

# The three starter heroes were "sticking to each other, sometimes running away"
# (dev report 2026-07-22): all default to the "city" post, aimed at the SAME
# centre point in lockstep (the knot), and chased east-road wild mobs 760px off
# down the road (the run-away). Locks the spread/desync + the aggro leash.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func mk_enemy(host: Node, grp: String, x: float) -> Node2D:
	var e := Node2D.new()
	e.add_to_group(grp)
	host.add_child(e)
	e.global_position = Vector2(x, 0)
	return e

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	var host := get_tree().current_scene
	var script = load("res://adventurer.gd")
	var ids := ["adv_roland", "adv_wren", "adv_castor"]
	var advs: Array = []
	for id in ids:
		var a = script.new()
		a.adventurer_id = id
		host.add_child(a)                       # _ready runs the spread/desync init
		a.global_position = Vector2(9000.0, 0)  # far from the real village heroes
		a.home_x = 9000.0
		advs.append(a)
	await get_tree().process_frame

	# ---- SPREAD: the three no longer aim at one identical point ----
	var dests: Array = []
	for a in advs:
		dests.append(a.home_x + a._post_offset + a.patrol_off)
	check("the three heroes don't all target the SAME point",
		not (is_equal_approx(dests[0], dests[1]) and is_equal_approx(dests[1], dests[2])),
		str(dests))
	check("their patrol phases are desynced (not lockstep)",
		not (is_equal_approx(advs[0].patrol_off, advs[1].patrol_off) and is_equal_approx(advs[1].patrol_off, advs[2].patrol_off)))

	# ---- LEASH: a hero at post x=9000 ----
	var hero = advs[0]
	# a siege raider inside the post's watch is a target
	var siege = mk_enemy(host, "siege_enemy", 9000.0 + 300.0)
	check("a siege raider near the post IS engaged", hero._nearest_raider() == siege)
	# ...but a siege raider far beyond the watch is left to the nearer post
	siege.global_position = Vector2(9000.0 + 900.0, 0)
	check("a siege raider beyond the watch is NOT chased", hero._nearest_raider() == null)
	# a wild road mob far off is IGNORED (no more sprinting down the road)
	var wild = mk_enemy(host, "course_enemy", 9000.0 + 400.0)
	check("a distant wild road mob is IGNORED", hero._nearest_raider() == null)
	# ...but one right on top of them, they DO fight (self-defense)
	wild.global_position = Vector2(9000.0 + 100.0, 0)
	check("a wild mob right on them IS fought (self-defense)", hero._nearest_raider() == wild)

	var asrc := FileAccess.open("res://adventurer.gd", FileAccess.READ).get_as_text()
	check("the leash is real (DEFEND_RADIUS + SELF_DEFENSE_RADIUS)",
		asrc.contains("DEFEND_RADIUS") and asrc.contains("SELF_DEFENSE_RADIUS"))

	for a in advs: a.queue_free()
	siege.queue_free(); wild.queue_free()
	printerr("test_advfix : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
