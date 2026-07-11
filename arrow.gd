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

func _ready() -> void:
	start_position = global_position
	rotation = direction.angle()
	$HitArea.body_entered.connect(_on_hit_area_body_entered)

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

	velocity = direction * SPEED
	move_and_slide()

	if global_position.distance_to(start_position) > max_range:
		despawn()
		return

	if not pierces_terrain and get_slide_collision_count() > 0:
		break_arrow()

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
	if has_hit:
		return
	has_hit = true
	set_physics_process(false)
	$HitArea.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false
	global_position = Vector2(200000, 200000)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(knockback_min, knockback_max)
		var knockback_dir_sign = 1 if direction.x >= 0 else -1
		body.apply_knockback(knockback_dir_sign, knockback_distance)
	queue_free()
