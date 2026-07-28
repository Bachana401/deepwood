extends CanvasLayer
# THE CAVE'S PAUSE MENU (scan fix 2026-07-27).
#
# underground.tscn is two nodes and inherits none of the overlays main.tscn and
# dungeon_interior.tscn author by hand, so down here ESC did nothing at all:
# no pause, no window sweep (the bag and skill tree could only be closed with
# their own keys), and -- worst of the three -- no Quit to Menu, i.e. no way to
# save and leave from a scene the player can spend a whole session in. The only
# persistence was the 180-second autosave.
#
# pause_menu.gd binds to a Panel/VBox/Button tree that lives in those .tscn
# files, so it cannot be instantiated from script; this is the same contract in
# a self-building form: `visible` mirrors `get_tree().paused`, ESC closes any
# open esc_window first (exactly like pause_menu.close_open_windows), and the
# quit paths save before leaving.

var _panel: Panel = null

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -190.0
	_panel.offset_right = 190.0
	_panel.offset_top = -140.0
	_panel.offset_bottom = 140.0
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24.0
	vb.offset_right = -24.0
	vb.offset_top = 22.0
	vb.offset_bottom = -22.0
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "THE DEEP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.86, 0.82, 0.6))
	vb.add_child(title)
	vb.add_child(HSeparator.new())

	_add_button(vb, "Resume", _on_resume)
	_add_button(vb, "Save and Quit to Menu", _on_quit_menu)
	_add_button(vb, "Save and Quit Game", _on_quit_game)

func _add_button(vb: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	vb.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# a window on screen is what ESC closes first -- only a clear screen pauses
	if _close_open_windows():
		return
	toggle_pause()

func _close_open_windows() -> bool:
	var closed := false
	for w in get_tree().get_nodes_in_group("esc_window"):
		if is_instance_valid(w) and w.has_method("esc_is_open") and w.esc_is_open():
			if w.has_method("esc_close"):
				w.esc_close()
				closed = true
	return closed

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible

func _on_resume() -> void:
	visible = false
	get_tree().paused = false

func _save() -> void:
	var p = get_tree().get_first_node_in_group("player")
	GameState.save_game(p)

func _on_quit_menu() -> void:
	get_tree().paused = false
	_save()
	# leaving the cave by the menu is still leaving the cave: clear the flags the
	# deep sets, or the next Continue would think the player is still down here
	GameState.in_dungeon = false
	GameState.came_from_underground = false
	GameState.proving_grounds = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_game() -> void:
	get_tree().paused = false
	_save()
	GameState.in_dungeon = false
	GameState.came_from_underground = false
	GameState.proving_grounds = false
	get_tree().quit()
