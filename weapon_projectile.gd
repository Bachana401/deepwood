extends Area2D

# One configurable projectile powering the special-attack weapons (see
# player.gd launch_projectile + the "special" dicts in inventory.gd). Kinds:
#   slash       -- a flying wind-crescent that pierces everyone in its path
#   javelin     -- a hurled spectral spear, also piercing
#   fireball    -- explodes in an AoE on the first hit (or at max range)
#   frost_shard -- fast piercing ice sliver
#   hook        -- drags the first enemy struck back to the player's feet
#   boomerang   -- flies out, turns, and comes back: hits on BOTH passes
#
# Area2D (not a body) so it sails over terrain; enemies are found the same
# way the player's arrows find them (collision_mask 4 + take_damage check).
# All visuals are procedural polygons, self-cleaning on despawn.

var kind := "slash"
var girth := 1.0            # scales the HITBOX (and, gently, the drawing)
var _draw_girth := 1.0      # what the eye gets: see the note in _ready()
var element := "physical"   # the caster weapon's element (VFX pass): hit bursts pop in its colour
var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10
var max_distance := 450.0
var pierce := false
var aoe_radius := 0.0
var knockback := 40.0
var is_crit := false        # set by the player when it rolls a crit
var on_hit_status := {}     # {"kind","dur","mag"} applied to enemies on hit
var source: Node2D = null   # the player (hook pull target / boomerang home)
var from_wand := false      # set by player.launch_projectile for true wand casts (Stillness)
var rider := ""             # flagship bespoke behavior (The Rumor "grows", ...)
var _borrowed := false      # A Borrowed Star: the apex split fires only once

func _apply_status_to(node) -> void:
	# element impact burst (VFX pass): every landed projectile pops in colour
	if node is Node2D and not node.is_in_group("player"):
		HitFx.burst(get_parent(), (node as Node2D).global_position, element, is_crit)
	if not on_hit_status.is_empty() and node.has_method("apply_status"):
		node.apply_status(str(on_hit_status.get("kind","burn")), float(on_hit_status.get("dur",3.0)), float(on_hit_status.get("mag",0.0)))
	# Stillness (Wukong road): a wand bolt may carry the stopping word --
	# 12% to hold a NON-boss perfectly still. Bosses shrug the word off.
	if from_wand and node.has_method("apply_status") and not ("boss_id" in node) \
			and GameState.get_bonus_total("stillness") > 0.0 and randf() < 0.12:
		node.apply_status("freeze", 2.5, 0.0)
		if node is Node2D:
			SfxSynth.play_at(self, (node as Node2D).global_position, "chime", -12.0)
	# Elementalist Wildfire / Cataclysm: the burn you just applied leaps to any
	# foes crowded around the one you struck.
	if GameState.get_bonus_total("combustion") > 0.0 and is_instance_valid(node):
		var mag = GameState.get_bonus_total("on_hit_burn")
		if mag <= 0.0:
			mag = 6.0
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if e == node or not is_instance_valid(e) or not e.has_method("apply_status"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if node.global_position.distance_to(e.global_position) <= 110.0:
					e.apply_status("burn", 3.0, mag)

var beam_tint := Color(0, 0, 0, 0)   # slash: a weapon may colour its crescent
var _mark: Node2D = null             # marcher: the one it was called for
var _lash_len := 0.0                 # edict_lash: how far the law currently reaches
var _lash_t := 0.0
var _lash_line: Line2D = null
var _lash_hits := {}                 # instance_id -> next time this body may be cut again
var court_index := 0                 # courtier: which ancestor tint this shade wears
var court_target := Vector2.ZERO     # courtier: ITS OWN mark (the court spreads out)
var _zen_start := Vector2.ZERO       # zenith_blade: the three-phase swoop
var _zen_target := Vector2.ZERO
var _zen_tint := Color.WHITE
static var _zenith_cycle := 0        # each swing cycles the ancestor tints
var traveled := 0.0
var returning := false      # boomerang/lash: on the way back
var done := false
var hit_bodies: Array = []
var visual: Node2D = null
var spin_speed := 0.0
var rope: Line2D = null     # hook: drawn back to the thrower

# --- the wave-1 behavior library (Terraria-INSPIRED, never 1:1; weapons
# overhaul 2026-07-28). Five new kinds join the six above:
#   orbiter  -- a soulthread charm: flies out, then SPINS at the far point
#               striking everything around it, then threads home (yoyo-kin)
#   ricochet -- leaps enemy to enemy, damage decaying each bounce
#   cluster  -- bursts into a fan of shards on its first kill or at range
#   lob      -- a mortar arc: rises, falls, and BLOSSOMS where it lands
#   lash     -- a piercing ribbon that weaves out and whips back through
#               the same lane, hitting on both passes (eruption-kin)
var dwell := 2.2            # orbiter: seconds it spins at the far point
var bounces := 3            # ricochet: enemy-to-enemy leaps
var shards := 5             # cluster: children in the burst
var arc_gravity := 620.0    # lob: the mortar's pull
var _vel_y := 0.0           # lob: vertical velocity
var _start_y := 0.0         # lob: the launch height (landing detector)
var _orbit_centre := Vector2.ZERO
var _orbit_t := 0.0
var _behave_state := 0      # orbiter: 0 fly out, 1 spin, 2 thread home
var _rehit_t := 0.0         # orbiter/lash: clears the hit list to strike again

const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]
const EMBEDDED_STACK = preload("res://embedded_stack.gd")

func _ready() -> void:
	# findable in flight, so a mirror boss has something to reflect (boss.gd
	# tick_mirror). Without this the mechanic is a silent no-op.
	add_to_group("player_projectile")
	collision_layer = 0
	collision_mask = 4   # enemy layer, same as the player's arrows target
	monitoring = true
	z_index = 40
	var cs = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	# girth scales the projectile as a whole -- the drawn shape AND what it can
	# hit -- so a mythic crescent is genuinely a wall of force sweeping the room
	# rather than a small sprite that merely looks impressive.
	shape.size = Vector2(36, 20) * girth
	# Terra standard: the wind-crescent is TALL now, and its reach must be
	# honest about it; the zenith image is a whole blade
	if kind == "slash":
		shape.size = Vector2(38, 46) * girth
	elif kind == "zenith_blade":
		shape.size = Vector2(44, 44) * girth
	elif kind == "courtier":
		shape.size = Vector2(40, 40) * girth
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	visual = Node2D.new()
	# The HITBOX takes girth in full (late-game weapons stay forgiving to land),
	# but the DRAWN size grows far more gently. Those were one number, and it
	# stacked with WeaponFx._gscale until a crown arrow drew at 5.6 player-
	# heights -- the dev's "sizes are still big". Hitbox slightly larger than
	# the image is the friendly direction for the mismatch to run.
	_draw_girth = 1.0 + (girth - 1.0) * 0.32
	visual.scale = Vector2.ONE * _draw_girth
	add_child(visual)
	match kind:
		"soul_split": _build_soulbolt()
		"slash": _build_slash()
		# ---- T6 batch 1 ----
		"late_thunder": _build_late_thunder()
		"eclipse_disc":
			# it must SURVIVE the row to reach its eclipse point -- without
			# this the generic hit path ate the disc on the first body it
			# touched and the whole verb never happened (film caught it)
			pierce = true
			_build_eclipse_disc()
		"comet": _build_comet()
		"cinder_patch": _build_cinder_patch()
		"cinder_drag": _build_chainmaul()
		"watch_fire": _build_watch_fire()
		"debt_mark": _build_debt_mark()
		# ---- T6 batch 2 ----
		"stage_pike": _build_stage_pike()
		"flood_wave":
			pierce = true
			_build_flood_wave()
		"lodestar": _build_lodestar()
		"moon_orbit":
			pierce = true
			_build_moon_orbit()
		"glass_note": _build_glass_note()
		"long_tongue":
			pierce = true
			_build_long_tongue()
		# ---- T6 batch 3 ----
		"anvil_toll": _build_anvil_toll()
		"rend_half":
			pierce = true
			_build_rend_half()
		"sun_piece": _build_sun_piece()
		"ice_sheet": _build_ice_sheet()
		"silent_note": _build_silent_note()
		"nova_seed": _build_nova_seed()
		# ---- T6 batch 4: the last ten ----
		"hollow_wheel":
			pierce = true
			_build_hollow_wheel()
		"portent": _build_portent()
		"courier_route":
			pierce = true
			_build_courier()
			_cour_next()
		"stoop_arrow": _build_stoop_arrow()
		"quill_fall": _build_quill()
		"ash_cloud": _build_ash_cloud()
		"cinder_shelf": _build_cinder_shelf()
		"grief_return":
			pierce = true
			_build_grief_return()
		"night_lash":
			pierce = true
			_build_night_lash()
		"noon_shaft": _build_noon_shaft()
		# ---- T5 batch 1 ----
		"sea_wall":
			pierce = true
			_build_sea_wall()
		"serpent_coil": _build_serpent_coil()
		"twin_bolt":
			pierce = true
			_build_twin_bolt()
		"deep_beacon": _build_deep_beacon()
		"star_fall": _build_star_fall()
		"under_toll":
			pierce = true
			_build_under_toll()
		# ---- T5 batch 2 ----
		"ice_floe":
			pierce = true
			_build_ice_floe()
		"owl_pass":
			pierce = true
			_build_owl_pass()
		"rain_quill": _build_rain_quill()
		"ransom_seal": _build_ransom_seal()
		"gallows_head": _build_chainmaul()
		"pilgrim_lash":
			pierce = true
			_build_pilgrim_lash()
		# ---- T5 batch 3 ----
		"zenith_storm":
			pierce = true
			_build_zenith_storm()
		# ---- the monarch eleven ----
		"patient_storm":
			pierce = true
			_build_patient_storm()
		"kingdom_ring":
			pierce = true
			_build_kingdom_ring()
		"rumor_bolt": _build_rumor_bolt()
		"sky_measure": _build_sky_measure()
		"colonnade": _build_colonnade()
		"harmonic": _build_harmonic()
		"harp_string": _build_harp()
		"grief_tear": _build_grief_tear()
		"sky_charge": _build_sky_charge()
		"world_cut":
			pierce = true
			_build_world_cut()
		# ---- T4 batch 1 ----
		"howl_crescent":
			pierce = true
			_build_howl_crescent()
		"frost_roller":
			pierce = true
			_build_frost_roller()
		"reaper_return":
			pierce = true
			_build_reaper_return()
		"prism_bolt": _build_prism_bolt()
		"comet_chain": _build_chainmaul()
		"oath_arrow": _build_stoop_arrow()
		# ---- T5 batch 4: the last eleven ----
		"omen_eye":
			pierce = true
			_build_omen_eye()
		"omen_sigil": _build_omen_sigil()
		"iron_spike": _build_iron_spike()
		"kestrel": _build_kestrel()
		"thunderhead":
			pierce = true
			_build_thunderhead()
		"midnight_post":
			pierce = true
			_build_midnight_post()
		"siren_song":
			pierce = true
			_build_siren_song()
		"star_splinter":
			pierce = true
			_build_star_splinter()
		"ember_hymn":
			pierce = true
		"saint_halo":
			pierce = true
			_build_saint_halo()
		"quiet_wheel":
			pierce = true
			_build_quiet_wheel()
		"winter_wheel":
			pierce = true
			_build_winter_wheel()
		"sky_quill": _build_sky_quill()
		"eventide":
			pierce = true
			_build_eventide()
		"rain_cloud":
			pierce = true
			_build_rain_cloud()
		"warden_post": _build_warden_post()
		"zenith_blade":
			# THE LAST WORD: a ghost-image of an ancestor blade. Swoops out,
			# whirls one tight loop at the far point, and comes home. Each
			# swing wears the next tint in the culminated line.
			pierce = true
			_zenith_cycle = (_zenith_cycle + 1) % WeaponFx.LEGACY_TINTS.size()
			_zen_tint = WeaponFx.LEGACY_TINTS[_zenith_cycle]
			_zen_start = global_position
			# the image flies to where the FIGHT is: the nearest living thing
			# ahead of the swing (Zenith flies to the cursor; an aim-direction
			# game sends it to the foe instead), else a half-range point
			_zen_target = global_position + direction * max_distance * 0.5
			var zprey := _nearest_hostile_node(max_distance * 0.8)
			if zprey != null and (zprey.global_position - global_position).dot(direction) > 0.0:
				_zen_target = zprey.global_position
			_behave_state = 0
			_orbit_t = 0.0
			_build_zenithblade()
		"tether_arrow":
			# HEAVENSTRING (T7): the shaft trails a thread of light, and when
			# it lands the thread goes TAUT -- what it hit comes to you.
			_build_tether_arrow()
		"choir_note":
			# CHOIRSTRING (T7): each shaft that lands plants a NOTE, and notes
			# left standing near each other hum together.
			monitoring = false
			pierce = true
			_build_choir_note()
		"piercing_point":
			# THE HEAVEN-PIERCING POINT (T7): one lance, and everything in the
			# line takes the SAME wound. The study's even-pierce family, which
			# feels nothing like the stepped-falloff kind.
			pierce = true
			_build_piercing_point()
		"asphodel_post":
			# ASPHODEL POST (T7): a planted marker that sends wisps out on its
			# own, slowly, for as long as it stands.
			monitoring = false
			_build_asphodel_post()
		"rift_bloom":
			# RIFTBURST ROD (T7): the bolt does not explode, it OPENS. A tear
			# hangs there hauling everything toward its middle, and then it
			# shuts -- and shutting is the damage.
			monitoring = false
			pierce = true
			_build_rift()
		"regent_shard":
			# THE SHARD REGENT (T7): the shards do not leave at once. They
			# crown the caster first, then go one after another.
			pierce = true
			_build_regent_shard()
		"bent_ray":
			# HEAVEN, BENT (T7): the beam does not go straight. It climbs over
			# whatever is between and comes down on the far side.
			pierce = true
			_build_bent_ray()
		"sky_pillar":
			# PILLAR OF THE SKY (T7): a column of daylight standing where you
			# pointed. It does not travel; it simply IS there, and briefly.
			monitoring = false
			pierce = true
			_build_sky_pillar()
		"commandment":
			# THE NINTH COMMANDMENT (T7): the ninth shot is not an arrow, it is
			# a RULING -- one heavy bolt that goes through everything.
			pierce = true
			_build_commandment()
		"world_edge":
			# EDGE OF THE WORLD (T7): the cut WIDENS as it goes. It leaves the
			# blade as a sliver and arrives as a horizon.
			pierce = true
			_build_slash()
		"rising_wheel":
			# WHEEL OF ASCENSION (T7): the wheel does not orbit, it CLIMBS --
			# spinning upward and taking whatever it catches with it.
			pierce = true
			spin_speed = 13.0
			_build_rising_wheel()
		"debt_arrow":
			# THE QUIET RECKONING (T7): the arrow barely stings. It stays in
			# you, and a second and a half later the reckoning arrives
			# (Nail-Gun-kin: small now, ~7x later, and the WAITING is legible).
			_build_debt_arrow()
		"storm_bird":
			# FLOCK OF STORMS (T7): each jab looses a bird that turns and dives
			_build_storm_bird()
		"dawn_line":
			# DAWN CHORUS (T7): a bar of first light laid on the floor that
			# RISES through whatever is standing in it.
			monitoring = false
			pierce = true
			_build_dawn_line()
		"lingering_arc":
			# AFTERLIGHT (T7): the swing does not end. A blade-shaped light
			# hangs where it passed and keeps cutting whatever walks into it.
			monitoring = false
			pierce = true
			_build_lingering_arc()
		"anvil_drop":
			# ANVIL OF ENDINGS (T7): the ending arrives a beat LATE -- a mass
			# falls out of the dark onto the place you struck.
			monitoring = false
			_build_anvil()
		"ground_thorn":
			# THORN OF THE WORLD (T7): the thrust wakes the ground; thorns come
			# up where the point went in (Blood-Thorn-kin, never 1:1).
			monitoring = false
			pierce = true
			_build_ground_thorn()
		"sun_pool":
			# SUNSPILL (T7): what it throws does not explode, it SPILLS -- a
			# burning pool that stays and punishes standing still.
			monitoring = false
			pierce = true
			_build_sun_pool()
		"kneeling_stone":
			# THE MOUNTAIN THAT KNEELS: a boulder that rolls, follows the slope,
			# and hits for whatever pace it has gathered (Staff-of-Earth-kin)
			pierce = true
			_build_boulder()
		"marcher":
			# NIGHT PARADE: one of the procession, walked in from off-camera
			pierce = false
			_build_marcher()
			modulate.a = 0.0
			var mt := create_tween()
			mt.tween_property(self, "modulate:a", 1.0, 0.25)
		"sunder_wave":
			# GRIEF WEARS A CROWN: the blow lands and the GROUND carries it --
			# a front that runs outward through rock, taking each body once as
			# it passes (Golem-Fist-kin, never 1:1). No collision body: a wave
			# is not a projectile and must not stop at the first thing it meets.
			monitoring = false
			pierce = true
			_build_sunder()
		"grief_beam":
			# THE CROWN'S SORROW: not a swing -- a POUR. Narrow lances of grief
			# leave the blade many times a second, each piercing whatever it
			# passes through (Starlight-kin: the identity is hit RATE, and the
			# per-hit number is deliberately small).
			pierce = true
			_build_griefbeam()
		"brazier_flail":
			# THRONE OF EMBERS: a flail whose head, when it comes to REST on the
			# ground, stops being a weapon and becomes a THRONE -- a burning
			# brazier that spits embers until you take it up again
			# (Flower-Pow-kin, never 1:1).
			_build_chainmaul()
			_recolor_brazier()
			spin_speed = 16.0
			pierce = true
		"crown_spear":
			# REGICIDE: a thrown crown-spear that STICKS. The kill is not the
			# throw -- it is the fifth spear, and the sixth pushing the first
			# one out (Daybreak-kin, never 1:1).
			_build_crownspear()
		"edict_lash":
			# THE FINAL EDICT: the law reaches everyone. A segmented arm extends
			# from the wielder THROUGH solid rock, cuts everything along its
			# whole length, and blooms where it touches (Solar-Eruption-kin,
			# never 1:1). It owns its own damage -- no physics body at all.
			monitoring = false
			pierce = true
			_build_edict()
		"courtier":
			# THE WHOLE COURT, SPINNING: a shade of someone you brought home,
			# holding one of the ladder's ancestor blades. Many appear at once
			# (First-Fractal-kin, never 1:1) -- they materialise around the
			# wielder, hold a beat, then all sweep together.
			pierce = true
			_zen_tint = WeaponFx.LEGACY_TINTS[court_index % WeaponFx.LEGACY_TINTS.size()]
			_zen_start = global_position
			# each shade takes ITS OWN mark when the caller assigned one, so a
			# rank of courtiers fans across the row instead of bunching on one
			# body; falls back to the nearest when the court outnumbers the foes
			if court_target != Vector2.ZERO:
				_zen_target = court_target
			else:
				_zen_target = global_position + direction * max_distance
				var cprey := _nearest_hostile_node(max_distance)
				if cprey != null:
					_zen_target = cprey.global_position
			_behave_state = 0
			_orbit_t = 0.0
			_build_courtier()
			modulate.a = 0.0
		"javelin": _build_javelin()
		"fireball": _build_fireball()
		"frost_shard": _build_frost()
		"hook": _build_hook()
		"boomerang":
			_build_boomerang()
			spin_speed = 16.0
		"orbiter":
			_build_orbiter()
			spin_speed = 22.0
			pierce = true          # multi-hit by nature; despawn is state-driven
		"chain_maul":
			_build_chainmaul()
			spin_speed = 18.0
			pierce = true          # the whirl and the hurl both rake through
		"ricochet":
			_build_ricochet()
		"cluster":
			_build_cluster()
		"lob":
			_build_lob()
			_vel_y = -absf(float(speed)) * 0.62   # the mortar's upward kick
			_start_y = global_position.y
			if aoe_radius <= 0.0:
				aoe_radius = 90.0
		"lash":
			_build_lash()
			pierce = true
		# tome batch 3b (no two tomes cast the same shape):
		"ink_jet":
			_build_inkjet()
			pierce = true
			_vel_y = -absf(float(speed)) * 0.3   # a lobbed STREAM: gentle arc
		"wake_scythe":
			_build_wakescythe()
			pierce = true
			spin_speed = 9.0
			speed = maxf(120.0, float(speed) * 0.3)   # starts lazy, ACCELERATES
		"soul_stream":
			_build_soulwispshot()
			pierce = false
	if spin_speed == 0.0:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if done:
		return
	# the behavior kinds that OWN their whole flight take the frame here
	if kind == "orbiter" and _tick_orbiter(delta):
		return
	if kind == "chain_maul":
		_tick_chainmaul(delta)
		return
	if kind == "brazier_flail":
		_tick_brazier(delta)
		return
	if kind == "lob":
		_tick_lob(delta)
		return
	if kind == "zenith_blade":
		_tick_zenith(delta)
		return
	if kind == "courtier":
		_tick_courtier(delta)
		return
	if kind == "edict_lash":
		_tick_edict(delta)
		return
	if kind == "sunder_wave":
		_tick_sunder(delta)
		return
	if kind in ["lingering_arc", "ground_thorn", "sun_pool", "sky_pillar"]:
		_tick_standing_zone(delta)
		return
	if kind == "anvil_drop":
		_tick_anvil(delta)
		return
	if kind == "kneeling_stone":
		_tick_boulder(delta)
		return
	if kind == "marcher" or kind == "storm_bird":
		_tick_marcher(delta)
		return
	if kind == "dawn_line":
		_tick_dawn_line(delta)
		return
	if kind == "rift_bloom":
		_tick_rift(delta)
		return
	if kind == "choir_note":
		_tick_standing_zone(delta)
		return
	if kind == "asphodel_post":
		_tick_asphodel(delta)
		return
	if kind == "late_thunder":
		_tick_late_thunder(delta)
		return
	if kind == "eclipse_disc":
		_tick_eclipse(delta)
		return
	if kind == "comet":
		_tick_comet(delta)
		return
	if kind == "cinder_drag":
		_tick_cinder_drag(delta)
		return
	if kind == "comet_chain":
		_tick_comet_chain(delta)
		return
	if kind == "cinder_patch":
		_tick_standing_zone(delta)
		return
	if kind == "watch_fire":
		_tick_watch_fire(delta)
		return
	if kind == "stage_pike":
		_tick_stage_pike(delta)
		return
	if kind == "flood_wave":
		_tick_flood(delta)
		return
	if kind == "lodestar":
		_tick_lodestar(delta)
		return
	if kind == "moon_orbit":
		_tick_moon(delta)
		return
	if kind == "anvil_toll":
		_tick_toll(delta)
		return
	if kind == "rend_half":
		_tick_rend(delta)
		return
	if kind == "sun_piece":
		_tick_sunpiece(delta)
		return
	if kind == "ice_sheet":
		_tick_ice_sheet(delta)
		return
	if kind == "hollow_wheel":
		_tick_hollow_wheel(delta)
		return
	if kind == "grief_return":
		_tick_grief(delta)
		return
	if kind == "portent":
		_tick_portent(delta)
		return
	if kind == "courier_route":
		_tick_courier(delta)
		return
	if kind == "stoop_arrow":
		_tick_stoop(delta)
		return
	if kind == "quill_fall":
		_tick_quill(delta)
		return
	if kind in ["ash_cloud", "cinder_shelf"]:
		_tick_standing_zone(delta)
		return
	if kind == "sea_wall":
		_tick_seawall(delta)
		return
	if kind == "serpent_coil":
		_tick_serpent(delta)
		return
	if kind == "twin_bolt":
		_tick_twin(delta)
		return
	if kind == "deep_beacon":
		_tick_beacon(delta)
		return
	if kind == "star_fall":
		_tick_quill(delta)      # same fall, its own face (see _build_star_fall)
		return
	if kind == "zenith_storm":
		_tick_zenith_storm(delta)
		return
	if kind == "patient_storm" or kind == "kingdom_ring":
		_tick_zenith_storm(delta)     # same swarm engine, different crowd
		return
	if kind == "rumor_bolt":
		_tick_rumor(delta)
		return
	if kind == "sky_measure":
		_tick_measure(delta)
		return
	if kind == "colonnade":
		_tick_colonnade(delta)
		return
	if kind == "harmonic":
		_tick_harmonic(delta)
		return
	if kind == "harp_string":
		_tick_harp(delta)
		return
	if kind == "grief_tear":
		_tick_tear(delta)
		return
	if kind == "sky_charge":
		_tick_skycharge(delta)
		return
	if kind == "world_cut":
		_tick_worldcut(delta)
		return
	if kind == "howl_crescent":
		_tick_howl(delta)
		return
	if kind == "frost_roller":
		_tick_roller(delta)
		return
	if kind == "reaper_return":
		_tick_grief(delta)          # same route-and-come-home, its own face
		return
	if kind == "omen_eye":
		_tick_omeneye(delta)
		return
	if kind == "kestrel":
		_tick_kestrel(delta)
		return
	if kind == "thunderhead":
		_tick_thunderhead(delta)
		return
	if kind == "midnight_post":
		_tick_midnight(delta)
		return
	if kind == "siren_song":
		_tick_siren(delta)
		return
	if kind == "star_splinter":
		_tick_splinter(delta)
		return
	if kind == "ember_hymn":
		_tick_emberhymn(delta)
		return
	if kind == "saint_halo":
		_tick_saint(delta)
		return
	if kind == "iron_spike":
		_tick_standing_zone(delta)
		return
	if kind == "quiet_wheel":
		_tick_quiet(delta)
		return
	if kind == "winter_wheel":
		_tick_winter(delta)
		return
	if kind == "sky_quill":
		_tick_skyquill(delta)
		return
	if kind == "eventide":
		_tick_eventide(delta)
		return
	if kind == "rain_cloud":
		_tick_raincloud(delta)
		return
	if kind == "warden_post":
		_tick_warden(delta)
		return
	if kind == "ice_floe":
		_tick_floe(delta)
		return
	if kind == "owl_pass":
		_tick_owl(delta)
		return
	if kind == "rain_quill":
		_tick_quill(delta)     # the same fall; its face and cadence differ
		return
	if kind == "under_toll":
		# it runs along the floor and SURFACES at the end of its run
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance:
			_nova_burst_tinted(global_position, Color(0.92, 0.66, 0.32))
			_rock_smoke(global_position)
			done = true
			queue_free()
		return
	if kind == "regent_shard":
		_tick_regent_shard(delta)
		return
	if kind == "bent_ray":
		# it climbs over what is between, then comes down on the far side
		_bent_t += delta
		var arc: float = -560.0 * cos(clampf(_bent_t / 0.9, 0.0, 1.0) * PI)
		global_position += direction * speed * delta + Vector2(0, arc * delta)
		rotation = (direction * speed + Vector2(0, arc)).angle()
		traveled += speed * delta
		if traveled >= max_distance:
			done = true
			queue_free()
		return
	if kind == "world_edge":
		# it grows the whole way: a sliver at the hilt, a horizon at the end
		var grow: float = 1.0 + 1.7 * clampf(traveled / maxf(1.0, max_distance), 0.0, 1.0)
		if visual:
			visual.scale = Vector2.ONE * _draw_girth * grow
	if kind == "rising_wheel":
		_tick_rising_wheel(delta)
		return
	if kind == "ink_jet":
		# THE INKWELL OF STORMS: a piercing stream riding a gentle arc --
		# gravity pulls the jet down as it flies, staining as it goes
		_vel_y += 620.0 * delta
		global_position += direction * speed * delta + Vector2(0, _vel_y * delta)
		rotation = (direction * speed + Vector2(0, _vel_y)).angle()
		traveled += speed * delta
		if traveled >= max_distance or _vel_y > 700.0:
			done = true
			queue_free()
		return
	if kind == "wake_scythe":
		# THE BOOK OF WAKES: the scythe WAKES as it travels -- lazy at the
		# page, terrible by the far edge (accelerating pierce disc)
		speed = minf(1100.0, speed * (1.0 + 2.4 * delta))
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance * 1.4:
			done = true
			queue_free()
		return
	if kind == "soul_stream":
		# THE FLOOD OF SOULS: each soul BENDS toward the nearest living thing
		var prey := _nearest_hostile_node(420.0)
		if prey != null:
			var desired := (prey.global_position - global_position).normalized()
			var maxturn := 4.2 * delta
			direction = direction.rotated(clampf(direction.angle_to(desired), -maxturn, maxturn)).normalized()
			rotation = direction.angle()
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance * 1.3:
			done = true
			queue_free()
		return
	if kind == "lash":
		# a weaving ribbon: the lane is `direction`, the weave rides across it
		_rehit_t += delta
		if _rehit_t >= 0.5:
			_rehit_t = 0.0
			hit_bodies.clear()   # both passes -- and long bodies get raked
	if (kind == "boomerang" or kind == "lash") and returning:
		if not is_instance_valid(source):
			queue_free()
			return
		var to_src = source.global_position - global_position
		if to_src.length() < 26.0:
			queue_free()
			return
		direction = to_src.normalized()
	var step = speed * delta
	global_position += direction * step
	if kind == "lash":
		# the sideways weave, perpendicular to the lane
		var perp := Vector2(-direction.y, direction.x)
		global_position += perp * sin(traveled * 0.045) * 90.0 * delta
	traveled += step
	if spin_speed != 0.0 and visual:
		visual.rotation += spin_speed * delta
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	if not returning and traveled >= max_distance:
		if kind == "boomerang" or kind == "lash":
			returning = true
			hit_bodies.clear()   # the return pass hits everyone again
			# NOVA TONGUE (T7): the tongue reaches its full length and the tip
			# goes NOVA -- the turn is the detonation
			if rider == "nova":
				_nova_burst(global_position)
			# THE SHAPE OF SILENCE (T7): where the lash turns, it leaves a
			# hush -- a still place that holds whatever stands in it
			elif rider == "hush":
				var hush = get_script().new()
				hush.kind = "lingering_arc"
				hush.damage = maxi(1, int(round(float(damage) * 0.3)))
				hush.element = element
				hush.on_hit_status = {"kind": "slow", "dur": 2.2, "mag": 0.45}
				hush.source = source
				hush.position = global_position
				get_parent().call_deferred("add_child", hush)
		elif kind == "fireball":
			explode()
		elif kind == "cluster":
			_burst()             # nothing in the way: blossom at full reach
		elif kind == "orbiter":
			if _behave_state == 0:   # full thread: start the wheel HERE
				_behave_state = 1
				_orbit_centre = global_position
				_orbit_t = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -12.0, 1.2)
		else:
			done = true   # a spent bolt lands no same-frame parting hit
			queue_free()

# Orbiter: fly out (false = let the shared movement run), then spin at the far
# point striking everything in the wheel, then thread home. Returns true while
# it owns the frame.
func _tick_orbiter(delta: float) -> bool:
	match _behave_state:
		1:
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.35:
				_rehit_t = 0.0
				hit_bodies.clear()   # the wheel keeps cutting
			var r := 30.0 * _draw_girth
			global_position = _orbit_centre + Vector2(cos(_orbit_t * 9.0), sin(_orbit_t * 9.0)) * r
			if _orbit_t >= dwell:
				_behave_state = 2
				hit_bodies.clear()   # one clean cut on the way home
			return true
		2:
			if not is_instance_valid(source):
				queue_free()
				return true
			var to_src = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return true
			global_position += to_src.normalized() * speed * 1.35 * delta
			return true
		_:
			if traveled >= max_distance:
				_behave_state = 1
				_orbit_centre = global_position
				SfxSynth.play_at(self, global_position, "whoosh", -12.0, 1.2)
			return false

# Chain maul: whirls about the WIELDER gathering speed, then hurls itself
# along the aim as a comet, then hauls back home on its chain. Owns every
# frame of its flight.
func _tick_chainmaul(delta: float) -> void:
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	if spin_speed != 0.0 and visual:
		visual.rotation += spin_speed * delta
	match _behave_state:
		0:   # the whirl: an opening spiral centred on the wielder
			if not is_instance_valid(source):
				queue_free()
				return
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.3:
				_rehit_t = 0.0
				hit_bodies.clear()   # every lap of the whirl cuts again
				if rider == "moon":
					_moon_pull()     # Second Moon: the whirl has its own tide
			var r := (44.0 + _orbit_t * 75.0) * _draw_girth
			var side := 1.0 if direction.x >= 0.0 else -1.0
			global_position = source.global_position \
				+ Vector2(cos(_orbit_t * 9.5 * side), sin(_orbit_t * 9.5 * side)) * r
			if _orbit_t >= 0.7:
				_behave_state = 1
				hit_bodies.clear()
				# hurl from wherever the whirl released, along the aim
				traveled = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -9.0, 0.9)
		1:   # the hurl
			var step := speed * 1.45 * delta
			global_position += direction * step
			traveled += step
			if traveled >= max_distance:
				_behave_state = 2
				hit_bodies.clear()   # one clean cut on the haul home
				# CHAINED COMET (T7): the head is a comet, and a comet leaves a
				# CRATER -- a burning pool at the far end of the throw
				if rider == "comet":
					var crater = get_script().new()
					crater.kind = "sun_pool"
					crater.damage = maxi(1, int(round(float(damage) * 0.26)))
					crater.element = element
					crater.on_hit_status = on_hit_status
					crater.source = source
					crater.position = global_position
					get_parent().call_deferred("add_child", crater)
		_:   # hauled home on the chain
			if not is_instance_valid(source):
				queue_free()
				return
			var to_src = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return
			global_position += to_src.normalized() * speed * 1.3 * delta

# Lob: a mortar arc under its own gravity; blossoms where it lands (or on
# whatever it meets on the way down).
func _tick_lob(delta: float) -> void:
	# A Borrowed Star: at the TOP of the arc it sheds two smaller embers,
	# once -- three falling lights where one was borrowed
	if rider == "borrow" and not _borrowed and _vel_y >= 0.0:
		_borrowed = true
		var script: GDScript = get_script()
		for side in [-0.3, 0.3]:
			var ember = script.new()
			ember.kind = "lob"
			ember.direction = Vector2(direction.x + side, 0.0).normalized()
			ember.speed = speed * 0.8
			ember.damage = maxi(1, int(round(damage * 0.45)))
			ember.aoe_radius = aoe_radius * 0.6
			ember.max_distance = max_distance
			ember.arc_gravity = arc_gravity
			ember._start_y = _start_y
			ember.on_hit_status = on_hit_status
			ember.source = source
			get_parent().add_child(ember)
			ember.global_position = global_position
	_vel_y += arc_gravity * delta
	global_position += Vector2(direction.x * speed * 0.8 * delta, _vel_y * delta)
	traveled += speed * 0.8 * delta
	if visual:
		visual.rotation += 6.0 * delta
	# landing: past the launch height on the way down, or out of reach entirely
	if (_vel_y > 0.0 and global_position.y >= _start_y + 8.0) or traveled >= max_distance * 1.6:
		explode()

# Cluster: the blossom -- a fan of frost-quick shards from the burst point.
func _burst() -> void:
	if done:
		return
	done = true
	SfxSynth.play_at(self, global_position, "pop", -10.0, 0.7)
	var script: GDScript = get_script()
	for i in range(maxi(2, shards)):
		var a := -PI * 0.5 + (float(i) / float(maxi(2, shards) - 1) - 0.5) * PI * 1.3
		var child = script.new()
		child.kind = "frost_shard"
		child.direction = Vector2(cos(a), sin(a)) if direction.x >= 0.0 else Vector2(-cos(a), sin(a))
		child.speed = speed * 1.15
		child.damage = maxi(1, int(round(damage * 0.45)))
		child.max_distance = 260.0
		child.girth = girth * 0.7
		child.pierce = false
		child.on_hit_status = on_hit_status
		child.is_crit = false
		child.source = source
		get_parent().add_child(child)
		child.global_position = global_position
	# a soft pop so the split reads
	var pop = Polygon2D.new()
	pop.polygon = _circle(16.0 * _draw_girth, 12)
	pop.color = Color(0.8, 0.9, 1.0, 0.6)
	get_parent().add_child(pop)
	pop.global_position = global_position
	var t = pop.create_tween()
	t.tween_property(pop, "scale", Vector2(2.2, 2.2), 0.2)
	t.parallel().tween_property(pop, "modulate:a", 0.0, 0.2)
	t.tween_callback(pop.queue_free)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if done or body in hit_bodies:
		return
	if not body.has_method("take_damage"):
		return
	if "is_dead" in body and body.is_dead:
		return
	hit_bodies.append(body)
	# the Soul Split bolt never damages -- it only asks the target to divide
	if kind == "soul_split":
		# `done` on EVERY terminal path (audit fix): queue_free() does not stop
		# a second body_entered in the SAME physics frame, so a bolt overlapping
		# two enemies at once hit both -- and a soul_split could ask two targets
		# to divide with one cast
		done = true
		if body.has_method("on_soul_split_wand"):
			body.on_soul_split_wand()
		else:
			FloatingText.spawn_word(get_parent(), body.global_position + Vector2(0, -40), "...nothing?", Color(0.8, 0.8, 0.9))
		queue_free()
		return
	# A weapon's thrown crescent carries its owner's signature: landing one is a
	# hit like any other, so lifesteal, gold-touch, execute and the rest all fire.
	# Without this a weapon built to reach was strictly worse at its own range.
	# (The player guards against a unique that throws another projectile.)
	if is_instance_valid(source) and source.has_method("on_projectile_hit"):
		source.on_projectile_hit(body, damage)
	match kind:
		"portent":
			# DIRE PORTENT: the shaft does not kill, it FIXES the omen in place
			var landed_p = body.take_damage(maxi(1, int(round(float(damage) * 0.35))))
			if landed_p == null or landed_p:
				FloatingText.spawn(get_parent(), body.global_position,
					maxi(1, int(round(float(damage) * 0.35))), false)
			_apply_status_to(body)
			_portent_fix(body)
		"prism_bolt":
			# PRISMBREAK: the bolt goes in white and comes out in three colours
			var landed_pb = body.take_damage(damage)
			if landed_pb == null or landed_pb:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_prism_split(body.global_position)
			done = true
			queue_free()
			return
		"oath_arrow":
			# FALCON'S OATH: the shaft keeps the promise -- where it lands, you
			# ARE. The one weapon in the roster that moves the wielder.
			var landed_oa = body.take_damage(damage)
			if landed_oa == null or landed_oa:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			if is_instance_valid(source) and source.has_method("oath_dash_to"):
				source.oath_dash_to(body.global_position)
			done = true
			queue_free()
			return
		"rumor_bolt":
			# THE RUMOR: every body it reaches tells two more
			var landed_ru = body.take_damage(damage)
			if landed_ru == null or landed_ru:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_rumor_spread(body.global_position)
			done = true
			queue_free()
			return
		"grief_tear":
			var landed_gt = body.take_damage(damage)
			if landed_gt == null or landed_gt:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			done = true
			queue_free()
			return
		"ransom_seal":
			# KING'S RANSOM: the seal itself is nearly harmless. The value is
			# what it pays if they die still wearing it.
			var landed_r2 = body.take_damage(damage)
			if landed_r2 == null or landed_r2:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			var seal = load("res://embedded_stack.gd").drive(body, "ransom", {
				"max": 3, "gap": 1.0, "life": 8.0, "tick": 0, "pop": 0,
				"player": source, "ransom": 6,
				"tint": Color(1.0, 0.87, 0.42)})
			if seal != null:
				seal.add_one(damage)
			done = true
			queue_free()
			return
		"pilgrim_lash":
			# PILGRIM'S SCOURGE: every place it lands becomes a waymark
			var landed_pl = body.take_damage(damage)
			if landed_pl == null or landed_pl:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_plant_waymark(body.global_position)
		"gallows_head":
			# GALLOWS SWING: it does not knock them back, it takes them UP
			var landed_g = body.take_damage(damage)
			if landed_g == null or landed_g:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_hang_them(body)
		"serpent_coil":
			# SERPENT'S SERMON: it stops being a whip and becomes a grip
			var landed_sc = body.take_damage(damage)
			if landed_sc == null or landed_sc:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_serpent_wrap(body)
		"under_toll":
			# WORLDTOLL MAUL: it runs UNDER them, so contact is a rumble, and
			# the eruption where it surfaces is the real blow
			var landed_ut = body.take_damage(maxi(1, int(round(float(damage) * 0.35))))
			if landed_ut == null or landed_ut:
				FloatingText.spawn(get_parent(), body.global_position,
					maxi(1, int(round(float(damage) * 0.35))), false)
			_apply_status_to(body)
		"night_lash":
			# A LONG NIGHT'S TONGUE: the crack lands now, the dark answers late
			var landed_nl = body.take_damage(damage)
			if landed_nl == null or landed_nl:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			var host_nl := get_parent()
			if host_nl != null:
				var echo = (load("res://weapon_projectile.gd") as GDScript).new()
				echo.kind = "late_thunder"
				echo.damage = maxi(1, int(round(float(damage) * 0.65)))
				echo.element = element
				echo.on_hit_status = on_hit_status
				echo.source = source
				host_nl.add_child(echo)
				echo.global_position = body.global_position
		"silent_note":
			# THE SILENT CHOIR: the shaft does almost nothing. It leaves a
			# VOICE. Five voices and the chord goes off all at once.
			var quiet: int = maxi(1, int(round(float(damage) * 0.2)))
			var landed_s = body.take_damage(quiet)
			if landed_s == null or landed_s:
				FloatingText.spawn(get_parent(), body.global_position, quiet, false)
			var choir = load("res://embedded_stack.gd").drive(body, "choir", {
				"max": 5, "gap": 1.0, "life": 5.0, "tick": 0, "pop": 0,
				"player": source, "burst_at_max": true,
				"burst": maxi(1, int(round(float(damage) * 1.15))),
				"tint": Color(0.84, 0.9, 1.0)})
			if choir != null:
				choir.add_one(damage)
			done = true
			queue_free()
			return
		"nova_seed":
			# NOVABURST ROD: one bolt, three bursts -- the seed plants two more
			# beats after itself so a room keeps going off behind you
			var landed_v = body.take_damage(damage)
			if landed_v == null or landed_v:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			var host_v := get_parent()
			if host_v != null:
				for beat in range(2):
					var lt = (load("res://weapon_projectile.gd") as GDScript).new()
					lt.kind = "late_thunder"
					lt.damage = maxi(1, int(round(float(damage) * 0.6)))
					lt.element = element
					lt.on_hit_status = on_hit_status
					lt.source = source
					host_v.add_child(lt)
					lt.global_position = global_position + Vector2(
						randf_range(-74.0, 74.0), randf_range(-34.0, 18.0))
					lt.set("_hush_t", -0.32 * float(beat))
			done = true
			queue_free()
			return
		"glass_note":
			# SHATTERHYMN: the note does not land, it BREAKS
			var landed_n = body.take_damage(damage)
			if landed_n == null or landed_n:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_shatter_note(body.global_position)
			done = true
			queue_free()
			return
		"lodestar":
			# LODESTAR: the first thing it touches becomes true north
			var landed_l = body.take_damage(damage)
			if landed_l == null or landed_l:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_lode_plant(body.global_position, body)
		"long_tongue":
			# DAWN'S LONG TONGUE: every body it tastes makes it LONGER, and
			# the reach you earn is visible in the strands
			var landed_t = body.take_damage(damage)
			if landed_t == null or landed_t:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			max_distance += 46.0
			if visual:
				visual.scale = visual.scale * Vector2(1.14, 1.04)
		"eclipse_disc":
			# a graze on the way out: the real damage is the shadow it throws
			var landed_e = body.take_damage(maxi(1, int(round(float(damage) * 0.4))))
			if landed_e == null or landed_e:
				FloatingText.spawn(get_parent(), body.global_position,
					maxi(1, int(round(float(damage) * 0.4))), false)
			_apply_status_to(body)
		"debt_mark":
			var landed_d = body.take_damage(damage)
			if landed_d == null or landed_d:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			# THE DEBT IS BOOKED. It ticks, and if the debtor dies still owing,
			# the book does not close -- it moves to whoever is standing
			# nearest. Third economy on the embedded-stack system (Regicide
			# overflows, the Reckoning comes due, this one INHERITS).
			var st = load("res://embedded_stack.gd").drive(body, "debt", {
				"max": 4, "gap": 0.6, "life": 5.0,
				"tick": maxi(1, int(round(float(damage) * 0.16))),
				"pop": maxi(1, int(round(float(damage) * 0.55))),
				"player": source, "pop_on_expire": true,
				"transfer_on_death": true,
				"tint": Color(0.98, 0.86, 0.42)})
			if st != null:
				st.add_one(damage)
			done = true
			queue_free()
			return
		"fireball":
			explode()
		"lob":
			explode()
		"cluster":
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_burst()
		"ricochet":
			var landed_r = body.take_damage(damage)
			if landed_r == null or landed_r:
				FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			# leap to the nearest fresh target; the arc loses an edge each jump
			# -- unless it's The Rumor, which GROWS in the telling
			bounces -= 1
			damage = maxi(1, int(round(damage * (1.08 if rider == "grows" else 0.85))))
			# Grave Courier: a quarter of the bodies it departs are left
			# FEARED -- rooted deep in a slow, watching it leave
			if rider == "courier" and randf() < 0.25 and body.has_method("apply_status"):
				body.apply_status("slow", 1.5, 0.45)
			# THE FINAL DEBT (T7): every body it touches is BOOKED, and the
			# mark comes due on its own. A long chain leaves a room full of
			# accounts closing one after another.
			if rider == "debt":
				var bk = EMBEDDED_STACK.drive(body, "finaldebt", {
					"max": 3, "gap": 1.0, "life": 1.9,
					"tick": 0, "pop": maxi(1, int(round(float(damage) * 1.4))),
					"pop_on_expire": true,
					"tint": Color(1.0, 0.84, 0.34), "player": source})
				if bk != null:
					bk.add_one(damage)
			var next: Node2D = null
			var best := 340.0
			if bounces >= 0:
				for group_name in HOSTILE_GROUPS:
					for e in get_tree().get_nodes_in_group(group_name):
						if e == body or hit_bodies.has(e) or not is_instance_valid(e):
							continue
						if not (e is Node2D) or not e.has_method("take_damage"):
							continue
						if "is_dead" in e and e.is_dead:
							continue
						var d: float = global_position.distance_to(e.global_position)
						if d < best:
							best = d
							next = e
			if next != null:
				direction = (next.global_position - global_position).normalized()
				rotation = direction.angle()
				traveled = 0.0   # each leap gets its full legs
				# every leap PINGS, rising as the chain grows (The Rumor's
				# nine leaps climb almost an octave)
				SfxSynth.play_at(self, global_position, "pop", -14.0, 1.3 + 0.06 * float(shards))
			else:
				done = true
				queue_free()
		"hook":
			done = true   # same one-frame double-hit guard as soul_split
			body.take_damage(damage)
			FloatingText.spawn(get_parent(), body.global_position, damage, is_crit)
			_apply_status_to(body)
			_pull_to_source(body)
			queue_free()
		_:
			# only show a number if the blow actually got through (a boss can
			# absorb it entirely); void take_damage means "landed"
			# The Long Goodbye: the RETURN pass cuts double -- it hurts most
			# on the way out of your life
			var dealt := damage * (2 if kind == "lash" and returning and rider == "goodbye" else 1)
			# THE MOUNTAIN THAT KNEELS pays for its PACE, not its size
			if kind == "kneeling_stone":
				dealt = boulder_damage()
				_rock_smoke(body.global_position)   # the source bursts white smoke
			# HEAVENSTRING: the thread snaps taut and brings them to you
			if kind == "tether_arrow" and is_instance_valid(source) \
					and body.has_method("apply_knockback"):
				var toward: int = 1 if source.global_position.x > body.global_position.x else -1
				body.apply_knockback(toward, 165.0)
			# THE QUIET RECKONING: the arrow stays in, and the bill comes due
			# a second and a half later. Small now, large then.
			if kind == "debt_arrow":
				var dt = EMBEDDED_STACK.drive(body, "reckoning", {
					"max": 4, "gap": 1.0, "life": 1.5,
					"tick": 0, "pop": maxi(1, int(round(float(damage) * 7.0))),
					"pop_on_expire": true,
					"tint": Color(0.72, 0.84, 1.0), "player": source})
				if dt != null:
					dt.add_one(damage)
			# REGICIDE: the spear does NOT merely hit -- it stays in them, and
			# the stack it joins is the weapon (see embedded_stack.gd)
			if kind == "crown_spear":
				var st = EMBEDDED_STACK.drive(body, "regicide", {
					"max": 5, "gap": 0.5, "life": 6.0,
					"tick": maxi(1, int(round(float(damage) * 0.22))),
					"pop": maxi(1, int(round(float(damage) * 1.35))),
					"tint": Color(1.0, 0.86, 0.42), "player": source})
				if st != null:
					st.add_one(damage)
			var landed = body.take_damage(dealt)
			if landed == null or landed:
				# CLUSTER LAW (study/DESIGN_LAWS.md): several projectiles landing
				# together must read as a RAGGED BURST of small numbers, not one
				# blob stacked at the same pixel -- scatter the court's numbers
				var at: Vector2 = body.global_position
				if kind == "courtier":
					at += Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, 10.0))
				FloatingText.spawn(get_parent(), at, dealt, is_crit)
			_apply_status_to(body)
			# Terra semantics (2026-07-28): the wind-wall loses a quarter of its
			# edge for each body it carves through -- crowds FEEL it without
			# being erased by one swing from across the room
			if kind == "slash" and pierce:
				damage = maxi(1, int(round(damage * 0.75)))
			# The Last Word: every landing is punctuated in the image's own tint
			if kind == "zenith_blade":
				_zen_sparkle(body.global_position)
			# Summer's Coffin: what it kills SHATTERS -- the cold bursts onto
			# the mourners crowded round
			if rider == "coffin" and "is_dead" in body and body.is_dead:
				_frost_shatter(body.global_position)
			if body.has_method("apply_knockback"):
				body.apply_knockback(1 if direction.x >= 0.0 else -1, knockback)
			if not pierce and kind != "boomerang":
				done = true   # same one-frame double-hit guard as soul_split
				queue_free()

# Second Moon: every lap of the whirl drags loose enemies a step toward the
# wielder -- a gentle tide that feeds the spiral's own blades.
func _moon_pull() -> void:
	if not is_instance_valid(source):
		return
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("apply_knockback"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var dx: float = source.global_position.x - e.global_position.x
			if absf(dx) <= 180.0 and absf(dx) > 30.0:
				e.apply_knockback(1 if dx >= 0.0 else -1, 26.0)

# Summer's Coffin: the shatter -- cold damage and a deep chill around a body
# the sliver just killed.
func _frost_shatter(at: Vector2) -> void:
	SfxSynth.play_at(self, at, "chime", -11.0, 0.6)   # the cold, breaking
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if at.distance_to(e.global_position) <= 90.0:
				e.take_damage(maxi(1, int(round(damage * 0.5))))
				if e.has_method("apply_status"):
					e.apply_status("slow", 2.0, 0.5)
	var ring = Polygon2D.new()
	ring.polygon = _circle(30.0, 12)
	ring.color = Color(0.75, 0.92, 1.0, 0.8)
	ring.z_index = 45
	get_parent().add_child(ring)
	ring.global_position = at
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.3)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_callback(ring.queue_free)

# Hook: reel the victim in using its own knockback system (negative direction
# = toward the player), so it respects the enemy's is_dead/knockback rules.
func _pull_to_source(body: Node2D) -> void:
	if not is_instance_valid(source) or not body.has_method("apply_knockback"):
		return
	var dx = source.global_position.x - body.global_position.x
	var pull_sign = 1 if dx >= 0.0 else -1
	body.apply_knockback(pull_sign, max(absf(dx) - 42.0, 0.0))

const SFX_EXPLOSION = preload("res://audio/explosion.wav")

# Fireball: blast everyone standing near the detonation point.
func explode() -> void:
	if done:
		return
	done = true
	SfxSynth.play_stream_at(self, global_position, SFX_EXPLOSION, -9.0)
	# SUNSPILL (T7): the shell does not just burst, it SPILLS -- a pool of
	# burning daylight is left where it landed
	if rider == "spill":
		var pool = get_script().new()
		pool.kind = "sun_pool"
		pool.damage = maxi(1, int(round(float(damage) * 0.3)))
		pool.element = element
		pool.on_hit_status = on_hit_status
		pool.source = source
		pool.position = global_position
		get_parent().call_deferred("add_child", pool)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= aoe_radius:
				e.take_damage(damage)
				FloatingText.spawn(get_parent(), e.global_position, damage, is_crit)
				_apply_status_to(e)
				if e.has_method("apply_knockback"):
					e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback)
	# A Small Personal Sun: the blast doesn't leave -- a grounded sunlet
	# keeps burning the spot for a few seconds after the flash
	if rider == "sunfall":
		var sun = load("res://storm_cloud.gd").new()
		sun.sun_mode = true
		sun.radius = 80.0
		sun.strike_gap = 0.5
		sun.duration = 3.0
		sun.damage = maxi(1, int(round(damage * 0.35)))
		sun.source = source
		get_parent().add_child(sun)
		sun.global_position = global_position
	# blast flash: expanding fading disc + ring, left behind as we free
	var blast = Polygon2D.new()
	blast.polygon = _circle(aoe_radius * 0.4, 20)
	blast.color = Color(1.0, 0.6, 0.2, 0.7)
	blast.z_index = 45
	get_parent().add_child(blast)
	blast.global_position = global_position
	var t = blast.create_tween()
	t.tween_property(blast, "scale", Vector2(2.6, 2.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(blast, "modulate:a", 0.0, 0.25)
	t.tween_callback(blast.queue_free)
	queue_free()

# --- tome batch 3b builds + the soul's eye ------------------------------
# THE INKWELL OF STORMS: a dark teardrop stream, ink-blue, trailing droplets
func _build_inkjet() -> void:
	var drop := Polygon2D.new()
	drop.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(-4, -5), Vector2(10, -3), Vector2(16, 0), Vector2(10, 3), Vector2(-4, 5)])
	drop.color = Color(0.16, 0.2, 0.45, 0.95)
	visual.add_child(drop)
	var sheen := Polygon2D.new()
	sheen.polygon = PackedVector2Array([Vector2(-8, -2), Vector2(6, -2), Vector2(10, 0), Vector2(6, 1), Vector2(-8, 1)])
	sheen.color = Color(0.45, 0.55, 0.9, 0.8)
	visual.add_child(sheen)

# THE BOOK OF WAKES: a bone-pale scythe disc that spins as it wakes
func _build_wakescythe() -> void:
	var arc := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var r := 22.0 if i % 2 == 0 else 11.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	arc.polygon = pts
	arc.color = Color(0.85, 0.9, 0.8, 0.95)
	visual.add_child(arc)
	var wash := Polygon2D.new()
	var wpts := PackedVector2Array()
	for i in range(12):
		var aw := TAU * float(i) / 12.0
		wpts.append(Vector2(cos(aw), sin(aw)) * 30.0)
	wash.polygon = wpts
	wash.color = Color(0.65, 0.85, 0.8, 0.3)
	var wm := CanvasItemMaterial.new()
	wm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wash.material = wm
	visual.add_child(wash)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5)])
	eye.color = Color(0.3, 0.45, 0.35, 0.95)
	visual.add_child(eye)

# THE FLOOD OF SOULS: a pale wisp-skull with a streaming tail
func _build_soulwispshot() -> void:
	var skull := Polygon2D.new()
	var pts2 := PackedVector2Array()
	for i in range(10):
		var a2 := TAU * float(i) / 10.0
		pts2.append(Vector2(cos(a2) * 7.0, sin(a2) * 6.0))
	skull.polygon = pts2
	skull.color = Color(0.8, 0.88, 1.0, 0.9)
	visual.add_child(skull)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-6, -3), Vector2(-18, 0), Vector2(-6, 3)])
	tail.color = Color(0.6, 0.72, 0.95, 0.6)
	visual.add_child(tail)

func _nearest_hostile_node(within: float) -> Node2D:
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

# THE LAST WORD (Zenith-kin, GIF-measured 2026-07-28): the three-phase swoop.
# Out along a bowed arc (~0.22s), one tight whirl at the far point (~0.34s,
# re-hitting every fifth-second like the orbiter), then home to the wielder's
# CURRENT position, cutting on the way back. ~0.55s more or less, exactly the
# measured cadence. The image never minds terrain -- it is only an image.
var _zen_trail: Line2D = null
func _tick_zenith(delta: float) -> void:
	_orbit_t += delta
	match _behave_state:
		0:
			var t := clampf(_orbit_t / 0.22, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)   # smoothstep: launch soft, arrive keen
			var perp := Vector2(-direction.y, direction.x)
			var prev := global_position
			# minus: the arc bows UP over the field (Godot +y is down)
			global_position = _zen_start.lerp(_zen_target, e) - perp * sin(t * PI) * 88.0
			if (global_position - prev).length_squared() > 1.0:
				rotation = (global_position - prev).angle()
			if t >= 1.0:
				_behave_state = 1
				_orbit_t = 0.0
				_rehit_t = 0.2
		1:
			var a := _orbit_t / 0.34 * TAU
			var prev1 := global_position
			global_position = _zen_target + Vector2(cos(a), sin(a)) * 66.0
			rotation = (global_position - prev1).angle()
			_rehit_t -= delta
			if _rehit_t <= 0.0:
				hit_bodies.clear()   # the whirl grinds: each lap cuts again
				_rehit_t = 0.2
			if _orbit_t >= 0.34:
				_behave_state = 2
				_orbit_t = 0.0
				hit_bodies.clear()   # the return pass is its own sentence
		2:
			var home := _zen_start
			if is_instance_valid(source):
				home = source.global_position
			var to_home := home - global_position
			if to_home.length() <= 44.0 or _orbit_t > 0.8:
				done = true
				queue_free()
				return
			global_position += to_home.normalized() * 1300.0 * delta
			rotation = to_home.angle()
	_zen_trail_tick()

# THE FINAL EDICT (crown spear, Solar-Eruption-kin never 1:1): the arm of the
# law extends over 0.26s, holds a beat, and withdraws over 0.24s. It is drawn
# and damaged along its WHOLE LENGTH, and it does not care about terrain --
# reaching through rock is the entire point of the weapon.
const EDICT_OUT := 0.26
const EDICT_HOLD := 0.1
const EDICT_BACK := 0.24
const EDICT_BAND := 34.0     # how far off the line a body still gets cut
const EDICT_REHIT := 0.22    # the grind: a body inside the arm is cut again

func _tick_edict(delta: float) -> void:
	_lash_t += delta
	# the wielder is the anchor -- the arm stays attached while it works
	if is_instance_valid(source):
		global_position = source.global_position + Vector2(0, -10.0)
	if _lash_t <= EDICT_OUT:
		_lash_len = max_distance * ease(_lash_t / EDICT_OUT, 0.45)
	elif _lash_t <= EDICT_OUT + EDICT_HOLD:
		_lash_len = max_distance
	else:
		var b := (_lash_t - EDICT_OUT - EDICT_HOLD) / EDICT_BACK
		_lash_len = max_distance * (1.0 - clampf(b, 0.0, 1.0))
		if b >= 1.0:
			done = true
			queue_free()
			return
	# the tip traces a shallow arc as it goes out -- the sweep of a sentence
	var sweep := sin(clampf(_lash_t / (EDICT_OUT + EDICT_HOLD), 0.0, 1.0) * PI) * 46.0
	var perp := Vector2(-direction.y, direction.x)
	var tip: Vector2 = global_position + direction * _lash_len - perp * sweep
	_draw_edict(tip)
	_cut_along_edict(tip)

# damage everything within the band of the segment, terrain be damned
func _cut_along_edict(tip: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var a := global_position
	var ab := tip - a
	var ab_len2 := maxf(1.0, ab.length_squared())
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var eid := e.get_instance_id()
			if _lash_hits.has(eid) and now < _lash_hits[eid]:
				continue
			# closest point on the arm to this body
			var t: float = clampf((e.global_position - a).dot(ab) / ab_len2, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			if closest.distance_to(e.global_position) > EDICT_BAND:
				continue
			_lash_hits[eid] = now + EDICT_REHIT
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 6.0)), damage, is_crit)
			_apply_status_to(e)
			_edict_bloom(e.global_position, e)
			if is_instance_valid(source) and source.has_method("on_projectile_hit"):
				source.on_projectile_hit(e, damage)

# Every contact BLOOMS -- and the bloom is not decoration. The measured
# source erupts hit points BEYOND the visible lash (AoE procs), so the flare
# catches bodies standing NEAR the arm as well as on it. Without this the
# weapon is a line; with it, it is a sentence with consequences.
const EDICT_BLOOM_R := 74.0
func _edict_bloom(at: Vector2, struck: Node = null) -> void:
	var host := get_parent()
	if host == null:
		return
	var splash: int = maxi(1, int(round(float(damage) * 0.35)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == struck or not (e is Node2D) or not is_instance_valid(e):
				continue
			if not e.has_method("take_damage") or ("is_dead" in e and e.is_dead):
				continue
			if at.distance_to(e.global_position) > EDICT_BLOOM_R:
				continue
			var landed = e.take_damage(splash)
			if landed == null or landed:
				FloatingText.spawn(host, e.global_position
					+ Vector2(randf_range(-16.0, 16.0), -14.0), splash, false)
			_apply_status_to(e)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := TAU * float(i) / 10.0
		pts.append(Vector2(cos(ang), sin(ang)) * 17.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.86, 0.42, 0.75)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = m
	ring.z_index = 44
	host.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.3, 2.3), 0.24)
	tw.tween_property(ring, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(ring.queue_free)

var _lash_glow: Line2D = null
var _lash_knuckles: Array = []   # the joints, repositioned each frame (no churn)
var _lash_head: Polygon2D = null

func _build_edict() -> void:
	var add_m := CanvasItemMaterial.new()
	add_m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the halo the whole arm sits in
	_lash_glow = Line2D.new()
	_lash_glow.top_level = true
	_lash_glow.width = 28.0 * _draw_girth
	_lash_glow.default_color = Color(1.0, 0.66, 0.18, 0.22)
	_lash_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_glow.z_index = 42
	_lash_glow.material = add_m
	add_child(_lash_glow)
	# the core: a solid gold cord, NOT additive, so it stays gold instead of
	# washing out to white against a dark hall
	_lash_line = Line2D.new()
	_lash_line.top_level = true
	_lash_line.width = 11.0 * _draw_girth
	_lash_line.default_color = Color(0.98, 0.74, 0.24, 0.96)
	_lash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_lash_line.z_index = 43
	add_child(_lash_line)
	# the joints -- this is what makes it an ARM and not a laser
	for i in range(7):
		var k := Polygon2D.new()
		var kp := PackedVector2Array()
		for j in range(6):
			var a := TAU * float(j) / 6.0
			kp.append(Vector2(cos(a), sin(a)) * 9.0 * _draw_girth)
		k.polygon = kp
		k.color = Color(1.0, 0.88, 0.5, 0.95)
		k.top_level = true
		k.z_index = 44
		add_child(k)
		_lash_knuckles.append(k)
	# the writing tip
	_lash_head = Polygon2D.new()
	var hp := PackedVector2Array()
	for j in range(10):
		var a2 := TAU * float(j) / 10.0
		hp.append(Vector2(cos(a2), sin(a2)) * (14.0 if j % 2 == 0 else 6.5) * _draw_girth)
	_lash_head.polygon = hp
	_lash_head.color = Color(1.0, 0.95, 0.72, 0.95)
	_lash_head.top_level = true
	_lash_head.z_index = 45
	_lash_head.material = add_m
	add_child(_lash_head)

# the arm is drawn as SEGMENTS -- links of a sentence, brightening to the tip
func _draw_edict(tip: Vector2) -> void:
	if _lash_line == null:
		return
	var pts := PackedVector2Array()
	var n := 16
	var perp := Vector2(-direction.y, direction.x)
	for i in range(n + 1):
		var f := float(i) / float(n)
		var base: Vector2 = global_position.lerp(tip, f)
		# a real serpentine, wide enough to READ at play zoom -- the arm coils
		pts.append(base + perp * sin(f * PI * 2.2 + _lash_t * 7.0) * 15.0 * (1.0 - f * 0.35))
	_lash_line.points = pts
	_lash_line.width = (10.5 + 2.0 * sin(_lash_t * 18.0)) * _draw_girth
	if _lash_glow != null:
		_lash_glow.points = pts
	# seat the joints along the cord, biggest at the wrist, smallest at the tip
	for ki in range(_lash_knuckles.size()):
		var k: Polygon2D = _lash_knuckles[ki]
		var idx: int = int(round(float(ki + 1) / float(_lash_knuckles.size() + 1) * float(n)))
		k.global_position = pts[clampi(idx, 0, pts.size() - 1)]
		var taper := 1.0 - 0.55 * (float(ki) / float(maxi(1, _lash_knuckles.size() - 1)))
		k.scale = Vector2.ONE * taper
		k.visible = _lash_len > 60.0
	if _lash_head != null:
		_lash_head.global_position = pts[pts.size() - 1]
		_lash_head.rotation = _lash_t * 5.0
		_lash_head.visible = _lash_len > 40.0

# THE WHOLE COURT, SPINNING: materialise (0.14s, the court arrives) -> sweep
# together at the mark -> fade out. Deliberately BUSY: this is the culmination
# weapon, the one place the crown rule ("cleaner, not busier") is broken on
# purpose, exactly as Zenith breaks it.
func _tick_courtier(delta: float) -> void:
	_orbit_t += delta
	match _behave_state:
		0:
			# the shade fades in and draws itself up to full height
			var t := clampf(_orbit_t / 0.14, 0.0, 1.0)
			modulate.a = t
			visual.scale = Vector2.ONE * _draw_girth * lerpf(0.45, 1.0, t)
			# it faces its mark while it gathers
			var face := _zen_target - global_position
			if face.length_squared() > 1.0:
				visual.scale.x = absf(visual.scale.x) * (-1.0 if face.x < 0.0 else 1.0)
			if t >= 1.0:
				_behave_state = 1
				_orbit_t = 0.0
				# the mark may have moved (or died) while the court gathered
				var late := _nearest_hostile_node(max_distance)
				if late != null:
					_zen_target = late.global_position
				direction = (_zen_target - global_position).normalized()
		1:
			global_position += direction * 1150.0 * delta
			rotation = direction.angle()
			traveled += 1150.0 * delta
			if traveled >= max_distance * 1.15 or _orbit_t > 0.55:
				_behave_state = 2
				_orbit_t = 0.0
		2:
			global_position += direction * 420.0 * delta
			modulate.a = maxf(0.0, 1.0 - _orbit_t / 0.2)
			if _orbit_t >= 0.2:
				done = true
				queue_free()
				return
	_zen_trail_tick()

func _zen_trail_tick() -> void:
	if _zen_trail == null:
		_zen_trail = Line2D.new()
		_zen_trail.top_level = true
		_zen_trail.width = 7.0
		_zen_trail.default_color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.5)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_zen_trail.material = m
		add_child(_zen_trail)
	_zen_trail.add_point(global_position)
	while _zen_trail.get_point_count() > 16:
		_zen_trail.remove_point(0)

# the sparkle burst every zenith landing pops -- white heart, tinted rim
func _zen_sparkle(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	for i in range(4):
		var s := Polygon2D.new()
		s.polygon = PackedVector2Array([Vector2(-1.6, 0), Vector2(0, -5), Vector2(1.6, 0), Vector2(0, 5)])
		s.color = Color.WHITE if i % 2 == 0 else Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.95)
		var m2 := CanvasItemMaterial.new()
		m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m2
		host.add_child(s)
		s.global_position = at + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position + Vector2(randf_range(-26, 26), randf_range(-30, 6)), 0.4)
		tw.tween_property(s, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(s.queue_free)

# the ghost of an ancestor blade: a full sword-image drawn point-first (+X),
# glowing in its legacy tint with a pale core -- The Last Word remembers
# every sword that was folded into it
# a courtier of the Whole Court: the shade of someone you brought home, drawn
# point-first (+X) -- a hooded cloak streaming behind an ancestor blade. The
# blade wears the tint; the shade stays dark, so a swing reads as SEVERAL
# distinct people arriving, not one effect repeated.
# THRONE OF EMBERS (crown melee, Flower-Pow-kin never 1:1) --------------
# whirl -> hurl -> FALL -> sit as a brazier spitting embers -> haul home.
# The study's find: a flail head RESTED on the ground becoming a turret is a
# whole second weapon hiding inside the first, and it costs the player their
# flail to use it -- a real trade, not a free bonus.
const BRAZ_WHIRL := 0.55
const BRAZ_SIT := 3.2        # seconds the throne burns before it is taken up
const BRAZ_SPIT := 0.45      # seconds between embers
var _braz_spit_t := 0.0

const CHAIN_BAND := 26.0
const CHAIN_REHIT := 0.35
var _chain_hits := {}

# THE CHAIN BITES (fidelity pass). The source's chain hits everything along
# its length -- three bodies at once in the measured footage -- and our own
# DESIGN_LAWS guardrail says exactly "flail launches must damage along the
# chain, not just the head". It was drawn but inert. Now it is a line of
# damage from the wielder to the head, at a third of the head's bite.
func _chain_bite() -> void:
	if not is_instance_valid(source):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var a: Vector2 = source.global_position
	var ab: Vector2 = global_position - a
	var ab_len2: float = maxf(1.0, ab.length_squared())
	var bite: int = maxi(1, int(round(float(damage) * 0.34)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var eid := e.get_instance_id()
			if _chain_hits.has(eid) and now < _chain_hits[eid]:
				continue
			var t: float = clampf((e.global_position - a).dot(ab) / ab_len2, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			if closest.distance_to(e.global_position) > CHAIN_BAND:
				continue
			_chain_hits[eid] = now + CHAIN_REHIT
			var landed = e.take_damage(bite)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-14.0, 14.0), -18.0), bite, false)
			_apply_status_to(e)

func _tick_brazier(delta: float) -> void:
	if rope and is_instance_valid(source):
		rope.points = PackedVector2Array([Vector2.ZERO, to_local(source.global_position)])
	# the chain is live from the moment it is out until it comes home
	if _behave_state >= 1:
		_chain_bite()
	match _behave_state:
		0:   # the whirl, tight around the wielder
			if not is_instance_valid(source):
				queue_free()
				return
			if visual:
				visual.rotation += spin_speed * delta
			_orbit_t += delta
			_rehit_t += delta
			if _rehit_t >= 0.3:
				_rehit_t = 0.0
				hit_bodies.clear()
			var r := (40.0 + _orbit_t * 70.0) * _draw_girth
			var side := 1.0 if direction.x >= 0.0 else -1.0
			global_position = source.global_position \
				+ Vector2(cos(_orbit_t * 9.0 * side), sin(_orbit_t * 9.0 * side)) * r
			if _orbit_t >= BRAZ_WHIRL:
				_behave_state = 1
				hit_bodies.clear()
				traveled = 0.0
				SfxSynth.play_at(self, global_position, "whoosh", -9.0, 0.8)
		1:   # the hurl
			if visual:
				visual.rotation += spin_speed * delta
			var step := speed * 1.3 * delta
			global_position += direction * step
			traveled += step
			if traveled >= max_distance:
				_behave_state = 2
				_vel_y = 0.0
				hit_bodies.clear()
		2:   # the fall: the head looks for somewhere to sit
			if visual:
				visual.rotation += spin_speed * 0.5 * delta
			_vel_y += 1500.0 * delta
			var drop := _vel_y * delta
			global_position.y += drop
			if _find_floor_below(maxf(drop, 6.0) + 10.0):
				_behave_state = 3
				_orbit_t = 0.0
				_braz_spit_t = 0.0
				spin_speed = 0.0
				_seat_the_throne()
			elif _vel_y > 1400.0:      # nothing under it: give up and come back
				_behave_state = 4
		3:   # THE THRONE: it sits, and it burns
			_orbit_t += delta
			_braz_spit_t += delta
			if _braz_spit_t >= BRAZ_SPIT:
				_braz_spit_t = 0.0
				_spit_ember()
			if _orbit_t >= BRAZ_SIT:
				_behave_state = 4
		_:   # hauled home on the chain
			if not is_instance_valid(source):
				queue_free()
				return
			var to_src: Vector2 = source.global_position - global_position
			if to_src.length() < 26.0:
				queue_free()
				return
			global_position += to_src.normalized() * speed * 1.25 * delta

# is there ground within `dist` below the head?
func _find_floor_below(dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, dist))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y - 12.0
		return true
	return false

# the moment it becomes furniture: a seat of coals, and the fire takes
func _seat_the_throne() -> void:
	SfxSynth.play_at(self, global_position, "thud", -8.0, 0.7)
	var coals := Polygon2D.new()
	coals.polygon = _circle(26.0, 12)
	coals.color = Color(1.0, 0.45, 0.12, 0.3)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	coals.material = m
	coals.z_index = -1
	visual.add_child(coals)
	var tw := coals.create_tween()
	tw.set_loops()
	tw.tween_property(coals, "scale", Vector2(1.25, 1.25), 0.5)
	tw.tween_property(coals, "scale", Vector2(0.9, 0.9), 0.5)

# an ember leaves the throne for whoever is nearest
func _spit_ember() -> void:
	var prey := _nearest_hostile_node(560.0)
	var dir := Vector2(1, -0.25).normalized() if prey == null \
		else (prey.global_position - global_position).normalized()
	var e = get_script().new()
	e.kind = "fireball"
	e.damage = maxi(1, int(round(float(damage) * 0.45)))
	e.speed = 430.0
	e.max_distance = 620.0
	e.aoe_radius = 54.0
	e.girth = 0.7 * girth
	e.direction = dir
	e.element = element
	e.on_hit_status = on_hit_status
	e.source = source
	e.position = global_position + Vector2(0, -14)
	get_parent().add_child(e)
	SfxSynth.play_at(self, global_position, "pop", -19.0, 1.4)

# the maul, but forged as a seat of embers rather than cold iron.
# _build_chainmaul lays out: [0] halo, [1] head, [2..7] six spikes, [8] gleam.
func _recolor_brazier() -> void:
	if visual == null:
		return
	var polys := []
	for c in visual.get_children():
		if c is Polygon2D:
			polys.append(c)
	for i in range(polys.size()):
		var p: Polygon2D = polys[i]
		if i == 0:
			p.color = Color(1.0, 0.5, 0.14, 0.3)        # the heat it gives off
		elif i == 1:
			p.color = Color(0.3, 0.17, 0.12, 1.0)       # blackened iron
		elif i == polys.size() - 1:
			p.color = Color(1.0, 0.9, 0.58, 0.95)       # the live coal
		else:
			p.color = Color(0.93, 0.44, 0.13, 1.0)      # ember-lit spikes

# --- T7, the last four ---------------------------------------------------

# HEAVENSTRING: the shaft trails a thread and the thread goes taut
func _build_tether_arrow() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var thread := Polygon2D.new()
	thread.polygon = PackedVector2Array([
		Vector2(-8, -1.2), Vector2(-64, -0.5), Vector2(-64, 0.5), Vector2(-8, 1.2)])
	thread.color = Color(0.9, 0.94, 1.0, 0.5)
	thread.material = m
	visual.add_child(thread)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(11, -1.3), Vector2(-15, -1.3), Vector2(-15, 1.3), Vector2(11, 1.3)])
	shaft.color = Color(0.78, 0.84, 0.96, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(20, 0), Vector2(8, -4), Vector2(8, 4)])
	head.color = Color(1.0, 1.0, 0.95, 0.98)
	visual.add_child(head)

# CHOIRSTRING: a note left standing where the shaft landed
func _build_choir_note() -> void:
	_zone_max = 2.4
	_zone_r = 54.0
	_zone_gap = 0.5      # it HUMS on a beat rather than grinding
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for r in [26.0, 16.0]:
		var ring := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(14):
			var a := TAU * float(i) / 14.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		for i in range(14):
			var a2 := TAU * float(13 - i) / 14.0
			pts.append(Vector2(cos(a2), sin(a2)) * (r - 3.0))
		ring.polygon = pts
		ring.color = Color(0.82, 0.9, 1.0, 0.5 if r > 20.0 else 0.75)
		ring.material = m
		visual.add_child(ring)
		var tw := ring.create_tween()
		tw.set_loops()
		tw.tween_property(ring, "scale", Vector2(1.18, 1.18), 0.5)
		tw.tween_property(ring, "scale", Vector2(0.94, 0.94), 0.5)

# THE HEAVEN-PIERCING POINT: one lance, everything in the line takes the same
func _build_piercing_point() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(36, 0), Vector2(11, -6), Vector2(-26, -3), Vector2(-26, 3), Vector2(11, 6)])
	glow.color = Color(0.86, 0.92, 1.0, 0.3)
	glow.material = m
	visual.add_child(glow)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(9, -1.6), Vector2(-25, -1.6), Vector2(-25, 1.6), Vector2(9, 1.6)])
	shaft.color = Color(0.72, 0.78, 0.9, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(32, 0), Vector2(9, -3.4), Vector2(5, 0), Vector2(9, 3.4)])
	head.color = Color(1.0, 1.0, 0.98, 0.98)
	visual.add_child(head)

# --- ASPHODEL POST: a marker that keeps sending ---------------------------
var _post_t := 0.0
var _post_send := 0.0
const POST_LIFE := 9.0
const POST_GAP := 1.15

func _tick_asphodel(delta: float) -> void:
	_post_t += delta
	_post_send += delta
	if visual:
		visual.modulate.a = clampf((POST_LIFE - _post_t) / 1.2, 0.0, 1.0)
	if _post_send >= POST_GAP:
		_post_send = 0.0
		var prey := _nearest_hostile_node(700.0)
		var w = get_script().new()
		w.kind = "soul_stream"          # the homing wisp already exists
		w.damage = damage
		w.speed = 250.0
		w.max_distance = 700.0
		w.direction = Vector2.RIGHT if prey == null \
			else (prey.global_position - global_position).normalized()
		w.girth = 0.75
		w.element = element
		w.on_hit_status = on_hit_status
		w.source = source
		w.position = global_position + Vector2(0, -26.0)
		get_parent().call_deferred("add_child", w)
		SfxSynth.play_at(self, global_position, "chime", -20.0, 1.2)
	if _post_t >= POST_LIFE:
		done = true
		queue_free()

func _build_asphodel_post() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3.5, 16), Vector2(-2.5, -34), Vector2(2.5, -34), Vector2(3.5, 16)])
	post.color = Color(0.36, 0.34, 0.4, 1.0)
	visual.add_child(post)
	var bloom := Polygon2D.new()   # the asphodel itself, pale on top
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 9.0 - 38.0))
	bloom.polygon = pts
	bloom.color = Color(0.92, 0.94, 0.86, 0.95)
	visual.add_child(bloom)
	var halo := Polygon2D.new()
	halo.polygon = _circle(20.0, 12)
	halo.position = Vector2(0, -38)
	halo.color = Color(0.8, 0.86, 1.0, 0.22)
	halo.material = m
	visual.add_child(halo)

# --- RIFTBURST ROD: the tear that hauls, then shuts ----------------------
var _rift_t := 0.0
var _bent_t := 0.0
const RIFT_HOLD := 0.85
const RIFT_R := 132.0

func _tick_rift(delta: float) -> void:
	_rift_t += delta
	var f: float = clampf(_rift_t / RIFT_HOLD, 0.0, 1.0)
	if visual:
		# it opens fast, hangs, then snaps shut
		visual.scale = Vector2.ONE * _draw_girth * (0.4 + 1.1 * sin(f * PI))
		visual.rotation += 3.4 * delta
	# the HAUL: everything in reach is dragged toward the middle
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var d: float = global_position.distance_to(e.global_position)
			if d > RIFT_R or d < 8.0:
				continue
			if e.has_method("apply_knockback"):
				# toward the tear, not away from it
				e.apply_knockback(1 if global_position.x > e.global_position.x else -1, 34.0 * delta * 60.0 / 60.0)
	if f < 1.0:
		return
	# THE SHUTTING is the damage
	for group_name2 in HOSTILE_GROUPS:
		for e2 in get_tree().get_nodes_in_group(group_name2):
			if not (e2 is Node2D) or not is_instance_valid(e2) or not e2.has_method("take_damage"):
				continue
			if "is_dead" in e2 and e2.is_dead:
				continue
			if global_position.distance_to(e2.global_position) > RIFT_R * 0.8:
				continue
			var landed = e2.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e2.global_position
					+ Vector2(randf_range(-18.0, 18.0), -24.0), damage, true)
			_apply_status_to(e2)
	_nova_burst_tinted(global_position, Color(0.72, 0.45, 1.0))
	done = true
	queue_free()

# the nova flash, in an arbitrary colour (the rift shuts violet, not gold)
func _nova_burst_tinted(at: Vector2, col: Color) -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * (30.0 if i % 2 == 0 else 12.0))
	ring.polygon = pts
	ring.color = col
	ring.material = m
	ring.z_index = 45
	host.add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(0.2, 0.2), 0.22)   # it SHUTS
	tw.tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(ring.queue_free)

func _build_rift() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = _circle(46.0, 16)
	halo.color = Color(0.55, 0.3, 0.95, 0.22)
	halo.material = m
	visual.add_child(halo)
	# the tear itself: a narrow vertical slit, not a ball
	var slit := Polygon2D.new()
	slit.polygon = PackedVector2Array([
		Vector2(0, -44), Vector2(11, -14), Vector2(7, 0), Vector2(11, 14),
		Vector2(0, 44), Vector2(-11, 14), Vector2(-7, 0), Vector2(-11, -14)])
	slit.color = Color(0.78, 0.5, 1.0, 0.75)
	slit.material = m
	visual.add_child(slit)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -38), Vector2(3.4, 0), Vector2(0, 38), Vector2(-3.4, 0)])
	core.color = Color(0.05, 0.02, 0.1, 0.95)   # the dark INSIDE the tear
	visual.add_child(core)

# --- THE SHARD REGENT: the crown that goes one at a time -----------------
var _shard_delay := 0.0
func _tick_regent_shard(delta: float) -> void:
	_orbit_t += delta
	if _orbit_t < _shard_delay:
		# still crowning the caster: orbit the source
		if is_instance_valid(source):
			var a := _orbit_t * 5.2 + float(court_index) * 1.05
			global_position = source.global_position + Vector2(cos(a), sin(a) * 0.55) * 54.0
			visual.rotation = a
		return
	if _mark == null or not is_instance_valid(_mark) or _is_dead_node(_mark):
		_mark = _nearest_hostile_node(620.0)
		if _mark != null:
			direction = (_mark.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	traveled += speed * delta
	if traveled >= max_distance:
		done = true
		queue_free()

func _build_regent_shard() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(0, -9), Vector2(-12, 0), Vector2(0, 9)])
	glow.color = Color(0.7, 0.9, 1.0, 0.34)
	glow.material = m
	visual.add_child(glow)
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(13, 0), Vector2(0, -5), Vector2(-9, 0), Vector2(0, 5)])
	shard.color = Color(0.86, 0.95, 1.0, 0.95)
	visual.add_child(shard)

# HEAVEN, BENT: a ray with a spine, drawn so the arc reads
func _build_bent_ray() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(2, -8), Vector2(-24, 0), Vector2(2, 8)])
	glow.color = Color(0.62, 0.78, 1.0, 0.36)
	glow.material = m
	visual.add_child(glow)
	var ray := Polygon2D.new()
	ray.polygon = PackedVector2Array([
		Vector2(22, 0), Vector2(1, -3.2), Vector2(-18, 0), Vector2(1, 3.2)])
	ray.color = Color(0.9, 0.95, 1.0, 0.95)
	visual.add_child(ray)

# PILLAR OF THE SKY: a standing column of daylight. Reuses the standing-zone
# tick wholesale -- only the shape and the numbers differ.
func _build_sky_pillar() -> void:
	_zone_max = 1.5
	_zone_r = 58.0
	_zone_gap = 0.3
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([
		Vector2(-40, 34), Vector2(-24, -300), Vector2(24, -300), Vector2(40, 34)])
	halo.color = Color(1.0, 0.9, 0.55, 0.16)
	halo.material = m
	visual.add_child(halo)
	var col := Polygon2D.new()
	col.polygon = PackedVector2Array([
		Vector2(-21, 32), Vector2(-13, -300), Vector2(13, -300), Vector2(21, 32)])
	col.color = Color(1.0, 0.95, 0.72, 0.4)
	col.material = m
	visual.add_child(col)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-7, 30), Vector2(-4, -300), Vector2(4, -300), Vector2(7, 30)])
	core.color = Color(1.0, 1.0, 0.92, 0.75)
	core.material = m
	visual.add_child(core)
	var pool := Polygon2D.new()   # where it meets the floor
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * 44.0, sin(a) * 11.0))
	pool.polygon = pts
	pool.position = Vector2(0, 30)
	pool.color = Color(1.0, 0.86, 0.46, 0.4)
	pool.material = m
	visual.add_child(pool)

# THE NINTH COMMANDMENT's ruling: one heavy bolt, wider than any arrow
func _build_commandment() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(44, 0), Vector2(10, -13), Vector2(-30, -7), Vector2(-30, 7), Vector2(10, 13)])
	glow.color = Color(1.0, 0.88, 0.5, 0.34)
	glow.material = m
	visual.add_child(glow)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(38, 0), Vector2(8, -6), Vector2(-26, -3.2), Vector2(-26, 3.2), Vector2(8, 6)])
	body.color = Color(1.0, 0.94, 0.72, 0.95)
	visual.add_child(body)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(32, 0), Vector2(6, -2.4), Vector2(-22, -1.2), Vector2(-22, 1.2), Vector2(6, 2.4)])
	core.color = Color(1.0, 1.0, 1.0, 0.95)
	visual.add_child(core)

# --- WHEEL OF ASCENSION: the wheel that climbs ---------------------------
# It goes UP rather than out, dragging what it catches with it. The lift is
# the weapon: a crowd held off the floor is a crowd not hitting you.
var _wheel_t := 0.0
func _tick_rising_wheel(delta: float) -> void:
	_wheel_t += delta
	# a widening upward spiral centred on where it was thrown
	var climb := 200.0 * delta
	global_position.y -= climb
	global_position.x += sin(_wheel_t * 6.5) * 74.0 * delta
	if visual:
		visual.rotation += spin_speed * delta
		visual.modulate.a = clampf(1.6 - _wheel_t * 0.55, 0.0, 1.0)
	_rehit_t += delta
	if _rehit_t >= 0.28:
		_rehit_t = 0.0
		hit_bodies.clear()      # each turn of the wheel bites again
	# anything it passes gets carried UP with it
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) > 78.0:
				continue
			if e.has_method("apply_knockback"):
				e.apply_knockback(0, 26.0)   # the lift, not a shove
	if _wheel_t >= 2.1:
		done = true
		queue_free()

func _build_rising_wheel() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 21.0)
	for i in range(14):
		var a2 := TAU * float(13 - i) / 14.0
		pts.append(Vector2(cos(a2), sin(a2)) * 15.0)
	rim.polygon = pts
	rim.color = Color(0.86, 0.92, 1.0, 0.85)
	rim.material = m
	visual.add_child(rim)
	for i in range(6):
		var spoke := Polygon2D.new()
		var a3 := TAU * float(i) / 6.0
		spoke.polygon = PackedVector2Array([
			Vector2(cos(a3 - 0.07), sin(a3 - 0.07)) * 18.0,
			Vector2(cos(a3), sin(a3)) * 3.0,
			Vector2(cos(a3 + 0.07), sin(a3 + 0.07)) * 18.0])
		spoke.color = Color(0.7, 0.84, 1.0, 0.75)
		spoke.material = m
		visual.add_child(spoke)

# NOVA TONGUE: the tip detonates at full extension -- damage plus a real
# star-burst, so the turn of the lash IS the payoff rather than dead time
const NOVA_R := 108.0
func _nova_burst(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var pay: int = maxi(1, int(round(float(damage) * 0.8)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if at.distance_to(e.global_position) > NOVA_R:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, e.global_position
					+ Vector2(randf_range(-20.0, 20.0), -26.0), pay, true)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if e.global_position.x >= at.x else -1, 90.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the flash: a star, not a circle
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * (34.0 if i % 2 == 0 else 13.0))
	star.polygon = pts
	star.color = Color(1.0, 0.86, 0.5, 0.95)
	star.material = m
	star.z_index = 45
	host.add_child(star)
	star.global_position = at
	var tw := star.create_tween()
	tw.set_parallel(true)
	tw.tween_property(star, "scale", Vector2(2.6, 2.6), 0.3)
	tw.tween_property(star, "rotation", 1.2, 0.3)
	tw.tween_property(star, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(star.queue_free)
	for i in range(9):
		var sp := ColorRect.new()
		sp.color = Color(1.0, 0.94, 0.68, 0.9)
		sp.size = Vector2(4, 4)
		sp.z_index = 45
		host.add_child(sp)
		sp.global_position = at
		var v := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(50.0, 108.0)
		var st := sp.create_tween()
		st.set_parallel(true)
		st.tween_property(sp, "global_position", at + v, 0.34)
		st.tween_property(sp, "modulate:a", 0.0, 0.34)
		st.chain().tween_callback(sp.queue_free)
	SfxSynth.play_at(self, at, "chime", -8.0, 0.6)

# --- DAWN CHORUS: the bar of first light that rises ----------------------
var _dawn_t := 0.0
const DAWN_RISE := 0.7
func _tick_dawn_line(delta: float) -> void:
	_dawn_t += delta
	var f: float = clampf(_dawn_t / DAWN_RISE, 0.0, 1.0)
	global_position.y -= 132.0 * delta
	if visual:
		visual.modulate.a = 1.0 - f * f
		visual.scale.x = 1.0 + f * 0.35
	# it cuts everything it climbs past, once each
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead or hit_bodies.has(e):
				continue
			if absf(e.global_position.x - global_position.x) > 74.0:
				continue
			if absf(e.global_position.y - global_position.y) > 22.0:
				continue
			hit_bodies.append(e)
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-14.0, 14.0), -22.0), damage, is_crit)
			_apply_status_to(e)
	if f >= 1.0:
		done = true
		queue_free()

func _build_dawn_line() -> void:
	# TAPERED, not rectangular. The first cut drew a flat bar with square ends
	# and read as a UI progress bar sitting in the world; light has soft ends.
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-78, 0), Vector2(-52, -11), Vector2(52, -11),
		Vector2(78, 0), Vector2(52, 11), Vector2(-52, 11)])
	glow.color = Color(1.0, 0.7, 0.26, 0.34)
	glow.material = m
	visual.add_child(glow)
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([
		Vector2(-72, 0), Vector2(-46, -4.2), Vector2(46, -4.2),
		Vector2(72, 0), Vector2(46, 4.2), Vector2(-46, 4.2)])
	bar.color = Color(1.0, 0.9, 0.55, 0.85)
	bar.material = m
	visual.add_child(bar)
	# a few motes lifting off it, so the rise reads as dawn and not a slab
	for i in range(5):
		var mote := Polygon2D.new()
		mote.polygon = _circle(2.6, 6)
		mote.color = Color(1.0, 0.95, 0.72, 0.9)
		mote.material = m
		mote.position = Vector2(randf_range(-62.0, 62.0), randf_range(-4.0, 4.0))
		visual.add_child(mote)
		var tw := mote.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mote, "position", mote.position + Vector2(randf_range(-8, 8), -26.0), 0.6)
		tw.tween_property(mote, "modulate:a", 0.0, 0.6)

# THE QUIET RECKONING's arrow: pale, quiet, and carrying a bill
func _build_debt_arrow() -> void:
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(12, -1.4), Vector2(-18, -1.4), Vector2(-18, 1.4), Vector2(12, 1.4)])
	shaft.color = Color(0.62, 0.66, 0.78, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(21, 0), Vector2(9, -4.0), Vector2(9, 4.0)])
	head.color = Color(0.86, 0.92, 1.0, 0.98)
	visual.add_child(head)

# FLOCK OF STORMS' bird: a dark wedge with a lit edge
func _build_storm_bird() -> void:
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-4, -6), Vector2(-14, 0), Vector2(-4, 6)])
	body.color = Color(0.16, 0.18, 0.26, 0.95)
	visual.add_child(body)
	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([
		Vector2(-2, -4), Vector2(-16, -16), Vector2(-8, -2)])
	wing.color = Color(0.34, 0.42, 0.6, 0.9)
	visual.add_child(wing)
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(10, -3), Vector2(12, 0), Vector2(10, 3)])
	spark.color = Color(0.8, 0.92, 1.0, 0.95)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spark.material = m
	visual.add_child(spark)

# --- T7 STANDING ZONES ---------------------------------------------------
# One tick serves three weapons, because the study's aftermath family is one
# idea wearing three coats: something STAYS where the attack happened and
# keeps working. Afterlight's hanging blade-light, Thorn of the World's
# risen spikes, Sunspill's burning pool. Duration, radius and bite differ;
# the machinery does not.
var _zone_life := 0.0
var _zone_max := 1.6
var _zone_r := 60.0
var _zone_gap := 0.35
var _zone_t := 0.0

func _tick_standing_zone(delta: float) -> void:
	_zone_life += delta
	_zone_t += delta
	var frac: float = clampf(_zone_life / _zone_max, 0.0, 1.0)
	if visual:
		visual.modulate.a = 1.0 - frac * frac      # holds, then goes quickly
	if _zone_t >= _zone_gap:
		_zone_t = 0.0
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if global_position.distance_to(e.global_position) > _zone_r:
					continue
				var landed = e.take_damage(damage)
				if landed == null or landed:
					FloatingText.spawn(get_parent(), e.global_position
						+ Vector2(randf_range(-16.0, 16.0), -20.0), damage, false)
				_apply_status_to(e)
	if _zone_life >= _zone_max:
		done = true
		queue_free()

# AFTERLIGHT: the shape of the swing, left behind in the air
func _build_lingering_arc() -> void:
	_zone_max = 1.7
	_zone_r = 66.0
	_zone_gap = 0.34
	for pass_i in range(2):
		var arc := Polygon2D.new()
		var pts := PackedVector2Array()
		var outer := 52.0 if pass_i == 0 else 44.0
		var inner := 34.0 if pass_i == 0 else 30.0
		for i in range(11):
			var a := lerpf(-1.05, 1.05, float(i) / 10.0)
			pts.append(Vector2(cos(a), sin(a)) * outer)
		for i in range(11):
			var a2 := lerpf(1.05, -1.05, float(i) / 10.0)
			pts.append(Vector2(cos(a2), sin(a2)) * inner)
		arc.polygon = pts
		arc.color = Color(1.0, 0.94, 0.72, 0.3) if pass_i == 0 else Color(1.0, 1.0, 0.9, 0.6)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		arc.material = m
		visual.add_child(arc)

# THORN OF THE WORLD: three spikes come up out of the floor
func _build_ground_thorn() -> void:
	_zone_max = 1.3
	_zone_r = 74.0
	_zone_gap = 0.3
	for i in range(3):
		var th := Polygon2D.new()
		var h := 46.0 - absf(float(i) - 1.0) * 12.0
		th.polygon = PackedVector2Array([
			Vector2(-7.0, 8.0), Vector2(-2.5, -h), Vector2(2.5, -h), Vector2(7.0, 8.0)])
		th.color = Color(0.5, 0.14, 0.2, 0.95)
		th.position = Vector2(-42.0 + 42.0 * float(i), 8.0)
		visual.add_child(th)
		var lip := Polygon2D.new()
		lip.polygon = PackedVector2Array([
			Vector2(-2.0, -h * 0.55), Vector2(0.0, -h), Vector2(2.0, -h * 0.55)])
		lip.color = Color(0.95, 0.4, 0.45, 0.9)
		lip.position = th.position
		visual.add_child(lip)
		# they ERUPT rather than appear
		th.scale.y = 0.1
		var tw := th.create_tween()
		tw.tween_property(th, "scale:y", 1.0, 0.14).set_delay(0.05 * float(i))

# SUNSPILL: a pool of daylight burning on the floor
func _build_sun_pool() -> void:
	_zone_max = 4.2
	_zone_r = 82.0
	_zone_gap = 0.4
	var pool := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 80.0, sin(a) * 20.0))
	pool.polygon = pts
	pool.color = Color(1.0, 0.62, 0.16, 0.42)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = m
	visual.add_child(pool)
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in range(14):
		var a2 := TAU * float(i) / 14.0
		cpts.append(Vector2(cos(a2) * 52.0, sin(a2) * 12.0))
	core.polygon = cpts
	core.color = Color(1.0, 0.86, 0.4, 0.5)
	core.material = m
	visual.add_child(core)
	var tw := pool.create_tween()
	tw.set_loops()
	tw.tween_property(pool, "scale", Vector2(1.06, 1.15), 0.6)
	tw.tween_property(pool, "scale", Vector2(0.96, 0.9), 0.6)

# --- ANVIL OF ENDINGS: the mass that arrives late ------------------------
var _anvil_t := 0.0
var _anvil_target := Vector2.ZERO
const ANVIL_FALL := 0.45

func _tick_anvil(delta: float) -> void:
	if done:
		return   # landed: it is sitting there fading, not falling
	_anvil_t += delta
	var f: float = clampf(_anvil_t / ANVIL_FALL, 0.0, 1.0)
	# it comes down out of the dark, accelerating
	global_position = Vector2(_anvil_target.x,
		lerpf(_anvil_target.y - 420.0, _anvil_target.y, f * f))
	if f < 1.0:
		return
	# landing
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) > 92.0:
				continue
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position + Vector2(0, -28.0), damage, true)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback * 1.4)
	_rock_smoke(global_position + Vector2(0, 12.0))
	SfxSynth.play_at(self, global_position, "thud", -4.0, 0.55)
	# LET IT BE SEEN. Freeing on the landing frame meant the mass arrived and
	# vanished in the same instant -- on film there was smoke and a number but
	# no anvil. It sits for a beat, then sinks away.
	done = true
	if _anvil_shadow != null and is_instance_valid(_anvil_shadow):
		_anvil_shadow.visible = false
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)

func set_anvil_target(at: Vector2) -> void:
	_anvil_target = at
	global_position = Vector2(at.x, at.y - 420.0)
	# the tell sits on the GROUND, not on the falling mass -- it is top_level
	# so it would otherwise have stayed pinned at the world origin
	if _anvil_shadow != null and is_instance_valid(_anvil_shadow):
		_anvil_shadow.global_position = at + Vector2(0, 12.0)

var _anvil_shadow: Polygon2D = null
func _build_anvil() -> void:
	# THE TELL: a shadow on the ground the whole time it is falling, so the
	# player (and anything with sense) knows exactly where the mass lands
	_anvil_shadow = Polygon2D.new()
	_anvil_shadow.polygon = PackedVector2Array([
		Vector2(-34, 0), Vector2(-20, -7), Vector2(20, -7), Vector2(34, 0),
		Vector2(20, 7), Vector2(-20, 7)])
	_anvil_shadow.color = Color(0.05, 0.04, 0.07, 0.45)
	_anvil_shadow.top_level = true
	_anvil_shadow.z_index = 3
	add_child(_anvil_shadow)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-30, -6), Vector2(-16, -26), Vector2(20, -26), Vector2(30, -8),
		Vector2(24, 14), Vector2(-24, 14)])
	body.color = Color(0.19, 0.18, 0.22, 1.0)
	visual.add_child(body)
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([
		Vector2(-16, -26), Vector2(20, -26), Vector2(18, -18), Vector2(-14, -18)])
	face.color = Color(0.42, 0.4, 0.46, 1.0)
	visual.add_child(face)

# --- GRIEF WEARS A CROWN: the ground carries the blow ------------------
const SUNDER_SPEED := 1400.0
const SUNDER_BAND := 42.0        # how thick the front is
var _wave_r := 0.0
var _wave_left: Polygon2D = null
var _wave_right: Polygon2D = null

func _tick_sunder(delta: float) -> void:
	_wave_r += SUNDER_SPEED * delta
	if _wave_r >= max_distance:
		done = true
		queue_free()
		return
	var fade: float = 1.0 - (_wave_r / max_distance)
	for w in [_wave_left, _wave_right]:
		if w != null and is_instance_valid(w):
			w.position.x = _wave_r * (-1.0 if w == _wave_left else 1.0)
			w.scale = Vector2(1.0, lerpf(0.5, 1.5, 1.0 - fade))
			w.modulate.a = fade
	# each body is taken ONCE, as the front reaches it -- a wave passes
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead or hit_bodies.has(e):
				continue
			var dx: float = absf(e.global_position.x - global_position.x)
			var dy: float = absf(e.global_position.y - global_position.y)
			if dy > 90.0 or absf(dx - _wave_r) > SUNDER_BAND:
				continue
			hit_bodies.append(e)
			var landed = e.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), e.global_position
					+ Vector2(randf_range(-18.0, 18.0), -24.0), damage, is_crit)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if e.global_position.x >= global_position.x else -1, knockback * 1.6)
			if is_instance_valid(source) and source.has_method("on_projectile_hit"):
				source.on_projectile_hit(e, damage)

# two crescents of displaced force running away from the blow
func _build_sunder() -> void:
	for side in [-1.0, 1.0]:
		var c := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(9):
			var a := lerpf(-1.15, 1.15, float(i) / 8.0)
			pts.append(Vector2(cos(a) * 16.0 * float(side), sin(a) * 30.0))
		for i in range(9):
			var a2 := lerpf(1.15, -1.15, float(i) / 8.0)
			pts.append(Vector2(cos(a2) * 3.0 * float(side), sin(a2) * 26.0))
		c.polygon = pts
		c.color = Color(1.0, 0.74, 0.36, 0.85)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = m
		visual.add_child(c)
		if side < 0.0: _wave_left = c
		else: _wave_right = c

# --- THE MOUNTAIN THAT KNEELS: damage is the boulder's own speed --------
var _roll_life := 0.0

func _tick_boulder(delta: float) -> void:
	_roll_life += delta
	_vel_y += 1500.0 * delta
	global_position += direction * speed * delta + Vector2(0, _vel_y * delta)
	traveled += speed * delta
	# sit on the ground and follow the slope, so a hill becomes a multiplier
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -18.0),
		global_position + Vector2(0, 26.0))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit:
		var was_falling := _vel_y
		global_position.y = hit.position.y - 16.0
		if _vel_y > 0.0:
			# rolling downhill FEEDS it; a flat floor just carries it
			speed = minf(1250.0, speed + _vel_y * 0.25)
			_vel_y = 0.0
		# a real landing kicks dust; a gentle roll along the floor does not
		if was_falling > 420.0:
			_rock_smoke(global_position + Vector2(0, 14.0))
	if visual:
		visual.rotation += (speed / 34.0) * delta * (1.0 if direction.x >= 0.0 else -1.0)
	if traveled >= max_distance or _roll_life > 6.0:
		done = true
		queue_free()

# the boulder's bite is its pace: slow rock barely stings, a boulder at
# full roll flattens (the climbing numbers ARE the weapon -- DESIGN_LAWS 7)
func boulder_damage() -> int:
	return maxi(1, int(round(float(damage) * clampf(speed / 720.0, 0.35, 1.6))))

# white smoke, the way a heavy rock actually announces itself (fidelity pass)
func _rock_smoke(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	for i in range(4):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(7.0, 12.0), 8)
		puff.color = Color(0.92, 0.9, 0.86, 0.6)
		puff.z_index = 41
		host.add_child(puff)
		puff.global_position = at + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 8.0))
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "scale", Vector2(2.1, 2.1), 0.42)
		tw.tween_property(puff, "global_position",
			puff.global_position + Vector2(randf_range(-18.0, 18.0), -22.0), 0.42)
		tw.tween_property(puff, "modulate:a", 0.0, 0.42)
		tw.chain().tween_callback(puff.queue_free)

func _build_boulder() -> void:
	var rock := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(11):
		var a := TAU * float(i) / 11.0
		var r := 21.0 + sin(float(i) * 2.3) * 4.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	rock.polygon = pts
	rock.color = Color(0.36, 0.33, 0.31, 1.0)
	visual.add_child(rock)
	for i in range(4):
		var chip := Polygon2D.new()
		var a2 := TAU * float(i) / 4.0 + 0.4
		chip.polygon = PackedVector2Array([
			Vector2(cos(a2), sin(a2)) * 8.0,
			Vector2(cos(a2 + 0.5), sin(a2 + 0.5)) * 15.0,
			Vector2(cos(a2 + 0.9), sin(a2 + 0.9)) * 7.0])
		chip.color = Color(0.47, 0.44, 0.41, 1.0)
		visual.add_child(chip)

# --- NIGHT PARADE: they come in from off the edge of the world ----------
func _tick_marcher(delta: float) -> void:
	_orbit_t += delta
	var prey: Node2D = null
	if _mark != null and is_instance_valid(_mark) and not _is_dead_node(_mark):
		prey = _mark
	else:
		prey = _nearest_hostile_node(900.0)
		_mark = prey
	if prey == null or _orbit_t > 4.0:
		modulate.a = maxf(0.0, modulate.a - delta * 3.0)
		if modulate.a <= 0.05:
			done = true
			queue_free()
		return
	# a marcher WALKS: it closes horizontally and ignores the terrain
	var to_prey: Vector2 = prey.global_position - global_position
	global_position += Vector2(signf(to_prey.x), 0).normalized() * 420.0 * delta
	global_position.y = lerpf(global_position.y, prey.global_position.y, 2.2 * delta)
	if visual:
		visual.scale.x = absf(visual.scale.x) * (-1.0 if to_prey.x < 0.0 else 1.0)
		visual.position.y = sin(_orbit_t * 7.0) * 3.0   # the walking bob
	if absf(to_prey.x) < 30.0 and absf(to_prey.y) < 60.0:
		if prey.has_method("take_damage"):
			var landed = prey.take_damage(damage)
			if landed == null or landed:
				FloatingText.spawn(get_parent(), prey.global_position
					+ Vector2(randf_range(-20.0, 20.0), -30.0), damage, is_crit)
			_apply_status_to(prey)
		done = true
		queue_free()

func _is_dead_node(n: Node) -> bool:
	return "is_dead" in n and n.is_dead

# a marcher: a hooded shade carrying a small lantern -- the parade reads as
# PEOPLE, which is what ties it to the rescue story
func _build_marcher() -> void:
	var cloak := Polygon2D.new()
	cloak.polygon = PackedVector2Array([
		Vector2(0, -26), Vector2(9, -12), Vector2(7, 14), Vector2(-7, 14), Vector2(-9, -12)])
	cloak.color = Color(0.13, 0.12, 0.2, 0.88)
	visual.add_child(cloak)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(7, -22), Vector2(4, -14), Vector2(-4, -14), Vector2(-7, -22)])
	hood.color = Color(0.07, 0.07, 0.12, 0.95)
	visual.add_child(hood)
	var lantern := Polygon2D.new()
	lantern.polygon = PackedVector2Array([
		Vector2(11, -4), Vector2(16, -4), Vector2(16, 3), Vector2(11, 3)])
	lantern.color = Color(1.0, 0.82, 0.42, 0.95)
	visual.add_child(lantern)
	var glow := Polygon2D.new()
	glow.polygon = _circle(15.0, 10)
	glow.color = Color(1.0, 0.78, 0.36, 0.3)
	glow.position = Vector2(13.5, 0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	visual.add_child(glow)

# THE CROWN'S SORROW's lance: a narrow spindle of pale light with a white
# core -- small, fast, and there are always several in the air
func _build_griefbeam() -> void:
	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(4, -6), Vector2(-16, 0), Vector2(4, 6)])
	halo.color = Color(0.62, 0.78, 1.0, 0.34)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = m
	visual.add_child(halo)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(25, 0), Vector2(3, -2.6), Vector2(-12, 0), Vector2(3, 2.6)])
	body.color = Color(0.82, 0.9, 1.0, 0.95)
	visual.add_child(body)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(2, -1.1), Vector2(-8, 0), Vector2(2, 1.1)])
	core.color = Color(1.0, 1.0, 1.0, 0.98)
	visual.add_child(core)

# REGICIDE's thrown spear: a slim crown-gold lance, point-first
func _build_crownspear() -> void:
	# THE STREAK (fidelity pass): the source drags a ~2.5 player-height flame
	# behind every javelin, and our own law says the TRAIL is the signature.
	# A long tapering additive wedge reads as fire at speed without costing a
	# per-frame trail node.
	var streak := Polygon2D.new()
	streak.polygon = PackedVector2Array([
		Vector2(-24, -5.0), Vector2(-46, -2.6), Vector2(-70, 0),
		Vector2(-46, 2.6), Vector2(-24, 5.0)])
	streak.color = Color(1.0, 0.6, 0.2, 0.42)
	var sm := CanvasItemMaterial.new()
	sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	streak.material = sm
	visual.add_child(streak)
	var streak_hot := Polygon2D.new()
	streak_hot.polygon = PackedVector2Array([
		Vector2(-22, -2.2), Vector2(-38, -1.1), Vector2(-52, 0),
		Vector2(-38, 1.1), Vector2(-22, 2.2)])
	streak_hot.color = Color(1.0, 0.88, 0.5, 0.55)
	streak_hot.material = sm
	visual.add_child(streak_hot)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(6, -7), Vector2(-24, -4), Vector2(-24, 4), Vector2(6, 7)])
	glow.color = Color(1.0, 0.82, 0.36, 0.3)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(10, -1.8), Vector2(-26, -1.8), Vector2(-26, 1.8), Vector2(10, 1.8)])
	shaft.color = Color(0.46, 0.36, 0.22, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(9, -5.5), Vector2(4, 0), Vector2(9, 5.5)])
	head.color = Color(1.0, 0.9, 0.5, 0.98)
	visual.add_child(head)
	var fletch := Polygon2D.new()
	fletch.polygon = PackedVector2Array([
		Vector2(-20, -1.8), Vector2(-30, -7.0), Vector2(-27, 0), Vector2(-30, 7.0), Vector2(-20, 1.8)])
	fletch.color = Color(0.88, 0.72, 0.3, 0.9)
	visual.add_child(fletch)

func _build_courtier() -> void:
	var cloak := Polygon2D.new()
	cloak.polygon = PackedVector2Array([
		Vector2(6, -9), Vector2(-6, -11), Vector2(-22, -4),
		Vector2(-26, 0), Vector2(-22, 4), Vector2(-6, 11), Vector2(6, 9)])
	cloak.color = Color(0.09, 0.08, 0.13, 0.72)
	visual.add_child(cloak)
	var hem := Polygon2D.new()   # a tint-lit edge so each shade is legible
	hem.polygon = PackedVector2Array([
		Vector2(-6, -11), Vector2(-22, -4), Vector2(-26, 0), Vector2(-21, -1), Vector2(-7, -8)])
	hem.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.55)
	visual.add_child(hem)
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(8, -6), Vector2(2, -9), Vector2(-4, -5), Vector2(-3, 4), Vector2(4, 6), Vector2(9, 2)])
	hood.color = Color(0.05, 0.05, 0.09, 0.9)
	visual.add_child(hood)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(34, 0), Vector2(10, -8), Vector2(-2, -5), Vector2(-4, 0), Vector2(-2, 5), Vector2(10, 8)])
	glow.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.32)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(8, -4), Vector2(-2, -2.5), Vector2(-2, 2.5), Vector2(8, 4)])
	blade.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.95)
	visual.add_child(blade)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(8, -1.6), Vector2(0, -1.0), Vector2(0, 1.0), Vector2(8, 1.6)])
	core.color = Color(1.0, 1.0, 1.0, 0.8)
	visual.add_child(core)

func _build_zenithblade() -> void:
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(6, -11), Vector2(-20, -7), Vector2(-26, 0),
		Vector2(-20, 7), Vector2(6, 11)])
	glow.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.35)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	visual.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(4, -6), Vector2(-14, -4), Vector2(-14, 4), Vector2(4, 6)])
	blade.color = Color(_zen_tint.r, _zen_tint.g, _zen_tint.b, 0.9)
	visual.add_child(blade)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(22, 0), Vector2(4, -2.5), Vector2(-12, -1.5), Vector2(-12, 1.5), Vector2(4, 2.5)])
	core.color = Color(1.0, 1.0, 1.0, 0.85)
	visual.add_child(core)
	var guard := Polygon2D.new()
	guard.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(-11, 0), Vector2(-14, 8), Vector2(-17, 0)])
	guard.color = Color(minf(1.0, _zen_tint.r + 0.2), minf(1.0, _zen_tint.g + 0.2), minf(1.0, _zen_tint.b + 0.2), 0.95)
	visual.add_child(guard)

# --- procedural looks ---

# The Soul Split Wand's bolt: a pale prismatic orb. It deals NO damage --
# whatever it strikes is asked to divide, and what that means is the target's
# business (a joke for everything alive; the end of the world for one thing).
func _build_soulbolt() -> void:
	var orb = Polygon2D.new()
	orb.polygon = _circle(9.0, 12)
	orb.color = Color(0.95, 0.8, 1.0, 0.9)
	visual.add_child(orb)
	var halo = Polygon2D.new()
	halo.polygon = _circle(14.0, 12)
	halo.color = Color(0.8, 0.6, 1.0, 0.3)
	visual.add_child(halo)

func _build_slash() -> void:
	# TERRA STANDARD (2026-07-28, GIF-measured): the beam IS the weapon -- a
	# tall readable crescent near player height, riding an additive wake that
	# streaks behind it. A weapon may tint the whole thing (beam_tint).
	var tint := beam_tint if beam_tint.a > 0.0 else Color(0.75, 0.95, 1.0)
	var wake = Polygon2D.new()   # the streak: a soft afterglow swept backward
	var wpts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.75, 0.75, i / 8.0)
		wpts.append(Vector2(cos(a), sin(a)) * 24.0)
	for i in range(9):
		var a = lerp(0.75, -0.75, i / 8.0)
		wpts.append(Vector2(cos(a) * 24.0 - 34.0, sin(a) * 21.0))
	wake.polygon = wpts
	wake.color = Color(tint.r, tint.g, tint.b, 0.28)
	var wm := CanvasItemMaterial.new()
	wm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wake.material = wm
	visual.add_child(wake)
	var arc = Polygon2D.new()   # the blade of wind itself
	var pts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.95, 0.95, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 27.0)
	for i in range(9):
		var a = lerp(0.95, -0.95, i / 8.0)
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	arc.polygon = pts
	arc.color = Color(tint.r, tint.g, tint.b, 0.9)
	visual.add_child(arc)
	var edge = Polygon2D.new()   # a bright leading lip
	var epts = PackedVector2Array()
	for i in range(9):
		var a = lerp(-0.95, 0.95, i / 8.0)
		epts.append(Vector2(cos(a), sin(a)) * 27.0)
	for i in range(9):
		var a = lerp(0.95, -0.95, i / 8.0)
		epts.append(Vector2(cos(a), sin(a)) * 24.0)
	edge.polygon = epts
	edge.color = Color(minf(1.0, tint.r + 0.25), minf(1.0, tint.g + 0.25), minf(1.0, tint.b + 0.25), 0.95)
	visual.add_child(edge)

func _build_javelin() -> void:
	var shaft = Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-24, -2), Vector2(16, -2), Vector2(16, 2), Vector2(-24, 2)])
	shaft.color = Color(0.85, 0.8, 0.55, 0.9)
	visual.add_child(shaft)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(16, -5), Vector2(28, 0), Vector2(16, 5)])
	tip.color = Color(0.95, 0.92, 0.75, 0.95)
	visual.add_child(tip)

func _build_fireball() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(14.0, 14)
	glow.color = Color(1.0, 0.5, 0.1, 0.4)
	visual.add_child(glow)
	var core = Polygon2D.new()
	core.polygon = _circle(8.0, 12)
	core.color = Color(1.0, 0.75, 0.3, 0.95)
	visual.add_child(core)
	var trail = CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.35
	trail.direction = Vector2(-1, 0)
	trail.spread = 24.0
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 90.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.4
	trail.color = Color(1.0, 0.55, 0.15, 0.8)
	visual.add_child(trail)

func _build_frost() -> void:
	var shard = Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(-4, -6), Vector2(18, 0), Vector2(-4, 6)])
	shard.color = Color(0.7, 0.9, 1.0, 0.9)
	visual.add_child(shard)
	var gleam = Polygon2D.new()
	gleam.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(0, -2), Vector2(10, 0), Vector2(0, 2)])
	gleam.color = Color(0.95, 1.0, 1.0, 0.9)
	visual.add_child(gleam)

# A soulthread charm: a rune-disc that spins on its thread.
func _build_orbiter() -> void:
	# EYES 2026-07-28: sized and haloed like the flail -- the first build was
	# a faint dot at world zoom, and a spinning wheel must LOOK like a wheel
	var glow = Polygon2D.new()
	glow.polygon = _circle(22.0, 12)
	glow.color = Color(0.7, 0.88, 1.0, 0.2)
	visual.add_child(glow)
	var disc = Polygon2D.new()
	disc.polygon = _circle(16.0, 10)
	disc.color = Color(0.75, 0.9, 1.0, 1.0)
	visual.add_child(disc)
	var core = Polygon2D.new()
	core.polygon = _circle(7.0, 8)
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	visual.add_child(core)
	for i in range(3):
		var spoke = Polygon2D.new()
		var a := TAU * float(i) / 3.0
		spoke.polygon = PackedVector2Array([
			Vector2(cos(a), sin(a)) * 5.0, Vector2(cos(a + 0.3), sin(a + 0.3)) * 19.0,
			Vector2(cos(a - 0.3), sin(a - 0.3)) * 19.0])
		spoke.color = Color(0.6, 0.82, 1.0, 0.95)
		visual.add_child(spoke)

# A spiked head on its chain, drawn back to the fist that swings it. Sized
# and lit to READ at world zoom against the night palette (EYES 2026-07-28:
# the first build was a faint smear -- a flail must look like a threat).
func _build_chainmaul() -> void:
	var glow = Polygon2D.new()   # a dim halo so the head carries in the dark
	glow.polygon = _circle(20.0, 12)
	glow.color = Color(0.9, 0.85, 0.7, 0.18)
	visual.add_child(glow)
	var head = Polygon2D.new()
	head.polygon = _circle(14.0, 10)
	head.color = Color(0.68, 0.66, 0.72, 1.0)
	visual.add_child(head)
	for i in range(6):
		var spike = Polygon2D.new()
		var a := TAU * float(i) / 6.0
		spike.polygon = PackedVector2Array([
			Vector2(cos(a - 0.25), sin(a - 0.25)) * 11.0,
			Vector2(cos(a), sin(a)) * 23.0,
			Vector2(cos(a + 0.25), sin(a + 0.25)) * 11.0])
		spike.color = Color(0.88, 0.86, 0.92, 1.0)
		visual.add_child(spike)
	var gleam = Polygon2D.new()   # one bright facet: motion reads as a flash
	gleam.polygon = PackedVector2Array([
		Vector2(-4, -8), Vector2(3, -11), Vector2(6, -4), Vector2(-1, -2)])
	gleam.color = Color(1.0, 0.98, 0.9, 0.9)
	visual.add_child(gleam)
	rope = Line2D.new()
	rope.width = 4.0
	rope.default_color = Color(0.78, 0.72, 0.6, 0.95)
	rope.z_index = -1
	add_child(rope)

# An angular dart that looks eager to change its mind.
func _build_ricochet() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(15.0, 10)
	glow.color = Color(1.0, 0.85, 0.4, 0.2)
	visual.add_child(glow)
	var dart = Polygon2D.new()
	dart.polygon = PackedVector2Array([
		Vector2(-19, -7), Vector2(17, 0), Vector2(-19, 7), Vector2(-11, 0)])
	dart.color = Color(1.0, 0.88, 0.45, 1.0)
	visual.add_child(dart)

# A pregnant orb with its shards already showing.
func _build_cluster() -> void:
	var glow = Polygon2D.new()
	glow.polygon = _circle(20.0, 12)
	glow.color = Color(0.65, 0.85, 1.0, 0.2)
	visual.add_child(glow)
	var orb = Polygon2D.new()
	orb.polygon = _circle(14.0, 12)
	orb.color = Color(0.7, 0.88, 1.0, 1.0)
	visual.add_child(orb)
	for i in range(4):
		var sat = Polygon2D.new()
		var a := TAU * float(i) / 4.0 + 0.4
		sat.polygon = _circle(4.5, 6)
		sat.position = Vector2(cos(a), sin(a)) * 11.0
		sat.color = Color(1.0, 1.0, 1.0, 1.0)
		visual.add_child(sat)

# The mortar shot: a heavy orb with a sputtering fuse.
func _build_lob() -> void:
	var glow = Polygon2D.new()   # the fuse-light carries the shell in the dark
	glow.polygon = _circle(17.0, 10)
	glow.color = Color(1.0, 0.6, 0.25, 0.2)
	visual.add_child(glow)
	var shell = Polygon2D.new()
	shell.polygon = _circle(13.0, 12)
	shell.color = Color(0.5, 0.46, 0.44, 1.0)
	visual.add_child(shell)
	var band = Polygon2D.new()
	band.polygon = PackedVector2Array([
		Vector2(-10, -2), Vector2(10, -2), Vector2(10, 2), Vector2(-10, 2)])
	band.color = Color(0.85, 0.55, 0.2, 1.0)
	visual.add_child(band)
	var fuse = CPUParticles2D.new()
	fuse.amount = 8
	fuse.lifetime = 0.3
	fuse.position = Vector2(0, -10)
	fuse.initial_velocity_min = 20.0
	fuse.initial_velocity_max = 40.0
	fuse.color = Color(1.0, 0.8, 0.3, 0.9)
	visual.add_child(fuse)

# The lash ribbon: a long tapering flame-tongue.
func _build_lash() -> void:
	var ribbon = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(11):
		var x := lerpf(-30.0, 26.0, float(i) / 10.0)
		pts.append(Vector2(x, -4.5 * (1.0 - absf(x) / 32.0) - sin(x * 0.25) * 2.0))
	for i in range(11):
		var x := lerpf(26.0, -30.0, float(i) / 10.0)
		pts.append(Vector2(x, 4.5 * (1.0 - absf(x) / 32.0) - sin(x * 0.25) * 2.0))
	ribbon.polygon = pts
	ribbon.color = Color(1.0, 0.65, 0.3, 1.0)
	visual.add_child(ribbon)
	var edge = Polygon2D.new()
	edge.polygon = PackedVector2Array([
		Vector2(14, -3), Vector2(34, 0), Vector2(14, 3)])
	edge.color = Color(1.0, 0.95, 0.6, 1.0)
	visual.add_child(edge)
	# a warm trail-glow so the weave reads as a burning ribbon in the dark
	var glow = Polygon2D.new()
	glow.polygon = _circle(16.0, 10)
	glow.color = Color(1.0, 0.7, 0.3, 0.18)
	visual.add_child(glow)
	visual.move_child(glow, 0)

func _build_hook() -> void:
	var curve = Line2D.new()   # the hook itself: a J-curve
	curve.width = 4.0
	curve.default_color = Color(0.75, 0.78, 0.85, 1.0)
	var pts = PackedVector2Array()
	for i in range(8):
		var a = lerp(-PI * 0.15, PI, i / 7.0)
		pts.append(Vector2(10, 0) + Vector2(cos(a), sin(a)) * 9.0)
	curve.points = pts
	visual.add_child(curve)
	rope = Line2D.new()
	rope.width = 2.0
	rope.default_color = Color(0.5, 0.42, 0.3, 0.9)
	rope.z_index = -1
	add_child(rope)

func _build_boomerang() -> void:
	for ang in [0.0, PI * 0.5]:   # two blades in a V
		var blade = Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(22, -4), Vector2(24, 0), Vector2(22, 4)])
		blade.color = Color(0.35, 0.8, 0.75, 0.95)
		blade.rotation = ang
		visual.add_child(blade)

# ==========================================================================
# TIER 6, BATCH 1. Six weapons off the crowded verbs (arc/cleave/orbiter/
# lob_a/rapid/ricochet/chain_maul). Each reuses an engine already standing --
# standing zones, the nova, the chain-maul flight, the embedded stack -- so
# the tier gets souls without six bespoke physics implementations.
# ==========================================================================

# --- HUSHFALL: the blow lands in silence, the SOUND arrives late ----------
var _hush_t := 0.0
var _hush_ring: Polygon2D = null
const HUSH_DELAY := 0.55

func _tick_late_thunder(delta: float) -> void:
	_hush_t += delta
	var frac: float = clampf(_hush_t / HUSH_DELAY, 0.0, 1.0)
	# the held breath: a ring of quiet CONTRACTING toward the point, so the
	# eye knows something is coming back for them
	if _hush_ring != null and is_instance_valid(_hush_ring):
		_hush_ring.scale = Vector2.ONE * lerpf(2.5, 0.35, frac * frac)
		_hush_ring.modulate.a = 0.16 + 0.5 * frac
	if _hush_t < HUSH_DELAY:
		return
	# ...and then the sound catches up
	_nova_burst_tinted(global_position, Color(0.78, 0.88, 1.0))
	done = true
	queue_free()

func _build_late_thunder() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_hush_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * 26.0)
	for i in range(20):
		var a2 := TAU * float(19 - i) / 20.0
		pts.append(Vector2(cos(a2), sin(a2)) * 22.0)
	_hush_ring.polygon = pts
	_hush_ring.color = Color(0.8, 0.9, 1.0, 0.3)
	_hush_ring.material = m
	visual.add_child(_hush_ring)

# --- ECLIPSE WHEEL: the wheel goes dark, and its SHADOW is the attack -----
var _ecl_t := 0.0
var _ecl_home := Vector2.ZERO
var _ecl_shadow: Polygon2D = null
var _ecl_struck := false
# FILM NOTE: at 0.38 it went dark about a step from the player's hand, which
# wasted the whole image -- the eclipse wants ROOM around it.
const ECL_OUT := 0.34          # time flying to the eclipse point
const ECL_HOLD := 0.5          # how long it stays dark
const ECL_SHADOW_LEN := 190.0

func _tick_eclipse(delta: float) -> void:
	_ecl_t += delta
	if _ecl_home == Vector2.ZERO and is_instance_valid(source):
		_ecl_home = (source as Node2D).global_position
	if _ecl_t <= ECL_OUT:
		# out along the aim, spinning up
		global_position += direction * speed * delta
		if visual:
			visual.rotation += 13.0 * delta
		return
	if _ecl_t <= ECL_OUT + ECL_HOLD:
		# THE ECLIPSE: it stops, goes black, and throws a long shadow onward
		if visual:
			visual.rotation += 2.0 * delta
		if _ecl_shadow == null:
			_go_dark()
		if not _ecl_struck:
			_ecl_struck = true
			_strike_shadow()
		return
	# and comes back to the hand
	var home: Vector2 = (source as Node2D).global_position \
		if is_instance_valid(source) else _ecl_home
	var to_home: Vector2 = home - global_position
	if to_home.length() < 26.0:
		done = true
		queue_free()
		return
	global_position += to_home.normalized() * (speed * 1.25) * delta
	if visual:
		visual.rotation += 16.0 * delta

func _go_dark() -> void:
	# the disc itself eats its own light
	if visual:
		for c in visual.get_children():
			if c is Polygon2D:
				(c as Polygon2D).color = Color(0.06, 0.05, 0.10, 0.98)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the corona: the only bright thing left
	var cor := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(22):
		var a := TAU * float(i) / 22.0
		pts.append(Vector2(cos(a), sin(a)) * 25.0)
	for i in range(22):
		var a2 := TAU * float(21 - i) / 22.0
		pts.append(Vector2(cos(a2), sin(a2)) * 20.0)
	cor.polygon = pts
	cor.color = Color(1.0, 0.94, 0.72, 0.85)
	cor.material = m
	if visual:
		visual.add_child(cor)
	# the shadow it casts, thrown AWAY from the player
	_ecl_shadow = Polygon2D.new()
	_ecl_shadow.polygon = PackedVector2Array([
		Vector2(0, -15.0), Vector2(ECL_SHADOW_LEN, -30.0),
		Vector2(ECL_SHADOW_LEN, 30.0), Vector2(0, 15.0)])
	_ecl_shadow.color = Color(0.05, 0.04, 0.09, 0.62)
	_ecl_shadow.z_index = -2
	_ecl_shadow.rotation = direction.angle()
	add_child(_ecl_shadow)
	# FILM NOTE: black-on-night is invisible. The band only reads if its EDGES
	# do, so the shadow gets two lit rims -- the light going around the disc.
	for s in [-1.0, 1.0]:
		var rim := Polygon2D.new()
		rim.polygon = PackedVector2Array([
			Vector2(0, 15.0 * s), Vector2(ECL_SHADOW_LEN, 30.0 * s),
			Vector2(ECL_SHADOW_LEN, 26.0 * s), Vector2(0, 11.5 * s)])
		rim.color = Color(0.86, 0.78, 1.0, 0.5)
		rim.material = m
		rim.z_index = -1
		rim.rotation = direction.angle()
		add_child(rim)
		var rt := rim.create_tween()
		rt.tween_property(rim, "modulate:a", 0.0, ECL_HOLD)
	var tw := _ecl_shadow.create_tween()
	tw.tween_property(_ecl_shadow, "modulate:a", 0.0, ECL_HOLD)

func _strike_shadow() -> void:
	# everything standing in the cast shadow, once
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 0.85)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			var along: float = rel.dot(direction)
			if along < 0.0 or along > ECL_SHADOW_LEN:
				continue
			if absf(rel.dot(Vector2(-direction.y, direction.x))) > 34.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, true)
			_apply_status_to(e)

func _build_eclipse_disc() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 20.0)
	for i in range(16):
		var a2 := TAU * float(15 - i) / 16.0
		pts.append(Vector2(cos(a2), sin(a2)) * 13.0)
	rim.polygon = pts
	rim.color = Color(0.86, 0.84, 0.96, 0.9)
	rim.material = m
	visual.add_child(rim)
	# four spokes so the spin is legible
	for k in range(4):
		var spoke := Polygon2D.new()
		spoke.polygon = PackedVector2Array([
			Vector2(-2.2, -14.0), Vector2(2.2, -14.0), Vector2(2.2, 14.0), Vector2(-2.2, 14.0)])
		spoke.color = Color(0.7, 0.68, 0.85, 0.8)
		spoke.rotation = deg_to_rad(45.0 * float(k))
		visual.add_child(spoke)

# --- COMETFALL: up, over, and DOWN in a burning line ----------------------
var _comet_vy := 0.0
var _comet_t := 0.0

func _tick_comet(delta: float) -> void:
	_comet_t += delta
	_comet_vy += 1150.0 * delta          # heavier than a lob: it FALLS
	global_position += direction * speed * delta + Vector2(0, _comet_vy * delta)
	var vel := direction * speed + Vector2(0, _comet_vy)
	rotation = vel.angle()
	# it brightens as it comes down -- a comet is only a comet on the way in
	if visual and _comet_vy > 0.0:
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + minf(0.5, _comet_vy / 1400.0))
	traveled += speed * delta
	if _comet_t > 0.16 and _on_floor_now():
		_comet_land()

func _comet_land() -> void:
	_nova_burst_tinted(global_position, Color(1.0, 0.66, 0.3))
	_rock_smoke(global_position)
	# the crater keeps burning: a standing patch of fire, the reason you lob
	# it AHEAD of something rather than at it
	var host := get_parent()
	if host != null:
		var patch = (load("res://weapon_projectile.gd") as GDScript).new()
		patch.kind = "cinder_patch"
		patch.damage = maxi(1, int(round(float(damage) * 0.3)))
		patch.element = element
		patch.on_hit_status = on_hit_status
		patch.source = source
		patch.girth = girth
		host.add_child(patch)
		patch.global_position = global_position
	done = true
	queue_free()

# a cheap floor probe: the world's ground sits on the terrain layer
func _on_floor_now() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 16.0))
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()

func _build_comet() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-14, -6.0), Vector2(-42, -2.4), Vector2(-64, 0),
		Vector2(-42, 2.4), Vector2(-14, 6.0)])
	tail.color = Color(1.0, 0.62, 0.24, 0.45)
	tail.material = m
	visual.add_child(tail)
	var head := Polygon2D.new()
	head.polygon = _circle(11.0, 12)
	head.color = Color(1.0, 0.9, 0.62, 0.98)
	visual.add_child(head)
	var halo := Polygon2D.new()
	halo.polygon = _circle(17.0, 12)
	halo.color = Color(1.0, 0.72, 0.35, 0.4)
	halo.material = m
	visual.add_child(halo)

# the burning crater left behind
func _build_cinder_patch() -> void:
	_zone_max = 3.4
	_zone_r = 62.0
	_zone_gap = 0.42
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pool := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * 58.0, sin(a) * 15.0))
	pool.polygon = pts
	pool.color = Color(1.0, 0.42, 0.12, 0.6)
	pool.material = m
	visual.add_child(pool)
	for k in range(5):
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([
			Vector2(-5.0, 0), Vector2(0, -19.0), Vector2(5.0, 0)])
		flame.color = Color(1.0, 0.6, 0.16, 0.85)
		flame.material = m
		flame.position = Vector2(-42.0 + 21.0 * float(k), -2.0)
		visual.add_child(flame)
		var tw := flame.create_tween().set_loops()
		tw.tween_property(flame, "scale", Vector2(0.75, 1.35), 0.26)
		tw.tween_property(flame, "scale", Vector2(1.1, 0.8), 0.22)

# --- CINDERCHAIN: the head drags, and the ground it crosses catches -------
var _cinder_drop := 0.0

func _tick_cinder_drag(delta: float) -> void:
	_tick_chainmaul(delta)
	if done:
		return
	_cinder_drop -= delta
	if _cinder_drop > 0.0:
		return
	_cinder_drop = 0.19
	# a small ember where the head is now -- a TRAIL of them draws the arc of
	# the swing on the floor, which is the whole reason to hold this thing
	var host := get_parent()
	if host == null:
		return
	var em := Polygon2D.new()
	em.polygon = _circle(randf_range(4.0, 7.5), 7)
	em.color = Color(1.0, randf_range(0.45, 0.7), 0.2, 0.75)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	em.material = m
	em.z_index = 38
	host.add_child(em)
	em.global_position = global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
	var tw := em.create_tween()
	tw.set_parallel(true)
	tw.tween_property(em, "global_position:y", em.global_position.y + 22.0, 0.5)
	tw.tween_property(em, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(em.queue_free)

# --- WATCHFIRE: it holds its fire until something crosses the light -------
# The generic `sentry` shoots on a timer and the T7 Asphodel Post sends
# constantly; this one does NOTHING until a body enters its ring, which makes
# where you plant it the whole decision.
var _watch_t := 0.0
var _watch_cool := 0.0
var _watch_eye: Polygon2D = null
var _watch_ring: Polygon2D = null
const WATCH_LIFE := 11.0
const WATCH_SEE := 132.0
const WATCH_RECOVER := 1.1

func _tick_watch_fire(delta: float) -> void:
	_watch_t += delta
	if _watch_t >= WATCH_LIFE:
		done = true
		queue_free()
		return
	_watch_cool = maxf(0.0, _watch_cool - delta)
	# banked while it waits, blinding when it catches something
	var banked: bool = _watch_cool > 0.0
	if _watch_eye != null and is_instance_valid(_watch_eye):
		var breathe: float = 0.55 + 0.2 * sin(_watch_t * 3.4)
		_watch_eye.modulate.a = 0.3 if banked else breathe
		_watch_eye.scale = Vector2.ONE * (0.7 if banked else (0.9 + 0.14 * sin(_watch_t * 3.4)))
	if _watch_ring != null and is_instance_valid(_watch_ring):
		_watch_ring.modulate.a = 0.08 if banked else 0.2
	if banked:
		return
	var seen := _nearest_hostile_node(WATCH_SEE)
	if seen == null:
		return
	_watch_flare(seen)

func _watch_flare(_seen: Node2D) -> void:
	_watch_cool = WATCH_RECOVER
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > WATCH_SEE * 1.15:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, false)
			_apply_status_to(e)
	# the flare itself: a hard ring of light thrown out from the post
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var flash := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a), sin(a)) * 30.0)
	for i in range(18):
		var a2 := TAU * float(17 - i) / 18.0
		pts.append(Vector2(cos(a2), sin(a2)) * 23.0)
	flash.polygon = pts
	flash.color = Color(1.0, 0.82, 0.42, 0.9)
	flash.material = m
	flash.z_index = 44
	host.add_child(flash)
	flash.global_position = global_position
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(4.2, 4.2), 0.3)
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(flash.queue_free)

func _build_watch_fire() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the ring it watches: faint, so you can SEE where the trap is armed
	_watch_ring = Polygon2D.new()
	var rp := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		rp.append(Vector2(cos(a) * WATCH_SEE, sin(a) * WATCH_SEE * 0.42))
	for i in range(24):
		var a2 := TAU * float(23 - i) / 24.0
		rp.append(Vector2(cos(a2) * (WATCH_SEE - 4.0), sin(a2) * (WATCH_SEE - 4.0) * 0.42))
	_watch_ring.polygon = rp
	_watch_ring.color = Color(1.0, 0.78, 0.4, 0.2)
	_watch_ring.material = m
	_watch_ring.z_index = -1
	visual.add_child(_watch_ring)
	# a low iron cresset on three legs
	for leg_i in range(3):
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0.8, 16.0), Vector2(-0.8, 16.0)])
		leg.color = Color(0.26, 0.23, 0.24, 0.95)
		leg.rotation = deg_to_rad(-22.0 + 22.0 * float(leg_i))
		visual.add_child(leg)
	var bowl := Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-13, -2.0), Vector2(13, -2.0), Vector2(9, 6.0), Vector2(-9, 6.0)])
	bowl.color = Color(0.3, 0.27, 0.28, 0.98)
	visual.add_child(bowl)
	_watch_eye = Polygon2D.new()
	_watch_eye.polygon = PackedVector2Array([
		Vector2(-7.0, -3.0), Vector2(0, -20.0), Vector2(7.0, -3.0)])
	_watch_eye.color = Color(1.0, 0.74, 0.32, 0.8)
	_watch_eye.material = m
	_watch_eye.position = Vector2(0, -2.0)
	visual.add_child(_watch_eye)

# --- THE DEBT COLLECTOR: a seal that outlives the debtor ------------------
func _build_debt_mark() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = _circle(14.0, 12)
	halo.color = Color(0.95, 0.82, 0.38, 0.35)
	halo.material = m
	visual.add_child(halo)
	# a coin on edge, turning: the collector's calling card
	var coin := Polygon2D.new()
	coin.polygon = _circle(8.5, 10)
	coin.color = Color(0.98, 0.88, 0.46, 0.96)
	visual.add_child(coin)
	var inner := Polygon2D.new()
	inner.polygon = _circle(4.0, 8)
	inner.color = Color(0.62, 0.46, 0.14, 0.9)
	visual.add_child(inner)
	var tw := coin.create_tween().set_loops()
	tw.tween_property(coin, "scale", Vector2(0.25, 1.0), 0.34)
	tw.tween_property(coin, "scale", Vector2(1.0, 1.0), 0.34)

# ==========================================================================
# TIER 6, BATCH 2.
# ==========================================================================

# --- HORIZON PIKE: it does not thrust once, it TELESCOPES ----------------
var _pike_t := 0.0
var _pike_stage := 0
var _pike_segs: Array = []
const PIKE_STAGES := 3
const PIKE_GAP := 0.11
const PIKE_SEG := 62.0

func _tick_stage_pike(delta: float) -> void:
	_pike_t += delta
	if _pike_stage < PIKE_STAGES and _pike_t >= float(_pike_stage) * PIKE_GAP:
		_punch_segment(_pike_stage)
		_pike_stage += 1
		return
	if _pike_t >= float(PIKE_STAGES) * PIKE_GAP + 0.24:
		# it draws back the way it went out
		for s in _pike_segs:
			if is_instance_valid(s):
				var tw := (s as Node2D).create_tween()
				tw.tween_property(s, "scale", Vector2(0.05, 1.0), 0.14)
		done = true
		var ft := create_tween()
		ft.tween_interval(0.16)
		ft.tween_callback(queue_free)

# each stage is a NEW length of pike shoved out past the last, and each one
# bites on its own -- three separate hits down one line
func _punch_segment(idx: int) -> void:
	var near: float = float(idx) * PIKE_SEG
	var far: float = near + PIKE_SEG
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var seg := Polygon2D.new()
	var taper: float = 5.2 - 1.1 * float(idx)
	seg.polygon = PackedVector2Array([
		Vector2(near, -taper), Vector2(far - 9.0, -taper * 0.8),
		Vector2(far, 0), Vector2(far - 9.0, taper * 0.8), Vector2(near, taper)])
	seg.color = Color(0.94, 0.9, 0.72, 0.92 - 0.12 * float(idx))
	seg.material = m
	seg.rotation = direction.angle()
	add_child(seg)
	_pike_segs.append(seg)
	seg.scale = Vector2(0.05, 1.0)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale", Vector2.ONE, 0.07)
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * (1.0 - 0.16 * float(idx)))))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			var along: float = rel.dot(direction)
			if along < near or along > far:
				continue
			if absf(rel.dot(Vector2(-direction.y, direction.x))) > 30.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, idx == PIKE_STAGES - 1)
			_apply_status_to(e)

func _build_stage_pike() -> void:
	var grip := Polygon2D.new()
	grip.polygon = PackedVector2Array([
		Vector2(-16, -2.6), Vector2(4, -2.6), Vector2(4, 2.6), Vector2(-16, 2.6)])
	grip.color = Color(0.4, 0.36, 0.3, 0.95)
	grip.rotation = direction.angle()
	visual.add_child(grip)

# --- THE DELUGE: a wall of water that GROWS as it runs --------------------
var _flood_t := 0.0
var _flood_body: Polygon2D = null
const FLOOD_LIFE := 1.5

func _tick_flood(delta: float) -> void:
	_flood_t += delta
	global_position += direction * speed * delta
	var grow: float = 1.0 + 1.5 * (_flood_t / FLOOD_LIFE)
	if _flood_body != null and is_instance_valid(_flood_body):
		_flood_body.scale = Vector2(1.0, grow)
		_flood_body.modulate.a = 1.0 - 0.5 * (_flood_t / FLOOD_LIFE)
	_rehit_t += delta
	if _rehit_t >= 0.2:
		_rehit_t = 0.0
		hit_bodies.clear()   # the water keeps arriving
	# it SHOVES more than it wounds: everything it reaches goes with it
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if e in hit_bodies:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			if absf(rel.dot(direction)) > 30.0 or absf(rel.y) > 46.0 * grow:
				continue
			hit_bodies.append(e)
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if direction.x >= 0.0 else -1, 190.0)
	if _flood_t >= FLOOD_LIFE:
		done = true
		queue_free()

func _build_flood_wave() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flood_body = Polygon2D.new()
	# a curling front, not a rectangle: the crest leans the way it travels
	_flood_body.polygon = PackedVector2Array([
		Vector2(-18, 30.0), Vector2(-14, -8.0), Vector2(-4, -34.0),
		Vector2(10, -42.0), Vector2(20, -30.0), Vector2(6, -22.0),
		Vector2(12, -4.0), Vector2(16, 30.0)])
	_flood_body.color = Color(0.42, 0.72, 0.95, 0.62)
	_flood_body.material = m
	visual.add_child(_flood_body)
	var foam := Polygon2D.new()
	foam.polygon = PackedVector2Array([
		Vector2(-6, -30.0), Vector2(12, -40.0), Vector2(18, -28.0), Vector2(2, -20.0)])
	foam.color = Color(0.9, 0.97, 1.0, 0.8)
	foam.material = m
	visual.add_child(foam)

# --- LODESTAR: it becomes TRUE NORTH and the room leans toward it --------
var _lode_t := 0.0
var _lode_anchor: Node2D = null
const LODE_LIFE := 3.0
const LODE_PULL_R := 300.0

func _tick_lodestar(delta: float) -> void:
	if _lode_anchor == null:
		# still flying: the first thing it touches becomes the star
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance:
			_lode_plant(global_position)
		return
	if is_instance_valid(_lode_anchor) and not ("is_dead" in _lode_anchor and _lode_anchor.is_dead):
		global_position = _lode_anchor.global_position
	_lode_t += delta
	if visual:
		visual.rotation += 2.2 * delta
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.16 * sin(_lode_t * 7.0))
	# everything else in the room leans in
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or e == _lode_anchor:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var to_star: Vector2 = global_position - (e as Node2D).global_position
			var d: float = to_star.length()
			if d < 24.0 or d > LODE_PULL_R:
				continue
			(e as Node2D).global_position += to_star.normalized() * 92.0 * delta
	if _lode_t >= LODE_LIFE:
		# and then the star goes out, all at once, on the crowd it gathered
		_nova_burst_tinted(global_position, Color(0.72, 0.86, 1.0))
		done = true
		queue_free()

func _lode_plant(at: Vector2, victim: Node2D = null) -> void:
	_lode_anchor = victim
	global_position = at
	if victim == null:
		# nothing hit: it still hangs there and gathers
		_lode_anchor = self
	speed = 0.0

func _build_lodestar() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0 - PI * 0.5
		pts.append(Vector2(cos(a), sin(a)) * (17.0 if i % 2 == 0 else 6.0))
	star.polygon = pts
	star.color = Color(0.86, 0.93, 1.0, 0.95)
	star.material = m
	visual.add_child(star)
	var core := Polygon2D.new()
	core.polygon = _circle(5.0, 8)
	core.color = Color(1.0, 1.0, 1.0, 0.98)
	core.material = m
	visual.add_child(core)

# --- SECOND MOON: it never comes back. It ORBITS, and it has PHASES ------
var _moon_t := 0.0
var _moon_dark: Polygon2D = null
# ONE MOON. The dps gate caught this at 233 vs a tier median of 72: the moon
# outlived its own 0.85s cooldown by ten times, so you could stack a sky full
# of them. It is capped to a single instance (see MOON_GROUP), and a recast
# renews the one you have rather than adding another.
const MOON_GROUP := "second_moon_instance"
const MOON_LIFE := 6.0
const MOON_BITE := 0.5
const MOON_PERIOD := 2.6      # one full wax-and-wane

func _tick_moon(delta: float) -> void:
	_moon_t += delta
	if _moon_t >= MOON_LIFE or not is_instance_valid(source):
		done = true
		queue_free()
		return
	# lifted off the floor: at a flat orbit the moon spent half its life buried
	# in the terrain, which is not where a moon goes
	var centre: Vector2 = (source as Node2D).global_position + Vector2(0, -46.0)
	var ang: float = _moon_t * 2.5
	global_position = centre + Vector2(cos(ang), sin(ang) * 0.42) * 96.0
	# the phase: full moon bites hard, new moon barely at all -- the weapon
	# has a RHYTHM you can read off the sky instead of a cooldown bar
	var phase: float = 0.5 + 0.5 * sin(_moon_t * TAU / MOON_PERIOD)
	# the shadow slides OFF as the moon waxes. This ran backwards at first --
	# the disc went black at phase 1, so it looked deadest exactly when it hit
	# hardest, and the whole read-it-off-the-sky idea was inverted.
	# It must also FADE as it goes, or the shadow slides clear of the disc and
	# reads as a second, separate black object floating beside the moon.
	if _moon_dark != null and is_instance_valid(_moon_dark):
		_moon_dark.position = Vector2(lerpf(0.0, -26.0, phase), 0.0)
		_moon_dark.modulate.a = 1.0 - phase * 0.95
	_rehit_t += delta
	if _rehit_t < MOON_BITE:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * (0.25 + 0.75 * phase))))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > 40.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, phase > 0.85)
			_apply_status_to(e)

func _build_moon_orbit() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var disc := Polygon2D.new()
	disc.polygon = _circle(15.0, 16)
	disc.color = Color(0.9, 0.92, 0.82, 0.96)
	visual.add_child(disc)
	var halo := Polygon2D.new()
	halo.polygon = _circle(21.0, 16)
	halo.color = Color(0.8, 0.86, 1.0, 0.3)
	halo.material = m
	visual.add_child(halo)
	# the shadow that slides across it: the phase made literal
	_moon_dark = Polygon2D.new()
	_moon_dark.polygon = _circle(15.0, 16)
	_moon_dark.color = Color(0.07, 0.07, 0.12, 0.94)
	visual.add_child(_moon_dark)

# --- SHATTERHYMN: a glass note that BREAKS into ringing splinters ---------
func _shatter_note(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(7):
		var sh := Polygon2D.new()
		var w: float = randf_range(2.4, 4.4)
		sh.polygon = PackedVector2Array([
			Vector2(0, -randf_range(9.0, 16.0)), Vector2(w, 0), Vector2(0, w * 1.6), Vector2(-w, 0)])
		sh.color = Color(0.78, 0.92, 1.0, 0.9)
		sh.material = m
		sh.z_index = 43
		host.add_child(sh)
		sh.global_position = at
		var a := TAU * float(i) / 7.0 + randf_range(-0.2, 0.2)
		var fly: Vector2 = at + Vector2(cos(a), sin(a)) * randf_range(52.0, 92.0) + Vector2(0, 26.0)
		sh.rotation = a
		var tw := sh.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sh, "global_position", fly, 0.62).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sh, "rotation", a + randf_range(-2.4, 2.4), 0.62)
		tw.tween_property(sh, "modulate:a", 0.0, 0.62)
		tw.chain().tween_callback(sh.queue_free)

func _build_glass_note() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var bell := Polygon2D.new()
	bell.polygon = PackedVector2Array([
		Vector2(0, -14.0), Vector2(9, -2.0), Vector2(11, 10.0),
		Vector2(-11, 10.0), Vector2(-9, -2.0)])
	bell.color = Color(0.7, 0.88, 1.0, 0.72)
	bell.material = m
	visual.add_child(bell)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-4, -10.0), Vector2(-1, -10.0), Vector2(-2, 6.0), Vector2(-6, 6.0)])
	shine.color = Color(1.0, 1.0, 1.0, 0.85)
	shine.material = m
	visual.add_child(shine)

# --- DAWN'S LONG TONGUE: a whip that LENGTHENS while it keeps landing ----
func _build_long_tongue() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(3):
		var strand := Polygon2D.new()
		var sway: float = -5.0 + 5.0 * float(i)
		strand.polygon = PackedVector2Array([
			Vector2(-30, sway * 0.2), Vector2(2, sway), Vector2(30, sway * 0.5),
			Vector2(30, sway * 0.5 + 2.2), Vector2(2, sway + 2.6), Vector2(-30, sway * 0.2 + 2.0)])
		strand.color = Color(1.0, 0.84 - 0.1 * float(i), 0.46, 0.85 - 0.18 * float(i))
		strand.material = m
		visual.add_child(strand)
	var tip := Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(38, 0), Vector2(26, -5.0), Vector2(26, 5.0)])
	tip.color = Color(1.0, 0.95, 0.7, 0.95)
	tip.material = m
	visual.add_child(tip)

# ==========================================================================
# TIER 6, BATCH 3.
# ==========================================================================

# --- THE WORLD-ANVIL: struck once, it RINGS DOWN three times -------------
var _toll_t := 0.0
var _toll_n := 0
const TOLL_GAP := 0.3

func _tick_toll(delta: float) -> void:
	_toll_t += delta
	if _toll_n < 3 and _toll_t >= float(_toll_n) * TOLL_GAP:
		# each toll is quieter and tighter than the last: a bell dying, not
		# three copies of the same blow
		var fall: float = 1.0 - 0.28 * float(_toll_n)
		_toll_ring(fall)
		_toll_n += 1
		return
	if _toll_t >= 3.0 * TOLL_GAP + 0.3:
		done = true
		queue_free()

func _toll_ring(fall: float) -> void:
	var host := get_parent()
	var r: float = 128.0 * fall
	var pay: int = maxi(1, int(round(float(damage) * fall * 0.55)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > r:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, fall > 0.9)
			_apply_status_to(e)
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(22):
		var a := TAU * float(i) / 22.0
		pts.append(Vector2(cos(a) * 26.0, sin(a) * 11.0))
	for i in range(22):
		var a2 := TAU * float(21 - i) / 22.0
		pts.append(Vector2(cos(a2) * 21.0, sin(a2) * 8.0))
	ring.polygon = pts
	ring.color = Color(0.96, 0.88, 0.62, 0.5 + 0.4 * fall)
	ring.material = m
	ring.z_index = 43
	host.add_child(ring)
	ring.global_position = global_position
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * (r / 24.0), 0.34)
	tw.tween_property(ring, "modulate:a", 0.0, 0.34)
	tw.chain().tween_callback(ring.queue_free)

func _build_anvil_toll() -> void:
	pass   # the tolls draw themselves; the striker leaves nothing standing

# --- HORIZONRENDER: the crescent SPLITS, parts, and closes again ---------
var _rend_t := 0.0
var _rend_side := 1.0
var _rend_origin := Vector2.ZERO
const REND_SPREAD := 62.0
const REND_PERIOD := 0.85

func _tick_rend(delta: float) -> void:
	_rend_t += delta
	if _rend_origin == Vector2.ZERO:
		_rend_origin = global_position
	# out along the aim, but bowing away from its twin and then back in --
	# the two halves cross again right where they started apart
	var lateral: float = sin(clampf(_rend_t / REND_PERIOD, 0.0, 1.0) * PI) * REND_SPREAD * _rend_side
	var perp := Vector2(-direction.y, direction.x)
	traveled += speed * delta
	global_position = _rend_origin + direction * traveled + perp * lateral
	rotation = direction.angle() + lateral * 0.006
	_rehit_t += delta
	if _rehit_t >= 0.3:
		_rehit_t = 0.0
		hit_bodies.clear()
	if traveled >= max_distance:
		done = true
		queue_free()

func set_rend_side(s: float) -> void:
	_rend_side = s

func _build_rend_half() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(4, -17.0), Vector2(-16, -13.0),
		Vector2(-8, 0), Vector2(-16, 13.0), Vector2(4, 17.0)])
	blade.color = Color(0.82, 0.9, 1.0, 0.85)
	blade.material = m
	visual.add_child(blade)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([
		Vector2(28, 0), Vector2(8, -9.0), Vector2(-6, 0), Vector2(8, 9.0)])
	edge.color = Color(1.0, 1.0, 1.0, 0.9)
	edge.material = m
	visual.add_child(edge)

# --- A PIECE OF THE SUN: it hangs, and SWEEPS a beam ---------------------
var _sun_t := 0.0
var _sun_hung := false
var _sun_vy := 0.0
var _sun_beam: Polygon2D = null
const SUNP_HANG := 3.6
const SUNP_BEAM := 210.0

func _tick_sunpiece(delta: float) -> void:
	if not _sun_hung:
		_sun_vy += 620.0 * delta
		global_position += direction * speed * delta + Vector2(0, _sun_vy * delta)
		traveled += speed * delta
		if traveled >= max_distance or _sun_vy > 340.0:
			_sun_hung = true
			speed = 0.0
			_hang_sun()
		return
	_sun_t += delta
	if _sun_t >= SUNP_HANG:
		_nova_burst_tinted(global_position, Color(1.0, 0.82, 0.4))
		done = true
		queue_free()
		return
	# the beam turns like a lighthouse; standing still is not an option
	var ang: float = _sun_t * 2.3
	if _sun_beam != null and is_instance_valid(_sun_beam):
		_sun_beam.rotation = ang
	if visual:
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.1 * sin(_sun_t * 9.0))
	_rehit_t += delta
	if _rehit_t < 0.3:
		return
	_rehit_t = 0.0
	var sweep := Vector2(cos(ang), sin(ang))
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 0.5)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			var along: float = rel.dot(sweep)
			if along < 0.0 or along > SUNP_BEAM:
				continue
			if absf(rel.dot(Vector2(-sweep.y, sweep.x))) > 30.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)

func _hang_sun() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sun_beam = Polygon2D.new()
	_sun_beam.polygon = PackedVector2Array([
		Vector2(0, -9.0), Vector2(SUNP_BEAM, -26.0),
		Vector2(SUNP_BEAM, 26.0), Vector2(0, 9.0)])
	_sun_beam.color = Color(1.0, 0.86, 0.44, 0.3)
	_sun_beam.material = m
	_sun_beam.z_index = -1
	add_child(_sun_beam)

func _build_sun_piece() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var corona := Polygon2D.new()
	corona.polygon = _circle(20.0, 14)
	corona.color = Color(1.0, 0.7, 0.26, 0.4)
	corona.material = m
	visual.add_child(corona)
	var core := Polygon2D.new()
	core.polygon = _circle(11.0, 12)
	core.color = Color(1.0, 0.95, 0.72, 0.98)
	core.material = m
	visual.add_child(core)

# --- PERMAFROST DECREE: a sheet of ice that KEEPS SPREADING ---------------
var _ice_t := 0.0
const ICE_LIFE := 5.0
const ICE_R0 := 40.0
const ICE_R1 := 128.0

func _tick_ice_sheet(delta: float) -> void:
	_ice_t += delta
	var frac: float = clampf(_ice_t / ICE_LIFE, 0.0, 1.0)
	var r: float = lerpf(ICE_R0, ICE_R1, frac)
	if visual:
		visual.scale = Vector2.ONE * _draw_girth * (r / ICE_R0)
		visual.modulate.a = 1.0 - frac * frac * 0.7
	if _ice_t >= ICE_LIFE:
		done = true
		queue_free()
		return
	_zone_t += delta
	if _zone_t < 0.45:
		return
	_zone_t = 0.0
	var host := get_parent()
	# the longer the sheet has been growing the DEEPER the cold bites
	var pay: int = maxi(1, int(round(float(damage) * (0.5 + 0.9 * frac))))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > r:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, false)
			if e.has_method("apply_status"):
				e.apply_status("slow", 1.4, 0.3 + 0.35 * frac)
			_apply_status_to(e)

func _build_ice_sheet() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sheet := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(15):
		var a := TAU * float(i) / 15.0
		var wob: float = 1.0 + 0.16 * sin(float(i) * 2.7)
		pts.append(Vector2(cos(a) * ICE_R0 * wob, sin(a) * ICE_R0 * 0.3 * wob))
	sheet.polygon = pts
	sheet.color = Color(0.62, 0.86, 1.0, 0.4)
	sheet.material = m
	visual.add_child(sheet)
	# shards standing up out of the sheet so it is not just a flat decal
	for k in range(6):
		var sp := Polygon2D.new()
		var h: float = randf_range(9.0, 19.0)
		sp.polygon = PackedVector2Array([
			Vector2(-3.4, 0), Vector2(0, -h), Vector2(3.4, 0)])
		sp.color = Color(0.82, 0.94, 1.0, 0.8)
		sp.material = m
		sp.position = Vector2(-30.0 + 12.0 * float(k), randf_range(-3.0, 4.0))
		visual.add_child(sp)

func _build_silent_note() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# barely there: a shaft you can hardly see is the promise of the weapon
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(10, -1.0), Vector2(-16, -1.0), Vector2(-16, 1.0), Vector2(10, 1.0)])
	shaft.color = Color(0.76, 0.84, 0.96, 0.5)
	shaft.material = m
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(17, 0), Vector2(7, -3.0), Vector2(7, 3.0)])
	head.color = Color(0.9, 0.95, 1.0, 0.72)
	head.material = m
	visual.add_child(head)

func _build_nova_seed() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = _circle(15.0, 12)
	halo.color = Color(0.86, 0.72, 1.0, 0.34)
	halo.material = m
	visual.add_child(halo)
	var seed_core := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * (9.5 if i % 2 == 0 else 4.5))
	seed_core.polygon = pts
	seed_core.color = Color(1.0, 0.94, 1.0, 0.95)
	seed_core.material = m
	visual.add_child(seed_core)
	var tw := seed_core.create_tween().set_loops()
	tw.tween_property(seed_core, "rotation", PI, 0.5)
	tw.tween_property(seed_core, "rotation", TAU, 0.5)

# ==========================================================================
# TIER 6, BATCH 4 -- the last ten. Closes the tier.
# ==========================================================================

# --- WHEEL OF THE HOLLOW: not thrown. It GUARDS. -------------------------
var _hw_t := 0.0
const HW_LIFE := 3.6
const HW_R := 62.0

func _tick_hollow_wheel(delta: float) -> void:
	_hw_t += delta
	if _hw_t >= HW_LIFE or not is_instance_valid(source):
		done = true
		queue_free()
		return
	var centre: Vector2 = (source as Node2D).global_position
	var ang: float = _hw_t * 11.0            # fast: it is a guard, not a moon
	global_position = centre + Vector2(cos(ang), sin(ang) * 0.5) * HW_R
	if visual:
		visual.rotation += 15.0 * delta
	_rehit_t += delta
	if _rehit_t < 0.22:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 0.5)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > 40.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)
			# the point of a guard is that it MOVES them off you
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if (e as Node2D).global_position.x >= centre.x else -1, 210.0)

func _build_hollow_wheel() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 17.0)
	for i in range(14):
		var a2 := TAU * float(13 - i) / 14.0
		pts.append(Vector2(cos(a2), sin(a2)) * 10.0)
	rim.polygon = pts
	rim.color = Color(0.58, 0.5, 0.72, 0.9)
	rim.material = m
	visual.add_child(rim)
	# the HOLLOW: an empty middle you can see the room through
	for k in range(3):
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(-2.4, -20.0), Vector2(2.4, -20.0), Vector2(1.4, -14.0), Vector2(-1.4, -14.0)])
		tooth.color = Color(0.8, 0.74, 0.95, 0.85)
		tooth.material = m
		tooth.rotation = deg_to_rad(120.0 * float(k))
		visual.add_child(tooth)

# --- DIRE PORTENT: a sign hangs over them, and then it FALLS -------------
var _port_t := 0.0
var _port_mark: Node2D = null
var _port_sign: Polygon2D = null
const PORT_WARN := 1.4

func _tick_portent(delta: float) -> void:
	if _port_mark == null:
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance:
			done = true
			queue_free()
		return
	if is_instance_valid(_port_mark) and not ("is_dead" in _port_mark and _port_mark.is_dead):
		global_position = (_port_mark as Node2D).global_position
	_port_t += delta
	var frac: float = clampf(_port_t / PORT_WARN, 0.0, 1.0)
	# the sign sinks toward them as the hour comes: the telegraph IS the fun
	if _port_sign != null and is_instance_valid(_port_sign):
		_port_sign.position = Vector2(0.0, lerpf(-96.0, -26.0, frac * frac))
		_port_sign.rotation = sin(_port_t * 13.0) * (0.06 + 0.22 * frac)
		_port_sign.scale = Vector2.ONE * (1.0 + 0.5 * frac)
	if _port_t < PORT_WARN:
		return
	# and the hour comes
	_nova_burst_tinted(global_position, Color(0.72, 0.5, 0.86))
	done = true
	queue_free()

func _portent_fix(victim: Node2D) -> void:
	_port_mark = victim
	speed = 0.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_port_sign = Polygon2D.new()
	# an omen reads as a SHAPE, not a bar: a downward wedge with an eye
	_port_sign.polygon = PackedVector2Array([
		Vector2(0, 16.0), Vector2(-15.0, -11.0), Vector2(15.0, -11.0)])
	_port_sign.color = Color(0.76, 0.54, 0.92, 0.85)
	_port_sign.material = m
	add_child(_port_sign)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(0, 2.0), Vector2(-5.0, -4.0), Vector2(0, -8.0), Vector2(5.0, -4.0)])
	eye.color = Color(1.0, 0.96, 1.0, 0.95)
	eye.material = m
	_port_sign.add_child(eye)

func _build_portent() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(11, -1.4), Vector2(-15, -1.4), Vector2(-15, 1.4), Vector2(11, 1.4)])
	shaft.color = Color(0.66, 0.5, 0.82, 0.92)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(19, 0), Vector2(8, -4.4), Vector2(8, 4.4)])
	head.color = Color(0.9, 0.78, 1.0, 0.96)
	head.material = m
	visual.add_child(head)

# --- THE LAST COURIER: a ROUTE, not a ricochet ---------------------------
# A ricochet bounces at random and loses an edge each time. A courier keeps a
# list, never knocks twice, and every delivery is the same weight.
var _cour_left := 4
var _cour_seen: Array = []
var _cour_target: Node2D = null

func _tick_courier(delta: float) -> void:
	if _cour_target == null or not is_instance_valid(_cour_target) \
			or ("is_dead" in _cour_target and _cour_target.is_dead):
		_cour_next()
		if _cour_target == null:
			done = true
			queue_free()
			return
	var to_t: Vector2 = (_cour_target as Node2D).global_position - global_position
	if to_t.length() < 20.0:
		_deliver(_cour_target)
		return
	direction = to_t.normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta

func _cour_next() -> void:
	_cour_target = null
	var best_d := 460.0
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or e in _cour_seen:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if not e.has_method("take_damage"):
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				_cour_target = e

func _deliver(who: Node2D) -> void:
	_cour_seen.append(who)
	_cour_left -= 1
	var host := get_parent()
	var landed = who.take_damage(damage)     # no decay: every letter matters
	if landed == null or landed:
		FloatingText.spawn(host, (who as Node2D).global_position
			+ Vector2(randf_range(-16.0, 16.0), -26.0), damage, false)
	_apply_status_to(who)
	if host != null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var seal := Polygon2D.new()
		seal.polygon = _circle(9.0, 8)
		seal.color = Color(0.95, 0.84, 0.5, 0.85)
		seal.material = m
		seal.z_index = 44
		host.add_child(seal)
		seal.global_position = global_position
		var tw := seal.create_tween()
		tw.set_parallel(true)
		tw.tween_property(seal, "scale", Vector2(2.2, 2.2), 0.24)
		tw.tween_property(seal, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(seal.queue_free)
	if _cour_left <= 0:
		done = true
		queue_free()
		return
	_cour_next()

func _build_courier() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var env := Polygon2D.new()
	env.polygon = PackedVector2Array([
		Vector2(-10, -7.0), Vector2(10, -7.0), Vector2(10, 7.0), Vector2(-10, 7.0)])
	env.color = Color(0.94, 0.9, 0.78, 0.95)
	visual.add_child(env)
	var fold := Polygon2D.new()
	fold.polygon = PackedVector2Array([
		Vector2(-10, -7.0), Vector2(10, -7.0), Vector2(0, 1.0)])
	fold.color = Color(0.74, 0.68, 0.56, 0.95)
	visual.add_child(fold)
	var glow := Polygon2D.new()
	glow.polygon = _circle(13.0, 10)
	glow.color = Color(1.0, 0.9, 0.6, 0.28)
	glow.material = m
	visual.add_child(glow)

# --- GRIFFIN VOLLEY: each shaft STOOPS on its own bird ------------------
var _stoop_t := 0.0
var _stoop_prey: Node2D = null

func _tick_stoop(delta: float) -> void:
	_stoop_t += delta
	# it climbs first, then folds and dives -- a stoop, not a homing missile
	if _stoop_t < 0.26:
		global_position += (direction + Vector2(0, -1.5)).normalized() * speed * delta
		rotation = (direction + Vector2(0, -1.5)).angle()
		traveled += speed * delta
		return
	if _stoop_prey == null or not is_instance_valid(_stoop_prey) \
			or ("is_dead" in _stoop_prey and _stoop_prey.is_dead):
		_stoop_prey = _nearest_hostile_node(520.0)
	var aim: Vector2 = direction
	if _stoop_prey != null:
		aim = ((_stoop_prey as Node2D).global_position - global_position).normalized()
		direction = direction.lerp(aim, 6.0 * delta).normalized()
	global_position += direction * (speed * 1.5) * delta
	rotation = direction.angle()
	traveled += speed * delta
	if traveled >= max_distance:
		done = true
		queue_free()

func _build_stoop_arrow() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# swept wings, so a flight of them reads as birds and not as darts
	for s in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.polygon = PackedVector2Array([
			Vector2(2, 0), Vector2(-11, 9.0 * s), Vector2(-4, 1.5 * s)])
		wing.color = Color(0.92, 0.84, 0.6, 0.8)
		wing.material = m
		visual.add_child(wing)
	var body_p := Polygon2D.new()
	body_p.polygon = PackedVector2Array([
		Vector2(15, 0), Vector2(2, -3.2), Vector2(-12, 0), Vector2(2, 3.2)])
	body_p.color = Color(1.0, 0.95, 0.78, 0.95)
	body_p.material = m
	visual.add_child(body_p)

# --- METEOR QUILLS: the volley goes UP and comes down as a shower --------
var _quill_vy := 0.0

func _tick_quill(delta: float) -> void:
	_quill_vy += 980.0 * delta
	global_position += direction * speed * delta + Vector2(0, _quill_vy * delta)
	var vel := direction * speed + Vector2(0, _quill_vy)
	rotation = vel.angle()
	traveled += speed * delta
	if _quill_vy > 60.0 and _on_floor_now():
		_rock_smoke(global_position)
		var host := get_parent()
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if global_position.distance_to((e as Node2D).global_position) > 46.0:
					continue
				var landed = e.take_damage(damage)
				if landed == null or landed:
					FloatingText.spawn(host, (e as Node2D).global_position
						+ Vector2(randf_range(-14.0, 14.0), -26.0), damage, false)
				_apply_status_to(e)
		done = true
		queue_free()

func _build_quill() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var trail := Polygon2D.new()
	trail.polygon = PackedVector2Array([
		Vector2(-8, -2.6), Vector2(-30, 0), Vector2(-8, 2.6)])
	trail.color = Color(1.0, 0.64, 0.34, 0.45)
	trail.material = m
	visual.add_child(trail)
	var quill := Polygon2D.new()
	quill.polygon = PackedVector2Array([
		Vector2(13, 0), Vector2(-2, -2.8), Vector2(-9, 0), Vector2(-2, 2.8)])
	quill.color = Color(1.0, 0.88, 0.62, 0.96)
	quill.material = m
	visual.add_child(quill)

# --- HERD OF ASHES: each jab leaves a cloud, and clouds make a HERD ------
func _build_ash_cloud() -> void:
	_zone_max = 3.0
	_zone_r = 52.0
	_zone_gap = 0.5
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for k in range(4):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(13.0, 21.0), 9)
		puff.color = Color(0.44, 0.4, 0.38, 0.42)
		puff.position = Vector2(randf_range(-22.0, 22.0), randf_range(-14.0, 8.0))
		visual.add_child(puff)
		var tw := puff.create_tween().set_loops()
		tw.tween_property(puff, "position:y", puff.position.y - 7.0, 1.1)
		tw.tween_property(puff, "position:y", puff.position.y, 1.1)
	var ember := Polygon2D.new()
	ember.polygon = _circle(7.0, 8)
	ember.color = Color(1.0, 0.5, 0.2, 0.5)
	ember.material = m
	visual.add_child(ember)

# --- CINDERSHELF: a burning LEDGE hung in the air ------------------------
func _build_cinder_shelf() -> void:
	_zone_max = 4.0
	_zone_r = 86.0
	_zone_gap = 0.4
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shelf := Polygon2D.new()
	shelf.polygon = PackedVector2Array([
		Vector2(-84, -5.0), Vector2(84, -5.0), Vector2(78, 5.0), Vector2(-78, 5.0)])
	shelf.color = Color(0.9, 0.36, 0.12, 0.66)
	shelf.material = m
	visual.add_child(shelf)
	for k in range(7):
		var fl := Polygon2D.new()
		fl.polygon = PackedVector2Array([
			Vector2(-5.0, 0), Vector2(0, -randf_range(14.0, 24.0)), Vector2(5.0, 0)])
		fl.color = Color(1.0, 0.62, 0.2, 0.8)
		fl.material = m
		fl.position = Vector2(-72.0 + 24.0 * float(k), -4.0)
		visual.add_child(fl)
		var tw := fl.create_tween().set_loops()
		tw.tween_property(fl, "scale", Vector2(0.7, 1.35), randf_range(0.2, 0.3))
		tw.tween_property(fl, "scale", Vector2(1.15, 0.8), randf_range(0.18, 0.26))

# --- GRIEF, COLLECTED: it GATHERS instead of decaying, then comes home ---
# A ricochet loses an edge each bounce. This one does the opposite: it takes
# something from every body it touches, and brings the whole weight back.
var _grief_carried := 0
var _grief_going_home := false
var _grief_seen: Array = []
const GRIEF_STOPS := 4

func _tick_grief(delta: float) -> void:
	if _grief_going_home:
		if not is_instance_valid(source):
			done = true
			queue_free()
			return
		var home: Vector2 = (source as Node2D).global_position
		var to_home: Vector2 = home - global_position
		if to_home.length() < 28.0:
			_grief_arrive()
			return
		direction = to_home.normalized()
		rotation = direction.angle()
		global_position += direction * (speed * 1.2) * delta
		return
	var prey := _grief_next()
	if prey == null:
		_grief_going_home = true
		return
	var to_p: Vector2 = (prey as Node2D).global_position - global_position
	if to_p.length() < 22.0:
		_grief_take(prey)
		return
	direction = to_p.normalized()
	rotation = direction.angle()
	global_position += direction * speed * delta

func _grief_next() -> Node2D:
	if _grief_seen.size() >= GRIEF_STOPS:
		return null
	var best: Node2D = null
	var best_d := 440.0
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or e in _grief_seen:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if not e.has_method("take_damage"):
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _grief_take(who: Node2D) -> void:
	_grief_seen.append(who)
	# heavier at every stop: the collected weight is the weapon
	var pay: int = maxi(1, int(round(float(damage) * (1.0 + 0.3 * float(_grief_carried)))))
	_grief_carried += 1
	var landed = who.take_damage(pay)
	if landed == null or landed:
		FloatingText.spawn(get_parent(), (who as Node2D).global_position
			+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, _grief_carried >= 3)
	_apply_status_to(who)
	if visual:
		visual.scale = visual.scale * 1.16

func _grief_arrive() -> void:
	# and what it carried is given back to you
	if is_instance_valid(source) and _grief_carried > 0 and source.has_method("heal"):
		source.heal(_grief_carried * 3)
		FloatingText.spawn_word(get_parent(),
			(source as Node2D).global_position + Vector2(0, -52),
			"grief, collected", Color(0.7, 0.86, 0.8))
	done = true
	queue_free()

func _build_grief_return() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var urn := Polygon2D.new()
	urn.polygon = PackedVector2Array([
		Vector2(-7, -9.0), Vector2(7, -9.0), Vector2(10, 3.0),
		Vector2(0, 11.0), Vector2(-10, 3.0)])
	urn.color = Color(0.5, 0.62, 0.6, 0.95)
	visual.add_child(urn)
	var mist := Polygon2D.new()
	mist.polygon = _circle(14.0, 10)
	mist.color = Color(0.66, 0.86, 0.82, 0.3)
	mist.material = m
	visual.add_child(mist)

func _build_night_lash() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(3):
		var coil := Polygon2D.new()
		var off: float = -6.0 + 6.0 * float(i)
		coil.polygon = PackedVector2Array([
			Vector2(-28, off * 0.3), Vector2(4, off), Vector2(30, off * 0.6),
			Vector2(30, off * 0.6 + 2.4), Vector2(4, off + 2.8), Vector2(-28, off * 0.3 + 2.2)])
		coil.color = Color(0.34, 0.26, 0.5, 0.85 - 0.16 * float(i))
		visual.add_child(coil)
	var tip := Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(36, 0), Vector2(24, -5.0), Vector2(24, 5.0)])
	tip.color = Color(0.7, 0.6, 0.95, 0.9)
	tip.material = m
	visual.add_child(tip)

func _build_noon_shaft() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glare := Polygon2D.new()
	glare.polygon = PackedVector2Array([
		Vector2(-4, -3.4), Vector2(-26, -1.2), Vector2(-26, 1.2), Vector2(-4, 3.4)])
	glare.color = Color(1.0, 0.96, 0.7, 0.4)
	glare.material = m
	visual.add_child(glare)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(10, -1.3), Vector2(-14, -1.3), Vector2(-14, 1.3), Vector2(10, 1.3)])
	shaft.color = Color(1.0, 0.98, 0.86, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(18, 0), Vector2(8, -3.6), Vector2(8, 3.6)])
	head.color = Color(1.0, 1.0, 0.96, 0.98)
	head.material = m
	visual.add_child(head)

# ==========================================================================
# TIER 5, BATCH 1.
# ==========================================================================

# --- SEAWALL: the swing STOPS and stands there -------------------------
var _wall_t := 0.0
const WALL_LIFE := 3.2
const WALL_HALF := 52.0

func _tick_seawall(delta: float) -> void:
	_wall_t += delta
	# it runs out a short way, then plants
	if _wall_t < 0.2:
		global_position += direction * speed * delta
	if visual:
		visual.modulate.a = 1.0 - pow(_wall_t / WALL_LIFE, 3.0)
	if _wall_t >= WALL_LIFE:
		done = true
		queue_free()
		return
	_rehit_t += delta
	if _rehit_t < 0.3:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 0.6)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			if absf(rel.x) > 24.0 or absf(rel.y) > WALL_HALF:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)
			# a wall's job is to be on the WRONG side of them
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if rel.x >= 0.0 else -1, 240.0)

func _build_sea_wall() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var body_w := Polygon2D.new()
	body_w.polygon = PackedVector2Array([
		Vector2(-11, WALL_HALF), Vector2(-7, -WALL_HALF * 0.6),
		Vector2(3, -WALL_HALF), Vector2(12, -WALL_HALF * 0.55),
		Vector2(10, WALL_HALF)])
	body_w.color = Color(0.36, 0.68, 0.92, 0.55)
	body_w.material = m
	visual.add_child(body_w)
	for k in range(4):
		var crest := Polygon2D.new()
		crest.polygon = PackedVector2Array([
			Vector2(-9, 0), Vector2(0, -9.0), Vector2(11, 0), Vector2(0, 5.0)])
		crest.color = Color(0.86, 0.96, 1.0, 0.7)
		crest.material = m
		crest.position = Vector2(0, -WALL_HALF * 0.7 + 26.0 * float(k))
		visual.add_child(crest)
		var tw := crest.create_tween().set_loops()
		tw.tween_property(crest, "position:x", 5.0, randf_range(0.5, 0.8))
		tw.tween_property(crest, "position:x", -5.0, randf_range(0.5, 0.8))

# --- SERPENT'S SERMON: the lash COILS and preaches at close range -------
var _coil_t := 0.0
var _coil_on: Node2D = null
const COIL_LIFE := 2.6
const COIL_BITE := 0.42

func _tick_serpent(delta: float) -> void:
	if _coil_on == null:
		global_position += direction * speed * delta
		traveled += speed * delta
		if traveled >= max_distance:
			done = true
			queue_free()
		return
	if not is_instance_valid(_coil_on) or ("is_dead" in _coil_on and _coil_on.is_dead):
		done = true
		queue_free()
		return
	global_position = (_coil_on as Node2D).global_position
	_coil_t += delta
	if visual:
		visual.rotation += 3.4 * delta
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.1 * sin(_coil_t * 9.0))
	if _coil_t >= COIL_LIFE:
		done = true
		queue_free()
		return
	_rehit_t += delta
	if _rehit_t < COIL_BITE:
		return
	_rehit_t = 0.0
	var pay: int = maxi(1, int(round(float(damage) * 0.5)))
	var landed = _coil_on.take_damage(pay)
	if landed == null or landed:
		FloatingText.spawn(get_parent(), (_coil_on as Node2D).global_position
			+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
	_apply_status_to(_coil_on)

func _serpent_wrap(who: Node2D) -> void:
	_coil_on = who
	speed = 0.0
	# the lash stops being a whip and becomes a ring of scales
	if visual:
		for c in visual.get_children():
			c.queue_free()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for band in range(3):
			var ring := Polygon2D.new()
			var rr: float = 20.0 - 4.0 * float(band)
			var pts := PackedVector2Array()
			for i in range(12):
				var a := TAU * float(i) / 12.0
				pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.42))
			for i in range(12):
				var a2 := TAU * float(11 - i) / 12.0
				pts.append(Vector2(cos(a2) * (rr - 3.5), sin(a2) * (rr - 3.5) * 0.42))
			ring.polygon = pts
			ring.color = Color(0.42, 0.76, 0.44, 0.8)
			ring.material = m
			ring.position = Vector2(0, -18.0 + 17.0 * float(band))
			visual.add_child(ring)

func _build_serpent_coil() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(3):
		var seg := Polygon2D.new()
		var off: float = -5.0 + 5.0 * float(i)
		seg.polygon = PackedVector2Array([
			Vector2(-26, off * 0.4), Vector2(6, off), Vector2(28, off * 0.7),
			Vector2(28, off * 0.7 + 2.6), Vector2(6, off + 3.0), Vector2(-26, off * 0.4 + 2.4)])
		seg.color = Color(0.36, 0.7, 0.4, 0.88 - 0.16 * float(i))
		visual.add_child(seg)
	var headp := Polygon2D.new()
	headp.polygon = PackedVector2Array([
		Vector2(34, 0), Vector2(24, -6.0), Vector2(20, 0), Vector2(24, 6.0)])
	headp.color = Color(0.7, 0.95, 0.6, 0.95)
	headp.material = m
	visual.add_child(headp)

# --- TWINBURST SCEPTRE: two bolts winding, and they blow where they CROSS
var _twin_t := 0.0
var _twin_side := 1.0
var _twin_origin := Vector2.ZERO
const TWIN_WIND := 0.42     # seconds per half-turn
const TWIN_AMP := 34.0

func _tick_twin(delta: float) -> void:
	_twin_t += delta
	if _twin_origin == Vector2.ZERO:
		_twin_origin = global_position
	traveled += speed * delta
	var perp := Vector2(-direction.y, direction.x)
	var wind: float = sin(_twin_t * PI / TWIN_WIND) * TWIN_AMP * _twin_side
	global_position = _twin_origin + direction * traveled + perp * wind
	rotation = direction.angle()
	# they cross whenever the winding passes through zero -- and only ONE of
	# the pair fires the burst, or every crossing would go off twice
	if _twin_side > 0.0 and _twin_t > 0.05:
		var beat: float = fmod(_twin_t, TWIN_WIND)
		if beat < delta:
			_nova_burst_tinted(global_position, Color(0.86, 0.6, 1.0))
	if traveled >= max_distance:
		done = true
		queue_free()

func set_twin_side(s: float) -> void:
	_twin_side = s

func _build_twin_bolt() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-4, -3.0), Vector2(-22, 0), Vector2(-4, 3.0)])
	tail.color = Color(0.7, 0.44, 0.95, 0.4)
	tail.material = m
	visual.add_child(tail)
	var core := Polygon2D.new()
	core.polygon = _circle(7.0, 9)
	core.color = Color(0.95, 0.82, 1.0, 0.96)
	core.material = m
	visual.add_child(core)

# --- BEACON OF THE DEEP: a slow pulse, and the pulse SHOVES --------------
var _bea_t := 0.0
var _bea_next := 0.0
const BEA_LIFE := 6.5
const BEA_GAP := 1.15
const BEA_R := 118.0

func _tick_beacon(delta: float) -> void:
	_bea_t += delta
	if _bea_t >= BEA_LIFE:
		done = true
		queue_free()
		return
	if visual:
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.08 * sin(_bea_t * 4.0))
	if _bea_t < _bea_next:
		return
	_bea_next += BEA_GAP
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			if rel.length() > BEA_R:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if rel.x >= 0.0 else -1, 150.0)
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pulse := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * 22.0, sin(a) * 9.0))
	for i in range(20):
		var a2 := TAU * float(19 - i) / 20.0
		pts.append(Vector2(cos(a2) * 18.0, sin(a2) * 7.0))
	pulse.polygon = pts
	pulse.color = Color(0.5, 0.86, 0.96, 0.72)
	pulse.material = m
	pulse.z_index = 42
	host.add_child(pulse)
	pulse.global_position = global_position
	var tw := pulse.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pulse, "scale", Vector2.ONE * (BEA_R / 20.0), 0.62)
	tw.tween_property(pulse, "modulate:a", 0.0, 0.62)
	tw.chain().tween_callback(pulse.queue_free)

func _build_deep_beacon() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3.4, 18.0), Vector2(-2.2, -14.0), Vector2(2.2, -14.0), Vector2(3.4, 18.0)])
	post.color = Color(0.24, 0.34, 0.4, 0.96)
	visual.add_child(post)
	var lamp := Polygon2D.new()
	lamp.polygon = _circle(10.0, 10)
	lamp.color = Color(0.62, 0.94, 1.0, 0.94)
	lamp.material = m
	lamp.position = Vector2(0, -20.0)
	visual.add_child(lamp)
	var glow := Polygon2D.new()
	glow.polygon = _circle(17.0, 10)
	glow.color = Color(0.4, 0.8, 1.0, 0.32)
	glow.material = m
	glow.position = Vector2(0, -20.0)
	visual.add_child(glow)

# --- STARFALL BOW: the same fall as a quill, a very different face -------
func _build_star_fall() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var trail := Polygon2D.new()
	trail.polygon = PackedVector2Array([
		Vector2(-6, -3.4), Vector2(-34, 0), Vector2(-6, 3.4)])
	trail.color = Color(0.72, 0.82, 1.0, 0.5)
	trail.material = m
	visual.add_child(trail)
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0 - PI * 0.5
		pts.append(Vector2(cos(a), sin(a)) * (13.0 if i % 2 == 0 else 4.6))
	star.polygon = pts
	star.color = Color(0.94, 0.96, 1.0, 0.97)
	star.material = m
	visual.add_child(star)

# --- WORLDTOLL MAUL: the blow travels UNDER the ground and erupts --------
func _build_under_toll() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# a crack running along the floor: low, wide, and clearly BELOW them
	var crack := Polygon2D.new()
	crack.polygon = PackedVector2Array([
		Vector2(-22, 2.0), Vector2(-8, -6.0), Vector2(6, 1.0),
		Vector2(20, -5.0), Vector2(22, 3.0), Vector2(-20, 7.0)])
	crack.color = Color(0.86, 0.62, 0.3, 0.72)
	crack.material = m
	visual.add_child(crack)
	for k in range(3):
		var grit := Polygon2D.new()
		grit.polygon = _circle(randf_range(3.0, 6.0), 6)
		grit.color = Color(0.5, 0.42, 0.34, 0.7)
		grit.position = Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, -4.0))
		visual.add_child(grit)

# ==========================================================================
# TIER 5, BATCH 2.
# ==========================================================================

# --- GLACIER WRIT: a floe that GROWS the further it goes ----------------
var _floe_t := 0.0

func _tick_floe(delta: float) -> void:
	_floe_t += delta
	global_position += direction * speed * delta
	traveled += speed * delta
	var frac: float = clampf(traveled / maxf(1.0, max_distance), 0.0, 1.0)
	if visual:
		# it accretes as it drifts, so late in its run it is a wall of ice
		visual.scale = Vector2.ONE * _draw_girth * (0.55 + 1.5 * frac)
		visual.rotation = sin(_floe_t * 1.6) * 0.12
	_rehit_t += delta
	if _rehit_t >= 0.28:
		_rehit_t = 0.0
		hit_bodies.clear()
	if traveled >= max_distance:
		# and then it breaks up
		_shatter_note(global_position)
		done = true
		queue_free()

func _build_ice_floe() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var slab := Polygon2D.new()
	slab.polygon = PackedVector2Array([
		Vector2(-16, 13.0), Vector2(-20, -6.0), Vector2(-5, -17.0),
		Vector2(13, -13.0), Vector2(19, 3.0), Vector2(8, 16.0)])
	slab.color = Color(0.6, 0.84, 1.0, 0.62)
	slab.material = m
	visual.add_child(slab)
	for k in range(3):
		var spike := Polygon2D.new()
		var h: float = randf_range(10.0, 18.0)
		spike.polygon = PackedVector2Array([
			Vector2(-4.0, 0), Vector2(0, -h), Vector2(4.0, 0)])
		spike.color = Color(0.86, 0.95, 1.0, 0.85)
		spike.material = m
		spike.position = Vector2(-9.0 + 9.0 * float(k), -4.0)
		visual.add_child(spike)

# --- THE OWL REMEMBERS: it circles and comes back, harder each pass -----
var _owl_t := 0.0
var _owl_pass := 0
var _owl_prey: Node2D = null
var _owl_from := Vector2.ZERO
const OWL_PASSES := 3
const OWL_ARC := 0.44        # seconds per swoop

func _tick_owl(delta: float) -> void:
	if _owl_prey == null or not is_instance_valid(_owl_prey) \
			or ("is_dead" in _owl_prey and _owl_prey.is_dead):
		_owl_prey = _nearest_hostile_node(520.0)
		if _owl_prey == null:
			global_position += direction * speed * delta
			traveled += speed * delta
			if traveled >= max_distance:
				done = true
				queue_free()
			return
		_owl_from = global_position
		_owl_t = 0.0
	_owl_t += delta
	var t: float = clampf(_owl_t / OWL_ARC, 0.0, 1.0)
	var target: Vector2 = (_owl_prey as Node2D).global_position
	# a swoop, not a straight line: it rises off the line and drops on them
	var flat: Vector2 = _owl_from.lerp(target, t)
	var lift: float = -sin(t * PI) * 62.0 * (1.0 if _owl_pass % 2 == 0 else -1.0)
	var prev := global_position
	global_position = flat + Vector2(0, lift)
	if global_position != prev:
		rotation = (global_position - prev).angle()
	if t < 1.0:
		return
	# it lands the pass, then wheels around for the next one
	_owl_strike()
	_owl_pass += 1
	if _owl_pass >= OWL_PASSES:
		done = true
		queue_free()
		return
	_owl_t = 0.0
	_owl_from = global_position + Vector2(
		-92.0 if randf() < 0.5 else 92.0, -46.0)
	global_position = _owl_from

func _owl_strike() -> void:
	if _owl_prey == null or not is_instance_valid(_owl_prey):
		return
	if not _owl_prey.has_method("take_damage"):
		return
	# IT REMEMBERS: the second visit hurts more than the first
	var pay: int = maxi(1, int(round(float(damage) * (1.0 + 0.45 * float(_owl_pass)))))
	var landed = _owl_prey.take_damage(pay)
	if landed == null or landed:
		FloatingText.spawn(get_parent(), (_owl_prey as Node2D).global_position
			+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, _owl_pass >= 2)
	_apply_status_to(_owl_prey)

func _build_owl_pass() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for s in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.polygon = PackedVector2Array([
			Vector2(1, 0), Vector2(-9, 11.0 * s), Vector2(-14, 3.0 * s), Vector2(-5, 1.0 * s)])
		wing.color = Color(0.82, 0.76, 0.62, 0.85)
		wing.material = m
		visual.add_child(wing)
	var body_o := Polygon2D.new()
	body_o.polygon = PackedVector2Array([
		Vector2(13, 0), Vector2(3, -5.0), Vector2(-10, 0), Vector2(3, 5.0)])
	body_o.color = Color(0.9, 0.86, 0.72, 0.95)
	visual.add_child(body_o)
	# two eyes: an owl reads as an owl only if it is LOOKING at you
	for ex in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		eye.polygon = _circle(2.2, 6)
		eye.color = Color(1.0, 0.88, 0.3, 0.98)
		eye.material = m
		eye.position = Vector2(6.0, 2.4 * ex)
		visual.add_child(eye)

# --- GALLOWS SWING: it does not knock them back, it LIFTS them ----------
func _hang_them(who: Node2D) -> void:
	var host := get_parent()
	if host == null or not is_instance_valid(who):
		return
	if who.has_method("apply_status"):
		who.apply_status("freeze", 1.1, 1.0)     # they stop, because they are up
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rope := Polygon2D.new()
	rope.polygon = PackedVector2Array([
		Vector2(-1.6, -78.0), Vector2(1.6, -78.0), Vector2(1.6, -14.0), Vector2(-1.6, -14.0)])
	rope.color = Color(0.66, 0.58, 0.4, 0.9)
	host.add_child(rope)
	rope.global_position = (who as Node2D).global_position
	var noose := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 5.0))
	noose.polygon = pts
	noose.color = Color(0.8, 0.72, 0.5, 0.9)
	noose.material = m
	noose.position = Vector2(0, -14.0)
	rope.add_child(noose)
	var tw := rope.create_tween()
	tw.tween_property(rope, "rotation", 0.13, 0.28)
	tw.tween_property(rope, "rotation", -0.13, 0.34)
	tw.tween_property(rope, "rotation", 0.0, 0.26)
	tw.tween_property(rope, "modulate:a", 0.0, 0.2)
	tw.tween_callback(rope.queue_free)
	# and then the floor comes back: the drop is the second half of the blow
	var drop = (load("res://weapon_projectile.gd") as GDScript).new()
	drop.kind = "late_thunder"
	drop.damage = maxi(1, int(round(float(damage) * 0.8)))
	drop.element = element
	drop.on_hit_status = on_hit_status
	drop.source = source
	host.add_child(drop)
	drop.global_position = (who as Node2D).global_position

# --- PILGRIM'S SCOURGE: every strike plants a WAYMARK you can walk back to
func _plant_waymark(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var cairn := Node2D.new()
	cairn.z_index = 8
	cairn.add_to_group("pilgrim_waymark")
	# a small stack of stones, so the road you walked is readable at a glance
	for k in range(3):
		var stone := Polygon2D.new()
		stone.polygon = _circle(6.5 - 1.6 * float(k), 7)
		stone.color = Color(0.86, 0.8, 0.66, 0.96)
		stone.position = Vector2(randf_range(-1.5, 1.5), -3.0 - 7.0 * float(k))
		cairn.add_child(stone)
	var halo := Polygon2D.new()
	halo.polygon = _circle(15.0, 10)
	halo.color = Color(1.0, 0.92, 0.62, 0.42)
	halo.material = m
	halo.position = Vector2(0, -10.0)
	cairn.add_child(halo)
	host.add_child(cairn)
	cairn.global_position = Vector2(at.x, at.y + 12.0)
	var tw := cairn.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(cairn, "modulate:a", 0.0, 0.8)
	tw.tween_callback(cairn.queue_free)

func _build_pilgrim_lash() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(3):
		var cord := Polygon2D.new()
		var off: float = -6.0 + 6.0 * float(i)
		cord.polygon = PackedVector2Array([
			Vector2(-24, off * 0.4), Vector2(4, off), Vector2(26, off * 0.7),
			Vector2(26, off * 0.7 + 2.2), Vector2(4, off + 2.6), Vector2(-24, off * 0.4 + 2.0)])
		cord.color = Color(0.78, 0.7, 0.5, 0.88 - 0.16 * float(i))
		visual.add_child(cord)
		# the knots: a scourge is knotted, and the knots are what land
		var knot := Polygon2D.new()
		knot.polygon = _circle(3.6, 6)
		knot.color = Color(0.92, 0.86, 0.62, 0.95)
		knot.material = m
		knot.position = Vector2(24.0, off * 0.7 + 1.0)
		visual.add_child(knot)

# --- QUILLRAIN: a drizzle, not a volley ---------------------------------
func _build_rain_quill() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var streak := Polygon2D.new()
	streak.polygon = PackedVector2Array([
		Vector2(-3, -1.6), Vector2(-19, 0), Vector2(-3, 1.6)])
	streak.color = Color(0.72, 0.88, 0.82, 0.42)
	streak.material = m
	visual.add_child(streak)
	var q := Polygon2D.new()
	q.polygon = PackedVector2Array([
		Vector2(9, 0), Vector2(-2, -2.0), Vector2(-6, 0), Vector2(-2, 2.0)])
	q.color = Color(0.88, 0.96, 0.9, 0.92)
	visual.add_child(q)

# --- KING'S RANSOM: a price on their head -------------------------------
func _build_ransom_seal() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = _circle(13.0, 10)
	halo.color = Color(1.0, 0.86, 0.36, 0.3)
	halo.material = m
	visual.add_child(halo)
	# a crown stamped on a coin
	var coin := Polygon2D.new()
	coin.polygon = _circle(8.0, 10)
	coin.color = Color(1.0, 0.88, 0.42, 0.96)
	visual.add_child(coin)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([
		Vector2(-5, 2.0), Vector2(-5, -2.0), Vector2(-2.5, 0.5), Vector2(0, -3.0),
		Vector2(2.5, 0.5), Vector2(5, -2.0), Vector2(5, 2.0)])
	crown.color = Color(0.56, 0.4, 0.1, 0.95)
	visual.add_child(crown)

# ==========================================================================
# TIER 5, BATCH 3.
# ==========================================================================

# --- WHEEL OF QUIET: it works in SILENCE and bills you once -------------
# Every other weapon in the game shouts a number per hit. This one shows
# nothing at all while it grinds, then one total when it stops -- the
# presentation IS the weapon.
var _qw_t := 0.0
var _qw_owed := 0
const QW_LIFE := 2.8
const QW_R := 58.0

func _tick_quiet(delta: float) -> void:
	_qw_t += delta
	if _qw_t < 0.22:
		global_position += direction * speed * delta
	if visual:
		visual.rotation += 7.0 * delta
		visual.modulate.a = 1.0 - pow(_qw_t / QW_LIFE, 4.0)
	if _qw_t >= QW_LIFE:
		_qw_settle()
		return
	_rehit_t += delta
	if _rehit_t < 0.3:
		return
	_rehit_t = 0.0
	var pay: int = maxi(1, int(round(float(damage) * 0.34)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > QW_R:
				continue
			e.take_damage(pay)      # deliberately NO FloatingText -- it is quiet
			_qw_owed += pay
			_apply_status_to(e)

func _qw_settle() -> void:
	if _qw_owed > 0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -40.0), _qw_owed, true)
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -58.0),
			"quietly", Color(0.78, 0.82, 0.88))
	done = true
	queue_free()

func _build_quiet_wheel() -> void:
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 21.0)
	for i in range(16):
		var a2 := TAU * float(15 - i) / 16.0
		pts.append(Vector2(cos(a2), sin(a2)) * 15.0)
	rim.polygon = pts
	# muted on purpose: no additive glow anywhere on this weapon
	rim.color = Color(0.52, 0.54, 0.58, 0.8)
	visual.add_child(rim)
	for k in range(6):
		var spoke := Polygon2D.new()
		spoke.polygon = PackedVector2Array([
			Vector2(-1.4, -16.0), Vector2(1.4, -16.0), Vector2(1.4, 0), Vector2(-1.4, 0)])
		spoke.color = Color(0.62, 0.64, 0.68, 0.6)
		spoke.rotation = deg_to_rad(60.0 * float(k))
		visual.add_child(spoke)

# --- MIDWINTER WHEEL: it lays a RING of frost as it goes round ----------
var _mw_t := 0.0
var _mw_drop := 0.0
const MW_LIFE := 3.2

func _tick_winter(delta: float) -> void:
	_mw_t += delta
	if _mw_t >= MW_LIFE or not is_instance_valid(source):
		done = true
		queue_free()
		return
	var centre: Vector2 = (source as Node2D).global_position
	var ang: float = _mw_t * 5.2
	global_position = centre + Vector2(cos(ang), sin(ang) * 0.45) * 84.0
	if visual:
		visual.rotation += 9.0 * delta
	# the track it leaves: a circle of rime drawn on the floor around you
	_mw_drop -= delta
	if _mw_drop <= 0.0:
		_mw_drop = 0.1
		var host := get_parent()
		if host != null:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var rime := Polygon2D.new()
			rime.polygon = _circle(randf_range(4.0, 7.0), 6)
			rime.color = Color(0.72, 0.9, 1.0, 0.6)
			rime.material = m
			rime.z_index = 8
			host.add_child(rime)
			rime.global_position = global_position
			var tw := rime.create_tween()
			tw.tween_interval(0.8)
			tw.tween_property(rime, "modulate:a", 0.0, 0.7)
			tw.tween_callback(rime.queue_free)
	_rehit_t += delta
	if _rehit_t < 0.26:
		return
	_rehit_t = 0.0
	var host2 := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 0.55)))
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > 38.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host2, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			if e.has_method("apply_status"):
				e.apply_status("slow", 1.6, 0.4)
			_apply_status_to(e)

func _build_winter_wheel() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	for i in range(12):
		var a2 := TAU * float(11 - i) / 12.0
		pts.append(Vector2(cos(a2), sin(a2)) * 12.0)
	rim.polygon = pts
	rim.color = Color(0.68, 0.88, 1.0, 0.9)
	rim.material = m
	visual.add_child(rim)
	for k in range(6):
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(-3.0, -17.0), Vector2(0, -25.0), Vector2(3.0, -17.0)])
		tooth.color = Color(0.88, 0.96, 1.0, 0.9)
		tooth.material = m
		tooth.rotation = deg_to_rad(60.0 * float(k))
		visual.add_child(tooth)

# --- SKY OF QUILLS: they HANG up there, and then they all come down -----
var _sq_t := 0.0
var _sq_fired := false
const SQ_HANG := 0.85

func _tick_skyquill(delta: float) -> void:
	_sq_t += delta
	if not _sq_fired:
		# drift up into place and wait, quivering
		global_position += Vector2(0, -34.0) * delta
		if visual:
			visual.rotation = PI * 0.5 + sin(_sq_t * 16.0) * 0.09
		if _sq_t >= SQ_HANG:
			_sq_fired = true
			speed = 620.0
			direction = Vector2.DOWN
			if visual:
				visual.rotation = 0.0
			rotation = PI * 0.5
		return
	global_position += Vector2.DOWN * speed * delta
	traveled += speed * delta
	if traveled >= 460.0 or _on_floor_now():
		_rock_smoke(global_position)
		done = true
		queue_free()

func _build_sky_quill() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var q := Polygon2D.new()
	q.polygon = PackedVector2Array([
		Vector2(15, 0), Vector2(-1, -3.2), Vector2(-13, 0), Vector2(-1, 3.2)])
	q.color = Color(0.86, 0.9, 0.98, 0.95)
	visual.add_child(q)
	var glint := Polygon2D.new()
	glint.polygon = PackedVector2Array([Vector2(17, 0), Vector2(6, -2.0), Vector2(6, 2.0)])
	glint.color = Color(1.0, 1.0, 1.0, 0.9)
	glint.material = m
	visual.add_child(glint)

# --- EVENTIDE: the volley goes out, and then the tide comes back --------
var _ev_t := 0.0
var _ev_out := true
const EV_TURN := 0.42

func _tick_eventide(delta: float) -> void:
	_ev_t += delta
	if _ev_out and _ev_t >= EV_TURN:
		_ev_out = false
		hit_bodies.clear()        # it may take the same body on the way home
		direction = -direction
		rotation = direction.angle()
	global_position += direction * speed * delta
	if not _ev_out and is_instance_valid(source):
		if global_position.distance_to((source as Node2D).global_position) < 26.0:
			done = true
			queue_free()
			return
	if _ev_t > EV_TURN * 3.0:
		done = true
		queue_free()

func _build_eventide() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var wake := Polygon2D.new()
	wake.polygon = PackedVector2Array([
		Vector2(-3, -4.0), Vector2(-24, 0), Vector2(-3, 4.0)])
	wake.color = Color(0.86, 0.6, 0.4, 0.42)
	wake.material = m
	visual.add_child(wake)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(10, -1.2), Vector2(-12, -1.2), Vector2(-12, 1.2), Vector2(10, 1.2)])
	shaft.color = Color(0.95, 0.72, 0.5, 0.95)
	visual.add_child(shaft)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(17, 0), Vector2(7, -3.4), Vector2(7, 3.4)])
	head.color = Color(1.0, 0.88, 0.66, 0.98)
	head.material = m
	visual.add_child(head)

# --- GRAND TOME OF RAINS: a cloud opens and it RAINS ---------------------
var _rc_t := 0.0
var _rc_drop := 0.0
const RC_LIFE := 4.6
const RC_HALF := 108.0

func _tick_raincloud(delta: float) -> void:
	_rc_t += delta
	if _rc_t >= RC_LIFE:
		done = true
		queue_free()
		return
	if visual:
		visual.position.x = sin(_rc_t * 0.8) * 6.0
	_rc_drop -= delta
	if _rc_drop > 0.0:
		return
	_rc_drop = 0.16
	var host := get_parent()
	if host == null:
		return
	# one drop, somewhere under the cloud
	var dx: float = randf_range(-RC_HALF, RC_HALF)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var drop := Polygon2D.new()
	drop.polygon = PackedVector2Array([
		Vector2(-1.4, -9.0), Vector2(1.4, -9.0), Vector2(0.8, 5.0), Vector2(-0.8, 5.0)])
	drop.color = Color(0.62, 0.82, 1.0, 0.8)
	drop.material = m
	drop.z_index = 39
	host.add_child(drop)
	drop.global_position = global_position + Vector2(dx, 18.0)
	var land: Vector2 = drop.global_position + Vector2(0, 104.0)
	var tw := drop.create_tween()
	tw.tween_property(drop, "global_position", land, 0.26)
	tw.tween_callback(drop.queue_free)
	# and the drop bites whatever is under it
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - (global_position + Vector2(dx, 0))
			if absf(rel.x) > 30.0 or rel.y < -20.0 or rel.y > 150.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-14.0, 14.0), -26.0), pay, false)
			_apply_status_to(e)
			break     # one drop, one body

func _build_rain_cloud() -> void:
	for k in range(5):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(20.0, 31.0), 10)
		puff.color = Color(0.3, 0.36, 0.48, 0.82)
		puff.position = Vector2(-84.0 + 42.0 * float(k), randf_range(-6.0, 6.0))
		visual.add_child(puff)
		var tw := puff.create_tween().set_loops()
		tw.tween_property(puff, "position:y", puff.position.y - 4.0, randf_range(1.2, 1.9))
		tw.tween_property(puff, "position:y", puff.position.y, randf_range(1.2, 1.9))

# --- WARDEN'S LONG WATCH: a post that snipes the lane -------------------
var _wp_t := 0.0
var _wp_next := 0.7
const WP_LIFE := 9.0
const WP_GAP := 1.5

func _tick_warden(delta: float) -> void:
	_wp_t += delta
	if _wp_t >= WP_LIFE:
		done = true
		queue_free()
		return
	if _wp_t < _wp_next:
		return
	_wp_next += WP_GAP
	var prey := _nearest_hostile_node(640.0)
	if prey == null:
		return
	var host := get_parent()
	if host == null:
		return
	var aim: Vector2 = ((prey as Node2D).global_position - global_position).normalized()
	# ONE long shot, and it goes through everything standing in the line
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(0, -3.0), Vector2(600.0, -1.2), Vector2(600.0, 1.2), Vector2(0, 3.0)])
	beam.color = Color(0.86, 0.92, 0.7, 0.85)
	beam.material = m
	beam.z_index = 41
	beam.rotation = aim.angle()
	host.add_child(beam)
	beam.global_position = global_position
	var tw := beam.create_tween()
	tw.tween_property(beam, "modulate:a", 0.0, 0.24)
	tw.tween_callback(beam.queue_free)
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			var along: float = rel.dot(aim)
			if along < 0.0 or along > 600.0:
				continue
			if absf(rel.dot(Vector2(-aim.y, aim.x))) > 26.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-14.0, 14.0), -26.0), pay, true)
			_apply_status_to(e)

func _build_warden_post() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var leg := Polygon2D.new()
	leg.polygon = PackedVector2Array([
		Vector2(-4.0, 20.0), Vector2(-2.4, -12.0), Vector2(2.4, -12.0), Vector2(4.0, 20.0)])
	leg.color = Color(0.34, 0.3, 0.24, 0.96)
	visual.add_child(leg)
	# a slitted lantern head: it is WATCHING one direction at a time
	var hood := Polygon2D.new()
	hood.polygon = PackedVector2Array([
		Vector2(-11, -12.0), Vector2(11, -12.0), Vector2(8, -26.0), Vector2(-8, -26.0)])
	hood.color = Color(0.4, 0.42, 0.34, 0.96)
	visual.add_child(hood)
	var slit := Polygon2D.new()
	slit.polygon = PackedVector2Array([
		Vector2(-7, -16.0), Vector2(7, -16.0), Vector2(7, -21.0), Vector2(-7, -21.0)])
	slit.color = Color(0.94, 0.98, 0.7, 0.95)
	slit.material = m
	visual.add_child(slit)

# ==========================================================================
# THE LAST WORD, REBUILT (2026-07-29). Dev: "no zenith similar like weapon in
# game" -- and they were right. The old verb loosed ONE ghost blade per swing,
# which is a boomerang with a good name. The source's identity is the whole
# armoury at once: a swirling storm of many blades, continuous, screen-filling.
# So: one node, NINE blades, one damage loop, one instance cap.
# ==========================================================================
const ZS_BLADES := 9
const ZS_LIFE := 1.05
const ZS_R0 := 34.0
const ZS_R1 := 215.0
const ZS_BITE := 0.2
const ZS_REACH := 40.0

var _zs_t := 0.0
var _zs_parts: Array = []

func _tick_zenith_storm(delta: float) -> void:
	_zs_t += delta
	if _zs_t >= ZS_LIFE or not is_instance_valid(source):
		done = true
		queue_free()
		return
	global_position = (source as Node2D).global_position
	var frac: float = _zs_t / ZS_LIFE
	# they bloom OUT and draw back in, so the storm breathes rather than
	# just expanding off the screen
	var swell: float = sin(frac * PI)
	var r: float = lerpf(ZS_R0, ZS_R1, swell)
	var spin: float = _zs_t * 7.4
	for i in range(_zs_parts.size()):
		var part: Node2D = _zs_parts[i]
		if not is_instance_valid(part):
			continue
		var a: float = spin + TAU * float(i) / float(ZS_BLADES)
		# each blade rides its own slightly different radius, so nine of them
		# read as a CROWD of swords and not one spinning ring
		var rr: float = r * (0.72 + 0.28 * sin(_zs_t * 5.0 + float(i) * 1.7))
		part.position = Vector2(cos(a), sin(a) * 0.78) * rr
		part.rotation = a + PI * 0.5
		part.modulate.a = 0.35 + 0.65 * swell
	if visual:
		visual.modulate.a = 1.0
	_rehit_t += delta
	if _rehit_t < ZS_BITE:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			# hit if ANY blade is on them -- the storm is the hitbox
			var struck := false
			for part2 in _zs_parts:
				if not is_instance_valid(part2):
					continue
				if (part2 as Node2D).global_position.distance_to(
						(e as Node2D).global_position) <= ZS_REACH:
					struck = true
					break
			if not struck:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-22.0, 22.0), -26.0), pay, randf() < 0.3)
			_apply_status_to(e)

func _build_zenith_storm() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(ZS_BLADES):
		var tint: Color = WeaponFx.LEGACY_TINTS[i % WeaponFx.LEGACY_TINTS.size()]
		var part := Node2D.new()
		# each one a DIFFERENT blade silhouette, because the fantasy is that
		# every sword you ever carried is in the air at once
		var length: float = 26.0 + 7.0 * float(i % 4)
		var width: float = 5.0 + 1.6 * float(i % 3)
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(0, -length), Vector2(width, -length * 0.55),
			Vector2(width * 0.7, length * 0.28), Vector2(-width * 0.7, length * 0.28),
			Vector2(-width, -length * 0.55)])
		blade.color = Color(tint.r, tint.g, tint.b, 0.95)
		part.add_child(blade)
		var edge := Polygon2D.new()
		edge.polygon = PackedVector2Array([
			Vector2(0, -length - 4.0), Vector2(width * 0.45, -length * 0.5),
			Vector2(-width * 0.45, -length * 0.5)])
		edge.color = Color(1.0, 1.0, 1.0, 0.75)
		edge.material = m
		part.add_child(edge)
		var guard := Polygon2D.new()
		guard.polygon = PackedVector2Array([
			Vector2(-width * 1.7, length * 0.26), Vector2(width * 1.7, length * 0.26),
			Vector2(width * 1.7, length * 0.42), Vector2(-width * 1.7, length * 0.42)])
		guard.color = Color(tint.r * 0.6, tint.g * 0.55, tint.b * 0.5, 0.95)
		part.add_child(guard)
		visual.add_child(part)
		_zs_parts.append(part)

# ==========================================================================
# THE MONARCH ELEVEN (2026-07-29). The dev opened the monarch chest and found
# half the best tier swinging like a tier-1 cudgel. These eleven were still on
# generic shared verbs; they are now built to the same scale as the Zenith.
#
# THE RULE FOR THIS TIER, per the dev: power lives in the VERB, not in stat
# riders. More blades, more beams, more summons, more of everything at once.
# ==========================================================================

# --- THE RUMOR: it does not bounce. It SPREADS. -------------------------
# 1 -> 2 -> 4: every body it touches tells two more. A room full of rumour.
var _rum_gen := 0
const RUM_MAX_GEN := 3

func _tick_rumor(delta: float) -> void:
	global_position += direction * speed * delta
	traveled += speed * delta
	if visual:
		visual.rotation += 6.0 * delta
	if traveled >= max_distance:
		done = true
		queue_free()

func set_rumor_gen(g: int) -> void:
	_rum_gen = g

func _rumor_spread(at: Vector2) -> void:
	if _rum_gen >= RUM_MAX_GEN:
		return
	var host := get_parent()
	if host == null:
		return
	for k in range(2):
		var child = (load("res://weapon_projectile.gd") as GDScript).new()
		child.kind = "rumor_bolt"
		# it does NOT decay -- a rumour grows in the telling
		child.damage = maxi(1, int(round(float(damage) * 1.06)))
		child.element = element
		child.on_hit_status = on_hit_status
		child.source = source
		child.girth = girth * 0.92
		child.speed = speed * 0.94
		child.max_distance = max_distance * 0.7
		child.direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		host.add_child(child)
		child.global_position = at
		child.set_rumor_gen(_rum_gen + 1)

func _build_rumor_bolt() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Polygon2D.new()
	halo.polygon = _circle(13.0, 10)
	halo.color = Color(0.86, 0.72, 0.96, 0.32)
	halo.material = m
	visual.add_child(halo)
	# a whispering mouth-shape, turning
	for k in range(3):
		var lip := Polygon2D.new()
		lip.polygon = PackedVector2Array([
			Vector2(-8, 0), Vector2(0, -4.6), Vector2(8, 0), Vector2(0, 3.0)])
		lip.color = Color(0.94, 0.86, 1.0, 0.85 - 0.2 * float(k))
		lip.material = m
		lip.rotation = deg_to_rad(60.0 * float(k))
		visual.add_child(lip)

# --- STAFF THAT MEASURES THE SKY: it draws a grid and the grid FALLS -----
var _meas_t := 0.0
var _meas_fired := false
const MEAS_LINES := 6
const MEAS_SPAN := 300.0
const MEAS_WARN := 0.42

func _tick_measure(delta: float) -> void:
	_meas_t += delta
	if not _meas_fired and _meas_t >= MEAS_WARN:
		_meas_fired = true
		_measure_fall()
	if _meas_t >= MEAS_WARN + 0.5:
		done = true
		queue_free()

func _measure_fall() -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pay: int = maxi(1, damage)
	for i in range(MEAS_LINES):
		var x: float = -MEAS_SPAN + 2.0 * MEAS_SPAN * float(i) / float(MEAS_LINES - 1)
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([
			Vector2(-7.0, -300.0), Vector2(7.0, -300.0), Vector2(4.0, 90.0), Vector2(-4.0, 90.0)])
		beam.color = Color(0.84, 0.9, 1.0, 0.9)
		beam.material = m
		beam.z_index = 44
		host.add_child(beam)
		beam.global_position = global_position + Vector2(x, 0)
		var tw := beam.create_tween()
		tw.tween_interval(0.04 * float(i))
		tw.tween_property(beam, "modulate:a", 0.0, 0.3)
		tw.tween_callback(beam.queue_free)
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				var rel: Vector2 = (e as Node2D).global_position - (global_position + Vector2(x, 0))
				if absf(rel.x) > 26.0 or rel.y < -290.0 or rel.y > 96.0:
					continue
				var landed = e.take_damage(pay)
				if landed == null or landed:
					FloatingText.spawn(host, (e as Node2D).global_position
						+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, true)
				_apply_status_to(e)

func _build_sky_measure() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the survey marks: a row of faint verticals that promise where it lands
	for i in range(MEAS_LINES):
		var x: float = -MEAS_SPAN + 2.0 * MEAS_SPAN * float(i) / float(MEAS_LINES - 1)
		var mark := Polygon2D.new()
		mark.polygon = PackedVector2Array([
			Vector2(x - 1.4, -250.0), Vector2(x + 1.4, -250.0),
			Vector2(x + 1.4, 80.0), Vector2(x - 1.4, 80.0)])
		mark.color = Color(0.7, 0.82, 1.0, 0.3)
		mark.material = m
		visual.add_child(mark)
		var tw := mark.create_tween().set_loops()
		tw.tween_property(mark, "modulate:a", 0.7, 0.16)
		tw.tween_property(mark, "modulate:a", 0.25, 0.16)

# --- THE UNBENT COLUMN: a whole COLONNADE comes up at once --------------
var _col_t := 0.0
var _col_fired := false
const COL_COUNT := 5
const COL_GAP := 88.0

func _tick_colonnade(delta: float) -> void:
	_col_t += delta
	if not _col_fired and _col_t >= 0.14:
		_col_fired = true
		_raise_colonnade()
	if _col_t >= 1.1:
		done = true
		queue_free()

func _raise_colonnade() -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pay: int = maxi(1, damage)
	for i in range(COL_COUNT):
		var at: Vector2 = global_position + direction * (COL_GAP * float(i))
		var pillar := Polygon2D.new()
		pillar.polygon = PackedVector2Array([
			Vector2(-19.0, 26.0), Vector2(-13.0, -150.0),
			Vector2(13.0, -150.0), Vector2(19.0, 26.0)])
		pillar.color = Color(0.92, 0.88, 0.72, 0.82)
		pillar.material = m
		pillar.z_index = 43
		host.add_child(pillar)
		pillar.global_position = at
		pillar.scale = Vector2(1.0, 0.05)
		var tw := pillar.create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(pillar, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.34)
		tw.tween_property(pillar, "modulate:a", 0.0, 0.24)
		tw.tween_callback(pillar.queue_free)
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				var rel: Vector2 = (e as Node2D).global_position - at
				if absf(rel.x) > 30.0 or rel.y < -150.0 or rel.y > 34.0:
					continue
				var landed = e.take_damage(pay)
				if landed == null or landed:
					FloatingText.spawn(host, (e as Node2D).global_position
						+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, true)
				_apply_status_to(e)
				if e.has_method("apply_knockback"):
					e.apply_knockback(1 if rel.x >= 0.0 else -1, 120.0)

func _build_colonnade() -> void:
	pass    # the pillars draw themselves the instant they come up

# --- A CHOIR OF ONE: one shaft that becomes FIVE in flight --------------
var _harm_t := 0.0
var _harm_split := false

func _tick_harmonic(delta: float) -> void:
	_harm_t += delta
	global_position += direction * speed * delta
	traveled += speed * delta
	if not _harm_split and _harm_t >= 0.1:
		_harm_split = true
		_split_harmonics()
	if traveled >= max_distance:
		done = true
		queue_free()

func _split_harmonics() -> void:
	var host := get_parent()
	if host == null:
		return
	# the one voice becomes a chord: four more shafts fanning off this one
	for k in range(4):
		var h = (load("res://weapon_projectile.gd") as GDScript).new()
		h.kind = "shot"
		h.damage = maxi(1, int(round(float(damage) * 0.8)))
		h.element = element
		h.on_hit_status = on_hit_status
		h.source = source
		h.girth = girth
		h.speed = speed * randf_range(0.9, 1.12)
		h.max_distance = max_distance * 0.85
		h.direction = direction.rotated(deg_to_rad(-11.0 + 7.3 * float(k)))
		h.beam_tint = Color(0.82, 0.9, 1.0)
		host.add_child(h)
		h.global_position = global_position

func _build_harmonic() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-4, -4.0), Vector2(-26, 0), Vector2(-4, 4.0)])
	glow.color = Color(0.8, 0.9, 1.0, 0.45)
	glow.material = m
	visual.add_child(glow)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(12, -1.4), Vector2(-12, -1.4), Vector2(-12, 1.4), Vector2(12, 1.4)])
	shaft.color = Color(0.94, 0.98, 1.0, 0.96)
	shaft.material = m
	visual.add_child(shaft)

# --- THRONE OF STRINGS: seven strings across the room, and they RING ----
var _harp_t := 0.0
var _harp_fired := false
const HARP_STRINGS := 7
const HARP_LEN := 420.0

func _tick_harp(delta: float) -> void:
	_harp_t += delta
	if not _harp_fired and _harp_t >= 0.1:
		_harp_fired = true
		_pluck()
	if _harp_t >= 0.9:
		done = true
		queue_free()

func _pluck() -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pay: int = maxi(1, damage)
	var perp := Vector2(-direction.y, direction.x)
	for i in range(HARP_STRINGS):
		var off: float = (float(i) - float(HARP_STRINGS - 1) * 0.5) * 26.0
		var base: Vector2 = global_position + perp * off
		var line := Polygon2D.new()
		line.polygon = PackedVector2Array([
			Vector2(0, -1.6), Vector2(HARP_LEN, -1.6), Vector2(HARP_LEN, 1.6), Vector2(0, 1.6)])
		line.color = Color(0.96, 0.88, 0.6, 0.9)
		line.material = m
		line.z_index = 42
		line.rotation = direction.angle()
		host.add_child(line)
		line.global_position = base
		var tw := line.create_tween()
		tw.tween_interval(0.03 * float(i))
		tw.tween_property(line, "scale", Vector2(1.0, 3.4), 0.1)
		tw.tween_property(line, "scale", Vector2(1.0, 1.0), 0.12)
		tw.tween_property(line, "modulate:a", 0.0, 0.3)
		tw.tween_callback(line.queue_free)
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				var rel: Vector2 = (e as Node2D).global_position - base
				var along: float = rel.dot(direction)
				if along < 0.0 or along > HARP_LEN:
					continue
				if absf(rel.dot(perp)) > 15.0:
					continue
				var landed = e.take_damage(pay)
				if landed == null or landed:
					FloatingText.spawn(host, (e as Node2D).global_position
						+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, false)
				_apply_status_to(e)

func _build_harp() -> void:
	pass    # the strings appear on the pluck

# --- THE WORLD'S GRIEF: twelve tears, and each one finds someone --------
var _tear_prey: Node2D = null
var _tear_t := 0.0

func _tick_tear(delta: float) -> void:
	_tear_t += delta
	if _tear_prey == null or not is_instance_valid(_tear_prey) \
			or ("is_dead" in _tear_prey and _tear_prey.is_dead):
		_tear_prey = _nearest_hostile_node(460.0)
	if _tear_prey != null:
		var want: Vector2 = ((_tear_prey as Node2D).global_position - global_position).normalized()
		direction = direction.lerp(want, 5.0 * delta).normalized()
	_vel_y += 340.0 * delta
	global_position += direction * speed * delta + Vector2(0, _vel_y * delta)
	rotation = (direction * speed + Vector2(0, _vel_y)).angle()
	traveled += speed * delta
	if traveled >= max_distance or _tear_t > 2.4:
		done = true
		queue_free()

func _build_grief_tear() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tear := Polygon2D.new()
	tear.polygon = PackedVector2Array([
		Vector2(11, 0), Vector2(-2, -5.4), Vector2(-9, 0), Vector2(-2, 5.4)])
	tear.color = Color(0.66, 0.8, 0.98, 0.94)
	tear.material = m
	visual.add_child(tear)
	var wet := Polygon2D.new()
	wet.polygon = _circle(9.0, 8)
	wet.color = Color(0.5, 0.68, 0.96, 0.3)
	wet.material = m
	visual.add_child(wet)

# --- WHAT THE SKY CHARGES: the sky sends the BILL, in lightning ---------
var _sc_t := 0.0
var _sc_struck := 0
const SC_BOLTS := 8
const SC_GAP := 0.19
const SC_SPAN := 300.0

func _tick_skycharge(delta: float) -> void:
	_sc_t += delta
	if _sc_struck < SC_BOLTS and _sc_t >= float(_sc_struck) * SC_GAP:
		_strike_bolt(_sc_struck)
		_sc_struck += 1
		return
	if _sc_t >= float(SC_BOLTS) * SC_GAP + 0.4:
		done = true
		queue_free()

func _strike_bolt(idx: int) -> void:
	var host := get_parent()
	if host == null:
		return
	# prefer a living target; otherwise walk the span so the storm still reads
	var at: Vector2 = global_position + Vector2(
		randf_range(-SC_SPAN, SC_SPAN), 0)
	var prey := _nearest_hostile_node(SC_SPAN * 1.2)
	if prey != null and idx % 2 == 0:
		at = Vector2((prey as Node2D).global_position.x, global_position.y)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# a jagged bolt, drawn as a zigzag ribbon from the ceiling down
	var pts := PackedVector2Array()
	var back := PackedVector2Array()
	var y := -300.0
	var x := 0.0
	while y < 40.0:
		pts.append(Vector2(x, y))
		back.insert(0, Vector2(x + 5.0, y))
		y += 34.0
		x = randf_range(-16.0, 16.0)
	for p in back:
		pts.append(p)
	var bolt := Polygon2D.new()
	bolt.polygon = pts
	bolt.color = Color(0.86, 0.92, 1.0, 0.95)
	bolt.material = m
	bolt.z_index = 45
	host.add_child(bolt)
	bolt.global_position = at
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.24)
	tw.tween_callback(bolt.queue_free)
	_nova_burst_tinted(at + Vector2(0, 30.0), Color(0.8, 0.9, 1.0))

func _build_sky_charge() -> void:
	pass    # the storm is the bolts; the caster node is invisible

# --- A CUT ACROSS THE WORLD: one slash, the whole lane ------------------
# Straight off the study's aura ladder: at the crown the swing aura is TRADED
# AWAY for an every-swing screen-crossing beam (~22 player-heights).
var _wc_t := 0.0
const WC_LEN := 1050.0

func _tick_worldcut(delta: float) -> void:
	_wc_t += delta
	if _wc_t < 0.02:
		_world_cut()
	if visual:
		visual.scale = Vector2(1.0, maxf(0.05, 1.0 - _wc_t * 3.2))
		visual.modulate.a = 1.0 - _wc_t * 2.6
	if _wc_t >= 0.4:
		done = true
		queue_free()

func _world_cut() -> void:
	var host := get_parent()
	var pay: int = maxi(1, damage)
	var perp := Vector2(-direction.y, direction.x)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			var along: float = rel.dot(direction)
			if along < -40.0 or along > WC_LEN:
				continue
			if absf(rel.dot(perp)) > 46.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-22.0, 22.0), -26.0), pay, true)
			_apply_status_to(e)

func _build_world_cut() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-40, -7.0), Vector2(WC_LEN, -22.0),
		Vector2(WC_LEN, 22.0), Vector2(-40, 7.0)])
	core.color = Color(1.0, 0.98, 0.9, 0.92)
	core.material = m
	core.rotation = direction.angle()
	visual.add_child(core)
	var wide := Polygon2D.new()
	wide.polygon = PackedVector2Array([
		Vector2(-40, -20.0), Vector2(WC_LEN, -50.0),
		Vector2(WC_LEN, 50.0), Vector2(-40, 20.0)])
	wide.color = Color(0.7, 0.86, 1.0, 0.34)
	wide.material = m
	wide.rotation = direction.angle()
	visual.add_child(wide)

# --- THE PATIENT KNIFE / A KINGDOM, TURNING: swarms on the storm engine --
func _build_patient_storm() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# twelve small knives, all one colour: patience is not a pageant
	for i in range(12):
		var part := Node2D.new()
		var knife := Polygon2D.new()
		knife.polygon = PackedVector2Array([
			Vector2(0, -17.0), Vector2(3.4, -7.0), Vector2(2.2, 6.0),
			Vector2(-2.2, 6.0), Vector2(-3.4, -7.0)])
		knife.color = Color(0.86, 0.9, 0.94, 0.95)
		part.add_child(knife)
		var glint := Polygon2D.new()
		glint.polygon = PackedVector2Array([
			Vector2(0, -20.0), Vector2(1.6, -9.0), Vector2(-1.6, -9.0)])
		glint.color = Color(1.0, 1.0, 1.0, 0.85)
		glint.material = m
		part.add_child(glint)
		visual.add_child(part)
		_zs_parts.append(part)

func _build_kingdom_ring() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# six crowned shades, each holding a spear: a kingdom, turning
	for i in range(6):
		var tint: Color = WeaponFx.LEGACY_TINTS[i % WeaponFx.LEGACY_TINTS.size()]
		var part := Node2D.new()
		var body_k := Polygon2D.new()
		body_k.polygon = PackedVector2Array([
			Vector2(-6.0, 14.0), Vector2(-4.0, -10.0), Vector2(0, -16.0),
			Vector2(4.0, -10.0), Vector2(6.0, 14.0)])
		body_k.color = Color(tint.r * 0.7, tint.g * 0.66, tint.b * 0.78, 0.88)
		part.add_child(body_k)
		var crown := Polygon2D.new()
		crown.polygon = PackedVector2Array([
			Vector2(-5, -16.0), Vector2(-3, -22.0), Vector2(0, -18.0),
			Vector2(3, -22.0), Vector2(5, -16.0)])
		crown.color = Color(1.0, 0.88, 0.5, 0.95)
		crown.material = m
		part.add_child(crown)
		var spear := Polygon2D.new()
		spear.polygon = PackedVector2Array([
			Vector2(7.0, -26.0), Vector2(9.4, -26.0), Vector2(9.4, 14.0), Vector2(7.0, 14.0)])
		spear.color = Color(tint.r, tint.g, tint.b, 0.9)
		spear.material = m
		part.add_child(spear)
		visual.add_child(part)
		_zs_parts.append(part)

# ==========================================================================
# TIER 5, BATCH 4 -- the last eleven. Closes the tier.
# Includes the OMEN TRIO (Seeker / of Iron / the Third), built as a family:
# one reads the room, one weighs it down, one arrives in threes.
# ==========================================================================

# --- OMEN SEEKER: it reads the room, then everything it read pays --------
var _oe_t := 0.0
var _oe_marked: Array = []
const OE_LIFE := 1.9
const OE_SEE := 62.0

func _tick_omeneye(delta: float) -> void:
	_oe_t += delta
	global_position += direction * speed * delta
	if visual:
		visual.rotation = sin(_oe_t * 5.0) * 0.3
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.12 * sin(_oe_t * 8.0))
	# everything it drifts past is SEEN, and being seen is the whole cost
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or e in _oe_marked:
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if not e.has_method("take_damage"):
				continue
			if global_position.distance_to((e as Node2D).global_position) > OE_SEE:
				continue
			_oe_marked.append(e)
			_omen_mark(e)
	if _oe_t >= OE_LIFE:
		_omen_reckon()

func _omen_mark(who: Node2D) -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(0, -6.0), Vector2(9, 0), Vector2(0, 6.0)])
	eye.color = Color(0.86, 0.72, 1.0, 0.85)
	eye.material = m
	eye.z_index = 44
	eye.position = Vector2(0, -38.0)
	who.add_child(eye)
	var tw := eye.create_tween().set_loops()
	tw.tween_property(eye, "scale", Vector2(1.2, 0.8), 0.3)
	tw.tween_property(eye, "scale", Vector2(0.9, 1.15), 0.3)

func _omen_reckon() -> void:
	var host := get_parent()
	var pay: int = maxi(1, int(round(float(damage) * 1.3)))
	for e in _oe_marked:
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var landed = e.take_damage(pay)
		if landed == null or landed:
			FloatingText.spawn(host, (e as Node2D).global_position
				+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, true)
		_apply_status_to(e)
		_nova_burst_tinted((e as Node2D).global_position, Color(0.8, 0.66, 1.0))
	done = true
	queue_free()

func _build_omen_eye() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([
		Vector2(-17, 0), Vector2(0, -11.0), Vector2(17, 0), Vector2(0, 11.0)])
	lid.color = Color(0.72, 0.58, 0.94, 0.75)
	lid.material = m
	visual.add_child(lid)
	var pupil := Polygon2D.new()
	pupil.polygon = _circle(5.5, 8)
	pupil.color = Color(1.0, 0.96, 1.0, 0.98)
	pupil.material = m
	visual.add_child(pupil)

# --- KESTREL'S COURT: they HOVER, then stoop one after another ----------
var _ks_t := 0.0
var _ks_hover := 0.0
var _ks_prey: Node2D = null
var _ks_diving := false

func _tick_kestrel(delta: float) -> void:
	_ks_t += delta
	if not _ks_diving:
		# hold station, wings working, waiting its turn
		global_position += Vector2(0, sin(_ks_t * 9.0) * 22.0) * delta
		if _ks_t >= _ks_hover:
			_ks_diving = true
			_ks_prey = _nearest_hostile_node(560.0)
		return
	if _ks_prey != null and is_instance_valid(_ks_prey) \
			and not ("is_dead" in _ks_prey and _ks_prey.is_dead):
		var want: Vector2 = ((_ks_prey as Node2D).global_position - global_position).normalized()
		direction = direction.lerp(want, 9.0 * delta).normalized()
	global_position += direction * (speed * 1.7) * delta
	rotation = direction.angle()
	traveled += speed * delta
	if traveled >= max_distance:
		done = true
		queue_free()

func set_kestrel_hover(h: float) -> void:
	_ks_hover = h

func _build_kestrel() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for s in [-1.0, 1.0]:
		var wing := Polygon2D.new()
		wing.polygon = PackedVector2Array([
			Vector2(2, 0), Vector2(-7, 8.0 * s), Vector2(-11, 2.0 * s)])
		wing.color = Color(0.76, 0.62, 0.4, 0.9)
		visual.add_child(wing)
		var tw := wing.create_tween().set_loops()
		tw.tween_property(wing, "scale", Vector2(1.0, 0.5), 0.09)
		tw.tween_property(wing, "scale", Vector2(1.0, 1.0), 0.09)
	var body_ks := Polygon2D.new()
	body_ks.polygon = PackedVector2Array([
		Vector2(12, 0), Vector2(1, -3.4), Vector2(-9, 0), Vector2(1, 3.4)])
	body_ks.color = Color(0.92, 0.82, 0.6, 0.96)
	body_ks.material = m
	visual.add_child(body_ks)

# --- THUNDERHEAD: it parks overhead and throws lightning ----------------
var _th_t := 0.0
var _th_struck := 0
const TH_BOLTS := 4
const TH_GAP := 0.42

func _tick_thunderhead(delta: float) -> void:
	_th_t += delta
	if visual:
		visual.position.x = sin(_th_t * 1.4) * 8.0
	if _th_struck < TH_BOLTS and _th_t >= 0.3 + float(_th_struck) * TH_GAP:
		_strike_bolt(_th_struck)     # shared with What the Sky Charges
		_th_struck += 1
		return
	if _th_t >= 0.3 + float(TH_BOLTS) * TH_GAP + 0.4:
		done = true
		queue_free()

func _build_thunderhead() -> void:
	for k in range(4):
		var puff := Polygon2D.new()
		puff.polygon = _circle(randf_range(17.0, 26.0), 9)
		puff.color = Color(0.22, 0.24, 0.34, 0.88)
		puff.position = Vector2(-44.0 + 30.0 * float(k), randf_range(-5.0, 5.0))
		visual.add_child(puff)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(-4, 8.0), Vector2(2, -4.0), Vector2(-1, -3.0), Vector2(5, -14.0),
		Vector2(0, -2.0), Vector2(3, -1.0)])
	spark.color = Color(0.9, 0.94, 1.0, 0.7)
	spark.material = m
	visual.add_child(spark)
	var tw := spark.create_tween().set_loops()
	tw.tween_property(spark, "modulate:a", 0.15, 0.24)
	tw.tween_property(spark, "modulate:a", 0.9, 0.18)

# --- MIDNIGHT POST: it gathers the dark in, then throws it out ----------
var _mp_t := 0.0
var _mp_burst := false
const MP_GATHER := 1.1
const MP_R := 130.0

func _tick_midnight(delta: float) -> void:
	_mp_t += delta
	var frac: float = clampf(_mp_t / MP_GATHER, 0.0, 1.0)
	if visual:
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.5 * frac)
		visual.rotation += (1.4 + 5.0 * frac) * delta
	if not _mp_burst:
		# haul everything nearby toward the post while it charges
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				var to_post: Vector2 = global_position - (e as Node2D).global_position
				var d: float = to_post.length()
				if d < 20.0 or d > MP_R * 1.5:
					continue
				(e as Node2D).global_position += to_post.normalized() * 118.0 * delta
		if _mp_t >= MP_GATHER:
			_mp_burst = true
			_midnight_out()
		return
	if _mp_t >= MP_GATHER + 0.5:
		done = true
		queue_free()

func _midnight_out() -> void:
	var host := get_parent()
	if host == null:
		return
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var pay: int = maxi(1, damage)
	# eight spokes of night, straight out
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var spoke := Polygon2D.new()
		spoke.polygon = PackedVector2Array([
			Vector2(0, -6.0), Vector2(MP_R, -14.0), Vector2(MP_R, 14.0), Vector2(0, 6.0)])
		spoke.color = Color(0.36, 0.24, 0.52, 0.85)
		spoke.material = m
		spoke.z_index = 43
		spoke.rotation = a
		host.add_child(spoke)
		spoke.global_position = global_position
		spoke.scale = Vector2(0.05, 1.0)
		var tw := spoke.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spoke, "scale", Vector2.ONE, 0.16)
		tw.tween_property(spoke, "modulate:a", 0.0, 0.42)
		tw.chain().tween_callback(spoke.queue_free)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			if rel.length() > MP_R:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-18.0, 18.0), -26.0), pay, true)
			_apply_status_to(e)
			if e.has_method("apply_knockback"):
				e.apply_knockback(1 if rel.x >= 0.0 else -1, 260.0)

func _build_midnight_post() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3.0, 22.0), Vector2(-2.0, -22.0), Vector2(2.0, -22.0), Vector2(3.0, 22.0)])
	post.color = Color(0.2, 0.17, 0.26, 0.96)
	visual.add_child(post)
	for k in range(3):
		var ring := Polygon2D.new()
		var rr: float = 12.0 + 6.0 * float(k)
		var pts := PackedVector2Array()
		for i in range(12):
			var a := TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.4))
		for i in range(12):
			var a2 := TAU * float(11 - i) / 12.0
			pts.append(Vector2(cos(a2) * (rr - 2.0), sin(a2) * (rr - 2.0) * 0.4))
		ring.polygon = pts
		ring.color = Color(0.5, 0.34, 0.72, 0.55 - 0.12 * float(k))
		ring.material = m
		visual.add_child(ring)

# --- THE SIREN'S APPENDIX: it SINGS them in, then shuts ------------------
var _sr_t := 0.0
const SR_SING := 1.3
const SR_CONE := 250.0

func _tick_siren(delta: float) -> void:
	_sr_t += delta
	if _sr_t >= SR_SING:
		_nova_burst_tinted(global_position, Color(0.5, 0.9, 0.86))
		done = true
		queue_free()
		return
	if visual:
		visual.scale = Vector2.ONE * _draw_girth * (1.0 + 0.14 * sin(_sr_t * 11.0))
	# they walk toward the singing, whether or not they meant to
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = global_position - (e as Node2D).global_position
			if rel.length() > SR_CONE:
				continue
			(e as Node2D).global_position += rel.normalized() * 96.0 * delta
	_rehit_t += delta
	if _rehit_t < 0.4:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > SR_CONE:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)

func _build_siren_song() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var book := Polygon2D.new()
	book.polygon = PackedVector2Array([
		Vector2(-15, -10.0), Vector2(0, -6.0), Vector2(15, -10.0),
		Vector2(15, 10.0), Vector2(0, 14.0), Vector2(-15, 10.0)])
	book.color = Color(0.24, 0.5, 0.52, 0.95)
	visual.add_child(book)
	# the song: staves rippling outward
	for k in range(3):
		var wave := Polygon2D.new()
		var rr: float = 24.0 + 16.0 * float(k)
		var pts := PackedVector2Array()
		for i in range(14):
			var a := TAU * float(i) / 14.0
			pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.55))
		for i in range(14):
			var a2 := TAU * float(13 - i) / 14.0
			pts.append(Vector2(cos(a2) * (rr - 3.0), sin(a2) * (rr - 3.0) * 0.55))
		wave.polygon = pts
		wave.color = Color(0.56, 0.94, 0.9, 0.4 - 0.1 * float(k))
		wave.material = m
		visual.add_child(wave)
		var tw := wave.create_tween().set_loops()
		tw.tween_property(wave, "scale", Vector2(1.25, 1.25), 0.5 + 0.14 * float(k))
		tw.tween_property(wave, "scale", Vector2(1.0, 1.0), 0.5 + 0.14 * float(k))

# --- STARSPLINTER: eight splinters that hang, then converge -------------
var _sp_t := 0.0
var _sp_home := Vector2.ZERO
var _sp_ang := 0.0
const SP_HANG := 0.5

func _tick_splinter(delta: float) -> void:
	_sp_t += delta
	if _sp_home == Vector2.ZERO:
		_sp_home = global_position
	if _sp_t < SP_HANG:
		# fly out to its station and wait, glinting
		var t: float = _sp_t / SP_HANG
		global_position = _sp_home + Vector2(cos(_sp_ang), sin(_sp_ang)) * (128.0 * t)
		rotation = _sp_ang
		return
	# then they all come back through the middle at once
	var toward: Vector2 = (_sp_home - global_position)
	if toward.length() < 18.0:
		done = true
		queue_free()
		return
	global_position += toward.normalized() * 620.0 * delta
	rotation = toward.angle()

func set_splinter_angle(a: float) -> void:
	_sp_ang = a

func _build_star_splinter() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(-2, -4.4), Vector2(-11, 0), Vector2(-2, 4.4)])
	shard.color = Color(0.92, 0.94, 1.0, 0.96)
	shard.material = m
	visual.add_child(shard)

# --- EMBERHYMN: each cast is another verse, and the fire climbs ----------
var _eh_t := 0.0
var _eh_h := 0.0
const EH_LIFE := 1.6

func _tick_emberhymn(delta: float) -> void:
	_eh_t += delta
	if visual:
		visual.scale = Vector2(1.0, 1.0) * _draw_girth
		visual.modulate.a = 1.0 - pow(_eh_t / EH_LIFE, 3.0)
	if _eh_t >= EH_LIFE:
		done = true
		queue_free()
		return
	_rehit_t += delta
	if _rehit_t < 0.3:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			var rel: Vector2 = (e as Node2D).global_position - global_position
			if absf(rel.x) > 40.0 or rel.y < -_eh_h or rel.y > 40.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)

func set_hymn_height(h: float) -> void:
	_eh_h = h
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the verse so far, drawn as a column: the taller it is, the longer you
	# have kept singing without stopping
	var col := Polygon2D.new()
	col.polygon = PackedVector2Array([
		Vector2(-26, 30.0), Vector2(-15, -h * 0.55), Vector2(0, -h),
		Vector2(15, -h * 0.55), Vector2(26, 30.0)])
	col.color = Color(1.0, 0.5, 0.16, 0.62)
	col.material = m
	visual.add_child(col)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-12, 26.0), Vector2(-6, -h * 0.5), Vector2(0, -h * 0.86),
		Vector2(6, -h * 0.5), Vector2(12, 26.0)])
	core.color = Color(1.0, 0.86, 0.42, 0.8)
	core.material = m
	visual.add_child(core)

# --- SAINT'S REWARD: the halo pays you back for every strike -------------
var _sn_t := 0.0
var _sn_given := 0
const SN_LIFE := 4.0

func _tick_saint(delta: float) -> void:
	_sn_t += delta
	if _sn_t >= SN_LIFE or not is_instance_valid(source):
		done = true
		queue_free()
		return
	var centre: Vector2 = (source as Node2D).global_position + Vector2(0, -30.0)
	var ang: float = _sn_t * 4.4
	global_position = centre + Vector2(cos(ang), sin(ang) * 0.4) * 72.0
	if visual:
		visual.rotation += 3.0 * delta
	_rehit_t += delta
	if _rehit_t < 0.3:
		return
	_rehit_t = 0.0
	var host := get_parent()
	var pay: int = maxi(1, damage)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to((e as Node2D).global_position) > 38.0:
				continue
			var landed = e.take_damage(pay)
			if landed == null or landed:
				FloatingText.spawn(host, (e as Node2D).global_position
					+ Vector2(randf_range(-16.0, 16.0), -26.0), pay, false)
			_apply_status_to(e)
			# THE REWARD: a saint's work comes back to the one who did it
			if _sn_given < 8 and is_instance_valid(source) and source.has_method("heal"):
				_sn_given += 1
				source.heal(2)
				FloatingText.spawn_word(host,
					(source as Node2D).global_position + Vector2(0, -54), "+2",
					Color(1.0, 0.94, 0.7))

func _build_saint_halo() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a) * 19.0, sin(a) * 8.0))
	for i in range(18):
		var a2 := TAU * float(17 - i) / 18.0
		pts.append(Vector2(cos(a2) * 14.0, sin(a2) * 5.0))
	ring.polygon = pts
	ring.color = Color(1.0, 0.94, 0.62, 0.92)
	ring.material = m
	visual.add_child(ring)
	for k in range(4):
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([
			Vector2(-1.8, -24.0), Vector2(1.8, -24.0), Vector2(1.0, -18.0), Vector2(-1.0, -18.0)])
		ray.color = Color(1.0, 0.98, 0.8, 0.75)
		ray.material = m
		ray.rotation = deg_to_rad(90.0 * float(k))
		visual.add_child(ray)

# --- OMEN OF IRON: the sigil leaves IRON standing where it bounced ------
func _build_iron_spike() -> void:
	_zone_max = 3.4
	_zone_r = 44.0
	_zone_gap = 0.5
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for k in range(3):
		var spike := Polygon2D.new()
		var h: float = randf_range(20.0, 34.0)
		spike.polygon = PackedVector2Array([
			Vector2(-5.0, 8.0), Vector2(0, -h), Vector2(5.0, 8.0)])
		spike.color = Color(0.48, 0.5, 0.56, 0.95)
		spike.position = Vector2(-14.0 + 14.0 * float(k), 0)
		visual.add_child(spike)
		var glint := Polygon2D.new()
		glint.polygon = PackedVector2Array([
			Vector2(-1.4, 2.0), Vector2(0, -h * 0.9), Vector2(1.4, 2.0)])
		glint.color = Color(0.86, 0.9, 1.0, 0.6)
		glint.material = m
		glint.position = spike.position
		visual.add_child(glint)

func _build_omen_sigil() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var plate := Polygon2D.new()
	plate.polygon = PackedVector2Array([
		Vector2(0, -13.0), Vector2(11, -5.0), Vector2(7, 10.0),
		Vector2(-7, 10.0), Vector2(-11, -5.0)])
	plate.color = Color(0.52, 0.54, 0.6, 0.96)
	visual.add_child(plate)
	var rune := Polygon2D.new()
	rune.polygon = PackedVector2Array([
		Vector2(-4, -5.0), Vector2(4, -5.0), Vector2(0, 1.0), Vector2(4, 6.0), Vector2(-4, 6.0)])
	rune.color = Color(0.9, 0.82, 0.5, 0.9)
	rune.material = m
	visual.add_child(rune)

# ==========================================================================
# TIER 4, BATCH 1. Epic tier: the power still lives in the VERB, just at a
# smaller scale than the crown -- fewer blades, shorter reach, same idea.
# ==========================================================================

# --- HOWLPIECE: the crescent HOWLS as it goes ---------------------------
var _hw2_t := 0.0
var _hw2_next := 0.14

func _tick_howl(delta: float) -> void:
	_hw2_t += delta
	global_position += direction * speed * delta
	traveled += speed * delta
	if visual:
		visual.rotation += 9.0 * delta
	_rehit_t += delta
	if _rehit_t >= 0.3:
		_rehit_t = 0.0
		hit_bodies.clear()
	# every beat it lets out a ring ACROSS its own path, so the lane it flies
	# is wider than the blade and you can see exactly how wide
	if _hw2_t >= _hw2_next:
		_hw2_next += 0.17
		var host := get_parent()
		if host != null:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var ring := Polygon2D.new()
			ring.polygon = PackedVector2Array([
				Vector2(-3.0, -10.0), Vector2(3.0, -10.0),
				Vector2(3.0, 10.0), Vector2(-3.0, 10.0)])
			ring.color = Color(0.72, 0.86, 0.96, 0.7)
			ring.material = m
			ring.z_index = 41
			ring.rotation = direction.angle()
			host.add_child(ring)
			ring.global_position = global_position
			var tw := ring.create_tween()
			tw.set_parallel(true)
			tw.tween_property(ring, "scale", Vector2(1.0, 5.5), 0.26)
			tw.tween_property(ring, "modulate:a", 0.0, 0.26)
			tw.chain().tween_callback(ring.queue_free)
			var pay: int = maxi(1, int(round(float(damage) * 0.45)))
			var perp := Vector2(-direction.y, direction.x)
			for group_name in HOSTILE_GROUPS:
				for e in get_tree().get_nodes_in_group(group_name):
					if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
						continue
					if "is_dead" in e and e.is_dead:
						continue
					var rel: Vector2 = (e as Node2D).global_position - global_position
					if absf(rel.dot(direction)) > 18.0 or absf(rel.dot(perp)) > 56.0:
						continue
					var landed = e.take_damage(pay)
					if landed == null or landed:
						FloatingText.spawn(host, (e as Node2D).global_position
							+ Vector2(randf_range(-14.0, 14.0), -26.0), pay, false)
					_apply_status_to(e)
	if traveled >= max_distance:
		done = true
		queue_free()

func _build_howl_crescent() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var arc := Polygon2D.new()
	arc.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(2, -15.0), Vector2(-12, -10.0),
		Vector2(-4, 0), Vector2(-12, 10.0), Vector2(2, 15.0)])
	arc.color = Color(0.7, 0.84, 0.98, 0.88)
	arc.material = m
	visual.add_child(arc)

# --- WINTERWHEEL: it ROLLS, and the floor freezes behind it -------------
var _fr_t := 0.0
var _fr_drop := 0.0

func _tick_roller(delta: float) -> void:
	_fr_t += delta
	global_position += direction * speed * delta
	traveled += speed * delta
	if visual:
		visual.rotation += (speed / 24.0) * delta * (1.0 if direction.x >= 0.0 else -1.0)
	_rehit_t += delta
	if _rehit_t >= 0.3:
		_rehit_t = 0.0
		hit_bodies.clear()
	# the track: rime laid on the floor the whole way, so the lane stays cold
	_fr_drop -= delta
	if _fr_drop <= 0.0:
		_fr_drop = 0.07
		var host := get_parent()
		if host != null:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var rime := Polygon2D.new()
			rime.polygon = PackedVector2Array([
				Vector2(-7.0, 3.0), Vector2(0, -randf_range(5.0, 11.0)), Vector2(7.0, 3.0)])
			rime.color = Color(0.7, 0.9, 1.0, 0.62)
			rime.material = m
			rime.z_index = 7
			host.add_child(rime)
			rime.global_position = global_position + Vector2(0, 16.0)
			var tw := rime.create_tween()
			tw.tween_interval(1.1)
			tw.tween_property(rime, "modulate:a", 0.0, 0.6)
			tw.tween_callback(rime.queue_free)
	if traveled >= max_distance:
		done = true
		queue_free()

func _build_frost_roller() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 15.0)
	for i in range(12):
		var a2 := TAU * float(11 - i) / 12.0
		pts.append(Vector2(cos(a2), sin(a2)) * 9.0)
	rim.polygon = pts
	rim.color = Color(0.72, 0.9, 1.0, 0.9)
	rim.material = m
	visual.add_child(rim)
	for k in range(5):
		var stud := Polygon2D.new()
		stud.polygon = PackedVector2Array([
			Vector2(-2.6, -14.0), Vector2(0, -20.0), Vector2(2.6, -14.0)])
		stud.color = Color(0.9, 0.97, 1.0, 0.92)
		stud.material = m
		stud.rotation = deg_to_rad(72.0 * float(k))
		visual.add_child(stud)

# --- REAPER'S REBUKE: the scythe GROWS on the way round -----------------
func _build_reaper_return() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var haft := Polygon2D.new()
	haft.polygon = PackedVector2Array([
		Vector2(-13, -1.8), Vector2(9, -1.8), Vector2(9, 1.8), Vector2(-13, 1.8)])
	haft.color = Color(0.36, 0.3, 0.26, 0.95)
	visual.add_child(haft)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(9, -2.0), Vector2(20, -13.0), Vector2(23, -4.0),
		Vector2(14, 3.0), Vector2(9, 2.0)])
	blade.color = Color(0.82, 0.9, 0.86, 0.95)
	blade.material = m
	visual.add_child(blade)

# --- PRISMBREAK: one bolt in, three colours out -------------------------
func _prism_split(at: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var tints := [Color(1.0, 0.5, 0.5), Color(0.5, 1.0, 0.6), Color(0.55, 0.7, 1.0)]
	for k in range(3):
		var b = (load("res://weapon_projectile.gd") as GDScript).new()
		b.kind = "shot"
		b.damage = maxi(1, int(round(float(damage) * 0.55)))
		b.element = element
		b.on_hit_status = on_hit_status
		b.source = source
		b.girth = girth * 0.85
		b.speed = speed * 0.9
		b.max_distance = max_distance * 0.6
		b.direction = direction.rotated(deg_to_rad(-26.0 + 26.0 * float(k)))
		b.beam_tint = tints[k]
		host.add_child(b)
		b.global_position = at

func _build_prism_bolt() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -11.0), Vector2(9, 5.0), Vector2(-9, 5.0)])
	core.color = Color(0.96, 0.96, 1.0, 0.95)
	core.material = m
	visual.add_child(core)
	for k in range(3):
		var facet := Polygon2D.new()
		facet.polygon = PackedVector2Array([
			Vector2(0, -7.0), Vector2(5, 3.0), Vector2(-5, 3.0)])
		facet.color = [Color(1.0, 0.5, 0.5, 0.55), Color(0.5, 1.0, 0.6, 0.55),
			Color(0.55, 0.7, 1.0, 0.55)][k]
		facet.material = m
		facet.position = Vector2(-3.0 + 3.0 * float(k), 0)
		visual.add_child(facet)

# --- COMET ON A CHAIN: the hurl drops fire behind it --------------------
var _cc_drop := 0.0

func _tick_comet_chain(delta: float) -> void:
	_tick_chainmaul(delta)
	if done:
		return
	_cc_drop -= delta
	if _cc_drop > 0.0:
		return
	_cc_drop = 0.16
	var host := get_parent()
	if host == null:
		return
	var fb = (load("res://weapon_projectile.gd") as GDScript).new()
	fb.kind = "cinder_patch"
	fb.damage = maxi(1, int(round(float(damage) * 0.22)))
	fb.element = element
	fb.on_hit_status = on_hit_status
	fb.source = source
	fb.girth = girth * 0.55
	host.add_child(fb)
	fb.global_position = global_position + Vector2(randf_range(-8.0, 8.0), 10.0)

func _circle(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts
