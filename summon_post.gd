extends Node2D

# SUMMONER POSTS (batch 1 — 2026-07-30).
#
# A totem plants a STATIONED guardian. It differs from the wand's existing
# sentry_totem in exactly one way, and the difference is the point: a sentry
# is TIMED and expires; a post is PERMANENT until you replace it. The two
# families coexist and the player can tell them apart by whether the thing
# ever leaves.
#
# One script, `s_kind`-branched, so a new post archetype is a new branch
# rather than a new file -- the same discipline weapon_projectile keeps.

const GROUP := "summon_post"
const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]
const PROJECTILE_SCRIPT = preload("res://weapon_projectile.gd")
const BOND_MARK := preload("res://bond_mark.gd")

var s_kind := "watchstone"
var damage := 8
var gap := 1.1
var source_id := ""
var player: Node2D = null
var reach := 300.0

var _cool := 0.0
var _t := 0.0
var _berserk := 0.0
var visual: Node2D = null

func _ready() -> void:
	z_index = 9
	add_to_group(GROUP)
	visual = Node2D.new()
	add_child(visual)
	match s_kind:
		"watchstone": _build_watchstone()
		"bramble": _build_bramble()
		"ballista": _build_ballista()
		"bell": _build_bell()
		"sister": _build_sister()
		"eggkeeper": _build_eggkeeper()
		"frostfount": _build_frostfount()
		"rift": _build_rift()
		_: _build_watchstone()
	# the posts that do not SHOOT reach differently
	match s_kind:
		"bell": reach = 118.0        # a tolling zone, not a gun
		"sister": reach = 130.0      # it mends within arm's length of the wall
		"rift": reach = 520.0        # a beam sweeping the whole hall
	# it rises out of the ground rather than popping into being
	visual.scale = Vector2(1.0, 0.1)
	var tw: Tween = visual.create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)

# THE POSTS DO NOT SLEEP: when the player is struck, every post goes berserk.
# Called by player.take_damage so the trigger is real rather than polled.
func rouse(seconds: float) -> void:
	_berserk = maxf(_berserk, seconds)

func _physics_process(delta: float) -> void:
	_t += delta
	_berserk = maxf(0.0, _berserk - delta)
	_cool = maxf(0.0, _cool - delta)
	if visual != null and is_instance_valid(visual):
		# a lit post leans forward slightly while roused, so the state reads
		visual.rotation = sin(_t * (14.0 if _berserk > 0.0 else 1.6)) * (0.07 if _berserk > 0.0 else 0.02)
	if _cool > 0.0:
		return
	var prey := _pick()
	# the bell tolls and the sister mends whether or not anything is looking
	if prey == null and s_kind != "bell" and s_kind != "sister":
		return
	_cool = _fire_gap()
	_loose_at(prey)

# posts prefer the bond-mark too -- the whole army looks where you point
func _pick() -> Node2D:
	var tagged := BOND_MARK.marked(get_tree())
	if tagged != null and global_position.distance_to(tagged.global_position) <= reach:
		return tagged
	var best: Node2D = null
	var bd := reach
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _fire_gap() -> float:
	var g: float = gap * (1.0 - clampf(GameState.get_bonus_total("post_cooldown"), 0.0, 0.6))
	if _berserk > 0.0:
		g *= 0.5           # roused: double rate
	return maxf(0.12, g)

# Not every post SHOOTS. Three of them do something else entirely, and the
# branch is here rather than in eight scripts.
func _act_on(prey: Node2D) -> bool:
	match s_kind:
		"bell":
			# THE STORM BELL: a tolling zone. It does not aim -- everything
			# standing inside the ring pays, and armour is not consulted.
			_toll()
			return true
		"sister":
			# THE QUIET SISTER: the doctor's promise, standing. She never
			# strikes; she mends you and the pack around her.
			_mend()
			return true
		"eggkeeper":
			# THE EGG-KEEPER: a post that FEEDS the horde
			_lay_egg(prey)
			return true
	return false

func _toll() -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a) * 24.0, sin(a) * 10.0))
	for i in range(18):
		var a2 := TAU * float(17 - i) / 18.0
		pts.append(Vector2(cos(a2) * 20.0, sin(a2) * 8.0))
	ring.polygon = pts
	ring.color = Color(0.78, 0.86, 1.0, 0.7)
	ring.material = m
	ring.z_index = 41
	host.add_child(ring)
	ring.global_position = global_position
	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * (reach / 22.0), 0.5)
	tw.tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)
	var pay: int = maxi(1, int(round(float(damage) * (1.0 + GameState.get_bonus_total("post_damage")))))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > reach:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-14.0, 14.0), -26.0), pay, false)

func _mend() -> void:
	var host := get_parent()
	if is_instance_valid(player) and player.has_method("heal") \
			and global_position.distance_to((player as Node2D).global_position) <= reach:
		player.heal(maxi(1, damage))
		if host != null:
			FloatingText.spawn_word(host,
				(player as Node2D).global_position + Vector2(0, -56),
				"+%d" % maxi(1, damage), Color(0.8, 1.0, 0.86))

func _lay_egg(prey: Node2D) -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(player):
		return
	# a brief spiderling, borrowed from the class's own bestiary
	var brood = load("res://companion.gd").new()
	brood.kind = "spiderling"
	brood.style = "latch"
	brood.summoned = true
	brood.damage = maxi(1, int(round(float(damage) * 0.5)))
	brood.gap = 0.8
	brood.source_id = source_id
	brood.player = player
	host.add_child(brood)
	brood.global_position = global_position + Vector2(randf_range(-14.0, 14.0), -10.0)
	# it is a HATCHLING: it does not live long, and the post makes more
	var tw: Tween = brood.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(brood, "modulate:a", 0.0, 0.4)
	tw.tween_callback(brood.queue_free)

func _loose_at(prey: Node2D) -> void:
	if _act_on(prey):
		return
	var d: float = float(damage) * (1.0 + GameState.get_bonus_total("post_damage"))
	if BOND_MARK.is_marked(prey):
		d += GameState.get_bonus_total("tag_damage")
	var bolt = PROJECTILE_SCRIPT.new()
	bolt.kind = "shot"
	bolt.damage = maxi(1, int(round(d)))
	bolt.speed = 520.0
	bolt.max_distance = reach + 60.0
	bolt.direction = ((prey as Node2D).global_position - global_position).normalized()
	bolt.pierce = GameState.get_bonus_total("post_pierce") > 0.0
	bolt.girth = 0.85
	bolt.beam_tint = Color(0.92, 0.76, 0.42)
	bolt.source = null      # a post's bolt carries no weapon unique
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector2(0, -22.0)

# --- the bodies -------------------------------------------------------

func _amber() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _ring_pts(rx: float, ry: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# THE BRAMBLE POST: a knot of thorn that keeps re-arming itself.
func _build_bramble() -> void:
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-6, 20.0), Vector2(-4, -10.0), Vector2(4, -10.0), Vector2(6, 20.0)])
	trunk.color = Color(0.3, 0.26, 0.18, 0.96)
	visual.add_child(trunk)
	for k in range(7):
		var thorn := Polygon2D.new()
		var h: float = randf_range(9.0, 17.0)
		thorn.polygon = PackedVector2Array([
			Vector2(-2.6, 0), Vector2(0, -h), Vector2(2.6, 0)])
		thorn.color = Color(0.36, 0.42, 0.24, 0.95)
		thorn.position = Vector2(-18.0 + 6.0 * float(k), randf_range(-8.0, 14.0))
		thorn.rotation = randf_range(-0.5, 0.5)
		visual.add_child(thorn)

# THE STANDING THORN: a ballista. It should look WOUND, ready to let go.
func _build_ballista() -> void:
	var m := _amber()
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([
		Vector2(-11, 20.0), Vector2(-7, -14.0), Vector2(7, -14.0), Vector2(11, 20.0)])
	frame.color = Color(0.36, 0.3, 0.22, 0.97)
	visual.add_child(frame)
	var bow := Polygon2D.new()
	bow.polygon = PackedVector2Array([
		Vector2(-18, -20.0), Vector2(0, -12.0), Vector2(18, -20.0),
		Vector2(18, -16.0), Vector2(0, -8.0), Vector2(-18, -16.0)])
	bow.color = Color(0.52, 0.44, 0.3, 0.97)
	visual.add_child(bow)
	var bolt_v := Polygon2D.new()
	bolt_v.polygon = PackedVector2Array([
		Vector2(0, -20.0), Vector2(3.0, -10.0), Vector2(-3.0, -10.0)])
	bolt_v.color = Color(0.9, 0.86, 0.6, 0.95)
	bolt_v.material = m
	visual.add_child(bolt_v)

# THE STORM BELL: it TOLLS. Everything about it should suggest sound.
func _build_bell() -> void:
	var m := _amber()
	var yoke := Polygon2D.new()
	yoke.polygon = PackedVector2Array([
		Vector2(-14, -22.0), Vector2(14, -22.0), Vector2(14, -18.0), Vector2(-14, -18.0)])
	yoke.color = Color(0.3, 0.28, 0.24, 0.96)
	visual.add_child(yoke)
	var bell := Polygon2D.new()
	bell.polygon = PackedVector2Array([
		Vector2(-13, 12.0), Vector2(-9, -14.0), Vector2(9, -14.0), Vector2(13, 12.0)])
	bell.color = Color(0.62, 0.58, 0.36, 0.97)
	visual.add_child(bell)
	var lip := Polygon2D.new()
	lip.polygon = PackedVector2Array([
		Vector2(-15, 12.0), Vector2(15, 12.0), Vector2(15, 16.0), Vector2(-15, 16.0)])
	lip.color = Color(0.78, 0.72, 0.44, 0.97)
	lip.material = m
	visual.add_child(lip)
	var tw: Tween = bell.create_tween().set_loops()
	tw.tween_property(bell, "rotation", 0.09, 0.6)
	tw.tween_property(bell, "rotation", -0.09, 0.6)

# THE QUIET SISTER: she mends. She should look like a person keeping vigil.
func _build_sister() -> void:
	var m := _amber()
	var robe := Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-11, 20.0), Vector2(-7, -8.0), Vector2(0, -16.0),
		Vector2(7, -8.0), Vector2(11, 20.0)])
	robe.color = Color(0.78, 0.82, 0.86, 0.95)
	visual.add_child(robe)
	var veil := Polygon2D.new()
	veil.polygon = PackedVector2Array([
		Vector2(-7, -8.0), Vector2(-5, -19.0), Vector2(5, -19.0), Vector2(7, -8.0)])
	veil.color = Color(0.9, 0.92, 0.95, 0.96)
	visual.add_child(veil)
	var halo := Polygon2D.new()
	halo.polygon = _ring_pts(11.0, 5.0, 12)
	halo.color = Color(0.7, 1.0, 0.84, 0.6)
	halo.material = m
	halo.position = Vector2(0, -24.0)
	visual.add_child(halo)
	var tw: Tween = halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.3, 1.1)
	tw.tween_property(halo, "modulate:a", 0.9, 1.1)

# THE EGG-KEEPER: a squat clutch that keeps producing.
func _build_eggkeeper() -> void:
	var nest := Polygon2D.new()
	nest.polygon = PackedVector2Array([
		Vector2(-18, 18.0), Vector2(-14, 2.0), Vector2(14, 2.0), Vector2(18, 18.0)])
	nest.color = Color(0.32, 0.28, 0.2, 0.96)
	visual.add_child(nest)
	for k in range(3):
		var egg := Polygon2D.new()
		egg.polygon = _ring_pts(6.0, 8.0, 9)
		egg.color = Color(0.86, 0.84, 0.7, 0.96)
		egg.position = Vector2(-9.0 + 9.0 * float(k), -4.0)
		visual.add_child(egg)
		var tw: Tween = egg.create_tween().set_loops()
		tw.tween_property(egg, "rotation", 0.18, randf_range(0.5, 0.9))
		tw.tween_property(egg, "rotation", -0.18, randf_range(0.5, 0.9))

# WINTER'S THREE MOUTHS: three heads on one stem.
func _build_frostfount() -> void:
	var m := _amber()
	var stem := Polygon2D.new()
	stem.polygon = PackedVector2Array([
		Vector2(-5, 20.0), Vector2(-3, -6.0), Vector2(3, -6.0), Vector2(5, 20.0)])
	stem.color = Color(0.4, 0.5, 0.58, 0.96)
	visual.add_child(stem)
	for k in range(3):
		var head := Polygon2D.new()
		head.polygon = PackedVector2Array([
			Vector2(0, -6.0), Vector2(9, -16.0), Vector2(2, -20.0), Vector2(-4, -12.0)])
		head.color = Color(0.66, 0.86, 1.0, 0.9)
		head.material = m
		head.rotation = deg_to_rad(-34.0 + 34.0 * float(k))
		visual.add_child(head)

# THE DOOR THAT WATCHES: a standing rift. It should not look built.
func _build_rift() -> void:
	var m := _amber()
	var frame_r := Polygon2D.new()
	frame_r.polygon = PackedVector2Array([
		Vector2(-13, 20.0), Vector2(-9, -26.0), Vector2(9, -26.0), Vector2(13, 20.0)])
	frame_r.color = Color(0.14, 0.1, 0.2, 0.95)
	visual.add_child(frame_r)
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(-8, 17.0), Vector2(-5, -22.0), Vector2(5, -22.0), Vector2(8, 17.0)])
	inner.color = Color(0.7, 0.5, 0.95, 0.7)
	inner.material = m
	visual.add_child(inner)
	var tw: Tween = inner.create_tween().set_loops()
	tw.tween_property(inner, "scale", Vector2(0.7, 1.0), 0.9)
	tw.tween_property(inner, "scale", Vector2(1.0, 1.0), 0.9)

func _build_watchstone() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var stone := Polygon2D.new()
	stone.polygon = PackedVector2Array([
		Vector2(-13, 20.0), Vector2(-10, -18.0), Vector2(0, -26.0),
		Vector2(10, -18.0), Vector2(13, 20.0)])
	stone.color = Color(0.42, 0.4, 0.38, 0.97)
	visual.add_child(stone)
	# the carved eye: this is a WATCHING stone, and it must look like one
	var socket := Polygon2D.new()
	socket.polygon = PackedVector2Array([
		Vector2(-8, -12.0), Vector2(0, -19.0), Vector2(8, -12.0), Vector2(0, -6.0)])
	socket.color = Color(0.24, 0.22, 0.2, 0.98)
	visual.add_child(socket)
	var iris := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(9):
		var a := TAU * float(i) / 9.0
		pts.append(Vector2(cos(a) * 4.4, sin(a) * 3.4))
	iris.polygon = pts
	iris.color = Color(0.98, 0.78, 0.4, 0.98)
	iris.material = m
	iris.position = Vector2(0, -12.0)
	visual.add_child(iris)
	var tw: Tween = iris.create_tween().set_loops()
	tw.tween_property(iris, "scale", Vector2(1.0, 0.15), 0.09)
	tw.tween_interval(2.4)
	tw.tween_property(iris, "scale", Vector2.ONE, 0.09)
	tw.tween_interval(1.1)
