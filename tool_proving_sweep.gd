extends Node

# THE PROVING SWEEP (dev, 2026-07-30: "you have to test everything not me, i
# can't test 350 weapons").
#
# The Proving Ground answers every question about ONE weapon while you stand
# and watch it. This runs the same experiment on ALL OF THEM and hands back a
# table, so the dev's job is reading a verdict instead of swinging 350 times.
#
# It measures what the arena panel shows: reach, how many bodies it touched,
# hits, damage, dps, what it costs, whether it channels, and its class -- then
# FLAGS the ones that do not fit, which is the only part anyone should have to
# read.
#
# PLACEMENT. This used to READ THE REAL CURSOR to find the aim, and that single
# choice cost three wrong answers headless -- with no mouse the vector points up
# and to the left, so every aim-following weapon fired into empty space and read
# as dead -- and windowed it fought the dev for their own mouse, firing wherever
# their hand happened to be while missing the marks it had just placed.
#
# THE TEST NOW OWNS THE AIM (player.set_test_aim): flat and to the right, marks
# laid on that same line. Nothing here depends on where anybody is pointing, so
# the dev can use their PC while this runs.
#
# The near ring sits at 45px, inside melee's own reach, so a sword is judged
# where a sword can actually swing.

const RINGS := [45.0, 150.0, 280.0]
const WATCH := 2.4           # seconds of firing per weapon
const CHANNELLED := ["prism_converge", "beam_channel", "soul_stream"]

func say(t: String) -> void: printerr(t)

class Mark extends StaticBody2D:
	var health := 999999999
	var max_health := 999999999
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
		say("ABORTED: no player"); get_tree().quit(0); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	var rows := []
	say("\n=== THE PROVING SWEEP: %d weapons ===" % WeaponRoster.ROWS.size())
	# SWEEP_TIER=8 re-runs one tier in a minute instead of the whole roster in
	# fifteen -- which is what you want when you are chasing one finding.
	var only_tier := 0
	var env_tier := OS.get_environment("SWEEP_TIER")
	if env_tier != "":
		only_tier = int(env_tier)
	for row in WeaponRoster.ROWS:
		if only_tier > 0 and int(row[3]) != only_tier:
			continue
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			say("  [skipped: no def] %s" % id)
			continue
		var special: Dictionary = def.get("special", {})
		var stype := str(special.get("type", ""))

		p.inventory.add_item(id, 1)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		p.health = p.get_max_health()
		var mana_before: float = float(p.mana)

		p.set_test_aim(Vector2.RIGHT)
		var aim := Vector2.RIGHT
		var marks := []
		for r in RINGS:
			var m := Mark.new()
			m.add_to_group("course_enemy")
			stage.add_child(m)
			m.global_position = (p as Node2D).global_position + aim.normalized() * r
			marks.append(m)
		await get_tree().process_frame
		await get_tree().process_frame

		# HOLD THE TRIGGER -- and let the weapon's OWN COOLDOWN rule the rate.
		#
		# The first cut of this zeroed attack_cooldown_remaining before every
		# call, which fires every 0.12s no matter what the weapon's cooldown
		# says. That is not a held trigger, it is a machine gun, and it reported
		# A Cut Across the World at 8,275 dps -- a number I nearly took to the
		# dev as a balance emergency. A fast weapon was being handed the same
		# rate as a slow one and then judged for being fast.
		#
		# perform_attack already returns immediately if the cooldown is unspent,
		# so calling it every frame IS holding the button.
		p.attack_cooldown_remaining = 0.0        # start ready, then earn it
		var t := 0.0
		while t < WATCH:
			p.perform_attack()
			await get_tree().process_frame
			t += get_process_delta_time()

		var struck := 0
		var hits := 0
		var total := 0
		var reach := 0.0
		for i in range(marks.size()):
			var m = marks[i]
			if m.hits > 0:
				struck += 1
				reach = maxf(reach, float(RINGS[i]))
			hits += m.hits
			total += m.total
			m.queue_free()
		var spent: float = maxf(0.0, mana_before - float(p.mana))
		rows.append({
			"name": str(def.get("name", id)), "id": id,
			"cls": str(row[2]), "tier": int(row[3]), "verb": str(row[4]),
			"stype": stype, "reach": reach, "struck": struck,
			"hits": hits, "dmg": total, "dps": float(total) / WATCH,
			"mana": spent, "chan": stype in CHANNELLED,
		})
		await get_tree().process_frame

	# ------- THE VERDICT: only the rows that do not fit are worth reading -----
	var dead := []
	var single := []
	var freebies := []
	for r in rows:
		if int(r["hits"]) == 0:
			dead.append(r)
		elif int(r["struck"]) == 1 and float(r["reach"]) <= RINGS[0]:
			single.append(r)      # never got past the nearest ring
	say("\n--- FULL TABLE (tier, class, verb | reach, targets, hits, dps, mana) ---")
	for r in rows:
		say("  T%d %-7s %-26s %-15s reach %4.0f  tgt %d/3  hits %3d  dps %6.1f  %s%s"
			% [r["tier"], r["cls"], r["name"], r["verb"], r["reach"], r["struck"],
				r["hits"], r["dps"],
				("FREE" if float(r["mana"]) <= 0.0 else "%.0f mana" % float(r["mana"])),
				"  CHANNEL" if r["chan"] else ""])
	say("\n=== NOTHING LANDED (%d) ===" % dead.size())
	for r in dead:
		say("  T%d %-7s %-26s %s" % [r["tier"], r["cls"], r["name"], r["verb"]])
	say("\n=== NEVER REACHED PAST %dpx (%d) ===" % [int(RINGS[0]), single.size()])
	for r in single:
		say("  T%d %-7s %-26s %s" % [r["tier"], r["cls"], r["name"], r["verb"]])
	say("\n=== SWEPT %d weapons ===" % rows.size())
	get_tree().quit(0)
