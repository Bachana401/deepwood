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
	# So the world can FIND a player shot in flight. Nothing could before, which
	# meant a mirror boss (boss.gd tick_mirror) had nothing to reflect -- it
	# would have looked implemented and silently done nothing forever.
	add_to_group("player_projectile")
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
		# a boss can absorb the shot outright -- don't print a number for a hit
		# that never landed (void take_damage means "landed")
		var landed = body.take_damage(damage)
		if landed == null or landed:
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
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
