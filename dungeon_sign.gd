extends Node2D

const ARROW_TOP_Y = -122.0
const ARROW_TIP_Y = -54.0
const ARROW_COLOR = Color(0.55, 0.05, 0.05, 0.95)

func _ready() -> void:
	add_child(make_arrow(ARROW_TOP_Y, ARROW_TIP_Y, ARROW_COLOR))
	var label = $Label
	var glow = $GlowRect

	var heartbeat = create_tween()
	heartbeat.set_loops()
	heartbeat.tween_property(label, "scale", Vector2(1.07, 1.07), 0.12).set_trans(Tween.TRANS_SINE)
	heartbeat.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	heartbeat.tween_property(label, "scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_SINE)
	heartbeat.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
	heartbeat.tween_interval(0.9)

	var glow_pulse = create_tween()
	glow_pulse.set_loops()
	glow_pulse.tween_property(glow, "modulate:a", 0.75, 0.5).set_trans(Tween.TRANS_SINE)
	glow_pulse.tween_property(glow, "modulate:a", 0.15, 0.7).set_trans(Tween.TRANS_SINE)

	flicker_spike($SpikeLeft)
	flicker_spike($SpikeRight)

func make_arrow(top_y: float, tip_y: float, color: Color) -> Node2D:
	var arrow = Node2D.new()

	var shaft = ColorRect.new()
	shaft.color = color
	shaft.size = Vector2(4, tip_y - top_y - 14.0)
	shaft.position = Vector2(-2, top_y)
	arrow.add_child(shaft)

	var head = Polygon2D.new()
	head.color = color
	head.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(0, 14)])
	head.position = Vector2(0, tip_y - 14.0)
	arrow.add_child(head)

	return arrow

func flicker_spike(spike: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(spike, "modulate:a", randf_range(0.35, 0.6), randf_range(0.06, 0.15))
	tween.tween_property(spike, "modulate:a", 1.0, randf_range(0.06, 0.12))
	tween.tween_interval(randf_range(0.4, 1.4))
