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
# REAL separations. The short end matters most: at a 45px floor, Mongrel Knife
# and Barrel Stave connected at NO distance and no staff connected at all, which
# is the harness bottoming out rather than the weapons missing. A melee arc that
# reaches 30px has to be measured at 30px or the number is about the probe.
const DISTS := [16.0, 26.0, 36.0, 45.0, 80.0, 140.0, 240.0]
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
				for mode in ["aim", "flat", "area"]:
					p.inventory.add_item(id, 1)
					p.wield_weapon(id)
					p.mana = p.get_max_mana()
					p.health = p.get_max_health()
					var aim: Vector2 = p.get_aim_direction()
					if aim.length() < 0.01:
						aim = Vector2.RIGHT
					var dummy := Counter.new()
					dummy.add_to_group("course_enemy")
					stage.add_child(dummy)
					if mode == "area":
						# THE ANSWER to five weapons measuring zero. Melee damage
						# is `$AttackArea.get_overlapping_bodies()` -- a hitbox
						# on the PLAYER, offset along the aim. Headless aim points
						# up and to the left, so a small area sits up-left while
						# every other placement puts the target to the right. Oak
						# Cudgel's area is wide enough to catch it anyway and
						# Mongrel Knife's is not, which is the whole of the
						# "five weapons deal no damage" scare.
						# For a melee weapon "hits per USE" is not a function of
						# range at all -- it is what one swing does to a body
						# that is in the arc. So put the body in the arc.
						var area = (p as Node2D).get_node_or_null("AttackArea")
						if area == null:
							dummy.queue_free()
							continue
						dummy.global_position = (area as Node2D).global_position
					elif mode == "aim":
						dummy.global_position = (p as Node2D).global_position \
							+ aim.normalized() * dist        # TRUE distance, no clamp
					else:
						dummy.global_position = (p as Node2D).global_position \
							+ Vector2(signf(aim.x) if aim.x != 0.0 else 1.0, 0.0) * dist
					await get_tree().process_frame
					await get_tree().process_frame
					# THE PRIMING SWING. perform_attack MOVES $AttackArea to
					# aim_dir * range_offset (player.gd:4895) and then reads
					# get_overlapping_bodies() (player.gd:4940) in the SAME
					# call -- and Godot's overlap set is whatever the last
					# PHYSICS STEP computed, at the area's OLD position. So the
					# first swing after the area moves reads a stale set.
					# One throwaway swing parks the area, a physics frame lets
					# the engine notice, and the swing we actually count then
					# reads a true overlap set.
					p.attack_cooldown_remaining = 0.0
					p.perform_attack()
					await get_tree().physics_frame
					await get_tree().physics_frame
					dummy.hits = 0              # the priming swing does not count
					p.attack_cooldown_remaining = 0.0
					p.perform_attack()          # exactly ONE counted use
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
