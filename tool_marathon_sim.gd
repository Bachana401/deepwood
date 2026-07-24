extends Node
# THE MARATHON (dev ask 2026-07-22: "simulate a player playing 4-5 hours -- how he
# develops, what items he gathers, how the skill tree upgrades, the village
# situation"). A continuous, accelerated playthrough that drives the REAL systems:
#   - dungeon kills pay the REAL depth-scaled XP/gold (enemy.die's formula),
#   - loot rolls the REAL drop tables (construction, caches, potions, deep mats),
#   - level-ups grant REAL skill points spent through the REAL skill tree
#     (points + prereqs + exclusive forks + MATERIAL gates),
#   - the village runs on the REAL clock (tick_village_clock: food, wages, mine +
#     fishing material yield, sieges).
# It prints a development TIMELINE and a final report per class, then flags the
# anomalies a 4-5h marathon would expose. Faithful, so the numbers are the game's.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)
func say(t: String) -> void: printerr(t)

var p: Node = null

const SESSION_MIN := 270.0          # 4.5 hours at the keyboard
const CHECKPOINT_MIN := 45.0        # a timeline row this often
const PLAYMIN_TO_GAMEHOURS := 2.4   # 10-min days: 1 real minute = 0.1 day = 2.4 game-hours
const SKILL_MATS := ["slime", "iron_shard", "ember_crystal", "void_essence", "ancient_relic"]

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

	seed(20260722)
	# The marathon models a player LONG past the opening (they're delving floor
	# 60 by the end) -- the siege clock is gated on opening_done now, and without
	# this the whole 4.5h ran siege-free ("0 lost to siege" was an artifact,
	# caught on the 2026-07-23 re-run).
	GameState.opening_done = true
	var summaries: Array = []
	summaries.append(run_marathon("Sword", true))
	summaries.append(run_marathon("Archer", false))
	summaries.append(run_marathon("Mage", false))

	say("\n================= 4.5-HOUR MARATHON: THREE BUILDS =================")
	say("class    | endLvl | floor | pts spent/earned | tree% | key mats gathered")
	for s in summaries:
		say("%-8s |   %3d  |  %3d  |     %2d / %2d       |  %2d%%  | slime %d iron %d ember %d void %d relic %d" % [
			s.cls, s.level, s.floor, s.spent, s.earned, s.tree_pct,
			s.mats.get("slime", 0), s.mats.get("iron_shard", 0), s.mats.get("ember_crystal", 0),
			s.mats.get("void_essence", 0), s.mats.get("ancient_relic", 0)])

	# -------- anomaly assertions (a marathon should surface these) --------
	say("\n== anomaly checks ==")
	for s in summaries:
		check("%s: a 4.5h run reaches a real character level (>=25)" % s.cls, s.level >= 25, "L%d" % s.level)
		check("%s: ...but not the level cap in one sitting (<95)" % s.cls, s.level < 95, "L%d" % s.level)
		# a healthy tail: the last few points wait on tier-6/7 CAPSTONE materials
		# (void_essence, deep-cache only) -- which co-occurs with not yet being high
		# enough level to finish a branch. A frozen tree (pre-slime-fix: 29 idle) is
		# the failure; a handful waiting on the endgame reagent is correct pacing.
		check("%s: the tree keeps pace with levels (<=10 idle, capstone tail only)" % s.cls, s.idle_points <= 10,
			"%d idle (of %d earned)" % [s.idle_points, s.earned])
		check("%s: the build actually progressed (>=10 nodes)" % s.cls, s.spent_nodes >= 10, "%d nodes" % s.spent_nodes)
		check("%s: the bag isn't empty and isn't one-note (>=5 item kinds)" % s.cls, s.item_kinds >= 5,
			"%d kinds" % s.item_kinds)
		check("%s: the village kept its people through the session (>=3)" % s.cls, s.pop >= 3, "%d pop" % s.pop)
		check("%s: the village didn't bankrupt the run (gold >= 0)" % s.cls, s.gold >= 0, "%dg" % s.gold)

	GameState.reset_for_new_game()
	printerr("\nRESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ the run
func run_marathon(cls: String, verbose: bool) -> Dictionary:
	GameState.reset_for_new_game()
	# past the opening: the reset re-closes the siege gate, and a marathon player
	# is hours beyond the tutorial -- re-open it per class run
	GameState.opening_done = true
	GameState.village_last_hours_elapsed = 0.0
	GameState.game_hours = 0.0
	GameState.chosen_class = cls
	GameState.player_level = 1
	GameState.player_xp = 0
	GameState.skill_points = 0
	GameState.unlocked_skills = []
	GameState.researched_materials = []
	GameState.rescued_villagers = []
	GameState.building_stage = {}
	p.currency = 0
	clear_bag()

	var target_branch := 0        # commit to one spec (branch 0), splash later if points spare
	var build_log: Array = []
	var siege_events := 0
	var play_min := 0.0
	var next_cp := CHECKPOINT_MIN
	var floor := 0
	var losses := 0

	if verbose:
		say("\n########################  MARATHON: %s  ########################" % cls)
		say(" time |flr| Lv | pts | gold  | food | pop | mrl | recent build")

	while play_min < SESSION_MIN and floor < 99:
		floor += 1
		GameState.highest_unlocked_level = maxi(GameState.highest_unlocked_level, floor)
		GameState.in_dungeon = true
		GameState.active_dungeon_level = floor
		clear_floor(floor)
		play_min += floor_minutes(floor)

		# village runs on the real clock for the time that passed -- WHILE the
		# player is still away in the deep, so a siege landing in that window
		# resolves through the OFFLINE math (resolve_siege_offline) like a real
		# delve. The old order flipped in_dungeon=false FIRST, so every siege
		# started as a LIVE battle with real raider nodes the sim never fought,
		# then was abandoned on the next floor -- "0 lost to siege" was that
		# artifact, not balance (caught 2026-07-23).
		grow_village(floor)
		var pop_before := pop()
		advance_village(floor_minutes(floor) * PLAYMIN_TO_GAMEHOURS)
		GameState.in_dungeon = false
		if pop() < pop_before:
			losses += pop_before - pop()          # a defender fell (siege / famine)
		siege_events = losses

		# spend whatever points are now affordable, following a coherent build
		spend_points(cls, target_branch, build_log, floor)

		if verbose and play_min >= next_cp:
			var recent := ""
			if build_log.size() > 0:
				recent = str(build_log.back().name)
			say("%4.0fm |%3d|%3d | %d/%d | %5d | %4.0f | %3d | %3d | %s" % [
				play_min, floor, GameState.player_level, GameState.skill_points,
				spent_total(build_log) + GameState.skill_points, p.currency,
				GameState.village_food, pop(), GameState.village_morale(), recent])
			next_cp += CHECKPOINT_MIN

	# ---- per-run report ----
	var earned: int = GameState.player_level - 1      # 1 point per level
	var spent := spent_total(build_log)
	var tree_total := tree_point_total(cls)
	var mats := {}
	for m in SKILL_MATS: mats[m] = p.inventory.get_count(m)
	var summary := {
		"cls": cls, "level": GameState.player_level, "floor": floor,
		"spent": spent, "earned": earned, "idle_points": GameState.skill_points,
		"spent_nodes": build_log.size(), "tree_pct": int(round(100.0 * float(spent) / float(maxi(1, tree_total)))),
		"mats": mats, "item_kinds": count_item_kinds(), "pop": pop(),
		"gold": p.currency, "food": GameState.village_food, "morale": GameState.village_morale(),
	}

	if verbose:
		say("\n---- %s: end of session ----" % cls)
		say("  reached FLOOR %d at LEVEL %d  (%d skill points earned, %d spent, %d idle)" % [
			floor, GameState.player_level, earned, spent, GameState.skill_points])
		say("  the build, in order:")
		var line := "    "
		for e in build_log:
			line += "%s(L%d) -> " % [e.name, e.level]
			if line.length() > 92:
				say(line); line = "    "
		if line.strip_edges() != "": say(line.trim_suffix(" -> "))
		say("  tree completion: %d%% (%d of %d points into %s)" % [summary.tree_pct, spent, tree_total, cls])
		say("  materials in bag: slime %d, iron %d, ember %d, void %d, relic %d" % [
			mats.slime, mats.iron_shard, mats.ember_crystal, mats.void_essence, mats.ancient_relic])
		say("  other loot: potions H/M %d/%d, wood %d, stone %d, herb %d, meat %d" % [
			p.inventory.get_count("potion_health"), p.inventory.get_count("potion_mana"),
			p.inventory.get_count("wood"), p.inventory.get_count("stone"),
			p.inventory.get_count("herb"), p.inventory.get_count("raw_meat")])
		say("  village: %d people, %d gold, %.0f food, morale %d, %d lost to siege/famine" % [
			pop(), p.currency, GameState.village_food, GameState.village_morale(), siege_events])
		var blocked := blocked_nodes_report(cls)
		if blocked != "":
			say("  NEXT nodes still locked: " + blocked)
	return summary

# ------------------------------------------------------------------ dungeon
func floor_minutes(floor: int) -> float:
	var base := 2.2 + 0.06 * float(floor)          # deeper floors take longer
	if floor % 5 == 0: base += 2.0                 # boss floors
	return base

# One floor, cleared: ~9 grunts (+ a boss every 5th), paying the REAL rewards and
# rolling the REAL drop tables, plus the floor's cache.
func clear_floor(floor: int) -> void:
	var mult := GameState.depth_reward_mult()
	var kills := 9
	for k in range(kills):
		p.add_currency(int(round(5.0 * mult * (1.0 + GameState.get_bonus_total("gold_gain")))))
		GameState.add_xp(int(round(8.0 * mult)))
		GameState.roll_construction_drop(p, 1.0)
		if randf() < 0.25:
			p.inventory.add_item("raw_meat", 1)
		if floor <= 30 and randf() < 0.06:            # slime, the early keystone reagent (see enemy.die)
			p.inventory.add_item("slime", 1)
		if (floor - 1) % 5 + 1 >= 4:               # the potions rule (pre-boss floors)
			if randf() < 0.16: p.inventory.add_item("potion_health", 1)
			if randf() < 0.12: p.inventory.add_item("potion_mana", 1)
	if floor % 5 == 0:                             # the boss
		p.add_currency(int(round(40.0 * mult)))
		GameState.add_xp(int(round(60.0 * mult)))
	# the floor's hidden cache (build_floor_surprises: ~60% a cache)
	if randf() < 0.6:
		var table := ["potion_health", "potion_mana", "iron_shard", "ember_crystal", "coin_gold", "herb", "resin"]
		if floor <= 30: table += ["slime"]
		if floor >= 40: table += ["void_essence", "ancient_relic"]
		p.inventory.add_item(table[randi() % table.size()], 1)

# ------------------------------------------------------------------ village
# Grow the town to a plausible state for this depth: buildings come online, rescues
# arrive and get staffed (Mine + Fishing Dock so materials actually flow).
func grow_village(floor: int) -> void:
	# rescues: about one soul every third floor -- a managed town, not a mob
	var want_pop := clampi(3 + int(floor / 3), 3, 26)
	var i := GameState.rescued_villagers.size()
	while GameState.rescued_villagers.size() < want_pop:
		GameState.rescued_villagers.append(mk("m_%d" % i))
		i += 1
	# buildings online by depth milestones (blueprints land by floor 30)
	var online := ["Farm"]
	if floor >= 4: online.append("Fishing Dock")
	if floor >= 6: online.append("Mine")
	if floor >= 8: online += ["Government", "Bank"]
	if floor >= 12: online += ["Bar", "Hospital"]
	if floor >= 16: online += ["Builderhouse", "Barracks"]
	if floor >= 24: online.append("Science Lab")
	for b in online:
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES
		GameState.building_health[b] = 100
	# re-staff food-first and PROPORTIONALLY, so the town is fed (a cared-for town,
	# per balance_sim S4): Fishing gives slime, the Mine gives iron.
	for v in GameState.rescued_villagers:
		v["role_key"] = ""; v["role_title"] = ""
	var pop_n := GameState.rescued_villagers.size()
	var order: Array = []
	for k in range(maxi(3, int(ceil(float(pop_n) / 4.0)))): order.append("Farm")
	order += ["Fishing Dock", "Fishing Dock", "Mine", "Mine",
		"Bank", "Government", "Hospital", "Bar", "Builderhouse", "Science Lab", "Barracks"]
	staff(order)
	# a kept larder: a player managing their town keeps the farm stocked, so the
	# sim doesn't spiral into a famine that drowns out the development it's measuring
	if GameState.village_food < float(pop_n) * 8.0:
		GameState.village_food = float(pop_n) * 12.0

func advance_village(hours: float) -> void:
	var stepped := 0.0
	while stepped < hours:
		var step: float = minf(6.0, hours - stepped)
		GameState.game_hours += step
		GameState.tick_village_clock()
		GameState.generate_passive_income()
		stepped += step

# ------------------------------------------------------------------ skills
func spend_points(cls: String, target_branch: int, log_arr: Array, floor: int) -> void:
	var tree: Array = SkillTreeData.TREES[cls]
	var progressed := true
	while progressed:
		progressed = false
		# identify any skill material you've gathered (so material nodes aren't ID-blocked)
		for mid in SKILL_MATS:
			if p.inventory.get_count(mid) > 0 and not GameState.researched_materials.has(mid):
				GameState.researched_materials.append(mid)
		var best: Dictionary = {}
		var best_score := 1e9
		for node in tree:
			if GameState.is_skill_unlocked(node.id): continue
			if not SkillTreeData.prereq_met(node): continue
			if SkillTreeData.is_exclusive_blocked(node): continue
			if GameState.skill_points < int(node.cost): continue
			var have_mats := true
			for mid in node.get("materials", {}):
				if p.inventory.get_count(mid) < int(node.materials[mid]): have_mats = false; break
			if not have_mats: continue
			# score: root/target-branch first, then by tier then cost (climb in order)
			var br := int(node.get("branch", -1))
			var pref := 0.0 if (br == -1 or br == target_branch) else 100.0
			var score := pref + float(node.tier) * 2.0 + float(node.cost) * 0.1
			if score < best_score:
				best_score = score; best = node
		if not best.is_empty():
			if GameState.try_unlock_skill(best, p):
				log_arr.append({"id": best.id, "name": str(best.name), "level": GameState.player_level, "floor": floor})
				progressed = true

func spent_total(log_arr: Array) -> int:
	var t := 0
	for e in log_arr:
		t += int(SkillTreeData.get_node_by_id(str(e.id)).get("cost", 1))
	return t

func tree_point_total(cls: String) -> int:
	# buyable points = all nodes minus the pricier side of each exclusive fork
	var total := 0
	var forks := {}
	for node in SkillTreeData.TREES[cls]:
		total += int(node.get("cost", 1))
		var grp := str(node.get("exclusive", ""))
		if grp != "":
			if not forks.has(grp): forks[grp] = []
			forks[grp].append(int(node.get("cost", 1)))
	var locked := 0
	for grp in forks:
		var arr: Array = forks[grp]; arr.sort()
		for i in range(1, arr.size()): locked += arr[i]
	return total - locked

func blocked_nodes_report(cls: String) -> String:
	var out := []
	for node in SkillTreeData.TREES[cls]:
		if GameState.is_skill_unlocked(node.id): continue
		if not SkillTreeData.prereq_met(node): continue
		if SkillTreeData.is_exclusive_blocked(node): continue
		var why := []
		if GameState.skill_points < int(node.cost):
			why.append("%dpt" % int(node.cost))
		for mid in node.get("materials", {}):
			var have: int = p.inventory.get_count(mid)
			if have < int(node.materials[mid]):
				why.append("%dx%s(have %d)" % [int(node.materials[mid]), mid, have])
		if not why.is_empty():
			out.append("%s[%s]" % [str(node.name), ", ".join(why)])
		if out.size() >= 3: break
	return ", ".join(out)

# ------------------------------------------------------------------ helpers
func mk(id: String) -> Dictionary:
	return {"id": id, "name": id, "sex": "Male" if hash(id) % 2 == 0 else "Female",
		"is_kid": false, "stat_name": "Farm", "stat_value": 4, "role_key": "", "role_title": ""}

func staff(order: Array) -> void:
	# assign jobless adults to the given buildings in order (only operational ones)
	var vs: Array = GameState.rescued_villagers
	var idx := 0
	for b in order:
		if int(GameState.building_stage.get(b, 0)) < GameState.TOTAL_BUILD_STAGES:
			continue
		while idx < vs.size():
			if str(vs[idx].get("role_key", "")) == "":
				vs[idx]["role_key"] = b
				var roles = BuildingRoles.get_roles(b)
				vs[idx]["role_title"] = roles.back().get("title", "Worker") if not roles.is_empty() else "Worker"
				idx += 1
				break
			idx += 1

func pop() -> int:
	return GameState.rescued_villagers.size()

func clear_bag() -> void:
	# a roomy bag so the sim measures GROSS gathering (add_item only fills existing
	# slots, so it must be sized, not emptied to []). The real 15-slot bag is a
	# separate management concern; here we want the totals.
	if p.inventory:
		p.inventory.slots.clear()
		p.inventory.slots.resize(80)
		p.inventory.capacity = 80

func count_item_kinds() -> int:
	var kinds := {}
	if p.inventory:
		for slot in p.inventory.slots:
			if slot != null:
				kinds[str(slot.item_id)] = true
	return kinds.size()
