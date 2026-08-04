extends Node
# THE DIRE PORTENT'S HOUR ACTUALLY LANDS (guard added 2026-08-04).
#
# wpn_direseeker's card reads: "The shaft does not kill. It FIXES an omen over
# them, and the sign sinks lower and shakes harder until the hour comes -- and
# then it falls." It deliberately withholds damage on impact -- 0.35x -- and
# stakes the whole weapon on the deferred payoff.
#
# That payoff paid NOTHING. _tick_portent called _nova_burst_TINTED, which draws
# the ring and has no damage loop at all, while its damaging twin _nova_burst
# sits five hundred lines away and was never called from this path. A Tier-6 bow
# with 24 base damage delivered an 8-damage prick and a purple particle.
#
# Nothing caught it: the two helpers are one identifier apart, no audit reads
# intent, and test_weapondps_node's table DECLARES "direportent: 1.6 -- a 0.35x
# prick, then the omen falls for a 0.8x nova" without ever measuring it, so the
# balance model was scoring damage that did not exist.
#
# This measures the fall.

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

# A REAL BODY ON THE ENEMY LAYER (4). The shaft's prick is a physics overlap, so
# a plain Node2D is invisible to it -- the projectile sails straight through.
# (The nova half searches HOSTILE_GROUPS instead, so it needs the group too.)
func _make_hostile(host: Node, pos: Vector2) -> Node2D:
	var d := StaticBody2D.new()
	var s := GDScript.new()
	s.source_code = "extends StaticBody2D\nvar hits := 0\nvar taken := 0\nvar is_dead := false\nfunc take_damage(a: int) -> bool:\n\thits += 1\n\ttaken += a\n\treturn true\nfunc apply_status(_k: String, _d: float, _m: float) -> void: pass\nfunc apply_knockback(_s: float, _f: float) -> void: pass\n"
	s.reload()
	d.set_script(s)
	d.collision_layer = 4
	d.collision_mask = 0
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
	var prey := _make_hostile(host, p.global_position + Vector2(150.0, 0.0))

	# drive the verb the way the game does: the projectile carries it
	var PROJ := load("res://weapon_projectile.gd")
	var shaft = PROJ.new()
	shaft.kind = "portent"
	shaft.damage = 100                     # round numbers make the split readable
	shaft.direction = Vector2.RIGHT
	shaft.speed = 900.0
	shaft.max_distance = 600.0
	shaft.source = p
	host.add_child(shaft)
	shaft.global_position = p.global_position + Vector2(40.0, 0.0)

	# the shaft flies, pricks, and fixes the omen
	for i in range(90):
		keep_running()
		await get_tree().process_frame
		if prey.hits > 0:
			break
	check("the shaft lands its prick", prey.hits >= 1, "hits=%d" % prey.hits)
	var after_prick: int = prey.taken
	check("...and the prick is only a FRACTION, as the card says (does not kill)",
		after_prick > 0 and after_prick < 60, "took %d of 100" % after_prick)

	# THE HOUR. PORT_WARN is 1.4s; wait past it with room to spare.
	var t := 0.0
	while t < 2.6:
		keep_running()
		await get_tree().process_frame
		t += get_process_delta_time()

	check("THE OMEN FALLS AND IT LANDS (the fall used to deal nothing)",
		prey.taken > after_prick,
		"took %d before the hour and %d after -- the fall paid %d"
			% [after_prick, prey.taken, prey.taken - after_prick])
	check("...and the fall is the BIGGER half, which is the whole bargain",
		prey.taken - after_prick > after_prick,
		"prick %d vs fall %d" % [after_prick, prey.taken - after_prick])

	if is_instance_valid(prey):
		prey.queue_free()
	printerr("test_portent : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
