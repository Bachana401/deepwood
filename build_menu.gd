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
	"Marketplace": "trade — and the Wanderer's Post, where road-merchants set up their carts",
	"Builderhouse": "the builders who raise everything else",
	"Mine": "digs stone and ore from under the hills",
	"Shrine": "where sorrow-crystals are cleansed",
	"Cottage": "a family's home",
	"Wall": "a rampart the siege breaks against — raise one at the gate the wave comes from",
	"Watchtower": "eyes on the horizon — early siege warning",
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
	# map any LIVE building node by name (for its built status)...
	var by_name := {}
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b:
			by_name[str(b.building_name)] = b
	# ...but list the WHOLE roster (dev 2026-07-23: most sites start as open ground
	# with no ruin now, yet must still be buildable). A site with no live node builds
	# fresh via create_building; a deleted or unraised one lists all the same.
	var scene = get_tree().current_scene
	var names: Array = scene.building_names() if (scene != null and scene.has_method("building_names")) else by_name.keys()
	names.sort()
	var standing := 0
	for nm in names:
		rows_box.add_child(_build_row(str(nm), by_name.get(str(nm), null)))
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

func _start_build(bn: String, node) -> void:
	panel.visible = false
	var w := 120.0
	var h := 90.0
	var col := Color(0.5, 0.45, 0.4)
	if node != null and "width" in node:
		# a live ruin gives its own dimensions
		w = float(node.width)
		h = float(node.height)
		col = node.body_color
	else:
		# a DELETED building has no node -- size the holo from the village roster
		var scene = get_tree().current_scene
		if scene != null and scene.has_method("building_def"):
			var def: Dictionary = scene.building_def(bn)
			if not def.is_empty():
				var sc := float(def.get("scale", 2.0))
				w = float(def.width) * sc * 1.3
				h = float(def.height) * sc * 1.3
				col = def.color
	_placer().start_build(bn, w, h, col)

func _start_delete() -> void:
	panel.visible = false
	_placer().start_delete()

func _cost_text(bn: String) -> String:
	var parts := PackedStringArray()
	for k in GameState.build_cost(bn):
		var nm: String = "g" if k == "coin_gold" else Inventory.get_display_name(k)
		parts.append("%d%s" % [int(GameState.build_cost(bn)[k]), (nm if k == "coin_gold" else " " + nm)])
	return ", ".join(parts)
