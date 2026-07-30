extends Node

# THE DEAD-VERB AUDIT (2026-07-30).
#
# Four weapons have now shipped that did nothing at all, each by the same
# mechanism: the roster row names a BEHAVIOR, and _special_for() has no case
# label for it, so the weapon falls through with an empty special dict. For a
# wand that is fatal -- _expand hardcodes wand swing damage to 0, so the weapon
# deals literally zero.
#
#   souls        (T8 Monarch wand)  -- a crown weapon casting nothing
#   storm_debt   (T4 Epic wand)     -- borrowed a visual, never wired
#   ink          (T4 Epic wand)     -- ink_jet fully built, never named
#   wake         (T6 Mythic wand)   -- wake_scythe fully built, never named
#
# No existing audit could see it. The fx audit checks that behaviors are
# DISTINCT, not that they RESOLVE. The dispatch audit only inspects weapons that
# declare a special -- a weapon with an empty special is skipped as "plain", so
# the ones that are broken are precisely the ones it ignores. The dps audit
# multiplies a damage number by a declared factor and never asks whether the
# damage reaches anything.
#
# This closes the hole at the source: every behavior a row declares must either
# resolve to a special, or be on the short list of behaviors that are plain BY
# DESIGN. There is no third category, and "I forgot to write the case" cannot
# hide in it.
#
#   MONARCH_TEST="res://tool_deadverb_audit.gd" Godot.exe --headless --path .

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

# Behaviors that legitimately produce no special. These are the material-ladder
# rungs: an ordinary swing or shot, no verb, by deliberate design.
const PLAIN_BY_DESIGN := ["arc", "thrust", "shot", "rapid"]

# Types routed by a DEDICATED METHOD rather than by a named branch, so the
# string never appears next to the dispatch. Each is verified by a live test
# elsewhere, which is why a name-scan missing them is a false positive and not
# a finding -- listing them here keeps this audit quiet enough to be believed.
const HANDLED_BY_METHOD := {
	"minion": "player.cast_summon() -- covered by test_summoner_node",
	"whipcrack": "player.whip_crack() -- covered by test_summoner_node",
	"post": "player.plant_post() -- covered by test_summoner_node",
	"multi_shot": "player.spawn_arrow() fans it -- covered by test_dispatch_node",
	"homing": "a FLAG on an ordinary arrow, not a kind -- see arrow.homing",
}

func _ready() -> void:
	await get_tree().process_frame

	var dead := []
	var zero_dmg := []
	var seen := {}
	for row in WeaponRoster.ROWS:
		var id := str(row[0])
		var behavior := str(row[4])
		var def: Dictionary = WeaponRoster.get_def(id)
		var sp: Dictionary = def.get("special", {})
		if not sp.is_empty():
			continue
		if behavior in PLAIN_BY_DESIGN:
			continue
		# a behavior that is neither plain-by-design nor resolving is a typo or
		# a case someone forgot to write
		if not seen.has(behavior):
			seen[behavior] = true
			dead.append("%s -> behavior '%s' has no case in _special_for"
				% [str(row[1]), behavior])
		# and for a WAND it is not merely featureless, it is inert: swing damage
		# is hardcoded to 0 for the class, so nothing is left to deal
		if str(row[2]) == "wand" or str(row[2]) == "staff":
			zero_dmg.append("%s (T%d %s)" % [str(row[1]), int(row[3]), str(row[2])])

	check("every declared behavior resolves to a special (or is plain by design)",
		dead.is_empty(), "\n        " + "\n        ".join(dead))
	# stated separately because this is the one that reaches the player as a
	# weapon that visibly does nothing when swung
	check("no wand or staff ships with an empty special (they deal 0 by class)",
		zero_dmg.is_empty(), ", ".join(zero_dmg))

	# the reverse hole: a case label nobody uses is dead code that will rot
	var roster_src := FileAccess.get_file_as_string("res://weapon_roster.gd")
	var used := {}
	for row2 in WeaponRoster.ROWS:
		used[str(row2[4])] = true
	var orphan_cases := []
	var in_special := false
	for line in roster_src.split("\n"):
		var t := str(line).strip_edges()
		if t.begins_with("static func _special_for"):
			in_special = true
			continue
		if in_special and t.begins_with("static func ") and not t.contains("_special_for"):
			break
		if not in_special or not t.ends_with(":"):
			continue
		var cre := RegEx.new()
		cre.compile('^"([a-z_0-9]+)"(,\\s*"[a-z_0-9]+")*:$')
		if cre.search(t) == null:
			continue
		var kre := RegEx.new()
		kre.compile('"([a-z_0-9]+)"')
		for m in kre.search_all(t):
			var key := m.get_string(1)
			if not used.has(key):
				orphan_cases.append(key)
	check("every case label in _special_for is reached by some weapon",
		orphan_cases.is_empty(), ", ".join(orphan_cases))

	# --- THE SECOND GATE, which is where all four dead weapons actually died ---
	# Writing the case in _special_for is only half the wiring. player.gd holds a
	# hand-maintained ALLOW-LIST of wand special types --
	#     elif special_type == "flood_wave" or special_type == "glass_note" ...
	# -- and a type missing from it is built, given a name, given damage, and
	# then never launched. That is the real mechanism behind souls, storm_debt,
	# ink and wake: each had a case, and none had a launch. Nothing connected the
	# two lists, so the omission was invisible from either side.
	var player_src := FileAccess.get_file_as_string("res://player.gd")
	var proj_src := FileAccess.get_file_as_string("res://weapon_projectile.gd")
	var unlaunched := []
	var checked_types := {}
	for row3 in WeaponRoster.ROWS:
		var d3: Dictionary = WeaponRoster.get_def(str(row3[0]))
		var st := str((d3.get("special", {}) as Dictionary).get("type", ""))
		if st == "" or checked_types.has(st):
			continue
		checked_types[st] = true
		# it must be named SOMEWHERE that can act on it: the player's cast
		# chain, or the projectile's own kind dispatch
		if player_src.contains('"%s"' % st) or proj_src.contains('"%s"' % st):
			continue
		if HANDLED_BY_METHOD.has(st):
			continue
		unlaunched.append("%s (from %s)" % [st, str(row3[1])])
	check("every special type is named somewhere that can act on it",
		unlaunched.is_empty(), "\n        " + "\n        ".join(unlaunched))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
