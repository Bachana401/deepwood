extends Node2D
# THE BUILDER'S HAND (dev 2026-07-22). Raise a building from the B menu with a
# green/red HOLOGRAM that follows the cursor -- green where it can stand, red
# where it can't (off clear ground, or on another building) -- and left-click to
# place it. Or delete a building: click it, then a YES/NO panel makes you sure.
# Lives in the village scene; build_menu.gd drives it. World-space for the holo;
# a CanvasLayer child carries the on-screen hint + the confirm panel.

const VILLAGE_Y := -39.0
const HOUSE_SCRIPT = preload("res://house.gd")
const HOUSE_PALETTES = [
	{"body": Color(0.62, 0.48, 0.32, 1), "roof": Color(0.48, 0.24, 0.18, 1)},
	{"body": Color(0.55, 0.42, 0.5, 1), "roof": Color(0.4, 0.22, 0.32, 1)},
	{"body": Color(0.42, 0.5, 0.42, 1), "roof": Color(0.28, 0.36, 0.24, 1)},
	{"body": Color(0.58, 0.5, 0.35, 1), "roof": Color(0.42, 0.3, 0.16, 1)},
]

var mode := ""              # "" | "build" | "delete"
var build_name := ""
var build_w := 120.0
var ghost: ColorRect = null
var ui: CanvasLayer = null
var hint: Label = null

func _ready() -> void:
	z_index = 90
	add_to_group("build_placer")
	ui = CanvasLayer.new()
	ui.layer = 60
	add_child(ui)

func start_build(bname: String, w: float, h: float, col: Color) -> void:
	_clear()
	mode = "build"
	GameState.placing_building = true
	build_name = bname
	build_w = w
	ghost = ColorRect.new()
	ghost.size = Vector2(w, h)
	ghost.color = Color(0.4, 0.9, 0.5, 0.42)
	ghost.z_index = 90
	add_child(ghost)
	_show_hint("Placing the %s — left-click on GREEN ground · right-click to cancel" % bname)

func start_delete() -> void:
	_clear()
	mode = "delete"
	GameState.placing_building = true
	_show_hint("Click a building to remove it · right-click to cancel")

func _clear() -> void:
	mode = ""
	GameState.placing_building = false
	build_name = ""
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if hint != null:
		hint.queue_free()
		hint = null

func _process(_d: float) -> void:
	if mode != "build" or ghost == null:
		return
	var mx := get_global_mouse_position().x
	ghost.global_position = Vector2(mx - build_w / 2.0, VILLAGE_Y - ghost.size.y)
	var p = get_tree().get_first_node_in_group("player")
	var ok := GameState.can_place_building(get_tree(), build_w, mx) \
		and p != null and GameState.can_afford_build(build_name, p)
	ghost.color = Color(0.35, 0.9, 0.5, 0.42) if ok else Color(0.95, 0.3, 0.3, 0.42)

# _input (not _unhandled_input): grab the click BEFORE any building's Area2D or
# the world eats it, so a delete/place click always lands (dev: "delete didn't
# work on ruins").
func _input(event: InputEvent) -> void:
	if mode == "":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_clear()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var wx := get_global_mouse_position().x
			if mode == "build":
				_try_place(wx)
			elif mode == "delete":
				_try_delete(wx)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear()

func _try_place(x: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if not GameState.can_place_building(get_tree(), build_w, x):
		if stack: stack.show_notification("Can't build there — need clear ground inside the walls.")
		return
	if p == null or not GameState.can_afford_build(build_name, p):
		if stack: stack.show_notification("Not enough materials for the %s." % build_name)
		return
	GameState.pay_build(build_name, p)
	# A COTTAGE has no pre-placed ruin -- build a brand-new home on the chosen spot
	# and remember its ground so it comes back there (see main.generate_houses).
	if build_name == "Cottage":
		var pal = HOUSE_PALETTES[GameState.extra_cottages % HOUSE_PALETTES.size()]
		var home = HOUSE_SCRIPT.new()
		home.house_id = "menu_house_%d" % GameState.extra_cottages
		home.house_name = "Cottage %d" % (6 + GameState.extra_cottages)
		home.body_color = pal.body
		home.roof_color = pal.roof
		home.position = Vector2(x, VILLAGE_Y)
		var village = get_tree().current_scene.get_node_or_null("Village")
		(village if village != null else get_tree().current_scene).add_child(home)
		GameState.extra_cottage_positions.append(x)
		GameState.extra_cottages += 1
		GameState.play_sfx(GameState.SFX_YES, 1.0)
		var st = get_tree().get_first_node_in_group("notification_stack")
		if st: st.show_notification("🏠 A new cottage is raised.")
		GameState.log_event("village", "A cottage was raised from the build menu.")
		_clear()
		return
	# raise it at the chosen spot: the site exists as a ruin, so move it + finish it
	GameState.building_positions[build_name] = x
	GameState.building_cleared[build_name] = GameState.CLEAR_STEPS
	GameState.building_stage[build_name] = GameState.TOTAL_BUILD_STAGES
	GameState.removed_buildings.erase(build_name)
	var node = _find_building(build_name)
	if node != null:
		node.global_position.x = x
		if node.has_method("rebuild_geometry"): node.rebuild_geometry()
		if node.has_method("refresh_visual"): node.refresh_visual()
	GameState.play_sfx(GameState.SFX_YES, 1.0)
	if stack: stack.show_notification("🏗 The %s is raised on its new ground." % build_name)
	GameState.log_event("village", "The %s was raised from the build menu." % build_name)
	_clear()

func _try_delete(x: float) -> void:
	var target = _building_at(x)
	if target != null:
		_confirm_delete(str(target.building_name))

func _find_building(bname: String):
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and str(b.building_name) == bname:
			return b
	return null

func _building_at(x: float):
	for b in get_tree().get_nodes_in_group("building"):
		if not ("building_name" in b and "width" in b):
			continue
		if absf(x - b.global_position.x) <= float(b.width) / 2.0 + 24.0:
			return b
	return null

# The YES/NO panel: "This building will be deleted forever. Continue?"
func _confirm_delete(bname: String) -> void:
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -230.0; panel.offset_right = 230.0
	panel.offset_top = -80.0; panel.offset_bottom = 80.0
	ui.add_child(panel)
	var msg := Label.new()
	msg.text = "The %s will be deleted FOREVER.\nAre you sure you want to continue?" % bname
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 15)
	msg.position = Vector2(20, 22); msg.size = Vector2(420, 60)
	panel.add_child(msg)
	var yes := Button.new()
	yes.text = "YES, delete it"
	yes.position = Vector2(40, 108); yes.size = Vector2(170, 34)
	panel.add_child(yes)
	var no := Button.new()
	no.text = "NO, keep it"
	no.position = Vector2(250, 108); no.size = Vector2(170, 34)
	panel.add_child(no)
	yes.pressed.connect(func() -> void:
		GameState.remove_building(bname)
		var n = _find_building(bname)
		if n != null: n.queue_free()
		GameState.play_sfx(GameState.SFX_THUD, 1.0)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack: stack.show_notification("The %s was cleared away." % bname)
		panel.queue_free()
		_clear())
	no.pressed.connect(func() -> void:
		panel.queue_free())

func _show_hint(text: String) -> void:
	hint = Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.offset_top = 90.0; hint.offset_bottom = 116.0
	ui.add_child(hint)
