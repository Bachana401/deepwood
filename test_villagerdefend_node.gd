extends Node
# "THEY SHOULD GO TO VILLAGE, AND ALSO DEFEND THEMSELVES" (dev 2026-07-21).
# A struck villager used to only run. Running is still the instinct -- these
# are farmers -- but a thing that catches them now gets hit for it.

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

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
	p.god_mode = true

	# This harness boots main.tscn directly (no new-game flow), so the roster and
	# its wandering avatars are empty. Seed a farmer and spawn their avatar in the
	# streets so there is a villager to test the run-and-defend behaviour on.
	var already_out := false
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and n.has_method("take_damage") and not n.is_in_building:
			already_out = true
			break
	if not already_out:
		GameState.rescued_villagers.append({
			"id": "test_defender", "name": "Fieldhand", "sex": "Male", "is_kid": false,
			"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""})
		var seeded = load("res://npc.gd").new()
		seeded.villager_id = "test_defender"
		get_tree().current_scene.add_child(seeded)
		seeded.global_position = p.global_position + Vector2(60.0, 0.0)
		for i in range(30):
			keep_running()
			await get_tree().process_frame

	var villager: Node = null
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and n.has_method("take_damage") and not n.is_in_building:
			villager = n
			break
	check("a villager is out and about to test", villager != null)
	if villager == null:
		printerr("RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return

	# a raider takes hold of them
	var raider = load("res://enemy.tscn").instantiate()
	raider.respawns = false
	get_tree().current_scene.add_child(raider)
	raider.add_to_group("course_enemy")
	await get_tree().process_frame
	# stand them well OUT from the village heart, so "running home" has somewhere
	# to run to and can actually be measured
	var span: Vector2 = villager._village_span()
	var haven: float = (span.x + span.y) * 0.5
	villager.global_position.x = haven - 700.0
	await get_tree().physics_frame
	raider.global_position = villager.global_position + Vector2(34.0, 0.0)
	var raider_hp0: int = raider.health
	var d_haven0: float = absf(villager.global_position.x - haven)

	villager.take_damage(3)
	check("a struck villager panics", villager.is_fleeing())

	var struck_back := false
	for i in range(240):
		keep_running()
		# the raider CHASES rather than being welded on: pinning it to their
		# exact spot every frame physically blocks the villager from moving at
		# all, which measures the fixture, not the villager
		if is_instance_valid(raider) and not raider.is_dead:
			var gap: float = villager.global_position.x - raider.global_position.x
			raider.global_position.x += clampf(gap, -6.0, 6.0)
			raider.global_position.y = villager.global_position.y
		await get_tree().physics_frame
		if is_instance_valid(raider) and raider.health < raider_hp0:
			struck_back = true
			break

	check("...and hits back at what has hold of them",
		is_instance_valid(raider) and raider.health < raider_hp0,
		"raider %d -> %d" % [raider_hp0, raider.health if is_instance_valid(raider) else -1])
	check("...but is still a farmer, not a soldier (a weak blow)",
		villager.DEFEND_DAMAGE <= 6, "%d damage" % villager.DEFEND_DAMAGE)
	check("...and only at arm's length", villager.DEFEND_RANGE <= 70.0,
		"%.0f range" % villager.DEFEND_RANGE)

	# fighting must not cancel the running: they still make for the village.
	# Measured over its OWN window -- the loop above stops the instant the blow
	# lands, which is barely a second of running and proves nothing either way.
	for i in range(150):
		keep_running()
		if is_instance_valid(raider) and not raider.is_dead:
			var gap2: float = villager.global_position.x - raider.global_position.x
			raider.global_position.x += clampf(gap2, -6.0, 6.0)
			raider.global_position.y = villager.global_position.y
		await get_tree().physics_frame
	var d_haven1: float = absf(villager.global_position.x - haven)
	check("...while still running for the village",
		d_haven1 < d_haven0 - 20.0,
		"%.0f -> %.0f from the village heart" % [d_haven0, d_haven1])

	# out of reach = no swinging at thin air
	if is_instance_valid(raider):
		raider.global_position = villager.global_position + Vector2(900.0, 0.0)
		var hp_far: int = raider.health
		villager.defend_cd = 0.0
		for i in range(90):
			keep_running()
			raider.global_position = villager.global_position + Vector2(900.0, 0.0)
			await get_tree().physics_frame
		check("a villager never swings at something across the field",
			raider.health == hp_far, "%d -> %d" % [hp_far, raider.health])
		raider.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
