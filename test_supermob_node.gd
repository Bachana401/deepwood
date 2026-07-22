extends Node
# SUPER-MOBS (dev report 2026-07-21: "no super mobs"). An elite is now a champion
# you see coming and must play around, NOT a stat wall. This proves the promises:
#   - it dresses up on spawn (aura + crown) so it reads across the room,
#   - its signature SLAM hurts but can NEVER one-shot (the forever boss rule),
#   - and the slam is a GROUND wave -- leap above it and it whiffs.

var fails := 0

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(30):
		keep_running()
		await get_tree().process_frame

	var was_god: bool = p.god_mode
	p.god_mode = false
	var maxhp: int = p.get_max_health()

	# ---- spawn an elite the way the dungeon does: behavior BEFORE the tree ----
	var e = load("res://enemy.tscn").instantiate()
	e.weapon_type = "sword"
	e.wave_hp_multiplier = 6.0        # a deep-floor elite: fat multipliers
	e.wave_damage_multiplier = 4.0
	e.set_behavior("shield", true)
	get_tree().current_scene.add_child(e)
	e.global_position = p.global_position + Vector2(300, 0)
	for i in range(5):
		await get_tree().process_frame

	# ---- 1. it dresses up so you SEE it ----
	var has_glow := false
	var has_crown := false
	for c in e.get_children():
		if c is Sprite2D and c.material is CanvasItemMaterial:
			has_glow = true
		if c is Polygon2D and c.color.r > 0.9 and c.color.g > 0.7 and c.color.b < 0.5:
			has_crown = true
	check("an elite wears a glowing aura", has_glow)
	check("...and a champion's crown", has_crown)
	check("...and is visibly bigger", e.scale.x >= 1.25, "scale %.2f" % e.scale.x)

	# ---- 2. the slam hurts but NEVER one-shots ----
	e.global_position = p.global_position + Vector2(40, 0)   # right beside, same height
	p.health = maxhp
	e._elite_shockwave()
	for i in range(3):
		await get_tree().process_frame
	var taken: int = maxhp - p.health
	check("the elite slam lands on a grounded player next to it", taken > 0, "took %d" % taken)
	check("...but it can NEVER one-shot (capped share of max HP)",
		p.health > 0 and taken <= int(round(maxhp * 0.46)),
		"took %d of %d max" % [taken, maxhp])

	# ---- 3. leap OVER it and it whiffs ----
	p.health = maxhp
	e.global_position = p.global_position + Vector2(40, 120)   # mob 120px BELOW: player is airborne over it
	e._elite_shockwave()
	for i in range(3):
		await get_tree().process_frame
	check("a leap clears the shockwave (it is a ground wave)", p.health == maxhp,
		"took %d while airborne" % (maxhp - p.health))

	e.queue_free()
	p.god_mode = was_god
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
