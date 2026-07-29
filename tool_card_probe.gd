extends Node
# CARD PROBE (dev: "check please and make sure weapons are good"): expands a
# ladder-spanning sample and prints each card as the player meets it --
# damage, speed, soul, words -- for a HUMAN taste check, not an audit.

func _ready() -> void:
	await get_tree().process_frame
	var sample := ["wpn_oakcudgel", "wpn_stingerbow", "wpn_bellhammer",
		"wpn_winterwheel", "wpn_daybreakedge", "wpn_eclipsewheel",
		"wpn_afterlight", "wpn_borrowedstar", "wpn_regicide", "wpn_lastword"]
	for id in sample:
		var d: Dictionary = Inventory.get_item_def(id)
		var g := Inventory.get_grade(id)
		var st: Dictionary = d.get("weapon_stats", {})
		var fx = d.get("special", {}).get("fx", null)
		var fx_txt := "PLAIN (honest rung)"
		if fx != null:
			var kinds := []
			for e in (fx if fx is Array else [fx]):
				kinds.append(str(e.get("kind", "?")) + str(e).replace('{ "kind": "' + str(e.get("kind", "")) + '"', "").substr(0, 0))
			fx_txt = JSON.stringify(fx)
		printerr("=== %s [%s] dmg %s cd %s" % [d.get("name", id), g,
			str(st.get("damage", "?")), str(st.get("cooldown", "?"))])
		printerr("    soul: %s" % fx_txt)
		printerr("    card: %s" % str(d.get("unique_desc", "(no line)")))
	get_tree().quit(0)
