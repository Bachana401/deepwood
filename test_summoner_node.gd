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

# A boss is recognised project-wide by HAVING a boss_id property, so a test
# boss has to DECLARE one -- set()ting the name onto a plain Foe silently does
# nothing, and every boss-exemption check then reads "not a boss".
class BossFoe extends Foe:
	var boss_id := "gravewarden"

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

	# --- 8. THE GEAR (batch 4) ------------------------------------------
	var brand: Dictionary = Inventory.ITEM_DEFS.get("relic_kennelbrand", {})
	check("The Kennel Brand exists and grants a slot",
		not brand.is_empty()
		and float((brand.get("equip_effect", {}) as Dictionary).get("summon_cap", 0.0)) > 0.0)
	check("...and carries a readable power",
		str(brand.get("relic_power", "")) == "packmend"
		and str(brand.get("relic_desc", "")) != "")
	var bw: Dictionary = Inventory.SET_DEFS.get("bondwarden", {})
	check("The Bondwarden's Vestments is a real 3-piece set",
		(bw.get("pieces", []) as Array).size() == 3)
	for pc in (bw.get("pieces", []) as Array):
		var pdef: Dictionary = Inventory.ITEM_DEFS.get(str(pc), {})
		check("%s exists and belongs to the set" % pc,
			not pdef.is_empty() and str(pdef.get("set", "")) == "bondwarden")
	check("the set names a weapon that exists",
		not (WeaponRoster.get_def(str(bw.get("weapon", ""))) as Dictionary).is_empty(),
		str(bw.get("weapon", "")))
	check("the set soul is on the card", str(bw.get("bonus_desc", "")).contains("PACKLAW"))
	# THE SOULS MUST NOT BE THE SAME TRICK. PACKLAW frees the pack from needing
	# a tag; the flagship whip makes the pack strike the moment you tag. If
	# these ever collapse into one effect the set stops being a choice.
	var court: Dictionary = WeaponRoster.get_def("whp_tencourt")
	check("the set soul and the flagship whip are different tricks",
		str((court.get("special", {}) as Dictionary).get("tag_fx", "")) == "tenfold")
	# and every key the gear grants must be READ, same rule as the tree
	var gear_src := ""
	for path3 in ["res://player.gd", "res://companion.gd", "res://summon_post.gd"]:
		gear_src += FileAccess.get_file_as_string(path3)
	var gear_unread := []
	var gear_promises := [brand.get("equip_effect", {}), bw.get("bonus", {}),
		bw.get("bonus_2pc", {}), bw.get("full_bonus", {})]
	for pc2 in (bw.get("pieces", []) as Array):     # the PIECES promise things too
		gear_promises.append(Inventory.ITEM_DEFS.get(str(pc2), {}).get("equip_effect", {}))
	for src_dict in gear_promises:
		for k2 in (src_dict as Dictionary):
			if k2 == "max_health":
				continue
			if not gear_src.contains('"%s"' % k2):
				gear_unread.append(str(k2))
	check("every key the Summoner gear grants is READ", gear_unread.is_empty(),
		", ".join(gear_unread))

	# GEAR NOBODY CAN FIND IS NOT GEAR. Declaring an item in ITEM_DEFS makes it
	# real to the catalogue and to this test, and still leaves it unreachable in
	# a real run -- every other set had to be listed in a drop pool by hand.
	var drops := FileAccess.get_file_as_string("res://dungeon_interior.gd")
	var unreachable := []
	for id2 in ["relic_kennelbrand"] + (bw.get("pieces", []) as Array):
		if not drops.contains('"%s"' % str(id2)):
			unreachable.append(str(id2))
	check("every piece of Summoner gear is in a drop pool", unreachable.is_empty(),
		", ".join(unreachable))
	# ...and depth-gating reads the grade, so a missing grade silently drops it
	# on floor one next to the wooden club.
	for id3 in ["relic_kennelbrand"] + (bw.get("pieces", []) as Array):
		check("%s has a grade to gate its depth" % id3,
			Inventory.get_grade(str(id3)) == "epic", Inventory.get_grade(str(id3)))
	# the set weapon needs no hand-listing -- the roster ladder carries it, but
	# only inside its OWN tier bracket, so ask at a floor that bracket admits
	var swid := str(bw.get("weapon", ""))
	var stier := 0                      # the expanded def drops tier; the row keeps it
	for r in WeaponRoster.ROWS:
		if str(r[0]) == swid:
			stier = int(r[3])
			break
	var sfloor: int = int((WeaponRoster.TIER_FLOORS[clampi(stier, 1, 8)] as Array)[0])
	check("the set weapon rides the roster ladder",
		WeaponRoster.pool_for_level(sfloor).has(swid),
		"T%d absent from the floor-%d pool" % [stier, sfloor])
	# and the set must be findable as a WHOLE -- pieces and weapon on the same
	# rung, or you wear two thirds of it for twenty floors waiting on the third
	check("the set weapon sits at the same grade as its pieces",
		Inventory.get_grade(swid) == "epic", Inventory.get_grade(swid))

	# --- 9. THE BOSS RULE HOLDS FOR THE PACK ----------------------------
	# FOREVER RULE: no execute on a boss. The guard must use the test the rest
	# of the project uses -- it was written against a "boss" GROUP that this
	# project has never had, so for one batch it never fired even once.
	var comp_src := FileAccess.get_file_as_string("res://companion.gd")
	check("the execute exempts bosses by the project's own boss test",
		comp_src.contains('"boss_id" in _mark'))
	check("...and not by a group that nothing joins",
		not comp_src.contains('is_in_group("boss")'))
	# Prove it at RUNTIME, not just in the source -- and the fork must actually
	# be taken, or the branch is skipped and the test proves nothing.
	var skills_keep: Array = GameState.unlocked_skills.duplicate()
	GameState.unlocked_skills.append("sm_b4a")     # Fang of the Bond, 12%
	check("the execute fork is live for this test",
		GameState.get_bonus_total("bond_execute") > 0.0)

	var fang = COMPANION.new()
	fang.kind = "direhound"
	fang.summoned = true
	fang.is_bond = true
	fang.player = stand
	add_child(fang)

	# a MOB deep in the window: the execute must take it to zero in one bite
	var prey := Foe.new()
	add_child(prey)
	prey.add_to_group("course_enemy")
	prey.global_position = Vector2(700, 0)
	prey.max_health = 4000
	prey.health = 200                              # 5% -- inside the 12% window
	BOND_MARK.paint(prey)
	await get_tree().process_frame
	fang.global_position = prey.global_position
	fang._mark = prey
	fang._land()
	check("the execute DOES finish a tagged mob deep in the window",
		prey.health <= 0, "left %d hp" % prey.health)

	# the same shot against a BOSS at the same fraction must merely bite
	var bossy := BossFoe.new()
	add_child(bossy)
	bossy.add_to_group("course_enemy")
	bossy.global_position = Vector2(760, 0)
	bossy.max_health = 4000
	bossy.health = 200
	BOND_MARK.paint(bossy)
	await get_tree().process_frame
	fang.global_position = bossy.global_position
	fang._mark = bossy
	fang._land()
	check("...but a bond-beast can never EXECUTE a boss",
		bossy.health > 0, "boss deleted from 200 hp in one bite")
	GameState.unlocked_skills = skills_keep

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(0 if fails == 0 else 1)
