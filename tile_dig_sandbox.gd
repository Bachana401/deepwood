extends Node2D
# ── TERRARIA-STYLE MINING SANDBOX — now CHUNKED + PERSISTENT ──────────────────
# Proving the two load-bearing risks before we touch the real Underdark:
#   1. SCALE  — a Terraria-size world (4000x900 tiles) that only ever has the
#      chunks near the player loaded (generate/collide on approach, free on
#      leave), so per-tile collision stays cheap at any world size.
#   2. PERSISTENCE — the world is a PURE function of the seed, so we never save
#      it; we save only the DIFF (every cell the player dug) and re-apply it when
#      a chunk regenerates. Tunnels survive chunk unload/reload AND app restarts.
#
# Matched to Terraria / the real player: 16px tiles, 32x48 (2x3-tile) character,
# jump -400 / gravity 900 (~5.5-tile peak), speed 200.
# Controls: A/D or ←/→ move · Space jump · hold LMB mine · 1/2/3 pickaxe · F5 save.

const TILE := 16
const W := 4000                      # world width  in tiles (Terraria "large"-ish)
const H := 900                       # world depth  in tiles
const CHUNK := 32                    # tiles per chunk side
const LOAD_R := 3                    # chunks kept loaded around the player
const REACH := 5.0
const SWING := 0.16
const SAVE_PATH := "user://dig_sandbox_save.json"

const SPEED := 200.0                 # ── all four copied from player.gd ──
const JUMP := -400.0
const GRAVITY := 900.0

const AIR := -1
enum { DIRT, STONE, ORE, DEEP, OBSID }
const KIND_HARDNESS := {DIRT: 2, STONE: 4, ORE: 5, DEEP: 6, OBSID: 9}
const KIND_TIER := {DIRT: 0, STONE: 0, ORE: 0, DEEP: 1, OBSID: 2}
const KIND_NAME := {DIRT: "Dirt", STONE: "Stone", ORE: "Copper Ore",
	DEEP: "Deeprock", OBSID: "Obsidian Core"}
const PICKS := [
	{"name": "Copper Pickaxe", "tier": 0},
	{"name": "Iron Pickaxe", "tier": 1},
	{"name": "Mythril Pickaxe", "tier": 2},
]

var _map: TileMapLayer
var _body: CharacterBody2D
var _hills: FastNoiseLite
var _caves: FastNoiseLite
var _ore: FastNoiseLite
var _loaded := {}                    # Vector2i(chunk) -> true
var _edits := {}                     # Vector2i(cell)  -> kind (AIR = dug out)
var _hp := {}
var _swing_cd := 0.0
var _msg_cd := 0.0
var _mined := 0
var _pick := 0
var _cur_chunk := Vector2i(999999, 999999)
var _hud: Label

func _pick_tier() -> int:
	return int(PICKS[_pick].tier)

func _ready() -> void:
	_hills = FastNoiseLite.new(); _hills.seed = 0xD33B; _hills.frequency = 0.03
	_caves = FastNoiseLite.new(); _caves.seed = 0xCA7E; _caves.frequency = 0.075
	_ore = FastNoiseLite.new();   _ore.seed = 0xACE1;   _ore.frequency = 0.16
	_build_tileset_and_map()
	_load_save()
	var cx := int(W / 2)
	var spawn := Vector2(cx * TILE, _surface_y_px(cx) - 40.0)
	_stream_around(_chunk_of(spawn))          # load ground before the player exists
	_build_player(spawn)
	_build_hud()

# ── deterministic per-cell world (the "seed IS the world") ────────────────────
func _gen_kind(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return AIR
	var surface := 14 + int(_hills.get_noise_1d(float(x)) * 6.0)
	if y < surface:
		return AIR
	var depth := y - surface
	if depth > 4 and _caves.get_noise_2d(float(x), float(y)) > 0.28:
		return AIR
	var kind := DIRT
	if depth > 128:
		kind = OBSID
	elif depth > 62:
		kind = DEEP
	elif depth > 20:
		kind = STONE
	if kind == STONE and _ore.get_noise_2d(float(x), float(y)) > 0.60:
		kind = ORE
	return kind

func _cell_kind(cell: Vector2i) -> int:
	return int(_edits.get(cell, _gen_kind(cell.x, cell.y)))    # player edits win

func _surface_y_px(x_tile: int) -> float:
	return float(14 + int(_hills.get_noise_1d(float(x_tile)) * 6.0)) * TILE

# ── chunk streaming ───────────────────────────────────────────────────────────
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

func _unload_chunk(c: Vector2i) -> void:
	# free the collision; the cells regenerate identically (+ edits) on reload
	for ly in range(CHUNK):
		for lx in range(CHUNK):
			_map.erase_cell(Vector2i(c.x * CHUNK + lx, c.y * CHUNK + ly))
	_loaded.erase(c)

# ── persistence: save/load only the diff ──────────────────────────────────────
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

# ── tileset built in code (no art needed for the prototype) ───────────────────
func _build_tileset_and_map() -> void:
	var cols := {
		DIRT: Color(0.42, 0.30, 0.18), STONE: Color(0.40, 0.41, 0.45),
		ORE: Color(0.46, 0.44, 0.30), DEEP: Color(0.24, 0.27, 0.34),
		OBSID: Color(0.14, 0.10, 0.20)}
	var order := [DIRT, STONE, ORE, DEEP, OBSID]
	var img := Image.create(order.size() * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(order.size()):
		var kind: int = order[c]
		for x in range(TILE):
			for y in range(TILE):
				var col: Color = cols[kind]
				if x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1:
					col = col.darkened(0.35)
				elif (x * 7 + y * 13 + c * 5) % 11 == 0:
					col = col.lightened(0.10)
				if kind == ORE and (x * 3 + y * 5) % 9 == 0 and x > 1 and y > 1 and x < 14 and y < 14:
					col = Color(0.95, 0.78, 0.28)
				if kind == OBSID and (x + y) % 8 == 0:
					col = col.lightened(0.30)
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
	ts.add_source(src, 0)                        # attach BEFORE per-tile collision
	var sq := PackedVector2Array([
		Vector2(-TILE / 2.0, -TILE / 2.0), Vector2(TILE / 2.0, -TILE / 2.0),
		Vector2(TILE / 2.0, TILE / 2.0), Vector2(-TILE / 2.0, TILE / 2.0)])
	for c in range(order.size()):
		var coord := Vector2i(c, 0)
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, sq)
	_map = TileMapLayer.new()
	_map.tile_set = ts
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_map)

func _build_player(spawn: Vector2) -> void:
	_body = CharacterBody2D.new()
	_body.collision_layer = 2
	_body.collision_mask = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 48)
	cs.shape = rect
	_body.add_child(cs)
	var vis := ColorRect.new()
	vis.offset_left = -16; vis.offset_top = -24; vis.offset_right = 16; vis.offset_bottom = 24
	vis.color = Color(0.24, 0.03, 0.88)
	_body.add_child(vis)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.position_smoothing_enabled = true
	_body.add_child(cam)
	add_child(_body)
	_body.global_position = spawn
	cam.make_current()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_1: _pick = 0
		elif e.keycode == KEY_2: _pick = 1
		elif e.keycode == KEY_3: _pick = 2
		elif e.keycode == KEY_F5: _save()

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_body.velocity.y += GRAVITY * delta
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0 and InputMap.has_action("move_right"):
		dir = Input.get_axis("move_left", "move_right")
	_body.velocity.x = dir * SPEED
	if Input.is_action_just_pressed("ui_accept") and _body.is_on_floor():
		_body.velocity.y = JUMP
	_body.move_and_slide()
	# stream chunks when the player crosses into a new chunk
	var pc := _chunk_of(_body.global_position)
	if pc != _cur_chunk:
		_cur_chunk = pc
		_stream_around(pc)
	_swing_cd -= delta
	_msg_cd -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_mine()
	_refresh_hud()

func _try_mine() -> void:
	var cell := _map.local_to_map(_map.to_local(get_global_mouse_position()))
	if _map.get_cell_source_id(cell) == -1:
		return
	var center := _map.to_global(_map.map_to_local(cell))
	if _body.global_position.distance_to(center) > REACH * TILE:
		return
	var kind := _map.get_cell_atlas_coords(cell).x
	var need: int = KIND_TIER.get(kind, 0)
	if _pick_tier() < need:
		if _msg_cd <= 0.0:
			_msg_cd = 0.8
			_flash("%s is too hard — need %s" % [KIND_NAME[kind], _pick_named(need)])
			_spawn_debris(center, kind, true)
		return
	if _swing_cd > 0.0:
		return
	_swing_cd = SWING
	var left := int(_hp.get(cell, KIND_HARDNESS.get(kind, 3)))
	left -= 1
	_spawn_debris(center, kind, false)
	if left <= 0:
		_hp.erase(cell)
		_edits[cell] = AIR                 # record the diff -> persists
		_map.erase_cell(cell)
		_mined += 1
	else:
		_hp[cell] = left

func _pick_named(tier: int) -> String:
	for p in PICKS:
		if int(p.tier) == tier:
			return String(p.name)
	return "a stronger pickaxe"

func _spawn_debris(at: Vector2, kind: int, spark: bool) -> void:
	var base := {DIRT: Color(0.42,0.30,0.18), STONE: Color(0.40,0.41,0.45),
		ORE: Color(0.95,0.78,0.28), DEEP: Color(0.24,0.27,0.34), OBSID: Color(0.14,0.10,0.20)}
	for i in range(3):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1, 0.9, 0.5) if spark else base.get(kind, Color.WHITE)
		p.global_position = at
		add_child(p)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(p, "global_position", at + Vector2(randf_range(-18,18), randf_range(-22,-4)), 0.35)
		t.tween_property(p, "modulate:a", 0.0, 0.35)
		t.chain().tween_callback(p.queue_free)

func _flash(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 0.7, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.global_position = _body.global_position + Vector2(-40, -70)
	add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y - 26.0, 1.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(l.queue_free)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(_hud)

func _refresh_hud() -> void:
	if _hud == null or _body == null:
		return
	var depth_tiles: int = max(int(_body.global_position.y / TILE) - 14, 0)
	_hud.text = "TERRARIA-SIZE MINING SANDBOX (chunked · persistent)\nA/D or ←/→ move · Space jump · hold LMB mine · 1/2/3 pickaxe · F5 save\npickaxe: %s (tier %d)   depth: %d   mined: %d   chunks: %d   edits: %d" % [
		String(PICKS[_pick].name), _pick_tier(), depth_tiles, _mined, _loaded.size(), _edits.size()]
