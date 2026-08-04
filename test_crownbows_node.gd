extends Node
# THE TWO CROWN BOWS (guards added 2026-08-03, after tool_eyes_projectiles found
# both on its first run -- five audits and 119 green suites saw neither).
#
# 1. THE HOLLOW KING'S RAIN fired through the floor. Its arrows are launched at
#    the player's hands and then MOVED into the sky; the mover used to take
#    get_parent().get_children().back() on faith, so anything else parented in
#    the same breath stole the guess and the real shaft stayed in the player's
#    hands -- carrying a direction that points DOWN from the sky to the mark.
#    Guard: every shaft it makes must end up high above the AIM, never at the
#    player.
#
# 2. NIGHT PARADE's procession marched in blind. A marcher is a WeaponProjectile,
#    i.e. an Area2D whose _ready() turns monitoring on, and it is called in by a
#    landed arrow -- from inside a collision callback, mid physics-query flush,
#    where the engine REFUSES that change. The parade walked in unable to touch
#    anything. Guard: a marcher must come out of its spawn actually monitoring.
#
# Both are POSITION/STATE facts, so they are driven by calling the verb directly.
# (Judging how a weapon FEELS still needs the film -- see tool_eyes_projectiles.)

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

# A body the procession will actually walk to: course_enemy is one of
# WeaponProjectile.HOSTILE_GROUPS, which is what _nearest_hostile_node searches.
func _make_hostile(host: Node, pos: Vector2) -> Node2D:
	var d := Node2D.new()
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar hits := 0\nvar is_dead := false\nfunc take_damage(a: int) -> bool:\n\thits += a\n\treturn true\n"
	s.reload()
	d.set_script(s)
	d.add_to_group("course_enemy")
	host.add_child(d)
	d.global_position = pos
	return d

# children of `host` that were not there before, narrowed to one projectile kind
func _new_of_kind(host: Node, before: Array, kind: String) -> Array:
	var out := []
	for c in host.get_children():
		if before.has(c):
			continue
		if c.get("kind") == kind:
			out.append(c)
	return out

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
	# a DETERMINISTIC aim: aim_world_point() honours aim_override before it ever
	# reads the mouse, which headless does not have
	p.aim_override = Vector2.RIGHT
	var aim: Vector2 = p.aim_world_point()
	check("the aim point is out to the side, not on the player",
		aim.distance_to(p.global_position) > 100.0, str(aim))

	# ---------------- 1. THE HOLLOW KING'S RAIN ----------------
	p.inventory.add_item("wpn_hollowking", 1)
	check("the Hollow King's Rain can be wielded", p.wield_weapon("wpn_hollowking"))
	var before_rain := host.get_children().duplicate()
	p.call_the_kings_rain(p.active_def.get("special", {}))
	var shafts := _new_of_kind(host, before_rain, "javelin")
	check("the rain actually looses shafts", shafts.size() >= 1, "n=%d" % shafts.size())

	var at_the_hands := 0
	var below_the_aim := 0
	for s in shafts:
		var sp: Vector2 = (s as Node2D).global_position
		if sp.distance_to(p.global_position) < 120.0:
			at_the_hands += 1
		# "from above" -- the spawn sits a long way UP from the mark (smaller y)
		if sp.y > aim.y - 300.0:
			below_the_aim += 1
	check("no shaft is left in the player's hands (it would fire through the floor)",
		at_the_hands == 0, "%d of %d still at the player" % [at_the_hands, shafts.size()])
	check("every shaft falls FROM ABOVE the mark",
		below_the_aim == 0, "%d of %d not high above the aim" % [below_the_aim, shafts.size()])
	for s in shafts:
		if is_instance_valid(s):
			s.queue_free()
	await get_tree().process_frame

	# ---------------- 2. NIGHT PARADE ----------------
	p.inventory.add_item("wpn_nightparade", 1)
	check("Night Parade can be wielded", p.wield_weapon("wpn_nightparade"))
	# STAND SOMETHING FOR THEM TO MARCH AT. Without a hostile inside 900px,
	# _tick_marcher takes the prey == null branch, and because _build_marcher
	# starts a marcher at modulate.a = 0.0 that branch frees it on its FIRST
	# tick -- so the procession vanished before it could be counted. The first
	# version of this test relied on a village mob happening to wander into
	# range: it passed alone and failed under sweep load (2026-08-04). A guard
	# whose result depends on who is nearby is not a guard.
	var prey := _make_hostile(host, p.global_position + Vector2(260.0, 0.0))
	var before_march := host.get_children().duplicate()
	p.call_a_marcher(aim, 20, null)
	# The add is DEFERRED on purpose (that is the fix), so POLL for it rather
	# than guessing a frame count -- and keep_running() throughout, because a
	# story beat pausing the tree would otherwise stall the idle flush.
	var marchers := []
	for i in range(40):
		keep_running()
		await get_tree().process_frame
		marchers = _new_of_kind(host, before_march, "marcher")
		if marchers.size() >= p.MARCHERS_PER_ARROW:
			break
	check("a landed arrow calls the procession in",
		marchers.size() == p.MARCHERS_PER_ARROW,
		"got %d, expected %d" % [marchers.size(), p.MARCHERS_PER_ARROW])

	var blind := 0
	for m in marchers:
		if not bool(m.monitoring):
			blind += 1
	check("every marcher arrives able to SEE (monitoring survived the spawn)",
		blind == 0 and marchers.size() > 0,
		"%d of %d spawned blind" % [blind, marchers.size()])
	for m in marchers:
		if is_instance_valid(m):
			m.queue_free()
	if is_instance_valid(prey):
		prey.queue_free()

	# ...AND THE SPAWN MUST STAY DEFERRED. The check above cannot carry this on
	# its own and it is worth being honest about why: calling call_a_marcher
	# straight from a test runs it OUTSIDE the physics-query flush, where a plain
	# add_child works perfectly and monitoring comes up true. Negative-tested
	# 2026-08-03 -- put the bare add back and every runtime assertion above still
	# passed. The bug only bites on the REAL path, where the lantern calls the
	# procession from inside the physics step. So assert the shape of the code,
	# the way test_god_node pins its own invariant.
	var src := FileAccess.open("res://player.gd", FileAccess.READ)
	var ptxt := src.get_as_text() if src != null else ""
	if src != null:
		src.close()
	var marcher_fn := ptxt.substr(ptxt.find("func call_a_marcher"))
	marcher_fn = marcher_fn.substr(0, marcher_fn.find("\nfunc "))
	check("the marcher spawn is still DEFERRED (a bare add_child spawns it blind)",
		marcher_fn.contains("add_child.call_deferred(m)")
		and not marcher_fn.contains("get_parent().add_child(m)"),
		"call_a_marcher no longer defers its add_child")

	printerr("test_crownbows : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
