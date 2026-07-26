extends Node
# TIERED PICKAXES (2026-07-26): the deep biomes gate mining on pick_tier
# (underground.gd BIOMES: Emberdeep=2, Blightcore=3). This proves the new
# Embersteel (tier 2) and Blightbreaker (tier 3) exist, wield at the right tier
# (the exact value player._tick_dig passes to mine_at), and that the gate lets
# the matching tier through while blocking a weaker one.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	# boot the tile underground directly (it builds the world + spawns a player)
	get_tree().change_scene_to_file.call_deferred("res://underground.tscn")
	var ug: Node = null
	var pl: Node = null
	for i in range(1400):
		await get_tree().process_frame
		var cs = get_tree().current_scene
		if cs != null and cs.has_method("mine_at"):
			ug = cs
			pl = get_tree().get_first_node_in_group("player")
			if pl != null:
				break
	if ug == null or pl == null:
		printerr("FAIL  underground/player did not boot"); get_tree().quit(1); return
	for i in range(20):
		await get_tree().process_frame

	# --- wield each pickaxe; active_def.pick_tier is what _tick_dig reads ---
	check("Miner's Pickaxe wields at tier 1",
		pl.wield_weapon("tool_pickaxe") and int(pl.active_def.get("pick_tier", 0)) == 1)
	check("Embersteel Pickaxe exists and wields at tier 2",
		pl.wield_weapon("tool_pickaxe_ember") and int(pl.active_def.get("pick_tier", 0)) == 2)
	check("Blightbreaker Pickaxe exists and wields at tier 3",
		pl.wield_weapon("tool_pickaxe_blight") and int(pl.active_def.get("pick_tier", 0)) == 3)

	# --- the gate: place a solid Emberdeep (biome 3, tier 2) tile next to the player ---
	var pcell: Vector2i = ug._map.local_to_map(ug._map.to_local(pl.global_position))
	var ecell: Vector2i = pcell + Vector2i(2, 0)
	ug._map.set_cell(ecell, 0, Vector2i(3, 0))          # biome 3 = Emberdeep, non-ore
	var epos: Vector2 = ug._map.to_global(ug._map.map_to_local(ecell))
	check("a tier-1 pickaxe is BLOCKED by Emberdeep (tier 2)",
		not ug.mine_at(epos, pl.global_position, 240.0, false, 1, pl))
	check("...and the blocked tile survives (nothing mined)",
		ug._map.get_cell_source_id(ecell) != -1)
	check("a tier-2 pickaxe CAN mine Emberdeep",
		ug.mine_at(epos, pl.global_position, 240.0, false, 2, pl))

	# --- Blightcore (biome 4, tier 3): tier 2 blocked, tier 3 through ---
	var bcell: Vector2i = pcell + Vector2i(3, 0)
	ug._map.set_cell(bcell, 0, Vector2i(4, 0))          # biome 4 = Blightcore, non-ore
	var bpos: Vector2 = ug._map.to_global(ug._map.map_to_local(bcell))
	check("a tier-2 pickaxe is BLOCKED by Blightcore (tier 3)",
		not ug.mine_at(bpos, pl.global_position, 240.0, false, 2, pl))
	check("a tier-3 pickaxe CAN mine Blightcore",
		ug.mine_at(bpos, pl.global_position, 240.0, false, 3, pl))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
