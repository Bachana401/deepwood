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
	# THE VENUE MOVED (canon rework 2026-07-20): the Harvest is fought AT HOME.
	# The fight machinery lives in harvest_director.gd now; the dungeon's floor
	# 100 is the EMPTY THRONE that sets the false victory in motion.
	var di := FileAccess.open("res://harvest_director.gd", FileAccess.READ).get_as_text()
	var dgn := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("floor 100 stands EMPTY in a real run (the trap's final move)",
		dgn.contains("seen_empty_throne = true") and dgn.contains("the deep is SILENT"))
	check("the false victory -> feast -> reveal chain exists at home",
		di.contains("begin_false_victory") and di.contains("FEAST_SECONDS")
		and di.contains("Story.REVEAL_AT_FEAST"))
	check("the feast fires only when the deep is TRULY empty (Ten included)",
		FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains("func deep_truly_empty")
		and FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains("highest_unlocked_level >= 100 and all_ten_freed()"))
	check("the village mounts the director when the feast is ready",
		FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("GameState.feast_ready()"))
	check("nobody descends mid-Harvest (you cannot run from this)",
		FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("GameState.harvest_at_home"))
	check("the town streams in as waves, never all at once",
		di.contains("HARVEST_WAVE_GAP") and di.contains("HARVEST_LIVE_CAP"))
	check("every transformed wears a villager's NAME", di.contains("_spawn_transformed"))
	check("the Devourer starts WEAK -- power must be eaten",
		di.contains("damage_multiplier *= 0.25"))
	check("he eats the LIVING transformed on a clock", di.contains("DEVOUR_INTERVAL"))
	check("+1 tier per 5%% consumed, ~20 tiers", di.contains("DEVOUR_TIERS := 20"))
	check("the Ten hold lanes as allies", di.contains("_spawn_ally") and ResourceLoader.exists("res://ten_ally.gd"))
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
	check("the Rewound Hour offers a real turn-or-shatter choice, never a misclick",
		pl.contains("_open_hourglass_choice") and pl.contains("GameState.new_game_plus(self)")
		and pl.contains("GameState.break_the_cycle") and ResourceLoader.exists("res://choice_prompt.gd"))
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
	# ...AND THE BOOK MUST FIT ON THE SCREEN. It used to hang at a fixed offset
	# from the pause panel, so re-centring that panel silently pushed its right
	# edge to 1246 in a 1152-wide UI and cut the last lines off mid-word. Nobody
	# noticed until it was rendered. Placed from the screen now -- assert that.
	var live_pm: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("pause_menu.gd"):
			live_pm = n
			break
	if live_pm != null and live_pm.chron_panel != null:
		var ui_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
		var ui_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
		var left: float = live_pm.get_node("Panel").offset_left + live_pm.chron_panel.position.x
		var top: float = live_pm.get_node("Panel").offset_top + live_pm.chron_panel.position.y
		check("the Chronicle fits on the screen, whatever the menu does",
			left >= 0.0 and left + live_pm.chron_panel.size.x <= ui_w
			and top >= 0.0 and top + live_pm.chron_panel.size.y <= ui_h,
			"spans %.0f..%.0f x %.0f..%.0f in %.0fx%.0f" % [
				left, left + live_pm.chron_panel.size.x,
				top, top + live_pm.chron_panel.size.y, ui_w, ui_h])

	# ---- the softlock guard: the wand returns AT THE FEAST ----
	check("the reveal hands the wand back if you left it behind",
		di.contains('get_count("wpn_soulsplit") == 0')
		and di.contains('add_item("wpn_soulsplit", 1)'))
	check("...and says WHY, in Elenwe's voice",
		di.contains("An undivided soul cannot be destroyed"))

	# ---- the defenders' fate (12.6, decided delegated) ----
	check("Wren and Castor walk in the horde, and their deaths are real",
		di.contains('for aid in ["adv_wren", "adv_castor"]')
		and di.contains("walks in the horde"))
	check("Roland alone holds -- the eleventh, mortal, standing anyway",
		di.contains('_spawn_ally("", "Roland")') and di.contains("We hold. Same as always."))
	var ta := FileAccess.open("res://ten_ally.gd", FileAccess.READ).get_as_text()
	check("the ally body carries a mortal's name and scale",
		ta.contains("var override_name") and ta.contains("power_scale"))

	# restore
	GameState.rescued_villagers = saved_roster
	GameState.harvested_villagers = saved_harvested
	GameState.harvest_done = saved_done
	# ================================================================
	# THE NEW FINALE, WALKED LIVE (canon rework 2026-07-20): empty throne
	# -> false victory -> feast -> reveal -> the Harvest in the STREETS ->
	# the kill -> the return -> the Shadow Army. In the real village scene.
	# ================================================================
	var was_completed: bool = GameState.game_completed
	GameState.reset_for_new_game()
	# the dev's machine may carry the LIFETIME completion unlock -- baseline it
	# off so the victory chain is actually observable (restored below)
	GameState.game_completed = false
	GameState.highest_unlocked_level = 100
	for tid in TheTen.ids():
		GameState.free_one_of_the_ten(tid)
	for i in range(4):
		GameState.rescue_villager({"id": "feast_%d" % i, "name": "Feastgoer %d" % i,
			"sex": "Male", "is_kid": false, "stat_name": "Farm", "stat_value": 3,
			"role_key": "", "role_title": ""})
	GameState.seen_empty_throne = true
	check("LIVE: the feast is ready when the deep is truly empty", GameState.feast_ready())
	var main_scene = get_tree().current_scene
	var director = preload("res://harvest_director.gd").new()
	main_scene.add_child(director)
	# drive the dialogue chain through. NB the feast interlude is a REAL-time
	# timer and headless frames run uncapped, so wait in wall-clock slices --
	# and once the glow is up, call the reveal directly (the double-trigger
	# guard makes the later real timer a no-op).
	var guard := 0
	while guard < 120 and not director._fight_on:
		guard += 1
		await get_tree().create_timer(0.15).timeout
		if GameState.feast_glow and not director._revealed:
			director.begin_reveal()
		if get_tree().paused:
			for n in get_tree().root.find_children("*", "", true, false):
				if n.has_method("finish") and n.has_method("show_line"):
					n.finish()
					break
	check("LIVE: the fight begins in the village", director._fight_on, "after %d frames" % guard)
	check("LIVE: the Monarch stands in the streets",
		director._monarch != null and is_instance_valid(director._monarch))
	check("LIVE: the town turned -- only the unbreakable remain",
		GameState.rescued_villagers.size() == 10 and GameState.harvested_villagers.size() >= 4)
	check("LIVE: the feast glow died with the reveal", not GameState.feast_glow)
	check("LIVE: the wand is in hand at the only fight that needs it",
		p.inventory.get_count("wpn_soulsplit") > 0)
	for i in range(240):
		await get_tree().physics_frame
		if not get_tree().get_nodes_in_group("transformed").is_empty():
			break
	check("LIVE: the transformed stream into their own streets",
		not get_tree().get_nodes_in_group("transformed").is_empty())
	check("LIVE: the deep is sealed mid-Harvest", GameState.harvest_at_home)
	# the kill (the wand window is boss.gd's own tested machinery -- here we
	# fell the monarch directly to walk the VICTORY chain)
	director._monarch.is_dead = true
	guard = 0
	while guard < 120 and not GameState.despair_dead:
		guard += 1
		await get_tree().create_timer(0.15).timeout
		if get_tree().paused:
			for n in get_tree().root.find_children("*", "", true, false):
				if n.has_method("finish") and n.has_method("show_line"):
					n.finish()
					break
	check("LIVE: victory marks the game complete", GameState.game_completed)
	check("LIVE: Despair is dead -- the nights are over", GameState.despair_dead)
	# let the ENDING's on_finished (shadow army + spoils) settle
	guard = 0
	while guard < 60 and GameState.harvest_at_home:
		guard += 1
		await get_tree().create_timer(0.1).timeout
		if get_tree().paused:
			for n in get_tree().root.find_children("*", "", true, false):
				if n.has_method("finish") and n.has_method("show_line"):
					n.finish()
					break
	for i in range(30):
		await get_tree().process_frame
	var shadows := 0
	for v in GameState.rescued_villagers:
		if v.get("shadow", false):
			shadows += 1
	check("LIVE: the Shadow Army raised the fallen as themselves",
		shadows >= 4 and GameState.harvested_villagers.is_empty(),
		"%d shadows" % shadows)
	check("LIVE: the Rewound Hour lies among the spoils",
		p.inventory.get_count("relic_rewound_hour") > 0)
	check("LIVE: the director leaves the stage", not GameState.harvest_at_home)
	# ---- THE RESUME ROAD: a mid-Harvest quit must never strand the world ----
	# paint the exact state a quit leaves behind: harvest done, Despair alive,
	# the turned town saved -- and nothing on stage
	GameState.harvest_done = true
	GameState.despair_dead = false
	GameState.harvest_at_home = false
	GameState.harvested_villagers = [{"id": "res_1", "name": "Lost Soul", "sex": "Male",
		"is_kid": false, "stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}]
	p.inventory.remove_item("wpn_soulsplit", p.inventory.get_count("wpn_soulsplit"))
	main_scene._maybe_begin_feast()
	var res_dir: Node = null
	guard = 0
	while guard < 90 and (res_dir == null or not res_dir._fight_on):
		guard += 1
		await get_tree().create_timer(0.15).timeout
		if res_dir == null:
			for c in main_scene.get_children():
				if c.get_script() != null and str(c.get_script().resource_path).contains("harvest_director"):
					res_dir = c
		if get_tree().paused:
			for n in get_tree().root.find_children("*", "", true, false):
				if n.has_method("finish") and n.has_method("show_line"):
					n.finish()
					break
	check("RESUME: a reloaded half-turned world re-stages the fight",
		res_dir != null and res_dir._fight_on)
	check("RESUME: Orin returns to finish what he started",
		res_dir != null and res_dir._monarch != null and is_instance_valid(res_dir._monarch))
	check("RESUME: the wand guard holds on this road too",
		p.inventory.get_count("wpn_soulsplit") > 0)
	if res_dir != null:
		if res_dir._monarch != null and is_instance_valid(res_dir._monarch):
			res_dir._monarch.queue_free()
		res_dir.queue_free()
	GameState.harvest_at_home = false

	# leave no permanent trace: the completion file belongs to the dev's real runs
	if not was_completed:
		GameState.game_completed = false
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.GAME_COMPLETED_PATH))
	else:
		GameState.game_completed = true
	GameState.reset_for_new_game()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
