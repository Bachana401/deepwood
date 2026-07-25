class_name ChoicePrompt
extends CanvasLayer

# A small modal decision box, styled like the DialogueBox: a title, a body line,
# and a column of buttons, each wired to a callback. Pauses the game while open.
# Built for the pivotal, no-misclicks choices -- above all the Rewound Hour's
# turn-or-shatter at the true ending (GAME_BIBLE 11/12).
#
#   ChoicePrompt.open(host, "TITLE", "body...", [
#       {"label": "Do it",   "cb": func(): ...},
#       {"label": "Danger",  "danger": true, "cb": func(): ...},
#       {"label": "Not now", "cb": func(): ...},   # a plain close
#   ])

var _title := ""
var _body := ""
var _options: Array = []

static func open(host: Node, title: String, body: String, options: Array) -> void:
	var box = ChoicePrompt.new()
	box._title = title
	box._body = body
	box._options = options
	host.get_tree().root.add_child(box)

func _ready() -> void:
	layer = 61                                    # above the DialogueBox (60)
	process_mode = Node.PROCESS_MODE_ALWAYS       # runs while the tree is paused
	add_to_group("choice_prompt")
	add_to_group("esc_window")                    # closable like the game's other panels
	_build()
	get_tree().paused = true

func _build() -> void:
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	add_child(shade)

	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -170
	panel.offset_bottom = 180
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.border_color = Color(0.82, 0.68, 0.34, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vb = VBoxContainer.new()
	vb.anchor_left = 0.0
	vb.anchor_right = 1.0
	vb.offset_left = 24
	vb.offset_right = -24
	vb.offset_top = 20
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title_lbl = Label.new()
	title_lbl.text = _title
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.4, 1))
	vb.add_child(title_lbl)

	var body_lbl = Label.new()
	body_lbl.text = _body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(552, 0)
	body_lbl.add_theme_font_size_override("font_size", 14)
	body_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.93, 1))
	vb.add_child(body_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vb.add_child(spacer)

	for opt in _options:
		var b = Button.new()
		b.text = str(opt.get("label", "..."))
		b.add_theme_font_size_override("font_size", 15)
		if bool(opt.get("danger", false)):
			b.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45, 1))
		var cb: Callable = opt.get("cb", Callable())
		b.pressed.connect(func(): _choose(cb))
		vb.add_child(b)

func _choose(cb: Callable) -> void:
	get_tree().paused = false
	queue_free()
	if cb.is_valid():
		cb.call()

# Esc / the shared close key dismisses the prompt as "no choice made".
# esc_is_open() is REQUIRED: pause_menu.close_open_windows() only calls esc_close
# on group members that report open -- without it, Esc fell through to toggling
# the pause menu behind this modal and desynced the pause state.
func esc_is_open() -> bool:
	return true

func esc_close() -> void:
	_choose(Callable())
