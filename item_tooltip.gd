extends CanvasLayer

# A single hover tooltip shared by every item UI (inventory, chest, equipment
# panel). Those panels find it via the "item_tooltip" group and call
# show_for(item_id) / hide_tooltip(). It follows the mouse and clamps to the
# screen so it never runs off an edge.
#
# The card is Terraria-styled (dev ask 2026-07-22): a dark pixel box with the
# item name in its rarity colour, base stats in white, every "+" bonus in
# green, specials in gold, and the sell value in coin-gold -- all rendered as
# BBCode by Inventory.build_tooltip_bbcode.

const PAD = 9.0
const WIDTH = 250.0
const CURSOR_OFFSET = Vector2(18, 14)

var panel: Panel
var rich: RichTextLabel

func _ready() -> void:
	layer = 90
	add_to_group("item_tooltip")
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(WIDTH, 60)
	panel.add_theme_stylebox_override("panel", _card_style())
	add_child(panel)

	rich = RichTextLabel.new()
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.position = Vector2(PAD, PAD)
	rich.custom_minimum_size = Vector2(WIDTH - PAD * 2, 0)
	rich.size = Vector2(WIDTH - PAD * 2, 0)
	rich.add_theme_font_size_override("normal_font_size", 13)
	rich.add_theme_color_override("default_color", Color(0.90, 0.88, 0.80, 1))
	# a crisp black shadow under every glyph -- Terraria's tooltip text pops off
	# the box the same way, and it keeps light rarity colours legible on the dark
	rich.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	rich.add_theme_constant_override("shadow_offset_x", 1)
	rich.add_theme_constant_override("shadow_offset_y", 1)
	rich.add_theme_constant_override("line_separation", 3)
	panel.add_child(rich)

	panel.visible = false

func show_for(item_id: String) -> void:
	if item_id == "":
		hide_tooltip()
		return
	rich.text = Inventory.build_tooltip_bbcode(item_id)
	panel.visible = true
	_resize()
	reposition(get_viewport().get_mouse_position())

func hide_tooltip() -> void:
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible:
		_resize()
		reposition(get_viewport().get_mouse_position())

# Grow the box to the text: the RichTextLabel reports the height its content
# needs at our fixed width, and the panel wraps it with even padding.
func _resize() -> void:
	var h: float = rich.get_content_height()
	if h <= 0.0:
		h = rich.size.y
	panel.size = Vector2(WIDTH, h + PAD * 2)

func reposition(mouse_pos: Vector2) -> void:
	var view = get_viewport().get_visible_rect().size
	var pos = mouse_pos + CURSOR_OFFSET
	pos.x = min(pos.x, view.x - panel.size.x - 4)
	pos.y = min(pos.y, view.y - panel.size.y - 4)
	pos.x = max(pos.x, 4)
	pos.y = max(pos.y, 4)
	panel.position = pos

# The pixel box: near-black navy fill, a thin cool-grey border, tight corners.
func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.098, 0.97)
	style.border_color = Color(0.32, 0.35, 0.5, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	# a faint inner lift so the box reads as a raised pixel panel, not a hole
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	return style
