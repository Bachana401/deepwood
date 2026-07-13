extends Node2D

# A small BLOCKY, pixel-styled farm animal (chicken / pig / cow / sheep) that
# ambles inside its pen and never leaves it (see farm_pen.gd). When the player
# comes close it makes its noise (a little speech bubble + a synthesized sound).

var animal_type := "chicken"
var min_x := 0.0
var max_x := 100.0
var ground_y := 0.0

var speed := 18.0
var target_x := 0.0
var pause_timer := 0.0
var facing := 1
var walk_t := 0.0
var gfx: Node2D = null

var noise_cooldown := 0.0
var sfx: AudioStreamPlayer2D = null
var bubble: Label = null
var bubble_timer := 0.0
const NOISE_RANGE := 150.0
const NOISE_WORD := {"chicken": "Cluck!", "pig": "Oink!", "cow": "Moo!", "sheep": "Baa!"}

func setup(t: String, mn: float, mx: float, gy: float) -> void:
	animal_type = t
	min_x = mn
	max_x = mx
	ground_y = gy

func _ready() -> void:
	var speeds = {"chicken": 30.0, "pig": 16.0, "cow": 11.0, "sheep": 14.0}
	speed = speeds.get(animal_type, 18.0)
	gfx = Node2D.new()
	add_child(gfx)
	_build_body()
	global_position.y = ground_y
	global_position.x = clamp(global_position.x, min_x, max_x)
	facing = [-1, 1][randi() % 2]
	gfx.scale.x = facing
	_pick_target()
	noise_cooldown = randf_range(1.0, 5.0)
	# synthesized noise
	sfx = AudioStreamPlayer2D.new()
	sfx.stream = _synth(animal_type)
	sfx.volume_db = -6.0
	add_child(sfx)
	# speech bubble
	bubble = Label.new()
	bubble.text = NOISE_WORD.get(animal_type, "!")
	bubble.position = Vector2(-14, -34)
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 1, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	bubble.add_theme_constant_override("outline_size", 4)
	bubble.visible = false
	add_child(bubble)

func _pick_target() -> void:
	target_x = randf_range(min_x, max_x)
	pause_timer = randf_range(0.5, 2.6)

func _process(delta: float) -> void:
	global_position.y = ground_y
	# noise when the player is near
	noise_cooldown -= delta
	if noise_cooldown <= 0.0:
		var pl = get_tree().get_first_node_in_group("player")
		if pl and global_position.distance_to(pl.global_position) < NOISE_RANGE:
			_make_noise()
		noise_cooldown = randf_range(2.5, 5.5)
	if bubble_timer > 0.0:
		bubble_timer -= delta
		if bubble_timer <= 0.0 and bubble:
			bubble.visible = false

	if pause_timer > 0.0:
		pause_timer -= delta
		gfx.position.y = 0.0
		return
	var dx = target_x - global_position.x
	if absf(dx) < 3.0:
		_pick_target()
		return
	var dir = signf(dx)
	if int(dir) != facing:
		facing = int(dir)
		gfx.scale.x = facing
	global_position.x = clamp(global_position.x + dir * speed * delta, min_x, max_x)
	walk_t += delta * 9.0
	gfx.position.y = -absf(sin(walk_t)) * 1.6

func _make_noise() -> void:
	if bubble:
		bubble.visible = true
		bubble_timer = 1.3
	if sfx and sfx.stream:
		sfx.play()

# --- BLOCKY draw helpers ---
func _px(x: float, y: float, w: float, h: float, col: Color) -> void:
	var r = ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gfx.add_child(r)

func _eye(x: float, y: float) -> void:
	_px(x, y, 3, 3, Color(0.08, 0.08, 0.08))       # big cute square eye
	_px(x, y, 1.2, 1.2, Color(1, 1, 1))            # glint

func _build_body() -> void:
	match animal_type:
		"chicken": _build_chicken()
		"pig": _build_pig()
		"cow": _build_cow()
		"sheep": _build_sheep()
		_: _build_chicken()

func _build_chicken() -> void:
	var white = Color(0.97, 0.96, 0.92)
	_px(2, -2, 1.6, 2, Color(0.92, 0.6, 0.15))    # legs
	_px(6, -2, 1.6, 2, Color(0.92, 0.6, 0.15))
	_px(1, -10, 8, 8, white)                       # blocky body
	_px(-1, -9, 2, 4, white)                       # tail block
	_px(7, -15, 5, 5, white)                       # head
	_px(8, -18, 3, 2, Color(0.88, 0.16, 0.12))     # comb
	_px(12, -13, 2.5, 2, Color(0.95, 0.6, 0.1))    # beak
	_eye(9, -14)

func _build_pig() -> void:
	var pink = Color(0.93, 0.64, 0.66)
	var dark = pink.darkened(0.18)
	_px(-5, -3, 2, 3, dark)                         # legs
	_px(-1, -3, 2, 3, dark)
	_px(5, -3, 2, 3, dark)
	_px(9, -3, 2, 3, dark)
	_px(-6, -13, 14, 10, pink)                      # blocky body
	_px(-8, -11, 2, 3, dark)                        # curly tail blocks
	_px(-9, -13, 2, 2, dark)
	_px(8, -14, 6, 6, pink)                         # head
	_px(13, -12, 3, 3, pink.darkened(0.08))         # snout
	_px(13, -12, 1, 1, dark)
	_px(15, -12, 1, 1, dark)
	_px(8, -16, 2, 2, dark)                         # ear
	_eye(10, -13)

func _build_cow() -> void:
	var white = Color(0.96, 0.95, 0.91)
	var black = Color(0.18, 0.16, 0.16)
	var pinkn = Color(0.85, 0.6, 0.62)
	_px(-7, -5, 2.5, 5, black)                      # legs
	_px(-2, -5, 2.5, 5, black)
	_px(5, -5, 2.5, 5, black)
	_px(10, -5, 2.5, 5, black)
	_px(-8, -18, 18, 13, white)                     # blocky body
	_px(-5, -16, 5, 4, black)                       # patches
	_px(3, -12, 4, 3, black)
	_px(9, -21, 8, 8, white)                        # head
	_px(8, -24, 2, 3, white)                        # horns
	_px(15, -24, 2, 3, white)
	_px(15, -16, 4, 3, pinkn)                       # snout
	_px(16, -15, 1, 1, black)
	_px(18, -15, 1, 1, black)
	_eye(12, -19)

func _build_sheep() -> void:
	var wool = Color(0.95, 0.94, 0.91)
	var face = Color(0.28, 0.26, 0.26)
	_px(-5, -5, 2, 5, face)                         # legs
	_px(-1, -5, 2, 5, face)
	_px(4, -5, 2, 5, face)
	_px(8, -5, 2, 5, face)
	# fluffy blocky wool (stepped squares)
	_px(-6, -14, 14, 9, wool)
	_px(-4, -17, 10, 4, wool)
	_px(-2, -18, 6, 3, wool)
	_px(9, -15, 6, 6, face)                         # head
	_px(9, -17, 2, 2, face)                         # ear
	_eye(11, -14)

# --- crude synthesized animal noise (16-bit PCM) ---
func _synth(type: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var v := 0.0
		match type:
			"cow":
				var f := lerpf(195.0, 150.0, t / dur)
				var env := exp(-t * 3.0) * (1.0 - exp(-t * 45.0))
				v = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.25) * env
			"sheep":
				var fs := 330.0 + sin(t * 42.0) * 32.0
				var envs := exp(-t * 3.6) * (1.0 - exp(-t * 45.0))
				v = sin(TAU * fs * t) * envs * 0.7
			"pig":
				var seg := fmod(t, 0.16)
				var on := 1.0 if seg < 0.09 else 0.0
				v = (sin(TAU * 205.0 * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.2) * on * exp(-seg * 8.0)
			"chicken":
				var seg2 := fmod(t, 0.14)
				var on2 := 1.0 if seg2 < 0.05 else 0.0
				var fc := 760.0 + sin(t * 80.0) * 120.0
				v = sin(TAU * fc * t) * on2 * exp(-seg2 * 20.0) * 0.6
		v = clampf(v, -1.0, 1.0)
		var s16 := int(v * 30000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
