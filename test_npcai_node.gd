extends Node
# ALIVE, NOT ALIKE (dev 2026-07-23): villagers get a stable per-id TEMPERAMENT
# (stride/idle/favourite-end) and FLEE ON SIGHT of a close enemy (not only when
# struck); warriors walk their watch to a PERSONAL rhythm (span/speed/pauses) and
# wall guards hold the rampart -- they engage what reaches the wall or what has
# BREACHED into the village, and never sprint across town (the city line does that).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	get_tree().paused = false

	# ---- villager temperament: stable, varied, in range ----
	var NPC = load("res://npc.gd")
	var a = NPC.new(); a.villager_id = "vid_alpha"
	var b = NPC.new(); b.villager_id = "vid_beta"
	add_child(a); add_child(b)
	await get_tree().process_frame
	check("temperaments are in their designed ranges",
		a.temper_speed >= 0.85 and a.temper_speed <= 1.2 \
		and a.temper_idle >= 0.7 and a.temper_idle <= 1.6 \
		and absf(a.temper_wander_bias) <= 60.0,
		"spd=%.2f idle=%.2f bias=%.0f" % [a.temper_speed, a.temper_idle, a.temper_wander_bias])
	check("different villagers differ (not lookalike)",
		a.temper_speed != b.temper_speed or a.temper_idle != b.temper_idle \
		or a.temper_wander_bias != b.temper_wander_bias)
	var speed_before: float = a.temper_speed
	a._roll_temperament()
	check("temperament is STABLE for the same id (survives re-roll/reload)",
		a.temper_speed == speed_before)

	# ---- villager flees ON SIGHT of a close enemy ----
	var SE = load("res://siege_enemy.gd")
	var raider = SE.new()
	add_child(raider)
	raider.global_position = a.global_position + Vector2(120, 0)   # inside SIGHT_FLEE_RANGE
	a._sight_check_cd = 0.0
	a._tick_flee_on_sight(1.0)
	check("a villager who SEES a close enemy starts fleeing (not only when struck)",
		a.is_fleeing())
	# ...but a theatrical (staged) raider scares nobody
	b.global_position = Vector2(-4000, 0)                          # far from the live raider
	var stage_r = SE.new(); stage_r.theatrical = true
	add_child(stage_r)
	stage_r.global_position = b.global_position + Vector2(90, 0)
	b._sight_check_cd = 0.0
	b._tick_flee_on_sight(1.0)
	check("a theatrical/staged raider does NOT trigger the flee", not b.is_fleeing())

	# ---- warrior watch rhythm: personal + varied ----
	var ADV = load("res://adventurer.gd")
	var w1 = ADV.new(); w1.adventurer_id = "adv_roland"
	var w2 = ADV.new(); w2.adventurer_id = "adv_wren"
	add_child(w1); add_child(w2)
	await get_tree().process_frame
	check("watch rhythm is in its designed ranges",
		w1._patrol_span >= 70.0 and w1._patrol_span <= 140.0 \
		and w1._patrol_speed >= 20.0 and w1._patrol_speed <= 36.0 \
		and w1._pause_every >= 2.5 and w1._pause_every <= 6.5 \
		and w1._pause_len >= 0.8 and w1._pause_len <= 3.0,
		"span=%.0f spd=%.0f every=%.1f len=%.1f" % [w1._patrol_span, w1._patrol_speed, w1._pause_every, w1._pause_len])
	check("two warriors keep DIFFERENT watches (no drill row)",
		w1._patrol_span != w2._patrol_span or w1._patrol_speed != w2._patrol_speed \
		or w1._pause_every != w2._pause_every)

	# ---- wall guard: holds the wall; chases only the breached ----
	# clear the STAGED arrival tableau first -- its theatrical raiders sit right in
	# this synthetic post's hold radius, and (by design) adventurers DO engage them
	# (the trio trades blows with the tableau; see main.stage_arrival_battle)
	for r0 in get_tree().get_nodes_in_group("siege_enemy"):
		if is_instance_valid(r0) and r0 != raider and r0 != stage_r and "theatrical" in r0 and r0.theatrical:
			r0.queue_free()
	stage_r.queue_free()
	await get_tree().process_frame
	var WALL = load("res://wall.tscn")
	var wall = WALL.instantiate()
	wall.flank = "west"
	wall.position = Vector2(4700.0, -39.0)
	get_tree().current_scene.add_child(wall)
	await get_tree().process_frame
	w1.station = "wall"
	w1.home_x = 4540.0                     # the wall post (anchored just off the rampart)
	w1.global_position = Vector2(4540.0, -60.0)
	# raider far OUT past the wall, on the road: NOT this guard's fight
	raider.global_position = Vector2(3600.0, -60.0)
	check("a raider still out on the road is NOT chased by the wall guard",
		w1._nearest_raider() == null)
	# raider AT the wall: fought
	raider.global_position = Vector2(4450.0, -60.0)
	check("a raider that reaches the wall IS fought", w1._nearest_raider() == raider)
	# raider BREACHED into the village: chased even though it's past the hold radius
	raider.global_position = Vector2(5400.0, -60.0)
	check("a raider that breached INTO the village is chased", w1._nearest_raider() == raider)
	# the same deep breacher is the CITY guard's job too, from anywhere in town
	w2.station = "city"
	w2.home_x = 7000.0
	w2.global_position = Vector2(7800.0, -60.0)
	check("the city line crosses town for a breacher", w2._nearest_raider() == raider)

	for n in [a, b, raider, stage_r, w1, w2, wall]:
		if is_instance_valid(n): n.queue_free()
	await get_tree().process_frame
	printerr("test_npcai : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
