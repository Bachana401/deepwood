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
	# ON A CANVASLAYER, not in the world -- and this is the answer to the
	# "leftover village strip" that survived three wrong diagnoses.
	#
	# Dumping the tree AT THE MOMENT OF CAPTURE showed no village at all: just
	# GameState, DragState, TouchControls, the driver and this arena. The strip
	# was never in the scene. It was STALE FRAMEBUFFER -- a world-space
	# ColorRect follows world coordinates, so the top of the viewport was simply
	# never overdrawn, and those pixels still held whatever the village had left
	# there before the swap. It never changed between weapons while the arena
	# band below it updated every shot, which was the clue I kept ignoring.
	#
	# A CanvasLayer backdrop is in SCREEN space and covers the viewport whatever
	# the camera does, so every pixel of every frame is drawn by this scene.
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	# SIZED EXPLICITLY, not by anchors: a ColorRect parented straight to a
	# CanvasLayer has no Control above it to anchor against, so anchor_right=1.0
	# resolves to nothing and the rect covers zero pixels. That is why the first
	# CanvasLayer attempt changed nothing at all.
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.11, 0.20, 1.0)
	var vp: Vector2 = Vector2(1920, 1080)
	if is_inside_tree() and get_viewport() != null:
		vp = get_viewport().get_visible_rect().size
	sky.position = Vector2(-80, -80)
	sky.size = vp + Vector2(160, 160)
	layer.add_child(sky)

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
#
# `keep` is the CALLING TOOL and must be passed. main_menu.gd parents the test
# driver to the ROOT so it survives the scene change (main_menu.gd:55), which
# means the root sweep below will happily delete the very script asking for the
# arena. It did exactly that: the first run after I added the sweep produced
# zero frames because the walker freed itself on its second line.
static func take_over(tree: SceneTree, keep: Node = null) -> Node2D:
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
	# WHAT IS ACTUALLY THERE. I have now guessed twice at what draws the leftover
	# village strip -- a deferred free, then a stray CanvasLayer -- and been
	# wrong twice. Printing the tree ends the guessing in one run, and costs
	# nothing in a rig that only ever runs under a test harness.
	if OS.has_environment("ARENA_DUMP"):
		printerr("\n=== ROOT CHILDREN AT TAKEOVER ===")
		for n in tree.root.get_children():
			printerr("  %-28s %-22s vis=%s" % [n.name, n.get_class(),
				str(n.visible) if n is CanvasItem else "-"])
			for c in n.get_children():
				printerr("      %-24s %-22s" % [c.name, c.get_class()])
		printerr("=== current_scene: %s ===\n" % (
			"null" if tree.current_scene == null else tree.current_scene.name))
	# THE ROOT SWEEP IS GONE, and the reason is the answer to the whole hunt.
	#
	# The leftover "village strip" is not a stray node I failed to kill. It is
	# main.tscn, and THE PLAYER CANNOT LIVE WITHOUT IT:
	#
	#   player.gd:2705  $"../CanvasLayer/HealthBarFill".size.x = ...
	#
	# The player reaches OUT of itself, by path, into its parent scene's HUD --
	# health bar, labels, hotbar. update_health_display runs from _ready via
	# wield_weapon, so a player instanced anywhere that is not main.tscn errors
	# on its first frame. Dumping the tree turned a cosmetic puzzle into a
	# structural fact in one run, after I had guessed wrong twice.
	#
	# So the arena can never be a truly standalone scene while the player is
	# coupled to main's UI. Killing main to tidy up a screenshot would break the
	# very puppet the arena exists to hold. The strip stays until the player's
	# HUD access is decoupled -- and that is a real refactor of player.gd, not a
	# tweak to a test rig, so it is the dev's call rather than a thing to
	# quietly attempt at the end of a session.
	# ...and what SURVIVED it, which is the half that actually matters
	if OS.has_environment("ARENA_DUMP"):
		printerr("=== ROOT CHILDREN AFTER THE SWEEP ===")
		for n2 in tree.root.get_children():
			printerr("  %-28s %-22s" % [n2.name, n2.get_class()])
		printerr("=====================================\n")
	return arena
