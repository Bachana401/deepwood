extends CanvasLayer
# THE VILLAGER SHEET (dev call 2026-07-27). The old way of reading a villager was
# a tiny 182px hover card floating over their head, which the dev reported two
# faults with: it was too small for the card it had grown into (spirit, home,
# watch, bond, title -- long lines wrapped and fell off the bottom), and if the
# villager spoke while you were reading it the speech bubble landed on top of the
# same words. Hovering is gone; you right-click a villager and pick "Show me
# stats", and their sheet opens HERE -- a proper window, sized to its content,
# with room for every line.
#
# It also owns their VOICE while it is open: anything the villager says is
# printed at the bottom of their own sheet instead of spawning a floating bubble
# over their head, so the two can never overlap again.

const W := 560.0
const PAD := 22.0
const SPEECH_LINES := 3

var villager_id := ""
var _npc: Node = null
var _panel: Panel = null
var _rows: VBoxContainer = null
var _speech: Label = null
var _speech_box: Panel = null
var _refresh_cd := 0.0

func _ready() -> void:
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	add_to_group("villager_sheet")

func esc_is_open() -> bool:
	return _panel != null and _panel.visible

func esc_close() -> void:
	queue_free()

static func open_for(host: Node, npc: Node) -> Node:
	# one sheet at a time: reopening for anyone replaces whatever is up
	for old in host.get_tree().get_nodes_in_group("villager_sheet"):
		if is_instance_valid(old):
			old.queue_free()
	var s = load("res://villager_sheet.gd").new()
	s.villager_id = str(npc.villager_id)
	s._npc = npc
	host.get_tree().current_scene.add_child(s)
	return s

func _enter_tree() -> void:
	if _panel == null:
		_build()

func _build() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -W / 2.0
	_panel.offset_right = W / 2.0
	_panel.offset_top = -220.0
	_panel.offset_bottom = 220.0
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.0
	vb.anchor_right = 1.0
	vb.offset_left = PAD
	vb.offset_right = -PAD
	vb.offset_top = PAD - 6.0
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	_rows = vb

	# the speech strip lives at the BOTTOM, pinned, so a long card never pushes
	# it off the panel -- this is where their voice goes while the sheet is open
	_speech_box = Panel.new()
	_speech_box.anchor_left = 0.0
	_speech_box.anchor_right = 1.0
	_speech_box.anchor_top = 1.0
	_speech_box.anchor_bottom = 1.0
	_speech_box.offset_left = PAD * 0.6
	_speech_box.offset_right = -PAD * 0.6
	_speech_box.offset_top = -(18.0 * float(SPEECH_LINES) + 58.0)
	_speech_box.offset_bottom = -52.0
	_speech_box.visible = false
	_panel.add_child(_speech_box)
	_speech = Label.new()
	_speech.anchor_right = 1.0
	_speech.anchor_bottom = 1.0
	_speech.offset_left = 10.0
	_speech.offset_top = 6.0
	_speech.offset_right = -10.0
	_speech.offset_bottom = -6.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.add_theme_font_size_override("font_size", 14)
	_speech.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	_speech_box.add_child(_speech)

	var close := Button.new()
	close.text = "Close"
	close.anchor_top = 1.0
	close.anchor_bottom = 1.0
	close.offset_left = PAD * 0.6
	close.offset_top = -44.0
	close.offset_bottom = -12.0
	close.custom_minimum_size = Vector2(120, 32)
	close.pressed.connect(esc_close)
	_panel.add_child(close)

	refresh()

func _process(delta: float) -> void:
	# the villager keeps living while you read: spirit, duty and home can change
	_refresh_cd -= delta
	if _refresh_cd <= 0.0:
		_refresh_cd = 0.5
		if _npc == null or not is_instance_valid(_npc):
			queue_free()
			return
		refresh()

func refresh() -> void:
	if _rows == null or _npc == null or not is_instance_valid(_npc):
		return
	for c in _rows.get_children():
		c.queue_free()
	var fields: Array = _npc.info_fields() if _npc.has_method("info_fields") else []
	if fields.is_empty():
		return
	# line 1 is the NAME -- give it the title treatment
	var title := Label.new()
	title.text = str(fields[0])
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	_rows.add_child(title)
	var sep := HSeparator.new()
	_rows.add_child(sep)
	# every remaining line at a readable size, wrapping INSIDE the panel rather
	# than being clipped by it (the old card's real failure)
	for i in range(1, fields.size()):
		var l := Label.new()
		l.text = str(fields[i])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W - PAD * 2.0, 0)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		_rows.add_child(l)
	# grow the window to whatever the card needs, plus room for the speech strip
	var want: float = 96.0 + float(fields.size()) * 26.0 + 18.0 * float(SPEECH_LINES) + 60.0
	var half: float = clampf(want, 300.0, 600.0) / 2.0
	_panel.offset_top = -half
	_panel.offset_bottom = half

# Called by npc.gd instead of spawning a floating bubble: their voice belongs in
# their own sheet while it is open, so speech can never sit on top of the stats.
func show_speech(line: String) -> void:
	if _speech == null:
		return
	_speech.text = "“%s”" % line
	_speech_box.visible = true
