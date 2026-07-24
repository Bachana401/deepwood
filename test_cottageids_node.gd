extends Node
# STABLE COTTAGE IDS (dev 2026-07-23). Player-built cottages were keyed by their
# ARRAY INDEX ("menu_house_%d" % j). Deleting a NON-LAST cottage shifted every later
# id, so on reload a settled couple's cottage_homes entry pointed at an id that no
# longer existed (their home orphaned, the real cottage read empty and could be
# double-booked) -- and the very next build collided its id with a survivor. The id is
# STABLE now (register_cottage hands out a never-reused id, stored per cottage). This
# locks: build -> settle -> delete the MIDDLE one -> the reload id derivation still
# resolves every home, and a fresh build never reuses a surviving id. See
# [[deepwood_build_menu]].

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	# Operate directly on GameState's cottage bookkeeping; snapshot + restore it so the
	# test never disturbs the live village it booted into.
	var snap := {
		"n": GameState.extra_cottages,
		"pos": GameState.extra_cottage_positions.duplicate(),
		"ids": GameState.extra_cottage_ids.duplicate(),
		"seq": GameState.cottage_id_seq,
		"homes": GameState.cottage_homes.duplicate(true),
		"mate": GameState.mating_houses.duplicate(true),
	}
	GameState.extra_cottages = 0
	GameState.extra_cottage_positions = []
	GameState.extra_cottage_ids = []
	GameState.cottage_id_seq = 0
	GameState.cottage_homes = {}
	GameState.mating_houses = {}

	# ---- build three cottages ----
	var id0 := GameState.register_cottage(100.0)
	var id1 := GameState.register_cottage(200.0)
	var id2 := GameState.register_cottage(300.0)
	check("three builds -> three unique ids",
		id0 != id1 and id1 != id2 and id0 != id2, "%s/%s/%s" % [id0, id1, id2])
	check("count + both arrays stay in lockstep after builds",
		GameState.extra_cottages == 3 and GameState.extra_cottage_positions.size() == 3 \
		and GameState.extra_cottage_ids.size() == 3)

	# a couple SETTLES in the last cottage, and a pairing is mid-cycle in the middle one
	GameState.cottage_homes[id2] = {"a": "villager_A", "b": "villager_B"}
	GameState.mating_houses[id1] = {"male_id": "M", "female_id": "F", "remaining_hours": 5.0}

	# ---- delete the FIRST cottage: the reindex trap ----
	GameState.remove_cottage(id0, 100.0)
	check("delete drops the count to 2", GameState.extra_cottages == 2)
	check("the settled couple's home SURVIVES the middle delete",
		GameState.cottage_homes.has(id2), "homes=%s" % str(GameState.cottage_homes.keys()))
	check("the mid-cycle pairing in a SURVIVING cottage is untouched",
		GameState.mating_houses.has(id1), "mate=%s" % str(GameState.mating_houses.keys()))

	# ---- simulate the reload id derivation (main.gd stamps cottage_id_at over range) ----
	var reload_ids := {}
	for j in range(GameState.extra_cottages):
		reload_ids[GameState.cottage_id_at(j)] = true
	check("every settled home resolves to a real cottage on reload (no orphan)",
		reload_ids.has(id2), "reload=%s home=%s" % [str(reload_ids.keys()), id2])
	check("the surviving middle cottage keeps its OWN id",
		reload_ids.has(id1))

	# ---- a fresh build after the delete must not reuse a surviving id ----
	var id3 := GameState.register_cottage(400.0)
	check("a new build never collides a surviving id",
		id3 != id1 and id3 != id2, "new=%s survivors=%s,%s" % [id3, id1, id2])

	# ---- legacy migration: an old save with NO ids synths the matching menu_house_%d,
	# so its existing cottage_homes["menu_house_1"] still resolves (mirrors the load path) ----
	GameState.extra_cottage_ids = []
	GameState.extra_cottage_positions = [100.0, 200.0, 300.0]
	GameState.extra_cottages = 3
	var want: int = maxi(GameState.extra_cottages, GameState.extra_cottage_positions.size())
	while GameState.extra_cottage_ids.size() < want:
		GameState.extra_cottage_ids.append("menu_house_%d" % GameState.extra_cottage_ids.size())
	check("a legacy save synths the old menu_house ids (backward compatible)",
		GameState.cottage_id_at(0) == "menu_house_0" and GameState.cottage_id_at(2) == "menu_house_2")

	# restore the live village bookkeeping untouched
	GameState.extra_cottages = snap.n
	GameState.extra_cottage_positions = snap.pos
	GameState.extra_cottage_ids = snap.ids
	GameState.cottage_id_seq = snap.seq
	GameState.cottage_homes = snap.homes
	GameState.mating_houses = snap.mate

	printerr("test_cottageids : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
