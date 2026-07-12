extends CanvasLayer

const COLUMNS = 5
const ROWS = 3
const SLOT_SIZE = 48.0
const SLOT_GAP = 8.0
const ICON_MARGIN = 8.0
const GRID_ORIGIN = Vector2(16.0, 48.0)

const SLOT_BG_COLOR = Color(0.15, 0.15, 0.18, 0.9)

var player: Node2D
var slot_bgs: Array = []
var slot_icons: Array = []
var slot_counts: Array = []

func _ready() -> void:
	visible = false
	player = get_tree().get_first_node_in_group("player")
	build_slots()
	DragState.register_panel(self)

func build_slots() -> void:
	var capacity = player.inventory.capacity if player else COLUMNS * ROWS
	for i in range(capacity):
		var col = i % COLUMNS
		var row = i / COLUMNS
		var pos = GRID_ORIGIN + Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))

		var bg = ColorRect.new()
		bg.color = SLOT_BG_COLOR
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = pos
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(_on_slot_gui_input.bind(i))
		$Panel.add_child(bg)
		slot_bgs.append(bg)

		var icon = ColorRect.new()
		icon.size = Vector2(SLOT_SIZE - ICON_MARGIN * 2, SLOT_SIZE - ICON_MARGIN * 2)
		icon.position = pos + Vector2(ICON_MARGIN, ICON_MARGIN)
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.add_child(icon)
		slot_icons.append(icon)

		var count_label = Label.new()
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		count_label.add_theme_constant_override("outline_size", 3)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.position = pos + Vector2(0, SLOT_SIZE - 18)
		count_label.size = Vector2(SLOT_SIZE - 4, 16)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.add_child(count_label)
		slot_counts.append(count_label)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if DragState.split_mode:
			DragState.deposit_split(player.inventory, index)
		else:
			DragState.start_drag(player.inventory, index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		DragState.start_or_continue_split(player.inventory, index)

func get_slot_at_global(pos: Vector2) -> int:
	for i in range(slot_bgs.size()):
		var bg = slot_bgs[i]
		if Rect2(bg.global_position, bg.size).has_point(pos):
			return i
	return -1

func get_inventory_for_drag() -> Inventory:
	return player.inventory

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func refresh() -> void:
	if not player:
		return
	for i in range(player.inventory.capacity):
		var slot = player.inventory.slots[i]
		if slot == null:
			slot_icons[i].visible = false
			slot_counts[i].text = ""
		else:
			var def = Inventory.get_item_def(slot.item_id)
			slot_icons[i].visible = true
			slot_icons[i].color = def.get("color", Color.WHITE)
			slot_counts[i].text = str(slot.count) if slot.count > 1 else ""
