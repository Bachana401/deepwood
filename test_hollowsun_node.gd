extends Node
# THE HOLLOW SUN, FOUGHT (2026-08-06).
#
# Everything about the hardest fight in Deepwood was proven STATICALLY: the
# dictionaries exist and point at each other (test_eclipse_node). Nobody had
# ever put the thing on stage. A boss that crashes on spawn, stands inert, or
# names six abilities it cannot perform passes every static check in the suite.
#
# This test does the fight. In the running game, in the village, through the
# real item and the real gate:
#
#   1. SPAWN     -- a Hollow Signet raised under a true eclipse produces a
#                   director + a live evt_hollowsun body in main.tscn.
#   2. SCALED    -- its HP and damage are the highest of any event boss,
#                   measured off the live EventBoss.DIFF table.
#   3. ABILITIES -- all six of its named abilities EXECUTE. Two independent
#                   proofs: the live AI reaching its own kit unaided, and a
#                   deterministic per-ability probe that watches the cooldown
#                   each do_* stamps when its body completes.
#   4. COMBOS    -- every verb in its four sentences is one it can perform.
#   5. PHASE 2   -- THE CORONA BREAKS fires off real damage, and each of the
#                   three knobs it sets is consumed by live machinery
#                   (cooldown_mult / effective_speed / check_bump's reach).
#   6. DEATH     -- it dies to real damage and the kill pays the exclusive table.
#   7. VILLAGE   -- it fights on top of the town without eating the save.
#
# House rules that bite here: every var is explicitly typed (variant inference
# is a hard compile error in this project and shows up as a six-minute idle,
# not as a parse error), and the boss's death is tracked by INSTANCE ID, never
# by null-checking the reference -- a freed object compares equal to null.

const BS = preload("res://boss.gd")

var fails: int = 0

func check(n: String, ok: bool, d: String = "") -> void:
	if ok:
		printerr("PASS  ", n)
	else:
		fails += 1
		printerr("FAIL  ", n, "   ", d)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

# "" when every building still stands as tall and as whole as it did at the
# snapshot, else the first wound found. A 1-point float tolerance absorbs the
# save file's JSON round-trip (health is stored as a float, read back as an int).
func _village_intact(was_health: Dictionary, was_stage: Dictionary) -> String:
	for b in was_health:
		var now_h: float = float(GameState.building_health.get(b, -1.0))
		if now_h < float(was_health[b]) - 1.0:
			return "%s took %.0f damage;" % [str(b), float(was_health[b]) - now_h]
	for b2 in was_stage:
		if int(GameState.building_stage.get(b2, -1)) < int(was_stage[b2]):
			return "%s was knocked back a build stage;" % str(b2)
	return ""

# The live staged boss, found by boss_id among the hostile group.
func _find_hollowsun() -> Node:
	for c in get_tree().get_nodes_in_group("dungeon_combatant"):
		if "boss_id" in c and str(c.boss_id) == "evt_hollowsun":
			return c
	return null

func _ready() -> void:
	# ---------------- boot into the village ----------------
	var pl: Node = null
	for i in range(1800):
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame
		pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			break
	if pl == null:
		printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
	if get_tree().paused:
		get_tree().paused = false
	await _frames(6)

	var def: Dictionary = BS.BOSSES.get("evt_hollowsun", {})
	var ev: Dictionary = EventBoss.get_event("hollowsun")
	var tier: Dictionary = EventBoss.DIFF.get("eclipse", {})
	if def.is_empty() or ev.is_empty() or tier.is_empty():
		printerr("FAIL  the Hollow Sun is not registered at all"); get_tree().quit(1); return

	# ---------------- clear the stage ----------------
	GameState.opening_done = true
	GameState.harvest_at_home = false
	GameState.despair_dead = false
	GameState.in_dungeon = false
	GameState._summon_pending = false
	GameState.arm_hidden_events()
	GameState.event_rematch_level = {}
	GameState.event_rearm_at = {}
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	await _frames(3)

	# The town is WHOLE and FED before the sky goes out. A village already in
	# ruins cannot be shown to survive anything, and a village dying of hunger
	# would blame the boss for its own empty larder.
	GameState.restore_all_buildings()
	GameState.village_food = GameState.food_capacity()
	GameState.food_empty_hours = 0.0
	var v_health: Dictionary = GameState.building_health.duplicate(true)
	var v_stage: Dictionary = GameState.building_stage.duplicate(true)
	var v_ruined: int = GameState.count_ruined_buildings()
	var v_villagers: int = GameState.rescued_villagers.size()
	var v_deaths: int = GameState.run_villager_deaths
	var v_nodes: int = get_tree().get_nodes_in_group("building").size()
	var v_npcs: int = get_tree().get_nodes_in_group("npc").size()
	var v_gold: int = int(pl.currency)

	# ============================================================
	# 1. IT SPAWNS -- the real item, through the real gate
	# ============================================================
	# The sky goes out HERE AND NOW. (Never by jumping game_hours forward:
	# tick_village_clock plays out the whole skipped span in one tick, so a
	# 9000-hour jump burns buildings down and starves the town before the boss
	# has even landed -- the harness would then blame the Hollow Sun for it.)
	GameState.eclipse_at_hours = float(GameState.game_hours) - 0.01
	check("the sky is under a TRUE eclipse", GameState.is_true_eclipse())

	pl.inventory.add_item("hollow_signet", 1)
	var had: int = pl.inventory.get_count("hollow_signet")
	var used: bool = pl.use_item("hollow_signet")
	check("raising the Hollow Signet during the eclipse is accepted", used)
	check("...and the ring is spent exactly once",
		pl.inventory.get_count("hollow_signet") == had - 1,
		"%d -> %d" % [had, pl.inventory.get_count("hollow_signet")])
	check("the summon claims the stage through its whole countdown",
		GameState._summon_pending or not get_tree().get_nodes_in_group("event_boss_director").is_empty())

	var sig_eff: Dictionary = Inventory.get_item_def("hollow_signet").get("use_effect", {})
	await _seconds(float(sig_eff.get("delay", 5.0)) + 1.0)
	var boss: Node = _find_hollowsun()
	for i in range(240):
		if boss != null:
			break
		await get_tree().physics_frame
		boss = _find_hollowsun()
	check("a director stands on the village stage",
		get_tree().get_nodes_in_group("event_boss_director").size() == 1,
		str(get_tree().get_nodes_in_group("event_boss_director").size()))
	if boss == null:
		printerr("FAIL  THE HOLLOW SUN NEVER APPEARED -- nothing further can be proven")
		printerr("test_hollowsun : RESULT: %d FAILURES" % (fails + 1))
		get_tree().quit(1)
		return
	check("THE HOLLOW SUN STANDS IN THE VILLAGE", is_instance_valid(boss) and boss.is_inside_tree())
	check("...wearing its own name", str(boss.get_display_name()) == str(def.get("name", "")),
		str(boss.get_display_name()))
	check("...as a hostile the world can actually target",
		boss.is_in_group("dungeon_combatant"))
	check("...alive, with a real health pool", int(boss.health) > 0 and int(boss.max_health) > 0,
		"%d/%d" % [int(boss.health), int(boss.max_health)])
	check("...and standing inside the village arena, not in a wall",
		boss.global_position.x >= 70.0 and boss.global_position.x <= boss.arena_width() - 70.0,
		"x %.0f of %.0f" % [boss.global_position.x, boss.arena_width()])
	# it is bounded by the TOWN's own edge, not by the dungeon's 15000 fallback
	var scene: Node = get_tree().current_scene
	var edge: float = float(scene.village_right_edge) if ("village_right_edge" in scene) else -1.0
	check("the village supplies its own arena bound (not the 15000 fallback)",
		edge > 0.0 and is_equal_approx(float(boss.arena_width()), edge + 400.0),
		"arena %.0f, village edge %.0f" % [float(boss.arena_width()), edge])

	# ============================================================
	# 2. IT IS SCALED AS THE HARDEST THING IN THE GAME
	# ============================================================
	var base_hp: float = float(def.get("hp", 0))
	var want_hp: int = int(round(base_hp * float(tier.get("hp", 1.0))))
	check("its pool is the eclipse tier applied to its own body",
		int(boss.max_health) == want_hp, "%d vs %d" % [int(boss.max_health), want_hp])
	check("its damage multiplier is the eclipse tier's",
		is_equal_approx(float(boss.damage_multiplier), float(tier.get("dmg", 1.0))),
		"%.3f vs %.3f" % [float(boss.damage_multiplier), float(tier.get("dmg", 1.0))])
	check("it is fought at the deepest floor the table knows",
		int(boss.boss_floor) == int(tier.get("floor", 0)), str(int(boss.boss_floor)))

	# nothing else staged by ANY event reaches it, on either axis
	var beaten_hp: Array = []
	var beaten_dmg: Array = []
	for oid in EventBoss.ids():
		if str(oid) == "hollowsun":
			continue
		var oev: Dictionary = EventBoss.get_event(str(oid))
		var odef: Dictionary = BS.BOSSES.get(str(oev.get("boss_id", "")), {})
		var otier: Dictionary = EventBoss.DIFF.get(str(oev.get("difficulty", "medium")), {})
		var ohp: int = int(round(float(odef.get("hp", 0)) * float(otier.get("hp", 1.0))))
		if ohp >= want_hp:
			beaten_hp.append("%s %d" % [str(oid), ohp])
		if float(otier.get("dmg", 0.0)) >= float(tier.get("dmg", 0.0)):
			beaten_dmg.append("%s %.2f" % [str(oid), float(otier.get("dmg", 0.0))])
	check("no event boss in the game is staged with more health",
		beaten_hp.is_empty(), str(beaten_hp))
	check("no event boss in the game is staged hitting harder",
		beaten_dmg.is_empty(), str(beaten_dmg))
	check("the eclipse tier tops every other rung of DIFF",
		float(tier.get("hp", 0.0)) > float(EventBoss.DIFF["master"]["hp"])
		and float(tier.get("dmg", 0.0)) > float(EventBoss.DIFF["master"]["dmg"]),
		"hp %.2f dmg %.2f" % [float(tier.get("hp", 0.0)), float(tier.get("dmg", 0.0))])

	# and the damage it deals actually REACHES the player through the real funnel
	var was_god: bool = bool(pl.god_mode)
	pl.god_mode = false
	pl.health = pl.get_max_health() if pl.has_method("get_max_health") else 100
	var hp_before: int = int(pl.health)
	var landed: bool = false
	for i in range(6):   # dodge_chance is a roll; a few swings removes the flake
		boss.deal_player_damage(BS.BEAM_DAMAGE)
		if int(pl.health) < hp_before:
			landed = true
			break
	check("its attacks reach the player for real damage", landed,
		"%d -> %d" % [hp_before, int(pl.health)])
	pl.health = pl.get_max_health() if pl.has_method("get_max_health") else 100
	pl.god_mode = true   # the harness is not here to die to it

	# ============================================================
	# 3a. ITS ABILITIES ARE REAL -- watched firing in a LIVE fight
	# ============================================================
	# Every do_* stamps its own cooldown when the body completes, so a cooldown
	# that JUMPS is proof that ability actually ran. No hooks, no source reading.
	var kit: Array = (def.get("abilities", []) as Array).duplicate()
	var prev: Dictionary = {}
	var fired: Dictionary = {}
	for a in kit:
		prev[str(a)] = float(boss.ability_cd.get(str(a), 0.0))
	var saw_combo: bool = false
	var watch: int = 0
	while watch < 900 and is_instance_valid(boss) and not boss.is_dead:
		watch += 1
		await get_tree().physics_frame
		if bool(boss.in_combo):
			saw_combo = true
		for a in kit:
			var cur: float = float(boss.ability_cd.get(str(a), 0.0))
			if cur > prev[str(a)] + 0.01:
				fired[str(a)] = true
			prev[str(a)] = cur
	check("its own AI reaches its kit unaided -- it does not stand inert",
		not fired.is_empty(), "fired live: " + str(fired.keys()))
	check("it speaks in COMBOS in the village (a combo boss must reach run_combo)",
		saw_combo)

	# ============================================================
	# 3b. ...and every single one, probed deterministically
	# ============================================================
	# A second body, staged the same way but with its AI switched off, so each
	# ability is fired alone and its completion observed with nothing racing it.
	var probe: Node = preload("res://boss.tscn").instantiate()
	probe.boss_id = "evt_hollowsun"
	probe.level_hp_mult = float(tier.get("hp", 1.0))
	probe.damage_multiplier = float(tier.get("dmg", 1.0))
	probe.boss_floor = int(tier.get("floor", 100))
	boss.get_parent().add_child(probe)
	probe.set_physics_process(false)
	probe.global_position = pl.global_position + Vector2(700.0, -40.0)
	await _frames(2)

	var src: String = FileAccess.get_file_as_string("res://boss.gd")
	var dispatch: String = ""
	var d_from: int = src.find("func run_ability(")
	var d_to: int = src.find("func _combo_charge(")
	if d_from >= 0 and d_to > d_from:
		dispatch = src.substr(d_from, d_to - d_from)

	var no_meta: Array = []
	var no_method: Array = []
	var no_branch: Array = []
	var no_effect: Array = []
	for a in kit:
		var an: String = str(a)
		if not BS.ABILITY_META.has(an):
			no_meta.append(an)          # choose_attack can never pick it
		if not probe.has_method("do_" + an):
			no_method.append(an)
		if dispatch != "" and not dispatch.contains('"%s":' % an):
			no_branch.append(an)        # run_combo would silently drop the beat
		probe.ability_cd[an] = 0.0
		probe.is_busy = true
		await probe.run_ability(an)
		if float(probe.ability_cd.get(an, 0.0)) <= 0.0:
			no_effect.append(an)        # the body never reached its own set_cd
		await _frames(1)
	check("every named ability has an ABILITY_META row (or nothing can pick it)",
		no_meta.is_empty(), str(no_meta))
	check("every named ability has a do_* body on the boss", no_method.is_empty(), str(no_method))
	check("every named ability has a run_ability dispatch branch", no_branch.is_empty(), str(no_branch))
	check("EVERY named ability RUNS TO COMPLETION when fired (no named-but-dead verb)",
		no_effect.is_empty(), "never completed: " + str(no_effect))

	# ============================================================
	# 4. ITS COMBO SENTENCES RESOLVE
	# ============================================================
	var chains: Array = BS.BOSS_COMBOS.get("evt_hollowsun", [])
	check("it owns a combo book", not chains.is_empty(), str(chains.size()))
	var foreign: Array = []
	var undispatched: Array = []
	for chain in chains:
		for step in chain:
			var sn: String = str(step)
			if not kit.has(sn):
				foreign.append(sn)      # a verb it was never given
			if not probe.has_method("do_" + sn):
				undispatched.append(sn)
			elif dispatch != "" and not dispatch.contains('"%s":' % sn):
				undispatched.append(sn)
	check("every verb in its sentences is one it actually owns", foreign.is_empty(), str(foreign))
	check("every verb in its sentences can actually be performed",
		undispatched.is_empty(), str(undispatched))
	var live_chains: Array = probe.active_combos()
	var want_len: int = probe.combo_length_for(int(tier.get("floor", 100)))
	var bad_len: Array = []
	for chain2 in live_chains:
		if (chain2 as Array).size() != want_len:
			bad_len.append((chain2 as Array).size())
	check("at the deepest floor its sentences run the full length",
		bad_len.is_empty() and want_len >= 5, "want %d, got %s" % [want_len, str(bad_len)])
	# choose_attack is unreachable for a combo boss, so an ability in NO chain
	# only ever fires through the rare orphan beat -- worth knowing about.
	check("no ability is stranded outside every sentence",
		(probe._orphan_abilities() as Array).is_empty(), str(probe._orphan_abilities()))

	# ============================================================
	# 5. PHASE TWO FIRES, AND ITS KNOBS ARE CONSUMED
	# ============================================================
	check("THE CORONA BREAKS is registered", BS.PHASE_TWO.has("evt_hollowsun"),
		str(BS.PHASE_TWO.get("evt_hollowsun", "")))
	var cd0: float = float(probe.cooldown_mult())
	var spd0: float = float(probe.effective_speed())
	var reach0: float = float(probe.reach_mult)

	# reach_mult is consumed inline by check_bump's threshold: park the player
	# just OUTSIDE the base reach, and the phase alone must bring them inside it.
	var pl_pos: Vector2 = pl.global_position
	var gap: float = BS.BUMP_THRESHOLD * reach0 * 1.06
	probe.global_position = Vector2(pl.global_position.x - gap, pl.global_position.y)
	probe.is_busy = false
	pl.is_knocked_back = false
	pl.knockback_immune_until = 0.0
	probe.check_bump()
	var bumped_before: bool = bool(pl.is_knocked_back)

	probe.phase_two()
	check("phase two ACTIVATES", bool(probe.phase2_active))
	check("...through its OWN branch (phase2_applied is set only there)",
		bool(probe.phase2_applied))
	check("...its kit quickens (phase2_cd_mult is consumed by cooldown_mult)",
		float(probe.cooldown_mult()) < cd0,
		"%.3f -> %.3f" % [cd0, float(probe.cooldown_mult())])
	check("...it stops giving ground (base_move_speed is consumed by effective_speed)",
		float(probe.effective_speed()) > spd0,
		"%.1f -> %.1f" % [spd0, float(probe.effective_speed())])
	pl.is_knocked_back = false
	pl.knockback_immune_until = 0.0
	probe.is_busy = false
	probe.check_bump()
	var bumped_after: bool = bool(pl.is_knocked_back)
	check("...and its reach WIDENS for real (reach_mult is consumed by check_bump)",
		(not bumped_before) and bumped_after,
		"before %s, after %s, reach %.3f -> %.3f" % [str(bumped_before), str(bumped_after), reach0, float(probe.reach_mult)])
	pl.is_knocked_back = false
	pl.global_position = pl_pos
	probe.queue_free()
	await _frames(2)

	# ...and the live body transforms off REAL damage, in the village. It owns
	# `sidestep`, which shrugs a melee-range blow outright, so the wound is dealt
	# over as many swings as it takes -- exactly what a player does.
	check("the live body has not transformed yet", not bool(boss.phase2_active))
	var target_hp: int = int(round(float(boss.max_health) * 0.55))
	var saw_phase: bool = false
	var swings: int = 0
	while int(boss.health) > target_hp and swings < 200 and not bool(boss.is_dead):
		swings += 1
		boss.phase_until = 0.0     # stand still and take the next one
		var before_h: int = int(boss.health)
		boss.take_damage(maxi(1, int(boss.health) - target_hp))
		if int(boss.health) < before_h and boss.is_phased():
			saw_phase = true
		await get_tree().physics_frame
	check("real damage crosses the apex threshold and THE CORONA BREAKS",
		bool(boss.phase2_active) and bool(boss.phase2_applied) and bool(boss.is_enraged),
		"hp %d/%d after %d swings" % [int(boss.health), int(boss.max_health), swings])
	check("...and it steps out of the world after the blow (its `phase` passive is live)",
		bool(boss.has_phase) and saw_phase)

	# ============================================================
	# 7a. THE VILLAGE, MID-FIGHT: nothing corrupts across a save
	# ============================================================
	var keep_eclipse: float = float(GameState.eclipse_at_hours)
	GameState.save_game(pl)
	var keep_state: String = str(GameState.event_state.get("hollowsun", ""))
	var keep_hours: float = float(GameState.game_hours)
	GameState.load_game()
	check("the village survives a save taken with the Hollow Sun on the field",
		_village_intact(v_health, v_stage) == ""
		and GameState.rescued_villagers.size() == v_villagers
		and GameState.count_ruined_buildings() == v_ruined,
		_village_intact(v_health, v_stage) + " villagers %d -> %d, ruined %d -> %d"
			% [v_villagers, GameState.rescued_villagers.size(), v_ruined, GameState.count_ruined_buildings()])
	check("the eclipse clock survives it too -- the sky is still out",
		absf(float(GameState.eclipse_at_hours) - keep_eclipse) < 0.001
		and GameState.is_true_eclipse(),
		"%.4f vs %.4f" % [float(GameState.eclipse_at_hours), keep_eclipse])
	check("the event ledger survives it (triggered relaxes to armed, never lost)",
		GameState.event_state.has("hollowsun"), str(GameState.event_state.get("hollowsun", "")))
	GameState.event_state["hollowsun"] = keep_state
	GameState.game_hours = keep_hours

	# ============================================================
	# 6. IT CAN DIE, AND IT PAYS
	# ============================================================
	for lid in EventBoss.all_loot_ids():
		pl.inventory.remove_item(str(lid), 99)
	var boss_id_num: int = boss.get_instance_id()   # a freed object == null: track by ID
	for i in range(600):
		if not boss.is_phased():
			break
		await get_tree().physics_frame
	check("its intangibility is a window, not a wall (it becomes hittable again)",
		not boss.is_phased())
	# the killing blows go through its FULL defensive gauntlet -- phase, sidestep,
	# the lot -- with nothing switched off. It has to actually be beatable.
	var kill_swings: int = 0
	while not bool(boss.is_dead) and kill_swings < 900:
		kill_swings += 1
		if not boss.is_phased():
			boss.take_damage(int(boss.max_health) * 10)
		await get_tree().physics_frame
	check("THE HOLLOW SUN CAN BE KILLED", bool(boss.is_dead),
		"hp %d after %d swings" % [int(boss.health), kill_swings])
	# the death flourish plays out before the body frees itself; poll by INSTANCE
	# ID, never by null-checking the reference (a freed object == null here)
	var gone: bool = false
	for i in range(600):
		await get_tree().physics_frame
		if instance_from_id(boss_id_num) == null:
			gone = true
			break
	check("...and the body actually leaves the world", gone)

	var got_weapons: int = 0
	for w in ev.get("weapons", []):
		got_weapons += pl.inventory.get_count(str(w))
	check("the kill pays exactly ONE of the two exclusive weapons",
		got_weapons == 1, "%d of %s" % [got_weapons, str(ev.get("weapons", []))])
	var missing: Array = []
	for e in ev.get("extras", []):
		if pl.inventory.get_count(str(e)) < 1:
			missing.append(str(e))
	check("the kill pays every guaranteed extra (crown + plate + ringlight)",
		missing.is_empty(), str(missing))
	check("the ledger records the Hollow Sun as felled",
		str(GameState.event_state.get("hollowsun", "")) == "killed",
		str(GameState.event_state.get("hollowsun", "")))
	check("felling it never counts toward the Hunter's Horn (it is outside the ten)",
		not EventBoss.hunt_ids().has("hollowsun"))

	# ============================================================
	# 6b. THE SECOND SUMMON -- the dev made this fight RECURRING on purpose
	# ============================================================
	var ups: int = int(GameState.event_rematch_level.get("hollowsun", 0))
	check("a felled Hollow Sun schedules a rematch (never a one-shot chance)", ups >= 1, str(ups))
	var again: Dictionary = EventBoss.scaling_for("hollowsun")
	check("A RE-SUMMONED HOLLOW SUN IS NEVER STAGED WEAKER THAN THE FIRST ONE",
		float(again.get("hp", 0.0)) >= float(tier.get("hp", 0.0))
		and float(again.get("dmg", 0.0)) >= float(tier.get("dmg", 0.0)),
		"rematch %s hp %.2f dmg %.2f vs first hp %.2f dmg %.2f"
			% [str(again.get("label", "?")), float(again.get("hp", 0.0)), float(again.get("dmg", 0.0)),
			float(tier.get("hp", 0.0)), float(tier.get("dmg", 0.0))])

	# ============================================================
	# 7b. THE VILLAGE, AFTER: dangerous, but never destructive
	# ============================================================
	await _frames(4)
	check("not one building was harmed by the fight",
		_village_intact(v_health, v_stage) == "" and GameState.count_ruined_buildings() == v_ruined,
		_village_intact(v_health, v_stage) + " ruined %d -> %d"
			% [v_ruined, GameState.count_ruined_buildings()])
	check("every building still stands in the scene",
		get_tree().get_nodes_in_group("building").size() == v_nodes,
		"%d -> %d" % [v_nodes, get_tree().get_nodes_in_group("building").size()])
	check("not one villager was lost to it",
		GameState.rescued_villagers.size() == v_villagers
		and GameState.run_villager_deaths == v_deaths
		and get_tree().get_nodes_in_group("npc").size() == v_npcs,
		"villagers %d->%d deaths %d->%d npcs %d->%d"
			% [v_villagers, GameState.rescued_villagers.size(), v_deaths,
			GameState.run_villager_deaths, v_npcs, get_tree().get_nodes_in_group("npc").size()])
	check("the purse was not raided either", int(pl.currency) >= v_gold,
		"%d -> %d" % [v_gold, int(pl.currency)])
	check("the stage clears itself once the fight is over (no stranded event)",
		str(GameState.event_state.get("hollowsun", "")) == "killed")

	pl.god_mode = was_god
	printerr("test_hollowsun : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
