extends Node

# Roster census (weapons overhaul, 2026-07-28): prints the full rarity /
# class / behavior breakdown of every weapon in the game -- ITEM_DEFS
# originals plus the whole WeaponRoster ladder. Run it headless via
# MONARCH_TEST="res://tool_roster_report.gd" after any roster wave to
# regenerate the numbers for the dev report. Admin gear is excluded: the
# census counts what a player can actually wield.

func _ready() -> void:
	await get_tree().process_frame
	var ids := {}
	for id in Inventory.ITEM_DEFS.keys():
		var d0: Dictionary = Inventory.ITEM_DEFS[id]
		if d0.get("category", "") != "weapon":
			continue
		if str(d0.get("name", "")).contains("Admin"):
			continue
		ids[id] = true
	for id in WeaponRoster.all_ids():
		ids[id] = true

	var by_grade := {}
	var by_class := {}
	var by_beh := {}
	var grid := {}   # grade -> class -> count
	for id in ids.keys():
		var d: Dictionary = Inventory.get_item_def(id)
		var g := str(Inventory.get_grade(id))
		var sp: Dictionary = d.get("special", {})
		var c := str(d.get("weapon_type", "?"))
		if str(sp.get("type", "")) == "staff_extend":
			c = "staff"   # staves read as melee to the combat code on purpose
		by_grade[g] = by_grade.get(g, 0) + 1
		by_class[c] = by_class.get(c, 0) + 1
		if not grid.has(g):
			grid[g] = {}
		grid[g][c] = grid[g].get(c, 0) + 1
		var b := str(sp.get("type", "plain"))
		if b == "plain" and sp.has("status"):
			b = "plain+status"
		by_beh[b] = by_beh.get(b, 0) + 1

	var grade_order := ["common", "uncommon", "rare", "epic", "legendary",
		"mythic", "ascended", "monarch"]
	printerr("TOTAL WEAPONS: %d" % ids.size())
	printerr("-- by grade --")
	for g in grade_order:
		printerr("  %-10s %d" % [g, by_grade.get(g, 0)])
	printerr("-- by class --")
	for c in ["melee", "spear", "bow", "wand", "staff"]:
		printerr("  %-10s %d" % [c, by_class.get(c, 0)])
	printerr("-- grade x class --")
	for g in grade_order:
		var row: Dictionary = grid.get(g, {})
		printerr("  %-10s melee=%d spear=%d bow=%d wand=%d staff=%d" % [g,
			row.get("melee", 0), row.get("spear", 0), row.get("bow", 0),
			row.get("wand", 0), row.get("staff", 0)])
	printerr("-- by behavior --")
	var keys := by_beh.keys()
	keys.sort()
	for b in keys:
		printerr("  %-14s %d" % [b, by_beh[b]])

	# ---- DPS curve (damage control): per-tier medians + outliers ----
	# Raw DPS = damage / cooldown from each def. Wands read special.damage
	# (their weapon_stats.damage is 0 by design). A row deviating far from
	# its tier median is either a flagship EARNING its crown or a typo --
	# the list below is the tuning worklist, eyeballed not auto-changed.
	var tier_dps := {}   # rank -> Array[float]
	var row_dps := {}    # id -> dps
	for id in ids.keys():
		var d: Dictionary = Inventory.get_item_def(id)
		var ws: Dictionary = d.get("weapon_stats", {})
		var dmg := float(ws.get("damage", 0))
		if dmg <= 0.0:
			dmg = float(d.get("special", {}).get("damage", 0))
		var cd := maxf(0.05, float(ws.get("cooldown", 0.5)))
		if dmg <= 0.0:
			continue   # the classic nuke wand and kin: no numeric damage
		var dps := dmg / cd
		row_dps[id] = dps
		var rank := int(Inventory.GRADE_DEFS.get(Inventory.get_grade(id), {}).get("rank", 1))
		if not tier_dps.has(rank):
			tier_dps[rank] = []
		tier_dps[rank].append(dps)
	printerr("-- DPS by tier (median [min..max]) --")
	var medians := {}
	for rank in range(1, 9):
		var arr: Array = tier_dps.get(rank, [])
		if arr.is_empty():
			continue
		arr.sort()
		var med: float = arr[arr.size() / 2]
		medians[rank] = med
		printerr("  tier %d  %5.1f  [%5.1f .. %5.1f]  (n=%d)" % [rank, med, arr[0], arr[arr.size() - 1], arr.size()])
	printerr("-- outliers (>60%% off their tier median) --")
	var out_n := 0
	for id in row_dps.keys():
		var rank2 := int(Inventory.GRADE_DEFS.get(Inventory.get_grade(id), {}).get("rank", 1))
		var med2: float = medians.get(rank2, 0.0)
		if med2 <= 0.0:
			continue
		var ratio: float = row_dps[id] / med2
		if ratio > 1.6 or ratio < 0.4:
			out_n += 1
			printerr("  %-20s t%d  dps %5.1f  (%0.2fx median)" % [id, rank2, row_dps[id], ratio])
	printerr("  (%d outliers)" % out_n)
	get_tree().quit(0)
