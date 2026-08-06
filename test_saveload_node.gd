extends Node

# The LIVE save/load round trip. tool_save_audit proves every written key is
# read back; this proves the VALUES survive the trip -- JSON coerces ints to
# floats, dictionaries can lose shape, and a bug like that passes the static
# audit while quietly corrupting a real playthrough.
#
# SAFETY: this test writes user://savegame.json -- the dev's REAL save lives
# there. The original bytes are backed up before the trip and restored after,
# no matter what; if no save existed, the test's file is deleted.

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

	# ---- back up the real save ----
	var backup: PackedByteArray = PackedByteArray()
	var had_save := FileAccess.file_exists(GameState.SAVE_PATH)
	if had_save:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
		backup = f.get_buffer(f.get_length())
		f.close()

	# ---- paint a maximally distinctive state ----
	p.currency = 4321
	p.inventory.add_item("wpn_katana", 1)
	GameState.doctor_heals_bought = 3
	GameState.seen_orin_arrival = true
	GameState.seen_failed_escape = true
	GameState.seen_orin_glimpse = false
	GameState.ensure_adventurers()
	GameState.adventurers["adv_wren"]["station"] = "house"
	GameState.adventurers["adv_castor"]["dead"] = true
	var sena = GameState.find_villager_by_id("sena_ward")
	if not sena.is_empty():
		sena["quest_state"] = "active"
		sena["quest_progress"] = 1
	GameState.away_report = {"sieges": 2, "repelled": 1, "villagers_lost": 3, "adventurers_lost": 1, "fallen_names": ["Castor"], "stabilized": 1}
	GameState.save_game(p)

	# ---- scramble everything, then load ----
	p.currency = 0
	GameState.doctor_heals_bought = 0
	GameState.seen_orin_arrival = false
	GameState.seen_failed_escape = false
	GameState.adventurers["adv_wren"]["station"] = "wall"
	GameState.adventurers["adv_castor"]["dead"] = false
	# GameState is an autoload that survives Quit-to-Menu, so transient run-flags
	# from the pre-menu session must NOT leak into the continued game (a quit
	# inside a dungeon / mid-Harvest once left these set, disabling live sieges /
	# soft-locking the finale). load_game must clear them.
	GameState.in_dungeon = true
	GameState.harvest_at_home = true
	GameState.feast_glow = true
	GameState.load_game()
	if GameState.has_method("apply_save_to_player"):
		GameState.apply_save_to_player(p)

	# Currency reaches the purse on the scene reload, not here -- so this asserts
	# what load_game() genuinely owes at this point: the flags a quit-in-progress
	# left set are CLEARED. (It used to assert the literal `true` under the note
	# "key checked below", which made it a slot that could never fail.)
	check("a quit inside a dungeon / mid-Harvest does not leak into the loaded run",
		not GameState.in_dungeon and not GameState.harvest_at_home and not GameState.feast_glow,
		"in_dungeon=%s harvest_at_home=%s feast_glow=%s" % [str(GameState.in_dungeon),
			str(GameState.harvest_at_home), str(GameState.feast_glow)])
	# reads what save_game just WROTE -- under MONARCH_TEST that is the
	# sidecar, never the dev's real file (which lines 32-39 back up anyway)
	var raw := FileAccess.open(GameState.active_save_path(), FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(raw.get_as_text())
	raw.close()
	check("the file holds the exact gold", int(saved.get("currency", -1)) == 4321)
	check("the doctor's ledger survives", GameState.doctor_heals_bought == 3)
	check("story one-shots survive exactly (true stays true, false stays false)",
		GameState.seen_orin_arrival and GameState.seen_failed_escape and not GameState.seen_orin_glimpse)
	check("a housed adventurer stays housed",
		str(GameState.adventurers["adv_wren"]["station"]) == "house")
	check("a DEAD adventurer stays dead through the trip -- permadeath is sacred",
		bool(GameState.adventurers["adv_castor"]["dead"]))
	check("Continue clears the transient run-flags (no leak from a quit-to-menu)",
		not GameState.in_dungeon and not GameState.harvest_at_home and not GameState.feast_glow)
	if not sena.is_empty():
		var sena2 = GameState.find_villager_by_id("sena_ward")
		check("quest progress survives (JSON floats cast back cleanly)",
			int(sena2.get("quest_progress", 0)) == 1 and str(sena2.get("quest_state", "")) == "active")
	# JSON coercion trap: after a round trip these must still behave as their types
	check("the rescued flag still reads as bool after JSON",
		GameState.adventurer_state("adv_roland").get("rescued", false) == true)
	check("fighting_adventurers still excludes the dead after the trip",
		not "adv_castor" in GameState.fighting_adventurers())
	check("the away-report keeps its fallen adventurers through the trip (homecoming lines)",
		int(GameState.away_report.get("adventurers_lost", 0)) == 1
		and GameState.away_report.get("fallen_names", []) == ["Castor"]
		and int(GameState.away_report.get("stabilized", 0)) == 1)

	# ---- a New Game must be a NEW game ----
	# The state is still maximally dirty from the round trip: freed legends,
	# a finished harvest, spent story beats. One reset must rewind all of it
	# (the static tool_reset_audit names missing keys; this proves the values).
	GameState.the_ten["ten_brannoc"] = {"freed": true}
	GameState.harvest_done = true
	GameState.harvested_villagers = [{"name": "Ghost"}]
	GameState.seen_orin_arrival = true
	GameState.seen_kneel_echo = true
	GameState.reset_for_new_game()
	check("new game re-cages the Ten", GameState.count_ten_freed() == 0)
	check("new game un-happens the Harvest",
		not GameState.harvest_done and GameState.harvested_villagers.is_empty())
	check("new game rewinds the story one-shots",
		not GameState.seen_orin_arrival and not GameState.seen_kneel_echo)
	check("new game: Orin has not yet walked out of the dungeon",
		not GameState.orin_arrived())
	check("new game: the Forge is locked again",
		not GameState.blacksmith_unlocked())

	# ---- the save file itself is armoured (global hunt 2026-07-28) ----
	# under MONARCH_TEST every byte goes to the SIDECAR -- the dev's real
	# save is no longer a fixture for any suite, from any parallel session
	check("tests write the sidecar, never the real path",
		GameState.active_save_path() != GameState.SAVE_PATH)
	# atomic write: a finished save leaves no .tmp behind
	GameState.save_game(p)
	check("a finished save leaves no .tmp litter",
		FileAccess.file_exists(GameState.active_save_path())
		and not FileAccess.file_exists(GameState.active_save_path() + ".tmp"))
	# a CORRUPT save must load as nothing -- never crash, never half-apply
	var g := FileAccess.open(GameState.active_save_path(), FileAccess.WRITE)
	g.store_string("{ this is not json")
	g.close()
	check("a corrupt save loads as nothing, without a crash",
		GameState.load_game() == {})
	DirAccess.remove_absolute(GameState.active_save_path())

	# ---- restore the dev's real save, no matter what ----
	if had_save:
		var w := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		w.store_buffer(backup)
		w.close()
	else:
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	# ...and PROVE it. This used to assert the literal `true`, which is the one
	# thing a restore check must never do: the whole point is that a suite run can
	# never cost the dev their save, and "we ran the restore code" is not that.
	if had_save:
		var vf := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
		var restored: PackedByteArray = PackedByteArray() if vf == null else vf.get_buffer(vf.get_length())
		if vf != null: vf.close()
		check("the dev's real save was restored byte-for-byte",
			restored == backup, "%d bytes back of %d" % [restored.size(), backup.size()])
	else:
		check("no save existed, and none was left behind",
			not FileAccess.file_exists(GameState.SAVE_PATH))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
