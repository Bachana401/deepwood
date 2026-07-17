extends SceneTree

# Cuts a background plate down to its usable band (drops any baked ground the
# game draws itself) and writes it as a new plate.
# usage: -- <src-name> <dst-name> <keep-rows>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		printerr("usage: -- <src> <dst> <keep-rows>")
		quit(1)
		return
	var t: Texture2D = load("res://art/environment/%s.png" % a[0])
	if t == null:
		printerr("cannot load %s" % a[0])
		quit(1)
		return
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var keep := int(a[2])
	var w := img.get_width()
	keep = mini(keep, img.get_height())
	var out := Image.create(w, keep, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, w, keep), Vector2i.ZERO)
	var dst := ProjectSettings.globalize_path("res://art/environment/%s.png" % a[1])
	var err := out.save_png(dst)
	printerr("cut %s (%dx%d) -> %s (%dx%d) err=%d" % [a[0], w, img.get_height(), a[1], w, keep, err])
	quit(0)
