extends Node
# EYES: FISHING (pillar 3, 2026-07-28). The whole loop, seen with eyes:
# the Dock's pond, the cast bobber, the bite flare, the landed catch, the
# Harbormaster's Ledger panel, and an underdark calm pool. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_fishing.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("EYES-F: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()

	# ---- raise a whole, staffed Dock and let the tick hand over the rod ----
	var scene = get_tree().current_scene
	GameState.building_stage["Fishing Dock"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Fishing Dock"] = GameState.BUILDING_MAX_HEALTH
	GameState.removed_buildings.erase("Fishing Dock")
	GameState.rescued_villagers.append({"name": "Eyes Fisher", "role_key": "Fishing Dock", "role_title": "Fisherman"})
	GameState.game_hours = 30.0
	# the clock jump above would back-pay a siege into the middle of the
	# shoot; push every war drum far away, this walk is about the water
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0
	GameState.live_siege_active = false
	var dock: Node = null
	if scene.has_method("create_building"):
		# clear ground PAST the village row -- x=2600 planted the pond square
		# on the cave mouth's mound (seen with eyes, first run)
		var dx: float = 8600.0
		if "village_right_edge" in scene:
			dx = float(scene.village_right_edge) + 900.0
		dock = scene.create_building("Fishing Dock", dx)
	if dock == null:
		say("EYES-F: no dock"); get_tree().quit(1); return
	GameState.willow_rod_granted = false
	GameState.fishing_quest = {}
	GameState.fishing_last_post_day = -1
	GameState.tick_fishing()   # grants the willow rod + posts the daily
	await _settle(0.8)

	# ---- f1: the pond itself ----
	p.global_position = dock.global_position + Vector2(-140.0, -60.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.0)
	await _shot("f1_dock_pond")

	# ---- f2: the cast, bobber on the water ----
	p.wield_weapon("tool_rod_willow")
	await _settle(0.3)
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	await _settle(0.5)
	await _shot("f2_cast_bobber")

	# ---- f3: the BITE (fast-forwarded) ----
	p._fish_timer = 0.05
	await _settle(0.5)
	await _shot("f3_bite_flare")

	# ---- f4: the strike lands the catch ----
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	await _settle(0.5)
	await _shot("f4_catch_toast")

	# ---- f5: the Harbormaster's Ledger panel ----
	var aui: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("open_for_building"):
			aui = n
			break
	if aui != null:
		aui.open_for_building(dock)
		await _settle(0.8)
		# the Ledger section sits below the role rows -- scroll to it, or the
		# shot proves nothing (EYES: first framing showed only the fold above)
		var sc = aui.get_node_or_null("Panel/ScrollContainer")
		if sc != null:
			sc.scroll_vertical = 100000
		await _settle(0.4)
		await _shot("f5_dock_panel")
		if "visible" in aui: aui.visible = false
	else:
		say("EYES-F: no assign ui found")

	# ---- f6/f7: a water pool in the LIVE underground (the tile world) ----
	# The legacy underdark strip is retired; the cave mouth routes to
	# underground.tscn, so that is where the "cave" water lives. Ride in,
	# then hop downward until a water pool streams in near us.
	get_tree().change_scene_to_file("res://underground.tscn")
	var world: Node = null
	for i in range(600):
		await get_tree().process_frame
		world = get_tree().get_first_node_in_group("tile_world")
		if world != null:
			break
	p = null
	for i in range(600):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if world == null or p == null:
		say("EYES-F: underground did not come up"); get_tree().quit(1); return
	await _settle(1.0)
	var pool: Node = null
	var hop := 0
	while pool == null and hop < 60:
		hop += 1
		# wander down through the water biomes (0-2); sideways drift widens the net
		p.global_position += Vector2(340.0 * (1.0 if hop % 2 == 0 else -0.6), 260.0)
		if "velocity" in p: p.velocity = Vector2.ZERO
		await _settle(0.35)
		for n in get_tree().get_nodes_in_group("fish_water"):
			if is_instance_valid(n) and n.has_method("fish_kind") and str(n.fish_kind()) == "cave":
				pool = n
				break
	if pool != null:
		p.global_position = pool.global_position + Vector2(-40.0, -40.0)
		if "velocity" in p: p.velocity = Vector2.ZERO
		await _settle(1.0)
		await _shot("f6_cave_pool")
		# and a cast into it, for the bobber against the dark
		if p.has_method("wield_weapon"):
			if "inventory" in p and p.inventory != null:
				p.inventory.add_item("tool_rod_willow", 1)
			p.wield_weapon("tool_rod_willow")
			p.attack_cooldown_remaining = 0.0
			p.perform_attack()
			await _settle(0.5)
			await _shot("f7_cave_cast")
	else:
		say("EYES-F: no water pool streamed in after %d hops" % hop)

	say("EYES-F: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-F: shot %s" % name)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); found = true
		get_tree().paused = false
		await _settle(0.2)
		if not found and not get_tree().paused:
			return
