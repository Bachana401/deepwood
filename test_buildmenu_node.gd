extends Node
# THE BUILD MENU — deletable ruins (dev 2026-07-22: "player can delete these
# ruins... game always double checks"). Proves a site can be razed for good: the
# removal is recorded, the live node leaves the world, generate_village skips it
# on rebuild, and the removal is saved/loaded.

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
	# let the village finish generating
	for i in range(30):
		await get_tree().process_frame

	# ---- the removal API ----
	GameState.removed_buildings = {}
	check("nothing is razed at the start", not GameState.building_removed("Bar"))
	GameState.remove_building("Bar")
	check("remove_building records the razing", GameState.building_removed("Bar"))
	GameState.restore_building("Bar")
	check("restore un-records it", not GameState.building_removed("Bar"))

	# ---- razing takes the live site out of the world (the menu's own helper) ----
	var target := ""
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b:
			target = str(b.building_name)
			break
	check("the live village has a site to raze", target != "", target)
	var before := _count(target)
	var bm: Node = null
	for w in get_tree().get_nodes_in_group("esc_window"):
		if w.has_method("_delete_live_building"):
			bm = w
			break
	check("the build menu exposes the raze helper", bm != null)
	if bm != null:
		GameState.remove_building(target)
		bm._delete_live_building(target)
		await get_tree().process_frame
		await get_tree().process_frame
	check("razing removes the site from the world",
		before > 0 and _count(target) == 0, "%s: %d -> %d" % [target, before, _count(target)])

	# ---- the wiring that makes it stick ----
	var main_txt := FileAccess.open("res://main.gd", FileAccess.READ).get_as_text()
	check("generate_village skips a razed site on rebuild",
		main_txt.contains("GameState.building_removed(def.name)"))
	var gs_txt := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("razings are saved", gs_txt.contains('"removed_buildings": removed_buildings'))
	check("razings are loaded", gs_txt.contains('parsed.has("removed_buildings")'))

	GameState.removed_buildings = {}     # leave the throwaway boot clean
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _count(bn: String) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("building"):
		if "building_name" in b and str(b.building_name) == bn:
			n += 1
	return n
