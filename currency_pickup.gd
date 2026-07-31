extends Area2D

const PICKUP_RADIUS = 14.0
const COIN_COLOR = Color(1.0, 0.85, 0.2, 1.0)
const RING_COLOR = Color(0.75, 0.55, 0.05, 1.0)

# "1 full in-game day" is defined by the day/night cycle's own day length,
# not a duplicated magic number here -- if that pacing ever changes, this
# follows it automatically.
const DESPAWN_SECONDS = preload("res://day_night_cycle.gd").DAY_LENGTH_SECONDS

var amount = 0
var _label: Label = null   # kept so a merged spill can update its number

# ============================ COINS THAT LIVE ============================
# A coin used to be a circle bobbing on a loop from the instant it appeared.
# Now it is TOSSED, it falls, it lands, and only then does it settle -- and if
# it lands in water it DROWNS, sinking with a wobble and a thread of bubbles.
#
# THE RULE THAT MATTERS: water never eats your money. A coin that sinks out of
# the pool is paid straight into your purse on its way out. You lose the coin,
# never the gold. (And if your bag is full at that moment it simply waits on
# the bottom rather than vanishing into nothing -- the same courtesy the
# spilled piles already get on land.)
enum { FALL, REST, DROWN, SUNK }
var _state := FALL
var _vel := Vector2.ZERO
var _bob_tween: Tween = null
var _wobble := 0.0
var _sunk := 0.0

const GRAVITY := 900.0
const BOUNCE := 0.36           # a coin is not a rubber ball
const TOSS_UP := 210.0
const TOSS_SIDE := 95.0
const SINK_SPEED := 34.0       # slow. Watching it go is the point.
const SINK_DRAG := 6.0
const BOTTOMLESS := 900.0      # sank this far and found no floor: there isn't one

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
	add_to_group("currency_pickup")   # so a full-bag spill can merge into one pile
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
	# TOSSED, not placed. Every coin leaves its source with a little arc of its
	# own, so a spill reads as a scatter rather than as one object appearing.
	_vel = Vector2(randf_range(-TOSS_SIDE, TOSS_SIDE), -TOSS_UP * randf_range(0.75, 1.0))
	_state = FALL

	get_tree().create_timer(DESPAWN_SECONDS).timeout.connect(_on_expired)

func _physics_process(delta: float) -> void:
	match _state:
		FALL:
			_vel.y += GRAVITY * delta
			global_position += _vel * delta
			if _enter_water_if_wet():
				return
			var floor_y := _ground_below()
			if not is_nan(floor_y) and global_position.y >= floor_y and _vel.y > 0.0:
				global_position.y = floor_y
				if absf(_vel.y) > 60.0:
					_vel.y = -_vel.y * BOUNCE          # one or two small hops
					_vel.x *= 0.55
				else:
					_vel = Vector2.ZERO
					_state = REST
					start_bob()
		REST:
			# a coin can be flooded where it lies -- rising water, a new pool
			if _enter_water_if_wet():
				return
		DROWN:
			# IT GOES TO THE BOTTOM. Not to some arbitrary depth and out of
			# existence -- it sinks until it lands on the floor of the pool and
			# then it LIES THERE, in the water, where you can see it and go and
			# get it. A coin at the bottom of a pond is a thing in the world.
			_sunk += SINK_SPEED * delta
			_wobble += delta * 2.4
			# sinking is not falling: it drifts, it turns, it takes its time
			global_position.y += SINK_SPEED * delta
			global_position.x += sin(_wobble) * SINK_DRAG * delta
			rotation += delta * 0.8
			modulate.a = 0.82                       # dimmed by the water, not fading
			if randf() < delta * 6.0:
				_bubble()
			if is_nan(_water_surface()):
				_claim_from_the_deep()              # drifted out of the pool
				return
			var bed := _ground_below()
			if not is_nan(bed) and global_position.y >= bed:
				global_position.y = bed
				_state = SUNK
				rotation = randf_range(-0.5, 0.5)   # it settles however it lands
				_puff_silt()
			elif _sunk > BOTTOMLESS:
				_claim_from_the_deep()              # no floor at all: it is gone
		SUNK:
			# resting on the bed. It still sways with the water, and it is still
			# yours to collect -- the pickup area never stopped working.
			_wobble += delta * 1.1
			position.x += sin(_wobble) * 3.0 * delta
			if randf() < delta * 0.7:
				_bubble()
			if is_nan(_water_surface()):
				_claim_from_the_deep()              # the pool drained or moved

# the surface of any fish_water this coin is currently over, or NAN
func _water_surface() -> float:
	for w in get_tree().get_nodes_in_group("fish_water"):
		if not is_instance_valid(w) or not (w is Node2D):
			continue
		if not w.has_method("fish_surface_y") or not w.has_method("fish_half_width"):
			continue
		var half: float = float(w.fish_half_width())
		if absf(global_position.x - (w as Node2D).global_position.x) > half:
			continue
		return float(w.fish_surface_y())
	return NAN

func _enter_water_if_wet() -> bool:
	var surf := _water_surface()
	if is_nan(surf) or global_position.y < surf:
		return false
	_state = DROWN
	_sunk = 0.0
	_vel = Vector2.ZERO
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	global_position.y = surf                 # break the surface, don't skip it
	_splash()
	return true

func _ground_below() -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 40.0))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return NAN if hit.is_empty() else float(hit.position.y)

# OUT OF THE POOL, AND YOURS. The coin is gone; the gold is not.
func _claim_from_the_deep() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return                                # no one to pay: keep waiting
	# the same courtesy the land spills get -- a full bag does not destroy gold,
	# it just means the coin rests on the bottom until there is room for it
	if "inventory" in p and p.inventory != null \
			and not p.inventory.can_accept("coin_gold"):
		return                                # no room: wait, and try again
	if p.has_method("add_currency"):
		p.add_currency(amount)
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("The water gives up %d currency" % amount)
	queue_free()

# it lands on the bed and lifts a little cloud of silt. Small thing; it is the
# difference between arriving and simply stopping.
func _puff_silt() -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	for i in range(5):
		var s := Polygon2D.new()
		var r: float = randf_range(2.5, 5.5)
		var pts := PackedVector2Array()
		for k in range(7):
			var a: float = TAU * float(k) / 7.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		s.polygon = pts
		s.color = Color(0.52, 0.48, 0.40, 0.45)
		s.z_index = 11
		host.add_child(s)
		s.global_position = global_position + Vector2(randf_range(-8, 8), 4)
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position
			+ Vector2(randf_range(-14, 14), randf_range(-10, -3)), 0.8)
		tw.tween_property(s, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(s.queue_free)

func _splash() -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	for i in range(7):
		var d := Polygon2D.new()
		var r: float = randf_range(1.6, 3.4)
		var pts := PackedVector2Array()
		for k in range(6):
			var a: float = TAU * float(k) / 6.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		d.polygon = pts
		d.color = Color(0.72, 0.90, 1.0, 0.85)
		d.z_index = 12
		host.add_child(d)
		d.global_position = global_position
		var tw := d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "global_position", global_position
			+ Vector2(randf_range(-26, 26), randf_range(-30, -12)), 0.4)
		tw.tween_property(d, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(d.queue_free)

func _bubble() -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	var b := Polygon2D.new()
	var r: float = randf_range(1.2, 2.6)
	var pts := PackedVector2Array()
	for k in range(7):
		var a: float = TAU * float(k) / 7.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	b.polygon = pts
	b.color = Color(0.85, 0.95, 1.0, 0.6)
	b.z_index = 12
	host.add_child(b)
	b.global_position = global_position + Vector2(randf_range(-5, 5), 0)
	var tw := b.create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "global_position", b.global_position + Vector2(
		randf_range(-6, 6), -randf_range(26.0, 48.0)), 0.9)
	tw.tween_property(b, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(b.queue_free)

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

	_label = Label.new()
	_label.text = str(amount)
	_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.02, 1))
	_label.add_theme_font_size_override("font_size", 12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(-PICKUP_RADIUS, -PICKUP_RADIUS * 0.6)
	_label.size = Vector2(PICKUP_RADIUS * 2, PICKUP_RADIUS * 1.2)
	add_child(_label)

func refresh_label() -> void:
	if _label != null:
		_label.text = str(amount)

func start_bob() -> void:
	# only once it has LANDED. Bobbing from the instant of spawn is what made a
	# coin read as a UI element that happened to be in the world.
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "position:y", -6.0, 0.7).as_relative()
	_bob_tween.tween_property(self, "position:y", 6.0, 0.7).as_relative()

func _on_body_entered(body: Node) -> void:
	if not can_collect:
		return
	if not body.is_in_group("player"):
		return
	# a bag with no room for coin must NOT collect: add_currency would just
	# spill the same gold straight back out (collect -> spill -> collect,
	# forever). The pile simply waits until a slot frees.
	if "inventory" in body and body.inventory != null \
			and not body.inventory.can_accept("coin_gold"):
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
