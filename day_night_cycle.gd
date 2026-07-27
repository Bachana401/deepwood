extends Node

const DAY_LENGTH_SECONDS = 600.0
const HOURS_PER_SECOND = 24.0 / DAY_LENGTH_SECONDS

const DAWN_START = 5.0
const DAWN_END = 7.0
const DUSK_START = 18.0
const DUSK_END = 20.0

const SUNRISE = 6.0
const SUNSET = 18.0
const MOONRISE = 18.0
const MOONSET = 30.0

# real skies show the sun and moon at once around dawn/dusk -- widen each
# body's visible window by this much (centered on the rise/set point) so
# there's a brief overlap. Defined in real seconds and converted using the
# current pacing so it stays "7 seconds" even if DAY_LENGTH_SECONDS changes.
const SUN_MOON_OVERLAP_SECONDS = 7.0
const SUN_MOON_OVERLAP_HOURS = SUN_MOON_OVERLAP_SECONDS * HOURS_PER_SECOND

# sun/moon live in world space and only drift a small fraction of how far the
# player actually travels -- that "lag" is what reads as distant/parallax
# instead of being glued to the screen like a HUD element.
const PARALLAX_FACTOR = 0.12
const ARC_SWING_X = 300.0
const SKY_HORIZON_Y = -540.0
const SKY_PEAK_Y = -760.0

const DAY_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR = Color(0.16, 0.18, 0.34, 1.0)

const SUN_COLOR = Color(1.0, 0.87, 0.45, 1.0)
const MOON_COLOR = Color(0.83, 0.81, 0.75, 1.0)
const SUN_RADIUS = 44.2
const MOON_RADIUS = 40.0

# tighter, more intense halo than before -- a big spread-out glow was
# smearing the disc's edges into an indistinct blob. Keeping the halo close
# to the disc reads as a crisp "shine" instead.
const SUN_GLOW_OUTER_SCALE = 1.6
const SUN_GLOW_INNER_SCALE = 1.25
const SUN_GLOW_OUTER_ALPHA = 0.16
const SUN_GLOW_INNER_ALPHA = 0.32

# straight rays radiating outward, like a classic sun icon -- drawn behind
# the disc (so the disc's clean edge still reads on top) and additively
# blended so they read as light rather than solid spokes.
const SUN_RAY_COUNT = 12
const SUN_RAY_INNER_SCALE = 1.05
const SUN_RAY_OUTER_SCALE = 3.8
const SUN_RAY_HALF_WIDTH_RAD = 0.025
const SUN_RAY_ALPHA = 0.18

# a small surface highlight -- breaks up the flat fill so the disc reads as
# a textured sphere instead of a solid color. Mostly circular with just a
# touch of irregularity, sitting toward the lower-left of the disc.
const SUN_HIGHLIGHT_COLOR = Color(1.0, 1.0, 1.0, 0.8)
const SUN_HIGHLIGHT_RADIUS = 5.25
const SUN_HIGHLIGHT_OFFSET = Vector2(-15.0, 14.0)
const SUN_HIGHLIGHT_BUMPINESS = 0.08

# moon's own close-up shine: small radius, but more intense than the sun's --
# "shinier" without actually lighting up the ground. It is purely cosmetic
# and never touches CanvasModulate, so it has zero effect on how visible
# enemies are at night.
const MOON_GLOW_OUTER_SCALE = 1.5
const MOON_GLOW_INNER_SCALE = 1.2
const MOON_GLOW_OUTER_ALPHA = 0.32
const MOON_GLOW_INNER_ALPHA = 0.55

# separate "moonlight" sky glow: much larger, faint rings that light up the
# open sky around the moon (brightest closest to it). Rendered at a z_index
# between the flat sky bands (-100) and all terrain/gameplay objects (0), so
# it's automatically masked out wherever ground, platforms, or mountains
# stand in front of it -- it can never brighten the player's play area.
const SKY_GLOW_COLOR = Color(0.75, 0.82, 0.95, 1.0)
const SKY_GLOW_LAYERS = [
	{"scale": 4.0, "alpha": 0.12},
	{"scale": 7.0, "alpha": 0.07},
	{"scale": 11.0, "alpha": 0.035},
]

const MOON_PHASES = [
	{"name": "full", "k": 1.0},
	{"name": "gibbous", "k": 0.5},
	{"name": "half", "k": 0.0},
	{"name": "crescent", "k": -0.5},
	{"name": "thin_crescent", "k": -0.85},
]

# small crater dots give the moon's surface texture instead of a flat
# color -- positions are generated once so it reads as one consistent moon
# surface (real craters don't move), and only the ones that currently fall
# within the lit silhouette are shown, so they correctly track each phase.
# Sized and contrasted to actually read at the moon's small on-screen size.
const MOON_CRATER_COUNT = 10
const MOON_CRATER_RADIUS_MIN = 5.0
const MOON_CRATER_RADIUS_MAX = 11.0
# a small palette instead of one flat tone -- real craters/maria vary between
# dusty brown-grey and cooler shadow-grey, which reads as "dirty" texture
# rather than a uniform wash. Darkened further so they're clearly visible.
const MOON_CRATER_COLORS = [
	Color(0.36, 0.32, 0.24, 1.0),
	Color(0.32, 0.34, 0.38, 1.0),
	Color(0.4, 0.35, 0.24, 1.0),
]
const MOON_CRATER_ALPHA = 0.7

var time_of_day = 8.0
var was_night = false
var current_phase_index = 0
var last_phase_name = ""
var moon_craters: Array = []

# Unlike time_of_day (which wraps every 24 hours), this counts up forever --
# other systems that need to measure elapsed in-game time across day
# boundaries (e.g. mating house pairings, see GameState) read this instead.
# The debug time-skip keys adjust both together, so fast-forwarding OR
# rewinding time correctly speeds up/reverses anything tracked this way too.
var total_hours_elapsed = 0.0

func _ready() -> void:
	var sun = get_node_or_null("../SunIcon")
	if sun:
		build_sun(sun)
	var moon = get_node_or_null("../MoonIcon")
	if moon:
		setup_moon_glow_materials(moon)
		build_moon_sky_glow(moon)
	var old_sun = get_node_or_null("../Background/Sun")
	if old_sun:
		old_sun.visible = false
	add_to_group("day_night")   # so main can resync us after a Continue load
	sync_from_master()

# Sync the clock from the master BEFORE the first draw -- else the scene
# renders one frame at the 8.0 default (bright day) before _process corrects
# it, and if a dialogue pauses the tree on frame one (the prologue!) that
# bright frame is what the player sees. (start-scene fix)
# EXTRACTED (audit fix): children _ready before main._ready applies a Continue
# save, so on a fresh launch this seeded from the PRE-load game_hours (0.0) --
# possibly re-rolling the moon across a night boundary the real clock never
# crossed. main.gd calls this again right after the save lands.
func sync_from_master() -> void:
	total_hours_elapsed = GameState.game_hours
	time_of_day = fposmod(GameState.START_TIME_OF_DAY + GameState.game_hours, 24.0)
	was_night = is_night()
	pick_new_moon_phase()
	update_visuals()

# Normal alpha blending just fades a shape toward the background color -- it
# never actually looks like it's emitting light, only like a faded overlay.
# Additive blending genuinely brightens whatever is behind it (and stacks
# where multiple glow layers overlap), which is what a real "glow"/"shine"
# effect requires. Only the glow halos get this; the solid discs/body stay
# on normal blending so they still read as an opaque surface.
func make_additive_material() -> CanvasItemMaterial:
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func build_sun(sun_container: Node2D) -> void:
	var outer = sun_container.get_node_or_null("GlowOuter")
	var inner = sun_container.get_node_or_null("GlowInner")
	var disc = sun_container.get_node_or_null("Disc")
	var rays = sun_container.get_node_or_null("Rays")
	var highlight = sun_container.get_node_or_null("Highlight")
	if outer:
		build_circle(outer, SUN_RADIUS * SUN_GLOW_OUTER_SCALE, Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, SUN_GLOW_OUTER_ALPHA))
		outer.material = make_additive_material()
	if inner:
		build_circle(inner, SUN_RADIUS * SUN_GLOW_INNER_SCALE, Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, SUN_GLOW_INNER_ALPHA))
		inner.material = make_additive_material()
	if rays:
		build_sun_rays(rays)
	if disc:
		build_circle(disc, SUN_RADIUS, SUN_COLOR)
	if highlight:
		build_sun_highlight(highlight, SUN_HIGHLIGHT_RADIUS, SUN_HIGHLIGHT_COLOR)

func build_sun_highlight(poly: Polygon2D, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	var segments = 9
	for i in range(segments):
		var angle = i * TAU / float(segments)
		var variance = 1.0 + randf_range(-SUN_HIGHLIGHT_BUMPINESS, SUN_HIGHLIGHT_BUMPINESS)
		points.append(SUN_HIGHLIGHT_OFFSET + Vector2(cos(angle), sin(angle)) * radius * variance)
	poly.polygon = points
	poly.color = color

func build_sun_rays(rays_node: Node2D) -> void:
	for i in range(SUN_RAY_COUNT):
		var angle = i * TAU / float(SUN_RAY_COUNT)
		var inner_r = SUN_RADIUS * SUN_RAY_INNER_SCALE
		var outer_r = SUN_RADIUS * SUN_RAY_OUTER_SCALE
		var p1 = Vector2(cos(angle - SUN_RAY_HALF_WIDTH_RAD), sin(angle - SUN_RAY_HALF_WIDTH_RAD)) * inner_r
		var p2 = Vector2(cos(angle + SUN_RAY_HALF_WIDTH_RAD), sin(angle + SUN_RAY_HALF_WIDTH_RAD)) * inner_r
		var tip = Vector2(cos(angle), sin(angle)) * outer_r
		var ray = Polygon2D.new()
		ray.polygon = PackedVector2Array([p1, p2, tip])
		ray.color = Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, SUN_RAY_ALPHA)
		ray.material = make_additive_material()
		rays_node.add_child(ray)

func setup_moon_glow_materials(moon_container: Node2D) -> void:
	var outer = moon_container.get_node_or_null("GlowOuter")
	var inner = moon_container.get_node_or_null("GlowInner")
	if outer:
		outer.material = make_additive_material()
	if inner:
		inner.material = make_additive_material()

# The close-up glow has to match the CURRENT phase's silhouette -- a plain
# circular halo behind a thin crescent body looked wrong (a full-moon-shaped
# glow around a sliver of moon). Rebuilding this with the same k as the body
# keeps the shine following whatever's actually lit.
func update_moon_glow_shape(moon_container: Node2D, k: float) -> void:
	var outer = moon_container.get_node_or_null("GlowOuter")
	var inner = moon_container.get_node_or_null("GlowInner")
	if outer:
		build_moon_phase(outer, MOON_RADIUS * MOON_GLOW_OUTER_SCALE, k, Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, MOON_GLOW_OUTER_ALPHA))
	if inner:
		build_moon_phase(inner, MOON_RADIUS * MOON_GLOW_INNER_SCALE, k, Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, MOON_GLOW_INNER_ALPHA))

# Old approach generated craters uniformly across the WHOLE disc, then threw
# out any that didn't fully fit the current phase's silhouette. That's fine
# for full/gibbous/half (most of the disc is lit), but crescent/thin_crescent
# only leave a sliver a few pixels wide -- a crater sized for a full moon can
# never fit there, so those phases ended up with barely any craters at all
# (or, before the containment fix, ones that visibly poked past the edge).
# Instead, sample positions directly inside the CURRENT phase's lit band, and
# size each crater to whatever that spot can actually hold (via binary
# search), capped at the normal min/max. Narrow phases naturally get a
# handful of small craters near the limb instead of none.
func generate_moon_craters(k: float) -> void:
	moon_craters.clear()
	var attempts = 0
	var max_attempts = MOON_CRATER_COUNT * 400
	while moon_craters.size() < MOON_CRATER_COUNT and attempts < max_attempts:
		attempts += 1
		var y = randf_range(-MOON_RADIUS * 0.85, MOON_RADIUS * 0.85)
		var half_width = sqrt(max(MOON_RADIUS * MOON_RADIUS - y * y, 0.0))
		var limb_x = half_width
		var terminator_x = -k * half_width
		var lo_x = min(terminator_x, limb_x)
		var hi_x = max(terminator_x, limb_x)
		if hi_x - lo_x < 2.0:
			continue
		var x = randf_range(lo_x, hi_x)
		var pos = Vector2(x, y)
		var fit_radius = max_crater_radius_at(pos, MOON_RADIUS, k, MOON_CRATER_RADIUS_MAX)
		if fit_radius < 2.0:
			continue
		var radius = min(fit_radius, randf_range(MOON_CRATER_RADIUS_MIN, MOON_CRATER_RADIUS_MAX))
		var too_close = false
		for existing in moon_craters:
			if pos.distance_to(existing.pos) < (radius + existing.radius) + 3.0:
				too_close = true
				break
		if too_close:
			continue
		var color = MOON_CRATER_COLORS[randi() % MOON_CRATER_COLORS.size()]
		moon_craters.append({"pos": pos, "radius": radius, "color": color})

# Binary search for the largest radius centered on pos that still keeps the
# WHOLE crater disc inside the phase silhouette (see is_crater_fully_in_phase).
func max_crater_radius_at(pos: Vector2, moon_radius: float, k: float, max_r: float) -> float:
	if not is_point_in_moon_phase(pos, moon_radius, k):
		return 0.0
	var lo = 0.0
	var hi = max_r
	for i in range(14):
		var mid = (lo + hi) / 2.0
		if is_crater_fully_in_phase(pos, mid, moon_radius, k):
			lo = mid
		else:
			hi = mid
	return lo

# Same math as build_moon_phase(): at a given height (py), the lit region
# spans from the terminator curve to the round limb. A point is inside the
# currently-lit silhouette exactly when its x falls between those two.
func is_point_in_moon_phase(pos: Vector2, radius: float, k: float) -> bool:
	if absf(pos.y) > radius:
		return false
	var half_width = sqrt(max(radius * radius - pos.y * pos.y, 0.0))
	var limb_x = half_width
	var terminator_x = -k * half_width
	return pos.x >= terminator_x and pos.x <= limb_x

# checking only the crater's center point let large craters poke their edge
# past a curved/narrow terminator (gibbous, crescent) into the dark side --
# looked like a rendering glitch. Sampling points around its own circumference
# too ensures the WHOLE crater disc sits safely inside the lit silhouette.
func is_crater_fully_in_phase(pos: Vector2, crater_radius: float, moon_radius: float, k: float) -> bool:
	if not is_point_in_moon_phase(pos, moon_radius, k):
		return false
	var check_points = 8
	for i in range(check_points):
		var angle = i * TAU / float(check_points)
		var edge_point = pos + Vector2(cos(angle), sin(angle)) * crater_radius
		if not is_point_in_moon_phase(edge_point, moon_radius, k):
			return false
	return true

func update_moon_craters(moon_container: Node2D, k: float) -> void:
	var container = moon_container.get_node_or_null("Craters")
	if container == null:
		return
	for child in container.get_children():
		child.free()
	for crater in moon_craters:
		if not is_crater_fully_in_phase(crater.pos, crater.radius, MOON_RADIUS, k):
			continue
		var dot = Polygon2D.new()
		build_circle(dot, crater.radius, crater.color)
		dot.color.a = MOON_CRATER_ALPHA
		dot.position = crater.pos
		dot.set_meta("crater_color", crater.color)
		container.add_child(dot)

func build_moon_sky_glow(moon_container: Node2D) -> void:
	for i in range(SKY_GLOW_LAYERS.size()):
		var glow = moon_container.get_node_or_null("SkyGlow" + str(i + 1))
		if glow:
			var layer = SKY_GLOW_LAYERS[i]
			build_circle(glow, MOON_RADIUS * layer.scale, Color(SKY_GLOW_COLOR.r, SKY_GLOW_COLOR.g, SKY_GLOW_COLOR.b, layer.alpha))
			glow.material = make_additive_material()

func build_circle(poly: Polygon2D, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(28):
		var angle = i * TAU / 28.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = points
	poly.color = color

func build_moon_phase(poly: Polygon2D, radius: float, k: float, color: Color) -> void:
	var points = PackedVector2Array()
	var segments = 28
	for i in range(segments + 1):
		var theta = -PI / 2 + i * PI / segments
		points.append(Vector2(cos(theta) * radius, sin(theta) * radius))
	if absf(k) < 0.02:
		# near-exact half moon: the terminator is a straight vertical line.
		# Sweeping 29 EXACTLY colinear points along it (the general formula
		# below) triggers visible triangulation artifacts on some polygons --
		# two points cleanly close the diameter edge instead.
		points.append(Vector2(0, radius))
		points.append(Vector2(0, -radius))
	else:
		for i in range(segments + 1):
			var theta = PI / 2 - i * PI / segments
			points.append(Vector2(-cos(theta) * radius * k, sin(theta) * radius))
	poly.polygon = points
	poly.color = color

func pick_new_moon_phase() -> void:
	var candidates: Array = []
	for i in range(MOON_PHASES.size()):
		if last_phase_name == "full" and MOON_PHASES[i].name == "full":
			continue
		candidates.append(i)
	current_phase_index = candidates[randi() % candidates.size()]
	last_phase_name = MOON_PHASES[current_phase_index].name
	var k = MOON_PHASES[current_phase_index].k
	var moon = get_node_or_null("../MoonIcon")
	if moon:
		var moon_body = moon.get_node_or_null("Body")
		if moon_body:
			build_moon_phase(moon_body, MOON_RADIUS, k, MOON_COLOR)
		update_moon_glow_shape(moon, k)
		generate_moon_craters(k)
		update_moon_craters(moon, k)

func _process(_delta: float) -> void:
	handle_debug_time_input()
	# The clock now lives in GameState (so it advances in every scene). This
	# node is purely the visual, mirroring the master clock each frame.
	total_hours_elapsed = GameState.game_hours
	time_of_day = fposmod(GameState.START_TIME_OF_DAY + GameState.game_hours, 24.0)
	var night_now = is_night()
	if night_now and not was_night:
		pick_new_moon_phase()
	was_night = night_now
	update_visuals()

func handle_debug_time_input() -> void:
	# Dev-only: these keys ([ ] \ in the input map) drive the master clock and can rewind
	# it, which rewinds training/pregnancies/wages via negative hours_passed. A player must
	# never reach them.
	if not GameState.dev_mode:
		return
	# Debug keys nudge the master clock; time_of_day/total_hours_elapsed follow.
	if Input.is_action_just_pressed("time_forward"):
		GameState.skip_hours(1.0)
	if Input.is_action_just_pressed("time_backward"):
		GameState.skip_hours(-1.0)
	if Input.is_action_just_pressed("time_skip_day"):
		GameState.skip_hours(24.0)
		pick_new_moon_phase()

func get_darkness_factor() -> float:
	if time_of_day >= DAWN_END and time_of_day <= DUSK_START:
		return 0.0
	if time_of_day >= DUSK_END or time_of_day < DAWN_START:
		return 1.0
	if time_of_day >= DUSK_START and time_of_day < DUSK_END:
		return (time_of_day - DUSK_START) / (DUSK_END - DUSK_START)
	return 1.0 - (time_of_day - DAWN_START) / (DAWN_END - DAWN_START)

func is_night() -> bool:
	return get_darkness_factor() > 0.5

func get_sun_progress() -> float:
	var half_overlap = SUN_MOON_OVERLAP_HOURS / 2.0
	if time_of_day < SUNRISE - half_overlap or time_of_day > SUNSET + half_overlap:
		return -1.0
	return clamp((time_of_day - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)

func get_moon_progress() -> float:
	var half_overlap = SUN_MOON_OVERLAP_HOURS / 2.0
	var window_start = MOONRISE - half_overlap
	var window_end = MOONSET + half_overlap
	var t = time_of_day
	if t < window_end - 24.0:
		t += 24.0
	if t < window_start or t > window_end:
		return -1.0
	return clamp((t - MOONRISE) / (MOONSET - MOONRISE), 0.0, 1.0)

# public hook for gameplay systems (e.g. a hidden event) to check whether the
# player could currently see both the sun and moon in the sky at once.
func is_sun_moon_overlap() -> bool:
	return get_sun_progress() >= 0.0 and get_moon_progress() >= 0.0

func get_parallax_anchor_x() -> float:
	var player = get_node_or_null("../Player")
	if player:
		return player.global_position.x * PARALLAX_FACTOR
	return 0.0

func arc_position(progress: float, anchor_x: float) -> Vector2:
	var x = anchor_x + lerp(-ARC_SWING_X, ARC_SWING_X, progress)
	var y = lerp(SKY_HORIZON_Y, SKY_PEAK_Y, sin(progress * PI))
	return Vector2(x, y)

func update_visuals() -> void:
	var t = get_darkness_factor()
	var canvas_color = DAY_COLOR.lerp(NIGHT_COLOR, t)
	var modulate_node = get_node_or_null("../CanvasModulate")
	if modulate_node:
		modulate_node.color = canvas_color
	var sun = get_node_or_null("../SunIcon")
	var moon = get_node_or_null("../MoonIcon")
	var sun_progress = get_sun_progress()
	var moon_progress = get_moon_progress()
	var anchor_x = get_parallax_anchor_x()
	if sun:
		sun.visible = sun_progress >= 0.0
		if sun.visible:
			sun.position = arc_position(sun_progress, anchor_x)
	if moon:
		moon.visible = moon_progress >= 0.0
		if moon.visible:
			moon.position = arc_position(moon_progress, anchor_x)
			update_moon_true_colors(moon, canvas_color)
	update_clock_label()

# CanvasModulate darkens EVERYTHING in the scene uniformly, including the
# moon itself -- without this, the moon would get dimmed right along with
# the night sky and never actually look like it's emitting light. Here we
# counteract that: each frame, set the moon's rendered color to
# (true_color / canvas_color) so that after the engine's automatic
# CanvasModulate multiply, the moon still displays at true_color regardless
# of time of day. This only touches the moon's own nodes -- CanvasModulate
# itself, and therefore ground/enemy/platform visibility, is untouched.
func counter_color(true_color: Color, canvas_color: Color) -> Color:
	return Color(
		true_color.r / max(canvas_color.r, 0.05),
		true_color.g / max(canvas_color.g, 0.05),
		true_color.b / max(canvas_color.b, 0.05),
		true_color.a
	)

func update_moon_true_colors(moon_container: Node2D, canvas_color: Color) -> void:
	var body = moon_container.get_node_or_null("Body")
	var glow_outer = moon_container.get_node_or_null("GlowOuter")
	var glow_inner = moon_container.get_node_or_null("GlowInner")
	if body:
		body.color = counter_color(MOON_COLOR, canvas_color)
	if glow_outer:
		glow_outer.color = counter_color(Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, MOON_GLOW_OUTER_ALPHA), canvas_color)
	if glow_inner:
		glow_inner.color = counter_color(Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, MOON_GLOW_INNER_ALPHA), canvas_color)
	for i in range(SKY_GLOW_LAYERS.size()):
		var glow = moon_container.get_node_or_null("SkyGlow" + str(i + 1))
		if glow:
			var layer = SKY_GLOW_LAYERS[i]
			glow.color = counter_color(Color(SKY_GLOW_COLOR.r, SKY_GLOW_COLOR.g, SKY_GLOW_COLOR.b, layer.alpha), canvas_color)
	var craters_container = moon_container.get_node_or_null("Craters")
	if craters_container:
		for dot in craters_container.get_children():
			var true_crater_color = dot.get_meta("crater_color", MOON_CRATER_COLORS[0])
			dot.color = counter_color(Color(true_crater_color.r, true_crater_color.g, true_crater_color.b, MOON_CRATER_ALPHA), canvas_color)

func update_clock_label() -> void:
	var label = get_node_or_null("../CanvasLayer/ClockLabel")
	if label:
		var hours = int(time_of_day)
		var minutes = int((time_of_day - float(hours)) * 60.0)
		label.text = "%02d:%02d" % [hours, minutes]
