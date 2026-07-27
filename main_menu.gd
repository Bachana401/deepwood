extends Control

# Whether the fresh-start flow currently in the difficulty picker should wipe
# an existing save first. Start Game (no save exists yet) doesn't need this;
# New Game (a save already exists) does.
var pending_delete_save = false

const DIFFICULTY_DEFAULT_HINT = "Hover an option above to see what it means. This cannot be changed later."
const DIFFICULTY_DESCRIPTIONS = {
	"Easy": "Easy: on death you drop some of your currency at the spot where you died (walk back to recover it). No permanent losses -- best for a relaxed playthrough.",
	"Medium": "Medium: same currency drop as Easy, PLUS you lose one randomly chosen rescued villager. Real stakes alongside steady progress.",
	"Hard": "Hard: same currency drop as Easy, PLUS a random rescued villager, PLUS a skill material. The full risk -- every death costs you something lasting.",
}

# Easy reads safe/friendly (green), Medium reads cautious-but-fine (amber),
# Hard reads outright menacing (near-black blood red with a darker border)
# -- color communicating severity at a glance, on top of the text.
const DIFFICULTY_COLORS = {
	"Easy": {"bg": Color(0.2, 0.55, 0.26), "border": Color(0.12, 0.35, 0.16)},
	"Medium": {"bg": Color(0.72, 0.52, 0.12), "border": Color(0.5, 0.35, 0.06)},
	"Hard": {"bg": Color(0.4, 0.04, 0.04), "border": Color(0.12, 0.01, 0.01)},
}

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/ContinueButton.pressed.connect(_on_continue)
	$VBox/NewGameButton.pressed.connect(_on_new_game)
	$VBox/HowToPlayButton.pressed.connect(_on_how_to_play)
	$HowToPlayPanel/CloseButton.pressed.connect(_on_close_how_to_play)
	$VBox/QuitButton.pressed.connect(_on_quit)
	$DifficultyPanel/EasyButton.pressed.connect(_on_difficulty_chosen.bind("Easy"))
	$DifficultyPanel/MediumButton.pressed.connect(_on_difficulty_chosen.bind("Medium"))
	$DifficultyPanel/HardButton.pressed.connect(_on_difficulty_chosen.bind("Hard"))
	$DifficultyPanel/CancelButton.pressed.connect(_on_cancel_difficulty)
	$ProloguePanel/BeginButton.pressed.connect(_on_begin_journey)
	$DifficultyPanel/EasyButton.mouse_entered.connect(_on_difficulty_hover.bind("Easy"))
	$DifficultyPanel/MediumButton.mouse_entered.connect(_on_difficulty_hover.bind("Medium"))
	$DifficultyPanel/HardButton.mouse_entered.connect(_on_difficulty_hover.bind("Hard"))
	$DifficultyPanel/EasyButton.mouse_exited.connect(_on_difficulty_hover_end)
	$DifficultyPanel/MediumButton.mouse_exited.connect(_on_difficulty_hover_end)
	$DifficultyPanel/HardButton.mouse_exited.connect(_on_difficulty_hover_end)
	style_difficulty_button($DifficultyPanel/EasyButton, "Easy")
	style_difficulty_button($DifficultyPanel/MediumButton, "Medium")
	style_difficulty_button($DifficultyPanel/HardButton, "Hard")
	build_hard_button_fire()
	update_buttons()
	update_deepest_level_label()
	# Headless test hook: MONARCH_TEST=1 skips the menu into a fresh run with a
	# test driver script attached under root (it survives the scene change).
	var test_script = OS.get_environment("MONARCH_TEST")
	if test_script != "" and ResourceLoader.exists(test_script):
		GameState.reset_for_new_game()
		var tester = Node.new()
		tester.set_script(load(test_script))
		get_tree().root.add_child.call_deferred(tester)
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")

const HARD_FIRE_COUNT = 14
const HARD_FIRE_COLORS = [
	Color(0.85, 0.12, 0.03, 0.9),
	Color(0.95, 0.4, 0.04, 0.88),
	Color(1.0, 0.65, 0.1, 0.8),
]

# A ring of small flickering flame tongues radiating outward from the Hard
# button's edges, plus a soft pulsing ember glow behind them (additive
# blend, same technique as the sun/moon glow in day_night_cycle.gd -- normal
# alpha blending can't read as "glowing", only additive genuinely brightens).
func build_hard_button_fire() -> void:
	var button = $DifficultyPanel/HardButton
	var center = button.position + button.size / 2.0
	var half_w = button.size.x / 2.0 + 6.0
	var half_h = button.size.y / 2.0 + 6.0

	var fire_container = Node2D.new()
	fire_container.position = center
	$DifficultyPanel.add_child(fire_container)
	$DifficultyPanel.move_child(fire_container, button.get_index())

	for i in range(HARD_FIRE_COUNT):
		var angle = i * TAU / float(HARD_FIRE_COUNT)
		var edge_point = Vector2(cos(angle) * half_w, sin(angle) * half_h)
		var out_dir = edge_point.normalized()
		var base_len = randf_range(9.0, 16.0)
		var perp = Vector2(-out_dir.y, out_dir.x) * randf_range(3.0, 5.0)
		var flame = Polygon2D.new()
		flame.color = HARD_FIRE_COLORS[randi() % HARD_FIRE_COLORS.size()]
		flame.polygon = PackedVector2Array([edge_point - perp, edge_point + perp, edge_point + out_dir * base_len])
		fire_container.add_child(flame)
		animate_flame(flame, edge_point, perp, out_dir, base_len)

func animate_flame(flame: Polygon2D, edge_point: Vector2, perp: Vector2, out_dir: Vector2, base_len: float) -> void:
	var tall = base_len * randf_range(1.5, 2.1)
	var short = base_len * randf_range(0.55, 0.8)
	var duration = randf_range(0.22, 0.45)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(func(l): flame.polygon = PackedVector2Array([edge_point - perp, edge_point + perp, edge_point + out_dir * l]), base_len, tall, duration)
	tween.tween_method(func(l): flame.polygon = PackedVector2Array([edge_point - perp, edge_point + perp, edge_point + out_dir * l]), tall, short, duration)
	tween.tween_method(func(l): flame.polygon = PackedVector2Array([edge_point - perp, edge_point + perp, edge_point + out_dir * l]), short, base_len, duration)

func style_difficulty_button(button: Button, difficulty: String) -> void:
	var palette = DIFFICULTY_COLORS[difficulty]
	for state in ["normal", "hover", "pressed"]:
		var box = StyleBoxFlat.new()
		box.bg_color = palette.bg.lightened(0.12) if state == "hover" else (palette.bg.darkened(0.15) if state == "pressed" else palette.bg)
		box.border_color = palette.border
		box.border_width_left = 2
		box.border_width_right = 2
		box.border_width_top = 2
		box.border_width_bottom = 2
		box.corner_radius_top_left = 4
		box.corner_radius_top_right = 4
		box.corner_radius_bottom_left = 4
		box.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.9, 1))

func _on_difficulty_hover(difficulty: String) -> void:
	$DifficultyPanel/DescriptionLabel.text = DIFFICULTY_DESCRIPTIONS.get(difficulty, DIFFICULTY_DEFAULT_HINT)

func _on_difficulty_hover_end() -> void:
	$DifficultyPanel/DescriptionLabel.text = DIFFICULTY_DEFAULT_HINT

func update_buttons() -> void:
	var has_save = GameState.has_save()
	$VBox/StartButton.visible = not has_save
	$VBox/ContinueButton.visible = has_save
	$VBox/NewGameButton.visible = has_save

func update_deepest_level_label() -> void:
	if GameState.deepest_level_reached > 0:
		$DeepestLevelLabel.text = "Deepest Level Reached: " + str(GameState.deepest_level_reached)
		$DeepestLevelLabel.visible = true

# ONE source of truth for the controls (polish 2026-07-20): the menu's
# baked-in panel had drifted years behind -- no L, no Z, no H, none of the
# laws. It now opens the SAME page the pause menu does, so the two can
# never disagree again. (The old panel stays in the scene, unused.)
func _on_how_to_play() -> void:
	var page = get_tree().get_first_node_in_group("how_to_play")
	if page == null:
		page = preload("res://how_to_play.gd").new()
		get_tree().root.add_child(page)
	page.open_page()

func _on_close_how_to_play() -> void:
	$HowToPlayPanel.visible = false
	var page = get_tree().get_first_node_in_group("how_to_play")
	if page != null:
		page.esc_close()

func _on_start() -> void:
	pending_delete_save = false
	$DifficultyPanel/DescriptionLabel.text = DIFFICULTY_DEFAULT_HINT
	$DifficultyPanel.visible = true

func _on_continue() -> void:
	GameState.pending_load = true
	get_tree().change_scene_to_file("res://main.tscn")

func _on_new_game() -> void:
	pending_delete_save = true
	$DifficultyPanel/DescriptionLabel.text = DIFFICULTY_DEFAULT_HINT
	$DifficultyPanel.visible = true

func _on_difficulty_chosen(difficulty: String) -> void:
	GameState.difficulty = difficulty
	if pending_delete_save:
		GameState.delete_save()
	# ALWAYS reset for a fresh run: BOTH Start (first-ever launch, no save file) and New Game
	# reach here, and without this a fresh install boots on bare var defaults -- no seeded
	# villagers, no starter blueprints, an empty larder, no Ten -- a broken first game.
	# Continue never comes through this path (it goes straight to _on_continue).
	GameState.reset_for_new_game()
	GameState.pending_load = false
	$DifficultyPanel.visible = false
	$ProloguePanel.visible = true

func _on_begin_journey() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_cancel_difficulty() -> void:
	$DifficultyPanel.visible = false

func _on_quit() -> void:
	get_tree().quit()
