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
	# 2026-07-21 dev rework of the opening: the player walks the road ALONE.
	# The prologue only ARMS the arrival; the defenders and their raiders do not
	# exist until the west rampart is in sight, and the words wait for the fight.
	check("the prologue arms the arrival, it does not stage it",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains("arm_arrival_battle"))
	check("a reload before the wall re-arms the arrival (transient flag survives)",
		msrc.contains("RELOAD GUARD") and msrc.contains("GameState.seen_intro")
		and msrc.contains("not GameState.seen_arrival_battle")
		and msrc.contains("not GameState.arrival_battle_active"))
	check("the approach in sight of the wall triggers the scene",
		msrc.contains("func _check_arrival_trigger") and msrc.contains("ARRIVAL_TRIGGER_DIST")
		and msrc.contains('w.flank == "west"') and msrc.contains("trigger_arrival_scene"))
	# 2026-07-22 dev rework: the fight is STAGED from the first frame so there is no
	# spawn-on-approach pop-in -- the trio + raiders are already at the gate, fighting
	# theatrically, when the player walks up.
	check("the fight is STAGED at game start, already in progress at the gate",
		msrc.contains("func stage_arrival_battle") and msrc.contains("stage_arrival_battle()")
		and msrc.contains("e.theatrical = true") and msrc.contains("wall_x - 620.0"))
	var esrc := FileAccess.open("res://siege_enemy.gd", FileAccess.READ).get_as_text()
	check("a staged raider deals no damage and can't be felled until the scene",
		esrc.contains("var theatrical") and esrc.contains("can't be felled yet")
		and esrc.contains("and not theatrical"))
	check("the approach turns the shadow-fight real: banter, then live",
		msrc.contains("func trigger_arrival_scene") and msrc.contains("Story.HEROES_BANTER")
		and msrc.contains("func activate_arrival_combat") and msrc.contains("e.theatrical = false"))
	# 2026-07-21 dev change: the wave breaking ARMS the walk home; the trap
	# dialogue is DELIVERED when the player crosses the west rampart with the
	# defenders (with a mouth-of-the-dungeon fallback so it can't be skipped)
	check("the words wait for the last raider to fall",
		msrc.contains("_arrival_talk_pending = true")
		and msrc.contains("play_arrival_talk(pl0)"))
	check("the talk fires at the west rampart, beside an adventurer",
		msrc.contains("func _check_arrival_talk") and msrc.contains("Story.ARRIVAL_TRAP")
		and msrc.contains('w.flank == "west"')
		and msrc.contains("get_nodes_in_group(\"adventurer\")"))
	check("diving early can't skip it (the DOOR delivers the talk if still owed)",
		FileAccess.open("res://underdark_door.gd", FileAccess.READ).get_as_text().contains("play_arrival_talk"))
	# THE SCENE HAPPENS AT THE VILLAGE, NEVER IN THE DEEP (dev report 2026-07-21:
	# went down first, killed a mob, and the rescues/trio happened in the dungeon).
	# The road east passes the cave BEFORE the wall, so the descent stays SEALED
	# until the arrival battle is done, and the trigger never fires from below.
	check("the cave is sealed until the arrival is done (the scene is at the gate first)",
		FileAccess.open("res://underdark.gd", FileAccess.READ).get_as_text().contains(
			"not GameState.seen_arrival_battle and not GameState.dev_mode"))
	check("...and the arrival never fires from underground or a dungeon floor",
		msrc.contains("GameState.in_dungeon or pl.global_position.y > 250.0"))
	var gsrc := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the arrival is one-shot, saved, and OLD saves never replay it",
		gsrc.contains('"seen_arrival_battle": seen_arrival_battle')
		and gsrc.contains('parsed.get("seen_arrival_battle", true)'))
	check("...and the delivered TALK survives a mid-walk save separately",
		gsrc.contains('"seen_arrival_talk": seen_arrival_talk')
		and gsrc.contains('parsed.get("seen_arrival_talk", seen_arrival_battle)'))
	# nobody dies in the teaching wave -- Roland especially (12.6: he is the
	# eleventh ally at the gate of 100, and losing him at minute one would
	# quietly break that beat forever)
	# LIVE PLAYTEST FIX (2026-07-21): arrival raiders must fight the PEOPLE
	# in front of them -- wall=null used to silently re-acquire the village
	# wall and march the whole battle 4km east, off-screen
	check("arrival raiders never re-acquire a wall",
		FileAccess.open("res://siege_enemy.gd", FileAccess.READ).get_as_text().contains("wall == null and not arrival_mode"))
	check("...and hunt only the defenders and the player",
		FileAccess.open("res://siege_enemy.gd", FileAccess.READ).get_as_text().contains('["adventurer", "player"] if arrival_mode'))
	check("...and the wave is set to arrival_mode at spawn",
		msrc.contains("e.arrival_mode = true"))
	check("the teaching fight lasts long enough to reach on foot",
		msrc.contains("e.max_health = 60"))
	check("the trio is shielded FOR THE ARRIVAL ONLY",
		FileAccess.open("res://adventurer.gd", FileAccess.READ).get_as_text().contains("GameState.arrival_shield_on()")
		and msrc.contains("begin_arrival_shield()")
		and msrc.contains("arrival_battle_active = false"))
	check("...and the shield is transient, never saved (a real siege still kills)",
		not gsrc.contains('"arrival_battle_active"'))
	var adv_shield := get_tree().get_nodes_in_group("adventurer")
	if not adv_shield.is_empty():
		var a0 = adv_shield[0]
		var st0: Dictionary = GameState.adventurer_state(str(a0.adventurer_id))
		var hp_before: float = float(st0.get("hp", 100.0))
		GameState.begin_arrival_shield()
		a0.take_damage(9999)
		check("a live blow in the arrival cannot even scratch them",
			not a0.is_dead
			and float(GameState.adventurer_state(str(a0.adventurer_id)).get("hp", 100.0)) == hp_before)
		# the shield can NEVER stick: walking into the deep drops it, and so
		# does its own deadline (an unfinished wave must not grant immortality)
		GameState.in_dungeon = true
		check("entering the deep stands the shield down", not GameState.arrival_shield_on())
		GameState.in_dungeon = false
		GameState.begin_arrival_shield(-1.0)
		check("and it expires on its own deadline", not GameState.arrival_shield_on())
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
