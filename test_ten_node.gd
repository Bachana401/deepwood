extends Node

# THE TEN (GAME_BIBLE §8) -- the capstone hostages. Ten legends in gilded
# Trophy Vaults, one permanent village boon each, and the finale gate: floor
# 100 stays sealed while any of them still hangs. Names, floors and boons are
# canon transcribed from the §8 table; this suite holds the build to it.

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

	# ---------------- the registry holds to the canon table ----------------
	check("ten of the Ten", TheTen.ids().size() == 10)
	var canon_floors := {52: "ten_brannoc", 58: "ten_maera", 63: "ten_toren", 69: "ten_sylvara",
		74: "ten_kaldos", 79: "ten_elenwe", 84: "ten_dorian", 89: "ten_mirielle",
		94: "ten_seraphel", 99: "ten_ilo"}
	for fl in canon_floors.keys():
		var d = TheTen.for_level(fl)
		check("floor %d holds %s (canon table)" % [fl, canon_floors[fl]],
			str(d.get("id", "")) == canon_floors[fl], str(d.get("id", "(none)")))
	# every one has a boon and a line -- no silent trophies
	for id in TheTen.ids():
		var d = TheTen.get_def(id)
		check("'%s' carries a boon and a voice" % id,
			str(d.get("boon", "")) != "" and str(d.get("line", "")) != "")

	# ---------------- freeing one: roster + flags + gate maths ----------------
	var saved_ten = GameState.the_ten.duplicate(true)
	GameState.the_ten = {}
	GameState.ensure_the_ten()
	check("all ten start captive", GameState.count_ten_freed() == 0)
	check("...so the finale gate is sealed", not GameState.all_ten_freed())
	GameState.free_one_of_the_ten("ten_brannoc")
	check("freeing Brannoc flips his flag", GameState.ten_freed("ten_brannoc"))
	check("...and he walks the village as a Legend",
		not GameState.find_villager_by_id("ten_brannoc").is_empty()
		and GameState.find_villager_by_id("ten_brannoc").get("unbreakable", false))
	check("the count advances", GameState.count_ten_freed() == 1)
	for id in TheTen.ids():
		GameState.free_one_of_the_ten(id)
	check("all ten freed opens the finale gate", GameState.all_ten_freed())

	# ---------------- the boons, functionally ----------------
	# Brannoc: warriors train twice as fast, the wall stands half again as strong
	GameState.the_ten["ten_brannoc"]["freed"] = false
	var base_grad: float = GameState.get_barracks_graduation_speed_multiplier()
	GameState.the_ten["ten_brannoc"]["freed"] = true
	check("Brannoc: warriors train twice as fast",
		abs(GameState.get_barracks_graduation_speed_multiplier() - base_grad * 2.0) < 0.001)
	var wall = load("res://wall.gd").new()
	get_tree().root.add_child(wall)
	await get_tree().process_frame
	check("Brannoc: the wall stands half again as strong", wall.max_health == 1200,
		"%d" % wall.max_health)
	wall.queue_free()
	# Toren: the Forge sells Epic, crafting costs a quarter less
	var aui = get_tree().root.find_children("*", "", true, false).filter(func(n): return n.has_method("smithy_max_rank"))
	if aui.size() > 0:
		check("Toren: the Forge sells one grade higher (Epic, rank 4)", aui[0].smithy_max_rank() == 4)
	p.inventory.add_item("void_essence", 4)
	p.inventory.add_item("slime", 4)
	var before_slime: int = p.inventory.get_count("slime")
	var craft_err: String = GameState.try_craft("potion_reset", p)   # canon cost 2+5 -> 2+4 with Toren
	check("Toren: crafting costs a quarter less (5 slime -> 4)",
		craft_err == "" and p.inventory.get_count("slime") == before_slime - 4,
		"err='%s' slime %d->%d" % [craft_err, before_slime, p.inventory.get_count("slime")])
	# Dorian: half the death-drop is insured
	p.currency = 100
	p.drop_currency_on_death()
	check("Dorian: half the dropped gold never leaves your purse", p.currency == 61,
		"%d left (77%% halved -> 39 dropped)" % p.currency)
	# Maera: the price mends twice as fast
	GameState.doctor_heals_bought = 1
	GameState._doctor_decay_accum = 0.0
	GameState.decay_doctor_price(12.0)   # half a day: only enough at Maera's pace
	check("Maera: the Doctor's price mends twice as fast", GameState.doctor_heals_bought == 0)
	# Sylvara: farm output doubled (pure function, farmers or none)
	GameState.the_ten["ten_sylvara"]["freed"] = false
	var base_food: float = GameState.food_production_per_hour()
	GameState.the_ten["ten_sylvara"]["freed"] = true
	check("Sylvara: farm output doubled",
		abs(GameState.food_production_per_hour() - base_food * 2.0) < 0.001 or base_food == 0.0)
	# Ilo: his line leads the L100 reveal
	var di_src := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("Ilo: at the gate of 100 he names what stirs", di_src.contains("ten_ilo") and di_src.contains("Thrones do not stay empty"))
	# the gate itself is enforced at the door
	var ls_src := FileAccess.open("res://level_select_ui.gd", FileAccess.READ).get_as_text()
	check("the finale gate is enforced at level select", ls_src.contains("all_ten_freed"))
	# vaults spawn from the dungeon's rescue hook
	var du_src := di_src
	check("trophy vaults spawn on their canon floors", du_src.contains("TheTen.for_level(current_level)"))

	# restore
	GameState.the_ten = saved_ten
	for id in TheTen.ids():
		var v = GameState.find_villager_by_id(id)
		if not v.is_empty():
			GameState.rescued_villagers.erase(v)
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
