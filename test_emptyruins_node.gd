extends Node
# THE EMPTY RUINS (2026-07-25): a fresh arrival opens on a DEAD village. The three
# starting souls (Doctor Maren + two farmhands) exist in the roster from frame one
# so every system that counts them keeps working, but their AVATARS do NOT appear
# until the first wave is broken -- then they creep out in the arrival cutscene.
# This locks that: unpeopled ruins before the wave, three survivors after.

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

	# fresh New Game with the opening NOT yet won: skip only the prologue so the
	# village boots directly, but leave the arrival battle UNSEEN.
	GameState.reset_for_new_game()
	GameState.dev_mode = false                  # dev mode peoples the village at once
	GameState.seen_intro = true
	GameState.seen_arrival_battle = false
	GameState.seen_arrival_talk = false
	GameState.in_dungeon = false
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	for i in range(240):
		await get_tree().process_frame
	for i in range(120):
		await get_tree().process_frame

	# the data is there from the first breath...
	check("roster still holds the 3 starting villagers", GameState.rescued_villagers.size() == 3,
		"%d" % GameState.rescued_villagers.size())
	# ...but NONE of them walk the ruins yet
	var before := get_tree().get_nodes_in_group("npc")
	check("the ruins stand EMPTY before the first wave (0 villager avatars)",
		before.size() == 0, "%d npc avatars" % before.size())

	# break the wave: flip the flag and run the emergence spawn the cutscene uses
	GameState.seen_arrival_battle = true
	var main := get_tree().current_scene
	check("the town scene exposes the emergence spawn",
		main != null and main.has_method("spawn_existing_villager_avatars"), str(main))
	if main != null and main.has_method("spawn_existing_villager_avatars"):
		main.spawn_existing_villager_avatars()
	for i in range(30):
		await get_tree().process_frame
	var after := get_tree().get_nodes_in_group("npc")
	check("the three survivors emerge once the wave is broken (3 villager avatars)",
		after.size() == 3, "%d npc avatars" % after.size())

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
