extends CharacterBody2D

# ---------------------------------------------------------------------------
# Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL
# (non-boss) levels alongside the six humanoid grunt archetypes in enemy.gd.
# One script, several "kinds", each with its own silhouette, movement, and
# attack pattern:
#
#   flyer   -- slow floating eye; drifts above the player, contact damage,
#              occasional lazy shot. Cannot touch the ground. Easy.
#   bomber  -- round kamikaze; sprints in and self-destructs in an AoE.
#   charger -- horned rammer; winds up then dashes across the floor.
#   spitter -- squat turret-toad; roots in place and fires 3-shot spreads.
#
# Built entirely in code (no .tscn) and self-registers as a dungeon_combatant
# so the player's weapons hit it and the level-clear counter tracks it. Stats
# are injected by dungeon_interior.gd before the node enters the tree.
# ---------------------------------------------------------------------------

signal died

const GRAVITY = 900.0
const KNOCKBACK_DURATION = 0.12
const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_HIT = preload("res://audio/hit.wav")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_EXPLOSION = preload("res://audio/explosion.wav")
const MAGIC_ORB = preload("res://magic_orb.gd")
const SFX_BLINK = preload("res://audio/dash.wav")

# Base statline per kind (before level scaling multipliers).
# Undead/evil monsters. "main" = body, "accent" = glow (eyes/pustules/etc).
const KINDS = {
	# Gloomeye -- a floating skull-wisp shrouded in tattered darkness.
	"flyer": {
		"hp": 34, "dmg": 7, "speed": 66.0, "reward": 6, "xp": 6,
		"main": Color(0.24, 0.22, 0.3), "accent": Color(0.7, 0.25, 0.95),
	},
	# Festerling -- a bloated rotting corpse that ruptures on approach.
	"bomber": {
		"hp": 40, "dmg": 24, "speed": 132.0, "reward": 8, "xp": 8,
		"main": Color(0.26, 0.3, 0.2), "accent": Color(0.8, 1.0, 0.3),
	},
	# Gravehound -- a skeletal beast that charges the living.
	"charger": {
		"hp": 78, "dmg": 16, "speed": 78.0, "reward": 9, "xp": 10,
		"main": Color(0.4, 0.38, 0.34), "accent": Color(0.9, 0.85, 0.66),
	},
	# Bilespitter -- a diseased, fanged toad-corpse that vomits bile.
	"spitter": {
		"hp": 50, "dmg": 9, "speed": 34.0, "reward": 8, "xp": 8,
		"main": Color(0.26, 0.36, 0.18), "accent": Color(0.7, 1.0, 0.35),
	},
	# Blink Stalker -- teleports behind you (never on top of you), then lunges.
	"stalker": {
		"hp": 60, "dmg": 18, "speed": 96.0, "reward": 10, "xp": 11,
		"main": Color(0.17, 0.15, 0.24), "accent": Color(0.6, 0.2, 0.95),
	},
	# Revenant Archer -- kites; blinks to a flank to fire, blinks away when close.
	"blink_archer": {
		"hp": 46, "dmg": 12, "speed": 72.0, "reward": 10, "xp": 11,
		"main": Color(0.19, 0.24, 0.26), "accent": Color(0.4, 0.95, 0.85),
	},
	# Hexer -- exhales an expanding ring of bolts with ONE gap to slip through.
	"hexer": {
		"hp": 52, "dmg": 11, "speed": 42.0, "reward": 11, "xp": 12,
		"main": Color(0.3, 0.15, 0.34), "accent": Color(0.9, 0.35, 1.0),
	},
	# Runecaster -- brands the ground with delayed sigils that erupt under you.
	"runecaster": {
		"hp": 54, "dmg": 22, "speed": 34.0, "reward": 11, "xp": 12,
		"main": Color(0.32, 0.22, 0.12), "accent": Color(1.0, 0.55, 0.2),
	},
	# Warlock -- conjures slow cursed orbs that home in and must be juked.
	"warlock": {
		"hp": 48, "dmg": 13, "speed": 40.0, "reward": 12, "xp": 13,
		"main": Color(0.15, 0.19, 0.32), "accent": Color(0.5, 0.5, 1.0),
	},
	# --- 9 more, each a distinct trick (2026-07-26) ---
	# Weaver -- a spider-mage; snares you ROOTED in a web from range.
	"weaver": {"hp": 52, "dmg": 10, "speed": 40.0, "reward": 11, "xp": 12,
		"main": Color(0.20, 0.24, 0.16), "accent": Color(0.72, 0.95, 0.4)},
	# Grave Leech -- latches a tether that DRAINS your mana and heals itself.
	"leech": {"hp": 60, "dmg": 6, "speed": 60.0, "reward": 12, "xp": 13,
		"main": Color(0.30, 0.14, 0.18), "accent": Color(0.95, 0.30, 0.42)},
	# Burrower -- tunnels unseen (untouchable), then ERUPTS up beneath you.
	"burrower": {"hp": 66, "dmg": 20, "speed": 152.0, "reward": 12, "xp": 13,
		"main": Color(0.30, 0.22, 0.14), "accent": Color(0.92, 0.6, 0.28)},
	# Gravewell -- warps space to YANK you into its reach.
	"warper": {"hp": 56, "dmg": 15, "speed": 40.0, "reward": 12, "xp": 13,
		"main": Color(0.16, 0.14, 0.26), "accent": Color(0.55, 0.4, 1.0)},
	# Plaguebearer -- trails clouds of POISON gas that linger where it walks.
	"plague": {"hp": 62, "dmg": 8, "speed": 46.0, "reward": 12, "xp": 13,
		"main": Color(0.22, 0.28, 0.14), "accent": Color(0.7, 0.95, 0.25)},
	# Wailer -- shrieks a sonic ring that DISORIENTS; flee its range.
	"wailer": {"hp": 50, "dmg": 9, "speed": 40.0, "reward": 11, "xp": 12,
		"main": Color(0.28, 0.20, 0.30), "accent": Color(0.9, 0.6, 1.0)},
	# Bone Ballista -- a siege corpse: a long charge, then a PIERCING line-bolt.
	"ballista": {"hp": 72, "dmg": 26, "speed": 20.0, "reward": 12, "xp": 13,
		"main": Color(0.34, 0.32, 0.26), "accent": Color(1.0, 0.85, 0.4)},
	# Hive Maw -- coughs up a SWARM of homing gnats.
	"swarm": {"hp": 54, "dmg": 6, "speed": 34.0, "reward": 12, "xp": 13,
		"main": Color(0.22, 0.24, 0.14), "accent": Color(0.82, 0.9, 0.3)},
	# Rimewisp -- a frost sprite; FREEZES you and leaves ice underfoot.
	"frostling": {"hp": 44, "dmg": 10, "speed": 72.0, "reward": 11, "xp": 12,
		"main": Color(0.20, 0.28, 0.36), "accent": Color(0.62, 0.9, 1.0)},
	# --- 9 MORE, each a new trick (2026-07-27) ---
	# Bonewatch Sentinel -- a rooted skull-turret that SWEEPS a searing beam across an arc.
	"sentinel": {"hp": 74, "dmg": 16, "speed": 0.0, "reward": 12, "xp": 13,
		"main": Color(0.30, 0.30, 0.24), "accent": Color(1.0, 0.72, 0.30)},
	# Writhing Brood -- a bloated sac that SPLITS into two smaller broods when slain.
	"brood": {"hp": 64, "dmg": 12, "speed": 66.0, "reward": 10, "xp": 11,
		"main": Color(0.24, 0.30, 0.20), "accent": Color(0.70, 0.95, 0.40)},
	# Arcbinder -- snipes a CHAIN-LIGHTNING strike: instant, telegraphed, jolts + slows.
	"arcbinder": {"hp": 50, "dmg": 15, "speed": 46.0, "reward": 12, "xp": 13,
		"main": Color(0.18, 0.22, 0.34), "accent": Color(0.60, 0.85, 1.0)},
	# Warchief -- a war-drummer corpse that pulses a RAGE aura, whipping nearby mobs faster.
	"warchief": {"hp": 82, "dmg": 15, "speed": 52.0, "reward": 13, "xp": 14,
		"main": Color(0.34, 0.18, 0.16), "accent": Color(1.0, 0.40, 0.25)},
	# Voidling -- a flickering wraith that BLINKS away from your blows, then jabs.
	"voidling": {"hp": 40, "dmg": 14, "speed": 104.0, "reward": 12, "xp": 13,
		"main": Color(0.16, 0.16, 0.24), "accent": Color(0.55, 0.50, 0.95)},
	# Gorgon Gazer -- its STARE petrifies: linger in its gaze cone and you freeze fast.
	"gazer": {"hp": 58, "dmg": 12, "speed": 30.0, "reward": 12, "xp": 13,
		"main": Color(0.26, 0.30, 0.20), "accent": Color(0.85, 1.0, 0.55)},
	# Skycaller -- calls a RAIN of falling strikes across the ground around you.
	"skycaller": {"hp": 54, "dmg": 18, "speed": 34.0, "reward": 13, "xp": 14,
		"main": Color(0.22, 0.20, 0.32), "accent": Color(0.70, 0.70, 1.0)},
	# Sanguine -- a fanged leaper whose bite DRAINS your life to heal its own.
	"vampire": {"hp": 56, "dmg": 13, "speed": 92.0, "reward": 12, "xp": 13,
		"main": Color(0.28, 0.12, 0.14), "accent": Color(1.0, 0.25, 0.30)},
	# Ironclad -- a shielded juggernaut: near-immune behind its guard, deadly when it drops.
	"juggernaut": {"hp": 120, "dmg": 24, "speed": 40.0, "reward": 14, "xp": 15,
		"main": Color(0.30, 0.30, 0.32), "accent": Color(0.90, 0.90, 0.95)},
}

# injected before _ready
var kind := "flyer"
var elite := false            # bigger, tougher, glowing, double reward

# --- Elite affixes ---
# An elite is not just a bigger mob: each rolls ONE affix at spawn, worn as a
# title over its head, and each affix is a different mechanic (the creative
# directive: distinct in kind, not in numbers):
#   Thorned   -- striking it up close bites back (reflects a fifth to the player)
#   Frenzied  -- below half health it moves half again as fast
#   Blinking  -- struck, it flickers a short step away (cooldown)
#   Bulwark   -- a fifth of every blow rings off its hide
const ELITE_AFFIXES = {
	"thorned": "Thorned", "frenzied": "Frenzied", "blinking": "Blinking", "bulwark": "Bulwark",
}
var affix := ""
var _blink_ready_at := 0.0
const BLINK_CD := 2.5
const THORN_FRAC := 0.2
const THORN_RANGE := 140.0
const BULWARK_FRAC := 0.2
const FRENZY_MULT := 1.5
var wave_hp_multiplier := 1.0
var wave_damage_multiplier := 1.0
var wave_speed_multiplier := 1.0

var data: Dictionary = {}
var player: Node2D = null
var max_health := 34
var health := 34
var attack_damage := 7
# NEVER a one-shot -- the game's fairness line covers elites too. A special mob is
# far less telegraphed than a boss (no wind-up to read), so being deleted by one
# is even more "the number was too big" than a boss one-shot. Every blow -- melee,
# blast, or bolt, they all carry attack_damage -- is capped to this share of the
# player's max HP: a floor-100 elite glass-cannon (raw 159) still hits like a
# truck and threatens a 2-hit kill, but you always survive the first and get a
# beat to answer. Below the cap, damage scales normally; only the hardest hitters
# at the deepest floors ever reach it.
const MAX_HIT_FRACTION := 0.7
var reward := 6
var xp_reward := 6
var move_speed := 66.0
var main_color: Color
var accent_color: Color

var is_dead := false
var is_knocked_back := false
var facing := 1

# --- Statuses. Special mobs used to have NO apply_status, so every burn/poison/
# slow silently vanished against them -- the DoT specs' whole kit did nothing to
# elites. DoT lands in full; slow lands in full; freeze is a hard slow rather
# than a stop, because their scripted behaviours (teleports, dives, charges)
# were never written to be interrupted mid-move.
var status_burn_until := 0.0
var status_burn_dps := 0.0
var status_poison_until := 0.0
var status_poison_dps := 0.0
var status_slow_until := 0.0
var status_slow_factor := 1.0
var _dot_accum := 0.0

func apply_status(status_kind: String, dur: float, mag: float) -> void:
	if is_dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	match status_kind:
		"burn":
			var burn_live := now < status_burn_until
			status_burn_until = now + dur
			status_burn_dps = maxf(status_burn_dps if burn_live else 0.0, mag)
		"poison":
			var poison_live := now < status_poison_until
			status_poison_until = now + dur
			status_poison_dps = maxf(status_poison_dps if poison_live else 0.0, mag)
		"slow":
			# keep the STRONGER (lower factor) and LONGER of any overlapping slow --
			# a weak slow must not un-freeze a frozen mob or cut its timer short
			var live := now < status_slow_until
			status_slow_factor = minf(status_slow_factor if live else 1.0, clampf(1.0 - mag, 0.2, 1.0))
			status_slow_until = maxf(status_slow_until, now + dur)
		"freeze":
			var live_f := now < status_slow_until
			status_slow_factor = minf(status_slow_factor if live_f else 1.0, 0.25)
			status_slow_until = maxf(status_slow_until, now + dur)

func status_slow_mult() -> float:
	return status_slow_factor if Time.get_ticks_msec() / 1000.0 < status_slow_until else 1.0

func tick_statuses(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dps := 0.0
	if now < status_burn_until:
		dps += status_burn_dps
	if now < status_poison_until:
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
var attack_cooldown := 0.0

# flyer
var hover_offset := Vector2.ZERO
var bob_time := 0.0
# bomber
var is_priming := false
# charger
var charge_state := "seek"   # seek -> windup -> dash -> recover
var charge_timer := 0.0
var charge_dir := 1
# casters / teleporters
var cast_timer := 0.0
var tp_timer := 0.0
var state := "seek"          # generic small state machine (stalker)
var state_timer := 0.0
var lunge_dir := 1
var burrow_elapsed := 0.0    # burrower: max time it may stay burrowed/untouchable
var is_casting := false
var pending_tp := Vector2.ZERO
# --- the 9 new kinds (2026-07-27) ---
var split_gen := 0           # brood: 0 = original (splits on death), 1 = a split (won't)
var _rage_until := 0.0       # warchief aura: this mob moves faster until this time
var _dodge_ready_at := 0.0   # voidling
var _gaze_accum := 0.0       # gazer: seconds the player has held our gaze
var _jug_open := false       # juggernaut: guard dropped -> vulnerable + attacking
# distinct locomotion (2026-07-27): each new kind MOVES differently, not just "walk at you"
var _hop_cd := 0.0           # brood: a bouncing hop gait
var _pounce_cd := 0.0        # vampire: a leaper -- pounces in arcs, creeps between
var _drum_until := 0.0       # warchief: plants and drums while it rallies
var _turn_cd := 0.0          # gazer: turns its head SLOWLY, so you can hold its blind side
var _void_repos_cd := 1.2    # voidling: flickers to a flank on its own, hard to pin
const SENTINEL_CD := 3.4
const SENTINEL_TELEGRAPH := 0.5
const SENTINEL_RANGE := 520.0
const SENTINEL_ARC := 100.0      # degrees swept
const SENTINEL_STEPS := 18
const BROOD_SPLITS := 2
const ARC_CD := 2.8
const ARC_TELEGRAPH := 0.55
const ARC_RANGE := 560.0
const ARC_HIT_RADIUS := 46.0
const WARCHIEF_CD := 4.0
const WARCHIEF_AURA_RANGE := 320.0
const WARCHIEF_RAGE_TIME := 4.0
const WARCHIEF_RAGE_MULT := 1.45
const VOID_DODGE_CD := 0.9
const VOID_BLINK_DIST := 150.0
const GAZE_RANGE := 300.0
const GAZE_HALF_ANGLE := 34.0    # degrees each side of facing
const GAZE_FREEZE_TIME := 1.6    # sustained gaze before a hard freeze
const SKY_CD := 3.6
const SKY_TELEGRAPH := 0.6
const SKY_COUNT := 5
const SKY_RADIUS := 46.0
const VAMP_HIT_RANGE := 46.0
const VAMP_LIFESTEAL := 0.6
const JUG_GUARD_TIME := 3.2
const JUG_OPEN_TIME := 1.6
const JUG_SHIELD_FRAC := 0.15    # fraction of damage that gets through the raised guard
const JUG_SLAM_RANGE := 74.0

var visual: Node2D = null
var visual_parts: Array = []   # [[node, base_color], ...] for hit-flash restore

# PixelLab skins (art/mobs/<kind>/) replace the procedural polygon build when
# the art is present; without it the poly build runs unchanged (zero-risk).
const MOB_ROOT := "res://art/mobs/"
const MOB_SPRITE_H := 60.0
var mob_sprite: AnimatedSprite2D = null
var health_fill: ColorRect = null

const FLYER_CONTACT_RANGE = 42.0
const FLYER_SHOOT_RANGE = 380.0
const BOMBER_PRIME_RANGE = 70.0
const BOMBER_BLAST_RADIUS = 96.0
const BOMBER_PRIME_TIME = 0.55
const CHARGER_TRIGGER_RANGE = 320.0
const CHARGER_WINDUP = 0.5
const CHARGER_DASH_TIME = 0.55
const CHARGER_DASH_SPEED = 470.0
const CHARGER_RECOVER = 0.9
const CHARGER_HIT_RANGE = 46.0
const SPITTER_SHOOT_RANGE = 620.0
const SPITTER_COOLDOWN = 2.0
const SPITTER_SPREAD_DEG = 14.0

const STALKER_TP_INTERVAL = 3.4
const STALKER_MARK_TIME = 0.45      # destination is telegraphed this long first
const STALKER_LUNGE_TIME = 0.7
const STALKER_LUNGE_SPEED = 430.0
const STALKER_TP_DIST = 260.0       # appears this far behind you -- never on top
const STALKER_HIT_RANGE = 46.0

const BLINK_MIN_RANGE = 200.0       # if you get closer than this it blinks away
const BLINK_TP_INTERVAL = 3.6
const BLINK_SHOOT_RANGE = 640.0
const BLINK_SHOOT_CD = 1.6
const BLINK_FLANK_DIST = 430.0

const HEX_CAST_CD = 3.0
const HEX_BOLTS = 15
const HEX_GAP = 4                   # consecutive bolts skipped -> a dodge gap
const HEX_TELEGRAPH = 0.45
const HEX_BOLT_RANGE = 540.0

const RUNE_CAST_CD = 3.6
const RUNE_COUNT = 4
const RUNE_TELEGRAPH = 0.9
const RUNE_RADIUS = 56.0
const RUNE_SPREAD = 230.0

const WARLOCK_CAST_CD = 3.2
const WARLOCK_ORBS = 2
const WARLOCK_KEEP_RANGE = 320.0

func _ready() -> void:
	add_to_group("dungeon_combatant")
	collision_layer = 4                      # player weapons hit layer 4
	collision_mask = 0 if kind == "flyer" else 1
	data = KINDS.get(kind, KINDS["flyer"])
	main_color = data["main"]
	accent_color = data["accent"]
	max_health = int(round(data["hp"] * wave_hp_multiplier))
	health = max_health
	attack_damage = int(round(data["dmg"] * wave_damage_multiplier))
	if kind != "flyer":                       # a floating mob has nothing to cast on
		preload("res://char_shadow.gd").attach(self, 0.5, 0.0)
	reward = data["reward"]
	xp_reward = data["xp"]
	move_speed = data["speed"] * wave_speed_multiplier
	if elite:
		max_health = int(round(max_health * 1.6))
		health = max_health
		attack_damage = int(round(attack_damage * 1.25))
		reward *= 2
		xp_reward *= 2
		scale = Vector2(1.35, 1.35)
		# and its rolled identity: one affix, worn as a title
		affix = ELITE_AFFIXES.keys()[randi() % ELITE_AFFIXES.size()]
	hover_offset = Vector2(randf_range(-70.0, 70.0), -randf_range(150.0, 240.0))
	player = get_tree().get_first_node_in_group("player")
	# cap every blow below a one-shot (see MAX_HIT_FRACTION) -- one place, so melee,
	# blasts and every projectile that carries attack_damage all obey it
	if player != null and player.has_method("get_max_health"):
		attack_damage = mini(attack_damage, int(round(player.get_max_health() * MAX_HIT_FRACTION)))
	build_collision()
	build_visual()
	build_health_bar()
	if elite:
		build_elite_glow()
		var al := Label.new()
		al.text = ELITE_AFFIXES.get(affix, "Elite")
		al.position = Vector2(-50, -74)
		al.size = Vector2(100, 14)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.add_theme_font_size_override("font_size", 9)
		al.add_theme_color_override("font_color", Color(1.0, 0.6, 0.9))
		al.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		al.add_theme_constant_override("outline_size", 3)
		al.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(al)

func build_collision() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	match kind:
		"flyer": rect.size = Vector2(30, 30)
		"bomber": rect.size = Vector2(30, 28)
		"charger": rect.size = Vector2(46, 30)
		"spitter": rect.size = Vector2(40, 30)
		"stalker": rect.size = Vector2(30, 42)
		"blink_archer": rect.size = Vector2(28, 42)
		"hexer", "runecaster", "warlock": rect.size = Vector2(32, 44)
		"weaver", "wailer", "plague": rect.size = Vector2(34, 42)
		"leech", "frostling": rect.size = Vector2(28, 36)
		"burrower": rect.size = Vector2(40, 26)
		"warper": rect.size = Vector2(30, 44)
		"ballista": rect.size = Vector2(46, 34)
		"swarm": rect.size = Vector2(38, 32)
		"sentinel": rect.size = Vector2(36, 40)
		"brood": rect.size = Vector2(34, 30)
		"arcbinder", "skycaller": rect.size = Vector2(32, 44)
		"warchief": rect.size = Vector2(38, 46)
		"voidling": rect.size = Vector2(26, 40)
		"gazer": rect.size = Vector2(34, 40)
		"vampire": rect.size = Vector2(30, 40)
		"juggernaut": rect.size = Vector2(44, 44)
		_: rect.size = Vector2(30, 30)
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	tick_statuses(delta)
	if is_dead:            # a burn/poison tick can kill mid-frame -- stop before a
		return             # corpse falls, attacks, or moves (enemy.gd guards this too)
	if kind != "flyer" and not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if cast_timer > 0.0:
		cast_timer -= delta
	if tp_timer > 0.0:
		tp_timer -= delta
	if state_timer > 0.0:
		state_timer -= delta
	if is_knocked_back:
		move_and_slide()
		return

	if player != null and is_instance_valid(player):
		match kind:
			"flyer": act_flyer(delta)
			"bomber": act_bomber(delta)
			"charger": act_charger(delta)
			"spitter": act_spitter(delta)
			"stalker": act_stalker(delta)
			"blink_archer": act_blink_archer(delta)
			"hexer": act_hexer(delta)
			"runecaster": act_runecaster(delta)
			"warlock": act_warlock(delta)
			"weaver": act_weaver(delta)
			"leech": act_leech(delta)
			"burrower": act_burrower(delta)
			"warper": act_warper(delta)
			"plague": act_plague(delta)
			"wailer": act_wailer(delta)
			"ballista": act_ballista(delta)
			"swarm": act_swarm(delta)
			"frostling": act_frostling(delta)
			"sentinel": act_sentinel(delta)
			"brood": act_brood(delta)
			"arcbinder": act_arcbinder(delta)
			"warchief": act_warchief(delta)
			"voidling": act_voidling(delta)
			"gazer": act_gazer(delta)
			"skycaller": act_skycaller(delta)
			"vampire": act_vampire(delta)
			"juggernaut": act_juggernaut(delta)

	if velocity.x > 1.0:
		facing = 1
	elif velocity.x < -1.0:
		facing = -1
	if visual:
		visual.scale.x = facing
	_update_mob_anim()
	bob_time += delta
	# chill drags the whole mob: x always, y only for flyers (scaling y on a
	# grounded mob would slow its FALL, which reads as floating, not frozen)
	var _sm := status_slow_mult()
	# Frenzied: wounded past half, it stops pacing itself
	if affix == "frenzied" and health < max_health / 2:
		_sm *= FRENZY_MULT
	# a Warchief's RAGE aura whips it (and its neighbours) into a faster stride
	if Time.get_ticks_msec() / 1000.0 < _rage_until:
		_sm *= WARCHIEF_RAGE_MULT
	# apply slow/rage to horizontal speed only while GROUNDED (flyers always -- they re-aim
	# every frame). A hop/pounce preserves its launch velocity.x across airborne frames, so
	# scaling it every frame would COMPOUND the multiplier -- hurling the mob into the wall
	# under rage/Frenzied, or dropping it straight down under slow.
	if not is_equal_approx(_sm, 1.0):
		if kind == "flyer":
			velocity.x *= _sm
			velocity.y *= _sm
		elif is_on_floor():
			velocity.x *= _sm
	move_and_slide()
	# hard containment: no mob (flyer, teleporter, or otherwise) ever ends a
	# frame outside the level walls
	global_position.x = clampf(global_position.x, 50.0, arena_width() - 50.0)

# --- per-kind behaviour ---

func act_flyer(delta: float) -> void:
	var target = player.global_position + hover_offset
	var to_target = target - global_position
	if to_target.length() > 30.0:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	velocity.y += sin(bob_time * 2.5) * 22.0
	var dist = global_position.distance_to(player.global_position)
	if dist < FLYER_CONTACT_RANGE and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 1.0
	elif dist < FLYER_SHOOT_RANGE and attack_cooldown <= 0.0 and randf() < 0.4:
		var dir = (player.global_position - global_position).normalized()
		fire_projectile(dir, attack_damage)
		attack_cooldown = 2.2

func act_bomber(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	if not is_priming:
		velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
		if global_position.distance_to(player.global_position) < BOMBER_PRIME_RANGE:
			is_priming = true
			prime_and_explode()
	else:
		velocity.x = 0.0

func prime_and_explode() -> void:
	# quick flash telegraph, then detonate (killing self)
	var t = create_tween()
	t.set_loops(3)
	t.tween_callback(func(): set_flash(Color(1.0, 0.4, 0.1)))
	t.tween_interval(BOMBER_PRIME_TIME / 6.0)
	t.tween_callback(clear_flash)
	t.tween_interval(BOMBER_PRIME_TIME / 6.0)
	await get_tree().create_timer(BOMBER_PRIME_TIME).timeout
	if not is_instance_valid(self) or is_dead:   # died mid-prime -> the freed mob can't explode
		return
	explode()

func explode() -> void:
	spawn_blast()
	play_sfx(SFX_EXPLOSION)
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < BOMBER_BLAST_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
		if player.has_method("apply_knockback"):
			var away = sign(player.global_position.x - global_position.x)
			player.apply_knockback(away if away != 0 else 1, 220.0)
		if player.has_node("Camera2D"):
			player.get_node("Camera2D").shake(7.0, 0.3)
	die()

func act_charger(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	match charge_state:
		"seek":
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			if absf(dx) < CHARGER_TRIGGER_RANGE and absf(player.global_position.y - global_position.y) < 90.0:
				charge_state = "windup"
				charge_timer = CHARGER_WINDUP
				charge_dir = sign(dx) if dx != 0 else facing
				velocity.x = 0.0
		"windup":
			velocity.x = 0.0
			set_flash(Color(1.0, 0.85, 0.4))
			charge_timer -= delta
			if charge_timer <= 0.0:
				clear_flash()
				charge_state = "dash"
				charge_timer = CHARGER_DASH_TIME
		"dash":
			velocity.x = charge_dir * CHARGER_DASH_SPEED
			charge_timer -= delta
			if global_position.distance_to(player.global_position) < CHARGER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				if player.has_method("apply_knockback"):
					player.apply_knockback(charge_dir, 200.0)
				attack_cooldown = 0.8
			var hit_wall = false
			for i in range(get_slide_collision_count()):
				if absf(get_slide_collision(i).get_normal().x) > 0.5:
					hit_wall = true
			if charge_timer <= 0.0 or hit_wall:
				charge_state = "recover"
				charge_timer = CHARGER_RECOVER
		"recover":
			velocity.x = 0.0
			charge_timer -= delta
			if charge_timer <= 0.0:
				charge_state = "seek"

func act_spitter(delta: float) -> void:
	# roots in place, slowly faces the player, fires 3-round spreads
	velocity.x = 0.0
	if global_position.distance_to(player.global_position) < SPITTER_SHOOT_RANGE and attack_cooldown <= 0.0:
		var base = (player.global_position - global_position).angle()
		for k in [-1, 0, 1]:
			var dir = Vector2.RIGHT.rotated(base + deg_to_rad(SPITTER_SPREAD_DEG) * k)
			fire_projectile(dir, attack_damage)
		attack_cooldown = SPITTER_COOLDOWN

# Blink Stalker -- seek, then telegraph a spot BEHIND the player, blink there,
# and lunge in. Never teleports on top of you (STALKER_TP_DIST away).
func act_stalker(delta: float) -> void:
	var dist = global_position.distance_to(player.global_position)
	match state:
		"seek":
			var dx = player.global_position.x - global_position.x
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			if dist < STALKER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				attack_cooldown = 0.9
			if tp_timer <= 0.0 and dist > 150.0:
				var side = -sign(player.global_position.x - global_position.x)
				if side == 0:
					side = 1
				pending_tp = Vector2(player.global_position.x + side * STALKER_TP_DIST, player.global_position.y)
				spawn_sigil(pending_tp, 26.0, STALKER_MARK_TIME, accent_color)
				state = "mark"
				state_timer = STALKER_MARK_TIME
		"mark":
			velocity.x = 0.0
			if state_timer <= 0.0:
				teleport_to(pending_tp)
				lunge_dir = sign(player.global_position.x - global_position.x)
				if lunge_dir == 0:
					lunge_dir = 1
				state = "lunge"
				state_timer = STALKER_LUNGE_TIME
		"lunge":
			velocity.x = lunge_dir * STALKER_LUNGE_SPEED
			if dist < STALKER_HIT_RANGE and attack_cooldown <= 0.0:
				deal_contact_damage()
				if player.has_method("apply_knockback"):
					player.apply_knockback(lunge_dir, 160.0)
				attack_cooldown = 0.7
			var hit_wall = false
			for i in range(get_slide_collision_count()):
				if absf(get_slide_collision(i).get_normal().x) > 0.5:
					hit_wall = true
			if state_timer <= 0.0 or hit_wall:
				state = "seek"
				tp_timer = STALKER_TP_INTERVAL
	face_player()

# Revenant Archer -- fires from range, blinks to a flank on a timer AND
# immediately if the player closes the distance.
func act_blink_archer(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	var dist = global_position.distance_to(player.global_position)
	if dist < BLINK_MIN_RANGE or tp_timer <= 0.0:
		blink_to_flank()
		tp_timer = BLINK_TP_INTERVAL
	if dist < BLINK_SHOOT_RANGE and attack_cooldown <= 0.0:
		var base = (player.global_position - global_position).angle()
		for k in [-1, 0, 1]:
			fire_projectile(Vector2.RIGHT.rotated(base + deg_to_rad(9.0) * k), attack_damage)
		attack_cooldown = BLINK_SHOOT_CD

# Hexer -- keeps mid-range, then breathes an expanding ring of bolts with one
# gap left open. Slip through the gap or eat the whole ring.
func act_hexer(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 220.0:
		velocity.x = -sign(dx) * move_speed
	elif dist > 430.0:
		velocity.x = sign(dx) * move_speed
	else:
		velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting:
		cast_timer = HEX_CAST_CD
		cast_hex_ring()

func cast_hex_ring() -> void:
	is_casting = true
	set_flash(accent_color)
	await get_tree().create_timer(HEX_TELEGRAPH).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	var gap_start = randi() % HEX_BOLTS
	for i in range(HEX_BOLTS):
		# the escape gap must WRAP the ring -- a non-wrapping window shrank to as
		# few as 1 bolt (a near-closed, undodgeable ring) when gap_start was near
		# the end. This always leaves exactly HEX_GAP bolts open.
		if (i - gap_start + HEX_BOLTS) % HEX_BOLTS < HEX_GAP:
			continue
		var dir = Vector2.RIGHT.rotated(i * TAU / HEX_BOLTS)
		var arrow = ARROW_SCENE.instantiate()
		arrow.position = global_position + Vector2(0, -18) + dir * 20.0
		arrow.setup(dir, attack_damage, 8.0, 16.0, 2, true, HEX_BOLT_RANGE)
		get_parent().add_child(arrow)
	is_casting = false

# Runecaster -- brands the ground with delayed sigils around the player that
# erupt after a telegraph. Keep moving or get caught in one.
func act_runecaster(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	if cast_timer <= 0.0 and not is_casting:
		cast_timer = RUNE_CAST_CD
		cast_runes()

func cast_runes() -> void:
	is_casting = true
	set_flash(accent_color)
	var gy = player.global_position.y
	var xs: Array = []
	for i in range(RUNE_COUNT):
		xs.append(player.global_position.x + randf_range(-RUNE_SPREAD, RUNE_SPREAD))
	for x in xs:
		spawn_sigil(Vector2(x, gy), RUNE_RADIUS, RUNE_TELEGRAPH, accent_color)
	await get_tree().create_timer(RUNE_TELEGRAPH).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	for x in xs:
		erupt_rune(Vector2(x, gy))
		if player != null and is_instance_valid(player) and player.global_position.distance_to(Vector2(x, gy)) < RUNE_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
			if player.has_method("apply_knockback"):
				var away = sign(player.global_position.x - x)
				player.apply_knockback(away if away != 0 else 1, 150.0)
	is_casting = false

# Warlock -- conjures slow cursed orbs that home toward the player.
func act_warlock(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = -sign(dx) * move_speed if dist < WARLOCK_KEEP_RANGE else 0.0
	if cast_timer <= 0.0:
		cast_timer = WARLOCK_CAST_CD
		for i in range(WARLOCK_ORBS):
			var base = (player.global_position - global_position).normalized()
			var dir = base.rotated(deg_to_rad(randf_range(-18.0, 18.0)))
			var orb = MAGIC_ORB.new()
			orb.setup(dir, attack_damage, accent_color, 130.0)
			orb.position = position + Vector2(0, -18)
			get_parent().add_child(orb)

# ============ 9 MORE SPECIAL MOBS (2026-07-26) -- each a distinct trick ========
const WEAVER_CD = 4.0
const WEAVER_TELEGRAPH = 0.7
const WEAVER_RADIUS = 46.0
const LEECH_CD = 4.5
const LEECH_RANGE = 440.0
const BURROW_INTERVAL = 3.0
const WARPER_CD = 3.8
const WARPER_TELEGRAPH = 0.5
const PLAGUE_GAS_CD = 1.3
const WAILER_CD = 4.0
const WAILER_TELEGRAPH = 0.55
const WAILER_RADIUS = 220.0
const BALLISTA_WINDUP = 1.4
const BALLISTA_CD = 3.6
const SWARM_CD = 4.2
const SWARM_COUNT = 6
const FROST_CD = 3.2

# a generic expanding burst ring (reused by several of the new mobs)
func _burst(pos: Vector2, radius: float, color: Color) -> void:
	var b = poly(circle_points(radius, 24))
	b.color = Color(color.r, color.g, color.b, 0.5)
	b.global_position = pos
	b.z_index = 6
	b.scale = Vector2(0.2, 0.2)
	get_parent().add_child(b)
	var t = b.create_tween()
	t.set_parallel(true)
	t.tween_property(b, "scale", Vector2.ONE, 0.22)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(b.queue_free)

# WEAVER -- keeps mid-range, casts a web at your feet that ROOTS you.
func act_weaver(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 240.0: velocity.x = -sign(dx) * move_speed
	elif dist > 460.0: velocity.x = sign(dx) * move_speed
	else: velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting and dist < 520.0:
		cast_timer = WEAVER_CD
		cast_web()

func cast_web() -> void:
	is_casting = true
	set_flash(accent_color)
	var target = Vector2(player.global_position.x, player.global_position.y)
	spawn_sigil(target, WEAVER_RADIUS, WEAVER_TELEGRAPH, accent_color)
	await get_tree().create_timer(WEAVER_TELEGRAPH).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	_burst(target, WEAVER_RADIUS, accent_color)
	if is_instance_valid(player) and player.global_position.distance_to(target) < WEAVER_RADIUS:
		if player.has_method("take_damage"): player.take_damage(int(round(attack_damage * 0.5)))
		if player.has_method("apply_root"): player.apply_root(1.3)
	is_casting = false

# GRAVE LEECH -- closes to mid, latches a tether that drains mana + heals it.
func act_leech(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 200.0: velocity.x = -sign(dx) * move_speed
	elif dist > 360.0: velocity.x = sign(dx) * move_speed
	else: velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting and dist < LEECH_RANGE:
		cast_timer = LEECH_CD
		leech_tether()

func leech_tether() -> void:
	is_casting = true
	var beam = Line2D.new()
	beam.width = 3.0
	beam.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.75)
	beam.z_index = 5
	get_parent().add_child(beam)
	# Failsafe free: the beam lives under the LEVEL, not the mob, so a mid-tether death
	# (common -- 60 HP, drains every 0.3s) frees the mob and aborts this coroutine before
	# the cleanup below, leaking a frozen line from the death spot to the player. A
	# SceneTree timer frees the beam regardless; the early free below auto-drops this
	# connection (Godot clears a freed object's signal links), so there is no double free.
	get_tree().create_timer(1.75).timeout.connect(beam.queue_free)
	var elapsed = 0.0
	while elapsed < 1.6 and not is_dead and is_instance_valid(player):
		beam.points = PackedVector2Array([global_position + Vector2(0, -18), player.global_position + Vector2(0, -24)])
		if global_position.distance_to(player.global_position) < LEECH_RANGE:
			if player.has_method("take_damage"): player.take_damage(2)
			if "mana" in player: player.mana = maxf(0.0, player.mana - 7.0)
			health = mini(max_health, health + 3)
			update_health_bar()
		await get_tree().create_timer(0.3).timeout
		elapsed += 0.3
	if is_instance_valid(beam): beam.queue_free()
	is_casting = false

# BURROWER -- races under you UNTOUCHABLE, then bursts up in a telegraphed erupt.
func act_burrower(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	match state:
		"seek":
			collision_layer = 0                    # burrowed: weapons pass through
			if visual: visual.modulate.a = 0.22
			velocity.x = sign(dx) * move_speed if absf(dx) > 8.0 else 0.0
			burrow_elapsed += delta
			# surface when you're overhead OR after a timeout -- so a player it can't
			# reach (a ledge, behind terrain) can never leave it untouchable forever.
			if (absf(dx) < 46.0 and tp_timer <= 0.0) or burrow_elapsed > 6.0:
				state = "mark"
				state_timer = 0.7
				spawn_sigil(Vector2(global_position.x, player.global_position.y), 52.0, 0.7, accent_color)
		"mark":
			velocity.x = 0.0
			if state_timer <= 0.0:
				collision_layer = 4                # surfaces -- now it can be hit
				if visual: visual.modulate.a = 1.0
				var at = Vector2(global_position.x, player.global_position.y)
				_burst(at, 56.0, accent_color)
				if is_instance_valid(player) and player.global_position.distance_to(at) < 62.0:
					if player.has_method("take_damage"): player.take_damage(attack_damage)
					if player.has_method("apply_knockback"): player.apply_knockback(sign(dx) if dx != 0 else 1, 220.0)
				state = "cool"
				state_timer = 2.2
		"cool":
			collision_layer = 4                    # stays hittable through the recovery
			velocity.x = 0.0
			if state_timer <= 0.0:
				state = "seek"
				tp_timer = BURROW_INTERVAL
				burrow_elapsed = 0.0
	face_player()

# GRAVEWELL -- stationary; telegraphs, then YANKS you toward it, then bites.
func act_warper(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = 0.0
	if dist < 58.0 and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 0.9
	if cast_timer <= 0.0 and not is_casting and dist > 120.0 and dist < 640.0:
		cast_timer = WARPER_CD
		warp_pull()

func warp_pull() -> void:
	is_casting = true
	set_flash(accent_color)
	spawn_sigil(global_position + Vector2(0, -18), 40.0, WARPER_TELEGRAPH, accent_color)
	await get_tree().create_timer(WARPER_TELEGRAPH).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead or not is_instance_valid(player):
		is_casting = false
		return
	if player.has_method("apply_knockback"):
		var toward = sign(global_position.x - player.global_position.x)
		player.apply_knockback(toward if toward != 0 else 1, 360.0)
	is_casting = false

# PLAGUEBEARER -- shambles toward you, leaving a trail of poison gas.
func act_plague(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
	if global_position.distance_to(player.global_position) < 46.0 and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 0.9
	if cast_timer <= 0.0:
		cast_timer = PLAGUE_GAS_CD
		spawn_gas(global_position + Vector2(0, -12))

func spawn_gas(pos: Vector2) -> void:
	var cloud = poly(circle_points(38.0, 20))
	cloud.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	cloud.global_position = pos
	cloud.z_index = 3
	get_parent().add_child(cloud)
	# SELF-MANAGING: a Timer on the cloud applies poison, fades, and frees it -- so
	# the cloud outlives (and never touches) this mob after spawn. No mob-coroutine,
	# so no use-after-free / leak if the plaguebearer dies while its gas lingers.
	var pl := player
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	cloud.add_child(timer)
	var elapsed := [0.0]
	timer.timeout.connect(func():
		elapsed[0] += 0.5
		if is_instance_valid(pl) and pl.global_position.distance_to(pos) < 44.0 and pl.has_method("apply_poison"):
			pl.apply_poison(2.0, 4.0)
		cloud.modulate.a = maxf(0.0, 1.0 - elapsed[0] / 5.0)
		if elapsed[0] >= 5.0:
			cloud.queue_free())

# WAILER -- shrieks an expanding sonic ring that DISORIENTS if it catches you.
func act_wailer(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = -sign(dx) * move_speed if dist < 180.0 else 0.0
	if cast_timer <= 0.0 and not is_casting:
		cast_timer = WAILER_CD
		wail()

func wail() -> void:
	is_casting = true
	set_flash(accent_color)
	spawn_sigil(global_position + Vector2(0, -18), WAILER_RADIUS, WAILER_TELEGRAPH, accent_color)
	await get_tree().create_timer(WAILER_TELEGRAPH).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	_burst(global_position + Vector2(0, -18), WAILER_RADIUS, accent_color)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < WAILER_RADIUS:
		if player.has_method("take_damage"): player.take_damage(int(round(attack_damage * 0.6)))
		if player.has_method("apply_disorient"): player.apply_disorient(2.0)
	is_casting = false

# BONE BALLISTA -- roots, telegraphs a long aim line, then fires a fast piercing bolt.
func act_ballista(delta: float) -> void:
	velocity.x = 0.0
	face_player()
	if cast_timer <= 0.0 and not is_casting and global_position.distance_to(player.global_position) < 900.0:
		cast_timer = BALLISTA_CD
		ballista_fire()

func ballista_fire() -> void:
	is_casting = true
	var dir = (player.global_position - global_position).normalized()
	var sight = Line2D.new()
	sight.width = 2.0
	sight.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.5)
	sight.z_index = 5
	sight.points = PackedVector2Array([global_position + Vector2(0, -18), global_position + Vector2(0, -18) + dir * 900.0])
	get_parent().add_child(sight)
	set_flash(accent_color)
	await get_tree().create_timer(BALLISTA_WINDUP).timeout
	if is_instance_valid(sight): sight.queue_free()   # free the sight line even if self died
	if not is_instance_valid(self):        # died mid-windup -> don't touch the freed mob
		return
	clear_flash()
	if is_dead or not is_instance_valid(player):
		is_casting = false
		return
	var shot_dir = (player.global_position - global_position).normalized()
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + Vector2(0, -18) + shot_dir * 24.0
	arrow.setup(shot_dir, attack_damage, 22.0, 34.0, 6, true, 1100.0)   # fast, big, pierces
	get_parent().add_child(arrow)
	is_casting = false

# HIVE MAW -- coughs a burst of homing gnats (small cursed orbs).
func act_swarm(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = -sign(dx) * move_speed if dist < 240.0 else 0.0
	if cast_timer <= 0.0 and dist < 620.0:
		cast_timer = SWARM_CD
		for i in range(SWARM_COUNT):
			var base = (player.global_position - global_position).normalized()
			var d = base.rotated(deg_to_rad(randf_range(-40.0, 40.0)))
			var orb = MAGIC_ORB.new()
			orb.setup(d, maxi(1, int(round(attack_damage * 0.6))), accent_color, 165.0)
			orb.position = position + Vector2(randf_range(-8, 8), -16)
			get_parent().add_child(orb)

# RIMEWISP -- kites; a frost bolt that FREEZES + drops a lingering ice patch.
func act_frostling(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 220.0: velocity.x = -sign(dx) * move_speed
	elif dist > 460.0: velocity.x = sign(dx) * move_speed
	else: velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting and dist < 560.0:
		cast_timer = FROST_CD
		frost_cast()

func frost_cast() -> void:
	is_casting = true
	set_flash(accent_color)
	var at = Vector2(player.global_position.x, player.global_position.y)
	spawn_sigil(at, 40.0, 0.6, accent_color)
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):        # died mid-telegraph -> don't touch the freed mob
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	_burst(at, 44.0, accent_color)
	if is_instance_valid(player) and player.global_position.distance_to(at) < 48.0:
		if player.has_method("take_damage"): player.take_damage(int(round(attack_damage * 0.6)))
		if player.has_method("apply_freeze"): player.apply_freeze(0.9)
	spawn_frost_patch(at)
	is_casting = false

func spawn_frost_patch(pos: Vector2) -> void:
	var patch = poly(circle_points(46.0, 20))
	patch.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.30)
	patch.global_position = pos
	patch.z_index = 3
	get_parent().add_child(patch)
	# self-managing (see spawn_gas): the patch slows whoever stands on it, then frees.
	var pl := player
	var timer := Timer.new()
	timer.wait_time = 0.35
	timer.autostart = true
	patch.add_child(timer)
	var elapsed := [0.0]
	timer.timeout.connect(func():
		elapsed[0] += 0.35
		if is_instance_valid(pl) and pl.global_position.distance_to(pos) < 50.0 and pl.has_method("apply_slow"):
			pl.apply_slow(0.5, 0.5)
		patch.modulate.a = maxf(0.0, 1.0 - elapsed[0] / 4.0)
		if elapsed[0] >= 4.0:
			patch.queue_free())

# ── SENTINEL: a rooted turret that SWEEPS a searing beam across an arc (weave through) ──
func act_sentinel(_delta: float) -> void:
	velocity.x = 0.0
	face_player()
	if cast_timer <= 0.0 and not is_casting and global_position.distance_to(player.global_position) < SENTINEL_RANGE + 60.0:
		cast_timer = SENTINEL_CD
		sentinel_sweep()

func sentinel_sweep() -> void:
	is_casting = true
	var mid := (player.global_position - (global_position + Vector2(0, -18))).angle()
	spawn_sigil(global_position + Vector2(0, -18), 26.0, SENTINEL_TELEGRAPH, accent_color)
	set_flash(accent_color)
	await get_tree().create_timer(SENTINEL_TELEGRAPH).timeout
	if not is_instance_valid(self):
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	var beam := Line2D.new()
	beam.width = 5.0
	beam.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.85)
	beam.z_index = 5
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = mat
	get_parent().add_child(beam)
	get_tree().create_timer(2.0).timeout.connect(beam.queue_free)   # failsafe free even if we die
	var a0 := mid - deg_to_rad(SENTINEL_ARC * 0.5)
	var id := get_instance_id()
	var hit := false
	for i in range(SENTINEL_STEPS + 1):
		var s = instance_from_id(id)
		if s == null or not is_instance_valid(s) or s.is_dead:
			break
		var ang: float = a0 + deg_to_rad(SENTINEL_ARC) * (float(i) / float(SENTINEL_STEPS))
		var o: Vector2 = s.global_position + Vector2(0, -18)
		beam.points = PackedVector2Array([o, o + Vector2(cos(ang), sin(ang)) * SENTINEL_RANGE])
		if not hit and is_instance_valid(s.player):
			var to_p: Vector2 = s.player.global_position - o
			if to_p.length() < SENTINEL_RANGE and absf(wrapf(to_p.angle() - ang, -PI, PI)) < deg_to_rad(7.0):
				hit = true
				if s.player.has_method("take_damage"): s.player.take_damage(int(round(s.attack_damage * 0.6)))
		await get_tree().create_timer(0.03).timeout
	if is_instance_valid(beam):
		beam.queue_free()
	var s2 = instance_from_id(id)
	if s2 != null and is_instance_valid(s2):
		s2.is_casting = false

# ── BROOD: rushes in; on death it SPLITS into two smaller broods (see die()) ──
func act_brood(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	if is_on_floor():                                   # a bloated sac BOUNCES toward you in hops
		if _hop_cd <= 0.0:
			_hop_cd = 0.7
			velocity.y = -260.0
			velocity.x = signf(dx) * move_speed * 2.2
		else:
			_hop_cd -= delta
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
	# airborne: keep the hop's momentum (don't touch velocity.x)
	if global_position.distance_to(player.global_position) < 44.0 and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 0.8

# ── ARCBINDER: telegraphs a spot, then a hitscan CHAIN bolt jolts + slows if you linger ──
func act_arcbinder(_delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	if dist < 200.0: velocity.x = -sign(dx) * move_speed
	elif dist > 480.0: velocity.x = sign(dx) * move_speed
	else: velocity.x = 0.0
	if cast_timer <= 0.0 and not is_casting and dist < ARC_RANGE:
		cast_timer = ARC_CD
		arc_strike()

func arc_strike() -> void:
	is_casting = true
	set_flash(accent_color)
	var mark = Vector2(player.global_position.x, player.global_position.y)   # snipes THIS spot -- move off it
	spawn_sigil(mark, ARC_HIT_RADIUS, ARC_TELEGRAPH, accent_color)
	await get_tree().create_timer(ARC_TELEGRAPH).timeout
	if not is_instance_valid(self):
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	var bolt := Line2D.new()
	bolt.width = 3.0
	bolt.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.9)
	bolt.z_index = 6
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bolt.material = mat
	var o := global_position + Vector2(0, -18)
	var pts := PackedVector2Array([o])
	for i in range(1, 6):
		var b: Vector2 = o.lerp(mark, float(i) / 6.0)
		pts.append(b + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
	pts.append(mark)
	bolt.points = pts
	get_parent().add_child(bolt)
	get_tree().create_timer(0.18).timeout.connect(bolt.queue_free)
	_burst(mark, ARC_HIT_RADIUS, accent_color)
	if is_instance_valid(player) and player.global_position.distance_to(mark) < ARC_HIT_RADIUS:
		if player.has_method("take_damage"): player.take_damage(attack_damage)
		if player.has_method("apply_slow"): player.apply_slow(1.6, 0.55)
	is_casting = false

# ── WARCHIEF: melee + a periodic RAGE pulse whipping nearby special mobs faster ──
func act_warchief(_delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	var now := Time.get_ticks_msec() / 1000.0
	if now < _drum_until:                               # PLANTS and drums while it rallies
		velocity.x = 0.0
	else:                                               # otherwise a slow, heavy war-march
		velocity.x = signf(dx) * move_speed if absf(dx) > 6.0 else 0.0
	if global_position.distance_to(player.global_position) < 46.0 and attack_cooldown <= 0.0:
		deal_contact_damage()
		attack_cooldown = 1.0
	if cast_timer <= 0.0:
		cast_timer = WARCHIEF_CD
		_drum_until = now + 0.6
		rally()

func rally() -> void:
	_burst(global_position + Vector2(0, -18), WARCHIEF_AURA_RANGE * 0.4, accent_color)
	var now := Time.get_ticks_msec() / 1000.0
	for m in get_tree().get_nodes_in_group("dungeon_combatant"):
		if m == self or not is_instance_valid(m) or ("is_dead" in m and m.is_dead):
			continue
		if "_rage_until" in m and global_position.distance_to(m.global_position) < WARCHIEF_AURA_RANGE:
			m._rage_until = now + WARCHIEF_RAGE_TIME

# ── VOIDLING: darts in for a jab; BLINKS away when struck (see take_damage) ──
func act_voidling(delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	# shifty: it FLICKERS to a flank on its own now and then, never where you swung last
	if _void_repos_cd <= 0.0 and dist < 320.0:
		_void_repos_cd = randf_range(1.4, 2.4)
		spawn_teleport_puff(global_position)
		blink_to_flank()
		spawn_teleport_puff(global_position)
	else:
		_void_repos_cd -= delta
	if dist > 66.0:
		velocity.x = signf(dx) * move_speed
	else:
		velocity.x = 0.0
		if attack_cooldown <= 0.0:
			deal_contact_damage()
			attack_cooldown = 0.7

# ── GAZER: its STARE freezes -- linger in its facing cone and you slow, then freeze ──
func act_gazer(delta: float) -> void:
	velocity.x = 0.0                         # rooted, staring -- creeps nowhere
	# turns its head SLOWLY (a real turn cooldown), so a mobile player can hold its blind side
	if _turn_cd > 0.0:
		_turn_cd -= delta
	elif is_instance_valid(player):
		var dxf: float = player.global_position.x - global_position.x
		var want := 1 if dxf > 0.0 else -1
		if want != facing and absf(dxf) > 20.0:
			facing = want
			_turn_cd = 1.1
	if not is_instance_valid(player):
		_gaze_accum = 0.0
		return
	var to_p := player.global_position - (global_position + Vector2(0, -18))
	var facing_ang := 0.0 if facing >= 0 else PI
	var in_cone := to_p.length() < GAZE_RANGE and absf(wrapf(to_p.angle() - facing_ang, -PI, PI)) < deg_to_rad(GAZE_HALF_ANGLE)
	if in_cone:
		_gaze_accum += delta
		if player.has_method("apply_slow"):
			player.apply_slow(0.3, clampf(0.9 - _gaze_accum * 0.4, 0.3, 0.9))
		if _gaze_accum >= GAZE_FREEZE_TIME:
			if player.has_method("apply_freeze"): player.apply_freeze(0.8)
			if player.has_method("take_damage"): player.take_damage(int(round(attack_damage * 0.5)))
			# a NEGATIVE reset guarantees a real free window after the 0.8s freeze wears off:
			# the player can't leave the cone while frozen, so without this the gaze re-locks
			# almost at once -- and the game never permanently locks control.
			_gaze_accum = -GAZE_FREEZE_TIME * 0.5
	else:
		_gaze_accum = maxf(0.0, _gaze_accum - delta * 1.5)

# ── SKYCALLER: calls a RAIN of falling strikes across the ground around you ──
func act_skycaller(_delta: float) -> void:
	face_player()
	var dist = global_position.distance_to(player.global_position)
	var dx = player.global_position.x - global_position.x
	velocity.x = -sign(dx) * move_speed if dist < 220.0 else 0.0
	if cast_timer <= 0.0 and not is_casting and dist < 640.0:
		cast_timer = SKY_CD
		sky_rain()

func sky_rain() -> void:
	is_casting = true
	set_flash(accent_color)
	var marks := []
	var py := player.global_position.y
	for i in range(SKY_COUNT):
		var mk := Vector2(player.global_position.x + randf_range(-160.0, 160.0), py)
		marks.append(mk)
		spawn_sigil(mk, SKY_RADIUS, SKY_TELEGRAPH, accent_color)
	await get_tree().create_timer(SKY_TELEGRAPH).timeout
	if not is_instance_valid(self):
		return
	clear_flash()
	if is_dead:
		is_casting = false
		return
	for mk in marks:
		var streak := Line2D.new()
		streak.width = 3.0
		streak.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.8)
		streak.z_index = 6
		streak.points = PackedVector2Array([mk + Vector2(0, -220), mk])
		get_parent().add_child(streak)
		get_tree().create_timer(0.16).timeout.connect(streak.queue_free)
		_burst(mk, SKY_RADIUS, accent_color)
		if is_instance_valid(player) and player.global_position.distance_to(mk) < SKY_RADIUS:
			if player.has_method("take_damage"): player.take_damage(int(round(attack_damage * 0.7)))
	is_casting = false

# ── VAMPIRE: a leaper whose bite DRAINS life to heal itself ──
func act_vampire(delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	var dist = global_position.distance_to(player.global_position)
	if dist < VAMP_HIT_RANGE and attack_cooldown <= 0.0:
		attack_cooldown = 0.85
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(attack_damage)
			health = mini(max_health, health + int(round(attack_damage * VAMP_LIFESTEAL)))
			update_health_bar()
			var spark := poly(circle_points(6.0)); spark.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.7)
			spark.global_position = global_position + Vector2(0, -20); spark.z_index = 8
			get_parent().add_child(spark)
			var t := spark.create_tween(); t.tween_property(spark, "modulate:a", 0.0, 0.4); t.tween_callback(spark.queue_free)
	if is_on_floor():                                   # a LEAPER: pounces in arcs, creeps between
		if dist > VAMP_HIT_RANGE and dist < 280.0 and _pounce_cd <= 0.0:
			_pounce_cd = 1.5
			velocity.y = -300.0
			velocity.x = signf(dx) * move_speed * 2.4
		else:
			_pounce_cd -= delta
			velocity.x = signf(dx) * move_speed * 0.5 if dist > VAMP_HIT_RANGE else 0.0
	# airborne: keep the leap's momentum

# ── JUGGERNAUT: near-immune behind its GUARD; drops it to slam, then guards again ──
func act_juggernaut(_delta: float) -> void:
	var dx = player.global_position.x - global_position.x
	match charge_state:
		"seek":
			_jug_open = false
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			charge_state = "guard"
			state_timer = JUG_GUARD_TIME
		"guard":
			velocity.x = sign(dx) * move_speed if absf(dx) > 6.0 else 0.0
			if state_timer <= 0.0:
				charge_state = "open"
				state_timer = 0.5
				set_flash(accent_color)          # tell: the guard drops
		"open":
			_jug_open = true
			velocity.x = 0.0
			if state_timer <= 0.0:
				clear_flash()
				if global_position.distance_to(player.global_position) < JUG_SLAM_RANGE:
					_burst(global_position + Vector2(0, -18), JUG_SLAM_RANGE, accent_color)
					if is_instance_valid(player) and player.has_method("take_damage"): player.take_damage(attack_damage)
				charge_state = "recover"
				state_timer = JUG_OPEN_TIME
		"recover":
			_jug_open = true                     # stays vulnerable through the recovery -- your window
			velocity.x = 0.0
			if state_timer <= 0.0:
				charge_state = "seek"

# --- caster/teleport helpers ---

func face_player() -> void:
	if player != null and is_instance_valid(player):
		var dx = player.global_position.x - global_position.x
		if absf(dx) > 4.0:
			facing = 1 if dx > 0 else -1

func arena_width() -> float:
	var s = get_tree().current_scene
	if s != null and "current_width" in s:
		return s.current_width
	return 2600.0

func teleport_to(target: Vector2) -> void:
	spawn_teleport_puff(global_position)
	var w = arena_width()
	global_position = Vector2(clampf(target.x, 70.0, w - 70.0), target.y)
	spawn_teleport_puff(global_position)
	modulate.a = 0.25
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func blink_to_flank() -> void:
	var side = 1.0 if randf() < 0.5 else -1.0
	teleport_to(Vector2(player.global_position.x + side * BLINK_FLANK_DIST, player.global_position.y))

func spawn_teleport_puff(p: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = p + Vector2(0, -18)
	particles.z_index = 9
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 10
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	particles.color = accent_color
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)

func spawn_sigil(pos: Vector2, radius: float, duration: float, color: Color) -> void:
	var ring = poly(circle_points(radius, 24))
	ring.color = Color(color.r, color.g, color.b, 0.25)
	ring.global_position = pos
	ring.z_index = 4
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_loops(int(duration / 0.16) + 1)
	t.tween_property(ring, "modulate:a", 0.15, 0.08)
	t.tween_property(ring, "modulate:a", 0.7, 0.08)
	get_tree().create_timer(duration).timeout.connect(ring.queue_free)

func erupt_rune(pos: Vector2) -> void:
	var burst = poly(circle_points(RUNE_RADIUS, 24))
	burst.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.55)
	burst.global_position = pos
	burst.z_index = 6
	burst.scale = Vector2(0.2, 0.2)
	get_parent().add_child(burst)
	var t = burst.create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2.ONE, 0.2)
	t.tween_property(burst, "modulate:a", 0.0, 0.28)
	t.chain().tween_callback(burst.queue_free)

# --- shared combat ---

func deal_contact_damage() -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func fire_projectile(dir: Vector2, dmg: int) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + Vector2(0, -16) + dir * 22.0
	arrow.setup(dir.normalized(), dmg, 10.0, 20.0, 2, true, 560.0)
	get_parent().add_child(arrow)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Ironclad: nearly every blow rings off its raised guard -- only when it drops to slam
	# (_jug_open) is it truly vulnerable. Never fully immune (min 1), so it can't stall.
	if kind == "juggernaut" and not _jug_open:
		amount = maxi(1, int(round(amount * JUG_SHIELD_FRAC)))
	# Bulwark: a fifth of every blow rings off its hide
	if affix == "bulwark":
		amount = maxi(1, int(round(amount * (1.0 - BULWARK_FRAC))))
	health -= amount
	update_health_bar()
	# Thorned: striking it up close bites back
	if affix == "thorned" and is_instance_valid(player) and not ("is_dead" in player and player.is_dead) \
			and global_position.distance_to(player.global_position) <= THORN_RANGE \
			and player.has_method("take_damage"):
		player.take_damage(maxi(1, int(round(amount * THORN_FRAC))))
	if health <= 0:
		die()
	else:
		# Blinking: struck, it flickers a short step away
		var now := Time.get_ticks_msec() / 1000.0
		if affix == "blinking" and now >= _blink_ready_at:
			_blink_ready_at = now + BLINK_CD
			var away := 1.0 if (not is_instance_valid(player) or global_position.x <= player.global_position.x) else -1.0
			global_position.x += -away * 140.0 if randf() < 0.5 else away * 140.0
			play_sfx(SFX_BLINK)
		# Voidling: its defining evasion -- struck, it BLINKS away (its own quick cooldown)
		var nowv := Time.get_ticks_msec() / 1000.0
		if kind == "voidling" and nowv >= _dodge_ready_at and is_instance_valid(player):
			_dodge_ready_at = nowv + VOID_DODGE_CD
			spawn_teleport_puff(global_position)
			var vaway := 1.0 if global_position.x <= player.global_position.x else -1.0
			global_position.x = clampf(global_position.x - vaway * VOID_BLINK_DIST, 50.0, arena_width() - 50.0)
			spawn_teleport_puff(global_position)
			play_sfx(SFX_BLINK)
		set_flash(Color(1, 1, 1))
		get_tree().create_timer(0.12).timeout.connect(clear_flash)
		play_sfx(SFX_HIT)

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	# Re-resolve self through its id after the wait: a DoT tick can kill+queue_free
	# this mob mid-knockback, and writing is_knocked_back on the freed instance when
	# the timer resumes is a use-after-free. instance_from_id returns null once freed.
	var id := get_instance_id()
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	var s = instance_from_id(id)
	if s != null and is_instance_valid(s) and not s.is_dead:
		s.is_knocked_back = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	var p = get_tree().get_first_node_in_group("player")
	var depth: float = GameState.depth_reward_mult()
	if p and p.has_method("add_currency"):
		p.add_currency(int(round(reward * depth * (1.0 + GameState.get_bonus_total("gold_gain")))))
	GameState.add_xp(int(round(xp_reward * depth)))
	if kind == "brood" and split_gen == 0:
		_spawn_brood_splits()
	spawn_death_particles()
	died.emit()
	queue_free()

func _spawn_brood_splits() -> void:
	# two smaller broods burst out and JOIN the floor's live count -- so the floor can't be
	# declared cleared while they live (same contract as summoner minions). Gen-1 won't split.
	var director = get_tree().get_first_node_in_group("level_director")
	for i in range(BROOD_SPLITS):
		var b = get_script().new()
		b.kind = "brood"
		b.split_gen = 1
		b.wave_hp_multiplier = wave_hp_multiplier * 0.5
		b.wave_damage_multiplier = wave_damage_multiplier * 0.7
		b.wave_speed_multiplier = wave_speed_multiplier * 1.15
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(randf_range(-24, 24), -4)
		b.scale = Vector2(0.7, 0.7)
		if director != null and director.has_method("register_extra_combatant"):
			director.register_extra_combatant(b)

# --- visuals ---

func set_flash(c: Color) -> void:
	if mob_sprite:
		mob_sprite.modulate = Color(2.2, 2.2, 2.2)
	for entry in visual_parts:
		if is_instance_valid(entry[0]):
			entry[0].color = c

func clear_flash() -> void:
	if mob_sprite:
		mob_sprite.modulate = Color(1, 1, 1)
	for entry in visual_parts:
		if is_instance_valid(entry[0]):
			entry[0].color = entry[1]

func add_part(node: CanvasItem, color: Color) -> void:
	node.color = color
	visual.add_child(node)
	visual_parts.append([node, color])

func build_visual() -> void:
	visual = Node2D.new()
	add_child(visual)
	if EnemySkins.is_per_frame(kind, MOB_ROOT):
		_build_mob_sprite()
		return
	match kind:
		"flyer": build_flyer_visual()
		"bomber": build_bomber_visual()
		"charger": build_charger_visual()
		"spitter": build_spitter_visual()
		"stalker": build_stalker_visual()
		"blink_archer": build_blink_archer_visual()
		"hexer": build_hexer_visual()
		"runecaster": build_runecaster_visual()
		"warlock": build_warlock_visual()
		"weaver": build_weaver_visual()
		"leech": build_leech_visual()
		"burrower": build_burrower_visual()
		"warper": build_warper_visual()
		"plague": build_plague_visual()
		"wailer": build_wailer_visual()
		"ballista": build_ballista_visual()
		"swarm": build_swarm_visual()
		"frostling": build_frostling_visual()
		"sentinel": build_sentinel_visual()
		"brood": build_brood_visual()
		"arcbinder": build_arcbinder_visual()
		"warchief": build_warchief_visual()
		"voidling": build_voidling_visual()
		"gazer": build_gazer_visual()
		"skycaller": build_skycaller_visual()
		"vampire": build_vampire_visual()
		"juggernaut": build_juggernaut_visual()

# Skinned mob body: normalized to MOB_SPRITE_H, feet planted on visual-local
# y=0 (the same ground line the polygon builds draw up from). Facing rides the
# existing visual.scale.x flip; idle/walk swap from movement each frame.
func _build_mob_sprite() -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(kind, MOB_ROOT)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := MOB_SPRITE_H / EnemySkins.content_height(kind, MOB_ROOT)
	spr.scale = Vector2(sc, sc)
	spr.offset = Vector2(-EnemySkins.hcenter_px(kind, MOB_ROOT), -EnemySkins.feet_px(kind, MOB_ROOT))
	if spr.sprite_frames.has_animation("idle"):
		spr.play("idle")
	visual.add_child(spr)
	mob_sprite = spr

func _update_mob_anim() -> void:
	if mob_sprite == null:
		return
	var want := "walk" if velocity.length() > 8.0 else "idle"
	var sf := mob_sprite.sprite_frames
	if sf and sf.has_animation(want) and mob_sprite.animation != want:
		mob_sprite.play(want)

func poly(points: PackedVector2Array) -> Polygon2D:
	var p = Polygon2D.new()
	p.polygon = points
	return p

func circle_points(r: float, _segs: int = 8) -> PackedVector2Array:
	# chunky octagon (flats up/down) -- squarish pixel-art theme
	var pts = PackedVector2Array()
	for i in range(8):
		pts.append(Vector2(cos((i + 0.5) * TAU / 8), sin((i + 0.5) * TAU / 8)) * r)
	return pts

const BONE := Color(0.8, 0.78, 0.7)

# Gloomeye -- a hovering skull shrouded in tattered darkness, one burning eye.
func build_flyer_visual() -> void:
	# ragged dark wings
	add_part(poly(PackedVector2Array([Vector2(-11, -20), Vector2(-33, -30), Vector2(-25, -16), Vector2(-35, -8), Vector2(-20, -11)])), main_color.darkened(0.3))
	add_part(poly(PackedVector2Array([Vector2(11, -20), Vector2(33, -30), Vector2(25, -16), Vector2(35, -8), Vector2(20, -11)])), main_color.darkened(0.3))
	# jagged shroud / skull body
	var body = poly(PackedVector2Array([Vector2(-13, -4), Vector2(-11, -23), Vector2(0, -31), Vector2(11, -23), Vector2(13, -4), Vector2(5, -9), Vector2(0, -1), Vector2(-5, -9)]))
	body.position = Vector2(0, 0)
	add_part(body, main_color)
	# hollow socket with a single glowing pupil
	var socket = poly(circle_points(6.0))
	socket.position = Vector2(0, -17)
	add_part(socket, Color(0.04, 0.03, 0.06))
	var pupil = poly(circle_points(3.0))
	pupil.position = Vector2(0, -17)
	add_part(pupil, accent_color)
	# bony brow ridge
	add_part(poly(PackedVector2Array([Vector2(-8, -23), Vector2(8, -23), Vector2(0, -19)])), BONE)

# Festerling -- a bloated rotting corpse studded with glowing pustules.
func build_bomber_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-16, 0), Vector2(-14, -20), Vector2(-3, -30), Vector2(11, -27), Vector2(16, -12), Vector2(11, 0)]))
	add_part(body, main_color)
	# glowing rupture-line down the middle (about to burst)
	add_part(poly(PackedVector2Array([Vector2(-2, -26), Vector2(2, -26), Vector2(1, -3), Vector2(-1, -3)])), accent_color.darkened(0.05))
	# pustules
	for p in [Vector2(-7, -16), Vector2(6, -9), Vector2(-2, -23), Vector2(9, -20)]:
		var b = poly(circle_points(3.0))
		b.position = p
		add_part(b, accent_color)
	# sunken dark eye sockets
	for sx in [-5, 6]:
		var s = poly(circle_points(2.4))
		s.position = Vector2(sx, -14)
		add_part(s, Color(0.04, 0.05, 0.03))

# Gravehound -- a low skeletal beast, horned, with bared ribs.
func build_charger_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-24, -6), Vector2(14, -8), Vector2(22, -21), Vector2(-14, -25), Vector2(-26, -16)]))
	add_part(body, main_color)
	# forward horn
	add_part(poly(PackedVector2Array([Vector2(20, -18), Vector2(42, -15), Vector2(20, -9)])), BONE)
	# bared ribs
	for rx in [-16, -9, -2]:
		var rib = Line2D.new()
		rib.points = PackedVector2Array([Vector2(rx, -7), Vector2(rx, -20)])
		rib.width = 1.5
		rib.default_color = BONE.darkened(0.15)
		visual.add_child(rib)
	# burning eye
	var eye = poly(circle_points(3.0))
	eye.position = Vector2(11, -20)
	add_part(eye, Color(1.0, 0.28, 0.15))

# Bilespitter -- a squat diseased corpse-toad with a fanged maw.
func build_spitter_visual() -> void:
	var body = poly(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(16, -25), Vector2(-16, -25)]))
	add_part(body, main_color)
	# gaping dark maw
	add_part(poly(PackedVector2Array([Vector2(-13, -11), Vector2(13, -11), Vector2(10, -2), Vector2(-10, -2)])), Color(0.07, 0.11, 0.05))
	# fangs
	add_part(poly(PackedVector2Array([Vector2(-10, -11), Vector2(-7, -4), Vector2(-4, -11)])), BONE)
	add_part(poly(PackedVector2Array([Vector2(10, -11), Vector2(7, -4), Vector2(4, -11)])), BONE)
	# glowing eyes + boils
	for sx in [-8, 8]:
		var eye = poly(circle_points(3.2))
		eye.position = Vector2(sx, -19)
		add_part(eye, accent_color)
	for p in [Vector2(-14, -6), Vector2(14, -8)]:
		var boil = poly(circle_points(2.6))
		boil.position = p
		add_part(boil, accent_color.darkened(0.1))

# Blink Stalker -- a hooded cloaked assassin with a bared dagger.
func build_stalker_visual() -> void:
	add_part(poly(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(9, -30), Vector2(-9, -30)])), main_color)
	add_part(poly(PackedVector2Array([Vector2(-9, -26), Vector2(9, -26), Vector2(6, -44), Vector2(-6, -44)])), main_color.darkened(0.25))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -35)
		add_part(e, accent_color)
	add_part(poly(PackedVector2Array([Vector2(12, -16), Vector2(22, -20), Vector2(13, -11)])), Color(0.72, 0.72, 0.78))

# Revenant Archer -- a bony archer: ribbed torso, skull, and a bow.
func build_blink_archer_visual() -> void:
	add_part(poly(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -26), Vector2(-7, -26)])), main_color)
	for ry in [-6, -12, -18]:
		var rib = Line2D.new()
		rib.points = PackedVector2Array([Vector2(-7, ry), Vector2(7, ry)])
		rib.width = 1.2
		rib.default_color = BONE.darkened(0.1)
		visual.add_child(rib)
	var skull = poly(circle_points(7.0))
	skull.position = Vector2(0, -33)
	add_part(skull, BONE)
	for sx in [-2.6, 2.6]:
		var s = poly(circle_points(1.8))
		s.position = Vector2(sx, -33)
		add_part(s, accent_color)
	var bow = Line2D.new()
	bow.points = PackedVector2Array([Vector2(14, -30), Vector2(20, -16), Vector2(14, -2)])
	bow.width = 2.0
	bow.default_color = Color(0.35, 0.24, 0.16)
	visual.add_child(bow)

# Hexer -- a hunched robed mage cradling a glowing hex-orb.
func build_hexer_visual() -> void:
	_robe(main_color)
	add_part(poly(PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(7, -44), Vector2(-7, -44)])), main_color.darkened(0.2))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -36)
		add_part(e, accent_color)
	var orb = poly(circle_points(6.0))
	orb.position = Vector2(13, -10)
	add_part(orb, accent_color)

# Runecaster -- a tall pointed-hat mage with a rune staff.
func build_runecaster_visual() -> void:
	_robe(main_color)
	# tall witch hat
	add_part(poly(PackedVector2Array([Vector2(-11, -26), Vector2(11, -26), Vector2(2, -52)])), main_color.darkened(0.15))
	var e = poly(circle_points(2.2))
	e.position = Vector2(0, -30)
	add_part(e, accent_color)
	var staff = Line2D.new()
	staff.points = PackedVector2Array([Vector2(-14, 2), Vector2(-14, -34)])
	staff.width = 2.5
	staff.default_color = Color(0.3, 0.2, 0.12)
	visual.add_child(staff)
	var tip = poly(circle_points(4.5))
	tip.position = Vector2(-14, -36)
	add_part(tip, accent_color)

# Warlock -- a horned-hood mage with a cursed orb orbiting overhead.
func build_warlock_visual() -> void:
	_robe(main_color)
	add_part(poly(PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(7, -42), Vector2(-7, -42)])), main_color.darkened(0.2))
	# horns
	add_part(poly(PackedVector2Array([Vector2(-7, -40), Vector2(-13, -54), Vector2(-3, -42)])), accent_color)
	add_part(poly(PackedVector2Array([Vector2(7, -40), Vector2(13, -54), Vector2(3, -42)])), accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8))
		e.position = Vector2(sx, -34)
		add_part(e, accent_color)
	var orb = poly(circle_points(5.0))
	orb.position = Vector2(0, -58)
	add_part(orb, accent_color)

func _robe(color: Color) -> void:
	add_part(poly(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(10, -30), Vector2(-10, -30)])), color)

# --- the 9 new mobs' silhouettes (simple, distinct) ---
func build_weaver_visual() -> void:      # bulbous spider-mage
	var ab = poly(circle_points(14.0)); ab.position = Vector2(0, -12); add_part(ab, main_color)
	var head = poly(circle_points(8.0)); head.position = Vector2(0, -26); add_part(head, main_color.darkened(0.15))
	for sx in [-3, 3]:
		var e = poly(circle_points(2.0)); e.position = Vector2(sx, -27); add_part(e, accent_color)
	for lx in [-1, 1]:
		for ly in [-8, -16]:
			var leg = Line2D.new(); leg.points = PackedVector2Array([Vector2(lx * 10, ly), Vector2(lx * 24, ly - 6)])
			leg.width = 1.5; leg.default_color = main_color.darkened(0.3); visual.add_child(leg)

func build_leech_visual() -> void:       # segmented worm with a sucker maw
	add_part(poly(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -30), Vector2(-7, -30)])), main_color)
	for ry in [-6, -14, -22]:
		var seg = Line2D.new(); seg.points = PackedVector2Array([Vector2(-8, ry), Vector2(8, ry)])
		seg.width = 1.5; seg.default_color = main_color.darkened(0.2); visual.add_child(seg)
	var maw = poly(circle_points(5.0)); maw.position = Vector2(0, -30); add_part(maw, accent_color)

func build_burrower_visual() -> void:    # low armoured digger with claws
	add_part(poly(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(14, -20), Vector2(-14, -20)])), main_color)
	add_part(poly(PackedVector2Array([Vector2(-22, -6), Vector2(-30, -2), Vector2(-20, -12)])), BONE)
	add_part(poly(PackedVector2Array([Vector2(22, -6), Vector2(30, -2), Vector2(20, -12)])), BONE)
	for sx in [-6, 6]:
		var e = poly(circle_points(2.0)); e.position = Vector2(sx, -13); add_part(e, accent_color)

func build_warper_visual() -> void:      # rift-mage with a swirling core
	_robe(main_color)
	add_part(poly(PackedVector2Array([Vector2(-10, -26), Vector2(10, -26), Vector2(6, -44), Vector2(-6, -44)])), main_color.darkened(0.2))
	var rift = poly(circle_points(7.0)); rift.position = Vector2(0, -16); add_part(rift, accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.6)); e.position = Vector2(sx, -36); add_part(e, accent_color)

func build_plague_visual() -> void:      # bloated boil-covered corpse
	add_part(poly(PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(11, -26), Vector2(-11, -30), Vector2(-15, -14)])), main_color)
	for p in [Vector2(-7, -16), Vector2(6, -10), Vector2(-2, -24), Vector2(9, -20), Vector2(0, -6)]:
		var boil = poly(circle_points(3.0)); boil.position = p; add_part(boil, accent_color)

func build_wailer_visual() -> void:      # gaunt screamer, wide maw
	_robe(main_color)
	var head = poly(circle_points(8.0)); head.position = Vector2(0, -34); add_part(head, main_color.darkened(0.1))
	add_part(poly(PackedVector2Array([Vector2(-4, -33), Vector2(4, -33), Vector2(3, -26), Vector2(-3, -26)])), Color(0.05, 0.03, 0.06))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.6)); e.position = Vector2(sx, -38); add_part(e, accent_color)

func build_ballista_visual() -> void:    # squat siege corpse with a bolt-arm
	add_part(poly(PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(16, -22), Vector2(-16, -22)])), main_color)
	var arm = Line2D.new(); arm.points = PackedVector2Array([Vector2(-18, -14), Vector2(20, -14)])
	arm.width = 4.0; arm.default_color = BONE.darkened(0.1); visual.add_child(arm)
	add_part(poly(PackedVector2Array([Vector2(18, -17), Vector2(34, -14), Vector2(18, -11)])), accent_color)
	for sx in [-8, 8]:
		var e = poly(circle_points(2.4)); e.position = Vector2(sx, -15); add_part(e, accent_color)

func build_swarm_visual() -> void:       # a gaping hive-maw
	add_part(poly(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(14, -26), Vector2(-14, -26)])), main_color)
	var maw = poly(circle_points(9.0)); maw.position = Vector2(0, -13); add_part(maw, Color(0.04, 0.05, 0.02))
	for p in [Vector2(-11, -6), Vector2(11, -8), Vector2(0, -22)]:
		var cell = poly(circle_points(2.2)); cell.position = p; add_part(cell, accent_color)

func build_frostling_visual() -> void:   # a jagged ice sprite
	add_part(poly(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(10, -16), Vector2(0, -30), Vector2(-10, -16)])), main_color)
	for p in [Vector2(-9, -10), Vector2(9, -12), Vector2(0, -22)]:
		var shard = poly(PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(0, -8)])); shard.position = p; add_part(shard, accent_color)
	var core = poly(circle_points(3.0)); core.position = Vector2(0, -14); add_part(core, accent_color.lightened(0.2))

func build_sentinel_visual() -> void:    # a rooted bone turret with a glowing lens-eye
	add_part(poly(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(12, -16), Vector2(-12, -16)])), main_color.darkened(0.2))
	var head = poly(circle_points(12.0)); head.position = Vector2(0, -26); add_part(head, main_color)
	var lens = poly(circle_points(5.0)); lens.position = Vector2(0, -26); add_part(lens, accent_color)
	var barrel = Line2D.new(); barrel.points = PackedVector2Array([Vector2(0, -26), Vector2(22, -26)]); barrel.width = 4.0; barrel.default_color = BONE.darkened(0.1); visual.add_child(barrel)

func build_brood_visual() -> void:       # a bloated wobbling egg-sac
	var body = poly(circle_points(16.0)); body.position = Vector2(0, -16); add_part(body, main_color)
	for p in [Vector2(-6, -20), Vector2(7, -14), Vector2(0, -8)]:
		var boil = poly(circle_points(3.0)); boil.position = p; add_part(boil, accent_color)
	for sx in [-5, 5]:
		var e = poly(circle_points(2.0)); e.position = Vector2(sx, -22); add_part(e, Color(0.9, 0.2, 0.2))

func build_arcbinder_visual() -> void:   # a hunched caster wreathed in a spark
	_robe(main_color)
	var head = poly(circle_points(7.0)); head.position = Vector2(0, -34); add_part(head, main_color.darkened(0.1))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.6)); e.position = Vector2(sx, -35); add_part(e, accent_color)
	var arm = Line2D.new(); arm.points = PackedVector2Array([Vector2(-10, -22), Vector2(-18, -30), Vector2(-12, -26)]); arm.width = 2.0; arm.default_color = accent_color; visual.add_child(arm)

func build_warchief_visual() -> void:    # a broad horned brute with a war-drum
	add_part(poly(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(12, -32), Vector2(-12, -32)])), main_color)
	var head = poly(circle_points(9.0)); head.position = Vector2(0, -40); add_part(head, main_color.darkened(0.1))
	for hx in [-1, 1]:
		add_part(poly(PackedVector2Array([Vector2(hx * 8, -44), Vector2(hx * 14, -52), Vector2(hx * 10, -42)])), BONE)
	var drum = poly(circle_points(10.0)); drum.position = Vector2(16, -14); add_part(drum, accent_color.darkened(0.2))
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8)); e.position = Vector2(sx, -41); add_part(e, accent_color)

func build_voidling_visual() -> void:    # a thin flickering wraith
	add_part(poly(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(6, -30), Vector2(0, -38), Vector2(-6, -30)])), main_color)
	var core = poly(circle_points(4.0)); core.position = Vector2(0, -22); add_part(core, accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.6)); e.position = Vector2(sx, -30); add_part(e, accent_color.lightened(0.2))

func build_gazer_visual() -> void:       # a squat body dominated by one great eye
	add_part(poly(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(10, -18), Vector2(-10, -18)])), main_color)
	var eye = poly(circle_points(11.0)); eye.position = Vector2(0, -26); add_part(eye, main_color.lightened(0.15))
	var iris = poly(circle_points(6.0)); iris.position = Vector2(0, -26); add_part(iris, accent_color)
	var pupil = poly(circle_points(2.5)); pupil.position = Vector2(0, -26); add_part(pupil, Color(0.05, 0.05, 0.05))

func build_skycaller_visual() -> void:   # a robed herald with a raised star-staff
	_robe(main_color)
	var head = poly(circle_points(7.0)); head.position = Vector2(0, -34); add_part(head, main_color.darkened(0.1))
	var staff = Line2D.new(); staff.points = PackedVector2Array([Vector2(10, -20), Vector2(16, -46)]); staff.width = 2.0; staff.default_color = BONE.darkened(0.1); visual.add_child(staff)
	var orb = poly(circle_points(4.0)); orb.position = Vector2(16, -48); add_part(orb, accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.6)); e.position = Vector2(sx, -35); add_part(e, accent_color)

func build_vampire_visual() -> void:     # a gaunt fanged stalker
	add_part(poly(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -30), Vector2(-7, -30)])), main_color)
	var head = poly(circle_points(7.0)); head.position = Vector2(0, -36); add_part(head, main_color.darkened(0.1))
	add_part(poly(PackedVector2Array([Vector2(-3, -33), Vector2(-1, -33), Vector2(-2, -29)])), BONE)
	add_part(poly(PackedVector2Array([Vector2(1, -33), Vector2(3, -33), Vector2(2, -29)])), BONE)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8)); e.position = Vector2(sx, -38); add_part(e, accent_color)

func build_juggernaut_visual() -> void:  # a heavy hulk behind a great shield
	add_part(poly(PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(14, -36), Vector2(-14, -36)])), main_color)
	var head = poly(circle_points(9.0)); head.position = Vector2(0, -42); add_part(head, main_color.darkened(0.15))
	add_part(poly(PackedVector2Array([Vector2(-24, -4), Vector2(-16, -4), Vector2(-16, -40), Vector2(-24, -36)])), accent_color.darkened(0.1))
	var bossp = poly(circle_points(4.0)); bossp.position = Vector2(-20, -22); add_part(bossp, accent_color)
	for sx in [-3, 3]:
		var e = poly(circle_points(1.8)); e.position = Vector2(sx, -43); add_part(e, Color(1.0, 0.5, 0.3))

# A pulsing additive halo that marks an elite at a glance.
func build_elite_glow() -> void:
	var glow = poly(circle_points(26.0, 20))
	glow.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = Vector2(0, -18)
	glow.z_index = -2
	add_child(glow)
	var t = glow.create_tween()
	t.set_loops()
	t.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.5)
	t.tween_property(glow, "scale", Vector2(0.9, 0.9), 0.5)

func build_health_bar() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.05, 0.05, 0.9)
	bg.size = Vector2(34, 4)
	bg.position = Vector2(-17, -48)
	bg.z_index = 20
	add_child(bg)
	health_fill = ColorRect.new()
	health_fill.color = Color(0.85, 0.25, 0.25, 1.0)
	health_fill.size = Vector2(34, 4)
	health_fill.position = Vector2(-17, -48)
	health_fill.z_index = 21
	add_child(health_fill)

func update_health_bar() -> void:
	if health_fill:
		health_fill.size.x = 34.0 * clamp(float(health) / max_health, 0.0, 1.0)

func play_sfx(stream: AudioStream) -> void:
	var p = AudioStreamPlayer2D.new()
	p.stream = stream
	p.global_position = global_position
	get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func spawn_blast() -> void:
	var ring = poly(circle_points(BOMBER_BLAST_RADIUS, 24))
	ring.color = Color(1.0, 0.55, 0.15, 0.5)
	ring.global_position = global_position + Vector2(0, -16)
	ring.z_index = 8
	ring.scale = Vector2(0.2, 0.2)
	get_parent().add_child(ring)
	var t = ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.28)
	t.tween_property(ring, "modulate:a", 0.0, 0.32)
	t.chain().tween_callback(ring.queue_free)

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position + Vector2(0, -16)
	particles.z_index = 10
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 95.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = accent_color
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)
