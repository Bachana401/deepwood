extends CharacterBody2D

# Points back at their entry in GameState.rescued_villagers -- info is
# always looked up fresh (name/age/sex/stat) rather than cached here, so it
# stays correct even after they graduate school/barracks or get reassigned.
var villager_id: String = ""

const GRAVITY = 900.0
const SPEED = 40.0
# Keeps unemployed NPCs wandering within the whole village, not drifting into
# the combat course or off the far end past the mating houses. Once assigned
# to a building, wander_min_x/max_x below narrow this down to just that
# building's neighborhood instead (see refresh_wander_bounds).
const WANDER_MIN_X = 4850.0
const WANDER_MAX_X = 8000.0
const MIN_WALK_SECONDS = 2.0
const MAX_WALK_SECONDS = 5.0
const MIN_IDLE_SECONDS = 1.5
const MAX_IDLE_SECONDS = 4.0

var direction = 0
var is_walking = false
var state_timer = 0.0
var player_inside = false
var wander_min_x = WANDER_MIN_X
var wander_max_x = WANDER_MAX_X

# Assigned villagers periodically clock in at their workplace: 0-5 times per
# 24 in-game hours, each visit lasting 30-60 in-game minutes, at random times
# re-rolled every cycle -- so some days they might not go in at all, other
# days up to 5 times. Ticks off the same in-game clock as mating/school (see
# GameState), so debug time-skip keys speed this up/rewind it correctly too.
const VISIT_MIN_HOURS = 0.5
const VISIT_MAX_HOURS = 1.0
const CYCLE_LENGTH_HOURS = 24.0
const MIN_VISITS_PER_CYCLE = 0
const MAX_VISITS_PER_CYCLE = 5
const BUILDING_WANDER_RADIUS = 70.0

var last_hours_elapsed = 0.0
var cycle_elapsed_hours = 0.0
var visit_times_this_cycle: Array = []
var is_in_building = false
var hours_until_exit = 0.0

# Small hover tooltip, attached above the NPC's head -- shown while the
# mouse is over them, no click needed (left-click already swings the
# player's weapon, so a click-to-inspect would double as an attack).
const HOVER_BOUNDS = Rect2(-20.0, -40.0, 40.0, 44.0)
var hover_panel: Panel = null
var hover_label: Label = null

# Kids are drawn/collide smaller than adults (see apply_size) -- graduating
# school/barracks flips is_kid to false well after spawn, so this tracks the
# last-applied value and re-sizes on change rather than only sizing once.
var body_rect: ColorRect = null
var collision_shape: CollisionShape2D = null
var last_applied_is_kid = true

# Health. The bar is normally hidden. On any hit it flashes into view for a
# moment (HIT_REVEAL_SECONDS) so the player notices the villager is under
# attack, then hides again. Once HP is at/below the danger threshold (30%) it
# stays visible AND pulses red -- a "about to die" warning. At 0 the villager
# dies for good (removed from roster + world, see die()). The player can't
# deal this damage (collision_layer 0); it's reserved for future siege enemies.
const MAX_HEALTH = 100
const HEALTH_BAR_DANGER_THRESHOLD = 0.30
const HEALTH_BAR_HIT_REVEAL_SECONDS = 1.6
const HEALTH_BAR_WIDTH = 30.0
const HEALTH_BAR_HEIGHT = 5.0
const HEALTH_BAR_Y = -48.0
const HEALTH_COLOR_OK = Color(0.15, 0.75, 0.25, 1.0)
const HEALTH_COLOR_DANGER = Color(0.9, 0.15, 0.15, 1.0)
var health = MAX_HEALTH
var hp_reveal_timer = 0.0
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

func _ready() -> void:
	add_to_group("npc")
	# layer 0 = NOT on any hittable layer, so the player's weapons/arrows can
	# never target villagers. Damage only ever arrives through the public
	# take_damage() below -- reserved for the future village-siege enemies.
	collision_layer = 0
	collision_mask = 1
	pick_new_state()
	build_visual()
	build_hover_panel()
	build_health_bar()
	refresh_wander_bounds()
	# NPCs can spawn well after in-game time has already been ticking (e.g. a
	# child born hours into a playthrough) -- start the local clock baseline
	# at the CURRENT reading, not 0, or the very first tick would see a huge
	# false "hours_passed" and immediately roll/skip a full cycle.
	last_hours_elapsed = GameState.game_hours
	roll_new_cycle()

	collision_shape = CollisionShape2D.new()
	collision_shape.shape = RectangleShape2D.new()
	add_child(collision_shape)
	apply_size()

	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_shape = CollisionShape2D.new()
	var area_rect = RectangleShape2D.new()
	area_rect.size = Vector2(60, 60)
	area_shape.shape = area_rect
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func build_visual() -> void:
	body_rect = ColorRect.new()
	body_rect.name = "Body"
	add_child(body_rect)

# Applies both the sprite size and the physical collision box for the
# villager's CURRENT is_kid/sex, and remembers is_kid so refresh_size_if_needed
# only does real work when it actually changes (e.g. on graduation).
func apply_size() -> void:
	var data = find_villager_data()
	var is_kid = data.get("is_kid", true)
	var sex = data.get("sex", "Female")
	last_applied_is_kid = is_kid
	var scale_factor = 0.65 if is_kid else 1.0
	var base_color = Color(0.55, 0.62, 0.72, 1) if sex == "Male" else Color(0.68, 0.58, 0.62, 1)

	var w = 20.0 * scale_factor
	var h = 32.0 * scale_factor
	if body_rect:
		body_rect.size = Vector2(w, h)
		body_rect.position = Vector2(-w / 2.0, -h)
		body_rect.color = base_color
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = Vector2(20.0 * scale_factor, 36.0 * scale_factor)

func refresh_size_if_needed() -> void:
	var data = find_villager_data()
	if data.get("is_kid", true) != last_applied_is_kid:
		apply_size()

func build_hover_panel() -> void:
	hover_panel = Panel.new()
	hover_panel.visible = false
	hover_panel.z_index = 100
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.position = Vector2(-72, -92)
	hover_panel.size = Vector2(144, 66)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.9)
	style.border_color = Color(0.65, 0.65, 0.7, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	hover_panel.add_theme_stylebox_override("panel", style)
	add_child(hover_panel)

	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.position = Vector2(8, 6)
	hover_label.size = Vector2(128, 54)
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_label.add_theme_font_size_override("font_size", 11)
	hover_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hover_panel.add_child(hover_label)

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_bg.z_index = 60
	health_bar_bg.visible = false
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.15, 0.75, 0.25, 1.0)
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_Y)
	health_bar_fill.z_index = 61
	health_bar_fill.visible = false
	add_child(health_bar_fill)

# Public entry point for anything that hurts a villager (reserved for the
# future village-siege enemies). Villagers sheltered inside a building are safe.
func take_damage(amount: int) -> void:
	if is_in_building:
		return
	health -= amount
	if health <= 0:
		die()
		return
	# flash the bar into view briefly so the player sees they're taking hits
	hp_reveal_timer = HEALTH_BAR_HIT_REVEAL_SECONDS
	update_health_bar_fill()

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / MAX_HEALTH, 0.0, 1.0)

# Called every frame. Bar is shown while a recent-hit reveal is counting down,
# or permanently (pulsing red) once HP is in the danger zone.
func update_health_bar_display(delta: float) -> void:
	if not health_bar_bg or not health_bar_fill:
		return
	if hp_reveal_timer > 0.0:
		hp_reveal_timer -= delta
	var in_danger = health > 0 and float(health) <= MAX_HEALTH * HEALTH_BAR_DANGER_THRESHOLD
	var show_bar = in_danger or hp_reveal_timer > 0.0
	health_bar_bg.visible = show_bar
	health_bar_fill.visible = show_bar
	if not show_bar:
		return
	if in_danger:
		health_bar_fill.color = HEALTH_COLOR_DANGER
		# pulse the whole bar's opacity as a danger warning
		var pulse = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0))
		health_bar_bg.modulate.a = pulse
		health_bar_fill.modulate.a = pulse
	else:
		health_bar_fill.color = HEALTH_COLOR_OK
		health_bar_bg.modulate.a = 1.0
		health_bar_fill.modulate.a = 1.0

func die() -> void:
	# permanent: gone from the roster (so no income/mating/etc. and doesn't
	# come back on reload) and gone from the world. remove_villager_by_id
	# despawns this avatar via the "npc" group; the guard covers a missing id.
	GameState.remove_villager_by_id(villager_id)
	if not is_queued_for_deletion():
		queue_free()

func _physics_process(delta: float) -> void:
	if is_in_building:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	state_timer -= delta
	if state_timer <= 0:
		pick_new_state()

	if is_walking:
		if global_position.x <= wander_min_x:
			direction = 1
		elif global_position.x >= wander_max_x:
			direction = -1
		velocity.x = direction * SPEED
	else:
		velocity.x = 0

	move_and_slide()

func pick_new_state() -> void:
	if is_walking:
		is_walking = false
		state_timer = randf_range(MIN_IDLE_SECONDS, MAX_IDLE_SECONDS)
	else:
		is_walking = true
		direction = -1 if randf() < 0.5 else 1
		state_timer = randf_range(MIN_WALK_SECONDS, MAX_WALK_SECONDS)

func find_villager_data() -> Dictionary:
	for v in GameState.rescued_villagers:
		if v.get("id") == villager_id:
			return v
	return {}

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _process(delta: float) -> void:
	refresh_size_if_needed()
	update_health_bar_display(delta)
	refresh_wander_bounds()
	tick_building_visits()
	if is_in_building:
		if hover_panel:
			hover_panel.visible = false
		return
	if player_inside and Input.is_action_just_pressed("interact"):
		show_info()
	update_hover_panel(get_global_mouse_position())

# Unassigned NPCs roam the whole village; once given a role_key, they're
# confined to a small neighborhood around that specific building instead
# ("only allowed to move in their designated building" -- they don't wander
# into/near other buildings once employed).
func refresh_wander_bounds() -> void:
	var role_key = find_villager_data().get("role_key", "")
	var building = get_building_for_role(role_key) if role_key != "" else null
	if building:
		wander_min_x = building.global_position.x - BUILDING_WANDER_RADIUS
		wander_max_x = building.global_position.x + BUILDING_WANDER_RADIUS
	else:
		wander_min_x = WANDER_MIN_X
		wander_max_x = WANDER_MAX_X

func get_building_for_role(role_key: String) -> Node:
	return get_tree().get_first_node_in_group("building_role_" + role_key)

func roll_new_cycle() -> void:
	var visit_count = randi_range(MIN_VISITS_PER_CYCLE, MAX_VISITS_PER_CYCLE)
	visit_times_this_cycle = []
	for i in range(visit_count):
		visit_times_this_cycle.append(randf_range(0.0, CYCLE_LENGTH_HOURS))
	visit_times_this_cycle.sort()

func tick_building_visits() -> void:
	var current_hours = GameState.game_hours
	var hours_passed = current_hours - last_hours_elapsed
	last_hours_elapsed = current_hours

	var role_key = find_villager_data().get("role_key", "")
	if role_key == "":
		if is_in_building:
			exit_building()
		return

	if is_in_building:
		hours_until_exit -= hours_passed
		if hours_until_exit <= 0:
			exit_building()
		return

	cycle_elapsed_hours += hours_passed
	if cycle_elapsed_hours >= CYCLE_LENGTH_HOURS:
		cycle_elapsed_hours = fmod(cycle_elapsed_hours, CYCLE_LENGTH_HOURS)
		roll_new_cycle()

	# a big time-skip can cross several scheduled visit times at once -- only
	# one visit can actually happen (can't be in two places at once), so
	# consume all of them but trigger a single visit.
	var visit_due = false
	while not visit_times_this_cycle.is_empty() and cycle_elapsed_hours >= visit_times_this_cycle[0]:
		visit_times_this_cycle.pop_front()
		visit_due = true
	if visit_due:
		enter_building(role_key)

func enter_building(role_key: String) -> void:
	var building = get_building_for_role(role_key)
	if not building:
		return
	is_in_building = true
	hours_until_exit = randf_range(VISIT_MIN_HOURS, VISIT_MAX_HOURS)
	visible = false
	velocity = Vector2.ZERO
	global_position = building.global_position + Vector2(0.0, -4.0)

func exit_building() -> void:
	is_in_building = false
	visible = true
	var role_key = find_villager_data().get("role_key", "")
	var building = get_building_for_role(role_key) if role_key != "" else null
	if building:
		global_position = building.global_position + Vector2(randf_range(-15.0, 15.0), -60.0)
	pick_new_state()

# Small info fields shared by both the Press-E notification (joined with
# " -- ") and the hover tooltip (joined with newlines) -- so both stay in
# sync automatically as villager data evolves (graduation, reassignment).
func info_fields() -> Array:
	var data = find_villager_data()
	if data.is_empty():
		return []
	var age_text = "Kid" if data.get("is_kid", false) else "Adult"
	var stat_text = data.get("stat_name", "") if data.get("stat_name", "") != "" else "no stat yet"
	var fields = [data.get("name", "?"), age_text + ", " + data.get("sex", "?"), stat_text]
	if data.get("role_title", "") != "":
		fields.append("Works: " + data.get("role_title"))
	return fields

func show_info() -> void:
	var fields = info_fields()
	if fields.is_empty():
		return
	# the NPC introducing themselves is speech -- floating text above their
	# head that follows them as they wander, not a corner notification
	SpeechText.spawn(self, " -- ".join(fields))

# Takes an explicit world position (rather than always reading the live
# mouse cursor) so this can be exercised directly in headless tests, where
# there is no real viewport/cursor to move.
func is_hovering(mouse_world_pos: Vector2) -> bool:
	return HOVER_BOUNDS.has_point(mouse_world_pos - global_position)

func update_hover_panel(mouse_world_pos: Vector2) -> void:
	if not hover_panel:
		return
	if is_hovering(mouse_world_pos):
		var fields = info_fields()
		if fields.is_empty():
			hover_panel.visible = false
			return
		hover_label.text = "\n".join(fields)
		hover_panel.visible = true
	else:
		hover_panel.visible = false
