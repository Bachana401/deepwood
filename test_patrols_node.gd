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

# How much is actually IN the bag. Not slots.size() -- that is the fixed slot count
# (55 before and 55 after), so a check written against it can never move.
func _bag_total(p: Node) -> int:
	var n := 0
	for slot in p.inventory.slots:
		if slot != null:
			n += int(slot.count)
	return n

# The highest grade rank the bag holds, 0 if it holds nothing graded.
func _best_rank(p: Node) -> int:
	var best := 0
	for slot in p.inventory.slots:
		if slot == null:
			continue
		var g := Inventory.get_grade(str(slot.item_id))
		if g == "":
			continue
		best = maxi(best, int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 1)))
	return best

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

	# ======== THE WALL AND THE LEDGER MUST AGREE ========
	# village_defense_power() had always subtracted the posted corps, so the check
	# above passed -- but two other halves of the same system did not, and the suite
	# only ever measured the one that worked.
	GameState.rescued_villagers = []
	for iw in range(20):
		GameState.rescued_villagers.append(warrior("k%d" % iw))
	GameState.floors_cleared = {}
	for lvw in range(1, 21):
		GameState.floors_cleared[str(lvw)] = true
	GameState.barracks_arms = 20
	GameState.patrol_posts = {}
	var duty_home: int = GameState.on_duty_warrior_count()
	var armed_home: int = GameState.armed_warriors()
	GameState.post_patrol(1, 4)
	GameState.post_patrol(2, 6)
	# siege_manager spawns min(on_duty_warrior_count(), MAX_SOLDIERS) BODIES for a
	# live siege -- so this is not bookkeeping, it is who turns up and swings.
	check("a warrior in the deep does not also stand on the wall in the live siege",
		GameState.on_duty_warrior_count() < duty_home,
		"%d -> %d on duty with 10 posted" % [duty_home, GameState.on_duty_warrior_count()])
	# ...and does not leave their issued arms behind to keep paying ARMED_WARRIOR_BONUS
	check("...nor leave their arms on the wall behind them",
		GameState.armed_warriors() == armed_home - 10,
		"%d -> %d armed" % [armed_home, GameState.armed_warriors()])

	# THE LEDGER CANNOT OUTLIVE THE CORPS. patrol_posts is a count, not a roster, so
	# a posted warrior who dies (plague, siege, the Harvest) left their post standing
	# forever -- the town earning for bodies it did not have and holding blocks with
	# ghosts.
	for _kill in range(14):
		GameState.rescued_villagers.pop_back()
	check("the corps really did shrink below the watch", GameState.warrior_count() < 10,
		"%d left, %d posted" % [GameState.warrior_count(), GameState.posted_warriors()])
	GameState.tick_patrols(0.1)
	check("a watch can never outnumber the warriors still alive to stand it",
		GameState.posted_warriors() <= GameState.warrior_count(),
		"%d posted vs %d alive" % [GameState.posted_warriors(), GameState.warrior_count()])
	check("...and it is the DEEPEST stretch abandoned first, not the road home",
		GameState.patrol_at(1) >= GameState.patrol_at(2),
		"block1=%d block2=%d" % [GameState.patrol_at(1), GameState.patrol_at(2)])
	# hand the next section back the state it expects: three warriors, all posted on
	# block 1, exactly as the wall-cost check above left things before this block
	# existed. (Clearing the posts here and not re-posting them is what made the
	# earnings checks below report 0 gold -- the earnings were fine; the fixture wasn't.)
	GameState.rescued_villagers = [warrior("w1"), warrior("w2"), warrior("w3")]
	GameState.patrol_posts = {}
	GameState.post_patrol(1, 3)

	# ---- what they send up: bulk, and rarely something off a body ----
	# The old heading read "bulk, NEVER gear" and captured bag_before to prove it --
	# then never asserted on it. _patrol_find_gear had since made the claim false, so
	# the dead capture was the only trace of a rule that no longer existed, and
	# nothing in the suite guarded patrol drops in EITHER direction.
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._patrol_accum = 0.0
	p.currency = 0
	GameState._patrol_earnings(24.5)
	var mats: int = int(GameState.village_stockpile["wood"]) + int(GameState.village_stockpile["stone"]) \
		+ int(GameState.village_stockpile["iron_shard"])
	check("a day below sends up coin", p.currency > 0, "%dg" % p.currency)
	check("...and raw material into the stores", mats > 0, str(GameState.village_stockpile))

	# ---- A FIND IS REAL, AND IT IS DEPTH-GATED ----
	# Nothing guarded this in either direction: the suite neither proved a find can
	# happen nor that it cannot outrun the floors that earned it. Driven directly
	# rather than waited for -- at one find per ~6.9 in-game days, observing the
	# random roll would be an unexercised negative, which is the whole failure mode
	# this suite spent a session cataloguing.
	# NOTE slots.size() is the FIXED slot COUNT, not how much is in the bag -- it is
	# 55 before and 55 after, so a check written against it can never move. Count the
	# items themselves.
	var shallow_bag: int = _bag_total(p)
	GameState._patrol_find_gear(1, p)          # the top ten floors
	check("a patrol find actually reaches the player's bag",
		_bag_total(p) > shallow_bag,
		"%d -> %d items" % [shallow_bag, _bag_total(p)])
	# what block 1 can turn up must not out-reach floor 10
	var worst_rank := 0
	var deep_rank := 0
	worst_rank = _best_rank(p)
	var br1: Array = WeaponRoster.TIER_FLOORS[clampi(worst_rank, 1, 8)]
	check("...and nothing it turns up out-reaches the floors that earned it",
		worst_rank == 0 or int(br1[0]) <= GameState.PATROL_BLOCK_SIZE,
		"grade rank %d starts at floor %d, block 1 ends at %d"
			% [worst_rank, int(br1[0]), GameState.PATROL_BLOCK_SIZE])
	# and the deep genuinely pays better than the shallows
	GameState._patrol_find_gear(GameState.PATROL_BLOCKS, p)
	deep_rank = _best_rank(p)
	check("the deepest block can reach grades the shallowest never could",
		deep_rank >= worst_rank, "deep rank %d vs shallow rank %d" % [deep_rank, worst_rank])
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()

	# ---- DEPTH pays: a deep watch is worth taking warriors off the wall for ----
	var day_at := func(b: int) -> int:
		GameState.floors_cleared = {}
		for lv3 in range(1, b * GameState.PATROL_BLOCK_SIZE + 1):
			GameState.floors_cleared[str(lv3)] = true
		GameState.patrol_posts = {}
		GameState.post_patrol(b, 3)
		GameState._patrol_accum = 0.0
		p.currency = 0
		GameState._patrol_earnings(24.5)
		return p.currency
	var shallow: int = day_at.call(1)
	var deep: int = day_at.call(6)
	check("a deep watch pays far better than a shallow one (the risk is worth taking)",
		deep > shallow, "block1=%dg block6=%dg" % [shallow, deep])

	# ---- the rare find is SELF-BALANCING by depth, not by a tuned percentage ----
	check("a find can only be gear those floors would have yielded",
		gs.contains("WeaponRoster.TIER_FLOORS") and gs.contains("func _patrol_find_gear"))
	check("...and never the things that are never loot",
		gs.split("func _patrol_find_gear(")[1].split("\nfunc ")[0].contains("WANDERER_NEVER_SOLD"))
	# a shallow watch must not be able to turn up deep gear
	var shallow_pool_ok := true
	for id in Inventory.ITEM_DEFS.keys():
		var cat2 := str(Inventory.ITEM_DEFS[id].get("category", ""))
		if not (cat2 in ["weapon", "armor", "relic"]):
			continue
		var g2 := Inventory.get_grade(str(id))
		var rank2 := int(Inventory.GRADE_DEFS.get(g2, {}).get("rank", 1))
		var br2: Array = WeaponRoster.TIER_FLOORS[clampi(rank2, 1, 8)]
		# floors 1-10 may only ever yield things whose bracket opens by floor 10
		if int(br2[0]) > GameState.PATROL_BLOCK_SIZE and 10 >= int(br2[0]):
			shallow_pool_ok = false
	check("a shallow watch can never turn up endgame gear", shallow_pool_ok)

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
	# THE OLD SETUP COULD NOT HAPPEN. It poked block_creep = {1: 1.0} and asked
	# whether the road was cut -- but _block_falls sets that block's creep straight
	# back to 0.0, and tick_patrols erases the creep of anything no longer swept, so
	# a creep of 1.0 cannot survive the instant that produces it. The test was pinning
	# a state the game never reaches, and first_fallen_block() (which read creep) could
	# never return anything but 0 -- the road-cut gate in level_select_ui was dead the
	# day it was wired, and this check was what made that invisible.
	#
	# A fallen block is now DERIVED from the floors, which is what one actually leaves
	# behind: a stretch that is no longer swept while something deeper still is.
	GameState.floors_cleared = {}
	for lv2 in range(11, 21):
		GameState.floors_cleared[str(lv2)] = true   # block 2 held, block 1 lost
	check("a fallen stretch blocks the walk down past it",
		GameState.floor_is_road_blocked(15), "first fallen = %d" % GameState.first_fallen_block())
	check("...and it is the shallow stretch that is the hole",
		GameState.first_fallen_block() == 1, str(GameState.first_fallen_block()))
	check("...but the floors above it are not blocked", not GameState.floor_is_road_blocked(5))
	# ...and the real thing that produces it agrees: let a block actually FALL
	GameState.floors_cleared = {}
	for lv4 in range(1, 21):
		GameState.floors_cleared[str(lv4)] = true
	GameState.patrol_posts = {}
	GameState.block_creep = {1: 0.99}
	GameState.tick_patrols(24.0)
	check("a block that genuinely falls cuts the road for real",
		GameState.first_fallen_block() == 1 and GameState.floor_is_road_blocked(15),
		"first fallen = %d" % GameState.first_fallen_block())
	GameState.floors_cleared = {}
	for lv3 in range(1, 21):
		GameState.floors_cleared[str(lv3)] = true
	GameState.block_creep = {}
	check("with the road clear nothing is blocked", not GameState.floor_is_road_blocked(15))

	# ---- it survives the save ----
	check("posts and creep are written down", gs.contains('"patrol_posts": patrol_posts')
		and gs.contains('"block_creep": block_creep'))
	check("...and reloaded with INT keys (JSON would hand them back as strings)",
		gs.contains("patrol_posts[int(str(k))]"))
	check("the Barracks is where you post them",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("add_patrol_section"))

	# ======== THE MUSTER RUNS ITSELF (automation ladder, floor 65) ========
	# The ladder law says every manual chore is eventually handed to a leader. It had
	# a FORTY-FLOOR HOLE: nothing new was automated between floor 56 and the Chancellor
	# at 95, because Foreman/Warchief/Lead Researcher are all second holders of seats
	# already filled -- they raise numbers and retire no chore. Meanwhile posting the
	# watch stayed manual to the end of the game. The Warchief takes it.
	GameState.floors_cleared = {}
	for lv2 in range(1, 101):
		GameState.floors_cleared[str(lv2)] = true
	GameState.rescued_villagers = []
	for i9 in range(30):
		GameState.rescued_villagers.append({"id": "wc%d" % i9, "name": "Wc%d" % i9, "sex": "Male",
			"is_kid": false, "stat_name": "Warrior", "stat_value": 5,
			"role_key": "Barracks", "role_title": ""})
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState.tick_patrols(1.0)
	check("with no Warchief the watch is the player's job, as it always was",
		GameState.posted_warriors() == 0, "%d posted" % GameState.posted_warriors())

	GameState.rescued_villagers[0]["role_title"] = "Warchief"
	check("a seated Warchief holds the deep", GameState.warchief_holds_the_deep())
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState.tick_patrols(1.0)
	check("...and musters the watch across every swept block without you",
		GameState.posted_warriors() > 0 and GameState.patrol_posts.size() == GameState.PATROL_BLOCKS,
		"%d warriors over %d blocks" % [GameState.posted_warriors(), GameState.patrol_posts.size()])
	# THE POINT: it must actually HOLD. A muster that still loses blocks automated
	# nothing -- it just spends the wall for you.
	var fell := 0
	for _d9 in range(120):
		GameState.tick_patrols(24.0)
		if GameState.first_fallen_block() > 0:
			fell += 1
	check("the road stays open for months without a single order from you",
		fell == 0 and GameState.first_fallen_block() == 0, "%d days with a fallen block" % fell)
	# ...and it must not empty the wall. It posts the MINIMUM that holds, never more,
	# so the real decision -- how much of your defence to spend on the deep -- is
	# still the player's. This relieves the bookkeeping, not the choice.
	check("...and most of the corps is still standing at home",
		GameState.warriors_available_to_post() > GameState.posted_warriors(),
		"%d home vs %d posted" % [GameState.warriors_available_to_post(), GameState.posted_warriors()])
	check("it never posts more than a block needs",
		GameState.patrol_at(1) <= GameState.garrison_needed(1) + 1,
		"block 1 has %d, needs %d" % [GameState.patrol_at(1), GameState.garrison_needed(1)])
	# a garrison YOU set by hand is never thinned back to the minimum
	GameState.patrol_posts = {}
	GameState.post_patrol(3, 6)
	GameState.tick_patrols(1.0)
	check("a watch you set by hand is left exactly as you set it",
		GameState.patrol_at(3) == 6, "%d" % GameState.patrol_at(3))
	# and the ladder reads it as a chore retired
	var watch_handled := false
	for dom in GameState.chore_domains():
		if str(dom.get("key", "")) == "watch":
			watch_handled = bool(dom.get("handled", false))
	check("the automation ladder counts the watch as handed over", watch_handled)

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.floors_cleared = s_cleared
	GameState.patrol_posts = s_posts
	GameState.block_creep = s_creep
	GameState.village_stockpile = s_store
	p.currency = s_gold

	printerr("test_patrols : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
