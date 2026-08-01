extends Node
# AURAS (settlement-depth roadmap Phase 4 — the last one). The only spatial rule
# that points OUTWARD: Phases 1-3 change what a building produces for ITSELF, an
# aura changes life for everything around it.
#
#   Bar      The Sound of It    gladder homes in earshot
#   Shrine   Hallowed Ground    despair cannot take root in range
#   Hospital The Ward's Shadow  the hurt mend faster nearby
#
# Measured against HOMES and WORKPLACES, never wandering bodies: an NPC avatar
# only exists while the surface scene is loaded and walks about all day, while a
# cottage and a job stand still and survive into the deep. This pins that
# contract, each of the three effects, and the reach falling off with distance.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

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

	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_roster: Array = GameState.rescued_villagers.duplicate(true)
	var s_x: Dictionary = GameState.building_x.duplicate(true)
	var s_ids: Array = GameState.extra_cottage_ids.duplicate()
	var s_pos: Array = GameState.extra_cottage_positions.duplicate()
	var s_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var s_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var s_rot: Dictionary = GameState.villager_rot.duplicate(true)

	# ---- the registry ----
	check("there are auras, and each names a real building", GameState.AURAS.size() > 0)
	var bad := []
	for bn in GameState.AURAS.keys():
		if not (str(bn) in GameState.STARTING_BUILDINGS):
			bad.append("no such building: " + str(bn))
		if float(GameState.AURAS[bn].get("radius", 0.0)) <= 0.0:
			bad.append("no radius: " + str(bn))
		if str(GameState.AURAS[bn].get("name", "")) == "":
			bad.append("unnamed: " + str(bn))
	check("...with a real radius and a name apiece", bad.is_empty(), str(bad))

	# ---- a staged town: Bar/Shrine/Hospital together, one near home, one far ----
	for b in ["Bar", "Shrine", "Hospital"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
	GameState.building_x = {"Bar": 10000.0, "Shrine": 10000.0, "Hospital": 10000.0, "Farm": 10200.0}
	GameState.building_stage["Farm"] = GameState.TOTAL_BUILD_STAGES
	GameState.extra_cottage_ids = ["h_near", "h_far"]
	GameState.extra_cottage_positions = [10300.0, 40000.0]
	GameState.cottage_homes = {
		"h_near": {"a": "au_near", "b": "au_spouse"},
		"h_far": {"a": "au_far", "b": "au_spouse2"},
	}
	var near_v := {"id": "au_near", "name": "Nearby", "sex": "Male", "is_kid": false,
		"stat_name": "", "stat_value": 1, "role_key": "", "role_title": ""}
	var far_v := {"id": "au_far", "name": "Faraway", "sex": "Female", "is_kid": false,
		"stat_name": "", "stat_value": 1, "role_key": "", "role_title": ""}
	var nowhere_v := {"id": "au_none", "name": "Rootless", "sex": "Male", "is_kid": false,
		"stat_name": "", "stat_value": 1, "role_key": "", "role_title": ""}
	GameState.rescued_villagers = [near_v, far_v, nowhere_v]

	check("a home inside the circle is reached", GameState.in_aura("Bar", near_v))
	check("...and a home far down the road is not", not GameState.in_aura("Bar", far_v))
	check("a soul with no home and no job is reached by nothing (house them)",
		GameState.villager_places(nowhere_v).is_empty() and not GameState.in_aura("Bar", nowhere_v))
	# WORK counts too, even when home is far away
	far_v["role_key"] = "Farm"
	check("...but working in range is enough on its own", GameState.in_aura("Bar", far_v))
	far_v["role_key"] = ""

	check("the reach is counted for the panel", GameState.aura_reach("Bar") == 1,
		str(GameState.aura_reach("Bar")))
	GameState.building_stage["Bar"] = 0
	check("a RUINED building projects nothing", not GameState.in_aura("Bar", near_v))
	GameState.building_stage["Bar"] = GameState.TOTAL_BUILD_STAGES

	# ---- effect 1: the Bar gladdens the homes in earshot ----
	var near_target: float = GameState.personal_morale_target(near_v)
	var far_target: float = GameState.personal_morale_target(far_v)
	check("living in earshot of the Bar is worth real spirit",
		near_target > far_target, "%.2f vs %.2f" % [near_target, far_target])

	# ---- effect 2: hallowed ground refuses despair ----
	GameState.villager_rot = {}
	near_v["morale"] = 0.0
	far_v["morale"] = 0.0
	GameState.tick_rot(1.0)
	check("despair cannot open its window inside the Shrine's light",
		not GameState.villager_rot.has("au_near"), str(GameState.villager_rot))
	check("...but it does outside it", GameState.villager_rot.has("au_far"),
		str(GameState.villager_rot))
	# ...and it PULLS BACK someone already slipping when the light reaches them
	GameState.villager_rot["au_near"] = GameState.game_hours
	GameState.tick_rot(1.0)
	check("someone already slipping is pulled back when the light reaches their door",
		not GameState.villager_rot.has("au_near"))

	# ---- effect 3: the ward's shadow mends the hurt nearby ----
	GameState.villager_hp = {"au_near": 40.0, "au_far": 40.0}
	near_v["morale"] = 8.0
	far_v["morale"] = 8.0
	GameState.tick_morale_effects(1.0)
	var healed_near: float = GameState.get_villager_hp("au_near")
	var healed_far: float = GameState.get_villager_hp("au_far")
	check("the hurt mend faster in the ward's shadow",
		healed_near > healed_far, "near %.1f vs far %.1f" % [healed_near, healed_far])

	# ---- it survives the save, and reads off real ground ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("building positions are cached + saved (auras resolve while you're deep)",
		gs.contains('"building_x": building_x'))
	check("auras are measured off homes and workplaces, not wandering avatars",
		gs.contains("func villager_places"))
	GameState.rescued_villagers = s_roster
	GameState.refresh_layout()
	check("refresh reads every standing building's position",
		not GameState.building_x.is_empty(), str(GameState.building_x.size()))
	check("the E-panel tells you who the aura actually reaches",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("aura_reach"))

	# ---- restore ----
	GameState.building_stage = s_stage
	GameState.rescued_villagers = s_roster
	GameState.building_x = s_x
	GameState.extra_cottage_ids = s_ids
	GameState.extra_cottage_positions = s_pos
	GameState.cottage_homes = s_homes
	GameState.villager_hp = s_hp
	GameState.villager_rot = s_rot

	printerr("test_auras : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
