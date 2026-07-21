extends Node
# The east road (wilderness.gd). Proves the three rules that make it fair:
# it fills up the further you go, wild mobs see you late, and they let go.

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(30):
		keep_running()
		await get_tree().process_frame
	p.god_mode = true

	var wild: Node = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("wilderness.gd"):
			wild = n
	check("the wilderness streamer is mounted in the village", wild != null)
	if wild == null:
		printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return

	# ---- 1. the village is NOT wild, and the east road IS ----
	# Check the MIDDLE of the town, not the road west of it. The old check stood
	# at x=2200 -- outside the west wall, where nothing was ever going to spawn
	# -- and so it passed happily while mobs streamed among the houses from 5200
	# to 22693 (the whole village). Test the place the bug actually was.
	var west_x := 4700.0
	var east_x := 22693.0
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == "west":
			west_x = w.global_position.x
		elif "flank" in w and w.flank == "east":
			east_x = w.global_position.x
	check("the wilds begin OUTSIDE the east gate", wild.wild_start > east_x,
		"wilds at %.0f, east gate at %.0f" % [wild.wild_start, east_x])
	var mid_town := (west_x + east_x) * 0.5
	await _settle(p, wild, Vector2(mid_town, -100.0))
	check("no wild mobs spawn in the middle of the village", _inside(west_x, east_x) == 0,
		"%d among the houses at x=%.0f" % [_inside(west_x, east_x), mid_town])
	# Standing just inside the gate you can SEE the wilds -- that is the point.
	# What must never happen is one of them being inside the walls with you, so
	# count by POSITION, not by how many happen to be alive within earshot.
	await _settle(p, wild, Vector2(east_x - 600.0, -100.0))
	check("...nor any that a player at the gate could walk back to town with",
		_inside(west_x, east_x) == 0, "%d inside the walls" % _inside(west_x, east_x))

	var near: int = await _settle(p, wild, Vector2(wild.wild_start + 1400.0, -100.0))
	check("the road east of the village is populated", near > 0, "%d near the edge" % near)

	var far: int = await _settle(p, wild, Vector2(30000.0, -100.0))
	check("the deep road is BUSIER than the near road", far > near, "near %d vs far %d" % [near, far])

	# ---- 2. they see you late ----
	var sample: Node = wild.any_live_mob()
	check("a wild mob exists to inspect", sample != null)
	if sample != null:
		check("a wild mob's sight is 60% shorter than normal",
			absf(sample.detection_range_current - sample.DETECTION_RANGE * 0.4) < 1.0,
			"%.0f vs normal %.0f" % [sample.detection_range_current, sample.DETECTION_RANGE])
		check("...and it is meaner out here than a village-edge mob",
			sample.max_health > sample.MAX_HEALTH, "hp %d vs base %d" % [sample.max_health, sample.MAX_HEALTH])

	# ---- 3. they let go ----
	if sample != null:
		var home: float = sample.wild_home_x
		# stand far past its leash and give it time to give up and walk back
		p.global_position = Vector2(home + 2000.0, -100.0)
		var chased := false
		for i in range(240):
			keep_running()
			p.global_position = Vector2(home + 2000.0, -100.0)
			p.velocity = Vector2.ZERO
			await get_tree().physics_frame
			if not is_instance_valid(sample):
				break
			if absf(sample.global_position.x - home) > sample.WILD_LEASH + 260.0:
				chased = true
				break
		check("a wild mob never trails you past its leash",
			not chased or not is_instance_valid(sample),
			"wandered %.0f from home (leash %.0f)" % [
				absf(sample.global_position.x - home) if is_instance_valid(sample) else 0.0,
				sample.WILD_LEASH if is_instance_valid(sample) else 0.0])

	# ---- 4. streaming really puts them away (no marathon leak) ----
	var deep: int = await _settle(p, wild, Vector2(30000.0, -100.0))
	var back_home: int = await _settle(p, wild, Vector2(2200.0, -100.0))
	check("walking away frees the mobs behind you", back_home < deep,
		"%d deep -> %d at home" % [deep, back_home])
	check("...all the way to none near the village", back_home == 0, "%d left" % back_home)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# park the player somewhere, let the streamer catch up, and count what's alive
func _settle(p: Node, wild: Node, pos: Vector2) -> int:
	p.global_position = pos
	for i in range(90):
		keep_running()
		p.global_position = pos
		p.velocity = Vector2.ZERO
		await get_tree().physics_frame
	return wild.live_count()

# How many wild mobs are standing INSIDE the village walls right now.
func _inside(west_x: float, east_x: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("course_enemy"):
		if not is_instance_valid(e) or not ("is_wild" in e) or not e.is_wild:
			continue
		if e.global_position.x > west_x and e.global_position.x < east_x:
			n += 1
	return n
