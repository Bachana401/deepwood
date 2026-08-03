extends CanvasLayer
# ── THE FULL MAP, EVERYWHERE (M) ──────────────────────────────────────────────
# The underground grew a Terraria-style fullscreen map and the dev asked for it
# in every scene. The underground keeps its own painter (its world is tiles);
# this is the same map for NODE scenes -- the village and the dungeon floors --
# built from a SNAPSHOT of what is actually there: every building by name,
# every wall, every villager and defender, the ways in and out, the player as
# a pulsing arrowhead. Drag to pan, wheel to zoom anchored at the cursor,
# hover for what things are. M toggles, ESC closes.
#
# A scene owns one of these and feeds it:
#   open_map(rects, markers, live_groups, player)
#     rects       [{rect: Rect2 (world px), color: Color}]      -- the ground truth
#     markers     [{at: Vector2, color: Color, label: String}]  -- named places
#     live_groups {group_name: {color, label}}                  -- moving things,
#                  re-read every frame so people WALK on the chart
const PAD := 260.0                     # world margin around the content

var _root: Node2D = null
var _view: Node2D = null
var _zoom := 1.0
var _drag := false
var _tip: Label = null
var _markers: Array = []
var _live: Dictionary = {}
var _live_dots := {}                   # node -> Polygon2D on the chart
var _player: Node = null
var _player_dot: Polygon2D = null
var _bounds := Rect2()

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 70
	visible = false
	# THE VILLAGE PAUSES THE TREE (its opening, its own menus -- the audit kit's
	# oldest trap). A paused chart is a chart with nobody on it: the engine's
	# _process silently stops while is_processing() still reads true, which cost
	# an hour of "the loop is right, where are the dots". The map lives above
	# the pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")   # ui_blocks_world_input: no swinging through the chart

func open_map(rects: Array, markers: Array, live_groups: Dictionary, player: Node) -> void:
	_teardown()
	_player = player
	_live = live_groups
	_markers = markers
	# world bounds = everything drawn, padded
	_bounds = Rect2(player.global_position, Vector2.ZERO) if player != null else Rect2()
	for r in rects:
		_bounds = _bounds.merge(r.rect)
	for m in markers:
		_bounds = _bounds.expand(m.at)
	_bounds = _bounds.grow(PAD)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.93)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_root = Node2D.new()
	add_child(_root)
	_view = Node2D.new()                            # world-space content, transformed
	_root.add_child(_view)
	for r in rects:
		var p := ColorRect.new()
		p.position = r.rect.position
		p.size = r.rect.size
		p.color = r.color
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.add_child(p)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for m in _markers:
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-9, -9), Vector2(9, -9), Vector2(9, 9), Vector2(-9, 9)])
		dot.color = m.color
		dot.material = add_mat
		dot.position = m.at
		dot.z_index = 4
		_view.add_child(dot)
	_player_dot = Polygon2D.new()
	_player_dot.polygon = PackedVector2Array([Vector2(0, -26), Vector2(20, 18), Vector2(-20, 18)])
	_player_dot.color = Color(1, 1, 1)
	_player_dot.z_index = 6
	_view.add_child(_player_dot)
	# bound to the dot itself: _teardown frees it, and a loop tween outliving its
	# freed target trips the engine's infinite-loop error on every reopen
	var tw := _player_dot.create_tween().set_loops()
	tw.tween_property(_player_dot, "modulate:a", 0.45, 0.5)
	tw.tween_property(_player_dot, "modulate:a", 1.0, 0.5)
	_tip = Label.new()
	_tip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	_tip.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_tip.add_theme_constant_override("outline_size", 6)
	add_child(_tip)
	var hint := Label.new()
	hint.text = "M / ESC close · drag to pan · wheel to zoom · hover for what things are"
	hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.position = Vector2(16, 8)
	add_child(hint)
	# open FITTED: the whole place in view
	var vp := get_viewport().get_visible_rect().size
	_zoom = minf(vp.x / _bounds.size.x, vp.y / _bounds.size.y) * 0.94
	_root.scale = Vector2(_zoom, _zoom)
	_root.position = (vp - _bounds.size * _zoom) * 0.5 - _bounds.position * _zoom
	visible = true

func close_map() -> void:
	visible = false

func _teardown() -> void:
	for c in get_children():
		c.queue_free()
	_live_dots = {}

func _process(_delta: float) -> void:
	if not visible or _view == null:
		return
	if _player != null and is_instance_valid(_player) and _player_dot != null:
		_player_dot.position = _player.global_position
	# the LIVING chart: one dot per member of each live group, made and dropped
	# as they spawn and die, moved every frame -- the village walks on the map
	for gname in _live.keys():
		for n in get_tree().get_nodes_in_group(gname):
			if not is_instance_valid(n) or not (n is Node2D):
				continue
			if not _live_dots.has(n):
				var dot := Polygon2D.new()
				var r := 7.0
				var pts := PackedVector2Array()
				for i in range(8):
					var a := TAU * float(i) / 8.0
					pts.append(Vector2(cos(a), sin(a)) * r)
				dot.polygon = pts
				dot.color = _live[gname].color
				dot.z_index = 5
				dot.set_meta("map_label", String(_live[gname].label))
				_view.add_child(dot)
				_live_dots[n] = dot
			_live_dots[n].position = n.global_position
	for n in _live_dots.keys():
		if not is_instance_valid(n) or not n.is_inside_tree():
			if is_instance_valid(_live_dots[n]):
				_live_dots[n].queue_free()
			_live_dots.erase(n)

# feed events from the owning scene's _unhandled_input; returns true if eaten
func handle_input(e: InputEvent) -> bool:
	if not visible:
		return false
	if e is InputEventKey and e.pressed and not e.echo \
			and (e.keycode == KEY_ESCAPE or e.keycode == KEY_M):
		close_map()
		return true
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				var factor := 1.25 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8
				var nz: float = clampf(_zoom * factor, 0.02, 4.0)
				_root.position = e.position - (e.position - _root.position) * (nz / _zoom)
				_zoom = nz
				_root.scale = Vector2(_zoom, _zoom)
			return true
		if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
			return true
	if e is InputEventMouseMotion:
		if _drag:
			_root.position += e.relative
		_update_tip(e.position)
		return true
	return false

func _update_tip(screen: Vector2) -> void:
	if _tip == null:
		return
	var world: Vector2 = (screen - _root.position) / _zoom
	var reach := 26.0 / maxf(_zoom, 0.001)          # generous at any zoom
	var best := ""
	var best_d := reach
	for m in _markers:                              # named places first
		var d: float = world.distance_to(m.at)
		if d < best_d:
			best_d = d
			best = String(m.label)
	if best == "":
		for n in _live_dots.keys():                 # then whoever is walking past
			if not is_instance_valid(n):
				continue
			var d2: float = world.distance_to(n.global_position)
			if d2 < best_d:
				best_d = d2
				best = _live_name(n)
	_tip.text = best
	_tip.position = screen + Vector2(16, 10)

# a living thing introduces itself as specifically as it can
func _live_name(n: Node) -> String:
	for prop in ["display_name", "villager_name", "adventurer_name", "npc_name", "building_name"]:
		if prop in n and String(n.get(prop)) != "":
			return String(n.get(prop))
	var dot = _live_dots.get(n)
	if dot != null and is_instance_valid(dot):
		return String(dot.get_meta("map_label", "Someone"))
	return "Someone"

# the ui_blocks_world_input contract (player.gd)
func esc_is_open() -> bool:
	return visible

# ...and the OTHER half of the esc_window contract. Joining that group is a promise
# of BOTH esc_is_open() and esc_close(); this half was missing, so pause_menu's
# close_open_windows() saw the chart reporting itself open and then had nothing to
# call -- ESC closed every other window in the game but left the map hanging there.
func esc_close() -> void:
	close_map()
