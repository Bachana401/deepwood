extends Node

# WHERE DOES A MORTAR ACTUALLY GO? (2026-07-31) The proving sweep scores the
# whole lob family zero even with rings at 430/560 and a settle window. The
# arithmetic says a T3 shell lands ~520px out; the sweep says nothing lands
# anywhere. One of them is wrong and this prints which. Setup mirrors the
# sweep exactly: arena puppet, set_test_aim(RIGHT), perform_attack.

const ARENA = preload("res://weapon_arena.gd")

func say(t: String) -> void: printerr(t)

class Mark extends StaticBody2D:
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

func _ready() -> void:
	await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	var arena = ARENA.take_over(get_tree(), self)
	for _f in range(20):
		await get_tree().process_frame
	var p: Node = arena.player
	if p == null or not is_instance_valid(p):
		say("ABORTED: arena has no puppet"); get_tree().quit(0); return
	var stage: Node = arena
	# same furniture rule as the sweep: the EYES-rig house marks leave first,
	# or the nearest one eats every shaft at +70 and the trace lies
	for hm in arena.marks:
		if is_instance_valid(hm):
			hm.queue_free()
	arena.marks.clear()
	await get_tree().process_frame
	p.set_test_aim(Vector2.RIGHT)
	var home: Vector2 = (p as Node2D).global_position
	say("puppet at (%.0f, %.0f)" % [home.x, home.y])
	# TRACE_WEAPON picks the weapon; the tracer outgrew the lob family the day
	# a bow needed the same treatment (arrows are CharacterBody2D, not Area2D)
	var wid := OS.get_environment("TRACE_WEAPON")
	if wid == "":
		wid = "wpn_bogmortar"
	p.inventory.add_item(wid, 1)
	p.wield_weapon(wid)
	# let the puppet SETTLE onto the floor before placing anything relative to
	# it -- spawn #1 fired from mid-fall taught this the hard way
	for _s in range(20):
		await get_tree().process_frame
	home = (p as Node2D).global_position
	say("settled at (%.0f, %.0f)" % [home.x, home.y])
	var marks := []
	for d in [45, 150, 280]:
		var m := Mark.new()
		m.add_to_group("course_enemy")
		stage.add_child(m)
		m.global_position = home + Vector2(float(d), 0.0)
		marks.append(m)
	await get_tree().process_frame
	p.mana = p.get_max_mana()
	p.attack_cooldown_remaining = 0.0
	get_tree().paused = false
	# HOLD the trigger exactly as the sweep does -- a single loose cannot see
	# repeat-fire bugs, and Orchard Bow's sweep number said the repeats vanish
	var hold := 0.0
	var spawns := 0
	var last_seen: Node = null
	while hold < 2.4:
		p.perform_attack()
		await get_tree().process_frame
		hold += get_process_delta_time()
		for c2 in stage.get_children():
			if c2 != last_seen and is_instance_valid(c2) \
					and c2 is CharacterBody2D and c2.get("rider") != null \
					and not c2.is_in_group("player"):
				spawns += 1
				last_seen = c2
				say("  spawn #%d at t=%.2f rel(%.0f, %.0f) cd=%.2f" % [spawns, hold,
					c2.global_position.x - home.x, c2.global_position.y - home.y,
					p.attack_cooldown_remaining])
	say("total spawns seen: %d" % spawns)
	say("trigger held 2.4s; watching the tail  (tree paused=%s)" % str(get_tree().paused))
	var flips := 0
	var t := 0.0
	var traced = null
	var seen := false
	while t < 3.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if get_tree().paused:
			flips += 1
			if flips <= 3:
				say("  !! tree re-paused at t=%.2f" % t)
			get_tree().paused = false
		if traced == null or not is_instance_valid(traced):
			if traced != null:
				traced = null
			for c in stage.get_children():
				if is_instance_valid(c) and ((c is Area2D and c.get("kind") != null)
						or (c is CharacterBody2D and c.get("rider") != null and not c.is_in_group("player"))):
					traced = c
					if not seen:
						seen = true
						say("  found projectile kind=%s rider=%s rel(%.0f, %.0f) can_process=%s phys=%s paused=%s"
							% [c.get("kind"), c.get("rider"),
								c.global_position.x - home.x, c.global_position.y - home.y,
								str(c.can_process()), str(c.is_physics_processing()),
								str(get_tree().paused)])
		elif int(t * 10.0) != int((t - dt) * 10.0):
			say("  t=%.2f kind=%s rel(%.0f, %.0f) vel_y=%s max_range=%s"
				% [t, str(traced.get("kind")), traced.global_position.x - home.x,
					traced.global_position.y - home.y, str(traced.get("_vel_y")),
					str(traced.get("max_range"))])
	if not seen:
		say("  NO PROJECTILE EVER APPEARED on the stage")
	say("--- final mark tally ---")
	for m in marks:
		say("  mark at +%.0f: %d hits" % [m.global_position.x - home.x, m.hits])
	get_tree().quit(0)
