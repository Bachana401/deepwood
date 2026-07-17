extends SceneTree

# Contact sheet: lays every frame of an animation out in a row, magnified, on a
# slate backing with a frame index bar, so the whole loop can be QC'd in one
# look -- drift, morphing, a dud frame, a bad transparency edge.
# usage: --script tool_sheet.gd -- <dir> <prefix> <count> [zoom]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		printerr("usage: -- <dir> <prefix> <count> [zoom]")
		quit(1)
		return
	var dir: String = a[0]
	var prefix: String = a[1]
	var n: int = int(a[2])
	var zoom: int = int(a[3]) if a.size() > 3 else 3
	var imgs := []
	for i in range(1, n + 1):
		var p := "res://%s/%s_%d.png" % [dir, prefix, i]
		var t: Texture2D = load(p)
		if t == null:
			printerr("missing ", p)
			continue
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		imgs.append(im)
	if imgs.is_empty():
		quit(1)
		return
	var fw: int = imgs[0].get_width()
	var fh: int = imgs[0].get_height()
	var pad := 2
	var sheet := Image.create((fw + pad) * imgs.size() + pad, fh + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.17, 1))
	for i in range(imgs.size()):
		var ox: int = pad + i * (fw + pad)
		# alternating checker so transparency is obvious
		for y in range(fh):
			for x in range(fw):
				var bg: Color = Color(0.2, 0.2, 0.25) if ((x / 8 + y / 8) % 2 == 0) else Color(0.24, 0.24, 0.29)
				var c: Color = imgs[i].get_pixel(x, y)
				sheet.set_pixel(ox + x, y + 4, bg.lerp(Color(c.r, c.g, c.b), c.a))
		# index tick
		for x in range(mini(i + 1, fw)):
			sheet.set_pixel(ox + x, fh + 6, Color(0.4, 1.0, 0.5))
	sheet.resize(sheet.get_width() * zoom, sheet.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	var out := ProjectSettings.globalize_path("res://qc_sheet_%s.png" % prefix)
	sheet.save_png(out)
	printerr("%d frames %dx%d -> %s" % [imgs.size(), fw, fh, out])
	quit()
