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

func exit_dungeon() -> void:
	pass
