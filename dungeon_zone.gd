extends Area2D

var player_inside = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		if not $"../DungeonManager".started and not $"../DungeonManager".starting:
			$PromptLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$PromptLabel.visible = false
		$"../LevelSelectUI".close()

func _process(_delta: float) -> void:
	if player_inside and not $"../DungeonManager".started and not $"../DungeonManager".starting and Input.is_action_just_pressed("enter_dungeon"):
		$PromptLabel.visible = false
		$"../LevelSelectUI".open()
