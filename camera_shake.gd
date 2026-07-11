extends Camera2D

var shake_strength = 0.0
var shake_timer = 0.0

func shake(strength: float, duration: float) -> void:
	shake_strength = max(shake_strength, strength)
	shake_timer = max(shake_timer, duration)

func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
