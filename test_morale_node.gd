extends Node

# PERSONAL MORALE (GAME_BIBLE 5.5b) -- the substrate everything later reads.
# Two layers, same numbers at two scales: each villager carries their own
# 0-10; the meter is the plain average. These checks pin the layer's contract:
# seeding, the perfect-10 tuning, the average, instant grief, drift, and the
# finale gate's "no one below 10" strictness.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

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

	# ---- paint a controlled world (restored at the end) ----
	var saved_roster: Array = GameState.rescued_villagers
	var saved_houses: Dictionary = GameState.mating_houses
	var saved_homes: Dictionary = GameState.cottage_homes
	var saved_hours: float = GameState.game_hours
	var saved_health: Dictionary = GameState.building_health.duplicate(true)
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_shock: float = GameState.morale_death_shock
	var saved_admin: int = GameState.morale_admin_offset
	var saved_food: float = GameState.village_food
	var saved_ilo = GameState.the_ten.get("ten_ilo", {"freed": false})

	GameState.morale_death_shock = 0.0
	GameState.morale_admin_offset = 0
	GameState.the_ten["ten_ilo"] = {"freed": false}
	GameState.village_food = 500.0                      # larder full
	for b in GameState.STARTING_BUILDINGS:              # whole town operational
		GameState.building_health[b] = 100
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
	# a perfect adult: employed + paired; a perfect child; pop at target
	var roster := []
	for i in range(int(GameState.MORALE_POP_TARGET)):
		roster.append({"id": "m_ad_%d" % i, "name": "Adult %d" % i, "sex": "Male",
			"is_kid": false, "stat_name": "Farm", "stat_value": 3,
			"role_key": "Farm", "role_title": "Farmer"})
	roster.append({"id": "m_kid", "name": "Kid", "sex": "Female", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": ""})
	GameState.rescued_villagers = roster
	GameState.mating_houses = {}
	GameState.cottage_homes = {}
	# pair AND HOUSE every adult except the last two -- the lonely, homeless
	# pair the checks below first measure, then unite (5.8: perfection needs
	# both the partner and the cottage)
	for i in range(0, int(GameState.MORALE_POP_TARGET) - 2, 2):
		roster[i]["partner_id"] = "m_ad_%d" % (i + 1)
		roster[i + 1]["partner_id"] = "m_ad_%d" % i
		roster[i]["paired"] = true
		roster[i + 1]["paired"] = true
		GameState.cottage_homes["h%d" % i] = {"a": "m_ad_%d" % i, "b": "m_ad_%d" % (i + 1)}

	# ---- the tuning: a perfect adult is EXACTLY 10, no boons needed ----
	var perfect: Dictionary = roster[0]
	check("a perfect adult's target is exactly 10.0",
		absf(GameState.personal_morale_target(perfect) - 10.0) < 0.01,
		str(GameState.personal_morale_target(perfect)))
	check("a cared-for child also reaches 10",
		absf(GameState.personal_morale_target(roster[-1]) - 10.0) < 0.01,
		str(GameState.personal_morale_target(roster[-1])))
	var last_adult: Dictionary = roster[int(GameState.MORALE_POP_TARGET) - 1]
	check("purpose and love are load-bearing: the one unpaired adult cannot reach 10",
		GameState.personal_morale_target(last_adult) < 10.0)

	# ---- seeding + the plain average ----
	check("first touch seeds a villager AT their target",
		absf(GameState.get_personal_morale(perfect) - GameState.personal_morale_target(perfect)) < 0.01)
	var meter: int = GameState.village_morale()
	check("the meter is the plain average of everyone (two lonely souls keep it under 100)",
		meter < 100 and meter >= 95, str(meter))
	var second_last: Dictionary = roster[int(GameState.MORALE_POP_TARGET) - 2]
	check("loneliness is a standing -2, not a missing bonus",
		absf(GameState.personal_morale_target(last_adult) - 7.2) < 0.01,
		str(GameState.personal_morale_target(last_adult)))
	last_adult["partner_id"] = second_last["id"]
	second_last["partner_id"] = last_adult["id"]
	last_adult["paired"] = true
	second_last["paired"] = true
	GameState.cottage_homes["hz"] = {"a": second_last["id"], "b": last_adult["id"]}
	last_adult.erase("morale")
	second_last.erase("morale")
	check("unite and house the lonely pair and perfection is reachable",
		GameState.village_morale() == 100, str(GameState.village_morale()))

	# ---- widowhood (5.8): death parts, mourning gates, the cottage frees ----
	GameState.remove_villager_by_id(str(second_last["id"]))
	check("death breaks the pair and frees their cottage",
		str(last_adult.get("partner_id", "x")) == "" and not GameState.cottage_homes.has("hz"))
	check("the widow carries the -3 on the spot",
		GameState.get_personal_morale(last_adult) < 7.5,
		str(GameState.get_personal_morale(last_adult)))
	var mates: Dictionary = GameState.find_available_parents()
	check("a mourner cannot be re-paired inside the 48 hours",
		mates.get("male_id", "") != str(last_adult["id"]))
	GameState.game_hours += GameState.WIDOW_MOURN_HOURS + 1.0
	mates = GameState.find_available_parents()
	check("after the mourning, they may love again",
		mates.get("male_id", "") == str(last_adult["id"]) or mates.get("female_id", "") == str(last_adult["id"]))
	GameState.morale_death_shock = 0.0

	# ---- the raised-cottage row survives the save ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("homes and raised cottages survive the save",
		gs.contains('"cottage_homes": cottage_homes') and gs.contains('"extra_cottages": extra_cottages'))
	check("the plot at the row's end exists and charges materials",
		ResourceLoader.exists("res://cottage_plot.gd")
		and FileAccess.open("res://cottage_plot.gd", FileAccess.READ).get_as_text().contains("remove_item"))

	# ---- instant grief + drift home ----
	GameState.register_villager_deaths(5)
	check("five deaths land on every spirit at once (-1.0)",
		GameState.get_personal_morale(perfect) <= 9.01,
		str(GameState.get_personal_morale(perfect)))
	check("grief also weighs the target down while it lasts",
		GameState.personal_morale_target(perfect) < 10.0)
	GameState.morale_death_shock = 0.0
	var before: float = GameState.get_personal_morale(perfect)
	GameState.tick_personal_morale(1.0)
	var after: float = GameState.get_personal_morale(perfect)
	check("spirits drift home at the drift rate, no faster",
		after > before and after - before <= GameState.MORALE_DRIFT_PER_HOUR + 0.01,
		"%f -> %f" % [before, after])

	# ---- the meter still speaks the old contract ----
	GameState.morale_admin_offset = -20
	check("the admin nudge still lands on the meter",
		GameState.village_morale() <= 80)
	GameState.morale_admin_offset = 0
	GameState.rescued_villagers = []
	check("an empty village reads 0", GameState.village_morale() == 0)

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.mating_houses = saved_houses
	GameState.cottage_homes = saved_homes
	GameState.game_hours = saved_hours
	GameState.building_health = saved_health
	GameState.building_stage = saved_stage
	GameState.morale_death_shock = saved_shock
	GameState.morale_admin_offset = saved_admin
	GameState.village_food = saved_food
	GameState.the_ten["ten_ilo"] = saved_ilo
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
