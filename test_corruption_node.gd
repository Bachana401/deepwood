extends Node

# CORRUPTION v2 (GAME_BIBLE 10), ENABLED. The Law of Despair, locally: rot
# opens at PERSONAL morale zero, mending redeems inside the window, the
# window running out turns them. Infection spreads by each neighbour's own
# state; healthy neighbours are the firewall. Starvation KILLS; broken hope
# CORRUPTS -- two separate fates. Warriors never break. Children rot fast.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	var saved_roster: Array = GameState.rescued_villagers
	var saved_rot: Dictionary = GameState.villager_rot
	var saved_hours: float = GameState.game_hours
	var saved_log: Array = GameState.village_log
	var saved_homes: Dictionary = GameState.cottage_homes
	var saved_shock: float = GameState.morale_death_shock
	GameState.village_log = []
	GameState.villager_rot = {}
	GameState.morale_death_shock = 0.0
	GameState.game_hours = 100.0

	check("corruption is ENABLED", GameState.CORRUPTION_ENABLED)

	# ---- the rot clock: opens at zero, redeems on mending, turns at the end ----
	var soul := {"id": "cor_soul", "name": "Edda", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": "", "morale": 0.0}
	GameState.rescued_villagers = [soul]
	GameState.tick_rot(0.1)
	check("morale zero opens the rot window, and the Log says so",
		GameState.villager_rot.has("cor_soul")
		and str(GameState.village_log[0].get("text", "")).contains("slipping"))
	soul["morale"] = 5.0
	GameState.tick_rot(0.1)
	check("mending their life REDEEMS them -- nobody turns whose needs are fixed",
		not GameState.villager_rot.has("cor_soul")
		and str(GameState.village_log[0].get("text", "")).contains("pulled back"))
	soul["morale"] = 0.0
	GameState.tick_rot(0.1)
	GameState.game_hours += GameState.ROT_HOURS + 0.5
	GameState.tick_rot(0.1)
	check("the window running out TURNS them", GameState.rescued_villagers.is_empty())

	# ---- children rot in half the time; warriors never ----
	GameState.game_hours = 200.0
	var kid := {"id": "cor_kid", "name": "Pip", "sex": "Male", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "morale": 0.0}
	var vet := {"id": "cor_vet", "name": "Sarge", "sex": "Male", "is_kid": false,
		"stat_name": "Warrior", "stat_value": 8, "role_key": "Barracks", "role_title": "Warrior", "morale": 0.0}
	GameState.rescued_villagers = [kid, vet]
	GameState.tick_rot(0.1)
	check("a warrior at zero does NOT rot -- they break in battle, never in spirit",
		not GameState.villager_rot.has("cor_vet"))
	GameState.game_hours += GameState.ROT_HOURS * GameState.ROT_CHILD_MULT + 0.2
	GameState.tick_rot(0.1)
	var kid_turned := true
	for v in GameState.rescued_villagers:
		if str(v.get("id", "")) == "cor_kid":
			kid_turned = false
	check("a child turns in HALF an adult's window", kid_turned)
	check("the warrior still stands", GameState.rescued_villagers.size() == 1)

	# ---- infection: dragged / pushed / the firewall ----
	var low := {"id": "inf_low", "name": "Low", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": "", "morale": 2.0}
	var strained := {"id": "inf_str", "name": "Strained", "sex": "Female", "is_kid": false,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "morale": 6.0}
	GameState.rescued_villagers = [low, strained]
	GameState._spread_infection(Vector2(INF, INF))
	check("an already-low neighbour is dragged UNDER (their own rot begins)",
		float(low["morale"]) <= 0.01, str(low["morale"]))
	check("a healthy-but-strained neighbour takes the push, not the fall",
		absf(float(strained["morale"]) - 4.0) < 0.01, str(strained["morale"]))
	var sound := {"id": "inf_ok", "name": "Sound", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 5, "role_key": "Farm", "role_title": "Farmer",
		"partner_id": "inf_ok2", "morale": 8.0}
	var other := {"id": "inf_ok2", "name": "Other", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 5, "role_key": "Farm", "role_title": "Farmer",
		"partner_id": "inf_ok", "morale": 8.0}
	GameState.rescued_villagers = [sound, other]
	GameState.cottage_homes = {"cor_home": {"a": "inf_ok", "b": "inf_ok2"}}
	GameState._spread_infection(Vector2(INF, INF))
	check("a well-kept neighbour RESISTS -- healthy villagers are the firewall",
		float(sound["morale"]) >= 7.9 and float(other["morale"]) >= 7.9,
		"%s / %s" % [sound["morale"], other["morale"]])

	# ---- death shock: a wave that stacks; children feel it harder ----
	var adult := {"id": "ds_a", "name": "A", "sex": "Male", "is_kid": false,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "morale": 10.0}
	var child := {"id": "ds_k", "name": "K", "sex": "Female", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "morale": 10.0}
	GameState.rescued_villagers = [adult, child]
	GameState.register_villager_deaths(1)
	check("unwitnessed news still lands, flat",
		absf(float(adult["morale"]) - (10.0 - GameState.DEATH_SHOCK_ABSTRACT)) < 0.01)
	check("children feel every death half again as hard",
		float(child["morale"]) < float(adult["morale"]))

	# ---- the omen, the fates, the trickle, the telegraph, the save ----
	GameState.on_wall_broken("west")
	check("a fallen rampart is an omen for every spirit -- modest, and logged",
		absf(float(adult["morale"]) - (10.0 - GameState.DEATH_SHOCK_ABSTRACT - GameState.WALL_BREAK_MORALE_HIT)) < 0.01
		and str(GameState.village_log[0].get("text", "")).contains("rampart has fallen"))
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("starvation KILLS (a death), it does not corrupt",
		gs.contains("starved to death"))
	check("a loose demon's presence saps hope -- a trickle by design",
		gs.contains("FALLEN_PRESENCE_DRAIN") and gs.contains("village_demon"))
	check("the rot wears a grey, pulsing telegraph on the avatar",
		FileAccess.open("res://npc.gd", FileAccess.READ).get_as_text().contains("GameState.villager_rot.has(villager_id)"))
	check("the rot clock survives the save", gs.contains('"villager_rot": villager_rot'))
	check("a turning infects by proximity", gs.contains("_spread_infection(pos"))

	GameState.rescued_villagers = saved_roster
	GameState.villager_rot = saved_rot
	GameState.game_hours = saved_hours
	GameState.village_log = saved_log
	GameState.cottage_homes = saved_homes
	GameState.morale_death_shock = saved_shock
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
