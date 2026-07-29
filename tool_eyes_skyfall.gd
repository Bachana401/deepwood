extends Node
# EYES: THE SKY-FALL FAMILY (2026-07-28, Star Wrath frame-study). The comet
# cascade seen with eyes: A Borrowed Star's gold stars mid-fall, the impact
# fountains, Throne of Strings' silver rain, and stormcall's spark burst.
# Drives WeaponFx directly at a dummy so the shots are deterministic.
#   MONARCH_TEST="res://tool_eyes_skyfall.gd" Godot.exe --path .  (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

class Dummy extends Node2D:
	var health := 99999
	var max_health := 99999
	var is_dead := false
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
		say("EYES-SF: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0
	GameState.game_hours = 22.5   # night: additive trails read best in the dark

	p.global_position = Vector2(6000.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	get_tree().current_scene.add_child(foe)
	foe.global_position = p.global_position + Vector2(150.0, -10.0)
	await _settle(1.0)

	# ---- f1/f2: A Borrowed Star -- the golden three-comet cascade ----
	p.inventory.add_item("wpn_borrowedstar", 1)
	p.wield_weapon("wpn_borrowedstar")
	WeaponFx.on_hit(p, foe, 30, false)
	await _settle(0.3)          # comets mid-fall
	await _shot("sf1_cascade_midfall")
	await _settle(0.45)         # impacts landing
	await _shot("sf2_impact_fountains")

	# ---- f3: Throne of Strings -- silver rain ----
	p.inventory.add_item("wpn_thronestrings", 1)
	p.wield_weapon("wpn_thronestrings")
	WeaponFx.on_hit(p, foe, 30, false)
	await _settle(0.25)
	await _shot("sf3_silver_strings")

	# ---- f4: stormcall rhythm bolt + spark fountain (Daybreak Edge) ----
	p.inventory.add_item("wpn_daybreakedge", 1)
	p.wield_weapon("wpn_daybreakedge")
	WeaponFx.on_swing(p)
	WeaponFx.on_swing(p)
	WeaponFx.on_swing(p)        # the 3rd swing is the rhythm hit
	WeaponFx.on_hit(p, foe, 30, false)
	await _settle(0.15)
	await _shot("sf4_stormcall_burst")

	say("EYES-SF: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-SF: shot %s" % name)

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
