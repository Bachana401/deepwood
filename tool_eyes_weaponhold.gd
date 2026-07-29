extends Node
# Held-weapon calibration shot. Robust capture: force a synchronous draw
# (works even if the window isn't focused) instead of awaiting frame_post_draw.
#   MONARCH_TEST="res://tool_eyes_weaponhold.gd" Godot.exe --path .   (windowed)
var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr("HOLD: " + t); OS.delay_msec(1)

func _ready() -> void:
	say("start")
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "": shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(600):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: say("no player"); get_tree().quit(1); return
	say("player found")
	# leave the opening
	for _r in range(20):
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish()
		get_tree().paused = false
		await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	GameState.game_hours = 10.0   # broad daylight so the shots read
	p.global_position = Vector2(-400, -160)
	for id in ["exc_thunder","exc_stormfury","wpn_huntingbow","exc_voidcaller"]:
		if p.inventory != null: p.inventory.add_item(id, 1)
	# let the camera catch up to the teleport before shooting
	for _f in range(90):
		await get_tree().process_frame
	var cases := [
		["exc_thunder", Vector2(1,0), "01_sword_E"],
		["exc_stormfury", Vector2(1,0), "06_bow_E"],
		["exc_stormfury", Vector2(1,-1), "07_bow_NE"],
		["wpn_huntingbow", Vector2(1,0), "08_plainbow_E"],
		["exc_voidcaller", Vector2(1,0), "09_wand_E"],
	]
	for c in cases:
		p.wield_weapon(c[0])
		# aim relative to the player's REAL screen position (camera may offset)
		var pscreen: Vector2 = get_viewport().get_canvas_transform() * (p as Node2D).global_position
		get_viewport().warp_mouse(pscreen + (c[1] as Vector2).normalized() * 200.0)
		for _f in range(10):
			await get_tree().process_frame
		_shot(c[2], (get_viewport().get_canvas_transform() * (p as Node2D).global_position))
	say("done %d shots -> %s" % [_n, shot_dir])
	get_tree().quit(0)

func _shot(name: String, center: Vector2) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null: say("null img %s" % name); return
	var sz := img.get_size()
	var box := 300
	var c := Vector2i(int(center.x), int(center.y))
	var r := Rect2i(c.x-box/2, c.y-box/2, box, box).intersection(Rect2i(0,0,sz.x,sz.y))
	img.get_region(r).save_png(shot_dir.path_join(name + ".png"))
	_n += 1
	say("shot %s around (%d,%d)" % [name, c.x, c.y])
