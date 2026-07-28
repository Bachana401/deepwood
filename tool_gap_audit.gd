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

	# ---- 4b. every villager quest must have a spawnable giver AND target ----
	# Bram and Sena had full quest defs -- dialogue, rewards, the game's only
	# reunite bond -- and neither spawned anywhere: two dead quests nobody could
	# ever see. A quest def id must be a hand-placed main.tscn villager or an
	# IMPORTANT_FIGURES dungeon rescue, and a reunite target must be spawnable
	# too, or the chain is broken at the far end instead.
	printerr("\n== villager quests whose giver or target can never spawn ==")
	var spawnable := {}
	for lv in VillagerQuests.IMPORTANT_FIGURES.keys():
		spawnable[str(VillagerQuests.IMPORTANT_FIGURES[lv].get("villager_id", ""))] = true
	var scene := FileAccess.open("res://main.tscn", FileAccess.READ)
	if scene != null:
		var re_v := RegEx.new()
		re_v.compile("villager_id = \"([a-z_0-9]+)\"")
		for m in re_v.search_all(scene.get_as_text()):
			spawnable[m.get_string(1)] = true
		scene.close()
	for qid in VillagerQuests.QUEST_DEFS.keys():
		if not spawnable.has(qid):
			note("quest", "'%s' has a quest def but no spawn anywhere -- the quest can never activate" % qid)
		var qdef: Dictionary = VillagerQuests.QUEST_DEFS[qid]
		if str(qdef.get("kind", "")) == "reunite":
			var target := str(qdef.get("key", ""))
			if not spawnable.has(target):
				note("quest", "reunite quest '%s' targets '%s', who can never be rescued" % [qid, target])

	# ---- 4c. every role must be FILLABLE and every recipe CRAFTABLE ----
	# A role whose required_stat nothing can ever grant is a permanently empty
	# slot in the assign UI; a recipe with an unobtainable ingredient is a
	# button that can never be pressed. Stat sources: the School's random roll
	# (REGULAR_STATS), the Barracks ("Warrior"), VIP rescues (IMPORTANT_FIGURES
	# stat_names) and hand-seeded starting villagers.
	printerr("\n== roles nothing can staff / recipes nothing can craft ==")
	var stat_sources := {}
	for s in GameState.REGULAR_STATS:
		stat_sources[s] = true
	stat_sources["Warrior"] = true
	for lv in VillagerQuests.IMPORTANT_FIGURES.keys():
		stat_sources[str(VillagerQuests.IMPORTANT_FIGURES[lv].get("stat_name", ""))] = true
	var roles_src := FileAccess.open("res://building_roles.gd", FileAccess.READ)
	if roles_src != null:
		var rtxt := roles_src.get_as_text()
		roles_src.close()
		var rre := RegEx.new()
		rre.compile("\"required_stat\": \"([A-Za-z ]+)\"")
		var seen := {}
		for m in rre.search_all(rtxt):
			var stat := m.get_string(1)
			if seen.has(stat):
				continue
			seen[stat] = true
			if not stat_sources.has(stat):
				note("role", "roles require stat '%s', which nothing can ever grant" % stat)
	var grant_src := _load_grant_sources()
	for recipe_id in Inventory.CRAFT_RECIPES.keys():
		for ing in Inventory.CRAFT_RECIPES[recipe_id].keys():
			if not grant_src.contains('"%s"' % ing):
				note("recipe", "'%s' needs '%s', which nothing grants -- the recipe is dead" % [recipe_id, ing])

	# ---- 5. can the player actually OBTAIN each item? ----
	# An item nothing grants is invisible content: it exists, it is balanced, it
	# shows up in the catalogue, and no player will ever hold one. Loot pools are
	# plain id lists (GEAR_EXCELLENT_IDS and friends), so an id that appears
	# nowhere outside inventory.gd is unreachable in real play.
	printerr("\n== items nothing can grant (unreachable in normal play) ==")
	var src := _load_grant_sources()
	var unreachable := {}
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if str(d.get("name", "")).contains("Admin"):
			continue
		# a CRAFTABLE item IS reachable -- the crafting UI lists every recipe.
		# (grant sources skip inventory.gd, where CRAFT_RECIPES lives, so without
		# this a craft-only item read as "nothing grants" -- a blind spot that
		# false-flagged the event-boss re-summon tokens. 2026-07-28)
		if Inventory.CRAFT_RECIPES.has(id):
			continue
		if not src.contains('"%s"' % id):
			var cat := str(d.get("category", "misc"))
			if not unreachable.has(cat):
				unreachable[cat] = []
			unreachable[cat].append(id)
	for cat in unreachable.keys():
		var list: Array = unreachable[cat]
		note("loot", "%d %s items nothing grants: %s" % [list.size(), cat,
			", ".join(list.slice(0, 8)) + ("  ..." if list.size() > 8 else "")])

	_audit_phantom_item_ids()

	printerr("\n== TOTAL GAPS: %d ==" % issues)
	get_tree().quit(0)

# ---- PHANTOM ITEM IDS ----
# Every audit here asks "is this DEFINED item wired up?". None asked the
# reverse: is every string the code USES as an item id actually defined?
# Inventory.add_item takes any string at all -- a typo'd id becomes a slot in
# the player's bag that has no name, no icon and no use, and it saves and
# reloads faithfully forever. Nothing in the game would ever tell you. This
# pass reads the source and flags item ids that no definition backs.
const ID_TAKING_CALLS := ["add_item", "remove_item", "get_count", "has_item",
	"get_display_name", "get_item_def", "equip_item", "wield_weapon", "use_item"]

func _audit_phantom_item_ids() -> void:
	printerr("\n== item ids the code uses that nothing defines ==")
	var re := RegEx.new()
	re.compile("\\b(%s)\\(\\s*\"([a-z0-9_]+)\"" % "|".join(ID_TAKING_CALLS))
	var dir := DirAccess.open("res://")
	if dir == null:
		return
	var seen := {}
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd") and not f.begins_with("tool_") \
				and not f.begins_with("test_") and not f.begins_with("probe_"):
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				var line_no := 0
				for line in fh.get_as_text().split("\n"):
					line_no += 1
					for m in re.search_all(line):
						var id: String = m.get_string(2)
						if not Inventory.ITEM_DEFS.has(id) and not seen.has(id):
							seen[id] = true
							note("item-id", "%s:%d calls %s(\"%s\") -- no such item" % [
								f, line_no, m.get_string(1), id])
				fh.close()
		f = dir.get_next()
	dir.list_dir_end()

# Every game script EXCEPT the item definitions themselves -- so an id only
# counts as reachable if something other than its own declaration names it.
func _load_grant_sources() -> String:
	var out := ""
	var dir := DirAccess.open("res://")
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd") and not f.begins_with("tool_") and not f.begins_with("test_") \
				and f != "inventory.gd":
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				out += fh.get_as_text()
				fh.close()
		f = dir.get_next()
	dir.list_dir_end()
	return out
