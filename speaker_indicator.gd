class_name SpeakerIndicator
extends Node2D
# A small bobbing chevron that hovers over whoever is currently speaking in a
# scripted DialogueBox, so the player can see WHOSE line is on screen. Tinted to
# match that speaker's name-plate accent (same color as the box), which links the
# floating name to the body. Runs while the tree is paused (the box pauses it).
#
# NO GLOW (dev call 2026-07-27: "brightness/shininess around the indicator is
# silly, indicator not visible"). It used to be an ADDITIVE node under a
# seven-disc radial bloom, which fought its own background two ways: additive
# blending washed the shape out over anything bright, and the bloom read as a
# vague shiny blob rather than an arrow. It is now a flat, solid, outlined
# chevron -- a shape, not a light -- so it stays legible on any background.

var accent: Color = Color(0.82, 0.68, 0.34)
var _tx: float = 0.0
var _ty: float = 0.0
var _t: float = 0.0

const W := 15.0          # half-width of the chevron
const H := 15.0          # height, tip to shoulders
const OUTLINE := 3.0     # dark keyline, so it reads on light AND dark ground

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
	global_position = Vector2(_tx, _ty + sin(_t * 4.0) * 3.0)   # gentle bob
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	# a downward-pointing triangle: shoulders up top, tip at the speaker's head
	var tip := Vector2(0.0, 0.0)
	var left := Vector2(-W, -H)
	var right := Vector2(W, -H)
	# 1) dark keyline first (a slightly larger triangle behind the fill), so the
	#    marker never disappears into a pale wall or a bright torch
	var k := 1.0 + OUTLINE / H
	draw_colored_polygon(PackedVector2Array([left * k, right * k, tip * k]),
		Color(0.05, 0.04, 0.06, 0.9))
	# 2) the solid body in the speaker's own accent -- flat, fully opaque
	draw_colored_polygon(PackedVector2Array([left, right, tip]), accent)
	# 3) one bright band along the top edge for a little shape, NOT a glow
	draw_line(left, right, accent.lightened(0.45), 2.5)
