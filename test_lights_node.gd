extends Node

# Verifies the "living building" pass in a REAL running village: finishes every
# building via the same path the admin panel uses, then checks that the
# Blacksmith actually has 3 burning flames, the Bar's sign is lit, the flames
# respond to nightfall, and the street lanterns flicker.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	# finish every building (what the admin P panel does)
	for b in get_tree().get_nodes_in_group("building"):
		if not ("building_level" in b):
			continue
		b.build_stage = GameState.TOTAL_BUILD_STAGES
		GameState.building_stage[b.building_name] = b.build_stage
		b.constructing = false
		b.health = b.MAX_HEALTH
		GameState.building_health[b.building_name] = b.health
		b.building_level = 1
		GameState.building_levels[b.building_name] = 1
		b.current_state = b.compute_visual_state()
		b.rebuild_geometry()
	for i in range(20):
		await get_tree().process_frame

	var smith: Node = null
	var bar: Node = null
	for b in get_tree().get_nodes_in_group("building"):
		if b.building_name == "Blacksmith": smith = b
		elif b.building_name == "Bar": bar = b
	check("Blacksmith exists", smith != null)
	check("Bar exists", bar != null)
	if smith == null or bar == null:
		printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return

	var sl = _lights(smith)
	var bl = _lights(bar)
	check("Blacksmith has a BuildingLights", sl != null)
	check("Bar has a BuildingLights", bl != null)
	if sl == null or bl == null:
		printerr("RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return

	# --- the fire ---
	check("Blacksmith burns 3 flames", sl._fires.size() == 3, "got %d" % sl._fires.size())
	var playing := true
	for f in sl._fires:
		if not f.is_playing() or f.sprite_frames.get_frame_count("burn") < 8:
			playing = false
	check("flames animating (>=8 frames, playing)", playing)
	check("flames use additive blend", sl._fires.size() > 0
		and sl._fires[0].material is CanvasItemMaterial
		and sl._fires[0].material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	# each flame must sit inside the building, above its base
	var inside := true
	for f in sl._fires:
		var lp: Vector2 = f.position
		if lp.y > 4.0 or lp.y < -smith.eff_h() - 4.0 or absf(lp.x) > smith.eff_w():
			inside = false
	check("flames land on the facade", inside)
	check("no fire on the Bank", _lights(_named("Bank")) == null or _lights(_named("Bank"))._fires.is_empty())

	# --- the sign ---
	check("Bar sign is lit", bl._signs.size() == 1, "got %d" % bl._signs.size())

	# --- day vs night ---
	GameState.game_hours = 18.0    # -> 02:00, deep night
	await get_tree().process_frame
	await get_tree().process_frame
	var night_fire: float = sl._fires[0].modulate.a
	var night_sign: float = bl._signs[0]["halo"].modulate.a
	GameState.game_hours = 4.0     # -> 12:00, noon
	await get_tree().process_frame
	await get_tree().process_frame
	var day_fire: float = sl._fires[0].modulate.a
	var day_sign: float = bl._signs[0]["halo"].modulate.a
	check("fire burns brighter at night", night_fire > day_fire + 0.15,
		"night %.2f vs day %.2f" % [night_fire, day_fire])
	check("fire never goes out in daylight", day_fire > 0.3, "day %.2f" % day_fire)
	check("sign lights up at night", night_sign > day_sign + 0.4,
		"night %.2f vs day %.2f" % [night_sign, day_sign])

	# --- street lanterns flicker ---
	var vl = get_tree().root.find_children("VillageLife", "", true, false)
	var life = vl[0] if vl.size() > 0 else null
	if life == null:
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("_update_lanterns"):
				life = n; break
	check("VillageLife found", life != null)
	if life != null:
		check("street lanterns registered", life._lanterns.size() > 0, "got %d" % life._lanterns.size())
		if life._lanterns.size() > 0:
			GameState.game_hours = 18.0
			await get_tree().process_frame
			var a1: float = life._lanterns[0]["glow"].color.a
			var moved := false
			for i in range(40):
				await get_tree().process_frame
				if absf(life._lanterns[0]["glow"].color.a - a1) > 0.02:
					moved = true; break
			check("lantern glow actually flickers", moved)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _named(n: String) -> Node:
	for b in get_tree().get_nodes_in_group("building"):
		if b.building_name == n:
			return b
	return null

func _lights(b: Node) -> Node:
	if b == null:
		return null
	for n in b.find_children("*", "", true, false):
		if n.has_method("add_fires"):
			return n
	return null
