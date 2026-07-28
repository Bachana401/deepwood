extends CanvasLayer

# WUKONG-STYLE BOSS SPECTACLE (dev ask 2026-07-22). Makes every boss an EVENT:
#   present()      -- a cinematic name-card on entry (letterbox + name reveal),
#                     then a big named health bar slides in at the top
#   set_health()   -- drives that bar (eased, so hits read as a smooth drain)
#   phase_banner() -- a red flash + a banner when the boss TURNS (enrage/frenzy)
#   slain()        -- the kill flourish: the bar shatters, a big SLAIN reveal
# One per dungeon, found via the "boss_hud" group. Additive UI only -- no pause,
# no time-scale (those belong to the hit-stop system), so it never fights combat.

var flash: ColorRect
var lb_top: ColorRect
var lb_bot: ColorRect
var card_title: Label
var card_sub: Label
var bar_root: Control
var bar_name: Label
var bar_fill: ColorRect
var _hp_target := 1.0
var _hp_shown := 1.0
var _accent := Color(1.0, 0.32, 0.3)
var _alive := false

func _ready() -> void:
	layer = 60
	add_to_group("boss_hud")
	process_mode = Node.PROCESS_MODE_ALWAYS

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	lb_top = _letterbox(true)
	lb_bot = _letterbox(false)

	# the name-card text, dead-centre, hidden until present()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	cc.add_child(vb)
	card_title = _mk_label(46, Color(0.96, 0.92, 0.85))
	card_sub = _mk_label(18, Color(0.85, 0.7, 0.55))
	card_title.modulate.a = 0.0
	card_sub.modulate.a = 0.0
	vb.add_child(card_title)
	vb.add_child(card_sub)

	# the big named health bar, top-centre, hidden until the reveal
	bar_root = Control.new()
	bar_root.anchor_left = 0.5
	bar_root.anchor_right = 0.5
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# y 46, not 30: the floor tally ("Floor 65/100 - 1 left") owns the very
	# top line, and the boss's NAME printed straight through it (EYES b65)
	bar_root.position = Vector2(0, 46)
	bar_root.modulate.a = 0.0
	add_child(bar_root)
	const BW := 640.0
	bar_name = _mk_label(17, Color(0.96, 0.9, 0.82))
	bar_name.position = Vector2(-BW / 2.0, -2)
	bar_name.size = Vector2(BW, 22)
	bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_root.add_child(bar_name)
	var frame := ColorRect.new()
	frame.color = Color(0.08, 0.07, 0.09, 0.92)
	frame.position = Vector2(-BW / 2.0, 24)
	frame.size = Vector2(BW, 20)
	bar_root.add_child(frame)
	bar_fill = ColorRect.new()
	bar_fill.color = _accent
	bar_fill.position = Vector2(-BW / 2.0 + 2.0, 26)
	bar_fill.size = Vector2(BW - 4.0, 16)
	bar_root.add_child(bar_fill)
	var edge := ColorRect.new()   # a thin bright top rim for a glassy read
	edge.color = Color(1, 1, 1, 0.14)
	edge.position = Vector2(-BW / 2.0 + 2.0, 26)
	edge.size = Vector2(BW - 4.0, 4)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(edge)

const BAR_W := 640.0

func _letterbox(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	if top:
		r.anchor_top = 0.0; r.anchor_bottom = 0.0
		r.offset_top = 0.0; r.offset_bottom = 78.0
	else:
		r.anchor_top = 1.0; r.anchor_bottom = 1.0
		r.offset_top = -78.0; r.offset_bottom = 0.0
	add_child(r)
	return r

func _mk_label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# --- the entrance ---
func present(display_name: String, subtitle: String, accent: Color) -> void:
	_accent = accent
	_alive = true
	_hp_target = 1.0
	_hp_shown = 1.0
	bar_fill.color = accent
	bar_name.text = display_name
	card_title.text = display_name
	card_sub.text = subtitle
	_shake(7.0, 0.5)
	var tw := create_tween()
	# letterbox in
	tw.set_parallel(true)
	tw.tween_property(lb_top, "color:a", 0.82, 0.35)
	tw.tween_property(lb_bot, "color:a", 0.82, 0.35)
	# name + subtitle rise in
	tw.tween_property(card_title, "modulate:a", 1.0, 0.4).set_delay(0.15)
	tw.tween_property(card_sub, "modulate:a", 1.0, 0.4).set_delay(0.35)
	# hold, then clear the card and reveal the bar
	tw.set_parallel(false)
	tw.tween_interval(1.5)
	tw.set_parallel(true)
	tw.tween_property(card_title, "modulate:a", 0.0, 0.4)
	tw.tween_property(card_sub, "modulate:a", 0.0, 0.4)
	tw.tween_property(lb_top, "color:a", 0.0, 0.45)
	tw.tween_property(lb_bot, "color:a", 0.0, 0.45)
	tw.tween_property(bar_root, "modulate:a", 1.0, 0.45).set_delay(0.25)

# --- the drain ---
func set_health(frac: float) -> void:
	_hp_target = clampf(frac, 0.0, 1.0)

func _process(delta: float) -> void:
	if bar_fill == null:
		return
	_hp_shown = move_toward(_hp_shown, _hp_target, delta * 1.4)
	bar_fill.size.x = (BAR_W - 4.0) * _hp_shown
	# redden as it empties -- a wounded boss reads hotter
	bar_fill.color = _accent.lerp(Color(0.95, 0.15, 0.12), 1.0 - _hp_shown)

# --- the turn (enrage / frenzy) ---
func phase_banner(text: String) -> void:
	if not _alive:
		return
	card_title.text = text
	card_sub.text = ""
	card_title.modulate = Color(1.0, 0.5, 0.4, 0.0)
	_shake(9.0, 0.45)
	var fl := create_tween()
	fl.tween_property(flash, "color", Color(1.0, 0.2, 0.15, 0.32), 0.06)
	fl.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.4)
	var tw := create_tween()
	tw.tween_property(card_title, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.9)
	tw.tween_property(card_title, "modulate:a", 0.0, 0.4)

# --- the kill ---
func slain(display_name: String) -> void:
	_alive = false
	_hp_target = 0.0
	var fl := create_tween()
	fl.tween_property(flash, "color", Color(1, 1, 1, 0.5), 0.05)
	fl.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.6)
	_shake(11.0, 0.6)
	card_title.text = display_name + "\nSLAIN"
	card_sub.text = ""
	card_title.modulate = Color(1.0, 0.85, 0.5, 0.0)
	var tw := create_tween()
	tw.tween_property(bar_root, "modulate:a", 0.0, 0.5)
	tw.tween_property(card_title, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(card_title, "modulate:a", 0.0, 0.7)

func _shake(mag: float, dur: float) -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl and pl.has_node("Camera2D"):
		pl.get_node("Camera2D").shake(mag, dur)
