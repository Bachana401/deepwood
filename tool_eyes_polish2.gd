extends Node
# EYES: POLISH SWEEP 2 (2026-07-28). Surfaces tonight's work touched that no
# eye has seen yet:
#   s1  the Sword tree with its two Wukong side-roads on the new lanes
#   s2  the Shadow Monarch tree (side-road on lane 5.5 by the Ascendant)
#   s3  a RARE vault chest OPEN -- 76 items in the panel (scroll/overflow)
#   s4  the item card for a flagship (The Rumor's RIDER_DESC promise)
#   s5  the relic picker listing the three Wukong runes
# Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_polish2.gd" Godot.exe --path .  (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

func _find_skill_tree() -> Node:
	for n in get_tree().root.find_children("*", "", true, false):
		if "_fork_armed" in n and n.has_method("refresh"):
			return n
	return null

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
		say("EYES-P2: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _settle(0.8)

	# ---- s1/s2: the trees with their Wukong roads ----
	var st := _find_skill_tree()
	if st != null:
		GameState.chosen_class = "Sword"
		st.panel.visible = true
		st.refresh()
		await _settle(0.8)
		await _shot("s1_sword_tree_wukong")
		GameState.chosen_class = "Shadow Monarch"
		st.refresh()
		await _settle(0.6)
		await _shot("s2_monarch_tree_wukong")
		st.panel.visible = false
		GameState.chosen_class = "Sword"
	else:
		say("EYES-P2: no skill tree UI found")
	await _settle(0.4)

	# ---- s4: the flagship item card ----
	p.inventory.add_item("wpn_therumor", 1)
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip != null and tip.has_method("show_for"):
		tip.show_for("wpn_therumor")
		await _settle(0.6)
		await _shot("s4_flagship_card")
		if tip.has_method("hide_tooltip"):
			tip.hide_tooltip()
	else:
		say("EYES-P2: no item tooltip found")
	await _settle(0.3)

	# ---- s5: the relic picker with the runes ----
	for rid in ["rune_sanctuary", "rune_stoneguise", "rune_riddlestaff"]:
		p.inventory.add_item(rid, 1)
	var eq = get_tree().get_first_node_in_group("equipment_ui")
	if eq != null and "panel" in eq:
		eq.panel.visible = true
		eq.refresh()
		eq.open_picker_for_slot("relic", 0)
		await _settle(0.8)
		await _shot("s5_relic_picker_runes")
		eq.close()
	else:
		say("EYES-P2: no equipment UI found")
	await _settle(0.4)

	# ---- s3: a rack chest OPEN in the proving grounds ----
	GameState.proving_grounds = true
	get_tree().change_scene_to_file("res://dungeon_interior.tscn")
	await _settle(2.5)
	var rare_chest: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if "title" in n and str(n.get("title")) == "RARE" and n.has_method("_open"):
			rare_chest = n
			break
	if rare_chest != null:
		var p2 = get_tree().get_first_node_in_group("player")
		if p2 != null:
			p2.global_position = rare_chest.global_position + Vector2(-60, 0)
		rare_chest._open()
		await _settle(1.0)
		await _shot("s3_rare_chest_open")
	else:
		say("EYES-P2: no RARE rack chest found")

	say("EYES-P2: done, %s" % shot_dir)
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-P2: shot %s" % name)

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
