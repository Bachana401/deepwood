extends Node2D
# A SPECIAL PLOT marker (roadmap Phase 3): the ground itself, drawn.
#
# A plot the player cannot SEE is a guessing game, not a decision -- so every
# patch announces what it is. Drawn procedurally on purpose: the art freeze
# stands until 2026-08-14, and this needs no new assets. Each kind gets its own
# ground tint and a few marks in its own idiom (a seam of ore, furrowed soil,
# ripples, cut blocks, standing stones), so the seven read apart at a glance.
#
# NOT in the "village_structure" group -- that group reserves ground against
# placement, and a plot must be the one piece of ground you CAN build on.

var plot_id := ""
var plot_name := ""
var plot_desc := ""
var for_building := ""
var half_width := 260.0

const PATCH_H := 26.0
const KIND_TINT := {
	"vein":   Color(0.30, 0.28, 0.34, 1.0),
	"soil":   Color(0.22, 0.16, 0.12, 1.0),
	"spring": Color(0.24, 0.40, 0.46, 1.0),
	"quarry": Color(0.42, 0.41, 0.38, 1.0),
	"stones": Color(0.34, 0.33, 0.40, 1.0),
	"muster": Color(0.34, 0.29, 0.22, 1.0),
	"square": Color(0.36, 0.33, 0.28, 1.0),
}
const KIND_MARK := {
	"vein":   Color(0.72, 0.62, 0.42, 1.0),
	"soil":   Color(0.36, 0.26, 0.18, 1.0),
	"spring": Color(0.58, 0.80, 0.86, 1.0),
	"quarry": Color(0.62, 0.61, 0.57, 1.0),
	"stones": Color(0.60, 0.58, 0.70, 1.0),
	"muster": Color(0.52, 0.44, 0.32, 1.0),
	"square": Color(0.54, 0.50, 0.42, 1.0),
}

func _ready() -> void:
	# ⚠ ABOVE THE EARTH, OR IT IS NOT THERE AT ALL. The terrain body draws at z 0
	# with its grass cap at z 1, so the -4 this used to sit at buried every plot
	# behind the ground itself -- seven painted patches that no player could ever
	# see (caught by the EYES walker 2026-07-30; the unit test only ever asserted
	# the marker NODES existed). 2 clears the cap and still passes under the
	# building bodies (frame z 3, door 4) and the player.
	z_index = 2
	add_to_group("special_plot")
	_build_label()

func _build_label() -> void:
	var lbl := Label.new()
	lbl.text = plot_name
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", KIND_MARK.get(plot_id, Color(0.8, 0.8, 0.8, 1)))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(half_width * 2.0, 20)
	lbl.position = Vector2(-half_width, -PATCH_H - 30.0)
	lbl.z_index = 2
	add_child(lbl)

func _draw() -> void:
	var tint: Color = KIND_TINT.get(plot_id, Color(0.3, 0.3, 0.3, 1))
	var mark: Color = KIND_MARK.get(plot_id, Color(0.6, 0.6, 0.6, 1))
	# the patch of worked ground itself
	draw_rect(Rect2(Vector2(-half_width, -PATCH_H), Vector2(half_width * 2.0, PATCH_H)), tint)
	draw_line(Vector2(-half_width, -PATCH_H), Vector2(half_width, -PATCH_H), mark * Color(1, 1, 1, 0.5), 2.0)
	# ...and its own idiom on top. Deterministic: same ground every load.
	match plot_id:
		"vein":                      # a black seam broken by bright ore
			for i in range(7):
				var x := -half_width + 40.0 + i * (half_width * 2.0 - 80.0) / 6.0
				draw_line(Vector2(x, -PATCH_H + 4), Vector2(x + 14, -4), mark, 2.5)
		"soil":                      # furrows
			for i in range(9):
				var x2 := -half_width + 20.0 + i * (half_width * 2.0 - 40.0) / 8.0
				draw_line(Vector2(x2, -PATCH_H + 6), Vector2(x2, -3), mark, 3.0)
		"spring":                    # ripples
			for i in range(3):
				var y := -PATCH_H + 7.0 + i * 7.0
				draw_arc(Vector2(0, y + 26), 60.0 + i * 26.0, PI * 1.15, PI * 1.85, 18, mark, 1.8)
		"quarry":                    # half-dressed blocks
			for i in range(5):
				var bx := -half_width + 40.0 + i * (half_width * 2.0 - 80.0) / 4.0
				draw_rect(Rect2(Vector2(bx - 13, -PATCH_H + 5), Vector2(26, 15)), mark, false, 2.0)
		"stones":                    # standing stones
			for i in range(4):
				var sx := -half_width + 55.0 + i * (half_width * 2.0 - 110.0) / 3.0
				draw_rect(Rect2(Vector2(sx - 5, -PATCH_H - 16), Vector2(10, 22)), mark)
		"muster":                    # packed earth, boot-trodden lanes
			for i in range(4):
				var my := -PATCH_H + 5.0 + i * 5.0
				draw_line(Vector2(-half_width + 26, my), Vector2(half_width - 26, my), mark * Color(1, 1, 1, 0.6), 1.6)
		"square":                    # old cobbles
			for i in range(11):
				var cx := -half_width + 24.0 + i * (half_width * 2.0 - 48.0) / 10.0
				draw_rect(Rect2(Vector2(cx - 8, -PATCH_H + 7), Vector2(16, 11)), mark * Color(1, 1, 1, 0.7), false, 1.4)
