extends CanvasLayer
# THE VILLAGER MENU (dev ask 2026-07-27): walk up to a villager, RIGHT-CLICK, and
# choose what you want from them -- Talk, Ask for Quest, Show me stats, or send
# them away. It replaces reading people by hovering the mouse over them.
#
# It opens beside the villager (screen-projected, then nudged to stay on screen)
# so it is obvious WHO you are talking to, and it runs while the tree is paused
# like every other window.

const W := 232.0
const ROW_H := 34.0

var villager_id := ""
var _npc: Node = null
var _panel: Panel = null

func _ready() -> void:
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	add_to_group("villager_menu")

func esc_is_open() -> bool:
	return _panel != null and _panel.visible

func esc_close() -> void:
	queue_free()

static func open_for(host: Node, npc: Node) -> Node:
	for old in host.get_tree().get_nodes_in_group("villager_menu"):
		if is_instance_valid(old):
			old.queue_free()
	var m = load("res://villager_menu.gd").new()
	m.villager_id = str(npc.villager_id)
	m._npc = npc
	host.get_tree().current_scene.add_child(m)
	return m

func _enter_tree() -> void:
	if _panel == null:
		_build()

func _name_of() -> String:
	if _npc != null and is_instance_valid(_npc) and _npc.has_method("find_villager_data"):
		return str(_npc.find_villager_data().get("name", "the villager"))
	return "the villager"

func _build() -> void:
	_panel = Panel.new()
	_panel.size = Vector2(W, ROW_H * 4.0 + 54.0)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.position = Vector2(10.0, 8.0)
	vb.custom_minimum_size = Vector2(W - 20.0, 0)
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	var who := Label.new()
	who.text = _name_of()
	who.add_theme_font_size_override("font_size", 15)
	who.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	vb.add_child(who)
	vb.add_child(HSeparator.new())

	for entry in [
		{"label": "Talk", "cb": _on_talk},
		{"label": "Ask for Quest", "cb": _on_quest},
		{"label": "Show me stats", "cb": _on_stats},
		{"label": "Leave the village", "cb": _on_leave, "danger": true},
	]:
		var b := Button.new()
		b.text = "  " + str(entry["label"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(W - 20.0, ROW_H)
		b.add_theme_font_size_override("font_size", 15)
		if entry.get("danger", false):
			b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		b.pressed.connect(entry["cb"])
		vb.add_child(b)

	_place_beside_villager()

# Put the panel next to the villager on screen, then keep it fully on screen --
# a menu half off the edge is how these things usually go wrong.
func _place_beside_villager() -> void:
	if _npc == null or not is_instance_valid(_npc):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_2d()
	var screen: Vector2 = _npc.global_position
	if cam != null:
		var zoom: Vector2 = cam.zoom
		screen = (_npc.global_position - cam.get_screen_center_position()) * zoom \
			+ vp.get_visible_rect().size * 0.5
	var view: Vector2 = vp.get_visible_rect().size
	var pos := Vector2(screen.x + 46.0, screen.y - _panel.size.y * 0.75)
	pos.x = clampf(pos.x, 12.0, maxf(12.0, view.x - _panel.size.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, view.y - _panel.size.y - 12.0))
	_panel.position = pos

func _npc_gone() -> bool:
	return _npc == null or not is_instance_valid(_npc)

# --- the four choices -------------------------------------------------------

func _on_talk() -> void:
	if _npc_gone():
		esc_close(); return
	# what they'd have said if you pressed E: a mood line, plus the diary
	# recount for a player with no live feed from home
	if _npc.has_method("maybe_recount_news"):
		_npc.maybe_recount_news()
	if _npc.has_method("say_mood_line"):
		_npc.say_mood_line()
	esc_close()

func _on_quest() -> void:
	if _npc_gone():
		esc_close(); return
	var data: Dictionary = _npc.find_villager_data()
	var def: Dictionary = VillagerQuests.get_def(str(data.get("id", "")))
	if def.is_empty():
		_npc.speak_or_notify("I've no errand for you, friend.")
		esc_close(); return
	# the bond flow already handles offer / progress / turn-in on E -- reuse it
	# rather than growing a second, subtly different copy of those rules
	if _npc.has_method("try_bond_interaction") and _npc.try_bond_interaction():
		esc_close(); return
	if str(data.get("quest_state", "")) == "done":
		_npc.speak_or_notify("You already did that for me. I won't forget it.")
	esc_close()

func _on_stats() -> void:
	if _npc_gone():
		esc_close(); return
	load("res://villager_sheet.gd").open_for(self, _npc)
	esc_close()

# Sending someone away is IRREVERSIBLE (they leave the roster for good), so it
# goes through the same confirmation the game uses for its other one-way doors.
func _on_leave() -> void:
	if _npc_gone():
		esc_close(); return
	var nm := _name_of()
	var pl = get_tree().get_first_node_in_group("player")
	var host: Node = pl if pl != null else get_tree().current_scene
	var id := str(_npc.villager_id)
	ChoicePrompt.open(host, "SEND THEM AWAY?",
		"%s will pack up and leave Deepwood for good. Their job, their home and whatever they were owed go with them. This cannot be undone." % nm,
		[
			{"label": "Send %s away" % nm, "danger": true, "cb": func():
				GameState.remove_villager_by_id(id)
				GameState.log_event("people", "%s left Deepwood — sent away." % nm)
				GameState.notify("%s has left the village." % nm)},
			{"label": "Never mind", "cb": func(): pass},
		])
	esc_close()
