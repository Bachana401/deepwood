extends CharacterBody2D

# A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between
# sieges, stationable by the player with E, and MORTAL: when one dies it is
# gone for the whole playthrough -- GameState.kill_adventurer marks the roster
# and nothing ever respawns it.
#
#   wall  -- plants near the village wall, the first thing a raider meets
#   city  -- patrols the village proper, a second line
#   house -- shelters indoors: no combat, no targeting, CANNOT die
#
# Raiders find fighting adventurers through the "village_defender" group
# (siege_enemy.DEFENDER_GROUPS); a housed adventurer leaves that group, so the
# horde has no claim on it. Visuals are procedural (art freeze).

const GRAVITY = 900.0
const WALK_SPEED = 74.0
const ATTACK_RANGE = 56.0
const BOW_RANGE = 420.0
const ATTACK_COOLDOWN = 1.0
const SEEK_RANGE = 760.0
const ARROW_SCENE = preload("res://arrow.tscn")

var adventurer_id := ""
var def: Dictionary = {}
var station := "city"
var home_x := 0.0            # the anchor this station patrols around
var patrol_off := 0.0
var patrol_dir := 1.0
var attack_cd := 0.0
var is_dead := false
var player_near := false

var body_rect: ColorRect = null
var weapon_rect: ColorRect = null
var name_label: Label = null
var prompt: Label = null

const WEAPON_COLORS = {
	"blade": Color(0.82, 0.84, 0.9),
	"bow": Color(0.45, 0.3, 0.14),
	"spear": Color(0.6, 0.45, 0.25),
}

func _ready() -> void:
	def = Adventurers.get_def(adventurer_id)
	var st = GameState.adventurer_state(adventurer_id)
	station = str(st.get("station", "city"))
	collision_mask = 1
	collision_layer = 0
	add_to_group("adventurer")
	_apply_station_groups()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 44)
	cs.shape = rect
	cs.position = Vector2(0, -22)
	add_child(cs)
	_build_visual()
	# player proximity for the E prompt
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(110, 90)
	acs.shape = arect
	acs.position = Vector2(0, -30)
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player"): player_near = true; _refresh_prompt())
	area.body_exited.connect(func(b): if b.is_in_group("player"): player_near = false; _refresh_prompt())

func _build_visual() -> void:
	body_rect = ColorRect.new()
	body_rect.size = Vector2(20, 40)
	body_rect.position = Vector2(-10, -42)
	body_rect.color = Color(0.32, 0.36, 0.46)   # travel-worn blues, not villager browns
	body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_rect)
	weapon_rect = ColorRect.new()
	weapon_rect.size = Vector2(4, 30)
	weapon_rect.position = Vector2(10, -40)
	weapon_rect.color = WEAPON_COLORS.get(str(def.get("weapon", "blade")), Color.WHITE)
	weapon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_rect)
	name_label = Label.new()
	name_label.text = str(def.get("name", "Adventurer"))
	name_label.position = Vector2(-60, -66)
	name_label.size = Vector2(120, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	prompt = Label.new()
	prompt.position = Vector2(-90, -84)
	prompt.size = Vector2(180, 16)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.visible = false
	add_child(prompt)

func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.visible = player_near
	prompt.text = "[E] Station: %s" % station.to_upper()

# Housed adventurers are untouchable and untargetable; fighting ones are
# village defenders the horde will come for.
func _apply_station_groups() -> void:
	if station == "house":
		if is_in_group("village_defender"):
			remove_from_group("village_defender")
	else:
		if not is_in_group("village_defender"):
			add_to_group("village_defender")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cd > 0.0:
		attack_cd -= delta
	if player_near and Input.is_action_just_pressed("interact"):
		_cycle_station()
	var target: Node2D = null
	if station != "house":
		target = _nearest_raider()
	if target != null:
		_fight(target)
	else:
		_hold_station(delta)
	move_and_slide()

func _cycle_station() -> void:
	var idx = Adventurers.STATIONS.find(station)
	station = Adventurers.STATIONS[(idx + 1) % Adventurers.STATIONS.size()]
	GameState.set_adventurer_station(adventurer_id, station)
	_apply_station_groups()
	home_x = _station_anchor_x()
	_refresh_prompt()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		var how: String = {"wall": "holds the wall", "city": "patrols the village", "house": "shelters indoors (safe)"}[station]
		stack.show_notification("%s now %s." % [def.get("name", "The adventurer"), how])

func _station_anchor_x() -> float:
	match station:
		"wall":
			var wall = get_tree().get_first_node_in_group("village_wall")
			return (wall.global_position.x - 160.0) if wall else global_position.x
		"house":
			return 1050.0        # by the cottages
		_:
			return 2200.0        # the village heart

func _hold_station(delta: float) -> void:
	if home_x == 0.0:
		home_x = _station_anchor_x()
	# a housed adventurer stands still at the door; the rest pace their post
	if station == "city":
		patrol_off += patrol_dir * 24.0 * delta
		if absf(patrol_off) > 140.0:
			patrol_dir *= -1.0
	var dest := home_x + (patrol_off if station == "city" else 0.0)
	var dx := dest - global_position.x
	velocity.x = clampf(dx, -WALK_SPEED, WALK_SPEED) if absf(dx) > 6.0 else 0.0
	if body_rect and absf(velocity.x) > 1.0:
		body_rect.scale.x = 1.0 if velocity.x >= 0.0 else -1.0

func _nearest_raider() -> Node2D:
	var best: Node2D = null
	var best_d := SEEK_RANGE
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		var d: float = global_position.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best

func _fight(target: Node2D) -> void:
	var dist := global_position.distance_to(target.global_position)
	var is_bow := str(def.get("weapon", "blade")) == "bow"
	var reach := BOW_RANGE if is_bow else ATTACK_RANGE
	if dist > reach:
		velocity.x = signf(target.global_position.x - global_position.x) * WALK_SPEED * 1.35
		return
	velocity.x = 0.0
	if attack_cd > 0.0:
		return
	attack_cd = ATTACK_COOLDOWN * (1.4 if is_bow else 1.0)
	if is_bow:
		var arrow = ARROW_SCENE.instantiate()
		var dir = (target.global_position + Vector2(0, -14) - global_position).normalized()
		arrow.position = global_position + Vector2(0, -30) + dir * 16.0
		arrow.setup(dir, int(def.get("dmg", 12)), 20.0, 40.0, 4)
		get_parent().add_child(arrow)
	elif target.has_method("take_damage"):
		target.take_damage(int(def.get("dmg", 12)))
		if weapon_rect:
			var t = create_tween()
			t.tween_property(weapon_rect, "rotation_degrees", 70.0 * body_rect.scale.x, 0.08)
			t.tween_property(weapon_rect, "rotation_degrees", 0.0, 0.1)

func take_damage(amount: int) -> void:
	if is_dead or station == "house":
		return
	var st = GameState.adventurer_state(adventurer_id)
	var hp := float(st.get("hp", 100.0)) - float(amount)
	GameState.adventurers[adventurer_id]["hp"] = hp
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -40), amount)
	if body_rect:
		body_rect.color = Color(0.8, 0.3, 0.3)
		var t = create_tween()
		t.tween_property(body_rect, "color", Color(0.32, 0.36, 0.46), 0.25)
	if hp <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.kill_adventurer(adventurer_id)
	if is_in_group("village_defender"):
		remove_from_group("village_defender")
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)

func apply_knockback(direction_sign: int, distance: float) -> void:
	velocity.x += float(direction_sign) * distance * 2.0
