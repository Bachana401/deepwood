extends Node
# THE PATROLS (dev design 2026-07-30) -- the town's first reach OUTWARD.
# Warriors posted into ten-floor stretches you have already swept: they hold the
# dark down, send up coin and material, and are NOT on the wall while they do it.
#
# Pins the whole contract: a block must be personally cleared before it can be
# held; a posted warrior really does leave the wall; patrols pay BULK ONLY (never
# gear); an unheld stretch creeps and eventually FALLS, reverting those floors to
# wild and cutting the road down; and posting can never conjure more warriors
# than the town has.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func warrior(id: String) -> Dictionary:
	return {"id": id, "name": id, "sex": "Male", "is_kid": false, "stat_name": "Warrior",
		"stat_value": 4, "role_key": "Barracks", "role_title": "Warrior"}

func _ready() -> void:
	var p: Node = null
	for i in range(600):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false

	var s_roster: Array = GameState.rescued_villagers.duplicate(true)
	var s_cleared: Dictionary = GameState.floors_cleared.duplicate(true)
	var s_posts: Dictionary = GameState.patrol_posts.duplicate(true)
	var s_creep: Dictionary = GameState.block_creep.duplicate(true)
	var s_store: Dictionary = GameState.village_stockpile.duplicate(true)
	var s_gold: int = p.currency

	GameState.rescued_villagers = [warrior("w1"), warrior("w2"), warrior("w3")]
	GameState.patrol_posts = {}
	GameState.block_creep = {}

	# ---- a stretch must be YOURS before it can be held ----
	GameState.floors_cleared = {}
	check("an unswept stretch cannot be patrolled", not GameState.block_is_cleared(1))
	check("...and posting there is refused", not GameState.post_patrol(1, 2)
		and GameState.patrol_at(1) == 0)
	for lv in range(1, 11):
		GameState.floors_cleared[str(lv)] = true
	check("sweeping every floor of a stretch opens it", GameState.block_is_cleared(1))
	check("a stretch you only half-swept stays shut", not GameState.block_is_cleared(2))

	# ---- posting is bounded by the warriors you actually have ----
	check("posting works once it is yours", GameState.post_patrol(1, 2)
		and GameState.patrol_at(1) == 2)
	GameState.post_patrol(1, 99)
	check("you cannot post more warriors than the town has",
		GameState.patrol_at(1) <= GameState.warrior_count(), str(GameState.patrol_at(1)))

	# ---- THE COST: a posted warrior is off the wall ----
	GameState.patrol_posts = {}
	var wall_full: float = GameState.village_defense_power()
	GameState.post_patrol(1, 3)
	var wall_thin: float = GameState.village_defense_power()
	check("every warrior sent below is a warrior off the wall",
		wall_thin < wall_full, "%.2f -> %.2f" % [wall_full, wall_thin])

	# ---- what they send up: bulk, never gear ----
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._patrol_accum = 0.0
	p.currency = 0
	var bag_before: int = p.inventory.slots.size()
	GameState._patrol_earnings(24.5)
	var mats: int = int(GameState.village_stockpile["wood"]) + int(GameState.village_stockpile["stone"]) \
		+ int(GameState.village_stockpile["iron_shard"])
	check("a day below sends up coin", p.currency > 0, "%dg" % p.currency)
	check("...and raw material into the stores", mats > 0, str(GameState.village_stockpile))
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("patrols pay BULK ONLY — the earnings never touch the item tables",
		not gs.split("func _patrol_earnings(")[1].split("func ")[0].contains("add_item"))

	# ---- an unheld stretch creeps, and eventually falls ----
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState.tick_patrols(24.0)
	check("an unheld stretch starts souring", GameState.block_creep_of(1) > 0.0,
		"%.3f" % GameState.block_creep_of(1))
	var held_before: float = GameState.block_creep_of(1)
	GameState.post_patrol(1, 3)
	GameState.tick_patrols(24.0)
	check("...and posting warriors pushes it back down",
		GameState.block_creep_of(1) < held_before,
		"%.3f -> %.3f" % [held_before, GameState.block_creep_of(1)])

	# let it fall outright
	GameState.patrol_posts = {}
	GameState.block_creep = {1: 0.99}
	GameState.tick_patrols(24.0)
	check("a stretch left too long FALLS — its floors are wild again",
		not GameState.floor_is_cleared(5), "floor 5 cleared=%s" % str(GameState.floor_is_cleared(5)))
	check("...and nobody is left posted there", GameState.patrol_at(1) == 0)

	# ---- a fallen stretch cuts the road below it ----
	GameState.floors_cleared = {}
	for lv2 in range(1, 21):
		GameState.floors_cleared[str(lv2)] = true
	GameState.block_creep = {1: 1.0}
	check("a fallen stretch blocks the walk down past it",
		GameState.floor_is_road_blocked(15), "block of 15 = %d" % GameState.block_of_floor(15))
	check("...but not the floors above it", not GameState.floor_is_road_blocked(5))
	GameState.block_creep = {}
	check("with the road clear nothing is blocked", not GameState.floor_is_road_blocked(15))

	# ---- it survives the save ----
	check("posts and creep are written down", gs.contains('"patrol_posts": patrol_posts')
		and gs.contains('"block_creep": block_creep'))
	check("...and reloaded with INT keys (JSON would hand them back as strings)",
		gs.contains("patrol_posts[int(str(k))]"))
	check("the Barracks is where you post them",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("add_patrol_section"))

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.floors_cleared = s_cleared
	GameState.patrol_posts = s_posts
	GameState.block_creep = s_creep
	GameState.village_stockpile = s_store
	p.currency = s_gold

	printerr("test_patrols : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
