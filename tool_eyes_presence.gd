extends Node
# EYES: the presence layer, photographed. The dev's complaint was that the town's
# systems are invisible, so a green test proves nothing here -- the only honest
# check is a picture. Stages a town that HAS all of it (full stores, a working
# neighbour pair, all three auras lit) and shoots the three places it should show.
#
#   MONARCH_TEST="res://tool_eyes_presence.gd" Godot.exe --path .    (no --headless)

const SHOT_DIR := "user://eyes_presence"

func _ready() -> void:
	var p: Node = null
	for i in range(900):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)

	# ---- stage a town that actually has something to show ----
	# ⚠ BODIES, NOT FLAGS: a fresh village only stands up the 4 iconic ruins, and
	# setting build_stage on the other eleven creates no NODE -- so refresh_layout
	# never learns where they are and the auras have nothing to pool around. (The
	# first run of this walker printed "aura Bar at x=?" and proved it.) dev_mode
	# makes generate_village raise all fifteen, so reload the scene under it.
	GameState.dev_mode = true
	for bn in GameState.STARTING_BUILDINGS:
		GameState.building_stage[bn] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[bn] = GameState.BUILDING_MAX_HEALTH
		GameState.building_levels[bn] = 4
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	for i in range(180):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group("player")
	if p == null: printerr("no player after reload"); get_tree().quit(1); return
	GameState.village_stockpile = {"wood": 40, "stone": 40, "iron_shard": 30}
	# seat a leader everywhere so the powers are awake and the auras are live
	GameState.rescued_villagers = []
	for bn2 in GameState.STARTING_BUILDINGS:
		var post := ""
		for rd in BuildingRoles.get_roles(bn2):
			if rd.get("leadership", false):
				post = str(rd.get("title", ""))
				break
		if post != "":
			GameState.rescued_villagers.append({"id": "e_%s" % bn2, "name": "Chief", "sex": "Male",
				"is_kid": false, "stat_name": post, "stat_value": 6,
				"role_key": bn2, "role_title": post})
		else:
			GameState.rescued_villagers.append({"id": "e_%s" % bn2, "name": "Keeper", "sex": "Female",
				"is_kid": false, "stat_name": "Hospital", "stat_value": 4,
				"role_key": bn2, "role_title": "Lightkeeper"})
	GameState.refresh_layout()
	await get_tree().process_frame

	# report what SHOULD be on screen, so a blank frame is obviously a bug
	var pairs := []
	for bn3 in GameState.building_x.keys():
		for link in GameState.adjacency_links(str(bn3)):
			pairs.append("%s+%s" % [str(bn3), str(link["partner"])])
	printerr("live neighbour pairs: ", pairs)
	printerr("stores: ", GameState.village_stockpile)
	for a in GameState.AURAS.keys():
		printerr("aura %s at x=%s reaches %d" % [a, str(GameState.building_x.get(a, "?")),
			GameState.aura_reach(str(a))])

	var cam := get_viewport().get_camera_2d()
	var shots := [
		{"name": "01_stores_yard", "x": float(GameState.building_x.get("Builderhouse", 17000.0)) + 250.0},
		{"name": "02_auras_bar", "x": float(GameState.building_x.get("Bar", 12000.0))},
		{"name": "03_auras_shrine", "x": float(GameState.building_x.get("Shrine", 20200.0))},
		{"name": "04_lanterns_heart", "x": float(GameState.building_x.get("Bank", 11728.0))},
		{"name": "05_road_wide", "x": float(GameState.building_x.get("Marketplace", 14933.0))},
	]
	for s in shots:
		p.global_position = Vector2(float(s["x"]), -100.0)
		if cam != null:
			cam.global_position = Vector2(float(s["x"]), -140.0)
		# ⚠ THE LAYER IS ON A 1.5s TIMER. The walker was shooting ~0.2s after
		# refresh_layout, so every frame caught the presence node's FIRST draw --
		# made before building_x existed, i.e. empty. Poke it, then let it settle.
		for n in get_tree().get_nodes_in_group("village_presence"):
			n.queue_redraw()
		for n2 in get_tree().get_nodes_in_group("synergy_lanterns"):
			n2.queue_redraw()
		for i in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [SHOT_DIR, str(s["name"])]
		img.save_png(path)
		printerr("shot: ", ProjectSettings.globalize_path(path))
	printerr("EYES DONE -> ", ProjectSettings.globalize_path(SHOT_DIR))
	get_tree().quit(0)
