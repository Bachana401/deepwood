extends Area2D

@export var house_id: String = "house_1"
@export var house_name: String = "Cottage"
@export var width: float = 70.0
@export var height: float = 55.0
@export var body_color: Color = Color(0.65, 0.5, 0.35, 1.0)
@export var roof_color: Color = Color(0.5, 0.25, 0.2, 1.0)

const NPC_SCRIPT = preload("res://npc.gd")

var player_inside = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("village_structure")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.couple_departed.connect(_on_couple_departed)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width, height + 40.0)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)

	build_visual()

	var label = Label.new()
	label.text = house_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-width / 2.0, -height - 30.0)
	label.size = Vector2(width, 18.0)
	add_child(label)

	var prompt = Label.new()
	prompt.name = "PromptLabel"
	prompt.visible = false
	prompt.text = "Press E"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.position = Vector2(-width / 2.0, -height - 12.0)
	prompt.size = Vector2(width, 16.0)
	add_child(prompt)

func build_visual() -> void:
	# PixelLab cottage facade replaces the flat polygon look when present
	# (fits the footprint, base on the ground line); fallback stays procedural.
	if ResourceLoader.exists("res://art/buildings/house.png"):
		var tex: Texture2D = load("res://art/buildings/house.png")
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var content := Rect2(img.get_used_rect())   # skip transparent padding
		if content.size.x <= 0:
			content = Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.region_enabled = true
		spr.region_rect = content
		var s := (height + 22.0) * 1.3 / content.size.y   # 30% bigger, roof-peak room
		spr.scale = Vector2(s, s)
		spr.position = Vector2(-content.size.x * s / 2.0, -content.size.y * s)
		add_child(spr)
		var lights := BuildingLights.new()
		add_child(lights)
		lights.build(tex, content, spr.position, spr.scale)
		return
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-width / 2.0, 0), Vector2(width / 2.0, 0),
		Vector2(width / 2.0, -height), Vector2(-width / 2.0, -height),
	])
	body.color = body_color
	add_child(body)

	var roof = Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-width / 2.0 - 6.0, -height), Vector2(width / 2.0 + 6.0, -height), Vector2(0, -height - 22.0),
	])
	roof.color = roof_color
	add_child(roof)

	var chimney = ColorRect.new()
	chimney.size = Vector2(7.0, 16.0)
	chimney.position = Vector2(width * 0.2, -height - 20.0)
	chimney.color = roof_color.darkened(0.3)
	add_child(chimney)

	var door_width = width * 0.28
	var door = ColorRect.new()
	door.size = Vector2(door_width, height * 0.55)
	door.position = Vector2(-door_width / 2.0, -height * 0.55)
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

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		interact()

func interact() -> void:
	# houses are children of Main/Village, not Main directly -- CanvasLayer
	# is a sibling of Village, so it takes two levels up to reach it.
	var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
	# 5.8: an occupied home is occupied for LIFE -- only death frees it
	if GameState.cottage_homes.has(house_id):
		var home: Dictionary = GameState.cottage_homes[house_id]
		if notif:
			notif.show_notification("%s — %s and %s live here." % [house_name,
				GameState.villager_name(str(home.get("a", ""))),
				GameState.villager_name(str(home.get("b", "")))])
		return
	if GameState.mating_houses.has(house_id):
		var pairing = GameState.mating_houses[house_id]
		var remaining_ingame_minutes = int(ceil(max(pairing.remaining_hours, 0.0) * 60.0))
		if notif:
			notif.show_notification(house_name + " -- occupied, leaving in " + str(remaining_ingame_minutes) + " in-game minutes.")
		return
	var parents = GameState.find_available_parents()
	if parents.male_id == "" or parents.female_id == "":
		if notif:
			notif.show_notification(house_name + " -- needs one unpaired Male and one unpaired Female rescued villager.")
		return
	GameState.start_pairing(house_id, parents.male_id, parents.female_id)
	if notif:
		notif.show_notification(house_name + " -- villagers paired! They'll head out in an hour.")

func _on_couple_departed(departing_house_id: String, male_id: String, female_id: String) -> void:
	if departing_house_id != house_id:
		return
	spawn_departing_npc(male_id)
	spawn_departing_npc(female_id)
	var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("The pair has left " + house_name + " to wander the village.")

func spawn_departing_npc(villager_id: String) -> void:
	var npc = NPC_SCRIPT.new()
	npc.villager_id = villager_id
	# NOBODY POPS INTO EXISTENCE IN FRONT OF YOU (main.gd rule): the departing pair
	# walk in from off-screen instead of materialising beside the player.
	var spot: Vector2 = global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	var scn = get_tree().current_scene
	if scn and scn.has_method("offscreen_spawn"):
		spot = scn.offscreen_spawn(spot)
	npc.global_position = spot
	get_parent().add_child(npc)
