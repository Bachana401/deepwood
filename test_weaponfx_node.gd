extends Node

# WEAPONFX ENGINE, Phase A (2026-07-28): every primitive the engine claims
# to handle fires clean through a dummy foe -- no missing keys, no crashes,
# damage always through take_damage. The uniqueness AUTHORING lands per
# tier; this proves the machine those tiers stand on.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

class Dummy extends Node2D:
	var health := 1000
	var max_health := 1000
	var is_dead := false
	var hits := 0
	var statuses := []
	func take_damage(n: int):
		hits += 1
		health -= n
		return true
	func apply_status(kind: String, _dur: float, _mag: float) -> void:
		statuses.append(kind)
	func apply_knockback(_sign: float, _force: float) -> void:
		pass

class FxProbe extends Node2D:
	var active_weapon_id := "wpn_fxprobe"
	var active_def := {}
	var currency := 0
	var health := 100
	var inventory = Inventory.new(4)
	var has_dash := false
	var has_double_jump := false
	func get_max_health() -> int: return 160
	func update_health_display() -> void: pass
	func update_currency_display() -> void: pass
	func gain_mana(_m: float) -> void: pass
	func add_buff(_k: String, _v: float, _d: float) -> void: pass
	func spawn_shock_ring(_at: Vector2, _r: float, _c: Color) -> void: pass

func _ready() -> void:
	await get_tree().process_frame
	var p := FxProbe.new()
	add_child(p)
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	add_child(foe)
	var other := Dummy.new()
	other.add_to_group("enemies")
	other.global_position = Vector2(60, 0)
	add_child(other)

	# ---- every handled kind fires without error and only via take_damage ----
	var broke := []
	for kind in WeaponFx.HANDLED:
		p.active_def = {"special": {"fx": {"kind": kind}}}
		WeaponFx.on_wield(p)
		WeaponFx.on_swing(p)
		var before_hp: int = p.health
		WeaponFx.on_hit(p, foe, 20, true)      # crit=true exercises crit-keyed fx
		WeaponFx.on_kill(p, foe.global_position)
		if p.health > before_hp + 50:
			broke.append(kind + " (healed absurdly)")
	check("all %d handled kinds run clean" % WeaponFx.HANDLED.size(), broke.is_empty(), ", ".join(broke))

	# ---- the ones with visible contracts ----
	p.active_def = {"special": {"fx": {"kind": "chain", "n": 1, "pct": 0.5, "range": 300.0}}}
	other.hits = 0
	WeaponFx.on_hit(p, foe, 20, false)
	check("chain leaps to a neighbour", other.hits >= 1)

	p.active_def = {"special": {"fx": {"kind": "brand", "dur": 5.0, "amp": 0.5}}}
	foe.set_meta("fx_brand_until", 0.0)   # the HANDLED sweep above branded it once
	foe.hits = 0
	WeaponFx.on_hit(p, foe, 20, false)          # brands -- pays NOTHING itself
	check("a brand never pays the hit that placed it", foe.hits == 0)
	WeaponFx.on_hit(p, foe, 20, false)          # the NEXT hit pays the mark once
	check("a branded foe pays the mark on the next hit", foe.hits == 1)

	p.active_def = {"special": {"fx": {"kind": "rend", "pct_per": 0.1, "max": 5}}}
	foe.set_meta("fx_rend", 0)
	foe.hits = 0
	WeaponFx.on_hit(p, foe, 20, false)
	WeaponFx.on_hit(p, foe, 20, false)
	check("rend deepens with stacks", int(foe.get_meta("fx_rend", 0)) == 2 and foe.hits >= 3)

	p.active_def = {"special": {"fx": {"kind": "bloodprice", "pct": 0.5, "cost": 2}}}
	var hp0: int = p.health
	WeaponFx.on_hit(p, foe, 20, false)
	check("bloodprice draws its due", p.health == hp0 - 2)

	p.active_def = {"special": {"fx": {"kind": "goldtouch", "chance": 1.0, "gold": 3}}}
	var g0: int = p.currency
	WeaponFx.on_hit(p, foe, 20, false)
	check("goldtouch mints", p.currency == g0 + 3)

	# a combo LIST runs every entry
	p.active_def = {"special": {"fx": [{"kind": "goldtouch", "chance": 1.0, "gold": 1},
		{"kind": "bulwark"}]}}
	g0 = p.currency
	WeaponFx.on_hit(p, foe, 20, false)
	check("fx combos run every entry", p.currency == g0 + 1)

	# frostbloom only blooms on a crit
	p.active_def = {"special": {"fx": {"kind": "frostbloom", "radius": 300.0}}}
	other.statuses = []
	WeaponFx.on_hit(p, foe, 20, false)
	check("frostbloom sleeps without a crit", other.statuses.is_empty())
	WeaponFx.on_hit(p, foe, 20, true)
	check("...and blooms on one", not other.statuses.is_empty())

	# ============ THE UNIQUENESS AUDIT (the dev's order, enforced) ============
	# "all these weapons skills and effects and aftereffects should be unique"
	# -- so the ROSTER is audited, not trusted. Every declared kind must be
	# HANDLED (the named-but-never-read trap), every tier at or above the
	# authored bar must CARRY an fx, and no two fx-bearing weapons may share
	# a signature (their sorted set of kinds). The bar rises as tiers land.
	# THE 221/129 MIX (dev decision): mirroring the reference game's honest
	# split -- 129 ladder rows are PLAIN ("plain": true, tiers 1-6 only, the
	# crown never plain): stat rungs upgraded by materials, NO fx. Every
	# other weapon is DISTINCT and must carry its soul. Both counts pinned.
	const PLAIN_QUOTA := 129
	var plain_n := 0
	var overdressed := []
	var unknown := []
	var bare := []
	var sigs := {}
	var dupes := []
	for row in WeaponRoster.ROWS:
		var ex: Dictionary = row[7]
		var tier: int = int(row[3])
		if bool(ex.get("plain", false)):
			plain_n += 1
			if ex.has("fx"):
				overdressed.append(str(row[0]))
			if tier >= 7:
				overdressed.append(str(row[0]) + " (crown tier gone plain)")
			continue
		if not ex.has("fx"):
			bare.append(str(row[0]))
			continue
		var fxl: Array = ex["fx"] if ex["fx"] is Array else [ex["fx"]]
		var kinds := []
		for f in fxl:
			var k := str(f.get("kind", ""))
			if not WeaponFx.HANDLED.has(k):
				unknown.append("%s:%s" % [str(row[0]), k])
			kinds.append(k)
		kinds.sort()
		var sig := ",".join(kinds)
		# COMMONS are exempt from the dupe rule by tier policy (dev-chosen):
		# a light flavored touch may share its family; T2+ must be UNIQUE
		if tier >= 2:
			if sigs.has(sig):
				dupes.append("%s == %s (%s)" % [str(row[0]), str(sigs[sig]), sig])
			sigs[sig] = str(row[0])
	check("every declared fx kind is handled by the engine", unknown.is_empty(), ", ".join(unknown))
	check("every DISTINCT weapon carries its own fx", bare.is_empty(), ", ".join(bare))
	check("no two distinct weapons share an fx signature", dupes.is_empty(), "; ".join(dupes))
	check("the plain ladder is exactly %d rungs, none dressed, none crowned" % PLAIN_QUOTA,
		plain_n == PLAIN_QUOTA and overdressed.is_empty(),
		"plain=%d; %s" % [plain_n, ", ".join(overdressed)])
	# THE SOUL MUST BE READABLE (dev: "not dumb and only plain stats"): every
	# fx-bearing weapon's CARD says what it does -- an invisible unique is
	# stats with extra steps
	var mute := []
	for row in WeaponRoster.ROWS:
		var ex2: Dictionary = row[7]
		if not ex2.has("fx"):
			continue
		var def: Dictionary = Inventory.get_item_def(str(row[0]))
		if str(def.get("unique_desc", "")).strip_edges() == "":
			mute.append(str(row[0]))
	check("every soul is written on its weapon's card", mute.is_empty(), ", ".join(mute))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
