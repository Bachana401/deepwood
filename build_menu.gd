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
	"Watchtower": "eyes on the horizon — early siege warning",
	"Wanderer's Post": "draws wanderers in from the roads",
}

var panel: Panel = null
var rows_box: VBoxContainer = null
var title: Label = null

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
	hint.text = "the village, site by site — details live at each building's own door (E)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.64))
	hint.position = Vector2(0, 36)
	hint.size = Vector2(660, 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(16, 60)
	scroll.size = Vector2(628, 470)
	panel.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(608, 0)
	rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(rows_box)

	var close = Button.new()
	close.text = "Close (B)"
	close.position = Vector2(275, 542)
	close.size = Vector2(110, 30)
	close.pressed.connect(func(): panel.visible = false)
	panel.add_child(close)

# The ledger's four site states, in the order the player meets them.
func _site_state(bn: String) -> Dictionary:
	if not GameState.building_is_cleared(bn):
		return {"label": "rubble — press E at the site to clear it",
			"color": Color(0.55, 0.52, 0.5), "known": false}
	if GameState.building_build_stage(bn) >= GameState.TOTAL_BUILD_STAGES:
		return {"label": "standing", "color": Color(0.55, 0.78, 0.55), "known": true}
	if not GameState.has_blueprint(bn):
		return {"label": "cleared — its plans are still lost in the deep",
			"color": Color(0.72, 0.62, 0.45), "known": true}
	if GameState.building_build_stage(bn) == 0:
		return {"label": "cleared — ready to build (F at the site)",
			"color": Color(0.6, 0.72, 0.55), "known": true}
	return {"label": "under construction — stage %d/%d (F at the site)" % [
		GameState.building_build_stage(bn), GameState.TOTAL_BUILD_STAGES],
		"color": Color(0.72, 0.7, 0.5), "known": true}

func refresh() -> void:
	for c in rows_box.get_children():
		c.queue_free()
	# every real building site currently in the world, steadiest order first
	var names: Array = []
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and not names.has(b.building_name):
			names.append(b.building_name)
	names.sort()
	var standing := 0
	for bn in names:
		var st := _site_state(bn)
		if st["known"] and GameState.building_build_stage(bn) >= GameState.TOTAL_BUILD_STAGES:
			standing += 1
		rows_box.add_child(_make_row(bn, st))
	title.text = "THE BUILDER'S LEDGER — %d of %d standing" % [standing, names.size()]

func _make_row(bn: String, st: Dictionary) -> Control:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var head = Label.new()
	# an uncleared site keeps its secret: no name in the ledger either
	head.text = (bn if st["known"] else "an unrecognisable ruin")
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color",
		Color(0.88, 0.88, 0.92) if st["known"] else Color(0.6, 0.58, 0.56))
	row.add_child(head)
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
