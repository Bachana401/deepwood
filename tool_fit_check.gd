extends SceneTree

# Verifies the derived widths: for every building, does the facade the code will
# DRAW (uniform scale off height, sink rows scaled away) match the footprint the
# village reserves for it (eff_w)? A mismatch means the labels/workers/spacing
# drift off the art. Also reports the stretch that USED to be applied.

func _initialize() -> void:
	var main := load("res://main.gd")
	var bld := load("res://building.gd")
	var defs = main.VILLAGE_BUILDINGS
	var art = bld.BUILDING_ART
	var sink = bld.ART_SINK
	var worst := 0.0
	for def in defs:
		var key: String = art.get(def.name, "")
		if key == "":
			continue
		var tex: Texture2D = load("res://art/buildings/%s.png" % key)
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var c := Rect2(img.get_used_rect())
		var sc: float = float(def.get("scale", 2.0))
		# what main.gd hands the building (VILLAGE_WIDTH_BOOST is now 1.0)
		var w: float = def.width * sc * main.VILLAGE_WIDTH_BOOST * 1.3
		var h: float = def.height * sc * 1.3
		# what build_intact will actually draw
		var ch: float = maxf(c.size.y - float(sink.get(def.name, 0.0)), 1.0)
		var s: float = h / ch
		var dw: float = c.size.x * s
		var err: float = absf(dw - w) / w * 100.0
		worst = maxf(worst, err)
		printerr("%-14s reserved %6.1f x %6.1f | drawn %6.1f | fit err %4.1f%%"
			% [def.name, w, h, dw, err])
	printerr("WORST FIT ERROR: %.1f%%  %s" % [worst, "OK" if worst < 1.5 else "*** TOO BIG ***"])
	quit()
