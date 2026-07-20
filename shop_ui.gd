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
	_connect_option($DashOption, "dash")
	_connect_option($DoubleJumpOption, "double_jump")
	_connect_option($SpearOption, "spear")
	_connect_option($BowOption, "bow")
	# The classic screen-nuke Magic Wand is an ADMIN/test item (it deletes every
	# enemy incl. bosses) -- it is NOT for sale in the real game. Hidden here.
	$MagicWandOption.visible = false

func esc_is_open() -> bool:
	return visible

func esc_close() -> void:
	visible = false

func _connect_option(label: Label, item: String) -> void:
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
	player.currency -= cost
	player.inventory.add_item(item_id, 1)
	player.update_currency_display()
	show_notification(display + " added to your inventory! Press its hotbar number to wield it.")

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
