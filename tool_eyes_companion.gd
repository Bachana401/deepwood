extends Node
# EYES: COMPANIONS (light summoner 2026-07-29). Each carrier summons its
# companion over a dummy row: the brother-blade darts, the watch-candle lobs
# a mote, the shade-hound pounces, the Standing Star guards from the relic
# slot -- and putting everything away leaves the field EMPTY (absence shot).
#   MONARCH_TEST="res://tool_eyes_companion.gd" Godot.exe --path .  (no --headless!)

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

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
		say("EYES-C: no player"); get_tree().quit(1); return
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
	for dx in [150.0, 230.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		scene.add_child(foe)
		foe.global_position = p.global_position + Vector2(dx, 20.0)
	await _settle(1.0)

	# ---- c1: the BROTHER-BLADE (A Long Night's Tongue) ----
	p.inventory.add_item("wpn_nightlash", 1)
	p.wield_weapon("wpn_nightlash")
	await _settle(1.2)
	await _shot("c1_brother_blade")

	# ---- c2: the WATCH-CANDLE (Shatterhymn) ----
	p.inventory.add_item("wpn_shatterhymn", 1)
	p.wield_weapon("wpn_shatterhymn")
	await _settle(1.4)
	await _shot("c2_watch_candle")

	# ---- c3: the SHADE-HOUND (Dire Portent) ----
	p.inventory.add_item("wpn_direseeker", 1)
	p.wield_weapon("wpn_direseeker")
	await _settle(1.2)
	await _shot("c3_shade_hound")

	# ---- c4: the STANDING STAR from the relic slot, stacked with the hound ----
	p.inventory.add_item("relic_guardian", 1)
	GameState.equip_item("relic_guardian", p)
	await _settle(1.2)
	await _shot("c4_standing_star")

	# ---- c5: everything away -- the field must be EMPTY of companions ----
	p.inventory.add_item("wpn_hearthpoker", 1)
	p.wield_weapon("wpn_hearthpoker")
	var ridx := -1
	for i in range(GameState.relic_slot_count()):
		if GameState.equipment.relics[i] == "relic_guardian":
			ridx = i
	if ridx >= 0:
		GameState.unequip_slot("relic", p, ridx)
	await _settle(1.0)
	await _shot("c5_all_bowed_out")

	say("EYES-C: done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-C: shot %s" % name)

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
