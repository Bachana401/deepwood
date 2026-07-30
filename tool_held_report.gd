extends Node
# HELD-WEAPON SIZE CENSUS (2026-07-29). The dev has called weapon sizes wrong
# three times; the first two fixes were to PROJECTILES. Nothing had ever
# measured the sprite actually held in the hand, so this does.
#
# player.gd: blade_len = max(icon_size.x, HELD_MIN_LEN) * HELD_LEN_MULT
#            scale     = blade_len / (tex.width * HELD_BLADE_FRAC)
#            sprite is centred at blade_len*0.5 along the aim
# so the on-screen span is tex.width * scale = blade_len / HELD_BLADE_FRAC,
# and the TIP reaches blade_len*0.5 + span*0.5 from the player's centre.
#
#   MONARCH_TEST="res://tool_held_report.gd" Godot.exe --headless --path .

const PLAYER_H := 48.0
const HELD_BLADE_FRAC := 0.80
const HELD_LEN_MULT := 0.75
const HELD_MIN_LEN := 30.0

func say(t: String) -> void: printerr(t)

func _ready() -> void:
	await get_tree().process_frame
	var by_class := {}
	var worst := []
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if not d.has("weapon_stats"):
			continue
		var st: Dictionary = d["weapon_stats"]
		if not st.has("icon_size"):
			continue
		var wtype := str(d.get("weapon_type", "melee"))
		if wtype == "bow":
			continue      # bows are sized by HEIGHT, a separate path
		var icon: Vector2 = st["icon_size"]
		var blade: float = maxf(icon.x, HELD_MIN_LEN) * HELD_LEN_MULT
		var span: float = blade / HELD_BLADE_FRAC
		var reach: float = blade * 0.5 + span * 0.5
		var pl: float = reach / PLAYER_H
		if not by_class.has(wtype):
			by_class[wtype] = []
		by_class[wtype].append(pl)
		worst.append({"id": id, "name": str(d.get("name", id)), "type": wtype,
			"icon_x": icon.x, "span": span, "reach": reach, "pl": pl})

	say("=== HELD WEAPON SIZE (player height = %d px = 1.0 PL) ===" % int(PLAYER_H))
	var keys := by_class.keys()
	keys.sort()
	for k in keys:
		var arr: Array = by_class[k]
		arr.sort()
		say("  %-8s n=%3d   min %4.1f PL   median %4.1f PL   max %4.1f PL"
			% [k, arr.size(), arr[0], arr[arr.size() / 2], arr[arr.size() - 1]])

	worst.sort_custom(func(a, b): return a["pl"] > b["pl"])
	say("")
	say("  LONGEST 18 (tip distance from the player's centre):")
	for i in range(mini(18, worst.size())):
		var w = worst[i]
		say("    %-26s %-6s icon.x=%3d  span=%5.1f  tip=%5.1f px = %4.1f PL"
			% [w["name"].substr(0, 26), w["type"], int(w["icon_x"]),
				w["span"], w["reach"], w["pl"]])
	say("RESULT: census done")
	get_tree().quit(0)
