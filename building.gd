extends Area2D

@export var building_name: String = "Building"
# Matches a villager's "role_key" field (see villager.gd / game_state.gd) --
# whichever villagers have this role_key work at this building. The specific
# roles available (titles, slot counts, stat requirements) come from
# BuildingRoles.get_roles(role_key) -- see building_roles.gd. Only Farm
# actually does anything mechanically yet (passive income); the rest are
# real, slot-limited, stat-gated assignments, just without a functional
# payoff of their own so far.
@export var role_key: String = ""
@export var width: float = 100.0
@export var height: float = 80.0
@export var body_color: Color = Color(0.5, 0.4, 0.3, 1.0)

const NPC_SCRIPT = preload("res://npc.gd")

var player_inside = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if role_key == "Hospital":
		GameState.child_produced.connect(_on_child_produced)
	# lets npc.gd look up "the building whichever villager works at" by role_key
	# without needing a scene-tree reference of its own -- see npc.gd's
	# building-visit system.
	if role_key != "":
		add_to_group("building_role_" + role_key)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width, height + 40.0)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)

	build_visual()

	var label = Label.new()
	label.text = building_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-width / 2.0, -height - 34.0)
	label.size = Vector2(width, 20.0)
	add_child(label)

	var prompt = Label.new()
	prompt.name = "PromptLabel"
	prompt.visible = false
	prompt.text = "Press E"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-width / 2.0, -height - 14.0)
	prompt.size = Vector2(width, 18.0)
	add_child(prompt)

func build_visual() -> void:
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-width / 2.0, 0), Vector2(width / 2.0, 0),
		Vector2(width / 2.0, -height), Vector2(-width / 2.0, -height),
	])
	body.color = body_color
	add_child(body)

	var roof = Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-width / 2.0 - 8.0, -height), Vector2(width / 2.0 + 8.0, -height), Vector2(0, -height - 26.0),
	])
	roof.color = body_color.darkened(0.35)
	add_child(roof)

	var door_width = width * 0.22
	var door = ColorRect.new()
	door.size = Vector2(door_width, height * 0.5)
	door.position = Vector2(-door_width / 2.0, -height * 0.5)
	door.color = body_color.darkened(0.5)
	add_child(door)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		$PromptLabel.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$PromptLabel.visible = false
		# buildings are children of Main/Village, not Main directly -- AssignUI
		# is a sibling of Village, so it takes two levels up to reach it.
		var assign_ui = get_node_or_null("../../AssignUI")
		if assign_ui and assign_ui.current_building == self:
			assign_ui.close()

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		open_assign_ui()

func get_roles() -> Array:
	return BuildingRoles.get_roles(role_key)

func get_role_holders(role_title: String) -> Array:
	var holders = []
	for villager in GameState.rescued_villagers:
		if villager.get("role_key") == role_key and villager.get("role_title") == role_title:
			holders.append(villager)
	return holders

func is_role_full(role_def: Dictionary) -> bool:
	return get_role_holders(role_def.title).size() >= role_def.slots

# A villager qualifies for a role if: not already working/enrolled anywhere
# else, meets the stat/sex/age requirements (empty requirement = anyone
# qualifies on that axis), and the role has an open slot.
func get_eligible_villagers(role_def: Dictionary) -> Array:
	if is_role_full(role_def):
		return []
	var eligible = []
	for villager in GameState.rescued_villagers:
		if villager.get("role_key", "") != "" or GameState.school_enrollments.has(villager.get("id")):
			continue
		if role_def.get("required_stat", "") != "" and villager.get("stat_name", "") != role_def.required_stat:
			continue
		if role_def.get("requires_sex", "") != "" and villager.get("sex", "") != role_def.requires_sex:
			continue
		if role_def.get("requires_kid", false) and not villager.get("is_kid", false):
			continue
		if not role_def.get("requires_kid", false) and not role_def.get("is_enrollment", false) and villager.get("is_kid", false):
			continue
		eligible.append(villager)
	return eligible

func open_assign_ui() -> void:
	# buildings are children of Main/Village, not Main directly -- AssignUI
	# is a sibling of Village, so it takes two levels up to reach it.
	var assign_ui = get_node_or_null("../../AssignUI")
	if assign_ui:
		assign_ui.open_for_building(self)

# Only connected for the Hospital instance (see _ready) -- every pregnancy,
# regardless of which cottage it started in, ends here.
func _on_child_produced(child_id: String) -> void:
	var npc = NPC_SCRIPT.new()
	npc.villager_id = child_id
	npc.global_position = global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	get_parent().add_child(npc)
	var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("A new villager has been born at " + building_name + "!")
