extends SceneTree

# Crops a content-space box out of a facade and magnifies it, with a 10px grid
# overlay in content coordinates -- so spot boxes (fires, signs, lanterns) can
# be read off the art directly instead of guessed.
# usage: -- <facade> <x> <y> <w> <h> [zoom]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 5:
		printerr("usage: -- <facade> <x> <y> <w> <h> [zoom]")
		quit(1)
		return
	var t: Texture2D = load("res://art/buildings/%s.png" % a[0])
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_used_rect()
	var x := int(a[1]); var y := int(a[2]); var w := int(a[3]); var h := int(a[4])
	var zoom: int = int(a[5]) if a.size() > 5 else 6
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in range(h):
		for i in range(w):
			var sp := c.position + Vector2i(x + i, y + j)
			var col := Color(0.15, 0.15, 0.19, 1.0)
			if sp.x >= 0 and sp.y >= 0 and sp.x < img.get_width() and sp.y < img.get_height():
				var p: Color = img.get_pixelv(sp)
				if p.a > 0.02:
					col = Color(p.r, p.g, p.b, 1.0)
			# grid every 10 content px, brighter every 50
			if (x + i) % 50 == 0 or (y + j) % 50 == 0:
				col = col.lerp(Color(0, 1, 1), 0.5)
			elif (x + i) % 10 == 0 or (y + j) % 10 == 0:
				col = col.lerp(Color(0, 1, 1), 0.18)
			out.set_pixel(i, j, col)
	out.resize(w * zoom, h * zoom, Image.INTERPOLATE_NEAREST)
	var p2 := ProjectSettings.globalize_path("res://qc_crop_%s.png" % a[0])
	out.save_png(p2)
	printerr("crop %s [%d,%d %dx%d] x%d -> %s  (cyan grid = 10px, bright = 50px, origin = content top-left)"
		% [a[0], x, y, w, h, zoom, p2])
	quit()
