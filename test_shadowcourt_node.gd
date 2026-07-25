extends Node

# THE SHADOW COURT (GAME_BIBLE 11) -- a villager raised into the Shadow Army is
# fully pledged to the Monarch and NEEDLESS with it: spirit fixed at 10, never
# hungry, never rotting, never withering, beyond the reach of a neighbour's
# turning. The living around them still live by the old rules.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	get_tree().paused = false

	# ---- save the world ----
	var saved_roster: Array = GameState.rescued_villagers
	var saved_harvest: Array = GameState.harvested_villagers
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var saved_rot: Dictionary = GameState.villager_rot.duplicate(true)
	var saved_food: float = GameState.village_food
	var saved_empty: float = GameState.food_empty_hours
	var saved_hours: float = GameState.game_hours
	var saved_last: float = GameState.village_last_hours_elapsed
	var saved_dungeon: bool = GameState.in_dungeon

	# a bleak, unbuilt, unfed world -- the harshest test of "needs nothing"
	GameState.in_dungeon = false
	GameState.building_stage = {}
	GameState.villager_hp = {}
	GameState.villager_rot = {}
	GameState.village_food = 0.0
	GameState.game_hours = 500.0
	GameState.village_last_hours_elapsed = 500.0

	var shade := {"id": "sc_shadow", "name": "Risen", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": "", "shadow": true}
	var flesh := {"id": "sc_flesh", "name": "Living", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}
	GameState.rescued_villagers = [shade, flesh]

	# ---- spirit fixed at the top, whatever the neglect ----
	check("a shadow's spirit is a perfect 10, jobless/homeless/starving and all",
		absf(GameState.personal_morale_target(shade) - 10.0) < 0.001,
		"%.2f" % GameState.personal_morale_target(shade))
	check("the living beside them are NOT spared the old rules",
		GameState.personal_morale_target(flesh) < 8.0,
		"%.2f" % GameState.personal_morale_target(flesh))

	# ---- shadows draw nothing from the larder ----
	var burn_both := GameState.food_consumption_per_hour()
	GameState.rescued_villagers = [flesh, {"id": "sc_flesh2", "name": "Living2", "sex": "Male",
		"is_kid": false, "stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}]
	var burn_two_flesh := GameState.food_consumption_per_hour()
	check("a shadow hungers for nothing -- it never draws on the food",
		burn_both < burn_two_flesh and absf(burn_both - GameState.FOOD_PER_VILLAGER_PER_DAY / 24.0) < 0.0001,
		"shade+flesh=%.4f  two flesh=%.4f" % [burn_both, burn_two_flesh])
	GameState.rescued_villagers = [shade, flesh]

	# ---- a shadow never enters the rot, even at a dead-zero spirit reading ----
	shade["morale"] = 0.0     # even if something forced it, the guard holds
	flesh["morale"] = 0.0
	GameState.tick_rot(1.0)
	check("a broken-hope reading still cannot rot a shadow",
		not GameState.villager_rot.has("sc_shadow"))
	check("...while the living soul at zero DOES slip toward the dark",
		GameState.villager_rot.has("sc_flesh"))
	shade.erase("morale")
	flesh.erase("morale")
	GameState.villager_rot = {}

	# ---- a shadow never withers, even in a famine past its grace ----
	GameState.village_food = 0.0
	GameState.food_empty_hours = GameState.FOOD_STARVE_GRACE_HOURS + 10.0
	GameState.villager_hp["sc_shadow"] = GameState.VILLAGER_MAX_HP
	GameState.villager_hp["sc_flesh"] = GameState.VILLAGER_MAX_HP
	for h in range(0, 24, 6):
		GameState.game_hours += 6.0
		GameState.tick_morale_effects(6.0)
	check("a shadow keeps full health through a famine that withers the living",
		absf(GameState.get_villager_hp("sc_shadow") - GameState.VILLAGER_MAX_HP) < 0.01,
		"shadow hp=%.1f" % GameState.get_villager_hp("sc_shadow"))
	check("...but the living beside them really are starving (HP lost or gone)",
		(not GameState.find_villager_by_id("sc_flesh").is_empty() \
			and GameState.get_villager_hp("sc_flesh") < GameState.VILLAGER_MAX_HP) \
		or GameState.find_villager_by_id("sc_flesh").is_empty())

	# ---- the raising itself: whatever they fell as, they rise whole ----
	GameState.rescued_villagers = []
	GameState.villager_rot = {"hv": 900.0}
	GameState.villager_hp = {"hv": 3.0}
	GameState.harvested_villagers = [{"id": "hv", "name": "Fallen", "sex": "Male",
		"is_kid": false, "stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": "",
		"morale": 0.0}]
	GameState.raise_shadow_army()
	var risen := GameState.find_villager_by_id("hv")
	check("the raised rise as shadows, spirit at the top, body mended, rot cleared",
		risen.get("shadow", false) and absf(float(risen.get("morale", 0.0)) - 10.0) < 0.01
		and absf(GameState.get_villager_hp("hv") - GameState.VILLAGER_MAX_HP) < 0.01
		and not GameState.villager_rot.has("hv"))

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.harvested_villagers = saved_harvest
	GameState.building_stage = saved_stage
	GameState.villager_hp = saved_hp
	GameState.villager_rot = saved_rot
	GameState.village_food = saved_food
	GameState.food_empty_hours = saved_empty
	GameState.game_hours = saved_hours
	GameState.village_last_hours_elapsed = saved_last
	GameState.in_dungeon = saved_dungeon
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
