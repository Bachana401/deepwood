extends Node

# THE FADING OF DEEPWOOD (dev ask 2026-07-22). As the hearth empties, escalating
# dread fires on WORSENING and PIERCES the away-fog. An empty village is a wound,
# not the end, while any named soul still waits in the dark. A fallen leadership
# FIGURE is lost FOREVER (permadeath, dev call) -- which lets the finite rescue
# pool finally empty; only then, with an empty hearth, does the story truly end.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func mk(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"id": "pv_%d" % i, "name": "Soul %d" % i, "sex": "Male", "is_kid": false})
	return out

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

	var saved_roster: Array = GameState.rescued_villagers
	var saved_dev: bool = GameState.dev_mode
	var saved_band: int = GameState._peril_band
	var saved_lost: bool = GameState.village_lost
	var saved_souls: Array = GameState.lost_souls.duplicate()
	var saved_adv: Dictionary = GameState.adventurers.duplicate(true)
	var saved_ten: Dictionary = GameState.the_ten.duplicate(true)
	GameState.dev_mode = false

	var fig_id := ""
	for lvl in VillagerQuests.IMPORTANT_FIGURES:
		fig_id = str(VillagerQuests.IMPORTANT_FIGURES[lvl].get("villager_id", ""))
		break

	# ---- the dread ladder + re-arm ----
	GameState._peril_band = -1
	GameState.lost_souls = []
	GameState.rescued_villagers = mk(6)
	GameState.tick_village_peril()
	check("a healthy village raises no dread", GameState._peril_band == -1, str(GameState._peril_band))
	GameState.rescued_villagers = mk(3); GameState.tick_village_peril()
	check("dwindling sounds the cold dread", GameState._peril_band == 0)
	GameState.rescued_villagers = mk(1); GameState.tick_village_peril()
	check("the last soul raises the final warning", GameState._peril_band == 1)
	# empty, but the dungeon is full -> recoverable, NOT the end
	GameState.village_lost = false
	GameState.rescued_villagers = []
	check("with a fresh dungeon the rescue pool is open", GameState.rescue_pool_open())
	GameState.tick_village_peril()
	check("an emptied hearth reaches the empty band", GameState._peril_band == 2)
	check("...but is NOT the true end while souls wait", not GameState.village_lost)
	GameState.rescued_villagers = mk(5); GameState.tick_village_peril()
	check("bringing people home re-arms the dread", GameState._peril_band == -1)

	# ---- figure permadeath: a fallen leader is lost forever ----
	GameState.lost_souls = []
	GameState.rescued_villagers = [{"id": fig_id, "name": "Test Figure", "sex": "Male", "is_kid": false}]
	check("the id is a real leadership figure", GameState.is_important_figure(fig_id))
	GameState.remove_villager_by_id(fig_id)
	check("a fallen figure is added to the lost forever", GameState.lost_souls.has(fig_id))
	# ...and brought home again (cleanse / re-rescue) clears that
	GameState.rescue_villager({"id": fig_id, "name": "Test Figure", "sex": "Male", "is_kid": false})
	check("a soul brought home is no longer lost", not GameState.lost_souls.has(fig_id))
	var dsrc := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the dungeon won't respawn a lost figure", dsrc.contains("GameState.lost_souls.has(fig_id)"))

	# ---- the true end: empty hearth AND the pool fully emptied ----
	GameState.lost_souls = []
	for lvl2 in VillagerQuests.IMPORTANT_FIGURES:
		GameState.lost_souls.append(str(VillagerQuests.IMPORTANT_FIGURES[lvl2].get("villager_id", "")))
	GameState.ensure_adventurers()
	for aid in GameState.adventurers.keys():
		GameState.adventurers[aid]["dead"] = true
	GameState.ensure_the_ten()
	for tid in GameState.the_ten.keys():
		GameState.the_ten[tid]["freed"] = true
	GameState.rescued_villagers = []
	check("with every soul lost or freed, the rescue pool is CLOSED", not GameState.rescue_pool_open())
	GameState.village_lost = false
	GameState._peril_band = 1
	GameState.tick_village_peril()   # -> empty band -> pool closed -> the true end
	check("an empty hearth with no one to save ENDS the story", GameState.village_lost)
	get_tree().paused = false        # the end-screen pauses the tree; release it
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == 250:
			c.queue_free()

	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("mortal warnings pierce the fog (notify_urgent)", gs.contains("func notify_urgent"))
	check("the lost-forever set survives the save", gs.contains('"lost_souls": lost_souls'))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.dev_mode = saved_dev
	GameState._peril_band = saved_band
	GameState.village_lost = saved_lost
	GameState.lost_souls = saved_souls
	GameState.adventurers = saved_adv
	GameState.the_ten = saved_ten
	printerr("test_peril : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
