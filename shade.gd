extends Node2D

# A shade -- a soldier of living shadow in the Shadow Monarch's service
# (Rise, Shade: 5/7+, see player.gd raise_shade). When a foe falls, its shadow
# tears free of the ground, takes the Monarch's colours and hunts beside him:
# it drifts to the nearest living enemy and cuts it down with claws of dark,
# then gutters out when its borrowed time is spent. At 7/7 (true form) shades
# never expire -- a standing army of the dark. Drawn procedurally (a hooded
# wraith with burning violet eyes and a ragged hem) so it reads as PURE SHADOW
# next to any painted enemy skin.

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]
const FLY_SPEED := 250.0
const SEEK_RANGE := 760.0
const HOME_RANGE := 46.0      # hover ring around the Monarch when idle

# --- the legion: some kill, some guard -------------------------------------
# A shade army that all charges at once is a swarm, not a legion. Each shade
# takes a ROLE and keeps it: attackers hunt, defenders stay home and eat the
# projectiles meant for their king. The split is per-shade and re-rolled as the
# army's size changes, so you never get all-attack or all-defend.
enum Role { ATTACK, DEFEND }
var role: int = Role.ATTACK
const DEFEND_SHARE := 0.4     # ~40% guard, so an army always does both

# Two attacks, deliberately different in reach AND rhythm:
#   CLAW  -- melee, fast, low damage. The workhorse.
#   BOLT  -- low/mid range, slow, hits harder. Punishes hanging back.
const CLAW_RANGE := 44.0
const CLAW_COOLDOWN := 0.8
const BOLT_RANGE := 300.0
const BOLT_MIN_RANGE := 60.0  # won't bolt point-blank -- that's what claws are for
const BOLT_COOLDOWN := 3.2
const BOLT_SPEED := 420.0

# Defenders body-block: a hostile projectile that touches a guarding shade dies
# on it instead of reaching the Monarch.
const GUARD_RADIUS := 26.0
const GUARD_ORBIT := 54.0     # how far out front the guards hold station
const PROJECTILE_GROUPS = ["enemy_projectile", "boss_projectile", "hostile_projectile"]

var damage := 10
var explode_frac := 0.0       # Legion "Volatile Dead": burst on death for this x damage
var is_splinter := false      # born of the Splitting Dark: half-strength, never re-splits
var expires_at := 0.0         # ticks-seconds; 0 = permanent (true form)
var owner_player: Node2D = null

var _attack_ready_at := 0.0
var _bolt_ready_at := 0.0
var _bob := randf() * TAU
var _home_side := 1.0 if randf() < 0.5 else -1.0
var _dying := false
var _spawned := false

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	z_index = 6
	_build_visual()
	# rise out of the ground: unfold upward from a flat puddle of shadow
	scale = Vector2(1.3, 0.1)
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.22)
	t.tween_callback(func(): _spawned = true)

func _build_visual() -> void:
	# The Monarch's aura, inherited but lesser: his is a broad swirling cloud of
	# tendrils that swallows him whole; a shade's is a tight, jagged, upward-
	# licking flame of the same violet -- clearly his power, clearly a fraction
	# of it, and a different SHAPE so the two never read as the same effect.
	_aura = Polygon2D.new()
	_aura.polygon = _aura_shape(0.0)
	_aura.color = Color(0.45, 0.15, 0.85, 0.30)
	var add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura.material = add_mat
	_aura.position = Vector2(0, -12)
	_aura.z_index = -1
	add_child(_aura)
	# hooded wraith silhouette: cowled head, cloaked torso, ragged trailing hem
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(7, -26), Vector2(9, -18),
		Vector2(11, -6), Vector2(9, 2), Vector2(12, 8),
		Vector2(6, 4), Vector2(3, 10), Vector2(0, 5),
		Vector2(-3, 11), Vector2(-6, 4), Vector2(-12, 9),
		Vector2(-9, 1), Vector2(-11, -6), Vector2(-9, -18), Vector2(-7, -26),
	])
	body.color = Color(0.10, 0.04, 0.20, 0.92)
	add_child(body)
	# burning eyes in the cowl's dark
	for side in [-1.0, 1.0]:
		var eye = ColorRect.new()
		eye.size = Vector2(3, 2)
		eye.position = Vector2(side * 3.5 - 1.5, -24)
		eye.color = Color(0.85, 0.5, 1.0, 0.95)
		eye.material = add_mat
		add_child(eye)

# A ragged upward flame: spikes of alternating length around a small core, the
# odd ones stretched up. Nothing like the Monarch's round tendril cloud -- same
# colour, same family, unmistakably a lesser thing.
var _aura: Polygon2D = null
var _aura_t := 0.0
const AURA_SPIKES := 11
const AURA_CORE := 9.0

func _aura_shape(t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(AURA_SPIKES):
		var a: float = TAU * float(i) / AURA_SPIKES - PI / 2.0
		var up: float = maxf(0.0, -sin(a))          # 1 at the top, 0 at the sides
		var spike: float = 1.0 if i % 2 == 0 else 0.55
		var lick: float = 1.0 + 0.35 * sin(t * 3.4 + float(i) * 1.9)
		var r: float = AURA_CORE * spike * lick * (1.0 + up * 1.5)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _tick_aura(delta: float) -> void:
	if _aura == null:
		return
	_aura_t += delta
	_aura.polygon = _aura_shape(_aura_t)
	_aura.color.a = 0.22 + 0.12 * (0.5 + 0.5 * sin(_aura_t * 2.6))

func _blob(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a = TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r * randf_range(0.85, 1.15))
	return pts

func _process(delta: float) -> void:
	if _dying:
		return
	_tick_aura(delta)
	_tick_bolts(delta)
	if expires_at > 0.0 and _now() > expires_at:
		dissolve()
		return
	if not is_instance_valid(owner_player) or ("is_dead" in owner_player and owner_player.is_dead):
		dissolve()   # the Monarch has fallen -- his shadows go with him
		return
	_bob += delta * 3.0
	if role == Role.DEFEND:
		_tick_defend(delta)
		return
	var target = _nearest_enemy()
	var dest: Vector2
	if target != null:
		dest = target.global_position + Vector2(0, -12)
	else:
		dest = owner_player.global_position + Vector2(_home_side * HOME_RANGE, -30)
	var to = dest - global_position
	if to.length() > 6.0:
		global_position += to.normalized() * minf(FLY_SPEED * delta, to.length())
	if _spawned and absf(to.x) > 2.0:
		scale.x = absf(scale.x) * (1.0 if to.x >= 0.0 else -1.0)
	position.y += sin(_bob) * 6.0 * delta
	# BOLT: the slow one. Only from mid range -- hanging back is not safety.
	if target != null and _now() >= _bolt_ready_at:
		var d: float = global_position.distance_to(target.global_position)
		if d > BOLT_MIN_RANGE and d <= BOLT_RANGE:
			_bolt_ready_at = _now() + BOLT_COOLDOWN
			_fire_bolt(target)
	# CLAW: the fast one, in close
	if target != null and _now() >= _attack_ready_at \
			and global_position.distance_to(target.global_position) <= CLAW_RANGE:
		_attack_ready_at = _now() + CLAW_COOLDOWN
		_slash(target)

# --- DEFEND: hold station in front of the king and eat what's coming ---------
# A guarding shade doesn't chase. It orbits just ahead of the Monarch on the
# side the danger is, and any hostile projectile that touches it dies there --
# that IS its purpose. It cannot block what it isn't standing in front of, so a
# player who lets every shade go hunting has no screen.
func _tick_defend(delta: float) -> void:
	var threat := _nearest_projectile()
	var face_x: float = _home_side
	if threat != null:
		# slide to intercept: get between the king and the incoming shot
		face_x = signf(threat.global_position.x - owner_player.global_position.x)
		if face_x == 0.0:
			face_x = _home_side
	var dest: Vector2 = owner_player.global_position + Vector2(face_x * GUARD_ORBIT, -26.0 + sin(_bob) * 5.0)
	var to := dest - global_position
	if to.length() > 4.0:
		global_position += to.normalized() * minf(FLY_SPEED * delta, to.length())
	if _spawned:
		scale.x = absf(scale.x) * (1.0 if face_x >= 0.0 else -1.0)
	# body-block: anything hostile that reaches us dies on us
	for pr in _projectiles_near(GUARD_RADIUS):
		_block(pr)

func _nearest_projectile() -> Node2D:
	var best: Node2D = null
	var best_d := 420.0
	for g in PROJECTILE_GROUPS:
		for pr in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(pr) or not (pr is Node2D):
				continue
			var d: float = owner_player.global_position.distance_to(pr.global_position)
			if d < best_d:
				best_d = d
				best = pr
	return best

func _projectiles_near(r: float) -> Array:
	var out: Array = []
	for g in PROJECTILE_GROUPS:
		for pr in get_tree().get_nodes_in_group(g):
			if is_instance_valid(pr) and pr is Node2D \
					and global_position.distance_to(pr.global_position) <= r:
				out.append(pr)
	return out

# Eat one shot: a violet spark where it broke, and the shot is gone.
func _block(pr: Node) -> void:
	if not is_instance_valid(pr):
		return
	var spark := CPUParticles2D.new()
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.amount = 7
	spark.lifetime = 0.28
	spark.spread = 180.0
	spark.initial_velocity_min = 40.0
	spark.initial_velocity_max = 110.0
	spark.color = Color(0.62, 0.28, 1.0)
	spark.z_index = 30
	get_parent().add_child(spark)
	spark.global_position = (pr as Node2D).global_position
	spark.emitting = true
	spark.finished.connect(spark.queue_free)
	pr.queue_free()

# BOLT: the slow, longer-reaching attack -- a bolt of shadow it throws.
func _fire_bolt(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var bolt := Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 0
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(0, -3.5), Vector2(9, 0), Vector2(0, 3.5)])
	vis.color = Color(0.62, 0.26, 1.0, 0.95)
	bolt.add_child(vis)
	var glow := Polygon2D.new()
	glow.polygon = _blob(7.0, 9)
	glow.color = Color(0.45, 0.15, 0.85, 0.35)
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = am
	bolt.add_child(glow)
	bolt.z_index = 8
	get_parent().add_child(bolt)
	bolt.global_position = global_position
	var dir: Vector2 = (target.global_position - global_position).normalized()
	bolt.rotation = dir.angle()
	_bolts.append({"n": bolt, "dir": dir, "dmg": int(round(damage * 1.6)), "life": 1.6})

var _bolts: Array = []

func _tick_bolts(delta: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		var b: Dictionary = _bolts[i]
		var n: Node2D = b["n"]
		if not is_instance_valid(n):
			_bolts.remove_at(i)
			continue
		b["life"] -= delta
		n.global_position += b["dir"] * BOLT_SPEED * delta
		if b["life"] <= 0.0:
			n.queue_free()
			_bolts.remove_at(i)
			continue
		# a hit consumes THIS bolt only (audit fix): the old `return` bailed out
		# of the whole tick on the first connect, freezing every other airborne
		# bolt for the frame -- dropped hit tests on 420px/s projectiles once a
		# Legion build had several in the air.
		var hit := false
		for g in HOSTILE_GROUPS:
			if hit:
				break
			for e in get_tree().get_nodes_in_group(g):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if n.global_position.distance_to(e.global_position) <= 26.0:
					e.take_damage(b["dmg"])
					n.queue_free()
					_bolts.remove_at(i)
					hit = true
					break

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := SEEK_RANGE
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _slash(target: Node2D) -> void:
	target.take_damage(damage)
	# a dark arc flashes across the victim
	var arc = Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(0.62, 0.28, 1.0, 0.9)
	for i in range(7):
		var a = lerpf(-1.1, 1.1, i / 6.0)
		arc.add_point(Vector2(sin(a) * 16.0, -10.0 - cos(a) * 10.0))
	arc.z_index = 40
	get_parent().add_child(arc)
	arc.global_position = target.global_position
	var t = arc.create_tween()
	t.tween_property(arc, "modulate:a", 0.0, 0.2)
	t.tween_callback(arc.queue_free)

func spawn_burst() -> void:
	var burst_fx := CPUParticles2D.new()
	burst_fx.one_shot = true
	burst_fx.explosiveness = 1.0
	burst_fx.amount = 14
	burst_fx.lifetime = 0.35
	burst_fx.spread = 180.0
	burst_fx.initial_velocity_min = 80.0
	burst_fx.initial_velocity_max = 180.0
	burst_fx.color = Color(0.55, 0.2, 1.0)
	burst_fx.z_index = 30
	get_parent().add_child(burst_fx)
	burst_fx.global_position = global_position
	burst_fx.emitting = true
	burst_fx.finished.connect(burst_fx.queue_free)

func dissolve() -> void:
	if _dying:
		return
	_dying = true
	# free any airborne bolts -- once the shade dissolves, _tick_bolts stops
	# running, so scriptless bolt nodes would linger in the world forever
	for b in _bolts:
		if is_instance_valid(b.get("n")):
			b["n"].queue_free()
	_bolts.clear()
	# Volatile Dead: a falling shade erupts, harming everything around where it
	# stood -- so the Legion keeps working even as it's whittled down
	if explode_frac > 0.0:
		var burst := int(round(float(damage) * explode_frac))
		if burst > 0:
			for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
				for e in get_tree().get_nodes_in_group(group_name):
					if is_instance_valid(e) and e.has_method("take_damage") \
							and not ("is_dead" in e and e.is_dead) \
							and global_position.distance_to(e.global_position) <= 130.0:
						e.take_damage(burst)
			spawn_burst()
	# The Splitting Dark (Wukong road): the falling shade TEARS ITSELF IN TWO --
	# half-strength halves that fight on for a while. Splinters never re-split,
	# and nothing splits once the Monarch himself has fallen.
	if not is_splinter and is_instance_valid(owner_player) \
			and not ("is_dead" in owner_player and owner_player.is_dead) \
			and GameState.get_skill_total("clone_burst") > 0.0:
		SfxSynth.play_at(self, global_position, "tear", -11.0)
		for side in [-1.0, 1.0]:
			var sp = get_script().new()
			sp.owner_player = owner_player
			sp.damage = maxi(1, int(round(damage * 0.5)))
			sp.expires_at = _now() + 8.0
			sp.is_splinter = true
			get_parent().add_child(sp)
			sp.global_position = global_position + Vector2(side * 18.0, 0.0)
			sp.scale = Vector2(0.72, 0.72)
			# each half TEARS free in a burst of the same dark the parent
			# dissolves into -- the split is seen, not just counted
			sp.call_deferred("spawn_burst")
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(self, "scale", Vector2(1.2, 0.05), 0.3)
	t.tween_callback(queue_free)
