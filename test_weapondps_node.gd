extends Node

# WEAPON DPS AUDIT (weapon overhaul, 2026-07-29).
#
# WHY THIS EXISTS: the roster declares ONE damage number per weapon, but the
# overhaul's verbs land MANY hits per use -- the Court sends four shades, the
# Sun pours six beams, Regicide throws AND ticks a five-stack. Nothing in the
# repo measured that. tool_balance_sim.gd is a VILLAGE ECONOMY sim (food,
# wages, morale, sieges); it never touches weapon damage, so "balance sim
# green" says nothing about whether a verb is ten times overtuned.
#
# This audit computes EFFECTIVE dps -- nominal dps times an honestly declared
# hits-per-use factor -- and holds every weapon against its own tier's band.
# It is deliberately a WIDE net: verbs are supposed to differ. It only fires
# when something is so far out of band that it would trivialise its tier.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)
func say(t: String) -> void: printerr(t)

# HITS PER USE, declared per behavior and justified. A factor of 1.0 means
# "one damage instance per activation" (a plain swing). Anything above 1.0 is
# a verb that multiplies, and the number is the honest estimate of how many
# damage instances ONE activation puts on ONE body (not on the whole room --
# crowd damage is a feature, not a balance problem).
const HITS_PER_USE := {
	# --- the overhaul's new verbs (each measured against its own code) ---
	"court":    2.0,   # 4 shades, but they SPREAD one per body; ~2 cross any
	                   # single target on the sweep (weapon_projectile courtier)
	"edict":    2.7,   # the arm is out ~0.6s and re-cuts every 0.22s (EDICT_REHIT)
	"prism":    6.0,   # six beams; at full focus all six are on one body
	"regicide": 2.4,   # the throw, plus a 5-stack ticking 22% every 0.5s
	"brazier":  2.2,   # whirl/hurl contacts plus ~7 embers at 45% over the sit
	"sorrow":   1.4,   # one narrow lance per beat, piercing (the RATE is in
	                   # the cooldown, not here -- do not double-count it)
	"sunder":   1.0,   # one front, one pass, each body taken exactly once
	"skyfall_rain": 2.0,  # 3 arrows fall; ~2 land on any one body
	"parade":   1.8,   # the arrow, plus the marcher it calls
	"boulder":  1.6,   # it rolls THROUGH several, and its bite scales with pace
	# T7 batch 1 -- the aftermath family (a zone that keeps working)
	"afterlight": 3.4, # the hanging arc bites ~5x over 1.7s if they stand in it
	"anvil":      1.0, # one mass, one landing
	"worldthorn": 2.6, # three spikes, ~4 bites over 1.3s
	"sunspill":   2.8, # the shell, then the pool ticking ~10x over 4.2s at 30%
	# T7 batch 2
	"reckoning":  2.4, # the small hit, then the 7x bill 1.5s later
	"cometchain": 2.5, # the maul's contacts plus the crater it leaves
	"stormflock": 2.0, # several birds, but they SPREAD across the row
	"dawnline":   1.0, # the bar climbs past each body exactly once
	# T7 batch 3 -- the remaining melee
	"worldedge":  1.8, # the swing AND a widening crescent that pierces
	"risingwheel":3.0, # ~7 bites over its 2.1s climb if they stay under it
	"nova":       2.6, # both lash passes plus the detonation at the turn
	"hush":       2.4, # both passes plus the still place it leaves
	# T7 batch 4
	"commandment":1.6, # eight plain shafts, then one 4.2x ruling that pierces
	"skypillar":  3.0, # ~5 bites over 1.5s on anything inside the column
	"finaldebt":  2.6, # the chain, plus each booked mark coming due
	# T7 batch 5 -- the wands and the bent staff
	"riftburst":  1.0, # the haul is control; the SHUTTING is the one hit
	"shardregent":2.2, # five shards, but they pick their own marks and spread
	"bentheaven": 1.5, # one arcing ray, piercing what it comes down on
	# T7 batch 6 -- the tier's last four
	"heavenstring":1.2, # one shaft, one pull; the value is the reposition
	"choirstring": 3.2, # 3 notes, each humming ~4x over 2.4s
	"heavenpoint": 1.0, # even-pierce: same wound to each, one pass
	# ---- T6 batch 1 ----
	"hushfall":    1.8, # the swing, then the late nova at 0.8x in a radius
	"eclipse":     1.7, # the disc out and back, plus one shadow band at 0.85x
	"cometfall":   2.2, # crater nova at 0.8x + the burning patch ticking 0.3x
	"debtmark":    2.4, # the hit, then 4 barbs biting and each paying out
	"cinderdrag":  1.5, # the maul's own hits; the embers are theatre, not dps
	"watchfire":   3.0, # ~3 flares across 11s if something stays in the light
	# ---- T6 batch 2 ----
	"horizonpike": 2.6, # three staged lengths, 1.0 / 0.84 / 0.68 down one line
	"deluge":      2.0, # re-hits every 0.2s across a 1.5s run, but pays in shove
	"lodestar":    2.3, # the strike, then the gathered crowd eats one 0.8x nova
	"secondmoon":  1.5, # ONE moon only, so a recast renews rather than stacks:
	                    # the sky adds ~half the swing's dps, it does not multiply
	"shatterhymn": 1.0, # one note; the splinters are theatre, not damage
	"longtongue":  1.6, # pierces the row and grows, so ~2 bodies a swing
	# ---- T6 batch 3 ----
	"anviltoll":   1.3, # three tolls at 0.55x, each fainter: 0.55+0.40+0.28
	"horizonrend": 1.7, # two halves on one cast, but they overlap on the row
	"silentchoir": 1.3, # 5 near-silent shafts at 0.2x, then one 1.15x*5 chord
	"sunpiece":    3.4, # ~12 sweeps at 0.5x over 3.6s, then a 0.8x nova
	"permafrost":  3.6, # 11 bites over 5s escalating 0.5x -> 1.4x, one cast
	"novaburst":   2.2, # the hit plus two delayed 0.6x novas in a radius
	"asphodel":    4.0, # the post sends ~8 wisps over its 9s life
	# --- pre-existing multi-hit verbs, for a fair comparison ---
	"volley":     2.0,
	"jab_volley": 3.0,
	"cluster":    2.5,
	"ricochet":   1.8,
	"lash":       2.0,
	"orbiter":    2.5,
	"chain_maul": 2.0,
	"crescent":   1.6,   # the swing AND the thrown crescent
	"tome":       3.0,   # a zone that ticks
	"sentry":     3.0,
	"souls":      3.0,
	"zenith":     1.8,
	"ink":        1.4,
	"wake":       1.4,
}

func hits_for(behavior: String) -> float:
	return float(HITS_PER_USE.get(behavior, 1.0))

func _ready() -> void:
	await get_tree().process_frame
	say("=== WEAPON DPS AUDIT ===")
	# effective dps per weapon, bucketed by tier
	var by_tier := {}
	var rows := {}
	for row in WeaponRoster.ROWS:
		var id := str(row[0])
		var tier := int(row[3])
		var behavior := str(row[4])
		var dmg := float(row[5])
		var cd := maxf(0.05, float(row[6]))
		var eff: float = (dmg / cd) * hits_for(behavior)
		rows[id] = {"name": str(row[1]), "tier": tier, "behavior": behavior,
			"dmg": dmg, "cd": cd, "eff": eff}
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(eff)

	# --- report the bands so a human can eyeball the curve ---
	var tiers := by_tier.keys()
	tiers.sort()
	var medians := {}
	for t in tiers:
		var arr: Array = by_tier[t]
		arr.sort()
		var med: float = arr[arr.size() / 2]
		medians[t] = med
		say("  T%d  n=%2d   min %6.1f   median %6.1f   max %6.1f"
			% [t, arr.size(), arr[0], med, arr[arr.size() - 1]])

	# --- 1. the ladder must ASCEND: a tier's median beats the one below ---
	var ascending := true
	var broke := ""
	for i in range(1, tiers.size()):
		if float(medians[tiers[i]]) <= float(medians[tiers[i - 1]]):
			ascending = false
			broke = "T%d (%.1f) <= T%d (%.1f)" % [tiers[i], medians[tiers[i]],
				tiers[i - 1], medians[tiers[i - 1]]]
	check("effective dps ascends tier by tier", ascending, broke)

	# --- 2. no weapon may run away from its own tier ---
	# A wide net on purpose: verbs SHOULD differ, and a spectacle weapon is
	# allowed to be the best in its tier. 3.2x the tier median is the point
	# where one weapon stops being a choice and becomes the only answer.
	var runaways := []
	for id in rows:
		var r: Dictionary = rows[id]
		var med: float = float(medians[r["tier"]])
		if med > 0.0 and r["eff"] > med * 3.2:
			runaways.append("%s T%d %s: %.0f dps vs T%d median %.0f"
				% [r["name"], r["tier"], r["behavior"], r["eff"], r["tier"], med])
	check("no weapon exceeds 3.2x its tier median", runaways.is_empty(),
		"; ".join(runaways))

	# --- 3. nor may it be so weak it is a trap pick ---
	var duds := []
	for id in rows:
		var r: Dictionary = rows[id]
		var med: float = float(medians[r["tier"]])
		if med > 0.0 and r["eff"] < med * 0.3:
			duds.append("%s T%d %s: %.0f dps vs T%d median %.0f"
				% [r["name"], r["tier"], r["behavior"], r["eff"], r["tier"], med])
	check("no weapon falls below 0.3x its tier median", duds.is_empty(),
		"; ".join(duds))

	# --- 4. every NEW overhaul verb must be declared here, so a future verb
	# cannot slip in unmeasured (the whole failure this audit exists to fix) ---
	var undeclared := []
	for row in WeaponRoster.ROWS:
		var b := str(row[4])
		var known: bool = HITS_PER_USE.has(b) or b in ["arc", "thrust", "shot",
			"rapid", "cleave", "staff", "bolt", "fire", "frost", "seeker",
			"lob", "lob_a", "hook", "boomerang", "slash"]
		if not known and not undeclared.has(b):
			undeclared.append(b)
	check("every behavior has a declared hits-per-use", undeclared.is_empty(),
		"undeclared: " + ", ".join(undeclared))

	say("RESULT: %s" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)
