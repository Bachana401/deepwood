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

const TILE := 16
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

# ── content (streamed per chunk, like the terrain) ────────────────────────────
const ENEMY_SCENE := preload("res://enemy.tscn")
const TRAP_SCENE := preload("res://trap.tscn")
# chest loot by biome depth -- all ids the harvest/gather system already drops
const LOOT := [
	["wood", "stone", "stone", "resin"],
	["stone", "stone", "iron_shard", "iron_shard"],
	["iron_shard", "iron_shard", "ember_crystal", "stone"],
	["ember_crystal", "ember_crystal", "iron_shard", "relic_mountain"],
	["ember_crystal", "relic_mountain", "ember_crystal", "iron_shard"],
]

var _map: TileMapLayer
var _player: Node = null
var _worm1: FastNoiseLite               # fine worm tunnels
var _worm2: FastNoiseLite               # broader cross tunnels
var _cav: FastNoiseLite                 # big caverns
var _ore: FastNoiseLite                 # richer pockets
var _loaded := {}                      # Vector2i(chunk) -> true
var _edits := {}                       # Vector2i(cell) -> kind (AIR = dug)
var _hp := {}
var _cur_chunk := Vector2i(999999, 999999)
var _entry := Vector2.ZERO
var _spawn_pos := Vector2.ZERO
var _content := {}                     # Vector2i(chunk) -> [spawned content nodes]

func _ready() -> void:
	add_to_group("tile_world")
	GameState.in_dungeon = true          # so village-only ticks stay quiet
	_worm1 = FastNoiseLite.new(); _worm1.seed = 0xCA7E; _worm1.frequency = 0.050
	_worm2 = FastNoiseLite.new(); _worm2.seed = 0x51DE; _worm2.frequency = 0.031
	_cav = FastNoiseLite.new();   _cav.seed = 0x0F0F;   _cav.frequency = 0.013
	_ore = FastNoiseLite.new();   _ore.seed = 0xACE1;   _ore.frequency = 0.09
	_build_backdrop()        # a dark cave behind the tiles (so air isn't flat grey)
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
	_stream_around(_chunk_of(_spawn_pos))
	_spawn_player()
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
	# ENTRY LEDGE: a small solid shelf at the top of the true path (checked BEFORE
	# any carve) so the player lands instead of dropping down the shaft on spawn.
	if y >= ENTRY_ROW and y <= ENTRY_ROW + 1 and absf(float(x) - _truepath_x(ENTRY_ROW)) < 7.0:
		return _biome_of(y)
	if y < 1:
		return AIR                                    # open ceiling above the ledge
	# THE TRUE PATH: a walkable carved corridor around the switchback line, open the
	# whole way down so you can always descend (and mine sideways off it).
	if absf(float(x) - _truepath_x(y)) < 3.6:
		return AIR
	# 2-D CAVE NETWORK: two worm systems (thin |noise|) crossing in all directions,
	# plus big caverns (low-freq blobs). Dense + interconnected, like Terraria.
	if absf(_worm1.get_noise_2d(float(x), float(y))) < 0.052:
		return AIR
	if absf(_worm2.get_noise_2d(float(x), float(y))) < 0.040:
		return AIR
	if _cav.get_noise_2d(float(x), float(y)) > 0.56:
		return AIR
	return _biome_of(y)

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
	var drop := []
	for c in _loaded.keys():
		if not want.has(c):
			drop.append(c)
	for c in drop:
		_unload_chunk(c)

func _load_chunk(c: Vector2i) -> void:
	_loaded[c] = true
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			var cell := Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly)
			var kind := _cell_kind(cell)
			if kind != AIR:
				_map.set_cell(cell, 0, Vector2i(kind, 0))
	_populate_chunk(c)

func _unload_chunk(c: Vector2i) -> void:
	_depopulate_chunk(c)
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			_map.erase_cell(Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly))
	_loaded.erase(c)

# ── streamed content: chests (loot), depth-scaled mobs, traps ─────────────────
func _populate_chunk(c: Vector2i) -> void:
	if c.y < 1:
		return                                    # keep the entry a safe landing
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
	var mob_count := 1 + int(biome / 2)            # deeper -> more, tougher mobs
	for i in range(mob_count):
		if rng.randf() < 0.6:
			var mc = _find_floor_cell(c, rng)
			if mc != null and _player != null \
					and _map.to_global(_map.map_to_local(mc)).distance_to(_player.global_position) > 460.0:
				nodes.append(_spawn_mob(mc, biome, rng))
	# FLOOR-DOORS on the true path: one per dungeon level by depth (deeper = higher
	# floor). The frontier door -- the deepest you can currently enter -- wears a
	# beacon, so the way down is always clear. Leaving a floor returns you here.
	var level_h := float(DEPTH) / 100.0
	var l_lo := maxi(1, int(ceil(float(c.y * CHUNK) / level_h)))
	var l_hi := mini(100, int(float(c.y * CHUNK + CHUNK - 1) / level_h))
	for L in range(l_lo, l_hi + 1):
		var dy := int(float(L) * level_h)
		var dx := int(_truepath_x(dy))
		if dx >= c.x * CHUNK and dx < (c.x + 1) * CHUNK:
			var dcell := _floor_near(dx, dy)
			if dcell.x > -9000:
				nodes.append(_spawn_floor_door(dcell, L))
	if not nodes.is_empty():
		_content[c] = nodes

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

func _spawn_chest(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Node:
	var id := "ug_c_%d_%d" % [cell.x, cell.y]
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
		chest.set_meta("loot", loot)
	add_child(chest)
	return chest

func _spawn_trap(cell: Vector2i) -> Node:
	var t = TRAP_SCENE.instantiate()
	add_child(t)
	t.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, 4)
	return t

func _spawn_mob(cell: Vector2i, biome: int, rng: RandomNumberGenerator) -> Node:
	var e = ENEMY_SCENE.instantiate()
	if "respawns" in e: e.respawns = false
	if "is_wild" in e: e.is_wild = true
	var wx: float = _map.to_global(_map.map_to_local(cell)).x
	if "wild_home_x" in e: e.wild_home_x = wx
	var depth := float(biome) / float(BIOMES.size() - 1)
	if "wave_hp_multiplier" in e: e.wave_hp_multiplier = lerpf(1.2, 5.0, depth) * rng.randf_range(0.9, 1.15)
	if "wave_damage_multiplier" in e: e.wave_damage_multiplier = lerpf(1.1, 3.4, depth) * rng.randf_range(0.9, 1.1)
	if "wave_speed_multiplier" in e: e.wave_speed_multiplier = lerpf(1.0, 1.35, depth)
	if e.has_method("apply_block_archetype"): e.apply_block_archetype(mini(int(depth * 9.0), 8))
	e.add_to_group("course_enemy")
	add_child(e)
	e.global_position = _map.to_global(_map.map_to_local(cell)) + Vector2(0, -22)
	if "detection_range_current" in e and "DETECTION_RANGE" in e:
		var sight: float = e.WILD_SIGHT_MULT if "WILD_SIGHT_MULT" in e else 1.0
		e.detection_range_current = e.DETECTION_RANGE * sight
	return e

func _try_loot_chest() -> bool:
	if _player == null:
		return false
	for ch in get_tree().get_nodes_in_group("ug_chest"):
		if not is_instance_valid(ch) or bool(ch.get_meta("opened", false)):
			continue
		if _player.global_position.distance_to(ch.global_position) > 62.0:
			continue
		var loot: Array = ch.get_meta("loot", [])
		var got := {}
		for id in loot:
			if "inventory" in _player and _player.inventory != null:
				_player.inventory.add_item(String(id), 1)
			got[String(id)] = int(got.get(String(id), 0)) + 1
		ch.set_meta("opened", true)
		GameState.chest_contents[String(ch.get_meta("chest_id"))] = {}   # persist: emptied
		for c in ch.get_children():
			if c is Polygon2D:
				c.color = c.color.darkened(0.5)
		var parts := []
		for id in got:
			parts.append("%s ×%d" % [Inventory.get_display_name(id), got[id]])
		GameState.notify("⛏ Chest looted: " + ", ".join(parts))
		return true
	return false

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pc := _chunk_of(_player.global_position)
	if pc != _cur_chunk:
		_cur_chunk = pc
		_stream_around(pc)
	if _bg != null:
		var b := _biome_of(int(_player.global_position.y / TILE))
		_bg.color = _bg.color.lerp(_biome_backdrop(b), clampf(delta * 1.5, 0.0, 1.0))

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
		var best := Vector2i.ZERO
		var have := false
		var best_score := 1.0e9
		for used in _map.get_used_cells():
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
	var biome: Dictionary = BIOMES[clampi(kind, 0, BIOMES.size() - 1)]
	var center := _map.to_global(_map.map_to_local(cell))
	if pick_tier < int(biome.tier):
		GameState.notify("%s is too hard for your pickaxe — you'll need a stronger one." % biome.name)
		_chips(center, biome.accent, true)
		return false
	var left := int(_hp.get(cell, int(biome.hard)))
	left -= 1
	_chips(center, biome.base, false)
	if left <= 0:
		_hp.erase(cell)
		_edits[cell] = AIR
		_map.erase_cell(cell)
		if player != null and "inventory" in player and player.inventory != null:
			player.inventory.add_item("stone", 1)
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
	if typeof(data) == TYPE_DICTIONARY:
		for k in data.keys():
			var parts: PackedStringArray = String(k).split(",")
			if parts.size() == 2:
				_edits[Vector2i(int(parts[0]), int(parts[1]))] = int(data[k])

func _save() -> void:
	var out := {}
	for cell in _edits.keys():
		out["%d,%d" % [cell.x, cell.y]] = _edits[cell]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out))

func _exit_tree() -> void:
	_save()

# ── the tileset (one natural-looking block per biome) ─────────────────────────
func _build_tileset() -> void:
	var img := Image.create(BIOMES.size() * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(BIOMES.size()):
		var base: Color = BIOMES[c].base
		var accent: Color = BIOMES[c].accent
		for x in range(TILE):
			for y in range(TILE):
				var col := base
				# a soft top-edge shade so blocks read as blocks without a harsh grid
				if y == 0:
					col = base.lightened(0.12)
				elif y == TILE - 1 or x == 0 or x == TILE - 1:
					col = base.darkened(0.22)
				# natural grain: a few flecks + veins in the biome accent
				var h := (x * 928371 + y * 1237 + c * 99991)
				if h % 17 == 0:
					col = base.lightened(0.10)
				elif h % 23 == 0:
					col = base.darkened(0.12)
				if h % 41 == 0:
					col = accent.lerp(base, 0.45)     # subtle mineral fleck
				img.set_pixel(c * TILE + x, y, col)
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var sq := PackedVector2Array([
		Vector2(-TILE/2.0, -TILE/2.0), Vector2(TILE/2.0, -TILE/2.0),
		Vector2(TILE/2.0, TILE/2.0), Vector2(-TILE/2.0, TILE/2.0)])
	for c in range(BIOMES.size()):
		var coord := Vector2i(c, 0)
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, sq)
	_map = TileMapLayer.new()
	_map.tile_set = ts
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_map)

func _ensure_dark() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.72, 0.70, 0.74)     # a dim underworld, not pitch black
	add_child(cm)

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
		cam.zoom = Vector2(1.2, 1.2)         # tighter Terraria-style view underground
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

func _build_hud_extras() -> void:
	add_child(preload("res://hotbar_ui.gd").new())
	add_child(preload("res://admin_panel.gd").new())

func start_music() -> void:
	pass
