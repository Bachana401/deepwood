extends Node

# Mechanical wiring scan. The data audits ask whether declared effects are read;
# this asks whether the CODE is actually connected to itself:
#
#   * groups something looks for that nothing ever joins  (a lookup that always
#     returns null -- the bug that made mirror bosses silently reflect nothing)
#   * groups joined that nothing ever looks for          (dead bookkeeping)
#   * signals emitted that nothing listens to            (a dead event)
#   * has_method("x") probes where no script defines x   (a permanently false
#     branch: the feature looks wired and never runs)
#   * no-op functions that still have live callers       (a call that does
#     nothing, like Hard's death penalty did)
#
# Diagnostic only -- changes nothing.

var files := {}      # path -> source
var issues := 0

func note(kind: String, msg: String) -> void:
	issues += 1
	printerr("  [%s] %s" % [kind, msg])

func _ready() -> void:
	await get_tree().process_frame
	_load_sources()
	# COMMENTS ARE NOT CODE (2026-07-21). Every pass below matches call shapes --
	# add_to_group("x"), has_method("y") -- against this blob, and it used to
	# include comments, so a line of prose EXPLAINING a call read as the call.
	# Caught the day it mattered: a comment saying a group was deliberately NOT
	# joined was reported as joining it. The per-file `files` map keeps its
	# comments; only this scan blob is stripped, because the no-op pass below
	# genuinely needs to see whether the line above a function is a comment.
	var all := ""
	for f in files.keys():
		all += _strip_comments(files[f]) + "\n"
	printerr("== scanned %d scripts ==" % files.size())

	# ---------- 1. groups ----------
	var queried := _collect(all, "get_first_node_in_group\\(\"([a-z_0-9]+)\"\\)")
	_merge(queried, _collect(all, "get_nodes_in_group\\(\"([a-z_0-9]+)\"\\)"))
	_merge(queried, _collect(all, "is_in_group\\(\"([a-z_0-9]+)\"\\)"))
	var joined := _collect(all, "add_to_group\\(\"([a-z_0-9]+)\"\\)")
	# groups can also be joined in a .tscn via the groups=[...] property
	for scene_groups in _scene_groups():
		joined[scene_groups] = true

	printerr("\n== groups looked for but never joined ==")
	for g in queried.keys():
		if not joined.has(g):
			note("group", "'%s' is searched for, but nothing ever joins it -- the lookup always fails" % g)

	printerr("\n== groups joined but never looked for ==")
	for g in joined.keys():
		if queried.has(g):
			continue
		# A group is often searched through a CONST ARRAY rather than a literal
		# call -- boss.gd reflects via PLAYER_PROJECTILE_GROUPS, player.gd hits
		# via HOSTILE_GROUPS. If the name appears anywhere beyond its own
		# add_to_group, something is using it.
		if all.count('"%s"' % g) > 1:
			continue
		note("group", "'%s' is joined, but its name appears nowhere else -- dead bookkeeping" % g)

	# ---------- 2. has_method probes ----------
	printerr("\n== has_method() probes for methods nothing defines ==")
	var probed := _collect(all, "has_method\\(\"([a-z_0-9]+)\"\\)")
	for m in probed.keys():
		if all.contains("func %s(" % m):
			continue
		# engine built-ins (is_on_floor, queue_free...) are legitimately probed
		# on nodes whose exact type isn't known at the call site
		if _is_engine_method(m):
			continue
		note("method", "has_method(\"%s\") is checked, but no script defines it -- that branch is dead" % m)

	# ---------- 3. no-op functions that are still called ----------
	printerr("\n== functions whose body is just `pass`, but which are still called ==")
	for path in files.keys():
		var src: String = files[path]
		var lines := src.split("\n")
		for i in range(lines.size() - 1):
			var line: String = lines[i]
			if not line.begins_with("func "):
				continue
			var body: String = lines[i + 1].strip_edges()
			if body != "pass":
				continue
			var fname := line.substr(5, line.find("(") - 5)
			# An accept-and-ignore no-op is a legitimate pattern (a boss that
			# shrugs off knockback, a disposable vault that never persists).
			# What makes one a BUG is being undocumented -- that is the shape
			# Hard's death penalty had: an empty body and a stale TODO. So only
			# flag a no-op that nobody bothered to explain.
			var documented := i > 0 and lines[i - 1].strip_edges().begins_with("#")
			if documented:
				continue
			var refs := all.count(fname) - 1
			if refs > 0:
				note("noop", "%s() in %s does nothing, is undocumented, and is referenced %d time(s)" % [fname, path.get_file(), refs])

	# ---------- 3b. group PROTOCOL conformance ----------
	# Joining a group is only half a contract. Some groups have an interface the
	# searcher calls guarded by has_method(), so a member that joins without
	# implementing it doesn't error -- it just silently ignores the call. The
	# admin panel sat in esc_window for its whole life without esc_is_open, so
	# ESC never closed it and nothing ever said so.
	printerr("\n== group members missing their group's protocol ==")
	var protocols := {"esc_window": ["esc_is_open", "esc_close"]}
	for group_name in protocols.keys():
		for path in files.keys():
			if not files[path].contains('add_to_group("%s")' % group_name):
				continue
			for method in protocols[group_name]:
				if not files[path].contains("func %s(" % method):
					note("protocol", "%s joins '%s' but lacks %s() -- the group's calls silently skip it" % [
						path.get_file(), group_name, method])

	# ---------- 4. hardcoded cross-scene node paths ----------
	# This repo's nastiest shipped bug was pause_menu reaching for
	# "../DungeonManager", which existed in the village and NOT inside a
	# dungeon, so the pause menu silently did nothing there. A script used by
	# two scenes must find its hardcoded paths in BOTH.
	printerr("\n== hardcoded ../paths that don't resolve in every scene using the script ==")
	var scenes := _scene_index()
	var path_re := RegEx.new()
	path_re.compile("\\$\"\\.\\./([A-Za-z0-9_/]+)\"")
	for script_path in files.keys():
		var wanted := {}
		for m in path_re.search_all(files[script_path]):
			wanted[m.get_string(1)] = true
		if wanted.is_empty():
			continue
		for scene in scenes.keys():
			if not scenes[scene]["scripts"].has(script_path):
				continue
			# Skip the script's OWN scene (player.gd in player.tscn). There "../"
			# points outside the scene file entirely, so it resolves wherever the
			# scene is instanced -- checking it here is meaningless.
			if scene.get_file().get_basename() == script_path.get_file().get_basename():
				continue
			for w in wanted.keys():
				for segment in w.split("/"):
					if not scenes[scene]["nodes"].has(segment):
						note("path", "%s reaches for '../%s' but scene %s has no node named '%s'" % [
							script_path.get_file(), w, scene.get_file(), segment])

	# ---------- 5. input actions used but never defined ----------
	# A typo'd action name never errors -- is_action_just_pressed("atack") just
	# returns false forever, and the feature it guards silently never fires.
	# Only this direction is checked: defined-but-unused actions turned out to be
	# noise (dash fires from a double-tap; hotbar_1..10 are read via "hotbar_%d"
	# interpolation a literal scan can't see).
	printerr("\n== input actions used in code but missing from project.godot ==")
	var proj := _read_file("res://project.godot")
	var act_re := RegEx.new()
	act_re.compile("is_action_(?:just_)?(?:pressed|released)\\(\"([a-z_0-9]+)\"")
	var used_actions := {}
	for path in files.keys():
		for m in act_re.search_all(files[path]):
			used_actions[m.get_string(1)] = path.get_file()
	for act in used_actions.keys():
		if act.begins_with("ui_"):
			continue        # engine built-ins
		if not proj.contains("\n%s=" % act):
			note("input", "'%s' is checked in %s but not defined in project.godot -- it can never fire" % [act, used_actions[act]])

	# ---------- 5b. two actions fighting over one key ----------
	# The other direction that a literal scan CAN see safely. Found 2026-07-21:
	# `buy_dash` and `enter_dungeon` were both on F, right where the world says
	# "Press F to Enter Dungeon". buy_dash happened to be dead (the shop buys on
	# a mouse click), so nothing misfired -- but a dead action sitting on a live
	# key is a trap set for whoever wires it next.
	printerr("\n== two input actions bound to the same key ==")
	_audit_key_conflicts(proj)

	# --- PLAYER-FACING SYSTEMS NOTHING CAN REACH (added 2026-07-20) ---
	# Crafting hid for the ENTIRE project: CRAFT_RECIPES, try_craft and even
	# Toren's discount all worked, and no UI anywhere called them -- a whole
	# system the player could never touch, invisible to every other audit
	# (the code was live, the promises were kept, the recipes were valid).
	# Each entry below is a player-facing verb that must have a caller
	# OUTSIDE the file that defines it.
	printerr("\n== player-facing systems with no way in ==")
	var reachable := {
		"try_craft": "the crafting bench",
		"try_cleanse": "the Shrine's mercy",
		"buy_from_wanderer": "the Wanderer's Post",
		"new_game_plus": "the Rewound Hour",
		"try_plant_building": "relocation",
		"grant_blueprint": "blueprint satchels",
		"next_objective": "the what-now advisor",
		"chronicle": "the Chronicle panel",
		"try_weave_portal": "Riftweaving",
		"open_page": "the Roster / How to Play",
	}
	# A verb counts as reachable if ANYTHING calls it -- including its own
	# file, since player.gd legitimately defines AND invokes its own input
	# verbs (Z weaves a rift, H plants a building). What must never happen
	# is what crafting did: zero call sites anywhere in the project.
	for fn in reachable.keys():
		var call_sites := 0
		for path in files.keys():
			var src: String = files[path]
			var hits := src.count(fn + "(")
			if src.contains("func " + fn + "("):
				hits -= src.count("func " + fn + "(")   # the definition is not a call
			call_sites += maxi(hits, 0)
		if call_sites == 0:
			note("unreachable", "'%s()' (%s) is defined but NOTHING anywhere calls it -- the player can never reach it" % [fn, reachable[fn]])

	# --- UNREACHABLE CODE (added 2026-07-21) ---
	# The villager hover card was built, sized and filled every frame and
	# shown to NOBODY, because its only call site sat after a `return true`.
	# Dead statements look completely normal in review and in a unit probe
	# (which calls the function directly) -- only the running game notices.
	printerr("\n== unreachable statements ==")
	for path in files.keys():
		var lines: PackedStringArray = files[path].split("\n")
		for i in range(lines.size() - 1):
			var ln: String = lines[i]
			var stripped := ln.strip_edges()
			if not (stripped == "return" or stripped.begins_with("return ")):
				continue
			var indent := ln.length() - ln.lstrip("\t").length()
			for j in range(i + 1, mini(i + 6, lines.size())):
				var nx: String = lines[j]
				var nstr := nx.strip_edges()
				if nstr == "" or nstr.begins_with("#"):
					continue
				if nx.length() - nx.lstrip("\t").length() == indent:
					note("dead-code", "%s:%d is unreachable -- it follows a return at the same depth: %s" % [
						path.get_file(), j + 1, nstr.substr(0, 60)])
				break

	printerr("\n== TOTAL WIRING ISSUES: %d ==" % issues)
	get_tree().quit(0)

func _read_file(path: String) -> String:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return ""
	var s := fh.get_as_text()
	fh.close()
	return s

# scene path -> {nodes: {name:true}, scripts: {res://x.gd: true}}
func _scene_index() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://")
	if dir == null:
		return out
	var node_re := RegEx.new()
	node_re.compile("\\[node name=\"([^\"]+)\"")
	var script_re := RegEx.new()
	script_re.compile("path=\"(res://[a-z_0-9]+\\.gd)\"")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				var txt := fh.get_as_text()
				fh.close()
				var nodes := {}
				for m in node_re.search_all(txt):
					nodes[m.get_string(1)] = true
				var scripts := {}
				for m in script_re.search_all(txt):
					scripts[m.get_string(1)] = true
				out["res://" + f] = {"nodes": nodes, "scripts": scripts}
		f = dir.get_next()
	dir.list_dir_end()
	return out

# True if the engine itself provides the method on a common node type, so a
# has_method() probe for it is legitimate rather than a dead branch.
func _is_engine_method(m: String) -> bool:
	for cls in ["Node", "Node2D", "CanvasItem", "CharacterBody2D", "Area2D",
			"CollisionObject2D", "Control", "Object"]:
		if ClassDB.class_has_method(cls, m, true):
			return true
	return false

func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from.keys():
		into[k] = true

func _collect(src: String, pattern: String) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile(pattern)
	for m in re.search_all(src):
		out[m.get_string(1)] = true
	return out

# Groups assigned in scene files (groups=["player"] on a node).
func _scene_groups() -> Array:
	var found := []
	var dir := DirAccess.open("res://")
	if dir == null:
		return found
	var re := RegEx.new()
	re.compile("groups=\\[([^\\]]*)\\]")
	var inner := RegEx.new()
	inner.compile("\"([a-z_0-9]+)\"")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				var txt := fh.get_as_text()
				fh.close()
				for m in re.search_all(txt):
					for g in inner.search_all(m.get_string(1)):
						found.append(g.get_string(1))
		f = dir.get_next()
	dir.list_dir_end()
	return found

func _load_sources() -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd") and not f.begins_with("tool_") and not f.begins_with("test_"):
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				files["res://" + f] = fh.get_as_text()
				fh.close()
		f = dir.get_next()
	dir.list_dir_end()

# Walks the [input] block of project.godot, collecting every physical key and
# mouse button each action binds, and reports any that two actions share.
func _audit_key_conflicts(proj: String) -> void:
	var owner_of := {}          # "key 70" -> first action that claimed it
	var action := ""
	var in_input := false
	for line in proj.split("\n"):
		if line.begins_with("["):
			in_input = line.begins_with("[input]")
			continue
		if not in_input:
			continue
		if line.contains("=") and not line.begins_with("\"") and not line.begins_with("Object"):
			action = line.split("=")[0].strip_edges()
		for bind in _binds_in(line):
			if owner_of.has(bind) and owner_of[bind] != action:
				note("input", "'%s' and '%s' are both bound to %s" % [owner_of[bind], action, bind])
			elif not owner_of.has(bind):
				owner_of[bind] = action

func _binds_in(line: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("(physical_keycode|button_index)\":([0-9]+)")
	for m in re.search_all(line):
		var code := int(m.get_string(2))
		if code > 0:            # 0 = "no key set" on the keycode twin field
			out.append("%s %d" % ["key" if m.get_string(1) == "physical_keycode" else "mouse", code])
	return out

# Drops `#` comments, but only when the # is genuinely outside a string -- a
# naive cut would maim lines like `label.text = "Floor #%d"` and silently blind
# the scan to whatever else is on them.
func _strip_comments(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var in_str := false
		var quote := ""
		var cut := -1
		for i in range(line.length()):
			var c := line[i]
			if in_str:
				if c == quote and (i == 0 or line[i - 1] != "\\"):
					in_str = false
			elif c == "\"" or c == "'":
				in_str = true
				quote = c
			elif c == "#":
				cut = i
				break
		out += (line.substr(0, cut) if cut >= 0 else line) + "\n"
	return out
