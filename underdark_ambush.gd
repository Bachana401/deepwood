extends Area2D
# A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits).
# Dormant until the player DROPS IN, then a pack of the deep's own mobs boils out
# around them. The cache at the bottom is the bait and the prize -- you fight to
# keep what you came for. One-shot: once sprung it stays quiet (the mobs it made
# don't respawn), so a cleared chamber is a cleared chamber for this visit.
var band := 0
var host: Node = null
var sprung := false

func _ready() -> void:
	collision_mask = 2          # the player's body layer
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(360.0, 240.0)
	cs.shape = r
	add_child(cs)
	body_entered.connect(_on_enter)

func _on_enter(b: Node2D) -> void:
	if sprung or b == null or not b.is_in_group("player"):
		return
	sprung = true
	if host != null and is_instance_valid(host) and host.has_method("spring_ambush"):
		host.spring_ambush(global_position, band)
