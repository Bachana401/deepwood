extends Node

# The Proving Grounds test arena (admin tool): the invincible DPS dummy, the
# item vault chests, and that the arena actually builds all of it.

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
	var host := Node2D.new(); get_tree().root.add_child(host)

	# ---------------- the DPS dummy ----------------
	var d = load("res://dps_dummy.gd").new()
	host.add_child(d); await get_tree().process_frame
	check("dummy is a valid target (group + take_damage + not dead)",
		d.is_in_group("dungeon_combatant") and d.has_method("take_damage") and not d.is_dead)
	d.take_damage(50); d.take_damage(30)
	check("dummy records damage (total + last)", d._total == 80 and d._last == 30, "total=%d last=%d" % [d._total, d._last])
	check("dummy NEVER dies (huge HP, is_dead stays false)", not d.is_dead and d.health >= 1)
	# it accepts every weapon/relic effect without erroring
	d.apply_knockback(1, 100.0); d.apply_status("burn", 3.0, 5.0); d.apply_slow(2.0, 0.5)
	check("dummy petrify is a no-op that reports 'landed'", d.apply_petrify(3.0))
	await get_tree().process_frame
	check("dummy shows a DPS readout", d._label != null and d._label.text.contains("DPS"))
	d.queue_free()

	# ---------------- a vault chest grants its items ----------------
	var before: int = p.inventory.get_count("wpn_katana")
	var chest = load("res://vault_chest.gd").new()
	chest.item_ids = ["wpn_katana", "relic_gorgon", "armor_dragon"]
	chest.title = "TEST"; chest.subtitle = "3 items"
	host.add_child(chest); await get_tree().process_frame
	chest._grant()
	check("chest grants its items into the bag",
		p.inventory.get_count("wpn_katana") > before and p.inventory.get_count("relic_gorgon") >= 1,
		"katana %d->%d" % [before, p.inventory.get_count("wpn_katana")])
	chest.queue_free()

	# ---------------- the arena builds chests + a dummy ----------------
	GameState.proving_grounds = true
	var arena = load("res://dungeon_interior.tscn").instantiate()
	get_tree().root.add_child(arena)
	for i in range(15):
		await get_tree().physics_frame
	var kids = arena.get_node("LevelContainer").find_children("*", "", true, false)
	var chests := 0
	var dummies := 0
	for k in kids:
		var s = k.get_script()
		if s == null: continue
		if s.resource_path.ends_with("vault_chest.gd"): chests += 1
		if s.resource_path.ends_with("dps_dummy.gd"): dummies += 1
	check("Proving Grounds builds a chest per rarity + more (>= 8)", chests >= 8, "%d chests" % chests)
	check("Proving Grounds builds the DPS dummy", dummies == 1, "%d dummies" % dummies)
	arena.queue_free()
	GameState.proving_grounds = false
	GameState.in_dungeon = false
	await get_tree().process_frame

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
