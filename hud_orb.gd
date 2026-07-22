extends Control

# MU Online / Diablo style liquid globe for HP or mana (dev ask 2026-07-22).
# A shader (hud_orb.gdshader) draws the glass sphere + liquid; this Control frames
# it, animates the ripple, eases the liquid toward its target so a hit DRAINS
# smoothly rather than snapping, and shows the current/max number.

var rect: ColorRect = null
var label: Label = null
var _t := 0.0
var _fill := 1.0
var _target := 1.0

func setup(top: Color, bottom: Color, frame: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://hud_orb.gdshader")
	mat.set_shader_parameter("liquid_top", top)
	mat.set_shader_parameter("liquid_bottom", bottom)
	mat.set_shader_parameter("frame_col", frame)
	mat.set_shader_parameter("fill", 1.0)
	rect.material = mat
	add_child(rect)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func set_values(cur: float, max_v: float) -> void:
	_target = clampf(cur / maxf(max_v, 1.0), 0.0, 1.0)
	if label:
		label.text = "%d/%d" % [int(round(maxf(cur, 0.0))), int(round(max_v))]

func _process(delta: float) -> void:
	_t += delta
	_fill = move_toward(_fill, _target, delta * 1.8)
	if rect and rect.material:
		rect.material.set_shader_parameter("fill", _fill)
		rect.material.set_shader_parameter("t", _t)
