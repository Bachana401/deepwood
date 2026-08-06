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
# Widened with the arc lowering below: the sun used to cross only ~270 screen px,
# which read as a lamp nudging sideways rather than a day passing.
const ARC_SWING_X = 700.0
# LOWERED so noon is actually in frame. Measured constraints: the view top sits near
# world y -630, the mountain peaks top out near -380, and the HUD banner covers the
# top ~233 world px -- so anything above about -590 is behind the banner at screen
# centre. That leaves a genuinely narrow usable band, which is why the arc had to
# come DOWN rather than just be re-centred. Noon at -760 was above the frame even at
# world origin, so the sun was off screen for the middle 70% of every day.
const SKY_HORIZON_Y = -430.0
const SKY_PEAK_Y = -600.0

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

# THE SKY IS AT INFINITY (dev ruling 2026-08-06). It does not slide against the
# mountains; parallax belongs to the ridgelines, which already have it.
#
# This used to return player.x * PARALLAX_FACTOR (0.12) while the camera sat at
# player.x, so the sun fell behind by 88% of however far the player had walked.
# Scenes measured the result rather than estimating it: about 3,000 screen pixels
# off the left edge at the west gate, and 7,250 at the Bar -- six screen-widths.
# It scales linearly with x, so it got worse the further east the town grew.
#
# NOT a smaller factor. Any value below 1.0 leaves a drift that grows without
# bound, so 0.5 or 0.8 only moves the failure further out instead of removing it,
# and the village row already runs past 20,000.
#
# Net effect of the old behaviour: nobody had ever seen the sun or moon from their
# own town, at any hour. The day/night cycle drives sieges, the lantern night and
# the CanvasModulate that governs how the whole world reads -- and the player could
# only tell the time from a clock string in the HUD.
func get_parallax_anchor_x() -> float:
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null:
		return cam.get_screen_center_position().x
	var player = get_node_or_null("../Player")
	if player:
		return player.global_position.x
	return 0.0

func arc_position(progress: float, anchor_x: float) -> Vector2:
	var x = anchor_x + lerp(-ARC_SWING_X, ARC_SWING_X, progress)
	var y = lerp(SKY_HORIZON_Y, SKY_PEAK_Y, sin(progress * PI))
	return Vector2(x, y)

func update_visuals() -> void:
	var t = get_darkness_factor()
	var canvas_color = DAY_COLOR.lerp(NIGHT_COLOR, t)
	# ================== THE ECLIPSE (dev design 2026-08-06) ==================
	# The reference the dev gave is a RING, not a red filter: a world gone to black
	# silhouette lit by one hot red source. So the global tint goes deep red-DARK
	# (everything reads as outline) rather than red-bright, and the moon rides onto
	# the sun so what survives is a burning corona around a black disc.
	var ecl: float = GameState.eclipse_progress()
	if ecl > 0.0:
		canvas_color = canvas_color.lerp(
			ECLIPSE_TINT.lerp(ECLIPSE_TINT_TOTAL, ecl), clampf(ecl * 1.15, 0.0, 1.0))
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
			sun.position = _eclipse_sky_pos(arc_position(sun_progress, anchor_x), ecl)
			update_sun_eclipse(sun, ecl, canvas_color)
	if moon:
		moon.visible = moon_progress >= 0.0 or ecl > 0.0
		if moon.visible:
			# during totality the moon RIDES the sun -- that is the whole image
			if ecl > 0.0 and sun_progress >= 0.0:
				var own := arc_position(maxf(moon_progress, 0.0), anchor_x)
				moon.position = _eclipse_sky_pos(
					own.lerp(arc_position(sun_progress, anchor_x), clampf(ecl * 1.4, 0.0, 1.0)), ecl)
			else:
				moon.position = arc_position(moon_progress, anchor_x)
			update_moon_true_colors(moon, canvas_color, ecl)
	_update_eclipse_ring(ecl, sun_progress, anchor_x)

# BRING THE ECLIPSE DOWN WHERE IT CAN BE SEEN.
#
# The ordinary arc peaks at SKY_PEAK_Y (-760) and the camera's view top sits near
# -690 at the standard zoom -- so the midday sun is normally OFF SCREEN, about
# seventy pixels above the frame. Nobody ever noticed, because on an ordinary day
# there is nothing up there worth looking at and the sun is visible at dawn and
# dusk when it rides the horizon.
#
# The eclipse peaks at noon. So the one moment the entire feature exists for -- the
# black disc inside the burning ring -- was drawn just past the top edge of the
# screen and could never be seen at all. Static analysis and the test suite both
# called this feature finished; only a screenshot found it.
#
# Rather than lower the arc for every day of the game (which would change a sky the
# dev has already approved), the pair is pulled down toward a visible band ONLY
# while an eclipse is running, in proportion to how far along it is. The band is
# measured off the live camera so it holds at any zoom or resolution.
# ======================= THE RING (dev design 2026-08-06) =======================
# The dev's reference is a world in black silhouette lit by ONE HOT RED RING. The
# silhouette half is easy -- that is just the CanvasModulate going deep red-dark.
# The ring is not, and the reason is worth writing down because it is not obvious:
#
#   CanvasModulate MULTIPLIES. Nothing on that canvas can ever be brighter than the
#   modulate colour itself. With the eclipse tint at (0.20, 0.035, 0.045), a sun
#   painted pure white still renders at (0.20, 0.035, 0.045) -- and the sky bands
#   behind it render at (0.10, 0.02, 0.04). So the "blazing corona" came out about
#   twice as bright as the sky it sat in: a faint smudge, invisible in play. The
#   counter_color trick the moon uses works at night only because NIGHT_COLOR is
#   comparatively light; at eclipse darkness it clamps and dies.
#
# So the ring is drawn on its OWN CanvasLayer, which CanvasModulate does not touch,
# in screen space at the sun's projected position. Fully additive: nothing in
# main.tscn moves, the ordinary sky is untouched, and at ecl = 0 the whole overlay
# is transparent and costs nothing.
# SIZE IS THE WHOLE POINT, IN BOTH DIRECTIONS. The first version drew a ring that measured
# about seven pixels across on a 1152-wide frame -- pixel-sampling proved it was
# there and burning at (1.0, 0.40, 0.22) against a (0.11, 0.03, 0.04) sky, roughly
# nine times the surrounding brightness, and it still read as nothing at all. An
# eclipse has to DOMINATE the sky it ruins. The bright band is deliberately wide
# (core 1.0 -> hot edge 1.34) rather than a hairline, so it reads as a burning
# ring and not as a bright outline.
# More layers than the look strictly needs: with only four, the additive discs
# read as hard concentric bands -- a dartboard rather than a corona. Eight closely
# spaced steps let the falloff blend into something that looks like light.
const RING_LAYERS = [
	# radius scale, colour, alpha at totality  -- outermost first
	[3.40, Color(1.0, 0.13, 0.05), 0.10],
	[2.90, Color(1.0, 0.15, 0.06), 0.12],
	[2.45, Color(1.0, 0.18, 0.07), 0.15],
	[2.08, Color(1.0, 0.22, 0.08), 0.19],
	[1.78, Color(1.0, 0.28, 0.10), 0.25],
	[1.55, Color(1.0, 0.38, 0.14), 0.34],
	[1.40, Color(1.0, 0.52, 0.22), 0.55],
	[1.28, Color(1.0, 0.74, 0.40), 1.0],    # the hot inner edge
]
const RING_CORE_RADIUS = 34.0
# high in the frame, where a sun belongs -- and clear of the dialogue box along the
# bottom and the notification stack in the top right
const RING_SCREEN_Y = 0.22
var _ring_layer: CanvasLayer = null
var _ring_parts: Array = []
var _ring_core: Polygon2D = null

func _build_eclipse_ring() -> void:
	_ring_layer = CanvasLayer.new()
	# Layer 1, NOT 0. A CanvasLayer at 0 ties with the root viewport's own canvas
	# and loses -- the ring was being drawn behind the whole world, which looks
	# identical to it not being drawn at all. At 1 it clears the world, and because
	# same-layer CanvasLayers draw in tree order and DayNightCycle sits well above
	# every UI layer in main.tscn, it still passes safely UNDER the HUD, the
	# dialogue box and the menus.
	_ring_layer.layer = 1
	add_child(_ring_layer)
	for spec in RING_LAYERS:
		var p := Polygon2D.new()
		build_circle(p, RING_CORE_RADIUS * float(spec[0]), Color(1, 1, 1, 0))
		p.material = make_additive_material()
		_ring_layer.add_child(p)
		_ring_parts.append(p)
	# the moon: the hole in the middle. NOT additive -- it is the absence of light.
	_ring_core = Polygon2D.new()
	build_circle(_ring_core, RING_CORE_RADIUS, Color(0.03, 0.015, 0.02, 0.0))
	_ring_layer.add_child(_ring_core)

func _update_eclipse_ring(ecl: float, sun_progress: float, anchor_x: float) -> void:
	if ecl <= 0.0 or sun_progress < 0.0:
		if _ring_layer != null:
			_ring_layer.visible = false
		return
	if _ring_layer == null:
		_build_eclipse_ring()
	# THE RING SITS ON THE REAL SUN.
	#
	# It did not always. When the sky still lagged the camera by 88% of however far
	# the player had walked, the sun was thousands of pixels off screen out at the
	# village -- the one place this event exists for -- so the ring had to be anchored
	# to the screen instead, and simply drawn where a sun ought to be.
	#
	# Now that the sky is camera-anchored and the arc has been lowered into frame, the
	# sun is reliably on screen at every daylight hour, so the ring can go back to
	# where it belongs: projected from the sun's own world position, dead concentric
	# with it. Before this, with both fixes in, the two were drawn a hundred pixels
	# apart and you could see the true sun peeking out above the corona.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cam0 := get_viewport().get_camera_2d() if get_viewport() != null else null
	var screen := Vector2(vp.x * 0.5, vp.y * RING_SCREEN_Y)
	if cam0 != null:
		var world := _eclipse_sky_pos(arc_position(sun_progress, anchor_x), ecl)
		screen = (world - cam0.get_screen_center_position()) * cam0.zoom + vp * 0.5
	_ring_layer.visible = true
	# scale off the viewport, not the camera zoom: the ring is a fixed share of the
	# screen so it reads the same on a phone and on a desktop window
	var rs: float = clampf(vp.y / 648.0, 0.55, 2.0)
	for i in range(_ring_parts.size()):
		var part: Polygon2D = _ring_parts[i]
		var spec: Array = RING_LAYERS[i]
		var col: Color = spec[1]
		part.position = screen
		part.scale = Vector2(rs, rs)
		# the corona SWELLS as the moon closes: at first contact it is barely a
		# rumour, at totality it is the only light left in the world
		part.color = Color(col.r, col.g, col.b, float(spec[2]) * pow(ecl, 1.4))
	_ring_core.position = screen
	_ring_core.scale = Vector2(rs, rs)
	_ring_core.color = Color(0.03, 0.015, 0.02, clampf(ecl * 1.6, 0.0, 1.0))

# Sized off the CORONA, not the sun: the outer ring reaches RING_CORE_RADIUS x the
# widest RING_LAYERS scale (34 x 3.4 = 116 screen px), so the pair has to hang at
# least that far below the top edge or the ring is cropped at totality. Expressed in
# WORLD units, hence the divide by zoom at the call site.
const ECLIPSE_VIEW_MARGIN = 240.0     # how far below the view's top edge to hang it
const ECLIPSE_SKY_Y_FALLBACK = -450.0 # if there is no camera to measure against

func _eclipse_sky_pos(pos: Vector2, ecl: float) -> Vector2:
	# STILL NEEDED, for a different reason than before. The arc has since been lowered
	# so the ordinary sun is in frame all day -- but the eclipse CORONA is far bigger
	# than the sun disc, and at noon a sun sitting comfortably in frame still had the
	# top of its ring cut off by the edge of the screen. The margin below is sized off
	# the corona's outer radius rather than the sun's, so the whole thing fits.
	if ecl <= 0.0:
		return pos
	var target_y := ECLIPSE_SKY_Y_FALLBACK
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null and cam.zoom.y > 0.0:
		var view_h: float = get_viewport().get_visible_rect().size.y / cam.zoom.y
		target_y = cam.get_screen_center_position().y - view_h * 0.5 + ECLIPSE_VIEW_MARGIN
	# maxf, not minf: y runs NEGATIVE upward, so the larger value is the lower one.
	# This only ever hauls the pair DOWN into view when the arc has carried it above
	# the frame -- at dawn and dusk it already hangs low and is left exactly alone.
	return Vector2(pos.x, lerpf(pos.y, maxf(pos.y, target_y), clampf(ecl, 0.0, 1.0)))
	update_clock_label()

# The sky the dev asked for: black silhouettes, one red ring. The tint goes deep
# red-dark rather than "red" so the world reads as outline lit BY the eclipse,
# instead of a red sheet laid over a normal day.
const ECLIPSE_TINT = Color(0.34, 0.10, 0.10, 1.0)
const ECLIPSE_TINT_TOTAL = Color(0.20, 0.035, 0.045, 1.0)
const ECLIPSE_CORONA = Color(1.0, 0.20, 0.10, 1.0)
const ECLIPSE_CORONA_HOT = Color(1.0, 0.55, 0.22, 1.0)

# Bleed the sun from its daylight gold to a burning red corona as the moon takes
# it. Counter-coloured like the moon, so the ring stays BRIGHT while everything
# around it goes to black -- otherwise CanvasModulate would swallow it too.
func update_sun_eclipse(sun_container: Node2D, ecl: float, canvas_color: Color) -> void:
	var core := SUN_COLOR.lerp(ECLIPSE_CORONA, ecl)
	var halo := SUN_COLOR.lerp(ECLIPSE_CORONA_HOT, ecl)
	# NOTE the node is "Disc", not "Body" -- the moon uses Body, the sun does not.
	var disc = sun_container.get_node_or_null("Disc")
	if disc:
		disc.color = counter_color(core, canvas_color) if ecl > 0.0 else SUN_COLOR
	var highlight = sun_container.get_node_or_null("Highlight")
	if highlight:
		highlight.color = counter_color(Color(halo.r, halo.g, halo.b, SUN_HIGHLIGHT_COLOR.a), canvas_color) \
			if ecl > 0.0 else SUN_HIGHLIGHT_COLOR
	for nm in ["GlowOuter", "GlowInner"]:
		var g = sun_container.get_node_or_null(nm)
		if g == null:
			continue
		var a: float = SUN_GLOW_OUTER_ALPHA if nm == "GlowOuter" else SUN_GLOW_INNER_ALPHA
		# the corona FLARES as totality closes: this is the ring in the picture
		var lit := Color(halo.r, halo.g, halo.b, a + a * 2.2 * ecl)
		g.color = counter_color(lit, canvas_color) if ecl > 0.0 \
			else Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, a)
	var rays = sun_container.get_node_or_null("Rays")
	if rays:
		for r in rays.get_children():
			var ra := SUN_RAY_ALPHA * (1.0 + 2.0 * ecl)
			r.color = counter_color(Color(halo.r, halo.g, halo.b, ra), canvas_color) if ecl > 0.0 \
				else Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, SUN_RAY_ALPHA)

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

func update_moon_true_colors(moon_container: Node2D, canvas_color: Color, ecl := 0.0) -> void:
	var body = moon_container.get_node_or_null("Body")
	var glow_outer = moon_container.get_node_or_null("GlowOuter")
	var glow_inner = moon_container.get_node_or_null("GlowInner")
	# THE MOON GOES BLACK. counter_color divides by the canvas tint, so under the
	# near-black eclipse sky the ordinary path would render a blinding white moon --
	# the exact opposite of the image. During an eclipse the moon is not a light
	# source, it is the hole: drop it to a flat dark disc and let the sun's corona
	# behind it be the only bright thing on screen.
	if ecl > 0.0:
		if body:
			body.color = Color(0.05, 0.02, 0.03, 1.0).lerp(counter_color(MOON_COLOR, canvas_color), 1.0 - ecl)
		for nm in ["GlowOuter", "GlowInner"]:
			var g = moon_container.get_node_or_null(nm)
			if g:
				g.color = Color(g.color.r, g.color.g, g.color.b, g.color.a * (1.0 - ecl))
		for i in range(SKY_GLOW_LAYERS.size()):
			var sg = moon_container.get_node_or_null("SkyGlow" + str(i + 1))
			if sg:
				sg.color = Color(sg.color.r, sg.color.g, sg.color.b, sg.color.a * (1.0 - ecl))
		var cr = moon_container.get_node_or_null("Craters")
		if cr:
			for dot in cr.get_children():
				dot.color = Color(0.05, 0.02, 0.03, 1.0)
		return
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
