extends Node

# THE FOREVER RULE: "in this game all bosses must be different in many many ways."
#
# The bug this pins: get_boss_id() used a modulo over a 6-boss roster, so each
# cycling boss was fought THREE times across the 100 floors -- Gravewarden on 5,
# again on 35, again on 65. 12 of the 22 boss fights were reruns.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame
	var DI = load("res://dungeon_interior.gd")
	var BS = load("res://boss.gd")
	var di = DI.new()
	var ladder: Dictionary = DI.BOSS_LADDER
	var defs: Dictionary = BS.BOSSES

	# --- every boss floor is named, and named uniquely ---
	var floors: Array = []
	for lv in range(5, 101, 5):
		floors.append(lv)
	for lv in [95, 98, 99, 100]:
		if not floors.has(lv):
			floors.append(lv)
	floors.sort()
	check("every boss floor has a ladder entry (%d floors)" % floors.size(),
		floors.all(func(lv): return ladder.has(lv)),
		"missing: %s" % str(floors.filter(func(lv): return not ladder.has(lv))))

	var named: Array = []
	for lv in floors:
		named.append(ladder.get(lv, ""))
	var uniq := {}
	for n in named:
		uniq[n] = true
	check("THE LADDER NAMES %d DIFFERENT BOSSES FOR %d FLOORS (no reruns)"
		% [uniq.size(), floors.size()],
		uniq.size() == floors.size(),
		"repeats: %s" % str(named))

	# --- the modulo is gone ---
	check("CYCLING_BOSSES is gone", not ("CYCLING_BOSSES" in DI))

	# --- nothing bricks: every floor resolves to a boss that really exists ---
	var unresolved: Array = []
	for lv in floors:
		var id: String = di.get_boss_id(lv)
		if not defs.has(id):
			unresolved.append("%d->%s" % [lv, id])
	check("every floor resolves to a REAL boss (no bricked floors)",
		unresolved.is_empty(), str(unresolved))

	# --- how much of the ladder is actually built yet? (honest progress) ---
	var built: Array = []
	var todo: Array = []
	for lv in floors:
		if defs.has(ladder[lv]):
			built.append(lv)
		else:
			todo.append("%d:%s" % [lv, ladder[lv]])
	printerr("      ladder built: %d/%d floors. still to build: %s"
		% [built.size(), floors.size(), str(todo)])

	# --- the finale gauntlet keeps its reserved bosses ---
	check("95 = Seraphiel", di.get_boss_id(95) == "seraph", di.get_boss_id(95))
	check("100 = The Fallen Wizard", di.get_boss_id(100) == "wizard", di.get_boss_id(100))

	# --- the specific rerun the dev noticed ---
	check("floor 5 and floor 35 are NOT the same boss",
		ladder.get(5, "a") != ladder.get(35, "a"),
		"%s vs %s" % [ladder.get(5, "?"), ladder.get(35, "?")])
	check("floor 5 / 35 / 65 are three different bosses",
		ladder.get(5, "a") != ladder.get(65, "b") and ladder.get(35, "c") != ladder.get(65, "b"))

	di.free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
