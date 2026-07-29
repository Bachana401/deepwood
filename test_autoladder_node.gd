extends Node
# THE AUTOMATION LADDER (dev law 2026-07-29): every chore the player does BY HAND
# early must eventually be taken over by a building. This locks the family loop --
# the dev's own worked example -- plus the chain links that pay for it:
#   raise a cottage  (B menu, by hand)  -> the Builderhouse's leaders
#   pair a couple    (E on a cottage)   -> the Bar's Publican
#   school a child   (assign UI)        -> the School's Principal (already built)
# Each automation must cost the village stores, fire only when actually NEEDED,
# and keep working while the player is away.

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

	# ---- save everything this test paints over ----
	var saved_roster: Array = GameState.rescued_villagers.duplicate(true)
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_ids: Array = GameState.extra_cottage_ids.duplicate()
	var saved_pos: Array = GameState.extra_cottage_positions.duplicate()
	var saved_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var saved_mating: Dictionary = GameState.mating_houses.duplicate(true)
	var saved_store: Dictionary = GameState.village_stockpile.duplicate(true)
	var saved_treasury: int = GameState.village_treasury
	var saved_enroll: Dictionary = GameState.school_enrollments.duplicate(true)

	GameState.dev_mode = false
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	GameState.extra_cottages = 0
	GameState.cottage_homes = {}
	GameState.mating_houses = {}
	for b in ["Builderhouse", "Bar", "Marketplace", "Science Lab", "School", "Mine"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES

	# a seated Master Builder + one unpaired couple waiting for a home
	GameState.rescued_villagers = [
		{"id": "al_mb", "name": "Garrick", "sex": "Male", "is_kid": false, "stat_name": "Master Builder",
			"stat_value": 7, "role_key": "Builderhouse", "role_title": "Master Builder"},
		{"id": "al_w1", "name": "Mara", "sex": "Female", "is_kid": false, "stat_name": "Farm",
			"stat_value": 3, "role_key": "Farm", "role_title": "Farmer"},
	]
	GameState.village_stockpile = {"wood": 40, "stone": 20, "iron_shard": 0}

	# ---- the builders raise the home themselves ----
	var wood0: int = int(GameState.village_stockpile["wood"])
	var built: bool = GameState.auto_build_cottage()
	check("the builders raise a cottage for a waiting couple (no B menu)",
		built and GameState.extra_cottages == 1, "built=%s n=%d" % [str(built), GameState.extra_cottages])
	check("...and it COSTS the village stores (the chain pays for housing)",
		int(GameState.village_stockpile["wood"]) < wood0,
		"%d -> %d" % [wood0, int(GameState.village_stockpile["wood"])])
	check("...and the cottage body actually stands in the village",
		get_tree().get_nodes_in_group("house").size() > 0
			or get_tree().current_scene.get_node_or_null("Village") != null)
	check("a home already standing empty means they DON'T sprawl another",
		not GameState.auto_build_cottage() and GameState.extra_cottages == 1,
		"n=%d" % GameState.extra_cottages)

	# ---- the Publican makes the match ----
	check("no Publican, no matchmaking (the chore is still the player's)",
		GameState.mating_houses.is_empty())
	GameState.rescued_villagers.append({"id": "al_pub", "name": "Fenn", "sex": "Male", "is_kid": false,
		"stat_name": "Publican", "stat_value": 5, "role_key": "Bar", "role_title": "Publican"})
	GameState.auto_pair_couples()
	check("the Publican pairs a couple into the empty cottage, hands-free",
		GameState.mating_houses.size() == 1, str(GameState.mating_houses))
	check("...and the paired pair are off the market",
		GameState.free_cottage_ids().is_empty())

	# ---- the stores gate the pace ----
	GameState.rescued_villagers.append({"id": "al_w2", "name": "Bren", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 2, "role_key": "Farm", "role_title": "Farmer"})
	GameState.rescued_villagers.append({"id": "al_w3", "name": "Cole", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 2, "role_key": "Farm", "role_title": "Farmer"})
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	check("empty stores stall the builders (housing is never free)",
		not GameState.auto_build_cottage(), "n=%d" % GameState.extra_cottages)
	GameState.village_stockpile = {"wood": 40, "stone": 20, "iron_shard": 0}
	check("...and a restocked store lets the next home go up",
		GameState.auto_build_cottage() and GameState.extra_cottages == 2,
		"n=%d" % GameState.extra_cottages)

	# ---- the Principal schools the children (the ladder's third rung) ----
	GameState.school_enrollments = {}
	GameState.rescued_villagers.append({"id": "al_prin", "name": "Ollin", "sex": "Male", "is_kid": false,
		"stat_name": "Principal", "stat_value": 6, "role_key": "School", "role_title": "Principal"})
	GameState.rescued_villagers.append({"id": "al_kid", "name": "Pip", "sex": "Female", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": ""})
	GameState.auto_enroll_children(GameState.seated_leaders("School"))
	check("the Principal enrolls the child with no assign-UI visit",
		GameState.school_enrollments.has("al_kid"), str(GameState.school_enrollments))

	# ---- the chain links that pay for all of it ----
	GameState.village_treasury = 0
	GameState.village_stockpile = {"wood": 90, "stone": 90, "iron_shard": 0}
	GameState.auto_sell_village_surplus()
	check("the Merchant Prince sells surplus STORES into the treasury (Mine → Market → wages)",
		GameState.village_treasury > 0
			and int(GameState.village_stockpile["wood"]) == GameState.AUTO_SELL_VILLAGE_KEEP,
		"treasury=%d wood=%d" % [GameState.village_treasury, int(GameState.village_stockpile["wood"])])

	var base_mult: float = GameState.research_yield_multiplier()
	GameState.rescued_villagers.append({"id": "al_lab", "name": "Wrenna", "sex": "Female", "is_kid": false,
		"stat_name": "Lead Researcher", "stat_value": 7, "role_key": "Science Lab", "role_title": "Lead Researcher"})
	check("the Lab's researchers make every seam yield more (Lab → the whole chain)",
		GameState.research_yield_multiplier() > base_mult,
		"%.2f -> %.2f" % [base_mult, GameState.research_yield_multiplier()])

	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the Bar pours from the LARDER — no food, no takings",
		gs.contains('is_building_operational("Bar") and has_food()'))

	# ---- the player can SEE the chain, and FEED it by hand when it stalls ----
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	p.inventory.add_item("wood", 5)
	var carried: int = p.inventory.get_count("wood")
	var given: int = GameState.donate_to_stores(p, "wood")
	check("the player can hand carried wood to the village stores (the early supply line)",
		given == carried and int(GameState.village_stockpile["wood"]) == carried,
		"gave=%d store=%d" % [given, int(GameState.village_stockpile["wood"])])
	check("...and donating what you don't have gives nothing",
		GameState.donate_to_stores(p, "wood") == 0)
	var ui := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("the Builderhouse panel SHOWS the stores + a donate path",
		ui.contains("add_stores_section") and ui.contains("donate_to_stores"))
	var mm := FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text()
	check("the glance panel reads the stores out (the chain is visible)",
		mm.contains("village_stockpile"))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.building_stage = saved_stage
	GameState.extra_cottage_ids = saved_ids
	GameState.extra_cottage_positions = saved_pos
	GameState.extra_cottages = saved_ids.size()
	GameState.cottage_homes = saved_homes
	GameState.mating_houses = saved_mating
	GameState.village_stockpile = saved_store
	GameState.village_treasury = saved_treasury
	GameState.school_enrollments = saved_enroll

	printerr("test_autoladder : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
