extends Node

# THE WHOLE ARC, WALKED (added 2026-07-20 -- the "full scan" pass).
#
# test_firstsession_node walks the OPENING. This one walks everything
# after it: the mid-game loop nobody had ever tested end to end (rescue ->
# thaw -> employ -> pay -> build -> house -> siege while away -> come home
# and read what it cost), and then the whole finale chain (free the Ten ->
# the gate -> the Harvest -> the mortal window -> victory -> the Shadow
# Army -> the Chronicle -> NG+).
#
# The point is SEAMS. Each of these systems has its own passing suite; the
# breaks that actually strand a player live between two of them, and the
# only way to find those is to walk the whole road in order.

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
	for i in range(90):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false
	for i in range(10):
		await get_tree().physics_frame

	GameState.reset_for_new_game()
	GameState.hours_until_next_siege = 99999.0
	p.global_position = Vector2(5000.0, -100.0)   # stand in the village (fog off)

	# ============ ACT II: THE LOOP THAT IS THE GAME ============
	# a rescue comes home WRAPPED (4.2a) and unwraps at the door
	GameState.rescue_villager({
		"id": "arc_smith", "name": "Arc Smith", "sex": "Female", "is_kid": false,
		"stat_name": "Blacksmith", "stat_value": 5, "role_key": "", "role_title": "",
		"stats_hidden": true,
	})
	check("a rescue joins the roster", GameState.is_villager_rescued("arc_smith"))
	var v: Dictionary = GameState.find_villager_by_id("arc_smith")
	check("...with their talents still wrapped", v.get("stats_hidden", false))
	var main_scene = get_tree().current_scene
	if main_scene.has_method("spawn_existing_villager_avatars"):
		main_scene.spawn_existing_villager_avatars()
	v = GameState.find_villager_by_id("arc_smith")
	check("...and the THAW at home unwraps them", not v.get("stats_hidden", false))

	# a raised building can be staffed by exactly the right person
	GameState.building_stage["Blacksmith"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Blacksmith"] = 100
	check("a rebuilt building is operational", GameState.is_building_operational("Blacksmith"))
	check("the rescued smith can take the post",
		GameState.assign_villager_to_role("arc_smith", "Blacksmith", "Blacksmith"))
	check("...and the village counts them as staff",
		GameState.count_workers("Blacksmith") == 1)
	check("a staffed forge lifts every spirit (the armed-town term)",
		GameState.personal_morale_target(GameState.find_villager_by_id("arc_smith")) > 1.4)

	# wages: they are PAID, and an empty purse costs you the worker
	var saved_gold: int = p.currency
	p.currency = 1000
	GameState.wage_accum_hours = 0.0
	GameState.tick_wages(24.0)
	check("payday draws from the purse", p.currency < 1000)
	p.currency = 0
	GameState.tick_wages(24.0)
	check("an empty purse costs you the post",
		str(GameState.find_villager_by_id("arc_smith").get("role_key", "")) == "")
	p.currency = saved_gold

	# ---- the away siege, and the homecoming that explains it ----
	GameState.log_unread = 0
	GameState.rescue_villager({"id": "arc_spare", "name": "Spare Soul", "sex": "Male",
		"is_kid": false, "stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": ""})
	# a wave the village cannot quite hold -- costly, NOT a wipe (a tier-99
	# hammer would leave only the unbreakable Ten and there would be no town
	# left to harvest later, which is the town's problem, not the game's)
	#
	# DERIVED FROM LIVE DEFENSE, never hardcoded (fix 2026-07-29): resolve_siege_offline
	# repels a wave OUTRIGHT at defense >= tier, so a fixed tier silently stops testing
	# anything the moment defense is rebalanced. It did: 78cbe3c dropped the low-morale
	# 0.5x penalty, which lifted this town's defense above the old flat tier-6 and the
	# "costs real people" assertion went green-by-accident-then-red. A few points ABOVE
	# whatever the town can actually field always models the intended scenario.
	var before_roster: int = GameState.rescued_villagers.size()
	GameState.in_dungeon = true                    # the fog comes down
	# ...and the wave must out-last the SHIELDS too: every fighting adventurer dies
	# in place of a villager, and Maera pulls one more back from the brink, so a
	# wave sized only just past the wall kills nothing but adventurers.
	var shields: int = GameState.fighting_adventurers().size()
	var stabilized: int = 1 if GameState.ten_freed("ten_maera") else 0
	var unholdable: int = int(ceil(GameState.village_defense_power())) + shields + stabilized + 2
	GameState.resolve_siege_offline(unholdable)
	check("an unheld siege costs the village real people",
		GameState.rescued_villagers.size() < before_roster)
	check("...and it is written down while you cannot see it",
		GameState.log_unread > 0, str(GameState.log_unread))
	GameState.in_dungeon = false
	if main_scene.has_method("show_away_report"):
		main_scene.show_away_report()
	check("coming home clears the unread mark (you were told)",
		GameState.log_unread == 0)

	# ---- your own death has a NAMED price, and never takes a legend ----
	GameState.rescue_villager({"id": "arc_doomed", "name": "Doomed Soul", "sex": "Female",
		"is_kid": false, "stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": ""})
	GameState.log_unread = 0
	var toll_before: int = GameState.rescued_villagers.size()
	GameState.report_death_toll("Medium")
	check("your death costs a named life",
		GameState.rescued_villagers.size() == toll_before - 1)
	var told := false
	for e in GameState.village_log:
		if str(e.get("text", "")).contains("while you lay dying"):
			told = true
	check("...and the diary records WHY they died", told)

	# ============ ACT IV: THE GATE, AND WHAT IT DEMANDS ============
	check("the gate refuses an imperfect village",
		not GameState.finale_gate_missing().is_empty())
	for b in GameState.STARTING_BUILDINGS:          # a perfect town, by hand
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100
	for t in TheTen.ids():
		GameState.free_one_of_the_ten(t)
	check("all Ten walk free", GameState.all_ten_freed())
	check("...and freeing the tenth gifts the wand",
		p.inventory.get_count("wpn_soulsplit") > 0)
	var still_missing: Array = GameState.finale_gate_missing()
	check("the gate now wants only PEOPLE, not stone",
		not str(still_missing).contains("ruins"), str(still_missing))

	# ============ THE HARVEST ============
	# a real town stands at the gate: the Ten plus ordinary souls to lose
	for i in range(6):
		GameState.rescue_villager({"id": "arc_town_%d" % i, "name": "Townsfolk %d" % i,
			"sex": "Male", "is_kid": false, "stat_name": "Farm", "stat_value": 3,
			"role_key": "", "role_title": ""})
	var roster_before: int = GameState.rescued_villagers.size()
	GameState.begin_harvest()
	check("the turn takes everyone who can be taken",
		GameState.harvested_villagers.size() > 0)
	check("...and ONLY the unbreakable are left standing",
		GameState.rescued_villagers.size() == 10
		and GameState.rescued_villagers.size() < roster_before,
		"%d left of %d" % [GameState.rescued_villagers.size(), roster_before])
	# the unbreakable are unbreakable by EVERY road, including your death
	var legends_before: int = GameState.rescued_villagers.size()
	for i in range(25):
		GameState.report_death_toll("Hard")
		GameState.remove_random_villager()
	check("nothing -- not even your dying -- can take one of the Ten",
		GameState.rescued_villagers.size() == legends_before,
		"%d -> %d" % [legends_before, GameState.rescued_villagers.size()])
	check("the turn happens exactly once",
		(func():
			var n := GameState.harvested_villagers.size()
			GameState.begin_harvest()
			return GameState.harvested_villagers.size() == n).call())

	# ============ VICTORY, AND THE WORLD AFTER ============
	GameState.despair_dead = true
	GameState.raise_shadow_army()
	check("the fallen rise as themselves, continued",
		GameState.harvested_villagers.is_empty() and GameState.rescued_villagers.size() > 10)
	var shadows := 0
	for sv in GameState.rescued_villagers:
		if sv.get("shadow", false):
			shadows += 1
	check("...and they wear the shadow", shadows > 0, str(shadows))
	GameState.hours_until_next_siege = 1.0
	GameState.tick_sieges(48.0)
	check("Despair is dead, so the nights are quiet forever",
		GameState.hours_until_next_siege == 1.0)
	var book: Array = GameState.chronicle()
	check("the Chronicle can see the war is won",
		bool(book[5].get("done", false)) and bool(book[6].get("done", false)))

	# ============ NG+: THE REWOUND HOUR ============
	GameState.player_level = 55
	GameState.chosen_class = "Mage"
	GameState.unlocked_skills = ["mg_root", "mg_t1"]
	GameState.rewind_world_keep_player()
	check("the rewind keeps YOU whole",
		GameState.player_level == 55 and GameState.chosen_class == "Mage"
		and GameState.unlocked_skills.has("mg_t1"))
	check("...and gives the world back its ruins",
		GameState.count_ruined_buildings() == GameState.STARTING_BUILDINGS.size()
		and not GameState.despair_dead and not GameState.harvest_done
		and GameState.count_ten_freed() == 0)
	check("...counting the worlds walked", GameState.ng_plus_cycles == 1)
	check("a rewound world still knows what to do next",
		GameState.next_objective().length() > 8)

	GameState.reset_for_new_game()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
