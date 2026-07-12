extends Node

# Presents LIVE sieges while the player is in the village. Scheduling and
# off-screen (player-away) resolution now live in GameState so the clock and
# assaults keep advancing in every scene -- this node just stages the physical
# battle when GameState says one is due here: it spawns the attacker wave,
# tracks it, and on a full repel repairs the wall + tells GameState the live
# battle is over.

const SIEGE_ENEMY_SCENE = preload("res://siege_enemy.tscn")

const BASE_COUNT = 3
const MAX_COUNT = 12
const BASE_HP = 50.0
const BASE_DMG = 10.0
const HP_PER_TIER = 0.30
const DMG_PER_TIER = 0.20

const SPAWN_Y = -70.0
const DEFAULT_WALL_X = 4700.0
const SPAWN_STANDOFF = 360.0

var alive_count = 0
var siege_number = 0
var label: Label = null

func _ready() -> void:
	add_to_group("siege_manager")
	build_label()

func _process(_delta: float) -> void:
	update_label()

# Called by GameState.trigger_siege() when a scheduled siege lands while the
# player is here in the village.
func start_live_siege(tier: int) -> void:
	siege_number += 1
	var count = min(BASE_COUNT + tier, MAX_COUNT)
	var hp = int(round(BASE_HP * (1.0 + (tier - 1) * HP_PER_TIER)))
	var dmg = int(round(BASE_DMG * (1.0 + (tier - 1) * DMG_PER_TIER)))

	var wall = get_tree().get_first_node_in_group("village_wall")
	var face_x = wall.west_face_x() if wall else DEFAULT_WALL_X
	var base_x = face_x - SPAWN_STANDOFF

	alive_count = 0
	for i in range(count):
		var e = SIEGE_ENEMY_SCENE.instantiate()
		e.max_health = hp
		e.attack_damage = dmg
		e.reward = 5 + tier
		e.wall = wall
		e.global_position = Vector2(base_x - i * randf_range(34.0, 70.0), SPAWN_Y)
		e.died.connect(_on_enemy_died)
		get_parent().add_child(e)
		alive_count += 1

	notify("A siege begins! Wave %d -- %d attackers (tier %d)." % [siege_number, count, tier])

func _on_enemy_died() -> void:
	alive_count -= 1
	if alive_count <= 0 and GameState.live_siege_active:
		end_siege()

func end_siege() -> void:
	alive_count = 0
	var wall = get_tree().get_first_node_in_group("village_wall")
	if wall and wall.has_method("repair_fully"):
		wall.repair_fully()
	GameState.on_live_siege_ended()
	notify("Siege repelled! The walls are patched up.")

func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)

func build_label() -> void:
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	label = Label.new()
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -170.0
	label.offset_right = 170.0
	label.offset_top = 44.0
	label.offset_bottom = 66.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(label)

func update_label() -> void:
	if not label:
		return
	if GameState.live_siege_active:
		label.text = "⚔ SIEGE  -  %d attacker%s left" % [alive_count, "" if alive_count == 1 else "s"]
	else:
		label.text = "Next siege in %.0fh  (tier %d)" % [max(GameState.hours_until_next_siege, 0.0), GameState.current_siege_tier()]
