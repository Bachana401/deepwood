extends Node
# BUILD FROM THE MENU (dev 2026-07-22: "list of buildings... a holo, green if
# placeable, red if bad, on the ground, not on another building"). The holo's
# colour and the actual placement both read GameState.can_place_building, so this
# proves that ONE truth: inside the walls + clear of other buildings = placeable,
# and a placement there raises the building and charges its cost.

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
	for i in range(30):
		await get_tree().process_frame

	# ---- the fallen village starts SPARSE (dev 2026-07-23): a few iconic ruins,
	# no pre-built cottages -- but the whole roster still builds from the menu ----
	var start_ruins := []
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b: start_ruins.append(str(b.building_name))
	check("only a few iconic sites start as ruins, not all 15", start_ruins.size() <= 6,
		"%d: %s" % [start_ruins.size(), str(start_ruins)])
	check("...Government is one of them", "Government" in start_ruins)
	check("a non-iconic site (Tavern) starts as OPEN GROUND", not ("Tavern" in start_ruins))
	var start_cottages := 0
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if "house_id" in n and str(n.house_id).begins_with("house_"):
			start_cottages += 1
	check("the village starts with NO pre-built cottages", start_cottages == 0, "%d" % start_cottages)
	var scene = get_tree().current_scene
	check("the build menu still offers all 15 roster buildings",
		scene.has_method("building_names") and scene.building_names().size() == 15,
		"%d" % (scene.building_names().size() if scene.has_method("building_names") else -1))
	check("...including a non-iconic one with no ruin (Tavern)",
		scene.has_method("building_names") and "Tavern" in scene.building_names())

	# ---- cost table ----
	check("a building has a material cost", not GameState.build_cost("Bar").is_empty())
	check("a Cottage costs gatherable timber, no gold",
		GameState.build_cost("Cottage").has("wood") and not GameState.build_cost("Cottage").has("coin_gold"))
	check("a grander hall still costs gold (Bar)", GameState.build_cost("Bar").has("coin_gold"))

	# ---- can_place_building is the green/red truth ----
	var walls := get_tree().get_nodes_in_group("village_wall")
	var west := 4700.0
	for w in walls:
		if not ("flank" in w and w.flank == "east"): west = w.global_position.x
	check("NOT placeable west of the wall (off the ground you own)",
		not GameState.can_place_building(get_tree(), 120.0, west - 50.0))
	# a spot ON an existing building must be red
	var target: Node = null
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and "width" in b:
			target = b; break
	check("there is a building to test against", target != null)
	var bw: float = float(target.width)
	check("NOT placeable on top of another building",
		not GameState.can_place_building(get_tree(), bw, target.global_position.x))
	# a genuinely clear x inside the walls, sized to the REAL building footprint
	var clear_x := 0.0
	for cand in range(int(west) + 240, 24000, 40):
		if GameState.can_place_building(get_tree(), bw, float(cand)):
			clear_x = float(cand); break
	check("clear ground inside the walls IS placeable", clear_x > 0.0, "clear_x %.0f" % clear_x)

	# ---- raising a building from the menu (the placer's own logic) ----
	var bn: String = str(target.building_name)
	GameState.building_stage[bn] = 0                 # make it a ruin to build
	var placer = preload("res://build_placer.gd").new()
	get_tree().current_scene.add_child(placer)
	await get_tree().process_frame
	# fund it, then place at the clear spot the same call the holo validated
	for k in GameState.build_cost(bn):
		p.inventory.add_item(k, int(GameState.build_cost(bn)[k]) + 2)
	var gold0: int = p.inventory.get_count("coin_gold")
	placer.start_build(bn, float(target.width), float(target.height), Color(0.5, 0.45, 0.4))
	placer._try_place(clear_x)
	check("building it raises the site to standing",
		GameState.building_stage.get(bn, 0) == GameState.TOTAL_BUILD_STAGES,
		"stage %d" % int(GameState.building_stage.get(bn, 0)))
	check("...on the ground you chose", absf(float(GameState.building_positions.get(bn, -1.0)) - clear_x) < 1.0)
	check("...and it charged the materials", p.inventory.get_count("coin_gold") < gold0)

	# ---- a COTTAGE builds a BRAND-NEW home on chosen ground (dev ask) ----
	check("the player holds the Cottage blueprint", GameState.has_blueprint("Cottage"))
	var cott0: int = GameState.extra_cottages
	var cx := 0.0
	for cand in range(int(west) + 260, 24000, 40):
		if GameState.can_place_building(get_tree(), 90.0, float(cand)):
			cx = float(cand); break
	for k in GameState.build_cost("Cottage"):
		p.inventory.add_item(k, int(GameState.build_cost("Cottage")[k]) + 1)
	placer.start_build("Cottage", 90.0, 80.0, Color(0.58, 0.5, 0.35))
	placer._try_place(cx)
	await get_tree().process_frame
	check("building a Cottage raises a NEW home", GameState.extra_cottages == cott0 + 1,
		"%d -> %d" % [cott0, GameState.extra_cottages])
	check("...remembered on the chosen ground",
		GameState.extra_cottage_positions.size() > 0
		and absf(float(GameState.extra_cottage_positions[-1]) - cx) < 1.0)
	var found_home := false
	var cott_node: Node = null
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if "house_id" in n and str(n.house_id).begins_with("menu_house_"):
			found_home = true; cott_node = n; break
	check("...and it stands in the village", found_home)
	# ---- and a raised COTTAGE can be DELETED (checked BEFORE any wall exists,
	# so the delete tool's building/wall/cottage search resolves to the cottage) ----
	if cott_node != null:
		var cbefore: int = GameState.extra_cottages
		check("the delete tool finds a COTTAGE, not just halls",
			placer._building_at(cott_node.global_position.x) == cott_node)
		placer._do_delete(cott_node, placer._delete_kind(cott_node))
		check("deleting a cottage drops the home count", GameState.extra_cottages == cbefore - 1)
		await get_tree().process_frame

	# ---- the tutorial builds cost NO gold (a penniless new player can raise them) ----
	check("the Wall costs no gold, only gatherable stone/wood",
		not GameState.build_cost("Wall").has("coin_gold"))
	check("the Farm costs no gold either", not GameState.build_cost("Farm").has("coin_gold"))
	check("the Cottage costs no gold either", not GameState.build_cost("Cottage").has("coin_gold"))
	# ---- a rampart may stand AT the west gate (it defines the edge) ----
	check("a WALL can stand west of the ramparts (at the gate the dark comes for)",
		GameState.can_place_building(get_tree(), 64.0, west - 40.0, null, true))
	check("...but an ordinary HALL may not (it must sit inside the walls)",
		not GameState.can_place_building(get_tree(), 120.0, west - 40.0, null, false))

	# ---- a WALL builds a rampart on chosen ground + persists ----
	check("the player holds the Wall blueprint", GameState.has_blueprint("Wall"))
	var walls0: int = GameState.placed_walls.size()
	var wx := 0.0
	for cand in range(int(west) + 300, 24000, 40):
		if GameState.can_place_building(get_tree(), 64.0, float(cand)):
			wx = float(cand); break
	for k in GameState.build_cost("Wall"):
		p.inventory.add_item(k, int(GameState.build_cost("Wall")[k]) + 2)
	placer.start_build("Wall", 64.0, 132.0, Color(0.5, 0.5, 0.55))
	placer._try_place(wx)
	await get_tree().process_frame
	check("building a Wall records a placed rampart", GameState.placed_walls.size() == walls0 + 1,
		"%d -> %d" % [walls0, GameState.placed_walls.size()])
	var found_wall := false
	for w2 in get_tree().get_nodes_in_group("village_wall"):
		if is_instance_valid(w2) and absf(w2.global_position.x - wx) < 2.0:
			found_wall = true; break
	check("...and the rampart stands in the village", found_wall)

	# ---- ONE rampart per flank: a second wall on a walled flank is refused (dev
	# 2026-07-23: "at level 15 the player can place 2 walls" -- the duplicate) ----
	var wflank := placer._flank_for_x(wx)
	check("the flank now reads as walled", placer._flank_has_wall(wflank))
	var wx2 := 0.0
	for cand2 in range(int(west) + 200, 26000, 40):
		var c := float(cand2)
		if placer._flank_for_x(c) == wflank and absf(c - wx) > 140.0 \
				and GameState.can_place_building(get_tree(), 64.0, c, null, true):
			wx2 = c; break
	if wx2 > 0.0:
		var before2: int = GameState.placed_walls.size()
		for k in GameState.build_cost("Wall"):
			p.inventory.add_item(k, int(GameState.build_cost("Wall")[k]) + 2)
		placer.start_build("Wall", 64.0, 132.0, Color(0.5, 0.5, 0.55))
		placer._try_place(wx2)
		await get_tree().process_frame
		check("a SECOND wall on the same flank is refused — no duplicate rampart",
			GameState.placed_walls.size() == before2, "%d walls" % GameState.placed_walls.size())

	# ---- a Wall is DELETABLE too now (dev 2026-07-23) ----
	var wall_node: Node = null
	for w3 in get_tree().get_nodes_in_group("village_wall"):
		if is_instance_valid(w3) and absf(w3.global_position.x - wx) < 2.0:
			wall_node = w3; break
	if wall_node != null:
		var wbefore: int = GameState.placed_walls.size()
		check("the delete tool finds a WALL", placer._building_at(wall_node.global_position.x) == wall_node)
		check("a player-RAISED wall is recognised as deletable",
			placer._wall_is_player_placed(wall_node))
		# the town's OWN rampart (the Orin-gated east gate) is NOT in placed_walls, so
		# a stray delete-click must be refused -- forge one far from any placed entry
		# and confirm the guard rejects it (else a misclick strips a flank mid-siege)
		var town_wall = load("res://wall.tscn").instantiate()
		town_wall.flank = "east"
		town_wall.position = Vector2(wall_node.global_position.x + 5000.0, wall_node.global_position.y)
		get_tree().current_scene.add_child(town_wall)
		await get_tree().process_frame
		check("the town's own rampart is NOT deletable (guard holds)",
			not placer._wall_is_player_placed(town_wall))
		town_wall.queue_free()
		placer._do_delete(wall_node, placer._delete_kind(wall_node))
		check("deleting a wall removes it from placed_walls", GameState.placed_walls.size() == wbefore - 1)
	await get_tree().process_frame

	# ---- the step-gated tutorial advances as you build ----
	GameState.tutorial_step = 0
	GameState.tutorial_note("Farm")            # step 0 wants Wall -- wrong build, no move
	check("the tutorial ignores the wrong build", GameState.tutorial_step == 0)
	GameState.tutorial_note("Wall")            # the right one advances it
	check("building the wanted building advances the tutorial", GameState.tutorial_step == 1)
	GameState.tutorial_note("Farm")
	GameState.tutorial_note("Cottage")
	check("the tutorial closes after the last step", GameState.tutorial_step == -1,
		str(GameState.tutorial_step))

	# ---- a DELETED building can be REBUILT from scratch (no orphaned roster) ----
	var reb := "Bar"
	GameState.remove_building(reb)
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and str(b.building_name) == reb:
			b.queue_free()
	await get_tree().process_frame
	check("the razed building is gone from the world",
		not _has_building(reb) and GameState.building_removed(reb))
	for k in GameState.build_cost(reb):
		p.inventory.add_item(k, int(GameState.build_cost(reb)[k]) + 2)
	var rx := 0.0
	for cand in range(int(west) + 340, 26000, 40):
		if GameState.can_place_building(get_tree(), 400.0, float(cand)):
			rx = float(cand); break
	placer.start_build(reb, 400.0, 110.0, Color(0.4, 0.4, 0.4))
	placer._try_place(rx)
	await get_tree().process_frame
	check("...and it can be rebuilt fresh from the menu",
		_has_building(reb) and not GameState.building_removed(reb))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _has_building(bn: String) -> bool:
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and str(b.building_name) == bn:
			return true
	return false
