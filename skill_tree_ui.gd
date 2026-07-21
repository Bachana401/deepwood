extends CanvasLayer

# Skill tree window (K to toggle) + the always-visible XP bar. Everything is
# built procedurally in _ready() so one small .tscn can be instanced into
# both main.tscn and dungeon_interior.tscn identically.
#
# The tree is drawn as a real GRAPH from each node's own (col, tier): a root at
# the top fans into 3 spec spines; each spine FORKS (two cards side by side at
# tier 4) and reconverges. Connector lines are drawn from every node to each of
# its prereqs, so forks and convergences read visually. Deeper tiers stay hidden
# ("???") until you unlock within 2 tiers of them.

const RESET_POTION_COST = 150

var panel: Panel
var _fork_armed := ""   # the fork node warned about, awaiting its second click
var class_choice_box: VBoxContainer
var tree_scroll: ScrollContainer
var tree_canvas: Control
var title_label: Label
var points_label: Label
var xp_fill: ColorRect
var xp_label: Label

# Tree layout geometry (canvas-local pixels). Cards are placed purely from their
# node.col (lane) and node.tier (row); spec spines sit on half-lanes (x.5) with
# their two fork cards on the integer lanes either side.
#
# CARD_H IS A MEASUREMENT, NOT A WISH (visual sweep 2026-07-21). It used to say
# 60, but a card's text is three wrapped lines, and a Button never shrinks below
# its own minimum size -- so cards actually drew ~76 tall. Everything spaced off
# the 60 was therefore wrong on screen: tier rows touched with no gap, connector
# lines anchored inside the cards instead of at their edges, and the centre spec
# header ("Guardian") was drawn underneath the root card. The spacing below is
# measured from what the cards really are.
const CARD_W = 140.0
const CARD_H = 76.0
const LEFT_MARGIN = 12.0
const LANE_W = 146.0
const ROOT_TOP = 6.0
const HEADER_Y = 90.0          # clears the root card (ROOT_TOP + CARD_H + 8)
const TIER1_Y = 118.0          # clears the header label (HEADER_Y + 22 + 6)
const TIER_SPACING = 86.0      # CARD_H + a 10px breathing gap

func _ready() -> void:
	layer = 50
	add_to_group("esc_window")
	build_xp_bar()
	build_panel()
	panel.visible = false

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
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
	panel.offset_left = -460.0
	panel.offset_top = -290.0
	panel.offset_right = 460.0
	panel.offset_bottom = 290.0
	add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(16, 8)
	title_label.size = Vector2(888, 30)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	points_label = Label.new()
	points_label.position = Vector2(16, 40)
	points_label.size = Vector2(888, 22)
	points_label.add_theme_font_size_override("font_size", 13)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(points_label)

	class_choice_box = VBoxContainer.new()
	class_choice_box.position = Vector2(310, 92)
	class_choice_box.size = Vector2(300, 340)
	class_choice_box.add_theme_constant_override("separation", 12)
	panel.add_child(class_choice_box)

	tree_scroll = ScrollContainer.new()
	tree_scroll.position = Vector2(16, 68)
	tree_scroll.size = Vector2(888, 476)
	panel.add_child(tree_scroll)
	tree_canvas = Control.new()
	tree_canvas.custom_minimum_size = Vector2(894, 476)
	tree_scroll.add_child(tree_canvas)

	var close = Button.new()
	close.text = "Close (K)"
	close.position = Vector2(16, 550)
	close.size = Vector2(110, 32)
	close.pressed.connect(func(): panel.visible = false)
	panel.add_child(close)

	var reset = Button.new()
	reset.text = "Drink Reset Potion (%dg)" % RESET_POTION_COST
	reset.position = Vector2(710, 550)
	reset.size = Vector2(194, 32)
	reset.pressed.connect(_on_reset_potion)
	panel.add_child(reset)

	# --- testing sandbox (GameState.TEST_SKILL_SANDBOX): every node is free to
	# unlock (0 skill points, 0 materials -- see try_unlock_skill). You still
	# click each upgrade yourself, and fork choices are STILL exclusive (you must
	# pick a side). A free class switch lets you go test another tree. ---
	if GameState.TEST_SKILL_SANDBOX:
		var switch = Button.new()
		switch.text = "⇄ Switch Class"
		switch.position = Vector2(140, 550)
		switch.size = Vector2(150, 32)
		switch.pressed.connect(_on_switch_class)
		panel.add_child(switch)

# Free class switch that KEEPS what you've unlocked (unlike the reset potion),
# so you can go upgrade another tree while testing.
func _on_switch_class() -> void:
	GameState.chosen_class = ""
	refresh()

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
		if GameState.TEST_SKILL_SANDBOX:
			# free-pass testing: names show real (no "Unknown Substance") and
			# every node costs nothing -- just click to upgrade. Forks stay
			# exclusive so you still experience the real choice.
			GameState.research_all_materials()
			points_label.text = "Sandbox: upgrades FREE (0 pts, 0 mats) — but forks are still one-or-the-other"
		else:
			points_label.text = "Skill points: %d      (★ keystones grant mechanics; forks lock out the other side)" % GameState.skill_points
		rebuild_tree()

func rebuild_class_choice() -> void:
	for child in class_choice_box.get_children():
		child.queue_free()
	for class_name_key in ["Sword", "Archer", "Mage", "Shadow Monarch"]:
		var button = Button.new()
		var color = SkillTreeData.CLASS_COLORS[class_name_key]
		button.custom_minimum_size = Vector2(0, 48)
		var monarch_open = GameState.game_completed or GameState.TEST_SKILL_SANDBOX
		if class_name_key == "Shadow Monarch" and not monarch_open:
			button.text = "Shadow Monarch  [LOCKED -- finish the game]"
			button.disabled = true
		else:
			button.text = class_name_key
			if class_name_key == "Shadow Monarch":
				button.text = "Shadow Monarch  ★ UNLOCKED" if GameState.game_completed else "Shadow Monarch  [sandbox preview]"
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

# Per-branch reveal: within a branch you can only see 2 tiers past that branch's
# own deepest unlock (a fresh branch shows tiers 1-2).
func deepest_unlocked_tier_in_branch(branch: int) -> int:
	var deepest = 0
	for node in SkillTreeData.TREES.get(GameState.chosen_class, []):
		if node.branch == branch and GameState.is_skill_unlocked(node.id):
			deepest = max(deepest, node.tier)
	return deepest

# --- graph layout: everything is derived from node.col (lane) and node.tier ---
func lane_x(col: float) -> float:
	return LEFT_MARGIN + col * LANE_W

func node_pos(node: Dictionary) -> Vector2:
	# top-left of the card
	if node.get("branch", 0) == -1 and node.tier == 0 and not node.get("default_unlocked", false):
		return Vector2(lane_x(float(node.get("col", 2.5))), ROOT_TOP)   # root trunk
	if node.get("default_unlocked", false):
		return Vector2(8.0, ROOT_TOP)                                   # innate Levitate (corner)
	return Vector2(lane_x(float(node.get("col", 0.5))), tier_top_y(node.tier))

func node_center(node: Dictionary) -> Vector2:
	var p = node_pos(node)
	return Vector2(p.x + CARD_W / 2.0, p.y + CARD_H / 2.0)

func tier_top_y(tier: int) -> float:
	return TIER1_Y + (tier - 1) * TIER_SPACING

func prereq_ids(node: Dictionary) -> Array:
	var pr = node.get("prereq", "")
	if pr is Array:
		return pr
	if pr == "":
		return []
	return [pr]

func rebuild_tree() -> void:
	for child in tree_canvas.get_children():
		child.queue_free()
	var color = SkillTreeData.CLASS_COLORS.get(GameState.chosen_class, Color.WHITE)
	var tree_nodes = SkillTreeData.TREES.get(GameState.chosen_class, [])
	var branch_names = SkillTreeData.BRANCH_NAMES.get(GameState.chosen_class, ["", "", ""])

	# size the scrollable canvas to the deepest tier present
	var overall_max_tier = 1
	for node in tree_nodes:
		overall_max_tier = max(overall_max_tier, node.tier)
	tree_canvas.custom_minimum_size = Vector2(894, max(476.0, tier_top_y(overall_max_tier) + CARD_H + 20.0))

	# connectors first (z=-1) so cards render over them. One line per prereq
	# link -> forks fan out, convergence nodes gather two lines back in.
	for node in tree_nodes:
		if node.get("default_unlocked", false):
			continue
		for pid in prereq_ids(node):
			var parent = SkillTreeData.get_node_by_id(pid)
			if parent.is_empty():
				continue
			var from_pt = node_center(parent) + Vector2(0, CARD_H / 2.0)
			var to_pt = node_center(node) - Vector2(0, CARD_H / 2.0)
			var lit = GameState.is_skill_unlocked(node.id)
			add_connector(from_pt, to_pt, color, lit)

	# spec headers
	for branch in range(3):
		var header = Label.new()
		header.text = branch_names[branch]
		header.position = Vector2(lane_x(0.5 + branch * 2.0) - CARD_W / 2.0, HEADER_Y)
		header.size = Vector2(CARD_W * 2.0, 22)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", color.lightened(0.3))
		tree_canvas.add_child(header)

	# nodes: revealed cards, or a "???" slot if still too deep
	for node in tree_nodes:
		var pos = node_pos(node)
		if node.branch == -1:
			add_card(node, color, pos)
			continue
		var visible_limit = deepest_unlocked_tier_in_branch(node.branch) + 2
		if node.tier > visible_limit:
			add_hidden_slot(node.tier, color, pos)
		else:
			add_card(node, color, pos)

func add_connector(from_pt: Vector2, to_pt: Vector2, color: Color, lit: bool) -> void:
	var line = Line2D.new()
	line.points = PackedVector2Array([from_pt, to_pt])
	line.width = 3.0 if lit else 2.0
	line.default_color = Color(color.r, color.g, color.b, 0.85) if lit else Color(0.4, 0.4, 0.45, 0.5)
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
	button.add_theme_font_size_override("font_size", 10)
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var unlocked = GameState.is_skill_unlocked(node.id)
	var blocked = SkillTreeData.is_exclusive_blocked(node)
	var is_keystone = node.get("keystone", false)
	var star = "★ " if is_keystone else ""
	var cost_line = "%d pt" % node.cost
	for mat_id in node.materials.keys():
		cost_line += " + %dx %s" % [node.materials[mat_id], Inventory.get_display_name(mat_id)]

	if unlocked:
		button.text = "✔ " + star + node.name + "\n" + node.desc
		button.disabled = true
	elif blocked:
		button.text = "🔒 " + star + node.name + "\n(path not taken)"
		button.disabled = true
	else:
		button.text = star + node.name + "\n" + node.desc + "\n" + cost_line
		button.pressed.connect(_on_node_pressed.bind(node))

	var gold = Color(1.0, 0.78, 0.28)
	var style = StyleBoxFlat.new()
	if blocked:
		style.bg_color = Color(0.12, 0.09, 0.09, 1.0)
		style.border_color = Color(0.45, 0.2, 0.2, 1.0)
		style.set_border_width_all(2)
	elif is_keystone:
		style.bg_color = Color(0.24, 0.19, 0.08, 1.0) if not unlocked else Color(0.4, 0.3, 0.1, 1.0)
		style.border_color = gold
		style.set_border_width_all(3)
	else:
		style.bg_color = color.darkened(0.2) if unlocked else Color(0.14, 0.14, 0.17, 1.0)
		style.border_color = color if unlocked else color.darkened(0.35)
		style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.55, 1) if blocked else Color(0.95, 0.95, 0.95, 1))
	return button

func _on_node_pressed(node: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if not SkillTreeData.prereq_met(node):
		notify("Unlock an earlier node on this path first.")
		return
	if SkillTreeData.is_exclusive_blocked(node):
		notify("You chose the other side of this fork — that path is locked.")
		return
	# A FORK IS FOREVER (polish 2026-07-20): taking one side of a crossroads
	# locks its sibling for the rest of the run, and this used to happen on
	# a single click -- one misclick could quietly end a build. Confirm it
	# the way the game already asks for irreversible things (the Rewound
	# Hour): press once to be warned, again to commit.
	var grp := str(node.get("exclusive", ""))
	if grp != "" and not GameState.is_skill_unlocked(str(node.id)):
		var sibling_names := []
		for other in SkillTreeData.nodes_in_exclusive_group(grp):
			if str(other.id) != str(node.id):
				sibling_names.append(str(other.name))
		if _fork_armed != str(node.id):
			_fork_armed = str(node.id)
			notify("⚠ FORK: taking %s locks %s for this whole run. Click again to commit." % [
				str(node.name), " / ".join(sibling_names)])
			return
	_fork_armed = ""
	# In the testing sandbox every node is free: skip the point + material gates
	# here too (but the fork/prereq gates above still apply, on purpose).
	if not GameState.TEST_SKILL_SANDBOX:
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
