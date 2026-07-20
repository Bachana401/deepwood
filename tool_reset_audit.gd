extends Node

# New-game rewind scan. Every per-run key that save_game() writes must be
# re-initialized inside reset_for_new_game(), or a "New Game" quietly inherits
# a previous life: boons pre-active, story beats already "seen", a finale that
# refuses to fire because harvest_done survived the reset. This exact bug
# class shipped once (the_ten / harvest_done / six seen_* flags) -- this scan
# exists so it can never ship twice.
#
# It reads the source rather than driving a live reset so it can name the
# exact key, and so it runs without a populated game state.
#
# Diagnostic only.

# Keys that live on the PLAYER NODE, not GameState -- a New Game instantiates
# a fresh player scene, so these reset by construction and reset_for_new_game
# never touches them.
const PLAYER_SIDE = [
	"currency", "inventory", "position_x", "position_y", "active_weapon_id",
	"has_dash", "has_double_jump", "health", "mana",
]

# Deliberate carriers, each with a reason. Keep this list SHORT and argued --
# an entry here is a design decision, not an escape hatch.
const ALLOWED = {
	# chosen by the New Game difficulty picker itself, immediately after reset
	"difficulty": "set by the difficulty picker as part of the new-game flow",
}

var issues := 0
func note(msg: String) -> void:
	issues += 1
	printerr("  " + msg)

func _ready() -> void:
	await get_tree().process_frame
	var gs := _read("res://game_state.gd")

	var save_body := _slice(gs, "func save_game(")
	var reset_body := _slice(gs, "func reset_for_new_game(")
	if save_body == "" or reset_body == "":
		note("could not slice save_game/reset_for_new_game out of game_state.gd")

	var written := []
	var re := RegEx.new()
	re.compile("\"([a-z_0-9]+)\":")
	for m in re.search_all(save_body):
		var k: String = m.get_string(1)
		if not written.has(k):
			written.append(k)

	for k in written:
		if PLAYER_SIDE.has(k):
			continue
		if ALLOWED.has(k):
			continue
		# an assignment anywhere in the reset body counts -- `x = []`,
		# `x = {}`, `x = 0.0`, or a rebuild via `x = whatever()`
		var assign := RegEx.new()
		assign.compile("(^|\\n)\\t+" + k + "\\s*=[^=]")
		if assign.search(reset_body) == null:
			note("saved key '%s' is never re-initialized in reset_for_new_game() -- it will leak into every fresh run" % k)

	print("== TOTAL RESET GAPS: %d ==" % issues)
	get_tree().quit(1 if issues > 0 else 0)

func _slice(src: String, header: String) -> String:
	var start := src.find(header)
	if start < 0:
		return ""
	var nxt := src.find("\nfunc ", start + header.length())
	return src.substr(start, (nxt - start) if nxt > 0 else -1)

func _read(path: String) -> String:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return ""
	var s := fh.get_as_text()
	fh.close()
	return s
