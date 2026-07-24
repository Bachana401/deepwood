extends Node
# DRAG-SPLIT STRANDING (dev 2026-07-23). A right-click split pulls items OUT of the
# source slot into DragState's "hand" (pick_one_more: slot.count -= 1). No close path
# (Tab, Esc, the ✕, a chest closing, a scene change) resolved a split still in hand, so
# closing mid-split STRANDED the held items -- gone from the source, never deposited,
# the icon stuck to the cursor, split_mode jammed true. DragState now self-heals when
# orphaned (no visible panel): the held split returns to its source. This locks it.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	# wait for the boot so DragState (autoload) is processing
	for i in range(120):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	# the opening cutscene PAUSES the tree, and DragState._process (pausable, like in
	# game) heals only while running -- so unpause for the test (in-game the player
	# closes the bag during normal, unpaused play). Clear any dialogue holding the pause.
	for r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); found = true
		get_tree().paused = false
		await get_tree().process_frame
		if not found and not get_tree().paused:
			break
	get_tree().paused = false

	var inv := Inventory.new(15)
	inv.add_item("wood", 10)
	check("setup: 10 wood in slot 0",
		inv.slots[0] != null and inv.slots[0].item_id == "wood" and inv.slots[0].count == 10)

	# a fake open panel so DragState sees a visible surface while we split
	var panel := Control.new()
	panel.visible = true
	add_child(panel)
	DragState.register_panel(panel)

	# right-click split: pull 3 into the hand (start does 1, then two more)
	DragState.start_or_continue_split(inv, 0)
	DragState.pick_one_more()
	DragState.pick_one_more()
	check("mid-split: 3 pulled into the hand, 7 left in the source",
		DragState.split_mode and DragState.split_count == 3 \
		and inv.slots[0] != null and inv.slots[0].count == 7,
		"held=%d src=%s" % [DragState.split_count, str(inv.slots[0])])

	# CLOSE the panel mid-split -- the frame the drag finds itself orphaned it must
	# return the hand to the source, not strand it.
	panel.visible = false
	for i in range(3):
		await get_tree().process_frame

	check("closing mid-split returns the held items to the source (no stranding)",
		inv.slots[0] != null and inv.slots[0].count == 10,
		"src=%s" % str(inv.slots[0]))
	check("split state is cleared after the auto-heal",
		not DragState.split_mode and DragState.split_count == 0)

	# a LEFT-drag never removed from the source, so an orphaned drag just clears
	panel.visible = true
	DragState.start_drag(inv, 0)
	check("mid-drag: source still holds all 10 (a left-drag doesn't remove yet)",
		DragState.active and inv.slots[0] != null and inv.slots[0].count == 10)
	panel.visible = false
	for i in range(3):
		await get_tree().process_frame
	check("closing mid-drag clears the drag and loses nothing",
		not DragState.active and inv.slots[0] != null and inv.slots[0].count == 10)

	printerr("test_dragsplit : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
