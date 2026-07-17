extends SceneTree

# The hooded hero's whole point is that his face is NOT there. This measures it
# rather than trusting a glance: for every frame, count SKIN-coloured pixels in
# the head region (the top third of the figure). A hood with a face painted in
# it lights this up (40-70px); a proper lightless cowl scores 0.
#
# It is a TRIAGE tool, not a verdict: hands are skin too, so a pose that puts a
# fist up near the head (the fall's horizontal frames) scores ~15-20 without
# anything being wrong. Anything it flags still gets looked at on a contact
# sheet -- a real face is unmistakable next to a raised fist.
# usage: -- <dir> <prefix> <count>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var prefix: String = a[1]
	var n: int = int(a[2])
	var worst := 0
	for i in range(1, n + 1):
		var p := "res://%s/%s_%d.png" % [dir, prefix, i]
		var t: Texture2D = load(p)
		if t == null:
			printerr("missing ", p)
			continue
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var c := img.get_used_rect()
		if c.size.y <= 0:
			continue
		# head band = top 34% of the figure's own content box
		var band := int(c.size.y * 0.34)
		var skin := 0
		for y in range(band):
			for x in range(int(c.size.x)):
				var col: Color = img.get_pixelv(c.position + Vector2i(x, y))
				if col.a < 0.5:
					continue
				# pale skin: bright, warm, red>green>blue, low saturation gap
				if col.r > 0.65 and col.g > 0.45 and col.b > 0.4 and col.r > col.b and (col.r - col.b) < 0.45 and col.g > col.b * 0.95:
					skin += 1
		worst = maxi(worst, skin)
		printerr("  %s_%d: %d skin px in head band%s" % [prefix, i, skin, "   <-- FACE!" if skin > 6 else ""])
	printerr("%s: worst frame %d skin px -> %s" % [prefix, worst, "VOID OK" if worst <= 6 else "*** FACE VISIBLE ***"])
	quit(0 if worst <= 6 else 1)
