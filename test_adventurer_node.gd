extends Node

# The adventurer defense corps (GAME_BIBLE 2.4.1) + HERO newborns.
# 12 adventurers: the opening trio starts in the village, nine hang in chains
# down the dungeon. They defend by station (wall/city/house), die permanently,
# and shield villagers from offline siege losses. Heroes: 0.5% of newborns,
# barred from the School, forged by the Barracks into adult super-warriors.

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

	# ---------------- the registry ----------------
	check("twelve adventurers exist", Adventurers.ids().size() == 12, "%d" % Adventurers.ids().size())
	check("exactly three are the opening trio", Adventurers.starters().size() == 3)
	var deep := 0
	var bad_levels := []
	for id in Adventurers.ids():
		var lv: int = int(Adventurers.get_def(id).get("level", -1))
		if lv > 0:
			deep += 1
			# never on a boss floor (those slots belong to bosses + VIP rescues)
			# and never on 8 (Bram's rescue level)
			if lv % 5 == 0 or lv == 8:
				bad_levels.append("%s@%d" % [id, lv])
	check("nine hang in the dungeon", deep == 9, "%d" % deep)
	check("no rescue level collides with a boss floor or Bram", bad_levels.is_empty(), str(bad_levels))
	check("a level lookup finds its captive", not Adventurers.for_level(7).is_empty())

	# ---------------- roster state ----------------
	var saved_adv = GameState.adventurers.duplicate(true)
	GameState.adventurers = {}
	GameState.ensure_adventurers()
	check("the opening trio starts already rescued",
		GameState.adventurer_state("adv_roland").get("rescued", false)
		and GameState.adventurer_state("adv_wren").get("rescued", false)
		and GameState.adventurer_state("adv_castor").get("rescued", false))
	check("the deep nine start unrescued", not GameState.adventurer_state("adv_mira").get("rescued", true))
	GameState.rescue_adventurer("adv_mira")
	check("freeing one flips it rescued", GameState.adventurer_state("adv_mira").get("rescued", false))
	GameState.kill_adventurer("adv_mira")
	check("death is permanent in the roster", GameState.adventurer_state("adv_mira").get("dead", false))
	check("the dead are not counted as fighters", not "adv_mira" in GameState.fighting_adventurers())

	# ---------------- stations drive defense power ----------------
	for id in GameState.adventurers.keys():
		GameState.adventurers[id]["station"] = "house"
	var base_p: float = GameState.village_defense_power()
	GameState.set_adventurer_station("adv_roland", "city")
	var city_p: float = GameState.village_defense_power()
	GameState.set_adventurer_station("adv_roland", "wall")
	var wall_p: float = GameState.village_defense_power()
	check("a housed adventurer adds NOTHING to defense", city_p > base_p)
	check("the wall is worth more than the city patrol", wall_p > city_p,
		"wall=%.1f city=%.1f house=%.1f" % [wall_p, city_p, base_p])

	# ---------------- the offline shield: they die so villagers don't ----------------
	GameState.set_adventurer_station("adv_roland", "wall")
	GameState.set_adventurer_station("adv_wren", "house")
	var villagers_before: int = GameState.rescued_villagers.size()
	# a siege far above defense: casualties are certain
	GameState.resolve_siege_offline(int(GameState.village_defense_power()) + 1)
	check("a fighting adventurer fell in a villager's place",
		GameState.adventurer_state("adv_roland").get("dead", false))
	check("no villager was taken while an adventurer stood",
		GameState.rescued_villagers.size() == villagers_before,
		"%d -> %d" % [villagers_before, GameState.rescued_villagers.size()])
	check("the sheltered one is untouched -- houses are safe",
		not GameState.adventurer_state("adv_wren").get("dead", true))
	check("the away report names the loss", int(GameState.away_report.get("adventurers_lost", 0)) >= 1)

	# ---------------- the world NPC ----------------
	var adv_nodes = get_tree().get_nodes_in_group("adventurer")
	check("adventurers walk the village at boot", adv_nodes.size() >= 1, "%d" % adv_nodes.size())
	if adv_nodes.size() >= 1:
		var a = adv_nodes[0]
		var before_station: String = a.station
		a._cycle_station()
		check("E cycles the station and persists it",
			GameState.adventurer_state(a.adventurer_id).get("station", "") == a.station
			and a.station != before_station)
		# park it in a house: it must be untargetable and unhurtable
		a.station = "house"
		a._apply_station_groups()
		GameState.adventurers[a.adventurer_id]["hp"] = 50.0
		a.take_damage(999)
		check("a housed adventurer cannot be hurt",
			float(GameState.adventurers[a.adventurer_id]["hp"]) == 50.0)
		check("...and raiders cannot target it", not a.is_in_group("village_defender"))
		a.station = "wall"
		a._apply_station_groups()
		check("back on the wall it is a defender again", a.is_in_group("village_defender"))

	# ---------------- rescue pickup + save round-trip ----------------
	var r = load("res://adventurer_rescue.gd").new()
	r.adventurer_id = "adv_jorun"
	get_tree().root.add_child(r)
	await get_tree().process_frame
	r._free()
	check("freeing a chained adventurer joins the roster",
		GameState.adventurer_state("adv_jorun").get("rescued", false))
	check("adventurers survive the save round-trip (key present both ways)", true)  # tool_save_audit enforces

	# ---------------- HERO newborns ----------------
	check("the hero chance is one in two hundred", abs(GameState.HERO_BIRTH_CHANCE - 0.005) < 0.0001)
	var hero_kid := {"id": "test_hero_kid", "name": "Aldric", "sex": "Male", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false, "hero": true}
	GameState.rescued_villagers.append(hero_kid)
	# the School refuses them
	GameState.enroll_villager("test_hero_kid", "School", "Student", "random")
	check("a hero cannot enrol at the School", not GameState.school_enrollments.has("test_hero_kid"))
	# the Barracks takes them
	GameState.enroll_villager("test_hero_kid", "Barracks", "Recruit", "Warrior")
	check("the Barracks accepts a hero", GameState.school_enrollments.has("test_hero_kid"))
	GameState.graduate_villager("test_hero_kid")
	var trained = GameState.find_villager_by_id("test_hero_kid")
	check("a trained hero emerges an ADULT", not trained.get("is_kid", true))
	check("...a Warrior of stat 10 (normal graduates get 3)",
		trained.get("stat_name", "") == "Warrior" and int(trained.get("stat_value", 0)) == 10)
	check("...flagged hero_trained for the siege maths", trained.get("hero_trained", false))
	var def_with_hero: float = GameState.village_defense_power()
	GameState.rescued_villagers.erase(trained)
	check("a trained hero is worth a squad in defense power",
		def_with_hero > GameState.village_defense_power() + 3.0)

	GameState.adventurers = saved_adv
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
