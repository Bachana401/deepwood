extends Node

# WHY DO FIVE WEAPONS DEAL ZERO? (2026-07-30)
#
# Three hypotheses have already failed: a missing case label, a missing entry in
# player.gd's wand allow-list, and the projectile not spawning at all. The
# dispatch audit says nodes DO spawn. So the launch works and the damage does
# not, and guessing a fourth time is not a method.
#
# This traces the two halves separately:
#   A. build the projectile DIRECTLY beside a dummy and step it -- if it damages
#      here, the verb is fine and the CAST path is losing it.
#   B. fire it through the real player -- and report what the player computed.

func say(t: String) -> void: printerr(t)

class Dummy extends StaticBody2D:
	var health := 999999
	var max_health := 999999
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

const PROJ = preload("res://weapon_projectile.gd")

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
		say("no player"); get_tree().quit(1); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	# ---------- A. THE VERB, IN ISOLATION ----------
	say("\n===== A. projectile built directly, dummy 70px away =====")
	for spec in [["chalk_line", 96.0], ["ink_jet", 420.0], ["wake_scythe", 420.0]]:
		var d := Dummy.new()
		d.add_to_group("course_enemy")
		stage.add_child(d)
		d.global_position = (p as Node2D).global_position + Vector2(70.0, 0.0)
		var pr = PROJ.new()
		pr.kind = str(spec[0])
		pr.direction = Vector2.RIGHT
		pr.speed = 300.0
		pr.damage = 11
		pr.max_distance = float(spec[1])
		pr.source = p
		stage.add_child(pr)
		pr.global_position = (p as Node2D).global_position
		for _f in range(90):
			await get_tree().process_frame
		say("  %-14s hits=%d   projectile still alive: %s"
			% [str(spec[0]), d.hits, str(is_instance_valid(pr))])
		if is_instance_valid(pr):
			pr.queue_free()
		d.queue_free()
		await get_tree().process_frame

	# ---------- B. THROUGH THE PLAYER ----------
	say("\n===== B. fired by the player =====")
	for id in ["wpn_chalkwand", "wpn_inkbook", "wpn_wakebook"]:
		var def: Dictionary = WeaponRoster.get_def(id)
		var sp: Dictionary = def.get("special", {})
		say("  %s  weapon_type=%s  special=%s  mana_cost=%s"
			% [id, str(def.get("weapon_type", "?")), str(sp),
				str(def.get("mana_cost", "none"))])
		var d2 := Dummy.new()
		d2.add_to_group("course_enemy")
		stage.add_child(d2)
		d2.global_position = (p as Node2D).global_position + Vector2(80.0, 0.0)
		p.inventory.add_item(id, 1)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		var before := stage.get_child_count()
		Input.warp_mouse(get_viewport().get_canvas_transform() * d2.global_position)
		await get_tree().process_frame
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		await get_tree().process_frame
		var spawned := stage.get_child_count() - before
		# name what actually appeared, so "a node spawned" is not the end of it
		var kinds := []
		for c in stage.get_children():
			var k = c.get("kind")
			if k != null and str(k) != "":
				kinds.append(str(k))
		for _f2 in range(80):
			await get_tree().process_frame
		# THE SUSPECT: in --headless there is no window, so Input.warp_mouse is a
		# no-op and get_aim_direction() returns whatever the default is. If that
		# points away from the dummy, the weapon is fine and the HARNESS is what
		# measured zero. Print it rather than assume either way.
		var aim: Vector2 = p.get_aim_direction()
		var toward: Vector2 = (d2.global_position - (p as Node2D).global_position).normalized()
		say("      spawned=%d  kinds=[%s]  mana_after=%.0f  HITS=%d"
			% [spawned, ", ".join(kinds), p.mana, d2.hits])
		say("      aim=(%.2f, %.2f)  toward_dummy=(%.2f, %.2f)  dot=%.2f"
			% [aim.x, aim.y, toward.x, toward.y, aim.dot(toward)])
		d2.queue_free()
		await get_tree().process_frame

	printerr("RESULT: TRACE COMPLETE")
	get_tree().quit(0)
