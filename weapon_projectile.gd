extends Area2D

# One configurable projectile powering the special-attack weapons (see
# player.gd launch_projectile + the "special" dicts in inventory.gd). Kinds:
#   slash       -- a flying wind-crescent that pierces everyone in its path
#   javelin     -- a hurled spectral spear, also piercing
#   fireball    -- explodes in an AoE on the first hit (or at max range)
#   frost_shard -- fast piercing ice sliver
#   hook        -- drags the first enemy struck back to the player's feet
#   boomerang   -- flies out, turns, and comes back: hits on BOTH passes
#
# Area2D (not a body) so it sails over terrain; enemies are found the same
# way the player's arrows find them (collision_mask 4 + take_damage check).
# All visuals are procedural polygons, self-cleaning on despawn.

var kind := "slash"
var girth := 1.0            # scales the visual AND the hitbox together
var element := "physical"   # the caster weapon's element (VFX pass): hit bursts pop in its colour
var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10
var max_distance := 450.0
var pierce := false
var aoe_radius := 0.0
var knockback := 40.0
var is_crit := false        # set by the player when it rolls a crit
var on_hit_status := {}     # {"kind","dur","mag"} applied to enemies on hit
var source: Node2D = null   # the player (hook pull target / boomerang home)
var from_wand := false      # set by player.launch_projectile for true wand casts (Stillness)
var rider := ""             # flagship bespoke behavior (The Rumor "grows", ...)
var _borrowed := false      # A Borrowed Star: the apex split fires only once

func _apply_status_to(node) -> void:
	# element impact burst (VFX pass): every landed projectile pops in colour
	if node is Node2D and not node.is_in_group("player"):
		HitFx.burst(get_parent(), (node as Node2D).global_position, element, is_crit)
	if not on_hit_status.is_empty() and node.has_method("apply_status"):
		node.apply_status(str(on_hit_status.get("kind","burn")), float(on_hit_status.get("dur",3.0)), float(on_hit_status.get("mag",0.0)))
	# Stillness (Wukong road): a wand bolt may carry the stopping word --
	# 12% to hold a NON-boss perfectly still. Bosses shrug the word off.
	if from_wand and node.has_method("apply_status") and not ("boss_id" in node) \
			and GameState.get_bonus_total("stillness") > 0.0 and randf() < 0.12:
		node.apply_status("freeze", 2.5, 0.0)
		if node is Node2D:
			SfxSynth.play_at(self, (node as Node2D).global_position, "chime", -12.0)
	# Elementalist Wildfire / Cataclysm: the burn you just applied leaps to any
	# foes crowded around the one you struck.
	if GameState.get_bonus_total("combustion") > 0.0 and is_instance_valid(node):
		var mag = GameState.get_bonus_total("on_hit_burn")
		if mag <= 0.0:
			mag = 6.0
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if e == node or not is_instance_valid(e) or not e.has_method("apply_status"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if node.global_position.distance_to(e.global_position) <= 110.0:
					e.apply_status("burn", 3.0, mag)

var traveled := 0.0
var returning := false      # boomerang/lash: on the way back
var done := false
var hit_bodies: Array = []
var visual: Node2D = null
var spin_speed := 0.0
var rope: Line2D = null     # hook: drawn back to the thrower

# --- the wave-1 behavior library (Terraria-INSPIRED, never 1:1; weapons
# overhaul 2026-07-28). Five new kinds join the six above:
#   orbiter  -- a soulthread charm: flies out, then SPINS at the far point
#               striking everything around it, then threads home (yoyo-kin)
#   ricochet -- leaps enemy to enemy, damage decaying each bounce
#   cluster  -- bursts into a fan of shards on its first kill or at range
#   lob      -- a mortar arc: rises, falls, and BLOSSOMS where it lands
#   lash     -- a piercing ribbon that weaves out and whips back through
#               the same lane, hitting on both passes (eruption-kin)
var dwell := 2.2            # orbiter: seconds it spins at the far point
var bounces := 3            # ricochet: enemy-to-enemy leaps
var shards := 5             # cluster: children in the burst
var arc_gravity := 620.0    # lob: the mortar's pull
var _vel_y := 0.0           # lob: vertical velocity
var _start_y := 0.0         # lob: the launch height (landing detector)
var _orbit_centre := Vector2.ZERO
var _orbit_t := 0.0
var _behave_state := 0      # orbiter: 0 fly out, 1 spin, 2 thread home
var _rehit_t := 0.0         # orbiter/lash: clears the hit list to strike again

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	# findable in flight, so a mirror boss has something to reflect (boss.gd
	# tick_mirror). Without this the mechanic is a silent no-op.
	add_to_group("player_projectile")
	collision_layer = 0
	collision_mask = 4   # enemy layer, same as the player's arrows target
	monitoring = true
	z_index = 40
	var cs = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	# girth scales the projectile as a whole -- the drawn shape AND what it can
	# hit -- so a mythic crescent is genuinely a wall of force sweeping the room
	# rather than a small sprite that merely looks impressive.
	shape.size = Vector2(36, 20) * girth
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	visual = Node2D.new()
	visual.scale = Vector2.ONE * girth
	add_child(visual)
	match kind:
		"soul_split": _build_soulbolt()
		"slash": _build_slash()
		"javelin": _build_javelin()
		"fireball": _build_fireball()
		"frost_shard": _build_frost()
		"hook": _build_hook()
		"boomerang":
			_build_boomerang()
			spin_speed = 16.0
		"orbiter":
			_build_orbiter()
			spin_speed = 22.0
			pierce = true          # multi-hit by nature; despawn is state-driven
		"chain_maul":
			_build_chainmaul()
			spin_speed = 18.0
			pierce = true          # the whirl and the hurl both rake through
		"ricochet":
			_build_ricochet()
		"cluster":
			_build_cluster()
		"lob":
			_build_lob()
			_vel_y = -absf(float(speed)) * 0.62   # the mortar's upward kick
			_start_y = global_position.y
			if aoe_radius <= 0.0:
				aoe_radius = 90.0
		"lash":
			_build_lash()
			pierce = true
		# tome batch 3b (no two tomes cast the same shape):
		"ink_jet":
			_build_inkjet()
			pierce = true
			_vel_y = -absf(float(speed)) * 0.3   # a lobbed STREAM: gentle arc
		"wake_scythe":
			_build_wakescythe()
			pierce = true
			spin_speed = 9.0
			speed = maxf(120.0, float(speed) * 0.3)   # starts lazy, ACCELERATES
		"soul_stream":
			_build_soulwispshot()
			pierce = false
	if spin_speed == 0.0:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if done:
		return
	# the behavior kinds that OWN their whole flight take the frame here
	if kind == "orbiter" and _tick_orbiter(delta):
		return
	if kind == "chain_maul":
		_tick_chainmaul(delta)
		return
	if kind == "lob":
		_tick_lob(delta)
		return
	if kind == "ink_jet":
		# THE INKWELL OF STORMS: a piercing stream riding a gentle arc --
		# gravity pulls the jet down as it flies, staining as it goes
		_vel_y += 620.0 * delta
		global_position += direction * speed * delta + Vector2(0, _vel_y * delta)
		rotation = (direction * speed + Vector2(0, _vel_y)).angle()
		traveled += speed * delta
		if traveled >= max_distance or _vel_y > 700.0:
			done = true
			queue_free()
		return
	if kind == "wake_scythe":
		# THE BOOK OF WAKES: the scythe WAKES as it travels -- lazy at the
		# page, terrible by the far edge (accelerating pierce disc)
		speed = minf(1100.0, speed * (1.0 + 2.4 * delta))
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance * 1.4:
			done = true
			queue_free()
		return
	if kind == "soul_stream":
		# THE FLOOD OF SOULS: each soul BENDS toward the nearest living thing
		var prey := _nearest_hostile_node(420.0)
		if prey != null:
			var desired := (prey.global_position - global_position).normalized()
			var maxturn := 4.2 * delta
			direction = direction.rotated(clampf(direction.angle_to(desired), -maxturn, maxturn)).normalized()
			rotation = direction.angle()
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance * 1.3:
			done = true
			queue_free()
		return
	if kind == "lash":
		# a weaving ribbon: the lane is `direction`, the weave rides across it
		_rehit_t += delta
		if _rehit_t >= 0.5:
			_rehit_t = 0.0
			hit_bodies.clear()   # both passes -- and long bodies get raked
	if (kind == "boomerang" or kind == "lash") and returning:
		if not is_instance_valid(source):
			queue_free()
			return
		var to_src = source.global_position - global_position
		if to_src.length() < 26.0:
			queue_free()
			return
		direction = to_src.normalized()
	var step = speed * delta
	global_position += direction * step
	if kind == "lash":
		# the sideways weave, perpendicular to the lane
		var perp := Vector2(-direction.y, direction.x)
		global_position += perp * sin(traveled * 0.045) * 90.0 * delta
	traveled += step
	if spin_speed != 0.0 and visual:
		visual.rotation += spin_speed * delta
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	if not returning and traveled >= max_distance:
		if kind == "boomerang" or kind == "lash":
			returning = true
			hit_bodies.clear()   # the return pass hits everyone again
		elif kind == "fireball":
			explode()
		elif kind == "cluster":
			_burst()             # nothing in the way: blossom at full reach
		elif kind == "orbiter":
			if _behave_state == 0:   # full thread: start the wheel HERE
				_behave_state = 1
				_orbit_centre = global_position
				_orbit_t = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -12.0, 1.2)
		else:
			done = true   # a spent bolt lands no same-frame parting hit
			queue_free()

# Orbiter: fly out (false = let the shared movement run), then spin at the far
# point striking everything in the wheel, then thread home. Returns true while
# it owns the frame.
func _tick_orbiter(delta: float) -> bool:
	match _behave_state:
		1:
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.35:
				_rehit_t = 0.0
				hit_bodies.clear()   # the wheel keeps cutting
			var r := 30.0 * girth
			global_position = _orbit_centre + Vector2(cos(_orbit_t * 9.0), sin(_orbit_t * 9.0)) * r
			if _orbit_t >= dwell:
				_behave_state = 2
				hit_bodies.clear()   # one clean cut on the way home
			return true
		2:
			if not is_instance_valid(source):
				queue_free()
				return true
			var to_src = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return true
			global_position += to_src.normalized() * speed * 1.35 * delta
			return true
		_:
			if traveled >= max_distance:
				_behave_state = 1
				_orbit_centre = global_position
				SfxSynth.play_at(self, global_position, "whoosh", -12.0, 1.2)
			return false

# Chain maul: whirls about the WIELDER gathering speed, then hurls itself
# along the aim as a comet, then hauls back home on its chain. Owns every
# frame of its flight.
func _tick_chainmaul(delta: float) -> void:
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	if spin_speed != 0.0 and visual:
		visual.rotation += spin_speed * delta
	match _behave_state:
		0:   # the whirl: an opening spiral centred on the wielder
			if not is_instance_valid(source):
				queue_free()
				return
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.3:
				_rehit_t = 0.0
				hit_bodies.clear()   # every lap of the whirl cuts again
				if rider == "moon":
					_moon_pull()     # Second Moon: the whirl has its own tide
			var r := (44.0 + _orbit_t * 75.0) * girth
			var side := 1.0 if direction.x >= 0.0 else -1.0
			global_position = source.global_position \
				+ Vector2(cos(_orbit_t * 9.5 * side), sin(_orbit_t * 9.5 * side)) * r
			if _orbit_t >= 0.7:
				_behave_state = 1
				hit_bodies.clear()
				# hurl from wherever the whirl released, along the aim
				traveled = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -9.0, 0.9)
		1:   # the hurl
			var step := speed * 1.45 * delta
			global_position += direction * step
			traveled += step
			if traveled >= max_distance:
				_behave_state = 2
				hit_bodies.clear()   # one clean cut on the haul home
		_:   # hauled home on the chain
			if not is_instance_valid(source):
				queue_free()
				return
			var to_src = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return
			global_position += to_src.normalized() * speed * 1.3 * delta

# Lob: a mortar arc under its own gravity; blossoms where it lands (or on
# whatever it meets on the way down).
func _tick_lob(delta: float) -> void:
	# A Borrowed Star: at the TOP of the arc it sheds two smaller embers,
	# once -- three falling lights where one was borrowed
	if rider == "borrow" and not _borrowed and _vel_y >= 0.0:
		_borrowed = true
		var script: GDScript = get_script()
		for side in [-0.3, 0.3]:
			var ember = script.new()
			ember.kind = "lob"
			ember.direction = Vector2(direction.x + side, 0.0).normalized()
			ember.speed = speed * 0.8
			ember.damage = maxi(1, int(round(damage * 0.45)))
			ember.aoe_radius = aoe_radius * 0.6
			ember.max_distance = max_distance
			ember.arc_gravity = arc_gravity
			ember._start_y = _start_y
			ember.on_hit_status = on_hit_status
			ember.source = source
			get_parent().add_child(ember)
			ember.global_position = global_position
	_vel_y += arc_gravity * delta
	global_position += Vector2(direction.x * speed * 0.8 * delta, _vel_y * delta)
	traveled += speed * 0.8 * delta
	if visual:
		visual.rotation += 6.0 * delta
	# landing: past the launch height on the way down, or out of reach entirely
	if (_vel_y > 0.0 and global_position.y >= _start_y + 8.0) or traveled >= max_distance * 1.6:
		explode()

# Cluster: the blossom -- a fan of frost-quick shards from the burst point.
func _burst() -> void:
	if done:
		return
	done = true
	SfxSynth.play_at(self, global_position, "pop", -10.0, 0.7)
	var script: GDScript = get_script()
	for i in range(maxi(2, shards)):
		var a := -PI * 0.5 + (float(i) / float(maxi(2, shards) - 1) - 0.5) * PI * 1.3
		var child = script.new()
		child.kind = "frost_shard"
		child.direction = Vector2(cos(a), sin(a)) if direction.x >= 0.0 else Vector2(-cos(a), sin(a))
		child.speed = speed * 1.15
		child.damage = maxi(1, int(round(damage * 0.45)))
		child.max_distance = 260.0
		child.girth = girth * 0.7
		child.pierce = false
		child.on_hit_status = on_hit_status
		child.is_crit = false
		child.source = source
		get_parent().add_child(child)
		child.global_position = global_position
	# a soft pop so the split reads
	var pop = Polygon2D.new()
	pop.polygon = _circle(16.0 * girth, 12)
	pop.color = Color(0.8, 0.9, 1.0, 0.6)
	get_parent().add_child(pop)
	pop.global_position = global_position
	var t = pop.create_tween()
	t.tween_property(pop, "scale", Vector2(2.2, 2.2), 0.2)
	t.parallel().tween_property(pop, "modulate:a", 0.0, 0.2)
	t.tween_callback(pop.queue_free)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if done or body in hit_bodies:
		return
	if not body.has_method("take_damage"):
		return
	if "is_dead" in body and body.is_dead:
		return
	hit_bodies.append(body)
	# the Soul Split bolt never damages -- it only asks the target to divide
	if kind == "soul_split":
		# `done` on EVERY terminal path (audit fix): queue_free() does not stop
		# a second body_entered in the SAME physics frame, so a bolt overlapping
		# two enemies at once hit both -- and a soul_split could ask two targets
		# to divide with one cast
		done = true
		if body.has_method("on_soul_split_wand"):
			body.on_soul_split_wand()
		else:
			FloatingText.spawn_word(get_parent(), body.global_position + Vector2(0, -40), "...nothing?", Color(0.8, 0.8, 0.9))
		queue_free()
		return
	# A weapon's thrown crescent carries its owner's signature: landing one is a
	# hit like any other, so lifesteal, gold-touch, execute and the rest all fire.
	# Without this a weapon built to reach was strictly worse at its own range.
	# (The player guards against a unique that throws another projectile.)
	if is_instance_valid(source) and source.has_method("on_projectile_hit"):
		source.on_projectile_hit(body, damage)
	match kind:
		"fireball":
			explode()
		"lob":
			explode()
		"cluster":
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_burst()
		"ricochet":
			var landed_r = body.take_damage(damage)
			if landed_r == null or landed_r:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			# leap to the nearest fresh target; the arc loses an edge each jump
			# -- unless it's The Rumor, which GROWS in the telling
			bounces -= 1
			damage = maxi(1, int(round(damage * (1.08 if rider == "grows" else 0.85))))
			# Grave Courier: a quarter of the bodies it departs are left
			# FEARED -- rooted deep in a slow, watching it leave
			if rider == "courier" and randf() < 0.25 and body.has_method("apply_status"):
				body.apply_status("slow", 1.5, 0.45)
			var next: Node2D = null
			var best := 340.0
			if bounces >= 0:
				for group_name in HOSTILE_GROUPS:
					for e in get_tree().get_nodes_in_group(group_name):
						if e == body or hit_bodies.has(e) or not is_instance_valid(e):
							continue
						if not (e is Node2D) or not e.has_method("take_damage"):
							continue
						if "is_dead" in e and e.is_dead:
							continue
						var d: float = global_position.distance_to(e.global_position)
						if d < best:
							best = d
							next = e
			if next != null:
				direction = (next.global_position - global_position).normalized()
				rotation = direction.angle()
				traveled = 0.0   # each leap gets its full legs
				# every leap PINGS, rising as the chain grows (The Rumor's
				# nine leaps climb almost an octave)
				SfxSynth.play_at(self, global_position, "pop", -14.0, 1.3 + 0.06 * float(shards))
			else:
				done = true
				queue_free()
		"hook":
			done = true   # same one-frame double-hit guard as soul_split
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_pull_to_source(body)
			queue_free()
		_:
			# only show a number if the blow actually got through (a boss can
			# absorb it entirely); void take_damage means "landed"
			# The Long Goodbye: the RETURN pass cuts double -- it hurts most
			# on the way out of your life
			var dealt := damage * (2 if kind == "lash" and returning and rider == "goodbye" else 1)
			var landed = body.take_damage(dealt)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), body.global_position, dealt, is_crit)
			_apply_status_to(body)
			# Summer's Coffin: what it kills SHATTERS -- the cold bursts onto
			# the mourners crowded round
			if rider == "coffin" and "is_dead" in body and body.is_dead:
				_frost_shatter(body.global_position)
			if body.has_method("apply_knockback"):
				body.apply_knockback(1 if direction.x >= 0.0 else -1, knockback)
			if not pierce and kind != "boomerang":
				done = true   # same one-frame double-hit guard as soul_split
				queue_free()

# Second Moon: every lap of the whirl drags loose enemies a step toward the
# wielder -- a gentle tide that feeds the spiral's own blades.
func _moon_pull() -> void:
	if not is_instance_valid(source):
		return
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("apply_knockback"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var dx: float = source.global_position.x - e.global_position.x
			if absf(dx) <= 180.0 and absf(dx) > 30.0:
				e.apply_knockback(1 if dx >= 0.0 else -1, 26.0)

# Summer's Coffin: the shatter -- cold damage and a deep chill around a body
# the sliver just killed.
func _frost_shatter(at: Vector2) -> void:
	SfxSynth.play_at(self, at, "chime", -11.0, 0.6)   # the cold, breaking
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if at.distance_to(e.global_position) <= 90.0:
				e.take_damage(maxi(1, int(round(damage * 0.5))))
				if e.has_method("apply_status"):
					e.apply_status("slow", 2.0, 0.5)
	var ring = Polygon2D.new()
	ring.polygon = _circle(30.0, 12)
	ring.color = Color(0.75, 0.92, 1.0, 0.8)
	ring.z_index = 45
	get_parent().add_child(ring)
	ring.global_position = at
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.3)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_callback(ring.queue_free)

# Hook: reel the victim in using its own knockback system (negative direction
# = toward the player), so it respects the enemy's is_dead/knockback rules.
func _pull_to_source(body: Node2D) -> void:
	if not is_instance_valid(source) or not body.has_method("apply_knockback"):
		return
	var dx = source.global_position.x - body.global_position.x
	var pull_sign = 1 if dx >= 0.0 else -1
	body.apply_knockback(pull_sign, max(absf(dx) - 42.0, 0.0))

const SFX_EXPLOSION = preload("res://audio/explosion.wav")

# Fireball: blast everyone standing near the detonation point.
func explode() -> void:
	if done:
		return
	done = true
	SfxSynth.play_stream_at(self, global_position, SFX_EXPLOSION, -9.0)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= aoe_radius:
				e.take_damage(damage)
				FloatingText.spawn(get_parent(), e.global_position, damage, is_crit)
				_apply_status_to(e)
				if e.has_method("apply_knockback"):
					e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback)
	# A Small Personal Sun: the blast doesn't leave -- a grounded sunlet
	# keeps burning the spot for a few seconds after the flash
	if rider == "sunfall":
		var sun = load("res://storm_cloud.gd").new()
		sun.sun_mode = true
		sun.radius = 80.0
		sun.strike_gap = 0.5
		sun.duration = 3.0
		sun.damage = maxi(1, int(round(damage * 0.35)))
		sun.source = source
		get_parent().add_child(sun)
		sun.global_position = global_position
	# blast flash: expanding fading disc + ring, left behind as we free
	var blast = Polygon2D.new()
	blast.polygon = _circle(aoe_radius * 0.4, 20)
	blast.color = Color(1.0, 0.6, 0.2, 0.7)
	blast.z_index = 45
	get_parent().add_child(blast)
	blast.global_position = global_position
	var t = blast.create_tween()
	t.tween_property(blast, "scale", Vector2(2.6, 2.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(blast, "modulate:a", 0.0, 0.25)
	t.tween_callback(blast.queue_free)
	queue_free()

# --- tome batch 3b builds + the soul's eye ------------------------------
# THE INKWELL OF STORMS: a dark teardrop stream, ink-blue, trailing droplets
func _build_inkjet() -> void:
	var drop := Polygon2D.new()
	drop.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(-4, -5), Vector2(10, -3), Vector2(16, 0), Vector2(10, 3), Vector2(-4, 5)])
	drop.color = Color(0.16, 0.2, 0.45, 0.95)
	visual.add_child(drop)
	var sheen := Polygon2D.new()
	sheen.polygon = PackedVector2Array([Vector2(-8, -2), Vector2(6, -2), Vector2(10, 0), Vector2(6, 1), Vector2(-8, 1)])
	sheen.color = Color(0.45, 0.55, 0.9, 0.8)
	visual.add_child(sheen)

# THE BOOK OF WAKES: a bone-pale scythe disc that spins as it wakes
func _build_wakescythe() -> void:
	var arc := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var r := 22.0 if i % 2 == 0 else 11.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	arc.polygon = pts
	arc.color = Color(0.85, 0.9, 0.8, 0.95)
	visual.add_child(arc)
	var wash := Polygon2D.new()
	var wpts := PackedVector2Array()
	for i in range(12):
		var aw := TAU * float(i) / 12.0
		wpts.append(Vector2(cos(aw), sin(aw)) * 30.0)
	wash.polygon = wpts
	wash.color = Color(0.65, 0.85, 0.8, 0.3)
	var wm := CanvasItemMaterial.new()
	wm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wash.material = wm
	visual.add_child(wash)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5)])
	eye.color = Color(0.3, 0.45, 0.35, 0.95)
	visual.add_child(eye)

# THE FLOOD OF SOULS: a pale wisp-skull with a streaming tail
func _build_soulwispshot() -> void:
	var skull := Polygon2D.new()
	var pts2 := PackedVector2Array()
	for i in range(10):
		var a2 := TAU * float(i) / 10.0
		pts2.append(Vector2(cos(a2) * 7.0, sin(a2) * 6.0))
	skull.polygon = pts2
	skull.color = Color(0.8, 0.88, 1.0, 0.9)
	visual.add_child(skull)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-6, -3), Vector2(-18, 0), Vector2(-6, 3)])
	tail.color = Color(0.6, 0.72, 0.95, 0.6)
	visual.add_child(tail)

func _nearest_hostile_node(within: float) -> Node2D:
	var best: Node2D = null
	var bd := within
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best

# --- procedural looks ---

# The Soul Split Wand's bolt: a pale prismatic orb. It deals NO damage --
# whatever it strikes is asked to divide, and what that means is the target's
# business (a joke for everything alive; the end of the world for one thing).
func _build_soulbolt() -> void:
	var orb = Polygon2D.new()
	orb.polygon = _circle(9.0, 12)
	orb.color = Color(0.95, 0.8, 1.0, 0.9)
	visual.add_child(orb)
	var halo = Polygon2D.new()
	halo.polygon = _circle(14.0, 12)
	halo.color = Color(0.8, 0.6, 1.0, 0.3)
	visual.add_child(halo)

func _build_slash() -> void:
	var arc = Polygon2D.new()   # a thin crescent, like a slice of wind
	var pts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.9, 0.9, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	for i in range(9):
		var a = lerp(0.9, -0.9, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	arc.polygon = pts
	arc.color = Color(0.75, 0.95, 1.0, 0.85)
	visual.add_child(arc)

func _build_javelin() -> void:
	var shaft = Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-24, -2), Vector2(16, -2), Vector2(16, 2), Vector2(-24, 2)])
	shaft.color = Color(0.85, 0.8, 0.55, 0.9)
	visual.add_child(shaft)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(16, -5), Vector2(28, 0), Vector2(16, 5)])
	tip.color = Color(0.95, 0.92, 0.75, 0.95)
	visual.add_child(tip)

func _build_fireball() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(14.0, 14)
	glow.color = Color(1.0, 0.5, 0.1, 0.4)
	visual.add_child(glow)
	var core = Polygon2D.new()
	core.polygon = _circle(8.0, 12)
	core.color = Color(1.0, 0.75, 0.3, 0.95)
	visual.add_child(core)
	var trail = CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.35
	trail.direction = Vector2(-1, 0)
	trail.spread = 24.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 90.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.4
	trail.color = Color(1.0, 0.55, 0.15, 0.8)
	visual.add_child(trail)

func _build_frost() -> void:
	var shard = Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(-4, -6), Vector2(18, 0), Vector2(-4, 6)])
	shard.color = Color(0.7, 0.9, 1.0, 0.9)
	visual.add_child(shard)
	var gleam = Polygon2D.new()
	gleam.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(0, -2), Vector2(10, 0), Vector2(0, 2)])
	gleam.color = Color(0.95, 1.0, 1.0, 0.9)
	visual.add_child(gleam)

# A soulthread charm: a rune-disc that spins on its thread.
func _build_orbiter() -> void:
	# EYES 2026-07-28: sized and haloed like the flail -- the first build was
	# a faint dot at world zoom, and a spinning wheel must LOOK like a wheel
	var glow = Polygon2D.new()
	glow.polygon = _circle(22.0, 12)
	glow.color = Color(0.7, 0.88, 1.0, 0.2)
	visual.add_child(glow)
	var disc = Polygon2D.new()
	disc.polygon = _circle(16.0, 10)
	disc.color = Color(0.75, 0.9, 1.0, 1.0)
	visual.add_child(disc)
	var core = Polygon2D.new()
	core.polygon = _circle(7.0, 8)
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	visual.add_child(core)
	for i in range(3):
		var spoke = Polygon2D.new()
		var a := TAU * float(i) / 3.0
		spoke.polygon = PackedVector2Array([
			Vector2(cos(a), sin(a)) * 5.0, Vector2(cos(a + 0.3), sin(a + 0.3)) * 19.0,
			Vector2(cos(a - 0.3), sin(a - 0.3)) * 19.0])
		spoke.color = Color(0.6, 0.82, 1.0, 0.95)
		visual.add_child(spoke)

# A spiked head on its chain, drawn back to the fist that swings it. Sized
# and lit to READ at world zoom against the night palette (EYES 2026-07-28:
# the first build was a faint smear -- a flail must look like a threat).
func _build_chainmaul() -> void:
	var glow = Polygon2D.new()   # a dim halo so the head carries in the dark
	glow.polygon = _circle(20.0, 12)
	glow.color = Color(0.9, 0.85, 0.7, 0.18)
	visual.add_child(glow)
	var head = Polygon2D.new()
	head.polygon = _circle(14.0, 10)
	head.color = Color(0.68, 0.66, 0.72, 1.0)
	visual.add_child(head)
	for i in range(6):
		var spike = Polygon2D.new()
		var a := TAU * float(i) / 6.0
		spike.polygon = PackedVector2Array([
			Vector2(cos(a - 0.25), sin(a - 0.25)) * 11.0,
			Vector2(cos(a), sin(a)) * 23.0,
			Vector2(cos(a + 0.25), sin(a + 0.25)) * 11.0])
		spike.color = Color(0.88, 0.86, 0.92, 1.0)
		visual.add_child(spike)
	var gleam = Polygon2D.new()   # one bright facet: motion reads as a flash
	gleam.polygon = PackedVector2Array([
		Vector2(-4, -8), Vector2(3, -11), Vector2(6, -4), Vector2(-1, -2)])
	gleam.color = Color(1.0, 0.98, 0.9, 0.9)
	visual.add_child(gleam)
	rope = Line2D.new()
	rope.width = 4.0
	rope.default_color = Color(0.78, 0.72, 0.6, 0.95)
	rope.z_index = -1
	add_child(rope)

# An angular dart that looks eager to change its mind.
func _build_ricochet() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(15.0, 10)
	glow.color = Color(1.0, 0.85, 0.4, 0.2)
	visual.add_child(glow)
	var dart = Polygon2D.new()
	dart.polygon = PackedVector2Array([
		Vector2(-19, -7), Vector2(17, 0), Vector2(-19, 7), Vector2(-11, 0)])
	dart.color = Color(1.0, 0.88, 0.45, 1.0)
	visual.add_child(dart)

# A pregnant orb with its shards already showing.
func _build_cluster() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(20.0, 12)
	glow.color = Color(0.65, 0.85, 1.0, 0.2)
	visual.add_child(glow)
	var orb = Polygon2D.new()
	orb.polygon = _circle(14.0, 12)
	orb.color = Color(0.7, 0.88, 1.0, 1.0)
	visual.add_child(orb)
	for i in range(4):
		var sat = Polygon2D.new()
		var a := TAU * float(i) / 4.0 + 0.4
		sat.polygon = _circle(4.5, 6)
		sat.position = Vector2(cos(a), sin(a)) * 11.0
		sat.color = Color(1.0, 1.0, 1.0, 1.0)
		visual.add_child(sat)

# The mortar shot: a heavy orb with a sputtering fuse.
func _build_lob() -> void:
	var glow = Polygon2D.new()   # the fuse-light carries the shell in the dark
	glow.polygon = _circle(17.0, 10)
	glow.color = Color(1.0, 0.6, 0.25, 0.2)
	visual.add_child(glow)
	var shell = Polygon2D.new()
	shell.polygon = _circle(13.0, 12)
	shell.color = Color(0.5, 0.46, 0.44, 1.0)
	visual.add_child(shell)
	var band = Polygon2D.new()
	band.polygon = PackedVector2Array([
		Vector2(-10, -2), Vector2(10, -2), Vector2(10, 2), Vector2(-10, 2)])
	band.color = Color(0.85, 0.55, 0.2, 1.0)
	visual.add_child(band)
	var fuse = CPUParticles2D.new()
	fuse.amount = 8
	fuse.lifetime = 0.3
	fuse.position = Vector2(0, -10)
	fuse.initial_velocity_min = 20.0
	fuse.initial_velocity_max = 40.0
	fuse.color = Color(1.0, 0.8, 0.3, 0.9)
	visual.add_child(fuse)

# The lash ribbon: a long tapering flame-tongue.
func _build_lash() -> void:
	var ribbon = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(11):
		var x := lerpf(-30.0, 26.0, float(i) / 10.0)
		pts.append(Vector2(x, -4.5 * (1.0 - absf(x) / 32.0) - sin(x * 0.25) * 2.0))
	for i in range(11):
		var x := lerpf(26.0, -30.0, float(i) / 10.0)
		pts.append(Vector2(x, 4.5 * (1.0 - absf(x) / 32.0) - sin(x * 0.25) * 2.0))
	ribbon.polygon = pts
	ribbon.color = Color(1.0, 0.65, 0.3, 1.0)
	visual.add_child(ribbon)
	var edge = Polygon2D.new()
	edge.polygon = PackedVector2Array([
		Vector2(14, -3), Vector2(34, 0), Vector2(14, 3)])
	edge.color = Color(1.0, 0.95, 0.6, 1.0)
	visual.add_child(edge)
	# a warm trail-glow so the weave reads as a burning ribbon in the dark
	var glow = Polygon2D.new()
	glow.polygon = _circle(16.0, 10)
	glow.color = Color(1.0, 0.7, 0.3, 0.18)
	visual.add_child(glow)
	visual.move_child(glow, 0)

func _build_hook() -> void:
	var curve = Line2D.new()   # the hook itself: a J-curve
	curve.width = 4.0
	curve.default_color = Color(0.75, 0.78, 0.85, 1.0)
	var pts = PackedVector2Array()
	for i in range(8):
		var a = lerp(-PI * 0.15, PI, i / 7.0)
		pts.append(Vector2(10, 0) + Vector2(cos(a), sin(a)) * 9.0)
	curve.points = pts
	visual.add_child(curve)
	rope = Line2D.new()
	rope.width = 2.0
	rope.default_color = Color(0.5, 0.42, 0.3, 0.9)
	rope.z_index = -1
	add_child(rope)

func _build_boomerang() -> void:
	for ang in [0.0, PI * 0.5]:   # two blades in a V
		var blade = Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(22, -4), Vector2(24, 0), Vector2(22, 4)])
		blade.color = Color(0.35, 0.8, 0.75, 0.95)
		blade.rotation = ang
		visual.add_child(blade)

func _circle(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts
