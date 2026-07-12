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
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		$Panel/VBox/ExitDungeonButton.visible = $"../DungeonManager".started
		$Panel/SettingsPanel.visible = false

func _on_resume() -> void:
	toggle_pause()

func _on_exit_dungeon() -> void:
	$"../DungeonManager".exit_dungeon()
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
