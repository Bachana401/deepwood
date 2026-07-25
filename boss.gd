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

# Bosses have GRAVITY but no jump, and on touching any vertical surface they set
# wall_turn_timer and walk AWAY for WALL_TURN_DURATION. That was fine when the
# only terrain was drop-through ledges (a boss never collides sideways with
# one). It is a disaster next to the new solid COVER: a ground boss walks into a
# knee-high pillar, turns away, comes back, turns away -- oscillating forever,
# never reaching the player. Five arenas (gaoler/warden/cinderking/glass_saint/
# last_man) put cover in front of a ground boss, so without a hop the fight is
# literally unwinnable: stand behind a pillar and plink it.
#
# So a grounded, wall-blocked ground boss HOPS instead of turning. Cover is
# capped at VAULT_HEIGHT (dungeon_interior), and this clears comfortably more:
# rise = 480^2 / (2*900) = 128px. Cover slows the boss (it must hop); it never
# traps it. The turn-away stays only as the airborne/cooldown fallback.
const BOSS_CLIMB_VELOCITY = -480.0
const BOSS_CLIMB_COOLDOWN = 0.55

# BEHAVIOR PROFILE -- the boss's MOVEMENT personality, separate from its attacks,
# so no two bosses cross the floor the same way (dev: "significantly different").
# Flying bosses ignore this and hover (process_hover). The vocabulary:
#   rusher   -- closes straight in (default, bruisers)
#   kiter    -- holds a range; backs off when you crowd it (ranged casters)
#   pursuer  -- relentless: ACCELERATES the longer it chases you
#   pouncer  -- holds a medium range, then bursts in and peels back out
#   erratic  -- unpredictable feinting bursts and pauses (skittery)
#   weave    -- advances while wobbling forward/back, hard to time
#   turtle   -- barely moves; it wants YOU to come to it
#   hopper   -- approaches in periodic jumps instead of walking
#   mirror   -- moves only while YOU move; stalks your rhythm (the Last Man)
const KITE_RANGE = 380.0
const KITE_HYSTERESIS = 70.0
const POUNCE_HOLD_RANGE = 300.0
var profile := "rusher"
# per-boss movement state used by the profiles above
var _move_timer := 0.0
var _move_phase := 0.0
var _move_dir := 0.0
var _chase_ramp := 1.0

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

# --- SIGNATURE abilities (BOSSES.md §6): one distinct move per boss, spread
# across attack TYPES (grab/root, tracking-freeze, zone-denial, stun, pull, ...)
# so bosses threaten DIFFERENTLY, not just with reskinned projectiles. These use
# the player CC substrate (player.gd apply_root/freeze/stun/disorient/pull) and
# the hazard_zone primitive. Teaching tier (floors 5-30) implemented first.
const HAZARD_SCENE = preload("res://hazard_zone.gd")

# Gravewarden 5 -- Grave Grasp (GRAB/ROOT): a hand bursts up under you and holds
const GRASP_TELEGRAPH = 0.55
const GRASP_DAMAGE = 14
const GRASP_ROOT = 1.1
const GRASP_RADIUS = 74.0
# Frost Monarch 10 -- Rime Lance (TRACKING + FREEZE): a marker that follows, locks, strikes
const RIME_TRACK = 0.7
const RIME_TELEGRAPH = 0.3
const RIME_DAMAGE = 18
const RIME_FREEZE = 1.15
const RIME_RADIUS = 62.0
# Cinder Colossus 15 -- Magma Wake (ZONE DENIAL): a line of lingering fire toward you
const MAGMA_COUNT = 5
const MAGMA_DAMAGE = 9
const MAGMA_LIFETIME = 3.2
const MAGMA_RADIUS = 66.0
# Weaver 20 -- Web Snare (ROOT-ZONE): a sticky patch that roots/slows
const WEB_TELEGRAPH = 0.4
const WEB_DAMAGE = 6
const WEB_LIFETIME = 4.0
const WEB_RADIUS = 90.0
# Stormcaller 25 -- Thunderstrike (DELAYED STRIKE + STUN): a bolt drops on your spot
const THUNDER_TELEGRAPH = 0.5
const THUNDER_DAMAGE = 20
const THUNDER_STUN = 0.7
const THUNDER_RADIUS = 58.0
const THUNDER_BOLTS = 3
# Void Sovereign 30 -- Void Rift (PULL-ZONE): a singularity drags you in while it hits
const RIFT_TELEGRAPH = 0.5
const RIFT_DURATION = 1.8
const RIFT_PULL = 300.0      # px/s of drag velocity (added each frame while open)
const RIFT_DAMAGE = 8
const RIFT_RADIUS = 120.0
const HOMING_SCENE = preload("res://homing_bolt.gd")

# --- deep tier signatures (floors 35-60) ---
# Hollow Choir 35 -- Dissonant Scream (DISORIENT cone)
const SCREAM_TELEGRAPH = 0.5
const SCREAM_RANGE = 380.0
const SCREAM_DAMAGE = 16
const SCREAM_DISORIENT = 1.4
# Ashen Penitent 40 -- Prayer Pyre (EXPANDING flame front)
const PYRE_STEPS = 4
const PYRE_STEP_TIME = 0.34
const PYRE_DAMAGE = 12
const PYRE_MAX_RADIUS = 360.0
# Gaoler 45 -- Iron Maiden (DELAYED cage trap: heavy hit + brief cage-root)
const MAIDEN_TELEGRAPH = 0.7
const MAIDEN_DAMAGE = 26
const MAIDEN_RADIUS = 82.0
const MAIDEN_ROOT = 0.55
# Sablefang 50 -- Pounce (GAP-CLOSER leap)
const POUNCE_TELEGRAPH = 0.4
const POUNCE_TIME = 0.34
const POUNCE_DAMAGE = 22
const POUNCE_HIT_RADIUS = 92.0
# Effigy 55 -- Splinter Burst (DELAYED outward ring + embers)
const SPLINTER_TELEGRAPH = 0.55
const SPLINTER_COUNT = 12
const SPLINTER_DAMAGE = 14
const SPLINTER_RANGE = 460.0
# Mourncaller 60 -- Keening (HOMING swarm)
const KEENING_COUNT = 5
const KEENING_DAMAGE = 11
# --- deep tier signatures (floors 65-90) ---
# Unseen 65 -- Ambush (MOBILITY-STRIKE: blink behind + hit + brief stun)
const AMBUSH_VANISH = 0.28
const AMBUSH_STRIKE = 0.22
const AMBUSH_DAMAGE = 20
const AMBUSH_STUN = 0.5
const AMBUSH_RADIUS = 105.0
# Warden of Nails 70 -- Impale (TRACKING OVERHEAD nail: hit + knockback)
const IMPALE_TRACK = 0.45
const IMPALE_TELEGRAPH = 0.3
const IMPALE_DAMAGE = 24
const IMPALE_RADIUS = 72.0
# Twin Despair 75 -- Pincer Lunge (cross-LEAP through the player)
const PINCER_TELEGRAPH = 0.38
const PINCER_TIME = 0.4
const PINCER_DAMAGE = 21
const PINCER_HIT_RADIUS = 88.0
# Cinderking 80 -- Eruption (spreading floor WAVE: jump the cracks)
const ERUPT_STEPS = 5
const ERUPT_SPACING = 135.0
const ERUPT_STEP_TIME = 0.16
const ERUPT_DAMAGE = 18
const ERUPT_BAND = 82.0
# Glass Saint 85 -- Refraction (MULTI-BEAM)
const REFRACT_BEAMS = 5
const REFRACT_TELEGRAPH = 0.5
const REFRACT_DAMAGE = 16
const REFRACT_LENGTH = 720.0
const REFRACT_WIDTH = 42.0
const REFRACT_SPREAD = 0.5     # radians between adjacent beams
# Last Man 90 -- Riposte Stance (active COUNTER)
const STANCE_DURATION = 1.3
const STANCE_COUNTER_DAMAGE = 26
const STANCE_COUNTER_STUN = 0.6
var parry_until := 0.0
var _parry_consumed := false
# Light hits that rang off stagger armour, packed into the guard. Once they add
# up to what a heavy blow would have been, the guard cracks -- so a fast weapon
# gets there by volume instead of being ignored forever.
var _guard_chip := 0.0

# --- Statuses on bosses: DoT yes, hard CC no. ---
# Every status used to vanish against a boss (no apply_status at all, and every
# thrower guards with has_method) -- which silently killed two whole class specs
# at every boss fight: the Warden is PURE DoT and the Elementalist's keystone is
# Ignite. But full status handling would let freeze-lock trivialise fights, so
# the line is drawn where apply_petrify already drew it: damage-over-time works
# in full, control is resisted -- slow lands at half strength (capped), freeze
# becomes that same brief slow.
const BOSS_SLOW_FLOOR := 0.55       # a boss never moves slower than this factor
var status_burn_until := 0.0
var status_burn_dps := 0.0
var status_poison_until := 0.0
var status_poison_dps := 0.0
var status_slow_until := 0.0
var status_slow_factor := 1.0
var _dot_accum := 0.0

func apply_status(kind: String, dur: float, mag: float) -> void:
	if is_dead:
		return
	match kind:
		"burn":
			var burn_live := _time_now() < status_burn_until
			status_burn_until = _time_now() + dur
			status_burn_dps = maxf(status_burn_dps if burn_live else 0.0, mag)
		"poison":
			var poison_live := _time_now() < status_poison_until
			status_poison_until = _time_now() + dur
			status_poison_dps = maxf(status_poison_dps if poison_live else 0.0, mag)
		"slow", "freeze":
			# freeze on a boss is just a hard slow -- it never stops acting
			var factor := maxf(BOSS_SLOW_FLOOR, 1.0 - (1.0 - (mag if kind == "slow" else 0.5)) * 0.5)
			status_slow_until = _time_now() + (dur if kind == "slow" else minf(dur, 1.2))
			status_slow_factor = factor
		"petrify":
			apply_petrify(dur)

func boss_status_slow_mult() -> float:
	return status_slow_factor if _time_now() < status_slow_until else 1.0

# DoT ticks bypass take_damage ON PURPOSE: routing them through it would fire
# the reactive phase (and eat guard chips) every tick, leaving the boss
# permanently intangible. Burn and poison are the slow chip that works while
# everything else is being dodged -- that is the whole identity of a DoT spec.
func tick_statuses(delta: float) -> void:
	var dps := 0.0
	if _time_now() < status_burn_until:
		dps += status_burn_dps
	if _time_now() < status_poison_until:
		dps += status_poison_dps
	if dps <= 0.0:
		return
	_dot_accum += dps * delta
	if _dot_accum >= 1.0:
		var chunk := int(_dot_accum)
		_dot_accum -= float(chunk)
		health -= chunk
		update_health_bar()
		if health <= 0:
			die()
# The boss's HP before floor scaling. Stagger armour is measured against this,
# not against the inflated pool -- see stagger_threshold().
var base_max_health := 900
# --- apex tier signatures (floors 95-100) ---
# Seraphiel 95 -- Judgment (full-height light wall SWEEPS across: dodge sideways)
const JUDGMENT_TELEGRAPH = 0.6
const JUDGMENT_SPEED = 620.0
const JUDGMENT_SPAN = 1400.0
const JUDGMENT_DAMAGE = 24
const JUDGMENT_BAND = 55.0
# Leviathan 98 -- Tidal Crush (low WAVE sweeps the floor: get to high ground)
const TIDAL_TELEGRAPH = 0.7
const TIDAL_SPEED = 560.0
const TIDAL_SPAN = 1500.0
const TIDAL_DAMAGE = 26
const TIDAL_BAND = 60.0
const TIDAL_LOW = 130.0        # only catches players within this height of the floor line
# Eclipse 99 -- Black Sun (darkness closes in: the safe lit ring SHRINKS to it)
const SUN_STEPS = 5
const SUN_STEP_TIME = 0.5
const SUN_START_RADIUS = 620.0
const SUN_END_RADIUS = 190.0
const SUN_DAMAGE = 16
# Fallen Wizard 100 -- Unwriting (the arena UNWRITES: void tears open under you)
const UNWRITE_TELEGRAPH = 0.7
const UNWRITE_ZONES = 5
const UNWRITE_RADIUS = 130.0
const UNWRITE_DAMAGE = 14
const UNWRITE_LIFETIME = 2.4

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
# echoes used to cast SLOWER than the original (1.5) and only had two ranged
# skills, so they were easy to out-fly. Now they cast a touch FASTER than base
# and can teleport onto you -- a genuinely harassing swarm you can't just kite.
const CLONE_CD_PENALTY = 0.85
const CLONE_KIT = ["volley", "curse", "teleport"]

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
	# signature abilities (BOSSES.md §6) -- teaching tier
	"grave_grasp":  {"cd": 6.0, "min": 0.0,   "max": 520.0},
	"rime_lance":   {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"magma_wake":   {"cd": 7.0, "min": 150.0, "max": 100000.0},
	"web_snare":    {"cd": 7.0, "min": 0.0,   "max": 100000.0},
	"thunderstrike":{"cd": 6.0, "min": 0.0,   "max": 100000.0},
	"void_rift":    {"cd": 8.5, "min": 120.0, "max": 100000.0},
	# signature abilities -- deep tier (35-60)
	"dissonant_scream": {"cd": 6.0, "min": 0.0,   "max": 420.0},
	"prayer_pyre":      {"cd": 8.0, "min": 0.0,   "max": 100000.0},
	"iron_maiden":      {"cd": 7.0, "min": 0.0,   "max": 100000.0},
	"pounce":           {"cd": 6.0, "min": 140.0, "max": 100000.0},
	"splinter_burst":   {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"keening":          {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	# signature abilities -- deep tier (65-90)
	"ambush":         {"cd": 6.0, "min": 0.0,   "max": 100000.0},
	"impale":         {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"pincer_lunge":   {"cd": 6.0, "min": 120.0, "max": 100000.0},
	"eruption":       {"cd": 7.5, "min": 0.0,   "max": 100000.0},
	"refraction":     {"cd": 6.5, "min": 0.0,   "max": 100000.0},
	"riposte_stance": {"cd": 8.0, "min": 0.0,   "max": 100000.0},
	# signature abilities -- apex tier (95-100)
	"judgment":     {"cd": 8.0, "min": 0.0, "max": 100000.0},
	"tidal_crush":  {"cd": 8.0, "min": 0.0, "max": 100000.0},
	"black_sun":    {"cd": 9.0, "min": 0.0, "max": 100000.0},
	"unwriting":    {"cd": 9.0, "min": 0.0, "max": 100000.0},
}

# --- The Fallen Wizard's combo book (level 100 only) ---
# Instead of the generic "one attack, wait out the cooldown, repeat" loop, the
# real wizard chains several DIFFERENT skills back-to-back into a combo -- the
# player has to dodge a sustained flurry, then gets a recovery window where the
# boss hovers exposed (see drive_wizard). Each combo is teleport-heavy and uses
# a distinct mix of skills; he never runs the same one twice in a row. Steps
# map 1:1 to the do_* abilities (plus "teleport"). Clones do NOT use these --
# they keep the simple two-skill AI so the swarm stays readable.
const WIZARD_COMBOS = [
	["teleport", "volley", "teleport", "curse", "volley"],       # Blink Hunt
	["doomring", "teleport", "meteors", "doomring"],             # Doom Cascade
	["meteors", "teleport", "beam", "teleport", "volley"],       # Skyfall
	["clone", "teleport", "curse", "volley", "curse"],           # Mirror Hunt
	["teleport", "beam", "teleport", "doomring", "teleport", "volley"],  # Phantom Barrage
	["unwriting", "teleport", "doomring", "clone", "unwriting"],         # Unwriting (the finale mutate)
]

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
		"abilities": ["grave_grasp", "slam", "charge"], "sprite": "gravewarden",
	},
	# A tall, skeletal-thin frozen lich-king in an icy shroud.
	"frost_monarch": {
		"profile": "kiter",
		"name": "The Frost Monarch",
		"color": Color(0.55, 0.68, 0.8), "eye_color": Color(0.85, 0.97, 1.0),
		"magic": Color(0.65, 0.9, 1.0),
		"body": Vector2(110, 250), "hp": 780, "speed": 56.0, "shape": "crown",
		"abilities": ["rime_lance", "rain", "teleport"], "sprite": "frost_monarch",
		"passives": ["stagger_armour"],   # teaches: commit to heavy hits
	},
	# A huge charcoal stag-demon, antlers still burning from the forest fire
	# that killed it. Stampedes and erupts fire.
	"cinder_colossus": {
		"profile": "pursuer",
		"name": "The Cinder Colossus",
		"color": Color(0.16, 0.12, 0.11), "eye_color": Color(1.0, 0.6, 0.15),
		"magic": Color(1.0, 0.5, 0.12),
		"body": Vector2(240, 230), "hp": 1100, "speed": 95.0, "shape": "colossus",
		"abilities": ["magma_wake", "charge", "barrage"], "sprite": "cinder_colossus",
		"passives": ["riposte"],          # teaches: read the tell, hit the recovery
	},
	# A SMALL corpse-spider brood mother -- quick, evasive, hard to corner;
	# her legs span far wider than her body.
	"weaver": {
		"profile": "erratic",
		"name": "The Weaver",
		"color": Color(0.3, 0.22, 0.34), "eye_color": Color(1.0, 0.4, 0.9),
		"magic": Color(0.95, 0.4, 0.85),
		"body": Vector2(120, 110), "hp": 720, "speed": 105.0, "shape": "spider",
		"abilities": ["web_snare", "summon", "teleport"],
		"passives": ["soulbind"],         # teaches: kill the adds first
	},
	# A lightning-scarred owl-wraith of the dead canopy; medium build.
	"stormcaller": {
		"profile": "weave",
		"name": "The Stormcaller",
		"color": Color(0.36, 0.38, 0.3), "eye_color": Color(1.0, 1.0, 0.55),
		"magic": Color(0.95, 0.95, 0.55),
		"body": Vector2(150, 180), "hp": 880, "speed": 88.0, "shape": "caster",
		"abilities": ["thunderstrike", "nova", "barrage"], "sprite": "stormcaller",
		"passives": ["skyfall"],          # teaches: the ground is safer
	},
	# The hollow king: a dead monarch whose chest is an open void, his crown
	# floating above the ruin of his head.
	"void_sovereign": {
		"profile": "pouncer",
		"name": "The Void Sovereign",
		"color": Color(0.17, 0.11, 0.25), "eye_color": Color(0.9, 0.2, 1.0),
		"magic": Color(0.75, 0.3, 1.0),
		"body": Vector2(170, 240), "hp": 1220, "speed": 76.0, "shape": "void",
		"abilities": ["void_rift", "teleport", "nova", "summon"], "sprite": "void_sovereign",
		"passives": ["sidestep"],         # teaches: bait it, do not spam
	},
	# ----- FINALE TIER (levels 95/98/99/100) -----
	# Apex bosses: enrage earlier, FRENZY at low health, and most fly.
	# A fallen angel of bone: skeletal wings, tarnished halo.
	# ======================= THE DEEP: floors 35-90 =========================
	# The forever rule: every boss differs in MANY ways at once -- combos,
	# pattern, attack manner, speed, and SIZE (width and length both). No two
	# silhouettes and no two rhythms may repeat. Depth buys LONGER, nastier
	# combos and stacked reactive mechanics -- never bigger numbers.

	# 35 -- villagers fused into one chorus of soulless mouths. WIDE and squat:
	# it fills the arena sideways so there is nowhere to stand that isn't in
	# front of some part of it. Slow. The fakes sing; the real one doesn't.
	"hollow_choir": {
		"profile": "pursuer",
		"name": "The Hollow Choir",
		"color": Color(0.34, 0.33, 0.30), "eye_color": Color(0.9, 0.95, 0.8),
		"magic": Color(0.75, 0.85, 0.6),
		"body": Vector2(300, 150), "hp": 1150, "speed": 44.0, "shape": "brute",
		"abilities": ["summon", "nova", "rain"],
		"passives": ["false_twin", "soulbind"],
	},
	# 40 -- a burning devil locked mid-prayer. TALL and thin, and it barely
	# moves: it wants you to come to it and swing at the prayer.
	"ashen_penitent": {
		"profile": "turtle",
		"name": "The Ashen Penitent",
		"color": Color(0.36, 0.16, 0.12), "eye_color": Color(1.0, 0.55, 0.15),
		"magic": Color(1.0, 0.45, 0.1),
		"body": Vector2(90, 300), "hp": 900, "speed": 34.0, "shape": "caster",
		"abilities": ["pillars", "beam", "nova"],
		"passives": ["riposte", "famine"],
	},
	# 45 -- warden of the soul-pits. Heavy, armoured, deliberate: chains you to
	# the floor you stand on and then walks you down.
	"gaoler": {
		"name": "The Gaoler",
		"color": Color(0.28, 0.26, 0.30), "eye_color": Color(0.6, 0.9, 1.0),
		"magic": Color(0.5, 0.8, 1.0),
		"body": Vector2(190, 240), "hp": 1500, "speed": 52.0, "shape": "titan",
		"abilities": ["slam", "charge", "pillars"],
		"passives": ["tether", "stagger_armour"],
	},
	# 50 -- a beast that has learned your habits. SMALL and very fast: it dodges
	# what you repeat, so the fight punishes muscle memory.
	"sablefang": {
		"profile": "pouncer",
		"name": "Sablefang",
		"color": Color(0.16, 0.14, 0.20), "eye_color": Color(1.0, 0.85, 0.2),
		"magic": Color(0.8, 0.7, 1.0),
		"body": Vector2(150, 90), "hp": 820, "speed": 165.0, "shape": "spider",
		"abilities": ["charge", "volley", "teleport"],
		"passives": ["sidestep", "rhythm_punish"],
	},
	# 55 -- a burning wicker giant. HUGE and slow; it sows fire where you were,
	# and chip damage does nothing to a thing made of bundled logs.
	"effigy": {
		"profile": "hopper",
		"name": "The Effigy",
		"color": Color(0.42, 0.28, 0.12), "eye_color": Color(1.0, 0.7, 0.2),
		"magic": Color(1.0, 0.6, 0.15),
		"body": Vector2(230, 330), "hp": 1750, "speed": 40.0, "shape": "colossus",
		"abilities": ["slam", "pillars", "meteors"],
		"passives": ["stagger_armour", "afterimage_trap"],
	},
	# 60 -- a widow of the Harvest. Mid-sized, drifting; grief reflects, and she
	# feeds on what you throw until her mourners are dead.
	"mourncaller": {
		"name": "Mourncaller",
		"color": Color(0.24, 0.20, 0.30), "eye_color": Color(0.7, 0.9, 1.0),
		"magic": Color(0.55, 0.75, 1.0),
		"body": Vector2(110, 200), "hp": 1050, "speed": 82.0, "shape": "caster",
		"abilities": ["summon", "rain", "volley"],
		"passives": ["soulbind", "mirror"],
		"flying": true,
	},
	# 65 -- intangible. You cannot hit it AND cannot stand still. The two
	# mechanics eat each other's counter-play: the answer is patience + motion.
	"unseen": {
		"name": "The Unseen",
		"color": Color(0.12, 0.12, 0.16), "eye_color": Color(0.9, 0.2, 0.9),
		"magic": Color(0.75, 0.2, 0.95),
		"body": Vector2(100, 210), "hp": 980, "speed": 136.0, "shape": "void",
		"abilities": ["teleport", "volley", "curse"],
		"passives": ["phase", "afterimage_trap"],
		"flying": true,
	},
	# 70 -- anti-air, flankable only, and it punishes the wind-up. Three
	# mechanics that each close a different escape.
	"warden_of_nails": {
		"name": "The Warden of Nails",
		"color": Color(0.30, 0.24, 0.22), "eye_color": Color(1.0, 0.9, 0.4),
		"magic": Color(0.9, 0.8, 0.35),
		"body": Vector2(170, 270), "hp": 1600, "speed": 60.0, "shape": "titan",
		"abilities": ["barrage", "pillars", "slam"],
		"passives": ["skyfall", "dread_ward", "riposte"],
	},
	# 75 -- two bodies, one soul. Narrow and quick, and it will not stay still
	# long enough to be traded with.
	"twin_despair": {
		"profile": "erratic",
		"name": "The Twin Despair",
		"color": Color(0.20, 0.18, 0.28), "eye_color": Color(0.85, 0.3, 1.0),
		"magic": Color(0.7, 0.3, 1.0),
		"body": Vector2(95, 230), "hp": 1250, "speed": 117.0, "shape": "crown",
		"abilities": ["teleport", "clone", "nova"],
		"passives": ["covenant", "sidestep", "phase"],
	},
	# 80 -- devil-lord of the burning deep. Broad and heavy; reflects what you
	# throw, burns where you stood, and eats your mana for standing near him.
	"cinderking": {
		"profile": "weave",
		"name": "The Cinderking",
		"color": Color(0.34, 0.12, 0.10), "eye_color": Color(1.0, 0.6, 0.1),
		"magic": Color(1.0, 0.4, 0.05),
		"body": Vector2(260, 250), "hp": 1900, "speed": 66.0, "shape": "brute",
		"abilities": ["meteors", "pillars", "nova", "charge"],
		"passives": ["afterimage_trap", "mirror", "famine"],
	},
	# 85 -- reflects everything, must be flanked, and punishes a steady rhythm:
	# every ranged answer is closed; it is a pure melee-discipline fight.
	"glass_saint": {
		"profile": "kiter",
		"name": "The Glass Saint",
		"color": Color(0.62, 0.66, 0.72), "eye_color": Color(0.95, 1.0, 1.0),
		"magic": Color(0.8, 0.95, 1.0),
		"body": Vector2(130, 290), "hp": 1450, "speed": 93.0, "shape": "angel",
		"abilities": ["beam", "volley", "nova"],
		"passives": ["mirror", "dread_ward", "rhythm_punish"],
	},
	# 90 -- the last soulless human. Man-sized, man-speed: he fights exactly the
	# way the player does, and punishes the player's own habits.
	"last_man": {
		"profile": "mirror",
		"name": "The Last Man",
		"color": Color(0.18, 0.17, 0.24), "eye_color": Color(1.0, 1.0, 1.0),
		"magic": Color(0.6, 0.6, 0.7),
		"body": Vector2(80, 180), "hp": 1300, "speed": 145.0, "shape": "crown",
		"abilities": ["charge", "teleport", "volley", "nova"],
		"passives": ["rhythm_punish", "phase", "covenant"],
	},
	"seraph": {
		"name": "Seraphiel, the Last Light",
		"color": Color(0.78, 0.74, 0.6), "eye_color": Color(1.0, 0.55, 0.1),
		"magic": Color(1.0, 0.85, 0.4),
		"body": Vector2(140, 220), "hp": 2400, "speed": 130.0, "shape": "angel",
		"flying": true, "apex": true, "sprite": "seraph",
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
		"profile": "turtle",
		"name": "The Eclipse Titan",
		"color": Color(0.09, 0.06, 0.08), "eye_color": Color(1.0, 0.2, 0.1),
		"magic": Color(1.0, 0.25, 0.12),
		"body": Vector2(260, 340), "hp": 3300, "speed": 90.0, "shape": "titan",
		"apex": true, "sprite": "eclipse",
		"abilities": ["beam", "pillars", "meteors", "teleport", "summon"],
	},
	# The level-100 finale: barely taller than the adventurer -- his power is
	# his magic, not his bulk. Pitch-black robes wreathed in a crumbling red
	# aura (with a lagging purple echo) that burns anyone inside it; he blinks
	# reflexively when struck, and he mirrors himself into a legion of up to 6
	# echoes. Nothing counters him.
	"wizard": {
		"profile": "erratic",
		"name": "The Fallen Wizard",
		"color": Color(0.09, 0.05, 0.07), "eye_color": Color(1.0, 0.12, 0.08),
		"magic": Color(1.0, 0.22, 0.12),
		"body": Vector2(34, 52), "hp": 4000, "speed": 120.0, "shape": "wizard",
		"flying": true, "apex": true, "sprite": "fallen_wizard",
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

# PixelLab boss skins (art/bosses/<skin>/) replace the procedural rig when a
# BOSSES entry sets "sprite" and the art exists; otherwise the rig_<shape>()
# build runs unchanged. The sprite lives UNDER rig, so flash_hit / telegraph /
# death (all modulate rig) and facing (rig.scale.x) drive it for free.
const BOSS_ROOT := "res://art/bosses/"
const BOSS_FILL := 1.0   # sprite content height as a fraction of the boss body.y
var boss_sprite: AnimatedSprite2D = null

var is_busy := false
var is_charging := false
var charge_direction := 1
var charge_dir_2d := Vector2.RIGHT   # flying bosses charge in a full 2D line
var charge_timer := 0.0
var charge_has_hit := false
var is_wall_blocked := false
var wall_turn_timer := 0.0
var climb_cd := 0.0

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

# ============================ REACTIVE MECHANICS =============================
# The vocabulary that makes each boss fight differently (design: BOSSES.md 2).
# The rule every one of these obeys: NONE of them raise damage. They gate HOW
# you are allowed to fight, and each has a counter-play the player can learn.
# Difficulty must come from misreading the fight, never from a big number.
# -----------------------------------------------------------------------------

# SIDESTEP -- it blinks a body-width out of your melee swing, leaving an
# afterimage. Beaten by baiting it, or by reach. Only dodges MELEE: a projectile
# already in the air isn't something you can read a dodge off.
# Punish damage, deliberately in the same band as its ordinary attacks
# (SLAM 30 / CHARGE 26) and scaled by the SAME sqrt(damage_multiplier) the rest
# of the fight uses -- a counter must sting, never one-shot. That is the dev's
# hard line: hard because you misread it, not because the number was too big.
const RIPOSTE_DAMAGE := 28
const RHYTHM_DAMAGE := 18
const SKYFALL_DAMAGE := 22

const SIDESTEP_COOLDOWN := 1.6
var has_sidestep := false
var sidestep_ready_at := 0.0

# RIPOSTE -- hit it during its WIND-UP and it counters. Hit it in the recovery
# and you're fine. This is the mechanic that punishes attacking on reflex: the
# tell is there, you just have to actually read it.
const RIPOSTE_COOLDOWN := 2.5
var has_riposte := false
var riposte_ready_at := 0.0
var telegraphing := false      # true only during an ability's wind-up

# (skyfall + mirror are declared with the rest of the deep mechanics below)

# RHYTHM_PUNISH -- every Nth CONSECUTIVE hit is countered. Punishes mashing one
# button; beaten by varying your rhythm or dropping a beat.
const RHYTHM_WINDOW := 1.2     # hits this close together count as consecutive
const RHYTHM_COUNT := 4        # every 4th in a row bites
var has_rhythm_punish := false
var rhythm_streak := 0
var rhythm_last_hit := 0.0

# STAGGER_ARMOUR -- chip damage bounces; only a HEAVY/crit hit breaks the guard.
const STAGGER_HEAVY_FRACTION := 0.06   # >=6% of its max HP in one blow = heavy
var has_stagger_armour := false

# TETHER -- chains the player to where they stand. The chain doesn't stop you,
# it BILLS you: the further you drag it, the harder it pulls back. Break line of
# sight or close the distance. (The Gaoler, floor 45.)
const TETHER_RANGE := 420.0        # snaps if you get further than this
const TETHER_DPS := 6.0            # per second, ramping with distance
const TETHER_RECAST := 7.0
var has_tether := false
var tether_active := false
var tether_anchor := Vector2.ZERO
var tether_next_at := 0.0
var _tether_line: Line2D = null

# FAMINE -- drains MANA on contact, not HP. Your resources are the resource.
# (The Ashen Penitent, floor 40.)
const FAMINE_RADIUS := 120.0
const FAMINE_DRAIN := 9.0          # mana/sec inside the radius
var has_famine := false

# AFTERIMAGE_TRAP -- marks the ground where you STOOD, and it detonates. Standing
# still is the mistake. (The Effigy 55, The Unseen 65, The Cinderking 80.)
const TRAP_DELAY := 1.5
const TRAP_RADIUS := 54.0
const TRAP_PERIOD := 2.2
const TRAP_DAMAGE := 20
var has_afterimage_trap := false
var trap_next_at := 0.0

# DREAD_WARD -- only takes damage from BEHIND. It must be flanked, not out-DPSed.
# (Warden of Nails 70, Seraphiel 95, The Glass Saint 85.)
var has_dread_ward := false

# MIRROR -- hostile-to-IT projectiles are turned around and sent back. Closes the
# ranged answer entirely: get in its face, or eat your own arrows.
# (Mourncaller 60, Cinderking 80, Glass Saint 85.)
const MIRROR_RADIUS := 90.0
const MIRROR_COOLDOWN := 0.35     # so a volley doesn't reflect 20 shots in a frame
var has_mirror := false
var mirror_ready_at := 0.0

# SKYFALL -- anti-air. Being off the ground near it is punished, which matters
# now the Monarch levitates from 1/7: flight is not a free win.
# (Stormcaller 25, Warden of Nails 70.)
const SKYFALL_RADIUS := 320.0
const SKYFALL_COOLDOWN := 3.0
var has_skyfall := false
var skyfall_ready_at := 0.0

# FALSE_TWIN -- it splits into copies and only ONE is real. The fakes hit back,
# so you can't just swing at everything. The tell: the real one casts a shadow.
# (Hollow Choir 35, Eclipse 99.)
const TWIN_COUNT := 2
const TWIN_HP_FRAC := 0.18        # a fake folds fast -- the cost is the time you spent
const TWIN_DMG_FRAC := 0.6        # but it hits hard enough that ignoring it is not free
const TWIN_RESPLIT := 9.0         # kill every fake and it just splits again
const TWIN_SPREAD := 260.0
var has_false_twin := false
var is_false_copy := false
var _twins: Array = []
var twin_ready_at := 0.0
var true_shadow: Polygon2D = null

# SOULBIND -- your blows FEED it while its rune adds live. Break the runes, then
# burst it in the window before it binds new ones. This one was sitting on three
# bosses as a NAME with nothing reading it -- the fights claimed it and the adds
# were just adds. (Weaver 20, Hollow Choir 35, Mourncaller 60.)
const SOULBIND_ADDS := 2
const SOULBIND_HEAL_FRAC := 0.5   # bound, half of every blow is turned into healing
const SOULBIND_REBIND := 10.0     # the burst window you earn by breaking the runes
var has_soulbind := false
var rune_adds: Array = []
var rune_links: Array = []
var soulbind_ready_at := 0.0
var _runes_were_lit := false

# COVENANT -- two bodies, one soul: they share an HP pool and heal each other
# unless both are pressured. (Twin Despair 75, Last Man 90.)
const COVENANT_HEAL := 14.0       # hp/sec the partner claws back if left alone
var has_covenant := false
var covenant_partner: Node = null

# --- phase (Obito) -----------------------------------------------------------
# The nastiest thing in the vocabulary, and the dev's own example. The instant
# your blade lands, the boss goes INTANGIBLE -- your hits pass clean through for
# PHASE_SECONDS and deal nothing. There is no damage number to beat; the hit
# simply does not connect. And it keeps attacking out of the ghost, so you can
# never trade: you have to bait the phase out and punish the solid frames.
#
# It is only fair because you can SEE it: while phased the body goes translucent
# and washes toward its magic colour. Hard because you misread the tell, never
# because it was hidden. (Design: BOSSES.md 5.)
const PHASE_SECONDS := 2.0
const PHASE_COOLDOWN := 4.5     # it cannot live permanently intangible
var has_phase := false
var phase_until := 0.0
var phase_ready_at := 0.0

func _time_now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- reactive mechanic behaviours --------------------------------------------

# Is the player close enough that this hit could only be melee? Projectiles are
# resolved at range, so distance is a good enough proxy without plumbing the
# damage source through every weapon.
func _player_is_meleeing() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) < MELEE_READ_RANGE
const MELEE_READ_RANGE := 150.0

# SIDESTEP: leave an afterimage where you were, and be a body-width away.
func _do_sidestep() -> void:
	var gfx: CanvasItem = boss_sprite if boss_sprite != null else self
	var ghost := Sprite2D.new()
	if boss_sprite != null and boss_sprite.sprite_frames != null:
		ghost.texture = boss_sprite.sprite_frames.get_frame_texture(boss_sprite.animation, boss_sprite.frame)
		ghost.centered = boss_sprite.centered
		ghost.offset = boss_sprite.offset
		ghost.scale = boss_sprite.scale
		ghost.flip_h = boss_sprite.flip_h
	ghost.modulate = Color(0.6, 0.7, 1.0, 0.55)
	ghost.z_index = 5
	get_parent().add_child(ghost)
	ghost.global_position = gfx.global_position
	var gt := ghost.create_tween()
	gt.tween_property(ghost, "modulate:a", 0.0, 0.3)
	gt.tween_callback(ghost.queue_free)
	# step AWAY from the player, along the ground
	var away := 1.0 if (player == null or global_position.x >= player.global_position.x) else -1.0
	var dist: float = float(current_def.get("body", Vector2(120, 200)).x) * 0.45
	global_position.x += away * dist

# RIPOSTE: it was waiting for you to swing at the wind-up.
func _do_riposte() -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 34.0)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.85, 0.3, 0.95)
	ring.z_index = 45
	add_child(ring)
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector2(1.9, 1.9), 0.2)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.2)
	t.tween_callback(ring.queue_free)
	player.take_damage(riposte_damage())
	if player.has_method("apply_slow"):
		player.apply_slow(0.8, 0.55)

# Scaled off the boss's own hit, so it stings without ever one-shotting.
func riposte_damage() -> int:
	return int(round(RIPOSTE_DAMAGE * sqrt(damage_multiplier)))

# RHYTHM PUNISH: the fourth identical beat in a row gets answered.
func _do_rhythm_counter() -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	player.take_damage(int(round(RHYTHM_DAMAGE * sqrt(damage_multiplier))))
	if player.has_method("apply_slow"):
		player.apply_slow(0.6, 0.6)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification("It has learned your rhythm.")

# DREAD WARD: is the player actually behind it? It faces the player by default,
# so "behind" means the player is on the side its back is turned to.
func _hit_from_behind() -> bool:
	if player == null or not is_instance_valid(player):
		return true          # nothing to flank: don't make it immortal
	var facing: float = -1.0 if (boss_sprite != null and boss_sprite.flip_h) else 1.0
	var to_player: float = signf(player.global_position.x - global_position.x)
	return to_player != 0.0 and to_player != facing

# --- ticked mechanics --------------------------------------------------------

# TETHER: chain them where they stand. It doesn't stop you moving -- it bills
# you for it, harder the further you drag. Break LOS/close in, or bleed.
func tick_tether(delta: float) -> void:
	if not has_tether or is_dead or player == null or not is_instance_valid(player):
		return
	if not tether_active:
		if _time_now() >= tether_next_at and global_position.distance_to(player.global_position) < TETHER_RANGE:
			tether_active = true
			tether_anchor = player.global_position
			tether_next_at = _time_now() + TETHER_RECAST
			_tether_line = Line2D.new()
			_tether_line.width = 2.0
			_tether_line.default_color = Color(0.5, 0.85, 1.0, 0.75)
			_tether_line.z_index = 20
			add_child(_tether_line)
		return
	var d: float = player.global_position.distance_to(tether_anchor)
	if d > TETHER_RANGE:
		_drop_tether()          # dragged it past breaking: it snaps, you're free
		return
	# ...or put something solid between you and it. The chain is a line of
	# sight, so the Gaoler's pillars are cover in the literal sense: duck behind
	# one and it cuts. Without this the arena's whole pillar forest would be
	# scenery and the only counter-play would be running, which the tether is
	# specifically designed to bill you for.
	if _sight_to_player_blocked():
		_drop_tether()
		return
	if _tether_line != null and is_instance_valid(_tether_line):
		_tether_line.points = PackedVector2Array([Vector2.ZERO, to_local(player.global_position)])
		_tether_line.default_color.a = 0.4 + 0.5 * clampf(d / TETHER_RANGE, 0.0, 1.0)
	# the bill ramps with how far you've pulled
	_tether_accum += delta * TETHER_DPS * (0.35 + 1.4 * clampf(d / TETHER_RANGE, 0.0, 1.0))
	if _tether_accum >= 1.0:
		var tick := int(_tether_accum)
		_tether_accum -= tick
		if player.has_method("take_damage"):
			player.take_damage(tick)

var _tether_accum := 0.0

# Is there cover between us? Tested against COVER_LAYER (bit 5) ALONE, never
# the ground layer: a raycast ignores one_way_collision, so sighting against
# layer 1 would have every ordinary drop-through ledge break the tether and the
# mechanic would fall apart on scenery.
const COVER_MASK := 16

func _sight_to_player_blocked() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, player.global_position, COVER_MASK)
	q.collide_with_areas = false
	return not space.intersect_ray(q).is_empty()

func _drop_tether() -> void:
	tether_active = false
	if _tether_line != null and is_instance_valid(_tether_line):
		_tether_line.queue_free()
	_tether_line = null

# FAMINE: standing near it costs MANA, not health. Your resources are the prize.
func tick_famine(delta: float) -> void:
	if not has_famine or is_dead or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > FAMINE_RADIUS:
		return
	if "mana" in player:
		player.mana = maxf(0.0, player.mana - FAMINE_DRAIN * delta)
		if player.has_method("update_mana_display"):
			player.update_mana_display()

# AFTERIMAGE_TRAP: mark where they STOOD, and burn it a beat later. Standing
# still is the mistake; the counter-play is simply to keep moving.
func tick_traps(delta: float) -> void:
	if not has_afterimage_trap or is_dead or player == null or not is_instance_valid(player):
		return
	if _time_now() < trap_next_at:
		return
	trap_next_at = _time_now() + TRAP_PERIOD
	_plant_trap(player.global_position)

func _plant_trap(at: Vector2) -> void:
	var mark := Node2D.new()
	get_parent().add_child(mark)
	mark.global_position = at
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a), sin(a)) * TRAP_RADIUS)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 2.0
	var m: Color = current_def.get("magic", Color(1, 0.5, 0.2))
	ring.default_color = Color(m.r, m.g, m.b, 0.85)
	mark.add_child(ring)
	# it TELLS you: the ring closes over TRAP_DELAY, then it goes off
	# The trap lives on `mark` in the scene, so it outlives the boss -- if he is
	# killed during TRAP_DELAY the callback must not touch his freed self (the
	# meteor-class bug). Re-resolve the caster by id and bail if he's gone or dead:
	# a slain boss springs no traps, and never reads state off a stale instance.
	var boss_id := get_instance_id()
	var t := mark.create_tween()
	t.tween_property(ring, "scale", Vector2(0.25, 0.25), TRAP_DELAY)
	t.tween_callback(func():
		var b = instance_from_id(boss_id)
		if is_instance_valid(b) and not b.is_dead and is_instance_valid(player) \
				and player.global_position.distance_to(at) <= TRAP_RADIUS \
				and player.has_method("take_damage"):
			player.take_damage(int(round(TRAP_DAMAGE * sqrt(b.damage_multiplier))))
		if is_instance_valid(mark):
			mark.queue_free())

# MIRROR: turn incoming shots around. Your own arrow is now the problem.
# Deliberately radius-based rather than on-hit: the shot must be SEEN to come
# back, so the player can watch it happen and learn to stop shooting.
const PLAYER_PROJECTILE_GROUPS = ["player_projectile"]   # arrow.gd + weapon_projectile.gd join this in _ready

func tick_mirror(delta: float) -> void:
	if not has_mirror or is_dead:
		return
	if _time_now() < mirror_ready_at:
		return
	for g in PLAYER_PROJECTILE_GROUPS:
		for pr in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(pr) or not (pr is Node2D):
				continue
			if global_position.distance_to(pr.global_position) > MIRROR_RADIUS:
				continue
			mirror_ready_at = _time_now() + MIRROR_COOLDOWN
			_reflect(pr)
			return

# FALSE TWIN: it wears its own face. The fakes carry the real kit, so swinging
# at everything burns the window you needed -- but they cannot split again and
# they cast no shadow. That absence is the whole puzzle.
func living_twins() -> int:
	_twins = _twins.filter(func(t): return is_instance_valid(t) and not (("is_dead" in t) and t.is_dead))
	return _twins.size()

func tick_false_twin(_delta: float) -> void:
	if not has_false_twin or is_dead or is_false_copy:
		return
	if living_twins() > 0:
		return
	if _time_now() < twin_ready_at:
		return
	_do_false_split()

func _do_false_split() -> void:
	twin_ready_at = _time_now() + TWIN_RESPLIT
	if true_shadow == null:
		_build_true_shadow()
	for i in range(TWIN_COUNT):
		var t = load("res://boss.tscn").instantiate()
		t.boss_id = boss_id
		t.is_false_copy = true
		t.level_hp_mult = level_hp_mult
		t.damage_multiplier = damage_multiplier
		t.speed_multiplier = speed_multiplier
		t.boss_floor = boss_floor
		t.position = global_position + Vector2(randf_range(-TWIN_SPREAD, TWIN_SPREAD), 0.0)
		t.add_to_group("dungeon_combatant")
		get_parent().add_child(t)
		_twins.append(t)
		minions.append(t)   # swept away when the real one dies
	spawn_shockwave(70.0, magic_color)

# The tell. Only the real one owns this.
func _build_true_shadow() -> void:
	var body: Vector2 = current_def.get("body", Vector2(160, 220))
	true_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * body.x * 0.42, sin(a) * 9.0))
	true_shadow.polygon = pts
	true_shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	true_shadow.position = Vector2(0, body.y * 0.5)
	true_shadow.z_index = -1
	add_child(true_shadow)

# SOULBIND: while its runes are lit, everything you land is FOOD. The fight is
# not a damage race -- it is "break the runes, THEN burst", and it rebinds.
func living_rune_adds() -> int:
	rune_adds = rune_adds.filter(func(a): return is_instance_valid(a) and not (("is_dead" in a) and a.is_dead))
	return rune_adds.size()

func tick_soulbind(_delta: float) -> void:
	if not has_soulbind or is_dead or is_false_copy:
		return
	if living_rune_adds() > 0:
		_runes_were_lit = true
		_update_rune_links()
		return
	if _runes_were_lit:
		# the runes just went out: this is the window the player bought
		_runes_were_lit = false
		soulbind_ready_at = _time_now() + SOULBIND_REBIND
		_clear_rune_links()
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack != null and stack.has_method("show_notification"):
			stack.show_notification("The runes go dark. Hit it NOW.")
		return
	if _time_now() >= soulbind_ready_at:
		_bind_runes()

func _bind_runes() -> void:
	_clear_rune_links()
	for i in range(SOULBIND_ADDS):
		var m = MINION_SCENE.instantiate()
		m.respawns = false
		m.instant_aggro = true
		m.wave_hp_multiplier = 0.5 * level_hp_mult
		m.wave_damage_multiplier = 0.5 * damage_multiplier
		m.wave_speed_multiplier = speed_multiplier
		m.position = global_position + Vector2(randf_range(-180.0, 180.0), -30.0)
		m.add_to_group("dungeon_combatant")
		get_parent().add_child(m)
		m.modulate = magic_color.lerp(Color.WHITE, 0.35)
		rune_adds.append(m)
		minions.append(m)
		var link := Line2D.new()
		link.width = 2.0
		link.default_color = Color(magic_color.r, magic_color.g, magic_color.b, 0.7)
		link.z_index = -2
		add_child(link)
		rune_links.append(link)
	_runes_were_lit = true
	spawn_shockwave(60.0, magic_color)

# the leash you have to cut, drawn so the mechanic is never invisible
func _update_rune_links() -> void:
	for i in range(rune_links.size()):
		var link = rune_links[i]
		if not is_instance_valid(link):
			continue
		if i >= rune_adds.size() or not is_instance_valid(rune_adds[i]):
			link.visible = false
			continue
		link.visible = true
		link.points = PackedVector2Array([Vector2.ZERO, to_local(rune_adds[i].global_position)])

func _clear_rune_links() -> void:
	for link in rune_links:
		if is_instance_valid(link):
			link.queue_free()
	rune_links.clear()

# it drinks the blow instead of taking it
func _spawn_soulbind_feed() -> void:
	var glow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	glow.polygon = pts
	glow.color = Color(magic_color.r, magic_color.g, magic_color.b, 0.7)
	glow.z_index = 30
	get_parent().add_child(glow)
	glow.global_position = global_position
	var t = glow.create_tween()
	t.tween_property(glow, "scale", Vector2(2.2, 2.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glow, "modulate:a", 0.0, 0.3)
	t.tween_callback(glow.queue_free)

func _reflect(pr: Node2D) -> void:
	# turn it around: flip whatever it uses to travel, and hand it to the player
	if "velocity" in pr:
		pr.velocity = -pr.velocity
	if "direction" in pr:
		pr.direction = -pr.direction
	if "dir" in pr:
		pr.dir = -pr.dir
	pr.rotation += PI
	# it belongs to the boss now
	for g in PLAYER_PROJECTILE_GROUPS:
		if pr.is_in_group(g):
			pr.remove_from_group(g)
	pr.add_to_group("hostile_projectile")
	if "owner_is_player" in pr:
		pr.owner_is_player = false
	var flash := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	pts.append(pts[0])
	flash.points = pts
	flash.width = 2.5
	flash.default_color = Color(0.85, 0.95, 1.0, 0.9)
	flash.z_index = 40
	get_parent().add_child(flash)
	flash.global_position = pr.global_position
	var t := flash.create_tween()
	t.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.18)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.18)
	t.tween_callback(flash.queue_free)

# SKYFALL: anti-air. Leave the ground near it and it drags you back down.
func tick_skyfall(delta: float) -> void:
	if not has_skyfall or is_dead or player == null or not is_instance_valid(player):
		return
	if _time_now() < skyfall_ready_at:
		return
	if global_position.distance_to(player.global_position) > SKYFALL_RADIUS:
		return
	# only bites if they're actually airborne
	if player.has_method("is_on_floor") and player.is_on_floor():
		return
	skyfall_ready_at = _time_now() + SKYFALL_COOLDOWN
	if player.has_method("take_damage"):
		player.take_damage(int(round(SKYFALL_DAMAGE * sqrt(damage_multiplier))))
	# slam them groundward -- flight is not a free win here
	if "velocity" in player:
		player.velocity.y = maxf(player.velocity.y, 520.0)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification("It will not let you leave the ground.")

# COVENANT: two bodies, one soul. Left alone, a partner claws its twin back up --
# so you cannot burn one down and rest. Split the damage or win nothing.
func tick_covenant(delta: float) -> void:
	if not has_covenant or is_dead:
		return
	if covenant_partner == null or not is_instance_valid(covenant_partner):
		return
	if covenant_partner.is_dead:
		return
	# if I haven't been hit recently, I spend that time healing my twin
	if _time_now() - _last_hurt_at < 2.0:
		return
	_covenant_accum += delta * COVENANT_HEAL
	if _covenant_accum >= 1.0:
		var heal := int(_covenant_accum)
		_covenant_accum -= heal
		covenant_partner.health = mini(covenant_partner.max_health, covenant_partner.health + heal)
		if covenant_partner.has_method("update_health_bar"):
			covenant_partner.update_health_bar()

var _covenant_accum := 0.0
var _last_hurt_at := 0.0

# STAGGER ARMOUR: a chip hit rings off the guard, and says so.
# Says WHY a blow did nothing. Each reason gets its own word, because they ask
# for different things from the player: GUARDED means hit harder, FLANK IT means
# get behind it, DODGED/PHASED/PARRIED mean wait for a real opening. A silent
# block just reads as a bug.
# --- THE SOUL SPLIT (GAME_BIBLE 9.5) ---
# "An undivided soul cannot be destroyed" -- so the Monarch of Despair (the
# L100 "wizard") cannot drop below 1 HP by ANY ordinary means: outside the
# window, the deathless thing simply reforms around the wound. The Soul Split
# Wand is the one exception: struck by it, his soul scatters into fragments for
# four seconds, and for those four seconds he is -- for the first and only
# time -- MORTAL. Everything else that gets hit by the wand just does the
# harmless disco-split joke.
const SOUL_SPLIT_WINDOW := 4.0
var soul_split_window_until := 0.0

func is_final_monarch() -> bool:
	return boss_id == "wizard" and not is_clone and not is_false_copy

func in_mortal_window() -> bool:
	return _time_now() < soul_split_window_until

func on_soul_split_wand() -> void:
	if is_dead:
		return
	if is_final_monarch():
		soul_split_window_until = _time_now() + SOUL_SPLIT_WINDOW
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -120),
			"HIS SOUL SCATTERS — STRIKE NOW!", Color(1.0, 0.9, 0.5))
		# the scattered soul cannot hold its guard together
		_guard_chip = 0.0
		phase_until = 0.0
		return
	# everyone else: the harmless joke -- 7 tiny spinning copies, then snap back
	FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -80), "...SPLIT?", Color(0.9, 0.8, 1.0))
	_spawn_split_joke()

func _spawn_split_joke() -> void:
	for i in range(7):
		var ghost := ColorRect.new()
		ghost.size = Vector2(24, 34)
		ghost.color = Color(current_def.get("color", Color(0.6, 0.6, 0.7)), 0.7)
		ghost.position = Vector2(-12, -60)
		add_child(ghost)
		var ang := TAU * float(i) / 7.0
		var t := ghost.create_tween()
		t.set_parallel(true)
		t.tween_property(ghost, "position", ghost.position + Vector2(cos(ang), sin(ang)) * 70.0, 0.4)
		t.tween_property(ghost, "rotation", TAU * 2.0, 3.2)
		t.set_parallel(false)
		t.tween_interval(3.2)
		t.tween_property(ghost, "position", Vector2(-12, -60), 0.4)
		t.tween_callback(ghost.queue_free)

# What counts as a "heavy" blow against stagger armour.
#
# This used to be a flat 6% of max_health, which quietly made the mechanic worse
# the deeper you went: max_health is multiplied by floor level, while a player's
# per-hit damage grows far slower. By floor 55 the Effigy demanded 478 damage in
# a SINGLE blow -- no weapon in the game swings that hard, so the guard could
# never be broken outright and the fight was a pure war of attrition against the
# chip meter.
#
# Measuring against the geometric mean of the boss's BASE hp and its scaled pool
# keeps the requirement growing with depth (a floor-55 boss should ask more than
# a floor-10 one) without compounding the level multiplier twice:
#
#   Frost Monarch  f10   110 -> 72
#   Gaoler         f45   391 -> 188
#   Effigy         f55   478 -> 224
func stagger_threshold() -> float:
	return STAGGER_HEAVY_FRACTION * sqrt(float(base_max_health) * float(max_health))

func _spawn_block_label(word: String, tint: Color = Color(0.72, 0.84, 1.0)) -> void:
	var body: Vector2 = current_def.get("body", Vector2(160, 220))
	FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -body.y * 0.5), word, tint)

func _spawn_guard_spark() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 5
	p.lifetime = 0.25
	p.direction = Vector2(0, -1)
	p.spread = 90.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.color = Color(0.85, 0.88, 1.0)
	p.z_index = 40
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func is_phased() -> bool:
	return _time_now() < phase_until

# A hit that passed through: say so, or the player just thinks the game ate the
# input. A pale ring at the point of contact, no number.
func _spawn_phase_whiff() -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * 26.0)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 2.5
	var m: Color = current_def.get("magic", Color(0.7, 0.7, 1.0))
	ring.default_color = Color(m.r, m.g, m.b, 0.8)
	ring.z_index = 40
	add_child(ring)
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector2(1.7, 1.7), 0.22)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	t.tween_callback(ring.queue_free)

# Drop back to solid the moment the window closes -- called every frame, cheap.
func tick_phase() -> void:
	if not has_phase:
		return
	var ghosted: bool = is_phased()
	if ghosted != _was_phased:
		_was_phased = ghosted
		_refresh_phase_visual()

var _was_phased := false

# Called the moment a hit lands on a phase boss (see take_damage).
func enter_phase() -> void:
	if not has_phase or is_dead or _time_now() < phase_ready_at:
		return
	phase_until = _time_now() + PHASE_SECONDS
	phase_ready_at = phase_until + PHASE_COOLDOWN
	_refresh_phase_visual()

func _refresh_phase_visual() -> void:
	var gfx: CanvasItem = boss_sprite if boss_sprite != null else self
	if is_phased():
		# ghosted, and washed toward its own magic colour so it reads as the
		# boss having stepped sideways out of the world rather than gone dim
		var m: Color = current_def.get("magic", Color(0.7, 0.7, 1.0))
		gfx.modulate = Color(m.r, m.g, m.b, 0.38)
	else:
		gfx.modulate = Color(1, 1, 1, 1)
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

# --- wizard combo state (real wizard only; see WIZARD_COMBOS / drive_wizard) ---
var in_combo := false
# starts >0 so the fight opens with a brief breather instead of an instant combo
var combo_recovery_timer := 1.5
var last_combo_index := -1

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
	has_phase = "phase" in passives
	has_sidestep = "sidestep" in passives
	has_riposte = "riposte" in passives
	has_skyfall = "skyfall" in passives
	has_mirror = "mirror" in passives
	has_rhythm_punish = "rhythm_punish" in passives
	has_stagger_armour = "stagger_armour" in passives
	has_tether = "tether" in passives
	has_famine = "famine" in passives
	has_afterimage_trap = "afterimage_trap" in passives
	has_dread_ward = "dread_ward" in passives
	has_false_twin = "false_twin" in passives
	has_soulbind = "soulbind" in passives
	has_covenant = "covenant" in passives
	profile = def.get("profile", "rusher")
	abilities = (def.get("abilities", ["slam"]) as Array).duplicate()
	base_max_health = int(def.get("hp", 900))   # pre-scaling, for stagger maths
	max_health = int(round(float(base_max_health) * level_hp_mult))
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

	# A FAKE of a false_twin boss. Deliberately NOT tinted: it has to look
	# exactly like the real thing, or the mechanic answers its own riddle. It
	# keeps the full kit so it fights back convincingly, but it cannot split
	# again, cannot inherit the ward-style passives (an unkillable fake would be
	# a wall, not a puzzle), and casts no shadow -- that absence IS the tell.
	if is_false_copy:
		has_false_twin = false
		max_health = max(1, int(round(max_health * TWIN_HP_FRAC)))
		health = max_health
		damage_multiplier *= TWIN_DMG_FRAC
		has_dread_ward = false
		has_stagger_armour = false
		has_covenant = false
		has_soulbind = false
		has_phase = false
		has_mirror = false

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

	# the hitbox + visual rig only exist on a scene-built boss; a headless boss
	# (created via .new() to exercise mechanics) has neither, so skip them cleanly
	if has_node("CollisionShape2D"):
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
	health_bar_w = bar_half * 2.0                 # a stat the mechanics still need
	var bar_y := -body.y / 2.0 - 34.0
	if has_node("HealthBarFill"):                 # bars only exist on a scene-built boss
		for bar in [$HealthBarBG, $HealthBarFill]:
			bar.offset_left = -bar_half
			bar.offset_right = bar_half
			bar.offset_top = bar_y
			bar.offset_bottom = bar_y + 12.0

	if has_aura:
		build_aura()
		_build_wizard_ground_aura()
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
	aura_particles.amount = 69          # 1.5x denser red crumble
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
	for i in range(15):                  # 1.5x the ember ring blocks
		var ang = i * TAU / 15.0 + randf_range(-0.2, 0.2)
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
	aura_particles2.amount = 48          # ~0.7x the red layer's 69 (1.5x denser)
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
	for i in range(11):                  # ~0.7x the red ring's 15 blocks (1.5x)
		var ang2 = i * TAU / 11.0 + randf_range(-0.2, 0.2)
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
			var red_total = 126 if is_frenzied else 69   # 1.5x aura density
			var pur_total = 89 if is_frenzied else 48
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
	boss_sprite = null
	var skin := str(current_def.get("sprite", ""))
	if skin != "" and EnemySkins.is_per_frame(skin, BOSS_ROOT):
		_build_boss_sprite(skin, body)
		return
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

# --- Skinned bosses (PixelLab) ---
# The sprite becomes the whole visible body; it's normalised so its measured
# content height fills body.y and its feet sit on the collision underside.
func _build_boss_sprite(skin: String, body: Vector2) -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(skin, BOSS_ROOT)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ch := EnemySkins.content_height(skin, BOSS_ROOT)
	var sc := (body.y * BOSS_FILL) / ch
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(-EnemySkins.hcenter_px(skin, BOSS_ROOT), (body.y / 2.0) / sc - EnemySkins.feet_px(skin, BOSS_ROOT))
	if spr.sprite_frames.has_animation("idle"):
		spr.play("idle")
	spr.animation_finished.connect(_on_boss_anim_finished)
	rig.add_child(spr)
	boss_sprite = spr

# Idle when still, walk when moving; attacks are triggered by start_attack and
# left to finish before walk/idle resumes.
func _update_boss_anim() -> void:
	if boss_sprite == null:
		return
	if boss_sprite.animation == "attack" and boss_sprite.is_playing():
		return
	# A FLYING boss has nothing under its feet, so it must not stride: the
	# Fallen Wizard was walking through open sky. Airborne bosses cruise on
	# their levitate clip instead, and fall back to walk if a skin hasn't drawn
	# one yet.
	var sf := boss_sprite.sprite_frames
	var want := "walk" if absf(velocity.x) > 8.0 else "idle"
	if flying and sf and sf.has_animation("levitate"):
		want = "levitate"
	if sf and sf.has_animation(want) and boss_sprite.animation != want:
		boss_sprite.play(want)

func _on_boss_anim_finished() -> void:
	if boss_sprite and boss_sprite.animation != "idle" and boss_sprite.sprite_frames.has_animation("idle"):
		boss_sprite.play("idle")

# Skinned bosses with bespoke POWER animations (the Fallen Wizard finale):
# each ability maps to its own clip when the skin ships one -- beam channels,
# meteors raise the staff skyward, curse/doomring/clone spread the arms wide,
# teleport swirls the cloak. Anything unmapped (or missing art) falls back to
# the generic "attack" clip, so partially-animated skins still read fine.
const BOSS_ABILITY_ANIMS := {
	"beam": "beam", "meteors": "summon", "rain": "summon",
	"curse": "curse", "doomring": "curse", "clone": "curse", "nova": "curse",
	"teleport": "teleport",
}

func _play_boss_ability_anim(ability: String) -> void:
	if boss_sprite == null:
		return
	var sf := boss_sprite.sprite_frames
	var want: String = BOSS_ABILITY_ANIMS.get(ability, "attack")
	if not sf.has_animation(want):
		want = "attack"
	if sf.has_animation(want):
		boss_sprite.play(want)

# The finale wizard's CONSTANT ground aura: a looping pillar of crumbling
# crimson-and-purple flame erupting from beneath his feet (PixelLab effect
# frames, art/bosses/<skin>/aura_N.png). Bottom-anchored on the collision
# underside so it always pours off his feet, drawn behind the body, with a
# slow breathing pulse so it feels alive. Self-guarding: no art, no aura.
var ground_aura: AnimatedSprite2D = null

func _build_wizard_ground_aura() -> void:
	var skin := str(current_def.get("sprite", ""))
	if skin == "" or not ResourceLoader.exists(BOSS_ROOT + skin + "/aura_1.png"):
		return
	var sf := SpriteFrames.new()
	sf.add_animation("burn")
	sf.set_animation_loop("burn", true)
	sf.set_animation_speed("burn", 10.0)
	var i := 1
	while true:
		var p := BOSS_ROOT + skin + "/aura_%d.png" % i
		if not ResourceLoader.exists(p):
			break
		sf.add_frame("burn", load(p))
		i += 1
	if sf.get_frame_count("burn") == 0:
		return
	var spr := AnimatedSprite2D.new()
	spr.name = "GroundAura"
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var body: Vector2 = current_def.get("body", Vector2(160, 220))
	var tex: Texture2D = sf.get_frame_texture("burn", 0)
	# span comfortably wider than the boss and pour upward from the feet
	var sc := (body.x * 2.6) / float(tex.get_width())
	spr.scale = Vector2(sc, sc)
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -float(tex.get_height()))
	spr.position = Vector2(0, body.y / 2.0)   # bottom pinned to his feet
	spr.modulate = Color(1.0, 0.55, 0.45, 0.9)
	add_child(spr)
	move_child(spr, rig.get_index())   # behind the body, above the world
	spr.play("burn")
	ground_aura = spr
	# slow breathing pulse -- the fire swells and settles forever
	var t := create_tween().set_loops()
	t.tween_property(spr, "scale", Vector2(sc * 1.12, sc * 1.06), 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(spr, "scale", Vector2(sc, sc), 1.1).set_trans(Tween.TRANS_SINE)

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

	tick_phase()   # drop back to solid when the ghost window closes
	tick_statuses(delta)   # burn/poison chip -- the DoT specs' anti-boss tool
	tick_tether(delta)
	tick_famine(delta)
	tick_traps(delta)
	tick_mirror(delta)
	tick_skyfall(delta)
	tick_covenant(delta)
	tick_false_twin(delta)
	tick_soulbind(delta)

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
	if climb_cd > 0:
		climb_cd -= delta
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
			if in_combo:
				# the combo coroutine owns the boss -- just float above the
				# player between casts so he keeps repositioning
				if flying:
					process_hover(delta)
				else:
					velocity.x = 0
			elif is_combo_boss():
				drive_wizard(delta)
			else:
				var chosen = choose_attack(dist)
				if chosen != "":
					start_attack(chosen)
				elif flying:
					process_hover(delta)
				elif wall_turn_timer > 0:
					velocity.x = -facing_direction * effective_speed()
				else:
					_drive_profile(dist, delta)
		check_bump()

	# creature rigs face the way the boss moves/aims
	if rig != null:
		rig.scale.x = facing_direction
	_update_boss_anim()

	move_and_slide()

	# hard containment: no boss ever ends a frame outside the arena walls
	var bw = arena_width()
	global_position.x = clampf(global_position.x, 70.0, bw - 70.0)

	process_passives(delta)

	if not flying and not is_wall_blocked and not is_charging:
		for i in range(get_slide_collision_count()):
			if absf(get_slide_collision(i).get_normal().x) > 0.5:
				# Grounded and off cooldown: HOP it, keeping the forward drive
				# (velocity.x already points at the player) so the boss clears
				# the pillar instead of retreating from it. Only fall back to
				# the old turn-away when it can't hop -- airborne, or a hop just
				# failed to clear (climb_cd still ticking = a wall too big, which
				# VAULT_HEIGHT should make impossible, but fail safe not stuck).
				if is_on_floor() and climb_cd <= 0.0:
					velocity.y = BOSS_CLIMB_VELOCITY
					climb_cd = BOSS_CLIMB_COOLDOWN
				else:
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
	var s = base_move_speed * speed_multiplier * boss_status_slow_mult()
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

# --- The Fallen Wizard's active combo brain (level 100 only) ---
# Only the REAL wizard runs combos; echoes keep the simple AI.
# Combo books for the OTHER apex bosses (the wizard keeps WIZARD_COMBOS). Only
# synchronous, await-completing abilities are used (NOT charge/dive, which
# finish later in process_charge/process_dive and would let a combo run ahead).
# DEPTH BUYS LENGTH. Dev: "as their level is higher, the longer the combos and
# disgusting." The chains below scale with the floor, and combo_length_for()
# enforces it so a shallow boss can never accidentally ship a 5-beat chain:
#   fl 5-30 -> 2 beats   (learn the verb)
#   fl 35-60 -> 3        (learn to read a sentence)
#   fl 65-90 -> 4        (no safe gap in it)
#   fl 95-100 -> 5+      (the gauntlet)
# Every boss also gets its OWN chains -- never a shared list -- because two
# bosses that open the same way are the same boss wearing a different colour.
const BOSS_COMBOS = {
	# --- the deep ---
	# Choir: fills the room, then makes you look away from the fakes. Its combos
	# always END on summon -- the adds are the point, the rest is pressure.
	"hollow_choir": [["dissonant_scream", "rain", "summon"], ["rain", "dissonant_scream", "summon"], ["nova", "summon", "rain"]],
	# Penitent: it barely moves, so everything it does is REACH. Pillars then
	# beam means the floor is taken before the line is drawn.
	"ashen_penitent": [["prayer_pyre", "beam", "nova"], ["beam", "prayer_pyre", "beam"], ["nova", "prayer_pyre", "beam"]],
	# Gaoler: chain you, then close. slam->charge is a shove into the tether.
	"gaoler": [["iron_maiden", "slam", "charge"], ["charge", "slam", "iron_maiden"], ["slam", "iron_maiden", "charge"]],
	# Sablefang: blink-in, bite, blink-out. Fast and rude; never stands still.
	"sablefang": [["teleport", "pounce", "volley"], ["pounce", "volley", "teleport"], ["volley", "teleport", "pounce"]],
	# Effigy: takes the floor, then drops the sky on it. Slow, enormous, patient.
	"effigy": [["splinter_burst", "slam", "meteors"], ["meteors", "splinter_burst", "slam"], ["slam", "meteors", "splinter_burst"]],
	# Mourncaller: mourners first, then grief from above. Never melees.
	"mourncaller": [["keening", "summon", "rain"], ["summon", "keening", "rain"], ["rain", "keening", "summon"]],
	# Unseen: it is never where the last thing came from. Curse -> blink -> spit.
	"unseen": [["curse", "teleport", "ambush"], ["ambush", "volley", "curse"], ["teleport", "curse", "ambush"]],
	# Warden: pins the sky, floors the ground, then swings. Nothing rushed.
	"warden_of_nails": [["barrage", "impale", "slam"], ["impale", "barrage", "slam"], ["slam", "barrage", "impale"]],
	# Twin Despair: split, blink, blow. You never know which one you're hitting.
	"twin_despair": [["clone", "teleport", "pincer_lunge"], ["teleport", "pincer_lunge", "clone"], ["pincer_lunge", "clone", "teleport"]],
	# Cinderking: sky, floor, blast, and then he's on top of you.
	"cinderking": [["meteors", "eruption", "charge"], ["charge", "meteors", "eruption"], ["eruption", "nova", "charge", "meteors"]],
	# Glass Saint: light, then more light. Everything at range comes back at you.
	"glass_saint": [["refraction", "nova", "volley"], ["volley", "refraction", "nova"], ["nova", "volley", "refraction"]],
	# Last Man: he fights like YOU do -- close, blink, punish, repeat.
	"last_man": [["charge", "riposte_stance", "teleport", "volley"], ["teleport", "charge", "riposte_stance", "nova"], ["volley", "teleport", "nova", "riposte_stance"]],
	# --- the finale gauntlet: the longest, nastiest sentences in the game ---
	"seraph": [["volley", "judgment", "rain"], ["judgment", "volley", "nova"], ["rain", "nova", "judgment"]],
	"leviathan": [["meteors", "tidal_crush", "vortex"], ["tidal_crush", "meteors", "vortex"], ["vortex", "tidal_crush", "meteors"]],
	"eclipse": [["beam", "black_sun", "meteors"], ["black_sun", "beam", "pillars"], ["meteors", "teleport", "black_sun"]],
}

# The floor this boss is being fought on decides how long its sentences run.
# Set by dungeon_interior alongside the scaling multipliers.
var boss_floor := 5

func combo_length_for(floor_lv: int) -> int:
	if floor_lv >= 95:
		return 5
	if floor_lv >= 65:
		return 4
	if floor_lv >= 35:
		return 3
	return 2

func is_wizard_boss() -> bool:
	return boss_id == "wizard" and not is_clone

# Any apex boss with a combo book runs the combo brain (the wizard uses its own
# WIZARD_COMBOS; the rest use BOSS_COMBOS). Clones never combo.
func is_combo_boss() -> bool:
	if is_clone:
		return false
	return boss_id == "wizard" or BOSS_COMBOS.has(boss_id)

func active_combos() -> Array:
	var base: Array = WIZARD_COMBOS if boss_id == "wizard" else BOSS_COMBOS.get(boss_id, [])
	if base.is_empty():
		return base
	# DEPTH BUYS LENGTH. The same boss met deeper says a longer sentence: its
	# chains are trimmed at shallow floors and EXTENDED at deep ones by looping
	# its own verbs back in, so a floor-90 fight has no safe gap to breathe in.
	# Nothing here touches damage -- only how long you're under it.
	var want: int = combo_length_for(boss_floor)
	var out: Array = []
	for c in base:
		var chain: Array = (c as Array).duplicate()
		if chain.size() > want:
			chain = chain.slice(0, want)
		else:
			var i := 0
			while chain.size() < want:
				chain.append(c[i % c.size()])   # loop its OWN verbs, never a foreign one
				i += 1
		out.append(chain)
	return out

# Called each idle frame for the wizard: either burn down the recovery window
# (a real opening for the player -- he hovers exposed and won't blink away) or
# kick off the next combo.
func drive_wizard(delta: float) -> void:
	if combo_recovery_timer > 0.0:
		combo_recovery_timer -= delta
		# a combo boss expresses its movement personality BETWEEN sentences
		if flying:
			process_hover(delta)
		elif player != null and is_instance_valid(player):
			_drive_profile(global_position.distance_to(player.global_position), delta)
		else:
			velocity.x = 0
		return
	run_combo()

# The movement personality. Sets velocity from the boss's `profile` so no two
# bosses cross the floor the same way. (See the profile vocabulary up top.)
func _drive_profile(dist: float, delta: float) -> void:
	var spd := effective_speed()
	var face := float(facing_direction)
	match profile:
		"kiter":
			if dist < KITE_RANGE - KITE_HYSTERESIS:
				velocity.x = -face * spd            # crowded: back off, keep shooting
			elif dist > KITE_RANGE + KITE_HYSTERESIS:
				velocity.x = face * spd             # too far: close some gap
			else:
				velocity.x = 0.0                    # in the pocket: hold
		"pursuer":
			# relentless -- the longer it chases, the faster it comes
			if dist > 130.0:
				_chase_ramp = minf(2.1, _chase_ramp + delta * 0.7)
			else:
				_chase_ramp = 1.0
			velocity.x = face * spd * _chase_ramp
		"pouncer":
			_move_timer -= delta
			if _move_phase > 0.0:                    # mid-pounce burst
				_move_phase -= delta
				velocity.x = face * spd * 2.3
			elif _move_timer <= 0.0:
				_move_timer = randf_range(1.2, 2.0)
				_move_phase = 0.28                   # start a new burst
			elif dist < POUNCE_HOLD_RANGE:
				velocity.x = -face * spd * 0.7       # too close between pounces: peel out
			else:
				velocity.x = 0.0
		"erratic":
			_move_timer -= delta
			if _move_timer <= 0.0:
				_move_timer = randf_range(0.22, 0.6)
				var r := randf()
				_move_dir = face if r < 0.6 else (-face if r < 0.82 else 0.0)  # feint/pause
			velocity.x = _move_dir * spd * 1.25
		"weave":
			_move_phase += delta * 4.5
			velocity.x = face * spd * lerpf(-0.4, 1.0, 0.5 + 0.5 * sin(_move_phase))
		"turtle":
			velocity.x = face * spd * 0.22           # it wants you to come to it
		"hopper":
			velocity.x = face * spd * 0.85
			_move_timer -= delta
			if _move_timer <= 0.0 and is_on_floor():
				_move_timer = randf_range(0.7, 1.15)
				velocity.y = -430.0                  # a hop toward you
		"mirror":
			# it moves only while YOU move -- it stalks your rhythm. Detected by
			# the player's POSITION change (robust to velocity being zeroed).
			var pmoving := false
			if player != null and is_instance_valid(player):
				if _move_dir != 0.0:   # _move_dir holds the last-seen player x here
					pmoving = absf(player.global_position.x - _move_dir) > 2.0
				_move_dir = player.global_position.x
			velocity.x = (face * spd) if pmoving else 0.0
		_:                                           # rusher / default
			velocity.x = face * spd

# Gaps between combo steps and the length of the punish window both tighten as
# he enrages (60% HP) and then frenzies (25% HP) -- the fight escalates.
func combo_step_gap() -> float:
	if is_frenzied:
		return 0.2
	if is_enraged:
		return 0.32
	return 0.45

func combo_recovery_time() -> float:
	if is_frenzied:
		return 1.5
	if is_enraged:
		return 2.0
	return 2.5

# Pick a combo, never the same one twice running so the skills keep changing.
func pick_combo_index() -> int:
	var n = active_combos().size()
	if n <= 1:
		return 0
	var idx = randi() % n
	if idx == last_combo_index:
		idx = (idx + 1) % n
	return idx

# Runs one full combo, then opens the recovery window. in_combo keeps
# _physics_process from starting anything else while this coroutine drives.
func run_combo() -> void:
	in_combo = true
	shake_camera(4.0, 0.2)   # a small "here it comes" cue
	last_combo_index = pick_combo_index()
	var steps: Array = active_combos()[last_combo_index]
	var gap = combo_step_gap()
	for step in steps:
		if is_dead or player == null or not is_instance_valid(player):
			break
		await run_ability(step)
		if is_dead:
			break
		await get_tree().create_timer(gap).timeout
	in_combo = false
	if not is_dead:
		combo_recovery_timer = combo_recovery_time()

# Fires one ability by name and waits for it to finish. Called straight (not via
# start_attack) so combos ignore per-ability cooldowns and just flow.
func run_ability(ability_name: String) -> void:
	_play_boss_ability_anim(ability_name)
	match ability_name:
		"teleport": await do_teleport()
		"volley": await do_volley()
		"curse": await do_curse()
		"meteors": await do_meteors()
		"beam": await do_beam()
		"doomring": await do_doomring()
		"clone": await do_clone()
		"rain": await do_rain()
		"nova": await do_nova()
		"pillars": await do_pillars()
		"vortex": await do_vortex()
		"summon": await do_summon()
		"grave_grasp": await do_grave_grasp()
		"rime_lance": await do_rime_lance()
		"magma_wake": await do_magma_wake()
		"web_snare": await do_web_snare()
		"thunderstrike": await do_thunderstrike()
		"void_rift": await do_void_rift()
		"dissonant_scream": await do_dissonant_scream()
		"prayer_pyre": await do_prayer_pyre()
		"iron_maiden": await do_iron_maiden()
		"pounce": await do_pounce()
		"splinter_burst": await do_splinter_burst()
		"keening": await do_keening()
		"ambush": await do_ambush()
		"impale": await do_impale()
		"pincer_lunge": await do_pincer_lunge()
		"eruption": await do_eruption()
		"refraction": await do_refraction()
		"riposte_stance": await do_riposte_stance()
		"judgment": await do_judgment()
		"tidal_crush": await do_tidal_crush()
		"black_sun": await do_black_sun()
		"unwriting": await do_unwriting()
		# slam/barrage self-complete like the rest; charge/dive finish over frames
		# in process_charge/process_dive, so their combo beats wait (capped) for the
		# sweep. Without these four cases, combo bosses silently dropped every
		# slam/charge/barrage/dive step to a no-op (e.g. the Gaoler only ever cast
		# iron_maiden) -- BOSS_COMBOS lists them, so they must actually fire.
		"slam": await do_slam()
		"barrage": await do_barrage()
		"charge": await _combo_charge()
		"dive": await _combo_dive()
		_: pass

# A combo beat that fires a frame-driven move, then holds the chain until the
# move finishes (process_charge/process_dive clears the flag), capped so a freed
# player mid-sweep can never hang the combo.
func _combo_charge() -> void:
	await do_charge()
	var g := 0
	while is_charging and not is_dead and g < 240:
		g += 1
		await get_tree().physics_frame
	is_charging = false

func _combo_dive() -> void:
	await do_dive()
	var g := 0
	while is_diving and not is_dead and g < 240:
		g += 1
		await get_tree().physics_frame
	is_diving = false

func start_attack(attack_name: String) -> void:
	is_busy = true
	velocity.x = 0
	_play_boss_ability_anim(attack_name)
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
		"grave_grasp": do_grave_grasp()
		"rime_lance": do_rime_lance()
		"magma_wake": do_magma_wake()
		"web_snare": do_web_snare()
		"thunderstrike": do_thunderstrike()
		"void_rift": do_void_rift()
		"dissonant_scream": do_dissonant_scream()
		"prayer_pyre": do_prayer_pyre()
		"iron_maiden": do_iron_maiden()
		"pounce": do_pounce()
		"splinter_burst": do_splinter_burst()
		"keening": do_keening()
		"ambush": do_ambush()
		"impale": do_impale()
		"pincer_lunge": do_pincer_lunge()
		"eruption": do_eruption()
		"refraction": do_refraction()
		"riposte_stance": do_riposte_stance()
		"judgment": do_judgment()
		"tidal_crush": do_tidal_crush()
		"black_sun": do_black_sun()
		"unwriting": do_unwriting()
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
		m *= CLONE_CD_PENALTY # echoes now cast a bit FASTER -> constant harassment
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
		# sqrt curve like every other boss attack: CURSE fires CURSE_ORBS at once,
		# and at the full floor-100 curve a point-blank faceful (4 x 74) was an
		# instant kill; sqrt keeps even all four (4 x 32 = 128) under a full bar.
		orb.setup(dir, int(round(CURSE_DAMAGE * sqrt(damage_multiplier))), Color(0.62, 0.35, 1.0), CURSE_ORB_SPEED)
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

# ===================== SIGNATURE ABILITIES (BOSSES.md §6) =====================

# A lingering hazard patch (magma/web/fire). The boss drops it and forgets it.
func spawn_hazard(pos: Vector2, radius: float, dmg: int, lifetime: float, color: Color, kind := "", dur := 1.0, mag := 0.0) -> void:
	var h = HAZARD_SCENE.new()
	h.radius = radius
	h.damage = dmg
	h.lifetime = lifetime
	h.color = color
	h.damage_multiplier = damage_multiplier
	h.on_kind = kind
	h.on_dur = dur
	h.on_mag = mag
	get_parent().add_child(h)
	h.global_position = pos

func _player_in(pos: Vector2, radius: float) -> bool:
	return player != null and is_instance_valid(player) and player.global_position.distance_to(pos) < radius

# GRAVEWARDEN 5 -- Grave Grasp: a hand erupts under you and ROOTS you. Punishes
# standing still (the mark lands where you ARE), then the slam/charge follows.
func do_grave_grasp() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("grave_grasp"); is_busy = false; return
	var spot: Vector2 = player.global_position
	spawn_ground_marker(spot, Color(0.35, 0.85, 0.4), GRASP_TELEGRAPH, GRASP_RADIUS * 2.0)
	await get_tree().create_timer(GRASP_TELEGRAPH).timeout
	if is_dead:
		return
	spawn_ring_telegraph(spot, GRASP_RADIUS, Color(0.3, 0.9, 0.4), 0.3)
	shake_camera(5.0, 0.2)
	if _player_in(spot, GRASP_RADIUS):
		deal_player_damage(GRASP_DAMAGE)
		if player.has_method("apply_root"):
			player.apply_root(GRASP_ROOT)
	set_cd("grave_grasp"); is_busy = false

# FROST MONARCH 10 -- Rime Lance: a marker TRACKS you, locks, then strikes and
# FREEZES. You can't just stand off; you have to break the lock at the last beat.
func do_rime_lance() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("rime_lance"); is_busy = false; return
	var marker := _zone_marker(player.global_position, RIME_RADIUS, Color(0.6, 0.85, 1.0, 0.28))
	var t := 0.0
	while t < RIME_TRACK and not is_dead and is_instance_valid(player):
		marker.global_position = player.global_position
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var lock: Vector2 = marker.global_position
	await get_tree().create_timer(RIME_TELEGRAPH).timeout
	if is_instance_valid(marker):
		marker.queue_free()
	if is_dead:
		return
	spawn_ring_telegraph(lock, RIME_RADIUS, Color(0.7, 0.9, 1.0), 0.25)
	if _player_in(lock, RIME_RADIUS):
		deal_player_damage(RIME_DAMAGE)
		if player.has_method("apply_freeze"):
			player.apply_freeze(RIME_FREEZE)
	set_cd("rime_lance"); is_busy = false

# CINDER COLOSSUS 15 -- Magma Wake: lays a line of lingering fire from itself
# toward you, so the lane you dodge into can already be burning.
func do_magma_wake() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("magma_wake"); is_busy = false; return
	flash_telegraph(Color(1.0, 0.4, 0.1))
	await get_tree().create_timer(0.35).timeout
	if is_dead:
		return
	var to_p: Vector2 = (player.global_position - global_position)
	var step: Vector2 = to_p / float(MAGMA_COUNT)
	for i in range(MAGMA_COUNT):
		var pos: Vector2 = global_position + step * float(i + 1)
		pos.y = global_position.y
		spawn_hazard(pos, MAGMA_RADIUS, MAGMA_DAMAGE, MAGMA_LIFETIME,
			Color(1.0, 0.45, 0.12, 0.5), "poison", 1.2, 5.0)   # burn = poison-type DoT
	shake_camera(5.0, 0.25)
	set_cd("magma_wake"); is_busy = false

# WEAVER 20 -- Web Snare: a sticky patch on your position that ROOTS you, so its
# adds and novas land while you're pinned. Get off it fast.
func do_web_snare() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("web_snare"); is_busy = false; return
	var spot: Vector2 = player.global_position
	spawn_ground_marker(spot, Color(0.9, 0.95, 0.7), WEB_TELEGRAPH, WEB_RADIUS * 2.0)
	await get_tree().create_timer(WEB_TELEGRAPH).timeout
	if is_dead:
		return
	# the web lingers and re-roots anyone standing in it
	spawn_hazard(spot, WEB_RADIUS, WEB_DAMAGE, WEB_LIFETIME,
		Color(0.85, 0.9, 0.75, 0.4), "root", 0.6)
	set_cd("web_snare"); is_busy = false

# STORMCALLER 25 -- Thunderstrike: telegraphed bolts drop on your CURRENT spot a
# beat later and STUN. Punishes standing; keep moving through the tells.
func do_thunderstrike() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("thunderstrike"); is_busy = false; return
	var spots: Array = []
	for i in range(THUNDER_BOLTS):
		var s: Vector2 = player.global_position + Vector2(randf_range(-40.0, 40.0) * i, 0)
		spots.append(s)
		spawn_ground_marker(s, Color(1.0, 1.0, 0.6), THUNDER_TELEGRAPH, THUNDER_RADIUS * 2.0)
	await get_tree().create_timer(THUNDER_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.2)
	for s in spots:
		spawn_ring_telegraph(s, THUNDER_RADIUS, Color(1.0, 1.0, 0.7), 0.22)
		if _player_in(s, THUNDER_RADIUS):
			deal_player_damage(THUNDER_DAMAGE)
			if player.has_method("apply_stun"):
				player.apply_stun(THUNDER_STUN)
	set_cd("thunderstrike"); is_busy = false

# VOID SOVEREIGN 30 -- Void Rift: opens a singularity that DRAGS you toward it
# while it hits, so you fight its pull as well as its blinks.
func do_void_rift() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("void_rift"); is_busy = false; return
	# open it a short, fixed distance to the player's side, not on top of them
	var side: float = signf(player.global_position.x - global_position.x)
	if side == 0.0:
		side = 1.0
	var center: Vector2 = player.global_position + Vector2(side * 220.0, 0)
	var marker := _zone_marker(center, RIFT_RADIUS, Color(0.55, 0.25, 0.75, 0.32))
	spawn_ring_telegraph(center, RIFT_RADIUS, Color(0.7, 0.3, 1.0), RIFT_TELEGRAPH)
	await get_tree().create_timer(RIFT_TELEGRAPH).timeout
	var t := 0.0
	var dmg_acc := 0.0
	while t < RIFT_DURATION and not is_dead and is_instance_valid(player):
		if player.has_method("apply_pull"):
			player.apply_pull(center.x, RIFT_PULL)
		dmg_acc += get_physics_process_delta_time()
		if dmg_acc >= 0.4:
			dmg_acc -= 0.4
			if _player_in(center, RIFT_RADIUS):
				deal_player_damage(RIFT_DAMAGE)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if is_instance_valid(marker):
		marker.queue_free()
	set_cd("void_rift"); is_busy = false

# HOLLOW CHOIR 35 -- Dissonant Scream: a frontal cone of sound that DISORIENTS
# (your controls invert), so the fakes and adds land while you're turned around.
func do_dissonant_scream() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("dissonant_scream"); is_busy = false; return
	var face: float = -1.0 if (boss_sprite != null and boss_sprite.flip_h) else 1.0
	if player != null:
		face = signf(player.global_position.x - global_position.x)
		if face == 0.0:
			face = 1.0
	flash_telegraph(Color(0.75, 0.9, 0.65))
	# a cone telegraph fanning out toward the player's side
	_spawn_cone(face, SCREAM_RANGE, Color(0.8, 0.95, 0.6, 0.22), SCREAM_TELEGRAPH)
	await get_tree().create_timer(SCREAM_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.25)
	if player != null and is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		var dy: float = absf(player.global_position.y - global_position.y)
		if signf(dx) == face and absf(dx) < SCREAM_RANGE and dy < 200.0:
			deal_player_damage(SCREAM_DAMAGE)
			if player.has_method("apply_disorient"):
				player.apply_disorient(SCREAM_DISORIENT)
	set_cd("dissonant_scream"); is_busy = false

# ASHEN PENITENT 40 -- Prayer Pyre: a ring of fire EXPANDS out from it in pulses,
# forcing you to range (it barely moves, so it makes the near ground lethal).
func do_prayer_pyre() -> void:
	flash_telegraph(Color(1.0, 0.55, 0.15))
	for i in range(PYRE_STEPS):
		if is_dead:
			return
		var r: float = PYRE_MAX_RADIUS * float(i + 1) / float(PYRE_STEPS)
		spawn_ring_telegraph(global_position, r, Color(1.0, 0.5, 0.12), PYRE_STEP_TIME)
		await get_tree().create_timer(PYRE_STEP_TIME).timeout
		if is_dead:
			return
		# the flame FRONT: hits if you're in the expanding band (stay ahead of it)
		if player != null and is_instance_valid(player):
			var d: float = player.global_position.distance_to(global_position)
			if d < r and d > r - 110.0:
				deal_player_damage(PYRE_DAMAGE)
				if player.has_method("apply_poison"):
					player.apply_poison(1.2, 4.0)
	set_cd("prayer_pyre"); is_busy = false

# GAOLER 45 -- Iron Maiden: a spiked cage slams down on your spot -- heavy hit
# and a brief cage-ROOT. Punishes standing; the mark lands where you ARE.
func do_iron_maiden() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("iron_maiden"); is_busy = false; return
	var spot: Vector2 = player.global_position
	spawn_ground_marker(spot, Color(0.5, 0.8, 1.0), MAIDEN_TELEGRAPH, MAIDEN_RADIUS * 2.0)
	await get_tree().create_timer(MAIDEN_TELEGRAPH).timeout
	if is_dead:
		return
	spawn_ring_telegraph(spot, MAIDEN_RADIUS, Color(0.5, 0.8, 1.0), 0.3)
	shake_camera(8.0, 0.3)
	if _player_in(spot, MAIDEN_RADIUS):
		deal_player_damage(MAIDEN_DAMAGE)
		if player.has_method("apply_root"):
			player.apply_root(MAIDEN_ROOT)
	set_cd("iron_maiden"); is_busy = false

# SABLEFANG 50 -- Pounce: it LEAPS the gap to where you are and bites. Fast, and
# it commits -- dodge on the landing frame. (Position-leap; velocity is pinned so
# the boss's own move_and_slide doesn't fight it.)
func do_pounce() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("pounce"); is_busy = false; return
	flash_telegraph(Color(0.8, 0.7, 1.0))
	var target: Vector2 = player.global_position
	await get_tree().create_timer(POUNCE_TELEGRAPH).timeout
	if is_dead:
		return
	var start: Vector2 = global_position
	var landing := Vector2(target.x, start.y)
	var t := 0.0
	var hit := false
	while t < POUNCE_TIME and not is_dead:
		velocity = Vector2.ZERO
		var f: float = t / POUNCE_TIME
		var arc: float = sin(f * PI) * 70.0
		global_position = Vector2(lerpf(start.x, landing.x, f), start.y - arc)
		if not hit and _player_in(global_position, POUNCE_HIT_RADIUS):
			hit = true
			deal_player_damage(POUNCE_DAMAGE)
			knockback_player_away(180.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	velocity = Vector2.ZERO
	set_cd("pounce"); is_busy = false

# EFFIGY 55 -- Splinter Burst: sheds a ring of burning splinters that blow
# OUTWARD a beat later, leaving embers where they land.
func do_splinter_burst() -> void:
	flash_telegraph(Color(1.0, 0.6, 0.15))
	spawn_ring_telegraph(global_position, 130.0, Color(1.0, 0.6, 0.15), SPLINTER_TELEGRAPH)
	await get_tree().create_timer(SPLINTER_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.25)
	for i in range(SPLINTER_COUNT):
		var ang: float = i * TAU / SPLINTER_COUNT
		var dir := Vector2.RIGHT.rotated(ang)
		spawn_arrow(global_position + dir * 44.0, dir, SPLINTER_DAMAGE, SPLINTER_RANGE)
	# a few embers linger on the ground around it
	for s in [-1.0, 1.0]:
		spawn_hazard(global_position + Vector2(s * 130.0, 0), 60.0, 8, 2.6,
			Color(1.0, 0.5, 0.12, 0.5), "poison", 1.0, 4.0)
	set_cd("splinter_burst"); is_busy = false

# MOURNCALLER 60 -- Keening: releases a swarm of slow HOMING sorrow-wisps you
# have to outmaneuver, not outrun. It never melees; this is its reach.
func do_keening() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("keening"); is_busy = false; return
	flash_telegraph(Color(0.6, 0.75, 1.0))
	await get_tree().create_timer(0.4).timeout
	if is_dead:
		return
	for i in range(KEENING_COUNT):
		var b = HOMING_SCENE.new()
		b.damage = KEENING_DAMAGE
		b.damage_multiplier = damage_multiplier
		b.dir = Vector2.RIGHT.rotated(randf() * TAU)
		get_parent().add_child(b)
		b.global_position = global_position + b.dir * 30.0
	set_cd("keening"); is_busy = false

# UNSEEN 65 -- Ambush: it blinks out and reappears right BEHIND you, striking
# and briefly STUNNING. It is never where the last thing came from.
func do_ambush() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("ambush"); is_busy = false; return
	spawn_ring_telegraph(global_position, 70.0, Color(0.75, 0.2, 0.95), AMBUSH_VANISH)
	await get_tree().create_timer(AMBUSH_VANISH).timeout
	if is_dead:
		return
	# reappear on its own approach side, close behind the player
	var side: float = signf(global_position.x - player.global_position.x)
	if side == 0.0:
		side = 1.0
	global_position = player.global_position + Vector2(side * 80.0, 0)
	if boss_sprite != null:
		boss_sprite.flip_h = side > 0.0
	spawn_ring_telegraph(global_position, AMBUSH_RADIUS, Color(0.8, 0.3, 1.0), AMBUSH_STRIKE)
	await get_tree().create_timer(AMBUSH_STRIKE).timeout
	if is_dead:
		return
	if _player_in(player.global_position, AMBUSH_RADIUS):
		deal_player_damage(AMBUSH_DAMAGE)
		if player.has_method("apply_stun"):
			player.apply_stun(AMBUSH_STUN)
	set_cd("ambush"); is_busy = false

# WARDEN OF NAILS 70 -- Impale: a giant nail TRACKS you overhead, then drops.
# Synergy with the low ceiling + skyfall: leaving the ground is already death.
func do_impale() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("impale"); is_busy = false; return
	var marker := _zone_marker(player.global_position, IMPALE_RADIUS, Color(0.9, 0.85, 0.4, 0.28))
	var t := 0.0
	while t < IMPALE_TRACK and not is_dead and is_instance_valid(player):
		marker.global_position = player.global_position
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var lock: Vector2 = marker.global_position
	await get_tree().create_timer(IMPALE_TELEGRAPH).timeout
	if is_instance_valid(marker):
		marker.queue_free()
	if is_dead:
		return
	spawn_ring_telegraph(lock, IMPALE_RADIUS, Color(0.95, 0.9, 0.45), 0.25)
	shake_camera(7.0, 0.25)
	if _player_in(lock, IMPALE_RADIUS):
		deal_player_damage(IMPALE_DAMAGE)
		knockback_player_away(160.0)
	set_cd("impale"); is_busy = false

# TWIN DESPAIR 75 -- Pincer Lunge: it leaps THROUGH you to the far side, hitting
# on the pass. With its covenant twin also lunging, you are caught between them.
func do_pincer_lunge() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("pincer_lunge"); is_busy = false; return
	flash_telegraph(Color(0.7, 0.3, 1.0))
	var side: float = signf(player.global_position.x - global_position.x)
	if side == 0.0:
		side = 1.0
	var through_x: float = player.global_position.x + side * 210.0
	await get_tree().create_timer(PINCER_TELEGRAPH).timeout
	if is_dead:
		return
	var start: Vector2 = global_position
	var t := 0.0
	var hit := false
	while t < PINCER_TIME and not is_dead:
		velocity = Vector2.ZERO
		var f: float = t / PINCER_TIME
		global_position = Vector2(lerpf(start.x, through_x, f), start.y)
		if not hit and _player_in(global_position, PINCER_HIT_RADIUS):
			hit = true
			deal_player_damage(PINCER_DAMAGE)
			knockback_player_away(140.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	velocity = Vector2.ZERO
	set_cd("pincer_lunge"); is_busy = false

# CINDERKING 80 -- Eruption: cracks race outward across the floor and gout fire.
# It only catches you if you're GROUNDED when the crack reaches your spot -- jump
# the wave as it passes.
func do_eruption() -> void:
	flash_telegraph(Color(1.0, 0.4, 0.05))
	var fy: float = global_position.y
	for step in range(ERUPT_STEPS):
		if is_dead:
			return
		var offs := ERUPT_SPACING * float(step + 1)
		for s in [-1.0, 1.0]:
			spawn_ground_marker(Vector2(global_position.x + s * offs, fy), Color(1.0, 0.45, 0.1),
				ERUPT_STEP_TIME, ERUPT_BAND * 2.0)
		await get_tree().create_timer(ERUPT_STEP_TIME).timeout
		if is_dead:
			return
		for s in [-1.0, 1.0]:
			var ex: float = global_position.x + s * offs
			spawn_ring_telegraph(Vector2(ex, fy), 52.0, Color(1.0, 0.5, 0.12), 0.16)
			if player != null and is_instance_valid(player):
				var grounded: bool = player.is_on_floor() if player.has_method("is_on_floor") else true
				if absf(player.global_position.x - ex) < ERUPT_BAND and grounded:
					deal_player_damage(ERUPT_DAMAGE)
	set_cd("eruption"); is_busy = false

# GLASS SAINT 85 -- Refraction: its light splits into several angled beams that
# fan across you. Synergy with mirror -- everything at range comes back at you.
func do_refraction() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("refraction"); is_busy = false; return
	var base: float = (player.global_position - global_position).angle()
	var dirs: Array = []
	for i in range(REFRACT_BEAMS):
		var off: float = (i - (REFRACT_BEAMS - 1) / 2.0) * REFRACT_SPREAD
		dirs.append(Vector2.RIGHT.rotated(base + off))
	for d in dirs:
		_spawn_beam_line(global_position, d, REFRACT_LENGTH, Color(0.8, 0.95, 1.0, 0.25), REFRACT_TELEGRAPH)
	await get_tree().create_timer(REFRACT_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(6.0, 0.2)
	var struck := false
	for d in dirs:
		_spawn_beam_line(global_position, d, REFRACT_LENGTH, Color(0.9, 0.98, 1.0, 0.85), 0.22)
		if not struck and player != null and is_instance_valid(player):
			if _point_near_ray(global_position, d, REFRACT_LENGTH, player.global_position, REFRACT_WIDTH):
				struck = true
				deal_player_damage(REFRACT_DAMAGE)
	set_cd("refraction"); is_busy = false

# LAST MAN 90 -- Riposte Stance: it takes a guard. Hit it during the stance and
# it PARRIES the blow (no damage) and counters hard -- it fights like you do.
# (The parry is consumed in take_damage; see the gate there.)
func do_riposte_stance() -> void:
	flash_telegraph(Color(0.9, 0.9, 1.0))
	parry_until = _time_now() + STANCE_DURATION
	_parry_consumed = false
	spawn_ring_telegraph(global_position, 90.0, Color(0.85, 0.9, 1.0), STANCE_DURATION)
	await get_tree().create_timer(STANCE_DURATION).timeout
	parry_until = 0.0
	set_cd("riposte_stance"); is_busy = false

func _do_parry_counter() -> void:
	spawn_ring_telegraph(global_position, 110.0, Color(1.0, 0.95, 0.8), 0.3)
	shake_camera(8.0, 0.25)
	deal_player_damage(STANCE_COUNTER_DAMAGE)
	if player != null and is_instance_valid(player) and player.has_method("apply_stun"):
		player.apply_stun(STANCE_COUNTER_STUN)

# SERAPHIEL 95 -- Judgment: a full-height wall of light SWEEPS across the arena.
# There is no jumping it; you move sideways and stay off its line.
func do_judgment() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("judgment"); is_busy = false; return
	flash_telegraph(Color(1.0, 0.95, 0.6))
	var dir: float = signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	var x: float = global_position.x - dir * JUDGMENT_SPAN * 0.5
	var end_x: float = global_position.x + dir * JUDGMENT_SPAN * 0.5
	var bar := _make_wall(Color(1.0, 0.97, 0.7, 0.5), 1200.0)
	await get_tree().create_timer(JUDGMENT_TELEGRAPH).timeout
	var last_hit := -1.0
	while (dir > 0.0 and x < end_x) or (dir < 0.0 and x > end_x):
		if is_dead:
			break
		x += dir * JUDGMENT_SPEED * get_physics_process_delta_time()
		bar.global_position = Vector2(x, global_position.y)
		if player != null and is_instance_valid(player) and absf(player.global_position.x - x) < JUDGMENT_BAND:
			if _time_now() - last_hit > 0.5:
				last_hit = _time_now()
				deal_player_damage(JUDGMENT_DAMAGE)
		await get_tree().physics_frame
	if is_instance_valid(bar):
		bar.queue_free()
	set_cd("judgment"); is_busy = false

# LEVIATHAN 98 -- Tidal Crush: a low wave sweeps the floor. Get to HIGH GROUND
# (a platform, or airborne) -- it only catches you near the floor line.
func do_tidal_crush() -> void:
	if player == null or not is_instance_valid(player):
		set_cd("tidal_crush"); is_busy = false; return
	flash_telegraph(Color(0.3, 0.85, 0.9))
	var floor_y: float = global_position.y + 40.0
	var dir: float = signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	var x: float = global_position.x - dir * TIDAL_SPAN * 0.5
	var end_x: float = global_position.x + dir * TIDAL_SPAN * 0.5
	var wave := _make_wall(Color(0.3, 0.8, 0.95, 0.5), 200.0)
	await get_tree().create_timer(TIDAL_TELEGRAPH).timeout
	var last_hit := -1.0
	while (dir > 0.0 and x < end_x) or (dir < 0.0 and x > end_x):
		if is_dead:
			break
		x += dir * TIDAL_SPEED * get_physics_process_delta_time()
		wave.global_position = Vector2(x, floor_y)
		if player != null and is_instance_valid(player) and absf(player.global_position.x - x) < TIDAL_BAND:
			if player.global_position.y > floor_y - TIDAL_LOW and _time_now() - last_hit > 0.5:
				last_hit = _time_now()
				deal_player_damage(TIDAL_DAMAGE)
				knockback_player_away(150.0)
		await get_tree().physics_frame
	if is_instance_valid(wave):
		wave.queue_free()
	set_cd("tidal_crush"); is_busy = false

# ECLIPSE 99 -- Black Sun: the light DIES. The only safe ground is a ring around
# the Titan that SHRINKS -- you must close in on it to stay lit, or the dark bites.
func do_black_sun() -> void:
	flash_telegraph(Color(0.2, 0.05, 0.1))
	for i in range(SUN_STEPS):
		if is_dead:
			return
		var r: float = lerpf(SUN_START_RADIUS, SUN_END_RADIUS, float(i) / float(SUN_STEPS - 1))
		spawn_ring_telegraph(global_position, r, Color(1.0, 0.7, 0.3), SUN_STEP_TIME)
		await get_tree().create_timer(SUN_STEP_TIME).timeout
		if is_dead:
			return
		# outside the shrinking light = the dark takes a bite
		if player != null and is_instance_valid(player):
			if player.global_position.distance_to(global_position) > r:
				deal_player_damage(SUN_DAMAGE)
				if player.has_method("apply_slow"):
					player.apply_slow(0.8, 0.6)
	set_cd("black_sun"); is_busy = false

# FALLEN WIZARD 100 -- Unwriting: reality comes apart. Void tears open across the
# arena -- one right under you -- erasing safe ground for a moment. The culmination.
func do_unwriting() -> void:
	flash_telegraph(Color(0.5, 0.2, 0.7))
	var spots: Array = []
	if player != null and is_instance_valid(player):
		spots.append(player.global_position)           # one always opens under you
	for i in range(UNWRITE_ZONES - spots.size()):
		spots.append(global_position + Vector2(randf_range(-700.0, 700.0), randf_range(-120.0, 40.0)))
	for s in spots:
		spawn_ground_marker(s, Color(0.55, 0.25, 0.75), UNWRITE_TELEGRAPH, UNWRITE_RADIUS * 2.0)
	await get_tree().create_timer(UNWRITE_TELEGRAPH).timeout
	if is_dead:
		return
	shake_camera(9.0, 0.4)
	for s in spots:
		spawn_hazard(s, UNWRITE_RADIUS, UNWRITE_DAMAGE, UNWRITE_LIFETIME,
			Color(0.35, 0.1, 0.5, 0.55), "slow", 1.0, 0.55)
		spawn_ring_telegraph(s, UNWRITE_RADIUS, Color(0.6, 0.3, 0.9), 0.35)
	set_cd("unwriting"); is_busy = false

# a tall/wide sweeping wall visual owned by the caller
func _make_wall(color: Color, height: float) -> Polygon2D:
	var w := Polygon2D.new()
	w.polygon = PackedVector2Array([
		Vector2(-14, -height * 0.5), Vector2(14, -height * 0.5),
		Vector2(14, height * 0.5), Vector2(-14, height * 0.5)])
	w.color = color
	w.z_index = 6
	get_parent().add_child(w)
	return w

# point-to-ray-segment distance test (for beam lines)
func _point_near_ray(origin: Vector2, dir: Vector2, length: float, point: Vector2, width: float) -> bool:
	var to_pt: Vector2 = point - origin
	var proj: float = to_pt.dot(dir)
	if proj < 0.0 or proj > length:
		return false
	var closest: Vector2 = origin + dir * proj
	return closest.distance_to(point) < width

func _spawn_beam_line(origin: Vector2, dir: Vector2, length: float, color: Color, duration: float) -> void:
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = color
	line.points = PackedVector2Array([Vector2.ZERO, dir * length])
	line.z_index = 6
	get_parent().add_child(line)
	line.global_position = origin
	var t = line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, duration)
	t.tween_callback(line.queue_free)

# a triangular cone telegraph fanning from the boss along a horizontal facing
func _spawn_cone(face: float, length: float, color: Color, duration: float) -> void:
	var cone := Polygon2D.new()
	cone.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(face * length, -length * 0.5),
		Vector2(face * length, length * 0.5)])
	cone.color = color
	cone.z_index = 5
	get_parent().add_child(cone)
	cone.global_position = global_position
	var t = cone.create_tween()
	t.tween_property(cone, "modulate:a", 0.0, duration)
	t.tween_callback(cone.queue_free)

# a translucent octagon marker the CALLER owns (moves/frees it); for tracking
# and channelled signatures. Self-freeing flashes use spawn_ring_telegraph.
func _zone_marker(pos: Vector2, radius: float, color: Color) -> Polygon2D:
	var m := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * radius)
	m.polygon = pts
	m.color = color
	m.z_index = 5
	get_parent().add_child(m)
	m.global_position = pos
	return m

# --- ability helpers ---

func spawn_arrow(pos: Vector2, dir: Vector2, dmg: int, rng: float) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = pos
	# sqrt(damage_multiplier), same hard line as deal_player_damage: this helper
	# fires SEVEN abilities (barrage/nova/rain/volley/meteor/doomring/splinter) and
	# most rain SEVERAL projectiles at once. At the full floor-100 curve two meteors
	# (2x106) or a point-blank volley one-shot through 160 HP; sqrt keeps a whole
	# salvo survivable (2 meteors = 138) while still stinging.
	arrow.setup(dir.normalized(), int(round(dmg * sqrt(damage_multiplier))), 15.0, 30.0, 2, true, rng)
	get_parent().add_child(arrow)

func deal_player_damage(amount: int) -> void:
	# EVERY boss attack scales by sqrt(damage_multiplier), NOT the full multiplier
	# -- the dev's hard line (see the SIDESTEP/RIPOSTE note: "scaled by the SAME
	# sqrt the rest of the fight uses -- a counter must sting, never one-shot").
	# The punish passives applied sqrt inline and were safe, but the ~24 ORDINARY
	# attacks all route through here, and this multiplied by the FULL curve. At the
	# floor-100 curve (x5.3) that doubled every hit: BEAM one-shot from floor 55
	# (167 > 160 HP) up to 201, SLAM reached 159. sqrt brings them back to the
	# documented band (BEAM 80/87, SLAM 63/69) -- stings hard, never one-shots.
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(int(round(amount * sqrt(damage_multiplier))))

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

# PETRIFY (Gorgon's Gaze relic, WEAPONS.md §6). The apex / undying bosses shrug
# it off -- that is the "works on some bosses and not others." The rest can be
# stoned: routed through the stun that roots them and locks their attacks.
# Returns whether it LANDED, so the relic can report "immune".
func apply_petrify(dur: float) -> bool:
	if is_apex or is_dead:
		return false
	stun_timer = maxf(stun_timer, dur)
	return true

func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	# RIPOSTE STANCE (Last Man 90 signature): while its guard is up, the first
	# blow is PARRIED -- no damage -- and answered with a hard counter + stun.
	# Highest priority: it fights like you, and it was waiting for that swing.
	if _time_now() < parry_until and not _parry_consumed:
		_parry_consumed = true
		parry_until = 0.0
		_do_parry_counter()
		_spawn_block_label("PARRIED!", Color(1.0, 0.85, 0.45))
		return false
	# PHASE (Obito): while intangible the blow passes clean through. Not reduced,
	# not guarded -- it does not land at all, so there is nothing to out-damage.
	if is_phased():
		_spawn_phase_whiff()
		_spawn_block_label("PHASED", Color(0.72, 0.55, 1.0))
		return false
	# SIDESTEP: it reads the swing and isn't there any more. Melee only -- you
	# can't dodge what's already in the air.
	if has_sidestep and _time_now() >= sidestep_ready_at and _player_is_meleeing():
		sidestep_ready_at = _time_now() + SIDESTEP_COOLDOWN
		_do_sidestep()
		_spawn_block_label("DODGED", Color(0.8, 0.85, 0.9))
		return false
	# STAGGER ARMOUR: chip damage rings off the guard. A heavy blow breaks it
	# outright -- but light hits are no longer simply deleted. They pack into the
	# guard, and once they add up to what a heavy blow would have been, the guard
	# cracks and THAT hit lands. Without this a fast weapon could never hurt a
	# stagger boss at all: the threshold is a share of the boss's MAX HP, which
	# grows with floor level while a dagger's damage does not, so past a certain
	# depth those bosses were literally immortal to half the roster.
	if has_stagger_armour and float(amount) < stagger_threshold():
		_guard_chip += amount
		if _guard_chip < stagger_threshold():
			_spawn_guard_spark()
			_spawn_block_label("GUARDED", Color(0.72, 0.84, 1.0))
			return false
		_guard_chip = 0.0     # packed in enough -- the guard cracks on this blow
	# DREAD WARD: it can only be hurt from BEHIND. Standing in front of it and
	# holding attack does nothing at all -- it has to be flanked.
	if has_dread_ward and not _hit_from_behind():
		_spawn_guard_spark()
		# names the ACTION, not the state -- "guarded" would just read as
		# "hit harder", which is the one thing that will never work here
		_spawn_block_label("FLANK IT!", Color(1.0, 0.6, 0.55))
		return false
	# RIPOSTE: you hit it during the WIND-UP. It was waiting for that.
	if has_riposte and telegraphing and _time_now() >= riposte_ready_at:
		riposte_ready_at = _time_now() + RIPOSTE_COOLDOWN
		_do_riposte()
		# the blow still lands -- the punish is the counter, not immunity
	# RHYTHM PUNISH: mash the same beat and the fourth one bites.
	if has_rhythm_punish:
		var t := _time_now()
		rhythm_streak = (rhythm_streak + 1) if (t - rhythm_last_hit) < RHYTHM_WINDOW else 1
		rhythm_last_hit = t
		if rhythm_streak >= RHYTHM_COUNT:
			rhythm_streak = 0
			_do_rhythm_counter()
	# SOULBIND: while the runes are lit, your blow is FOOD. Nothing you do to the
	# boss itself counts until the adds are broken -- that IS the lesson.
	if has_soulbind and living_rune_adds() > 0:
		health = min(max_health, health + int(round(amount * SOULBIND_HEAL_FRAC)))
		update_health_bar()
		_spawn_soulbind_feed()
		# it's HEALING off you -- say so, or this reads as the same flat block
		_spawn_block_label("FEEDING — KILL THE RUNES", Color(0.6, 1.0, 0.65))
		return false
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
		# while the soul is SCATTERED (the wand's 4s window) the ward is gone --
		# the fragments are bare, and every blow lands in full
		if in_mortal_window():
			pass
		else:
			dmg = max(1, int(round(dmg * (SOUL_WARD_BASE + SOUL_WARD_PER_CLONE * living_clones()))))
	health -= dmg
	_last_hurt_at = _time_now()   # covenant: pressure me and I stop healing my twin
	update_health_bar()
	if health <= 0:
		# an undivided soul cannot be destroyed: the final Monarch reforms
		# around any killing blow landed OUTSIDE the wand's mortal window
		if is_final_monarch() and not in_mortal_window():
			health = 1
			update_health_bar()
			FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -110),
				"THE UNDIVIDED SOUL REFORMS", Color(0.8, 0.5, 1.0))
			return true
		die()
	else:
		# REACTIVE: the blow landed and it lived, so it steps out of the world --
		# everything you throw for the next couple of seconds hits nothing. This
		# is what stops the fight being a damage race: you get ONE hit, then you
		# have to read it.
		enter_phase()
		flash_hit()
		play_sfx(SFX_HIT)
		# apex bosses enrage earlier AND hit a second gear near death
		var enrage_at = 0.6 if is_apex else ENRAGE_THRESHOLD
		if not is_enraged and health <= max_health * enrage_at:
			enrage()
		if is_apex and not is_frenzied and health <= max_health * 0.25:
			frenzy()
		# the Wizard's reflex: struck, he may flicker a short step away -- but
		# NOT during a combo recovery window, which is the player's guaranteed
		# opening to land free hits (he hovers exposed there).
		if has_blink_on_hit and not is_busy and not is_charging and not is_diving and combo_recovery_timer <= 0.0 and randf() < BLINK_ON_HIT_CHANCE:
			blink_short()
	return true    # the blow landed -- callers may show a damage number

func enrage() -> void:
	is_enraged = true
	current_tint = Color(1.0, 0.62, 0.56)   # blood-tinged
	if rig != null:
		rig.modulate = current_tint
	_boss_hud_banner("ENRAGED")

# Apex second wind: cooldowns nearly vanish and it moves a quarter faster.
func frenzy() -> void:
	is_frenzied = true
	current_tint = Color(1.0, 0.38, 0.32)   # burning red
	if rig != null:
		rig.modulate = current_tint
	_boss_hud_banner("FRENZY")
	base_move_speed *= 1.25
	shake_camera(9.0, 0.5)
	spawn_shockwave(240.0, Color(1.0, 0.15, 0.1))
	# the crumbling aura rages with him
	if aura_particles != null and is_instance_valid(aura_particles):
		aura_particles.amount = 126   # 1.5x denser
		aura_particles.emission_sphere_radius = AURA_RADIUS * 0.95
		aura_particles.scale_amount_max = 8.0
	if aura_particles2 != null and is_instance_valid(aura_particles2):
		aura_particles2.amount = 89   # keeps its ~0.7x ratio in frenzy (1.5x)
		aura_particles2.emission_sphere_radius = AURA_RADIUS * 0.95
		aura_particles2.scale_amount_max = 8.0
	aura_spin = 1.9   # the ember rings whirl in frenzy
	aura_last_n = -1  # force the soul-split distribution to recompute

# Deliberately does nothing. Bosses are immovable -- a boss that could be
# shoved around would let a knockback weapon stunlock it into a corner and
# trivialise every fight in the game. It still ACCEPTS the call so every
# knockback source can hit any target without type-checking first. Do not
# "fix" this into real knockback.
func apply_knockback(_direction_sign: int, _distance: float) -> void:
	pass

func flash_hit() -> void:
	if rig == null:
		return
	rig.modulate = Color(2.4, 2.4, 2.4)
	var tween = create_tween()
	tween.tween_property(rig, "modulate", current_tint, 0.15)

func play_sfx(stream: AudioStream) -> void:
	var sfx = get_node_or_null("SFXPlayer")   # a headless-built boss has no scene tree
	if sfx == null:
		return
	sfx.stream = stream
	sfx.play()

func update_health_bar() -> void:
	var percent = clamp(float(health) / max_health, 0.0, 1.0)
	var fill = get_node_or_null("HealthBarFill")   # null on a headless-built boss
	if fill:
		fill.size.x = health_bar_w * percent
	# the real boss also drives the big screen bar (not its clones/echoes)
	if not is_clone and not is_false_copy:
		var hud = get_tree().get_first_node_in_group("boss_hud")
		if hud:
			hud.set_health(percent)

# A one-shot dramatic banner on the boss spectacle overlay (enrage/frenzy).
func _boss_hud_banner(text: String) -> void:
	if is_clone or is_false_copy:
		return
	var hud = get_tree().get_first_node_in_group("boss_hud")
	if hud:
		hud.phase_banner("%s — %s" % [get_display_name(), text])

func die() -> void:
	# echoes are worth a token amount, not a boss bounty
	# echoes and false copies are worth a token amount, not a boss bounty
	GameState.add_xp(15 if (is_clone or is_false_copy) else int(round(60 * damage_multiplier * GameState.depth_reward_mult())))
	is_dead = true
	is_busy = true
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	# the kill flourish (the real boss only -- an echo dying is not the fight ending)
	if not is_clone and not is_false_copy:
		var hud = get_tree().get_first_node_in_group("boss_hud")
		if hud:
			hud.slain(get_display_name())
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
	if boss_sprite and boss_sprite.sprite_frames.has_animation("death"):
		boss_sprite.play("death")
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
