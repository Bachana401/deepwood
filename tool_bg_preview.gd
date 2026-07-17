extends SceneTree

# Composites the backdrop plates exactly as generate_mountains() tiles them
# (cycle 1,2,3 then 1',2',3') so the seams can be EYEBALLED offline -- headless
# can't render the game, but it can prove the tiling maths.
# Red line = where GROUND_Y cuts the plate (rows below it are hidden in-game).
# Cyan ticks = tile joins, drawn only in the top 6px so they don't hide the seam.
# usage: -- [tiles]

const MOUNTAIN_Y := 40.0
const GROUND_Y := -39.0
const SCALE := 3
const PLATES := [
	"res://art/environment/deepwood_backdrop_1.png",
	"res://art/environment/deepwood_backdrop_2.png",
	"res://art/environment/deepwood_backdrop_3.png",
]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var tiles: int = int(a[0]) if a.size() > 0 else 6
	var imgs: Array = []
	for p in PLATES:
		var t: Texture2D = load(p)
		if t == null:
			printerr("missing plate %s" % p)
			quit(1)
			return
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		imgs.append(im)
	var w: int = (imgs[0] as Image).get_width()
	var h: int = (imgs[0] as Image).get_height()
	for im in imgs:
		if (im as Image).get_width() != w or (im as Image).get_height() != h:
			printerr("SIZE MISMATCH -- plates are not aligned")
			quit(1)
			return

	var flips: Array = []
	for im in imgs:
		var f := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				f.set_pixel(x, y, (im as Image).get_pixel(w - 1 - x, y))
		flips.append(f)

	var out := Image.create(w * tiles, h, false, Image.FORMAT_RGBA8)
	for i in range(tiles):
		var src: Image = flips[i % imgs.size()] if (i / imgs.size()) % 2 == 1 else imgs[i % imgs.size()]
		out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
		printerr("tile %d -> plate %d%s" % [i, (i % imgs.size()) + 1, "'" if (i / imgs.size()) % 2 == 1 else ""])

	var top_world := MOUNTAIN_Y - float(h * SCALE)
	var ground_row := int(round((GROUND_Y - top_world) / float(SCALE)))
	printerr("plate %dx%d scale %d -> %d world px tall; top y=%.1f" % [w, h, SCALE, h * SCALE, top_world])
	printerr("ground cuts source row %d/%d -- rows below are hidden in-game" % [ground_row, h])
	if ground_row >= 0 and ground_row < h:
		for x in range(out.get_width()):
			out.set_pixel(x, ground_row, Color(1, 0, 0))
	for i in range(1, tiles):
		for y in range(6):
			out.set_pixel(i * w, y, Color(0, 1, 1))
	out.save_png(ProjectSettings.globalize_path("res://qc_backdrop.png"))
	printerr("saved qc_backdrop.png (red = ground line, cyan ticks = joins)")
	quit(0)
