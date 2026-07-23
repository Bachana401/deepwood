class_name DialogueBox
extends CanvasLayer

# A small, reusable conversation box (bottom of screen): speaker name + one line,
# advanced with E / Space / click, pausing the game while open. NOT a cutscene
# engine -- STORY.md says the story is earned through the loop and delivered in
# brief exchanges, so this just carries Deepwood's few scripted beats (the
# opening plea, the Level-100 reveal, the ending). Epic/mythic tone.
#
#   DialogueBox.play(some_node, [{"speaker": "...", "text": "..."}, ...], on_done)

var lines: Array = []
var index := 0
var panel: Panel
var speaker_label: Label
var text_label: Label
var _on_finished: Callable

static func play(host: Node, script_lines: Array, on_finished := Callable()) -> void:
	if script_lines.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return
	var box = DialogueBox.new()
	box.lines = script_lines
	box._on_finished = on_finished
	host.get_tree().root.add_child(box)

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running while the tree is paused
	add_to_group("dialogue_box")
	build_ui()
	get_tree().paused = true
	_set_cutscene_hud_hidden(true)            # ONLY CHAT while a scripted beat plays
	show_line()

# The opening (and every scripted beat) should read as chat, not chat-over-a-HUD:
# hide the HUD chrome + hotbar (group "cutscene_hides") while a box is on screen.
# Restored when the LAST box closes -- checked by group, so a chained next line
# keeps it hidden with no flicker, and a stray leak can never strand it off.
func _set_cutscene_hud_hidden(hidden: bool) -> void:
	var t := get_tree()
	if t == null:
		return
	for n in t.get_nodes_in_group("cutscene_hides"):
		if is_instance_valid(n):
			n.visible = not hidden

func build_ui() -> void:
	var shade = ColorRect.new()   # dim the world a touch behind the box
	shade.color = Color(0, 0, 0, 0.28)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 48
	panel.offset_right = -48
	panel.offset_top = -184
	panel.offset_bottom = -28
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.96)
	style.border_color = Color(0.82, 0.68, 0.34, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	speaker_label = Label.new()
	speaker_label.position = Vector2(22, 12)
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.4, 1))
	panel.add_child(speaker_label)

	text_label = Label.new()
	text_label.position = Vector2(22, 44)
	text_label.size = Vector2(0, 96)
	text_label.anchor_right = 1.0
	text_label.offset_right = -22
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.95, 1))
	panel.add_child(text_label)

	var hint = Label.new()
	hint.anchor_left = 1.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -170
	hint.offset_top = -26
	hint.offset_right = -14
	hint.offset_bottom = -6
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66, 1))
	hint.text = "E / Space  ▸"
	panel.add_child(hint)

func show_line() -> void:
	if index >= lines.size():
		finish()
		return
	var l = lines[index]
	speaker_label.text = str(l.get("speaker", ""))
	text_label.text = str(l.get("text", ""))

func _unhandled_input(event: InputEvent) -> void:
	var advance = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if not advance and event is InputEventMouseButton and event.pressed:
		advance = true
	if advance:
		index += 1
		show_line()
		get_viewport().set_input_as_handled()

func finish() -> void:
	var t := get_tree()
	t.paused = false
	var cb = _on_finished
	queue_free()                              # deferred: this box still counts below
	if cb.is_valid():
		cb.call()                             # a chained line re-hides on its _ready
	# restore the HUD only when the conversation is truly over -- if the callback
	# opened another box, one still lives in the group and we stay hidden
	var still_talking := false
	for n in t.get_nodes_in_group("dialogue_box"):
		if n != self and is_instance_valid(n) and not n.is_queued_for_deletion():
			still_talking = true
			break
	if not still_talking:
		_set_cutscene_hud_hidden(false)
