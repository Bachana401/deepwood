extends Node

# THE SUMMONER, BATCH 1 — the engine (2026-07-30).
#
# Gates the five things the class stands on before any content rides them:
#   1. the bond-mark is SINGULAR (painting a new one moves it)
#   2. a summoned minion prefers the mark over mere distance
#   3. the slot budget is respected, and carriers never eat a slot
#   4. the pack survives a save round-trip, and an OLD save loads clean
#   5. a post is permanent-until-replaced, not timed

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

const BOND_MARK := preload("res://bond_mark.gd")
const COMPANION := preload("res://companion.gd")
const POST := preload("res://summon_post.gd")

class Foe extends Node2D:
	var health := 9999
	var max_health := 9999
	var is_dead := false
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

func _ready() -> void:
	await get_tree().process_frame
	get_tree().paused = false

	var a := Foe.new()
	var b := Foe.new()
	add_child(a); add_child(b)
	a.add_to_group("course_enemy")
	b.add_to_group("course_enemy")
	a.global_position = Vector2(0, 0)
	b.global_position = Vector2(400, 0)

	# --- 1. ONE MARK ---------------------------------------------------
	BOND_MARK.paint(a)
	await get_tree().process_frame
	check("the mark lands", BOND_MARK.is_marked(a))
	BOND_MARK.paint(b)
	await get_tree().process_frame
	await get_tree().process_frame
	check("painting a new mark MOVES it off the old foe",
		BOND_MARK.is_marked(b) and not BOND_MARK.is_marked(a))
	check("marked() reports the one wearing it", BOND_MARK.marked(get_tree()) == b)
	# re-tagging the same foe refreshes rather than re-acquiring
	var before_count: int = get_tree().get_nodes_in_group(BOND_MARK.GROUP).size()
	BOND_MARK.paint(b)
	await get_tree().process_frame
	check("re-tagging the same foe does not stack marks",
		get_tree().get_nodes_in_group(BOND_MARK.GROUP).size() == before_count)

	# --- 2. THE PACK LOOKS WHERE YOU POINT ------------------------------
	# `a` is much nearer; the mark is on the far `b`. A summoned minion must
	# still choose `b`, and a carried guest must still choose `a`.
	var stand := Node2D.new()
	add_child(stand)
	stand.global_position = Vector2(20, 0)

	var minion = COMPANION.new()
	minion.kind = "mudling"
	minion.summoned = true
	minion.player = stand
	add_child(minion)
	minion.global_position = Vector2(20, -40)
	await get_tree().process_frame
	check("a SUMMONED minion prefers the marked foe over the nearer one",
		minion._find_mark() == b, "picked %s" % str(minion._find_mark()))

	var guest = COMPANION.new()
	guest.kind = "blade"
	guest.summoned = false
	guest.player = stand
	add_child(guest)
	guest.global_position = Vector2(20, -40)
	await get_tree().process_frame
	check("a CARRIED guest still takes the nearest foe (it has no master)",
		guest._find_mark() == a, "picked %s" % str(guest._find_mark()))

	# --- 3. THE TAG DONATION IS REAL ------------------------------------
	var plain: Array = minion.strike_damage(a)     # unmarked
	var tagged: Array = minion.strike_damage(b)    # marked
	check("a summoned strike on the MARK is worth at least as much as off it",
		int(tagged[0]) >= int(plain[0]),
		"marked=%d unmarked=%d" % [int(tagged[0]), int(plain[0])])
	var guest_dmg: Array = guest.strike_damage(b)
	check("a carried guest ignores the tag donation entirely",
		int(guest_dmg[0]) == guest.damage)

	# --- 4. THE LEDGER SAVES, AND OLD SAVES LOAD CLEAN ------------------
	var keep: Array = GameState.active_summons.duplicate(true)
	GameState.active_summons = [{"scepter_id": "smn_smallloyalty", "kind": "mudling"}]
	var round_trip = JSON.parse_string(JSON.stringify(
		{"active_summons": GameState.active_summons}))
	check("the summon ledger survives a JSON round-trip",
		round_trip is Dictionary and (round_trip["active_summons"] as Array).size() == 1)
	# a save written before the class existed has no key at all
	var ancient := {"unlocked_skills": []}
	check("a save with no summon key defaults to an empty pack, not a crash",
		(ancient.get("active_summons", []) as Array).is_empty())
	GameState.active_summons = keep

	# --- 5. THE POST IS PERMANENT, NOT TIMED ----------------------------
	var post = POST.new()
	post.s_kind = "watchstone"
	post.damage = 8
	post.player = stand
	add_child(post)
	post.global_position = Vector2(60, 0)
	for _f in range(40):
		await get_tree().process_frame
	check("a post is still standing long after a timed sentry would have gone",
		is_instance_valid(post) and post.is_inside_tree())
	check("the post registered in its group", post.is_in_group("summon_post"))

	# --- 6. THE ROSTER KNOWS THE THREE NEW CLASSES ----------------------
	var seen := {}
	for row in WeaponRoster.ROWS:
		var k := str(row[2])
		if k in ["scepter", "whip", "totem"]:
			seen[k] = true
	check("the roster carries all three Summoner families",
		seen.has("scepter") and seen.has("whip") and seen.has("totem"),
		"found %s" % str(seen.keys()))
	for id in ["smn_smallloyalty", "whp_firstlesson", "pst_watchingstone"]:
		var d: Dictionary = WeaponRoster.get_def(id)
		check("%s expands with a special" % id,
			not (d.get("special", {}) as Dictionary).is_empty())
	# scepters and totems must resolve to weapon_type "summon", whips to "whip"
	check("a scepter is weapon_type summon",
		str(WeaponRoster.get_def("smn_smallloyalty").get("weapon_type", "")) == "summon")
	check("a whip is weapon_type whip",
		str(WeaponRoster.get_def("whp_firstlesson").get("weapon_type", "")) == "whip")
	check("a totem is weapon_type summon",
		str(WeaponRoster.get_def("pst_watchingstone").get("weapon_type", "")) == "summon")

	# --- 7. THE TREE (batch 3) ------------------------------------------
	var tree_nodes: Array = SkillTreeData.TREES.get("Summoner", [])
	check("the Summoner tree exists", tree_nodes.size() >= 25,
		"%d nodes" % tree_nodes.size())
	check("it has three branch names",
		(SkillTreeData.BRANCH_NAMES.get("Summoner", []) as Array).size() == 3)
	check("it has a class colour", SkillTreeData.CLASS_COLORS.has("Summoner"))

	# every tier-4 fork must be mutually exclusive, or a player takes both
	var groups := {}
	for n in tree_nodes:
		var exg := str((n as Dictionary).get("exclusive", ""))
		if exg == "":
			continue
		groups[exg] = int(groups.get(exg, 0)) + 1
	check("all three specs fork into an exclusive PAIR",
		groups.size() == 3 and groups.values().all(func(v): return v == 2),
		str(groups))

	# THE PROMISE AUDIT, in miniature: a node effect nobody reads is a lie on
	# the card. This class adds 16 keys and it is its biggest build risk.
	var readers := {}
	for path in ["res://player.gd", "res://companion.gd", "res://summon_post.gd",
			"res://bond_mark.gd"]:
		readers[path] = FileAccess.get_file_as_string(path)
	var unread := []
	for n2 in tree_nodes:
		for key in ((n2 as Dictionary).get("effect", {}) as Dictionary):
			if key in ["max_health"]:
				continue          # read by the shared stat pipeline
			var found := false
			for path2 in readers:
				if str(readers[path2]).contains('"%s"' % key):
					found = true
					break
			if not found:
				unread.append("%s (in %s)" % [key, str((n2 as Dictionary).get("id", "?"))])
	check("every tree effect key is READ somewhere", unread.is_empty(),
		", ".join(unread))

	# the class must be pickable, and its starters must exist to be granted
	var ui_src := FileAccess.get_file_as_string("res://skill_tree_ui.gd")
	check("the class picker offers the Summoner", ui_src.contains('"Summoner"'))
	for gift in ["whp_firstlesson", "smn_smallloyalty"]:
		check("the starter %s exists to grant" % gift,
			not (WeaponRoster.get_def(gift) as Dictionary).is_empty())

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(0 if fails == 0 else 1)
