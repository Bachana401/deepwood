extends CanvasLayer

# Skill tree window (K to toggle) + the always-visible XP bar. Everything is
# built procedurally in _ready() so one small .tscn can be instanced into
# both main.tscn and dungeon_interior.tscn identically.
#
# Progressive reveal: a node is shown only if its tier is within 2 of the
# deepest tier already unlocked (so a fresh class sees tiers 1-2, unlocking
# tier 1 reveals tier 3, etc.) -- deeper tiers show as "???".

const RESET_POTION_COST = 150

var panel: Panel
var class_choice_box: VBoxContainer
var tree_box: VBoxContainer
var title_label: Label
var points_label: Label
var xp_fill: ColorRect
var xp_label: Label

func _ready() -> void:
	layer = 50
	build_xp_bar()
	build_panel()
	panel.visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_skill_tree"):
		panel.visible = not panel.visible
		if panel.visible:
			refresh()
	update_xp_bar()

func build_xp_bar() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.85)
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 20.0
	bg.offset_top = -46.0
	bg.offset_right = 240.0
	bg.offset_bottom = -32.0
	add_child(bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color(0.45, 0.7, 1.0, 1.0)
	xp_fill.anchor_top = 1.0
	xp_fill.anchor_bottom = 1.0
	xp_fill.offset_left = 20.0
	xp_fill.offset_top = -46.0
	xp_fill.offset_right = 20.0
	xp_fill.offset_bottom = -32.0
	add_child(xp_fill)
	xp_label = Label.new()
	xp_label.anchor_top = 1.0
	xp_label.anchor_bottom = 1.0
	xp_label.offset_left = 20.0
	xp_label.offset_top = -30.0
	xp_label.offset_right = 400.0
	xp_label.offset_bottom = -12.0
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	xp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	xp_label.add_theme_constant_override("outline_size", 4)
	add_child(xp_label)

func update_xp_bar() -> void:
	var needed = GameState.xp_to_next_level()
	xp_fill.offset_right = 20.0 + 220.0 * clamp(float(GameState.player_xp) / needed, 0.0, 1.0)
	xp_label.text = "Lv %d   %d / %d XP   |   %d skill pts (K)" % [GameState.player_level, GameState.player_xp, needed, GameState.skill_points]

func build_panel() -> void:
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270.0
	panel.offset_top = -240.0
	panel.offset_right = 270.0
	panel.offset_bottom = 240.0
	add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(16, 8)
	title_label.size = Vector2(508, 30)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	points_label = Label.new()
	points_label.position = Vector2(16, 40)
	points_label.size = Vector2(508, 22)
	points_label.add_theme_font_size_override("font_size", 13)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(points_label)

	class_choice_box = VBoxContainer.new()
	class_choice_box.position = Vector2(120, 90)
	class_choice_box.size = Vector2(300, 340)
	class_choice_box.add_theme_constant_override("separation", 12)
	panel.add_child(class_choice_box)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 68)
	scroll.size = Vector2(508, 360)
	panel.add_child(scroll)
	tree_box = VBoxContainer.new()
	tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_box.add_theme_constant_override("separation", 10)
	scroll.add_child(tree_box)

	var close = Button.new()
	close.text = "Close (K)"
	close.position = Vector2(16, 438)
	close.size = Vector2(110, 32)
	close.pressed.connect(func(): panel.visible = false)
	panel.add_child(close)

	var reset = Button.new()
	reset.text = "Drink Reset Potion (%dg)" % RESET_POTION_COST
	reset.position = Vector2(330, 438)
	reset.size = Vector2(194, 32)
	reset.pressed.connect(_on_reset_potion)
	panel.add_child(reset)

func _on_reset_potion() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or player.currency < RESET_POTION_COST:
		notify("Not enough gold for a Reset Potion (%dg)." % RESET_POTION_COST)
		return
	player.currency -= RESET_POTION_COST
	player.update_currency_display()
	GameState.reset_skills()
	notify("All skill points refunded. Choose your class anew.")
	refresh()

func refresh() -> void:
	var choosing = GameState.chosen_class == ""
	class_choice_box.visible = choosing
	tree_box.get_parent().visible = not choosing
	if choosing:
		title_label.text = "Choose Your Class"
		points_label.text = "This defines your skill tree. A Reset Potion can undo it later."
		rebuild_class_choice()
	else:
		var color = SkillTreeData.CLASS_COLORS.get(GameState.chosen_class, Color.WHITE)
		title_label.text = GameState.chosen_class.to_upper() + " SKILL TREE"
		title_label.add_theme_color_override("font_color", color)
		points_label.text = "Skill points: %d" % GameState.skill_points
		rebuild_tree()

func rebuild_class_choice() -> void:
	for child in class_choice_box.get_children():
		child.queue_free()
	for class_name_key in ["Sword", "Archer", "Mage", "Necromancer"]:
		var button = Button.new()
		var color = SkillTreeData.CLASS_COLORS[class_name_key]
		button.custom_minimum_size = Vector2(0, 48)
		if class_name_key == "Necromancer":
			button.text = "Necromancer  [LOCKED -- finish the game]"
			button.disabled = true
		else:
			button.text = class_name_key
			button.pressed.connect(_on_class_chosen.bind(class_name_key))
		var style = StyleBoxFlat.new()
		style.bg_color = color.darkened(0.45)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)
		var hover = style.duplicate()
		hover.bg_color = color.darkened(0.2)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		class_choice_box.add_child(button)

func _on_class_chosen(picked: String) -> void:
	GameState.chosen_class = picked
	notify("Class chosen: " + picked + "!")
	refresh()

func deepest_unlocked_tier() -> int:
	var deepest = 0
	for node in SkillTreeData.TREES.get(GameState.chosen_class, []):
		if GameState.is_skill_unlocked(node.id):
			deepest = max(deepest, node.tier)
	return deepest

func rebuild_tree() -> void:
	for child in tree_box.get_children():
		child.queue_free()
	var color = SkillTreeData.CLASS_COLORS.get(GameState.chosen_class, Color.WHITE)
	var visible_limit = deepest_unlocked_tier() + 2
	var nodes_by_tier = {}
	for node in SkillTreeData.TREES.get(GameState.chosen_class, []):
		if not nodes_by_tier.has(node.tier):
			nodes_by_tier[node.tier] = []
		nodes_by_tier[node.tier].append(node)
	var tiers = nodes_by_tier.keys()
	tiers.sort()
	for tier in tiers:
		var header = Label.new()
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", color.lightened(0.3))
		if tier > visible_limit:
			header.text = "Tier %d -- ???" % tier
			tree_box.add_child(header)
			continue
		header.text = "Tier %d" % tier
		tree_box.add_child(header)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		tree_box.add_child(row)
		for node in nodes_by_tier[tier]:
			row.add_child(make_node_button(node, color))

func make_node_button(node: Dictionary, color: Color) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(240, 64)
	var unlocked = GameState.is_skill_unlocked(node.id)
	var cost_line = "%d pt" % node.cost
	for mat_id in node.materials.keys():
		cost_line += " + %dx %s" % [node.materials[mat_id], Inventory.get_display_name(mat_id)]
	if unlocked:
		button.text = "[UNLOCKED]  " + node.name + "\n" + node.desc
		button.disabled = true
	else:
		button.text = node.name + "\n" + node.desc + "\n" + cost_line
		button.pressed.connect(_on_node_pressed.bind(node))
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.25) if unlocked else Color(0.13, 0.13, 0.16, 1.0)
	style.border_color = color if unlocked else color.darkened(0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.95, 1))
	return button

func _on_node_pressed(node: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if node.prereq != "" and not GameState.is_skill_unlocked(node.prereq):
		notify("Requires '" + SkillTreeData.get_node_by_id(node.prereq).name + "' first.")
		return
	if GameState.skill_points < node.cost:
		notify("Not enough skill points (%d needed)." % node.cost)
		return
	for mat_id in node.materials.keys():
		if not GameState.researched_materials.has(mat_id):
			notify("Requires an unresearched material -- take your finds to the Science Lab.")
			return
		if player.inventory.get_count(mat_id) < node.materials[mat_id]:
			notify("Missing materials: needs %dx %s." % [node.materials[mat_id], Inventory.get_display_name(mat_id)])
			return
	if GameState.try_unlock_skill(node, player):
		notify("Unlocked: " + node.name + "!")
		player.update_health_display()
		refresh()

func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)
