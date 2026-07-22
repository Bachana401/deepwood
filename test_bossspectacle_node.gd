extends Node

# WUKONG BOSS SPECTACLE (dev ask 2026-07-22): a cinematic name-card on entry, a
# big named health bar that drains, a flash+banner when the boss turns, and a
# kill flourish. Locks that the overlay drives cleanly and that the boss +
# dungeon actually call into it.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	var hud = load("res://boss_hud.gd").new()
	get_tree().current_scene.add_child(hud)
	await get_tree().process_frame

	# the entrance
	hud.present("The Gravewarden", "weak to fire", Color(0.55, 0.95, 0.35))
	check("present() arms the fight", hud._alive and hud.bar_name.text == "The Gravewarden")
	check("the subtitle carries the weakness", hud.card_sub.text == "weak to fire")

	# the drain eases toward the target
	hud.set_health(0.4)
	for i in range(45):
		await get_tree().process_frame
	check("the health bar drains toward the hit", hud._hp_shown < 0.6, str(hud._hp_shown))
	check("the fill width tracks the drain", hud.bar_fill.size.x < (hud.BAR_W - 4.0) * 0.6)

	# the turn + the kill don't crash and close the fight out
	hud.phase_banner("ENRAGED")
	await get_tree().process_frame
	hud.slain("The Gravewarden")
	check("slain() closes the fight", not hud._alive)
	for i in range(4):
		await get_tree().process_frame
	check("the kill flourish names the boss", hud.card_title.text.contains("SLAIN"))

	# the wiring is real
	var dsrc := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	check("the dungeon seats a BossHUD and presents the boss",
		dsrc.contains('bhud.name = "BossHUD"') and dsrc.contains("hud.present("))
	var bsrc := FileAccess.open("res://boss.gd", FileAccess.READ).get_as_text()
	check("the boss drives the bar, the banners, and the flourish",
		bsrc.contains("hud.set_health(percent)") and bsrc.contains("_boss_hud_banner")
		and bsrc.contains("hud.slain(get_display_name())"))
	check("enrage + frenzy raise banners",
		bsrc.contains('_boss_hud_banner("ENRAGED")') and bsrc.contains('_boss_hud_banner("FRENZY")'))

	hud.queue_free()
	printerr("test_bossspectacle : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
