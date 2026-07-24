extends Node
# BUILDER CREW REPAIRS ONLY WHAT STANDS (dev 2026-07-23). is_building_operational is
# building_stage >= TOTAL (no node needed), and auto_repair_one advanced the most-ruined
# of ALL 15 STARTING_BUILDINGS. Since buildings are PLACED from the B menu now and an
# unplaced one has no node while building_stage defaults to 0, the Builderhouse crew
# silently raised every un-built hall to OPERATIONAL with no node -- running its service
# for free and handing the finale gate ("every building repaired") the whole roster.
# Fixed: auto_repair_one skips buildings with no node. This locks both halves.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(300):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break

	# "School" is a menu-built hall: a fresh honest village has NOT placed it (no node)
	var unplaced := "School"
	# "Government" DOES stand at boot -- as a ruin (stage 0), with a node
	var placed := "Government"
	check("%s has no node (unplaced) and is not operational" % unplaced,
		get_tree().get_first_node_in_group("building_role_" + unplaced) == null \
		and not GameState.is_building_operational(unplaced))
	check("%s has a node (placed, a ruin) and starts non-operational" % placed,
		get_tree().get_first_node_in_group("building_role_" + placed) != null \
		and not GameState.is_building_operational(placed),
		"stage=%d" % GameState.building_build_stage(placed))

	# run the Builderhouse crew a long time
	for i in range(120):
		GameState.auto_repair_one()

	check("the crew NEVER raised the unplaced %s to operational (no phantom build)" % unplaced,
		not GameState.is_building_operational(unplaced) \
		and get_tree().get_first_node_in_group("building_role_" + unplaced) == null,
		"stage=%d" % GameState.building_build_stage(unplaced))
	check("the crew DID repair the standing %s to operational" % placed,
		GameState.is_building_operational(placed),
		"stage=%d" % GameState.building_build_stage(placed))

	# only the buildings that actually STAND ever become operational this way
	var operational := 0
	var placed_count := 0
	for bn in GameState.STARTING_BUILDINGS:
		if get_tree().get_first_node_in_group("building_role_" + bn) != null:
			placed_count += 1
		if GameState.is_building_operational(bn):
			operational += 1
	check("operational count == placed count (no free roster)", operational == placed_count,
		"operational=%d placed=%d of %d" % [operational, placed_count, GameState.STARTING_BUILDINGS.size()])

	var src := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("auto_repair_one skips buildings with no node",
		src.contains('if get_tree().get_first_node_in_group("building_role_" + bn) == null:'))

	printerr("test_autorepair : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
