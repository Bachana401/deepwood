extends CharacterBody2D

# ---------------------------------------------------------------------------
# Dungeon boss.
#
# Every 5th dungeon level (5, 10, 15, ...) spawns ONE boss. Rather than a
# single hard-coded fight, each boss is a data entry in BOSSES below: its own
# body/colors, base health, move speed, and -- most importantly -- its own
# hand-picked set of abilities from the shared library further down. That is
# what makes each boss feel individual.
#
# dungeon_interior.gd picks which boss id a level uses (see get_boss_id there),
# sets boss_id + the level scaling multipliers, THEN adds the node to the tree
# so _ready() can build itself from the matching definition.
# ---------------------------------------------------------------------------

const GRAVITY = 900.0
const ENRAGE_THRESHOLD = 0.5
const BUMP_THRESHOLD = 110.0
const WALL_TURN_DURATION = 0.8

# --- shared ability tuning ---
# Ranges are deliberately long: boss arenas are 3-5x the regular width, so a
# boss must be able to threaten across a big gap or it just gets kited.
const SLAM_RADIUS = 220.0
const SLAM_DAMAGE = 30
const SLAM_KNOCKBACK = 260.0
const SLAM_TELEGRAPH = 0.55

const CHARGE_SPEED = 720.0
const CHARGE_DURATION = 0.85
const CHARGE_DAMAGE = 26
const CHARGE_KNOCKBACK = 300.0
const CHARGE_TELEGRAPH = 0.45
const CHARGE_HIT_RADIUS = 135.0

const BARRAGE_COUNT = 7
const BARRAGE_SPREAD_DEG = 13.0
const BARRAGE_DAMAGE = 12
const BARRAGE_TELEGRAPH = 0.35
const BARRAGE_RANGE = 1300.0

const RAIN_COUNT = 13
const RAIN_DAMAGE = 12
const RAIN_TELEGRAPH = 0.6
const RAIN_HEIGHT = 470.0
const RAIN_HALF_SPREAD = 480.0

const NOVA_COUNT = 22
const NOVA_DAMAGE = 11
const NOVA_TELEGRAPH = 0.42
const NOVA_RANGE = 1300.0

const TELEPORT_TELEGRAPH = 0.32
const TELEPORT_SHOCK_DAMAGE = 22
const TELEPORT_SHOCK_RADIUS = 95.0

const SUMMON_COUNT = 2
const MAX_MINIONS = 4
const SUMMON_TELEGRAPH = 0.5

const PILLAR_COUNT = 6
const PILLAR_DAMAGE = 27
const PILLAR_TELEGRAPH = 0.7
const PILLAR_HALF_WIDTH = 46.0
const PILLAR_KNOCKBACK = 130.0
const PILLAR_HEIGHT = 320.0
const PILLAR_SPREAD = 720.0

# --- apex ability tuning (the level 35+ monsters) ---
const HOVER_ALTITUDE = 270.0        # how high a flying boss cruises above the player

const DIVE_DAMAGE = 34
const DIVE_RADIUS = 160.0
const DIVE_KNOCKBACK = 260.0
const DIVE_RISE_SPEED = 460.0
const DIVE_PLUNGE_SPEED = 980.0

const VOLLEY_COUNT = 6
const VOLLEY_DAMAGE = 10
const VOLLEY_INTERVAL = 0.16
const VOLLEY_RANGE = 1500.0

const METEOR_COUNT = 10
const METEOR_DAMAGE = 20
const METEOR_TELEGRAPH = 0.8
const METEOR_SPREAD = 850.0
const METEOR_HEIGHT = 800.0

const VORTEX_DURATION = 1.6
const VORTEX_TICK = 0.12
const VORTEX_PULL = 34.0
const VORTEX_RANGE = 900.0
const VORTEX_DAMAGE = 16
const VORTEX_CLOSE = 150.0

const BEAM_TELEGRAPH = 0.9
const BEAM_HALF_HEIGHT = 55.0
const BEAM_DAMAGE = 38
const BEAM_KNOCKBACK = 200.0

const CURSE_ORBS = 4          # the Wizard's homing curse volley
const CURSE_DAMAGE = 14
const CURSE_ORB_SPEED = 150.0
const CURSE_TELEGRAPH = 0.4

# --- the Fallen Wizard's passives & doomring ---
const AURA_RADIUS = 150.0     # crumbling red aura: stand inside and burn
const AURA_TICK = 0.5
const AURA_DAMAGE = 5         # scaled by sqrt of level dmg mult, not the full mult
const BLINK_ON_HIT_CHANCE = 0.18
const DOOMRING_BOLTS = 16
const DOOMRING_WAVES = 2
const DOOMRING_RANGE = 900.0
const DOOMRING_DAMAGE = 13

# Mirror Legion: the Wizard copies himself, up to 6 echoes at once -- but the
# legion grows SLOWLY: at full HP no echoes are allowed at all, and the cap
# rises with his missing health (see allowed_clones), only reaching 6 near
# death. Echoes are deliberately weak fakes -- a sliver of HP, reduced damage,
# only volleys and curses, slower cooldowns, and NO aura/reflex-blink (the
# real one is the one wreathed in crumbling red).
const MAX_CLONES = 6
const CLONES_PER_CAST = 2
const CLONE_HP_FRAC = 0.12
const CLONE_DMG_FRAC = 0.35
const CLONE_CD_PENALTY = 1.5
const CLONE_KIT = ["volley", "curse"]

# Soul Ward: the Wizard's defence is his undivided soul. With NO echoes out he
# only takes half damage -- bursting him early is a wall. Every living echo
# carries a shard of his soul (and a visible shard of his aura), cracking the
# ward: +25% damage taken per echo, up to 2x at the full legion of 6. The kill
# logic: let the legion grow, survive it, and burst him while he is split.
const SOUL_WARD_BASE = 0.5
const SOUL_WARD_PER_CLONE = 0.25
# how much of each aura layer every echo carries away (particle counts)
const CLONE_SHARD_RED = 7
const CLONE_SHARD_PURPLE = 5

# --- weapon counter (set per boss level by dungeon_interior.gd) ---
# Only the first 8 boss levels (5-40) are countered; deeper bosses set
# counter_role = "" and take every weapon at face value. When a counter IS
# set, the matching weapon gets +30% damage AND a distinct mechanical edge;
# every other weapon is partly "guarded" (75%). See trigger_counter_mechanic.
const COUNTER_DMG_BONUS = 1.3
const GUARD_MULT = 0.75
const EXPOSE_DURATION = 3.5    # archer: an arrow strips the guard for everyone
const HEX_DURATION = 4.0       # mage: a wand hit slows the boss
const HEX_SPEED_MULT = 0.55
const HEX_CD_PENALTY = 1.4
const STAGGER_MAX = 4          # sword: this many melee hits -> a stun
const STUN_DURATION = 1.3

# Per-ability metadata: cooldown after use, and the player-distance window in
# which the ability is a valid choice. choose_attack() filters on these.
const ABILITY_META = {
	"slam":     {"cd": 3.5, "min": 0.0,   "max": 210.0},
	"charge":   {"cd": 4.5, "min": 160.0, "max": 100000.0},
	"barrage":  {"cd": 3.2, "min": 0.0,   "max": 100000.0},
	"rain":     {"cd": 5.5, "min": 0.0,   "max": 100000.0},
	"nova":     {"cd": 4.6, "min": 0.0,   "max": 480.0},
	"teleport": {"cd": 6.0, "min": 0.0,   "max": 100000.0},
	"summon":   {"cd": 10.0, "min": 0.0,  "max": 100000.0},
	"pillars":  {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	# apex abilities
	"dive":     {"cd": 5.0, "min": 0.0,   "max": 100000.0},
	"volley":   {"cd": 3.6, "min": 0.0,   "max": 100000.0},
	"meteors":  {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"vortex":   {"cd": 8.0, "min": 0.0,   "max": 100000.0},
	"beam":     {"cd": 7.0, "min": 0.0,   "max": 100000.0},
	"curse":    {"cd": 5.5, "min": 0.0,   "max": 100000.0},
	"doomring": {"cd": 6.0, "min": 0.0,   "max": 100000.0},
	"clone":    {"cd": 12.0, "min": 0.0,  "max": 100000.0},
}

# The roster. Ids here must line up with BOSS_ARENAS / get_boss_id in
# dungeon_interior.gd so each boss gets its matching arena.
#
# Every boss is a deepwood undead/monster with a body SIZE that matches its
# role -- hulking tanks are huge, casters slim, the spider small and nimble --
# and a "magic" colour its spell effects (markers, pillars, shocks) are drawn
# in, so powers visually belong to the creature (the abyss-wyrm rains teal
# water-spouts, the burnt stag erupts fire, the storm-owl calls lightning).
# Melee-ish hit radii scale with the body via reach_mult (see configure).
const BOSSES = {
	# A hulking grave-troll of root and grave-soil, a tombstone sunk in its
	# chest. Big and slow; its slam and bull-charge hit wide.
	"gravewarden": {
		"name": "The Gravewarden",
		"color": Color(0.26, 0.32, 0.22), "eye_color": Color(0.7, 1.0, 0.4),
		"magic": Color(0.55, 0.95, 0.35),
		"body": Vector2(200, 260), "hp": 1000, "speed": 72.0, "shape": "brute",
		"abilities": ["slam", "charge", "summon"],
	},
	# A tall, skeletal-thin frozen lich-king in an icy shroud.
	"frost_monarch": {
		"name": "The Frost Monarch",
		"color": Color(0.55, 0.68, 0.8), "eye_color": Color(0.85, 0.97, 1.0),
		"magic": Color(0.65, 0.9, 1.0),
		"body": Vector2(110, 250), "hp": 780, "speed": 56.0, "shape": "crown",
		"abilities": ["rain", "nova", "teleport"],
	},
	# A huge charcoal stag-demon, antlers still burning from the forest fire
	# that killed it. Stampedes and erupts fire.
	"cinder_colossus": {
		"name": "The Cinder Colossus",
		"color": Color(0.16, 0.12, 0.11), "eye_color": Color(1.0, 0.6, 0.15),
		"magic": Color(1.0, 0.5, 0.12),
		"body": Vector2(240, 230), "hp": 1100, "speed": 95.0, "shape": "colossus",
		"abilities": ["charge", "barrage", "pillars"],
	},
	# A SMALL corpse-spider brood mother -- quick, evasive, hard to corner;
	# her legs span far wider than her body.
	"weaver": {
		"name": "The Weaver",
		"color": Color(0.3, 0.22, 0.34), "eye_color": Color(1.0, 0.4, 0.9),
		"magic": Color(0.95, 0.4, 0.85),
		"body": Vector2(120, 110), "hp": 720, "speed": 105.0, "shape": "spider",
		"abilities": ["summon", "nova", "teleport"],
	},
	# A lightning-scarred owl-wraith of the dead canopy; medium build.
	"stormcaller": {
		"name": "The Stormcaller",
		"color": Color(0.36, 0.38, 0.3), "eye_color": Color(1.0, 1.0, 0.55),
		"magic": Color(0.95, 0.95, 0.55),
		"body": Vector2(150, 180), "hp": 880, "speed": 88.0, "shape": "caster",
		"abilities": ["nova", "pillars", "barrage"],
	},
	# The hollow king: a dead monarch whose chest is an open void, his crown
	# floating above the ruin of his head.
	"void_sovereign": {
		"name": "The Void Sovereign",
		"color": Color(0.17, 0.11, 0.25), "eye_color": Color(0.9, 0.2, 1.0),
		"magic": Color(0.75, 0.3, 1.0),
		"body": Vector2(170, 240), "hp": 1220, "speed": 76.0, "shape": "void",
		"abilities": ["teleport", "rain", "nova", "summon"],
	},
	# ----- FINALE TIER (levels 95/98/99/100) -----
	# Apex bosses: enrage earlier, FRENZY at low health, and most fly.
	# A fallen angel of bone: skeletal wings, tarnished halo.
	"seraph": {
		"name": "Seraphiel, the Last Light",
		"color": Color(0.78, 0.74, 0.6), "eye_color": Color(1.0, 0.55, 0.1),
		"magic": Color(1.0, 0.85, 0.4),
		"body": Vector2(140, 220), "hp": 2400, "speed": 130.0, "shape": "angel",
		"flying": true, "apex": true,
		"abilities": ["dive", "volley", "rain", "nova"],
	},
	# A LONG skeletal abyss-wyrm; its "meteors" are teal water-spouts and its
	# vortex a drowning whirlpool -- water powers for a water beast.
	"leviathan": {
		"name": "The Abyssal Leviathan",
		"color": Color(0.12, 0.3, 0.34), "eye_color": Color(0.4, 1.0, 0.9),
		"magic": Color(0.3, 0.9, 0.85),
		"body": Vector2(340, 120), "hp": 2800, "speed": 150.0, "shape": "serpent",
		"flying": true, "apex": true,
		"abilities": ["charge", "vortex", "meteors", "summon"],
	},
	# The biggest creature in the game: a dead god crowned by a black sun.
	"eclipse": {
		"name": "The Eclipse Titan",
		"color": Color(0.09, 0.06, 0.08), "eye_color": Color(1.0, 0.2, 0.1),
		"magic": Color(1.0, 0.25, 0.12),
		"body": Vector2(260, 340), "hp": 3300, "speed": 90.0, "shape": "titan",
		"apex": true,
		"abilities": ["beam", "pillars", "meteors", "teleport", "summon"],
	},
	# The level-100 finale: barely taller than the adventurer -- his power is
	# his magic, not his bulk. Pitch-black robes wreathed in a crumbling red
	# aura (with a lagging purple echo) that burns anyone inside it; he blinks
	# reflexively when struck, and he mirrors himself into a legion of up to 6
	# echoes. Nothing counters him.
	"wizard": {
		"name": "The Fallen Wizard",
		"color": Color(0.09, 0.05, 0.07), "eye_color": Color(1.0, 0.12, 0.08),
		"magic": Color(1.0, 0.22, 0.12),
		"body": Vector2(34, 52), "hp": 4000, "speed": 120.0, "shape": "wizard",
		"flying": true, "apex": true,
		"passives": ["crumbling_aura", "blink_on_hit", "soul_split"],
		"abilities": ["curse", "beam", "meteors", "teleport", "volley", "doomring", "clone"],
	},
}

const ARROW_SCENE = preload("res://arrow.tscn")
const MINION_SCENE = preload("res://enemy.tscn")
const MAGIC_ORB = preload("res://magic_orb.gd")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_HIT = preload("res://audio/hit.wav")

signal died

# Set by dungeon_interior.gd before the node enters the tree.
var boss_id: String = "gravewarden"
var level_hp_mult := 1.0
var damage_multiplier := 1.0
var speed_multiplier := 1.0

var current_def: Dictionary = {}
var abilities: Array = []
var ability_cd: Dictionary = {}
var base_move_speed := 62.0

var player: Node2D = null
var max_health := 900
var health := 900
var is_dead := false
var is_enraged := false
var facing_direction := 1
var base_color: Color
var magic_color := Color(1, 1, 1)   # per-boss spell/effect palette
var reach_mult := 1.0               # melee-ish radii scale with body size
var rig: Node2D = null              # the procedural creature body
var current_tint := Color(1, 1, 1)  # rig modulate baseline (shifts on enrage)

var is_busy := false
var is_charging := false
var charge_direction := 1
var charge_dir_2d := Vector2.RIGHT   # flying bosses charge in a full 2D line
var charge_timer := 0.0
var charge_has_hit := false
var is_wall_blocked := false
var wall_turn_timer := 0.0

# weapon-counter state
var counter_role := ""        # "sword" | "archer" | "mage"; "" = counter-immune
var exposed_timer := 0.0
var hex_timer := 0.0
var stagger := 0
var stun_timer := 0.0

# apex state
var flying := false
var is_apex := false
var is_frenzied := false
# passives (the Fallen Wizard)
var has_aura := false
var has_blink_on_hit := false
var aura_particles: CPUParticles2D = null
var aura_timer := 0.0
# the aura rides a trailing anchor that chases the boss with a slight delay,
# so blinks and darts leave a smooth red sweep instead of a rigid attachment
var aura_anchor: Node2D = null
var aura_orbit: Node2D = null
var aura_spin := 0.9
# the purple echo: a second layer with double the lag and ~0.7x the pixels
var aura_anchor2: Node2D = null
var aura_orbit2: Node2D = null
var aura_particles2: CPUParticles2D = null
# Mirror Legion state
var is_clone := false        # set by the real wizard before spawning an echo
var clones: Array = []
var health_bar_w := 160.0
# Soul Ward / aura distribution
var has_soul_split := false
var aura_last_n := -1        # last clone count the aura amounts were set for
var shard_red: CPUParticles2D = null     # an echo's little piece of the aura
var shard_purple: CPUParticles2D = null
var hover_time := 0.0
var is_diving := false
var dive_phase := 0
var dive_target := Vector2.ZERO
var dive_timer := 0.0

var minions: Array = []

func _ready() -> void:
	current_def = BOSSES.get(boss_id, BOSSES["gravewarden"])
	configure_from_def(current_def)
	player = get_tree().get_first_node_in_group("player")
	update_health_bar()

func configure_from_def(def: Dictionary) -> void:
	base_move_speed = float(def.get("speed", 62.0))
	flying = bool(def.get("flying", false))
	is_apex = bool(def.get("apex", false))
	var passives: Array = def.get("passives", [])
	has_aura = "crumbling_aura" in passives
	has_blink_on_hit = "blink_on_hit" in passives
	has_soul_split = "soul_split" in passives
	abilities = (def.get("abilities", ["slam"]) as Array).duplicate()
	max_health = int(round(float(def.get("hp", 900)) * level_hp_mult))
	health = max_health

	# echoes are weak fakes: sliver HP, restricted kit, no passives -- but each
	# carries a visible SHARD of his soul (see build_shard_aura), and that is
	# exactly what cracks his Soul Ward while they live
	if is_clone:
		abilities = CLONE_KIT.duplicate()
		max_health = max(1, int(round(max_health * CLONE_HP_FRAC)))
		health = max_health
		has_aura = false
		has_blink_on_hit = false
		has_soul_split = false
		modulate = Color(1.0, 0.85, 1.0, 0.75)

	# stagger initial cooldowns so the boss doesn't dump every ability at once
	for a in abilities:
		ability_cd[a] = randf_range(0.5, 1.7)
	# ...but the Mirror Legion never opens the fight -- long first delay, and
	# allowed_clones() keeps the count at zero while he's near full health
	if ability_cd.has("clone"):
		ability_cd["clone"] = randf_range(7.0, 10.0)

	var body: Vector2 = def.get("body", Vector2(160, 220))
	base_color = def.get("color", Color(0.32, 0.1, 0.38))
	var eye_color: Color = def.get("eye_color", Color(0.95, 0.15, 0.15))
	magic_color = def.get("magic", eye_color)
	# bigger creatures genuinely hit wider: slam/charge/bump/dive/shock/vortex
	# radii all multiply by this (1.0 = the old 160x220 reference body)
	reach_mult = clampf((body.x + body.y) / 380.0, 0.7, 1.6)

	var shape := RectangleShape2D.new()
	shape.size = body
	$CollisionShape2D.shape = shape

	# the old flat placeholder body is replaced by a per-boss creature rig
	$ColorRect.visible = false
	$EyeLeft.visible = false
	$EyeRight.visible = false
	build_rig(def.get("shape", ""), body, eye_color)

	# health bar width follows the body so small bosses don't wear giant bars
	var bar_half := clampf(body.x / 2.0 + 30.0, 40.0, 80.0)
	health_bar_w = bar_half * 2.0
	var bar_y := -body.y / 2.0 - 34.0
	for bar in [$HealthBarBG, $HealthBarFill]:
		bar.offset_left = -bar_half
		bar.offset_right = bar_half
		bar.offset_top = bar_y
		bar.offset_bottom = bar_y + 12.0

	if has_aura:
		build_aura()
	if is_clone:
		build_shard_aura()

# An echo's shard of the master's aura: small red and purple crumbles riding
# the clone. Particles emit in world space, so fast echoes leave faint trails.
func build_shard_aura() -> void:
	shard_red = _make_shard(CLONE_SHARD_RED, Color(0.4, 0.03, 0.02, 0.85), Color(1.0, 0.25, 0.1, 0.9))
	shard_purple = _make_shard(CLONE_SHARD_PURPLE, Color(0.28, 0.05, 0.4, 0.8), Color(0.72, 0.3, 0.95, 0.85))

func _make_shard(count: int, born: Color, flare: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = 1.0
	p.preprocess = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 52.0
	p.gravity = Vector2(0, 80)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([born, flare, Color(0.02, 0.0, 0.02, 0.0)])
	p.color_ramp = ramp
	p.z_index = 3
	add_child(p)
	p.emitting = true
	return p

# The crumbling red pixel aura: a constant rain of small red squares plus an
# orbiting ring of flickering ember blocks. Everything hangs off aura_anchor,
# a top-level node that LAGS behind the boss (see process_passives), so fast
# movement and teleports leave a smooth trailing sweep. Also a weapon.
func build_aura() -> void:
	aura_anchor = Node2D.new()
	aura_anchor.top_level = true          # ignores the boss transform; we steer it
	aura_anchor.z_index = 3
	add_child(aura_anchor)
	aura_anchor.global_position = global_position

	aura_particles = CPUParticles2D.new()
	aura_particles.amount = 46
	aura_particles.lifetime = 1.1
	aura_particles.preprocess = 1.0
	aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura_particles.emission_sphere_radius = AURA_RADIUS * 0.75
	aura_particles.gravity = Vector2(0, 90)          # the pixels crumble downward
	aura_particles.initial_velocity_min = 8.0
	aura_particles.initial_velocity_max = 30.0
	aura_particles.scale_amount_min = 3.0
	aura_particles.scale_amount_max = 7.0
	# each pixel is born deep red, flares bright, and gutters out to black
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([Color(0.4, 0.03, 0.02, 0.9), Color(1.0, 0.25, 0.1, 0.95), Color(0.03, 0.0, 0.0, 0.0)])
	aura_particles.color_ramp = ramp
	aura_anchor.add_child(aura_particles)
	aura_particles.emitting = true

	# the slow-orbiting ember ring around his body
	aura_orbit = Node2D.new()
	aura_anchor.add_child(aura_orbit)
	for i in range(10):
		var ang = i * TAU / 10.0 + randf_range(-0.2, 0.2)
		var r = randf_range(62.0, 95.0)
		_ember_block(Vector2(cos(ang), sin(ang)) * r, randf_range(2.5, 4.5), false, aura_orbit)

	# --- the purple echo: a second shadow of the aura, ~0.7x the pixels,
	# trailing with DOUBLE the delay, tones violet -> lighter -> near-black ---
	aura_anchor2 = Node2D.new()
	aura_anchor2.top_level = true
	aura_anchor2.z_index = 2   # behind the red layer
	add_child(aura_anchor2)
	aura_anchor2.global_position = global_position

	aura_particles2 = CPUParticles2D.new()
	aura_particles2.amount = 32          # ~0.7x the red layer's 46
	aura_particles2.lifetime = 1.1
	aura_particles2.preprocess = 1.0
	aura_particles2.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura_particles2.emission_sphere_radius = AURA_RADIUS * 0.75
	aura_particles2.gravity = Vector2(0, 90)
	aura_particles2.initial_velocity_min = 8.0
	aura_particles2.initial_velocity_max = 30.0
	aura_particles2.scale_amount_min = 3.0
	aura_particles2.scale_amount_max = 7.0
	var ramp2 := Gradient.new()
	ramp2.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp2.colors = PackedColorArray([Color(0.28, 0.05, 0.4, 0.85), Color(0.72, 0.3, 0.95, 0.9), Color(0.02, 0.0, 0.04, 0.0)])
	aura_particles2.color_ramp = ramp2
	aura_anchor2.add_child(aura_particles2)
	aura_particles2.emitting = true

	aura_orbit2 = Node2D.new()
	aura_anchor2.add_child(aura_orbit2)
	for i in range(7):                   # ~0.7x the red ring's 10 blocks
		var ang2 = i * TAU / 7.0 + randf_range(-0.2, 0.2)
		var r2 = randf_range(62.0, 95.0)
		_ember_block(Vector2(cos(ang2), sin(ang2)) * r2, randf_range(2.5, 4.5), false, aura_orbit2, EMBER_TONES_PURPLE)

# Passive effects that run regardless of what the boss is doing.
func process_passives(delta: float) -> void:
	if is_dead or not has_aura:
		return
	# the aura chases the boss with a soft lag -- teleports become red sweeps
	if aura_anchor != null and is_instance_valid(aura_anchor):
		var chase = 1.0 - exp(-7.0 * delta)
		aura_anchor.global_position = aura_anchor.global_position.lerp(global_position, chase)
		if aura_orbit != null and is_instance_valid(aura_orbit):
			aura_orbit.rotation += delta * aura_spin
	# the purple echo trails with double the delay, counter-rotating
	if aura_anchor2 != null and is_instance_valid(aura_anchor2):
		var chase2 = 1.0 - exp(-3.5 * delta)
		aura_anchor2.global_position = aura_anchor2.global_position.lerp(global_position, chase2)
		if aura_orbit2 != null and is_instance_valid(aura_orbit2):
			aura_orbit2.rotation -= delta * aura_spin * 0.8
	# soul distribution: every living echo carries a shard away, thinning HIS
	# aura (amounts only touched when the count changes -- setting amount
	# restarts a particle system)
	if has_soul_split:
		var n = living_clones()
		if n != aura_last_n:
			aura_last_n = n
			var red_total = 84 if is_frenzied else 46
			var pur_total = 59 if is_frenzied else 32
			if aura_particles != null and is_instance_valid(aura_particles):
				aura_particles.amount = max(5, red_total - n * CLONE_SHARD_RED)
			if aura_particles2 != null and is_instance_valid(aura_particles2):
				aura_particles2.amount = max(4, pur_total - n * CLONE_SHARD_PURPLE)
			var ring_fade = clampf(1.0 - 0.12 * n, 0.3, 1.0)
			if aura_orbit != null and is_instance_valid(aura_orbit):
				aura_orbit.modulate.a = ring_fade
			if aura_orbit2 != null and is_instance_valid(aura_orbit2):
				aura_orbit2.modulate.a = ring_fade
	aura_timer -= delta
	if aura_timer <= 0.0:
		aura_timer = AURA_TICK
		if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < AURA_RADIUS:
			# gentler scaling than abilities (sqrt) so the aura punishes
			# lingering without instantly deleting the player at level 100
			if player.has_method("take_damage"):
				player.take_damage(int(round(AURA_DAMAGE * sqrt(damage_multiplier))))

# Blink-on-hit passive: struck mid-fight, he flickers a short step away.
func blink_short() -> void:
	var side = 1 if randf() < 0.5 else -1
	var tx = global_position.x + side * randf_range(160.0, 260.0)
	tx = clampf(tx, 100.0, arena_width() - 100.0)
	spawn_shockwave(60.0, magic_color)
	global_position.x = tx
	spawn_shockwave(60.0, magic_color)

# --- procedural creature rigs ---
# Each boss body is assembled from polygons and lines under a "Rig" node:
# actual undead deepwood monsters instead of colored blocks. Coordinates are
# relative to the collision centre; hw/hh are half the body extents so every
# rig scales with its boss's size. The rig flips horizontally with facing.

const BONE_COL := Color(0.8, 0.77, 0.68)
# The Fallen Wizard's ember palette: his face and aura pixels wander through
# these tones -- deep red, flaring bright, guttering to near-black.
const EMBER_TONES = [Color(0.32, 0.02, 0.02), Color(0.65, 0.08, 0.04), Color(1.0, 0.25, 0.1), Color(0.1, 0.01, 0.01)]
# The purple echo layer's tones: dark violet, lighter, sometimes near-black.
const EMBER_TONES_PURPLE = [Color(0.2, 0.03, 0.28), Color(0.5, 0.12, 0.62), Color(0.8, 0.35, 1.0), Color(0.05, 0.0, 0.08)]

func build_rig(shape: String, body: Vector2, eye: Color) -> void:
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)
	var hw := body.x / 2.0
	var hh := body.y / 2.0
	match shape:
		"brute": rig_gravewarden(hw, hh, eye)
		"crown": rig_frost(hw, hh, eye)
		"colossus": rig_cinder(hw, hh, eye)
		"spider": rig_weaver(hw, hh, eye)
		"caster": rig_stormcaller(hw, hh, eye)
		"void": rig_void(hw, hh, eye)
		"angel": rig_seraph(hw, hh, eye)
		"serpent": rig_leviathan(hw, hh, eye)
		"titan": rig_eclipse(hw, hh, eye)
		"wizard": rig_wizard(hw, hh, eye)
		_: rig_gravewarden(hw, hh, eye)

func _rp(points: PackedVector2Array, color: Color, z: int = 0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.z_index = z
	rig.add_child(p)
	return p

func _rc(pos: Vector2, r: float, color: Color, z: int = 0, _segs: int = 14) -> Polygon2D:
	# squarish pixel-art style: every "round" part is drawn as a block
	var pts := PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	var p := _rp(pts, color, z)
	p.position = pos
	return p

func _rl(points: PackedVector2Array, width: float, color: Color, z: int = 0) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.width = width
	l.default_color = color
	l.z_index = z
	rig.add_child(l)
	return l

# A skull face: pale cranium, hollow sockets, glowing pupils, jaw fangs.
func _rskull(pos: Vector2, r: float, eye: Color) -> void:
	_rc(pos, r, BONE_COL, 2)
	for sx in [-0.42, 0.42]:
		_rc(pos + Vector2(r * sx, -r * 0.12), r * 0.3, Color(0.05, 0.05, 0.07), 3)
		_rc(pos + Vector2(r * sx, -r * 0.12), r * 0.15, eye, 4)
	_rp(PackedVector2Array([pos + Vector2(-r * 0.5, r * 0.55), pos + Vector2(-r * 0.25, r * 1.05), pos + Vector2(0, r * 0.55)]), BONE_COL, 2)
	_rp(PackedVector2Array([pos + Vector2(r * 0.5, r * 0.55), pos + Vector2(r * 0.25, r * 1.05), pos + Vector2(0, r * 0.55)]), BONE_COL, 2)

# Gravewarden -- a grave-troll of root and soil, a tombstone sunk in its chest.
func rig_gravewarden(hw: float, hh: float, eye: Color) -> void:
	var dark := base_color.darkened(0.25)
	_rp(PackedVector2Array([Vector2(-hw * 0.7, hh), Vector2(-hw * 0.25, hh), Vector2(-hw * 0.35, hh * 0.2), Vector2(-hw * 0.65, hh * 0.25)]), dark)
	_rp(PackedVector2Array([Vector2(hw * 0.7, hh), Vector2(hw * 0.25, hh), Vector2(hw * 0.35, hh * 0.2), Vector2(hw * 0.65, hh * 0.25)]), dark)
	_rp(PackedVector2Array([Vector2(-hw, -hh * 0.45), Vector2(-hw * 0.75, hh * 0.45), Vector2(hw * 0.75, hh * 0.45), Vector2(hw, -hh * 0.45), Vector2(hw * 0.6, -hh * 0.8), Vector2(-hw * 0.6, -hh * 0.8)]), base_color, 1)
	_rp(PackedVector2Array([Vector2(-hw, -hh * 0.4), Vector2(-hw - 26.0, hh * 0.5), Vector2(-hw + 14.0, hh * 0.2)]), dark, 1)
	_rp(PackedVector2Array([Vector2(hw, -hh * 0.4), Vector2(hw + 26.0, hh * 0.5), Vector2(hw - 14.0, hh * 0.2)]), dark, 1)
	_rp(PackedVector2Array([Vector2(-hw * 0.28, hh * 0.15), Vector2(-hw * 0.28, -hh * 0.35), Vector2(-hw * 0.14, -hh * 0.5), Vector2(hw * 0.14, -hh * 0.5), Vector2(hw * 0.28, -hh * 0.35), Vector2(hw * 0.28, hh * 0.15)]), Color(0.45, 0.45, 0.48), 2)
	_rl(PackedVector2Array([Vector2(0, -hh * 0.42), Vector2(-hw * 0.06, -hh * 0.2), Vector2(hw * 0.05, -hh * 0.05)]), 2.0, Color(0.25, 0.25, 0.28), 3)
	_rc(Vector2(-hw * 0.55, -hh * 0.6), hw * 0.12, magic_color.darkened(0.35), 2)
	_rc(Vector2(hw * 0.5, hh * 0.1), hw * 0.1, magic_color.darkened(0.4), 2)
	_rp(PackedVector2Array([Vector2(-hw * 0.45, -hh * 0.75), Vector2(hw * 0.45, -hh * 0.75), Vector2(hw * 0.35, -hh - 14.0), Vector2(-hw * 0.35, -hh - 10.0)]), dark, 2)
	for sx in [-0.2, 0.18]:
		_rc(Vector2(hw * sx, -hh * 0.86), 6.5, Color(0.04, 0.05, 0.03), 3)
		_rc(Vector2(hw * sx, -hh * 0.86), 3.2, eye, 4)
	_rl(PackedVector2Array([Vector2(hw * 0.3, -hh - 8.0), Vector2(hw * 0.55, -hh - 34.0), Vector2(hw * 0.45, -hh - 52.0)]), 4.0, dark, 2)

# Frost Monarch -- a tall skeletal lich-king in an icy shroud.
func rig_frost(hw: float, hh: float, eye: Color) -> void:
	var shroud := base_color.darkened(0.15)
	_rp(PackedVector2Array([Vector2(-hw, hh), Vector2(-hw * 0.55, hh * 0.75), Vector2(-hw * 0.15, hh), Vector2(hw * 0.3, hh * 0.78), Vector2(hw * 0.7, hh), Vector2(hw, hh * 0.9), Vector2(hw * 0.6, -hh * 0.55), Vector2(-hw * 0.6, -hh * 0.55)]), shroud, 1)
	_rp(PackedVector2Array([Vector2(-hw, -hh * 0.5), Vector2(-hw * 0.4, -hh * 0.68), Vector2(-hw * 0.55, -hh * 0.3)]), Color(0.75, 0.85, 0.92), 2)
	_rp(PackedVector2Array([Vector2(hw, -hh * 0.5), Vector2(hw * 0.4, -hh * 0.68), Vector2(hw * 0.55, -hh * 0.3)]), Color(0.75, 0.85, 0.92), 2)
	_rc(Vector2(0, -hh * 0.15), hw * 0.3, Color(0.06, 0.08, 0.12), 2)
	_rc(Vector2(0, -hh * 0.15), hw * 0.14, magic_color, 3)
	_rskull(Vector2(0, -hh * 0.78), hw * 0.34, eye)
	for k in [-0.55, -0.2, 0.15, 0.5]:
		_rp(PackedVector2Array([Vector2(hw * k - 5.0, -hh * 0.92), Vector2(hw * k + 5.0, -hh * 0.92), Vector2(hw * k, -hh - 30.0)]), Color(0.8, 0.92, 1.0), 3)

# Cinder Colossus -- a charred stag-demon, antlers still burning.
func rig_cinder(hw: float, hh: float, eye: Color) -> void:
	var char_dark := base_color.darkened(0.3)
	for lx in [-0.75, -0.35, 0.3, 0.68]:
		_rp(PackedVector2Array([Vector2(hw * lx - 9.0, hh * 0.1), Vector2(hw * lx + 9.0, hh * 0.1), Vector2(hw * lx + 6.0, hh), Vector2(hw * lx - 6.0, hh)]), char_dark, 1)
	_rp(PackedVector2Array([Vector2(-hw, hh * 0.25), Vector2(-hw * 0.85, -hh * 0.35), Vector2(hw * 0.55, -hh * 0.45), Vector2(hw * 0.9, -hh * 0.1), Vector2(hw * 0.8, hh * 0.25)]), base_color, 2)
	for cx in [-0.5, -0.1, 0.35]:
		_rl(PackedVector2Array([Vector2(hw * cx, -hh * 0.3), Vector2(hw * cx + 12.0, hh * 0.05)]), 3.0, magic_color, 3)
	_rp(PackedVector2Array([Vector2(hw * 0.55, -hh * 0.45), Vector2(hw * 0.95, -hh * 0.75), Vector2(hw, -hh * 0.45)]), base_color, 2)
	_rp(PackedVector2Array([Vector2(hw * 0.8, -hh * 0.78), Vector2(hw + 22.0, -hh * 0.72), Vector2(hw + 18.0, -hh * 0.5), Vector2(hw * 0.85, -hh * 0.5)]), char_dark, 3)
	_rc(Vector2(hw * 0.95, -hh * 0.66), 4.5, eye, 4)
	_rl(PackedVector2Array([Vector2(hw * 0.85, -hh * 0.8), Vector2(hw * 0.75, -hh - 30.0), Vector2(hw * 0.6, -hh - 48.0)]), 4.0, char_dark, 3)
	_rl(PackedVector2Array([Vector2(hw * 0.78, -hh - 16.0), Vector2(hw * 0.95, -hh - 36.0)]), 3.0, char_dark, 3)
	_rl(PackedVector2Array([Vector2(hw * 0.9, -hh * 0.8), Vector2(hw + 10.0, -hh - 24.0), Vector2(hw + 26.0, -hh - 38.0)]), 4.0, char_dark, 3)
	for tip in [Vector2(hw * 0.6, -hh - 48.0), Vector2(hw * 0.95, -hh - 36.0), Vector2(hw + 26.0, -hh - 38.0)]:
		_rc(tip, 5.0, magic_color, 4)

# Weaver -- a small corpse-spider brood mother; legs span wider than her body.
func rig_weaver(hw: float, hh: float, eye: Color) -> void:
	var dark := base_color.darkened(0.3)
	for i in range(4):
		var ay := -hh * 0.3 + i * (hh * 0.32)
		var span := hw + 52.0 + i * 8.0
		_rl(PackedVector2Array([Vector2(-hw * 0.5, ay), Vector2(-(hw + span) / 2.0, ay - 26.0), Vector2(-span, ay + 10.0)]), 4.0, dark, 1)
		_rl(PackedVector2Array([Vector2(hw * 0.5, ay), Vector2((hw + span) / 2.0, ay - 26.0), Vector2(span, ay + 10.0)]), 4.0, dark, 1)
	_rc(Vector2(-hw * 0.35, -hh * 0.05), hw * 0.62, base_color, 2, 16)
	_rc(Vector2(-hw * 0.35, -hh * 0.15), hw * 0.2, BONE_COL, 3)
	for sx in [-0.45, -0.25]:
		_rc(Vector2(hw * sx, -hh * 0.12), hw * 0.055, Color(0.05, 0.05, 0.07), 4)
	_rc(Vector2(hw * 0.42, -hh * 0.1), hw * 0.38, base_color.lightened(0.08), 2, 12)
	for e in [Vector2(hw * 0.3, -hh * 0.28), Vector2(hw * 0.5, -hh * 0.3), Vector2(hw * 0.38, -hh * 0.16), Vector2(hw * 0.56, -hh * 0.18)]:
		_rc(e, 3.4, eye, 4)
	_rp(PackedVector2Array([Vector2(hw * 0.42, hh * 0.08), Vector2(hw * 0.5, hh * 0.38), Vector2(hw * 0.58, hh * 0.08)]), BONE_COL, 3)
	_rp(PackedVector2Array([Vector2(hw * 0.6, hh * 0.06), Vector2(hw * 0.68, hh * 0.32), Vector2(hw * 0.74, hh * 0.04)]), BONE_COL, 3)

# Stormcaller -- a lightning-scarred owl-wraith of the dead canopy.
func rig_stormcaller(hw: float, hh: float, eye: Color) -> void:
	var dark := base_color.darkened(0.25)
	for tx in [-0.3, 0.25]:
		_rl(PackedVector2Array([Vector2(hw * tx, hh * 0.85), Vector2(hw * tx, hh)]), 3.5, Color(0.3, 0.26, 0.2), 1)
	_rp(PackedVector2Array([Vector2(-hw * 0.62, hh * 0.85), Vector2(hw * 0.62, hh * 0.85), Vector2(hw * 0.75, -hh * 0.25), Vector2(0, -hh * 0.45), Vector2(-hw * 0.75, -hh * 0.25)]), base_color, 2)
	_rp(PackedVector2Array([Vector2(-hw * 0.75, -hh * 0.2), Vector2(-hw, hh * 0.5), Vector2(-hw * 0.55, hh * 0.75)]), dark, 2)
	_rp(PackedVector2Array([Vector2(hw * 0.75, -hh * 0.2), Vector2(hw, hh * 0.5), Vector2(hw * 0.55, hh * 0.75)]), dark, 2)
	_rl(PackedVector2Array([Vector2(-hw * 0.15, hh * 0.05), Vector2(hw * 0.05, hh * 0.25), Vector2(-hw * 0.08, hh * 0.42), Vector2(hw * 0.1, hh * 0.6)]), 3.0, magic_color, 3)
	_rc(Vector2(0, -hh * 0.62), hw * 0.52, base_color.lightened(0.05), 3, 16)
	for sx in [-0.26, 0.26]:
		_rc(Vector2(hw * sx, -hh * 0.66), hw * 0.19, Color(0.05, 0.05, 0.04), 4)
		_rc(Vector2(hw * sx, -hh * 0.66), hw * 0.1, eye, 5)
	_rp(PackedVector2Array([Vector2(-hw * 0.06, -hh * 0.52), Vector2(hw * 0.06, -hh * 0.52), Vector2(0, -hh * 0.36)]), Color(0.85, 0.75, 0.4), 5)
	_rp(PackedVector2Array([Vector2(-hw * 0.45, -hh * 0.95), Vector2(-hw * 0.2, -hh * 0.8), Vector2(-hw * 0.5, -hh * 0.72)]), dark, 3)
	_rp(PackedVector2Array([Vector2(hw * 0.45, -hh * 0.95), Vector2(hw * 0.2, -hh * 0.8), Vector2(hw * 0.5, -hh * 0.72)]), dark, 3)

# Void Sovereign -- the hollow king: an open void where his chest was.
func rig_void(hw: float, hh: float, eye: Color) -> void:
	var robe := base_color
	_rp(PackedVector2Array([Vector2(-hw, hh), Vector2(-hw * 0.6, hh * 0.82), Vector2(-hw * 0.2, hh), Vector2(hw * 0.25, hh * 0.85), Vector2(hw * 0.65, hh), Vector2(hw, hh * 0.88), Vector2(hw * 0.7, -hh * 0.5), Vector2(-hw * 0.7, -hh * 0.5)]), robe, 1)
	_rp(PackedVector2Array([Vector2(-hw * 0.7, -hh * 0.45), Vector2(-hw - 18.0, -hh * 0.6), Vector2(-hw * 0.45, -hh * 0.62)]), robe.darkened(0.2), 2)
	_rp(PackedVector2Array([Vector2(hw * 0.7, -hh * 0.45), Vector2(hw + 18.0, -hh * 0.6), Vector2(hw * 0.45, -hh * 0.62)]), robe.darkened(0.2), 2)
	_rc(Vector2(0, -hh * 0.05), hw * 0.4, Color(0.02, 0.01, 0.04), 2, 18)
	_rl(PackedVector2Array([Vector2(-hw * 0.4, -hh * 0.05), Vector2(-hw * 0.28, -hh * 0.33), Vector2(0, -hh * 0.45), Vector2(hw * 0.28, -hh * 0.33), Vector2(hw * 0.4, -hh * 0.05), Vector2(hw * 0.28, hh * 0.23), Vector2(0, hh * 0.35), Vector2(-hw * 0.28, hh * 0.23), Vector2(-hw * 0.4, -hh * 0.05)]), 3.0, magic_color, 3)
	_rc(Vector2(0, -hh * 0.05), hw * 0.07, magic_color, 3)
	_rskull(Vector2(0, -hh * 0.78), hw * 0.26, eye)
	for k in [-0.3, 0.0, 0.3]:
		_rp(PackedVector2Array([Vector2(hw * k - 8.0, -hh - 22.0), Vector2(hw * k + 8.0, -hh - 22.0), Vector2(hw * k, -hh - 46.0)]), Color(0.5, 0.4, 0.18), 3)
	_rl(PackedVector2Array([Vector2(-hw * 0.32, -hh - 22.0), Vector2(hw * 0.32, -hh - 22.0)]), 4.0, Color(0.5, 0.4, 0.18), 3)

# Seraphiel -- a fallen angel of bone: skeletal wings, tarnished halo.
func rig_seraph(hw: float, hh: float, eye: Color) -> void:
	var robe := base_color
	for side in [-1.0, 1.0]:
		for w in [[0.15, -50.0, 130.0], [0.0, -20.0, 150.0], [-0.12, 14.0, 140.0]]:
			_rl(PackedVector2Array([Vector2(side * hw * 0.6, -hh * 0.35), Vector2(side * (hw + w[2] * 0.55), -hh * w[0] * 2.0 + w[1] * 0.5), Vector2(side * (hw + w[2]), w[1])]), 4.0, BONE_COL, 1)
		_rp(PackedVector2Array([Vector2(side * hw * 0.6, -hh * 0.3), Vector2(side * (hw + 120.0), -36.0), Vector2(side * (hw + 80.0), hh * 0.25), Vector2(side * hw * 0.62, hh * 0.05)]), Color(base_color.r, base_color.g, base_color.b, 0.35), 0)
	_rp(PackedVector2Array([Vector2(-hw * 0.6, hh), Vector2(-hw * 0.25, hh * 0.8), Vector2(hw * 0.1, hh), Vector2(hw * 0.45, hh * 0.82), Vector2(hw * 0.6, hh), Vector2(hw * 0.5, -hh * 0.5), Vector2(-hw * 0.5, -hh * 0.5)]), robe, 2)
	_rc(Vector2(0, -hh * 0.1), hw * 0.13, magic_color, 3)
	_rskull(Vector2(0, -hh * 0.72), hw * 0.3, eye)
	_rl(PackedVector2Array([Vector2(-hw * 0.42, -hh - 26.0), Vector2(-hw * 0.15, -hh - 38.0), Vector2(hw * 0.15, -hh - 38.0), Vector2(hw * 0.42, -hh - 26.0), Vector2(hw * 0.15, -hh - 14.0), Vector2(-hw * 0.15, -hh - 14.0), Vector2(-hw * 0.42, -hh - 26.0)]), 3.5, magic_color, 3)

# Leviathan -- a long skeletal abyss-wyrm with fin membranes.
func rig_leviathan(hw: float, hh: float, eye: Color) -> void:
	var belly := base_color.lightened(0.12)
	var segs := 5
	for i in range(segs):
		var t := float(i) / float(segs - 1)
		var sx := lerpf(-hw * 0.85, hw * 0.45, t)
		var r := lerpf(hh * 0.45, hh * 0.95, t)
		_rc(Vector2(sx, 0), r, base_color, 1 + i, 16)
		_rl(PackedVector2Array([Vector2(sx - r * 0.5, -r * 0.55), Vector2(sx, -r * 0.85), Vector2(sx + r * 0.5, -r * 0.55)]), 3.0, BONE_COL, 6)
		if i % 2 == 0:
			_rp(PackedVector2Array([Vector2(sx - 12.0, -r * 0.8), Vector2(sx + 12.0, -r * 0.8), Vector2(sx, -r * 0.8 - 34.0)]), Color(magic_color.r, magic_color.g, magic_color.b, 0.5), 6)
	_rp(PackedVector2Array([Vector2(-hw * 0.85, 0), Vector2(-hw - 44.0, -hh * 0.6), Vector2(-hw - 44.0, hh * 0.6)]), Color(magic_color.r, magic_color.g, magic_color.b, 0.55), 1)
	_rp(PackedVector2Array([Vector2(hw * 0.45, -hh * 0.75), Vector2(hw + 12.0, -hh * 0.4), Vector2(hw + 16.0, hh * 0.2), Vector2(hw * 0.6, hh * 0.7)]), base_color.darkened(0.15), 7)
	_rp(PackedVector2Array([Vector2(hw * 0.7, hh * 0.15), Vector2(hw + 10.0, hh * 0.4), Vector2(hw * 0.65, hh * 0.65)]), belly, 8)
	for tx in [0.78, 0.92]:
		_rp(PackedVector2Array([Vector2(hw * tx - 5.0, hh * 0.3), Vector2(hw * tx + 5.0, hh * 0.3), Vector2(hw * tx, hh * 0.55)]), BONE_COL, 9)
	_rc(Vector2(hw * 0.82, -hh * 0.25), 7.0, Color(0.04, 0.05, 0.06), 9)
	_rc(Vector2(hw * 0.82, -hh * 0.25), 3.6, eye, 10)

# Eclipse Titan -- a dead god crowned by a black sun.
func rig_eclipse(hw: float, hh: float, eye: Color) -> void:
	var stone := base_color
	var crack := magic_color
	for lx in [-0.45, 0.45]:
		_rp(PackedVector2Array([Vector2(hw * lx - hw * 0.2, hh * 0.3), Vector2(hw * lx + hw * 0.2, hh * 0.3), Vector2(hw * lx + hw * 0.16, hh), Vector2(hw * lx - hw * 0.16, hh)]), stone.darkened(0.15), 1)
	_rp(PackedVector2Array([Vector2(-hw * 0.8, hh * 0.35), Vector2(hw * 0.8, hh * 0.35), Vector2(hw * 0.95, -hh * 0.45), Vector2(-hw * 0.95, -hh * 0.45)]), stone, 2)
	_rp(PackedVector2Array([Vector2(-hw, -hh * 0.5), Vector2(-hw * 0.55, -hh * 0.62), Vector2(-hw * 0.5, -hh * 0.35), Vector2(-hw * 0.95, -hh * 0.25)]), stone.darkened(0.1), 3)
	_rp(PackedVector2Array([Vector2(hw, -hh * 0.5), Vector2(hw * 0.55, -hh * 0.62), Vector2(hw * 0.5, -hh * 0.35), Vector2(hw * 0.95, -hh * 0.25)]), stone.darkened(0.1), 3)
	_rp(PackedVector2Array([Vector2(-hw, -hh * 0.45), Vector2(-hw - 26.0, hh * 0.2), Vector2(-hw * 0.7, hh * 0.1)]), stone.darkened(0.2), 2)
	_rp(PackedVector2Array([Vector2(hw, -hh * 0.45), Vector2(hw + 26.0, hh * 0.2), Vector2(hw * 0.7, hh * 0.1)]), stone.darkened(0.2), 2)
	_rl(PackedVector2Array([Vector2(-hw * 0.2, hh * 0.3), Vector2(-hw * 0.05, -hh * 0.05), Vector2(-hw * 0.22, -hh * 0.3)]), 4.0, crack, 4)
	_rl(PackedVector2Array([Vector2(hw * 0.3, hh * 0.32), Vector2(hw * 0.18, 0.0)]), 3.0, crack, 4)
	_rc(Vector2(0, -hh * 0.1), hw * 0.1, crack, 4)
	var head_y := -hh * 0.72
	for i in range(10):
		var ang := i * TAU / 10.0
		var dir := Vector2(cos(ang), sin(ang))
		_rp(PackedVector2Array([Vector2(0, head_y) + dir * hw * 0.3, Vector2(0, head_y) + dir.rotated(0.18) * hw * 0.52, Vector2(0, head_y) + dir.rotated(-0.18) * hw * 0.52]), crack.darkened(0.15), 4)
	_rc(Vector2(0, head_y), hw * 0.3, Color(0.02, 0.015, 0.02), 5, 18)
	for sx in [-0.1, 0.1]:
		_rc(Vector2(hw * sx, head_y), 5.0, eye, 6)

# The Fallen Wizard -- an undead archmage barely taller than the adventurer;
# power, not bulk. All geometry is proportional so it reads at small size.
func rig_wizard(hw: float, hh: float, eye: Color) -> void:
	var robe := base_color
	_rp(PackedVector2Array([Vector2(-hw * 0.9, hh), Vector2(-hw * 0.5, hh * 0.8), Vector2(-hw * 0.1, hh), Vector2(hw * 0.35, hh * 0.82), Vector2(hw * 0.8, hh), Vector2(hw * 0.7, -hh * 0.35), Vector2(-hw * 0.7, -hh * 0.35)]), robe, 1)
	_rl(PackedVector2Array([Vector2(-hw * 0.55, hh * 0.05), Vector2(hw * 0.55, hh * 0.05)]), 2.0, Color(0.45, 0.38, 0.2), 2)
	_rp(PackedVector2Array([Vector2(-hw * 0.55, -hh * 0.28), Vector2(hw * 0.55, -hh * 0.28), Vector2(hw * 0.4, -hh * 0.72), Vector2(-hw * 0.4, -hh * 0.72)]), robe.darkened(0.25), 2)
	# no face at all -- a hollow of shifting red ember-pixels under the hood
	_wizard_void_face(Vector2(0, -hh * 0.5), hw * 0.5)
	# crooked hat
	_rp(PackedVector2Array([Vector2(-hw * 0.95, -hh * 0.62), Vector2(hw * 0.95, -hh * 0.68), Vector2(hw * 0.25, -hh * 0.82)]), robe.darkened(0.35), 3)
	_rp(PackedVector2Array([Vector2(-hw * 0.45, -hh * 0.72), Vector2(hw * 0.48, -hh * 0.76), Vector2(hw * 0.06, -hh * 1.9)]), robe.darkened(0.35), 3)
	# blood-red hat band and torn red hem
	_rl(PackedVector2Array([Vector2(-hw * 0.8, -hh * 0.64), Vector2(hw * 0.8, -hh * 0.7)]), 2.5, magic_color, 4)
	for hx in [-0.6, -0.15, 0.3, 0.65]:
		_rp(PackedVector2Array([Vector2(hw * hx - hw * 0.12, hh * 0.92), Vector2(hw * hx + hw * 0.12, hh * 0.92), Vector2(hw * hx, hh * 1.3)]), magic_color.darkened(0.25), 2)
	# levitating staff with a burning witchlight
	_rl(PackedVector2Array([Vector2(hw * 1.5, hh * 0.6), Vector2(hw * 1.7, -hh * 0.9)]), 2.5, Color(0.28, 0.2, 0.12), 1)
	_rc(Vector2(hw * 1.72, -hh * 1.0), hw * 0.35, magic_color, 2)
	# clawed shadow of a hand -- nothing human left
	_rc(Vector2(-hw * 0.55, hh * 0.02), hw * 0.2, Color(0.12, 0.03, 0.03), 2)

# The Fallen Wizard's face: a black hollow with two burning eye-blocks. All
# other embers live on the trailing aura ring so nothing is stuck to the face.
func _wizard_void_face(center: Vector2, r: float) -> void:
	_rc(center, r, Color(0.03, 0.01, 0.02), 3)
	for sx in [-0.45, 0.45]:
		_ember_block(center + Vector2(r * sx, -r * 0.15), r * 0.3, true, rig)

# A flickering ember pixel: cycles through its palette's tones (dark -> flare
# -> gutter to near-black) on its own rhythm.
func _ember_block(pos: Vector2, half: float, bright: bool, parent: Node2D, palette: Array = EMBER_TONES) -> void:
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	b.position = pos
	b.color = palette[0]
	b.z_index = 4
	parent.add_child(b)
	var t := b.create_tween()
	t.set_loops()
	var tones := palette.duplicate()
	tones.shuffle()
	for tone in tones:
		var c: Color = tone
		if bright:
			c = c.lightened(0.25)
		t.tween_property(b, "color", c, randf_range(0.18, 0.5))

func get_display_name() -> String:
	return current_def.get("name", "Boss")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# flying bosses ignore gravity entirely; they steer in full 2D
	if not flying and not is_on_floor():
		velocity.y += GRAVITY * delta

	for a in ability_cd.keys():
		if ability_cd[a] > 0.0:
			ability_cd[a] -= delta
	if wall_turn_timer > 0:
		wall_turn_timer -= delta
		if wall_turn_timer <= 0:
			is_wall_blocked = false
	if exposed_timer > 0.0:
		exposed_timer -= delta
	if hex_timer > 0.0:
		hex_timer -= delta
	if stun_timer > 0.0:
		stun_timer -= delta

	if player != null and is_instance_valid(player):
		if is_charging:
			process_charge(delta)
		elif is_diving:
			process_dive(delta)
		elif stun_timer > 0.0:
			# staggered by a sword-counter: rooted and unable to start attacks
			velocity = Vector2.ZERO if flying else Vector2(0, velocity.y)
		elif not is_busy:
			var dx = player.global_position.x - global_position.x
			if absf(dx) > 4.0:
				facing_direction = sign(dx)
			var dist = global_position.distance_to(player.global_position)
			var chosen = choose_attack(dist)
			if chosen != "":
				start_attack(chosen)
			elif flying:
				process_hover(delta)
			elif wall_turn_timer > 0:
				velocity.x = -facing_direction * effective_speed()
			else:
				velocity.x = facing_direction * effective_speed()
		check_bump()

	# creature rigs face the way the boss moves/aims
	if rig != null:
		rig.scale.x = facing_direction

	move_and_slide()

	# hard containment: no boss ever ends a frame outside the arena walls
	var bw = arena_width()
	global_position.x = clampf(global_position.x, 70.0, bw - 70.0)

	process_passives(delta)

	if not flying and not is_wall_blocked and not is_charging:
		for i in range(get_slide_collision_count()):
			if absf(get_slide_collision(i).get_normal().x) > 0.5:
				is_wall_blocked = true
				wall_turn_timer = WALL_TURN_DURATION
				break

# Cruise toward a point hovering above the player, with a slow wing-beat bob.
func process_hover(delta: float) -> void:
	hover_time += delta
	var target = player.global_position + Vector2(0, -HOVER_ALTITUDE)
	var to_target = target - global_position
	if to_target.length() > 40.0:
		velocity = to_target.normalized() * effective_speed()
	else:
		velocity = to_target * 2.0
	velocity.y += sin(hover_time * 3.0) * 28.0

func arena_width() -> float:
	var s = get_tree().current_scene
	if s != null and "current_width" in s:
		return s.current_width
	return 15000.0

# Movement speed after the mage-counter's hex slow (and level scaling).
func effective_speed() -> float:
	var s = base_move_speed * speed_multiplier
	if hex_timer > 0.0:
		s *= HEX_SPEED_MULT
	return s

func choose_attack(dist: float) -> String:
	var candidates: Array = []
	for a in abilities:
		var meta = ABILITY_META.get(a, null)
		if meta == null:
			continue
		if ability_cd.get(a, 0.0) > 0.0:
			continue
		if dist < meta["min"] or dist > meta["max"]:
			continue
		# cloning is only on the menu when his health deficit permits more
		if a == "clone" and living_clones() >= allowed_clones():
			continue
		candidates.append(a)
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]

func start_attack(attack_name: String) -> void:
	is_busy = true
	velocity.x = 0
	match attack_name:
		"slam": do_slam()
		"charge": do_charge()
		"barrage": do_barrage()
		"rain": do_rain()
		"nova": do_nova()
		"teleport": do_teleport()
		"summon": do_summon()
		"pillars": do_pillars()
		"dive": do_dive()
		"volley": do_volley()
		"meteors": do_meteors()
		"vortex": do_vortex()
		"beam": do_beam()
		"curse": do_curse()
		"doomring": do_doomring()
		"clone": do_clone()
		_:
			is_busy = false

func set_cd(ability_name: String) -> void:
	ability_cd[ability_name] = ABILITY_META[ability_name]["cd"] * cooldown_mult()

func cooldown_mult() -> float:
	var m := 1.0
	if is_frenzied:
		m = 0.35
	elif is_enraged:
		m = 0.5 if is_apex else 0.6
	if hex_timer > 0.0:
		m *= HEX_CD_PENALTY   # mage-counter: hexed bosses attack slower
	if is_clone:
		m *= CLONE_CD_PENALTY # echoes cast noticeably slower than the original
	return m

# Maps the player's currently-held weapon to one of the three counter roles.
# Read live when the boss is hit, so it reflects whatever dealt the blow.
func current_player_role() -> String:
	if player != null and is_instance_valid(player) and "active_weapon_type" in player:
		match player.active_weapon_type:
			"bow": return "archer"
			"wand": return "mage"
			_: return "sword"   # "melee", "spear", or unset
	return "sword"

# The distinct mechanical edge each countering weapon gets. Called only on a
# hit from this boss's countering weapon.
func trigger_counter_mechanic(role: String) -> void:
	match role:
		"sword":
			# build stagger; a full bar roots the boss briefly (an opening)
			stagger += 1
			if stagger >= STAGGER_MAX and stun_timer <= 0.0:
				stagger = 0
				stun_timer = STUN_DURATION
				spawn_shockwave(150.0, Color(1.0, 0.95, 0.55))
		"archer":
			# strip the guard for a few seconds -- everyone hits full during it
			exposed_timer = EXPOSE_DURATION
		"mage":
			# hex: slows movement and lengthens cooldowns
			hex_timer = HEX_DURATION

# --- abilities ---

func do_slam() -> void:
	var radius = SLAM_RADIUS * reach_mult   # big creatures slam wider
	flash_telegraph(Color(1.0, 0.9, 0.2))
	spawn_ring_telegraph(global_position, radius, Color(1.0, 0.85, 0.2), SLAM_TELEGRAPH)
	await get_tree().create_timer(SLAM_TELEGRAPH).timeout
	if is_dead:
		return
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < radius:
		deal_player_damage(SLAM_DAMAGE)
		knockback_player_away(SLAM_KNOCKBACK)
	shake_camera(10.0, 0.35)
	spawn_shockwave(radius, magic_color)
	set_cd("slam")
	is_busy = false

func do_charge() -> void:
	flash_telegraph(Color(1.0, 0.3, 0.2))
	await get_tree().create_timer(CHARGE_TELEGRAPH).timeout
	if is_dead:
		return
	charge_direction = facing_direction
	# a flying boss locks a full 2D line onto the player and sweeps along it
	if flying and player != null and is_instance_valid(player):
		charge_dir_2d = (player.global_position - global_position).normalized()
	is_charging = true
	charge_timer = CHARGE_DURATION
	charge_has_hit = false

func process_charge(delta: float) -> void:
	if flying:
		velocity = charge_dir_2d * CHARGE_SPEED * speed_multiplier
	else:
		velocity.x = charge_direction * CHARGE_SPEED * speed_multiplier
	charge_timer -= delta
	if not charge_has_hit and player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < CHARGE_HIT_RADIUS * reach_mult:
		charge_has_hit = true
		deal_player_damage(CHARGE_DAMAGE)
		if player.has_method("apply_knockback"):
			player.apply_knockback(charge_direction, CHARGE_KNOCKBACK)
		shake_camera(9.0, 0.3)
	var hit_wall = false
	for i in range(get_slide_collision_count()):
		# an aerial sweep ends on ANY surface; a ground charge only on walls
		if flying or absf(get_slide_collision(i).get_normal().x) > 0.5:
			hit_wall = true
			break
	if charge_timer <= 0 or hit_wall:
		is_charging = false
		velocity = Vector2.ZERO if flying else Vector2(0, velocity.y)
		set_cd("charge")
		is_busy = false

func do_barrage() -> void:
	flash_telegraph(Color(1.0, 0.6, 0.1))
	await get_tree().create_timer(BARRAGE_TELEGRAPH).timeout
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("barrage")
		return
	var base_angle = (player.global_position - global_position).angle()
	var half = BARRAGE_COUNT / 2
	for i in range(BARRAGE_COUNT):
		var angle = base_angle + deg_to_rad(BARRAGE_SPREAD_DEG) * (i - half)
		var dir = Vector2.RIGHT.rotated(angle)
		spawn_arrow(global_position + dir * 44.0, dir, BARRAGE_DAMAGE, BARRAGE_RANGE)
	set_cd("barrage")
	is_busy = false

func do_nova() -> void:
	flash_telegraph(Color(0.7, 0.9, 1.0))
	await get_tree().create_timer(NOVA_TELEGRAPH).timeout
	if is_dead:
		return
	var jitter = randf() * TAU
	for i in range(NOVA_COUNT):
		var angle = jitter + i * TAU / NOVA_COUNT
		var dir = Vector2.RIGHT.rotated(angle)
		spawn_arrow(global_position + dir * 40.0, dir, NOVA_DAMAGE, NOVA_RANGE)
	shake_camera(5.0, 0.2)
	set_cd("nova")
	is_busy = false

func do_rain() -> void:
	flash_telegraph(Color(0.6, 0.8, 1.0))
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("rain")
		return
	var center_x = player.global_position.x
	var ground_y = player.global_position.y
	var xs: Array = []
	for i in range(RAIN_COUNT):
		xs.append(center_x + randf_range(-RAIN_HALF_SPREAD, RAIN_HALF_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), magic_color, RAIN_TELEGRAPH)
	await get_tree().create_timer(RAIN_TELEGRAPH).timeout
	if is_dead:
		return
	for x in xs:
		var spawn_pos = Vector2(x, ground_y - RAIN_HEIGHT)
		spawn_arrow(spawn_pos, Vector2.DOWN, RAIN_DAMAGE, RAIN_HEIGHT + 120.0)
		await get_tree().create_timer(0.05).timeout
		if is_dead:
			return
	set_cd("rain")
	is_busy = false

func do_teleport() -> void:
	# blink out, reappear on a random side of the player, then a close shock.
	var tween = create_tween()
	if rig != null:
		tween.tween_property(rig, "modulate:a", 0.15, TELEPORT_TELEGRAPH)
	else:
		tween.tween_interval(TELEPORT_TELEGRAPH)
	await tween.finished
	if is_dead:
		return
	if player != null and is_instance_valid(player):
		var side = 1 if randf() < 0.5 else -1
		var target_x = player.global_position.x + side * randf_range(150.0, 240.0)
		# never blink outside the arena walls
		target_x = clampf(target_x, 100.0, arena_width() - 100.0)
		global_position = Vector2(target_x, player.global_position.y)
		facing_direction = -side
	if rig != null:
		var tween2 = create_tween()
		tween2.tween_property(rig, "modulate:a", 1.0, 0.15)
	var shock_r = TELEPORT_SHOCK_RADIUS * reach_mult
	spawn_shockwave(shock_r, magic_color)
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < shock_r:
		deal_player_damage(TELEPORT_SHOCK_DAMAGE)
		knockback_player_away(160.0)
	set_cd("teleport")
	is_busy = false

func do_summon() -> void:
	flash_telegraph(Color(0.7, 0.3, 0.9))
	await get_tree().create_timer(SUMMON_TELEGRAPH).timeout
	if is_dead:
		set_cd("summon")
		return
	minions = minions.filter(func(m): return is_instance_valid(m) and not (("is_dead" in m) and m.is_dead))
	var room = MAX_MINIONS - minions.size()
	for i in range(min(SUMMON_COUNT, room)):
		var m = MINION_SCENE.instantiate()
		m.respawns = false
		m.instant_aggro = true
		m.wave_hp_multiplier = 0.6 * level_hp_mult
		m.wave_damage_multiplier = 0.7 * damage_multiplier
		m.wave_speed_multiplier = speed_multiplier
		m.position = global_position + Vector2(randf_range(-110.0, 110.0), -30.0)
		m.add_to_group("dungeon_combatant")
		get_parent().add_child(m)
		minions.append(m)
	set_cd("summon")
	is_busy = false

func do_pillars() -> void:
	flash_telegraph(Color(1.0, 0.5, 0.15))
	if player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("pillars")
		return
	var ground_y = player.global_position.y
	var xs: Array = [player.global_position.x]
	for i in range(PILLAR_COUNT - 1):
		xs.append(player.global_position.x + randf_range(-PILLAR_SPREAD, PILLAR_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), magic_color, PILLAR_TELEGRAPH, PILLAR_HALF_WIDTH * 2.0)
	await get_tree().create_timer(PILLAR_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(7.0, 0.3)
	for x in xs:
		erupt_pillar(Vector2(x, ground_y), magic_color)
		if player != null and is_instance_valid(player) and absf(player.global_position.x - x) < PILLAR_HALF_WIDTH:
			deal_player_damage(PILLAR_DAMAGE)
			var away = sign(player.global_position.x - x)
			if away == 0:
				away = 1
			if player.has_method("apply_knockback"):
				player.apply_knockback(away, PILLAR_KNOCKBACK)
	set_cd("pillars")
	is_busy = false

# --- apex abilities ---

# Dive bomb (flying): climb to a point high above the player, lock their
# position, then plummet through it and detonate on impact.
func do_dive() -> void:
	flash_telegraph(Color(1.0, 0.8, 0.3))
	is_diving = true
	dive_phase = 0
	dive_timer = 1.4

func process_dive(delta: float) -> void:
	dive_timer -= delta
	if dive_phase == 0:
		var target = player.global_position + Vector2(0, -380.0)
		var to_target = target - global_position
		velocity = to_target.normalized() * DIVE_RISE_SPEED
		if to_target.length() < 50.0 or dive_timer <= 0:
			dive_phase = 1
			dive_timer = 1.2
			dive_target = player.global_position
			spawn_ground_marker(dive_target, magic_color, 0.3, DIVE_RADIUS * reach_mult)
	else:
		velocity = (dive_target - global_position).normalized() * DIVE_PLUNGE_SPEED
		var hit_surface = get_slide_collision_count() > 0
		if global_position.distance_to(dive_target) < 60.0 or hit_surface or dive_timer <= 0:
			shake_camera(11.0, 0.4)
			spawn_shockwave(DIVE_RADIUS * reach_mult, magic_color)
			if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < DIVE_RADIUS * reach_mult:
				deal_player_damage(DIVE_DAMAGE)
				knockback_player_away(DIVE_KNOCKBACK)
			is_diving = false
			velocity = Vector2.ZERO
			set_cd("dive")
			is_busy = false

# Rapid volley: a burst of shots, each re-aimed at the player mid-burst.
func do_volley() -> void:
	flash_telegraph(Color(1.0, 0.9, 0.5))
	await get_tree().create_timer(0.3).timeout
	for i in range(VOLLEY_COUNT):
		if is_dead or player == null or not is_instance_valid(player):
			break
		var dir = (player.global_position - global_position).normalized()
		spawn_arrow(global_position + dir * 46.0, dir, VOLLEY_DAMAGE, VOLLEY_RANGE)
		await get_tree().create_timer(VOLLEY_INTERVAL).timeout
	set_cd("volley")
	is_busy = false

# Meteor storm: like rain but heavier, wider, and falling from far higher.
func do_meteors() -> void:
	flash_telegraph(Color(1.0, 0.4, 0.1))
	if is_dead or player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("meteors")
		return
	var ground_y = player.global_position.y
	var xs: Array = [player.global_position.x]
	for i in range(METEOR_COUNT - 1):
		xs.append(player.global_position.x + randf_range(-METEOR_SPREAD, METEOR_SPREAD))
	for x in xs:
		spawn_ground_marker(Vector2(x, ground_y), magic_color, METEOR_TELEGRAPH, 90.0)
	await get_tree().create_timer(METEOR_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.5)
	for x in xs:
		spawn_arrow(Vector2(x, ground_y - METEOR_HEIGHT), Vector2.DOWN, METEOR_DAMAGE, METEOR_HEIGHT + 150.0)
		await get_tree().create_timer(0.06).timeout
		if is_dead:
			return
	set_cd("meteors")
	is_busy = false

# Vortex: drags the player toward the boss for a sustained pull, then bites
# if they end up in its jaws. Fighting the pull means dashing/flying away.
func do_vortex() -> void:
	flash_telegraph(Color(0.3, 0.95, 0.85))
	spawn_ring_telegraph(global_position, VORTEX_RANGE * 0.4, Color(0.3, 0.95, 0.85), 0.45)
	await get_tree().create_timer(0.45).timeout
	var ticks = int(VORTEX_DURATION / VORTEX_TICK)
	for i in range(ticks):
		if is_dead or player == null or not is_instance_valid(player):
			break
		var dist = global_position.distance_to(player.global_position)
		if dist < VORTEX_RANGE and player.has_method("apply_knockback"):
			var toward = sign(global_position.x - player.global_position.x)
			if toward != 0:
				player.apply_knockback(toward, VORTEX_PULL)
		if i % 3 == 0:
			spawn_shockwave(90.0 + i * 14.0, Color(0.3, 0.95, 0.85))
		await get_tree().create_timer(VORTEX_TICK).timeout
	if not is_dead and player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < VORTEX_CLOSE * reach_mult:
		deal_player_damage(VORTEX_DAMAGE)
		knockback_player_away(180.0)
	set_cd("vortex")
	is_busy = false

# Eclipse beam: locks a horizontal band at the player's altitude across the
# WHOLE arena, then fires. The only escape is changing height -- which is
# exactly what the tiered crater (and late-game flight) is for.
func do_beam() -> void:
	if player == null or not is_instance_valid(player):
		is_busy = false
		set_cd("beam")
		return
	var band_y = player.global_position.y - 20.0
	var arena_w := arena_width()
	flash_telegraph(Color(1.0, 0.25, 0.15))
	var band = ColorRect.new()
	band.position = Vector2(-100.0, band_y - BEAM_HALF_HEIGHT)
	band.size = Vector2(arena_w + 200.0, BEAM_HALF_HEIGHT * 2.0)
	band.color = Color(1.0, 0.2, 0.1, 0.14)
	band.z_index = 5
	get_parent().add_child(band)
	var warn = band.create_tween()
	warn.set_loops(4)
	warn.tween_property(band, "modulate:a", 0.4, BEAM_TELEGRAPH / 8.0)
	warn.tween_property(band, "modulate:a", 1.0, BEAM_TELEGRAPH / 8.0)
	await get_tree().create_timer(BEAM_TELEGRAPH).timeout
	if is_dead:
		if is_instance_valid(band):
			band.queue_free()
		return
	# fire: two damage ticks 0.2s apart so hopping through the band still hurts
	band.color = Color(1.0, 0.3, 0.12, 0.75)
	shake_camera(8.0, 0.3)
	for tick in range(2):
		if player != null and is_instance_valid(player) and absf(player.global_position.y - band_y) < BEAM_HALF_HEIGHT:
			deal_player_damage(BEAM_DAMAGE / (tick + 1))
			if player.has_method("apply_knockback"):
				player.apply_knockback(facing_direction, BEAM_KNOCKBACK / (tick + 1))
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(band):
		var fade = band.create_tween()
		fade.tween_property(band, "modulate:a", 0.0, 0.25)
		fade.tween_callback(band.queue_free)
	set_cd("beam")
	is_busy = false

# Curse volley (the Wizard): a fan of slow homing orbs that chase the player
# and must be juked around terrain -- they cannot be shot down.
func do_curse() -> void:
	flash_telegraph(Color(0.55, 0.3, 1.0))
	await get_tree().create_timer(CURSE_TELEGRAPH).timeout
	if is_dead or player == null or not is_instance_valid(player):
		set_cd("curse")
		is_busy = false
		return
	var base = (player.global_position - global_position).normalized()
	for i in range(CURSE_ORBS):
		var dir = base.rotated(deg_to_rad(-27.0 + 18.0 * i))
		var orb = MAGIC_ORB.new()
		orb.setup(dir, int(round(CURSE_DAMAGE * damage_multiplier)), Color(0.62, 0.35, 1.0), CURSE_ORB_SPEED)
		orb.position = position + dir * 34.0
		get_parent().add_child(orb)
	set_cd("curse")
	is_busy = false

# Doomring (the Wizard): two full rings of bolts in quick succession, each at
# a different rotation -- weave between the spokes or take both waves.
func do_doomring() -> void:
	flash_telegraph(magic_color)
	await get_tree().create_timer(0.5).timeout
	if is_dead:
		set_cd("doomring")
		is_busy = false
		return
	for wave in range(DOOMRING_WAVES):
		var offset = randf() * TAU
		for i in range(DOOMRING_BOLTS):
			var dir = Vector2.RIGHT.rotated(offset + i * TAU / DOOMRING_BOLTS)
			spawn_arrow(global_position + dir * 40.0, dir, DOOMRING_DAMAGE, DOOMRING_RANGE)
		shake_camera(5.0, 0.2)
		await get_tree().create_timer(0.35).timeout
		if is_dead:
			return
	set_cd("doomring")
	is_busy = false

# Mirror Legion (the Wizard): split into weak echoes of himself, up to 6 at
# once. Each echo carries a visible shard of his red/purple aura -- and while
# it lives, a piece of his Soul Ward: the more echoes are out, the harder HE
# can be hurt. Slaying echoes re-hardens him, so the player must choose.
# How many echoes his current wounds permit: none at full health, one more
# per ~12% HP lost, the full six only when he's nearly destroyed.
func allowed_clones() -> int:
	var missing = 1.0 - float(health) / float(max_health)
	return clampi(int(floor(missing * (MAX_CLONES + 2.0))), 0, MAX_CLONES)

func living_clones() -> int:
	clones = clones.filter(func(c): return is_instance_valid(c) and not (("is_dead" in c) and c.is_dead))
	return clones.size()

func do_clone() -> void:
	flash_telegraph(magic_color)
	await get_tree().create_timer(0.45).timeout
	if is_dead:
		set_cd("clone")
		is_busy = false
		return
	var room = allowed_clones() - living_clones()
	for i in range(min(CLONES_PER_CAST, room)):
		var c = load("res://boss.tscn").instantiate()
		c.boss_id = "wizard"
		c.is_clone = true
		c.level_hp_mult = level_hp_mult
		c.damage_multiplier = damage_multiplier * CLONE_DMG_FRAC
		c.speed_multiplier = speed_multiplier
		c.position = global_position + Vector2(randf_range(-420.0, 420.0), randf_range(-140.0, 0.0))
		c.add_to_group("dungeon_combatant")
		get_parent().add_child(c)
		clones.append(c)
		minions.append(c)   # swept away when the real wizard dies
		spawn_shockwave(70.0, magic_color)
	set_cd("clone")
	is_busy = false

# --- ability helpers ---

func spawn_arrow(pos: Vector2, dir: Vector2, dmg: int, rng: float) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = pos
	arrow.setup(dir.normalized(), int(round(dmg * damage_multiplier)), 15.0, 30.0, 2, true, rng)
	get_parent().add_child(arrow)

func deal_player_damage(amount: int) -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(int(round(amount * damage_multiplier)))

func knockback_player_away(distance: float) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("apply_knockback"):
		return
	var away = sign(player.global_position.x - global_position.x)
	if away == 0:
		away = facing_direction
	player.apply_knockback(away, distance)

func shake_camera(magnitude: float, duration: float) -> void:
	if player != null and is_instance_valid(player) and player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(magnitude, duration)

func spawn_ring_telegraph(center: Vector2, radius: float, color: Color, duration: float) -> void:
	# chunky octagon: reads as a radius but keeps the squarish pixel theme
	var ring = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * radius)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.18)
	ring.global_position = center
	ring.z_index = 5
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.tween_property(ring, "modulate:a", 0.0, duration)
	t.tween_callback(ring.queue_free)

func spawn_shockwave(radius: float, color: Color) -> void:
	var ring = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * radius)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.5)
	ring.global_position = global_position
	ring.z_index = 6
	ring.scale = Vector2(0.2, 0.2)
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.3)
	t.tween_property(ring, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(ring.queue_free)

func spawn_ground_marker(pos: Vector2, color: Color, duration: float, width: float = 60.0) -> void:
	var marker = ColorRect.new()
	marker.size = Vector2(width, 10.0)
	marker.position = pos - Vector2(width / 2.0, 5.0)
	marker.color = Color(color.r, color.g, color.b, 0.55)
	marker.z_index = 5
	get_parent().add_child(marker)
	var t = marker.create_tween()
	t.set_loops(int(duration / 0.16) + 1)
	t.tween_property(marker, "modulate:a", 0.2, 0.08)
	t.tween_property(marker, "modulate:a", 0.8, 0.08)
	get_tree().create_timer(duration).timeout.connect(marker.queue_free)

func erupt_pillar(base: Vector2, color: Color = Color(1.0, 0.45, 0.12)) -> void:
	var pillar = ColorRect.new()
	pillar.size = Vector2(PILLAR_HALF_WIDTH * 2.0, PILLAR_HEIGHT)
	pillar.position = base - Vector2(PILLAR_HALF_WIDTH, PILLAR_HEIGHT)
	pillar.color = Color(color.r, color.g, color.b, 0.9)
	pillar.z_index = 6
	pillar.scale.y = 0.05
	get_parent().add_child(pillar)
	var t = pillar.create_tween()
	t.tween_property(pillar, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.15)
	t.tween_property(pillar, "modulate:a", 0.0, 0.25)
	t.tween_callback(pillar.queue_free)

# --- combat / lifecycle ---

func check_bump() -> void:
	if is_busy or is_charging or is_dead or player == null or not is_instance_valid(player) or player.is_knocked_back:
		return
	if global_position.distance_to(player.global_position) > BUMP_THRESHOLD * reach_mult:
		return
	var away = sign(player.global_position.x - global_position.x)
	if away == 0:
		away = 1
	if player.has_method("apply_knockback"):
		player.apply_knockback(away, randf_range(30.0, 45.0))

func flash_telegraph(color: Color) -> void:
	if rig == null:
		return
	var tween = create_tween()
	tween.tween_property(rig, "modulate", color, 0.12)
	tween.tween_property(rig, "modulate", current_tint, 0.12)
	tween.set_loops(2)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	var dmg := amount
	# weapon counter: countering weapon hits harder AND fires its mechanic;
	# every other weapon is guarded (unless an archer has just exposed the boss)
	if counter_role != "":
		var role := current_player_role()
		if role == counter_role:
			dmg = int(round(dmg * COUNTER_DMG_BONUS))
			trigger_counter_mechanic(role)
		elif exposed_timer <= 0.0:
			dmg = int(round(dmg * GUARD_MULT))
	# Soul Ward: undivided he shrugs off half of everything; each living echo
	# carries a shard of his soul away and cracks the ward wider open
	if has_soul_split:
		dmg = max(1, int(round(dmg * (SOUL_WARD_BASE + SOUL_WARD_PER_CLONE * living_clones()))))
	health -= dmg
	update_health_bar()
	if health <= 0:
		die()
	else:
		flash_hit()
		play_sfx(SFX_HIT)
		# apex bosses enrage earlier AND hit a second gear near death
		var enrage_at = 0.6 if is_apex else ENRAGE_THRESHOLD
		if not is_enraged and health <= max_health * enrage_at:
			enrage()
		if is_apex and not is_frenzied and health <= max_health * 0.25:
			frenzy()
		# the Wizard's reflex: struck, he may flicker a short step away
		if has_blink_on_hit and not is_busy and not is_charging and not is_diving and randf() < BLINK_ON_HIT_CHANCE:
			blink_short()

func enrage() -> void:
	is_enraged = true
	current_tint = Color(1.0, 0.62, 0.56)   # blood-tinged
	if rig != null:
		rig.modulate = current_tint

# Apex second wind: cooldowns nearly vanish and it moves a quarter faster.
func frenzy() -> void:
	is_frenzied = true
	current_tint = Color(1.0, 0.38, 0.32)   # burning red
	if rig != null:
		rig.modulate = current_tint
	base_move_speed *= 1.25
	shake_camera(9.0, 0.5)
	spawn_shockwave(240.0, Color(1.0, 0.15, 0.1))
	# the crumbling aura rages with him
	if aura_particles != null and is_instance_valid(aura_particles):
		aura_particles.amount = 84
		aura_particles.emission_sphere_radius = AURA_RADIUS * 0.95
		aura_particles.scale_amount_max = 8.0
	if aura_particles2 != null and is_instance_valid(aura_particles2):
		aura_particles2.amount = 59   # keeps its ~0.7x ratio in frenzy
		aura_particles2.emission_sphere_radius = AURA_RADIUS * 0.95
		aura_particles2.scale_amount_max = 8.0
	aura_spin = 1.9   # the ember rings whirl in frenzy
	aura_last_n = -1  # force the soul-split distribution to recompute

func apply_knockback(_direction_sign: int, _distance: float) -> void:
	pass

func flash_hit() -> void:
	if rig == null:
		return
	rig.modulate = Color(2.4, 2.4, 2.4)
	var tween = create_tween()
	tween.tween_property(rig, "modulate", current_tint, 0.15)

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

func update_health_bar() -> void:
	var percent = clamp(float(health) / max_health, 0.0, 1.0)
	$HealthBarFill.size.x = health_bar_w * percent

func die() -> void:
	# echoes are worth a token amount, not a boss bounty
	GameState.add_xp(15 if is_clone else int(round(60 * damage_multiplier)))
	is_dead = true
	is_busy = true
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	# clear any minions this boss summoned so they don't linger after the fight
	for m in minions:
		if is_instance_valid(m) and m.has_method("take_damage"):
			m.take_damage(999999)
	died.emit()
	await play_death_animation()
	visible = false
	await get_tree().create_timer(0.2).timeout
	queue_free()

func play_death_animation() -> void:
	spawn_death_particles()
	var tween = create_tween()
	tween.set_parallel(true)
	if rig != null:
		tween.tween_property(rig, "modulate", Color(1.0, 0.35, 0.1), 0.25)
		tween.tween_property(rig, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 36
	particles.lifetime = 0.9
	particles.explosiveness = 0.85
	particles.direction = Vector2(0, -1)
	particles.spread = 65.0
	particles.gravity = Vector2(0, -60)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 130.0
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.4, 0.08, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
