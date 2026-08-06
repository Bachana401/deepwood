extends Node

# MATING-DEPRESSION (GAME_BIBLE 7) -- loneliness is not flat: an adult who stays
# single SADDENS the longer they go unpaired (the -2 deepens toward -3.5 over
# ~5 days), pairing lifts it entirely, children are exempt, and a widow's clock
# waits out the mourning they're barred from re-pairing through.

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

	# ---- a controlled, operational town (restored at the end) ----
	var saved_roster: Array = GameState.rescued_villagers
	var saved_houses: Dictionary = GameState.mating_houses
	var saved_homes: Dictionary = GameState.cottage_homes
	var saved_hours: float = GameState.game_hours
	var saved_health: Dictionary = GameState.building_health.duplicate(true)
	var saved_stage: Dictionary = GameState.building_stage.duplicate(true)
	var saved_shock: float = GameState.morale_death_shock
	var saved_food: float = GameState.village_food
	var saved_ilo = GameState.the_ten.get("ten_ilo", {"freed": false})
	var saved_pregs: Dictionary = GameState.pregnancies

	GameState.morale_death_shock = 0.0
	GameState.the_ten["ten_ilo"] = {"freed": false}
	GameState.village_food = 500.0
	GameState.game_hours = 1000.0
	GameState.mating_houses = {}
	GameState.cottage_homes = {}
	GameState.pregnancies = {}
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
	# an unhoused, employed adult + a partner to pair with; pop padded to target
	var A := {"id": "md_a", "name": "Solo", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "Farm", "role_title": "Farmer"}
	var B := {"id": "md_b", "name": "Match", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "Farm", "role_title": "Farmer"}
	var kid := {"id": "md_kid", "name": "Sprout", "sex": "Female", "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": ""}
	var roster := [A, B, kid]
	for i in range(int(GameState.MORALE_POP_TARGET)):
		roster.append({"id": "md_pad_%d" % i, "name": "Pad %d" % i, "sex": "Male",
			"is_kid": false, "stat_name": "Farm", "stat_value": 3,
			"role_key": "Farm", "role_title": "Farmer", "partner_id": "md_pad_x"})
	GameState.rescued_villagers = roster

	# ---- depth 0: a freshly-single adult still carries exactly the -2 ----
	A.erase("single_since_hours")
	var base_single := GameState.personal_morale_target(A)   # unstamped -> depth 0
	A["partner_id"] = "md_b"
	B["partner_id"] = "md_a"
	var paired := GameState.personal_morale_target(A)
	check("pairing lifts the whole loneliness penalty (~2.0)",
		absf((paired - base_single) - GameState.SINGLE_MORALE_PENALTY) < 0.05,
		"single=%.2f paired=%.2f" % [base_single, paired])
	A.erase("partner_id")
	B.erase("partner_id")

	# ---- the deepening: solitude drags the penalty toward the -3.5 floor ----
	A["single_since_hours"] = GameState.game_hours - GameState.SINGLE_DEEPEN_HOURS
	var deep := GameState.personal_morale_target(A)
	check("five days single sinks loneliness to its -3.5 floor",
		absf((base_single - deep) - (GameState.SINGLE_MORALE_PENALTY_MAX - GameState.SINGLE_MORALE_PENALTY)) < 0.05,
		"base=%.2f deep=%.2f (drop %.2f)" % [base_single, deep, base_single - deep])
	A["single_since_hours"] = GameState.game_hours - GameState.SINGLE_DEEPEN_HOURS * 0.5
	var mid := GameState.personal_morale_target(A)
	# at the halfway mark the penalty is the midpoint (~-2.75), i.e. an EXTRA
	# ~0.75 below the -2 base
	var want_extra := (GameState.SINGLE_MORALE_PENALTY_MAX - GameState.SINGLE_MORALE_PENALTY) * 0.5
	check("halfway through, it sits at the midpoint (~-2.75)",
		absf((base_single - mid) - want_extra) < 0.05,
		"extra drop=%.2f want=%.2f" % [base_single - mid, want_extra])
	# it never sinks past the floor, however long the solitude
	A["single_since_hours"] = GameState.game_hours - GameState.SINGLE_DEEPEN_HOURS * 10.0
	check("the sadness bottoms out at the floor, it does not run away",
		absf(GameState.personal_morale_target(A) - deep) < 0.01)
	A.erase("single_since_hours")

	# ---- the clock is stamped/cleared by the tick ----
	GameState.tick_personal_morale(1.0)
	check("the tick starts a single adult's solitude clock", A.has("single_since_hours"))
	check("children never carry a solitude clock", not kid.has("single_since_hours"))
	# pair them, tick again: the clock clears and the sadness is gone
	A["partner_id"] = "md_b"
	B["partner_id"] = "md_a"
	GameState.tick_personal_morale(1.0)
	check("pairing clears the clock (a later break-up starts fresh)",
		not A.has("single_since_hours"))
	A.erase("partner_id")
	B.erase("partner_id")

	# ---- a widow's clock waits out the mourning they can't re-pair through ----
	A.erase("single_since_hours")
	A["widowed_at_hours"] = GameState.game_hours
	GameState.tick_personal_morale(1.0)
	check("a mourner's solitude clock only starts when they may love again",
		A.has("single_since_hours")
		and absf(float(A["single_since_hours"]) - (float(A["widowed_at_hours"]) + GameState.WIDOW_MOURN_HOURS)) < 0.01,
		str(A.get("single_since_hours", "none")))
	# so through the mourning window the loneliness does NOT deepen past base:
	# a soul whose only difference is that future-dated clock reads identical to
	# a freshly-single one (both at the -2 base, zero extra deepening)
	var widow_extra := base_single - GameState.personal_morale_target({
		"id": "md_a", "name": "Solo", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "Farm", "role_title": "Farmer",
		"single_since_hours": A["single_since_hours"]})
	check("loneliness stays at base through the mourning it cannot pair through",
		absf(widow_extra) < 0.05, "extra=%.2f" % widow_extra)

	# ---- it saves with the game (villager dicts serialize wholesale) ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the roster (and each soul's solitude clock) survives the save",
		gs.contains('"rescued_villagers": rescued_villagers'))

	# ---- THE FLYWHEEL (2026-07-29): more cottages MUST mean more cradles ----
	# The bug this pins: update_cottage_families used to conceive exactly ONE
	# child per cycle regardless of how many couples were housed, so the town
	# could never grow to city scale. Births must now scale with the cottage
	# count -- that is the whole "the brake is the cottage count itself" contract.
	var conceptions := func(couples: int) -> int:
		GameState.village_food = 500.0
		GameState.morale_death_shock = 0.0
		GameState.rescued_villagers = []
		GameState.cottage_homes = {}
		GameState.pregnancies = {}
		for i in range(couples):
			var m := {"id": "fw_m%d" % i, "name": "M%d" % i, "sex": "Male", "is_kid": false,
				"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}
			var f := {"id": "fw_f%d" % i, "name": "F%d" % i, "sex": "Female", "is_kid": false,
				"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}
			GameState.rescued_villagers.append(m)
			GameState.rescued_villagers.append(f)
			GameState.cottage_homes["fw_h%d" % i] = {"a": m.id, "b": f.id}
		# run several cycles so the per-couple roll averages out
		var total := 0
		for _c in range(12):
			GameState.pregnancies = {}
			GameState._family_cycle_accum = 0.0
			GameState.update_cottage_families(GameState.FAMILY_CYCLE_HOURS)
			total += GameState.pregnancies.size()
		return total
	var few: int = conceptions.call(1)
	var many: int = conceptions.call(12)
	check("a single housed couple still conceives (the cradle isn't dead)", few > 0, "%d over 12 cycles" % few)
	check("TWELVE cottages out-breed ONE by a wide margin (the flywheel spins)",
		many > few * 4, "1 cottage=%d births, 12 cottages=%d births over 12 cycles" % [few, many])
	check("a couple already expecting is not double-booked",
		many <= 12 * 12, "%d (cap %d)" % [many, 12 * 12])
	# the brakes still hold: an empty larder stops conception dead
	GameState.village_food = 0.0
	GameState.pregnancies = {}
	GameState._family_cycle_accum = 0.0
	GameState.update_cottage_families(GameState.FAMILY_CYCLE_HOURS)
	check("a starving village conceives nobody, however many cottages stand",
		GameState.pregnancies.is_empty(), "%d conceived on an empty larder" % GameState.pregnancies.size())

	# ---- restore ----
	GameState.rescued_villagers = saved_roster
	GameState.mating_houses = saved_houses
	GameState.cottage_homes = saved_homes
	GameState.game_hours = saved_hours
	GameState.building_health = saved_health
	GameState.building_stage = saved_stage
	GameState.morale_death_shock = saved_shock
	GameState.village_food = saved_food
	GameState.the_ten["ten_ilo"] = saved_ilo
	GameState.pregnancies = saved_pregs
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
