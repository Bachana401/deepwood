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
	if cfg.has("tint"):
		s.tint = cfg["tint"]
	s.add_to_group(GROUP)
	s.z_index = 6
	victim.add_child(s)
	return s

func add_one(_dmg: int = 0) -> void:
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
		queue_free()
		return
	# barbs whose time ran out leave the same way they would if pushed
	var expired := []
	for b in _barbs:
		if _t >= b["dies_at"]:
			expired.append(b)
	for b in expired:
		_barbs.erase(b)
		_burst(b, false)
	# the bite
	if _barbs.is_empty():
		return
	if fmod(_t, tick_gap) < delta:
		var total: int = tick_damage * _barbs.size()
		if victim.has_method("take_damage"):
			var landed = victim.take_damage(total)
			if landed == null or landed:
				FloatingText.spawn(_stage(), (victim as Node2D).global_position
					+ Vector2(randf_range(-20.0, 20.0), -26.0), total, false)
	_animate_barbs()

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
		pts.append(Vector2(cos(a), sin(a)) * (16.0 if paid else 9.0))
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
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4) if paid else Vector2(1.5, 1.5), 0.26)
	tw.tween_property(ring, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(ring.queue_free)

# one embedded spear, angled so a row of them reads as a COUNT at a glance
func _make_barb(idx: int) -> Node2D:
	var holder := Node2D.new()
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-2.0, 0), Vector2(-1.4, -22.0), Vector2(1.4, -22.0), Vector2(2.0, 0)])
	shaft.color = Color(tint.r * 0.55, tint.g * 0.5, tint.b * 0.45, 0.95)
	holder.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(0, -32.0), Vector2(4.5, -20.0), Vector2(0, -16.0), Vector2(-4.5, -20.0)])
	head.color = Color(tint.r, tint.g, tint.b, 0.98)
	holder.add_child(head)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, -36.0), Vector2(7.0, -20.0), Vector2(0, -12.0), Vector2(-7.0, -20.0)])
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
