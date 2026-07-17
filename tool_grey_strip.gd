extends SceneTree

# Strips leftover baked backdrop from a facade. The original border flood-fill
# could only reach backdrop touching the canvas edge; anything WALLED IN by the
# art (the marketplace's two stall interiors, boxed in by posts, awning and
# counter) survived as flat grey panels that read as solid walls instead of
# showing the village behind.
#
# Run with --report first: it writes a QC image with the doomed pixels in
# magenta and changes nothing. Only --apply actually rewrites the PNG.

const GREY_TOL := 0.05     # how close r,g,b must be to count as neutral grey
const MIN_COMPONENT := 150 # ignore small grey specks (real art: nails, stone)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var apply := args.has("--apply")
	var files := []
	for a in args:
		if not a.begins_with("--"):
			files.append(a)
	if files.is_empty():
		printerr("usage: --script tool_grey_strip.gd -- <name> [<name>...] [--apply]")
		quit(1)
		return
	for f in files:
		_strip(f, apply)
	quit()

func _strip(fname: String, apply: bool) -> void:
	var path := "res://art/buildings/%s.png" % fname
	var tex: Texture2D = load(path)
	if tex == null:
		printerr(fname, ": no art")
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	# 1) the dominant flat grey = the backdrop tone
	var hist := {}
	for y in range(H):
		for x in range(W):
			var c := img.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var mx: float = maxf(c.r, maxf(c.g, c.b))
			var mn: float = minf(c.r, minf(c.g, c.b))
			if mx - mn < GREY_TOL and mx > 0.4 and mx < 0.9:
				var k := "%.2f" % snappedf(mx, 0.01)
				hist[k] = hist.get(k, 0) + 1
	if hist.is_empty():
		printerr("%-14s no flat grey" % fname)
		return
	var keys: Array = hist.keys()
	keys.sort_custom(func(a, b): return hist[a] > hist[b])
	var tone: float = float(keys[0])
	# 2) connected components of that tone
	var seen := {}
	var doomed := {}
	var comps: Array = []
	for y0 in range(H):
		for x0 in range(W):
			var s := Vector2i(x0, y0)
			if seen.has(s) or not _is_tone(img, s, tone):
				continue
			var q: Array = [s]
			var cells: Array = []
			var mn := s
			var mx := s
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				if seen.has(p) or p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
					continue
				if not _is_tone(img, p, tone):
					continue
				seen[p] = true
				cells.append(p)
				mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
				mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
				q.append(p + Vector2i(1, 0)); q.append(p + Vector2i(-1, 0))
				q.append(p + Vector2i(0, 1)); q.append(p + Vector2i(0, -1))
			if cells.size() >= MIN_COMPONENT:
				comps.append({"n": cells.size(), "mn": mn, "mx": mx})
				for p in cells:
					doomed[p] = true
	comps.sort_custom(func(a, b): return a["n"] > b["n"])
	var txt := ""
	for c in comps:
		txt += "[%d,%d %dx%d n=%d] " % [c["mn"].x, c["mn"].y, c["mx"].x - c["mn"].x + 1, c["mx"].y - c["mn"].y + 1, c["n"]]
	printerr("%-14s tone %.2f  %d region(s) %d px: %s" % [fname, tone, comps.size(), doomed.size(), txt])
	if comps.is_empty():
		return
	if not apply:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qc_grey/"))
		var q2 := Image.create(W, H, false, Image.FORMAT_RGBA8)
		q2.fill(Color(0.1, 0.1, 0.13, 1))
		for y in range(H):
			for x in range(W):
				var c := img.get_pixel(x, y)
				if doomed.has(Vector2i(x, y)):
					q2.set_pixel(x, y, Color(1, 0, 1))      # magenta = would be cleared
				elif c.a > 0.02:
					q2.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
		q2.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
		q2.save_png(ProjectSettings.globalize_path("res://qc_grey/%s_grey.png" % fname))
		printerr("    -> qc_grey/%s_grey.png (magenta = would clear). Re-run with --apply to commit." % fname)
		return
	for p in doomed:
		img.set_pixelv(p, Color(0, 0, 0, 0))
	img.save_png(ProjectSettings.globalize_path(path))
	printerr("    -> APPLIED: %d px cleared to transparent" % doomed.size())

func _is_tone(img: Image, p: Vector2i, tone: float) -> bool:
	var c := img.get_pixelv(p)
	if c.a <= 0.5:
		return false
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	return mx - mn < GREY_TOL and absf(mx - tone) < 0.03
