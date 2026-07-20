extends Node

# THE SORROW-CRYSTAL (GAME_BIBLE 4.2a) + THE ARRIVAL (2.4.1 beats 1-2).
# The taken are frozen to a draining crystal: its guard must fall, its
# shattering frees them, and what they can do stays WRAPPED until they
# thaw at home. And the player's first fight is in company -- the trio's
# battle at the gate, then the trap explained.

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

	var saved_roster: Array = GameState.rescued_villagers.duplicate()

	# ---- the crystal: guard gate, shatter, wrapped stats ----
	var hostage = load("res://villager.tscn").instantiate()
	hostage.villager_id = "cr_test_soul"
	hostage.villager_name = "Frozen Aldo"
	hostage.stat_name = "Financist"
	hostage.stat_value = 5
	hostage.role_key = ""
	hostage.role_title = ""
	get_tree().root.add_child(hostage)
	await get_tree().process_frame
	check("the shell is a crystal, not a cage",
		hostage.crystal != null and is_instance_valid(hostage.crystal))
	var guard := Node2D.new()
	guard.add_to_group("dungeon_combatant")
	get_tree().root.add_child(guard)
	guard.global_position = hostage.global_position + Vector2(120, 0)
	hostage.rescue()
	check("the shackle HOLDS while the pocket's guard still stands",
		not hostage.is_rescued and not GameState.is_villager_rescued("cr_test_soul"))
	guard.queue_free()
	await get_tree().process_frame
	hostage.rescue()
	check("clear the pocket and the crystal shatters -- they are free",
		hostage.is_rescued and GameState.is_villager_rescued("cr_test_soul"))
	var freed: Dictionary = {}
	for v in GameState.rescued_villagers:
		if str(v.get("id", "")) == "cr_test_soul":
			freed = v
	check("what they can do stays WRAPPED (stats hidden until home)",
		bool(freed.get("stats_hidden", false)))
	var vsrc := FileAccess.open("res://villager.gd", FileAccess.READ).get_as_text()
	check("the rescue toast keeps the gift wrapped",
		vsrc.contains("you'll learn when they're home"))
	var msrc := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("the THAW happens at home: reveal + Log line",
		msrc.contains('villager.erase("stats_hidden")') and msrc.contains("thawed at home"))
	check("the hover keeps the secret meanwhile",
		FileAccess.open("res://npc.gd", FileAccess.READ).get_as_text().contains("still thawing"))
	check("the material the crystal should also pay is FLAGGED, not invented",
		vsrc.contains("12-open"))
	if is_instance_valid(hostage):
		hostage.queue_free()

	# ---- the arrival (2.4.1) ----
	var st := FileAccess.open("res://story.gd", FileAccess.READ).get_as_text()
	check("the trio explains the trap in their own voices",
		st.contains("ARRIVAL_TRAP") and st.contains("It's not a siege. It's a cage.")
		and st.contains("Down. Through the root of it."))
	check("the plea flows INTO the battle (opening's callback)",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("begin_arrival_battle"))
	check("the first fight is in company at the west gate",
		msrc.contains("func begin_arrival_battle") and msrc.contains("the trio is ALREADY in the fight"))
	check("the wave breaking triggers the trap dialogue, once",
		msrc.contains("_on_arrival_raider_died") and msrc.contains("Story.ARRIVAL_TRAP"))
	var gsrc := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the arrival is one-shot, saved, and OLD saves never replay it",
		gsrc.contains('"seen_arrival_battle": seen_arrival_battle')
		and gsrc.contains('parsed.get("seen_arrival_battle", true)'))
	# nobody dies in the teaching wave -- Roland especially (12.6: he is the
	# eleventh ally at the gate of 100, and losing him at minute one would
	# quietly break that beat forever)
	check("the trio is shielded FOR THE ARRIVAL ONLY",
		FileAccess.open("res://adventurer.gd", FileAccess.READ).get_as_text().contains("GameState.arrival_battle_active")
		and msrc.contains("arrival_battle_active = true")
		and msrc.contains("arrival_battle_active = false"))
	check("...and the shield is transient, never saved (a real siege still kills)",
		not gsrc.contains('"arrival_battle_active"'))
	var adv_shield := get_tree().get_nodes_in_group("adventurer")
	if not adv_shield.is_empty():
		var a0 = adv_shield[0]
		var st0: Dictionary = GameState.adventurer_state(str(a0.adventurer_id))
		var hp_before: float = float(st0.get("hp", 100.0))
		GameState.arrival_battle_active = true
		a0.take_damage(9999)
		check("a live blow in the arrival cannot even scratch them",
			not a0.is_dead
			and float(GameState.adventurer_state(str(a0.adventurer_id)).get("hp", 100.0)) == hp_before)
		GameState.arrival_battle_active = false

	# ---- the road out, testable (12.7, decided delegated) ----
	var mn2 := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("the first attempt stays the scripted near-death",
		mn2.contains("GameState.escape_attempts <= 1") and mn2.contains("barely crawl back"))
	check("every retry answers in DOUBLING numbers, capped",
		mn2.contains("4 * int(pow(2.0") and mn2.contains("mini(") and mn2.contains("24)"))
	check("clearing the wave teaches the lesson -- the road already doubled",
		mn2.contains("already DOUBLED"))
	check("once Despair is dead, the roads are roads again",
		mn2.contains("GameState.game_completed or GameState.despair_dead"))
	check("the attempts survive the save",
		gsrc.contains('"escape_attempts": escape_attempts'))

	GameState.rescued_villagers = saved_roster
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
