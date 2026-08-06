extends Node
# THE SICKNESS (dev design 2026-08-06) -- the town's own problem, and the answer
# to "what is there to do once the village runs itself". Everything else the
# village produces, it produces FOR you; this it produces AT you.
#
# Pins the contract: a hamlet never sickens; it spreads HOUSE TO HOUSE by the
# same homes-and-workplaces the auras read, so cottage placement decides how fast;
# the ward's shadow shelters, slows and cures; the Ten and the pledged are never
# taken; and long neglect really can kill -- but slowly enough that coming home
# always saves them.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func soul(id: String) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 3, "role_key": "", "role_title": ""}

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

	var s_roster: Array = GameState.rescued_villagers.duplicate(true)
	var s_sick: Dictionary = GameState.sick.duplicate(true)
	var s_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var s_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var s_ids: Array = GameState.extra_cottage_ids.duplicate()
	var s_pos: Array = GameState.extra_cottage_positions.duplicate()
	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_x: Dictionary = GameState.building_x.duplicate(true)
	var s_plague: Dictionary = GameState.plague_ids.duplicate(true)
	var s_depth: int = GameState.deepest_level_reached
	var s_deaths: int = GameState.run_villager_deaths
	var s_immune: Dictionary = GameState.plague_immune_until.duplicate(true)
	var s_gh: float = GameState.game_hours

	GameState.sick = {}
	GameState.villager_hp = {}
	GameState.building_stage["Hospital"] = 0        # no ward for the early checks

	# ---- a hamlet never sickens ----
	GameState.rescued_villagers = []
	for i in range(4):
		GameState.rescued_villagers.append(soul("h%d" % i))
	GameState._sick_accum = 0.0
	for _d in range(40):
		GameState.tick_sickness(24.0)
	check("a hamlet never sickens — there is nobody to catch it from",
		GameState.sick_count() == 0, "%d ill" % GameState.sick_count())

	# ---- a town does, and it spreads to the NEIGHBOURS ----
	# two clusters: four homes packed together, four far down the road
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	for i2 in range(16):
		var id := "s%d" % i2
		GameState.rescued_villagers.append(soul(id))
		GameState.extra_cottage_ids.append("c%d" % i2)
		# first eight shoulder to shoulder; last eight scattered a long way off
		GameState.extra_cottage_positions.append(6000.0 + float(i2) * 120.0 if i2 < 8
			else 30000.0 + float(i2) * 4000.0)
		GameState.cottage_homes["c%d" % i2] = {"a": id, "b": ""}
	check("everyone has a home to catch it in",
		GameState.villager_home_id("s0") != "" and GameState.villager_home_id("s15") != "")

	# seed it in the packed cluster and let a few nights pass
	GameState.sick = {"s0": GameState.game_hours}
	GameState._sick_accum = 0.0
	for _d2 in range(4):
		# HOLD PATIENT ZERO ILL. This test measures WHERE the sickness travels, not
		# whether one villager happens to shake it off -- and at a 10%-a-day cure over
		# four nights, s0 recovering before infecting anyone made this fail roughly
		# one run in four. That flake had nothing to do with spread. Re-seeding the
		# carrier each night isolates the property actually under test and drops the
		# odds of a false red to about one in a thousand.
		GameState.sick["s0"] = GameState.game_hours
		GameState._sickness_day(false)
	var packed := 0
	var far := 0
	for vid in GameState.sick.keys():
		var n := int(str(vid).substr(1))
		if n < 8: packed += 1
		else: far += 1
	check("it spreads through homes packed together", packed > 1, "%d in the row" % packed)
	# ============ WHERE THEY SLEEP DECIDES IT (dev ruling 2026-08-06) ============
	# The spread used to read home OR workplace, which put everyone rostered to the
	# same hall at DISTANCE ZERO -- so in a staffed town every soul touched every
	# other, and spacing the cottage row 27x further apart changed the contact graph
	# by exactly nothing. Three systems' headers claimed the opposite. This pins the
	# fix: distance is measured between HOMES, and a shared bench is a separate,
	# much weaker vector that must never flatten the map again.
	var near_pair: Dictionary = GameState.find_villager_by_id("s0")
	var far_pair: Dictionary = GameState.find_villager_by_id("s15")
	near_pair["role_key"] = "Farm"
	far_pair["role_key"] = "Farm"          # same bench, homes a very long way apart
	check("two souls at the same bench but far-apart homes do NOT count as neighbours",
		not GameState._lives_touch(near_pair, far_pair, GameState.SICK_SPREAD_RADIUS))
	check("...though sharing that bench is still recognised as its own vector",
		GameState._share_a_workplace(near_pair, far_pair))
	check("...and it is much weaker than living next door",
		GameState.WORKMATE_INFECT_PER_DAY < GameState.SICK_SPREAD_CHANCE_PER_DAY * 0.5,
		"%.3f vs %.3f" % [GameState.WORKMATE_INFECT_PER_DAY, GameState.SICK_SPREAD_CHANCE_PER_DAY])
	var s1v: Dictionary = GameState.find_villager_by_id("s1")
	s1v["role_key"] = ""
	near_pair["role_key"] = ""
	far_pair["role_key"] = ""
	check("neighbours on the same row still touch, employment or not",
		GameState._lives_touch(near_pair, s1v, GameState.SICK_SPREAD_RADIUS))
	check("...and does NOT reach homes far down the road (placement decides)",
		far == 0, "%d caught it across town" % far)

	# ---- the ward's shadow shelters, and cures ----
	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Hospital"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_x["Hospital"] = 6400.0        # right on top of the packed row
	var v0: Dictionary = GameState.find_villager_by_id("s0")
	check("a home in the ward's shadow is recognised", GameState.in_aura("Hospital", v0))

	# ================== TWO STRAINS (dev ruling 2026-08-06) ==================
	# THE ORDINARY ILLNESS CANNOT KILL. The dev's reasoning: when this first appears
	# the player has no staffed ward, no doctors and no leader to answer it with, so
	# a plague that took people then would punish being early rather than pose a
	# problem. Its entire cost is that a sick body stops mending and the town's mood
	# drops. THE PLAGUE is the late-game strain, gated behind PLAGUE_MIN_DEPTH so it
	# only ever arrives once the player holds the tools to fight it.
	GameState.plague_ids = {}
	GameState.sick = {"s0": GameState.game_hours}
	GameState.villager_hp = {"s0": 100.0}
	GameState.tick_sickness(48.0)
	check("the ordinary illness costs no strength at all — two full days of it",
		is_equal_approx(GameState.get_villager_hp("s0"), 100.0), "%.1f" % GameState.get_villager_hp("s0"))
	# ...and it cannot kill even from the brink, which is the whole ruling
	GameState.villager_hp = {"s0": 0.5}
	GameState.sick = {"s0": GameState.game_hours}
	var pop_before: int = GameState.rescued_villagers.size()
	GameState.tick_sickness(240.0)
	check("...and it can NEVER take anyone, even from the brink, even after ten days",
		GameState.rescued_villagers.size() == pop_before,
		"%d -> %d" % [pop_before, GameState.rescued_villagers.size()])

	# but a sick body does not MEND either -- that is the cost, and it has to be real
	GameState.sick = {}
	GameState.plague_ids = {}
	GameState.villager_hp = {"s0": 40.0}
	GameState.tick_morale_effects(6.0)
	var healed: float = GameState.get_villager_hp("s0")
	GameState.sick = {"s0": GameState.game_hours}
	GameState.villager_hp = {"s0": 40.0}
	GameState.tick_morale_effects(6.0)
	var not_healed: float = GameState.get_villager_hp("s0")
	check("a WELL villager mends over six hours", healed > 40.0, "%.1f" % healed)
	check("a SICK one does not — the illness freezes healing (this is the mechanic)",
		is_equal_approx(not_healed, 40.0), "%.1f" % not_healed)

	# and the town feels it: for the ordinary illness the MOOD is the entire cost,
	# so if it did not land in morale the illness would cost the player nothing
	# Read the TARGET, not village_morale_10(): the village figure averages each
	# villager's STORED morale, which only drifts toward its target as the clock
	# ticks, so a freshly-set outbreak would not show there for hours of game time.
	# The target is where the penalty actually lives.
	GameState.sick = {}
	GameState.plague_ids = {}
	var subject: Dictionary = GameState.find_villager_by_id("s0")
	var mood_well: float = GameState.personal_morale_target(subject)
	GameState.sick = {"s0": GameState.game_hours, "s1": GameState.game_hours,
		"s2": GameState.game_hours, "s3": GameState.game_hours}
	var mood_sick: float = GameState.personal_morale_target(subject)
	check("a sick town is a low town", mood_sick < mood_well,
		"well %.2f vs sick %.2f" % [mood_well, mood_sick])
	check("...but never a morale wipe (a rough week must not rot the village)",
		mood_well - mood_sick <= GameState.SICK_MORALE_CAP + 0.001,
		"drop %.2f, cap %.2f" % [mood_well - mood_sick, GameState.SICK_MORALE_CAP])
	# and the PLAGUE weighs heavier on the town than the ordinary illness does
	GameState.plague_ids = {"s0": true, "s1": true, "s2": true, "s3": true}
	var mood_plague: float = GameState.personal_morale_target(subject)
	check("a plagued town is lower still than a merely sick one",
		mood_plague < mood_sick, "sick %.2f vs plagued %.2f" % [mood_sick, mood_plague])
	GameState.plague_ids = {}

	# ---- THE PLAGUE: gated to the mid game, and it does have teeth ----
	GameState.deepest_level_reached = GameState.PLAGUE_MIN_DEPTH - 1
	check("below the gate the virulent strain does not exist", not GameState.plague_is_possible())
	GameState.deepest_level_reached = GameState.PLAGUE_MIN_DEPTH
	check("...and once you are deep enough, it can", GameState.plague_is_possible())

	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_x["Hospital"] = 6400.0        # right on top of the packed row
	GameState.sick = {"s0": GameState.game_hours}
	GameState.plague_ids = {"s0": true}
	GameState.villager_hp = {"s0": 100.0}
	GameState.tick_sickness(10.0)
	var hp_warded: float = GameState.get_villager_hp("s0")
	GameState.building_x["Hospital"] = 90000.0       # move the ward far away
	GameState.sick = {"s0": GameState.game_hours}
	GameState.plague_ids = {"s0": true}
	GameState.villager_hp = {"s0": 100.0}
	GameState.tick_sickness(10.0)
	var hp_bare: float = GameState.get_villager_hp("s0")
	check("the plague DOES cost strength", hp_bare < 100.0, "%.1f" % hp_bare)
	check("the ward's shadow costs the plagued far less",
		hp_warded > hp_bare, "warded %.1f vs bare %.1f" % [hp_warded, hp_bare])
	check("...but it still costs them something", hp_warded < 100.0, "%.1f" % hp_warded)

	# ---- long neglect kills — but ONLY the plague ----
	GameState.building_stage["Hospital"] = 0
	GameState.rescued_villagers = [soul("doomed")]
	for i3 in range(14):
		GameState.rescued_villagers.append(soul("bystander%d" % i3))
	GameState.sick = {"doomed": GameState.game_hours}
	GameState.plague_ids = {"doomed": true}
	GameState.villager_hp = {"doomed": 3.0}
	var before: int = GameState.rescued_villagers.size()
	# ZERO THE DAY-CLOCK FIRST. The cure roll now runs BEFORE the reaper (so nobody
	# is buried without the recovery chance that same chunk owed them), which means
	# a day boundary landing inside these six hours gives "doomed" a 10% escape and
	# fails this check at random. This section is about the drain, not the dice.
	GameState._sick_accum = 0.0
	GameState.tick_sickness(6.0)
	check("neglected long enough, the PLAGUE takes them",
		GameState.rescued_villagers.size() < before,
		"%d -> %d" % [before, GameState.rescued_villagers.size()])
	check("...and they are no longer counted as ill", not GameState.villager_is_sick("doomed"))
	check("...nor as carrying the strain", not GameState.villager_has_plague("doomed"))

	# ONE funeral per body. remove_villager_by_id already registers the death; a
	# second register_villager_deaths call here charged the town twice -- doubling
	# the morale shock, double-logging it, and arming the Grief-Eater a body early.
	GameState.rescued_villagers = [soul("only")]
	for i4 in range(14):
		GameState.rescued_villagers.append(soul("witness%d" % i4))
	GameState.run_villager_deaths = 0
	GameState._sick_accum = 0.0        # same reason: no cure roll inside this window
	GameState.sick = {"only": GameState.game_hours}
	GameState.plague_ids = {"only": true}
	GameState.villager_hp = {"only": 0.5}
	GameState.tick_sickness(6.0)
	check("a plague death is one funeral, not two",
		GameState.run_villager_deaths == 1, str(GameState.run_villager_deaths))

	# ============ IMMUNITY: AN OUTBREAK MUST BE ABLE TO END ============
	# Balance measured a single plague case into a cared-for town of eighty and it
	# killed 73 of them; a staffed ward on the cottage row still lost 55. The cause
	# was not the drain or the spread -- there was no such thing as having HAD it, so
	# a cured villager was re-infected that same night and re-rolled until a roll
	# killed them. This pins the fix, and the property that matters most: the
	# outbreak RUNS OUT OF PEOPLE and stops.
	GameState.plague_immune_until = {}
	GameState.sick = {}
	GameState.plague_ids = {}
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	for i5 in range(20):
		var iid := "im%d" % i5
		GameState.rescued_villagers.append(soul(iid))
		GameState.extra_cottage_ids.append("ic%d" % i5)
		GameState.extra_cottage_positions.append(6000.0 + float(i5) * 100.0)
		GameState.cottage_homes["ic%d" % i5] = {"a": iid, "b": ""}
		GameState.villager_hp[iid] = 100.0
	var recovered: Dictionary = GameState.find_villager_by_id("im0")
	check("a fresh villager is not immune", not GameState.villager_is_immune("im0"))
	GameState._grant_immunity("im0")
	check("...but is the moment they throw it off", GameState.villager_is_immune("im0"))
	check("...so the sickness cannot take them again", not GameState._can_sicken(recovered))
	GameState.game_hours += GameState.IMMUNITY_DAYS * 24.0 + 1.0
	check("...and it wears off, so a later outbreak still finds them",
		not GameState.villager_is_immune("im0") and GameState._can_sicken(recovered))

	# THE PROPERTY THAT MAKES IT SAFE: with immunity the pool shrinks with every
	# recovery, so the sickness runs out of fuel. Without it the town never clears.
	# Run the SAME outbreak twice: once as shipped, once with immunity wiped every
	# night. The contrast is the whole proof -- an "it burns out" assertion on its own
	# would pass for the wrong reason the moment the last carrier happened to recover,
	# and my first version of this check did exactly that, failing about one run in
	# four on "it did not end instantly". That is a coin flip wearing an assertion's
	# clothes. This is the positive control instead: without immunity it must NOT end.
	var ended_with := -1
	var ended_without := -1
	for pass_i in range(2):
		var immune_on: bool = pass_i == 0
		GameState.plague_immune_until = {}
		GameState.sick = {}
		GameState.plague_ids = {}
		GameState._sick_accum = 0.0
		for seed_i in range(4):                       # several carriers: no single roll ends it
			GameState.sick["im%d" % seed_i] = GameState.game_hours
		for day in range(300):
			GameState._sickness_day(false)
			if not immune_on:
				GameState.plague_immune_until = {}    # nobody ever gains immunity
			for hid2 in GameState.sick.keys():
				GameState.villager_hp[str(hid2)] = 100.0   # nobody dies; measure the BURN-OUT
			if GameState.sick.is_empty():
				if immune_on:
					ended_with = day
				else:
					ended_without = day
				break
	check("an outbreak BURNS OUT instead of running forever", ended_with >= 0,
		"still going after 300 days")
	check("...BECAUSE of immunity — strip it and the same outbreak never clears",
		ended_without < 0, "cleared on day %d without immunity" % ended_without)

	# ---- but never a legend ----
	GameState.rescued_villagers = [{"id": "legend", "name": "Maera", "sex": "Female",
		"is_kid": false, "stat_name": "", "stat_value": 9, "role_key": "", "role_title": "",
		"unbreakable": true}]
	GameState.sick = {"legend": GameState.game_hours}
	GameState.villager_hp = {"legend": 1.0}
	GameState.tick_sickness(24.0)
	check("the Ten sicken to the brink and no further",
		GameState.rescued_villagers.size() == 1 and GameState.get_villager_hp("legend") > 0.0,
		"hp=%.1f" % GameState.get_villager_hp("legend"))
	var lv: Dictionary = GameState.find_villager_by_id("legend")
	check("...and a legend can never be picked as patient zero", not GameState._can_sicken(lv))

	# ---- it is written down, and it is LOUD ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("who is ill survives the save", gs.contains('"sick": sick'))
	check("...and which of them carry the virulent strain", gs.contains('"plague_ids": plague_ids'))
	check("the day-clock travels with them (else every Continue defers the cure roll)",
		gs.contains('"sick_accum": _sick_accum') and gs.contains('"fire_accum": _fire_accum'))
	check("an outbreak pierces the away-fog (you must be able to come home)",
		gs.split("func _begin_outbreak(")[1].split("\nfunc ")[0].contains("notify_urgent"))
	var mm := FileAccess.open("res://morale_meter.gd", FileAccess.READ).get_as_text()
	check("the glance panel shows the emergency", mm.contains("SICK"))
	# ...and tells the two strains APART. The model has weighed them differently since
	# the split, but the panel showed one number -- so three colds and three plague
	# cases read identically, and the only strain worth coming home for was the
	# invisible one. villager_has_plague/plague_count existed and nothing displayed it.
	check("...and a PLAGUE reads differently from a cold",
		mm.contains("PLAGUE") and mm.contains("plague_count()"))
	# the harness must not inherit this machine's real high-water mark, either:
	# plague_is_possible() is a depth check, and deepest_level.dat was being read into
	# every test process -- permanently true here, permanently false on a fresh
	# checkout, so the plague was silently on for one person and off for everyone else
	check("the deepest-level record is sidecarred under test, like every other save",
		gs.contains("func deepest_level_path()") and gs.contains("deepest_level_test.dat"))
	check("sickness is NOT corruption — it has its own ledger",
		gs.contains("func tick_sickness") and gs.contains("func tick_rot"))

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.sick = s_sick
	GameState.villager_hp = s_hp
	GameState.cottage_homes = s_homes
	GameState.extra_cottage_ids = s_ids
	GameState.extra_cottage_positions = s_pos
	GameState.extra_cottages = s_ids.size()
	GameState.building_stage = s_stage
	GameState.building_x = s_x
	GameState.plague_ids = s_plague
	GameState.deepest_level_reached = s_depth
	GameState.run_villager_deaths = s_deaths
	GameState.plague_immune_until = s_immune
	GameState.game_hours = s_gh

	printerr("test_sickness : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
