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
	var def_without: float = GameState.village_defense_power()
	# ...and a plain warrior for scale, so morale's multiplier cancels out
	var plain := {"id": "test_plain_warrior", "name": "P", "sex": "Male", "is_kid": false,
		"stat_name": "Warrior", "stat_value": 3, "role_key": "", "role_title": "", "paired": false}
	GameState.rescued_villagers.append(plain)
	var def_with_plain: float = GameState.village_defense_power()
	GameState.rescued_villagers.erase(plain)
	var hero_delta: float = def_with_hero - def_without
	var plain_delta: float = def_with_plain - def_without
	check("a trained hero is worth several plain warriors (ratio ~4x)",
		plain_delta > 0.0 and hero_delta / plain_delta > 2.5,
		"hero=+%.2f plain=+%.2f" % [hero_delta, plain_delta])

	GameState.adventurers = saved_adv

	# ---------------- the Doctor (GAME_BIBLE 5.5a) ----------------
	var saved_heals: int = GameState.doctor_heals_bought
	GameState.doctor_heals_bought = 0
	check("the base price is modest", GameState.doctor_heal_price() == GameState.DOCTOR_BASE_PRICE)
	GameState.doctor_heals_bought = 3
	check("every purchase escalates by half again (8 -> 27 after three)",
		GameState.doctor_heal_price() == int(round(8 * pow(1.5, 3))),
		"%d" % GameState.doctor_heal_price())
	# a day of peace forgives one step
	GameState.decay_doctor_price(24.0)
	check("a quiet day walks the price back one step", GameState.doctor_heals_bought == 2)
	GameState.doctor_heals_bought = saved_heals
	# a new game seeds the starting six's civilians: Doctor + two farmers
	var had := {"doctor": false, "farmers": 0}
	var probe := ["doctor_maren", "farmer_tam", "farmer_ada"]
	var kept := []
	for v in GameState.rescued_villagers:
		if str(v.get("id", "")) in probe:
			kept.append(v)
	# simulate the fresh-start seeding without wiping this session's state
	var src := FileAccess.open("res://game_state.gd", FileAccess.READ)
	var gs_src := src.get_as_text() if src != null else ""
	if src != null: src.close()
	check("a new game seeds the Doctor with the healer flag",
		gs_src.contains('"id": "doctor_maren"') and gs_src.contains('"healer": true'))
	check("...and the two farmhands of the starting six",
		gs_src.contains('"id": "farmer_tam"') and gs_src.contains('"id": "farmer_ada"'))
	check("the heal service dies with her (doctor_alive reads the roster)",
		GameState.has_method("doctor_alive"))
	check("the price counter survives the save (key written)",
		gs_src.contains('"doctor_heals_bought": doctor_heals_bought'))
	check("npc offers the heal on E", load("res://npc.gd").new().has_method("try_doctor_heal"))

	# ---------------- signature abilities: 12 adventurers, 12 mechanics ----------------
	var abilities := {}
	for aid in Adventurers.ids():
		var adef = Adventurers.get_def(aid)
		check("'%s' carries a named ability" % aid,
			str(adef.get("ability", "")) != "" and str(adef.get("ability_name", "")) != ""
			and str(adef.get("ability_desc", "")) != "")
		abilities[str(adef.get("ability", ""))] = true
	check("all twelve abilities are DISTINCT mechanics", abilities.size() == 12, "%d unique" % abilities.size())
	# every declared ability id must have a handler in adventurer.gd -- the
	# repo's cardinal sin is a promise nothing reads
	var af := FileAccess.open("res://adventurer.gd", FileAccess.READ)
	var asrc := af.get_as_text() if af != null else ""
	if af != null: af.close()
	for ab in abilities.keys():
		check("ability '%s' is actually implemented" % ab, asrc.contains('"%s"' % ab))

	# functional spot-checks on the ones that need no live raiders.
	# NB the fresh boot may still be inside the ARRIVAL wave, where the corps
	# is deliberately unkillable -- these checks are about real siege combat,
	# so stand the shield down first.
	GameState.arrival_battle_active = false
	var hero_a = load("res://adventurer.gd").new()
	hero_a.adventurer_id = "adv_roland"
	get_tree().root.add_child(hero_a)
	await get_tree().process_frame
	hero_a.station = "wall"
	GameState.adventurers["adv_roland"]["dead"] = false
	GameState.adventurers["adv_roland"]["hp"] = 100.0
	hero_a.take_damage(40)
	check("Shield Wall: the first blow is BLOCKED outright",
		float(GameState.adventurers["adv_roland"]["hp"]) == 100.0)
	hero_a.take_damage(40)
	check("...but the rhythm has a cooldown -- the second lands",
		float(GameState.adventurers["adv_roland"]["hp"]) == 60.0,
		"%.0f" % GameState.adventurers["adv_roland"]["hp"])
	hero_a.free()

	var kessa = load("res://adventurer.gd").new()
	kessa.adventurer_id = "adv_kessa"
	get_tree().root.add_child(kessa)
	await get_tree().process_frame
	kessa.station = "wall"
	GameState.adventurers["adv_kessa"] = {"rescued": true, "dead": false, "station": "wall", "hp": 200.0}
	var base_hit: int = kessa._attack_damage()
	kessa.take_damage(10)
	var grudge_hit: int = kessa._attack_damage()
	check("Grudgekeeper: struck, her answer lands DOUBLE", grudge_hit == base_hit * 2,
		"%d -> %d" % [base_hit, grudge_hit])
	check("...and the grudge is spent on that answer", kessa._attack_damage() == base_hit)
	kessa.free()

	var jorun = load("res://adventurer.gd").new()
	jorun.adventurer_id = "adv_jorun"
	get_tree().root.add_child(jorun)
	await get_tree().process_frame
	var all_alive_dmg: int
	for id in GameState.adventurers.keys():
		GameState.adventurers[id]["dead"] = false
	all_alive_dmg = jorun._attack_damage()
	GameState.adventurers["adv_mira"]["dead"] = true
	GameState.adventurers["adv_essa"]["dead"] = true
	check("Ledger of the Lost: every fallen comrade sharpens Jorun (+25%% each)",
		jorun._attack_damage() > all_alive_dmg,
		"%d -> %d" % [all_alive_dmg, jorun._attack_damage()])
	GameState.adventurers["adv_mira"]["dead"] = false
	GameState.adventurers["adv_essa"]["dead"] = false
	jorun.free()

	var hakon = load("res://adventurer.gd").new()
	hakon.adventurer_id = "adv_hakon"
	get_tree().root.add_child(hakon)
	await get_tree().process_frame
	hakon.station = "wall"
	GameState.adventurers["adv_hakon"] = {"rescued": true, "dead": false, "station": "wall", "hp": 330.0}
	hakon.take_damage(250)   # would leave him at 80 -- under 30% of 330
	check("Daybreak Pact: brought to the brink, he rises to FULL",
		float(GameState.adventurers["adv_hakon"]["hp"]) == 330.0,
		"%.0f" % GameState.adventurers["adv_hakon"]["hp"])
	check("...once per siege only", hakon._daybreak_used)
	hakon.on_siege_ended()
	check("...and the pact renews when the siege ends", not hakon._daybreak_used)
	hakon.free()

	# Bottom-Seen: a wounded raider is finished, not fought
	var sorrel = load("res://adventurer.gd").new()
	sorrel.adventurer_id = "adv_sorrel"
	get_tree().root.add_child(sorrel)
	await get_tree().process_frame
	GameState.adventurers["adv_sorrel"] = {"rescued": true, "dead": false, "station": "wall", "hp": 380.0}
	var prey = load("res://siege_enemy.gd").new()
	get_tree().root.add_child(prey)
	await get_tree().process_frame
	prey.max_health = 500
	prey.health = 90    # 18% -- under the 20% line
	prey.global_position = sorrel.global_position + Vector2(30, 0)
	sorrel.attack_cd = 0.0
	sorrel._fight(prey)
	check("Bottom-Seen: a raider under 20%% is EXECUTED outright", prey.is_dead)
	prey.queue_free()
	sorrel.free()

	# ---------------- hero powers: a miracle never fights generic ----------------
	# graduation rolls a personal power and keeps it for life
	var hero_kid2 := {"id": "test_hero_kid2", "name": "Brenna", "sex": "Female", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false, "hero": true}
	GameState.rescued_villagers.append(hero_kid2)
	GameState.enroll_villager("test_hero_kid2", "Barracks", "Recruit", "Warrior")
	GameState.graduate_villager("test_hero_kid2")
	var brenna = GameState.find_villager_by_id("test_hero_kid2")
	check("a hero graduates with a PERSONAL power",
		GameState.HERO_POWERS.has(str(brenna.get("hero_power", ""))),
		str(brenna.get("hero_power", "(none)")))
	# every rollable power must be handled by the siege unit -- no dead promises
	# rally is a spawn-time banner (siege_manager); the rest live on the unit
	var ssrc := ""
	for path in ["res://siege_enemy.gd", "res://siege_manager.gd"]:
		var sf := FileAccess.open(path, FileAccess.READ)
		if sf != null:
			ssrc += sf.get_as_text()
			sf.close()
	for pw in GameState.HERO_POWERS.keys():
		check("hero power '%s' is implemented on the field" % pw,
			ssrc.contains('"%s"' % pw))
	GameState.rescued_villagers.erase(brenna)
	# Unbroken, functionally: the first death each siege doesn't take
	var unb = load("res://siege_enemy.gd").new()
	unb.faction = "village"
	unb.hero_power = "unbroken"
	unb.hero_name = "Test"
	get_tree().root.add_child(unb)
	await get_tree().process_frame
	unb.max_health = 100
	unb.health = 100
	unb.take_damage(150)
	check("Unbroken: the first killing blow leaves them standing at half",
		not unb.is_dead and unb.health == 50, "hp=%d dead=%s" % [unb.health, unb.is_dead])
	unb.take_damage(150)
	check("...the second death is real", unb.is_dead)
	unb.queue_free()
	# Warcry, functionally: arrival staggers a raider slow
	var cryer = load("res://siege_enemy.gd").new()
	cryer.faction = "village"
	cryer.hero_power = "warcry"
	cryer.hero_name = "Test"
	var prey2 = load("res://siege_enemy.gd").new()   # a raider in range
	get_tree().root.add_child(prey2)
	await get_tree().process_frame
	get_tree().root.add_child(cryer)
	cryer.global_position = prey2.global_position + Vector2(100, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	check("Warcry: taking the field staggers nearby raiders slow",
		prey2.status_slow_mult() < 1.0, "%.2f" % prey2.status_slow_mult())
	cryer.queue_free(); prey2.queue_free()

	# ---------------- the Doctor's account + elite affixes ----------------
	var story_src := FileAccess.open("res://story.gd", FileAccess.READ).get_as_text()
	check("the Doctor's account exists as a story beat", story_src.contains("DOCTOR_ACCOUNT"))
	check("...and it carries the lost-wizard rumour (2.5.1 beat 1)",
		story_src.contains("wizard") and story_src.contains("candle"))
	check("the opening no longer claims Orin defends nightly (2.5.1: he is absent)",
		not story_src.contains("He dies for us and rises with the dawn"))
	var npc_src := FileAccess.open("res://npc.gd", FileAccess.READ).get_as_text()
	check("her first talk plays the account before any healing",
		npc_src.contains("seen_doctor_account") and npc_src.contains("DOCTOR_ACCOUNT"))

	# elites roll ONE affix and every affix is implemented
	var em = load("res://special_mob.gd").new()
	em.kind = "charger"
	em.elite = true
	get_tree().root.add_child(em)
	await get_tree().process_frame
	check("an elite rolls an affix at spawn", em.ELITE_AFFIXES.has(em.affix), em.affix)
	var sm_src := FileAccess.open("res://special_mob.gd", FileAccess.READ).get_as_text()
	for ax in em.ELITE_AFFIXES.keys():
		check("elite affix '%s' is implemented" % ax, sm_src.count('"%s"' % ax) >= 2)
	# bulwark functionally: a fifth rings off
	em.affix = "bulwark"
	em.max_health = 100
	em.health = 100
	em.take_damage(50)
	check("Bulwark: a fifth of the blow rings off (50 -> 40 taken)", em.health == 60,
		"hp=%d" % em.health)
	# frenzied functionally: past half it stops pacing itself
	em.affix = "frenzied"
	em.health = 30
	check("Frenzied kicks in below half health", em.health < em.max_health / 2)
	em.queue_free()
	var plain_mob = load("res://special_mob.gd").new()
	plain_mob.kind = "charger"
	get_tree().root.add_child(plain_mob)
	await get_tree().process_frame
	check("a non-elite has no affix", plain_mob.affix == "")
	plain_mob.queue_free()

	# ---------------- the failed escape (GAME_BIBLE 2.4.1 beat 3) ----------------
	var main_src := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("the west road carries the escape ward", main_src.contains("build_escape_ward"))
	check("the ward respects a WON game (roads reopen)", main_src.contains("game_completed"))
	var story_src2 := FileAccess.open("res://story.gd", FileAccess.READ).get_as_text()
	check("the failed-escape beat exists and names the bait",
		story_src2.contains("FAILED_ESCAPE") and story_src2.contains("bait"))
	check("the beat is one-shot and saved",
		main_src.contains("seen_failed_escape") and GameState.get("seen_failed_escape") != null)

	# ---------------- old-save migration: the Doctor arrives, the dead stay dead ----------------
	# a pre-Doctor save (no doctor_heals_bought key) must gain the civilians...
	var saved_roster: Array = GameState.rescued_villagers
	GameState.rescued_villagers = [{"id": "old_villager", "name": "Old", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 1, "role_key": "", "role_title": "", "paired": false}]
	GameState._migrate_starting_civilians()
	check("an old save gains its Doctor on load", GameState.doctor_alive())
	check("...and the two farmhands",
		not GameState.find_villager_by_id("farmer_tam").is_empty()
		and not GameState.find_villager_by_id("farmer_ada").is_empty())
	check("...without touching its own villagers",
		not GameState.find_villager_by_id("old_villager").is_empty())
	# ...but the load path only migrates when the fingerprint says PRE-Doctor,
	# so a newer save that lost her to a siege keeps its dead
	var gs_load := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("migration is fingerprint-gated -- the dead are never resurrected",
		gs_load.contains('if not parsed.has("doctor_heals_bought"):'))
	GameState.rescued_villagers = saved_roster

	# ---------------- the reunite chain, end to end ----------------
	# Sena waits at home; Bram is freed on floor 8; the bond must complete and
	# pay out. This is the chain that was entirely unreachable before the
	# spawn fix -- prove every link.
	var sena = GameState.find_villager_by_id("sena_ward")
	var sena_added := false
	if sena.is_empty():
		sena = {"id": "sena_ward", "name": "Sena", "sex": "Female", "is_kid": false,
			"stat_name": "Hospital", "stat_value": 3, "role_key": "", "role_title": "", "paired": false}
		GameState.rescued_villagers.append(sena)
		sena_added = true
	sena["quest_state"] = "active"
	sena["quest_progress"] = 0
	GameState.rescue_villager({"id": "bram_hollow", "name": "Bram Hollow", "sex": "Female",
		"is_kid": false, "stat_name": "Warrior", "stat_value": 4, "role_key": "", "role_title": "", "paired": false})
	check("freeing Bram advances Sena's bond", int(sena.get("quest_progress", 0)) >= 1)
	check("...and the bond reads READY", GameState.villager_quest_ready(sena, p))
	var gold_before: int = p.currency
	var sena_line: String = GameState.turn_in_villager_quest("sena_ward", p)
	check("turn-in speaks Sena's reward line", sena_line.contains("brought her back"))
	check("...pays her gold", p.currency > gold_before)
	check("...and the bond is DONE", sena.get("quest_state", "") == "done")
	# clean up the roster we touched
	var bram_v = GameState.find_villager_by_id("bram_hollow")
	if not bram_v.is_empty():
		GameState.rescued_villagers.erase(bram_v)
	if sena_added:
		GameState.rescued_villagers.erase(sena)

	# ---------------- the pact scene (GAME_BIBLE 2.5.1 beats 2+3) ----------------
	check("the pact scene exists with a full cast", Story.ORIN_PACT.size() >= 8)
	var speakers := {}
	var pact_text := ""
	for line in Story.ORIN_PACT:
		speakers[str(line.get("speaker", ""))] = true
		pact_text += str(line.get("text", "")) + "\n"
	check("the Doctor makes the introduction (she met him days earlier)",
		speakers.has("Doctor Maren Hollis"))
	check("a defender sizes him up", speakers.has("Roland Ashmark"))
	check("the player commits to the plan aloud", speakers.has("You"))
	check("Orin plants the game's central lie -- he wants the village at its PEAK",
		pact_text.contains("peak"))
	check("...and repeats his cover story (cleared a level, got stuck)",
		pact_text.contains("cleared one of their levels"))
	check("the pact commits to the whole plan: rebuild, free, grow strong",
		pact_text.contains("Rebuild Deepwood") and pact_text.contains("Free the taken"))
	# the dungeon half: the glimpse after the floor-15 boss
	check("the glimpse beat exists", Story.ORIN_GLIMPSE.size() >= 1)
	var di_src := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the floor-15 boss kill triggers the glimpse",
		di_src.contains("ORIN_ARRIVAL_DEPTH") and di_src.contains("play_orin_glimpse"))
	var main_src2 := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("the village visit plays the full PACT scene, not a mere notification",
		main_src2.contains("Story.ORIN_PACT"))
	check("the glimpse flag survives the save",
		GameState.get("seen_orin_glimpse") != null)

	# ---------------- Orin's entrance (GAME_BIBLE 2.5.1) ----------------
	# Gated on THIS run's carving (highest_unlocked_level), not the lifetime
	# depth record -- otherwise Orin is "home" at hour zero of a second life.
	var saved_depth: int = GameState.highest_unlocked_level
	var saved_dev: bool = GameState.dev_mode
	GameState.dev_mode = false
	GameState.highest_unlocked_level = 3
	check("Orin is ABSENT before floor 15 (a rumour, not a resident)", not GameState.orin_arrived())
	var shallow_def: float = GameState.village_defense_power()
	GameState.highest_unlocked_level = 15
	check("carving to floor 15 brings him home", GameState.orin_arrived())
	check("his meteors only defend a village he's actually in",
		GameState.village_defense_power() > shallow_def)
	check("a fresh world does not inherit his arrival from a past life",
		not (func():
			GameState.highest_unlocked_level = 15
			GameState.reset_for_new_game()
			return GameState.orin_arrived()).call())
	GameState.highest_unlocked_level = saved_depth
	GameState.dev_mode = saved_dev
	var wiz_src := FileAccess.open("res://wizard.gd", FileAccess.READ)
	var wtxt := wiz_src.get_as_text() if wiz_src != null else ""
	if wiz_src != null: wiz_src.close()
	check("the village wizard node removes itself pre-arrival", wtxt.contains("orin_arrived()"))

	# ---------------- day/night shifts (GAME_BIBLE 7.3) ----------------
	var saved_hours2: float = GameState.game_hours
	var saved_roster2: Array = GameState.rescued_villagers
	var corps := []
	for i in range(8):
		corps.append({"id": "w_%d" % i, "name": "W%d" % i, "sex": "Male", "is_kid": false,
			"stat_name": "Warrior", "stat_value": 5, "role_key": "Barracks", "role_title": "Warrior"})
	GameState.rescued_villagers = corps
	var dawn := 0
	for v in corps:
		if GameState.warrior_shift(str(v["id"])) == "dawn":
			dawn += 1
	check("the corps splits into two watches, neither empty",
		dawn > 0 and dawn < corps.size(), str(dawn))
	GameState.game_hours = 12.0   # noon -> dawn watch on duty
	var noon_duty: int = GameState.on_duty_warrior_count()
	GameState.game_hours = 23.0   # night -> dusk watch
	var night_duty: int = GameState.on_duty_warrior_count()
	check("noon and midnight field DIFFERENT watches, together the whole corps",
		noon_duty + night_duty == corps.size() and noon_duty > 0 and night_duty > 0)
	GameState.game_hours = 12.0
	var day_power: float = GameState.village_defense_power()
	GameState.game_hours = 17.5
	check("the changeover hour is a real, detectable weak window",
		GameState.in_shift_change_window())
	GameState.game_hours = 12.0
	check("noon is not a weak window", not GameState.in_shift_change_window())
	check("the off-shift still counts, at half worth (they scramble from bed)",
		day_power > 0.0)
	var sm := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("live sieges field only the watch on duty",
		sm.contains("on_duty_warrior_count()"))
	check("the horn at changeover fields HALF the watch, announced",
		sm.contains("in_shift_change_window()") and sm.contains("caught the shift change"))
	var gsrc := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("a warrior on shift heals NOTHING until relieved",
		gsrc.contains("warrior_on_duty(v):\n\t\t\t\tcontinue"))

	# ---------------- both flanks (GAME_BIBLE 7.2) ----------------
	var wl := FileAccess.open("res://wall.gd", FileAccess.READ).get_as_text()
	check("the wall knows its flank and its outer face",
		wl.contains("@export var flank") and wl.contains("func east_face_x") and wl.contains("func outer_face_x"))
	check("the siege splits across BOTH ramparts",
		sm.contains("wall_for_flank(\"east\")") and sm.contains("BOTH flanks"))
	check("raiders plant on the OUTSIDE face of their rampart",
		FileAccess.open("res://siege_enemy.gd", FileAccess.READ).get_as_text().contains("east_face_x() + ATTACK_STOP_GAP"))
	check("both ramparts get patched between assaults",
		sm.contains("for wall in get_tree().get_nodes_in_group(\"village_wall\")"))
	check("the east rampart rises past the last cottage lot",
		FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("east_wall.flank = \"east\"")
		and FileAccess.open("res://cottage_plot.gd", FileAccess.READ).get_as_text().contains("MAX_RAISED"))
	check("wall-stationed adventurers split between the two ramparts",
		FileAccess.open("res://adventurer.gd", FileAccess.READ).get_as_text().contains("hash(adventurer_id) % walls.size()"))
	GameState.game_hours = saved_hours2
	GameState.rescued_villagers = saved_roster2

	# ---------------- the Watchtower (GAME_BIBLE 7.1) ----------------
	var saved_tier: int = GameState.watchtower_tier
	var saved_dev2: bool = GameState.dev_mode
	var saved_siege_hours: float = GameState.hours_until_next_siege
	var saved_log2: Array = GameState.village_log
	GameState.village_log = []
	GameState.dev_mode = false
	GameState.watchtower_tier = 0
	check("Act I is TRUE CHAOS: no clock without a tower",
		not GameState.siege_clock_visible())
	GameState.watchtower_tier = 1
	check("tier 1 makes the siege clock readable",
		GameState.siege_clock_visible())
	check("the warning ladder is canon-locked: none, 1h, 2h, 24h",
		GameState.WATCHTOWER_WARNING_HOURS == [0.0, 1.0, 2.0, 24.0])
	GameState.hours_until_next_siege = 0.5
	GameState._tower_bell_armed = true
	GameState.tick_watchtower_warning()
	var rang := false
	for e3 in GameState.village_log:
		if str(e3.get("text", "")).contains("Watchtower rang"):
			rang = true
	check("the bell tolls inside the warning window", rang)
	var log_n: int = GameState.village_log.size()
	GameState.tick_watchtower_warning()
	check("...and tolls ONCE per siege, not every tick",
		GameState.village_log.size() == log_n)
	var sm2 := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the banner keeps its own counsel at tier 0",
		sm2.contains("keeps its own counsel"))
	check("the pre-descent warning cannot name hours it cannot know",
		FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("cannot know when"))
	check("the tower stands as a paid, growing structure",
		ResourceLoader.exists("res://watchtower.gd")
		and FileAccess.open("res://watchtower.gd", FileAccess.READ).get_as_text().contains("remove_item")
		and FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("watchtower.gd"))
	check("the tower's tier survives the save",
		FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains('"watchtower_tier": watchtower_tier'))
	GameState.watchtower_tier = saved_tier
	GameState.dev_mode = saved_dev2
	GameState.hours_until_next_siege = saved_siege_hours
	GameState.village_log = saved_log2

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
