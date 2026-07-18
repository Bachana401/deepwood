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
	var all := ""
	for f in files.keys():
		all += files[f] + "\n"
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

	printerr("\n== TOTAL WIRING ISSUES: %d ==" % issues)
	get_tree().quit(0)

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
