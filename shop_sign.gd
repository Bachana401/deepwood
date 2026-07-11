extends Node2D

const LETTERS = ["S", "H", "O", "P"]
const BULB_SPACING = 32.0
const BULB_RADIUS = 15.0
const SIGN_Y = -142.0
const FLICKER_LETTER_INDEX = 2
const ARROW_TOP_Y = -122.0
const ARROW_TIP_Y = -54.0
const ARROW_COLOR = Color(1.0, 0.82, 0.25, 0.9)

func _ready() -> void:
	var start_x = -(LETTERS.size() - 1) * BULB_SPACING / 2.0
	for i in range(LETTERS.size()):
		var bulb = make_bulb(LETTERS[i])
		bulb.position = Vector2(start_x + i * BULB_SPACING, SIGN_Y)
		add_child(bulb)
		if i == FLICKER_LETTER_INDEX:
			flicker_bulb(bulb)
		else:
			glow_bulb(bulb)

	flicker_bolt($BoltLeft)
	flicker_bolt($BoltRight)

	add_child(make_arrow(ARROW_TOP_Y, ARROW_TIP_Y, ARROW_COLOR))

func make_bulb(letter: String) -> Node2D:
	var bulb = Node2D.new()

	var glass = Polygon2D.new()
	glass.color = Color(1.0, 0.82, 0.25, 0.95)
	var points = PackedVector2Array()
	for i in range(12):
		var angle = i * TAU / 12.0
		points.append(Vector2(cos(angle), sin(angle)) * BULB_RADIUS)
	glass.polygon = points
	bulb.add_child(glass)

	var label = Label.new()
	label.text = letter
	label.size = Vector2(30, 30)
	label.position = Vector2(-15, -16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.88, 1))
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	bulb.add_child(label)

	return bulb

func glow_bulb(bulb: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(bulb, "scale", Vector2(1.06, 1.06), 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bulb, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func flicker_bulb(bulb: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(bulb, "modulate:a", 0.15, 0.06)
	tween.tween_property(bulb, "modulate:a", 1.0, 0.06)
	tween.tween_property(bulb, "modulate:a", 0.15, 0.05)
	tween.tween_property(bulb, "modulate:a", 1.0, 0.08)
	tween.tween_property(bulb, "modulate:a", 0.1, 0.3)
	tween.tween_interval(0.7)
	tween.tween_property(bulb, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.2)

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

func flicker_bolt(bolt: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(bolt, "modulate:a", randf_range(0.3, 0.55), randf_range(0.05, 0.12))
	tween.tween_property(bolt, "modulate:a", 1.0, randf_range(0.05, 0.1))
	tween.tween_interval(randf_range(0.3, 1.3))
