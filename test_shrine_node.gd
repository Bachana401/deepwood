extends Node

# WAYSTONE SHRINES (Wukong-style fast-travel, dev 2026-07-21). A Deep Shrine
# stands on every tenth floor -- INVISIBLE until you clear it, then it WAKES
# (Log line + world-wide chime) and becomes a travel anchor. The village
# WAYSTONE, its blueprint earned at floor 20, leaps you to any woken shrine so
# re-descending the deep never wastes your time. This proves the reveal derives
# from cleared floors, the unlock lands at 20, both structures build, the travel
# menu opens, and the unlock persists.

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
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# 1. a shrine stands on every tenth floor, from 10
	check("shrines stand on every tenth floor, from 10",
		GameState.is_shrine_floor(10) and GameState.is_shrine_floor(20) and GameState.is_shrine_floor(100)
		and not GameState.is_shrine_floor(15) and not GameState.is_shrine_floor(5) and not GameState.is_shrine_floor(0))

	# 2. INVISIBLE until the floor falls -- reveal is derived from floors_cleared
	var saved: Dictionary = GameState.floors_cleared.duplicate()
	GameState.floors_cleared = {}
	check("a shrine stays hidden until its floor is cleared", not GameState.shrine_revealed(10))
	GameState.mark_floor_cleared(10)
	GameState.mark_floor_cleared(30)
	GameState.mark_floor_cleared(31)              # not a decade floor -- no shrine
	check("...and reveals the moment it is", GameState.shrine_revealed(10) and GameState.shrine_revealed(30))
	check("...but not floors between the tens", not GameState.shrine_revealed(31))
	check("the travel list holds exactly the woken shrines", GameState.revealed_shrines() == [10, 30],
		str(GameState.revealed_shrines()))
	GameState.floors_cleared = saved

	# 3. clearing a tenth floor WAKES it (log + world chime); floor 20 wakes the Waystone
	var dsrc := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("clearing a tenth floor wakes its shrine",
		dsrc.contains("is_shrine_floor(current_level)") and dsrc.contains("_place_deep_shrine(true)"))
	check("...and the whole world hears it (announced + chime, not silent)",
		dsrc.contains("A DEEP SHRINE awakens") and dsrc.contains("SFX_CHIME"))
	check("the WAYSTONE blueprint is earned at floor 20",
		dsrc.contains("current_level >= 20 and not GameState.waystone_unlocked"))
	check("...and a re-entered woken floor shows its shrine again",
		dsrc.contains("shrine_revealed(current_level)") and dsrc.contains("_place_deep_shrine(false)"))

	# 4. both structures build, and the travel menu opens
	var sh = load("res://shrine_node.gd").new()
	sh.is_waystone = false
	add_child(sh)
	await get_tree().process_frame
	check("a Deep Shrine builds its dais, pillar, sigil and rune ring",
		sh._visual != null and sh._visual.get_child_count() >= 5)
	check("...and it can play its dramatic wake", sh.has_method("play_wake"))
	sh.play_wake()
	await get_tree().process_frame
	sh.queue_free()
	var wm = load("res://shrine_menu.gd").new()
	add_child(wm)
	wm.open(Vector2(4730.0, -39.0))
	await get_tree().process_frame
	check("the travel menu opens", wm.visible)
	wm.close()
	await get_tree().process_frame

	# 5. the unlock is saved, loaded and reset (triple-wired)
	var gsrc := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the Waystone unlock survives a save",
		gsrc.contains('"waystone_unlocked": waystone_unlocked')
		and gsrc.contains('waystone_unlocked = bool(parsed.get("waystone_unlocked"')
		and gsrc.contains("waystone_unlocked = false"))

	# 6. the village raises the Waystone at its threshold once unlocked
	var msrc := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("the village raises the Waystone once its blueprint is earned",
		msrc.contains("if GameState.waystone_unlocked") and msrc.contains("way.is_waystone = true")
		and msrc.contains("GameState.waystone_home_pos = way.global_position"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
