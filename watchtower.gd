extends Area2D

# THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone
# structure beside the west rampart: pay the tier, the tower grows, and the
# night gets more honest with you. Tier 0 is a staked plot and true chaos;
# tier 1 raises the frame and makes the siege clock VISIBLE at all (plus a
# 1-hour bell); tier 2 adds the bell-and-brazier (2h); tier 3 the
# far-seeing flame (24h -- plan whole delves around known windows).
# Procedural build (art freeze); grows taller with each tier.

var player_inside := false
var gfx: Node2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b.is_in_group("player"): player_inside = true; $Prompt.visible = true; _refresh_prompt())
	body_exited.connect(func(b): if b.is_in_group("player"): player_inside = false; $Prompt.visible = false)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110.0, 140.0)
	shape.shape = rect
	shape.position = Vector2(0, -50.0)
	add_child(shape)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.visible = false
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-150.0, -170.0)
	prompt.size = Vector2(300.0, 32.0)
	add_child(prompt)
	build_visual()

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for mat in cost:
		parts.append("%s %d" % [str(mat).replace("_", " "), int(cost[mat])])
	return ", ".join(parts)

func _refresh_prompt() -> void:
	var tier: int = GameState.watchtower_tier
	if tier >= 3:
		$Prompt.text = "The far-seeing flame burns — 24h of warning."
	else:
		var cost: Dictionary = GameState.WATCHTOWER_COSTS[tier]
		var what: String = ["Raise the Watchtower", "Hang the bell and brazier", "Kindle the far-seeing flame"][tier]
		var gain: String = ["see the siege clock + 1h bell", "2h of warning", "24h of warning"][tier]
		$Prompt.text = "[E] %s — %s  (%s)" % [what, _cost_text(cost), gain]

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		try_upgrade()

func try_upgrade() -> void:
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	var tier: int = GameState.watchtower_tier
	if tier >= 3:
		if notif:
			notif.show_notification("The tower sees as far as a tower can.")
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not "inventory" in player or player.inventory == null:
		return
	var cost: Dictionary = GameState.WATCHTOWER_COSTS[tier]
	var missing := []
	for mat in cost:
		if player.inventory.get_count(mat) < int(cost[mat]):
			missing.append("%s %d/%d" % [str(mat).replace("_", " "), player.inventory.get_count(mat), int(cost[mat])])
	if not missing.is_empty():
		if notif:
			notif.show_notification("The tower needs: " + ", ".join(missing))
		return
	for mat in cost:
		player.inventory.remove_item(mat, int(cost[mat]))
	GameState.watchtower_tier = tier + 1
	build_visual()
	_refresh_prompt()
	var lines = [
		"The Watchtower stands — the siege clock is yours to read, and its bell gives an hour.",
		"The bell and brazier hang — two hours of warning now.",
		"The far-seeing flame is lit — a full day's warning. Plan your delves around the dark.",
	]
	if notif:
		notif.show_notification("🗼 " + lines[tier])
	GameState.log_event("village", ["The Watchtower was raised.", "The Watchtower's bell was hung.", "The far-seeing flame was kindled."][tier])

# The tower grows with its tier: staked plot -> timber frame -> bell story
# with brazier -> the flame. All procedural, grounded at y=0.
func build_visual() -> void:
	if gfx:
		gfx.queue_free()
	gfx = Node2D.new()
	add_child(gfx)
	var tier: int = GameState.watchtower_tier
	if tier <= 0:
		for corner in [Vector2(-30, -4), Vector2(26, -4), Vector2(-30, -40), Vector2(26, -40)]:
			var stake := ColorRect.new()
			stake.size = Vector2(4, 10)
			stake.position = corner
			stake.color = Color(0.5, 0.4, 0.28, 1.0)
			gfx.add_child(stake)
		var sign_board := ColorRect.new()
		sign_board.size = Vector2(40, 14)
		sign_board.position = Vector2(-20, -30)
		sign_board.color = Color(0.6, 0.5, 0.35, 1.0)
		gfx.add_child(sign_board)
		return
	var height := 70.0 + 40.0 * tier
	var body := ColorRect.new()
	body.size = Vector2(34, height)
	body.position = Vector2(-17, -height)
	body.color = Color(0.45, 0.42, 0.4, 1.0)
	gfx.add_child(body)
	for i in range(1, tier + 2):
		var seam := ColorRect.new()
		seam.size = Vector2(34, 2)
		seam.position = Vector2(-17, -height * i / float(tier + 2))
		seam.color = Color(0.34, 0.32, 0.3, 1.0)
		gfx.add_child(seam)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(-24, -height), Vector2(24, -height), Vector2(0, -height - 26)])
	roof.color = Color(0.4, 0.26, 0.2, 1.0)
	gfx.add_child(roof)
	if tier >= 2:
		var bell := ColorRect.new()
		bell.size = Vector2(10, 12)
		bell.position = Vector2(-5, -height - 14)
		bell.color = Color(0.75, 0.65, 0.3, 1.0)
		gfx.add_child(bell)
	if tier >= 3:
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([Vector2(-6, -height - 26), Vector2(6, -height - 26), Vector2(0, -height - 44)])
		flame.color = Color(0.95, 0.7, 0.3, 0.9)
		gfx.add_child(flame)
		var t := flame.create_tween()
		t.set_loops()
		t.tween_property(flame, "modulate:a", 0.6, 0.5)
		t.tween_property(flame, "modulate:a", 1.0, 0.5)
