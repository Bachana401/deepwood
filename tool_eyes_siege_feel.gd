extends Node
# PLAY-QA: does a siege still FEEL threatening after the 2026-07-29 attrition
# softening? The softening touched resolve_siege_offline ONLY -- the away-report
# maths -- while a LIVE siege is real combat through siege_manager. This stages a
# real mid-game wave at home and shoots it so the dev can judge the feel, and
# prints the raider stats the player is actually facing.
#   MONARCH_TEST="res://tool_eyes_siege_feel.gd" Godot.exe --path .   (windowed)
var shot_dir := "user://eyes"
func say(t: String) -> void: printerr("SIEGE: " + t); OS.delay_msec(1)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "": shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(900):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: say("no player"); get_tree().quit(1); return
	for _r in range(20):
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish()
		get_tree().paused = false
		await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	GameState.game_hours = 10.0

	# --- a real mid-game town: floor ~40 depth, a peopled village, a raised wall
	# and defenders posted, which is the state a siege is BALANCED against ---
	GameState.highest_unlocked_level = 40
	GameState.wall_level = 3
	for i in range(GameState.rescued_villagers.size(), 18):
		GameState.rescued_villagers.append({
			"id": "qa_%d" % i, "name": "Townsfolk %d" % i,
			"sex": "Male" if i % 2 == 0 else "Female", "is_kid": false,
			"stat_name": "Warrior" if i % 3 == 0 else "Farm", "stat_value": 4,
			"role_key": "", "role_title": ""})
	GameState.ensure_adventurers()
	for id in Adventurers.ids():
		if int(Adventurers.get_def(id).get("level", 0)) <= 40:
			GameState.adventurers[id]["rescued"] = true
			GameState.adventurers[id]["dead"] = false
			if not GameState.set_adventurer_station(id, "wall"):
				GameState.set_adventurer_station(id, "city")
	var tier: int = GameState.current_siege_tier()
	say("depth 40 -> siege TIER %d, village defense %.1f" % [tier, GameState.village_defense_power()])
	say("offline maths WOULD cost: %d souls (shortfall/%0.1f, cap %d)" % [
		maxi(0, mini(GameState.SIEGE_MAX_CASUALTIES,
			int(ceil(maxf(0.0, float(tier) - GameState.village_defense_power()) / GameState.SIEGE_SHORTFALL_PER_CASUALTY)))),
		GameState.SIEGE_SHORTFALL_PER_CASUALTY, GameState.SIEGE_MAX_CASUALTIES])

	# put the camera at the west gate, where the wave climbs out of the deep
	var wall = get_tree().get_first_node_in_group("village_wall")
	if wall != null and p is Node2D:
		(p as Node2D).global_position = Vector2(wall.global_position.x + 260.0, (p as Node2D).global_position.y)
	for _f in range(60):
		await get_tree().process_frame

	var mgr = get_tree().get_first_node_in_group("siege_manager")
	if mgr == null: say("no siege_manager in scene"); get_tree().quit(1); return
	mgr.start_live_siege(tier, false)
	GameState.live_siege_active = true
	say("live siege started at tier %d" % tier)
	# shoot the battle as it develops: the horde arriving, the clash, the aftermath.
	# The camera RIDES THE FRONT -- raiders climb the road from ~640px west of the
	# gate, so a fixed spot at the wall just shows empty ground (first attempt did).
	var marks := [40, 150, 300, 500, 800]
	var shot_i := 0
	for f in range(1, 900):
		await get_tree().process_frame
		if p is Node2D:
			var front := _front_x()
			if front != INF:
				(p as Node2D).global_position.x = front + 150.0
		if shot_i < marks.size() and f >= marks[shot_i]:
			_shot("siege_%02d_f%d" % [shot_i + 1, f])
			shot_i += 1

# Where the fighting is: the raider nearest the village (largest x on the west
# approach), so the shot frames the clash instead of the empty road behind it.
func _front_x() -> float:
	var best := -INF
	for e in get_tree().get_nodes_in_group("siege_enemy"):
		if is_instance_valid(e) and e is Node2D and not (e.get("is_dead") == true):
			best = maxf(best, (e as Node2D).global_position.x)
	return best if best > -INF else INF
	say("villagers left: %d, adventurers dead: %d" % [
		GameState.rescued_villagers.size(), _dead_advs()])
	say("done -> %s" % shot_dir)
	get_tree().quit(0)

func _dead_advs() -> int:
	var n := 0
	for id in GameState.adventurers.keys():
		if GameState.adventurers[id].get("dead", false): n += 1
	return n

func _shot(name: String) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	img.save_png(shot_dir.path_join(name + ".png"))
	say("shot %s" % name)
