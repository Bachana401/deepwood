extends Node2D
# CREATIVE DUNGEON HAZARDS (dev report 2026-07-21: "no creative traps"). Beyond
# the proximity land-mine (trap.gd), a family of distinct environmental dangers,
# each READ and BEATEN differently -- so a floor's danger isn't one blinking plate
# repeated:
#   spike     -- floor spikes that ERUPT when you linger over them (telegraphed);
#                keep moving and they miss.
#   flamevent -- a floor vent that jets fire on a RHYTHM, ignoring you entirely;
#                cross it in the gap between bursts.
#   crusher   -- a ceiling block that SLAMS the instant you stand under it; don't
#                stop beneath it.
#   gas       -- a geyser that coughs a lingering POISON cloud on a rhythm; the
#                damage follows you out, so don't breathe it in.
# All procedural (no art), all self-contained, all driven off a phase clock so
# they're deterministic. dungeon_interior.place_hazards scatters a themed couple
# per floor; the Underdark can reuse them too.

var kind := "spike"
var damage := 20
var span := 96.0                  # horizontal reach along the floor
var _t := 0.0                     # time in the current phase
var _state := "idle"
var _hit_cd := 0.0                # so a continuous danger doesn't hit every frame

const SFX_IMPACT = preload("res://audio/explosion.wav")

# tuning
const SPIKE_WARN := 0.45
const SPIKE_UP := 0.55
const SPIKE_RETRACT := 0.22
const SPIKE_CD := 1.6
const FLAME_DORMANT := 2.0
const FLAME_TELL := 0.55          # the nozzle glows for the last of the dormant phase
const FLAME_ERUPT := 0.9
const FLAME_H := 155.0
const CRUSH_WARN := 0.4
const CRUSH_DROP := 0.13
const CRUSH_HOLD := 0.28
const CRUSH_RISE := 0.9
const CRUSH_CD := 1.1
const CRUSH_HEIGHT := 300.0
const GAS_DORMANT := 2.2
const GAS_TELL := 0.5
const GAS_SPEW := 1.6
const GAS_R := 98.0
const VERT_TOLERANCE := 74.0      # a floor hazard only bites something near the floor

# visual refs
var _spikes: Node2D = null
var _flame: Polygon2D = null
var _nozzle: Polygon2D = null
var _flame_light: PointLight2D = null

# Shared warm radial texture for the flamevent's light (a fire jet IS a light
# source in the dark cave, dev ask 2026-07-22).
static var _htex: GradientTexture2D = null
static func _light_tex() -> GradientTexture2D:
	if _htex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		_htex = GradientTexture2D.new()
		_htex.gradient = g
		_htex.width = 96
		_htex.height = 96
		_htex.fill = GradientTexture2D.FILL_RADIAL
		_htex.fill_from = Vector2(0.5, 0.5)
		_htex.fill_to = Vector2(1.0, 0.5)
	return _htex
var _block: Node2D = null
var _cloud: Node2D = null
var _sfx: AudioStreamPlayer2D = null

func _ready() -> void:
	_sfx = AudioStreamPlayer2D.new()
	add_child(_sfx)
	_t = randf() * 2.5            # desync rhythm hazards so they don't all fire together
	match kind:
		"spike": _build_spike()
		"flamevent": _build_flamevent()
		"crusher": _build_crusher()
		"gas": _build_gas()

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")

# horizontal overlap with a floor hazard, at floor height
func _player_over(p: Node2D, reach: float, vtol: float = VERT_TOLERANCE) -> bool:
	if p == null:
		return false
	return absf(p.global_position.x - global_position.x) <= reach \
		and absf(p.global_position.y - global_position.y) <= vtol

func _hit(p: Node2D, dmg: int, knock := 0.0, shake := 8.0) -> void:
	if p == null or not p.has_method("take_damage"):
		return
	p.take_damage(dmg)
	if knock > 0.0 and p.has_method("apply_knockback"):
		var away := signf(p.global_position.x - global_position.x)
		p.apply_knockback(int(away) if away != 0.0 else 1, knock)
	if p.has_node("Camera2D"):
		p.get_node("Camera2D").shake(shake, 0.3)

func _boom() -> void:
	_sfx.stream = SFX_IMPACT
	_sfx.play()

func _physics_process(delta: float) -> void:
	_t += delta
	if _hit_cd > 0.0:
		_hit_cd -= delta
	match kind:
		"spike": _tick_spike()
		"flamevent": _tick_flamevent()
		"crusher": _tick_crusher()
		"gas": _tick_gas()

# ---------------- SPIKE: erupts when you dawdle over it ----------------
func _build_spike() -> void:
	var base := ColorRect.new()
	base.size = Vector2(span, 8.0)
	base.position = Vector2(-span * 0.5, -4.0)
	base.color = Color(0.18, 0.16, 0.15, 1.0)
	add_child(base)
	_spikes = Node2D.new()
	add_child(_spikes)
	var n := int(span / 20.0)
	for i in range(n):
		var sx := -span * 0.5 + 12.0 + i * 20.0
		var spike := Polygon2D.new()
		spike.polygon = PackedVector2Array([Vector2(sx - 7, 0), Vector2(sx + 7, 0), Vector2(sx, -30)])
		spike.color = Color(0.72, 0.74, 0.78, 1.0)
		_spikes.add_child(spike)
	_spikes.position.y = 6.0        # tucked below the plate when idle
	_spikes.modulate.a = 0.0

func _tick_spike() -> void:
	var p := _player()
	match _state:
		"idle":
			_spikes.position.y = 6.0
			_spikes.modulate.a = 0.0
			if _player_over(p, span * 0.5, 40.0):
				_state = "warn"; _t = 0.0
		"warn":
			# telegraph: spikes shiver just above the plate, tinted hot
			_spikes.modulate = Color(1.4, 0.7, 0.6, 0.55 + 0.3 * sin(_t * 40.0))
			_spikes.position.y = 2.0
			if _t >= SPIKE_WARN:
				_state = "up"; _t = 0.0
				_boom()
				if _player_over(p, span * 0.5, 46.0):
					_hit(p, damage, 40.0, 9.0)
		"up":
			_spikes.modulate = Color(1, 1, 1, 1)
			_spikes.position.y = -24.0
			if _player_over(p, span * 0.5, 46.0) and _hit_cd <= 0.0:
				_hit(p, int(damage * 0.5), 20.0, 5.0)   # walking back onto raised spikes still hurts
				_hit_cd = 0.4
			if _t >= SPIKE_UP:
				_state = "retract"; _t = 0.0
		"retract":
			_spikes.position.y = lerpf(-24.0, 6.0, clampf(_t / SPIKE_RETRACT, 0.0, 1.0))
			_spikes.modulate.a = lerpf(1.0, 0.0, clampf(_t / SPIKE_RETRACT, 0.0, 1.0))
			if _t >= SPIKE_RETRACT:
				_state = "cd"; _t = 0.0
		"cd":
			if _t >= SPIKE_CD:
				_state = "idle"; _t = 0.0

# ---------------- FLAMEVENT: a rhythmic fire jet ----------------
func _build_flamevent() -> void:
	_nozzle = Polygon2D.new()
	_nozzle.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(9, -12), Vector2(-9, -12)])
	_nozzle.color = Color(0.25, 0.22, 0.2, 1.0)
	add_child(_nozzle)
	_flame = Polygon2D.new()
	_flame.color = Color(1.0, 0.55, 0.15, 0.9)
	_flame.polygon = PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(9, -FLAME_H), Vector2(0, -FLAME_H - 24), Vector2(-9, -FLAME_H)])
	_flame.position.y = -10.0
	_flame.scale.y = 0.0
	add_child(_flame)
	_flame_light = PointLight2D.new()
	_flame_light.texture = _light_tex()
	_flame_light.texture_scale = 2.6
	_flame_light.color = Color(1.0, 0.6, 0.25)
	_flame_light.energy = 0.0
	_flame_light.shadow_enabled = false
	_flame_light.position = Vector2(0, -30.0)
	add_child(_flame_light)

func _tick_flamevent() -> void:
	var cycle := FLAME_DORMANT + FLAME_ERUPT
	var ph := fmod(_t, cycle)
	if ph < FLAME_DORMANT:
		_flame.scale.y = 0.0
		# glow the nozzle as the tell
		var tell := ph > (FLAME_DORMANT - FLAME_TELL)
		_nozzle.color = Color(1.0, 0.5, 0.2, 1.0) if tell else Color(0.25, 0.22, 0.2, 1.0)
		if _flame_light:
			_flame_light.energy = 0.25 if tell else 0.0   # a faint pre-glow on the tell
	else:
		var e := (ph - FLAME_DORMANT) / FLAME_ERUPT
		# quick whoosh up, flicker, then snuff
		_flame.scale.y = clampf(sin(e * PI) * 1.15, 0.0, 1.0)
		_flame.scale.x = 1.0 + 0.15 * sin(_t * 30.0)
		if _flame_light:
			_flame_light.energy = _flame.scale.y * 1.3 + 0.1 * sin(_t * 30.0)  # light pulses with the jet
		if _flame.scale.y > 0.35:
			var p := _player()
			if p != null and absf(p.global_position.x - global_position.x) <= span * 0.5 \
					and p.global_position.y <= global_position.y + 20.0 \
					and p.global_position.y >= global_position.y - FLAME_H - 30.0 \
					and _hit_cd <= 0.0:
				_hit(p, int(damage * 0.7), 0.0, 4.0)
				_hit_cd = 0.3

# ---------------- CRUSHER: a ceiling block that slams ----------------
func _build_crusher() -> void:
	# a guide rail up to the ceiling
	var rail := ColorRect.new()
	rail.size = Vector2(6.0, CRUSH_HEIGHT)
	rail.position = Vector2(-3.0, -CRUSH_HEIGHT)
	rail.color = Color(0.16, 0.15, 0.17, 0.7)
	add_child(rail)
	_block = Node2D.new()
	add_child(_block)
	var body := ColorRect.new()
	body.size = Vector2(span, 54.0)
	body.position = Vector2(-span * 0.5, -54.0)
	body.color = Color(0.26, 0.24, 0.27, 1.0)
	_block.add_child(body)
	# studded underside
	for i in range(int(span / 22.0)):
		var stud := Polygon2D.new()
		var sx := -span * 0.5 + 14.0 + i * 22.0
		stud.polygon = PackedVector2Array([Vector2(sx - 6, 0), Vector2(sx + 6, 0), Vector2(sx, 10)])
		stud.color = Color(0.5, 0.5, 0.55, 1.0)
		_block.add_child(stud)
	_block.position.y = -CRUSH_HEIGHT

func _tick_crusher() -> void:
	var p := _player()
	match _state:
		"idle", "":
			_block.position.y = -CRUSH_HEIGHT
			if _player_over(p, span * 0.5, VERT_TOLERANCE + 40.0):
				_state = "warn"; _t = 0.0
		"warn":
			# a shudder before the drop
			_block.position.y = -CRUSH_HEIGHT + 6.0 * sin(_t * 44.0)
			if _t >= CRUSH_WARN:
				_state = "drop"; _t = 0.0
		"drop":
			_block.position.y = lerpf(-CRUSH_HEIGHT, -6.0, clampf(_t / CRUSH_DROP, 0.0, 1.0))
			if _t >= CRUSH_DROP:
				_state = "impact"; _t = 0.0
				_boom()
				if _player_over(p, span * 0.5, 52.0):
					_hit(p, damage, 30.0, 11.0)
		"impact":
			_block.position.y = -6.0
			if _t >= CRUSH_HOLD:
				_state = "rise"; _t = 0.0
		"rise":
			_block.position.y = lerpf(-6.0, -CRUSH_HEIGHT, clampf(_t / CRUSH_RISE, 0.0, 1.0))
			if _t >= CRUSH_RISE:
				_state = "cd"; _t = 0.0
		"cd":
			if _t >= CRUSH_CD:
				_state = "idle"; _t = 0.0

# ---------------- GAS: a rhythmic poison geyser ----------------
func _build_gas() -> void:
	var vent := Polygon2D.new()
	vent.polygon = PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(8, -10), Vector2(-8, -10)])
	vent.color = Color(0.2, 0.26, 0.18, 1.0)
	add_child(vent)
	_cloud = Node2D.new()
	add_child(_cloud)
	var puff := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * GAS_R, sin(a) * GAS_R * 0.7 - GAS_R * 0.5))
	puff.polygon = pts
	puff.color = Color(0.5, 0.85, 0.4, 0.32)
	_cloud.add_child(puff)
	_cloud.scale = Vector2.ZERO

func _tick_gas() -> void:
	var cycle := GAS_DORMANT + GAS_SPEW
	var ph := fmod(_t, cycle)
	if ph < GAS_DORMANT:
		_cloud.scale = Vector2.ZERO
	else:
		var e := (ph - GAS_DORMANT) / GAS_SPEW
		_cloud.scale = Vector2.ONE * clampf(sin(e * PI) * 1.2, 0.0, 1.0)
		if _cloud.scale.x > 0.35:
			var p := _player()
			if p != null and absf(p.global_position.x - global_position.x) <= GAS_R \
					and absf(p.global_position.y - global_position.y) <= GAS_R \
					and _hit_cd <= 0.0:
				# poison follows you out of the cloud -- the price of breathing it
				if p.has_method("apply_poison"):
					p.apply_poison(3.0, maxf(3.0, damage * 0.25))
				_hit_cd = 1.2
