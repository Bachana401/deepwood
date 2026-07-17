extends SceneTree

# Tone-matches a set of backdrop plates to ONE reference plate, so plates cut
# from separate generations read as the same forest instead of a patchwork.
#
# Generations of the same prompt drift in hue: plate 1 came back blue-teal while
# 2 and 3 came back green. Tiled side by side at 1200 world px each, that drift
# reads as coloured patches marching across the treeline. This transfers each
# plate's per-channel mean and spread onto the reference's, which unifies the
# palette while leaving all the painted detail intact.
#
# Run BEFORE tool_bg_align -- grading moves pixels, which would otherwise undo
# the shared edge column.
#
# usage: -- <reference-plate> <plate> [plate ...]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("usage: -- <reference> <plate> [plate ...]")
		quit(1)
		return
	var ref := _load(a[0])
	if ref == null:
		quit(1)
		return
	var rs := _stats(ref)
	printerr("reference %s: mean %.3f,%.3f,%.3f  std %.3f,%.3f,%.3f" % [a[0], rs[0].x, rs[0].y, rs[0].z, rs[1].x, rs[1].y, rs[1].z])

	for i in range(1, a.size()):
		var name: String = a[i]
		var im := _load(name)
		if im == null:
			quit(1)
			return
		var s := _stats(im)
		printerr("  %s before: mean %.3f,%.3f,%.3f  std %.3f,%.3f,%.3f" % [name, s[0].x, s[0].y, s[0].z, s[1].x, s[1].y, s[1].z])
		var w := im.get_width()
		var h := im.get_height()
		for y in range(h):
			for x in range(w):
				var p := im.get_pixel(x, y)
				var r: float = _remap(p.r, s[0].x, s[1].x, rs[0].x, rs[1].x)
				var g: float = _remap(p.g, s[0].y, s[1].y, rs[0].y, rs[1].y)
				var b: float = _remap(p.b, s[0].z, s[1].z, rs[0].z, rs[1].z)
				im.set_pixel(x, y, Color(r, g, b, p.a))
		var after := _stats(im)
		printerr("  %s after:  mean %.3f,%.3f,%.3f  std %.3f,%.3f,%.3f" % [name, after[0].x, after[0].y, after[0].z, after[1].x, after[1].y, after[1].z])
		im.save_png(ProjectSettings.globalize_path("res://art/environment/%s.png" % name))
	quit(0)

func _remap(v: float, m: float, sd: float, rm: float, rsd: float) -> float:
	if sd < 0.0001:
		return clampf(rm, 0.0, 1.0)
	return clampf((v - m) * (rsd / sd) + rm, 0.0, 1.0)

func _load(n: String) -> Image:
	var t: Texture2D = load("res://art/environment/%s.png" % n)
	if t == null:
		printerr("MISSING plate %s" % n)
		return null
	var im := t.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im

# [mean(rgb), std(rgb)]
func _stats(im: Image) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var n := float(w * h)
	var m := Vector3.ZERO
	for y in range(h):
		for x in range(w):
			var p := im.get_pixel(x, y)
			m += Vector3(p.r, p.g, p.b)
	m /= n
	var v := Vector3.ZERO
	for y in range(h):
		for x in range(w):
			var p := im.get_pixel(x, y)
			var d := Vector3(p.r, p.g, p.b) - m
			v += Vector3(d.x * d.x, d.y * d.y, d.z * d.z)
	v /= n
	return [m, Vector3(sqrt(v.x), sqrt(v.y), sqrt(v.z))]
