extends Node2D

# THE ARENA, AS ITS OWN SCENE (dev, 2026-07-30: "you have bad arena btw. bad
# placement on puppet, it should be absolutely separate scene").
#
# Every probe so far ran inside the LIVE VILLAGE: it found whatever player
# happened to exist, wherever they happened to be standing, with whatever
# terrain, buildings, NPCs and time of day were around them. That is not a test
# rig, it is a photograph of a moment. Two consequences bit today:
#
#   * MARKS LANDED BADLY. Placed relative to a player standing anywhere, they
#     ended up inside hillsides, in mid-air, or off the play area entirely --
#     the dev's "bad placement on puppet".
#   * FRAMES WERE NOT COMPARABLE. Two EYES runs of the same weapon differed by
#     background, light and camera, so a colour judgement between runs meant
#     nothing. I shot the Crown's Sorrow twice and the second frame's biggest
#     visible change was where it happened to be pointing.
#
# So: a scene with nothing in it but a floor, a backdrop, a puppet and three
# marks, at FIXED coordinates every single time. The floor is deliberately long
# and flat, the marks stand ON it at known distances, and the backdrop is the
# game's own night blue rather than a void -- contrast has to be judged against
# what the game actually looks like, not against black.

const PLAYER_SCENE := preload("res://player.tscn")
const MARK_AT := [70.0, 190.0, 330.0]
const FLOOR_Y := 360.0
const SPAWN := Vector2(200.0, 296.0)

var player: Node2D = null
var marks: Array = []

class Mark extends StaticBody2D:
	var health := 999999999
	var max_health := 999999999
	var is_dead := false
	var hits := 0
	var total := 0
	var first_at := -1.0
	var born := 0.0
	var tag := ""
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 64)
		cs.shape = sh
		add_child(cs)
	func _ready() -> void:
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-17, -32), Vector2(17, -32), Vector2(17, 32), Vector2(-17, 32)])
		body.color = Color(0.46, 0.37, 0.28, 1.0)
		add_child(body)
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(-17, -10), Vector2(17, -10), Vector2(17, -2), Vector2(-17, -2)])
		band.color = Color(0.86, 0.78, 0.56, 1.0)
		add_child(band)
		z_index = 20
	func take_damage(n: int):
		hits += 1
		total += n
		if first_at < 0.0:
			first_at = Time.get_ticks_msec() / 1000.0 - born
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass
	func reset() -> void:
		hits = 0
		total = 0
		first_at = -1.0
		born = Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	_backdrop()
	_floor()
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = SPAWN
	# the puppet never aims at a cursor in here -- see player.set_test_aim
	if player.has_method("set_test_aim"):
		player.set_test_aim(Vector2.RIGHT)
	var born := Time.get_ticks_msec() / 1000.0
	for d in MARK_AT:
		var m := Mark.new()
		m.born = born
		m.tag = "%dpx" % int(d)
		m.add_to_group("course_enemy")
		add_child(m)
		# ON the floor, not floating above it and not buried in it
		m.global_position = Vector2(SPAWN.x + float(d), FLOOR_Y - 32.0)
		marks.append(m)

# the game's own night blue, not a void: a projectile has to be judged against
# the background it will actually be seen on
func _backdrop() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.11, 0.20, 1.0)
	sky.size = Vector2(2400, 1400)
	sky.position = Vector2(-600, -700)
	sky.z_index = -100
	add_child(sky)

func _floor() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(2000, 120)
	cs.shape = sh
	ground.add_child(cs)
	ground.global_position = Vector2(700, FLOOR_Y + 60.0)
	add_child(ground)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([
		Vector2(-1000, -60), Vector2(1000, -60), Vector2(1000, 60), Vector2(-1000, 60)])
	top.color = Color(0.17, 0.19, 0.16, 1.0)
	ground.add_child(top)

func reset_marks() -> void:
	for m in marks:
		if is_instance_valid(m):
			m.reset()

func totals() -> Dictionary:
	var hits := 0
	var dmg := 0
	var struck := 0
	var reach := 0.0
	for i in range(marks.size()):
		var m = marks[i]
		if not is_instance_valid(m):
			continue
		if m.hits > 0:
			struck += 1
			reach = maxf(reach, float(MARK_AT[i]))
		hits += m.hits
		dmg += m.total
	return {"hits": hits, "dmg": dmg, "struck": struck, "reach": reach}

# swap the running game out for a clean arena. Returns the arena node.
static func take_over(tree: SceneTree) -> Node2D:
	var arena = (load("res://weapon_arena.gd") as GDScript).new()
	tree.root.add_child(arena)
	var old := tree.current_scene
	tree.current_scene = arena
	if old != null and is_instance_valid(old):
		# REMOVE FIRST, free after. queue_free() is deferred, and a scene that is
		# merely SCHEDULED to die still draws -- which is why a strip of village
		# terrain, trees and a second player kept appearing along the top of
		# every arena screenshot. remove_child takes it out of the tree on this
		# line, so it stops rendering immediately; queue_free then cleans up.
		tree.root.remove_child(old)
		old.queue_free()
	# and anything the old scene parented directly to the ROOT rather than to
	# itself outlives both of the above. In a rig that exists to give
	# comparable frames, one stray leftover is a wrong answer waiting to happen.
	for n in tree.root.get_children():
		if n == arena or n.name == "" or n is Window:
			continue
		# autoloads are root children too and must survive
		if ProjectSettings.has_setting("autoload/" + str(n.name)):
			continue
		tree.root.remove_child(n)
		n.queue_free()
	return arena
