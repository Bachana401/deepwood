extends Node
# ===================== THE VILLAGE ECONOMY SIMULATOR =====================
# Run:  MONARCH_TEST="res://tool_econ_sim.gd" Godot.exe --headless --path .
#
# The village shipped a SECOND income stream this week (buildings -> shared
# stockpile + treasury, everything scaled by building_output_multiplier: level,
# adjacency, district, special plot) and nobody had measured it against the
# first one (delving). This drives the REAL machine -- the real tick_village_clock,
# the real generate_passive_income on its REAL 20-real-second cadence, the real
# apply_leadership_automation -- across identical towns whose ONLY difference is
# where the buildings stand and how high they are levelled.
#
# WHAT IT MEASURES
#   E0  the geometry: gate, district bounds, which quarter every special plot is in
#   E1  the SPATIAL PUZZLE's true ceiling -- a hill-climb over the row order,
#       reporting the best total building_output_multiplier the layout rules allow
#   E2  the REAL economy under four towns (naive/tuned x level 1/level 6):
#       gold to the player, gold to the treasury, stores hauled, food grown
#   E3  what the same real minute pays in the DUNGEON, using the marathon sim's
#       own floor model (floor_minutes + the real depth_reward_mult rewards)
#   E4  the verdict lines
#
# ASSUMPTIONS (stated, per the brief)
#   * A PERFECTLY-PLAYED town: 80 souls, every building operational and staffed,
#     every leadership seat filled, larder full, everyone housed and paired.
#     This is deliberately the ceiling -- the question asked was what an
#     OPTIMISED late village earns, so an average one would earn strictly less.
#   * Layout is imposed by writing the same four caches refresh_layout() writes,
#     computed with GameState's OWN district_at()/plot_at(). Nothing is faked:
#     building_output_multiplier reads exactly what it reads in play.
#   * Sieges/caravans/wanderers are pinned off so the reading is the ECONOMY and
#     not a raid roll. Same seed and same painted town for every scenario.
#   * One in-game day = 600 real seconds, so 1 real minute = 2.4 game hours.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)
func say(t: String) -> void: printerr(t)

var p: Node = null

const REAL_SEC_PER_GAME_HOUR := 25.0        # 600s day / 24h
const GAME_HOURS_PER_REAL_MIN := 2.4
const INCOME_TICK_HOURS := 0.8              # INCOME_INTERVAL_SECONDS(20) / 25
const MEASURE_HOURS := 240.0                # 10 in-game days = 100 real minutes

var _income_accum := 0.0
var _t0 := 0

func mark(what: String) -> void:
	var now: int = Time.get_ticks_msec()
	printerr("      [%.1fs] %s" % [float(now - _t0) / 1000.0, what])

# ------------------------------------------------------------------ clock
# Faithful to _process: the clock ticks every frame, income+automation fire on
# their OWN 20-real-second timer. The old balance sim fired income once per
# simulated hour, which under-counted every gold figure by 20%.
var pin_pop := false

func advance(hours: float) -> void:
	var stepped := 0.0
	while stepped < hours:
		var step: float = minf(1.0, hours - stepped)
		GameState.game_hours += step
		GameState.tick_village_clock()
		_income_accum += step
		while _income_accum >= INCOME_TICK_HOURS:
			_income_accum -= INCOME_TICK_HOURS
			GameState.generate_passive_income()
			GameState.apply_leadership_automation()
		# POPULATION PINNED (the controlled run): couples stay housed, paired and
		# happy -- morale, auras and the tax roll are untouched -- but no pregnancy
		# is ever carried to term, so every scenario is measured over the SAME 80
		# souls. Without this the roster doubles inside the window and the "layout"
		# figure is really a birth-rate figure.
		if pin_pop:
			GameState.pregnancies = {}
		stepped += step

# ------------------------------------------------------------------ layout
# THE GATE, read once. district_at() re-scans the scene tree for the west wall on
# EVERY call; the layout search below evaluates hundreds of thousands of rows, so
# the same answer is cached here and the district is derived with district_at's
# own arithmetic. (Verified identical against district_at in E0.)
var _gate := 0.0
var _geom: Dictionary = {}      # x -> {"d": district, "p": plot_id}

func gate_x() -> float:
	var g: float = GameState.SURFACE_WEST_FALLBACK_X
	var t := get_tree()
	if t != null:
		for w in t.get_nodes_in_group("village_wall"):
			if "flank" in w and str(w.flank) == "west":
				g = w.global_position.x
				break
	return g

func geom_of(x: float) -> Dictionary:
	if _geom.has(x):
		return _geom[x]
	var east: float = x - _gate
	var d := "outskirts"
	if east <= GameState.DISTRICT_GATEFRONT_DEPTH:
		d = "gatefront"
	elif east <= GameState.DISTRICT_HEART_DEPTH:
		d = "heart"
	var plot: Dictionary = GameState.plot_at(x)
	var g := {"d": d, "p": str(plot["id"]) if not plot.is_empty() else ""}
	_geom[x] = g
	return g

# Exactly what refresh_layout() does, but off a chosen row instead of the live
# bodies -- so a scenario can stand its town anywhere without moving a node.
func apply_layout(places: Dictionary) -> void:
	var row: Array = []
	for bn in places.keys():
		row.append({"name": str(bn), "x": float(places[bn])})
	row.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
	var nb: Dictionary = {}
	var dist: Dictionary = {}
	var plots: Dictionary = {}
	var xs: Dictionary = {}
	for i in range(row.size()):
		var bn2: String = str(row[i]["name"])
		var bx: float = float(row[i]["x"])
		var g: Dictionary = geom_of(bx)
		xs[bn2] = bx
		nb[bn2] = [
			str(row[i - 1]["name"]) if i > 0 else "",
			str(row[i + 1]["name"]) if i < row.size() - 1 else "",
		]
		dist[bn2] = str(g["d"])
		plots[bn2] = str(g["p"])
	GameState.building_neighbors = nb
	GameState.building_districts = dist
	GameState.building_plots = plots
	GameState.building_x = xs

func total_multiplier(names: Array) -> float:
	var t := 0.0
	for bn in names:
		t += GameState.building_output_multiplier(str(bn))
	return t

# ------------------------------------------------------------------ the town
const LEADER_OF := {
	"Government": "Chancellor", "School": "Principal", "Farm": "Harvestmaster",
	"Hospital": "Chief Physician", "Barracks": "Warchief", "Fishing Dock": "Harbormaster",
	"Science Lab": "Lead Researcher", "Bank": "Treasurer", "Blacksmith": "Forgemaster",
	"Tavern": "Tavernkeeper", "Bar": "Publican", "Marketplace": "Merchant Prince",
	"Builderhouse": "Master Builder", "Mine": "Pitmaster",
}
# The worker post + the stat that qualifies for it (building_roles.gd).
const WORKER_OF := {
	"Government": ["Party", ""], "School": ["Teachers", ""], "Farm": ["Farmer", "Farm"],
	"Hospital": ["Doctors", "Hospital"], "Barracks": ["Warrior", "Warrior"],
	"Fishing Dock": ["Fisherman", "Fishing"], "Science Lab": ["Researcher", "Science"],
	"Bank": ["Clerk", "Banking"], "Blacksmith": ["Blacksmith", "Blacksmith"],
	"Tavern": ["Barman", "Tavern"], "Bar": ["Barkeep", "Tavern"],
	"Marketplace": ["Trader", "Marketplace"], "Builderhouse": ["Builder", "Builder"],
	"Mine": ["Miner", "Mine"], "Shrine": ["Lightkeeper", "Hospital"],
}
# How many WORKERS each hall gets in the painted 80-soul town. Food-first, the
# same shape a player who keeps their larder full would run.
const CREW := {
	"Farm": 8, "Fishing Dock": 6, "Mine": 6, "Builderhouse": 5, "Blacksmith": 4,
	"Government": 4, "Bank": 4, "Marketplace": 4, "Science Lab": 4, "School": 3,
	"Bar": 3, "Tavern": 3, "Hospital": 4, "Barracks": 6, "Shrine": 2,
}
const COTTAGE_X0 := 12000.0
const COTTAGE_SPACING := 170.0

var _vid := 0
func mk(sex: String, stat: String, role: String, title: String) -> Dictionary:
	_vid += 1
	return {"id": "e_%d" % _vid, "name": "E%d" % _vid, "sex": sex, "is_kid": false,
		"stat_name": stat, "stat_value": 5, "role_key": role, "role_title": title,
		"morale": 8.0}

# A perfectly-run late town: 15 halls up, every leader seated, every crew filled,
# everybody housed and paired, larder deep. Identical for every scenario -- only
# the LAYOUT and the LEVELS change between runs.
#   halls    -- which buildings stand at all ([] = all fifteen)
#   crew_div -- 1 = full crews; 2 = a half-staffed mid-game town
func paint_town(halls: Array = [], crew_div: int = 1) -> void:
	GameState.reset_for_new_game()
	GameState.opening_done = true
	GameState.dev_mode = false
	GameState.village_last_hours_elapsed = GameState.game_hours
	GameState.hours_until_next_siege = 999999.0
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.mating_houses = {}
	GameState.pregnancies = {}
	GameState.school_enrollments = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	GameState.extra_cottages = 0
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	GameState.village_treasury = 0
	GameState.villager_rot = {}
	GameState.villager_hp = {}
	GameState.sick = {}
	GameState.building_levels = {}
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState.wanderer = {}
	_vid = 0
	_income_accum = 0.0
	var up: Array = halls if not halls.is_empty() else GameState.STARTING_BUILDINGS
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES if b in up else 0
		GameState.building_health[b] = 100 if b in up else 0
	# leaders first (the automation ladder only runs with seats filled)
	for b in LEADER_OF.keys():
		if not (b in up):
			continue
		GameState.rescued_villagers.append(
			mk("Female" if _vid % 2 == 0 else "Male", str(LEADER_OF[b]), str(b), str(LEADER_OF[b])))
	# ...then the crews
	for b in CREW.keys():
		if not (b in up):
			continue
		var wd: Array = WORKER_OF[b]
		for i in range(maxi(1, int(CREW[b]) / maxi(1, crew_div))):
			GameState.rescued_villagers.append(
				mk("Male" if i % 2 == 0 else "Female", str(wd[1]), str(b), str(wd[0])))
	# house and pair everyone into a real cottage ROW (so the auras have somewhere
	# to point, and villager_places resolves)
	var vs: Array = GameState.rescued_villagers
	var hi := 0
	for j in range(0, vs.size() - 1, 2):
		var hid: String = GameState.register_cottage(COTTAGE_X0 + COTTAGE_SPACING * float(hi))
		hi += 1
		vs[j]["partner_id"] = str(vs[j + 1]["id"])
		vs[j + 1]["partner_id"] = str(vs[j]["id"])
		vs[j]["paired"] = true
		vs[j + 1]["paired"] = true
		GameState.cottage_homes[hid] = {"a": str(vs[j]["id"]), "b": str(vs[j + 1]["id"])}
	GameState.village_food = 4000.0

func pop() -> int:
	return GameState.rescued_villagers.size()

# ------------------------------------------------------------------ scenarios
func run_economy(label: String, places: Dictionary, level: int, away: bool,
		pinned := true, halls: Array = [], crew_div: int = 1) -> Dictionary:
	seed(20260806)
	pin_pop = pinned
	paint_town(halls, crew_div)
	for b in GameState.STARTING_BUILDINGS:
		GameState.building_levels[b] = level
	apply_layout(places)
	GameState.in_dungeon = away
	p.currency = 0
	# settle spirits at their targets first, so the measured window is steady state
	advance(48.0)
	p.currency = 0
	var t0: int = GameState.village_treasury
	var s0 := {"wood": int(GameState.village_stockpile["wood"]),
		"stone": int(GameState.village_stockpile["stone"]),
		"iron_shard": int(GameState.village_stockpile["iron_shard"])}
	var f0: float = GameState.village_food
	var arms0: int = GameState.barracks_arms
	advance(MEASURE_HOURS)
	GameState.in_dungeon = false
	var names: Array = GameState.STARTING_BUILDINGS
	var out := {
		"label": label,
		"mult_total": total_multiplier(names),
		"mult_mean": total_multiplier(names) / float(names.size()),
		"gold": float(p.currency),
		"treasury": float(GameState.village_treasury - t0),
		"wood": float(int(GameState.village_stockpile["wood"]) - s0["wood"]),
		"stone": float(int(GameState.village_stockpile["stone"]) - s0["stone"]),
		"iron": float(int(GameState.village_stockpile["iron_shard"]) - s0["iron_shard"]),
		"food": float(GameState.village_food - f0),
		"arms": float(GameState.barracks_arms - arms0),
		"morale": float(GameState.village_morale()),
		"pop": float(pop()),
	}
	out["coin_per_hour"] = (out["gold"] + out["treasury"]) / MEASURE_HOURS
	out["coin_per_realmin"] = out["coin_per_hour"] * GAME_HOURS_PER_REAL_MIN
	return out

func report(r: Dictionary) -> void:
	say("  %-22s  mult %.3f avg | %7.1f g/h  (%6.1f g per real-min) | purse %5d  treasury %5d" % [
		str(r["label"]), float(r["mult_mean"]), float(r["coin_per_hour"]),
		float(r["coin_per_realmin"]), int(r["gold"]), int(r["treasury"])])
	say("      %sstores: %d wood, %d stone, %d iron | food %+.0f | arms %+d | morale %d | pop %d" % [
		" ".repeat(18), int(r["wood"]), int(r["stone"]), int(r["iron"]),
		float(r["food"]), int(r["arms"]), int(r["morale"]), int(r["pop"])])

# ------------------------------------------------------------------ the search
# The layout rules are ORDINAL for adjacency (a pair fires if nothing stands
# between them, at any distance) and POSITIONAL for district + plot. That is a
# real combinatorial puzzle, so the honest way to say "what a well-optimised
# village earns" is to SEARCH for the best row rather than to eyeball one.
func slot_pool() -> Array:
	var gate: float = _gate
	var slots: Array = []
	for plot in GameState.SPECIAL_PLOTS:                 # the seven rich spots
		slots.append(float(plot["x"]))
	# fillers spread through each quarter, kept clear of every plot's radius
	var cand: Array = []
	var x: float = gate + 200.0
	while x < gate + 17000.0:
		cand.append(x)
		x += 420.0
	for c in cand:
		var clear := true
		for plot2 in GameState.SPECIAL_PLOTS:
			if absf(float(c) - float(plot2["x"])) <= GameState.PLOT_RADIUS + 60.0:
				clear = false
				break
		if clear:
			slots.append(float(c))
	slots.sort()
	return slots

# The row a careful player would reason their way to: every building on its own
# plot where it has one, otherwise a filler inside its home quarter, ordered so
# that as many ADJACENCY_PAIRS as possible land consecutively. The search below
# starts one of its restarts here, so a blind hill-climb can never report a
# WORSE answer than a thinking player would find by hand.
func textbook_layout() -> Dictionary:
	var g: float = _gate
	return {
		# gatefront: the war quarter. Blacksmith beside the drill yard.
		"Hospital": g + 1100.0, "Blacksmith": g + 1700.0, "Barracks": 7000.0,
		# the heart: three pairs chained, the Chancellor's hall on the end.
		"Government": g + 4900.0, "Science Lab": g + 5700.0, "School": g + 6500.0,
		"Bank": g + 7300.0, "Marketplace": 13200.0, "Bar": g + 9100.0, "Tavern": g + 9400.0,
		# the working land: every plot worked, both outskirts pairs chained.
		"Farm": 15800.0, "Fishing Dock": 16650.0, "Builderhouse": 17300.0,
		"Mine": 18200.0, "Shrine": 20200.0,
	}

func optimise_layout(names: Array, restarts: int, steps: int) -> Dictionary:
	var slots: Array = slot_pool()
	var best: Dictionary = {}
	var best_score := -1.0
	for r in range(restarts):
		var cur: Dictionary = {}
		if r == 0:
			cur = textbook_layout()
		else:
			var used: Array = []
			for bn in names:
				var s: float = 0.0
				for _try in range(200):
					s = float(slots[randi() % slots.size()])
					if not used.has(s):
						break
				used.append(s)
				cur[str(bn)] = s
		apply_layout(cur)
		var score: float = total_multiplier(names)
		for _st in range(steps):
			var moved := false
			# move ONE building to a free slot, or swap two -- keep it if it pays
			for _k in range(48):
				var bn2: String = str(names[randi() % names.size()])
				var trial: Dictionary = cur.duplicate()
				if randf() < 0.5:
					var s2: float = float(slots[randi() % slots.size()])
					var occupied := false
					for k in trial.keys():
						if str(k) != bn2 and is_equal_approx(float(trial[k]), s2):
							occupied = true
							break
					if occupied:
						continue
					trial[bn2] = s2
				else:
					var bn3: String = str(names[randi() % names.size()])
					if bn3 == bn2:
						continue
					var tmp: float = float(trial[bn2])
					trial[bn2] = float(trial[bn3])
					trial[bn3] = tmp
				apply_layout(trial)
				var ns: float = total_multiplier(names)
				if ns > score + 0.0001:
					cur = trial
					score = ns
					moved = true
					break
			if not moved:
				break
		if score > best_score:
			best_score = score
			best = cur.duplicate()
	return {"places": best, "score": best_score}

# The worst honest row: everything crammed west of the gate in one clump, so
# nobody stands in their own quarter, nobody works a plot, and (by ordering the
# clump so no ADJACENCY_PAIR is ever consecutive) no synergy fires either.
func naive_layout(names: Array) -> Dictionary:
	var order: Array = ["Farm", "Government", "Mine", "School", "Blacksmith",
		"Bank", "Fishing Dock", "Marketplace", "Builderhouse", "Science Lab",
		"Shrine", "Bar", "Hospital", "Tavern", "Barracks"]
	var gate: float = _gate
	var out: Dictionary = {}
	var i := 0
	for bn in order:
		if not names.has(bn):
			continue
		out[str(bn)] = gate + 300.0 + 220.0 * float(i)
		i += 1
	return out

# ------------------------------------------------------------------ the deep
# The marathon sim's own dungeon model, so the two halves of the economy are
# measured on the same ruler: ~9 grunts a floor at the REAL depth_reward_mult
# rewards, a boss every fifth, and floor_minutes of real time to walk it.
func floor_minutes(f: int) -> float:
	var base := 2.2 + 0.06 * float(f)
	if f % 5 == 0:
		base += 2.0
	return base

func delve_gold_per_real_min(f: int) -> float:
	var saved: bool = GameState.in_dungeon
	var saved_lv: int = GameState.active_dungeon_level
	GameState.in_dungeon = true
	GameState.active_dungeon_level = f
	var mult: float = GameState.depth_reward_mult()
	GameState.in_dungeon = saved
	GameState.active_dungeon_level = saved_lv
	var gold := 9.0 * 5.0 * mult
	if f % 5 == 0:
		gold += 40.0 * mult
	return gold / floor_minutes(f)

# ...and what the FLOOR'S LOOT is worth if the player liquidates every scrap of
# it. The marathon's real drop model (roll_construction_drop + the potion rule +
# the ~60% cache), priced through Inventory.sell_value. This is the CEILING of
# the delve's second stream: nobody really sells every potion they find.
const CACHE_BASE := ["potion_health", "potion_mana", "iron_shard", "ember_crystal",
	"coin_gold", "herb", "resin"]

func delve_loot_per_real_min(f: int, reps: int) -> float:
	var total := 0.0
	for _r in range(reps):
		var bag: Dictionary = {}
		for _k in range(9):
			# GameState's OWN drop table (roll_construction_drop needs a live
			# inventory to write into, so the roll is reproduced, not the table)
			var r: float = randf()
			var acc: float = 0.0
			for entry in GameState.CONSTRUCTION_DROP_TABLE:
				acc += float(entry[1])
				if r < acc:
					bag[str(entry[0])] = int(bag.get(str(entry[0]), 0)) + 1
					break
			if randf() < 0.25:
				bag["raw_meat"] = int(bag.get("raw_meat", 0)) + 1
			if f <= 30 and randf() < 0.06:
				bag["slime"] = int(bag.get("slime", 0)) + 1
			if (f - 1) % 5 + 1 >= 4:
				if randf() < 0.16: bag["potion_health"] = int(bag.get("potion_health", 0)) + 1
				if randf() < 0.12: bag["potion_mana"] = int(bag.get("potion_mana", 0)) + 1
		if randf() < 0.6:
			var table: Array = CACHE_BASE.duplicate()
			if f <= 30: table.append("slime")
			if f >= 40: table += ["void_essence", "ancient_relic"]
			var pick: String = str(table[randi() % table.size()])
			bag[pick] = int(bag.get(pick, 0)) + 1
		for id in bag.keys():
			total += float(Inventory.sell_value(str(id))) * float(bag[id])
	return (total / float(reps)) / floor_minutes(f)

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
	_t0 = Time.get_ticks_msec()
	_gate = gate_x()

	var names: Array = GameState.STARTING_BUILDINGS

	# ---------------- E0: the ground itself ----------------
	say("\n===================== E0: THE GROUND =====================")
	var gate: float = _gate
	say("  west gate x=%.0f   gatefront <= %.0f   heart <= %.0f   outskirts beyond" % [
		gate, gate + GameState.DISTRICT_GATEFRONT_DEPTH, gate + GameState.DISTRICT_HEART_DEPTH])
	# the cached-geometry shortcut must agree with district_at() itself
	var geom_drift := 0
	for probe in [gate - 500.0, gate + 1.0, gate + 4499.0, gate + 4501.0,
			gate + 9499.0, gate + 9501.0, gate + 15000.0, 7000.0, 13200.0, 20200.0]:
		if str(geom_of(float(probe))["d"]) != GameState.district_at(float(probe)):
			geom_drift += 1
	check("E0: the sim's cached geometry agrees with district_at() everywhere probed",
		geom_drift == 0, "%d disagreements" % geom_drift)
	var plot_ok := 0
	for plot in GameState.SPECIAL_PLOTS:
		var bn: String = str(plot["building"])
		var d: String = GameState.district_at(float(plot["x"]))
		var home: String = str(GameState.DISTRICT_HOME.get(bn, ""))
		var agree: bool = d == home
		if agree: plot_ok += 1
		say("   plot %-7s x=%-6.0f %-10s  %s wants %-10s  -> %s" % [
			str(plot["id"]), float(plot["x"]), d, bn, home,
			"plot AND quarter" if agree else "PLOT FIGHTS QUARTER"])
	check("E0: every special plot sits inside its own building's home quarter",
		plot_ok == GameState.SPECIAL_PLOTS.size(), "%d of %d" % [plot_ok, GameState.SPECIAL_PLOTS.size()])

	# ---------------- E1: how much the puzzle can possibly pay ----------------
	say("\n============ E1: THE SPATIAL PUZZLE'S CEILING ============")
	for b in names:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100
		GameState.building_levels[b] = 1
	var theoretical: float = 1.0 + GameState.ADJACENCY_BONUS_CAP + GameState.DISTRICT_BONUS + GameState.PLOT_BONUS
	var theoretical6: float = theoretical + 5.0 * GameState.BUILDING_OUTPUT_PER_LEVEL
	say("  per-building ceiling by the constants: L1 %.2fx   L6 %.2fx" % [theoretical, theoretical6])
	var naive: Dictionary = naive_layout(names)
	apply_layout(naive)
	var naive_mult: float = total_multiplier(names) / float(names.size())
	say("  naive row (one clump west of the gate): mean multiplier %.3f" % naive_mult)
	apply_layout(textbook_layout())
	var book_mult: float = total_multiplier(names) / float(names.size())
	say("  textbook row (every plot worked, every quarter right, pairs chained):")
	say("                                          mean multiplier %.3f" % book_mult)
	mark("E1 search starting")
	var found: Dictionary = optimise_layout(names, 80, 900)
	mark("E1 search done")
	var tuned: Dictionary = found["places"]
	apply_layout(tuned)
	var tuned_mult: float = total_multiplier(names) / float(names.size())
	say("  hill-climbed best row:                  mean multiplier %.3f  (total %.2f)" % [
		tuned_mult, float(found["score"])])
	say("  the winning row, west to east:")
	var row2: Array = []
	for bn in tuned.keys():
		row2.append({"n": str(bn), "x": float(tuned[bn])})
	row2.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
	for e in row2:
		var bn3: String = str(e["n"])
		var links: Array = GameState.adjacency_links(bn3)
		var lnames: Array = []
		for l in links:
			lnames.append("%s+%.0f%%" % [str(l["partner"]), float(l["bonus"]) * 100.0])
		say("    %-14s x=%-6.0f %-10s %s%s  =%.2fx  %s" % [
			bn3, float(e["x"]), GameState.building_district(bn3),
			"[quarter]" if GameState.district_bonus(bn3) > 0.0 else "         ",
			"[plot]" if GameState.plot_bonus(bn3) > 0.0 else "      ",
			GameState.building_output_multiplier(bn3),
			", ".join(lnames)])
	var spread_pct: float = 100.0 * (tuned_mult / naive_mult - 1.0)
	say("  SPREAD, layout alone (both level 1): naive %.3f -> tuned %.3f = %+.1f%% output" % [
		naive_mult, tuned_mult, spread_pct])
	check("E1: the spatial puzzle is worth more than a rounding error (>=15%)",
		spread_pct >= 15.0, "%.1f%%" % spread_pct)

	# ---------------- E2: what the town actually pays ----------------
	say("\n=========== E2: THE REAL ECONOMY, %d IN-GAME DAYS ===========" % int(MEASURE_HOURS / 24.0))
	say("  (80 souls, every hall up + staffed + led, larder deep, sieges pinned off)")
	say("  (player AWAY in the deep -- this is the passive stream)")
	say("  -- POPULATION PINNED at 80: the same tax roll in every row, so this")
	say("     isolates LAYOUT and LEVEL from the birth rate --")
	var res: Array = []
	res.append(run_economy("naive row, L1", naive, 1, true)); mark("E2 run 1/6")
	res.append(run_economy("naive row, L6", naive, 6, true)); mark("E2 run 2/6")
	res.append(run_economy("tuned row, L1", tuned, 1, true)); mark("E2 run 3/6")
	res.append(run_economy("tuned row, L6", tuned, 6, true)); mark("E2 run 4/6")
	for r in res:
		report(r)
	var home: Dictionary = run_economy("tuned L6, AT HOME", tuned, 6, false)
	mark("E2 run 5/6")
	report(home)
	var base_gph: float = float(res[0]["coin_per_hour"])
	var best_gph: float = float(res[3]["coin_per_hour"])
	var lvl_gph: float = float(res[1]["coin_per_hour"])
	var lay_gph: float = float(res[2]["coin_per_hour"])
	say("\n  gold/hour: naive-L1 %.1f -> +levels %.1f (%+.0f%%) -> +layout %.1f (%+.0f%%) -> both %.1f (%+.0f%%)" % [
		base_gph, lvl_gph, 100.0 * (lvl_gph / base_gph - 1.0),
		lay_gph, 100.0 * (lay_gph / base_gph - 1.0),
		best_gph, 100.0 * (best_gph / base_gph - 1.0)])
	say("\n  ...and the same tuned-L6 town with the CRADLES LEFT RUNNING (the real game):")
	var live: Dictionary = run_economy("tuned L6, births ON", tuned, 6, true, false)
	mark("E2 run 6/6")
	report(live)
	say("  the town grew 80 -> %d souls in %d in-game days, and its gold/hour rose %.0f%%." % [
		int(live["pop"]), int(MEASURE_HOURS / 24.0),
		100.0 * (float(live["coin_per_hour"]) / best_gph - 1.0)])
	var cradle_days: float = MEASURE_HOURS / 24.0
	say("  that is one new soul per couple per %.1f in-game days (%.0f real minutes)." % [
		cradle_days / maxf(0.01, (float(live["pop"]) - 80.0) / 40.0),
		(cradle_days / maxf(0.01, (float(live["pop"]) - 80.0) / 40.0)) * 600.0 / 60.0])
	check("E2: a maxed town does not DOUBLE its population in %d in-game days" % int(cradle_days),
		float(live["pop"]) < 160.0, "80 -> %d souls" % int(live["pop"]))

	# ---------------- E2b: the same question, halfway down ----------------
	# The late town above is what a player HAS at floor 80+. To read the arc
	# honestly the mid-game town has to be measured too: ~floor 35, every
	# blueprint in hand (they land by 30) but only the halls a player has had
	# time and gold to raise, half-crewed, unplanned row, level 2.
	say("\n=========== E2b: THE MID-GAME TOWN (about floor 35) ===========")
	var mid_halls: Array = ["Farm", "Fishing Dock", "Mine", "Government", "Bank",
		"Bar", "Tavern", "Hospital", "Builderhouse", "School", "Barracks", "Blacksmith"]
	var mid: Dictionary = run_economy("mid town, naive, L2", naive, 2, true, true, mid_halls, 2)
	mark("E2b done")
	report(mid)

	# ---------------- E3: what the deep pays for the same minute ----------------
	say("\n=========== E3: THE SAME REAL MINUTE, SPENT DELVING ===========")
	say("  Coin = kill + boss gold only. Loot = every scrap of the floor's drops")
	say("  liquidated at Inventory.sell_value (the delve's absolute CEILING --")
	say("  nobody sells every potion). The truth sits between the two columns.")
	say("  floor |  coin/min |  loot/min |  total  | village tuned-L6 | verdict")
	var village_per_min: float = float(res[3]["coin_per_realmin"])
	var mid_per_min: float = float(mid["coin_per_realmin"])
	var delve_total := {}
	for f in [1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 99]:
		var c: float = delve_gold_per_real_min(int(f))
		var l: float = delve_loot_per_real_min(int(f), 400)
		delve_total[int(f)] = c + l
		say("   %3d  | %8.1f  | %8.1f  | %7.1f | %8.1f         | %s" % [
			int(f), c, l, c + l, village_per_min,
			"DELVE x%.2f" % ((c + l) / maxf(0.01, village_per_min)) if c + l > village_per_min
				else "village wins by x%.2f" % (village_per_min / maxf(0.01, c + l))])
	say("\n  THE ARC, each town against the depth a player would BE at:")
	say("    mid town (floor ~35): %6.1f g/real-min passive  vs  %6.1f delving floor 35  -> delve x%.2f" % [
		mid_per_min, float(delve_total[30]), float(delve_total[30]) / maxf(0.01, mid_per_min)])
	say("    late town (floor ~80): %6.1f g/real-min passive  vs  %6.1f delving floor 80  -> delve x%.2f" % [
		village_per_min, float(delve_total[80]), float(delve_total[80]) / maxf(0.01, village_per_min)])
	mark("E3 done")
	var d50: float = float(delve_total[50])
	var d90: float = float(delve_total[90])
	check("E3: the deep out-earns a maxed village at mid depth (floor 50)",
		d50 > village_per_min, "delve %.1f vs village %.1f g/real-min" % [d50, village_per_min])
	check("E3: ...and still does at the bottom (floor 90)",
		d90 > village_per_min, "delve %.1f vs village %.1f g/real-min" % [d90, village_per_min])
	check("E3: ...but the village is a real second stream, not a rounding error (>=10% of floor-50 delving)",
		village_per_min >= 0.10 * d50,
		"village %.1f vs delve %.1f" % [village_per_min, d50])

	# ---------------- E4: the sinks the village has to fill ----------------
	say("\n=========== E4: WHAT THE GOLD IS FOR ===========")
	var BLD = load("res://building.gd")
	var bld = BLD.new()
	var ladder := 0
	for lvl in range(1, BLD.MAX_LEVEL):
		bld.building_level = lvl
		ladder += bld.upgrade_cost()
	bld.free()
	var town_cost: int = ladder * names.size()
	say("  maxing one hall: %dg    maxing all %d: %dg" % [ladder, names.size(), town_cost])
	say("  a tuned L6 village pays for the WHOLE town ladder in %.0f in-game days (%.0f real minutes)" % [
		float(town_cost) / maxf(0.01, best_gph) / 24.0,
		float(town_cost) / maxf(0.01, best_gph) / GAME_HOURS_PER_REAL_MIN])

	GameState.reset_for_new_game()
	printerr("\ntool_econ_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
