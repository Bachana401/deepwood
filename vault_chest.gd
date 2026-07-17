extends Area2D

# A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless
# *catalogue*: it stocks one full stack of every item on its list and tops
# itself back up every time you open it, so the item is always there to grab
# again. Press E to open it in the shared ChestUI -- then it's the exact same
# drag interface as any chest in the game: drag an item out into your bag to
# take it, drag it back into the chest to put it away. Your bag opens alongside
# it automatically so both panels are on screen to drag between.
#
# Set `item_ids`, `title`, `subtitle`, and `accent` before adding it to the
# tree (build_proving_grounds does this).

var item_ids: Array = []
var title := "CHEST"
var subtitle := ""
var accent := Color(0.8, 0.8, 0.85)
var ui_title := ""            # what the ChestUI title bar shows when open

var inventory: Inventory
var _inside := false
var _prompt: Label = null

const SPARE_SLOTS := 8        # room for the player to drop items back in

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2         # detect the player body (player is on layer 2)
	monitoring = true
	# one slot per catalogued item, plus spare slots so putting things back
	# always has somewhere to land
	inventory = Inventory.new(item_ids.size() + SPARE_SLOTS)
	_restock()
	ui_title = "%s  ·  %d items" % [title, item_ids.size()]

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 96)
	cs.shape = rect
	cs.position = Vector2(0, -30)
	add_child(cs)
	# chest body
	var base := ColorRect.new()
	base.size = Vector2(58, 34); base.position = Vector2(-29, -34)
	base.color = accent.darkened(0.35)
	add_child(base)
	var lid := ColorRect.new()
	lid.size = Vector2(62, 16); lid.position = Vector2(-31, -48)
	lid.color = accent
	add_child(lid)
	var lock := ColorRect.new()
	lock.size = Vector2(8, 10); lock.position = Vector2(-4, -40)
	lock.color = Color(1, 0.9, 0.5)
	add_child(lock)
	# glowing rank tint at the base
	var glow := ColorRect.new()
	glow.size = Vector2(66, 4); glow.position = Vector2(-33, -2)
	glow.color = Color(accent.r, accent.g, accent.b, 0.6)
	add_child(glow)
	# label overhead: title + short "what's inside"
	var lbl := Label.new()
	lbl.position = Vector2(-110, -108)
	lbl.size = Vector2(220, 54)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = title + ("\n" + subtitle if subtitle != "" else "")
	lbl.add_theme_color_override("font_color", accent)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 40
	add_child(lbl)
	# E prompt (hidden until you're on it)
	_prompt = Label.new()
	_prompt.position = Vector2(-60, -70)
	_prompt.size = Vector2(120, 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.text = "[E] Open"
	_prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	_prompt.z_index = 41
	add_child(_prompt)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

# Top every catalogued item back up to a full stack. Weapons/armor/relics stack
# to 1, potions to 20, materials to 99 -- so the chest always shows the whole
# catalogue no matter how much you've taken, while staying a well-formed
# inventory (never an over-cap stack that would break equipping/wielding).
func _restock() -> void:
	for id in item_ids:
		var target: int = Inventory.get_max_stack(id)
		var have: int = inventory.get_count(id)
		if have < target:
			inventory.add_item(id, target - have)

func _process(_delta: float) -> void:
	if _inside and Input.is_action_just_pressed("interact"):
		_open()

func _open() -> void:
	_restock()   # always a full catalogue on open
	var chest_ui = get_tree().get_first_node_in_group("chest_ui")
	if chest_ui == null:
		return
	chest_ui.open_chest(self)
	# open the bag alongside so there are two panels to drag between
	var bag = get_tree().get_first_node_in_group("inventory_ui")
	if bag != null:
		bag.visible = true
		if bag.has_method("refresh"):
			bag.refresh()
	if _prompt != null:
		_prompt.visible = false

# ChestUI calls this on close. An admin vault is disposable -- never write its
# giant contents into the save file.
func save_contents() -> void:
	pass

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		if _prompt != null:
			_prompt.visible = true

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		if _prompt != null:
			_prompt.visible = false
		var chest_ui = get_tree().get_first_node_in_group("chest_ui")
		if chest_ui != null and chest_ui.current_chest == self:
			chest_ui.close()
