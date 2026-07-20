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

# Barracks soldiers: visible defenders that sally out to meet the raiders. Count
# = trained warriors, capped. They're a bit tankier/harder-hitting than raiders.
const MAX_SOLDIERS = 6
const SOLDIER_BASE_HP = 62.0
const SOLDIER_BASE_DMG = 12.0
const SOLDIER_SALLY_OFFSET = 130.0   # spawn just outside the wall (west), then charge on

var alive_count = 0
var siege_number = 0
var soldiers: Array = []
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
		e.skin = "raider"          # PixelLab goblin marauder art
		e.max_health = hp
		e.attack_damage = dmg
		e.reward = 5 + tier
		e.wall = wall
		e.global_position = Vector2(base_x - i * randf_range(34.0, 70.0), SPAWN_Y)
		e.died.connect(_on_enemy_died)
		get_parent().add_child(e)
		alive_count += 1

	notify("A siege begins! Wave %d -- %d attackers (tier %d)." % [siege_number, count, tier])
	_spawn_barracks_soldiers(tier, face_x, wall)

# The Barracks answers the horn: trained warriors sally out (just west of the
# wall) as visible Soldier units and charge the raiders. Reuses the siege_enemy
# body with faction "village" + the soldier sprite skin.
func _spawn_barracks_soldiers(tier: int, face_x: float, wall) -> void:
	soldiers.clear()
	# Barracks-forged HEROES sally first: one unit each, on top of the soldier
	# cap, at triple a soldier's strength -- the 0.5% birth paying off in force.
	# Each hero marches under their OWN name and power (rolled at graduation) --
	# a 0.5% miracle never fights like a big generic soldier.
	var hero_villagers := []
	for v in GameState.rescued_villagers:
		if v.get("hero_trained", false):
			hero_villagers.append(v)
	var hero_hp = int(round(SOLDIER_BASE_HP * 3.0 * (1.0 + (tier - 1) * HP_PER_TIER)))
	var hero_dmg = int(round(SOLDIER_BASE_DMG * 3.0 * (1.0 + (tier - 1) * DMG_PER_TIER)))
	var rally_present := false
	for i in range(hero_villagers.size()):
		var hv: Dictionary = hero_villagers[i]
		var h = SIEGE_ENEMY_SCENE.instantiate()
		h.faction = "village"
		h.skin = "soldier"
		h.max_health = hero_hp
		h.attack_damage = hero_dmg
		h.hero_power = str(hv.get("hero_power", "warcry"))
		h.hero_name = str(hv.get("name", "Hero"))
		if h.hero_power == "rally":
			rally_present = true
		h.wall = wall
		h.facing = -1
		h.global_position = Vector2(face_x - SOLDIER_SALLY_OFFSET - 40.0 - i * 46.0, SPAWN_Y)
		h.died.connect(_on_soldier_died.bind(h))
		get_parent().add_child(h)
		h.scale = Vector2(1.25, 1.25)   # a hero reads bigger on the field
		soldiers.append(h)
	if not hero_villagers.is_empty():
		notify("★ %d HERO%s take%s the field!" % [hero_villagers.size(), "" if hero_villagers.size() == 1 else "ES", "s" if hero_villagers.size() == 1 else ""])
	var n = min(GameState.warrior_count(), MAX_SOLDIERS)
	if n <= 0:
		return
	var hp = int(round(SOLDIER_BASE_HP * (1.0 + (tier - 1) * HP_PER_TIER)))
	# Rally: a hero of the banner on the field hardens every soldier who
	# marches beside them
	if rally_present:
		hp = int(round(hp * 1.5))
	var dmg = int(round(SOLDIER_BASE_DMG * (1.0 + (tier - 1) * DMG_PER_TIER)))
	for i in range(n):
		var s = SIEGE_ENEMY_SCENE.instantiate()
		s.faction = "village"
		s.skin = "soldier"
		s.max_health = hp
		s.attack_damage = dmg
		s.wall = wall
		s.facing = -1
		s.global_position = Vector2(face_x - SOLDIER_SALLY_OFFSET - i * randf_range(30.0, 55.0), SPAWN_Y)
		s.died.connect(_on_soldier_died.bind(s))
		get_parent().add_child(s)
		soldiers.append(s)
	notify("%d soldier%s march out from the Barracks!" % [n, "" if n == 1 else "s"])

func _on_soldier_died(s) -> void:
	soldiers.erase(s)

func _on_enemy_died() -> void:
	alive_count -= 1
	if alive_count <= 0 and GameState.live_siege_active:
		end_siege()

func end_siege() -> void:
	alive_count = 0
	var wall = get_tree().get_first_node_in_group("village_wall")
	if wall and wall.has_method("repair_fully"):
		wall.repair_fully()
	# surviving soldiers march back to the Barracks
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	soldiers.clear()
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
	if GameState.despair_dead:
		label.text = "☾ The nights are quiet — Despair is dead. Deepwood is yours."
	elif GameState.live_siege_active:
		label.text = "⚔ SIEGE  -  %d attacker%s left" % [alive_count, "" if alive_count == 1 else "s"]
	else:
		label.text = "Next siege in %.0fh  (tier %d)" % [max(GameState.hours_until_next_siege, 0.0), GameState.current_siege_tier()]
