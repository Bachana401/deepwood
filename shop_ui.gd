extends Panel

const DASH_COST = 30
const DOUBLE_JUMP_COST = 20
const SPEAR_COST = 40
const BOW_COST = 35

const SFX_PURCHASE = preload("res://audio/purchase.wav")
const SFX_DENIED = preload("res://audio/purchase_denied.wav")

var hovered_item: String = ""
var player: Node2D = null

func _ready() -> void:
	add_to_group("esc_window")
	player = get_tree().get_first_node_in_group("player")
	# null-safe like assign_ui (f6b819b): a bare-script instance has none of
	# these children, and reaching through $ threw on frame one
	_connect_option(get_node_or_null("DashOption"), "dash")
	_connect_option(get_node_or_null("DoubleJumpOption"), "double_jump")
	_connect_option(get_node_or_null("SpearOption"), "spear")
	_connect_option(get_node_or_null("BowOption"), "bow")
	# The classic screen-nuke Magic Wand is an ADMIN/test item (it deletes every
	# enemy incl. bosses) -- it is NOT for sale in the real game. Hidden here.
	var mw := get_node_or_null("MagicWandOption")
	if mw != null:
		mw.visible = false
	# a visible way OUT (audit fix, same as wanderer_ui): this panel had neither
	# a close button nor a toggle key -- ESC via the pause sweep was the sole,
	# undiscoverable exit, while the Panel ate every click under its 300x200
	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(size.x - 34.0, 4.0)
	close.size = Vector2(30, 30)
	close.pressed.connect(esc_close)
	add_child(close)
	refresh_prices()

# THE SHOP NEVER SAID WHAT ANYTHING COST (visual sweep 2026-07-21). Four bare
# words -- "Dashing", "Double Jump", "Spear", "Bow" -- and you clicked blind,
# with no price, no idea whether you could afford it, and no sign you already
# owned it. Every row now carries its price, greys out when your purse is
# short, and reads OWNED once bought.
const SHOP_ROWS := {
	"dash": DASH_COST, "double_jump": DOUBLE_JUMP_COST,
	"spear": SPEAR_COST, "bow": BOW_COST,
}
const SHOP_NAMES := {
	"dash": "Dashing", "double_jump": "Double Jump",
	"spear": "Spear", "bow": "Bow",
}

func _owns(item: String) -> bool:
	if player == null:
		return false
	match item:
		"dash":
			return player.has_dash
		"double_jump":
			return player.has_double_jump
		"spear":
			return player.inventory.get_count("wpn_spear") > 0
		"bow":
			return player.inventory.get_count("wpn_bow") > 0
	return false

func refresh_prices() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	for item in SHOP_ROWS.keys():
		var label := _get_label(item)
		if label == null:
			continue
		var cost: int = SHOP_ROWS[item]
		if _owns(item):
			label.text = "%s — OWNED" % SHOP_NAMES[item]
			label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
		else:
			label.text = "%s — %dg" % [SHOP_NAMES[item], cost]
			var afford: bool = player != null and player.currency >= cost
			label.add_theme_color_override("font_color",
				Color(1, 1, 1) if afford else Color(0.72, 0.6, 0.55))

func esc_is_open() -> bool:
	return visible

func esc_close() -> void:
	visible = false

func _connect_option(label: Label, item: String) -> void:
	if label == null:
		return
	label.mouse_entered.connect(_on_hover_start.bind(item))
	label.mouse_exited.connect(_on_hover_end.bind(item))
	label.gui_input.connect(_on_option_gui_input.bind(item))

func _on_hover_start(item: String) -> void:
	hovered_item = item
	_get_label(item).modulate = Color(1, 0.9, 0.3)

func _on_hover_end(item: String) -> void:
	if hovered_item == item:
		hovered_item = ""
	_get_label(item).modulate = Color(1, 1, 1)

func _get_label(item: String) -> Label:
	match item:
		"dash":
			return $DashOption
		"double_jump":
			return $DoubleJumpOption
		"spear":
			return $SpearOption
		"bow":
			return $BowOption
	return null

func _on_option_gui_input(event: InputEvent, item: String) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		match item:
			"dash":
				try_buy_dash()
			"double_jump":
				try_buy_double_jump()
			"spear":
				try_buy_spear()
			"bow":
				try_buy_bow()

func try_buy_dash() -> void:
	if player.has_dash:
		show_denied_notification("You already own Dash.")
		return
	if player.currency < DASH_COST:
		show_denied_notification("Not enough currency for Dash (need " + str(DASH_COST) + "g, have " + str(player.currency) + "g).")
		return
	player.currency -= DASH_COST
	player.has_dash = true
	player.update_currency_display()
	show_notification("Dash purchased! Double-tap A or D to use it.")
	refresh_prices()
	print("Dash unlocked!")

func try_buy_double_jump() -> void:
	if player.has_double_jump:
		show_denied_notification("You already own Double Jump.")
		return
	if player.currency < DOUBLE_JUMP_COST:
		show_denied_notification("Not enough currency for Double Jump (need " + str(DOUBLE_JUMP_COST) + "g, have " + str(player.currency) + "g).")
		return
	player.currency -= DOUBLE_JUMP_COST
	player.has_double_jump = true
	player.update_currency_display()
	show_notification("Double Jump purchased! Press SPACE again mid-air.")
	refresh_prices()
	print("Double jump unlocked!")

# Weapons are inventory items now -- buying one drops it in your bag; wield it
# from the hotbar (its inventory slot's number key).
func try_buy_weapon_item(item_id: String, cost: int, display: String) -> void:
	if player.inventory.get_count(item_id) > 0:
		show_denied_notification("You already own the " + display + ".")
		return
	if player.currency < cost:
		show_denied_notification("Not enough currency for the " + display + " (need " + str(cost) + "g, have " + str(player.currency) + "g).")
		return
	# add FIRST and charge only if it fit -- add_item returns the leftover, so a
	# full bag (returns 1, nothing deposited) must not silently eat the gold
	if player.inventory.add_item(item_id, 1) > 0:
		show_denied_notification("Your bag is full — make room for the " + display + " first.")
		return
	player.currency -= cost
	player.update_currency_display()
	show_notification(display + " added to your inventory! Press its hotbar number to wield it.")
	refresh_prices()

func try_buy_spear() -> void:
	try_buy_weapon_item("wpn_spear", SPEAR_COST, "Spear")

func try_buy_bow() -> void:
	try_buy_weapon_item("wpn_bow", BOW_COST, "Bow")

func show_notification(text: String) -> void:
	$SFXPlayer.stream = SFX_PURCHASE
	$SFXPlayer.play()
	$"../NotificationStack".show_notification(text)

# Failed purchases (not enough money, or already owned) get their own
# slightly negative two-note descending chime instead of the success jingle
# -- the old behavior played the same "cha-ching" sound whether or not
# anything was actually bought, which was misleading.
func show_denied_notification(text: String) -> void:
	$SFXPlayer.stream = SFX_DENIED
	$SFXPlayer.play()
	$"../NotificationStack".show_notification(text)
