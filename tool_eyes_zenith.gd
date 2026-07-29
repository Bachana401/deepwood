extends Node
# EYES: THE MELEE CROWN (2026-07-28). The Last Word's zenith ghost-blade in
# all three phases (swoop / whirl / return) and Edge of the World's emerald
# Terra beam, over a dummy row. Projectiles are launched through the player's
# own launch_projectile with the roster's real special dicts.
#   MONARCH_TEST="res://tool_eyes_zenith.gd" Godot.exe --path .  (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

# a REAL body on the enemy layer (4): projectiles find targets by physics
# overlap, so a plain Node2D dummy would be invisible to them
class Dummy extends StaticBody2D:
	var health := 99999
	var max_health := 99999
	var is_dead := false
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 60)
		cs.shape = sh
		add_child(cs)
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

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
		say("EYES-Z: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0

	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	var scene = get_tree().current_scene
	for dx in [140.0, 210.0, 280.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 20.0)
	await _settle(1.0)

	# ---- z1-z3: THE LAST WORD -- the ghost-blade's three phases ----
	p.inventory.add_item("wpn_lastword", 1)
	p.wield_weapon("wpn_lastword")
	var zs: Dictionary = p.active_def.get("special", {})
	p.launch_projectile(zs, Vector2.RIGHT, int(zs.get("damage", 40)))
	await _settle(0.13)
	await _shot("z1_zenith_swoop")
	await _settle(0.16)
	await _shot("z2_zenith_whirl")
	await _settle(0.22)
	await _shot("z3_zenith_return")
	# a second swing to see the tint CYCLE
	p.launch_projectile(zs, Vector2.RIGHT, int(zs.get("damage", 40)))
	await _settle(0.3)
	await _shot("z4_zenith_second_tint")
	await _settle(0.8)

	# ---- z5: EDGE OF THE WORLD -- the emerald Terra beam ----
	p.inventory.add_item("wpn_worldsedge", 1)
	p.wield_weapon("wpn_worldsedge")
	var cs: Dictionary = p.active_def.get("special", {})
	p.launch_projectile(cs, Vector2.RIGHT, int(cs.get("damage", 30)))
	await _settle(0.25)
	await _shot("z5_terra_beam")

	say("EYES-Z: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-Z: shot %s" % name)

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
