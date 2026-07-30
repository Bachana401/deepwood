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
		_: _build_watchstone()
	# it rises out of the ground rather than popping into being
	visual.scale = Vector2(1.0, 0.1)
	var tw := visual.create_tween()
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
	if prey == null:
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

func _loose_at(prey: Node2D) -> void:
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
	var tw := iris.create_tween().set_loops()
	tw.tween_property(iris, "scale", Vector2(1.0, 0.15), 0.09)
	tw.tween_interval(2.4)
	tw.tween_property(iris, "scale", Vector2.ONE, 0.09)
	tw.tween_interval(1.1)
