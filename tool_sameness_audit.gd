extends Node

# THE SAMENESS AUDIT (2026-07-30).
#
# Dev: "I noticed almost identical 2 melee weapons: The Last Word and The
# Patient Knife, I am 100% sure there are many weapons like this."
#
# They were right, and the mechanism is findable. Both dispatch to the SAME tick
# function -- weapon_projectile.gd line ~821 reads
#     if kind == "patient_storm" or kind == "kingdom_ring": _tick_zenith_storm()
# so three Monarch weapons render as one orbiting storm with different names.
#
# Every other uniqueness audit in this repo checks the DECLARATION layer: does
# this weapon have its own behavior string, its own special type, its own fx
# kind. All three can differ while the code they reach is identical, and the
# player only ever sees the code. This audit follows the dispatch through to
# the function that actually draws and moves the thing, and groups weapons by
# what they REALLY do.
#
#   MONARCH_TEST="res://tool_sameness_audit.gd" Godot.exe --headless --path .

var fails := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	await get_tree().process_frame
	var src := FileAccess.get_file_as_string("res://weapon_projectile.gd")

	# ---- 1. map every projectile KIND to the tick function it reaches ----
	# two shapes are used in the file:
	#     if kind == "a" or kind == "b":
	#         _tick_x(delta)
	#     "a", "b":            (inside a match)
	#         _tick_x(delta)
	var kind_to_tick := {}
	var lines := src.split("\n")
	for i in range(lines.size()):
		var line := str(lines[i])
		if not (line.contains("kind ==") or line.strip_edges().begins_with("\"")):
			continue
		# collect every quoted kind on this line
		var kinds := []
		var kre := RegEx.new()
		kre.compile('"([a-z_0-9]+)"')
		for m in kre.search_all(line):
			kinds.append(m.get_string(1))
		if kinds.is_empty():
			continue
		# look ahead a few lines for the tick call this branch makes
		var tick := ""
		for j in range(i + 1, mini(i + 4, lines.size())):
			var tre := RegEx.new()
			tre.compile("(_tick_[a-z_0-9]+)\\(")
			var tm := tre.search(str(lines[j]))
			if tm != null:
				tick = tm.get_string(1)
				break
			if str(lines[j]).contains("kind ==") or str(lines[j]).strip_edges().begins_with("\""):
				break
		if tick == "":
			continue
		for k in kinds:
			kind_to_tick[str(k)] = tick

	# ---- 2. group the ROSTER by the tick each weapon actually reaches ----
	var by_engine := {}
	var no_engine := []
	for row in WeaponRoster.ROWS:
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		var sp: Dictionary = def.get("special", {})
		var stype := str(sp.get("type", ""))
		if stype == "":
			no_engine.append("%s (%s)" % [str(row[1]), str(row[4])])
			continue
		var engine: String = str(kind_to_tick.get(stype, "(inline: %s)" % stype))
		if not by_engine.has(engine):
			by_engine[engine] = []
		by_engine[engine].append("%s T%d" % [str(row[1]), int(row[3])])

	# ---- 3. report ----
	var shared := []
	for e in by_engine:
		if (by_engine[e] as Array).size() > 1:
			shared.append(e)
	shared.sort_custom(func(a, b):
		return (by_engine[a] as Array).size() > (by_engine[b] as Array).size())

	var total := 0
	var duped := 0
	for e2 in by_engine:
		total += (by_engine[e2] as Array).size()
		if (by_engine[e2] as Array).size() > 1:
			duped += (by_engine[e2] as Array).size()

	say("\n================ WEAPONS THAT SHARE AN ENGINE ================")
	say("Weapons with a special: %d   sharing an engine with another: %d (%d%%)"
		% [total, duped, int(round(100.0 * float(duped) / maxf(1.0, float(total))))])
	say("Weapons with NO special at all (plain rungs): %d" % no_engine.size())
	say("")
	for e3 in shared:
		var members: Array = by_engine[e3]
		say("  %-26s x%d" % [str(e3), members.size()])
		say("      " + ", ".join(members))

	say("\n== the worst offenders are the top of that list ==")
	printerr("RESULT: SAMENESS REPORT")
	get_tree().quit(0)
