extends CharacterBody2D

# ORIN, the stranded village mage. Lore: an adventurer like the player who
# reached Deepwood two years ago and has been trapped ever since -- the evil
# outside is too thick to cross alone. Until the player clears him a path he
# earns his keep defending the walls, raining small meteors on any beast that
# nears the village.
#
# Deliberately NOT a rescued_villagers roster entry and NOT in the "npc" group:
# he can't be assigned a job, mated, schooled, or counted for income. His only
# use is standing near the village and burning approaching enemies -- the
# groundwork for the future village-siege system. He's in the "village_defender"
# group so that system (and tests) can find him.

# --- Combat / survivability tuning ---
# 250 HP with slow regen (+5 every 3s) so he can hold a wall through a siege
# and recover between assaults without ever being unkillable -- sustained
# pressure still wears him down. His OFFENCE stays wave-5-ish: ~14 per meteor
# on a ~1.7s cadence, roughly one wave-5 unit's worth. No armor by design.
const MAX_HEALTH = 250
const REGEN_AMOUNT = 5
const REGEN_INTERVAL = 3.0        # +5 HP every 3 seconds, capped at MAX_HEALTH
const DEFENSE_RANGE = 400.0       # how far out he'll start hurling meteors
const CAST_COOLDOWN = 1.7         # seconds between casts
const METEOR_DAMAGE = 14
const METEOR_SPLASH_RADIUS = 48.0
const METEOR_FALL_HEIGHT = 340.0
const METEOR_FALL_TIME = 0.5

const GRAVITY = 900.0

# The evil he targets. He never touches villagers, children, or the player.
const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

var health = MAX_HEALTH
var cast_cooldown_remaining = 0.0
var regen_timer = 0.0
var facing := 1

# --- Downed / respawn ---
# On death Orin doesn't vanish: he collapses into a small fireball on his exact
# spot and reforms GameState.WIZARD_RESPAWN_HOURS in-game hours later (the timer
# lives in GameState so it counts down even while the player is off in a
# dungeon and the village scene is unloaded). While down he neither deals nor
# takes damage.
const FIREBALL_Y = -14.0        # fireball sits at torso height, where he stood
var is_down := false
var fireball: Node2D = null
var fireball_tween: Tween = null

# visuals
var gfx: Node2D = null
var staff: Node2D = null
var orb: Polygon2D = null
var orb_glow: Polygon2D = null

# health bar (same behaviour as villagers: hidden until hurt, pulses in danger)
const HEALTH_BAR_DANGER_THRESHOLD = 0.30
const HEALTH_BAR_HIT_REVEAL_SECONDS = 1.6
const HEALTH_BAR_WIDTH = 40.0
const HEALTH_BAR_HEIGHT = 5.0
const HEALTH_BAR_Y = -70.0
const HEALTH_COLOR_OK = Color(0.15, 0.75, 0.25, 1.0)
const HEALTH_COLOR_DANGER = Color(0.9, 0.15, 0.15, 1.0)
var hp_reveal_timer = 0.0
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

# info / interaction
const HOVER_BOUNDS = Rect2(-24.0, -66.0, 48.0, 70.0)
var hover_panel: Panel = null
var hover_label: Label = null
var player_inside = false

const INFO_FIELDS = [
	"Orin, Stranded Mage",
	"Adventurer, trapped 2 years",
	"Defends the walls with meteors",
	"Cannot be given a village job",
]
const SPEECH_LINE = "Two winters I've been stranded here. The evil outside is too thick to cross alone -- so I'll guard these walls till you clear me a path."

func _ready() -> void:
	add_to_group("village_defender")
	# layer 0 = the player's weapons/arrows can never hit him (he's friendly);
	# mask 1 so he still rests on the ground. Future siege enemies will hurt him
	# through the public take_damage() below.
	collision_layer = 0
	collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(24.0, 44.0)
	shape.shape = rect
	add_child(shape)

	build_visual()
	build_health_bar()
	build_hover_panel()
	build_proximity_area()
	start_idle_animation()
	build_fireball()
	# If he was already down when this village scene loaded (e.g. the player
	# left him as a fireball and came back before 12h passed), start downed --
	# no collapse animation, he's simply still an ember.
	if GameState.wizard_is_down():
		enter_downed_state(false)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()

	if is_down:
		return

	if cast_cooldown_remaining > 0.0:
		cast_cooldown_remaining -= delta
	else:
		try_cast()

func _process(delta: float) -> void:
	if is_down:
		# reform the moment the in-game clock passes his respawn time -- works
		# whether time advanced normally or via the debug time-skip keys.
		if not GameState.wizard_is_down():
			respawn()
		return

	tick_regen(delta)
	update_health_bar_display(delta)
	if player_inside and Input.is_action_just_pressed("interact"):
		SpeechText.spawn(self, SPEECH_LINE)
	update_hover_panel(get_global_mouse_position())

# Slow, steady self-heal. Only tops up the number + bar fill -- it never forces
# the bar visible (that stays reserved for the on-hit reveal / danger pulse).
func tick_regen(delta: float) -> void:
	if health >= MAX_HEALTH:
		return
	regen_timer += delta
	if regen_timer >= REGEN_INTERVAL:
		regen_timer -= REGEN_INTERVAL
		health = min(MAX_HEALTH, health + REGEN_AMOUNT)
		update_health_bar_fill()

# ------------------------------------------------------------------ combat ---

func try_cast() -> void:
	var target = find_target()
	if target == null:
		return
	cast_cooldown_remaining = CAST_COOLDOWN
	face_toward(target.global_position)
	animate_cast()
	cast_meteor_at(target.global_position)

# Nearest living hostile within DEFENSE_RANGE, or null.
func find_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist = DEFENSE_RANGE
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if not e.has_method("take_damage"):
				continue
			var d = global_position.distance_to(e.global_position)
			if d <= nearest_dist:
				nearest_dist = d
				nearest = e
	return nearest

# Spawns a meteor high above target_pos that falls and detonates on the spot.
# Returns the meteor node (used by tests). Non-homing on purpose -- an enemy
# that keeps moving can dodge it, which keeps him from being oppressive.
func cast_meteor_at(target_pos: Vector2) -> Node2D:
	var impact_pos = Vector2(target_pos.x, target_pos.y)
	var meteor = Node2D.new()
	meteor.z_index = 40
	meteor.add_to_group("wizard_meteor")
	meteor.global_position = Vector2(impact_pos.x + randf_range(-6.0, 6.0), impact_pos.y - METEOR_FALL_HEIGHT)
	get_parent().add_child(meteor)

	var glow = Polygon2D.new()
	glow.polygon = _circle_points(11.0, 12)
	glow.color = Color(1.0, 0.55, 0.15, 0.35)
	meteor.add_child(glow)
	var rock = Polygon2D.new()
	rock.polygon = _rock_points(6.5)
	rock.color = Color(0.85, 0.3, 0.08, 1.0)
	meteor.add_child(rock)
	var core = Polygon2D.new()
	core.polygon = _circle_points(3.0, 10)
	core.color = Color(1.0, 0.9, 0.5, 1.0)
	meteor.add_child(core)

	# a fiery trail streaming off the falling rock
	var trail = CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.35
	trail.direction = Vector2(0, -1)
	trail.spread = 18.0
	trail.gravity = Vector2(0, -40)
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 45.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 3.5
	trail.color = Color(1.0, 0.5, 0.12, 1.0)
	meteor.add_child(trail)
	trail.emitting = true

	var t = meteor.create_tween()
	t.tween_property(meteor, "global_position", impact_pos, METEOR_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(rock, "rotation", TAU, METEOR_FALL_TIME)
	t.tween_callback(func():
		apply_meteor_impact(impact_pos)
		spawn_impact_fx(impact_pos)
		if is_instance_valid(meteor):
			meteor.queue_free())
	return meteor

# AoE damage on landing -- every living hostile within the splash radius.
func apply_meteor_impact(impact_pos: Vector2) -> void:
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if impact_pos.distance_to(e.global_position) <= METEOR_SPLASH_RADIUS and e.has_method("take_damage"):
				e.take_damage(METEOR_DAMAGE)

func spawn_impact_fx(impact_pos: Vector2) -> void:
	var ring = Polygon2D.new()
	ring.polygon = _circle_points(METEOR_SPLASH_RADIUS * 0.5, 20)
	ring.color = Color(1.0, 0.6, 0.2, 0.55)
	ring.z_index = 39
	ring.global_position = impact_pos
	get_parent().add_child(ring)
	var rt = ring.create_tween()
	rt.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	rt.tween_callback(ring.queue_free)

	var burst = CPUParticles2D.new()
	burst.global_position = impact_pos
	burst.z_index = 41
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 18
	burst.lifetime = 0.5
	burst.direction = Vector2(0, -1)
	burst.spread = 90.0
	burst.gravity = Vector2(0, 240)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 140.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(1.0, 0.5, 0.12, 1.0)
	get_parent().add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

# --------------------------------------------------------------- take hits ---

# Public entry for the future siege enemies. Sheltered logic isn't needed --
# he stands his ground on the wall.
func take_damage(amount: int) -> void:
	if is_down:
		return   # a fireball can't be hurt
	health -= amount
	if health <= 0:
		die()
		return
	hp_reveal_timer = HEALTH_BAR_HIT_REVEAL_SECONDS
	update_health_bar_fill()

# He doesn't truly die: he collapses into an ember (see enter_downed_state) and
# schedules his own reform via GameState's shared clock.
func die() -> void:
	if is_down:
		return
	GameState.mark_wizard_down()
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification("Orin has fallen -- his magic collapses to an ember. He'll reform in %d hours." % int(GameState.WIZARD_RESPAWN_HOURS))
	enter_downed_state(true)

# ------------------------------------------------------------ downed / reform ---

func build_fireball() -> void:
	fireball = Node2D.new()
	fireball.name = "DownedFireball"
	fireball.position = Vector2(0, FIREBALL_Y)
	fireball.visible = false
	fireball.z_index = 5
	add_child(fireball)

	var glow = Polygon2D.new()
	glow.polygon = _circle_points(13.0, 16)
	glow.color = Color(1.0, 0.5, 0.12, 0.4)
	glow.material = _additive_material()
	fireball.add_child(glow)

	var core = Polygon2D.new()
	core.polygon = _circle_points(7.0, 14)
	core.color = Color(1.0, 0.6, 0.18, 1.0)
	fireball.add_child(core)

	var hot = Polygon2D.new()
	hot.polygon = _circle_points(3.4, 12)
	hot.color = Color(1.0, 0.92, 0.6, 1.0)
	fireball.add_child(hot)

	var flames = CPUParticles2D.new()
	flames.name = "Flames"
	flames.amount = 16
	flames.lifetime = 0.5
	flames.direction = Vector2(0, -1)
	flames.spread = 24.0
	flames.gravity = Vector2(0, -90)
	flames.initial_velocity_min = 18.0
	flames.initial_velocity_max = 40.0
	flames.scale_amount_min = 2.0
	flames.scale_amount_max = 3.6
	flames.color = Color(1.0, 0.5, 0.12, 1.0)
	flames.emitting = false
	fireball.add_child(flames)

# Hide the mage, show the ember. `animated` = the death collapse (burst + shrink);
# false = he was already down when the scene loaded, so just show the ember.
func enter_downed_state(animated: bool) -> void:
	is_down = true
	cast_cooldown_remaining = CAST_COOLDOWN
	if health_bar_bg:
		health_bar_bg.visible = false
	if health_bar_fill:
		health_bar_fill.visible = false

	if fireball:
		fireball.visible = true
		fireball.modulate.a = 1.0
		fireball.scale = Vector2.ONE
		_set_fireball_flames(true)
		if fireball_tween and fireball_tween.is_valid():
			fireball_tween.kill()
		fireball_tween = fireball.create_tween()
		fireball_tween.set_loops()
		fireball_tween.tween_property(fireball, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
		fireball_tween.tween_property(fireball, "scale", Vector2(0.85, 0.85), 0.5).set_trans(Tween.TRANS_SINE)

	if animated:
		spawn_puff(18, Color(1.0, 0.5, 0.12, 1.0))
		if gfx:
			var gt = gfx.create_tween()
			gt.tween_property(gfx, "scale", Vector2(0.001 * facing, 0.001), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			gt.tween_callback(_hide_gfx)
	elif gfx:
		gfx.visible = false

func _hide_gfx() -> void:
	if gfx:
		gfx.visible = false

# Reform: the ember flares and vanishes, the mage pops back in, full HP, and he
# resumes fighting from the same spot.
func respawn() -> void:
	is_down = false
	GameState.clear_wizard_down()
	health = MAX_HEALTH
	regen_timer = 0.0
	cast_cooldown_remaining = 0.5   # a beat to finish the pop-in before casting

	if fireball:
		if fireball_tween and fireball_tween.is_valid():
			fireball_tween.kill()
		var ft = fireball.create_tween()
		ft.tween_property(fireball, "scale", Vector2(1.9, 1.9), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.parallel().tween_property(fireball, "modulate:a", 0.0, 0.22)
		ft.tween_callback(func():
			if not fireball:
				return
			fireball.visible = false
			fireball.modulate.a = 1.0
			fireball.scale = Vector2.ONE
			_set_fireball_flames(false))

	spawn_puff(20, Color(1.0, 0.75, 0.3, 1.0))
	if gfx:
		gfx.visible = true
		gfx.scale = Vector2(0.001 * facing, 0.001)
		var gt = gfx.create_tween()
		gt.tween_property(gfx, "scale", Vector2(float(facing), 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification("Orin reforms and returns to the walls!")

func _set_fireball_flames(on: bool) -> void:
	if not fireball:
		return
	for c in fireball.get_children():
		if c is CPUParticles2D:
			c.emitting = on

func spawn_puff(amount: int, color: Color) -> void:
	var burst = CPUParticles2D.new()
	burst.position = Vector2(0, FIREBALL_Y)
	burst.z_index = 41
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = amount
	burst.lifetime = 0.5
	burst.direction = Vector2(0, -1)
	burst.spread = 80.0
	burst.gravity = Vector2(0, 140)
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 130.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = color
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func _additive_material() -> CanvasItemMaterial:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# ----------------------------------------------------------------- visuals ---

func build_visual() -> void:
	# all body art lives under Gfx so facing can mirror it without flipping the
	# health bar / collision on the root
	gfx = Node2D.new()
	gfx.name = "Gfx"
	add_child(gfx)

	# robe (indigo, flaring to the hem at the feet)
	var robe = Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-13, 22), Vector2(13, 22), Vector2(9, -14), Vector2(-9, -14),
	])
	robe.color = Color(0.26, 0.22, 0.5, 1.0)
	gfx.add_child(robe)
	# lighter hem trim
	var hem = Polygon2D.new()
	hem.polygon = PackedVector2Array([
		Vector2(-13, 22), Vector2(13, 22), Vector2(12, 16), Vector2(-12, 16),
	])
	hem.color = Color(0.5, 0.45, 0.8, 1.0)
	gfx.add_child(hem)

	# head + beard
	var head = Polygon2D.new()
	head.polygon = _circle_points(7.0, 12)
	head.position = Vector2(0, -20)
	head.color = Color(0.92, 0.77, 0.63, 1.0)
	gfx.add_child(head)
	var beard = Polygon2D.new()
	beard.polygon = PackedVector2Array([Vector2(-6, -18), Vector2(6, -18), Vector2(0, -4)])
	beard.color = Color(0.82, 0.82, 0.88, 1.0)
	gfx.add_child(beard)

	# pointy hat (brim + cone, slightly tilted)
	var brim = Polygon2D.new()
	brim.polygon = PackedVector2Array([Vector2(-13, -25), Vector2(13, -25), Vector2(10, -28), Vector2(-10, -28)])
	brim.color = Color(0.18, 0.16, 0.42, 1.0)
	gfx.add_child(brim)
	var cone = Polygon2D.new()
	cone.polygon = PackedVector2Array([Vector2(-10, -27), Vector2(10, -27), Vector2(4, -50)])
	cone.color = Color(0.2, 0.18, 0.46, 1.0)
	gfx.add_child(cone)
	# a little star on the hat
	var star = Polygon2D.new()
	star.polygon = _star_points(2.6, 1.2, 5)
	star.position = Vector2(1, -36)
	star.color = Color(1.0, 0.9, 0.5, 1.0)
	gfx.add_child(star)

	build_staff()

func build_staff() -> void:
	staff = Node2D.new()
	staff.name = "Staff"
	staff.position = Vector2(13, -2)
	gfx.add_child(staff)

	var shaft = Polygon2D.new()
	shaft.polygon = PackedVector2Array([Vector2(-1.6, 8), Vector2(1.6, 8), Vector2(1.6, -30), Vector2(-1.6, -30)])
	shaft.color = Color(0.45, 0.3, 0.16, 1.0)
	staff.add_child(shaft)

	orb_glow = Polygon2D.new()
	orb_glow.polygon = _circle_points(10.0, 14)
	orb_glow.position = Vector2(0, -32)
	orb_glow.color = Color(0.4, 0.85, 1.0, 0.3)
	staff.add_child(orb_glow)
	orb = Polygon2D.new()
	orb.polygon = _circle_points(5.0, 12)
	orb.position = Vector2(0, -32)
	orb.color = Color(0.55, 0.9, 1.0, 1.0)
	staff.add_child(orb)

func start_idle_animation() -> void:
	# gentle pulsing of the staff orb's glow so he reads as "charged"
	if not orb_glow:
		return
	var t = orb_glow.create_tween()
	t.set_loops()
	t.tween_property(orb_glow, "scale", Vector2(1.25, 1.25), 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(orb_glow, "scale", Vector2(0.85, 0.85), 1.1).set_trans(Tween.TRANS_SINE)

func animate_cast() -> void:
	# a quick bright flare of the orb on each cast
	if orb:
		var t = orb.create_tween()
		t.tween_property(orb, "scale", Vector2(1.7, 1.7), 0.1)
		t.tween_property(orb, "scale", Vector2(1.0, 1.0), 0.2)
	if staff:
		var s = staff.create_tween()
		s.tween_property(staff, "rotation_degrees", -18.0, 0.1)
		s.tween_property(staff, "rotation_degrees", 0.0, 0.25)

func face_toward(pos: Vector2) -> void:
	var want = 1 if pos.x >= global_position.x else -1
	if want != facing:
		facing = want
		if gfx:
			gfx.scale.x = facing

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_bg.z_index = 60
	health_bar_bg.visible = false
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = HEALTH_COLOR_OK
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_fill.z_index = 61
	health_bar_fill.visible = false
	add_child(health_bar_fill)

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / MAX_HEALTH, 0.0, 1.0)

func update_health_bar_display(delta: float) -> void:
	if not health_bar_bg or not health_bar_fill:
		return
	if hp_reveal_timer > 0.0:
		hp_reveal_timer -= delta
	var in_danger = health > 0 and float(health) <= MAX_HEALTH * HEALTH_BAR_DANGER_THRESHOLD
	var show_bar = in_danger or hp_reveal_timer > 0.0
	health_bar_bg.visible = show_bar
	health_bar_fill.visible = show_bar
	if not show_bar:
		return
	if in_danger:
		health_bar_fill.color = HEALTH_COLOR_DANGER
		var pulse = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0))
		health_bar_bg.modulate.a = pulse
		health_bar_fill.modulate.a = pulse
	else:
		health_bar_fill.color = HEALTH_COLOR_OK
		health_bar_bg.modulate.a = 1.0
		health_bar_fill.modulate.a = 1.0

func build_proximity_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_shape = CollisionShape2D.new()
	var area_rect = RectangleShape2D.new()
	area_rect.size = Vector2(70, 70)
	area_shape.shape = area_rect
	area_shape.position = Vector2(0, -20)
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func build_hover_panel() -> void:
	hover_panel = Panel.new()
	hover_panel.visible = false
	hover_panel.z_index = 100
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.position = Vector2(-96, -130)
	hover_panel.size = Vector2(192, 74)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.92)
	style.border_color = Color(0.55, 0.6, 0.95, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	hover_panel.add_theme_stylebox_override("panel", style)
	add_child(hover_panel)

	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.position = Vector2(8, 6)
	hover_label.size = Vector2(176, 62)
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_label.add_theme_font_size_override("font_size", 11)
	hover_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
	hover_label.text = "\n".join(INFO_FIELDS)
	hover_panel.add_child(hover_label)

func is_hovering(mouse_world_pos: Vector2) -> bool:
	return HOVER_BOUNDS.has_point(mouse_world_pos - global_position)

func update_hover_panel(mouse_world_pos: Vector2) -> void:
	if not hover_panel:
		return
	hover_panel.visible = is_hovering(mouse_world_pos)

# ------------------------------------------------------------- geometry util --

func _circle_points(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

func _rock_points(radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var sides = 9
	for i in range(sides):
		var ang = TAU * float(i) / sides
		var r = radius * randf_range(0.8, 1.2)
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	return pts

func _star_points(outer: float, inner: float, spikes: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(spikes * 2):
		var r = outer if i % 2 == 0 else inner
		var ang = -PI / 2.0 + PI * float(i) / spikes
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	return pts
