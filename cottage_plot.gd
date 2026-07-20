extends Area2D

# The empty plot at the end of the cottage row (GAME_BIBLE 5.8): housing is
# BUILT, not free. Pay the materials, a cottage rises on the spot, and the
# plot shuffles one lot to the right for the next one. This is the hard
# brake on the population flywheel made touchable -- you can always SEE the
# next home the village needs.

const COST = {"wood": 8, "stone": 6}
const HOUSE_SCRIPT = preload("res://house.gd")
const HOUSE_SPACING = 160.0
const HOUSE_COLORS = [
	{"body": Color(0.65, 0.5, 0.35, 1.0), "roof": Color(0.5, 0.25, 0.2, 1.0)},
	{"body": Color(0.6, 0.55, 0.45, 1.0), "roof": Color(0.35, 0.3, 0.4, 1.0)},
	{"body": Color(0.55, 0.5, 0.4, 1.0), "roof": Color(0.45, 0.3, 0.2, 1.0)},
]

var player_inside := false

func _ready() -> void:
	add_to_group("village_structure")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true; $Prompt.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false; $Prompt.visible = false)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90.0, 90.0)
	shape.shape = rect
	shape.position = Vector2(0, -30.0)
	add_child(shape)
	# the plot itself: staked corners and a sign -- unmistakably "yours to build"
	for corner in [Vector2(-34, -4), Vector2(30, -4), Vector2(-34, -44), Vector2(30, -44)]:
		var stake := ColorRect.new()
		stake.size = Vector2(4, 10)
		stake.position = corner
		stake.color = Color(0.5, 0.4, 0.28, 1.0)
		add_child(stake)
	var sign_post := ColorRect.new()
	sign_post.size = Vector2(4, 22)
	sign_post.position = Vector2(-2, -22)
	sign_post.color = Color(0.45, 0.35, 0.25, 1.0)
	add_child(sign_post)
	var sign_board := ColorRect.new()
	sign_board.size = Vector2(34, 14)
	sign_board.position = Vector2(-17, -34)
	sign_board.color = Color(0.6, 0.5, 0.35, 1.0)
	add_child(sign_board)
	var label := Label.new()
	label.text = "Empty plot"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-45.0, -66.0)
	label.size = Vector2(90.0, 16.0)
	add_child(label)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.visible = false
	prompt.text = "[E] Raise a cottage — wood 8, stone 6"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-110.0, -50.0)
	prompt.size = Vector2(220.0, 16.0)
	add_child(prompt)

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		try_raise()

const MAX_RAISED := 15   # the east rampart (7.2) stands past the last possible lot

func try_raise() -> void:
	var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not "inventory" in player or player.inventory == null:
		return
	if GameState.extra_cottages >= MAX_RAISED:
		if notif:
			notif.show_notification("The row ends here — the east rampart guards this ground.")
		return
	var missing := []
	for mat in COST:
		if player.inventory.get_count(mat) < COST[mat]:
			missing.append("%s %d/%d" % [mat.capitalize(), player.inventory.get_count(mat), COST[mat]])
	if not missing.is_empty():
		if notif:
			notif.show_notification("A cottage needs: " + ", ".join(missing))
		return
	for mat in COST:
		player.inventory.remove_item(mat, int(COST[mat]))
	GameState.extra_cottages += 1
	GameState.play_sfx(GameState.SFX_THUD, 1.6, global_position)
	var idx: int = GameState.extra_cottages
	var house = HOUSE_SCRIPT.new()
	var palette: Dictionary = HOUSE_COLORS[idx % HOUSE_COLORS.size()]
	house.house_id = "extra_house_%d" % idx
	house.house_name = "Cottage %d" % (5 + idx)
	house.body_color = palette.body
	house.roof_color = palette.roof
	house.position = position
	get_parent().add_child(house)
	position.x += HOUSE_SPACING
	GameState.log_event("village", "A new cottage was raised — room for one more pair.")
	if notif:
		notif.show_notification("A new cottage stands — room for one more pair to call Deepwood home.")
