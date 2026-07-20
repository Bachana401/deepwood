extends Node

# THE GOLD FAUCETS + WAGES (GAME_BIBLE 5.5 / 5.6). Canon: only the
# Government (taxes) and the Bank (interest) make village gold -- plus a Bar
# trickle and the player's dungeon haul. No other building prints money.
# Staff draw a daily wage; workers the purse cannot cover QUIT.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# ---- paint a controlled economy ----
	var saved_roster: Array = GameState.rescued_villagers
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_gold: int = p.currency
	var saved_wage_accum: float = GameState.wage_accum_hours
	var saved_log: Array = GameState.village_log
	GameState.village_log = []
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_stage[b] = 0            # whole town in ruins
	var roster := []
	for i in range(6):
		roster.append({"id": "ec_%d" % i, "name": "Worker %d" % i, "sex": "Male",
			"is_kid": false, "stat_name": "Farm", "stat_value": 5,
			"role_key": "Farm", "role_title": "Farmer"})
	GameState.rescued_villagers = roster

	# ---- 5.6: no Government, no taxes -- the dungeon is the only faucet ----
	p.currency = 100
	GameState.generate_passive_income()
	check("a village without a working Government prints NOTHING",
		p.currency == 100, str(p.currency))
	GameState.building_stage["Government"] = GameState.TOTAL_BUILD_STAGES
	GameState.generate_passive_income()
	check("a working but UNSTAFFED Government still cannot tax",
		p.currency == 100, str(p.currency))
	roster.append({"id": "ec_gov", "name": "Official", "sex": "Male", "is_kid": false,
		"stat_name": "Financist", "stat_value": 5, "role_key": "Government", "role_title": "Official"})
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.generate_passive_income()
	check("a staffed Government taxes the working village",
		p.currency > 100, str(p.currency))
	var taxed: int = p.currency
	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES
	roster.append({"id": "ec_bar", "name": "Keep", "sex": "Female", "is_kid": false,
		"stat_name": "Tavern", "stat_value": 4, "role_key": "Bar", "role_title": "Barkeep"})
	GameState.generate_passive_income()
	check("the Bar trickles drink money on the side",
		p.currency > taxed, str(p.currency))
	check("the old per-worker printing press is GONE",
		not FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains("INCOME_ROLES"))

	# ---- 5.5 wages: payday, and the quitting ----
	p.currency = 1000
	GameState.wage_accum_hours = 0.0
	GameState.tick_wages(24.0)
	check("payday draws the daily wage from the purse",
		p.currency < 1000, str(p.currency))
	var employed := 0
	for v in roster:
		if str(v.get("role_key", "")) != "":
			employed += 1
	p.currency = 0
	GameState.tick_wages(24.0)
	var still_employed := 0
	for v in roster:
		if str(v.get("role_key", "")) != "":
			still_employed += 1
	check("an empty purse means workers QUIT, on the spot",
		still_employed < employed, "%d -> %d" % [employed, still_employed])
	var quit_logged := false
	for e in GameState.village_log:
		if str(e.get("text", "")).contains("quit their post"):
			quit_logged = true
	check("the Log names the quitters", quit_logged)

	# ---- 5.5 health: the ward fights the withering ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("doctors slow the withering and speed recovery",
		gs.contains("drain_rate /= 1.0 + 0.3 * float(doctors)")
		and gs.contains("1.0 + 0.5 * float(doctors)"))
	var bg := FileAccess.open("res://building.gd", FileAccess.READ).get_as_text()
	check("the staffed ward treats the PLAYER for a flat price",
		bg.contains("HOSPITAL_HEAL_PRICE") and bg.contains("knit you whole"))
	check("interest is the Bank's function, not only the Treasurer's",
		gs.contains('count_workers("Bank") > 0'))
	check("wage bookkeeping survives the save",
		gs.contains('"wage_accum_hours": wage_accum_hours'))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.building_stage = saved_stage
	GameState.wage_accum_hours = saved_wage_accum
	GameState.village_log = saved_log
	p.currency = saved_gold
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
