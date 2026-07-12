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
var tree_scroll: ScrollContainer
var tree_canvas: Control
var title_label: Label
var points_label: Label
var xp_fill: ColorRect
var xp_label: Label

# Tree layout geometry (canvas-local pixels). One root card centered at top,
# 3 branch columns fanning out below it, tiers descending within each column,
# Line2D connectors drawn between parent->child so it reads as a real tree.
const CANVAS_W = 620.0
const CARD_W = 190.0
const CARD_H = 54.0
const ROOT_TOP = 8.0
const HEADER_Y = 66.0
const TIER1_Y = 100.0
const TIER_SPACING = 66.0
const BRANCH_CENTERS = [105.0, 310.0, 515.0]
const ROOT_CENTER_X = 310.0

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
	panel.offset_left = -330.0
	panel.offset_top = -250.0
	panel.offset_right = 330.0
	panel.offset_bottom = 250.0
	add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(16, 8)
	title_label.size = Vector2(628, 30)
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
	class_choice_box.position = Vector2(180, 90)
	class_choice_box.size = Vector2(300, 340)
	class_choice_box.add_theme_constant_override("separation", 12)
	panel.add_child(class_choice_box)

	tree_scroll = ScrollContainer.new()
	tree_scroll.position = Vector2(16, 68)
	tree_scroll.size = Vector2(628, 380)
	panel.add_child(tree_scroll)
	tree_canvas = Control.new()
	tree_canvas.custom_minimum_size = Vector2(CANVAS_W, 440)
	tree_scroll.add_child(tree_canvas)

	var close = Button.new()
	close.text = "Close (K)"
	close.position = Vector2(16, 458)
	close.size = Vector2(110, 32)
	close.pressed.connect(func(): panel.visible = false)
	panel.add_child(close)

	var reset = Button.new()
	reset.text = "Drink Reset Potion (%dg)" % RESET_POTION_COST
	reset.position = Vector2(450, 458)
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
	tree_scroll.visible = not choosing
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

# Per-branch reveal: within a branch you can only see 2 tiers past that
# branch's own deepest unlock (a fresh branch shows tiers 1-2).
func deepest_unlocked_tier_in_branch(branch: int) -> int:
	var deepest = 0
	for node in SkillTreeData.TREES.get(GameState.chosen_class, []):
		if node.branch == branch and GameState.is_skill_unlocked(node.id):
			deepest = max(deepest, node.tier)
	return deepest

# Drawn as an actual tree: one root card centered at the top, connector lines
# fanning out to 3 branch columns, and each branch a descending chain of tier
# cards with lines linking each tier to the next. Cards are absolutely
# positioned on tree_canvas; Line2D connectors go on first (z=-1) so cards
# render over them.
func tier_top_y(tier: int) -> float:
	return TIER1_Y + (tier - 1) * TIER_SPACING

func rebuild_tree() -> void:
	for child in tree_canvas.get_children():
		child.queue_free()
	var color = SkillTreeData.CLASS_COLORS.get(GameState.chosen_class, Color.WHITE)
	var tree_nodes = SkillTreeData.TREES.get(GameState.chosen_class, [])
	var branch_names = SkillTreeData.BRANCH_NAMES.get(GameState.chosen_class, ["", "", ""])

	var root_bottom = Vector2(ROOT_CENTER_X, ROOT_TOP + CARD_H)

	# connectors first (root -> each branch tier1, then tier -> tier within a branch)
	for branch in range(3):
		var cx = BRANCH_CENTERS[branch]
		add_connector(root_bottom, Vector2(cx, tier_top_y(1)), color)
		for tier in range(1, 5):
			add_connector(Vector2(cx, tier_top_y(tier) + CARD_H), Vector2(cx, tier_top_y(tier + 1)), color)

	# root card
	for node in tree_nodes:
		if node.branch == -1:
			add_card(node, color, Vector2(ROOT_CENTER_X - CARD_W / 2.0, ROOT_TOP))

	# branch headers + tier cards / hidden placeholders
	for branch in range(3):
		var cx = BRANCH_CENTERS[branch]
		var header = Label.new()
		header.text = branch_names[branch]
		header.position = Vector2(cx - CARD_W / 2.0, HEADER_Y)
		header.size = Vector2(CARD_W, 22)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", color.lightened(0.3))
		tree_canvas.add_child(header)

		var visible_limit = deepest_unlocked_tier_in_branch(branch) + 2
		var branch_nodes = []
		for node in tree_nodes:
			if node.branch == branch:
				branch_nodes.append(node)
		branch_nodes.sort_custom(func(a, b): return a.tier < b.tier)
		for node in branch_nodes:
			var pos = Vector2(cx - CARD_W / 2.0, tier_top_y(node.tier))
			if node.tier > visible_limit:
				add_hidden_slot(node.tier, color, pos)
			else:
				add_card(node, color, pos)

func add_connector(from_pt: Vector2, to_pt: Vector2, color: Color) -> void:
	var line = Line2D.new()
	line.points = PackedVector2Array([from_pt, to_pt])
	line.width = 3.0
	line.default_color = Color(color.r, color.g, color.b, 0.65)
	line.z_index = -1
	tree_canvas.add_child(line)

func add_hidden_slot(tier: int, color: Color, pos: Vector2) -> void:
	var slot = Panel.new()
	slot.position = pos
	slot.size = Vector2(CARD_W, CARD_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	style.border_color = color.darkened(0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	tree_canvas.add_child(slot)
	var label = Label.new()
	label.text = "Tier %d\n???" % tier
	label.position = Vector2(0, 8)
	label.size = Vector2(CARD_W, CARD_H)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	slot.add_child(label)

func add_card(node: Dictionary, color: Color, pos: Vector2) -> void:
	var button = make_node_button(node, color)
	button.position = pos
	button.size = Vector2(CARD_W, CARD_H)
	tree_canvas.add_child(button)

func make_node_button(node: Dictionary, color: Color) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(CARD_W, CARD_H)
	button.add_theme_font_size_override("font_size", 11)
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var unlocked = GameState.is_skill_unlocked(node.id)
	var cost_line = "%d pt" % node.cost
	for mat_id in node.materials.keys():
		cost_line += " + %dx %s" % [node.materials[mat_id], Inventory.get_display_name(mat_id)]
	if unlocked:
		button.text = "✔ " + node.name + "\n" + node.desc
		button.disabled = true
	else:
		button.text = node.name + "\n" + node.desc + "\n" + cost_line
		button.pressed.connect(_on_node_pressed.bind(node))
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.2) if unlocked else Color(0.14, 0.14, 0.17, 1.0)
	style.border_color = color if unlocked else color.darkened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("hover", style)
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
