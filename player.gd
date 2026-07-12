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

const WEAPONS = {
	"sword": {"damage": 8, "cooldown": 0.3, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.75, 0.75, 0.8), "icon_offset": 20.0},
	"spear": {"damage": 24, "cooldown": 0.9, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 60.0, "knockback_max": 90.0, "icon_size": Vector2(114, 8), "icon_color": Color(0.55, 0.35, 0.15), "icon_offset": 16.0},
	"bow": {"damage": 15, "cooldown": 0.5, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.45, 0.28, 0.1), "icon_offset": 18.0},
	"wand": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.65, 0.2, 0.85), "icon_offset": 20.0},
}

var owned_weapons = {"sword": true, "spear": false, "bow": false, "wand": false}
var equipped_weapon = "sword"
var attack_cooldown_remaining = 0.0
var weapon_anim_tween: Tween = null
var spear_hit_bodies: Array = []
var is_attacking = false

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

func _ready() -> void:
	original_color = $ColorRect.color
	spawn_position = global_position
	$AttackArea/CollisionShape2D.shape = $AttackArea/CollisionShape2D.shape.duplicate()
	$SpearTipArea.body_entered.connect(_on_spear_tip_hit)
	# entering/exiting the dungeon interior is a real scene transition, which
	# re-instances (and re-_ready()s) a fresh Player -- restore the carried-
	# over state instead of re-granting starting resources in that case.
	if not GameState.pending_player_state.is_empty():
		apply_pending_player_state()
	else:
		inventory.add_item("coin_gold", STARTING_CURRENCY)
		inventory.add_item("coin_silver", STARTING_SILVER)
		inventory.add_item("coin_bronze", STARTING_BRONZE)
		equip_weapon("sword")
	update_currency_display()
	update_health_display()

func apply_pending_player_state() -> void:
	var data = GameState.pending_player_state
	GameState.pending_player_state = {}
	if data.has("inventory"):
		inventory.from_save_data(data["inventory"])
	if data.has("owned_weapons"):
		for w in data["owned_weapons"].keys():
			owned_weapons[w] = data["owned_weapons"][w]
	if data.has("has_dash"):
		has_dash = data["has_dash"]
	if data.has("has_double_jump"):
		has_double_jump = data["has_double_jump"]
	if data.has("health"):
		health = data["health"]
	var eq = data.get("equipped_weapon", "sword")
	equip_weapon(eq if owned_weapons.get(eq, false) else "sword")

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# --- skill tree effect hooks (see skill_tree.gd / GameState.get_skill_total) ---

func get_max_health() -> int:
	return MAX_HEALTH + int(round(GameState.get_skill_total("max_health")))

func skill_damage_mult(weapon: String) -> float:
	if weapon == "sword" or weapon == "spear":
		return 1.0 + GameState.get_skill_total("melee_damage")
	if weapon == "bow":
		return 1.0 + GameState.get_skill_total("bow_damage")
	return 1.0

func skill_cooldown_mult(weapon: String) -> float:
	var reduction = 0.0
	if weapon == "sword" or weapon == "spear":
		reduction = GameState.get_skill_total("melee_cooldown")
	elif weapon == "bow":
		reduction = GameState.get_skill_total("bow_cooldown")
	elif weapon == "wand":
		reduction = GameState.get_skill_total("wand_cooldown")
	return max(0.3, 1.0 - reduction)

func skill_move_speed_mult() -> float:
	return 1.0 + GameState.get_skill_total("move_speed")

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
	var stats = WEAPONS["spear"]
	if body.has_method("take_damage"):
		body.take_damage(int(round(stats.damage * skill_damage_mult("spear"))))
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
		body.apply_knockback(knockback_sign_toward(body), knockback_distance)

func equip_weapon(weapon_name: String) -> void:
	if not owned_weapons.get(weapon_name, false):
		return
	equipped_weapon = weapon_name
	var stats = WEAPONS[weapon_name]
	$AttackArea/CollisionShape2D.shape.size = stats.area_size
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	$WeaponIcon.size = stats.icon_size
	$WeaponIcon.color = stats.icon_color
	$WeaponIcon.rotation_degrees = 0.0
	$WeaponIcon.scale = Vector2.ONE
	$WeaponIcon.pivot_offset = Vector2(0.0, stats.icon_size.y / 2.0)
	update_weapon_visual(stats.icon_offset)
	print("Equipped: ", weapon_name)

func get_aim_direction() -> Vector2:
	var to_mouse = get_global_mouse_position() - global_position
	if to_mouse.length() < 1.0:
		return Vector2(facing_direction, 0)
	return to_mouse.normalized()

func update_weapon_visual(offset: float) -> void:
	var stats = WEAPONS[equipped_weapon]
	var aim_dir = get_aim_direction()
	$WeaponTip.visible = false
	$BowVisual.visible = false
	if equipped_weapon == "bow":
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
		if equipped_weapon == "spear":
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
	$ColorRect.color = Color(1, 0, 0)
	var color_tween = create_tween()
	color_tween.tween_property($ColorRect, "color", original_color, 0.15)
	invincibility_tween = create_tween()
	invincibility_tween.set_loops()
	invincibility_tween.tween_property($ColorRect, "modulate:a", 0.25, 0.1)
	invincibility_tween.tween_property($ColorRect, "modulate:a", 1.0, 0.1)

func stop_invincibility_flash() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
		invincibility_tween = null
	$ColorRect.modulate.a = 1.0

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	play_sfx(SFX_DEATH)
	stop_invincibility_flash()
	$ColorRect.color = Color(0.4, 0.05, 0.05)

	drop_currency_on_death()
	apply_difficulty_death_penalty()

	var death_screen = get_node_or_null("../DeathScreen")
	if death_screen:
		await death_screen.run_death_sequence(DEATH_COUNTDOWN_SECONDS)
	else:
		await get_tree().create_timer(DEATH_COUNTDOWN_SECONDS).timeout

	health = get_max_health()
	global_position = spawn_position
	$ColorRect.color = original_color
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

	if Input.is_action_just_pressed("equip_sword"):
		equip_weapon("sword")
	if Input.is_action_just_pressed("equip_spear"):
		equip_weapon("spear")
	if Input.is_action_just_pressed("equip_bow"):
		equip_weapon("bow")
	if Input.is_action_just_pressed("equip_wand"):
		equip_weapon("wand")

	if Input.is_action_just_pressed("admin_dash"):
		perform_admin_dash()

	if Input.is_action_just_pressed("admin_kill"):
		# bypasses invincible/take_damage entirely -- an instant dev/admin
		# kill for testing the death sequence, not a real damage source.
		die()

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
	var stats = WEAPONS[equipped_weapon]
	if not is_attacking:
		update_weapon_visual(stats.icon_offset)

	if not is_dashing and not is_knocked_back:
		velocity.x = direction * SPEED * skill_move_speed_mult()

	if Input.is_action_just_pressed("attack"):
		perform_attack()

	move_and_slide()

func perform_attack() -> void:
	if attack_cooldown_remaining > 0:
		return
	var stats = WEAPONS[equipped_weapon]
	attack_cooldown_remaining = stats.cooldown * skill_cooldown_mult(equipped_weapon)
	if equipped_weapon == "bow":
		animate_bow(stats)
		return
	if equipped_weapon == "spear":
		animate_spear(stats)
		return
	if equipped_weapon == "wand":
		cast_wand()
		return
	var aim_dir = get_aim_direction()
	$AttackArea.position = aim_dir * stats.range_offset
	$AttackArea.rotation = aim_dir.angle()
	var bodies = $AttackArea.get_overlapping_bodies()
	print("Attack pressed, bodies found: ", bodies)
	var target = closest_body(bodies)
	if target:
		if target.has_method("take_damage"):
			target.take_damage(int(round(stats.damage * skill_damage_mult("sword"))))
		if target.has_method("apply_knockback"):
			var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
			target.apply_knockback(knockback_sign_toward(target), knockback_distance)
	animate_sword()

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

	for enemy in get_tree().get_nodes_in_group("course_enemy"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage") and not enemy.is_dead:
			enemy.take_damage(999999)
	for combatant in get_tree().get_nodes_in_group("dungeon_combatant"):
		if is_instance_valid(combatant) and combatant.has_method("take_damage") and not combatant.is_dead:
			combatant.take_damage(999999)
