extends Node2D

# A slow homing projectile — the Mourncaller's Keening wisps, and reusable for
# any "swarm you have to outmaneuver, not outrun" signature. Steers toward the
# player at a capped turn rate (so a sharp juke still shakes it), damages on
# contact, and self-frees on a lifetime.

var speed := 165.0
var damage := 10
var turn := 2.6                       # rad/sec of steering authority
var lifetime := 4.5
var hit_radius := 26.0
var color := Color(0.6, 0.75, 1.0, 0.9)
var damage_multiplier := 1.0
var dir := Vector2.RIGHT
var _age := 0.0

func _ready() -> void:
	z_index = 30
	add_to_group("enemy_projectile")   # enemy-cast -> the player's shades can block it
	var v := Polygon2D.new()
	v.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(0, -6), Vector2(9, 0), Vector2(0, 6)])
	v.color = color
	add_child(v)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p):
		var desired: Vector2 = (p.global_position - global_position).normalized()
		var diff: float = dir.angle_to(desired)
		dir = dir.rotated(clampf(diff, -turn * delta, turn * delta)).normalized()
		if global_position.distance_to(p.global_position) < hit_radius:
			if p.has_method("take_damage"):
				p.take_damage(int(round(damage * damage_multiplier)))
			queue_free()
			return
	global_position += dir * speed * delta
	rotation = dir.angle()
