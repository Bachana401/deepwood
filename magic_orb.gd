extends Node2D

# A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It
# steers toward the player with a capped turn rate -- fast enough to threaten,
# slow enough to juke around -- and pops (dealing damage) on contact or when
# its lifetime runs out. Deliberately NOT on a hostile collision layer: it's a
# hazard to dodge, not a target to shoot. Self-contained; injected with
# damage/speed by its caster before entering the tree.

var damage := 12
var speed := 130.0
var turn_rate := 2.4          # radians/sec the heading can rotate toward you
var lifetime := 4.5
var hit_radius := 22.0
var color := Color(0.7, 0.25, 0.95)

var player: Node2D = null
var heading := Vector2.RIGHT
var age := 0.0
var popped := false
var core: Polygon2D = null
var glow: Polygon2D = null

func setup(dir: Vector2, dmg: int, orb_color: Color, orb_speed := 130.0) -> void:
	heading = dir.normalized()
	damage = dmg
	color = orb_color
	speed = orb_speed

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemy_projectile")   # enemy-cast (boss/special_mob) -> the player's shades can block it
	build_visual()

func build_visual() -> void:
	glow = _disc(15.0, Color(color.r, color.g, color.b, 0.28))
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	core = _disc(8.0, color)
	add_child(core)
	var eye = _disc(3.0, Color(0.05, 0.02, 0.08))
	add_child(eye)

func _disc(r: float, c: Color) -> Polygon2D:
	# squarish pixel-art style: the orb is a block with a diamond glow
	var p = Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	p.color = c
	return p

func _physics_process(delta: float) -> void:
	if popped:
		return
	age += delta
	if age >= lifetime:
		pop(false)
		return
	if player != null and is_instance_valid(player):
		var desired = (player.global_position - global_position).normalized()
		var current_angle = heading.angle()
		var target_angle = desired.angle()
		var diff = wrapf(target_angle - current_angle, -PI, PI)
		var step = clampf(diff, -turn_rate * delta, turn_rate * delta)
		heading = Vector2.RIGHT.rotated(current_angle + step)
		if global_position.distance_to(player.global_position) < hit_radius:
			pop(true)
			return
	global_position += heading * speed * delta
	if core:
		var pulse = 1.0 + sin(age * 10.0) * 0.15
		core.scale = Vector2(pulse, pulse)

func pop(hit_player: bool) -> void:
	if popped:
		return
	popped = true
	if hit_player and player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage)
		if player.has_method("apply_knockback"):
			var away = sign(player.global_position.x - global_position.x)
			player.apply_knockback(away if away != 0 else 1, 90.0)
	spawn_burst()
	queue_free()

func spawn_burst() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	particles.color = color
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)
