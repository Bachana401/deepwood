extends Node

# THE WHOLE TREE, STRUCTURALLY (polish pass 2026-07-28): every class tree is
# checked as a GRAPH -- every prereq resolves inside the same tree, every
# effect key is READ by real code (the named-but-never-read trap, again),
# every exclusive fork is a well-formed pair, no two cards share a grid cell,
# costs are sane and every material is a real item. The Wukong roads and the
# rift/telepathy side-roads are part of the graph like everything else.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# every effect key any node grants, and the sources that may consume them
	var sources := ""
	for f in ["player.gd", "arrow.gd", "weapon_projectile.gd", "shade.gd",
			"enemy.gd", "game_state.gd", "boss.gd", "skill_tree_ui.gd",
			"main.gd", "dungeon_interior.gd"]:
		var fa := FileAccess.open("res://" + f, FileAccess.READ)
		if fa != null:
			sources += fa.get_as_text()

	for cls in SkillTreeData.TREES.keys():
		var tree: Array = SkillTreeData.TREES[cls]
		var ids := {}
		for n in tree:
			ids[str(n.id)] = true

		# ---- prereqs resolve INSIDE the class, and always point UP the tree ----
		var bad_pr := []
		for n in tree:
			var pr = n.get("prereq", "")
			var plist: Array = pr if pr is Array else ([pr] if str(pr) != "" else [])
			for pid in plist:
				if not ids.has(str(pid)):
					bad_pr.append("%s->%s" % [n.id, pid])
					continue
				var pnode = SkillTreeData.get_node_by_id(str(pid))
				if int(pnode.get("tier", 0)) >= int(n.get("tier", 0)):
					bad_pr.append("%s(t%d)->%s(t%d)" % [n.id, n.get("tier", 0), pid, pnode.get("tier", 0)])
		check("%s: every prereq resolves in-tree and points up" % cls,
			bad_pr.is_empty(), ", ".join(bad_pr))

		# ---- every effect key is consumed somewhere real ----
		var unread := []
		for n in tree:
			for key in n.get("effect", {}).keys():
				if not sources.contains('"%s"' % key):
					unread.append("%s.%s" % [n.id, key])
		check("%s: every effect key is READ by game code" % cls,
			unread.is_empty(), ", ".join(unread))

		# ---- exclusive forks: pairs, same tier, same prereq ----
		var groups := {}
		for n in tree:
			var g := str(n.get("exclusive", ""))
			if g == "":
				continue
			if not groups.has(g):
				groups[g] = []
			groups[g].append(n)
		var bad_forks := []
		for g in groups.keys():
			var members: Array = groups[g]
			if members.size() != 2:
				bad_forks.append("%s x%d" % [g, members.size()])
				continue
			if int(members[0].tier) != int(members[1].tier) \
					or str(members[0].prereq) != str(members[1].prereq):
				bad_forks.append("%s mismatched" % g)
		check("%s: every exclusive fork is a matched PAIR" % cls,
			bad_forks.is_empty(), ", ".join(bad_forks))

		# ---- the grid: no two cards share a (col, tier) cell ----
		var cells := {}
		var collisions := []
		for n in tree:
			var cell := "%s@%s" % [str(n.get("col", 0)), str(n.get("tier", 0))]
			if cells.has(cell):
				collisions.append("%s vs %s" % [n.id, cells[cell]])
			cells[cell] = str(n.id)
		check("%s: no two cards share a grid cell" % cls,
			collisions.is_empty(), ", ".join(collisions))

		# ---- costs and materials are sane and REAL ----
		var bad_cost := []
		for n in tree:
			if int(n.get("cost", 0)) <= 0:
				bad_cost.append(str(n.id))
			for mid in n.get("materials", {}).keys():
				if Inventory.get_item_def(str(mid)).is_empty():
					bad_cost.append("%s?%s" % [n.id, mid])
		check("%s: every cost is positive and every material is a real item" % cls,
			bad_cost.is_empty(), ", ".join(bad_cost))

		# ---- reachability: every node can trace a prereq chain to the root ----
		var reachable := {}
		var frontier := []
		for n in tree:
			if str(n.get("prereq", "")) == "" and not (n.get("prereq", "") is Array):
				reachable[str(n.id)] = true
				frontier.append(str(n.id))
		var grew := true
		while grew:
			grew = false
			for n in tree:
				if reachable.has(str(n.id)):
					continue
				var pr2 = n.get("prereq", "")
				var plist2: Array = pr2 if pr2 is Array else [pr2]
				for pid in plist2:
					if reachable.has(str(pid)):
						reachable[str(n.id)] = true
						grew = true
						break
		var stranded := []
		for n in tree:
			if not reachable.has(str(n.id)):
				stranded.append(str(n.id))
		check("%s: every node is reachable from the root" % cls,
			stranded.is_empty(), ", ".join(stranded))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
