extends Node

# REAL HITS, MEASURED (2026-07-30).
#
# test_weapondps_node computes effective dps as nominal x a DECLARED
# hits-per-use factor. Those declarations are hand-written estimates, and one of
# them was simply wrong in a way nothing could catch: The Last Word claimed 4.0,
# which made it read as the second-strongest Monarch in the game, while in play
# it landed one or two hits and the dev reported it as weak. The blades rode a
# thin ring that swept past a target once; the number said otherwise and the
# audit believed the number.
#
# So: fire the weapon at a real dummy, count real take_damage calls, and hold
# the DECLARATION against what actually happened. A guess that cannot be checked
# is not a measurement, and every "some are too weak, some are too OP" complaint
# this campaign traces back to one.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)
func say(t: String) -> void: printerr(t)

class Counter extends StaticBody2D:
	var health := 99999999
	var max_health := 99999999
	var is_dead := false
	var hits := 0
	var total := 0
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
		total += n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

# Every weapon is probed at SEVERAL distances and scored on its best. A single
# distance is not a measurement: a verb with a range band -- pillars that come
# up ahead of you, a lob with an arc -- reads as stone dead at the one distance
# that happens to fall between its teeth, and I would have "fixed" a weapon
# that was working.
const PROBE_IDS := ["wpn_lastword", "wpn_griefcrown", "wpn_unbentcolumn",
	"wpn_worldsgrief", "wpn_rumor", "wpn_skymeasure",
	# the two wands that shipped dealing literally zero -- kept here permanently
	# as the regression guard, since "it has a case label now" is not the same
	# claim as "it damages a body"
	"wpn_inkbook", "wpn_wakebook",
	# every wand reworked off the shared icicle stays here permanently. A new
	# verb that compiles, dispatches and declares a hit count can still land
	# nothing -- that was true of three weapons before this probe existed.
	"wpn_chalkwand", "wpn_tallowwand", "wpn_stubwand",
	"wpn_brookwand", "wpn_mosswand"]
const PROBE_RANGES := [90.0, 170.0, 280.0]

func _ready() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		check("player found", false); _done(); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	say("\n=== MEASURED HITS ON ONE BODY (declared vs real) ===")
	var wrong := []
	for id in PROBE_IDS:
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			continue
		var behavior := ""
		for row in WeaponRoster.ROWS:
			if str(row[0]) == id:
				behavior = str(row[4])
				break
		var best := 0
		var best_dmg := 0
		var at_range := 0.0
		var per_range := []
		for dist in PROBE_RANGES:
			p.inventory.add_item(id, 1)
			p.wield_weapon(id)
			p.mana = p.get_max_mana()
			p.health = p.get_max_health()
			# PUT THE DUMMY WHERE THE WEAPON WILL ACTUALLY FIRE.
			# The obvious approach -- warp the mouse onto the target -- is a
			# NO-OP under --headless, because there is no window for the pointer
			# to move in. get_aim_direction() then returns a default that has
			# nothing to do with the dummy: measured (-0.40, -0.92), i.e. up and
			# to the left, while the dummy sat directly right. Every
			# aim-dependent weapon fired into empty space and read as DEAD, and
			# I reported three healthy wands as broken on the strength of it.
			# Reading the aim and placing the target along it measures the
			# weapon instead of the harness.
			var aim: Vector2 = p.get_aim_direction()
			if aim.length() < 0.01:
				aim = Vector2.RIGHT
			var dummy := Counter.new()
			dummy.add_to_group("course_enemy")
			stage.add_child(dummy)
			# TWO dummies' worth of coverage from one: place it along the aim,
			# but at the player's OWN height. A purely aim-following placement
			# puts the target in mid-air, which is invisible to a floor-hugging
			# weapon -- the Brookwand runs along the ground by design and read as
			# stone dead against a target hovering above it. Keeping the target
			# at ground level while offset along the aim's horizontal serves the
			# thrown, the fired and the poured alike.
			var off: Vector2 = aim.normalized() * dist
			off.y = clampf(off.y, -40.0, 40.0)
			dummy.global_position = (p as Node2D).global_position + off
			await get_tree().process_frame
			await get_tree().process_frame
			p.attack_cooldown_remaining = 0.0
			p.perform_attack()
			# Let the whole verb play out. 1.8s was too short for the slow ones:
			# the Mosslight spore DRIFTS for up to 2.4s before it even plants,
			# so its patch had barely appeared when the window closed and a
			# 5-second zone measured as a single tap. A zone weapon has to be
			# watched for as long as it lives or the number is about the clock.
			await get_tree().create_timer(4.0, true).timeout
			per_range.append("%dpx:%d" % [int(dist), dummy.hits])
			if dummy.hits > best:
				best = dummy.hits
				best_dmg = dummy.total
				at_range = dist
			dummy.queue_free()
			await get_tree().process_frame

		var declared: float = _declared(behavior)
		say("  %-22s %-14s declared %.1f   BEST %d @%dpx (%d dmg)   [%s]"
			% [str(def.get("name", id)), behavior, declared, best, int(at_range),
				best_dmg, ", ".join(per_range)])
		# a verb that lands nothing at ANY of three distances is broken outright
		check("%s connects at some range" % str(def.get("name", id)), best > 0,
			"nothing at 90, 170 or 280px")
		# and the declaration must be in the neighbourhood of the truth. Wide on
		# purpose -- this is here to catch a claim of 4.0 against a reality of 1,
		# not to police a 20% drift.
		if best > 0 and (declared > float(best) * 2.2 or declared < float(best) * 0.4):
			wrong.append("%s: declared %.1f, measured %d"
				% [str(def.get("name", id)), declared, best])

	check("every declared hits-per-use is in the neighbourhood of reality",
		wrong.is_empty(), "; ".join(wrong))
	_done()

# read the audit's own table so the two can never drift apart
func _declared(behavior: String) -> float:
	var src := FileAccess.get_file_as_string("res://test_weapondps_node.gd")
	var re := RegEx.new()
	re.compile('"%s":\\s*([0-9.]+)' % behavior)
	var m := re.search(src)
	return 1.0 if m == null else float(m.get_string(1))

func _done() -> void:
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
