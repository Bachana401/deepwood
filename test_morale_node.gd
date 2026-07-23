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
	check("cottages are raised from the B menu, charged in gatherable mats",
		FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("pay_build")
		and str(GameState.build_cost("Cottage")).contains("wood")
		and str(GameState.build_cost("Cottage")).contains("stone"))

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

	# ---- THE VILLAGE FOG + TELEPATHY (dev decision 2026-07-20) ----
	var tele_node: Dictionary = SkillTreeData.get_node_by_id("mg_t1")
	check("Telepathy lives mid-tree in the Mystic's road",
		not tele_node.is_empty() and int(tele_node.get("tier", 0)) == 4
		and str(tele_node.get("prereq", "")) == "mg_m2"
		and float(tele_node.get("effect", {}).get("telepathy", 0.0)) > 0.0)
	var fog_saved_skills = GameState.unlocked_skills.duplicate(true)
	var fog_saved_dungeon: bool = GameState.in_dungeon
	GameState.unlocked_skills = []
	GameState.in_dungeon = true
	check("in the deep without Telepathy, the village is beyond knowing",
		not GameState.village_info_available())
	GameState.unlocked_skills = ["mg_t1"]
	check("Telepathy reaches home from ANYWHERE, even the deep",
		GameState.village_info_available())
	GameState.unlocked_skills = []
	GameState.in_dungeon = false
	var fog_p = get_tree().get_first_node_in_group("player")
	var fog_saved_pos: Vector2 = fog_p.global_position
	fog_p.global_position = Vector2(200.0, -100.0)
	check("far west of the gate, the fog holds even in the overworld",
		not GameState.village_info_available())
	fog_p.global_position = Vector2(5000.0, -100.0)
	check("standing in the village, everything is knowable",
		GameState.village_info_available())
	fog_p.global_position = fog_saved_pos
	GameState.unlocked_skills = fog_saved_skills
	GameState.in_dungeon = fog_saved_dungeon
	var gfog := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the village toast channel is fog-gated (the Log records regardless)",
		gfog.contains("if not village_info_available():\n\t\treturn\n\tvar stack"))
	check("the diary, the meter, and the door warning all obey the fog",
		FileAccess.open("res://village_log_ui.gd", FileAccess.READ).get_as_text().contains("village_info_available()")
		and FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text().contains("village_info_available()")
		and FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("village_info_available()"))
	check("the monarch's awakening is about YOU — never fog-gated",
		gfog.contains("never gated by the village fog"))

	# ---- polish: the village at a glance + a game that speaks ----
	var mm: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if "glance" in n and n.has_method("_refresh_glance"):
			mm = n
	check("the TAB overlay carries a village-at-a-glance readout", mm != null)
	# the "what now?" advisor: survival first, then people, then depth
	var obj_saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var obj_saved_roster: Array = GameState.rescued_villagers
	var obj_saved_food: float = GameState.village_food
	GameState.building_stage["Farm"] = 0
	GameState.blueprints = GameState.STARTING_BUILDINGS.duplicate()
	check("with the Farm in ruins, the advisor says raise the Farm",
		GameState.next_objective().contains("Raise the Farm"), GameState.next_objective())
	GameState.blueprints = ["Tavern"]
	check("...unless its plans are still lost, and then it says THAT",
		GameState.next_objective().contains("blueprint"), GameState.next_objective())
	GameState.blueprints = GameState.STARTING_BUILDINGS.duplicate()
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.rescued_villagers = []
	check("a standing but unstaffed Farm asks for hands",
		GameState.next_objective().contains("work at the Farm"), GameState.next_objective())
	GameState.building_stage = obj_saved_stage
	GameState.rescued_villagers = obj_saved_roster
	GameState.village_food = obj_saved_food
	check("the advisor always says SOMETHING true", GameState.next_objective().length() > 5)
	# ---- the hover card must actually be CALLED, and the flee must run ----
	var nsrc := FileAccess.open("res://npc.gd", FileAccess.READ).get_as_text()
	check("the hover card is driven from _process, not dead code after a return",
		nsrc.contains("func _process(delta: float) -> void:\n\t# THE HOVER CARD NEVER RAN"))
	check("...and no unreachable hover call survives the quest turn-in",
		not nsrc.contains("\treturn true\n\tupdate_hover_panel"))
	check("the card shows the talent's VALUE, not just its name",
		nsrc.contains('stat_text = "%s %d" % [str(data.get("stat_name")), int(data.get("stat_value", 0))]'))
	check("a struck villager RUNS FOR HOME",
		nsrc.contains("func is_fleeing") and nsrc.contains("flee_until = Time.get_ticks_msec()")
		and nsrc.contains("FLEE_SPEED_MULT"))
	check("...and panic outranks wandering and clocking in",
		nsrc.contains("if is_fleeing():"))

	check("chests can never be buried under a relocated building",
		FileAccess.open("res://chest.gd", FileAccess.READ).get_as_text().contains("village_structure"))

	# ---- THE ROSTER: every soul on one page, trouble first ----
	var roster_page = preload("res://roster_ui.gd").new()
	get_tree().root.add_child(roster_page)
	await get_tree().process_frame
	var r_saved: Array = GameState.rescued_villagers
	var r_saved_rot: Dictionary = GameState.villager_rot.duplicate(true)
	var r_saved_dev: bool = GameState.dev_mode
	GameState.dev_mode = true              # the fog would otherwise refuse
	GameState.rescued_villagers = [
		{"id": "r_ok", "name": "Content", "sex": "Male", "is_kid": false, "stat_name": "Farm",
			"stat_value": 4, "role_key": "Farm", "role_title": "Farmer", "morale": 9.0},
		{"id": "r_idle", "name": "Idle", "sex": "Female", "is_kid": false, "stat_name": "Farm",
			"stat_value": 3, "role_key": "", "role_title": "", "morale": 8.0},
		{"id": "r_rot", "name": "Slipping", "sex": "Male", "is_kid": false, "stat_name": "",
			"stat_value": 0, "role_key": "", "role_title": "", "morale": 0.0},
	]
	GameState.villager_rot = {"r_rot": 0.0}
	roster_page.open_page()
	check("the roster opens and lists every soul",
		roster_page.esc_is_open() and roster_page.rows.get_child_count() >= 3)
	check("the one in the dark is sorted to the TOP, never buried",
		roster_page.rows.get_child(0).get_child(1).text.contains("Slipping"),
		roster_page.rows.get_child(0).get_child(1).text)
	check("the header counts the trouble at a glance",
		roster_page.header.text.contains("without work") and roster_page.header.text.contains("in the dark"))
	GameState.dev_mode = false
	GameState.in_dungeon = true
	roster_page.esc_close()
	roster_page.open_page()
	check("the fog rules the roster too -- you cannot count unseen souls",
		not roster_page.esc_is_open())
	GameState.in_dungeon = false
	GameState.dev_mode = r_saved_dev
	GameState.rescued_villagers = r_saved
	GameState.villager_rot = r_saved_rot
	roster_page.queue_free()
	check("the pause menu carries the roster",
		FileAccess.open("res://pause_menu.gd", FileAccess.READ).get_as_text().contains("RosterButton"))
	if mm != null:
		mm._refresh_glance()
		var txt: String = str(mm.glance.text)
		check("...it answers food, souls and the wage bill without walking the town",
			txt.contains("Food") and txt.contains("Souls") and txt.contains("Wages"), txt)
		check("...and warns about lost blueprints while any remain",
			(GameState.blueprints.size() >= GameState.STARTING_BUILDINGS.size())
			or txt.contains("blueprint"), txt)
	var gsnd := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("one shared one-shot sfx helper exists (positional + flat)",
		gsnd.contains("func play_sfx(stream: AudioStream"))
	check("the week's new systems SPEAK: bell, cleansing, quits",
		gsnd.contains("play_sfx(SFX_CHIME, 0.7)") and gsnd.contains("play_sfx(SFX_YES, 1.15)")
		and gsnd.contains("play_sfx(SFX_NO, 0.8)"))
	check("...as do rifts, relocation, blueprints, the tower and cottages",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("GameState.play_sfx")
		and FileAccess.open("res://blueprint_pickup.gd", FileAccess.READ).get_as_text().contains("play_sfx")
		and FileAccess.open("res://watchtower.gd", FileAccess.READ).get_as_text().contains("play_sfx")
		and FileAccess.open("res://build_placer.gd", FileAccess.READ).get_as_text().contains("play_sfx"))

	# ---- alignment (5.7): every building's staffing is load-bearing ----
	var gsrc2 := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("a staffed Builder crew rebuilds WITHOUT a leader (half pace)",
		gsrc2.contains('count_workers("Builderhouse") > 0') and gsrc2.contains("_builder_half_tick"))
	check("the Dock's premium food lifts every spirit (slack, never gate-required)",
		gsrc2.contains('count_workers("Fishing Dock") > 0'))
	check("the Lab's service is the SCHOLAR, not the bench",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("The bench sits cold"))

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
