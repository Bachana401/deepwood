extends CanvasLayer

# One-stop dev/testing console, toggled with P. Every "OP" testing action lives
# here as a clickable button instead of a scattered hotkey: morale nudges,
# build-all, populate, god mode, kill, heal, gold, time-skips, level unlock.
# (The T super-dash stays a movement key; G still places a torch.)

var panel: Panel
var morale_label: Label
var god_button: Button

const W := 340.0
const PAD := 14.0
const BW := 44.0    # small button width
const BH := 26.0
const GAP := 6.0

func _ready() -> void:
	layer = 70
	add_to_group("esc_window")
	_build()
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("admin_panel"):
		panel.visible = not panel.visible
		if panel.visible:
			refresh()
		get_viewport().set_input_as_handled()

func close() -> void:   # lets ESC/esc_window logic hide it too
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible:
		refresh()

func refresh() -> void:
	if morale_label:
		morale_label.text = "Morale: %.1f / 10   (nudge %+d)" % [GameState.village_morale_10(), GameState.morale_admin_offset / 10]
	if god_button:
		var pl = _player()
		god_button.text = "Invincibility: %s" % ("ON" if (pl and pl.god_mode) else "OFF")

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _notify(msg: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification(msg)

# --- layout ---
func _build() -> void:
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -W / 2.0
	panel.offset_right = W / 2.0
	panel.offset_top = -230.0
	panel.offset_bottom = 230.0
	add_child(panel)

	var title = Label.new()
	title.position = Vector2(PAD, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.text = "ADMIN CONTROL PANEL  (P)"
	panel.add_child(title)

	var y = 46.0
	# --- Morale ---
	y = _section("MORALE", y)
	morale_label = _text("Morale: -", y)
	y += 24.0
	# row of nudge buttons: -10 -2 -1 +1 +2 +10
	var mx = PAD
	for spec in [["-10", -10], ["-2", -2], ["-1", -1], ["+1", 1], ["+2", 2], ["+10", 10]]:
		var tenths = spec[1]
		_btn(spec[0], mx, y, BW, BH, func(): GameState.admin_nudge_morale(tenths))
		mx += BW + GAP
	y += BH + GAP
	_btn("Reset morale nudge", PAD, y, 160, BH, func(): GameState.morale_admin_offset = 0)
	y += BH + 10.0

	# --- Village ---
	y = _section("VILLAGE", y)
	_btn("Build ALL buildings", PAD, y, 160, BH, _build_all)
	_btn("Populate village", PAD + 166, y, 150, BH, func():
		GameState.test_populate_village()
		_notify("Admin: village populated."))
	y += BH + 10.0

	# --- Player ---
	y = _section("PLAYER", y)
	god_button = _btn("Invincibility: OFF", PAD, y, 150, BH, _toggle_god)
	_btn("Kill player", PAD + 156, y, 160, BH, func():
		var pl = _player()
		if pl:
			pl.god_mode = false
			pl.die())
	y += BH + GAP
	_btn("Full heal + mana", PAD, y, 150, BH, _full_heal)
	_btn("+500 gold", PAD + 156, y, 160, BH, func():
		var pl = _player()
		if pl and pl.has_method("add_currency"):
			pl.add_currency(500))
	y += BH + 10.0

	# --- World ---
	y = _section("WORLD / TIME", y)
	var tx = PAD
	for spec in [["-1 Day", -24.0], ["-1 Hr", -1.0], ["+1 Hr", 1.0], ["+1 Day", 24.0]]:
		var hrs = spec[1]
		_btn(spec[0], tx, y, 74, BH, func(): _skip_time(hrs))
		tx += 74 + GAP
	y += BH + GAP
	_btn("Unlock ALL dungeon levels", PAD, y, 220, BH, func():
		GameState.highest_unlocked_level = 999
		_notify("Admin: all dungeon levels unlocked."))
	y += BH + 12.0

	_btn("Close (P)", PAD, y, W - PAD * 2.0, BH, close)

func _section(name: String, y: float) -> float:
	var l = Label.new()
	l.position = Vector2(PAD, y)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	l.text = "— " + name + " —"
	panel.add_child(l)
	return y + 22.0

func _text(txt: String, y: float) -> Label:
	var l = Label.new()
	l.position = Vector2(PAD, y)
	l.add_theme_font_size_override("font_size", 13)
	l.text = txt
	panel.add_child(l)
	return l

func _btn(txt: String, x: float, y: float, w: float, h: float, cb: Callable) -> Button:
	var b = Button.new()
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE   # keep TAB/keys free
	b.pressed.connect(cb)
	panel.add_child(b)
	return b

# --- actions ---
func _build_all() -> void:
	GameState.restore_all_buildings()
	for b in get_tree().get_nodes_in_group("building"):
		if b.has_method("restore_full"):
			b.restore_full()
	_notify("Admin: all buildings restored.")

func _toggle_god() -> void:
	var pl = _player()
	if pl:
		pl.god_mode = not pl.god_mode
		_notify("Admin: Invincibility %s." % ("ON" if pl.god_mode else "OFF"))

func _full_heal() -> void:
	var pl = _player()
	if pl == null:
		return
	pl.health = pl.get_max_health()
	pl.mana = pl.get_max_mana()
	if pl.has_method("update_health_display"):
		pl.update_health_display()
	if pl.has_method("update_mana_display"):
		pl.update_mana_display()

func _skip_time(hours: float) -> void:
	GameState.skip_hours(hours)
	var dn = get_tree().get_first_node_in_group("day_night_cycle")
	if dn and dn.has_method("pick_new_moon_phase"):
		dn.pick_new_moon_phase()
