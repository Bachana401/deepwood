extends Node

# THE REAVER CARAVAN (renewability pillar 2, 2026-07-28): the marching
# invasion's whole GameState half, headless -- the road only cares once the
# deep does, the dust announces an hour out, the away-resolution pays or
# tolls honestly, the cache honours ownership, and the clock survives a
# new game whole. The live three-wave/captain choreography is source-guarded
# (it needs a staged village to run).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var pl: Node = null
	for i in range(1200):
		await get_tree().process_frame
		pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			break
	if pl == null:
		printerr("no player"); get_tree().quit(1); return

	var saved_deep: int = GameState.deepest_level_reached
	var saved_gold: int = pl.currency
	var saved_opening: bool = GameState.opening_done
	GameState.opening_done = true

	# ---- the road only cares once the deep does ----
	GameState.deepest_level_reached = CaravanProbe.MIN_FLOOR() - 1
	GameState.hours_until_caravan = 0.5
	GameState.caravans_seen = 0
	GameState.tick_caravans(2.0)
	check("no caravan rolls before floor %d" % GameState.CARAVAN_MIN_FLOOR,
		GameState.caravans_seen == 0)

	# ---- the dust announces, then the wheels arrive ----
	GameState.deepest_level_reached = GameState.CARAVAN_MIN_FLOOR
	GameState.hours_until_caravan = 1.4
	GameState.caravan_warned = false
	GameState.tick_caravans(0.5)   # 0.9h out -> the dust rises
	check("dust on the east road, about an hour out", GameState.caravan_warned)
	check("...but the wheels have not arrived yet", GameState.caravans_seen == 0)
	# the wheels arrive while away: the clock mechanics alone are asserted
	# here (the tick's tier is prosperity-driven -- outcomes are proven
	# deterministically below)
	GameState.in_dungeon = true
	GameState.tick_caravans(1.0)
	GameState.in_dungeon = false
	check("the caravan rolled once", GameState.caravans_seen == 1)
	check("...and the clock re-armed inside its 2-4 day window",
		GameState.hours_until_caravan >= GameState.CARAVAN_GAP_MIN - 0.01
		and GameState.hours_until_caravan <= GameState.CARAVAN_GAP_MAX + 0.01,
		"%0.1f" % GameState.hours_until_caravan)
	# strong defense, known tier: a held road PAYS
	GameState.rescued_villagers = []
	for i in range(8):
		GameState.rescued_villagers.append({"id": "war_%d" % i, "name": "W", "sex": "Male",
			"is_kid": false, "stat_name": "Warrior", "stat_value": 8,
			"role_key": "Barracks", "role_title": "Warrior"})
	var gold0: int = pl.currency
	GameState.resolve_caravan_offline(2)
	check("a held road PAYS (the cache's gold arrived)", pl.currency > gold0,
		"%d -> %d" % [gold0, pl.currency])

	# ---- the cache honours ownership and the pool is real ----
	var bad_pool := []
	for id in GameState.CARAVAN_WEAPON_POOL:
		if Inventory.get_item_def(id).is_empty():
			bad_pool.append(id)
	check("every reaver-pool weapon is a real item", bad_pool.is_empty(), ", ".join(bad_pool))
	var owned_before := 0
	for id in GameState.CARAVAN_WEAPON_POOL:
		owned_before += pl.inventory.get_count(id)
	GameState.grant_reaver_cache(4)
	var owned_after := 0
	for id in GameState.CARAVAN_WEAPON_POOL:
		owned_after += pl.inventory.get_count(id)
	check("the cache arms you with ONE themed weapon you lacked",
		owned_after == owned_before + 1, "%d -> %d" % [owned_before, owned_after])

	# ---- a weak road pays the toll instead (gold out, grief up) ----
	GameState.rescued_villagers = [{"id": "v1", "name": "V", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": "", "morale": 8.0}]
	var gold1: int = pl.currency
	var shock0: float = GameState.morale_death_shock
	GameState.resolve_caravan_offline(9)
	check("an unheld road pays the toll in gold and grief",
		pl.currency < gold1 and GameState.morale_death_shock > shock0,
		"gold %d->%d shock %0.0f->%0.0f" % [gold1, pl.currency, shock0, GameState.morale_death_shock])

	# ---- the live choreography is wired (source guard) ----
	var msrc := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the manager stages three waves and a named captain",
		msrc.contains("func start_caravan") and msrc.contains("_next_caravan_wave")
		and msrc.contains("_spawn_captain") and msrc.contains("caravan_wave < 3")
		and msrc.contains("CARAVAN_CAPTAIN_NAMES"))
	check("a live siege takes precedence over the road",
		msrc.contains("GameState.live_siege_active or caravan_wave > 0"))
	var gsrc := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the clock survives a new game whole (reset-leak lesson)",
		gsrc.contains("hours_until_caravan = CARAVAN_FIRST_HOURS")
		and gsrc.contains('"hours_until_caravan": hours_until_caravan'))

	# ---- restore ----
	GameState.deepest_level_reached = saved_deep
	GameState.opening_done = saved_opening
	pl.currency = saved_gold
	GameState.hours_until_caravan = GameState.CARAVAN_FIRST_HOURS
	GameState.caravan_warned = false
	GameState.caravans_seen = 0
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# tiny indirection so the first check reads clearly
class CaravanProbe:
	static func MIN_FLOOR() -> int:
		return GameState.CARAVAN_MIN_FLOOR
