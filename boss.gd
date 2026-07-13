extends CharacterBody2D

# ---------------------------------------------------------------------------
# Dungeon boss.
#
# Every 5th dungeon level (5, 10, 15, ...) spawns ONE boss. Rather than a
# single hard-coded fight, each boss is a data entry in BOSSES below: its own
# body/colors, base health, move speed, and -- most importantly -- its own
# hand-picked set of abilities from the shared library further down. That is
# what makes each boss feel individual.
#
# dungeon_interior.gd picks which boss id a level uses (see get_boss_id there),
# sets boss_id + the level scaling multipliers, THEN adds the node to the tree
# so _ready() can build itself from the matching definition.
# ---------------------------------------------------------------------------

const GRAVITY = 900.0
const ENRAGE_THRESHOLD = 0.5
const BUMP_THRESHOLD = 110.0
const WALL_TURN_DURATION = 0.8

# --- shared ability tuning ---
# Ranges are deliberately long: boss arenas are 3-5x the regular width, so a
# boss must be able to threaten across a big gap or it just gets kited.
const SLAM_RADIUS = 220.0
const SLAM_DAMAGE = 30
const SLAM_KNOCKBACK = 260.0
const SLAM_TELEGRAPH = 0.55

const CHARGE_SPEED = 720.0
const CHARGE_DURATION = 0.85
const CHARGE_DAMAGE = 26
const CHARGE_KNOCKBACK = 300.0
const CHARGE_TELEGRAPH = 0.45
const CHARGE_HIT_RADIUS = 135.0

const BARRAGE_COUNT = 7
const BARRAGE_SPREAD_DEG = 13.0
const BARRAGE_DAMAGE = 12
const BARRAGE_TELEGRAPH = 0.35
const BARRAGE_RANGE = 1300.0

const RAIN_COUNT = 13
const RAIN_DAMAGE = 12
const RAIN_TELEGRAPH = 0.6
const RAIN_HEIGHT = 470.0
const RAIN_HALF_SPREAD = 480.0

const NOVA_COUNT = 22
const NOVA_DAMAGE = 11
const NOVA_TELEGRAPH = 0.42
const NOVA_RANGE = 1300.0

const TELEPORT_TELEGRAPH = 0.32
const TELEPORT_SHOCK_DAMAGE = 22
const TELEPORT_SHOCK_RADIUS = 95.0

const SUMMON_COUNT = 2
const MAX_MINIONS = 4
const SUMMON_TELEGRAPH = 0.5

const PILLAR_COUNT = 6
const PILLAR_DAMAGE = 27
const PILLAR_TELEGRAPH = 0.7
const PILLAR_HALF_WIDTH = 46.0
const PILLAR_KNOCKBACK = 130.0
const PILLAR_HEIGHT = 320.0
const PILLAR_SPREAD = 720.0

# --- apex ability tuning (the level 35+ monsters) ---
const HOVER_ALTITUDE = 270.0        # how high a flying boss cruises above the player

const DIVE_DAMAGE = 34
const DIVE_RADIUS = 160.0
const DIVE_KNOCKBACK = 260.0
const DIVE_RISE_SPEED = 460.0
const DIVE_PLUNGE_SPEED = 980.0

const VOLLEY_COUNT = 6
const VOLLEY_DAMAGE = 10
const VOLLEY_INTERVAL = 0.16
const VOLLEY_RANGE = 1500.0

const METEOR_COUNT = 10
const METEOR_DAMAGE = 20
const METEOR_TELEGRAPH = 0.8
const METEOR_SPREAD = 850.0
const METEOR_HEIGHT = 800.0

const VORTEX_DURATION = 1.6
const VORTEX_TICK = 0.12
const VORTEX_PULL = 34.0
const VORTEX_RANGE = 900.0
const VORTEX_DAMAGE = 16
const VORTEX_CLOSE = 150.0

const BEAM_TELEGRAPH = 0.9
const BEAM_HALF_HEIGHT = 55.0
const BEAM_DAMAGE = 38
const BEAM_KNOCKBACK = 200.0

# Per-ability metadata: cooldown after use, and the player-distance window in
# which the ability is a valid choice. choose_attack() filters on these.
const ABILITY_META = {
	"slam":     {"cd": 3.5, "min": 0.0,   "max": 210.0},
	"charge":   {"cd": 4.5, "min": 160.0, "max": 100000.0},
	"barrage":  {"cd": 3.2, "min": 0.0,   "max": 100000.0},
	"rain":     {"cd": 5.5, "min": 0.0,   "max": 100000.0},
	"nova":     {"cd": 4.6, "min": 0.0,   "max": 480.0},
	"teleport": {"cd": 6.0, "min": 0.0,   "max": 100000.0},
	"summon":   {"cd": 10.0, "min": 0.0,  "max": 100000.0},
	"pillars":  {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	# apex abilities
	"dive":     {"cd": 5.0, "min": 0.0,   "max": 100000.0},
	"volley":   {"cd": 3.6, "min": 0.0,   "max": 100000.0},
	"meteors":  {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"vortex":   {"cd": 8.0, "min": 0.0,   "max": 100000.0},
	"beam":     {"cd": 7.0, "min": 0.0,   "max": 100000.0},
}

# The roster. Ids here must line up with BOSS_ARENAS / get_boss_id in
# dungeon_interior.gd so each boss gets its matching arena.
const BOSSES = {
	"gravewarden": {
		"name": "The Gravewarden",
		"color": Color(0.30, 0.42, 0.28), "eye_color": Color(0.7, 1.0, 0.4),
		"body": Vector2(172, 240), "hp": 900, "speed": 80.0,
		"abilities": ["slam", "charge", "summon"],
	},
	"frost_monarch": {
		"name": "The Frost Monarch",
		"color": Color(0.40, 0.6, 0.85), "eye_color": Color(0.85, 0.97, 1.0),
		"body": Vector2(142, 212), "hp": 820, "speed": 54.0,
		"abilities": ["rain", "nova", "teleport"],
	},
	"cinder_colossus": {
		"name": "The Cinder Colossus",
		"color": Color(0.72, 0.25, 0.12), "eye_color": Color(1.0, 0.85, 0.2),
		"body": Vector2(192, 252), "hp": 1050, "speed": 90.0,
		"abilities": ["charge", "barrage", "pillars"],
	},
	"weaver": {
		"name": "The Weaver",
		"color": Color(0.45, 0.25, 0.6), "eye_color": Color(1.0, 0.4, 0.9),
		"body": Vector2(150, 202), "hp": 800, "speed": 72.0,
		"abilities": ["summon", "nova", "teleport"],
	},
	"stormcaller": {
		"name": "The Stormcaller",
		"color": Color(0.85, 0.8, 0.35), "eye_color": Color(1.0, 1.0, 0.75),
		"body": Vector2(150, 216), "hp": 920, "speed": 84.0,
		"abilities": ["nova", "pillars", "barrage"],
	},
	"void_sovereign": {
		"name": "The Void Sovereign",
		"color": Color(0.2, 0.12, 0.3), "eye_color": Color(0.9, 0.2, 1.0),
		"body": Vector2(178, 246), "hp": 1220, "speed": 76.0,
		"abilities": ["teleport", "rain", "nova", "summon"],
	},
	# ----- APEX TIER (levels 35/40/45) -----
	# Built to be nearly unbeatable without endgame gear: apex bosses enrage
	# earlier, FRENZY at low health (cooldowns nearly vanish), and two of the
	# three fly. Their HP dwarfs the standard roster on top of level scaling.
	"seraph": {
		"name": "Seraphiel, the Last Light",
		"color": Color(0.92, 0.88, 0.68), "eye_color": Color(1.0, 0.55, 0.1),
		"body": Vector2(150, 240), "hp": 2400, "speed": 130.0,
		"flying": true, "apex": true,
		"abilities": ["dive", "volley", "rain", "nova"],
	},
	"leviathan": {
		"name": "The Abyssal Leviathan",
		"color": Color(0.1, 0.35, 0.4), "eye_color": Color(0.4, 1.0, 0.9),
		"body": Vector2(300, 150), "hp": 2800, "speed": 150.0,
		"flying": true, "apex": true,
		"abilities": ["charge", "vortex", "meteors", "summon"],
	},
	"eclipse": {
		"name": "The Eclipse Titan",
		"color": Color(0.1, 0.06, 0.08), "eye_color": Color(1.0, 0.2, 0.1),
		"body": Vector2(250, 330), "hp": 3300, "speed": 95.0,
		"apex": true,
		"abilities": ["beam", "pillars", "meteors", "teleport", "summon"],
	},
}

const ARROW_SCENE = preload("res://arrow.tscn")
const MINION_SCENE = preload("res://enemy.tscn")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_HIT = preload("res://audio/hit.wav")

signal died

# Set by dungeon_interior.gd before the node enters the tree.
var boss_id: String = "gravewarden"
var level_hp_mult := 1.0
var damage_multiplier := 1.0
var speed_multiplier := 1.0

var current_def: Dictionary = {}
var abilities: Array = []
var ability_cd: Dictionary = {}
var base_move_speed := 62.0

var player: Node2D = null
var max_health := 900
var health := 900
var is_dead := false
var is_enraged := false
var facing_direction := 1
var base_color: Color

var is_busy := false
var is_charging := false
var charge_direction := 1
var charge_dir_2d := Vector2.RIGHT   # flying bosses charge in a full 2D line
var charge_timer := 0.0
var charge_has_hit := false
var is_wall_blocked := false
var wall_turn_timer := 0.0

# apex state
var flying := false
var is_apex := false
var is_frenzied := false
var hover_time := 0.0
var is_diving := false
var dive_phase := 0
var dive_target := Vector2.ZERO
var dive_timer := 0.0

var minions: Array = []

func _ready() -> void:
	current_def = BOSSES.get(boss_id, BOSSES["gravewarden"])
	configure_from_def(current_def)
	player = get_tree().get_first_node_in_group("player")
	update_health_bar()

func configure_from_def(def: Dictionary) -> void:
	base_move_speed = float(def.get("speed", 62.0))
	flying = bool(def.get("flying", false))
	is_apex = bool(def.get("apex", false))
	abilities = (def.get("abilities", ["slam"]) as Array).duplicate()
	max_health = int(round(float(def.get("hp", 900)) * level_hp_mult))
	health = max_health

	# stagger initial cooldowns so the boss doesn't dump every ability at once
	for a in abilities:
		ability_cd[a] = randf_range(0.5, 1.7)

	var body: Vector2 = def.get("body", Vector2(160, 220))
	base_color = def.get("color", Color(0.32, 0.1, 0.38))

	var shape := RectangleShape2D.new()
	shape.size = body
	$CollisionShape2D.shape = shape

	$ColorRect.offset_left = -body.x / 2.0
	$ColorRect.offset_right = body.x / 2.0
	$ColorRect.offset_top = -body.y / 2.0
	$ColorRect.offset_bottom = body.y / 2.0
	$ColorRect.color = base_color

	var eye_color: Color = def.get("eye_color", Color(0.95, 0.15, 0.15))
	var ew := body.x * 0.14
	var ex := body.x * 0.2
	var ey := -body.y * 0.22
	place_eye($EyeLeft, -ex, ey, ew, eye_color)
	place_eye($EyeRight, ex, ey, ew, eye_color)

	var bar_y := -body.y / 2.0 - 26.0
	for bar in [$HealthBarBG, $HealthBarFill]:
		bar.offset_left = -80.0
		bar.offset_right = 80.0
		bar.offset_top = bar_y
		bar.offset_bottom = bar_y + 12.0

func place_eye(eye: ColorRect, cx: float, cy: float, size: float, color: Color) -> void:
	eye.offset_left = cx - size / 2.0
	eye.offset_right = cx + size / 2.0
	eye.offset_top = cy - size / 2.0
	eye.offset_bottom = cy + size / 2.0
	eye.color = color

func get_display_name() -> String:
	return current_def.get("name", "Boss")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# flying bosses ignore gravity entirely; they steer in full 2D
	if not flying and not is_on_floor():
		velocity.y += GRAVITY * delta

	for a in ability_cd.keys():
		if ability_cd[a] > 0.0:
			ability_cd[a] -= delta
	if wall_turn_timer > 0:
		wall_turn_timer -= delta
		if wall_turn_timer <= 0:
			is_wall_blocked = false

	if player != null and is_instance_valid(player):
		if is_charging:
			process_charge(delta)
		elif is_diving:
			process_dive(delta)
		elif not is_busy:
			var dx = player.global_position.x - global_position.x
			if absf(dx) > 4.0:
				facing_direction = sign(dx)
			var dist = global_position.distance_to(player.global_position)
			var chosen = choose_attack(dist)
			if chosen != "":
				start_attack(chosen)
			elif flying:
				process_hover(delta)
			elif wall_turn_timer > 0:
				velocity.x = -facing_direction * base_move_speed * speed_multiplier
			else:
				velocity.x = facing_direction * base_move_speed * speed_multiplier
		check_bump()

	move_and_slide()

	if not flying and not is_wall_blocked and not is_charging:
		for i in range(get_slide_collision_count()):
			if absf(get_slide_collision(i).get_normal().x) > 0.5:
				is_wall_blocked = true
				wall_turn_timer = WALL_TURN_DURATION
				break

# Cruise toward a point hovering above the player, with a slow wing-beat bob.
func process_hover(delta: float) -> void:
	hover_time += delta
	var target = player.global_position + Vector2(0, -HOVER_ALTITUDE)
	var to_target = target - global_position
	if to_target.length() > 40.0:
		velocity = to_target.normalized() * base_move_speed * speed_multiplier
	else:
		velocity = to_target * 2.0
	velocity.y += sin(hover_time * 3.0) * 28.0

func choose_attack(dist: float) -> String:
	var candidates: Array = []
	for a in abilities:
		var meta = ABILITY_META.get(a, null)
		if meta == null:
			continue
		if ability_cd.get(a, 0.0) > 0.0:
			continue
		if dist < meta["min"] or dist > meta["max"]:
			continue
		candidates.append(a)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]

func start_attack(attack_name: String) -> void:
	is_busy = true
	velocity.x = 0
	match attack_name:
		"slam": do_slam()
		"charge": do_charge()
		"barrage": do_barrage()
		"rain": do_rain()
		"nova": do_nova()
		"teleport": do_teleport()
		"summon": do_summon()
		"pillars": do_pillars()
		"dive": do_dive()
		"volley": do_volley()
		"meteors": do_meteors()
		"vortex": do_vortex()
		"beam": do_beam()
		_:
			is_busy = false

func set_cd(ability_name: String) -> void:
	ability_cd[ability_name] = ABILITY_META[ability_name]["cd"] * cooldown_mult()

func cooldown_mult() -> float:
	if is_frenzied:
		return 0.35
	if is_enraged:
		return 0.5 if is_apex else 0.6
	return 1.0

# --- abilities ---

func do_slam() -> void:
	flash_telegraph(Color(1.0, 0.9, 0.2))
	spawn_ring_telegraph(global_position, SLAM_RADIUS, Color(1.0, 0.85, 0.2), SLAM_TELEGRAPH)
	await get_tree().create_timer(SLAM_TELEGRAPH).timeout
	if is_dead:
		return
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < SLAM_RADIUS:
		deal_player_damage(SLAM_DAMAGE)
		knockback_player_away(SLAM_KNOCKBACK)
	shake_camera(10.0, 0.35)
	spawn_shockwave(SLAM_RADIUS, Color(1.0, 0.8, 0.3))
	set_cd("slam")
	is_busy = false

func do_charge() -> void:
	flash_telegraph(Color(1.0, 0.3, 0.2))
	await get_tree().create_timer(CHARGE_TELEGRAPH).timeout
	if is_dead:
		return
	charge_direction = facing_direction
	# a flying boss locks a full 2D line onto the player and sweeps along it
	if flying and player != null and is_instance_valid(player):
		charge_dir_2d = (player.global_position - global_position).normalized()
	is_charging = true
	charge_timer = CHARGE_DURATION
	charge_has_hit = false

func process_charge(delta: float) -> void:
	if flying:
		velocity = charge_dir_2d * CHARGE_SPEED * speed_multiplier
	else:
		velocity.x = charge_direction * CHARGE_SPEED * speed_multiplier
	charge_timer -= delta
	if not charge_has_hit and player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < CHARGE_HIT_RADIUS:
		charge_has_hit = true
		deal_player_damage(CHARGE_DAMAGE)
		if player.has_method("apply_knockback"):
			player.apply_knockback(charge_direction, CHARGE_KNOCKBACK)
		shake_camera(9.0, 0.3)
	var hit_wall = false
	for i in range(get_slide_collision_count()):
		# an aerial sweep ends on ANY surface; a ground charge only on walls
		if flying or absf(get_slide_collision(i).get_normal().x) > 0.5:
			hit_wall = true
			break
	if charge_timer <= 0 or hit_wall:
		is_charging = false
		velocity = Vector2.ZERO if flying else Vector2(0, velocity.y)
		set_cd("charge")
		is_busy = false

func do_barrage() -> void:
	flash_telegraph(Color(1.0, 0.6, 0.1))
	await get_tree().create_timer(BARRAGE_TELEGRAPH).timeout
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("barrage")
		return
	var base_angle = (player.global_position - global_position).angle()
	var half = BARRAGE_COUNT / 2
	for i in range(BARRAGE_COUNT):
		var angle = base_angle + deg_to_rad(BARRAGE_SPREAD_DEG) * (i - half)
		var dir = Vector2.RIGHT.rotated(angle)
		spawn_arrow(global_position + dir * 44.0, dir, BARRAGE_DAMAGE, BARRAGE_RANGE)
	set_cd("barrage")
	is_busy = false

func do_nova() -> void:
	flash_telegraph(Color(0.7, 0.9, 1.0))
	await get_tree().create_timer(NOVA_TELEGRAPH).timeout
	if is_dead:
		return
	var jitter = randf() * TAU
	for i in range(NOVA_COUNT):
		var angle = jitter + i * TAU / NOVA_COUNT
		var dir = Vector2.RIGHT.rotated(angle)
		spawn_arrow(global_position + dir * 40.0, dir, NOVA_DAMAGE, NOVA_RANGE)
	shake_camera(5.0, 0.2)
	set_cd("nova")
	is_busy = false

func do_rain() -> void:
	flash_telegraph(Color(0.6, 0.8, 1.0))
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("rain")
		return
	var center_x = player.global_position.x
	var ground_y = player.global_position.y
	var xs: Array = []
	for i in range(RAIN_COUNT):
		xs.append(center_x + randf_range(-RAIN_HALF_SPREAD, RAIN_HALF_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), Color(0.5, 0.75, 1.0), RAIN_TELEGRAPH)
	await get_tree().create_timer(RAIN_TELEGRAPH).timeout
	if is_dead:
		return
	for x in xs:
		var spawn_pos = Vector2(x, ground_y - RAIN_HEIGHT)
		spawn_arrow(spawn_pos, Vector2.DOWN, RAIN_DAMAGE, RAIN_HEIGHT + 120.0)
		await get_tree().create_timer(0.05).timeout
		if is_dead:
			return
	set_cd("rain")
	is_busy = false

func do_teleport() -> void:
	# blink out, reappear on a random side of the player, then a close shock.
	var tween = create_tween()
	tween.tween_property($ColorRect, "modulate:a", 0.15, TELEPORT_TELEGRAPH)
	await tween.finished
	if is_dead:
		return
	if player != null and is_instance_valid(player):
		var side = 1 if randf() < 0.5 else -1
		var target_x = player.global_position.x + side * randf_range(150.0, 240.0)
		global_position = Vector2(target_x, player.global_position.y)
		facing_direction = -side
	var tween2 = create_tween()
	tween2.tween_property($ColorRect, "modulate:a", 1.0, 0.15)
	spawn_shockwave(TELEPORT_SHOCK_RADIUS, Color(0.8, 0.3, 1.0))
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < TELEPORT_SHOCK_RADIUS:
		deal_player_damage(TELEPORT_SHOCK_DAMAGE)
		knockback_player_away(160.0)
	set_cd("teleport")
	is_busy = false

func do_summon() -> void:
	flash_telegraph(Color(0.7, 0.3, 0.9))
	await get_tree().create_timer(SUMMON_TELEGRAPH).timeout
	if is_dead:
		set_cd("summon")
		return
	minions = minions.filter(func(m): return is_instance_valid(m) and not (("is_dead" in m) and m.is_dead))
	var room = MAX_MINIONS - minions.size()
	for i in range(min(SUMMON_COUNT, room)):
		var m = MINION_SCENE.instantiate()
		m.respawns = false
		m.instant_aggro = true
		m.wave_hp_multiplier = 0.6 * level_hp_mult
		m.wave_damage_multiplier = 0.7 * damage_multiplier
		m.wave_speed_multiplier = speed_multiplier
		m.position = global_position + Vector2(randf_range(-110.0, 110.0), -30.0)
		m.add_to_group("dungeon_combatant")
		get_parent().add_child(m)
		minions.append(m)
	set_cd("summon")
	is_busy = false

func do_pillars() -> void:
	flash_telegraph(Color(1.0, 0.5, 0.15))
	if player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("pillars")
		return
	var ground_y = player.global_position.y
	var xs: Array = [player.global_position.x]
	for i in range(PILLAR_COUNT - 1):
		xs.append(player.global_position.x + randf_range(-PILLAR_SPREAD, PILLAR_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), Color(1.0, 0.5, 0.1), PILLAR_TELEGRAPH, PILLAR_HALF_WIDTH * 2.0)
	await get_tree().create_timer(PILLAR_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(7.0, 0.3)
	for x in xs:
		erupt_pillar(Vector2(x, ground_y))
		if player != null and is_instance_valid(player) and absf(player.global_position.x - x) < PILLAR_HALF_WIDTH:
			deal_player_damage(PILLAR_DAMAGE)
			var away = sign(player.global_position.x - x)
			if away == 0:
				away = 1
			if player.has_method("apply_knockback"):
				player.apply_knockback(away, PILLAR_KNOCKBACK)
	set_cd("pillars")
	is_busy = false

# --- apex abilities ---

# Dive bomb (flying): climb to a point high above the player, lock their
# position, then plummet through it and detonate on impact.
func do_dive() -> void:
	flash_telegraph(Color(1.0, 0.8, 0.3))
	is_diving = true
	dive_phase = 0
	dive_timer = 1.4

func process_dive(delta: float) -> void:
	dive_timer -= delta
	if dive_phase == 0:
		var target = player.global_position + Vector2(0, -380.0)
		var to_target = target - global_position
		velocity = to_target.normalized() * DIVE_RISE_SPEED
		if to_target.length() < 50.0 or dive_timer <= 0:
			dive_phase = 1
			dive_timer = 1.2
			dive_target = player.global_position
			spawn_ground_marker(dive_target, Color(1.0, 0.8, 0.2), 0.3, DIVE_RADIUS)
	else:
		velocity = (dive_target - global_position).normalized() * DIVE_PLUNGE_SPEED
		var hit_surface = get_slide_collision_count() > 0
		if global_position.distance_to(dive_target) < 60.0 or hit_surface or dive_timer <= 0:
			shake_camera(11.0, 0.4)
			spawn_shockwave(DIVE_RADIUS, Color(1.0, 0.85, 0.3))
			if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < DIVE_RADIUS:
				deal_player_damage(DIVE_DAMAGE)
				knockback_player_away(DIVE_KNOCKBACK)
			is_diving = false
			velocity = Vector2.ZERO
			set_cd("dive")
			is_busy = false

# Rapid volley: a burst of shots, each re-aimed at the player mid-burst.
func do_volley() -> void:
	flash_telegraph(Color(1.0, 0.9, 0.5))
	await get_tree().create_timer(0.3).timeout
	for i in range(VOLLEY_COUNT):
		if is_dead or player == null or not is_instance_valid(player):
			break
		var dir = (player.global_position - global_position).normalized()
		spawn_arrow(global_position + dir * 46.0, dir, VOLLEY_DAMAGE, VOLLEY_RANGE)
		await get_tree().create_timer(VOLLEY_INTERVAL).timeout
	set_cd("volley")
	is_busy = false

# Meteor storm: like rain but heavier, wider, and falling from far higher.
func do_meteors() -> void:
	flash_telegraph(Color(1.0, 0.4, 0.1))
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("meteors")
		return
	var ground_y = player.global_position.y
	var xs: Array = [player.global_position.x]
	for i in range(METEOR_COUNT - 1):
		xs.append(player.global_position.x + randf_range(-METEOR_SPREAD, METEOR_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), Color(1.0, 0.45, 0.1), METEOR_TELEGRAPH, 90.0)
	await get_tree().create_timer(METEOR_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.5)
	for x in xs:
		spawn_arrow(Vector2(x, ground_y - METEOR_HEIGHT), Vector2.DOWN, METEOR_DAMAGE, METEOR_HEIGHT + 150.0)
		await get_tree().create_timer(0.06).timeout
		if is_dead:
			return
	set_cd("meteors")
	is_busy = false

# Vortex: drags the player toward the boss for a sustained pull, then bites
# if they end up in its jaws. Fighting the pull means dashing/flying away.
func do_vortex() -> void:
	flash_telegraph(Color(0.3, 0.95, 0.85))
	spawn_ring_telegraph(global_position, VORTEX_RANGE * 0.4, Color(0.3, 0.95, 0.85), 0.45)
	await get_tree().create_timer(0.45).timeout
	var ticks = int(VORTEX_DURATION / VORTEX_TICK)
	for i in range(ticks):
		if is_dead or player == null or not is_instance_valid(player):
			break
		var dist = global_position.distance_to(player.global_position)
		if dist < VORTEX_RANGE and player.has_method("apply_knockback"):
			var toward = sign(global_position.x - player.global_position.x)
			if toward != 0:
				player.apply_knockback(toward, VORTEX_PULL)
		if i % 3 == 0:
			spawn_shockwave(90.0 + i * 14.0, Color(0.3, 0.95, 0.85))
		await get_tree().create_timer(VORTEX_TICK).timeout
	if not is_dead and player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < VORTEX_CLOSE:
		deal_player_damage(VORTEX_DAMAGE)
		knockback_player_away(180.0)
	set_cd("vortex")
	is_busy = false

# Eclipse beam: locks a horizontal band at the player's altitude across the
# WHOLE arena, then fires. The only escape is changing height -- which is
# exactly what the tiered crater (and late-game flight) is for.
func do_beam() -> void:
	if player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("beam")
		return
	var band_y = player.global_position.y - 20.0
	var scene = get_tree().current_scene
	var arena_w: float = scene.current_width if (scene != null and "current_width" in scene) else 15000.0
	flash_telegraph(Color(1.0, 0.25, 0.15))
	var band = ColorRect.new()
	band.position = Vector2(-100.0, band_y - BEAM_HALF_HEIGHT)
	band.size = Vector2(arena_w + 200.0, BEAM_HALF_HEIGHT * 2.0)
	band.color = Color(1.0, 0.2, 0.1, 0.14)
	band.z_index = 5
	get_parent().add_child(band)
	var warn = band.create_tween()
	warn.set_loops(4)
	warn.tween_property(band, "modulate:a", 0.4, BEAM_TELEGRAPH / 8.0)
	warn.tween_property(band, "modulate:a", 1.0, BEAM_TELEGRAPH / 8.0)
	await get_tree().create_timer(BEAM_TELEGRAPH).timeout
	if is_dead:
		if is_instance_valid(band):
			band.queue_free()
		return
	# fire: two damage ticks 0.2s apart so hopping through the band still hurts
	band.color = Color(1.0, 0.3, 0.12, 0.75)
	shake_camera(8.0, 0.3)
	for tick in range(2):
		if player != null and is_instance_valid(player) and absf(player.global_position.y - band_y) < BEAM_HALF_HEIGHT:
			deal_player_damage(BEAM_DAMAGE / (tick + 1))
			if player.has_method("apply_knockback"):
				player.apply_knockback(facing_direction, BEAM_KNOCKBACK / (tick + 1))
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(band):
		var fade = band.create_tween()
		fade.tween_property(band, "modulate:a", 0.0, 0.25)
		fade.tween_callback(band.queue_free)
	set_cd("beam")
	is_busy = false

# --- ability helpers ---

func spawn_arrow(pos: Vector2, dir: Vector2, dmg: int, rng: float) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = pos
	arrow.setup(dir.normalized(), int(round(dmg * damage_multiplier)), 15.0, 30.0, 2, true, rng)
	get_parent().add_child(arrow)

func deal_player_damage(amount: int) -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(int(round(amount * damage_multiplier)))

func knockback_player_away(distance: float) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("apply_knockback"):
		return
	var away = sign(player.global_position.x - global_position.x)
	if away == 0:
		away = facing_direction
	player.apply_knockback(away, distance)

func shake_camera(magnitude: float, duration: float) -> void:
	if player != null and is_instance_valid(player) and player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(magnitude, duration)

func spawn_ring_telegraph(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var ring = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(28):
		pts.append(Vector2(cos(i * TAU / 28), sin(i * TAU / 28)) * radius)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.18)
	ring.global_position = center
	ring.z_index = 5
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.tween_property(ring, "modulate:a", 0.0, duration)
	t.tween_callback(ring.queue_free)

func spawn_shockwave(radius: float, color: Color) -> void:
	var ring = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(28):
		pts.append(Vector2(cos(i * TAU / 28), sin(i * TAU / 28)) * radius)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.5)
	ring.global_position = global_position
	ring.z_index = 6
	ring.scale = Vector2(0.2, 0.2)
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.3)
	t.tween_property(ring, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(ring.queue_free)

func spawn_ground_marker(pos: Vector2, color: Color, duration: float, width: float = 60.0) -> void:
	var marker = ColorRect.new()
	marker.size = Vector2(width, 10.0)
	marker.position = pos - Vector2(width / 2.0, 5.0)
	marker.color = Color(color.r, color.g, color.b, 0.55)
	marker.z_index = 5
	get_parent().add_child(marker)
	var t = marker.create_tween()
	t.set_loops(int(duration / 0.16) + 1)
	t.tween_property(marker, "modulate:a", 0.2, 0.08)
	t.tween_property(marker, "modulate:a", 0.8, 0.08)
	get_tree().create_timer(duration).timeout.connect(marker.queue_free)

func erupt_pillar(base: Vector2) -> void:
	var pillar = ColorRect.new()
	pillar.size = Vector2(PILLAR_HALF_WIDTH * 2.0, PILLAR_HEIGHT)
	pillar.position = base - Vector2(PILLAR_HALF_WIDTH, PILLAR_HEIGHT)
	pillar.color = Color(1.0, 0.45, 0.12, 0.9)
	pillar.z_index = 6
	pillar.scale.y = 0.05
	get_parent().add_child(pillar)
	var t = pillar.create_tween()
	t.tween_property(pillar, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.15)
	t.tween_property(pillar, "modulate:a", 0.0, 0.25)
	t.tween_callback(pillar.queue_free)

# --- combat / lifecycle ---

func check_bump() -> void:
	if is_busy or is_charging or is_dead or player == null or not is_instance_valid(player) or player.is_knocked_back:
		return
	if global_position.distance_to(player.global_position) > BUMP_THRESHOLD:
		return
	var away = sign(player.global_position.x - global_position.x)
	if away == 0:
		away = 1
	if player.has_method("apply_knockback"):
		player.apply_knockback(away, randf_range(30.0, 45.0))

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
		# apex bosses enrage earlier AND hit a second gear near death
		var enrage_at = 0.6 if is_apex else ENRAGE_THRESHOLD
		if not is_enraged and health <= max_health * enrage_at:
			enrage()
		if is_apex and not is_frenzied and health <= max_health * 0.25:
			frenzy()

func enrage() -> void:
	is_enraged = true
	base_color = base_color.lerp(Color(0.6, 0.0, 0.0), 0.4)
	$ColorRect.color = base_color

# Apex second wind: cooldowns nearly vanish and it moves a quarter faster.
func frenzy() -> void:
	is_frenzied = true
	base_color = base_color.lerp(Color(1.0, 0.1, 0.05), 0.5)
	$ColorRect.color = base_color
	base_move_speed *= 1.25
	shake_camera(9.0, 0.5)
	spawn_shockwave(240.0, Color(1.0, 0.15, 0.1))

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
	is_dead = true
	is_busy = true
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	# clear any minions this boss summoned so they don't linger after the fight
	for m in minions:
		if is_instance_valid(m) and m.has_method("take_damage"):
			m.take_damage(999999)
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
