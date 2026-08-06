extends Node
# THE REGISTRY GUARD (QA, 2026-08-06) -- the one test whose whole job is to stop
# the suite from lying about its own size.
#
# all_test_files.txt is a STATIC registry. A test file that exists on disk but is
# not listed in it never runs, and the suite still prints ALL PASS. That has cost
# this project twice already: one commit silently dropped eight registrations, and
# a test written a week later was never registered at all. Both were found by
# accident, which is the same as not being found.
#
# This test diffs the registry against the disk in BOTH directions and fails loud:
#   * a file on disk that nothing runs  -> dead coverage, the dangerous one
#   * a name in the registry with no file -> the runner burns a Godot launch on a
#     missing script, the menu idles, and the run looks like a six-minute TIMEOUT
#     rather than a missing test (main_menu.gd guards on ResourceLoader.exists,
#     so a bad name attaches NOTHING and reports nothing).
# It also pins the shape every test must have, so an empty stub cannot sit in a
# registered slot pretending to be coverage.
#
# SCRATCH TESTS: a throwaway probe must be named test_zz*.gd. That prefix is the
# only thing this guard ignores, and it sorts to the end of a directory listing
# so it is visible. Anything else named test_*.gd is coverage and must be listed.

const REGISTRY_PATH := "res://all_test_files.txt"
const SCRATCH_PREFIX := "test_zz"

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

# Every test_*.gd sitting at the project root. Deliberately NON-recursive: the
# dev's parallel sessions keep sibling git worktrees under .claude/worktrees/,
# and a recursive walk would scoop up another department's tests as "unregistered".
func tests_on_disk() -> Array:
	var found: Array = []
	var d: DirAccess = DirAccess.open("res://")
	if d == null:
		return found
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		if not d.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
			found.append(f.substr(0, f.length() - 3))
		f = d.get_next()
	d.list_dir_end()
	found.sort()
	return found

func _ready() -> void:
	var p: Node = null
	for i in range(600):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return

	# ---- read the registry exactly the way a runner would ----
	var fa: FileAccess = FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	check("the registry is readable at all", fa != null, REGISTRY_PATH)
	if fa == null:
		printerr("test_registry : RESULT: ", "%d FAILURES" % maxi(fails, 1))
		get_tree().quit(1)
		return
	var raw_lines: PackedStringArray = fa.get_as_text().split("\n")
	fa.close()

	var listed: Array = []
	var dupes: Array = []
	var malformed: Array = []
	for raw in raw_lines:
		var name: String = str(raw).strip_edges()
		if name == "":
			continue
		# a stray path, extension or comment in here silently becomes a test name
		# the runner cannot resolve -- catch it as garbage, not as a missing file
		if name.ends_with(".gd") or name.contains("/") or name.begins_with("#"):
			malformed.append(name)
			continue
		if name in listed:
			dupes.append(name)
		else:
			listed.append(name)

	check("the registry holds only bare test names (no paths, no .gd, no comments)",
		malformed.is_empty(), str(malformed))
	check("no test is registered twice (a dupe doubles the suite's runtime for nothing)",
		dupes.is_empty(), str(dupes))
	check("the registry is not empty", listed.size() > 0, "%d entries" % listed.size())

	# ---- BOTH directions against the disk ----
	var on_disk: Array = tests_on_disk()
	check("the project root actually has test scripts in it", on_disk.size() > 0)

	var unregistered: Array = []
	for f in on_disk:
		if str(f).begins_with(SCRATCH_PREFIX):
			continue
		if not (f in listed):
			unregistered.append(f)
	check("every test on disk is REGISTERED — an unlisted test never runs and the suite still says ALL PASS",
		unregistered.is_empty(),
		"unlisted: %s  (add these to all_test_files.txt, or rename scratch probes to %s*)"
			% [str(unregistered), SCRATCH_PREFIX])

	var missing: Array = []
	for n in listed:
		if not (n in on_disk):
			missing.append(n)
	check("every registered test EXISTS on disk — a dead name makes the run look like a timeout, not a gap",
		missing.is_empty(), "no such file: %s" % str(missing))

	# a scratch probe must never be smuggled into the registry: it is untracked, so
	# it exists on the machine that wrote it and nowhere else, and the suite would
	# go red for everyone but its author.
	var scratch_listed: Array = []
	for n2 in listed:
		if str(n2).begins_with(SCRATCH_PREFIX):
			scratch_listed.append(n2)
	check("no scratch probe is registered (it exists on one machine only)",
		scratch_listed.is_empty(), str(scratch_listed))

	# ---- keep it sorted: a sorted registry is how drift gets spotted by eye ----
	var sorted_copy: Array = listed.duplicate()
	sorted_copy.sort()
	var first_out_of_order := ""
	for i2 in range(listed.size()):
		if listed[i2] != sorted_copy[i2]:
			first_out_of_order = "%s should be %s (line %d)" % [listed[i2], sorted_copy[i2], i2 + 1]
			break
	check("the registry is alphabetical (append and it sorts wrong — insert in place)",
		first_out_of_order == "", first_out_of_order)

	# ---- a registered slot must hold a REAL test, not a stub ----
	# Every driver in this suite is a Node with a _ready() that ends in
	# get_tree().quit(<code>). Anything missing one of those either never reports or
	# never exits, and an entry that never exits is a six-minute timeout per run.
	var shapeless: Array = []
	for n3 in listed:
		if not (n3 in on_disk):
			continue      # already reported as missing above
		var src_file: FileAccess = FileAccess.open("res://%s.gd" % n3, FileAccess.READ)
		if src_file == null:
			shapeless.append("%s (unreadable)" % n3)
			continue
		var src: String = src_file.get_as_text()
		src_file.close()
		if not src.contains("extends Node"):
			shapeless.append("%s (not a Node)" % n3)
		elif not src.contains("func _ready("):
			shapeless.append("%s (no _ready)" % n3)
		elif not src.contains("get_tree().quit("):
			shapeless.append("%s (never exits — this is a timeout, not a pass)" % n3)
	check("every registered test is a real driver (Node + _ready + quit)",
		shapeless.is_empty(), str(shapeless))

	printerr("test_registry : %d registered, %d on disk" % [listed.size(), on_disk.size()])
	printerr("test_registry : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
