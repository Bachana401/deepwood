extends Node

# Regression net for the full-game audit. These are bugs that actually shipped,
# not hypotheticals -- each check corresponds to something found broken.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	# --- 1) equipment dict survives a New Game with every slot intact ---
	# Shipped bug: reset_for_new_game rebuilt the dict WITHOUT gloves/boots, so
	# get_equipment_total threw on every stat query for the rest of the run.
	GameState.reset_for_new_game()
	for slot in GameState.GEAR_SLOTS:
		check("new game keeps '%s' slot" % slot, GameState.equipment.has(slot),
			"equipment keys: %s" % str(GameState.equipment.keys()))
	check("new game keeps relics array", GameState.equipment.has("relics")
		and GameState.equipment["relics"].size() == GameState.RELIC_MAX_SLOTS)

	# every stat query must survive a fresh game -- this is the actual crash path
	var keys := ["damage_reduction", "melee_damage", "max_health", "move_speed",
		"dodge_chance", "lifesteal", "crit_chance", "thorns"]
	for k in keys:
		var v: float = GameState.get_bonus_total(k)
		# asserted the literal `true` -- so it only ever proved "the call returned".
		# A NAN out of here poisons every stat it touches and compares false against
		# everything, which is exactly the kind of silent wrong this file exists for.
		check("get_bonus_total('%s') is a real number on a fresh game (%.2f)" % [k, v],
			is_finite(v))

	# --- 2) a malformed/old save cannot leave a slot missing either ---
	GameState.load_equipment({"helmet": "helm_iron"})   # ancient save shape
	var ok := true
	for slot in GameState.GEAR_SLOTS:
		if not GameState.equipment.has(slot):
			ok = false
	check("old save shape is sanitised to full slots", ok,
		str(GameState.equipment.keys()))
	check("...and still reads the saved helmet", GameState.equipment["helmet"] == "helm_iron")

	# --- 3) worn armor actually applies (the feature, end to end). Gloves and
	# boots are RETIRED slots (Terraria-exact armor, 2026-07-28) -- the chest
	# piece carries the check now, and the retired keys must NOT come back.
	GameState.equipment["chest"] = "armor_bulwark"
	var with_chest: float = GameState.get_bonus_total("max_health")
	GameState.equipment["chest"] = ""
	var without: float = GameState.get_bonus_total("max_health")
	check("worn armor contributes to stats (%.1f vs %.1f)" % [with_chest, without],
		with_chest > without)
	for retired in GameState.RETIRED_SLOTS:
		check("retired slot '%s' stays retired" % retired,
			not GameState.equipment.has(retired), str(GameState.equipment.keys()))

	# --- 4) the registry guard is itself registered ---
	# test_registry_node.gd is what stops an unlisted test from vanishing silently.
	# It can only do that job if IT is listed, and dropping one line from
	# all_test_files.txt is exactly how this project has lost coverage twice. This
	# check means the guard cannot be disarmed without a SECOND test going red.
	var reg := FileAccess.open("res://all_test_files.txt", FileAccess.READ)
	check("the registry drift guard is still registered (it is what catches the rest)",
		reg != null and reg.get_as_text().contains("test_registry_node"))
	if reg != null:
		reg.close()

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
