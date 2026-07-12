extends CanvasLayer

func _ready() -> void:
	visible = false

func run_death_sequence(seconds: float) -> void:
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
