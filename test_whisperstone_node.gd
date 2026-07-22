extends Node

# THE WHISPERSTONE (dev ask 2026-07-22): the non-mage's fog-lift. Built ONCE at a
# working, staffed Science Lab, it makes the village's live feed reach the player
# anywhere -- the deep included -- exactly like the Telepathy rune. Locks the gate,
# the build requirements, and that it truly lifts the away-fog.

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

	var saved_ws: bool = GameState.has_whisperstone
	var saved_dev: bool = GameState.dev_mode
	var saved_dungeon: bool = GameState.in_dungeon
	var saved_roster: Array = GameState.rescued_villagers
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	GameState.dev_mode = false
	GameState.in_dungeon = true          # away in the deep: the fog is closed
	GameState.has_whisperstone = false

	check("away with no rune and no stone, the fog HIDES the village",
		not GameState.village_info_available())

	# no Lab -> can't build
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_stage[b] = 0
	GameState.rescued_villagers = []
	var r1 := GameState.try_build_whisperstone(p)
	check("no working Lab, no Whisperstone", r1 != "" and not GameState.has_whisperstone, r1)

	# a working Lab but no staff -> still can't
	GameState.building_stage["Science Lab"] = GameState.TOTAL_BUILD_STAGES
	var r2 := GameState.try_build_whisperstone(p)
	check("an unstaffed Lab can't make it", r2 != "" and not GameState.has_whisperstone, r2)

	# staff a Scientist + carry the reagents -> it builds
	GameState.rescued_villagers = [{"id": "ws_sci", "name": "Scholar", "sex": "Female", "is_kid": false,
		"stat_name": "Scientist", "stat_value": 5, "role_key": "Science Lab", "role_title": "Scientist"}]
	p.inventory.slots[0] = null; p.inventory.slots[1] = null
	p.inventory.add_item("iron_shard", 8)
	p.inventory.add_item("ember_crystal", 2)
	var r3 := GameState.try_build_whisperstone(p)
	check("a staffed Lab with the reagents forges the Whisperstone",
		r3 == "" and GameState.has_whisperstone, r3)
	check("it consumed the reagents", p.inventory.get_count("iron_shard") == 0 and p.inventory.get_count("ember_crystal") == 0)

	# NOW the fog is lifted even deep away
	check("with the stone humming, the village reaches you in the deep",
		GameState.village_info_available())
	# and it won't double-build
	var r4 := GameState.try_build_whisperstone(p)
	check("the Whisperstone is a one-time build", r4 != "")

	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the stone survives the save", gs.contains('"has_whisperstone": has_whisperstone'))
	check("it feeds the same fog gate as Telepathy",
		gs.contains("or has_communicator()"))
	var asrc := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("the Lab panel offers to build it", asrc.contains("Build the Whisperstone"))

	GameState.has_whisperstone = saved_ws
	GameState.dev_mode = saved_dev
	GameState.in_dungeon = saved_dungeon
	GameState.rescued_villagers = saved_roster
	GameState.building_stage = saved_stage
	printerr("test_whisperstone : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
