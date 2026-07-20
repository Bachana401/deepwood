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

	GameState.reset_for_new_game()
	printerr("\nRESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
