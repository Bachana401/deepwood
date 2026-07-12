extends CharacterBody2D

const GRAVITY = 900.0
const SPEED = 70.0
const MAX_HEALTH = 600
const ENRAGE_THRESHOLD = 0.5
const BUMP_THRESHOLD = 110.0
const WALL_TURN_DURATION = 0.8

const SLAM_RADIUS = 170.0
const SLAM_DAMAGE = 28
const SLAM_KNOCKBACK = 220.0
const SLAM_TELEGRAPH = 0.55
const SLAM_COOLDOWN = 3.5

const CHARGE_SPEED = 520.0
const CHARGE_DURATION = 0.5
const CHARGE_DAMAGE = 24
const CHARGE_KNOCKBACK = 260.0
const CHARGE_TELEGRAPH = 0.45
const CHARGE_COOLDOWN = 4.5
const CHARGE_HIT_RADIUS = 110.0
const CHARGE_MIN_RANGE = 160.0

const BARRAGE_COUNT = 5
const BARRAGE_SPREAD_DEG = 16.0
const BARRAGE_DAMAGE = 10
const BARRAGE_TELEGRAPH = 0.35
const BARRAGE_COOLDOWN = 3.0
const BARRAGE_RANGE = 550.0

const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_HIT = preload("res://audio/hit.wav")

signal died

var player: Node2D = null
var max_health = MAX_HEALTH
var health = MAX_HEALTH
var damage_multiplier = 1.0
var speed_multiplier = 1.0
var is_dead = false
var is_enraged = false
var facing_direction = 1
var base_color: Color

var slam_cooldown_remaining = 0.0
var charge_cooldown_remaining = 0.0
var barrage_cooldown_remaining = 0.0

var is_busy = false
var is_charging = false
var charge_direction = 1
var charge_timer = 0.0
var charge_has_hit = false
var is_wall_blocked = false
var wall_turn_timer = 0.0

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	base_color = $ColorRect.color
	update_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if slam_cooldown_remaining > 0:
		slam_cooldown_remaining -= delta
	if charge_cooldown_remaining > 0:
		charge_cooldown_remaining -= delta
	if barrage_cooldown_remaining > 0:
		barrage_cooldown_remaining -= delta
	if wall_turn_timer > 0:
		wall_turn_timer -= delta
		if wall_turn_timer <= 0:
			is_wall_blocked = false

	if player != null:
		if is_charging:
			process_charge(delta)
		elif not is_busy:
			var dx = player.global_position.x - global_position.x
			if absf(dx) > 4.0:
				facing_direction = sign(dx)
			var dist = global_position.distance_to(player.global_position)
			var chosen = choose_attack(dist)
			if chosen != "":
				start_attack(chosen)
			elif wall_turn_timer > 0:
				velocity.x = -facing_direction * SPEED * speed_multiplier
			else:
				velocity.x = facing_direction * SPEED * speed_multiplier
		check_bump()

	move_and_slide()

	if not is_wall_blocked and not is_charging:
		for i in range(get_slide_collision_count()):
			if absf(get_slide_collision(i).get_normal().x) > 0.5:
				is_wall_blocked = true
				wall_turn_timer = WALL_TURN_DURATION
				break

func choose_attack(dist: float) -> String:
	var candidates: Array = []
	if slam_cooldown_remaining <= 0 and dist < SLAM_RADIUS * 1.1:
		candidates.append("slam")
	if charge_cooldown_remaining <= 0 and dist > CHARGE_MIN_RANGE:
		candidates.append("charge")
	if barrage_cooldown_remaining <= 0:
		candidates.append("barrage")
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]

func start_attack(attack_name: String) -> void:
	is_busy = true
	velocity.x = 0
	match attack_name:
		"slam":
			do_slam()
		"charge":
			do_charge()
		"barrage":
			do_barrage()

func cooldown_mult() -> float:
	return 0.6 if is_enraged else 1.0

func do_slam() -> void:
	flash_telegraph(Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(SLAM_TELEGRAPH).timeout
	if is_dead:
		return
	if player != null and global_position.distance_to(player.global_position) < SLAM_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(int(round(SLAM_DAMAGE * damage_multiplier)))
		if player.has_method("apply_knockback"):
			var away = sign(player.global_position.x - global_position.x)
			if away == 0:
				away = facing_direction
			player.apply_knockback(away, SLAM_KNOCKBACK)
		if player.has_node("Camera2D"):
			player.get_node("Camera2D").shake(10.0, 0.35)
	slam_cooldown_remaining = SLAM_COOLDOWN * cooldown_mult()
	is_busy = false

func do_charge() -> void:
	flash_telegraph(Color(1.0, 0.3, 0.2))
	await get_tree().create_timer(CHARGE_TELEGRAPH).timeout
	if is_dead:
		return
	charge_direction = facing_direction
	is_charging = true
	charge_timer = CHARGE_DURATION
	charge_has_hit = false

func process_charge(delta: float) -> void:
	velocity.x = charge_direction * CHARGE_SPEED * speed_multiplier
	charge_timer -= delta
	if not charge_has_hit and player != null and global_position.distance_to(player.global_position) < CHARGE_HIT_RADIUS:
		charge_has_hit = true
		if player.has_method("take_damage"):
			player.take_damage(int(round(CHARGE_DAMAGE * damage_multiplier)))
		if player.has_method("apply_knockback"):
			player.apply_knockback(charge_direction, CHARGE_KNOCKBACK)
		if player.has_node("Camera2D"):
			player.get_node("Camera2D").shake(9.0, 0.3)
	var hit_wall = false
	for i in range(get_slide_collision_count()):
		if absf(get_slide_collision(i).get_normal().x) > 0.5:
			hit_wall = true
			break
	if charge_timer <= 0 or hit_wall:
		is_charging = false
		velocity.x = 0
		charge_cooldown_remaining = CHARGE_COOLDOWN * cooldown_mult()
		is_busy = false

func do_barrage() -> void:
	flash_telegraph(Color(1.0, 0.6, 0.1))
	await get_tree().create_timer(BARRAGE_TELEGRAPH).timeout
	if is_dead:
		return
	fire_barrage()
	barrage_cooldown_remaining = BARRAGE_COOLDOWN * cooldown_mult()
	is_busy = false

func fire_barrage() -> void:
	if player == null:
		return
	var base_dir = (player.global_position - global_position).normalized()
	var base_angle = base_dir.angle()
	var half = BARRAGE_COUNT / 2
	for i in range(BARRAGE_COUNT):
		var offset_index = i - half
		var angle = base_angle + deg_to_rad(BARRAGE_SPREAD_DEG) * offset_index
		var dir = Vector2.RIGHT.rotated(angle)
		var arrow = ARROW_SCENE.instantiate()
		arrow.position = global_position + dir * 40.0
		arrow.setup(dir, int(round(BARRAGE_DAMAGE * damage_multiplier)), 20.0, 40.0, 2, true, BARRAGE_RANGE)
		get_parent().add_child(arrow)

func check_bump() -> void:
	if is_busy or is_charging or is_dead or player == null or player.is_knocked_back:
		return
	if global_position.distance_to(player.global_position) > BUMP_THRESHOLD:
		return
	var bump_distance = randf_range(30.0, 45.0)
	var away_from_boss = sign(player.global_position.x - global_position.x)
	if away_from_boss == 0:
		away_from_boss = 1
	if player.has_method("apply_knockback"):
		player.apply_knockback(away_from_boss, bump_distance)

func flash_telegraph(color: Color) -> void:
	var tween = create_tween()
	tween.tween_property($ColorRect, "color", color, 0.12)
	tween.tween_property($ColorRect, "color", base_color, 0.12)
	tween.set_loops(2)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	update_health_bar()
	if health <= 0:
		die()
	else:
		flash_hit()
		play_sfx(SFX_HIT)
		if not is_enraged and health <= max_health * ENRAGE_THRESHOLD:
			enrage()

func enrage() -> void:
	is_enraged = true
	base_color = base_color.lerp(Color(0.5, 0.0, 0.0), 0.4)
	$ColorRect.color = base_color

func apply_knockback(_direction_sign: int, _distance: float) -> void:
	pass

func flash_hit() -> void:
	$ColorRect.color = Color(1, 1, 1)
	var tween = create_tween()
	tween.tween_property($ColorRect, "color", base_color, 0.15)

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

func update_health_bar() -> void:
	var percent = clamp(float(health) / max_health, 0.0, 1.0)
	$HealthBarFill.size.x = 160 * percent

func die() -> void:
	GameState.add_xp(int(round(60 * damage_multiplier)))
	# bosses always hand over a bundle of construction materials
	var bplayer = get_tree().get_first_node_in_group("player")
	GameState.grant_construction_bundle(bplayer, 3, 2, 1)
	var bstack = get_tree().get_first_node_in_group("notification_stack")
	if bstack:
		bstack.show_notification("The boss dropped building materials! (3 Wood, 2 Stone, 1 Resin)")
	is_dead = true
	is_busy = true
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	died.emit()
	await play_death_animation()
	visible = false
	await get_tree().create_timer(0.2).timeout
	queue_free()

func play_death_animation() -> void:
	spawn_death_particles()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($ColorRect, "color", Color(1.0, 0.3, 0.05, 1), 0.25)
	tween.tween_property($ColorRect, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.tween_property($EyeLeft, "modulate:a", 0.0, 0.5)
	tween.tween_property($EyeRight, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 36
	particles.lifetime = 0.9
	particles.explosiveness = 0.85
	particles.direction = Vector2(0, -1)
	particles.spread = 65.0
	particles.gravity = Vector2(0, -60)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 130.0
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.4, 0.08, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
