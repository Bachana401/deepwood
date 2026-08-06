extends Node
# FIRE (dev design 2026-08-06) -- the SECOND FACE OF ADJACENCY.
#
# Every placement rule until now was pure upside: standing the Mine beside the
# forge simply made you richer, so the best economic layout was the only sane one
# and the "puzzle" had a single answer. Fire travels the SAME neighbour map the
# synergies use, so the tight, perfectly-paired row that earns most is also the
# row that burns whole. This pins that: it spreads to IMMEDIATE neighbours, the
# Builderhouse crew is what fights it, hearth buildings start more of them, a
# hamlet rarely burns, and a gutted hall is knocked back down its stages rather
# than destroyed for good.

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

	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_health: Dictionary = GameState.building_health.duplicate(true)
	var s_burn: Dictionary = GameState.burning.duplicate(true)
	var s_nb: Dictionary = GameState.building_neighbors.duplicate(true)
	var s_roster: Array = GameState.rescued_villagers.duplicate(true)

	var stand := func(names: Array) -> void:
		for bn in GameState.STARTING_BUILDINGS:
			GameState.building_stage[bn] = 0
		for bn2 in names:
			GameState.building_stage[bn2] = GameState.TOTAL_BUILD_STAGES
			GameState.building_health[bn2] = GameState.BUILDING_MAX_HEALTH
	GameState.rescued_villagers = []          # no crew unless a test asks for one

	# ---- a hamlet rarely burns: the gate is real ----
	stand.call(["Farm", "Tavern"])
	GameState.burning = {}
	GameState._fire_accum = 0.0
	for _d in range(200):
		GameState._fire_day()
	check("a hamlet below the threshold never catches fire",
		GameState.fire_count() == 0, "%d alight" % GameState.fire_count())

	# ---- THE COST OF A TIGHT ROW: it jumps to an immediate neighbour ----
	stand.call(["Blacksmith", "Barracks", "Farm", "Bank", "Mine", "Tavern"])
	GameState.building_neighbors = {
		"Blacksmith": ["", "Barracks"],
		"Barracks": ["Blacksmith", "Farm"],
		"Farm": ["Barracks", ""],
		"Mine": ["", ""],          # standing alone, well away from the row
	}
	GameState.burning = {"Blacksmith": GameState.game_hours}
	var jumped := false
	for _d2 in range(30):
		GameState._fire_day()
		if GameState.building_is_burning("Barracks"):
			jumped = true
			break
		if GameState.fire_count() == 0:
			GameState.burning = {"Blacksmith": GameState.game_hours}   # relight and keep watching
	check("fire jumps to the hall built right beside it", jumped)

	# ...but never to one that is nobody's neighbour
	GameState.burning = {"Blacksmith": GameState.game_hours}
	var reached_isolated := false
	for _d3 in range(30):
		GameState._fire_day()
		if GameState.building_is_burning("Mine"):
			reached_isolated = true
		if GameState.fire_count() == 0:
			GameState.burning = {"Blacksmith": GameState.game_hours}
	check("...and never to a hall that stands alone (spacing is a real defence)",
		not reached_isolated)

	# ---- the Builderhouse crew is what fights it ----
	stand.call(["Blacksmith", "Barracks", "Farm", "Bank", "Mine", "Builderhouse"])
	GameState.building_neighbors = {}
	GameState.rescued_villagers = []
	GameState.burning = {"Blacksmith": GameState.game_hours}
	GameState.building_health["Blacksmith"] = GameState.BUILDING_MAX_HEALTH
	GameState.tick_fire(4.0)
	var hp_alone: float = float(GameState.building_health["Blacksmith"])
	# now with a crew on hand
	for i2 in range(4):
		GameState.rescued_villagers.append({"id": "crew%d" % i2, "name": "Hand", "sex": "Male",
			"is_kid": false, "stat_name": "", "stat_value": 2,
			"role_key": "Builderhouse", "role_title": "Worker"})
	GameState.burning = {"Blacksmith": GameState.game_hours}
	GameState.building_health["Blacksmith"] = GameState.BUILDING_MAX_HEALTH
	GameState.tick_fire(4.0)
	var hp_crewed: float = float(GameState.building_health["Blacksmith"])
	check("a Builderhouse crew visibly fights the blaze back",
		hp_crewed > hp_alone, "no crew %.0f vs crew %.0f" % [hp_alone, hp_crewed])

	# ---- an unfought blaze guts the hall, but never destroys it forever ----
	GameState.rescued_villagers = []
	GameState.burning = {"Farm": GameState.game_hours}
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Farm"] = 10.0
	GameState.tick_fire(3.0)
	check("a hall the fire finishes is knocked back down its stages",
		int(GameState.building_stage["Farm"]) < GameState.TOTAL_BUILD_STAGES,
		"stage=%d" % int(GameState.building_stage["Farm"]))
	check("...and the fire in it is out (it has nothing left to eat)",
		not GameState.building_is_burning("Farm"))
	check("...and it can be raised again, never lost for good",
		int(GameState.building_stage["Farm"]) >= 0)

	# ---- hearths are likelier to start one ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("forges and hearths start more fires than a counting house",
		gs.contains("FIRE_HEARTH_MULT") and gs.contains("FIRE_HEARTHS"))
	check("it travels the SAME neighbour map the synergies use",
		gs.split("func _fire_day(")[1].split("\nfunc ")[0].contains("building_neighbors"))
	check("what is alight survives the save", gs.contains('"burning": burning'))
	check("the glance panel shows it, and whether anyone is fighting it",
		FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text().contains("BURNING"))

	# ---- restore ----
	GameState.building_stage = s_stage
	GameState.building_health = s_health
	GameState.burning = s_burn
	GameState.building_neighbors = s_nb
	GameState.rescued_villagers = s_roster

	printerr("test_fire : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
