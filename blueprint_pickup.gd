extends Area2D

# A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building,
# lost to the deep when Deepwood fell, lying at its fixed floor. E to take.
# Procedural: a leather roll with a paper scroll poking out, pulsing gently
# so it reads as a pickup among the gloom.

var building_name := ""
var player_inside := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46.0, 40.0)
	cs.shape = rect
	cs.position = Vector2(0, -16.0)
	add_child(cs)
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true; $Prompt.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false; $Prompt.visible = false)
	var roll := ColorRect.new()
	roll.size = Vector2(26, 10)
	roll.position = Vector2(-13, -12)
	roll.color = Color(0.5, 0.36, 0.22, 1.0)
	add_child(roll)
	var scroll := ColorRect.new()
	scroll.size = Vector2(18, 14)
	scroll.position = Vector2(-9, -24)
	scroll.color = Color(0.88, 0.84, 0.7, 1.0)
	add_child(scroll)
	var lines := ColorRect.new()
	lines.size = Vector2(12, 2)
	lines.position = Vector2(-6, -19)
	lines.color = Color(0.35, 0.45, 0.65, 1.0)
	add_child(lines)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.visible = false
	prompt.text = "[E] Take the %s blueprint" % building_name
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-130.0, -52.0)
	prompt.size = Vector2(260.0, 16.0)
	add_child(prompt)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "modulate:a", 0.7, 0.9)
	tw.tween_property(self, "modulate:a", 1.0, 0.9)

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		GameState.grant_blueprint(building_name)
		queue_free()
