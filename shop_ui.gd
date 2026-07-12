extends Panel

const DASH_COST = 30
const DOUBLE_JUMP_COST = 20
const SPEAR_COST = 40
const BOW_COST = 35
const WAND_COST = 1

const SFX_PURCHASE = preload("res://audio/purchase.wav")
const SFX_DENIED = preload("res://audio/purchase_denied.wav")

var hovered_item: String = ""
var player: Node2D = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_connect_option($DashOption, "dash")
	_connect_option($DoubleJumpOption, "double_jump")
	_connect_option($SpearOption, "spear")
	_connect_option($BowOption, "bow")
	_connect_option($MagicWandOption, "wand")

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
		"wand":
			return $MagicWandOption
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
			"wand":
				try_buy_wand()

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
	show_notification("Dashing purchased succesfully ! (Double press A or D to use)")
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
	show_notification("Double Jump purchased successfully (so creative right ?!)")
	print("Double jump unlocked!")

func try_buy_spear() -> void:
	if player.owned_weapons.get("spear", false):
		show_denied_notification("You already own the Spear.")
		return
	if player.currency < SPEAR_COST:
		show_denied_notification("Not enough currency for the Spear (need " + str(SPEAR_COST) + "g, have " + str(player.currency) + "g).")
		return
	player.currency -= SPEAR_COST
	player.owned_weapons["spear"] = true
	player.equip_weapon("spear")
	player.update_currency_display()
	show_notification("Spear purchased successfully! (Press 2 to equip)")
	print("Spear unlocked!")

func try_buy_bow() -> void:
	if player.owned_weapons.get("bow", false):
		show_denied_notification("You already own the Bow.")
		return
	if player.currency < BOW_COST:
		show_denied_notification("Not enough currency for the Bow (need " + str(BOW_COST) + "g, have " + str(player.currency) + "g).")
		return
	player.currency -= BOW_COST
	player.owned_weapons["bow"] = true
	player.equip_weapon("bow")
	player.update_currency_display()
	show_notification("Bow purchased successfully! (Press 3 to equip)")
	print("Bow unlocked!")

func try_buy_wand() -> void:
	if player.owned_weapons.get("wand", false):
		show_denied_notification("You already own the Magic Wand.")
		return
	if player.currency < WAND_COST:
		show_denied_notification("Not enough currency for the Magic Wand (need " + str(WAND_COST) + "g, have " + str(player.currency) + "g).")
		return
	player.currency -= WAND_COST
	player.owned_weapons["wand"] = true
	player.equip_weapon("wand")
	player.update_currency_display()
	show_notification("Magic Wand purchased! (Press 4 to equip, kills all enemies)")
	print("Magic Wand unlocked!")

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
