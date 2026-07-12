extends CharacterBody2D

# A besieger: marches east out of the evil lands toward the village wall and
# hammers it. Once the wall is breached (or if there is no wall), it pushes on
# to the nearest defender -- Orin the wizard, a villager, or the player -- and
# attacks them instead. Killable by the player's weapons AND Orin's meteors
# (collision_layer 4 like course enemies + in the "siege_enemy" group).
#
# Spawned and scaled by siege_manager.gd; stats (max_health / attack_damage)
# are injected before it enters the tree.

signal died

const GRAVITY = 900.0
const SPEED = 66.0
const ATTACK_RANGE = 44.0
const ATTACK_STOP_GAP = 34.0     # how far from the target it plants to attack
const ATTACK_COOLDOWN = 1.2
const KNOCKBACK_DURATION = 0.12
const DEFENDER_SEEK_RANGE = 700.0

# Injected by the SiegeManager (defaults are a sane tier-1 statline).
var max_health = 55
var health = 55
var attack_damage = 11
var reward = 6

var is_dead = false
var is_knocked_back = false
var wall: Node2D = null
var attack_cooldown_remaining = 0.0
var facing = 1

var body: Node2D = null
var body_rect: ColorRect = null
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

# After breaching the wall, besiegers go for whatever's nearest: the wizard,
# villagers, the player, AND the buildings themselves (to raze the village).
const DEFENDER_GROUPS = ["village_defender", "npc", "player", "building"]

func _ready() -> void:
	add_to_group("siege_enemy")
	collision_layer = 4   # same as course enemies -> player weapons hit it
	collision_mask = 1    # collide with ground only
	health = max_health

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(26.0, 40.0)
	shape.shape = rect
	shape.position = Vector2(0, -20.0)
	add_child(shape)

	if wall == null:
		wall = get_tree().get_first_node_in_group("village_wall")

	build_visual()
	build_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining -= delta

	if is_knocked_back:
		move_and_slide()
		return

	var target = current_target()
	if target == null:
		velocity.x = SPEED   # nothing to hit yet -> keep marching into the village
	else:
		var stop_x = target_stop_x(target)
		if global_position.x < stop_x:
			velocity.x = SPEED
		else:
			velocity.x = 0.0
			try_attack(target)

	if velocity.x > 0.1:
		facing = 1
	elif velocity.x < -0.1:
		facing = -1
	if body:
		body.scale.x = facing
	move_and_slide()

# Wall first (while it stands); after a breach, the nearest reachable defender.
func current_target() -> Node2D:
	if is_instance_valid(wall) and not wall.breached:
		return wall
	return nearest_defender()

func nearest_defender() -> Node2D:
	var best: Node2D = null
	var best_d = DEFENDER_SEEK_RANGE
	for group_name in DEFENDER_GROUPS:
		for d in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(d) or not d.has_method("take_damage"):
				continue
			if "is_dead" in d and d.is_dead:
				continue
			var dist = global_position.distance_to(d.global_position)
			if dist < best_d:
				best_d = dist
				best = d
	return best

func target_stop_x(target: Node2D) -> float:
	if target == wall and is_instance_valid(wall):
		return wall.west_face_x() - ATTACK_STOP_GAP
	return target.global_position.x - ATTACK_STOP_GAP

func try_attack(target: Node2D) -> void:
	if attack_cooldown_remaining > 0.0 or not is_instance_valid(target):
		return
	# only the wall is reached purely by x; a defender must be genuinely close
	if target != wall and global_position.distance_to(target.global_position) > ATTACK_RANGE + ATTACK_STOP_GAP:
		return
	attack_cooldown_remaining = ATTACK_COOLDOWN
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	animate_attack()

func animate_attack() -> void:
	if not body:
		return
	var t = body.create_tween()
	t.tween_property(body, "position:x", 8.0 * facing, 0.1)
	t.tween_property(body, "position:x", 0.0, 0.18)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	update_health_bar_fill()
	if health <= 0:
		die()
	else:
		flash_hit()

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	is_knocked_back = false

func flash_hit() -> void:
	if not body_rect:
		return
	var base = body_rect.color
	body_rect.color = Color(1, 1, 1)
	var t = body_rect.create_tween()
	t.tween_property(body_rect, "color", base, 0.15)

func die() -> void:
	is_dead = true
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_currency"):
		player.add_currency(reward)
	var smat = GameState.roll_construction_drop(player)
	if smat != "":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Salvaged " + Inventory.get_display_name(smat) + " from the raider.")
	GameState.add_xp(6)
	spawn_death_particles()
	died.emit()
	queue_free()

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position + Vector2(0, -18)
	particles.z_index = 10
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 14
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = Color(0.6, 0.1, 0.15, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func build_visual() -> void:
	body = Node2D.new()
	add_child(body)
	# hooded dark figure
	body_rect = ColorRect.new()
	body_rect.size = Vector2(26, 38)
	body_rect.position = Vector2(-13, -38)
	body_rect.color = Color(0.32, 0.1, 0.14, 1.0)
	body.add_child(body_rect)
	# hood
	var hood = Polygon2D.new()
	hood.polygon = PackedVector2Array([Vector2(-13, -34), Vector2(13, -34), Vector2(9, -46), Vector2(-9, -46)])
	hood.color = Color(0.2, 0.06, 0.1, 1.0)
	body.add_child(hood)
	# two glowing eyes
	for sx in [-5, 5]:
		var eye = ColorRect.new()
		eye.size = Vector2(3, 3)
		eye.position = Vector2(sx - 1.5, -30)
		eye.color = Color(1.0, 0.75, 0.2, 1.0)
		body.add_child(eye)

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(34, 5)
	health_bar_bg.position = Vector2(-17, -54)
	health_bar_bg.z_index = 20
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.85, 0.2, 0.2, 1.0)
	health_bar_fill.size = Vector2(34, 5)
	health_bar_fill.position = Vector2(-17, -54)
	health_bar_fill.z_index = 21
	add_child(health_bar_fill)

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = 34.0 * clamp(float(health) / max_health, 0.0, 1.0)
