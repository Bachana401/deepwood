extends Node2D
# TOME AREA DENIAL (weapons overhaul 2026-07-28, Terraria-spellbook-INSPIRED,
# not copied): a conjured stormlet hangs over the aimed ground and rains
# strikes inside its ring for a few seconds. The caster walks away; the storm
# keeps working the area. Spawned by player.cast_storm_tome.

var damage := 8
var radius := 130.0
var duration := 4.5
var strike_gap := 0.4        # seconds between bolts
var tint := Color(0.55, 0.75, 1.0)
var source: Node2D = null    # the caster (for on-kill credits later)
# flagship variants (2026-07-28):
var sun_mode := false        # A Small Personal Sun: a grounded sunlet, warm palette
var drift := false           # What the Sky Charges: the storm WALKS toward prey
# TOME VERBS (attack-verb overhaul 2026-07-28: "Mire Pages and Coven's Ledger
# have exactly the same skill" -- dev. No two tomes cast the same shape now):
var mire_mode := false       # The Mire Pages: a creeping BOG that slows+poisons
var coven_mode := false      # The Coven's Ledger: a sigil ring pulsing INWARD
# tome batch 2 (no two tomes cast the same shape):
var column_mode := false     # The Deluge: three column eruptions MARCHING forward
var lure_mode := false       # The Siren's Appendix: gathers, then the verse ends
var tide_mode := false       # The Tidal Codex: a WALL of water travelling the lane
var facing := 1              # cast-time facing: columns march and tides travel this way
var _pulse_i := 0            # column/lure bookkeeping

var _t := 0.0
var _next := 0.0
var _cloud: Polygon2D = null

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

func _ready() -> void:
	z_index = 42
	if sun_mode:
		tint = Color(1.0, 0.62, 0.2)
	# the cloud: three soft lobes hanging where the storm works
	_cloud = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var r := 34.0 + sin(a * 3.0) * 12.0
		pts.append(Vector2(cos(a) * r * 1.6, sin(a) * r * 0.55))
	_cloud.polygon = pts
	# brighter lobes (EYES 2026-07-28): 0.5x tint at 0.75 alpha vanished into
	# the night sky -- a storm the caster paid mana for must be SEEN working
	_cloud.color = Color(tint.r * 0.75, tint.g * 0.75, tint.b * 0.85, 0.9)
	_cloud.position = Vector2(0, -110)
	if sun_mode:
		# not a cloud at all: a small sun sitting low over the scorched spot
		_cloud.color = Color(1.0, 0.75, 0.3, 0.85)
		_cloud.position = Vector2(0, -46)
		_cloud.scale = Vector2(0.55, 0.9)
	if mire_mode:
		# THE MIRE PAGES: no cloud -- a low BOG slick lying ON the ground,
		# bright bile-green, breathing; it slows and sickens what stands in it
		tint = Color(0.5, 0.72, 0.32)
		_cloud.color = Color(0.5, 0.78, 0.3, 1.0)
		_cloud.position = Vector2(0, 2)
		_cloud.scale = Vector2(2.2, 0.42)
	if coven_mode:
		# THE COVEN'S LEDGER: no cloud at all -- the sigil RING is the cast,
		# violet, closing its circle three times
		tint = Color(0.8, 0.5, 1.0)
		_cloud.visible = false
	if column_mode:
		# THE DELUGE: no cloud -- the sky itself answers in marching columns
		tint = Color(0.5, 0.7, 1.0)
		_cloud.visible = false
	if lure_mode:
		# THE SIREN'S APPENDIX: a teal song-ring; motes orbit while it gathers
		tint = Color(0.35, 0.85, 0.8)
		_cloud.visible = false
	if tide_mode:
		# THE TIDAL CODEX: a travelling WALL of water, foam at its crest
		tint = Color(0.4, 0.7, 0.95)
		_cloud.color = Color(0.35, 0.6, 0.9, 0.9)
		_cloud.position = Vector2(0, -55)
		_cloud.scale = Vector2(0.35, 1.9)
	add_child(_cloud)
	# the working ring on the ground, faint -- the promise of where it strikes
	var ring := Line2D.new()
	var rp := PackedVector2Array()
	for i in range(25):
		var a2 := TAU * float(i) / 24.0
		rp.append(Vector2(cos(a2), sin(a2) * 0.35) * radius)
	ring.points = rp
	ring.width = 3.0
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.55)
	# the zone verbs live or die by their ring (EYES: 0.55 vanished at night)
	if mire_mode or coven_mode or lure_mode or tide_mode:
		ring.width = 4.5
		ring.default_color = Color(tint.r, tint.g, tint.b, 0.95)
		var ring_mat := CanvasItemMaterial.new()
		ring_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = ring_mat
		# the bog BODY stays solid paint (additive washed it out -- EYES);
		# only its ring glows
	add_child(ring)

func _physics_process(delta: float) -> void:
	_t += delta
	if _cloud != null and not sun_mode and not mire_mode and not coven_mode:
		_cloud.position.y = -110.0 + sin(_t * 2.2) * 5.0
	elif _cloud != null and mire_mode:
		# the bog BREATHES in place instead of bobbing in the sky
		_cloud.scale.y = 0.3 + sin(_t * 3.0) * 0.05
	# What the Sky Charges: the storm walks its ring toward the nearest prey
	if drift:
		var prey := _nearest_hostile(700.0)
		if prey != null:
			var dx: float = prey.global_position.x - global_position.x
			if absf(dx) > 20.0:
				global_position.x += signf(dx) * minf(60.0 * delta, absf(dx))
	if _t >= duration:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _t < _next:
		return
	if mire_mode:
		# the bog doesn't strike -- it SOAKS: everything standing in the
		# slick takes its toll and comes away slowed and sickened. And it
		# BREATHES visibly: ambient bubbles rise whether anyone stands in
		# it or not (the particle-density bar: OP zones shed light)
		_next = _t + strike_gap
		for bi in range(3):
			_bubble(global_position + Vector2(randf_range(-radius * 0.8, radius * 0.8), 0))
		var world_c := global_position
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if absf(e.global_position.x - world_c.x) <= radius \
						and absf(e.global_position.y - world_c.y) <= 70.0:
					e.take_damage(damage)
					FloatingText.spawn(get_parent(), e.global_position, damage, false)
					if e.has_method("apply_status"):
						e.apply_status("slow", 1.2, 0.5)
						e.apply_status("poison", 2.0, 2.0)
					_bubble(e.global_position)
		return
	if coven_mode:
		# the ledger closes its circle three times; the circle COLLECTS --
		# and every pulse sheds violet sparks around the rim
		_next = _t + maxf(0.6, duration / 3.0)
		var pulse := create_tween()
		pulse.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
		pulse.tween_property(self, "scale", Vector2.ONE, 0.14)
		for si in range(8):
			var a := TAU * float(si) / 8.0
			var spark := Polygon2D.new()
			spark.polygon = PackedVector2Array([Vector2(-2.5, 0), Vector2(0, -5), Vector2(2.5, 0), Vector2(0, 5)])
			spark.color = Color(0.85, 0.6, 1.0, 0.95)
			get_parent().add_child(spark)
			spark.global_position = global_position + Vector2(cos(a), sin(a) * 0.35) * radius
			var stw := spark.create_tween()
			stw.set_parallel(true)
			stw.tween_property(spark, "global_position", spark.global_position + Vector2(cos(a), sin(a) * 0.35) * -radius * 0.5, 0.4)
			stw.tween_property(spark, "modulate:a", 0.0, 0.4)
			stw.chain().tween_callback(spark.queue_free)
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if global_position.distance_to(e.global_position) <= radius:
					e.take_damage(int(round(damage * 1.5)))
					FloatingText.spawn(get_parent(), e.global_position, int(round(damage * 1.5)), false)
					if e.has_method("apply_knockback"):
						e.apply_knockback(signf(global_position.x - e.global_position.x), 140.0)
		return
	if column_mode:
		# THE DELUGE: three column eruptions MARCHING the cast's facing
		_next = _t + maxf(0.5, duration / 3.0)
		_pulse_i += 1
		var cx: float = (float(_pulse_i) - 2.0) * radius * 0.5 * float(facing)
		var col := ColorRect.new()
		var cmat := CanvasItemMaterial.new()
		cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		col.material = cmat
		col.color = Color(0.55, 0.75, 1.0, 0.9)
		col.size = Vector2(radius * 0.4, 220.0)
		col.position = Vector2(cx - radius * 0.2, -220.0)
		add_child(col)
		var ctw := col.create_tween()
		ctw.tween_property(col, "modulate:a", 0.0, 0.45)
		ctw.tween_callback(col.queue_free)
		# droplets shed off the column (the particle bar)
		for di in range(5):
			_bubble(to_global(Vector2(cx + randf_range(-radius * 0.2, radius * 0.2), -randf_range(10.0, 180.0))))
		var wc := to_global(Vector2(cx, 0))
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if absf(e.global_position.x - wc.x) <= radius * 0.25:
					e.take_damage(int(round(damage * 1.3)))
					FloatingText.spawn(get_parent(), e.global_position, int(round(damage * 1.3)), false)
					if e.has_method("apply_knockback"):
						e.apply_knockback(signf(e.global_position.x - wc.x + 0.1), 200.0)
		return
	if lure_mode:
		# THE SIREN'S APPENDIX: gathers every tick; the verse ENDS in a burst
		_next = _t + strike_gap
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				var d := global_position.distance_to(e.global_position)
				if d <= radius * 1.4:
					if e.has_method("apply_knockback"):
						e.apply_knockback(signf(global_position.x - e.global_position.x), 120.0)
					if d <= radius:
						e.take_damage(maxi(1, int(round(damage * 0.4))))
		# the song's motes (particle bar): three orbiting sparks
		for mi in range(3):
			var ma := _t * 2.4 + TAU * float(mi) / 3.0
			_bubble(global_position + Vector2(cos(ma), sin(ma) * 0.35) * radius * 0.9)
		# the final beat: everything gathered pays at once
		if _t + strike_gap >= duration:
			for group_name in HOSTILE_GROUPS:
				for e in get_tree().get_nodes_in_group(group_name):
					if is_instance_valid(e) and e.has_method("take_damage") \
							and not ("is_dead" in e and e.is_dead) \
							and global_position.distance_to(e.global_position) <= radius * 0.6:
						e.take_damage(int(round(damage * 2.5)))
						FloatingText.spawn(get_parent(), e.global_position, int(round(damage * 2.5)), false)
		return
	if tide_mode:
		# THE TIDAL CODEX: the wall TRAVELS; what it touches is swept along
		_next = _t + strike_gap
		global_position.x += 160.0 * float(facing) * strike_gap
		for fi in range(2):
			_bubble(global_position + Vector2(randf_range(-14.0, 14.0), -randf_range(80.0, 110.0)))
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if absf(e.global_position.x - global_position.x) <= 40.0:
					e.take_damage(damage)
					FloatingText.spawn(get_parent(), e.global_position, damage, false)
					if e.has_method("apply_knockback"):
						e.apply_knockback(float(facing), 220.0)
		return
	_next = _t + strike_gap
	var x := randf_range(-radius, radius)
	_strike(Vector2(x, 0))

func _strike(local: Vector2) -> void:
	# the bolt: a jagged streak from the cloud down to the strike point
	var bolt := Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(minf(tint.r + 0.25, 1.0), minf(tint.g + 0.25, 1.0), minf(tint.b + 0.25, 1.0), 1.0)
	var top: Vector2 = Vector2(local.x * 0.3, -104)
	var pts := PackedVector2Array([top])
	for i in range(1, 4):
		var f := float(i) / 4.0
		pts.append(top.lerp(local, f) + Vector2(randf_range(-9, 9), 0))
	pts.append(local)
	bolt.points = pts
	add_child(bolt)
	# heard from where it lands: a crack for storms, a lower sizzle for suns
	SfxSynth.play_at(self, to_global(local), "crack", -13.0, 0.7 if sun_mode else 1.0)
	var t := bolt.create_tween()
	t.tween_property(bolt, "modulate:a", 0.0, 0.22)
	t.tween_callback(bolt.queue_free)
	# the strike lands on anything close to the point
	var world := to_global(local)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if world.distance_to(e.global_position) <= 52.0:
				e.take_damage(damage)
				FloatingText.spawn(get_parent(), e.global_position, damage, false)
				if sun_mode and e.has_method("apply_status"):
					e.apply_status("burn", 2.0, 4.0)   # the sunlet clings

# a bog bubble: rises a little way and pops (mire_mode's breathing)
func _bubble(at: Vector2) -> void:
	var b := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 3.5)
	b.polygon = pts
	b.color = Color(0.55, 0.75, 0.4, 0.8)
	get_parent().add_child(b)
	b.global_position = at + Vector2(randf_range(-14.0, 14.0), -4.0)
	var t := b.create_tween()
	t.set_parallel(true)
	t.tween_property(b, "global_position", b.global_position + Vector2(0, -22.0), 0.5)
	t.tween_property(b, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(b.queue_free)

func _nearest_hostile(within: float) -> Node2D:
	var best: Node2D = null
	var bd := within
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best
