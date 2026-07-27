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
# Fallback wander span, used only until the real buildings can be measured.
# These were HARDCODED at 4850..8000 while the village actually spans roughly
# 5,200..18,500 -- so villagers were fenced into the western third of their own
# town and everything east of the Bank looked deserted (dev's report). The live
# bounds are derived in _village_span() below.
const WANDER_MIN_X = 4850.0
const WANDER_MAX_X = 8000.0
const WANDER_WALL_INSET = 140.0   # ordinary villagers roam BETWEEN the two walls, kept this far off each

# The real village edges, measured from the buildings themselves (cached; the
# layout only changes when a building is relocated or a cottage is raised).
static var _span_lo := 0.0
static var _span_hi := 0.0
static var _span_count := -1

# The building cluster -- the CENTRE OF TOWN -- cached. The fallback roam band
# when the two ramparts aren't both up yet.
func _town_cluster() -> Vector2:
	var buildings := get_tree().get_nodes_in_group("building")
	if buildings.size() != _span_count:
		var lo := INF
		var hi := -INF
		for b in buildings:
			if is_instance_valid(b):
				lo = minf(lo, b.global_position.x)
				hi = maxf(hi, b.global_position.x)
		if lo == INF:
			return Vector2(WANDER_MIN_X, WANDER_MAX_X)
		_span_count = buildings.size()
		_span_lo = lo - 120.0
		_span_hi = hi + 220.0
	return Vector2(_span_lo, _span_hi)

# The band BETWEEN THE TWO RAMPARTS, inset on each side -- or ZERO if both walls
# aren't standing. Fresh each call (cheap: at most two wall nodes).
func _wall_span(inset: float) -> Vector2:
	var west_x := INF
	var east_x := -INF
	for w in get_tree().get_nodes_in_group("village_wall"):
		if not is_instance_valid(w):
			continue
		if "flank" in w and str(w.flank) == "east":
			east_x = w.global_position.x
		else:
			west_x = w.global_position.x
	if west_x != INF and east_x != -INF and east_x - west_x > 2.0 * inset + 60.0:
		return Vector2(west_x + inset, east_x - inset)
	return Vector2.ZERO

# Where an ORDINARY villager may roam: between the two walls if both stand (kept
# off each by WANDER_WALL_INSET), else the centre of town. Keeps folk INSIDE the
# village -- off the gate, out of the void.
func _village_span() -> Vector2:
	var walls := _wall_span(WANDER_WALL_INSET)
	return walls if walls != Vector2.ZERO else _town_cluster()
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
## (HOVER_BOUNDS / hover_panel / hover_label died with the hover card -- a
## villager is read through their sheet now. See the note in _process.)

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
# deal this damage (collision_layer 0); it comes from siege raiders that
# breach the walls (siege_enemy.gd targets the "npc" group via take_damage).
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
	# take_damage() below -- from breaching siege raiders (siege_enemy.gd).
	collision_layer = 0
	collision_mask = 1
	_roll_temperament()
	pick_new_state()
	build_visual()
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
# Adult on-screen height. Was 38 -- which left rescued villagers TINY beside
# the 56px player, the 64px Orin and 72px enemies (dev: "some NPCs are tiny").
# 52 reads as an ordinary adult standing just under the hero. Kids inherit
# body_scale_factor (0.65) -> ~34px, correctly child-sized.
const VILLAGER_SPRITE_H := 52.0
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
	# a grounding shadow at the feet (18*scale below origin), same as everyone
	# carries now (char_shadow.gd). Attached to self so the body_gfx rebuild
	# below never wipes it; guarded, so repeat apply_size calls don't stack it.
	preload("res://char_shadow.gd").attach(self, 0.45 * body_scale_factor, 18.0 * body_scale_factor)

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
	"Male": ["man", "man2", "man3", "man4", "man5",
		"man6", "man7", "man8", "man9", "man10", "man11", "man12", "man13"],
	"Female": ["woman", "woman2", "woman3", "woman4", "woman5",
		"woman6", "woman7", "woman8", "woman9", "woman10", "woman11", "woman12", "woman13"],
}
# Kids now have their own varied roster too (art/villagers/boy1.. / girl1..), picked
# by sex like the adults. The original single gender-neutral "kid" stays as the
# safety fallback when none of the sexed kid art is present.
const KID_VARIANTS := {
	"Male": ["boy1", "boy2", "boy3", "boy4", "boy5", "boy6", "boy7",
		"boy8", "boy9", "boy10", "boy11", "boy12", "boy13"],
	"Female": ["girl1", "girl2", "girl3", "girl4", "girl5", "girl6", "girl7",
		"girl8", "girl9", "girl10", "girl11", "girl12", "girl13"],
}
func _villager_skin(is_kid: bool, sex: String) -> String:
	var pool: Dictionary = KID_VARIANTS if is_kid else VILLAGER_VARIANTS
	var candidates: Array = pool.get(sex, pool["Female"])
	var have: Array = []
	for v in candidates:
		if EnemySkins.is_per_frame(v, VILLAGER_ROOT):
			have.append(v)
	if have.is_empty():
		return "kid" if is_kid else candidates[0]
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

# Skinned villagers pick run (fleeing) > walk (moving) > idle each frame. The new
# side-view villagers ship a run clip; the older skins don't, so run gracefully
# degrades to walk, then idle, for anyone missing the wanted animation.
func _update_villager_anim() -> void:
	if villager_sprite == null:
		return
	var sf := villager_sprite.sprite_frames
	if sf == null:
		return
	# run only while actually MOVING in panic; a cowering (stationary) villager
	# plays idle, not the run cycle jogging on the spot.
	var want := "idle"
	if is_walking:
		want = "run" if is_fleeing() else "walk"
	if not sf.has_animation(want):
		if want == "run":
			want = "walk"
		if not sf.has_animation(want):
			want = "idle"
	if sf.has_animation(want) and villager_sprite.animation != want:
		villager_sprite.play(want)

func refresh_size_if_needed() -> void:
	var data = find_villager_data()
	if data.get("is_kid", true) != last_applied_is_kid:
		apply_size()

## (build_hover_panel / update_hover_panel were removed with the hover card --
## the sheet in villager_sheet.gd replaces them. See the note in _process.)

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
# A struck villager RUNS FOR HOME (dev call 2026-07-21). They used to take a
# hit and keep ambling along their wander route as if nothing had happened.
# Now a blow sends them sprinting for the heart of the village, and they stay
# panicked for a while after the last hit.
# How far outside the village's own ground counts as "stranded", and how much
# quicker than an amble they walk when heading back to it.
const STRAY_MARGIN := 260.0
const HOMEWARD_SPEED_MULT := 1.5

const FLEE_SECONDS := 6.0

# ...AND THEY FIGHT BACK (dev request 2026-07-21: "they should go to village,
# and also defend themselves"). Running was only half of it -- a villager
# caught by something still just took the beating. These are farmers and
# fishwives, not soldiers, so this is not combat: it is a cornered person
# swinging whatever is in their hands at whatever has hold of them. Weak,
# slow, and only at arm's length. They keep running while they do it.
const DEFEND_RANGE := 52.0
const DEFEND_DAMAGE := 4
const DEFEND_COOLDOWN := 1.2
const THREAT_GROUPS := ["siege_enemy", "course_enemy", "dungeon_combatant"]
var defend_cd := 0.0
var _threat_scan_cd := 0.0   # throttle the peacetime 3-group threat scan (see _tick_defence)

func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_d := DEFEND_RANGE
	for grp in THREAT_GROUPS:
		for e in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _tick_defence(delta: float) -> void:
	if defend_cd > 0.0:
		defend_cd -= delta
		return
	# throttle the 3-group scan: in peacetime (no threat -> defend_cd never set) this ran
	# every frame on every villager for nothing. ~0.2s is plenty for a 52px defence reach.
	_threat_scan_cd -= delta
	if _threat_scan_cd > 0.0:
		return
	_threat_scan_cd = 0.2
	var threat := _nearest_threat()
	if threat == null or not threat.has_method("take_damage"):
		return
	defend_cd = DEFEND_COOLDOWN
	# face what you are hitting, then hit it
	var dx: float = threat.global_position.x - global_position.x
	if absf(dx) > 1.0:
		direction = signf(dx)
	threat.take_damage(DEFEND_DAMAGE)
	speak_or_notify(["Get BACK!", "Leave us alone!", "Not today!", "Aaagh!"][randi() % 4])
const FLEE_SPEED_MULT := 2.6
var flee_until := 0.0

# --- ALIVE, NOT ALIKE (dev 2026-07-23: "make them more alive and not lookalike") ---
# A stable per-villager TEMPERAMENT, hashed from their id so it survives reloads and
# never re-rolls: how briskly they walk, how long they linger when idle, and how far
# they like to stray from the middle of their ground. Nothing exotic -- just enough
# spread that a street of villagers stops moving like one body wearing ten skins.
var temper_speed := 1.0        # 0.85..1.2 -- amblers and striders
var temper_idle := 1.0         # 0.7..1.6  -- fidgets and lingerers
var temper_wander_bias := 0.0  # -60..60 px -- a favourite end of their ground

func _roll_temperament() -> void:
	var h := hash(villager_id if villager_id != "" else name)
	temper_speed = 0.85 + float(h % 36) / 100.0            # 0.85 .. 1.20
	temper_idle = 0.7 + float((h / 37) % 91) / 100.0       # 0.70 .. 1.60
	temper_wander_bias = float((h / 3391) % 121) - 60.0    # -60 .. +60

# ...and DANGER MAKES THEM RUN ON SIGHT (same dev note: "if attacked or see enemy
# close they run away from danger"). Being STRUCK already triggered the panic; now
# an enemy merely coming NEAR does too -- a farmer doesn't wait to be hit. Checked
# on a short throttle (not every frame): villagers are many and sieges are busy.
const SIGHT_FLEE_RANGE := 210.0
const SIGHT_CHECK_INTERVAL := 0.35
var _sight_check_cd := 0.0

# Nearest live, non-theatrical threat within `reach` px, or null. Used both to
# decide WHETHER to flee and (in the flee branch) which way is AWAY from danger.
func _nearest_threat_within(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach
	for grp in THREAT_GROUPS:
		for e in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
				continue
			# theatrical/staged raiders (the arrival tableau) scare nobody
			if "theatrical" in e and e.theatrical:
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _tick_flee_on_sight(delta: float) -> void:
	_sight_check_cd -= delta
	if _sight_check_cd > 0.0:
		return
	_sight_check_cd = SIGHT_CHECK_INTERVAL
	# REFRESH the panic every check while a raider is still in sight -- previously
	# this bailed the moment is_fleeing() was true, so the 6s timer ran out with the
	# enemy still right there and the villager lapsed back into a calm pace (the
	# "back and forth like an npc" the dev flagged 2026-07-25). Now the fright holds
	# as long as danger is visible.
	var was_fleeing := is_fleeing()
	if _nearest_threat_within(SIGHT_FLEE_RANGE) != null:
		flee_until = Time.get_ticks_msec() / 1000.0 + FLEE_SECONDS
		if not was_fleeing and randf() < 0.6:
			speak_or_notify(["RUN!", "They're here!", "Get inside!", "Look out!"][randi() % 4])

func is_fleeing() -> bool:
	return Time.get_ticks_msec() / 1000.0 < flee_until

func take_damage(amount: int) -> void:
	if is_in_building:
		return
	# panic first -- even a survivable hit sends them running
	flee_until = Time.get_ticks_msec() / 1000.0 + FLEE_SECONDS
	health -= amount
	if health <= 0:
		# THE UNBREAKABLES CANNOT BE BROKEN. Every other loss path (sieges, rot,
		# infection, the Harvest, random deaths) already exempts the Ten -- this
		# was the one that didn't, so a wall-breach raider or street demon could
		# permanently erase a freed legend in about five hits. They are beaten to
		# the door of death and no further: pinned at 1 HP, still fleeing.
		if bool(find_villager_data().get("unbreakable", false)):
			health = 1
		else:
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
	# THE SICK ROAD: a hurt villager wears it -- a pale, blood-drained tint laid
	# over the normal look (the rot pulse above still wins) so the wounded read at
	# a glance as they limp toward the Hospital, and lose it once mended.
	if body_gfx and _is_wounded():
		body_gfx.modulate = Color(0.95, 0.78, 0.78)

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

# (Peer separation was REMOVED 2026-07-23 on dev's call: "every NPC passes through
# each other like the player, no collision." Villagers overlap and pass through each
# other freely -- collision_layer 0 already means they never physically collide, and
# we no longer shove them apart either. Their own wander sends them to their own
# spots, so they read as a crowd rather than a single glued blob.)

func _physics_process(delta: float) -> void:
	if is_in_building:
		velocity = Vector2.ZERO
		return
	# indoors is safe; out here, anything that gets its hands on you gets hit
	_tick_defence(delta)
	# ...and anything merely SEEN coming sends them running (flee on sight)
	_tick_flee_on_sight(delta)

	# Fleeing overrides every errand: a spooked villager on a routine Bar/workplace
	# visit DROPS it rather than calmly marching to the door through raiders (dev
	# 2026-07-25 "smarter npc"). Care trips are cancelled just below; this catches
	# ordinary visits, whose door_target used to survive and be walked in the branch
	# further down BEFORE the flee branch ever ran.
	if is_fleeing() and door_target != null and not _care_visit:
		door_target = null
		current_visit_building = null
	# THE SICK ROAD: a wounded villager breaks off for the nearest Hospital.
	# Fleeing always wins -- a threat mid-trek cancels the trip; otherwise, when
	# idle and hurt, set out (this sets door_target, and the branch below walks it).
	if _care_visit and (is_fleeing() or GameState.live_siege_active):
		_cancel_care()
	elif door_target == null and not is_in_building and not is_fleeing():
		_try_seek_care()

	# En route to a building visit: march straight to the door, then slip in.
	if door_target != null:
		if not is_instance_valid(door_target):
			# the target building was freed mid-walk (e.g. the Hospital was razed). Clear
			# the care flag too, else _try_seek_care stays blocked and the villager never
			# seeks another ward until an unrelated flee/siege resets it.
			if _care_visit:
				_cancel_care()
			else:
				door_target = null
		else:
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			var door_dx = door_target.global_position.x - global_position.x
			if absf(door_dx) < 8.0:
				_complete_enter()
				return
			direction = 1 if door_dx > 0.0 else -1
			# THE SICK ROAD: a wounded villager LIMPS to the Hospital -- slower, the
			# bad leg barely lifting, with a downward hitch each step, so you can read
			# the hurt heading for care at a glance.
			var hurt: bool = _care_visit and _is_wounded()
			velocity.x = direction * SPEED * (0.6 if hurt else 1.0)
			# A villager sent to their building keeps whatever walk/idle state the
			# wander AI last picked, so anyone summoned mid-idle marched to the
			# door playing their IDLE animation -- sliding along like a statue on
			# rails. They are, self-evidently, walking.
			is_walking = true
			if body_gfx:
				body_gfx.scale.x = direction * body_scale_factor
			_update_villager_anim()
			walk_anim_t += delta * (5.5 if hurt else 9.0)
			var door_swing = sin(walk_anim_t)
			if l_leg:
				l_leg.rotation = door_swing * (0.25 if hurt else 0.5)   # bad leg drags
				r_leg.rotation = -door_swing * 0.5
				l_arm.rotation = -door_swing * 0.42
				r_arm.rotation = door_swing * 0.42
			if body_gfx:
				body_gfx.position.y = 18.0 * body_scale_factor + (absf(sin(walk_anim_t)) * 2.4 * body_scale_factor if hurt else 0.0)
			move_and_slide()
			return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# PANIC (smarter 2026-07-25: dev "make them a smarter npc"): a spooked villager
	# sprints directly AWAY from the nearest raider toward the safe interior -- NOT
	# toward a fixed town-centre that might sit past the enemy, which is what made
	# them jog back and forth into the very thing chasing them. Pinned against the
	# far edge with nowhere left to run, they cower STILL (idle), not jog on the spot.
	if is_fleeing():
		var span := _village_span()
		var threat := _nearest_threat_within(SIGHT_FLEE_RANGE * 1.5)
		var away := 0.0
		if threat != null:
			away = signf(global_position.x - threat.global_position.x)
		if away == 0.0:                          # no threat located / dead-on: fall back to the interior
			away = signf((span.x + span.y) * 0.5 - global_position.x)
		if away == 0.0:
			away = 1.0
		var target_x: float = clampf(global_position.x + away * 260.0, span.x, span.y)
		if absf(target_x - global_position.x) > 6.0:
			direction = signf(target_x - global_position.x)
			velocity.x = direction * SPEED * FLEE_SPEED_MULT
			is_walking = true
			if body_gfx:
				body_gfx.scale.x = direction * body_scale_factor
			_update_villager_anim()
			walk_anim_t += delta * 15.0        # frantic stride
			var flee_swing := sin(walk_anim_t)
			if l_leg:
				l_leg.rotation = flee_swing * 0.7
				r_leg.rotation = -flee_swing * 0.7
				l_arm.rotation = -flee_swing * 0.6
				r_arm.rotation = flee_swing * 0.6
			move_and_slide()
			return
		velocity.x = 0.0                        # cornered at the edge -- cower, don't jog on the spot
		is_walking = false
		if l_leg:
			l_leg.rotation = lerpf(l_leg.rotation, 0.0, 0.3)
			r_leg.rotation = lerpf(r_leg.rotation, 0.0, 0.3)
			l_arm.rotation = lerpf(l_arm.rotation, 0.0, 0.3)
			r_arm.rotation = lerpf(r_arm.rotation, 0.0, 0.3)
		_update_villager_anim()
		move_and_slide()
		return

	# STRANDED VILLAGERS WALK HOME (dev report 2026-07-21: "good NPC are not
	# walking to village"). The wander below only TURNS at its bounds and idles
	# half the time, so a villager left out on the road -- by a story beat that
	# moved them, or a siege that scattered them -- would drift back over
	# several minutes of stop-start ambling, if at all. Outside their ground
	# they now simply head for it, purposefully, without pausing to idle.
	var span_home := _village_span()
	if global_position.x < span_home.x - STRAY_MARGIN or global_position.x > span_home.y + STRAY_MARGIN:
		var target: float = clampf(global_position.x, span_home.x, span_home.y)
		direction = signf(target - global_position.x)
		velocity.x = direction * SPEED * HOMEWARD_SPEED_MULT
		is_walking = true
		if body_gfx and direction != 0:
			body_gfx.scale.x = direction * body_scale_factor
		_update_villager_anim()
		walk_anim_t += delta * 10.0
		var home_swing := sin(walk_anim_t)
		if l_leg:
			l_leg.rotation = home_swing * 0.55
			r_leg.rotation = -home_swing * 0.55
			l_arm.rotation = -home_swing * 0.45
			r_arm.rotation = home_swing * 0.45
		move_and_slide()
		return

	state_timer -= delta
	if state_timer <= 0:
		pick_new_state()

	if is_walking:
		if global_position.x <= wander_min_x:
			direction = 1
		elif global_position.x >= wander_max_x:
			direction = -1
		velocity.x = direction * SPEED * temper_speed   # amblers and striders
		if body_gfx and direction != 0:
			body_gfx.scale.x = direction * body_scale_factor
		# simple walk cycle: arm swings forward while the opposite leg swings back
		walk_anim_t += delta * 9.0 * temper_speed
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
			speak_or_notify(lines[randi() % lines.size()])

func pick_new_state() -> void:
	if is_walking:
		is_walking = false
		# temperament: fidgets barely pause, lingerers people-watch a while
		state_timer = randf_range(MIN_IDLE_SECONDS, MAX_IDLE_SECONDS) * temper_idle
	else:
		is_walking = true
		# lean toward their favourite end of the ground, not a pure coin flip
		var mid: float = (wander_min_x + wander_max_x) * 0.5 + temper_wander_bias
		var toward_favourite := -1 if global_position.x > mid else 1
		direction = toward_favourite if randf() < 0.65 else -toward_favourite
		state_timer = randf_range(MIN_WALK_SECONDS, MAX_WALK_SECONDS)

var _vd_cache: Dictionary = {}
var _vd_cache_at := 0.0

func find_villager_data() -> Dictionary:
	# cached REFERENCE, re-resolved twice a second (audit fix): three per-frame
	# helpers each walked the whole roster per avatar -- O(avatars x roster)
	# work every frame in a big village. Dictionaries are references, so the
	# cached entry stays live; the re-resolve only covers removal/re-add.
	var now := Time.get_ticks_msec() / 1000.0
	if _vd_cache.is_empty() or now - _vd_cache_at > 0.5:
		_vd_cache_at = now
		_vd_cache = {}
		for v in GameState.rescued_villagers:
			if v.get("id") == villager_id:
				_vd_cache = v
				break
	return _vd_cache

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _process(delta: float) -> void:
	# NO MORE MOUSE HOVER (dev call 2026-07-27). Reading a villager used to mean
	# holding the cursor over them for a 182px card that was too small for its
	# own contents and got sat on by their speech bubble. Their sheet now opens
	# from the right-click menu instead (villager_menu.gd -> villager_sheet.gd),
	# which has room for every line and takes their voice while it is open.
	refresh_size_if_needed()
	update_health_bar_display(delta)
	apply_despair_visual()
	refresh_wander_bounds()
	tick_building_visits()
	if is_in_building:
		return
	if player_inside and Input.is_action_just_pressed("interact"):
		if not try_doctor_heal() and not try_bond_interaction():
			maybe_recount_news()   # no far-feed? then ask the people who were here
			show_info()
	tick_mood_talk(delta)

# "Ask the villagers what happened while you were gone" (dev ask 2026-07-22): the
# fallback for a player with NO live feed (no Whisperstone, no Telepathy rune) --
# each soul you ask recounts a RANDOM recent entry from the town's diary, so
# asking around is how you piece together the days you missed.
func maybe_recount_news() -> void:
	if GameState.has_communicator() or GameState.has_telepathy():
		return   # you already heard it all live
	if GameState.village_log.is_empty():
		return
	var recent: Array = GameState.village_log.slice(0, min(6, GameState.village_log.size()))
	var e = recent[randi() % recent.size()]
	speak_or_notify("You were gone, but —\n" + str(e.get("text", "...")))

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
		speak_or_notify(line if line != "" else "Thank you.")
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
		speak_or_notify(str(def.get("giver", "")) + "\n(" + VillagerQuests.objective_text(def) + ")")
	return true

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
	speak_or_notify(lines[randi() % lines.size()])

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
	var data := find_villager_data()
	# WARRIORS ARE NOT PENNED IN (dev 2026-07-24): they must be free to answer an
	# invasion and hold the wall, so they range the full wall-to-wall defensive
	# band -- never the tight workplace neighbourhood nor the inset villager band.
	if GameState.is_warrior_villager(data):
		var wspan := _wall_span(0.0)
		if wspan == Vector2.ZERO:
			wspan = _town_cluster()
		wander_min_x = wspan.x
		wander_max_x = wspan.y
		return
	var role_key = str(data.get("role_key", ""))
	var building = get_building_for_role(role_key) if role_key != "" else null
	if building:
		wander_min_x = building.global_position.x - BUILDING_WANDER_RADIUS
		wander_max_x = building.global_position.x + BUILDING_WANDER_RADIUS
	else:
		# stay INSIDE the village: between the walls if both stand, else the centre
		var span := _village_span()
		wander_min_x = span.x
		wander_max_x = span.y

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
		# Sick Road: a patient mends over time while inside, faster the better the
		# ward is staffed; discharged the moment they're whole (or when the visit
		# cap runs out, so even a slow ward eventually releases them).
		if _under_treatment:
			_tick_treatment(hours_passed)
			return
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
	if visit_due and not _care_visit:   # a Sick Road trip outranks a routine visit
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
var _care_visit := false        # true while this trip is a Sick Road walk to the Hospital
var _under_treatment := false   # true while admitted, mending over time inside the Hospital
const CARE_HP_THRESHOLD := 0.5  # wounded below half health -> break off and seek the Hospital

# A visit now starts by WALKING to the building's door (see the door_target
# branch in _physics_process); the actual disappearance happens on arrival in
# _complete_enter, with the facade's door swinging open.
func enter_building_node(building: Node) -> void:
	current_visit_building = building
	door_target = building

# --- THE SICK ROAD (expansion 2026-07-24) --------------------------------------
# A wounded villager breaks off and WALKS to the nearest operational Hospital to
# be treated, then returns to life. The cost is the walk itself: a Hospital near
# where people get hurt (the Barracks, the homes) means quick recovery; one
# across town means a long, exposed trek. Reuses the door_target walk-and-enter
# rail; healing lands on arrival, in _complete_enter.
func _is_wounded() -> bool:
	return GameState.get_villager_hp(villager_id) < GameState.VILLAGER_MAX_HP * CARE_HP_THRESHOLD

func _nearest_hospital() -> Node:
	var best: Node = null
	var best_d := 1.0e12
	for h in get_tree().get_nodes_in_group("building_role_Hospital"):
		if is_instance_valid(h) and h.has_method("is_operational") and h.is_operational():
			var d: float = absf(h.global_position.x - global_position.x)
			if d < best_d:
				best_d = d
				best = h
	return best

# Begin a Sick Road trip if hurt and a working Hospital stands. Returns true if
# one started. With no operational Hospital it does nothing (the slow passive
# regen does what it can).
func _try_seek_care() -> bool:
	# only once the DANGER has passed: no villager limps out to the ward mid-siege
	# -- they hide until the wall's defenders and the player clear the wave (and
	# live_siege_active flips false the instant the last raider falls)
	if _care_visit or is_in_building or GameState.live_siege_active or not _is_wounded():
		return false
	var hosp := _nearest_hospital()
	if hosp == null:
		return false
	current_visit_building = hosp
	door_target = hosp
	_care_visit = true
	return true

func _cancel_care() -> void:
	_care_visit = false
	door_target = null
	current_visit_building = null

# One tick of Hospital treatment while admitted (Sick Road). Heals toward full at
# the ward's staffed rate; discharges on full health, or breaks off if the ward
# was razed out from under them mid-treatment.
func _tick_treatment(hours_passed: float) -> void:
	var b = current_visit_building
	if b == null or not is_instance_valid(b) or (b.has_method("is_operational") and not b.is_operational()):
		_under_treatment = false
		exit_building()
		return
	var hp: float = GameState.get_villager_hp(villager_id)
	hp = minf(GameState.VILLAGER_MAX_HP, hp + hours_passed * GameState.hospital_treat_rate())
	if hp >= GameState.VILLAGER_MAX_HP:
		GameState.villager_hp.erase(villager_id)   # made whole -> discharged
		_under_treatment = false
		if b and is_instance_valid(b):
			FloatingText.spawn_word(b.get_parent(), b.global_position + Vector2(0.0, -92.0), "♥", Color(0.72, 1.0, 0.78))
		exit_building()
		return
	GameState.villager_hp[villager_id] = hp
	if hours_until_exit <= 0:                        # visit-cap safety release
		_under_treatment = false
		exit_building()

func _complete_enter() -> void:
	var building = door_target
	var was_care := _care_visit
	_care_visit = false
	door_target = null
	is_in_building = true
	hours_until_exit = randf_range(VISIT_MIN_HOURS, VISIT_MAX_HOURS)
	# Sick Road: arriving wounded doesn't snap you whole -- you're admitted, and
	# mend OVER TIME while inside (see _tick_treatment), faster the better the ward
	# is staffed. The walk was the cost of getting here; the stay is the cost of
	# how well you built and staffed the Hospital.
	if was_care:
		_under_treatment = true
		# a care symbol rises over the ward as the patient is admitted
		if building and is_instance_valid(building):
			FloatingText.spawn_word(building.get_parent(), building.global_position + Vector2(0.0, -92.0), "✚", Color(0.6, 0.95, 0.72))
	if building and is_instance_valid(building) and building.has_method("play_door_anim"):
		building.play_door_anim()
	visible = false
	velocity = Vector2.ZERO
	if building and is_instance_valid(building):
		global_position = building.global_position + Vector2(0.0, -4.0)

func exit_building() -> void:
	is_in_building = false
	_under_treatment = false
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
		# feet on the DOORSTEP, not above it: this collision box is centred on the
		# origin, so standing means 18*scale below it -- the old flat -30 left them
		# a dozen pixels in the air (invisible while the world runs, but a villager
		# stepping out during a paused cutscene would just hang there)
		global_position = building.global_position \
			+ Vector2(randf_range(-5.0, 5.0), -18.0 * body_scale_factor)
	pick_new_state()

# Small info fields shared by both the Press-E notification (joined with
# " -- ") and the hover tooltip (joined with newlines) -- so both stay in
# sync automatically as villager data evolves (graduation, reassignment).
func info_fields() -> Array:
	var data = find_villager_data()
	if data.is_empty():
		return []
	var age_text = "Kid" if data.get("is_kid", false) else "Adult"
	# the stat with its VALUE -- "Farm 4", not just "Farm" (live playtest:
	# "they don't really show their stats")
	var stat_text := "no talent yet"
	if str(data.get("stat_name", "")) != "":
		stat_text = "%s %d" % [str(data.get("stat_name")), int(data.get("stat_value", 0))]
	# 4.2a: a crystal-freed hostage stays WRAPPED until the thaw at home
	if data.get("stats_hidden", false):
		stat_text = "— still thawing —"
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
	speak_or_notify(" -- ".join(fields))

# ONE MOUTH, TWO PLACES (dev call 2026-07-27: "if npc talks at the same time as
# player is checking their stats, 2 texts are overlaid"). While this villager's
# sheet is open their words are printed INSIDE it; otherwise they float over
# their head as before. Either way a line is never drawn on top of their stats.
func speak_or_notify(line: String) -> void:
	var sheet := open_sheet()
	if sheet != null:
		sheet.show_speech(line)
		return
	SpeechText.spawn(self, line)

# This villager's stat sheet, if the player has it open right now.
func open_sheet() -> Node:
	for s in get_tree().get_nodes_in_group("villager_sheet"):
		if is_instance_valid(s) and str(s.villager_id) == str(villager_id):
			return s
	return null

# Right-click near this villager opens their menu (see villager_menu.gd). Driven
# from player.gd so the same click can't also fire the player's off-hand attack.
func open_menu() -> void:
	load("res://villager_menu.gd").open_for(self, self)
