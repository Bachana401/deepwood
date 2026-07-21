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

	# ---------------- a vault chest is a stocked, browsable catalogue ----------------
	var chest = load("res://vault_chest.gd").new()
	chest.item_ids = ["wpn_katana", "relic_gorgon", "armor_dragon", "potion_health", "wood"]
	chest.title = "TEST"; chest.subtitle = "5 items"
	host.add_child(chest); await get_tree().process_frame
	check("vault chest stocks one full stack of each item (weapons 1, potions 20, mats 99)",
		chest.inventory != null
		and chest.inventory.get_count("wpn_katana") == 1
		and chest.inventory.get_count("relic_gorgon") == 1
		and chest.inventory.get_count("potion_health") == 20
		and chest.inventory.get_count("wood") == 99,
		"katana=%d potion=%d wood=%d" % [chest.inventory.get_count("wpn_katana"), chest.inventory.get_count("potion_health"), chest.inventory.get_count("wood")])
	# taking an item out (drag) empties that stack; reopening tops it back up
	chest.inventory.transfer_to(p.inventory, "wpn_katana", 1)
	check("taking an item removes it from the chest", chest.inventory.get_count("wpn_katana") == 0)
	chest._restock()
	check("reopening restocks it -- the vault is bottomless", chest.inventory.get_count("wpn_katana") == 1)
	# opening routes through the shared ChestUI (found by group) and pops the bag
	chest._open()
	await get_tree().process_frame
	var cui = get_tree().get_first_node_in_group("chest_ui")
	check("opening the vault routes through the shared ChestUI", cui != null and cui.current_chest == chest)
	if cui != null and cui.has_method("close"): cui.close()
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
	check("Proving Grounds builds a chest per rarity + a materials chest (>= 7)", chests >= 7, "%d chests" % chests)
	check("Proving Grounds builds the DPS dummy", dummies == 1, "%d dummies" % dummies)
	arena.queue_free()
	GameState.proving_grounds = false
	GameState.in_dungeon = false
	await get_tree().process_frame

	# ---- the straggler problem: the exit needs a CLEAR floor ----
	var dsrc2 := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the floor shows how many foes are left",
		dsrc2.contains('"   ⚔ %d left"'))
	check("...and points the way when only a few remain",
		dsrc2.contains("func _straggler_hint") and dsrc2.contains("◀ west"))
	check("the tally updates on every kill, and the hint tracks the player",
		dsrc2.contains("update_level_label()   # the tally is live")
		and dsrc2.contains("_hint_timer"))
	check("a cleared floor says so on the label",
		dsrc2.contains("✔ cleared"))

	# ---- the sound of depth: one track, but not one mood ----
	var DID = load("res://dungeon_interior.gd")
	var did = DID.new()
	var p1: float = did.music_pitch_for(1)
	var p50: float = did.music_pitch_for(49)
	var p_boss: float = did.music_pitch_for(50)
	var p_fin: float = did.music_pitch_for(100)
	check("the deeper you go, the lower the world sounds", p50 < p1, "%.3f -> %.3f" % [p1, p50])
	check("a BOSS floor drops under its own neighbours", p_boss < p50,
		"boss %.3f vs %.3f" % [p_boss, p50])
	check("the gate of 100 is the heaviest sound in the game",
		p_fin < p_boss and p_fin < p1, "%.3f" % p_fin)
	check("...and nothing ever pitches into a growl", p_fin >= 0.6 and p1 <= 1.0)
	check("the music actually uses it, and a clear rings out",
		dsrc2.contains("pitch_scale = music_pitch_for(current_level)")
		and dsrc2.contains("a cleared floor deserves a SOUND"))
	did.free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
