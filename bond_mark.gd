extends Node2D

# THE BOND-MARK (Summoner, batch 1 — 2026-07-30).
#
# The Summoner's active heart. A whip hit paints this sigil on one foe, and
# the whole pack turns to look. ONE mark exists at a time: painting a new one
# moves it, so CHOOSING the target is the skill rather than stacking debuffs.
#
# It is damage-focus, never crowd control -- the boss rule stands, so a boss
# can wear the mark and lose nothing but the argument.
#
# Lives as a child of the marked foe, so it dies with them; no registry to
# leak, exactly like embedded_stack.gd.

const GROUP := "bond_mark"

var life := 4.0
# WHAT THIS PARTICULAR WHIP DONATED. The mark carries the donation rather than
# the player, because the donation belongs to the whip that painted it -- swap
# whips and the mark already in the world keeps the terms it was made under.
var bonus_damage := 0.0
var bonus_crit := 0.0
var rider := ""          # the whip's signature (see whip_crack)
var charge := 0          # Stormlash counts whip hits on this mark
var armed := false       # Candlewick: the next summon hit DETONATES
var _t := 0.0
var _ring: Polygon2D = null
var _spin: Node2D = null

# Paint the mark on `victim`, moving it off whoever wore it before.
# Returns the mark node (or null if the victim cannot wear one).
static func paint(victim: Node2D, dur: float = 4.0, terms: Dictionary = {}) -> Node:
	if victim == null or not is_instance_valid(victim):
		return null
	if "is_dead" in victim and victim.is_dead:
		return null
	var tree := victim.get_tree()
	if tree == null:
		return null
	# refreshing the SAME foe just resets the clock -- re-tagging your current
	# target should feel like keeping the pack on it, not like re-acquiring
	for old in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(old):
			continue
		if old.get_parent() == victim:
			old.set("_t", 0.0)
			old.set("life", dur)
			# a re-tag re-arms the rider: hitting them again should feel like
			# renewing the order, not like the whip going quiet
			old.set("charge", int(old.get("charge")) + 1)
			if bool(terms.get("armed", false)):
				old.set("armed", true)
			return old
		old.queue_free()
	var m = load("res://bond_mark.gd").new()
	m.life = dur
	m.bonus_damage = float(terms.get("tag_dmg", 0.0))
	m.bonus_crit = float(terms.get("tag_crit", 0.0))
	m.rider = str(terms.get("rider", ""))
	m.armed = bool(terms.get("armed", false))
	m.charge = 1
	m.add_to_group(GROUP)
	victim.add_child(m)
	return m

# the mark riding this foe, if any -- companions read its terms
static func mark_on(who: Node) -> Node:
	if who == null or not is_instance_valid(who):
		return null
	for c in who.get_children():
		if c.is_in_group(GROUP):
			return c
	return null

# Who currently wears the mark, if anyone.
static func marked(tree: SceneTree) -> Node2D:
	if tree == null:
		return null
	for m in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(m):
			continue
		var host = m.get_parent()
		if host is Node2D and is_instance_valid(host):
			if "is_dead" in host and host.is_dead:
				continue
			return host
	return null

static func is_marked(who: Node) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	for c in who.get_children():
		if c.is_in_group(GROUP):
			return true
	return false

func _ready() -> void:
	z_index = 30
	position = Vector2(0, -44.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spin = Node2D.new()
	add_child(_spin)
	# a hearth-amber sigil: an open ring with three ticks, turning slowly.
	# Amber is the class colour -- it must never read as the Mage's violet or
	# the Monarch's green-black.
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a) * 0.5) * 15.0)
	for i in range(20):
		var a2 := TAU * float(19 - i) / 20.0
		pts.append(Vector2(cos(a2), sin(a2) * 0.5) * 11.5)
	_ring.polygon = pts
	_ring.color = Color(0.95, 0.72, 0.34, 0.9)
	_ring.material = m
	_spin.add_child(_ring)
	for k in range(3):
		var tick := Polygon2D.new()
		tick.polygon = PackedVector2Array([
			Vector2(-1.8, -19.0), Vector2(1.8, -19.0), Vector2(1.2, -13.0), Vector2(-1.2, -13.0)])
		tick.color = Color(1.0, 0.86, 0.5, 0.95)
		tick.material = m
		tick.rotation = deg_to_rad(120.0 * float(k))
		_spin.add_child(tick)

func _process(delta: float) -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(host) \
			or ("is_dead" in host and host.is_dead):
		queue_free()
		return
	_t += delta
	if _spin != null and is_instance_valid(_spin):
		_spin.rotation += 1.6 * delta
		# it tightens as it runs out, so the clock is readable at a glance
		var left: float = clampf(1.0 - _t / maxf(0.01, life), 0.0, 1.0)
		_spin.scale = Vector2.ONE * (0.75 + 0.35 * left)
		modulate.a = 0.35 + 0.65 * left
	if _t >= life:
		queue_free()
