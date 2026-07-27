extends CanvasLayer

const COLUMNS = 6
const ROWS = 4
const SLOT_SIZE = 40.0
const SLOT_GAP = 6.0
const ICON_MARGIN = 6.0
const GRID_ORIGIN = Vector2(16.0, 46.0)
const BUTTON_H = 32.0        # matches the Take/Deposit/Close buttons in the .tscn
const BUTTON_PITCH = 104.0   # x-spacing of the Take All / Deposit All / Match row

# Terraria pixel-box slots, matching the inventory: slate border + dark fill.
const SLOT_BORDER_COLOR = Color(0.34, 0.38, 0.52, 0.95)
const SLOT_FILL_COLOR = Color(0.10, 0.12, 0.17, 0.92)

var player: Node2D
var current_chest: Node = null
var slot_bgs: Array = []
var slot_icons: Array = []
var slot_counts: Array = []

var item_buttons: Array = []

func _ready() -> void:
	visible = false
	add_to_group("esc_window")
	add_to_group("chest_ui")   # so vault chests can find the shared UI by group
	player = get_tree().get_first_node_in_group("player")
	build_slots(COLUMNS * ROWS)
	$Panel/TakeButton.text = "Take Gold"
	$Panel/DepositButton.text = "Deposit Gold"
	$Panel/TakeButton.pressed.connect(_on_take_coins)
	$Panel/DepositButton.pressed.connect(_on_deposit_coins)
	$Panel/CloseButton.pressed.connect(close)
	# QoL (dev request): whole-container ITEM transfers on their own row --
	# plus SHIFT-CLICK on any stack to flick it across instantly
	for def in [["⇈ Take All", _on_take_all], ["⇊ Deposit All", _on_deposit_all], ["⇄ Match", _on_deposit_matching]]:
		var b := Button.new()
		b.text = def[0]
		b.custom_minimum_size = Vector2(96, BUTTON_H)
		b.pressed.connect(def[1])
		if str(def[0]).contains("Match"):
			b.tooltip_text = "Deposit only what the chest already holds — restock its stores"
		$Panel.add_child(b)
		item_buttons.append(b)
	DragState.register_panel(self)

# Rebuild the slot grid to hold exactly `count` slots (6 per row, growing
# downward), then resize the panel and drop the buttons below the grid. Most
# chests are the standard 24; the Proving Grounds vaults are much bigger, so the
# grid has to grow to fit them rather than hiding items past slot 24.
# the inset dark fills, tracked like the other three per-slot nodes (audit
# fix: they were added to $Panel and forgotten, so every grid RESIZE -- open a
# huge Proving vault, then a normal 24-slot chest -- orphaned a vault's worth
# of phantom squares onto the panel, growing with each differently-sized chest)
var slot_fills: Array = []

func _ensure_grid(count: int) -> void:
	if slot_bgs.size() == count:
		return
	for arr in [slot_bgs, slot_icons, slot_counts, slot_fills]:
		for n in arr:
			if is_instance_valid(n):
				n.queue_free()
	slot_bgs.clear(); slot_icons.clear(); slot_counts.clear(); slot_fills.clear()
	build_slots(count)

func _layout_panel(count: int) -> void:
	var rows: int = int(ceil(float(count) / float(COLUMNS)))
	var btn_y: float = GRID_ORIGIN.y + rows * (SLOT_SIZE + SLOT_GAP) + 16.0
	# two button rows now: items above, gold + close below
	var item_y: float = btn_y
	var gold_y: float = btn_y + BUTTON_H + 8.0
	var panel_h: float = gold_y + BUTTON_H + 12.0
	var half: float = panel_h / 2.0
	$Panel.offset_top = -half
	$Panel.offset_bottom = half
	# The three transfer buttons sit on a 104px pitch and the .tscn panel is 302
	# wide, so "⇄ Match" ran off the right edge -- invisible until the theme gave
	# panels a border to run off. Widen the panel to whatever the row needs (the
	# panel is RIGHT-anchored, so only offset_left moves).
	var row_w: float = 16.0 + item_buttons.size() * BUTTON_PITCH + 16.0
	var panel_w: float = maxf(row_w, GRID_ORIGIN.x * 2.0 + COLUMNS * (SLOT_SIZE + SLOT_GAP))
	$Panel.offset_left = $Panel.offset_right - panel_w
	for i in range(item_buttons.size()):
		item_buttons[i].position = Vector2(16.0 + i * BUTTON_PITCH, item_y)
	for btn in [$Panel/TakeButton, $Panel/DepositButton, $Panel/CloseButton]:
		btn.position.y = gold_y

func build_slots(count: int) -> void:
	for i in range(count):
		var col = i % COLUMNS
		var row = i / COLUMNS
		var pos = GRID_ORIGIN + Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))

		var bg = ColorRect.new()
		bg.color = SLOT_BORDER_COLOR                     # frame; fill sits on top
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = pos
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(_on_slot_gui_input.bind(i))
		bg.mouse_entered.connect(_on_slot_hover.bind(i))
		bg.mouse_exited.connect(_on_slot_unhover)
		$Panel.add_child(bg)
		slot_bgs.append(bg)

		var fill = ColorRect.new()                       # inset dark fill -> border ring shows
		fill.color = SLOT_FILL_COLOR
		fill.size = Vector2(SLOT_SIZE - 4.0, SLOT_SIZE - 4.0)
		fill.position = pos + Vector2(2.0, 2.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.add_child(fill)
		slot_fills.append(fill)

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
		if Input.is_key_pressed(KEY_SHIFT):
			quick_transfer_from_chest(index)   # flick the stack to your bag
		elif DragState.split_mode:
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
	var cap: int = chest.inventory.capacity if chest and chest.inventory else COLUMNS * ROWS
	_ensure_grid(cap)
	_layout_panel(cap)
	# the coin Take-All/Deposit-All buttons only make sense for real loot chests;
	# on a disposable vault "Deposit All" would sink your gold into it, so hide them
	var is_vault: bool = "ui_title" in chest and chest.ui_title != ""
	$Panel/TakeButton.visible = not is_vault
	$Panel/DepositButton.visible = not is_vault
	visible = true
	refresh()

func close() -> void:
	if current_chest:
		# Resolve any in-flight right-click split BEFORE the snapshot: a split has
		# already pulled its items out of the source inventory into the hand, so
		# saving first wrote a chest state WITHOUT them -- DragState's orphan
		# self-heal then returned them to the live Inventory object a frame
		# later, and nothing ever re-serialised it. Walk out of the chest's
		# radius mid-split, take one dungeon trip: those items were gone.
		if DragState.split_mode:
			DragState.return_split_to_source()
			DragState.refresh_all_panels()
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
	# vault chests carry their own title; ordinary chests show their coin count
	if current_chest and "ui_title" in current_chest and current_chest.ui_title != "":
		$Panel/TitleLabel.text = current_chest.ui_title
	else:
		$Panel/TitleLabel.text = "Chest (" + str(inv.get_count("coin_gold")) + "g coins)"

# --- whole-container ITEM transfers (dev request) ---
# transfer_to handles stacking and space honestly: what doesn't fit stays
# where it was, and the toast says exactly what moved.

func _bulk_transfer(src: Inventory, dst: Inventory, keep_wielded: bool, matching_only := false) -> void:
	var moved_total := 0
	var stacks: Array = []
	for slot in src.slots:
		if slot != null:
			stacks.append({"id": str(slot.item_id), "count": int(slot.count)})
	for s in stacks:
		# never strand the weapon in your hand inside a box
		if keep_wielded and player and s.id == str(player.active_weapon_id):
			continue
		if matching_only and dst.get_count(s.id) <= 0:
			continue
		moved_total += src.transfer_to(dst, s.id, s.count)
	refresh()
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()
	var stack_node = get_tree().get_first_node_in_group("notification_stack")
	if stack_node:
		if moved_total > 0:
			stack_node.show_notification("Moved %d item%s." % [moved_total, "" if moved_total == 1 else "s"])
		else:
			stack_node.show_notification("Nothing to move — or no room for it.")

func _on_take_all() -> void:
	if current_chest and player:
		_bulk_transfer(current_chest.inventory, player.inventory, false)

func _on_deposit_all() -> void:
	if current_chest and player:
		_bulk_transfer(player.inventory, current_chest.inventory, true)

func _on_deposit_matching() -> void:
	if current_chest and player:
		_bulk_transfer(player.inventory, current_chest.inventory, true, true)

# SHIFT-CLICK: flick one whole stack across without dragging.
func quick_transfer_from_chest(index: int) -> void:
	if not current_chest or index >= current_chest.inventory.slots.size():
		return
	# same guard its siblings carry (audit fix): this was the one path that
	# dereferenced player.inventory without checking the player exists
	if player == null or not is_instance_valid(player) or player.inventory == null:
		return
	var slot = current_chest.inventory.slots[index]
	if slot == null:
		return
	current_chest.inventory.transfer_to(player.inventory, str(slot.item_id), int(slot.count))
	refresh()
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()

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
