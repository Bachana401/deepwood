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
var set_box: VBoxContainer = null  # the spelled-out set bonuses (refresh_set_lines)

const PANEL_W = 250.0
# taller since the set-bonus block moved in under the relics (2026-07-28);
# 500 clipped the FULL-bonus instruction off the panel's bottom edge
const PANEL_H = 560.0
# Weapons moved to the hotbar (see player.gd) -- the gear panel is armor only.
# THREE SLOTS, Terraria-exact (dev 2026-07-28): helmet / breastplate /
# leggings. Gloves+boots retired; their identity folds into the 3-piece sets.
const GEAR_SLOTS = [
	{"key": "helmet", "label": "Helmet"},
	{"key": "chest", "label": "Breastplate"},
	{"key": "pants", "label": "Leggings"},
]
# 12 relic slots (dev 2026-07-28): six open from the start, one more every
# ten levels -- the label on a locked slot names the level that opens it
const RELIC_UNLOCK_LEVEL = [0, 0, 0, 0, 0, 0, 10, 20, 30, 40, 50, 60]

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

# A Terraria pixel-box slot (dev ask 2026-07-22): slate border over a dark-navy
# fill, matching the inventory/tooltip palette. Empty slots read as slots via
# both the frame AND a faint ghost silhouette of what belongs there (refresh()).
func _slot_style(hover: bool, locked := false) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if locked:
		s.bg_color = Color(0.07, 0.08, 0.11, 1)
		s.border_color = Color(0.22, 0.24, 0.32, 1)
	else:
		s.bg_color = Color(0.16, 0.18, 0.25, 1) if hover else Color(0.10, 0.12, 0.17, 1)
		s.border_color = Color(0.46, 0.50, 0.66, 1) if hover else Color(0.34, 0.38, 0.52, 1)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 3
	s.content_margin_right = 3
	return s

# Representative silhouette shown, dimmed, in an EMPTY slot -- the Terraria "a
# ghost helmet means a helmet goes here" read. Reuses the bag's own icons.
const SLOT_GHOST = {
	"helmet": "helm_leather", "chest": "armor_leather", "pants": "pants_leather",
	"relic": "relic_vigor",
}

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
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	pstyle.border_color = Color(0.34, 0.38, 0.52, 0.9)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", pstyle)
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

	# armour slots in TWO columns (3 rows) so all five fit above the relics
	var cx = PANEL_W / 2.0
	var box = 60.0
	var start_y = 40.0
	var step = 92.0
	var col_gap = 16.0
	for i in range(GEAR_SLOTS.size()):
		var def = GEAR_SLOTS[i]
		var col = i % 2
		var row = i / 2
		var lx = (cx - box - col_gap / 2.0) if col == 0 else (cx + col_gap / 2.0)
		var ly = start_y + row * step
		var name_lbl = Label.new()
		name_lbl.position = Vector2(lx, ly)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.92, 1))
		name_lbl.text = def.label
		panel.add_child(name_lbl)
		var button = _slot_button(lx, ly + 18.0, box, box)
		button.pressed.connect(_on_gear_slot_pressed.bind(def.key))
		button.mouse_entered.connect(_on_gear_slot_hover.bind(def.key))
		button.mouse_exited.connect(_hide_tip)
		slot_buttons[def.key] = button

	# relics below the armour (3 slots = 2 rows now)
	var relic_y = start_y + 2 * step + 8.0
	var relic_header = Label.new()
	relic_header.position = Vector2(12, relic_y)
	relic_header.add_theme_font_size_override("font_size", 13)
	relic_header.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5, 1))
	relic_header.text = "Relics"
	panel.add_child(relic_header)

	# 12 slots in a 4-wide grid: three tidy rows inside the same panel
	var per_row = 4
	var rbox = 48.0
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

	# set bonuses, spelled out under the relic grid (polish 2026-07-28: the
	# Regalia raised the HP orb and the window never said WHY)
	set_box = VBoxContainer.new()
	set_box.position = Vector2(12, ry0 + 3.0 * (rbox + 16.0) + 8.0)
	set_box.add_theme_constant_override("separation", 2)
	panel.add_child(set_box)

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
	style.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	style.border_color = Color(0.34, 0.38, 0.52, 0.9)
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
		_dress_slot(slot_buttons[key], equipped_id, "", SLOT_GHOST.get(key, ""))
	var count = GameState.relic_slot_count()
	for i in range(GameState.RELIC_MAX_SLOTS):
		var rb = relic_buttons[i]
		if i >= count:
			rb.text = "Lv%d" % RELIC_UNLOCK_LEVEL[i]
			rb.disabled = true
		else:
			rb.disabled = false
			var rid = GameState.equipment.relics[i]
			_dress_slot(rb, rid, "", SLOT_GHOST.get("relic", ""))
	refresh_set_lines()

# Every set with 2+ pieces worn gets its name (in the set's own colour), the
# count, and each tier ALREADY earned -- plus the one instruction that turns
# a full suit into the FULL bonus: wield the set's weapon.
func refresh_set_lines() -> void:
	if set_box == null:
		return
	for c in set_box.get_children():
		c.queue_free()
	var any := false
	for sid in Inventory.SET_DEFS.keys():
		var sd: Dictionary = Inventory.SET_DEFS[sid]
		var have: int = GameState.set_pieces_equipped(sid)
		if have < 2:
			continue
		if not any:
			any = true
			var h := Label.new()
			h.text = "Set Bonuses"
			h.add_theme_font_size_override("font_size", 13)
			h.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5, 1))
			set_box.add_child(h)
		var pieces: Array = sd.get("pieces", [])
		var total: int = pieces.size()
		var col: Color = Inventory.ITEM_DEFS.get(pieces[0], {}).get("color", Color.WHITE) if total > 0 else Color.WHITE
		var name_l := Label.new()
		name_l.text = "%s  (%d/%d)" % [str(sd.get("name", sid)), have, total]
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", col)
		set_box.add_child(name_l)
		var lines := []
		if have >= 2 and sd.has("bonus_2pc_desc"):
			lines.append("2pc: %s" % sd.bonus_2pc_desc)
		if have >= total and sd.has("bonus_desc"):
			lines.append("%dpc: %s" % [total, sd.bonus_desc])
		if sd.has("weapon") and have >= total:
			# the FULL tier pays only while the set's weapon is IN HAND
			# (get_set_bonus_total's rule -- mirror it exactly, never flatter)
			if GameState.wielded_weapon_id() == str(sd.weapon):
				lines.append("FULL: %s" % str(sd.get("full_bonus_desc", "")))
			else:
				lines.append("wield %s for the FULL bonus" % Inventory.get_display_name(str(sd.weapon)))
		for t in lines:
			var l := Label.new()
			l.text = "  " + str(t)
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86, 1))
			set_box.add_child(l)

func _slot_label(key: String) -> String:
	for def in GEAR_SLOTS:
		if def.key == key:
			return def.label
	return key

# EVERY SLOT SAID "Dragonsc" (sweep 2026-07-21). _short() cut names to nine
# characters, so a full Dragonscale set read as five identical boxes and you
# could not tell your helm from your boots. Show the ITEM instead: the same
# silhouette the bag draws, with the full name wrapped underneath it -- which
# is also the standing rule, that an icon must read as the thing you wear.
const SLOT_ICON = 30.0

func _dress_slot(button: Button, item_id: String, empty_text: String, ghost_id := "") -> void:
	var icon: ColorRect = button.get_node_or_null("SlotIcon")
	if item_id == "":
		if ghost_id != "":
			# a dim ghost of what belongs here, centred -- "a helmet goes here"
			if icon == null:
				icon = ColorRect.new()
				icon.name = "SlotIcon"
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.size = Vector2(SLOT_ICON, SLOT_ICON)
				button.add_child(icon)
			icon.position = Vector2((button.size.x - SLOT_ICON) / 2.0, (button.size.y - SLOT_ICON) / 2.0)
			Inventory.paint_icon(icon, ghost_id)
			icon.modulate = Color(1, 1, 1, 0.16)
			button.text = ""
		else:
			if icon != null:
				icon.queue_free()
			button.text = empty_text
		button.add_theme_constant_override("icon_max_width", 0)
		return
	if icon == null:
		icon = ColorRect.new()
		icon.name = "SlotIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size = Vector2(SLOT_ICON, SLOT_ICON)
		button.add_child(icon)
	icon.modulate = Color(1, 1, 1, 1)     # opaque again if this slot was a ghost before
	icon.position = Vector2((button.size.x - SLOT_ICON) / 2.0, 3.0)
	Inventory.paint_icon(icon, item_id)
	# full name, wrapped, in the space under the icon
	button.text = "\n\n" + Inventory.get_display_name(item_id)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 9)

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
	if eligible.is_empty():
		var none_label = Label.new()
		none_label.position = Vector2(8, 32)
		none_label.size = Vector2(264, 20)
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "(no matching items in inventory)"
		picker.add_child(none_label)
	# the list SCROLLS (audit fix): buttons used to stack straight down a fixed
	# 300px panel -- from the 8th eligible item they collided with Cancel, and
	# past the 9th they rendered outside the panel where they could never be
	# clicked. Ten helmets is routine loot after a few dungeon runs.
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 32)
	scroll.size = Vector2(272, 192)   # stops above Cancel (y=232)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	for item_id in eligible:
		var b = Button.new()
		b.custom_minimum_size = Vector2(258, 26)
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		var desc = Inventory.get_display_name(item_id) + _effect_summary(item_id)
		b.text = desc
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pick_item.bind(item_id, relic_index))
		rows.add_child(b)

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
		else:  # helmet/chest/pants/gloves/boots ("weapon" gear died with the hotbar migration)
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
