extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 900.0
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const DOUBLE_TAP_WINDOW = 0.3
const DASH_COOLDOWN = 0.5

# Dev/admin-only traversal dash bound to T -- always available (no purchase,
# no cooldown) so I can fly around the map fast while testing, independent
# of the player's normal purchasable Dash ability. Also grants invincibility
# for the dash itself plus ADMIN_DASH_INVINCIBILITY_SECONDS afterward.
const ADMIN_DASH_SPEED = DASH_SPEED * 7.0
const ADMIN_DASH_INVINCIBILITY_SECONDS = 10.0

const ARROW_SCENE = preload("res://arrow.tscn")

const SFX_SWORD = preload("res://audio/sword_swing.wav")
const SFX_SPEAR = preload("res://audio/spear_thrust.wav")
const SFX_BOW = preload("res://audio/bow_shot.wav")
const SFX_HURT = preload("res://audio/player_hurt.wav")
const SFX_DEATH = preload("res://audio/player_death.wav")
const SFX_JUMP = preload("res://audio/jump.wav")
const SFX_DASH = preload("res://audio/dash.wav")

const MAX_HEALTH = 100
const BOUNCE_DURATION = 0.1
const INVINCIBILITY_DURATION = 1.0
const DEATH_COUNTDOWN_SECONDS = 7.0
const CURRENCY_DROP_FRACTION = 0.77

const CURRENCY_PICKUP_SCRIPT = preload("res://currency_pickup.gd")

const INVENTORY_CAPACITY = 15
# 9999 starting gold was a debug leftover from before real inventory slots
# existed -- at 999/stack that alone would fill 10 of 15 slots on a brand
# new save. Dropped to a sane starting amount now that currency is a real
# stackable item.
const STARTING_CURRENCY = 50
# Silver/bronze are separate denominations, not automatically convertible to
# gold -- shop prices, the death drop, and passive income all still run on
# gold only. These starting amounts just give the player something to see
# and drag around immediately.
const STARTING_SILVER = 20
const STARTING_BRONZE = 15

# Enemy groups the player's area effects (wand nuke, Thundercaller chain) sweep.
# Includes the village siege attackers so those weapons help defend the walls.
const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

# Every weapon is an inventory item now (see inventory.gd). The player wields
# ONE at a time by picking its inventory slot with the hotbar keys (1-9, 0).
# The active weapon's id/type/stats/def are cached here; "" = unarmed.
const HOTBAR_SIZE = 10
var active_weapon_id: String = ""
var active_weapon_type: String = ""   # "melee" | "spear" | "bow" | "wand"
var active_stats: Dictionary = {}
var active_def: Dictionary = {}
var selected_hotbar_slot: int = 0

var attack_cooldown_remaining = 0.0
var weapon_anim_tween: Tween = null
var spear_hit_bodies: Array = []
var is_attacking = false

func get_weapon_stats() -> Dictionary:
	return active_stats

func has_weapon() -> bool:
	return active_weapon_id != "" and not active_stats.is_empty()

var health = MAX_HEALTH
var invincible = false
# Absolute Time.get_ticks_msec()/1000.0 the current admin-dash invincibility
# window ends at -- lets a repeated T press extend the window without an
# earlier, still-pending "turn it off" call cutting it short.
var admin_invincible_until = 0.0
var is_dead = false

# currency is now a real inventory item ("coin_gold") instead of a bare int
# -- this property just proxies to the inventory so every EXISTING call site
# (player.currency >= X, player.currency -= X, save/load, etc.) keeps
# working unchanged. The inventory itself is the actual source of truth.
# Silver/bronze coins exist in the inventory too but are separate items --
# "currency" only ever means gold.
var inventory: Inventory = Inventory.new(INVENTORY_CAPACITY)
var currency: int:
	get:
		return inventory.get_count("coin_gold")
	set(value):
		var delta = value - inventory.get_count("coin_gold")
		if delta > 0:
			inventory.add_item("coin_gold", delta)
		elif delta < 0:
			inventory.remove_item("coin_gold", -delta)

var facing_direction = 1
var original_color: Color
var spawn_position: Vector2
var has_double_jump = false
var jumps_used = 0
var has_dash = false
var is_dashing = false
var is_knocked_back = false
var last_left_press_time = -10.0
var last_right_press_time = -10.0
var last_dash_time = -10.0
var invincibility_tween: Tween = null

var helmet_visual: Polygon2D = null
var chest_visual: Polygon2D = null
var pants_visual: Polygon2D = null
var weapon_guard: ColorRect = null

# Pixel-art body = an AnimatedSprite2D assembled from PNGs in art/. Drop
# numbered frames (from 1) to fill each state:
#   player_idle_N.png / player_walk_N.png / player_jump_N.png / player_attack_N.png
# A single player_idle.png (or player.png) also works as a one-frame idle. Any
# state with no frames of its own falls back to the idle frame -- and if that
# fallback is a single frame, a gentle procedural walk-bob keeps it alive. No
# art at all -> the placeholder box. All hit-flash/death tint drives body_visual.
const IDLE_SINGLE_PATHS = ["res://art/player_idle.png", "res://art/player.png"]
const SPRITE_TARGET_HEIGHT = 66.0
const WALK_BOB_AMP = 2.5
const WALK_BOB_SPEED = 12.0
# procedural "juice" tuning (all applied on top of the single idle sprite)
const RUN_LEAN_DEG = 3.0
const DASH_LEAN_DEG = 14.0
const LAND_SQUASH_TIME = 0.16
const HURT_SHAKE_TIME = 0.28
# Every player action is its own animation. Drop numbered frames in art/ to
# fill any of them (e.g. player_walk_1.png, player_walk_2.png, player_jump_1.png,
# player_death_1.png ...). Anything you haven't drawn yet falls back to the idle
# frame + procedural motion, so states light up one at a time as you add art.
const ANIM_DEFS = [
	{"name": "idle", "fps": 4.0, "loop": true},
	{"name": "walk", "fps": 9.0, "loop": true},
	{"name": "jump", "fps": 8.0, "loop": false},
	{"name": "fall", "fps": 8.0, "loop": false},
	{"name": "land", "fps": 14.0, "loop": false},
	{"name": "dash", "fps": 12.0, "loop": false},
	{"name": "hurt", "fps": 12.0, "loop": false},
	{"name": "attack", "fps": 12.0, "loop": false},
	{"name": "death", "fps": 8.0, "loop": false},
]
var body_anim: AnimatedSprite2D = null
var body_visual: CanvasItem = null
var anim_base_y = 0.0
var base_scale := Vector2.ONE
var real_anims: Dictionary = {}  # which states have their own frames (vs idle fallback)
var was_on_floor := true
var land_timer := 0.0
var hurt_timer := 0.0
var afterimage_cd := 0.0

func _ready() -> void:
	original_color = $ColorRect.color
	spawn_position = global_position
	$AttackArea/CollisionShape2D.shape = $AttackArea/CollisionShape2D.shape.duplicate()
	$SpearTipArea.body_entered.connect(_on_spear_tip_hit)
	# worn-gear visuals + the held-weapon crossguard are built before any
	# equip call so equip_weapon/on_equipment_changed can drive them.
	build_armor_visuals()
	build_weapon_guard()
	# keep the held weapon drawn in front of the body armor
	$WeaponIcon.z_index = 3
	$BowVisual.z_index = 3
	$WeaponTip.z_index = 3
	setup_body_anim()
	# entering/exiting the dungeon interior is a real scene transition, which
	# re-instances (and re-_ready()s) a fresh Player -- restore the carried-
	# over state instead of re-granting starting resources in that case.
	if not GameState.pending_player_state.is_empty():
		apply_pending_player_state()
	else:
		# weapons FIRST so they land in the first hotbar slots (1=sword, 2=spear,
		# 3=bow, 4=wand, 5=Vampiric Fang, 6=Thundercaller) for easy testing.
		grant_starter_weapons()
		inventory.add_item("coin_gold", STARTING_CURRENCY)
		inventory.add_item("coin_silver", STARTING_SILVER)
		inventory.add_item("coin_bronze", STARTING_BRONZE)
		grant_starter_gear()
		wield_weapon("wpn_sword")
	# armor/relic bonuses + HP sync (survives dungeon scene swaps)
	on_equipment_changed()
	update_currency_display()
	update_health_display()

# TEST: hands the player every weapon at the start so the whole hotbar is
# usable immediately. Will be replaced by real dungeon loot drops later.
func grant_starter_weapons() -> void:
	for item_id in ["wpn_sword", "wpn_spear", "wpn_bow", "wpn_wand", "exc_vampiric", "exc_thunder"]:
		inventory.add_item(item_id, 1)

# Temporary: sample armor + relics so the equipment panel is usable. Weapons
# are granted separately (grant_starter_weapons). Replaced by loot later.
func grant_starter_gear() -> void:
	for item_id in ["helm_leather", "armor_leather", "pants_leather", "relic_vigor", "relic_swiftness"]:
		inventory.add_item(item_id, 1)

# --- worn-gear visuals (helmet / chest / pants overlays on the body) ---
# The body ColorRect spans x[-16,16] y[-24,24]. These sit over the head,
# torso, and legs, tinted to the equipped item's colour and shown/hidden by
# update_armor_visuals(). Relics deliberately have no worn visual.
func build_armor_visuals() -> void:
	helmet_visual = Polygon2D.new()
	helmet_visual.polygon = PackedVector2Array([
		Vector2(-17, -9), Vector2(-17, -17), Vector2(-12, -24), Vector2(0, -27),
		Vector2(12, -24), Vector2(17, -17), Vector2(17, -9),
	])
	helmet_visual.z_index = 1
	helmet_visual.visible = false
	add_child(helmet_visual)

	chest_visual = Polygon2D.new()
	chest_visual.polygon = PackedVector2Array([
		Vector2(-16, -8), Vector2(16, -8), Vector2(15, 11), Vector2(-15, 11),
	])
	chest_visual.z_index = 1
	chest_visual.visible = false
	add_child(chest_visual)

	pants_visual = Polygon2D.new()
	pants_visual.polygon = PackedVector2Array([
		Vector2(-15, 11), Vector2(15, 11), Vector2(15, 24), Vector2(4, 24),
		Vector2(2, 15), Vector2(-2, 15), Vector2(-4, 24), Vector2(-15, 24),
	])
	pants_visual.z_index = 1
	pants_visual.visible = false
	add_child(pants_visual)

func update_armor_visuals() -> void:
	# With the real character sprite active, the flat placeholder armor overlays
	# would only clutter it -- keep them hidden (armor still applies its stats;
	# real gear sprites will layer here later). The box fallback still shows them.
	if body_anim:
		if helmet_visual: helmet_visual.visible = false
		if chest_visual: chest_visual.visible = false
		if pants_visual: pants_visual.visible = false
		return
	_apply_armor_piece(helmet_visual, GameState.equipment.get("helmet", ""))
	_apply_armor_piece(chest_visual, GameState.equipment.get("chest", ""))
	_apply_armor_piece(pants_visual, GameState.equipment.get("pants", ""))

func _apply_armor_piece(node: Polygon2D, item_id: String) -> void:
	if not node:
		return
	if item_id == "":
		node.visible = false
	else:
		node.visible = true
		node.color = Inventory.get_item_def(item_id).get("color", Color(0.5, 0.5, 0.5, 1))

# A small perpendicular crossguard child of the WeaponIcon (so it inherits
# the icon's swing/aim transform automatically) -- makes melee weapons read
# as bladed weapons rather than plain bars. Hidden for bow/wand.
func build_weapon_guard() -> void:
	weapon_guard = ColorRect.new()
	weapon_guard.color = Color(0.32, 0.24, 0.14, 1.0)
	weapon_guard.visible = false
	weapon_guard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$WeaponIcon.add_child(weapon_guard)

# Swaps the placeholder box for the pixel-art sprite when the art exists.
# Scaled by height and feet-aligned to the bottom of the collision body so it
# stands on the ground; falls back to the ColorRect box if the file is missing.
func setup_body_anim() -> void:
	var frames = build_sprite_frames()
	if frames == null:
		body_visual = $ColorRect  # no art -> keep the placeholder box
		return
	body_anim = AnimatedSprite2D.new()
	body_anim.sprite_frames = frames
	body_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_anim.centered = true
	var tex = frames.get_frame_texture("idle", 0)
	var sc = SPRITE_TARGET_HEIGHT / float(max(tex.get_height(), 1))
	base_scale = Vector2(sc, sc)
	body_anim.scale = base_scale
	anim_base_y = 24.0 - SPRITE_TARGET_HEIGHT / 2.0  # feet on the ground line
	body_anim.position = Vector2(0, anim_base_y)
	body_anim.z_index = 0
	add_child(body_anim)
	body_anim.play("idle")
	$ColorRect.visible = false
	body_visual = body_anim

# Builds the SpriteFrames from whatever art exists. Returns null if there's no
# idle art at all (so the caller keeps the box).
func build_sprite_frames():
	var idle_frames = load_frames_for("idle")
	var idle_real = not idle_frames.is_empty()
	if idle_frames.is_empty():
		for p in IDLE_SINGLE_PATHS:
			var t = load_texture(p)
			if t:
				idle_frames = [t]
				break
	if idle_frames.is_empty():
		return null
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	real_anims = {}
	for def in ANIM_DEFS:
		var nm = def.name
		var fr = idle_frames if nm == "idle" else load_frames_for(nm)
		real_anims[nm] = idle_real if nm == "idle" else not fr.is_empty()
		if fr.is_empty():
			fr = idle_frames  # fall back to the idle frame so play(state) always works
		_add_anim(sf, nm, fr, def.fps, def.loop)
	return sf

func load_frames_for(anim: String) -> Array:
	var out = []
	var i = 1
	while true:
		var t = load_texture("res://art/player_%s_%d.png" % [anim, i])
		if t == null:
			break
		out.append(t)
		i += 1
	return out

# Accepts an imported resource OR a loose not-yet-imported PNG, and auto-trims
# transparent margins so the character fills the frame (feet at the bottom) no
# matter how the PNG was cropped.
func load_texture(path: String) -> Texture2D:
	var img: Image = null
	# prefer the imported resource, but fall back to decoding the raw PNG (which
	# works even if the import is missing/broken -- e.g. file just dropped in).
	if ResourceLoader.exists(path):
		var t = load(path)
		if t:
			img = t.get_image()
	if img == null:
		img = load_image_smart(path)
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	# trim to the character, ignoring faint stray AI noise (alpha threshold, not
	# Godot's get_used_rect which keeps any pixel with alpha > 0)
	var used = opaque_bounds(img, 0.35)
	if used.size.x > 0 and used.size.y > 0 and used != Rect2i(Vector2i.ZERO, img.get_size()):
		img = img.get_region(used)
	return ImageTexture.create_from_image(img)

# Bounding box of pixels more opaque than `threshold` (coarse scan for speed).
func opaque_bounds(img: Image, threshold: float) -> Rect2i:
	var w = img.get_width()
	var h = img.get_height()
	var step = 3
	var minx = w
	var miny = h
	var maxx = -1
	var maxy = -1
	for y in range(0, h, step):
		for x in range(0, w, step):
			if img.get_pixel(x, y).a > threshold:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return Rect2i(Vector2i.ZERO, img.get_size())
	return Rect2i(minx, miny, maxx - minx + step, maxy - miny + step).intersection(Rect2i(0, 0, w, h))

# Decodes an image by its ACTUAL content (magic bytes), not its file extension
# -- so a mislabeled .png (e.g. a JPEG renamed) or a correct PNG both load.
func load_image_smart(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12:
		return null
	var img = Image.new()
	var err = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = img.load_png_from_buffer(bytes)      # PNG
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)      # JPEG (no alpha)
	elif bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[8] == 0x57 and bytes[9] == 0x45:
		err = img.load_webp_from_buffer(bytes)     # WEBP
	else:
		err = img.load(path)
	return img if err == OK else null

func _add_anim(sf: SpriteFrames, anim: String, textures: Array, fps: float, loops: bool) -> void:
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loops)
	for t in textures:
		sf.add_frame(anim, t)

# Picks the animation from the player's current action and flips to face the
# move direction. When a state has no real frames of its own, a small bob keeps
# the single idle frame from sliding around lifelessly.
# Which action the player is doing right now, mapped to an animation name.
func current_anim_state() -> String:
	if is_dead:
		return "death"
	if hurt_timer > 0.0:
		return "hurt"
	if is_dashing:
		return "dash"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if land_timer > 0.0:
		return "land"
	if is_attacking:
		return "attack"
	if absf(velocity.x) > 12.0:
		return "walk"
	return "idle"

# Node y that puts the CURRENT frame's bottom edge (feet) on the ground line
# (+24 = bottom of the collision body), whatever height that frame was drawn at.
func feet_anchor_y() -> float:
	if not body_anim:
		return anim_base_y
	var tex = body_anim.sprite_frames.get_frame_texture(body_anim.animation, body_anim.frame)
	if tex == null:
		return anim_base_y
	return 24.0 - (tex.get_height() * base_scale.y) / 2.0

func update_body_anim(delta: float) -> void:
	if not body_anim:
		return
	# tick timers
	var on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		land_timer = LAND_SQUASH_TIME   # just landed
	was_on_floor = on_floor
	if land_timer > 0.0:
		land_timer -= delta
	if hurt_timer > 0.0:
		hurt_timer -= delta

	var state = current_anim_state()
	if body_anim.animation != state:
		body_anim.play(state)
	body_anim.flip_h = facing_direction < 0

	# If this state has its OWN drawn frames, let them do the work -- no
	# procedural distortion on top. Anchor by FEET per-frame so poses that were
	# drawn at different sizes/positions still stand on the ground (fixes the
	# floating/sinking between AI frames).
	if real_anims.get(state, false):
		body_anim.rotation = 0.0
		body_anim.scale = base_scale
		body_anim.position = Vector2(0, feet_anchor_y())
		if state == "dash":
			spawn_dash_afterimage(delta)
		return

	# Dead with no death frames -> the topple tween in die() owns the transform.
	if state == "death":
		return

	# Otherwise: procedural fallback for this state (single idle frame).
	var target_scale = base_scale
	var target_rot = 0.0
	var target_y = feet_anchor_y()
	var now = Time.get_ticks_msec() / 1000.0
	match state:
		"dash":
			target_scale = base_scale * Vector2(1.18, 0.86)
			target_rot = deg_to_rad(DASH_LEAN_DEG * facing_direction)
			spawn_dash_afterimage(delta)
		"jump":
			target_scale = base_scale * Vector2(0.9, 1.14)
		"fall":
			target_scale = base_scale * Vector2(0.96, 1.06)
			target_rot = deg_to_rad(4.0 * facing_direction)
		"land":
			var k = land_timer / LAND_SQUASH_TIME
			target_scale = base_scale * Vector2(lerp(1.0, 1.2, k), lerp(1.0, 0.8, k))
		"walk":
			target_y = feet_anchor_y() - absf(sin(now * WALK_BOB_SPEED)) * WALK_BOB_AMP
			target_rot = deg_to_rad(RUN_LEAN_DEG * facing_direction)
		"attack":
			target_rot = deg_to_rad(6.0 * facing_direction)
		"hurt":
			pass  # shake handled below
		_:
			target_scale = base_scale * Vector2(1.0, 1.0 + sin(now * 2.0) * 0.012)  # idle breathe

	var shake = (sin(hurt_timer * 90.0) * 2.2) if state == "hurt" else 0.0
	body_anim.scale = body_anim.scale.lerp(target_scale, 0.3)
	body_anim.rotation = lerp_angle(body_anim.rotation, target_rot, 0.3)
	body_anim.position = Vector2(shake, target_y)

# Faded trailing copies during a dash.
func spawn_dash_afterimage(delta: float) -> void:
	afterimage_cd -= delta
	if afterimage_cd > 0.0:
		return
	afterimage_cd = 0.045
	var ghost = Sprite2D.new()
	ghost.texture = body_anim.sprite_frames.get_frame_texture(body_anim.animation, body_anim.frame)
	ghost.centered = true
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = body_anim.scale
	ghost.flip_h = body_anim.flip_h
	ghost.rotation = body_anim.global_rotation
	ghost.global_position = body_anim.global_position
	ghost.modulate = Color(0.6, 0.75, 1.0, 0.5)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

func apply_pending_player_state() -> void:
	var data = GameState.pending_player_state
	GameState.pending_player_state = {}
	if data.has("inventory"):
		inventory.from_save_data(data["inventory"])
	if data.has("has_dash"):
		has_dash = data["has_dash"]
	if data.has("has_double_jump"):
		has_double_jump = data["has_double_jump"]
	if data.has("health"):
		health = data["health"]
	# re-wield whatever weapon was in hand (weapons live in the inventory now)
	var eq = str(data.get("active_weapon_id", "wpn_sword"))
	if not wield_weapon(eq):
		wield_weapon("wpn_sword")

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# --- combat/economy effect hooks. get_bonus_total = skill tree + worn gear
# (armor/relics), so equipping gear flows through the same math as skills. ---

func get_max_health() -> int:
	return MAX_HEALTH + int(round(GameState.get_bonus_total("max_health")))

# `weapon` is a weapon_type: "melee" | "spear" | "bow" | "wand".
func skill_damage_mult(weapon: String) -> float:
	if weapon == "melee" or weapon == "spear":
		return 1.0 + GameState.get_bonus_total("melee_damage")
	if weapon == "bow":
		return 1.0 + GameState.get_bonus_total("bow_damage")
	return 1.0

func skill_cooldown_mult(weapon: String) -> float:
	var reduction = 0.0
	if weapon == "melee" or weapon == "spear":
		reduction = GameState.get_bonus_total("melee_cooldown")
	elif weapon == "bow":
		reduction = GameState.get_bonus_total("bow_cooldown")
	elif weapon == "wand":
		reduction = GameState.get_bonus_total("wand_cooldown")
	return max(0.3, 1.0 - reduction)

func skill_move_speed_mult() -> float:
	return 1.0 + GameState.get_bonus_total("move_speed")

# Called by GameState whenever a piece of gear (armor/relic) is equipped or
# unequipped -- refresh armor visuals and clamp HP to the new max.
func on_equipment_changed() -> void:
	update_armor_visuals()
	health = min(health, get_max_health())
	update_health_display()

func update_health_display() -> void:
	var percent = clamp(float(health) / get_max_health(), 0.0, 1.0)
	$"../CanvasLayer/HealthBarFill".size.x = 100 * percent
	$"../CanvasLayer/HealthLabel".text = str(max(health, 0)) + "/" + str(get_max_health())

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / BOUNCE_DURATION)
	await get_tree().create_timer(BOUNCE_DURATION).timeout
	is_knocked_back = false

func knockback_sign_toward(body: Node2D) -> int:
	var s = sign(body.global_position.x - global_position.x)
	if s == 0:
		s = facing_direction
	return s

func _on_spear_tip_hit(body: Node2D) -> void:
	if body in spear_hit_bodies:
		return
	spear_hit_bodies.append(body)
	var stats = active_stats
	if body.has_method("take_damage"):
		body.take_damage(int(round(stats.damage * skill_damage_mult("spear"))))
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
		body.apply_knockback(knockback_sign_toward(body), knockback_distance)

# Wields the weapon ITEM `item_id` (must be a "weapon" category item). Caches
# its stats/type/def and configures the held-weapon visuals. Returns false for
# non-weapons.
func wield_weapon(item_id: String) -> bool:
	var def = Inventory.get_item_def(item_id)
	if def.get("category", "") != "weapon":
		return false
	var stats = def.get("weapon_stats", {})
	if stats.is_empty():
		return false
	active_weapon_id = item_id
	active_def = def
	active_stats = stats
	active_weapon_type = def.get("weapon_type", "melee")
	$AttackArea/CollisionShape2D.shape.size = stats.area_size
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	$WeaponIcon.size = stats.icon_size
	$WeaponIcon.color = stats.icon_color
	$WeaponIcon.rotation_degrees = 0.0
	$WeaponIcon.scale = Vector2.ONE
	$WeaponIcon.pivot_offset = Vector2(0.0, stats.icon_size.y / 2.0)
	update_weapon_guard()
	update_weapon_visual(stats.icon_offset)
	return true

# Hotbar select: index 0-9 = inventory slots 1-10. Wields the weapon in that
# slot; a non-weapon (or empty) slot does nothing.
func select_hotbar_slot(index: int) -> void:
	selected_hotbar_slot = index
	if index >= inventory.slots.size():
		return
	var slot = inventory.slots[index]
	if slot == null or Inventory.get_category(slot.item_id) != "weapon":
		return
	if slot.item_id == active_weapon_id:
		return
	if wield_weapon(slot.item_id):
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Wielding " + Inventory.get_display_name(slot.item_id))

# Shows/sizes the crossguard for bladed melee weapons (melee/spear), hides it
# for bow and wand. The guard is a child of WeaponIcon, so it swings/aims with
# the weapon automatically.
func update_weapon_guard() -> void:
	if not weapon_guard:
		return
	if active_weapon_type == "bow" or active_weapon_type == "wand" or active_stats.is_empty():
		weapon_guard.visible = false
		return
	var guard_height = active_stats.icon_size.y + 12.0
	weapon_guard.size = Vector2(5.0, guard_height)
	weapon_guard.position = Vector2(active_stats.icon_size.x * 0.16, (active_stats.icon_size.y - guard_height) / 2.0)
	weapon_guard.visible = true

func get_aim_direction() -> Vector2:
	var to_mouse = get_global_mouse_position() - global_position
	if to_mouse.length() < 1.0:
		return Vector2(facing_direction, 0)
	return to_mouse.normalized()

func update_weapon_visual(offset: float) -> void:
	if not has_weapon():
		$WeaponIcon.visible = false
		$BowVisual.visible = false
		$WeaponTip.visible = false
		return
	var stats = active_stats
	var aim_dir = get_aim_direction()
	$WeaponTip.visible = false
	$BowVisual.visible = false
	if active_weapon_type == "bow":
		$WeaponIcon.visible = false
		$BowVisual.visible = true
		$BowVisual.position = aim_dir * offset
		$BowVisual.rotation = aim_dir.angle()
		$BowVisual.scale = Vector2.ONE
	else:
		$WeaponIcon.visible = true
		$WeaponIcon.position = aim_dir * offset - $WeaponIcon.pivot_offset
		$WeaponIcon.rotation = aim_dir.angle()
		$AttackArea.position = aim_dir * stats.range_offset
		$AttackArea.rotation = aim_dir.angle()
		if active_weapon_type == "spear":
			$WeaponTip.visible = true
			var tip_pos = aim_dir * (offset + stats.icon_size.x)
			$WeaponTip.position = tip_pos
			$WeaponTip.rotation = aim_dir.angle()
			$WeaponTip.scale = Vector2.ONE
			$SpearTipArea.position = tip_pos

func add_currency(amount: int) -> void:
	currency += amount
	$"../CanvasLayer/CurrencyLabel".text = "Currency: " + str(currency)
	print("Currency: ", currency)

func take_damage(amount: int) -> void:
	if invincible or is_dead:
		return
	health -= amount
	update_health_display()
	play_sfx(SFX_HURT)
	hurt_timer = HURT_SHAKE_TIME
	if has_node("Camera2D"):
		$Camera2D.shake(4.0, 0.15)
	if health <= 0:
		die()
		return
	invincible = true
	start_invincibility_flash()
	await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
	stop_invincibility_flash()
	invincible = false

func start_invincibility_flash() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
	body_visual.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var color_tween = create_tween()
	color_tween.tween_property(body_visual, "modulate", Color(1, 1, 1, 1), 0.15)
	invincibility_tween = create_tween()
	invincibility_tween.set_loops()
	invincibility_tween.tween_property(body_visual, "modulate:a", 0.25, 0.1)
	invincibility_tween.tween_property(body_visual, "modulate:a", 1.0, 0.1)

func stop_invincibility_flash() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
		invincibility_tween = null
	body_visual.modulate.a = 1.0

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	play_sfx(SFX_DEATH)
	stop_invincibility_flash()
	body_visual.modulate = Color(0.55, 0.2, 0.2, 1.0)
	# topple over as he dies -- but only if you haven't drawn real death frames
	# (those play themselves; update_body_anim yields the transform while dead)
	if body_anim and not real_anims.get("death", false):
		var topple = create_tween()
		topple.tween_property(body_anim, "rotation", deg_to_rad(82.0 * facing_direction), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	drop_currency_on_death()
	apply_difficulty_death_penalty()

	var death_screen = get_node_or_null("../DeathScreen")
	if death_screen:
		await death_screen.run_death_sequence(DEATH_COUNTDOWN_SECONDS)
	else:
		await get_tree().create_timer(DEATH_COUNTDOWN_SECONDS).timeout

	health = get_max_health()
	global_position = spawn_position
	body_visual.modulate = Color(1, 1, 1, 1)
	if body_anim:
		body_anim.rotation = 0.0
		body_anim.scale = base_scale
		body_anim.position = Vector2(0, anim_base_y)
	invincible = false
	is_dead = false
	update_health_display()

# All difficulties drop currency on death -- the amount stays in the world
# as a pickup (see currency_pickup.gd) for a full in-game day before it
# despawns, rather than being lost outright.
func drop_currency_on_death() -> void:
	var drop_amount = int(round(currency * CURRENCY_DROP_FRACTION))
	if drop_amount <= 0:
		return
	currency -= drop_amount
	update_currency_display()
	var pickup = CURRENCY_PICKUP_SCRIPT.new()
	pickup.global_position = global_position
	pickup.setup(drop_amount, true)
	# die() can be reached from an Area2D physics callback (an arrow's
	# body_entered, mid physics-step) -- adding a new collider synchronously
	# there hits Godot's "can't change state while flushing queries"
	# restriction, so this has to go through the deferred queue instead.
	get_parent().call_deferred("add_child", pickup)

# Medium/Hard difficulties additionally take something more permanent on
# death. Both hooks are stubs until the villager/skill-material systems
# exist -- this just guarantees they fire correctly once they do.
func apply_difficulty_death_penalty() -> void:
	match GameState.difficulty:
		"Medium":
			GameState.remove_random_villager()
		"Hard":
			GameState.remove_random_villager()
			GameState.remove_one_skill_material()

func update_currency_display() -> void:
	$"../CanvasLayer/CurrencyLabel".text = "Currency: " + str(currency)

func perform_dash(dash_direction: int) -> void:
	if not has_dash or is_dashing:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_dash_time < DASH_COOLDOWN:
		return
	last_dash_time = now
	is_dashing = true
	play_sfx(SFX_DASH)
	velocity.x = dash_direction * DASH_SPEED
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func perform_admin_dash() -> void:
	if is_dashing:
		return
	is_dashing = true
	invincible = true
	play_sfx(SFX_DASH)
	var input_dir = Input.get_axis("move_left", "move_right")
	var dash_direction = int(sign(input_dir)) if input_dir != 0 else facing_direction
	velocity.x = dash_direction * ADMIN_DASH_SPEED
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false
	var now = Time.get_ticks_msec() / 1000.0
	admin_invincible_until = now + ADMIN_DASH_INVINCIBILITY_SECONDS
	var my_expiry = admin_invincible_until
	await get_tree().create_timer(ADMIN_DASH_INVINCIBILITY_SECONDS).timeout
	# only clear invincibility if nothing extended the window since this
	# specific dash scheduled it (a later T press pushes admin_invincible_until
	# further out, so this stale check simply becomes a no-op).
	if my_expiry == admin_invincible_until:
		invincible = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jumps_used = 0

	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= delta

	# hotbar: keys 1-9 and 0 pick inventory slots 0-9; wield the weapon there
	for i in range(HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			select_hotbar_slot(i)

	if Input.is_action_just_pressed("admin_dash"):
		perform_admin_dash()

	if Input.is_action_just_pressed("admin_kill"):
		# bypasses invincible/take_damage entirely -- an instant dev/admin
		# kill for testing the death sequence, not a real damage source.
		die()

	if Input.is_action_just_pressed("admin_restore"):
		# admin/dev: instantly repair every building in the village to full.
		GameState.restore_all_buildings()
		for b in get_tree().get_nodes_in_group("building"):
			if b.has_method("restore_full"):
				b.restore_full()
		var restore_notif = get_tree().get_first_node_in_group("notification_stack")
		if restore_notif:
			restore_notif.show_notification("Admin: all buildings restored.")

	if Input.is_action_just_pressed("move_left"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_left_press_time < DOUBLE_TAP_WINDOW:
			perform_dash(-1)
		last_left_press_time = now

	if Input.is_action_just_pressed("move_right"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_right_press_time < DOUBLE_TAP_WINDOW:
			perform_dash(1)
		last_right_press_time = now

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumps_used = 1
			play_sfx(SFX_JUMP)
		elif has_double_jump and jumps_used < 2:
			velocity.y = JUMP_VELOCITY
			jumps_used = 2
			play_sfx(SFX_JUMP)

	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		facing_direction = sign(direction)
	if has_weapon() and not is_attacking:
		update_weapon_visual(active_stats.icon_offset)

	if not is_dashing and not is_knocked_back:
		velocity.x = direction * SPEED * skill_move_speed_mult()

	if Input.is_action_just_pressed("attack"):
		perform_attack()

	move_and_slide()
	# drive the sprite animation after movement (needs final velocity/floor state)
	update_body_anim(delta)

func perform_attack() -> void:
	if attack_cooldown_remaining > 0 or not has_weapon():
		return
	var stats = active_stats
	attack_cooldown_remaining = stats.cooldown * skill_cooldown_mult(active_weapon_type)
	if active_weapon_type == "bow":
		animate_bow(stats)
		return
	if active_weapon_type == "spear":
		animate_spear(stats)
		return
	if active_weapon_type == "wand":
		cast_wand()
		return
	# melee swing (also the swing for an Excellent weapon)
	var is_excellent = active_def.has("unique_effect")
	var aim_dir = get_aim_direction()
	$AttackArea.position = aim_dir * stats.range_offset
	$AttackArea.rotation = aim_dir.angle()
	var bodies = $AttackArea.get_overlapping_bodies()
	var target = closest_body(bodies)
	if target:
		# Excellent weapons are classless -- no skill-tree damage scaling.
		var mult = 1.0 if is_excellent else skill_damage_mult("melee")
		var dealt = int(round(stats.damage * mult))
		if target.has_method("take_damage"):
			target.take_damage(dealt)
		if target.has_method("apply_knockback"):
			var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
			target.apply_knockback(knockback_sign_toward(target), knockback_distance)
		if is_excellent:
			apply_excellent_effect(target, dealt)
	animate_sword()

# The unique effect of the active Excellent weapon, fired on each melee hit.
func apply_excellent_effect(target: Node2D, damage_dealt: int) -> void:
	var effect = active_def.get("unique_effect", "")
	if effect == "lifesteal":
		var heal = int(round(damage_dealt * active_def.get("unique_value", 0.0)))
		health = min(get_max_health(), health + heal)
		update_health_display()
		if heal > 0 and is_instance_valid(target):
			spawn_blood_steal(target.global_position)
	elif effect == "chain":
		var radius = active_def.get("unique_radius", 0.0)
		var zap = int(active_def.get("unique_value", 0))
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if e == target or not is_instance_valid(e):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if target.global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
					e.take_damage(zap)
					spawn_lightning_bolt(target.global_position, e.global_position)

# --- Excellent-weapon hit visuals (all procedural, world-space, self-cleaning) ---

const LIGHTNING_CORE_COLOR = Color(0.7, 0.9, 1.0, 1.0)
const LIGHTNING_GLOW_COLOR = Color(0.4, 0.65, 1.0, 0.35)
const BLOOD_COLOR = Color(0.72, 0.05, 0.1, 0.95)

# A flickering jagged bolt from one enemy to another (Thundercaller's chain).
# Placed at from_pos with points relative to it, so it lands correctly no
# matter what transform the parent level node has.
func spawn_lightning_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var local_end = to_pos - from_pos
	var glow = Line2D.new()
	glow.width = 8.0
	glow.default_color = LIGHTNING_GLOW_COLOR
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.z_index = 49
	var core = Line2D.new()
	core.width = 3.0
	core.default_color = LIGHTNING_CORE_COLOR
	core.joint_mode = Line2D.LINE_JOINT_ROUND
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.z_index = 50
	var pts = _jagged_points(Vector2.ZERO, local_end)
	core.points = pts
	glow.points = pts
	get_parent().add_child(glow)
	get_parent().add_child(core)
	glow.global_position = from_pos
	core.global_position = from_pos
	# flicker once, then fade out and free
	var t = core.create_tween()
	t.tween_interval(0.05)
	t.tween_callback(func():
		if is_instance_valid(core):
			var p = _jagged_points(Vector2.ZERO, local_end)
			core.points = p
			glow.points = p)
	t.tween_interval(0.04)
	t.tween_property(core, "modulate:a", 0.0, 0.18)
	t.parallel().tween_property(glow, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		if is_instance_valid(glow): glow.queue_free()
		if is_instance_valid(core): core.queue_free())

# Builds a lightning path from a to b with perpendicular random kinks.
func _jagged_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var segments = 7
	var dir = b - a
	var length = dir.length()
	var perp = Vector2(-dir.y, dir.x).normalized() if length > 0.01 else Vector2.UP
	for i in range(segments + 1):
		var frac = float(i) / segments
		var base = a + dir * frac
		if i != 0 and i != segments:
			base += perp * randf_range(-1.0, 1.0) * length * 0.09
		pts.append(base)
	return pts

# Red droplets streaming from the struck enemy back into the player, selling
# the Vampiric Fang's life-drain.
func spawn_blood_steal(from_pos: Vector2) -> void:
	var to_pos = global_position
	for i in range(7):
		var drop = Polygon2D.new()
		drop.polygon = _circle_points(randf_range(2.0, 4.0), 8)
		drop.color = BLOOD_COLOR
		drop.z_index = 48
		get_parent().add_child(drop)
		drop.global_position = from_pos + Vector2(randf_range(-11, 11), randf_range(-16, 6))
		var mid = drop.global_position.lerp(to_pos, 0.5) + Vector2(randf_range(-18, 18), randf_range(-28, -6))
		var dur = randf_range(0.26, 0.46)
		var move = drop.create_tween()
		move.tween_property(drop, "global_position", mid, dur * 0.5).set_trans(Tween.TRANS_SINE)
		move.tween_property(drop, "global_position", to_pos, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var fade = drop.create_tween()
		fade.tween_interval(dur * 0.55)
		fade.tween_property(drop, "modulate:a", 0.0, dur * 0.45)
		fade.tween_callback(drop.queue_free)

func _circle_points(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

func closest_body(bodies: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist = INF
	for body in bodies:
		var dist = global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	return nearest

func animate_sword() -> void:
	play_sfx(SFX_SWORD)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	is_attacking = true
	var base_angle = get_aim_direction().angle()
	icon.rotation = base_angle - deg_to_rad(60)
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "rotation", base_angle + deg_to_rad(60), 0.1)
	weapon_anim_tween.tween_property(icon, "rotation", base_angle, 0.08)
	weapon_anim_tween.tween_callback(func(): is_attacking = false)

func animate_spear(stats: Dictionary) -> void:
	play_sfx(SFX_SPEAR)
	var base_offset = stats.icon_offset
	var lunge_offset = base_offset + 30.0
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	is_attacking = true
	spear_hit_bodies.clear()
	$SpearTipArea.monitoring = true
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_method(update_weapon_visual, base_offset, lunge_offset, 0.1)
	weapon_anim_tween.tween_method(update_weapon_visual, lunge_offset, base_offset, 0.15)
	weapon_anim_tween.tween_callback(func(): $SpearTipArea.monitoring = false)
	weapon_anim_tween.tween_callback(func(): is_attacking = false)

func animate_bow(stats: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var bow = $BowVisual
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(bow, "scale", Vector2(1.3, 1.3), 0.06)
	weapon_anim_tween.tween_property(bow, "scale", Vector2.ONE, 0.1)
	spawn_arrow(stats, get_aim_direction())

func spawn_arrow(stats: Dictionary, aim_dir: Vector2) -> void:
	var arrow = ARROW_SCENE.instantiate()
	arrow.position = global_position + aim_dir * 20.0
	arrow.setup(aim_dir, int(round(stats.damage * skill_damage_mult("bow"))), stats.knockback_min, stats.knockback_max, 4)
	get_parent().add_child(arrow)

func cast_wand() -> void:
	play_sfx(SFX_BOW)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.15)

	for group_name in HOSTILE_GROUPS:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(enemy) and enemy.has_method("take_damage") and "is_dead" in enemy and not enemy.is_dead:
				enemy.take_damage(999999)
