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
var _confirming := false    # a YES/NO panel is open -- let the BUTTONS get the click
var _confirm_panel: Node = null   # tracked so _clear() can tear down a stale delete dialog
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

# If the village scene is torn down (you dive into a dungeon) while a build/delete
# is in progress, _clear() never runs -- so clear the flag here, or the player
# would be unable to attack in the dungeon (it gates on placing_building).
func _exit_tree() -> void:
	GameState.placing_building = false

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
	_show_hint("Click a building, wall or cottage to remove it · right-click to cancel")

func _clear() -> void:
	mode = ""
	_confirming = false
	GameState.placing_building = false
	build_name = ""
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if hint != null:
		hint.queue_free()
		hint = null
	# a delete confirm left open when a new build/delete starts would linger, still wired to
	# the OLD target -- clicking its YES then deletes the wrong building. Tear it down.
	if _confirm_panel != null and is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	_confirm_panel = null

func _process(_d: float) -> void:
	if mode != "build" or ghost == null:
		return
	var mx := get_global_mouse_position().x
	ghost.global_position = Vector2(mx - build_w / 2.0, VILLAGE_Y - ghost.size.y)
	var p = get_tree().get_first_node_in_group("player")
	# exclude the hall's OWN node (audit fix): re-raising a razed building on or
	# near its old ground was refused by the very ruin being rebuilt -- the
	# `exclude` parameter existed for exactly this and was never passed
	var ok := GameState.can_place_building(get_tree(), build_w, mx, _find_building(build_name), build_name == "Wall") \
		and p != null and GameState.can_afford_build(build_name, p)
	# a flank that already holds a wall can't take a second (you upgrade at the gate) --
	# the ghost must read RED there too, or "green always means it will build" is broken.
	if ok and build_name == "Wall" and _flank_has_wall(_flank_for_x(mx)):
		ok = false
	ghost.color = Color(0.35, 0.9, 0.5, 0.42) if ok else Color(0.95, 0.3, 0.3, 0.42)
	# A WALL's hint reads the ground LIVE: which gate would this spot guard? The
	# tutorial says "the west" but nothing at placement-time did (dev 2026-07-23:
	# "placed the wall as instructed... the wave passed through") -- so say it under
	# the cursor, and warn plainly when the ground guards the quiet east instead.
	if build_name == "Wall" and hint != null:
		var f := _flank_for_x(mx)
		if f == "west":
			hint.text = "This ground guards the WEST gate — where the dark climbs out. Left-click on GREEN."
		else:
			hint.text = "⚠ This ground guards the EAST road (quiet until far deeper). The dark comes from the WEST — walk left of the village."

# _input (not _unhandled_input): grab the click BEFORE any building's Area2D or
# the world eats it, so a delete/place click always lands (dev: "delete didn't
# work on ruins").
func _input(event: InputEvent) -> void:
	# While the delete-confirm panel is open, do NOT swallow CLICKS -- the YES/NO
	# buttons need them (dev: "I press YES/NO, no effect"). ESC and right-click
	# still have to cancel it though: without this the obvious escape key fell
	# through to the pause menu and paused the game UNDER a modal whose buttons
	# are pausable, i.e. the dialog stopped responding until you unpaused.
	if _confirming:
		if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) \
				or (event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_RIGHT):
			_cancel_confirm()
			get_viewport().set_input_as_handled()
		return
	if mode == "":
		return
	# ...and NEVER steal a click that belongs to an open window. This runs before
	# GUI dispatch by design, so with a mode armed it used to eat the press meant
	# for whatever panel was on screen: clicking "Upgrade" in the assign panel
	# instead popped "this building will be deleted FOREVER" for whatever sat
	# under the WORLD cursor. Cancelling on the Ledger alone was not enough --
	# any esc_window counts.
	if _a_window_is_open():
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
		get_viewport().set_input_as_handled()   # else the same Esc also toggles the pause menu

# Is any of the game's windows on screen right now? (Same group the player's
# world-input guard uses, so the two can never disagree about "a panel is open".)
func _a_window_is_open() -> bool:
	for w in get_tree().get_nodes_in_group("esc_window"):
		if is_instance_valid(w) and w.has_method("esc_is_open") and w.esc_is_open():
			return true
	return false

func _try_place(x: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	var stack = get_tree().get_first_node_in_group("notification_stack")
	# THE FORGE IS MID-GAME (dungeon depth 35). The old ruin-repair path checked
	# blacksmith_unlocked() but became dead code when ruins went inert -- this,
	# the only LIVE build path, never did, so the blueprint (floor 16) raised a
	# fully-stocked gear vendor 19 floors early. Checked before anything charges.
	if build_name == "Blacksmith" and not GameState.blacksmith_unlocked():
		if stack: stack.show_notification("The Forge's fire won't take — its secrets lie deeper. (Clear dungeon floor %d.)" % GameState.BLACKSMITH_UNLOCK_DEPTH)
		return
	# same exclude as the ghost (audit fix): green must mean "it will build"
	if not GameState.can_place_building(get_tree(), build_w, x, _find_building(build_name), build_name == "Wall"):
		if stack: stack.show_notification("Can't build there — need clear ground inside the walls.")
		return
	# ONE rampart per flank (dev 2026-07-23: "at level 15 the player can place 2
	# walls"). A flank that already holds a wall can't take a second -- you UPGRADE the
	# standing rampart at the gate (press E), you never stack a fresh one beside it.
	# Checked BEFORE we charge, so a refused placement costs nothing.
	if build_name == "Wall":
		var f := _flank_for_x(x)
		if _flank_has_wall(f):
			if stack: stack.show_notification("The %s rampart already stands — upgrade it at the gate (press E)." % f)
			return
	if p == null or not GameState.can_afford_build(build_name, p):
		if stack: stack.show_notification("Not enough materials for the %s." % build_name)
		return
	GameState.pay_build(build_name, p)
	# A WALL is raised fresh (walls start removed now). Its flank faces OUTWARD --
	# west if placed left of the village's middle, east if right -- and it persists
	# in GameState.placed_walls so main.gd re-raises it on every scene build.
	if build_name == "Wall":
		var wall = preload("res://wall.tscn").instantiate()
		wall.flank = _flank_for_x(x)
		wall.position = Vector2(x, VILLAGE_Y)
		var vil = get_tree().current_scene.get_node_or_null("Village")
		(vil if vil != null else get_tree().current_scene).add_child(wall)
		GameState.placed_walls.append({"x": x, "flank": str(wall.flank)})
		GameState.play_sfx(GameState.SFX_YES, 1.0)
		var stk = get_tree().get_first_node_in_group("notification_stack")
		if stk: stk.show_notification("🧱 A rampart rises.")
		GameState.log_event("village", "A wall was raised from the build menu.")
		GameState.tutorial_note("Wall")
		_clear()
		return
	# A COTTAGE has no pre-placed ruin -- build a brand-new home on the chosen spot
	# and remember its ground so it comes back there (see main.generate_houses).
	if build_name == "Cottage":
		var pal = HOUSE_PALETTES[GameState.extra_cottages % HOUSE_PALETTES.size()]
		var home = HOUSE_SCRIPT.new()
		home.house_name = "Cottage %d" % (6 + GameState.extra_cottages)
		home.body_color = pal.body
		home.roof_color = pal.roof
		home.position = Vector2(x, VILLAGE_Y)
		# ONE id source: register on the chosen ground and take the STABLE id back (set
		# before add_child), so a later middle-delete can never shift it or collide the
		# next build (dev 2026-07-23).
		home.house_id = GameState.register_cottage(x)
		var village = get_tree().current_scene.get_node_or_null("Village")
		(village if village != null else get_tree().current_scene).add_child(home)
		GameState.play_sfx(GameState.SFX_YES, 1.0)
		var st = get_tree().get_first_node_in_group("notification_stack")
		if st: st.show_notification("🏠 A new cottage is raised.")
		GameState.log_event("village", "A cottage was raised from the build menu.")
		GameState.tutorial_note("Cottage")
		_clear()
		return
	# raise it at the chosen spot: the site exists as a ruin, so move it + finish it
	GameState.building_positions[build_name] = x
	GameState.building_cleared[build_name] = GameState.CLEAR_STEPS
	GameState.building_stage[build_name] = GameState.TOTAL_BUILD_STAGES
	GameState.removed_buildings.erase(build_name)
	var node = _find_building(build_name)
	if node == null:
		# its ruin was deleted -- there's no node to raise, so make a fresh one
		var scene = get_tree().current_scene
		if scene != null and scene.has_method("create_building"):
			node = scene.create_building(build_name, x)
	if node != null:
		node.global_position.x = x
		# fully re-raise the LIVE node, not just its geometry: without this the node kept
		# build_stage=0/health=0 (still is_ruined + not operational -> no E-panel, no
		# workers, drawn as rubble) until a scene reload, so rebuilding a razed hall from
		# the B-menu did nothing visible (dev bug-sweep 2026-07-25).
		if node.has_method("restore_full"):
			node.restore_full()
		else:
			if node.has_method("rebuild_geometry"): node.rebuild_geometry()
			if node.has_method("refresh_visual"): node.refresh_visual()
	GameState.play_sfx(GameState.SFX_YES, 1.0)
	if stack: stack.show_notification("🏗 The %s is raised on its new ground." % build_name)
	GameState.log_event("village", "The %s was raised from the build menu." % build_name)
	GameState.tutorial_note(build_name)
	_clear()

func _try_delete(x: float) -> void:
	var target = _building_at(x)
	if target != null:
		_confirm_delete(target)

func _find_building(bname: String):
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and str(b.building_name) == bname:
			return b
	return null

# The building/wall/cottage nearest the click. Roster buildings first, then walls,
# then cottages -- so ANY placeable can be removed, not just the 15 halls (dev ask
# 2026-07-23: "make them deletable").
func _building_at(x: float):
	# NEAREST hall wins, at its EFFECTIVE width (audit fix): the old
	# first-match-at-base-width walk made a level-6 building's outer 30%
	# unclickable and could resolve a click between two close halls to
	# whichever happened to come first in the group, not the one under
	# the cursor.
	var best: Node = null
	var best_d := 1.0e9
	for b in get_tree().get_nodes_in_group("building"):
		if not ("building_name" in b and "width" in b):
			continue
		var half: float = (b.eff_w() if b.has_method("eff_w") else float(b.width)) / 2.0
		var d: float = absf(x - b.global_position.x)
		if d <= half + 24.0 and d < best_d:
			best_d = d
			best = b
	if best != null:
		return best
	for w in get_tree().get_nodes_in_group("village_wall"):
		if is_instance_valid(w) and absf(x - w.global_position.x) <= 46.0:
			return w
	for h in get_tree().get_nodes_in_group("village_structure"):
		if is_instance_valid(h) and "house_id" in h and absf(x - h.global_position.x) <= 55.0:
			return h
	return null

# What KIND of thing is this, and a friendly name for the confirm popup.
func _delete_kind(target) -> String:
	if "building_name" in target and target.is_in_group("building"):
		return "building"
	if target.is_in_group("village_wall"):
		return "wall"
	if target.is_in_group("village_structure"):
		return "cottage"
	return "building"

func _delete_label(target, kind: String) -> String:
	match kind:
		"wall": return "%s wall" % str(target.flank) if "flank" in target else "wall"
		"cottage": return "cottage"
		_: return str(target.building_name)

# A wall you RAISED (it lives in placed_walls) can be pulled down; any wall NOT in
# placed_walls is the town's own and must never be deletable, so a misclick can't
# queue_free a rampart GameState still believes stands (its defence gone mid-siege,
# silently re-raised only on the next reload). Player-built is now the norm -- this
# stays as the invariant guard for any future non-placed rampart (dev 2026-07-23).
func _wall_is_player_placed(target) -> bool:
	for entry in GameState.placed_walls:
		if absf(float(entry.get("x", 0.0)) - target.global_position.x) <= 8.0:
			return true
	return false

# The village's mid-x, from the spread of its buildings. A wall placed left of it
# guards the WEST (pit-road) gate; right of it, the EAST gate that wakes at floor 15.
func _village_center_x() -> float:
	var lo := INF
	var hi := -INF
	for b in get_tree().get_nodes_in_group("building"):
		lo = minf(lo, b.global_position.x)
		hi = maxf(hi, b.global_position.x)
	return (lo + hi) * 0.5 if lo != INF else 7000.0

func _flank_for_x(x: float) -> String:
	return "west" if x < _village_center_x() else "east"

# True if this flank already holds a rampart -- checked against BOTH the live nodes
# and placed_walls, so a second placement is refused even before the first wall's
# _ready has joined it to the "village_wall" group.
func _flank_has_wall(flank: String) -> bool:
	for w in get_tree().get_nodes_in_group("village_wall"):
		if is_instance_valid(w) and "flank" in w and str(w.flank) == flank:
			return true
	for entry in GameState.placed_walls:
		if str(entry.get("flank", "")) == flank:
			return true
	return false

func _do_delete(target, kind: String) -> void:
	if not is_instance_valid(target):
		return   # target freed while the confirm panel was open -- don't deref it below
	match kind:
		"building":
			# clear a stale relocate: if you packed this building then deleted it, its
			# name lingered in moving_building and suppressed Hospital/School/Marketplace
			# H-features until the next H-press (dev sweep 2026-07-25).
			if GameState.moving_building == str(target.building_name):
				GameState.moving_building = ""
			GameState.remove_building(str(target.building_name))
			# attachments go with their building (audit fix): the Dock's bridge
			# and the Farm's pasture are SIBLINGS under $Village, so deleting
			# only the hall left a ~1000px invisible collision deck (or a pen
			# full of animals) standing on empty ground -- and rebuilding from
			# the B menu then added a second one on top.
			var att_group := ""
			if str(target.building_name) == "Fishing Dock":
				att_group = "dock_bridge"
			elif str(target.building_name) == "Farm":
				att_group = "farm_pen"
			if att_group != "":
				for att in get_tree().get_nodes_in_group(att_group):
					if is_instance_valid(att):
						att.queue_free()
		"wall":
			GameState.remove_placed_wall(target.global_position.x)
		"cottage":
			GameState.remove_cottage(str(target.house_id) if "house_id" in target else "", target.global_position.x)
	if is_instance_valid(target):
		target.queue_free()

# The YES/NO panel: "This will be deleted forever. Continue?" -- works for any
# placeable (a hall, a rampart, or a cottage).
func _confirm_delete(target: Node) -> void:
	_confirming = true          # stop _input swallowing the YES/NO clicks
	var kind := _delete_kind(target)
	# the town's OWN rampart (not one you raised) can't be torn down -- refuse before
	# the confirm even opens, so a stray click can't strip a flank's defence
	if kind == "wall" and not _wall_is_player_placed(target):
		_confirming = false
		var stk = get_tree().get_first_node_in_group("notification_stack")
		if stk: stk.show_notification("The town's own rampart holds the line — it can't be pulled down.")
		return
	var label := _delete_label(target, kind)
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -230.0; panel.offset_right = 230.0
	panel.offset_top = -80.0; panel.offset_bottom = 80.0
	ui.add_child(panel)
	var msg := Label.new()
	msg.text = "The %s will be deleted FOREVER.\nAre you sure you want to continue?" % label
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 15)
	msg.position = Vector2(20, 22); msg.size = Vector2(420, 60)
	panel.add_child(msg)
	_confirm_panel = panel
	var yes := Button.new()
	yes.text = "YES, delete it"
	yes.position = Vector2(40, 108); yes.size = Vector2(170, 34)
	panel.add_child(yes)
	var no := Button.new()
	no.text = "NO, keep it"
	no.position = Vector2(250, 108); no.size = Vector2(170, 34)
	panel.add_child(no)
	yes.pressed.connect(func() -> void:
		_do_delete(target, kind)
		GameState.play_sfx(GameState.SFX_THUD, 1.0)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack: stack.show_notification("The %s was cleared away." % label)
		_confirm_panel = null
		panel.queue_free()
		_clear())
	no.pressed.connect(_cancel_confirm)

# "NO, keep it" -- also what ESC and right-click do while the dialog is open.
func _cancel_confirm() -> void:
	_confirming = false
	if _confirm_panel != null and is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	_confirm_panel = null

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
