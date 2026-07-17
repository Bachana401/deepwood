extends Area2D

# A Proving Grounds vault chest. Labelled with what it holds; press E while
# standing on it to drop every item in its list straight into the bag. Set
# `item_ids`, `title`, `subtitle`, and `accent` before adding it to the tree.

var item_ids: Array = []
var title := "CHEST"
var subtitle := ""
var accent := Color(0.8, 0.8, 0.85)
var _inside := false
var _prompt: Label = null
var _taken := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2         # detect the player body (player is on layer 2)
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 96)
	cs.shape = rect
	cs.position = Vector2(0, -30)
	add_child(cs)
	# chest body
	var base := ColorRect.new()
	base.size = Vector2(58, 34); base.position = Vector2(-29, -34)
	base.color = accent.darkened(0.35)
	add_child(base)
	var lid := ColorRect.new()
	lid.size = Vector2(62, 16); lid.position = Vector2(-31, -48)
	lid.color = accent
	add_child(lid)
	var lock := ColorRect.new()
	lock.size = Vector2(8, 10); lock.position = Vector2(-4, -40)
	lock.color = Color(1, 0.9, 0.5)
	add_child(lock)
	# glowing rank tint at the base
	var glow := ColorRect.new()
	glow.size = Vector2(66, 4); glow.position = Vector2(-33, -2)
	glow.color = Color(accent.r, accent.g, accent.b, 0.6)
	add_child(glow)
	# label overhead: title + short "what's inside"
	var lbl := Label.new()
	lbl.position = Vector2(-110, -108)
	lbl.size = Vector2(220, 54)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = title + ("\n" + subtitle if subtitle != "" else "")
	lbl.add_theme_color_override("font_color", accent)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 40
	add_child(lbl)
	# E prompt (hidden until you're on it)
	_prompt = Label.new()
	_prompt.position = Vector2(-60, -70)
	_prompt.size = Vector2(120, 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.text = "[E] Take all"
	_prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	_prompt.z_index = 41
	add_child(_prompt)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _process(_delta: float) -> void:
	if _inside and Input.is_action_just_pressed("interact"):
		_grant()

func _grant() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not ("inventory" in p) or p.inventory == null:
		return
	var n := 0
	for id in item_ids:
		if p.inventory.add_item(id, 1) > 0 or true:   # count added; chests always try
			n += 1
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack != null and stack.has_method("show_notification"):
		stack.show_notification("%s: took %d items" % [title, n])
	if _prompt != null:
		_prompt.text = "taken ✓"

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		if _prompt != null and _prompt.text.begins_with("["):
			_prompt.visible = true

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		if _prompt != null:
			_prompt.visible = false
