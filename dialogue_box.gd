class_name DialogueBox
extends CanvasLayer

# A small, reusable conversation box (bottom of screen): a brass name-plate, one
# line of typewritten pixel text, and a blinking caret -- advanced with E / Space
# / click, pausing the game while open. NOT a cutscene engine -- STORY.md says the
# story is earned through the loop and delivered in brief exchanges, so this just
# carries Deepwood's few scripted beats (the opening plea, the arrival cutscene,
# the Level-100 reveal, the ending). Epic/mythic tone, retro-pixel presentation.
#
#   DialogueBox.play(some_node, [{"speaker": "...", "text": "..."}, ...], on_done)

const FONT_BODY := preload("res://art/fonts/PixelifySans.ttf")
const FONT_NAME := preload("res://art/fonts/Silkscreen-Regular.ttf")

# Type speed (characters per second) and how the box reads each speaker.
const TYPE_CPS := 42.0
# Per-speaker accent + a short role tag for the plate. Anyone not listed falls to
# the default. "" is the narrator (scene description) -- no plate, centred text.
const SPEAKERS := {
	"You":            {"color": Color(0.96, 0.86, 0.45), "tag": "You"},
	"Roland":         {"color": Color(0.62, 0.78, 0.98), "tag": "Roland · Blade"},
	"Wren":           {"color": Color(0.66, 0.92, 0.62), "tag": "Wren · Scout"},
	"Castor":         {"color": Color(0.98, 0.80, 0.52), "tag": "Castor · Shield"},
	"A Survivor":     {"color": Color(0.95, 0.72, 0.74), "tag": "A Survivor"},
	"Doctor Maren Hollis": {"color": Color(0.95, 0.72, 0.74), "tag": "Doctor Maren"},
	"Orin":           {"color": Color(0.80, 0.60, 0.98), "tag": "Orin"},
}
const DEFAULT_ACCENT := Color(0.82, 0.68, 0.34)

var lines: Array = []
var index := 0
var panel: Panel
var name_plate: Panel
var speaker_label: Label
var text_label: Label
var caret: Label
var _on_finished: Callable

var _full_text := ""      # the whole current line
var _shown := 0.0         # characters revealed so far (float for smooth typing)
var _typing := false
var _blink := 0.0
var _pointer: SpeakerIndicator = null   # the chevron hovering over the live speaker
# The scene whose beat this is, held BY INSTANCE ID (see _host_gone): a freed
# object compares EQUAL to null in GDScript, so a plain `scene != null and not
# is_instance_valid(scene)` check reads false the moment the scene actually dies
# -- exactly when it must fire. instance_from_id() has no such blind spot.
var _host_id := 0
var _finished := false                  # finish() ran; every later call is a no-op

static func play(host: Node, script_lines: Array, on_finished := Callable()) -> void:
	# a deferred opening beat can fire during a scene swap, when host has left the tree and
	# host.get_tree() is null -- there's nowhere to mount the box, so abort quietly.
	if host == null or not host.is_inside_tree():
		return
	if script_lines.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return
	var box = DialogueBox.new()
	box.lines = script_lines
	box._on_finished = on_finished
	# root-mounted on purpose (survives pauses, owns layer 60) -- but remember
	# WHOSE beat this is, so a scene change can dissolve it (see _process)
	var host_scene := host.get_tree().current_scene
	box._host_id = host_scene.get_instance_id() if host_scene != null else 0
	host.get_tree().root.add_child(box)

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running (and typing) while paused
	add_to_group("dialogue_box")
	build_ui()
	get_tree().paused = true
	_set_cutscene_hud_hidden(true)            # ONLY the conversation while a beat plays
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
		if not is_instance_valid(n):
			continue
		# THE TOAST CHANNEL STAYS ON THROUGH BEATS (audit fix): the main HUD
		# layer contains the NotificationStack, so hiding the layer swallowed
		# every toast issued alongside a dialogue -- including the finale's own
		# guard text (the Soul Split Wand re-grant explains the whole unkillable
		# lock, and it fired invisible). For a member that CONTAINS the stack,
		# hide its other children instead of the layer itself.
		var toast := n.get_node_or_null("NotificationStack")
		if toast != null:
			for c in n.get_children():
				if c == toast or not ("visible" in c):
					continue
				_set_one_hidden(c, hidden)
		else:
			_set_one_hidden(n, hidden)

# remember what was ALREADY hidden (audit fix): the restore used to force-show
# every member, so anything legitimately invisible when a beat started was
# revealed when it ended
func _set_one_hidden(n: Node, hidden: bool) -> void:
	if hidden:
		if not n.has_meta("cutscene_was_visible"):
			n.set_meta("cutscene_was_visible", n.visible)
		n.visible = false
	else:
		n.visible = bool(n.get_meta("cutscene_was_visible", true))
		n.remove_meta("cutscene_was_visible")

func build_ui() -> void:
	# NO DIMMING (dev call 2026-07-27: "don't dim the background when dialogue is
	# on, let it stay in same color"). There used to be a full-screen 42%-black
	# ColorRect here. It also made the speaker chevron look broken: this box is a
	# CanvasLayer, which always draws OVER world nodes whatever their z_index, so
	# the shade washed the world-space indicator out no matter how bright it was.
	panel = Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 56
	panel.offset_right = -56
	panel.offset_top = -172
	panel.offset_bottom = -34
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.085, 0.98)
	style.border_color = Color(0.82, 0.68, 0.34, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	style.content_margin_left = 28
	style.content_margin_top = 30
	style.content_margin_right = 28
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# the name-plate: a small brass tab riding the top-left border of the panel
	name_plate = Panel.new()
	name_plate.position = Vector2(18, -18)
	name_plate.size = Vector2(220, 32)
	var plate_style = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	plate_style.border_color = DEFAULT_ACCENT
	plate_style.set_border_width_all(2)
	plate_style.set_corner_radius_all(3)
	plate_style.content_margin_left = 12
	plate_style.content_margin_right = 12
	plate_style.content_margin_top = 4
	plate_style.content_margin_bottom = 4
	name_plate.add_theme_stylebox_override("panel", plate_style)
	panel.add_child(name_plate)

	speaker_label = Label.new()
	speaker_label.add_theme_font_override("font", FONT_NAME)
	speaker_label.add_theme_font_size_override("font_size", 16)
	speaker_label.add_theme_color_override("font_color", DEFAULT_ACCENT)
	speaker_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_plate.add_child(speaker_label)

	text_label = Label.new()
	text_label.add_theme_font_override("font", FONT_BODY)
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97, 1))
	text_label.add_theme_constant_override("line_spacing", 6)
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A plain Panel does NOT inset its children by the stylebox content margins the
	# way a Container would, so pad the text rect explicitly -- otherwise the body
	# text sits flush against the left border, out of line with the name-plate. The
	# left edge (30) matches the name-plate's text start (plate x=18 + its 12px
	# margin) so speaker and line share ONE left margin. TOP-aligned so every beat
	# begins at the SAME spot regardless of length -- no vertical jump between lines.
	text_label.offset_left = 30
	text_label.offset_top = 24
	text_label.offset_right = -30
	text_label.offset_bottom = -16
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(text_label)

	# the blinking "press E" caret, bottom-right of the panel
	caret = Label.new()
	caret.add_theme_font_override("font", FONT_NAME)
	caret.add_theme_font_size_override("font_size", 12)
	caret.add_theme_color_override("font_color", Color(0.72, 0.66, 0.5, 1))
	caret.text = "E / SPACE  ▸"
	caret.anchor_left = 1.0
	caret.anchor_top = 1.0
	caret.anchor_right = 1.0
	caret.anchor_bottom = 1.0
	caret.offset_left = -168
	caret.offset_top = -26
	caret.offset_right = -14
	caret.offset_bottom = -6
	panel.add_child(caret)

func show_line() -> void:
	if index >= lines.size():
		finish()
		return
	var l = lines[index]
	var speaker := str(l.get("speaker", ""))
	_full_text = str(l.get("text", ""))
	_shown = 0.0
	_typing = true
	# style by speaker
	var info: Dictionary = SPEAKERS.get(speaker, {})
	var accent: Color = info.get("color", DEFAULT_ACCENT)
	if speaker == "":
		# narrator: no plate, centred amber prose
		name_plate.visible = false
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.add_theme_color_override("font_color", Color(0.86, 0.8, 0.62, 1))
	else:
		name_plate.visible = true
		speaker_label.text = str(info.get("tag", speaker)).to_upper()
		speaker_label.add_theme_color_override("font_color", accent)
		var ps: StyleBoxFlat = name_plate.get_theme_stylebox("panel")
		ps.border_color = accent
		# widen the plate to the name
		name_plate.size.x = maxf(120.0, speaker_label.get_theme_font("font").get_string_size(
			speaker_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.97, 1))
	text_label.text = _full_text
	text_label.visible_characters = 0
	caret.visible = false
	_point_at_speaker(speaker, accent)

# Hover the chevron over the body that owns this line, so the player can tell who
# is speaking. Hidden for the narrator ("") and for any speaker with no avatar on
# screen (e.g. a beat delivered before the cast has spawned).
func _point_at_speaker(speaker: String, tint: Color) -> void:
	var found := _find_speaker(speaker)
	if found.is_empty():
		if _pointer != null and is_instance_valid(_pointer):
			_pointer.visible = false
		return
	var node = found[0]
	var yoff: float = found[1]
	if node == null or not is_instance_valid(node):
		if _pointer != null and is_instance_valid(_pointer):
			_pointer.visible = false
		return
	if _pointer == null or not is_instance_valid(_pointer):
		var host := get_tree().current_scene
		if host == null:
			return
		_pointer = SpeakerIndicator.new()
		host.add_child(_pointer)
	_pointer.place(node.global_position + Vector2(0.0, yoff), tint)

# Resolve a speaker name to its on-screen body, plus how far above the origin the
# chevron should sit. Returns [] when nobody matches (graceful -> no chevron).
func _find_speaker(speaker: String) -> Array:
	var t := get_tree()
	if t == null or speaker == "":
		return []
	if speaker == "You":
		var p = t.get_first_node_in_group("player")
		return [p, -86.0] if p != null else []
	if speaker == "Orin":
		for w in t.get_nodes_in_group("village_defender"):
			if w.has_method("cast_meteor_at"):        # the wizard's signature ability
				return [w, -96.0]
		return []
	# adventurers carry their FULL display name on `def` ("Roland Ashmark"), while a
	# story speaker is the first name ("Roland") -- match either the whole name or
	# its leading word.
	for a in t.get_nodes_in_group("adventurer"):
		if "is_dead" in a and a.is_dead:
			continue
		if not ("def" in a) or a.def == null:
			continue
		var full := str(a.def.get("name", ""))
		if full == "":
			continue
		if full == speaker or full.split(" ", false)[0] == speaker:
			return [a, -82.0]
	# villagers: "A Survivor" and any "Doctor ..." line belong to the Doctor, who
	# speaks the arrival reveal; otherwise match a villager by name
	var want_doc := (speaker == "A Survivor" or speaker.begins_with("Doctor"))
	for n in t.get_nodes_in_group("npc"):
		if not is_instance_valid(n):
			continue
		if want_doc and str(n.get("villager_id")) == "doctor_maren":
			return [n, -76.0]
		if n.has_method("find_villager_data"):
			var d: Dictionary = n.find_villager_data()
			if str(d.get("name", "")) == speaker:
				return [n, -76.0]
	if want_doc:                                        # doctor gone? any survivor will do
		for n in t.get_nodes_in_group("npc"):
			if is_instance_valid(n):
				return [n, -76.0]
	return []

# The scene that spoke this beat no longer exists (freed mid scene-swap or
# quit-to-menu). Its callback aims at freed nodes and must never dispatch.
func _host_gone() -> bool:
	if _host_id == 0:
		return false                      # a sceneless beat has nobody to outlive
	var host = instance_from_id(_host_id)
	return host == null or not is_instance_valid(host)

func _process(delta: float) -> void:
	# THE BEAT DIES WITH ITS SCENE. We are parented to root (survives scene
	# swaps by design), so a Quit-to-Menu or dungeon exit mid-beat used to
	# strand this box -- full-screen shade + panel eating input over the next
	# scene, and a finish() whose callback fired into freed nodes. If the scene
	# that spoke us is gone, dissolve: drop the callback, release the pause.
	if _host_gone():
		_on_finished = Callable()
		finish()
		return
	if _typing:
		_shown += delta * TYPE_CPS
		var n := int(_shown)
		if n >= _full_text.length():
			text_label.visible_characters = -1
			_typing = false
		else:
			text_label.visible_characters = n
	else:
		# blink the continue caret once the line is fully shown
		_blink += delta
		caret.visible = fmod(_blink, 0.9) < 0.55

func _unhandled_input(event: InputEvent) -> void:
	var advance = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	# a real click (left/right) advances -- but NOT mouse-wheel notches, which also arrive
	# as a pressed InputEventMouseButton and would blow through several lines in one scroll,
	# skipping the scripted opening (which is marked delivered up front and never replays).
	if not advance and event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		advance = true
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		# first press: finish typing this line instantly (E as a fast-forward)
		_typing = false
		text_label.visible_characters = -1
		return
	index += 1
	show_line()

func _exit_tree() -> void:
	# never strand the world-space chevron if this box leaves the tree
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.queue_free()
	_pointer = null

func finish() -> void:
	# IDEMPOTENT + TEARDOWN-SAFE (0xC0000005 fix 2026-07-29): tests and the
	# tool_eyes_* walkers call finish() straight off the "dialogue_box" group, and
	# during a scene reload that call can land in the one-frame window where the
	# scene owning our callback is already freed but _process hasn't dissolved us
	# yet. Dispatching _on_finished then is a NATIVE crash (the lambda's captured
	# self is a dangling script instance), not a catchable script error -- so the
	# box guards here, once, instead of trusting its many direct callers.
	if _finished:
		return
	_finished = true
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.queue_free()             # the speaker chevron dies with the box
	_pointer = null
	var cb = _on_finished
	_on_finished = Callable()
	# the beat's scene is gone (mid scene-swap): the callback aims at freed nodes.
	# The same rule _process applies, enforced for direct callers too.
	if _host_gone():
		cb = Callable()
	var t := get_tree()
	if t == null:                             # already off the tree: just die quietly
		queue_free()
		return
	# release the pause -- UNLESS the pause menu is open on top of us (ESC works
	# during a beat): blind-unpausing here left the world running behind a
	# visible pause menu, desynced from its own toggle.
	var pm = t.get_first_node_in_group("pause_menu")
	t.paused = pm != null and is_instance_valid(pm) and pm.visible
	queue_free()                              # deferred: this box still counts below
	# only dispatch a callback whose owner still breathes AND still stands in the
	# tree -- a Callable outlives its object, and is_valid() alone does not cover
	# a lambda whose captured self was freed
	var cb_owner = cb.get_object() if cb.is_valid() else null
	if cb.is_valid() and is_instance_valid(cb_owner) \
			and (not cb_owner is Node or cb_owner.is_inside_tree()):
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
