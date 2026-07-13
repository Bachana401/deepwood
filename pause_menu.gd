extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/ExitDungeonButton.pressed.connect(_on_exit_dungeon)
	$Panel/VBox/SettingsButton.pressed.connect(_on_toggle_settings)
	$Panel/VBox/QuitMenuButton.pressed.connect(_on_quit_to_menu)
	$Panel/VBox/QuitGameButton.pressed.connect(_on_quit_game)
	$Panel/SettingsPanel.visible = false
	$Panel/SettingsPanel/VolumeSlider.value = GameState.master_volume
	$Panel/SettingsPanel/VolumeSlider.value_changed.connect(_on_volume_changed)
	if $Panel/SettingsPanel.has_node("MusicSlider"):
		$Panel/SettingsPanel/MusicSlider.value = GameState.music_volume
		$Panel/SettingsPanel/MusicSlider.value_changed.connect(_on_music_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ESC first dismisses any open game window (inventory, gear, chest, skill
		# tree, a building panel, the shop). Only when nothing is open -- or the
		# pause menu itself is up -- does it toggle pause.
		if not visible and close_open_windows():
			get_viewport().set_input_as_handled()
			return
		toggle_pause()
		get_viewport().set_input_as_handled()

# Closes every window that reports itself open (see the esc_window group). Any
# window can opt in by joining that group and exposing esc_is_open/esc_close.
func close_open_windows() -> bool:
	var closed := false
	for w in get_tree().get_nodes_in_group("esc_window"):
		if w.has_method("esc_is_open") and w.esc_is_open():
			w.esc_close()
			closed = true
	return closed

# The "dungeon manager" node differs by scene: in the village (main.tscn) it's
# a sibling child literally named "DungeonManager"; inside a dungeon run
# (dungeon_interior.tscn) the SCENE ROOT itself is the manager and PauseMenu is
# its child, so "../DungeonManager" resolves to nothing. Resolve both here
# instead of hard-coding a path -- the old "../DungeonManager" was null in the
# dungeon, so opening the pause menu there hit a null and never worked.
func dungeon_manager() -> Node:
	var m = get_node_or_null("../DungeonManager")
	if m:
		return m
	var parent = get_parent()   # dungeon interior: the root IS the manager
	if parent and parent.has_method("exit_dungeon"):
		return parent
	return null

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		var dm = dungeon_manager()
		$Panel/VBox/ExitDungeonButton.visible = dm != null and dm.started
		$Panel/SettingsPanel.visible = false

func _on_resume() -> void:
	toggle_pause()

func _on_exit_dungeon() -> void:
	var dm = dungeon_manager()
	if dm:
		dm.exit_dungeon()
	toggle_pause()

func _on_toggle_settings() -> void:
	$Panel/SettingsPanel.visible = not $Panel/SettingsPanel.visible

func _on_volume_changed(value: float) -> void:
	GameState.set_master_volume(value)

func _on_music_changed(value: float) -> void:
	GameState.set_music_volume(value)

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	GameState.save_game($"../Player")
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_game() -> void:
	get_tree().paused = false
	GameState.save_game($"../Player")
	get_tree().quit()
