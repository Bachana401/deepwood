extends Node

# THE FIVE DEFAULTS (2026-07-30).
#
# `HITS_PER_USE.get(behavior, 1.0)` -- a behavior with no entry is silently
# modelled at 1.0. The plain-ladder behaviors `arc`, `rapid`, `fire`, `shot`
# and `staff` have no entries, and they are the baseline every tier median is
# computed from, so every "the tier stayed flat" claim rests on them.
#
# WHY THIS EXISTS RATHER THAN tool_hitsweep: that probe places the dummy along
# the aim vector and then CLAMPS y to +/-40. Headless aim is about (-0.40,-0.92)
# -- almost straight up -- so a requested 280px becomes roughly 112px of real
# separation, and its range labels are fiction. It reported a melee cudgel
# landing 4 hits "at 280px", which is not a thing that can happen.
#
# Here the dummy is placed at a TRUE distance, twice: once straight along the
# aim (honest for aim-following projectiles) and once flat and horizontal
# (honest for melee arcs and floor-hugging verbs). Best of the two. Neither
# placement lies about how far away the target is.

func say(t: String) -> void: printerr(t)

class Counter extends StaticBody2D:
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
	func take_damage(_n: int):
		hits += 1
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

const WANTED := ["arc", "rapid", "fire", "shot", "staff", "volley"]
# real separations, and short ones included: a melee arc that only reaches 70px
# must be measured somewhere it can actually connect
const DISTS := [45.0, 80.0, 140.0, 240.0]
const SAMPLES := 3          # three weapons per behavior, not one

func _weapons_for(behavior: String) -> Array:
	var out := []
	for row in WeaponRoster.ROWS:
		if str(row[4]) == behavior:
			out.append(str(row[0]))
		if out.size() >= SAMPLES:
			break
	return out

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

	say("\n=== THE FIVE DEFAULTS: one swing, true distances ===")
	for behavior in WANTED:
		var ids := _weapons_for(behavior)
		var per_weapon := []
		for id in ids:
			var def: Dictionary = WeaponRoster.get_def(id)
			if def.is_empty():
				continue
			var best := 0
			var best_at := 0.0
			for dist in DISTS:
				for mode in ["aim", "flat"]:
					p.inventory.add_item(id, 1)
					p.wield_weapon(id)
					p.mana = p.get_max_mana()
					p.health = p.get_max_health()
					var aim: Vector2 = p.get_aim_direction()
					if aim.length() < 0.01:
						aim = Vector2.RIGHT
					var off: Vector2
					if mode == "aim":
						off = aim.normalized() * dist     # TRUE distance, no clamp
					else:
						off = Vector2(signf(aim.x) if aim.x != 0.0 else 1.0, 0.0) * dist
					var dummy := Counter.new()
					dummy.add_to_group("course_enemy")
					stage.add_child(dummy)
					dummy.global_position = (p as Node2D).global_position + off
					await get_tree().process_frame
					await get_tree().process_frame
					p.attack_cooldown_remaining = 0.0
					p.perform_attack()          # exactly ONE use
					await get_tree().create_timer(2.0, true).timeout
					if dummy.hits > best:
						best = dummy.hits
						best_at = dist
					dummy.queue_free()
					await get_tree().process_frame
			per_weapon.append([str(def.get("name", id)), best, best_at])
		var line := "  %-8s" % behavior
		var total := 0
		for w in per_weapon:
			line += "  %s=%d@%dpx" % [w[0], w[1], int(w[2])]
			total += int(w[1])
		var mean := 0.0 if per_weapon.is_empty() else float(total) / float(per_weapon.size())
		say("%s   -> MEAN %.1f hits per use" % [line, mean])
	get_tree().quit(0)
