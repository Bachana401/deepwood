extends Node

# Headless QC for the weapon roster (run with MONARCH_TEST). Prints every
# weapon sorted by hitbox area alongside its grade, reach, swing speed and
# derived DPS, then flags where the roster contradicts its own rules:
#   * bigger must swing slower  (area up  => cooldown up)
#   * longer must reach further (icon len => range_offset)
#   * nothing may be strictly better than a peer at the same size
# Purely diagnostic -- it changes nothing.

func _ready() -> void:
	await get_tree().process_frame
	var rows := []
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if d.get("category", "") != "weapon":
			continue
		var ws: Dictionary = Inventory.weapon_stats_for(id)
		if ws.is_empty():
			continue
		var area: Vector2 = ws.get("area_size", Vector2.ZERO)
		var icon: Vector2 = ws.get("icon_size", Vector2.ZERO)
		rows.append({
			"id": id,
			"type": str(d.get("weapon_type", "?")),
			"grade": str(Inventory.ITEM_GRADES.get(id, "-")),
			"dmg": float(ws.get("damage", 0)),
			"cd": float(ws.get("cooldown", 0.0)),
			"reach": float(ws.get("range_offset", 0)),
			"area": area,
			"icon": icon,
			"acell": area.x * area.y,
			"slash": not d.get("swing_slash", {}).is_empty(),
		})
	rows.sort_custom(func(a, b): return a["acell"] < b["acell"])

	printerr("== WEAPON ROSTER (by hitbox area) ==")
	printerr("%-22s %-7s %-10s %5s %6s %6s %11s %6s %8s %s" % ["id", "type", "grade", "dmg", "cd", "reach", "area", "drawn", "dps", "slash"])
	for r in rows:
		printerr("%-22s %-7s %-10s %5d %6.2f %6.0f %5.0fx%-5.0f %6.0f %8.1f %s" % [
			r["id"], r["type"], r["grade"], int(r["dmg"]), r["cd"], r["reach"],
			r["area"].x, r["area"].y, r["icon"].x, r["dmg"] / maxf(0.01, r["cd"]),
			"slash" if r["slash"] else ""])

	# --- rule violations: within a weapon type, a bigger hitbox must not also
	# swing faster. That is the "big weapons just win" failure mode.
	printerr("\n== VIOLATIONS: bigger AND faster (same type) ==")
	var bad := 0
	# only weapons that actually SWING are judged -- a bow or wand's hitbox never
	# touches anything (they fire projectiles), so its size is not a rule.
	for a in rows:
		for b in rows:
			if a["type"] != b["type"] or not Inventory.SIZE_BANDS.has(a["type"]):
				continue
			if a["acell"] > b["acell"] * 1.05 and a["cd"] < b["cd"] - 0.001:
				printerr("  %s (area %.0f, cd %.2f) is bigger AND faster than %s (area %.0f, cd %.2f)" % [
					a["id"], a["acell"], a["cd"], b["id"], b["acell"], b["cd"]])
				bad += 1
	printerr("  total: %d" % bad)

	# --- strictly-dominant pairs: same type, >= in every dial and > in one.
	# Same GRADE only: a mythic outclassing a rare is the point of grades. The
	# real fault is two weapons of equal grade where one is free to ignore.
	printerr("\n== VIOLATIONS: strictly dominates a peer (same type AND grade) ==")
	var dom := 0
	for a in rows:
		for b in rows:
			if a["id"] == b["id"] or a["type"] != b["type"] or a["grade"] != b["grade"]:
				continue
			# a weapon with 0 base damage does its work through a projectile
			# special, so comparing it on the damage dial says nothing
			if a["dmg"] <= 0.0 or b["dmg"] <= 0.0:
				continue
			if a["dmg"] >= b["dmg"] and a["cd"] <= b["cd"] and a["reach"] >= b["reach"] and a["acell"] >= b["acell"] \
					and (a["dmg"] > b["dmg"] or a["cd"] < b["cd"] or a["reach"] > b["reach"] or a["acell"] > b["acell"]):
				printerr("  %s [%s] dominates %s [%s]" % [a["id"], a["grade"], b["id"], b["grade"]])
				dom += 1
	printerr("  total: %d" % dom)

	# --- how much spread is there per type? (are weapons actually distinct?)
	printerr("\n== SIZE SPREAD PER TYPE ==")
	var by_type := {}
	for r in rows:
		if not by_type.has(r["type"]):
			by_type[r["type"]] = []
		by_type[r["type"]].append(r)
	for t in by_type.keys():
		var list: Array = by_type[t]
		var lo: float = list[0]["acell"]
		var hi: float = list[list.size() - 1]["acell"]
		printerr("  %-7s n=%-3d smallest %.0f  largest %.0f  spread %.2fx" % [
			t, list.size(), lo, hi, hi / maxf(1.0, lo)])
	get_tree().quit(0)
