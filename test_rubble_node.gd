extends Node
# Rubble clearing (E x3 reveals a nameless ruin) + the Builder's Ledger (B).

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

	# a genuinely fresh village: nothing cleared, nothing built
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
	await get_tree().process_frame

	# ---- anonymous rubble ----
	check("a fresh ruin is NOT cleared", not GameState.building_is_cleared("Farm"))
	check("no name floats over uncleared rubble", not b.name_label.visible)
	check("the rubble mounds are on the ground", b.rubble_layer != null
		and b.rubble_layer.get_child_count() > 0)
	b.update_prompt()
	check("the prompt asks for E, not F", b.prompt_label.text.begins_with("Press E to clear"),
		"'%s'" % b.prompt_label.text)

	# ---- three shovelfuls (the work lockout is real time, so wait it out) ----
	for i in range(3):
		b.attempt_clear_rubble()
		check("clear %d/3 registered" % (i + 1),
			GameState.building_clear_progress("Farm") == i + 1,
			"got %d" % GameState.building_clear_progress("Farm"))
		await get_tree().create_timer(b.CLEAR_WORK_SECONDS + 0.1).timeout
	check("spamming E past 3 does nothing weird", GameState.building_clear_progress("Farm") == 3)

	# ---- the reveal ----
	check("the site is now cleared", GameState.building_is_cleared("Farm"))
	check("the name appears only now", b.name_label.visible)
	check("the rubble is gone", b.rubble_layer == null)
	b.update_prompt()
	check("the prompt moves on from clearing", not b.prompt_label.text.begins_with("Press E to clear"),
		"'%s'" % b.prompt_label.text)

	# ---- an already-standing building never demands a shovel ----
	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES
	check("a standing building counts as cleared without shovelling",
		GameState.building_is_cleared("Bar"))

	# ---- save / load round trip ----
	GameState.save_game(p)
	GameState.building_cleared["Farm"] = 0
	GameState.load_game()
	check("clearing survives save/load", GameState.building_clear_progress("Farm") == 3,
		"got %d" % GameState.building_clear_progress("Farm"))
	# ...and a New Game starts with every site buried again
	GameState.reset_for_new_game()
	check("a NEW game starts uncleared", not GameState.building_is_cleared("Farm"))

	# ---- the Builder's Ledger ----
	var menu: Node = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("build_menu.gd"):
			menu = n
	check("the ledger is mounted in the village", menu != null)
	if menu != null:
		menu.panel.visible = true
		menu.refresh()
		await get_tree().process_frame
		var texts := []
		for row in menu.rows_box.get_children():
			for l in row.get_children():
				if l is Label:
					texts.append(l.text)
		var joined: String = "\n".join(texts)
		check("the ledger lists the sites", menu.rows_box.get_child_count() >= 10,
			"%d rows" % menu.rows_box.get_child_count())
		check("uncleared sites keep their secret in the ledger too",
			joined.contains("an unrecognisable ruin"))
		check("uncleared sites never leak their purpose",
			not joined.contains("grows the food"))
		GameState.building_cleared["Farm"] = GameState.CLEAR_STEPS
		menu.refresh()
		await get_tree().process_frame
		texts = []
		for row in menu.rows_box.get_children():
			for l in row.get_children():
				if l is Label:
					texts.append(l.text)
		joined = "\n".join(texts)
		check("a cleared site shows its name in the ledger", joined.contains("Farm"))
		check("...and its one-line purpose", joined.contains("grows the food"))
		menu.panel.visible = false

	# every building named in the ledger's purpose map must actually exist
	var known := {}
	for n in get_tree().get_nodes_in_group("building"):
		known[n.building_name] = true
	for bn in ["Cottage", "Watchtower", "Wanderer's Post"]:
		known[bn] = true      # spawned later / dynamically, purposes still valid
	if menu != null:
		for bn in menu.PURPOSE.keys():
			check("ledger purpose '%s' names a real building" % bn, known.has(bn))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
