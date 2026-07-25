extends Node
# VILLAGER CONTAINMENT (dev 2026-07-24): ordinary villagers stay INSIDE the
# village -- between the two ramparts if both stand, else the centre of town.
# WARRIORS are exempt: they range wall-to-wall so they can answer an invasion and
# hold the wall.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish(); break
	get_tree().paused = false

func _wall_stub(host: Node, x: float, flank: String) -> Node2D:
	var s := Node2D.new()
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar flank := \"west\"\n"
	scr.reload()
	s.set_script(scr)
	s.flank = flank
	s.add_to_group("village_wall")
	host.add_child(s)
	s.global_position = Vector2(x, 0.0)
	return s

func _villager(host: Node, id: String, warrior: bool) -> Node:
	GameState.rescued_villagers.append({
		"id": id, "name": id, "sex": "Male", "is_kid": false,
		"stat_name": ("Warrior" if warrior else "Farm"), "stat_value": 4,
		"role_key": ("Barracks" if warrior else ""), "role_title": ("Warrior" if warrior else "")})
	var n = load("res://npc.gd").new()
	n.villager_id = id
	host.add_child(n)
	return n

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running(); await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(30):
		keep_running(); await get_tree().process_frame

	var host := get_tree().current_scene
	var base: Vector2 = p.global_position
	# isolate: clear any real ramparts so only our stubs define the band
	for w in get_tree().get_nodes_in_group("village_wall"):
		w.queue_free()
	await get_tree().process_frame

	var folk := _villager(host, "wtest_folk", false)
	var soldier := _villager(host, "wtest_war", true)
	for i in range(10):
		await get_tree().process_frame

	var wx := base.x + 1000.0
	var ex := base.x + 5000.0
	var ww := _wall_stub(host, wx, "west")
	var ew := _wall_stub(host, ex, "east")

	# ---- the between-walls band is inset off each rampart ----
	var ws: Vector2 = folk._wall_span(140.0)
	check("the between-walls band sits inset off both ramparts",
		is_equal_approx(ws.x, wx + 140.0) and is_equal_approx(ws.y, ex - 140.0), str(ws))

	# ---- an ordinary villager is penned BETWEEN the two walls ----
	folk.refresh_wander_bounds()
	check("an ordinary villager stays between the two walls",
		folk.wander_min_x >= wx and folk.wander_max_x <= ex,
		"%.0f..%.0f inside %.0f..%.0f" % [folk.wander_min_x, folk.wander_max_x, wx, ex])

	# ---- a WARRIOR ranges wall-to-wall (reaches the ramparts to fight) ----
	soldier.refresh_wander_bounds()
	check("a warrior ranges the full wall-to-wall defensive band",
		is_equal_approx(soldier.wander_min_x, wx) and is_equal_approx(soldier.wander_max_x, ex),
		"%.0f..%.0f" % [soldier.wander_min_x, soldier.wander_max_x])
	check("...wider than an ordinary villager's band",
		soldier.wander_min_x < folk.wander_min_x and soldier.wander_max_x > folk.wander_max_x)

	# ---- fewer than two walls -> ordinary villagers fall back to the town centre ----
	ew.queue_free()
	await get_tree().process_frame
	var span: Vector2 = folk._village_span()
	var cluster: Vector2 = folk._town_cluster()
	check("with only one wall standing, villagers fall back to the town centre",
		is_equal_approx(span.x, cluster.x) and is_equal_approx(span.y, cluster.y),
		"span %s vs cluster %s" % [str(span), str(cluster)])

	folk.queue_free(); soldier.queue_free()
	if is_instance_valid(ww): ww.queue_free()
	printerr("test_wanderbounds : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
