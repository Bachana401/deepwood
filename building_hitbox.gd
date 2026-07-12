extends StaticBody2D

# Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows
# can't strike -- Area2D.body_entered only fires for physics bodies. This child
# gives the building a physics body on the dedicated "building" layer (8) so
# enemy projectiles land on it; the hit is forwarded to the parent building.
# The player's weapons mask layer 4 only, so they never touch this.

func take_damage(amount: int) -> void:
	var b = get_parent()
	if b and b.has_method("take_damage"):
		b.take_damage(amount)

func apply_knockback(_dir_sign: int, _distance: float) -> void:
	pass  # buildings don't get knocked around
