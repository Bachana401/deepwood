extends Node2D
# A SPECIAL PLOT marker (roadmap Phase 3): the ground itself, drawn.
#
# A plot the player cannot SEE is a guessing game, not a decision -- so every
# patch announces what it is. Drawn procedurally on purpose: the art freeze
# stands until 2026-08-14, and this needs no new assets. Each kind gets its own
# ground tint and a few marks in its own idiom (a seam of ore, furrowed soil,
# ripples, cut blocks, standing stones), so the seven read apart at a glance.
#
# ⚠ AND IT HAS TO READ FROM THE ROAD, BEFORE ANYTHING IS BUILT ON IT. The first
# version was a 26px-tall patch of tinted ground plus a 13px label -- at the
# world's 0.6 zoom that label rendered about 8 screen pixels tall, and the patch
# read as a slightly different shade of dirt. The EYES walker photographed it
# beside a 500px-wide hall and it was, for practical purposes, still invisible.
# So the plot now carries FURNITURE: a surveyed cordon between two stakes, drifting
# motes over the worked ground, and a signpost tall enough to clear a building's
# roof -- which also means the mark survives once the building is standing on it,
# instead of being swallowed by the facade (this node is z 2, the building z 3).
#
# NOT in the "village_structure" group -- that group reserves ground against
# placement, and a plot must be the one piece of ground you CAN build on.

var plot_id := ""
var plot_name := ""
var plot_desc := ""
var for_building := ""
var half_width := 260.0

const PATCH_H := 34.0
# ⚠ THE TOWN HAS THREE SIGN BANDS, and they must not share one. Plot names ride
# highest (here), an aura's edge hangs at head height, and the ground clutter --
# woodpiles, crates, ward stones -- lives below both. At 258 this board sat 20px
# from the aura boards and the two overlapped into mush wherever a rim landed
# near a plot; dropping the aura board then buried it in the Builderhouse's
# timber instead. Both were EYES findings, one shot apart.
const POST_H := 336.0
const REFRESH := 0.1
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
	"vein":   Color(0.86, 0.72, 0.44, 1.0),
	"soil":   Color(0.62, 0.46, 0.28, 1.0),
	"spring": Color(0.58, 0.86, 0.94, 1.0),
	"quarry": Color(0.76, 0.74, 0.68, 1.0),
	"stones": Color(0.72, 0.68, 0.90, 1.0),
	"muster": Color(0.80, 0.58, 0.36, 1.0),
	"square": Color(0.78, 0.70, 0.54, 1.0),
}

const PLIGHT := preload("res://presence_light.gd")

var _phase: float = 0.0
var _t: float = 0.0
var _font: Font = null
var _mod: Color = Color(1, 1, 1, 1)

# The lip, the motes, the tags and the sign's lettering are what the eye catches
# from down the road, and the night CanvasModulate would otherwise crush all four
# to nothing. The worked earth itself darkens like any other ground.
func _lit(c: Color, amount: float = 1.0) -> Color:
	return PLIGHT.lift(c, _mod, amount)

func _ready() -> void:
	# ⚠ ABOVE THE EARTH, OR IT IS NOT THERE AT ALL. The terrain body draws at z 0
	# with its grass cap at z 1, so the -4 this used to sit at buried every plot
	# behind the ground itself -- seven painted patches that no player could ever
	# see (caught by the EYES walker 2026-07-30; the unit test only ever asserted
	# the marker NODES existed). 2 clears the cap and still passes under the
	# building bodies (frame z 3, door 4) and the player.
	z_index = 2
	add_to_group("special_plot")
	var f: Resource = load("res://art/fonts/PixelifySans.ttf")
	if f is Font:
		_font = f

func _process(delta: float) -> void:
	_phase += delta
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
		queue_redraw()

# Is the building this ground suits actually standing on it? Drawn differently
# when it is, so the reward for a careful placement is something you can look at.
func _claimed() -> bool:
	if for_building == "":
		return false
	return GameState.on_home_plot(for_building)

func _draw() -> void:
	_mod = PLIGHT.canvas(self)
	var tint: Color = KIND_TINT.get(plot_id, Color(0.3, 0.3, 0.3, 1))
	var mark: Color = KIND_MARK.get(plot_id, Color(0.6, 0.6, 0.6, 1))
	var worked: bool = _claimed()
	# the patch of worked ground itself
	draw_rect(Rect2(Vector2(-half_width, -PATCH_H), Vector2(half_width * 2.0, PATCH_H)), tint)
	# a lit lip along the top edge: the single cheapest thing that separates
	# "special ground" from "slightly different dirt" at any hour of the day
	draw_rect(Rect2(Vector2(-half_width, -PATCH_H - 4.0), Vector2(half_width * 2.0, 4.0)),
		_lit(Color(mark.r, mark.g, mark.b, 0.95 if worked else 0.75), 0.8))
	_draw_idiom(_lit(mark, 0.5))
	_draw_cordon(mark, worked)
	_draw_motes(mark, worked)
	_draw_signpost(mark, worked)

# Each kind in its own language. Deterministic: same ground every load.
func _draw_idiom(mark: Color) -> void:
	match plot_id:
		"vein":                      # a black seam broken by bright ore
			for i in range(7):
				var x := -half_width + 40.0 + i * (half_width * 2.0 - 80.0) / 6.0
				draw_line(Vector2(x, -PATCH_H + 5), Vector2(x + 16, -5), mark, 3.0)
		"soil":                      # furrows
			for i in range(9):
				var x2 := -half_width + 20.0 + i * (half_width * 2.0 - 40.0) / 8.0
				draw_line(Vector2(x2, -PATCH_H + 7), Vector2(x2, -4), mark, 3.5)
		"spring":                    # ripples
			for i in range(3):
				var y := -PATCH_H + 9.0 + i * 8.0
				draw_arc(Vector2(0, y + 30), 60.0 + i * 26.0, PI * 1.15, PI * 1.85, 18, mark, 2.4)
		"quarry":                    # half-dressed blocks
			for i in range(5):
				var bx := -half_width + 40.0 + i * (half_width * 2.0 - 80.0) / 4.0
				draw_rect(Rect2(Vector2(bx - 15, -PATCH_H + 6), Vector2(30, 19)), mark, false, 2.5)
		"stones":                    # standing stones
			for i in range(4):
				var sx := -half_width + 55.0 + i * (half_width * 2.0 - 110.0) / 3.0
				draw_rect(Rect2(Vector2(sx - 6, -PATCH_H - 22), Vector2(12, 30)), mark)
		"muster":                    # packed earth, boot-trodden lanes
			for i in range(4):
				var my := -PATCH_H + 6.0 + i * 6.0
				draw_line(Vector2(-half_width + 26, my), Vector2(half_width - 26, my), mark * Color(1, 1, 1, 0.7), 2.0)
		"square":                    # old cobbles
			for i in range(11):
				var cx := -half_width + 24.0 + i * (half_width * 2.0 - 48.0) / 10.0
				draw_rect(Rect2(Vector2(cx - 9, -PATCH_H + 8), Vector2(18, 14)), mark * Color(1, 1, 1, 0.8), false, 1.8)

# THE CORDON. Two stakes and a slack line: the universal sign that a piece of
# ground has been measured and spoken for. Reads instantly, and it draws the
# plot's true EDGE -- which is the thing the player has to get a building inside.
func _draw_cordon(mark: Color, worked: bool) -> void:
	var wood := Color(0.30, 0.24, 0.18, 1.0)
	for s in [-1.0, 1.0]:
		var sx: float = s * half_width
		draw_rect(Rect2(Vector2(sx - 5.0, -86.0), Vector2(10.0, 86.0)), wood)
		draw_rect(Rect2(Vector2(sx - 10.0, -94.0), Vector2(20.0, 10.0)),
			_lit(Color(mark.r, mark.g, mark.b, 0.95), 0.7))
	var pts := PackedVector2Array()
	for i in range(13):
		var t: float = float(i) / 12.0
		pts.append(Vector2(-half_width + half_width * 2.0 * t, -80.0 + 16.0 * sin(t * PI)))
	draw_polyline(pts, _lit(Color(mark.r, mark.g, mark.b, 0.6 if worked else 0.45), 0.7), 2.5)
	# little cloth tags along the line, so it flutters rather than sits there
	for i in range(5):
		var t2: float = 0.1 + float(i) * 0.2
		var p := Vector2(-half_width + half_width * 2.0 * t2, -80.0 + 16.0 * sin(t2 * PI))
		var sway: float = sin(_phase * 2.0 + float(i) * 1.3) * 5.0
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(sway - 9.0, 22.0), p + Vector2(sway + 9.0, 22.0)]),
			_lit(Color(mark.r, mark.g, mark.b, 0.9), 0.6))

# Something on this ground is worth having: a few slow motes, brighter once the
# right building is finally standing here.
func _draw_motes(mark: Color, worked: bool) -> void:
	var n: int = 6 if worked else 4
	for i in range(n):
		var sd: float = float(i) * 2.39
		var x: float = sin(_phase * 0.23 + sd) * (half_width - 50.0)
		var y: float = -46.0 - fposmod(_phase * (9.0 if worked else 6.0) + sd * 21.0, 78.0)
		var fade: float = clampf(1.0 - (-y - 46.0) / 78.0, 0.0, 1.0)
		draw_circle(Vector2(x, y), 5.0, _lit(Color(mark.r, mark.g, mark.b, fade * (0.95 if worked else 0.75)), 0.85))
		draw_circle(Vector2(x, y), 14.0, _lit(Color(mark.r, mark.g, mark.b, fade * 0.12), 0.85))

# THE SIGN. Tall enough to be seen from down the road, and tall enough to still
# clear the roof once its building is standing on the patch. Says what the ground
# is and what it wants; wears a lit ring once it has it.
func _draw_signpost(mark: Color, worked: bool) -> void:
	var px: float = -half_width * 0.62
	var wood := Color(0.28, 0.22, 0.17, 1.0)
	draw_rect(Rect2(Vector2(px - 5.0, -POST_H), Vector2(10.0, POST_H)), wood)
	draw_rect(Rect2(Vector2(px - 26.0, -18.0), Vector2(52.0, 8.0)), wood)   # its footing
	if _font == null:
		return
	var title: String = plot_name.to_upper()
	var want: String = ("WORKED BY THE " + for_building.to_upper()) if worked \
		else ("WANTS THE " + for_building.to_upper())
	var s1: int = 27
	var s2: int = 19
	var w1: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, s1).x
	var w2: float = _font.get_string_size(want, HORIZONTAL_ALIGNMENT_LEFT, -1, s2).x
	var bw: float = maxf(w1, w2) + 40.0
	var bh: float = 68.0
	var c := Vector2(px + bw * 0.42, -POST_H + bh * 0.5 + 14.0)
	var r := Rect2(c - Vector2(bw * 0.5, bh * 0.5), Vector2(bw, bh))
	# the crossbar the board hangs from, drawn FIRST so it passes behind it
	draw_rect(Rect2(Vector2(px - 5.0, -POST_H), Vector2(bw * 0.42 + 10.0, 8.0)), wood)
	draw_rect(Rect2(Vector2(c.x - 2.5, -POST_H + 4.0), Vector2(5.0, 12.0)), wood)
	draw_rect(r, Color(0.13, 0.10, 0.08, 0.95))
	draw_rect(r, _lit(Color(mark.r, mark.g, mark.b, 0.95), 0.75), false, 3.0 if worked else 2.0)
	if worked:
		var beat: float = 0.72 + 0.28 * sin(_phase * 2.4)
		draw_rect(r.grow(7.0), _lit(Color(mark.r, mark.g, mark.b, 0.35 * beat), 0.8), false, 2.5)
	draw_string(_font, c + Vector2(-w1 * 0.5, -3.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, s1, _lit(Color(mark.r, mark.g, mark.b, 1.0), 0.75))
	draw_string(_font, c + Vector2(-w2 * 0.5, 22.0), want,
		HORIZONTAL_ALIGNMENT_LEFT, -1, s2, _lit(Color(0.80, 0.78, 0.72, 0.95), 0.6))
