extends Node
# ── UNDERGROUND MAP AUDIT (headless) ──────────────────────────────────────────
# Builds a bare underground generator (no scene, no player, no HUD -- the terrain
# is a pure function of the seeds, see underground._init_noise) and MEASURES the
# map the dev actually plays:
#
#   1 DESCENT     is the way down WALKABLE, or does it drop you?
#   2 MOB SPOTS   how many spawn cells embed a 28x40 enemy body in solid rock
#   3 DOOR CHAIN  how far apart consecutive floor-doors sit (1 near 2 near 3...)
#   4 SHAPE       air / water fraction by depth
#
# Run:  MONARCH_TEST="res://tool_ug_scan.gd" Godot.exe --headless --path .

const UG := preload("res://underground.gd")

var ug                                   # the bare generator
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	ug = UG.new()
	ug._init_noise()
	var gen_ms := Time.get_ticks_msec() - t0
	say("")
	say("═══ UNDERGROUND MAP AUDIT ═══  WIDTH=%d  DEPTH=%d  TILE=%d  (built in %d ms)"
		% [UG.WIDTH, UG.DEPTH, UG.TILE, gen_ms])
	_audit_descent()
	_audit_mob_spots()
	_audit_door_chain()
	_audit_shape()
	say("")
	ug.free()
	get_tree().quit(0)

func _solid(x: int, y: int) -> bool:
	var k: int = ug._gen_kind(x, y)
	return k != UG.AIR and k != UG.WATER

func _water(x: int, y: int) -> bool:
	return ug._gen_kind(x, y) == UG.WATER

# ── 1. THE DESCENT ────────────────────────────────────────────────────────────
# Structural checks lie here: a road-bed cell erased at the lip of a stair looks
# identical to one erased by a crossing that opened a hole, and a "nearest
# surface" scan happily hops between two different roads. So don't inspect the
# geometry -- WALK it. Simulate a player leaving the entry chamber and travelling
# the chain door by door, and report the worst thing that happens to them.
const JUMP_UP := 7          # ~89px at GRAVITY 900 / JUMP -400 = 7.4 tiles
const FALL_SAFE := 25       # 300px, the fall-damage threshold in player.gd

# can a 32x48 player stand at (x, y), feet on the cell below?
func _stand_ok(x: int, y: int) -> bool:
	if not _solid(x, y + 1):
		return false
	for h in range(0, 4):
		if _solid(x, y - h):
			return false
	return true

# the standing row nearest `hint` in column x (this is where the player ends up
# after stepping sideways -- up a step, down a step, or off a ledge)
func _stand_row(x: int, hint: int, window: int) -> int:
	for d in range(0, window):
		if _stand_ok(x, hint + d):
			return hint + d
		if d > 0 and _stand_ok(x, hint - d):
			return hint - d
	return -99999

func _audit_descent() -> void:
	say("")
	say("── 1. DESCENT — walking the Delver's Road, cell by cell ──")
	var path: Array = ug._path
	if path.is_empty():
		say("  ⛔ no road was built")
		return
	var blocked := 0                 # a cell the player cannot fit through
	var blocked_at := []
	var holes := 0                   # a cell with no floor under it
	var wet_bed := 0
	var air_bed := 0
	var worst_fall := 0
	var worst_fall_at := Vector2i.ZERO
	var falls_that_hurt := 0
	var total_damage := 0
	var worst_climb := 0
	var worst_climb_at := Vector2i.ZERO
	var prev := -999999
	for i in range(path.size()):
		var c: Vector2i = path[i]
		var feet := c.y - 1                        # standing ON the bed cell c
		# 1. does the player FIT here? (32x48 = 3 tiles wide at the shoulders, 4 tall)
		var fits := true
		for h in range(0, 4):
			if _solid(c.x, feet - h):
				fits = false
				break
		if not fits:
			blocked += 1
			if blocked_at.size() < 5:
				blocked_at.append(c)
		# 2. is there ground under them, and how far down if not?
		if not _solid(c.x, c.y):
			if ug._gen_kind(c.x, c.y) == UG.WATER:
				wet_bed += 1
			else:
				air_bed += 1
			# a fall ENDS at water as surely as at rock -- water breaks your fall in
			# this game (underground._water_tick holds fall_apex at the surface), so
			# counting a plunge into a lake as an 70-tile drop is just wrong
			var drop := 0
			while drop < 300 and ug._gen_kind(c.x, c.y + 1 + drop) == UG.AIR:
				drop += 1
			if drop > 0:
				holes += 1
			if drop > worst_fall:
				worst_fall = drop
				worst_fall_at = c
			if drop > FALL_SAFE:
				falls_that_hurt += 1
				total_damage += int(float(drop * UG.TILE - 300) * 0.15)
		# 3. how steep is the road itself between one cell and the next?
		if prev > -999998:
			var rise := prev - c.y                 # positive = climbing
			if rise > worst_climb:
				worst_climb = rise
				worst_climb_at = c
		prev = c.y
	# the wades: road cells you have to swim. They must sit ON the trail -- anchored
	# to a flat band at the door's row instead, they mostly missed it and painted
	# sealed water boxes into the rock beside it.
	var wade := 0
	for i in range(path.size()):
		var c: Vector2i = path[i]
		if ug._gen_kind(c.x, c.y - 1) == UG.WATER:
			wade += 1
	var flood_cells := 0
	for y in range(ug._road_flood.size()):
		for s in ug._road_flood[y]:
			flood_cells += int(s.y) - int(s.x) + 1
	# THE SHORTCUT TEST: stand on the road, dig straight down. How many tiles
	# before you break into open space? Two meant you could skip the whole route
	# and fall into a cavern.
	var thin := 0
	var min_dig := 9999
	var thin_danger := 0
	var thin_worst := 0
	var thin_at := Vector2i.ZERO
	var dig_total := 0
	var samples := 0
	for i in range(0, path.size(), 7):
		var c: Vector2i = path[i]
		# start at the floor the player is really standing on: at a stair lip the
		# recorded bed cell is air and the ground is a row or two lower
		var top := c.y
		while top < c.y + 4 and not _solid(c.x, top):
			top += 1
		var solid_run := 0
		while solid_run < 90 and _solid(c.x, top + solid_run):
			solid_run += 1
		samples += 1
		dig_total += solid_run
		min_dig = mini(min_dig, solid_run)
		if solid_run < 6:
			thin += 1
			# A thin spot only MATTERS if breaking through drops you a long way --
			# punching into the road's own lower corridor, or into water, is a
			# 7-tile step and no shortcut at all.
			var below := top + solid_run
			var drop := 0
			while drop < 120 and ug._gen_kind(c.x, below + drop) == UG.AIR:
				drop += 1
			if drop > JUMP_UP:
				thin_danger += 1
				if thin_worst < drop:
					thin_worst = drop
					thin_at = Vector2i(c.x, top)
	say("  road length : %d cells (%d px of walking)" % [path.size(), path.size() * UG.TILE])
	say("  DIG-DOWN depth under the road: mean %d tiles, thinnest %d  (spots under 6 tiles: %d of %d)"
		% [int(float(dig_total) / maxf(1.0, float(samples))), min_dig, thin, samples])
	say("  ...of those, ones that DROP you more than a jump: %d   worst %d tiles (%d px) at %s"
		% [thin_danger, thin_worst, thin_worst * UG.TILE, str(thin_at)])
	say("  wades ON the road: %d cells   flood painted in total: %d  (%.0f%% landed on the trail)"
		% [wade, flood_cells, 100.0 * float(wade * UG.FLOOD_DEPTH) / maxf(1.0, float(flood_cells))])
	say("  legs that never dodged a crossing: %d   holes patched over voids: %d"
		% [ug._crossings, ug.road_holes_patched])
	say("  ⛔ cells the player CANNOT FIT through : %d %s"
		% [blocked, str(blocked_at) if blocked > 0 else ""])
	say("  cells with no floor underfoot         : %d  (bed turned to AIR: %d, to WATER: %d)" % [holes, air_bed, wet_bed])
	say("  WORST FALL from the road : %d tiles (%d px) at %s"
		% [worst_fall, worst_fall * UG.TILE, str(worst_fall_at)])
	say("  falls that cost health   : %d   total fall damage walking the whole road: %d"
		% [falls_that_hurt, total_damage])
	say("  steepest single step UP  : %d tiles (%d px) at %s  [player jumps %d tiles]"
		% [worst_climb, worst_climb * UG.TILE, str(worst_climb_at), JUMP_UP])
	# every door must sit on the road and be standable
	var off := 0
	for i in range(ug._doors.size()):
		var d: Vector2i = ug._door_stand(ug._doors[i])
		if not _stand_ok(d.x, d.y - 1):
			off += 1
	say("  doors you cannot stand at: %d of %d" % [off, ug._doors.size()])

# ── 2. MOB SPAWN SPOTS ────────────────────────────────────────────────────────
# An enemy body is 28x40 px = 2.3 x 3.3 tiles, dropped at cell + MOB_FEET_OFF.
# Check whether that box actually FITS in air -- if not, the mob is born inside
# rock and can never move.
func _audit_mob_spots() -> void:
	say("")
	say("── 2. MOB SPAWN SPOTS (body 28x40 resting on the floor) ──")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var tried := 0
	var found := 0
	var stuck := 0
	var wet := 0
	for i in range(600):
		var c := Vector2i(rng.randi_range(6, int(UG.WIDTH / UG.CHUNK) - 6),
			rng.randi_range(1, int(UG.DEPTH / UG.CHUNK) - 1))
		tried += 1
		var cell = ug._find_floor_cell(c, rng)
		if cell == null:
			continue
		found += 1
		if not _body_fits(cell, 28, 40, UG.MOB_FEET_OFF):
			stuck += 1
		if _water(cell.x, cell.y):
			wet += 1
	say("  chunks sampled  : %d   spots found: %d" % [tried, found])
	say("  ⛔ EMBEDDED IN ROCK : %d / %d  (%.1f%%)"
		% [stuck, found, 100.0 * float(stuck) / maxf(1.0, float(found))])
	say("  spawned in water    : %d / %d" % [wet, found])

# does a w x h px box, centred at the cell centre + (0, off_y) px, sit entirely in air?
func _body_fits(cell: Vector2i, w: int, h: int, off_y: float) -> bool:
	var cx := float(cell.x) * UG.TILE + UG.TILE * 0.5
	var cy := float(cell.y) * UG.TILE + UG.TILE * 0.5 + off_y
	var x0 := int(floor((cx - w * 0.5) / UG.TILE))
	var x1 := int(floor((cx + w * 0.5 - 1) / UG.TILE))
	var y0 := int(floor((cy - h * 0.5) / UG.TILE))
	var y1 := int(floor((cy + h * 0.5 - 1) / UG.TILE))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _solid(x, y):
				return false
	return true

# ── 3. FLOOR-DOOR CHAIN ───────────────────────────────────────────────────────
func _audit_door_chain() -> void:
	say("")
	say("── 3. FLOOR-DOOR CHAIN (level N -> N+1) ──")
	var d: Array = ug._doors
	if d.size() < 2:
		say("  !! no doors built")
		return
	var total := 0.0
	var worst := 0
	var worst_l := 0
	var far := 0
	var backwards := 0
	for L in range(1, d.size()):
		var a: Vector2i = d[L - 1]
		var b: Vector2i = d[L]
		var hop := absi(b.x - a.x)
		total += float(hop)
		if hop > worst:
			worst = hop
			worst_l = L
		if hop > int(UG.WIDTH / 4):
			far += 1
		if b.y < a.y:
			backwards += 1
	say("  doors built     : %d" % d.size())
	say("  mean hop L->L+1 : %d tiles (%d px) of a %d-tile world"
		% [int(total / float(d.size() - 1)), int(total / float(d.size() - 1)) * UG.TILE, UG.WIDTH])
	say("  worst hop       : %d tiles at level %d->%d" % [worst, worst_l, worst_l + 1])
	say("  hops > 1/4 world: %d of %d" % [far, d.size() - 1])
	say("  levels that go UP instead of down: %d" % backwards)
	say("  depth 1 -> %d   depth %d -> %d" % [int(d[0].y), d.size(), int(d[d.size() - 1].y)])
	var line := "  first 8 door x : "
	for L in range(0, 8):
		line += str(int(d[L].x)) + " "
	say(line)

# ── 4. SHAPE / WATER ──────────────────────────────────────────────────────────
func _audit_shape() -> void:
	say("")
	say("── 4. SHAPE + WATER by depth ──")
	var tot_open := 0
	var tot_water := 0
	for b in range(5):
		var y0 := b * UG.BIOME_H + 40
		var air := 0
		var wat := 0
		var n := 0
		for y in range(y0, y0 + 80, 2):
			for x in range(400, 3800, 5):
				n += 1
				var k: int = ug._gen_kind(x, y)
				if k == UG.AIR:
					air += 1
				elif k == UG.WATER:
					wat += 1
		tot_open += air + wat
		tot_water += wat
		say("  %-14s rows %4d-%4d : %5.1f%% open   %5.1f%% WATER   (water is %4.1f%% of the open space)"
			% [String(UG.BIOMES[b].name), y0, y0 + 80,
			100.0 * float(air + wat) / float(n), 100.0 * float(wat) / float(n),
			100.0 * float(wat) / maxf(1.0, float(air + wat))])
	say("  ---")
	say("  lakes carved      : %d" % ug._lakes.size())
	say("  water as a share of all open space: %.1f%%" % [100.0 * float(tot_water) / maxf(1.0, float(tot_open))])
