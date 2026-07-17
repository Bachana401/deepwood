extends Node

# Verifies the yard workers are real people now, not coloured boxes: every
# outdoor mode builds a villager sprite, the window silhouettes stay
# procedural on purpose, walkers actually play their walk cycle, and the
# held tools still land in the hands rather than at the worker's knees.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	# the opening plea pauses the whole tree -- without this nothing _processes
	# and every worker sits frozen on frame 0
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break
	check("tree unpaused", not get_tree().paused)
	for i in range(30):
		await get_tree().process_frame

	var WF = load("res://worker_figure.gd")
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# --- every outdoor mode gets a sprite body ---
	for mode in ["walk", "stand", "anvil", "vendor", "carry", "sweep", "fish"]:
		var f = WF.new()
		f.mode = mode
		f.spot = Vector2.ZERO
		f.ground_y = 0.0
		host.add_child(f)
		await get_tree().process_frame
		check("%s worker is a villager sprite" % mode, f.skin_sprite != null)
		if f.skin_sprite != null:
			# the DRAWN height: the frame carries transparent padding, so measure
			# the used rect, not the canvas
			var im: Image = f.skin_sprite.sprite_frames.get_frame_texture("idle", 0).get_image()
			var h: float = im.get_used_rect().size.y * f.skin_sprite.scale.y * f.body_scale
			# should stand roughly as tall as a wandering villager (38px)
			check("%s worker is human-sized (%.0fpx)" % [mode, h], h > 26.0 and h < 44.0, "%.1f" % h)
	# --- window silhouettes stay procedural (a shape behind glass) ---
	var wf = WF.new()
	wf.mode = "window"
	wf.window_rect = Rect2(0, 0, 20, 24)
	host.add_child(wf)
	await get_tree().process_frame
	check("window worker stays a silhouette", wf.skin_sprite == null)

	# --- a walker actually plays its walk cycle ---
	var walker = WF.new()
	walker.mode = "walk"
	walker.min_x = -60.0
	walker.max_x = 60.0
	walker.ground_y = 0.0
	host.add_child(walker)
	await get_tree().process_frame
	var saw_walk := false
	var moved := false
	var x0: float = walker.position.x
	for i in range(120):
		await get_tree().process_frame
		if walker.skin_sprite and walker.skin_sprite.animation == "walk":
			saw_walk = true
		if absf(walker.position.x - x0) > 1.0:
			moved = true
		if saw_walk and moved:
			break
	check("walker moves", moved)
	check("walker plays the WALK animation", saw_walk,
		"stuck on '%s'" % (walker.skin_sprite.animation if walker.skin_sprite else "?"))

	# --- the fisherman's rod still reaches his hands ---
	var fish = WF.new()
	fish.mode = "fish"
	fish.spot = Vector2.ZERO
	host.add_child(fish)
	await get_tree().process_frame
	check("fisherman keeps his rod", fish.rod != null)
	if fish.rod != null and fish.skin_sprite != null:
		# rod grip (y=-10) must sit inside the body, not below its feet (y=0)
		var grip_y: float = fish.rod.points[0].y
		var body_h: float = fish.skin_sprite.sprite_frames.get_frame_texture("idle", 0).get_height() * fish.skin_sprite.scale.y
		check("rod grip is at hand height", grip_y < 0.0 and grip_y > -body_h,
			"grip %.1f vs body height %.1f" % [grip_y, body_h])

	# --- smith without a spare arm still hammers ---
	var smith = WF.new()
	smith.mode = "anvil"
	smith.spot = Vector2.ZERO
	host.add_child(smith)
	await get_tree().process_frame
	check("skinned smith has no pasted-on arm", smith.arm == null or smith.skin_sprite == null)
	var rocked := false
	var r0: float = smith.skin_sprite.rotation if smith.skin_sprite else 0.0
	for i in range(60):
		await get_tree().process_frame
		if smith.skin_sprite and absf(smith.skin_sprite.rotation - r0) > 0.01:
			rocked = true
			break
	check("smith leans into the blow", rocked)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
