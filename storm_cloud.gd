extends Node2D
# TOME AREA DENIAL (weapons overhaul 2026-07-28, Terraria-spellbook-INSPIRED,
# not copied): a conjured stormlet hangs over the aimed ground and rains
# strikes inside its ring for a few seconds. The caster walks away; the storm
# keeps working the area. Spawned by player.cast_storm_tome.

var damage := 8
var radius := 130.0
var duration := 4.5
var strike_gap := 0.4        # seconds between bolts
var tint := Color(0.55, 0.75, 1.0)
var source: Node2D = null    # the caster (for on-kill credits later)
# flagship variants (2026-07-28):
var sun_mode := false        # A Small Personal Sun: a grounded sunlet, warm palette
var drift := false           # What the Sky Charges: the storm WALKS toward prey

var _t := 0.0
var _next := 0.0
var _cloud: Polygon2D = null

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	z_index = 42
	if sun_mode:
		tint = Color(1.0, 0.62, 0.2)
	# the cloud: three soft lobes hanging where the storm works
	_cloud = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var r := 34.0 + sin(a * 3.0) * 12.0
		pts.append(Vector2(cos(a) * r * 1.6, sin(a) * r * 0.55))
	_cloud.polygon = pts
	# brighter lobes (EYES 2026-07-28): 0.5x tint at 0.75 alpha vanished into
	# the night sky -- a storm the caster paid mana for must be SEEN working
	_cloud.color = Color(tint.r * 0.75, tint.g * 0.75, tint.b * 0.85, 0.9)
	_cloud.position = Vector2(0, -110)
	if sun_mode:
		# not a cloud at all: a small sun sitting low over the scorched spot
		_cloud.color = Color(1.0, 0.75, 0.3, 0.85)
		_cloud.position = Vector2(0, -46)
		_cloud.scale = Vector2(0.55, 0.9)
	add_child(_cloud)
	# the working ring on the ground, faint -- the promise of where it strikes
	var ring := Line2D.new()
	var rp := PackedVector2Array()
	for i in range(25):
		var a2 := TAU * float(i) / 24.0
		rp.append(Vector2(cos(a2), sin(a2) * 0.35) * radius)
	ring.points = rp
	ring.width = 3.0
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.55)
	add_child(ring)

func _physics_process(delta: float) -> void:
	_t += delta
	if _cloud != null and not sun_mode:
		_cloud.position.y = -110.0 + sin(_t * 2.2) * 5.0
	# What the Sky Charges: the storm walks its ring toward the nearest prey
	if drift:
		var prey := _nearest_hostile(700.0)
		if prey != null:
			var dx: float = prey.global_position.x - global_position.x
			if absf(dx) > 20.0:
				global_position.x += signf(dx) * minf(60.0 * delta, absf(dx))
	if _t >= duration:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _t < _next:
		return
	_next = _t + strike_gap
	var x := randf_range(-radius, radius)
	_strike(Vector2(x, 0))

func _strike(local: Vector2) -> void:
	# the bolt: a jagged streak from the cloud down to the strike point
	var bolt := Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(minf(tint.r + 0.25, 1.0), minf(tint.g + 0.25, 1.0), minf(tint.b + 0.25, 1.0), 1.0)
	var top: Vector2 = Vector2(local.x * 0.3, -104)
	var pts := PackedVector2Array([top])
	for i in range(1, 4):
		var f := float(i) / 4.0
		pts.append(top.lerp(local, f) + Vector2(randf_range(-9, 9), 0))
	pts.append(local)
	bolt.points = pts
	add_child(bolt)
	var t := bolt.create_tween()
	t.tween_property(bolt, "modulate:a", 0.0, 0.22)
	t.tween_callback(bolt.queue_free)
	# the strike lands on anything close to the point
	var world := to_global(local)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if world.distance_to(e.global_position) <= 52.0:
				e.take_damage(damage)
				FloatingText.spawn(get_parent(), e.global_position, damage, false)
				if sun_mode and e.has_method("apply_status"):
					e.apply_status("burn", 2.0, 4.0)   # the sunlet clings

func _nearest_hostile(within: float) -> Node2D:
	var best: Node2D = null
	var bd := within
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best
