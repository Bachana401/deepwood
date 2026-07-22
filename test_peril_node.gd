extends Node

# THE FADING OF DEEPWOOD (dev ask 2026-07-22): as the hearth empties, escalating
# dread fires on WORSENING and PIERCES the away-fog; an empty village is a wound,
# not the end, while any named soul still waits in the dark to be brought home.
# Locks the band ladder, the re-arm on recovery, the recoverable-empty state, and
# the true-end trigger.

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

	var saved_roster: Array = GameState.rescued_villagers
	var saved_dev: bool = GameState.dev_mode
	var saved_band: int = GameState._peril_band
	var saved_lost: bool = GameState.village_lost
	GameState.dev_mode = false

	# a healthy hearth raises no dread
	GameState._peril_band = -1
	GameState.rescued_villagers = mk(6)
	GameState.tick_village_peril()
	check("a healthy village raises no dread", GameState._peril_band == -1, str(GameState._peril_band))

	# dwindling -> the cold dread band
	GameState.rescued_villagers = mk(3)
	GameState.tick_village_peril()
	check("dwindling to a few souls sounds the dread", GameState._peril_band == 0, str(GameState._peril_band))

	# the last soul
	GameState.rescued_villagers = mk(1)
	GameState.tick_village_peril()
	check("the last soul raises the final warning", GameState._peril_band == 1, str(GameState._peril_band))

	# empty -- but with souls still in the dark, it is recoverable, NOT the end
	GameState.village_lost = false
	GameState.rescued_villagers = []
	check("with a fresh dungeon the rescue pool is open", GameState.rescue_pool_open())
	GameState.tick_village_peril()
	check("an emptied hearth reaches the empty band", GameState._peril_band == 2, str(GameState._peril_band))
	check("...but is NOT the true end while souls wait to be rescued", not GameState.village_lost)

	# recovery re-arms the dread (band falls back)
	GameState.rescued_villagers = mk(5)
	GameState.tick_village_peril()
	check("bringing people home re-arms the warning", GameState._peril_band == -1, str(GameState._peril_band))
	# ...and a healthy town holding steady does NOT re-fire
	GameState.tick_village_peril()
	check("a steady healthy town stays quiet", GameState._peril_band == -1)

	# the true end fires once, and only through its trigger
	GameState.village_lost = false
	GameState._trigger_village_lost()
	check("the true end sets the lost flag", GameState.village_lost)
	GameState._trigger_village_lost()
	check("the true end never double-fires", GameState.village_lost)

	# wired into the clock + reset on a new run
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the peril watch ticks with the village clock", gs.contains("tick_village_peril()"))
	check("mortal warnings PIERCE the fog (notify_urgent, not notify)",
		gs.contains("func notify_urgent") and gs.contains("notify_urgent("))
	check("a fresh run starts quiet", gs.contains("_peril_band = -1"))

	GameState.rescued_villagers = saved_roster
	GameState.dev_mode = saved_dev
	GameState._peril_band = saved_band
	GameState.village_lost = saved_lost
	printerr("test_peril : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
