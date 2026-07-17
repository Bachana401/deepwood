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

# The CRAFT this worker is actually practising, when the villager art has a
# drawn animation for it (art/villagers/<skin>/<craft>_N.png). Every yard trade
# used to run the same generic hammer-rock with differently coloured chips --
# the farmer, the sawyer, the soldier and the smith were all doing the identical
# motion, which is what made the yards read as fake. A worker whose skin has the
# real craft animation plays THAT instead; anyone else falls back to the rock,
# so this degrades gracefully per-skin rather than all-or-nothing.
var craft := ""

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

# Outdoor workers wear the same PixelLab villager art as the wandering
# villagers (art/villagers/), so the people working the yards are the same
# people who live here -- not a stack of coloured rectangles. The window
# silhouettes stay procedural ON PURPOSE: those are shapes behind glass, and a
# dark head-and-shoulders reads better there than a shrunken sprite.
# If the art is missing, every mode falls back to the little ColorRect person
# below, so this is safe with no art shipped.
const VILLAGER_ROOT := "res://art/villagers/"
const VILLAGER_VARIANTS := ["man", "man2", "man3", "man4", "man5",
	"woman", "woman2", "woman3", "woman4", "woman5"]
# The sprite is normalised to the SAME height the ColorRect person is drawn at,
# so body_scale keeps sizing the worker exactly as before and every mode's tool
# coordinates (the rod, the broom, the crate) still land in the hands.
const PROC_BODY_H := 16.7
var skin_sprite: AnimatedSprite2D = null

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
			_build_person()
			position = Vector2(randf_range(min_x, max_x), ground_y)
		"stand":
			_build_person()
			position = spot
		"anvil":
			_build_person()
			position = spot
			if _plays_craft():
				# he has the real motion drawn -- let it play, add nothing
				_skin_anim(craft)
				skin_sprite.speed_scale = randf_range(0.85, 1.15)
				if skin_sprite.sprite_frames.get_frame_count(craft) > 0:
					skin_sprite.frame = randi() % skin_sprite.sprite_frames.get_frame_count(craft)
			elif skin_sprite == null:
				# unskinned fallback: a swinging ColorRect arm
				arm = _px(2.8, -11.0, 2.2, 6.5, skin)
				arm.pivot_offset = Vector2(1.1, 0.5)
		"vendor":
			_build_person()
			position = spot
		"carry":
			# hauls a crate back and forth across the yard
			speed = randf_range(16.0, 24.0)
			_build_person()
			var crate = _px(2.5, -10.5, 6.0, 5.0, Color(0.62, 0.44, 0.26))
			crate.z_index = 1
			_px(2.5, -8.6, 6.0, 1.2, Color(0.5, 0.34, 0.2))
			position = Vector2(randf_range(min_x, max_x), ground_y)
		"sweep":
			# stands and sweeps: broom rocks around its grip
			_build_person()
			position = spot
			arm = _px(2.2, -10.0, 1.8, 12.0, Color(0.55, 0.4, 0.22))   # broom pole
			arm.pivot_offset = Vector2(0.9, 0.0)
			arm.z_index = 1
			var head = ColorRect.new()
			head.position = Vector2(-1.6, 10.5)
			head.size = Vector2(5.0, 2.6)
			head.color = Color(0.75, 0.65, 0.4)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arm.add_child(head)
		"fish":
			_build_person()
			position = spot
			rod = Line2D.new()
			rod.width = 1.4
			rod.default_color = Color(0.4, 0.3, 0.18)
			rod.points = PackedVector2Array([Vector2(3, -10), Vector2(15, -15), Vector2(16, 4)])
			rod.z_index = 1
			gfx.add_child(rod)
	# outdoor workers stand as tall as the wandering NPC avatars (36px body):
	# base art is ~16.7px -> ~2.05-2.3x, varied so heights differ person to person
	if mode != "window":
		body_scale = randf_range(2.0, 2.3)
	dir = [-1, 1][randi() % 2]
	var face_sign = dir if mode in ["walk", "window", "carry"] else face
	gfx.scale = Vector2(face_sign * body_scale, body_scale)

# Picks a villager skin whose art is actually present; "" if none is.
# When this worker has a CRAFT, prefer the villagers who can actually perform
# it -- so the smith is drawn as someone who owns a hammer swing, rather than
# rolling a random villager and hoping.
func _pick_skin() -> String:
	var have: Array = []
	var skilled: Array = []
	for v in VILLAGER_VARIANTS:
		if not EnemySkins.is_per_frame(v, VILLAGER_ROOT):
			continue
		have.append(v)
		if craft != "" and _skin_has_anim(v, craft):
			skilled.append(v)
	if not skilled.is_empty():
		return skilled[randi() % skilled.size()]
	if have.is_empty():
		return ""
	return have[randi() % have.size()]

func _skin_has_anim(vskin: String, anim: String) -> bool:
	return ResourceLoader.exists("%s%s/%s_1.png" % [VILLAGER_ROOT, vskin, anim])

# Roughly the frame where the tool lands, so sparks/chips fly ON the strike.
# The craft loops are drawn as one full swing, so the blow lands around the
# middle of the cycle.
var _last_craft_frame := -1
func _strike_frame() -> int:
	if skin_sprite == null:
		return 0
	return int(skin_sprite.sprite_frames.get_frame_count(craft) * 0.5)

# True once this worker is both skinned AND that skin can really do the craft.
func _plays_craft() -> bool:
	if craft == "" or skin_sprite == null:
		return false
	var sf := skin_sprite.sprite_frames
	return sf != null and sf.has_animation(craft) and sf.get_frame_count(craft) > 1

# The sprite body, feet on gfx's local origin -- same contract as _build_body,
# so every mode's tools/particles keep working against the same anchor.
func _build_skin(vskin: String) -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(vskin, VILLAGER_ROOT)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ch := EnemySkins.content_height(vskin, VILLAGER_ROOT)
	var sc: float = PROC_BODY_H / maxf(ch, 1.0)
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(-EnemySkins.hcenter_px(vskin, VILLAGER_ROOT), -EnemySkins.feet_px(vskin, VILLAGER_ROOT))
	if spr.sprite_frames.has_animation("idle"):
		spr.animation = "idle"
		spr.play("idle")
	gfx.add_child(spr)
	skin_sprite = spr

# Skinned workers walk when they're walking and idle when they're not.
func _skin_anim(want: String) -> void:
	if skin_sprite == null:
		return
	var sf := skin_sprite.sprite_frames
	if sf and sf.has_animation(want) and skin_sprite.animation != want:
		skin_sprite.play(want)

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

# Every outdoor mode builds its body through here: the villager sprite when the
# art is there, the little ColorRect person when it isn't.
func _build_person() -> void:
	var vskin := _pick_skin()
	if vskin != "":
		_build_skin(vskin)
	else:
		_build_body()

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
			_skin_anim("idle" if pause_t > 0.0 else "walk")
			if skin_sprite == null:
				gfx.position.y = -absf(sin(t * 8.0)) * 1.2 * body_scale
			_swing_limbs(t * 9.0, 1.0)
		"stand":
			gfx.rotation = sin(t * 1.3) * 0.045
			if fmod(t, 6.0) < delta:
				face = -face
				gfx.scale.x = face * body_scale
		"anvil":
			swing_t += delta
			if _plays_craft():
				# the drawn craft carries the whole performance -- don't rock the
				# sprite on top of it. Spark on the frame the tool lands, so the
				# chips fly with the strike instead of on a timer of their own.
				var f: int = skin_sprite.frame
				if f != _last_craft_frame:
					_last_craft_frame = f
					if f == _strike_frame():
						_burst()
			elif arm:
				arm.rotation = -absf(sin(swing_t * 5.0)) * 1.3
				if fmod(swing_t, TAU / 5.0) < delta:
					_burst()
			elif skin_sprite:
				# skinned but no drawn craft: lean the body into the blow
				skin_sprite.rotation = -absf(sin(swing_t * 5.0)) * 0.16 * face
				skin_sprite.position.y = -absf(sin(swing_t * 5.0)) * 1.1
				if fmod(swing_t, TAU / 5.0) < delta:
					_burst()
		"vendor":
			gfx.position.y = -absf(sin(t * 2.2)) * 1.0 * body_scale
			gfx.scale.y = body_scale * (1.0 + (0.08 if fmod(t, 4.0) < 0.4 else 0.0))
		"carry":
			_tick_span(delta, min_x, max_x)
			_skin_anim("idle" if pause_t > 0.0 else "walk")
			if skin_sprite == null:
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
