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
	# From 5/7 he must stand like a sovereign, not like the brawler he was.
	# The fists-up idle belongs to the man below 5/7 only.
	# (idle only reads true once he's actually standing on the ground)
	# wait for him to land AND for the landing squash to finish settling
	for i in range(300):
		await get_tree().physics_frame
		if p.is_on_floor() and absf(p.velocity.x) < 1.0 and p.land_timer <= 0.0:
			break
	check("player is grounded and settled", p.is_on_floor() and p.land_timer <= 0.0,
		"state '%s'" % p.body_anim.animation)
	check("5/7 stands like a MONARCH (not the old fists-up idle)",
		p.body_anim.animation == "monarchidle",
		"playing '%s'" % p.body_anim.animation)
	check("...and it's real drawn art, not an idle fallback",
		p.real_anims.get("monarchidle", false))
	# and below 5/7 he must go back to the brawler stance
	GameState.player_level = 45
	for i in range(30):
		await get_tree().physics_frame
	check("4/7 stands like the brawler he was ('idle')",
		p.body_anim.animation == "idle", "playing '%s'" % p.body_anim.animation)
	GameState.player_level = 60
	for i in range(10):
		await get_tree().physics_frame
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
	# base_scale is no longer "the man's scale x N" -- the ascended sprite has its
	# own proportions and derives its own scale, so assert the thing that
	# actually matters: how tall he DRAWS.
	var tfi: Image = p.body_anim.sprite_frames.get_frame_texture(p.body_anim.animation, 0).get_image()
	var tfh: float = tfi.get_height() * p.base_scale.y
	check("true form towers (%.0fpx = %.1fx the man)" % [tfh, tfh / p.SPRITE_TARGET_HEIGHT],
		p.monarch_true_form_active and tfh > p.SPRITE_TARGET_HEIGHT * 1.4,
		"drew %.1fpx, man is %.1f" % [tfh, p.SPRITE_TARGET_HEIGHT])

	# --- and it goes back down if the stage is taken away (admin/testing) ---
	GameState.rescued_villagers.append({"name": "T"})
	GameState.player_level = 30          # 3/7
	for i in range(10):
		await get_tree().process_frame
	check("hood comes back down below 5/7", not p._hooded and p._art_prefix == p.BASE_ART)

	# --- 7/7: he stops wearing the man entirely ---
	GameState.player_level = 100
	GameState.rescued_villagers.clear()
	for i in range(30):
		await get_tree().physics_frame
	check("ascended art is present", p._ascended_art_present())
	check("7/7 wears the ASCENDED skin", p._ascended and p._art_prefix == p.ASCENDED_ART,
		"prefix %s" % p._art_prefix)
	# he must TOWER: measure the pixels actually drawn, not the flag
	var ai: Image = p.body_anim.sprite_frames.get_frame_texture("monarchidle", 0).get_image()
	var ah: float = ai.get_height() * p.base_scale.y
	var aw: float = ai.get_width() * p.base_scale.x
	check("god-form TOWERS at %.0fpx (%.1fx the man)" % [ah, ah / p.SPRITE_TARGET_HEIGHT],
		absf(ah - p.SPRITE_TARGET_HEIGHT * p.TRUE_FORM_SCALE) < 2.0,
		"%.1f vs target %.1f" % [ah, p.SPRITE_TARGET_HEIGHT * p.TRUE_FORM_SCALE])
	check("...and is TALLER than wide (%.0fx%.0f)" % [aw, ah], ah > aw,
		"tall must beat wide")
	# and back down: the god recedes to the man
	GameState.rescued_villagers.append({"name": "T2"})
	for i in range(30):
		await get_tree().physics_frame
	check("god recedes -> back to the hooded man", not p._ascended and p._art_prefix == p.HOODED_ART,
		"prefix %s" % p._art_prefix)

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
