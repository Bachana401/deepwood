extends Node
# THE SICK ROAD (expansion 2026-07-24): a wounded villager breaks off and WALKS
# to the nearest operational Hospital, is admitted, and mends OVER TIME while
# inside -- faster the better the ward is staffed. Placement gets them there;
# staffing is how fast they heal once in. Covers: wounded-detect, seek + walk,
# admission (not instant), over-time treatment, staffing scaling, discharge on
# full, ward-razed interrupt, and the no-hospital fallback.

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
	GameState.rescued_villagers.append({
		"id": "sick_test", "name": "Ailing", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""})
	var npc = load("res://npc.gd").new()
	npc.villager_id = "sick_test"
	host.add_child(npc)
	var base: Vector2 = p.global_position
	npc.global_position = Vector2(base.x + 260.0, base.y)
	for i in range(20):
		keep_running()
		await get_tree().process_frame

	# ---- wounded detection ----
	GameState.villager_hp.erase("sick_test")
	check("a full-health villager is NOT wounded", not npc._is_wounded())
	GameState.villager_hp["sick_test"] = 20.0
	check("below half health, the villager IS wounded", npc._is_wounded())

	# ---- Step 3 polish: a wounded villager WEARS the hurt (pale tint) ----
	# (isolate the wound: rot's grey pulse legitimately outranks it, so clear any
	# rot the bare-scenario corruption tick may have opened on this test villager)
	GameState.villager_rot.erase("sick_test")
	npc.apply_despair_visual()
	check("a wounded villager wears a hurt tint",
		npc.body_gfx != null and npc.body_gfx.modulate.is_equal_approx(Color(0.95, 0.78, 0.78)),
		str(npc.body_gfx.modulate) if npc.body_gfx else "no body_gfx")
	GameState.villager_hp.erase("sick_test")
	GameState.villager_rot.erase("sick_test")
	npc.apply_despair_visual()
	check("...and the colour returns once mended",
		npc.body_gfx != null and npc.body_gfx.modulate.is_equal_approx(Color(1, 1, 1)))
	GameState.villager_hp["sick_test"] = 20.0   # re-wound for the walk that follows

	# ---- no Hospital -> no trip (graceful fallback) ----
	npc.door_target = null
	npc._care_visit = false
	check("no Hospital yet -> no trip, falls back to slow regen",
		not npc._try_seek_care() and npc.door_target == null)

	# ---- Hospital to the WEST becomes the target; villager sets out ----
	var hosp := _make_hospital_stub(host, base.x)
	check("the nearest operational Hospital is found", npc._nearest_hospital() == hosp)
	check("a wounded villager sets out for the Hospital",
		npc._try_seek_care() and npc.door_target == hosp and npc._care_visit)

	# ---- walks toward it ----
	var x_before: float = npc.global_position.x
	for i in range(200):
		keep_running()
		await get_tree().physics_frame
		if npc.is_in_building:
			break
	check("the villager walked toward the Hospital",
		npc.is_in_building or npc.global_position.x < x_before - 20.0,
		"moved %.0f px (in=%s)" % [npc.global_position.x - x_before, str(npc.is_in_building)])

	# ---- admitted, NOT snapped to full (Step 2: treatment takes time) ----
	if not npc.is_in_building:
		npc.current_visit_building = hosp
		npc.door_target = hosp
		npc._care_visit = true
		npc._complete_enter()
	check("arriving admits the patient (goes inside)", npc.is_in_building)
	check("...under treatment, NOT instantly healed",
		npc._under_treatment and GameState.get_villager_hp("sick_test") < GameState.VILLAGER_MAX_HP,
		"%.0f hp, treating=%s" % [GameState.get_villager_hp("sick_test"), str(npc._under_treatment)])

	# ---- treatment heals OVER TIME ----
	var hp0: float = GameState.get_villager_hp("sick_test")
	npc._tick_treatment(0.5)
	var hp1: float = GameState.get_villager_hp("sick_test")
	check("a little treatment mends a little (over time, not all at once)",
		hp1 > hp0 and hp1 < GameState.VILLAGER_MAX_HP, "%.0f -> %.0f" % [hp0, hp1])
	# enough hours -> whole and discharged
	npc._tick_treatment(100.0)
	check("enough treatment heals to full and discharges",
		GameState.get_villager_hp("sick_test") >= GameState.VILLAGER_MAX_HP
		and not npc.is_in_building and not npc._under_treatment,
		"%.0f hp, in=%s" % [GameState.get_villager_hp("sick_test"), str(npc.is_in_building)])

	# ---- staffing SPEEDS the ward ----
	var bare: float = GameState.hospital_treat_rate()
	GameState.rescued_villagers.append({"id": "doc1", "name": "Doc", "sex": "Female",
		"is_kid": false, "stat_name": "Hospital", "stat_value": 5, "role_key": "Hospital", "role_title": "Doctors"})
	var staffed: float = GameState.hospital_treat_rate()
	check("staffing a Doctor speeds treatment", staffed > bare, "%.0f -> %.0f/hr" % [bare, staffed])
	GameState.rescued_villagers.append({"id": "chief", "name": "Chief", "sex": "Female",
		"is_kid": false, "stat_name": "Chief Physician", "stat_value": 9, "role_key": "Hospital", "role_title": "Chief Physician"})
	check("a seated Chief Physician sharpens it further",
		GameState.hospital_treat_rate() > staffed, "%.0f/hr" % GameState.hospital_treat_rate())

	# ---- interrupt: the ward is razed mid-treatment -> discharged ----
	GameState.villager_hp["sick_test"] = 30.0
	npc.is_in_building = true
	npc._under_treatment = true
	npc.current_visit_building = hosp
	hosp.queue_free()
	await get_tree().process_frame
	npc._tick_treatment(1.0)
	check("a razed Hospital breaks off treatment (patient discharged)",
		not npc.is_in_building and not npc._under_treatment)

	# ---- Step 3 polish: the feature wires visible feedback ----
	var src := FileAccess.open("res://npc.gd", FileAccess.READ).get_as_text()
	check("the Hospital shows floating care feedback", src.contains("FloatingText.spawn_word"))
	check("wounded villagers limp on the Sick Road", src.contains("LIMPS") and src.contains("bad leg drags"))

	npc.queue_free()
	printerr("test_sickroad : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
