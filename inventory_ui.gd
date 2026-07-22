extends CanvasLayer

const COLUMNS = 5
const ROWS = 3
# Terraria-tight pixel slots (dev ask 2026-07-22): a compact grid of bordered
# boxes rather than fat flat squares.
const SLOT_SIZE = 40.0
const SLOT_GAP = 6.0
const ICON_MARGIN = 6.0
const GRID_ORIGIN = Vector2(16.0, 48.0)
# tallest the bag may get in UI units -- the base viewport is 648 high, so this
# leaves a margin top and bottom no matter how many slots the player carries.
const MAX_PANEL_H = 560.0
const PANEL_MARGIN_X = 24.0   # matches the .tscn's left offset

# Each slot is a pixel box: a slate-blue border frame (the interactive node,
# full-size for the drag hit-test) with a dark-navy fill inset on top, matching
# the item tooltip's palette.
const SLOT_BORDER_COLOR = Color(0.34, 0.38, 0.52, 0.95)
const SLOT_FILL_COLOR = Color(0.10, 0.12, 0.17, 0.92)

var player: Node2D
var panel_w := 304.0   # computed in build_slots from the real capacity
var slot_bgs: Array = []
var slot_icons: Array = []
var slot_counts: Array = []

func _ready() -> void:
	visible = false
	add_to_group("inventory_ui")  # so the gear panel can trigger a redraw
	add_to_group("esc_window")    # ESC closes it (see pause_menu)
	player = get_tree().get_first_node_in_group("player")
	build_slots()
	build_close_button()
	build_craft_panel()
	DragState.register_panel(self)

# --- THE CRAFTING BENCH (polish 2026-07-20) ---
# GameState.try_craft, CRAFT_RECIPES and even Toren's cost discount all
# existed and worked -- with NO way in. Four recipes (three foods and the
# Reset Potion) were unreachable for the whole game; the comment in
# inventory.gd literally referred to "the crafting popup in inventory_ui"
# that was never built. Here it is: a bench beside the bag, showing every
# recipe, what it needs, and what you have.
var craft_panel: Panel = null
var craft_rows: VBoxContainer = null

func build_craft_panel() -> void:
	var btn := Button.new()
	btn.position = Vector2(panel_w - 34, 36)
	btn.size = Vector2(26, 22)
	btn.add_theme_font_size_override("font_size", 13)
	btn.text = "⚒"
	btn.tooltip_text = "Crafting"
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func():
		craft_panel.visible = not craft_panel.visible
		if craft_panel.visible:
			refresh_craft())
	$Panel.add_child(btn)
	craft_panel = Panel.new()
	craft_panel.visible = false
	craft_panel.position = Vector2(panel_w + 12, 0)
	craft_panel.size = Vector2(330, 250)
	$Panel.add_child(craft_panel)
	var title := Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 15)
	title.position = Vector2(12, 6)
	craft_panel.add_child(title)
	craft_rows = VBoxContainer.new()
	craft_rows.position = Vector2(12, 30)
	craft_rows.custom_minimum_size = Vector2(306, 0)
	craft_rows.add_theme_constant_override("separation", 6)
	craft_panel.add_child(craft_rows)

func refresh_craft() -> void:
	if craft_rows == null or player == null:
		return
	for c in craft_rows.get_children():
		c.queue_free()
	for item_id in Inventory.CRAFT_RECIPES:
		var recipe: Dictionary = Inventory.CRAFT_RECIPES[item_id]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var can_make := true
		var parts := []
		for ing in recipe:
			var need: int = maxi(1, int(ceil(float(recipe[ing]) * (0.75 if GameState.ten_freed("ten_toren") else 1.0))))
			var have: int = player.inventory.get_count(ing)
			if have < need:
				can_make = false
			parts.append("%s %d/%d" % [Inventory.get_display_name(ing), have, need])
		var make := Button.new()
		make.text = "⚒ %s" % Inventory.get_display_name(item_id)
		make.custom_minimum_size = Vector2(300, 26)
		make.disabled = not can_make
		make.pressed.connect(_on_craft.bind(item_id))
		row.add_child(make)
		var need_l := Label.new()
		need_l.text = "     " + ", ".join(parts)
		need_l.add_theme_font_size_override("font_size", 11)
		need_l.add_theme_color_override("font_color",
			Color(0.65, 0.8, 0.65) if can_make else Color(0.75, 0.6, 0.55))
		row.add_child(need_l)
		craft_rows.add_child(row)

func _on_craft(item_id: String) -> void:
	# try_craft returns "" on success, or the reason it refused
	var result: String = GameState.try_craft(item_id, player)
	if result == "":
		notify("Crafted " + Inventory.get_display_name(item_id) + "!")
		GameState.play_sfx(GameState.SFX_YES, 1.1)
	else:
		notify(result)
	refresh()
	refresh_craft()

# A visible ✕ in the panel corner so the inventory can always be dismissed by
# click, not only with the Tab key.
func build_close_button() -> void:
	var close_btn = Button.new()
	close_btn.position = Vector2(panel_w - 34, 8)
	close_btn.size = Vector2(26, 22)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_panels)
	$Panel.add_child(close_btn)

# Inventory and gear panel open together on Tab, so closing one closes both --
# otherwise the next Tab press would leave them out of sync (one open, one shut).
func close_panels() -> void:
	visible = false
	var equip_ui = get_tree().get_first_node_in_group("equipment_ui")
	if equip_ui and equip_ui.has_method("close"):
		equip_ui.close()

func esc_is_open() -> bool:
	return visible

func esc_close() -> void:
	close_panels()

func build_slots() -> void:
	var capacity = player.inventory.capacity if player else COLUMNS * ROWS
	# THE BAG RAN OFF THE SCREEN (visual sweep 2026-07-21). This grew the panel
	# downward one row per 5 slots, and the real bag is 55 slots -- eleven rows,
	# 672px, in a 648px-tall UI. The top and bottom rows were clipped away
	# entirely: unreachable items, and the crafting bench (anchored to the panel
	# top) had its title sliced off. A bag that outgrows its 3-tscn-row default
	# must grow SIDEWAYS, not past the edge.
	var max_rows = int((MAX_PANEL_H - GRID_ORIGIN.y - 8.0) / (SLOT_SIZE + SLOT_GAP))
	var cols = maxi(COLUMNS, int(ceil(float(capacity) / float(max_rows))))
	var rows = int(ceil(float(capacity) / float(cols)))
	var half_h = (GRID_ORIGIN.y + rows * (SLOT_SIZE + SLOT_GAP) + 8.0) / 2.0
	panel_w = GRID_ORIGIN.x * 2.0 + cols * SLOT_SIZE + (cols - 1) * SLOT_GAP
	$Panel.offset_top = -half_h
	$Panel.offset_bottom = half_h
	# NOTE: this Panel is LEFT-anchored (anchor_left = 0 in the .tscn), so the
	# offsets are measured from the screen's left edge, not from its centre.
	$Panel.offset_left = PANEL_MARGIN_X
	$Panel.offset_right = PANEL_MARGIN_X + panel_w
	# the .tscn pins the hint at y=208 -- the floor of the old 3-row panel. Once
	# the grid is taller than that it reads as text buried under the slots, so
	# re-seat it on the real bottom edge.
	var hint = $Panel.get_node_or_null("HintLabel")
	if hint:
		hint.offset_top = half_h * 2.0 - 22.0
		hint.offset_bottom = half_h * 2.0 - 4.0
		hint.offset_right = panel_w - 16.0
	for i in range(capacity):
		var col = i % cols
		var row = i / cols
		var pos = GRID_ORIGIN + Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))

		var bg = ColorRect.new()
		bg.color = SLOT_BORDER_COLOR                     # the frame; the fill sits on top
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = pos
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.gui_input.connect(_on_slot_gui_input.bind(i))
		bg.mouse_entered.connect(_on_slot_hover.bind(i))
		bg.mouse_exited.connect(_on_slot_unhover)
		$Panel.add_child(bg)
		slot_bgs.append(bg)

		var fill = ColorRect.new()                       # inset dark fill -> 2px border ring shows
		fill.color = SLOT_FILL_COLOR
		fill.size = Vector2(SLOT_SIZE - 4.0, SLOT_SIZE - 4.0)
		fill.position = pos + Vector2(2.0, 2.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.add_child(fill)

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

func _on_slot_hover(index: int) -> void:
	if not player or index >= player.inventory.slots.size():
		return
	var slot = player.inventory.slots[index]
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip and slot != null:
		tip.show_for(slot.item_id)

func _on_slot_unhover() -> void:
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip:
		tip.hide_tooltip()

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		# SHIFT-CLICK with a chest open: flick the whole stack into the chest
		if Input.is_key_pressed(KEY_SHIFT):
			var cui = get_tree().get_first_node_in_group("chest_ui")
			if cui and cui.visible and cui.current_chest != null:
				var slot0 = player.inventory.slots[index]
				if slot0 != null:
					player.inventory.transfer_to(cui.current_chest.inventory, str(slot0.item_id), int(slot0.count))
					refresh()
					cui.refresh()
				return
		if DragState.split_mode:
			DragState.deposit_split(player.inventory, index)
		else:
			DragState.start_drag(player.inventory, index)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# right-click: weapons -> wield instantly; armor/relics -> equip; other
		# stacks (coins/materials) keep the stack-split behavior.
		var slot = player.inventory.slots[index]
		if slot != null and Inventory.get_category(slot.item_id) == "consumable":
			player.use_item(slot.item_id)   # potions / food / reset -> consume + apply
		elif slot != null and Inventory.get_category(slot.item_id) == "weapon":
			if player.wield_weapon(slot.item_id):
				notify("Wielding " + Inventory.get_display_name(slot.item_id))
		elif slot != null and Inventory.is_equippable(slot.item_id):
			quick_equip(slot.item_id)
		else:
			DragState.start_or_continue_split(player.inventory, index)

func quick_equip(item_id: String) -> void:
	# equip_item already syncs player stats (on_equipment_changed)
	if GameState.equip_item(item_id, player):
		refresh()
		var equip_ui = get_tree().get_first_node_in_group("equipment_ui")
		if equip_ui:
			equip_ui.refresh()
		notify("Equipped " + Inventory.get_display_name(item_id))
	else:
		notify("Couldn't equip " + Inventory.get_display_name(item_id) + " (no free slot?)")

func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)

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
			Inventory.paint_icon(slot_icons[i], slot.item_id)
			slot_counts[i].text = str(slot.count) if slot.count > 1 else ""
