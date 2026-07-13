extends CanvasLayer

# Equipment panel, pinned to the RIGHT side of the screen (kept clear of the
# left-side inventory), toggled with TAB alongside it. Big, clearly-labelled
# armour slots stacked head-to-toe -- Helmet, Armour, Pants -- with the relic
# slots in a grid below. Click a filled slot to unequip it back to the bag;
# click an empty slot to pick an eligible item.
#
# Built procedurally so one .tscn instances identically into main.tscn and
# dungeon_interior.tscn.

var player: Node2D
var panel: Panel
var picker: Panel
var title_label: Label
var slot_buttons = {}  # "helmet"/"chest"/"pants" -> Button
var relic_buttons: Array = []  # index 0..5 -> Button

const PANEL_W = 250.0
const PANEL_H = 500.0
# Weapons moved to the hotbar (see player.gd) -- the gear panel is armor only.
const GEAR_SLOTS = [
	{"key": "helmet", "label": "Helmet"},
	{"key": "chest", "label": "Armor"},
	{"key": "pants", "label": "Pants"},
]
const RELIC_UNLOCK_LEVEL = [0, 0, 0, 0, 10, 20]  # per relic slot index

func _ready() -> void:
	layer = 40
	add_to_group("equipment_ui")
	add_to_group("esc_window")
	build_panel()
	build_picker()
	panel.visible = false
	picker.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		panel.visible = not panel.visible
		picker.visible = false
		if panel.visible:
			refresh()

# A boxed slot with a border so empty slots read as slots.
func _slot_style(hover: bool, locked := false) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if locked:
		s.bg_color = Color(0.09, 0.09, 0.11, 1)
		s.border_color = Color(0.3, 0.3, 0.35, 1)
	else:
		s.bg_color = Color(0.19, 0.19, 0.24, 1) if hover else Color(0.13, 0.13, 0.17, 1)
		s.border_color = Color(0.55, 0.55, 0.62, 1)
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left = 3
	s.content_margin_right = 3
	return s

func _slot_button(x: float, y: float, w: float, h: float) -> Button:
	var b = Button.new()
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 11)
	b.clip_text = true
	# FOCUS_NONE keeps TAB free to toggle the panel instead of moving focus.
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _slot_style(false))
	b.add_theme_stylebox_override("hover", _slot_style(true))
	b.add_theme_stylebox_override("pressed", _slot_style(true))
	b.add_theme_stylebox_override("disabled", _slot_style(false, true))
	panel.add_child(b)
	return b

func build_panel() -> void:
	panel = Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -(PANEL_W + 20.0)
	panel.offset_right = -20.0
	panel.offset_top = -PANEL_H / 2.0
	panel.offset_bottom = PANEL_H / 2.0
	add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(12, 8)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.text = "Equipment"
	panel.add_child(title_label)

	var close_btn = Button.new()
	close_btn.position = Vector2(PANEL_W - 32, 6)
	close_btn.size = Vector2(24, 22)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)

	# three armour slots, head-to-toe, each a labelled box centred in the panel
	var cx = PANEL_W / 2.0
	var box = 64.0
	var start_y = 40.0
	var step = 88.0
	var i = 0
	for def in GEAR_SLOTS:
		var ly = start_y + i * step
		var name_lbl = Label.new()
		name_lbl.position = Vector2(cx - box / 2.0, ly)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.92, 1))
		name_lbl.text = def.label
		panel.add_child(name_lbl)
		var button = _slot_button(cx - box / 2.0, ly + 18.0, box, box)
		button.pressed.connect(_on_gear_slot_pressed.bind(def.key))
		button.mouse_entered.connect(_on_gear_slot_hover.bind(def.key))
		button.mouse_exited.connect(_hide_tip)
		slot_buttons[def.key] = button
		i += 1

	# relics below, in a grid (3 per row)
	var relic_y = start_y + 3 * step + 8.0
	var relic_header = Label.new()
	relic_header.position = Vector2(12, relic_y)
	relic_header.add_theme_font_size_override("font_size", 13)
	relic_header.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5, 1))
	relic_header.text = "Relics"
	panel.add_child(relic_header)

	var per_row = 3
	var rbox = 56.0
	var rgap = 8.0
	var row_w = per_row * rbox + (per_row - 1) * rgap
	var rx0 = (PANEL_W - row_w) / 2.0
	var ry0 = relic_y + 22.0
	for j in range(GameState.RELIC_MAX_SLOTS):
		var col = j % per_row
		var row = j / per_row
		var rb = _slot_button(rx0 + col * (rbox + rgap), ry0 + row * (rbox + 16.0), rbox, rbox)
		rb.add_theme_font_size_override("font_size", 10)
		rb.pressed.connect(_on_relic_slot_pressed.bind(j))
		rb.mouse_entered.connect(_on_relic_slot_hover.bind(j))
		rb.mouse_exited.connect(_hide_tip)
		relic_buttons.append(rb)

func build_picker() -> void:
	# the picker opens just to the LEFT of the right-side panel
	picker = Panel.new()
	picker.anchor_left = 1.0
	picker.anchor_right = 1.0
	picker.anchor_top = 0.5
	picker.anchor_bottom = 0.5
	picker.offset_left = -(PANEL_W + 20.0 + 290.0)
	picker.offset_right = -(PANEL_W + 20.0 + 10.0)
	picker.offset_top = -150.0
	picker.offset_bottom = 150.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	style.border_color = Color(0.6, 0.6, 0.66, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	picker.add_theme_stylebox_override("panel", style)
	add_child(picker)

func ensure_player() -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

func close() -> void:
	panel.visible = false
	picker.visible = false
	# keep the inventory panel in lock-step (they open together on Tab)
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.visible:
		inv_ui.visible = false

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	close()

# Equip/unequip changes the player's bag too, so the inventory panel has to be
# redrawn or its items look like they vanished (they didn't -- the panel was
# just showing a stale picture).
func refresh_inventory_ui() -> void:
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()

func _on_gear_slot_hover(key: String) -> void:
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip:
		tip.show_for(GameState.equipment.get(key, ""))

func _on_relic_slot_hover(index: int) -> void:
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip and index < GameState.relic_slot_count():
		tip.show_for(GameState.equipment.relics[index])

func _hide_tip() -> void:
	var tip = get_tree().get_first_node_in_group("item_tooltip")
	if tip:
		tip.hide_tooltip()

func refresh() -> void:
	ensure_player()
	if not player:
		return
	# the slot name lives in the Label above each box, so the box shows just the
	# item (or "(empty)") -- exactly an "empty helmet place", "empty armor place"...
	for key in slot_buttons.keys():
		var equipped_id = GameState.equipment.get(key, "")
		slot_buttons[key].text = "(empty)" if equipped_id == "" else _short(Inventory.get_display_name(equipped_id))
	var count = GameState.relic_slot_count()
	for i in range(GameState.RELIC_MAX_SLOTS):
		var rb = relic_buttons[i]
		if i >= count:
			rb.text = "Lv%d" % RELIC_UNLOCK_LEVEL[i]
			rb.disabled = true
		else:
			rb.disabled = false
			var rid = GameState.equipment.relics[i]
			rb.text = "R%d" % (i + 1) if rid == "" else _short(Inventory.get_display_name(rid))

func _slot_label(key: String) -> String:
	for def in GEAR_SLOTS:
		if def.key == key:
			return def.label
	return key

func _short(name: String) -> String:
	return name.substr(0, 9)

func _on_gear_slot_pressed(key: String) -> void:
	ensure_player()
	if not player:
		return
	if GameState.equipment.get(key, "") != "":
		GameState.unequip_slot(key, player)
		refresh()
		refresh_inventory_ui()
	else:
		open_picker_for_slot(key, -1)

func _on_relic_slot_pressed(index: int) -> void:
	ensure_player()
	if not player:
		return
	if index >= GameState.relic_slot_count():
		notify("Relic slot %d unlocks at level %d." % [index + 1, RELIC_UNLOCK_LEVEL[index]])
		return
	if GameState.equipment.relics[index] != "":
		GameState.unequip_slot("relic", player, index)
		refresh()
		refresh_inventory_ui()
	else:
		open_picker_for_slot("relic", index)

# Lists eligible inventory items for a slot as clickable buttons.
func open_picker_for_slot(slot_key: String, relic_index: int) -> void:
	for child in picker.get_children():
		child.queue_free()
	var header = Label.new()
	header.position = Vector2(8, 6)
	header.size = Vector2(264, 20)
	header.add_theme_font_size_override("font_size", 13)
	header.text = "Equip which item?"
	picker.add_child(header)

	var eligible = _eligible_items(slot_key)
	var y = 32.0
	if eligible.is_empty():
		var none_label = Label.new()
		none_label.position = Vector2(8, y)
		none_label.size = Vector2(264, 20)
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "(no matching items in inventory)"
		picker.add_child(none_label)
	for item_id in eligible:
		var b = Button.new()
		b.position = Vector2(8, y)
		b.size = Vector2(264, 26)
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		var desc = Inventory.get_display_name(item_id) + _effect_summary(item_id)
		b.text = desc
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pick_item.bind(item_id, relic_index))
		picker.add_child(b)
		y += 30.0

	var close = Button.new()
	close.position = Vector2(8, 232)
	close.size = Vector2(120, 24)
	close.add_theme_font_size_override("font_size", 11)
	close.text = "Cancel"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): picker.visible = false)
	picker.add_child(close)
	picker.visible = true

func _eligible_items(slot_key: String) -> Array:
	var seen = {}
	var result = []
	for slot in player.inventory.slots:
		if slot == null:
			continue
		var item_id = slot.item_id
		if seen.has(item_id):
			continue
		var cat = Inventory.get_category(item_id)
		var matches = false
		if slot_key == "relic":
			matches = cat == "relic"
		elif slot_key == "weapon":
			matches = cat == "weapon"
		else:  # helmet/chest/pants
			matches = cat == "armor" and Inventory.get_equip_slot(item_id) == slot_key
		if matches:
			seen[item_id] = true
			result.append(item_id)
	return result

func _effect_summary(item_id: String) -> String:
	var def = Inventory.get_item_def(item_id)
	if def.get("category") == "weapon":
		return "  (" + def.get("unique_desc", "unique effect") + ")"
	var parts = []
	for key in def.get("equip_effect", {}).keys():
		var val = def.equip_effect[key]
		if Inventory.FLAG_EFFECT_TEXT.has(key):
			parts.append(Inventory.FLAG_EFFECT_TEXT[key])
		elif key == "max_health":
			parts.append("+%d HP" % int(val))
		elif key == "max_mana":
			parts.append("+%d Mana" % int(val))
		elif key in Inventory.COOLDOWN_EFFECT_KEYS:
			parts.append("-%d%% %s" % [int(val * 100), key.replace("_", " ")])
		else:
			parts.append("+%d%% %s" % [int(val * 100), key.replace("_", " ")])
	return "  (" + ", ".join(parts) + ")" if not parts.is_empty() else ""

func _on_pick_item(item_id: String, relic_index: int) -> void:
	ensure_player()
	if player and GameState.equip_item(item_id, player, relic_index):
		notify("Equipped " + Inventory.get_display_name(item_id) + ".")
	picker.visible = false
	refresh()
	refresh_inventory_ui()

func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)
