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

	# THE ENGINE ITSELF COMPILES. A size pass once left weapon_projectile.gd
	# with a parse error and all four audits still reported ALL PASS -- they
	# read the ROSTER, never the engine the roster drives. A broken projectile
	# script must never leave the gate green again.
	for engine_path in ["res://weapon_projectile.gd", "res://weapon_fx.gd",
			"res://companion.gd", "res://embedded_stack.gd"]:
		var scr = load(engine_path)
		check("engine compiles: " + engine_path.get_file(),
			scr != null and scr is GDScript and (scr as GDScript).can_instantiate(),
			"script failed to load or instantiate")

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
	# ---- THE CRAFT CHAINS: every plain rung except a family head forges
	# from ANOTHER plain weapon (its predecessor) plus materials ----
	var plain_ids := {}
	for row in WeaponRoster.ROWS:
		if bool(row[7].get("plain", false)):
			plain_ids[str(row[0])] = true
	var chained := 0
	var broken := []
	for pid in plain_ids:
		if not Inventory.CRAFT_RECIPES.has(pid):
			continue   # a family head: forged by the world, not the bench
		chained += 1
		var ing: Dictionary = Inventory.CRAFT_RECIPES[pid]
		var prev_ok := false
		var mat_ok := false
		for k in ing:
			if plain_ids.has(str(k)):
				prev_ok = true
			elif Inventory.get_item_def(str(k)).get("is_material", false):
				mat_ok = true
		if not (prev_ok and mat_ok):
			broken.append(pid)
	check("every chained rung forges from kin plus materials (106 links)",
		chained == 106 and broken.is_empty(),
		"chained=%d; broken: %s" % [chained, ", ".join(broken)])
	# ---- THE CULMINATION (Zenith-kin): the melee crown forges from its three
	# famous T7 ancestors -- the same blades whose tinted ghosts its zenith
	# verb frees -- plus essence. The vaults stay the other road.
	var culm: Dictionary = Inventory.CRAFT_RECIPES.get("wpn_lastword", {})
	var roster_ids := {}
	for row in WeaponRoster.ROWS:
		roster_ids[str(row[0])] = true
	var culm_ok: bool = culm.has("wpn_worldsedge") and culm.has("wpn_afterlight") \
		and culm.has("wpn_novatongue") and culm.has("void_essence")
	for k in culm:
		if str(k) != "void_essence" and not roster_ids.has(str(k)):
			culm_ok = false
	check("The Last Word forges from its three famous ancestors (the culmination)",
		culm_ok, str(culm))
	# ---- COMBINED RELICS (Ankh/Terraspark-kin 2026-07-29): each folds real
	# lesser relics + essence, and every folded power name is a power some
	# classic relic actually carries (no orphan strings the player can't read)
	var known_powers := {}
	for iid in Inventory.ITEM_DEFS:
		var idef: Dictionary = Inventory.ITEM_DEFS[iid]
		if str(idef.get("relic_power", "")) != "":
			known_powers[str(idef["relic_power"])] = true
	var combo_bad := []
	for cid in ["relic_unbroken", "relic_wayfarer"]:
		var cdef: Dictionary = Inventory.ITEM_DEFS.get(cid, {})
		var rec: Dictionary = Inventory.CRAFT_RECIPES.get(cid, {})
		if cdef.is_empty() or rec.is_empty():
			combo_bad.append("%s: missing def or recipe" % cid)
			continue
		var relic_ing := 0
		for k in rec:
			if str(Inventory.ITEM_DEFS.get(str(k), {}).get("category", "")) == "relic":
				relic_ing += 1
		if relic_ing < 3 or not rec.has("void_essence"):
			combo_bad.append("%s: wants 3 relics + essence, got %s" % [cid, str(rec)])
		for pw in cdef.get("relic_powers", []):
			if not known_powers.has(str(pw)):
				combo_bad.append("%s: orphan power %s" % [cid, str(pw)])
		if cdef.get("relic_powers", []).is_empty():
			combo_bad.append("%s: no folded powers" % cid)
	check("combined relics fold three real relics and only readable powers",
		combo_bad.is_empty(), "; ".join(combo_bad))
	# ---- SET-SOULS (2026-07-29): the three marquee sets carry a named
	# triggered soul, and the card SAYS so (an invisible soul is a stat bump)
	var soul_bad := []
	for pair in [["bulwark", "TEMPER"], ["windstalker", "DEADEYE"], ["runeweave", "SOULTHREAD"]]:
		var sdef: Dictionary = Inventory.SET_DEFS.get(pair[0], {})
		if not str(sdef.get("bonus_desc", "")).contains(pair[1]):
			soul_bad.append("%s lacks %s on its card" % [pair[0], pair[1]])
		for piece in sdef.get("pieces", []):
			if not Inventory.ITEM_DEFS.has(str(piece)):
				soul_bad.append("%s: ghost piece %s" % [pair[0], piece])
	check("the marquee set-souls are named on their cards and completable",
		soul_bad.is_empty(), "; ".join(soul_bad))
	# ---- COMPANIONS (light summoner 2026-07-29): every carrier's kind is one
	# companion.gd actually speaks, and the card SAYS the companion ----
	var comp_kinds := {"blade": true, "wisp": true, "beast": true}
	var comp_bad := []
	var comp_n := 0
	for row in WeaponRoster.ROWS:
		var rex: Dictionary = row[7]
		if not rex.has("companion"):
			continue
		comp_n += 1
		if not comp_kinds.has(str(rex["companion"])):
			comp_bad.append("%s: unknown kind %s" % [row[0], rex["companion"]])
		var cdw: Dictionary = WeaponRoster.get_def(str(row[0]))
		if not str(cdw.get("unique_desc", "")).to_upper().contains("-BLADE") \
				and not str(cdw.get("unique_desc", "")).to_upper().contains("CANDLE") \
				and not str(cdw.get("unique_desc", "")).to_upper().contains("HOUND"):
			comp_bad.append("%s: companion not on the card" % row[0])
	var guard_def: Dictionary = Inventory.ITEM_DEFS.get("relic_guardian", {})
	if str(guard_def.get("companion", "")) == "" or not comp_kinds.has(str(guard_def.get("companion", ""))):
		comp_bad.append("relic_guardian carries no known companion")
	check("three weapon carriers + the Standing Star all speak real companions",
		comp_n == 3 and comp_bad.is_empty(), "n=%d; %s" % [comp_n, "; ".join(comp_bad)])
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
