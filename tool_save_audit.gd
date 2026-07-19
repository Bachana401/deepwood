extends Node

# Save round-trip scan. Every key save_game() writes must be read back somewhere
# on load, or that slice of progress is silently lost between sessions -- the
# quietest possible bug, because everything looks fine until you reload and
# something you earned is gone.
#
# It reads the source rather than round-tripping a live save so it can name the
# exact key, and so it runs without a populated game state.
#
# Diagnostic only.

var issues := 0
func note(msg: String) -> void:
	issues += 1
	printerr("  " + msg)

func _ready() -> void:
	await get_tree().process_frame
	var gs := _read("res://game_state.gd")
	var mn := _read("res://main.gd")
	var consumers := gs + "\n" + mn

	# pull the keys written inside save_game()'s data dictionary
	var save_body := _slice(gs, "func save_game(")
	var written := []
	var re := RegEx.new()
	re.compile("\"([a-z_0-9]+)\":")
	for m in re.search_all(save_body):
		written.append(m.get_string(1))

	printerr("== save_game writes %d keys ==" % written.size())
	printerr("\n== keys saved but never read back (silent progress loss) ==")
	for key in written:
		# a key is "read" if anything fetches it: parsed.get("key"),
		# data.get("key"), or ["key"] indexing on load
		if consumers.contains('get("%s"' % key) or consumers.contains('["%s"]' % key):
			continue
		note("'%s' is written by save_game but nothing reads it on load" % key)

	# the reverse: a load default that names a key never saved is dead too, but
	# that's cosmetic -- the real damage is only in the direction above.
	printerr("\n== TOTAL SAVE GAPS: %d ==" % issues)
	get_tree().quit(0)

func _slice(src: String, marker: String) -> String:
	var start := src.find(marker)
	if start == -1:
		return ""
	# to the next top-level "func " after the marker
	var next := src.find("\nfunc ", start + marker.length())
	return src.substr(start, (next - start) if next != -1 else -1)

func _read(path: String) -> String:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return ""
	var s := fh.get_as_text()
	fh.close()
	return s
