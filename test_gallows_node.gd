extends Node
# THE GALLOWS ACTUALLY HANGS THEM (guard added 2026-08-04).
#
# wpn_gallows' card draws its whole identity as a contrast with ordinary
# knockback: "It does not knock them back. It takes them UP, holds them there
# swinging, and then the floor comes back."
#
# None of that happened. _hang_them applied a 1.1s freeze and parented a rope
# graphic to the HOST at the victim's position -- no velocity write, no position
# write, no knockback anywhere. The enemy stood on the ground, frozen, while an
# unattached noose swung in the air above its head. And the drop that is meant
# to arrive AFTER the hold was spawned immediately, overlapping the victim, so
# it resolved on the next physics frame: the card's three beats collapsed into
# one. Worse, the drop's own payoff (_tick_late_thunder) ended in
# _nova_burst_TINTED, which draws a ring and pays nothing.
#
# THE FIXTURE FALLS. A dummy without gravity would pass this test without ever
# exercising the thing that makes the hang hard: enemy.gd adds gravity BEFORE
# its frozen gate ("frozen OR petrified: rooted, can't act (still falls with
# gravity)"), so a one-shot lift is a hop, not a hang. This foe accelerates
# downward and stands on real terrain, exactly as an enemy does.

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

# layer 4 so the head can hit it, mask 1 so it STANDS on the ground, and gravity
# in _physics_process so the hang is tested against a real fall
func _make_foe(host: Node, pos: Vector2) -> Node2D:
	var d := CharacterBody2D.new()
	var s := GDScript.new()
	s.source_code = """extends CharacterBody2D
var hits := 0
var taken := 0
var is_dead := false
func take_damage(a: int) -> bool:
	hits += 1
	taken += a
	return true
func apply_status(_k: String, _d: float, _m: float) -> void: pass
func apply_knockback(_s: float, _f: float) -> void: pass
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 900.0 * delta
	move_and_slide()
"""
	s.reload()
	d.set_script(s)
	d.collision_layer = 4
	d.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(40, 80)
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
	var foe := _make_foe(host, p.global_position + Vector2(150.0, -10.0))
	# let it settle onto the ground first, so "up" is measured from standing
	for i in range(40):
		keep_running()
		await get_tree().process_frame
	var y0: float = foe.global_position.y

	var PROJ := load("res://weapon_projectile.gd")
	var head = PROJ.new()
	head.kind = "gallows_head"
	head.damage = 100
	head.direction = Vector2.RIGHT
	head.speed = 900.0
	head.max_distance = 600.0
	head.source = p
	host.add_child(head)
	head.global_position = p.global_position + Vector2(40.0, 0.0)

	for i in range(90):
		keep_running()
		await get_tree().process_frame
		if foe.hits > 0:
			break
	check("the head connects", foe.hits >= 1, "hits=%d" % foe.hits)
	var after_hit: int = foe.taken

	# --- UP, and HELD there against gravity ---
	var peak: float = y0
	var t := 0.0
	while t < 0.55:
		keep_running()
		await get_tree().process_frame
		t += get_process_delta_time()
		peak = minf(peak, foe.global_position.y)
	check("IT TAKES THEM UP (the card's whole contrast with knockback)",
		y0 - peak > 20.0, "peak only %.1fpx above standing" % (y0 - peak))

	# --- ...and then the floor comes back ---
	t = 0.0
	while t < 2.0:
		keep_running()
		await get_tree().process_frame
		t += get_process_delta_time()
	check("...and the floor comes back (they end up standing again)",
		absf(foe.global_position.y - y0) < 16.0,
		"ended %.1fpx from standing" % (foe.global_position.y - y0))
	check("THE DROP LANDS (its payoff used to draw a ring and pay nothing)",
		foe.taken > after_hit,
		"took %d on the hit, %d total -- the drop paid %d"
			% [after_hit, foe.taken, foe.taken - after_hit])

	# --- THE DROP MUST SURVIVE THE VICTIM ---
	# This verb damages FIRST and hangs SECOND, so a head that kills outright is
	# the common case on trash. The swing tween is bound to the victim and dies
	# with it; the drop must not be. (Adversarial review, 2026-08-04: it WAS,
	# so a lethal hit silently deleted the entire second beat of the blow. The
	# first version of this test could not see it -- its foe never died.)
	# CLEAR THE LANE FIRST. The head does not pierce, so with the earlier foe
	# still standing at +150 it never reaches a target at +230 -- and that foe
	# SURVIVES, so its drop spawns and satisfies the check below for entirely
	# the wrong reason. (Caught by negative-testing this very assertion: with
	# the bug restored it still passed.) Also clear any thunder still in flight
	# from the first scenario, or a leftover would answer for the new one.
	if is_instance_valid(foe):
		foe.queue_free()
	for n in get_tree().get_nodes_in_group("player_projectile"):
		if is_instance_valid(n):
			n.queue_free()
	for i in range(20):
		keep_running()
		await get_tree().process_frame
	var doomed := _make_foe(host, p.global_position + Vector2(230.0, -10.0))
	for i in range(30):
		keep_running()
		await get_tree().process_frame
	var head2 = PROJ.new()
	head2.kind = "gallows_head"
	head2.damage = 100
	head2.direction = Vector2.RIGHT
	head2.speed = 900.0
	head2.max_distance = 700.0
	head2.source = p
	host.add_child(head2)
	head2.global_position = p.global_position + Vector2(40.0, 0.0)
	for i in range(120):
		keep_running()
		await get_tree().process_frame
		if doomed.hits > 0:
			break
	# they die to the head, exactly as trash does
	doomed.queue_free()
	var saw_drop := false
	var t2 := 0.0
	while t2 < 2.2:
		keep_running()
		await get_tree().process_frame
		t2 += get_process_delta_time()
		for n in get_tree().get_nodes_in_group("player_projectile"):
			if is_instance_valid(n) and n.get("kind") == "late_thunder":
				saw_drop = true
		if saw_drop:
			break
	check("the drop still falls when the head KILLS them (it is bound to the world, not the corpse)",
		saw_drop, "no late_thunder ever spawned after the victim was freed")

	# --- AND THE TIMED PAYOFF ITSELF ---
	# The check above does NOT cover it, and that is worth stating: the gallows
	# drop spawns ON the victim, so it resolves through the immediate contact
	# path and pays before _tick_late_thunder ever reaches HUSH_DELAY. Negative-
	# tested 2026-08-04 -- restoring the broken payoff left every assertion above
	# green. The timed half is what Novaburst's two echoes and Storm-Debt's
	# accruing beats rely on, because those are spawned AWAY from any body, so it
	# is tested the same way here: land a late_thunder at a distance and let the
	# clock run it out.
	var lone := _make_foe(host, p.global_position + Vector2(420.0, -10.0))
	for i in range(30):
		keep_running()
		await get_tree().process_frame
	var before_thunder: int = lone.taken
	var boom = PROJ.new()
	boom.kind = "late_thunder"
	boom.damage = 60
	boom.source = p
	host.add_child(boom)
	# offset so it does NOT overlap: the contact path must not be what pays
	boom.global_position = lone.global_position + Vector2(0.0, -70.0)
	var wait := 0.0
	while wait < 1.2:
		keep_running()
		await get_tree().process_frame
		wait += get_process_delta_time()
	check("the TIMED thunder pays when the clock runs out (not just on contact)",
		lone.taken > before_thunder,
		"took %d before and %d after the delay -- the timed payoff gave %d"
			% [before_thunder, lone.taken, lone.taken - before_thunder])
	if is_instance_valid(lone):
		lone.queue_free()

	if is_instance_valid(foe):
		foe.queue_free()
	printerr("test_gallows : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
