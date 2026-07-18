extends CanvasLayer

# Bottom-of-screen hotbar showing the first 10 inventory slots (keys 1-9, 0).
# The slot holding the currently-wielded weapon is highlighted. Weapons are
# wielded by pressing the matching number key (see player.gd's hotbar input).

const SLOTS = 10
const SLOT_SIZE = 42.0
const GAP = 4.0
const BG_IDLE = Color(0.1, 0.1, 0.13, 0.85)
const BG_ACTIVE = Color(0.9, 0.8, 0.3, 0.95)

var player: Node2D = null
var slot_bgs: Array = []
var slot_icons: Array = []

func _ready() -> void:
	layer = 30
	player = get_tree().get_first_node_in_group("player")
	build()

func build() -> void:
	var total = SLOTS * SLOT_SIZE + (SLOTS - 1) * GAP
	var row = Control.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -total / 2.0
	row.offset_right = total / 2.0
	row.offset_top = -SLOT_SIZE - 8.0
	row.offset_bottom = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in range(SLOTS):
		var x = i * (SLOT_SIZE + GAP)
		var bg = ColorRect.new()
		bg.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = Vector2(x, 0)
		bg.color = BG_IDLE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bg)
		slot_bgs.append(bg)

		var icon = ColorRect.new()
		icon.size = Vector2(SLOT_SIZE - 14, SLOT_SIZE - 14)
		icon.position = Vector2(x + 7, 7)
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		slot_icons.append(icon)

		var num = Label.new()
		num.text = str((i + 1) % 10)  # 1..9 then 0
		num.position = Vector2(x + 3, 0)
		num.add_theme_font_size_override("font_size", 11)
		num.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7, 1))
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		num.add_theme_constant_override("outline_size", 3)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(num)

func _process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	for i in range(SLOTS):
		var slot = player.inventory.slots[i] if i < player.inventory.slots.size() else null
		if slot == null:
			slot_icons[i].visible = false
		else:
			slot_icons[i].visible = true
			Inventory.paint_icon(slot_icons[i], slot.item_id)
		var is_active = slot != null and slot.item_id == player.active_weapon_id
		slot_bgs[i].color = BG_ACTIVE if is_active else BG_IDLE
