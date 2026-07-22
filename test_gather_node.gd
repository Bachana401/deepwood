extends Node
# GATHERING (dev report 2026-07-22: "mining and chopping wood doesn't work"). The
# swing used to look for harvest nodes via $AttackArea.get_overlapping_areas(), but
# a harvest node sits on the default collision layer while AttackArea only monitors
# the enemy layer -- so the swing never saw a tree or rock. Now it finds the nearest
# `harvestable` in the group within reach. This proves an axe swing on a tree yields
# WOOD and a pickaxe swing on a rock yields STONE.

var fails := 0
const HN = preload("res://harvest_node.gd")

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
	# unpause past the opening prologue so pausable nodes (the drops) actually tick
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false
	for i in range(30):
		await get_tree().process_frame

	# ---- CHOP A TREE with the axe ----
	check("the player can wield the Woodsman's Axe", p.wield_weapon("tool_axe"))
	var tree = HN.new()
	tree.node_type = "tree"
	get_tree().current_scene.add_child(tree)
	tree.global_position = p.global_position
	await get_tree().process_frame
	var wood0: int = p.inventory.get_count("wood")
	for s in range(6):                 # a tree is ~4 chops
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		for i in range(4):
			await get_tree().process_frame
	for i in range(140):               # the drops toss out, then magnet back to the player
		await get_tree().process_frame
	check("chopping a tree with the axe yields WOOD (dropped, then collected)",
		p.inventory.get_count("wood") > wood0, "wood %d -> %d" % [wood0, p.inventory.get_count("wood")])
	tree.queue_free()

	# ---- MINE A ROCK with the pickaxe ----
	check("the player can wield the Miner's Pickaxe", p.wield_weapon("tool_pickaxe"))
	var rock = HN.new()
	rock.node_type = "rock"
	get_tree().current_scene.add_child(rock)
	rock.global_position = p.global_position
	await get_tree().process_frame
	var stone0: int = p.inventory.get_count("stone")
	for s in range(3):                 # a rock pays on every swing
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		for i in range(4):
			await get_tree().process_frame
	for i in range(140):               # let the dropped stone magnet back
		await get_tree().process_frame
	check("mining a rock with the pickaxe yields STONE (dropped, then collected)",
		p.inventory.get_count("stone") > stone0, "stone %d -> %d" % [stone0, p.inventory.get_count("stone")])

	# ---- and the WRONG tool does nothing (still needs the pickaxe on a rock) ----
	p.wield_weapon("tool_axe")
	var rock2 = HN.new()
	rock2.node_type = "rock"
	get_tree().current_scene.add_child(rock2)
	rock2.global_position = p.global_position
	# clear any drops still magneting in from the real mining above, so they
	# can't trickle into the baseline and fake a "wrong tool mined stone"
	for d in get_tree().get_nodes_in_group("material_pickup"):
		if is_instance_valid(d): d.queue_free()
	await get_tree().process_frame
	var stone1: int = p.inventory.get_count("stone")
	for s in range(2):
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		for i in range(4):
			await get_tree().process_frame
	check("an AXE does not mine a rock (wrong tool)", p.inventory.get_count("stone") == stone1,
		"stone %d -> %d" % [stone1, p.inventory.get_count("stone")])
	rock.queue_free()
	rock2.queue_free()

	# ---- swinging a PLAIN WEAPON at a tree/rock teaches the tool ONCE ----
	GameState.seen_gather_hint = false
	p.wield_weapon("wpn_sword")
	var tree2 = HN.new()
	tree2.node_type = "tree"
	get_tree().current_scene.add_child(tree2)
	tree2.global_position = p.global_position
	await get_tree().process_frame
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	await get_tree().process_frame
	check("a plain-weapon swing at a tree teaches the tool (once)", GameState.seen_gather_hint)
	tree2.queue_free()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
