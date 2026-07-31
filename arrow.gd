extends CharacterBody2D

const SPEED = 900.0
const DEFAULT_MAX_RANGE = 700.0

const SFX_BREAK = preload("res://audio/arrow_deflect.wav")

var direction := Vector2.RIGHT
var damage := 0
var knockback_min := 0.0
var knockback_max := 0.0
var start_position := Vector2.ZERO
var has_hit := false
var max_range := DEFAULT_MAX_RANGE
var pierces_terrain := false
var is_crit := false   # set by the player when it rolls a crit for this arrow
var slows_player := false   # caster enemies fire chilling bolts that slow you
var enemy_statuses := []   # Warden keystones: list of {"kind","dur","mag"} applied on hit
var execute_threshold := 0.0   # Archer keystone Killshot: execute a non-boss below this HP frac
var execute_heal := 0.0        # Headhunter: heal this frac of max HP on an execute
var pierce_count := 0   # Marksman Piercing Shot / Skyfall: pass through this many foes
var poison_spread := false   # Warden Contagion: poison also splashes onto nearby foes
var pierced_bodies := []   # bodies already struck this flight (so pierce never double-hits)

# Seeker Bow: the arrow bends mid-flight toward the nearest living enemy
# (capped turn rate, so point-blank dodges still work). Enabled by the
# player's spawn_arrow when the wielded bow's special is "homing".
var homing := false
# 0 = the shot you fired; 1 = a shaft born from a split. Splits are one deep.
var split_gen := 0
var split_at := 0.0      # Twinnock: fraction of range at which one shaft becomes two
var _has_split := false
# THE PLAIN-BOW SOULS (2026-07-31): sixteen material-ladder bows shared two
# verbs (shot, rapid) and differed only in stats. Each now carries ONE small
# named trick -- the rider -- same seam as the whips' tag, the staffs' slam
# and the lobs' riders. Children spawned by tricks never inherit the rider.
var rider := ""
var _rider_spent := false   # one-shot tricks (gutter skip, glass, needle) fire once

const SELF_SCENE = preload("res://arrow.tscn")

# Target selection is what separates the two Seekers. Nearest-first is the
# ordinary rule and neither of them uses it: one hunts the WEAKEST thing in the
# room, the other the BIGGEST, and that single difference does more to tell
# them apart than any amount of recolouring.
func _pick_prey(rule: String) -> Node2D:
	var best: Node2D = null
	var best_score := -1.0
	var best_d := 1e9
	for group_name in HOMING_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d > (460.0 if rule == "wounded" else 420.0):
				continue
			var score := 0.0
			if rule == "wounded":
				# lowest health FRACTION, so it finishes what is already hurt
				if "health" in e and "max_health" in e and float(e.max_health) > 0.0:
					score = 1.0 - (float(e.health) / float(e.max_health))
				else:
					score = 0.0
			else:
				# biggest: a boss outranks everything, then raw max_health
				score = 10000.0 if ("boss_id" in e) else float(e.get("max_health") \
					if "max_health" in e else 1)
			# ties broken by distance, so it never dithers between equals
			if score > best_score or (is_equal_approx(score, best_score) and d < best_d):
				best_score = score
				best_d = d
				best = e
	return best

func _split_seekers() -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	# INSTANTIATE THE SCENE, never the script. arrow.gd's _ready() reaches for
	# $HitArea, which only exists in arrow.tscn -- a script-only `.new()` makes
	# a bare CharacterBody2D with no hit area, no sprite and no collision, so
	# the split shafts were invisible ghosts that could not hit anything AND
	# threw a null error on every spawn. (Shipped in c3ca689; caught by the
	# error spew in the dispatch log, not by any assertion -- the audit only
	# checks that SOMETHING spawned, and something did.)
	for side in [-0.7, 0.7]:
		var s = SELF_SCENE.instantiate()
		s.homing = true
		s.hunt_rule = "wounded"      # the children hunt by the same rule
		s.split_gen = 1
		s.damage = maxi(1, int(round(float(damage) * 0.5)))
		s.element = element
		s.is_crit = is_crit
		s.direction = Vector2(direction.x, direction.y).rotated(side).normalized()
		# arrow.gd has no per-instance speed -- SPEED is a const, and range is
		# what an instance carries. A split shaft is a short-lived one.
		s.max_range = max_range * 0.5
		s.start_position = global_position
		s.add_to_group("player_projectile")
		# DEFERRED, because this runs inside a body_entered callback and Godot
		# is mid-flush of its physics queries -- adding an Area2D right there is
		# "Can't change this state while flushing queries". The split shafts
		# join the world on the next idle frame instead.
		s.global_position = global_position
		host.call_deferred("add_child", s)
var girth := 1.0   # grade-driven scale: a heavier shaft, drawn AND felt
var element := "physical"   # the bow's element (VFX pass): hit bursts pop in its colour
const HOMING_TURN_RATE = 5.0     # radians/sec of steering authority
const HOMING_RANGE = 460.0
const HOMING_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	# The "player_projectile" tag now happens in setup() and ONLY for the player's
	# own arrows -- enemy and boss arrows reuse this same scene, and tagging them
	# here made a mirror boss (boss.gd tick_mirror) reflect its OWN volley.
	start_position = global_position
	rotation = direction.angle()
	apply_girth()
	$HitArea.body_entered.connect(_on_hit_area_body_entered)

# Scales the shaft with its bow's grade -- the drawn arrow AND what it can hit,
# so a mythic bow's shot is genuinely a heavier projectile rather than a
# same-sized one wearing a bigger sprite.
func apply_girth() -> void:
	if is_equal_approx(girth, 1.0):
		return
	# NOTE: one RectangleShape2D resource is shared by the body, the hit area,
	# and every arrow ever fired -- duplicate before touching it or the change
	# leaks into every other arrow in the game.
	for cs in [$CollisionShape2D, $HitArea/HitAreaShape]:
		cs.shape = cs.shape.duplicate()
		if cs.shape is RectangleShape2D:
			cs.shape.size *= girth
	var cr: ColorRect = $ColorRect
	cr.offset_left *= girth
	cr.offset_top *= girth
	cr.offset_right *= girth
	cr.offset_bottom *= girth

func setup(dir: Vector2, dmg: int, kb_min: float, kb_max: float, target_mask: int = 4, pierce_terrain: bool = false, custom_max_range: float = -1.0) -> void:
	direction = dir.normalized()
	damage = dmg
	knockback_min = kb_min
	knockback_max = kb_max
	$HitArea.collision_mask = target_mask
	# Only the PLAYER's arrows are reflectable "player projectiles". A player arrow
	# targets the ENEMY layer (4) and never the player (layer 2); enemy/boss arrows
	# include layer 2 in their mask, so this cleanly excludes them.
	if (target_mask & 2) == 0:
		add_to_group("player_projectile")
	else:
		add_to_group("enemy_projectile")   # targets the player -> the player's DEFEND shades can body-block it
	pierces_terrain = pierce_terrain
	if pierces_terrain:
		collision_mask = 0
	if custom_max_range > 0.0:
		max_range = custom_max_range
	rotation = direction.angle()

func _physics_process(_delta: float) -> void:
	if has_hit:
		return

	if homing:
		steer_toward_prey(_delta)
	velocity = direction * SPEED
	move_and_slide()

	# TWINNOCK: two arrows nocked as one. It leaves the string as a SINGLE shaft
	# and comes apart MID-FLIGHT -- which is a different event from the Pale
	# Seeker's split, and needed its own trigger: that one divides when it HITS
	# something, this one divides on the way there whether or not anything is in
	# the lane. The halves diverge, and neither splits again.
	if split_at > 0.0 and not _has_split \
			and global_position.distance_to(start_position) >= max_range * split_at:
		_has_split = true
		var host := get_parent()
		if host != null and is_instance_valid(host):
			for s in [-1.0, 1.0]:
				var half = SELF_SCENE.instantiate()
				half.setup(direction.rotated(s * 0.20), maxi(1, int(round(damage * 0.7))),
					knockback_min, knockback_max, 4)
				half.split_at = 0.0          # a half never halves again
				half.enemy_statuses = enemy_statuses
				half.girth = girth * 0.8
				half.global_position = global_position
				host.call_deferred("add_child", half)
		despawn()
		return
	# ORCHARD BOW: the shaft is a windfall -- it drops as it flies, and what
	# falls hits harder (the pay is in _rider_pay, the droop is here)
	if rider == "windfall":
		direction = (direction + Vector2(0.0, 0.55 * _delta)).normalized()

	if global_position.distance_to(start_position) > max_range:
		_end_of_flight()
		return

	if not pierces_terrain and get_slide_collision_count() > 0:
		# GUTTER BOW: the first thing the world puts in its way is a lip to
		# SKIP off, not a wall to die on
		if rider == "gutter" and not _rider_spent:
			_gutter_skip()
		else:
			break_arrow()

# TWO SEEKERS, TWO DIFFERENT HUNTERS (2026-07-30).
# They were one weapon with two names: same shaft, same nearest-target rule,
# and I made it worse by giving BOTH the split. The split now belongs to the
# Pale Seeker alone, and removing it from the Hale is what makes the pair read
# as two weapons.
#   "" (default) -- nearest, the ordinary homing flag other bows use
#   "wounded"    -- Pale Seeker: ignores the healthy, bends toward the WEAKEST
#   "biggest"    -- Hale Seeker: one hard turn onto the LARGEST, then locked
var hunt_rule := ""
var _hale_turned := false

func steer_toward_prey(delta: float) -> void:
	# HALE SEEKER commits. It flies dead straight, takes exactly ONE decision at
	# 40% of its range, and never turns again -- a committed hunter that guessed
	# wrong is part of the fantasy, so if nothing qualifies it simply flies on.
	if hunt_rule == "biggest":
		if _hale_turned:
			return
		if global_position.distance_to(start_position) < max_range * 0.4:
			return
		_hale_turned = true
		var big: Node2D = _pick_prey("biggest")
		if big != null:
			direction = (big.global_position - global_position).normalized()
			rotation = direction.angle()
		return
	if hunt_rule == "wounded":
		var hurt: Node2D = _pick_prey("wounded")
		if hurt != null:
			# soft and sweeping, visibly gentler than the default steer
			var want: float = (hurt.global_position - global_position).angle()
			direction = Vector2.RIGHT.rotated(
				rotate_toward(direction.angle(), want, 4.0 * delta))
			rotation = direction.angle()
		return
	var prey: Node2D = null
	var prey_dist = HOMING_RANGE
	for group_name in HOMING_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e is Node2D:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d = global_position.distance_to(e.global_position)
			if d < prey_dist:
				prey_dist = d
				prey = e
	if prey == null:
		return
	var desired = (prey.global_position - global_position).normalized()
	var max_turn = HOMING_TURN_RATE * delta
	var angle_diff = direction.angle_to(desired)
	direction = direction.rotated(clamp(angle_diff, -max_turn, max_turn)).normalized()
	rotation = direction.angle()

func despawn() -> void:
	if has_hit:
		return
	has_hit = true
	queue_free()

func break_arrow() -> void:
	if has_hit:
		return
	has_hit = true
	set_physics_process(false)
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$HitArea.monitoring = false
	var sfx = $SFXPlayer
	sfx.reparent(get_parent())
	sfx.global_position = global_position
	sfx.stream = SFX_BREAK
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	queue_free()

# what THIS hit pays, per rider. Reads the world (poison on the body, the
# shaft's own droop, how far it has flown) rather than a dice roll -- every
# one of these is a fact the player can see and steer.
func _rider_pay(body: Node2D) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	match rider:
		"dart":
			# EMBERDART gathers heat the whole flight: weak point-blank,
			# half again as hard at full stretch
			var fl := clampf(global_position.distance_to(start_position)
				/ maxf(1.0, max_range), 0.0, 1.0)
			return maxi(1, int(round(float(damage) * (0.8 + 0.65 * fl))))
		"windfall":
			# ORCHARD BOW: what FALLS hits harder
			if direction.y > 0.12:
				return int(round(float(damage) * 1.35))
		"briar":
			# BRAMBLEBOW: thorns catch best in a wound already poisoned
			if "status_poison_until" in body and float(body.status_poison_until) > now:
				return int(round(float(damage) * 1.4))
		"reminder":
			# THE POLITE REMINDER: the second notice, as previously discussed
			if float(body.get_meta("reminder_at", -100.0)) > now - 3.0:
				return int(round(float(damage) * 1.6))
	return damage

# what happens AFTER the hit. Returns true when the trick keeps the shaft
# flying (through the burning, through the dead) instead of letting it die.
func _rider_after(body: Node2D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	match rider:
		"crow":
			# CROWCHASER: the hit CAWS -- everything near the struck body
			# startles back a step. No damage; a T1 bow that herds.
			for gname in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
				for e in get_tree().get_nodes_in_group(gname):
					if e == body or not (e is Node2D) or not is_instance_valid(e):
						continue
					if not e.has_method("apply_knockback"):
						continue
					if body.global_position.distance_to((e as Node2D).global_position) > 90.0:
						continue
					e.apply_knockback(1.0 if (e as Node2D).global_position.x
						>= body.global_position.x else -1.0, 150.0)
		"curfew":
			# CURFEW BOW: everyone it passes is sent HOME -- slowed hard
			if body.has_method("apply_status"):
				body.apply_status("slow", 1.0, 0.5)
		"reminder":
			body.set_meta("reminder_at", now)
		"veil":
			# VEILPIERCER: every layer parted sharpens the point for the next
			damage = int(round(float(damage) * 1.25))
		"ash":
			# ASHWOOD: ash remembers fire -- the shaft passes CLEAN through
			# anything already burning, still paying it on the way
			if "status_burn_until" in body and float(body.status_burn_until) > now:
				return true
		"shrike":
			# SHRIKEBOW: a kill does not stop the shaft; it goes through the
			# dead to the living, harder
			if "is_dead" in body and body.is_dead:
				damage = int(round(float(damage) * 1.3))
				return true
	return false

# the tricks that fire where the shaft DIES in the air
func _end_of_flight() -> void:
	if not _rider_spent:
		match rider:
			"gutter":
				_gutter_skip()
				return
			"glass":
				_glass_shatter()
			"needle":
				# NEEDLERAIN: a miss is not nothing -- it falls where it died
				_rider_spent = true
				var host := get_parent()
				if host != null and is_instance_valid(host):
					var nd = SELF_SCENE.instantiate()
					nd.setup(Vector2.DOWN, maxi(1, int(round(float(damage) * 0.6))),
						knockback_min, knockback_max, 4, false, 400.0)
					nd.girth = girth * 0.8
					nd.global_position = global_position + Vector2(0.0, -8.0)
					host.call_deferred("add_child", nd)
	despawn()

# GUTTER BOW: drop flat, skip once, run half the road again at reduced pay
func _gutter_skip() -> void:
	_rider_spent = true
	SfxSynth.play_at(self, global_position, "pop", -15.0, 1.9)   # the skip: a small bright tick off the lip
	direction = Vector2(1.0 if direction.x >= 0.0 else -1.0, 0.0)
	damage = maxi(1, int(round(float(damage) * 0.6)))
	start_position = global_position
	max_range = max_range * 0.5
	global_position.y -= 6.0   # off the lip, not into it

func _glass_shatter() -> void:
	_rider_spent = true
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	for s in [-0.3, 0.0, 0.3]:
		var sl = SELF_SCENE.instantiate()
		sl.setup(direction.rotated(s), maxi(1, int(round(float(damage) * 0.35))),
			knockback_min, knockback_max, 4, false, 140.0)
		sl.girth = girth * 0.7
		sl.global_position = global_position
		host.call_deferred("add_child", sl)

func _on_hit_area_body_entered(body: Node2D) -> void:
	if has_hit or body in pierced_bodies:
		return
	pierced_bodies.append(body)
	# a rider that changes what THIS hit pays does it before the damage lands
	if rider != "" and not body.is_in_group("player"):
		damage = _rider_pay(body)
	if body.has_method("take_damage"):
		if body.is_in_group("player"):
			# the player's take_damage is a coroutine (its i-frames await
			# inside) -- fire and forget; reading its return would hand back
			# a function-state and log an async error on every enemy arrow
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
		else:
			# a boss can absorb the shot outright -- don't print a number for
			# a hit that never landed (void take_damage means "landed")
			var landed = body.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
	# element impact burst (VFX pass): a player shaft pops in the bow's colour
	if is_in_group("player_projectile") and not body.is_in_group("player"):
		HitFx.burst(get_parent(), body.global_position, element, is_crit)
	# THE WEAPON'S OWN SOUL rides the arrow too (WeaponFx 2026-07-28): bows
	# never pass apply_melee_skills, so the fx hook lands here, right after
	# the shot's own damage -- player arrows against non-players only
	if not body.is_in_group("player") and is_instance_valid(body):
		var _pl = get_tree().get_first_node_in_group("player")
		if _pl != null and is_in_group("player_projectile"):
			WeaponFx.on_hit(_pl, body, damage, is_crit)
	# THE SEEKER SPLITS (2026-07-30). A homing shaft used to bend to a target,
	# land, and be over -- which made both Seeker bows the weakest Rares in the
	# game, under the Uncommon median. A seeking arrow should not stop seeking
	# because it found something: on impact it breaks into two lesser shafts
	# that go looking for whatever is left. They do NOT split again (split_gen),
	# or one shot would clear a floor.
	# THE SPLIT BELONGS TO THE PALE SEEKER ALONE. It used to fire on any homing
	# arrow, which meant both Seekers did the same trick and the pair still read
	# as one weapon under two names -- my own fix making the problem worse.
	if hunt_rule == "wounded" and split_gen == 0 and not body.is_in_group("player") \
			and is_in_group("player_projectile"):
		_split_seekers()
	# KILLSHOT (Archer keystone): arrows execute a low-HP non-boss, same as apply_melee_skills
	# does for melee -- routed here because arrows never go through that path (dev 2026-07-26).
	if execute_threshold > 0.0 and not body.is_in_group("player") and not ("boss_id" in body) \
			and "max_health" in body and "health" in body and body.has_method("take_damage"):
		if float(body.health) <= float(body.max_health) * execute_threshold and float(body.health) > 0.0:
			body.take_damage(999999)
			if execute_heal > 0.0:
				var pl = get_tree().get_first_node_in_group("player")
				if pl != null and "health" in pl and pl.has_method("get_max_health"):
					pl.health = mini(pl.get_max_health(), pl.health + int(round(pl.get_max_health() * execute_heal)))
					if pl.has_method("update_health_display"):
						pl.update_health_display()
	# THE GOLDEN GAZE (Wukong road): the player's arrow paints its mark AFTER
	# its own damage lands -- the gold rewards the follow-up, not the marker.
	if is_in_group("player_projectile") and not body.is_in_group("player") \
			and GameState.get_bonus_total("golden_gaze") > 0.0 and body.has_method("take_damage"):
		body.set_meta("gold_mark_until", Time.get_ticks_msec() / 1000.0 + 2.5)
		if body.has_method("show_gold_mark"):
			body.show_gold_mark(2.5)
	if slows_player and body.has_method("apply_slow"):
		body.apply_slow(3.0, 0.55)
	if body.has_method("apply_status"):
		for st in enemy_statuses:
			body.apply_status(str(st.get("kind", "poison")), float(st.get("dur", 4.0)), float(st.get("mag", 0.0)))
	if poison_spread:
		spread_poison_near(body.global_position, body)
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(knockback_min, knockback_max)
		var knockback_dir_sign = 1 if direction.x >= 0 else -1
		body.apply_knockback(knockback_dir_sign, knockback_distance)
	# a rider that acts after the hit -- and may keep the shaft flying
	if rider != "" and not body.is_in_group("player"):
		if _rider_after(body):
			return
	# Piercing Shot: keep flying through the first N enemies instead of stopping
	if pierce_count > 0:
		pierce_count -= 1
		return
	# GLASSTRING: the shaft's DEATH is the weapon -- on its last body it
	# shatters onward into three slivers
	if rider == "glass" and not _rider_spent:
		_glass_shatter()
	has_hit = true
	set_physics_process(false)
	$HitArea.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false
	global_position = Vector2(200000, 200000)
	queue_free()

# Warden Contagion: the poison you just applied also seeps into nearby foes.
func spread_poison_near(center: Vector2, struck: Node2D) -> void:
	for group_name in HOMING_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == struck or not is_instance_valid(e) or not e.has_method("apply_status"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if e.global_position.distance_to(center) <= 120.0:
				e.apply_status("poison", 4.0, 6.0)
