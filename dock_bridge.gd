extends StaticBody2D

# A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a
# plank bridge across, stairs down. The COLLISION is a smooth ramp-deck-ramp
# trapezoid on the ground layer -- so the player, NPCs and enemies all walk it
# naturally with move_and_slide (a ~24 degree slope, well under the 45 degree
# floor limit) -- while the VISUAL draws real stair steps on both ends.
# Placed by main.gd centred on the dock, slightly wider than the water.

var span := 900.0          # total footprint width (stairs included)
var deck_height := 40.0    # how high the deck sits above the ground line
var stair_width := 90.0    # horizontal run of each staircase

const WOOD = Color(0.52, 0.38, 0.22)
const WOOD_D = Color(0.4, 0.29, 0.16)
const WOOD_L = Color(0.62, 0.47, 0.28)

func _ready() -> void:
	add_to_group("dock_bridge")   # so deleting the Dock can take its deck with it
	collision_layer = 1   # ground layer: everyone stands on it
	collision_mask = 0
	build_collision()
	build_visual()

func build_collision() -> void:
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-span / 2.0, 0),
		Vector2(-span / 2.0 + stair_width, -deck_height),
		Vector2(span / 2.0 - stair_width, -deck_height),
		Vector2(span / 2.0, 0),
	])
	add_child(poly)

func _rect(pos: Vector2, size: Vector2, col: Color) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func build_visual() -> void:
	var steps := 5
	var sw = stair_width / steps
	# stair steps on both ends (aligned to the collision ramps)
	for i in range(steps):
		var sh = deck_height * float(i + 1) / float(steps)
		var col = WOOD_D if i % 2 == 0 else WOOD
		_rect(Vector2(-span / 2.0 + i * sw, -sh), Vector2(sw + 1.0, sh), col)           # left, ascending
		_rect(Vector2(span / 2.0 - (i + 1) * sw, -sh), Vector2(sw + 1.0, sh), col)      # right, descending
	# deck
	var deck_l = -span / 2.0 + stair_width
	var deck_w = span - stair_width * 2.0
	_rect(Vector2(deck_l, -deck_height), Vector2(deck_w, 10.0), WOOD)
	_rect(Vector2(deck_l, -deck_height), Vector2(deck_w, 3.0), WOOD_L)   # worn top edge
	# plank seams
	var seams = max(2, int(deck_w / 46.0))
	for i in range(1, seams):
		_rect(Vector2(deck_l + i * deck_w / seams, -deck_height + 2.0), Vector2(1.6, 8.0), WOOD_D)
	# far-side handrail (drawn behind characters -> reads as the back rail)
	var rail_posts = max(3, int(deck_w / 110.0))
	for i in range(rail_posts + 1):
		var px = deck_l + i * deck_w / rail_posts
		_rect(Vector2(px - 2.0, -deck_height - 24.0), Vector2(4.0, 24.0), WOOD_D)
	_rect(Vector2(deck_l, -deck_height - 26.0), Vector2(deck_w, 4.0), WOOD_L)
	# support posts sunk into the water below the deck
	var posts = max(3, int(deck_w / 120.0))
	for i in range(posts + 1):
		var px = deck_l + i * deck_w / posts
		_rect(Vector2(px - 3.0, -deck_height + 10.0), Vector2(6.0, deck_height + 4.0), WOOD_D)
