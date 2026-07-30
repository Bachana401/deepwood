extends Node
# EYES: TIER 6 (weapon overhaul, 2026-07-29).
# One walker per tier -- see the note at the top of tool_eyes_t7.gd for why.
#   MONARCH_TEST="res://tool_eyes_t6.gd" Godot.exe --path .   (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

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
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

var _home := Vector2(6000.0, -80.0)

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
		say("EYES-T6: no player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true
	await _clear_dialog()
	GameState.hours_until_next_siege = 999.0
	GameState.hours_until_caravan = 999.0

	p.global_position = _home
	if "velocity" in p: p.velocity = Vector2.ZERO
	var scene = get_tree().current_scene
	for dx in [150.0, 240.0, 330.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 20.0)
	await _settle(0.8)

	# id, shot name, settle before the shot, swings
	for spec in [
			["wpn_hushfall",     "a1_hush_held",   0.30, 1],   # ring contracting
			["wpn_hushfall",     "a2_hush_thunder", 0.66, 1],  # the sound lands
			["wpn_eclipsewheel", "b1_eclipse_out", 0.20, 1],
			["wpn_eclipsewheel", "b2_eclipse_dark", 0.50, 1],  # dark + shadow band
			["wpn_cometfall",    "c1_comet_up",    0.30, 1],
			["wpn_cometfall",    "c2_comet_crater", 1.30, 1],  # crater + burning
			["wpn_debtcollector", "d1_debt_booked", 0.70, 1],
			["wpn_debtcollector", "d2_debt_biting", 1.60, 1],
			["wpn_cinderchain",  "e1_cinder_drag", 0.55, 1],
			["wpn_watchfire",    "f1_watch_armed", 0.30, 1],   # planted, waiting
			["wpn_watchfire",    "f2_watch_flare", 0.55, 1],
			["wpn_dawntongue",   "g1_longtongue",  0.22, 1],
			["wpn_kindlyend",    "h1_pike_staged", 0.30, 1],
			["wpn_lodestar",     "i1_lode_planted", 0.90, 1],
			["wpn_lodestar",     "i2_lode_burst",  3.30, 1],
			["wpn_deluge",       "j1_flood_run",   0.75, 1],
			["wpn_shatterhymn",  "k1_note_shatter", 0.55, 1],
			["wpn_secondmoon",   "l1_moon_full",   0.70, 1],
			["wpn_secondmoon",   "l2_moon_waning", 2.10, 1],
			["wpn_worldanvil",   "m1_toll_first",  0.12, 1],
			["wpn_worldanvil",   "m2_toll_third",  0.70, 1],
			["wpn_horizonrender", "n1_rend_apart", 0.30, 1],
			["wpn_silentchoir",  "o1_choir_sings", 0.30, 5],
			["wpn_sunmortar",    "p1_sun_hung",    1.30, 1],
			["wpn_permafrost",   "q1_ice_spread",  2.60, 1],
			["wpn_novaburst",    "r1_nova_beats",  0.60, 1]]:  # it caught someone
		p.global_position = _home
		if "velocity" in p: p.velocity = Vector2.ZERO
		p.inventory.add_item(spec[0], 1)
		p.wield_weapon(spec[0])
		p.mana = p.get_max_mana()
		await _aim_right(p)
		for s in range(int(spec[3])):
			p.attack_cooldown_remaining = 0.0
			p.perform_attack()
			if int(spec[3]) > 1:
				await _settle(0.13)
		await _settle(float(spec[2]))
		await _shot(str(spec[1]))
		await _settle(0.35)

	say("EYES-T6: done")
	get_tree().quit(0)

# perform_attack aims at the CURSOR; a walker has none, so every swing-driven
# weapon fires LEFT and lands off-frame unless the pointer is parked first.
func _aim_right(p: Node) -> void:
	var at: Vector2 = (p as Node2D).global_position + Vector2(240.0, 10.0)
	Input.warp_mouse(get_viewport().get_canvas_transform() * at)
	await get_tree().process_frame
	await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-T6: shot %s" % name)

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
