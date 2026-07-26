extends Node
# EVERY ITEM DRAWS A SYMBOL (2026-07-26): the inventory icon system (Inventory.paint_icon)
# paints a little procedural symbol per item; anything that falls through to the bare
# `_: target.color = col` branch is a flat coloured square = "no art". This paints EVERY
# item in the catalog and fails on any that renders no symbol (zero child nodes), so a
# newly-added item can never silently ship as a blank tile.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var flat: Array = []
	var total := 0
	for id in Inventory.ITEM_DEFS.keys():
		total += 1
		var rect := ColorRect.new()
		rect.size = Vector2(40, 40)
		add_child(rect)
		Inventory.paint_icon(rect, str(id))
		if rect.get_child_count() == 0:
			flat.append(str(id))
		rect.free()
	printerr("painted %d items" % total)
	check("every item draws a symbol (no flat-tile placeholders)", flat.is_empty(),
		"flat: %s" % str(flat))

	# the six materials this pass gave art -- assert each specifically
	for mid in ["slime", "iron_shard", "ember_crystal", "void_essence", "ancient_relic", "sorrowshard"]:
		var r := ColorRect.new()
		r.size = Vector2(40, 40)
		add_child(r)
		Inventory.paint_icon(r, mid)
		check("%s has a drawn icon" % mid, r.get_child_count() > 0, "%d children" % r.get_child_count())
		r.free()

	# and the tiered pickaxes get their own distinct icons (not the shared grey one)
	for pid in ["tool_pickaxe_ember", "tool_pickaxe_blight"]:
		var r := ColorRect.new()
		r.size = Vector2(40, 40)
		add_child(r)
		Inventory.paint_icon(r, pid)
		check("%s has a drawn icon" % pid, r.get_child_count() > 0, "%d children" % r.get_child_count())
		r.free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
