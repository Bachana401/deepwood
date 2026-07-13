extends Node2D

# A villager-at-work figure, spawned by building.gd when villagers are employed
# there. Outdoor figures are FULL NPC SIZE (~36px, same as the wandering
# villager avatars) proper little humans -- legs, tunic, arms, head, hood --
# with per-person variety: height, tunic/pants/hood colors and skin tone are
# all mixed so no two workers look alike.
# Modes:
#   window -- a dark head-and-shoulders silhouette pacing INSIDE a window rect
#             (scaled to the window, min-clamped so it always reads human).
#   walk   -- patrols a strip of ground.
#   stand  -- works at a fixed station: gentle sway + occasional turn.
#   anvil  -- hammers at a station: swinging arm + periodic burst
#             (sparks=true -> golden smith sparks; false -> chip_color dust).
#   vendor -- stands at a market stall, bobbing, little arm-raise.
#   fish   -- stands on the dock deck with a rod line down to the water.

var mode := "walk"
var window_rect := Rect2(0, 0, 20, 20)
var min_x := -40.0
var max_x := 40.0
var ground_y := 0.0
var spot := Vector2.ZERO
var face := 1
var sparks := true
var chip_color := Color(0.85, 0.72, 0.45)

var gfx: Node2D = null
var arm: ColorRect = null
var paper: ColorRect = null
var rod: Line2D = null
var speed := 10.0
var dir := 1
var pause_t := 0.0
var t := 0.0
var swing_t := 0.0
var static_window := false
# Base body is drawn ~16px tall; outdoor figures scale up to full NPC height
# (36px avatar body) with a little per-person variety.
var body_scale := 1.0

const SILHOUETTE = Color(0.12, 0.13, 0.19, 0.95)
const SKINS = [Color(0.87, 0.72, 0.56), Color(0.78, 0.6, 0.45), Color(0.92, 0.78, 0.64)]
const TUNICS = [
	Color(0.36, 0.46, 0.58), Color(0.56, 0.42, 0.28), Color(0.38, 0.52, 0.34),
	Color(0.58, 0.42, 0.52), Color(0.62, 0.55, 0.34), Color(0.44, 0.38, 0.6),
	Color(0.6, 0.34, 0.3), Color(0.4, 0.55, 0.55),
]
const PANTS = [Color(0.3, 0.28, 0.34), Color(0.36, 0.3, 0.22), Color(0.28, 0.34, 0.3), Color(0.42, 0.36, 0.3)]
const HOODS = [Color(0.24, 0.4, 0.26), Color(0.42, 0.3, 0.2), Color(0.45, 0.26, 0.28)]
var skin := SKINS[0]

func _ready() -> void:
	gfx = Node2D.new()
	add_child(gfx)
	t = randf() * TAU
	skin = SKINS[randi() % SKINS.size()]
	match mode:
		"window":
			speed = [7.0, 9.0, 20.0, 26.0][randi() % 4]
			_build_silhouette()
			var lo = window_rect.position.x + 3.0
			var hi = window_rect.end.x - 3.0
			if hi - lo < 4.0:
				static_window = true
			position = Vector2(clamp(window_rect.get_center().x, lo, hi), window_rect.end.y)
			if not static_window and speed > 15.0:
				paper = _px(1.5, -8.0, 3.0, 4.0, Color(0.95, 0.95, 0.9))
		"walk":
			speed = randf_range(24.0, 40.0)
			_build_body()
			position = Vector2(randf_range(min_x, max_x), ground_y)
		"stand":
			_build_body()
			position = spot
		"anvil":
			_build_body()
			position = spot
			arm = _px(2.8, -11.0, 2.2, 6.5, skin)
			arm.pivot_offset = Vector2(1.1, 0.5)
		"vendor":
			_build_body()
			position = spot
		"carry":
			# hauls a crate back and forth across the yard
			speed = randf_range(16.0, 24.0)
			_build_body()
			var crate = _px(2.5, -10.5, 6.0, 5.0, Color(0.62, 0.44, 0.26))
			crate.z_index = 1
			_px(2.5, -8.6, 6.0, 1.2, Color(0.5, 0.34, 0.2))
			position = Vector2(randf_range(min_x, max_x), ground_y)
		"sweep":
			# stands and sweeps: broom rocks around its grip
			_build_body()
			position = spot
			arm = _px(2.2, -10.0, 1.8, 12.0, Color(0.55, 0.4, 0.22))   # broom pole
			arm.pivot_offset = Vector2(0.9, 0.0)
			var head = ColorRect.new()
			head.position = Vector2(-1.6, 10.5)
			head.size = Vector2(5.0, 2.6)
			head.color = Color(0.75, 0.65, 0.4)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arm.add_child(head)
		"fish":
			_build_body()
			position = spot
			rod = Line2D.new()
			rod.width = 1.4
			rod.default_color = Color(0.4, 0.3, 0.18)
			rod.points = PackedVector2Array([Vector2(3, -10), Vector2(15, -15), Vector2(16, 4)])
			gfx.add_child(rod)
	# outdoor workers stand as tall as the wandering NPC avatars (36px body):
	# base art is ~16.7px -> ~2.05-2.3x, varied so heights differ person to person
	if mode != "window":
		body_scale = randf_range(2.0, 2.3)
	dir = [-1, 1][randi() % 2]
	var face_sign = dir if mode in ["walk", "window", "carry"] else face
	gfx.scale = Vector2(face_sign * body_scale, body_scale)

func _px(x: float, y: float, w: float, h: float, col: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gfx.add_child(r)
	return r

# A little person, feet at local (0,0), ~16.7px tall BEFORE body_scale:
# pants-colored legs, belted tunic, two arms, head, hood. Colors all varied.
var l_leg: ColorRect = null
var r_leg: ColorRect = null
var l_arm: ColorRect = null
var r_arm: ColorRect = null

func _build_body() -> void:
	var tunic = TUNICS[randi() % TUNICS.size()]
	var pants = PANTS[randi() % PANTS.size()]
	var hood = HOODS[randi() % HOODS.size()]
	l_leg = _px(-2.8, -5.0, 2.2, 5.0, pants)          # legs (pivot at the hip)
	r_leg = _px(0.6, -5.0, 2.2, 5.0, pants)
	l_leg.pivot_offset = Vector2(1.1, 0.0)
	r_leg.pivot_offset = Vector2(1.1, 0.0)
	_px(-3.2, -11.5, 6.4, 6.5, tunic)                 # tunic
	l_arm = _px(-4.6, -11.0, 1.6, 5.0, tunic.darkened(0.12))
	r_arm = _px(3.0, -11.0, 1.6, 5.0, tunic.darkened(0.12))
	l_arm.pivot_offset = Vector2(0.8, 0.0)
	r_arm.pivot_offset = Vector2(0.8, 0.0)
	_px(-3.2, -6.2, 6.4, 1.2, tunic.darkened(0.35))   # belt
	_px(-2.0, -15.5, 4.0, 4.0, skin)                  # head
	_px(-2.4, -16.7, 4.8, 1.9, hood)                  # hood

# Head-and-shoulders behind the glass; min-clamped so it always reads human.
func _build_silhouette() -> void:
	var hgt = max(10.0, window_rect.size.y * 0.78)
	var wdt = max(5.0, hgt * 0.42)
	_px(-wdt / 2.0, -hgt * 0.72, wdt, hgt * 0.72, SILHOUETTE)
	_px(-wdt * 0.7, -hgt * 0.62, wdt * 0.24, hgt * 0.34, SILHOUETTE)
	_px(-wdt * 0.3, -hgt, wdt * 0.6, hgt * 0.3, SILHOUETTE)

func _process(delta: float) -> void:
	t += delta
	match mode:
		"window":
			if not static_window:
				_tick_span(delta, window_rect.position.x + 3.0, window_rect.end.x - 3.0)
		"walk":
			_tick_span(delta, min_x, max_x)
			gfx.position.y = -absf(sin(t * 8.0)) * 1.2 * body_scale
			_swing_limbs(t * 9.0, 1.0)
		"stand":
			gfx.rotation = sin(t * 1.3) * 0.045
			if fmod(t, 6.0) < delta:
				face = -face
				gfx.scale.x = face * body_scale
		"anvil":
			swing_t += delta
			if arm:
				arm.rotation = -absf(sin(swing_t * 5.0)) * 1.3
			if fmod(swing_t, TAU / 5.0) < delta:
				_burst()
		"vendor":
			gfx.position.y = -absf(sin(t * 2.2)) * 1.0 * body_scale
			gfx.scale.y = body_scale * (1.0 + (0.08 if fmod(t, 4.0) < 0.4 else 0.0))
		"carry":
			_tick_span(delta, min_x, max_x)
			gfx.position.y = -absf(sin(t * 6.0)) * 1.0 * body_scale   # heavier trudge
			_swing_limbs(t * 6.5, 0.6)   # legs only really -- arms hold the crate
		"sweep":
			if arm:
				arm.rotation = 0.35 + sin(t * 2.6) * 0.4   # broom sweeps an arc
			gfx.rotation = sin(t * 2.6) * 0.03
		"fish":
			gfx.position.y = -absf(sin(t * 1.6)) * 0.8 * body_scale
			if rod:
				rod.points[2] = Vector2(16, 4 + sin(t * 2.4) * 1.5)

# Simple walk cycle: arm forward while the opposite leg swings back.
func _swing_limbs(phase: float, strength: float) -> void:
	if l_leg == null:
		return
	var swing = sin(phase) * strength
	l_leg.rotation = swing * 0.5
	r_leg.rotation = -swing * 0.5
	if mode != "carry":   # carriers keep both hands on the crate
		l_arm.rotation = -swing * 0.42
		r_arm.rotation = swing * 0.42

func _tick_span(delta: float, lo: float, hi: float) -> void:
	if pause_t > 0.0:
		pause_t -= delta
		return
	position.x += dir * speed * delta
	if position.x >= hi:
		position.x = hi
		_turn(-1)
	elif position.x <= lo:
		position.x = lo
		_turn(1)

func _turn(new_dir: int) -> void:
	dir = new_dir
	gfx.scale.x = dir * (body_scale if mode != "window" else 1.0)
	pause_t = randf_range(0.3, 1.8)
	if paper:
		paper.visible = randf() < 0.75

func _burst() -> void:
	var p = CPUParticles2D.new()
	p.position = Vector2(7, -5)   # in gfx space so it scales with the body
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 6
	p.lifetime = 0.32
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 260 if not sparks else 220)
	p.initial_velocity_min = 28.0
	p.initial_velocity_max = 66.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	p.color = Color(1.0, 0.8, 0.3) if sparks else chip_color
	gfx.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
