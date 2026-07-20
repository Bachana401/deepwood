extends Node

# GOD MODE: one admin switch that must give all three powers at once --
# untouchable, T super-dash, and unlimited flight with the wings showing --
# and must give NONE of them when it's off.

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

	var panel: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("_toggle_god"):
			panel = n
			break
	check("admin panel found", panel != null)
	if panel == null:
		printerr("RESULT: 1 FAILURES"); get_tree().quit(1); return

	# --- OFF: a mortal player gets none of it ---
	p.god_mode = false
	# levitation is universal now, so the mortal difference is that it is PAID
	# for in mana rather than being unavailable
	check("off: levitation is available but costs mana", p.has_flight() and p.levitate_mana_rate() >= 1.0,
		"rate=%.1f/s" % p.levitate_mana_rate())
	check("off: no wings", p.wings_left == null or not p.wings_left.visible)
	var hp0: int = p.health
	p.invincible = false
	p.monarch_iframes_until = 0.0
	p.take_damage(7)
	check("off: damage lands", p.health < hp0, "%d -> %d" % [hp0, p.health])

	# --- the button ---
	panel._toggle_god()
	await get_tree().process_frame
	check("button turns god mode ON", p.god_mode)
	check("button label reads GOD MODE: ON",
		panel.god_button != null and panel.god_button.text == "GOD MODE: ON",
		panel.god_button.text if panel.god_button else "?")

	# --- 1) untouchable ---
	p.health = p.get_max_health()
	p.invincible = false
	p.monarch_iframes_until = 0.0
	var hp1: int = p.health
	p.take_damage(9999)
	check("on: nothing can hurt you", p.health == hp1 and not p.is_dead,
		"%d -> %d dead=%s" % [hp1, p.health, p.is_dead])

	# --- 2) T super dash, through the real input path ---
	check("on: no blink relic equipped (so it's god mode granting it)",
		not p.has_relic_power("blink"))
	# is_action_just_pressed is true for ONE frame, and the dash is short, so
	# sample across the window rather than betting on a single frame landing
	p.is_dashing = false
	p.last_dash_time = 0.0
	var x0: float = p.global_position.x
	var saw_dash := false
	var top_speed := 0.0
	Input.action_press("admin_dash")
	for i in range(30):
		await get_tree().physics_frame
		if i == 1:
			Input.action_release("admin_dash")
		if p.is_dashing:
			saw_dash = true
		top_speed = maxf(top_speed, absf(p.velocity.x))
	check("on: T triggers the super dash", saw_dash)
	check("on: dash hits ADMIN speed (%.0f)" % top_speed,
		top_speed >= p.ADMIN_DASH_SPEED - 1.0,
		"%.0f vs %.0f" % [top_speed, p.ADMIN_DASH_SPEED])
	check("on: the dash actually moves you", absf(p.global_position.x - x0) > 100.0,
		"moved %.0fpx" % absf(p.global_position.x - x0))

	# --- 3) flight + wings ---
	check("on: flight granted without the Aetherwing", p.has_flight())
	check("on: fall immunity granted (won't die on landing)", p.has_fall_immunity())
	await get_tree().physics_frame
	check("on: wings are visible", p.wings_left != null and p.wings_left.visible)
	# fly: hold Space off the ground. Levitation costs mana now -- but god mode
	# must never pay it, the whole point is crossing the map freely.
	p.global_position.y -= 300.0
	p.mana = p.get_max_mana()
	var mana0: float = p.mana
	Input.action_press("jump")
	var rose := false
	var y0: float = p.global_position.y
	for i in range(30):
		await get_tree().physics_frame
		if p.global_position.y < y0 - 5.0:
			rose = true
	Input.action_release("jump")
	check("on: holding Space lifts you", rose, "y %.0f -> %.0f" % [y0, p.global_position.y])
	check("on: levitating costs god mode no mana", absf(p.mana - mana0) < 0.01,
		"%.1f -> %.1f" % [mana0, p.mana])

	# --- back off again ---
	panel._toggle_god()
	await get_tree().process_frame
	check("button turns god mode OFF", not p.god_mode)
	# and now that god mode is off, the same hold visibly drains the pool
	p.global_position.y -= 260.0
	p.mana = p.get_max_mana()
	var mortal_mana0: float = p.mana
	Input.action_press("jump")
	for i in range(20):
		await get_tree().physics_frame
	Input.action_release("jump")
	check("off again: levitating now burns mana", p.mana < mortal_mana0,
		"%.1f -> %.1f" % [mortal_mana0, p.mana])
	check("off again: label reads OFF",
		panel.god_button.text == "GOD MODE: OFF", panel.god_button.text)

	# ---- the console rides everywhere + god mode carries the doors ----
	check("the admin console is instanced in the dungeon scene too",
		FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text().contains("admin_panel.gd"))
	var g_saved_skills = GameState.unlocked_skills.duplicate(true)
	GameState.unlocked_skills = []
	p.god_mode = true
	check("god mode grants Z: the doors, free, drainless",
		p.has_portal_skill() and p.portal_open_cost() == 0.0 and p.portal_drain_per_second() == 0.0)
	p.god_mode = false
	check("mortals still need the skill", not p.has_portal_skill())
	GameState.unlocked_skills = g_saved_skills

	# ---- How to Play: the deep game, taught ----
	var htp := FileAccess.open("res://how_to_play.gd", FileAccess.READ).get_as_text()
	check("How to Play exists, teaches the laws, and closes like any window",
		htp.contains("Distance is ignorance") and htp.contains("Hope is the resource")
		and htp.contains("esc_window") and htp.contains("func esc_close"))
	check("...and the pause menu carries it in both scenes",
		FileAccess.open("res://pause_menu.gd", FileAccess.READ).get_as_text().contains("HowToPlayButton"))
	check("the MAIN MENU opens the same page (one source of truth, no drift)",
		FileAccess.open("res://main_menu.gd", FileAccess.READ).get_as_text().contains("how_to_play.gd"))
	check("...and the page can always be closed, menu or not",
		htp.contains("close_btn.pressed.connect(esc_close)"))
	# autosave: a crash should cost minutes, never a session
	var gauto := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the world writes itself down periodically",
		gauto.contains("AUTOSAVE_INTERVAL_SECONDS") and gauto.contains("_autosave_accum >= AUTOSAVE_INTERVAL_SECONDS"))
	check("...at milestones too: a cleared floor and coming home",
		FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text().contains("GameState.autosave(\"floor")
		and FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().contains("home safe"))
	check("...never over a corpse, never from a test harness",
		gauto.contains("player.is_dead:\n\t\treturn") and gauto.contains('OS.has_environment("MONARCH_TEST")'))
	check("...its keys are the REAL bindings (Z rifts, L log, H hands-on)",
		htp.contains("[\"Z\",") and htp.contains("Riftweaving") and htp.contains("VILLAGE LOG")
		and htp.contains("hands-on key"))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
