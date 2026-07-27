extends Node
# REGULAR FLOOR LAYOUTS (dev report 2026-07-21: "map is 2/10, uncreative... platforms
# weird"). The dungeon used to cycle four hand-placed platform sets; now every floor
# builds its own themed layout. This proves the two promises those themes must keep:
#   1. VARIED -- consecutive floors never share a theme, and the catalogue is deep.
#   2. REACHABLE -- flood-fill from the floor, every one-way ledge on all 100 floors
#      sits within a 92px jump of a reachable surface (floor or lower ledge) with
#      horizontal overlap. Zero stranded (the Underdark "closed places" lesson).
# It calls the pure generator directly -- no scene, no boot -- so it's fast and exact.

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var dgn = load("res://dungeon_interior.gd").new()
	var GROUND: float = dgn.GROUND_Y
	var CEIL: float = dgn.CEILING_Y
	var PH: float = dgn.PLATFORM_HEIGHT
	var WIDTH: float = dgn.DUNGEON_WIDTH
	var JUMP := 92.0
	var HREACH := 64.0

	# ---- 1. VARIETY: neighbours differ, the catalogue is used in full ----
	var themes_seen := {}
	var repeats := 0
	var prev := -1
	for level in range(1, 101):
		if dgn.is_boss_level(level):
			prev = -1
			continue
		var th: int = dgn.get_regular_theme(level)
		themes_seen[th] = int(themes_seen.get(th, 0)) + 1
		if th == prev:
			repeats += 1
		prev = th
	check("no two adjacent floors share a theme", repeats == 0, "%d repeats" % repeats)
	check("the whole theme catalogue is in rotation", themes_seen.size() >= 12,
		"%d distinct themes" % themes_seen.size())

	# ---- 2. REACHABILITY: flood-fill every non-boss floor ----
	var worst_floor := -1
	var worst_stranded := 0
	var total_ledges := 0
	var high_ledge_floors := 0     # floors that offer a real vertical climb
	for level in range(1, 101):
		if dgn.is_boss_level(level):
			continue
		var layout: Array = dgn.generate_regular_layout(level)
		var surfaces: Array = [{"top": GROUND, "x0": 0.0, "x1": WIDTH}]
		var plated: Array = []
		var has_high := false
		for plat in layout:
			if plat.get("solid", false):
				continue                       # cover is an obstacle, not a standing goal
			var ph: float = plat.get("h", PH)
			var top: float = float(plat.y) - ph * 0.5
			var w: float = float(plat.w)
			plated.append({"top": top, "x0": float(plat.x) - w * 0.5, "x1": float(plat.x) + w * 0.5, "r": false})
			total_ledges += 1
			if top < GROUND - 150.0:
				has_high = true
			# no ledge may clip through the ceiling
			if top < CEIL + 20.0:
				check("floor %d has a ledge above the ceiling" % level, false, "top %.0f vs ceil %.0f" % [top, CEIL])
		if has_high:
			high_ledge_floors += 1
		# flood-fill
		var changed := true
		var passes := 0
		while changed and passes < 30:
			changed = false
			passes += 1
			for pf in plated:
				if pf.r:
					continue
				var ok := false
				for s in surfaces:
					if s.top - pf.top <= JUMP and pf.x0 <= s.x1 + HREACH and pf.x1 >= s.x0 - HREACH:
						ok = true
						break
				if not ok:
					for q in plated:
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
		if stranded > worst_stranded:
			worst_stranded = stranded
			worst_floor = level
	check("every ledge on every floor is reachable -- no 'closed places'",
		worst_stranded == 0, "floor %d stranded %d" % [worst_floor, worst_stranded])
	check("the floors are actually built (ledges exist)", total_ledges > 200,
		"%d ledges over 80 floors" % total_ledges)
	check("most floors give a real vertical climb, not just low stones",
		high_ledge_floors >= 40, "%d floors with a high ledge" % high_ledge_floors)

	# ---- 3. THE 92-PIXEL RULE ON SOLIDS -- every floor, BOSS ARENAS INCLUDED ----
	# A side-scroller has no way AROUND a pillar: any SOLID obstacle taller than
	# one jump seals the corridor for good (an uncompletable floor). Regular
	# floors route cover through pillar() (clamped to 88), but that convention
	# had no net under it -- and the flood-fill above skips boss arenas AND
	# every solid, which is exactly where the VAULT_HEIGHT comment says this
	# failure already shipped once. This is that net (audit fix).
	var solid_bad := 0
	var solid_seen := 0
	for level in range(1, 101):
		var layout: Array
		if dgn.is_boss_level(level):
			var bid: String = dgn.get_boss_id(level)
			var adef: Dictionary = dgn.BOSS_ARENAS.get(bid, {})
			layout = dgn.generate_boss_platforms(bid,
				float(adef.get("width", WIDTH)), float(adef.get("height", CEIL)))
		else:
			layout = dgn.generate_regular_layout(level)
		for plat in layout:
			if not plat.get("solid", false):
				continue
			solid_seen += 1
			var sh: float = plat.get("h", PH)
			var stop: float = float(plat.y) - sh * 0.5
			if GROUND - stop > JUMP:
				solid_bad += 1
				check("floor %d: solid obstacle too tall to vault" % level, false,
					"top %.0fpx above the floor (max %.0f)" % [GROUND - stop, JUMP])
	check("every solid obstacle on all 100 floors is vaultable (the 92px rule)",
		solid_bad == 0, "%d of %d solids too tall" % [solid_bad, solid_seen])

	dgn.free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
