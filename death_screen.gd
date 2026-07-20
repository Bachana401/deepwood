extends CanvasLayer

func _ready() -> void:
	visible = false

# The cost of dying, said ON the black screen itself -- the toast version
# played behind this overlay and was never seen (presentation sweep).
var toll_label: Label = null

func _ensure_toll_label() -> void:
	if toll_label != null:
		return
	toll_label = Label.new()
	toll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toll_label.anchors_preset = Control.PRESET_CENTER_TOP
	toll_label.position = Vector2(-380.0, 400.0)
	toll_label.size = Vector2(760.0, 60.0)
	toll_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	toll_label.add_theme_font_size_override("font_size", 16)
	toll_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5))
	add_child(toll_label)

func run_death_sequence(seconds: float) -> void:
	_ensure_toll_label()
	var lines := ["Your dropped gold lies where you fell."]
	if GameState.last_death_toll != "":
		lines.push_front("💀 " + GameState.last_death_toll)
	toll_label.text = "\n".join(lines)
	visible = true
	var remaining = int(round(seconds))
	while remaining > 0:
		$CountdownLabel.text = str(remaining)
		pop_countdown()
		await get_tree().create_timer(1.0).timeout
		remaining -= 1
	visible = false

func pop_countdown() -> void:
	$CountdownLabel.scale = Vector2(1.3, 1.3)
	var tween = create_tween()
	tween.tween_property($CountdownLabel, "scale", Vector2.ONE, 0.25)
