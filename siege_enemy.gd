extends CharacterBody2D

# A besieger: marches east out of the evil lands toward the village wall and
# hammers it. Once the wall is breached (or if there is no wall), it pushes on
# to the nearest defender -- Orin the wizard, a villager, or the player -- and
# attacks them instead. Killable by the player's weapons AND Orin's meteors
# (collision_layer 4 like course enemies + in the "siege_enemy" group).
#
# Spawned and scaled by siege_manager.gd; stats (max_health / attack_damage)
# are injected before it enters the tree.

signal died

const GRAVITY = 900.0
const SPEED = 66.0
const ATTACK_RANGE = 44.0
const ATTACK_STOP_GAP = 34.0     # how far from the target it plants to attack
const ATTACK_COOLDOWN = 1.2
const KNOCKBACK_DURATION = 0.12
const DEFENDER_SEEK_RANGE = 700.0

# Injected by the SiegeManager (defaults are a sane tier-1 statline).
var max_health = 55
var health = 55
var attack_damage = 11
var reward = 6

var is_dead = false

# --- Statuses. Siege enemies had NO apply_status, so a DoT build's whole kit
# silently did nothing during sieges. Same substrate as special mobs: DoT in
# full, slow in full, freeze = hard slow (their march was never written to be
# stopped dead).
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
	var now := Time.get_ticks_msec() / 1000.0
	match kind:
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
		update_health_bar_fill()
		if health <= 0:
			die()
var is_knocked_back = false
var wall: Node2D = null
# 10 (Shrine, decided delegated): a corruption demon REMEMBERS who it was --
# the villager snapshot rides along so putting it down can become a cleansing
var was_villager: Dictionary = {}
var attack_cooldown_remaining = 0.0
var facing = 1

# Faction: "raider" (default) marches on the wall/village; "village" is a
# Barracks soldier that sallies out and fights the raiders instead. Set (with
# an optional sprite skin from art/enemies/) before add_child.
var faction := "raider"
var skin := ""

# --- Hero powers (village units only) ---
# A Barracks-forged HERO doesn't fight like a big soldier -- at graduation each
# rolls a personal power (see GameState.graduate_villager), and their siege
# unit expresses it on the field:
#   warcry    -- taking the field, all raiders nearby stagger slow in dread
#   stormhand -- every blow chains a shock into a second raider
#   unbroken  -- the first death each siege doesn't take: stands back up at half
#   rally     -- their presence hardens every soldier who marches beside them
#                (applied at spawn by siege_manager: +50% soldier HP)
var hero_power := ""
var hero_name := ""
var _unbroken_spent := false
const WARCRY_RADIUS := 300.0
const STORMHAND_RADIUS := 150.0
const STORMHAND_FRAC := 0.4
const MELEE_ENGAGE_RANGE := 66.0   # a raider fights an in-its-face soldier over the wall

var body: Node2D = null
var body_rect: ColorRect = null
var skin_sprite: AnimatedSprite2D = null
var skin_attack_timer := 0.0
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

# After breaching the wall, besiegers go for whatever's nearest: the wizard,
# villagers, the player, AND the buildings themselves (to raze the village).
const DEFENDER_GROUPS = ["village_defender", "npc", "player", "building"]
# THE ARRIVAL FIGHT (2.4.1, fixed 2026-07-21 from live playtest): with
# wall=null the road raiders fell through to the post-breach list above and
# marched 4km EAST toward the nearest BUILDING -- dragging the trio with
# them, so the player fought nobody, heard Wren's bow forever, and the
# "beside Roland" dialogue played to an empty road. Arrival raiders fight
# the people in front of them, and nothing else.
var arrival_mode := false
# THEATRICAL (dev 2026-07-22): the arrival fight is STAGED at new-game start so the
# trio + raiders are already trading blows when the player walks up -- no pop-in.
# While theatrical a raider shadow-boxes: it swings at the trio but deals NO damage
# and CANNOT be killed, so nobody falls before the player triggers the scene. The
# approach (main.trigger_arrival_scene) clears this and the fight turns real.
var theatrical := false

func _ready() -> void:
	if faction == "village":
		# a friendly Barracks soldier: raiders target it (village_defender), and
		# it is NOT in "siege_enemy" and NOT on the player-weapon layer.
		add_to_group("village_defender")
		collision_layer = 0
	else:
		add_to_group("siege_enemy")
		collision_layer = 4   # course-enemy layer -> the player's weapons hit it
	collision_mask = 1        # collide with ground only
	preload("res://char_shadow.gd").attach(self, 0.5, 0.0)   # grounding shadow (feet at y0)
	health = max_health

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(26.0, 40.0)
	shape.shape = rect
	shape.position = Vector2(0, -20.0)
	add_child(shape)

	# arrival raiders fight PEOPLE, never stone -- the auto-acquire here was
	# silently overriding wall=null and sending them marching at the village
	if wall == null and not arrival_mode:
		wall = get_tree().get_first_node_in_group("village_wall")

	if skin != "":
		build_skin_visual()
	else:
		build_visual()
	build_health_bar()
	# a hero announces themselves: name overhead, and Warcry lands on arrival
	if hero_power != "":
		var hl := Label.new()
		hl.text = "★ %s" % hero_name
		hl.position = Vector2(-60, -64)
		hl.size = Vector2(120, 14)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.add_theme_font_size_override("font_size", 10)
		hl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		hl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hl.add_theme_constant_override("outline_size", 3)
		add_child(hl)
		if hero_power == "warcry":
			call_deferred("_do_warcry")

const SFX_WARCRY = preload("res://audio/explosion.wav")

func _do_warcry() -> void:
	var sp = AudioStreamPlayer2D.new()
	sp.stream = SFX_WARCRY
	sp.pitch_scale = 0.6   # slowed into a roar rather than a blast
	sp.global_position = global_position
	get_parent().add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)
	var caught := false
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if is_instance_valid(r) and r.has_method("apply_status") \
				and not ("is_dead" in r and r.is_dead) \
				and global_position.distance_to(r.global_position) <= WARCRY_RADIUS:
			r.apply_status("slow", 3.0, 0.5)
			caught = true
	if caught:
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -70), "WARCRY!", Color(1.0, 0.75, 0.3))

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	tick_statuses(delta)
	if is_dead:            # a burn/poison tick can kill mid-frame -- stop before a
		return             # corpse falls, marches, or lands a final attack (enemy.gd guards this too)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining -= delta

	if is_knocked_back:
		move_and_slide()
		return

	if skin_attack_timer > 0.0:
		skin_attack_timer -= delta

	var target = current_target()
	if target == null:
		# nothing to hit yet -> raiders push into the village (+x), soldiers march
		# out to meet them (-x)
		velocity.x = (SPEED if faction == "raider" else -SPEED) * status_slow_mult()
	else:
		# approach the target from whichever side we're on, then attack
		var stop_x = target_stop_x(target)
		if absf(stop_x - global_position.x) > 2.0:
			velocity.x = signf(stop_x - global_position.x) * SPEED * status_slow_mult()
		else:
			velocity.x = 0.0
			try_attack(target)

	if velocity.x > 0.1:
		facing = 1
	elif velocity.x < -0.1:
		facing = -1
	if body:
		body.scale.x = facing
	if skin_sprite:
		_update_skin_anim()
	move_and_slide()

# Raider: the wall while it stands, but retaliate against a soldier already in
# its face; then the nearest defender. Village soldier: the nearest raider.
func current_target() -> Node2D:
	if faction == "village":
		return nearest_raider()
	var d = nearest_defender()
	if d != null and global_position.distance_to(d.global_position) <= MELEE_ENGAGE_RANGE:
		return d
	if is_instance_valid(wall) and not wall.breached:
		return wall
	return d

func nearest_defender() -> Node2D:
	var best: Node2D = null
	var best_d = DEFENDER_SEEK_RANGE
	# theatrical raiders shadow-box the TRIO only -- never the player (who can walk
	# right up to the staged fight before the scene without being swung at)
	var groups: Array = (["adventurer"] if theatrical \
		else (["adventurer", "player"] if arrival_mode else DEFENDER_GROUPS))
	for group_name in groups:
		for d in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(d) or not d.has_method("take_damage"):
				continue
			if "is_dead" in d and d.is_dead:
				continue
			# skip targets that can't actually TAKE damage right now -- else a raider parks
			# on an invulnerable target forever and the live siege never ends (softlock that
			# wedges live_siege_active: blocks future sieges, the Black Tide, care-seeking):
			#  - a villager sheltered inside a building (npc.take_damage no-ops)
			#  - a ruined/unfinished building (building.take_damage no-ops)
			if "is_in_building" in d and d.is_in_building:
				continue
			if "build_stage" in d and (int(d.build_stage) < GameState.TOTAL_BUILD_STAGES or int(d.health) <= 0):
				continue
			var dist = global_position.distance_to(d.global_position)
			if dist < best_d:
				best_d = dist
				best = d
	return best

# A soldier's target: the nearest living raider.
func nearest_raider() -> Node2D:
	var best: Node2D = null
	var best_d = DEFENDER_SEEK_RANGE
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		var dist = global_position.distance_to(r.global_position)
		if dist < best_d:
			best_d = dist
			best = r
	return best

func target_stop_x(target: Node2D) -> float:
	if target == wall and is_instance_valid(wall):
		# Plant on whichever face we are APPROACHING FROM, so we physically stop at
		# the wall and can NEVER walk through it. Was flank-based (dev 2026-07-23:
		# "placed the wall as the tutorial said, the wave passed through") -- a west
		# raider hitting a wall the game had labelled 'east' aimed at its FAR face and
		# marched clean through. Approach-based is right for both fronts anyway: west
		# raiders come from the west and stop at west_face; east raiders from the east.
		if global_position.x <= wall.global_position.x:
			return wall.west_face_x() - ATTACK_STOP_GAP
		return wall.east_face_x() + ATTACK_STOP_GAP
	# plant on whichever side we're approaching from
	if global_position.x <= target.global_position.x:
		return target.global_position.x - ATTACK_STOP_GAP
	return target.global_position.x + ATTACK_STOP_GAP

func try_attack(target: Node2D) -> void:
	if attack_cooldown_remaining > 0.0 or not is_instance_valid(target):
		return
	# only the wall is reached purely by x; a defender must be genuinely close
	if target != wall and global_position.distance_to(target.global_position) > ATTACK_RANGE + ATTACK_STOP_GAP:
		return
	attack_cooldown_remaining = ATTACK_COOLDOWN
	# a theatrical raider still SWINGS (below) but its blow lands for nothing --
	# the staged shadow-fight can't hurt anyone until the scene turns it real
	if target.has_method("take_damage") and not theatrical:
		target.take_damage(attack_damage)
		# Stormhand: the blow arcs on into a second raider nearby
		if hero_power == "stormhand":
			for r in get_tree().get_nodes_in_group("siege_enemy"):
				if r != target and is_instance_valid(r) and r.has_method("take_damage") \
						and not ("is_dead" in r and r.is_dead) \
						and target.global_position.distance_to(r.global_position) <= STORMHAND_RADIUS:
					r.take_damage(int(round(attack_damage * STORMHAND_FRAC)))
					break
	skin_attack_timer = 0.4
	animate_attack()

func animate_attack() -> void:
	if not body:
		return
	var t = body.create_tween()
	t.tween_property(body, "position:x", 8.0 * facing, 0.1)
	t.tween_property(body, "position:x", 0.0, 0.18)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	if theatrical:
		return                        # a staged shadow-raider can't be felled yet
	health -= amount
	update_health_bar_fill()
	if health <= 0:
		# Unbroken: the first death each siege doesn't take
		if hero_power == "unbroken" and not _unbroken_spent:
			_unbroken_spent = true
			health = int(max_health / 2.0)
			update_health_bar_fill()
			FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -60), "UNBROKEN", Color(1.0, 0.95, 0.6))
			return
		die()
	else:
		flash_hit()

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	is_knocked_back = true
	velocity.x = direction_sign * (distance / KNOCKBACK_DURATION)
	# a DoT tick can kill+free a non-skinned raider (die() frees immediately, no anim await)
	# mid-knockback; re-resolve self after the wait so we never write to a freed instance.
	var id := get_instance_id()
	await get_tree().create_timer(KNOCKBACK_DURATION).timeout
	var s = instance_from_id(id)
	if s != null and is_instance_valid(s) and not s.is_dead:
		s.is_knocked_back = false

func flash_hit() -> void:
	if skin_sprite != null:
		skin_sprite.modulate = Color(2.4, 2.4, 2.4)
		skin_sprite.create_tween().tween_property(skin_sprite, "modulate", Color(1, 1, 1), 0.15)
		return
	if not body_rect:
		return
	var base = body_rect.color
	body_rect.color = Color(1, 1, 1)
	var t = body_rect.create_tween()
	t.tween_property(body_rect, "color", base, 0.15)

func die() -> void:
	if is_dead:
		return   # a second die() would double-emit `died` and drive alive_count negative
	is_dead = true
	# THE CLEANSING (10): if this thing was once a villager and the Shrine
	# stands ready with its shards, putting it down gives them BACK -- the
	# only mercy corruption has. Otherwise, the loss is what it always was.
	if not was_villager.is_empty():
		GameState.try_cleanse(was_villager)
		was_villager = {}
	# FORESHADOWING (GAME_BIBLE 9.8): once, mid-game, a single dying raider
	# turns and BOWS -- not to you, to the horizon, the way the whole horde
	# will kneel at the gate of 100. No notification, no fanfare: blink and
	# you miss it, remember it forever at the reveal.
	if faction == "raider" and not GameState.seen_kneel_echo and GameState.highest_unlocked_level >= 35:
		GameState.seen_kneel_echo = true
		if body:
			var t = body.create_tween()
			t.tween_property(body, "rotation_degrees", 24.0, 0.5)
	if faction == "village":
		# a fallen soldier is the town's loss, not a payout to the player
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("A village soldier has fallen defending the wall.")
		_finish_death()
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_currency"):
		player.add_currency(reward)
	var smat = GameState.roll_construction_drop(player)
	if smat != "":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Salvaged " + Inventory.get_display_name(smat) + " from the raider.")
	GameState.add_xp(6)
	_finish_death()

# Play the death animation (if skinned) then remove the unit.
func _finish_death() -> void:
	spawn_death_particles()
	died.emit()
	if skin_sprite != null:
		skin_sprite.play("death")
		var t = skin_sprite.create_tween()
		t.tween_property(skin_sprite, "modulate:a", 0.0, 0.45).set_delay(0.18)
		await t.finished
	queue_free()

# --- Sprite skin (shared with dungeon enemies via EnemySkins) ---
const SKIN_SCALE := 3.1    # x5 from the first pass (0.62) -- developer sizing call

func build_skin_visual() -> void:
	body = Node2D.new()
	add_child(body)
	skin_sprite = AnimatedSprite2D.new()
	skin_sprite.sprite_frames = EnemySkins.frames_for(skin)
	skin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# PixelLab skins normalise to a consistent on-screen height; CraftPix strip
	# skins keep their approved fixed scale.
	var sc = (EnemySkins.TARGET_HEIGHT / EnemySkins.content_height(skin)) if EnemySkins.is_per_frame(skin) else SKIN_SCALE
	skin_sprite.scale = Vector2(sc, sc)
	# this body's ORIGIN IS AT THE FEET (collision spans -40..0): lift the frame
	# by the character's MEASURED feet position so they land exactly at y = 0
	skin_sprite.offset = Vector2(0, -EnemySkins.feet_px(skin))
	skin_sprite.animation = "idle"
	skin_sprite.play("idle")
	body.add_child(skin_sprite)

func _update_skin_anim() -> void:
	if skin_sprite == null:
		return
	var want := "idle"
	if skin_attack_timer > 0.0:
		want = "attack"
	elif absf(velocity.x) > 5.0:
		want = "walk"
	if skin_sprite.animation != want:
		skin_sprite.play(want)

func spawn_death_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position + Vector2(0, -18)
	particles.z_index = 10
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 14
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 120)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = Color(0.6, 0.1, 0.15, 1.0)
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func build_visual() -> void:
	body = Node2D.new()
	add_child(body)
	# hooded dark figure
	body_rect = ColorRect.new()
	body_rect.size = Vector2(26, 38)
	body_rect.position = Vector2(-13, -38)
	body_rect.color = Color(0.32, 0.1, 0.14, 1.0)
	body.add_child(body_rect)
	# hood
	var hood = Polygon2D.new()
	hood.polygon = PackedVector2Array([Vector2(-13, -34), Vector2(13, -34), Vector2(9, -46), Vector2(-9, -46)])
	hood.color = Color(0.2, 0.06, 0.1, 1.0)
	body.add_child(hood)
	# two glowing eyes
	for sx in [-5, 5]:
		var eye = ColorRect.new()
		eye.size = Vector2(3, 3)
		eye.position = Vector2(sx - 1.5, -30)
		eye.color = Color(1.0, 0.75, 0.2, 1.0)
		body.add_child(eye)

func build_health_bar() -> void:
	# skinned units are much taller than the procedural body: put the bar above
	# the sprite's head instead of inside its chest
	var bar_y := -54.0
	if skin != "":
		bar_y = -(25.0 + 50.0 * 0.75) * SKIN_SCALE - 12.0
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(34, 5)
	health_bar_bg.position = Vector2(-17, bar_y)
	health_bar_bg.z_index = 20
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	# friendly units read green at a glance; hostiles red
	health_bar_fill.color = Color(0.25, 0.8, 0.3, 1.0) if faction == "village" else Color(0.85, 0.2, 0.2, 1.0)
	health_bar_fill.size = Vector2(34, 5)
	health_bar_fill.position = Vector2(-17, bar_y)
	health_bar_fill.z_index = 21
	add_child(health_bar_fill)

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = 34.0 * clamp(float(health) / max_health, 0.0, 1.0)
