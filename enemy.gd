extends CharacterBody2D

const SPEED = 100.0
const GRAVITY = 900.0
const DETECTION_RANGE = 225.0
const KNOCKBACK_DURATION = 0.12
const MAX_HEALTH = 60
const BUMP_THRESHOLD = 42.0
const RESPAWN_DELAY = 3.0
const GROWTH_PER_RESPAWN = 1.085
const BOW_RETREAT_RANGE = 90.0
const BOW_HOLD_RANGE = 180.0
const JUMP_VELOCITY = -380.0
const JUMP_COOLDOWN = 1.2
const CLIMB_JUMP_COOLDOWN = 0.45
const RANDOM_JUMP_CHANCE = 0.006
const JUMP_SEE_HEIGHT = 40.0
const HORIZONTAL_DEADZONE = 6.0
const ENEMY_ARROW_RANGE = 460.0
const WALL_TURN_DURATION = 0.8
const WALL_NOTICE_DURATION = 3.5
const WALL_DETECTION_BONUS = 120.0
const HESITATE_MIN_INTERVAL = 1.8
const HESITATE_MAX_INTERVAL = 4.5
const HESITATE_DURATION = 0.35
const JUMP_DESYNC_GROUP_SIZE = 3
const JUMP_DESYNC_RADIUS = 260.0
const JUMP_DESYNC_MIN_DELAY = 0.05
const JUMP_DESYNC_MAX_DELAY = 0.45

const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_HIT = preload("res://audio/hit.wav")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_SWORD = preload("res://audio/sword_swing.wav")
const SFX_SPEAR = preload("res://audio/spear_thrust.wav")
const SFX_BOW = preload("res://audio/bow_shot.wav")

const WEAPONS = {
	"sword": {"damage": 10, "cooldown": 1.3, "range": 45.0, "knockback_min": 15.0, "knockback_max": 25.0, "size": Vector2(8, 28), "color": Color(0.75, 0.75, 0.8), "offset": 14.0},
	"spear": {"damage": 16, "cooldown": 1.4, "range": 65.0, "knockback_min": 25.0, "knockback_max": 35.0, "size": Vector2(50, 5), "color": Color(0.55, 0.35, 0.15), "offset": 12.0},
	"bow": {"damage": 8, "cooldown": 1.6, "range": 440.0, "knockback_min": 10.0, "knockback_max": 20.0, "size": Vector2(10, 10), "color": Color(0.45, 0.28, 0.1), "offset": 12.0},
}

# Dungeon enemy "rosters": one themed archetype per block of 5 dungeon levels.
# dungeon_interior.gd calls apply_block_archetype(block) where block =
# (level-1)/5, so levels 1-5 share roster 0, 6-10 share roster 1, and so on;
# past the end of the list it simply cycles. Each entry re-skins the plain
# enemy body (color/size), picks its weapon mix, and nudges the base stats so
# the flavor is felt in combat, not just visually.
const ENEMY_ROSTERS = [
	# 0 -- Ghouls (levels 1-5): shambling rotten dead, balanced weapon mix.
	{"name": "Ghoul", "color": Color(0.33, 0.4, 0.29), "accent": Color(0.7, 1.0, 0.45), "scale": 1.0, "shape": "grunt", "weapons": ["sword", "spear", "bow"], "hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.0},
	# 1 -- Frost Wights (6-10): frozen undead skirmishers, spear & bow.
	{"name": "Frost Wight", "color": Color(0.4, 0.5, 0.6), "accent": Color(0.7, 0.92, 1.0), "scale": 0.92, "shape": "frost", "weapons": ["spear", "bow"], "hp_mult": 0.85, "dmg_mult": 1.0, "speed_mult": 1.22},
	# 2 -- Charred Revenants (11-15): burnt corpses, hit hard but slow.
	{"name": "Charred Revenant", "color": Color(0.2, 0.15, 0.15), "accent": Color(1.0, 0.5, 0.12), "scale": 1.12, "shape": "ember", "weapons": ["sword", "spear"], "hp_mult": 1.3, "dmg_mult": 1.18, "speed_mult": 0.88},
	# 3 -- Wraiths (16-20): spectral fast archers that swarm from range.
	{"name": "Wraith", "color": Color(0.32, 0.22, 0.42), "accent": Color(0.7, 0.4, 1.0), "scale": 0.9, "shape": "wraith", "weapons": ["bow", "bow", "sword"], "hp_mult": 0.78, "dmg_mult": 1.0, "speed_mult": 1.32},
	# 4 -- Bone Golems (21-25): huge tomb-bone tanks, slow, pure melee.
	{"name": "Bone Golem", "color": Color(0.52, 0.5, 0.44), "accent": Color(0.86, 0.84, 0.72), "scale": 1.28, "shape": "stone", "weapons": ["sword"], "hp_mult": 1.7, "dmg_mult": 1.22, "speed_mult": 0.78},
	# 5 -- Rotfiends (26-30): small, fast, diseased jabbers.
	{"name": "Rotfiend", "color": Color(0.28, 0.4, 0.2), "accent": Color(0.7, 1.0, 0.3), "scale": 0.84, "shape": "venom", "weapons": ["spear", "spear", "bow"], "hp_mult": 0.85, "dmg_mult": 1.12, "speed_mult": 1.26},
]

@export var weapon_type: String = "sword"
@export var base_color: Color = Color(0.6236201, 0.18110216, 0.10793113)
@export var respawns: bool = true
@export var instant_aggro: bool = false

signal died

var direction = 1
var start_x: float
var spawn_position: Vector2
var player: Node2D = null
var health = MAX_HEALTH
var max_health = MAX_HEALTH
var damage_multiplier = 1.0
var detection_range_current = DETECTION_RANGE
var generation = 0
var is_dead = false
var is_knocked_back = false
var facing_direction = 1
var attack_cooldown_remaining = 0.0
var is_attacking = false
var jump_cooldown_remaining = 0.0
var is_wall_blocked = false
var wall_turn_timer = 0.0
var wall_notice_timer = 0.0
var frozen_for_dungeon = false
var speed_variance = 1.0
var jump_chance_variance = 1.0
var was_player_above = false
var jump_react_timer = 0.0
var hesitate_timer = 0.0
var hesitate_remaining = 0.0
var wave_hp_multiplier = 1.0
var wave_damage_multiplier = 1.0
var wave_speed_multiplier = 1.0
var character_shape := "grunt"
var accent_color := Color(0.85, 0.42, 0.3)

func _ready() -> void:
	start_x = global_position.x
	spawn_position = global_position
	player = get_tree().get_first_node_in_group("player")
	speed_variance = randf_range(0.82, 1.22)
	jump_chance_variance = randf_range(0.5, 1.8)
	hesitate_timer = randf_range(HESITATE_MIN_INTERVAL, HESITATE_MAX_INTERVAL)
	if wave_hp_multiplier != 1.0:
		max_health = int(round(MAX_HEALTH * wave_hp_multiplier))
		health = max_health
	damage_multiplier *= wave_damage_multiplier
	setup_weapon_visual()
	update_body_color()
	build_character()

func update_body_color() -> void:
	$ColorRect.color = base_color.darkened(clamp(generation * 0.15, 0.0, 0.6))

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# Re-skins this enemy into the roster archetype for the given 5-level block.
# MUST be called before the node enters the tree (before _ready), because the
# wave multipliers it stacks onto are baked into max_health in _ready. It also
# chooses the weapon from the archetype's mix, so it overrides any weapon_type
# set beforehand.
func apply_block_archetype(block: int) -> void:
	if ENEMY_ROSTERS.is_empty():
		return
	var data: Dictionary = ENEMY_ROSTERS[block % ENEMY_ROSTERS.size()]
	base_color = data.get("color", base_color)
	var s := float(data.get("scale", 1.0))
	scale = Vector2(s, s)
	var weapons: Array = data.get("weapons", [weapon_type])
	if not weapons.is_empty():
		weapon_type = weapons[randi() % weapons.size()]
	character_shape = data.get("shape", "grunt")
	accent_color = data.get("accent", accent_color)
	wave_hp_multiplier *= float(data.get("hp_mult", 1.0))
	wave_damage_multiplier *= float(data.get("dmg_mult", 1.0))
	wave_speed_multiplier *= float(data.get("speed_mult", 1.0))

# Builds a distinct UNDEAD silhouette (skull/hood + bony features) on top of
# the torso ColorRect, so each roster archetype reads as its own monster. Parts
# live under a "Features" node; flash_hit/death brighten/fade it with the torso.
const BONE := Color(0.82, 0.8, 0.72)

func build_character() -> void:
	if has_node("Features"):
		$Features.queue_free()
	var f := Node2D.new()
	f.name = "Features"
	add_child(f)
	match character_shape:
		"frost":
			_add_skull(f, -27.0, 7.0, BONE.lerp(base_color, 0.35))
			for sx in [-8.0, 0.0, 8.0]:   # jagged frozen-bone crown
				_add_poly(f, PackedVector2Array([Vector2(sx - 3, -32), Vector2(sx + 3, -32), Vector2(sx, -48)]), BONE)
		"ember":
			_add_shoulders(f, base_color.darkened(0.12))
			_add_skull(f, -28.0, 8.0, Color(0.24, 0.19, 0.18))   # charred skull
			_add_poly(f, PackedVector2Array([Vector2(-9, -33), Vector2(-17, -49), Vector2(-4, -35)]), accent_color)   # horns
			_add_poly(f, PackedVector2Array([Vector2(9, -33), Vector2(17, -49), Vector2(4, -35)]), accent_color)
			_add_dot(f, Vector2(-6, -6), 2.5, accent_color)      # glowing ember cracks
			_add_dot(f, Vector2(5, 2), 2.0, accent_color)
		"wraith":
			# hollow hood, no face -- just two burning eyes in the dark
			_add_poly(f, PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(8, -42), Vector2(-8, -42)]), base_color.darkened(0.3))
			for sx in [-4.0, 4.0]:
				_add_dot(f, Vector2(sx, -29), 2.2, accent_color)
			# ragged spectral tatters trailing below
			_add_poly(f, PackedVector2Array([Vector2(-12, 16), Vector2(-6, 28), Vector2(0, 16), Vector2(6, 28), Vector2(12, 16)]), base_color.darkened(0.18))
		"stone":
			_add_shoulders(f, base_color.darkened(0.15))
			var head := ColorRect.new()   # heavy blocky bone skull
			head.size = Vector2(20, 18)
			head.position = Vector2(-10, -40)
			head.color = BONE.darkened(0.08)
			f.add_child(head)
			_add_socket(f, Vector2(-5, -32))
			_add_socket(f, Vector2(5, -32))
			_add_dot(f, Vector2(-5, -32), 1.4, accent_color)
			_add_dot(f, Vector2(5, -32), 1.4, accent_color)
			_add_poly(f, PackedVector2Array([Vector2(-2, -24), Vector2(2, -24), Vector2(0, -14)]), Color(0.1, 0.1, 0.1))   # crack
		"venom":
			_add_skull(f, -25.0, 6.5, BONE.lerp(base_color, 0.4))
			for p in [Vector2(-7, -2), Vector2(6, 4), Vector2(-2, 9)]:   # festering boils
				_add_dot(f, p, 2.5, accent_color)
		_:  # grunt / Ghoul
			_add_skull(f, -26.0, 7.0, BONE.lerp(base_color, 0.4))
			# hunched ragged shoulders
			_add_poly(f, PackedVector2Array([Vector2(-15, -20), Vector2(15, -20), Vector2(10, -11), Vector2(-10, -11)]), base_color.darkened(0.22))

# A skull: pale cranium, two dark sockets with glowing pupils, and jaw fangs.
func _add_skull(parent: Node2D, y: float, r: float, color: Color) -> void:
	_add_dot(parent, Vector2(0, y), r, color)
	_add_socket(parent, Vector2(-r * 0.45, y - 1.0))
	_add_socket(parent, Vector2(r * 0.45, y - 1.0))
	_add_dot(parent, Vector2(-r * 0.45, y - 1.0), 1.5, accent_color)
	_add_dot(parent, Vector2(r * 0.45, y - 1.0), 1.5, accent_color)
	_add_poly(parent, PackedVector2Array([Vector2(-r * 0.5, y + r * 0.6), Vector2(-r * 0.2, y + r * 1.3), Vector2(0, y + r * 0.6)]), color)
	_add_poly(parent, PackedVector2Array([Vector2(r * 0.5, y + r * 0.6), Vector2(r * 0.2, y + r * 1.3), Vector2(0, y + r * 0.6)]), color)

func _add_socket(parent: Node2D, pos: Vector2) -> void:
	_add_dot(parent, pos, 2.6, Color(0.05, 0.045, 0.06))

func _add_shoulders(parent: Node2D, color: Color) -> void:
	var s := ColorRect.new()
	s.size = Vector2(34, 10)
	s.position = Vector2(-17, -22)
	s.color = color
	parent.add_child(s)

func _add_poly(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	parent.add_child(p)

func _add_dot(parent: Node2D, pos: Vector2, r: float, color: Color) -> void:
	# squarish pixel-art style: dots are blocks
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	p.position = pos
	p.color = color
	parent.add_child(p)

func setup_weapon_visual() -> void:
	var stats = WEAPONS.get(weapon_type, WEAPONS["sword"])
	if weapon_type == "bow":
		$WeaponIcon.visible = false
		$BowVisual.visible = true
	else:
		$WeaponIcon.visible = true
		$BowVisual.visible = false
		$WeaponIcon.size = stats.size
		$WeaponIcon.color = stats.color
		$WeaponIcon.position.y = -stats.size.y / 2.0
		$WeaponIcon.pivot_offset = stats.size / 2.0
	update_weapon_icon_position()

func get_aim_direction() -> Vector2:
	if player != null:
		var to_player = player.global_position - global_position
		if to_player.length() > 1.0:
			return to_player.normalized()
	return Vector2(facing_direction, 0)

func update_weapon_icon_position() -> void:
	var stats = WEAPONS.get(weapon_type, WEAPONS["sword"])
	if weapon_type == "bow":
		var aim_dir = get_aim_direction()
		$BowVisual.position = aim_dir * stats.offset
		$BowVisual.rotation = aim_dir.angle()
		$BowVisual.scale = Vector2.ONE
	elif facing_direction > 0:
		$WeaponIcon.position.x = stats.offset
	else:
		$WeaponIcon.position.x = -stats.offset - stats.size.x

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= delta
	if jump_cooldown_remaining > 0:
		jump_cooldown_remaining -= delta
	if wall_turn_timer > 0:
		wall_turn_timer -= delta
		if wall_turn_timer <= 0:
			is_wall_blocked = false
	if wall_notice_timer > 0:
		wall_notice_timer -= delta

	if hesitate_remaining > 0:
		hesitate_remaining -= delta
	else:
		hesitate_timer -= delta
		if hesitate_timer <= 0:
			hesitate_remaining = HESITATE_DURATION
			hesitate_timer = randf_range(HESITATE_MIN_INTERVAL, HESITATE_MAX_INTERVAL)

	if jump_react_timer > 0:
		jump_react_timer -= delta

	if not is_knocked_back:
		var effective_detection_range = detection_range_current * 2.0 if weapon_type == "bow" else detection_range_current
		if wall_notice_timer > 0:
			effective_detection_range += WALL_DETECTION_BONUS
		if instant_aggro:
			effective_detection_range = INF
		if player != null and global_position.distance_to(player.global_position) < effective_detection_range:
			var dist_to_player = global_position.distance_to(player.global_position)
			var dx = player.global_position.x - global_position.x
			var player_above = player.global_position.y < global_position.y - JUMP_SEE_HEIGHT
			if player_above and not was_player_above and count_nearby_enemies() >= JUMP_DESYNC_GROUP_SIZE:
				jump_react_timer = randf_range(JUMP_DESYNC_MIN_DELAY, JUMP_DESYNC_MAX_DELAY)
			was_player_above = player_above
			var dir_to_player = facing_direction
			if absf(dx) > HORIZONTAL_DEADZONE:
				dir_to_player = sign(dx)
			if hesitate_remaining > 0:
				velocity.x = 0
			elif wall_turn_timer > 0:
				velocity.x = -dir_to_player * SPEED * speed_variance * wave_speed_multiplier
			elif weapon_type == "bow" and dist_to_player < BOW_RETREAT_RANGE and not player_above:
				velocity.x = -dir_to_player * SPEED * speed_variance * wave_speed_multiplier
			elif weapon_type == "bow" and dist_to_player < BOW_HOLD_RANGE and not player_above:
				velocity.x = 0
			elif absf(dx) <= HORIZONTAL_DEADZONE and not player_above:
				velocity.x = 0
			else:
				velocity.x = dir_to_player * SPEED * speed_variance * wave_speed_multiplier
			try_attack(dir_to_player)
			try_jump(player_above)
		else:
			velocity.x = direction * SPEED * speed_variance * wave_speed_multiplier
			if direction > 0 and global_position.x - start_x > 150:
				direction = -1
			elif direction < 0 and global_position.x - start_x < -150:
				direction = 1

	if velocity.x > 0:
		facing_direction = 1
	elif velocity.x < 0:
		facing_direction = -1
	if not is_attacking:
		update_weapon_icon_position()

	check_bump()

	move_and_slide()

	if not is_wall_blocked:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider != null and collider.is_in_group("player"):
				continue
			if absf(collision.get_normal().x) > 0.5:
				is_wall_blocked = true
				wall_turn_timer = WALL_TURN_DURATION
				wall_notice_timer = WALL_NOTICE_DURATION
				break

func try_jump(player_above: bool = false) -> void:
	if not is_on_floor() or jump_cooldown_remaining > 0:
		return
	var should_jump = false
	if player_above:
		should_jump = jump_react_timer <= 0.0
	elif randf() < RANDOM_JUMP_CHANCE * jump_chance_variance:
		should_jump = true
	if should_jump:
		velocity.y = JUMP_VELOCITY
		jump_cooldown_remaining = CLIMB_JUMP_COOLDOWN if player_above else JUMP_COOLDOWN

func count_nearby_enemies() -> int:
	var count = 1
	for group_name in ["course_enemy", "dungeon_combatant"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == self or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) < JUMP_DESYNC_RADIUS:
				count += 1
	return count

func check_bump() -> void:
	if is_knocked_back or is_attacking or player == null or player.is_knocked_back:
		return
	if global_position.distance_to(player.global_position) > BUMP_THRESHOLD:
		return
	var bump_distance = randf_range(20.0, 30.0)
	var away_from_player = sign(global_position.x - player.global_position.x)
	if away_from_player == 0:
		away_from_player = 1
	if player.has_method("apply_knockback"):
		player.apply_knockback(-away_from_player, bump_distance)
	apply_knockback(away_from_player, bump_distance * 0.6)

func try_attack(dir_to_player: int) -> void:
	if attack_cooldown_remaining > 0 or is_attacking:
		return
	var stats = WEAPONS[weapon_type]
	var dist = global_position.distance_to(player.global_position)
	if dist > stats.range:
		return
	attack_cooldown_remaining = stats.cooldown
	facing_direction = dir_to_player
	is_attacking = true
	match weapon_type:
		"sword":
			animate_sword_attack(stats)
		"spear":
			animate_spear_attack(stats)
		"bow":
			animate_bow_attack(stats)

func finish_attack() -> void:
	is_attacking = false
	update_weapon_icon_position()

func try_deal_melee_damage(stats: Dictionary) -> void:
	if player != null and global_position.distance_to(player.global_position) <= stats.range and player.has_method("take_damage"):
		player.take_damage(int(stats.damage * damage_multiplier))
		if player.has_method("apply_knockback"):
			var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
			var away_from_enemy = sign(player.global_position.x - global_position.x)
			if away_from_enemy == 0:
				away_from_enemy = facing_direction
			player.apply_knockback(away_from_enemy, knockback_distance)

func animate_sword_attack(stats: Dictionary) -> void:
	play_sfx(SFX_SWORD)
	var icon = $WeaponIcon
	update_weapon_icon_position()
	icon.rotation_degrees = -50 * facing_direction
	var tween = create_tween()
	tween.tween_property(icon, "rotation_degrees", 50 * facing_direction, 0.15)
	tween.tween_callback(try_deal_melee_damage.bind(stats))
	tween.tween_property(icon, "rotation_degrees", 0.0, 0.1)
	tween.tween_callback(finish_attack)

func animate_spear_attack(stats: Dictionary) -> void:
	play_sfx(SFX_SPEAR)
	var icon = $WeaponIcon
	update_weapon_icon_position()
	var base_x = icon.position.x
	var lunge_x = base_x + 20 * facing_direction
	var tween = create_tween()
	tween.tween_property(icon, "position:x", lunge_x, 0.12)
	tween.tween_callback(try_deal_melee_damage.bind(stats))
	tween.tween_property(icon, "position:x", base_x, 0.18)
	tween.tween_callback(finish_attack)

func animate_bow_attack(stats: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var bow = $BowVisual
	var aim_dir = get_aim_direction()
	update_weapon_icon_position()
	var tween = create_tween()
	tween.tween_property(bow, "scale", Vector2(1.3, 1.3), 0.06)
	tween.tween_property(bow, "scale", Vector2.ONE, 0.1)
	tween.tween_callback(finish_attack)
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + aim_dir * 20.0
	# target mask 2 (player) | 8 (buildings) -- enemy arrows can smash buildings
	arrow.setup(aim_dir, int(stats.damage * damage_multiplier), stats.knockback_min, stats.knockback_max, 2 | 8, true, ENEMY_ARROW_RANGE)
	get_parent().add_child(arrow)

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

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	is_knocked_back = false

func flash_hit() -> void:
	$ColorRect.color = Color(1, 1, 1)
	var tween = create_tween()
	tween.tween_property($ColorRect, "color", base_color.darkened(clamp(generation * 0.15, 0.0, 0.6)), 0.15)
	if has_node("Features"):
		$Features.modulate = Color(2.2, 2.2, 2.2)
		create_tween().tween_property($Features, "modulate", Color(1, 1, 1), 0.15)

func update_health_bar() -> void:
	var health_percent = float(health) / max_health
	$HealthBarFill.size.x = 40 * health_percent

func die() -> void:
	var reward = int(round(5 * damage_multiplier * (1.0 + GameState.get_bonus_total("gold_gain"))))
	if player.has_method("add_currency"):
		player.add_currency(reward)
	GameState.add_xp(int(round(8 * damage_multiplier)))
	spawn_coin_popup(reward)
	# low-rate construction-material drop (tougher gens roll a little better)
	var mat = GameState.roll_construction_drop(player, 1.0 + 0.15 * generation)
	if mat != "":
		spawn_material_popup(mat)
	is_dead = true
	is_attacking = false
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	died.emit()
	await play_death_animation()
	visible = false
	if not respawns:
		await get_tree().create_timer(0.5).timeout
		queue_free()
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	var mgr = get_tree().get_first_node_in_group("dungeon_manager")
	while mgr != null and mgr.started:
		await get_tree().create_timer(1.0).timeout
	respawn()

func play_death_animation() -> void:
	spawn_death_particles()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($ColorRect, "color", Color(1.0, 0.35, 0.05, 1), 0.15)
	tween.tween_property($ColorRect, "modulate:a", 0.0, 0.45).set_delay(0.1)
	if has_node("Features"):
		tween.tween_property($Features, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tween.tween_property(self, "scale", Vector2(0.15, 0.15), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.6
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 55.0
	particles.gravity = Vector2(0, -70)
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 85.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 4.5
	particles.color = Color(1.0, 0.45, 0.1, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func spawn_coin_popup(amount: int) -> void:
	var popup = Node2D.new()
	popup.global_position = global_position + Vector2(0, -30)
	get_parent().add_child(popup)

	# chunky octagonal coin -- fits the squarish pixel-art theme
	var coin = Polygon2D.new()
	coin.color = Color(1.0, 0.85, 0.2, 1)
	var points = PackedVector2Array()
	var radius = 7.0
	for i in range(8):
		var angle = (i + 0.5) * TAU / 8
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	coin.polygon = points
	popup.add_child(coin)

	var ring = Polygon2D.new()
	ring.color = Color(0.75, 0.55, 0.05, 1)
	var ring_points = PackedVector2Array()
	for i in range(8):
		var angle = (i + 0.5) * TAU / 8
		ring_points.append(Vector2(cos(angle), sin(angle)) * (radius - 2.0))
	ring.polygon = ring_points
	popup.add_child(ring)

	var label = Label.new()
	label.text = "+" + str(amount)
	label.position = Vector2(12, -8)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	popup.add_child(label)

	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 45, 0.8)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
	tween.tween_callback(popup.queue_free)

# Floating "+1 Wood" style popup when a construction material drops.
func spawn_material_popup(mat_id: String) -> void:
	var def = Inventory.get_item_def(mat_id)
	var col = def.get("color", Color(1, 1, 1, 1))
	var popup = Node2D.new()
	popup.global_position = global_position + Vector2(0, -48)
	get_parent().add_child(popup)

	var chip = Polygon2D.new()
	chip.color = col
	chip.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	popup.add_child(chip)

	var label = Label.new()
	label.text = "+1 " + Inventory.get_display_name(mat_id)
	label.position = Vector2(9, -10)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	popup.add_child(label)

	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 42, 0.9)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.9)
	tween.tween_callback(popup.queue_free)

func respawn() -> void:
	generation += 1
	max_health = int(round(MAX_HEALTH * pow(GROWTH_PER_RESPAWN, generation)))
	damage_multiplier = pow(GROWTH_PER_RESPAWN, generation)
	detection_range_current = DETECTION_RANGE * pow(GROWTH_PER_RESPAWN, generation)
	health = max_health
	global_position = spawn_position
	start_x = spawn_position.x
	direction = 1
	velocity = Vector2.ZERO
	is_knocked_back = false
	attack_cooldown_remaining = 0.0
	jump_cooldown_remaining = 0.0
	is_dead = false
	visible = true
	scale = Vector2.ONE
	$ColorRect.modulate = Color(1, 1, 1, 1)
	$CollisionShape2D.set_deferred("disabled", false)
	update_health_bar()
	update_body_color()
	print(name, " respawned: generation=", generation, " max_health=", max_health, " damage_x", damage_multiplier)
