extends Node

# Structural gap scan across the game's DATA (items, sets, skill trees).
# Complements tool_promise_audit (which checks declared effects are read) by
# asking the opposite question: what is MISSING that ought to be there?
#
# Diagnostic only -- changes nothing.

var issues := 0

func note(section: String, msg: String) -> void:
	issues += 1
	printerr("  [%s] %s" % [section, msg])

func _ready() -> void:
	await get_tree().process_frame

	# ---- 1. high-grade weapons with no signature of any kind ----
	printerr("== high-grade weapons with nothing special about them ==")
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if d.get("category", "") != "weapon":
			continue
		var g: String = Inventory.ITEM_GRADES.get(id, "")
		var rank: int = int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 0))
		if rank < 4:
			continue     # epic and up should feel authored
		# rare+ melee weapons receive a swing slash by DERIVATION now, so having
		# no authored swing_slash key no longer means having no signature
		var derived_slash: bool = d.get("weapon_type", "") == "melee" and rank >= 3
		var has_signature: bool = d.has("special") or d.has("unique_effect") \
			or d.has("passive") or derived_slash
		if not has_signature:
			note("weapon", "%s [%s] has no special/unique/passive -- it is just numbers" % [id, g])

	# ---- 2. equipment sets: completeness and a signature weapon ----
	printerr("\n== equipment sets ==")
	var sets := {}
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		var s := str(d.get("set", ""))
		if s == "":
			continue
		if not sets.has(s):
			sets[s] = {"armor": [], "weapon": []}
		if d.get("category", "") == "weapon":
			sets[s]["weapon"].append(id)
		else:
			sets[s]["armor"].append(id)
	for s in sets.keys():
		var w: Array = sets[s]["weapon"]
		var a: Array = sets[s]["armor"]
		printerr("  %-13s %d armour, %d weapon(s)" % [s, a.size(), w.size()])
		for wid in w:
			var wd: Dictionary = Inventory.ITEM_DEFS[wid]
			if not (wd.has("special") or wd.has("unique_effect") or not wd.get("swing_slash", {}).is_empty()):
				note("set", "%s's weapon '%s' has no signature while its set-mates do" % [s, wid])

	# ---- 3. skill trees: dead nodes and broken links ----
	printerr("\n== skill trees ==")
	for cls in SkillTreeData.TREES.keys():
		# The Shadow Monarch tree is a deliberate post-game teaser: every node is
		# "???" with no effect until the game is finished. Flagging it as empty
		# would bury the real findings under four permanent false alarms.
		if cls == "Shadow Monarch":
			continue
		var ids := {}
		for node in SkillTreeData.TREES[cls]:
			ids[node.get("id", "")] = true
		for node in SkillTreeData.TREES[cls]:
			var nid := str(node.get("id", "?"))
			var nname := str(node.get("name", "?"))
			# a node that grants nothing and costs points is a dead pick
			if node.get("effect", {}).is_empty() and int(node.get("cost", 0)) > 0:
				note("skill", "%s/%s costs %d points and grants NOTHING" % [cls, nname, int(node.get("cost", 0))])
			# prereqs must exist, or the node is unreachable
			var pre = node.get("prereq", "")
			var pre_list: Array = pre if pre is Array else ([pre] if str(pre) != "" else [])
			for pid in pre_list:
				if not ids.has(str(pid)):
					note("skill", "%s/%s requires '%s', which does not exist in that tree" % [cls, nname, pid])
			# a materials cost the player can never research is unpayable
			for mat in node.get("materials", {}).keys():
				if not Inventory.ITEM_DEFS.has(mat):
					note("skill", "%s/%s costs material '%s', which is not an item" % [cls, nname, mat])

	# ---- 4. consumables / relics that describe themselves but do nothing ----
	printerr("\n== items whose text has no backing ==")
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		var cat := str(d.get("category", ""))
		# admin/test tools are hardcoded by hand in player.gd (cast_wand's
		# screen wipe) rather than declared as data, and are not shipping items
		if str(d.get("name", "")).contains("Admin"):
			continue
		if cat == "consumable" and d.get("use_effect", {}).is_empty():
			note("item", "consumable '%s' has no use_effect -- using it does nothing" % id)
		if cat == "relic" and d.get("equip_effect", {}).is_empty() and not d.has("relic_power"):
			note("item", "relic '%s' grants no stats and has no power" % id)
		# NOTE: a unique_desc is NOT automatically a promise of a bespoke effect.
		# Most low-grade weapons use it to describe their derived feel ("a slow,
		# devastating blow", "the fastest strikes around"), which the size/speed
		# derivation genuinely delivers. Flagging all of them buried the two real
		# findings under twenty false alarms, so only text that names a MECHANIC
		# the engine would have to implement is worth reporting.
		var desc := str(d.get("unique_desc", "")).to_lower()
		if desc != "" and not (d.has("unique_effect") or d.has("special") \
				or d.has("passive") or not d.get("swing_slash", {}).is_empty()):
			for promise in ["chance to", "on hit", "every ", "heals", "steal", "explode",
					"chain", "pierce", "summon", "revive", "stun", "freeze", "burn", "poison"]:
				if desc.contains(promise):
					note("item", "'%s' text promises '%s' but nothing implements it" % [id, promise])
					break

	printerr("\n== TOTAL GAPS: %d ==" % issues)
	get_tree().quit(0)
