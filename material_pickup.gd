extends Node2D

# A dropped material on the ground (dev ask 2026-07-22: "materials like in
# Terraria"). Pops out with a little toss, rests, then MAGNETS to the player and
# is collected when close -- the Terraria vacuum. Spawned by harvest_node (and
# reusable for enemy drops). Carries an item_id + count; draws the item's own
# icon so a dropped stone reads as stone.

const MAGNET_RANGE := 84.0
const COLLECT_RANGE := 15.0
const MAGNET_SPEED := 300.0
const DESPAWN_SECONDS := 120.0
const ICON_SIZE := 22.0

var item_id := ""
var count := 1
var _armed := false          # collectible only after the toss settles
var _icon: ColorRect = null
var _count_lbl: Label = null

func _ready() -> void:
	z_index = 20
	add_to_group("material_pickup")

# MUST be called AFTER add_child (it needs to be in the tree for the position,
# the tween, and the despawn timer). harvest_node._drop does exactly that.
func setup(id: String, n: int, at: Vector2) -> void:
	item_id = id
	count = n
	global_position = at
	_build_visual()
	_pop_out()
	get_tree().create_timer(DESPAWN_SECONDS).timeout.connect(func(): if is_inside_tree(): queue_free())

func _build_visual() -> void:
	_icon = ColorRect.new()
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	Inventory.paint_icon(_icon, item_id)
	_refresh_count()

func _refresh_count() -> void:
	if count > 1:
		if _count_lbl == null:
			_count_lbl = Label.new()
			_count_lbl.add_theme_font_size_override("font_size", 11)
			_count_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			_count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			_count_lbl.add_theme_constant_override("outline_size", 3)
			_count_lbl.position = Vector2(3.0, -1.0)
			add_child(_count_lbl)
		_count_lbl.text = "x%d" % count
	elif _count_lbl:
		_count_lbl.text = ""

func _pop_out() -> void:
	# a little toss: up and out, then land, THEN it becomes collectible
	var dx := randf_range(-24.0, 24.0)
	var apex := global_position + Vector2(dx * 0.5, randf_range(-34.0, -50.0))
	var land := global_position + Vector2(dx, randf_range(-2.0, 6.0))
	var t := create_tween()
	t.tween_property(self, "global_position", apex, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", land, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_arm)

func _arm() -> void:
	_armed = true

func _process(delta: float) -> void:
	if not _armed:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var target: Vector2 = p.global_position + Vector2(0, -22.0)
	var d := global_position.distance_to(target)
	if d < MAGNET_RANGE:
		global_position = global_position.move_toward(target, MAGNET_SPEED * delta)
	if d < COLLECT_RANGE:
		_collect(p)

func _collect(p: Node) -> void:
	if not ("inventory" in p) or p.inventory == null:
		return
	var added: int = p.inventory.add_item(item_id, count)
	if added <= 0:
		return   # bag full -- leave it on the ground for later
	count -= added
	if count > 0:
		_refresh_count()   # partial pickup; the rest waits
		return
	GameState.play_sfx(GameState.SFX_YES, 1.5)
	queue_free()
