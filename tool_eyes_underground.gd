extends Node
# EYES: THE UNDERGROUND. Boots the tile world and photographs the places the map
# rework changed -- the arrival chamber, the Delver's Road, a floor door on the
# chain, an ore vein, a lake, and a flooded road crossing. Static audits cannot
# see whether water READS as water, so this is the one that checks the look.
#
# Run WINDOWED (screenshots need a live viewport):
#   EYES_DIR="C:/.../pl_work" MONARCH_TEST="res://tool_eyes_underground.gd" Godot.exe --path .

var shot_dir := "user://eyes"
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().change_scene_to_file.call_deferred("res://underground.tscn")
	var p := await _await_player()
	if p == null:
		say("EYES-UG: no player"); get_tree().quit(1); return
	var ug = get_tree().get_first_node_in_group("tile_world")
	if ug == null:
		say("EYES-UG: no tile world"); get_tree().quit(1); return
	# This tool teleports the player into the middle of mob crowds all over the
	# map; without this it gets killed halfway through the run and every shot
	# after that is a death screen.
	if "god_mode" in p:
		p.god_mode = true
	await _settle(1.2)
	await _shot("ug_entry")                      # the arrival chamber + the road out of it

	# ── the road, a few levels down the chain ──
	for lvl in [3, 18, 46, 84]:
		var d: Vector2i = ug._door_stand(ug._doors[lvl - 1])
		await _tp(p, ug, d + Vector2i(0, -2))
		await _shot("ug_door_%d" % lvl)

	# ── a lake: the biggest one in each biome ──
	var shown := {}
	for lk in ug._lakes:
		var b: int = ug._biome_of(int(lk.c.y))
		if shown.has(b) or not bool(lk.big):
			continue
		shown[b] = true
		await _tp(p, ug, Vector2i(int(lk.c.x), int(lk.c.y) - 3))
		await _shot("ug_lake_b%d" % b)
		if shown.size() >= 3:
			break

	# ── a flooded stretch of the road itself ──
	var flood: Array = ug._road_flood
	for y in range(flood.size()):
		if not flood[y].is_empty():
			var s: Vector2i = flood[y][0]
			await _tp(p, ug, Vector2i(int((s.x + s.y) / 2), y - 1))
			await _settle(0.9)                   # let the player sink in
			await _shot("ug_wade")
			break

	# ── an ore vein, for the glint ──
	var found := false
	for lk in ug._lakes:
		if found:
			break
		for r in range(0, 60):
			var cell := Vector2i(int(lk.c.x) + r, int(lk.c.y) + 20)
			if ug._gen_kind(cell.x, cell.y) >= ug.ORE_COL:
				await _tp(p, ug, cell + Vector2i(0, -3))
				await _shot("ug_ore")
				found = true
				break
	# ── CLOSE-UP: the world sits at 0.6 zoom (160 tiles across), where cave decor
	# is a few pixels tall and impossible to judge. Zoom right in on a lit stretch
	# of road so the stalactites, vines, webs, rubble and pots can be inspected.
	var cam = p.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(2.2, 2.2)
	for lvl in [12, 40]:
		var d: Vector2i = ug._door_stand(ug._doors[lvl - 1])
		await _tp(p, ug, d + Vector2i(6, -2))
		await _settle(0.5)
		await _shot("ug_closeup_%d" % lvl)
	say("EYES-UG: done -> %s" % shot_dir)
	get_tree().quit(0)

func _tp(p: Node, ug: Node, cell: Vector2i) -> void:
	p.global_position = ug._map.to_global(ug._map.map_to_local(cell))
	if "velocity" in p:
		p.velocity = Vector2.ZERO
	await _settle(0.7)                            # let the chunks stream in around it

func _await_player() -> Node:
	for i in range(1400):
		await get_tree().process_frame
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			return p
	return null

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	say("EYES-UG: shot %s" % name)
