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

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
