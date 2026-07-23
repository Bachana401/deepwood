extends Control

# Always-visible village food gauge, top-left HUD, tucked just under the mana
# bar (and above the TAB-only morale meter). Food is the town's larder -- see
# GameState.village_food / food_capacity() / food_days_remaining(). The bar
# fills toward the population-scaled capacity and shifts wheat-gold -> amber ->
# red as the days of food dwindle; an EMPTY larder flashes to warn the player
# their village is starting to starve. Lives only in the village scene
# (main.tscn), so it never shows in the dungeon.

const BAR_X := 20.0
const BAR_Y := 112.0
const BAR_W := 100.0
const BAR_H := 10.0

var bg: ColorRect = null
var fill: ColorRect = null
var label: Label = null
var flash_t := 0.0
var cur_frac := 1.0
var cur_days := 4.0
var empty := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg = ColorRect.new()
	bg.position = Vector2(BAR_X, BAR_Y)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.color = Color(0.06, 0.06, 0.09, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	fill = ColorRect.new()
	fill.position = Vector2(BAR_X, BAR_Y)
	fill.size = Vector2(BAR_W, BAR_H)
	fill.color = Color(0.85, 0.72, 0.2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	label = Label.new()
	label.position = Vector2(BAR_X + BAR_W + 12.0, BAR_Y - 6.0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _process(delta: float) -> void:
	# NO MOUTHS, NO GAUGE (dev 2026-07-23): an empty village has no one to feed, so
	# the larder is meaningless -- don't show a static bar before the first villager
	# is rescued. It appears the moment the town has anyone to eat.
	visible = not GameState.rescued_villagers.is_empty()
	if not visible:
		return
	flash_t += delta
	var cap = GameState.food_capacity()
	cur_frac = clampf(GameState.village_food / cap, 0.0, 1.0) if cap > 0.0 else 0.0
	cur_days = GameState.food_days_remaining()
	empty = not GameState.has_food()
	fill.size.x = BAR_W * cur_frac
	var col = _food_color(cur_days)
	# an empty larder pulses so the warning is impossible to miss
	if empty:
		var pulse = 0.5 + 0.5 * sin(flash_t * 7.0)
		col = Color(0.9, 0.2, 0.15).lerp(Color(0.4, 0.05, 0.05), pulse)
	fill.color = col
	if empty:
		if GameState.village_is_starving():
			label.text = "STARVING"
		else:
			label.text = "No food!"
		label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	else:
		label.text = "Food  %.1f days" % cur_days
		label.add_theme_color_override("font_color", Color(1, 1, 1))
	queue_redraw()

# A little wheat sheaf drawn just left of the bar, so food reads at a glance and
# never depends on an emoji glyph the default font might not have.
func _draw() -> void:
	var cx = BAR_X - 9.0
	var cy = BAR_Y + BAR_H / 2.0
	var stalk = Color(0.75, 0.62, 0.18) if not empty else Color(0.6, 0.35, 0.2)
	# three stalks fanning up
	for a in [-0.5, 0.0, 0.5]:
		var tip = Vector2(cx + sin(a) * 5.0, cy - 7.0)
		draw_line(Vector2(cx, cy + 4.0), tip, stalk, 1.6)
		# grains: a few dots along the top of each stalk
		for k in range(3):
			var t = 0.45 + 0.22 * k
			var p = Vector2(cx, cy + 4.0).lerp(tip, t)
			draw_circle(p + Vector2(1.2, 0), 1.15, stalk)
			draw_circle(p - Vector2(1.2, 0), 1.15, stalk)

func _food_color(days: float) -> Color:
	if days >= 2.0:
		return Color(0.55, 0.78, 0.28)   # comfortable -- green-gold
	elif days >= 1.0:
		return Color(0.88, 0.72, 0.2)    # tightening -- amber
	return Color(0.85, 0.35, 0.18)        # nearly out -- red
