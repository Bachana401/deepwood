extends Node2D

# A shade -- a soldier of living shadow in the Shadow Monarch's service
# (Rise, Shade: 5/7+, see player.gd raise_shade). When a foe falls, its shadow
# tears free of the ground, takes the Monarch's colours and hunts beside him:
# it drifts to the nearest living enemy and cuts it down with claws of dark,
# then gutters out when its borrowed time is spent. At 7/7 (true form) shades
# never expire -- a standing army of the dark. Drawn procedurally (a hooded
# wraith with burning violet eyes and a ragged hem) so it reads as PURE SHADOW
# next to any painted enemy skin.

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]
const FLY_SPEED := 250.0
const ATTACK_RANGE := 40.0
const ATTACK_COOLDOWN := 0.85
const SEEK_RANGE := 760.0
const HOME_RANGE := 46.0      # hover ring around the Monarch when idle

var damage := 10
var expires_at := 0.0         # ticks-seconds; 0 = permanent (true form)
var owner_player: Node2D = null

var _attack_ready_at := 0.0
var _bob := randf() * TAU
var _home_side := 1.0 if randf() < 0.5 else -1.0
var _dying := false
var _spawned := false

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	z_index = 6
	_build_visual()
	# rise out of the ground: unfold upward from a flat puddle of shadow
	scale = Vector2(1.3, 0.1)
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.22)
	t.tween_callback(func(): _spawned = true)

func _build_visual() -> void:
	# soft violet halo behind the body
	var glow = Polygon2D.new()
	glow.polygon = _blob(16.0, 10)
	glow.color = Color(0.45, 0.15, 0.85, 0.20)
	var add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add_mat
	glow.position = Vector2(0, -14)
	add_child(glow)
	# hooded wraith silhouette: cowled head, cloaked torso, ragged trailing hem
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(7, -26), Vector2(9, -18),
		Vector2(11, -6), Vector2(9, 2), Vector2(12, 8),
		Vector2(6, 4), Vector2(3, 10), Vector2(0, 5),
		Vector2(-3, 11), Vector2(-6, 4), Vector2(-12, 9),
		Vector2(-9, 1), Vector2(-11, -6), Vector2(-9, -18), Vector2(-7, -26),
	])
	body.color = Color(0.10, 0.04, 0.20, 0.92)
	add_child(body)
	# burning eyes in the cowl's dark
	for side in [-1.0, 1.0]:
		var eye = ColorRect.new()
		eye.size = Vector2(3, 2)
		eye.position = Vector2(side * 3.5 - 1.5, -24)
		eye.color = Color(0.85, 0.5, 1.0, 0.95)
		eye.material = add_mat
		add_child(eye)

func _blob(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a = TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r * randf_range(0.85, 1.15))
	return pts

func _process(delta: float) -> void:
	if _dying:
		return
	if expires_at > 0.0 and _now() > expires_at:
		dissolve()
		return
	if not is_instance_valid(owner_player) or ("is_dead" in owner_player and owner_player.is_dead):
		dissolve()   # the Monarch has fallen -- his shadows go with him
		return
	_bob += delta * 3.0
	var target = _nearest_enemy()
	var dest: Vector2
	if target != null:
		dest = target.global_position + Vector2(0, -12)
	else:
		dest = owner_player.global_position + Vector2(_home_side * HOME_RANGE, -30)
	var to = dest - global_position
	if to.length() > 6.0:
		global_position += to.normalized() * minf(FLY_SPEED * delta, to.length())
	if _spawned and absf(to.x) > 2.0:
		scale.x = absf(scale.x) * (1.0 if to.x >= 0.0 else -1.0)
	position.y += sin(_bob) * 6.0 * delta
	# claws of dark
	if target != null and _now() >= _attack_ready_at \
			and global_position.distance_to(target.global_position) <= ATTACK_RANGE:
		_attack_ready_at = _now() + ATTACK_COOLDOWN
		_slash(target)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := SEEK_RANGE
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _slash(target: Node2D) -> void:
	target.take_damage(damage)
	# a dark arc flashes across the victim
	var arc = Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(0.62, 0.28, 1.0, 0.9)
	for i in range(7):
		var a = lerpf(-1.1, 1.1, i / 6.0)
		arc.add_point(Vector2(sin(a) * 16.0, -10.0 - cos(a) * 10.0))
	arc.z_index = 40
	get_parent().add_child(arc)
	arc.global_position = target.global_position
	var t = arc.create_tween()
	t.tween_property(arc, "modulate:a", 0.0, 0.2)
	t.tween_callback(arc.queue_free)

func dissolve() -> void:
	if _dying:
		return
	_dying = true
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(self, "scale", Vector2(1.2, 0.05), 0.3)
	t.tween_callback(queue_free)
