extends Node2D

# Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle.
#
# Two layers, both purely cosmetic (no gameplay state lives here):
#  1) AMBIENT LIFE that grows with the town. The more buildings stand, the more
#     festive the streets get -- flower boxes and lanterns at every finished
#     building, banner flags, and finally a
#     central fountain + maypole once the whole village is rebuilt. Birds and
#     butterflies drift about in numbers that scale with morale, so a happy
#     town literally teems with life.
#  2) A morale CELEBRATION. At ~10/10 the sky erupts with fireworks, confetti
#     rains over the square, and the villagers stop to clap, hop and cheer.
#
# Added to main.tscn (village only) at world origin, so its children sit in
# world space across the whole village.

var decor_layer: Node2D
var critter_layer: Node2D
var fx_layer: Node2D
var cheer_sfx: AudioStreamPlayer

var built_tier := -1
var celebrating := false
var was_at_peak := false        # tracks the rising edge of morale reaching 10/10
var celebration_time_left := 0.0
const CELEBRATION_DURATION := 20.0   # a celebration is an EVENT, not a forever-state
var firework_cd := 0.0
var confetti_cd := 0.0
var critter_cd := 2.0
var cheer_cd := 0.0

var village_lo := 0.0
var village_hi := 6000.0
var center_x := 3000.0
const GROUND_Y := -39.0

const LANTERN = Color(0.98, 0.82, 0.4)
const FLOWERS = [Color(0.9, 0.35, 0.4), Color(0.95, 0.75, 0.3), Color(0.7, 0.45, 0.85), Color(0.95, 0.5, 0.7)]
const BANNER = [Color(0.8, 0.25, 0.3), Color(0.25, 0.5, 0.8), Color(0.3, 0.65, 0.4), Color(0.85, 0.65, 0.25)]
const FIREWORK = [Color(1, 0.4, 0.4), Color(0.5, 0.8, 1), Color(1, 0.9, 0.4), Color(0.7, 1, 0.6), Color(1, 0.6, 0.9), Color(0.8, 0.7, 1)]

func _ready() -> void:
	decor_layer = Node2D.new()
	decor_layer.name = "Decor"
	add_child(decor_layer)
	critter_layer = Node2D.new()
	critter_layer.name = "Critters"
	add_child(critter_layer)
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	fx_layer.z_index = 90
	add_child(fx_layer)
	cheer_sfx = AudioStreamPlayer.new()
	cheer_sfx.stream = _synth_cheer()
	cheer_sfx.volume_db = -8.0
	add_child(cheer_sfx)
	call_deferred("_recompute_bounds")

func _recompute_bounds() -> void:
	var bs = get_tree().get_nodes_in_group("building")
	if bs.is_empty():
		return
	var lo = 1.0e9
	var hi = -1.0e9
	for b in bs:
		lo = minf(lo, b.global_position.x)
		hi = maxf(hi, b.global_position.x)
	village_lo = lo - 200.0
	village_hi = hi + 200.0
	center_x = (lo + hi) * 0.5

func _process(delta: float) -> void:
	_update_decor()
	_update_lanterns(delta)
	_update_celebration(delta)
	_update_critters(delta)

# --- 1a) Decorations that grow with the number of finished buildings ---
func operational_buildings() -> Array:
	var out: Array = []
	for b in get_tree().get_nodes_in_group("building"):
		if GameState.is_building_operational(b.building_name):
			out.append(b)
	out.sort_custom(func(a, c): return a.global_position.x < c.global_position.x)
	return out

func _update_decor() -> void:
	var ops = operational_buildings()
	if ops.size() == built_tier:
		return
	built_tier = ops.size()
	for c in decor_layer.get_children():
		c.queue_free()
	_lanterns.clear()   # the lamps we were flickering just got freed with the layer
	# per-building dressing
	for b in ops:
		var bx = b.global_position.x
		var half = b.eff_w() / 2.0
		# flower boxes flanking the door
		_flower_box(Vector2(bx - half * 0.5, GROUND_Y))
		_flower_box(Vector2(bx + half * 0.5, GROUND_Y))
		# a hanging lantern on a little post
		_lantern(Vector2(bx - half + 10.0, GROUND_Y))
		if built_tier >= 6:
			_lantern(Vector2(bx + half - 10.0, GROUND_Y))
	# (2026-07-16) The garlands strung between the buildings are gone -- dev call:
	# a flat green rope sagging across the street just read as a stray line over
	# the painted facades. The lanterns/flower boxes carry the festive read.
	# banner flags on poles down the main street
	if built_tier >= 8:
		for b in ops:
			_banner(Vector2(b.global_position.x, GROUND_Y))
	# the whole village rebuilt -> a proud central fountain + festival maypole
	if built_tier >= 13:
		_fountain(Vector2(center_x - 60.0, GROUND_Y))
		_maypole(Vector2(center_x + 60.0, GROUND_Y))

func _rect(parent: Node2D, pos: Vector2, size: Vector2, col: Color, zi := 0) -> ColorRect:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	r.z_index = zi
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _flower_box(base: Vector2) -> void:
	_rect(decor_layer, base + Vector2(-7, -8), Vector2(14, 8), Color(0.45, 0.3, 0.18))
	for i in range(3):
		var col = FLOWERS[randi() % FLOWERS.size()]
		_rect(decor_layer, base + Vector2(-6 + i * 5, -13), Vector2(4, 5), col)
		_rect(decor_layer, base + Vector2(-5 + i * 5, -14), Vector2(2, 2), col.lightened(0.3))

func _lantern(base: Vector2) -> void:
	_rect(decor_layer, base + Vector2(-1, -34), Vector2(2, 34), Color(0.4, 0.28, 0.16))  # post
	var lamp = _rect(decor_layer, base + Vector2(-4, -40), Vector2(8, 8), LANTERN)
	var glow = _rect(decor_layer, base + Vector2(-7, -43), Vector2(14, 14), Color(LANTERN.r, LANTERN.g, LANTERN.b, 0.22))
	glow.z_index = -1
	# A lamp with a dead-steady flame is just a yellow box. These burn: each one
	# gutters on its own rhythm, blazes after dark and dims to nothing by day
	# (GameState.torches_lit), so the street lights itself as the sun goes down.
	_lanterns.append({"lamp": lamp, "glow": glow, "phase": randf() * TAU, "speed": randf_range(3.2, 6.5)})

var _lanterns: Array = []

func _update_lanterns(delta: float) -> void:
	if _lanterns.is_empty():
		return
	_lantern_t += delta
	var night: bool = GameState.torches_lit()
	for l in _lanterns:
		var f: float = 0.5 + 0.5 * sin(_lantern_t * l["speed"] + l["phase"])
		f = f * 0.65 + 0.35 * (0.5 + 0.5 * sin(_lantern_t * l["speed"] * 2.3 + l["phase"] * 1.6))
		if night:
			l["lamp"].color = LANTERN.lerp(Color(1.0, 0.95, 0.7), f * 0.5)
			l["lamp"].color.a = 1.0
			l["glow"].color.a = 0.16 + 0.26 * f
		else:
			l["lamp"].color = LANTERN.darkened(0.45)
			l["glow"].color.a = 0.04

var _lantern_t := 0.0

func _banner(base: Vector2) -> void:
	_rect(decor_layer, base + Vector2(-1, -120), Vector2(2, 120), Color(0.5, 0.36, 0.2))   # pole
	var col = BANNER[randi() % BANNER.size()]
	var flag = _rect(decor_layer, base + Vector2(1, -118), Vector2(20, 12), col, 1)
	_rect(decor_layer, base + Vector2(1, -104), Vector2(20, 3), col.darkened(0.2), 1)
	flag.pivot_offset = Vector2(0, 6)

func _fountain(base: Vector2) -> void:
	_rect(decor_layer, base + Vector2(-26, -10), Vector2(52, 12), Color(0.55, 0.57, 0.6))   # basin
	_rect(decor_layer, base + Vector2(-22, -14), Vector2(44, 6), Color(0.35, 0.6, 0.8))     # water
	_rect(decor_layer, base + Vector2(-3, -34), Vector2(6, 22), Color(0.5, 0.52, 0.55))     # spout
	for i in range(6):
		var d = _rect(decor_layer, base + Vector2(-8 + i * 3, -40 + (i % 3) * 4), Vector2(2, 4), Color(0.6, 0.8, 0.95, 0.8))
		d.z_index = 3

func _maypole(base: Vector2) -> void:
	_rect(decor_layer, base + Vector2(-2, -130), Vector2(4, 130), Color(0.5, 0.36, 0.2))
	for i in range(5):
		var col = BANNER[i % BANNER.size()]
		var ribbon = Line2D.new()
		ribbon.points = PackedVector2Array([base + Vector2(0, -130), base + Vector2(-30 + i * 15, -70)])
		ribbon.width = 2.0
		ribbon.default_color = col
		ribbon.z_index = 2
		decor_layer.add_child(ribbon)

# --- 1b) Ambient critters, denser when morale is high ---
func _update_critters(delta: float) -> void:
	critter_cd -= delta
	if critter_cd > 0.0:
		return
	critter_cd = randf_range(1.4, 3.0)
	var morale = GameState.village_morale()
	var target = int(round(float(morale) / 100.0 * 7.0))
	if critter_layer.get_child_count() >= target:
		return
	if randf() < 0.6:
		_spawn_bird()
	else:
		_spawn_butterfly()

func _spawn_bird() -> void:
	var bird = Polygon2D.new()
	bird.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -3), Vector2(0, 0), Vector2(6, 0), Vector2(0, 0), Vector2(0, -3)])
	bird.color = Color(0.15, 0.15, 0.2)
	var left_to_right = randf() < 0.5
	var y = GROUND_Y - randf_range(200.0, 380.0)
	var x0 = village_lo if left_to_right else village_hi
	var x1 = village_hi if left_to_right else village_lo
	bird.position = Vector2(x0, y)
	bird.scale.x = 1.0 if left_to_right else -1.0
	critter_layer.add_child(bird)
	var dur = randf_range(7.0, 12.0)
	var tw = create_tween()
	tw.tween_method(func(p): bird.position = Vector2(lerpf(x0, x1, p), y + sin(p * TAU * 3.0) * 12.0), 0.0, 1.0, dur)
	tw.tween_callback(bird.queue_free)

func _spawn_butterfly() -> void:
	var bf = _rect(critter_layer, Vector2.ZERO, Vector2(4, 3), FLOWERS[randi() % FLOWERS.size()])
	var x = randf_range(village_lo + 100.0, village_hi - 100.0)
	var y = GROUND_Y - randf_range(20.0, 70.0)
	bf.position = Vector2(x, y)
	var tw = create_tween()
	for i in range(6):
		var nx = x + randf_range(-60.0, 60.0)
		var ny = GROUND_Y - randf_range(15.0, 80.0)
		tw.tween_property(bf, "position", Vector2(nx, ny), randf_range(0.6, 1.2)).set_trans(Tween.TRANS_SINE)
		x = nx
	tw.tween_callback(bf.queue_free)

# --- 2) The 10/10 celebration ---
func _update_celebration(delta: float) -> void:
	# A celebration is a bounded EVENT: it fires when morale first reaches a
	# perfect 10/10, runs for ~20s, then winds down and the villagers go back to
	# their lives -- even if the town stays at 10/10. It only fires again on a
	# fresh 10/10 (morale dipped and climbed back), so nobody parties forever.
	var at_peak = GameState.village_is_celebrating()
	if at_peak and not was_at_peak:
		celebrating = true
		celebration_time_left = CELEBRATION_DURATION
		_on_celebration_start()
	was_at_peak = at_peak
	if not celebrating:
		return
	celebration_time_left -= delta
	if celebration_time_left <= 0.0 or GameState.village_morale() < 90:
		celebrating = false   # party's over -- villagers finish their burst and resume
		return
	firework_cd -= delta
	if firework_cd <= 0.0:
		firework_cd = randf_range(0.5, 1.1)
		_spawn_firework()
	confetti_cd -= delta
	if confetti_cd <= 0.0:
		confetti_cd = 0.12
		_spawn_confetti()
	cheer_cd -= delta
	if cheer_cd <= 0.0:
		cheer_cd = randf_range(1.2, 2.4)
		_make_villagers_cheer()

func _on_celebration_start() -> void:
	if cheer_sfx and cheer_sfx.stream:
		cheer_sfx.play()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification("Deepwood is overjoyed! The whole village is celebrating!")

func _spawn_firework() -> void:
	var bx = randf_range(village_lo + 150.0, village_hi - 150.0)
	var burst_y = GROUND_Y - randf_range(280.0, 520.0)
	var col = FIREWORK[randi() % FIREWORK.size()]
	# a rising rocket that streaks up to the burst point
	var rocket = _rect(fx_layer, Vector2(bx, GROUND_Y - 40.0), Vector2(3, 8), col.lightened(0.3))
	var up = create_tween()
	up.tween_property(rocket, "position", Vector2(bx, burst_y), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_callback(func():
		rocket.queue_free()
		_burst(Vector2(bx, burst_y), col))

func _burst(center: Vector2, col: Color) -> void:
	# a ring of sparks flung outward, each fading + falling as it goes
	var count = 20
	for i in range(count):
		var ang = TAU * float(i) / float(count) + randf_range(-0.1, 0.1)
		var dir = Vector2(cos(ang), sin(ang))
		var spark = _rect(fx_layer, center, Vector2(3, 3), col)
		var reach = randf_range(50.0, 90.0)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", center + dir * reach + Vector2(0, 30.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate", Color(col.r, col.g, col.b, 0.0), 0.9)
		tw.chain().tween_callback(spark.queue_free)
	# a quick central flash
	var flash = _rect(fx_layer, center - Vector2(6, 6), Vector2(12, 12), Color(1, 1, 1, 0.9))
	var ft = create_tween()
	ft.tween_property(flash, "modulate", Color(1, 1, 1, 0.0), 0.25)
	ft.tween_callback(flash.queue_free)

func _spawn_confetti() -> void:
	for i in range(3):
		var x = randf_range(center_x - 260.0, center_x + 260.0)
		var top = GROUND_Y - randf_range(340.0, 420.0)
		var bit = _rect(fx_layer, Vector2(x, top), Vector2(3, 4), FIREWORK[randi() % FIREWORK.size()])
		var fall = randf_range(2.2, 3.6)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(bit, "position:y", GROUND_Y, fall).set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(bit, "position:x", x + randf_range(-40.0, 40.0), fall).set_trans(Tween.TRANS_SINE)
		tw.tween_property(bit, "rotation", randf_range(-6.0, 6.0), fall)
		tw.chain().tween_callback(bit.queue_free)

func _make_villagers_cheer() -> void:
	# only some villagers start a burst each cycle (the rest are mid-burst or on
	# cooldown), so participation rotates naturally instead of one big unison wave
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.has_method("cheer") and randf() < 0.4:
			npc.cheer(randf_range(2.5, 4.5))

# A short synthesized crowd cheer/applause: a swell of filtered noise.
func _synth_cheer() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.4
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in range(n):
		var t := float(i) / rate
		var env := clampf(t / 0.2, 0.0, 1.0) * exp(-maxf(0.0, t - 0.4) * 1.4)   # fast rise, slow fall
		var noise := randf() * 2.0 - 1.0
		last = last * 0.6 + noise * 0.4                                          # low-passed = applause hiss
		var v := last * env * 0.7
		v = clampf(v, -1.0, 1.0)
		var s16 := int(v * 26000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
