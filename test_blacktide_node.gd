extends Node

# PILLAR 3c — THE BLACK TIDE (dev vision: "a few waves, not often, which the
# village won't survive without adventurers"). Every 6th siege (once you've drawn
# real heat) is a boosted wave the wall's passive defense can't hold -- only
# stationed adventurers turn it -- telegraphed early by a fog-piercing omen.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func mk(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"id": "bt_%d" % i, "name": "Soul %d" % i, "sex": "Male", "is_kid": false})
	return out

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	get_tree().paused = false

	var s_depth: int = GameState.highest_unlocked_level
	var s_seen: int = GameState.sieges_seen
	var s_roster: Array = GameState.rescued_villagers
	var s_adv: Dictionary = GameState.adventurers.duplicate(true)
	var s_report: Dictionary = GameState.away_report.duplicate(true)
	var s_omen: bool = GameState._black_omen_armed
	var s_hours: float = GameState.hours_until_next_siege
	var s_despair: bool = GameState.despair_dead
	var s_live: bool = GameState.live_siege_active
	GameState.despair_dead = false
	GameState.live_siege_active = false

	# ---- cadence: rare + depth-gated ----
	GameState.highest_unlocked_level = 25
	check("every 6th siege is a Black Tide", GameState.is_black_tide_number(6) and GameState.is_black_tide_number(12))
	check("the sieges between are ordinary", not GameState.is_black_tide_number(5) and not GameState.is_black_tide_number(7))
	GameState.highest_unlocked_level = 5
	check("...but none before the town has drawn real heat", not GameState.is_black_tide_number(6))
	GameState.highest_unlocked_level = 25
	GameState.sieges_seen = 5
	check("the NEXT siege is flagged a Black Tide", GameState.next_siege_is_black_tide())

	# ---- the fog-piercing omen fires once, ahead of time ----
	GameState.hours_until_next_siege = 4.0
	GameState._black_omen_armed = true
	GameState.tick_black_tide_omen()
	check("the Black Tide omen fires within its lead window", not GameState._black_omen_armed)

	# ---- the wall CANNOT hold it alone; adventurers CAN ----
	# defense scales with morale, so measure both states with the SAME fixed roster
	# and set the tide BETWEEN them: idle defense can't hold it, stationed can.
	GameState.ensure_adventurers()
	var ids: Array = Adventurers.ids()
	GameState.rescued_villagers = mk(8)
	for id in ids:
		GameState.adventurers[id] = {"rescued": true, "dead": false, "station": "house", "hp": 100.0}
	var def_idle := GameState.village_defense_power()          # defenders sheltered
	for i in range(8):
		GameState.adventurers[ids[i]]["station"] = "wall"
	var def_wall := GameState.village_defense_power()          # posted to the wall
	check("stationing the adventurers raises the village's defense",
		def_wall > def_idle + 1.0, "%.1f -> %.1f" % [def_idle, def_wall])
	var tide := int((def_idle + def_wall) * 0.5)              # past idle, under stationed

	# case A: defenders sheltered -> the tide claims villagers
	for id in ids:
		GameState.adventurers[id]["station"] = "house"
	GameState.rescued_villagers = mk(8)
	GameState.away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}
	GameState.resolve_siege_offline(tide)
	check("a Black Tide with the defenders idle CLAIMS villagers",
		int(GameState.away_report.villagers_lost) > 0, str(GameState.away_report))

	# case B: same tide, adventurers on the wall -> it holds
	for i in range(8):
		GameState.adventurers[ids[i]]["station"] = "wall"
	GameState.rescued_villagers = mk(8)
	GameState.away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}
	GameState.resolve_siege_offline(tide)
	check("...and the same tide is TURNED, not a soul lost",
		int(GameState.away_report.villagers_lost) == 0 and int(GameState.away_report.repelled) > 0, str(GameState.away_report))

	# ---- wiring ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the tide boosts the tier + pierces the fog",
		gs.contains("BLACK_TIDE_TIER_MULT") and gs.contains("THE BLACK TIDE BREAKS"))
	check("the count survives the save", gs.contains('"sieges_seen": sieges_seen'))
	var sm := FileAccess.open("res://siege_manager.gd", FileAccess.READ).get_as_text()
	check("the live wave fields a bigger horde on a Black Tide", sm.contains("is_black"))

	GameState.highest_unlocked_level = s_depth
	GameState.sieges_seen = s_seen
	GameState.rescued_villagers = s_roster
	GameState.adventurers = s_adv
	GameState.away_report = s_report
	GameState._black_omen_armed = s_omen
	GameState.hours_until_next_siege = s_hours
	GameState.despair_dead = s_despair
	GameState.live_siege_active = s_live
	printerr("test_blacktide : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
