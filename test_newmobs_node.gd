extends Node
# The 9 NEW special mobs (2026-07-27). Each must _ready (build visual/collision), run its
# behaviour -- including its telegraphed async cast -- for a stretch without a runtime error,
# take damage, and die. Plus the two special mechanics: a brood SPLITS into two, and a
# juggernaut's raised guard soaks most damage.

const SPECIAL = preload("res://special_mob.gd")
const LOOP_KINDS = ["sentinel", "arcbinder", "warchief", "voidling", "gazer", "skycaller", "vampire", "juggernaut"]

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(800):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	get_tree().paused = false
	if "god_mode" in p: p.god_mode = true      # survive the mobs we spawn to test them
	var scene := get_tree().current_scene

	for k in LOOP_KINDS:
		var m = SPECIAL.new()
		m.kind = k
		scene.add_child(m)
		m.global_position = p.global_position + Vector2(120, 0)
		for i in range(40):                     # ~0.67s: enough for a first telegraphed cast
			await get_tree().physics_frame
		check("%s lives and acts (incl. its cast) without error" % k,
			is_instance_valid(m) and not m.is_dead and m.health > 0,
			"invalid or dead")
		var got := [false]
		if is_instance_valid(m):
			m.died.connect(func(): got[0] = true)
			m.take_damage(100000)
		await get_tree().physics_frame
		check("%s dies on a lethal blow" % k, got[0])

	# --- brood splits into two gen-1 broods ---
	var b = SPECIAL.new(); b.kind = "brood"
	scene.add_child(b)
	b.global_position = p.global_position + Vector2(150, 0)
	await get_tree().physics_frame
	b.take_damage(100000)
	for i in range(3):
		await get_tree().physics_frame
	var splits := 0
	for m in get_tree().get_nodes_in_group("dungeon_combatant"):
		if is_instance_valid(m) and "kind" in m and m.kind == "brood" and "split_gen" in m and m.split_gen == 1:
			splits += 1
	check("a slain brood splits into two smaller broods", splits == 2, "found %d" % splits)

	# --- juggernaut guard soaks damage; dropping it exposes the mob ---
	var j = SPECIAL.new(); j.kind = "juggernaut"
	scene.add_child(j)
	j.global_position = p.global_position + Vector2(180, 0)
	await get_tree().physics_frame
	j._jug_open = false
	var hp0: int = j.health
	j.take_damage(60)
	var guarded: int = hp0 - j.health
	j._jug_open = true
	var hp1: int = j.health
	j.take_damage(60)
	var exposed: int = hp1 - j.health
	check("juggernaut takes far less while guarding than exposed", guarded < exposed,
		"guarded %d vs exposed %d" % [guarded, exposed])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
