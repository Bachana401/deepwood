extends SceneTree

# Sweeps EVERY png the game actually loads and flags the things that have
# bitten us before:
#   BACKDROP  - no transparent pixels at all -> a baked background never stripped
#   OPAQUE-BORDER - the canvas edge is solid -> backdrop, or art running off frame
#   EMPTY     - nothing but transparency
#   TINY      - content is a speck (a failed/blank generation)
# Skips the third-party asset packs, which are not ours to fix.

const SKIP := ["Tiny RPG Character Asset Pack", "backup_leonardo"]

func _initialize() -> void:
	var files: Array = []
	_walk("res://art", files)
	files.sort()
	var bad := 0
	var checked := 0
	for f in files:
		var skip := false
		for s in SKIP:
			if f.contains(s):
				skip = true
		if skip:
			continue
		checked += 1
		var issue := _check(f)
		if issue != "":
			bad += 1
			printerr("%-9s %s" % [issue, f.replace("res://art/", "")])
	printerr("--- swept %d project pngs, %d flagged ---" % [checked, bad])
	quit()

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(p, out)
		elif n.ends_with(".png"):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()

func _check(path: String) -> String:
	var t: Texture2D = load(path)
	if t == null:
		return "LOADFAIL"
	var img := t.get_image()
	if img == null:
		return "LOADFAIL"
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return "EMPTY"
	var used := img.get_used_rect()
	if used.size.x <= 0:
		return "EMPTY"
	# a speck of content on a big canvas = a dud generation
	if float(used.size.x * used.size.y) / float(w * h) < 0.01:
		return "TINY"
	# fully opaque canvas -> the backdrop was never stripped
	var transparent := 0
	var step: int = maxi(1, int(mini(w, h) / 24))
	for y in range(0, h, step):
		for x in range(0, w, step):
			if img.get_pixel(x, y).a < 0.5:
				transparent += 1
	if transparent == 0:
		return "BACKDROP"
	# every border pixel opaque -> backdrop, or the art runs off the canvas
	var border_opaque := true
	for x in range(0, w, maxi(1, w / 32)):
		if img.get_pixel(x, 0).a < 0.5 or img.get_pixel(x, h - 1).a < 0.5:
			border_opaque = false
			break
	if border_opaque:
		for y in range(0, h, maxi(1, h / 32)):
			if img.get_pixel(0, y).a < 0.5 or img.get_pixel(w - 1, y).a < 0.5:
				border_opaque = false
				break
	if border_opaque:
		return "BORDER"
	return ""
