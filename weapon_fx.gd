class_name WeaponFx
extends RefCounted

# ========================== THE WEAPON FX ENGINE ==========================
# (dev order 2026-07-28: "all weapons skills and effects and aftereffects
# should be unique and cool, as higher grade you can go crazier -- not by
# stats only".) The ladder's 275 weapons shared 18 behaviors with fatter
# numbers; THIS is where each one becomes itself. A weapon's row carries
# {"fx": {"kind": ..., params...}} (or {"fx": [ {...}, {...} ]} for combos)
# and the engine resolves it at the pipeline's three moments:
#
#   on_hit(p, target, dealt, crit)  -- every landed blow, melee/arrow/bolt
#   on_kill(p, target_pos)          -- the moment a foe falls
#   on_swing(p)                     -- every attack, for rhythm counters
#
# RULES OF THE HOUSE: all damage is % OF THE HIT and goes through
# take_damage (the boss gates and the Monarch's wand-window clamp stay
# sovereign); execute-class fx exempt bosses outright; nothing here reads
# a key the engine doesn't handle -- tool_fx_audit cross-checks every
# declared kind against HANDLED, because a named-but-never-read effect is
# this codebase's oldest trap.

# every kind the engine resolves; the audit fails on any fx outside it
const HANDLED = ["chain", "echo", "rend", "quake", "splinter", "brand",
	"harvest", "goldtouch", "stormcall", "gravity", "bulwark", "haste",
	"moonlit", "bloodprice", "duelist", "crowd", "frostbloom", "soulwisp",
	"shove", "sparkfly", "windup", "mendstrike", "farsight", "closequarters",
	"starfall", "skyrain", "legacy"]

# --- per-run scratch (cleared on wield; keyed by player instance) ---------
static var _counters := {}       # rhythm counters: weapon_id -> swing count
static var _duelist := {}        # duelist ramp: last target id + stacks
static var _haste := {}          # haste stacks: {"n": int, "until": float}

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# SIZE IS THE CROWN'S PRIVILEGE (dev 2026-07-28: "reduce stats, increase
# unique effects, size"): a weapon's grade scales its fx PHYSICALLY --
# bigger heads, wider trails, fatter bursts, and genuinely larger reach.
# Stats stay modest, Terra-style; the spectacle grows instead.
static func _grade_rank(p: Node) -> int:
	var g := Inventory.get_grade(str(p.active_weapon_id))
	return int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 0))

static func _gscale(p: Node) -> float:      # visual size: up to ~1.8x at the crown
	return 1.0 + 0.11 * float(_grade_rank(p))

static func _rscale(p: Node) -> float:      # effect REACH: up to ~1.4x at the crown
	return 1.0 + 0.055 * float(_grade_rank(p))

static func _fx_list(def: Dictionary) -> Array:
	var fx = def.get("special", {}).get("fx", null)
	if fx == null:
		return []
	return fx if fx is Array else [fx]

static func on_wield(_p: Node) -> void:
	_counters.clear()
	_duelist.clear()

# =============================== ON SWING ================================
static func on_swing(p: Node) -> void:
	var wid := str(p.active_weapon_id)
	_counters[wid] = int(_counters.get(wid, 0)) + 1

# ================================ ON HIT =================================
static func on_hit(p: Node, target: Node2D, dealt: int, crit: bool) -> void:
	if dealt <= 0 or not is_instance_valid(target):
		return
	# the brand pays FIRST -- before this hit's own fx can (re)brand -- so a
	# mark amps the NEXT blows, never itself, and pays once per hit, never
	# once per fx entry of a combo weapon
	if float(target.get_meta("fx_brand_until", 0.0)) > _now():
		_deal(target, int(round(dealt * float(target.get_meta("fx_brand_amp", 0.0)))))
	for fx in _fx_list(p.active_def):
		_run_hit_fx(p, target, dealt, crit, fx)

static func _run_hit_fx(p: Node, target: Node2D, dealt: int, crit: bool, fx: Dictionary) -> void:
	match str(fx.get("kind", "")):
		"chain":
			# lightning leaps to the n nearest others, pct of the hit each
			var n: int = int(fx.get("n", 2))
			var pct: float = float(fx.get("pct", 0.5))
			var hops := _others_near(p, target, float(fx.get("range", 240.0)) * _rscale(p), n)
			for h in hops:
				_deal(h, int(round(dealt * pct)))
				_zap_line(p, target.global_position, h.global_position, Color(0.65, 0.85, 1.0, 0.9))
		"echo":
			# the blow repeats itself as a ghost strike a beat later
			var pct_e: float = float(fx.get("pct", 0.6))
			var tid: int = target.get_instance_id()
			p.get_tree().create_timer(float(fx.get("delay", 0.45)), false).timeout.connect(
				func():
					var t = instance_from_id(tid)
					if t != null and is_instance_valid(t) and t.has_method("take_damage"):
						t.take_damage(maxi(1, int(round(dealt * pct_e))))
						if t.has_method("get_global_position"):
							_puff(p, t.global_position, Color(0.8, 0.75, 0.95, 0.7)))
		"rend":
			# wounds stack: each hit deepens the next (stored ON the target)
			var stacks: int = int(target.get_meta("fx_rend", 0))
			var maxs: int = int(fx.get("max", 5))
			if stacks > 0:
				_deal(target, int(round(dealt * float(fx.get("pct_per", 0.08)) * stacks)))
			target.set_meta("fx_rend", mini(stacks + 1, maxs))
		"quake":
			# the ground answers: a shockwave hits everything near the target
			var qr: float = float(fx.get("radius", 130.0)) * _rscale(p)
			for o in _others_near(p, target, qr, 8):
				_deal(o, int(round(dealt * float(fx.get("pct", 0.4)))))
				if o.has_method("apply_knockback"):
					o.apply_knockback(signf(o.global_position.x - target.global_position.x), 120.0)
			if p.has_method("spawn_shock_ring"):
				p.spawn_shock_ring(target.global_position, qr, Color(0.75, 0.6, 0.4, 0.8))
		"splinter":
			# the hit bursts into shards that nick everything close
			for o in _others_near(p, target, float(fx.get("range", 150.0)) * _rscale(p), int(fx.get("n", 3))):
				_deal(o, maxi(1, int(round(dealt * float(fx.get("pct", 0.3))))))
			_puff(p, target.global_position, Color(0.9, 0.85, 0.6, 0.8))
		"brand":
			# marked: the branded foe takes amplified damage from your NEXT hits
			target.set_meta("fx_brand_until", _now() + float(fx.get("dur", 4.0)))
			target.set_meta("fx_brand_amp", float(fx.get("amp", 0.25)))
		"goldtouch":
			if randf() < float(fx.get("chance", 0.15)):
				p.currency += int(fx.get("gold", 2))
				if p.has_method("update_currency_display"):
					p.update_currency_display()
		"stormcall":
			# every Nth swing, the sky answers the hit with a bolt -- lightning
			# stays INSTANT (that is its whole character), but the strike now
			# leaves a spark fountain where it lands (frame-study family)
			var wid := str(p.active_weapon_id)
			if int(_counters.get(wid, 0)) % maxi(2, int(fx.get("every", 4))) == 0:
				_deal(target, int(round(dealt * float(fx.get("pct", 0.9)))))
				_zap_line(p, target.global_position + Vector2(0, -220), target.global_position, Color(1.0, 0.95, 0.5, 0.95))
				_star_burst(p, target.global_position, Color(1.0, 0.95, 0.55))
		"gravity":
			# the blow PULLS the nearby dark toward the point of impact
			for o in _others_near(p, target, float(fx.get("radius", 200.0)) * _rscale(p), 8):
				if o.has_method("apply_knockback"):
					o.apply_knockback(signf(target.global_position.x - o.global_position.x), float(fx.get("pull", 140.0)))
		"bulwark":
			# striking true steels you: brief damage reduction
			if p.has_method("add_buff"):
				p.add_buff("damage_reduction", float(fx.get("dr", 0.1)), float(fx.get("dur", 2.5)))
		"moonlit":
			# fiercer under the night sky (the world's clock, not a timer)
			if GameState.time_of_day() >= 20.0 or GameState.time_of_day() < 5.0:
				_deal(target, int(round(dealt * float(fx.get("pct", 0.35)))))
		"bloodprice":
			# power paid for in blood: bonus damage, a nick of your own HP
			_deal(target, int(round(dealt * float(fx.get("pct", 0.5)))))
			p.health = maxi(1, int(p.health) - int(fx.get("cost", 1)))
			p.update_health_display()
		"duelist":
			# loyalty to one foe: repeated hits on the SAME target ramp up
			var tid2: int = target.get_instance_id()
			var d: Dictionary = _duelist.get("d", {"id": 0, "n": 0})
			d["n"] = d["n"] + 1 if int(d["id"]) == tid2 else 0
			d["id"] = tid2
			_duelist["d"] = d
			var ds: int = mini(int(d["n"]), int(fx.get("max", 6)))
			if ds > 0:
				_deal(target, int(round(dealt * float(fx.get("pct_per", 0.06)) * ds)))
		"crowd":
			# louder in a crowd: bonus per other enemy standing near you
			var around := _others_near(p, p, float(fx.get("radius", 260.0)), 8).size()
			if around > 0:
				_deal(target, int(round(dealt * minf(float(fx.get("pct_per", 0.08)) * around, float(fx.get("cap", 0.5))))))
		"shove":
			# the blow lands like a battering ram -- everything about the
			# strike says GET BACK
			if target.has_method("apply_knockback"):
				target.apply_knockback(signf(target.global_position.x - p.global_position.x),
					float(fx.get("force", 220.0)))
		"sparkfly":
			# a spark leaps OFF the wound and finds another foe a beat later
			# (the slow cousin of chain: it travels, it doesn't arc)
			var sn: int = int(fx.get("n", 1))
			var spct: float = float(fx.get("pct", 0.4))
			var flyers := _others_near(p, target, float(fx.get("range", 260.0)), sn)
			for fl in flyers:
				var fid: int = fl.get_instance_id()
				var from: Vector2 = target.global_position
				p.get_tree().create_timer(float(fx.get("delay", 0.35)), false).timeout.connect(
					func():
						var t2 = instance_from_id(fid)
						if t2 != null and is_instance_valid(t2) and t2.has_method("take_damage"):
							t2.take_damage(maxi(1, int(round(dealt * spct))))
							_zap_line(p, from, t2.global_position, Color(1.0, 0.8, 0.4, 0.8)))
		"windup":
			# the rhythm hit: every Nth swing this weapon's OWN blow lands heavier
			var wwid := str(p.active_weapon_id)
			if int(_counters.get(wwid, 0)) % maxi(2, int(fx.get("every", 3))) == 0:
				_deal(target, int(round(dealt * float(fx.get("pct", 0.8)))))
				_puff(p, target.global_position, Color(1.0, 0.9, 0.7, 0.85))
		"mendstrike":
			# the weapon mends its wielder a little with each true blow
			if randf() < float(fx.get("chance", 0.35)):
				p.health = mini(p.get_max_health(), int(p.health) + int(fx.get("hp", 2)))
				p.update_health_display()
		"farsight":
			# fiercer at a distance: the far shot is the true one
			if p.global_position.distance_to(target.global_position) >= float(fx.get("min_dist", 260.0)):
				_deal(target, int(round(dealt * float(fx.get("pct", 0.4)))))
		"closequarters":
			# fiercer nose to nose: no room to swing means no room to miss
			if p.global_position.distance_to(target.global_position) <= float(fx.get("max_dist", 90.0)):
				_deal(target, int(round(dealt * float(fx.get("pct", 0.4)))))
		"starfall":
			# (Star Wrath, 302 frames studied): a staggered CASCADE of comets
			# falls diagonally onto the mark -- star-glyph heads, tapering
			# additive trails, impact sparkle fountains. Borrowed-gold, ours.
			var sw_n: int = int(fx.get("stars", 2))
			var sw_pct: float = float(fx.get("pct", 0.5))
			var sw_tid: int = target.get_instance_id()
			for si in range(sw_n):
				var side: float = 1.0 if randf() < 0.5 else -1.0
				var from_sw: Vector2 = target.global_position + Vector2(
					side * randf_range(70.0, 170.0), -300.0 - 60.0 * float(si))
				_comet_star(p, from_sw, sw_tid,
					maxi(1, int(round(dealt * sw_pct))), 0.26 + 0.13 * float(si),
					Color(1.0, 0.72, 0.22))
		"skyrain":
			# (the Stormbow's cousin) the volley falls FROM THE SKY: n bolts
			# rain down in a spread around the struck point
			var r_n: int = int(fx.get("n", 3))
			var r_pct: float = float(fx.get("pct", 0.35))
			var r_spread: float = float(fx.get("spread", 130.0))
			var near := _others_near(p, target, r_spread, r_n - 1)
			near.push_front(target)
			# comet treatment (Star Wrath frame-study family): silver-blue
			# strings falling steeply, near-vertical -- rain, not stars
			for k in range(mini(r_n, near.size())):
				var r_tid: int = near[k].get_instance_id()
				var from: Vector2 = near[k].global_position + Vector2(randf_range(-34.0, 34.0), -280.0 - 40.0 * float(k))
				_comet_star(p, from, r_tid,
					maxi(1, int(round(dealt * r_pct))), 0.2 + 0.12 * float(k),
					Color(0.72, 0.82, 1.0))
		"legacy":
			# (the Zenith's cousin -- The Last Word) every blow hurls ghost
			# echoes of the ladder's blades, tinted and streaking to the near
			var l_pct: float = float(fx.get("pct", 0.5))
			var ghosts := _others_near(p, target, float(fx.get("range", 300.0)), int(fx.get("n", 2)))
			ghosts.push_front(target)
			for g in range(mini(ghosts.size(), int(fx.get("n", 2)) + 1)):
				_ghost_blade(p, p.global_position, ghosts[g], maxi(1, int(round(dealt * l_pct))), g)
		"frostbloom":
			# crits bloom into a slowing frost-flower
			if crit:
				for o in _others_near(p, target, float(fx.get("radius", 140.0)) * _rscale(p), 8):
					if o.has_method("apply_status"):
						o.apply_status("slow", float(fx.get("dur", 2.5)), 0.55)
				if p.has_method("spawn_shock_ring"):
					p.spawn_shock_ring(target.global_position, float(fx.get("radius", 140.0)), Color(0.6, 0.85, 1.0, 0.8))

# ================================ ON KILL ================================
static func on_kill(p: Node, at: Vector2) -> void:
	for fx in _fx_list(p.active_def):
		match str(fx.get("kind", "")):
			"harvest":
				p.health = mini(p.get_max_health(), int(p.health) + int(fx.get("hp", 3)))
				p.update_health_display()
				if fx.has("mana") and p.has_method("gain_mana"):
					p.gain_mana(float(fx.get("mana", 0.0)))
			"haste":
				var h: Dictionary = _haste.get("h", {"n": 0, "until": 0.0})
				h["n"] = mini(int(h["n"]) + 1, int(fx.get("max", 5)))
				h["until"] = _now() + float(fx.get("dur", 4.0))
				_haste["h"] = h
				if p.has_method("add_buff"):
					p.add_buff("all_damage", float(fx.get("pct_per", 0.04)) * int(h["n"]), float(fx.get("dur", 4.0)))
			"soulwisp":
				_spawn_wisp(p, at, fx)

# --------------------------- shared machinery ----------------------------
static func _deal(t: Node, amount: int) -> void:
	if amount > 0 and is_instance_valid(t) and t.has_method("take_damage"):
		t.take_damage(amount)

static func _others_near(p: Node, center: Node2D, radius: float, cap: int) -> Array:
	var out := []
	for g in ["enemies", "siege_enemy"]:
		for e in p.get_tree().get_nodes_in_group(g):
			if e == center or not is_instance_valid(e):
				continue
			if ("is_dead" in e) and e.is_dead:
				continue
			if e.global_position.distance_to(center.global_position) <= radius:
				out.append(e)
				if out.size() >= cap:
					return out
	return out

# fx visuals need a stage; under a bare test harness there may be none
static func _stage(p: Node) -> Node:
	var s = p.get_tree().current_scene
	return s if s != null else p.get_parent()

static func _zap_line(p: Node, a: Vector2, b: Vector2, col: Color) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, a.lerp(b, 0.4) + Vector2(randf_range(-14, 14), randf_range(-14, 14)), b])
	l.width = 2.5
	l.default_color = col
	l.z_index = 40
	_stage(p).add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

static func _puff(p: Node, at: Vector2, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.size = Vector2(10, 10)
	d.position = at - Vector2(5, 5)
	d.z_index = 40
	_stage(p).add_child(d)
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "scale", Vector2(2.2, 2.2), 0.3)
	tw.tween_property(d, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(d.queue_free)

# a ghost of the ladder's blades (legacy): a tinted sword-shade streaks from
# the wielder to its mark and strikes on arrival. The tints cycle the grade
# ladder itself -- every echo is a memory of some rung below.
const LEGACY_TINTS = [Color(0.75, 0.78, 0.8), Color(0.45, 0.85, 0.5),
	Color(0.4, 0.65, 1.0), Color(0.75, 0.5, 1.0), Color(1.0, 0.7, 0.3),
	Color(1.0, 0.4, 0.4)]
static var _legacy_cycle := 0
static func _ghost_blade(p: Node, from: Vector2, victim: Node2D, dmg: int, idx: int) -> void:
	if not is_instance_valid(victim):
		return
	_legacy_cycle += 1
	var tint: Color = LEGACY_TINTS[(_legacy_cycle + idx) % LEGACY_TINTS.size()]
	var vid: int = victim.get_instance_id()
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(-4, 12), Vector2(0, -18), Vector2(4, 12), Vector2(0, 7)])
	blade.scale = Vector2.ONE * _gscale(p)
	blade.color = Color(tint.r, tint.g, tint.b, 0.9)
	blade.z_index = 42
	_stage(p).add_child(blade)
	blade.global_position = from + Vector2(randf_range(-18.0, 18.0), randf_range(-30.0, -6.0))
	blade.rotation = (victim.global_position - blade.global_position).angle() + PI / 2.0
	var tw := blade.create_tween()
	tw.tween_property(blade, "global_position", victim.global_position, 0.22 + 0.06 * float(idx)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(blade, "modulate:a", 0.35, 0.22 + 0.06 * float(idx))
	tw.tween_callback(func():
		var v = instance_from_id(vid)
		if v != null and is_instance_valid(v) and v.has_method("take_damage"):
			v.take_damage(dmg)
		blade.queue_free())

# a comet-star: a glyph head streaking down a tapering additive trail; on
# arrival it pays its damage and erupts in a sparkle fountain
static func _comet_star(p: Node, from: Vector2, tid: int, dmg: int, dur: float, tint: Color) -> void:
	var t0 = instance_from_id(tid)
	if t0 == null or not is_instance_valid(t0):
		return
	var to: Vector2 = t0.global_position
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the trail: drawn whole, fading as the head travels it
	var trail := Line2D.new()
	trail.points = PackedVector2Array([from, from.lerp(to, 0.5), to])
	trail.width = 5.0 * _gscale(p)
	trail.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	trail.material = add_mat
	trail.z_index = 41
	_stage(p).add_child(trail)
	var tw_t := trail.create_tween()
	tw_t.tween_property(trail, "modulate:a", 0.0, dur + 0.25)
	tw_t.tween_callback(trail.queue_free)
	# the head: a five-point star glyph
	var head := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var r: float = 9.0 if i % 2 == 0 else 3.8
		var a: float = TAU * float(i) / 10.0 - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	head.polygon = pts
	head.scale = Vector2.ONE * _gscale(p)
	head.color = Color(tint.r, tint.g, tint.b, 0.95)
	head.material = add_mat
	head.z_index = 42
	_stage(p).add_child(head)
	head.global_position = from
	var tw := head.create_tween()
	tw.tween_property(head, "global_position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(head, "rotation", 2.6, dur)
	tw.tween_callback(func():
		var t = instance_from_id(tid)
		if t != null and is_instance_valid(t) and t.has_method("take_damage"):
			t.take_damage(dmg)
		_star_burst(p, head.global_position, tint)
		head.queue_free())

# the impact fountain: sparkles erupt upward and drift out
static func _star_burst(p: Node, at: Vector2, tint: Color) -> void:
	for i in range(9):
		var s := ColorRect.new()
		s.color = Color(minf(tint.r * 1.15, 1.0), minf(tint.g * 1.15, 1.0), tint.b, 0.95)
		s.size = Vector2(4, 4) * _gscale(p)
		s.position = at - Vector2(2.0, 2.0)
		s.z_index = 42
		_stage(p).add_child(s)
		var v := Vector2(randf_range(-46.0, 46.0), randf_range(-88.0, -30.0))
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "position", s.position + v, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(s.queue_free)

# a wisp of the fallen: drifts to the next foe and pops (soulwisp)
static func _spawn_wisp(p: Node, at: Vector2, fx: Dictionary) -> void:
	var w := Node2D.new()
	w.z_index = 30
	var body := ColorRect.new()
	body.color = Color(0.75, 0.9, 1.0, 0.9)
	body.size = Vector2(7, 7)
	body.position = Vector2(-3.5, -3.5)
	w.add_child(body)
	w.global_position = at + Vector2(0, -16)
	_stage(p).add_child(w)
	var targets := _others_near(p, p, 420.0, 1)
	var pct: float = float(fx.get("pct", 0.5))
	var base: int = maxi(2, int(round(float(fx.get("dmg", 8)))))
	if targets.is_empty():
		var tw := w.create_tween()
		tw.tween_property(w, "position", w.position + Vector2(0, -60), 0.8)
		tw.parallel().tween_property(w, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(w.queue_free)
		return
	var tid: int = targets[0].get_instance_id()
	var tw2 := w.create_tween()
	tw2.tween_property(w, "global_position", targets[0].global_position, 0.5)
	tw2.tween_callback(func():
		var t = instance_from_id(tid)
		if t != null and is_instance_valid(t) and t.has_method("take_damage"):
			t.take_damage(maxi(1, int(round(base * pct + base))))
		w.queue_free())
