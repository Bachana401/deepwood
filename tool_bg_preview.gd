extends SceneTree

# Composites the backdrop plate exactly as generate_mountains() tiles it
# (mirror every other tile) so the seams can be EYEBALLED offline -- headless
# can't render the game, but it can prove the tiling maths.
# Draws a red line where GROUND_Y sits relative to MOUNTAIN_Y, so anything baked
# into the plate below that line is provably hidden in-game.
# usage: -- [tiles]

const MOUNTAIN_Y := 40.0
const GROUND_Y := -39.0
const SCALE := 3

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var tiles: int = int(a[0]) if a.size() > 0 else 3
	var t: Texture2D = load("res://art/environment/deepwood_backdrop.png")
	if t == null:
		printerr("no plate")
		quit(1)
		return
	var src := t.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()

	var flip := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			flip.set_pixel(x, y, src.get_pixel(w - 1 - x, y))

	var out := Image.create(w * tiles, h, false, Image.FORMAT_RGBA8)
	for i in range(tiles):
		out.blit_rect(flip if i % 2 == 1 else src, Rect2i(0, 0, w, h), Vector2i(i * w, 0))

	# Where does the ground surface cut across the plate?
	# plate top sits at MOUNTAIN_Y - h*SCALE ; ground surface at GROUND_Y.
	var top_world := MOUNTAIN_Y - float(h * SCALE)
	var ground_row := int(round((GROUND_Y - top_world) / float(SCALE)))
	printerr("plate %dx%d  scale %d  world height %d" % [w, h, SCALE, h * SCALE])
	printerr("plate top world y = %.1f ; ground surface y = %.1f" % [top_world, GROUND_Y])
	printerr("ground cuts the plate at source row %d of %d (rows below it are hidden in-game)" % [ground_row, h])
	if ground_row >= 0 and ground_row < h:
		for x in range(out.get_width()):
			out.set_pixel(x, ground_row, Color(1, 0, 0))
	# mark each seam in cyan so a mismatch is obvious
	for i in range(1, tiles):
		for y in range(h):
			out.set_pixel(i * w, y, Color(0, 1, 1))
	var dst := ProjectSettings.globalize_path("res://qc_backdrop.png")
	printerr("saved -> %s  (red = ground line, cyan = tile seams)" % dst)
	out.save_png(dst)
	quit(0)
