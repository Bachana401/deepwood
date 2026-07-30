extends Node

# THE ADMIN WARP (2026-07-30, dev: "teleport to any dungeon level of my choice,
# so I can test weapons on different bosses").
#
# A dev tool still has to work. The failure mode that matters here is silent:
# warp to floor 90, get bounced back to your deepest earned floor, and conclude
# the weapon is fine when you never fought the boss you meant to fight.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

const PANEL := preload("res://admin_panel.gd")
const DUNGEON := preload("res://dungeon_interior.gd")

# A stand-in for dungeon_interior: the panel finds the boss ladder by asking its
# PARENT, so the test needs a parent that answers. Delegates to the real script's
# statics-by-instance so the ladder under test is the shipping one.
class FakeDungeon extends Node:
	const MAX_LEVEL = 100
	var _d = null
	func is_boss_level(level: int) -> bool:
		return level % 5 == 0 or level >= MAX_LEVEL - 2
	func get_boss_id(level: int) -> String:
		var ladder: Dictionary = load("res://dungeon_interior.gd").BOSS_LADDER
		var best := "gravewarden"
		var best_lv := -1
		for lv in ladder:
			if int(lv) <= level and int(lv) > best_lv:
				best_lv = int(lv)
				best = str(ladder[lv])
		return best

func _ready() -> void:
	await get_tree().process_frame
	get_tree().paused = false

	var host := FakeDungeon.new()
	add_child(host)
	var panel = PANEL.new()
	host.add_child(panel)
	await get_tree().process_frame

	# --- 1. the stepper stays inside the dungeon -------------------------
	panel._warp_level = 1
	panel._warp_step(-10)
	check("stepping below floor 1 clamps, it does not go negative",
		panel._warp_level == 1, "got %d" % panel._warp_level)
	panel._warp_level = 98
	panel._warp_step(10)
	check("stepping past the last floor clamps to MAX_LEVEL",
		panel._warp_level == 100, "got %d" % panel._warp_level)
	check("the cap is read from the LIVE constant, not a copy",
		panel._max_level() == DUNGEON.MAX_LEVEL,
		"panel says %d, dungeon says %d" % [panel._max_level(), DUNGEON.MAX_LEVEL])

	# --- 2. BOSS > always lands on a floor that HAS one ------------------
	panel._warp_level = 1
	var seen := []
	for i in range(24):
		panel._warp_next_boss()
		seen.append(panel._warp_level)
		check("BOSS > lands on an actual boss floor (%d)" % panel._warp_level,
			panel._boss_on(panel._warp_level) != "",
			"floor %d has no boss" % panel._warp_level)
	check("BOSS > wraps around rather than sticking at the bottom",
		seen.has(5) and seen[seen.size() - 1] < 100 or seen.count(seen[0]) > 1,
		str(seen))

	# --- 3. the boss NAMES are real ---------------------------------------
	var ladder: Dictionary = DUNGEON.BOSS_LADDER
	var bosses: Dictionary = load("res://boss_defs.gd").BOSSES if \
		ResourceLoader.exists("res://boss_defs.gd") else {}
	panel._warp_level = 5
	check("floor 5 reports the Gravewarden", panel._boss_on(5) == "gravewarden",
		panel._boss_on(5))
	panel._warp_level = 50
	check("floor 50 reports Sablefang", panel._boss_on(50) == "sablefang",
		panel._boss_on(50))
	check("a NON-boss floor reports no boss", panel._boss_on(47) == "", panel._boss_on(47))

	# --- 4. THE SILENT FAILURE --------------------------------------------
	# Warping to a floor you have not unlocked bounces you back to your deepest
	# earned one. If _warp_go forgets to raise highest_unlocked_level, the button
	# looks like it worked and quietly drops you somewhere else entirely.
	var src := FileAccess.get_file_as_string("res://admin_panel.gd")
	var go_at := src.find("func _warp_go")
	var go_body := src.substr(go_at, 700)
	check("_warp_go unlocks the target floor before travelling",
		go_body.contains("highest_unlocked_level"))
	check("_warp_go leaves proving-grounds mode, or you land in the test arena",
		go_body.contains("proving_grounds = false"))
	check("_warp_go sets an exit anchor, or you return under the village floor",
		go_body.contains("pre_dungeon_position"))
	check("_warp_go actually sets the level it advertises",
		go_body.contains("active_dungeon_level = _warp_level"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
