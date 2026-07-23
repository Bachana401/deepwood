extends Node
# THE UPGRADABLE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
# upgradable... in the beginning it's gotta be weak"). Proves a wall tier is
# WEAK at the start and grows on every axis when raised: more HP, real defensive
# worth, trap damage, and more posts for defenders -- and that raising it costs
# gold + materials, refreshes the live wall, and that a tier caps how many
# adventurers can stand on it.

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

	# walls START REMOVED now (buildable from the B menu, dev 2026-07-22) -- raise
	# one so the live rampart's HP can be checked against the tier below.
	if get_tree().get_first_node_in_group("village_wall") == null:
		var w = preload("res://wall.tscn").instantiate()
		w.flank = "west"
		w.position = Vector2(4700.0, -39.0)
		get_tree().current_scene.add_child(w)
		await get_tree().process_frame

	# ---- TIER 1 IS WEAK ----
	GameState.wall_level = 1
	check("the wall starts weak — tier 1 is 350 HP", GameState.wall_max_health() == 350,
		str(GameState.wall_max_health()))
	check("tier 1 has no wall-worth and no traps yet",
		GameState.wall_defense_bonus() == 0.0 and GameState.wall_trap_dps() == 0.0)
	check("tier 1 holds only 2 posts", GameState.wall_station_capacity() == 2,
		str(GameState.wall_station_capacity()))

	# ---- RAISE IT 1 -> 2 (costs gold + stone + iron) ----
	p.inventory.add_item("coin_gold", 200)
	p.inventory.add_item("stone", 30)
	p.inventory.add_item("iron_shard", 6)
	# measure what the upgrade SPENDS (deltas) -- the player may already hold some
	# stone from the founder's cache, so absolute counts aren't reliable
	var g0: int = p.inventory.get_count("coin_gold")
	var stone0: int = p.inventory.get_count("stone")
	var iron0: int = p.inventory.get_count("iron_shard")
	check("with the materials in hand, tier 2 is affordable", GameState.can_afford_wall_upgrade(p))
	check("raising the rampart to tier 2 succeeds", GameState.try_upgrade_wall(p))
	check("the wall is now tier 2", GameState.wall_level == 2)
	check("tier 2 is a tougher 650 HP", GameState.wall_max_health() == 650,
		str(GameState.wall_max_health()))
	check("tier 2 adds worth (1.5), traps (8 dps) and posts (4)",
		GameState.wall_defense_bonus() == 1.5 and GameState.wall_trap_dps() == 8.0
		and GameState.wall_station_capacity() == 4)
	check("the upgrade spent the gold", g0 - p.inventory.get_count("coin_gold") == 120,
		"gold spent %d" % (g0 - p.inventory.get_count("coin_gold")))
	check("the upgrade spent the stone + iron",
		stone0 - p.inventory.get_count("stone") == 20 and iron0 - p.inventory.get_count("iron_shard") == 4,
		"stone spent %d iron spent %d" % [stone0 - p.inventory.get_count("stone"), iron0 - p.inventory.get_count("iron_shard")])

	# ---- the LIVE wall in the scene followed the tier ----
	var wall = get_tree().get_first_node_in_group("village_wall")
	check("the standing wall's HP jumped with the tier",
		wall != null and wall.max_health == GameState.wall_max_health(),
		"wall hp %s" % (str(wall.max_health) if wall else "no wall"))

	# ---- can't buy tier 3 on the change left (needs 320 gold, has 80) ----
	check("tier 3 is NOT affordable on pocket change", not GameState.can_afford_wall_upgrade(p))
	check("a failed upgrade leaves the tier untouched",
		not GameState.try_upgrade_wall(p) and GameState.wall_level == 2)

	# ---- STATION CAPACITY: a tier caps how many can man the wall ----
	GameState.ensure_adventurers()
	var ids: Array = GameState.adventurers.keys()
	for id in ids:                     # clear the wall so the count is deterministic
		GameState.adventurers[id]["station"] = "city"
	var picked: Array = []
	for id in ids:
		GameState.adventurers[id]["rescued"] = true
		GameState.adventurers[id]["dead"] = false
		picked.append(id)
		if picked.size() >= 3: break
	check("three test defenders are ready", picked.size() == 3)
	GameState.wall_level = 1            # cap 2
	var ok1: bool = GameState.set_adventurer_station(picked[0], "wall")
	var ok2: bool = GameState.set_adventurer_station(picked[1], "wall")
	var ok3: bool = GameState.set_adventurer_station(picked[2], "wall")
	check("a tier-1 wall holds exactly two, turns the third away",
		ok1 and ok2 and not ok3, "%s/%s/%s" % [ok1, ok2, ok3])
	check("the turned-away one stayed off the wall",
		GameState.adventurers[picked[2]]["station"] != "wall")
	GameState.wall_level = 2            # cap 4 -- now the third fits
	var ok3b: bool = GameState.set_adventurer_station(picked[2], "wall")
	check("after the wall is raised, the third can finally post",
		ok3b and GameState.wall_stationed_count() >= 3, str(GameState.wall_stationed_count()))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
