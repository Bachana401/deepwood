extends CharacterBody2D

# ---------------------------------------------------------------------------
# Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL
# (non-boss) levels alongside the six humanoid grunt archetypes in enemy.gd.
# One script, several "kinds", each with its own silhouette, movement, and
# attack pattern:
#
#   flyer   -- slow floating eye; drifts above the player, contact damage,
#              occasional lazy shot. Cannot touch the ground. Easy.
#   bomber  -- round kamikaze; sprints in and self-destructs in an AoE.
#   charger -- horned rammer; winds up then dashes across the floor.
#   spitter -- squat turret-toad; roots in place and fires 3-shot spreads.
#
# Built entirely in code (no .tscn) and self-registers as a dungeon_combatant
# so the player's weapons hit it and the level-clear counter tracks it. Stats
# are injected by dungeon_interior.gd before the node enters the tree.
# ---------------------------------------------------------------------------

signal died

const GRAVITY = 900.0
const KNOCKBACK_DURATION = 0.12
const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_HIT = preload("res://audio/hit.wav")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_EXPLOSION = preload("res://audio/explosion.wav")

# Base statline per kind (before level scaling multipliers).
# Undead/evil monsters. "main" = body, "accent" = glow (eyes/pustules/etc).
const KINDS = {
	# Gloomeye -- a floating skull-wisp shrouded in tattered darkness.
	"flyer": {
		"hp": 34, "dmg": 7, "speed": 66.0, "reward": 6, "xp": 6,
		"main": Color(0.24, 0.22, 0.3), "accent": Color(0.7, 0.25, 0.95),
	},
	# Festerling -- a bloated rotting corpse that ruptures on approach.
	"bomber": {
		"hp": 40, "dmg": 24, "speed": 132.0, "reward": 8, "xp": 8,
		"main": Color(0.26, 0.3, 0.2), "accent": Color(0.8, 1.0, 0.3),
	},
	# Gravehound -- a skeletal beast that charges the living.
	"charger": {
		"hp": 78, "dmg": 16, "speed": 78.0, "reward": 9, "xp": 10,
		"main": Color(0.4, 0.38, 0.34), "accent": Color(0.9, 0.85, 0.66),
	},
	# Bilespitter -- a diseased, fanged toad-corpse that vomits bile.
	"spitter": {
		"hp": 50, "dmg": 9, "speed": 34.0, "reward": 8, "xp": 8,
		"main": Color(0.26, 0.36, 0.18), "accent": Color(0.7, 1.0, 0.35),
	},
}

# injected before _ready
var kind := "flyer"
var wave_hp_multiplier := 1.0
var wave_damage_multiplier := 1.0
var wave_speed_multiplier := 1.0

var data: Dictionary = {}
var player: Node2D = null
var max_health := 34
var health := 34
var attack_damage := 7
var reward := 6
var xp_reward := 6
var move_speed := 66.0
var main_color: Color
var accent_color: Color

var is_dead := false
var is_knocked_back := false
var facing := 1
var attack_cooldown := 0.0

# flyer
var hover_offset := Vector2.ZERO
var bob_time := 0.0
# bomber
var is_priming := false
# charger
var charge_state := "seek"   # seek -> windup -> dash -> recover
var charge_timer := 0.0
var charge_dir := 1

var visual: Node2D = null
var visual_parts: Array = []   # [[node, base_color], ...] for hit-flash restore
var health_fill: ColorRect = null

const FLYER_CONTACT_RANGE = 42.0
const FLYER_SHOOT_RANGE = 380.0
const BOMBER_PRIME_RANGE = 70.0
const BOMBER_BLAST_RADIUS = 96.0
const BOMBER_PRIME_TIME = 0.55
const CHARGER_TRIGGER_RANGE = 320.0
const CHARGER_WINDUP = 0.5
const CHARGER_DASH_TIME = 0.55
const CHARGER_DASH_SPEED = 470.0
const CHARGER_RECOVER = 0.9
const CHARGER_HIT_RANGE = 46.0
const SPITTER_SHOOT_RANGE = 620.0
const SPITTER_COOLDOWN = 2.0
const SPITTER_SPREAD_DEG = 14.0

func _ready() -> void:
	add_to_group("dungeon_combatant")
	collision_layer = 4                      # player weapons hit layer 4
	collision_mask = 0 if kind == "flyer" else 1
	data = KINDS.get(kind, KINDS["flyer"])
	main_color = data["main"]
	accent_color = data["accent"]
	max_health = int(round(data["hp"] * wave_hp_multiplier))
	health = max_health
	attack_damage = int(round(data["dmg"] * wave_damage_multiplier))
	reward = data["reward"]
	xp_reward = data["xp"]
	move_speed = data["speed"] * wave_speed_multiplier
	hover_offset = Vector2(randf_range(-70.0, 70.0), -randf_range(150.0, 240.0))
	player = get_tree().get_first_node_in_group("player")
	build_collision()
	build_visual()
	build_health_bar()

func build_collision() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	match kind:
		"flyer": rect.size = Vector2(30, 30)
		"bomber": rect.size = Vector2(30, 28)
		"charger": rect.size = Vector2(46, 30)
		"spitter": rect.size = Vector2(40, 30)
		_: rect.size = Vector2(30, 30)
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if kind != "flyer" and not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if is_knocked_back:
		move_and_slide()
		return

	if player != null and is_instance_valid(player):
		match kind:
			"flyer": act_flyer(delta)
			"bomber": act_bomber(delta)
			"charger": act_charger(delta)
			"spitter": act_spitter(delta)

	if velocity.x > 1.0:
		facing = 1
	elif velocity.x < -1.0:
		facing = -1
	if visual:
		visual.scale.x = facing
	bob_time += delta
	move_and_slide()

# --- per-kind behaviour ---

func act_flyer(delta: float) -> void:
	var target = player.global_position + hover_offset
	var to_target = target - global_position
	if to_target.length() > 30.0:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	velocity.y += sin(bob_time * 2.5) * 22.0
	var dist = global_position.distance_to(player.global_position)
	if dist < FLYER_CONTACT_RANGE and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 1.0
	elif dist < FLYER_SHOOT_RANGE and attack_cooldown <= 0.0 and randf() < 0.4:
		var dir = (player.global_position - global_position).normalized()
		fire_projectile(dir, attack_damage)
		attack_cooldown = 2.2

func act_bomber(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	if not is_priming:
		velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
		if global_position.distance_to(player.global_position) < BOMBER_PRIME_RANGE:
			is_priming = true
			prime_and_explode()
	else:
		velocity.x = 0.0

func prime_and_explode() -> void:
	# quick flash telegraph, then detonate (killing self)
	var t = create_tween()
	t.set_loops(3)
	t.tween_callback(func(): set_flash(Color(1.0, 0.4, 0.1)))
	t.tween_interval(BOMBER_PRIME_TIME / 6.0)
	t.tween_callback(clear_flash)
	t.tween_interval(BOMBER_PRIME_TIME / 6.0)
	await get_tree().create_timer(BOMBER_PRIME_TIME).timeout
	if is_dead:
		return
	explode()

func explode() -> void:
	spawn_blast()
	play_sfx(SFX_EXPLOSION)
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < BOMBER_BLAST_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
		if player.has_method("apply_knockback"):
			var away = sign(player.global_position.x - global_position.x)
			player.apply_knockback(away if away != 0 else 1, 220.0)
		if player.has_node("Camera2D"):
			player.get_node("Camera2D").shake(7.0, 0.3)
	die()

func act_charger(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	match charge_state:
		"seek":
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			if absf(dx) < CHARGER_TRIGGER_RANGE and absf(player.global_position.y - global_position.y) < 90.0:
				charge_state = "windup"
				charge_timer = CHARGER_WINDUP
				charge_dir = sign(dx) if dx != 0 else facing
				velocity.x = 0.0
		"windup":
			velocity.x = 0.0
			set_flash(Color(1.0, 0.85, 0.4))
			charge_timer -= delta
			if charge_timer <= 0.0:
				clear_flash()
				charge_state = "dash"
				charge_timer = CHARGER_DASH_TIME
		"dash":
			velocity.x = charge_dir * CHARGER_DASH_SPEED
			charge_timer -= delta
			if global_position.distance_to(player.global_position) < CHARGER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				if player.has_method("apply_knockback"):
					player.apply_knockback(charge_dir, 200.0)
				attack_cooldown = 0.8
			var hit_wall = false
			for i in range(get_slide_collision_count()):
				if absf(get_slide_collision(i).get_normal().x) > 0.5:
					hit_wall = true
			if charge_timer <= 0.0 or hit_wall:
				charge_state = "recover"
				charge_timer = CHARGER_RECOVER
		"recover":
			velocity.x = 0.0
			charge_timer -= delta
			if charge_timer <= 0.0:
				charge_state = "seek"

func act_spitter(delta: float) -> void:
	# roots in place, slowly faces the player, fires 3-round spreads
	velocity.x = 0.0
	if global_position.distance_to(player.global_position) < SPITTER_SHOOT_RANGE and attack_cooldown <= 0.0:
		var base = (player.global_position - global_position).angle()
		for k in [-1, 0, 1]:
			var dir = Vector2.RIGHT.rotated(base + deg_to_rad(SPITTER_SPREAD_DEG) * k)
			fire_projectile(dir, attack_damage)
		attack_cooldown = SPITTER_COOLDOWN

# --- shared combat ---

func deal_contact_damage() -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func fire_projectile(dir: Vector2, dmg: int) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + Vector2(0, -16) + dir * 22.0
	arrow.setup(dir.normalized(), dmg, 10.0, 20.0, 2, true, 560.0)
	get_parent().add_child(arrow)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	update_health_bar()
	if health <= 0:
		die()
	else:
		set_flash(Color(1, 1, 1))
		get_tree().create_timer(0.12).timeout.connect(clear_flash)
		play_sfx(SFX_HIT)

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	is_knocked_back = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("add_currency"):
		p.add_currency(int(round(reward * (1.0 + GameState.get_bonus_total("gold_gain")))))
	GameState.add_xp(xp_reward)
	spawn_death_particles()
	died.emit()
	queue_free()

# --- visuals ---

func set_flash(c: Color) -> void:
	for entry in visual_parts:
		if is_instance_valid(entry[0]):
			entry[0].color = c

func clear_flash() -> void:
	for entry in visual_parts:
		if is_instance_valid(entry[0]):
			entry[0].color = entry[1]

func add_part(node: CanvasItem, color: Color) -> void:
	node.color = color
	visual.add_child(node)
	visual_parts.append([node, color])

func build_visual() -> void:
	visual = Node2D.new()
	add_child(visual)
	match kind:
		"flyer": build_flyer_visual()
		"bomber": build_bomber_visual()
		"charger": build_charger_visual()
		"spitter": build_spitter_visual()

func poly(points: PackedVector2Array) -> Polygon2D:
	var p = Polygon2D.new()
	p.polygon = points
	return p

func circle_points(r: float, segs: int = 16) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segs):
		pts.append(Vector2(cos(i * TAU / segs), sin(i * TAU / segs)) * r)
	return pts

const BONE := Color(0.8, 0.78, 0.7)

# Gloomeye -- a hovering skull shrouded in tattered darkness, one burning eye.
func build_flyer_visual() -> void:
	# ragged dark wings
	add_part(poly(PackedVector2Array([Vector2(-11, -20), Vector2(-33, -30), Vector2(-25, -16), Vector2(-35, -8), Vector2(-20, -11)])), main_color.darkened(0.3))
	add_part(poly(PackedVector2Array([Vector2(11, -20), Vector2(33, -30), Vector2(25, -16), Vector2(35, -8), Vector2(20, -11)])), main_color.darkened(0.3))
	# jagged shroud / skull body
	var body = poly(PackedVector2Array([Vector2(-13, -4), Vector2(-11, -23), Vector2(0, -31), Vector2(11, -23), Vector2(13, -4), Vector2(5, -9), Vector2(0, -1), Vector2(-5, -9)]))
	body.position = Vector2(0, 0)
	add_part(body, main_color)
	# hollow socket with a single glowing pupil
	var socket = poly(circle_points(6.0))
	socket.position = Vector2(0, -17)
	add_part(socket, Color(0.04, 0.03, 0.06))
	var pupil = poly(circle_points(3.0))
	pupil.position = Vector2(0, -17)
	add_part(pupil, accent_color)
	# bony brow ridge
	add_part(poly(PackedVector2Array([Vector2(-8, -23), Vector2(8, -23), Vector2(0, -19)])), BONE)

# Festerling -- a bloated rotting corpse studded with glowing pustules.
func build_bomber_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-16, 0), Vector2(-14, -20), Vector2(-3, -30), Vector2(11, -27), Vector2(16, -12), Vector2(11, 0)]))
	add_part(body, main_color)
	# glowing rupture-line down the middle (about to burst)
	add_part(poly(PackedVector2Array([Vector2(-2, -26), Vector2(2, -26), Vector2(1, -3), Vector2(-1, -3)])), accent_color.darkened(0.05))
	# pustules
	for p in [Vector2(-7, -16), Vector2(6, -9), Vector2(-2, -23), Vector2(9, -20)]:
		var b = poly(circle_points(3.0))
		b.position = p
		add_part(b, accent_color)
	# sunken dark eye sockets
	for sx in [-5, 6]:
		var s = poly(circle_points(2.4))
		s.position = Vector2(sx, -14)
		add_part(s, Color(0.04, 0.05, 0.03))

# Gravehound -- a low skeletal beast, horned, with bared ribs.
func build_charger_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-24, -6), Vector2(14, -8), Vector2(22, -21), Vector2(-14, -25), Vector2(-26, -16)]))
	add_part(body, main_color)
	# forward horn
	add_part(poly(PackedVector2Array([Vector2(20, -18), Vector2(42, -15), Vector2(20, -9)])), BONE)
	# bared ribs
	for rx in [-16, -9, -2]:
		var rib = Line2D.new()
		rib.points = PackedVector2Array([Vector2(rx, -7), Vector2(rx, -20)])
		rib.width = 1.5
		rib.default_color = BONE.darkened(0.15)
		visual.add_child(rib)
	# burning eye
	var eye = poly(circle_points(3.0))
	eye.position = Vector2(11, -20)
	add_part(eye, Color(1.0, 0.28, 0.15))

# Bilespitter -- a squat diseased corpse-toad with a fanged maw.
func build_spitter_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(16, -25), Vector2(-16, -25)]))
	add_part(body, main_color)
	# gaping dark maw
	add_part(poly(PackedVector2Array([Vector2(-13, -11), Vector2(13, -11), Vector2(10, -2), Vector2(-10, -2)])), Color(0.07, 0.11, 0.05))
	# fangs
	add_part(poly(PackedVector2Array([Vector2(-10, -11), Vector2(-7, -4), Vector2(-4, -11)])), BONE)
	add_part(poly(PackedVector2Array([Vector2(10, -11), Vector2(7, -4), Vector2(4, -11)])), BONE)
	# glowing eyes + boils
	for sx in [-8, 8]:
		var eye = poly(circle_points(3.2))
		eye.position = Vector2(sx, -19)
		add_part(eye, accent_color)
	for p in [Vector2(-14, -6), Vector2(14, -8)]:
		var boil = poly(circle_points(2.6))
		boil.position = p
		add_part(boil, accent_color.darkened(0.1))

func build_health_bar() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.05, 0.05, 0.9)
	bg.size = Vector2(34, 4)
	bg.position = Vector2(-17, -48)
	bg.z_index = 20
	add_child(bg)
	health_fill = ColorRect.new()
	health_fill.color = Color(0.85, 0.25, 0.25, 1.0)
	health_fill.size = Vector2(34, 4)
	health_fill.position = Vector2(-17, -48)
	health_fill.z_index = 21
	add_child(health_fill)

func update_health_bar() -> void:
	if health_fill:
		health_fill.size.x = 34.0 * clamp(float(health) / max_health, 0.0, 1.0)

func play_sfx(stream: AudioStream) -> void:
	var p = AudioStreamPlayer2D.new()
	p.stream = stream
	p.global_position = global_position
	get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func spawn_blast() -> void:
	var ring = poly(circle_points(BOMBER_BLAST_RADIUS, 24))
	ring.color = Color(1.0, 0.55, 0.15, 0.5)
	ring.global_position = global_position + Vector2(0, -16)
	ring.z_index = 8
	ring.scale = Vector2(0.2, 0.2)
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.28)
	t.tween_property(ring, "modulate:a", 0.0, 0.32)
	t.chain().tween_callback(ring.queue_free)

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position + Vector2(0, -16)
	particles.z_index = 10
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 95.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = accent_color
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)
