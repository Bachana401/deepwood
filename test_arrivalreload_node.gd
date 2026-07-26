extends Node
# SOFTLOCK REGRESSION (2026-07-25): a CONTINUE that still owed the arrival used to
# re-stage the teaching wave but NEVER activate it. Staging turns on the shield
# (arrival_battle_active), which blocked _check_arrival_trigger from arming, so
# activate_arrival_combat never fired and the raiders stayed theatrical=true --
# INVINCIBLE forever ("their HP doesn't go down"). Fix: stage_arrival_battle arms
# the approach trigger itself. This verifies the reload path activates the wave.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return

	# a CONTINUE that still owes the arrival (prologue already seen, wave not yet won)
	GameState.reset_for_new_game()
	GameState.dev_mode = false
	GameState.seen_intro = true
	GameState.seen_arrival_battle = false
	GameState.seen_arrival_talk = false
	GameState.opening_done = false
	GameState.in_dungeon = false
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
	for i in range(240):
		await get_tree().process_frame
	var main := get_tree().current_scene

	var raiders := get_tree().get_nodes_in_group("siege_enemy")
	check("the arrival re-stages on a continue (raiders present)", raiders.size() >= 1, "%d" % raiders.size())
	var all_theatrical := raiders.size() > 0
	for r in raiders:
		if not ("theatrical" in r and r.theatrical):
			all_theatrical = false
	check("staged raiders start theatrical (shadow-fight, not yet killable)", all_theatrical)

	# walk to the wall so the approach trigger fires; dismiss the banter so the
	# activate callback runs (this is exactly the path that was dead on reload)
	var wall_x: float = main._west_wall_x() if main.has_method("_west_wall_x") else 5000.0
	p = get_tree().get_first_node_in_group("player")
	p.global_position.x = wall_x - 300.0
	var activated := false
	for i in range(180):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			p.global_position.x = wall_x - 300.0
		var box := get_tree().get_first_node_in_group("dialogue_box")
		if box != null and box.has_method("finish"):
			box.finish()
		raiders = get_tree().get_nodes_in_group("siege_enemy")
		var any_live := false
		var any_theatrical := false
		for r in raiders:
			if is_instance_valid(r) and not (("is_dead" in r) and r.is_dead):
				any_live = true
				if "theatrical" in r and r.theatrical:
					any_theatrical = true
		if any_live and not any_theatrical:
			activated = true
			break
	check("the reload path ACTIVATES the wave (raiders become killable)", activated)

	# and a real hit now lands -- the whole point of the bug report
	if activated:
		var target: Node = null
		for r in get_tree().get_nodes_in_group("siege_enemy"):
			if is_instance_valid(r) and not (("is_dead" in r) and r.is_dead):
				target = r; break
		if target != null and target.has_method("take_damage"):
			var h0: int = target.health
			target.take_damage(25)
			check("a raider's HP now goes DOWN (no more invincible wave-1)", target.health < h0,
				"%d -> %d" % [h0, target.health])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
