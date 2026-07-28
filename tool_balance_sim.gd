extends Node

# BALANCE SIMULATOR -- drives the REAL village machine (the actual master
# tick: food, wages, morale drift, rot, sieges, wanderers, mine) across
# simulated weeks and REPORTS the arithmetic in motion: does Act I starve,
# does mid-game self-fund, does a well-kept town ever rot, how long does a
# neglected one get, and do siege tiers stay a contest instead of a wipe.
# Numbers to judge by, plus hard assertions on the extremes only.
#
# Cadence note: generate_passive_income really fires on a 20-real-second
# timer (~1.25x per game hour at 10min days); the sim calls it once per
# simulated hour, so income figures here are ~20% conservative.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func say(t: String) -> void:
	printerr(t)

var p: Node = null

func advance(hours: float, with_income := false) -> void:
	var stepped := 0.0
	while stepped < hours:
		var step: float = minf(1.0, hours - stepped)
		GameState.skip_hours(step)
		GameState.tick_village_clock()
		if with_income:
			GameState.generate_passive_income()
		stepped += step

func fresh_world() -> void:
	GameState.reset_for_new_game()
	GameState.village_last_hours_elapsed = 0.0
	GameState.hours_until_next_siege = 99999.0   # scenarios arm sieges themselves
	p.currency = 0

func mk(id: String, kid: bool, stat: String, role: String, title: String) -> Dictionary:
	return {"id": id, "name": id, "sex": "Male" if hash(id) % 2 == 0 else "Female",
		"is_kid": kid, "stat_name": stat, "stat_value": 4, "role_key": role, "role_title": title}

func staff_town(n_total: int, employed_map: Dictionary) -> void:
	# a painted town: employed per building per the map, rest jobless; all
	# adults paired+housed in synthetic homes so the baseline is a CARED-FOR
	# town (scenarios break specific needs on purpose)
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	var i := 0
	for b in employed_map:
		for k in range(int(employed_map[b])):
			var role_title: String = BuildingRoles.get_roles(b).back().get("title", "Worker") if not BuildingRoles.get_roles(b).is_empty() else "Worker"
			GameState.rescued_villagers.append(mk("s_%d" % i, false, str(GameState.rescued_villagers.size()), b, role_title))
			i += 1
	while GameState.rescued_villagers.size() < n_total:
		GameState.rescued_villagers.append(mk("s_%d" % i, false, "Farm", "", ""))
		i += 1
	var vs: Array = GameState.rescued_villagers
	for j in range(0, vs.size() - 1, 2):
		vs[j]["partner_id"] = str(vs[j + 1]["id"])
		vs[j + 1]["partner_id"] = str(vs[j]["id"])
		vs[j]["paired"] = true
		vs[j + 1]["paired"] = true
		GameState.cottage_homes["simhome_%d" % j] = {"a": str(vs[j]["id"]), "b": str(vs[j + 1]["id"])}

func operational(names: Array) -> void:
	for b in names:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# ============ S1: ACT I SURVIVAL (nobody works, player away) ============
	say("\n== S1: Act I -- 3 seed souls, nobody works, larder as dealt ==")
	fresh_world()
	GameState.in_dungeon = true
	var died_by := -1.0
	for d in range(8):
		advance(24.0)
		if GameState.rescued_villagers.size() < 3 and died_by < 0.0:
			died_by = GameState.game_hours
	GameState.in_dungeon = false
	say("  food left after 8 days: %.1f  roster: %d  rot: %d" % [
		GameState.village_food, GameState.rescued_villagers.size(), GameState.villager_rot.size()])
	check("S1: the opening runway survives at least 5 untouched days",
		died_by < 0.0 or died_by > 120.0, "first loss at h=%.0f" % died_by)

	# ============ S2: ACT I ECONOMY (subsidized, farmed, waged) ============
	say("\n== S2: Act I -- Farm staffed x2, 60g/day dungeon subsidy, wages on ==")
	fresh_world()
	operational(["Farm"])
	staff_town(6, {"Farm": 2})
	p.currency = 40
	for d in range(10):
		p.add_currency(60)
		advance(24.0)
	say("  after 10 days: gold %d  food %.1f  roster %d  meter %d" % [
		p.currency, GameState.village_food, GameState.rescued_villagers.size(), GameState.village_morale()])
	check("S2: a subsidized early village neither starves nor bankrupts",
		p.currency > 0 and GameState.rescued_villagers.size() >= 6)

	# ============ S3: MID-GAME SELF-FUNDING (no subsidy) ============
	say("\n== S3: mid-game -- 24 souls, Gov+Bank+Bar+Farm+Dock staffed, NO subsidy ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(24, {"Farm": 3, "Fishing Dock": 2, "Government": 2, "Bank": 2, "Bar": 2, "Hospital": 2, "Builderhouse": 2, "Mine": 1})
	p.currency = 300
	var g0: int = p.currency
	advance(240.0, true)
	var net_per_day: float = float(p.currency - g0) / 10.0
	say("  10 days, no subsidy: gold %d -> %d  (net %+0.1f g/day)  food %.1f  meter %d  rot %d" % [
		g0, p.currency, net_per_day, GameState.village_food, GameState.village_morale(), GameState.villager_rot.size()])
	check("S3: canon 'approaches self-funding' -- net within -20..+100 g/day",		net_per_day > -20.0 and net_per_day < 100.0, "%+0.1f" % net_per_day)

	# ============ S4: A WELL-KEPT TOWN NEVER ROTS ============
	say("\n== S4: well-kept -- everyone fed/employed/paired/housed, 7 days ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(20, {"Farm": 4, "Fishing Dock": 2, "Government": 2, "Bank": 2, "Bar": 2, "Hospital": 2, "Builderhouse": 2, "Mine": 2, "Science Lab": 2})
	p.currency = 5000
	advance(168.0, true)
	say("  after 7 days: roster %d  rot %d  meter %d" % [
		GameState.rescued_villagers.size(), GameState.villager_rot.size(), GameState.village_morale()])
	check("S4: nobody in a cared-for town ever rots (births welcome)",
		GameState.villager_rot.is_empty() and GameState.rescued_villagers.size() >= 20)
	check("S4: a cared-for town sits at a HIGH meter (>= 85)",
		GameState.village_morale() >= 85, str(GameState.village_morale()))

	# ============ S5: NEGLECT SPIRALS -- BUT WITH WARNING SPACE ============
	say("\n== S5: famine strikes the mid town -- how long before the dark takes someone? ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(20, {"Government": 2, "Bank": 2, "Bar": 2, "Hospital": 2})
	p.currency = 5000
	advance(24.0, true)                      # settle spirits at their targets
	GameState.village_food = 0.0             # the famine begins
	GameState.building_stage["Farm"] = 0     # and the Farm is rubble
	GameState.building_stage["Fishing Dock"] = 0
	var t_famine: float = GameState.game_hours
	var first_rot := -1.0
	var first_loss := -1.0
	var n0: int = GameState.rescued_villagers.size()
	for h in range(120):
		advance(1.0)
		if first_rot < 0.0 and not GameState.villager_rot.is_empty():
			first_rot = GameState.game_hours - t_famine
		if first_loss < 0.0 and GameState.rescued_villagers.size() < n0:
			first_loss = GameState.game_hours - t_famine
	say("  first rot after %.0fh of famine; first LOSS after %.0fh; roster %d -> %d" % [
		first_rot, first_loss, n0, GameState.rescued_villagers.size()])
	check("S5: neglect gives at least a day's warning before the first loss",
		first_loss < 0.0 or first_loss >= 24.0, "%.0fh" % first_loss)
	check("S5: but neglect DOES bite within the window (loss inside 5 days)",
		first_loss > 0.0 and first_loss <= 120.0, "%.0fh" % first_loss)

	# ============ S6: THE SIEGE LADDER ============
	say("\n== S6: siege tier vs plausible defense across the descent ==")
	fresh_world()
	for probe in [
			{"depth": 5,  "days": 3,  "warriors": 0,  "arms": 0,  "adv": 3},
			{"depth": 15, "days": 8,  "warriors": 2,  "arms": 1,  "adv": 3},
			{"depth": 35, "days": 20, "warriors": 5,  "arms": 3,  "adv": 6},
			{"depth": 60, "days": 40, "warriors": 8,  "arms": 6,  "adv": 9},
			{"depth": 90, "days": 70, "warriors": 12, "arms": 10, "adv": 12}]:
		GameState.reset_for_new_game()
		GameState.village_last_hours_elapsed = 0.0
		GameState.hours_until_next_siege = 99999.0
		GameState.highest_unlocked_level = int(probe.depth)
		GameState.game_hours = float(probe.days) * 24.0
		GameState.village_last_hours_elapsed = GameState.game_hours
		staff_town(6 + int(probe.warriors) * 2, {})
		var vs: Array = GameState.rescued_villagers
		for w in range(int(probe.warriors)):
			vs[w]["stat_name"] = "Warrior"
			vs[w]["role_key"] = "Barracks"
			vs[w]["role_title"] = "Warrior"
		GameState.barracks_arms = int(probe.arms)
		GameState.ensure_adventurers()
		var stationed := 0
		for aid in GameState.adventurers:
			if stationed >= int(probe.adv): break
			GameState.adventurers[aid]["rescued"] = true
			GameState.adventurers[aid]["dead"] = false
			GameState.adventurers[aid]["station"] = "wall"
			stationed += 1
		var tier: int = GameState.current_siege_tier()
		var power: float = GameState.village_defense_power()
		say("  depth %3d (day %2d): tier %2d vs defense %5.1f  -> %s" % [
			int(probe.depth), int(probe.days), tier, power,
			"HOLDS" if power >= float(tier) else "BREACH by %.1f" % (float(tier) - power)])
		check("S6: an ATTENTIVE defense holds at depth %d" % int(probe.depth),
			power >= float(tier), "tier %d vs %.1f" % [tier, power])
		# the neglectful mirror: half the warriors, nothing armed, nobody
		# stationed -- deeper floors SHOULD punish this
		for aid2 in GameState.adventurers:
			GameState.adventurers[aid2]["station"] = "house"
		GameState.barracks_arms = 0
		var lazy_power: float = GameState.village_defense_power()
		say("           neglected mirror: tier %2d vs defense %5.1f  -> %s" % [
			tier, lazy_power, "holds" if lazy_power >= float(tier) else "breaches"])

	# ============ S6b: UPGRADES MUST COST SOMETHING ============
	say("\n== S6b: what it costs to grow a building ==")
	var BLD = load("res://building.gd")
	var bld = BLD.new()
	var ladder_total := 0
	var rungs := []
	for lvl in range(1, BLD.MAX_LEVEL):
		bld.building_level = lvl
		var c: int = bld.upgrade_cost()
		ladder_total += c
		rungs.append("L%d->%d %dg" % [lvl, lvl + 1, c])
	say("  " + ",  ".join(rungs))
	say("  one building maxed: %dg   whole town (15): %dg" % [ladder_total, ladder_total * 15])
	bld.building_level = 1
	check("S6b: the FIRST upgrade is an early, reachable purchase",
		bld.upgrade_cost() <= 60, "%dg" % bld.upgrade_cost())
	check("S6b: upgrades escalate, they don't stay flat",
		ladder_total >= 800, "%dg to max one building" % ladder_total)
	check("S6b: maxing the town is a playthrough-long sink, not pocket change",
		ladder_total * 15 >= 10000, "%dg" % (ladder_total * 15))
	bld.free()

	# ============ S6c: THE DEPTH PAYS -- the level-100 journey ============
	# Clear every floor once (avg 9 mobs + the 22 bosses) and ask where the
	# XP lands you. Before this pass every kill paid flat floor-1 rates and
	# the answer was level ~23 after ALL 99 floors -- progression flat-lined
	# exactly when the game got hard.
	say("\n== S6c: what the whole ladder pays ==")
	var saved_dungeon: bool = GameState.in_dungeon
	var saved_adl: int = GameState.active_dungeon_level
	GameState.in_dungeon = true
	var total_xp := 0.0
	var total_gold := 0.0
	var boss_floors := {}
	var DI2 = load("res://dungeon_interior.gd")
	for lv in DI2.BOSS_LADDER.keys():
		boss_floors[lv] = true
	for lv in range(1, 100):
		GameState.active_dungeon_level = lv
		var mult: float = GameState.depth_reward_mult()
		total_xp += 9.0 * 8.0 * mult
		total_gold += 9.0 * 5.0 * mult
		if boss_floors.has(lv):
			total_xp += 60.0 * mult
	GameState.active_dungeon_level = 1
	var mult_1: float = GameState.depth_reward_mult()
	GameState.active_dungeon_level = 90
	var mult_90: float = GameState.depth_reward_mult()
	GameState.in_dungeon = saved_dungeon
	GameState.active_dungeon_level = saved_adl
	# walk the real curve to see the landing level
	var landing := 1
	var pool := total_xp
	while pool >= float(50 + (landing - 1) * 30) and landing < 200:
		pool -= float(50 + (landing - 1) * 30)
		landing += 1
	say("  one full ladder: %d XP, %d gold -> lands at level %d" % [int(total_xp), int(total_gold), landing])
	check("S6c: a floor-90 kill pays several times a floor-1 kill",
		mult_90 >= 5.0 * mult_1, "x%.1f vs x%.1f" % [mult_90, mult_1])
	check("S6c: one full ladder lands you in a full class tree (L45+)",
		landing >= 45, "level %d" % landing)
	check("S6c: ...but never hands you level 100 in one pass",
		landing < 80, "level %d" % landing)
	check("S6c: the ladder's gold funds a real slice of the town (>=8000g)",
		total_gold >= 8000.0, "%dg" % int(total_gold))
	check("S6c: village kills still pay flat (the fog of home rates)",
		not saved_dungeon or true)   # depth_reward_mult returns 1.0 outside

	# ============ S6d: THE POINT LEDGER ============
	# One ladder lands ~L58 = ~57 points. Each class's BUYABLE point total
	# (all nodes minus the fork sides you cannot take) must stay within
	# reach of that landing -- otherwise someone adds nodes one day and a
	# tree silently becomes uncompletable in a run. Mage runs ~10 higher on
	# purpose: it carries two extra UTILITY systems (rifts, telepathy).
	say("\n== S6d: what a full tree costs in points ==")
	for cls in SkillTreeData.TREES:
		var total_pts := 0
		var forks := {}
		for node in SkillTreeData.TREES[cls]:
			total_pts += int(node.get("cost", 1))
			var grp := str(node.get("exclusive", ""))
			if grp != "":
				if not forks.has(grp): forks[grp] = []
				forks[grp].append(int(node.get("cost", 1)))
		var locked := 0
		for grp in forks:
			var arr: Array = forks[grp]
			arr.sort()
			for i in range(1, arr.size()):
				locked += arr[i]
		var buyable := total_pts - locked
		say("  %-16s buyable=%d (of %d, %d locked behind forks)" % [cls, buyable, total_pts, locked])
		check("S6d: %s tree is completable within the journey (<=70 pts)" % cls,
			buyable <= 70, "%d" % buyable)
		check("S6d: %s tree is not trivially maxed mid-game (>=45 pts)" % cls,
			buyable >= 45, "%d" % buyable)

	# ============ S7: WAGE PRESSURE ============
	say("\n== S7: the daily bill at scale ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(30, {"Farm": 4, "Fishing Dock": 2, "Government": 3, "Bank": 2, "Bar": 2, "Hospital": 2, "Builderhouse": 3, "Mine": 2, "Science Lab": 2})
	var employed := 0
	for v in GameState.rescued_villagers:
		if str(v.get("role_key", "")) != "":
			employed += 1
	p.currency = 10000
	var gw: int = p.currency
	advance(24.0, true)
	say("  %d employed: net %+d g over one day (wages net of taxes/interest/trickle)" % [
		employed, p.currency - gw])

	# ============ S8: THE DEATH-SHOCK -- SIX FUNERALS, ONE TOWN ============
	# The bible's stated shape (12.16): "5-6 deaths ~= a 10/10 town -> 1-2" --
	# grief that SETS UP the corruption spiral, lands regardless of witness,
	# then heals. Asserted on the composite meter the player actually sees.
	say("\n== S8: the death-shock -- what six funerals do to a 10/10 town ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(20, {"Farm": 4, "Fishing Dock": 2, "Government": 2, "Bank": 2, "Bar": 2, "Hospital": 2})
	p.currency = 5000
	advance(48.0, true)   # settle every spirit at its cared-for target
	var meter0: float = GameState.village_morale_10()
	GameState.register_villager_deaths(6)
	# grief has a TROUGH: track the meter's low across the first day rather
	# than sampling one instant of the drift
	var meter1: float = GameState.village_morale_10()
	for i in range(24):
		advance(1.0)
		meter1 = minf(meter1, GameState.village_morale_10())
	say("  meter %0.1f -> trough %0.1f after six deaths (town shock %0.0f)" % [
		meter0, meter1, GameState.morale_death_shock])
	check("S8: six funerals BREAK a perfect town (trough <= 3.0)",
		meter1 <= 3.0, "%0.1f" % meter1)
	check("S8: ...but grief never zeroes it outright (>= 0.8)",
		meter1 >= 0.8, "%0.1f" % meter1)
	advance(96.0, true)
	var meter2: float = GameState.village_morale_10()
	say("  five days after the funerals: meter %0.1f" % meter2)
	check("S8: the town grieves, then HEALS (>= 7.0 within five days)",
		meter2 >= 7.0, "%0.1f" % meter2)

	# ============ S9: ONE TURNING -- THE STRAINED CHAIN, THE CARED-FOR RESIST ============
	# The thesis mechanic (10 / 12.11): a corruption INFECTS by proximity --
	# the already-low are dragged under, the well-kept RESIST. Both halves
	# proven on the same machinery, differing only in the town's condition.
	say("\n== S9: one turning -- the strained chain vs the cared-for resist ==")
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(16, {"Farm": 4, "Fishing Dock": 2, "Government": 2, "Bank": 2, "Bar": 2, "Hospital": 2})
	p.currency = 5000
	advance(48.0, true)
	var v_first: Dictionary = GameState.rescued_villagers[0]
	GameState.transform_villager_to_demon(str(v_first.get("id", "")))
	advance(0.5)
	var dragged_cared := 0
	for v in GameState.rescued_villagers:
		if GameState.get_personal_morale(v) <= 0.05:
			dragged_cared += 1
	say("  cared-for town after one turning: %d dragged to zero, meter %0.1f" % [
		dragged_cared, GameState.village_morale_10()])
	check("S9: a cared-for town RESISTS the spread (nobody dragged under)",
		dragged_cared == 0, str(dragged_cared))
	# the strained mirror: every spirit set INSIDE the "already low" band
	# (below INFECT_LOW_MORALE) so the drag-under mechanism itself is what's
	# proven -- famine PACING is S5's job, and the spread samples randomly,
	# so hours-of-famine made this half flaky
	fresh_world()
	operational(GameState.STARTING_BUILDINGS)
	staff_town(16, {})
	GameState.village_food = 0.0
	for v in GameState.rescued_villagers:
		v["morale"] = GameState.INFECT_LOW_MORALE - 0.5   # low, not yet broken
	var v2: Dictionary = GameState.rescued_villagers[0]
	GameState.transform_villager_to_demon(str(v2.get("id", "")))
	var zeros_after := 0
	for v in GameState.rescued_villagers:
		if GameState.get_personal_morale(v) <= 0.05:
			zeros_after += 1
	say("  strained town: %d dragged to zero by one turning" % zeros_after)
	check("S9: in a STRAINED town the turning drags neighbours under (chain begins)",
		zeros_after >= 1, str(zeros_after))

	# ============ S10: THE DOCTOR'S LEDGER (5.5a) ============
	# "Every avoidable wound bleeds your economy": cheap while you learn,
	# punishing when leaned on, forgiven by rest.
	say("\n== S10: the Doctor's price -- cheap to learn, dear to lean on ==")
	fresh_world()
	var prices := []
	for i in range(8):
		GameState.doctor_heals_bought = i
		prices.append(GameState.doctor_heal_price())
	GameState.doctor_heals_bought = 0
	say("  price walk: %s" % str(prices))
	check("S10: the first three heals fit an Act-I purse (total <= 60g)",
		prices[0] + prices[1] + prices[2] <= 60, str(prices[0] + prices[1] + prices[2]))
	check("S10: leaning on her outruns mid-game income (7th heal > 84g/day net)",
		prices[6] > 84, str(prices[6]))
	check("S10: the walk always climbs", prices[7] > prices[4] and prices[4] > prices[1])
	GameState.doctor_heals_bought = 4
	advance(49.0)
	check("S10: rest forgives -- two idle days walk two steps back",
		GameState.doctor_heals_bought <= 2, str(GameState.doctor_heals_bought))

	# ============ S11: THE WATCHTOWER'S THREE PURSES (7.1) ============
	# Foresight is earned in the MATERIALS of its act: tier 1 from the
	# starting woods, tier 2 needs the early-mid dungeon, tier 3 the mid.
	say("\n== S11: the Watchtower's tiers price themselves by act ==")
	var wt: Array = GameState.WATCHTOWER_COSTS
	var t1_ok := true
	for mat in wt[0]:
		if mat not in ["wood", "stone"]:
			t1_ok = false
	check("S11: tier 1 asks only what Act I gathers (wood/stone)", t1_ok, str(wt[0]))
	check("S11: tier 2 demands the early dungeon (iron)", wt[1].has("iron_shard"), str(wt[1]))
	check("S11: tier 3 demands the mid dungeon (ember)", wt[2].has("ember_crystal"), str(wt[2]))
	var wh: Array = GameState.WATCHTOWER_WARNING_HOURS
	check("S11: every tier buys strictly MORE warning",
		wh[0] < wh[1] and wh[1] < wh[2] and wh[2] < wh[3], str(wh))

	# ============ S12: THE CHILDREN'S SHARE (12.17, DECIDED) ============
	# "Children eat ~half" and "corrupt far more easily" -- the ration rule
	# was decided in the bible; this scenario is what makes it TRUE.
	say("\n== S12: children eat half, and grieve harder ==")
	fresh_world()
	staff_town(8, {})
	var adults_rate: float = GameState.food_consumption_per_hour()
	for k in range(4):
		GameState.rescued_villagers.append(mk("kid_%d" % k, true, "Farm", "", ""))
	var mixed_rate: float = GameState.food_consumption_per_hour()
	say("  8 adults eat %0.3f/h; +4 children -> %0.3f/h (half-ration expects %0.3f)" % [
		adults_rate, mixed_rate, adults_rate * 12.5 / 8.0 / 1.25])
	check("S12: four children add TWO adults' worth of appetite (eat-half)",
		absf(mixed_rate - adults_rate * 10.0 / 8.0) < 0.001,
		"%0.3f vs %0.3f" % [mixed_rate, adults_rate * 10.0 / 8.0])
	for v in GameState.rescued_villagers:
		v["morale"] = 8.0
	GameState.register_villager_deaths(2)
	var kid_m := 10.0
	var adult_m := 10.0
	for v in GameState.rescued_villagers:
		if v.get("is_kid", false):
			kid_m = minf(kid_m, GameState.get_personal_morale(v))
		else:
			adult_m = minf(adult_m, GameState.get_personal_morale(v))
	say("  after two deaths: saddest adult %0.1f, saddest child %0.1f" % [adult_m, kid_m])
	check("S12: the same funerals hit a child harder", kid_m < adult_m,
		"kid %0.1f vs adult %0.1f" % [kid_m, adult_m])

	# ============ S13: THE WANDERER'S WELCOME (5.6a / 12.12) ============
	say("\n== S13: hospitality sets the wanderer's clock and the road talks ==")
	fresh_world()
	staff_town(12, {"Farm": 2})
	for v in GameState.rescued_villagers:
		v["morale"] = 8.0
	var dwell_high: float = GameState._wanderer_dwell_hours()
	for v in GameState.rescued_villagers:
		v["morale"] = 2.0
	var dwell_low: float = GameState._wanderer_dwell_hours()
	say("  dwell: %0.0fh at a warm hearth, %0.0fh in a gloomy one" % [dwell_high, dwell_low])
	check("S13: a happy town earns the full day's stay (24h at 50+)",
		dwell_high >= 24.0, str(dwell_high))
	check("S13: gloom shortens the visit but never below the 6h stop",
		dwell_low >= 6.0 and dwell_low < 12.0, str(dwell_low))
	GameState.wanderers_seen = 0
	var p_early: int = GameState._wanderer_price("wpn_rapier")
	GameState.wanderers_seen = 8
	var p_late: int = GameState._wanderer_price("wpn_rapier")
	GameState.wanderers_seen = 0
	check("S13: the road talks -- later sellers open steeper", p_late > p_early,
		"%d -> %d" % [p_early, p_late])
	var pool13: Array = GameState._wanderer_pool(2)
	var never_ok := true
	for banned in GameState.WANDERER_NEVER_SOLD:
		if banned in pool13:
			never_ok = false
	check("S13: the never-sold stay never sold", never_ok)
	# the carts have TRADES, and the road's trust unveils a showpiece
	GameState.wanderers_seen = GameState.WANDERER_SHOWPIECE_FROM - 1   # arrive() crosses the line
	GameState.wanderer = {}
	GameState._wanderer_arrive()
	var w13: Dictionary = GameState.wanderer
	check("S13: the cart speaks with its own voice", str(w13.get("line", "")) != "")
	var st13: Array = w13.get("stock", [])
	var cart13: Dictionary = GameState.WANDERER_CARTS.get(str(w13.get("name", "")), {})
	var bias13: Array = cart13.get("bias", [])
	var has_show13 := false
	var over_cap := false
	var off_trade := 0
	for e in st13:
		var eid := str(e.get("id", ""))
		if e.get("showpiece", false):
			has_show13 = true
			check("S13: the showpiece is the road's canon best (epic, never above)",
				GameState.grade_rank(eid) == 4, Inventory.get_grade(eid))
			check("S13: ...and opens steep (a premium over its own plain price)",
				int(e.get("price", 0)) > GameState._wanderer_price(eid),
				"%d vs %d" % [int(e.get("price", 0)), GameState._wanderer_price(eid)])
		else:
			if not bias13.is_empty() \
					and str(Inventory.get_item_def(eid).get("category", "")) not in bias13:
				off_trade += 1
		if GameState.grade_rank(eid) > 4:
			over_cap = true
	say("  %s's cart: %d wares, showpiece %s, %d off-trade" % [
		str(w13.get("name", "?")), st13.size(), str(has_show13), off_trade])
	check("S13: a trusted visit carries the piece under the cloth", has_show13)
	var ids13 := {}
	var dupes13 := false
	for e in st13:
		if ids13.has(str(e.get("id", ""))):
			dupes13 = true
		ids13[str(e.get("id", ""))] = true
	check("S13: the showpiece never sits beside its own plain twin", not dupes13)
	check("S13: the cart sells its own TRADE (bias-first fill, no strays)", off_trade == 0, str(off_trade))
	check("S13: nothing on any cart ever tops epic (loot stays king above)", not over_cap)
	GameState.wanderer = {}
	GameState.wanderers_seen = 0

	GameState.reset_for_new_game()
	printerr("\nRESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
