extends Node

# THE WEEPING HOUR (night event, 2026-07-28), headless. The gates hold one by
# one, the dice only roll at the dusk crossing, the war clocks stand still
# while the forest grieves, dawn pays tears (and the Locket exactly once),
# an interrupted night pays nothing, and a new game forgets all of it.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# ---- what the sorrow leaves is all real and graded ----
	var bad := []
	for id in ["tear_pale", "potion_tears", "relic_mourner"]:
		if Inventory.get_item_def(id).is_empty() or Inventory.get_grade(id) == "":
			bad.append(id)
	check("tear, draught and locket are real, graded items", bad.is_empty(), ", ".join(bad))
	check("the Teardraught is crafted from tears", Inventory.CRAFT_RECIPES.has("potion_tears")
		and int(Inventory.CRAFT_RECIPES["potion_tears"].get("tear_pale", 0)) > 0)

	var probe := WeepProbe.new()
	probe.add_to_group("player")
	add_child(probe)

	# ---- the gates, one by one ----
	GameState.opening_done = true
	GameState.despair_dead = false
	GameState.harvest_at_home = false
	GameState.live_siege_active = false
	GameState.live_caravan_active = false
	GameState.in_dungeon = false
	GameState.deepest_level_reached = maxi(GameState.deepest_level_reached, GameState.WEEP_MIN_FLOOR)
	GameState.hours_since_weeping = GameState.WEEP_MIN_GAP_HOURS + 1.0
	GameState.weeping_tonight = false
	check("a clear dark is eligible", GameState.weeping_eligible())
	GameState.live_siege_active = true
	check("a live siege blocks the night", not GameState.weeping_eligible())
	GameState.live_siege_active = false
	GameState.live_caravan_active = true
	check("a live caravan blocks it too", not GameState.weeping_eligible())
	GameState.live_caravan_active = false
	GameState.harvest_at_home = true
	check("the Harvest outranks every night", not GameState.weeping_eligible())
	GameState.harvest_at_home = false
	GameState.in_dungeon = true
	check("nobody home, nobody weeps", not GameState.weeping_eligible())
	GameState.in_dungeon = false
	var kept_depth: int = GameState.deepest_level_reached
	GameState.deepest_level_reached = GameState.WEEP_MIN_FLOOR - 1
	check("a shallow name is not yet grieved for", not GameState.weeping_eligible())
	GameState.deepest_level_reached = kept_depth
	GameState.hours_since_weeping = GameState.WEEP_MIN_GAP_HOURS - 1.0
	check("the forest cannot weep twice in four days", not GameState.weeping_eligible())
	GameState.hours_since_weeping = GameState.WEEP_MIN_GAP_HOURS + 1.0

	# ---- the dice roll only at the dusk crossing ----
	GameState.game_hours = 22.2         # time_of_day 20.2, just past full dark
	var started := false
	for i in range(200):                # P(all misses) = 0.78^200 ~ 0
		GameState._weep_last_tod = 19.9
		GameState.tick_weeping(0.0)
		if GameState.weeping_tonight:
			started = true
			break
	check("the dusk crossing starts the night (200 rolls)", started)
	check("...and the gap clock resets with it", GameState.hours_since_weeping == 0.0)
	check("...and the ledger counts it", GameState.weepings_seen >= 1)

	# ---- the war clocks stand still while the forest grieves ----
	GameState.hours_until_next_siege = 5.0
	GameState.tick_sieges(2.0)
	check("the siege clock holds through the night", GameState.hours_until_next_siege == 5.0)
	GameState.hours_until_caravan = 7.0
	GameState.tick_caravans(2.0)
	check("the caravan clock holds too", GameState.hours_until_caravan == 7.0)

	# ---- dawn pays: tears by the tally, and the Locket exactly once ----
	GameState.weeping_kills = 8
	GameState.weepings_survived = 0
	GameState.end_weeping(false)
	check("dawn ends the night", not GameState.weeping_tonight)
	check("dawn pays tears by the tally", probe.inventory.get_count("tear_pale") == 2 + 8 / 4)
	check("the first survived night leaves the Locket", probe.inventory.get_count("relic_mourner") == 1)
	# hiding all night earns tears at most -- never the Locket (kills gate)
	probe.inventory.remove_item("relic_mourner", 1)
	GameState.weeping_tonight = true
	GameState.weeping_kills = GameState.WEEP_LOCKET_KILLS - 1
	GameState.end_weeping(false)
	check("a hidden night never earns the Locket", probe.inventory.get_count("relic_mourner") == 0)
	# a Rewound-Hour bag already carrying it is never handed another,
	# however hard the night was fought
	probe.inventory.add_item("relic_mourner", 1)
	GameState.weeping_tonight = true
	GameState.weeping_kills = 20
	GameState.end_weeping(false)
	check("a bag already carrying the Locket is left alone", probe.inventory.get_count("relic_mourner") == 1)

	# ---- an interrupted night pays nothing ----
	var tears_before: int = probe.inventory.get_count("tear_pale")
	GameState.weeping_tonight = true
	GameState.weeping_kills = 20
	GameState.end_weeping(true)
	check("a broken night pays nothing", probe.inventory.get_count("tear_pale") == tears_before
		and not GameState.weeping_tonight)

	# ---- the dawn crossing itself ends a live night ----
	GameState.weeping_tonight = true
	GameState.weeping_kills = 0
	GameState.game_hours = 7.1          # time_of_day 5.1, first light
	GameState._weep_last_tod = 4.9
	GameState.tick_weeping(0.0)
	check("first light dries the forest's eyes", not GameState.weeping_tonight)
	# ...even when a catch-up tick JUMPS the dawn window whole (leave at
	# 4am, return at 2pm -- the perpetual-night bug, hunt 2026-07-28)
	GameState.weeping_tonight = true
	GameState.weeping_kills = 0
	GameState.game_hours = 16.0         # time_of_day 14.0, mid-afternoon
	GameState._weep_last_tod = 4.9
	GameState.tick_weeping(10.0)
	check("a jumped dawn still ends the night", not GameState.weeping_tonight)

	# ---- a new game forgets the whole grief ----
	GameState.reset_for_new_game()
	check("reset forgets the weeping ledger",
		not GameState.weeping_tonight and GameState.hours_since_weeping == 0.0
		and GameState.weepings_seen == 0 and GameState.weepings_survived == 0
		and GameState.weeping_kills == 0)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# Just enough player: a bag, a purse, a position, and the two flags the shop
# UI peeks at on any refresh it catches.
class WeepProbe extends Node2D:
	var inventory = Inventory.new(8)
	var currency := 0
	var has_dash := false
	var has_double_jump := false
