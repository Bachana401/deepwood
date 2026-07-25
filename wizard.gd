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

# --- Undying escalation ---
# Every death makes Orin 1.3x stronger (HP, damage, regen), faster to cast, and
# unlocks a new named skill (more meteors / bigger blasts), FOREVER. The tier
# lives in GameState.wizard_power_tier so it persists and keeps climbing across
# the whole game -- he is secretly the unkillable final boss. These consts are
# the tier-0 baselines; apply_power_tier() scales the runtime vars below.
const POWER_MULT = 1.3
const SKILL_NAMES = [
	"Twin Meteors", "Cinderfall", "Meteor Storm", "Molten Fury",
	"Starfall", "Apocalypse Rain", "Infernal Cataclysm",
]

var power_tier := 0
var max_health := MAX_HEALTH
var meteor_damage := METEOR_DAMAGE
var cast_cooldown := CAST_COOLDOWN
var meteor_count := 1
var splash_radius := METEOR_SPLASH_RADIUS
var regen_amount := REGEN_AMOUNT

var health = MAX_HEALTH
var cast_cooldown_remaining = 0.0
var regen_timer = 0.0
var facing := 1

# PixelLab skin (art/orin/) replaces the procedural robe/hat/staff rig when the
# art is present; without it, build_visual falls back to the polygon wizard so
# this stays safe with no art shipped. idle + attack(cast) [+ hurt].
const ORIN_ROOT := "res://art/"
const ORIN_SKIN := "orin"
const ORIN_SPRITE_H := 64.0
var orin_sprite: AnimatedSprite2D = null

# Recompute every scaled stat from the current death count.
func apply_power_tier() -> void:
	power_tier = GameState.wizard_power_tier
	var m = pow(POWER_MULT, power_tier)
	max_health = int(round(MAX_HEALTH * m))
	meteor_damage = int(round(METEOR_DAMAGE * m))
	regen_amount = int(round(REGEN_AMOUNT * m))
	cast_cooldown = max(0.35, CAST_COOLDOWN * pow(0.88, power_tier))   # attack speed up
	meteor_count = min(1 + (power_tier + 1) / 2, 6)                    # T1=2, T3=3, T5=4...
	splash_radius = METEOR_SPLASH_RADIUS * (1.0 + 0.08 * power_tier)

# The skill unlocked at the current tier (unique + escalating, forever).
func current_skill_name() -> String:
	if power_tier <= 0:
		return ""
	var idx = power_tier - 1
	if idx < SKILL_NAMES.size():
		return SKILL_NAMES[idx]
	return "Power Surge %d" % (idx - SKILL_NAMES.size() + 2)

# --- Downed / respawn ---
# On death Orin doesn't vanish: he collapses into a small fireball on his exact
# spot and reforms GameState.WIZARD_RESPAWN_HOURS in-game hours later (the timer
# lives in GameState so it counts down even while the player is off in a
# dungeon and the village scene is unloaded). While down he neither deals nor
# takes damage.
const FIREBALL_Y = 22.0         # at his feet -- the ember rests ON the ground
var is_down := false
var fireball: Node2D = null
var fireball_tween: Tween = null
var body_shape: CollisionShape2D = null

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

# (Canon sync 2026-07-21: his card told the OLD story -- "trapped 2 years"
# -- while the Doctor and the pact say he came weeks ago chasing the rumour
# and went down after the taken. His cover story must match itself.)
const INFO_FIELDS = [
	"Orin, Wandering Mage",
	"Came chasing the same rumour",
	"Holds the nights with meteors",
	"Cannot be given a village job",
]
const SPEECH_LINE = "I went down after this village's people, and the deep kept me for weeks. Now I hold the nights -- until you clear the path to the root of it."

func _ready() -> void:
	# GAME_BIBLE 2.5.1: Orin is ABSENT from the village at the start. He is a
	# rumour from the Doctor first, and only appears -- "whole and unshattered,
	# as though returning from a long walk" -- once the player has carved down
	# to ~floor 15. Until then this node removes itself. (--dev keeps him, the
	# sandbox needs its meteor turret.)
	if not GameState.orin_arrived():
		queue_free()
		return
	add_to_group("village_defender")
	preload("res://char_shadow.gd").attach(self, 0.5, 22.0)  # grounding shadow at his feet
	# layer 0 = the player's weapons/arrows can never hit him (he's friendly);
	# mask 1 so he still rests on the ground. Future siege enemies will hurt him
	# through the public take_damage() below.
	collision_layer = 0
	collision_mask = 1

	body_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(24.0, 44.0)
	body_shape.shape = rect
	add_child(body_shape)

	apply_power_tier()
	health = max_health
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
	# Gravity + rest-on-floor ALWAYS run (even while down) so the ember settles
	# on the ground where he fell. He never blocks anyone: collision_layer = 0
	# means nothing collides with him, and while down he also leaves the
	# village_defender group so raiders don't path to the ember.
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
		else:
			update_ember_growth()
		return

	tick_regen(delta)
	update_health_bar_display(delta)
	if player_inside and Input.is_action_just_pressed("interact"):
		SpeechText.spawn(self, SPEECH_LINE)
	update_hover_panel(get_global_mouse_position())

# Slow, steady self-heal. Only tops up the number + bar fill -- it never forces
# the bar visible (that stays reserved for the on-hit reveal / danger pulse).
func tick_regen(delta: float) -> void:
	if health >= max_health:
		return
	regen_timer += delta
	if regen_timer >= REGEN_INTERVAL:
		regen_timer -= REGEN_INTERVAL
		health = min(max_health, health + regen_amount)
		update_health_bar_fill()

# ------------------------------------------------------------------ combat ---

func try_cast() -> void:
	var target = find_target()
	if target == null:
		return
	cast_cooldown_remaining = cast_cooldown
	face_toward(target.global_position)
	animate_cast()
	# higher tiers rain several meteors per cast (his unlocked skills)
	for i in range(meteor_count):
		var off = Vector2.ZERO if i == 0 else Vector2(randf_range(-42.0, 42.0), randf_range(-8.0, 8.0))
		cast_meteor_at(target.global_position + off)

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
	# The meteor takes METEOR_FALL_TIME to land, and if Orin is freed in that window
	# (killed mid-siege, or his object slot later reused by another node) the
	# deferred callback would fire with a STALE self -- surfacing as "Nonexistent
	# function 'apply_meteor_impact' in base ... npc.gd". Capture his instance ID
	# (an int, so no "lambda capture was freed" either) and re-resolve it at impact:
	# a dead mage's in-flight meteor simply fizzles instead of erroring.
	var caster_id := get_instance_id()
	t.tween_callback(func():
		var caster = instance_from_id(caster_id)
		if is_instance_valid(caster) and caster.has_method("apply_meteor_impact"):
			caster.apply_meteor_impact(impact_pos)
			caster.spawn_impact_fx(impact_pos)
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
			if impact_pos.distance_to(e.global_position) <= splash_radius and e.has_method("take_damage"):
				e.take_damage(meteor_damage)

func spawn_impact_fx(impact_pos: Vector2) -> void:
	var ring = Polygon2D.new()
	ring.polygon = _circle_points(splash_radius * 0.5, 20)
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
	GameState.wizard_power_tier += 1   # he returns stronger every single time
	GameState.mark_wizard_down()
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification("Orin has fallen -- his magic collapses to an ember. He'll reform in %d hours... stronger." % int(GameState.WIZARD_RESPAWN_HOURS))
	enter_downed_state(true)

# ------------------------------------------------------------ downed / reform ---

func build_fireball() -> void:
	fireball = Node2D.new()
	fireball.name = "DownedFireball"
	fireball.position = Vector2(0, FIREBALL_Y)
	fireball.visible = false
	fireball.z_index = 5
	add_child(fireball)

	# soft glowing pool where the flame meets the ground
	var pool = Polygon2D.new()
	pool.polygon = _ellipse_points(17.0, 5.5, 18)
	pool.color = Color(1.0, 0.5, 0.14, 0.4)
	pool.material = _additive_material()
	fireball.add_child(pool)

	# outer glow halo (additive) lighting the ground around it
	var halo = Polygon2D.new()
	halo.polygon = _flame_points(20.0, 40.0)
	halo.color = Color(1.0, 0.4, 0.1, 0.22)
	halo.material = _additive_material()
	fireball.add_child(halo)

	# three nested flame tongues, base on the ground, licking upward
	var outer = Polygon2D.new()
	outer.polygon = _flame_points(15.0, 34.0)
	outer.color = Color(0.86, 0.22, 0.05, 0.96)
	fireball.add_child(outer)

	var mid = Polygon2D.new()
	mid.polygon = _flame_points(10.0, 26.0)
	mid.color = Color(1.0, 0.5, 0.12, 1.0)
	fireball.add_child(mid)

	var inner = Polygon2D.new()
	inner.polygon = _flame_points(5.5, 16.0)
	inner.color = Color(1.0, 0.92, 0.55, 1.0)
	fireball.add_child(inner)

	# MAIN FIRE: a dense column of particles whose colour ramps yellow-white ->
	# orange -> red -> smoke over their short life. This colour-over-lifetime is
	# what makes it read as real fire rather than a glowing blob.
	var fire = CPUParticles2D.new()
	fire.name = "Flames"
	fire.position = Vector2(0, -3.0)
	fire.amount = 46
	fire.lifetime = 0.55
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(7.0, 2.0)
	fire.direction = Vector2(0, -1)
	fire.spread = 10.0
	fire.gravity = Vector2(0, -160)
	fire.initial_velocity_min = 34.0
	fire.initial_velocity_max = 66.0
	fire.damping_min = 12.0
	fire.damping_max = 24.0
	fire.scale_amount_min = 3.2
	fire.scale_amount_max = 5.2
	var fire_scale := Curve.new()
	fire_scale.add_point(Vector2(0.0, 1.0))
	fire_scale.add_point(Vector2(1.0, 0.15))   # shrink as they rise -> tapered flame
	fire.scale_amount_curve = fire_scale
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.65, 1.0),   # hot yellow-white core
		Color(1.0, 0.62, 0.16, 1.0),   # orange
		Color(0.86, 0.22, 0.05, 0.85), # deep red
		Color(0.25, 0.06, 0.03, 0.0),  # fades to dark smoke
	])
	fire.color_ramp = grad
	fire.emitting = false
	fireball.add_child(fire)

	# SPARKS: a few bright embers popping upward for life on top of the fire.
	var sparks = CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.position = Vector2(0, -10.0)
	sparks.amount = 12
	sparks.lifetime = 0.8
	sparks.direction = Vector2(0, -1)
	sparks.spread = 22.0
	sparks.gravity = Vector2(0, -60)
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 95.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = Color(1.0, 0.85, 0.4, 1.0)
	sparks.emitting = false
	fireball.add_child(sparks)

# Hide the mage, show the ember. `animated` = the death collapse (burst + shrink);
# false = he was already down when the scene loaded, so just show the ember.
func enter_downed_state(animated: bool) -> void:
	is_down = true
	cast_cooldown_remaining = cast_cooldown
	# drop out of the defender group so raiders don't path to the ember (he still
	# rests on the ground via physics; collision_layer 0 means he blocks nobody).
	if is_in_group("village_defender"):
		remove_from_group("village_defender")
	if health_bar_bg:
		health_bar_bg.visible = false
	if health_bar_fill:
		health_bar_fill.visible = false

	if fireball:
		fireball.visible = true
		_set_fireball_flames(true)
		if fireball_tween and fireball_tween.is_valid():
			fireball_tween.kill()
		# starts as a tiny dull ember; update_ember_growth() (called each frame
		# while down) swells + brightens it as the revival time nears.
		fireball.modulate = Color(0.5, 0.38, 0.38, 0.85)
		fireball.scale = Vector2.ONE * 0.22
		update_ember_growth()

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
	apply_power_tier()          # he comes back 1.3x stronger + a new skill
	health = max_health         # ALWAYS full HP after reforming
	regen_timer = 0.0
	update_health_bar_fill()
	cast_cooldown_remaining = 0.5   # a beat to finish the pop-in before casting
	# back to being a targetable wall-defender
	if not is_in_group("village_defender"):
		add_to_group("village_defender")

	# the ember erupts into a big fiery flash, then he's standing there again
	if fireball:
		if fireball_tween and fireball_tween.is_valid():
			fireball_tween.kill()
		fireball.modulate = Color(1.6, 1.4, 1.0, 1.0)
		var ft = fireball.create_tween()
		ft.tween_property(fireball, "scale", Vector2(3.2, 3.4), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.parallel().tween_property(fireball, "modulate:a", 0.0, 0.24)
		ft.tween_callback(func():
			if not fireball:
				return
			fireball.visible = false
			fireball.modulate = Color(1, 1, 1, 1)
			fireball.scale = Vector2.ONE
			_set_fireball_flames(false))

	spawn_revive_flash()
	spawn_puff(28, Color(1.0, 0.8, 0.4, 1.0))
	if gfx:
		gfx.visible = true
		gfx.scale = Vector2(0.001 * facing, 0.001)
		var gt = gfx.create_tween()
		gt.tween_property(gfx, "scale", Vector2(float(facing), 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		var skill = current_skill_name()
		if skill != "":
			notif.show_notification("Orin reforms STRONGER (Power %d) -- unlocked %s! HP %d, %d/meteor." % [power_tier, skill, max_health, meteor_damage])
		else:
			notif.show_notification("Orin reforms and returns to the walls!")

func _set_fireball_flames(on: bool) -> void:
	if not fireball:
		return
	for c in fireball.get_children():
		if c is CPUParticles2D:
			c.emitting = on

# Called every frame while he's an ember: it starts tiny and dull right after
# death and swells larger, brighter and hotter as the revive time approaches.
func update_ember_growth() -> void:
	if not fireball or not fireball.visible:
		return
	var p = GameState.wizard_down_progress()   # 0 just fell -> 1 about to revive
	var grow = lerp(0.22, 1.5, p)
	var flicker = 1.0 + 0.14 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
	fireball.scale = Vector2.ONE * grow * flicker
	# dull dark ember -> bright hot yellow-white fire near revival
	fireball.modulate = Color(0.5, 0.38, 0.38, 0.85).lerp(Color(1.45, 1.2, 0.9, 1.0), p)

# A bright expanding flash ring at his feet the instant he reforms.
func spawn_revive_flash() -> void:
	var flash = Polygon2D.new()
	flash.polygon = _circle_points(20.0, 20)
	flash.position = Vector2(0, FIREBALL_Y - 12.0)
	flash.color = Color(1.0, 0.85, 0.55, 0.9)
	flash.material = _additive_material()
	flash.z_index = 42
	add_child(flash)
	var t = flash.create_tween()
	t.tween_property(flash, "scale", Vector2(4.5, 4.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)

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

	# a PixelLab wizard skin replaces the whole polygon rig (robe/hat/staff/orb)
	if EnemySkins.is_per_frame(ORIN_SKIN, ORIN_ROOT):
		_build_orin_sprite()
		return

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

# Skinned Orin: an AnimatedSprite2D under gfx, feet planted on the old robe-hem
# line (gfx-local +22 = the collision underside), idle playing. Casting swaps to
# the non-looping attack anim and returns to idle when it finishes.
func _build_orin_sprite() -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(ORIN_SKIN, ORIN_ROOT)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ch := EnemySkins.content_height(ORIN_SKIN, ORIN_ROOT)
	var sc := ORIN_SPRITE_H / ch
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(-EnemySkins.hcenter_px(ORIN_SKIN, ORIN_ROOT), 22.0 / sc - EnemySkins.feet_px(ORIN_SKIN, ORIN_ROOT))
	if spr.sprite_frames.has_animation("idle"):
		spr.play("idle")
	spr.animation_finished.connect(_on_orin_anim_finished)
	gfx.add_child(spr)
	orin_sprite = spr

func _on_orin_anim_finished() -> void:
	if orin_sprite and orin_sprite.animation != "idle" and orin_sprite.sprite_frames.has_animation("idle"):
		orin_sprite.play("idle")

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
	# skinned Orin plays his cast animation (returns to idle when it finishes)
	if orin_sprite and orin_sprite.sprite_frames.has_animation("attack"):
		orin_sprite.play("attack")
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
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / max_health, 0.0, 1.0)

func update_health_bar_display(delta: float) -> void:
	if not health_bar_bg or not health_bar_fill:
		return
	if hp_reveal_timer > 0.0:
		hp_reveal_timer -= delta
	var in_danger = health > 0 and float(health) <= max_health * HEALTH_BAR_DANGER_THRESHOLD
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

# A flattened ellipse (for the flame's ground pool).
func _ellipse_points(rx: float, ry: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

# A flame-tongue silhouette: base on the ground (local y = 0, width `w`),
# tapering to a curled tip at the top (local y = -h). Slight asymmetry gives it
# a lively lick rather than a symmetric teardrop.
func _flame_points(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, 0.0),
		Vector2(-w * 0.5, -h * 0.34),
		Vector2(-w * 0.22, -h * 0.62),
		Vector2(-w * 0.30, -h * 0.82),
		Vector2(-w * 0.08, -h * 0.95),
		Vector2(w * 0.06, -h),          # curled tip
		Vector2(w * 0.26, -h * 0.86),
		Vector2(w * 0.20, -h * 0.64),
		Vector2(w * 0.5, -h * 0.34),
		Vector2(w * 0.5, 0.0),
	])

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
