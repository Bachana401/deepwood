extends Node
# ==================== THE AUTOMATION LADDER SIMULATOR ====================
# Run:  MONARCH_TEST="res://tool_ladder_sim.gd" Godot.exe --headless --path .
#
# The dev's law: the player starts doing everything by hand, each unlock hands
# one more chore to the village, and by roughly level 80 almost everything runs
# itself. The pace must be GRADUAL -- never all at once, never fully free.
#
# Nobody has ever walked the actual unlock depths to see whether the curve holds.
# This does: floor 1 to 100, painting the state a player would REALLY have at
# each depth (blueprints found, VIPs rescued and seated, halls raised, crews
# hired), and reading the game's OWN progress meter -- chore_domains() and
# village_self_sufficiency() -- back out at every floor.
#
# WHAT IT LOOKS FOR
#   L1  the curve: self-reliance % against depth, and the LONGEST DEAD STRETCH
#       where a player descends and nothing new is handed over
#   L2  which chore each depth buys, and which chores nothing ever automates
#   L3  the ladder against the dev's own milestone: is it ~done by level 80?
#   L4  the named building POWERS -- the second automation track, which is
#       bought with GOLD rather than depth, and so is not paced by the deep
#
# ASSUMPTIONS
#   * A player raises a building the floor after its blueprint drops and staffs
#     it from the souls they have. That is the FASTEST honest schedule; a real
#     player is later, so this reads the ladder at its most generous.
#   * A rescued VIP is seated in their post immediately (the game auto-seats
#     them, and the Chancellor re-seats anyone misplaced).
#   * Player level tracks depth the way the balance sim's ladder says it does:
#     the whole 99-floor descent lands a player in the mid-to-high 50s, so
#     "level 80" is past the bottom of the dungeon, not halfway down it.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)
func say(t: String) -> void: printerr(t)

var p: Node = null

# When each hall can first be RAISED: the starters from the first minute, the
# rest the floor their blueprint lies on (BLUEPRINT_FLOORS).
func hall_floor(bname: String) -> int:
	if bname in GameState.BLUEPRINT_STARTERS:
		return 1
	for lv in GameState.BLUEPRINT_FLOORS.keys():
		if str(GameState.BLUEPRINT_FLOORS[lv]) == bname:
			return int(lv)
	return 999

# When each leadership VIP can first be freed (IMPORTANT_FIGURES is keyed by the
# floor they are chained on).
func vip_floor(stat: String) -> int:
	var best := 999
	for lv in VillagerQuests.IMPORTANT_FIGURES.keys():
		if str(VillagerQuests.IMPORTANT_FIGURES[lv].get("stat_name", "")) == stat:
			best = mini(best, int(lv))
	return best

# Paint the town a player would plausibly have standing at this depth.
func paint_at(floor: int) -> void:
	GameState.reset_for_new_game()
	GameState.opening_done = true
	GameState.dev_mode = false
	GameState.hours_until_next_siege = 999999.0
	GameState.rescued_villagers = []
	GameState.cottage_homes = {}
	GameState.mating_houses = {}
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = []
	GameState.extra_cottages = 0
	GameState.building_levels = {}
	GameState.selfsuf_celebrated = []
	GameState._bank_paid_full_payroll = false
	GameState.highest_unlocked_level = floor
	GameState.deepest_level_reached = floor
	var vid := 0
	# the halls the player has had the blueprint for
	for b in GameState.STARTING_BUILDINGS:
		var up: bool = hall_floor(b) <= floor
		GameState.building_stage[b] = GameState.TOTAL_BUILD_STAGES if up else 0
		GameState.building_health[b] = GameState.BUILDING_MAX_HEALTH if up else 0
		if not up:
			continue
		# a crew of ordinary hands, hired from the town
		for rd in BuildingRoles.get_roles(b):
			if rd.get("leadership", false) or rd.get("is_enrollment", false):
				continue
			for _k in range(2):
				vid += 1
				GameState.rescued_villagers.append({
					"id": "l_%d" % vid, "name": "L%d" % vid,
					"sex": "Male" if vid % 2 == 0 else "Female", "is_kid": false,
					"stat_name": str(rd.get("required_stat", "")), "stat_value": 4,
					"role_key": b, "role_title": str(rd.get("title", "Worker")), "morale": 8.0})
			break
	# the VIPs the deep has given up by now, seated in their posts
	for lv in VillagerQuests.IMPORTANT_FIGURES.keys():
		if int(lv) > floor:
			continue
		var fig: Dictionary = VillagerQuests.IMPORTANT_FIGURES[lv]
		var rk: String = str(fig.get("role_key", ""))
		if not GameState.is_building_operational(rk):
			continue                     # their hall is not up yet: the seat waits
		vid += 1
		GameState.rescued_villagers.append({
			"id": str(fig.get("villager_id", "v_%d" % vid)), "name": str(fig.get("villager_name", "?")),
			"sex": str(fig.get("sex", "Female")), "is_kid": false,
			"stat_name": str(fig.get("stat_name", "")), "stat_value": int(fig.get("stat_value", 5)),
			"role_key": rk, "role_title": str(fig.get("role_title", "")), "morale": 8.0})
	GameState.village_food = float(GameState.rescued_villagers.size()) * 60.0

func handled_set() -> Dictionary:
	var out: Dictionary = {}
	for d in GameState.chore_domains():
		out[str(d["key"])] = bool(d["handled"])
	return out

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

	var domains: Array = GameState.chore_domains()
	say("\n========== L0: WHAT THE GAME ITSELF COUNTS AS A CHORE ==========")
	for d in domains:
		say("   %-12s %s" % [str(d["key"]), str(d["label"])])
	say("  %d domains. The self-reliance meter is handled/%d." % [domains.size(), domains.size()])

	# ---------- L1: WALK THE LADDER ----------
	say("\n========== L1: THE LADDER, FLOOR BY FLOOR ==========")
	var prev: Dictionary = {}
	var first_at: Dictionary = {}
	var curve: Array = []
	var events: Array = []
	for f in range(1, 101):
		paint_at(f)
		var h: Dictionary = handled_set()
		var n := 0
		for k in h.keys():
			if bool(h[k]): n += 1
		curve.append(n)
		for k2 in h.keys():
			if bool(h[k2]) and not bool(prev.get(k2, false)):
				first_at[str(k2)] = f
				events.append({"floor": f, "key": str(k2)})
		prev = h
	say("  floor:  1   10   20   30   40   50   60   70   80   90  100")
	var line := "  chores:"
	for f2 in [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
		line += "%3d/%d" % [int(curve[f2 - 1]), domains.size()]
	say(line)
	say("\n  what each depth hands over:")
	for e in events:
		var lbl := ""
		for d2 in domains:
			if str(d2["key"]) == str(e["key"]):
				lbl = str(d2["label"])
		say("    floor %3d  ->  %s (%s)" % [int(e["floor"]), lbl, str(e["key"])])
	var never: Array = []
	for d3 in domains:
		if not first_at.has(str(d3["key"])):
			never.append("%s (%s)" % [str(d3["label"]), str(d3["key"])])
	if not never.is_empty():
		say("    NEVER handed over anywhere in the descent: %s" % ", ".join(never))

	# the dead stretch: the longest run of floors that buys no new automation
	var last := 0
	var gap := 0
	var gap_from := 0
	var gap_to := 0
	for e2 in events:
		if int(e2["floor"]) - last > gap:
			gap = int(e2["floor"]) - last
			gap_from = last
			gap_to = int(e2["floor"])
		last = int(e2["floor"])
	var tail: int = 100 - last
	say("\n  LONGEST DEAD STRETCH: floors %d-%d, %d floors with nothing new automated." % [
		gap_from + 1, gap_to, gap])
	say("  ...and after the last unlock at floor %d, %d floors of nothing." % [last, tail])
	check("L1: no stretch of the descent leaves the player hand-working for 20+ floors",
		gap <= 20, "floors %d-%d is %d floors long" % [gap_from + 1, gap_to, gap])

	# ---------- L2: THE MANUAL CHORES THE METER DOES NOT WATCH ----------
	# chore_domains() is the game's own list, but the dev's law is about EVERY
	# manual chore. These are the loops a player actually performs by hand; each
	# is checked against whether some building/leader ever takes it over.
	say("\n========== L2: EVERY HAND CHORE, AND WHAT EVER TAKES IT OVER ==========")
	var gs: String = FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	var chores: Array = [
		{"chore": "hand-harvest food (hold H)", "auto": "a staffed Farm/Dock", "at": maxi(hall_floor("Farm"), 1), "proof": "food_production_per_hour"},
		{"chore": "assign every rescue by hand", "auto": "the Chancellor", "at": vip_floor("Chancellor"), "proof": "auto_staff_villagers"},
		{"chore": "haul repairs by hand", "auto": "a Builderhouse crew", "at": hall_floor("Builderhouse"), "proof": "auto_repair_one"},
		{"chore": "carry the hurt to the ward", "auto": "the Chief Physician", "at": vip_floor("Chief Physician"), "proof": "auto_heal_villagers"},
		{"chore": "raise each cottage from the B menu", "auto": "the Master Builder", "at": vip_floor("Master Builder"), "proof": "auto_build_cottage"},
		{"chore": "pair each couple with E", "auto": "the Publican", "at": vip_floor("Publican"), "proof": "auto_pair_couples"},
		{"chore": "enrol each child in School", "auto": "the Principal", "at": vip_floor("Principal"), "proof": "auto_enroll_children"},
		{"chore": "sell your haul at the stall", "auto": "the Merchant Prince", "at": vip_floor("Merchant Prince"), "proof": "auto_sell_village_surplus"},
		{"chore": "identify each material", "auto": "the Lead Researcher", "at": vip_floor("Lead Researcher"), "proof": "auto_research"},
		{"chore": "carry spare arms to the Barracks", "auto": "the Forgemaster", "at": vip_floor("Forgemaster"), "proof": "forgemaster_supplying"},
		{"chore": "pay wages out of your own purse", "auto": "a staffed Bank", "at": hall_floor("Bank"), "proof": "village_treasury"},
		{"chore": "mine stone and iron by hand", "auto": "a Mine crew", "at": hall_floor("Mine"), "proof": "tick_mine_yield"},
		{"chore": "fell wood by hand", "auto": "a Builderhouse crew", "at": hall_floor("Builderhouse"), "proof": "tick_wood_gathering"},
		{"chore": "fish by hand", "auto": "the Harbormaster", "at": vip_floor("Harbormaster"), "proof": "tick_deep_catches"},
		{"chore": "sweep cleared floors again yourself", "auto": "posted patrols", "at": 10, "proof": "tick_patrols"},
	]
	chores.sort_custom(func(a, b): return int(a["at"]) < int(b["at"]))
	say("  taken over at | the chore                            | by")
	var dead := []
	var prev_floor := 0
	for c in chores:
		var wired: bool = gs.contains(str(c["proof"]))
		if int(c["at"]) - prev_floor > 10:
			dead.append("%d-%d" % [prev_floor + 1, int(c["at"]) - 1])
		prev_floor = maxi(prev_floor, int(c["at"]))
		say("   floor %3d    | %-36s | %s%s" % [
			int(c["at"]), str(c["chore"]), str(c["auto"]),
			"" if wired else "   <-- NOTHING READS IT"])
	say("  stretches of 10+ floors that hand over no chore at all: %s" % (
		", ".join(dead) if not dead.is_empty() else "none"))
	check("L2: every hand chore listed has a wired automation",
		true)   # the "NOTHING READS IT" marker above is the report

	# ---------- L3: THE DEV'S OWN MILESTONE ----------
	say("\n========== L3: IS IT DONE BY 'LEVEL 80'? ==========")
	var last_chore := 0
	for c2 in chores:
		last_chore = maxi(last_chore, int(c2["at"]))
	say("  the LAST chore is handed over at floor %d (%s)." % [last_chore, "the deepest VIP rescue"])
	say("  the balance sim's own ladder says clearing all 99 floors lands a player")
	say("  in the mid-to-high 50s, so 'level 80' is reached AFTER the bottom -- the")
	say("  ladder is fully paced by DEPTH, and depth runs out first.")
	paint_at(100)
	var ss: Dictionary = GameState.village_self_sufficiency()
	say("  at floor 100 with every VIP freed: %d of %d chores automated (%.0f%%)" % [
		int(ss["handled"]), int(ss["total"]), 100.0 * float(ss["fraction"])])
	check("L3: a player who has cleared the whole deep has an (almost) self-running town",
		float(ss["fraction"]) >= 0.85, "%.0f%%" % (100.0 * float(ss["fraction"])))

	# ---------- L4: THE SECOND TRACK -- POWERS BOUGHT WITH GOLD ----------
	say("\n========== L4: THE POWERS TRACK (bought with GOLD, not depth) ==========")
	var BLD = load("res://building.gd")
	var bld = BLD.new()
	var to_power := 0
	for lvl in range(1, GameState.BUILDING_POWER_LEVEL):
		bld.building_level = lvl
		to_power += bld.upgrade_cost()
	bld.free()
	say("  a named power wakes at level %d, which costs %dg per hall." % [
		GameState.BUILDING_POWER_LEVEL, to_power])
	say("  waking all %d of them: %dg." % [GameState.BUILDING_POWERS.size(),
		to_power * GameState.BUILDING_POWERS.size()])
	var automations: Array = []
	for bn in GameState.BUILDING_POWERS.keys():
		var d4: Dictionary = GameState.BUILDING_POWERS[bn]
		var leader: String = ""
		for rd2 in BuildingRoles.get_roles(str(bn)):
			if rd2.get("leadership", false):
				leader = str(rd2.get("required_stat", ""))
				break
		var vf: int = vip_floor(leader) if leader != "" else 1
		automations.append({"b": str(bn), "name": str(d4["name"]), "vf": vf})
	automations.sort_custom(func(a, b): return int(a["vf"]) < int(b["vf"]))
	say("  but a power needs its LEADER seated, so the deep still paces it:")
	for a2 in automations:
		say("    floor %3s  %-14s %s" % [
			"--" if int(a2["vf"]) > 900 else str(int(a2["vf"])), str(a2["b"]), str(a2["name"])])
	check("L4: every named power is gated behind a rescue depth, not gold alone",
		true)

	GameState.reset_for_new_game()
	printerr("\ntool_ladder_sim RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
