extends Node2D

# Dungeons are a real separate scene the player is teleported into (see
# level_select_ui.gd), roughly half the width of the overworld combat
# course. Layouts cycle every 5 levels: (level-1)%5 gives 0-3 for one of 4
# regular platform arrangements, or exactly 4 on every 5th level (5, 10,
# 15...), which uses ONE unique boss arena layout instead.
const DUNGEON_WIDTH = 2600.0
const GROUND_Y = -39.0
const CEILING_Y = -480.0
const ENTRY_X = 140.0

const REGULAR_LAYOUTS = [
	# 0 -- "Ascending Steps": a rough staircase climbing left to right.
	[
		{"x": 320.0, "y": -120.0, "w": 180.0},
		{"x": 640.0, "y": -200.0, "w": 160.0},
		{"x": 980.0, "y": -280.0, "w": 160.0},
		{"x": 1380.0, "y": -220.0, "w": 200.0},
		{"x": 1780.0, "y": -140.0, "w": 180.0},
		{"x": 2160.0, "y": -260.0, "w": 160.0},
	],
	# 1 -- "Scattered Isles": small floating platforms, wider gaps.
	[
		{"x": 260.0, "y": -160.0, "w": 120.0},
		{"x": 530.0, "y": -260.0, "w": 100.0},
		{"x": 830.0, "y": -180.0, "w": 140.0},
		{"x": 1160.0, "y": -320.0, "w": 110.0},
		{"x": 1490.0, "y": -200.0, "w": 130.0},
		{"x": 1860.0, "y": -300.0, "w": 120.0},
		{"x": 2210.0, "y": -180.0, "w": 140.0},
	],
	# 2 -- "Twin Ledges over a Pit": symmetric flanking ledges, high spine.
	[
		{"x": 230.0, "y": -140.0, "w": 220.0},
		{"x": 570.0, "y": -240.0, "w": 160.0},
		{"x": 1300.0, "y": -340.0, "w": 200.0},
		{"x": 2030.0, "y": -240.0, "w": 160.0},
		{"x": 2370.0, "y": -140.0, "w": 220.0},
	],
	# 3 -- "Long Overwatch": one long high spine over lower stepping stones.
	[
		{"x": 1300.0, "y": -300.0, "w": 700.0},
		{"x": 360.0, "y": -150.0, "w": 150.0},
		{"x": 760.0, "y": -190.0, "w": 130.0},
		{"x": 1900.0, "y": -190.0, "w": 130.0},
		{"x": 2300.0, "y": -150.0, "w": 150.0},
	],
]
const BOSS_LAYOUT = [
	{"x": 500.0, "y": -220.0, "w": 320.0},
	{"x": 2100.0, "y": -220.0, "w": 320.0},
]

const PLATFORM_HEIGHT = 20.0
const PLATFORM_COLOR = Color(0.3, 0.26, 0.24, 1.0)

const MIN_MINES = 8
const MAX_MINES = 14
const BOSS_MIN_MINES = 10
const BOSS_MAX_MINES = 16
const MINE_SAFE_ZONE = 220.0
const TRAP_SCENE = preload("res://trap.tscn")

const ENEMY_SCENE = preload("res://enemy.tscn")
const BOSS_SCENE = preload("res://boss.tscn")
const WEAPON_TYPES = ["sword", "spear", "bow"]
const BASE_ENEMY_COUNT = 2
const MAX_ENEMY_COUNT = 8
const HP_SCALE_PER_LEVEL = 0.15
const DMG_SCALE_PER_LEVEL = 0.10
const SPEED_SCALE_PER_LEVEL = 0.075
const SPEED_SCALE_CAP_LEVEL = 25
const START_COUNTDOWN_SECONDS = 3
const LEVEL_CLEAR_DELAY = 2.5
const MAX_LEVEL = 100

const BG_TOP_COLOR = Color(0.03, 0.025, 0.05, 1.0)
const BG_BOTTOM_COLOR = Color(0.09, 0.06, 0.11, 1.0)
const BOSS_BG_TOP_COLOR = Color(0.09, 0.015, 0.015, 1.0)
const BOSS_BG_BOTTOM_COLOR = Color(0.17, 0.035, 0.03, 1.0)
const WALL_COLOR_FAR = Color(0.09, 0.07, 0.11, 1.0)
const WALL_COLOR_NEAR = Color(0.14, 0.11, 0.16, 1.0)
const TORCH_SPACING = 380.0
const TORCH_COLOR = Color(1.0, 0.55, 0.15, 1.0)
const STALACTITE_COLOR = Color(0.11, 0.09, 0.13, 1.0)

var music: AudioStreamWAV = preload("res://audio/dungeon_music.wav")

# pause_menu.gd (shared with the overworld) reads these off whichever node
# is named "DungeonManager" -- this scene's root plays that role here, and
# unlike the overworld's stub, a dungeon run really IS always active while
# this scene is loaded.
var started = true
var starting = false
var current_level = 1
var alive_count = 0
var level_in_progress = false
# set once the current level's combat is fully cleared -- this is what arms
# the forward gate (advancing is a manual walk through it now, never automatic)
var level_cleared = false

const GATE_SCRIPT = preload("res://dungeon_gate.gd")

func _ready() -> void:
	GameState.in_dungeon = true
	current_level = GameState.active_dungeon_level
	build_level_visuals(current_level)
	place_player_at_entry(false)
	update_level_label()
	setup_exit_button()
	start_music()
	run_start_countdown()

func setup_exit_button() -> void:
	var exit_button = get_node_or_null("CanvasLayer/ExitDungeonButton")
	if exit_button:
		exit_button.visible = true
		exit_button.pressed.connect(exit_dungeon)

# 10 seconds of 16-bit mono at 44.1kHz -- must match the synthesized file.
const DUNGEON_MUSIC_LOOP_SAMPLES = 441000

func start_music() -> void:
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# loop_end defaults to 0, and a [0,0] loop region plays as pure silence --
	# the loop bounds have to be set explicitly (same as main.gd's music).
	music.loop_begin = 0
	music.loop_end = DUNGEON_MUSIC_LOOP_SAMPLES
	$MusicPlayer.stream = music
	$MusicPlayer.play()

# --- layout selection ---

func get_layout_slot(level: int) -> int:
	return (level - 1) % 5

func is_boss_level(level: int) -> bool:
	return get_layout_slot(level) == 4

func get_layout(level: int) -> Array:
	if is_boss_level(level):
		return BOSS_LAYOUT
	return REGULAR_LAYOUTS[get_layout_slot(level)]

# --- level (re)building ---

func build_level_visuals(level: int) -> void:
	for child in $LevelContainer.get_children():
		child.queue_free()
	var boss = is_boss_level(level)
	build_background(boss)
	build_ground_and_walls()
	var layout = get_layout(level)
	build_platforms(layout)
	build_stalactites(boss)
	build_torches(boss)
	place_mines(boss, layout)
	build_gates()

func build_gates() -> void:
	var back_gate = GATE_SCRIPT.new()
	back_gate.direction = "back"
	back_gate.manager = self
	back_gate.position = Vector2(46.0, GROUND_Y)
	$LevelContainer.add_child(back_gate)
	var forward_gate = GATE_SCRIPT.new()
	forward_gate.direction = "forward"
	forward_gate.manager = self
	forward_gate.position = Vector2(DUNGEON_WIDTH - 46.0, GROUND_Y)
	$LevelContainer.add_child(forward_gate)

# Both gates funnel through here. Back: level 1 leaves the dungeon, deeper
# levels retreat one (usable any time, even mid-fight, as an escape hatch).
# Forward: locked until the level is cleared; on the final level it exits.
func on_gate_used(direction: String) -> void:
	if direction == "back":
		if current_level <= 1:
			exit_dungeon()
		else:
			go_to_level(current_level - 1, true)
		return
	if not level_cleared:
		show_notification("The way down is sealed -- clear this level first!")
		return
	if current_level >= MAX_LEVEL:
		show_notification("All " + str(MAX_LEVEL) + " dungeon levels cleared!")
		exit_dungeon()
	else:
		go_to_level(current_level + 1, false)

func go_to_level(level: int, enter_from_right: bool) -> void:
	current_level = level
	build_level_visuals(current_level)
	place_player_at_entry(enter_from_right)
	spawn_level_combat()

func build_background(boss: bool) -> void:
	var top_color = BOSS_BG_TOP_COLOR if boss else BG_TOP_COLOR
	var bottom_color = BOSS_BG_BOTTOM_COLOR if boss else BG_BOTTOM_COLOR
	var sky_top = ColorRect.new()
	sky_top.color = top_color
	sky_top.z_index = -100
	sky_top.position = Vector2(-150, -900)
	sky_top.size = Vector2(DUNGEON_WIDTH + 300, 500)
	$LevelContainer.add_child(sky_top)
	var sky_bottom = ColorRect.new()
	sky_bottom.color = bottom_color
	sky_bottom.z_index = -100
	sky_bottom.position = Vector2(-150, -400)
	sky_bottom.size = Vector2(DUNGEON_WIDTH + 300, 400)
	$LevelContainer.add_child(sky_bottom)
	build_wall_layer(-90.0, 240.0, 5, WALL_COLOR_FAR, -95)
	build_wall_layer(-55.0, 170.0, 6, WALL_COLOR_NEAR, -90)

# A jagged ridge silhouette, reusing the same "a few random peaks blended
# with falloff, plus fine jitter" technique that made the overworld
# mountains read as natural rather than random zigzag -- here inverted to
# hang from the ceiling as cave-wall texture.
func build_wall_layer(y_offset: float, height: float, peak_count: int, color: Color, z: int) -> void:
	var points = PackedVector2Array()
	var segments = max(peak_count * 6, 18)
	var peak_positions = []
	var peak_heights = []
	for p in range(peak_count):
		peak_positions.append(randf_range(0.05, 0.95))
		peak_heights.append(randf_range(0.6, 1.0))
	points.append(Vector2(0, y_offset))
	for i in range(1, segments):
		var t = float(i) / float(segments)
		var x = t * DUNGEON_WIDTH
		var influence = 0.0
		for p in range(peak_count):
			var dist = absf(t - peak_positions[p])
			influence = max(influence, max(0.0, 1.0 - dist * 3.2) * peak_heights[p])
		var jitter = 1.0 + randf_range(-0.08, 0.08)
		points.append(Vector2(x, y_offset + height * (0.3 + 0.7 * influence) * jitter))
	points.append(Vector2(DUNGEON_WIDTH, y_offset))
	points.append(Vector2(DUNGEON_WIDTH, CEILING_Y - 40.0))
	points.append(Vector2(0, CEILING_Y - 40.0))
	var wall = Polygon2D.new()
	wall.polygon = points
	wall.color = color
	wall.z_index = z
	$LevelContainer.add_child(wall)

func build_ground_and_walls() -> void:
	var ground = StaticBody2D.new()
	ground.position = Vector2(DUNGEON_WIDTH / 2.0, GROUND_Y + 40.0)
	var gshape = CollisionShape2D.new()
	var grect = RectangleShape2D.new()
	grect.size = Vector2(DUNGEON_WIDTH + 200.0, 80.0)
	gshape.shape = grect
	ground.add_child(gshape)
	var ground_visual = ColorRect.new()
	ground_visual.size = Vector2(DUNGEON_WIDTH + 200.0, 80.0)
	ground_visual.position = Vector2(-(DUNGEON_WIDTH + 200.0) / 2.0, -40.0)
	ground_visual.color = Color(0.2, 0.17, 0.15, 1.0)
	ground.add_child(ground_visual)
	var ground_top_edge = ColorRect.new()
	ground_top_edge.size = Vector2(DUNGEON_WIDTH + 200.0, 6.0)
	ground_top_edge.position = Vector2(-(DUNGEON_WIDTH + 200.0) / 2.0, -40.0)
	ground_top_edge.color = Color(0.26, 0.22, 0.19, 1.0)
	ground.add_child(ground_top_edge)
	$LevelContainer.add_child(ground)

	build_wall(-40.0)
	build_wall(DUNGEON_WIDTH + 40.0)

func build_wall(x: float) -> void:
	var wall = StaticBody2D.new()
	wall.position = Vector2(x, GROUND_Y - 200.0)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(20.0, 500.0)
	shape.shape = rect
	wall.add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(20.0, 500.0)
	visual.position = Vector2(-10.0, -250.0)
	visual.color = Color(0.13, 0.1, 0.12, 1.0)
	wall.add_child(visual)
	$LevelContainer.add_child(wall)

func build_platforms(layout: Array) -> void:
	for plat in layout:
		var body = StaticBody2D.new()
		body.position = Vector2(plat.x, plat.y)
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(plat.w, PLATFORM_HEIGHT)
		shape.shape = rect
		shape.one_way_collision = true
		body.add_child(shape)
		var visual = ColorRect.new()
		visual.size = Vector2(plat.w, PLATFORM_HEIGHT)
		visual.position = Vector2(-plat.w / 2.0, -PLATFORM_HEIGHT / 2.0)
		visual.color = PLATFORM_COLOR
		body.add_child(visual)
		var edge = ColorRect.new()
		edge.size = Vector2(plat.w, 4.0)
		edge.position = Vector2(-plat.w / 2.0, -PLATFORM_HEIGHT / 2.0)
		edge.color = PLATFORM_COLOR.lightened(0.18)
		body.add_child(edge)
		$LevelContainer.add_child(body)

func build_stalactites(boss: bool) -> void:
	var count = 14 if boss else 10
	for i in range(count):
		var x = randf_range(40.0, DUNGEON_WIDTH - 40.0)
		var h = randf_range(30.0, 75.0)
		var w = randf_range(10.0, 22.0)
		var stalactite = Polygon2D.new()
		stalactite.polygon = PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(w / 2.0, 0), Vector2(0, h)])
		stalactite.color = STALACTITE_COLOR.darkened(randf_range(0.0, 0.15))
		stalactite.position = Vector2(x, CEILING_Y)
		$LevelContainer.add_child(stalactite)

func make_additive_material() -> CanvasItemMaterial:
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func build_torches(boss: bool) -> void:
	var count = int(DUNGEON_WIDTH / TORCH_SPACING)
	for i in range(count):
		var x = 180.0 + i * TORCH_SPACING + randf_range(-40.0, 40.0)
		build_torch(Vector2(clamp(x, 60.0, DUNGEON_WIDTH - 60.0), GROUND_Y))

func build_torch(pos: Vector2) -> void:
	var torch = Node2D.new()
	torch.position = pos
	$LevelContainer.add_child(torch)

	var pole = ColorRect.new()
	pole.color = Color(0.22, 0.16, 0.11, 1.0)
	pole.size = Vector2(6.0, 30.0)
	pole.position = Vector2(-3.0, -30.0)
	torch.add_child(pole)

	var glow = Polygon2D.new()
	var glow_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		glow_points.append(Vector2(cos(angle), sin(angle)) * 28.0)
	glow.polygon = glow_points
	glow.color = Color(TORCH_COLOR.r, TORCH_COLOR.g, TORCH_COLOR.b, 0.32)
	glow.position = Vector2(0, -38.0)
	glow.material = make_additive_material()
	torch.add_child(glow)

	var flame = Polygon2D.new()
	flame.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, -16)])
	flame.color = TORCH_COLOR
	flame.position = Vector2(0, -38.0)
	torch.add_child(flame)

	var flicker = flame.create_tween()
	flicker.set_loops()
	flicker.tween_property(flame, "scale", Vector2(1.15, 0.85), randf_range(0.15, 0.25))
	flicker.tween_property(flame, "scale", Vector2(0.88, 1.12), randf_range(0.15, 0.25))
	flicker.tween_property(flame, "scale", Vector2.ONE, randf_range(0.15, 0.25))

func place_mines(boss: bool, layout: Array) -> void:
	var ground_count = randi_range(BOSS_MIN_MINES, BOSS_MAX_MINES) if boss else randi_range(MIN_MINES, MAX_MINES)
	for i in range(ground_count):
		var x = randf_range(60.0, DUNGEON_WIDTH - 60.0)
		# keep both doorway areas mine-free so entering/leaving is never a trap
		if absf(x - ENTRY_X) < MINE_SAFE_ZONE or absf(x - (DUNGEON_WIDTH - 46.0)) < 150.0:
			continue
		place_mine(Vector2(x, GROUND_Y))
	for plat in layout:
		if randf() < 0.5:
			var x = plat.x + randf_range(-plat.w * 0.3, plat.w * 0.3)
			place_mine(Vector2(x, plat.y))

func place_mine(pos: Vector2) -> void:
	var mine = TRAP_SCENE.instantiate()
	mine.position = pos
	$LevelContainer.add_child(mine)

func place_player_at_entry(enter_from_right: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var x = (DUNGEON_WIDTH - ENTRY_X) if enter_from_right else ENTRY_X
		player.global_position = Vector2(x, GROUND_Y - 100.0)
		player.velocity = Vector2.ZERO

# --- combat flow (mirrors the old overworld dungeon_manager.gd) ---

func run_start_countdown() -> void:
	starting = true
	var label = get_node_or_null("CanvasLayer/CountdownLabel")
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
	if label:
		label.visible = false
	starting = false
	spawn_level_combat()

func get_level_scaling() -> Dictionary:
	var hp_mult = 1.0 + (current_level - 1) * HP_SCALE_PER_LEVEL
	var dmg_mult = 1.0 + (current_level - 1) * DMG_SCALE_PER_LEVEL
	var speed_level = min(current_level, SPEED_SCALE_CAP_LEVEL)
	var speed_mult = 1.0 + (speed_level - 1) * SPEED_SCALE_PER_LEVEL
	return {"hp": hp_mult, "dmg": dmg_mult, "speed": speed_mult}

func spawn_level_combat() -> void:
	level_in_progress = true
	level_cleared = false
	alive_count = 0
	GameState.record_level_reached(current_level)
	if is_boss_level(current_level):
		spawn_boss()
		show_notification("Level " + str(current_level) + " - BOSS INCOMING")
	else:
		var count = min(BASE_ENEMY_COUNT + current_level - 1, MAX_ENEMY_COUNT)
		for i in range(count):
			spawn_enemy()
		show_notification("Level " + str(current_level))
	update_level_label()

func spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var scaling = get_level_scaling()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	enemy.position = Vector2(randf_range(600.0, DUNGEON_WIDTH - 200.0), GROUND_Y - 60.0)
	enemy.add_to_group("dungeon_combatant")
	$LevelContainer.add_child(enemy)
	enemy.died.connect(_on_combatant_died)
	alive_count += 1

func spawn_boss() -> void:
	var boss = BOSS_SCENE.instantiate()
	var scaling = get_level_scaling()
	boss.max_health = int(round(boss.MAX_HEALTH * scaling.hp))
	boss.damage_multiplier = scaling.dmg
	boss.speed_multiplier = scaling.speed
	boss.position = Vector2(DUNGEON_WIDTH - 400.0, GROUND_Y - 60.0)
	boss.add_to_group("dungeon_combatant")
	$LevelContainer.add_child(boss)
	boss.died.connect(_on_combatant_died)
	alive_count += 1

# Which skill-tree material this dungeon depth drops -- deeper brackets
# drop rarer materials (matching the escalating tier costs in skill_tree.gd).
func get_material_for_level(level: int) -> String:
	if level <= 5:
		return "slime"
	if level <= 10:
		return "iron_shard"
	if level <= 20:
		return "ember_crystal"
	if level <= 40:
		return "void_essence"
	return "ancient_relic"

const MATERIAL_DROP_CHANCE = 0.25

func roll_material_drop(guaranteed: bool = false) -> void:
	if not guaranteed and randf() > MATERIAL_DROP_CHANCE:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var mat_id = get_material_for_level(current_level)
	player.inventory.add_item(mat_id, 1)
	show_notification("Found: " + Inventory.get_display_name(mat_id))

func _on_combatant_died() -> void:
	# bosses always drop a material; regular enemies drop rarely
	roll_material_drop(is_boss_level(current_level))
	alive_count -= 1
	if alive_count <= 0 and level_in_progress:
		level_in_progress = false
		level_cleared = true
		GameState.highest_unlocked_level = max(GameState.highest_unlocked_level, current_level + 1)
		show_notification("Level " + str(current_level) + " cleared! The far gate is open.")

func exit_dungeon() -> void:
	starting = false
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.in_dungeon = false
	GameState.returning_from_dungeon = true
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func update_level_label() -> void:
	var label = get_node_or_null("CanvasLayer/LevelLabel")
	if label:
		label.text = "Level: " + str(current_level) + " / " + str(MAX_LEVEL) + "  (Unlocked: " + str(GameState.highest_unlocked_level) + ")"
		label.visible = true

func show_notification(text: String) -> void:
	var stack = get_node_or_null("CanvasLayer/NotificationStack")
	if stack:
		stack.show_notification(text)
