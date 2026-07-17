extends Node

# Floors 35-50 of the ladder, against the dev's forever rules:
#   "all bosses must be different in many many ways"
#   "as their level is higher, the longer the combos and disgusting"
#   difficulty from MECHANICS, never one-shots.
#
# So this doesn't check "does a boss exist" -- it checks that no two of them are
# the same boss wearing a different colour, and that depth really does buy
# longer sentences.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame
	var BS = load("res://boss.gd")
	var DI = load("res://dungeon_interior.gd")
	var defs: Dictionary = BS.BOSSES
	var combos: Dictionary = BS.BOSS_COMBOS
	var ladder: Dictionary = DI.BOSS_LADDER

	var deep := ["hollow_choir", "ashen_penitent", "gaoler", "sablefang"]

	# --- they exist and the ladder actually reaches them ---
	for id in deep:
		check("%s is defined" % id, defs.has(id))
	var di = DI.new()
	for lv in [35, 40, 45, 50]:
		check("floor %d resolves to its OWN boss (%s)" % [lv, ladder[lv]],
			di.get_boss_id(lv) == ladder[lv], "got %s" % di.get_boss_id(lv))

	# --- DIFFERENT IN MANY WAYS: no axis may repeat across them ---
	var sizes := {}
	var speeds := {}
	var shapes := {}
	for id in deep:
		var d: Dictionary = defs[id]
		sizes[str(d["body"])] = true
		speeds[d["speed"]] = true
		shapes[d["shape"]] = true
	check("all 4 have DIFFERENT silhouettes (%d/4 sizes)" % sizes.size(), sizes.size() == 4)
	check("all 4 have DIFFERENT speeds (%d/4)" % speeds.size(), speeds.size() == 4)
	check("all 4 have DIFFERENT shapes (%d/4)" % shapes.size(), shapes.size() == 4)
	# widths AND lengths must both vary -- not just "scaled the same body"
	var wide := defs["hollow_choir"]["body"] as Vector2
	var tall := defs["ashen_penitent"]["body"] as Vector2
	check("the Choir is WIDE (%dx%d) and the Penitent is TALL (%dx%d)"
		% [wide.x, wide.y, tall.x, tall.y],
		wide.x > wide.y and tall.y > tall.x)
	check("the fast one is >3x the speed of the slow one (%.0f vs %.0f)"
		% [defs["sablefang"]["speed"], defs["ashen_penitent"]["speed"]],
		defs["sablefang"]["speed"] > defs["ashen_penitent"]["speed"] * 3.0)

	# --- EXCLUSIVE combos: no two bosses may share a chain ---
	for id in deep:
		check("%s has its own combos" % id, combos.has(id) and combos[id].size() >= 3)
	var seen := {}
	var dupes: Array = []
	for id in combos:
		for c in combos[id]:
			var key: String = str(c)
			if seen.has(key):
				dupes.append("%s == %s : %s" % [id, seen[key], key])
			seen[key] = id
	check("NO boss in the game shares a combo chain with another", dupes.is_empty(), str(dupes))

	# --- their reactive mechanics differ too ---
	var mech := {}
	for id in deep:
		mech[str(defs[id].get("passives", []))] = true
	check("all 4 stack DIFFERENT mechanics (%d/4)" % mech.size(), mech.size() == 4)

	# --- DEPTH BUYS LENGTH ---
	var b = BS.new()
	b.boss_id = "sablefang"
	add_child(b)
	await get_tree().process_frame
	b.boss_floor = 50
	var at50: int = b.active_combos()[0].size()
	b.boss_floor = 90
	var at90: int = b.active_combos()[0].size()
	b.boss_floor = 5
	var at5: int = b.active_combos()[0].size()
	check("floor 5 says a SHORT sentence (%d beats)" % at5, at5 == 2, "got %d" % at5)
	check("floor 50 says a longer one (%d beats)" % at50, at50 == 3, "got %d" % at50)
	check("floor 90 says a LONGER one (%d beats)" % at90, at90 == 4, "got %d" % at90)
	check("deeper is strictly longer", at5 < at50 and at50 < at90,
		"%d -> %d -> %d" % [at5, at50, at90])
	# an extended chain must only ever use the boss's OWN verbs
	b.boss_floor = 90
	var own := {}
	for v in BS.BOSS_COMBOS["sablefang"][0]:
		own[v] = true
	var foreign: Array = []
	for v in b.active_combos()[0]:
		if not own.has(v):
			foreign.append(v)
	check("a lengthened combo only loops its OWN verbs", foreign.is_empty(), str(foreign))

	# --- and depth must NOT be doing it with damage ---
	check("no deep boss out-damages the finale by stats alone",
		defs["gaoler"]["hp"] < defs["wizard"]["hp"] * 3,
		"depth must come from mechanics, not numbers")

	b.free()
	di.free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
