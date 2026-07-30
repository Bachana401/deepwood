extends Node
# ── THE UNDERGROUND MAP (rework 2026-07-30) ───────────────────────────────────
# Locks the four things the dev walked into and reported:
#   1 the way down was a bare vertical shaft -- step off the entry ledge and take
#     ~115 fall damage, with 749 of 1195 rows below having nothing to stand on
#   2 70% of mobs spawned INSIDE solid rock, frozen where they woke up
#   3 each floor's door was hashed to a random x across the whole width, so
#     consecutive levels averaged a 1384-tile hop -- the map felt scattered
#   4 water was a flat rectangle you walked through
#
# The deep geometry is measured in full by tool_ug_scan.gd; this is the fast
# regression guard, plus the in-engine half (swimming, the air meter, unsticking)
# that a bare generator cannot check.
#
#   MONARCH_TEST="res://test_underground_node.gd" Godot.exe --headless --path .

const UG := preload("res://underground.gd")

var pass_count := 0
var fail_count := 0

func check(label: String, ok: bool) -> void:
	if ok:
		pass_count += 1
		printerr("PASS  " + label)
	else:
		fail_count += 1
		printerr("FAIL  " + label)

func _ready() -> void:
	_test_generator()
	await _test_in_engine()
	printerr("RESULT: %s   (%d passed, %d failed)"
		% ["ALL PASS" if fail_count == 0 else "FAILURES", pass_count, fail_count])
	get_tree().quit(1 if fail_count > 0 else 0)

# ══ the world as generated (no scene needed) ═════════════════════════════════
func _test_generator() -> void:
	# PIN THE WORLD. reset_for_new_game() now rolls a fresh world_seed, and the
	# MONARCH_TEST hook calls it -- so without this every run measured a different
	# map and the thresholds below passed or failed on luck. Seed 0 is the fixed
	# reference world these numbers were tuned against; the seed VARIATION is
	# tested deliberately at the end.
	GameState.world_seed = 0
	var ug = UG.new()
	ug._init_noise()

	# ── 1. THE DELVER'S ROAD IS WALKABLE ──
	var path: Array = ug._path
	check("the road was built", path.size() > 4000)
	var worst_fall := 0
	var blocked := 0
	for i in range(0, path.size(), 3):            # every third cell is plenty
		var c: Vector2i = path[i]
		for h in range(1, 5):                     # the player is 4 tiles tall
			if _solid(ug, c.x, c.y - h):
				blocked += 1
				break
		if not _solid(ug, c.x, c.y):
			var drop := 0
			while drop < 60 and ug._gen_kind(c.x, c.y + 1 + drop) == UG.AIR:
				drop += 1
			worst_fall = maxi(worst_fall, drop)
	check("the player fits along the whole road", blocked == 0)
	# THE GUARANTEE IS "NO FALL DAMAGE", not "no fall". Where two passes of the
	# road run close, one loses its floor to the other's headroom, and the honest
	# fix is to let you drop onto the road below rather than to seal that lower
	# corridor off (which measured 14-15 impassable cells across seeds). Those
	# drops top out around 10 tiles = 120px: no damage, and you land back on the
	# route, one switchback further down. 25 tiles is the 300px damage line.
	check("no fall on the road costs health (worst %d tiles = %d px)"
		% [worst_fall, worst_fall * UG.TILE], worst_fall <= 25)

	# ── 1b. YOU CANNOT DIG STRAIGHT DOWN AND SKIP THE ROUTE ──
	# The bed is only ROAD_BED thick and what lay under it used to be whatever the
	# noise felt like -- usually open cavern. Two pickaxe swings from the trail
	# dropped you into a void, skipping the whole winding chain. ROAD_UNDER puts a
	# deep apron of rock beneath it: tunnelling down stays possible, it just costs
	# real time, so the road is the sane way to travel rather than the only one.
	var dig_total := 0
	var dig_n := 0
	var breakthroughs := 0
	for i in range(0, path.size(), 11):
		var c: Vector2i = path[i]
		var top := c.y
		while top < c.y + 4 and not _solid(ug, c.x, top):
			top += 1                              # stair lips: the real floor is lower
		var run := 0
		while run < 90 and _solid(ug, c.x, top + run):
			run += 1
		dig_total += run
		dig_n += 1
		if run < 6:
			var drop := 0
			while drop < 120 and ug._gen_kind(c.x, top + run + drop) == UG.AIR:
				drop += 1
			if drop > 7:
				# WHAT you break into is the whole question. Landing on the road's
				# own lower corridor is not a bypass -- it's a shortcut between two
				# switchbacks of the route you were already on, and it costs you the
				# climb back. Breaking into unrelated natural cave IS the bypass the
				# dev asked to close, so that is what this counts.
				var land: int = top + run + drop
				if not (ug._in_span(ug._road_air, land, c.x)
						or ug._in_span(ug._road_air, land - 1, c.x)
						or ug._gen_kind(c.x, land) == UG.WATER):
					breakthroughs += 1
	var mean_dig := int(float(dig_total) / maxf(1.0, float(dig_n)))
	check("the road rides on real mass (mean %d tiles to dig through)" % mean_dig, mean_dig >= 9)
	check("digging down never bypasses the route into open cave (%d spots)" % breakthroughs,
		breakthroughs == 0)

	# ── 2. THE CHAIN ──
	check("100 floor doors exist", ug._doors.size() == 100)
	var worst_hop := 0
	var backwards := 0
	for L in range(1, ug._doors.size()):
		var a: Vector2i = ug._doors[L - 1]
		var b: Vector2i = ug._doors[L]
		worst_hop = maxi(worst_hop, absi(b.x - a.x))
		if b.y < a.y:
			backwards += 1
	check("consecutive doors stay near each other (worst hop %d tiles)" % worst_hop,
		worst_hop <= UG.DOOR_HOP_MAX + 4)
	check("the chain only ever goes deeper", backwards == 0)
	var unstandable := 0
	for i in range(ug._doors.size()):
		var d: Vector2i = ug._door_stand(ug._doors[i])
		if not _solid(ug, d.x, d.y) or _solid(ug, d.x, d.y - 1):
			unstandable += 1
	check("every door has ground to stand on", unstandable == 0)

	# ── 3. SPAWN SPOTS FIT A REAL BODY ──
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var found := 0
	var stuck := 0
	for i in range(260):
		var c := Vector2i(rng.randi_range(6, int(UG.WIDTH / UG.CHUNK) - 6),
			rng.randi_range(1, int(UG.DEPTH / UG.CHUNK) - 1))
		var cell = ug._find_floor_cell(c, rng)
		if cell == null:
			continue
		found += 1
		if not _body_fits(ug, cell, 28, 40, UG.MOB_FEET_OFF):
			stuck += 1
	check("spawn spots were found at all", found > 20)
	check("no spawn spot embeds a mob in rock (%d of %d)" % [stuck, found], stuck == 0)

	# ── 4. WATER ──
	check("lakes were carved", ug._lakes.size() > 400)
	var water := 0
	var open := 0
	for y in range(60, UG.DEPTH - 60, 17):
		for x in range(400, 3800, 23):
			var k: int = ug._gen_kind(x, y)
			if k == UG.WATER:
				water += 1
				open += 1
			elif k == UG.AIR:
				open += 1
	var share := 100.0 * float(water) / maxf(1.0, float(open))
	check("water fills a good share of the caves (%.1f%%)" % share, share >= 12.0)
	# and a lake must actually HOLD it -- rock under every water cell's basin
	var leaks := 0
	for lk in ug._lakes:
		var c: Vector2i = lk.c
		var bottom: int = c.y + int(lk.d) + 1
		if not _solid(ug, c.x, bottom):
			leaks += 1
	check("no lake is missing its floor (%d leaks)" % leaks, leaks == 0)
	# ── 5. A SEED MAKES A WORLD ──
	# Every field used to be a hardcoded constant, so every playthrough on every
	# machine generated the identical map. Two different seeds must now differ
	# everywhere that matters, and one seed must reproduce itself exactly.
	var doors_a: Array = ug._doors.duplicate()
	GameState.world_seed = 0x1234
	var ug_b = UG.new()
	ug_b._init_noise()
	var same_door := 0
	for i in range(mini(doors_a.size(), ug_b._doors.size())):
		if doors_a[i] == ug_b._doors[i]:
			same_door += 1
	check("a different seed lays a different chain (%d/100 doors shared)" % same_door, same_door <= 2)
	var diff := 0
	var n := 0
	for y in range(80, UG.DEPTH - 80, 29):
		for x in range(500, 3700, 37):
			n += 1
			if ug._gen_kind(x, y) != ug_b._gen_kind(x, y):
				diff += 1
	check("a different seed carves different rock (%.0f%% of cells differ)"
		% [100.0 * float(diff) / maxf(1.0, float(n))], float(diff) / maxf(1.0, float(n)) > 0.25)
	# ...and the same seed is the same world, or a save could never be reloaded
	var ug_c = UG.new()
	ug_c._init_noise()
	var mismatch := 0
	for y in range(80, UG.DEPTH - 80, 61):
		for x in range(500, 3700, 71):
			if ug_c._gen_kind(x, y) != ug_b._gen_kind(x, y):
				mismatch += 1
	check("the same seed rebuilds the same world", mismatch == 0)
	GameState.world_seed = 0
	ug_b.free()
	ug_c.free()
	ug.free()

func _solid(ug, x: int, y: int) -> bool:
	var k: int = ug._gen_kind(x, y)
	return k != UG.AIR and k != UG.WATER

func _body_fits(ug, cell: Vector2i, w: int, h: int, off_y: float) -> bool:
	var cx := float(cell.x) * UG.TILE + UG.TILE * 0.5
	var cy := float(cell.y) * UG.TILE + UG.TILE * 0.5 + off_y
	for y in range(int(floor((cy - h * 0.5) / UG.TILE)), int(floor((cy + h * 0.5 - 1) / UG.TILE)) + 1):
		for x in range(int(floor((cx - w * 0.5) / UG.TILE)), int(floor((cx + w * 0.5 - 1) / UG.TILE)) + 1):
			if _solid(ug, x, y):
				return false
	return true

# ══ the live scene: swimming, air, the unstick sweep ═════════════════════════
func _test_in_engine() -> void:
	get_tree().change_scene_to_file.call_deferred("res://underground.tscn")
	var p: Node = null
	for i in range(900):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	var ug = get_tree().get_first_node_in_group("tile_world")
	check("the underground booted with a player", p != null and ug != null)
	if p == null or ug == null:
		return
	# the hero's carried torch has to be lit down here or the caves are unreadable
	if "player_light" in p and p.player_light != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
		check("the carried torch is lit in the tile world", p.player_light.enabled)

	# ── drop the player into a lake and see them swim ──
	var lake: Dictionary = {}
	for lk in ug._lakes:
		if bool(lk.big) and int(lk.d) >= 14:
			lake = lk
			break
	check("a deep lake exists to test in", not lake.is_empty())
	if lake.is_empty():
		return
	var c: Vector2i = lake.c
	var mid := Vector2i(c.x, c.y + int(lake.d) / 2)
	check("the middle of a lake really is water", ug._gen_kind(mid.x, mid.y) == UG.WATER)
	p.global_position = ug._map.to_global(ug._map.map_to_local(mid))
	p.velocity = Vector2(0, 900.0)                # falling fast
	for i in range(8):
		await get_tree().physics_frame
	check("water slows the fall to a sink (%.0f px/s)" % p.velocity.y, p.velocity.y <= UG.SWIM_SINK + 1.0)
	var air_start: float = ug._breath
	for i in range(30):
		await get_tree().physics_frame
	check("air drains while submerged", ug._breath < air_start)
	check("the air meter is showing", ug._breath_bar != null and ug._breath_bar.visible)
	# ...and comes back on dry land
	var dry: Vector2i = ug._door_stand(ug._doors[0])
	p.global_position = ug._map.to_global(ug._map.map_to_local(dry - Vector2i(0, 2)))
	for i in range(40):
		await get_tree().physics_frame
	check("air refills out of the water", ug._breath > air_start - 0.5)

	# ── a mob sealed in rock is freed, not left frozen ──
	var e = preload("res://enemy.tscn").instantiate()
	e.add_to_group("course_enemy")
	ug.add_child(e)
	var buried := Vector2i(dry.x, dry.y + 6)      # under the road bed, in the rock
	e.global_position = ug._map.to_global(ug._map.map_to_local(buried))
	var was: Vector2 = e.global_position
	ug._unstick_cd = 0.0
	for i in range(20):
		await get_tree().process_frame
	check("a mob buried in rock is moved or removed",
		not is_instance_valid(e) or e.global_position != was)
