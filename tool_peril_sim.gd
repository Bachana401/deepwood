extends Node
# ======================== THE FIRE SIMULATOR ========================
# Run:  MONARCH_TEST="res://tool_peril_sim.gd" Godot.exe --headless --path .
#
# WHAT THIS FILE USED TO BE, AND WHY IT CHANGED (QA, 2026-08-06)
#   It was the SICKNESS & FIRE simulator, written against the single-strain
#   sickness. That model is gone: SICK_DRAIN_PER_HOUR no longer exists, the
#   ordinary illness costs no HP at all (it suppresses the passive regen and
#   sours the mood), and only the PLAGUE drains, at PLAGUE_DRAIN_PER_HOUR.
#   Every sickness reading in here was measuring a constant the game no longer
#   has -- and worse, the file therefore did not resolve at all, so running it
#   idled at the menu and read as a six-minute TIMEOUT rather than as an error.
#   The sickness half now lives in tool_plague_sim.gd, written for the two-strain
#   model. This file keeps the half nothing else measures: FIRE.
#
# WHY FIRE NEEDS ITS OWN SIM
#   Fire is the only system whose cost is paid by a BUILDING rather than a body,
#   and it is fought by an automation that runs on a DIFFERENT SCHEDULE from the
#   thing it fights. The burn is in tick_village_clock (per in-game hour); the
#   crew's repair is in apply_leadership_automation (per INCOME_INTERVAL_SECONDS
#   of REAL time). A measurement that drives only one of them measures half a
#   system -- which is how the douse-roll bug survived once already: an unclamped
#   roll put 1.06 on a randf(), so every fire went out on its first day forever
#   and the whole system switched itself off the moment the crew was staffed.
#
# METHOD
#   * Nothing here calls a fire function with numbers it invented. The hourly
#     half is driven through tick_village_clock(), the daily half through
#     _fire_day(), and the crew's repair through apply_leadership_automation()
#     on the real-time cadence _process gives it.
#   * Every rate is reported in REAL minutes of play as well as in-game hours:
#     "26 health an hour" means nothing until you know an in-game hour is 25
#     real seconds.
#   * 1 in-game day = 600 real seconds, so 1 in-game hour = 25 real seconds.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)
func say(t: String) -> void: printerr(t)

var p: Node = null
const STEP := 0.25                    # in-game hours per simulated frame
var _income_accum := 0.0

func real_min(game_hours: float) -> float:
	return game_hours / GameState.HOURS_PER_SECOND / 60.0

# --- the town ------------------------------------------------------------
# Halls the village actually PLACED. auto_repair_one and _auto_mend_one both skip
# a building with no node in the scene, so a repair measured on a GameState-only
# town measures a crew that was never allowed to lift a hammer -- and reports a
# clean, confident zero for it.
func placed_halls() -> Array:
	var out: Array = []
	for bn in GameState.STARTING_BUILDINGS:
		if get_tree().get_first_node_in_group("building_role_" + str(bn)) != null:
			out.append(str(bn))
	return out

# Stand `names` up whole and flatten everything else. With `sync`, node-bearing
# halls are refreshed too: building.gd caches stage and health at _ready, and the
# fire's hourly resync returns early while that cached stage still reads a ruin.
# The Monte Carlo sections pass sync=false -- they never touch a node, and
# rebuilding every hall's geometry a thousand times over would cost minutes.
func stand(names: Array, sync := false) -> void:
	for bn in GameState.STARTING_BUILDINGS:
		GameState.building_stage[bn] = 0
		GameState.building_health[bn] = 0
	for n in names:
		GameState.building_stage[str(n)] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[str(n)] = float(GameState.BUILDING_MAX_HEALTH)
	if not sync:
		return
	for n2 in placed_halls():
		var node: Node = get_tree().get_first_node_in_group("building_role_" + str(n2))
		if node != null and node.has_method("sync_from_state"):
			node.call("sync_from_state")

func crew(hands: int) -> void:
	GameState.rescued_villagers = []
	for i in range(hands):
		GameState.rescued_villagers.append({"id": "hand%d" % i, "name": "Hand", "sex": "Male",
			"is_kid": false, "stat_name": "", "stat_value": 3,
			"role_key": "Builderhouse", "role_title": "Builderhouse"})

# A WHOLE FRAME, the way _process runs one: the automation on its real-time
# cadence, then the clock. Never one without the other -- that is the point of
# this file.
func run_frame(hours: float) -> void:
	GameState.village_last_hours_elapsed = GameState.game_hours
	_income_accum = 0.0
	var steps: int = int(round(hours / STEP))
	var real_per_step: float = STEP / GameState.HOURS_PER_SECOND
	for i in range(steps):
		GameState.game_hours += STEP
		_income_accum += real_per_step
		if _income_accum >= GameState.INCOME_INTERVAL_SECONDS:
			_income_accum -= GameState.INCOME_INTERVAL_SECONDS
			GameState.apply_leadership_automation()
		GameState.tick_village_clock()

# A quiet town: nothing but the fire may touch a building inside these windows.
func quiet() -> void:
	GameState.sick = {}
	GameState.plague_ids = {}
	GameState.villager_hp = {}
	GameState.burning = {}
	GameState._fire_accum = 0.0
	GameState.hours_until_next_siege = 1000000.0
	GameState.live_siege_active = false
	GameState.village_food = 100000.0
	GameState.food_empty_hours = 0.0
	GameState.village_stockpile = {"wood": 9999, "stone": 9999, "iron_shard": 0}
	# PAYDAY IS THE HARNESS BUG THAT ATE THE FIRST RUN OF THIS FILE. wage_accum_hours
	# is a member that survives everything below, so a payroll left mid-count by an
	# earlier section lands inside a later measurement window -- and an unpaid crew
	# WALKS OUT. The one-hand row read as a completely unfought fire because its
	# single hand had quit in the first in-game hour. Reset the counter and fill the
	# town's own purse: a fire measurement must never be a wage measurement.
	GameState.wage_accum_hours = 0.0
	GameState.village_treasury = 1000000
	GameState.building_levels = {}
	GameState.building_districts = {}
	GameState.building_plots = {}
	GameState.building_neighbors = {}

# ================================================================== main
func _ready() -> void:
	for i in range(1800):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false
	seed(20260806)

	var placed: Array = placed_halls()
	var burn_hall := ""
	for ph in placed:
		if str(ph) != "Builderhouse":
			burn_hall = str(ph)
			break
	if burn_hall == "":
		printerr("no placed hall to burn"); get_tree().quit(1); return
	say("\n  the hall under the torch: %s (one of %d the village actually placed)"
		% [burn_hall, placed.size()])

	say("\n  the constants under test:")
	say("    FIRE_DAMAGE_PER_HOUR        %.1f   of %d health -> a whole hall in %.1f in-game hours (%.1f real min)" % [
		GameState.FIRE_DAMAGE_PER_HOUR, GameState.BUILDING_MAX_HEALTH,
		float(GameState.BUILDING_MAX_HEALTH) / GameState.FIRE_DAMAGE_PER_HOUR,
		real_min(float(GameState.BUILDING_MAX_HEALTH) / GameState.FIRE_DAMAGE_PER_HOUR)])
	say("    FIRE_CREW_SUPPRESS          %.2f   per Builderhouse hand (clamped at 0.90)" % GameState.FIRE_CREW_SUPPRESS)
	say("    FIRE_OUT_CHANCE_PER_DAY     %.2f   + suppression, capped at %.2f" % [
		GameState.FIRE_OUT_CHANCE_PER_DAY, GameState.FIRE_OUT_CHANCE_CAP])
	say("    FIRE_SPREAD_CHANCE_PER_DAY  %.2f   to each immediate neighbour" % GameState.FIRE_SPREAD_CHANCE_PER_DAY)
	say("    FIRE_CHANCE_PER_DAY         %.3f  per standing hall over %d, x%.1f for a hearth" % [
		GameState.FIRE_CHANCE_PER_DAY, GameState.FIRE_MIN_BUILDINGS, GameState.FIRE_HEARTH_MULT])
	say("    MEND_PER_PASS               %d     every %.0f real seconds (the crew's OTHER job)" % [
		GameState.MEND_PER_PASS, GameState.INCOME_INTERVAL_SECONDS])
	say("    -> burn %.1f health per real minute  |  mend %.1f health per real minute" % [
		GameState.FIRE_DAMAGE_PER_HOUR * GameState.HOURS_PER_SECOND * 60.0,
		float(GameState.MEND_PER_PASS) * 60.0 / GameState.INCOME_INTERVAL_SECONDS])

	# ---------- F1: HOW LONG A BURNING HALL LASTS ----------
	say("\n========== F1: HOW LONG A BURNING HALL LASTS ==========")
	say("  One hall alight, driven through tick_village_clock() a quarter-hour at a")
	say("  time until the fire knocks it back down a build stage. The daily roll is")
	say("  held off so the blaze cannot simply go out: this measures the crew's")
	say("  WATER (_fire_suppression), never its hammer.")
	say("  hands | burn/hr | gutted after       | in real play")
	var gut_hours: Callable = func(hands: int) -> float:
		quiet()
		stand(placed, true)
		crew(hands)
		GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES if hands > 0 else 0
		GameState.building_health["Builderhouse"] = float(GameState.BUILDING_MAX_HEALTH)
		GameState.burning = {burn_hall: GameState.game_hours}
		GameState.village_last_hours_elapsed = GameState.game_hours
		var h := 0.0
		while h < 480.0:
			GameState.game_hours += STEP
			GameState.tick_village_clock()
			GameState._fire_accum = 0.0        # hold the daily roll off
			h += STEP
			if int(GameState.building_stage.get(burn_hall, 0)) < GameState.TOTAL_BUILD_STAGES:
				return h
		return -1.0
	var gut_alone := 0.0
	for hands in [0, 1, 2, 4, 6, 8]:
		crew(int(hands))
		GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES if int(hands) > 0 else 0
		var fought: float = clampf(GameState._fire_suppression(), 0.0, 0.9)
		var g: float = gut_hours.call(int(hands))
		if int(hands) == 0:
			gut_alone = g
		say("   %2d   |  %5.1f  | %s | %s" % [int(hands),
			GameState.FIRE_DAMAGE_PER_HOUR * (1.0 - fought),
			"never (480h+)      " if g < 0.0 else "%6.1f in-game hours " % g,
			"never" if g < 0.0 else "%.1f real minutes of watching it" % real_min(g)])
	check("F1: a fire nobody fights really does gut a hall",
		gut_alone > 0.0, "still standing after 480 in-game hours")

	# ---------- F2: HOW OFTEN A TOWN CATCHES ----------
	say("\n========== F2: HOW OFTEN A TOWN CATCHES ==========")
	say("  _fire_day() rolled on an unburnt town until something lights. The hearths")
	say("  (%s) carry x%.1f the odds, so the answer" % [
		", ".join(GameState.FIRE_HEARTHS), GameState.FIRE_HEARTH_MULT])
	say("  depends on WHICH halls stand, not only how many. 400 trials each.")
	say("  town                                  | mean in-game days to a fire | real hours of play")
	var days_to_fire: Callable = func(names: Array) -> float:
		quiet()
		crew(0)
		stand(names)
		var total := 0.0
		var trials := 400
		for t in range(trials):
			GameState.burning = {}
			var d := 0
			while d < 4000:
				d += 1
				GameState._fire_day()
				if not GameState.burning.is_empty():
					break
			total += float(d)
		return total / float(trials)
	var towns: Array = [
		{"tag": "4 halls, no hearth (under the gate) ", "b": ["Farm", "Bank", "Mine", "School"]},
		{"tag": "6 plain halls, no hearth            ", "b": ["Farm", "Bank", "Mine", "School", "Government", "Hospital"]},
		{"tag": "6 halls, one hearth (the Blacksmith)", "b": ["Farm", "Bank", "Mine", "School", "Government", "Blacksmith"]},
		{"tag": "a full town, every hearth standing  ", "b": GameState.STARTING_BUILDINGS},
	]
	var hamlet_safe := true
	for tw in towns:
		var d2: float = days_to_fire.call(tw["b"])
		if str(tw["tag"]).begins_with("4 halls") and d2 < 3999.0:
			hamlet_safe = false
		say("  %s |  %s | %s" % [str(tw["tag"]),
			"never (4000d+)          " if d2 >= 3999.0 else "%8.1f in-game days   " % d2,
			"never" if d2 >= 3999.0 else "%.1f hours" % (d2 * 10.0 / 60.0)])
	check("F2: a hamlet under the threshold never burns", hamlet_safe)

	# ---------- F3: THE COST OF A TIGHT ROW ----------
	say("\n========== F3: THE COST OF A TIGHT ROW ==========")
	say("  Eight halls chained shoulder to shoulder (each one its neighbour's")
	say("  neighbour), the middle one lit, then _fire_day() rolled until nothing is")
	say("  alight. This is the design's headline claim -- the row that earns most is")
	say("  the row that burns whole -- and the crew is the only thing shortening it.")
	say("  hands | mean days alight | mean halls that ever caught | worst seen")
	var row: Array = ["Farm", "Bank", "Mine", "School", "Government", "Hospital", "Tavern", "Blacksmith"]
	var chain: Dictionary = {}
	for i2 in range(row.size()):
		chain[str(row[i2])] = [
			str(row[i2 - 1]) if i2 > 0 else "",
			str(row[i2 + 1]) if i2 < row.size() - 1 else ""]
	var spread_ever := 0.0
	for hands2 in [0, 1, 2, 4, 8]:
		quiet()
		crew(int(hands2))
		var tot_days := 0.0
		var tot_halls := 0.0
		var worst := 0
		var trials2 := 300
		for t2 in range(trials2):
			stand(row)
			GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES if int(hands2) > 0 else 0
			GameState.building_health["Builderhouse"] = float(GameState.BUILDING_MAX_HEALTH)
			GameState.building_neighbors = chain
			GameState.burning = {str(row[3]): GameState.game_hours}
			var ever: Dictionary = {str(row[3]): true}
			var days := 0
			while days < 200 and not GameState.burning.is_empty():
				days += 1
				GameState._fire_day()
				for b in GameState.burning.keys():
					ever[str(b)] = true
			tot_days += float(days)
			tot_halls += float(ever.size())
			worst = maxi(worst, ever.size())
		var mean_halls: float = tot_halls / float(trials2)
		if int(hands2) == 0:
			spread_ever = mean_halls
		say("   %2d   |      %5.2f       |           %5.2f            |    %d of %d" % [
			int(hands2), tot_days / float(trials2), mean_halls, worst, row.size()])
	check("F3: an unfought fire really does travel the row (adjacency has a downside)",
		spread_ever > 1.0, "%.2f halls per fire" % spread_ever)

	# ---------- F4: THE BURN AND THE REPAIR, IN THE SAME FRAME ----------
	say("\n========== F4: THE BURN AND THE REPAIR, IN THE SAME FRAME ==========")
	say("  Everything above is the crew's WATER. The crew has a SECOND job --")
	say("  _auto_mend_one, which patches the most badly hurt standing hall by %d" % GameState.MEND_PER_PASS)
	say("  health every %.0f real seconds -- and nothing stops it choosing the hall" % GameState.INCOME_INTERVAL_SECONDS)
	say("  that is on fire. Below: one hall lit at half health, driven through WHOLE")
	say("  frames (automation + clock), %.0f in-game hours each." % 6.0)
	say("  hands | burn/hr | end health | net per in-game hour | verdict")
	var start_hp: float = float(GameState.BUILDING_MAX_HEALTH) * 0.5
	var burn_window := 6.0
	var crewed_net := 0.0
	for hands3 in [0, 1, 2, 4, 8]:
		quiet()
		stand(placed, true)
		crew(int(hands3))
		GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES if int(hands3) > 0 else 0
		GameState.building_health["Builderhouse"] = float(GameState.BUILDING_MAX_HEALTH)
		GameState.building_health[burn_hall] = start_hp
		GameState.burning = {burn_hall: GameState.game_hours}
		var fought3: float = clampf(GameState._fire_suppression(), 0.0, 0.9)
		run_frame(burn_window)
		var end_hp: float = float(GameState.building_health.get(burn_hall, -1.0))
		var net: float = (end_hp - start_hp) / burn_window
		if int(hands3) == 1:
			crewed_net = net
		say("   %2d   |  %5.1f  |   %6.1f   |       %+7.2f       | %s" % [
			int(hands3), GameState.FIRE_DAMAGE_PER_HOUR * (1.0 - fought3), end_hp, net,
			"the hall GAINS health while alight" if net > 0.0 else "the fire still costs the town"])
	say("")
	say("  THE FINDING. With a SINGLE hand on the crew the burning hall gains %+.2f" % crewed_net)
	say("  health an in-game hour. The mend is worth %.1f health a real minute against" % [
		float(GameState.MEND_PER_PASS) * 60.0 / GameState.INCOME_INTERVAL_SECONDS])
	say("  a burn of only %.1f, so the repair outruns an UNSUPPRESSED blaze %.1f to one" % [
		GameState.FIRE_DAMAGE_PER_HOUR * GameState.HOURS_PER_SECOND * 60.0,
		(float(GameState.MEND_PER_PASS) * 60.0 / GameState.INCOME_INTERVAL_SECONDS)
			/ (GameState.FIRE_DAMAGE_PER_HOUR * GameState.HOURS_PER_SECOND * 60.0)])
	say("  before a drop of water is thrown. Same shape as the douse-roll bug the")
	say("  clamp already had to fix: a system that switches itself off the moment the")
	say("  crew is staffed. THE FAILING CHECK BELOW IS DELIBERATE -- it IS the")
	say("  finding, and it is why this lives in a tool and not in the suite.")
	check("F4: a fire in a STAFFED town still costs that town health",
		crewed_net < 0.0,
		"one Builderhouse hand turns a blaze into %+.2f health per in-game hour — see QA_FINDINGS.md, 2026-08-06" % crewed_net)

	# ---------- F5: WHAT A SCAR ACTUALLY COSTS ----------
	say("\n========== F5: WHAT A SCAR ACTUALLY COSTS ==========")
	quiet()
	stand(placed, true)
	var whole: float = GameState.building_output_multiplier(burn_hall)
	say("  a whole %s produces x%.3f" % [burn_hall, whole])
	for frac in [0.75, 0.5, 0.25, 0.05]:
		GameState.building_health[burn_hall] = float(GameState.BUILDING_MAX_HEALTH) * float(frac)
		say("    at %3.0f%% health: x%.3f  — %.0f%% of whole (the floor is %.0f%%)" % [
			float(frac) * 100.0, GameState.building_output_multiplier(burn_hall),
			100.0 * GameState.building_output_multiplier(burn_hall) / whole,
			GameState.CONDITION_FLOOR * 100.0])
	GameState.building_health[burn_hall] = float(GameState.BUILDING_MAX_HEALTH)
	say("  and a GUTTED hall costs a whole rebuild stage: %d wood + %d stone, plus" % [
		GameState.REPAIR_STAGE_WOOD, GameState.REPAIR_STAGE_STONE])
	say("  every minute it produces nothing at all while the crew raises it again.")

	GameState.burning = {}
	printerr("\ntool_peril_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
