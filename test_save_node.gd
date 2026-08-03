extends Node

# Save/load round-trip: does the game you saved come back? Data loss is the
# worst polish bug there is, so this writes a distinctive run, reloads it, and
# checks each thing came home.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	# --- write a distinctive run ---
	GameState.player_level = 37
	GameState.player_xp = 111
	GameState.skill_points = 5
	GameState.chosen_class = "Warden"
	GameState.game_hours = 123.5
	GameState.village_food = 42.0
	GameState.barracks_arms = 3
	GameState.highest_unlocked_level = 9
	GameState.equipment["helmet"] = "helm_iron"
	GameState.equipment["chest"] = "armor_bulwark"
	GameState.equipment["pants"] = "pants_bulwark"
	GameState.building_levels["Farm"] = 4
	GameState.rescued_villagers = [{"id": "sv1", "name": "Roundtrip", "sex": "Female", "is_kid": false, "role_key": "Farm"}]
	# THE SLOW CLOCKS (2026-08-03): hours already waited toward something the
	# village is owed. None of these were saved, so every LOAD restarted the wait.
	# The family cycle is the one that bites -- 59 of its 60 hours thrown away
	# means the town is always one reload short of a child, forever, and nothing
	# on screen ever explains why.
	GameState._family_cycle_accum = 59.0
	GameState._mine_accum = 20.0
	GameState._wood_accum = 18.0
	GameState._deep_catch_accum = 12.0
	GameState._tide_table_accum = 50.0
	GameState._doctor_decay_accum = 7.0
	GameState._store_accum = {"wood": 0.75, "stone": 0.5, "iron_shard": 0.25}
	GameState.save_game(p)
	check("save file written", GameState.has_save())

	# --- wipe it the way a fresh boot would ---
	GameState.reset_for_new_game()
	check("reset actually cleared level", GameState.player_level == 1)

	# --- load it back ---
	var parsed = GameState.load_game()
	check("load returned data", parsed is Dictionary and not parsed.is_empty())

	check("level round-trips", GameState.player_level == 37, "got %d" % GameState.player_level)
	check("xp round-trips", GameState.player_xp == 111, "got %d" % GameState.player_xp)
	check("skill points round-trip", GameState.skill_points == 5, "got %d" % GameState.skill_points)
	check("class round-trips", GameState.chosen_class == "Warden", "got '%s'" % GameState.chosen_class)
	check("game clock round-trips", absf(GameState.game_hours - 123.5) < 0.01, "got %.2f" % GameState.game_hours)
	check("food round-trips", absf(GameState.village_food - 42.0) < 0.01, "got %.1f" % GameState.village_food)
	check("barracks arms round-trip", GameState.barracks_arms == 3, "got %d" % GameState.barracks_arms)
	check("dungeon progress round-trips", GameState.highest_unlocked_level == 9, "got %d" % GameState.highest_unlocked_level)
	check("helmet round-trips", GameState.equipment.get("helmet", "") == "helm_iron", str(GameState.equipment))
	check("BREASTPLATE round-trips", GameState.equipment.get("chest", "") == "armor_bulwark", str(GameState.equipment))
	check("LEGGINGS round-trip", GameState.equipment.get("pants", "") == "pants_bulwark", str(GameState.equipment))
	# THE RETIRED-SLOT MIGRATION (Terraria-exact armor, 2026-07-28): a save from
	# the five-slot era with gloves/boots EQUIPPED must hand them back to the
	# bag on load, never delete them
	var pre_gloves: int = p.inventory.get_count("gloves_iron")
	GameState.load_equipment({"helmet": "helm_iron", "gloves": "gloves_iron"})
	check("a five-slot-era save returns worn gloves to the bag",
		p.inventory.get_count("gloves_iron") == pre_gloves + 1)
	check("building level round-trips", int(GameState.building_levels.get("Farm", 0)) == 4,
		str(GameState.building_levels))
	check("the family cycle keeps the hours it already waited",
		absf(GameState._family_cycle_accum - 59.0) < 0.01,
		"got %.2f -- a reload used to reset the wait to zero" % GameState._family_cycle_accum)
	check("the daily yields keep theirs too",
		absf(GameState._mine_accum - 20.0) < 0.01 and absf(GameState._wood_accum - 18.0) < 0.01
		and absf(GameState._deep_catch_accum - 12.0) < 0.01,
		"mine=%.1f wood=%.1f catch=%.1f" % [GameState._mine_accum, GameState._wood_accum, GameState._deep_catch_accum])
	check("...and the Tide Table's longer count",
		absf(GameState._tide_table_accum - 50.0) < 0.01, "got %.1f" % GameState._tide_table_accum)
	check("...and the Doctor's price forgiveness",
		absf(GameState._doctor_decay_accum - 7.0) < 0.01, "got %.1f" % GameState._doctor_decay_accum)
	check("the store's fractional banking survives (small crews earn in fractions)",
		absf(float(GameState._store_accum.get("wood", 0.0)) - 0.75) < 0.01,
		str(GameState._store_accum))
	check("villagers round-trip", GameState.rescued_villagers.size() == 1
		and GameState.rescued_villagers[0].get("name", "") == "Roundtrip",
		str(GameState.rescued_villagers))
	# a loaded run must not explode on a stat query
	check("stats resolve after load", GameState.get_bonus_total("damage_reduction") >= 0.0)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
