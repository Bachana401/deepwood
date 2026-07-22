extends Node
# CREATIVE HAZARDS (dev report 2026-07-21: "no creative traps"). Four distinct
# environmental dangers now scatter through the floors. This proves each one:
#   - BITES a player caught in its zone at the moment it fires,
#   - SPARES a player who kept clear (it's dodgeable, not a blind tax),
#   - and never one-shots a healthy player.
# The state machines are phase-clocked, so the test forces each into its live
# phase and ticks it once -- deterministic, no waiting on rhythm.

var fails := 0
const HZ = preload("res://hazard.gd")

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func keep_running() -> void:
	if not get_tree().paused:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("finish") and n.has_method("show_line"):
			n.finish()
			break
	get_tree().paused = false

func _spawn(kind: String) -> Node2D:
	var h = HZ.new()
	h.kind = kind
	h.damage = 24
	get_tree().current_scene.add_child(h)
	# drive it ONLY by the forced _tick_* calls below, so the test is deterministic --
	# otherwise its own phase-clock could fire during an await (it did, in a clean
	# clone: the gas cloud poisoned the player before we measured the baseline).
	h.set_physics_process(false)
	return h

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		keep_running()
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(30):
		keep_running()
		await get_tree().process_frame
	var was_god: bool = p.god_mode
	p.god_mode = false
	var maxhp: int = p.get_max_health()

	# ---- SPIKE: fires from "warn" -> "up", hits whoever is over it ----
	var sp := _spawn("spike")
	sp.global_position = p.global_position + Vector2(20, 0)
	await get_tree().process_frame
	p.health = maxhp
	sp._state = "warn"; sp._t = sp.SPIKE_WARN + 0.01
	sp._tick_spike()
	await get_tree().process_frame
	check("spikes erupt on a player standing over them", p.health < maxhp, "hp %d/%d" % [p.health, maxhp])
	check("...without one-shotting", p.health > 0)
	# clear of it: nothing
	sp.global_position = p.global_position + Vector2(900, 0)
	p.health = maxhp; p.invincible = false
	sp._state = "warn"; sp._t = sp.SPIKE_WARN + 0.01
	sp._tick_spike()
	await get_tree().process_frame
	check("spikes miss a player who kept moving past", p.health == maxhp, "hp %d" % p.health)
	sp.queue_free()

	# ---- CRUSHER: fires from "drop" -> "impact" on whoever is under ----
	var cr := _spawn("crusher")
	cr.global_position = p.global_position + Vector2(10, 0)
	await get_tree().process_frame
	p.health = maxhp; p.invincible = false     # clear the i-frames the spike just set
	cr._state = "drop"; cr._t = cr.CRUSH_DROP + 0.01
	cr._tick_crusher()
	await get_tree().process_frame
	check("the crusher slams a player caught beneath it", p.health < maxhp, "hp %d" % p.health)
	check("...without one-shotting", p.health > 0)
	cr.global_position = p.global_position + Vector2(900, 0)
	p.health = maxhp; p.invincible = false
	cr._state = "drop"; cr._t = cr.CRUSH_DROP + 0.01
	cr._tick_crusher()
	await get_tree().process_frame
	check("the crusher misses if you don't stop under it", p.health == maxhp, "hp %d" % p.health)
	cr.queue_free()

	# ---- FLAMEVENT: burns whoever stands in the column mid-eruption ----
	var fv := _spawn("flamevent")
	fv.global_position = p.global_position + Vector2(0, 0)
	await get_tree().process_frame
	p.health = maxhp; p.invincible = false
	fv._hit_cd = 0.0
	fv._t = fv.FLAME_DORMANT + fv.FLAME_ERUPT * 0.5    # peak of the jet
	fv._tick_flamevent()
	await get_tree().process_frame
	check("a fire jet burns a player standing in it", p.health < maxhp, "hp %d" % p.health)
	check("...without one-shotting", p.health > 0)
	fv.global_position = p.global_position + Vector2(700, 0)
	p.health = maxhp; p.invincible = false
	fv._hit_cd = 0.0
	fv._t = fv.FLAME_DORMANT + fv.FLAME_ERUPT * 0.5
	fv._tick_flamevent()
	await get_tree().process_frame
	check("the jet spares a player who crossed in the gap", p.health == maxhp, "hp %d" % p.health)
	fv.queue_free()

	# ---- GAS: poisons whoever breathes the cloud (poison_until pushes forward) ----
	var gs := _spawn("gas")
	gs.global_position = p.global_position + Vector2(0, 0)
	await get_tree().process_frame
	p.poison_until = 0.0                        # clean baseline (poison uses max())
	var poison_before: float = p.poison_until
	gs._hit_cd = 0.0
	gs._t = gs.GAS_DORMANT + gs.GAS_SPEW * 0.5
	gs._tick_gas()
	await get_tree().process_frame
	check("the geyser poisons a player in the cloud", p.poison_until > poison_before,
		"until %.1f vs %.1f" % [p.poison_until, poison_before])
	# clear of the cloud: no poison
	gs.global_position = p.global_position + Vector2(600, 0)
	var poison_before2: float = p.poison_until
	gs._hit_cd = 0.0
	gs._t = gs.GAS_DORMANT + gs.GAS_SPEW * 0.5
	gs._tick_gas()
	await get_tree().process_frame
	check("the geyser spares a player clear of the cloud", p.poison_until == poison_before2)
	gs.queue_free()

	p.god_mode = was_god
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
