extends Node
# EYES: SCAN-2 WAVE-2 SPOTS (2026-07-27). The fixes of commit 4481178 that are
# VISUAL and were never seen with eyes: the speaker chevron's new keyline, the
# toast channel staying up through a beat, the villager right-click menu + stat
# sheet, the cave mouth + the new rubble seal at the tunnel head, the equip
# picker's scroll under 10+ items, the Forge panel's close button, and the
# music player's live state under a real audio driver. Run WINDOWED:
#   MONARCH_TEST="res://tool_eyes_wave2.gd" Godot.exe --path .    (no --headless!)

var shot_dir := "user://eyes"
var _n := 0
func say(t: String) -> void: printerr(t)

func _ready() -> void:
	var env_dir := OS.get_environment("EYES_DIR")
	if env_dir != "":
		shot_dir = env_dir
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("EYES-W2: no player"); get_tree().quit(1); return

	# ---- w1: the opening's FIRST box -- the chevron keyline over a speaker ----
	await _settle(1.2)
	await _shot("w1_chevron_opening")

	await _clear_dialog()
	GameState.opening_done = true
	GameState.seen_arrival_battle = true
	GameState.seen_arrival_talk = true

	# ---- w2: a toast fired DURING a beat must be visible (audit fix #45) ----
	var scene = get_tree().current_scene
	DialogueBox.play(p, [{"speaker": "Elenwe", "text": "A test beat is playing — the toast on the right must be visible."}], Callable())
	await _settle(0.5)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack != null:
		stack.show_notification("⚑ TOAST DURING BEAT — if you can read this in the shot, #45 holds.")
	await _settle(0.6)
	await _shot("w2_toast_during_beat")
	await _clear_dialog()

	# ---- w3/w4: villager right-click menu + the stat sheet ----
	if scene.has_method("spawn_existing_villager_avatars"):
		scene.spawn_existing_villager_avatars()
	await _settle(0.5)
	var vnpc: Node = null
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and "villager_id" in n and str(n.villager_id) != "":
			vnpc = n
			break
	if vnpc != null:
		p.global_position = vnpc.global_position + Vector2(-90.0, -40.0)
		vnpc.open_menu()
		await _settle(0.8)
		await _shot("w3_villager_menu")
		# press "Show me stats" via the menu's own handler
		var menu = get_tree().get_first_node_in_group("villager_menu")
		if menu != null and menu.has_method("_on_stats"):
			menu._on_stats()
			await _settle(0.8)
			await _shot("w4_villager_sheet")
		for s in get_tree().get_nodes_in_group("villager_sheet"):
			if is_instance_valid(s) and s.has_method("esc_close"):
				s.esc_close()
	else:
		say("EYES-W2: no villager npc found (menu/sheet shots skipped)")
	await _clear_dialog()

	# ---- w5/w6: the cave mouth, and the rubble seal at the tunnel head ----
	var UD = preload("res://underdark.gd")
	p.global_position = Vector2(UD.MOUTH_X - 80.0, -60.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.0)
	await _shot("w5_cave_mouth")
	p.global_position = Vector2(UD.DESCENT_X + 40.0, UD.TUNNEL_TOP_Y - 60.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(1.0)
	await _shot("w6_tunnel_head_seal")
	# back to the surface for the UI shots
	p.global_position = Vector2(UD.MOUTH_X + 300.0, -80.0)
	if "velocity" in p: p.velocity = Vector2.ZERO
	await _settle(0.6)

	# ---- w7: the equip picker under a PILE of helmets (audit fix #55) ----
	if "inventory" in p and p.inventory != null:
		var helms := []
		for id in Inventory.ITEM_DEFS.keys():
			var d: Dictionary = Inventory.ITEM_DEFS[id]
			if str(d.get("category", "")) == "armor" and str(d.get("slot", d.get("equip_slot", ""))) != "":
				helms.append(id)
		# any armor works: the point is MANY rows in one slot's picker. Load the
		# bag with every armor piece in the game, then open the fullest slot.
		var added := 0
		var rejected := 0
		for id in helms:
			if p.inventory.add_item(id, 1) == 0:
				added += 1
			else:
				rejected += 1
		say("EYES-W2: armor defs=%d added=%d rejected=%d bag_slots=%d" % [
			helms.size(), added, rejected, p.inventory.slots.size()])
		var eq: Node = null
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("open_picker_for_slot"):
				eq = n
				break
		if eq != null:
			# the real UI paths run ensure_player() before touching the bag; this
			# walker calls open_picker_for_slot directly, so do the same first
			if eq.has_method("ensure_player"):
				eq.ensure_player()
			if "panel" in eq and eq.panel != null:
				eq.panel.visible = true
			var best_slot := "helmet"
			var best_count := 0
			for slot_key in ["helmet", "chest", "pants"]:
				var c: int = eq._eligible_items(slot_key).size()
				if c > best_count:
					best_count = c
					best_slot = slot_key
			say("EYES-W2: picker slot=%s items=%d" % [best_slot, best_count])
			eq.open_picker_for_slot(best_slot, -1)
			await _settle(0.8)
			await _shot("w7_equip_picker")
			if "picker" in eq and eq.picker != null:
				eq.picker.visible = false
			if "panel" in eq and eq.panel != null:
				eq.panel.visible = false

	# ---- w8: the Forge wares panel with its new close button ----
	var forge = scene.get_node_or_null("CanvasLayer/ShopUI")
	if forge != null:
		forge.visible = true
		if forge.has_method("refresh_prices"):
			forge.refresh_prices()
		await _settle(0.6)
		await _shot("w8_forge_panel")
		forge.visible = false

	# ---- w9: the speaker chevron up close (its keyline is the fix) ----
	var si = preload("res://speaker_indicator.gd").new()
	scene.add_child(si)
	si.place(p.global_position + Vector2(0.0, -70.0), Color(0.9, 0.45, 0.3))
	await _settle(0.4)
	await _shot("w9_chevron_closeup")
	si.queue_free()

	# ---- music ground truth under a REAL audio driver (headless lies) ----
	var mp = scene.get_node_or_null("MusicPlayer")
	if mp != null:
		say("EYES-W2: MUSIC playing=%s stream=%s volume_db=%.1f" % [
			str(mp.playing), str(mp.stream), mp.volume_db])

	say("EYES-W2: done, %d shots in %s" % [_n, shot_dir])
	get_tree().quit(0)

# ------------------------------------------------------------------ helpers
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	_n += 1
	say("EYES-W2: shot %s" % name)

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
