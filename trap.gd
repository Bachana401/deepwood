extends Area2D

const TRIGGER_DELAY = 0.7
const BLINK_INTERVAL = 0.12
const EXPLOSION_RADIUS = 55.0
const DAMAGE = 22
const KNOCKBACK_MIN = 30.0
const KNOCKBACK_MAX = 45.0
const REARM_DELAY = 14.0

const SFX_EXPLOSION = preload("res://audio/explosion.wav")

var armed = true
var triggered = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not armed or triggered:
		return
	if not body.is_in_group("player"):
		return
	triggered = true
	trigger_sequence()

func trigger_sequence() -> void:
	armed = false
	var elapsed = 0.0
	while elapsed < TRIGGER_DELAY:
		$WarningIcon.visible = not $WarningIcon.visible
		await get_tree().create_timer(BLINK_INTERVAL).timeout
		elapsed += BLINK_INTERVAL
	explode()

func explode() -> void:
	$Plate.visible = false
	$WarningIcon.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	play_explosion_effects()
	var player = get_tree().get_first_node_in_group("player")
	if player != null and global_position.distance_to(player.global_position) <= EXPLOSION_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE)
		if player.has_method("apply_knockback"):
			var away = sign(player.global_position.x - global_position.x)
			if away == 0:
				away = 1
			player.apply_knockback(away, randf_range(KNOCKBACK_MIN, KNOCKBACK_MAX))
		if player.has_node("Camera2D"):
			player.get_node("Camera2D").shake(9.0, 0.3)
	# freed-safe rearm (audit fix): mines cluster near the entry corridor, so
	# tripping one and using the leave gate inside the 14s window was the
	# COMMON case -- the timer then resumed into a freed node's $Plate.
	var iid := get_instance_id()
	await get_tree().create_timer(REARM_DELAY).timeout
	if instance_from_id(iid) == null or not is_inside_tree():
		return
	rearm()

func play_explosion_effects() -> void:
	$SFXPlayer.stream = SFX_EXPLOSION
	$SFXPlayer.play()
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 100.0
	particles.gravity = Vector2(0, 260)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1.0, 0.45, 0.05, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func rearm() -> void:
	triggered = false
	armed = true
	$Plate.visible = true
	$CollisionShape2D.set_deferred("disabled", false)
