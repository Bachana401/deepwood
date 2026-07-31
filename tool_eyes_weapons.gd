extends Node

# EYES ON THE WEAPONS (dev, 2026-07-30: "i gave you so many good examples, but
# i still don't see any of them implemented the way i showed you").
#
# Every other instrument I built today counts. This one LOOKS. It stands a
# weapon in the Proving Ground, fires it, and photographs the result twice --
# once with the attack in flight, once a beat later when only the trail and the
# aftermath are left -- because the dev's complaint is not about numbers. It is
# that the Meowmere ribbon, the Starlight filaments and the Kaleidoscope chain
# were measured from his clips, written into the code, and never once looked at
# by anybody, me included.
#
# Two frames per weapon on purpose. The FLIGHT frame answers "is the projectile
# the right size and shape"; the AFTERMATH frame answers "does the trail
# outlive the thing that made it", which is the entire Meowmere law and cannot
# be seen in a frame where the projectile is still on screen.
#
# NOT headless: --headless has no renderer and every shot comes back null. Run
# it windowed. See run_eyes_weapons.ps1.
#
# Env:
#   EYES_DIR    where the pngs go (default user://eyes_weapons)
#   EYES_TIER   lowest tier to shoot (default 6 -- the tiers the dev is
#               complaining about; set 1 to photograph the whole roster)

var shot_dir := "user://eyes_weapons"
var min_tier := 6

func say(t: String) -> void: printerr(t)

class Mark extends StaticBody2D:
	var health := 999999999
	var max_health := 999999999
	var is_dead := false
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 64)
		cs.shape = sh
		add_child(cs)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-17, -32), Vector2(17, -32), Vector2(17, 32), Vector2(-17, 32)])
		body.color = Color(0.42, 0.34, 0.26, 1.0)
		add_child(body)
	func take_damage(_n: int): return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	var env_tier := OS.get_environment("EYES_TIER")
	if env_tier != "":
		min_tier = int(env_tier)
	DirAccess.make_dir_recursive_absolute(shot_dir)

	await get_tree().process_frame
	get_tree().paused = false
	var p: Node = null
	for i in range(1800):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("ABORTED: no player"); get_tree().quit(0); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	# three marks along the real aim, same placement law the sweep uses: a
	# target off the aim vector makes a healthy weapon look dead
	var aim: Vector2 = p.get_aim_direction()
	if aim.length() < 0.01:
		aim = Vector2.RIGHT
	for r in [70.0, 170.0, 290.0]:
		var m := Mark.new()
		m.add_to_group("course_enemy")
		stage.add_child(m)
		m.global_position = (p as Node2D).global_position + aim.normalized() * r

	var shot := 0
	for row in WeaponRoster.ROWS:
		if int(row[3]) < min_tier:
			continue
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			continue
		p.inventory.add_item(id, 1)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		p.health = p.get_max_health()
		for _f in range(4):
			await get_tree().process_frame
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		# IN FLIGHT: far enough in that the projectile has left the hand and is
		# at its full drawn size, early enough that it still exists
		await get_tree().create_timer(0.22, true).timeout
		_shot("T%d_%s_a_flight" % [int(row[3]), id])
		# AFTERMATH: the projectile is usually gone. What is left is the trail,
		# and whether anything is left AT ALL is the Meowmere law's whole test.
		await get_tree().create_timer(0.45, true).timeout
		_shot("T%d_%s_b_after" % [int(row[3]), id])
		shot += 1
		await get_tree().create_timer(0.25, true).timeout

	say("EYES: %d weapons, %d frames -> %s" % [shot, shot * 2, shot_dir])
	get_tree().quit(0)

func _shot(name: String) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		say("null img %s  (are you running WINDOWED? --headless cannot draw)" % name)
		return
	img.save_png(shot_dir.path_join(name + ".png"))
