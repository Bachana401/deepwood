class_name SpeakerIndicator
extends Node2D
# A small bobbing chevron that hovers over whoever is currently speaking in a
# scripted DialogueBox, so the player can see WHOSE line is on screen. Tinted to
# match that speaker's name-plate accent (same color as the box), which links the
# floating name to the body. Runs while the tree is paused (the box pauses it).

var accent: Color = Color(0.82, 0.68, 0.34)
var _tx: float = 0.0
var _ty: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4000            # ride above characters, buildings and the world
	z_as_relative = false

# Point at a world position (already offset above the head) in the given tint.
func place(world_pos: Vector2, tint: Color) -> void:
	_tx = world_pos.x
	_ty = world_pos.y
	accent = tint
	visible = true
	global_position = world_pos
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	global_position = Vector2(_tx, _ty + sin(_t * 5.0) * 3.5)   # gentle bob
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var w := 13.0
	var h := 11.0
	# a black backing triangle so the mark reads on any background
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w - 2.5, -h - 2.5), Vector2(w + 2.5, -h - 2.5), Vector2(0.0, 3.5)]),
		Color(0, 0, 0, 0.75))
	# the accent chevron, pointing straight down at the speaker's head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(0.0, 0.0)]), accent)
	# a bright top edge so it reads as a solid tab, not a flat triangle
	draw_line(Vector2(-w, -h), Vector2(w, -h), accent.lightened(0.4), 2.0)
