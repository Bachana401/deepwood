extends Area2D

# THE ROAD MARKERS (polish 2026-07-20) -- the village and the pit sit
# ~5,200px apart, which is 26 seconds of holding D EACH WAY, every single
# delve. Over a real session that is ten minutes of nothing. The road
# between your own gate and the hole you climb into is a road you have
# walked a hundred times: press E at either marker and you are at the
# other. No unlock, no cost -- it is your valley, and the walk was never
# the game.

@export var partner_x: float = 0.0
@export var marker_label: String = "the village"

var player_inside := false

func _ready() -> void:
	add_to_group("village_structure")   # never buried by a relocated building
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true; $Prompt.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false; $Prompt.visible = false)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70.0, 90.0)
	cs.shape = rect
	cs.position = Vector2(0, -45.0)
	add_child(cs)
	# a leaning signpost with two arms
	var post := ColorRect.new()
	post.size = Vector2(5, 62)
	post.position = Vector2(-2, -62)
	post.color = Color(0.45, 0.34, 0.22, 1.0)
	add_child(post)
	for arm_y in [-56.0, -44.0]:
		var arm := ColorRect.new()
		arm.size = Vector2(30, 8)
		arm.position = Vector2(2, arm_y)
		arm.color = Color(0.6, 0.5, 0.34, 1.0)
		add_child(arm)
	var glow := ColorRect.new()
	glow.size = Vector2(14, 14)
	glow.position = Vector2(-7, -76)
	glow.color = Color(0.85, 0.75, 0.4, 0.75)
	add_child(glow)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(glow, "modulate:a", 0.45, 1.1)
	tw.tween_property(glow, "modulate:a", 1.0, 1.1)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.visible = false
	prompt.text = "[E] Take the road to %s" % marker_label
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-120.0, -102.0)
	prompt.size = Vector2(240.0, 16.0)
	add_child(prompt)

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		travel()

func travel() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# the walk is skipped, not the danger: arrive on your feet, standing
	player.global_position = Vector2(partner_x, player.global_position.y)
	player.velocity = Vector2.ZERO
	player_inside = false
	$Prompt.visible = false
	GameState.play_sfx(GameState.SFX_CHIME, 0.8, global_position)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("You take the old road to %s." % marker_label)
