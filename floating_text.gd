class_name FloatingText
extends RefCounted

# Shared floating combat text -- a damage number that rises, drifts, and fades
# in world space. Any script that deals player damage calls FloatingText.spawn
# so the numbers are consistent everywhere (melee, arrows, projectiles, nukes).
#
# Design goal: smooth and easy on the eye. Normal hits are small and pale; crits
# pop bigger, gold, with a quick scale-punch and a "!" -- readable at a glance
# without cluttering the screen.

const NORMAL_COLOR = Color(1.0, 0.96, 0.86)
const CRIT_COLOR = Color(1.0, 0.82, 0.25)

static func spawn(parent: Node, world_pos: Vector2, amount: int, is_crit: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	if parent == null or not is_instance_valid(parent) or amount <= 0:
		return
	var lbl = Label.new()
	lbl.text = str(amount) + ("!" if is_crit else "")
	lbl.z_index = 100
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var col = tint if tint.a > 0.0 else (CRIT_COLOR if is_crit else NORMAL_COLOR)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5 if is_crit else 4)
	lbl.add_theme_font_size_override("font_size", 26 if is_crit else 17)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	# start centred on the target, with a little horizontal jitter so rapid hits
	# fan out instead of stacking into an unreadable blob
	var jitter = randf_range(-16.0, 16.0)
	lbl.global_position = world_pos + Vector2(jitter - 12.0, -28.0)
	lbl.pivot_offset = lbl.size * 0.5

	var rise = 44.0 + (10.0 if is_crit else 0.0)
	var t = lbl.create_tween()
	if is_crit:
		# a quick punch-in on crits
		lbl.scale = Vector2(0.5, 0.5)
		t.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "scale", Vector2.ONE, 0.08)
	# float up + drift, holding readable, then fade the back half
	t.parallel().tween_property(lbl, "global_position", lbl.global_position + Vector2(jitter * 0.4, -rise), 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.12)
	t.tween_property(lbl, "modulate:a", 0.0, 0.32)
	t.tween_callback(lbl.queue_free)
