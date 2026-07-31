extends Node

# EYES ON THE WEAPONS (dev, 2026-07-30: "i gave you so many good examples, but
# i still don't see any of them implemented the way i showed you").
#
# Every other instrument I built today counts. This one LOOKS. It stands a
# weapon in the Proving Ground, fires it, and photographs the result twice --
# once with the attack in flight, once a beat later when only the trail and the
# aftermath are left -- because the dev's complaint is not about numbers. It is
# that the Meowmere ribbon, the Starlight filaments and the Kaleidoscope chain
# were measured from his clips, written into the code, and never once looked at
# by anybody, me included.
#
# Two frames per weapon on purpose. The FLIGHT frame answers "is the projectile
# the right size and shape"; the AFTERMATH frame answers "does the trail
# outlive the thing that made it", which is the entire Meowmere law and cannot
# be seen in a frame where the projectile is still on screen.
#
# NOT headless: --headless has no renderer and every shot comes back null. Run
# it windowed. See run_eyes_weapons.ps1.
#
# Env:
#   EYES_DIR    where the pngs go (default user://eyes_weapons)
#   EYES_TIER   lowest tier to shoot (default 6 -- the tiers the dev is
#               complaining about; set 1 to photograph the whole roster)

const ARENA := preload("res://weapon_arena.gd")

var shot_dir := "user://eyes_weapons"
var min_tier := 6
var _dumped := false

func say(t: String) -> void: printerr(t)

# (the Mark class lived here until the arena became a scene of its own -- it is
# weapon_arena.Mark now, so there is exactly one puppet definition to keep true)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	var env_tier := OS.get_environment("EYES_TIER")
	if env_tier != "":
		min_tier = int(env_tier)
	DirAccess.make_dir_recursive_absolute(shot_dir)

	await get_tree().process_frame
	GameState.opening_done = true
	get_tree().paused = false
	# ITS OWN SCENE. Shooting inside the live village meant every frame carried
	# whatever terrain, buildings, NPCs and hour happened to be there, so two
	# runs of the SAME weapon were not comparable -- and a colour judgement
	# between two incomparable frames is worth nothing, which is exactly the
	# judgement these frames exist to support.
	var arena = ARENA.take_over(get_tree(), self)
	for _f in range(20):
		await get_tree().process_frame
	var p: Node = arena.player
	if p == null or not is_instance_valid(p):
		say("ABORTED: arena has no puppet"); get_tree().quit(0); return

	# EYES_IDS=wpn_a,wpn_b photographs a handful -- same filter the proving
	# sweep grew, for the same reason: a batch of new souls should not cost
	# a whole-tier shoot to look at
	var only_ids: PackedStringArray = []
	var env_ids := OS.get_environment("EYES_IDS")
	if env_ids != "":
		only_ids = env_ids.split(",")
	var shot := 0
	for row in WeaponRoster.ROWS:
		if only_ids.size() > 0:
			if not only_ids.has(str(row[0])):
				continue
		elif int(row[3]) < min_tier:
			continue
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			continue
		p.inventory.add_item(id, 1)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		p.health = p.get_max_health()
		for _f in range(4):
			await get_tree().process_frame
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		# IN FLIGHT: far enough in that the projectile has left the hand and is
		# at its full drawn size, early enough that it still exists
		await get_tree().create_timer(0.22, true).timeout
		_shot("T%d_%s_a_flight" % [int(row[3]), id])
		# AFTERMATH: the projectile is usually gone. What is left is the trail,
		# and whether anything is left AT ALL is the Meowmere law's whole test.
		# THE SLOW BEAT (2026-07-31): a mortar's flight alone is ~1.1s, a fuse
		# adds 0.55 more, a pool is laid AFTER the landing -- shooting their
		# aftermath at 0.67s photographed every slow verb mid-flight, before
		# its soul had happened. Slow families wait for their moment.
		var after_wait := 0.45
		if str(row[4]) in ["lob", "lob_a", "sunspill", "tallowdrip", "boulder"]:
			after_wait = 1.5
		await get_tree().create_timer(after_wait, true).timeout
		_shot("T%d_%s_b_after" % [int(row[3]), id])
		shot += 1
		await get_tree().create_timer(0.25, true).timeout

	say("EYES: %d weapons, %d frames -> %s" % [shot, shot * 2, shot_dir])
	get_tree().quit(0)

func _shot(name: String) -> void:
	# AT THE MOMENT OF CAPTURE, not at takeover. Three theories about the
	# leftover village strip have been wrong, and every one was tested against
	# the tree as it stood when the arena was built -- half a minute and many
	# frames before the picture was actually taken. What is on screen is decided
	# HERE.
	if OS.has_environment("ARENA_DUMP") and not _dumped:
		_dumped = true
		printerr("\n=== TREE AT SHOT TIME (%s) ===" % name)
		for n in get_tree().root.get_children():
			printerr("  %-26s %-20s" % [n.name, n.get_class()])
			for c in n.get_children():
				printerr("      %-22s %-20s vis=%s" % [c.name, c.get_class(),
					str(c.visible) if c is CanvasItem else "-"])
		printerr("  current_scene: %s" % (
			"null" if get_tree().current_scene == null
			else get_tree().current_scene.name))
		printerr("  viewport size: %s\n" % str(get_viewport().get_visible_rect().size))
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		say("null img %s  (are you running WINDOWED? --headless cannot draw)" % name)
		return
	img.save_png(shot_dir.path_join(name + ".png"))
