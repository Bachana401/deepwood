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

var beam_tint := Color(0, 0, 0, 0)   # slash: a weapon may colour its crescent
var _mark: Node2D = null             # marcher: the one it was called for
var _lash_len := 0.0                 # edict_lash: how far the law currently reaches
var _lash_t := 0.0
var _lash_line: Line2D = null
var _lash_hits := {}                 # instance_id -> next time this body may be cut again
var court_index := 0                 # courtier: which ancestor tint this shade wears
var court_target := Vector2.ZERO     # courtier: ITS OWN mark (the court spreads out)
var _zen_start := Vector2.ZERO       # zenith_blade: the three-phase swoop
var _zen_target := Vector2.ZERO
var _zen_tint := Color.WHITE
static var _zenith_cycle := 0        # each swing cycles the ancestor tints
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
const EMBEDDED_STACK = preload("res://embedded_stack.gd")

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
	# Terra standard: the wind-crescent is TALL now, and its reach must be
	# honest about it; the zenith image is a whole blade
	if kind == "slash":
		shape.size = Vector2(38, 46) * girth
	elif kind == "zenith_blade":
		shape.size = Vector2(44, 44) * girth
	elif kind == "courtier":
		shape.size = Vector2(40, 40) * girth
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	visual = Node2D.new()
	visual.scale = Vector2.ONE * girth
	add_child(visual)
	match kind:
		"soul_split": _build_soulbolt()
		"slash": _build_slash()
		"zenith_blade":
			# THE LAST WORD: a ghost-image of an ancestor blade. Swoops out,
			# whirls one tight loop at the far point, and comes home. Each
			# swing wears the next tint in the culminated line.
			pierce = true
			_zenith_cycle = (_zenith_cycle + 1) % WeaponFx.LEGACY_TINTS.size()
			_zen_tint = WeaponFx.LEGACY_TINTS[_zenith_cycle]
			_zen_start = global_position
			# the image flies to where the FIGHT is: the nearest living thing
			# ahead of the swing (Zenith flies to the cursor; an aim-direction
			# game sends it to the foe instead), else a half-range point
			_zen_target = global_position + direction * max_distance * 0.5
			var zprey := _nearest_hostile_node(max_distance * 0.8)
			if zprey != null and (zprey.global_position - global_position).dot(direction) > 0.0:
				_zen_target = zprey.global_position
			_behave_state = 0
			_orbit_t = 0.0
			_build_zenithblade()
		"lingering_arc":
			# AFTERLIGHT (T7): the swing does not end. A blade-shaped light
			# hangs where it passed and keeps cutting whatever walks into it.
			monitoring = false
			pierce = true
			_build_lingering_arc()
		"anvil_drop":
			# ANVIL OF ENDINGS (T7): the ending arrives a beat LATE -- a mass
			# falls out of the dark onto the place you struck.
			monitoring = false
			_build_anvil()
		"ground_thorn":
			# THORN OF THE WORLD (T7): the thrust wakes the ground; thorns come
			# up where the point went in (Blood-Thorn-kin, never 1:1).
			monitoring = false
			pierce = true
			_build_ground_thorn()
		"sun_pool":
			# SUNSPILL (T7): what it throws does not explode, it SPILLS -- a
			# burning pool that stays and punishes standing still.
			monitoring = false
			pierce = true
			_build_sun_pool()
		"kneeling_stone":
			# THE MOUNTAIN THAT KNEELS: a boulder that rolls, follows the slope,
			# and hits for whatever pace it has gathered (Staff-of-Earth-kin)
			pierce = true
			_build_boulder()
		"marcher":
			# NIGHT PARADE: one of the procession, walked in from off-camera
			pierce = false
			_build_marcher()
			modulate.a = 0.0
			var mt := create_tween()
			mt.tween_property(self, "modulate:a", 1.0, 0.25)
		"sunder_wave":
			# GRIEF WEARS A CROWN: the blow lands and the GROUND carries it --
			# a front that runs outward through rock, taking each body once as
			# it passes (Golem-Fist-kin, never 1:1). No collision body: a wave
			# is not a projectile and must not stop at the first thing it meets.
			monitoring = false
			pierce = true
			_build_sunder()
		"grief_beam":
			# THE CROWN'S SORROW: not a swing -- a POUR. Narrow lances of grief
			# leave the blade many times a second, each piercing whatever it
			# passes through (Starlight-kin: the identity is hit RATE, and the
			# per-hit number is deliberately small).
			pierce = true
			_build_griefbeam()
		"brazier_flail":
			# THRONE OF EMBERS: a flail whose head, when it comes to REST on the
			# ground, stops being a weapon and becomes a THRONE -- a burning
			# brazier that spits embers until you take it up again
			# (Flower-Pow-kin, never 1:1).
			_build_chainmaul()
			_recolor_brazier()
			spin_speed = 16.0
			pierce = true
		"crown_spear":
			# REGICIDE: a thrown crown-spear that STICKS. The kill is not the
			# throw -- it is the fifth spear, and the sixth pushing the first
			# one out (Daybreak-kin, never 1:1).
			_build_crownspear()
		"edict_lash":
			# THE FINAL EDICT: the law reaches everyone. A segmented arm extends
			# from the wielder THROUGH solid rock, cuts everything along its
			# whole length, and blooms where it touches (Solar-Eruption-kin,
			# never 1:1). It owns its own damage -- no physics body at all.
			monitoring = false
			pierce = true
			_build_edict()
		"courtier":
			# THE WHOLE COURT, SPINNING: a shade of someone you brought home,
			# holding one of the ladder's ancestor blades. Many appear at once
			# (First-Fractal-kin, never 1:1) -- they materialise around the
			# wielder, hold a beat, then all sweep together.
			pierce = true
			_zen_tint = WeaponFx.LEGACY_TINTS[court_index % WeaponFx.LEGACY_TINTS.size()]
			_zen_start = global_position
			# each shade takes ITS OWN mark when the caller assigned one, so a
			# rank of courtiers fans across the row instead of bunching on one
			# body; falls back to the nearest when the court outnumbers the foes
			if court_target != Vector2.ZERO:
				_zen_target = court_target
			else:
				_zen_target = global_position + direction * max_distance
				var cprey := _nearest_hostile_node(max_distance)
				if cprey != null:
					_zen_target = cprey.global_position
			_behave_state = 0
			_orbit_t = 0.0
			_build_courtier()
			modulate.a = 0.0
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
	if kind == "brazier_flail":
		_tick_brazier(delta)
		return
	if kind == "lob":
		_tick_lob(delta)
		return
	if kind == "zenith_blade":
		_tick_zenith(delta)
		return
	if kind == "courtier":
		_tick_courtier(delta)
		return
	if kind == "edict_lash":
		_tick_edict(delta)
		return
	if kind == "sunder_wave":
		_tick_sunder(delta)
		return
	if kind in ["lingering_arc", "ground_thorn", "sun_pool"]:
		_tick_standing_zone(delta)
		return
	if kind == "anvil_drop":
		_tick_anvil(delta)
		return
	if kind == "kneeling_stone":
		_tick_boulder(delta)
		return
	if kind == "marcher":
		_tick_marcher(delta)
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
			# THE MOUNTAIN THAT KNEELS pays for its PACE, not its size
			if kind == "kneeling_stone":
				dealt = boulder_damage()
				_rock_smoke(body.global_position)   # the source bursts white smoke
			# REGICIDE: the spear does NOT merely hit -- it stays in them, and
			# the stack it joins is the weapon (see embedded_stack.gd)
			if kind == "crown_spear":
				var st = EMBEDDED_STACK.drive(body, "regicide", {
					"max": 5, "gap": 0.5, "life": 6.0,
					"tick": maxi(1, int(round(float(damage) * 0.22))),
					"pop": maxi(1, int(round(float(damage) * 1.35))),
					"tint": Color(1.0, 0.86, 0.42), "player": source})
				if st != null:
					st.add_one(damage)
			var landed = body.take_damage(dealt)
			if landed == null or landed:
				# CLUSTER LAW (study/DESIGN_LAWS.md): several projectiles landing
				# together must read as a RAGGED BURST of small numbers, not one
				# blob stacked at the same pixel -- scatter the court's numbers
				var at: Vector2 = body.global_position
				if kind == "courtier":
					at += Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, 10.0))
				FloatingText.spawn(get_parent(), at, dealt, is_crit)
			_apply_status_to(body)
			# Terra semantics (2026-07-28): the wind-wall loses a quarter of its
			# edge for each body it carves through -- crowds FEEL it without
			# being erased by one swing from across the room
			if kind == "slash" and pierce:
				damage = maxi(1, int(round(damage * 0.75)))
			# The Last Word: every landing is punctuated in the image's own tint
			if kind == "zenith_blade":
				_zen_sparkle(body.global_position)
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
	# SUNSPILL (T7): the shell does not just burst, it SPILLS -- a pool of
	# burning daylight is left where it landed
	if rider == "spill":
		var pool = get_script().new()
		pool.kind = "sun_pool"
		pool.damage = maxi(1, int(round(float(damage) * 0.3)))
		pool.element = element
		pool.on_hit_status = on_hit_status
		pool.source = source
		pool.position = global_position
		get_parent().call_deferred("add_child", pool)
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

# THE LAST WORD (Zenith-kin, GIF-measured 2026-07-28): the three-phase swoop.
# Out along a bowed arc (~0.22s), one tight whirl at the far point (~0.34s,
# re-hitting every fifth-second like the orbiter), then home to the wielder's
# CURRENT position, cutting on the way back. ~0.55s more or less, exactly the
# measured cadence. The image never minds terrain -- it is only an image.
var _zen_trail: Line2D = null
func _tick_zenith(delta: float) -> void:
	_orbit_t += delta
	match _behave_state:
		0:
			var t := clampf(_orbit_t / 0.22, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)   # smoothstep: launch soft, arrive keen
			var perp := Vector2(-direction.y, direction.x)
			var prev := global_position
			# minus: the arc bows UP over the field (Godot +y is down)
			global_position = _zen_start.lerp(_zen_target, e) - perp * sin(t * PI) * 88.0
			if (global_position - prev).length_squared() > 1.0:
				rotation = (global_position - prev).angle()
			if t >= 1.0:
				_behave_state = 1
				_orbit_t = 0.0
				_rehit_t = 0.2
		1:
			var a := _orbit_t / 0.34 * TAU
			var prev1 := global_position
			global_position = _zen_target + Vector2(cos(a), sin(a)) * 66.0
			rotation = (global_position - prev1).angle()
			_rehit_t -= delta
			if _rehit_t <= 0.0:
				hit_bodies.clear()   # the whirl grinds: each lap cuts again
				_rehit_t = 0.2
			if _orbit_t >= 0.34:
				_behave_state = 2
				_orbit_t = 0.0
				hit_bodies.clear()   # the return pass is its own sentence
		2:
			var home := _zen_start
			if is_instance_valid(source):
				home = source.global_position
			var to_home := home - global_position
			if to_home.length() <= 44.0 or _orbit_t > 0.8:
				done = true
				queue_free()
				return
			global_position += to_home.normalized() * 1300.0 * delta
			rotation = to_home.angle()
	_zen_trail_tick()

# THE FINAL EDICT (crown spear, Solar-Eruption-kin never 1:1): the arm of the
# law extends over 0.26s, holds a beat, and withdraws over 0.24s. It is drawn
# and damaged along its WHOLE LENGTH, and it does not care about terrain --
# reaching through rock is the entire point of the weapon.
const EDICT_OUT := 0.26
const EDICT_HOLD := 0.1
const EDICT_BACK := 0.24
const EDICT_BAND := 34.0     # how far off the line a body still gets cut
const EDICT_REHIT := 0.22    # the grind: a body inside the arm is cut again

func _tick_edict(delta: float) -> void:
	_lash_t += delta
	# the wielder is the anchor -- the arm stays attached while it works
	if is_instance_valid(source):
		global_position = source.global_position + Vector2(0, -10.0)
	if _lash_t <= EDICT_OUT:
		_lash_len = max_distance * ease(_lash_t / EDICT_OUT, 0.45)
	elif _lash_t <= EDICT_OUT + EDICT_HOLD:
		_lash_len = max_distance
	else:
		var b := (_lash_t - EDICT_OUT - EDICT_HOLD) / EDICT_BACK
		_lash_len = max_distance * (1.0 - clampf(b, 0.0, 1.0))
		if b >= 1.0:
			done = true
			queue_free()
			return
	# the tip traces a shallow arc as it goes out -- the sweep of a sentence
	var sweep := sin(clampf(_lash_t / (EDICT_OUT + EDICT_HOLD), 0.0, 1.0) * PI) * 46.0
	var perp := Vector2(-direction.y, direction.x)
	var tip: Vector2 = global_position + direction * _lash_len - perp * sweep
	_draw_edict(tip)
	_cut_along_edict(tip)

# damage everything within the band of the segment, terrain be damned
func _cut_along_edict(tip: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var a := global_position
	var ab := tip - a
	var ab_len2 := maxf(1.0, ab.length_squared())
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var eid := e.get_instance_id()
			if _lash_hits.has(eid) and now < _lash_hits[eid]:
				continue
			# closest point on the arm to this body
			var t: float = clampf((e.global_position - a).dot(ab) / ab_len2, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			if closest.distance_to(e.global_position) > EDICT_BAND:
				continue
			_lash_hits[eid] = now + EDICT_REHIT
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 6.0)), damage, is_crit)
			_apply_status_to(e)
			_edict_bloom(e.global_position, e)
			if is_instance_valid(source) and source.has_method("on_projectile_hit"):
				source.on_projectile_hit(e, damage)

# Every contact BLOOMS -- and the bloom is not decoration. The measured
# source erupts hit points BEYOND the visible lash (AoE procs), so the flare
# catches bodies standing NEAR the arm as well as on it. Without this the
# weapon is a line; with it, it is a sentence with consequences.
const EDICT_BLOOM_R := 74.0
func _edict_bloom(at: Vector2, struck: Node = null) -> void:
	var host := get_parent()
	if host == null:
		return
	var splash: int = maxi(1, int(round(float(damage) * 0.35)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == struck or not (e is Node2D) or not is_instance_valid(e):
				continue
			if not e.has_method("take_damage") or ("is_dead" in e and e.is_dead):
				continue
			if at.distance_to(e.global_position) > EDICT_BLOOM_R:
				continue
			var landed = e.take_damage(splash)
			if landed == null or landed:
				FloatingText.spawn(host, e.global_position
					+ Vector2(randf_range(-16.0, 16.0), -14.0), splash, false)
			_apply_status_to(e)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := TAU * float(i) / 10.0
		pts.append(Vector2(cos(ang), sin(ang)) * 17.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.86, 0.42, 0.75)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = m
	ring.z_index = 44
	host.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.3, 2.3), 0.24)
	tw.tween_property(ring, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(ring.queue_free)

var _lash_glow: Line2D = null
var _lash_knuckles: Array = []   # the joints, repositioned each frame (no churn)
var _lash_head: Polygon2D = null

func _build_edict() -> void:
	var add_m := CanvasItemMaterial.new()
	add_m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the halo the whole arm sits in
	_lash_glow = Line2D.new()
	_lash_glow.top_level = true
	_lash_glow.width = 28.0 * girth
	_lash_glow.default_color = Color(1.0, 0.66, 0.18, 0.22)
	_lash_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_glow.z_index = 42
	_lash_glow.material = add_m
	add_child(_lash_glow)
	# the core: a solid gold cord, NOT additive, so it stays gold instead of
	# washing out to white against a dark hall
	_lash_line = Line2D.new()
	_lash_line.top_level = true
	_lash_line.width = 11.0 * girth
	_lash_line.default_color = Color(0.98, 0.74, 0.24, 0.96)
	_lash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_line.z_index = 43
	add_child(_lash_line)
	# the joints -- this is what makes it an ARM and not a laser
	for i in range(7):
		var k := Polygon2D.new()
		var kp := PackedVector2Array()
		for j in range(6):
			var a := TAU * float(j) / 6.0
			kp.append(Vector2(cos(a), sin(a)) * 9.0 * girth)
		k.polygon = kp
		k.color = Color(1.0, 0.88, 0.5, 0.95)
		k.top_level = true
		k.z_index = 44
		add_child(k)
		_lash_knuckles.append(k)
	# the writing tip
	_lash_head = Polygon2D.new()
	var hp := PackedVector2Array()
	for j in range(10):
		var a2 := TAU * float(j) / 10.0
		hp.append(Vector2(cos(a2), sin(a2)) * (14.0 if j % 2 == 0 else 6.5) * girth)
	_lash_head.polygon = hp
	_lash_head.color = Color(1.0, 0.95, 0.72, 0.95)
	_lash_head.top_level = true
	_lash_head.z_index = 45
	_lash_head.material = add_m
	add_child(_lash_head)

# the arm is drawn as SEGMENTS -- links of a sentence, brightening to the tip
func _draw_edict(tip: Vector2) -> void:
	if _lash_line == null:
		return
	var pts := PackedVector2Array()
	var n := 16
	var perp := Vector2(-direction.y, direction.x)
	for i in range(n + 1):
		var f := float(i) / float(n)
		var base: Vector2 = global_position.lerp(tip, f)
		# a real serpentine, wide enough to READ at play zoom -- the arm coils
		pts.append(base + perp * sin(f * PI * 2.2 + _lash_t * 7.0) * 15.0 * (1.0 - f * 0.35))
	_lash_line.points = pts
	_lash_line.width = (10.5 + 2.0 * sin(_lash_t * 18.0)) * girth
	if _lash_glow != null:
		_lash_glow.points = pts
	# seat the joints along the cord, biggest at the wrist, smallest at the tip
	for ki in range(_lash_knuckles.size()):
		var k: Polygon2D = _lash_knuckles[ki]
		var idx: int = int(round(float(ki + 1) / float(_lash_knuckles.size() + 1) * float(n)))
		k.global_position = pts[clampi(idx, 0, pts.size() - 1)]
		var taper := 1.0 - 0.55 * (float(ki) / float(maxi(1, _lash_knuckles.size() - 1)))
		k.scale = Vector2.ONE * taper
		k.visible = _lash_len > 60.0
	if _lash_head != null:
		_lash_head.global_position = pts[pts.size() - 1]
		_lash_head.rotation = _lash_t * 5.0
		_lash_head.visible = _lash_len > 40.0

# THE WHOLE COURT, SPINNING: materialise (0.14s, the court arrives) -> sweep
# together at the mark -> fade out. Deliberately BUSY: this is the culmination
# weapon, the one place the crown rule ("cleaner, not busier") is broken on
# purpose, exactly as Zenith breaks it.
func _tick_courtier(delta: float) -> void:
	_orbit_t += delta
	match _behave_state:
		0:
			# the shade fades in and draws itself up to full height
			var t := clampf(_orbit_t / 0.14, 0.0, 1.0)
			modulate.a = t
			visual.scale = Vector2.ONE * girth * lerpf(0.45, 1.0, t)
			# it faces its mark while it gathers
			var face := _zen_target - global_position
			if face.length_squared() > 1.0:
				visual.scale.x = absf(visual.scale.x) * (-1.0 if face.x < 0.0 else 1.0)
			if t >= 1.0:
				_behave_state = 1
				_orbit_t = 0.0
				# the mark may have moved (or died) while the court gathered
				var late := _nearest_hostile_node(max_distance)
				if late != null:
					_zen_target = late.global_position
				direction = (_zen_target - global_position).normalized()
		1:
			global_position += direction * 1150.0 * delta
			rotation = direction.angle()
			traveled += 1150.0 * delta
			if traveled >= max_distance * 1.15 or _orbit_t > 0.55:
				_behave_state = 2
				_orbit_t = 0.0
		2:
			global_position += direction * 420.0 * delta
			modulate.a = maxf(0.0, 1.0 - _orbit_t / 0.2)
			if _orbit_t >= 0.2:
				done = true
				queue_free()
				return
	_zen_trail_tick()

func _zen_trail_tick() -> void:
	if _zen_trail == null:
		_zen_trail = Line2D.new()
		_zen_trail.top_level = true
		_zen_trail.width = 7.0
		_zen_trail.default_color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.5)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_zen_trail.material = m
		add_child(_zen_trail)
	_zen_trail.add_point(global_position)
	while _zen_trail.get_point_count() > 16:
		_zen_trail.remove_point(0)

# the sparkle burst every zenith landing pops -- white heart, tinted rim
func _zen_sparkle(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	for i in range(4):
		var s := Polygon2D.new()
		s.polygon = PackedVector2Array([Vector2(-1.6, 0), Vector2(0, -5), Vector2(1.6, 0), Vector2(0, 5)])
		s.color = Color.WHITE if i % 2 == 0 else Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.95)
		var m2 := CanvasItemMaterial.new()
		m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m2
		host.add_child(s)
		s.global_position = at + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position + Vector2(randf_range(-26, 26), randf_range(-30, 6)), 0.4)
		tw.tween_property(s, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(s.queue_free)

# the ghost of an ancestor blade: a full sword-image drawn point-first (+X),
# glowing in its legacy tint with a pale core -- The Last Word remembers
# every sword that was folded into it
# a courtier of the Whole Court: the shade of someone you brought home, drawn
# point-first (+X) -- a hooded cloak streaming behind an ancestor blade. The
# blade wears the tint; the shade stays dark, so a swing reads as SEVERAL
# distinct people arriving, not one effect repeated.
# THRONE OF EMBERS (crown melee, Flower-Pow-kin never 1:1) --------------
# whirl -> hurl -> FALL -> sit as a brazier spitting embers -> haul home.
# The study's find: a flail head RESTED on the ground becoming a turret is a
# whole second weapon hiding inside the first, and it costs the player their
# flail to use it -- a real trade, not a free bonus.
const BRAZ_WHIRL := 0.55
const BRAZ_SIT := 3.2        # seconds the throne burns before it is taken up
const BRAZ_SPIT := 0.45      # seconds between embers
var _braz_spit_t := 0.0

const CHAIN_BAND := 26.0
const CHAIN_REHIT := 0.35
var _chain_hits := {}

# THE CHAIN BITES (fidelity pass). The source's chain hits everything along
# its length -- three bodies at once in the measured footage -- and our own
# DESIGN_LAWS guardrail says exactly "flail launches must damage along the
# chain, not just the head". It was drawn but inert. Now it is a line of
# damage from the wielder to the head, at a third of the head's bite.
func _chain_bite() -> void:
	if not is_instance_valid(source):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var a: Vector2 = source.global_position
	var ab: Vector2 = global_position - a
	var ab_len2: float = maxf(1.0, ab.length_squared())
	var bite: int = maxi(1, int(round(float(damage) * 0.34)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var eid := e.get_instance_id()
			if _chain_hits.has(eid) and now < _chain_hits[eid]:
				continue
			var t: float = clampf((e.global_position - a).dot(ab) / ab_len2, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			if closest.distance_to(e.global_position) > CHAIN_BAND:
				continue
			_chain_hits[eid] = now + CHAIN_REHIT
			var landed = e.take_damage(bite)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-14.0, 14.0), -18.0), bite, false)
			_apply_status_to(e)

func _tick_brazier(delta: float) -> void:
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	# the chain is live from the moment it is out until it comes home
	if _behave_state >= 1:
		_chain_bite()
	match _behave_state:
		0:   # the whirl, tight around the wielder
			if not is_instance_valid(source):
				queue_free()
				return
			if visual:
				visual.rotation += spin_speed * delta
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.3:
				_rehit_t = 0.0
				hit_bodies.clear()
			var r := (40.0 + _orbit_t * 70.0) * girth
			var side := 1.0 if direction.x >= 0.0 else -1.0
			global_position = source.global_position \
				+ Vector2(cos(_orbit_t * 9.0 * side), sin(_orbit_t * 9.0 * side)) * r
			if _orbit_t >= BRAZ_WHIRL:
				_behave_state = 1
				hit_bodies.clear()
				traveled = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -9.0, 0.8)
		1:   # the hurl
			if visual:
				visual.rotation += spin_speed * delta
			var step := speed * 1.3 * delta
			global_position += direction * step
			traveled += step
			if traveled >= max_distance:
				_behave_state = 2
				_vel_y = 0.0
				hit_bodies.clear()
		2:   # the fall: the head looks for somewhere to sit
			if visual:
				visual.rotation += spin_speed * 0.5 * delta
			_vel_y += 1500.0 * delta
			var drop := _vel_y * delta
			global_position.y += drop
			if _find_floor_below(maxf(drop, 6.0) + 10.0):
				_behave_state = 3
				_orbit_t = 0.0
				_braz_spit_t = 0.0
				spin_speed = 0.0
				_seat_the_throne()
			elif _vel_y > 1400.0:      # nothing under it: give up and come back
				_behave_state = 4
		3:   # THE THRONE: it sits, and it burns
			_orbit_t += delta
			_braz_spit_t += delta
			if _braz_spit_t >= BRAZ_SPIT:
				_braz_spit_t = 0.0
				_spit_ember()
			if _orbit_t >= BRAZ_SIT:
				_behave_state = 4
		_:   # hauled home on the chain
			if not is_instance_valid(source):
				queue_free()
				return
			var to_src: Vector2 = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return
			global_position += to_src.normalized() * speed * 1.25 * delta

# is there ground within `dist` below the head?
func _find_floor_below(dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, dist))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y - 12.0
		return true
	return false

# the moment it becomes furniture: a seat of coals, and the fire takes
func _seat_the_throne() -> void:
	SfxSynth.play_at(self, global_position, "thud", -8.0, 0.7)
	var coals := Polygon2D.new()
	coals.polygon = _circle(26.0, 12)
	coals.color = Color(1.0, 0.45, 0.12, 0.3)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	coals.material = m
	coals.z_index = -1
	visual.add_child(coals)
	var tw := coals.create_tween()
	tw.set_loops()
	tw.tween_property(coals, "scale", Vector2(1.25, 1.25), 0.5)
	tw.tween_property(coals, "scale", Vector2(0.9, 0.9), 0.5)

# an ember leaves the throne for whoever is nearest
func _spit_ember() -> void:
	var prey := _nearest_hostile_node(560.0)
	var dir := Vector2(1, -0.25).normalized() if prey == null \
		else (prey.global_position - global_position).normalized()
	var e = get_script().new()
	e.kind = "fireball"
	e.damage = maxi(1, int(round(float(damage) * 0.45)))
	e.speed = 430.0
	e.max_distance = 620.0
	e.aoe_radius = 54.0
	e.girth = 0.7 * girth
	e.direction = dir
	e.element = element
	e.on_hit_status = on_hit_status
	e.source = source
	e.position = global_position + Vector2(0, -14)
	get_parent().add_child(e)
	SfxSynth.play_at(self, global_position, "pop", -19.0, 1.4)

# the maul, but forged as a seat of embers rather than cold iron.
# _build_chainmaul lays out: [0] halo, [1] head, [2..7] six spikes, [8] gleam.
func _recolor_brazier() -> void:
	if visual == null:
		return
	var polys := []
	for c in visual.get_children():
		if c is Polygon2D:
			polys.append(c)
	for i in range(polys.size()):
		var p: Polygon2D = polys[i]
		if i == 0:
			p.color = Color(1.0, 0.5, 0.14, 0.3)        # the heat it gives off
		elif i == 1:
			p.color = Color(0.3, 0.17, 0.12, 1.0)       # blackened iron
		elif i == polys.size() - 1:
			p.color = Color(1.0, 0.9, 0.58, 0.95)       # the live coal
		else:
			p.color = Color(0.93, 0.44, 0.13, 1.0)      # ember-lit spikes

# --- T7 STANDING ZONES ---------------------------------------------------
# One tick serves three weapons, because the study's aftermath family is one
# idea wearing three coats: something STAYS where the attack happened and
# keeps working. Afterlight's hanging blade-light, Thorn of the World's
# risen spikes, Sunspill's burning pool. Duration, radius and bite differ;
# the machinery does not.
var _zone_life := 0.0
var _zone_max := 1.6
var _zone_r := 60.0
var _zone_gap := 0.35
var _zone_t := 0.0

func _tick_standing_zone(delta: float) -> void:
	_zone_life += delta
	_zone_t += delta
	var frac: float = clampf(_zone_life / _zone_max, 0.0, 1.0)
	if visual:
		visual.modulate.a = 1.0 - frac * frac      # holds, then goes quickly
	if _zone_t >= _zone_gap:
		_zone_t = 0.0
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if global_position.distance_to(e.global_position) > _zone_r:
					continue
				var landed = e.take_damage(damage)
				if landed == null or landed:
					FloatingText.spawn(get_parent(), e.global_position
						+ Vector2(randf_range(-16.0, 16.0), -20.0), damage, false)
				_apply_status_to(e)
	if _zone_life >= _zone_max:
		done = true
		queue_free()

# AFTERLIGHT: the shape of the swing, left behind in the air
func _build_lingering_arc() -> void:
	_zone_max = 1.7
	_zone_r = 66.0
	_zone_gap = 0.34
	for pass_i in range(2):
		var arc := Polygon2D.new()
		var pts := PackedVector2Array()
		var outer := 52.0 if pass_i == 0 else 44.0
		var inner := 34.0 if pass_i == 0 else 30.0
		for i in range(11):
			var a := lerpf(-1.05, 1.05, float(i) / 10.0)
			pts.append(Vector2(cos(a), sin(a)) * outer)
		for i in range(11):
			var a2 := lerpf(1.05, -1.05, float(i) / 10.0)
			pts.append(Vector2(cos(a2), sin(a2)) * inner)
		arc.polygon = pts
		arc.color = Color(1.0, 0.94, 0.72, 0.3) if pass_i == 0 else Color(1.0, 1.0, 0.9, 0.6)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		arc.material = m
		visual.add_child(arc)

# THORN OF THE WORLD: three spikes come up out of the floor
func _build_ground_thorn() -> void:
	_zone_max = 1.3
	_zone_r = 74.0
	_zone_gap = 0.3
	for i in range(3):
		var th := Polygon2D.new()
		var h := 46.0 - absf(float(i) - 1.0) * 12.0
		th.polygon = PackedVector2Array([
			Vector2(-7.0, 8.0), Vector2(-2.5, -h), Vector2(2.5, -h), Vector2(7.0, 8.0)])
		th.color = Color(0.5, 0.14, 0.2, 0.95)
		th.position = Vector2(-42.0 + 42.0 * float(i), 8.0)
		visual.add_child(th)
		var lip := Polygon2D.new()
		lip.polygon = PackedVector2Array([
			Vector2(-2.0, -h * 0.55), Vector2(0.0, -h), Vector2(2.0, -h * 0.55)])
		lip.color = Color(0.95, 0.4, 0.45, 0.9)
		lip.position = th.position
		visual.add_child(lip)
		# they ERUPT rather than appear
		th.scale.y = 0.1
		var tw := th.create_tween()
		tw.tween_property(th, "scale:y", 1.0, 0.14).set_delay(0.05 * float(i))

# SUNSPILL: a pool of daylight burning on the floor
func _build_sun_pool() -> void:
	_zone_max = 4.2
	_zone_r = 82.0
	_zone_gap = 0.4
	var pool := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 80.0, sin(a) * 20.0))
	pool.polygon = pts
	pool.color = Color(1.0, 0.62, 0.16, 0.42)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = m
	visual.add_child(pool)
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in range(14):
		var a2 := TAU * float(i) / 14.0
		cpts.append(Vector2(cos(a2) * 52.0, sin(a2) * 12.0))
	core.polygon = cpts
	core.color = Color(1.0, 0.86, 0.4, 0.5)
	core.material = m
	visual.add_child(core)
	var tw := pool.create_tween()
	tw.set_loops()
	tw.tween_property(pool, "scale", Vector2(1.06, 1.15), 0.6)
	tw.tween_property(pool, "scale", Vector2(0.96, 0.9), 0.6)

# --- ANVIL OF ENDINGS: the mass that arrives late ------------------------
var _anvil_t := 0.0
var _anvil_target := Vector2.ZERO
const ANVIL_FALL := 0.45

func _tick_anvil(delta: float) -> void:
	if done:
		return   # landed: it is sitting there fading, not falling
	_anvil_t += delta
	var f: float = clampf(_anvil_t / ANVIL_FALL, 0.0, 1.0)
	# it comes down out of the dark, accelerating
	global_position = Vector2(_anvil_target.x,
		lerpf(_anvil_target.y - 420.0, _anvil_target.y, f * f))
	if f < 1.0:
		return
	# landing
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) > 92.0:
				continue
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position + Vector2(0, -28.0), damage, true)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback * 1.4)
	_rock_smoke(global_position + Vector2(0, 12.0))
	SfxSynth.play_at(self, global_position, "thud", -4.0, 0.55)
	# LET IT BE SEEN. Freeing on the landing frame meant the mass arrived and
	# vanished in the same instant -- on film there was smoke and a number but
	# no anvil. It sits for a beat, then sinks away.
	done = true
	if _anvil_shadow != null and is_instance_valid(_anvil_shadow):
		_anvil_shadow.visible = false
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)

func set_anvil_target(at: Vector2) -> void:
	_anvil_target = at
	global_position = Vector2(at.x, at.y - 420.0)
	# the tell sits on the GROUND, not on the falling mass -- it is top_level
	# so it would otherwise have stayed pinned at the world origin
	if _anvil_shadow != null and is_instance_valid(_anvil_shadow):
		_anvil_shadow.global_position = at + Vector2(0, 12.0)

var _anvil_shadow: Polygon2D = null
func _build_anvil() -> void:
	# THE TELL: a shadow on the ground the whole time it is falling, so the
	# player (and anything with sense) knows exactly where the mass lands
	_anvil_shadow = Polygon2D.new()
	_anvil_shadow.polygon = PackedVector2Array([
		Vector2(-34, 0), Vector2(-20, -7), Vector2(20, -7), Vector2(34, 0),
		Vector2(20, 7), Vector2(-20, 7)])
	_anvil_shadow.color = Color(0.05, 0.04, 0.07, 0.45)
	_anvil_shadow.top_level = true
	_anvil_shadow.z_index = 3
	add_child(_anvil_shadow)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-30, -6), Vector2(-16, -26), Vector2(20, -26), Vector2(30, -8),
		Vector2(24, 14), Vector2(-24, 14)])
	body.color = Color(0.19, 0.18, 0.22, 1.0)
	visual.add_child(body)
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([
		Vector2(-16, -26), Vector2(20, -26), Vector2(18, -18), Vector2(-14, -18)])
	face.color = Color(0.42, 0.4, 0.46, 1.0)
	visual.add_child(face)

# --- GRIEF WEARS A CROWN: the ground carries the blow ------------------
const SUNDER_SPEED := 1400.0
const SUNDER_BAND := 42.0        # how thick the front is
var _wave_r := 0.0
var _wave_left: Polygon2D = null
var _wave_right: Polygon2D = null

func _tick_sunder(delta: float) -> void:
	_wave_r += SUNDER_SPEED * delta
	if _wave_r >= max_distance:
		done = true
		queue_free()
		return
	var fade: float = 1.0 - (_wave_r / max_distance)
	for w in [_wave_left, _wave_right]:
		if w != null and is_instance_valid(w):
			w.position.x = _wave_r * (-1.0 if w == _wave_left else 1.0)
			w.scale = Vector2(1.0, lerpf(0.5, 1.5, 1.0 - fade))
			w.modulate.a = fade
	# each body is taken ONCE, as the front reaches it -- a wave passes
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead or hit_bodies.has(e):
				continue
			var dx: float = absf(e.global_position.x - global_position.x)
			var dy: float = absf(e.global_position.y - global_position.y)
			if dy > 90.0 or absf(dx - _wave_r) > SUNDER_BAND:
				continue
			hit_bodies.append(e)
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-18.0, 18.0), -24.0), damage, is_crit)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback * 1.6)
			if is_instance_valid(source) and source.has_method("on_projectile_hit"):
				source.on_projectile_hit(e, damage)

# two crescents of displaced force running away from the blow
func _build_sunder() -> void:
	for side in [-1.0, 1.0]:
		var c := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(9):
			var a := lerpf(-1.15, 1.15, float(i) / 8.0)
			pts.append(Vector2(cos(a) * 16.0 * float(side), sin(a) * 30.0))
		for i in range(9):
			var a2 := lerpf(1.15, -1.15, float(i) / 8.0)
			pts.append(Vector2(cos(a2) * 3.0 * float(side), sin(a2) * 26.0))
		c.polygon = pts
		c.color = Color(1.0, 0.74, 0.36, 0.85)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = m
		visual.add_child(c)
		if side < 0.0: _wave_left = c
		else: _wave_right = c

# --- THE MOUNTAIN THAT KNEELS: damage is the boulder's own speed --------
var _roll_life := 0.0

func _tick_boulder(delta: float) -> void:
	_roll_life += delta
	_vel_y += 1500.0 * delta
	global_position += direction * speed * delta + Vector2(0, _vel_y * delta)
	traveled += speed * delta
	# sit on the ground and follow the slope, so a hill becomes a multiplier
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -18.0),
		global_position + Vector2(0, 26.0))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit:
		var was_falling := _vel_y
		global_position.y = hit.position.y - 16.0
		if _vel_y > 0.0:
			# rolling downhill FEEDS it; a flat floor just carries it
			speed = minf(1250.0, speed + _vel_y * 0.25)
			_vel_y = 0.0
		# a real landing kicks dust; a gentle roll along the floor does not
		if was_falling > 420.0:
			_rock_smoke(global_position + Vector2(0, 14.0))
	if visual:
		visual.rotation += (speed / 34.0) * delta * (1.0 if direction.x >= 0.0 else -1.0)
	if traveled >= max_distance or _roll_life > 6.0:
		done = true
		queue_free()

# the boulder's bite is its pace: slow rock barely stings, a boulder at
# full roll flattens (the climbing numbers ARE the weapon -- DESIGN_LAWS 7)
func boulder_damage() -> int:
	return maxi(1, int(round(float(damage) * clampf(speed / 720.0, 0.35, 1.6))))

# white smoke, the way a heavy rock actually announces itself (fidelity pass)
func _rock_smoke(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	for i in range(4):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(7.0, 12.0), 8)
		puff.color = Color(0.92, 0.9, 0.86, 0.6)
		puff.z_index = 41
		host.add_child(puff)
		puff.global_position = at + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 8.0))
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "scale", Vector2(2.1, 2.1), 0.42)
		tw.tween_property(puff, "global_position",
			puff.global_position + Vector2(randf_range(-18.0, 18.0), -22.0), 0.42)
		tw.tween_property(puff, "modulate:a", 0.0, 0.42)
		tw.chain().tween_callback(puff.queue_free)

func _build_boulder() -> void:
	var rock := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(11):
		var a := TAU * float(i) / 11.0
		var r := 21.0 + sin(float(i) * 2.3) * 4.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	rock.polygon = pts
	rock.color = Color(0.36, 0.33, 0.31, 1.0)
	visual.add_child(rock)
	for i in range(4):
		var chip := Polygon2D.new()
		var a2 := TAU * float(i) / 4.0 + 0.4
		chip.polygon = PackedVector2Array([
			Vector2(cos(a2), sin(a2)) * 8.0,
			Vector2(cos(a2 + 0.5), sin(a2 + 0.5)) * 15.0,
			Vector2(cos(a2 + 0.9), sin(a2 + 0.9)) * 7.0])
		chip.color = Color(0.47, 0.44, 0.41, 1.0)
		visual.add_child(chip)

# --- NIGHT PARADE: they come in from off the edge of the world ----------
func _tick_marcher(delta: float) -> void:
	_orbit_t += delta
	var prey: Node2D = null
	if _mark != null and is_instance_valid(_mark) and not _is_dead_node(_mark):
		prey = _mark
	else:
		prey = _nearest_hostile_node(900.0)
		_mark = prey
	if prey == null or _orbit_t > 4.0:
		modulate.a = maxf(0.0, modulate.a - delta * 3.0)
		if modulate.a <= 0.05:
			done = true
			queue_free()
		return
	# a marcher WALKS: it closes horizontally and ignores the terrain
	var to_prey: Vector2 = prey.global_position - global_position
	global_position += Vector2(signf(to_prey.x), 0).normalized() * 420.0 * delta
	global_position.y = lerpf(global_position.y, prey.global_position.y, 2.2 * delta)
	if visual:
		visual.scale.x = absf(visual.scale.x) * (-1.0 if to_prey.x < 0.0 else 1.0)
		visual.position.y = sin(_orbit_t * 7.0) * 3.0   # the walking bob
	if absf(to_prey.x) < 30.0 and absf(to_prey.y) < 60.0:
		if prey.has_method("take_damage"):
			var landed = prey.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), prey.global_position
					+ Vector2(randf_range(-20.0, 20.0), -30.0), damage, is_crit)
			_apply_status_to(prey)
		done = true
		queue_free()

func _is_dead_node(n: Node) -> bool:
	return "is_dead" in n and n.is_dead

# a marcher: a hooded shade carrying a small lantern -- the parade reads as
# PEOPLE, which is what ties it to the rescue story
func _build_marcher() -> void:
	var cloak := Polygon2D.new()
	cloak.polygon = PackedVector2Array([
		Vector2(0, -26), Vector2(9, -12), Vector2(7, 14), Vector2(-7, 14), Vector2(-9, -12)])
	cloak.color = Color(0.13, 0.12, 0.2, 0.88)
	visual.add_child(cloak)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(7, -22), Vector2(4, -14), Vector2(-4, -14), Vector2(-7, -22)])
	hood.color = Color(0.07, 0.07, 0.12, 0.95)
	visual.add_child(hood)
	var lantern := Polygon2D.new()
	lantern.polygon = PackedVector2Array([
		Vector2(11, -4), Vector2(16, -4), Vector2(16, 3), Vector2(11, 3)])
	lantern.color = Color(1.0, 0.82, 0.42, 0.95)
	visual.add_child(lantern)
	var glow := Polygon2D.new()
	glow.polygon = _circle(15.0, 10)
	glow.color = Color(1.0, 0.78, 0.36, 0.3)
	glow.position = Vector2(13.5, 0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	visual.add_child(glow)

# THE CROWN'S SORROW's lance: a narrow spindle of pale light with a white
# core -- small, fast, and there are always several in the air
func _build_griefbeam() -> void:
	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(4, -6), Vector2(-16, 0), Vector2(4, 6)])
	halo.color = Color(0.62, 0.78, 1.0, 0.34)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = m
	visual.add_child(halo)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(25, 0), Vector2(3, -2.6), Vector2(-12, 0), Vector2(3, 2.6)])
	body.color = Color(0.82, 0.9, 1.0, 0.95)
	visual.add_child(body)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(2, -1.1), Vector2(-8, 0), Vector2(2, 1.1)])
	core.color = Color(1.0, 1.0, 1.0, 0.98)
	visual.add_child(core)

# REGICIDE's thrown spear: a slim crown-gold lance, point-first
func _build_crownspear() -> void:
	# THE STREAK (fidelity pass): the source drags a ~2.5 player-height flame
	# behind every javelin, and our own law says the TRAIL is the signature.
	# A long tapering additive wedge reads as fire at speed without costing a
	# per-frame trail node.
	var streak := Polygon2D.new()
	streak.polygon = PackedVector2Array([
		Vector2(-24, -5.0), Vector2(-46, -2.6), Vector2(-70, 0),
		Vector2(-46, 2.6), Vector2(-24, 5.0)])
	streak.color = Color(1.0, 0.6, 0.2, 0.42)
	var sm := CanvasItemMaterial.new()
	sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	streak.material = sm
	visual.add_child(streak)
	var streak_hot := Polygon2D.new()
	streak_hot.polygon = PackedVector2Array([
		Vector2(-22, -2.2), Vector2(-38, -1.1), Vector2(-52, 0),
		Vector2(-38, 1.1), Vector2(-22, 2.2)])
	streak_hot.color = Color(1.0, 0.88, 0.5, 0.55)
	streak_hot.material = sm
	visual.add_child(streak_hot)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(6, -7), Vector2(-24, -4), Vector2(-24, 4), Vector2(6, 7)])
	glow.color = Color(1.0, 0.82, 0.36, 0.3)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(10, -1.8), Vector2(-26, -1.8), Vector2(-26, 1.8), Vector2(10, 1.8)])
	shaft.color = Color(0.46, 0.36, 0.22, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(9, -5.5), Vector2(4, 0), Vector2(9, 5.5)])
	head.color = Color(1.0, 0.9, 0.5, 0.98)
	visual.add_child(head)
	var fletch := Polygon2D.new()
	fletch.polygon = PackedVector2Array([
		Vector2(-20, -1.8), Vector2(-30, -7.0), Vector2(-27, 0), Vector2(-30, 7.0), Vector2(-20, 1.8)])
	fletch.color = Color(0.88, 0.72, 0.3, 0.9)
	visual.add_child(fletch)

func _build_courtier() -> void:
	var cloak := Polygon2D.new()
	cloak.polygon = PackedVector2Array([
		Vector2(6, -9), Vector2(-6, -11), Vector2(-22, -4),
		Vector2(-26, 0), Vector2(-22, 4), Vector2(-6, 11), Vector2(6, 9)])
	cloak.color = Color(0.09, 0.08, 0.13, 0.72)
	visual.add_child(cloak)
	var hem := Polygon2D.new()   # a tint-lit edge so each shade is legible
	hem.polygon = PackedVector2Array([
		Vector2(-6, -11), Vector2(-22, -4), Vector2(-26, 0), Vector2(-21, -1), Vector2(-7, -8)])
	hem.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.55)
	visual.add_child(hem)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(8, -6), Vector2(2, -9), Vector2(-4, -5), Vector2(-3, 4), Vector2(4, 6), Vector2(9, 2)])
	hood.color = Color(0.05, 0.05, 0.09, 0.9)
	visual.add_child(hood)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(34, 0), Vector2(10, -8), Vector2(-2, -5), Vector2(-4, 0), Vector2(-2, 5), Vector2(10, 8)])
	glow.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.32)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(8, -4), Vector2(-2, -2.5), Vector2(-2, 2.5), Vector2(8, 4)])
	blade.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.95)
	visual.add_child(blade)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(8, -1.6), Vector2(0, -1.0), Vector2(0, 1.0), Vector2(8, 1.6)])
	core.color = Color(1.0, 1.0, 1.0, 0.8)
	visual.add_child(core)

func _build_zenithblade() -> void:
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(6, -11), Vector2(-20, -7), Vector2(-26, 0),
		Vector2(-20, 7), Vector2(6, 11)])
	glow.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.35)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(4, -6), Vector2(-14, -4), Vector2(-14, 4), Vector2(4, 6)])
	blade.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.9)
	visual.add_child(blade)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(22, 0), Vector2(4, -2.5), Vector2(-12, -1.5), Vector2(-12, 1.5), Vector2(4, 2.5)])
	core.color = Color(1.0, 1.0, 1.0, 0.85)
	visual.add_child(core)
	var guard := Polygon2D.new()
	guard.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(-11, 0), Vector2(-14, 8), Vector2(-17, 0)])
	guard.color = Color(minf(1.0, _zen_tint.r + 0.2), minf(1.0, _zen_tint.g + 0.2), minf(1.0, _zen_tint.b + 0.2), 0.95)
	visual.add_child(guard)

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
	# TERRA STANDARD (2026-07-28, GIF-measured): the beam IS the weapon -- a
	# tall readable crescent near player height, riding an additive wake that
	# streaks behind it. A weapon may tint the whole thing (beam_tint).
	var tint := beam_tint if beam_tint.a > 0.0 else Color(0.75, 0.95, 1.0)
	var wake = Polygon2D.new()   # the streak: a soft afterglow swept backward
	var wpts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.75, 0.75, i / 8.0)
		wpts.append(Vector2(cos(a), sin(a)) * 24.0)
	for i in range(9):
		var a = lerp(0.75, -0.75, i / 8.0)
		wpts.append(Vector2(cos(a) * 24.0 - 34.0, sin(a) * 21.0))
	wake.polygon = wpts
	wake.color = Color(tint.r, tint.g, tint.b, 0.28)
	var wm := CanvasItemMaterial.new()
	wm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wake.material = wm
	visual.add_child(wake)
	var arc = Polygon2D.new()   # the blade of wind itself
	var pts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.95, 0.95, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 27.0)
	for i in range(9):
		var a = lerp(0.95, -0.95, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	arc.polygon = pts
	arc.color = Color(tint.r, tint.g, tint.b, 0.9)
	visual.add_child(arc)
	var edge = Polygon2D.new()   # a bright leading lip
	var epts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.95, 0.95, i / 8.0)
		epts.append(Vector2(cos(a), sin(a)) * 27.0)
	for i in range(9):
		var a = lerp(0.95, -0.95, i / 8.0)
		epts.append(Vector2(cos(a), sin(a)) * 24.0)
	edge.polygon = epts
	edge.color = Color(minf(1.0, tint.r + 0.25), minf(1.0, tint.g + 0.25), minf(1.0, tint.b + 0.25), 0.95)
	visual.add_child(edge)

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
