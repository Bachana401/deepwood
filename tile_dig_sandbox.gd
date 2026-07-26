extends Node2D
# ── PHASE-1 TERRARIA-STYLE MINING SANDBOX (throwaway prototype) ───────────────
# Proves the tile foundation before we rework the real Underdark. Matched to
# Terraria / the real player:
#   • 16px tiles                     (Terraria block size)
#   • 32x48 character = 2x3 tiles    (Terraria player size, == player.tscn)
#   • jump -400 / gravity 900        (peaks ~5.5 tiles, == player.gd, Terraria base)
#   • speed 200                      (== player.gd)
#
# TIERED TERRAIN (Terraria pickaxe-power gate): the deeper biomes are HARDER rock
# that a weak pickaxe simply can't cut -- you must earn a better pickaxe to dig
# on. Swap pickaxe with 1/2/3 to feel the gate.
#
# Controls: A/D or ←/→ move · Space jump · hold LMB mine · 1/2/3 swap pickaxe.

const TILE := 16
const W := 240                       # world width  in tiles  (3840 px)
const H := 340                       # world depth  in tiles  (5440 px)
const REACH := 5.0                   # pickaxe range in tiles (Terraria-ish)
const SWING := 0.16                  # seconds between mining hits

const SPEED := 200.0                 # ── all four copied from player.gd ──
const JUMP := -400.0
const GRAVITY := 900.0

const AIR := -1
enum { DIRT, STONE, ORE, DEEP, OBSID }     # also the atlas column of each
const KIND_HARDNESS := {DIRT: 2, STONE: 4, ORE: 5, DEEP: 6, OBSID: 9}   # hits
const KIND_TIER := {DIRT: 0, STONE: 0, ORE: 0, DEEP: 1, OBSID: 2}       # pick needed
const KIND_NAME := {DIRT: "Dirt", STONE: "Stone", ORE: "Copper Ore",
	DEEP: "Deeprock", OBSID: "Obsidian Core"}

# pickaxes, weakest -> strongest. tier N mines any tile whose KIND_TIER <= N.
const PICKS := [
	{"name": "Copper Pickaxe", "tier": 0},
	{"name": "Iron Pickaxe", "tier": 1},
	{"name": "Mythril Pickaxe", "tier": 2},
]

var _map: TileMapLayer
var _body: CharacterBody2D
var _hp := {}                        # Vector2i -> remaining hits on that cell
var _swing_cd := 0.0
var _msg_cd := 0.0
var _mined := 0
var _pick := 0                       # index into PICKS
var _hud: Label

func _pick_tier() -> int:
	return int(PICKS[_pick].tier)

func _ready() -> void:
	_build_tileset_and_map()
	_generate_world()
	_build_player()
	_build_hud()

# ── tileset built entirely in code (no art needed for the prototype) ──────────
func _build_tileset_and_map() -> void:
	var cols := {
		DIRT: Color(0.42, 0.30, 0.18),      # brown
		STONE: Color(0.40, 0.41, 0.45),     # grey
		ORE: Color(0.46, 0.44, 0.30),       # base (gold specks added below)
		DEEP: Color(0.24, 0.27, 0.34),      # cold slate (tier 1)
		OBSID: Color(0.14, 0.10, 0.20),     # black-purple glassy (tier 2)
	}
	var order := [DIRT, STONE, ORE, DEEP, OBSID]
	var img := Image.create(order.size() * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in range(order.size()):
		var kind: int = order[c]
		for x in range(TILE):
			for y in range(TILE):
				var col: Color = cols[kind]
				if x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1:
					col = col.darkened(0.35)                 # block edge
				elif (x * 7 + y * 13 + c * 5) % 11 == 0:
					col = col.lightened(0.10)                # grain
				if kind == ORE and (x * 3 + y * 5) % 9 == 0 and x > 1 and y > 1 and x < 14 and y < 14:
					col = Color(0.95, 0.78, 0.28)            # gold specks
				if kind == OBSID and (x + y) % 8 == 0:
					col = col.lightened(0.30)                # glassy sheen
				img.set_pixel(c * TILE + x, y, col)
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # tiles live on world layer 1
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)          # attach FIRST so per-tile collision sees the physics layer
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

func _put(cell: Vector2i, kind: int) -> void:
	if kind == AIR:
		_map.erase_cell(cell)
	else:
		_map.set_cell(cell, 0, Vector2i(kind, 0))

# ── procedural cave world: rolling surface, depth biomes, noise caves + ore ───
func _generate_world() -> void:
	var hills := FastNoiseLite.new()
	hills.seed = 0xD33B
	hills.frequency = 0.03
	var caves := FastNoiseLite.new()
	caves.seed = 0xCA7E
	caves.frequency = 0.075
	var ore := FastNoiseLite.new()
	ore.seed = 0xACE1
	ore.frequency = 0.16

	for x in range(W):
		var surface := 14 + int(hills.get_noise_1d(float(x)) * 6.0)
		for y in range(surface, H):
			var depth := y - surface
			if depth > 4 and caves.get_noise_2d(float(x), float(y)) > 0.28:
				continue                                    # carve AIR cave
			# depth biome — each deeper band is a harder terrain (pickaxe gate)
			var kind := DIRT
			if depth > 128:
				kind = OBSID                                # tier 2
			elif depth > 62:
				kind = DEEP                                 # tier 1
			elif depth > 20:
				kind = STONE                                # tier 0
			# copper ore veins salted through the tier-0 stone band
			if kind == STONE and ore.get_noise_2d(float(x), float(y)) > 0.60:
				kind = ORE
			_put(Vector2i(x, y), kind)

func _surface_y_px(x_tile: int) -> float:
	var hills := FastNoiseLite.new()
	hills.seed = 0xD33B
	hills.frequency = 0.03
	return float(14 + int(hills.get_noise_1d(float(x_tile)) * 6.0)) * TILE

# ── a minimal 2x3-tile character driven by the sandbox root ───────────────────
func _build_player() -> void:
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
	vis.color = Color(0.24, 0.03, 0.88)          # same violet as player.tscn
	_body.add_child(vis)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.position_smoothing_enabled = true
	_body.add_child(cam)
	add_child(_body)                      # in the tree before make_current (no warning)
	var cx := int(W / 2)
	_body.global_position = Vector2(cx * TILE, _surface_y_px(cx) - 40.0)
	cam.make_current()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_1: _pick = 0
		elif e.keycode == KEY_2: _pick = 1
		elif e.keycode == KEY_3: _pick = 2

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
	# ── the pickaxe-power gate ──
	var need: int = KIND_TIER.get(kind, 0)
	if _pick_tier() < need:
		if _msg_cd <= 0.0:
			_msg_cd = 0.8
			_flash("%s is too hard — need %s" % [KIND_NAME[kind], _pick_named(need)])
			_spawn_debris(center, kind, true)        # sparks, no progress
		return
	if _swing_cd > 0.0:
		return
	_swing_cd = SWING
	var left := int(_hp.get(cell, KIND_HARDNESS.get(kind, 3)))
	left -= 1
	_spawn_debris(center, kind, false)
	if left <= 0:
		_hp.erase(cell)
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
		ORE: Color(0.95,0.78,0.28), DEEP: Color(0.24,0.27,0.34),
		OBSID: Color(0.14,0.10,0.20)}
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

# ── HUD ──────────────────────────────────────────────────────────────────────
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
	_hud.text = "TERRARIA-SIZE MINING SANDBOX\nA/D or ←/→ move · Space jump · hold LMB mine · 1/2/3 pickaxe\npickaxe: %s (tier %d)   depth: %d   mined: %d" % [
		String(PICKS[_pick].name), _pick_tier(), depth_tiles, _mined]
