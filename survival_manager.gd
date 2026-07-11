extends Node

const ENEMY_SCENE = preload("res://enemy.tscn")
const BOSS_SCENE = preload("res://boss.tscn")

const ARENA_MIN_X = -695.0
const ARENA_Y = -63.0
const SPAWN_MARGIN = 15.0
const SPAWN_MIN_DISTANCE = 156.0
const SPAWN_MAX_DISTANCE = 260.0
const BOSS_WAVE_INTERVAL = 5
const BASE_ENEMY_COUNT = 2
const MAX_ENEMY_COUNT = 8
const WAVE_CLEAR_DELAY = 2.5
const START_COUNTDOWN_SECONDS = 3

const HP_SCALE_PER_WAVE = 0.15
const DMG_SCALE_PER_WAVE = 0.10
const SPEED_SCALE_PER_WAVE = 0.075
const SPEED_SCALE_CAP_WAVE = 25

const WEAPON_TYPES = ["sword", "spear", "bow"]

var current_wave = 0
var started = false
var starting = false
var alive_count = 0
var wave_in_progress = false

func _ready() -> void:
	update_wave_label()

func start_survival() -> void:
	if started or starting:
		return
	starting = true
	hide_course_enemies()
	run_start_countdown()

func run_start_countdown() -> void:
	var label = get_node_or_null("../CanvasLayer/CountdownLabel")
	for i in range(START_COUNTDOWN_SECONDS, 0, -1):
		if not starting:
			return
		if label:
			label.text = str(i)
			label.visible = true
			label.scale = Vector2(1.35, 1.35)
			var tween = label.create_tween()
			tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout
	if not starting:
		return
	if label:
		label.text = "FIGHT!"
		label.scale = Vector2(1.35, 1.35)
		var tween2 = label.create_tween()
		tween2.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	if not starting:
		return
	if label:
		label.visible = false
	starting = false
	started = true
	start_next_wave()

func hide_course_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("course_enemy"):
		if enemy.is_dead:
			# already dead / mid-respawn-wait -- its own die() coroutine
			# will hold off respawning until survival mode ends
			continue
		enemy.frozen_for_survival = true
		enemy.is_dead = true
		enemy.visible = false
		enemy.get_node("CollisionShape2D").set_deferred("disabled", true)

func get_spawn_x() -> float:
	var player = get_tree().get_first_node_in_group("player")
	var wall_edge_x = ARENA_MIN_X + SPAWN_MARGIN
	if player == null:
		return randf_range(wall_edge_x, wall_edge_x + SPAWN_MAX_DISTANCE)
	var px = player.global_position.x
	# spawns always follow the player's current position -- the only real
	# constraint is not spawning past the containment wall on the left
	var room_left = px - wall_edge_x
	var sides: Array = [1.0]
	if room_left >= SPAWN_MIN_DISTANCE:
		sides.append(-1.0)
	var side = sides[randi() % sides.size()]
	var max_dist = max(min(SPAWN_MAX_DISTANCE, room_left), SPAWN_MIN_DISTANCE) if side < 0.0 else SPAWN_MAX_DISTANCE
	var dist = randf_range(SPAWN_MIN_DISTANCE, max_dist)
	return max(px + side * dist, wall_edge_x)

func get_wave_scaling() -> Dictionary:
	var hp_mult = 1.0 + (current_wave - 1) * HP_SCALE_PER_WAVE
	var dmg_mult = 1.0 + (current_wave - 1) * DMG_SCALE_PER_WAVE
	var speed_wave = min(current_wave, SPEED_SCALE_CAP_WAVE)
	var speed_mult = 1.0 + (speed_wave - 1) * SPEED_SCALE_PER_WAVE
	return {"hp": hp_mult, "dmg": dmg_mult, "speed": speed_mult}

func start_next_wave() -> void:
	current_wave += 1
	wave_in_progress = true
	alive_count = 0
	GameState.record_wave(current_wave)
	var is_boss_wave = current_wave % BOSS_WAVE_INTERVAL == 0
	if is_boss_wave:
		spawn_boss()
		show_notification("Wave " + str(current_wave) + " - BOSS INCOMING")
	else:
		var count = min(BASE_ENEMY_COUNT + current_wave - 1, MAX_ENEMY_COUNT)
		for i in range(count):
			spawn_wave_enemy()
		show_notification("Wave " + str(current_wave))
	update_wave_label()

func spawn_wave_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var scaling = get_wave_scaling()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	enemy.position = Vector2(get_spawn_x(), ARENA_Y)
	enemy.add_to_group("wave_combatant")
	get_parent().add_child(enemy)
	enemy.died.connect(_on_combatant_died)
	alive_count += 1

func spawn_boss() -> void:
	var boss = BOSS_SCENE.instantiate()
	var scaling = get_wave_scaling()
	boss.max_health = int(round(boss.MAX_HEALTH * scaling.hp))
	boss.damage_multiplier = scaling.dmg
	boss.speed_multiplier = scaling.speed
	boss.position = Vector2(get_spawn_x(), ARENA_Y)
	boss.add_to_group("wave_combatant")
	get_parent().add_child(boss)
	boss.died.connect(_on_combatant_died)
	alive_count += 1

func _on_combatant_died() -> void:
	alive_count -= 1
	if alive_count <= 0 and wave_in_progress:
		wave_in_progress = false
		show_notification("Wave " + str(current_wave) + " cleared!")
		await get_tree().create_timer(WAVE_CLEAR_DELAY).timeout
		if started:
			start_next_wave()

func exit_survival() -> void:
	if not started and not starting:
		return
	starting = false
	var label = get_node_or_null("../CanvasLayer/CountdownLabel")
	if label:
		label.visible = false
	for c in get_tree().get_nodes_in_group("wave_combatant"):
		if is_instance_valid(c):
			c.queue_free()
	for enemy in get_tree().get_nodes_in_group("course_enemy"):
		if not enemy.frozen_for_survival:
			# genuinely mid-death/respawn-wait -- let its own die() coroutine
			# handle restoring it properly once started == false
			continue
		enemy.frozen_for_survival = false
		enemy.is_dead = false
		enemy.visible = true
		enemy.get_node("CollisionShape2D").set_deferred("disabled", false)
	started = false
	current_wave = 0
	alive_count = 0
	wave_in_progress = false
	update_wave_label()
	show_notification("Wave Survival exited")

func update_wave_label() -> void:
	var label = get_node_or_null("../CanvasLayer/WaveLabel")
	if label:
		label.text = "Wave: " + str(current_wave) + "  (Best: " + str(GameState.best_wave) + ")"
		label.visible = current_wave > 0

func show_notification(text: String) -> void:
	var stack = get_node_or_null("../CanvasLayer/NotificationStack")
	if stack:
		stack.show_notification(text)
