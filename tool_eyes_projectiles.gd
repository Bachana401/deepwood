extends Node
# EYES: THE PROJECTILE LAW (2026-07-29). The Crown Ten session shipped #6-#10 as
# "[EYES PENDING]" and said plainly it expected faults only film would find. This
# walker settles that debt, and judges every shot against the GIF-measured law in
# WEAPON_VERB_REFERENCE.md rather than against taste:
#   * projectile HEAD = 0.3-1.0 player heights  (player is 48px, so 14-48px)
#   * TRAIL = 4-9 player heights (190-430px), tapering, additive, hot->dim
#   * impact = a burst/fountain, not a silent stop
#   * crown fx pay FULL price per projectile; spectacle scales with tier
# Filmed at the REAL world zoom (0.6) -- judging a projectile zoomed in is how a
# 4px dot passes review and then reads as nothing in the actual game.
#   MONARCH_TEST="res://tool_eyes_projectiles.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

# A real body on the enemy layer (4): projectiles find targets by physics
# overlap, so a plain Node2D is invisible to them (the crown walker's lesson).
class Dummy extends StaticBody2D:
	var health := 999999
	var max_health := 999999
	var is_dead := false
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 60)
		cs.shape = sh
		add_child(cs)
		var body := ColorRect.new()      # so a shot shows WHAT was hit
		body.size = Vector2(30, 60)
		body.position = Vector2(-15, -30)
		body.color = Color(0.5, 0.2, 0.22, 0.85)
		add_child(body)
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

var player: Node = null

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	for i in range(1200):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player != null:
			break
	if player == null:
		say("EYES-PROJ: no player"); get_tree().quit(1); return
	var p := player
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0
	# midday: these are judgements about SHAPE and scale, and the village night
	# modulate flattens every colour into the same navy (bestiary walker lesson)
	# Setting day_night_cycle.time_of_day does NOTHING: its _process re-derives
	# that field from the master clock every frame. The clock is GameState.
	# game_hours, and a run starts at START_TIME_OF_DAY (22:00) -- so +13h = 11:00.
	GameState.game_hours = 13.0
	p.god_mode = true
	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(0.8)

	_stand_targets([170.0, 260.0, 350.0, 460.0])
	await _settle(0.4)

	# ---- CONTROL: a COMMON bow, filmed first, same frame and same zoom ----
	# "crown fx pay FULL price per projectile; spectacle scales with tier" is not
	# checkable against nothing -- with only tier-8 takes on the reel every one of
	# them looks expensive. This is the floor to measure that claim from.
	await _film("wpn_huntingbow", "p0_control", [0.2, 0.5, 0.9], 1.0)

	# ---- #6 THE CROWN'S SORROW: a POUR of narrow lances (identity = rate) ----
	await _film("wpn_crownsorrow", "p1_sorrow", [0.25, 0.7, 1.3], 1.5)

	# ---- #7 GRIEF WEARS A CROWN: the blow runs out THROUGH the ground ----
	await _film("wpn_griefcrown", "p2_sunder", [0.12, 0.3, 0.55], 0.9)

	# ---- #8 THE HOLLOW KING'S RAIN: nothing leaves the bow; it falls ----
	await _film("wpn_hollowking", "p3_hollowking", [0.18, 0.45, 0.9], 1.2)

	# ---- #9 NIGHT PARADE: every landed arrow calls one of the procession ----
	await _film("wpn_nightparade", "p4_parade", [0.3, 0.9, 1.6], 2.0)

	# ---- #10 THE MOUNTAIN THAT KNEELS: a boulder that gathers pace ----
	await _film("wpn_mountainking", "p5_boulder", [0.25, 0.6, 1.1], 1.4)

	say("EYES-PROJ: done -> %s" % shot_dir)
	get_tree().quit(0)

# Wield it and press the REAL attack action with the cursor on a target -- the
# crown session's own hard-won rule: driving a weapon by calling its function
# bypasses the player's per-frame loop and films a lie.
func _film(item_id: String, tag: String, at: Array, hold: float) -> void:
	await _clear_the_field()
	var p := player
	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	p.inventory.add_item(item_id, 1)
	if not p.wield_weapon(item_id):
		say("EYES-PROJ: could not wield %s" % item_id)
		return
	p.mana = p.get_max_mana()
	if "health" in p: p.health = p.get_max_health()
	var aim_world: Vector2 = p.global_position + Vector2(300.0, 12.0)
	Input.warp_mouse(get_viewport().get_canvas_transform() * aim_world)
	await get_tree().process_frame
	Input.action_press("attack")
	var last := 0.0
	for i in range(at.size()):
		await _settle(maxf(0.02, float(at[i]) - last))
		last = float(at[i])
		await _shot("%s_%d" % [tag, i + 1])
	Input.action_release("attack")
	await _settle(hold)
	await _shot("%s_after" % tag)
	await _settle(0.5)

# EVERY TAKE STARTS ON AN EMPTY FIELD (2026-08-04). Night Parade's procession
# walks in from 700px off-camera and comfortably outlives its own take: the
# marchers were still crossing frame during THE MOUNTAIN THAT KNEELS, and a
# reviewer cannot tell a boulder's trail from a column of lanterns. Weapon #10's
# film was unjudgeable for that reason alone -- the harness, not the weapon.
# Both projectile scripts join "player_projectile", so one sweep clears shafts,
# lanterns and marchers alike.
func _clear_the_field() -> void:
	for n in get_tree().get_nodes_in_group("player_projectile"):
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _stand_targets(offsets: Array) -> void:
	var scene := get_tree().current_scene
	for dx in offsets:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		# STAND them on the floor, do not bury them (dev, watching the film
		# 2026-08-04). At +20 the body -- a 30x60 rect drawn from -30 to +30 --
		# had its bottom third under the ground line, which both looked wrong and
		# spoiled the only in-frame SCALE BAR the reviewer has: a target of known
		# height is how world px get measured off a screenshot, and a partly
		# buried one measures short.
		foe.global_position = player.global_position + Vector2(float(dx), 0.0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-PROJ: shot %s" % name)

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
