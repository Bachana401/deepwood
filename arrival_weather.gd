extends CanvasLayer

# THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for
# a night arrival with rain and drama; what shipped was 8 AM sunshine over a
# SHOP sign. A new run now opens at 22:00 under this storm: slanted rain and
# distant lightning riding the whole arrival -- the fight, the trap, the
# reveal, the oath -- then the sky clears as the oath ends and dawn comes.
# Procedural only (art freeze): particles, flashes, low thunder.

var rain: CPUParticles2D = null
var flash: ColorRect = null
var _bolt_timer := 0.0
var _fading := false

func _ready() -> void:
	layer = 30                       # over the world, under dialogue/HUD text
	rain = CPUParticles2D.new()
	rain.amount = 260
	rain.lifetime = 0.9
	rain.preprocess = 1.0            # already raining on frame one
	rain.position = Vector2(640, -40)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(820, 10)
	rain.direction = Vector2(-0.25, 1.0)
	rain.spread = 4.0
	rain.gravity = Vector2(0, 980)
	rain.initial_velocity_min = 700.0
	rain.initial_velocity_max = 900.0
	rain.scale_amount_min = 0.6
	rain.scale_amount_max = 1.1
	rain.color = Color(0.65, 0.72, 0.9, 0.5)
	add_child(rain)
	flash = ColorRect.new()
	flash.color = Color(0.95, 0.97, 1.0, 0.0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_bolt_timer = randf_range(3.0, 6.0)

func _process(delta: float) -> void:
	# the storm breaks with the oath: once the arrival is done, fade and go
	if not _fading and GameState.seen_arrival_battle:
		_fading = true
		var tw := create_tween()
		tw.tween_interval(14.0)              # rain through the oath's last words
		tw.tween_property(rain, "modulate:a", 0.0, 10.0)
		tw.tween_callback(queue_free)
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = randf_range(6.0, 14.0)
		_strike()

func _strike() -> void:
	GameState.play_sfx(GameState.SFX_THUD, 0.45)
	var tw := create_tween()
	flash.color.a = 0.32
	tw.tween_property(flash, "color:a", 0.0, 0.18)
	tw.tween_property(flash, "color:a", 0.2, 0.06)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
