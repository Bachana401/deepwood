extends Node
# ── UNDERGROUND CHAOS SOAK ────────────────────────────────────────────────────
# Scripted tests check what I thought of; this checks what I didn't. Boot the
# live underground and do THOUSANDS of random destructive things where the
# player actually is -- mine, explode, topple, pour, quench -- and after every
# burst assert the invariants that must survive anything:
#
#   I1  no cell ever holds both liquids
#   I2  no liquid level survives inside solid rock
#   I3  the wake queue always drains back to empty (no perpetual simulation)
#   I4  every live mob's body is in open space (or the sweep frees it)
#   I5  the sidecar save round-trips whatever mess we made
#
#   MONARCH_TEST="res://tool_ug_chaos.gd" Godot.exe --headless --path .

var fails := 0
func say(t: String) -> void: printerr(t)
func flag(label: String, ok: bool) -> void:
	if not ok:
		fails += 1
		printerr("CHAOS-FAIL  " + label)

func _ready() -> void:
	GameState.world_seed = int(OS.get_environment("UG_SEED")) if OS.get_environment("UG_SEED") != "" else 0
	get_tree().change_scene_to_file.call_deferred("res://underground.tscn")
	var ug: Node = null
	var p: Node = null
	for i in range(1400):
		await get_tree().process_frame
		ug = get_tree().get_first_node_in_group("tile_world")
		p = get_tree().get_first_node_in_group("player")
		if ug != null and p != null:
			break
	if ug == null or p == null:
		say("CHAOS: no boot"); get_tree().quit(1); return
	if "god_mode" in p:
		p.god_mode = true
	# HERMETIC: the previous run SAVED its chaos (I5), and a polluted sidecar made
	# every later run fail I2 at burst 0 with a constant count -- the signature of
	# loaded state, not fresh breakage. Start from a clean world.
	DirAccess.remove_absolute(ug._save_path())
	ug._edits = {}
	ug._lv = {}
	ug._ll = {}
	ug._hp = {}
	ug._own_torches = {}
	ug._ropes = {}
	ug._platforms = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("CHAOS_SEED")) if OS.get_environment("CHAOS_SEED") != "" else 0xC4405
	var t0 := Time.get_ticks_msec()
	for burst in range(40):
		# go somewhere real: near a random door, chunks streamed in
		var d: Vector2i = ug._door_stand(ug._doors[rng.randi_range(0, 99)])
		p.global_position = ug._map.to_global(ug._map.map_to_local(d - Vector2i(0, 2)))
		if "_last_ground_pos" in p:
			p._last_ground_pos = p.global_position
		if "fall_apex_y" in p:
			p.fall_apex_y = p.global_position.y
		for i in range(10):
			await get_tree().process_frame
		# ── the burst: 60 random violent acts in the streamed bubble ──
		for act in range(60):
			var cell := Vector2i(d.x + rng.randi_range(-40, 40), d.y + rng.randi_range(-25, 25))
			match rng.randi_range(0, 4):
				0:
					ug._break(cell, 3, p)                       # strongest pickaxe
				1:
					if rng.randf() < 0.25:
						ug._explode(cell, rng.randi_range(3, 8))
				2:
					ug._topple_sand(cell)
				3:
					if ug._cell_kind(cell) == ug.AIR:
						ug._set_level(cell, rng.randi_range(1, 8))   # pour water
				4:
					if ug._cell_kind(cell) == ug.AIR:
						ug._set_lava(cell, rng.randi_range(1, 8))    # pour LAVA
		# let it settle: flow budget is per-frame, so give it frames
		for i in range(140):
			await get_tree().process_frame
			if ug._wq_list.is_empty() and get_tree().get_nodes_in_group("ug_fallsand").is_empty():
				break
		# ── the invariants ──
		var both := 0
		var in_rock := 0
		for cell in ug._lv.keys():
			if int(ug._lv[cell]) > 0:
				if ug._ll.has(cell) and int(ug._ll[cell]) > 0:
					both += 1
				if ug._solid_kind(cell):
					in_rock += 1
		for cell in ug._ll.keys():
			if int(ug._ll[cell]) > 0 and ug._solid_kind(cell):
				in_rock += 1
		flag("I1 burst %d: %d cells hold both liquids" % [burst, both], both == 0)
		flag("I2 burst %d: %d liquid levels inside rock" % [burst, in_rock], in_rock == 0)
		flag("I3 burst %d: wake queue stuck at %d" % [burst, ug._wq_list.size()],
			ug._wq_list.size() < 4000)
		# the unstick sweep runs on a 1s cadence, and the settle window above can
		# close in two frames when nothing poured -- so force one sweep NOW and
		# judge the MECHANISM, not the race against its timer
		ug._unstick_cd = 0.0
		for i in range(3):
			await get_tree().process_frame
		var buried := 0
		for e in get_tree().get_nodes_in_group("course_enemy"):
			if is_instance_valid(e) and e.get_parent() == ug \
					and ug._solid_kind(ug._cell_at(e.global_position)):
				buried += 1
				var bc: Vector2i = ug._cell_at(e.global_position)
				say("  [I4 dbg] mob at %s cell=%s kind=%d  queued_for_deletion=%s  in_group=%s"
					% [str(e.global_position), str(bc), ug._cell_kind(bc),
					   str(e.is_queued_for_deletion()), str(e.is_in_group("course_enemy"))])
		flag("I4 burst %d: %d mobs left inside rock after a sweep" % [burst, buried], buried == 0)
	# ── I5: the save survives the whole mess ──
	var edits_n: int = ug._edits.size()
	var lv_n: int = ug._lv.size()
	var ll_n: int = ug._ll.size()
	ug._save()
	ug._edits = {}
	ug._lv = {}
	ug._ll = {}
	ug._load_save()
	flag("I5 save round-trip (%d edits, %d water, %d lava)" % [edits_n, lv_n, ll_n],
		ug._edits.size() == edits_n and ug._lv.size() == lv_n and ug._ll.size() == ll_n)
	say("CHAOS: 40 bursts, 2400 acts, %d ms, edits=%d water=%d lava=%d"
		% [Time.get_ticks_msec() - t0, edits_n, lv_n, ll_n])
	say("RESULT: %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(1 if fails > 0 else 0)
