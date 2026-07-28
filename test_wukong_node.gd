extends Node

# THE WUKONG ROADS (2026-07-28): 8 tree skills + 3 relic-runes, proven
# headless. Every mechanic key must be READ by real code (the
# named-but-never-read guard), and each mechanic must demonstrably fire:
# the third hop, the flip, the pillar, the gold mark, the stopping word,
# the mirror-mage, the splitting shade, the ward ring, the stone save and
# the riddled staff.

const WP = preload("res://weapon_projectile.gd")
const ENEMY_SCENE = preload("res://enemy.tscn")

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _spawn_dummy(host: Node, pos: Vector2) -> Node:
	var e = ENEMY_SCENE.instantiate()
	e.respawns = false
	host.add_child(e)
	e.global_position = pos
	e.set_physics_process(false)
	e.add_to_group("course_enemy")
	return e

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _ready() -> void:
	var pl: Node = null
	for i in range(1200):
		await get_tree().process_frame
		pl = get_tree().get_first_node_in_group("player")
		if pl != null:
			break
	if pl == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(40):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	var saved_skills = GameState.unlocked_skills.duplicate()
	var saved_relics = GameState.equipment.relics.duplicate()

	# ---- the tree: all 8 roads exist, with valid prereqs + unique keys ----
	var road_keys := {"sw_wk1": "somersault", "sw_wk2": "pillar_stance",
		"ar_wk1": "golden_gaze", "ar_wk2": "cloud_step",
		"mg_wk1": "stillness", "mg_wk2": "hair_clone",
		"nc_wk1": "clone_burst", "nc_wk2": "monarch_air"}
	var missing := []
	for id in road_keys.keys():
		var node = SkillTreeData.get_node_by_id(id)
		if node.is_empty() or not node.get("effect", {}).has(road_keys[id]) \
				or SkillTreeData.get_node_by_id(str(node.get("prereq", ""))).is_empty():
			missing.append(id)
	check("all 8 Wukong roads stand in the trees, keyed and reachable",
		missing.is_empty(), ", ".join(missing))

	# ---- named-but-never-read guard: every key is CONSUMED by real code ----
	var sources := ""
	for f in ["player.gd", "arrow.gd", "weapon_projectile.gd", "shade.gd", "enemy.gd"]:
		sources += FileAccess.open("res://" + f, FileAccess.READ).get_as_text()
	var unread := []
	for key in ["somersault", "pillar_stance", "cloud_step", "golden_gaze",
			"stillness", "hair_clone", "clone_burst", "monarch_air",
			"sanctuary", "stone_guise", "staff_mastery"]:
		if not sources.contains('"%s"' % key):
			unread.append(key)
	check("every Wukong key is read by the mechanics code", unread.is_empty(), ", ".join(unread))

	var host := Node2D.new()
	get_tree().root.add_child(host)
	var base: Vector2 = pl.global_position + Vector2(3000.0, -400.0)

	# ---- air kit: the third hop and the flip ----
	GameState.unlocked_skills = ["ar_root", "ar_r1", "ar_r2", "ar_wk2"]
	pl.has_double_jump = true
	pl.jumps_used = 2
	check("Cloud Step opens a third hop past the double jump", pl.wukong_air_hop_allowed())
	pl.jumps_used = 3
	check("...and the sky has only so many stairs", not pl.wukong_air_hop_allowed())
	GameState.unlocked_skills = ["sw_root", "sw_b1", "sw_wk1"]
	pl.somersault_ready_at = 0.0
	check("Somersault answers when every hop is spent", pl.somersault_ready())
	var vx_before: float = pl.velocity.x
	pl.perform_somersault()
	check("...the flip carries real forward speed", absf(pl.velocity.x) >= 600.0,
		"vx %0.0f -> %0.0f" % [vx_before, pl.velocity.x])
	check("...and it goes on cooldown", not pl.somersault_ready())
	await _frames(24)   # let the borrowed dash machinery settle

	# ---- the Golden Gaze: the mark amplifies everything that follows ----
	var gz = _spawn_dummy(host, base)
	var h0: int = gz.health
	gz.take_damage(20)
	var plain_loss: int = h0 - gz.health
	gz.set_meta("gold_mark_until", Time.get_ticks_msec() / 1000.0 + 30.0)
	var h1: int = gz.health
	gz.take_damage(20)
	var marked_loss: int = h1 - gz.health
	check("a gold-marked foe takes more from the same blow", marked_loss > plain_loss,
		"plain %d vs marked %d" % [plain_loss, marked_loss])

	# ---- Stillness: the stopping word, statistically certain ----
	GameState.unlocked_skills = ["mg_root", "mg_e1", "mg_e2", "mg_wk1"]
	var st = _spawn_dummy(host, base + Vector2(160, 0))
	var wp = WP.new()
	wp.kind = "frost_shard"
	wp.from_wand = true
	host.add_child(wp)
	wp.global_position = base + Vector2(200, -40)
	var froze := false
	for i in range(80):   # P(miss all) = 0.88^80 ~ 4e-5
		wp._apply_status_to(st)
		if st.status_freeze_until > Time.get_ticks_msec() / 1000.0:
			froze = true
			break
	check("a wand bolt can speak the stopping word (freeze proc)", froze)
	wp.queue_free()

	# ---- The Plucked Hair: the mirror-mage stands when enemies press ----
	GameState.unlocked_skills = ["mg_root", "mg_s1", "mg_s2", "mg_wk2"]
	pl.hair_ready_at = 0.0
	var press = _spawn_dummy(host, pl.global_position + Vector2(180, 0))
	await _frames(12)
	var mirror = get_tree().get_first_node_in_group("player_mirror")
	check("the Plucked Hair stands a mirror-mage when threatened", mirror != null)
	if mirror != null:
		mirror.queue_free()
	press.queue_free()

	# ---- The Splitting Dark: a falling shade tears itself in two ----
	GameState.unlocked_skills = ["nc_root", "nc_l1", "nc_l2", "nc_wk1"]
	var shade = load("res://shade.gd").new()
	shade.owner_player = pl
	shade.damage = 10
	host.add_child(shade)
	shade.global_position = base + Vector2(0, -200)
	await _frames(2)
	shade.dissolve()
	await _frames(2)
	var splinters := 0
	for c in host.get_children():
		if "is_splinter" in c and c.is_splinter:
			splinters += 1
	check("the falling shade tears itself in TWO", splinters == 2, "got %d" % splinters)
	var resplit := 0
	for c in host.get_children():
		if "is_splinter" in c and c.is_splinter:
			c.dissolve()
	await _frames(2)
	for c in host.get_children():
		if "is_splinter" in c and c.is_splinter and not c._dying:
			resplit += 1
	check("...and splinters never re-split", resplit == 0, "%d fresh splinters" % resplit)

	# ---- Circle of Sanctuary: stand still, and shots die at the edge ----
	GameState.unlocked_skills = []
	GameState.equipment.relics[0] = "rune_sanctuary"
	var shot := Node2D.new()
	shot.add_to_group("enemy_projectile")
	host.add_child(shot)
	shot.global_position = pl.global_position + Vector2(60, -20)
	for i in range(10):   # hold the player truly still, however the ground behaves
		pl.velocity = Vector2.ZERO
		pl._still_t = 5.0
		if is_instance_valid(shot):
			shot.global_position = pl.global_position + Vector2(60, -20)
		await get_tree().physics_frame
	check("the ward ring kills the shot inside it", not is_instance_valid(shot))

	# ---- Stone Guise: the killing blow lands on stone, once per floor ----
	GameState.equipment.relics[0] = "rune_stoneguise"
	pl.stone_guise_floor = ""
	pl.health = 5
	pl.suffer_lethal()
	check("the killing blow lands on STONE instead", not pl.is_dead and pl.health == 1,
		"dead=%s hp=%d" % [pl.is_dead, pl.health])
	var saved_key: String = pl.stone_guise_floor
	check("...and the guise remembers where it fired", saved_key != "")

	# ---- The Riddle Staff: the combo holds one beat longer ----
	GameState.equipment.relics[0] = ""
	var saved_def = pl.active_def
	pl.active_def = {"special": {"type": "staff_extend"}}
	pl._staff_last_hit_at = Time.get_ticks_msec() / 1000.0
	pl._staff_combo = 4
	var reach_plain: float = pl.staff_reach_mult()
	GameState.equipment.relics[0] = "rune_riddlestaff"
	var reach_runed: float = pl.staff_reach_mult()
	check("the Riddle Staff draws a FOURTH stage of reach", reach_runed > reach_plain,
		"%0.2f vs %0.2f" % [reach_plain, reach_runed])

	# ---- the buff/debuff chips (polish): timed things are VISIBLE ----
	pl.add_buff("all_damage", 4.0, 30.0)
	pl.poison_until = Time.get_ticks_msec() / 1000.0 + 10.0
	await _frames(30)   # at least one 0.3s chip rebuild
	var chip_texts := []
	if pl.buff_row != null:
		for c in pl.buff_row.get_children():
			chip_texts.append(str(c.text))
	var has_fed := false
	var has_poison := false
	for t in chip_texts:
		if str(t).begins_with("Well Fed"):
			has_fed = true
		if str(t).begins_with("Poisoned"):
			has_poison = true
	check("the chips name the feast AND the poison", has_fed and has_poison, str(chip_texts))
	pl.active_buffs.clear()
	pl.poison_until = 0.0

	# ---- restore the world ----
	pl.active_def = saved_def
	GameState.unlocked_skills = saved_skills
	GameState.equipment.relics = saved_relics
	pl.has_double_jump = false
	pl.health = pl.get_max_health()
	if is_instance_valid(gz): gz.queue_free()
	if is_instance_valid(st): st.queue_free()
	host.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
