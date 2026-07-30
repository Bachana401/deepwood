extends Node

# Item-table integrity (WEAPONS.md batches): every weapon must have a grade and
# valid weapon_stats, every graded id must resolve to a real def, and the new
# grade-fill weapons must actually be present and loadable. Cheap guard that
# stops a typo (a weapon with no grade → grey fallback, or a bad stat block →
# crash on wield) from shipping.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame
	var defs = Inventory.ITEM_DEFS
	var grades = Inventory.ITEM_GRADES

	# every weapon has a grade + a usable weapon_stats block
	var no_grade: Array = []
	var bad_stats: Array = []
	var weapon_count := 0
	for id in defs.keys():
		var d = defs[id]
		if d.get("category", "") != "weapon":
			continue
		weapon_count += 1
		if not grades.has(id):
			no_grade.append(id)
		var ws = d.get("weapon_stats", {})
		if not (ws.has("damage") and ws.has("cooldown") and ws.has("area_size")):
			bad_stats.append(id)
	check("every weapon has a grade", no_grade.is_empty(), "missing: %s" % ", ".join(no_grade))
	check("every weapon has a valid weapon_stats block", bad_stats.is_empty(), "bad: %s" % ", ".join(bad_stats))

	# every graded id resolves to a real item def
	var orphan_grades: Array = []
	for id in grades.keys():
		if not defs.has(id):
			orphan_grades.append(id)
	check("no grade points at a missing item", orphan_grades.is_empty(), ", ".join(orphan_grades))

	# the grade-fill weapons are present, graded, and loadable
	var new_weapons = ["wpn_shortsword","wpn_rapier","wpn_cleaver","wpn_hatchet","wpn_woodspear",
		"wpn_slingshot","wpn_huntingbow","wpn_sparkwand","wpn_falchion","wpn_warpick","wpn_twinblades",
		"wpn_saber","wpn_trident","wpn_warglaive","wpn_crossbow","wpn_flatbow","wpn_frostwand","wpn_channelwand"]
	var missing: Array = []
	for id in new_weapons:
		var d = Inventory.get_item_def(id)
		if d.is_empty() or not grades.has(id) or not d.get("weapon_stats", {}).has("damage"):
			missing.append(id)
	check("all 18 grade-fill weapons load with a grade + stats", missing.is_empty(), ", ".join(missing))

	# the +15% pass landed (sword 8 -> 9)
	# Every item must be OBTAINABLE. 21 weapons and a relic once existed, fully
	# balanced and listed in the catalogue, that no drop pool could ever hand
	# you -- the class-weapon pool started at rare, so nothing granted a common
	# or uncommon weapon at all. Invisible content is the quietest kind of gap.
	var DI = load("res://dungeon_interior.gd")
	var grantable := {}
	for pool in [DI.GEAR_EARLY_WEAPON_IDS, DI.GEAR_RELIC_IDS, DI.GEAR_ARMOR_IDS,
			DI.GEAR_SET_WEAPON_IDS, DI.GEAR_CLASS_WEAPON_IDS, DI.GEAR_EXCELLENT_IDS]:
		for id in pool:
			grantable[id] = true
	# the generated ladder drops through pool_for_level -- every roster id is
	# reachable at its tier's floors by construction, and the roster's own
	# reachability check below proves the brackets leave no floor gap
	for id in WeaponRoster.all_ids():
		grantable[id] = true
	# no floor 1-100 may fall outside EVERY tier bracket (a bracket gap would
	# silently mute roster drops on those floors)
	var gapless := true
	for lv in range(1, 101):
		if WeaponRoster.pool_for_level(lv).is_empty():
			gapless = false
	check("the roster's tier brackets cover every floor", gapless)
	# NOTE: drop pools are not the only way to get gear -- leather armour is
	# starting kit, Heart of the Mountain and the Sylvan Charm are harvesting
	# finds, and the basic sword/spear/bow are the smithy's base kit. So the bar
	# here is narrow and exact: the grades that ONLY the dungeon hands out.
	# tool_gap_audit.gd checks whole-game reachability across every grant path.
	# the four base-kit weapons are handed over at the start, and the gathering
	# tools are deliberate Forge purchases -- neither is meant to drop
	var not_loot := {"wpn_sword": true, "wpn_spear": true, "wpn_bow": true, "wpn_wand": true,
		"tool_axe": true, "tool_pickaxe": true,
		"wpn_soulsplit": true,   # grandmother's GIFT (Ada's bond, 12.2) -- never loot
		# the rod ladder is FISHED out of the water (pillar 3), never dropped
		"tool_rod_willow": true, "tool_rod_wyrmbone": true, "tool_rod_moonline": true}
	var orphans := []
	for id in defs.keys():
		var d: Dictionary = defs[id]
		if d.get("category", "") != "weapon" or str(d.get("name", "")).contains("Admin"):
			continue
		if Inventory.ITEM_GRADES.get(id, "") not in ["common", "uncommon"]:
			continue
		if not_loot.has(id):
			continue
		if not grantable.has(id):
			orphans.append(id)
	check("every common/uncommon weapon can actually drop", orphans.is_empty(),
		"%d unreachable: %s" % [orphans.size(), ", ".join(orphans.slice(0, 6))])
	check("Gorgon's Gaze is in the relic pool (it was in none)",
		"relic_gorgon" in DI.GEAR_RELIC_IDS)
	# and each grade band should actually be represented in the early game
	var early_grades := {}
	for id in DI.GEAR_EARLY_WEAPON_IDS:
		early_grades[Inventory.ITEM_GRADES.get(id, "?")] = true
	check("the early rack covers common AND uncommon",
		early_grades.has("common") and early_grades.has("uncommon"), str(early_grades.keys()))

	var sword_dmg = int(defs["wpn_sword"]["weapon_stats"]["damage"])
	check("+15% pass applied (Sword base 8 -> 9)", sword_dmg == 9, "got %d" % sword_dmg)

	# the grades are no longer bottom-starved
	var cnt := {}
	for id in grades.keys():
		var g = grades[id]
		cnt[g] = cnt.get(g, 0) + 1
	check("common grade is no longer starved (>= 14)", cnt.get("common", 0) >= 14, "common=%d" % cnt.get("common", 0))
	check("uncommon grade filled out (>= 22)", cnt.get("uncommon", 0) >= 22, "uncommon=%d" % cnt.get("uncommon", 0))
	printerr("weapons=%d  grades: common=%d uncommon=%d rare=%d epic=%d legendary=%d mythic=%d" % [
		weapon_count, cnt.get("common",0), cnt.get("uncommon",0), cnt.get("rare",0),
		cnt.get("epic",0), cnt.get("legendary",0), cnt.get("mythic",0)])

	# ---- chest QoL (dev request): bulk moves + shift-click ----
	var a := Inventory.new(6)
	var b := Inventory.new(2)
	a.add_item("wood", 30)
	a.add_item("stone", 20)
	a.add_item("potion_health", 5)
	var stacks := []
	for s in a.slots:
		if s != null:
			stacks.append({"id": str(s.item_id), "count": int(s.count)})
	var moved := 0
	for s2 in stacks:
		moved += a.transfer_to(b, s2.id, s2.count)
	check("bulk transfer moves what FITS and leaves the rest honestly",
		moved > 0 and b.get_count("wood") == 30 and a.get_count("potion_health") == 5,
		"moved=%d" % moved)
	var csrc := FileAccess.open("res://chest_ui.gd", FileAccess.READ).get_as_text()
	check("the chest offers Take All / Deposit All / Match on their own row",
		csrc.contains("_on_take_all") and csrc.contains("_on_deposit_all")
		and csrc.contains("_on_deposit_matching") and csrc.contains("restock its stores"))
	check("Deposit All never strands the weapon in your hand",
		csrc.contains("active_weapon_id"))
	check("shift-click flicks stacks BOTH directions",
		csrc.contains("KEY_SHIFT")
		and FileAccess.open("res://inventory_ui.gd", FileAccess.READ).get_as_text().contains("KEY_SHIFT"))

	# THE POTIONS RULE (5.5): potions only from pre-boss floors + boss caches
	var esrc := FileAccess.open("res://enemy.gd", FileAccess.READ).get_as_text()
	check("ordinary floors drop NO potions (positions 4-5 of a block only)",
		esrc.contains("% 5 + 1 >= 4") and not esrc.contains("if randf() < 0.05:\n\t\tplayer.inventory.add_item(\"potion_health\""))
	check("a felled boss always restocks the belt",
		FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text().contains("The boss's cache"))

	# ---- GATHERING: a tree is four swings, a seam is a DEPOSIT ----
	var hsrc := FileAccess.open("res://harvest_node.gd", FileAccess.READ).get_as_text()
	check("a rock holds 5x a tree's reserve (dev: stone was WAY too much at 20x)",
		hsrc.contains("ROCK_RESERVE_MULT = 5")
		and hsrc.contains("ROCK_RESERVE = HITS_TO_HARVEST * ROCK_RESERVE_MULT"))
	check("every pickaxe swing PAYS, it doesn't wait for the end",
		hsrc.contains("func _mine_swing") and hsrc.contains('_drop("stone"'))
	check("materials POP OUT onto the ground (Terraria-style), not into the bag",
		hsrc.contains("MATERIAL_PICKUP") and hsrc.contains("func _drop"))
	check("the seam SHRINKS as it empties -- the size is the gauge",
		hsrc.contains("func _apply_reserve_scale") and hsrc.contains("ROCK_MIN_SCALE"))
	check("...and only vanishes when the reserve is worked out",
		hsrc.contains("func _exhaust_seam") and hsrc.contains("reserve_left <= 0"))
	check("a regrown seam returns to its own size",
		hsrc.contains("visual_root.scale = Vector2(size_mult, size_mult)"))
	check("trees still fall in HITS_TO_HARVEST swings",
		hsrc.contains("hits_left -= 1") and hsrc.contains("if hits_left <= 0:"))

	# ---- polish 2026-07-28: racks, retired slots, depth-gated grades, peaks ----
	var dsrc := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the proving racks include the generated ladder",
		dsrc.contains("WeaponRoster.all_ids():") and dsrc.contains("silently showed only a fifth"))
	var retired_leak := false
	for aid in DI.GEAR_ARMOR_IDS:
		if str(Inventory.ITEM_DEFS.get(aid, {}).get("slot", "")) in GameState.RETIRED_SLOTS:
			retired_leak = true
	check("retired gloves/boots left the armor drop pool", not retired_leak)
	check("armor/relic drops respect their grade's floor (lower bound)",
		dsrc.contains("func _gear_in_depth") and dsrc.contains("_gear_in_depth(GEAR_ARMOR_IDS)"))
	check("the Forge no longer sells retired-slot pieces",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains("RETIRED_SLOTS"))
	for sid in ["voidwalker", "regalia"]:
		var sd: Dictionary = Inventory.SET_DEFS.get(sid, {})
		var peak_ok: bool = not sd.is_empty() and sd.get("pieces", []).size() == 3
		for pid in sd.get("pieces", []):
			peak_ok = peak_ok and Inventory.ITEM_DEFS.has(pid) and Inventory.ITEM_GRADES.has(pid)
		peak_ok = peak_ok and Inventory.get_item_def(str(sd.get("weapon", ""))).has("weapon_stats")
		check("peak set '%s' stands complete (3 graded pieces + a real weapon)" % sid, peak_ok)
	var badw := []
	for sid2 in Inventory.SET_DEFS.keys():
		var w := str(Inventory.SET_DEFS[sid2].get("weapon", ""))
		if w != "" and Inventory.get_item_def(w).is_empty():
			badw.append(sid2)
	check("every set weapon resolves to a real item", badw.is_empty(), ", ".join(badw))

	# ---- the Forge's daily imports (2026-07-28): roster stock, rotated ----
	var au = load("res://assign_ui.gd").new()
	add_child(au)
	var saved_hours: float = GameState.game_hours
	GameState.game_hours = 24.0 * 3.0   # day 3
	var imports_a: Array = au.smithy_imports()
	var imports_b: Array = au.smithy_imports()
	GameState.game_hours = 24.0 * 4.0   # day 4
	var imports_c: Array = au.smithy_imports()
	GameState.game_hours = saved_hours
	check("the Forge deals a full hand of imports", imports_a.size() == au.SMITHY_IMPORTS_PER_DAY,
		"%d dealt" % imports_a.size())
	check("...stable within a day", imports_a == imports_b)
	check("...and fresh the next morning", imports_a != imports_c)
	var import_ok := true
	for iid in imports_a:
		var rk := int(Inventory.GRADE_DEFS.get(Inventory.get_grade(iid), {}).get("rank", 99))
		if rk > au.smithy_max_rank() or not WeaponRoster.has_id(iid):
			import_ok = false
	check("...every import honours the grade cap and is a real roster id", import_ok)
	var setw_leak := false
	for sid3 in Inventory.SET_DEFS.keys():
		if str(Inventory.SET_DEFS[sid3].get("weapon", "")) in imports_a:
			setw_leak = true
	check("...and set weapons stay dungeon-drop only", not setw_leak)
	au.queue_free()

	# a roster weapon can actually be ADDED to a bag (caravan catch 2026-07-28:
	# add_item's existence guard predated the ladder -- every roster grant was
	# refused with a false "bag full", so the 275 were uncollectable live)
	var live_bag := Inventory.new(4)
	check("a roster weapon can actually be ADDED to a bag",
		live_bag.add_item("wpn_oakcudgel", 1) == 0 and live_bag.get_count("wpn_oakcudgel") == 1)

	# ---- Grandmother's Wand (12.2): the joke phase, guarded ----
	var ada_def: Dictionary = VillagerQuests.get_def("farmer_ada")
	check("Ada Brook carries the Soul Split bond, attemptable on day one",
		str(ada_def.get("reward_item", "")) == "wpn_soulsplit"
		and str(ada_def.get("kind", "")) == "gather" and str(ada_def.get("key", "")) == "wood",
		str(ada_def))
	check("grandmother's junk must not glow (grade common)",
		Inventory.get_grade("wpn_soulsplit") == "common", Inventory.get_grade("wpn_soulsplit"))
	var ss_def: Dictionary = Inventory.get_item_def("wpn_soulsplit")
	check("the card plays the joke and seeds the promise, spoiler-free",
		str(ss_def.get("unique_desc", "")).contains("grandmother")
		and not str(ss_def.get("unique_desc", "")).contains("Ten"))
	check("the Forge never stocks the gift",
		FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text().contains('"wpn_soulsplit": true'))
	check("...and the Wanderer never sells it",
		"wpn_soulsplit" in GameState.WANDERER_NEVER_SOLD)

	# ---- item-art overhaul (2026-07-28): the texture-first + element plumbing --
	# guards the Phase 0 architecture so a later regression can't silently break
	# the fallbacks or the element contract.
	# (wpn_sword used to be the no-art probe -- the full art pass gave EVERY
	# weapon a sprite, so only a genuinely nonexistent id stays procedural)
	check("icon_texture is null-safe when no art exists (procedural fallback stays)",
		Inventory.icon_texture("") == null and Inventory.icon_texture("not_a_real_item") == null)
	# the first real weapon sprite (Thundercaller) flows through the loader AND
	# paint_icon actually shows it as a TextureRect, not the procedural draw
	if ResourceLoader.exists("res://art/items/exc_thunder.png"):
		check("Thundercaller resolves a real sprite through icon_texture",
			Inventory.icon_texture("exc_thunder") != null)
		var probe := ColorRect.new()
		probe.size = Vector2(40, 40)
		add_child(probe)
		Inventory.paint_icon(probe, "exc_thunder")
		var has_texrect := false
		for c in probe.get_children():
			if c is TextureRect and (c as TextureRect).texture != null:
				has_texrect = true
		check("...and paint_icon renders it as a texture (bag == hand)", has_texrect)
		probe.queue_free()
	# Every wired weapon sprite must (a) resolve through icon_texture and (b)
	# name a REAL item id -- a rename/typo/missing .import can't ship silently,
	# and an orphan PNG (art for an id the game doesn't have) gets caught too.
	# Scans the folder so new art is covered automatically.
	var art_dir := DirAccess.open("res://art/items")
	var unresolved := []
	var orphan_art := []
	var art_count := 0
	if art_dir:
		for f in art_dir.get_files():
			if not f.ends_with(".png"):
				continue
			art_count += 1
			var id := f.get_basename()
			if Inventory.icon_texture(id) == null:
				unresolved.append(id)
			if Inventory.get_item_def(id).is_empty():
				orphan_art.append(id)
	check("every wired item sprite resolves through icon_texture (%d found)" % art_count,
		unresolved.is_empty(), "unresolved: %s" % ", ".join(unresolved))
	check("no orphan sprite (every art/items png names a real item)",
		orphan_art.is_empty(), "orphans: %s" % ", ".join(orphan_art))
	var elem_bundles_ok := true
	for e in Inventory.ELEMENTS:
		var fx: Dictionary = Inventory.ELEMENT_FX.get(e, {})
		if not (fx.has("tint") and fx.has("glow") and fx.has("status")):
			elem_bundles_ok = false
	check("every element has a full FX bundle (tint/glow/status)", elem_bundles_ok)
	check("element_of infers fire from a burn weapon, physical by default",
		Inventory.element_of("exc_thunder") in Inventory.ELEMENTS
		and Inventory.element_of("wpn_sword") == "physical")
	check("element_fx always resolves (unknown -> physical, never empty)",
		not Inventory.element_fx("nonsense").is_empty()
		and Inventory.element_fx("fire")["status"] == "burn")

	# --- WEAPONS DO THINGS, ARMOUR GIVES STATS (dev, 2026-07-30) -------------
	# A Monarch staff's card used to carry eight green stat lines -- +Max HP,
	# +Max Mana, +Move Speed, +Melee/Bow/Wand damage, +Gold, +XP -- none of
	# which had anything to do with the staff. They came from GRADE_PASSIVES,
	# which every weapon inherited from its grade. The dev's call: delete all of
	# it and pay for it with a stronger effect. This guards the line.
	var passive_grades := []
	for g in Inventory.GRADE_PASSIVES.keys():
		if not (Inventory.GRADE_PASSIVES[g] as Dictionary).is_empty():
			passive_grades.append(str(g))
	check("no GRADE grants a weapon passive stats", passive_grades.is_empty(),
		", ".join(passive_grades))
	# and prove it on the card itself, for a weapon of every grade
	var carded := []
	for wid in ["wpn_sword", "wpn_windcutter", "exc_ragnarok"]:
		var card := Inventory.build_tooltip_bbcode(wid) + Inventory.build_tooltip_text(wid)
		if card.to_lower().contains("while wielded"):
			carded.append(wid)
	check("no weapon card prints a 'while wielded' stat block", carded.is_empty(),
		", ".join(carded))
	# armour and relics KEEP their stats -- that is their whole job, and if this
	# ever goes quiet the stat budget has left the game entirely
	var armour_pays := false
	for k in (Inventory.ITEM_DEFS.get("armor_bulwark", {}).get("equip_effect", {}) as Dictionary):
		armour_pays = true
	check("armour still carries the stat budget the weapons gave up", armour_pays)
	# the compensation must be real: a Monarch verb has to hit meaningfully
	# harder than a Common one, or the trade was a straight nerf
	check("verb force scales the effect with the tier",
		WeaponRoster.verb_force(8) >= WeaponRoster.verb_force(1) * 1.5,
		"t1=%.2f t8=%.2f" % [WeaponRoster.verb_force(1), WeaponRoster.verb_force(8)])

	# --- EVERY WEAPON MUST BE REACHABLE IN THE PROVING GROUNDS --------------
	# The vault stocks one chest per GRADE, filling them from ITEM_GRADES plus
	# WeaponRoster.all_ids(). Its only catch-all branch takes materials,
	# consumables and currency -- so a weapon that is in ITEM_DEFS, absent from
	# ITEM_GRADES, and not generated by the roster lands in NO chest and cannot
	# be tested at all. That is exactly the kind of hole nobody notices until
	# they go looking for a weapon and it simply is not there.
	var vault := {}
	for gid in Inventory.ITEM_GRADES.keys():
		vault[str(gid)] = true
	for rid in WeaponRoster.all_ids():
		vault[str(rid)] = true
	var unreachable := []
	for iid in Inventory.ITEM_DEFS.keys():
		var idef: Dictionary = Inventory.ITEM_DEFS[iid]
		if str(idef.get("category", "")) != "weapon":
			continue
		if not vault.has(str(iid)):
			unreachable.append(str(iid))
	check("every weapon is stocked in a Proving Grounds chest (%d weapons)"
		% vault.size(), unreachable.is_empty(), ", ".join(unreachable))
	# and the armour/relics the player is meant to test alongside them
	var gear_missing := []
	for iid2 in Inventory.ITEM_DEFS.keys():
		var d2: Dictionary = Inventory.ITEM_DEFS[iid2]
		if str(d2.get("category", "")) in ["armor", "relic"] and not vault.has(str(iid2)):
			gear_missing.append(str(iid2))
	check("every armour piece and relic is stocked too", gear_missing.is_empty(),
		", ".join(gear_missing))

	# --- A ROSTER WEAPON MUST SURVIVE A SAVE ROUND-TRIP --------------------
	# from_save_data validated slots against ITEM_DEFS alone, so all ~350
	# GENERATED weapons were silently dropped on every inventory restore --
	# leaving a dungeon, entering one, loading a save. Found in play, 2026-07-30
	# ("most of the weapons disappear"). Nothing in the suite covered it because
	# every existing test used hand-authored ids, which are in ITEM_DEFS and so
	# always survived.
	var bag := Inventory.new(20)
	var sample := ["wpn_griefcrown", "wpn_soulflood", "smn_smallloyalty",
		"whp_firstlesson", "pst_watchingstone", "wpn_sword"]
	for sid in sample:
		bag.add_item(sid, 1)
	var round_trip := Inventory.new(20)
	round_trip.from_save_data(bag.to_save_data())
	var lost := []
	for sid2 in sample:
		if round_trip.get_count(sid2) < 1:
			lost.append(sid2)
	check("generated roster weapons survive a save round-trip", lost.is_empty(),
		"lost: " + ", ".join(lost))
	# and the guard must still throw away genuine junk
	var junk := Inventory.new(4)
	junk.from_save_data([{"item_id": "wpn_does_not_exist", "count": 3}])
	check("...but an unknown id is still dropped, not resurrected",
		junk.get_count("wpn_does_not_exist") == 0)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
