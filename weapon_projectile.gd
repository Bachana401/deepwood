extends Area2D

# One configurable projectile powering the special-attack weapons (see
# player.gd launch_projectile + the "special" dicts in inventory.gd). Kinds:
#   slash       -- a flying wind-crescent that pierces everyone in its path
#   javelin     -- a hurled spectral spear, also piercing
#   fireball    -- explodes in an AoE on the first hit (or at max range)
#   frost_shard -- fast piercing ice sliver
#   hook        -- drags the first enemy struck back to the player's feet
#   boomerang   -- flies out, turns, and comes back: hits on BOTH passes
#
# Area2D (not a body) so it sails over terrain; enemies are found the same
# way the player's arrows find them (collision_mask 4 + take_damage check).
# All visuals are procedural polygons, self-cleaning on despawn.

var kind := "slash"
var girth := 1.0            # scales the visual AND the hitbox together
var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10
var max_distance := 450.0
var pierce := false
var aoe_radius := 0.0
var knockback := 40.0
var is_crit := false        # set by the player when it rolls a crit
var on_hit_status := {}     # {"kind","dur","mag"} applied to enemies on hit
var source: Node2D = null   # the player (hook pull target / boomerang home)

func _apply_status_to(node) -> void:
	if not on_hit_status.is_empty() and node.has_method("apply_status"):
		node.apply_status(str(on_hit_status.get("kind","burn")), float(on_hit_status.get("dur",3.0)), float(on_hit_status.get("mag",0.0)))
	# Elementalist Wildfire / Cataclysm: the burn you just applied leaps to any
	# foes crowded around the one you struck.
	if GameState.get_bonus_total("combustion") > 0.0 and is_instance_valid(node):
		var mag = GameState.get_bonus_total("on_hit_burn")
		if mag <= 0.0:
			mag = 6.0
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if e == node or not is_instance_valid(e) or not e.has_method("apply_status"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if node.global_position.distance_to(e.global_position) <= 110.0:
					e.apply_status("burn", 3.0, mag)

var traveled := 0.0
var returning := false      # boomerang: on the way back
var done := false
var hit_bodies: Array = []
var visual: Node2D = null
var spin_speed := 0.0
var rope: Line2D = null     # hook: drawn back to the thrower

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	# findable in flight, so a mirror boss has something to reflect (boss.gd
	# tick_mirror). Without this the mechanic is a silent no-op.
	add_to_group("player_projectile")
	collision_layer = 0
	collision_mask = 4   # enemy layer, same as the player's arrows target
	monitoring = true
	z_index = 40
	var cs = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	# girth scales the projectile as a whole -- the drawn shape AND what it can
	# hit -- so a mythic crescent is genuinely a wall of force sweeping the room
	# rather than a small sprite that merely looks impressive.
	shape.size = Vector2(36, 20) * girth
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	visual = Node2D.new()
	visual.scale = Vector2.ONE * girth
	add_child(visual)
	match kind:
		"slash": _build_slash()
		"javelin": _build_javelin()
		"fireball": _build_fireball()
		"frost_shard": _build_frost()
		"hook": _build_hook()
		"boomerang":
			_build_boomerang()
			spin_speed = 16.0
	if spin_speed == 0.0:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if done:
		return
	if kind == "boomerang" and returning:
		if not is_instance_valid(source):
			queue_free()
			return
		var to_src = source.global_position - global_position
		if to_src.length() < 26.0:
			queue_free()
			return
		direction = to_src.normalized()
	var step = speed * delta
	global_position += direction * step
	traveled += step
	if spin_speed != 0.0 and visual:
		visual.rotation += spin_speed * delta
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	if not returning and traveled >= max_distance:
		if kind == "boomerang":
			returning = true
			hit_bodies.clear()   # the return pass hits everyone again
		elif kind == "fireball":
			explode()
		else:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if done or body in hit_bodies:
		return
	if not body.has_method("take_damage"):
		return
	if "is_dead" in body and body.is_dead:
		return
	hit_bodies.append(body)
	# A weapon's thrown crescent carries its owner's signature: landing one is a
	# hit like any other, so lifesteal, gold-touch, execute and the rest all fire.
	# Without this a weapon built to reach was strictly worse at its own range.
	# (The player guards against a unique that throws another projectile.)
	if is_instance_valid(source) and source.has_method("on_projectile_hit"):
		source.on_projectile_hit(body, damage)
	match kind:
		"fireball":
			explode()
		"hook":
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_pull_to_source(body)
			queue_free()
		_:
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			if body.has_method("apply_knockback"):
				body.apply_knockback(1 if direction.x >= 0.0 else -1, knockback)
			if not pierce and kind != "boomerang":
				queue_free()

# Hook: reel the victim in using its own knockback system (negative direction
# = toward the player), so it respects the enemy's is_dead/knockback rules.
func _pull_to_source(body: Node2D) -> void:
	if not is_instance_valid(source) or not body.has_method("apply_knockback"):
		return
	var dx = source.global_position.x - body.global_position.x
	var pull_sign = 1 if dx >= 0.0 else -1
	body.apply_knockback(pull_sign, max(absf(dx) - 42.0, 0.0))

# Fireball: blast everyone standing near the detonation point.
func explode() -> void:
	if done:
		return
	done = true
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= aoe_radius:
				e.take_damage(damage)
				FloatingText.spawn(get_parent(), e.global_position, damage, is_crit)
				_apply_status_to(e)
				if e.has_method("apply_knockback"):
					e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback)
	# blast flash: expanding fading disc + ring, left behind as we free
	var blast = Polygon2D.new()
	blast.polygon = _circle(aoe_radius * 0.4, 20)
	blast.color = Color(1.0, 0.6, 0.2, 0.7)
	blast.z_index = 45
	get_parent().add_child(blast)
	blast.global_position = global_position
	var t = blast.create_tween()
	t.tween_property(blast, "scale", Vector2(2.6, 2.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(blast, "modulate:a", 0.0, 0.25)
	t.tween_callback(blast.queue_free)
	queue_free()

# --- procedural looks ---

func _build_slash() -> void:
	var arc = Polygon2D.new()   # a thin crescent, like a slice of wind
	var pts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.9, 0.9, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	for i in range(9):
		var a = lerp(0.9, -0.9, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	arc.polygon = pts
	arc.color = Color(0.75, 0.95, 1.0, 0.85)
	visual.add_child(arc)

func _build_javelin() -> void:
	var shaft = Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-24, -2), Vector2(16, -2), Vector2(16, 2), Vector2(-24, 2)])
	shaft.color = Color(0.85, 0.8, 0.55, 0.9)
	visual.add_child(shaft)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(16, -5), Vector2(28, 0), Vector2(16, 5)])
	tip.color = Color(0.95, 0.92, 0.75, 0.95)
	visual.add_child(tip)

func _build_fireball() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(14.0, 14)
	glow.color = Color(1.0, 0.5, 0.1, 0.4)
	visual.add_child(glow)
	var core = Polygon2D.new()
	core.polygon = _circle(8.0, 12)
	core.color = Color(1.0, 0.75, 0.3, 0.95)
	visual.add_child(core)
	var trail = CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.35
	trail.direction = Vector2(-1, 0)
	trail.spread = 24.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 90.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.4
	trail.color = Color(1.0, 0.55, 0.15, 0.8)
	visual.add_child(trail)

func _build_frost() -> void:
	var shard = Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(-4, -6), Vector2(18, 0), Vector2(-4, 6)])
	shard.color = Color(0.7, 0.9, 1.0, 0.9)
	visual.add_child(shard)
	var gleam = Polygon2D.new()
	gleam.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(0, -2), Vector2(10, 0), Vector2(0, 2)])
	gleam.color = Color(0.95, 1.0, 1.0, 0.9)
	visual.add_child(gleam)

func _build_hook() -> void:
	var curve = Line2D.new()   # the hook itself: a J-curve
	curve.width = 4.0
	curve.default_color = Color(0.75, 0.78, 0.85, 1.0)
	var pts = PackedVector2Array()
	for i in range(8):
		var a = lerp(-PI * 0.15, PI, i / 7.0)
		pts.append(Vector2(10, 0) + Vector2(cos(a), sin(a)) * 9.0)
	curve.points = pts
	visual.add_child(curve)
	rope = Line2D.new()
	rope.width = 2.0
	rope.default_color = Color(0.5, 0.42, 0.3, 0.9)
	rope.z_index = -1
	add_child(rope)

func _build_boomerang() -> void:
	for ang in [0.0, PI * 0.5]:   # two blades in a V
		var blade = Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(22, -4), Vector2(24, 0), Vector2(22, 4)])
		blade.color = Color(0.35, 0.8, 0.75, 0.95)
		blade.rotation = ang
		visual.add_child(blade)

func _circle(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts
