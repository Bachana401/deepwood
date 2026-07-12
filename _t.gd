extends Node2D
func _ready():
	var m=load("res://main.tscn").instantiate(); add_child(m)
	for i in range(6): await get_tree().process_frame
	# simulate a PRE-refactor save being loaded via Continue
	var old = {"inventory":[{"item_id":"coin_gold","count":50}], "owned_weapons":{"sword":true,"bow":true}, "equipped_weapon":"bow", "has_dash":true, "has_double_jump":false, "health":90, "position_x":4900.0, "position_y":-100.0}
	m.apply_save_data(old)
	for i in range(4): await get_tree().process_frame
	var p=get_tree().get_first_node_in_group("player")
	print("CONTINUE ok, wielding=", p.active_weapon_id, " health=", p.health)
	print("DONE")
	get_tree().quit()
