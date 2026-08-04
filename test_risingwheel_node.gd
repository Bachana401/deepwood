extends Node
# THE RISING WHEEL BITES EACH PASS (guard added 2026-08-04).
#
# wpn_risingwheel's card: "The wheel does not go out, it CLIMBS -- spinning
# upward in a widening turn, BITING EACH PASS, and carrying whatever it catches
# off the floor with it." test_weapondps_node declares "risingwheel: 3.0 -- ~7
# bites over its 2.1s climb if they stay under it".
#
# It bit ONCE. _tick_rising_wheel cleared hit_bodies every 0.28s so the wheel
# could "bite again", but body_entered fires exactly once, on ENTRY: a body
# already inside the area and staying there never re-triggers it, so emptying
# the list gave nothing to re-enter. Measured: 1 bite, against a declared ~7.
# The cure is _rake_overlapping(), which clears the list AND re-cuts whatever is
# still inside -- the same fix the file's own comment on the pierce family
# describes ("all three could touch a given body exactly once, so a piercing
# stream was worth one hit").
#
# THE FIXTURE HAS TO BE TALL. The wheel climbs 200px/s for 2.1s -- about 420px.
# A person-sized dummy is passed through in a few frames and would be bitten
# once or twice no matter what the code does, so this guard would pass on the
# broken build. A 240px body keeps it inside the wheel long enough for the
# re-bite cadence to be the thing under test.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _make_tall_foe(host: Node, pos: Vector2) -> Node2D:
	var d := StaticBody2D.new()
	var s := GDScript.new()
	s.source_code = """extends StaticBody2D
var hits := 0
var is_dead := false
func take_damage(a: int) -> bool:
	hits += 1
	return true
func apply_status(_k: String, _d: float, _m: float) -> void: pass
func apply_knockback(_s: float, _f: float) -> void: pass
"""
	s.reload()
	d.set_script(s)
	d.collision_layer = 4      # the enemy layer the wheel's area masks
	d.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(60, 240)
	cs.shape = sh
	d.add_child(cs)
	d.add_to_group("course_enemy")
	host.add_child(d)
	d.global_position = pos
	return d

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		keep_running()
		await get_tree().process_frame

	var host: Node = p.get_parent()
	p.god_mode = true
	# centred ABOVE the throw point, so the climbing wheel travels through it
	var foe := _make_tall_foe(host, p.global_position + Vector2(90.0, -120.0))

	var PROJ := load("res://weapon_projectile.gd")
	var wheel = PROJ.new()
	wheel.kind = "rising_wheel"
	wheel.damage = 10
	wheel.direction = Vector2.RIGHT
	wheel.speed = 200.0
	wheel.max_distance = 150.0
	wheel.spin_speed = 8.0
	wheel.source = p
	host.add_child(wheel)
	wheel.global_position = p.global_position + Vector2(90.0, 0.0)

	# the wheel's own life is 2.1s; give it that and a margin
	var t := 0.0
	while t < 2.6:
		keep_running()
		await get_tree().process_frame
		t += get_process_delta_time()

	check("the wheel connects at all", foe.hits >= 1, "hits=%d" % foe.hits)
	# ONE is the broken build. The declared model is ~7 over the climb; three is
	# a floor that a single entry-hit cannot reach however the frames land.
	check("IT BITES EACH PASS, not once (card: 'biting each pass')",
		foe.hits >= 3,
		"only %d bite(s) over the whole climb -- body_entered fires once, so clearing hit_bodies without re-raking gives exactly 1" % foe.hits)

	if is_instance_valid(foe):
		foe.queue_free()
	printerr("test_risingwheel : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
