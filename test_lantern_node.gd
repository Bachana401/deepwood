extends Node

# THE LANTERN NIGHT (festival event, 2026-07-28), headless. Joy is earned
# (morale-gated), grief always wins a shared dusk (mutual exclusion BOTH
# ways), the fair pitches and prices soften, dawn eases the town's carried
# grief exactly once, and a new game takes the lanterns down.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# a townsperson + the dev nudge give us a dialable morale
	GameState.opening_done = true
	GameState.despair_dead = false
	GameState.harvest_at_home = false
	GameState.live_siege_active = false
	GameState.live_caravan_active = false
	GameState.in_dungeon = false
	GameState.weeping_tonight = false
	GameState.lantern_tonight = false
	if GameState.rescued_villagers.is_empty():
		GameState.rescued_villagers.append({"name": "Festival Test", "id": "fest_t"})
	GameState.morale_admin_offset = 100
	GameState.hours_since_lantern = GameState.LANTERN_MIN_GAP_HOURS + 1.0

	# ---- the gates ----
	check("a thriving town may hang lanterns", GameState.lantern_eligible())
	GameState.morale_admin_offset = -100
	check("a struggling town hangs none (morale gate)", not GameState.lantern_eligible())
	GameState.morale_admin_offset = 100
	GameState.weeping_tonight = true
	check("grief blocks the festival", not GameState.lantern_eligible())
	GameState.weeping_tonight = false
	GameState.hours_since_lantern = GameState.LANTERN_MIN_GAP_HOURS - 1.0
	check("the festival keeps its distance (gap)", not GameState.lantern_eligible())
	GameState.hours_since_lantern = GameState.LANTERN_MIN_GAP_HOURS + 1.0
	# ...and the mirror: a festival night blocks the weeping
	GameState.deepest_level_reached = maxi(GameState.deepest_level_reached, GameState.WEEP_MIN_FLOOR)
	GameState.hours_since_weeping = GameState.WEEP_MIN_GAP_HOURS + 1.0
	GameState.lantern_tonight = true
	check("a lantern night blocks the weeping (both ways)", not GameState.weeping_eligible())
	GameState.lantern_tonight = false

	# ---- the dusk crossing starts it (dice looped to certainty) ----
	GameState.game_hours = 22.2      # time_of_day 20.2
	var started := false
	for i in range(200):
		GameState._lantern_last_tod = 19.9
		GameState.tick_lantern(0.0)
		if GameState.lantern_tonight:
			started = true
			break
	check("the dusk crossing hangs the lanterns (200 rolls)", started)
	check("...and the gap clock resets", GameState.hours_since_lantern == 0.0)

	# ---- the fair: a cart for the night, prices kind ----
	check("the fair pitches (a wanderer stands the night)", not GameState.wanderer.is_empty())
	if not GameState.wanderer.is_empty():
		check("...staying at least the whole night", float(GameState.wanderer.get("dwell", 0.0)) >= 14.0)
	var lit_price: int = GameState._wanderer_price("potion_health")
	GameState.lantern_tonight = false
	var dark_price: int = GameState._wanderer_price("potion_health")
	GameState.lantern_tonight = true
	check("lantern light makes prices kinder", lit_price < dark_price,
		"lit %d vs dark %d" % [lit_price, dark_price])

	# ---- dawn eases the carried grief, once ----
	GameState.morale_death_shock = 40.0
	GameState.game_hours = 7.1       # time_of_day 5.1
	GameState._lantern_last_tod = 4.9
	GameState.tick_lantern(0.0)
	check("first light takes the lanterns down", not GameState.lantern_tonight)
	check("...and old grief sits lighter (35% eased)",
		absf(GameState.morale_death_shock - 26.0) < 0.01,
		"shock now %.2f" % GameState.morale_death_shock)
	var shock_after: float = GameState.morale_death_shock
	GameState.end_lantern()
	check("the mend never double-fires", GameState.morale_death_shock == shock_after)

	# ---- a new game takes everything down ----
	GameState.reset_for_new_game()
	check("reset takes the lanterns down",
		not GameState.lantern_tonight and GameState.hours_since_lantern == 0.0
		and GameState.lanterns_seen == 0)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
