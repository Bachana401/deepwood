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
	GameState.village_food = GameState.food_capacity()
	GameState.food_empty_hours = 0.0
	GameState.low_morale_hours = 0.0
	GameState.hours_until_next_siege = 100000.0
	GameState.live_siege_active = false
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
	p.currency = s_gold

	printerr("test_realclock : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
