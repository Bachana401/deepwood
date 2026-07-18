extends Node

# Dungeon combat now happens in a fully separate scene (dungeon_interior.gd)
# reached via a real scene transition -- see level_select_ui.gd. Nothing runs
# an active dungeon session while standing in the village, so `started` stays
# false here; this node exists only so pause_menu.gd's shared
# `$"../DungeonManager"` lookup still resolves the same way in both scenes
# (dungeon_interior.tscn's own root plays the same role there, with
# started == true and a real exit_dungeon() -- see that script).
var started = false
var starting = false

# Deliberately empty: in the village there is no dungeon session to leave. This
# stub exists only so pause_menu's shared "../DungeonManager" lookup resolves in
# BOTH scenes -- inside a dungeon the interior's own root answers this call with
# the real implementation.
func exit_dungeon() -> void:
	pass
