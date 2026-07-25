extends Node

# THE TEN, IN CHARACTER (ten_ally.gd) -- each legend's Harvest combat kit echoes
# the village boon their rescue granted. This pins the distinct behaviours:
# Brannoc/Kaldos cleave, Toren knocks back, Sylvara roots, Elenwe/Dorian strike
# from range, Dorian mints gold on the kill, Maera heals the player, Seraphel
# slows the turned, Mirielle rallies and Ilo's song sharpens nearby legends.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

# A minimal stand-in for a transformed foe: records what a legend did to it.
class Dummy extends Node2D:
	var is_dead := false
	var hp := 100000
	var kb_dir := 0
	var kb_dist := 0.0
	var slow_factor := 1.0
	var slow_dur := 0.0
	func take_damage(a: int) -> void:
		hp -= a
		if hp <= 0: is_dead = true
	func apply_knockback(d: int, dist: float) -> void:
		kb_dir = d; kb_dist = dist
	func apply_status(kind: String, dur: float, mag: float = 0.0) -> void:
		if kind == "slow":
			slow_factor = mag; slow_dur = dur

func _mk_ally(host: Node, id: String) -> Node:
	var a = load("res://ten_ally.gd").new()
	a.ten_id = id
	host.add_child(a)   # _ready runs here, resolving the kit
	return a

func _mk_dummy(host: Node, at: Vector2, hp := 100000) -> Dummy:
	var d := Dummy.new()
	d.hp = hp
	d.add_to_group("transformed")
	host.add_child(d)
	d.global_position = at
	return d

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return

	var host := Node2D.new()
	get_tree().current_scene.add_child(host)
	host.global_position = Vector2(0, 0)

	# ---- every legend resolves a DISTINCT kit (no two share one profile) ----
	var seen := {}
	var distinct := true
	for id in TheTen.ids():
		var a = _mk_ally(host, id)
		var sig := "%s|%d|%.1f|%.1f|%s|%.0f|%s|%.0f" % [
			str(a.kit.mode), int(a.kit.damage), float(a.kit.cooldown), float(a.kit.hp_mult),
			str(a.kit.aura), float(a.kit.kb), str(a.kit.slow != null), float(a.kit.gold)]
		if seen.has(sig): distinct = false
		seen[sig] = id
		a.queue_free()
	check("all ten legends carry a distinct combat kit", distinct and seen.size() == 10)

	# ---- Roland (no ten_id) falls back to the default steel kit ----
	var roland = _mk_ally(host, "")
	roland.override_name = "Roland"
	check("Roland (no legend id) gets the default kit",
		str(roland.kit.mode) == "single" and int(roland.kit.damage) == 60)
	roland.queue_free()

	# ---- Brannoc & Kaldos CLEAVE: one swing hits every foe in reach ----
	var brannoc = _mk_ally(host, "ten_brannoc")
	brannoc.global_position = Vector2(0, 0)
	var reach: float = float(brannoc.kit.reach)
	var d1 := _mk_dummy(host, Vector2(reach * 0.5, 0))
	var d2 := _mk_dummy(host, Vector2(reach * 0.8, 0))
	var d3 := _mk_dummy(host, Vector2(reach + 300.0, 0))   # out of reach
	brannoc._attack(d1, Time.get_ticks_msec() / 1000.0)
	check("Brannoc cleaves ALL foes in reach, and only those",
		d1.hp < 100000 and d2.hp < 100000 and d3.hp == 100000)
	check("the Wall's blow shoves what it hits (knockback)", d1.kb_dist > 0.0)
	brannoc.queue_free(); d1.queue_free(); d2.queue_free(); d3.queue_free()

	# ---- Toren HAMMER: a single heavy blow with big knockback ----
	var toren = _mk_ally(host, "ten_toren")
	toren.global_position = Vector2(0, 0)
	var td := _mk_dummy(host, Vector2(40, 0))
	toren._hit(td, int(toren.kit.damage))
	check("Toren's hammer lands and hurls the body back",
		td.hp < 100000 and td.kb_dir == 1 and td.kb_dist >= 160.0)
	toren.queue_free(); td.queue_free()

	# ---- Sylvara ROOTS: her strike slows what it hits ----
	var sylvara = _mk_ally(host, "ten_sylvara")
	sylvara.global_position = Vector2(0, 0)
	var sd := _mk_dummy(host, Vector2(40, 0))
	sylvara._hit(sd, 10)
	check("Sylvara's roots drag the struck foe to a crawl",
		sd.slow_factor <= 0.4 and sd.slow_dur > 0.0)
	sylvara.queue_free(); sd.queue_free()

	# ---- Elenwe & Dorian RANGED: they strike from well beyond melee ----
	var elenwe = _mk_ally(host, "ten_elenwe")
	var dorian_kit_reach := 0.0
	check("Elenwe strikes from arcane range (far past melee)", float(elenwe.kit.reach) >= 200.0)
	elenwe.queue_free()

	# ---- Dorian mints gold into the player's purse on a KILL ----
	var dorian = _mk_ally(host, "ten_dorian")
	dorian.global_position = Vector2(0, 0)
	dorian_kit_reach = float(dorian.kit.reach)
	var gold_before: int = p.currency
	var dd := _mk_dummy(host, Vector2(40, 0), 5)   # dies to the hit
	dorian._hit(dd, 9999)
	check("Dorian strikes from range", dorian_kit_reach >= 200.0)
	check("the Coinbinder's kill mints gold into your purse",
		dd.is_dead and p.currency == gold_before + int(dorian.kit.gold))
	# ...but only on a KILL, never on a mere hit
	gold_before = p.currency
	var dd2 := _mk_dummy(host, Vector2(40, 0), 100000)
	dorian._hit(dd2, 10)
	check("no gold for a glancing blow -- only the kill pays",
		not dd2.is_dead and p.currency == gold_before)
	dorian.queue_free(); dd.queue_free(); dd2.queue_free()

	# ---- Maera HEALS the wounded player standing near her ----
	var maera = _mk_ally(host, "ten_maera")
	maera.global_position = p.global_position   # within her aura
	var maxh: int = p.get_max_health()
	p.health = maxi(1, maxh - 60)
	var hp_before: int = p.health
	maera._tick_aura()
	check("Maera's light knits the near, wounded player back up",
		p.health > hp_before and p.health <= maxh)
	# ...and never overheals past the cap
	p.health = maxh
	maera._tick_aura()
	check("her mending never spills past full health", p.health == maxh)
	maera.queue_free()

	# ---- Seraphel SLOWS every turned foe in her light ----
	var seraphel = _mk_ally(host, "ten_seraphel")
	seraphel.global_position = Vector2(0, 0)
	var near := _mk_dummy(host, Vector2(float(seraphel.kit.aura_range) * 0.5, 0))
	var far := _mk_dummy(host, Vector2(float(seraphel.kit.aura_range) + 300.0, 0))
	seraphel._tick_aura()
	check("Seraphel's radiance slows the near turned, not the far",
		near.slow_factor < 1.0 and far.slow_factor == 1.0)
	seraphel.queue_free(); near.queue_free(); far.queue_free()

	# ---- Mirielle RALLIES nearby legends (faster swings) ----
	var mirielle = _mk_ally(host, "ten_mirielle")
	mirielle.global_position = Vector2(0, 0)
	var buddy = _mk_ally(host, "ten_toren")
	buddy.global_position = Vector2(50, 0)
	var now := Time.get_ticks_msec() / 1000.0
	mirielle._tick_aura()
	check("Mirielle's command quickens a legend at her side",
		buddy._rally_until > now
		and mirielle._effective_cooldown(Time.get_ticks_msec() / 1000.0) < float(mirielle.kit.cooldown))
	mirielle.queue_free()

	# ---- Ilo's SONG sharpens nearby legends (harder hits) ----
	var ilo = _mk_ally(host, "ten_ilo")
	ilo.global_position = Vector2(0, 0)
	buddy.global_position = Vector2(50, 0)
	var now2 := Time.get_ticks_msec() / 1000.0
	ilo._tick_aura()
	check("Ilo's song lends the legend beside him a harder edge", buddy._song_until > now2)
	ilo.queue_free(); buddy.queue_free()

	# ---- the unbreakable rule still holds for every kit ----
	var unbroken = _mk_ally(host, "ten_sylvara")
	host.add_child(unbroken) if unbroken.get_parent() == null else null
	unbroken.take_damage(9999999)
	check("a legend beaten to nothing falls back, never dies",
		is_instance_valid(unbroken) and unbroken._fallback_until > 0.0)
	unbroken.queue_free()

	host.queue_free()
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
