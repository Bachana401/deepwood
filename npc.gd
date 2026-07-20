extends CharacterBody2D

# Points back at their entry in GameState.rescued_villagers -- info is
# always looked up fresh (name/age/sex/stat) rather than cached here, so it
# stays correct even after they graduate school/barracks or get reassigned.
var villager_id: String = ""

const GRAVITY = 900.0
const SPEED = 40.0
# Keeps unemployed NPCs wandering within the whole village, not drifting into
# the combat course or off the far end past the mating houses. Once assigned
# to a building, wander_min_x/max_x below narrow this down to just that
# building's neighborhood instead (see refresh_wander_bounds).
const WANDER_MIN_X = 4850.0
const WANDER_MAX_X = 8000.0
const MIN_WALK_SECONDS = 2.0
const MAX_WALK_SECONDS = 5.0
const MIN_IDLE_SECONDS = 1.5
const MAX_IDLE_SECONDS = 4.0

var direction = 0
var is_walking = false
var state_timer = 0.0
var player_inside = false
var wander_min_x = WANDER_MIN_X
var wander_max_x = WANDER_MAX_X

# Assigned villagers periodically clock in at their workplace: 0-5 times per
# 24 in-game hours, each visit lasting 30-60 in-game minutes, at random times
# re-rolled every cycle -- so some days they might not go in at all, other
# days up to 5 times. Ticks off the same in-game clock as mating/school (see
# GameState), so debug time-skip keys speed this up/rewind it correctly too.
const VISIT_MIN_HOURS = 0.5
const VISIT_MAX_HOURS = 1.0
const CYCLE_LENGTH_HOURS = 24.0
const MIN_VISITS_PER_CYCLE = 0
const MAX_VISITS_PER_CYCLE = 5
const BUILDING_WANDER_RADIUS = 70.0

var last_hours_elapsed = 0.0
var cycle_elapsed_hours = 0.0
var visit_times_this_cycle: Array = []
var is_in_building = false
var hours_until_exit = 0.0

# Small hover tooltip, attached above the NPC's head -- shown while the
# mouse is over them, no click needed (left-click already swings the
# player's weapon, so a click-to-inspect would double as an attack).
const HOVER_BOUNDS = Rect2(-20.0, -40.0, 40.0, 44.0)
var hover_panel: Panel = null
var hover_label: Label = null

# Kids are drawn/collide smaller than adults (see apply_size) -- graduating
# school/barracks flips is_kid to false well after spawn, so this tracks the
# last-applied value and re-sizes on change rather than only sizing once.
var collision_shape: CollisionShape2D = null
var last_applied_is_kid = true

# Health. The bar is normally hidden. On any hit it flashes into view for a
# moment (HIT_REVEAL_SECONDS) so the player notices the villager is under
# attack, then hides again. Once HP is at/below the danger threshold (30%) it
# stays visible AND pulses red -- a "about to die" warning. At 0 the villager
# dies for good (removed from roster + world, see die()). The player can't
# deal this damage (collision_layer 0); it's reserved for future siege enemies.
const MAX_HEALTH = 100
const HEALTH_BAR_DANGER_THRESHOLD = 0.30
const HEALTH_BAR_HIT_REVEAL_SECONDS = 1.6
const HEALTH_BAR_WIDTH = 30.0
const HEALTH_BAR_HEIGHT = 5.0
const HEALTH_BAR_Y = -48.0
const HEALTH_COLOR_OK = Color(0.15, 0.75, 0.25, 1.0)
const HEALTH_COLOR_DANGER = Color(0.9, 0.15, 0.15, 1.0)
var health = MAX_HEALTH
var hp_reveal_timer = 0.0
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

func _ready() -> void:
	add_to_group("npc")
	# SHADOW ARMY (GAME_BIBLE 9.6): a raised villager is themselves, continued --
	# same name, home and job -- re-made in shadow-form. The whole body reads as
	# living shadow: darkened, faintly violet, slightly translucent.
	call_deferred("_apply_shadow_form")
	# layer 0 = NOT on any hittable layer, so the player's weapons/arrows can
	# never target villagers. Damage only ever arrives through the public
	# take_damage() below -- reserved for the future village-siege enemies.
	collision_layer = 0
	collision_mask = 1
	pick_new_state()
	build_visual()
	build_hover_panel()
	build_health_bar()
	refresh_wander_bounds()
	# NPCs can spawn well after in-game time has already been ticking (e.g. a
	# child born hours into a playthrough) -- start the local clock baseline
	# at the CURRENT reading, not 0, or the very first tick would see a huge
	# false "hours_passed" and immediately roll/skip a full cycle.
	last_hours_elapsed = GameState.game_hours
	roll_new_cycle()

	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	apply_size()

	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_shape = CollisionShape2D.new()
	var area_rect = RectangleShape2D.new()
	area_rect.size = Vector2(60, 60)
	area_shape.shape = area_rect
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

# Villager avatars are little HUMANS now (legs, tunic, arms, head, hood), not
# flat squares. Looks are deterministic per villager_id so the same person
# always wears the same outfit; sexes lean toward different tunic palettes.
const NPC_SKINS = [Color(0.87, 0.72, 0.56), Color(0.78, 0.6, 0.45), Color(0.92, 0.78, 0.64)]
const NPC_TUNICS_M = [Color(0.36, 0.46, 0.58), Color(0.4, 0.52, 0.4), Color(0.44, 0.4, 0.6), Color(0.5, 0.42, 0.3)]
const NPC_TUNICS_F = [Color(0.62, 0.44, 0.52), Color(0.6, 0.5, 0.34), Color(0.5, 0.42, 0.62), Color(0.56, 0.36, 0.34)]
const NPC_PANTS = [Color(0.3, 0.28, 0.34), Color(0.36, 0.3, 0.22), Color(0.28, 0.34, 0.3)]
const NPC_HOODS = [Color(0.24, 0.4, 0.26), Color(0.42, 0.3, 0.2), Color(0.45, 0.26, 0.28)]

# PixelLab villager skins (art/villagers/<man|woman|kid>/) replace the ColorRect
# body when the art is present; without it, apply_size falls back to the
# deterministic little-person build above, so this is safe with no art shipped.
const VILLAGER_ROOT := "res://art/villagers/"
const VILLAGER_SPRITE_H := 38.0   # adult on-screen height; kids inherit body_scale_factor (0.65)
var villager_sprite: AnimatedSprite2D = null

var body_gfx: Node2D = null
var body_scale_factor := 1.0
# limb references for the walk animation (arms/legs swing in opposition)
var l_leg: ColorRect = null
var r_leg: ColorRect = null
var l_arm: ColorRect = null
var r_arm: ColorRect = null
var walk_anim_t := 0.0
var cheer_timer := 0.0        # >0 while celebrating a 10/10 morale
var cheer_bubble_cd := 0.0
var cheer_style := 0          # each villager's signature celebration move (0..4)
var cheer_phase := 0.0        # per-villager time offset so nobody is in sync
var cheer_cooldown := 0.0     # after a burst, back to normal life for a while

func build_visual() -> void:
	body_gfx = Node2D.new()
	body_gfx.name = "Body"
	add_child(body_gfx)

func _body_px(x: float, y: float, w: float, h: float, col: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_gfx.add_child(r)
	return r

# Applies both the sprite size and the physical collision box for the
# villager's CURRENT is_kid/sex, and remembers is_kid so refresh_size_if_needed
# only does real work when it actually changes (e.g. on graduation).
func apply_size() -> void:
	var data = find_villager_data()
	var is_kid = data.get("is_kid", true)
	var sex = data.get("sex", "Female")
	last_applied_is_kid = is_kid
	var scale_factor = 0.65 if is_kid else 1.0
	body_scale_factor = scale_factor

	if body_gfx:
		for c in body_gfx.get_children():
			body_gfx.remove_child(c)
			c.queue_free()
		# a skinned villager drives an AnimatedSprite2D; the procedural limb refs
		# stay null so the walk/cheer code below harmlessly skips them
		l_leg = null
		r_leg = null
		l_arm = null
		r_arm = null
		var vskin := _villager_skin(is_kid, sex)
		if EnemySkins.is_per_frame(vskin, VILLAGER_ROOT):
			_build_villager_sprite(vskin)
		else:
			# deterministic little-person fallback (no PixelLab art present)
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(villager_id)
			var skin = NPC_SKINS[rng.randi() % NPC_SKINS.size()]
			var tunics = NPC_TUNICS_M if sex == "Male" else NPC_TUNICS_F
			var tunic = tunics[rng.randi() % tunics.size()]
			var pants = NPC_PANTS[rng.randi() % NPC_PANTS.size()]
			var hood = NPC_HOODS[rng.randi() % NPC_HOODS.size()]
			# ~34px human, feet at local (0,0); limbs pivot at hip/shoulder so the
			# walk cycle can swing them (arm forward, opposite leg back)
			l_leg = _body_px(-5.5, -10.0, 4.4, 10.0, pants)
			r_leg = _body_px(1.1, -10.0, 4.4, 10.0, pants)
			l_leg.pivot_offset = Vector2(2.2, 0.0)
			r_leg.pivot_offset = Vector2(2.2, 0.0)
			_body_px(-6.5, -23.5, 13.0, 13.5, tunic)               # tunic
			l_arm = _body_px(-9.2, -22.5, 3.0, 10.0, tunic.darkened(0.12))
			r_arm = _body_px(6.2, -22.5, 3.0, 10.0, tunic.darkened(0.12))
			l_arm.pivot_offset = Vector2(1.5, 0.0)
			r_arm.pivot_offset = Vector2(1.5, 0.0)
			_body_px(-6.5, -12.5, 13.0, 2.4, tunic.darkened(0.35)) # belt
			_body_px(-4.2, -32.0, 8.4, 8.5, skin)                  # head
			_body_px(-4.8, -34.4, 9.6, 3.6, hood)                  # hood
		body_gfx.scale = Vector2(scale_factor, scale_factor)
		# the collision box is centred on the node, so its underside sits
		# 18*scale below origin -- anchor the feet THERE, on the actual ground
		body_gfx.position = Vector2(0.0, 18.0 * scale_factor)
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = Vector2(20.0 * scale_factor, 36.0 * scale_factor)

# Adult villagers pick deterministically among the sprite VARIANTS whose art is
# actually present -- so each person keeps one consistent look, and dropping in
# art/villagers/man2 ... man5 / woman2 ... woman5 automatically widens the pool
# with no code change. Kids share one sprite.
const VILLAGER_VARIANTS := {
	"Male": ["man", "man2", "man3", "man4", "man5"],
	"Female": ["woman", "woman2", "woman3", "woman4", "woman5"],
}
func _villager_skin(is_kid: bool, sex: String) -> String:
	if is_kid:
		return "kid"
	var candidates: Array = VILLAGER_VARIANTS.get(sex, VILLAGER_VARIANTS["Female"])
	var have: Array = []
	for v in candidates:
		if EnemySkins.is_per_frame(v, VILLAGER_ROOT):
			have.append(v)
	if have.is_empty():
		return candidates[0]
	return have[abs(hash(villager_id)) % have.size()]

# Builds the AnimatedSprite2D villager body under body_gfx: normalised to
# VILLAGER_SPRITE_H, feet planted on body_gfx's local origin (matching the
# procedural build), idle playing. body_gfx.scale (facing * body_scale_factor)
# and body_gfx.position are applied by apply_size for both body types.
func _build_villager_sprite(vskin: String) -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(vskin, VILLAGER_ROOT)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ch := EnemySkins.content_height(vskin, VILLAGER_ROOT)
	var sc := VILLAGER_SPRITE_H / ch
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(-EnemySkins.hcenter_px(vskin, VILLAGER_ROOT), -EnemySkins.feet_px(vskin, VILLAGER_ROOT))
	if spr.sprite_frames.has_animation("idle"):
		spr.animation = "idle"
		spr.play("idle")
	body_gfx.add_child(spr)
	villager_sprite = spr

# Skinned villagers swap idle<->walk from the movement state each frame.
func _update_villager_anim() -> void:
	if villager_sprite == null:
		return
	var want := "walk" if is_walking else "idle"
	var sf := villager_sprite.sprite_frames
	if sf and sf.has_animation(want) and villager_sprite.animation != want:
		villager_sprite.play(want)

func refresh_size_if_needed() -> void:
	var data = find_villager_data()
	if data.get("is_kid", true) != last_applied_is_kid:
		apply_size()

func build_hover_panel() -> void:
	hover_panel = Panel.new()
	hover_panel.visible = false
	hover_panel.z_index = 100
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.position = Vector2(-78, -108)
	hover_panel.size = Vector2(156, 82)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.9)
	style.border_color = Color(0.65, 0.65, 0.7, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	hover_panel.add_theme_stylebox_override("panel", style)
	add_child(hover_panel)

	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.position = Vector2(8, 6)
	hover_label.size = Vector2(128, 54)
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_label.add_theme_font_size_override("font_size", 11)
	hover_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hover_panel.add_child(hover_label)

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_bg.z_index = 60
	health_bar_bg.visible = false
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.15, 0.75, 0.25, 1.0)
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_fill.z_index = 61
	health_bar_fill.visible = false
	add_child(health_bar_fill)

# Public entry point for anything that hurts a villager (reserved for the
# future village-siege enemies). Villagers sheltered inside a building are safe.
func take_damage(amount: int) -> void:
	if is_in_building:
		return
	health -= amount
	if health <= 0:
		die()
		return
	# flash the bar into view briefly so the player sees they're taking hits
	hp_reveal_timer = HEALTH_BAR_HIT_REVEAL_SECONDS
	update_health_bar_fill()

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / MAX_HEALTH, 0.0, 1.0)

# When the whole village is starving (morale below 2/10 for too long) every
# villager visibly wastes away: their HP bar drains toward the town-wide
# starvation HP and the body takes on a sickly grey pallor. GameState is the
# authority that actually kills them at 0 HP; this only mirrors it on screen.
func apply_despair_visual() -> void:
	if health_bar_fill == null or health_bar_bg == null:
		return
	# THE ROT (10): a villager whose own hope sits at zero greys out and
	# flickers -- the telegraph that says "mend their life NOW or lose them".
	# Distinct from the village-wide wasting below: this one is personal.
	if GameState.villager_rot.has(villager_id):
		if body_gfx:
			var pulse := 0.55 + 0.15 * sin(Time.get_ticks_msec() / 180.0)
			body_gfx.modulate = Color(pulse, pulse, pulse)
		return
	if GameState.village_in_despair():
		var frac = clampf(GameState.get_villager_hp(villager_id) / 100.0, 0.0, 1.0)
		health_bar_bg.visible = true
		health_bar_fill.visible = true
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * frac
		health_bar_fill.color = Color(0.72, 0.5, 0.15)   # sickly amber
		health_bar_bg.modulate.a = 1.0
		health_bar_fill.modulate.a = 1.0
		if body_gfx:
			body_gfx.modulate = Color(0.72, 0.76, 0.8)   # grey, wasting away
	elif body_gfx and body_gfx.modulate != Color(1, 1, 1):
		body_gfx.modulate = Color(1, 1, 1)               # colour returns once fed

# Called every frame. Bar is shown while a recent-hit reveal is counting down,
# or permanently (pulsing red) once HP is in the danger zone.
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
		# pulse the whole bar's opacity as a danger warning
		var pulse = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0))
		health_bar_bg.modulate.a = pulse
		health_bar_fill.modulate.a = pulse
	else:
		health_bar_fill.color = HEALTH_COLOR_OK
		health_bar_bg.modulate.a = 1.0
		health_bar_fill.modulate.a = 1.0

func die() -> void:
	# permanent: gone from the roster (so no income/mating/etc. and doesn't
	# come back on reload) and gone from the world. remove_villager_by_id
	# despawns this avatar via the "npc" group; the guard covers a missing id.
	GameState.remove_villager_by_id(villager_id)
	if not is_queued_for_deletion():
		queue_free()

func _physics_process(delta: float) -> void:
	if is_in_building:
		velocity = Vector2.ZERO
		return

	# En route to a building visit: march straight to the door, then slip in.
	if door_target != null:
		if not is_instance_valid(door_target):
			door_target = null
		else:
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			var door_dx = door_target.global_position.x - global_position.x
			if absf(door_dx) < 8.0:
				_complete_enter()
				return
			direction = 1 if door_dx > 0.0 else -1
			velocity.x = direction * SPEED
			# A villager sent to their building keeps whatever walk/idle state the
			# wander AI last picked, so anyone summoned mid-idle marched to the
			# door playing their IDLE animation -- sliding along like a statue on
			# rails. They are, self-evidently, walking.
			is_walking = true
			if body_gfx:
				body_gfx.scale.x = direction * body_scale_factor
			_update_villager_anim()
			walk_anim_t += delta * 9.0
			var door_swing = sin(walk_anim_t)
			if l_leg:
				l_leg.rotation = door_swing * 0.5
				r_leg.rotation = -door_swing * 0.5
				l_arm.rotation = -door_swing * 0.42
				r_arm.rotation = door_swing * 0.42
			move_and_slide()
			return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	state_timer -= delta
	if state_timer <= 0:
		pick_new_state()

	if is_walking:
		if global_position.x <= wander_min_x:
			direction = 1
		elif global_position.x >= wander_max_x:
			direction = -1
		velocity.x = direction * SPEED
		if body_gfx and direction != 0:
			body_gfx.scale.x = direction * body_scale_factor
		# simple walk cycle: arm swings forward while the opposite leg swings back
		walk_anim_t += delta * 9.0
		var swing = sin(walk_anim_t)
		if l_leg:
			l_leg.rotation = swing * 0.5
			r_leg.rotation = -swing * 0.5
			l_arm.rotation = -swing * 0.42
			r_arm.rotation = swing * 0.42
	else:
		velocity.x = 0
		if l_leg:   # settle limbs when standing
			l_leg.rotation = lerpf(l_leg.rotation, 0.0, 0.2)
			r_leg.rotation = lerpf(r_leg.rotation, 0.0, 0.2)
			l_arm.rotation = lerpf(l_arm.rotation, 0.0, 0.2)
			r_arm.rotation = lerpf(r_arm.rotation, 0.0, 0.2)

	# celebration overrides everything: each villager does their own festive move,
	# but only in BURSTS -- when a burst ends they go on cooldown and resume
	# whatever they were doing (walking/idle) until the next one.
	if cheer_cooldown > 0.0:
		cheer_cooldown -= delta
	if cheer_timer > 0.0:
		cheer_timer -= delta
		if cheer_timer <= 0.0:
			cheer_cooldown = randf_range(6.0, 16.0)   # rejoin normal village life
		_apply_cheer(delta)
	elif body_gfx:
		body_gfx.position.y = 18.0 * body_scale_factor   # feet back on the ground
		body_gfx.rotation = 0.0

	_update_villager_anim()
	move_and_slide()

# Called by village_life.gd while the town is celebrating a 10/10 morale. Each
# villager gets a signature move (stable per person) and a random time offset,
# so the crowd looks like a real crowd -- one claps, one jumps, one waves, one
# dances, one fist-pumps -- all slightly out of sync rather than a Mexican wave.
func cheer(seconds: float) -> void:
	if cheer_cooldown > 0.0:
		return   # just celebrated -- taking a break, back to normal for now
	if cheer_timer <= 0.0:
		cheer_style = abs(hash(villager_id)) % 5
		cheer_phase = randf() * 10.0
	cheer_timer = maxf(cheer_timer, seconds)

func _apply_cheer(delta: float) -> void:
	velocity.x = 0.0
	var t = Time.get_ticks_msec() / 1000.0 + cheer_phase
	var base_y = 18.0 * body_scale_factor
	var hop = 0.0
	if l_leg:
		l_leg.rotation = 0.0
		r_leg.rotation = 0.0
	match cheer_style:
		0:  # clap overhead
			hop = absf(sin(t * 3.0)) * 2.0 * body_scale_factor
			var c = sin(t * 11.0) * 0.35
			if l_arm: l_arm.rotation = -2.3 + c
			if r_arm: r_arm.rotation = 2.3 - c
		1:  # big rhythmic jumps, arms up
			hop = absf(sin(t * 5.0)) * 7.0 * body_scale_factor
			if l_arm: l_arm.rotation = -2.0
			if r_arm: r_arm.rotation = 2.0
		2:  # wave one arm overhead
			if l_arm: l_arm.rotation = 0.25
			if r_arm: r_arm.rotation = 2.4 + sin(t * 6.0) * 0.5
		3:  # dance: sway + arms swinging
			var s = sin(t * 4.0)
			if l_arm: l_arm.rotation = -1.2 + s * 0.5
			if r_arm: r_arm.rotation = 1.2 - s * 0.5
			hop = absf(sin(t * 4.0)) * 1.5 * body_scale_factor
			if body_gfx: body_gfx.rotation = sin(t * 3.5) * 0.13
		4:  # fist pump
			var p = sin(t * 7.0) * 0.5 + 0.5
			if r_arm: r_arm.rotation = lerpf(0.7, 2.4, p)
			if l_arm: l_arm.rotation = -0.3
			hop = absf(sin(t * 3.5)) * 2.5 * body_scale_factor
	if body_gfx:
		body_gfx.position.y = base_y - hop
		if cheer_style != 3:
			body_gfx.rotation = 0.0
	cheer_bubble_cd -= delta
	if cheer_bubble_cd <= 0.0:
		cheer_bubble_cd = randf_range(1.6, 3.4)
		if randf() < 0.55:
			var lines = ["Hooray!", "Woo!", "For the hero!", "Long live Deepwood!", "Best day ever!"]
			SpeechText.spawn(self, lines[randi() % lines.size()])

func pick_new_state() -> void:
	if is_walking:
		is_walking = false
		state_timer = randf_range(MIN_IDLE_SECONDS, MAX_IDLE_SECONDS)
	else:
		is_walking = true
		direction = -1 if randf() < 0.5 else 1
		state_timer = randf_range(MIN_WALK_SECONDS, MAX_WALK_SECONDS)

func find_villager_data() -> Dictionary:
	for v in GameState.rescued_villagers:
		if v.get("id") == villager_id:
			return v
	return {}

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _process(delta: float) -> void:
	refresh_size_if_needed()
	update_health_bar_display(delta)
	apply_despair_visual()
	refresh_wander_bounds()
	tick_building_visits()
	if is_in_building:
		if hover_panel:
			hover_panel.visible = false
		return
	if player_inside and Input.is_action_just_pressed("interact"):
		if not try_doctor_heal() and not try_bond_interaction():
			show_info()
	tick_mood_talk(delta)

# E on the Doctor (GAME_BIBLE 5.5a): a full heal at an escalating price. Every
# purchase raises the next by half again; a day of peace forgives one step.
# This is the early game's lifeline before potions flow -- and it dies with
# her, because she is an ordinary villager a siege can take.
func _apply_shadow_form() -> void:
	var data = find_villager_data()
	if data.is_empty() or not data.get("shadow", false):
		return
	modulate = Color(0.45, 0.35, 0.6, 0.85)

func try_doctor_heal() -> bool:
	var data = find_villager_data()
	if data.is_empty() or not data.get("healer", false):
		return false
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return true
	# her first real talk is the ACCOUNT (2.4.1/2.5.1): the Law of Despair from
	# a survivor's mouth, and the rumour of the lost wizard. Healing starts on
	# the next press.
	if not GameState.seen_doctor_account:
		GameState.seen_doctor_account = true
		DialogueBox.play(get_tree().current_scene, Story.DOCTOR_ACCOUNT)
		return true
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if player.health >= player.get_max_health():
		if stack:
			stack.show_notification("Doctor: \"Not a scratch on you. Don't waste my thread.\"")
		return true
	var price: int = GameState.doctor_heal_price()
	if player.currency < price:
		if stack:
			stack.show_notification("Doctor: \"Healing costs %d gold. Come back when you have it.\"" % price)
		_play_doctor_sfx(preload("res://audio/purchase_denied.wav"))
		return true
	player.currency -= price
	player.update_currency_display()
	_play_doctor_sfx(preload("res://audio/purchase.wav"))
	player.health = player.get_max_health()
	if player.has_method("update_health_display"):
		player.update_health_display()
	GameState.doctor_heals_bought += 1
	if stack:
		stack.show_notification("The Doctor stitches you whole (-%d gold). Next visit: %d." % [price, GameState.doctor_heal_price()])
	return true

func _play_doctor_sfx(stream: AudioStream) -> void:
	var sp = AudioStreamPlayer2D.new()
	sp.stream = stream
	sp.global_position = global_position
	get_parent().add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)

# E on a villager with a bond: claim it if ready (reveal + reward + their line),
# otherwise voice the quest giver/objective. Returns true if the bond handled the
# press so the generic self-introduction doesn't also fire. No bond -> false.
func try_bond_interaction() -> bool:
	var data = find_villager_data()
	if data.is_empty() or VillagerQuests.get_def(str(data.get("id", ""))).is_empty():
		return false
	if data.get("quest_state", "") == "done":
		return false   # bond finished; fall through to normal chatter
	var pl = get_tree().get_first_node_in_group("player")
	var def = VillagerQuests.get_def(str(data.get("id", "")))
	if GameState.villager_quest_ready(data, pl):
		var line = GameState.turn_in_villager_quest(str(data.get("id", "")), pl)
		SpeechText.spawn(self, line if line != "" else "Thank you.")
		var notif = get_node_or_null("../CanvasLayer/NotificationStack")
		if notif == null:
			notif = get_tree().get_first_node_in_group("notification_stack")
		if notif:
			var msg = "Bond complete: " + str(def.get("title", ""))
			if int(def.get("reward_gold", 0)) > 0:
				msg += "  (+%dg)" % int(def.get("reward_gold"))
			notif.show_notification(msg)
		if pl and pl.has_method("update_currency_display"):
			pl.update_currency_display()
	else:
		SpeechText.spawn(self, str(def.get("giver", "")) + "\n(" + VillagerQuests.objective_text(def) + ")")
	return true
	update_hover_panel(get_global_mouse_position())

# --- mood talk ---
# While the player stands near, every few seconds there's a 15% chance the
# villager speaks their mind. What they say comes from their live needs
# (GameState.villager_needs/morale): no job, the wrong job for their training,
# no food (Farm in ruins), nowhere to drink (no Bar), no partner -- or, when
# life is good, genuinely happy lines. Morale also scales village income.
const TALK_RANGE = 100.0
const TALK_CHANCE = 0.45
var talk_cooldown := 0.0

func tick_mood_talk(delta: float) -> void:
	talk_cooldown -= delta
	if talk_cooldown > 0.0:
		return
	talk_cooldown = randf_range(2.5, 4.0)
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or global_position.distance_to(pl.global_position) > TALK_RANGE:
		return
	if randf() < TALK_CHANCE:
		say_mood_line()

func say_mood_line() -> void:
	var lines = mood_lines()
	if lines.is_empty():
		return
	SpeechText.spawn(self, lines[randi() % lines.size()])

func mood_lines() -> Array:
	var data = find_villager_data()
	if data.is_empty():
		return []
	# Villagers can't help reacting to the deathly-pale figure their hero is
	# becoming (Shadow Monarch 4/7+, unmistakable at 5-6): fear, shyness, awe,
	# confusion. Overrides the normal mood line most of the time at those stages.
	var mstage = GameState.monarch_stage()
	if mstage >= 4 and randf() < (0.9 if mstage >= 5 else 0.4):
		return _monarch_reaction_lines()
	var n = GameState.villager_needs(data)
	var morale = GameState.villager_morale(data)
	var complaints: Array = []
	if not n.work:
		complaints += ["I need work. Anything at all...", "Idle hands, empty pockets.", "Nobody has a job for me?"]
	if not n.right_job:
		var stat = data.get("stat_name", "")
		var role = data.get("role_title", "work")
		complaints += ["I trained as a %s, yet here I am doing %s..." % [stat, role], "This isn't the work I was made for."]
	if not n.food:
		complaints += ["My stomach growls... the Farm is still rubble.", "We're going hungry. Rebuild the Farm!"]
	if not n.social:
		complaints += ["A mug and a song would fix everything... if we had a Bar.", "No Bar in this town? Grim times."]
	if not n.love:
		complaints += ["Everyone has someone... except me.", "A cottage of my own, someone to share it with..."]
	if morale >= 75 or complaints.is_empty():
		return ["Deepwood breathes again, thanks to you!", "Fine day, friend.", "Good to see you, hero!",
			"The village grows stronger every day.", "I haven't felt this hopeful in years."]
	if morale < 35:
		complaints += ["I can't take much more of this...", "This village is falling apart around us."]
	return complaints

# Reactions to the paling Shadow Monarch (afraid / shy / lost / confused / awed).
func _monarch_reaction_lines() -> Array:
	return [
		"...why is your skin so pale? Are you unwell, my lord?",
		"*takes a step back* Forgive me. You just... you feel so cold.",
		"I— I shouldn't stare. Sorry. Sorry.",
		"There's something wrong about the air around you.",
		"My little one won't stop crying whenever you pass.",
		"You saved us all... so why am I so afraid of you now?",
		"The dogs won't come near you anymore.",
		"Is it just me, or does your shadow move on its own?",
		"You've changed. I can't say how. I just... know it.",
		"*whispers to another* they say he isn't what he seems...",
		"Bless you, hero. *clutches a charm* ...bless you, truly.",
		"I mean no disrespect but... please, keep your distance.",
		"Sometimes I forget your name, then I look at you and I'm just... afraid.",
	]

# Unassigned NPCs roam the whole village; once given a role_key, they're
# confined to a small neighborhood around that specific building instead
# ("only allowed to move in their designated building" -- they don't wander
# into/near other buildings once employed).
func refresh_wander_bounds() -> void:
	var role_key = find_villager_data().get("role_key", "")
	var building = get_building_for_role(role_key) if role_key != "" else null
	if building:
		wander_min_x = building.global_position.x - BUILDING_WANDER_RADIUS
		wander_max_x = building.global_position.x + BUILDING_WANDER_RADIUS
	else:
		wander_min_x = WANDER_MIN_X
		wander_max_x = WANDER_MAX_X

func get_building_for_role(role_key: String) -> Node:
	return get_tree().get_first_node_in_group("building_role_" + role_key)

func roll_new_cycle() -> void:
	var visit_count = randi_range(MIN_VISITS_PER_CYCLE, MAX_VISITS_PER_CYCLE)
	visit_times_this_cycle = []
	for i in range(visit_count):
		visit_times_this_cycle.append(randf_range(0.0, CYCLE_LENGTH_HOURS))
	visit_times_this_cycle.sort()

# Chance that a scheduled outing goes to the Bar instead of the workplace --
# EVERY villager (employed or not) drops by the Bar now and then, it's the
# village's social heart.
const BAR_VISIT_CHANCE = 0.3

func tick_building_visits() -> void:
	var current_hours = GameState.game_hours
	var hours_passed = current_hours - last_hours_elapsed
	last_hours_elapsed = current_hours

	# countdown first so bar visits work for the unemployed too
	if is_in_building:
		hours_until_exit -= hours_passed
		if hours_until_exit <= 0:
			exit_building()
		return

	cycle_elapsed_hours += hours_passed
	if cycle_elapsed_hours >= CYCLE_LENGTH_HOURS:
		cycle_elapsed_hours = fmod(cycle_elapsed_hours, CYCLE_LENGTH_HOURS)
		roll_new_cycle()

	# a big time-skip can cross several scheduled visit times at once -- only
	# one visit can actually happen (can't be in two places at once), so
	# consume all of them but trigger a single visit.
	var visit_due = false
	while not visit_times_this_cycle.is_empty() and cycle_elapsed_hours >= visit_times_this_cycle[0]:
		visit_times_this_cycle.pop_front()
		visit_due = true
	if visit_due:
		var target = pick_visit_building()
		if target:
			enter_building_node(target)

# Workplace most of the time, the Bar sometimes; the jobless only go to the
# Bar. Only OPERATIONAL (fully built) buildings accept visitors.
func pick_visit_building() -> Node:
	var bar = get_tree().get_first_node_in_group("building_role_Bar")
	var bar_ok = bar != null and bar.is_operational()
	var role_key = find_villager_data().get("role_key", "")
	if role_key == "":
		return bar if bar_ok else null
	var work = get_building_for_role(role_key)
	var work_ok = work != null and work.is_operational()
	if bar_ok and (not work_ok or randf() < BAR_VISIT_CHANCE):
		return bar
	return work if work_ok else null

var current_visit_building: Node = null
var door_target: Node = null   # building we're walking to before slipping inside

# A visit now starts by WALKING to the building's door (see the door_target
# branch in _physics_process); the actual disappearance happens on arrival in
# _complete_enter, with the facade's door swinging open.
func enter_building_node(building: Node) -> void:
	current_visit_building = building
	door_target = building

func _complete_enter() -> void:
	var building = door_target
	door_target = null
	is_in_building = true
	hours_until_exit = randf_range(VISIT_MIN_HOURS, VISIT_MAX_HOURS)
	if building and is_instance_valid(building) and building.has_method("play_door_anim"):
		building.play_door_anim()
	visible = false
	velocity = Vector2.ZERO
	if building and is_instance_valid(building):
		global_position = building.global_position + Vector2(0.0, -4.0)

func exit_building() -> void:
	is_in_building = false
	visible = true
	var building = current_visit_building
	current_visit_building = null
	if building == null or not is_instance_valid(building):
		var role_key = find_villager_data().get("role_key", "")
		building = get_building_for_role(role_key) if role_key != "" else null
	if building and is_instance_valid(building):
		# step out through the door, not out of thin air
		if building.has_method("play_door_anim"):
			building.play_door_anim()
		global_position = building.global_position + Vector2(randf_range(-5.0, 5.0), -30.0)
	pick_new_state()

# Small info fields shared by both the Press-E notification (joined with
# " -- ") and the hover tooltip (joined with newlines) -- so both stay in
# sync automatically as villager data evolves (graduation, reassignment).
func info_fields() -> Array:
	var data = find_villager_data()
	if data.is_empty():
		return []
	var age_text = "Kid" if data.get("is_kid", false) else "Adult"
	var stat_text = data.get("stat_name", "") if data.get("stat_name", "") != "" else "no stat yet"
	var fields = [data.get("name", "?"), age_text + ", " + data.get("sex", "?"), stat_text]
	# personal spirit (5.5b): the meter is the average, but THIS number is the
	# one that corrupts or saves this particular person -- surface it, colored
	# by the glyph so a villager in the red is findable at a glance
	var spirit: float = GameState.get_personal_morale(data)
	var glyph := "☀" if spirit >= 7.0 else ("☁" if spirit >= 3.5 else "⚠")
	fields.append("%s Spirit %.1f/10" % [glyph, spirit])
	# where they sleep (5.8): home, the Tavern's spare bed, or the street
	if not data.get("is_kid", false):
		var home_id: String = GameState.villager_home_id(str(data.get("id", "")))
		if data.has("widowed_at_hours") and GameState.game_hours < float(data["widowed_at_hours"]) + GameState.WIDOW_MOURN_HOURS:
			fields.append("🖤 In mourning")
		if home_id != "":
			fields.append("⌂ " + home_id.capitalize().replace("_", " "))
		elif GameState.is_building_operational("Tavern"):
			fields.append("⌂ Lodging at the Tavern")
		else:
			fields.append("⚠ Sleeps in the street")
	if data.get("role_title", "") != "":
		fields.append("Works: " + data.get("role_title"))
	# 7.3: a warrior wears their watch -- and whether they're on it right now
	if data.get("stat_name", "") == "Warrior" or data.get("role_key", "") == "Barracks":
		var shift: String = GameState.warrior_shift(str(data.get("id", "")))
		fields.append("⚔ %s watch%s" % [shift.capitalize(), " — ON DUTY" if GameState.warrior_on_duty(data) else " — resting"])
	# the Doctor quotes her price up front -- the escalation is the mechanic,
	# so the player should never need to press E just to learn the cost
	if data.get("healer", false):
		fields.append("[E] Heal — %dg" % GameState.doctor_heal_price())
	# a trained HERO is one villager in a crowd of dozens -- wear the title, so
	# the 0.5% miracle is findable at a glance
	if data.get("hero_trained", false):
		fields.append("★ HERO of the %s" % GameState.HERO_POWERS.get(str(data.get("hero_power", "")), "Vanguard"))
	elif data.get("hero", false):
		fields.append("★ HERO-BORN — the Barracks awaits")
	fields.append_array(bond_fields(data))
	return fields

# The villager's personal bond, shown right in their hover panel: the objective
# + progress while active, "press E" when ready, or the unlocked hidden stat
# once complete.
func bond_fields(data: Dictionary) -> Array:
	var def = VillagerQuests.get_def(str(data.get("id", "")))
	if def.is_empty():
		return []
	if data.get("quest_state", "") == "done":
		if str(data.get("stat2_name", "")) != "":
			return ["♥ " + str(data.get("stat2_name")) + " +" + str(data.get("stat2_value", 0))]
		return ["♥ Bonded"]
	var pl = get_tree().get_first_node_in_group("player")
	if GameState.villager_quest_ready(data, pl):
		return ["★ " + str(def.get("title", "Bond")) + " — press E"]
	return [str(def.get("title", "Bond")) + ": " + VillagerQuests.progress_text(def, data, pl)]

func show_info() -> void:
	var fields = info_fields()
	if fields.is_empty():
		return
	# the NPC introducing themselves is speech -- floating text above their
	# head that follows them as they wander, not a corner notification
	SpeechText.spawn(self, " -- ".join(fields))

# Takes an explicit world position (rather than always reading the live
# mouse cursor) so this can be exercised directly in headless tests, where
# there is no real viewport/cursor to move.
func is_hovering(mouse_world_pos: Vector2) -> bool:
	return HOVER_BOUNDS.has_point(mouse_world_pos - global_position)

func update_hover_panel(mouse_world_pos: Vector2) -> void:
	if not hover_panel:
		return
	if is_hovering(mouse_world_pos):
		var fields = info_fields()
		if fields.is_empty():
			hover_panel.visible = false
			return
		hover_label.text = "\n".join(fields)
		hover_panel.visible = true
	else:
		hover_panel.visible = false
