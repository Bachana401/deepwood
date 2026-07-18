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

func _count_labels(parent: Node) -> int:
	if parent == null or not is_instance_valid(parent):
		return 0
	var n := 0
	for c in parent.get_children():
		if c is Label:
			n += 1
	return n

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

	# ---- the exact fight that was reported: Frost Monarch, floor 10 ----
	# base 780 HP x the floor-10 multiplier (1 + 9*0.15 = 2.35) = ~1833, and the
	# stagger threshold is 6% of THAT -- so landing a hit at all demanded ~110
	# damage in a single blow. Most mythic weapons swing for well under that, so
	# every blow was absorbed and the fight was unwinnable by design accident.
	var floor10_hp: int = int(780 * (1.0 + 9 * 0.15))
	boss.has_stagger_armour = true
	boss.is_dead = false
	boss.max_health = floor10_hp
	boss.health = floor10_hp
	boss._guard_chip = 0.0
	var need_single: int = int(floor10_hp * boss.STAGGER_HEAVY_FRACTION)
	check("floor-10 stagger demanded a huge single blow (that was the bug)",
		need_single > 100, "%d damage in ONE hit" % need_single)
	# a realistic mythic swing -- Ragnarok-ish base 18, skill mults, a crit
	var mythic_hit := 55
	check("a realistic mythic swing is BELOW that threshold", mythic_hit < need_single,
		"%d < %d" % [mythic_hit, need_single])
	var hits := 0
	while boss.health == floor10_hp and hits < 30:
		boss.take_damage(mythic_hit)
		hits += 1
	check("but it now cracks the guard in a few swings", boss.health < floor10_hp,
		"%d swings" % hits)
	check("and that is a reasonable number, not a war of attrition", hits <= 4,
		"%d swings to first damage" % hits)

	# ---- a block must SAY why, or it reads as a bug ----
	check("boss can label a block", boss.has_method("_spawn_block_label"))
	# (FloatingText is a static utility class -- probe the source, not an instance)
	var ft := FileAccess.open("res://floating_text.gd", FileAccess.READ)
	var ft_src := ft.get_as_text() if ft != null else ""
	if ft != null: ft.close()
	check("floating text supports words, not just numbers",
		ft_src.contains("func spawn_word("))
	# the label must actually appear in the world when a hit is absorbed
	boss.has_stagger_armour = true
	boss.health = 1000
	boss.max_health = 1000
	boss._guard_chip = 0.0
	var labels_before := _count_labels(boss.get_parent())
	boss.take_damage(1)                     # absorbed
	await get_tree().process_frame
	check("an absorbed hit spawns a visible label",
		_count_labels(boss.get_parent()) > labels_before,
		"%d -> %d" % [labels_before, _count_labels(boss.get_parent())])

	# a dead boss reports nothing landed (so no number prints on a corpse)
	boss.is_dead = true
	check("hitting a dead boss reports no landing", boss.take_damage(100) == false)

	boss.queue_free()
	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
