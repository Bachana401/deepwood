extends CanvasLayer

func _ready() -> void:
	visible = false
	_ensure_chrome()

# main.tscn and dungeon_interior.tscn author the black shade + CountdownLabel by
# hand; the tile-underground builds this overlay from script, where those
# children do not exist. Build whatever is missing so one script serves both --
# without it, dying down there fell through to a silent five-second wait with no
# black screen, no countdown and no death toll (scan 2026-07-27).
func _ensure_chrome() -> void:
	if get_node_or_null("Shade") == null:
		var shade := ColorRect.new()
		shade.name = "Shade"
		shade.color = Color(0, 0, 0, 0.88)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		move_child(shade, 0)
	if get_node_or_null("CountdownLabel") == null:
		var cd := Label.new()
		cd.name = "CountdownLabel"
		cd.text = ""
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.add_theme_font_size_override("font_size", 96)
		cd.add_theme_color_override("font_color", Color(0.95, 0.3, 0.28))
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cd)

# The cost of dying, said ON the black screen itself -- the toast version
# played behind this overlay and was never seen (presentation sweep).
var toll_label: Label = null

func _ensure_toll_label() -> void:
	if toll_label != null:
		return
	toll_label = Label.new()
	toll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toll_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	toll_label.add_theme_font_size_override("font_size", 16)
	toll_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5))
	add_child(toll_label)
	# anchor AFTER entering the tree: a preset applied to a parentless Control
	# computes against nothing, leaving the anchors at top-left -- the toll
	# then hung 380px off the LEFT edge, clipped (EYES d61, 2026-07-28)
	toll_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toll_label.offset_left = -380.0
	toll_label.offset_right = 380.0
	toll_label.offset_top = 400.0
	toll_label.offset_bottom = 460.0

func run_death_sequence(seconds: float) -> void:
	_ensure_toll_label()
	var lines := ["Your dropped gold lies where you fell."]
	if GameState.last_death_toll != "":
		lines.push_front("💀 " + GameState.last_death_toll)
	toll_label.text = "\n".join(lines)
	visible = true
	var remaining = int(round(seconds))
	while remaining > 0:
		$CountdownLabel.text = str(remaining)
		pop_countdown()
		# each second TOLLS, sinking as the wait runs out -- the countdown
		# was mute drama (audio pass 2026-07-28)
		SfxSynth.play_ui(self, "thump", -12.0, 1.8 - 0.08 * float(remaining))
		await get_tree().create_timer(1.0).timeout
		remaining -= 1
	visible = false

func pop_countdown() -> void:
	$CountdownLabel.scale = Vector2(1.3, 1.3)
	var tween = create_tween()
	tween.tween_property($CountdownLabel, "scale", Vector2.ONE, 0.25)
