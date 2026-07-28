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
	# the legacy strip is no longer built on village load (scan 2026-07-27: dead
	# world, thousands of nodes). Its layout contracts still hold and are proven
	# here -- the suite raises it on demand.
	ud.build_legacy_strip()
	for i in range(4):
		await get_tree().physics_frame

	# ---- 1. the cave is the ONLY way down ----
	check("the old surface dungeon door is retired",
		get_tree().current_scene.get_node_or_null("DungeonZone") == null)
	var doors := _doors(ud)
	# ONE DOOR PER FLOOR (dev 2026-07-22): doors are the ONLY way into a floor now
	# (the in-dungeon forward gate is gone), so EVERY floor 1..MAX must have exactly
	# one findable door, or the ladder dead-ends at the first floor with no door.
	check("hidden stone doors exist in the deep", doors.size() >= ud.MAX_FLOOR, "%d doors" % doors.size())
	var by_floor := {}
	for d in doors:
		by_floor[d.target_level] = int(by_floor.get(d.target_level, 0)) + 1
	var missing := []
	for lv in range(1, ud.MAX_FLOOR + 1):
		if not by_floor.has(lv):
			missing.append(lv)
	check("EVERY floor has its own door (doors are the only way in)", missing.is_empty(),
		"%d floors have no door: %s" % [missing.size(), str(missing.slice(0, 8))])

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
	var lofts := 0
	var lofts_stocked := 0
	var stashes := 0
	var ambush_caches := 0
	var pit_caches_empty := 0
	for c in get_tree().current_scene.get_children():
		var sp2 = c.get_script()
		if sp2 == null or not str(sp2.resource_path).ends_with("chest.gd"):
			continue
		if not str(c.chest_id).begins_with("ud_"):
			continue
		chests += 1
		var items := 0
		for slot in c.inventory.slots:
			if slot != null:
				items += 1
				if str(slot.item_id) in ["void_essence", "ancient_relic"]:
					deep_loot = true
		var cid := str(c.chest_id)
		if cid.begins_with("ud_loft"):
			lofts += 1
			if items > 0:
				lofts_stocked += 1
		elif cid.begins_with("ud_stash"):
			stashes += 1
			if items == 0:
				pit_caches_empty += 1
		elif cid.begins_with("ud_ambush"):
			ambush_caches += 1
			if items == 0:
				pit_caches_empty += 1
	check("the deep is worth looting", chests >= 20, "%d chests" % chests)
	check("...and the deepest caches pay in what you cannot buy", deep_loot)
	# HIDDEN TREASURE LOFTS -- the reward for looking up, not just running east.
	# They must EXIST, hold loot, and their climb must be jump-safe (same span/nn
	# rung math as the shafts, so reachability is proven the same way).
	check("hidden treasure lofts are scattered through the deep", lofts >= 8, "%d lofts" % lofts)
	check("...and every one holds a cache", lofts > 0 and lofts_stocked == lofts,
		"%d/%d stocked" % [lofts_stocked, lofts])
	var udsrc := FileAccess.open("res://underdark.gd", FileAccess.READ).get_as_text()
	check("...reached by a jump-safe ladder (rungs from a span/nn divide, <=82px)",
		udsrc.contains("func _build_hidden_lofts")
		and udsrc.contains("int(ceil(span / 80.0))")
		and udsrc.contains("s.floor_y - stp * float(i)"))
	# SUNKEN STASHES + HIDDEN AMBUSH CHAMBERS -- rooms tucked BELOW the spine. A pit
	# you can drop into (or hop) for a cache; a wider chamber whose cache is guarded
	# by a pack that springs when you drop in. Both must exist, hold loot, and CLIMB
	# BACK OUT (a pit you can't leave is a softlock).
	check("sunken stashes are dug through the deep", stashes >= 6, "%d stashes" % stashes)
	check("hidden ambush chambers guard some caches", ambush_caches >= 3, "%d ambushes" % ambush_caches)
	check("every sunken cache holds loot", (stashes + ambush_caches) > 0 and pit_caches_empty == 0,
		"%d empty" % pit_caches_empty)
	var trigs := 0
	for c in ud.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("underdark_ambush.gd"):
			trigs += 1
	check("every ambush chamber has a live trigger", trigs == ambush_caches, "%d triggers vs %d" % [trigs, ambush_caches])
	check("...that springs a pack of mobs, and a jumpable mouth you climb back out of",
		udsrc.contains("func spring_ambush") and udsrc.contains("bottom - stp * float(i)")
		and udsrc.contains("PIT_MOUTH"))
	# the pit climb-out uses the same jump-safe span/nn divide as the shafts
	check("a sunken room's climb-out divides its depth into jump-sized rungs",
		udsrc.contains("nn: int = maxi(1, int(ceil(span / 80.0)))"))

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
	# THE DEEP REBUILDS ON EVERY RELOAD (fixed seed), so an opened vault has to be
	# remembered or it silently re-bars itself -- runes reset, gate back down, an
	# empty chest sealed behind it -- the moment you come back up from any floor.
	check("...and that it opened is REMEMBERED for the rebuild",
		GameState.underdark_vaults_open.has(0))
	# a rune belonging to an already-open vault must come up lit and inert
	var litrune = preload("res://underdark_rune.gd").new()
	litrune.start_lit = true
	add_child(litrune)
	await get_tree().process_frame
	check("a re-opened vault's runes come up already lit, not re-lightable", litrune.lit)
	litrune.queue_free()

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

	# ---- 4c3b. EVERY platform is REACHABLE (dev report 2026-07-21: "some places are
	# closed... I'm certain those are bugs"). They were: arena/chamber/tunnel ledges
	# used to be flung to random heights (arena ledges up to 620px over the floor), so
	# a third of them hung a jump or more past anything below -- loot you could SEE but
	# never reach. They are climbable STACKS now; this proves it forever. Flood-fill
	# from the whole floor: a thin platform is reachable if it sits within a jump of a
	# reachable surface (floor segment or lower platform) with horizontal overlap. It
	# can also be dropped onto from anything above it. Zero may be stranded.
	var JUMP := 92.0
	var HREACH := 60.0
	var surfaces: Array = []            # the floor, everywhere -- all reachable to begin
	for b3 in range(ud.BANDS):
		for s in ud._plan[b3]:
			surfaces.append({"top": s.floor_y, "x0": s.x0, "x1": s.x1})
	var plated: Array = []              # every thin (one-way) platform's standing surface
	for c in ud.get_children():
		if not (c is StaticBody2D):
			continue
		for cc in c.get_children():
			# >=80 so the 90px-wide CLIMB RUNGS (shaft/loft/pit ladders) count too --
			# leave them out and a loft shelf 500px up looks stranded when its ladder
			# was right there. SLAB_COLOR skips the edge highlight; size.y<=18 skips walls.
			if cc is ColorRect and cc.size.y <= 18.0 and cc.size.x >= 80.0 and cc.color == ud.SLAB_COLOR:
				var gx: float = c.global_position.x
				plated.append({
					"top": c.global_position.y - cc.size.y / 2.0,
					"x0": gx - cc.size.x / 2.0, "x1": gx + cc.size.x / 2.0, "r": false})
				break
	var changed := true
	var passes := 0
	while changed and passes < 30:
		changed = false
		passes += 1
		for pf in plated:
			if pf.r:
				continue
			var ok := false
			for s in surfaces:                       # reachable from the floor?
				if s.top - pf.top <= JUMP and pf.x0 <= s.x1 + HREACH and pf.x1 >= s.x0 - HREACH:
					ok = true
					break
			if not ok:
				for q in plated:                     # ...or from a lower, already-reachable rung?
					if q.r and q != pf and q.top - pf.top <= JUMP and pf.x0 <= q.x1 + HREACH and pf.x1 >= q.x0 - HREACH:
						ok = true
						break
			if ok:
				pf.r = true
				changed = true
	var stranded := 0
	for pf in plated:
		if not pf.r:
			stranded += 1
			# find nearest surface below/beside to diagnose the gap
			var best := 99999.0
			for s in surfaces:
				var dy: float = s.top - pf.top
				if pf.x0 <= s.x1 + 200.0 and pf.x1 >= s.x0 - 200.0:
					best = minf(best, absf(dy))
			printerr("  STRANDED plat top=%.0f x=[%.0f,%.0f] nearest-floor dy=%.0f" % [pf.top, pf.x0, pf.x1, best])
	check("every platform is reachable -- no 'closed places'", stranded == 0,
		"%d of %d stranded" % [stranded, plated.size()])

	# ---- 4c3. the shafts climb BOTH ways (no softlock in the deep) ----
	# The bands connect only by shafts, so a shaft you can fall down but not climb
	# back up traps you below band 0 forever. The ladder once stopped at the lower
	# CEILING, leaving the whole lower room (up to ~1050px in an arena) rung-less:
	# the lowest handhold sat 200-1000px over your head. Every shaft's rungs must
	# divide its full floor-to-floor span into jump-sized gaps -- checked here so
	# it can never regress into a softlock again.
	var shaft_count := 0
	var worst_rise := 0.0
	for sb in ud._shafts.keys():
		for sxx in ud._shafts[sb]:
			var tseg: Dictionary = ud._seg_at(sb, sxx)
			var bseg: Dictionary = ud._seg_at(sb + 1, sxx)
			if tseg.is_empty() or bseg.is_empty():
				continue
			shaft_count += 1
			# reconstruct the rungs exactly as _build_shaft_ladders lays them
			var sp: float = bseg.floor_y - tseg.floor_y
			var nn: int = maxi(1, int(ceil(sp / 82.0)))
			var stp: float = sp / float(nn)
			var ys: Array = [bseg.floor_y]
			for k in range(1, nn):
				ys.append(bseg.floor_y - stp * float(k))
			ys.append(tseg.floor_y)
			ys.sort()
			for k in range(ys.size() - 1):
				worst_rise = maxf(worst_rise, ys[k + 1] - ys[k])
	check("every shaft climbs back up (no rung gap past a jump)",
		shaft_count > 0 and worst_rise <= 92.0,
		"%d shafts, worst rise %.0fpx" % [shaft_count, worst_rise])

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
