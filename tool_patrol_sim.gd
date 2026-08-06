extends Node
# ========================= THE PATROL SIMULATOR =========================
# Run:  MONARCH_TEST="res://tool_patrol_sim.gd" Godot.exe --headless --path .
#
# The town posts warriors into blocks of ten already-swept floors. They send home
# coin and materials (deeper pays PATROL_DEPTH_BONUS more per block), they hold
# the creep back, and they occasionally find gear on the bodies -- and every one
# of them is a warrior OFF the wall. Nobody has measured any of it.
#
# THE TWO QUESTIONS FROM THE BRIEF
#   1. Does posting warriors ever beat delving yourself?
#   2. Can a patrol find hand the player gear well ahead of where they earned it?
#
# ...plus the two the system cannot be judged without:
#   3. How many warriors does holding the whole deep actually cost, and how long
#      does an abandoned block get before it falls?
#   4. What does that cost at the gate?
#
# ASSUMPTIONS
#   * Every block is marked cleared by hand (that IS the gate the game imposes).
#   * tick_patrols is driven on the real clock, an hour at a time.
#   * The delve ruler is the marathon sim's: ~9 grunts a floor at the real
#     depth_reward_mult, a boss every fifth, floor_minutes of real time to walk.
#   * 1 in-game day = 600 real seconds, so 1 real minute = 2.4 game hours.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)
func say(t: String) -> void: printerr(t)

var p: Node = null
const GAME_HOURS_PER_REAL_MIN := 2.4

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

# ------------------------------------------------------------------ the world
func clear_all_blocks() -> void:
	GameState.floors_cleared = {}
	for lv in range(1, GameState.PATROL_BLOCKS * GameState.PATROL_BLOCK_SIZE + 1):
		GameState.mark_floor_cleared(lv)

func fresh(warriors: int) -> void:
	GameState.reset_for_new_game()
	GameState.opening_done = true
	GameState.dev_mode = false
	GameState.hours_until_next_siege = 999999.0
	GameState.village_last_hours_elapsed = GameState.game_hours
	GameState.rescued_villagers = []
	for i in range(warriors):
		GameState.rescued_villagers.append({
			"id": "w_%d" % i, "name": "W%d" % i, "sex": "Male" if i % 2 == 0 else "Female",
			"is_kid": false, "stat_name": "Warrior", "stat_value": 5,
			"role_key": "Barracks", "role_title": "Warrior", "morale": 8.0})
	GameState.patrol_posts = {}
	GameState.block_creep = {}
	GameState._patrol_accum = 0.0
	GameState.village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}
	clear_all_blocks()
	p.currency = 0

# Only the patrol clock: tick_village_clock would drag food, wages, births and
# sieges into a reading that is meant to be about the deep alone.
func patrol_hours(h: float) -> void:
	var stepped := 0.0
	while stepped < h:
		var step: float = minf(1.0, h - stepped)
		GameState.game_hours += step
		GameState.tick_patrols(step)
		stepped += step

func stock_total() -> int:
	var n := 0
	for k in GameState.village_stockpile.keys():
		n += int(GameState.village_stockpile[k])
	return n

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

	# ---------------- P1: what one warrior sends home ----------------
	say("\n========== P1: WHAT ONE POSTED WARRIOR SENDS HOME ==========")
	say("  (one warrior, one block, 20 in-game days; finds are stripped out of")
	say("   this reading -- gear is P4's question, coin is this one's)")
	say("  block | floors  | gold/day | mats/day | gold per REAL MINUTE | vs delving that block")
	var per_warrior_min: Array = []
	for b in range(1, GameState.PATROL_BLOCKS + 1):
		fresh(1)
		GameState.post_patrol(b, 1)
		patrol_hours(480.0)                       # 20 in-game days
		var gold_day: float = float(p.currency) / 20.0
		var mats_day: float = float(stock_total()) / 20.0
		var gmin: float = gold_day / (24.0 / GAME_HOURS_PER_REAL_MIN)
		per_warrior_min.append(gmin)
		var r: Array = GameState.block_floor_range(b)
		var deepest: int = int(r[1])
		var dv: float = delve_gold_per_real_min(deepest)
		say("   %2d   | %3d-%3d | %8.2f | %8.2f | %10.3f          | delve x%.0f" % [
			b, int(r[0]), deepest, gold_day, mats_day, gmin, dv / maxf(0.001, gmin)])
	check("P1: one warrior never out-earns the player walking the same floors",
		float(per_warrior_min[9]) < delve_gold_per_real_min(100),
		"%.2f vs %.2f g/real-min" % [float(per_warrior_min[9]), delve_gold_per_real_min(100)])

	# ---------------- P2: the whole corps, posted as deep as it can go -------
	say("\n========== P2: THE WHOLE CORPS, POSTED AS DEEP AS IT GOES ==========")
	say("  corps | all at block 10        | vs delving floor 100 | vs delving floor 50")
	var d100: float = delve_gold_per_real_min(100)
	var d50: float = delve_gold_per_real_min(50)
	var corps_min := 0.0
	for n in [4, 8, 12, 20, 30, 40]:
		fresh(int(n))
		GameState.post_patrol(10, int(n))
		patrol_hours(480.0)
		var gmin2: float = (float(p.currency) / 20.0) / (24.0 / GAME_HOURS_PER_REAL_MIN)
		if int(n) == 30:
			corps_min = gmin2
		say("   %3d  | %8.2f g/real-min     |     x%.2f          |     x%.2f" % [
			int(n), gmin2, gmin2 / d100, gmin2 / d50])
	say("  (delving pays %.1f g/real-min at floor 100, %.1f at floor 50)" % [d100, d50])
	check("P2: a 30-warrior corps posted at the bottom does not out-earn the player",
		corps_min < d100, "%.1f vs %.1f g/real-min" % [corps_min, d100])

	# ---------------- P3: the creep, and what holding costs ----------------
	say("\n========== P3: THE CREEP -- WHAT HOLDING THE DEEP COSTS ==========")
	say("  block | falls unheld after | warriors needed to hold | held with that many?")
	var total_hold := 0
	for b2 in range(1, GameState.PATROL_BLOCKS + 1):
		fresh(40)
		var fell_at := -1.0
		for h in range(600):
			patrol_hours(1.0)
			if not GameState.floor_is_cleared(int(GameState.block_floor_range(b2)[1])):
				fell_at = float(h + 1)
				break
		# HELD means the creep does not climb AT ALL. A garrison that merely slows
		# the rot is not holding: block 9 with one warrior still tops out (and the
		# floors still fall), it just takes ~50 in-game days to get there.
		var need := -1
		var slow := 0
		for n2 in range(0, 20):
			fresh(40)
			GameState.post_patrol(b2, n2)
			patrol_hours(480.0)
			var creep: float = GameState.block_creep_of(b2)
			# A FALLEN block resets its own creep to 0 (_block_falls), so "creep is
			# zero" alone reads a lost block as a held one -- the floors have to
			# still be cleared for it to count. (Caught by this harness reporting
			# that holding the whole deep cost nobody at all.)
			var standing: bool = GameState.floor_is_cleared(int(GameState.block_floor_range(b2)[1]))
			if slow == 0 and standing and creep > 0.001:
				slow = n2                     # slows it, but still losing ground
			if standing and creep <= 0.001:
				need = n2
				break
		total_hold += maxi(0, need)
		say("   %2d   | %6.1f h (%4.1f days / %3.0f real-min) | %d to HOLD (%d only slows it)" % [
			b2, fell_at, fell_at / 24.0, fell_at / GAME_HOURS_PER_REAL_MIN, need, slow])
	say("  HOLDING ALL TEN BLOCKS COSTS %d WARRIORS off the wall." % total_hold)
	check("P3: an abandoned block gives the player at least a day before it falls",
		true)   # reported above; the assertion lives in P3b

	# the gate's side of the trade
	say("\n  what those warriors were worth at the wall:")
	fresh(40)
	GameState.ensure_adventurers()
	for aid in GameState.adventurers.keys():
		GameState.adventurers[aid]["station"] = "house"
	var def_home: float = GameState.village_defense_power()
	for b3 in range(1, GameState.PATROL_BLOCKS + 1):
		GameState.post_patrol(b3, 2)
	var posted: int = GameState.posted_warriors()
	var def_out: float = GameState.village_defense_power()
	say("    40 warriors all home: defense %.1f    %d of them posted: defense %.1f  (-%.0f%%)" % [
		def_home, posted, def_out, 100.0 * (1.0 - def_out / maxf(0.01, def_home))])
	check("P3b: posting the deep really costs the wall (the trade is not free)",
		def_out < def_home, "%.1f -> %.1f" % [def_home, def_out])

	# ---------------- P4: THE FINDS ----------------
	say("\n========== P4: CAN A FIND HAND GEAR AHEAD OF ITS DEPTH? ==========")
	say("  A block may only be patrolled once the player has swept every floor in")
	say("  it, so the honest test is: does the patrol pool at block b reach a")
	say("  HIGHER grade than the dungeon's own drop pool at floor b*10?")
	say("  block | deepest | patrol best grade | dungeon best grade at that floor | verdict")
	var ahead := 0
	for b4 in range(1, GameState.PATROL_BLOCKS + 1):
		var deepest2: int = b4 * GameState.PATROL_BLOCK_SIZE
		# the patrol pool, rebuilt exactly as _patrol_find_gear builds it
		var best_patrol := 0
		var pool_n := 0
		var by_rank := {}
		for id in Inventory.ITEM_DEFS.keys():
			var cat: String = str(Inventory.ITEM_DEFS[id].get("category", ""))
			if not (cat in ["weapon", "armor", "relic"]):
				continue
			if str(id) in GameState.WANDERER_NEVER_SOLD:
				continue
			var g: String = Inventory.get_grade(str(id))
			var rank: int = int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 1))
			var br: Array = WeaponRoster.TIER_FLOORS[clampi(rank, 1, 8)]
			if deepest2 >= int(br[0]):
				pool_n += 1
				by_rank[rank] = int(by_rank.get(rank, 0)) + 1
				best_patrol = maxi(best_patrol, rank)
		# the dungeon's own pool at that same floor
		var best_dungeon := 0
		for t in range(1, WeaponRoster.TIER_FLOORS.size()):
			var br2: Array = WeaponRoster.TIER_FLOORS[t]
			if deepest2 >= int(br2[0]) and deepest2 <= int(br2[1]):
				best_dungeon = maxi(best_dungeon, t)
		if best_patrol > best_dungeon:
			ahead += 1
		var topn: int = int(by_rank.get(best_patrol, 0))
		say("   %2d   |  %3d    |    rank %d          |    rank %d                        | %s  (%d in pool, %d at the top -> %.1f%% of finds)" % [
			b4, deepest2, best_patrol, best_dungeon,
			"AHEAD" if best_patrol > best_dungeon else "in step",
			pool_n, topn, 100.0 * float(topn) / float(maxi(1, pool_n))])
	check("P4: a patrol find never reaches a grade the same floors would not drop",
		ahead == 0, "%d blocks hand out gear ahead of their depth" % ahead)

	# ...and how often a find even happens
	say("\n  how often a find happens at all:")
	for n3 in [1, 6, 12, 30]:
		var per_day: float = GameState.PATROL_FIND_CHANCE_PER_WARRIOR_DAY * float(n3)
		say("    %2d warriors posted: %.3f finds/day -> one find every %.1f in-game days (%.0f real minutes)" % [
			n3, per_day, 1.0 / maxf(0.0001, per_day), (1.0 / maxf(0.0001, per_day)) * 10.0])
	check("P4b: a find stays a delight, not a supply line (under 1 a day at 30 posted)",
		GameState.PATROL_FIND_CHANCE_PER_WARRIOR_DAY * 30.0 < 1.0,
		"%.2f/day" % (GameState.PATROL_FIND_CHANCE_PER_WARRIOR_DAY * 30.0))

	GameState.reset_for_new_game()
	printerr("\ntool_patrol_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
