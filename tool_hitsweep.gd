extends Node

# THE HITS SWEEP (2026-07-30).
#
# test_realhits probes a hand-curated list of ~22 weapons. That list is a
# REGRESSION GUARD -- weapons that have already been caught once and are kept
# under watch. It was never a survey, and the difference matters: the Inkwell of
# Storms was found declaring 3.4 against a measured 1 purely because it happened
# to be on the list. Nothing else in the roster had ever been measured at all.
#
# HITS_PER_USE is keyed by BEHAVIOR, not by weapon, so one representative weapon
# per behavior is COMPLETE coverage of the thing that can lie. 191 behaviors
# instead of 350 weapons, and no blind spots.
#
# This is a survey, not a gate: it always exits 0 and reports the whole spread
# sorted by how badly the declaration misses. Finding out that the numbers are
# mostly honest is a real result; finding six more Inkwells is a better one.

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

const PROBE_RANGES := [90.0, 170.0, 280.0]

# one weapon per behavior, first row wins -- which one does not matter, since
# the declaration being tested belongs to the behavior
func _one_per_behavior() -> Array:
	var seen := {}
	var out := []
	for row in WeaponRoster.ROWS:
		var behavior := str(row[4])
		if seen.has(behavior):
			continue
		seen[behavior] = true
		out.append([str(row[0]), behavior])
	return out

func _declared(behavior: String) -> float:
	var src := FileAccess.get_file_as_string("res://test_weapondps_node.gd")
	var re := RegEx.new()
	re.compile('"%s":\\s*([0-9.]+)' % behavior)
	var m := re.search(src)
	return 1.0 if m == null else float(m.get_string(1))

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
		say("SWEEP ABORTED: no player"); get_tree().quit(0); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	var probes := _one_per_behavior()
	say("\n=== HITS SWEEP: %d behaviors, 3 ranges each ===" % probes.size())
	var rows := []
	for pair in probes:
		var id: String = pair[0]
		var behavior: String = pair[1]
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			continue
		var best := 0
		var per_range := []
		for dist in PROBE_RANGES:
			p.inventory.add_item(id, 1)
			p.wield_weapon(id)
			p.mana = p.get_max_mana()
			p.health = p.get_max_health()
			# aim is READ, never warped: Input.warp_mouse is a no-op headless,
			# and placing the dummy along the real aim vector measures the
			# weapon instead of the harness. Clamped to the player's own height
			# so floor-hugging verbs are not judged against a hovering target.
			var aim: Vector2 = p.get_aim_direction()
			if aim.length() < 0.01:
				aim = Vector2.RIGHT
			var dummy := Counter.new()
			dummy.add_to_group("course_enemy")
			stage.add_child(dummy)
			var off: Vector2 = aim.normalized() * dist
			off.y = clampf(off.y, -40.0, 40.0)
			dummy.global_position = (p as Node2D).global_position + off
			await get_tree().process_frame
			await get_tree().process_frame
			p.attack_cooldown_remaining = 0.0
			p.perform_attack()
			await get_tree().create_timer(2.6, true).timeout
			per_range.append(dummy.hits)
			if dummy.hits > best:
				best = dummy.hits
			dummy.queue_free()
			await get_tree().process_frame
		var declared: float = _declared(behavior)
		# ratio > 1 means the table claims MORE than the weapon delivers
		var ratio := 99.0 if best == 0 else declared / float(best)
		rows.append([ratio, behavior, str(def.get("name", id)), declared, best, per_range])

	rows.sort_custom(func(a, b): return a[0] > b[0])
	say("\n--- WORST FIRST (ratio = declared / measured) ---")
	var dead := 0
	var over := 0
	var under := 0
	for r in rows:
		var tag := "ok"
		if int(r[4]) == 0:
			tag = "DEAD"; dead += 1
		elif float(r[0]) > 2.2:
			tag = "OVERSTATED"; over += 1
		elif float(r[0]) < 0.4:
			tag = "understated"; under += 1
		say("  %-11s %-16s %-24s declared %5.1f  measured %d  %s"
			% [tag, r[1], r[2], r[3], r[4], str(r[5])])
	say("\n=== SUMMARY: %d behaviors | %d DEAD | %d OVERSTATED | %d understated | %d honest ==="
		% [rows.size(), dead, over, under, rows.size() - dead - over - under])
	get_tree().quit(0)
