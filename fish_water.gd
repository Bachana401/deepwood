extends Node2D
# FISHING (pillar 3): a stretch of fishable water. The Dock's pond needs no
# node of its own -- the Fishing Dock BUILDING self-registers (building.gd)
# because it already knows its water's exact span. This node is for every
# OTHER water in the world: the underdark's calm pools, and whatever the
# game floods next. Anything in the "fish_water" group answering
# fish_kind() / fish_half_width() / fish_surface_y() takes a cast line
# (player.gd), and the kind picks the table in fishing.gd.

var kind := "cave"
var half_width := 120.0

func _ready() -> void:
	add_to_group("fish_water")

func fish_kind() -> String:
	return kind

func fish_half_width() -> float:
	return half_width

func fish_surface_y() -> float:
	return global_position.y
