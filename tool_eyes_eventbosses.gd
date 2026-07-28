extends Node
# EYES: THE HIDDEN EVENT BOSSES (2026-07-28). Spawns each of the eleven secret
# bosses in the village in turn and screenshots TWO frames of each -- its idle
# procedural rig, and its PHASE-TWO transformation -- so every silhouette and
# every second form can be eyeballed at a glance (the one thing the test suite
# can't judge). Run WINDOWED (screenshots need a live viewport):
#   EYES_DIR="C:/some/dir" MONARCH_TEST="res://tool_eyes_eventbosses.gd" Godot.exe --path .
# Headless still runs the whole walk (spawn/transform/free every boss) as a
# smoke test -- it just logs instead of saving images.

const BOSS_SCENE = preload("res://boss.tscn")

var shot_dir := "user://eyes"
var _n := 0
var _headless := false
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p := await _await_player()
	if p == null:
		say("EYES-EB: no village player"); get_tree().quit(1); return
	await _clear_dialog()
	GameState.opening_done = true
	# seat a boss HUD so the phase-two banner reads in the shots (the village has
	# none by default; mirror what the event director does)
	var hud = get_tree().get_first_node_in_group("boss_hud")
	if hud == null:
		hud = preload("res://boss_hud.gd").new()
		hud.name = "EyesBossHUD"
		add_child(hud)

	var ground_y: float = p.global_position.y
	var base_x: float = p.global_position.x
	var scene = get_tree().current_scene
	if scene == null:
		say("EYES-EB: no scene"); get_tree().quit(1); return

	for id in EventBoss.ids():
		var ev: Dictionary = EventBoss.get_event(str(id))
		var sc: Dictionary = EventBoss.scaling_for(str(id))
		var boss = BOSS_SCENE.instantiate()
		boss.boss_id = str(ev.get("boss_id", "gravewarden"))
		boss.level_hp_mult = float(sc.get("hp", 1.0))
		boss.damage_multiplier = float(sc.get("dmg", 1.0))
		boss.speed_multiplier = 1.0
		boss.boss_floor = int(sc.get("floor", 22))
		scene.add_child(boss)                 # _ready builds the rig from the def
		boss.add_to_group("dungeon_combatant")
		var bx: float = base_x + 420.0
		boss.global_position = Vector2(bx, ground_y - 150.0)
		# frame it: put the camera (player) so the boss sits centre-right
		p.global_position = Vector2(bx - 300.0, ground_y)
		boss.player = null                    # idle: it stands and settles, no chase
		if hud != null and hud.has_method("present"):
			hud.present(str(ev.get("name", "?")),
				str(sc.get("label", "")) + " — " + str(ev.get("banner", "")),
				sc.get("accent", Color(1, 1, 1)))
		await _settle(1.1)
		await _shot("%02d_%s_1_idle" % [_boss_index(id), id])

		# force PHASE TWO directly so the second form is GUARANTEED in every shot
		# (a 1-damage chip gets absorbed by stagger-armoured bosses before it can
		# trip the threshold -- fine in real play with real hits, but unreliable
		# for a QC screenshot). Drain the bar too, so the shot reads "low HP".
		boss.player = p
		if "max_health" in boss and "health" in boss:
			boss.health = int(boss.max_health * 0.4)
			if boss.has_method("update_health_bar"):
				boss.update_health_bar()
		if boss.has_method("phase_two"):
			boss.phase_two()
		await _settle(1.5)                     # let the banner + transform land
		var p2 := ("phase2=%s" % str(boss.phase2_active)) if ("phase2_active" in boss) else "?"
		await _shot("%02d_%s_2_phase2" % [_boss_index(id), id])
		say("EYES-EB: %s  (%s / %s)  %s" % [id, str(ev.get("name", "")), str(sc.get("label", "")), p2])

		boss.queue_free()
		await _settle(0.4)

	say("EYES-EB: DONE — %d bosses, %d frames -> %s" % [EventBoss.ids().size(), _n, shot_dir])
	get_tree().quit(0)

func _boss_index(id: String) -> int:
	return EventBoss.ids().find(id) + 1

# ------------------------------------------------------------------ helpers
func _await_player() -> Node:
	for i in range(1400):
		await get_tree().process_frame
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			return p
	return null

func _shot(name: String) -> void:
	if _headless:
		_n += 1
		say("EYES-EB: (headless, no image) %s" % name)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	_n += 1
	say("EYES-EB: shot %s" % name)

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _clear_dialog() -> void:
	for _r in range(16):
		var found := false
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); found = true
		get_tree().paused = false
		await _settle(0.2)
		if not found and not get_tree().paused:
			return
