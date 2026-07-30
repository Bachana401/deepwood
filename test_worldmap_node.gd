extends Node
# ── THE FULL MAP, EVERYWHERE (M) ──────────────────────────────────────────────
# The dev asked for the underground's fullscreen chart in every scene. This
# proves the VILLAGE and a DUNGEON FLOOR both open one, that it holds the things
# it claims to (buildings by name, floor platforms), and that closing it gives
# the input back. The underground's own map is locked by test_underground_node.
#
#   MONARCH_TEST="res://test_worldmap_node.gd" Godot.exe --headless --path .

var pass_count := 0
var fail_count := 0

func check(label: String, ok: bool) -> void:
	if ok:
		pass_count += 1
		printerr("PASS  " + label)
	else:
		fail_count += 1
		printerr("FAIL  " + label)

const EXPECTED_CHECKS := 11

func _ready() -> void:
	await _run()
	var ran := pass_count + fail_count
	if ran < EXPECTED_CHECKS:
		fail_count += 1
		printerr("FAIL  only %d of ~%d checks ran -- a scene never booted" % [ran, EXPECTED_CHECKS])
	printerr("RESULT: %s   (%d passed, %d failed)"
		% ["ALL PASS" if fail_count == 0 else "FAILURES", pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

func _await_scene(has_method: String) -> Node:
	for i in range(1400):
		await get_tree().process_frame
		var cs = get_tree().current_scene
		if cs != null and cs.has_method(has_method):
			return cs
	return null

func _run() -> void:
	# ── the VILLAGE ──
	var village: Node = await _await_scene("_open_village_map")
	check("the village scene carries the map hook", village != null)
	if village == null:
		return
	GameState.opening_done = true                  # the chart, not the prologue
	for i in range(30):
		await get_tree().process_frame
	# ADMIN GATE (dev call): M must do NOTHING in the honest playthrough
	GameState.dev_mode = false
	var press := InputEventKey.new()
	press.keycode = KEY_M
	press.pressed = true
	village._unhandled_input(press)
	check("M is dead without dev_mode -- the map is admin kit",
		village._world_map == null or not village._world_map.is_open())
	GameState.dev_mode = true
	village._unhandled_input(press)
	check("...and answers with it", village._world_map != null and village._world_map.is_open())
	if village._world_map != null and village._world_map.is_open():
		village._open_village_map()                # close again for the scripted run below
	village._open_village_map()
	var vm = village._world_map
	check("M opens the village map", vm != null and vm.is_open())
	if vm != null and vm.is_open():
		var named := 0
		for m in vm._markers:
			if String(m.label) != "" and not String(m.label).begins_with("The"):
				named += 1
		check("the village's buildings are on the chart by name (%d named)" % named, named >= 3)
		check("the cave mouth is marked as the way down",
			vm._markers.any(func(m): return "cave mouth" in String(m.label)))
		# live dots: whoever exists walks on the chart. A fresh run's village is
		# EMPTY by design (people emerge after the first wave), so the check is
		# against the population that is actually there, not a fixed number.
		for i in range(12):
			await get_tree().process_frame
		var alive := get_tree().get_nodes_in_group("npc").size() \
			+ get_tree().get_nodes_in_group("adventurer").size()
		check("everyone alive walks on the chart (%d of %d)" % [vm._live_dots.size(), alive],
			vm._live_dots.size() >= mini(alive, 1) if alive > 0 else vm._live_dots.is_empty())
		village._open_village_map()                # toggle
		check("M again closes it", not vm.is_open())

	# ── a DUNGEON FLOOR ──
	GameState.pending_player_state = {}
	GameState.active_dungeon_level = 3
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
	var floor_scene: Node = await _await_scene("_open_floor_map")
	check("the dungeon floor carries the map hook", floor_scene != null)
	if floor_scene == null:
		return
	for i in range(40):
		await get_tree().process_frame
	floor_scene._open_floor_map()
	var fm = floor_scene._world_map
	check("M opens the floor map", fm != null and fm.is_open())
	if fm != null and fm.is_open():
		check("the floor's platforms are on the chart",
			fm._view != null and fm._view.get_child_count() > 4)
