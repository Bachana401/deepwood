extends CharacterBody2D

const SPEED = 100.0
const GRAVITY = 900.0
# Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non
# stop follow me everywhere". Everything downstream scales off this: bows see
# 2x it, a wall-alerted mob adds WALL_DETECTION_BONUS, and the respawn-growth
# curve multiplies it -- so one number moves the whole aggro economy.
const DETECTION_RANGE = 191.0
const KNOCKBACK_DURATION = 0.12
const MAX_HEALTH = 60
const BUMP_THRESHOLD = 42.0
const RESPAWN_DELAY = 3.0
const GROWTH_PER_RESPAWN = 1.085
const BOW_RETREAT_RANGE = 90.0
const BOW_HOLD_RANGE = 180.0
const JUMP_VELOCITY = -380.0
const JUMP_COOLDOWN = 1.2
const CLIMB_JUMP_COOLDOWN = 0.45
const RANDOM_JUMP_CHANCE = 0.006
const JUMP_SEE_HEIGHT = 40.0
const HORIZONTAL_DEADZONE = 6.0
const ENEMY_ARROW_RANGE = 460.0
# MELEE IS A SIDE-SCROLLER SWING, NOT A CIRCLE. Reach used to be euclidean
# centre-to-centre distance, so a mob would "hit" a player 45px straight up on a
# ledge, and its reach felt inconsistent from every angle (dev: "attack range
# seems weird"). A swing now connects ALONG the ground -- horizontal reach with a
# small vertical give -- which is where the weapon visibly is.
const MELEE_VERTICAL_BAND = 48.0
# Melee mobs HOLD at a weapon-length and swing, instead of shoving their body into
# the player at the 6px deadzone (dev: "mobs move weird"). A wall of mobs now
# rings you at reach rather than piling into your face.
const MELEE_STANDOFF_FRACTION = 0.82
# A readable WIND-UP before the strike lands, so an incoming hit can be seen and
# answered rather than arriving out of nowhere.
const WINDUP_SWORD = 0.17
const WINDUP_SPEAR = 0.14
const WINDUP_BOW = 0.16
# SUPER-MOBS (dev: "no super mobs"). An elite is not just a bigger grunt -- it
# wears a glowing aura and a crown so you spot it across the room, calls itself
# out on spawn, and every few seconds winds up a telegraphed ground SLAM: a
# shockwave you leap over. Mechanics, not a stat wall -- and hard-capped so a
# slam can stagger you but never one-shot (the forever boss rule).
const ELITE_SLAM_START = 210.0    # a slam begins if the player is at least this close
const ELITE_SLAM_RADIUS = 155.0   # the shockwave's ground reach
const ELITE_SLAM_AIR = 96.0       # ...and its height: jump above this and it whiffs
const ELITE_SLAM_MIN = 4.0
const ELITE_SLAM_MAX = 6.5
const ELITE_WINDUP = 0.55         # the tell: long enough to read and leap
const ELITE_SLAM_DMG_MULT = 1.7
const ELITE_SLAM_HP_CAP = 0.45    # a slam can never take more than this share of max HP
const WALL_TURN_DURATION = 0.8
const WALL_NOTICE_DURATION = 3.5
const WALL_DETECTION_BONUS = 120.0
const HESITATE_MIN_INTERVAL = 1.8
const HESITATE_MAX_INTERVAL = 4.5
const HESITATE_DURATION = 0.35
const JUMP_DESYNC_GROUP_SIZE = 3
const JUMP_DESYNC_RADIUS = 260.0
const JUMP_DESYNC_MIN_DELAY = 0.05
const JUMP_DESYNC_MAX_DELAY = 0.45

const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_HIT = preload("res://audio/hit.wav")
const SFX_DEATH = preload("res://audio/enemy_death.wav")
const SFX_SWORD = preload("res://audio/sword_swing.wav")
const SFX_SPEAR = preload("res://audio/spear_thrust.wav")
const SFX_BOW = preload("res://audio/bow_shot.wav")

const WEAPONS = {
	"sword": {"damage": 10, "cooldown": 1.3, "range": 45.0, "knockback_min": 15.0, "knockback_max": 25.0, "size": Vector2(8, 28), "color": Color(0.75, 0.75, 0.8), "offset": 14.0},
	"spear": {"damage": 16, "cooldown": 1.4, "range": 65.0, "knockback_min": 25.0, "knockback_max": 35.0, "size": Vector2(50, 5), "color": Color(0.55, 0.35, 0.15), "offset": 12.0},
	"bow": {"damage": 8, "cooldown": 1.6, "range": 440.0, "knockback_min": 10.0, "knockback_max": 20.0, "size": Vector2(10, 10), "color": Color(0.45, 0.28, 0.1), "offset": 12.0},
}

# Dungeon enemy "rosters": one themed archetype per block of 5 dungeon levels.
# dungeon_interior.gd calls apply_block_archetype(block) where block =
# (level-1)/5, so levels 1-5 share roster 0, 6-10 share roster 1, and so on;
# past the end of the list it simply cycles. Each entry re-skins the plain
# enemy body (color/size), picks its weapon mix, and nudges the base stats so
# the flavor is felt in combat, not just visually.
const ENEMY_ROSTERS = [
	# 0 -- Orcs (levels 1-5): melee brutes (sprite swings a cleaver -> no bows).
	{"name": "Orc", "color": Color(0.33, 0.4, 0.29), "accent": Color(0.7, 1.0, 0.45), "scale": 1.0, "shape": "grunt", "sprite": "orc", "weapons": ["sword", "spear"], "hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.0},
	# 1 -- Blood Fiends (6-10): fast melee skirmishers (claw/lunge sprite).
	{"name": "Blood Fiend", "color": Color(0.4, 0.5, 0.6), "accent": Color(0.7, 0.92, 1.0), "scale": 0.92, "shape": "frost", "sprite": "blood_monster", "weapons": ["spear", "sword"], "hp_mult": 0.85, "dmg_mult": 1.0, "speed_mult": 1.22},
	# 2 -- Demons (11-15): heavy melee, hit hard but slow.
	{"name": "Demon", "color": Color(0.2, 0.15, 0.15), "accent": Color(1.0, 0.5, 0.12), "scale": 1.12, "shape": "ember", "sprite": "demon", "weapons": ["sword", "spear"], "hp_mult": 1.3, "dmg_mult": 1.18, "speed_mult": 0.88},
	# 3 -- Wraiths (16-20): spectral fast archers (PixelLab "wraith" skin -- looses
	# a ghostly bow; the Soldier sprite stays reserved for the village Barracks).
	{"name": "Wraith", "color": Color(0.32, 0.22, 0.42), "accent": Color(0.7, 0.4, 1.0), "scale": 0.9, "shape": "wraith", "sprite": "wraith", "weapons": ["bow", "bow", "sword"], "hp_mult": 0.78, "dmg_mult": 1.0, "speed_mult": 1.32},
	# 4 -- Bone Golems (21-25): huge tomb-bone tanks, slow, pure melee.
	{"name": "Bone Golem", "color": Color(0.52, 0.5, 0.44), "accent": Color(0.86, 0.84, 0.72), "scale": 1.28, "shape": "stone", "sprite": "bone_golem", "weapons": ["sword"], "hp_mult": 1.7, "dmg_mult": 1.22, "speed_mult": 0.78},
	# 5 -- Rotfiends (26-30): small, fast, diseased jabbers.
	{"name": "Rotfiend", "color": Color(0.28, 0.4, 0.2), "accent": Color(0.7, 1.0, 0.3), "scale": 0.84, "shape": "venom", "sprite": "rotfiend", "weapons": ["spear", "spear", "bow"], "hp_mult": 0.85, "dmg_mult": 1.12, "speed_mult": 1.26},
]

@export var weapon_type: String = "sword"
@export var base_color: Color = Color(0.6236201, 0.18110216, 0.10793113)
@export var respawns: bool = true
@export var instant_aggro: bool = false

# --- WILDERNESS MOBS (the lands east of the village) ---
# A wild mob belongs to its patch of road. It sees you far LATER than anything
# else in the game (WILD_SIGHT_MULT), and once you leave its ground it gives up
# and walks home instead of trailing you across the map. That is what makes the
# east travellable: danger you can walk away from, not a growing tail of mobs.
const WILD_SIGHT_MULT = 0.4        # 60% less sight than a normal mob
const WILD_LEASH = 460.0           # how far from home it will chase
const WILD_LEASH_HYSTERESIS = 90.0 # ...and how far back before it re-engages
var is_wild := false
var wild_home_x := 0.0
var wild_going_home := false

signal died

var direction = 1
var start_x: float
var spawn_position: Vector2
var player: Node2D = null
var health = MAX_HEALTH
var max_health = MAX_HEALTH
var damage_multiplier = 1.0
var detection_range_current = DETECTION_RANGE
var generation = 0
var is_dead = false
var is_knocked_back = false
var facing_direction = 1
var attack_cooldown_remaining = 0.0
var is_attacking = false
var jump_cooldown_remaining = 0.0
var is_wall_blocked = false
var wall_turn_timer = 0.0
var wall_notice_timer = 0.0
var frozen_for_dungeon = false
var speed_variance = 1.0
var jump_chance_variance = 1.0
var was_player_above = false
var jump_react_timer = 0.0
var hesitate_timer = 0.0
var hesitate_remaining = 0.0
var wave_hp_multiplier = 1.0
var wave_damage_multiplier = 1.0
var wave_speed_multiplier = 1.0
var character_shape := "grunt"
var accent_color := Color(0.85, 0.42, 0.3)

# --- Status effects (see apply_status). burn/poison = damage-over-time,
# freeze = stunned (can't move or attack), slow = reduced move speed. Applied
# by the player's elemental weapons/relics; a frozen or burning enemy shows a
# tinted overlay. ---
var status_burn_until := 0.0
var status_burn_dps := 0.0
var status_poison_until := 0.0
var status_poison_dps := 0.0
var status_freeze_until := 0.0
var status_slow_until := 0.0
var status_slow_factor := 1.0
# PETRIFY (Gorgon's Gaze relic, WEAPONS.md §6): turned to stone -- can't act like
# a freeze, but ALSO takes bonus damage while stoned. Its own timer + grey overlay.
var status_petrify_until := 0.0
const PETRIFY_DAMAGE_MULT := 1.5
var status_dot_accum := 0.0
var status_overlay: ColorRect = null

# --- Behavior archetype (mechanics beyond plain melee/bow). Set by spawn:
# "shield" (halves FRONTAL damage -- flank it), "caster" (fires slow-bolts),
# "healer" (mends nearby wounded allies), "summoner" (spawns minions),
# "dasher" (evasive lunges). "" = the normal grunt AI. is_elite scales it up. ---
var behavior := ""
var is_elite := false
var elite_slam_timer := 0.0
var behavior_timer := 0.0
var summoned_minions: Array = []

func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

func move_speed() -> float:
	return SPEED * speed_variance * wave_speed_multiplier * status_slow_mult()

func status_slow_mult() -> float:
	return status_slow_factor if _now_s() < status_slow_until else 1.0

func is_frozen() -> bool:
	return _now_s() < status_freeze_until

# Applies (or refreshes) a status. magnitude: DoT/sec for burn/poison, the
# speed FACTOR (<1) for slow, ignored for freeze.
func apply_status(kind: String, duration: float, magnitude: float = 0.0) -> void:
	if is_dead:
		return
	var until = _now_s() + duration
	match kind:
		"burn":
			status_burn_until = max(status_burn_until, until)
			status_burn_dps = max(status_burn_dps, magnitude)
		"poison":
			status_poison_until = max(status_poison_until, until)
			status_poison_dps = max(status_poison_dps, magnitude)
		"freeze":
			status_freeze_until = max(status_freeze_until, until)
		"slow":
			status_slow_until = max(status_slow_until, until)
			status_slow_factor = min(status_slow_factor, magnitude if magnitude > 0.0 else 0.5)
		"petrify":
			status_petrify_until = max(status_petrify_until, until)
	_refresh_status_overlay()

func is_petrified() -> bool:
	return _now_s() < status_petrify_until

func tick_statuses(delta: float) -> void:
	var now = _now_s()
	var dps := 0.0
	if now < status_burn_until:
		dps += status_burn_dps
	if now < status_poison_until:
		dps += status_poison_dps
	if dps > 0.0:
		status_dot_accum += dps * delta
		if status_dot_accum >= 1.0:
			var whole = int(status_dot_accum)
			status_dot_accum -= whole
			health -= whole
			update_health_bar()
			if health <= 0:
				die()
				return
	if now >= status_slow_until:
		status_slow_factor = 1.0
	_refresh_status_overlay()

# A translucent tint over the body showing the strongest active status.
func _refresh_status_overlay() -> void:
	var now = _now_s()
	var col := Color(0, 0, 0, 0)
	if now < status_petrify_until:
		col = Color(0.55, 0.55, 0.58, 0.7)   # stone grey (highest priority)
	elif now < status_freeze_until:
		col = Color(0.5, 0.8, 1.0, 0.5)      # icy
	elif now < status_burn_until:
		col = Color(1.0, 0.45, 0.1, 0.4)     # fiery
	elif now < status_poison_until:
		col = Color(0.5, 0.9, 0.2, 0.4)      # toxic
	elif now < status_slow_until:
		col = Color(0.6, 0.75, 1.0, 0.3)     # chilled
	if col.a == 0.0:
		if status_overlay != null and is_instance_valid(status_overlay):
			status_overlay.visible = false
		return
	if status_overlay == null or not is_instance_valid(status_overlay):
		status_overlay = ColorRect.new()
		status_overlay.size = Vector2(40, 52)
		status_overlay.position = Vector2(-20, -46)
		status_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_overlay.z_index = 5
		add_child(status_overlay)
	status_overlay.visible = true
	status_overlay.color = col

# Optional downloaded-spritesheet skin (CraftPix Tiny RPG packs, see
# art/enemies/). When an archetype sets "sprite", the plain procedural body is
# hidden and this AnimatedSprite2D drives idle/walk/attack/hurt/death instead.
const SPRITE_SCALE := 3.0          # x5 from the first pass (0.6) -- developer sizing call
const SPRITE_GROUND_Y := 20.0      # this body's ground line (collision bottom)
var sprite_skin := ""
var use_sprite := false
var enemy_sprite: AnimatedSprite2D = null

# EVERY EVIL HUNTS THE VILLAGE (dev call 2026-07-21). These mobs only ever
# chased the PLAYER -- so the opening wave, and every overworld creature,
# walked past villagers, heroes, walls and buildings as if they were scenery.
# `player` is the mob's current PREY (retargeted below, so all the existing
# chase/attack logic just works); `real_player` stays the actual hero for
# rewards. Prey is picked by nearest, with a bias for living people.
const PREY_GROUPS := ["player", "npc", "adventurer", "village_defender"]
const PREY_RETARGET_INTERVAL := 0.8
var real_player: Node2D = null
var _retarget_timer := 0.0

func _pick_prey() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for g in PREY_GROUPS:
		for c in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(c) or not c.has_method("take_damage"):
				continue
			if "is_dead" in c and c.is_dead:
				continue
			if "is_in_building" in c and c.is_in_building:
				continue      # sheltered villagers are not prey
			var d: float = global_position.distance_to(c.global_position)
			# the living are worth crossing a street for; the player is prey
			# like anyone else once something closer is screaming
			if d < best_d:
				best_d = d
				best = c
	return best if best != null else real_player

func _retarget(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer > 0.0:
		return
	_retarget_timer = PREY_RETARGET_INTERVAL
	var p := _pick_prey()
	if p != null:
		player = p

func _ready() -> void:
	start_x = global_position.x
	spawn_position = global_position
	player = get_tree().get_first_node_in_group("player")
	real_player = player
	speed_variance = randf_range(0.82, 1.22)
	jump_chance_variance = randf_range(0.5, 1.8)
	hesitate_timer = randf_range(HESITATE_MIN_INTERVAL, HESITATE_MAX_INTERVAL)
	if wave_hp_multiplier != 1.0:
		max_health = int(round(MAX_HEALTH * wave_hp_multiplier))
		health = max_health
	damage_multiplier *= wave_damage_multiplier
	setup_weapon_visual()
	update_body_color()
	build_character()
	if is_elite:
		_become_super_mob()

func update_body_color() -> void:
	$ColorRect.color = base_color.darkened(clamp(generation * 0.15, 0.0, 0.6))

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# Re-skins this enemy into the roster archetype for the given 5-level block.
# MUST be called before the node enters the tree (before _ready), because the
# wave multipliers it stacks onto are baked into max_health in _ready. It also
# chooses the weapon from the archetype's mix, so it overrides any weapon_type
# set beforehand.
func apply_block_archetype(block: int) -> void:
	apply_mixed_archetype(block, block)

# The LOOK (sprite/colour/shape/weapon) comes from visual_block; the STAT mults
# always come from stat_block -- the FLOOR's own difficulty band. So a floor can
# field a MIXED horde of monster skins (dev request 2026-07-21: "mobs mostly 1
# variety, I want them mixed") WITHOUT changing how hard the fight is: give a
# grunt a neighbour's face and it still hits and dies exactly as this floor's own.
func apply_mixed_archetype(stat_block: int, visual_block: int) -> void:
	if ENEMY_ROSTERS.is_empty():
		return
	var vd: Dictionary = ENEMY_ROSTERS[visual_block % ENEMY_ROSTERS.size()]
	base_color = vd.get("color", base_color)
	var s := float(vd.get("scale", 1.0))
	scale = Vector2(s, s)
	var weapons: Array = vd.get("weapons", [weapon_type])
	if not weapons.is_empty():
		weapon_type = weapons[randi() % weapons.size()]
	character_shape = vd.get("shape", "grunt")
	accent_color = vd.get("accent", accent_color)
	sprite_skin = vd.get("sprite", "")
	var sd: Dictionary = ENEMY_ROSTERS[stat_block % ENEMY_ROSTERS.size()]
	wave_hp_multiplier *= float(sd.get("hp_mult", 1.0))
	wave_damage_multiplier *= float(sd.get("dmg_mult", 1.0))
	wave_speed_multiplier *= float(sd.get("speed_mult", 1.0))

# Builds a distinct UNDEAD silhouette (skull/hood + bony features) on top of
# the torso ColorRect, so each roster archetype reads as its own monster. Parts
# live under a "Features" node; flash_hit/death brighten/fade it with the torso.
const BONE := Color(0.82, 0.8, 0.72)

func build_character() -> void:
	if has_node("Features"):
		$Features.queue_free()
	# A downloaded-spritesheet archetype hides the procedural body entirely and
	# animates from strips instead.
	if sprite_skin != "":
		_build_sprite_visual()
		return
	var f := Node2D.new()
	f.name = "Features"
	add_child(f)
	match character_shape:
		"frost":
			_add_skull(f, -27.0, 7.0, BONE.lerp(base_color, 0.35))
			for sx in [-8.0, 0.0, 8.0]:   # jagged frozen-bone crown
				_add_poly(f, PackedVector2Array([Vector2(sx - 3, -32), Vector2(sx + 3, -32), Vector2(sx, -48)]), BONE)
		"ember":
			_add_shoulders(f, base_color.darkened(0.12))
			_add_skull(f, -28.0, 8.0, Color(0.24, 0.19, 0.18))   # charred skull
			_add_poly(f, PackedVector2Array([Vector2(-9, -33), Vector2(-17, -49), Vector2(-4, -35)]), accent_color)   # horns
			_add_poly(f, PackedVector2Array([Vector2(9, -33), Vector2(17, -49), Vector2(4, -35)]), accent_color)
			_add_dot(f, Vector2(-6, -6), 2.5, accent_color)      # glowing ember cracks
			_add_dot(f, Vector2(5, 2), 2.0, accent_color)
		"wraith":
			# hollow hood, no face -- just two burning eyes in the dark
			_add_poly(f, PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(8, -42), Vector2(-8, -42)]), base_color.darkened(0.3))
			for sx in [-4.0, 4.0]:
				_add_dot(f, Vector2(sx, -29), 2.2, accent_color)
			# ragged spectral tatters trailing below
			_add_poly(f, PackedVector2Array([Vector2(-12, 16), Vector2(-6, 28), Vector2(0, 16), Vector2(6, 28), Vector2(12, 16)]), base_color.darkened(0.18))
		"stone":
			_add_shoulders(f, base_color.darkened(0.15))
			var head := ColorRect.new()   # heavy blocky bone skull
			head.size = Vector2(20, 18)
			head.position = Vector2(-10, -40)
			head.color = BONE.darkened(0.08)
			f.add_child(head)
			_add_socket(f, Vector2(-5, -32))
			_add_socket(f, Vector2(5, -32))
			_add_dot(f, Vector2(-5, -32), 1.4, accent_color)
			_add_dot(f, Vector2(5, -32), 1.4, accent_color)
			_add_poly(f, PackedVector2Array([Vector2(-2, -24), Vector2(2, -24), Vector2(0, -14)]), Color(0.1, 0.1, 0.1))   # crack
		"venom":
			_add_skull(f, -25.0, 6.5, BONE.lerp(base_color, 0.4))
			for p in [Vector2(-7, -2), Vector2(6, 4), Vector2(-2, 9)]:   # festering boils
				_add_dot(f, p, 2.5, accent_color)
		_:  # grunt / Ghoul
			_add_skull(f, -26.0, 7.0, BONE.lerp(base_color, 0.4))
			# hunched ragged shoulders
			_add_poly(f, PackedVector2Array([Vector2(-15, -20), Vector2(15, -20), Vector2(10, -11), Vector2(-10, -11)]), base_color.darkened(0.22))

# A skull: pale cranium, two dark sockets with glowing pupils, and jaw fangs.
func _add_skull(parent: Node2D, y: float, r: float, color: Color) -> void:
	_add_dot(parent, Vector2(0, y), r, color)
	_add_socket(parent, Vector2(-r * 0.45, y - 1.0))
	_add_socket(parent, Vector2(r * 0.45, y - 1.0))
	_add_dot(parent, Vector2(-r * 0.45, y - 1.0), 1.5, accent_color)
	_add_dot(parent, Vector2(r * 0.45, y - 1.0), 1.5, accent_color)
	_add_poly(parent, PackedVector2Array([Vector2(-r * 0.5, y + r * 0.6), Vector2(-r * 0.2, y + r * 1.3), Vector2(0, y + r * 0.6)]), color)
	_add_poly(parent, PackedVector2Array([Vector2(r * 0.5, y + r * 0.6), Vector2(r * 0.2, y + r * 1.3), Vector2(0, y + r * 0.6)]), color)

func _add_socket(parent: Node2D, pos: Vector2) -> void:
	_add_dot(parent, pos, 2.6, Color(0.05, 0.045, 0.06))

func _add_shoulders(parent: Node2D, color: Color) -> void:
	var s := ColorRect.new()
	s.size = Vector2(34, 10)
	s.position = Vector2(-17, -22)
	s.color = color
	parent.add_child(s)

func _add_poly(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	parent.add_child(p)

func _add_dot(parent: Node2D, pos: Vector2, r: float, color: Color) -> void:
	# squarish pixel-art style: dots are blocks
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	p.position = pos
	p.color = color
	parent.add_child(p)

# --- Spritesheet-skinned enemies (downloaded art) ---
# Hide the procedural body/weapon and drive an AnimatedSprite2D from combat
# state. The strips live in art/enemies/<skin>/; SpriteFrames are built once per
# skin and shared across every enemy wearing it.
func _build_sprite_visual() -> void:
	use_sprite = true
	$ColorRect.visible = false
	$WeaponIcon.visible = false
	$BowVisual.visible = false
	var spr := AnimatedSprite2D.new()
	spr.name = "Skin"
	spr.sprite_frames = EnemySkins.frames_for(sprite_skin)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # keep pixel art crisp
	# PixelLab skins normalise to a consistent on-screen height (their frames pack
	# the character tightly); CraftPix strip skins keep their approved fixed scale.
	# Per-archetype "scale" still applies via the enemy root (golems big, etc).
	var sc = (EnemySkins.TARGET_HEIGHT / EnemySkins.content_height(sprite_skin)) if EnemySkins.is_per_frame(sprite_skin) else SPRITE_SCALE
	spr.scale = Vector2(sc, sc)
	# plant the character's MEASURED feet exactly on this body's ground line:
	# (feet_px + offset) * sc == SPRITE_GROUND_Y
	spr.offset = Vector2(-EnemySkins.hcenter_px(sprite_skin), SPRITE_GROUND_Y / sc - EnemySkins.feet_px(sprite_skin))
	spr.animation = "idle"
	spr.play("idle")
	add_child(spr)
	enemy_sprite = spr
	# lift the health bar above the (much taller) sprite instead of inside it
	var bar_y = -(EnemySkins.content_height(sprite_skin) * sc) - 12.0
	$HealthBarBG.position.y = bar_y
	$HealthBarFill.position.y = bar_y

# Pick idle/walk/attack from state each frame, and face the player. (Death and
# hurt are driven from die()/flash_hit().)
func _update_enemy_anim() -> void:
	if enemy_sprite == null:
		return
	enemy_sprite.flip_h = facing_direction < 0
	var want := "idle"
	if is_attacking:
		want = "attack"
	elif absf(velocity.x) > 5.0:
		want = "walk"
	if enemy_sprite.animation != want:
		enemy_sprite.play(want)

func setup_weapon_visual() -> void:
	var stats = WEAPONS.get(weapon_type, WEAPONS["sword"])
	if weapon_type == "bow":
		$WeaponIcon.visible = false
		$BowVisual.visible = true
	else:
		$WeaponIcon.visible = true
		$BowVisual.visible = false
		$WeaponIcon.size = stats.size
		$WeaponIcon.color = stats.color
		$WeaponIcon.position.y = -stats.size.y / 2.0
		$WeaponIcon.pivot_offset = stats.size / 2.0
	update_weapon_icon_position()

func get_aim_direction() -> Vector2:
	if player != null:
		var to_player = player.global_position - global_position
		if to_player.length() > 1.0:
			return to_player.normalized()
	return Vector2(facing_direction, 0)

func update_weapon_icon_position() -> void:
	var stats = WEAPONS.get(weapon_type, WEAPONS["sword"])
	if weapon_type == "bow":
		var aim_dir = get_aim_direction()
		$BowVisual.position = aim_dir * stats.offset
		$BowVisual.rotation = aim_dir.angle()
		$BowVisual.scale = Vector2.ONE
	elif facing_direction > 0:
		$WeaponIcon.position.x = stats.offset
	else:
		$WeaponIcon.position.x = -stats.offset - stats.size.x

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_retarget(delta)

	tick_statuses(delta)
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# frozen OR petrified: rooted, can't act (still falls with gravity)
	if is_frozen() or is_petrified():
		velocity.x = 0
		move_and_slide()
		return

	# special-behaviour ticks (heal allies / summon / cast) run on top of the
	# normal movement AI below
	if behavior != "":
		process_behavior(delta)
	if is_elite:
		_tick_elite_slam(delta)

	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= delta
	if jump_cooldown_remaining > 0:
		jump_cooldown_remaining -= delta
	if wall_turn_timer > 0:
		wall_turn_timer -= delta
		if wall_turn_timer <= 0:
			is_wall_blocked = false
	if wall_notice_timer > 0:
		wall_notice_timer -= delta

	if hesitate_remaining > 0:
		hesitate_remaining -= delta
	else:
		hesitate_timer -= delta
		if hesitate_timer <= 0:
			hesitate_remaining = HESITATE_DURATION
			hesitate_timer = randf_range(HESITATE_MIN_INTERVAL, HESITATE_MAX_INTERVAL)

	if jump_react_timer > 0:
		jump_react_timer -= delta

	# A wild mob that has been pulled off its ground breaks off and walks back.
	# Checked before the chase block so a leashed mob can't also be chasing.
	if is_wild and not is_knocked_back:
		var from_home: float = global_position.x - wild_home_x
		if wild_going_home:
			if absf(from_home) <= WILD_LEASH - WILD_LEASH_HYSTERESIS:
				wild_going_home = false
		elif absf(from_home) > WILD_LEASH:
			wild_going_home = true
		if wild_going_home:
			var back := -signf(from_home)
			if back != 0.0:
				facing_direction = int(back)
			velocity.x = back * move_speed()
			move_and_slide()
			return

	if not is_knocked_back:
		var effective_detection_range = detection_range_current * 2.0 if weapon_type == "bow" else detection_range_current
		if wall_notice_timer > 0:
			effective_detection_range += WALL_DETECTION_BONUS
		if instant_aggro:
			effective_detection_range = INF
		if player != null and global_position.distance_to(player.global_position) < effective_detection_range:
			var dist_to_player = global_position.distance_to(player.global_position)
			var dx = player.global_position.x - global_position.x
			var player_above = player.global_position.y < global_position.y - JUMP_SEE_HEIGHT
			if player_above and not was_player_above and count_nearby_enemies() >= JUMP_DESYNC_GROUP_SIZE:
				jump_react_timer = randf_range(JUMP_DESYNC_MIN_DELAY, JUMP_DESYNC_MAX_DELAY)
			was_player_above = player_above
			var dir_to_player = facing_direction
			if absf(dx) > HORIZONTAL_DEADZONE:
				dir_to_player = sign(dx)
			# a melee mob holds a weapon-length away and swings from there
			var standoff: float = float(WEAPONS[weapon_type].range) * MELEE_STANDOFF_FRACTION if weapon_type != "bow" else float(HORIZONTAL_DEADZONE)
			if is_attacking:
				velocity.x = 0    # PLANT and swing -- the wind-up reads as a commit, not a drive-by
			elif hesitate_remaining > 0:
				velocity.x = 0
			elif wall_turn_timer > 0:
				velocity.x = -dir_to_player * move_speed()
			elif weapon_type == "bow" and dist_to_player < BOW_RETREAT_RANGE and not player_above:
				velocity.x = -dir_to_player * move_speed()
			elif weapon_type == "bow" and dist_to_player < BOW_HOLD_RANGE and not player_above:
				velocity.x = 0
			elif absf(dx) <= standoff and not player_above:
				velocity.x = 0    # at reach: stop shoving in, stand and strike
			else:
				velocity.x = dir_to_player * move_speed()
			try_attack(dir_to_player)
			try_jump(player_above)
		else:
			velocity.x = direction * move_speed()
			if direction > 0 and global_position.x - start_x > 150:
				direction = -1
			elif direction < 0 and global_position.x - start_x < -150:
				direction = 1

	if velocity.x > 0:
		facing_direction = 1
	elif velocity.x < 0:
		facing_direction = -1
	if use_sprite:
		_update_enemy_anim()
	if not is_attacking:
		update_weapon_icon_position()

	check_bump()

	move_and_slide()

	if not is_wall_blocked:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider != null and collider.is_in_group("player"):
				continue
			if absf(collision.get_normal().x) > 0.5:
				is_wall_blocked = true
				wall_turn_timer = WALL_TURN_DURATION
				wall_notice_timer = WALL_NOTICE_DURATION
				break

func try_jump(player_above: bool = false) -> void:
	if not is_on_floor() or jump_cooldown_remaining > 0:
		return
	var should_jump = false
	if player_above:
		should_jump = jump_react_timer <= 0.0
	elif randf() < RANDOM_JUMP_CHANCE * jump_chance_variance:
		should_jump = true
	if should_jump:
		velocity.y = JUMP_VELOCITY
		jump_cooldown_remaining = CLIMB_JUMP_COOLDOWN if player_above else JUMP_COOLDOWN

func count_nearby_enemies() -> int:
	var count = 1
	for group_name in ["course_enemy", "dungeon_combatant"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if e == self or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) < JUMP_DESYNC_RADIUS:
				count += 1
	return count

func check_bump() -> void:
	# prey is not always the player (see _pick_prey) -- never assume its API
	if is_knocked_back or is_attacking or player == null:
		return
	if "is_knocked_back" in player and player.is_knocked_back:
		return
	if global_position.distance_to(player.global_position) > BUMP_THRESHOLD:
		return
	var bump_distance = randf_range(20.0, 30.0)
	var away_from_player = sign(global_position.x - player.global_position.x)
	if away_from_player == 0:
		away_from_player = 1
	if player.has_method("apply_knockback"):
		player.apply_knockback(-away_from_player, bump_distance)
	apply_knockback(away_from_player, bump_distance * 0.6)

# A side-scroller swing connects along the ground: horizontal reach, with a small
# vertical band so a step up onto a low ledge doesn't make you untouchable but a
# player a full storey up is safe. Bows keep true (euclidean) range -- they fire.
func _melee_connects(reach: float) -> bool:
	if player == null:
		return false
	var hx := absf(player.global_position.x - global_position.x)
	var vy := absf(player.global_position.y - global_position.y)
	return hx <= reach and vy <= MELEE_VERTICAL_BAND

func try_attack(dir_to_player: int) -> void:
	if attack_cooldown_remaining > 0 or is_attacking:
		return
	var stats = WEAPONS[weapon_type]
	if weapon_type == "bow":
		if global_position.distance_to(player.global_position) > stats.range:
			return
	elif not _melee_connects(stats.range):
		return
	attack_cooldown_remaining = stats.cooldown
	facing_direction = dir_to_player
	is_attacking = true
	match weapon_type:
		"sword":
			animate_sword_attack(stats)
		"spear":
			animate_spear_attack(stats)
		"bow":
			animate_bow_attack(stats)

func finish_attack() -> void:
	is_attacking = false
	update_weapon_icon_position()

func try_deal_melee_damage(stats: Dictionary) -> void:
	if player != null and _melee_connects(stats.range) and player.has_method("take_damage"):
		player.take_damage(int(stats.damage * damage_multiplier))
		if player.has_method("apply_knockback"):
			var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
			var away_from_enemy = sign(player.global_position.x - global_position.x)
			if away_from_enemy == 0:
				away_from_enemy = facing_direction
			player.apply_knockback(away_from_enemy, knockback_distance)

# A weapon flashes hot during its wind-up, so the strike telegraphs itself. Kept
# on the WEAPON so it never fights a body-wide status tint (burn/freeze/poison).
func _telegraph_weapon(node: CanvasItem, dur: float) -> void:
	node.modulate = Color(2.2, 1.5, 1.4)
	var t := create_tween()
	t.tween_property(node, "modulate", Color(1, 1, 1, 1), dur)

func animate_sword_attack(stats: Dictionary) -> void:
	play_sfx(SFX_SWORD)
	var icon = $WeaponIcon
	update_weapon_icon_position()
	# WIND-UP: cock back and flash, THEN strike through (damage on the follow-through)
	icon.rotation_degrees = -50 * facing_direction
	_telegraph_weapon(icon, WINDUP_SWORD)
	var tween = create_tween()
	tween.tween_property(icon, "rotation_degrees", -82 * facing_direction, WINDUP_SWORD)
	tween.tween_property(icon, "rotation_degrees", 58 * facing_direction, 0.12)
	tween.tween_callback(try_deal_melee_damage.bind(stats))
	tween.tween_property(icon, "rotation_degrees", 0.0, 0.1)
	tween.tween_callback(finish_attack)

func animate_spear_attack(stats: Dictionary) -> void:
	play_sfx(SFX_SPEAR)
	var icon = $WeaponIcon
	update_weapon_icon_position()
	var base_x = icon.position.x
	var draw_x = base_x - 14 * facing_direction         # draw the thrust back first
	var lunge_x = base_x + 24 * facing_direction
	_telegraph_weapon(icon, WINDUP_SPEAR)
	var tween = create_tween()
	tween.tween_property(icon, "position:x", draw_x, WINDUP_SPEAR)
	tween.tween_property(icon, "position:x", lunge_x, 0.09)   # then stab
	tween.tween_callback(try_deal_melee_damage.bind(stats))
	tween.tween_property(icon, "position:x", base_x, 0.18)
	tween.tween_callback(finish_attack)

func animate_bow_attack(stats: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var bow = $BowVisual
	var aim_dir = get_aim_direction()
	update_weapon_icon_position()
	# DRAW the bow (a readable wind-up), THEN loose on the release callback
	_telegraph_weapon(bow, WINDUP_BOW)
	var tween = create_tween()
	tween.tween_property(bow, "scale", Vector2(1.35, 0.85), WINDUP_BOW)   # draw back
	tween.tween_property(bow, "scale", Vector2.ONE, 0.08)                 # loose
	tween.tween_callback(_loose_arrow.bind(stats))
	tween.tween_callback(finish_attack)

func _loose_arrow(stats: Dictionary) -> void:
	if player == null or is_dead:
		return
	var aim_dir = get_aim_direction()
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + aim_dir * 20.0
	# target mask 2 (player) | 8 (buildings) -- enemy arrows can smash buildings
	arrow.setup(aim_dir, int(stats.damage * damage_multiplier), stats.knockback_min, stats.knockback_max, 2 | 8, true, ENEMY_ARROW_RANGE)
	get_parent().add_child(arrow)

# --- Behavior archetypes -----------------------------------------------------
# NB: enemy.tscn is load()ed lazily inside summon_minions rather than
# preload()ed as a const -- preloading the scene whose root IS this script is a
# circular reference that upsets compile order.

# Turn this enemy into a special archetype (+ optional elite). Call before or
# just after spawn; sets stats and a random timer offset so a pack doesn't all
# act on the same beat.
func set_behavior(kind: String, elite: bool = false) -> void:
	behavior = kind
	is_elite = elite
	behavior_timer = randf_range(0.6, 2.2)
	match kind:
		"shield":
			wave_hp_multiplier *= 1.4
			accent_color = Color(0.7, 0.75, 0.85)
		"healer":
			wave_hp_multiplier *= 1.1
			accent_color = Color(0.4, 1.0, 0.5)
		"summoner":
			wave_hp_multiplier *= 1.25
			accent_color = Color(0.8, 0.4, 1.0)
		"caster":
			accent_color = Color(0.55, 0.5, 1.0)
			detection_range_current *= 1.6
		"dasher":
			wave_speed_multiplier *= 1.15
			accent_color = Color(1.0, 0.55, 0.3)
	if elite:
		wave_hp_multiplier *= 2.4
		wave_damage_multiplier *= 1.4
		scale *= 1.3
		elite_slam_timer = randf_range(2.5, 4.0)   # first slam comes fairly soon

# ---------- SUPER-MOB (elite) presence + signature slam ----------
# A soft radial glow, built once and shared, so an elite's aura costs nothing.
static var _elite_glow: GradientTexture2D = null
static func _elite_glow_tex() -> GradientTexture2D:
	if _elite_glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0)])
		_elite_glow = GradientTexture2D.new()
		_elite_glow.gradient = g
		_elite_glow.width = 128
		_elite_glow.height = 128
		_elite_glow.fill = GradientTexture2D.FILL_RADIAL
		_elite_glow.fill_from = Vector2(0.5, 0.5)
		_elite_glow.fill_to = Vector2(1.0, 0.5)
	return _elite_glow

# Dress a plain elite up into something you SEE coming: a pulsing aura in its
# archetype colour, a gold crown so it reads as a champion in a crowd, and a
# shout on arrival.
func _become_super_mob() -> void:
	var glow := Sprite2D.new()
	glow.texture = _elite_glow_tex()
	glow.modulate = Color(accent_color.r, accent_color.g, accent_color.b, 0.9)
	glow.scale = Vector2(1.6, 1.6)
	glow.z_index = -1
	glow.position = Vector2(0, -18)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	var pulse := glow.create_tween()
	pulse.set_loops()
	pulse.tween_property(glow, "scale", Vector2(1.95, 1.95), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(1.6, 1.6), 0.8).set_trans(Tween.TRANS_SINE)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([
		Vector2(-11, -46), Vector2(-11, -58), Vector2(-4, -51),
		Vector2(0, -60), Vector2(4, -51), Vector2(11, -58), Vector2(11, -46)])
	crown.color = Color(1.0, 0.86, 0.3)
	add_child(crown)
	FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -72), "⚠ ELITE", Color(1.0, 0.85, 0.3))

func _tick_elite_slam(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	elite_slam_timer -= delta
	if elite_slam_timer > 0.0:
		return
	# only from a settled stance, and only when the player is in range to threaten
	if is_attacking or is_knocked_back or is_frozen() or is_petrified() or not is_on_floor():
		elite_slam_timer = 0.35
		return
	if absf(player.global_position.x - global_position.x) > ELITE_SLAM_START:
		elite_slam_timer = 0.4
		return
	elite_slam_timer = randf_range(ELITE_SLAM_MIN, ELITE_SLAM_MAX)
	_elite_slam()

func _elite_slam() -> void:
	is_attacking = true       # plant through the wind-up (the movement AI reads this)
	velocity.x = 0
	_telegraph_weapon($WeaponIcon, ELITE_WINDUP)
	_spawn_slam_ring()        # the tell: a ground ring swelling to the slam's reach
	var t := create_tween()
	t.tween_interval(ELITE_WINDUP)
	t.tween_callback(_elite_shockwave)
	t.tween_callback(finish_attack)

func _spawn_slam_ring() -> void:
	var ring := Node2D.new()
	ring.z_index = 2
	ring.position = Vector2(0, 4)
	add_child(ring)
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a) * ELITE_SLAM_RADIUS, sin(a) * ELITE_SLAM_RADIUS * 0.32))
	poly.polygon = pts
	poly.color = Color(1.0, 0.4, 0.2, 0.30)
	ring.add_child(poly)
	ring.scale = Vector2(0.2, 0.2)
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector2(1.0, 1.0), ELITE_WINDUP)
	t.tween_property(poly, "modulate:a", 0.0, 0.14)
	t.tween_callback(ring.queue_free)

func _elite_shockwave() -> void:
	if is_dead:
		return
	play_sfx(SFX_HIT)
	# a wave ALONG THE GROUND: near horizontally AND not lifted off -- so leaping
	# clears it. Hard-capped, so it staggers but can never one-shot.
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		var dx := absf(player.global_position.x - global_position.x)
		var dy := absf(player.global_position.y - global_position.y)
		if dx <= ELITE_SLAM_RADIUS and dy <= ELITE_SLAM_AIR:
			var raw := int(round(float(WEAPONS[weapon_type].damage) * damage_multiplier * ELITE_SLAM_DMG_MULT))
			if player.has_method("get_max_health"):
				raw = mini(raw, int(round(player.get_max_health() * ELITE_SLAM_HP_CAP)))
			player.take_damage(raw)
			if player.has_method("apply_knockback"):
				var away := signf(player.global_position.x - global_position.x)
				if away == 0.0:
					away = float(facing_direction)
				player.apply_knockback(int(away), randf_range(60.0, 92.0))
			if player.has_node("Camera2D"):
				player.get_node("Camera2D").shake(10.0, 0.35)
	_spawn_shock_burst()

func _spawn_shock_burst() -> void:
	var burst := Node2D.new()
	burst.z_index = 3
	get_parent().add_child(burst)
	burst.global_position = Vector2(global_position.x, global_position.y + 20.0)
	var ln := Line2D.new()
	ln.width = 5.0
	ln.default_color = Color(1.0, 0.6, 0.25, 0.9)
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 19.0
		pts.append(Vector2(cos(a) * ELITE_SLAM_RADIUS, sin(a) * ELITE_SLAM_RADIUS * 0.3))
	ln.points = pts
	burst.add_child(ln)
	burst.scale = Vector2(0.3, 0.3)
	var t := burst.create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.1, 1.1), 0.25)
	t.tween_property(ln, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(burst.queue_free)

# Periodic special action layered on the normal movement AI.
func process_behavior(delta: float) -> void:
	behavior_timer -= delta
	if behavior_timer > 0.0:
		return
	match behavior:
		"healer":
			behavior_timer = 3.2
			heal_nearby_allies()
		"summoner":
			behavior_timer = 5.5
			summon_minions()
		"caster":
			if player != null and is_instance_valid(player) and not is_attacking and global_position.distance_to(player.global_position) < 540.0:
				behavior_timer = 2.3
				cast_hex_bolt()
			else:
				behavior_timer = 0.3
		"dasher":
			var d = global_position.distance_to(player.global_position) if player else 9999.0
			if player != null and is_instance_valid(player) and d < 320.0 and d > 60.0 and not is_knocked_back:
				behavior_timer = 2.6
				perform_lunge()
			else:
				behavior_timer = 0.4
		_:
			behavior_timer = 1.0

func _living_allies(radius: float) -> Array:
	var out = []
	for g in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
		for e in get_tree().get_nodes_in_group(g):
			if e == self or not is_instance_valid(e):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= radius:
				out.append(e)
	return out

func heal_nearby_allies() -> void:
	var healed = false
	for e in _living_allies(280.0):
		if "health" in e and "max_health" in e and e.health < e.max_health:
			e.health = min(e.max_health, e.health + int(round(e.max_health * 0.15)))
			if e.has_method("update_health_bar"):
				e.update_health_bar()
			if e.has_method("spawn_status_spark"):
				e.spawn_status_spark(Color(0.4, 1.0, 0.5))
			healed = true
	if healed:
		spawn_status_spark(Color(0.4, 1.0, 0.5))

func summon_minions() -> void:
	summoned_minions = summoned_minions.filter(func(m): return is_instance_valid(m) and not (("is_dead" in m) and m.is_dead))
	if summoned_minions.size() >= 3:
		return
	var group = "dungeon_combatant" if is_in_group("dungeon_combatant") else "course_enemy"
	for i in range(2):
		if summoned_minions.size() >= 3:
			break
		var m = load("res://enemy.tscn").instantiate()
		m.respawns = false
		m.instant_aggro = true
		m.weapon_type = "sword"
		m.wave_hp_multiplier = 0.4 * wave_hp_multiplier
		m.wave_damage_multiplier = 0.6 * wave_damage_multiplier
		m.wave_speed_multiplier = wave_speed_multiplier
		m.position = global_position + Vector2(randf_range(-70, 70), -10)
		m.add_to_group(group)
		get_parent().add_child(m)
		summoned_minions.append(m)
	spawn_status_spark(Color(0.8, 0.4, 1.0))

func cast_hex_bolt() -> void:
	if player == null or not is_instance_valid(player):
		return
	is_attacking = true
	play_sfx(SFX_BOW)
	var aim_dir = (player.global_position - global_position).normalized()
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + aim_dir * 22.0
	arrow.setup(aim_dir, int(round(9 * damage_multiplier)), 8.0, 16.0, 2 | 8, true, ENEMY_ARROW_RANGE)
	if "slows_player" in arrow:
		arrow.slows_player = true
	get_parent().add_child(arrow)
	spawn_status_spark(Color(0.55, 0.5, 1.0))
	get_tree().create_timer(0.3).timeout.connect(func(): is_attacking = false)

func perform_lunge() -> void:
	if player == null or not is_instance_valid(player):
		return
	var dir = sign(player.global_position.x - global_position.x)
	if dir == 0:
		dir = facing_direction
	facing_direction = dir
	is_knocked_back = true   # borrow the knockback lock so the AI doesn't fight it
	velocity.x = dir * 620.0
	spawn_status_spark(Color(1.0, 0.55, 0.3))
	get_tree().create_timer(0.22).timeout.connect(func():
		is_knocked_back = false)

func spawn_block_spark() -> void:
	spawn_status_spark(Color(0.8, 0.85, 1.0))

# A quick colored spark over the enemy (block / heal / summon / cast cues).
func spawn_status_spark(col: Color) -> void:
	var s = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(10):
		var a = TAU * float(i) / 10.0
		var rad = 10.0 if i % 2 == 0 else 4.0
		pts.append(Vector2(cos(a), sin(a)) * rad)
	s.polygon = pts
	s.color = col
	s.position = Vector2(0, -30)
	s.z_index = 8
	add_child(s)
	var t = s.create_tween()
	t.tween_property(s, "scale", Vector2(1.8, 1.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.25)
	t.tween_callback(s.queue_free)

# The Soul Split Wand's joke half (GAME_BIBLE 9.7): split into 7 tiny spinning
# copies for 4 seconds, completely invulnerable, completely harmless -- pure
# disco. On every creature in the game but one, this is ALL it does.
var _split_until := 0.0

func on_soul_split_wand() -> void:
	if is_dead:
		return
	_split_until = Time.get_ticks_msec() / 1000.0 + 4.0
	FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -60), "...SPLIT?", Color(0.9, 0.8, 1.0))
	for i in range(7):
		var ghost := ColorRect.new()
		ghost.size = Vector2(14, 20)
		ghost.color = Color(0.8, 0.7, 0.95, 0.75)
		ghost.position = Vector2(-7, -34)
		add_child(ghost)
		var ang := TAU * float(i) / 7.0
		var t := ghost.create_tween()
		t.set_parallel(true)
		t.tween_property(ghost, "position", ghost.position + Vector2(cos(ang), sin(ang)) * 46.0, 0.35)
		t.tween_property(ghost, "rotation", TAU * 3.0, 3.3)
		t.set_parallel(false)
		t.tween_interval(3.3)
		t.tween_property(ghost, "position", Vector2(-7, -34), 0.35)
		t.tween_callback(ghost.queue_free)

func take_damage(amount: int) -> void:
	if Time.get_ticks_msec() / 1000.0 < _split_until:
		return   # while split, a creature is scattered light -- untouchable
	if is_dead:
		return
	# Shielded enemies halve damage taken from the FRONT -- the player has to
	# get around behind them (or burst through) to punish. Attacks from the
	# back land full.
	if behavior == "shield" and player != null and is_instance_valid(player):
		var from_front = sign(player.global_position.x - global_position.x) == facing_direction
		if from_front:
			amount = int(round(amount * 0.4))
			spawn_block_spark()
	# a stoned foe is brittle -- it takes bonus damage while petrified
	if is_petrified():
		amount = int(round(amount * PETRIFY_DAMAGE_MULT))
	health -= amount
	update_health_bar()
	if health <= 0:
		die()
	else:
		flash_hit()
		play_sfx(SFX_HIT)

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	is_knocked_back = false

func flash_hit() -> void:
	if use_sprite and enemy_sprite != null:
		enemy_sprite.modulate = Color(2.4, 2.4, 2.4)
		create_tween().tween_property(enemy_sprite, "modulate", Color(1, 1, 1), 0.15)
		return
	$ColorRect.color = Color(1, 1, 1)
	var tween = create_tween()
	tween.tween_property($ColorRect, "color", base_color.darkened(clamp(generation * 0.15, 0.0, 0.6)), 0.15)
	if has_node("Features"):
		$Features.modulate = Color(2.2, 2.2, 2.2)
		create_tween().tween_property($Features, "modulate", Color(1, 1, 1), 0.15)

func update_health_bar() -> void:
	var health_percent = float(health) / max_health
	$HealthBarFill.size.x = 40 * health_percent

func die() -> void:
	# damage_multiplier is the VILLAGE respawn-generation scaler; the deep
	# pays through depth_reward_mult instead (flat-8-at-floor-90 bug)
	var depth: float = GameState.depth_reward_mult()
	var reward = int(round(5 * damage_multiplier * depth * (1.0 + GameState.get_bonus_total("gold_gain"))))
	# rewards always go to the HERO, never to whatever this mob was chasing
	if real_player != null and real_player.has_method("add_currency"):
		real_player.add_currency(reward)
	GameState.add_xp(int(round(8 * damage_multiplier * depth)))
	if real_player != null and real_player.has_method("on_enemy_killed"):
		real_player.on_enemy_killed()
	spawn_coin_popup(reward)
	# ALL rewards go to the real hero, never to whatever the mob happened to be
	# fighting -- since the prey rework, `player` can be an adventurer or a
	# villager, and paying loot into THEIR "inventory" crashed the death
	# (caught 2026-07-21 the moment mobs and defenders met on the east road).
	var hero: Node2D = real_player if (real_player != null and is_instance_valid(real_player)) else null
	if hero != null and "inventory" in hero:
		# low-rate construction-material drop (tougher gens roll a little better)
		var mat = GameState.roll_construction_drop(hero, 1.0 + 0.15 * generation)
		if mat != "":
			spawn_material_popup(mat)
		# raw meat (cooking ingredient)
		if randf() < 0.25:
			hero.inventory.add_item("raw_meat", 1)
		# SLIME -- the reagent for the tier-3 KEYSTONE of every spec (the first real
		# payoff of a skill tree). It gates the whole rest of the tree, so it MUST be
		# an early material -- but its only source was the Fishing Dock's deep-catch,
		# itself gated behind freeing Kaldos of the Ten (floors 22-63). So every tree
		# froze at tier 2 for hours no matter your level (marathon sim 2026-07-22: 29
		# of 36 points sat idle). It now drops on the shallow floors where those
		# keystones are meant to open; fishing stays the deep's bulk source.
		if GameState.active_dungeon_level <= 30 and randf() < 0.06:
			hero.inventory.add_item("slime", 1)
		# THE POTIONS RULE (5.5): HP/mana potions drop ONLY from the pre-boss
		# floors (positions 4-5 of each block) -- the player enters every boss
		# stocked, and can't potion-spam ordinary floors. Scarcer source, richer
		# rolls, so the boss-eve larder still fills.
		if (GameState.active_dungeon_level - 1) % 5 + 1 >= 4:
			if randf() < 0.16:
				hero.inventory.add_item("potion_health", 1)
			if randf() < 0.12:
				hero.inventory.add_item("potion_mana", 1)
	is_dead = true
	is_attacking = false
	$CollisionShape2D.set_deferred("disabled", true)
	play_sfx(SFX_DEATH)
	died.emit()
	await play_death_animation()
	visible = false
	if not respawns:
		await get_tree().create_timer(0.5).timeout
		queue_free()
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	var mgr = get_tree().get_first_node_in_group("dungeon_manager")
	while mgr != null and mgr.started:
		await get_tree().create_timer(1.0).timeout
	# NOTHING COMES BACK WHILE YOU ARE WATCHING (dev report 2026-07-21: "evil
	# npc are still respawning on player POV"). respawn() puts this body back on
	# its ORIGINAL spot -- which is usually exactly where you just killed it and
	# are still standing. Three seconds later it blinked back into existence in
	# front of you. Wait for its spot to be off-screen first. The wilderness and
	# the Underdark already obey this rule when they stream; this is the last
	# spawner in the game that did not.
	await _wait_until_unwatched()
	respawn()

# How far the player must be from a point before something may appear there.
# Half the 1152-wide base viewport is 576, so this clears the screen edge with
# room to spare -- the same margin the streamed spawners use.
const UNWATCHED_DISTANCE = 760.0
const UNWATCHED_PATIENCE = 45.0   # ...but never wait forever

func _wait_until_unwatched() -> void:
	var waited := 0.0
	while waited < UNWATCHED_PATIENCE:
		var pl = get_tree().get_first_node_in_group("player")
		if pl == null or not is_instance_valid(pl):
			return
		if spawn_position.distance_to(pl.global_position) > UNWATCHED_DISTANCE:
			return
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

func play_death_animation() -> void:
	spawn_death_particles()
	if use_sprite and enemy_sprite != null:
		enemy_sprite.play("death")
	var tween = create_tween()
	tween.set_parallel(true)
	if use_sprite and enemy_sprite != null:
		tween.tween_property(enemy_sprite, "modulate:a", 0.0, 0.45).set_delay(0.18)
	else:
		tween.tween_property($ColorRect, "color", Color(1.0, 0.35, 0.05, 1), 0.15)
		tween.tween_property($ColorRect, "modulate:a", 0.0, 0.45).set_delay(0.1)
	if has_node("Features"):
		tween.tween_property($Features, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tween.tween_property(self, "scale", Vector2(0.15, 0.15), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 18.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 10
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.6
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 55.0
	particles.gravity = Vector2(0, -70)
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 85.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 4.5
	particles.color = Color(1.0, 0.45, 0.1, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	# JUICE (dev polish 2026-07-21): a bright shockwave ring bursts on the kill, so
	# a death reads as a POP, not just a fade
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * 13.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.86, 0.55, 0.85)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	ring.z_index = 11
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector2(0, -20)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale", Vector2(3.6, 3.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	rt.tween_callback(ring.queue_free)

func spawn_coin_popup(amount: int) -> void:
	var popup = Node2D.new()
	popup.global_position = global_position + Vector2(0, -30)
	get_parent().add_child(popup)

	# chunky octagonal coin -- fits the squarish pixel-art theme
	var coin = Polygon2D.new()
	coin.color = Color(1.0, 0.85, 0.2, 1)
	var points = PackedVector2Array()
	var radius = 7.0
	for i in range(8):
		var angle = (i + 0.5) * TAU / 8
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	coin.polygon = points
	popup.add_child(coin)

	var ring = Polygon2D.new()
	ring.color = Color(0.75, 0.55, 0.05, 1)
	var ring_points = PackedVector2Array()
	for i in range(8):
		var angle = (i + 0.5) * TAU / 8
		ring_points.append(Vector2(cos(angle), sin(angle)) * (radius - 2.0))
	ring.polygon = ring_points
	popup.add_child(ring)

	var label = Label.new()
	label.text = "+" + str(amount)
	label.position = Vector2(12, -8)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	popup.add_child(label)

	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 45, 0.8)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
	tween.tween_callback(popup.queue_free)

# Floating "+1 Wood" style popup when a construction material drops.
func spawn_material_popup(mat_id: String) -> void:
	var def = Inventory.get_item_def(mat_id)
	var col = def.get("color", Color(1, 1, 1, 1))
	var popup = Node2D.new()
	popup.global_position = global_position + Vector2(0, -48)
	get_parent().add_child(popup)

	var chip = Polygon2D.new()
	chip.color = col
	chip.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	popup.add_child(chip)

	var label = Label.new()
	label.text = "+1 " + Inventory.get_display_name(mat_id)
	label.position = Vector2(9, -10)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	popup.add_child(label)

	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 42, 0.9)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.9)
	tween.tween_callback(popup.queue_free)

func respawn() -> void:
	generation += 1
	max_health = int(round(MAX_HEALTH * pow(GROWTH_PER_RESPAWN, generation)))
	damage_multiplier = pow(GROWTH_PER_RESPAWN, generation)
	detection_range_current = DETECTION_RANGE * pow(GROWTH_PER_RESPAWN, generation)
	health = max_health
	global_position = spawn_position
	start_x = spawn_position.x
	direction = 1
	velocity = Vector2.ZERO
	is_knocked_back = false
	attack_cooldown_remaining = 0.0
	jump_cooldown_remaining = 0.0
	is_dead = false
	visible = true
	scale = Vector2.ONE
	$ColorRect.modulate = Color(1, 1, 1, 1)
	if use_sprite and enemy_sprite != null:
		enemy_sprite.modulate = Color(1, 1, 1, 1)
		enemy_sprite.play("idle")
	$CollisionShape2D.set_deferred("disabled", false)
	update_health_bar()
	update_body_color()
	print(name, " respawned: generation=", generation, " max_health=", max_health, " damage_x", damage_multiplier)
