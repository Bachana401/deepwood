extends Node
# EYES: VILLAGERS + BUILDINGS SWEEP (2026-07-28, the dev's assigned lane).
# Shots:
#   v1 the day village with its people out
#   v2 a villager's SHEET open (bond fields visible)
#   v3 the night village -- building_lights' windows/fires/signs at work
#   v4 the builder's holo mid-placement
#   v5 the west wall and its gate up close
# Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_village2.gd" Godot.exe --path .  (no --headless!)

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
		say("EYES-V: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	var scene = get_tree().current_scene
	if scene.has_method("spawn_existing_villager_avatars"):
		scene.spawn_existing_villager_avatars()
	await _settle(1.0)

	# ---- v1: daylight, people out ----
	GameState.game_hours = 14.0   # 22 + 14 = 12:00 noon
	await _settle(1.2)
	await _shot("v1_day_village")

	# ---- v2: a villager's sheet, bond and all ----
	var vnpc: Node = null
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and "villager_id" in n and str(n.villager_id) != "":
			vnpc = n
			break
	if vnpc != null:
		p.global_position = vnpc.global_position + Vector2(-80, -30)
		load("res://villager_sheet.gd").open_for(self, vnpc)
		await _settle(0.8)
		await _shot("v2_villager_sheet")
		for s in get_tree().get_nodes_in_group("villager_sheet"):
			if is_instance_valid(s):
				s.queue_free()
	else:
		say("EYES-V: no villager npc found for v2")
	await _settle(0.4)

	# ---- raise a hamlet first: a fresh start owns NO buildings, so the
	# night-lights pass had nothing to light on the first sweep ----
	var px: float = (p as Node2D).global_position.x
	for spec in [["Cottage", px - 380.0], ["Farm", px + 260.0], ["Builderhouse", px + 560.0], ["Bar", px + 900.0]]:
		if scene.has_method("create_building"):
			var b = scene.create_building(str(spec[0]), float(spec[1]))
			if b != null and b.has_method("restore_full"):
				b.restore_full()   # FINISHED buildings wear their facades + lights
	await _settle(0.8)

	# ---- v3: the living night ----
	GameState.game_hours = 25.0   # 22 + 25 = 23:00, deep night
	await _settle(1.5)
	await _shot("v3_night_lights")

	# ---- v4: the builder's holo ----
	var placer: Node = get_tree().get_first_node_in_group("build_placer")
	if placer == null:
		placer = load("res://build_placer.gd").new()
		scene.add_child(placer)
	if placer != null:
		placer.start_build("Cottage", 140.0, 110.0, Color(0.5, 0.8, 0.5))
		await _settle(0.6)
		await _shot("v4_build_holo")
		if placer.has_method("_clear"):
			placer._clear()
		GameState.placing_building = false
	else:
		say("EYES-V: no build placer found")
	await _settle(0.3)

	# ---- v5: the wall and gate ----
	var wall: Node = null
	for n in get_tree().get_nodes_in_group("village_wall"):
		wall = n
		break
	if wall == null:
		for n in get_tree().root.find_children("*", "", true, false):
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("wall.gd"):
				wall = n
				break
	if wall != null and wall is Node2D:
		p.global_position = (wall as Node2D).global_position + Vector2(120, -40)
		await _settle(0.8)
		await _shot("v5_wall_gate")
	else:
		say("EYES-V: no wall found (unbuilt on a fresh start -- fine)")

	# ---- v6: the Wanderer's Post with a SHOWPIECE under the cloth ----
	GameState.wanderers_seen = GameState.WANDERER_SHOWPIECE_FROM - 1
	GameState.wanderer = {}
	for v in GameState.rescued_villagers:
		v["morale"] = 8.0
	GameState._wanderer_arrive()
	var post = get_tree().get_first_node_in_group("wanderer_post_ui")
	if post != null and post.has_method("open_post"):
		post.open_post()
		await _settle(0.8)
		await _shot("v6_wanderer_showpiece")
		post.esc_close()
	else:
		say("EYES-V: no wanderer post UI found")
	GameState.wanderer = {}
	GameState.wanderers_seen = 0

	say("EYES-V: done, %s" % shot_dir)
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-V: shot %s" % name)

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
