extends Node
# EYES: THE BESTIARY (2026-07-29). A signature that asserts correctly but reads
# as nothing on screen has failed anyway -- the war cry has to LOOK like a shout,
# the heap has to look like bones, the gas has to look like gas. So every one of
# the six gets filmed.
#   MONARCH_TEST="res://tool_eyes_bestiary.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("EYES-BESTIARY: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0

	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	p.god_mode = true                  # the shoot must not end in a death screen
	var maxhp: int = p.get_max_health()
	# A signature filmed at midnight from the 0.6 world zoom is unjudgeable -- the
	# first pass came back as dark thumbnails. Force midday and lean the camera in
	# so a ring, a heap and a gas cloud are actually readable on film.
	# day_night_cycle re-derives time_of_day from the master clock inside its own
	# _process, so assigning it here was overwritten before the next frame drew --
	# every "midday" shoot still came back filmed at midnight. Drive the clock
	# instead: a run starts at START_TIME_OF_DAY (22:00), so +13h lands at 11:00.
	GameState.game_hours = 13.0
	var cam := p.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(1.6, 1.6)
	await _settle(1.0)

	# ---- 1. ORC: War Cry -- a pack that suddenly moves like a unit ----
	var pack := []
	for dx in [110.0, 170.0, 230.0, 290.0]:
		pack.append(_spawn(0, p.global_position + Vector2(dx, 0)))
	await _settle(0.6)
	pack[0].war_cry()
	await _settle(0.18)
	await _shot("s1_warcry")           # the ring sweeping out over the pack
	await _settle(0.5)
	await _shot("s2_warcry_rallied")   # sparks on everyone it reached
	_clear(pack)

	# ---- 2. BLOOD FIEND: Bloodscent -- it smells a wounded hero ----
	var fiend = _spawn(1, p.global_position + Vector2(150, 0))
	await _settle(0.6)
	p.health = int(maxhp * 0.3)
	await _settle(0.6)
	await _shot("s3_bloodscent")       # the red frenzy aura
	p.health = maxhp
	await _settle(0.5)
	_clear([fiend])

	# ---- 3. DEMON: Emberburst -- the corpse keeps burning ----
	var demon = _spawn(2, p.global_position + Vector2(130, 0))
	await _settle(0.6)
	demon.take_damage(999999)
	await _settle(0.35)
	await _shot("s4_ember_tell")       # the ring still swelling: the window to leave
	await _settle(1.0)
	await _shot("s5_ember_burn")       # burning
	await _settle(3.0)

	# ---- 4. WRAITH: Fade -- untouchable, and unable to strike ----
	var wraith = _spawn(3, p.global_position + Vector2(140, 0))
	await _settle(0.6)
	wraith.fade_out()
	await _settle(0.45)
	await _shot("s6_fade")             # near-transparent
	await _settle(1.2)
	_clear([wraith])

	# ---- 5. BONE GOLEM: Reassemble -- the heap, then the rise ----
	var golem = _spawn(4, p.global_position + Vector2(150, 0))
	await _settle(0.6)
	golem.take_damage(999999)
	await _settle(0.4)
	await _shot("s7_heap")             # a pile of bones where a tank stood
	await _settle(3.0)
	await _shot("s8_reassembled")      # back up at a third of its health
	_clear([golem])

	# ---- 6. ROTFIEND: Miasma -- it poisons the ground, not you ----
	var rot = _spawn(5, p.global_position + Vector2(90, 0))
	await _settle(0.6)
	rot.exhale_miasma()
	await _settle(0.3)
	rot.exhale_miasma()
	await _settle(0.4)
	await _shot("s9_miasma")           # gas lying where it walked
	_clear([rot])

	say("EYES-BESTIARY: done -> %s" % shot_dir)
	get_tree().quit(0)

# A real roster mob, staged the way a floor stages one (archetype before the
# tree), disarmed so its own sword never muddies the shot.
func _spawn(vis: int, at: Vector2) -> Node:
	var e = load("res://enemy.tscn").instantiate()
	e.respawns = false
	e.apply_mixed_archetype(0, vis)
	e.weapon_type = "sword"
	e.add_to_group("dungeon_combatant")
	get_tree().current_scene.add_child(e)
	e.global_position = at
	e.attack_cooldown_remaining = 999.0
	return e

func _clear(mobs: Array) -> void:
	for m in mobs:
		if is_instance_valid(m):
			m.queue_free()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-BESTIARY: shot %s" % name)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); found = true
		get_tree().paused = false
		await _settle(0.2)
		if not found and not get_tree().paused:
			return
