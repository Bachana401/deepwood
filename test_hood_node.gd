extends Node

# Verifies the hood rises at 5/7 and nothing else about the hero changes.
# The base art is protected by a standing order, so the first thing this checks
# is that the bare-headed art is still what he wears below stage 5.

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
	GameState.monarch_stage_announced = 7   # no toast spam
	# A fresh run has NO rescued villagers, which is itself the true-form
	# condition -- so hold one alive or the god-form engages the moment we
	# jump to level 100 and there's nothing left to measure.
	GameState.rescued_villagers.append({"name": "TestSoul"})

	check("hooded art is present", p._hooded_art_present())

	# --- below 5/7 he is bare-headed ---
	GameState.player_level = 45          # 4/7
	for i in range(6):
		await get_tree().process_frame
	check("4/7 stage is 4", GameState.monarch_stage() == 4)
	check("4/7 wears the BASE art", not p._hooded, "prefix %s" % p._art_prefix)
	var base_scale_4: Vector2 = p.base_scale
	var anim_4: String = p.body_anim.animation

	# --- 5/7: the hood goes up ---
	GameState.player_level = 60          # 5/7
	for i in range(6):
		await get_tree().process_frame
	check("5/7 stage is 5", GameState.monarch_stage() == 5)
	check("5/7 pulls the hood up", p._hooded, "prefix %s" % p._art_prefix)
	check("5/7 uses the hooded art path", p._art_prefix == p.HOODED_ART)
	check("hood keeps playing the same animation", p.body_anim.animation == anim_4,
		"%s -> %s" % [anim_4, p.body_anim.animation])
	# the hood must ADD height, not shrink him into the same silhouette
	var im: Image = p.body_anim.sprite_frames.get_frame_texture("idle", 0).get_image()
	var drawn_h: float = im.get_height() * p.base_scale.y
	check("hooded hero stands taller than bare-headed (%.1fpx)" % drawn_h,
		drawn_h > p.SPRITE_TARGET_HEIGHT and drawn_h < p.SPRITE_TARGET_HEIGHT * 1.35,
		"%.1f vs base %.1f" % [drawn_h, p.SPRITE_TARGET_HEIGHT])
	check("hooded frames actually loaded", p.body_anim.sprite_frames.get_frame_count("idle") == 8,
		"idle frames %d" % p.body_anim.sprite_frames.get_frame_count("idle"))
	check("walk/jump/fall are real hooded anims, not idle fallback",
		p.real_anims.get("walk", false) and p.real_anims.get("jump", false) and p.real_anims.get("fall", false),
		str(p.real_anims))
	# he must not change size when the hood goes up
	check("hood does not resize the hero", absf(p.base_scale.x - base_scale_4.x) < 0.06,
		"%.3f -> %.3f" % [base_scale_4.x, p.base_scale.x])

	# --- 6/7 and 7/7 stay hooded ---
	GameState.player_level = 80          # 6/7
	for i in range(6):
		await get_tree().process_frame
	check("6/7 stays hooded", p._hooded and GameState.monarch_stage() == 6)
	GameState.player_level = 100         # 7/7
	for i in range(6):
		await get_tree().process_frame
	check("7/7 stays hooded", p._hooded and GameState.monarch_stage() == 7)

	# --- the true form still scales him, hood and all ---
	var pre: Vector2 = p.base_scale
	GameState.rescued_villagers.clear()
	for i in range(20):
		await get_tree().process_frame
	check("true form still doubles the hooded hero", p.monarch_true_form_active
		and absf(p.base_scale.x - pre.x * 1.6) < 0.02,
		"%.3f -> %.3f" % [pre.x, p.base_scale.x])

	# --- and it goes back down if the stage is taken away (admin/testing) ---
	GameState.rescued_villagers.append({"name": "T"})
	GameState.player_level = 30          # 3/7
	for i in range(10):
		await get_tree().process_frame
	check("hood comes back down below 5/7", not p._hooded and p._art_prefix == p.BASE_ART)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
