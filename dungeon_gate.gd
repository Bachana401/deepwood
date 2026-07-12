extends Area2D

# One of the two doorways in every dungeon level (see dungeon_interior.gd):
#   "back"    -- left side, always usable. On level 1 it leaves the dungeon
#                entirely; on any deeper level it moves you back one level.
#   "forward" -- right side, only usable once the current level is CLEARED.
#                Advancing is always this manual step now -- clearing a level
#                no longer auto-teleports you forward.
var direction = "back"
var manager: Node = null

var player_inside = false
var prompt: Label
var frame_visual: Polygon2D
var glow: Polygon2D

const BACK_COLOR = Color(0.35, 0.55, 0.9, 1.0)
const FORWARD_READY_COLOR = Color(0.3, 0.85, 0.4, 1.0)
const FORWARD_LOCKED_COLOR = Color(0.35, 0.35, 0.38, 1.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(60, 100)
	shape.shape = rect
	shape.position = Vector2(0, -50)
	add_child(shape)

	build_visual()

	prompt = Label.new()
	prompt.visible = false
	prompt.z_index = 10
	prompt.position = Vector2(-110, -140)
	prompt.size = Vector2(220, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	add_child(prompt)

func build_visual() -> void:
	# a stone doorway: dark arch opening with a glowing inner portal whose
	# color signals state (blue = back, green = onward ready, grey = locked)
	var arch = Polygon2D.new()
	arch.polygon = PackedVector2Array([
		Vector2(-26, 0), Vector2(26, 0), Vector2(26, -78),
		Vector2(14, -92), Vector2(-14, -92), Vector2(-26, -78),
	])
	arch.color = Color(0.16, 0.13, 0.15, 1.0)
	add_child(arch)

	glow = Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(18, 0), Vector2(18, -72),
		Vector2(10, -84), Vector2(-10, -84), Vector2(-18, -72),
	])
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)

	frame_visual = Polygon2D.new()
	frame_visual.polygon = PackedVector2Array([
		Vector2(-20, 0), Vector2(20, 0), Vector2(20, -74),
		Vector2(11, -86), Vector2(-11, -86), Vector2(-20, -74),
	])
	add_child(frame_visual)

func current_color() -> Color:
	if direction == "back":
		return BACK_COLOR
	return FORWARD_READY_COLOR if (manager and manager.level_cleared) else FORWARD_LOCKED_COLOR

func prompt_text() -> String:
	if direction == "back":
		if manager and manager.current_level <= 1:
			return "Press E to Leave the Dungeon"
		return "Press E to Retreat a Level"
	if manager and manager.level_cleared:
		if manager.current_level >= manager.MAX_LEVEL:
			return "Press E to Leave -- Dungeon Complete!"
		return "Press E to Descend Deeper"
	return "Clear this level to unlock"

func _process(_delta: float) -> void:
	var color = current_color()
	frame_visual.color = Color(color.r, color.g, color.b, 0.55)
	glow.color = Color(color.r, color.g, color.b, 0.28)
	if player_inside:
		prompt.text = prompt_text()
	if player_inside and Input.is_action_just_pressed("interact") and manager:
		manager.on_gate_used(direction)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt.visible = false
