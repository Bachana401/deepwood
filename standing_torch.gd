extends Node2D

# A big free-standing brazier torch the player can PLACE anywhere on the ground
# (G key, costs materials -- see player.gd try_place_torch). Much larger and
# richer light than the small wall torches: a tall pole with an iron bowl, a
# real fire in it, and a wide golden light pool. Follows the same day/night
# rule as wall torches (lights itself at dusk, snuffs at dawn). Persisted in
# GameState.placed_torches so it survives scene reloads and saves.

const LIGHT_COLOR = Color(1.0, 0.76, 0.42)
const LIGHT_ENERGY = 1.35
const LIGHT_SCALE = 1.9   # 512px texture -> ~486px pool radius

static var big_light_tex: GradientTexture2D = null

static func _light_tex() -> GradientTexture2D:
	if big_light_tex == null:
		var grad = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.14, 0.42, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 0.95, 1.0),      # hot white core
			Color(1.0, 0.9, 0.7, 0.85),      # pale gold
			Color(1.0, 0.7, 0.4, 0.38),      # warm amber falloff
			Color(1.0, 0.6, 0.3, 0.0),       # long soft tail
		])
		big_light_tex = GradientTexture2D.new()
		big_light_tex.gradient = grad
		big_light_tex.width = 512
		big_light_tex.height = 512
		big_light_tex.fill = GradientTexture2D.FILL_RADIAL
		big_light_tex.fill_from = Vector2(0.5, 0.5)
		big_light_tex.fill_to = Vector2(1.0, 0.5)
	return big_light_tex

var light: PointLight2D = null
var flame: CPUParticles2D = null
var glow: Polygon2D = null
var lit := false
var flicker_phase := 0.0

func _ready() -> void:
	add_to_group("standing_torch")
	flicker_phase = randf() * TAU
	_build_visual()
	_apply_lit(GameState.torches_lit())

func _build_visual() -> void:
	# stone base + tall pole + iron bowl (bowl rim at ~ -52)
	_rect(Vector2(-9, -5), Vector2(18, 5), Color(0.4, 0.4, 0.44))
	_rect(Vector2(-2.5, -46), Vector2(5, 41), Color(0.32, 0.24, 0.15))
	_rect(Vector2(-4, -30), Vector2(8, 3), Color(0.28, 0.21, 0.13))   # banding
	_rect(Vector2(-10, -52), Vector2(20, 6), Color(0.24, 0.24, 0.28)) # bowl
	_rect(Vector2(-7, -56), Vector2(14, 4), Color(0.2, 0.2, 0.24))

	glow = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(16):
		var a = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 20.0))
	glow.polygon = pts
	glow.position = Vector2(0, -60)
	glow.color = Color(1.0, 0.66, 0.25, 0.16)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	add_child(glow)

	flame = CPUParticles2D.new()
	flame.position = Vector2(0, -57)
	flame.amount = 26
	flame.lifetime = 0.65
	flame.direction = Vector2(0, -1)
	flame.spread = 16.0
	flame.gravity = Vector2(0, -170)
	flame.initial_velocity_min = 22.0
	flame.initial_velocity_max = 52.0
	flame.scale_amount_min = 2.2
	flame.scale_amount_max = 4.4
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.15, 1), Color(0.6, 0.1, 0.05, 0)])
	flame.color_ramp = g
	flame.emitting = false
	add_child(flame)

	light = PointLight2D.new()
	light.position = Vector2(0, -58)
	light.texture = _light_tex()
	light.texture_scale = LIGHT_SCALE
	light.color = LIGHT_COLOR
	light.energy = LIGHT_ENERGY
	light.shadow_enabled = false
	light.enabled = false
	add_child(light)

func _rect(pos: Vector2, size: Vector2, col: Color) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _apply_lit(on: bool) -> void:
	lit = on
	flame.emitting = on
	light.enabled = on
	glow.visible = on

func _process(_delta: float) -> void:
	var want = GameState.torches_lit()
	if want != lit:
		_apply_lit(want)
	if lit:
		# living firelight: gentle irregular flicker
		var t = Time.get_ticks_msec() / 1000.0
		light.energy = LIGHT_ENERGY * (0.93 + 0.07 * sin(t * 7.3 + flicker_phase) + 0.03 * sin(t * 13.1 + flicker_phase * 2.0))
		glow.scale = Vector2.ONE * (1.0 + 0.1 * sin(t * 5.7 + flicker_phase))
