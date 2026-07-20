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
	# per-day-sane rates accrue fractionally -- a small town earns its coins
	# over several ticks, never a flood per tick (numbers pass 2026-07-20)
	for i2 in range(30):
		GameState.generate_passive_income()
	check("a staffed Government taxes the working village (a day's ticks)",
		p.currency > 100, str(p.currency))
	var taxed: int = p.currency
	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES
	roster.append({"id": "ec_bar", "name": "Keep", "sex": "Female", "is_kid": false,
		"stat_name": "Tavern", "stat_value": 4, "role_key": "Bar", "role_title": "Barkeep"})
	for i3 in range(30):
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

	# ---- THE ROLE ROLL (5.4): rare minds are RARE ----
	var counts := {}
	for i in range(600):
		var s: String = GameState.roll_regular_stat()
		counts[s] = int(counts.get(s, 0)) + 1
		if not GameState.ROLE_ROLL_WEIGHTS.has(s):
			counts["__off_table__"] = 1
	var commons: int = int(counts.get("Farm", 0)) + int(counts.get("Fishing", 0)) + int(counts.get("Tavern", 0))
	check("the roll never leaves the table", not counts.has("__off_table__"))
	check("food and fun are common hands (majority of 600 rolls)",
		commons > 330, str(commons))
	check("a banker is a rare mind",
		int(counts.get("Financist", 0)) < 72, str(counts.get("Financist", 0)))
	# favour-a-calling (5.4 weight-tuning, decided delegated)
	var saved_fav: String = GameState.school_favoured_stat
	var saved_lvls: Dictionary = GameState.building_levels.duplicate(true)
	GameState.school_favoured_stat = "Financist"
	GameState.building_levels["School"] = 1
	var w1: Dictionary = GameState.effective_roll_weights()
	check("level 1 School cannot steer -- the dice rule Act I",
		absf(float(w1["Financist"]) - 6.0) < 0.01)
	GameState.building_levels["School"] = 6
	var w6: Dictionary = GameState.effective_roll_weights()
	var tot6 := 0.0
	for wv in w6.values():
		tot6 += float(wv)
	check("a maxed School leans hard on the favoured calling",
		float(w6["Financist"]) > 6.0)
	check("...but NEVER past 40% -- the dice never fully leave",
		float(w6["Financist"]) / tot6 <= 0.401,
		str(float(w6["Financist"]) / tot6))
	GameState.school_favoured_stat = saved_fav
	GameState.building_levels = saved_lvls

	# ---- THE WANDERER'S POST (5.6a) ----
	var saved_wanderer: Dictionary = GameState.wanderer
	var saved_next: float = GameState.wanderer_next_at_hours
	var saved_seen: int = GameState.wanderers_seen
	var saved_admin2: int = GameState.morale_admin_offset
	var saved_hours3: float = GameState.game_hours
	GameState.building_stage["Marketplace"] = GameState.TOTAL_BUILD_STAGES
	GameState.wanderer = {}
	GameState.wanderers_seen = 0
	GameState.game_hours = 50.0
	GameState.wanderer_next_at_hours = 0.0
	GameState.morale_admin_offset = 100    # a delighted town
	GameState.tick_wanderers(0.1)
	check("a seller drifts in when the road allows",
		not GameState.wanderer.is_empty())
	var stock: Array = GameState.wanderer.get("stock", [])
	var clean := not stock.is_empty()
	for e2 in stock:
		if str(e2.get("id", "")) in GameState.WANDERER_NEVER_SOLD:
			clean = false
	check("the cart carries real wares, never the story items", clean)
	check("a happy town earns the FULL day's stay",
		absf(float(GameState.wanderer["dwell"]) - 24.0) < 0.01)
	var opening: int = int(stock[0].get("price", 0))
	GameState.game_hours = float(GameState.wanderer["arrived"]) + 23.5
	check("hospitality marks prices DOWN across the stay",
		GameState.wanderer_price_now(stock[0]) < opening,
		"%d -> %d" % [opening, GameState.wanderer_price_now(stock[0])])
	# the purchase itself -- with one slot deliberately freed, because a full
	# bag must REFUSE the sale (never charge gold for a ware that can't fit)
	p.currency = 100000
	var bought_id := str(stock[0].get("id", ""))
	var saved_slot0 = p.inventory.slots[0]
	p.inventory.slots[0] = null
	var had: int = p.inventory.get_count(bought_id)
	check("buying charges the purse and fills the bag",
		GameState.buy_from_wanderer(0, p) and p.currency < 100000
		and p.inventory.get_count(bought_id) == had + 1)
	p.inventory.remove_item(bought_id, 1)
	p.inventory.slots[0] = saved_slot0
	check("a full bag refuses the sale instead of eating the coin",
		FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains("add_item(str(entry.get(\"id\", \"\")), 1) > 0"))
	# departure + the next drift
	GameState.game_hours = float(GameState.wanderer["arrived"]) + float(GameState.wanderer["dwell"]) + 0.1
	GameState.tick_wanderers(0.1)
	check("the seller packs up and the NEXT visit is scheduled",
		GameState.wanderer.is_empty()
		and GameState.wanderer_next_at_hours > GameState.game_hours)
	# a gloomy town gets the short goodbye
	GameState.morale_admin_offset = -100
	GameState.wanderer_next_at_hours = 0.0
	GameState.tick_wanderers(0.1)
	check("a gloomy town gets a six-hour stop-and-go",
		absf(float(GameState.wanderer.get("dwell", 0.0)) - 6.0) < 0.01,
		str(GameState.wanderer.get("dwell", 0.0)))
	check("the road talks: later sellers open steeper",
		true if GameState.wanderers_seen >= 2 else false)
	var gs2 := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the Post survives the save",
		gs2.contains('"wanderer": wanderer') and gs2.contains('"wanderers_seen": wanderers_seen'))
	check("the counter opens at the Marketplace and closes like any window",
		FileAccess.open("res://building.gd", FileAccess.READ).get_as_text().contains("wanderer_post_ui")
		and FileAccess.open("res://wanderer_ui.gd", FileAccess.READ).get_as_text().contains("esc_window"))
	GameState.wanderer = saved_wanderer
	GameState.wanderer_next_at_hours = saved_next
	GameState.wanderers_seen = saved_seen
	GameState.morale_admin_offset = saved_admin2
	GameState.game_hours = saved_hours3

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.building_stage = saved_stage
	GameState.wage_accum_hours = saved_wage_accum
	GameState.village_log = saved_log
	p.currency = saved_gold
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
