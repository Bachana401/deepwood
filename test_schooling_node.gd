extends Node
# THE SCHOOLING POLICY (dev design 2026-07-30) -- the hinge of the population loop.
# A child is sent to the School or the Barracks; one comes out with a trade and
# takes a job, the other comes out a warrior and holds the wall; they are housed,
# they pair, and their children go round again.
#
# Pins: the dial really splits ten children the way it says, EITHER hall can take
# them (this used to feed the School alone, so half the loop had no automatic path
# at all), anyone may train regardless of sex, a full hall redirects rather than
# turning a child away, and a seated Chancellor takes the decision over entirely.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func _ready() -> void:
	var p: Node = null
	for i in range(600):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false

	var s_roster: Array = GameState.rescued_villagers.duplicate(true)
	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_enroll: Dictionary = GameState.school_enrollments.duplicate(true)
	var s_share: int = GameState.school_share
	var s_intake: int = GameState._kid_intake

	for b in ["School", "Barracks", "Government"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH

	# ---- anyone may train ----
	var male_only := false
	for rd in BuildingRoles.get_roles("Barracks"):
		if str(rd.get("title", "")) == "Recruit" and str(rd.get("requires_sex", "")) != "":
			male_only = true
	check("ANY child may take a spear — the drill yard is no longer Male-only", not male_only)

	# ---- the dial splits ten children the way it says ----
	var run := func(share: int, kids: int) -> Dictionary:
		GameState.school_share = share
		GameState._kid_intake = 0
		GameState.school_enrollments = {}
		GameState.rescued_villagers = []
		for i in range(kids):
			GameState.rescued_villagers.append({"id": "k_%d" % i, "name": "Kid%d" % i,
				"sex": "Female" if i % 2 == 0 else "Male", "is_kid": true,
				"stat_name": "", "stat_value": 0, "role_key": "", "role_title": ""})
		GameState.auto_enroll_children(99)
		var out := {"School": 0, "Barracks": 0}
		for e in GameState.school_enrollments.values():
			var rk := str(e.get("role_key", "School"))
			out[rk] = int(out.get(rk, 0)) + 1
		return out
	var four: Dictionary = run.call(4, 10)
	check("a dial of 4 sends four of ten to the School and six to the yard",
		int(four["School"]) == 4 and int(four["Barracks"]) == 6, str(four))
	var two: Dictionary = run.call(2, 10)
	check("...and a dial of 2 sends two and eight", int(two["School"]) == 2
		and int(two["Barracks"]) == 8, str(two))
	var all_school: Dictionary = run.call(10, 6)
	check("a dial of 10 trains nobody (the old behaviour, unchanged for old saves)",
		int(all_school["Barracks"]) == 0 and int(all_school["School"]) == 6, str(all_school))
	var all_yard: Dictionary = run.call(0, 6)
	check("a dial of 0 schools nobody", int(all_yard["School"]) == 0
		and int(all_yard["Barracks"]) == 6, str(all_yard))
	# girls really do end up in the yard, not just boys
	var girls_trained := 0
	for eid in GameState.school_enrollments.keys():
		if str(GameState.school_enrollments[eid].get("role_key", "")) != "Barracks":
			continue
		for v in GameState.rescued_villagers:
			if str(v.get("id", "")) == str(eid) and str(v.get("sex", "")) == "Female":
				girls_trained += 1
	check("...and daughters are among them", girls_trained > 0, "%d girls in the yard" % girls_trained)

	# ---- a hall that isn't standing never strands a child ----
	GameState.building_stage["Barracks"] = 0
	var no_yard: Dictionary = run.call(0, 5)      # dial says train everyone, but there is no yard
	check("with no drill yard the children are schooled anyway (never stranded)",
		int(no_yard["School"]) == 5 and int(no_yard["Barracks"]) == 0, str(no_yard))
	GameState.building_stage["Barracks"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_stage["School"] = 0
	var no_school: Dictionary = run.call(10, 5)   # dial says school everyone, but there is no school
	check("...and with no School they train instead", int(no_school["Barracks"]) == 5, str(no_school))
	GameState.building_stage["School"] = GameState.TOTAL_BUILD_STAGES

	# ---- the Chancellor takes the decision over ----
	check("with no Chancellor the dial is yours", not GameState.schooling_is_delegated())
	GameState.rescued_villagers = [{"id": "ch", "name": "Alaric", "sex": "Male", "is_kid": false,
		"stat_name": "Chancellor", "stat_value": 9, "role_key": "Government", "role_title": "Chancellor"}]
	check("a seated Chancellor takes it over", GameState.schooling_is_delegated())
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("...and decides from the WALL against what is coming, not from the dial",
		gs.contains("func chancellor_wants_warriors") and gs.contains("village_defense_power()"))
	check("the policy survives the save", gs.contains('"school_share": school_share'))
	check("the Government panel is where you set it",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("add_schooling_section"))

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.building_stage = s_stage
	GameState.school_enrollments = s_enroll
	GameState.school_share = s_share
	GameState._kid_intake = s_intake

	printerr("test_schooling : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
