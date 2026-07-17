extends SceneTree

# Makes a SET of backdrop plates interchangeable, so they can be tiled in any
# order with no visible seam.
#
# The problem: mirror-tiling one plate is seamless but visibly symmetric. Cycling
# several different plates kills the symmetry, but then tile N's right edge meets
# tile N+1's left edge and the join shows.
#
# The fix: force every plate to share ONE canonical edge column. Each plate's
# outer EDGE columns are ramped toward that column, so plate[0] and plate[w-1]
# are pixel-identical on every plate. Any A|B join is then two identical columns
# side by side -- and because the canonical column is picked as the DARKEST
# (most trunk-like) column in the set, every seam reads as a tree trunk.
#
# usage: -- <edge-width> <plate> [plate ...]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("usage: -- <edge-width> <plate> [plate ...]")
		quit(1)
		return
	var edge := int(a[0])
	var names: Array = a.slice(1)
	var imgs: Array = []
	var w := -1
	var h := -1
	for n in names:
		var t: Texture2D = load("res://art/environment/%s.png" % n)
		if t == null:
			printerr("MISSING plate %s" % n)
			quit(1)
			return
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		if w == -1:
			w = im.get_width(); h = im.get_height()
		elif im.get_width() != w or im.get_height() != h:
			printerr("ALIGNMENT FAIL: %s is %dx%d, expected %dx%d" % [n, im.get_width(), im.get_height(), w, h])
			quit(1)
			return
		imgs.append(im)
	printerr("%d plates, all %dx%d -- sizes aligned" % [imgs.size(), w, h])

	# canonical edge = the darkest full column across the set (a trunk, not a gap)
	var best_img := 0
	var best_x := 0
	var best_lum := 999.0
	for i in range(imgs.size()):
		var im: Image = imgs[i]
		for x in range(w):
			var lum := 0.0
			for y in range(h):
				var p := im.get_pixel(x, y)
				lum += (p.r + p.g + p.b) / 3.0
			lum /= h
			if lum < best_lum:
				best_lum = lum; best_img = i; best_x = x
	printerr("canonical edge column: plate %s col %d (mean lum %.3f)" % [names[best_img], best_x, best_lum])
	var canon: Array = []
	for y in range(h):
		canon.append((imgs[best_img] as Image).get_pixel(best_x, y))

	# ramp each plate's outer columns toward the canonical column
	for i in range(imgs.size()):
		var im: Image = imgs[i]
		for x in range(edge):
			var wgt := 1.0 - float(x) / float(edge)      # 1.0 at the very edge
			for y in range(h):
				var c: Color = canon[y]
				im.set_pixel(x, y, im.get_pixel(x, y).lerp(c, wgt))
				var rx := w - 1 - x
				im.set_pixel(rx, y, im.get_pixel(rx, y).lerp(c, wgt))
		var dst := ProjectSettings.globalize_path("res://art/environment/%s.png" % names[i])
		im.save_png(dst)

	# prove it: every plate's first and last column must now be identical
	var fail := 0
	for i in range(imgs.size()):
		for j in range(imgs.size()):
			for y in range(h):
				var l: Color = (imgs[i] as Image).get_pixel(0, y)
				var r: Color = (imgs[j] as Image).get_pixel(w - 1, y)
				if absf(l.r - r.r) > 0.004 or absf(l.g - r.g) > 0.004 or absf(l.b - r.b) > 0.004:
					fail += 1
	if fail == 0:
		printerr("SEAM PROOF: every plate's left edge == every plate's right edge. Any order tiles clean.")
	else:
		printerr("SEAM PROOF FAILED on %d pixel comparisons" % fail)
	quit(0)
