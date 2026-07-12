extends CanvasLayer

# A single hover tooltip shared by every item UI (inventory, chest, equipment
# panel). Those panels find it via the "item_tooltip" group and call
# show_for(item_id) / hide_tooltip(). It follows the mouse and clamps to the
# screen so it never runs off an edge.

const LINE_HEIGHT = 17.0
const PAD = 8.0
const WIDTH = 240.0
const CURSOR_OFFSET = Vector2(18, 12)

var panel: Panel
var label: Label

func _ready() -> void:
	layer = 90
	add_to_group("item_tooltip")
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(WIDTH, 60)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	style.border_color = Color(0.7, 0.68, 0.55, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(PAD, PAD)
	label.size = Vector2(WIDTH - PAD * 2, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85, 1))
	panel.add_child(label)

	panel.visible = false

func show_for(item_id: String) -> void:
	if item_id == "":
		hide_tooltip()
		return
	var text = Inventory.build_tooltip_text(item_id)
	label.text = text
	# first line (the name) coloured by the item's rarity/category tint
	var name_color = Inventory.get_item_def(item_id).get("color", Color(0.95, 0.93, 0.85, 1))
	label.add_theme_color_override("font_color", name_color.lightened(0.25))
	var line_count = text.count("\n") + 1
	panel.size = Vector2(WIDTH, line_count * LINE_HEIGHT + PAD * 2)
	panel.visible = true
	reposition(get_viewport().get_mouse_position())

func hide_tooltip() -> void:
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible:
		reposition(get_viewport().get_mouse_position())

func reposition(mouse_pos: Vector2) -> void:
	var view = get_viewport().get_visible_rect().size
	var pos = mouse_pos + CURSOR_OFFSET
	pos.x = min(pos.x, view.x - panel.size.x - 4)
	pos.y = min(pos.y, view.y - panel.size.y - 4)
	pos.x = max(pos.x, 4)
	pos.y = max(pos.y, 4)
	panel.position = pos
