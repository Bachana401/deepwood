extends Node

# Verifies the backdrop actually covers the world it is supposed to cover --
# the bug being that the map was lengthened and the sky wasn't, leaving the
# right half of Deepwood on bare viewport grey. Checks the sky, the ground
# skin, the mountains and the treeline all reach the world's right edge.

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
	for i in range(30):
		await get_tree().process_frame

	var main := p.get_parent()
	while main != null and not main.has_method("fit_sky_to_world"):
		main = main.get_parent()
	check("main scene found", main != null)
	if main == null:
		get_tree().quit(1); return

	var right: float = main.WORLD_RIGHT
	var left: float = main.WORLD_LEFT

	# --- sky covers the whole world ---
	var bands := []
	for b in main.get_node("Background").get_children():
		if b is ColorRect and b.name.begins_with("SkyBand"):
			bands.append(b)
	check("sky bands present", bands.size() == 4, "got %d" % bands.size())
	var sky_ok := true
	var worst := ""
	for b in bands:
		if b.offset_right < right or b.offset_left > left:
			sky_ok = false
			worst = "%s spans %.0f..%.0f, world is %.0f..%.0f" % [b.name, b.offset_left, b.offset_right, left, right]
	check("sky spans the whole world", sky_ok, worst)

	# --- ground skin reaches the right edge ---
	var ground_right := -1.0e9
	for s in main.get_node("Ground").get_children():
		if s is Sprite2D and s.region_enabled:
			ground_right = maxf(ground_right, s.position.x + s.region_rect.size.x)
	check("ground skin reaches world right", ground_right >= right - 1.0,
		"ground ends %.0f, world %.0f" % [ground_right, right])

	# --- parallax actually populates the whole map, not just the first half ---
	# (ridges and the treeline both live under Background/Mountains)
	var buckets := {}
	for m in main.get_node("Background/Mountains").get_children():
		var b: int = int(m.position.x / 5000.0)
		buckets[b] = buckets.get(b, 0) + 1
	var empty: Array = []
	for b in range(0, int(right / 5000.0)):
		if buckets.get(b, 0) < 2:
			empty.append("%d-%dk" % [b * 5, b * 5 + 5])
	check("no empty stretch of backdrop across the map", empty.is_empty(),
		"bare: %s" % str(empty))
	printerr("      backdrop density per 5k: ", buckets)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
