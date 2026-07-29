extends VBoxContainer

const DISPLAY_DURATION = 2.2
const FADE_DURATION = 0.5

func _ready() -> void:
	# lets autoloads (GameState's level-up toast) find whichever scene's
	# stack is live without a hardcoded scene path
	add_to_group("notification_stack")

# Toasts render as BBCode (item-art name-plate pass 2026-07-28): callers can
# colour an item's name in its rarity via Inventory.name_bbcode(id), Terraria-
# style, and every existing plain-text call renders unchanged (RichTextLabel
# passes plain text straight through).
func show_notification(text: String) -> void:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "[right]" + text + "[/right]"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween = create_tween()
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(label.queue_free)
