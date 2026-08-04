extends Node

# The village must stand ON the green, not above it.
#
# This shipped floating because every check asked "did the ground get built?"
# instead of "where is the visible grass?". The surface tile is a wang tile with
# transparent padding on top, so laying its cell edge on GROUND_Y hung the whole
# village 16px in the air. These checks read the ART, not the node.

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
	for i in range(40):
		await get_tree().process_frame

	var main := p.get_parent()
	while main != null and not main.has_method("build_ground_skin"):
		main = main.get_parent()
	check("main scene found", main != null)
	if main == null:
		get_tree().quit(1); return
	var ground_y: float = main.GROUND_Y

	# --- where is the visible grass? ---
	var strips := []
	for s in main.get_node("Ground").get_children():
		if s is Sprite2D and s.region_enabled:
			strips.append(s)
	check("ground skin built", strips.size() >= 2, "got %d strips" % strips.size())
	if strips.size() < 2:
		printerr("RESULT: %d FAILURES" % maxi(fails, 1)); get_tree().quit(1); return

	# top-most strip = the grass surface. Find its first OPAQUE row in world space.
	var surf: Sprite2D = strips[0]
	for s in strips:
		if s.position.y < surf.position.y:
			surf = s
	var img := surf.texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var pad := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				pad = y
				break
		if pad >= 0:
			break
	check("surface tile has opaque pixels", pad >= 0)
	var grass_top: float = surf.position.y + float(pad) * surf.scale.y
	check("VISIBLE GRASS starts exactly on the ground line (%.1f vs %.1f)" % [grass_top, ground_y],
		absf(grass_top - ground_y) < 1.0,
		"grass at %.1f, buildings stand at %.1f -> %.1f px of float" % [grass_top, ground_y, grass_top - ground_y])

	# --- NO GAP ANYWHERE DOWN THE COLUMN ---
	# This used to compare the grass against whichever strip sat LOWEST, which
	# only tested what it meant while there were exactly two. There are more now
	# (the deep fill is re-laid either side of the cave mouth, see
	# underdark._carve_ground_skin), and "lowest" became the deep one -- so the
	# check reported a seam at the join between two strips that touch exactly.
	# Walk the column instead and assert every consecutive pair meets: that is
	# the actual invariant, it still catches the original bug (earth not
	# reaching the grass), and it cannot be fooled by adding more strips.
	var column := strips.duplicate()
	column.sort_custom(func(a, b): return a.position.y < b.position.y)
	var worst_gap := 0.0
	var gap_where := ""
	for i in range(column.size() - 1):
		var upper: Sprite2D = column[i]
		var below: Sprite2D = column[i + 1]
		# strips laid side by side (same top) are spans, not a gap in the column
		if absf(below.position.y - upper.position.y) < 0.5:
			continue
		var upper_bottom: float = upper.position.y + upper.region_rect.size.y * upper.scale.y
		var gap: float = below.position.y - upper_bottom
		if gap > worst_gap:
			worst_gap = gap
			gap_where = "%.1f -> %.1f" % [upper_bottom, below.position.y]
	check("the ground column is continuous, grass to deepest (no seam)",
		worst_gap <= 0.5, "worst gap %.1fpx at %s" % [worst_gap, gap_where])

	# --- every building's base is on the grass ---
	var n := 0
	var worst := 0.0
	var worst_name := ""
	for b in get_tree().get_nodes_in_group("building"):
		n += 1
		var d: float = absf(b.global_position.y - grass_top)
		if d > worst:
			worst = d
			worst_name = b.building_name
	check("buildings exist", n > 0, "%d" % n)
	check("every building sits on the grass (worst %.1fpx: %s)" % [worst, worst_name],
		worst < 1.0, "%s floats %.1fpx" % [worst_name, worst])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
