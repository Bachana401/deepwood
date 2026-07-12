extends Area2D

# Unique per-instance id, used as the key into GameState.chest_contents so
# each chest's items persist independently across saves.
@export var chest_id: String = "chest_1"
@export var capacity: int = 24

var inventory: Inventory
var player_inside = false

func _ready() -> void:
	inventory = Inventory.new(capacity)
	if GameState.chest_contents.has(chest_id):
		inventory.from_save_data(GameState.chest_contents[chest_id])
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		$PromptLabel.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$PromptLabel.visible = false
		var chest_ui = get_node_or_null("../ChestUI")
		if chest_ui and chest_ui.current_chest == self:
			chest_ui.close()

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		open_ui()

func open_ui() -> void:
	$PromptLabel.visible = false
	var chest_ui = get_node_or_null("../ChestUI")
	if chest_ui:
		chest_ui.open_chest(self)

func save_contents() -> void:
	GameState.chest_contents[chest_id] = inventory.to_save_data()
