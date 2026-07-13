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
const MAGIC_ORB = preload("res://magic_orb.gd")

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
	# Blink Stalker -- teleports behind you (never on top of you), then lunges.
	"stalker": {
		"hp": 60, "dmg": 18, "speed": 96.0, "reward": 10, "xp": 11,
		"main": Color(0.17, 0.15, 0.24), "accent": Color(0.6, 0.2, 0.95),
	},
	# Revenant Archer -- kites; blinks to a flank to fire, blinks away when close.
	"blink_archer": {
		"hp": 46, "dmg": 12, "speed": 72.0, "reward": 10, "xp": 11,
		"main": Color(0.19, 0.24, 0.26), "accent": Color(0.4, 0.95, 0.85),
	},
	# Hexer -- exhales an expanding ring of bolts with ONE gap to slip through.
	"hexer": {
		"hp": 52, "dmg": 11, "speed": 42.0, "reward": 11, "xp": 12,
		"main": Color(0.3, 0.15, 0.34), "accent": Color(0.9, 0.35, 1.0),
	},
	# Runecaster -- brands the ground with delayed sigils that erupt under you.
	"runecaster": {
		"hp": 54, "dmg": 22, "speed": 34.0, "reward": 11, "xp": 12,
		"main": Color(0.32, 0.22, 0.12), "accent": Color(1.0, 0.55, 0.2),
	},
	# Warlock -- conjures slow cursed orbs that home in and must be juked.
	"warlock": {
		"hp": 48, "dmg": 13, "speed": 40.0, "reward": 12, "xp": 13,
		"main": Color(0.15, 0.19, 0.32), "accent": Color(0.5, 0.5, 1.0),
	},
}

# injected before _ready
var kind := "flyer"
var elite := false            # bigger, tougher, glowing, double reward
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
# casters / teleporters
var cast_timer := 0.0
var tp_timer := 0.0
var state := "seek"          # generic small state machine (stalker)
var state_timer := 0.0
var lunge_dir := 1
var is_casting := false
var pending_tp := Vector2.ZERO

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

const STALKER_TP_INTERVAL = 3.4
const STALKER_MARK_TIME = 0.45      # destination is telegraphed this long first
const STALKER_LUNGE_TIME = 0.7
const STALKER_LUNGE_SPEED = 430.0
const STALKER_TP_DIST = 260.0       # appears this far behind you -- never on top
const STALKER_HIT_RANGE = 46.0

const BLINK_MIN_RANGE = 200.0       # if you get closer than this it blinks away
const BLINK_TP_INTERVAL = 3.6
const BLINK_SHOOT_RANGE = 640.0
const BLINK_SHOOT_CD = 1.6
const BLINK_FLANK_DIST = 430.0

const HEX_CAST_CD = 3.0
const HEX_BOLTS = 15
const HEX_GAP = 4                   # consecutive bolts skipped -> a dodge gap
const HEX_TELEGRAPH = 0.45
const HEX_BOLT_RANGE = 540.0

const RUNE_CAST_CD = 3.6
const RUNE_COUNT = 4
const RUNE_TELEGRAPH = 0.9
const RUNE_RADIUS = 56.0
const RUNE_SPREAD = 230.0

const WARLOCK_CAST_CD = 3.2
const WARLOCK_ORBS = 2
const WARLOCK_KEEP_RANGE = 320.0

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
	if elite:
		max_health = int(round(max_health * 1.6))
		health = max_health
		attack_damage = int(round(attack_damage * 1.25))
		reward *= 2
		xp_reward *= 2
		scale = Vector2(1.35, 1.35)
	hover_offset = Vector2(randf_range(-70.0, 70.0), -randf_range(150.0, 240.0))
	player = get_tree().get_first_node_in_group("player")
	build_collision()
	build_visual()
	build_health_bar()
	if elite:
		build_elite_glow()

func build_collision() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	match kind:
		"flyer": rect.size = Vector2(30, 30)
		"bomber": rect.size = Vector2(30, 28)
		"charger": rect.size = Vector2(46, 30)
		"spitter": rect.size = Vector2(40, 30)
		"stalker": rect.size = Vector2(30, 42)
		"blink_archer": rect.size = Vector2(28, 42)
		"hexer", "runecaster", "warlock": rect.size = Vector2(32, 44)
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
	if cast_timer > 0.0:
		cast_timer -= delta
	if tp_timer > 0.0:
		tp_timer -= delta
	if state_timer > 0.0:
		state_timer -= delta
	if is_knocked_back:
		move_and_slide()
		return

	if player != null and is_instance_valid(player):
		match kind:
			"flyer": act_flyer(delta)
			"bomber": act_bomber(delta)
			"charger": act_charger(delta)
			"spitter": act_spitter(delta)
			"stalker": act_stalker(delta)
			"blink_archer": act_blink_archer(delta)
			"hexer": act_hexer(delta)
			"runecaster": act_runecaster(delta)
			"warlock": act_warlock(delta)

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

# Blink Stalker -- seek, then telegraph a spot BEHIND the player, blink there,
# and lunge in. Never teleports on top of you (STALKER_TP_DIST away).
func act_stalker(delta: float) -> void:
	var dist = global_position.distance_to(player.global_position)
	match state:
		"seek":
			var dx = player.global_position.x - global_position.x
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			if dist < STALKER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				attack_cooldown = 0.9
			if tp_timer <= 0.0 and dist > 150.0:
				var side = -sign(player.global_position.x - global_position.x)
				if side == 0:
					side = 1
				pending_tp = Vector2(player.global_position.x + side * STALKER_TP_DIST, player.global_position.y)
				spawn_sigil(pending_tp, 26.0, STALKER_MARK_TIME, accent_color)
				state = "mark"
				state_timer = STALKER_MARK_TIME
		"mark":
			velocity.x = 0.0
			if state_timer <= 0.0:
				teleport_to(pending_tp)
				lunge_dir = sign(player.global_position.x - global_position.x)
				if lunge_dir == 0:
					lunge_dir = 1
				state = "lunge"
				state_timer = STALKER_LUNGE_TIME
		"lunge":
			velocity.x = lunge_dir * STALKER_LUNGE_SPEED
			if dist < STALKER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				if player.has_method("apply_knockback"):
					player.apply_knockback(lunge_dir, 160.0)
				attack_cooldown = 0.7
			var hit_wall = false
			for i in range(get_slide_collision_count()):
				if absf(get_slide_collision(i).get_normal().x) > 0.5:
					hit_wall = true
			if state_timer <= 0.0 or hit_wall:
				state = "seek"
				tp_timer = STALKER_TP_INTERVAL
	face_player()

# Revenant Archer -- fires from range, blinks to a flank on a timer AND
# immediately if the player closes the distance.
func act_blink_archer(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	var dist = global_position.distance_to(player.global_position)
	if dist < BLINK_MIN_RANGE or tp_timer <= 0.0:
		blink_to_flank()
		tp_timer = BLINK_TP_INTERVAL
	if dist < BLINK_SHOOT_RANGE and attack_cooldown <= 0.0:
		var base = (player.global_position - global_position).angle()
		for k in [-1, 0, 1]:
			fire_projectile(Vector2.RIGHT.rotated(base + deg_to_rad(9.0) * k), attack_damage)
		attack_cooldown = BLINK_SHOOT_CD

# Hexer -- keeps mid-range, then breathes an expanding ring of bolts with one
# gap left open. Slip through the gap or eat the whole ring.
func act_hexer(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 220.0:
		velocity.x = -sign(dx) * move_speed
	elif dist > 430.0:
		velocity.x = sign(dx) * move_speed
	else:
		velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting:
		cast_timer = HEX_CAST_CD
		cast_hex_ring()

func cast_hex_ring() -> void:
	is_casting = true
	set_flash(accent_color)
	await get_tree().create_timer(HEX_TELEGRAPH).timeout
	clear_flash()
	if is_dead:
		is_casting = false
		return
	var gap_start = randi() % HEX_BOLTS
	for i in range(HEX_BOLTS):
		if i >= gap_start and i < gap_start + HEX_GAP:
			continue
		var dir = Vector2.RIGHT.rotated(i * TAU / HEX_BOLTS)
		var arrow = ARROW_SCENE.instantiate()
		arrow.position = global_position + Vector2(0, -18) + dir * 20.0
		arrow.setup(dir, attack_damage, 8.0, 16.0, 2, true, HEX_BOLT_RANGE)
		get_parent().add_child(arrow)
	is_casting = false

# Runecaster -- brands the ground with delayed sigils around the player that
# erupt after a telegraph. Keep moving or get caught in one.
func act_runecaster(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	if cast_timer <= 0.0 and not is_casting:
		cast_timer = RUNE_CAST_CD
		cast_runes()

func cast_runes() -> void:
	is_casting = true
	set_flash(accent_color)
	var gy = player.global_position.y
	var xs: Array = []
	for i in range(RUNE_COUNT):
		xs.append(player.global_position.x + randf_range(-RUNE_SPREAD, RUNE_SPREAD))
	for x in xs:
		spawn_sigil(Vector2(x, gy), RUNE_RADIUS, RUNE_TELEGRAPH, accent_color)
	await get_tree().create_timer(RUNE_TELEGRAPH).timeout
	clear_flash()
	if is_dead:
		is_casting = false
		return
	for x in xs:
		erupt_rune(Vector2(x, gy))
		if player != null and is_instance_valid(player) and player.global_position.distance_to(Vector2(x, gy)) < RUNE_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
			if player.has_method("apply_knockback"):
				var away = sign(player.global_position.x - x)
				player.apply_knockback(away if away != 0 else 1, 150.0)
	is_casting = false

# Warlock -- conjures slow cursed orbs that home toward the player.
func act_warlock(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = -sign(dx) * move_speed if dist < WARLOCK_KEEP_RANGE else 0.0
	if cast_timer <= 0.0:
		cast_timer = WARLOCK_CAST_CD
		for i in range(WARLOCK_ORBS):
			var base = (player.global_position - global_position).normalized()
			var dir = base.rotated(deg_to_rad(randf_range(-18.0, 18.0)))
			var orb = MAGIC_ORB.new()
			orb.setup(dir, attack_damage, accent_color, 130.0)
			orb.position = position + Vector2(0, -18)
			get_parent().add_child(orb)

# --- caster/teleport helpers ---

func face_player() -> void:
	if player != null and is_instance_valid(player):
		var dx = player.global_position.x - global_position.x
		if absf(dx) > 4.0:
			facing = 1 if dx > 0 else -1

func arena_width() -> float:
	var s = get_tree().current_scene
	if s != null and "current_width" in s:
		return s.current_width
	return 2600.0

func teleport_to(target: Vector2) -> void:
	spawn_teleport_puff(global_position)
	var w = arena_width()
	global_position = Vector2(clampf(target.x, 70.0, w - 70.0), target.y)
	spawn_teleport_puff(global_position)
	modulate.a = 0.25
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func blink_to_flank() -> void:
	var side = 1.0 if randf() < 0.5 else -1.0
	teleport_to(Vector2(player.global_position.x + side * BLINK_FLANK_DIST, player.global_position.y))

func spawn_teleport_puff(p: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = p + Vector2(0, -18)
	particles.z_index = 9
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 10
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	particles.color = accent_color
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)

func spawn_sigil(pos: Vector2, radius: float, duration: float, color: Color) -> void:
	var ring = poly(circle_points(radius, 24))
	ring.color = Color(color.r, color.g, color.b, 0.25)
	ring.global_position = pos
	ring.z_index = 4
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_loops(int(duration / 0.16) + 1)
	t.tween_property(ring, "modulate:a", 0.15, 0.08)
	t.tween_property(ring, "modulate:a", 0.7, 0.08)
	get_tree().create_timer(duration).timeout.connect(ring.queue_free)

func erupt_rune(pos: Vector2) -> void:
	var burst = poly(circle_points(RUNE_RADIUS, 24))
	burst.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.55)
	burst.global_position = pos
	burst.z_index = 6
	burst.scale = Vector2(0.2, 0.2)
	get_parent().add_child(burst)
	var t = burst.create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2.ONE, 0.2)
	t.tween_property(burst, "modulate:a", 0.0, 0.28)
	t.chain().tween_callback(burst.queue_free)

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
		"stalker": build_stalker_visual()
		"blink_archer": build_blink_archer_visual()
		"hexer": build_hexer_visual()
		"runecaster": build_runecaster_visual()
		"warlock": build_warlock_visual()

func poly(points: PackedVector2Array) -> Polygon2D:
	var p = Polygon2D.new()
	p.polygon = points
	return p

func circle_points(r: float, _segs: int = 8) -> PackedVector2Array:
	# chunky octagon (flats up/down) -- squarish pixel-art theme
	var pts = PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * r)
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

# Blink Stalker -- a hooded cloaked assassin with a bared dagger.
func build_stalker_visual() -> void:
	add_part(poly(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(9, -30), Vector2(-9, -30)])), main_color)
	add_part(poly(PackedVector2Array([Vector2(-9, -26), Vector2(9, -26), Vector2(6, -44), Vector2(-6, -44)])), main_color.darkened(0.25))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -35)
		add_part(e, accent_color)
	add_part(poly(PackedVector2Array([Vector2(12, -16), Vector2(22, -20), Vector2(13, -11)])), Color(0.72, 0.72, 0.78))

# Revenant Archer -- a bony archer: ribbed torso, skull, and a bow.
func build_blink_archer_visual() -> void:
	add_part(poly(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -26), Vector2(-7, -26)])), main_color)
	for ry in [-6, -12, -18]:
		var rib = Line2D.new()
		rib.points = PackedVector2Array([Vector2(-7, ry), Vector2(7, ry)])
		rib.width = 1.2
		rib.default_color = BONE.darkened(0.1)
		visual.add_child(rib)
	var skull = poly(circle_points(7.0))
	skull.position = Vector2(0, -33)
	add_part(skull, BONE)
	for sx in [-2.6, 2.6]:
		var s = poly(circle_points(1.8))
		s.position = Vector2(sx, -33)
		add_part(s, accent_color)
	var bow = Line2D.new()
	bow.points = PackedVector2Array([Vector2(14, -30), Vector2(20, -16), Vector2(14, -2)])
	bow.width = 2.0
	bow.default_color = Color(0.35, 0.24, 0.16)
	visual.add_child(bow)

# Hexer -- a hunched robed mage cradling a glowing hex-orb.
func build_hexer_visual() -> void:
	_robe(main_color)
	add_part(poly(PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(7, -44), Vector2(-7, -44)])), main_color.darkened(0.2))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -36)
		add_part(e, accent_color)
	var orb = poly(circle_points(6.0))
	orb.position = Vector2(13, -10)
	add_part(orb, accent_color)

# Runecaster -- a tall pointed-hat mage with a rune staff.
func build_runecaster_visual() -> void:
	_robe(main_color)
	# tall witch hat
	add_part(poly(PackedVector2Array([Vector2(-11, -26), Vector2(11, -26), Vector2(2, -52)])), main_color.darkened(0.15))
	var e = poly(circle_points(2.2))
	e.position = Vector2(0, -30)
	add_part(e, accent_color)
	var staff = Line2D.new()
	staff.points = PackedVector2Array([Vector2(-14, 2), Vector2(-14, -34)])
	staff.width = 2.5
	staff.default_color = Color(0.3, 0.2, 0.12)
	visual.add_child(staff)
	var tip = poly(circle_points(4.5))
	tip.position = Vector2(-14, -36)
	add_part(tip, accent_color)

# Warlock -- a horned-hood mage with a cursed orb orbiting overhead.
func build_warlock_visual() -> void:
	_robe(main_color)
	add_part(poly(PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(7, -42), Vector2(-7, -42)])), main_color.darkened(0.2))
	# horns
	add_part(poly(PackedVector2Array([Vector2(-7, -40), Vector2(-13, -54), Vector2(-3, -42)])), accent_color)
	add_part(poly(PackedVector2Array([Vector2(7, -40), Vector2(13, -54), Vector2(3, -42)])), accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -34)
		add_part(e, accent_color)
	var orb = poly(circle_points(5.0))
	orb.position = Vector2(0, -58)
	add_part(orb, accent_color)

func _robe(color: Color) -> void:
	add_part(poly(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(10, -30), Vector2(-10, -30)])), color)

# A pulsing additive halo that marks an elite at a glance.
func build_elite_glow() -> void:
	var glow = poly(circle_points(26.0, 20))
	glow.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = Vector2(0, -18)
	glow.z_index = -2
	add_child(glow)
	var t = glow.create_tween()
	t.set_loops()
	t.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.5)
	t.tween_property(glow, "scale", Vector2(0.9, 0.9), 0.5)

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
