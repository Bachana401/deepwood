extends Node
# EYES: THE POLISH SWEEP (2026-07-28). Tonight's visual work, actually SEEN
# (the standing rule: a green suite is not eyes). Shots:
#   p1  the buff/debuff chip row: feast gold + poison green + sanctuary blue
#   p2  a chain maul mid-WHIRL around the hero (then p3 mid-hurl)
#   p4  the equipment window wearing the full Sovereign's Regalia
#   p5  the proving racks with the whole 350-arsenal standing in them
# Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_polish.gd" Godot.exe --path .   (no --headless!)

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
		say("EYES-P: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _settle(0.8)

	# ---- p1: the chip row, fully lit ----
	p.add_buff("all_damage", 4.0, 60.0)
	p.add_buff("move_speed", 0.1, 45.0)
	p.poison_until = Time.get_ticks_msec() / 1000.0 + 30.0
	GameState.equipment.relics[0] = "rune_sanctuary"
	p.velocity = Vector2.ZERO
	p._still_t = 5.0
	await _settle(1.0)
	await _shot("p1_buff_chip_row")
	GameState.equipment.relics[0] = ""
	p.active_buffs.clear()
	p.poison_until = 0.0

	# ---- p2/p3: the chain maul's whirl and hurl ----
	p.inventory.add_item("wpn_secondmoon", 1)
	p.wield_weapon("wpn_secondmoon")
	await _settle(0.4)
	var sp: Dictionary = Inventory.get_item_def("wpn_secondmoon").get("special", {})
	p.launch_projectile(sp, Vector2.RIGHT, 30)
	await _settle(0.35)   # mid-whirl
	await _shot("p2_chainmaul_whirl")
	await _settle(0.55)   # mid-hurl / haul
	await _shot("p3_chainmaul_hurl")
	await _settle(1.2)

	# ---- p4: the equipment window in the full Regalia ----
	for id in ["helm_regal", "armor_regal", "pants_regal"]:
		p.inventory.add_item(id, 1)
		GameState.equip_item(id, p)
	var eq = get_tree().get_first_node_in_group("equipment_ui")
	if eq != null and "panel" in eq:
		eq.panel.visible = true
		if eq.has_method("refresh"):
			eq.refresh()
		await _settle(0.8)
		await _shot("p4_regalia_equipment")
		if eq.has_method("close"):
			eq.close()
	else:
		say("EYES-P: no equipment UI found for p4")
	await _settle(0.4)

	# ---- p5: the proving racks, whole-arsenal edition ----
	GameState.proving_grounds = true
	get_tree().change_scene_to_file("res://dungeon_interior.tscn")
	await _settle(2.5)
	var p2 = get_tree().get_first_node_in_group("player")
	if p2 != null:
		# stand at the racks' left edge so the chest row + counts read
		p2.global_position = Vector2(400.0, p2.global_position.y)
	await _settle(1.0)
	await _shot("p5_proving_racks")

	say("EYES-P: done, %s" % shot_dir)
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-P: shot %s" % name)

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
