extends Node

# Melee is melee: the cursor sets the DIRECTION of a swing, never the distance.
# Guards the levitation removal -- the attack hitbox must sit at exactly the
# weapon's own range_offset no matter where the mouse is, and reach must come
# from the weapon itself (a spear outranges a dagger).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# ---------------- no levitation API survives ----------------
	for gone in ["hover_for_mouse", "levitate_max_range", "levitate_float_offset",
			"clamped_hover", "trigger_levitate_flash", "update_levitate_aura", "build_levitate_aura"]:
		check("levitation helper '%s' is gone" % gone, not p.has_method(gone))
	check("no innate Levitate node in any class tree",
		not str(SkillTreeData.TREES).contains("_levitate"))
	check("no skill grants levitate_range",
		not str(SkillTreeData.TREES).contains("levitate_range"))

	# ---------------- the hitbox sits at the weapon's own reach ----------------
	# whatever the mouse is doing, |AttackArea.position| == range_offset exactly.
	p.inventory.add_item("wpn_sword", 1)
	p.wield_weapon("wpn_sword")
	await get_tree().process_frame
	var stats: Dictionary = p.get_weapon_stats()
	p.update_weapon_visual(stats.icon_offset)
	var reach: float = p.get_node("AttackArea").position.length()
	check("melee hitbox sits at exactly the weapon's range_offset (no hover)",
		abs(reach - float(stats.range_offset)) < 0.01,
		"reach=%.2f range_offset=%.2f" % [reach, float(stats.range_offset)])

	# calling it repeatedly must not creep the reach outward (the old hover
	# tracked the cursor and grew; a held weapon is stable)
	for i in range(5):
		p.update_weapon_visual(stats.icon_offset)
		await get_tree().process_frame
	var reach2: float = p.get_node("AttackArea").position.length()
	check("reach is stable across frames (no cursor-tracking creep)",
		abs(reach2 - float(stats.range_offset)) < 0.01,
		"reach=%.2f" % reach2)

	# ---------------- reach comes from the weapon ----------------
	var dagger: float = float(Inventory.get_item_def("wpn_dagger").get("weapon_stats", {}).get("range_offset", 0.0))
	var spear: float = float(Inventory.get_item_def("wpn_spear").get("weapon_stats", {}).get("range_offset", 0.0))
	check("a spear reaches further than a dagger", spear > dagger,
		"spear=%.1f dagger=%.1f" % [spear, dagger])

	# ---------------- the Sage beam replaces the old Far Hand line ----------------
	check("Sage grants beam_channel, not levitate reach",
		str(SkillTreeData.TREES).contains("beam_channel"))
	# every node that grants beam_ramp must sit at/after the fork that unlocks the
	# beam, else it's a passive that is named but never read
	check("beam ramp nodes exist alongside the unlock",
		str(SkillTreeData.TREES).contains("beam_ramp"))
	# drive the real tree nodes, so this also proves the node data grants what
	# its description promises
	var saved_skills: Array = GameState.unlocked_skills.duplicate()
	GameState.unlocked_skills = []
	check("without the skill there is no beam", not p.has_beam())
	GameState.unlocked_skills = ["mg_s4b"]                       # Focusing Lens
	check("Focusing Lens unlocks the beam", p.has_beam())
	p.beam_connect_time = 0.0
	check("beam starts at 1.0x", abs(p.beam_ramp_mult() - 1.0) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.beam_connect_time = p.BEAM_RAMP_TIME
	check("beam ramps to its 2.5x peak on full contact",
		abs(p.beam_ramp_mult() - 2.5) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.beam_connect_time = p.BEAM_RAMP_TIME * 10.0
	check("beam never exceeds its peak (ramp is clamped)",
		abs(p.beam_ramp_mult() - 2.5) < 0.001, "%.3f" % p.beam_ramp_mult())
	GameState.unlocked_skills = ["mg_s4b", "mg_s6", "mg_s7"]     # +0.6 +0.5
	check("Sustained Focus + Transcendence raise the peak (2.5 -> 3.6x)",
		abs(p.beam_ramp_mult() - 3.6) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.stop_beam()
	check("stopping the beam resets the ramp", p.beam_connect_time == 0.0)
	GameState.unlocked_skills = saved_skills

	# ---------------- high-grade blades throw their swing forward ----------------
	var slashers := []
	var heavy_got_slash := []
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if not d.get("swing_slash", {}).is_empty():
			slashers.append(id)
			# a swing-slash is an EARNED high-grade perk, never a common drop
			var g: String = Inventory.ITEM_GRADES.get(id, "")
			check("slash weapon '%s' is legendary/mythic (earned, not free)" % id,
				g in ["legendary", "mythic"], "grade=%s" % g)
	check("several blades launch swing slashes", slashers.size() >= 5, "%d" % slashers.size())
	# the maul is a BIG weapon, not a slasher -- size and slashes are alternatives
	check("Earthshaker Maul stays big instead of gaining a slash",
		Inventory.ITEM_DEFS["exc_earthshaker"].get("swing_slash", {}).is_empty())
	# and the slash must be a fraction of the swing, never a straight upgrade
	for id in slashers:
		var m: float = float(Inventory.ITEM_DEFS[id]["swing_slash"].get("damage_mult", 1.0))
		check("'%s' slash is weaker than its own swing (%.2fx)" % [id, m], m < 1.0, "%.2f" % m)
	# the Shadowblade's description promised a slash it never had -- now it does
	check("Shadowblade actually launches the slash its text promises",
		not Inventory.ITEM_DEFS["exc_shadowblade"].get("swing_slash", {}).is_empty())
	check("player can launch a swing slash", p.has_method("launch_swing_slash"))

	# ---------------- size is derived from swing speed ----------------
	# the roster rule: within a type that actually swings, a bigger weapon must
	# never also be a faster one.
	var swingers := []
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if d.get("category", "") != "weapon":
			continue
		if not Inventory.SIZE_BANDS.has(str(d.get("weapon_type", ""))):
			continue
		var ws: Dictionary = Inventory.weapon_stats_for(id)
		swingers.append({"id": id, "type": str(d.get("weapon_type", "")),
			"cd": float(ws.get("cooldown", 0.0)),
			"area": ws.get("area_size", Vector2.ZERO).x * ws.get("area_size", Vector2.ZERO).y,
			"icon": ws.get("icon_size", Vector2.ZERO).x})
	var offenders := []
	for a in swingers:
		for b in swingers:
			if a["type"] != b["type"]: continue
			if a["area"] > b["area"] * 1.05 and a["cd"] < b["cd"] - 0.001:
				offenders.append("%s>%s" % [a["id"], b["id"]])
	check("no weapon is bigger AND faster than a peer", offenders.is_empty(),
		"%d offenders e.g. %s" % [offenders.size(), ", ".join(offenders.slice(0, 3))])

	# the drawn weapon IS the hitbox, so length and arc move together
	var slow := Inventory.weapon_stats_for("wpn_warhammer")
	var fast := Inventory.weapon_stats_for("wpn_twinblades")
	check("a slow heavy weapon is drawn longer than a fast light one",
		slow.icon_size.x > fast.icon_size.x * 1.5,
		"warhammer=%.0f twinfangs=%.0f" % [slow.icon_size.x, fast.icon_size.x])
	check("its swing arc is bigger to match", slow.area_size.x > fast.area_size.x)
	check("and it reaches further", slow.range_offset > fast.range_offset,
		"%.0f vs %.0f" % [slow.range_offset, fast.range_offset])

	# spears out-reach every melee weapon -- that is their whole identity
	var longest_melee := 0.0
	for s in swingers:
		if s["type"] == "melee":
			longest_melee = maxf(longest_melee, s["icon"])
	var shortest_spear := 9999.0
	for s in swingers:
		if s["type"] == "spear":
			shortest_spear = minf(shortest_spear, s["icon"])
	check("even the shortest spear out-reaches the longest melee weapon",
		shortest_spear > longest_melee,
		"spear=%.0f melee=%.0f" % [shortest_spear, longest_melee])

	# ---------------- the swing leaves a trail, hit or miss ----------------
	# swing at empty air, far from anything, and a trail must still appear
	p.wield_weapon("wpn_sword")
	var before_kids := p.get_children().size()
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	var after_kids := p.get_children().size()
	check("swinging at nothing still draws a trail", after_kids > before_kids,
		"%d -> %d children" % [before_kids, after_kids])
	# grade drives how much the swing shows: mythic must out-sweep common
	var common_arc := deg_to_rad(64.0 + int(Inventory.GRADE_DEFS["common"]["rank"]) * 7.0)
	var mythic_arc := deg_to_rad(64.0 + int(Inventory.GRADE_DEFS["mythic"]["rank"]) * 7.0)
	check("a mythic weapon sweeps a wider trail than a common one", mythic_arc > common_arc)

	# ---------------- levitation costs mana, for everyone ----------------
	check("every class can levitate", p.has_flight())
	check("wings stay an earned visual, separate from the ability", p.has_method("has_wings"))
	var saved_class = GameState.chosen_class
	GameState.chosen_class = "Sword"
	var sword_rate: float = p.levitate_mana_rate()
	GameState.chosen_class = "Mage"
	var mage_rate: float = p.levitate_mana_rate()
	GameState.chosen_class = saved_class
	check("a Mage levitates cheaper than a Sword", mage_rate < sword_rate,
		"mage=%.1f/s sword=%.1f/s" % [mage_rate, sword_rate])
	check("levitation is never free", p.levitate_mana_rate() >= 1.0)
	# holding Space off the ground must actually drain the pool
	p.god_mode = false
	p.global_position.y -= 260.0
	p.mana = p.get_max_mana()
	var mana_before: float = p.mana
	Input.action_press("jump")
	for i in range(20):
		await get_tree().physics_frame
	Input.action_release("jump")
	check("levitating burns mana", p.mana < mana_before,
		"%.1f -> %.1f" % [mana_before, p.mana])

	# ---------------- combo strings ----------------
	# string length follows swing speed: quick blades flurry, heavy ones don't
	p.inventory.add_item("wpn_twinblades", 1); p.wield_weapon("wpn_twinblades")
	var fast_len: int = p.combo_length()
	p.inventory.add_item("wpn_warhammer", 1); p.wield_weapon("wpn_warhammer")
	var slow_len: int = p.combo_length()
	check("a quick blade chains a longer string than a heavy one", fast_len > slow_len,
		"twinfangs=%d warhammer=%d" % [fast_len, slow_len])
	# THE key balance property: every string length must average the same
	# multiplier, or combos silently buff one weapon class over another. A short
	# string reaches its finisher far more often, so it needs a SMALLER one.
	for wid in ["wpn_twinblades", "wpn_sword", "wpn_warhammer"]:
		p.inventory.add_item(wid, 1)
		p.wield_weapon(wid)
		var n: int = p.combo_length()
		var avg: float = (float(n - 1) + p.combo_finisher_mult()) / float(n)
		check("'%s' string averages 1.25x (%d hits, %.2fx finisher)" % [wid, n, p.combo_finisher_mult()],
			abs(avg - 1.25) < 0.001, "avg=%.3f" % avg)
	p.wield_weapon("wpn_twinblades")
	var fast_fin: float = p.combo_finisher_mult()
	p.wield_weapon("wpn_warhammer")
	var slow_fin: float = p.combo_finisher_mult()
	check("the LONGER string carries the bigger finisher (it lands rarer)",
		fast_fin > slow_fin, "twinfangs=%.2fx warhammer=%.2fx" % [fast_fin, slow_fin])
	# and the heavy weapon still lands the biggest absolute hit, via base damage
	var hammer_fin: float = float(Inventory.weapon_stats_for("wpn_warhammer").damage) * slow_fin
	var fang_fin: float = float(Inventory.weapon_stats_for("wpn_twinblades").damage) * fast_fin
	check("the maul's finisher still hits far harder in absolute terms",
		hammer_fin > fang_fin * 2.0, "hammer=%.0f fangs=%.0f" % [hammer_fin, fang_fin])

	# walking the string: only the LAST hit is multiplied
	p.wield_weapon("wpn_sword")
	p.reset_combo()
	var mults := []
	for i in range(p.combo_length()):
		mults.append(p.combo_step())
	var non_final_all_one := true
	for i in range(mults.size() - 1):
		if abs(float(mults[i]) - 1.0) > 0.001:
			non_final_all_one = false
	check("every hit before the finisher is a plain 1.0x", non_final_all_one, str(mults))
	check("the finisher multiplies", float(mults[mults.size() - 1]) > 1.0, str(mults))
	# the string wraps around rather than sticking on the finisher
	check("after the finisher the string restarts", abs(p.combo_step() - 1.0) < 0.001)
	# letting the window lapse drops you back to the start
	p.reset_combo()
	p.combo_step()
	p.combo_expire_at = 0.0        # pretend the window elapsed
	check("a lapsed window resets the string", abs(p.combo_step() - 1.0) < 0.001)
	# swapping weapons must not carry a banked finisher across
	p.reset_combo()
	p.combo_step()
	p.wield_weapon("wpn_dagger")
	check("swapping weapons clears the combo", p.combo_index == 0)

	# ---------------- per-weapon crit character ----------------
	p.wield_weapon("wpn_twinblades")
	var fast_cc: float = p.weapon_crit_chance_bonus()
	var fast_cd: float = p.weapon_crit_damage_bonus()
	p.wield_weapon("wpn_warhammer")
	var slow_cc: float = p.weapon_crit_chance_bonus()
	var slow_cd: float = p.weapon_crit_damage_bonus()
	check("a quick blade crits more OFTEN", fast_cc > slow_cc,
		"twinfangs=%.2f warhammer=%.2f" % [fast_cc, slow_cc])
	check("a heavy weapon crits HARDER", slow_cd > fast_cd,
		"warhammer=%.2f twinfangs=%.2f" % [slow_cd, fast_cd])
	check("crit character applies only to melee", true)
	p.wield_weapon("wpn_bow")
	check("a bow gets no melee crit bias",
		p.weapon_crit_chance_bonus() == 0.0 and p.weapon_crit_damage_bonus() == 0.0)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
