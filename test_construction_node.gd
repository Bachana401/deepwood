extends Node

# BLUEPRINTS + MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decisions 2026-07-20).
# A ruin cannot rise until its plans are found in the deep (all in hand by
# floor 30, survival basics known from the start); and every roster
# building can be packed up and planted on new ground for a small price.

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

	# ---- blueprints: the schedule and its shape ----
	var covered := GameState.BLUEPRINT_STARTERS.duplicate()
	var deepest := 0
	for f in GameState.BLUEPRINT_FLOORS:
		covered.append(GameState.BLUEPRINT_FLOORS[f])
		deepest = maxi(deepest, int(f))
	var all_covered := true
	for b in GameState.STARTING_BUILDINGS:
		if not b in covered:
			all_covered = false
	check("every roster building is either a starter or has a floor", all_covered)
	check("everything is in hand by floor 30 -- never too late", deepest <= 30, str(deepest))
	check("the survival basics are known from day one",
		"Farm" in GameState.BLUEPRINT_STARTERS and "Builderhouse" in GameState.BLUEPRINT_STARTERS
		and "Tavern" in GameState.BLUEPRINT_STARTERS)
	check("the Shrine's plans arrive with its own service depth",
		GameState.BLUEPRINT_FLOORS.get(30, "") == "Shrine")

	# ---- blueprints: gate, grant, reset, old saves ----
	var saved_bp = GameState.blueprints.duplicate(true)
	GameState.blueprints = GameState.BLUEPRINT_STARTERS.duplicate()
	check("a fresh run knows only the basics", not GameState.has_blueprint("Bank"))
	GameState.grant_blueprint("Bank")
	check("a found blueprint unlocks its ruin", GameState.has_blueprint("Bank"))
	GameState.grant_blueprint("Bank")
	check("granting twice is harmless", GameState.blueprints.count("Bank") == 1)
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("blueprints survive the save; OLD saves know everything",
		gs.contains('"blueprints": blueprints')
		and gs.contains("blueprints = STARTING_BUILDINGS.duplicate()"))
	var bsrc := FileAccess.open("res://building.gd", FileAccess.READ).get_as_text()
	# NEW MODEL (dev 2026-07-22): ruins are PURELY VISUAL -- no E-clear, no F-build,
	# no prompt on the heap. You raise buildings + delete ruins from the B menu.
	check("ruins are purely visual — inert, no clear/build on the heap",
		bsrc.contains("RUINS ARE PURELY VISUAL"))
	var dsrc := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("satchels spawn at their fixed floors, once",
		dsrc.contains("BLUEPRINT_FLOORS.has(current_level)")
		and ResourceLoader.exists("res://blueprint_pickup.gd"))
	# a ruin never names floors -- and now shows nothing at all on the heap
	check("the ruin never names the floor its plans lie on",
		not bsrc.contains("the plans lie on dungeon floor"))
	check("the level select marks floors holding unclaimed plans -- WITHOUT naming them",
		FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("Something of Deepwood's lies lost on this floor")
		and not FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("blueprint lies on this floor"))
	check("...and the marker clears once the plans are in hand",
		FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text().contains("not GameState.has_blueprint"))
	check("the test arena can never farm blueprints",
		dsrc.contains("build_proving_grounds()") and dsrc.find("build_proving_grounds()") < dsrc.find("spawn_deep_rescue()"))
	GameState.blueprints = saved_bp

	# ---- movable buildings: the whole journey ----
	# only a few ICONIC sites start standing now (dev 2026-07-23) -- relocate one
	# that exists (Government), not the Farm (which starts as open ground)
	var mover: Node = null
	for b2 in get_tree().get_nodes_in_group("building"):
		if str(b2.building_name) == "Government":
			mover = b2
	check("an iconic building stands in the live village", mover != null)
	if mover != null:
		var saved_positions = GameState.building_positions.duplicate(true)
		var saved_x: float = mover.global_position.x
		var saved_gold: int = p.currency
		var saved_pos_p: Vector2 = p.global_position
		GameState.moving_building = "Government"
		# too close to a neighbour: refused
		var neighbour: Node = null
		for b3 in get_tree().get_nodes_in_group("building"):
			if b3 != mover:
				neighbour = b3
				break
		p.currency = 1000
		p.inventory.add_item("wood", 10)
		p.global_position = Vector2(neighbour.global_position.x + 10.0, -100.0)
		p.try_plant_building()
		check("planting refuses ground too close to a neighbour",
			GameState.moving_building == "Government" and mover.global_position.x == saved_x)
		# clear ground: the open stretch just west of the EAST rampart -- the
		# only guaranteed-empty land in the packed default layout
		var east_wall_x := 999999.0
		for w in get_tree().get_nodes_in_group("village_wall"):
			if "flank" in w and w.flank == "east":
				east_wall_x = w.global_position.x
		var clear_x := east_wall_x - 400.0
		p.global_position = Vector2(clear_x, -100.0)
		var gold_before: int = p.currency
		p.try_plant_building()
		check("clear ground plants the building where you stand",
			GameState.moving_building == "" and absf(mover.global_position.x - clear_x) < 1.0)
		check("the plant charges the small price",
			p.currency == gold_before - GameState.RELOCATE_GOLD)
		check("the chosen ground persists",
			absf(float(GameState.building_positions.get("Government", -1.0)) - clear_x) < 1.0
			and gs.contains('"building_positions": building_positions'))
		check("the layout honors saved ground on rebuild",
			FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("GameState.building_positions.has(def.name)"))
		# restore
		mover.global_position.x = saved_x
		GameState.building_positions = saved_positions
		p.currency = saved_gold
		p.global_position = saved_pos_p
		p.inventory.remove_item("wood", 6)
	check("the assign panel offers Relocate in both states",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("add_relocate_section"))
	check("cottages, walls and the tower keep their ground (the clearance group)",
		FileAccess.open("res://house.gd", FileAccess.READ).get_as_text().contains("village_structure")
		and FileAccess.open("res://watchtower.gd", FileAccess.READ).get_as_text().contains("village_structure"))

	# ---- the road markers: the walk was never the game ----
	var markers := []
	for n in get_tree().root.find_children("*", "Area2D", true, false):
		if "partner_x" in n:
			markers.append(n)
	check("a marker stands at BOTH ends of the road", markers.size() == 2)
	if markers.size() == 2:
		check("each points at the other",
			absf(markers[0].global_position.x - markers[1].partner_x) < 1.0
			and absf(markers[1].global_position.x - markers[0].partner_x) < 1.0)
		check("the road is LONG enough to be worth skipping (>4000px)",
			absf(markers[0].global_position.x - markers[1].global_position.x) > 4000.0)
		var road_p = get_tree().get_first_node_in_group("player")
		var road_saved: Vector2 = road_p.global_position
		road_p.global_position = markers[0].global_position
		markers[0].travel()
		check("taking the road puts you at the other marker",
			absf(road_p.global_position.x - markers[0].partner_x) < 1.0)
		road_p.global_position = road_saved
		var clash := false
		for m in markers:
			for b4 in get_tree().get_nodes_in_group("building"):
				if absf(b4.global_position.x - m.global_position.x) < 120.0:
					clash = true
		check("neither marker fights a building for the E key", not clash)

	# ---- irreversible choices must be CONFIRMED, never one-click ----
	var stsrc := FileAccess.open("res://skill_tree_ui.gd", FileAccess.READ).get_as_text()
	check("a skill FORK warns before it locks its sibling forever",
		stsrc.contains("_fork_armed") and stsrc.contains("locks %s for this whole run"))
	check("...and the second click is what commits it",
		stsrc.contains("Click again to commit"))
	var asrc := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("drafting to the Barracks warns it DELETES their profession",
		asrc.contains("_draft_armed") and asrc.contains("DELETES their %s forever"))
	check("...and a villager with nothing to lose is drafted without nagging",
		asrc.contains('had != "" and had != "Warrior"'))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
