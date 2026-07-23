extends Area2D

# A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the
# Ten -- a legend he has tried for years to break and never cracked. Found deep
# in a non-boss floor, past the fighting; press E to tear it open. Freeing them
# grants their permanent village boon (GameState.free_one_of_the_ten) and moves
# the finale gate one step closer to opening.

var ten_id := ""
var _inside := false
var _prompt: Label = null

func _ready() -> void:
	var def = TheTen.get_def(ten_id)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110, 110)
	cs.shape = rect
	cs.position = Vector2(0, -36)
	add_child(cs)
	# the vault: gilded bars around a figure that stands unbowed
	var back := ColorRect.new()
	back.size = Vector2(52, 64)
	back.position = Vector2(-26, -66)
	back.color = Color(0.12, 0.1, 0.16)
	add_child(back)
	var figure := ColorRect.new()
	figure.size = Vector2(16, 40)
	figure.position = Vector2(-8, -46)
	figure.color = Color(0.75, 0.7, 0.6)   # unbowed, upright -- not kneeling
	add_child(figure)
	for i in range(5):
		var bar := ColorRect.new()
		bar.size = Vector2(4, 64)
		bar.position = Vector2(-26 + i * 12, -66)
		bar.color = Color(0.85, 0.7, 0.3)   # gilded: a trophy, not a prison cell
		add_child(bar)
	var crown := ColorRect.new()
	crown.size = Vector2(60, 5)
	crown.position = Vector2(-30, -72)
	crown.color = Color(0.9, 0.78, 0.35)
	add_child(crown)
	# the name overhead, in trophy gold
	var lbl := Label.new()
	lbl.text = "%s, %s" % [def.get("name", "?"), def.get("title", "")]
	lbl.position = Vector2(-120, -98)
	lbl.size = Vector2(240, 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 40
	add_child(lbl)
	var sub := Label.new()
	sub.text = "one of the Ten"
	sub.position = Vector2(-80, -84)
	sub.size = Vector2(160, 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("outline_size", 3)
	sub.z_index = 40
	add_child(sub)
	_prompt = Label.new()
	_prompt.text = "[E] Tear the vault open"
	_prompt.position = Vector2(-90, -70)
	_prompt.size = Vector2(180, 16)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	_prompt.z_index = 41
	add_child(_prompt)
	body_entered.connect(func(b): if b.is_in_group("player"): _inside = true; _prompt.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _inside = false; _prompt.visible = false)

func _process(_delta: float) -> void:
	if _inside and Input.is_action_just_pressed("interact"):
		_free()

func _free() -> void:
	GameState.free_one_of_the_ten(ten_id)
	# freeing one of the Ten is a permanent boon -- bank it NOW so Continue can't
	# undo it (autosave is otherwise every 180s), dev 2026-07-23
	GameState.autosave("freed %s of the Ten" % str(TheTen.get_def(ten_id).get("name", "one")))
	var def = TheTen.get_def(ten_id)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and str(def.get("line", "")) != "":
		stack.show_notification("%s: \"%s\"" % [def.get("name", "?"), def.get("line", "")])
	queue_free()
