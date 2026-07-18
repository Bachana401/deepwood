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
		# P always opens the console (dev request: instant visual testing of
		# upgrades without relaunching with --dev)
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
		var on: bool = pl != null and pl.god_mode
		god_button.text = "GOD MODE: %s" % ("ON" if on else "OFF")
		# green while it's live -- easy to see at a glance that you're not
		# testing the real difficulty
		god_button.add_theme_color_override("font_color",
			Color(0.5, 1.0, 0.55) if on else Color(1, 1, 1))

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
	panel.offset_top = -334.0
	panel.offset_bottom = 334.0
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
	god_button = _btn("GOD MODE: OFF", PAD, y, 150, BH, _toggle_god)
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

	# --- Shadow Monarch (jump character level to each 1..7 stage to see the aura) ---
	y = _section("SHADOW MONARCH  (set stage / level)", y)
	var sx = PAD
	for spec in [["1", 5], ["2", 15], ["3", 30], ["4", 45], ["5", 60], ["6", 80], ["7", 100]]:
		var lvl = spec[1]
		_btn(spec[0], sx, y, 38.0, BH, func(): _set_level(lvl))
		sx += 38.0 + GAP
	y += BH + GAP
	_btn("Reset to Lv 1 (no aura)", PAD, y, 200, BH, func(): _set_level(1))
	_btn("TRUE FORM", PAD + 200 + GAP, y, 106, BH, _toggle_true_form)
	y += BH + 12.0

	# --- Buildings (set every building's level instantly to eyeball upgrades) ---
	y = _section("BUILDINGS  (instant level, visual test)", y)
	_btn("All +1", PAD, y, 92, BH, func(): _buildings_level(1))
	_btn("All MAX", PAD + 92 + GAP, y, 92, BH, func(): _buildings_level(99))
	_btn("All Lv 1", PAD + (92 + GAP) * 2.0, y, 92, BH, func(): _buildings_level(0))
	y += BH + 12.0

	# --- Test arena ---
	y = _section("TEST ARENA", y)
	_btn("PROVING GROUNDS  (all items in chests + DPS dummy)", PAD, y, W - PAD * 2.0, BH, _enter_proving_grounds)
	y += BH + 12.0

	_btn("Close (P)", PAD, y, W - PAD * 2.0, BH, close)

# Enter the Proving Grounds: a flat test arena (dungeon_interior in a special
# mode) with every item in labelled rarity chests and an invincible DPS dummy.
func _enter_proving_grounds() -> void:
	GameState.proving_grounds = true
	GameState.active_dungeon_level = 1
	var pl = _player()
	if pl:
		GameState.pending_player_state = GameState.capture_player_state(pl)
		# remember where to drop the player back in the village -- without this
		# the exit falls back to pre_dungeon_position's default (0,0), which is
		# below the village ground line (GROUND_Y = -39) so you'd spawn embedded
		# in the floor and fall through. (matches level_select_ui's entry.)
		GameState.pre_dungeon_position = pl.global_position
	close()
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")

# Instantly set every live building's level (no gold cost, clamped to
# MAX_LEVEL) and rebuild its geometry so upgrades can be eyeballed on the
# spot. 1 = +1 level, 99 = jump to max, 0 = back to level 1.
func _buildings_level(mode: int) -> void:
	var n := 0
	for b in get_tree().get_nodes_in_group("building"):
		if not ("building_level" in b):
			continue
		# finish construction first -- the honest start leaves most buildings
		# as ruins, and levels/facades only show on FINISHED buildings
		b.build_stage = GameState.TOTAL_BUILD_STAGES
		GameState.building_stage[b.building_name] = b.build_stage
		b.constructing = false
		b.health = b.MAX_HEALTH
		GameState.building_health[b.building_name] = b.health
		var target: int = b.building_level + 1 if mode == 1 else (b.MAX_LEVEL if mode == 99 else 1)
		target = clampi(target, 1, b.MAX_LEVEL)
		b.building_level = target
		GameState.building_levels[b.building_name] = target
		b.current_state = b.compute_visual_state()
		b.rebuild_geometry()
		n += 1
	_notify("Admin: %d buildings finished -> %s" % [n, ("+1 level" if mode == 1 else ("MAX" if mode == 99 else "level 1"))])

# 7/7's full god-form normally waits for the finale (no villagers left alive);
# forcing it lets the 2x form + novas + permanent shades be eyeballed any time.
func _toggle_true_form() -> void:
	GameState.monarch_true_form_forced = not GameState.monarch_true_form_forced
	if GameState.monarch_true_form_forced and GameState.player_level < 100:
		_set_level(100)
	_notify("Admin: Shadow Monarch true form %s" % ("FORCED ON" if GameState.monarch_true_form_forced else "off (finale-gated)"))

# Jump the character level so a stage's aura/pallor/power shows instantly.
func _set_level(lvl: int) -> void:
	GameState.player_level = lvl
	GameState.player_xp = 0
	GameState.skill_points = max(GameState.skill_points, lvl - 1)
	GameState.announce_monarch_awakening()
	var pl = _player()
	if pl and pl.has_method("update_health_display"):
		pl.update_health_display()   # max HP may scale with level
	_notify("Admin: level %d  ->  Shadow Monarch %d/7" % [lvl, GameState.monarch_stage()])

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

# One switch for roaming the map: untouchable, T blink-dash without needing the
# Shadowstep Sigil, and unlimited flight without needing the Aetherwing.
func _toggle_god() -> void:
	var pl = _player()
	if pl == null:
		return
	pl.god_mode = not pl.god_mode
	if pl.god_mode:
		pl.mana = pl.get_max_mana()   # start airborne-ready (levitation burns mana)
		_notify("GOD MODE ON — invincible · T = super dash · hold Space = fly")
	else:
		_notify("GOD MODE OFF — mortal again")
	refresh()

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
