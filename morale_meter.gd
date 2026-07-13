extends Control

# Village morale, shown in the TAB overlay directly BELOW the mana bar (kept
# clear of it so the two never overlap). It stays hidden until the whole village
# has been rebuilt (GameState.morale_meter_unlocked); after that it appears
# whenever the player opens the TAB view and hides again when TAB is closed.
#
# The bar's colour AND a little face both shift with the mood -- a deep red
# frown in misery, through a flat amber neutral, to a wide green grin when the
# town is thriving -- and the face rides along the bar at the current fill level,
# so it literally moves with the morale.

const BAR_X := 20.0
const BAR_Y := 126.0     # clears the mana bar AND its label (which reach y=112)
const BAR_W := 100.0
const BAR_H := 12.0

var fill: ColorRect = null
var label: Label = null
var tab_open := false
var cur_morale := 50

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.position = Vector2(BAR_X, BAR_Y)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.color = Color(0.06, 0.06, 0.09, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	fill = ColorRect.new()
	fill.position = Vector2(BAR_X, BAR_Y)
	fill.size = Vector2(BAR_W, BAR_H)
	fill.color = Color(0.3, 0.8, 0.35)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	# readout sits past the face's furthest travel so they never collide
	label = Label.new()
	label.position = Vector2(BAR_X + BAR_W + 22.0, BAR_Y - 4.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	visible = false

# Toggle alongside the inventory/equipment panels on TAB.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		tab_open = not tab_open
		refresh()

func _process(_delta: float) -> void:
	if tab_open:
		refresh()

func refresh() -> void:
	if not is_instance_valid(fill):
		return
	# hidden until the town is fully built, and then only while the TAB view is open
	visible = GameState.morale_meter_unlocked and tab_open
	if not visible:
		return
	cur_morale = GameState.village_morale()
	fill.size.x = BAR_W * float(cur_morale) / 100.0
	fill.color = _mood_color(cur_morale)
	label.text = "Morale %.1f/10" % (float(cur_morale) / 10.0)
	queue_redraw()

# The face: a coloured disc riding at the fill tip, with a mouth that bends from
# a frown (low morale) through flat to a grin (high morale). Eyes droop when sad.
func _draw() -> void:
	if not visible:
		return
	var frac = float(cur_morale) / 100.0
	var cx = BAR_X + BAR_W * frac
	var cy = BAR_Y + BAR_H / 2.0
	var r = 9.0
	var col = _mood_color(cur_morale)
	draw_circle(Vector2(cx, cy), r, col)
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 1.4)
	# curve: -1 = deep frown, 0 = flat, +1 = big grin
	var curve = frac * 2.0 - 1.0
	var eye_col = Color(0.1, 0.08, 0.08)
	var ex = 3.3
	var ey = cy - 2.4
	if curve < -0.1:
		# sad: eyes as downward-slanting brows
		draw_line(Vector2(cx - ex - 1.3, ey - 1.0), Vector2(cx - ex + 1.3, ey + 0.4), eye_col, 1.4)
		draw_line(Vector2(cx + ex - 1.3, ey + 0.4), Vector2(cx + ex + 1.3, ey - 1.0), eye_col, 1.4)
	else:
		draw_circle(Vector2(cx - ex, ey), 1.35, eye_col)
		draw_circle(Vector2(cx + ex, ey), 1.35, eye_col)
	# mouth: sampled parabola; middle dips down for a smile, up for a frown
	var pts = PackedVector2Array()
	var mw = 4.6
	var n = 9
	for i in range(n):
		var t = float(i) / float(n - 1) * 2.0 - 1.0
		var mx = cx + t * mw
		var my = cy + 3.1 + curve * 2.7 * (1.0 - t * t)
		pts.append(Vector2(mx, my))
	draw_polyline(pts, Color(0.1, 0.05, 0.05), 1.7)

func _mood_color(m: int) -> Color:
	if m >= 66:
		return Color(0.3, 0.8, 0.35)     # thriving
	elif m >= 33:
		return Color(0.9, 0.75, 0.2)     # strained
	return Color(0.85, 0.3, 0.2)          # suffering
