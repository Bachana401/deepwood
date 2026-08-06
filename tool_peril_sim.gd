extends Node
# ==================== THE SICKNESS & FIRE SIMULATOR ====================
# Run:  MONARCH_TEST="res://tool_peril_sim.gd" Godot.exe --headless --path .
#
# Sickness and fire are the two costs the village produces AT the player rather
# than FOR them. Both were retuned by the lead after an audit found sickness
# could not kill anyone and fire switched itself off once the Builderhouse was
# staffed. Fresh numbers, never measured. This measures them.
#
# THE QUESTIONS FROM THE BRIEF
#   1. How long from falling ill to death with NO intervention?
#   2. How often does a town of eighty lose someone?
#   3. Can a fire chain through a tightly-packed row and take several buildings
#      before a staffed crew stops it?
#
# CRITICAL METHOD NOTE
#   Sickness does NOT own the villager's HP by itself. tick_village_clock runs
#   tick_sickness(h) and then tick_morale_effects(h), and the second one heals
#   everyone who is not starving at DESPAIR_HP_REGEN_PER_HOUR. So the only
#   honest reading of "how fast does sickness kill" comes from the WHOLE tick,
#   not from SICK_DRAIN_PER_HOUR on its own. Both are reported below, because
#   the difference between them is the entire finding.
#
# ASSUMPTIONS
#   * Towns are painted CARED-FOR: fed, housed, paired, high morale. That is the
#     kindest case for the sickness (no starvation drain helping it along) and
#     the one the design cares about -- "your town can now hurt" is meant to bite
#     a town that is otherwise doing fine.
#   * 1 in-game day = 600 real seconds, so 1 in-game hour = 25 real seconds.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)
func say(t: String) -> void: printerr(t)

var p: Node = null
const REAL_MIN_PER_GAME_DAY := 10.0
const COTTAGE_X0 := 12000.0

var _vid := 0
func mk(sex: String, role: String, title: String, stat: String) -> Dictionary:
	_vid += 1
	return {"id": "s_%d" % _vid, "name": "S%d" % _vid, "sex": sex, "is_kid": false,
		"stat_name": stat, "stat_value": 5, "role_key": role, "role_title": title,
		"morale": 9.0}

# A cared-for town of n souls, packed along a cottage row `spacing` apart.
# The spacing IS the experiment for spread: SICK_SPREAD_RADIUS is 900, so a row
# at 150 puts ~12 homes inside every carrier's reach and a row at 1200 puts none.
func paint(n: int, spacing: float, hospital: bool, doctors: int, hosp_x: float) -> void:
	GameState.reset_for_new_game()
	GameState.opening_done = true
	GameState.dev_mode = false
	GameState.hours_until_next_siege = 999999.0
	GameState.village_last_hours_elapsed = GameState.game_hours
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.mating_houses = {}
	GameState.pregnancies = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	GameState.extra_cottages = 0
	GameState.sick = {}
	GameState.villager_hp = {}
	GameState.villager_rot = {}
	GameState._sick_accum = 0.0
	GameState.building_levels = {}
	_vid = 0
	for b in ["Farm", "Fishing Dock", "Bar", "Tavern", "Government"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100
	for b2 in GameState.STARTING_BUILDINGS:
		if not (b2 in ["Farm", "Fishing Dock", "Bar", "Tavern", "Government", "Hospital"]):
			GameState.building_stage[b2] = 0
	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES if hospital else 0
	GameState.building_health["Hospital"] = 100 if hospital else 0
	for i in range(n):
		GameState.rescued_villagers.append(mk("Male" if i % 2 == 0 else "Female", "Farm", "Farmer", "Farm"))
	for d in range(doctors):
		GameState.rescued_villagers.append(mk("Female", "Hospital", "Doctors", "Hospital"))
	var vs: Array = GameState.rescued_villagers
	var hi := 0
	for j in range(0, vs.size() - 1, 2):
		var hid: String = GameState.register_cottage(COTTAGE_X0 + spacing * float(hi))
		hi += 1
		vs[j]["partner_id"] = str(vs[j + 1]["id"])
		vs[j + 1]["partner_id"] = str(vs[j]["id"])
		vs[j]["paired"] = true
		vs[j + 1]["paired"] = true
		GameState.cottage_homes[hid] = {"a": str(vs[j]["id"]), "b": str(vs[j + 1]["id"])}
	# the halls stand somewhere the cottage row can (or cannot) feel
	GameState.building_x = {"Farm": COTTAGE_X0 - 3000.0, "Fishing Dock": COTTAGE_X0 - 3200.0,
		"Bar": COTTAGE_X0 - 3400.0, "Tavern": COTTAGE_X0 - 3600.0,
		"Government": COTTAGE_X0 - 3800.0, "Hospital": hosp_x}
	GameState.building_districts = {}
	GameState.building_neighbors = {}
	GameState.building_plots = {}
	GameState.village_food = float(n) * 60.0

# THE LARDER IS HELD FULL. The first pass of this sim read a town wiping out and
# blamed the sickness; the hour-by-hour trace said otherwise -- HP sat pinned at
# 100 for nine straight days and then fell off a cliff the hour the food ran out.
# Starvation and sickness share ONE HP pool (tick_morale_effects), so the only way
# to measure either is to hold the other at zero.
var keep_fed := true
# Simulates a HIGHER SICK_DRAIN_PER_HOUR without touching the lead's constant.
# Applied after the tick, which is arithmetically identical: the regen clamps at
# MAX_HP either way, so the net rate is -(SICK_DRAIN + extra - REGEN) in both.
var extra_drain := 0.0
# Simulates the alternative patch: the sick simply do not passively regen.
var no_regen_when_sick := false

func advance(hours: float) -> void:
	var stepped := 0.0
	while stepped < hours:
		var step: float = minf(1.0, hours - stepped)
		if keep_fed:
			GameState.village_food = maxf(GameState.village_food, float(pop()) * 40.0)
		GameState.game_hours += step
		var before: Dictionary = {}
		if no_regen_when_sick:
			for sid in GameState.sick.keys():
				before[str(sid)] = GameState.get_villager_hp(str(sid))
		GameState.tick_village_clock()
		if no_regen_when_sick:
			for sid2 in before.keys():
				if GameState.villager_hp.has(sid2):
					var relief: float = 1.0
					var v: Dictionary = GameState.find_villager_by_id(str(sid2))
					if not v.is_empty() and GameState.in_aura("Hospital", v):
						relief = 1.0 - GameState.SICK_WARD_DRAIN_RELIEF
					GameState.villager_hp[sid2] = minf(
						float(before[sid2]) - GameState.SICK_DRAIN_PER_HOUR * step * relief,
						GameState.get_villager_hp(str(sid2)))
		if extra_drain > 0.0:
			for sid3 in GameState.sick.keys():
				if not GameState.villager_hp.has(sid3) and not GameState.sick.has(sid3):
					continue
				var relief2: float = 1.0
				var v2: Dictionary = GameState.find_villager_by_id(str(sid3))
				if not v2.is_empty() and GameState.in_aura("Hospital", v2):
					relief2 = 1.0 - GameState.SICK_WARD_DRAIN_RELIEF
				GameState.villager_hp[str(sid3)] = GameState.get_villager_hp(str(sid3)) \
					- extra_drain * step * relief2
			GameState._reap_the_sick()
		GameState.pregnancies = {}          # pin the roster: births would muddy the count
		stepped += step

func pop() -> int:
	return GameState.rescued_villagers.size()

# ================================================================== main
func _ready() -> void:
	for i in range(1800):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(90):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false
	seed(20260806)
	# S1/S2 walk thousands of full village ticks and take minutes. PERIL_ONLY=S5
	# runs just the parameter sweep, for iterating on a proposed number.
	var only: String = OS.get_environment("PERIL_ONLY")

	say("\n  the constants under test:")
	say("    SICK_DRAIN_PER_HOUR         %.2f" % GameState.SICK_DRAIN_PER_HOUR)
	say("    DESPAIR_HP_REGEN_PER_HOUR   %.2f   <- the passive heal that runs in the SAME tick" % GameState.DESPAIR_HP_REGEN_PER_HOUR)
	say("    VILLAGER_MAX_HP             %.0f" % GameState.VILLAGER_MAX_HP)
	say("    SICK_CURE_CHANCE_PER_DAY    %.2f" % GameState.SICK_CURE_CHANCE_PER_DAY)
	say("    OUTBREAK_MIN_POP            %d" % GameState.OUTBREAK_MIN_POP)
	say("    OUTBREAK_CHANCE_PER_DAY     %.3f  (+%.4f per soul over the threshold)" % [
		GameState.OUTBREAK_CHANCE_PER_DAY, GameState.OUTBREAK_CHANCE_PER_SOUL])
	say("    SICK_SPREAD_CHANCE_PER_DAY  %.2f within %.0f units" % [
		GameState.SICK_SPREAD_CHANCE_PER_DAY, GameState.SICK_SPREAD_RADIUS])

	# ---------- S1: ONE SOUL, ILL, NOBODY COMING ----------
	say("\n========== S1: ONE SOUL FALLS ILL AND NOBODY COMES ==========")
	say("  No hospital, no doctors, no ward aura, cure roll suppressed by re-")
	say("  infecting them every day -- the absolute worst case the game allows.")
	# (a) the drain ALONE, as the constant reads
	paint(2, 400.0, false, 0, -99999.0)
	var vid: String = str(GameState.rescued_villagers[0]["id"])
	GameState.villager_hp[vid] = GameState.VILLAGER_MAX_HP
	GameState.sick[vid] = GameState.game_hours
	var drain_only_h := 0
	for h in range(2000):
		GameState.villager_hp[vid] = GameState.get_villager_hp(vid) - GameState.SICK_DRAIN_PER_HOUR
		drain_only_h += 1
		if GameState.get_villager_hp(vid) <= 0.0:
			break
	say("  the DRAIN alone (SICK_DRAIN_PER_HOUR against full HP):")
	say("    dead in %d in-game hours = %.1f in-game days = %.0f real minutes" % [
		drain_only_h, float(drain_only_h) / 24.0, float(drain_only_h) / 24.0 * REAL_MIN_PER_GAME_DAY])

	# (b) the drain inside the REAL tick, where the passive regen also runs
	paint(2, 400.0, false, 0, -99999.0)
	var vid2: String = str(GameState.rescued_villagers[0]["id"])
	GameState.villager_hp[vid2] = GameState.VILLAGER_MAX_HP
	GameState.sick[vid2] = GameState.game_hours
	var hours_to_death: Callable = func(xdrain: float, skip_regen: bool, ward: bool) -> float:
		seed(20260806)
		extra_drain = xdrain
		no_regen_when_sick = skip_regen
		keep_fed = true
		paint(2, 400.0, ward, 3 if ward else 0, COTTAGE_X0 + 200.0 if ward else -99999.0)
		var v: String = str(GameState.rescued_villagers[0]["id"])
		GameState.villager_hp[v] = GameState.VILLAGER_MAX_HP
		GameState.sick[v] = GameState.game_hours
		var start: int = pop()
		for hh in range(2400):
			if not GameState.sick.has(v) and pop() >= start:
				GameState.sick[v] = GameState.game_hours   # hold them ill: "no intervention"
			advance(1.0)
			if pop() < start:
				return float(hh + 1)
		return -1.0

	var base_h: float = hours_to_death.call(0.0, false, false)
	extra_drain = 0.0
	no_regen_when_sick = false
	say("  inside the REAL tick (sickness drains, then tick_morale_effects heals),")
	say("  with the larder held FULL so famine cannot do the killing:")
	if base_h < 0.0:
		say("    STILL ALIVE after 100 in-game days (1000 real minutes).")
		say("    net HP per hour while ill: %+.2f  (sickness %.2f, passive regen %.2f)" % [
			GameState.DESPAIR_HP_REGEN_PER_HOUR - GameState.SICK_DRAIN_PER_HOUR,
			-GameState.SICK_DRAIN_PER_HOUR, GameState.DESPAIR_HP_REGEN_PER_HOUR])
		say("    THE SICKNESS IS SLOWER THAN THE HEAL IT RUNS BESIDE. It removes")
		say("    2.40 HP an hour from a pool that gains 3.00 back in the same tick.")
	else:
		say("    dead in %.0f in-game hours = %.1f in-game days = %.0f real minutes" % [
			base_h, base_h / 24.0, base_h / 24.0 * REAL_MIN_PER_GAME_DAY])
	check("S1: an untreated sickness can actually kill the villager it has",
		base_h > 0.0, "still alive after 100 in-game days")

	say("\n  --- what WOULD kill: the same experiment at other net drains ---")
	say("  SICK_DRAIN_PER_HOUR | net vs regen | dead after (no ward) | dead after (in ward aura)")
	for want in ([2.4, 3.0, 3.6, 4.5, 5.5, 7.0, 9.0] if only == "" else []):
		var xd: float = maxf(0.0, float(want) - GameState.SICK_DRAIN_PER_HOUR)
		var t_plain: float = hours_to_death.call(xd, false, false)
		var t_ward: float = hours_to_death.call(xd, false, true)
		say("        %5.2f%s        |   %+5.2f/h    | %s | %s" % [
			float(want), "  (LIVE)" if is_equal_approx(float(want), GameState.SICK_DRAIN_PER_HOUR) else "        ",
			GameState.DESPAIR_HP_REGEN_PER_HOUR - float(want),
			"never              " if t_plain < 0.0 else "%5.0fh (%4.1f d / %3.0f min)" % [t_plain, t_plain / 24.0, t_plain / 24.0 * REAL_MIN_PER_GAME_DAY],
			"never" if t_ward < 0.0 else "%5.0fh (%4.1f d / %3.0f min)" % [t_ward, t_ward / 24.0, t_ward / 24.0 * REAL_MIN_PER_GAME_DAY]])
	var t_noregen: float = hours_to_death.call(0.0, true, false)
	var t_noregen_ward: float = hours_to_death.call(0.0, true, true)
	extra_drain = 0.0
	no_regen_when_sick = false
	say("  the OTHER fix -- leave the drain at %.2f but stop the sick passively healing:" % GameState.SICK_DRAIN_PER_HOUR)
	say("        dead after %s  |  in the ward's aura: %s" % [
		"never" if t_noregen < 0.0 else "%.0fh (%.1f days / %.0f real minutes)" % [t_noregen, t_noregen / 24.0, t_noregen / 24.0 * REAL_MIN_PER_GAME_DAY],
		"never" if t_noregen_ward < 0.0 else "%.0fh (%.1f days / %.0f real min)" % [t_noregen_ward, t_noregen_ward / 24.0, t_noregen_ward / 24.0 * REAL_MIN_PER_GAME_DAY]])

	# ---------- S2: A TOWN OF EIGHTY, LEFT ALONE ----------
	say("\n========== S2: A TOWN OF EIGHTY, 200 IN-GAME DAYS ==========")
	say("  Larder held FULL throughout, so every death below is the sickness and")
	say("  nothing else. 80 souls in a tight row, 100 in-game days (1000 real min).")
	say("  Each candidate drain is run against three towns: no ward, a staffed ward")
	say("  too far to reach the homes, and a staffed ward the row sits inside.")
	say("  drain | ward         | outbreaks | peak sick | ever ill | DEAD | left alive")
	var town: Callable = func(xdrain: float, skip_regen: bool, hosp: bool, hx: float) -> Dictionary:
		seed(20260806)
		extra_drain = xdrain
		no_regen_when_sick = skip_regen
		keep_fed = true
		paint(80, 150.0, hosp, 3 if hosp else 0, hx)
		var start_pop: int = pop()
		var outbreaks := 0
		var peak := 0
		var ever := {}
		var was_empty := true
		for _h in range(2400):
			advance(1.0)
			if GameState.sick.is_empty():
				was_empty = true
			elif was_empty:
				outbreaks += 1
				was_empty = false
			peak = maxi(peak, GameState.sick.size())
			for sid in GameState.sick.keys():
				ever[str(sid)] = true
		return {"out": outbreaks, "peak": peak, "ever": ever.size(),
			"dead": start_pop - pop(), "left": pop(), "start": start_pop}
	var wards: Array = [
		{"hosp": false, "hx": -99999.0, "tag": "none        "},
		{"hosp": true, "hx": -99999.0, "tag": "staffed, far"},
		{"hosp": true, "hx": COTTAGE_X0 + 500.0, "tag": "staffed, near"}]
	var wipe_out := 0
	var live_dead := -1
	for want2 in ([2.4, 3.6, 5.5] if only == "" else []):
		for w in wards:
			var xd2: float = maxf(0.0, float(want2) - GameState.SICK_DRAIN_PER_HOUR)
			var t: Dictionary = town.call(xd2, false, bool(w["hosp"]), float(w["hx"]))
			if is_equal_approx(float(want2), GameState.SICK_DRAIN_PER_HOUR) and not bool(w["hosp"]):
				live_dead = int(t["dead"])
			if int(t["left"]) <= 2:
				wipe_out += 1
			say("  %5.2f | %s |    %2d     |    %3d    |   %3d    | %3d  | %d of %d" % [
				float(want2), str(w["tag"]), int(t["out"]), int(t["peak"]), int(t["ever"]),
				int(t["dead"]), int(t["left"]), int(t["start"])])
	say("  -- and the no-passive-regen alternative, drain left at %.2f --" % GameState.SICK_DRAIN_PER_HOUR)
	for w2 in (wards if only == "" else []):
		var t2: Dictionary = town.call(0.0, true, bool(w2["hosp"]), float(w2["hx"]))
		if int(t2["left"]) <= 2:
			wipe_out += 1
		say("  %5.2f | %s |    %2d     |    %3d    |   %3d    | %3d  | %d of %d" % [
			GameState.SICK_DRAIN_PER_HOUR, str(w2["tag"]), int(t2["out"]), int(t2["peak"]),
			int(t2["ever"]), int(t2["dead"]), int(t2["left"]), int(t2["start"])])
	extra_drain = 0.0
	no_regen_when_sick = false
	check("S2: as it ships, an outbreak in a town of eighty costs it somebody",
		live_dead > 0, "%d dead in 100 in-game days with no ward at all" % live_dead)
	check("S2: ...and no configuration of the sickness empties the town outright",
		wipe_out == 0, "%d of the 12 towns were emptied" % wipe_out)

	# ---------- S2b: does the geography actually matter? ----------
	# The design claim is "cottages packed in a row pass it along fast; a town
	# spread down the road resists it". _lives_touch reads home OR WORKPLACE, so
	# this asks whether sharing a workplace defeats the spacing outright.
	say("\n========== S2b: DOES SPACING ACTUALLY SLOW IT? ==========")
	say("  setup                                   | souls infected on the first day of spread")
	for cfg3 in ([
			{"space": 150.0, "jobs": false, "tag": "row 150 apart, all at one Farm    "},
			{"space": 4000.0, "jobs": false, "tag": "row 4000 apart, all at one Farm   "},
			{"space": 150.0, "jobs": true, "tag": "row 150 apart, NOBODY employed    "},
			{"space": 4000.0, "jobs": true, "tag": "row 4000 apart, NOBODY employed   "}] if only == "" else []):
		seed(20260806)
		var caught := 0
		for trial2 in range(40):
			paint(40, float(cfg3["space"]), false, 0, -99999.0)
			if bool(cfg3["jobs"]):
				for v3 in GameState.rescued_villagers:
					v3["role_key"] = ""
					v3["role_title"] = ""
			var seedv: String = str(GameState.rescued_villagers[0]["id"])
			GameState.sick[seedv] = GameState.game_hours
			GameState._sick_accum = 0.0
			advance(25.0)                       # cross exactly one sickness day
			caught += GameState.sick.size() - 1
		say("   %s |  %.2f caught per outbreak-day" % [str(cfg3["tag"]), float(caught) / 40.0])

	# ---------- S3: WHAT THE WARD IS WORTH ----------
	say("\n========== S3: WHAT THE WARD IS ACTUALLY BUYING ==========")
	say("  Since the ward's whole job is to end sicknesses, the reading that")
	say("  matters is how long one LASTS, not how hard it hurts.")
	for cfg2 in ([
			{"hosp": false, "docs": 0, "hx": -99999.0, "tag": "no hospital     "},
			{"hosp": true, "docs": 3, "hx": -99999.0, "tag": "staffed, far off"},
			{"hosp": true, "docs": 3, "hx": COTTAGE_X0 + 500.0, "tag": "staffed, in aura"}] if only == "" else []):
		seed(20260806)
		var spans: Array = []
		for trial in range(120):
			paint(4, 3000.0, bool(cfg2["hosp"]), int(cfg2["docs"]), float(cfg2["hx"]))
			var v3: String = str(GameState.rescued_villagers[0]["id"])
			GameState.sick[v3] = GameState.game_hours
			var lasted := 0
			for h4 in range(2400):
				advance(1.0)
				lasted += 1
				if not GameState.sick.has(v3):
					break
			spans.append(float(lasted))
		var mean := 0.0
		for s in spans:
			mean += float(s)
		mean /= float(spans.size())
		say("   %s: an illness lasts %.1f in-game hours (%.1f days / %.0f real minutes)" % [
			str(cfg2["tag"]), mean, mean / 24.0, mean / 24.0 * REAL_MIN_PER_GAME_DAY])

	# ---------- S5: THE SPREAD/CURE EQUILIBRIUM ----------
	# S1 and S2 together say the drain alone cannot be fixed: below the passive
	# regen nobody dies, above it EVERYBODY does. The reason is upstream -- the
	# spread saturates the town before the cure can clear anyone, so the sickness
	# has only two states, "everyone has it" and "everyone is dead". This sweeps
	# the two numbers that decide that, on the REAL contact graph (_lives_touch
	# over the real painted roster), to find a pair that settles somewhere in
	# between. It is a MODEL of _sickness_day, not the function itself -- the
	# constants are the lead's, so they cannot be set from here.
	say("\n========== S5: WHY IT HAS NO MIDDLE -- THE SPREAD/CURE SWEEP ==========")
	seed(20260806)
	keep_fed = true
	paint(80, 150.0, false, 0, -99999.0)
	var roster: Array = GameState.rescued_villagers
	var touch: Array = []                    # the real contact graph, built once
	for i2 in range(roster.size()):
		var rowt: Array = []
		for j2 in range(roster.size()):
			rowt.append(i2 != j2 and GameState._lives_touch(roster[i2], roster[j2], GameState.SICK_SPREAD_RADIUS))
		touch.append(rowt)
	# ...and the graph a HOMES-ONLY rule would give. villager_places() returns the
	# cottage first and the workplace second, so dropping the workplace is exactly
	# "does their door stand near your door". This is the graph the design line
	# describes ("cottages packed in a row pass it along fast").
	var homes: Array = []
	for i2b in range(roster.size()):
		var hx: float = -1.0e9
		var pl: Array = GameState.villager_places(roster[i2b])
		if not pl.is_empty():
			hx = float(pl[0])
		homes.append(hx)
	var touch_home: Array = []
	for i2c in range(roster.size()):
		var rowh: Array = []
		for j2c in range(roster.size()):
			rowh.append(i2c != j2c
				and absf(float(homes[i2c]) - float(homes[j2c])) <= GameState.SICK_SPREAD_RADIUS)
		touch_home.append(rowh)
	var contacts := 0
	var contacts_home := 0
	for i3 in range(touch.size()):
		for j3 in range(touch.size()):
			if bool(touch[i3][j3]): contacts += 1
			if bool(touch_home[i3][j3]): contacts_home += 1
	say("  the REAL contact graph (home OR workplace): every soul touches %.1f of %d others." % [
		float(contacts) / float(roster.size()), roster.size() - 1])
	say("  a HOMES-ONLY graph, same tight row:        every soul touches %.1f of %d others." % [
		float(contacts_home) / float(roster.size()), roster.size() - 1])
	say("  spread | cure | ward cure | avg %% of town ill | deaths/100 days | verdict")
	var model: Callable = func(spread: float, cure: float, net_per_hour: float, graph: Array) -> Dictionary:
		var n: int = roster.size()
		var ill: Array = []
		var hp: Array = []
		for _i in range(n):
			ill.append(false)
			hp.append(GameState.VILLAGER_MAX_HP)
		ill[0] = true
		var ill_days := 0
		var deaths := 0
		var alive := n
		for _d in range(100):
			# ---- the hourly half: HP moves by the net rate ----
			for i4 in range(n):
				if ill[i4] and hp[i4] > 0.0:
					hp[i4] -= net_per_hour * 24.0
					if hp[i4] <= 0.0:
						deaths += 1
						alive -= 1
						ill[i4] = false
				elif hp[i4] > 0.0:
					hp[i4] = minf(GameState.VILLAGER_MAX_HP, hp[i4] + 24.0 * 3.0)
			# ---- who throws it off ----
			for i5 in range(n):
				if ill[i5] and randf() < cure:
					ill[i5] = false
			# ---- who catches it ----
			var fresh: Array = []
			for i6 in range(n):
				if ill[i6] or hp[i6] <= 0.0:
					continue
				for j6 in range(n):
					if ill[j6] and bool(graph[j6][i6]) and randf() < spread:
						fresh.append(i6)
						break
			for f in fresh:
				ill[int(f)] = true
			var count := 0
			for i7 in range(n):
				if ill[i7]: count += 1
			ill_days += count
		return {"avg": 100.0 * float(ill_days) / float(100 * n), "dead": deaths}
	for cfg4 in [
			{"s": GameState.SICK_SPREAD_CHANCE_PER_DAY, "c": GameState.SICK_CURE_CHANCE_PER_DAY, "net": -0.60, "home": false, "tag": "AS IT SHIPS"},
			{"s": GameState.SICK_SPREAD_CHANCE_PER_DAY, "c": GameState.SICK_CURE_CHANCE_PER_DAY, "net": 2.40, "home": false, "tag": "ships + no sick regen"},
			{"s": 0.08, "c": 0.25, "net": 2.40, "home": false, "tag": "spread 0.08 cure 0.25"},
			{"s": 0.05, "c": 0.35, "net": 2.40, "home": false, "tag": "spread 0.05 cure 0.35"},
			{"s": 0.04, "c": 0.45, "net": 2.40, "home": false, "tag": "spread 0.04 cure 0.45"},
			# ...and the shape the numbers above argue for: an illness that is SLOW
			# to kill (so the daily cure roll usually beats it), carried by a spread
			# that cannot saturate the town because it only travels door to door.
			{"s": GameState.SICK_SPREAD_CHANCE_PER_DAY, "c": GameState.SICK_CURE_CHANCE_PER_DAY, "net": 1.20, "home": true, "tag": "HOMES-ONLY, ships' spread/cure"},
			{"s": 0.12, "c": 0.30, "net": 1.20, "home": true, "tag": "HOMES-ONLY 0.12/0.30 drain 1.2"},
			{"s": 0.12, "c": 0.30, "net": 0.60, "home": true, "tag": "PROPOSED  homes 0.12/0.30 drain 0.6"},
			{"s": 0.10, "c": 0.35, "net": 1.20, "home": true, "tag": "PROPOSED  homes 0.10/0.35 drain 1.2"}]:
		var acc_avg := 0.0
		var acc_dead := 0.0
		for rep in range(8):
			var m: Dictionary = model.call(float(cfg4["s"]), float(cfg4["c"]), float(cfg4["net"]),
				touch_home if bool(cfg4["home"]) else touch)
			acc_avg += float(m["avg"])
			acc_dead += float(m["dead"])
		acc_avg /= 8.0
		acc_dead /= 8.0
		say("   %.2f  | %.2f |   ---     |     %5.1f%%        |     %5.1f       | %s" % [
			float(cfg4["s"]), float(cfg4["c"]), acc_avg, acc_dead, str(cfg4["tag"])])

	# ---------- S4: FIRE ----------
	say("\n========== S4: FIRE ==========")
	var gs: String = FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	var markers: Array = ["FIRE_SPREAD", "building_fires", "tick_fire", "_tick_fire",
		"BLAZE", "FIRE_DAMAGE_PER_HOUR", "catch_fire", "burning_buildings"]
	var seen: Array = []
	for m in markers:
		if gs.contains(str(m)):
			seen.append(str(m))
	if seen.is_empty():
		say("  NOT PRESENT in the committed tree. game_state.gd carries no fire")
		say("  state, no per-hour building burn, and no spread-to-neighbour step;")
		say("  the only matches for 'fire' in the file are _fire_event(), which is")
		say("  the hidden-event-boss trigger, not a burning building.")
		say("  Nothing to measure. The harness above is ready for it the moment it")
		say("  lands: paint() already stands a packed row and building_health is the")
		say("  pool a burn would eat.")
	else:
		say("  found: %s -- fire has landed; extend this section." % ", ".join(seen))
	check("S4: the fire system this sim was asked to measure exists in the tree",
		not seen.is_empty(), "no fire state, constants or tick found in game_state.gd")

	GameState.reset_for_new_game()
	printerr("\ntool_peril_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
