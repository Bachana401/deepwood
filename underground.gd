extends Node2D
# ── THE TERRARIA UNDERGROUND (rework, 2026-07-25) ────────────────────────────
# A real 2-D underworld to replace the flat 1-D Underdark strip: solid rock you
# can mine EVERYWHERE, a 2-D cave network (left/up/right/down), and ONE TRUE PATH
# that switchbacks DOWN -- the deeper you go, the higher the level. Side pockets
# hold loot / chests / mobs / traps / puzzles (added in later steps).
#
# Terraria-matched: 16px tiles, the 32x48 player, ~5.5-tile jump. The world is a
# PURE function of the seed (chunk-streamed around the player so it performs at
# any size) and only the player's DIGS are saved (a diff), so tunnels persist.
# Materials are natural-looking, biome by depth. Group "tile_world" so the pickaxe
# swing (player.gd) can carve it.

const TILE := 12                       # smaller blocks (was 16) -> finer terrain, player reads bigger
const CHUNK := 32
const LOAD_R := 3                      # chunks kept live around the player (bounded collision)
const WIDTH := 4200                    # world width in tiles (Terraria "small" ~= 4200x1200)
const BIOME_H := 300                   # tiles of depth per biome -> 1500 deep
const SAVE_PATH := "user://underground_save.json"
const AIR := -1
# WATER is a cell kind like any other, but it lives on its own non-colliding
# layer (_watermap): you swim through it, you can't mine it, and it never
# counts as ground. Everything that used to ask `kind != AIR` to mean "solid"
# must ask _solid_kind() instead.
const WATER := 100

# 5 biomes by depth. base = block colour, accent = grain fleck. tier = pickaxe
# grade needed to MINE it (the true path is carved open, so you can always descend
# -- mining the rock is for branches + loot, and gets gated deeper).
const BIOMES := [
	{"name": "Rootearth",     "base": Color(0.40, 0.29, 0.17), "accent": Color(0.30, 0.44, 0.20), "hard": 2, "tier": 0},
	{"name": "Stonewarren",   "base": Color(0.39, 0.40, 0.45), "accent": Color(0.52, 0.53, 0.58), "hard": 4, "tier": 0},
	{"name": "Fungal Hollow",  "base": Color(0.22, 0.30, 0.28), "accent": Color(0.30, 0.85, 0.70), "hard": 5, "tier": 1},
	{"name": "Emberdeep",     "base": Color(0.30, 0.14, 0.11), "accent": Color(0.98, 0.48, 0.16), "hard": 7, "tier": 2},
	{"name": "Blightcore",    "base": Color(0.23, 0.09, 0.32), "accent": Color(0.85, 0.40, 1.00), "hard": 9, "tier": 3},
]
const DEPTH := BIOME_H * 5

# ORE VEINS: the atlas holds a second copy of each biome block, salted with bright
# gems, at column ORE_COL + biome. Mining ore drops a good material.
const ORE_COL := 5
const ORE_GEM := [
	Color(0.86, 0.55, 0.24), Color(0.80, 0.83, 0.92), Color(0.35, 0.95, 0.66),
	Color(1.00, 0.72, 0.20), Color(0.80, 0.46, 1.00)]
const ORE_DROP := ["iron_shard", "iron_shard", "ember_crystal", "ember_crystal", "relic_mountain"]

# ── content (streamed per chunk, like the terrain) ────────────────────────────
const ENEMY_SCENE := preload("res://enemy.tscn")
const TRAP_SCENE := preload("res://trap.tscn")
const MATERIAL_PICKUP := preload("res://material_pickup.gd")
const FISH_WATER_SCRIPT := preload("res://fish_water.gd")
# chest loot by biome depth -- all ids the harvest/gather system already drops
const LOOT := [
	["wood", "stone", "stone", "resin"],
	["stone", "stone", "iron_shard", "iron_shard"],
	["iron_shard", "iron_shard", "ember_crystal", "stone"],
	["ember_crystal", "ember_crystal", "iron_shard", "relic_mountain"],
	["ember_crystal", "relic_mountain", "ember_crystal", "iron_shard"],
]

var _map: TileMapLayer                  # foreground: solid, minable blocks
var _wallmap: TileMapLayer              # background: dark cave back-walls (no collision)
var _player: Node = null
var _caverns: FastNoiseLite             # big organic open caverns
var _tunnels: FastNoiseLite             # long winding tunnels between them
var _region: FastNoiseLite              # slow field: tight warrens <-> grand caverns
var _chasm: FastNoiseLite               # vertical chasms / drops
var _ore: FastNoiseLite                 # mineral vein pockets
var _loaded := {}                      # Vector2i(chunk) -> true
var _edits := {}                       # Vector2i(cell) -> kind (AIR = dug)
var _flags := {}                       # puzzle/lever state: id(String) -> true (persisted)
var _hp := {}
var _cur_chunk := Vector2i(999999, 999999)
var _entry := Vector2.ZERO
var _spawn_pos := Vector2.ZERO
var _lava_cd := 0.0
var _content := {}                     # Vector2i(chunk) -> [spawned content nodes]

# ── AUTHORED GEOMETRY (built once, deterministically, in _build_route/_build_lakes) ──
# Everything the terrain must GUARANTEE -- the walkable road, the lake basins --
# is stored as per-row x-spans: row y -> sorted, merged Array[Vector2i(x0, x1)].
# _gen_kind consults them before it touches the noise, so a guarantee costs one
# short scan of a handful of integers instead of 27 noise samples.
var _road_air: Array = []              # y -> spans that must be open (the corridor)
var _road_rock: Array = []             # y -> spans that must be solid (the road bed)
var _water_rows: Array = []            # y -> spans of WATER
var _lake_air: Array = []              # y -> spans of air above a lake's surface
var _lake_rock: Array = []             # y -> spans of the basin shell (holds the water in)
var _road_flood: Array = []            # y -> stretches where the road itself wades
var _road_mass: Array = []            # y -> the solid apron carrying the road (see _gen_kind)
var _lakes: Array = []                 # [{c:Vector2i, hw:int, d:int, big:bool}] for content spawns
var _lakes_by_chunk := {}              # chunk -> [index into _lakes] (the chunk that owns each lake)
var _doors: Array = []                 # level L (1..100) -> its door cell, index L-1
var _route_start := Vector2i.ZERO      # where the road leaves the entry chamber

func _ready() -> void:
	add_to_group("tile_world")
	GameState.in_dungeon = true          # so village-only ticks stay quiet
	GameState.returning_from_dungeon = false   # we own the return here; don't hand the village a stale flag
	_init_noise()
	_build_backdrop()        # a dark cave behind the tiles (so air isn't flat grey)
	_build_wallmap()         # dark textured back-walls behind everything (Terraria look)
	_build_tileset()
	_build_sparkmap()        # the glint on every ore vein (above the rock, under the player)
	_build_watermap()        # the lakes (behind the player, so you're visible under water)
	_ensure_dark()
	_build_hud_frame()       # BEFORE the player: its _ready writes to ../CanvasLayer/*
	_load_save()
	# entry: standing on the floor of the arrival chamber, where the road begins
	_entry = Vector2(_route_start.x * TILE, float(ENTRY_ROW + 1) * TILE)
	# returning from a floor entered down here? come back at that very door.
	_spawn_pos = _entry
	if GameState.came_from_underground and GameState.pre_dungeon_position != Vector2.ZERO:
		_spawn_pos = GameState.pre_dungeon_position + Vector2(0, -30.0)
		GameState.came_from_underground = false
	# Spawn the player BEFORE the first stream: _populate_chunk gates mob/elite spawns on
	# `_player != null`, so streaming first left the WHOLE initial LOAD_R bubble monster-
	# free until those chunks were unloaded and later reloaded. Player _ready does no
	# physics; the stream below builds collision before the first physics frame, so the
	# player still lands on the entry ledge.
	_spawn_player()
	_cur_chunk = _chunk_of(_spawn_pos)
	_stream_around(_cur_chunk)
	_spawn_exit()
	_build_hud_extras()      # hotbar + console, after the player exists
	start_music()

# The world's noise fields. Split out of _ready so headless map audits
# (tool_ug_scan.gd) can build a generator without a scene, a player or a HUD --
# the terrain is a pure function of these, so a bare instance generates the
# exact same world the game does.
func _init_noise() -> void:
	# BIG ORGANIC CAVERNS: low-freq domain-warped fbm blobs -> large open rooms with
	# wandering edges (not TV-static holes).
	_caverns = FastNoiseLite.new()
	_caverns.seed = 0x0F0F
	_caverns.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_caverns.frequency = 0.014
	_caverns.fractal_type = FastNoiseLite.FRACTAL_FBM
	_caverns.fractal_octaves = 4
	_caverns.domain_warp_enabled = true
	_caverns.domain_warp_amplitude = 42.0
	_caverns.domain_warp_fractal_octaves = 3
	# LONG WINDING TUNNELS: low-freq |fbm| ridges that snake for a long way and
	# stitch the caverns together.
	_tunnels = FastNoiseLite.new()
	_tunnels.seed = 0xCA7E
	_tunnels.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_tunnels.frequency = 0.012
	_tunnels.fractal_type = FastNoiseLite.FRACTAL_FBM
	_tunnels.fractal_octaves = 2
	_tunnels.domain_warp_enabled = true
	_tunnels.domain_warp_amplitude = 30.0
	# REGION FIELD: a slow-varying value that shapes each area's character -- from
	# tight winding warrens (solid, thin passages) to grand open caverns.
	_region = FastNoiseLite.new()
	_region.seed = 0x2B1E
	_region.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_region.frequency = 0.006
	_region.fractal_type = FastNoiseLite.FRACTAL_FBM
	_region.fractal_octaves = 2
	# CHASMS: vertically-stretched cracks that drop you between levels.
	_chasm = FastNoiseLite.new()
	_chasm.seed = 0x9D71
	_chasm.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_chasm.frequency = 0.02
	_ore = FastNoiseLite.new(); _ore.seed = 0xACE1; _ore.frequency = 0.10
	_build_route()          # the walkable way down + the 100 doors chained along it
	_build_lakes()          # water basins, placed around the road

const ENTRY_ROW := 5

# ══ SPAN TABLES ══════════════════════════════════════════════════════════════
func _new_rows() -> Array:
	var a: Array = []
	a.resize(DEPTH + 8)
	for i in range(a.size()):
		a[i] = []
	return a

func _add_span(tbl: Array, y: int, x0: int, x1: int) -> void:
	if y < 0 or y >= tbl.size() or x1 < x0:
		return
	tbl[y].append(Vector2i(maxi(x0, 2), mini(x1, WIDTH - 3)))

# sort + merge every row once, so lookups can early-out on the first span that
# starts past x (rows end up holding a handful of spans, not thousands).
func _merge_rows(tbl: Array) -> void:
	for y in range(tbl.size()):
		var a: Array = tbl[y]
		if a.size() < 2:
			continue
		a.sort_custom(func(p: Vector2i, q: Vector2i): return p.x < q.x)
		var out: Array = []
		var cur: Vector2i = a[0]
		for i in range(1, a.size()):
			var s: Vector2i = a[i]
			if s.x <= cur.y + 1:
				cur.y = maxi(cur.y, s.y)
			else:
				out.append(cur)
				cur = s
		out.append(cur)
		tbl[y] = out

func _in_span(tbl: Array, y: int, x: int) -> bool:
	if y < 0 or y >= tbl.size():
		return false
	for s in tbl[y]:
		if x < s.x:
			return false          # sorted -> nothing further right can match
		if x <= s.y:
			return true
	return false

# ══ THE DELVER'S ROAD ════════════════════════════════════════════════════════
# The old "true path" was an 8-wide vertical shaft with nothing to stand on: the
# first step off the entry ledge was a 1068px drop (~115 fall damage), and 749 of
# the 1195 rows below had no landing anywhere (audit, tool_ug_scan). You cannot
# walk a shaft, and you certainly cannot walk back UP one.
#
# The road replaces it with a carved, walkable trail. ONE INVARIANT makes it
# safe: the walker never moves a tile vertically without also moving a tile
# horizontally -- so the steepest thing it can ever build is a 45-degree
# staircase of 1-tile (12px) steps. 12px is far below the 300px fall-damage
# threshold and far below the ~89px jump, so the whole road is walkable DOWN and
# climbable back UP, end to end, with no double jump.
#
# The road is also THE CHAIN. Floor 1's door sits on it, then floor 2 a hop
# further along, then 3 -- so following the road is following the ladder of
# levels. It wanders: long sideways runs, staircases down, the occasional rise.
const ROAD_HALF := 1                   # corridor half-width -> 3 tiles wide
const ROAD_HEAD := 5                   # tiles of air above the road bed (player is 4 tall)
const ROAD_BED := 2                    # tiles of solid rock under it
const ROAD_UNDER := 10                 # ...plus this much solid apron beneath THAT
const ROAD_MASS_HALF := 5              # wider than the corridor, so you can't sidestep and dig
const STAIR_TREAD := 3                 # horizontal tiles per 1-tile step (shallower = comfier)
const LEVELS := 100
const DOOR_HOP_MIN := 90               # tiles between consecutive floor doors...
const DOOR_HOP_MAX := 220              # ...about one screen at zoom 0.6 -- near, but out of sight
const ROAD_MARGIN := 120               # keep the chain clear of the world edges

func _build_route() -> void:
	_road_air = _new_rows()
	_road_rock = _new_rows()
	_road_mass = _new_rows()
	_doors = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0DDBA11
	_beds = {}
	_path = []
	_road_fix = {}
	_path_i = 0
	_crossings = 0
	# ── where each floor's door lives: a wandering walk, never a fresh hash ──
	# consecutive doors are DOOR_HOP_MIN..MAX apart and one level deeper, so 1 is
	# near 2 is near 3 all the way to 100 -- "somewhere there", not on the far
	# side of the world (the old scatter averaged a 1384-tile hop).
	var bottom := DEPTH - 34
	var x := int(WIDTH * 0.5)
	var dir := 1 if rng.randf() < 0.5 else -1
	_route_start = Vector2i(clampi(x - rng.randi_range(120, 200), ROAD_MARGIN, WIDTH - ROAD_MARGIN), ENTRY_ROW + 2)
	var cur := _route_start
	for L in range(1, LEVELS + 1):
		var hop := rng.randi_range(DOOR_HOP_MIN, DOOR_HOP_MAX)
		var nx := cur.x + dir * hop
		if nx < ROAD_MARGIN or nx > WIDTH - ROAD_MARGIN:
			dir = -dir                          # bounce off the edge of the world
			nx = cur.x + dir * hop
		nx = clampi(nx, ROAD_MARGIN, WIDTH - ROAD_MARGIN)
		var flipped := signi(nx - cur.x) != dir
		if rng.randf() < 0.22:
			dir = -dir                          # and snake back now and then
		# the descent per level is re-derived from what's LEFT, so a leg that had
		# to dive deeper to dodge a crossing is absorbed by the ones after it and
		# floor 100 still lands at the bottom of the world
		var left := LEVELS - L + 1
		var step := maxi(7, int(round(float(bottom - cur.y) / float(left))))
		# A LEG THAT DOUBLES BACK PAYS IN DEPTH. Reversing retraces the columns the
		# previous leg just walked, so unless it drops well clear of them the two
		# passes sit within a corridor-height of each other and the upper one's bed
		# gets carved out from under the player. Two levels' worth of descent buys
		# the clearance; the self-correcting `step` above gives it back to the rest.
		if flipped:
			step = int(round(float(step) * 2.2))
		var target := Vector2i(nx, mini(cur.y + step, bottom))
		var path: Array = []
		var clear := false
		for attempt in range(8):
			path = _plan_leg(cur, target, rng, attempt)
			if _leg_clear(path):
				clear = true
				break
			# It would have run within a corridor-height of road already laid, so
			# drop it deeper -- but only for the first few tries. Deepening without
			# a limit is worse than the crossing it dodges: the leg dives 90 rows,
			# eats the depth budget the levels below it needed, and the walk comes
			# out with 29-tile drops. After that, just re-roll the waypoints.
			if attempt < 3:
				target.y = mini(target.y + 9, bottom)
		if not clear:
			_crossings += 1
		_carve_path(path)
		cur = path[path.size() - 1] if not path.is_empty() else cur
		_doors.append(cur)                      # the door stands on the road bed itself
	# run the road on a little past the last door so floor 100 isn't a dead end
	var tail := Vector2i(clampi(cur.x + 120 * (1 if cur.x < WIDTH / 2 else -1), ROAD_MARGIN, WIDTH - ROAD_MARGIN),
		mini(cur.y + 14, DEPTH - 6))
	_carve_path(_plan_leg(cur, tail, rng, 0))
	_merge_rows(_road_air)
	_merge_rows(_road_rock)
	_merge_rows(_road_mass)
	_repair_road()
	# LIGHT THE ROAD. The dev's complaint was that there was no clear way down;
	# geometry alone fixes that only if you can SEE it. A lantern every ~14 tiles
	# turns the trail into a lit line running through dark caves -- you always
	# know which way is onward, and the unlit branches read as the optional side
	# exploration they are. Indexed by chunk so streaming stays O(1).
	_road_lamps = {}
	for i in range(0, _path.size(), 14):
		var cell: Vector2i = _path[i]
		var key := _chunk_of_cell(cell)
		if not _road_lamps.has(key):
			_road_lamps[key] = []
		_road_lamps[key].append(cell)

var _road_lamps := {}                  # chunk -> [road cells that carry a lantern]

# ── THE LAST GUARANTEE: no hole over a void ───────────────────────────────────
# Air beats bed in _gen_kind, which is right at every stair lip but does let one
# pass carve the floor out from under another where they cross. Most of those are
# harmless -- there is another road, or plain cave floor, a few tiles below to
# land on. The one that is NOT harmless is a hole opening over a big cavern:
# walking the road you drop 40 tiles into the dark, which is precisely the bug
# this rewrite set out to kill.
#
# So walk every cell of the finished road and patch exactly those. Repairing only
# holes with nothing underneath is what keeps the fix surgical: where a lower
# corridor runs beneath, the "hole" is a 7-tile step onto it (84px, under both the
# 300px damage threshold and the 89px jump), and blocking it off would wall that
# corridor instead.
# A drop of 7 tiles is 84px: under the 300px damage threshold AND under the ~89px
# jump, so you can hop straight back up and the road is still two-way. Anything
# taller is a one-way trapdoor even when it costs no health, so that is where the
# patch line sits -- not at the damage threshold.
const REPAIR_DROP := 8
var _road_fix := {}                    # cells forced back to solid; small, so a dict is fine

func _repair_road() -> void:
	_road_fix = {}
	var patched := 0
	for c in _path:
		if _gen_kind(c.x, c.y) != AIR:
			continue                       # the bed survived
		var drop := 0
		while drop < REPAIR_DROP and _gen_kind(c.x, c.y + 1 + drop) == AIR:
			drop += 1
		if drop >= REPAIR_DROP:
			_road_fix[c] = true
			patched += 1
	road_holes_patched = patched

# Every road cell in order. Kept (about 200KB) rather than thrown away, because
# it is the only description of where the road actually GOES -- tool_ug_scan
# walks it cell by cell to prove the road is traversable, and a straight-line
# sweep across x cannot do that: the trail doubles back on itself.
var _path: Array = []
var road_holes_patched := 0            # audit reads this

# ── keeping the road from crossing over itself ────────────────────────────────
# A pass carves ROAD_HEAD tiles of headroom above its bed. If a second pass lays
# its bed inside that headroom, the first pass's floor is carved away underneath
# the walker -- a hole in the road, exactly the thing this whole rewrite exists
# to remove. So every leg is PLANNED first, checked against the beds already
# laid, and pushed deeper until it clears them.
var _beds := {}                        # column x -> [Vector2i(row, path index)]
var _path_i := 0
var _crossings := 0                    # legs that never found a clear line (audit reads this)
const CROSS_CLEAR := ROAD_HEAD + ROAD_BED     # rows of separation two passes need
const CROSS_RECENT := 44               # ...but the leg we just came off doesn't count

func _leg_clear(path: Array) -> bool:
	for k in range(path.size()):
		var c: Vector2i = path[k]
		var gi := _path_i + k
		for dx in range(-ROAD_HALF, ROAD_HALF + 1):
			var col = _beds.get(c.x + dx)
			if col == null:
				continue
			for rec in col:
				var d := absi(int(rec.x) - c.y)
				if d >= 2 and d <= CROSS_CLEAR and gi - int(rec.y) > CROSS_RECENT:
					return false
	return true

func _carve_path(path: Array) -> void:
	for k in range(path.size()):
		var c: Vector2i = path[k]
		_carve_road_cell(c)
		_path.append(c)
		for dx in range(-ROAD_HALF, ROAD_HALF + 1):
			var key := c.x + dx
			if not _beds.has(key):
				_beds[key] = []
			_beds[key].append(Vector2i(c.y, _path_i + k))
	_path_i += path.size()

# One leg of the trail: from `a` to `b` via 2-3 intermediate waypoints whose
# height is jittered (sometimes UPWARD -- the dev asked for down, sideways and
# up), flattening out on later attempts when the first line didn't fit.
func _plan_leg(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator, attempt: int) -> Array:
	var pts: Array = [a]
	var legs := rng.randi_range(2, 3)
	var rise := maxi(0, 8 - attempt * 3)          # give up the climbs if they're in the way
	for i in range(1, legs):
		var f := float(i) / float(legs)
		var wx := int(round(lerpf(float(a.x), float(b.x), f)))
		var wy := int(round(lerpf(float(a.y), float(b.y), f))) + rng.randi_range(-rise, 5)
		pts.append(Vector2i(wx, clampi(wy, ENTRY_ROW + 4, DEPTH - 8)))
	pts.append(b)
	var out: Array = []
	var cur := a
	for i in range(1, pts.size()):
		cur = _walk_to(cur, pts[i], out)
	return out

# Step from `p` toward `q`, collecting the cells. THE INVARIANT: a vertical step
# is only ever taken together with a horizontal one, and only after STAIR_TREAD
# horizontal tiles when there is room to be gentle -- so the trail is a
# staircase of 1-tile (12px) steps, never a shaft. 12px is nothing to fall and
# nothing to jump, which is what makes the road two-way.
func _walk_to(p: Vector2i, q: Vector2i, out: Array) -> Vector2i:
	var tread := 0
	var guard := 0
	while p != q and guard < 20000:
		guard += 1
		var dx := signi(q.x - p.x)
		var dy := signi(q.y - p.y)
		if dx == 0 and dy != 0:
			# no horizontal budget left -> sidestep so the descent stays a stair
			dx = 1 if p.x < WIDTH / 2 else -1
			q.x = p.x + dx * absi(q.y - p.y) * 2
			continue
		var need := absi(q.y - p.y) * STAIR_TREAD > absi(q.x - p.x)   # running out of room?
		if dy != 0 and (tread >= STAIR_TREAD or need):
			p += Vector2i(dx, dy)          # the step: down-and-along, never straight down
			tread = 0
		else:
			p.x += dx
			tread += 1
		out.append(p)
	return p

# The cross-section: air for the player's headroom, solid rock for the bed. The
# bed is what makes it a ROAD -- without it the corridor would open into a
# cavern and drop you through.
func _carve_road_cell(c: Vector2i) -> void:
	for dy in range(1, ROAD_HEAD + 1):
		_add_span(_road_air, c.y - dy, c.x - ROAD_HALF, c.x + ROAD_HALF)
	for dy in range(0, ROAD_BED):
		_add_span(_road_rock, c.y + dy, c.x - ROAD_HALF, c.x + ROAD_HALF)
	# the apron of rock the road rides on (see _gen_kind)
	for dy in range(ROAD_BED, ROAD_BED + ROAD_UNDER):
		_add_span(_road_mass, c.y + dy, c.x - ROAD_MASS_HALF, c.x + ROAD_MASS_HALF)

const ENTRY_HALF := 15

# The entry chamber: a real room you land in, with a floor, standing space and
# the road leaving one side -- not a ledge over a shaft.
func _entry_kind(x: int, y: int) -> int:
	var ex := _route_start.x
	var floor_y := ENTRY_ROW + 2
	if absi(x - ex) > ENTRY_HALF:
		return -999                                  # not the chamber
	if y < floor_y:
		return AIR
	if y <= floor_y + 1:
		return _biome_of(y)
	return -999

# ══ WATER: CARVED BASINS ═════════════════════════════════════════════════════
# Terraria's water sits in real bowls with a flat surface. Noise can't promise
# that, and a chunk-local flood fill can't either (a basin straddling two chunks
# would settle at two different levels). So the lakes are AUTHORED: each one
# carves its own bowl, forces a rock shell around it that holds the water in,
# and fills to a flat surface row. Deterministic, seam-free, and free to query.
const LAKE_STEP_X := 54                # candidate grid: one roll per cell of it
const LAKE_STEP_Y := 18
const LAKE_CHANCE := 0.74              # "lots -- a wet underworld" (~20% of open space)
const LAKE_BIG_CHANCE := 0.34          # big lakes carry most of the volume
const LAKE_SHELL := 3                  # tiles of rock that hold each bowl
const FLOOD_CROSSINGS := 11            # road stretches you must swim
const FLOOD_DEPTH := 5                 # tiles of water over the road bed (player is 4 tall)

func _build_lakes() -> void:
	_water_rows = _new_rows()
	_lake_air = _new_rows()
	_lake_rock = _new_rows()
	_road_flood = _new_rows()
	_lakes = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EA1EDE1
	var claimed := {}                  # coarse buckets, so bowls never overlap and mix levels
	for gy in range(1, int(float(DEPTH - 40) / LAKE_STEP_Y)):
		for gx in range(1, int(float(WIDTH - 2 * ROAD_MARGIN) / LAKE_STEP_X)):
			if rng.randf() > LAKE_CHANCE:
				continue
			var big := rng.randf() < LAKE_BIG_CHANCE
			var hw := rng.randi_range(38, 90) if big else rng.randi_range(10, 28)
			var d := rng.randi_range(14, 32) if big else rng.randi_range(5, 13)
			var cx := ROAD_MARGIN + gx * LAKE_STEP_X + rng.randi_range(-30, 30)
			var sy := 30 + gy * LAKE_STEP_Y + rng.randi_range(-8, 8)
			if cx - hw < ROAD_MARGIN or cx + hw > WIDTH - ROAD_MARGIN:
				continue
			if sy + d > DEPTH - 20:
				continue
			# never drown the road, and never flood the room you arrive in
			# The FULL footprint: the shore above, the bowl, and the shell under it.
			# The shore runs out to hw+6 (see _carve_lake), wider than the shell --
			# guarding only hw+LAKE_SHELL let neighbouring lakes eat each other's
			# outer bank.
			var y_top := sy - 7
			var y_bot := sy + d + LAKE_SHELL + 2
			var x_pad := hw + 6
			if _spans_hit(_road_air, y_top, y_bot, cx - x_pad, cx + x_pad) \
					or _spans_hit(_road_rock, y_top, y_bot, cx - x_pad, cx + x_pad):
				continue
			if sy < ENTRY_ROW + 26 and absi(cx - _route_start.x) < ENTRY_HALF + hw + 20:
				continue
			# one bowl per patch of buckets, so two lakes never merge into a
			# staircase-shaped "surface"
			# Claim the WHOLE footprint, shell included -- claiming only the water
			# let the next lake start inside this one's floor, and since water is
			# resolved before lake rock in _gen_kind that floor simply vanished:
			# two stacked bowls merged into one column with nothing holding the
			# upper one up.
			var taken := false
			# fine buckets, so bowls pack close without merging. Coarse ones rounded
			# every claim up to a big rectangle and starved the map of water.
			var b0 := Vector2i(int(float(cx - x_pad) / 12.0), int(float(y_top) / 6.0))
			var b1 := Vector2i(int(float(cx + x_pad) / 12.0), int(float(y_bot) / 6.0))
			for by in range(b0.y, b1.y + 1):
				for bx in range(b0.x, b1.x + 1):
					if claimed.has(Vector2i(bx, by)):
						taken = true
						break
				if taken:
					break
			if taken:
				continue
			for by in range(b0.y, b1.y + 1):
				for bx in range(b0.x, b1.x + 1):
					claimed[Vector2i(bx, by)] = true
			_carve_lake(cx, sy, hw, d)
			_lakes.append({"c": Vector2i(cx, sy), "hw": hw, "d": d, "big": big})
	# ── stretches where the ROAD ITSELF goes under ──
	# The road is otherwise sacred, so these are placed deliberately: a handful of
	# short wades you swim across, spaced down the chain.
	# FOLLOW THE ROAD, don't guess where it is. A flat band at the door's row misses
	# the trail almost entirely -- the road leaves a door descending a stair, so 25
	# tiles along it is already several rows lower. The band then painted a sealed
	# slab of water into solid rock while the road beside it stayed dry: the wade
	# you were supposed to swim wasn't there, and a water box was.
	if not _path.is_empty() and not _doors.is_empty():
		# where each door sits along the path, so a crossing can start from it
		var door_i := {}
		var di := 0
		for k in range(_path.size()):
			if di < _doors.size() and _path[k] == _doors[di]:
				door_i[di] = k
				di += 1
		for i in range(FLOOD_CROSSINGS):
			var L := int(float(i + 1) * float(LEVELS) / float(FLOOD_CROSSINGS + 1))
			var start = door_i.get(clampi(L - 1, 0, _doors.size() - 1))
			if start == null:
				continue
			var run := rng.randi_range(22, 40)
			var from := int(start) + 14                # begin clear of the door itself
			for k in range(from, mini(from + run, _path.size())):
				var c: Vector2i = _path[k]
				for dy in range(1, FLOOD_DEPTH + 1):
					for fx in range(c.x - ROAD_HALF, c.x + ROAD_HALF + 1):
						# never flood a BED cell. On a stair the neighbouring cell's
						# bed sits a row lower, so a flat span would dissolve the very
						# floor you wade along and drop you through it.
						if _in_span(_road_rock, c.y - dy, fx):
							continue
						_add_span(_road_flood, c.y - dy, fx, fx)
	_merge_rows(_water_rows)
	_merge_rows(_lake_air)
	_merge_rows(_lake_rock)
	_merge_rows(_road_flood)
	# index the lakes by the chunk that OWNS them, so _populate_chunk doesn't scan
	# all ~1400 of them on every single chunk load
	_lakes_by_chunk = {}
	for li in range(_lakes.size()):
		var key := _chunk_of_cell(_lakes[li].c)
		if not _lakes_by_chunk.has(key):
			_lakes_by_chunk[key] = []
		_lakes_by_chunk[key].append(li)

# an elliptical bowl: widest at the surface, tapering to the bed -- with a rock
# shell around it and open air above, so it reads as a lake in a cave.
func _carve_lake(cx: int, sy: int, hw: int, d: int) -> void:
	for dy in range(0, d + 1):
		var t := float(dy) / float(d)
		# RAGGED, not geometric. A clean ellipse read as a bowl of water set into
		# the rock (screenshot pl_work/ug/ug_ore.png) instead of a cave that
		# happens to be flooded, so each row's edge wobbles by a couple of tiles.
		var w := int(round(float(hw) * sqrt(maxf(0.0, 1.0 - t * t))))
		var lw := maxi(0, w + _lwob(cx, sy, dy, 0))
		var rw := maxi(0, w + _lwob(cx, sy, dy, 1))
		var y := sy + dy
		# always write the centre column, even at the very bottom where the ellipse
		# has closed to nothing and both wobbles rolled negative -- skipping it left
		# a 1-cell bubble of raw noise in the floor of about a third of the bowls
		_add_span(_water_rows, y, cx - lw, cx + rw)
		# The shell that holds it in: thick at depth, THIN at the waterline. A
		# 3-tile rim all the way up walled every lake off from the caves around
		# it -- the water has to meet the cave, or you can see it and never
		# reach it.
		var shell := 1 if dy < 3 else LAKE_SHELL
		_add_span(_lake_rock, y, cx - lw - shell, cx - lw - 1)
		_add_span(_lake_rock, y, cx + rw + 1, cx + rw + shell)
	for dy in range(1, LAKE_SHELL + 2):
		_add_span(_lake_rock, sy + d + dy, cx - hw - LAKE_SHELL, cx + hw + LAKE_SHELL)
	# THE SHORE: open cave above the surface, carried a few tiles PAST the water's
	# widest point so the bank always runs out into the surrounding rock and the
	# lake is approachable from either side.
	for dy in range(1, 7):
		var over := hw + 4 - _lwob(cx, sy, dy, 2)
		_add_span(_lake_air, sy - dy, cx - over, cx + over)

# a small deterministic wobble (-2..+2) for a lake's edge -- same lake, same
# shape, every time the chunk streams back in
func _lwob(cx: int, sy: int, dy: int, salt: int) -> int:
	var h := ((cx * 73856093) ^ (sy * 19349663) ^ (dy * 83492791) ^ (salt * 2654435761)) & 0x7fffffff
	return (h % 5) - 2

# does any span in `tbl` intersect this box? (used to keep lakes off the road)
func _spans_hit(tbl: Array, y0: int, y1: int, x0: int, x1: int) -> bool:
	for y in range(maxi(0, y0), mini(tbl.size(), y1 + 1)):
		for s in tbl[y]:
			if s.x <= x1 and s.y >= x0:
				return true
	return false

# WATER is not ground. Every "is there floor here" test must go through this --
# `kind != AIR` would happily stand a mob on the surface of a lake.
func _solid_kind(cell: Vector2i) -> bool:
	var k := _cell_kind(cell)
	return k != AIR and k != WATER

# ── deterministic 2-D world ───────────────────────────────────────────────────
func _biome_of(y: int) -> int:
	return clampi(int(floor(float(y) / float(BIOME_H))), 0, BIOMES.size() - 1)

func _gen_kind(x: int, y: int) -> int:
	if x < 2 or x >= WIDTH - 2 or y >= DEPTH:
		return _biome_of(clampi(y, 0, DEPTH - 1))     # solid walls / bedrock floor
	if y < 1:
		return AIR                                    # open sky above the entry
	# ── THE DELVER'S ROAD ─────────────────────────────────────────────────────
	# Checked FIRST, so it pierces the seal bands, the lakes and the noise alike:
	# the way down is never blocked and never a fall (see _build_route).
	if _road_fix.has(Vector2i(x, y)):
		return _biome_of(y)                           # a patched hole (see _repair_road)
	# AIR WINS over the bed, and it has to: at every stair lip the next step's
	# headroom is carved through the tread just laid, which is simply where the
	# step happens. (Letting the bed win instead walls the corridor off with its
	# own slabs -- measured: 292 dead ends and 36 damaging drops.) Crossings that
	# would punch a real hole are prevented up front instead, in _leg_clear.
	if _in_span(_road_flood, y, x):
		return WATER                                  # a stretch the road wades through
	if _in_span(_road_air, y, x):
		return AIR
	if _in_span(_road_rock, y, x):
		return _biome_of(y)
	# the arrival chamber -- AFTER the road, or its floor slab would roof over the
	# first stretch of the descent that leaves it
	var ek := _entry_kind(x, y)
	if ek != -999:
		return ek
	# LAKES: carved basins that actually hold their water (see _build_lakes).
	if _in_span(_lake_air, y, x):
		return AIR
	if _in_span(_water_rows, y, x):
		return WATER
	if _in_span(_lake_rock, y, x):
		return _biome_of(y)
	var b := _biome_of(y)
	# ── THE MASS UNDER THE ROAD ───────────────────────────────────────────────
	# The bed is only ROAD_BED thick, and what sat under it was whatever the noise
	# felt like -- usually open cavern. So you could stand on the trail, dig two
	# tiles, and drop straight through, skipping the whole winding route in
	# seconds and taking the exact fall this rework exists to prevent.
	#
	# Now the road rides on a deep apron of solid rock, wider than the corridor so
	# you cannot just sidestep and dig there. Cutting down through it is still
	# ALLOWED -- it just costs real time, which is the point: the road becomes the
	# sane way to travel rather than the only one. Checked after the lakes, so a
	# lake below the road keeps its water instead of being filled in.
	if _in_span(_road_mass, y, x):
		if _ore.get_noise_2d(float(x) * 1.3, float(y) * 1.3) > 0.42:
			return ORE_COL + b            # ...and the long dig down still pays
		return b
	# PICKAXE-GATE SEAL: a solid band of the hardest rock at the MOUTH of the deepest
	# biome. Free exploration gets you this far; to go deeper you must DIG through it
	# with a strong enough pickaxe. (The way down is otherwise open.)
	if int(BIOMES[b].tier) >= 3 and (y - b * BIOME_H) < 10:
		return b
	# DELICATE, ORGANIC CAVERNS: a cell opens only if MOST of its 3x3 neighbourhood
	# reads open (one cellular-automata smoothing pass over the noise). This melts
	# the single-tile speckle into big, smooth, sweeping caverns + tunnels -- one
	# connected system you explore freely, opening up with depth.
	var open := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if _raw_open(x + ox, y + oy):
				open += 1
	if open >= 5:
		return AIR
	# solid rock -- salt in clustered ORE VEINS for a reward when you dig
	if _ore.get_noise_2d(float(x) * 1.3, float(y) * 1.3) > 0.42:
		return ORE_COL + b
	return b

func _raw_open(x: int, y: int) -> bool:
	# the REGION shapes local character: r>0 -> grand open caverns, r<0 -> tight
	# solid warrens with only thin passages. Deeper = a touch more open overall.
	var r := _region.get_noise_2d(float(x), float(y))
	var thr := -0.02 - float(y) / float(DEPTH) * 0.06 - r * 0.34
	if _caverns.get_noise_2d(float(x), float(y)) > thr:
		return true
	# winding tunnels always stitch the world together (thinner inside warrens)
	var tun := 0.032 if r < -0.25 else 0.05
	if absf(_tunnels.get_noise_2d(float(x), float(y))) < tun:
		return true
	# vertical CHASMS: y-squashed noise -> tall narrow shafts you can drop down
	if absf(_chasm.get_noise_2d(float(x), float(y) * 0.22)) < 0.02:
		return true
	return false

func _cell_kind(cell: Vector2i) -> int:
	return int(_edits.get(cell, _gen_kind(cell.x, cell.y)))

# ── chunk streaming (bounded collision at any world size) ─────────────────────
func _chunk_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE / CHUNK)), int(floor(world_pos.y / TILE / CHUNK)))

# STAGGERED STREAMING (audit fix): loading every missing chunk synchronously
# meant a reproducible hitch each ~384px of travel -- the moving edge is 7
# chunks x 1,024 cells x up to 27 noise samples (~190k calls) in ONE frame.
# Only the chunks the player can SEE or STAND IN (Chebyshev distance <= 2 at
# the Terraria zoom, screen half-width ~2.5 chunks) still load immediately;
# the rest go on a nearest-first queue drained one chunk per frame. Walking a
# seam queues only distance-3 chunks (offscreen), so travel never hitches;
# a teleport or boot pays one bigger frame for the visible 5x5 and streams
# the outer ring over the following frames.
var _load_queue: Array = []
const STREAM_NOW_R := 2

func _stream_around(center: Vector2i) -> void:
	var want := {}
	for cy in range(center.y - LOAD_R, center.y + LOAD_R + 1):
		for cx in range(center.x - LOAD_R, center.x + LOAD_R + 1):
			want[Vector2i(cx, cy)] = true
	for c in want.keys():
		if _loaded.has(c):
			continue
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) <= STREAM_NOW_R:
			_load_chunk(c)
		elif not _load_queue.has(c):
			_load_queue.append(c)
	_load_queue.sort_custom(func(a, b):
		return (a - center).length_squared() < (b - center).length_squared())
	# Unload with a one-chunk dead-band (keep radius > load radius): a player pacing a
	# chunk seam would otherwise thrash the edge chunks, and re-populating a chunk resets
	# its mobs to full HP and repositions them on every crossing.
	var keep := {}
	for cy in range(center.y - LOAD_R - 1, center.y + LOAD_R + 2):
		for cx in range(center.x - LOAD_R - 1, center.x + LOAD_R + 2):
			keep[Vector2i(cx, cy)] = true
	var drop := []
	for c in _loaded.keys():
		if not keep.has(c):
			drop.append(c)
	for c in drop:
		_unload_chunk(c)
	_load_queue = _load_queue.filter(func(c): return keep.has(c))

func _drain_stream_queue() -> void:
	while not _load_queue.is_empty():
		var c: Vector2i = _load_queue.pop_front()
		if not _loaded.has(c):
			_load_chunk(c)
			return   # one chunk a frame is plenty -- these are offscreen

# which face a block wears, from what surrounds it. Air and water both count as
# "open" -- a block under a lake is a lakebed surface, not buried rock.
func _face_for(above: int, left: int, right: int) -> int:
	if above == AIR or above == WATER:
		return TILE_EXPOSED
	if left == AIR or left == WATER or right == AIR or right == WATER:
		return TILE_FACE
	return TILE_INTERIOR

# Re-derive one cell's face from the live map. Used after a dig, so the blocks
# a new tunnel uncovers stop looking like buried interior rock.
func _reface(cell: Vector2i) -> void:
	if _map.get_cell_source_id(cell) == -1:
		return
	_map.set_cell(cell, 0, Vector2i(_map.get_cell_atlas_coords(cell).x,
		_face_for(_cell_kind(cell + Vector2i(0, -1)), _cell_kind(cell + Vector2i(-1, 0)),
			_cell_kind(cell + Vector2i(1, 0)))))

func _load_chunk(c: Vector2i) -> void:
	_loaded[c] = true
	# Resolve the chunk's cells ONCE, one row taller than the chunk, so each block
	# can see what is above it without paying for a second _gen_kind (which costs
	# up to 27 noise samples). 33 extra lookups per chunk instead of 1024.
	var kinds: Array = []
	for ly in range(-1, CHUNK):
		var row: Array = []
		row.resize(CHUNK + 2)
		for lx in range(-1, CHUNK + 1):
			row[lx + 1] = _cell_kind(Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly))
		kinds.append(row)
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			var cell := Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly)
			_wallmap.set_cell(cell, 0, Vector2i(_biome_of(cell.y), 0))   # back-wall always
			var kind: int = kinds[ly + 1][lx + 1]
			var above: int = kinds[ly][lx + 1]
			if kind == WATER:
				# the SURFACE tile (atlas 1) wherever there's no water directly above,
				# so every lake gets Terraria's bright waterline instead of a flat slab
				_watermap.set_cell(cell, 0, Vector2i(0 if above == WATER else 1, 0))
			elif kind != AIR:
				var left: int = kinds[ly + 1][lx]
				var right: int = kinds[ly + 1][lx + 2]
				_map.set_cell(cell, 0, Vector2i(kind, _face_for(above, left, right)))
				if kind >= ORE_COL:
					_sparkmap.set_cell(cell, 0, Vector2i(kind - ORE_COL, 0))   # + its glint
	_populate_chunk(c)

func _unload_chunk(c: Vector2i) -> void:
	_depopulate_chunk(c)
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			var cell := Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly)
			_map.erase_cell(cell)
			_wallmap.erase_cell(cell)
			_watermap.erase_cell(cell)
			_sparkmap.erase_cell(cell)
	_loaded.erase(c)

# ── streamed content: chests (loot), depth-scaled mobs, traps ─────────────────
func _populate_chunk(c: Vector2i) -> void:
	if c.y < 1:
		# the entry stays a SAFE LANDING (no mobs/traps/chests), but its floor-doors --
		# levels 1-2 fall in chunk-row 0 -- must still spawn, or those two entrances AND
		# the early frontier BEACON are silently missing (dev 2026-07-26).
		var top_nodes: Array = []
		# lanterns still light the first stretch of road -- a lamp is not a threat,
		# so the arrival chamber stays a safe landing AND has a visible way out
		_place_road_lamps(c, top_nodes)
		_place_floor_doors(c, top_nodes)
		if not top_nodes.is_empty():
			_content[c] = top_nodes
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(c) ^ 0x9E3779B9) & 0x7fffffff
	var biome := _biome_of(c.y * CHUNK + CHUNK / 2)
	var nodes := []
	if rng.randf() < 0.16:                         # a loot chest
		var fc = _find_floor_cell(c, rng)
		if fc != null:
			nodes.append(_spawn_chest(fc, biome, rng))
	if rng.randf() < 0.14:                         # a trap
		var tc = _find_floor_cell(c, rng)
		if tc != null:
			nodes.append(_spawn_trap(tc))
	var mob_count := 3 + biome                     # MORE mobs, and more with depth
	for i in range(mob_count):
		if rng.randf() < 0.7:
			var mc = _find_floor_cell(c, rng)
			if mc != null and _player != null \
					and _map.to_global(_map.map_to_local(mc)).distance_to(_player.global_position) > 380.0:
				nodes.append(_spawn_mob(mc, biome, rng))
	# SPECIAL SET-PIECES (rare): a lever-vault PUZZLE, a crystal GEODE, a mushroom
	# GROVE -- discovery + variety as you explore.
	if rng.randf() < 0.06:
		var vc = _find_floor_cell(c, rng)
		if vc != null:
			nodes.append_array(_spawn_vault(vc, biome, rng))
	if rng.randf() < 0.05:
		var gc = _find_floor_cell(c, rng)
		if gc != null:
			nodes.append_array(_spawn_geode(gc, biome, rng))
	if rng.randf() < 0.05:
		var mgc = _find_floor_cell(c, rng)
		if mgc != null:
			nodes.append_array(_spawn_grove(mgc, biome, rng))
	if rng.randf() < 0.05:
		var rvc = _find_floor_cell(c, rng)
		if rvc != null:
			nodes.append_array(_spawn_runevault(rvc, biome, rng))
	if rng.randf() < 0.05:
		var plc = _find_floor_cell(c, rng)
		if plc != null:
			nodes.append_array(_spawn_pool(plc, biome, rng))
	# an ELITE mob now and then -- tougher, glowing, a real threat
	if rng.randf() < 0.10 and _player != null:
		var ec = _find_floor_cell(c, rng)
		if ec != null and _map.to_global(_map.map_to_local(ec)).distance_to(_player.global_position) > 400.0:
			nodes.append(_spawn_mob(ec, biome, rng, true))
	# TORCHES (dev 2026-07-26): ~30% of sampled floor spots get a wall torch, so the now-dark
	# caves have frequent warm light pools with dark stretches between (Terraria-style).
	# Thinned from 5 rolls at 0.3 now that _place_road_lamps lights the trail: every
	# one of these is a real PointLight2D, and 2D lights were what made the old
	# caves lag. Fewer scattered torches + a lit road is a NET reduction in live
	# lights, and it reads better -- the road glows, the side caves stay dark.
	for _ti in range(4):
		if rng.randf() < 0.22:
			var lc = _find_floor_cell(c, rng)
			if lc != null:
				nodes.append(_spawn_torch(lc))
	_place_lake_life(c, nodes)
	_place_road_lamps(c, nodes)
	_place_floor_doors(c, nodes)
	if not nodes.is_empty():
		_content[c] = nodes

# the lanterns that mark the Delver's Road (see _build_route)
func _place_road_lamps(c: Vector2i, nodes: Array) -> void:
	var here = _road_lamps.get(c)
	if here == null:
		return
	for cell in here:
		if _cell_kind(cell) == WATER or _cell_kind(cell + Vector2i(0, -1)) == WATER:
			continue                    # no lantern in the middle of a wade
		nodes.append(_spawn_torch(cell + Vector2i(0, -1)))

# ── what lives at a lake ──────────────────────────────────────────────────────
# A fishing contract (so a cast line finds the deep's "cave" table, where the
# Tidewalker's Knot sleeps) and a drift of rising bubbles. Keyed off the lake's
# own centre cell, so exactly ONE chunk owns each lake and it streams in and out
# with that chunk instead of being spawned once per chunk it overlaps.
func _place_lake_life(c: Vector2i, nodes: Array) -> void:
	var here = _lakes_by_chunk.get(c)
	if here == null:
		return
	for li in here:
		var lk: Dictionary = _lakes[li]
		var centre: Vector2i = lk.c
		var hw: int = int(lk.hw)
		var surface := _map.to_global(_map.map_to_local(centre))
		var fw = FISH_WATER_SCRIPT.new()
		fw.kind = "cave"
		fw.half_width = float(hw) * float(TILE)
		add_child(fw)
		fw.global_position = surface
		nodes.append(fw)
		# bubbles: additive motes drifting up through the water and popping at the
		# top (the forever-rule -- fake the glow, never spend a PointLight2D on it)
		var swarm := Node2D.new()
		swarm.z_index = -1                       # inside the water, behind the player
		add_child(swarm)
		swarm.global_position = surface
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var count := clampi(int(hw / 6), 2, 9)
		# seeded off the lake's own cell, like every other bit of streamed content:
		# with bare randf the bubbles rearranged themselves every time the chunk
		# came back, which the file's "pure function of the seed" contract forbids
		var brng := RandomNumberGenerator.new()
		brng.seed = (hash(centre) ^ 0xB0BB1E) & 0x7fffffff
		for i in range(count):
			var b := ColorRect.new()
			b.size = Vector2(2, 2)
			b.color = Color(0.66, 0.88, 1.0, 0.55)
			b.material = mat
			var bx := brng.randf_range(-float(hw) * 0.8, float(hw) * 0.8) * TILE
			var depth := float(int(lk.d)) * TILE
			b.position = Vector2(bx, brng.randf_range(0.0, depth))
			swarm.add_child(b)
			var rise := brng.randf_range(2.6, 5.2)
			var tw := swarm.create_tween().set_loops()
			tw.tween_property(b, "position:y", 2.0, rise).from(depth).set_trans(Tween.TRANS_SINE)
		nodes.append(swarm)

# FLOOR-DOORS: one per dungeon level, standing on the DELVER'S ROAD at the exact
# cell _build_route chose for it. That is what makes the ladder a CHAIN -- walk the
# road from floor 1 and floor 2 is the next thing you meet, then 3, then 4. The
# frontier door (the deepest you can currently enter) still wears its beacon.
#
# There is nothing to search for and nothing to fall back to: the road guarantees a
# bed under every door. The old code hashed a fresh x per level across the whole
# width -- a 1384-tile average hop between consecutive floors, a third of the world
# -- then scanned, then swept the chunk, then carved a pocket when the rock won.
func _place_floor_doors(c: Vector2i, nodes: Array) -> void:
	for L in range(1, _doors.size() + 1):
		var cell: Vector2i = _doors[L - 1]
		if _chunk_of_cell(cell) == c:
			nodes.append(_spawn_floor_door(_door_stand(cell) - Vector2i(0, 1), L))

# The recorded door cell is a road-bed cell, and about a fifth of those sit on a
# stair lip whose bed was carved away by the next step's headroom -- the floor is
# then one tile lower. Follow it down so the door is planted on the ground the
# player actually stands on, instead of hovering a tile above it.
func _door_stand(cell: Vector2i) -> Vector2i:
	var f := cell
	for i in range(8):
		if _solid_kind(f):
			return f
		f.y += 1
	return cell

# The nearest spot near (x, y0) that something can actually stand in. Shares
# _spot_ok with the mob spawner, so a lever can never be buried in rock either.
func _floor_near(x: int, y0: int) -> Vector2i:
	for r in range(0, 10):
		for sx in [x + r, x - r]:
			for dy in range(-3, 8):
				var cell := Vector2i(sx, y0 + dy)
				if _spot_ok(cell):
					return cell
	return Vector2i(-9999, -9999)

func _spawn_floor_door(cell: Vector2i, level: int) -> Node:
	var d = preload("res://underdark_door.gd").new()
	d.target_level = level
	d.add_to_group("ug_door")
	add_child(d)
	d.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 6)
	d.z_index = 6
	return d

func _depopulate_chunk(c: Vector2i) -> void:
	if not _content.has(c):
		return
	for n in _content[c]:
		if is_instance_valid(n):
			n.queue_free()
	_content.erase(c)

# ── A SPOT SOMETHING CAN ACTUALLY STAND IN ────────────────────────────────────
# The old test asked for one air cell with something under it and one cell of
# headroom. An enemy body is 28x40px = 2.3 x 3.3 TILEs, so 70% of everything this
# returned was spawned INSIDE ROCK, frozen forever (audit, tool_ug_scan) -- the
# "mobs stuck in walls" the dev hit. Now the pocket is measured against the body
# that will occupy it, plus a strip of floor to walk on so nothing is born in a
# one-tile niche it can never leave.
const SPOT_HALF_W := 1                 # 3 tiles wide  (a 28px body needs 2.3)
const SPOT_H := 4                      # 4 tiles tall  (a 40px body needs 3.3)
const SPOT_RUN := 2                    # tiles of floor either side, so it can patrol

func _spot_ok(cell: Vector2i, need_dry := true) -> bool:
	if not _solid_kind(cell + Vector2i(0, 1)):
		return false                                   # nothing to stand on
	if need_dry and _cell_kind(cell) == WATER:
		return false                                   # don't spawn things in a lake
	for dy in range(0, SPOT_H):
		for dx in range(-SPOT_HALF_W, SPOT_HALF_W + 1):
			var k := _cell_kind(cell + Vector2i(dx, -dy))
			if k != AIR and (need_dry or k != WATER):
				return false                           # the body would clip rock
	var run := 0
	for dx in range(-SPOT_RUN, SPOT_RUN + 1):
		if _solid_kind(cell + Vector2i(dx, 1)) and _cell_kind(cell + Vector2i(dx, 0)) == AIR:
			run += 1
	return run >= SPOT_RUN + 1

func _find_floor_cell(c: Vector2i, rng: RandomNumberGenerator):
	for attempt in range(28):
		var cell := Vector2i(c.x * CHUNK + rng.randi_range(2, CHUNK - 3),
			c.y * CHUNK + rng.randi_range(1, CHUNK - 2))
		if _spot_ok(cell):
			return cell
	return null

# The CHUNK a cell belongs to. Every persistent id down here keys off this, not
# off the landing cell: _find_floor_cell is terrain-dependent, so digging near a
# chest moved it to a new cell on the next chunk build -- minting a NEW id,
# respawning an emptied chest with fresh loot (dupe) and orphaning the old entry.
func _chunk_of_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))

# `prefix` keeps the chunk-keyed ids of the DIFFERENT chest kinds apart. A chunk
# rolls its plain chest, its geode and its vaults independently, so they can all
# exist in one chunk: sharing "ug_c_x_y" between the plain chest and the geode's
# meant looting one silently emptied the other, permanently.
func _spawn_chest(cell: Vector2i, biome: int, rng: RandomNumberGenerator, prefix := "ug_c") -> Node:
	var ch := _chunk_of_cell(cell)
	var id := "%s_%d_%d" % [prefix, ch.x, ch.y]
	var opened: bool = GameState.chest_contents.has(id)
	var chest := Node2D.new()
	chest.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 2)
	chest.z_index = 8
	chest.add_to_group("ug_chest")
	chest.set_meta("chest_id", id)
	chest.set_meta("opened", opened)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-11, -15), Vector2(11, -15), Vector2(11, -1), Vector2(-11, -1)])
	lid.color = Color(0.30, 0.24, 0.16) if opened else Color(0.62, 0.45, 0.22)
	chest.add_child(lid)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-11, -9), Vector2(11, -9), Vector2(11, -6), Vector2(-11, -6)])
	band.color = Color(0.85, 0.7, 0.35) if not opened else Color(0.4, 0.35, 0.22)
	chest.add_child(band)
	if not opened:
		var loot := []
		var table: Array = LOOT[clampi(biome, 0, LOOT.size() - 1)]
		for i in range(rng.randi_range(2, 4)):
			loot.append(table[rng.randi_range(0, table.size() - 1)])
		# THE DEEP PICKAXES (2026-07-26): the biome the CURRENT tier can mine hides the
		# pickaxe for the NEXT one, so you earn your way down. Fungal Hollow -> Embersteel
		# (opens Emberdeep); Emberdeep -> Blightbreaker (opens Blightcore). max_stack 1, so a
		# duplicate is harmlessly rejected on pickup once you already carry it.
		if biome == 2 and rng.randf() < 0.5:
			loot.append("tool_pickaxe_ember")
		elif biome == 3 and rng.randf() < 0.5:
			loot.append("tool_pickaxe_blight")
		chest.set_meta("loot", loot)
	add_child(chest)
	return chest

func _spawn_trap(cell: Vector2i) -> Node:
	var t = TRAP_SCENE.instantiate()
	add_child(t)
	t.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 4)
	return t

# a soft radial light texture, shared by every placed torch (built once)
static var _torch_tex: GradientTexture2D = null
static func _make_torch_tex() -> GradientTexture2D:
	if _torch_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
		_torch_tex = GradientTexture2D.new()
		_torch_tex.gradient = g
		_torch_tex.width = 96
		_torch_tex.height = 96
		_torch_tex.fill = GradientTexture2D.FILL_RADIAL
		_torch_tex.fill_from = Vector2(0.5, 0.5)
		_torch_tex.fill_to = Vector2(1.0, 0.5)
	return _torch_tex

# A placed torch: a warm PointLight2D pool + a little bobbing additive flame on a stick,
# planted on a floor cell. Streamed and freed with its chunk like all other content.
func _spawn_torch(cell: Vector2i) -> Node:
	var t := Node2D.new()
	t.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, -8)
	t.z_index = 6
	add_child(t)
	var light := PointLight2D.new()
	light.texture = _make_torch_tex()
	light.texture_scale = 2.6
	light.color = Color(1.0, 0.80, 0.45)
	light.energy = 0.95
	light.shadow_enabled = false
	t.add_child(light)
	var stick := ColorRect.new()
	stick.size = Vector2(2, 9)
	stick.position = Vector2(-1, 1)
	stick.color = Color(0.30, 0.20, 0.12)
	t.add_child(stick)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([Vector2(-3, 2), Vector2(3, 2), Vector2(0, -9)])
	flame.color = Color(1.0, 0.70, 0.25, 0.95)
	flame.material = mat
	flame.position = Vector2(0, -1)
	t.add_child(flame)
	var tw := t.create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector2(1.05, 1.18), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flame, "scale", Vector2(0.95, 0.9), 0.5).set_trans(Tween.TRANS_SINE)
	return t

# cell centre -> body centre for a 40px-tall enemy resting on the block below it:
# the floor's top edge is TILE/2 under the cell centre, and the body reaches 20px
# up from there.
const MOB_FEET_OFF := TILE / 2.0 - 20.0

func _spawn_mob(cell: Vector2i, biome: int, rng: RandomNumberGenerator, elite := false) -> Node:
	var e = ENEMY_SCENE.instantiate()
	if "respawns" in e: e.respawns = false
	if "is_wild" in e: e.is_wild = true
	var wx: float = _map.to_global(_map.map_to_local(cell)).x
	if "wild_home_x" in e: e.wild_home_x = wx
	var depth := float(biome) / float(BIOMES.size() - 1)
	var hp_m := lerpf(1.2, 5.0, depth) * rng.randf_range(0.9, 1.15)
	var dm_m := lerpf(1.1, 3.4, depth) * rng.randf_range(0.9, 1.1)
	if elite:
		hp_m *= 2.4
		dm_m *= 1.8
	if "wave_hp_multiplier" in e: e.wave_hp_multiplier = hp_m
	if "wave_damage_multiplier" in e: e.wave_damage_multiplier = dm_m
	if "wave_speed_multiplier" in e: e.wave_speed_multiplier = lerpf(1.0, 1.35, depth)
	# VARIETY (dev 2026-07-26): keep the difficulty band from depth, but MIX the LOOK across a
	# ~6-wide window so each biome fields 5-6 distinct mob types instead of a wall of clones.
	# apply_mixed_archetype modulos the visual index, so an over-range value just wraps around.
	if e.has_method("apply_mixed_archetype"):
		var stat_b := mini(int(depth * 9.0), 8)
		e.apply_mixed_archetype(stat_b, maxi(0, stat_b + rng.randi_range(-2, 3)))
	elif e.has_method("apply_block_archetype"):
		e.apply_block_archetype(mini(int(depth * 9.0), 8))
	e.add_to_group("course_enemy")
	add_child(e)
	# STAND IT ON THE FLOOR, not 22px above the cell centre. The body is 40px tall,
	# so its centre belongs half a body above the top edge of the block below --
	# spawning it high was half of why mobs woke up inside the ceiling.
	e.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, MOB_FEET_OFF)
	if "detection_range_current" in e and "DETECTION_RANGE" in e:
		var sight: float = e.WILD_SIGHT_MULT if "WILD_SIGHT_MULT" in e else 1.0
		e.detection_range_current = e.DETECTION_RANGE * sight
	if elite:
		e.add_to_group("ug_elite")
		if "modulate" in e:
			e.modulate = Color(1.25, 0.82, 0.82)      # a menacing flush
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var aura := Polygon2D.new()
		aura.polygon = _disc(26.0)
		aura.color = Color(1.0, 0.45, 0.2, 0.24)
		aura.material = add_mat
		aura.z_index = -1
		e.add_child(aura)
	return e

func _disc(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

# ── PUZZLE: the lever-vault. A locked treasure chest + a lever a few tiles away;
# pull the lever (E) to unseal the vault. State persists in _flags. ──────────────
func _spawn_vault(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	# chunk-keyed, like every other persistent id down here: the cell moves when
	# the player digs near it, which re-minted the id and re-stocked the vault
	var vch := _chunk_of_cell(cell)
	var vid := "ugv_%d_%d" % [vch.x, vch.y]
	var pulled: bool = _flags.has(vid)
	# the vault chest (ornate, gold; richer loot + a guaranteed gem)
	var chest := Node2D.new()
	chest.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 2)
	chest.z_index = 8
	chest.add_to_group("ug_chest")
	chest.set_meta("chest_id", vid + "_c")
	chest.set_meta("vault_id", vid)
	chest.set_meta("opened", GameState.chest_contents.has(vid + "_c"))
	chest.set_meta("locked", not pulled)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-13, -17), Vector2(13, -17), Vector2(13, -1), Vector2(-13, -1)])
	lid.color = Color(0.50, 0.38, 0.18)
	chest.add_child(lid)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-13, -11), Vector2(13, -11), Vector2(13, -7), Vector2(-13, -7)])
	band.color = Color(0.96, 0.80, 0.34)
	chest.add_child(band)
	if not bool(chest.get_meta("opened")):
		var loot := []
		var table: Array = LOOT[clampi(biome, 0, LOOT.size() - 1)]
		for i in range(rng.randi_range(3, 5)):
			loot.append(table[rng.randi_range(0, table.size() - 1)])
		loot.append(ORE_DROP[clampi(biome, 0, ORE_DROP.size() - 1)])
		chest.set_meta("loot", loot)
	add_child(chest)
	out.append(chest)
	# the lever, on a floor a short way to one side. ALWAYS spawn one -- otherwise
	# the vault would be locked forever. The fallback must still be REACHABLE: a
	# blind `cell + (loff,0)` could sit inside solid rock, and a lever buried in
	# stone cannot be pressed (the E check needs the player within 52px), so the
	# vault it guards was locked for good. Try the far side, then walk inward
	# toward the chest until a real floor cell turns up.
	var loff := 11 if rng.randf() < 0.5 else -11
	var lc := _floor_near(cell.x + loff, cell.y)
	if lc.x < -9000:
		lc = _floor_near(cell.x - loff, cell.y)
	var step := 1 if loff < 0 else -1
	var probe := loff
	while lc.x < -9000 and absf(probe) > 1.0:
		probe += step
		lc = _floor_near(cell.x + probe, cell.y)
	if lc.x < -9000:
		lc = cell            # last resort: ON the chest, always reachable
	var lever := Node2D.new()
	lever.global_position = _map.to_global(_map.map_to_local(lc))
	lever.z_index = 8
	lever.add_to_group("ug_lever")
	lever.set_meta("vault_id", vid)
	lever.set_meta("pulled", pulled)
	var basep := Polygon2D.new()
	basep.polygon = PackedVector2Array([Vector2(-6, -1), Vector2(6, -1), Vector2(5, -9), Vector2(-5, -9)])
	basep.color = Color(0.30, 0.30, 0.34)
	lever.add_child(basep)
	var handle := Polygon2D.new()
	handle.name = "Handle"
	handle.polygon = PackedVector2Array([Vector2(-2, -7), Vector2(2, -7), Vector2(2, -22), Vector2(-2, -22)])
	handle.color = Color(0.42, 0.82, 0.45) if pulled else Color(0.92, 0.5, 0.2)
	handle.rotation = 0.7 if pulled else -0.7
	lever.add_child(handle)
	var lbl := Label.new()
	lbl.text = "⚙ pull the lever (E)"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = Vector2(-40, -44)
	lever.add_child(lbl)
	add_child(lever)
	out.append(lever)
	return out

func _pull_lever(lv: Node) -> void:
	var vid := String(lv.get_meta("vault_id", ""))
	lv.set_meta("pulled", true)
	_flags[vid] = true
	_save()
	var h = lv.get_node_or_null("Handle")
	if h != null:
		h.rotation = 0.7
		h.color = Color(0.42, 0.82, 0.45)
	for ch in get_tree().get_nodes_in_group("ug_chest"):
		if is_instance_valid(ch) and String(ch.get_meta("vault_id", "")) == vid:
			ch.set_meta("locked", false)
			for c in ch.get_children():
				if c is Polygon2D:
					c.color = c.color.lightened(0.12)
	_notify("⚙ A grind of stone — the vault unseals nearby.")

# ── PUZZLE: a rune-sealed vault. A locked chest opened by lighting all 3 rune
# stones scattered around it (E on each). Each rune's state persists in _flags. ──
func _spawn_runevault(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	# chunk-keyed for the same reason as the lever vault: a dig near the chest
	# used to re-mint this id, re-locking a solved puzzle and re-stocking the loot
	var rch := _chunk_of_cell(cell)
	var vid := "ugr_%d_%d" % [rch.x, rch.y]
	var total := 3
	var lit := 0
	for i in range(total):
		if _flags.has(vid + "_%d" % i):
			lit += 1
	var unlocked := lit >= total
	var chest := Node2D.new()
	chest.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 2)
	chest.z_index = 8
	chest.add_to_group("ug_chest")
	chest.set_meta("chest_id", vid + "_c")
	chest.set_meta("vault_id", vid)
	chest.set_meta("opened", GameState.chest_contents.has(vid + "_c"))
	chest.set_meta("locked", not unlocked)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-13, -17), Vector2(13, -17), Vector2(13, -1), Vector2(-13, -1)])
	lid.color = Color(0.30, 0.20, 0.40)
	chest.add_child(lid)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-13, -11), Vector2(13, -11), Vector2(13, -7), Vector2(-13, -7)])
	band.color = Color(0.62, 0.42, 0.96)
	chest.add_child(band)
	if not bool(chest.get_meta("opened")):
		var loot := []
		var table: Array = LOOT[clampi(biome, 0, LOOT.size() - 1)]
		for i in range(rng.randi_range(3, 5)):
			loot.append(table[rng.randi_range(0, table.size() - 1)])
		loot.append(ORE_DROP[clampi(biome, 0, ORE_DROP.size() - 1)])
		chest.set_meta("loot", loot)
	add_child(chest)
	out.append(chest)
	var offs := [-12, 12, 21]
	for i in range(total):
		var rid := vid + "_%d" % i
		var rcell := _floor_near(cell.x + offs[i], cell.y)
		# a rune buried in solid rock cannot be lit (the E check needs the player
		# within 46px), and ALL THREE are needed -- one unreachable stone locked
		# the chest forever. Walk inward toward the vault for real floor instead
		# of planting it blind.
		var rstep := 1 if offs[i] < 0 else -1
		var rprobe: int = offs[i]
		while rcell.x < -9000 and absf(rprobe) > 1.0:
			rprobe += rstep
			rcell = _floor_near(cell.x + rprobe, cell.y)
		if rcell.x < -9000:
			rcell = cell + Vector2i(0, 0)   # last resort: at the vault, reachable
		var rune := Node2D.new()
		rune.global_position = _map.to_global(_map.map_to_local(rcell))
		rune.z_index = 8
		rune.add_to_group("ug_rune")
		rune.set_meta("rune_id", rid)
		rune.set_meta("vault_id", vid)
		rune.set_meta("rune_total", total)
		var is_lit: bool = _flags.has(rid)
		rune.set_meta("lit", is_lit)
		var stone := Polygon2D.new()
		stone.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(4, -16), Vector2(-4, -16)])
		stone.color = Color(0.22, 0.20, 0.26)
		rune.add_child(stone)
		var gem := Polygon2D.new()
		gem.name = "Gem"
		gem.polygon = PackedVector2Array([Vector2(-3, -7), Vector2(3, -7), Vector2(0, -13)])
		gem.color = Color(0.95, 0.80, 0.35) if is_lit else Color(0.35, 0.55, 0.90)
		rune.add_child(gem)
		if is_lit:
			var am := CanvasItemMaterial.new()
			am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var gl := Polygon2D.new()
			gl.polygon = _disc(10.0)
			gl.color = Color(1, 0.85, 0.4, 0.25)
			gl.material = am
			gl.position = Vector2(0, -9)
			rune.add_child(gl)
		add_child(rune)
		out.append(rune)
	return out

func _light_rune(rune: Node) -> void:
	var rid := String(rune.get_meta("rune_id"))
	var vid := String(rune.get_meta("vault_id"))
	var total := int(rune.get_meta("rune_total", 3))
	rune.set_meta("lit", true)
	_flags[rid] = true
	_save()
	var gem = rune.get_node_or_null("Gem")
	if gem != null:
		gem.color = Color(0.95, 0.80, 0.35)
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var gl := Polygon2D.new()
	gl.polygon = _disc(10.0)
	gl.color = Color(1, 0.85, 0.4, 0.25)
	gl.material = am
	gl.position = Vector2(0, -9)
	rune.add_child(gl)
	var lit := 0
	for i in range(total):
		if _flags.has(vid + "_%d" % i):
			lit += 1
	if lit >= total:
		for ch in get_tree().get_nodes_in_group("ug_chest"):
			if is_instance_valid(ch) and String(ch.get_meta("vault_id", "")) == vid:
				ch.set_meta("locked", false)
				for c in ch.get_children():
					if c is Polygon2D:
						c.color = c.color.lightened(0.15)
		_notify("✦ The runes align — the sealed vault opens.")
	else:
		_notify("✦ A rune kindles. (%d / %d)" % [lit, total])

# ── SPECIAL POCKET: a crystal geode -- glowing shards around a treasure chest. ──
func _spawn_geode(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	var node := Node2D.new()
	node.global_position = _map.to_global(_map.map_to_local(cell))
	node.z_index = 7
	var gem: Color = ORE_GEM[clampi(biome, 0, ORE_GEM.size() - 1)]
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = _disc(38.0)
	glow.color = Color(gem.r, gem.g, gem.b, 0.13)
	glow.material = add_mat
	glow.position = Vector2(0, -14)
	node.add_child(glow)
	for i in range(rng.randi_range(5, 8)):
		var sh := Polygon2D.new()
		var wdt := rng.randf_range(2.5, 5.0)
		var hh := rng.randf_range(9.0, 22.0)
		sh.polygon = PackedVector2Array([Vector2(-wdt, 0), Vector2(wdt, 0), Vector2(wdt * 0.4, -hh), Vector2(-wdt * 0.4, -hh)])
		sh.color = gem.lightened(0.18)
		sh.position = Vector2(rng.randf_range(-30, 30), -1)
		sh.rotation = rng.randf_range(-0.4, 0.4)
		node.add_child(sh)
	add_child(node)
	out.append(node)
	# its OWN id prefix -- a chunk can roll a plain chest and a geode, and
	# sharing an id meant looting one permanently emptied the other
	out.append(_spawn_chest(cell, biome, rng, "ug_g"))   # treasure amid the crystals
	return out

# ── SPECIAL POCKET: a glowing mushroom grove -- pure atmosphere/variety. ────────
func _spawn_grove(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Array:
	var node := Node2D.new()
	node.global_position = _map.to_global(_map.map_to_local(cell))
	node.z_index = 7
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glowc := Color(0.42, 0.95, 0.72)
	for i in range(rng.randi_range(5, 8)):
		var mx := rng.randf_range(-42.0, 42.0)
		var stem := Polygon2D.new()
		stem.polygon = PackedVector2Array([Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(1.5, -8), Vector2(-1.5, -8)])
		stem.color = Color(0.86, 0.86, 0.72)
		stem.position = Vector2(mx, 0)
		node.add_child(stem)
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([Vector2(-5, -8), Vector2(5, -8), Vector2(3, -14), Vector2(-3, -14)])
		cap.color = glowc
		cap.position = Vector2(mx, 0)
		node.add_child(cap)
		var g := Polygon2D.new()
		g.polygon = _disc(10.0)
		g.color = Color(glowc.r, glowc.g, glowc.b, 0.14)
		g.material = add_mat
		g.position = Vector2(mx, -10)
		node.add_child(g)
	add_child(node)
	return [node]

# ── HAZARD: a liquid pool on a cave floor. Deep biomes (Emberdeep+) pool LAVA that
# burns you; shallower biomes pool harmless glowing water. ──────────────────────
func _spawn_pool(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Array:
	var is_lava := biome >= 3
	if not is_lava:
		# WATER IS REAL NOW. This used to paint a flat translucent rectangle on the
		# cave floor and call it a pool; beside an actual carved lake it read as a
		# blue sticker. Lava still works this way (it is a hazard volume, not a
		# place you swim), so only that half survives -- and the fishing contract
		# moved to the lakes themselves, in _populate_chunk.
		return []
	# the pool fills only CONNECTED open floor (audit fix): the fixed rectangle
	# used to burn the player through a rock wall into a sealed neighbouring
	# air pocket. Walk outward from the centre; stop at the first wall each
	# way. (Same rng draw as before, so chunk layouts are unchanged.)
	var want := rng.randi_range(6, 14)
	var left := 0
	while left < want / 2 and _cell_kind(cell + Vector2i(-(left + 1), 0)) == AIR:
		left += 1
	var right := 0
	while right < want / 2 and _cell_kind(cell + Vector2i(right + 1, 0)) == AIR:
		right += 1
	var width := maxi(2, left + right + 1)
	var px_off := (float(right - left) / 2.0) * TILE   # centre on the real span
	var depth := 2
	var node := Node2D.new()
	node.z_index = 6
	node.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 2)
	var liq := ColorRect.new()
	liq.color = Color(0.98, 0.36, 0.10, 0.62) if is_lava else Color(0.24, 0.52, 0.92, 0.42)
	liq.position = Vector2(px_off - width * TILE / 2.0, -depth * TILE)
	liq.size = Vector2(width * TILE, depth * TILE + 4)
	node.add_child(liq)
	if is_lava:
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var glow := ColorRect.new()
		glow.color = Color(1.0, 0.42, 0.12, 0.20)
		glow.material = add_mat
		glow.position = Vector2(px_off - width * TILE / 2.0 - 6, -depth * TILE - 8)
		glow.size = Vector2(width * TILE + 12, depth * TILE + 14)
		node.add_child(glow)
	var area := Area2D.new()
	area.collision_mask = 2
	area.add_to_group("ug_hazard")
	area.set_meta("lava", is_lava)
	area.set_meta("in", false)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width * TILE, depth * TILE)
	cs.shape = r
	cs.position = Vector2(px_off, -depth * TILE / 2.0)
	area.add_child(cs)
	area.body_entered.connect(func(b): if b.is_in_group("player"): area.set_meta("in", true))
	area.body_exited.connect(func(b): if b.is_in_group("player"): area.set_meta("in", false))
	node.add_child(area)
	# FISHING (pillar 3): a WATER pool answers a cast line -- the deep's own
	# richer table ("cave" in fishing.gd, where the Tidewalker's Knot sleeps).
	# Lava never bites. The contract node streams out with its pool, and the
	# player's line notices the water vanishing (is_instance_valid guard).
	if not is_lava:
		var fw = FISH_WATER_SCRIPT.new()
		fw.kind = "cave"
		fw.half_width = float(width) * float(TILE) / 2.0
		fw.position = Vector2(px_off, float(-depth * TILE) + 2.0)
		node.add_child(fw)
	add_child(node)
	return [node]

func _try_loot_chest() -> bool:
	if _player == null:
		return false
	for ch in get_tree().get_nodes_in_group("ug_chest"):
		if not is_instance_valid(ch) or bool(ch.get_meta("opened", false)):
			continue
		if _player.global_position.distance_to(ch.global_position) > 62.0:
			continue
		if bool(ch.get_meta("locked", false)):
			_notify("🔒 Locked. Find the lever that opens this vault.")
			return true
		var loot: Array = ch.get_meta("loot", [])
		var got := {}
		var kept := []          # loot that didn't fit a FULL bag -- left for a return trip
		for id in loot:
			var sid := String(id)
			var landed := true
			if "inventory" in _player and _player.inventory != null:
				if _player.inventory.add_item(sid, 1) > 0:
					# it didn't fit. A duplicate one-of-a-kind (e.g. a tier pickaxe you
					# already carry, max_stack 1) is discarded silently; otherwise the BAG is
					# full, so leave it in the chest rather than destroy it or claim you got it.
					var mdef: Dictionary = Inventory.get_item_def(sid)
					if int(mdef.get("max_stack", 99)) <= 1 and _player.inventory.get_count(sid) >= 1:
						landed = false                       # already own it -> drop the dup
					else:
						kept.append(sid); landed = false     # bag full -> keep in the chest
			if landed:
				got[sid] = int(got.get(sid, 0)) + 1
		if kept.is_empty():
			ch.set_meta("loot", [])
			ch.set_meta("opened", true)
			GameState.chest_contents[String(ch.get_meta("chest_id"))] = {}   # persist: emptied
			for c in ch.get_children():
				if c is Polygon2D:
					c.color = c.color.darkened(0.5)
		else:
			ch.set_meta("loot", kept)   # some didn't fit -> the chest stays openable
		if not got.is_empty():
			var parts := []
			for id in got:
				parts.append("%s ×%d" % [Inventory.get_display_name(id), got[id]])
			_notify("⛏ Chest looted: " + ", ".join(parts))
		if not kept.is_empty():
			_notify("🎒 Your bag is full — the chest still holds the rest.")
		return true
	return false

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pc := _chunk_of(_player.global_position)
	if pc != _cur_chunk:
		_cur_chunk = pc
		_stream_around(pc)
	_drain_stream_queue()
	var b := _biome_of(int(_player.global_position.y / TILE))
	if _bg != null:
		_bg.color = _bg.color.lerp(_biome_backdrop(b), clampf(delta * 1.5, 0.0, 1.0))
	if _cm != null:
		# ONE place decides the cave's colour. _water_tick used to lerp this toward
		# blue itself, which just fought this line every frame and settled on a
		# muddy blend of the two.
		var mood := UNDERWATER_TINT if _submerged else _biome_ambient(b)
		_cm.color = _cm.color.lerp(mood, clampf(delta * (4.0 if _submerged else 1.2), 0.0, 1.0))
	# LAVA burns while you stand in it
	_lava_cd -= delta
	if _lava_cd <= 0.0:
		_lava_cd = 0.4
		for hz in get_tree().get_nodes_in_group("ug_hazard"):
			if is_instance_valid(hz) and bool(hz.get_meta("lava", false)) and bool(hz.get_meta("in", false)):
				if _player.has_method("take_damage"):
					_player.take_damage(7)
				break
	_unstick_cd -= delta
	if _unstick_cd <= 0.0:
		_unstick_cd = 1.0
		_free_the_stuck()

# ── NOTHING STAYS BURIED ──────────────────────────────────────────────────────
# _spot_ok stops mobs being BORN in rock, but a mob can still end up inside a
# wall afterwards: the player mines a tunnel shut on it, a knockback punts it
# into a seam, a chunk restreams under its feet. Once a CharacterBody2D is inside
# collision it can never push itself out -- it just stands there, frozen, which is
# exactly what the dev kept walking past. So sweep once a second and lift anything
# buried up to the nearest open cell above it.
var _unstick_cd := 0.0

func _free_the_stuck() -> void:
	for e in get_tree().get_nodes_in_group("course_enemy"):
		if not is_instance_valid(e) or e.get_parent() != self:
			continue
		var cell := _map.local_to_map(_map.to_local(e.global_position))
		if not _solid_kind(cell):
			continue                                   # standing in open air, fine
		var moved := false
		for up in range(1, 9):                         # look for daylight overhead
			var c2 := cell - Vector2i(0, up)
			# The destination has to hold the WHOLE body, by the same measure the
			# spawner uses. Checking two open cells instead just moved the mob into
			# a pocket its head still clipped -- and since the next sweep only looks
			# at the centre cell, that reads as "fine", so the sweep was quietly
			# turning detectable stuck mobs into undetectable ones.
			if _spot_ok(c2, false):
				e.global_position = _map.to_global(_map.map_to_local(c2)) + Vector2(0, MOB_FEET_OFF)
				moved = true
				break
		if not moved:
			e.queue_free()                             # sealed in solid rock -> let it go

# ══ SWIMMING ═════════════════════════════════════════════════════════════════
# Terraria water: you slow right down, you sink gently instead of falling, you
# hold jump to rise, water breaks your fall, and your breath runs out if you stay
# under. All of it drives the player from OUTSIDE -- this ticks from a node added
# after the player, so it lands on velocity once move_and_slide has run, and
# player.gd is left alone.
const SWIM_SINK := 74.0                # terminal "fall" speed in water
const SWIM_RISE := -136.0              # hold jump to swim up
const SWIM_X := 116.0                  # ~58% of the 200px/s run
const BREATH_MAX := 22.0               # seconds of air
const DROWN_DAMAGE := 6                # per drowning tick, once the air is gone
const DROWN_TICK := 0.9
# Under water the whole cave goes blue and DIM. Scaled by AMBIENT_DARK like every
# biome mood -- a raw (0.24, 0.42, 0.72) is brighter in green and blue than the
# ambient it replaces, so diving lit the cave UP instead of drowning it in blue.
const UNDERWATER_TINT := Color(0.20 * AMBIENT_DARK, 0.52 * AMBIENT_DARK, 1.05 * AMBIENT_DARK)

var _breath := BREATH_MAX
var _submerged := false
var _drown_cd := 0.0
var _splash_cd := 0.0
var _breath_bar: ColorRect = null
var _breath_bg: ColorRect = null

class _WaterTick extends Node:
	var ug: Node = null
	func _physics_process(delta: float) -> void:
		if ug != null and is_instance_valid(ug):
			ug._water_tick(delta)

func _cell_at(p: Vector2) -> Vector2i:
	return _map.local_to_map(_map.to_local(p))

func _water_tick(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _map == null:
		return
	# the player box is 32x48: sample the head and the feet separately, so wading
	# through the shallows is not the same as being under
	var head := _cell_kind(_cell_at(_player.global_position + Vector2(0, -17))) == WATER
	var feet := _cell_kind(_cell_at(_player.global_position + Vector2(0, 19))) == WATER
	var wet := head or feet
	if wet:
		var v: Vector2 = _player.velocity
		v.y = clampf(v.y, SWIM_RISE, SWIM_SINK)
		v.x = clampf(v.x, -SWIM_X, SWIM_X)
		if Input.is_action_pressed("jump"):
			v.y = SWIM_RISE
		_player.velocity = v
		# WATER BREAKS YOUR FALL. player.gd measures fall damage from the apex it
		# remembers, so holding that apex at the surface means a dive costs nothing --
		# which is both the Terraria rule and the reason a lake is a mercy, not a trap.
		if "fall_apex_y" in _player:
			_player.fall_apex_y = _player.global_position.y
	if head != _submerged:
		_submerged = head
		# THROTTLED. Holding jump at a surface makes you bob -- rise clear, fall
		# back in, several times a second -- and an unthrottled splash spawned 10
		# nodes and a tween on every crossing, so treading water quietly bled
		# hundreds of them. Same story walking any shoreline.
		if _splash_cd <= 0.0:
			_splash_cd = 0.45
			_splash(_player.global_position + Vector2(0, 8), head)
	_splash_cd = maxf(0.0, _splash_cd - delta)
	if head:
		_breath = maxf(0.0, _breath - delta)
		if _breath <= 0.0:
			_drown_cd -= delta
			if _drown_cd <= 0.0:
				_drown_cd = DROWN_TICK
				if _player.has_method("take_damage"):
					_player.take_damage(DROWN_DAMAGE)
				_notify("💨 You're out of air!")
	else:
		_breath = minf(BREATH_MAX, _breath + delta * 3.4)   # you catch it back quickly
		_drown_cd = 0.0
	_update_breath_hud()

# a burst of droplets when you break the surface either way
func _splash(at: Vector2, going_in: bool) -> void:
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(10):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(0.62, 0.86, 1.0, 0.9)
		p.material = add_mat
		p.global_position = at + Vector2(randf_range(-12, 12), 0)
		p.z_index = 20
		add_child(p)
		var t := create_tween()
		t.set_parallel(true)
		var up := randf_range(-34, -14) if going_in else randf_range(-22, -8)
		t.tween_property(p, "global_position", p.global_position + Vector2(randf_range(-22, 22), up), 0.42)
		t.tween_property(p, "modulate:a", 0.0, 0.42)
		t.chain().tween_callback(p.queue_free)

func _update_breath_hud() -> void:
	if _breath_bar == null:
		return
	var show := _breath < BREATH_MAX - 0.05
	_breath_bg.visible = show
	_breath_bar.visible = show
	_breath_bar.size.x = 100.0 * (_breath / BREATH_MAX)
	_breath_bar.color = Color(0.35, 0.75, 1.0) if _breath > BREATH_MAX * 0.28 else Color(1.0, 0.4, 0.35)

# ── mining API (called by the player's pickaxe swing) ─────────────────────────
# Terraria feel: dig the tile at the CURSOR within reach; smart=true auto-targets
# the nearest solid tile toward the aim (no pixel-precise aiming needed).
func mine_at(cursor: Vector2, from: Vector2, reach_px: float, smart: bool, pick_tier: int, player: Node) -> bool:
	if _map == null:
		return false
	var cell: Vector2i
	if smart:
		var dir := (cursor - from)
		dir = dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
		# scan only the small tile box within reach of the player (not the whole
		# loaded map -- that was thousands of cells every dig tick).
		var center := _map.local_to_map(_map.to_local(from))
		var rad := int(ceil(reach_px / float(TILE))) + 1
		var best := Vector2i.ZERO
		var have := false
		var best_score := 1.0e9
		for oy in range(-rad, rad + 1):
			for ox in range(-rad, rad + 1):
				var used := center + Vector2i(ox, oy)
				if _map.get_cell_source_id(used) == -1:
					continue
				var c := _map.to_global(_map.map_to_local(used))
				var d := from.distance_to(c)
				if d > reach_px:
					continue
				var tw := (c - from)
				if tw.length() > 0.01 and dir.dot(tw.normalized()) < -0.25:
					continue
				var score := d - dir.dot(tw.normalized()) * 10.0
				if score < best_score:
					best_score = score; best = used; have = true
		if not have:
			return false
		cell = best
	else:
		cell = _map.local_to_map(_map.to_local(cursor))
		if _map.get_cell_source_id(cell) == -1:
			return false
		if from.distance_to(_map.to_global(_map.map_to_local(cell))) > reach_px:
			return false
	return _break(cell, pick_tier, player)

func _break(cell: Vector2i, pick_tier: int, player: Node) -> bool:
	var kind := _map.get_cell_atlas_coords(cell).x
	var is_ore := kind >= ORE_COL
	var bi := (kind - ORE_COL) if is_ore else kind
	var biome: Dictionary = BIOMES[clampi(bi, 0, BIOMES.size() - 1)]
	var center := _map.to_global(_map.map_to_local(cell))
	if pick_tier < int(biome.tier):
		_notify("%s is too hard for your pickaxe — you'll need a stronger one." % biome.name)
		_chips(center, biome.accent, true)
		return false
	var hard := int(biome.hard) + (2 if is_ore else 0)   # ore is a bit tougher
	var left := int(_hp.get(cell, hard))
	left -= 1
	_chips(center, (ORE_GEM[bi] if is_ore else biome.base), false)
	if left <= 0:
		_hp.erase(cell)
		_edits[cell] = AIR
		_map.erase_cell(cell)
		_sparkmap.erase_cell(cell)      # ...and its glint, or the vein you just mined
		                                # keeps twinkling in mid-air until the chunk reloads
		# everything this swing just uncovered is open now -- re-face all four
		# neighbours, or a tunnel you dig stays walled in flat interior rock
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			_reface(cell + d)
		if player != null and "inventory" in player and player.inventory != null:
			var drop_id: String = ORE_DROP[bi] if is_ore else "stone"
			var leftover: int = player.inventory.add_item(drop_id, 1)
			if is_ore and leftover <= 0:
				# only celebrate the vein if the drop actually landed -- a full bag or a
				# max_stack-1 drop already held (Blightcore ore = relic_mountain, now
				# reachable via the tier-3 pickaxe) must not claim a haul it didn't give.
				_notify("⛏ Struck a vein — " + Inventory.get_display_name(drop_id) + "!")
			if leftover > 0:
				# the tile is already AIR by this line -- a full bag used to simply
				# DESTROY the ore/stone with it (the chest path keeps unfit loot;
				# mining didn't). Pop it out as a world pickup instead, exactly
				# like every surface harvest node.
				var d = MATERIAL_PICKUP.new()
				add_child(d)
				d.setup(drop_id, leftover, center + Vector2(0, -8.0))
	else:
		_hp[cell] = left
	return true

func _chips(at: Vector2, col: Color, spark: bool) -> void:
	for i in range(3):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1, 0.9, 0.5) if spark else col.lightened(0.15)
		p.global_position = at
		p.z_index = 30
		add_child(p)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(p, "global_position", at + Vector2(randf_range(-16, 16), randf_range(-20, -4)), 0.3)
		t.tween_property(p, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(p.queue_free)

# ── persistence: save only the diff ───────────────────────────────────────────
# the dev's real dig-diff is not a test fixture either (global hunt
# 2026-07-28): under MONARCH_TEST the tunnels save to a sidecar, same as
# GameState.active_save_path
func _save_path() -> String:
	if OS.has_environment("MONARCH_TEST"):
		return "user://underground_save_test.json"
	return SAVE_PATH

func _load_save() -> void:
	var path := _save_path()
	if not FileAccess.file_exists(path):
		path = _save_path() + ".tmp"      # the crash-window survivor
		if not FileAccess.file_exists(path):
			return
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	# new format {"edits":{...},"flags":{...}}; old format was the edits dict itself
	var edits = data.get("edits", data)
	if typeof(edits) == TYPE_DICTIONARY:
		for k in edits.keys():
			var parts: PackedStringArray = String(k).split(",")
			if parts.size() == 2:
				_edits[Vector2i(int(parts[0]), int(parts[1]))] = int(edits[k])
	var flags = data.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		for k in flags.keys():
			_flags[String(k)] = true

func _save() -> void:
	var e := {}
	for cell in _edits.keys():
		e["%d,%d" % [cell.x, cell.y]] = _edits[cell]
	var fl := {}
	for id in _flags.keys():
		fl[id] = 1
	# tmp-then-rename, like the main save: open(WRITE) truncates at once, and
	# a crash mid-write used to cost every tunnel ever dug
	var f := FileAccess.open(_save_path() + ".tmp", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"edits": e, "flags": fl}))
		f.close()
		DirAccess.remove_absolute(_save_path())
		DirAccess.rename_absolute(_save_path() + ".tmp", _save_path())

func _exit_tree() -> void:
	_save()

# ── the tileset (one natural-looking block per biome) ─────────────────────────
# EVERY block used to be drawn with a lit top lip and a light-to-dark gradient --
# including blocks buried forty tiles deep with rock on every side. A solid mass
# of stone therefore rendered as repeating light-dark bands, which is why the
# caves read as HORIZONTAL STRIPES rather than rock.
#
# Terraria lights the exposed SURFACE and leaves the interior flat, so the atlas
# now has two rows and _load_chunk picks between them from the cell above:
#   row 0  INTERIOR   -- uniform, a shade darker, grain only. Masses read solid.
#   row 1  EXPOSED    -- the lit lip and the gradient, for a block open to the air.
const TILE_INTERIOR := 0
const TILE_EXPOSED := 1
const TILE_FACE := 2
const TILE_ROWS := 3

func _build_tileset() -> void:
	var n := BIOMES.size()
	var img := Image.create(n * 2 * TILE, TILE_ROWS * TILE, false, Image.FORMAT_RGBA8)
	for c in range(n):
		var base: Color = BIOMES[c].base
		var gem: Color = ORE_GEM[c]
		for row in range(TILE_ROWS):
			for x in range(TILE):
				for y in range(TILE):
					var col: Color
					if row == TILE_EXPOSED:
						var t := float(y) / float(TILE - 1)
						col = base.lightened(0.10 * (1.0 - t)).darkened(0.16 * t)
						if y <= 1:
							col = base.lightened(0.20)         # the lit surface lip
					elif row == TILE_FACE:
						# a cave WALL: roofed over, but open to one side. Catches a
						# little light so the outline of a cavern reads instead of
						# dissolving into one flat dark mass.
						col = base.lightened(0.05)
					else:
						col = base.darkened(0.10)              # buried: flat and a touch darker
					var h := ((x * 73856093) ^ (y * 19349663) ^ (c * 83492791)) & 0x7fffffff
					if h % 34 == 0:
						col = col.darkened(0.24)               # a sparse crack
					elif h % 57 == 0:
						col = col.lightened(0.07)
					img.set_pixel(c * TILE + x, row * TILE + y, col)
					# ORE variant: the same block, salted with bright gem clusters
					var oc := col
					var oh := ((x * 40503) ^ (y * 20441) ^ (c * 12553)) & 0x7fffffff
					if oh % 6 == 0:
						oc = gem
					elif oh % 13 == 0:
						oc = gem.darkened(0.35)
					img.set_pixel((ORE_COL + c) * TILE + x, row * TILE + y, oc)
	_map = TileMapLayer.new()
	_map.tile_set = _make_tileset(img, true)
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_map)

func _make_tileset(img: Image, collide: bool) -> TileSet:
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	if collide:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)
		ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var sq := PackedVector2Array([
		Vector2(-TILE / 2.0, -TILE / 2.0), Vector2(TILE / 2.0, -TILE / 2.0),
		Vector2(TILE / 2.0, TILE / 2.0), Vector2(-TILE / 2.0, TILE / 2.0)])
	# every row of the atlas, so a texture can carry variants (the block tileset
	# has an interior row and an exposed-surface row); the wall/water/spark
	# textures are one row tall and are unaffected
	for r in range(int(img.get_height() / TILE)):
		for c in range(int(img.get_width() / TILE)):
			var coord := Vector2i(c, r)
			src.create_tile(coord)
			if collide:
				var td := src.get_tile_data(coord, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, sq)
	return ts

# ── THE GLINT ON THE ORE ──────────────────────────────────────────────────────
# The dev asked for sparkly materials you can spot from a distance. This is a
# transparent overlay layer holding ONLY the gem pixels of each ore block, drawn
# ADDITIVELY (the forever-rule: fake glow with additive canvas items, never a
# PointLight2D -- real 2D lights are what made the old caves lag) and twinkled by
# a shader off world position + TIME. Zero nodes, zero tweens, zero light budget.
var _sparkmap: TileMapLayer
const SPARK_SHADER := """
shader_type canvas_item;
render_mode blend_add;
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// each gem cluster breathes on its own phase, set by where it sits in the world
	float phase = wpos.x * 0.09 + wpos.y * 0.13;
	float slow = 0.55 + 0.45 * sin(TIME * 1.3 + phase);
	// ...and every so often one catches the light and flashes
	float glint = smoothstep(0.90, 1.0, sin(TIME * 2.1 + phase * 1.7));
	c.a *= slow;
	c.rgb *= 1.0 + glint * 1.9;
	COLOR = c;
}
"""

func _build_sparkmap() -> void:
	var n := BIOMES.size()
	var img := Image.create(n * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(n):
		var gem: Color = ORE_GEM[c]
		for x in range(TILE):
			for y in range(TILE):
				# EXACTLY the gem pixels _build_tileset salts into the ore variant,
				# so the glint lands on the crystals and nowhere else
				var oh := ((x * 40503) ^ (y * 20441) ^ (c * 12553)) & 0x7fffffff
				var col := Color(0, 0, 0, 0)
				if oh % 6 == 0:
					col = Color(gem.r, gem.g, gem.b, 0.85)
				elif oh % 13 == 0:
					col = Color(gem.r, gem.g, gem.b, 0.35)
				img.set_pixel(c * TILE + x, y, col)
	_sparkmap = TileMapLayer.new()
	_sparkmap.tile_set = _make_tileset(img, false)
	_sparkmap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sparkmap.z_index = 0            # above _map, below the player (both z 0, tree order decides)
	# the additive blend lives in SPARK_SHADER's `render_mode blend_add` -- a
	# CanvasItemMaterial here would be overwritten by the ShaderMaterial below,
	# which is exactly how the glint quietly ended up alpha-blended
	var sh := Shader.new()
	sh.code = SPARK_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = sh
	_sparkmap.material = smat
	_sparkmap.light_mask = 0
	add_child(_sparkmap)

# ── THE WATER ─────────────────────────────────────────────────────────────────
# Its own non-colliding layer, drawn BEHIND the player so you can see yourself
# swimming. Two tiles: the body, and a bright surface for the waterline. The
# shader gives it Terraria's slow swell plus drifting caustic glimmers.
var _watermap: TileMapLayer
const WATER_SHADER := """
shader_type canvas_item;
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// the slow swell: two crossing waves, so it never reads as a repeating tile
	float swell = sin(wpos.x * 0.045 + TIME * 1.25) * 0.5 + sin(wpos.y * 0.07 - TIME * 0.8) * 0.5;
	c.rgb += vec3(0.02, 0.05, 0.10) * swell;
	// caustics: bright ribbons drifting across the surface
	float ca = sin(wpos.x * 0.19 + TIME * 1.7) * sin(wpos.y * 0.15 - TIME * 1.1);
	c.rgb += vec3(0.20, 0.40, 0.52) * smoothstep(0.82, 1.0, ca) * 0.6;
	COLOR = c;
}
"""

func _build_watermap() -> void:
	var img := Image.create(2 * TILE, TILE, false, Image.FORMAT_RGBA8)
	var body := Color(0.11, 0.33, 0.76, 0.60)
	for t in range(2):
		for x in range(TILE):
			for y in range(TILE):
				var col := body
				var h := ((x * 7919) ^ (y * 104729) ^ (t * 31337)) & 0x7fffffff
				if h % 23 == 0:
					col = Color(0.20, 0.46, 0.88, 0.58)      # a little depth mottle
				if t == 1 and y <= 1:
					col = Color(0.62, 0.86, 1.00, 0.80)      # THE WATERLINE
				elif t == 1 and y <= 3:
					col = Color(0.24, 0.55, 0.95, 0.66)
				img.set_pixel(t * TILE + x, y, col)
	_watermap = TileMapLayer.new()
	_watermap.tile_set = _make_tileset(img, false)
	_watermap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_watermap.z_index = -1           # behind the player, in front of the back-walls
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = sh
	_watermap.material = smat
	add_child(_watermap)

# Dark textured back-wall behind EVERYTHING, so the big open caverns read as
# carved rock, not dead black (Terraria's back walls).
func _build_wallmap() -> void:
	var img := Image.create(BIOMES.size() * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(BIOMES.size()):
		var wall: Color = (BIOMES[c].base as Color).darkened(0.64)
		for x in range(TILE):
			for y in range(TILE):
				var col := wall
				var off := ((int(y) / 6) % 2) * 8
				if y % 6 == 0 or (x + off) % 16 == 0:
					col = wall.darkened(0.26)
				var h := ((x * 12345 + y * 6789 + c * 271)) & 0x7fffffff
				if h % 31 == 0:
					col = wall.lightened(0.06)
				img.set_pixel(c * TILE + x, y, col)
	_wallmap = TileMapLayer.new()
	_wallmap.tile_set = _make_tileset(img, false)
	_wallmap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wallmap.z_index = -5
	add_child(_wallmap)

var _cm: CanvasModulate = null
func _ensure_dark() -> void:
	_cm = CanvasModulate.new()
	_cm.color = _biome_ambient(0)          # a dim underworld, tinted by biome (see _process)
	add_child(_cm)

# each biome bathes the caves in its own mood: warm earth, cold stone, sickly
# green fungus, ember-red, violet blight.
const BIOME_AMBIENT := [
	Color(0.74, 0.69, 0.60), Color(0.66, 0.69, 0.75), Color(0.58, 0.78, 0.66),
	Color(0.84, 0.60, 0.48), Color(0.66, 0.54, 0.80)]
# Terraria-dim (dev 2026-07-26): the caves are DARK now -- the biome tint is scaled well
# down so you can't see far unaided. The player's carried torch and the placed wall torches
# (_spawn_torch, ~30% of spots) light the rest back up in warm pools.
const AMBIENT_DARK := 0.40
func _biome_ambient(b: int) -> Color:
	var c: Color = BIOME_AMBIENT[clampi(b, 0, BIOME_AMBIENT.size() - 1)]
	return Color(c.r * AMBIENT_DARK, c.g * AMBIENT_DARK, c.b * AMBIENT_DARK, 1.0)

# A dark cave behind everything so open air reads as depth, not flat grey. Tinted
# toward the current biome as you descend (see _process) for atmosphere.
var _bg: ColorRect = null
func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.045, 0.06)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg)

func _biome_backdrop(b: int) -> Color:
	var base: Color = BIOMES[clampi(b, 0, BIOMES.size() - 1)].base
	return base.darkened(0.78).lerp(Color(0.04, 0.04, 0.05), 0.4)

# ── the real player, at the entry ─────────────────────────────────────────────
func _spawn_player() -> void:
	_player = preload("res://player.tscn").instantiate()
	# POSITION FIRST. add_child runs player._ready synchronously, and the first
	# thing it does is `spawn_position = global_position` -- so adding before
	# placing recorded (0,0) as the respawn point. Column 0 is the world's bedrock
	# wall (`x < 2` is solid at every row), and a CharacterBody2D cannot push
	# itself out of collision, so dying down here sealed you in rock with no way
	# out but Quit to Menu. Cheap to hit now that drowning exists.
	_player.global_position = _spawn_pos
	add_child(_player)                       # its _ready auto-applies pending_player_state
	_player.global_position = _spawn_pos
	if "spawn_position" in _player:
		_player.spawn_position = _spawn_pos  # belt and braces: death returns you here
	var cam = _player.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(0.6, 0.6)         # match the village so the player reads the same size
	# make sure a Miner's Pickaxe is in the bag so digging is possible right away
	if "inventory" in _player and _player.inventory != null:
		if _player.inventory.get_count("tool_pickaxe") == 0:
			_player.inventory.add_item("tool_pickaxe", 1)

func _spawn_exit() -> void:
	# a way back to the surface at the entry (press E). Reuses the village.
	var area := Area2D.new()
	area.position = _entry + Vector2(-40.0, -10.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 90)
	cs.shape = rect
	area.add_child(cs)
	add_child(area)
	var lbl := Label.new()
	lbl.text = "↑ EXIT (E)"
	lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = _entry + Vector2(-46.0, -78.0)
	add_child(lbl)
	_exit_area = area

var _exit_area: Area2D = null

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E:
		if _player != null and _exit_area != null \
				and _player.global_position.distance_to(_exit_area.global_position) < 70.0:
			_return_to_village()
			return
		if _player != null:
			for rn in get_tree().get_nodes_in_group("ug_rune"):
				if is_instance_valid(rn) and not bool(rn.get_meta("lit", false)) \
						and _player.global_position.distance_to(rn.global_position) < 46.0:
					_light_rune(rn)
					return
			for lv in get_tree().get_nodes_in_group("ug_lever"):
				if is_instance_valid(lv) and not bool(lv.get_meta("pulled", false)) \
						and _player.global_position.distance_to(lv.global_position) < 52.0:
					_pull_lever(lv)
					return
		_try_loot_chest()

func _return_to_village() -> void:
	_save()
	GameState.in_dungeon = false
	if _player != null:
		GameState.pending_player_state = GameState.capture_player_state(_player)
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

# The player writes HP/level straight into $"../CanvasLayer/{HealthBarFill,HealthLabel,
# CurrencyLabel}" -- the same node names main.tscn and the dungeon provide. Build
# that CanvasLayer with those exact names BEFORE the player spawns, so its _ready's
# HUD refresh resolves instead of erroring.
func _build_hud_frame() -> void:
	var cl := CanvasLayer.new()
	cl.name = "CanvasLayer"
	cl.layer = 10
	add_child(cl)
	var frame := ColorRect.new()
	frame.color = Color(0.08, 0.08, 0.10, 0.9)
	frame.position = Vector2(20, 20)
	frame.size = Vector2(104, 18)
	cl.add_child(frame)
	var fill := ColorRect.new()
	fill.name = "HealthBarFill"
	fill.color = Color(0.78, 0.22, 0.26)
	fill.position = Vector2(22, 22)
	fill.size = Vector2(100, 14)
	cl.add_child(fill)
	var hlabel := Label.new()
	hlabel.name = "HealthLabel"
	hlabel.position = Vector2(28, 19)
	hlabel.add_theme_font_size_override("font_size", 12)
	hlabel.add_theme_color_override("font_color", Color(1, 1, 1))
	hlabel.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hlabel.add_theme_constant_override("outline_size", 4)
	cl.add_child(hlabel)
	var clabel := Label.new()
	clabel.name = "CurrencyLabel"
	clabel.position = Vector2(20, 44)
	clabel.add_theme_font_size_override("font_size", 14)
	clabel.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	clabel.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	clabel.add_theme_constant_override("outline_size", 4)
	cl.add_child(clabel)
	var hint := Label.new()
	hint.text = "⛏ Hold LEFT-CLICK to mine  ·  Shift = smart-aim  ·  go DOWN — deeper is higher level  ·  E at the top to leave"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
	hint.offset_top = -84.0; hint.offset_left = 20.0
	cl.add_child(hint)
	# player-personal message stack: this scene had none and _notify() is the
	# village channel (silenced while in_dungeon), so ALL mining/loot/vault/pickaxe-gate
	# feedback was invisible -- "no feedback reads as broken" (dev 2026-07-26).
	var notif := preload("res://notification_stack.gd").new()
	notif.name = "NotificationStack"
	notif.anchor_left = 1.0; notif.anchor_right = 1.0
	notif.offset_left = -420.0; notif.offset_right = -20.0
	notif.offset_top = 24.0
	cl.add_child(notif)

# player-personal underground feedback -> the scene's own stack, UNGATED. GameState.notify
# is the VILLAGE channel (silenced while in_dungeon, see game_state.gd:2154), so the
# underground must talk to the stack directly or the player gets no messages at all.
func _notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack != null and stack.has_method("show_notification"):
		stack.show_notification(text)

func _build_hud_extras() -> void:
	add_child(preload("res://hotbar_ui.gd").new())
	add_child(preload("res://admin_panel.gd").new())
	# THIS SCENE HAD NO WAY OUT (scan 2026-07-27). underground.tscn is two nodes
	# and carries neither of the overlays the other two playable scenes get from
	# their .tscn, so down here ESC did nothing at all: no pause, no window sweep
	# (the bag/skill tree could only be closed with their own keys) and -- worst
	# -- no Quit to Menu, i.e. no way to save and exit from the cave. Death was
    # equally bare: player.die() looks for "../DeathScreen", found none, and fell
	# through to a silent 5-second wait with no countdown and no death toll.
	# (pause_menu.gd / death_screen.gd bind to children authored in main.tscn and
	# dungeon_interior.tscn, so they cannot simply be .new()'d here -- this scene
	# builds its own, with the same names and the same public API.)
	_build_pause_overlay()
	var death := preload("res://death_screen.gd").new()
	death.name = "DeathScreen"
	add_child(death)
	_build_breath_hud()
	# LAST child, so its _physics_process runs AFTER the player's: swimming is a
	# correction applied to velocity once move_and_slide has already had its say.
	var wt := _WaterTick.new()
	wt.ug = self
	add_child(wt)

# The air meter. Hidden until you actually go under, so a dry run never carries
# a bar that means nothing.
func _build_breath_hud() -> void:
	var cl := get_node_or_null("CanvasLayer")
	if cl == null:
		return
	_breath_bg = ColorRect.new()
	_breath_bg.color = Color(0.05, 0.10, 0.16, 0.85)
	_breath_bg.position = Vector2(20, 62)
	_breath_bg.size = Vector2(104, 12)
	_breath_bg.visible = false
	cl.add_child(_breath_bg)
	_breath_bar = ColorRect.new()
	_breath_bar.color = Color(0.35, 0.75, 1.0)
	_breath_bar.position = Vector2(22, 64)
	_breath_bar.size = Vector2(100, 8)
	_breath_bar.visible = false
	cl.add_child(_breath_bar)

# A compact stand-in for the pause menu the other scenes get from their .tscn:
# Resume, and the save-and-leave the cave had no way to reach.
func _build_pause_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.name = "PauseMenu"
	cl.layer = 80
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	cl.visible = false
	cl.add_to_group("pause_menu")     # DialogueBox.finish() checks this group
	cl.set_script(preload("res://underground_pause.gd"))
	add_child(cl)

# THE CAVE THEME (dev-supplied, 2026-07-27). This world used to run in total
# silence -- the stub below was never filled in. underground.tscn has no
# MusicPlayer node, so the player is made here; the same track the dungeon
# floors use, so "below ground" has one voice throughout.
# a var, not a const: `loop` is set on the resource below, and GDScript refuses
# property assignment through a const reference
var cave_music: AudioStreamOggVorbis = preload("res://audio/cave_theme.ogg")

func start_music() -> void:
	var mp := AudioStreamPlayer.new()
	mp.name = "MusicPlayer"
	cave_music.loop = true
	mp.stream = cave_music
	mp.bus = "Music"          # controlled by the Music volume slider
	add_child(mp)
	mp.play()
