extends Node2D

# EMBEDDED STACKS (weapon overhaul, 2026-07-29) -- the "aftermath" system for
# weapons whose damage LIVES ON inside the victim: barbs that stick, tick, and
# overflow. Adapted from the study's stacking-embed family (Daybreak's spears,
# Bone Javelin's impalement, Tentacle Spike / Blood Butcherer's barbs) -- never
# 1:1, and generic on purpose so the other three can reuse it later.
#
# THE POINT IS THAT YOU CAN COUNT IT. The study's law: a stack the player can
# SEE (spears sticking out of the boss) beats a number in a corner of the UI.
#
# Lives as a child of the victim, so it dies with them -- no registry to leak.
# Usage:  EmbeddedStack.drive(victim, "regicide", cfg).add_one(dmg)

const GROUP := "embedded_stack"

var kind := "regicide"
var max_stacks := 5
var tick_gap := 0.5          # seconds between bites
var life := 6.0              # how long one barb lasts if never overflowed
var tick_damage := 4
var pop_damage := 30         # what the OLDEST barb does when pushed out
# THE QUIET RECKONING (T7) wants the opposite economy from Regicide: its
# barbs are not a stack you overflow, they are a DEBT that comes due. With
# this set, a barb pays its pop when its own time runs out, not only when a
# newer one shoves it off.
var pop_on_expire := false
# THE DEBT COLLECTOR (T6) wants a THIRD economy: Regicide overflows, the
# Reckoning comes due, and this one INHERITS. If the debtor dies still owing,
# the book does not close -- it moves to whoever is standing nearest, one
# stack heavier for the trouble.
var transfer_on_death := false
# THE SILENT CHOIR (T6) is the fourth economy: its marks do NOTHING while
# they gather -- no tick, no pop -- and then the full stack sings at once.
# Build-and-release rather than overflow, debt, or inheritance.
var burst_at_max := false
var burst_damage := 0
# KING'S RANSOM (T5) is the fifth economy: the mark is a PRICE. It does no
# damage at all -- it only pays out, in gold, if the marked one dies while it
# still stands.
var ransom_gold := 0
var tint := Color(0.95, 0.85, 0.45)
var owner_player: Node = null

var _barbs: Array = []       # [{node: Node2D, dies_at: float}]
var _t := 0.0

# find (or create) the stack driving this victim
static func drive(victim: Node2D, k: String, cfg: Dictionary) -> Node:
	if victim == null or not is_instance_valid(victim):
		return null
	for c in victim.get_children():
		if c is Node2D and c.get("kind") == k and c.is_in_group(GROUP):
			return c
	var s = load("res://embedded_stack.gd").new()
	s.kind = k
	s.max_stacks = int(cfg.get("max", 5))
	s.tick_gap = float(cfg.get("gap", 0.5))
	s.life = float(cfg.get("life", 6.0))
	s.tick_damage = int(cfg.get("tick", 4))
	s.pop_damage = int(cfg.get("pop", 30))
	s.owner_player = cfg.get("player", null)
	s.pop_on_expire = bool(cfg.get("pop_on_expire", false))
	s.transfer_on_death = bool(cfg.get("transfer_on_death", false))
	s.burst_at_max = bool(cfg.get("burst_at_max", false))
	s.burst_damage = int(cfg.get("burst", 0))
	s.ransom_gold = int(cfg.get("ransom", 0))
	if cfg.has("tint"):
		s.tint = cfg["tint"]
	s.add_to_group(GROUP)
	s.z_index = 6
	victim.add_child(s)
	return s

func add_one(_dmg: int = 0) -> void:
	# BUILD-AND-RELEASE: the last voice completes the chord and the whole
	# stack goes off together, instead of the oldest being shoved out
	if burst_at_max and _barbs.size() + 1 >= max_stacks:
		_sing()
		return
	# the newest barb pushes the oldest OUT, and going out is the payoff
	if _barbs.size() >= max_stacks:
		_pop_oldest()
	var b := _make_barb(_barbs.size())
	add_child(b)
	_barbs.append({"node": b, "dies_at": _t + life})

func stack_count() -> int:
	return _barbs.size()

func _process(delta: float) -> void:
	_t += delta
	var victim := get_parent()
	if victim == null or not is_instance_valid(victim) \
			or ("is_dead" in victim and victim.is_dead):
		if transfer_on_death and not _barbs.is_empty():
			_inherit()
		if ransom_gold > 0 and not _barbs.is_empty():
			_collect_ransom()
		queue_free()
		return
	# barbs whose time ran out leave the same way they would if pushed
	var expired := []
	for b in _barbs:
		if _t >= b["dies_at"]:
			expired.append(b)
	for b in expired:
		_barbs.erase(b)
		_burst(b, pop_on_expire)   # a debt that came due, or just a barb falling out
	# the bite -- but a SILENT stack is silent, and a RANSOM never bites at
	# all: it is a price, and prices are collected, not paid in blood
	if _barbs.is_empty() or burst_at_max or ransom_gold > 0:
		_animate_barbs()
		return
	if fmod(_t, tick_gap) < delta:
		var total: int = tick_damage * _barbs.size()
		if victim.has_method("take_damage"):
			var landed = victim.take_damage(total)
			if landed == null or landed:
				FloatingText.spawn(_stage(), (victim as Node2D).global_position
					+ Vector2(randf_range(-20.0, 20.0), -26.0), total, false)
	_animate_barbs()

# the debtor died owing: the book moves to the nearest body still standing,
# one stack heavier. A room can pass one debt around until it runs out of
# people, which is the entire fantasy of the weapon.
func _inherit() -> void:
	var here: Vector2 = global_position
	var owed: int = _barbs.size()
	var best: Node2D = null
	var best_d := 340.0
	for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or e == get_parent():
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if not e.has_method("take_damage"):
				continue
			var d: float = here.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
	if best == null:
		return
	var heir = (load("res://embedded_stack.gd") as GDScript).new()
	heir.kind = kind
	heir.max_stacks = max_stacks
	heir.tick_gap = tick_gap
	heir.life = life
	heir.tick_damage = tick_damage
	heir.pop_damage = pop_damage
	heir.owner_player = owner_player
	heir.pop_on_expire = pop_on_expire
	heir.transfer_on_death = transfer_on_death
	heir.tint = tint
	heir.add_to_group(GROUP)
	heir.z_index = 6
	best.add_child(heir)
	for i in range(mini(max_stacks, owed + 1)):
		heir.add_one(0)
	var host := _stage()
	if host != null:
		FloatingText.spawn_word(host, (best as Node2D).global_position + Vector2(0, -46),
			"the debt passes", Color(0.98, 0.86, 0.42))

# the price is paid: the marked one died still carrying it
func _collect_ransom() -> void:
	var at: Vector2 = global_position
	var paid: int = ransom_gold * maxi(1, _barbs.size())
	GameState.gold += paid
	var host := _stage()
	if host == null:
		return
	FloatingText.spawn_word(host, at + Vector2(0, -44), "+%dg ransom" % paid, tint)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(6):
		var coin := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in range(8):
			var a := TAU * float(k) / 8.0
			pts.append(Vector2(cos(a), sin(a)) * 4.5)
		coin.polygon = pts
		coin.color = Color(1.0, 0.87, 0.4, 0.95)
		coin.material = m
		coin.z_index = 46
		host.add_child(coin)
		coin.global_position = at
		var away: Vector2 = at + Vector2(randf_range(-46.0, 46.0), randf_range(-52.0, -18.0))
		var tw := coin.create_tween()
		tw.set_parallel(true)
		tw.tween_property(coin, "global_position", away, 0.5).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(coin, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(coin.queue_free)

# the chord: every voice gathered pays at once, and the stack is spent
func _sing() -> void:
	var victim := get_parent()
	var at: Vector2 = global_position
	var voices: int = _barbs.size() + 1
	for b in _barbs:
		var n = b.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_barbs.clear()
	var host := _stage()
	if victim != null and is_instance_valid(victim) and victim.has_method("take_damage"):
		var total: int = burst_damage * voices
		var landed = victim.take_damage(total)
		if landed == null or landed:
			FloatingText.spawn(host, at + Vector2(0, -40.0), total, true)
	if host != null:
		FloatingText.spawn_word(host, at + Vector2(0, -58.0), "the choir sings", tint)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for v in range(voices):
			var ring := Polygon2D.new()
			var pts := PackedVector2Array()
			for i in range(16):
				var a := TAU * float(i) / 16.0
				pts.append(Vector2(cos(a), sin(a)) * 14.0)
			for i in range(16):
				var a2 := TAU * float(15 - i) / 16.0
				pts.append(Vector2(cos(a2), sin(a2)) * 11.0)
			ring.polygon = pts
			ring.color = Color(tint.r, tint.g, tint.b, 0.75)
			ring.material = m
			ring.z_index = 45
			host.add_child(ring)
			ring.global_position = at
			var tw := ring.create_tween()
			tw.tween_interval(0.05 * float(v))
			tw.set_parallel(true)
			tw.tween_property(ring, "scale", Vector2.ONE * (2.0 + 0.7 * float(v)), 0.34)
			tw.tween_property(ring, "modulate:a", 0.0, 0.34)
			tw.chain().tween_callback(ring.queue_free)
	queue_free()

func _pop_oldest() -> void:
	if _barbs.is_empty():
		return
	var b = _barbs.pop_front()
	_burst(b, true)

# a barb leaving: the burst is the reward for overflowing the stack
func _burst(b: Dictionary, paid: bool) -> void:
	var n = b.get("node")
	var at: Vector2 = global_position
	if n != null and is_instance_valid(n):
		at = (n as Node2D).global_position
		n.queue_free()
	var victim := get_parent()
	if paid and victim != null and is_instance_valid(victim) and victim.has_method("take_damage"):
		var landed = victim.take_damage(pop_damage)
		if landed == null or landed:
			FloatingText.spawn(_stage(), at + Vector2(0, -34.0), pop_damage, true)
	var host := _stage()
	if host == null:
		return
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(9):
		var a := TAU * float(i) / 9.0
		# the overflow ring measured ~1.5 player-heights across in the source;
		# ours was about a third of that (fidelity pass)
		pts.append(Vector2(cos(a), sin(a)) * (22.0 if paid else 10.0))
	ring.polygon = pts
	ring.color = Color(tint.r, tint.g, tint.b, 0.8 if paid else 0.45)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = m
	ring.z_index = 45
	host.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4) if paid else Vector2(1.5, 1.5), 0.28)
	tw.tween_property(ring, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(ring.queue_free)

# one embedded spear, angled so a row of them reads as a COUNT at a glance
func _make_barb(idx: int) -> Node2D:
	var holder := Node2D.new()
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-1.7, 0), Vector2(-1.2, -17.0), Vector2(1.2, -17.0), Vector2(1.7, 0)])
	shaft.color = Color(tint.r * 0.55, tint.g * 0.5, tint.b * 0.45, 0.95)
	holder.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(0, -25.0), Vector2(3.6, -16.0), Vector2(0, -12.5), Vector2(-3.6, -16.0)])
	head.color = Color(tint.r, tint.g, tint.b, 0.98)
	holder.add_child(head)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, -28.0), Vector2(5.4, -16.0), Vector2(0, -9.5), Vector2(-5.4, -16.0)])
	glow.color = Color(tint.r, tint.g, tint.b, 0.28)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	holder.add_child(glow)
	# fan them so five are five distinct silhouettes, not one thick smear
	holder.rotation = deg_to_rad(-38.0 + 19.0 * float(idx))
	holder.position = Vector2(-14.0 + 7.0 * float(idx), -4.0)
	return holder

func _animate_barbs() -> void:
	# a slight breathing sway so the stack reads as ALIVE and stuck in flesh
	for i in range(_barbs.size()):
		var n = _barbs[i].get("node")
		if n != null and is_instance_valid(n):
			(n as Node2D).rotation = deg_to_rad(-38.0 + 19.0 * float(i)) \
				+ sin(_t * 4.0 + float(i)) * 0.05

func _stage() -> Node:
	var s = get_tree().current_scene if get_tree() != null else null
	return s if s != null else get_parent()
