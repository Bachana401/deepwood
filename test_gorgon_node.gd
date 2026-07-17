extends Node

# Gorgon's Gaze (WEAPONS.md §6, creative relic): a long-cooldown PETRIFY on melee
# hit, built on the petrify primitive. Proves the relic procs, respects its
# cooldown, and that apex/undying bosses resist (and DON'T waste the cooldown).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
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

	# equip Gorgon's Gaze
	check("Gorgon's Gaze is NOT active before equip", not p.has_relic_power("petrify"))
	GameState.equipment.relics[0] = "relic_gorgon"
	check("equipping it grants the petrify power", p.has_relic_power("petrify"))
	p.gorgon_ready_at = 0.0

	var host := Node2D.new(); get_tree().root.add_child(host)

	# ---------------- procs on an enemy ----------------
	var e = load("res://enemy.tscn").instantiate(); host.add_child(e); await get_tree().physics_frame
	e.global_position = p.global_position + Vector2(40, 0)
	p.apply_melee_skills(e, 20)
	check("Gorgon: a struck enemy is turned to stone", e.is_petrified())
	check("Gorgon: firing it starts the cooldown", p.gorgon_ready_at > p._now())
	e.queue_free()

	# ---------------- on cooldown: no second petrify ----------------
	var e2 = load("res://enemy.tscn").instantiate(); host.add_child(e2); await get_tree().physics_frame
	p.apply_melee_skills(e2, 20)   # still on CD
	check("Gorgon: while on cooldown it does NOT petrify again", not e2.is_petrified())
	e2.queue_free()

	# ---------------- apex boss resists, doesn't burn the cooldown ----------------
	p.gorgon_ready_at = 0.0
	var apex = load("res://boss.tscn").instantiate(); apex.boss_id = "eclipse"; host.add_child(apex); await get_tree().process_frame
	p.apply_melee_skills(apex, 20)
	check("Gorgon: an apex boss RESISTS (no stun)", apex.stun_timer == 0.0)
	check("Gorgon: resisting does NOT waste the cooldown", p.gorgon_ready_at == 0.0)
	apex.queue_free()

	# ---------------- a normal boss IS petrified, and it burns the CD ----------------
	var nb = load("res://boss.tscn").instantiate(); nb.boss_id = "gravewarden"; host.add_child(nb); await get_tree().process_frame
	p.apply_melee_skills(nb, 20)
	check("Gorgon: a normal boss IS stoned", nb.stun_timer > 0.0)
	check("Gorgon: landing on the boss spends the cooldown", p.gorgon_ready_at > p._now())
	nb.queue_free()

	GameState.equipment.relics[0] = ""   # cleanup
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
