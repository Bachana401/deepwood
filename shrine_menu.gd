extends CanvasLayer
# The fast-travel menu shared by the village WAYSTONE and every woken DEEP SHRINE
# (Wukong-style, dev 2026-07-21). Lists every shrine you have woken (Floor
# 10/20/...) plus "Return to the Village" when you are down in the deep. Pick one
# and you leap there, arriving at that floor's shrine. Built procedurally so it
# needs no .tscn; pauses the tree and runs while paused so its buttons still work.

var _return_pos := Vector2.ZERO

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

# return_pos: where LEAVING a travelled-to floor drops you back -- the village
# Waystone if one stands, else the default village spawn.
func open(return_pos: Vector2) -> void:
	_return_pos = return_pos
	_build()
	visible = true
	get_tree().paused = true

func close() -> void:
	if get_tree() != null:
		get_tree().paused = false
	queue_free()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(380.0, 0.0)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "▲  WAYSTONE  —  TRAVEL"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Leap to any Deep Shrine you have woken."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.82, 0.84, 0.92)
	vb.add_child(sub)
	vb.add_child(HSeparator.new())

	if GameState.in_dungeon:
		var home := Button.new()
		home.text = "⌂   Return to the Village"
		home.pressed.connect(_go_home)
		vb.add_child(home)

	var offered := 0
	for f in GameState.revealed_shrines():
		if GameState.in_dungeon and int(f) == GameState.active_dungeon_level:
			continue                        # you are already at this one
		var b := Button.new()
		b.text = "▲   Deep Shrine  —  Floor %d" % int(f)
		b.pressed.connect(_travel.bind(int(f)))
		vb.add_child(b)
		offered += 1
	if offered == 0 and not GameState.in_dungeon:
		var none := Label.new()
		none.text = "No shrines woken yet.\nClear floor 10, 20, 30 … to wake one."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.modulate = Color(0.75, 0.75, 0.82)
		vb.add_child(none)

	vb.add_child(HSeparator.new())
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(close)
	vb.add_child(cancel)

func _travel(floor: int) -> void:
	if GameState.harvest_at_home:
		close()
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# the exact carry-over the doors + level-select use, so the swap is seamless
	# you can only reach here for a REVEALED shrine (a cleared floor), so arrival
	# is combat-free at the entry where the shrine stands -- no special flag needed
	GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.pre_dungeon_position = _return_pos
	# pre_dungeon_position is now a VILLAGE-space point, so the floor's exit must
	# route to the village. Without this, a floor first entered through a tile-
	# underground door kept came_from_underground=true and its exit gate warped
	# into underground.tscn at village coordinates -- solid rock, ~19,000px from
	# the ladder. (level_select_ui clears the flag the same way; the shrine was
	# the one launch route that didn't.)
	GameState.came_from_underground = false
	GameState.active_dungeon_level = floor
	_warp_to("res://dungeon_interior.tscn")

func _go_home() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		GameState.pending_player_state = GameState.capture_player_state(player)
	# Land somewhere REAL. main.gd applies pre_dungeon_position verbatim on the
	# returning_from_dungeon path, and for a floor entered via a tile-underground
	# door that was a deep-underground coordinate -- applied in the village scene
	# it put the player in empty sky (or worse), falling forever. _return_pos is
	# always a village-space point (the Waystone if one stands, else the spawn).
	GameState.pre_dungeon_position = _return_pos
	GameState.came_from_underground = false
	GameState.in_dungeon = false
	GameState.returning_from_dungeon = true
	_warp_to("res://main.tscn")

# A quick warp flash before the hard cut -- the screen floods with the shrine's
# light and you are elsewhere. The tree STAYS paused through the flash (this
# layer is PROCESS_MODE_ALWAYS and the tween is told to tick through the pause),
# so the 0.3s window is not live gameplay the player can't answer -- a Waystone
# leap started during a siege used to eat 300ms of unanswerable damage here.
func _warp_to(scene_path: String) -> void:
	for c in get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE      # no stray clicks mid-warp
	var flash := ColorRect.new()
	flash.color = Color(0.6, 0.92, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash, "color:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	# The cut rides a TREE-owned timer, not an await on this node: if something
	# frees this layer mid-flash (a quit), an awaited coroutine would die and
	# strand the tree paused forever. SceneTreeTimers tick through pause.
	var tree := get_tree()
	tree.create_timer(0.30).timeout.connect(func():
		if not is_instance_valid(self):
			return   # whatever freed us owns the pause/scene state now
		tree.paused = false
		tree.change_scene_to_file(scene_path))
