extends SceneTree

# Lays the ascended-Monarch candidates out big, in two rows, each numbered with
# a bar of pips (row 1 = 0..7 across the top, counted in green pips under each),
# on the game's own gloom so they're judged in the light they'll actually live
# in -- not on a white page.

const Z := 4
const COLS := 8

func _initialize() -> void:
	var imgs := []
	for i in range(16):
		var t: Texture2D = load("res://qc_god/v_%d.png" % i)
		if t == null:
			continue
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		imgs.append(im)
	if imgs.is_empty():
		printerr("no candidates")
		quit(); return
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var pad := 3
	var lab := 6
	var rows: int = int(ceil(float(imgs.size()) / COLS))
	var out := Image.create((w + pad) * COLS * Z + pad, ((h + lab + pad) * rows + pad) * Z, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.11, 0.11, 0.15, 1))
	for n in range(imgs.size()):
		var cx: int = n % COLS
		var cy: int = n / COLS
		var ox: int = pad + cx * (w + pad)
		var oy: int = pad + cy * (h + lab + pad)
		for y in range(h):
			for x in range(w):
				var c: Color = imgs[n].get_pixel(x, y)
				if c.a < 0.04:
					continue
				var bg := Color(0.16, 0.16, 0.21) if ((x / 8 + y / 8) % 2 == 0) else Color(0.19, 0.19, 0.24)
				_px(out, ox + x, oy + y, bg.lerp(Color(c.r, c.g, c.b), c.a))
		# index pips: n+1 green marks under each candidate
		for p in range(n % COLS + 1 if false else n + 1):
			var px: int = ox + (p % w)
			var py: int = oy + h + 1 + (p / w) * 2
			_px(out, px, py, Color(0.45, 1.0, 0.5))
	out.save_png(ProjectSettings.globalize_path("res://qc_god/sheet.png"))
	printerr("%d candidates -> qc_god/sheet.png  (green pips under each = its number, left-to-right)" % imgs.size())
	quit()

func _px(dst: Image, x: int, y: int, c: Color) -> void:
	for j in range(Z):
		for i in range(Z):
			var dx := x * Z + i
			var dy := y * Z + j
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				dst.set_pixel(dx, dy, c)
