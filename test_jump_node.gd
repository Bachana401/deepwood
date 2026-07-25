extends Node

# What can the player ACTUALLY climb?
#
# Every arena is built out of ledges and (now) solid pillars, and in a
# side-scroller you cannot walk around a pillar -- if the player can't get over
# it, the room is a dead end and the floor is uncompletable. So this measures
# the real numbers rather than trusting JUMP_VELOCITY^2/2g on paper, and the
# arena suite builds against what it finds.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	var paper: float = (p.JUMP_VELOCITY * p.JUMP_VELOCITY) / (2.0 * p.GRAVITY)
	printerr("JUMP_VELOCITY=", p.JUMP_VELOCITY, "  GRAVITY=", p.GRAVITY)
	printerr("paper max rise = ", paper)
	printerr("has_double_jump=", p.has_double_jump)
	# sane physics constants: jump launches UP (negative y), gravity pulls DOWN
	check("jump velocity launches upward", p.JUMP_VELOCITY < 0.0, "%.0f" % p.JUMP_VELOCITY)
	check("gravity pulls down and paper rise is positive", p.GRAVITY > 0.0 and paper > 0.0, "paper %.1f" % paper)

	# land him first
	for i in range(240):
		await get_tree().physics_frame
		if p.is_on_floor():
			break
	printerr("grounded at y=", p.global_position.y, " on_floor=", p.is_on_floor())
	var floor_y: float = p.global_position.y

	# a single jump, driven the way the game drives it
	p.velocity.y = p.JUMP_VELOCITY
	var peak: float = floor_y
	for i in range(120):
		await get_tree().physics_frame
		peak = minf(peak, p.global_position.y)
		if p.is_on_floor() and i > 4:
			break
	var measured: float = floor_y - peak
	printerr("MEASURED single-jump rise = ", measured)
	check("the player can actually jump a real height", measured > 8.0, "%.1f px" % measured)
	check("measured rise is in the ballpark of the paper prediction (no broken jump)",
		measured > paper * 0.4 and measured < paper * 1.6, "measured %.1f vs paper %.1f" % [measured, paper])
	printerr("test_jump : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
