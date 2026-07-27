extends Node2D

# A lingering ground hazard dropped by a boss signature ability and then left to
# tick on its own (magma trails, web patches, fire rings, splinter residue...).
# The boss spawns it and forgets it: it damages / crowd-controls the player while
# they stand in it, fades, and self-frees. One primitive, reused by every
# zone-denial signature so none of them has to re-implement "hurt things here."

var radius := 60.0
var lifetime := 3.0
var tick := 0.4                       # seconds between damage/CC applications
var damage := 8
var color := Color(1.0, 0.5, 0.1, 0.5)
var damage_multiplier := 1.0          # inherited from the boss's scaling
var on_kind := ""                     # "" | "poison" | "root" | "slow" | "freeze"
var on_dur := 1.0
var on_mag := 0.0                     # slow factor, or poison dps
# A LOCK APPLIES ONCE, then degrades to a sticky slow. A root/freeze re-applied
# on every 0.4s tick never lapses while you stand in it -- and since root is
# exactly what stops you leaving, "get off it fast" became impossible: the
# Weaver's web was 4 seconds of guaranteed zero input. The snare still lands,
# the escape still exists.
var on_once := false
var _cc_spent := false
const ONCE_FOLLOWUP_SLOW := 0.4       # speed factor once the lock has been spent

var _age := 0.0
var _acc := 0.0
var _vis: Polygon2D = null

func _ready() -> void:
	z_index = 4
	_vis = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * radius)
	_vis.polygon = pts
	_vis.color = color
	add_child(_vis)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	# fade out over the last third of its life
	var fade_start := lifetime * 0.66
	if _vis != null and _age > fade_start:
		_vis.modulate.a = clampf(1.0 - (_age - fade_start) / (lifetime - fade_start), 0.0, 1.0)
	_acc += delta
	if _acc < tick:
		return
	_acc -= tick
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	if p.global_position.distance_to(global_position) > radius:
		return
	if p.has_method("take_damage"):
		# sqrt discipline: every other boss hit scales by sqrt(damage_multiplier)
		# (see boss.deal_player_damage) -- the raw multiplier made a floor-100
		# void tear tick 74 instead of 32 against a 160-HP player
		p.take_damage(int(round(damage * sqrt(maxf(damage_multiplier, 0.0)))))
	# a spent one-shot lock keeps the patch sticky instead of re-locking
	if on_once and _cc_spent and (on_kind == "root" or on_kind == "freeze"):
		if p.has_method("apply_slow"):
			p.apply_slow(tick * 1.6, ONCE_FOLLOWUP_SLOW)
		return
	match on_kind:
		"poison":
			if p.has_method("apply_poison"): p.apply_poison(on_dur, on_mag)
		"root":
			if p.has_method("apply_root"):
				p.apply_root(on_dur)
				_cc_spent = true
		"slow":
			if p.has_method("apply_slow"): p.apply_slow(on_dur, on_mag)
		"freeze":
			if p.has_method("apply_freeze"):
				p.apply_freeze(on_dur)
				_cc_spent = true
