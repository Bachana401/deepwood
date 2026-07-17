extends Node

# The 22 boss arenas.
#
# The bug this suite exists to prevent: generate_boss_platforms used to end in
# `_: return gen_gravewarden(w, h)`, so 12 of the 22 bosses fought in the SAME
# tomb. Nothing looked broken -- the room rendered fine, the fight worked, and
# the duplication was invisible from inside the game. It was the CYCLING_BOSSES
# modulo all over again, one layer down.
#
# So the load-bearing check here is DISTINCTNESS, and the rest assert that each
# arena actually carries the geometry its boss's mechanics need. An arena that
# ignores its boss is decoration (BOSSES.md).

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

# a layout's fingerprint, for "are these two rooms actually the same room?"
func sig(layout: Array) -> String:
	var parts: Array = []
	for p in layout:
		parts.append("%d,%d,%d,%s" % [int(p.x), int(p.y), int(p.w), p.get("solid", false)])
	return "|".join(parts)

func solids(layout: Array) -> Array:
	return layout.filter(func(p): return p.get("solid", false))

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	# Dismiss the opening plea. The tree is PAUSED until it finishes, and
	# physics_frame still fires while paused -- so without this a test loop spins
	# happily, no node ever processes, and every behavioural check quietly fails
	# for a reason that has nothing to do with the code under test.
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break
	check("the tree is actually running (not paused by the opening plea)",
		not get_tree().paused)

	var DI = load("res://dungeon_interior.gd")
	var di = DI.new()
	var ladder: Dictionary = DI.BOSS_LADDER
	var arenas: Dictionary = DI.BOSS_ARENAS

	# ---------------- COVERAGE ----------------
	var missing: Array = []
	for lv in ladder.keys():
		if not arenas.has(ladder[lv]):
			missing.append("%d/%s" % [lv, ladder[lv]])
	check("every boss on the ladder has its own arena", missing.is_empty(),
		"no arena for: %s" % ", ".join(missing))
	check("the ladder is the full 22 floors", ladder.size() == 22, "%d" % ladder.size())

	# ---------------- DISTINCTNESS (the fallback-clone trap) ----------------
	var seen := {}
	var dupes: Array = []
	var layouts := {}
	for lv in ladder.keys():
		var bid: String = ladder[lv]
		var a: Dictionary = arenas.get(bid, {})
		var layout: Array = di.generate_boss_platforms(bid,
			a.get("width", DI.DUNGEON_WIDTH), a.get("height", DI.CEILING_Y))
		layouts[bid] = layout
		check("%s: its arena is not empty" % bid, layout.size() > 0)
		var s := sig(layout)
		if seen.has(s):
			dupes.append("%s == %s" % [bid, seen[s]])
		seen[s] = bid
	check("no two bosses fight in the same room", dupes.is_empty(),
		"identical layouts: %s" % ", ".join(dupes))

	# every arena's footprint is its own too (not just the platforms)
	var box_seen := {}
	var box_dupes: Array = []
	for bid in arenas.keys():
		var a: Dictionary = arenas[bid]
		var box := "%d x %d" % [int(a["width"]), int(a["height"])]
		if box_seen.has(box):
			box_dupes.append("%s == %s (%s)" % [bid, box_seen[box], box])
		box_seen[box] = bid
	# shared footprints are allowed, but flag if MOST of them collide
	check("arena footprints are mostly distinct", box_dupes.size() <= arenas.size() / 3,
		"%d/%d share a footprint: %s" % [box_dupes.size(), arenas.size(), ", ".join(box_dupes)])

	# ---------------- IN BOUNDS ----------------
	var oob: Array = []
	for bid in layouts.keys():
		var a: Dictionary = arenas[bid]
		var aw: float = a["width"]
		var ah: float = a["height"]
		for pl in layouts[bid]:
			var half: float = pl.w / 2.0
			if pl.x - half < 0.0 or pl.x + half > aw:
				oob.append("%s x=%d" % [bid, int(pl.x)])
				break
			# ah is the CEILING (negative, up). y must sit between it and the floor.
			if pl.y > DI.GROUND_Y or pl.y < ah:
				oob.append("%s y=%d (ceiling %d)" % [bid, int(pl.y), int(ah)])
				break
	check("no platform sits outside its arena", oob.is_empty(), ", ".join(oob))

	# ---------------- TRAVERSABLE (the uncompletable-room trap) ----------------
	# In a side-scroller you cannot walk AROUND a pillar. A floor-rooted solid
	# taller than the player's jump is a wall between him and the exit gate, and
	# the floor simply cannot be finished -- while still looking completely
	# normal. The first draft of these arenas had 300-tall pillars in five rooms.
	# Measured, not assumed: rise = JUMP_VELOCITY^2 / 2*GRAVITY (test_jump_node
	# confirms ~92px in the real scene).
	var vault: float = (p.JUMP_VELOCITY * p.JUMP_VELOCITY) / (2.0 * p.GRAVITY)
	check("the player's jump still clears our cover ceiling",
		DI.VAULT_HEIGHT <= vault, "VAULT_HEIGHT=%d but he can only rise %d" % [
			int(DI.VAULT_HEIGHT), int(vault)])
	var walls: Array = []
	for bid in layouts.keys():
		for pl in solids(layouts[bid]):
			var top: float = pl.y - pl.h / 2.0          # y is the CENTRE
			var rise: float = absf(top - DI.GROUND_Y)
			if rise > vault:
				walls.append("%s: %dpx tall at x=%d" % [bid, int(rise), int(pl.x)])
				break
	check("no arena builds a wall the player cannot vault", walls.is_empty(),
		"uncompletable rooms -> %s" % ", ".join(walls))

	# Cover must not block the doorways either.
	var blocked_door: Array = []
	for bid in layouts.keys():
		for pl in solids(layouts[bid]):
			if pl.x - pl.w / 2.0 < DI.ENTRY_X + 60.0:
				blocked_door.append(bid)
				break
	check("no cover sits on top of the entry door", blocked_door.is_empty(),
		", ".join(blocked_door))

	# ---------------- MECHANIC-DRIVEN GEOMETRY ----------------
	# These are the point. Each asserts the room was built AGAINST its boss.

	# Warden of Nails: BOSSES.md's own worked example -- skyfall wants a LOW
	# ceiling and pillars, or it means nothing.
	var warden: float = arenas["warden_of_nails"]["height"]
	var lowest := true
	for bid in arenas.keys():
		if bid != "warden_of_nails" and arenas[bid]["height"] > warden:
			lowest = false
	check("skyfall (warden_of_nails): lowest ceiling in the game", lowest,
		"%d" % int(warden))
	check("skyfall (warden_of_nails): the ceiling is inside SKYFALL_RADIUS",
		absf(warden - DI.GROUND_Y) < 600.0, "%d of clearance" % int(absf(warden - DI.GROUND_Y)))
	check("dread_ward (warden_of_nails): pillars to flank around",
		solids(layouts["warden_of_nails"]).size() >= 8,
		"%d" % solids(layouts["warden_of_nails"]).size())
	# The room offers height and height is death: no perch in it escapes
	# skyfall's 320 reach, so climbing is never the answer here.
	var warden_high := 0.0
	for pl in layouts["warden_of_nails"]:
		warden_high = minf(warden_high, pl.y)
	check("skyfall (warden_of_nails): every perch is still inside SKYFALL_RADIUS",
		absf(warden_high - DI.GROUND_Y) < 320.0,
		"highest perch is %d above the floor" % int(absf(warden_high - DI.GROUND_Y)))

	# Gaoler: the tether is a line of sight, so cover must exist AND sit inside
	# the leash -- cover you cannot reach while chained is scenery.
	var gaoler_cover := solids(layouts["gaoler"])
	check("tether (gaoler): a real pillar forest", gaoler_cover.size() >= 15,
		"%d pillars" % gaoler_cover.size())
	var max_gap := 0.0
	for i in range(1, gaoler_cover.size()):
		max_gap = maxf(max_gap, absf(gaoler_cover[i].x - gaoler_cover[i - 1].x))
	check("tether (gaoler): cover spaced inside TETHER_RANGE (420)", max_gap < 420.0,
		"widest gap %d" % int(max_gap))

	# Mirror bosses turn your own shots around: you need something to break them on.
	for bid in ["mourncaller", "glass_saint", "cinderking"]:
		check("mirror (%s): cover to break your returning shot on" % bid,
			solids(layouts[bid]).size() >= 4, "%d" % solids(layouts[bid]).size())

	# Covenant: split your damage between two bodies -> the room must not favour
	# a side, or the mechanic resolves itself.
	var td: Array = layouts["twin_despair"]
	var tw: float = arenas["twin_despair"]["width"]
	var asym: Array = []
	for pl in td:
		var mirrored := false
		for q in td:
			if absf(q.x - (tw - pl.x)) < 1.0 and absf(q.y - pl.y) < 1.0 and absf(q.w - pl.w) < 1.0:
				mirrored = true
				break
		if not mirrored:
			asym.append("%d,%d" % [int(pl.x), int(pl.y)])
	check("covenant (twin_despair): the arena is exactly symmetric", asym.is_empty(),
		"unmirrored: %s" % ", ".join(asym))

	# Rhythm punish: the room must not hand the player a beat to fall into.
	var sf: Array = layouts["sablefang"]
	var gaps: Array = []
	for i in range(1, sf.size()):
		var g := absf(sf[i].x - sf[i - 1].x)
		if g > 1.0:
			gaps.append(round(g))
	var repeats := 0
	for i in range(1, gaps.size()):
		if gaps[i] == gaps[i - 1]:
			repeats += 1
	check("rhythm_punish (sablefang): no two consecutive gaps are equal", repeats == 0,
		"%d repeats" % repeats)
	var uniq := {}
	for g in gaps:
		uniq[g] = true
	check("rhythm_punish (sablefang): the room has no rhythm to find",
		uniq.size() >= 8, "only %d distinct gaps" % uniq.size())

	# False twin: the tell is a shadow on the FLOOR. Clutter the floor and the
	# mechanic is unreadable; give no high ground and it is unfindable.
	var hc: Array = layouts["hollow_choir"]
	var hw: float = arenas["hollow_choir"]["width"]
	var floor_clutter := hc.filter(func(pl):
		return pl.y > -350.0 and absf(pl.x - hw / 2.0) < hw * 0.3)
	check("false_twin (hollow_choir): the central floor is left bare to read shadows on",
		floor_clutter.is_empty(), "%d things in the way" % floor_clutter.size())
	check("false_twin (hollow_choir): galleries high enough to look down from",
		hc.any(func(pl): return pl.y < -400.0 and pl.w >= 300.0))

	# Phase + traps: nowhere to plant your feet and wait it out.
	var un: Array = layouts["unseen"]
	var widest := 0.0
	for pl in un:
		widest = maxf(widest, pl.w)
	check("phase (unseen): no wide standing room anywhere", widest <= 175.0,
		"widest platform %d" % int(widest))

	# Famine drains mana within 120: the Prayer Well's ledges must be free ground.
	var ap: Array = layouts["ashen_penitent"]
	var apw: float = arenas["ashen_penitent"]["width"]
	check("famine (ashen_penitent): mana-safe ledges well outside FAMINE_RADIUS",
		ap.any(func(pl): return absf(pl.x - apw / 2.0) > 400.0))
	check("riposte (ashen_penitent): a tall shaft to retreat up and read the tell",
		arenas["ashen_penitent"]["height"] < -1100.0)

	# ---------------- COVER IS REAL, NOT PAINTED ----------------
	# A solid pillar has to actually stop a tether, or the Gaoler's whole arena
	# is decoration and the mechanic has no counter-play but running.
	var BS = load("res://boss.gd")
	var host := Node2D.new()
	get_tree().root.add_child(host)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1 | DI.COVER_LAYER
	var wshape := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(60, 400)
	wshape.shape = wrect
	wall.add_child(wshape)
	host.add_child(wall)

	var g = BS.new()
	g.boss_id = "gaoler"
	host.add_child(g)
	await get_tree().process_frame
	g.has_tether = true
	g.player = p
	# boss on one side, player on the other, wall between: within TETHER_RANGE
	# the whole time, so ONLY the cover can explain a break
	g.global_position = p.global_position + Vector2(-200, 0)
	wall.global_position = p.global_position + Vector2(-100, 0)
	await get_tree().physics_frame
	check("cover: the boss cannot see through a pillar", g._sight_to_player_blocked())
	# same distance, no wall in the way
	wall.global_position = p.global_position + Vector2(-100, -2000)
	await get_tree().physics_frame
	check("cover: with the pillar moved away it sees you again",
		not g._sight_to_player_blocked())
	# and an ordinary drop-through ledge must NOT block sight, or the tether
	# would snap on scenery in every arena in the game
	var ledge := StaticBody2D.new()
	var lshape := CollisionShape2D.new()
	var lrect := RectangleShape2D.new()
	lrect.size = Vector2(60, 400)
	lshape.shape = lrect
	lshape.one_way_collision = true
	ledge.add_child(lshape)
	host.add_child(ledge)
	ledge.global_position = p.global_position + Vector2(-100, 0)
	await get_tree().physics_frame
	check("cover: a plain one-way ledge does NOT block sight (scenery trap)",
		not g._sight_to_player_blocked())

	# the tether itself snaps on cover
	ledge.queue_free()
	g.tether_active = true
	g.tether_anchor = p.global_position
	g.tether_next_at = g._time_now() + 999.0
	for i in range(8):
		# Re-pin every frame: the boss CHASES, so left alone it simply walks out
		# from behind the wall and the break stops being about cover at all.
		g.global_position = p.global_position + Vector2(-200, 0)
		g.velocity = Vector2.ZERO
		wall.global_position = p.global_position + Vector2(-100, 0)
		await get_tree().physics_frame
		if not g.tether_active:
			break
	check("tether: ducking behind cover BREAKS the chain (counter-play)",
		not g.tether_active)

	di.free()
	# ---------------- IT ACTUALLY BUILDS (KEEP THIS LAST) ----------------
	# Everything above reads generated DATA. This builds all 22 boss floors for
	# real, because a layout that generates cleanly can still blow up on the way
	# to being nodes -- and a boss floor that crashes is one the player cannot
	# ever finish.
	#
	# It MUST stay at the bottom: building a floor teleports the player, spawns
	# its boss and its adds, and generally takes the world apart. Run it before
	# the live checks above and they fail for reasons that have nothing to do
	# with what they are testing -- which is exactly what happened when this
	# block sat in the middle.
	var DSCN = load("res://dungeon_interior.tscn")
	var built_ok := true
	var cover_seen := 0
	var detail := ""
	for lv in ladder.keys():
		GameState.active_dungeon_level = lv
		var d = DSCN.instantiate()
		get_tree().root.add_child(d)
		await get_tree().process_frame
		var bodies: Array = d.get_node("LevelContainer").find_children("*", "StaticBody2D", true, false)
		if bodies.is_empty():
			built_ok = false
			detail += "floor %d built no geometry; " % lv
		for b in bodies:
			if b.collision_layer & DI.COVER_LAYER:
				cover_seen += 1
		d.queue_free()
		await get_tree().process_frame
	check("all 22 boss floors build for real", built_ok, detail)
	check("cover reaches the built world on COVER_LAYER", cover_seen > 0,
		"%d solid bodies" % cover_seen)
	GameState.in_dungeon = false

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
