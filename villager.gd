extends Area2D

# Unique per-instance id so an already-rescued villager doesn't reappear (and
# get double-counted) when a save is continued -- see GameState.is_villager_rescued().
@export var villager_id: String = "villager_1"
@export var villager_name: String = "Elin"
@export var stat_name: String = "Farm"
@export var stat_value: int = 3
# Which building/role this villager is assigned to on rescue -- role_key is
# the building (e.g. "Farm"), role_title is their specific title there (e.g.
# "Farmer"). Two fields since some titles like "Leader" are shared across
# several buildings -- see building_roles.gd. Currently only role_key=="Farm"
# does anything (passive income, see GameState.generate_passive_income()).
@export var role_key: String = "Farm"
@export var role_title: String = "Farmer"
# Villagers are humans and have a sex ("Male"/"Female") -- used for pairing
# in mating houses (see house.gd). Enemies deliberately do NOT have this
# field; it's specific to villagers. Rescued villagers are always adults --
# only children born in mating houses start as kids.
@export var sex: String = "Female"
# One line of who they are / what happened to them, shown as a second
# notification right after the rescue confirmation. Kept vague about the
# enemy itself (still undecided) -- just the aftermath.
@export_multiline var backstory: String = "Rescued from the raid -- they'll need time to recover."

const PULSE_MIN_ALPHA = 0.55
const PULSE_MAX_ALPHA = 0.85
const RESCUE_FADE_DURATION = 0.6

const NPC_SCRIPT = preload("res://npc.gd")
# Matches main.gd's VILLAGE_START_X/VILLAGE_Y -- used as a fallback spawn spot
# for a rescued villager's world avatar when they aren't pre-assigned to a
# specific building (role_key == "").
const VILLAGE_FALLBACK_POS = Vector2(4900.0, -100.0)

var player_inside = false
var is_rescued = false

func _ready() -> void:
	if GameState.is_villager_rescued(villager_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$PromptLabel.text = "Press E to Rescue " + villager_name
	start_pulse()

func start_pulse() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property($Body, "modulate:a", PULSE_MIN_ALPHA, 1.4)
	tween.tween_property($Body, "modulate:a", PULSE_MAX_ALPHA, 1.4)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_rescued:
		player_inside = true
		$PromptLabel.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$PromptLabel.visible = false

func _process(_delta: float) -> void:
	if player_inside and not is_rescued and Input.is_action_just_pressed("interact"):
		rescue()

func rescue() -> void:
	is_rescued = true
	$PromptLabel.visible = false
	GameState.rescue_villager({
		"id": villager_id,
		"name": villager_name,
		"sex": sex,
		"is_kid": false,
		"stat_name": stat_name,
		"stat_value": stat_value,
		"role_key": role_key,
		"role_title": role_title,
		"paired": false,
	})
	spawn_world_avatar()
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification(backstory)
		notif.show_notification("Rescued " + villager_name + "! (" + stat_name + " +" + str(stat_value) + ")")
	monitoring = false
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Body, "modulate:a", 0.0, RESCUE_FADE_DURATION)
	tween.tween_property($Restraint, "modulate:a", 0.0, RESCUE_FADE_DURATION)
	tween.tween_property(self, "position:y", position.y - 20.0, RESCUE_FADE_DURATION)
	tween.chain().tween_callback(queue_free)

# Every rescued villager gets a real walking presence in the village, same as
# a child born from mating -- stats are never shown until this point (the
# pre-rescue hostage box has no hover/stat display at all), so nothing about
# them is visible early; this just stops them vanishing into pure data the
# instant they're freed.
func spawn_world_avatar() -> void:
	var village = get_node_or_null("../Village")
	if not village:
		return
	var npc = NPC_SCRIPT.new()
	npc.villager_id = villager_id
	npc.global_position = find_avatar_spawn_position(village)
	village.add_child(npc)

func find_avatar_spawn_position(village: Node) -> Vector2:
	if role_key != "":
		for child in village.get_children():
			if child.has_method("get_roles") and child.role_key == role_key:
				return child.global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	return VILLAGE_FALLBACK_POS
