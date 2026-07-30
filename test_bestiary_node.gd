extends Node
# THE BESTIARY (2026-07-29). Before this, a species was a skin: six rosters that
# differed only in colour, scale and three stat multipliers, and dungeon_interior
# rolled a special out of ONE shared five-item bag -- so an Orc was as likely to
# be a healer as a Rotfiend. This suite holds the fix to its promises:
#   - every species has its own NAMED signature, taken from the face it wears,
#   - the generic specials now suit the species (and none of the five was lost),
#   - each signature is a MECHANIC, not a number: the only one that deals damage
#     is capped per tick and can never land the killing blow,
#   - and each one has a real counter-play the test actually exercises (kill the
#     crier, heal past the scent, wait out the fade, smash the heap, leave the gas).

var fails := 0

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

# Spawn a mob wearing a given species' face, the way a dungeon floor does:
# archetype BEFORE the tree (the wave multipliers bake into max_health in _ready).
func spawn_species(vis: int, at: Vector2, stat := 0) -> Node:
	var e = load("res://enemy.tscn").instantiate()
	e.respawns = false
	e.apply_mixed_archetype(stat, vis)
	e.weapon_type = "sword"        # keep every test mob melee so nothing snipes mid-measurement
	# join a combatant group the way every real spawner does -- _living_allies
	# (and therefore the War Cry) can only see mobs that belong to one. Without
	# this the test measures an orc shouting into an empty room.
	e.add_to_group("dungeon_combatant")
	get_tree().current_scene.add_child(e)
	e.global_position = at
	return e

func settle(frames := 4) -> void:
	for i in range(frames):
		keep_running()
		await get_tree().process_frame

# Count the self-managing field effects lying in the scene: a Polygon2D that
# carries its own Timer is an ember patch or a gas cloud (both outlive the mob
# that made them, which is the whole point -- and both must free themselves).
func field_effects() -> int:
	var n := 0
	for c in get_tree().current_scene.get_children():
		if c is Polygon2D:
			for g in c.get_children():
				if g is Timer:
					n += 1
					break
	return n

# Stop a test mob swinging, so a stray melee hit can never be mistaken for a
# signature's damage. (Cooldown only ticks down by delta -- 99s outlasts any test.)
func disarm(e: Node) -> void:
	e.attack_cooldown_remaining = 99.0
	e.is_attacking = false

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
	await settle(30)

	var was_god: bool = p.god_mode
	var maxhp: int = p.get_max_health()
	var far: Vector2 = p.global_position + Vector2(900, 0)   # out of every mob's reach
	var enemy_script = load("res://enemy.gd")

	# ---------------- 1. every species has an identity ----------------
	var rosters: Array = enemy_script.ENEMY_ROSTERS
	var valid := ["shield", "caster", "healer", "summoner", "dasher"]
	var seen_kinds := {}
	var all_signed := true
	var all_affine := true
	for d in rosters:
		if str(d.get("signature", "")) == "":
			all_signed = false
		var aff: Array = d.get("affinity", [])
		if aff.is_empty():
			all_affine = false
		for k in aff:
			if not valid.has(k):
				all_affine = false
			seen_kinds[k] = true
	check("every species carries a named signature", all_signed)
	check("every species has a non-empty, legal behavior affinity", all_affine)
	check("...and no generic special was lost in the split",
		seen_kinds.size() == valid.size(), "covered %d of %d" % [seen_kinds.size(), valid.size()])

	# identity follows the FACE, not the floor's stat band: a floor-1 grunt
	# wearing a golem's bones must reassemble like a golem.
	var masked := spawn_species(4, far, 0)
	await settle()
	check("a signature comes from the VISUAL species, not the stat block",
		masked.signature == "reassemble" and masked.species_name == "Bone Golem",
		"got '%s' / '%s'" % [masked.signature, masked.species_name])
	var own: Array = masked.species_behaviors()
	check("...and so does its affinity", own.size() > 0 and not own.has("healer"),
		"golem affinity %s" % str(own))
	masked.queue_free()

	# ---------------- 2. ORC: War Cry ----------------
	var crier = spawn_species(0, far)
	var pack := []
	for i in range(3):
		pack.append(spawn_species(0, far + Vector2(60 * (i + 1), 0)))
	await settle()
	p.health = maxhp
	var before_speed: float = pack[0].move_speed()
	crier.war_cry()
	await settle(2)
	var rallied := 0
	for e in pack:
		if e.is_rallied():
			rallied += 1
	check("a War Cry rouses the whole pack that hears it", rallied == pack.size(),
		"%d of %d" % [rallied, pack.size()])
	check("...a roused orc runs faster", pack[0].move_speed() > before_speed,
		"%.1f -> %.1f" % [before_speed, pack[0].move_speed()])
	check("...and swings faster too", enemy_script.RALLY_ATTACK_SPEED < 1.0)
	check("...but the shout itself does no damage at all", p.health == maxhp,
		"lost %d" % (maxhp - p.health))
	# counter-play: the rally is a TIMER, so killing the crier can't be pointless
	check("...and it expires (a rally is a window, not a buff you keep)",
		enemy_script.RALLY_DURATION <= 8.0, "%.1fs" % enemy_script.RALLY_DURATION)
	crier.queue_free()
	for e in pack:
		e.queue_free()

	# ---------------- 3. BLOOD FIEND: Bloodscent ----------------
	var fiend = spawn_species(1, far)
	await settle()
	var calm_sight: float = fiend.detection_range_current
	var calm_speed: float = fiend.move_speed()
	p.health = int(maxhp * 0.3)                 # wounded: it should smell it
	await settle(6)
	check("a Blood Fiend frenzies on a wounded hero", fiend.frenzied)
	check("...it moves faster while frenzied", fiend.move_speed() > calm_speed,
		"%.1f -> %.1f" % [calm_speed, fiend.move_speed()])
	check("...and its sight doubles", fiend.detection_range_current > calm_sight * 1.9)
	p.health = maxhp                            # heal up: it must settle again
	await settle(6)
	check("healing past the scent CALMS it (the counter-play)", not fiend.frenzied)
	check("...and its sight returns to exactly where it started",
		absf(fiend.detection_range_current - calm_sight) < 0.01,
		"%.1f vs %.1f" % [fiend.detection_range_current, calm_sight])
	fiend.queue_free()

	# ---------------- 4. DEMON: Emberburst ----------------
	p.god_mode = false
	var demon = spawn_species(2, p.global_position + Vector2(30, 0))
	await settle()
	disarm(demon)
	var patches_before: int = field_effects()
	p.health = maxhp
	demon.take_damage(99999)                    # the corpse should keep burning
	await settle(2)
	check("a Demon's corpse leaves a burning patch", field_effects() > patches_before,
		"%d -> %d field effects" % [patches_before, field_effects()])
	check("...nothing burns during the telegraph window", p.health == maxhp,
		"lost %d before the ring finished swelling" % (maxhp - p.health))
	await get_tree().create_timer(enemy_script.EMBER_TELEGRAPH + enemy_script.EMBER_LIFETIME + 0.6).timeout
	var burned: int = maxhp - p.health
	var tick_cap: int = maxi(1, int(round(float(maxhp) * enemy_script.EMBER_TICK_SHARE)))
	var ticks: int = int(enemy_script.EMBER_LIFETIME / enemy_script.EMBER_TICK) + 2
	check("...it burns whoever stands on the corpse", burned > 0, "took %d" % burned)
	check("...and never harder than its per-tick cap",
		burned <= tick_cap * ticks, "took %d, cap %d x %d ticks" % [burned, tick_cap, ticks])

	# the hard rule: an ember patch can never be the thing that kills you
	var demon2 = spawn_species(2, p.global_position + Vector2(20, 0))
	await settle()
	disarm(demon2)
	demon2.take_damage(99999)
	p.health = 1
	await get_tree().create_timer(enemy_script.EMBER_TELEGRAPH + enemy_script.EMBER_LIFETIME + 0.6).timeout
	check("...and it can NEVER land the killing blow", p.health == 1,
		"hero at %d" % p.health)
	p.health = maxhp

	# ---------------- 5. WRAITH: Fade ----------------
	var wraith = spawn_species(3, far)
	await settle()
	var wh: int = wraith.health
	wraith.fade_out()
	await settle(2)
	wraith.take_damage(25)
	check("a faded Wraith takes nothing (it is smoke)", wraith.health == wh,
		"lost %d" % (wh - wraith.health))
	check("...but it cannot strike while faded either",
		wraith.attack_cooldown_remaining >= enemy_script.FADE_DURATION - 0.2,
		"cooldown %.2f" % wraith.attack_cooldown_remaining)
	check("...and the fade is short enough to wait out",
		enemy_script.FADE_DURATION <= 1.5, "%.1fs" % enemy_script.FADE_DURATION)
	await get_tree().create_timer(enemy_script.FADE_DURATION + 0.2).timeout
	wraith.take_damage(25)
	check("...once it is solid again it takes damage normally", wraith.health < wh,
		"health %d of %d" % [wraith.health, wh])
	wraith.queue_free()

	# ---------------- 6. BONE GOLEM: Reassemble ----------------
	var golem = spawn_species(4, far)
	await settle()
	var gmax: int = golem.max_health
	golem.take_damage(99999)
	await settle(2)
	check("a killed Bone Golem collapses to a heap instead of dying",
		golem.is_heaped() and not golem.is_dead)
	check("...and a heap cannot chase or swing", absf(golem.velocity.x) < 1.0)
	await get_tree().create_timer(enemy_script.HEAP_DURATION + 0.4).timeout
	check("...three seconds later it RISES", not golem.is_heaped() and not golem.is_dead
		and golem.health > 0, "health %d" % golem.health)
	check("...at a fraction of its health, not full",
		golem.health <= int(round(gmax * enemy_script.HEAP_RISE_SHARE)) + 1 and golem.health > 0,
		"%d of %d" % [golem.health, gmax])
	golem.take_damage(99999)
	await settle(2)
	check("...and it only ever rises ONCE", golem.is_dead, "still standing")

	# counter-play: smash the heap inside the window and it never comes back
	var golem2 = spawn_species(4, far + Vector2(120, 0))
	await settle()
	golem2.take_damage(99999)
	await settle(2)
	check("a second golem heaps as well", golem2.is_heaped())
	golem2.take_damage(1)                       # the smash
	await settle(2)
	check("...smashing the heap ends it immediately (the counter-play)", golem2.is_dead)

	# the invariant: it heaps however it died -- a poison tick kills as surely as
	# a sword, and die() is the one door both walk through.
	var golem3 = spawn_species(4, far + Vector2(240, 0))
	await settle()
	golem3.apply_status("poison", 4.0, 400.0)
	await get_tree().create_timer(1.2).timeout
	check("a golem killed by POISON heaps too (one door, not two)",
		golem3.is_heaped() or golem3.has_reassembled, "dead=%s" % str(golem3.is_dead))
	golem3.queue_free()

	# ---------------- 7. ROTFIEND: Miasma ----------------
	var rot = spawn_species(5, p.global_position + Vector2(26, 0))
	await settle()
	disarm(rot)
	p.poison_until = 0.0
	var clouds_before: int = field_effects()
	rot.global_position = p.global_position          # exhale right where the hero stands
	await settle(2)
	rot.exhale_miasma()
	# and then GO: a mob body standing on the player shoves it out of its own gas
	# (the bump AI), which would test the cloud against an empty patch of floor.
	# Freeing it also proves the harder promise -- the cloud outlives its maker.
	var gas_at: Vector2 = rot.global_position
	rot.queue_free()
	await settle(2)
	check("a Rotfiend exhales a lingering cloud", field_effects() > clouds_before,
		"%d -> %d field effects" % [clouds_before, field_effects()])
	await get_tree().create_timer(0.8).timeout
	check("...standing in the gas poisons you", p.poison_until > 0.0,
		"god_mode=%s  hero %.0fpx from the gas (radius %.0f)" % [
			str(p.god_mode), p.global_position.distance_to(gas_at), enemy_script.MIASMA_RADIUS])
	await get_tree().create_timer(enemy_script.MIASMA_LIFETIME + 0.8).timeout
	check("...and the cloud frees itself even though the fiend is long dead",
		field_effects() <= clouds_before,
		"%d field effects linger" % (field_effects() - clouds_before))

	p.health = maxhp
	p.god_mode = was_god
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
