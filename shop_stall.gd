extends Node2D

# THE SHOP HAD NO SHOP (dev call 2026-07-21). It was a floating "SHOP" sign
# and an invisible trigger zone standing in open ground -- you walked into
# nothing and a menu opened. This is the storefront that was always missing:
# a timber-framed stall with a striped awning, a lit window of wares, a
# counter, and a merchant's lantern. Procedural only (art freeze), drawn from
# the ground line upward so it plants on VILLAGE_Y like the buildings do.

const WOOD_DARK := Color(0.30, 0.21, 0.13, 1.0)
const WOOD := Color(0.44, 0.31, 0.19, 1.0)
const WALL := Color(0.62, 0.55, 0.42, 1.0)
const AWN_A := Color(0.72, 0.24, 0.22, 1.0)
const AWN_B := Color(0.93, 0.89, 0.80, 1.0)
const GLOW := Color(1.0, 0.78, 0.40, 1.0)

const W := 190.0      # stall width
const H := 132.0      # wall height (the awning sits above this)

func _ready() -> void:
	z_index = -2       # the player and the sign read in front of the facade
	_rect(-W / 2.0, -H, W, H, WALL)                       # back wall
	_rect(-W / 2.0, -H, W, 7.0, WOOD_DARK)                # lintel
	_rect(-W / 2.0 - 5.0, -H, 10.0, H, WOOD)              # left post
	_rect(W / 2.0 - 5.0, -H, 10.0, H, WOOD)               # right post
	_rect(-W / 2.0, -6.0, W, 6.0, WOOD_DARK)              # sill on the ground
	_awning()
	_window()
	_counter()
	_lantern()

# --- pieces ---

func _awning() -> void:
	# a striped canopy leaning out over the counter
	var stripes := 8
	var sw := (W + 26.0) / float(stripes)
	for i in range(stripes):
		var p := Polygon2D.new()
		var x0 := -W / 2.0 - 13.0 + i * sw
		p.polygon = PackedVector2Array([
			Vector2(x0, -H - 4.0), Vector2(x0 + sw, -H - 4.0),
			Vector2(x0 + sw, -H - 30.0), Vector2(x0, -H - 30.0),
		])
		p.color = AWN_A if i % 2 == 0 else AWN_B
		add_child(p)
	# the scalloped hem
	for i in range(stripes):
		var t := Polygon2D.new()
		var x0 := -W / 2.0 - 13.0 + i * sw
		t.polygon = PackedVector2Array([
			Vector2(x0, -H - 4.0), Vector2(x0 + sw, -H - 4.0),
			Vector2(x0 + sw * 0.5, -H + 6.0),
		])
		t.color = AWN_A if i % 2 == 0 else AWN_B
		add_child(t)

func _window() -> void:
	# a lit window with goods on a shelf -- the reason the stall reads "shop"
	_rect(-64.0, -H + 20.0, 128.0, 58.0, Color(0.20, 0.17, 0.13, 1.0))
	_rect(-60.0, -H + 24.0, 120.0, 50.0, Color(1.0, 0.86, 0.55, 0.5))
	# wares: a potion, a coil of rope, a blade, a helm -- simple silhouettes
	_rect(-50.0, -H + 46.0, 10.0, 22.0, Color(0.80, 0.22, 0.26, 1.0))   # red flask
	_rect(-30.0, -H + 52.0, 16.0, 16.0, Color(0.55, 0.42, 0.24, 1.0))   # rope coil
	_rect(-2.0, -H + 38.0, 5.0, 30.0, Color(0.82, 0.84, 0.90, 1.0))     # blade
	_rect(20.0, -H + 50.0, 20.0, 18.0, Color(0.62, 0.64, 0.72, 1.0))    # helm
	_rect(-60.0, -H + 72.0, 120.0, 4.0, WOOD_DARK)                      # shelf

func _counter() -> void:
	_rect(-W / 2.0 - 10.0, -46.0, W + 20.0, 12.0, WOOD)        # counter top
	_rect(-W / 2.0 + 6.0, -34.0, 12.0, 34.0, WOOD_DARK)        # leg
	_rect(W / 2.0 - 18.0, -34.0, 12.0, 34.0, WOOD_DARK)        # leg
	# a crate and a sack leaning against the front
	_rect(W / 2.0 + 14.0, -30.0, 30.0, 30.0, Color(0.50, 0.36, 0.21, 1.0))
	_rect(W / 2.0 + 14.0, -18.0, 30.0, 4.0, WOOD_DARK)
	var sack := Polygon2D.new()
	sack.polygon = PackedVector2Array([
		Vector2(-W / 2.0 - 46.0, 0.0), Vector2(-W / 2.0 - 16.0, 0.0),
		Vector2(-W / 2.0 - 20.0, -26.0), Vector2(-W / 2.0 - 42.0, -26.0),
	])
	sack.color = Color(0.66, 0.58, 0.42, 1.0)
	add_child(sack)

func _lantern() -> void:
	# a warm lamp hung from the awning post, breathing slowly
	_rect(W / 2.0 - 4.0, -H - 4.0, 3.0, 16.0, WOOD_DARK)
	var lamp := Polygon2D.new()
	lamp.polygon = PackedVector2Array([
		Vector2(-7, 0), Vector2(7, 0), Vector2(5, 14), Vector2(-5, 14)])
	lamp.position = Vector2(W / 2.0 - 2.5, -H + 12.0)
	lamp.color = GLOW
	add_child(lamp)
	var halo := Sprite2D.new()
	halo.texture = _halo_tex()
	halo.position = lamp.position + Vector2(0, 6.0)
	halo.modulate = Color(GLOW.r, GLOW.g, GLOW.b, 0.45)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = m
	add_child(halo)
	var t := halo.create_tween()
	t.set_loops()
	t.tween_property(halo, "modulate:a", 0.28, 1.3)
	t.tween_property(halo, "modulate:a", 0.5, 1.5)

static var _halo: GradientTexture2D = null

static func _halo_tex() -> GradientTexture2D:
	if _halo == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0)])
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.width = 96
		_halo.height = 96
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
	return _halo

func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	var r := ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
