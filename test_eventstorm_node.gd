extends Node

# THE EVENT STORM (bug hunt 2026-07-28): an adversarial fuzz of the whole
# EVENT LAYER. 400 in-game hours through the REAL master clock, every event
# system live (sieges, caravans, the weeping, the lanterns, wanderers, the
# Harbormaster's daily), stepped in hostile sizes from 3 minutes to 9 hours,
# with random dungeon trips and random deaths thrown in -- and the
# cross-event invariants asserted after EVERY tick. The slice tests prove
# each event alone; this proves they never trample each other, whatever
# the clock does. Seeded, so a red here is reproducible, not weather.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# a REAL starting world (the wave-8 lesson: bare var defaults are a lie),
	# then aged to mid-game so every event's floor/gap gate is open
	GameState.reset_for_new_game()
	GameState.opening_done = true
	GameState.deepest_level_reached = 20
	GameState.highest_unlocked_level = 20
	GameState.building_stage["Fishing Dock"] = GameState.TOTAL_BUILD_STAGES
	GameState.removed_buildings.erase("Fishing Dock")
	if not GameState.rescued_villagers.is_empty():
		var f: Dictionary = GameState.rescued_villagers[0].duplicate(true)
		f["id"] = "storm_fisher"
		f["name"] = "Storm Fisher"
		f["role_key"] = "Fishing Dock"
		f["role_title"] = "Fisherman"
		GameState.rescued_villagers.append(f)
	GameState.village_food = 60.0
	var probe := StormProbe.new()
	probe.add_to_group("player")
	add_child(probe)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0xE057
	var steps := [0.05, 0.3, 1.0, 3.0, 9.0]
	var violations := []
	var t := 0.0
	while t < 400.0 and violations.size() < 8:
		var step: float = steps[rng.randi_range(0, steps.size() - 1)]
		t += step
		# hostile world-jitter: trips below, and losses that push the shock
		if rng.randf() < 0.06:
			GameState.in_dungeon = not GameState.in_dungeon
		if rng.randf() < 0.04 and GameState.rescued_villagers.size() > 3:
			GameState.register_villager_deaths(1)
		GameState.game_hours += step
		GameState.tick_village_clock()
		# --- the invariants, every single tick ---
		var tod: float = GameState.time_of_day()
		var live: int = int(GameState.weeping_tonight) + int(GameState.lantern_tonight) \
			+ int(GameState.live_siege_active) + int(GameState.live_caravan_active)
		if live > 1:
			violations.append("t=%.1f: two set-pieces live at once" % t)
		if GameState.weeping_tonight and tod >= 5.5 and tod < 19.5:
			violations.append("t=%.1f: weeping in broad daylight (tod %.1f)" % [t, tod])
		if GameState.lantern_tonight and tod >= 5.5 and tod < 19.5:
			violations.append("t=%.1f: lanterns burning at noon (tod %.1f)" % [t, tod])
		if GameState.morale_death_shock < 0.0:
			violations.append("t=%.1f: negative death shock" % t)
		if probe.currency < 0:
			violations.append("t=%.1f: the purse went negative" % t)
		if GameState.fishing_last_post_day > int(GameState.game_hours / 24.0):
			violations.append("t=%.1f: a daily posted from the future" % t)
		if is_nan(GameState.hours_until_next_siege) or is_nan(GameState.hours_until_caravan):
			violations.append("t=%.1f: a war clock went NaN" % t)
	GameState.in_dungeon = false

	check("400 stormed hours break no invariant", violations.is_empty(),
		"; ".join(violations.slice(0, 4)))
	check("the clock really ran", GameState.game_hours >= 399.0)
	printerr("STORM: sieges=%d caravans=%d weepings=%d lanterns=%d dailies_done=%d shock=%.1f gold=%d" % [
		GameState.sieges_seen, GameState.caravans_seen, GameState.weepings_seen,
		GameState.lanterns_seen, GameState.fishing_quests_done,
		GameState.morale_death_shock, probe.currency])
	# the storm must have actually STORMED -- a quiet world proves nothing
	check("the world actually fought back (sieges happened)", GameState.sieges_seen >= 3)

	GameState.reset_for_new_game()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# Just enough player: a bag, a purse, a position, and the shop-UI peek flags.
class StormProbe extends Node2D:
	var inventory = Inventory.new(12)
	var currency := 500
	var has_dash := false
	var has_double_jump := false