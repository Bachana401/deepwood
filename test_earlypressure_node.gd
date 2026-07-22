extends Node

# PILLAR 3b (2026-07-22): the early village should be HARD (poor, miserable, low
# income) but NOT a death spiral. Before, a fresh homeless/jobless town sat at
# ~0.5 morale and collapsed to demons in ~5 real minutes. Now a FED soul holds a
# floor -- poverty alone never rots them; only STARVATION (empty larder) can.
# Locks: fed + neglected = stable & miserable; starving = still deadly.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func mk(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"id": "ep_%d" % i, "name": "Soul %d" % i, "sex": "Male" if i % 2 == 0 else "Female",
			"is_kid": false, "stat_name": "Farm", "stat_value": 4, "role_key": "", "role_title": ""})
	return out

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	get_tree().paused = false

	var saved_roster: Array = GameState.rescued_villagers
	var saved_dev: bool = GameState.dev_mode
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var saved_rot: Dictionary = GameState.villager_rot.duplicate(true)
	var saved_food: float = GameState.village_food
	var saved_empty: float = GameState.food_empty_hours
	var saved_hours: float = GameState.game_hours
	var saved_last: float = GameState.village_last_hours_elapsed
	GameState.dev_mode = false

	# ---- a fresh, unbuilt, unstaffed, homeless town ----
	GameState.building_stage = {}
	GameState.villager_hp = {}
	GameState.villager_rot = {}
	GameState.rescued_villagers = mk(6)
	GameState.game_hours = 0.0
	GameState.village_last_hours_elapsed = 0.0
	GameState.food_empty_hours = 0.0

	# a fed soul sits above the rot zone (the whole fix)
	GameState.village_food = GameState.food_capacity()
	var t0 := GameState.personal_morale_target(GameState.rescued_villagers[0])
	check("a fed, homeless, jobless soul sits above the rot floor (not ~0)",
		t0 >= GameState.ROT_SAFE_FLOOR - 0.01, "target=%.2f" % t0)

	# ---- KEPT FED for 6 in-game days, neglected: nobody rots, nobody dies ----
	var pop0 := GameState.rescued_villagers.size()
	for h in range(0, 144, 6):
		GameState.village_food = GameState.food_capacity()   # the larder is kept stocked
		GameState.game_hours += 6.0
		GameState.tick_village_clock()
	check("a FED but neglected town keeps all its people (no death spiral)",
		GameState.rescued_villagers.size() == pop0, "%d -> %d" % [pop0, GameState.rescued_villagers.size()])
	check("...and nobody is even in the rot window", GameState.villager_rot.is_empty(),
		str(GameState.villager_rot.size()))
	var m := GameState.village_morale()
	check("...yet the town is genuinely MISERABLE (hard, not happy)", m > 0 and m <= 40, "morale=%d" % m)

	# ---- STARVATION still bites: an EMPTY larder past grace withers them ----
	GameState.village_food = 0.0
	GameState.food_empty_hours = GameState.FOOD_STARVE_GRACE_HOURS + 5.0
	for v in GameState.rescued_villagers:
		GameState.villager_hp[str(v.get("id", ""))] = GameState.VILLAGER_MAX_HP
	var pop_before2 := GameState.rescued_villagers.size()
	var total_before := 0.0
	for v in GameState.rescued_villagers:
		total_before += GameState.get_villager_hp(str(v.get("id", "")))
	for h in range(0, 18, 6):
		GameState.game_hours += 6.0
		GameState.tick_village_clock()
	var total_after := 0.0
	for v in GameState.rescued_villagers:
		total_after += GameState.get_villager_hp(str(v.get("id", "")))
	# withering shows as HP lost across the survivors AND/OR deaths -- either way
	# the starving town is losing ground (the real pressure the floor never blunts)
	check("an EMPTY larder still withers the town (real pressure remains)",
		GameState.rescued_villagers.size() < pop_before2 or total_after < total_before,
		"pop %d->%d, hp %.0f->%.0f" % [pop_before2, GameState.rescued_villagers.size(), total_before, total_after])

	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the fed-soul floor is real and food-gated",
		gs.contains("ROT_SAFE_FLOOR") and gs.contains("if has_food():"))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.dev_mode = saved_dev
	GameState.building_stage = saved_stage
	GameState.villager_hp = saved_hp
	GameState.villager_rot = saved_rot
	GameState.village_food = saved_food
	GameState.food_empty_hours = saved_empty
	GameState.game_hours = saved_hours
	GameState.village_last_hours_elapsed = saved_last
	printerr("test_earlypressure : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
