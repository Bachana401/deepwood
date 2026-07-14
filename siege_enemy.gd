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

# Faction: "raider" (default) marches on the wall/village; "village" is a
# Barracks soldier that sallies out and fights the raiders instead. Set (with
# an optional sprite skin from art/enemies/) before add_child.
var faction := "raider"
var skin := ""
const MELEE_ENGAGE_RANGE := 66.0   # a raider fights an in-its-face soldier over the wall

var body: Node2D = null
var body_rect: ColorRect = null
var skin_sprite: AnimatedSprite2D = null
var skin_attack_timer := 0.0
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

# After breaching the wall, besiegers go for whatever's nearest: the wizard,
# villagers, the player, AND the buildings themselves (to raze the village).
const DEFENDER_GROUPS = ["village_defender", "npc", "player", "building"]

func _ready() -> void:
	if faction == "village":
		# a friendly Barracks soldier: raiders target it (village_defender), and
		# it is NOT in "siege_enemy" and NOT on the player-weapon layer.
		add_to_group("village_defender")
		collision_layer = 0
	else:
		add_to_group("siege_enemy")
		collision_layer = 4   # course-enemy layer -> the player's weapons hit it
	collision_mask = 1        # collide with ground only
	health = max_health

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(26.0, 40.0)
	shape.shape = rect
	shape.position = Vector2(0, -20.0)
	add_child(shape)

	if wall == null:
		wall = get_tree().get_first_node_in_group("village_wall")

	if skin != "":
		build_skin_visual()
	else:
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

	if skin_attack_timer > 0.0:
		skin_attack_timer -= delta

	var target = current_target()
	if target == null:
		# nothing to hit yet -> raiders push into the village (+x), soldiers march
		# out to meet them (-x)
		velocity.x = SPEED if faction == "raider" else -SPEED
	else:
		# approach the target from whichever side we're on, then attack
		var stop_x = target_stop_x(target)
		if absf(stop_x - global_position.x) > 2.0:
			velocity.x = signf(stop_x - global_position.x) * SPEED
		else:
			velocity.x = 0.0
			try_attack(target)

	if velocity.x > 0.1:
		facing = 1
	elif velocity.x < -0.1:
		facing = -1
	if body:
		body.scale.x = facing
	if skin_sprite:
		_update_skin_anim()
	move_and_slide()

# Raider: the wall while it stands, but retaliate against a soldier already in
# its face; then the nearest defender. Village soldier: the nearest raider.
func current_target() -> Node2D:
	if faction == "village":
		return nearest_raider()
	var d = nearest_defender()
	if d != null and global_position.distance_to(d.global_position) <= MELEE_ENGAGE_RANGE:
		return d
	if is_instance_valid(wall) and not wall.breached:
		return wall
	return d

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

# A soldier's target: the nearest living raider.
func nearest_raider() -> Node2D:
	var best: Node2D = null
	var best_d = DEFENDER_SEEK_RANGE
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		var dist = global_position.distance_to(r.global_position)
		if dist < best_d:
			best_d = dist
			best = r
	return best

func target_stop_x(target: Node2D) -> float:
	if target == wall and is_instance_valid(wall):
		return wall.west_face_x() - ATTACK_STOP_GAP
	# plant on whichever side we're approaching from
	if global_position.x <= target.global_position.x:
		return target.global_position.x - ATTACK_STOP_GAP
	return target.global_position.x + ATTACK_STOP_GAP

func try_attack(target: Node2D) -> void:
	if attack_cooldown_remaining > 0.0 or not is_instance_valid(target):
		return
	# only the wall is reached purely by x; a defender must be genuinely close
	if target != wall and global_position.distance_to(target.global_position) > ATTACK_RANGE + ATTACK_STOP_GAP:
		return
	attack_cooldown_remaining = ATTACK_COOLDOWN
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	skin_attack_timer = 0.4
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
	if skin_sprite != null:
		skin_sprite.modulate = Color(2.4, 2.4, 2.4)
		skin_sprite.create_tween().tween_property(skin_sprite, "modulate", Color(1, 1, 1), 0.15)
		return
	if not body_rect:
		return
	var base = body_rect.color
	body_rect.color = Color(1, 1, 1)
	var t = body_rect.create_tween()
	t.tween_property(body_rect, "color", base, 0.15)

func die() -> void:
	is_dead = true
	if faction == "village":
		# a fallen soldier is the town's loss, not a payout to the player
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("A village soldier has fallen defending the wall.")
		_finish_death()
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_currency"):
		player.add_currency(reward)
	var smat = GameState.roll_construction_drop(player)
	if smat != "":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Salvaged " + Inventory.get_display_name(smat) + " from the raider.")
	GameState.add_xp(6)
	_finish_death()

# Play the death animation (if skinned) then remove the unit.
func _finish_death() -> void:
	spawn_death_particles()
	died.emit()
	if skin_sprite != null:
		skin_sprite.play("death")
		var t = skin_sprite.create_tween()
		t.tween_property(skin_sprite, "modulate:a", 0.0, 0.45).set_delay(0.18)
		await t.finished
	queue_free()

# --- Sprite skin (shared with dungeon enemies via EnemySkins) ---
const SKIN_SCALE := 3.1    # x5 from the first pass (0.62) -- developer sizing call
# This body's ORIGIN IS AT THE FEET (collision spans -40..0), while the 100px
# frames are drawn centered -- so the character in the frame (feet ~25px below
# the frame centre) must be lifted by that much or it renders half-sunk. (This
# offset is in pre-scale frame pixels, so it holds at any SKIN_SCALE.)
const SKIN_Y_OFFSET := -25.0

func build_skin_visual() -> void:
	body = Node2D.new()
	add_child(body)
	skin_sprite = AnimatedSprite2D.new()
	skin_sprite.sprite_frames = EnemySkins.frames_for(skin)
	skin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skin_sprite.scale = Vector2(SKIN_SCALE, SKIN_SCALE)
	skin_sprite.offset = Vector2(0, SKIN_Y_OFFSET)
	skin_sprite.animation = "idle"
	skin_sprite.play("idle")
	body.add_child(skin_sprite)

func _update_skin_anim() -> void:
	if skin_sprite == null:
		return
	var want := "idle"
	if skin_attack_timer > 0.0:
		want = "attack"
	elif absf(velocity.x) > 5.0:
		want = "walk"
	if skin_sprite.animation != want:
		skin_sprite.play(want)

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
	# skinned units are much taller than the procedural body: put the bar above
	# the sprite's head instead of inside its chest
	var bar_y := -54.0
	if skin != "":
		bar_y = -(25.0 + 50.0 * 0.75) * SKIN_SCALE - 12.0
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(34, 5)
	health_bar_bg.position = Vector2(-17, bar_y)
	health_bar_bg.z_index = 20
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	# friendly units read green at a glance; hostiles red
	health_bar_fill.color = Color(0.25, 0.8, 0.3, 1.0) if faction == "village" else Color(0.85, 0.2, 0.2, 1.0)
	health_bar_fill.size = Vector2(34, 5)
	health_bar_fill.position = Vector2(-17, bar_y)
	health_bar_fill.z_index = 21
	add_child(health_bar_fill)

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = 34.0 * clamp(float(health) / max_health, 0.0, 1.0)
