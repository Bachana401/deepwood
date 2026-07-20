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

	# restore
	GameState.rescued_villagers = saved_roster
	GameState.harvested_villagers = saved_harvested
	GameState.harvest_done = saved_done
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
