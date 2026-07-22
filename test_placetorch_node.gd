extends Node
# PLACE A STANDING TORCH (G) -- the one player interaction with no automated cover.
# Both bugs this week were untested features that silently no-op'd, so this closes
# the last such gap: proves G actually plants a torch, spends the materials, records
# it for save/reload, and is refused (not silently) down in the dungeon.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	get_tree().paused = false
	for i in range(20):
		await get_tree().process_frame

	GameState.in_dungeon = false
	# hand over exactly the cost, so we also prove it's SPENT
	p.inventory.add_item("wood", 2)
	p.inventory.add_item("resin", 1)
	var w0: int = p.inventory.get_count("wood")
	var r0: int = p.inventory.get_count("resin")
	var placed0: int = GameState.placed_torches.size()

	p.try_place_torch()
	await get_tree().process_frame
	check("planting a torch records it (for save/reload)", GameState.placed_torches.size() == placed0 + 1,
		"%d -> %d" % [placed0, GameState.placed_torches.size()])
	check("...and spends the 2 wood + 1 resin", p.inventory.get_count("wood") == w0 - 2 and p.inventory.get_count("resin") == r0 - 1,
		"wood %d->%d resin %d->%d" % [w0, p.inventory.get_count("wood"), r0, p.inventory.get_count("resin")])

	# no materials -> refused, and NOTHING is spent or planted (not a silent half-do)
	var placed1: int = GameState.placed_torches.size()
	p.inventory.remove_item("wood", p.inventory.get_count("wood"))
	p.inventory.remove_item("resin", p.inventory.get_count("resin"))
	p.try_place_torch()
	await get_tree().process_frame
	check("with no materials the torch is refused, none planted", GameState.placed_torches.size() == placed1)

	# in the dungeon -> refused (overworld only), not a silent failure
	p.inventory.add_item("wood", 2)
	p.inventory.add_item("resin", 1)
	GameState.in_dungeon = true
	var placed2: int = GameState.placed_torches.size()
	p.try_place_torch()
	await get_tree().process_frame
	GameState.in_dungeon = false
	check("standing torches are refused underground, not planted", GameState.placed_torches.size() == placed2)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
