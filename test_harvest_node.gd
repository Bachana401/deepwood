extends Node

# THE HARVEST (GAME_BIBLE 9) -- the turn, the Devourer's fuel, the Ten's lanes,
# and the Shadow Army. The finale's spine, held to canon.

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

	# ---------------- the turn (9.3): everyone but the Ten ----------------
	var saved_roster: Array = GameState.rescued_villagers
	var saved_harvested: Array = GameState.harvested_villagers
	var saved_done: bool = GameState.harvest_done
	GameState.harvest_done = false
	GameState.harvested_villagers = []
	GameState.rescued_villagers = [
		{"id": "hv_farmer", "name": "Pel", "sex": "Male", "is_kid": false, "stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": "", "paired": false},
		{"id": "hv_kid", "name": "Nia", "sex": "Female", "is_kid": true, "stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false},
		{"id": "ten_brannoc", "name": "Brannoc, the Wall That Stood", "sex": "Male", "is_kid": false, "stat_name": "Legend", "stat_value": 10, "role_key": "", "role_title": "", "paired": false, "unbreakable": true},
	]
	GameState.begin_harvest()
	check("the whole town turns at once...", GameState.harvested_villagers.size() == 2)
	check("...farmers AND children -- no survivors, no holdouts",
		GameState.harvested_villagers.any(func(v): return v.get("is_kid", false)))
	check("...EXCEPT the Ten, whose hope not even this can kill",
		GameState.rescued_villagers.size() == 1
		and GameState.rescued_villagers[0].get("unbreakable", false))
	check("the harvest fires exactly once", GameState.harvest_done)
	var before := GameState.harvested_villagers.size()
	GameState.begin_harvest()
	check("...and never twice", GameState.harvested_villagers.size() == before)

	# ---------------- the Shadow Army (9.6): themselves, continued ----------------
	GameState.raise_shadow_army()
	check("every fallen villager rises", GameState.rescued_villagers.size() == 3)
	var pel = GameState.find_villager_by_id("hv_farmer")
	check("...as a SHADOW of themselves -- same name, same self",
		pel.get("shadow", false) and str(pel.get("name", "")) == "Pel")
	check("...while the Ten remain flesh among the shadows",
		not GameState.find_villager_by_id("ten_brannoc").get("shadow", false))
	check("the harvest pool empties into the town", GameState.harvested_villagers.is_empty())

	# ---------------- the Devourer machinery (9.4) ----------------
	var di := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the town streams in as waves, never all at once",
		di.contains("HARVEST_WAVE_GAP") and di.contains("HARVEST_LIVE_CAP"))
	check("every transformed wears a villager's NAME", di.contains("_spawn_transformed"))
	check("the Devourer starts WEAK -- power must be eaten",
		di.contains("attack_damage * 0.5"))
	check("he eats the LIVING transformed on a clock", di.contains("DEVOUR_INTERVAL"))
	check("+1 tier per 5%% consumed, ~20 tiers", di.contains("DEVOUR_TIERS := 20"))
	check("the Ten hold lanes as allies", di.contains("_spawn_ten_ally") and ResourceLoader.exists("res://ten_ally.gd"))
	# a legend cannot be killed at the Harvest -- beaten down, they fall back
	var ally = load("res://ten_ally.gd").new()
	ally.ten_id = "ten_brannoc"
	get_tree().root.add_child(ally)
	await get_tree().process_frame
	ally.take_damage(99999)
	check("a legend at 0 falls BACK, never dies",
		is_instance_valid(ally) and ally._fallback_until > 0.0)
	ally.queue_free()
	# victory raises the army
	check("victory's first royal act is the Shadow Army", di.contains("raise_shadow_army"))
	# the reveal now carries the courteous two-monarchs beat (9.2)
	var st := FileAccess.open("res://story.gd", FileAccess.READ).get_as_text()
	check("the shiver carries the two-monarchs exchange",
		st.contains("stood like a king"))
	# harvest state survives the save
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the harvest survives save/load",
		gs.contains('"harvest_done": harvest_done') and gs.contains('"harvested_villagers": harvested_villagers'))

	# ---- the Shadow Court (GAME_BIBLE 11) ----
	var saved_despair: bool = GameState.despair_dead
	var saved_hours: float = GameState.hours_until_next_siege
	# "sieges are over -- Despair is dead": a dead Despair schedules nothing
	GameState.despair_dead = true
	GameState.hours_until_next_siege = 0.5
	GameState.tick_sieges(9999.0)
	check("Despair dead: the siege clock stops forever",
		GameState.hours_until_next_siege == 0.5)
	# a quit during the ending dialogue still owes the village its army --
	# settled the next time the player stands at home
	GameState.harvested_villagers = [{"name": "Owed Soul"}]
	var before_roster: int = GameState.rescued_villagers.size()
	GameState.settle_shadow_court()
	check("an interrupted coronation is settled at home",
		GameState.harvested_villagers.is_empty()
		and GameState.rescued_villagers.size() == before_roster + 1
		and bool(GameState.rescued_villagers[-1].get("shadow", false)))
	# ...but NEVER fires mid-Harvest (despair_dead is only set at victory)
	GameState.despair_dead = false
	GameState.harvested_villagers = [{"name": "Still Taken"}]
	GameState.settle_shadow_court()
	check("the court never settles while the Harvest still rages",
		GameState.harvested_villagers.size() == 1)
	check("despair_dead is set at the final victory", di.contains("GameState.despair_dead = true"))
	check("despair_dead survives the save",
		gs.contains('"despair_dead": despair_dead'))
	var sm := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the siege banner becomes the quiet-nights line",
		sm.contains("Despair is dead"))
	GameState.despair_dead = saved_despair
	GameState.hours_until_next_siege = saved_hours

	# ---- NG+: THE REWOUND HOUR (GAME_BIBLE 11) ----
	var hd: Dictionary = Inventory.get_item_def("relic_rewound_hour")
	check("the spoil exists: mythic consumable, one per world",
		hd.get("category", "") == "consumable"
		and Inventory.get_grade("relic_rewound_hour") == "mythic"
		and int(hd.get("max_stack", 0)) == 1
		and bool(hd.get("use_effect", {}).get("rewind_world", false)))
	# the pure turn: paint a veteran in a spent world, rewind, and check both
	# halves -- the character carried, the world unhappened
	var k_level: int = GameState.player_level
	var k_xp: int = GameState.player_xp
	var k_points: int = GameState.skill_points
	var k_class: String = GameState.chosen_class
	var k_skills = GameState.unlocked_skills.duplicate(true)
	var k_research = GameState.researched_materials.duplicate(true)
	var k_equip = GameState.equipment.duplicate(true)
	var k_stage: int = GameState.monarch_stage_announced
	var k_cycles: int = GameState.ng_plus_cycles
	GameState.player_level = 77
	GameState.chosen_class = "Mage"
	GameState.unlocked_skills = ["probe_skill"]
	GameState.ng_plus_cycles = 0
	GameState.the_ten["ten_brannoc"] = {"freed": true}
	GameState.harvest_done = true
	GameState.despair_dead = true
	GameState.seen_orin_arrival = true
	GameState.rewind_world_keep_player()
	check("the turn keeps YOU: level, class, skills",
		GameState.player_level == 77 and GameState.chosen_class == "Mage"
		and GameState.unlocked_skills == ["probe_skill"])
	check("the turn counts the worlds walked", GameState.ng_plus_cycles == 1)
	check("the turn rewinds the WORLD: Ten caged, Harvest unhappened, Despair alive, story fresh",
		GameState.count_ten_freed() == 0 and not GameState.harvest_done
		and not GameState.despair_dead and not GameState.seen_orin_arrival)
	check("the rewound player wakes to a full siege clock",
		GameState.hours_until_next_siege == GameState.SIEGE_FIRST_HOURS)
	check("the arrival is stamped exactly once", GameState.just_rewound)
	GameState.just_rewound = false
	GameState.player_level = k_level
	GameState.player_xp = k_xp
	GameState.skill_points = k_points
	GameState.chosen_class = k_class
	GameState.unlocked_skills = k_skills
	GameState.researched_materials = k_research
	GameState.equipment = k_equip
	GameState.monarch_stage_announced = k_stage
	GameState.ng_plus_cycles = k_cycles
	# the ceremony and its wiring
	var pl := FileAccess.open("res://player.gd", FileAccess.READ).get_as_text()
	check("two uses to end a world, never one",
		pl.contains("_rewind_armed_until") and pl.contains("GameState.new_game_plus(self)"))
	check("the ceremony saves the carried life and reloads home",
		gs.contains("func new_game_plus") and gs.contains("save_game(player)")
		and gs.contains("pending_load = true"))
	check("victory grants the hourglass -- once per world",
		di.contains('add_item("relic_rewound_hour"')
		and di.contains('get_count("relic_rewound_hour") == 0'))
	check("the worlds-walked count survives the save",
		gs.contains('"ng_plus_cycles": ng_plus_cycles'))

	# ---- THE CHRONICLE (GAME_BIBLE 11): the 100% ledger ----
	var book: Array = GameState.chronicle()
	check("the Chronicle holds the seven canon lines", book.size() == 7)
	var shaped := true
	for row in book:
		if not (row.has("line") and row.has("done") and row.has("detail")):
			shaped = false
	check("every line carries deed, verdict and tally", shaped)
	check("the Ten's line reads the live cages",
		str(book[2].get("line", "")) == "The Ten walk free"
		and bool(book[2].get("done", true)) == GameState.all_ten_freed())
	var was_despair: bool = GameState.despair_dead
	GameState.despair_dead = true
	check("Despair's line turns with the kill",
		bool(GameState.chronicle()[5].get("done", false)))
	GameState.despair_dead = was_despair
	check("the gate and the book weigh the same stones",
		gs.contains("count_ruined_buildings()") and gs.contains("count_empty_role_slots()")
		and gs.count("count_ruined_buildings()") >= 2)
	check("the closed book survives the save",
		gs.contains('"seen_chronicle_100": seen_chronicle_100'))
	check("the closing is a one-shot",
		gs.contains("if seen_chronicle_100:") and gs.contains("seen_chronicle_100 = true"))
	var pm := FileAccess.open("res://pause_menu.gd", FileAccess.READ).get_as_text()
	check("the pause menu carries the book into both scenes",
		pm.contains("ChronicleButton") and pm.contains("GameState.chronicle()"))

	# restore
	GameState.rescued_villagers = saved_roster
	GameState.harvested_villagers = saved_harvested
	GameState.harvest_done = saved_done
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
