class_name BuildingLights
extends Node2D

# Breathes life into the painted facades WITHOUT touching the approved art:
# scans the facade for its warm lit pixels (candlelit windows, lanterns, the
# forge fire), clusters them into little regions, and overlays each region
# with an ADDITIVE copy of the art's own pixels whose brightness flickers on
# its own rhythm -- living candle-light. Gentle by day, strong at night
# (follows GameState.torches_lit()). Works for every facade automatically.

const CELL := 6            # clustering grid (content-space px)
const MAX_GLOWS := 14      # node budget per building
const MIN_PIXELS := 10     # ignore stray warm speckles

var _glows: Array = []     # [{n: Sprite2D, phase: float, speed: float}]
var _t := 0.0

# tex/content: the facade texture + its content box. spr_pos/spr_scale: how the
# base facade sprite maps content-space onto the building (we mirror it exactly
# so every overlay sits pixel-perfect on its window).
func build(tex: Texture2D, content: Rect2, spr_pos: Vector2, spr_scale: Vector2) -> void:
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	# 1) warm-pixel mask on a coarse grid: cell -> warm pixel count
	var cells := {}
	var x0 := int(content.position.x)
	var y0 := int(content.position.y)
	for y in range(int(content.size.y)):
		for x in range(int(content.size.x)):
			var c := img.get_pixel(x0 + x, y0 + y)
			if c.a > 0.5 and c.r > 0.55 and c.r > c.b * 1.35 and c.g > c.b:
				var key := Vector2i(x / CELL, y / CELL)
				cells[key] = cells.get(key, 0) + 1
	# 2) flood-merge adjacent cells into cluster rects
	var seen := {}
	var clusters: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var q: Array = [start]
		var mn: Vector2i = start
		var mx: Vector2i = start
		var count := 0
		while not q.is_empty():
			var p: Vector2i = q.pop_back()
			if seen.has(p) or not cells.has(p):
				continue
			seen[p] = true
			count += cells[p]
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
					Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				q.append(p + d)
		if count >= MIN_PIXELS:
			clusters.append({"mn": mn, "mx": mx, "count": count})
	# biggest light sources first, respect the node budget
	clusters.sort_custom(func(a, b): return a["count"] > b["count"])
	# 3) one additive region-sprite per cluster, mapped exactly like the facade
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(mini(clusters.size(), MAX_GLOWS)):
		var cl: Dictionary = clusters[i]
		var px0: float = maxf(cl["mn"].x * CELL - 1, 0.0)
		var py0: float = maxf(cl["mn"].y * CELL - 1, 0.0)
		var px1: float = minf((cl["mx"].x + 1) * CELL + 1, content.size.x)
		var py1: float = minf((cl["mx"].y + 1) * CELL + 1, content.size.y)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.region_enabled = true
		spr.region_rect = Rect2(content.position + Vector2(px0, py0), Vector2(px1 - px0, py1 - py0))
		spr.scale = spr_scale
		spr.position = spr_pos + Vector2(px0 * spr_scale.x, py0 * spr_scale.y)
		spr.material = add_mat
		spr.modulate = Color(1, 0.9, 0.6, 0.0)   # warm additive tint, driven below
		add_child(spr)
		_glows.append({"n": spr, "phase": randf() * TAU, "speed": randf_range(4.0, 9.0)})

func _process(delta: float) -> void:
	if _glows.is_empty():
		return
	_t += delta
	# candles barely simmer by day, dance at night
	var night: bool = GameState.torches_lit()
	var base := 0.30 if night else 0.06
	var amp := 0.28 if night else 0.08
	for g in _glows:
		var flick: float = 0.5 + 0.5 * sin(_t * g["speed"] + g["phase"])
		flick = flick * 0.7 + 0.3 * (0.5 + 0.5 * sin(_t * g["speed"] * 2.7 + g["phase"] * 1.7))
		g["n"].modulate.a = base + amp * flick
