extends CharacterBody2D

const SPEED = 900.0
const DEFAULT_MAX_RANGE = 700.0

const SFX_BREAK = preload("res://audio/arrow_deflect.wav")

var direction := Vector2.RIGHT
var damage := 0
var knockback_min := 0.0
var knockback_max := 0.0
var start_position := Vector2.ZERO
var has_hit := false
var max_range := DEFAULT_MAX_RANGE
var pierces_terrain := false
var is_crit := false   # set by the player when it rolls a crit for this arrow
var slows_player := false   # caster enemies fire chilling bolts that slow you
var enemy_statuses := []   # Warden keystones: list of {"kind","dur","mag"} applied on hit
var execute_threshold := 0.0   # Archer keystone Killshot: execute a non-boss below this HP frac
var execute_heal := 0.0        # Headhunter: heal this frac of max HP on an execute
var pierce_count := 0   # Marksman Piercing Shot / Skyfall: pass through this many foes
var poison_spread := false   # Warden Contagion: poison also splashes onto nearby foes
var pierced_bodies := []   # bodies already struck this flight (so pierce never double-hits)

# Seeker Bow: the arrow bends mid-flight toward the nearest living enemy
# (capped turn rate, so point-blank dodges still work). Enabled by the
# player's spawn_arrow when the wielded bow's special is "homing".
var homing := false
var girth := 1.0   # grade-driven scale: a heavier shaft, drawn AND felt
const HOMING_TURN_RATE = 5.0     # radians/sec of steering authority
const HOMING_RANGE = 460.0
const HOMING_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	# The "player_projectile" tag now happens in setup() and ONLY for the player's
	# own arrows -- enemy and boss arrows reuse this same scene, and tagging them
	# here made a mirror boss (boss.gd tick_mirror) reflect its OWN volley.
	start_position = global_position
	rotation = direction.angle()
	apply_girth()
	$HitArea.body_entered.connect(_on_hit_area_body_entered)

# Scales the shaft with its bow's grade -- the drawn arrow AND what it can hit,
# so a mythic bow's shot is genuinely a heavier projectile rather than a
# same-sized one wearing a bigger sprite.
func apply_girth() -> void:
	if is_equal_approx(girth, 1.0):
		return
	# NOTE: one RectangleShape2D resource is shared by the body, the hit area,
	# and every arrow ever fired -- duplicate before touching it or the change
	# leaks into every other arrow in the game.
	for cs in [$CollisionShape2D, $HitArea/HitAreaShape]:
		cs.shape = cs.shape.duplicate()
		if cs.shape is RectangleShape2D:
			cs.shape.size *= girth
	var cr: ColorRect = $ColorRect
	cr.offset_left *= girth
	cr.offset_top *= girth
	cr.offset_right *= girth
	cr.offset_bottom *= girth

func setup(dir: Vector2, dmg: int, kb_min: float, kb_max: float, target_mask: int = 4, pierce_terrain: bool = false, custom_max_range: float = -1.0) -> void:
	direction = dir.normalized()
	damage = dmg
	knockback_min = kb_min
	knockback_max = kb_max
	$HitArea.collision_mask = target_mask
	# Only the PLAYER's arrows are reflectable "player projectiles". A player arrow
	# targets the ENEMY layer (4) and never the player (layer 2); enemy/boss arrows
	# include layer 2 in their mask, so this cleanly excludes them.
	if (target_mask & 2) == 0:
		add_to_group("player_projectile")
	else:
		add_to_group("enemy_projectile")   # targets the player -> the player's DEFEND shades can body-block it
	pierces_terrain = pierce_terrain
	if pierces_terrain:
		collision_mask = 0
	if custom_max_range > 0.0:
		max_range = custom_max_range
	rotation = direction.angle()

func _physics_process(_delta: float) -> void:
	if has_hit:
		return

	if homing:
		steer_toward_prey(_delta)
	velocity = direction * SPEED
	move_and_slide()

	if global_position.distance_to(start_position) > max_range:
		despawn()
		return

	if not pierces_terrain and get_slide_collision_count() > 0:
		break_arrow()

func steer_toward_prey(delta: float) -> void:
	var prey: Node2D = null
	var prey_dist = HOMING_RANGE
	for group_name in HOMING_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e is Node2D:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d = global_position.distance_to(e.global_position)
			if d < prey_dist:
				prey_dist = d
				prey = e
	if prey == null:
		return
	var desired = (prey.global_position - global_position).normalized()
	var max_turn = HOMING_TURN_RATE * delta
	var angle_diff = direction.angle_to(desired)
	direction = direction.rotated(clamp(angle_diff, -max_turn, max_turn)).normalized()
	rotation = direction.angle()

func despawn() -> void:
	if has_hit:
		return
	has_hit = true
	queue_free()

func break_arrow() -> void:
	if has_hit:
		return
	has_hit = true
	set_physics_process(false)
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$HitArea.monitoring = false
	var sfx = $SFXPlayer
	sfx.reparent(get_parent())
	sfx.global_position = global_position
	sfx.stream = SFX_BREAK
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	queue_free()

func _on_hit_area_body_entered(body: Node2D) -> void:
	if has_hit or body in pierced_bodies:
		return
	pierced_bodies.append(body)
	if body.has_method("take_damage"):
		if body.is_in_group("player"):
			# the player's take_damage is a coroutine (its i-frames await
			# inside) -- fire and forget; reading its return would hand back
			# a function-state and log an async error on every enemy arrow
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
		else:
			# a boss can absorb the shot outright -- don't print a number for
			# a hit that never landed (void take_damage means "landed")
			var landed = body.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
	# KILLSHOT (Archer keystone): arrows execute a low-HP non-boss, same as apply_melee_skills
	# does for melee -- routed here because arrows never go through that path (dev 2026-07-26).
	if execute_threshold > 0.0 and not body.is_in_group("player") and not ("boss_id" in body) \
			and "max_health" in body and "health" in body and body.has_method("take_damage"):
		if float(body.health) <= float(body.max_health) * execute_threshold and float(body.health) > 0.0:
			body.take_damage(999999)
			if execute_heal > 0.0:
				var pl = get_tree().get_first_node_in_group("player")
				if pl != null and "health" in pl and pl.has_method("get_max_health"):
					pl.health = mini(pl.get_max_health(), pl.health + int(round(pl.get_max_health() * execute_heal)))
					if pl.has_method("update_health_display"):
						pl.update_health_display()
	# THE GOLDEN GAZE (Wukong road): the player's arrow paints its mark AFTER
	# its own damage lands -- the gold rewards the follow-up, not the marker.
	if is_in_group("player_projectile") and not body.is_in_group("player") \
			and GameState.get_bonus_total("golden_gaze") > 0.0 and body.has_method("take_damage"):
		body.set_meta("gold_mark_until", Time.get_ticks_msec() / 1000.0 + 2.5)
		if body.has_method("show_gold_mark"):
			body.show_gold_mark(2.5)
	if slows_player and body.has_method("apply_slow"):
		body.apply_slow(3.0, 0.55)
	if body.has_method("apply_status"):
		for st in enemy_statuses:
			body.apply_status(str(st.get("kind", "poison")), float(st.get("dur", 4.0)), float(st.get("mag", 0.0)))
	if poison_spread:
		spread_poison_near(body.global_position, body)
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(knockback_min, knockback_max)
		var knockback_dir_sign = 1 if direction.x >= 0 else -1
		body.apply_knockback(knockback_dir_sign, knockback_distance)
	# Piercing Shot: keep flying through the first N enemies instead of stopping
	if pierce_count > 0:
		pierce_count -= 1
		return
	has_hit = true
	set_physics_process(false)
	$HitArea.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false
	global_position = Vector2(200000, 200000)
	queue_free()

# Warden Contagion: the poison you just applied also seeps into nearby foes.
func spread_poison_near(center: Vector2, struck: Node2D) -> void:
	for group_name in HOMING_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == struck or not is_instance_valid(e) or not e.has_method("apply_status"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if e.global_position.distance_to(center) <= 120.0:
				e.apply_status("poison", 4.0, 6.0)
