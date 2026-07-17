extends SceneTree

# Where does the GRASS actually start? The village places every building with
# its base at GROUND_Y (-39), which assumes the ground skin's surface tile is
# opaque from its very first row. If the tile has transparent padding on top,
# the visible grass begins lower than -39 and every building in the village
# hangs in the air by exactly that gap.

func _initialize() -> void:
	var tex: Texture2D = load("res://art/environment/ground_tiles.png")
	if tex == null:
		printerr("no ground_tiles.png")
		quit(); return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	printerr("sheet: %dx%d" % [img.get_width(), img.get_height()])
	for spec in [["surface (96,0)", 96, 0], ["fill (64,32)", 64, 32]]:
		var ox: int = spec[1]
		var oy: int = spec[2]
		printerr("--- %s ---" % spec[0])
		var first_opaque := -1
		for y in range(32):
			var n := 0
			for x in range(32):
				if img.get_pixel(ox + x, oy + y).a > 0.5:
					n += 1
			if n > 0 and first_opaque < 0:
				first_opaque = y
			printerr("   row %2d: %2d/32 opaque %s" % [y, n, "#".repeat(n / 2)])
		printerr("   FIRST OPAQUE ROW: %d  -> %s" % [first_opaque,
			"tile is full-bleed, ok" if first_opaque == 0
			else "*** %d px of transparent padding: everything placed on this line floats ***" % first_opaque])
	quit()
