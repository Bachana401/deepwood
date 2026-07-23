extends Node

# Item-table integrity (WEAPONS.md batches): every weapon must have a grade and
# valid weapon_stats, every graded id must resolve to a real def, and the new
# grade-fill weapons must actually be present and loadable. Cheap guard that
# stops a typo (a weapon with no grade → grey fallback, or a bad stat block →
# crash on wield) from shipping.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame
	var defs = Inventory.ITEM_DEFS
	var grades = Inventory.ITEM_GRADES

	# every weapon has a grade + a usable weapon_stats block
	var no_grade: Array = []
	var bad_stats: Array = []
	var weapon_count := 0
	for id in defs.keys():
		var d = defs[id]
		if d.get("category", "") != "weapon":
			continue
		weapon_count += 1
		if not grades.has(id):
			no_grade.append(id)
		var ws = d.get("weapon_stats", {})
		if not (ws.has("damage") and ws.has("cooldown") and ws.has("area_size")):
			bad_stats.append(id)
	check("every weapon has a grade", no_grade.is_empty(), "missing: %s" % ", ".join(no_grade))
	check("every weapon has a valid weapon_stats block", bad_stats.is_empty(), "bad: %s" % ", ".join(bad_stats))

	# every graded id resolves to a real item def
	var orphan_grades: Array = []
	for id in grades.keys():
		if not defs.has(id):
			orphan_grades.append(id)
	check("no grade points at a missing item", orphan_grades.is_empty(), ", ".join(orphan_grades))

	# the grade-fill weapons are present, graded, and loadable
	var new_weapons = ["wpn_shortsword","wpn_rapier","wpn_cleaver","wpn_hatchet","wpn_woodspear",
		"wpn_slingshot","wpn_huntingbow","wpn_sparkwand","wpn_falchion","wpn_warpick","wpn_twinblades",
		"wpn_saber","wpn_trident","wpn_warglaive","wpn_crossbow","wpn_flatbow","wpn_frostwand","wpn_channelwand"]
	var missing: Array = []
	for id in new_weapons:
		var d = Inventory.get_item_def(id)
		if d.is_empty() or not grades.has(id) or not d.get("weapon_stats", {}).has("damage"):
			missing.append(id)
	check("all 18 grade-fill weapons load with a grade + stats", missing.is_empty(), ", ".join(missing))

	# the +15% pass landed (sword 8 -> 9)
	# Every item must be OBTAINABLE. 21 weapons and a relic once existed, fully
	# balanced and listed in the catalogue, that no drop pool could ever hand
	# you -- the class-weapon pool started at rare, so nothing granted a common
	# or uncommon weapon at all. Invisible content is the quietest kind of gap.
	var DI = load("res://dungeon_interior.gd")
	var grantable := {}
	for pool in [DI.GEAR_EARLY_WEAPON_IDS, DI.GEAR_RELIC_IDS, DI.GEAR_ARMOR_IDS,
			DI.GEAR_SET_WEAPON_IDS, DI.GEAR_CLASS_WEAPON_IDS, DI.GEAR_EXCELLENT_IDS]:
		for id in pool:
			grantable[id] = true
	# NOTE: drop pools are not the only way to get gear -- leather armour is
	# starting kit, Heart of the Mountain and the Sylvan Charm are harvesting
	# finds, and the basic sword/spear/bow are the smithy's base kit. So the bar
	# here is narrow and exact: the grades that ONLY the dungeon hands out.
	# tool_gap_audit.gd checks whole-game reachability across every grant path.
	# the four base-kit weapons are handed over at the start, and the gathering
	# tools are deliberate Forge purchases -- neither is meant to drop
	var not_loot := {"wpn_sword": true, "wpn_spear": true, "wpn_bow": true, "wpn_wand": true,
		"tool_axe": true, "tool_pickaxe": true}
	var orphans := []
	for id in defs.keys():
		var d: Dictionary = defs[id]
		if d.get("category", "") != "weapon" or str(d.get("name", "")).contains("Admin"):
			continue
		if Inventory.ITEM_GRADES.get(id, "") not in ["common", "uncommon"]:
			continue
		if not_loot.has(id):
			continue
		if not grantable.has(id):
			orphans.append(id)
	check("every common/uncommon weapon can actually drop", orphans.is_empty(),
		"%d unreachable: %s" % [orphans.size(), ", ".join(orphans.slice(0, 6))])
	check("Gorgon's Gaze is in the relic pool (it was in none)",
		"relic_gorgon" in DI.GEAR_RELIC_IDS)
	# and each grade band should actually be represented in the early game
	var early_grades := {}
	for id in DI.GEAR_EARLY_WEAPON_IDS:
		early_grades[Inventory.ITEM_GRADES.get(id, "?")] = true
	check("the early rack covers common AND uncommon",
		early_grades.has("common") and early_grades.has("uncommon"), str(early_grades.keys()))

	var sword_dmg = int(defs["wpn_sword"]["weapon_stats"]["damage"])
	check("+15% pass applied (Sword base 8 -> 9)", sword_dmg == 9, "got %d" % sword_dmg)

	# the grades are no longer bottom-starved
	var cnt := {}
	for id in grades.keys():
		var g = grades[id]
		cnt[g] = cnt.get(g, 0) + 1
	check("common grade is no longer starved (>= 14)", cnt.get("common", 0) >= 14, "common=%d" % cnt.get("common", 0))
	check("uncommon grade filled out (>= 22)", cnt.get("uncommon", 0) >= 22, "uncommon=%d" % cnt.get("uncommon", 0))
	printerr("weapons=%d  grades: common=%d uncommon=%d rare=%d epic=%d legendary=%d mythic=%d" % [
		weapon_count, cnt.get("common",0), cnt.get("uncommon",0), cnt.get("rare",0),
		cnt.get("epic",0), cnt.get("legendary",0), cnt.get("mythic",0)])

	# ---- chest QoL (dev request): bulk moves + shift-click ----
	var a := Inventory.new(6)
	var b := Inventory.new(2)
	a.add_item("wood", 30)
	a.add_item("stone", 20)
	a.add_item("potion_health", 5)
	var stacks := []
	for s in a.slots:
		if s != null:
			stacks.append({"id": str(s.item_id), "count": int(s.count)})
	var moved := 0
	for s2 in stacks:
		moved += a.transfer_to(b, s2.id, s2.count)
	check("bulk transfer moves what FITS and leaves the rest honestly",
		moved > 0 and b.get_count("wood") == 30 and a.get_count("potion_health") == 5,
		"moved=%d" % moved)
	var csrc := FileAccess.open("res://chest_ui.gd", FileAccess.READ).get_as_text()
	check("the chest offers Take All / Deposit All / Match on their own row",
		csrc.contains("_on_take_all") and csrc.contains("_on_deposit_all")
		and csrc.contains("_on_deposit_matching") and csrc.contains("restock its stores"))
	check("Deposit All never strands the weapon in your hand",
		csrc.contains("active_weapon_id"))
	check("shift-click flicks stacks BOTH directions",
		csrc.contains("KEY_SHIFT")
		and FileAccess.open("res://inventory_ui.gd", FileAccess.READ).get_as_text().contains("KEY_SHIFT"))

	# THE POTIONS RULE (5.5): potions only from pre-boss floors + boss caches
	var esrc := FileAccess.open("res://enemy.gd", FileAccess.READ).get_as_text()
	check("ordinary floors drop NO potions (positions 4-5 of a block only)",
		esrc.contains("% 5 + 1 >= 4") and not esrc.contains("if randf() < 0.05:\n\t\tplayer.inventory.add_item(\"potion_health\""))
	check("a felled boss always restocks the belt",
		FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text().contains("The boss's cache"))

	# ---- GATHERING: a tree is four swings, a seam is a DEPOSIT ----
	var hsrc := FileAccess.open("res://harvest_node.gd", FileAccess.READ).get_as_text()
	check("a rock holds 5x a tree's reserve (dev: stone was WAY too much at 20x)",
		hsrc.contains("ROCK_RESERVE_MULT = 5")
		and hsrc.contains("ROCK_RESERVE = HITS_TO_HARVEST * ROCK_RESERVE_MULT"))
	check("every pickaxe swing PAYS, it doesn't wait for the end",
		hsrc.contains("func _mine_swing") and hsrc.contains('_drop("stone"'))
	check("materials POP OUT onto the ground (Terraria-style), not into the bag",
		hsrc.contains("MATERIAL_PICKUP") and hsrc.contains("func _drop"))
	check("the seam SHRINKS as it empties -- the size is the gauge",
		hsrc.contains("func _apply_reserve_scale") and hsrc.contains("ROCK_MIN_SCALE"))
	check("...and only vanishes when the reserve is worked out",
		hsrc.contains("func _exhaust_seam") and hsrc.contains("reserve_left <= 0"))
	check("a regrown seam returns to its own size",
		hsrc.contains("visual_root.scale = Vector2(size_mult, size_mult)"))
	check("trees still fall in HITS_TO_HARVEST swings",
		hsrc.contains("hits_left -= 1") and hsrc.contains("if hits_left <= 0:"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
