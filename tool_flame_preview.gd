extends SceneTree

# Composites the animated flame onto a facade's fire spots exactly the way the
# game will, and writes the result as a PNG so the look can be judged BEFORE
# wiring it up. Renders the same frame in both candidate blend modes:
#   add    -- flame's dark outline contributes nothing, bright core glows.
#   normal -- flame drawn solid over the painted fire.

const SPOTS := {
	"smithy": [
		{"x": 60, "y": 136, "w": 40, "h": 56},    # the archway forge
		{"x": 152, "y": 136, "w": 28, "h": 28},   # fire seen through the shop window
		{"x": 220, "y": 136, "w": 28, "h": 28},   # the brazier by the anvil
	],
}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var frame: int = int(a[0]) if a.size() > 0 else 1
	for name in SPOTS:
		for mode in ["add", "normal"]:
			_preview(name, frame, mode)
	quit()

func _preview(fname: String, frame: int, mode: String) -> void:
	var base := _img("res://art/buildings/%s.png" % fname)
	var fl := _img("res://art/effects/flame_%d.png" % frame)
	var c := base.get_used_rect()
	var fc := fl.get_used_rect()
	var out := Image.create(int(c.size.x), int(c.size.y), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.16, 0.16, 0.2, 1))
	for y in range(int(c.size.y)):
		for x in range(int(c.size.x)):
			var col: Color = base.get_pixelv(c.position + Vector2i(x, y))
			if col.a > 0.02:
				out.set_pixel(x, y, Color(col.r, col.g, col.b, 1))
	for spot in SPOTS[fname]:
		# uniform fit of the flame's content into the spot, bottom-anchored
		var s: float = minf(float(spot.w) / fc.size.x, float(spot.h) / fc.size.y)
		var dw: int = int(fc.size.x * s)
		var dh: int = int(fc.size.y * s)
		var ox: int = int(spot.x + (spot.w - dw) / 2.0)
		var oy: int = int(spot.y + spot.h - dh)
		for y in range(dh):
			for x in range(dw):
				var src := Vector2i(int(fc.position.x + x / s), int(fc.position.y + y / s))
				if src.x >= fl.get_width() or src.y >= fl.get_height():
					continue
				var f: Color = fl.get_pixelv(src)
				if f.a <= 0.02:
					continue
				var px := Vector2i(ox + x, oy + y)
				if px.x < 0 or px.y < 0 or px.x >= out.get_width() or px.y >= out.get_height():
					continue
				var b: Color = out.get_pixelv(px)
				var r: Color
				if mode == "add":
					r = Color(minf(b.r + f.r * f.a, 1.0), minf(b.g + f.g * f.a, 1.0), minf(b.b + f.b * f.a, 1.0), 1.0)
				else:
					r = Color(lerpf(b.r, f.r, f.a), lerpf(b.g, f.g, f.a), lerpf(b.b, f.b, f.a), 1.0)
				out.set_pixelv(px, r)
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var p := ProjectSettings.globalize_path("res://qc_flame_%s_%s_f%d.png" % [fname, mode, frame])
	out.save_png(p)
	printerr("-> ", p)

func _img(path: String) -> Image:
	var t: Texture2D = load(path)
	var i := t.get_image()
	if i.is_compressed():
		i.decompress()
	i.convert(Image.FORMAT_RGBA8)
	return i
