extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/ContinueButton.pressed.connect(_on_continue)
	$VBox/NewGameButton.pressed.connect(_on_new_game)
	$VBox/HowToPlayButton.pressed.connect(_on_how_to_play)
	$HowToPlayPanel/CloseButton.pressed.connect(_on_close_how_to_play)
	$VBox/QuitButton.pressed.connect(_on_quit)
	update_buttons()
	update_best_wave_label()

func update_buttons() -> void:
	var has_save = GameState.has_save()
	$VBox/StartButton.visible = not has_save
	$VBox/ContinueButton.visible = has_save
	$VBox/NewGameButton.visible = has_save

func update_best_wave_label() -> void:
	if GameState.best_wave > 0:
		$BestWaveLabel.text = "Best Wave: " + str(GameState.best_wave)
		$BestWaveLabel.visible = true

func _on_how_to_play() -> void:
	$HowToPlayPanel.visible = true

func _on_close_how_to_play() -> void:
	$HowToPlayPanel.visible = false

func _on_start() -> void:
	GameState.pending_load = false
	get_tree().change_scene_to_file("res://main.tscn")

func _on_continue() -> void:
	GameState.pending_load = true
	get_tree().change_scene_to_file("res://main.tscn")

func _on_new_game() -> void:
	GameState.delete_save()
	GameState.pending_load = false
	get_tree().change_scene_to_file("res://main.tscn")

func _on_quit() -> void:
	get_tree().quit()
