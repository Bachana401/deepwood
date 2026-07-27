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
const BIOME_H := 240                   # tiles of depth per biome -> 1200 deep
const SAVE_PATH := "user://underground_save.json"
const AIR := -1

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

func _ready() -> void:
	add_to_group("tile_world")
	GameState.in_dungeon = true          # so village-only ticks stay quiet
	GameState.returning_from_dungeon = false   # we own the return here; don't hand the village a stale flag
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
	_build_backdrop()        # a dark cave behind the tiles (so air isn't flat grey)
	_build_wallmap()         # dark textured back-walls behind everything (Terraria look)
	_build_tileset()
	_ensure_dark()
	_build_hud_frame()       # BEFORE the player: its _ready writes to ../CanvasLayer/*
	_load_save()
	# entry: a solid ledge at the top of the true path, so you don't fall straight in
	var ex := int(_truepath_x(ENTRY_ROW))
	_entry = Vector2(ex * TILE, (ENTRY_ROW - 2) * TILE)
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

const ENTRY_ROW := 5

# ── deterministic 2-D world ───────────────────────────────────────────────────
func _biome_of(y: int) -> int:
	return clampi(int(floor(float(y) / float(BIOME_H))), 0, BIOMES.size() - 1)

# the ONE true path: a switchbacking column that descends the whole world. Carved
# open for its full height so you can always get down (and mine sideways off it).
func _truepath_x(y: int) -> float:
	var cx := float(WIDTH) * 0.5
	return cx + 150.0 * sin(float(y) * 0.013) + 46.0 * sin(float(y) * 0.041 + 1.7)

func _gen_kind(x: int, y: int) -> int:
	if x < 2 or x >= WIDTH - 2 or y >= DEPTH:
		return _biome_of(clampi(y, 0, DEPTH - 1))     # solid walls / bedrock floor
	if y < 1:
		return AIR                                    # open sky above the entry
	# ENTRY CHAMBER: an open room at the top with a solid ledge to stand on, so you
	# spawn able to walk around and pick a direction (not buried, not free-falling).
	if absf(float(x) - _truepath_x(ENTRY_ROW)) < 13.0:
		if y < ENTRY_ROW:
			return AIR
		if y <= ENTRY_ROW + 1:
			return _biome_of(y)
	# THE TRUE PATH: a walkable corridor carved the whole way down. It PIERCES the
	# seal bands so you can ALWAYS descend (even before you've earned a stronger
	# pickaxe) -- the seal still walls off the rock to either side, gated for loot.
	if absf(float(x) - _truepath_x(y)) < 4.0:
		return AIR
	var b := _biome_of(y)
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

func _stream_around(center: Vector2i) -> void:
	var want := {}
	for cy in range(center.y - LOAD_R, center.y + LOAD_R + 1):
		for cx in range(center.x - LOAD_R, center.x + LOAD_R + 1):
			want[Vector2i(cx, cy)] = true
	for c in want.keys():
		if not _loaded.has(c):
			_load_chunk(c)
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

func _load_chunk(c: Vector2i) -> void:
	_loaded[c] = true
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			var cell := Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly)
			_wallmap.set_cell(cell, 0, Vector2i(_biome_of(cell.y), 0))   # back-wall always
			var kind := _cell_kind(cell)
			if kind != AIR:
				_map.set_cell(cell, 0, Vector2i(kind, 0))               # solid block on top
	_populate_chunk(c)

func _unload_chunk(c: Vector2i) -> void:
	_depopulate_chunk(c)
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			var cell := Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly)
			_map.erase_cell(cell)
			_wallmap.erase_cell(cell)
	_loaded.erase(c)

# ── streamed content: chests (loot), depth-scaled mobs, traps ─────────────────
func _populate_chunk(c: Vector2i) -> void:
	if c.y < 1:
		# the entry stays a SAFE LANDING (no mobs/traps/chests), but its floor-doors --
		# levels 1-2 fall in chunk-row 0 -- must still spawn, or those two entrances AND
		# the early frontier BEACON are silently missing (dev 2026-07-26).
		var top_nodes: Array = []
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
	for _ti in range(5):
		if rng.randf() < 0.3:
			var lc = _find_floor_cell(c, rng)
			if lc != null:
				nodes.append(_spawn_torch(lc))
	_place_floor_doors(c, nodes)
	if not nodes.is_empty():
		_content[c] = nodes

# FLOOR-DOORS on the true path: one per dungeon level by depth (deeper = higher floor). The
# frontier door -- the deepest you can currently enter -- wears a beacon, so the way down is
# always clear. Leaving a floor returns you here. Extracted so chunk-row 0 (levels 1-2) can
# place its doors while staying a mob-free safe landing.
func _place_floor_doors(c: Vector2i, nodes: Array) -> void:
	var level_h := float(DEPTH) / 100.0
	var l_lo := maxi(1, int(ceil(float(c.y * CHUNK) / level_h)))
	var l_hi := mini(100, int(float(c.y * CHUNK + CHUNK - 1) / level_h))
	for L in range(l_lo, l_hi + 1):
		var dy := mini(int(float(L) * level_h), DEPTH - 2)   # keep L=100 off the bedrock row
		# scatter each level's door across the width -- FOUND by exploring, deterministic
		# per level so returns land right.
		var dx := 8 + (hash(L * 2654435761) & 0x7fffffff) % (WIDTH - 16)
		if dx >= c.x * CHUNK and dx < (c.x + 1) * CHUNK:
			var dcell := _floor_near(dx, dy)
			if dcell.x <= -9000:
				# the scattered column was solid rock -> scan across the chunk (kept local
				# to c so it unloads/respawns with it, no cross-chunk blink).
				for sx in [c.x * CHUNK + CHUNK / 2, c.x * CHUNK + 6, c.x * CHUNK + CHUNK - 7]:
					dcell = _floor_near(sx, dy)
					if dcell.x > -9000:
						break
			if dcell.x <= -9000:
				# sweep the WHOLE chunk row before giving up (audit fix): each
				# level's door exists in exactly ONE chunk, so a level whose
				# scatter column AND all three fallbacks hit rock simply had no
				# door anywhere -- breaking the one-door-per-floor promise.
				var sx2 := c.x * CHUNK + 4
				while dcell.x <= -9000 and sx2 < (c.x + 1) * CHUNK - 4:
					dcell = _floor_near(sx2, dy)
					sx2 += 6
			if dcell.x <= -9000:
				# LAST RESORT: the band is solid -- carve a small pocket. The
				# door promise outranks untouched terrain.
				var px := c.x * CHUNK + CHUNK / 2
				for ax in range(px - 1, px + 2):
					for ay in range(dy - 2, dy + 1):
						var acell := Vector2i(ax, ay)
						_edits[acell] = AIR
						_map.erase_cell(acell)
				dcell = Vector2i(px, dy)
			nodes.append(_spawn_floor_door(dcell, L))

func _floor_near(x: int, y0: int) -> Vector2i:
	for r in range(0, 10):
		for sx in [x + r, x - r]:
			for dy in range(-3, 8):
				var cell := Vector2i(sx, y0 + dy)
				if _cell_kind(cell) == AIR and _cell_kind(cell + Vector2i(0, 1)) != AIR \
						and _cell_kind(cell + Vector2i(0, -1)) == AIR and _cell_kind(cell + Vector2i(0, -2)) == AIR:
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

# a floor spot inside the chunk: an AIR cell with solid below and headroom above
func _find_floor_cell(c: Vector2i, rng: RandomNumberGenerator):
	for attempt in range(24):
		var cell := Vector2i(c.x * CHUNK + rng.randi_range(1, CHUNK - 2),
			c.y * CHUNK + rng.randi_range(1, CHUNK - 2))
		if _cell_kind(cell) == AIR and _cell_kind(cell + Vector2i(0, 1)) != AIR \
				and _cell_kind(cell + Vector2i(0, -1)) == AIR:
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
	e.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, -22)
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
	var b := _biome_of(int(_player.global_position.y / TILE))
	if _bg != null:
		_bg.color = _bg.color.lerp(_biome_backdrop(b), clampf(delta * 1.5, 0.0, 1.0))
	if _cm != null:
		_cm.color = _cm.color.lerp(_biome_ambient(b), clampf(delta * 1.2, 0.0, 1.0))
	# LAVA burns while you stand in it
	_lava_cd -= delta
	if _lava_cd <= 0.0:
		_lava_cd = 0.4
		for hz in get_tree().get_nodes_in_group("ug_hazard"):
			if is_instance_valid(hz) and bool(hz.get_meta("lava", false)) and bool(hz.get_meta("in", false)):
				if _player.has_method("take_damage"):
					_player.take_damage(7)
				break

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
func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"edits": e, "flags": fl}))

func _exit_tree() -> void:
	_save()

# ── the tileset (one natural-looking block per biome) ─────────────────────────
func _build_tileset() -> void:
	var n := BIOMES.size()
	var img := Image.create(n * 2 * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(n):
		var base: Color = BIOMES[c].base
		var gem: Color = ORE_GEM[c]
		for x in range(TILE):
			for y in range(TILE):
				var t := float(y) / float(TILE - 1)
				var col := base.lightened(0.10 * (1.0 - t)).darkened(0.16 * t)
				if y <= 1:
					col = base.lightened(0.20)                 # grassy top lip
				var h := ((x * 73856093) ^ (y * 19349663) ^ (c * 83492791)) & 0x7fffffff
				if h % 34 == 0:
					col = base.darkened(0.24)                  # a sparse crack
				elif h % 57 == 0:
					col = base.lightened(0.07)
				img.set_pixel(c * TILE + x, y, col)            # plain biome block
				# ORE variant: the same block, salted with bright gem clusters
				var oc := col
				var oh := ((x * 40503) ^ (y * 20441) ^ (c * 12553)) & 0x7fffffff
				if oh % 6 == 0:
					oc = gem
				elif oh % 13 == 0:
					oc = gem.darkened(0.35)
				img.set_pixel((ORE_COL + c) * TILE + x, y, oc)
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
	for c in range(int(img.get_width() / TILE)):
		var coord := Vector2i(c, 0)
		src.create_tile(coord)
		if collide:
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, sq)
	return ts

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
	add_child(_player)                       # its _ready auto-applies pending_player_state
	_player.global_position = _spawn_pos
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
