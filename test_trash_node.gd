extends Node
# THE INVENTORY BIN (dev 2026-07-23: "drop items / delete in bin"). Drag a stack
# onto the 🗑 in the inventory header and let go -- it's discarded. This drives that
# exact path: start_drag on a stack, then perform_drop over the trash zone.

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
	for i in range(10):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame

	var ui = get_tree().get_first_node_in_group("inventory_ui")
	check("the inventory UI exists", ui != null)
	if ui == null: printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return
	ui.visible = true
	ui.refresh()
	await get_tree().process_frame
	check("the inventory has a 🗑 bin", "trash_zone" in ui and ui.trash_zone != null)

	# a junk stack to throw away
	p.inventory.add_item("herb", 5)
	var idx := -1
	for i in range(p.inventory.slots.size()):
		var s = p.inventory.slots[i]
		if s != null and str(s.item_id) == "herb":
			idx = i; break
	check("a herb stack sits in a slot", idx >= 0)
	var before: int = p.inventory.get_count("herb")

	# pick it up and drop it on the bin
	DragState.start_drag(p.inventory, idx)
	var center: Vector2 = ui.trash_zone.get_global_rect().get_center()
	check("the bin reports the cursor is over it", ui.is_over_trash(center))
	DragState.perform_drop(center)
	await get_tree().process_frame
	check("dropping a stack on the bin discards it",
		p.inventory.get_count("herb") < before,
		"herb %d -> %d" % [before, p.inventory.get_count("herb")])
	# and dropping over EMPTY space (not the bin) keeps the item (no accidental loss)
	p.inventory.add_item("wood", 3)
	var widx := -1
	for i in range(p.inventory.slots.size()):
		var s2 = p.inventory.slots[i]
		if s2 != null and str(s2.item_id) == "wood":
			widx = i; break
	var wbefore: int = p.inventory.get_count("wood")
	DragState.start_drag(p.inventory, widx)
	DragState.perform_drop(Vector2(-9999, -9999))   # nowhere -> returns to source
	await get_tree().process_frame
	check("a drop into empty space does NOT delete the item",
		p.inventory.get_count("wood") == wbefore)
	# and the bin REFUSES currency -- a fat-fingered drag can't nuke your gold
	p.inventory.add_item("coin_gold", 50)
	var gidx := -1
	for i in range(p.inventory.slots.size()):
		var s3 = p.inventory.slots[i]
		if s3 != null and str(s3.item_id) == "coin_gold":
			gidx = i; break
	var gbefore: int = p.inventory.get_count("coin_gold")
	DragState.start_drag(p.inventory, gidx)
	DragState.perform_drop(ui.trash_zone.get_global_rect().get_center())
	await get_tree().process_frame
	check("the bin refuses to discard COIN (no accidental gold loss)",
		p.inventory.get_count("coin_gold") == gbefore, "gold %d -> %d" % [gbefore, p.inventory.get_count("coin_gold")])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
