extends Node
# THE OPENING IS CHAT-ONLY (dev 2026-07-22). A new game's first frames should read
# as a cinematic: no "raise the Farm" ticker on frame one, and the HUD chrome falls
# away while any scripted beat is on screen. This asserts both gates.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(20):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame

	# ---- opening_done: a new game starts mid-opening, the tutorial ends it ----
	GameState.dev_mode = false
	GameState.reset_for_new_game()
	check("a fresh game is still in the opening", not GameState.opening_done)
	check("...and old saves are treated as past it",
		bool(JSON.parse_string('{"opening_done": true}').get("opening_done", true)))
	GameState.tutorial_step = -1
	GameState.tutorial_begin()
	check("beginning the build tutorial ends the opening", GameState.opening_done)

	# ---- the objective ticker is silent through the opening ----
	var banner: Node = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("objective_banner.gd"):
			banner = n
	check("the objective banner exists", banner != null)
	if banner != null:
		GameState.opening_done = false
		banner._refresh()
		check("the 'raise the Farm' ticker is HIDDEN during the opening", not banner._wrap.visible)
		GameState.opening_done = true
		GameState.tutorial_step = 0
		banner._refresh()
		check("...still hidden while the interactive tutorial card is up", not banner._wrap.visible)
		GameState.tutorial_step = -1
		banner._refresh()
		check("...and it appears once building is the task and the tutorial is done", banner._wrap.visible)

	# ---- the interactive tutorial card walks the first builds by DOING ----
	var tut: Node = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("tutorial_overlay.gd"):
			tut = n
	check("the tutorial card exists", tut != null)
	if tut != null:
		GameState.tutorial_step = -1
		tut._process(0.0)
		check("the card is hidden when no tutorial is running", not tut._card.visible)
		GameState.tutorial_step = 0
		tut._menu = null            # force it to re-find the ledger (closed)
		tut._process(0.0)
		check("step 1 shows the card, naming the WALL", tut._card.visible
			and tut._title.text.contains("WALL"))
		check("...and prompts the FIRST action: open the ledger",
			tut._action.text.contains("[B]"))
		# open the Builder's Ledger -> the card advances to the place sub-step
		var menu: Node = null
		for n in get_tree().current_scene.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("build_menu.gd"):
				menu = n
		if menu != null:
			menu.panel.visible = true
			tut._menu = menu
			tut._process(0.0)
			check("with the ledger open, it prompts to pick + place on GREEN",
				tut._action.text.contains("GREEN"))
			menu.panel.visible = false
		GameState.tutorial_step = -1
		tut._process(0.0)
		check("the card falls away when the tutorial finishes", not tut._card.visible)

	# clear the auto-started prologue box so the group is empty for a clean test
	for b in get_tree().get_nodes_in_group("dialogue_box"):
		if is_instance_valid(b): b.queue_free()
	await get_tree().process_frame
	if get_tree().paused: get_tree().paused = false

	# ---- a cutscene hides the HUD chrome, and restores it when it ends ----
	# The member CONTAINING the NotificationStack keeps the layer itself (and
	# the stack) visible and hides its other children instead -- toasts issued
	# alongside a beat must be seen (audit fix). Pick a probe accordingly:
	# a stack-free member is hidden whole; the stack's own layer is probed
	# through one of its non-stack children.
	var hud: Node = null
	var probe: Node = null            # the thing that must go invisible
	for member in get_tree().get_nodes_in_group("cutscene_hides"):
		var st = member.get_node_or_null("NotificationStack")
		if st == null:
			hud = member
			probe = member
			break
	if hud == null:
		for member in get_tree().get_nodes_in_group("cutscene_hides"):
			var st2 = member.get_node_or_null("NotificationStack")
			if st2 != null:
				hud = member
				for c in member.get_children():
					if c != st2 and ("visible" in c):
						probe = c
						break
				break
	check("the HUD is in the cutscene-hide group", hud != null and probe != null)
	if hud != null and probe != null:
		probe.visible = true
		DialogueBox.play(self, [{"speaker": "Test", "text": "a scripted beat"}], Callable())
		await get_tree().process_frame
		check("the HUD is hidden while a cutscene plays", not probe.visible)
		# ...but the toast channel is NOT: a toast fired mid-beat must be seen
		var main_hud: Node = null
		for member in get_tree().get_nodes_in_group("cutscene_hides"):
			if member.get_node_or_null("NotificationStack") != null:
				main_hud = member
				break
		if main_hud != null:
			check("the toast layer stays visible through the beat",
				main_hud.visible and main_hud.get_node("NotificationStack").visible)
		var box: Node = get_tree().get_first_node_in_group("dialogue_box")
		check("a dialogue box is on screen", box != null)
		if box != null:
			box.finish()
			await get_tree().process_frame
		check("the HUD comes back when the cutscene ends", probe.visible)
		if get_tree().paused: get_tree().paused = false

	# ---- a chained beat keeps the HUD hidden with no flicker ----
	if hud != null and probe != null:
		probe.visible = true
		DialogueBox.play(self, [{"speaker": "A", "text": "one"}],
			func(): DialogueBox.play(self, [{"speaker": "B", "text": "two"}], Callable()))
		await get_tree().process_frame
		var first: Node = get_tree().get_first_node_in_group("dialogue_box")
		if first != null:
			first.finish()   # opens the second box in its callback
		check("the HUD stays hidden across a chained line", not probe.visible)
		# drain the chained-in second box (skip the first, already finishing)
		for b in get_tree().get_nodes_in_group("dialogue_box"):
			if is_instance_valid(b) and not b.is_queued_for_deletion(): b.finish()
		await get_tree().process_frame
		check("...and restores after the last line", probe.visible)
		if get_tree().paused: get_tree().paused = false

	# ---- finish() is teardown-safe (0xC0000005 fix 2026-07-29) ----
	# Tests drain boxes by calling finish() off the group every frame, which can
	# double-fire on the same box, or land after the box's scene died mid-reload.
	# Both used to dispatch the callback anyway -- the second is a native crash.
	var fired := [0]                  # array: a lambda captures locals BY VALUE
	DialogueBox.play(self, [{"speaker": "Test", "text": "x"}], func(): fired[0] += 1)
	await get_tree().process_frame
	var bx: Node = get_tree().get_first_node_in_group("dialogue_box")
	check("teardown probe box exists", bx != null)
	if bx != null:
		bx.finish()
		bx.finish()                   # the race path: a second call must be a no-op
		check("finish() is idempotent -- callback fired exactly once", fired[0] == 1,
			str(fired[0]))
		await get_tree().process_frame
	if get_tree().paused: get_tree().paused = false
	var fired2 := [0]
	DialogueBox.play(self, [{"speaker": "Test", "text": "x"}], func(): fired2[0] += 1)
	await get_tree().process_frame
	bx = get_tree().get_first_node_in_group("dialogue_box")
	check("dead-scene probe box exists", bx != null)
	if bx != null:
		var ghost := Node.new()       # stands in for a current_scene freed mid-swap
		bx._host_id = ghost.get_instance_id()
		ghost.free()
		bx.finish()
		check("a dead-scene finish() DROPS its callback (no dispatch into freed nodes)",
			fired2[0] == 0, str(fired2[0]))
		await get_tree().process_frame
	if get_tree().paused: get_tree().paused = false

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
