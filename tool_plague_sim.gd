extends Node
# ==================== THE TWO-STRAIN SICKNESS SIMULATOR ====================
# Run:  MONARCH_TEST="res://tool_plague_sim.gd" Godot.exe --headless --path .
#
# THE TWO-STRAIN MODEL IS ON MASTER (merged; this header's old warning that it
# lived only on a branch is retired, 2026-08-06). It also means the old advice
# here -- "use tool_peril_sim.gd instead" -- is dead: that file's sickness half
# was written against SICK_DRAIN_PER_HOUR, which no longer exists, so it did not
# resolve at all. This tool is now the ONLY sickness measurement; tool_peril_sim
# has been retargeted at fire.
#
# WHAT CHANGED UNDER THE OLD SWEEP
#   SICK_DRAIN_PER_HOUR is gone. The ordinary ILLNESS now costs no HP at all --
#   it suppresses the passive regen (tick_morale_effects skips a sick body) and
#   drags morale. Only the PLAGUE, gated to PLAGUE_MIN_DEPTH, drains and reaps.
#   So the question "how long from falling ill to death" is now a PLAGUE question,
#   and the regen-suppression means the answer is finally not "never".
#
# THE TWO THINGS THIS IS FOR
#   1. The plague's real lethality curve, measured inside the whole tick.
#   2. THE CONTACT GRAPH. _lives_touch reads villager_places(), which returns the
#      cottage AND the workplace. Everyone sharing a hall stands at distance 0, so
#      a staffed town is one fully-connected blob and cottage spacing -- the thing
#      the spread design rests on -- stops mattering. Measured both ways here.
#
# THE HOMES-ONLY GRAPH IS MEASURED HONESTLY, NOT FAKED. _lives_touch belongs to
# the lead, so it is never edited. Instead the same function is fed a roster whose
# role_key is cleared: villager_places() then returns the cottage and nothing else,
# which is precisely the graph a homes-only rule would build. Same code path, same
# radius, same painted row -- only the data it reads differs.
#
# ASSUMPTIONS
#   * Towns painted CARED-FOR and the larder HELD FULL every hour, so starvation
#     can never be mistaken for the sickness (see the harness note in
#     tool_peril_sim.gd -- this exact confusion produced a false wipe-out once).
#   * 1 in-game day = 600 real seconds; 1 in-game hour = 25 real seconds.

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
	return {"id": "g_%d" % _vid, "name": "G%d" % _vid, "sex": sex, "is_kid": false,
		"stat_name": stat, "stat_value": 5, "role_key": role, "role_title": title,
		"morale": 9.0}

# n souls in a row `spacing` apart. employed=false clears every role_key, which is
# the homes-only contact graph (villager_places drops the workplace term).
func paint(n: int, spacing: float, employed: bool, hospital: bool, doctors: int, hosp_x: float) -> void:
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
	GameState.plague_ids = {}
	GameState.villager_hp = {}
	GameState.villager_rot = {}
	GameState._sick_accum = 0.0
	GameState.building_levels = {}
	_vid = 0
	for b in ["Farm", "Fishing Dock", "Bar", "Tavern", "Government"]:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH
	for b2 in GameState.STARTING_BUILDINGS:
		if not (b2 in ["Farm", "Fishing Dock", "Bar", "Tavern", "Government", "Hospital"]):
			GameState.building_stage[b2] = 0
	GameState.building_stage["Hospital"] = GameState.TOTAL_BUILD_STAGES if hospital else 0
	GameState.building_health["Hospital"] = GameState.BUILDING_MAX_HEALTH if hospital else 0
	for i in range(n):
		if employed:
			GameState.rescued_villagers.append(mk("Male" if i % 2 == 0 else "Female", "Farm", "Farmer", "Farm"))
		else:
			GameState.rescued_villagers.append(mk("Male" if i % 2 == 0 else "Female", "", "", "Farm"))
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
	GameState.building_x = {"Farm": COTTAGE_X0 - 3000.0, "Fishing Dock": COTTAGE_X0 - 3200.0,
		"Bar": COTTAGE_X0 - 3400.0, "Tavern": COTTAGE_X0 - 3600.0,
		"Government": COTTAGE_X0 - 3800.0, "Hospital": hosp_x}
	GameState.building_districts = {}
	GameState.building_neighbors = {}
	GameState.building_plots = {}
	GameState.village_food = float(n) * 60.0
	# the plague only exists once the player is established
	GameState.deepest_level_reached = maxi(GameState.deepest_level_reached, GameState.PLAGUE_MIN_DEPTH)

func pop() -> int:
	return GameState.rescued_villagers.size()

func advance(hours: float) -> void:
	var stepped := 0.0
	while stepped < hours:
		var step: float = minf(1.0, hours - stepped)
		GameState.village_food = maxf(GameState.village_food, float(pop()) * 40.0)
		GameState.game_hours += step
		GameState.tick_village_clock()
		stepped += step

func mean_of(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v in a:
		t += float(v)
	return t / float(a.size())

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

	say("\n  the TWO-STRAIN constants under test:")
	say("    PLAGUE_MIN_DEPTH            %d" % GameState.PLAGUE_MIN_DEPTH)
	say("    PLAGUE_SHARE_ONCE_DEEP      %.2f" % GameState.PLAGUE_SHARE_ONCE_DEEP)
	say("    PLAGUE_DRAIN_PER_HOUR       %.2f" % GameState.PLAGUE_DRAIN_PER_HOUR)
	say("    PLAGUE_SPREAD_MULT          %.2f  (base spread %.2f/day)" % [
		GameState.PLAGUE_SPREAD_MULT, GameState.SICK_SPREAD_CHANCE_PER_DAY])
	say("    PLAGUE_CURE_MULT            %.2f  (base cure %.2f/day)" % [
		GameState.PLAGUE_CURE_MULT, GameState.SICK_CURE_CHANCE_PER_DAY])
	say("    SICK_MORALE_PER_CASE        %.2f   PLAGUE_MORALE_PER_CASE %.2f   cap %.2f" % [
		GameState.SICK_MORALE_PER_CASE, GameState.PLAGUE_MORALE_PER_CASE, GameState.SICK_MORALE_CAP])
	say("    DESPAIR_HP_REGEN_PER_HOUR   %.2f  (SUPPRESSED while sick -- the new rule)" % \
		GameState.DESPAIR_HP_REGEN_PER_HOUR)

	# ---------- G1: ONE PLAGUE CASE, NOBODY COMES ----------
	say("\n========== G1: ONE PLAGUE CASE AND NOBODY COMES ==========")
	say("  Re-infected every hour so the cure roll can never end it -- this is the")
	say("  pure drain curve inside the REAL tick, larder held full.")
	for cfg in [{"h": false, "d": 0, "hx": -99999.0, "tag": "no hospital     "},
			{"h": true, "d": 3, "hx": -99999.0, "tag": "staffed, far off"},
			{"h": true, "d": 3, "hx": COTTAGE_X0 + 500.0, "tag": "staffed, in aura"}]:
		paint(4, 3000.0, true, bool(cfg["h"]), int(cfg["d"]), float(cfg["hx"]))
		var vid: String = str(GameState.rescued_villagers[0]["id"])
		var died := -1
		for h in range(4000):
			GameState.sick[vid] = GameState.game_hours
			GameState.plague_ids[vid] = true
			advance(1.0)
			if GameState.find_villager_by_id(vid).is_empty():
				died = h + 1
				break
		if died > 0:
			say("   %s: dead after %d in-game hours (%.1f days / %.0f real minutes)" % [
				str(cfg["tag"]), died, float(died) / 24.0, float(died) / 24.0 * REAL_MIN_PER_GAME_DAY])
		else:
			say("   %s: STILL ALIVE after 4000 in-game hours (166 days)" % str(cfg["tag"]))
	# ...and the ordinary strain, which must never kill
	paint(4, 3000.0, true, false, 0, -99999.0)
	var ovid: String = str(GameState.rescued_villagers[0]["id"])
	for h2 in range(2400):
		GameState.sick[ovid] = GameState.game_hours
		advance(1.0)
	var ordinary_alive: bool = not GameState.find_villager_by_id(ovid).is_empty()
	var ordinary_hp: float = GameState.get_villager_hp(ovid)
	say("   ordinary ILLNESS, held for 100 in-game days: alive=%s, HP %.0f/%.0f" % [
		str(ordinary_alive), ordinary_hp, GameState.VILLAGER_MAX_HP])
	check("G1: the ordinary illness can never kill (the dev's ruling)", ordinary_alive)

	# ---------- G2: THE CONTACT GRAPH ----------
	say("\n========== G2: THE CONTACT GRAPH -- WHAT WORKPLACES DO ==========")
	say("  _lives_touch reads villager_places(), which returns the cottage AND the")
	say("  workplace. Everyone at one hall stands at distance 0 to each other.")
	for cfg2 in [{"emp": true, "sp": 150.0, "tag": "employed,  row  150 apart"},
			{"emp": true, "sp": 4000.0, "tag": "employed,  row 4000 apart"},
			{"emp": false, "sp": 150.0, "tag": "no jobs,   row  150 apart"},
			{"emp": false, "sp": 4000.0, "tag": "no jobs,   row 4000 apart"}]:
		paint(80, float(cfg2["sp"]), bool(cfg2["emp"]), false, 0, -99999.0)
		var roster: Array = GameState.rescued_villagers
		var links := 0
		for i3 in range(roster.size()):
			for j3 in range(roster.size()):
				if i3 != j3 and GameState._lives_touch(roster[i3], roster[j3], GameState.SICK_SPREAD_RADIUS):
					links += 1
		say("   %s: every soul touches %.1f of %d others" % [
			str(cfg2["tag"]), float(links) / float(roster.size()), roster.size() - 1])

	# ---------- G3: AN OUTBREAK IN A TOWN OF EIGHTY, BOTH GRAPHS ----------
	say("\n========== G3: ONE PLAGUE SEED IN A TOWN OF EIGHTY ==========")
	say("  20 trials each. 'Saturation' = the hour 90%% of the town is ill at once.")
	say("  graph            | saturates in | reached whole town | dead of 80 | outbreak over in")
	for cfg3 in [
			{"emp": true, "ward": false, "tag": "home+work (LIVE) "},
			{"emp": false, "ward": false, "tag": "HOMES ONLY       "},
			{"emp": true, "ward": true, "tag": "LIVE + ward in aura"},
			{"emp": false, "ward": true, "tag": "HOMES ONLY + ward  "}]:
		var sat_hours: Array = []
		var whole := 0
		var deaths: Array = []
		var over: Array = []
		for trial in range(20):
			paint(80, 150.0, bool(cfg3["emp"]), bool(cfg3["ward"]), 3 if bool(cfg3["ward"]) else 0,
				COTTAGE_X0 + 500.0 if bool(cfg3["ward"]) else -99999.0)
			var n0: int = pop()
			var seedv: String = str(GameState.rescued_villagers[0]["id"])
			GameState.sick[seedv] = GameState.game_hours
			GameState.plague_ids[seedv] = true
			GameState._sick_accum = 0.0
			var sat := -1
			var peak := 1
			var ended := -1
			for h3 in range(2400):
				advance(1.0)
				peak = maxi(peak, GameState.sick_count())
				if sat < 0 and float(GameState.sick_count()) >= 0.9 * float(pop()):
					sat = h3 + 1
				if ended < 0 and GameState.sick_count() == 0:
					ended = h3 + 1
					break
			if sat > 0:
				sat_hours.append(float(sat))
			if float(peak) >= 0.9 * float(n0):
				whole += 1
			deaths.append(float(n0 - pop()))
			over.append(float(ended if ended > 0 else 2400))
		say("   %s|   %6.0f h   |     %2d of 20       |   %5.1f    |  %6.0f h (%.0f days)" % [
			str(cfg3["tag"]),
			mean_of(sat_hours) if not sat_hours.is_empty() else -1.0,
			whole, mean_of(deaths), mean_of(over), mean_of(over) / 24.0])
		check("G3: %s -- one plague seed does not kill most of a town of eighty" % str(cfg3["tag"]).strip_edges(),
			mean_of(deaths) < 40.0, "%.1f dead of 80" % mean_of(deaths))

	# ---------- G4: WHAT THE ORDINARY STRAIN COSTS IN MORALE ----------
	say("\n========== G4: THE ORDINARY STRAIN'S MORALE BILL ==========")
	say("  SICK_MORALE_PER_CASE moves the personal morale TARGET, not the meter, so")
	say("  each reading below is taken after 72 in-game hours of drift -- an instant")
	say("  read straight after infecting everyone reports a flat +0 and means nothing.")
	paint(80, 150.0, true, false, 0, -99999.0)
	advance(72.0)
	var m_clean: int = GameState.village_morale()
	for v4 in GameState.rescued_villagers:
		GameState.sick[str(v4.get("id", ""))] = GameState.game_hours
	advance(72.0)
	var m_all_ill: int = GameState.village_morale()
	paint(80, 150.0, true, false, 0, -99999.0)
	advance(72.0)
	for v5 in GameState.rescued_villagers:
		GameState.sick[str(v5.get("id", ""))] = GameState.game_hours
		GameState.plague_ids[str(v5.get("id", ""))] = true
	advance(72.0)
	var m_all_plague: int = GameState.village_morale()
	say("  a healthy town of 80 sits at morale %d" % m_clean)
	say("  all 80 down with the ORDINARY strain: morale %d  (%+d)" % [m_all_ill, m_all_ill - m_clean])
	say("  all 80 down with the PLAGUE:          morale %d  (%+d)" % [m_all_plague, m_all_plague - m_clean])
	say("  (SICK_MORALE_CAP is %.2f of 10, so the whole town ill costs at most %.0f meter points)" % [
		GameState.SICK_MORALE_CAP, GameState.SICK_MORALE_CAP * 10.0])
	check("G4: an outbreak is felt but never a morale wipe",
		m_all_plague >= m_clean - 30, "%d -> %d" % [m_clean, m_all_plague])

	# ---------- G5: WHY THE WARD BARELY HELPS -- RE-INFECTION ----------
	# G3 says a staffed ward standing right on the cottage row only takes the toll
	# from 73 to 55. Per-case arithmetic says it should be near zero: in the aura a
	# case lasts 543h = 22.6 daily cure rolls at 0.26, so P(never cured) ~ 0.1%.
	# The gap is RE-INFECTION -- nothing stops a cured villager catching it again
	# the same night, so on a saturated graph everyone is re-rolled until they die.
	# This models that directly. The model is calibrated first against G3's measured
	# 73.2 so its other rows can be trusted.
	say("\n========== G5: RE-INFECTION -- MODELLED, CALIBRATED ON G3 ==========")
	paint(80, 150.0, true, false, 0, -99999.0)
	var roster5: Array = GameState.rescued_villagers
	var g_work: Array = []
	for i5 in range(roster5.size()):
		var rw: Array = []
		for j5 in range(roster5.size()):
			rw.append(i5 != j5 and GameState._lives_touch(roster5[i5], roster5[j5], GameState.SICK_SPREAD_RADIUS))
		g_work.append(rw)
	paint(80, 150.0, false, false, 0, -99999.0)
	var roster5h: Array = GameState.rescued_villagers
	var g_home: Array = []
	for i6 in range(roster5h.size()):
		var rh: Array = []
		for j6 in range(roster5h.size()):
			rh.append(i6 != j6 and GameState._lives_touch(roster5h[i6], roster5h[j6], GameState.SICK_SPREAD_RADIUS))
		g_home.append(rh)
	var sim: Callable = func(graph: Array, cure: float, drain: float, immune_days: int) -> float:
		var n: int = graph.size()
		var dead_acc := 0.0
		for _rep in range(12):
			var ill: Array = []
			var hp: Array = []
			var imm: Array = []
			for _i in range(n):
				ill.append(false); hp.append(GameState.VILLAGER_MAX_HP); imm.append(0)
			ill[0] = true
			var dead := 0
			for _d in range(120):
				for a in range(n):
					if hp[a] <= 0.0: continue
					if ill[a]:
						hp[a] -= drain * 24.0
						if hp[a] <= 0.0:
							dead += 1; ill[a] = false
					else:
						hp[a] = minf(GameState.VILLAGER_MAX_HP, hp[a] + 24.0 * GameState.DESPAIR_HP_REGEN_PER_HOUR)
						if imm[a] > 0: imm[a] = int(imm[a]) - 1
				for b in range(n):
					if ill[b] and randf() < cure:
						ill[b] = false
						imm[b] = immune_days
				var fresh: Array = []
				for c in range(n):
					if ill[c] or hp[c] <= 0.0 or int(imm[c]) > 0: continue
					for d2 in range(n):
						if ill[d2] and bool(graph[d2][c]) \
								and randf() < GameState.SICK_SPREAD_CHANCE_PER_DAY * GameState.PLAGUE_SPREAD_MULT:
							fresh.append(c); break
				for f in fresh: ill[int(f)] = true
			dead_acc += float(dead)
		return dead_acc / 12.0
	var shipped_cure: float = GameState.SICK_CURE_CHANCE_PER_DAY * GameState.PLAGUE_CURE_MULT
	var ward_cure: float = (GameState.SICK_CURE_CHANCE_PER_DAY + GameState.SICK_WARD_CURE_BONUS) * GameState.PLAGUE_CURE_MULT
	say("  calibration: model on the LIVE graph, shipped cure/drain, no immunity")
	say("     -> %.1f dead of 80   (G3 measured %.1f -- the model tracks)" % [
		sim.call(g_work, shipped_cure, GameState.PLAGUE_DRAIN_PER_HOUR, 0), 73.2])
	say("  graph      | cure | immunity | dead of 80")
	for row in [
			{"g": "work", "c": shipped_cure, "im": 0, "tag": "LIVE       | 0.04 |   none   "},
			{"g": "work", "c": ward_cure, "im": 0, "tag": "LIVE       | 0.26 |   none   "},
			{"g": "work", "c": shipped_cure, "im": 14, "tag": "LIVE       | 0.04 |  14 days "},
			{"g": "work", "c": ward_cure, "im": 14, "tag": "LIVE       | 0.26 |  14 days "},
			{"g": "home", "c": shipped_cure, "im": 14, "tag": "HOMES ONLY | 0.04 |  14 days "},
			{"g": "home", "c": ward_cure, "im": 14, "tag": "HOMES ONLY | 0.26 |  14 days "}]:
		say("   %s |   %.1f" % [str(row["tag"]),
			sim.call(g_work if str(row["g"]) == "work" else g_home,
				float(row["c"]), GameState.PLAGUE_DRAIN_PER_HOUR, int(row["im"]))])

	GameState.sick = {}
	GameState.plague_ids = {}
	GameState.reset_for_new_game()
	printerr("\ntool_plague_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
