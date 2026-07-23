extends Node
# RUINS ARE PURELY VISUAL + the flat Builder's Ledger (B). (Rewritten 2026-07-22:
# the old model -- E×3 to clear a nameless heap, a ledger grouped by what a site
# needs with a bearing to walk to -- was replaced. A ruin is now inert decor you
# raise or delete from the B menu, and the ledger is a plain A-Z list of buildings
# by NAME. This test asserts THAT reality.)

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(30):
		keep_running()
		await get_tree().process_frame

	# a genuinely fresh village: nothing built, every site a ruin
	GameState.reset_for_new_game()
	var b: Node = null
	for n in get_tree().get_nodes_in_group("building"):
		if n.building_name == "Farm":
			b = n
	check("a Farm site exists", b != null)
	if b == null:
		printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return
	b.current_state = b.compute_visual_state()
	b.rebuild_geometry()
	b.update_name_label()
	await get_tree().process_frame

	# ---- a ruin is PURELY VISUAL: rubble on the ground, no name, no prompt ----
	check("a fresh site reads as a ruin", b.is_ruined())
	check("a fresh ruin is NOT counted as cleared", not GameState.building_is_cleared("Farm"))
	check("the rubble mounds still render on the ground", b.rubble_layer != null
		and b.rubble_layer.get_child_count() > 0)
	check("no name floats over the ruin", not b.name_label.visible)
	b.update_prompt()
	check("an inert ruin shows NO prompt at all (never 'Press E to clear')",
		not b.prompt_label.visible and b.prompt_label.text == "",
		"visible=%s text='%s'" % [b.prompt_label.visible, b.prompt_label.text])

	# ---- a standing building is not a ruin and shows its name ----
	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES
	var bar: Node = null
	for n in get_tree().get_nodes_in_group("building"):
		if n.building_name == "Bar":
			bar = n
	if bar != null:
		bar.build_stage = GameState.TOTAL_BUILD_STAGES   # sync the node to the state
		bar.current_state = bar.compute_visual_state()
		bar.rebuild_geometry()
		bar.update_name_label()
		await get_tree().process_frame
		check("a standing building is no longer a ruin", not bar.is_ruined())
		check("...and it counts as cleared", GameState.building_is_cleared("Bar"))
		check("...and its name shows", bar.name_label.visible)

	# ---- the Builder's Ledger is a FLAT list of buildings by name ----
	var menu: Node = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("build_menu.gd"):
			menu = n
	check("the ledger is mounted in the village", menu != null)
	if menu != null:
		menu.panel.visible = true
		menu.refresh()
		await get_tree().process_frame
		var joined: String = _all_text(menu.rows_box)
		check("the ledger lists the sites", menu.rows_box.get_child_count() >= 10,
			"%d rows" % menu.rows_box.get_child_count())
		# the FLAT model: every site is named outright, no "unrecognisable ruin",
		# no group headers, no walking bearings
		check("sites are named outright, no anonymous heaps", joined.contains("Farm")
			and not joined.contains("an unrecognisable ruin"))
		check("no grouping headers", not joined.contains("BURIED — needs clearing")
			and not joined.contains("READY TO BUILD"))
		check("no walking bearings", not joined.contains("paces"))
		# a starter you hold the plans for offers a priced Build...
		check("a starter offers a priced Build", joined.contains("Farm")
			and joined.contains("Build ("))
		# ...and Cottage + Wall are buildable rows of their own (not world nodes)
		check("Cottage is a buildable row", joined.contains("Cottage"))
		check("Wall is a buildable row", joined.contains("Wall"))
		# a building whose blueprint is still lost reads so, with no Build offer
		check("a blueprint you lack reads 'blueprint not found'",
			joined.contains("blueprint not found"))
		# a standing building reads as built, not as a build target
		check("a standing building shows as built", joined.contains("✓ built"))
		menu.panel.visible = false

	# every building named in the ledger's purpose map must resolve to a real
	# building OR a known buildable/dynamic site (Cottage + Wall are placed fresh
	# from the menu; the Watchtower bell + Wanderer's Post counter are sub-features)
	var known := {}
	for n in get_tree().get_nodes_in_group("building"):
		known[n.building_name] = true
	for bn in ["Cottage", "Wall", "Watchtower", "Wanderer's Post"]:
		known[bn] = true
	if menu != null:
		for bn in menu.PURPOSE.keys():
			check("ledger purpose '%s' resolves to a real site" % bn, known.has(bn))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# The ledger nests labels inside buttons/boxes, so a one-level scrape misses text.
func _all_text(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label:
			out += c.text + "\n"
		if c is Button:
			out += c.text + "\n"
		out += _all_text(c)
	return out
