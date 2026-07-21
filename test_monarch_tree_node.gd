extends Node

# The Shadow Monarch class -- the reward for beating the game -- used to be a
# skill tree of four "???" nodes with empty effects: you won, unlocked it, and
# its progression screen was blank. This builds the full Legion/Dominion/
# Ascendant tree on the shade/nova/true-form mechanics already in the game, and
# this test proves every node actually does something.

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

	var T = SkillTreeData.TREES.get("Shadow Monarch", [])
	var saved := GameState.unlocked_skills.duplicate()

	# ---- the tree is real, not a teaser ----
	check("Monarch tree has a full 25 nodes like the other classes", T.size() == 25,
		"%d nodes" % T.size())
	var ults := 0
	var empties := 0
	var names_ok := true
	for n in T:
		if int(n.get("tier", 0)) == 7: ults += 1
		if n.get("effect", {}).is_empty(): empties += 1
		if str(n.get("name", "")) == "???" or str(n.get("desc", "")) == "???": names_ok = false
	check("three specs, three ultimates", ults == 3, "%d" % ults)
	check("no node is a blank ??? placeholder anymore", empties == 0 and names_ok,
		"%d empty" % empties)
	check("branch names are set", SkillTreeData.BRANCH_NAMES.get("Shadow Monarch", [])[0] == "Legion")

	# ---- the mechanics each node promises actually fire ----
	# LEGION: the root unlocks raising shades even at low character level
	GameState.unlocked_skills = ["nc_root"]
	check("the Pact lets a fresh Monarch raise shades (not gated to stage 5)",
		p.can_raise_shades())
	GameState.unlocked_skills = []
	check("without the Pact a level-1 character raises no shades", not p.can_raise_shades())

	# shade cap grows with the Legion line
	GameState.unlocked_skills = ["nc_root"]
	var base_cap := 2 + int(GameState.get_skill_total("shade_cap"))
	GameState.unlocked_skills = ["nc_root", "nc_l1", "nc_l4a", "nc_l6", "nc_l7"]  # +1+2+1+2
	var big_cap := 2 + int(GameState.get_skill_total("shade_cap"))
	check("Legion raises the shade cap (2 -> %d)" % big_cap, big_cap >= base_cap + 5,
		"%d -> %d" % [base_cap, big_cap])

	# actually raise one and confirm the skill damage bonus lands on it
	GameState.unlocked_skills = ["nc_root", "nc_l1", "nc_l2"]   # +25% shade dmg
	for s0 in p.monarch_shades:
		if is_instance_valid(s0): s0.free()
	p.monarch_shades = []
	p.raise_shade()
	await get_tree().process_frame
	check("a shade is actually raised", p.monarch_shades.size() >= 1)
	if p.monarch_shades.size() >= 1:
		var plain_dmg := int(round(8.0 + GameState.player_level * 0.55))
		check("Sharpened Dead makes the shade hit harder than a base shade",
			p.monarch_shades[0].damage > plain_dmg, "%d vs base %d" % [p.monarch_shades[0].damage, plain_dmg])

	# Volatile Dead arms the shade to burst; Standing Army makes it permanent
	GameState.unlocked_skills = ["nc_root", "nc_l3", "nc_l4b"]
	for s1 in p.monarch_shades:
		if is_instance_valid(s1): s1.free()
	p.monarch_shades = []
	p.raise_shade()
	await get_tree().process_frame
	check("Volatile Dead arms shades to explode on death",
		p.monarch_shades.size() >= 1 and p.monarch_shades[0].explode_frac > 0.0)
	check("Standing Army shades never expire", p.monarch_shades[0].expires_at == 0.0)

	# DOMINION: nova on-demand and the fear aura
	GameState.unlocked_skills = ["nc_root", "nc_d1", "nc_d2", "nc_d3"]
	check("Deadly Presence unlocks the shadow nova without the true form",
		GameState.get_skill_total("nova_passive") > 0.0)
	check("Sovereign's Dread grants a fear aura", GameState.get_skill_total("fear_aura") > 0.0)
	check("the Monarch can apply that aura", p.has_method("apply_fear_aura"))
	GameState.unlocked_skills = ["nc_root", "nc_d3", "nc_d4a", "nc_d7"]
	check("Crown of Ruin + ultimate raise nova power", GameState.get_skill_total("nova_power") > 1.0)

	# ASCENDANT: the ultimate grants the true form as a skill
	GameState.unlocked_skills = []
	check("no true form without the ultimate (fresh Monarch)", not GameState.monarch_true_form())
	GameState.unlocked_skills = ["nc_a7"]
	check("Sovereign of the Dead grants the TRUE FORM at will", GameState.monarch_true_form())

	GameState.unlocked_skills = saved
	for s in p.monarch_shades:
		if is_instance_valid(s): s.free()
	p.monarch_shades = []

	# EVERY NODE MUST FIT INSIDE THE REACHABLE CANVAS. The width was hardcoded
	# to 894 while the Mage tree hangs Telepathy at col 6.5 (x~1100), so it was
	# clipped by the panel and impossible to click. Render each class tree and
	# assert the widest/deepest node sits within the scroll canvas.
	var st: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("skill_tree_ui.gd"):
			st = n
			break
	if st != null:
		for cls in ["Sword", "Archer", "Mage", "Shadow Monarch"]:
			GameState.chosen_class = cls
			GameState.skill_points = 60
			st.panel.visible = true
			st.refresh()
			await get_tree().process_frame
			var cw: float = st.tree_canvas.custom_minimum_size.x
			var ch: float = st.tree_canvas.custom_minimum_size.y
			var worst := 0.0
			for node in SkillTreeData.TREES.get(cls, []):
				var right: float = st.lane_x(float(node.get("col", 0.5))) + st.CARD_W
				var bottom: float = st.tier_top_y(node.tier) + st.CARD_H
				if right > cw + 1.0 or bottom > ch + 1.0:
					worst = maxf(worst, maxf(right - cw, bottom - ch))
			check("%s tree: every node fits the reachable canvas" % cls, worst < 1.0,
				"%.0f px past the canvas" % worst)
		st.panel.visible = false

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
