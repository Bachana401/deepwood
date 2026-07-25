extends Node
# THE SICK ROAD (expansion 2026-07-24): a wounded villager breaks off and WALKS
# to the nearest operational Hospital, and is treated on arrival. The cost is the
# walk, so a Hospital near where people get hurt means faster recovery. This
# locks the core loop: wounded-detect -> seek nearest hospital -> walk -> heal on
# arrival -> and a graceful no-hospital fallback.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

# A minimal stand-in Hospital: in the right group, reports operational, at a set x.
func _make_hospital_stub(host: Node, x: float) -> Node2D:
	var stub := Node2D.new()
	var s := GDScript.new()
	s.source_code = "extends Node2D\nfunc is_operational() -> bool:\n\treturn true\n"
	s.reload()
	stub.set_script(s)
	stub.add_to_group("building_role_Hospital")
	host.add_child(stub)
	stub.global_position = Vector2(x, 0.0)
	return stub

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		keep_running()
		await get_tree().process_frame

	var host := get_tree().current_scene
	# seed a villager + avatar (this harness boots main.tscn without a roster)
	GameState.rescued_villagers.append({
		"id": "sick_test", "name": "Ailing", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""})
	var npc = load("res://npc.gd").new()
	npc.villager_id = "sick_test"
	host.add_child(npc)
	var base: Vector2 = p.global_position
	npc.global_position = Vector2(base.x + 260.0, base.y)   # east of a soon-to-stand Hospital
	for i in range(20):
		keep_running()
		await get_tree().process_frame

	# ---- wounded detection ----
	GameState.villager_hp.erase("sick_test")
	check("a full-health villager is NOT wounded", not npc._is_wounded())
	GameState.villager_hp["sick_test"] = 20.0
	check("below half health, the villager IS wounded", npc._is_wounded())

	# ---- with no Hospital, no trip starts (graceful fallback) ----
	npc.door_target = null
	npc._care_visit = false
	check("no Hospital yet -> no trip, falls back to slow regen",
		not npc._try_seek_care() and npc.door_target == null)

	# ---- a Hospital stands to the WEST; it becomes the target ----
	var hosp := _make_hospital_stub(host, base.x)   # ~260px west of the villager
	check("the nearest operational Hospital is found", npc._nearest_hospital() == hosp)
	var started: bool = npc._try_seek_care()
	check("a wounded villager sets out for the Hospital",
		started and npc.door_target == hosp and npc._care_visit)

	# ---- the villager actually WALKS toward it ----
	var x_before: float = npc.global_position.x
	for i in range(200):
		keep_running()
		await get_tree().physics_frame
		if npc.is_in_building:
			break
	check("the villager walked toward the Hospital",
		npc.is_in_building or npc.global_position.x < x_before - 20.0,
		"moved %.0f px (in_building=%s)" % [npc.global_position.x - x_before, str(npc.is_in_building)])

	# ---- treated on arrival (deterministic: drive the arrival directly) ----
	if not npc.is_in_building:
		npc.current_visit_building = hosp
		npc.door_target = hosp
		npc._care_visit = true
		npc._complete_enter()
	check("arriving at the Hospital goes inside", npc.is_in_building)
	check("...and treats the wound (healed to full)",
		GameState.get_villager_hp("sick_test") >= GameState.VILLAGER_MAX_HP,
		"%.0f hp" % GameState.get_villager_hp("sick_test"))
	check("...and the care flag is cleared after arrival", not npc._care_visit)

	npc.queue_free()
	hosp.queue_free()
	printerr("test_sickroad : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
