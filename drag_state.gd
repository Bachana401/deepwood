extends CanvasLayer

# Coordinates dragging an item stack between slots -- possibly across two
# different panels (player inventory <-> chest), possibly within the same
# one (reordering). Lives as an autoload so both inventory_ui.gd and
# chest_ui.gd can share one drag session without needing direct references
# to each other.
#
# Release detection is done by POLLING the mouse button state in _process()
# rather than relying on gui_input's release event, since Godot delivers a
# Control's mouse-up to whichever Control initially captured the press, not
# necessarily whatever the cursor is over now -- polling sidesteps that
# entirely and just asks "where is the mouse right now" at release time.

var active = false
var source_inventory: Inventory = null
var source_index = -1

# Right-click stack-splitting: pulls the item 1 at a time into "hand" instead
# of moving the whole stack. Holding the button repeats the pickup at
# RIGHT_HOLD_INTERVAL. A subsequent left-click on a slot deposits whatever's
# currently held there; if the target can't take it all (different item, or
# not enough room), whatever doesn't fit goes back to the source slot rather
# than being lost.
var split_mode = false
var split_item_id = ""
var split_count = 0
var split_source_inventory: Inventory = null
var split_source_index = -1
var right_hold_timer = 0.0
const RIGHT_HOLD_INTERVAL = 0.15

var icon: ColorRect
var count_label: Label

var registered_panels: Array = []

func _ready() -> void:
	layer = 100
	icon = ColorRect.new()
	icon.size = Vector2(32, 32)
	icon.visible = false
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size = Vector2(32, 16)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.visible = false
	add_child(count_label)

func register_panel(panel: Node) -> void:
	registered_panels.append(panel)

func _process(delta: float) -> void:
	if active:
		var mouse_pos = get_viewport().get_mouse_position()
		icon.position = mouse_pos - icon.size / 2.0
		count_label.position = icon.position + Vector2(0, icon.size.y - 14)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			perform_drop(mouse_pos)
	elif split_mode:
		var mouse_pos = get_viewport().get_mouse_position()
		icon.position = mouse_pos - icon.size / 2.0
		count_label.position = icon.position + Vector2(0, icon.size.y - 14)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			right_hold_timer += delta
			if right_hold_timer >= RIGHT_HOLD_INTERVAL:
				right_hold_timer = 0.0
				pick_one_more()
		else:
			right_hold_timer = 0.0

func start_drag(inventory: Inventory, index: int) -> void:
	if active:
		return
	var slot = inventory.slots[index]
	if slot == null:
		return
	active = true
	source_inventory = inventory
	source_index = index
	var def = Inventory.get_item_def(slot.item_id)
	icon.color = def.get("color", Color.WHITE)
	icon.visible = true
	count_label.text = str(slot.count) if slot.count > 1 else ""
	count_label.visible = true

func perform_drop(mouse_pos: Vector2) -> void:
	# THE BIN (dev 2026-07-23): a drop released over a panel's 🗑 discards the held
	# stack outright. Checked before the slots so the bin always wins over a slot
	# it might overlap.
	for panel in registered_panels:
		if not is_instance_valid(panel) or not panel.visible:
			continue
		if panel.has_method("is_over_trash") and panel.is_over_trash(mouse_pos) \
				and source_inventory != null and source_index >= 0:
			var s = source_inventory.slots[source_index]
			if s != null:
				var nm: String = Inventory.get_display_name(str(s.item_id))
				source_inventory.slots[source_index] = null
				var stack = get_tree().get_first_node_in_group("notification_stack")
				if stack: stack.show_notification("🗑 Discarded %s." % nm)
			refresh_all_panels()
			cancel_drag()
			return
	var target_inventory: Inventory = null
	var target_index = -1
	for panel in registered_panels:
		if not is_instance_valid(panel) or not panel.visible:
			continue
		var idx = panel.get_slot_at_global(mouse_pos)
		if idx != -1:
			target_inventory = panel.get_inventory_for_drag()
			target_index = idx
			break
	if target_inventory != null and source_inventory != null:
		source_inventory.transfer_slot(source_index, target_inventory, target_index)
	refresh_all_panels()
	cancel_drag()

func cancel_drag() -> void:
	active = false
	source_inventory = null
	source_index = -1
	icon.visible = false
	count_label.visible = false

func start_or_continue_split(inventory: Inventory, index: int) -> void:
	if active:
		return
	if split_mode:
		# already holding a partial stack -- only the SAME source slot can
		# add more to it. Clicks elsewhere are ignored rather than silently
		# discarding what's already held; deposit it (left-click) first.
		if split_source_inventory == inventory and split_source_index == index:
			pick_one_more()
		return
	var slot = inventory.slots[index]
	if slot == null:
		return
	split_mode = true
	split_source_inventory = inventory
	split_source_index = index
	split_item_id = slot.item_id
	split_count = 0
	right_hold_timer = 0.0
	pick_one_more()

func pick_one_more() -> void:
	var slot = split_source_inventory.slots[split_source_index]
	if slot == null or slot.count <= 0:
		return
	slot.count -= 1
	split_count += 1
	if slot.count <= 0:
		split_source_inventory.slots[split_source_index] = null
	var def = Inventory.get_item_def(split_item_id)
	icon.color = def.get("color", Color.WHITE)
	icon.visible = true
	count_label.text = str(split_count)
	count_label.visible = true
	refresh_all_panels()

func deposit_split(target_inventory: Inventory, target_index: int) -> void:
	if not split_mode:
		return
	var target_slot = target_inventory.slots[target_index]
	if target_slot == null:
		target_inventory.slots[target_index] = {"item_id": split_item_id, "count": split_count}
		split_count = 0
	elif target_slot.item_id == split_item_id:
		var max_stack = Inventory.get_max_stack(split_item_id)
		var space = max_stack - target_slot.count
		var added = min(space, split_count)
		target_slot.count += added
		split_count -= added
	else:
		# different item at the destination -- can't merge into it, return
		# the held amount to the source instead of losing it.
		return_split_to_source()
		refresh_all_panels()
		return
	if split_count > 0:
		return_split_to_source()
	else:
		cancel_split()
	refresh_all_panels()

func return_split_to_source() -> void:
	if split_count > 0 and split_source_inventory != null:
		split_source_inventory.add_item(split_item_id, split_count)
	cancel_split()

func cancel_split() -> void:
	split_mode = false
	split_item_id = ""
	split_count = 0
	split_source_inventory = null
	split_source_index = -1
	right_hold_timer = 0.0
	icon.visible = false
	count_label.visible = false

func refresh_all_panels() -> void:
	for panel in registered_panels:
		if is_instance_valid(panel) and panel.has_method("refresh"):
			panel.refresh()
