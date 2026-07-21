extends Area2D
# One of three rune stones that unbar a band's vault (underdark.gd). Press E.
# Deliberately dumb: it knows its band and its host, lights once, and tells the
# host. All the counting lives in one place.

var band := 0
var host: Node = null
var lit := false
var player_inside := false
var glyph: ColorRect = null
var prompt: Label = null

func _ready() -> void:
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110.0, 110.0)
	cs.shape = rect
	cs.position = Vector2(0, -40.0)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	var stone := Polygon2D.new()
	stone.color = Color(0.17, 0.16, 0.15)
	stone.polygon = PackedVector2Array([
		Vector2(-20, 0), Vector2(-14, -56), Vector2(14, -56), Vector2(20, 0)])
	stone.z_index = -1
	add_child(stone)
	glyph = ColorRect.new()
	glyph.size = Vector2(10, 22)
	glyph.position = Vector2(-5, -42)
	glyph.color = Color(0.28, 0.42, 0.7, 0.8)
	glyph.z_index = -1
	add_child(glyph)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-120.0, -104.0)
	prompt.size = Vector2(240.0, 20.0)
	prompt.visible = false
	prompt.z_index = 5
	add_child(prompt)

func _on_enter(body: Node2D) -> void:
	if not body.is_in_group("player") or lit:
		return
	player_inside = true
	prompt.text = "[E]  A cold rune, waiting"
	prompt.visible = true

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if lit or not player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		lit = true
		player_inside = false
		prompt.visible = false
		glyph.color = Color(1.0, 0.72, 0.25, 1.0)
		if host != null and is_instance_valid(host):
			host.rune_lit(band)
