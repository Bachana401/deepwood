extends Node2D
# THE PLANTED SENTRY (weapons overhaul 2026-07-28, Terraria-sentry-INSPIRED):
# a warding totem stood at the caster's feet that snipes the nearest foe on
# its own clock, then crumbles when its time is spent. Deliberately SCARCE --
# summoning armies is the Shadow Monarch's identity, so the mage only ever
# borrows a single watchful post. Spawned by player.plant_sentry.

const WP = preload("res://weapon_projectile.gd")

var damage := 7
var lifetime := 16.0
# 0.85 made the high lantern a 51 dps Ascended -- a sentry you plant and then
# out-damage yourself is not worth the cast. 0.62 is a working watchman.
var fire_gap := 0.62
var seek_range := 540.0
var tint := Color(0.55, 0.75, 1.0)
var source: Node2D = null

var _t := 0.0
var _next := 0.6      # a breath to plant before the first shot
var _eye: Polygon2D = null

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	z_index = 5
	# the post: a narrow carved pillar with a watching eye-stone
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-7, 0), Vector2(-5, -46), Vector2(5, -46), Vector2(7, 0)])
	post.color = Color(0.32, 0.27, 0.22, 1.0)
	add_child(post)
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-9, -46), Vector2(0, -58), Vector2(9, -46)])
	cap.color = Color(0.4, 0.34, 0.27, 1.0)
	add_child(cap)
	# the watching eye carries a glow -- a dark post with a 5px eye vanished
	# into the night (world-zoom readability pass, EYES 2026-07-28)
	var halo := Polygon2D.new()
	var hpts := PackedVector2Array()
	for i in range(12):
		var ha := TAU * float(i) / 12.0
		hpts.append(Vector2(cos(ha) * 12.0, -38.0 + sin(ha) * 12.0))
	halo.polygon = hpts
	halo.color = Color(tint.r, tint.g, tint.b, 0.22)
	add_child(halo)
	_eye = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a) * 7.0, -38.0 + sin(a) * 7.0))
	_eye.polygon = pts
	_eye.color = Color(minf(tint.r + 0.2, 1.0), minf(tint.g + 0.2, 1.0), minf(tint.b + 0.2, 1.0), 1.0)
	add_child(_eye)

func _physics_process(delta: float) -> void:
	_t += delta
	if _eye != null:
		_eye.modulate.a = 0.7 + sin(_t * 5.0) * 0.3
	if _t >= lifetime:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.35)
		fade.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _t < _next:
		return
	var prey := _nearest()
	if prey == null:
		_next = _t + 0.3    # nothing to watch: check again soon
		return
	_next = _t + fire_gap
	var origin := global_position + Vector2(0, -38)
	var p = WP.new()
	p.kind = "frost_shard"
	p.direction = (prey.global_position - origin).normalized()
	p.speed = 640.0
	p.damage = damage
	p.max_distance = seek_range + 80.0
	p.girth = 0.8
	p.source = source
	get_parent().add_child(p)
	p.global_position = origin
	SfxSynth.play_at(self, origin, "pop", -14.0, 0.9)   # the post clears its throat

func _nearest() -> Node2D:
	var best: Node2D = null
	var bd := seek_range
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
