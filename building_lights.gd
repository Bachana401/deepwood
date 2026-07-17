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
# Only real hearth-buildings smoke; a smoking Bank pediment looks absurd.
const SMOKE_BUILDINGS := ["Tavern", "Bar", "Blacksmith", "Barracks"]
var _bname := ""

# Where a facade paints OPEN FIRE, in art-content px {x, y, w, h}. A real
# animated flame (art/effects/flame_N.png) burns in each spot, ADDITIVELY, so
# the painted fire underneath becomes the glow-bed the flame dances in and the
# flame's own dark outline contributes nothing.
#
# Hand-pinned, not auto-detected: fire and candle-lit windows are both warm, and
# every threshold loose enough to catch the forge also lit up half the Tavern's
# windows. tool_fire_scan.gd finds the candidates, a human picks the real fires.
# (The Blacksmith is the only building with open fire -- everything else warm is
# a window or a lantern, which the flicker pass below already handles.)
const FIRE_SPOTS := {
	"Blacksmith": [
		{"x": 60, "y": 136, "w": 40, "h": 56},    # the archway forge
		{"x": 152, "y": 136, "w": 28, "h": 28},   # fire through the shop window
		{"x": 220, "y": 136, "w": 28, "h": 28},   # the brazier by the anvil
	],
}
var _fires: Array = []

# Painted SIGNS that should read as lit-up, in art-content px. A sign is not a
# candle: it glows steadily with a slow breath and throws a halo, rather than
# guttering like the window flicker below. Measured off the art with
# tool_crop.gd (which draws a content-space grid over a facade).
const SIGN_SPOTS := {
	"Bar": {"x": 76, "y": 56, "w": 20, "h": 23},   # the big beer mug over the door
}
var _signs: Array = []

func build(tex: Texture2D, content: Rect2, spr_pos: Vector2, spr_scale: Vector2, bname: String = "") -> void:
	_bname = bname
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
	add_fires(content, spr_pos, spr_scale)
	add_sign(tex, content, spr_pos, spr_scale)
	add_smoke(img, content, spr_pos, spr_scale)

# The Bar's beer mug lights up like a real tavern sign: its own painted pixels
# burn brighter (additively) inside a soft amber halo, so after dark you can
# read the sign from down the street.
func add_sign(tex: Texture2D, content: Rect2, spr_pos: Vector2, spr_scale: Vector2) -> void:
	if not SIGN_SPOTS.has(_bname):
		return
	var spot: Dictionary = SIGN_SPOTS[_bname]
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var org := spr_pos + Vector2(float(spot.x) * spr_scale.x, float(spot.y) * spr_scale.y)
	var size := Vector2(float(spot.w) * spr_scale.x, float(spot.h) * spr_scale.y)
	# 1) the halo, behind the sign
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.78, 0.32, 0.5))
	grad.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var halo := Sprite2D.new()
	halo.texture = gt
	halo.centered = true
	halo.material = add_mat
	halo.position = org + size / 2.0
	var hs: float = maxf(size.x, size.y) * 2.6 / 64.0
	halo.scale = Vector2(hs, hs)
	add_child(halo)
	# 2) the sign's own pixels, lit
	var lit := Sprite2D.new()
	lit.texture = tex
	lit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lit.centered = false
	lit.region_enabled = true
	lit.region_rect = Rect2(content.position + Vector2(float(spot.x), float(spot.y)),
		Vector2(float(spot.w), float(spot.h)))
	lit.scale = spr_scale
	lit.position = org
	lit.material = add_mat
	add_child(lit)
	_signs.append({"halo": halo, "lit": lit, "phase": randf() * TAU})

# A real burning flame in every painted fire (see FIRE_SPOTS). Each spot gets
# its own start frame and speed, so three fires on one building never flicker
# in lockstep.
func add_fires(content: Rect2, spr_pos: Vector2, spr_scale: Vector2) -> void:
	if not FIRE_SPOTS.has(_bname) or not ResourceLoader.exists("res://art/effects/flame_1.png"):
		return
	var frames := SpriteFrames.new()
	frames.add_animation("burn")
	frames.set_animation_loop("burn", true)
	var i := 1
	while ResourceLoader.exists("res://art/effects/flame_%d.png" % i):
		frames.add_frame("burn", load("res://art/effects/flame_%d.png" % i))
		i += 1
	if frames.get_frame_count("burn") == 0:
		return
	# the flame's own content box inside its 64x64 canvas
	var ftex: Texture2D = frames.get_frame_texture("burn", 0)
	var fimg := ftex.get_image()
	if fimg.is_compressed():
		fimg.decompress()
	var fc := Rect2(fimg.get_used_rect())
	if fc.size.x <= 0:
		return
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for spot in FIRE_SPOTS[_bname]:
		# spot rect in the building's local space
		var sx: float = spr_pos.x + float(spot.x) * spr_scale.x
		var sy: float = spr_pos.y + float(spot.y) * spr_scale.y
		var sw: float = float(spot.w) * spr_scale.x
		var sh: float = float(spot.h) * spr_scale.y
		# fit the flame into the spot without distorting it, standing on its base
		var s: float = minf(sw / fc.size.x, sh / fc.size.y)
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flame.centered = false
		flame.material = add_mat
		flame.scale = Vector2(s, s)
		# put the flame's content bottom-centre on the spot's bottom-centre
		var target := Vector2(sx + sw / 2.0, sy + sh)
		flame.position = target - Vector2(
			(fc.position.x + fc.size.x / 2.0) * s,
			(fc.position.y + fc.size.y) * s)
		flame.speed_scale = randf_range(0.85, 1.2)
		flame.frame = randi() % frames.get_frame_count("burn")
		flame.play("burn")
		add_child(flame)
		_fires.append(flame)

# Curling chimney smoke (art/effects/smoke_N.png loop) anchored on the
# facade's chimney: the tallest narrow content column at the very top of the
# art. Buildings without a chimney silhouette simply get no smoke.
func add_smoke(img: Image, content: Rect2, spr_pos: Vector2, spr_scale: Vector2) -> void:
	if not ResourceLoader.exists("res://art/effects/smoke_1.png"):
		return
	if not SMOKE_BUILDINGS.has(_bname):
		return
	var x0 := int(content.position.x)
	var y0 := int(content.position.y)
	var cw := int(content.size.x)
	# chimney candidates: opaque runs in the art's top band. Start shallow and
	# deepen only while nothing chimney-like is found -- low buildings' roof
	# ridges enter deep bands and swallow the chimney into one wide run, while
	# facades with painted smoke wisps need a deeper look to reach the stack.
	var valid: Array = []
	for band in [6, 12, mini(int(content.size.y * 0.15), 34)]:
		var runs: Array = []
		var run_start := -1
		for x in range(cw):
			var hit := false
			for y in range(band):
				if img.get_pixel(x0 + x, y0 + y).a > 0.5:
					hit = true
					break
			if hit and run_start < 0:
				run_start = x
			elif not hit and run_start >= 0:
				runs.append([run_start, x - 1])
				run_start = -1
		if run_start >= 0:
			runs.append([run_start, cw - 1])
		valid = runs.filter(func(r):
			var rw: int = r[1] - r[0] + 1
			return rw >= 4 and rw <= cw * 0.22)
		if not valid.is_empty():
			break
	# narrowest valid run = the most chimney-like; one plume per building
	valid.sort_custom(func(a, b): return (a[1] - a[0]) < (b[1] - b[0]))
	for r in valid.slice(0, 1):
		var frames := SpriteFrames.new()
		frames.add_animation("puff")
		frames.set_animation_loop("puff", true)
		frames.set_animation_speed("puff", 7.0)
		var i := 1
		while ResourceLoader.exists("res://art/effects/smoke_%d.png" % i):
			frames.add_frame("puff", load("res://art/effects/smoke_%d.png" % i))
			i += 1
		var smoke := AnimatedSprite2D.new()
		smoke.sprite_frames = frames
		smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cx: float = (r[0] + r[1]) / 2.0
		smoke.position = spr_pos + Vector2(cx * spr_scale.x, -6.0)
		smoke.scale = Vector2(0.55, 0.55) * maxf(spr_scale.x, 0.5)
		smoke.offset = Vector2(0, -40.0)   # plume rises from the stack
		smoke.modulate = Color(1, 1, 1, 0.55)
		smoke.play("puff")
		add_child(smoke)
		_smokes.append(smoke)

var _smokes: Array = []

func _process(delta: float) -> void:
	if _glows.is_empty() and _smokes.is_empty() and _fires.is_empty() and _signs.is_empty():
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
	# hearths burn harder after dark
	for s in _smokes:
		s.modulate.a = 0.75 if night else 0.45
	# The forge never goes out -- but against a dark village its light carries,
	# and in daylight it washes out. Each flame also breathes on its own cycle.
	for i in range(_fires.size()):
		var f: AnimatedSprite2D = _fires[i]
		var breath: float = 0.92 + 0.08 * sin(_t * 3.1 + float(i) * 2.2)
		f.modulate.a = (0.95 if night else 0.62) * breath
	# a lit sign holds steady and just breathes -- it is not a candle
	for sg in _signs:
		var pulse: float = 0.88 + 0.12 * sin(_t * 1.5 + sg["phase"])
		sg["lit"].modulate.a = (0.6 if night else 0.14) * pulse
		sg["halo"].modulate.a = (0.85 if night else 0.1) * pulse
