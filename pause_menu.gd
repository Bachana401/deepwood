extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# discoverable by DialogueBox.finish(): a beat that ends under an open pause
	# menu must leave the tree paused (the menu owns it), not blind-unpause
	add_to_group("pause_menu")
	visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/ExitDungeonButton.pressed.connect(_on_exit_dungeon)
	$Panel/VBox/SettingsButton.pressed.connect(_on_toggle_settings)
	$Panel/VBox/QuitMenuButton.pressed.connect(_on_quit_to_menu)
	$Panel/VBox/QuitGameButton.pressed.connect(_on_quit_game)
	$Panel/SettingsPanel.visible = false
	_build_chronicle()
	$Panel/SettingsPanel/VolumeSlider.value = GameState.master_volume
	$Panel/SettingsPanel/VolumeSlider.value_changed.connect(_on_volume_changed)
	if $Panel/SettingsPanel.has_node("MusicSlider"):
		$Panel/SettingsPanel/MusicSlider.value = GameState.music_volume
		$Panel/SettingsPanel/MusicSlider.value_changed.connect(_on_music_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ESC first dismisses any open game window (inventory, gear, chest, skill
		# tree, a building panel, the shop). Only when nothing is open -- or the
		# pause menu itself is up -- does it toggle pause.
		# Even when the pause menu itself is up, a How-to-Play / roster page opened OVER it
		# (their own CanvasLayers, in esc_window) must close FIRST -- else ESC unpauses and
		# strands the page over the now-live game. Sweep windows before toggling pause.
		if close_open_windows():
			get_viewport().set_input_as_handled()
			return
		toggle_pause()
		get_viewport().set_input_as_handled()

# Closes every window that reports itself open (see the esc_window group). Any
# window can opt in by joining that group and exposing esc_is_open/esc_close.
func close_open_windows() -> bool:
	var closed := false
	for w in get_tree().get_nodes_in_group("esc_window"):
		if w.has_method("esc_is_open") and w.esc_is_open():
			w.esc_close()
			closed = true
	return closed

# The "dungeon manager" node differs by scene: in the village (main.tscn) it's
# a sibling child literally named "DungeonManager"; inside a dungeon run
# (dungeon_interior.tscn) the SCENE ROOT itself is the manager and PauseMenu is
# its child, so "../DungeonManager" resolves to nothing. Resolve both here
# instead of hard-coding a path -- the old "../DungeonManager" was null in the
# dungeon, so opening the pause menu there hit a null and never worked.
func dungeon_manager() -> Node:
	var m = get_node_or_null("../DungeonManager")
	if m:
		return m
	var parent = get_parent()   # dungeon interior: the root IS the manager
	if parent and parent.has_method("exit_dungeon"):
		return parent
	return null

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		var dm = dungeon_manager()
		$Panel/VBox/ExitDungeonButton.visible = dm != null and dm.started
		$Panel/SettingsPanel.visible = false
		if chron_panel:
			chron_panel.visible = false

func _on_resume() -> void:
	toggle_pause()

func _on_exit_dungeon() -> void:
	var dm = dungeon_manager()
	if dm:
		dm.exit_dungeon()
	toggle_pause()

func _on_toggle_settings() -> void:
	$Panel/SettingsPanel.visible = not $Panel/SettingsPanel.visible
	if chron_panel and $Panel/SettingsPanel.visible:
		chron_panel.visible = false

# --- THE CHRONICLE (GAME_BIBLE 11): the run's 100% ledger ---
# Seven canon lines in one book, readable any time from pause. Built in code
# so both scenes that embed this menu (village and dungeon) get it for free.
var chron_panel: Panel = null
var chron_rows: VBoxContainer = null

func _build_chronicle() -> void:
	# How to Play rides beside the Chronicle: the game grew deep, and toasts
	# alone can't teach fog, watches, wages, rot and rifts
	var help := Button.new()
	help.name = "HowToPlayButton"
	help.text = "How to Play"
	help.custom_minimum_size = Vector2(0, 36)
	var vbox0 = $Panel/VBox
	vbox0.add_child(help)
	vbox0.move_child(help, $Panel/VBox/SettingsButton.get_index() + 1)
	help.pressed.connect(func():
		var page = get_tree().get_first_node_in_group("how_to_play")
		if page == null:
			page = preload("res://how_to_play.gd").new()
			get_tree().root.add_child(page)
		page.open_page())
	# The Roster: every soul on one page, sorted by who needs you most
	var roster := Button.new()
	roster.name = "RosterButton"
	roster.text = "The People"
	roster.custom_minimum_size = Vector2(0, 36)
	vbox0.add_child(roster)
	vbox0.move_child(roster, $Panel/VBox/SettingsButton.get_index() + 2)
	roster.pressed.connect(func():
		var page = get_tree().get_first_node_in_group("roster_ui")
		if page == null:
			page = preload("res://roster_ui.gd").new()
			get_tree().root.add_child(page)
		page.open_page())
	var btn := Button.new()
	btn.name = "ChronicleButton"
	btn.text = "Chronicle"
	btn.custom_minimum_size = Vector2(0, 36)
	var vbox = $Panel/VBox
	vbox.add_child(btn)
	vbox.move_child(btn, $Panel/VBox/SettingsButton.get_index() + 3)
	btn.pressed.connect(_on_toggle_chronicle)
	chron_panel = Panel.new()
	chron_panel.name = "ChroniclePanel"
	chron_panel.visible = false
	chron_panel.size = Vector2(520, 360)
	$Panel.add_child(chron_panel)
	# THE BOOK RAN OFF THE SCREEN. It used to hang at a fixed +290 from the
	# pause panel's left edge -- which fitted only while that panel sat at
	# x=340. Re-centring the pause menu (it was centred on 480, half of a
	# viewport this game stopped using) pushed the Chronicle's right edge to
	# 1246 in a 1152-wide UI, and the seventh line's text was cut off mid-word.
	# Derive its place from the SCREEN, so moving the menu can never shove the
	# book off the edge again.
	var ui_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var ui_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	chron_panel.position = Vector2(
		(ui_w - chron_panel.size.x) / 2.0 - $Panel.offset_left,
		(ui_h - chron_panel.size.y) / 2.0 - $Panel.offset_top)
	var title := Label.new()
	title.text = "THE CHRONICLE OF DEEPWOOD"
	title.add_theme_font_size_override("font_size", 18)
	title.position = Vector2(16, 10)
	chron_panel.add_child(title)
	chron_rows = VBoxContainer.new()
	chron_rows.position = Vector2(16, 44)
	chron_rows.custom_minimum_size = Vector2(488, 0)
	chron_rows.add_theme_constant_override("separation", 8)
	chron_panel.add_child(chron_rows)

func _on_toggle_chronicle() -> void:
	chron_panel.visible = not chron_panel.visible
	$Panel/SettingsPanel.visible = false
	if not chron_panel.visible:
		return
	GameState.chronicle_check_complete()
	for c in chron_rows.get_children():
		c.queue_free()
	var entries: Array = GameState.chronicle()
	var done_count := 0
	for e in entries:
		var done: bool = bool(e.get("done", false))
		if done:
			done_count += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var mark := Label.new()
		mark.text = "✔" if done else "—"
		mark.add_theme_color_override("font_color",
			Color(0.45, 0.9, 0.45, 1.0) if done else Color(0.55, 0.5, 0.45, 1.0))
		mark.custom_minimum_size = Vector2(18, 0)
		row.add_child(mark)
		var line := Label.new()
		line.text = str(e.get("line", ""))
		if not done:
			line.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 1.0))
		row.add_child(line)
		var detail := Label.new()
		detail.text = "  " + str(e.get("detail", ""))
		detail.add_theme_font_size_override("font_size", 12)
		detail.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
		row.add_child(detail)
		chron_rows.add_child(row)
	var footer := Label.new()
	if done_count < entries.size():
		footer.text = "%d / %d — the book closes at 100%%" % [done_count, entries.size()]
	else:
		footer.text = "★ 100% — the book is closed. Deepwood will remember."
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color",
		Color(0.95, 0.85, 0.4, 1.0) if done_count == entries.size() else Color(0.7, 0.68, 0.62, 1.0))
	chron_rows.add_child(footer)

	# --- THE HIDDEN HUNT (2026-07-28): a record of the secret bosses. A slain
	# one reveals its name AND the deed that woke it; the rest stay "???". ---
	var hunt: Array = GameState.hidden_hunt_entries()
	var slain: int = GameState.hidden_hunt_slain_count()
	var sub := Label.new()
	sub.text = "— THE HIDDEN HUNT —   %d / %d" % [slain, hunt.size()]
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.85, 0.6, 0.85, 1.0))
	chron_rows.add_child(sub)
	for e in hunt:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var killed: bool = bool(e.get("killed", false))
		var mark := Label.new()
		mark.text = "☠" if killed else "?"
		mark.add_theme_color_override("font_color",
			Color(0.9, 0.55, 0.5, 1.0) if killed else Color(0.5, 0.46, 0.5, 1.0))
		mark.custom_minimum_size = Vector2(18, 0)
		row.add_child(mark)
		var nm := Label.new()
		nm.text = str(e.get("name", "???"))
		if bool(e.get("capstone", false)) and killed:
			nm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		elif not killed:
			nm.add_theme_color_override("font_color", Color(0.6, 0.56, 0.6, 1.0))
		nm.custom_minimum_size = Vector2(200, 0)
		row.add_child(nm)
		var how := Label.new()
		how.text = str(e.get("hint", ""))
		how.add_theme_font_size_override("font_size", 12)
		how.add_theme_color_override("font_color",
			Color(0.7, 0.66, 0.6, 1.0) if killed else Color(0.5, 0.48, 0.52, 1.0))
		row.add_child(how)
		chron_rows.add_child(row)

func _on_volume_changed(value: float) -> void:
	GameState.set_master_volume(value)

func _on_music_changed(value: float) -> void:
	GameState.set_music_volume(value)

func _on_quit_to_menu() -> void:
	get_tree().paused = false
	GameState.save_game($"../Player")
	# quitting skips exit_dungeon(), the only other place this unlatches --
	# left hot, the next real floor after Continue built the admin test arena
	# instead of the dungeon (audit fix; in_dungeon is repaired on load already)
	GameState.proving_grounds = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_game() -> void:
	get_tree().paused = false
	GameState.save_game($"../Player")
	GameState.proving_grounds = false
	get_tree().quit()
