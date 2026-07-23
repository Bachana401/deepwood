extends CanvasLayer
# THE BUILDER'S LEDGER (B key; dev request 2026-07-21).
#
# One place to see the whole village at a glance: every site, what state it is
# in, and -- once you have uncovered it -- what it is FOR. Deliberately not an
# encyclopedia ("not full information"): an uncleared heap is a "?", a cleared
# ruin shows its name and a one-line purpose, and the numbers (workers, levels,
# health) stay in each building's own E-panel where they always lived. This
# window answers "what am I building, and why" -- nothing else.

const PURPOSE := {
	"Government": "the village's head — advisors, decrees, direction",
	"School": "raises the children toward a calling",
	"Farm": "grows the food that keeps everyone fed",
	"Hospital": "a staffed ward that heals the hurt",
	"Barracks": "trains defenders and holds the walls",
	"Fishing Dock": "steady food from the water",
	"Science Lab": "studies what you haul out of the deep",
	"Bank": "keeps the treasury and pays out interest",
	"Blacksmith": "forges armour and arms for sale",
	"Tavern": "beds for the newly rescued",
	"Bar": "songs and drink — the village's spirits",
	"Marketplace": "trade, and a little coin from every stall",
	"Builderhouse": "the builders who raise everything else",
	"Mine": "digs stone and ore from under the hills",
	"Shrine": "where sorrow-crystals are cleansed",
	"Cottage": "a family's home",
	"Wall": "a rampart the siege breaks against — raise one at the gate the wave comes from",
	"Watchtower": "eyes on the horizon — early siege warning",
	"Wanderer's Post": "draws wanderers in from the roads",
}

var panel: Panel = null
var rows_box: VBoxContainer = null
var title: Label = null
var detail_label: Label = null   # hover a building -> its materials + purpose show here

func _ready() -> void:
	layer = 50
	add_to_group("esc_window")
	_build_panel()
	panel.visible = false

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_menu"):
		panel.visible = not panel.visible
		if panel.visible:
			refresh()
		get_viewport().set_input_as_handled()

func _build_panel() -> void:
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	add_child(panel)

	title = Label.new()
	title.text = "THE BUILDER'S LEDGER"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.62))
	title.position = Vector2(0, 10)
	title.size = Vector2(660, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var hint = Label.new()
	hint.text = "hover a building for its cost + what it does · click Build to place it"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.64))
	hint.position = Vector2(0, 36)
	hint.size = Vector2(660, 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 60)
	scroll.size = Vector2(628, 400)
	panel.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(608, 0)
	rows_box.add_theme_constant_override("separation", 3)
	scroll.add_child(rows_box)

	# the hover detail: materials + what the building is for
	var detail_bg = ColorRect.new()
	detail_bg.color = Color(0.12, 0.12, 0.15, 0.85)
	detail_bg.position = Vector2(16, 468)
	detail_bg.size = Vector2(628, 66)
	panel.add_child(detail_bg)
	detail_label = Label.new()
	detail_label.position = Vector2(28, 474)
	detail_label.size = Vector2(604, 56)
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.85, 0.86, 0.8))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(detail_label)

	# Delete a building: click it, then a YES/NO panel makes you sure.
	var del_btn = Button.new()
	del_btn.text = "🗑  Delete a Building"
	del_btn.position = Vector2(120, 544)
	del_btn.size = Vector2(190, 30)
	del_btn.pressed.connect(_start_delete)
	panel.add_child(del_btn)

	var close = Button.new()
	close.text = "Close (B)"
	close.position = Vector2(420, 544)
	close.size = Vector2(110, 30)
	close.pressed.connect(func(): panel.visible = false)
	panel.add_child(close)

# The ledger's four site states, in the order the player meets them.
func _site_state(bn: String) -> Dictionary:
	if not GameState.building_is_cleared(bn):
		# show the shovelling already done -- three anonymous heaps read as one
		# heap repeated, but "2/3 cleared" is a thing you are half-way through
		var done: int = GameState.building_clear_progress(bn)
		var label := "rubble — press E at the site to clear it"
		if done > 0:
			label = "rubble, %d/%d cleared — press E to keep digging" % [done, GameState.CLEAR_STEPS]
		return {"label": label, "color": Color(0.55, 0.52, 0.5),
			"known": false, "group": "rubble"}
	if GameState.building_build_stage(bn) >= GameState.TOTAL_BUILD_STAGES:
		return {"label": "standing", "color": Color(0.55, 0.78, 0.55),
			"known": true, "group": "standing"}
	if not GameState.has_blueprint(bn):
		return {"label": "cleared — its plans are still lost in the deep",
			"color": Color(0.72, 0.62, 0.45), "known": true, "group": "noplans"}
	if GameState.building_build_stage(bn) == 0:
		return {"label": "cleared — ready to build (F at the site)",
			"color": Color(0.6, 0.72, 0.55), "known": true, "group": "ready"}
	return {"label": "under construction — stage %d/%d (F at the site)" % [
		GameState.building_build_stage(bn), GameState.TOTAL_BUILD_STAGES],
		"color": Color(0.72, 0.7, 0.5), "known": true, "group": "building"}

# A LIST OF ELEVEN IDENTICAL LINES IS NOT A MENU (polish pass 2026-07-21).
# Early on, every site is an unnamed heap, so the first ledger a player ever
# opens read as eleven copies of "an unrecognisable ruin" -- nothing to act on,
# no way to tell one from another, no idea where any of them were. The secret
# stays kept (that is the design), but the window now answers the two questions
# it should: WHAT IS THERE TO DO, and WHERE DO I GO. Sites are grouped by what
# they need from you, urgent group first, and every row carries a bearing from
# where you are standing.
const GROUP_ORDER := ["ready", "building", "rubble", "noplans", "standing"]
const GROUP_TITLE := {
	"ready": "READY TO BUILD",
	"building": "UNDER CONSTRUCTION",
	"rubble": "BURIED — needs clearing",
	"noplans": "CLEARED — plans still lost in the deep",
	"standing": "STANDING",
}
const GROUP_COLOR := {
	"ready": Color(0.62, 0.82, 0.55),
	"building": Color(0.85, 0.78, 0.45),
	"rubble": Color(0.72, 0.66, 0.6),
	"noplans": Color(0.72, 0.62, 0.45),
	"standing": Color(0.55, 0.72, 0.6),
}

func refresh() -> void:
	for c in rows_box.get_children():
		c.queue_free()
	_set_detail("Hover a building to see what it costs and what it does.")
	# A PLAIN LIST of every building by name -- no "buried / cleared / standing"
	# grouping (dev ask 2026-07-22). The Cottage has no pre-placed node, so first.
	if GameState.has_blueprint("Cottage"):
		rows_box.add_child(_build_row("Cottage", null))
	if GameState.has_blueprint("Wall"):
		rows_box.add_child(_build_row("Wall", null))
	var by_name := {}
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b:
			by_name[str(b.building_name)] = b
	var names: Array = by_name.keys()
	names.sort()
	var standing := 0
	for nm in names:
		rows_box.add_child(_build_row(str(nm), by_name[nm]))
		if GameState.building_build_stage(str(nm)) >= GameState.TOTAL_BUILD_STAGES:
			standing += 1
	title.text = "THE BUILDER'S LEDGER — %d of %d built" % [standing, names.size()]

# One button per building: its name, and Build (cost) when you can raise it.
# Hovering it fills the detail strip with its cost + what it's for.
func _build_row(bn: String, node) -> Control:
	var built: bool = node != null and GameState.building_build_stage(bn) >= GameState.TOTAL_BUILD_STAGES
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(600, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	if built:
		btn.text = "  %s   —   ✓ built" % bn
		btn.add_theme_color_override("font_color", Color(0.6, 0.8, 0.62))
	elif GameState.has_blueprint(bn):
		btn.text = "  %s   —   Build (%s)" % [bn, _cost_text(bn)]
	else:
		btn.text = "  %s   —   blueprint not found" % bn
		btn.add_theme_color_override("font_color", Color(0.66, 0.62, 0.58))
	btn.mouse_entered.connect(func() -> void: _show_detail(bn))
	btn.pressed.connect(func() -> void: _on_build_pressed(bn, node, built))
	return btn

func _on_build_pressed(bn: String, node, built: bool) -> void:
	if bn == "Cottage":
		panel.visible = false
		_placer().start_build("Cottage", 90.0, 80.0, Color(0.58, 0.5, 0.35))
		return
	if bn == "Wall":
		panel.visible = false
		_placer().start_build("Wall", 64.0, 132.0, Color(0.5, 0.5, 0.55))
		return
	if built:
		_set_detail("The %s is already built. (Delete it first if you want to move it.)" % bn)
		return
	if not GameState.has_blueprint(bn):
		_set_detail("You haven't found the %s's blueprint yet — it lies somewhere in the deep." % bn)
		return
	_start_build(bn, node)

func _show_detail(bn: String) -> void:
	var purpose: String = PURPOSE.get(bn, "")
	if GameState.has_blueprint(bn):
		_set_detail("%s — %s\nNeeds: %s" % [bn, purpose, _cost_text(bn)])
	else:
		_set_detail("%s — %s\nBlueprint not found yet — look for its plans in the deep." % [bn, purpose])

func _set_detail(text: String) -> void:
	if detail_label != null:
		detail_label.text = text

# The world-space placer that carries the build hologram + the delete popup;
# made once, lazily, and parked in the village scene.
func _placer() -> Node:
	var pl = get_tree().get_first_node_in_group("build_placer")
	if pl == null:
		pl = preload("res://build_placer.gd").new()
		get_tree().current_scene.add_child(pl)
	return pl

func _start_build(bn: String, node: Node) -> void:
	panel.visible = false
	var w: float = float(node.width) if "width" in node else 120.0
	var h: float = float(node.height) if "height" in node else 90.0
	var col: Color = node.body_color if "body_color" in node else Color(0.5, 0.45, 0.4)
	_placer().start_build(bn, w, h, col)

func _start_delete() -> void:
	panel.visible = false
	_placer().start_delete()

func _make_header(group: String, count: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	box.add_child(pad)
	var h := Label.new()
	h.text = "%s  (%d)" % [GROUP_TITLE.get(group, group), count]
	h.add_theme_font_size_override("font_size", 12)
	h.add_theme_color_override("font_color", GROUP_COLOR.get(group, Color.WHITE))
	box.add_child(h)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(600, 1)
	rule.color = GROUP_COLOR.get(group, Color.WHITE)
	rule.color.a = 0.35
	box.add_child(rule)
	return box

# "260 paces west" -- enough to walk to, never a map coordinate.
func _bearing(dx: float) -> String:
	if absf(dx) < 90.0:
		return "right here"
	return "%d paces %s" % [int(absf(dx) / 10.0), "east" if dx > 0.0 else "west"]

func _cottage_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var h := Label.new()
	h.text = "RAISE A HOME"
	h.add_theme_font_size_override("font_size", 12)
	h.add_theme_color_override("font_color", Color(0.72, 0.84, 0.72))
	box.add_child(h)
	var line := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Cottage — a home for a family"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	lbl.custom_minimum_size = Vector2(300, 0)
	line.add_child(lbl)
	var cost := Label.new()
	cost.text = _cost_text("Cottage")
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.custom_minimum_size = Vector2(100, 0)
	line.add_child(cost)
	var build := Button.new()
	build.text = "Build (%s)" % _cost_text("Cottage")
	build.custom_minimum_size = Vector2(180, 0)
	build.add_theme_font_size_override("font_size", 11)
	build.pressed.connect(func() -> void:
		panel.visible = false
		_placer().start_build("Cottage", 90.0, 80.0, Color(0.58, 0.5, 0.35)))
	line.add_child(build)
	box.add_child(line)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(600, 1)
	rule.color = Color(0.35, 0.4, 0.35, 0.5)
	box.add_child(rule)
	return box

func _cost_text(bn: String) -> String:
	var parts := PackedStringArray()
	for k in GameState.build_cost(bn):
		var nm: String = "g" if k == "coin_gold" else Inventory.get_display_name(k)
		parts.append("%d%s" % [int(GameState.build_cost(bn)[k]), (nm if k == "coin_gold" else " " + nm)])
	return ", ".join(parts)

func _make_row(bn: String, st: Dictionary, dx: float, node: Node) -> Control:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var head_line = HBoxContainer.new()
	var head = Label.new()
	# an uncleared site keeps its secret: no name in the ledger either
	head.text = (bn if st["known"] else "an unrecognisable ruin")
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color",
		Color(0.88, 0.88, 0.92) if st["known"] else Color(0.6, 0.58, 0.56))
	head.custom_minimum_size = Vector2(300, 0)
	head_line.add_child(head)
	# where it is, so anonymous heaps are findable
	var where = Label.new()
	where.text = _bearing(dx)
	where.add_theme_font_size_override("font_size", 11)
	where.add_theme_color_override("font_color", Color(0.58, 0.62, 0.7))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	where.custom_minimum_size = Vector2(100, 0)
	head_line.add_child(where)
	# BUILD IT (dev 2026-07-22): a site not yet standing gets a Build button --
	# click to raise it on ground YOU pick, with the green/red placement holo.
	if str(st.get("group", "")) != "standing":
		var build := Button.new()
		build.text = "Build (%s)" % _cost_text(bn)
		build.custom_minimum_size = Vector2(180, 0)
		build.add_theme_font_size_override("font_size", 11)
		build.pressed.connect(func() -> void: _start_build(bn, node))
		head_line.add_child(build)
	row.add_child(head_line)
	var state = Label.new()
	state.text = "   " + st["label"]
	state.add_theme_font_size_override("font_size", 11)
	state.add_theme_color_override("font_color", st["color"])
	row.add_child(state)
	if st["known"] and PURPOSE.has(bn):
		var why = Label.new()
		why.text = "   " + PURPOSE[bn]
		why.add_theme_font_size_override("font_size", 11)
		why.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68))
		row.add_child(why)
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(600, 1)
	sep.color = Color(0.3, 0.29, 0.27, 0.6)
	row.add_child(sep)
	return row
