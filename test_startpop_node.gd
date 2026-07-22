extends Node
# STARTING VILLAGE POPULATION (dev 2026-07-22: "the village should have 6 NPCs --
# 3 heroes and 3 villagers, and one MUST be a Doctor woman"). Encodes that as a
# hard invariant and counts what ACTUALLY spawns on a fresh game, so a wrong count
# can never creep back.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	# get to a live scene + player first
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return

	# force a clean New Game, skip the prologue/arrival so we read the STEADY
	# village, and reload the town so its avatars spawn from the fresh roster
	GameState.reset_for_new_game()
	GameState.seen_intro = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	GameState.in_dungeon = false
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	for i in range(240):
		await get_tree().process_frame
	# let avatars finish spawning/walking in
	for i in range(120):
		await get_tree().process_frame

	# ---- roster (the data) ----
	var villagers: Array = GameState.rescued_villagers
	check("the roster holds exactly 3 villagers", villagers.size() == 3, "%d" % villagers.size())
	var rescued_adv := 0
	for id in GameState.adventurers:
		if GameState.adventurers[id].get("rescued", false) and not GameState.adventurers[id].get("dead", false):
			rescued_adv += 1
	check("...and exactly 3 heroes stand ready", rescued_adv == 3, "%d" % rescued_adv)
	# the Doctor woman, guaranteed
	var doc: Dictionary = {}
	for v in villagers:
		if str(v.get("stat_name", "")) == "Hospital" or v.get("healer", false):
			doc = v
			break
	check("one villager IS a Doctor (the healer)", not doc.is_empty(), str(villagers))
	check("...and she is a woman", str(doc.get("sex", "")) == "Female", str(doc.get("sex", "")))

	# ---- what actually SPAWNED in the village (the avatars you see) ----
	var npc_avatars := get_tree().get_nodes_in_group("npc")
	var adv_avatars := get_tree().get_nodes_in_group("adventurer")
	check("exactly 3 villager avatars walk the village", npc_avatars.size() == 3, "%d npc" % npc_avatars.size())
	check("exactly 3 hero avatars walk the village", adv_avatars.size() == 3, "%d adventurers" % adv_avatars.size())
	check("SIX people in the village, no more, no fewer",
		npc_avatars.size() + adv_avatars.size() == 6,
		"%d total" % (npc_avatars.size() + adv_avatars.size()))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
