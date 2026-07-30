extends Node2D

# COMPANIONS (task: light summoner, 2026-07-29). No fourth class: a companion
# is carried BY an item. Wield or equip the carrier and it walks with you;
# put the item away and it bows out. Terraria minion-KIN, never 1:1 -- bound
# to specific famous items instead of a summon stat.
#
# Kinds (procedural visuals, weapon_projectile's palette discipline):
#   blade -- an orbiting spectral blade that DARTS at the mark and returns
#   wisp  -- a hovering candleflame that lobs slow SEEKING motes
#   beast -- a ground-running shade that POUNCES
#
# Spawned/reaped by player._reconcile_companions (wield + equipment hooks).
# All damage lands through take_damage like everything else in the game.

var kind := "blade"
var damage := 12
var gap := 1.8              # seconds between attacks
var source_id := ""         # the carrier item; the player reaps us if it goes
var slot := 0               # hover-slot index so several companions spread out
var player: Node2D = null

# SUMMONER (batch 1, 2026-07-30). A carrier companion is a guest -- it belongs
# to an item and takes no orders. A SUMMONED minion belongs to the class: its
# damage runs through the bonus pipeline, it prefers the bond-mark over mere
# distance, and it collects the whip's tag donation. The chassis is shared;
# these two flags are the whole difference.
var summoned := false       # true = a Summoner minion, not a carried guest
const BOND_MARK := preload("res://bond_mark.gd")

const LEASH := 420.0
const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]
const PROJECTILE_SCRIPT = preload("res://weapon_projectile.gd")

var _state := 0             # 0 hover, 1 strike out, 2 come home
var _cool := 0.0
var _mark: Node2D = null
var _mark_point := Vector2.ZERO
var _bob_t := 0.0
var visual: Node2D = null

func _ready() -> void:
	z_index = 38
	visual = Node2D.new()
	add_child(visual)
	match kind:
		"blade": _build_blade()
		"wisp": _build_wisp()
		"beast": _build_beast()
		# ---- Summoner bodies (batch 1) ----
		"mudling": _build_mudling()
		"finch": _build_finch()
		_: _build_blade()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _slot_offset() -> Vector2:
	# beasts keep their feet on the ground line; fliers hover at the shoulder
	if kind == "beast":
		return Vector2(-46.0 - 26.0 * float(slot), 8.0)
	return Vector2(-34.0 - 24.0 * float(slot), -52.0 + 10.0 * float(slot % 2))

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_bob_t += delta
	_cool = maxf(0.0, _cool - delta)
	match _state:
		0:
			# spring-damped hover at the slot, with a gentle breath of bob
			var home: Vector2 = player.global_position + _slot_offset()
			home.y += sin(_bob_t * 2.2 + float(slot)) * (2.0 if kind == "beast" else 5.0)
			global_position = global_position.lerp(home, minf(1.0, 7.0 * delta))
			visual.scale.x = -1.0 if player.global_position.x < global_position.x else 1.0
			if _cool <= 0.0:
				_mark = _find_mark()
				if _mark != null:
					if kind == "wisp":
						_loose_mote()
						_cool = effective_gap()
					else:
						_mark_point = _mark.global_position
						_state = 1
		1:
			# the strike: fly (or lunge) at the mark's LIVE position
			if is_instance_valid(_mark) and not _is_dead(_mark):
				_mark_point = _mark.global_position
			var spd := 900.0 if kind == "blade" else 700.0
			var to_mark := _mark_point - global_position
			if kind == "beast":
				to_mark.y *= 0.35   # a pounce stays low; it is not a flier
			global_position += to_mark.normalized() * spd * delta
			visual.rotation = to_mark.angle() if kind == "blade" else 0.0
			visual.scale.x = -1.0 if to_mark.x < 0.0 else 1.0
			if to_mark.length() <= 34.0:
				_land()
			elif to_mark.length() > LEASH * 1.6:
				_state = 2
		2:
			var back: Vector2 = player.global_position + _slot_offset()
			global_position += (back - global_position).normalized() * 760.0 * delta
			visual.rotation = 0.0
			if global_position.distance_to(back) <= 26.0:
				_state = 0

# What one strike is worth right now. A carried guest keeps its flat item
# number; a SUMMONED minion runs through the same bonus pipeline as everything
# else, and collects the whip's tag donation when it lands on the marked foe.
func strike_damage(on: Node) -> Array:
	if not summoned:
		return [damage, false]
	var d: float = float(damage) * (1.0 + GameState.get_bonus_total("summon_damage"))
	# PACK LAW: fewer, hungrier -- damage scales with how many of you there are
	var pack: float = GameState.get_bonus_total("pack_law")
	if pack > 0.0:
		var alive := 0
		for c in get_parent().get_children():
			if c.get("summoned") == true:
				alive += 1
		d *= 1.0 + pack * float(alive)
	var crit := false
	if BOND_MARK.is_marked(on):
		d += GameState.get_bonus_total("tag_damage")
		if randf() < GameState.get_bonus_total("tag_crit"):
			crit = true
			d *= 1.7
	return [maxi(1, int(round(d))), crit]

func _land() -> void:
	if is_instance_valid(_mark) and not _is_dead(_mark) and _mark.has_method("take_damage"):
		var roll: Array = strike_damage(_mark)
		var pay: int = int(roll[0])
		var landed = _mark.take_damage(pay)
		if landed == null or landed:
			FloatingText.spawn(get_parent(), _mark.global_position, pay, bool(roll[1]))
		HitFx.burst(get_parent(), _mark_point, "physical", bool(roll[1]))
		if _mark.has_method("apply_knockback"):
			_mark.apply_knockback(1 if global_position.x < _mark.global_position.x else -1, 24.0)
	SfxSynth.play_at(self, global_position, "pop", -18.0, 1.5)
	_cool = effective_gap()
	_state = 2

# the wisp does not fly at anyone: it lobs a slow seeking mote (the homing
# soul_stream kind, already in the projectile library) and stays a candle
func _loose_mote() -> void:
	var m = PROJECTILE_SCRIPT.new()
	m.kind = "soul_stream"
	m.damage = damage
	m.speed = 300.0
	m.max_distance = 520.0
	m.direction = Vector2.RIGHT if visual.scale.x >= 0.0 else Vector2.LEFT
	if is_instance_valid(_mark):
		m.direction = (_mark.global_position - global_position).normalized()
	m.girth = 0.7
	m.source = null   # a companion's mote carries no weapon unique
	m.position = global_position
	get_parent().add_child(m)
	SfxSynth.play_at(self, global_position, "chime", -20.0, 1.6)

func _find_mark() -> Node2D:
	# THE MARK COMES FIRST. A summoned minion looks where you pointed before it
	# looks at what is closest -- that is the whole whip-and-pack loop. A
	# carried guest has no master and keeps picking the nearest thing.
	if summoned:
		var tagged := BOND_MARK.marked(get_tree())
		if tagged != null and player != null \
				and player.global_position.distance_to(tagged.global_position) < LEASH * reach_mult():
			return tagged
	var best: Node2D = null
	var bd := LEASH * reach_mult()
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if _is_dead(e):
				continue
			var d: float = player.global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _is_dead(n: Node) -> bool:
	return "is_dead" in n and n.is_dead

# Longer Leash (sm_b2) reaches farther and comes home faster.
func reach_mult() -> float:
	if not summoned:
		return 1.0
	return 1.0 + GameState.get_bonus_total("leash_bonus")

# TIDE OF TEETH: the pack frenzies at the mark. Applied to the gap between
# strikes rather than the damage, so it reads as the pack getting excited.
func effective_gap() -> float:
	if not summoned:
		return gap
	var g: float = gap
	if _mark != null and BOND_MARK.is_marked(_mark):
		g /= (1.0 + GameState.get_bonus_total("tag_frenzy"))
	return maxf(0.15, g)

# --- the three bodies ---

func _build_blade() -> void:
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(4, -8), Vector2(-14, -5), Vector2(-18, 0), Vector2(-14, 5), Vector2(4, 8)])
	glow.color = Color(0.6, 0.75, 1.0, 0.5)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(17, 0), Vector2(3, -4), Vector2(-10, -2.5), Vector2(-10, 2.5), Vector2(3, 4)])
	blade.color = Color(0.85, 0.92, 1.0, 0.95)
	visual.add_child(blade)
	var guard := Polygon2D.new()
	guard.polygon = PackedVector2Array([Vector2(-10, -5), Vector2(-8, 0), Vector2(-10, 5), Vector2(-12, 0)])
	guard.color = Color(0.5, 0.62, 0.9, 0.95)
	visual.add_child(guard)

func _build_wisp() -> void:
	var halo := Polygon2D.new()
	var hp := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		hp.append(Vector2(cos(a), sin(a)) * 11.0)
	halo.polygon = hp
	halo.color = Color(1.0, 0.85, 0.45, 0.3)
	var hm := CanvasItemMaterial.new()
	hm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = hm
	visual.add_child(halo)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(4, -2), Vector2(3, 4), Vector2(-3, 4), Vector2(-4, -2)])
	flame.color = Color(1.0, 0.78, 0.35, 0.95)
	visual.add_child(flame)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(0, -4), Vector2(2, 1), Vector2(0, 3), Vector2(-2, 1)])
	core.color = Color(1.0, 0.97, 0.85, 0.95)
	visual.add_child(core)

# A SMALL LOYALTY: a lump of hearth-clay with a face pressed into it. The
# starter minion, and it should look homemade -- the village made this.
func _build_mudling() -> void:
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, 6), Vector2(-8, -6), Vector2(0, -10), Vector2(9, -5),
		Vector2(11, 4), Vector2(4, 8)])
	body.color = Color(0.55, 0.42, 0.3, 0.95)
	visual.add_child(body)
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-7, -5), Vector2(0, -11), Vector2(8, -4), Vector2(0, -6)])
	cap.color = Color(0.66, 0.52, 0.36, 0.95)
	visual.add_child(cap)
	for ex in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			Vector2(2.0 * ex - 1.0, -3.0), Vector2(2.0 * ex + 1.0, -3.0),
			Vector2(2.0 * ex + 1.0, -1.0), Vector2(2.0 * ex - 1.0, -1.0)])
		eye.color = Color(0.95, 0.86, 0.6, 0.98)
		visual.add_child(eye)

# THE FLEDGLING: a small bird of amber light. It should read as eager.
func _build_finch() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for s in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.polygon = PackedVector2Array([
			Vector2(1, 0), Vector2(-8, 7.0 * s), Vector2(-11, 1.0 * s)])
		wing.color = Color(0.92, 0.72, 0.36, 0.85)
		wing.material = m
		visual.add_child(wing)
		var tw := wing.create_tween().set_loops()
		tw.tween_property(wing, "scale", Vector2(1.0, 0.45), 0.1)
		tw.tween_property(wing, "scale", Vector2(1.0, 1.0), 0.1)
	var body_f := Polygon2D.new()
	body_f.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(1, -4.0), Vector2(-8, 0), Vector2(1, 4.0)])
	body_f.color = Color(1.0, 0.86, 0.52, 0.96)
	body_f.material = m
	visual.add_child(body_f)
	var beak := Polygon2D.new()
	beak.polygon = PackedVector2Array([Vector2(14, 0), Vector2(9, -1.6), Vector2(9, 1.6)])
	beak.color = Color(0.7, 0.5, 0.2, 0.95)
	visual.add_child(beak)

func _build_beast() -> void:
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(14, -2), Vector2(8, -8), Vector2(-6, -7), Vector2(-14, -3),
		Vector2(-16, 2), Vector2(-10, 5), Vector2(10, 5), Vector2(15, 2)])
	body.color = Color(0.24, 0.2, 0.3, 0.92)
	visual.add_child(body)
	var ear := Polygon2D.new()
	ear.polygon = PackedVector2Array([Vector2(8, -8), Vector2(11, -13), Vector2(12, -7)])
	ear.color = Color(0.24, 0.2, 0.3, 0.92)
	visual.add_child(ear)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-14, -3), Vector2(-22, -8), Vector2(-15, 0)])
	tail.color = Color(0.28, 0.24, 0.35, 0.85)
	visual.add_child(tail)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([Vector2(9, -5), Vector2(12, -4.4), Vector2(9, -3.6)])
	eye.color = Color(0.95, 0.75, 0.3, 0.95)
	visual.add_child(eye)
