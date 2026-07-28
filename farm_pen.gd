extends Node2D

# A fenced pasture beside the Farm. Draws the fence + a dirt patch and spawns a
# few animals that wander only within it (they never leave; see farm_animal.gd).
# Placed by main.gd in its own reserved slot next to the Farm.

const ANIMAL_SCRIPT = preload("res://farm_animal.gd")

var pen_width := 360.0
var animals_spec := ["chicken", "chicken", "pig", "cow", "sheep"]

func _ready() -> void:
	add_to_group("farm_pen")   # so deleting the Farm can take its pasture with it
	build_fence()
	spawn_animals()

func build_fence() -> void:
	var half = pen_width * 0.5
	# dirt/hay ground patch (drawn BEHIND the animals)
	var dirt = ColorRect.new()
	dirt.position = Vector2(-half, -7)
	dirt.size = Vector2(pen_width, 11)
	dirt.color = Color(0.46, 0.37, 0.23)
	dirt.z_index = -2
	add_child(dirt)
	# a few grass tufts on the dirt
	for i in range(int(pen_width / 60.0)):
		var g = ColorRect.new()
		g.position = Vector2(-half + 30 + i * 60 + randf_range(-10, 10), -9)
		g.size = Vector2(6, 5)
		g.color = Color(0.3, 0.45, 0.24)
		g.z_index = -1
		add_child(g)

	# fence posts + rails drawn IN FRONT of the animals so they read as penned in
	var post_h = 32.0
	var posts = 9
	for i in range(posts + 1):
		var px = lerp(-half, half, float(i) / float(posts))
		var post = ColorRect.new()
		post.position = Vector2(px - 2.5, -post_h)
		post.size = Vector2(5, post_h)
		post.color = Color(0.42, 0.29, 0.16)
		post.z_index = 4
		add_child(post)
	for ry in [-post_h * 0.4, -post_h * 0.78]:
		var rail = Line2D.new()
		rail.points = PackedVector2Array([Vector2(-half, ry), Vector2(half, ry)])
		rail.width = 4.0
		rail.default_color = Color(0.5, 0.36, 0.2)
		rail.z_index = 4
		add_child(rail)

	# little "Pasture" sign
	var sign = Label.new()
	sign.text = "Pasture"
	sign.position = Vector2(-half + 6, -post_h - 20)
	sign.add_theme_font_size_override("font_size", 12)
	sign.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	sign.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sign.add_theme_constant_override("outline_size", 4)
	add_child(sign)

func spawn_animals() -> void:
	var half = pen_width * 0.5
	var margin = 30.0
	for spec in animals_spec:
		var a = ANIMAL_SCRIPT.new()
		var lo = global_position.x - half + margin
		var hi = global_position.x + half - margin
		a.setup(spec, lo, hi, global_position.y)
		a.z_index = 1   # on the dirt, behind the front fence rail (penned)
		add_child(a)
		a.global_position = Vector2(randf_range(lo, hi), global_position.y)
