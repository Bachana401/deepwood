extends VBoxContainer

const DISPLAY_DURATION = 2.2
const FADE_DURATION = 0.5

func show_notification(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween = create_tween()
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(label.queue_free)
