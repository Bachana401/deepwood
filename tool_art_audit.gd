extends SceneTree

# One-off art audit for the village polish pass: for every building facade,
# report the content box, the base profile (how many opaque px per row near the
# bottom -- a building whose widest base row sits ABOVE the lowest pixel will
# look like it is floating on a stalk), and any interior opaque regions that
# are NOT reachable from the border (leftover baked backdrop the flood-fill
# could not get to).

const DIR := "res://art/buildings/"

func _initialize() -> void:
	var names := []
	var d := DirAccess.open(DIR)
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".png"):
			names.append(f)
		f = d.get_next()
	names.sort()
	for n in names:
		_audit(n)
	quit()

func _audit(fname: String) -> void:
	var tex: Texture2D = load(DIR + fname)
	if tex == null:
		printerr(fname, ": LOAD FAILED")
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var c := img.get_used_rect()
	if c.size.x <= 0:
		printerr(fname, ": EMPTY")
		return
	# --- base profile: opaque px per row for the lowest 34 rows of content ---
	var widths := []
	var maxw := 0
	for y in range(c.size.y):
		var w := 0
		for x in range(c.size.x):
			if img.get_pixelv(c.position + Vector2i(x, y)).a > 0.5:
				w += 1
		widths.append(w)
		maxw = maxi(maxw, w)
	# the "true base": lowest row that is still at least 55% of the widest row
	var base_row := c.size.y - 1
	for y in range(c.size.y - 1, -1, -1):
		if widths[y] >= int(maxw * 0.55):
			base_row = y
			break
	var stalk: int = c.size.y - 1 - base_row   # px of thin stuff below the solid base
	var prof := ""
	for y in range(maxi(0, c.size.y - 12), c.size.y):
		prof += "%d " % widths[y]
	# --- interior backdrop remnants: opaque regions unreachable from the border ---
	var W := img.get_width()
	var H := img.get_height()
	var seen := {}
	var q: Array = []
	for x in range(W):
		q.append(Vector2i(x, 0)); q.append(Vector2i(x, H - 1))
	for y in range(H):
		q.append(Vector2i(0, y)); q.append(Vector2i(W - 1, y))
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H or seen.has(p):
			continue
		if img.get_pixelv(p).a > 0.5:
			continue          # opaque = the art itself, stop
		seen[p] = true
		q.append(p + Vector2i(1, 0)); q.append(p + Vector2i(-1, 0))
		q.append(p + Vector2i(0, 1)); q.append(p + Vector2i(0, -1))
	# grey-ish opaque pixels (r~g~b, mid-tone) that could be leftover backdrop
	var greys := {}
	for y in range(int(c.position.y), int(c.end.y)):
		for x in range(int(c.position.x), int(c.end.x)):
			var col := img.get_pixel(x, y)
			if col.a <= 0.5:
				continue
			var mx: float = maxf(col.r, maxf(col.g, col.b))
			var mn: float = minf(col.r, minf(col.g, col.b))
			if mx - mn < 0.045 and mx > 0.45 and mx < 0.88:
				var key := "%.2f" % mx
				greys[key] = greys.get(key, 0) + 1
	var top_greys: Array = greys.keys()
	top_greys.sort_custom(func(a, b): return greys[a] > greys[b])
	var gtxt := ""
	for i in range(mini(3, top_greys.size())):
		gtxt += "%s:%d " % [top_greys[i], greys[top_greys[i]]]
	printerr("%-18s tex %dx%d  content %s  maxw %d  base_row %d  STALK %d  aspect %.2f\n    base profile (last 12 rows): %s\n    flat greys: %s"
		% [fname, tex.get_width(), tex.get_height(), str(c), maxw, base_row, stalk,
		   float(c.size.x) / float(c.size.y), prof, gtxt if gtxt != "" else "none"])
