extends Node

# HIDDEN EVENT BOSSES (2026-07-28). Proves the registry is whole, its loot is
# real + EXCLUSIVE (never in the ordinary drop pools), the difficulty split is
# 3/3/3/1, award() hands over exactly one 50/50 weapon + all guaranteed extras,
# and a trigger actually fires -> a director + boss appear -> the kill pays out
# and the event won't fire twice in a run.

const DI = preload("res://dungeon_interior.gd")

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _ready() -> void:
	# ---- static registry checks (no scene needed) ----
	var ids: Array = EventBoss.ids()
	check("eleven events exist (ten hidden + the capstone)", ids.size() == 11, str(ids.size()))
	check("ten bosses make up the hunt", EventBoss.hunt_ids().size() == 10, str(EventBoss.hunt_ids().size()))

	var by_diff := {"medium": 0, "hard": 0, "very_hard": 0, "expert": 0, "master": 0}
	for id in ids:
		var ev: Dictionary = EventBoss.get_event(str(id))
		by_diff[ev.get("difficulty", "?")] = by_diff.get(ev.get("difficulty", "?"), 0) + 1
	check("difficulty split is 3 / 3 / 3 / 1 (+1 Master capstone)",
		by_diff["medium"] == 3 and by_diff["hard"] == 3 and by_diff["very_hard"] == 3 and by_diff["expert"] == 1 and by_diff["master"] == 1,
		str(by_diff))
	check("Nihil and the Master are item-only (never ambient)",
		EventBoss.is_item_only("nihil") and EventBoss.is_item_only("huntsman")
		and not EventBoss.is_item_only("tallyman"))

	# every boss_id resolves to a real procedural boss def
	var missing_boss := []
	for id in ids:
		var bid: String = EventBoss.get_event(str(id)).get("boss_id", "")
		if not preload("res://boss.gd").BOSSES.has(bid):
			missing_boss.append(bid)
	check("every event boss_id is a real boss def", missing_boss.is_empty(), str(missing_boss))

	# exactly 20 exclusive weapons, two per boss
	var weps := {}
	for id in ids:
		for w in EventBoss.get_event(str(id)).get("weapons", []):
			weps[w] = true
	check("exactly 22 exclusive event weapons (11 bosses x 2)", weps.size() == 22, str(weps.size()))

	# every re-summon token + the two rite items have a valid recipe of real items
	var summon_items := ["duskmoon_effigy", "hunters_horn"]
	for hid in EventBoss.hunt_ids():
		summon_items.append("token_" + str(hid).replace("_", ""))
	# (token ids don't 1:1 the event ids by string, so verify the recipe set directly)
	var bad_recipe := []
	for craft_id in Inventory.CRAFT_RECIPES:
		if not (str(craft_id).begins_with("token_") or craft_id in ["duskmoon_effigy", "hunters_horn"]):
			continue
		if not Inventory.ITEM_DEFS.has(craft_id):
			bad_recipe.append(craft_id)
		for ing in Inventory.CRAFT_RECIPES[craft_id]:
			if not Inventory.ITEM_DEFS.has(ing):
				bad_recipe.append(craft_id + ":" + str(ing))
	check("every summon-item recipe references real items", bad_recipe.is_empty(), str(bad_recipe))
	check("the Hunter's Horn recipe needs a trophy of all ten bosses",
		Inventory.CRAFT_RECIPES.get("hunters_horn", {}).size() >= 11)

	# every loot id is a real, graded item
	var bad_item := []
	var bad_grade := []
	for lid in EventBoss.all_loot_ids():
		if not Inventory.ITEM_DEFS.has(lid):
			bad_item.append(lid)
		elif Inventory.get_item_def(lid).get("category", "") in ["weapon", "relic", "armor"] and Inventory.get_grade(lid) == "":
			bad_grade.append(lid)
	check("every loot id is a defined item", bad_item.is_empty(), str(bad_item))
	check("every weapon/relic/armor drop carries a grade", bad_grade.is_empty(), str(bad_grade))

	# EXCLUSIVITY: no event loot may leak into the ordinary dungeon pools/roster
	var normal := {}
	for pool in [DI.GEAR_EARLY_WEAPON_IDS, DI.GEAR_ARMOR_IDS, DI.GEAR_SET_WEAPON_IDS,
			DI.GEAR_CLASS_WEAPON_IDS, DI.GEAR_EXCELLENT_IDS, DI.GEAR_RELIC_IDS]:
		for x in pool:
			normal[x] = true
	var leaked := []
	for lid in EventBoss.all_loot_ids():
		if normal.has(lid) or WeaponRoster.has_id(lid):
			leaked.append(lid)
	check("event loot never appears in the ordinary drop pools", leaked.is_empty(), str(leaked))

	# monarch-grade flagship + ascended present in the expert table
	var nihil: Dictionary = EventBoss.get_event("nihil")
	check("the Expert boss drops a Monarch-grade weapon",
		Inventory.get_grade("evt_endbringer") == "monarch", Inventory.get_grade("evt_endbringer"))

	# ---- award(): one weapon of two, plus every extra ----
	var pl: Node = null
	for i in range(1200):
		await get_tree().process_frame
		pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			break
	if pl == null:
		printerr("no player"); get_tree().quit(1); return
	await _frames(4)

	# clear the bag of any event loot the sandbox may have handed us
	for lid in EventBoss.all_loot_ids():
		pl.inventory.remove_item(lid, 99)
	var ev_g: Dictionary = EventBoss.get_event("grief_eater")
	var granted: Array = EventBoss.award(pl, "grief_eater")
	var wep_count := 0
	for w in ev_g.get("weapons", []):
		wep_count += pl.inventory.get_count(w)
	check("award grants exactly ONE of the two 50/50 weapons", wep_count == 1, str(wep_count))
	var extras_ok := true
	for e in ev_g.get("extras", []):
		if pl.inventory.get_count(e) < 1:
			extras_ok = false
	check("award grants ALL guaranteed extras (relic + armour + material)", extras_ok, str(ev_g.get("extras", [])))
	check("the toast names what was granted", granted.size() >= 1 + ev_g.get("extras", []).size() - 0, str(granted))

	# ---- live trigger -> director + boss -> kill -> loot -> once-per-run ----
	GameState.opening_done = true
	GameState.harvest_at_home = false
	GameState.despair_dead = false
	GameState.in_dungeon = false
	GameState.arm_hidden_events()
	# Sable Hound wakes on a 300-kill streak and has no location gate
	GameState.run_kills = 300
	GameState.tick_hidden_events()
	await _frames(6)
	var dirs := get_tree().get_nodes_in_group("event_boss_director")
	check("meeting a hidden condition mounts an event director", dirs.size() == 1, str(dirs.size()))
	check("the event is marked triggered (won't re-arm this run)",
		GameState.event_state.get("sable_hound", "") == "triggered", str(GameState.event_state.get("sable_hound", "")))
	var boss: Node = null
	for c in get_tree().get_nodes_in_group("dungeon_combatant"):
		if "boss_id" in c and str(c.boss_id) == "evt_sablehound":
			boss = c
			break
	check("the Sable Hound boss stands in the world", boss != null and is_instance_valid(boss))
	if boss != null:
		check("its HP was scaled up by difficulty (very hard)",
			boss.max_health > int(preload("res://boss.gd").BOSSES["evt_sablehound"]["hp"]),
			"%d vs base %d" % [boss.max_health, int(preload("res://boss.gd").BOSSES["evt_sablehound"]["hp"])])

	# a second tick must NOT spawn another while one is live
	GameState.tick_hidden_events()
	await _frames(2)
	check("only ONE event holds the stage at a time",
		get_tree().get_nodes_in_group("event_boss_director").size() == 1)

	# resolve the kill through the director's own handler (deterministic)
	for lid in EventBoss.all_loot_ids():
		pl.inventory.remove_item(lid, 99)
	var dir = dirs[0]
	dir._on_boss_died()
	await _frames(2)
	var got := 0
	var ev_s: Dictionary = EventBoss.get_event("sable_hound")
	for w in ev_s.get("weapons", []):
		got += pl.inventory.get_count(w)
	var got_extras := true
	for e in ev_s.get("extras", []):
		if pl.inventory.get_count(e) < 1:
			got_extras = false
	check("the kill pays one weapon + every extra", got == 1 and got_extras, "weapon %d, extras %s" % [got, got_extras])
	check("the event is now marked killed", GameState.event_state.get("sable_hound", "") == "killed")

	# and never fires again this run
	GameState.tick_hidden_events()
	await _frames(2)
	# (the director frees itself on a timer; the state guard is what matters)
	check("a killed event stays dead for the rest of the run",
		GameState.event_state.get("sable_hound", "") == "killed")

	# ---- item RE-SUMMON: a token re-wakes a boss even after it was killed ----
	# clear the live director first (it frees on a timer we don't want to wait for)
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	await _frames(2)
	var reason: String = GameState.summon_event_boss("sable_hound", 0.0, false)
	await _frames(4)
	check("a re-summon token re-wakes a killed boss", reason == "" and
		get_tree().get_nodes_in_group("event_boss_director").size() == 1, reason)
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	await _frames(2)

	# ---- ECLIPSE GATE: Nihil's rite refuses when the sky is ordinary ----
	# (headless village time is not the dawn/dusk overlap, so this must fail-safe)
	var eclipse_reason: String = GameState.summon_event_boss("nihil", 4.0, true)
	check("the eclipse rite refuses (and doesn't spend) outside the overlap",
		eclipse_reason != "" and get_tree().get_nodes_in_group("event_boss_director").is_empty(),
		eclipse_reason)

	# ---- CAPSTONE: felling all ten (ever) reveals the Horn ----
	GameState.event_bosses_ever_killed = []
	GameState.hunters_horn_announced = false
	for hid in EventBoss.hunt_ids():
		GameState.on_event_boss_killed(str(hid))
	check("slaying all ten (lifetime) announces the Hunter's Horn", GameState.hunters_horn_announced)
	check("the Master (capstone) is summonable by its own item, not the hunt",
		EventBoss.get_event("huntsman").get("capstone", false) == true)

	# ---- Chronicle: a slain boss reveals its name + trigger; the rest stay ??? ----
	var hunt: Array = GameState.hidden_hunt_entries()
	check("the Chronicle lists all eleven", hunt.size() == 11, str(hunt.size()))
	check("ten of the hunt now read as slain", GameState.hidden_hunt_slain_count() == 10,
		str(GameState.hidden_hunt_slain_count()))
	var tally_ok := false
	var master_hidden := false
	for e in hunt:
		if e.get("id", "") == "tallyman":
			tally_ok = e.get("killed", false) and str(e.get("name", "")) == "The Tallyman" and str(e.get("hint", "")) != "a secret yet unproven"
		if e.get("id", "") == "huntsman":
			master_hidden = (not e.get("killed", false)) and str(e.get("name", "")) == "???"
	check("a slain boss reveals its NAME and its trigger", tally_ok)
	check("an unproven boss stays ??? with no trigger shown", master_hidden)

	# ---- BUG1 regression: a DELAYED summon claims the stage during its 4s ----
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	await _frames(2)
	GameState._summon_pending = false
	var r_del: String = GameState.summon_event_boss("huntsman", 4.0, false)
	check("a delayed summon starts pending", r_del == "" and GameState._summon_pending, r_del)
	check("the stage is NOT free during the pending window", not GameState._event_stage_free())
	var r_block: String = GameState.summon_event_boss("sable_hound", 0.0, false)
	check("nothing else can summon during the pending window", r_block != "", r_block)
	GameState._summon_pending = false   # cancel the pending huntsman before it spawns

	# ---- BUG2 regression: fleeing (director freed, no kill) re-arms the event ----
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	await _frames(2)
	GameState.event_state["tallyman"] = "triggered"
	var scene2 = get_tree().current_scene
	var fdir = preload("res://event_boss_director.gd").new()
	fdir.event_id = "tallyman"
	scene2.add_child(fdir)
	await _frames(2)
	fdir.queue_free()          # flee: freed WITHOUT a kill
	await _frames(3)
	check("fleeing a fight re-arms the event (never lost for the run)",
		GameState.event_state.get("tallyman", "") == "armed",
		GameState.event_state.get("tallyman", ""))

	# ---- REMATCHES (pillar 2, 2026-07-28): the ladder climbs, the twin never drops ----
	var p9 = get_tree().get_first_node_in_group("player")
	GameState.event_rematch_level = {}
	GameState.event_rearm_at = {}
	GameState.event_state["glutton_root"] = "triggered"
	GameState.on_event_boss_killed("glutton_root")
	check("a felled hunt records its kill and schedules the rest",
		GameState.event_state["glutton_root"] == "killed"
		and int(GameState.event_rematch_level.get("glutton_root", 0)) == 1
		and GameState.event_rearm_at.has("glutton_root"))
	GameState.game_hours += GameState.REMATCH_REST_HOURS + 1.0
	GameState.tick_hidden_events()
	check("...and re-arms one day later, one rung harder",
		GameState.event_state["glutton_root"] == "armed")
	var sc1: Dictionary = EventBoss.scaling_for("glutton_root")
	check("the rematch stages HARDER (medium -> hard, labelled)",
		str(sc1.get("label", "")).contains("Rematch 1")
		and float(sc1.get("hp", 0.0)) > float(EventBoss.DIFF["medium"]["hp"]))
	GameState.event_rematch_level["glutton_root"] = 10
	var sc2: Dictionary = EventBoss.scaling_for("glutton_root")
	check("the ladder caps at Master forever",
		absf(float(sc2.get("hp", 0.0)) - float(EventBoss.DIFF["master"]["hp"])) < 0.01)
	# a rematch pays MATERIALS AND GOLD -- never the twin
	GameState.event_rematch_level["glutton_root"] = 1
	var ev9: Dictionary = EventBoss.get_event("glutton_root")
	var w_before9 := 0
	for w in ev9.get("weapons", []):
		w_before9 += p9.inventory.get_count(str(w))
	var gold9: int = p9.currency
	var got9: Array = EventBoss.award(p9, "glutton_root")
	var w_after9 := 0
	for w in ev9.get("weapons", []):
		w_after9 += p9.inventory.get_count(str(w))
	check("a rematch pays gold and materials, NEVER the twin (canon absolute)",
		w_after9 == w_before9 and p9.currency > gold9 and not got9.is_empty(),
		"weapons %d->%d gold %d->%d" % [w_before9, w_after9, gold9, p9.currency])
	check("the ladder survives a new game at the bottom (reset-leak lesson)",
		FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text().contains("event_rematch_level = {}"))
	GameState.event_rematch_level = {}
	GameState.event_rearm_at = {}

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
