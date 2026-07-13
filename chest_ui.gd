extends CanvasLayer

const COLUMNS = 6
const ROWS = 4
const SLOT_SIZE = 40.0
const SLOT_GAP = 6.0
const ICON_MARGIN = 6.0
const GRID_ORIGIN = Vector2(16.0, 46.0)

const SLOT_BG_COLOR = Color(0.15, 0.15, 0.18, 0.9)

var player: Node2D
var current_chest: Node = null
var slot_bgs: Array = []
var slot_icons: Array = []
var slot_counts: Array = []

func _ready() -> void:
	visible = false
	add_to_group("esc_window")
	player = get_tree().get_first_node_in_group("player")
	build_slots()
	$Panel/TakeButton.pressed.connect(_on_take_coins)
	$Panel/DepositButton.pressed.connect(_on_deposit_coins)
	$Panel/CloseButton.pressed.connect(close)
	DragState.register_panel(self)

func build_slots() -> void:
	for i in range(COLUMNS * ROWS):
		var col = i % COLUMNS
		var row = i / COLUMNS
		var pos = GRID_ORIGIN + Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))

		var bg = ColorRect.new()
		bg.color = SLOT_BG_COLOR
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = pos
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(_on_slot_gui_input.bind(i))
		bg.mouse_entered.connect(_on_slot_hover.bind(i))
		bg.mouse_exited.connect(_on_slot_unhover)
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
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		count_label.add_theme_constant_override("outline_size", 3)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.position = pos + Vector2(0, SLOT_SIZE - 16)
		count_label.size = Vector2(SLOT_SIZE - 4, 14)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.add_child(count_label)
		slot_counts.append(count_label)

func _on_slot_hover(index: int) -> void:
	if not current_chest or index >= current_chest.inventory.slots.size():
		return
	var slot = current_chest.inventory.slots[index]
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip and slot != null:
		tip.show_for(slot.item_id)

func _on_slot_unhover() -> void:
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip:
		tip.hide_tooltip()

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not current_chest:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if DragState.split_mode:
			DragState.deposit_split(current_chest.inventory, index)
		else:
			DragState.start_drag(current_chest.inventory, index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		DragState.start_or_continue_split(current_chest.inventory, index)

func get_slot_at_global(pos: Vector2) -> int:
	if not current_chest:
		return -1
	for i in range(slot_bgs.size()):
		var bg = slot_bgs[i]
		if Rect2(bg.global_position, bg.size).has_point(pos):
			return i
	return -1

func get_inventory_for_drag() -> Inventory:
	return current_chest.inventory if current_chest else null

func open_chest(chest: Node) -> void:
	current_chest = chest
	visible = true
	refresh()

func close() -> void:
	if current_chest:
		current_chest.save_contents()
	current_chest = null
	visible = false

func esc_is_open() -> bool:
	return current_chest != null

func esc_close() -> void:
	close()

func refresh() -> void:
	if not current_chest:
		return
	var inv = current_chest.inventory
	for i in range(slot_icons.size()):
		if i >= inv.slots.size():
			slot_icons[i].visible = false
			slot_counts[i].text = ""
			continue
		var slot = inv.slots[i]
		if slot == null:
			slot_icons[i].visible = false
			slot_counts[i].text = ""
		else:
			slot_icons[i].visible = true
			Inventory.paint_icon(slot_icons[i], slot.item_id)
			slot_counts[i].text = str(slot.count) if slot.count > 1 else ""
	$Panel/TitleLabel.text = "Chest (" + str(inv.get_count("coin_gold")) + "g coins)"

func _on_take_coins() -> void:
	if not current_chest or not player:
		return
	var moved = current_chest.inventory.transfer_to(player.inventory, "coin_gold", current_chest.inventory.get_count("coin_gold"))
	if moved > 0:
		player.update_currency_display()
	refresh()

func _on_deposit_coins() -> void:
	if not current_chest or not player:
		return
	var moved = player.inventory.transfer_to(current_chest.inventory, "coin_gold", player.inventory.get_count("coin_gold"))
	if moved > 0:
		player.update_currency_display()
	refresh()
