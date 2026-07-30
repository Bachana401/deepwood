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
	# ── a Life Crystal, and a keg mid-fuse ──
	for ci in range(ug._crystals.size()):
		var cc: Vector2i = ug._crystals[ci]
		if cc.x < -9000:
			continue
		await _tp(p, ug, cc - Vector2i(0, 2))
		await _settle(0.5)
		await _shot("ug_crystal")
		break
	var kegs := get_tree().get_nodes_in_group("ug_keg")
	if not kegs.is_empty():
		var k = kegs[0]
		p.global_position = k.global_position + Vector2(-70, -20)
		await _settle(0.6)
		await _shot("ug_keg")
		ug._light_keg(k)
		await _settle(0.5)
		await _shot("ug_keg_fuse")
		await _settle(0.9)
		await _shot("ug_keg_boom")
	# ── a rope and a plank walkway, found in the world ──
	for lvl in [30, 55]:
		var d: Vector2i = ug._door_stand(ug._doors[lvl - 1])
		await _tp(p, ug, d + Vector2i(0, -2))
		await _settle(0.6)
		var best := Vector2i(-9999, -9999)
		for cell in ug._ropes.keys():
			if absi(cell.x - d.x) < 90 and absi(cell.y - d.y) < 60:
				best = cell
				break
		if best.x > -9000:
			await _tp(p, ug, best - Vector2i(0, 2))
			await _settle(0.5)
			await _shot("ug_rope_%d" % lvl)
			break
	for lvl in [30, 55, 70]:
		var d2: Vector2i = ug._door_stand(ug._doors[lvl - 1])
		await _tp(p, ug, d2 + Vector2i(0, -2))
		await _settle(0.6)
		var bp := Vector2i(-9999, -9999)
		for cell in ug._platforms.keys():
			if absi(cell.x - d2.x) < 90 and absi(cell.y - d2.y) < 60:
				bp = cell
				break
		if bp.x > -9000:
			await _tp(p, ug, bp - Vector2i(0, 3))
			await _settle(0.5)
			await _shot("ug_platform_%d" % lvl)
			break
	# ── a mine railway, and a pocket of sand coming down ──
	if not ug._track_runs.is_empty():
		var mid: Vector2i = ug._path[int(ug._track_runs[0][0]) + 20]
		await _tp(p, ug, mid - Vector2i(0, 2))
		await _settle(0.6)
		await _shot("ug_track")
	for lvl in [8, 22, 44]:
		var d3: Vector2i = ug._door_stand(ug._doors[lvl - 1])
		var found_sand := Vector2i(-9999, -9999)
		for r in range(-40, 40):
			for dy in range(-14, 14):
				if ug._cell_kind(d3 + Vector2i(r, dy)) == ug.SAND:
					found_sand = d3 + Vector2i(r, dy)
					break
			if found_sand.x > -9000:
				break
		if found_sand.x > -9000:
			await _tp(p, ug, found_sand - Vector2i(6, 4))
			await _settle(0.5)
			await _shot("ug_sand")
			# cut it loose and watch
			for dx in range(-2, 3):
				ug._topple_sand(found_sand + Vector2i(dx, 1))
			await _settle(0.25)
			await _shot("ug_sand_falling")
			break
	# ── WATER FLOW: breach a lake and photograph it draining ──
	var lake := {}
	for lk in ug._lakes:
		if bool(lk.big) and int(lk.d) >= 16:
			lake = lk
			break
	if not lake.is_empty():
		var lc: Vector2i = lake.c
		var row: int = lc.y + int(lake.d) - 3
		var wx: int = lc.x
		while wx < lc.x + 140 and not ug._solid_kind(Vector2i(wx, row)):
			wx += 1
		await _tp(p, ug, Vector2i(wx + 6, row - 6))
		await _settle(0.7)
		await _shot("ug_flow_before")
		# cut a channel out of the side and let it run
		for k in range(14):
			var h := Vector2i(wx + k, row)
			for dy in range(0, 2):
				ug._edits[h + Vector2i(0, dy)] = ug.AIR
				ug._map.erase_cell(h + Vector2i(0, dy))
		ug._disturb(Vector2i(wx, row))
		await _settle(0.35)
		await _shot("ug_flow_running")
		await _settle(2.5)
		await _shot("ug_flow_settled")
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
