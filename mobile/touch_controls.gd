extends CanvasLayer
# ============================================================================
# DEEPWOOD MOBILE TOUCH LAYER v3 (autoload "TouchControls", 2026-07-28)
#
# ADDITIVE BY CONTRACT: on desktop without a force flag this deactivates
# itself in _ready and the game is byte-for-byte the PC experience. Active on
# any OS.has_feature("mobile") device, or forced with `--touch` after `--`
# on the command line / env DEEPWOOD_TOUCH=1 (for testing on the PC).
#
# v2 -> v3: the overlay is built from REAL NODES (Panel + Label) and the
# layout math is fixed. ⚠ THE LESSON: on DESKTOP, DisplayServer.
# get_display_safe_area() returns the MONITOR's work area, not the window --
# naive inset math goes hugely negative and quietly places every control
# off-screen (cost a whole false "rendering bug" hunt). Safe-area insets are
# therefore computed ONLY on mobile and clamped >= 0.
#
# v2 design (kept): parse_input_event(InputEventAction) injection so BOTH
# polled readers (player.gd) and event readers (menu UIs) hear the actions;
# NO touch-anywhere-attack (dev veto) -- dedicated ATTACK button + auto-aim
# via aim_point_for(); word labels in the game font; first-launch help
# overlay ("?" reopens); combat cluster hides while an esc_window panel is
# open and a CLOSE (ui_cancel) button appears instead.
#
# Buttons are hand-hit-tested in _input from raw InputEventScreenTouch/Drag,
# NOT Control Buttons: Godot only mouse-emulates the FIRST finger, so a
# Control never hears a second finger. First-finger mouse emulation is left
# untouched so the game's own panels/hotbar receive normal taps.
# process_mode ALWAYS: story dialogs pause the tree and still read input.
# ============================================================================

const GAME_FONT := preload("res://art/fonts/PixelifySans.ttf")

const STICK_ZONE_X := 0.40          # left fraction of screen that spawns the stick
const DEADZONE := 0.30              # of stick radius, before a move action fires
const AIM_RANGE := 620.0            # auto-aim search radius
const FACING_BONUS := 220.0         # distance discount for enemies on the facing side

const COL_BOX := Color(0.07, 0.08, 0.11, 0.55)
const COL_BOX_HELD := Color(0.32, 0.28, 0.12, 0.85)
const COL_EDGE := Color(1, 1, 1, 0.55)
const COL_TXT := Color(1, 1, 1, 0.92)

var active := false                 # the ONE flag the rest of the game may read

var _touches := {}                  # touch index -> {"kind": ..., "name": ...}
var _stick_origin := Vector2.ZERO
var _stick_rest := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _stick_down := false
var _move_dir := 0
var _held := {}
var _pending_release: Array[String] = []
var _extended := false
var _esc_open := false
var _esc_poll := 0.0
var _buttons := {}                  # name -> {rect, action, label, hold, group, node}
var _ui: Control                    # root of all overlay nodes
var _stick_ghost: Control
var _stick_base: Panel
var _stick_knob: Panel
var _help: Control

func _ready() -> void:
	var forced := ("--touch" in OS.get_cmdline_user_args()) \
		or OS.get_environment("DEEPWOOD_TOUCH") == "1"
	active = OS.has_feature("mobile") or forced
	printerr("TouchControls: active=%s (mobile=%s)" % [active, OS.has_feature("mobile")])
	if not active:
		set_process_input(false)
		set_process(false)
		return
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.name = "TouchUI"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var cfg := ConfigFile.new()
	cfg.load("user://touch_prefs.cfg")
	if not cfg.get_value("help", "seen", false):
		_set_help(true)

# --- node factory -----------------------------------------------------------

func _box_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 0        # hard pixel corners on purpose
	return sb

func _make_box(rect: Rect2, label: String, fs: int, edge: Color = COL_EDGE) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _box_style(COL_BOX, edge))
	if label != "":
		var l := Label.new()
		l.text = label
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.add_theme_font_override("font", GAME_FONT)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", COL_TXT)
		p.add_child(l)
	_ui.add_child(p)
	return p

func _btn(name: String, rect: Rect2, action: String, label: String, hold: bool, group: String) -> void:
	var fs := int(rect.size.y * (0.40 if label.length() > 2 else 0.52))
	var edge := COL_EDGE
	if name == "attack":
		edge = Color(0.95, 0.40, 0.30, 0.85)
	elif name == "close":
		edge = Color(0.95, 0.82, 0.35, 0.9)
	var node := _make_box(rect, label, fs, edge)
	_buttons[name] = {"rect": rect, "action": action, "label": label, "hold": hold,
		"group": group, "node": node}

# --- layout -----------------------------------------------------------------

func _layout() -> void:
	for k in _buttons:
		_buttons[k].node.queue_free()
	_buttons.clear()
	if is_instance_valid(_stick_ghost):
		_stick_ghost.queue_free()
	if is_instance_valid(_stick_base):
		_stick_base.queue_free()
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var ins_l := 0.0
	var ins_r := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		ins_l = maxf(0.0, float(safe.position.x)) * vp.x / maxf(float(win.x), 1.0)
		ins_r = maxf(0.0, float(win.x - safe.position.x - safe.size.x)) * vp.x / maxf(float(win.x), 1.0)
	var m_r := 14.0 + ins_r
	var m_l := 14.0 + ins_l
	var m_b := 14.0
	# base unit scales with the SHORTER edge: sane on the square Fold inner
	# screen and the narrow cover screen alike
	var u := clampf(minf(vp.x, vp.y) * 0.052, 26.0, 56.0)
	var bw := u * 2.6
	var bh := u * 1.35
	# --- combat cluster, bottom-right ---
	var ax := vp.x - m_r - bw * 1.25
	var ay := vp.y - m_b - bh * 1.5
	_btn("attack", Rect2(ax, ay, bw * 1.25, bh * 1.5), "attack", "ATTACK", true, "game")
	_btn("jump", Rect2(ax - bw * 1.15, ay + bh * 0.25, bw, bh * 1.25), "jump", "JUMP", true, "game")
	_btn("special", Rect2(ax + bw * 0.1, ay - bh * 1.35, bw * 1.1, bh), "secondary_attack", "SPECIAL", true, "game")
	_btn("use", Rect2(ax - bw * 1.15, ay - bh * 1.35, bw, bh), "interact", "USE", false, "game")
	_btn("enter", Rect2(ax - bw * 2.3, ay - bh * 1.35, bw * 0.95, bh), "enter_dungeon", "ENTER", false, "game")
	# --- menu strip, top-right ---
	var ty := 12.0
	var sw := bw * 0.92
	_btn("bag", Rect2(vp.x - m_r - sw, ty, sw, bh), "toggle_inventory", "BAG", false, "menu")
	_btn("build", Rect2(vp.x - m_r - sw * 2.15, ty, sw, bh), "build_menu", "BUILD", false, "menu")
	_btn("skills", Rect2(vp.x - m_r - sw * 3.3, ty, sw, bh), "toggle_skill_tree", "SKILLS", false, "menu")
	_btn("more", Rect2(vp.x - m_r - sw * 4.2, ty, sw * 0.75, bh), "", "+", false, "menu")
	_btn("help", Rect2(vp.x - m_r - sw * 4.95, ty, sw * 0.6, bh), "", "?", false, "menu")
	if _extended:
		var ey := ty + bh * 1.25
		var ex := [["portal", "PORTAL"], ["harvest", "PLANT"], ["place_torch", "TORCH"],
			["log_toggle", "LOG"], ["time_backward", "TIME-"], ["time_forward", "TIME+"],
			["time_skip_day", "SLEEP"]]
		for i in ex.size():
			_btn("x%d" % i, Rect2(vp.x - m_r - sw * (1.0 + 1.15 * i), ey, sw, bh),
				ex[i][0], ex[i][1], false, "game")
	# --- CLOSE (only while a panel is open; sends Esc) ---
	_btn("close", Rect2(vp.x - m_r - bw * 1.25, vp.y - m_b - bh * 1.5, bw * 1.25, bh * 1.5),
		"ui_cancel", "CLOSE", false, "close")
	# --- stick: resting ghost + live base/knob ---
	var stick_r := clampf(vp.y * 0.11, 40.0, 90.0)
	_stick_rest = Vector2(m_l + vp.x * 0.13, vp.y * 0.74)
	_stick_ghost = _make_box(Rect2(_stick_rest - Vector2(stick_r * 0.8, stick_r * 0.8),
		Vector2(stick_r * 1.6, stick_r * 1.6)), "MOVE", int(stick_r * 0.30),
		Color(1, 1, 1, 0.18))
	(_stick_ghost.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.0)
	(_stick_ghost.get_child(0) as Label).add_theme_color_override("font_color", Color(1, 1, 1, 0.30))
	_stick_base = _make_box(Rect2(0, 0, stick_r * 2.0, stick_r * 2.0), "", 10)
	_stick_knob = _make_box(Rect2(0, 0, stick_r * 0.8, stick_r * 0.8), "", 10)
	(_stick_knob.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(1, 1, 1, 0.35)
	_stick_base.visible = false
	_stick_knob.visible = false
	# --- help overlay (rebuilt lazily, sits above everything in _ui) ---
	if is_instance_valid(_help):
		_help.queue_free()
	_help = Control.new()
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.add_child(dim)
	var hl := Label.new()
	hl.text = "DEEPWOOD  -  TOUCH CONTROLS\n\n" \
		+ "LEFT SIDE - touch + drag = MOVE   (flick twice = DASH)\n" \
		+ "ATTACK - hold to keep attacking (auto-aims nearest enemy)\n" \
		+ "JUMP - tap (again in air = double jump / hold = glide)\n" \
		+ "SPECIAL - weapon skill  /  near a villager: talk\n" \
		+ "USE - interact (E)      ENTER - dungeon doors\n" \
		+ "BAG / BUILD / SKILLS - menus      + - more actions\n" \
		+ "CLOSE appears when a menu is open\n\n" \
		+ "tap anywhere to start  -  reopen with  ?"
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hl.add_theme_font_override("font", GAME_FONT)
	hl.add_theme_font_size_override("font_size", int(clampf(vp.y * 0.030, 12.0, 28.0)))
	hl.add_theme_color_override("font_color", COL_TXT)
	_help.add_child(hl)
	_help.visible = false
	_ui.add_child(_help)
	_refresh_visibility()

func _refresh_visibility() -> void:
	for k in _buttons:
		var b: Dictionary = _buttons[k]
		var vis := true
		if b.group == "close":
			vis = _esc_open
		elif b.group == "game":
			vis = not _esc_open
		b.node.visible = vis
	if is_instance_valid(_stick_ghost):
		_stick_ghost.visible = not _esc_open and not _stick_down
	if is_instance_valid(_stick_base):
		_stick_base.visible = _stick_down
		_stick_knob.visible = _stick_down

func _set_held_style(name: String, held: bool) -> void:
	var b: Dictionary = _buttons.get(name, {})
	if b.is_empty() or not is_instance_valid(b.node):
		return
	(b.node.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = COL_BOX_HELD if held else COL_BOX

func _set_help(vis: bool) -> void:
	if is_instance_valid(_help):
		_help.visible = vis

# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_begin(event.index, event.position)
		else:
			_touch_end(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position)

func _touch_begin(idx: int, pos: Vector2) -> void:
	if is_instance_valid(_help) and _help.visible:
		_set_help(false)
		var cfg := ConfigFile.new()
		cfg.load("user://touch_prefs.cfg")
		cfg.set_value("help", "seen", true)
		cfg.save("user://touch_prefs.cfg")
		get_viewport().set_input_as_handled()
		return
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if b.node.visible and b.rect.grow(8.0).has_point(pos):
			_touches[idx] = {"kind": "button", "name": name}
			_button_down(name)
			get_viewport().set_input_as_handled()
			return
	var vp := Vector2(get_viewport().get_visible_rect().size)
	if not _esc_open and not _stick_down and pos.x < vp.x * STICK_ZONE_X and pos.y > vp.y * 0.28:
		_touches[idx] = {"kind": "stick"}
		_stick_down = true
		_stick_origin = pos
		_stick_vec = Vector2.ZERO
		var r := _stick_base.size.x / 2.0
		_stick_base.position = pos - Vector2(r, r)
		_stick_knob.position = pos - _stick_knob.size / 2.0
		_refresh_visibility()
		get_viewport().set_input_as_handled()
		return
	# world touches are intentionally IGNORED (dev call: no touch-to-attack);
	# the first finger still mouse-emulates so game panels get normal taps

func _touch_drag(idx: int, pos: Vector2) -> void:
	if not _touches.has(idx):
		return
	if _touches[idx].kind == "stick":
		var stick_r := _stick_base.size.x / 2.0
		_stick_vec = (pos - _stick_origin) / stick_r
		if _stick_vec.length() > 1.0:
			_stick_vec = _stick_vec.normalized()
		_stick_knob.position = _stick_origin + _stick_vec * stick_r * 0.62 - _stick_knob.size / 2.0
		var dir := 0
		if _stick_vec.x > DEADZONE:
			dir = 1
		elif _stick_vec.x < -DEADZONE:
			dir = -1
		_set_move_dir(dir)

func _touch_end(idx: int) -> void:
	if not _touches.has(idx):
		return
	var t: Dictionary = _touches[idx]
	_touches.erase(idx)
	match t.kind:
		"stick":
			_stick_down = false
			_set_move_dir(0)
			_refresh_visibility()
		"button":
			_button_up(t.name)

# --- action injection: parse_input_event reaches BOTH polled and event readers

func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

# transitions only: repeated presses would re-fire is_action_just_pressed and
# the double-tap dash window reads that (flick-flick = dash, by design)
func _set_move_dir(dir: int) -> void:
	if dir == _move_dir:
		return
	if _move_dir == -1:
		_send("move_left", false)
	elif _move_dir == 1:
		_send("move_right", false)
	if dir == -1:
		_send("move_left", true)
	elif dir == 1:
		_send("move_right", true)
	_move_dir = dir

func _button_down(name: String) -> void:
	var b: Dictionary = _buttons[name]
	_held[name] = true
	_set_held_style(name, true)
	if name == "more":
		_extended = not _extended
		_layout()
		return
	if name == "help":
		_set_help(true)
		return
	if b.action == "":
		return
	_send(b.action, true)
	if not b.hold:
		_pending_release.append(b.action)

func _button_up(name: String) -> void:
	_held.erase(name)
	_set_held_style(name, false)
	var b: Dictionary = _buttons.get(name, {})
	if not b.is_empty() and b.get("hold", false) and b.action != "":
		_send(b.action, false)

func _process(delta: float) -> void:
	# tap actions live exactly one frame so just_pressed sees a clean edge
	if not _pending_release.is_empty():
		for a in _pending_release:
			_send(a, false)
		_pending_release.clear()
	# poll whether an esc_window panel is open (mirrors player.gd's guard)
	_esc_poll -= delta
	if _esc_poll <= 0.0:
		_esc_poll = 0.25
		var open := false
		for w in get_tree().get_nodes_in_group("esc_window"):
			if is_instance_valid(w) and w.has_method("esc_is_open") and w.esc_is_open():
				open = true
				break
		if open != _esc_open:
			_esc_open = open
			if open and _stick_down:
				_stick_down = false
				_set_move_dir(0)
			_refresh_visibility()

# --- API for player.gd ------------------------------------------------------

# Auto-aim: nearest node in group "enemies" within AIM_RANGE, enemies on the
# facing side count as FACING_BONUS px closer; with no target, aim straight
# ahead. Replaces the mouse entirely on touch devices.
func aim_point_for(pl: Node2D) -> Vector2:
	var facing: float = pl.facing_direction if "facing_direction" in pl else 1.0
	var best: Node2D = null
	var best_score := AIM_RANGE
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var d: float = pl.global_position.distance_to(e.global_position)
		if d > AIM_RANGE:
			continue
		var score := d
		if signf(e.global_position.x - pl.global_position.x) == signf(facing):
			score -= FACING_BONUS
		if score < best_score:
			best_score = score
			best = e
	if best != null:
		return best.global_position
	return pl.global_position + Vector2(facing * 320.0, 0.0)
