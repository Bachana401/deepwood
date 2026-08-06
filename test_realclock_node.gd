extends Node
# THE REAL CLOCK (QA, 2026-08-06) -- the gap this suite has been blind to.
#
# Every village system is tested by calling ITS OWN sub-tick directly with
# hand-seeded state: tick_sickness(6.0), tick_patrols(24.0), tick_mine_yield(240.5).
# Nothing tested tick_village_clock(), which is what actually runs in play: it
# calls ~25 sub-ticks in a fixed order, every frame, with hours_passed around
# 0.0025 (HOURS_PER_SECOND is 0.04, so an in-game hour is 25 real seconds).
#
# Two things only the real clock can show:
#   1. ORDER. A later sub-tick can undo an earlier one inside the same pass.
#      This is not hypothetical -- see THE SICKNESS block below.
#   2. WIRING. A sub-tick that works perfectly when called by hand proves nothing
#      about whether the clock still calls it.
#
# So this test drives GameState.tick_village_clock() the way _process does --
# small steps, in order, nothing hand-fed in between -- and asserts the outcomes
# the direct-call tests claim. Where the two disagree, the real clock wins,
# because the real clock is the game.
#
# The steps are 0.25 in-game hours (about 6 real seconds of play each), and every
# window is kept under 24 hours on purpose: the daily rolls (cure, spread, a new
# outbreak) are random, and a test that flakes is a test nobody believes.
#
# 2026-08-06, second pass: THE FIRE. tick_fire eats building health in the same
# pass the Builderhouse crew repairs in -- the same shape as the sickness bug
# above, one sub-tick taking what another gives back, each green in its own test.
# Worse, the two halves are not even in the same function: the burn is inside
# tick_village_clock() and the repair is inside apply_leadership_automation(),
# which _process calls on a SEPARATE real-time cadence. No test in this suite had
# ever run both, so run_clock_full() below drives the whole frame.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

const STEP := 0.25          # in-game hours per tick

func soul(id: String, role := "") -> Dictionary:
	return {"id": id, "name": id.capitalize(), "sex": "Male", "is_kid": false,
		"stat_name": "Farm" if role == "" else role, "stat_value": 3,
		"role_key": role, "role_title": role}

# Run the REAL clock for `hours` in-game hours, exactly as _process would.
func run_clock(hours: float) -> void:
	GameState.village_last_hours_elapsed = GameState.game_hours
	var steps := int(round(hours / STEP))
	for i in range(steps):
		GameState.game_hours += STEP
		GameState.tick_village_clock()

# ...and the WHOLE frame, which is more than the clock. _process runs
# apply_leadership_automation() on its own REAL-TIME cadence
# (INCOME_INTERVAL_SECONDS, in real seconds, not in-game hours) and only then
# calls tick_village_clock(). Every village automation the leaders and crews run
# lives in the first half; every hourly cost the town pays lives in the second.
# The Builderhouse's repair and the fire's burn are one of each, so they can only
# ever meet here.
#
# generate_passive_income() is deliberately left out of this loop: it moves gold,
# never building health, and a treasury quietly growing mid-measurement only makes
# the log harder to read.
var _income_accum := 0.0

func run_clock_full(hours: float) -> void:
	GameState.village_last_hours_elapsed = GameState.game_hours
	_income_accum = 0.0
	var steps := int(round(hours / STEP))
	var real_seconds_per_step: float = STEP / GameState.HOURS_PER_SECOND
	for i in range(steps):
		GameState.game_hours += STEP
		_income_accum += real_seconds_per_step
		if _income_accum >= GameState.INCOME_INTERVAL_SECONDS:
			_income_accum -= GameState.INCOME_INTERVAL_SECONDS
			GameState.apply_leadership_automation()
		GameState.tick_village_clock()

# Every hall the village actually PLACED (one with a node in the scene). Both
# auto_repair_one and _auto_mend_one skip a building that has no node, so a
# repair test that seeds only GameState measures a crew that was never allowed to
# lift a hammer -- and would report a clean pass for it.
func placed_halls() -> Array:
	var out: Array = []
	for bn in GameState.STARTING_BUILDINGS:
		if get_tree().get_first_node_in_group("building_role_" + str(bn)) != null:
			out.append(str(bn))
	return out

# Stand every placed hall up WHOLE, and tell its node so. building.gd caches
# build_stage and health at _ready, and sync_health_from_state() -- the resync the
# hourly burn leans on -- returns early while that cached stage still reads as a
# ruin. Seeding GameState alone would leave the node deaf and the burn invisible.
# Health matters as much as stage here: reset_for_new_game writes 0 into
# building_health for every hall, and a hall standing at 0 is the crew's mend
# target forever, which would steal the repair this file is trying to watch.
func raise_placed() -> Array:
	var halls: Array = placed_halls()
	for bn in GameState.STARTING_BUILDINGS:
		GameState.building_stage[bn] = 0
	for h in halls:
		GameState.building_stage[str(h)] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[str(h)] = float(GameState.BUILDING_MAX_HEALTH)
		var node: Node = get_tree().get_first_node_in_group("building_role_" + str(h))
		if node != null and node.has_method("sync_from_state"):
			node.call("sync_from_state")
	return halls

# A town that is fed, unbesieged and not in despair -- so anything that happens
# to a villager's body in the window below came from the system under test.
# The siege clock is pushed past the horizon on purpose: a raid inside a
# measurement window razes buildings and kills people, and a wiring test that
# fails because a wave happened to land is a test nobody will trust.
func quiet_town(n: int) -> void:
	GameState.rescued_villagers = []
	for i in range(n):
		GameState.rescued_villagers.append(soul("rc%d" % i))
	GameState.villager_hp = {}
	GameState.sick = {}
	GameState.plague_ids = {}
	GameState._sick_accum = 0.0
	GameState.burning = {}
	# the fire's DAY accumulator is a member and survives a reset of `burning`:
	# leave it where the last block left it and a 24h boundary can land inside a
	# measurement window, rolling a blaze out (or into a neighbour) mid-reading.
	GameState._fire_accum = 0.0
	GameState.village_food = GameState.food_capacity()
	GameState.food_empty_hours = 0.0
	GameState.low_morale_hours = 0.0
	GameState.hours_until_next_siege = 100000.0
	GameState.live_siege_active = false
	# PAYDAY, pinned. wage_accum_hours is a member that survives every reset here,
	# so a payroll left part-counted by an earlier block lands inside a later
	# measurement window -- and an unpaid worker WALKS OUT mid-window. A crew that
	# quits looks exactly like a crew that never worked, and the difference is
	# whichever block ran first. Fill the town's own purse and start the count at
	# zero, so nothing below is secretly a wage test.
	GameState.wage_accum_hours = 0.0
	GameState.village_treasury = 1000000
	GameState.building_stage["Hospital"] = 0

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
	var s_plague: Dictionary = GameState.plague_ids.duplicate(true)
	var s_burn: Dictionary = GameState.burning.duplicate(true)
	var s_hp: Dictionary = GameState.villager_hp.duplicate(true)
	var s_stage: Dictionary = GameState.building_stage.duplicate(true)
	var s_x: Dictionary = GameState.building_x.duplicate(true)
	var s_store: Dictionary = GameState.village_stockpile.duplicate(true)
	var s_cleared: Dictionary = GameState.floors_cleared.duplicate(true)
	var s_posts: Dictionary = GameState.patrol_posts.duplicate(true)
	var s_creep: Dictionary = GameState.block_creep.duplicate(true)
	var s_food: float = GameState.village_food
	var s_empty: float = GameState.food_empty_hours
	var s_health: Dictionary = GameState.building_health.duplicate(true)
	var s_homes: Dictionary = GameState.cottage_homes.duplicate(true)
	var s_ids: Array = GameState.extra_cottage_ids.duplicate()
	var s_pos: Array = GameState.extra_cottage_positions.duplicate()
	var s_siege: float = GameState.hours_until_next_siege
	var s_fire_accum: float = GameState._fire_accum
	var s_wage: float = GameState.wage_accum_hours
	var s_treasury: int = GameState.village_treasury
	var s_gold: int = p.currency

	# =====================================================================
	# THE SICKNESS, through the clock that actually runs it
	# ---------------------------------------------------------------------
	# This block is the reason the file exists. tick_sickness and the passive HP
	# regen live in DIFFERENT sub-ticks of the same pass -- tick_sickness at the
	# top, tick_morale_effects further down -- so the interaction between them is
	# invisible to any test that calls either one by hand. It hid a severe bug:
	# the regen had no exemption for the sick and comfortably outran the drain, so
	# a sick villager gained 0.6 HP an hour and the whole system could never take a
	# single life. Measured then: 50.00 -> 54.80 over eight in-game hours, and
	# 50.00 -> 85.36 inside the ward's aura.
	#
	# The two-strain design that replaced it is pinned below, and every assertion
	# is deliberately one the direct-call test cannot make:
	#   ORDINARY illness carries no drain at all. Its entire cost is that a sick
	#   body STOPS MENDING -- which is a fact about tick_morale_effects, reached
	#   only through the clock -- and that the town's mood sours. It must never
	#   take anyone.
	#   THE PLAGUE drains PLAGUE_DRAIN_PER_HOUR and can. The ward softens it.
	# =====================================================================

	# ---- an ordinary illness stops the mending, and costs nothing else ----
	quiet_town(14)
	GameState.sick = {"rc0": GameState.game_hours}
	GameState.plague_ids = {}
	GameState.villager_hp = {"rc0": 50.0}
	var before_hp: float = GameState.get_villager_hp("rc0")
	run_clock(8.0)
	var after_hp: float = GameState.get_villager_hp("rc0")
	check("an ordinary illness STOPS the mending on the real clock (a sick body does not heal itself)",
		is_equal_approx(after_hp, before_hp),
		"%.2f -> %.2f over 8 in-game hours (regen would give +%.1f, a drain would take some)"
			% [before_hp, after_hp, GameState.DESPAIR_HP_REGEN_PER_HOUR * 8.0])

	# ...and the control that proves the line above is the EXEMPTION and not a
	# regen that quietly stopped working for everyone.
	quiet_town(14)
	GameState.villager_hp = {"rc0": 50.0}
	run_clock(8.0)
	check("(control) a WOUNDED but healthy villager still mends on the real clock",
		GameState.get_villager_hp("rc0") > 50.0, "%.2f" % GameState.get_villager_hp("rc0"))

	# ...and per the dev's ruling, an ordinary illness must never take anyone --
	# even one already at the brink, left there for a full day.
	quiet_town(14)
	GameState.sick = {"rc0": GameState.game_hours}
	GameState.plague_ids = {}
	GameState.villager_hp = {"rc0": 1.0}
	run_clock(20.0)
	check("an ordinary illness never takes anyone, however long it is left",
		not GameState.find_villager_by_id("rc0").is_empty(),
		"taken at 1 HP by a common cold")

	# ---- the PLAGUE is the strain with teeth, and the clock must deliver it ----
	# Every window here stays under 24 in-game hours on purpose: _sickness_day rolls
	# the cure BEFORE the reaper now, so a day boundary inside the window could
	# rescue the villager this test expects to lose and turn it into a coin flip.
	quiet_town(14)
	GameState.sick = {"rc0": GameState.game_hours}
	GameState.plague_ids = {"rc0": true}
	GameState.villager_hp = {"rc0": 50.0}
	run_clock(8.0)
	var plague_hp: float = GameState.get_villager_hp("rc0")
	check("the PLAGUE really does cost strength on the real clock",
		plague_hp < 50.0 - GameState.PLAGUE_DRAIN_PER_HOUR * 8.0 * 0.9,
		"%.2f after 8h; %.1f/hr should take about %.1f"
			% [plague_hp, GameState.PLAGUE_DRAIN_PER_HOUR, GameState.PLAGUE_DRAIN_PER_HOUR * 8.0])

	# neglected long enough, it finishes them -- ON THE REAL CLOCK. At
	# PLAGUE_DRAIN_PER_HOUR a villager at 3 HP has ~5 hours left; 8 is past that
	# and still inside one day.
	quiet_town(14)
	GameState.sick = {"rc0": GameState.game_hours}
	GameState.plague_ids = {"rc0": true}
	GameState.villager_hp = {"rc0": 3.0}
	run_clock(8.0)
	check("neglected long enough, the plague really can take them ON THE REAL CLOCK",
		GameState.find_villager_by_id("rc0").is_empty(),
		"still alive at %.2f HP after 8 in-game hours at 3 HP" % GameState.get_villager_hp("rc0"))

	# the ward is supposed to make it cost LESS, not cost nothing. Before the fix
	# the aura's AURA_WARD_REGEN stacked on the passive trickle and a plague victim
	# standing in the Hospital's shadow HEALED faster than the plague hurt.
	quiet_town(14)
	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Hospital"] = GameState.BUILDING_MAX_HEALTH
	GameState.building_x["Hospital"] = 6400.0
	GameState.extra_cottage_ids = ["rcc0"]
	GameState.extra_cottage_positions = [6400.0]
	GameState.cottage_homes = {"rcc0": {"a": "rc0", "b": ""}}
	GameState.sick = {"rc0": GameState.game_hours}
	GameState.plague_ids = {"rc0": true}
	GameState.villager_hp = {"rc0": 50.0}
	check("the villager really is inside the ward's shadow (or the next check proves nothing)",
		GameState.in_aura("Hospital", GameState.find_villager_by_id("rc0")))
	run_clock(8.0)
	var ward_hp: float = GameState.get_villager_hp("rc0")
	check("...the ward's shadow SOFTENS the plague without curing it outright",
		ward_hp < 50.0 and ward_hp > plague_hp,
		"warded %.2f vs bare %.2f over the same 8 hours" % [ward_hp, plague_hp])
	GameState.building_stage["Hospital"] = 0
	GameState.plague_ids = {}

	# =====================================================================
	# WIRING: a sub-tick the clock has stopped calling would still pass its own
	# test. These prove the clock is still the thing that drives them.
	# =====================================================================

	# ---- the patrols pay the town through the real clock ----
	quiet_town(3)
	for i2 in range(3):
		GameState.rescued_villagers[i2]["stat_name"] = "Warrior"
		GameState.rescued_villagers[i2]["role_key"] = "Barracks"
		GameState.rescued_villagers[i2]["role_title"] = "Warrior"
	GameState.building_stage["Mine"] = 0        # so the only haul below is the patrol's
	GameState.floors_cleared = {}
	for lv in range(1, GameState.PATROL_BLOCK_SIZE + 1):
		GameState.floors_cleared[str(lv)] = true
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState.post_patrol(1, 3)
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._patrol_accum = 0.0
	run_clock(25.0)                              # one full watch-cycle (24h) plus slack
	var hauled: int = int(GameState.village_stockpile.get("wood", 0)) \
		+ int(GameState.village_stockpile.get("stone", 0)) \
		+ int(GameState.village_stockpile.get("iron_shard", 0))
	check("a posted patrol sends material up through the REAL clock (the clock still calls tick_patrols)",
		hauled > 0, str(GameState.village_stockpile))

	# ---- an unheld stretch really does sour on the real clock ----
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	run_clock(10.0)
	check("an unheld stretch sours on the real clock too", GameState.block_creep_of(1) > 0.0,
		"%.4f" % GameState.block_creep_of(1))

	# ---- the mine hauls through the real clock ----
	quiet_town(1)
	GameState.rescued_villagers = [soul("rc_mine", "Mine")]
	GameState.building_stage["Mine"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Mine"] = GameState.BUILDING_MAX_HEALTH
	GameState.patrol_posts = {}
	GameState.floors_cleared = {}
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState._store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	GameState._mine_accum = 0.0
	run_clock(25.0)                              # one full seam cycle (24h) plus slack
	check("a staffed Mine's day-cycle completes on the REAL clock, not only when tick_mine_yield is called by hand",
		int(GameState.village_stockpile.get("stone", 0)) > 0, str(GameState.village_stockpile))

	# =====================================================================
	# THE FIRE, through the clock that actually runs it
	# ---------------------------------------------------------------------
	# test_fire_node.gd calls tick_fire(4.0) by hand and proves the burn, the
	# spread, the hearth weighting and the gutting. Not one of those readings can
	# see the thing that matters most in play: WHAT ELSE IS TOUCHING THAT HALL IN
	# THE SAME FRAME. The Builderhouse crew's _auto_mend_one writes the same
	# dictionary the fire is eating, on a different schedule, out of a different
	# entry point -- so "the fire damages" and "the crew repairs" can both be true,
	# both be green, and together add up to a fire that costs a staffed town
	# nothing at all. That is exactly how the sickness bug hid, one screen up.
	#
	# Every negative below carries a positive control, because "the number did not
	# move" is also what a sub-tick the clock stopped calling looks like.
	# =====================================================================
	var placed: Array = placed_halls()
	var fire_halls: Array = []
	for ph in placed:
		if str(ph) != "Builderhouse":
			fire_halls.append(str(ph))
	check("the village stands at least two halls with real nodes to burn (or every fire check below is vacuous)",
		fire_halls.size() >= 2, "placed: %s" % str(placed))
	var hall: String = str(fire_halls[0]) if fire_halls.size() > 0 else "Farm"
	var spare: String = str(fire_halls[1]) if fire_halls.size() > 1 else "Tavern"
	var burn_hours := 6.0        # well under 24, so no daily roll lands mid-window

	# ---- a hall alight really burns on the real clock, and nothing heals it back ----
	quiet_town(0)
	raise_placed()
	GameState.building_stage["Builderhouse"] = 0     # nobody is fighting this one
	GameState.rescued_villagers = []
	GameState._fire_accum = 0.0
	GameState.burning = {hall: GameState.game_hours}
	run_clock(burn_hours)
	var lone_hp: float = float(GameState.building_health.get(hall, -1.0))
	var expect_hp: float = float(GameState.BUILDING_MAX_HEALTH) - GameState.FIRE_DAMAGE_PER_HOUR * burn_hours
	check("a hall alight really loses health across REAL clock steps -- and nothing later in the same pass hands it back",
		absf(lone_hp - expect_hp) < 1.0,
		"%s at %.1f after %.0fh; %.0f/hr from %d should leave %.1f"
			% [hall, lone_hp, burn_hours, GameState.FIRE_DAMAGE_PER_HOUR, GameState.BUILDING_MAX_HEALTH, expect_hp])
	check("(control) the hall next door, not alight, is untouched over the very same window",
		is_equal_approx(float(GameState.building_health.get(spare, -1.0)), float(GameState.BUILDING_MAX_HEALTH)),
		"%s at %.1f" % [spare, float(GameState.building_health.get(spare, -1.0))])

	# the live node is the half that was missed once already: building.gd caches its
	# health at _ready and nothing re-reads it, so a burn written only into GameState
	# left the bar frozen and the next hit wrote the stale number back over the blaze.
	var hall_node: Node = get_tree().get_first_node_in_group("building_role_" + hall)
	check("...and the live node heard about it WHILE it burned, not only when the hall finally fell",
		hall_node != null and absf(float(hall_node.get("health")) - lone_hp) <= 1.0,
		"node %s vs state %.1f" % [str(hall_node.get("health")) if hall_node != null else "<no node>", lone_hp])

	# the DAY half of tick_fire rides the same accumulator. If it ever counted calls
	# instead of hours, a blaze would roll 60 spread-and-douse checks a second.
	check("the fire's daily roll counts in-game HOURS, not ticks",
		absf(GameState._fire_accum - burn_hours) < 0.001,
		"%d quarter-hour steps advanced the day counter to %.3f, not %.1f"
			% [int(burn_hours / STEP), GameState._fire_accum, burn_hours])

	# ---- a blaze bills by the hour, not by the tick ----
	GameState.building_health[hall] = float(GameState.BUILDING_MAX_HEALTH)
	GameState._fire_accum = 0.0
	GameState.burning = {hall: GameState.game_hours}
	GameState.village_last_hours_elapsed = GameState.game_hours
	for i4 in range(40):
		GameState.tick_village_clock()               # 40 ticks, zero in-game time
	check("a blaze bills by the HOUR: 40 ticks with no time in them cost the hall nothing",
		is_equal_approx(float(GameState.building_health.get(hall, -1.0)), float(GameState.BUILDING_MAX_HEALTH)),
		"%.2f" % float(GameState.building_health.get(hall, -1.0)))
	GameState.game_hours += STEP
	GameState.tick_village_clock()
	check("(control) ...and one step WITH time in it does cost it",
		float(GameState.building_health.get(hall, -1.0)) < float(GameState.BUILDING_MAX_HEALTH),
		"%.2f" % float(GameState.building_health.get(hall, -1.0)))

	# ---- gutting, driven by the clock rather than by a hand-called tick_fire ----
	quiet_town(0)
	raise_placed()
	GameState.building_stage["Builderhouse"] = 0
	GameState.rescued_villagers = []
	GameState._fire_accum = 0.0
	GameState.building_health[hall] = GameState.FIRE_DAMAGE_PER_HOUR * 1.5   # ~90 minutes left
	GameState.building_health[spare] = GameState.FIRE_DAMAGE_PER_HOUR * 1.5
	GameState.burning = {hall: GameState.game_hours}
	run_clock(3.0)
	check("a hall left alight is GUTTED by the clock -- knocked back down its stages, never lost for good",
		int(GameState.building_stage.get(hall, -1)) < GameState.TOTAL_BUILD_STAGES \
			and int(GameState.building_stage.get(hall, -1)) >= 0,
		"stage=%d" % int(GameState.building_stage.get(hall, -1)))
	check("...and the blaze goes out once there is nothing left of it to eat",
		not GameState.building_is_burning(hall))
	check("(control) the hall next door, hurt exactly as badly but NOT alight, still stands",
		int(GameState.building_stage.get(spare, -1)) == GameState.TOTAL_BUILD_STAGES,
		"stage=%d" % int(GameState.building_stage.get(spare, -1)))

	# =====================================================================
	# THE COMPOSITION -- the reading only the whole frame can take.
	# The same wound, twice: once with nobody to fight it, once with a full
	# Builderhouse crew, over identical windows. The crew's repair is reached the
	# way _process reaches it (apply_leadership_automation, on its own real-time
	# cadence), never by calling auto_repair_one by hand.
	# The hall starts at HALF health on purpose: at full there is no headroom to
	# mend into, and a repair that outruns the blaze would read as a quiet fire.
	# =====================================================================
	var start_hp: float = float(GameState.BUILDING_MAX_HEALTH) * 0.5

	quiet_town(0)
	raise_placed()
	GameState.building_stage["Builderhouse"] = 0
	GameState.rescued_villagers = []
	GameState.village_stockpile = {"wood": 999, "stone": 999, "iron_shard": 0}
	GameState._fire_accum = 0.0
	GameState.building_health[hall] = start_hp
	GameState.burning = {hall: GameState.game_hours}
	run_clock_full(burn_hours)
	var unattended: float = float(GameState.building_health.get(hall, -1.0))

	quiet_town(4)
	for i5 in range(GameState.rescued_villagers.size()):
		GameState.rescued_villagers[i5]["role_key"] = "Builderhouse"
		GameState.rescued_villagers[i5]["role_title"] = "Builderhouse"
	raise_placed()
	GameState.building_stage["Builderhouse"] = GameState.TOTAL_BUILD_STAGES
	GameState.building_health["Builderhouse"] = float(GameState.BUILDING_MAX_HEALTH)
	GameState.village_stockpile = {"wood": 999, "stone": 999, "iron_shard": 0}
	GameState._fire_accum = 0.0
	GameState.building_health[hall] = start_hp
	GameState.burning = {hall: GameState.game_hours}
	run_clock_full(burn_hours)
	var crewed: float = float(GameState.building_health.get(hall, -1.0))
	var net_per_hour: float = (crewed - start_hp) / burn_hours

	# what the crew's WATER alone would have left, if it never touched a hammer --
	# the line the repair has to be measured against, not the unsuppressed burn
	var fought: float = clampf(GameState._fire_suppression(), 0.0, 0.9)
	var water_only: float = start_hp - GameState.FIRE_DAMAGE_PER_HOUR * burn_hours * (1.0 - fought)

	check("(control) the unattended arm burned at exactly the rate it should have, so the pair below compares what it claims to",
		absf(unattended - (start_hp - GameState.FIRE_DAMAGE_PER_HOUR * burn_hours)) < 1.0,
		"unattended %.1f, expected %.1f" % [unattended,
			start_hp - GameState.FIRE_DAMAGE_PER_HOUR * burn_hours])
	check("the crew and the fire really do compose on the real clock: the crewed hall ends the window better off than the unattended one",
		crewed > unattended + 1.0,
		"crewed %.1f vs unattended %.1f, both from %.1f over %.0fh"
			% [crewed, unattended, start_hp, burn_hours])

	# Does the mend have ANY notion that the hall it is patching is on fire? Probed
	# at RUNTIME -- seed a burning wound, call the mend once, look at the number --
	# rather than sniffed out of the source text, so it stays true after a rename.
	GameState.building_health[hall] = start_hp
	GameState.burning = {hall: GameState.game_hours}
	GameState.village_stockpile = {"wood": 999, "stone": 999, "iron_shard": 0}
	GameState._auto_mend_one()
	var mends_the_burning: bool = float(GameState.building_health.get(hall, -1.0)) > start_hp

	# the reading itself, kept in the log whether it passes or fails -- a measured
	# number is the only part of this the lead can act on
	printerr("      MEASURED  %s alight %.0f in-game hours from %.1f HP:  unattended %.1f | crewed %.1f | water alone would leave %.1f | net %+.2f HP per in-game hour"
		% [hall, burn_hours, start_hp, unattended, crewed, water_only, net_per_hour])

	if mends_the_burning:
		# ⚠ PINNED FINDING, not an endorsement -- QA_FINDINGS.md, 2026-08-06 §1.
		# _auto_mend_one has no burning-guard, so the Builderhouse crew patches the
		# very hall it is fighting a fire in, at MEND_PER_PASS every income tick,
		# while the blaze takes FIRE_DAMAGE_PER_HOUR an in-game hour. The repair is
		# roughly twice the burn even before suppression, so a staffed town's fire
		# is a net HEAL and the whole system is off the moment the crew is seated --
		# the same failure the douse-roll clamp already had to fix once.
		# WHEN THE GUARD LANDS THIS CHECK FAILS. That is the signal: delete this
		# branch, keep the else-branch below, which is the assertion that should hold.
		check("⚠ FINDING PINNED: a crewed town's fire is a net HEAL — the Builderhouse mends the very hall it is burning",
			crewed > start_hp,
			"%+.1f HP per in-game hour while alight (%.1f -> %.1f); its water alone would have left %.1f. Mend %d per pass every %.0f real seconds vs a burn of %.0f/hr"
				% [net_per_hour, start_hp, crewed, water_only, GameState.MEND_PER_PASS,
					GameState.INCOME_INTERVAL_SECONDS, GameState.FIRE_DAMAGE_PER_HOUR])
	else:
		check("the crew cannot mend a hall while it is actively alight, so a fire still costs a staffed town health",
			crewed < start_hp,
			"%+.1f HP per in-game hour while alight (%.1f -> %.1f)"
				% [net_per_hour, start_hp, crewed])

	GameState.burning = {}

	# =====================================================================
	# THE CLOCK ITSELF: hours_passed is a DIFFERENCE, so a tick with no time in it
	# must be free. If a sub-tick ever starts billing per call instead of per hour,
	# every system in the game silently runs at frame rate.
	# =====================================================================
	quiet_town(6)
	GameState.village_last_hours_elapsed = GameState.game_hours
	var food_before: float = GameState.village_food
	for i3 in range(40):
		GameState.tick_village_clock()           # 40 ticks, zero in-game time
	check("a tick with no time in it changes nothing (hours_passed is a difference, not a per-call charge)",
		is_equal_approx(GameState.village_food, food_before)
			and GameState.rescued_villagers.size() == 6,
		"food %.3f -> %.3f, roster %d" % [food_before, GameState.village_food,
			GameState.rescued_villagers.size()])

	# ---- restore ----
	GameState.rescued_villagers = s_roster
	GameState.sick = s_sick
	GameState.plague_ids = s_plague
	GameState.burning = s_burn
	GameState.villager_hp = s_hp
	GameState.building_stage = s_stage
	GameState.building_x = s_x
	GameState.village_stockpile = s_store
	GameState.floors_cleared = s_cleared
	GameState.patrol_posts = s_posts
	GameState.block_creep = s_creep
	GameState.village_food = s_food
	GameState.food_empty_hours = s_empty
	GameState.building_health = s_health
	GameState.cottage_homes = s_homes
	GameState.extra_cottage_ids = s_ids
	GameState.extra_cottage_positions = s_pos
	GameState.extra_cottages = s_ids.size()
	GameState.hours_until_next_siege = s_siege
	GameState._fire_accum = s_fire_accum
	GameState.wage_accum_hours = s_wage
	GameState.village_treasury = s_treasury
	p.currency = s_gold

	printerr("test_realclock : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
