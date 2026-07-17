extends SceneTree

# Locates a warm-coloured feature inside a region of a facade and prints its
# tight content-space box -- used to pin the Bar's beer sign and the hanging
# lanterns without guessing coordinates off a screenshot.
# usage: -- <facade> <x0> <y0> <x1> <y1>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 5:
		printerr("usage: -- <facade> <x0> <y0> <x1> <y1>")
		quit(1)
		return
	var t: Texture2D = load("res://art/buildings/%s.png" % a[0])
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_used_rect()
	var x0 := int(a[1]); var y0 := int(a[2]); var x1 := int(a[3]); var y1 := int(a[4])
	var mn := Vector2i(99999, 99999)
	var mx := Vector2i(-1, -1)
	var n := 0
	for y in range(y0, mini(y1, int(c.size.y))):
		for x in range(x0, mini(x1, int(c.size.x))):
			var p: Color = img.get_pixelv(c.position + Vector2i(x, y))
			# warm/lit: clearly warmer than it is blue
			if p.a > 0.5 and p.r > 0.6 and p.r > p.b * 1.3 and p.g > p.b * 0.9:
				mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
				mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
				n += 1
	if n == 0:
		printerr("%s: nothing warm in that region" % a[0])
	else:
		printerr("%s: warm box {\"x\": %d, \"y\": %d, \"w\": %d, \"h\": %d}  (%d px)"
			% [a[0], mn.x, mn.y, mx.x - mn.x + 1, mx.y - mn.y + 1, n])
	quit()
