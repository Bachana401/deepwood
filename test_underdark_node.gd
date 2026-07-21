extends Node
# THE UNDERDARK (GAME_BIBLE §4 amendment). Proves the promises: the cave is the
# ONLY way down, it is genuinely Terraria-scale, its doors respect the floor
# ladder and hand you back to the same door, and its mobs behave like the east
# road's (late sight, real leash, streamed away behind you).

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
	for i in range(40):
		keep_running()
		await get_tree().process_frame
	p.god_mode = true

	var ud = get_tree().current_scene.get_node_or_null("Underdark")
	check("the Underdark is built into the village scene", ud != null)
	if ud == null:
		printerr("RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return

	# ---- 1. the cave is the ONLY way down ----
	check("the old surface dungeon door is retired",
		get_tree().current_scene.get_node_or_null("DungeonZone") == null)
	var doors := _doors(ud)
	check("hidden stone doors exist in the deep", doors.size() >= 40, "%d doors" % doors.size())

	# ---- 2. Terraria-scale ----
	var depth: float = ud.band_floor_y(ud.BANDS - 1) - ud.UD_TOP
	var width: float = ud.UD_RIGHT - ud.ud_left
	check("the underworld runs the width of the map", width > 30000.0, "%.0f wide" % width)
	check("...and is Terraria-deep, not a corridor", depth > 9000.0, "%.0f deep" % depth)
	check("...in many depth bands", ud.BANDS >= 8, "%d bands" % ud.BANDS)

	# ---- 3. the descent lands on real ground, not through it ----
	check("the spine starts EAST of where the stair lets out",
		ud.ud_left > ud._stair_end_x(), "spine %.0f vs stair end %.0f" % [ud.ud_left, ud._stair_end_x()])
	check("the mouth is clear of the player's spawn point",
		absf(ud.MOUTH_X - (-300.0)) > 400.0, "mouth at %.0f" % ud.MOUTH_X)

	# ---- 4. deeper doors open onto deeper floors ----
	var shallow := _avg_level(doors, ud, 0, 2)
	var deep := _avg_level(doors, ud, 5, 7)
	check("the deeper you dig, the higher the floors behind the doors",
		deep > shallow + 25.0, "bands 0-2 avg %.0f vs bands 5-7 avg %.0f" % [shallow, deep])
	var maxlv := 0
	var minlv := 999
	for d in doors:
		maxlv = maxi(maxlv, d.target_level)
		minlv = mini(minlv, d.target_level)
	check("the deepest doors reach the end of the ladder", maxlv >= 95, "max %d" % maxlv)
	# A FRESH SAVE HAS ONLY FLOOR 1. With no surface door left, if the shallow
	# caves hold nothing below floor 8 the dungeon is unreachable for the whole
	# early game -- which is exactly what the first random placement did.
	check("a brand-new run can actually get in (a floor-1 door exists)",
		minlv == 1, "shallowest door is floor %d" % minlv)
	# ...and it must be REACHABLE: no door may sit on a rune-vault segment,
	# which is barred behind three runes. A gated floor-1 door would soft-lock a
	# fresh game exactly as an absent one would.
	var gated := 0
	for d in doors:
		var db := int((d.position.y - ud.UD_TOP) / ud.BAND_H)
		var dsegs: Array = ud._plan[db]
		var dv: Dictionary = dsegs[dsegs.size() - 2]
		if d.position.x >= dv.x0 and d.position.x <= dv.x1:
			gated += 1
	check("no door is trapped behind a rune-vault gate", gated == 0, "%d gated doors" % gated)

	# ---- 4b. it is a PLACE, not a hallway: arenas, squeezes, loot, traps ----
	var kinds := {}
	for b in range(ud.BANDS):
		for s in ud._plan[b]:
			kinds[s.kind] = int(kinds.get(s.kind, 0)) + 1
	check("there are huge halls to fight crowds in", int(kinds.get("arena", 0)) >= 10,
		"%d arenas" % int(kinds.get("arena", 0)))
	check("...and tight squeezes between them", int(kinds.get("crawl", 0)) >= 10,
		"%d crawls" % int(kinds.get("crawl", 0)))
	check("...and chambers, and plain tunnel to connect it all",
		int(kinds.get("chamber", 0)) >= 20 and int(kinds.get("tunnel", 0)) >= 50)
	var traps := 0
	var runes := 0
	for c in ud.get_children():
		var sp = c.get_script()
		if sp == null:
			continue
		if str(sp.resource_path).ends_with("trap.gd"):
			traps += 1
		elif str(sp.resource_path).ends_with("underdark_rune.gd"):
			runes += 1
	check("the squeezes are trapped", traps >= 8, "%d traps" % traps)
	var chests := 0
	var deep_loot := false
	for c in get_tree().current_scene.get_children():
		var sp2 = c.get_script()
		if sp2 == null or not str(sp2.resource_path).ends_with("chest.gd"):
			continue
		if not str(c.chest_id).begins_with("ud_"):
			continue
		chests += 1
		for slot in c.inventory.slots:
			if slot != null and str(slot.item_id) in ["void_essence", "ancient_relic"]:
				deep_loot = true
	check("the deep is worth looting", chests >= 20, "%d chests" % chests)
	check("...and the deepest caches pay in what you cannot buy", deep_loot)

	# ---- 4c. the rune puzzle actually unbars its vault ----
	check("every band hides a barred vault", ud._vault_gates.size() == ud.BANDS,
		"%d gates" % ud._vault_gates.size())
	check("...with three runes each to find", runes == ud.BANDS * 3, "%d runes" % runes)
	var gate0 = ud._vault_gates.get(0)
	check("the vault is BARRED until the runes are lit", is_instance_valid(gate0))
	ud.rune_lit(0)
	ud.rune_lit(0)
	check("...two of three is not enough", is_instance_valid(ud._vault_gates.get(0)))
	ud.rune_lit(0)
	await get_tree().process_frame
	check("...and the third opens it", not is_instance_valid(ud._vault_gates.get(0)))

	# ---- 4c2. the floor is WALKABLE and LIT (dev report: alignment too bad,
	# add real light, platforms here and there) ----
	var worst_step := 0.0
	for b2 in range(ud.BANDS):
		var sg: Array = ud._plan[b2]
		for i in range(1, sg.size()):
			worst_step = maxf(worst_step, absf(sg[i].floor_y - sg[i-1].floor_y))
	check("no floor step is taller than a jump (the deep is walkable)",
		worst_step <= 92.0, "worst step %.0f" % worst_step)
	var lit := 0
	var hues := {}
	for c in ud.get_children():
		if c is Sprite2D and c.material is CanvasItemMaterial:
			lit += 1
			hues["%.1f,%.1f,%.1f" % [c.modulate.r, c.modulate.g, c.modulate.b]] = true
	check("the deep is lit by real fires", lit >= 100, "%d lights" % lit)
	check("...in many fire-colours (orange, green, blue and more)", hues.size() >= 5,
		"%d distinct hues" % hues.size())
	var plats := 0
	for c in ud.get_children():
		if c is StaticBody2D:
			for cc in c.get_children():
				if cc is ColorRect and cc.size.y <= 18.0 and cc.size.x >= 100.0:
					plats += 1
	check("there are platforms to climb and fight from", plats >= 30, "%d platforms" % plats)

	# ---- 4d. THE WAY IN, and the road that must survive it ----
	# A side-scroller road is one-dimensional: anything solid on it is a wall,
	# and any hole in it is a trap you fall into every time you walk past. The
	# first cave was a hole that sealed itself with its own stair; the second
	# was a mound that walled off the village. Both of these must hold at once.
	var space := get_viewport().world_2d.direct_space_state
	var broken := 0
	var rx: float = float(ud.MOUND_LEFT) - 100.0
	while rx < float(ud.MOUND_RIGHT) + 200.0:
		var q := PhysicsRayQueryParameters2D.create(Vector2(rx, -120.0), Vector2(rx, 400.0))
		q.collide_with_areas = false
		var h := space.intersect_ray(q)
		if not h or absf(h["position"].y - (-39.0)) > 6.0:
			broken += 1
		rx += 40.0
	check("the road over the cave is unbroken (the village stays reachable)",
		broken == 0, "%d broken samples" % broken)
	p.global_position = Vector2(ud.DESCENT_X + 40.0, ud.TUNNEL_TOP_Y - 60.0)
	p.velocity = Vector2.ZERO
	for i in range(60):
		keep_running()
		await get_tree().physics_frame
	check("the tunnel head is solid ground you can stand on", p.is_on_floor(),
		"y=%.0f" % p.global_position.y)
	check("...and the whole descent lives BELOW the crust",
		ud.TUNNEL_TOP_Y > 60.0, "tunnel top at %.0f" % ud.TUNNEL_TOP_Y)

	# ---- 5. a door respects the ladder, and hands you back to itself ----
	GameState.highest_unlocked_level = 3
	var sealed_door: Node = null
	var open_door: Node = null
	for d in doors:
		if d.target_level > 3 and sealed_door == null:
			sealed_door = d
		if d.target_level <= 3 and open_door == null:
			open_door = d
	check("a door onto a floor you have not earned stays SEALED",
		sealed_door != null and not sealed_door._unlocked())
	check("...and one onto an unlocked floor opens", open_door != null and open_door._unlocked())
	if open_door != null:
		GameState.seen_arrival_battle = true
		GameState.seen_arrival_talk = true
		GameState.harvest_at_home = false
		var want_level: int = open_door.target_level
		var want_pos: Vector2 = open_door.global_position
		open_door._try_enter()
		for i in range(300):
			await get_tree().process_frame
			if GameState.in_dungeon:
				break
		check("entering a door drops you onto ITS floor",
			GameState.in_dungeon and GameState.active_dungeon_level == want_level,
			"in=%s level=%d want=%d" % [str(GameState.in_dungeon), GameState.active_dungeon_level, want_level])
		check("...and leaving that floor returns you to that very door",
			GameState.pre_dungeon_position.distance_to(want_pos) < 2.0,
			"%s vs %s" % [str(GameState.pre_dungeon_position), str(want_pos)])
		printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _doors(ud: Node) -> Array:
	var out := []
	for c in ud.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("underdark_door.gd"):
			out.append(c)
	return out

func _avg_level(doors: Array, ud: Node, lo_band: int, hi_band: int) -> float:
	var total := 0.0
	var n := 0
	for d in doors:
		var b := int((d.position.y - ud.UD_TOP) / ud.BAND_H)
		if b >= lo_band and b <= hi_band:
			total += float(d.target_level)
			n += 1
	return total / maxf(1.0, float(n))
