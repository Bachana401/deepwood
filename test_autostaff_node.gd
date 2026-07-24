extends Node
# AUTO-STAFF CAPACITY (dev 2026-07-23). The manual assign UI (is_role_full /
# assign_ui) caps a worker role at the building's effective_slots -- base +
# SLOTS_PER_LEVEL per upgrade. The Chancellor's auto-staff (try_auto_place) capped at
# the STATIC base instead, so it could never fill an upgraded worker building past its
# level-1 count: the panel offered slots automation refused, and a big auto-run town
# under-produced (food most of all). GameState.role_capacity now returns the live
# effective_slots (falling back to base with no node, so headless sims are unchanged).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(300):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break

	# the "Party" worker role (base 10 slots) on the Government (a building that
	# already stands, as a ruin, in a fresh village)
	var party_rd := {}
	for rd in BuildingRoles.get_roles("Government"):
		if str(rd.get("title", "")) == "Party":
			party_rd = rd
	check("found the Party worker role (base 10)", int(party_rd.get("slots", 0)) == 10)

	var gov = get_tree().get_first_node_in_group("building_role_Government")
	check("the village seats a Government building node", gov != null and gov.has_method("effective_slots"))
	if gov == null:
		printerr("test_autostaff : RESULT: 1 FAILURES  (FAILs=1)"); get_tree().quit(1); return

	# level 1 -> capacity is the base; level 3 -> base + 2*(3-1) = 14
	gov.building_level = 1
	check("auto-staff capacity at level 1 == base (10)",
		GameState.role_capacity("Government", party_rd) == 10,
		str(GameState.role_capacity("Government", party_rd)))
	gov.building_level = 3
	check("auto-staff capacity GROWS with upgrades (14 at level 3) — matches the assign UI",
		GameState.role_capacity("Government", party_rd) == 14 \
		and GameState.role_capacity("Government", party_rd) == gov.effective_slots(party_rd),
		"cap=%d effective=%d" % [GameState.role_capacity("Government", party_rd), gov.effective_slots(party_rd)])

	# no such building -> fall back to the static base (a headless sim path)
	check("with no building node, capacity falls back to base",
		GameState.role_capacity("NoSuchBuilding", party_rd) == 10)

	# and the auto-placer actually consults role_capacity, not the raw base slots
	var src := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("try_auto_place caps on role_capacity, not int(rd.slots)",
		src.contains("count_leader_holders(bkey, str(rd.get(\"title\", \"\"))) >= role_capacity(bkey, rd)"))

	printerr("test_autostaff : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
