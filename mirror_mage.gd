extends Node2D
# THE PLUCKED HAIR (Wukong roads, 2026-07-28): when enemies press the Sage,
# a hair plucks itself free and stands as a MIRROR-MAGE -- a hovering robed
# echo of the caster that bolts whatever threatens them, then scatters into
# strands. Spawned automatically by player.gd's hair-clone tick; one at a
# time, on a 20s cooldown, alive for 8s. Deliberately weaker than the true
# mage: it is a distraction that shoots, not a second player.

const WP = preload("res://weapon_projectile.gd")

var damage := 8
var lifetime := 8.0
var fire_gap := 0.9
var seek_range := 480.0
var source: Node2D = null

var _t := 0.0
var _next := 0.5
var _body: Node2D = null

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	z_index = 5
	add_to_group("player_mirror")
	_body = Node2D.new()
	add_child(_body)
	# the robe: a tapering hooded figure, glassy and half-there
	# brighter than the first cut (EYES 2026-07-28): a violet echo at 0.75
	# alpha melted into the night -- the hair must be SEEN standing guard
	var aura := Polygon2D.new()
	var apts := PackedVector2Array()
	for i in range(12):
		var aa := TAU * float(i) / 12.0
		apts.append(Vector2(cos(aa) * 16.0, -24.0 + sin(aa) * 26.0))
	aura.polygon = apts
	aura.color = Color(0.7, 0.55, 1.0, 0.16)
	_body.add_child(aura)
	var robe := Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(-11, -26), Vector2(-6, -40), Vector2(0, -44),
		Vector2(6, -40), Vector2(11, -26), Vector2(9, 0), Vector2(0, -6)])
	robe.color = Color(0.66, 0.52, 1.0, 0.95)
	_body.add_child(robe)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(-6, -38), Vector2(0, -50), Vector2(6, -38), Vector2(0, -34)])
	hood.color = Color(0.52, 0.4, 0.9, 1.0)
	_body.add_child(hood)
	# the face is a single mote of light under the hood
	var mote := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a) * 2.5, -40.0 + sin(a) * 2.5))
	mote.polygon = pts
	mote.color = Color(0.95, 0.9, 1.0, 0.95)
	_body.add_child(mote)
	# arrival: condense from nothing
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)

func _physics_process(delta: float) -> void:
	_t += delta
	if _body != null:
		_body.position.y = sin(_t * 3.0) * 4.0 - 2.0   # it hovers; it never stood
	if _t >= lifetime:
		# scatter back into strands
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		fade.parallel().tween_property(self, "scale", Vector2(0.4, 1.4), 0.4)
		fade.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _t < _next:
		return
	var prey := _nearest()
	if prey == null:
		_next = _t + 0.3
		return
	_next = _t + fire_gap
	var origin := global_position + Vector2(0, -40)
	var p = WP.new()
	p.kind = "frost_shard"
	p.direction = (prey.global_position - origin).normalized()
	p.speed = 560.0
	p.damage = damage
	p.max_distance = seek_range + 60.0
	p.girth = 0.85
	p.source = source
	get_parent().add_child(p)
	p.global_position = origin
	SfxSynth.play_at(self, origin, "pop", -16.0, 1.3)   # a hair's whisper of a cast
	if _body != null:
		_body.scale = Vector2(1.12, 0.92)   # a little casting lurch
		var s := create_tween()
		s.tween_property(_body, "scale", Vector2.ONE, 0.18)

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
