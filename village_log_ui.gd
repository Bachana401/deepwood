extends CanvasLayer

# THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births,
# deaths, rescues, sieges, buildings rising, spirits failing and mending --
# timestamped, newest first, in the town's own plain words. Much of it
# happens while the player is down in the dark; this is how they catch up
# without having to watch it live. Design bar: comforting to the eye,
# pleasant, readable by a brand-new player -- a diary, not a debug console.

const CAT_COLORS = {
	"people": Color(0.85, 0.78, 0.62, 1.0),
	"village": Color(0.65, 0.78, 0.62, 1.0),
	"combat": Color(0.85, 0.55, 0.5, 1.0),
	"economy": Color(0.65, 0.72, 0.85, 1.0),
}
const FILTERS = ["all", "people", "village", "combat", "economy"]

var panel: Panel = null
var rows: VBoxContainer = null
var filter := "all"
var filter_buttons := {}

func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(280, 80)
	panel.size = Vector2(600, 460)
	add_child(panel)
	var title := Label.new()
	title.text = "THE VILLAGE LOG"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(18, 10)
	panel.add_child(title)
	var hint := Label.new()
	hint.text = "the town's diary — newest first   [L] close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54, 1.0))
	hint.position = Vector2(18, 36)
	panel.add_child(hint)
	var filters := HBoxContainer.new()
	filters.position = Vector2(18, 58)
	filters.add_theme_constant_override("separation", 6)
	panel.add_child(filters)
	for f in FILTERS:
		var b := Button.new()
		b.text = f.capitalize()
		b.custom_minimum_size = Vector2(0, 26)
		b.pressed.connect(_on_filter.bind(f))
		filters.add_child(b)
		filter_buttons[f] = b
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 94)
	scroll.size = Vector2(564, 348)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.custom_minimum_size = Vector2(544, 0)
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("log_toggle"):
		toggle()
		get_viewport().set_input_as_handled()

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	panel.visible = false

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		refresh()

func _on_filter(f: String) -> void:
	filter = f
	refresh()

func refresh() -> void:
	for c in rows.get_children():
		c.queue_free()
	for f in filter_buttons:
		filter_buttons[f].modulate = Color(1, 1, 1, 1.0 if f == filter else 0.55)
	var shown := 0
	for e in GameState.village_log:
		var cat := str(e.get("cat", "village"))
		if filter != "all" and cat != filter:
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var stamp := Label.new()
		stamp.text = "Day %d, %02d:00" % [int(e.get("day", 1)), int(e.get("hour", 0))]
		stamp.add_theme_font_size_override("font_size", 12)
		stamp.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5, 1.0))
		stamp.custom_minimum_size = Vector2(92, 0)
		row.add_child(stamp)
		var text := Label.new()
		text.text = str(e.get("text", ""))
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_color_override("font_color", CAT_COLORS.get(cat, Color.WHITE))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(430, 0)
		row.add_child(text)
		rows.add_child(row)
	if shown == 0:
		var empty := Label.new()
		empty.text = "Nothing yet. The village will write as it lives."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54, 1.0))
		rows.add_child(empty)
