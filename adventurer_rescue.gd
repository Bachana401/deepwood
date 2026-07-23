extends Area2D

# A chained adventurer awaiting rescue in the dungeon (the deep nine of
# GAME_BIBLE 2.4.1). Press E to free them: they join the village defense roster
# (GameState.rescue_adventurer) and their avatar walks the village from the
# next visit on. Skipped forever once freed -- and if they later die defending
# the wall, they are gone for good, so every one of these is worth the detour.

var adventurer_id := ""
var _inside := false
var _prompt: Label = null

func _ready() -> void:
	var def = Adventurers.get_def(adventurer_id)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 90)
	cs.shape = rect
	cs.position = Vector2(0, -30)
	add_child(cs)
	# the captive: a kneeling figure in chains (procedural; art freeze)
	var body := ColorRect.new()
	body.size = Vector2(18, 30)
	body.position = Vector2(-9, -30)
	body.color = Color(0.3, 0.33, 0.42)
	add_child(body)
	var chain := ColorRect.new()
	chain.size = Vector2(30, 4)
	chain.position = Vector2(-15, -8)
	chain.color = Color(0.5, 0.5, 0.55)
	add_child(chain)
	var lbl := Label.new()
	lbl.text = str(def.get("name", "A captive"))
	lbl.position = Vector2(-80, -66)
	lbl.size = Vector2(160, 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	add_child(lbl)
	_prompt = Label.new()
	_prompt.text = "[E] Free them"
	_prompt.position = Vector2(-60, -50)
	_prompt.size = Vector2(120, 16)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(b): if b.is_in_group("player"): _inside = true; _prompt.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _inside = false; _prompt.visible = false)

func _process(_delta: float) -> void:
	if _inside and Input.is_action_just_pressed("interact"):
		_free()

func _free() -> void:
	GameState.rescue_adventurer(adventurer_id)
	# bank the rescue NOW so Continue can't undo it (autosave is otherwise every
	# 180s) -- same durability fix as the Sorrow-Crystal villagers, dev 2026-07-23
	GameState.autosave("freed %s" % str(Adventurers.get_def(adventurer_id).get("name", "an adventurer")))
	var def = Adventurers.get_def(adventurer_id)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and str(def.get("line", "")) != "":
		stack.show_notification("%s: \"%s\"" % [def.get("name", "?"), def.get("line", "")])
	queue_free()
