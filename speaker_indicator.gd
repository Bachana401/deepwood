class_name SpeakerIndicator
extends Node2D
# A small GLOWING, bobbing chevron that hovers over whoever is currently speaking
# in a scripted DialogueBox, so the player can see WHOSE line is on screen. Tinted
# to match that speaker's name-plate accent (same color as the box), which links
# the floating name to the body. The glow is additive so it reads on the dark
# night of the arrival. Runs while the tree is paused (the box pauses it).

var accent: Color = Color(0.82, 0.68, 0.34)
var _tx: float = 0.0
var _ty: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4000            # ride above characters, buildings and the world
	z_as_relative = false
	# additive blend -> the halo ADDS light to whatever is behind it, so it glows
	# against the dark instead of just sitting on top as a flat shape
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

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
	var pulse := 0.5 + 0.5 * sin(_t * 3.5)          # 0..1, slow breathing
	var c := Vector2(0.0, -7.0)                       # glow centre, over the chevron
	# soft radial halo: several additive discs, big+faint to small+bright, so they
	# stack into a warm bloom at the centre
	var layers := 7
	for i in range(layers):
		var f := float(i) / float(layers - 1)        # 0 (outer) .. 1 (inner)
		var r: float = lerp(36.0, 7.0, f) * (1.0 + 0.14 * pulse)
		var a: float = lerp(0.05, 0.20, f) * (0.75 + 0.6 * pulse)
		draw_circle(c, r, Color(accent.r, accent.g, accent.b, a))
	# the chevron itself, bright, pointing straight down at the speaker's head
	var w := 12.0
	var h := 10.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(0.0, 0.0)]), accent.lightened(0.35))
	# a hot top edge so it stays crisp on top of its own bloom
	draw_line(Vector2(-w, -h), Vector2(w, -h), accent.lightened(0.65), 2.0)
