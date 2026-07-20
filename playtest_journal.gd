extends CanvasLayer

# THE FIELD JOURNAL (built for the 4-5h marathon playtest, 2026-07-21).
#
# The dev's plan: play all day and "write down all problems and issues."
# Nobody should alt-tab out of a bug to write it down -- half the report
# is WHERE and WHEN it happened, and that half the game already knows.
# Press F8 anywhere (village, dungeon, arenas, even paused), type the
# problem, Enter. The note lands in PLAYTEST_NOTES.md in the project
# folder, stamped with scene, position, floor, level, gold, clock,
# roster, morale and fps -- the questions I would have to ask later,
# answered automatically at the moment of the sighting.

const NOTES_PATH := "res://PLAYTEST_NOTES.md"

var panel: Panel = null
var input: LineEdit = null
var hint: Label = null

func _ready() -> void:
	layer = 90                      # above every other UI, incl. pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("playtest_journal")
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(200, 220)
	panel.size = Vector2(760, 92)
	add_child(panel)
	var title := Label.new()
	title.text = "🐞 FIELD NOTE  —  Enter saves it (with where/when attached), Esc drops it"
	title.add_theme_font_size_override("font_size", 13)
	title.position = Vector2(14, 8)
	panel.add_child(title)
	input = LineEdit.new()
	input.position = Vector2(14, 34)
	input.size = Vector2(732, 40)
	input.placeholder_text = "what went wrong / felt wrong?"
	input.text_submitted.connect(_on_submit)
	panel.add_child(input)
	hint = Label.new()
	hint.visible = false
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	hint.position = Vector2(14, 76)
	panel.add_child(hint)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel.visible:
			panel.visible = false
			get_viewport().set_input_as_handled()

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		input.text = ""
		hint.visible = false
		input.grab_focus()

func _on_submit(text: String) -> void:
	if text.strip_edges() == "":
		panel.visible = false
		return
	_append_note(text.strip_edges())
	hint.text = "noted ✓"
	hint.visible = true
	input.text = ""
	# stay open a beat so "noted" is seen, then close on a short timer
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func(): panel.visible = false)

func _context_stamp() -> String:
	var p = get_tree().get_first_node_in_group("player")
	var scene := "?"
	if get_tree().current_scene != null:
		scene = str(get_tree().current_scene.scene_file_path.get_file())
	var where := "no player"
	if p != null:
		where = "x=%d y=%d" % [int(p.global_position.x), int(p.global_position.y)]
	var floor_s := "village"
	if GameState.in_dungeon:
		floor_s = "floor %d" % GameState.active_dungeon_level
	return "%s | %s | %s | Lv%d %dhp | %dg | day %d %02d:00 | %d souls, morale %d | %d fps" % [
		scene, floor_s, where,
		GameState.player_level,
		int(p.health) if p != null and "health" in p else -1,
		p.currency if p != null and "currency" in p else -1,
		int(GameState.game_hours / 24.0) + 1, int(GameState.game_hours) % 24,
		GameState.rescued_villagers.size(), GameState.village_morale(),
		int(Engine.get_frames_per_second())]

func _append_note(text: String) -> void:
	var line := "- **%s** — %s\n  - `%s`\n" % [
		Time.get_datetime_string_from_system().replace("T", " "), text, _context_stamp()]
	var existing := ""
	if FileAccess.file_exists(NOTES_PATH):
		var rf := FileAccess.open(NOTES_PATH, FileAccess.READ)
		existing = rf.get_as_text()
	else:
		existing = "# Playtest notes\n\nPress F8 in game, type the problem, Enter. Context attaches itself.\n\n"
	var wf := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(existing + line)
