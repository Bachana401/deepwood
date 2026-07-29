extends Node
# Show the 14 new armor icons IN THE GAME: fill the bag, open the inventory +
# gear panels, and shoot the real UI (rarity frames, ghost slots, set lines) --
# not the raw PNGs. A second shot wears the Regalia set so the equipped look
# and its set-bonus block read too.
#   MONARCH_TEST="res://tool_eyes_armor.gd" Godot.exe --path .   (windowed)
var shot_dir := "user://eyes"
func say(t: String) -> void: printerr("ARMOR: " + t); OS.delay_msec(1)

# the 14 pieces from part 2, in a sensible reading order
const NEW_ARMOR := [
	"helm_regal", "armor_regal", "pants_regal",       # Regalia (the king set)
	"armor_void", "pants_void",                        # Voidwalker
	"armor_ember", "helm_mourn", "armor_unmade",       # standalones
	"gloves_iron", "gloves_assassin", "gloves_titan",  # glove curios
	"boots_swift", "boots_storm", "boots_titan",       # boot curios
]

func _ready() -> void:
	say("start")
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "": shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)

	var p: Node = null
	for i in range(600):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: say("no player"); get_tree().quit(1); return
	say("player found")

	# leave the opening cutscene
	for _r in range(20):
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish()
		get_tree().paused = false
		await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	GameState.game_hours = 10.0                      # daylight so the shot reads
	if p is Node2D: (p as Node2D).global_position = Vector2(-400, -160)

	# fill the bag with the 14
	for id in NEW_ARMOR:
		if p.inventory != null: p.inventory.add_item(id, 1)
	for _f in range(30):
		await get_tree().process_frame

	# park the mouse in a corner so no cursor sits over the grid
	get_viewport().warp_mouse(Vector2(4, 4))

	# open both panels
	var bag = get_tree().get_first_node_in_group("inventory_ui")
	var gear = get_tree().get_first_node_in_group("equipment_ui")
	if bag:
		bag.visible = true
		if bag.has_method("refresh"): bag.refresh()
	if gear:
		if "panel" in gear and gear.panel: gear.panel.visible = true
		if gear.has_method("refresh"): gear.refresh()
	for _f in range(30):
		await get_tree().process_frame
	_shot("armor_01_bag_all14")

	# now WEAR the Regalia set so the equipped slots + set-bonus lines light up
	for id in ["helm_regal", "armor_regal", "pants_regal"]:
		GameState.equip_item(id, p)
	if bag and bag.has_method("refresh"): bag.refresh()
	if gear and gear.has_method("refresh"): gear.refresh()
	for _f in range(30):
		await get_tree().process_frame
	_shot("armor_02_regalia_worn")

	say("done -> %s" % shot_dir)
	get_tree().quit(0)

func _shot(name: String) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null: say("null img %s" % name); return
	img.save_png(shot_dir.path_join(name + ".png"))
	say("shot %s (%dx%d)" % [name, img.get_size().x, img.get_size().y])
