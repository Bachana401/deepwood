extends Node

# Headless functional test for the Shadow Monarch OP powers (task #7).
# Boots main.tscn, drives the player to stage 6/7, and exercises:
# Shadowstep i-frames, Rise-Shade (cap 2), The Long Dark, the 7/7 true form
# (scale x1.6, shade cap 4, permanent shades), and a shadow nova tick.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _enter_tree() -> void:
	printerr("T_enter_tree")

func _ready() -> void:
	printerr("T_ready_start")
	# launched by the main_menu.gd MONARCH_TEST hook -- the game scene is
	# loading underneath us; wait for the player to appear
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	printerr("T_frames_done")
	check("player exists", p != null)
	if p == null:
		get_tree().quit(1)
		return
	# the opening plea pauses the whole tree (dialogue_box.gd) -- skip it, or
	# the player's _physics_process (and monarch_tick) never runs
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish()
				break
	check("tree unpaused (opening plea skipped)", not get_tree().paused)

	# --- stage math ---
	GameState.player_level = 100
	GameState.monarch_stage_announced = 7   # no toast spam
	check("stage 7 at level 100", GameState.monarch_stage() == 7)
	# hold a villager alive so the true form stays hidden for the first half
	GameState.rescued_villagers.append({"name": "TestSoul"})
	check("true form hidden while a villager lives", not GameState.monarch_true_form())

	# --- Shadowstep (3/7+): dash i-frames ---
	p.has_dash = true
	p.global_position = Vector2(200, 0)
	p.perform_dash(1)
	var now = Time.get_ticks_msec() / 1000.0
	check("dash grants i-frames", p.monarch_iframes_until > now)
	var hp0 = p.health
	p.take_damage(25)
	check("hit during Shadowstep ignored", p.health == hp0, "hp %d -> %d" % [hp0, p.health])
	await get_tree().create_timer(0.5).timeout

	# --- Rise, Shade (5/7+): cap 2 below true form ---
	for i in range(20):
		p.on_enemy_killed()
	p.monarch_shades = p.monarch_shades.filter(func(s): return is_instance_valid(s))
	check("shade cap 2 without true form", p.monarch_shades.size() == 2, "got %d" % p.monarch_shades.size())
	await get_tree().process_frame
	var sh = p.monarch_shades[0] if p.monarch_shades.size() > 0 else null
	check("shade expires (temporary)", sh != null and sh.expires_at > 0.0)

	# --- The Long Dark (6/7+): lethal hit -> shadow-form, not death ---
	p.monarch_iframes_until = 0.0
	p.invincible = false
	p.health = 3
	p.take_damage(99999)
	check("Long Dark: survived lethal hit", not p.is_dead and p.health >= 1, "dead=%s hp=%d" % [p.is_dead, p.health])
	check("Long Dark: shadow-form invulnerable", p.invincible)
	check("Long Dark: cooldown armed", p.monarch_long_dark_ready_at > Time.get_ticks_msec() / 1000.0)

	# --- 7/7 true form: manifests when no villager is left ---
	var scale_before: Vector2 = p.base_scale
	GameState.rescued_villagers.clear()
	for i in range(20):
		await get_tree().process_frame
	check("true form manifests", p.monarch_true_form_active)
	check("god-form scale x1.6", is_equal_approx(p.base_scale.x, scale_before.x * 1.6),
		"%.3f -> %.3f" % [scale_before.x, p.base_scale.x])
	for i in range(6):
		p.on_enemy_killed()
	p.monarch_shades = p.monarch_shades.filter(func(s): return is_instance_valid(s))
	check("shade cap 4 in true form", p.monarch_shades.size() == 4, "got %d" % p.monarch_shades.size())
	var perm = p.monarch_shades.back()
	check("true-form shades permanent", perm != null and perm.expires_at == 0.0)

	# --- nova tick: force one, must not error even with no target in range ---
	p.monarch_nova_accum = 99.0
	await get_tree().process_frame
	await get_tree().process_frame
	printerr("nova ticked without error")

	# --- withdraw: villager back -> the god-form recedes ---
	GameState.rescued_villagers.append({"name": "TestSoul2"})
	for i in range(20):
		await get_tree().process_frame
	check("true form withdraws", not p.monarch_true_form_active)
	check("scale restored", is_equal_approx(p.base_scale.x, scale_before.x),
		"%.3f vs %.3f" % [p.base_scale.x, scale_before.x])

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
