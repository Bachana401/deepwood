extends Node2D

const GRASS_COLORS = [
	Color(0.32, 0.78, 0.28),
	Color(0.3, 0.72, 0.32),
	Color(0.34, 0.76, 0.26),
	Color(0.28, 0.68, 0.24),
]

const GROUND_SPAN_START = -395.0
const GROUND_SPAN_END = 4470.0
const GROUND_Y = -39.0
const TUFT_COUNT = 32

const PLATFORM_TUFTS = [
	{"pos": Vector2(1470, -195), "count": 2},
	{"pos": Vector2(1900, -195), "count": 2},
	{"pos": Vector2(2370, -235), "count": 2},
	{"pos": Vector2(2930, -215), "count": 2},
]

# natural jagged mountain silhouettes -- deliberately sparse so they read as
# landmarks rather than a wall-to-wall backdrop. Two big ones sit near player
# spawn (x=-300) with different shapes, two more big ones are scattered
# further along the course, and two SMALL ones (sized like the very first
# version of this system) fill the remaining gaps. Mixed palette: some
# green-tinted, some the original purple-blue "distant range" tone.
const MOUNTAIN_Y = 40.0
const MOUNTAIN_ZONES = [
	{"x": -480.0, "width": 1240.0, "height": 855.0, "peaks": 3, "color": Color(0.36, 0.46, 0.38, 1)},
	{"x": -140.0, "width": 855.0, "height": 560.0, "peaks": 2, "color": Color(0.5, 0.47, 0.63, 1)},
	{"x": 1700.0, "width": 1395.0, "height": 900.0, "peaks": 4, "color": Color(0.44, 0.41, 0.58, 1)},
	{"x": 3250.0, "width": 1080.0, "height": 720.0, "peaks": 3, "color": Color(0.4, 0.5, 0.42, 1)},
	{"x": 800.0, "width": 480.0, "height": 310.0, "peaks": 2, "color": Color(0.48, 0.45, 0.61, 1)},
	{"x": 4000.0, "width": 420.0, "height": 280.0, "peaks": 3, "color": Color(0.38, 0.48, 0.4, 1)},
]

const CLOUD_COUNT = 40
const CLOUD_SPAN_START = -900.0
const CLOUD_SPAN_END = 5000.0
const CLOUD_Y_MIN = -720.0
const CLOUD_Y_MAX = -470.0
const CLOUD_MIN_SCALE = 0.6
const CLOUD_MAX_SCALE = 2.4
const CLOUD_MIN_SPEED = 3.0
const CLOUD_MAX_SPEED = 10.0
const CLOUD_COLOR = Color(0.97, 0.97, 1.0, 1.0)
const CLOUD_Z_INDEX = -25

const MUSIC_LOOP_SAMPLES = 441000

const TRAP_SCENE = preload("res://trap.tscn")
const TRAP_COUNT = 25
const TRAP_SPAN_START = -670.0
const TRAP_SPAN_END = 4470.0
const TRAP_Y = -39.0
const TRAP_JITTER_FRACTION = 0.3
const TRAP_SAFE_ZONE_MIN = -365.0
const TRAP_SAFE_ZONE_MAX = -85.0
const TRAP_PLATFORM_EDGE_MARGIN = 28.0

const TRAP_PLATFORM_ZONES = [
	{"x_min": 48.0, "x_max": 248.0, "y": -128.0, "count": 1},
	{"x_min": 287.0, "x_max": 887.0, "y": -207.0, "count": 1},
	{"x_min": 1016.5, "x_max": 1305.0, "y": -160.5, "count": 1},
	{"x_min": 539.0, "x_max": 637.0, "y": -350.5, "count": 1},
	{"x_min": 1395.0, "x_max": 1545.0, "y": -195.0, "count": 1},
	{"x_min": 1610.0, "x_max": 1750.0, "y": -275.0, "count": 1},
	{"x_min": 1820.0, "x_max": 1980.0, "y": -195.0, "count": 1},
	{"x_min": 2055.0, "x_max": 2185.0, "y": -345.0, "count": 1},
	{"x_min": 2295.0, "x_max": 2445.0, "y": -235.0, "count": 1},
	{"x_min": 2580.0, "x_max": 2720.0, "y": -375.0, "count": 1},
	{"x_min": 2850.0, "x_max": 3010.0, "y": -215.0, "count": 1},
	{"x_min": 3145.0, "x_max": 3295.0, "y": -305.0, "count": 1},
]

var music: AudioStreamWAV = preload("res://audio/ambient_music.wav")

func _ready() -> void:
	generate_mountains()
	generate_grass()
	generate_traps()
	generate_platform_traps()
	generate_clouds()
	start_music()
	if GameState.pending_load:
		apply_save_data()

func _process(delta: float) -> void:
	for cloud in $Clouds.get_children():
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x > CLOUD_SPAN_END:
			cloud.position.x = CLOUD_SPAN_START

func start_music() -> void:
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = MUSIC_LOOP_SAMPLES
	$MusicPlayer.stream = music
	$MusicPlayer.play()

func apply_save_data() -> void:
	var data = GameState.load_game()
	if data.is_empty():
		return
	var player = $Player
	player.currency = data.get("currency", player.currency)
	player.global_position = Vector2(data.get("position_x", player.global_position.x), data.get("position_y", player.global_position.y))
	player.has_dash = data.get("has_dash", player.has_dash)
	player.has_double_jump = data.get("has_double_jump", player.has_double_jump)
	player.health = data.get("health", player.health)
	var saved_weapons = data.get("owned_weapons", null)
	if saved_weapons is Dictionary:
		for w in saved_weapons.keys():
			player.owned_weapons[w] = saved_weapons[w]
	var eq = data.get("equipped_weapon", null)
	if eq != null and player.owned_weapons.get(eq, false):
		player.equip_weapon(eq)
	player.update_currency_display()
	player.update_health_display()

func generate_grass() -> void:
	var spacing = (GROUND_SPAN_END - GROUND_SPAN_START) / float(TUFT_COUNT)
	for i in range(TUFT_COUNT):
		var x = GROUND_SPAN_START + i * spacing + randf_range(-spacing * 0.35, spacing * 0.35)
		spawn_tuft(Vector2(x, GROUND_Y))

	for group in PLATFORM_TUFTS:
		for i in range(group.count):
			var offset_x = randf_range(-35.0, 35.0)
			spawn_tuft(group.pos + Vector2(offset_x, 0))

func generate_traps() -> void:
	var spacing = (TRAP_SPAN_END - TRAP_SPAN_START) / float(TRAP_COUNT)
	for i in range(TRAP_COUNT):
		var x = TRAP_SPAN_START + i * spacing + randf_range(-spacing * TRAP_JITTER_FRACTION, spacing * TRAP_JITTER_FRACTION)
		if x > TRAP_SAFE_ZONE_MIN and x < TRAP_SAFE_ZONE_MAX:
			x = TRAP_SAFE_ZONE_MIN if (x - TRAP_SAFE_ZONE_MIN) < (TRAP_SAFE_ZONE_MAX - x) else TRAP_SAFE_ZONE_MAX
		place_trap(x, TRAP_Y)

func generate_platform_traps() -> void:
	for zone in TRAP_PLATFORM_ZONES:
		var usable_min = zone.x_min + TRAP_PLATFORM_EDGE_MARGIN
		var usable_max = zone.x_max - TRAP_PLATFORM_EDGE_MARGIN
		if usable_max <= usable_min:
			usable_min = zone.x_min
			usable_max = zone.x_max
		var count = zone.count
		if count == 1:
			var x = (usable_min + usable_max) / 2.0 + randf_range(-10.0, 10.0)
			place_trap(x, zone.y)
		else:
			var segment = (usable_max - usable_min) / float(count)
			for i in range(count):
				var seg_start = usable_min + i * segment
				var x = seg_start + segment * 0.5 + randf_range(-segment * 0.2, segment * 0.2)
				place_trap(x, zone.y)

func place_trap(x: float, y: float) -> void:
	var trap = TRAP_SCENE.instantiate()
	trap.position = Vector2(x, y)
	$Traps.add_child(trap)

func generate_mountains() -> void:
	for zone in MOUNTAIN_ZONES:
		var mountain = Polygon2D.new()
		mountain.position = Vector2(zone.x, MOUNTAIN_Y)
		mountain.color = zone.color
		mountain.polygon = generate_mountain_shape(zone.width, zone.height, zone.peaks)
		$Background/Mountains.add_child(mountain)

# a jagged ridge instead of a flat triangle or pure per-point noise: a few
# distinct "peaks" at random positions/heights shape the overall silhouette
# (so it reads as real summits, not random zigzag), a sine envelope tapers
# the whole thing to ground level at both edges, and fine jitter on top adds
# rocky texture without breaking the coherent shape.
func generate_mountain_shape(width: float, height: float, peak_count: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(Vector2(-width / 2.0, 0.0))
	var segments = max(peak_count * 6, 18)
	var peak_positions = []
	var peak_heights = []
	for p in range(peak_count):
		peak_positions.append(randf_range(0.15, 0.85))
		peak_heights.append(randf_range(0.65, 1.0))
	for i in range(1, segments):
		var t = float(i) / float(segments)
		var x = -width / 2.0 + t * width
		var peak_influence = 0.0
		for p in range(peak_count):
			var dist = absf(t - peak_positions[p])
			var influence = max(0.0, 1.0 - dist * 2.2)
			peak_influence = max(peak_influence, influence * peak_heights[p])
		var envelope = sin(t * PI)
		var fine_jitter = 1.0 + randf_range(-0.08, 0.08)
		var y = -height * envelope * (0.5 + 0.5 * peak_influence) * fine_jitter
		points.append(Vector2(x, y))
	points.append(Vector2(width / 2.0, 0.0))
	return points

func generate_clouds() -> void:
	for i in range(CLOUD_COUNT):
		var cloud = Polygon2D.new()
		var x = randf_range(CLOUD_SPAN_START, CLOUD_SPAN_END)
		var y = randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX)
		cloud.position = Vector2(x, y)
		cloud.z_index = CLOUD_Z_INDEX
		var scale_factor = randf_range(CLOUD_MIN_SCALE, CLOUD_MAX_SCALE)
		cloud.polygon = generate_cloud_shape(scale_factor)
		var alpha = randf_range(0.65, 0.95)
		cloud.color = Color(CLOUD_COLOR.r, CLOUD_COLOR.g, CLOUD_COLOR.b, alpha)
		cloud.set_meta("speed", randf_range(CLOUD_MIN_SPEED, CLOUD_MAX_SPEED))
		$Clouds.add_child(cloud)

func generate_cloud_shape(scale_factor: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var segments = randi_range(8, 14)
	var width = randf_range(30.0, 70.0) * scale_factor
	var height = width * randf_range(0.35, 0.6)
	var bumpiness = randf_range(0.15, 0.35)
	for i in range(segments):
		var angle = i * TAU / float(segments)
		var variance = 1.0 + randf_range(-bumpiness, bumpiness)
		var x = cos(angle) * width * variance
		var y = sin(angle) * height * variance
		points.append(Vector2(x, y))
	return points

func spawn_tuft(pos: Vector2) -> void:
	var tuft = Polygon2D.new()
	tuft.position = pos
	tuft.color = GRASS_COLORS[randi() % GRASS_COLORS.size()]
	var h = randf_range(9.0, 15.0)
	var w = randf_range(5.0, 8.0)
	tuft.polygon = PackedVector2Array([
		Vector2(-w, 0), Vector2(-w * 0.65, -h * 0.65), Vector2(-w * 0.3, -h * 0.3),
		Vector2(0, -h), Vector2(w * 0.3, -h * 0.3), Vector2(w * 0.65, -h * 0.65), Vector2(w, 0)
	])
	$Decorations.add_child(tuft)
