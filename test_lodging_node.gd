extends Node
# LODGING (dev design 2026-07-30) -- the shape the dev asked for: an adult coming
# out of the School is given a ROOF first, either an empty cottage or one that
# already holds a single of the opposite sex, and it is MOVING IN that makes the
# couple. Then they start a family and the population cycle turns on its own.
#
# Pins: a lone adult takes an empty cottage and waits; the next adult of the
# opposite sex moves in with them rather than taking a second empty one; sharing
# a roof makes the match; a same-sex housemate never does; a lone occupant can
# never conceive with nobody; and children/trainees are never housed as adults.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func adult(id: String, sex: String) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "sex": sex, "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}

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
	var s_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var s_mating: Dictionary = GameState.mating_houses.duplicate(true)
	var s_ids: Array = GameState.extra_cottage_ids.duplicate()
	var s_pos: Array = GameState.extra_cottage_positions.duplicate()
	var s_stage: Dictionary = GameState.building_stage.duplicate(true)

	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Bar"] = GameState.BUILDING_MAX_HEALTH
	GameState.cottage_homes = {}
	GameState.mating_houses = {}
	GameState.extra_cottage_ids = ["c1", "c2"]
	GameState.extra_cottage_positions = [6000.0, 6400.0]
	GameState.extra_cottages = 2

	# ---- one adult, one roof ----
	GameState.rescued_villagers = [adult("ann", "Female")]
	GameState.house_unpaired_adults()
	check("an adult with nowhere to live takes an empty cottage",
		GameState.villager_home_id("ann") != "", str(GameState.cottage_homes))
	var hid: String = GameState.villager_home_id("ann")
	check("...and lives there ALONE, waiting for company",
		GameState.cottage_lone_occupant(hid) == "ann" and not GameState.cottage_is_pair(hid))
	check("a lone occupant is not a couple, so nothing is expected of them",
		GameState.cottage_occupant_ids(hid).size() == 1)

	# ---- a same-sex arrival does NOT move in with her ----
	GameState.rescued_villagers.append(adult("beth", "Female"))
	GameState.house_unpaired_adults()
	check("another woman takes her OWN cottage, not Ann's spare room",
		GameState.villager_home_id("beth") != "" and GameState.villager_home_id("beth") != hid,
		"beth=%s ann=%s" % [GameState.villager_home_id("beth"), hid])

	# ---- a man moves IN with one of them, and that makes the match ----
	GameState.rescued_villagers.append(adult("carl", "Male"))
	GameState.house_unpaired_adults()
	var carl_home: String = GameState.villager_home_id("carl")
	check("a man with nowhere to live moves in with a woman living alone",
		carl_home == hid or carl_home == GameState.villager_home_id("beth"),
		"carl=%s" % carl_home)
	check("...and that cottage now holds a pair", GameState.cottage_is_pair(carl_home))
	GameState.pair_housemates()
	check("sharing the roof IS the match — they are paired and expecting to be a family",
		GameState.mating_houses.has(carl_home) or GameState.is_villager_paired("carl"),
		str(GameState.mating_houses))

	# ---- a lone occupant can never conceive with nobody ----
	GameState.mating_houses = {}
	GameState.cottage_homes = {"c1": {"a": "ann", "b": ""}}
	GameState.rescued_villagers = [adult("ann", "Female")]
	GameState.village_food = 500.0
	GameState._family_cycle_accum = 0.0
	var preg_before: int = GameState.pregnancies.size()
	GameState.update_cottage_families(GameState.FAMILY_CYCLE_HOURS + 1.0)
	check("a cottage with ONE person in it never produces a child",
		GameState.pregnancies.size() == preg_before,
		"%d -> %d" % [preg_before, GameState.pregnancies.size()])

	# ---- children and trainees are not housed as adults ----
	GameState.cottage_homes = {}
	GameState.rescued_villagers = [
		{"id": "kid", "name": "Kid", "sex": "Male", "is_kid": true, "stat_name": "",
			"stat_value": 0, "role_key": "", "role_title": ""},
		adult("dana", "Female")]
	GameState.school_enrollments = {"dana": {"role_key": "School", "role_title": "Student"}}
	GameState.house_unpaired_adults()
	check("a child is never given a household of their own",
		GameState.villager_home_id("kid") == "")
	check("...nor is someone still in training", GameState.villager_home_id("dana") == "")
	GameState.school_enrollments = {}

	# ---- the Bar is what runs it ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the Publican's round houses them before matching them",
		gs.contains("house_unpaired_adults()") and gs.contains("pair_housemates()"))
	check("a lone occupant reads correctly at the door",
		FileAccess.open("res://house.gd", FileAccess.READ).get_as_text().contains("lives here alone"))

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.cottage_homes = s_homes
	GameState.mating_houses = s_mating
	GameState.extra_cottage_ids = s_ids
	GameState.extra_cottage_positions = s_pos
	GameState.extra_cottages = s_ids.size()
	GameState.building_stage = s_stage

	printerr("test_lodging : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
