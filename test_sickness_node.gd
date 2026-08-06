extends Node
# THE SICKNESS (dev design 2026-08-06) -- the town's own problem, and the answer
# to "what is there to do once the village runs itself". Everything else the
# village produces, it produces FOR you; this it produces AT you.
#
# Pins the contract: a hamlet never sickens; it spreads HOUSE TO HOUSE by the
# same homes-and-workplaces the auras read, so cottage placement decides how fast;
# the ward's shadow shelters, slows and cures; the Ten and the pledged are never
# taken; and long neglect really can kill -- but slowly enough that coming home
# always saves them.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func soul(id: String) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "sex": "Male", "is_kid": false,
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
	var s_sick: Dictionary = GameState.sick.duplicate(true)
	var s_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var s_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var s_ids: Array = GameState.extra_cottage_ids.duplicate()
	var s_pos: Array = GameState.extra_cottage_positions.duplicate()
	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_x: Dictionary = GameState.building_x.duplicate(true)

	GameState.sick = {}
	GameState.villager_hp = {}
	GameState.building_stage["Hospital"] = 0        # no ward for the early checks

	# ---- a hamlet never sickens ----
	GameState.rescued_villagers = []
	for i in range(4):
		GameState.rescued_villagers.append(soul("h%d" % i))
	GameState._sick_accum = 0.0
	for _d in range(40):
		GameState.tick_sickness(24.0)
	check("a hamlet never sickens — there is nobody to catch it from",
		GameState.sick_count() == 0, "%d ill" % GameState.sick_count())

	# ---- a town does, and it spreads to the NEIGHBOURS ----
	# two clusters: four homes packed together, four far down the road
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	for i2 in range(16):
		var id := "s%d" % i2
		GameState.rescued_villagers.append(soul(id))
		GameState.extra_cottage_ids.append("c%d" % i2)
		# first eight shoulder to shoulder; last eight scattered a long way off
		GameState.extra_cottage_positions.append(6000.0 + float(i2) * 120.0 if i2 < 8
			else 30000.0 + float(i2) * 4000.0)
		GameState.cottage_homes["c%d" % i2] = {"a": id, "b": ""}
	check("everyone has a home to catch it in",
		GameState.villager_home_id("s0") != "" and GameState.villager_home_id("s15") != "")

	# seed it in the packed cluster and let a few nights pass
	GameState.sick = {"s0": GameState.game_hours}
	GameState._sick_accum = 0.0
	for _d2 in range(4):
		GameState._sickness_day(false)
	var packed := 0
	var far := 0
	for vid in GameState.sick.keys():
		var n := int(str(vid).substr(1))
		if n < 8: packed += 1
		else: far += 1
	check("it spreads through homes packed together", packed > 1, "%d in the row" % packed)
	check("...and does NOT reach homes far down the road (placement decides)",
		far == 0, "%d caught it across town" % far)

	# ---- the ward's shadow shelters, and cures ----
	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Hospital"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_x["Hospital"] = 6400.0        # right on top of the packed row
	var v0: Dictionary = GameState.find_villager_by_id("s0")
	check("a home in the ward's shadow is recognised", GameState.in_aura("Hospital", v0))
	# under the ward, the same illness costs far less strength
	GameState.sick = {"s0": GameState.game_hours}
	GameState.villager_hp = {"s0": 100.0}
	GameState.tick_sickness(10.0)
	var hp_warded: float = GameState.get_villager_hp("s0")
	GameState.building_x["Hospital"] = 90000.0       # move the ward far away
	GameState.sick = {"s0": GameState.game_hours}
	GameState.villager_hp = {"s0": 100.0}
	GameState.tick_sickness(10.0)
	var hp_bare: float = GameState.get_villager_hp("s0")
	check("the ward's shadow costs the sick far less strength",
		hp_warded > hp_bare, "warded %.1f vs bare %.1f" % [hp_warded, hp_bare])
	check("...but it still costs them something", hp_warded < 100.0, "%.1f" % hp_warded)

	# ---- long neglect kills, and it is a real death ----
	GameState.building_stage["Hospital"] = 0
	GameState.rescued_villagers = [soul("doomed")]
	for i3 in range(14):
		GameState.rescued_villagers.append(soul("bystander%d" % i3))
	GameState.sick = {"doomed": GameState.game_hours}
	GameState.villager_hp = {"doomed": 3.0}
	var before: int = GameState.rescued_villagers.size()
	GameState.tick_sickness(6.0)
	check("neglected long enough, the sickness takes them",
		GameState.rescued_villagers.size() < before,
		"%d -> %d" % [before, GameState.rescued_villagers.size()])
	check("...and they are no longer counted as ill", not GameState.villager_is_sick("doomed"))

	# ---- but never a legend ----
	GameState.rescued_villagers = [{"id": "legend", "name": "Maera", "sex": "Female",
		"is_kid": false, "stat_name": "", "stat_value": 9, "role_key": "", "role_title": "",
		"unbreakable": true}]
	GameState.sick = {"legend": GameState.game_hours}
	GameState.villager_hp = {"legend": 1.0}
	GameState.tick_sickness(24.0)
	check("the Ten sicken to the brink and no further",
		GameState.rescued_villagers.size() == 1 and GameState.get_villager_hp("legend") > 0.0,
		"hp=%.1f" % GameState.get_villager_hp("legend"))
	var lv: Dictionary = GameState.find_villager_by_id("legend")
	check("...and a legend can never be picked as patient zero", not GameState._can_sicken(lv))

	# ---- it is written down, and it is LOUD ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("who is ill survives the save", gs.contains('"sick": sick'))
	check("an outbreak pierces the away-fog (you must be able to come home)",
		gs.split("func _begin_outbreak(")[1].split("\nfunc ")[0].contains("notify_urgent"))
	check("the glance panel shows the emergency",
		FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text().contains("SICK"))
	check("sickness is NOT corruption — it has its own ledger",
		gs.contains("func tick_sickness") and gs.contains("func tick_rot"))

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.sick = s_sick
	GameState.villager_hp = s_hp
	GameState.cottage_homes = s_homes
	GameState.extra_cottage_ids = s_ids
	GameState.extra_cottage_positions = s_pos
	GameState.extra_cottages = s_ids.size()
	GameState.building_stage = s_stage
	GameState.building_x = s_x

	printerr("test_sickness : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
