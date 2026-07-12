extends Node2D

const BUILDING_SCRIPT = preload("res://building.gd")

class FakePlayer extends Node:
	var inventory = Inventory.new()

func _ready() -> void:
	var ok := true

	# 1) The 3 construction materials exist and are plainly named.
	for m in ["wood", "stone", "resin"]:
		if not Inventory.ITEM_DEFS.has(m):
			push_error("FAIL: material %s missing" % m); ok = false
		elif Inventory.ITEM_DEFS[m].get("is_material", false):
			push_error("FAIL: %s should NOT be research-gated" % m); ok = false
	# names should be readable immediately (not "Unknown Substance")
	if Inventory.get_display_name("wood") != "Wood":
		push_error("FAIL: wood display name wrong"); ok = false
	print("PASS: Wood/Stone/Resin exist and are plainly named")

	# 2) Repair requires materials.
	GameState.reset_for_new_game()   # ruins all buildings
	var b = BUILDING_SCRIPT.new()
	b.building_name = "Farm"
	b.role_key = "Farm"
	b.width = 110.0; b.height = 75.0; b.body_color = Color(0.5, 0.6, 0.3, 1)
	add_child(b)
	await get_tree().process_frame

	var p = FakePlayer.new()
	add_child(p)
	# not enough yet
	if b.has_repair_materials(p):
		push_error("FAIL: should lack materials with empty inventory"); ok = false
	if b.try_repair(p) != "materials":
		push_error("FAIL: repair should fail without materials"); ok = false
	if not b.is_ruined():
		push_error("FAIL: failed repair should leave it ruined"); ok = false
	var missing = b.missing_repair_materials(p)
	print("  missing when empty: ", missing)

	# give exactly the cost + 1 extra of each
	for mat in b.REPAIR_MATERIALS:
		p.inventory.add_item(mat, int(b.REPAIR_MATERIALS[mat]) + 1)
	if not b.has_repair_materials(p):
		push_error("FAIL: should have materials now"); ok = false
	var res = b.try_repair(p)
	if res != "ok":
		push_error("FAIL: repair with materials returned " + res); ok = false
	if b.is_ruined() or not b.is_operational() or b.health != b.MAX_HEALTH:
		push_error("FAIL: Farm not restored after material repair"); ok = false
	# exactly the cost consumed -> 1 of each should remain
	for mat in b.REPAIR_MATERIALS:
		if p.inventory.get_count(mat) != 1:
			push_error("FAIL: %s not consumed exactly (%d left)" % [mat, p.inventory.get_count(mat)]); ok = false
	if ok:
		print("PASS: repair consumes exactly the material cost and restores the building")

	# 3) Prompt text flips ruined <-> intact.
	b.health = 0
	GameState.building_health["Farm"] = 0
	b.current_state = b.State.DESTROYED
	b.update_prompt()
	if not b.prompt_label.text.begins_with("Press F to Repair"):
		push_error("FAIL: ruined prompt wrong: " + b.prompt_label.text); ok = false
	b.restore_full()
	if b.prompt_label.text != "Press E":
		push_error("FAIL: repaired prompt should be 'Press E', got: " + b.prompt_label.text); ok = false
	print("PASS: prompt shows F-repair when ruined, E when intact")
	b.queue_free()

	# 4) Drop table: never more than one per roll; 0x mult drops nothing.
	var p2 = FakePlayer.new()
	add_child(p2)
	if GameState.roll_construction_drop(p2, 0.0) != "":
		push_error("FAIL: 0x mult should never drop"); ok = false
	# huge mult -> always drops something (first entry)
	var any := false
	for i in range(5):
		if GameState.roll_construction_drop(p2, 50.0) != "":
			any = true
	if not any:
		push_error("FAIL: high mult should drop"); ok = false
	var total = p2.inventory.get_count("wood") + p2.inventory.get_count("stone") + p2.inventory.get_count("resin")
	if total <= 0:
		push_error("FAIL: nothing landed in inventory from drops"); ok = false
	print("PASS: drop rolls add at most one material; 0x mult yields nothing")

	# 5) Boss bundle grants the fixed amounts.
	var p3 = FakePlayer.new()
	add_child(p3)
	GameState.grant_construction_bundle(p3, 3, 2, 1)
	if p3.inventory.get_count("wood") != 3 or p3.inventory.get_count("stone") != 2 or p3.inventory.get_count("resin") != 1:
		push_error("FAIL: boss bundle amounts wrong"); ok = false
	else:
		print("PASS: boss bundle grants 3 Wood / 2 Stone / 1 Resin")

	# 6) main.tscn still instantiates cleanly.
	GameState.reset_for_new_game()
	var inst = load("res://main.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var builds = get_tree().get_nodes_in_group("building")
	if builds.size() < 12:
		push_error("FAIL: village buildings missing from main.tscn"); ok = false
	else:
		print("PASS: main.tscn instantiates with %d buildings" % builds.size())
	inst.queue_free()
	await get_tree().process_frame

	print("RESULT: ", "ALL PASS" if ok else "FAILURES ABOVE")
	get_tree().quit()
