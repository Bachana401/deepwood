extends Node
# THE FINALE IS AN EVENT (dev 2026-07-23). The Harvest monarch -- the game's FINAL
# boss, fought in the streets -- had no boss spectacle: the BossHUD is only ever
# seated in the dungeon, so update_health_bar's set_health found nothing and the
# climax showed only the tiny overhead bar (no name-card, no top banner). This locks:
# the director seats a BossHUD and presents "The Monarch of Despair", the monarch +
# allies spawn without crashing, and the siege foresight label stands aside during the
# Harvest so the two don't collide top-centre. See [[deepwood-boss-ladder]].

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1400):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("test_finale : no player"); get_tree().quit(1); return

	# clean, unpaused village (the opening otherwise pauses the tree)
	GameState.dev_mode = true
	GameState.seen_arrival_battle = true
	GameState.seen_intro = true
	GameState.opening_done = true
	get_tree().paused = false
	get_tree().reload_current_scene()
	for i in range(30):
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group("player")
	if p == null: printerr("test_finale : no player after reload"); get_tree().quit(1); return
	get_tree().paused = false

	GameState.harvested_villagers = []
	for i in range(12):
		GameState.harvested_villagers.append({"id": "h_%d" % i, "name": "Villager %d" % i, "sex": "Male"})

	var d = preload("res://harvest_director.gd").new()
	d.resume = true
	get_tree().current_scene.add_child(d)          # _ready plays HARVEST_RESUME + sets bounds
	for i in range(20):
		await get_tree().process_frame
	# neutralise the dialogue callbacks + free the boxes, then drive the fight directly
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			if "_on_finished" in n: n._on_finished = Callable()
			n.queue_free()
	get_tree().paused = false
	await get_tree().process_frame

	check("director marks harvest_at_home", GameState.harvest_at_home)
	d.resume_fight()                               # if this crashed, we'd never RESULT
	for i in range(20):
		await get_tree().process_frame

	# --- the spectacle is now seated + presented in the VILLAGE ---
	var hud = get_tree().get_first_node_in_group("boss_hud")
	check("the finale seats a BossHUD (the climax gets the spectacle)", hud != null)
	check("the monarch spawned", ("_monarch" in d) and d._monarch != null and is_instance_valid(d._monarch))
	check("the Ten (+ Roland) hold lanes as allies", get_tree().get_nodes_in_group("ten_ally").size() > 0)

	# --- the seated banner is fed the monarch's health (not a dead no-op) ---
	if hud != null and "_hp_target" in hud:
		check("the boss health banner is live (fraction in 0..1)", hud._hp_target >= 0.0 and hud._hp_target <= 1.0)

	# --- source: the director presents by the chosen name; the foresight yields ---
	var hsrc := FileAccess.open("res://harvest_director.gd", FileAccess.READ).get_as_text()
	check("the director presents the monarch with a name-card",
		hsrc.contains("hud.present(") and hsrc.contains("The Monarch of Despair"))
	var ssrc := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the siege foresight label stands aside during the Harvest",
		ssrc.contains("elif GameState.harvest_at_home:") and ssrc.contains("stands aside"))

	printerr("test_finale : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
