extends Node

# THE ERUPTION MUST SURVIVE THE CROWD (2026-08-07).
#
# A whole family of flagship verbs deals its damage BY HAND, a beat after the
# cast, from a node that stands in front of the caster: the Unbent Column's
# colonnade, Throne of Strings' pluck, the Staff That Measures the Sky's columns
# (and their kin -- the World-Anvil's tolls, Stormsliver's fork, What the Sky
# Charges' storm). Every one of those nodes is an Area2D, and it was left
# MONITORING. So when an enemy stood where the node spawned -- exactly the case
# in a real fight, a crowd at your feet -- body_entered fired, paid ONE stray
# hit, and the non-pierce default arm FREED the node before the eruption ran.
# The dev's report, verbatim: "weapon unbent column's projectiles or behavior are
# not really affecting enemies, some of them are some of them are not." Enemies at
# range saw the full eruption; a crowd at the spawn ate the projectile and the
# pillars never came up.
#
# The guard: seat a CROWDER on the exact spawn (the body that used to consume the
# cast) and FAR WITNESSES out in the eruption's zone, past melee reach. Pre-fix
# the witnesses take nothing; post-fix the eruption reaches them. A straight
# Orchard Bow shot is the POSITIVE CONTROL -- without it, a witness reading 0
# could mean the harness is broken rather than the weapon.
#
# These three verbs FIRE AFTER A DELAY (0.14s / 0.1s / 0.42s), so a freed node
# means a witness reads a clean zero -- a crisp, non-flaky assertion. The sibling
# verbs that strike on the first frame (toll/fork/storm) are fixed by the same
# one line (monitoring=false in their _build_) but cannot be asserted this way
# without racing their own first hit, so they are covered by the hits sweep, not
# here.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)
func say(t: String) -> void: printerr(t)

class Dummy extends StaticBody2D:
	var health := 99999999
	var max_health := 99999999
	var is_dead := false
	var hits := 0
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 64)
		cs.shape = sh
		add_child(cs)
	func take_damage(n: int):
		hits += 1
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

var _player: Node2D = null
var _stage: Node = null

func _dummy(off: Vector2) -> Dummy:
	var d := Dummy.new()
	d.add_to_group("course_enemy")
	_stage.add_child(d)
	d.global_position = _player.global_position + off
	return d

# fire `id` with `aim`, a crowder at `crowd`, witnesses at `wit_offs`; return how
# many DISTINCT witnesses were struck.
func _witnesses_struck(id: String, aim: Vector2, crowd: Vector2, wit_offs: Array) -> int:
	var crowder := _dummy(crowd)
	var wits: Array = []
	for o in wit_offs:
		wits.append(_dummy(o))
	_player.inventory.add_item(id, 1)
	_player.wield_weapon(id)
	_player.set_test_aim(aim)
	_player.mana = _player.get_max_mana()
	_player.health = _player.get_max_health()
	await get_tree().process_frame
	await get_tree().process_frame
	_player.attack_cooldown_remaining = 0.0
	_player.perform_attack()
	await get_tree().create_timer(1.7, true).timeout
	var struck := 0
	for w in wits:
		if (w as Dummy).hits > 0:
			struck += 1
	crowder.queue_free()
	for w in wits:
		w.queue_free()
	await get_tree().process_frame
	return struck

# for the PLANTED posts (wisp / candle / coven): one body ON the plant point is
# both the crowder that used to free the node AND the thing the post pays over
# time. Pre-fix it takes one stray hit; post-fix the post survives and pays it
# again and again. Returns that body's hit count.
func _plant_body_hits(id: String) -> int:
	var body := _dummy(Vector2(120, 0))
	_player.inventory.add_item(id, 1)
	_player.wield_weapon(id)
	_player.set_test_aim(Vector2.RIGHT)
	_player.mana = _player.get_max_mana()
	_player.health = _player.get_max_health()
	await get_tree().process_frame
	await get_tree().process_frame
	_player.attack_cooldown_remaining = 0.0
	_player.perform_attack()
	await get_tree().create_timer(1.7, true).timeout
	var h: int = (body as Dummy).hits
	body.queue_free()
	await get_tree().process_frame
	return h

func _ready() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	for i in range(1200):
		await get_tree().process_frame
		var pn := get_tree().get_first_node_in_group("player")
		if pn != null:
			_player = pn as Node2D
			break
	if _player == null:
		check("player found", false); _done(); return
	GameState.opening_done = true
	get_tree().paused = false
	_stage = _player.get_parent()

	say("\n=== ERUPTIONS SURVIVE A CROWD AT THE SPAWN ===")

	# POSITIVE CONTROL: a straight shot must land on a witness, or a 0 below means
	# nothing.
	var pc: int = await _witnesses_struck("wpn_orchardbow", Vector2.RIGHT,
		Vector2(999, 999), [Vector2(200, 0)])
	check("positive control: Orchard Bow strikes a witness", pc > 0,
		"the harness is not registering hits at all")

	# THE UNBENT COLUMN (staff): spawns 70px ahead on the floor; the colonnade
	# marches down the hall. Witnesses on the ground past melee reach.
	var col: int = await _witnesses_struck("wpn_unbentcolumn", Vector2.RIGHT,
		Vector2(70, 0), [Vector2(200, 0), Vector2(280, 0)])
	check("The Unbent Column erupts past a crowder", col > 0,
		"colonnade freed by body_entered before it rose")

	# THRONE OF STRINGS (bow): spawns 40px ahead; the bow shaft flies on-axis, so
	# witnesses sit OFF-axis where only the outer strings reach.
	var harp: int = await _witnesses_struck("wpn_thronestrings", Vector2.RIGHT,
		Vector2(40, 0), [Vector2(200, 60), Vector2(300, -60)])
	check("Throne of Strings plucks past a crowder", harp > 0,
		"harp strings freed before they rang")

	# STAFF THAT MEASURES THE SKY (staff): spawns 120px ahead; the survey columns
	# fall at set x, tall enough to catch a ground body. Witnesses on two columns.
	var meas: int = await _witnesses_struck("wpn_skymeasure", Vector2.RIGHT,
		Vector2(120, 0), [Vector2(180, 0), Vector2(300, 0)])
	check("Staff That Measures the Sky lands past a crowder", meas > 0,
		"survey columns freed before they fell")

	# THE COVEN'S LEDGER (wand): a planted ring that ticks over time -- the post
	# variant of the same premature-free. A body ON the plant point should be paid
	# again and again, not once. (Measured ~10 hits in 2s; >=2 is a wide margin and
	# stands in for its siblings Wisp Warden and Candlekeeper, which share the tick.)
	var coven: int = await _plant_body_hits("wpn_covenbook")
	check("The Coven's Ledger keeps ticking past a crowder", coven >= 2,
		"planted ring freed after one stray hit (got %d)" % coven)

	_done()

func _done() -> void:
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
