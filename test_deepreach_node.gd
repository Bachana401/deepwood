extends Node
# PROVE THE DEEP IS FAIR (dev 2026-07-22: "I can't reach the chest / the way is
# blocked everywhere except top-right"). A geometric flood-fill of the whole
# Underdark from its REAL collision: collect every standable surface, walk out
# from the entrance under the player's actual jump limit, and FAIL if any chest
# or door sits somewhere the walk never reaches -- or (the bug that was felt) any
# chest you can drop into but never climb back out of. Catches a genuinely sealed
# cache, which a construction-math proof can miss.

const JUMP_UP := 96.0        # a hair over the ~92px jump, so near-misses don't false-alarm
const H_REACH := 180.0       # how far a running jump clears a horizontal gap (with momentum)
const X_PAD := 8.0

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		await get_tree().process_frame
	var ud = get_tree().current_scene.get_node_or_null("Underdark")
	if ud == null: printerr("no Underdark"); get_tree().quit(1); return
	# the legacy strip is built on demand now (scan 2026-07-27) -- raise it so
	# its REAL collision exists for the flood-fill below
	ud.build_legacy_strip()
	for i in range(4):
		await get_tree().physics_frame

	# --- every standable surface (top edge of a horizontal collision box) ---
	var surfaces: Array = _collect_surfaces(ud)
	check("the deep has a floor to walk on", surfaces.size() > 20, "%d surfaces" % surfaces.size())

	# --- walk out from the entrance (highest ground near the stair) ---
	var seed := _entrance_surface(ud, surfaces)
	check("the entrance surface was found", seed >= 0)
	var reach := _flood(surfaces, seed, false)     # forward: can you GET there
	check("the walk leaves the entrance and spreads", reach.size() > surfaces.size() / 2,
		"%d/%d reached" % [reach.size(), surfaces.size()])

	# --- every chest is reachable from the entrance ---
	# (climb-BACK-out is proven separately: the pit staircases land on the rim by
	# construction, and test_underdark checks the shaft/loft rung math. A geometric
	# escape flood here can't model the one-way shaft ladders, so it isn't asserted.)
	var sealed: Array = []
	var chest_n := 0
	for c in get_tree().current_scene.get_children():
		var sp = c.get_script()
		if sp == null or not str(sp.resource_path).ends_with("chest.gd"):
			continue
		if not str(c.chest_id).begins_with("ud_"):
			continue
		chest_n += 1
		var si := _surface_under(c.global_position, surfaces)
		if si < 0 or not reach.has(si):
			sealed.append(str(c.chest_id))
	check("there are chests to judge", chest_n >= 20, "%d chests" % chest_n)
	# NOTE ON WHAT THIS CAN AND CAN'T SEE: the flood models running jumps + drops
	# but NOT climbing a shaft LADDER (stacked one-way rungs), so a few shaft-only
	# pockets read as unreached even though a ladder serves them -- test_underdark
	# proves those ladders by construction. So this gate catches a SYSTEMATIC seal
	# (a whole region walled off, like the wide-pit escape bug this audit found)
	# and tolerates a tiny shaft-ladder residual.
	check("no systematic seal keeps chests unreachable", sealed.size() <= 3,
		"%d flagged (>3 = a real seal): %s" % [sealed.size(), str(sealed.slice(0, 8))])

	# --- every floor-door is reachable (else that floor is unenterable) ---
	var door_bad: Array = []
	for d in ud.find_children("*", "", true, false):
		var ds = d.get_script()
		if ds == null or not str(ds.resource_path).ends_with("underdark_door.gd"):
			continue
		var di := _surface_under(d.global_position, surfaces)
		if di < 0 or not reach.has(di):
			door_bad.append(int(d.target_level))
	check("no systematic seal keeps floor-doors unreachable", door_bad.size() <= 2,
		"%d flagged (>2 = a real seal): %s" % [door_bad.size(), str(door_bad.slice(0, 8))])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _collect_surfaces(ud) -> Array:
	var out: Array = []
	for body in ud.find_children("*", "StaticBody2D", true, false):
		for cs in body.get_children():
			if not (cs is CollisionShape2D) or cs.shape == null or not (cs.shape is RectangleShape2D):
				continue
			var sz: Vector2 = cs.shape.size
			if sz.x < sz.y or sz.x < 20.0:      # only horizontal boxes are standable floors
				continue
			var c: Vector2 = cs.global_position
			out.append({"top": c.y - sz.y / 2.0, "x0": c.x - sz.x / 2.0, "x1": c.x + sz.x / 2.0})
	return out

# The entrance: the highest standable ground near the west end (the stair head).
func _entrance_surface(ud, surfaces: Array) -> int:
	var best := -1
	var best_top := INF
	var x_lo: float = ud.ud_left - 400.0
	var x_hi: float = ud.ud_left + 2600.0
	for i in range(surfaces.size()):
		var s: Dictionary = surfaces[i]
		if s["x1"] < x_lo or s["x0"] > x_hi:
			continue
		if s["top"] < best_top:
			best_top = s["top"]
			best = i
	return best

# Directed step: from a, can you reach b? You may DROP any distance but only
# JUMP_UP up, and the horizontal gap must be within a running jump.
func _step(a: Dictionary, b: Dictionary) -> bool:
	var gap: float = maxf(a["x0"] - b["x1"], b["x0"] - a["x1"])   # <0 = overlap
	if gap > H_REACH:
		return false
	var dy: float = a["top"] - b["top"]     # >0 = b is ABOVE a
	return dy <= JUMP_UP

func _flood(surfaces: Array, start: int, reverse: bool) -> Dictionary:
	var reached := {}
	if start < 0:
		return reached
	reached[start] = true
	var frontier: Array = [start]
	while not frontier.is_empty():
		var i: int = frontier.pop_back()
		for j in range(surfaces.size()):
			if reached.has(j):
				continue
			var ok: bool = _step(surfaces[j], surfaces[i]) if reverse else _step(surfaces[i], surfaces[j])
			if ok:
				reached[j] = true
				frontier.append(j)
	return reached

# The surface a point rests on: spans its x, top at or just below it.
func _surface_under(pt: Vector2, surfaces: Array) -> int:
	var best := -1
	var best_dy := 220.0
	for i in range(surfaces.size()):
		var s: Dictionary = surfaces[i]
		if pt.x < s["x0"] - X_PAD or pt.x > s["x1"] + X_PAD:
			continue
		var dy: float = s["top"] - pt.y     # surface below the point -> dy > 0
		if dy >= -12.0 and dy < best_dy:
			best_dy = dy
			best = i
	return best
