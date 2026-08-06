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

	# ---- THE WORKERS WORK (2026-07-29) ----
	# An audit found 30 declared, staffable worker slots that no game logic ever
	# read: School "Teachers", Tavern "Barman", Blacksmith "Blacksmith". A player
	# could seat ten villagers in each and change NOTHING. Each must now pay.
	var seat := func(bname: String, title: String, n: int) -> void:
		GameState.rescued_villagers = []
		GameState.building_stage[bname] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[bname] = GameState.BUILDING_MAX_HEALTH
		GameState.village_food = 400.0
		for i in range(n):
			GameState.rescued_villagers.append({
				"id": "wk_%s_%d" % [title, i], "name": "W%d" % i, "sex": "Male",
				"is_kid": false, "stat_name": "", "stat_value": 3,
				"role_key": bname, "role_title": title})

	seat.call("School", "Teachers", 0)
	var school_empty: float = GameState.get_school_graduation_speed_multiplier()
	seat.call("School", "Teachers", 8)
	var school_staffed: float = GameState.get_school_graduation_speed_multiplier()
	check("staffed TEACHERS speed graduation (the post is no longer inert)",
		school_staffed > school_empty, "%.2f -> %.2f" % [school_empty, school_staffed])

	seat.call("Tavern", "Barman", 0)
	var tav_empty: int = GameState.village_morale()
	seat.call("Tavern", "Barman", 8)
	var tav_staffed: int = GameState.village_morale()
	check("staffed BARMEN warm the room (morale rises)",
		tav_staffed > tav_empty, "%d -> %d" % [tav_empty, tav_staffed])

	# the smiths: more hands at the bench, more arms off it per tick
	GameState.rescued_villagers = []
	for b in ["Blacksmith", "Barracks"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH
	GameState.rescued_villagers.append({"id": "fm", "name": "Forgemaster", "sex": "Female",
		"is_kid": false, "stat_name": "Forgemaster", "stat_value": 6,
		"role_key": "Blacksmith", "role_title": "Forgemaster"})
	var arms_of := func(smiths: int) -> int:
		while GameState.rescued_villagers.size() > 1:
			GameState.rescued_villagers.pop_back()
		for i in range(smiths):
			GameState.rescued_villagers.append({"id": "sm_%d" % i, "name": "S%d" % i,
				"sex": "Male", "is_kid": false, "stat_name": "Blacksmith", "stat_value": 3,
				"role_key": "Blacksmith", "role_title": "Blacksmith"})
		GameState.barracks_arms = 0
		GameState.village_stockpile["iron_shard"] = 999
		GameState.apply_leadership_automation()
		return GameState.barracks_arms
	var arms_alone: int = arms_of.call(0)
	var arms_crew: int = arms_of.call(8)
	check("staffed SMITHS raise forge throughput (the bench is no longer inert)",
		arms_crew > arms_alone, "%d -> %d arms/tick" % [arms_alone, arms_crew])

	# ---- THE INVARIANT: every leadership post must be FILLABLE (2026-07-29) ----
	# The Mine shipped with no leadership post at all, and nothing caught it. Worse,
	# leadership stats are deliberately absent from REGULAR_STATS (the School must
	# never teach them), so the ONLY way to fill a leader seat is rescuing the VIP
	# who carries that stat. A post with no matching VIP is a seat nobody can ever
	# sit in. Pin both halves so neither gap can return.
	var vip_stats := {}
	for lvl in VillagerQuests.IMPORTANT_FIGURES:
		vip_stats[str(VillagerQuests.IMPORTANT_FIGURES[lvl].get("stat_name", ""))] = true
	var unfillable := []
	for bname in GameState.STARTING_BUILDINGS + ["Mine", "Shrine"]:
		for rd in BuildingRoles.get_roles(bname):
			if not rd.get("leadership", false):
				continue
			var want := str(rd.get("required_stat", ""))
			if not vip_stats.has(want):
				unfillable.append("%s/%s needs stat '%s'" % [bname, str(rd.get("title", "")), want])
	check("every leadership post has a rescuable VIP who can fill it",
		unfillable.is_empty(), ", ".join(unfillable))
	check("the Mine has a leadership post like every other building",
		BuildingRoles.get_roles("Mine").any(func(r): return r.get("leadership", false)),
		"Mine roles: %s" % str(BuildingRoles.get_roles("Mine")))

	# ---- THE UPGRADE MUST BUY SOMETHING (2026-07-29) ----
	# Every building levels 1..6 at 30*lvl^2 gold, and assign_ui PROMISES
	# "+N% output at this level" -- but nine buildings' outputs never read
	# building_output_multiplier(), so the player paid ~1650 gold for nothing and
	# the UI lied. Pin it at the source: every upgradeable building must fold its
	# own level into some output.
	# EXCEPTION: the Shrine's only output is binary (shrine_ready -> you may
	# cleanse), so there is no rate for a multiplier to scale.
	const OUTPUT_EXEMPT := ["Shrine"]
	var gs_src := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	var deaf := []
	for bname in GameState.STARTING_BUILDINGS + ["Mine"]:
		if bname in OUTPUT_EXEMPT:
			continue
		if not gs_src.contains('building_output_multiplier("%s")' % bname):
			deaf.append(bname)
	check("every upgradeable building's output actually reads its LEVEL",
		deaf.is_empty(), "these ignore their upgrades: %s" % ", ".join(deaf))
	# and prove it end-to-end on one of them: levelling the School must school faster
	GameState.rescued_villagers = []
	GameState.building_stage["School"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["School"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_levels["School"] = 1
	var sch_l1: float = GameState.get_school_graduation_speed_multiplier()
	GameState.building_levels["School"] = 6
	var sch_l6: float = GameState.get_school_graduation_speed_multiplier()
	GameState.building_levels.erase("School")
	check("...proved end-to-end: a level-6 School graduates faster than a level-1",
		sch_l6 > sch_l1, "L1=%.2f L6=%.2f" % [sch_l1, sch_l6])

	# ---- BUILDING POWERS (dev law 2026-07-29: behaviour, not stats) ----
	# At BUILDING_POWER_LEVEL each building wakes a NAMED power that changes what
	# it DOES -- but ONLY with its leader in the chair (dev call 2026-07-30: "leader
	# loses its value"). As first built, ten powers did the seated leader's own job,
	# so gold spent on a level bought past the rarest content in the game and past
	# the automation ladder's rescue-depth pacing. A power is now the leader's
	# MASTERWORK: it needs the hall AND the person.
	var lvl_all := func(n: int) -> void:
		for bn in GameState.BUILDING_POWERS.keys():
			GameState.building_levels[bn] = n
			GameState.building_stage[bn] = GameState.TOTAL_BUILD_STAGES
			GameState.building_health[bn] = GameState.BUILDING_MAX_HEALTH
	# seat whoever each power answers to: the named leader, or (the Shrine alone,
	# which crowns no VIP) its keepers at their posts
	var seat_all := func() -> void:
		GameState.rescued_villagers = []
		for bn in GameState.BUILDING_POWERS.keys():
			var post := ""
			for rd in BuildingRoles.get_roles(bn):
				if rd.get("leadership", false):
					post = str(rd.get("title", ""))
					break
			if post != "":
				GameState.rescued_villagers.append({"id": "pw_%s" % bn, "name": "Chief %s" % bn,
					"sex": "Male", "is_kid": false, "stat_name": post, "stat_value": 6,
					"role_key": bn, "role_title": post})
			else:
				GameState.rescued_villagers.append({"id": "pw_%s" % bn, "name": "Keeper %s" % bn,
					"sex": "Female", "is_kid": false, "stat_name": "Hospital", "stat_value": 4,
					"role_key": bn, "role_title": "Lightkeeper"})
	seat_all.call()
	lvl_all.call(GameState.BUILDING_POWER_LEVEL - 1)
	var dormant := []
	for bn in GameState.BUILDING_POWERS.keys():
		if GameState.has_building_power(bn):
			dormant.append(bn)
	check("no power wakes BELOW the milestone level, even fully staffed", dormant.is_empty(), str(dormant))
	lvl_all.call(GameState.BUILDING_POWER_LEVEL)
	var asleep := []
	for bn in GameState.BUILDING_POWERS.keys():
		if not GameState.has_building_power(bn):
			asleep.append(bn)
	check("every declared power wakes at the milestone WITH its leader seated", asleep.is_empty(), str(asleep))
	# ...AND THE RULE ITSELF: an empty chair wakes nothing, however grand the hall
	GameState.rescued_villagers = []
	var leaderless := []
	for bn in GameState.BUILDING_POWERS.keys():
		if GameState.has_building_power(bn):
			leaderless.append(bn)
	check("NO power wakes on level alone — an empty chair wakes nothing (the leader keeps its value)",
		leaderless.is_empty(), str(leaderless))
	seat_all.call()
	check("each power is NAMED (identity, not a stat line)",
		GameState.building_power_name("Blacksmith") == "The Night Forge")

	# THE STANDING WATCH: an off-shift warrior must count full once it wakes
	# (the Warchief must be in the chair now, or the power sleeps)
	GameState.rescued_villagers = [{"id": "sw1", "name": "Nightguard", "sex": "Male",
		"is_kid": false, "stat_name": "Warrior", "stat_value": 4,
		"role_key": "Barracks", "role_title": "Warrior"},
		{"id": "sw_ldr", "name": "Warchief", "sex": "Female", "is_kid": false,
		"stat_name": "Warchief", "stat_value": 7, "role_key": "Barracks", "role_title": "Warchief"}]
	GameState.ensure_adventurers()
	for aid in GameState.adventurers.keys():
		GameState.adventurers[aid]["station"] = "house"
	var off_shift := not GameState.warrior_on_duty(GameState.rescued_villagers[0])
	GameState.building_levels["Barracks"] = GameState.BUILDING_POWER_LEVEL - 1
	var def_before: float = GameState.village_defense_power()
	GameState.building_levels["Barracks"] = GameState.BUILDING_POWER_LEVEL
	var def_after: float = GameState.village_defense_power()
	if off_shift:
		check("THE STANDING WATCH: the off-shift hold the wall at full worth",
			def_after > def_before, "%.2f -> %.2f" % [def_before, def_after])
	else:
		check("THE STANDING WATCH: on-shift already full, power costs nothing",
			is_equal_approx(def_after, def_before), "%.2f -> %.2f" % [def_before, def_after])

	# THE NIGHT FORGE (re-scoped 2026-07-30): the Forgemaster's own bench, doubled.
	# It used to arm the town with NO Forgemaster -- which is exactly what made the
	# leader worthless. The master must be seated; level 4 is what he does with it.
	for b in ["Blacksmith", "Barracks"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH
	var forge := func(lvl: int) -> int:
		GameState.building_levels["Blacksmith"] = lvl
		GameState.rescued_villagers = [{"id": "fm", "name": "Hilda", "sex": "Female",
			"is_kid": false, "stat_name": "Forgemaster", "stat_value": 6,
			"role_key": "Blacksmith", "role_title": "Forgemaster"}]
		GameState.barracks_arms = 0
		GameState.village_stockpile["iron_shard"] = 999
		GameState.apply_leadership_automation()
		return GameState.barracks_arms
	var arms_plain: int = forge.call(GameState.BUILDING_POWER_LEVEL - 1)
	var arms_woken: int = forge.call(GameState.BUILDING_POWER_LEVEL)
	check("THE NIGHT FORGE: the Forgemaster's bench turns out MORE once the hall is grand",
		arms_woken > arms_plain, "plain=%d woken=%d" % [arms_plain, arms_woken])
	GameState.rescued_villagers = []
	GameState.building_levels["Blacksmith"] = GameState.BUILDING_POWER_LEVEL
	GameState.barracks_arms = 0
	GameState.village_stockpile["iron_shard"] = 999
	GameState.apply_leadership_automation()
	check("...and forges NOTHING with the chair empty, however grand the hall",
		GameState.barracks_arms == 0, str(GameState.barracks_arms))

	# THE STANDING ORDER (re-scoped): the Chancellor corrects the seating already
	# done -- a trained hand in the wrong trade is moved to work that fits. It used
	# to staff the town with NO Chancellor at all.
	var mismatch := func(lvl: int) -> bool:
		GameState.building_levels["Government"] = lvl
		for bb in ["Government", "Farm", "Mine"]:
			GameState.building_stage[bb] = GameState.TOTAL_BUILD_STAGES
			GameState.building_health[bb] = GameState.BUILDING_MAX_HEALTH
		GameState.rescued_villagers = [
			{"id": "ch", "name": "Alaric", "sex": "Male", "is_kid": false,
				"stat_name": "Chancellor", "stat_value": 9,
				"role_key": "Government", "role_title": "Chancellor"},
			# a trained farmer shovelling in the Mine: employed, but wrongly
			{"id": "wrong", "name": "Misplaced", "sex": "Male", "is_kid": false,
				"stat_name": "Farm", "stat_value": 4, "role_key": "Mine", "role_title": "Miner"}]
		GameState.apply_leadership_automation()
		for v in GameState.rescued_villagers:
			if str(v.get("id", "")) == "wrong":
				return str(v.get("role_key", "")) == "Farm"
		return false
	check("THE STANDING ORDER: below the milestone the misplaced stay misplaced",
		not mismatch.call(GameState.BUILDING_POWER_LEVEL - 1))
	check("THE STANDING ORDER: a grown Government moves them to work that fits",
		mismatch.call(GameState.BUILDING_POWER_LEVEL))

	# THE STANDING HARVEST: an empty larder must not kill a grown Farm's town
	var starve := func(lvl: int) -> float:
		GameState.building_levels["Farm"] = lvl
		GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health["Farm"] = GameState.BUILDING_MAX_HEALTH
		# the Harvestmaster must be seated (the power is HERS now) -- so the town has
		# to out-eat her fields for the larder to empty at all, which is exactly when
		# the reserve is meant to matter. Enough mouths to run the deficit.
		GameState.rescued_villagers = [{"id": "hm", "name": "Maeve", "sex": "Female",
			"is_kid": false, "stat_name": "Harvestmaster", "stat_value": 5,
			"role_key": "Farm", "role_title": "Harvestmaster"}]
		for hi in range(30):
			GameState.rescued_villagers.append({"id": "hungry_%d" % hi, "name": "Hungry%d" % hi,
				"sex": "Male", "is_kid": false, "stat_name": "", "stat_value": 3,
				"role_key": "", "role_title": ""})
		GameState.village_food = 0.0
		GameState._harvest_reserve_cd = 0.0
		GameState.tick_food(1.0)
		return GameState.village_food
	var fed_dormant: float = starve.call(GameState.BUILDING_POWER_LEVEL - 1)
	var fed_woken: float = starve.call(GameState.BUILDING_POWER_LEVEL)
	check("THE STANDING HARVEST: a grown Farm opens its reserve on an empty larder",
		fed_dormant <= 0.0 and fed_woken > 0.0, "dormant=%.1f woken=%.1f" % [fed_dormant, fed_woken])

	# THE WARD THAT NEVER SLEEPS: the wounded leave whole, not trickled
	var ward := func(lvl: int) -> float:
		GameState.building_levels["Hospital"] = lvl
		GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health["Hospital"] = GameState.BUILDING_MAX_HEALTH
		GameState.rescued_villagers = [{"id": "cp", "name": "Vesna", "sex": "Female",
			"is_kid": false, "stat_name": "Chief Physician", "stat_value": 6,
			"role_key": "Hospital", "role_title": "Chief Physician"}]
		GameState.villager_hp = {"hurt": 1.0}
		GameState.auto_heal_villagers(1)
		return float(GameState.villager_hp["hurt"])
	var hp_dormant: float = ward.call(GameState.BUILDING_POWER_LEVEL - 1)
	var hp_woken: float = ward.call(GameState.BUILDING_POWER_LEVEL)
	check("THE WARD THAT NEVER SLEEPS: a grown ward heals the hurt to FULL",
		hp_woken >= GameState.VILLAGER_MAX_HP and hp_dormant < GameState.VILLAGER_MAX_HP,
		"dormant=%.0f woken=%.0f" % [hp_dormant, hp_woken])

	# THE MATCHMAKER'S ROUND: with the Publican in a grand hall, a match is made AND
	# a home is raised for it, with no Master Builder needed to order the work
	# (the power needs its OWN leader now -- it just no longer needs anyone else's)
	var matched := func(lvl: int) -> int:
		GameState.building_levels["Bar"] = lvl
		for b in ["Bar", "Builderhouse"]:
			GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
			GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH
		GameState.building_levels["Builderhouse"] = 1
		# NO free cottage on purpose: pairing alone needs one, so what the power adds
		# is RAISING the home for the couple that would otherwise wait forever --
		# and doing it without a Master Builder to order the work.
		GameState.cottage_homes = {}
		GameState.mating_houses = {}
		GameState.extra_cottage_ids = []
		GameState.extra_cottage_positions = []
		GameState.extra_cottages = 0
		GameState.village_stockpile = {"wood": 99, "stone": 99, "iron_shard": 0}
		GameState.rescued_villagers = [
			{"id": "mm_m", "name": "M", "sex": "Male", "is_kid": false, "stat_name": "",
				"stat_value": 3, "role_key": "", "role_title": ""},
			{"id": "mm_f", "name": "F", "sex": "Female", "is_kid": false, "stat_name": "",
				"stat_value": 3, "role_key": "", "role_title": ""},
			{"id": "mm_pub", "name": "Fenn", "sex": "Male", "is_kid": false, "stat_name": "Publican",
				"stat_value": 5, "role_key": "Bar", "role_title": "Publican"}]
		# the full pass, not auto_pair_couples alone: RAISING the home is the half
		# the power adds, and that happens in apply_leadership_automation
		GameState.apply_leadership_automation()
		return GameState.mating_houses.size() + GameState.cottage_homes.size()
	var mm_dormant: int = matched.call(GameState.BUILDING_POWER_LEVEL - 1)
	var mm_woken: int = matched.call(GameState.BUILDING_POWER_LEVEL)
	check("THE MATCHMAKER'S ROUND: the Publican's grown Bar RAISES the home the couple lacked",
		mm_dormant == 0 and mm_woken > 0, "dormant=%d woken=%d" % [mm_dormant, mm_woken])

	# THE UNBROKEN LIGHT: despair takes root in nobody while the light holds
	var rooted := func(lvl: int) -> int:
		GameState.building_levels["Shrine"] = lvl
		GameState.building_stage["Shrine"] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health["Shrine"] = GameState.BUILDING_MAX_HEALTH
		GameState.villager_rot = {}
		GameState.rescued_villagers = [{"id": "sad", "name": "Sad", "sex": "Male",
			"is_kid": false, "stat_name": "", "stat_value": 3, "role_key": "",
			"role_title": "", "morale": 0.0},
			# the Shrine crowns no VIP: its KEEPERS at their posts hold the light
			{"id": "lk", "name": "Keeper", "sex": "Female", "is_kid": false,
				"stat_name": "Hospital", "stat_value": 4,
				"role_key": "Shrine", "role_title": "Lightkeeper"}]
		GameState.tick_rot(1.0)
		return GameState.villager_rot.size()
	var rot_dormant: int = rooted.call(GameState.BUILDING_POWER_LEVEL - 1)
	var rot_woken: int = rooted.call(GameState.BUILDING_POWER_LEVEL)
	check("THE UNBROKEN LIGHT: despair takes root in nobody while the light holds",
		rot_dormant > 0 and rot_woken == 0, "dormant=%d woken=%d" % [rot_dormant, rot_woken])

	# THE WHISPER NETWORK: every material known at once, not one per tick
	var known := func(lvl: int) -> int:
		GameState.building_levels["Science Lab"] = lvl
		GameState.building_stage["Science Lab"] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health["Science Lab"] = GameState.BUILDING_MAX_HEALTH
		GameState.rescued_villagers = [{"id": "lr", "name": "Wrenna", "sex": "Female",
			"is_kid": false, "stat_name": "Lead Researcher", "stat_value": 7,
			"role_key": "Science Lab", "role_title": "Lead Researcher"}]
		GameState.researched_materials = []
		GameState.auto_research(1)
		return GameState.researched_materials.size()
	var known_dormant: int = known.call(GameState.BUILDING_POWER_LEVEL - 1)
	var known_woken: int = known.call(GameState.BUILDING_POWER_LEVEL)
	check("THE WHISPER NETWORK: a grown Lab knows every material on sight",
		known_woken > known_dormant + 1, "dormant=%d woken=%d" % [known_dormant, known_woken])

	# THE LONG NIGHT: a floor under the town's spirit
	GameState.building_stage["Tavern"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Tavern"] = GameState.BUILDING_MAX_HEALTH
	GameState.village_food = 200.0
	GameState.morale_death_shock = 0.0
	GameState.rescued_villagers = [{"id": "bleak", "name": "Bleak", "sex": "Male",
		"is_kid": false, "stat_name": "", "stat_value": 3, "role_key": "",
		"role_title": "", "morale": 0.0},
		# the keeper is seated (the power is hers) but just as bleak, so the reading
		# reflects THE FLOOR rather than one cheerful outlier lifting the average
		{"id": "tk", "name": "Bess", "sex": "Female", "is_kid": false, "stat_name": "Tavernkeeper",
			"stat_value": 5, "role_key": "Tavern", "role_title": "Tavernkeeper", "morale": 0.0}]
	GameState.building_levels["Tavern"] = GameState.BUILDING_POWER_LEVEL - 1
	var mood_dormant: int = GameState.village_morale()
	GameState.building_levels["Tavern"] = GameState.BUILDING_POWER_LEVEL
	var mood_woken: int = GameState.village_morale()
	check("THE LONG NIGHT: no heart falls all the way to nothing",
		mood_woken > mood_dormant and mood_woken >= int(GameState.LONG_NIGHT_MORALE_FLOOR),
		"dormant=%d woken=%d" % [mood_dormant, mood_woken])

	# ALL FIFTEEN declared, named, and described
	check("all 15 buildings have a named power",
		GameState.BUILDING_POWERS.size() == 15,
		"%d declared" % GameState.BUILDING_POWERS.size())
	var nameless := []
	for bn in GameState.BUILDING_POWERS.keys():
		var d: Dictionary = GameState.BUILDING_POWERS[bn]
		if str(d.get("name", "")) == "" or str(d.get("desc", "")) == "":
			nameless.append(bn)
	check("every power carries a name AND a description for the UI",
		nameless.is_empty(), str(nameless))
	# ---- LEADER POWERS: the four who were pure STAT (2026-07-29) ----
	# Harvestmaster/Harbormaster/Pitmaster/Warchief carried only a percentage while
	# every other leader DID something. Each must now have a named behaviour.
	check("all four stat-only leaders have a named power",
		GameState.LEADER_POWERS.size() == 4
		and str(GameState.LEADER_POWERS["Barracks"]["name"]) == "The Muster",
		"%d declared" % GameState.LEADER_POWERS.size())
	check("their flat percentages shrank to connective tissue",
		GameState.HARVESTMASTER_FOOD_BONUS <= 0.15 and GameState.PITMASTER_YIELD_BONUS <= 0.15,
		"food=%.2f ore=%.2f" % [GameState.HARVESTMASTER_FOOD_BONUS, GameState.PITMASTER_YIELD_BONUS])

	# THE FULL TABLE: the Farm feeds with NO farmhands seated
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Farm"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_levels["Farm"] = 1
	GameState.rescued_villagers = []
	var food_nobody: float = GameState.food_production_per_hour()
	GameState.rescued_villagers = [{"id": "hm", "name": "Harvestmaster", "sex": "Female",
		"is_kid": false, "stat_name": "Harvestmaster", "stat_value": 5,
		"role_key": "Farm", "role_title": "Harvestmaster"}]
	var food_master: float = GameState.food_production_per_hour()
	check("THE FULL TABLE: a Harvestmaster works the fields with no farmhands",
		food_nobody == 0.0 and food_master > 0.0,
		"nobody=%.2f master=%.2f" % [food_nobody, food_master])

	# THE MUSTER: untrained townsfolk stand to the wall
	GameState.building_stage["Barracks"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Barracks"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_levels["Barracks"] = 1
	GameState.ensure_adventurers()
	for aid in GameState.adventurers.keys():
		GameState.adventurers[aid]["station"] = "house"
	var townsfolk := []
	for i in range(8):
		townsfolk.append({"id": "tf_%d" % i, "name": "T%d" % i, "sex": "Male",
			"is_kid": false, "stat_name": "Farm", "stat_value": 3,
			"role_key": "Farm", "role_title": "Farmer"})
	GameState.rescued_villagers = townsfolk.duplicate(true)
	var def_nomuster: float = GameState.village_defense_power()
	GameState.rescued_villagers = townsfolk.duplicate(true)
	GameState.rescued_villagers.append({"id": "wc", "name": "Warchief", "sex": "Female",
		"is_kid": false, "stat_name": "Warchief", "stat_value": 7,
		"role_key": "Barracks", "role_title": "Warchief"})
	var def_muster: float = GameState.village_defense_power()
	check("THE MUSTER: a Warchief calls untrained townsfolk to the wall",
		def_muster > def_nomuster + GameState.WARCHIEF_DEFENSE,
		"no-muster=%.2f muster=%.2f (Warchief alone would be +%.1f)" % [
			def_nomuster, def_muster, GameState.WARCHIEF_DEFENSE])

	# THE SOUNDING: the ore follows how deep the player has carved
	var saved_deep: int = GameState.deepest_level_reached
	GameState.deepest_level_reached = 5
	var shallow_ore: String = GameState._sounding_material()
	GameState.deepest_level_reached = 70
	var deep_ore: String = GameState._sounding_material()
	GameState.deepest_level_reached = saved_deep
	check("THE SOUNDING: the Mine's ore tracks the deepest floor reached",
		shallow_ore != deep_ore, "shallow=%s deep=%s" % [shallow_ore, deep_ore])

	# the shrink: numbers must now be connective tissue, not the reason to upgrade
	check("the numeric ladder shrank to connective tissue (<=10%/level)",
		GameState.BUILDING_OUTPUT_PER_LEVEL <= 0.10,
		"%.2f per level" % GameState.BUILDING_OUTPUT_PER_LEVEL)

	for bn in GameState.BUILDING_POWERS.keys():
		GameState.building_levels.erase(bn)

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
