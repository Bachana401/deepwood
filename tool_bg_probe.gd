extends SceneTree

# Row-profile probe for a background plate: prints mean colour + "grass-ness"
# per row band so the baked ground line can be read off the art instead of
# guessed. usage: -- <path-under-art/environment> [step]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var name: String = a[0] if a.size() > 0 else "_bg_src"
	var step: int = int(a[1]) if a.size() > 1 else 4
	var t: Texture2D = load("res://art/environment/%s.png" % name)
	if t == null:
		printerr("cannot load %s" % name)
		quit(1)
		return
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	printerr("size %dx%d" % [w, h])
	printerr("row | mean R,G,B | bright | greenDom | opaque%")
	for y in range(0, h, step):
		var r := 0.0; var g := 0.0; var b := 0.0; var op := 0
		for x in range(w):
			var p := img.get_pixel(x, y)
			if p.a > 0.02:
				op += 1
			r += p.r; g += p.g; b += p.b
		r /= w; g /= w; b /= w
		var bright := (r + g + b) / 3.0
		var green_dom: float = g - maxf(r, b)
		printerr("%3d | %.2f,%.2f,%.2f | %.3f | %+.3f | %d%%" % [y, r, g, b, bright, green_dom, int(round(float(op) / w * 100.0))])
	quit(0)
