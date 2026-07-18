extends Node

# Scans every PROMISE the data makes -- skill effect keys, armour/relic
# equip_effects, grade passives, consumable use_effects, weapon unique_effects,
# relic powers and weapon special types -- and checks whether any game code
# actually READS it.
#
# This exists because the recurring failure in this project is a passive that is
# NAMED but never read: the tooltip promises something, the player builds around
# it, and nothing in the code ever consumes the key. The Shadowblade shipped for
# months promising "a shadow-slash on every strike" with unique_effect radiance
# at value 0.0. That class of bug is invisible in play (the weapon still works,
# it just quietly does less than it says) so only a scan like this finds it.
#
# Diagnostic only -- changes nothing.

var source := ""

func _ready() -> void:
	await get_tree().process_frame
	source = _load_game_source()
	printerr("== scanned %d KB of game source ==" % (source.length() / 1024))

	var missing := {}      # promise -> where it was declared

	# --- 1. skill tree effect keys ---
	for cls in SkillTreeData.TREES.keys():
		for node in SkillTreeData.TREES[cls]:
			for key in node.get("effect", {}).keys():
				if not _is_read(key):
					_flag(missing, key, "skill '%s' (%s)" % [node.get("name", "?"), cls])

	# --- 2. item equip effects (armour + relics) and consumable use effects ---
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		for key in d.get("equip_effect", {}).keys():
			if not _is_read(key):
				_flag(missing, key, "equip_effect on '%s'" % id)
		for key in d.get("use_effect", {}).keys():
			if not _is_read(key):
				_flag(missing, key, "use_effect on '%s'" % id)
		for key in d.get("passive", {}).keys():
			if not _is_read(key):
				_flag(missing, key, "passive on '%s'" % id)
		# a weapon's signature behaviour
		var ue := str(d.get("unique_effect", ""))
		if ue != "" and not _is_read(ue):
			_flag(missing, ue, "unique_effect on '%s'" % id)
		var rp := str(d.get("relic_power", ""))
		if rp != "" and not _is_read(rp):
			_flag(missing, rp, "relic_power on '%s'" % id)
		var sp: Dictionary = d.get("special", {})
		var st := str(sp.get("type", ""))
		# A special's TYPE may just be a label: bows in particular are driven
		# generically off count/spread_deg/homing without the dispatcher ever
		# matching the name. Such a special is honoured even though its type
		# string appears nowhere, so only flag one that is BOTH unmatched and
		# carries no field the engine consumes on its own.
		if st != "" and not _is_read(st) and not _special_is_generic(sp):
			_flag(missing, st, "special.type on '%s'" % id)

	# --- 3. grade passives ---
	for g in Inventory.GRADE_PASSIVES.keys():
		for key in Inventory.GRADE_PASSIVES[g].keys():
			if not _is_read(key):
				_flag(missing, key, "GRADE_PASSIVES[%s]" % g)

	printerr("\n== PROMISES NOTHING READS ==")
	if missing.is_empty():
		printerr("  (none -- every declared effect is consumed somewhere)")
	else:
		var keys := missing.keys()
		keys.sort()
		for k in keys:
			var where: Array = missing[k]
			printerr("  %-24s  declared by %d: %s" % [k, where.size(),
				", ".join(where.slice(0, 3)) + ("  ..." if where.size() > 3 else "")])
	printerr("  total distinct: %d" % missing.size())

	# --- 4. the inverse: effects with a value of zero (named but neutered) ---
	printerr("\n== DECLARED BUT ZEROED (reads fine, does nothing) ==")
	var zeroed := 0
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		for src in ["equip_effect", "passive"]:
			for key in d.get(src, {}).keys():
				if typeof(d[src][key]) in [TYPE_INT, TYPE_FLOAT] and float(d[src][key]) == 0.0:
					printerr("  %s.%s = 0 on '%s'" % [src, key, id])
					zeroed += 1
		if d.has("unique_effect") and d.has("unique_value") \
				and typeof(d["unique_value"]) in [TYPE_INT, TYPE_FLOAT] \
				and float(d["unique_value"]) == 0.0:
			printerr("  unique_effect '%s' has unique_value 0 on '%s'" % [d["unique_effect"], id])
			zeroed += 1
	printerr("  total: %d" % zeroed)
	get_tree().quit(0)

# Fields the attack code acts on without ever looking at special.type.
const GENERIC_SPECIAL_KEYS = ["count", "spread_deg", "homing", "pierce", "aoe", "status"]

func _special_is_generic(sp: Dictionary) -> bool:
	for k in GENERIC_SPECIAL_KEYS:
		if sp.has(k):
			return true
	return false

func _flag(bag: Dictionary, key: String, where: String) -> void:
	if not bag.has(key):
		bag[key] = []
	bag[key].append(where)

# A promise counts as READ if its name appears as a string literal anywhere in
# the game's own source (get_bonus_total("x"), a match arm, has_relic_power(...)).
# Deliberately generous: the goal is to catch names NOTHING mentions, without
# drowning the report in false alarms.
func _is_read(key: String) -> bool:
	return source.contains('"%s"' % key)

func _load_game_source() -> String:
	var out := ""
	var dir := DirAccess.open("res://")
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		# skip the data files themselves and the QC scripts -- we want to know
		# what the GAME reads, not that the declaration exists
		if f.ends_with(".gd") and not f.begins_with("tool_") and not f.begins_with("test_") \
				and f != "inventory.gd" and f != "skill_tree.gd":
			var fh := FileAccess.open("res://" + f, FileAccess.READ)
			if fh != null:
				out += fh.get_as_text()
				fh.close()
		f = dir.get_next()
	dir.list_dir_end()
	return out
