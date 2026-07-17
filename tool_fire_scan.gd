extends SceneTree

# Finds the FIRE in each painted facade so an animated flame can be laid over
# it. Fire has to be told apart from candle-lit windows, which are also warm:
# fire is saturated orange (blue channel drops away, red runs well ahead of
# green), window light is a pale warm yellow with plenty of blue in it.
# Prints one line per cluster; writes a QC image per building with each
# detected cluster boxed in cyan so the hits can be eyeballed.

const OUT := "res://qc_fire/"
const CELL := 4
const MIN_PIXELS := 18

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var d := DirAccess.open("res://art/buildings/")
	var names := []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".png"):
			names.append(f.get_basename())
		f = d.get_next()
	names.sort()
	for n in names:
		_scan(n)
	quit()

# saturated orange fire, NOT pale window candle-light
static func is_fire(c: Color) -> bool:
	return c.a > 0.5 and c.r > 0.72 and c.b < 0.42 and c.r - c.b > 0.42 and c.g < c.r * 0.88 and c.g > c.b * 0.75

func _scan(fname: String) -> void:
	var tex: Texture2D = load("res://art/buildings/%s.png" % fname)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_used_rect()
	# 1) fire pixels -> coarse cells
	var cells := {}
	var total := 0
	for y in range(int(c.size.y)):
		for x in range(int(c.size.x)):
			if is_fire(img.get_pixelv(c.position + Vector2i(x, y))):
				cells[Vector2i(x / CELL, y / CELL)] = cells.get(Vector2i(x / CELL, y / CELL), 0) + 1
				total += 1
	if cells.is_empty():
		printerr("%-16s no fire" % fname)
		return
	# 2) flood-merge into clusters
	var seen := {}
	var clusters: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var q: Array = [start]
		var mn: Vector2i = start
		var mx: Vector2i = start
		var count := 0
		while not q.is_empty():
			var p: Vector2i = q.pop_back()
			if seen.has(p) or not cells.has(p):
				continue
			seen[p] = true
			count += cells[p]
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					q.append(p + Vector2i(dx, dy))
		if count >= MIN_PIXELS:
			clusters.append({"mn": mn, "mx": mx, "count": count})
	clusters.sort_custom(func(a, b): return a["count"] > b["count"])
	var txt := ""
	for cl in clusters:
		var r := Rect2i(cl["mn"] * CELL, (cl["mx"] - cl["mn"] + Vector2i.ONE) * CELL)
		txt += "[%d,%d %dx%d px%d] " % [r.position.x, r.position.y, r.size.x, r.size.y, cl["count"]]
	printerr("%-16s %d fire px, %d cluster(s): %s" % [fname, total, clusters.size(), txt])
	# 3) QC image: box every cluster in cyan
	if clusters.is_empty():
		return
	var out := Image.create(int(c.size.x), int(c.size.y), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.16, 0.16, 0.2, 1))
	for y in range(int(c.size.y)):
		for x in range(int(c.size.x)):
			var col := img.get_pixelv(c.position + Vector2i(x, y))
			if col.a > 0.02:
				out.set_pixel(x, y, Color(col.r, col.g, col.b, 1))
	for cl in clusters:
		var r := Rect2i(cl["mn"] * CELL, (cl["mx"] - cl["mn"] + Vector2i.ONE) * CELL)
		for x in range(r.position.x, mini(r.end.x, int(c.size.x))):
			out.set_pixel(x, clampi(r.position.y, 0, int(c.size.y) - 1), Color(0, 1, 1))
			out.set_pixel(x, clampi(r.end.y - 1, 0, int(c.size.y) - 1), Color(0, 1, 1))
		for y in range(r.position.y, mini(r.end.y, int(c.size.y))):
			out.set_pixel(clampi(r.position.x, 0, int(c.size.x) - 1), y, Color(0, 1, 1))
			out.set_pixel(clampi(r.end.x - 1, 0, int(c.size.x) - 1), y, Color(0, 1, 1))
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png(ProjectSettings.globalize_path(OUT + fname + "_fire.png"))
