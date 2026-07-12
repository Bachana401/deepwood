extends CanvasLayer

const LEVEL_COUNT = 100

func _ready() -> void:
	visible = false
	build_level_grid()
	$Panel/CloseButton.pressed.connect(close)

func build_level_grid() -> void:
	var grid = $Panel/ScrollContainer/GridContainer
	for level in range(1, LEVEL_COUNT + 1):
		var button = Button.new()
		button.text = str(level)
		button.custom_minimum_size = Vector2(36, 36)
		button.pressed.connect(_on_level_selected.bind(level))
		grid.add_child(button)

func open() -> void:
	refresh_lock_states()
	visible = true

# Only levels up to GameState.highest_unlocked_level are pressable -- clearing
# a level unlocks the next one (see DungeonManager._on_combatant_died).
func refresh_lock_states() -> void:
	var grid = $Panel/ScrollContainer/GridContainer
	for i in range(grid.get_child_count()):
		var level = i + 1
		grid.get_child(i).disabled = level > GameState.highest_unlocked_level

func close() -> void:
	visible = false

func _on_level_selected(level: int) -> void:
	if level > GameState.highest_unlocked_level:
		return
	close()
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# real teleport: capture everything that needs to survive the scene
	# swap, remember where to put the player back, then hand off to
	# dungeon_interior.tscn -- see game_state.gd's carry-over fields and
	# player.gd's apply_pending_player_state().
	GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.pre_dungeon_position = player.global_position
	GameState.active_dungeon_level = level
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
