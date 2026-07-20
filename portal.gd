extends Area2D

# ONE RIFT of the Mage's Riftweaving pair (mg_p1..p3, dev request
# 2026-07-20 -- yes, THAT game): the orange door and the blue door. Step
# into either and you exit the other. The player node owns the pair, pays
# the opening cost, and bleeds the drain while both stand; this node is
# just the standing door -- an ellipse of light with a lazy inner swirl,
# procedural (art freeze), grounded at the feet of wherever it was cast.

var owner_player: Node2D = null
var is_orange := true

const RING = [
	Color(0.95, 0.55, 0.15, 0.9),   # orange door
	Color(0.25, 0.55, 0.95, 0.9),   # blue door
]

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2               # the player's body layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30.0, 62.0)
	cs.shape = rect
	cs.position = Vector2(0, -31.0)
	add_child(cs)
	body_entered.connect(_on_body)
	var col: Color = RING[0] if is_orange else RING[1]
	# the door: an ellipse ring, a dimmer inner veil, a slow swirl
	var ring := Line2D.new()
	ring.width = 3.5
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 15.0, -31.0 + sin(a) * 31.0))
	ring.points = pts
	add_child(ring)
	var veil := Polygon2D.new()
	var vp := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		vp.append(Vector2(cos(a) * 12.0, -31.0 + sin(a) * 27.0))
	veil.polygon = vp
	veil.color = Color(col.r, col.g, col.b, 0.28)
	add_child(veil)
	var swirl := Line2D.new()
	swirl.width = 2.0
	swirl.default_color = Color(1, 1, 1, 0.5)
	var sp := PackedVector2Array()
	for i in range(16):
		var t := float(i) / 15.0
		var a := t * TAU * 1.5
		sp.append(Vector2(cos(a) * 9.0 * (1.0 - t), -31.0 + sin(a) * 20.0 * (1.0 - t)))
	swirl.points = sp
	add_child(swirl)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(self, "modulate:a", 0.7, 0.7)
	tw.tween_property(self, "modulate:a", 1.0, 0.7)
	var rot := swirl.create_tween()
	rot.set_loops()
	rot.tween_property(swirl, "rotation", TAU, 2.4).from(0.0)

func _on_body(b: Node) -> void:
	# teleporting moves a physics body -- always DEFERRED, never mid-flush
	if b.is_in_group("player") and owner_player != null and is_instance_valid(owner_player):
		owner_player.call_deferred("do_portal_teleport", self)

func collapse() -> void:
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.22)
	tw.tween_callback(queue_free)
