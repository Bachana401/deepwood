extends Node

const SAVE_PATH = "user://savegame.json"
const BEST_WAVE_PATH = "user://best_wave.dat"

var pending_load = false
var best_wave = 0

func _ready() -> void:
	load_best_wave()

func load_best_wave() -> void:
	if FileAccess.file_exists(BEST_WAVE_PATH):
		var file = FileAccess.open(BEST_WAVE_PATH, FileAccess.READ)
		best_wave = file.get_32()
		file.close()

func record_wave(wave: int) -> void:
	if wave > best_wave:
		best_wave = wave
		var file = FileAccess.open(BEST_WAVE_PATH, FileAccess.WRITE)
		file.store_32(best_wave)
		file.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player: Node) -> void:
	var data = {
		"currency": player.currency,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"owned_weapons": player.owned_weapons,
		"equipped_weapon": player.equipped_weapon,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
