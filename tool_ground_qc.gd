extends SceneTree

# Grounding QC: draws the GAME'S ground line across the bottom of a facade at a
# proposed sink (in content px) and writes a magnified crop of the base, so the
# fit can actually be eyeballed instead of guessed. Red = where the ground line
# lands. Anything below red is buried in the dirt.

const OUT := "res://qc_ground/"
const ZOOM := 3
const ROWS := 56

# name -> proposed sink in CONTENT px
const CASES := {
	"builderhouse": 16,
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for n in CASES:
		_qc(n, CASES[n])
	quit()

func _qc(fname: String, sink: int) -> void:
	var tex: Texture2D = load("res://art/buildings/%s.png" % fname)
	if tex == null:
		printerr(fname, ": no art")
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_used_rect()
	# crop the base band of the CONTENT box
	var y0: int = maxi(int(c.position.y), int(c.end.y) - ROWS)
	var band := Image.create(int(c.size.x), int(c.end.y) - y0, false, Image.FORMAT_RGBA8)
	band.fill(Color(0.16, 0.16, 0.2, 1.0))   # slate backing so transparency reads
	for y in range(y0, int(c.end.y)):
		for x in range(int(c.position.x), int(c.end.x)):
			var col := img.get_pixel(x, y)
			if col.a > 0.02:
				band.set_pixel(x - int(c.position.x), y - y0, Color(col.r, col.g, col.b, 1.0))
	# the ground line: content row (size.y - sink) maps to this band row
	var gy: int = (int(c.end.y) - sink) - y0 - 1
	if gy >= 0 and gy < band.get_height():
		for x in range(band.get_width()):
			band.set_pixel(x, gy, Color(1, 0, 0, 1))
	band.resize(band.get_width() * ZOOM, band.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	var p := ProjectSettings.globalize_path(OUT + fname + "_sink%d.png" % sink)
	band.save_png(p)
	printerr("%-16s sink %d  ->  %s" % [fname, sink, p])
