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

# HOW a minion fights, separate from WHAT it looks like. Seventeen scepters
# would be seventeen near-identical darters if body and behaviour were the same
# axis, so they are two:
#   ""      dart out, hit, come home        (the default; blade/mudling/beast)
#   "loop"  a FIXED elliptical circuit -- metronome reliability, never chases
#   "lob"   stays put and throws (the wisp's old exclusive, now a style)
#   "latch" rides the target and ticks instead of returning
#   "blink" teleports above the mark and snipes -- never out of position
#   "ram"   drives THROUGH bodies rather than stopping at one
var style := ""
# THE BOND (Bondmaster spec). Your FIRST slot stops being one of a crowd and
# becomes a named companion that grows with what it kills this run. Everything
# below is read only when is_bond is true, so a Hordecaller pays nothing for it.
var is_bond := false
var bond_kills := 0
var _form_broken := 0
var _latched: Node2D = null
var _loop_t := 0.0
var _empower := 0        # Keeper of One: recasts make her stronger, not more
var _coils := 1          # The Long Procession: a coil per cast

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
		# ---- the Summoner's bestiary ----
		"mudling": _build_mudling()
		"finch": _build_finch()
		"bat": _build_bat()
		"warden": _build_warden()
		"imp": _build_imp()
		"spiderling": _build_spiderling()
		"cub": _build_cub()
		"twin": _build_twin()
		"lanterneye": _build_lanterneye()
		"saw": _build_saw()
		"cell": _build_cell()
		"direhound": _build_direhound()
		"serpent": _build_serpent()
		"lightblade": _build_lightblade()
		"namebearer": _build_namebearer()
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
	# --- the styles that own their whole frame ---
	if style == "loop":
		_tick_loop(delta)
		return
	if style == "latch" and _latched != null:
		_tick_latched(delta)
		return
	if style == "blink":
		_tick_blink(delta)
		return
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
					if kind == "wisp" or style == "lob":
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

# --- THE STYLES -------------------------------------------------------

# LOOP: a fixed elliptical circuit around the player. It never chases, which
# makes it the most RELIABLE minion in the class and the least clever -- you
# position yourself so the circuit crosses them.
func _tick_loop(delta: float) -> void:
	_loop_t += delta
	var a: float = _loop_t * 2.4 + float(slot) * 1.4
	var centre: Vector2 = player.global_position + Vector2(0, -30.0)
	global_position = centre + Vector2(cos(a) * 92.0, sin(a) * 40.0)
	if visual != null:
		visual.scale.x = -1.0 if cos(a) < 0.0 else 1.0
	if _cool > 0.0:
		return
	# it bites whatever the circuit happens to be passing
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if _is_dead(e):
				continue
			if global_position.distance_to((e as Node2D).global_position) > 38.0:
				continue
			_mark = e
			_mark_point = (e as Node2D).global_position
			_land()
			return

# LATCH: it does not come home. It rides them and keeps biting -- the pack's
# damage-over-time body. Cheap to read: if a spider is on you, you are losing.
func _tick_latched(delta: float) -> void:
	if not is_instance_valid(_latched) or _is_dead(_latched):
		_latched = null
		_state = 2
		return
	global_position = (_latched as Node2D).global_position \
		+ Vector2(sin(_bob_t * 5.0) * 12.0, -10.0 + cos(_bob_t * 4.0) * 6.0)
	if _cool > 0.0:
		return
	_mark = _latched
	_mark_point = global_position
	_land()

# BLINK: it never travels. It appears above the mark and snipes, so it is
# never out of position and never wastes a second flying.
func _tick_blink(delta: float) -> void:
	if _cool > 0.0:
		# drift home between shots so it still reads as YOURS
		var home: Vector2 = player.global_position + _slot_offset()
		global_position = global_position.lerp(home, minf(1.0, 4.0 * delta))
		return
	var prey := _find_mark()
	if prey == null:
		return
	global_position = (prey as Node2D).global_position + Vector2(0, -78.0)
	_mark = prey
	_loose_mote()
	_cool = effective_gap()

# EMPOWER (Keeper of One): a recast does not add a second warden, it makes the
# one you have angrier. The player sees her grow.
func empower() -> void:
	_empower += 1
	damage = int(round(float(damage) * 1.28))
	if visual != null:
		visual.scale = Vector2.ONE * (1.0 + 0.11 * float(_empower))

# GROW A COIL (The Long Procession): visible segments ARE its level.
func add_coil() -> void:
	_coils += 1
	damage = int(round(float(damage) * 1.16))
	if visual != null:
		_build_coil(_coils)

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
	# THE BOND GROWS with what it kills, and BREAKS FORM twice on the way.
	if is_bond:
		var growth: float = GameState.get_bonus_total("bond_growth")
		if growth > 0.0:
			d *= 1.0 + growth * float(mini(25, bond_kills))
		d *= 1.0 + GameState.get_bonus_total("bond_damage") * float(_form_broken)
	var crit := false
	var mk = BOND_MARK.mark_on(on)
	if mk != null:
		# the tree's donation plus THIS WHIP'S -- the mark carries its own terms
		d += GameState.get_bonus_total("tag_damage") + float(mk.get("bonus_damage"))
		if randf() < GameState.get_bonus_total("tag_crit") + float(mk.get("bonus_crit")):
			crit = true
			d *= 1.7
		# CANDLEWICK: the whip armed this mark, and the FIRST summon hit spends
		# it. Read as one enormous number out of nowhere, then it is gone.
		if bool(mk.get("armed")):
			mk.set("armed", false)
			d *= 2.4
			crit = true
		# MOTHER'S MERCY: summon hits on your mark mend the one who ordered it
		if str(mk.get("rider")) == "mend" and is_instance_valid(player) \
				and player.has_method("heal"):
			player.heal(1)
	return [maxi(1, int(round(d))), crit]

func _land() -> void:
	if is_instance_valid(_mark) and not _is_dead(_mark) and _mark.has_method("take_damage"):
		var roll: Array = strike_damage(_mark)
		var pay: int = int(roll[0])
		# FANG OF THE BOND: it finishes tagged prey rather than whittling them.
		# Bosses are exempt -- the boss rule allows DoT and focus, never an
		# execute, and a minion deleting a boss would be exactly that.
		var ex_pct: float = GameState.get_bonus_total("bond_execute")
		if is_bond and ex_pct > 0.0 and BOND_MARK.is_marked(_mark) \
				and not _mark.is_in_group("boss") \
				and "health" in _mark and "max_health" in _mark \
				and float(_mark.max_health) > 0.0 \
				and float(_mark.health) / float(_mark.max_health) <= ex_pct:
			pay = int(_mark.health)
			FloatingText.spawn_word(get_parent(),
				(_mark as Node2D).global_position + Vector2(0, -46), "finished",
				Color(0.95, 0.76, 0.4))
		var was_alive: bool = ("health" not in _mark) or int(_mark.health) > 0
		var landed = _mark.take_damage(pay)
		_after_strike(_mark, was_alive)
		if landed == null or landed:
			FloatingText.spawn(get_parent(), _mark.global_position, pay, bool(roll[1]))
		HitFx.burst(get_parent(), _mark_point, "physical", bool(roll[1]))
		if _mark.has_method("apply_knockback"):
			_mark.apply_knockback(1 if global_position.x < _mark.global_position.x else -1, 24.0)
	SfxSynth.play_at(self, global_position, "pop", -18.0, 1.5)
	_cool = effective_gap()
	# LATCH rides them instead of coming home -- that IS the body
	if style == "latch" and is_instance_valid(_mark) and not _is_dead(_mark):
		_latched = _mark
		return
	# RAM drives THROUGH: it does not turn for home, it looks for the next body
	# and keeps going. Only an empty room sends it back.
	if style == "ram":
		var next_body := _find_mark()
		if next_body != null and next_body != _mark:
			_mark = next_body
			_mark_point = next_body.global_position
			_state = 1
			return
	_state = 2

# Everything that keys off a summon's KILL lives here, so the horde echo and
# the Bond's growth cannot drift apart from each other.
func _after_strike(victim: Node, was_alive: bool) -> void:
	if not summoned or not was_alive:
		return
	var died: bool = ("health" in victim and int(victim.health) <= 0) \
		or ("is_dead" in victim and victim.is_dead)
	if not died:
		return
	# FORM BREAK: at 10 and again at 20 the Bond outgrows its own shape
	if is_bond:
		bond_kills += 1
		if GameState.get_bonus_total("bond_form") > 0.0:
			var want_forms: int = (1 if bond_kills >= 10 else 0) + (1 if bond_kills >= 20 else 0)
			if want_forms > _form_broken:
				_form_broken = want_forms
				if visual != null:
					visual.scale = Vector2.ONE * (1.0 + 0.22 * float(_form_broken))
				FloatingText.spawn_word(get_parent(),
					global_position + Vector2(0, -40), "form breaks",
					Color(0.95, 0.7, 0.35))
	# THE HUNDRED HANDS: a kill may call a short-lived echo of the killer.
	# It is deliberately NOT a permanent slot -- the horde refuses arithmetic,
	# but it must not refuse the slot cap either.
	var echo_odds: float = GameState.get_bonus_total("horde_echo")
	if echo_odds <= 0.0 or randf() >= echo_odds:
		return
	var standing := 0
	for c in get_parent().get_children():
		if c.get("_is_echo") == true:
			standing += 1
	if standing >= 4:
		return
	var echo = load("res://companion.gd").new()
	echo.kind = kind
	echo.style = style
	echo.summoned = true
	echo.damage = maxi(1, int(round(float(damage) * 0.6)))
	echo.gap = gap
	echo.player = player
	echo.slot = 5 + standing
	echo.set("_is_echo", true)
	get_parent().add_child(echo)
	echo.global_position = global_position
	echo.modulate = Color(1.0, 1.0, 1.0, 0.7)
	var tw: Tween = echo.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(echo, "modulate:a", 0.0, 0.4)
	tw.tween_callback(echo.queue_free)

var _is_echo := false

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

# ==========================================================================
# THE SUMMONER'S BESTIARY (batch 2). Thirteen more bodies. Each is a promise
# made flesh, not a tamed monster -- the Law of Despair says the fallen are
# PEOPLE, so nothing here is a captured beast. They are shapes hope takes.
# ==========================================================================

# A helper: the class's amber additive material, used by nearly every body.
func _amber() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# THE QUIET CONGREGATION: a chapel-bat. Reads as devout, not vermin.
func _build_bat() -> void:
	for s in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.polygon = PackedVector2Array([
			Vector2(0, -1.0), Vector2(-6, -9.0 * s), Vector2(-13, -4.0 * s),
			Vector2(-9, 1.0 * s), Vector2(-3, 2.0 * s)])
		wing.color = Color(0.32, 0.28, 0.4, 0.94)
		visual.add_child(wing)
		var tw := wing.create_tween().set_loops()
		tw.tween_property(wing, "scale", Vector2(1.0, 0.4), 0.14)
		tw.tween_property(wing, "scale", Vector2(1.0, 1.0), 0.14)
	var body_b := Polygon2D.new()
	body_b.polygon = PackedVector2Array([
		Vector2(7, 0), Vector2(1, -5.0), Vector2(-6, 0), Vector2(1, 5.0)])
	body_b.color = Color(0.4, 0.34, 0.48, 0.96)
	visual.add_child(body_b)
	for ex in [-1.0, 1.0]:
		var ear := Polygon2D.new()
		ear.polygon = PackedVector2Array([
			Vector2(2.0, -5.0), Vector2(3.0 + ex, -10.0), Vector2(4.0, -4.0)])
		ear.color = Color(0.4, 0.34, 0.48, 0.96)
		visual.add_child(ear)

# KEEPER OF ONE: a ghost-warden. She should look like a person, because she is.
func _build_warden() -> void:
	var m := _amber()
	var robe := Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-9, 16.0), Vector2(-6, -8.0), Vector2(0, -14.0),
		Vector2(6, -8.0), Vector2(9, 16.0)])
	robe.color = Color(0.62, 0.68, 0.78, 0.6)
	robe.material = m
	visual.add_child(robe)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(-6, -8.0), Vector2(-4, -16.0), Vector2(4, -16.0), Vector2(6, -8.0)])
	hood.color = Color(0.74, 0.8, 0.9, 0.7)
	hood.material = m
	visual.add_child(hood)
	var lamp := Polygon2D.new()
	lamp.polygon = PackedVector2Array([
		Vector2(8, -2.0), Vector2(12, 2.0), Vector2(8, 6.0), Vector2(4, 2.0)])
	lamp.color = Color(1.0, 0.86, 0.5, 0.9)
	lamp.material = m
	visual.add_child(lamp)

# EMBERWARD: a hearth-imp. Small, hot, and entirely willing.
func _build_imp() -> void:
	var m := _amber()
	var body_i := Polygon2D.new()
	body_i.polygon = PackedVector2Array([
		Vector2(-7, 8.0), Vector2(-5, -6.0), Vector2(0, -10.0),
		Vector2(5, -6.0), Vector2(7, 8.0)])
	body_i.color = Color(0.6, 0.24, 0.16, 0.95)
	visual.add_child(body_i)
	for ex in [-1.0, 1.0]:
		var horn := Polygon2D.new()
		horn.polygon = PackedVector2Array([
			Vector2(3.0 * ex, -9.0), Vector2(5.0 * ex, -16.0), Vector2(1.0 * ex, -9.0)])
		horn.color = Color(0.34, 0.16, 0.12, 0.96)
		visual.add_child(horn)
	var coal := Polygon2D.new()
	coal.polygon = _ring_pts(5.0, 8)
	coal.color = Color(1.0, 0.6, 0.2, 0.85)
	coal.material = m
	coal.position = Vector2(0, -1.0)
	visual.add_child(coal)
	var tw := coal.create_tween().set_loops()
	tw.tween_property(coal, "modulate:a", 0.45, 0.4)
	tw.tween_property(coal, "modulate:a", 1.0, 0.4)

# THORNMOTHER'S BROOD: a spiderling. It LATCHES, so it needs legs you can see.
func _build_spiderling() -> void:
	var body_s := Polygon2D.new()
	body_s.polygon = _ring_pts(6.0, 8)
	body_s.color = Color(0.26, 0.3, 0.22, 0.96)
	visual.add_child(body_s)
	for k in range(6):
		var leg := Polygon2D.new()
		var a := PI * (0.2 + 0.6 * float(k % 3)) * (1.0 if k < 3 else -1.0)
		leg.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(cos(a) * 11.0, sin(a) * 9.0 - 3.0),
			Vector2(cos(a) * 12.0, sin(a) * 9.0 - 1.0)])
		leg.color = Color(0.2, 0.24, 0.18, 0.95)
		visual.add_child(leg)
	var venom := Polygon2D.new()
	venom.polygon = PackedVector2Array([Vector2(6, 0), Vector2(9, -1.4), Vector2(9, 1.4)])
	venom.color = Color(0.6, 0.9, 0.4, 0.9)
	venom.material = _amber()
	visual.add_child(venom)

# THE GROWING HUNT: it begins a CUB. A recast evolves it (see empower()).
func _build_cub() -> void:
	var body_c := Polygon2D.new()
	body_c.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(6, -6.0), Vector2(-5, -6.0), Vector2(-10, -1.0),
		Vector2(-11, 3.0), Vector2(-6, 5.0), Vector2(7, 5.0)])
	body_c.color = Color(0.46, 0.34, 0.24, 0.95)
	visual.add_child(body_c)
	var ear2 := Polygon2D.new()
	ear2.polygon = PackedVector2Array([Vector2(5, -6.0), Vector2(7, -11.0), Vector2(9, -5.0)])
	ear2.color = Color(0.46, 0.34, 0.24, 0.95)
	visual.add_child(ear2)
	var eye_c := Polygon2D.new()
	eye_c.polygon = PackedVector2Array([Vector2(7, -3.0), Vector2(9, -2.4), Vector2(7, -1.8)])
	eye_c.color = Color(1.0, 0.86, 0.44, 0.98)
	visual.add_child(eye_c)

# TWIN SORROWS: a PAIR in one body -- two small shapes that share a slot.
func _build_twin() -> void:
	var m := _amber()
	for ex in [-1.0, 1.0]:
		var half := Polygon2D.new()
		half.polygon = PackedVector2Array([
			Vector2(0, -7.0), Vector2(6.0 * ex, 0), Vector2(0, 7.0)])
		half.color = Color(0.7, 0.72, 0.86, 0.9) if ex < 0.0 \
			else Color(0.9, 0.8, 0.6, 0.9)
		half.material = m
		half.position = Vector2(7.0 * ex, 0)
		visual.add_child(half)
		var tw := half.create_tween().set_loops()
		tw.tween_property(half, "position:y", -4.0, 0.7)
		tw.tween_property(half, "position:y", 4.0, 0.7)

# THE LANTERN THAT BLINKS: an eye in a lamp-cage. It teleports, so it must
# look like something that was never really THERE.
func _build_lanterneye() -> void:
	var m := _amber()
	var cage := Polygon2D.new()
	cage.polygon = _ring_pts(12.0, 8)
	cage.color = Color(0.3, 0.3, 0.36, 0.5)
	visual.add_child(cage)
	var eye_l := Polygon2D.new()
	eye_l.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(0, -6.0), Vector2(9, 0), Vector2(0, 6.0)])
	eye_l.color = Color(0.96, 0.88, 0.56, 0.95)
	eye_l.material = m
	visual.add_child(eye_l)
	var pupil_l := Polygon2D.new()
	pupil_l.polygon = _ring_pts(2.6, 6)
	pupil_l.color = Color(0.1, 0.09, 0.12, 0.98)
	visual.add_child(pupil_l)

# SAWTOOTH PSALM: a whirring wheel of teeth. It RAMS, so it reads as momentum.
func _build_saw() -> void:
	var m := _amber()
	var disc := Polygon2D.new()
	disc.polygon = _ring_pts(9.0, 10)
	disc.color = Color(0.78, 0.8, 0.84, 0.95)
	visual.add_child(disc)
	for k in range(8):
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(-2.4, -9.0), Vector2(0, -15.0), Vector2(2.4, -9.0)])
		tooth.color = Color(0.9, 0.92, 0.96, 0.96)
		tooth.material = m
		tooth.rotation = deg_to_rad(45.0 * float(k))
		visual.add_child(tooth)
	var tw := visual.create_tween().set_loops()
	tw.tween_property(visual, "rotation", TAU, 0.4).as_relative()

# THE CLINGING CHOIR: a small singing cell. It latches and stacks.
func _build_cell() -> void:
	var m := _amber()
	var shell := Polygon2D.new()
	shell.polygon = _ring_pts(7.0, 9)
	shell.color = Color(0.7, 0.86, 0.9, 0.72)
	shell.material = m
	visual.add_child(shell)
	var mouth := Polygon2D.new()
	mouth.polygon = PackedVector2Array([
		Vector2(-3.4, 0), Vector2(0, -3.0), Vector2(3.4, 0), Vector2(0, 3.4)])
	mouth.color = Color(0.96, 1.0, 1.0, 0.9)
	mouth.material = m
	visual.add_child(mouth)

# KENNEL OF THE DEEP: a dire hound. Bigger, heavier, and it should look it.
func _build_direhound() -> void:
	var body_d := Polygon2D.new()
	body_d.polygon = PackedVector2Array([
		Vector2(17, -2.0), Vector2(11, -10.0), Vector2(-6, -9.0), Vector2(-17, -3.0),
		Vector2(-19, 3.0), Vector2(-12, 7.0), Vector2(13, 7.0), Vector2(18, 2.0)])
	body_d.color = Color(0.18, 0.16, 0.24, 0.95)
	visual.add_child(body_d)
	for ex in [0.0, 4.0]:
		var ear3 := Polygon2D.new()
		ear3.polygon = PackedVector2Array([
			Vector2(9.0 + ex, -10.0), Vector2(12.0 + ex, -17.0), Vector2(14.0 + ex, -9.0)])
		ear3.color = Color(0.18, 0.16, 0.24, 0.95)
		visual.add_child(ear3)
	for ex2 in [10.0, 13.5]:
		var eye_d := Polygon2D.new()
		eye_d.polygon = PackedVector2Array([
			Vector2(ex2, -6.0), Vector2(ex2 + 2.4, -5.2), Vector2(ex2, -4.4)])
		eye_d.color = Color(1.0, 0.6, 0.28, 0.98)
		eye_d.material = _amber()
		visual.add_child(eye_d)

# THE LONG PROCESSION: a grave-serpent that GROWS a coil per cast. The coils
# are its level, drawn so you can count them.
func _build_serpent() -> void:
	_build_coil(_coils)

func _build_coil(n: int) -> void:
	for c in visual.get_children():
		c.queue_free()
	var m := _amber()
	for i in range(n):
		var seg := Polygon2D.new()
		var r: float = 9.0 - 0.5 * float(i)
		seg.polygon = _ring_pts(maxf(3.5, r), 8)
		seg.color = Color(0.4, 0.5, 0.42, 0.92)
		seg.position = Vector2(-13.0 * float(i), sin(float(i) * 1.1) * 5.0)
		visual.add_child(seg)
	var head_s := Polygon2D.new()
	head_s.polygon = PackedVector2Array([
		Vector2(13, 0), Vector2(3, -7.0), Vector2(-4, 0), Vector2(3, 7.0)])
	head_s.color = Color(0.56, 0.68, 0.54, 0.96)
	head_s.material = m
	visual.add_child(head_s)

# THE UNERRING: blades of light in formation. They never whiff, so they should
# look assembled rather than alive.
func _build_lightblade() -> void:
	var m := _amber()
	for k in range(3):
		var blade_u := Polygon2D.new()
		blade_u.polygon = PackedVector2Array([
			Vector2(15, 0), Vector2(2, -3.4), Vector2(-9, 0), Vector2(2, 3.4)])
		blade_u.color = Color(1.0, 0.96, 0.82, 0.9 - 0.2 * float(k))
		blade_u.material = m
		blade_u.position = Vector2(-6.0 * float(k), -6.0 + 6.0 * float(k))
		visual.add_child(blade_u)

# THE HUNDREDTH NAME: a bearer carrying the roll of the living. Its light is
# literally the village's, so it must read as WRITING.
func _build_namebearer() -> void:
	var m := _amber()
	var scroll := Polygon2D.new()
	scroll.polygon = PackedVector2Array([
		Vector2(-11, -8.0), Vector2(11, -8.0), Vector2(11, 8.0), Vector2(-11, 8.0)])
	scroll.color = Color(0.9, 0.86, 0.7, 0.94)
	visual.add_child(scroll)
	for k in range(4):
		var line_n := Polygon2D.new()
		line_n.polygon = PackedVector2Array([
			Vector2(-8, -5.0 + 3.2 * float(k)), Vector2(7, -5.0 + 3.2 * float(k)),
			Vector2(7, -4.2 + 3.2 * float(k)), Vector2(-8, -4.2 + 3.2 * float(k))])
		line_n.color = Color(0.4, 0.34, 0.26, 0.85)
		visual.add_child(line_n)
	var glow_n := Polygon2D.new()
	glow_n.polygon = _ring_pts(15.0, 10)
	glow_n.color = Color(1.0, 0.86, 0.5, 0.24)
	glow_n.material = m
	visual.add_child(glow_n)

func _ring_pts(r: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

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
