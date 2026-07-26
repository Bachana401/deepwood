extends CanvasLayer

# THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on
# key at a working Marketplace while a seller is in town. Shows the cart:
# each ware, its LIVE price (the happy-town markdown deepens across the
# stay; a staffed Merchant haggles a tenth off), and how long the seller
# will linger. ESC closes it like any window.

var panel: Panel = null
var rows: VBoxContainer = null
var header: Label = null

func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	add_to_group("wanderer_post_ui")
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(320, 110)
	panel.size = Vector2(520, 400)
	add_child(panel)
	var title := Label.new()
	title.text = "THE WANDERER'S POST"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(18, 10)
	panel.add_child(title)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62, 1.0))
	header.position = Vector2(18, 38)
	header.size = Vector2(484, 34)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 78)
	scroll.size = Vector2(484, 306)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.custom_minimum_size = Vector2(464, 0)
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	panel.visible = false

func open_post() -> void:
	panel.visible = true
	refresh()

func refresh() -> void:
	for c in rows.get_children():
		c.queue_free()
	if GameState.wanderer.is_empty():
		panel.visible = false
		return
	var w: Dictionary = GameState.wanderer
	var leaves_in: float = maxf(0.0, float(w["arrived"]) + float(w["dwell"]) - GameState.game_hours)
	var mood := "the town's cheer is slowly working on the prices" if GameState.village_morale() >= 50 \
		else "a gloomy town gets a short, full-price visit"
	header.text = "%s — leaves in ~%dh. (%s)" % [str(w.get("name", "?")), int(ceil(leaves_in)), mood]
	var stock: Array = w.get("stock", [])
	for i in range(stock.size()):
		var entry: Dictionary = stock[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l := Label.new()
		name_l.text = "%s ×%d" % [Inventory.get_display_name(str(entry.get("id", ""))), int(entry.get("count", 1))]
		name_l.custom_minimum_size = Vector2(240, 0)
		name_l.add_theme_color_override("font_color", Inventory.get_grade_color(str(entry.get("id", ""))))
		row.add_child(name_l)
		var price_l := Label.new()
		price_l.text = "%dg" % GameState.wanderer_price_now(entry)
		price_l.custom_minimum_size = Vector2(60, 0)
		row.add_child(price_l)
		var buy := Button.new()
		buy.text = "Buy"
		buy.custom_minimum_size = Vector2(64, 26)
		buy.pressed.connect(_on_buy.bind(i))
		row.add_child(buy)
		rows.add_child(row)
	if stock.is_empty():
		var empty := Label.new()
		empty.text = "The cart is bare — you bought the lot."
		rows.add_child(empty)

func _on_buy(index: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	GameState.buy_from_wanderer(index, player)
	# refresh EITHER way: if the seller has since left, refresh() collapses the panel via
	# its empty guard instead of leaving a dead cart whose Buy silently does nothing; a
	# failed buy also re-reads current stock/prices.
	refresh()
