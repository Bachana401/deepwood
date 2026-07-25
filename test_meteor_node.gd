extends Node
# ORIN'S METEOR (fix 2026-07-24): a meteor takes METEOR_FALL_TIME to land. If Orin
# is freed in that window, its deferred tween callback used a STALE self and
# errored -- "Nonexistent function 'apply_meteor_impact' in base ... npc.gd" (his
# freed object slot reused by a villager npc). This locks it: a live mage's meteor
# still damages hostiles, and a freed mage's in-flight meteor fizzles + cleans up.

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

func _make_dummy(host: Node, pos: Vector2) -> Node2D:
	var d := Node2D.new()
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar hits := 0\nvar is_dead := false\nfunc take_damage(a: int) -> void:\n\thits += a\n"
	s.reload()
	d.set_script(s)
	d.add_to_group("siege_enemy")   # one of wizard.gd HOSTILE_GROUPS
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

	var host := get_tree().current_scene
	var base: Vector2 = p.global_position
	# Orin removes himself in _ready until he has "arrived" (deep enough run) --
	# satisfy that so the test mage stays.
	GameState.highest_unlocked_level = maxi(GameState.highest_unlocked_level, 99)
	var orin = load("res://wizard.gd").new()
	host.add_child(orin)
	orin.global_position = base
	for i in range(10):
		await get_tree().process_frame
	check("the test mage stands (arrived)", is_instance_valid(orin))
	if not is_instance_valid(orin):
		printerr("test_meteor : RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return

	# a hostile well BEYOND his auto-cast range, so only our manual casts reach it
	var dummy := _make_dummy(host, Vector2(base.x + 700.0, base.y))

	# ---- a LIVE mage's meteor lands and damages the hostile ----
	orin.cast_meteor_at(dummy.global_position)
	await get_tree().create_timer(0.85).timeout   # past METEOR_FALL_TIME (0.5s)
	check("a live mage's meteor damages the hostile", dummy.hits > 0, "hits=%d" % dummy.hits)

	# ---- a FREED mage's in-flight meteor must fizzle + clean up, not error ----
	dummy.hits = 0
	var m2 = orin.cast_meteor_at(dummy.global_position)
	orin.queue_free()                              # kill the caster mid-flight
	await get_tree().process_frame
	await get_tree().create_timer(0.85).timeout
	check("a freed mage's in-flight meteor cleans up (no stale-self crash)",
		not is_instance_valid(m2))
	check("...and it dealt no damage, the caster being gone", dummy.hits == 0, "hits=%d" % dummy.hits)

	if is_instance_valid(dummy):
		dummy.queue_free()
	printerr("test_meteor : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
