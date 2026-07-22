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
	for s in range(6):                 # a tree is 4 chops; a few extra for the drop tween
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		for i in range(4):
			await get_tree().process_frame
	check("chopping a tree with the axe yields WOOD",
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
	check("mining a rock with the pickaxe yields STONE",
		p.inventory.get_count("stone") > stone0, "stone %d -> %d" % [stone0, p.inventory.get_count("stone")])

	# ---- and the WRONG tool does nothing (still needs the pickaxe on a rock) ----
	p.wield_weapon("tool_axe")
	var rock2 = HN.new()
	rock2.node_type = "rock"
	get_tree().current_scene.add_child(rock2)
	rock2.global_position = p.global_position
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

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
