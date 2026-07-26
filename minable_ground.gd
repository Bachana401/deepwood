extends Node2D
# TILE-DIG FEEL TEST (2026-07-25): a small mound of diggable tile-terrain dropped
# into the real village so the Miner's Pickaxe can carve it Terraria-style. This
# is a throwaway proving patch for the coming Underdark tile-mining rework -- 16px
# tiles (matched to the 32x48 player), tiered rock, and the pickaxe-power gate.
# Spawned by main.gd; remove once the real Underdark mining lands.

const TILE := 16
enum { DIRT, STONE, DEEP, OBSID }
const HARD := {DIRT: 2, STONE: 4, DEEP: 6, OBSID: 9}     # hits to break
const TIER := {DIRT: 0, STONE: 0, DEEP: 1, OBSID: 2}     # pickaxe grade required
const NAMES := {DIRT: "Dirt", STONE: "Stone", DEEP: "Deeprock", OBSID: "Obsidian"}

const MW := 22          # mound width in tiles
const MH := 16          # mound height in tiles

var _map: TileMapLayer
var _hp := {}
var _last_msg := 0.0

func _ready() -> void:
	add_to_group("minable_ground")
	_build_tileset()
	_fill_mound()

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
	add_child(_map)

func _fill_mound() -> void:
	# a block sitting ON the ground (origin = ground point): rows go UP from y=-1
	# (near the ground) to y=-MH (the grassy top). Dirt on top, obsidian core at base.
	for tx in range(-MW / 2, MW / 2):
		for ty in range(1, MH + 1):
			var depth_from_top := MH - ty            # 0 at the top row
			var kind := DIRT
			if depth_from_top >= 12:
				kind = OBSID
			elif depth_from_top >= 8:
				kind = DEEP
			elif depth_from_top >= 3:
				kind = STONE
			# obsidian only as a small central core, so most of the base is deeprock
			if kind == OBSID and (tx < -3 or tx > 2):
				kind = DEEP
			_map.set_cell(Vector2i(tx, -ty), 0, Vector2i(kind, 0))

# Called by the player's pickaxe swing. Carves the solid tile nearest along the
# aim within reach, gated by the pickaxe's grade.
func mine_toward(from: Vector2, aim: Vector2, reach_px: float, pick_tier: int, player: Node) -> bool:
	if _map == null:
		return false
	var dir := aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	var best_cell := Vector2i(0, 0)
	var have := false
	var best_d := 1.0e9
	for step in range(1, 9):
		var wp := from + dir * (float(step) * TILE * 0.7)
		var cell := _map.local_to_map(_map.to_local(wp))
		if _map.get_cell_source_id(cell) != -1:
			var c := _map.to_global(_map.map_to_local(cell))
			var d := from.distance_to(c)
			if d <= reach_px and d < best_d:
				best_d = d
				best_cell = cell
				have = true
	if not have:
		return false
	var kind := _map.get_cell_atlas_coords(best_cell).x
	var center := _map.to_global(_map.map_to_local(best_cell))
	if pick_tier < int(TIER.get(kind, 0)):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_msg > 1.2:
			_last_msg = now
			GameState.notify("%s is too hard for the Miner's Pickaxe — you'll need a stronger one." % NAMES[kind])
		_chips(center, true)
		return false
	var left := int(_hp.get(best_cell, int(HARD.get(kind, 3))))
	left -= 1
	_chips(center, false)
	if left <= 0:
		_hp.erase(best_cell)
		_map.erase_cell(best_cell)
		if player != null and "inventory" in player and player.inventory != null:
			player.inventory.add_item("stone", 1)
	else:
		_hp[best_cell] = left
	return true

func _chips(at: Vector2, spark: bool) -> void:
	for i in range(3):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1, 0.9, 0.5) if spark else Color(0.6, 0.55, 0.45)
		p.global_position = at
		add_child(p)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(p, "global_position", at + Vector2(randf_range(-16,16), randf_range(-20,-4)), 0.3)
		t.tween_property(p, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(p.queue_free)
