extends Node

# Reported from play: "I hit the level 5 boss with a mythic, I SEE damage
# numbers, but his HP bar never moves."
#
# Both halves of that were real. The Frost Monarch has stagger_armour, which
# absorbed any blow under 6% of its max HP -- and the player printed a damage
# number regardless, so the feedback actively lied about what was happening.
# Worse, the threshold is a share of the boss's MAX HP, which grows with floor
# level while a fast weapon's damage does not, so those bosses trended towards
# being unkillable by half the roster.
#
# Guards: take_damage reports whether the blow landed, and light hits now pack
# into the guard until it cracks.

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

	var host := Node2D.new()
	get_tree().root.add_child(host)
	var boss = load("res://boss.tscn").instantiate()
	host.add_child(boss)
	await get_tree().process_frame

	# a plain boss reports that a blow landed, so a number may be shown
	boss.has_stagger_armour = false
	boss.is_dead = false
	boss.max_health = 1000
	boss.health = 1000
	var landed = boss.take_damage(50)
	check("take_damage reports a landed blow", landed == true, str(landed))
	check("and the health actually dropped", boss.health < 1000, "hp=%d" % boss.health)

	# ---- the reported bug: a guarded boss absorbing chip damage ----
	boss.has_stagger_armour = true
	boss.max_health = 1000
	boss.health = 1000
	boss._guard_chip = 0.0
	var heavy: int = int(1000 * boss.STAGGER_HEAVY_FRACTION)   # 60
	var light: int = maxi(1, heavy / 6)                        # a fast weapon's hit
	var absorbed_reported_damage := false
	var hp_before: int = boss.health
	var first = boss.take_damage(light)
	if first == true and boss.health == hp_before:
		absorbed_reported_damage = true
	check("an absorbed blow reports that it did NOT land", first == false, str(first))
	check("an absorbed blow never claims damage it didn't do", not absorbed_reported_damage)
	check("and the boss's health is untouched by it", boss.health == hp_before,
		"hp %d -> %d" % [hp_before, boss.health])

	# ...but the chip is remembered, so a fast weapon gets there by volume
	var swings := 1
	while boss.health == hp_before and swings < 40:
		boss.take_damage(light)
		swings += 1
	check("enough light hits DO break the guard (fast weapons aren't useless)",
		boss.health < hp_before, "%d swings, hp %d -> %d" % [swings, hp_before, boss.health])
	check("the guard breaks in a sane number of hits", swings <= 12, "%d swings" % swings)

	# a heavy blow still breaks it outright, first try
	boss.health = 1000
	boss._guard_chip = 0.0
	boss.take_damage(heavy + 1)
	check("a heavy blow still breaks the guard immediately", boss.health < 1000,
		"hp=%d" % boss.health)

	# a dead boss reports nothing landed (so no number prints on a corpse)
	boss.is_dead = true
	check("hitting a dead boss reports no landing", boss.take_damage(100) == false)

	boss.queue_free()
	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
