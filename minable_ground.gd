extends Node2D
# TILE-DIG FEEL TEST (2026-07-25): a diggable tile patch dropped into the CAVE
# (Underdark) so the Miner's Pickaxe can carve terrain Terraria-style. Only the
# underground is minable -- never the village. This is a throwaway proving patch
# for the coming Underdark tile-mining rework: 16px tiles (matched to the 32x48
# player), tiered rock, and the pickaxe-power gate.
#
# It builds DOWNWARD from its origin (the cave floor): the top row is flush with
# the floor and walkable, so it never blocks the 1-D corridor -- you stand on it
# and dig DOWN into a pit. Remove once the real Underdark mining lands.

const TILE := 16
enum { DIRT, STONE, DEEP, OBSID }
const HARD := {DIRT: 2, STONE: 4, DEEP: 6, OBSID: 9}     # hits to break
const TIER := {DIRT: 0, STONE: 0, DEEP: 1, OBSID: 2}     # pickaxe grade required
const NAMES := {DIRT: "Dirt", STONE: "Stone", DEEP: "Deeprock", OBSID: "Obsidian"}

# set by the spawner before add_child if it wants a different size
var MW := 24            # patch width  in tiles
var MH := 14            # patch depth  in tiles

var _map: TileMapLayer
var _hp := {}
var _last_msg := 0.0

func _ready() -> void:
	add_to_group("minable_ground")
	_build_tileset()
	_fill_patch()
	_add_hint()

func _build_tileset() -> void:
	var cols := {DIRT: Color(0.42,0.30,0.18), STONE: Color(0.40,0.41,0.45),
		DEEP: Color(0.24,0.27,0.34), OBSID: Color(0.14,0.10,0.20)}
	var order := [DIRT, STONE, DEEP, OBSID]
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
	ts.add_source(src, 0)
	var sq := PackedVector2Array([
		Vector2(-TILE/2.0, -TILE/2.0), Vector2(TILE/2.0, -TILE/2.0),
		Vector2(TILE/2.0, TILE/2.0), Vector2(-TILE/2.0, TILE/2.0)])
	for c in range(order.size()):
		var coord := Vector2i(c, 0)
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, sq)
	_map = TileMapLayer.new()
	_map.tile_set = ts
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.z_index = 5          # over the drawn cave floor
	add_child(_map)

func _fill_patch() -> void:
	# rows go DOWN from y=0 (the floor, walkable) to y=MH-1 (deep). Each layer is a
	# harder terrain, so digging straight down walks you through the pickaxe gate.
	for tx in range(-MW / 2, MW / 2):
		for ty in range(0, MH):
			var kind := DIRT
			if ty >= 11:
				kind = OBSID
			elif ty >= 7:
				kind = DEEP
			elif ty >= 3:
				kind = STONE
			if kind == OBSID and (tx < -3 or tx > 2):   # obsidian only as a core
				kind = DEEP
			_map.set_cell(Vector2i(tx, ty), 0, Vector2i(kind, 0))

func _add_hint() -> void:
	var l := Label.new()
	l.text = "⛏ DIG HERE — swing the Miner's Pickaxe downward"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	l.position = Vector2(-MW * TILE / 2.0, -46.0)
	add_child(l)

# Called by the player's pickaxe swing. Carves the nearest solid tile within reach
# in the aim direction (forgiving -- you don't have to pixel-aim a single tile),
# gated by the pickaxe's grade.
func mine_toward(from: Vector2, aim: Vector2, reach_px: float, pick_tier: int, player: Node) -> bool:
	if _map == null:
		return false
	var dir := aim.normalized() if aim.length() > 0.01 else Vector2.DOWN
	var best := Vector2i(0, 0)
	var have := false
	var best_score := 1.0e9
	for cell in _map.get_used_cells():
		var c := _map.to_global(_map.map_to_local(cell))
		var d := from.distance_to(c)
		if d > reach_px:
			continue
		var toward := (c - from)
		if toward.length() > 0.01 and dir.dot(toward.normalized()) < -0.25:
			continue                              # ignore tiles clearly behind you
		var score := d - dir.dot(toward.normalized()) * 10.0   # bias toward the aim
		if score < best_score:
			best_score = score
			best = cell
			have = true
	if not have:
		return false
	var kind := _map.get_cell_atlas_coords(best).x
	var center := _map.to_global(_map.map_to_local(best))
	if pick_tier < int(TIER.get(kind, 0)):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_msg > 1.2:
			_last_msg = now
			GameState.notify("%s is too hard for the Miner's Pickaxe — you'll need a stronger one." % NAMES[kind])
		_chips(center, true)
		return false
	var left := int(_hp.get(best, int(HARD.get(kind, 3))))
	left -= 1
	_chips(center, false)
	if left <= 0:
		_hp.erase(best)
		_map.erase_cell(best)
		if player != null and "inventory" in player and player.inventory != null:
			player.inventory.add_item("stone", 1)
	else:
		_hp[best] = left
	return true

func _chips(at: Vector2, spark: bool) -> void:
	for i in range(3):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1, 0.9, 0.5) if spark else Color(0.6, 0.55, 0.45)
		p.global_position = at
		p.z_index = 21
		add_child(p)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(p, "global_position", at + Vector2(randf_range(-16,16), randf_range(-20,-4)), 0.3)
		t.tween_property(p, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(p.queue_free)
