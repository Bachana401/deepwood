extends Node

# Regression guards for the two HIGH bugs found in the 2026-07-25 bug sweep:
#  1) building.gd looked up UI nodes with "../CanvasLayer/..." but buildings sit
#     under Main/Village, so the real path is "../../CanvasLayer/...". The bad
#     path left the Blacksmith forge (the only shop) unopenable and silently
#     dropped the Hospital/School/Marketplace hands-on feedback.
#  2) boss.gd run_ability (the ONLY dispatch path for combo bosses) had no case
#     for slam/barrage/charge/dive, so combo bosses that list those in
#     BOSS_COMBOS silently dropped them to no-ops (e.g. the Gaoler only cast
#     iron_maiden).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var bld := FileAccess.open("res://building.gd", FileAccess.READ).get_as_text()
	# the broken single-"../" lookup (with the get_node_or_null call attached, so
	# the correct "../../CanvasLayer/" does not false-match as a substring)
	check("building UI lookups use the real CanvasLayer path (forge opens; feedback shows)",
		not bld.contains('get_node_or_null("../CanvasLayer/'),
		"a building-context ../CanvasLayer/ lookup still resolves to null")
	check("...and the working two-dot path is present",
		bld.contains('get_node_or_null("../../CanvasLayer/ShopUI"'))

	var boss := FileAccess.open("res://boss.gd", FileAccess.READ).get_as_text()
	check("combo bosses can fire slam and barrage",
		boss.contains('"slam": await do_slam()') and boss.contains('"barrage": await do_barrage()'))
	check("combo bosses can fire charge and dive (waited to completion)",
		boss.contains('"charge": await _combo_charge()') and boss.contains('"dive": await _combo_dive()')
		and boss.contains("func _combo_charge()") and boss.contains("func _combo_dive()"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
