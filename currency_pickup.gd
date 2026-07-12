extends Area2D

const PICKUP_RADIUS = 14.0
const COIN_COLOR = Color(1.0, 0.85, 0.2, 1.0)
const RING_COLOR = Color(0.75, 0.55, 0.05, 1.0)

# "1 full in-game day" is defined by the day/night cycle's own day length,
# not a duplicated magic number here -- if that pacing ever changes, this
# follows it automatically.
const DESPAWN_SECONDS = preload("res://day_night_cycle.gd").DAY_LENGTH_SECONDS

var amount = 0

# When this pickup spawns exactly on top of the player (the death-drop case
# -- their body sits frozen right there for the whole death countdown),
# body_entered fires the instant it's created, which used to refund the
# currency almost immediately and made the drop look like it never
# happened. can_collect starts false in that case and only flips true once
# a real body_exited fires (the player actually leaving), so it only
# becomes collectible once they come back for it for real. Pickups spawned
# somewhere the player ISN'T already standing (not currently used, but
# supported) skip this and are collectible immediately.
var can_collect = true

func setup(drop_amount: int, spawned_on_player: bool = false) -> void:
	amount = drop_amount
	can_collect = not spawned_on_player

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
	shape.shape = circle
	add_child(shape)

	build_visual()
	start_bob()

	get_tree().create_timer(DESPAWN_SECONDS).timeout.connect(_on_expired)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		can_collect = true

func build_visual() -> void:
	var ring = Polygon2D.new()
	var ring_points = PackedVector2Array()
	for i in range(12):
		var angle = i * TAU / 12.0
		ring_points.append(Vector2(cos(angle), sin(angle)) * PICKUP_RADIUS)
	ring.polygon = ring_points
	ring.color = RING_COLOR
	add_child(ring)

	var coin = Polygon2D.new()
	var coin_points = PackedVector2Array()
	for i in range(12):
		var angle = i * TAU / 12.0
		coin_points.append(Vector2(cos(angle), sin(angle)) * (PICKUP_RADIUS * 0.7))
	coin.polygon = coin_points
	coin.color = COIN_COLOR
	add_child(coin)

	var label = Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.02, 1))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-PICKUP_RADIUS, -PICKUP_RADIUS * 0.6)
	label.size = Vector2(PICKUP_RADIUS * 2, PICKUP_RADIUS * 1.2)
	add_child(label)

func start_bob() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", -6.0, 0.7).as_relative()
	tween.tween_property(self, "position:y", 6.0, 0.7).as_relative()

func _on_body_entered(body: Node) -> void:
	if not can_collect:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("add_currency"):
		body.add_currency(amount)
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("Recovered " + str(amount) + " currency")
	queue_free()

func _on_expired() -> void:
	if is_inside_tree():
		queue_free()
