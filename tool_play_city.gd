extends Node
# PLAY THE CITY. Everything built on 2026-07-29 -- the population fixes, the 15
# building powers, the 4 leader powers -- only shows up in a town that has GROWN.
# A fresh game starts with an empty ruin, so seeing any of it means hours of play.
# This stages a real mid-game Deepwood and then GETS OUT OF THE WAY: no shots, no
# asserts, no quit. The game is left running for the dev to walk around in.
#   MONARCH_TEST="res://tool_play_city.gd" Godot.exe --path .     (windowed)
#
# Everything below is state the game itself would have produced; nothing here is
# a cheat that the real systems couldn't reach.

const POP := 46          # a peopled town, not a crowd that hides the buildings
# Floor 66 on purpose: the Warchief (The Muster) is held on floor 65, so a
# shallower staging silently hides one of the four leader powers. This is the
# shallowest depth at which ALL of them can actually be seen.
const DEPTH := 66

func say(t: String) -> void: printerr("CITY: " + t); OS.delay_msec(1)

func _ready() -> void:
	var p: Node = null
	for i in range(900):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: say("no player"); return

	# leave the opening cutscene behind
	for _r in range(20):
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish()
		get_tree().paused = false
		await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	GameState.game_hours = 9.0            # morning, so the town is lit and awake
	GameState.highest_unlocked_level = DEPTH
	GameState.deepest_level_reached = DEPTH
	GameState.wall_level = 3

	# --- the buildings, raised and GROWN PAST THE POWER THRESHOLD ---
	for bn in GameState.STARTING_BUILDINGS + ["Mine", "Shrine"]:
		GameState.building_stage[bn] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[bn] = GameState.BUILDING_MAX_HEALTH
		GameState.building_levels[bn] = GameState.BUILDING_POWER_LEVEL

	# --- the people: the named VIPs the deep gives up by floor 42, then townsfolk ---
	GameState.rescued_villagers = []
	for lvl in range(1, DEPTH + 1):
		var fig: Dictionary = VillagerQuests.figure_for_level(lvl)
		if not fig.is_empty():
			GameState.rescued_villagers.append({
				"id": str(fig.get("villager_id", "")), "name": str(fig.get("villager_name", "?")),
				"sex": str(fig.get("sex", "Female")), "is_kid": false,
				"stat_name": str(fig.get("stat_name", "")), "stat_value": int(fig.get("stat_value", 5)),
				"role_key": str(fig.get("role_key", "")), "role_title": str(fig.get("role_title", "")),
			})
		var ten: Dictionary = TheTen.for_level(lvl)
		if not ten.is_empty():
			GameState.free_one_of_the_ten(str(ten.get("id", "")))
	var i := GameState.rescued_villagers.size()
	while GameState.rescued_villagers.size() < POP:
		var k := i - 20
		GameState.rescued_villagers.append({
			"id": "town_%d" % i, "name": "Townsfolk %d" % i,
			"sex": "Male" if i % 2 == 0 else "Female", "is_kid": (k % 7 == 0),
			"stat_name": ["Farm", "Fishing", "Mine", "Warrior", "Hospital", "Tavern"][i % 6],
			"stat_value": 3, "role_key": "", "role_title": "",
		})
		i += 1
	# the Chancellor's own automation puts everyone to work -- the same call the
	# game makes, so the staffing you see is the game's, not mine
	GameState.auto_staff_villagers()

	# --- the defenders: every adventurer freed by this depth, posted ---
	GameState.ensure_adventurers()
	for id in Adventurers.ids():
		if int(Adventurers.get_def(id).get("level", 0)) <= DEPTH:
			GameState.adventurers[id]["rescued"] = true
			GameState.adventurers[id]["dead"] = false
			if not GameState.set_adventurer_station(id, "wall"):
				GameState.set_adventurer_station(id, "city")

	# --- homes, families, stores ---
	for c in range(10):
		GameState.register_cottage(6200.0 + 240.0 * float(c))
	GameState.auto_pair_couples()
	GameState.village_food = GameState.food_capacity()
	GameState.village_stockpile = {"wood": 120, "stone": 90, "iron_shard": 60}
	GameState.village_treasury = 800
	if p.has_method("add_currency"):
		p.add_currency(2500)

	# let one tick of the real clock run so the automations visibly fire
	GameState.tick_village_clock()
	GameState.apply_leadership_automation()

	var awake := []
	for bn in GameState.BUILDING_POWERS.keys():
		if GameState.has_building_power(bn):
			awake.append(GameState.building_power_name(bn))
	var leaders := []
	for bn in GameState.LEADER_POWERS.keys():
		if GameState.has_leader_power(bn):
			leaders.append(str(GameState.LEADER_POWERS[bn]["name"]))

	say("Deepwood staged: %d souls, %d gold, morale %d, defense %.1f" % [
		GameState.rescued_villagers.size(), p.currency,
		GameState.village_morale(), GameState.village_defense_power()])
	say("building powers awake (%d): %s" % [awake.size(), ", ".join(awake)])
	say("leader powers awake (%d): %s" % [leaders.size(), ", ".join(leaders)])
	say("--- the game is YOURS now. Walk the town; press E on a building for its")
	say("--- panel (the named power is listed there), B to build, L for the diary.")
