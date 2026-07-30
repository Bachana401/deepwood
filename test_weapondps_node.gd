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
	"edict":    3.4,   # the arm is out ~0.6s, re-cutting every 0.17s (EDICT_REHIT)
	"prism":    6.0,   # six beams; at full focus all six are on one body
	"regicide": 2.4,   # the throw, plus a 5-stack ticking 22% every 0.5s
	"brazier":  3.0,   # whirl/hurl contacts plus ~17 embers over a 4.6s sit
	"sorrow":   1.4,   # one narrow lance per beat, piercing (the RATE is in
	                   # the cooldown, not here -- do not double-count it)
	"sunder":   2.8,   # THREE passes now: out, back harder, back again (GRIEF_PASSES)
	"skyfall_rain": 3.6,  # 7 arrows fall now; ~3-4 land on any one body
	"parade":   4.0,   # the lantern GRINDS through (~2), plus marchers called
	                   # on a 0.35s clock rather than only on a landed hit
	"boulder":  3.2,   # rolls THROUGH several, then SHATTERS into 6 scree shards
	# T7 batch 1 -- the aftermath family (a zone that keeps working)
	"afterlight": 3.4, # the hanging arc bites ~5x over 1.7s if they stand in it
	# a spear strikes on the lunge AND rakes on the withdraw (0.6x) -- the
	# two-stroke animation always existed; only the hit ledger blocked it
	"thrust":     1.6,
	# a burst shell throws five fragments (SHRAPNEL_N) that keep hurting
	"lob_a":      2.0,
	"lob":        2.0,
	"cleave":     1.9,   # the arc, plus the CARVE the swing now throws
	"daybreak":   3.0, # three stars fall, each bursting for the full 0.55x hit
	"anvil":      1.8, # the mass lands, then the floor CRACKS outward (0.7x ring)
	"worldthorn": 2.6, # three spikes, ~4 bites over 1.3s
	"sunspill":   2.8, # the shell, then the pool ticking ~10x over 4.2s at 30%
	# T7 batch 2
	"reckoning":  2.4, # the small hit, then the 7x bill 1.5s later
	"cometchain": 2.5, # the maul's contacts plus the crater it leaves
	"stormflock": 3.0, # NINE birds now; they still spread, but the row is thick
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
	"riftburst":  2.0, # the haul GRINDS (3 ticks x 0.35) and then the shutting
	"shardregent":2.2, # five shards, but they pick their own marks and spread
	"bentheaven": 1.5, # one arcing ray, piercing what it comes down on
	# T7 batch 6 -- the tier's last four
	"heavenstring":1.7, # the shaft, the pull, and the line SNAPPING taut (0.6x)
	"choirstring": 3.2, # 3 notes, each humming ~4x over 2.4s
	"heavenpoint": 1.6, # it RE-cuts what it is still travelling through (0.22s)
	"frost":       1.5, # the shard pierces AND re-cuts (same 0.22s rake)
	# --- the eleven wands freed from the shared ice dart (2026-07-30) ---
	"chalkline":   1.2, # a static stroke; a body crosses it about once
	"tallowdrip":  2.4, # the splat + ~2 ticks; a T1 puddle is SHORT by design
	"stubmisfire": 2.5, # RANDOM 2-4 sparks (or 1 fat x3); measured 3-4 up close
	"brookflow":   1.8, # the band re-soaks every 0.4s at 0.6x while it passes
	"sporepatch":  3.0, # the stick, then ~8 ticks at 0.25x if they hold ground
	# MEASURED 1 against a STATIONARY dummy, and that is the honest number to
	# declare. The spec's 2.4 assumes a body that keeps pushing at the boundary;
	# a real enemy walking at the player does exactly that, but nothing in the
	# probe models intent, so the audit gets the floor rather than the hope.
	# observed 1-3 across runs: a containment ring only bills a body standing AT
	# the boundary, so its output is genuinely positional. 2.0 is honest against
	# both ends rather than flattering to one.
	"saltring":    2.0, # the scatter, plus 1-3 edge-burns depending on where
	"hollowring":  1.3, # even-pierce: one body takes exactly one, on collapse
	"forktree":    2.2, # 7 segments at 0.45x; deep in the tree eats 3-4
	# MEASURED 9, which includes the POISON ticking after the thread breaks --
	# damage-over-time is real output and the probe is right to count it.
	"drinkthread": 4.0, # 4 pulls at 0.22x, then the poison keeps working
	"writglyph":   1.6, # a body under ONE glyph takes one icicle at 0.7x
	"icecoffin":   2.6, # the shut at full, then panel-splinters at 0.45x
	# --- the cleave ten: the ARC stays shared, the FOLLOW-THROUGH is the weapon
	"spadespray":  2.0, # the arc, plus 7 clods at 0.3x that spread (2 airborne)
	"hoopshunt":   1.2, # the arc and one shunt; the wall slam is the bonus
	"opengrave":   2.2, # the arc, the thrown sod, and the hole it leaves behind
	"fellblow":    2.0, # the arc, then it TIPS a beat later at 0.6x
	"reaprow":     2.4, # the arc, then the line reaps the row it runs through
	"belltoll":    2.0, # the arc plus three rings at 0.35x
	"scoresplit":  2.0, # score, then SPLIT at 1.1x on the second swing
	"endtoll":     2.1, # the arc, then the bill lands at 1.1x
	"gravehands":  2.6, # the arc, plus 5 hands at 0.4x marching away
	"stophour":    2.4, # the arc, then the stored hour pays at 1.4x
	# ---- T6 batch 1 ----
	"hushfall":    1.8, # the swing, then the late nova at 0.8x in a radius
	"eclipse":     1.7, # the disc out and back, plus one shadow band at 0.85x
	"cometfall":   2.2, # crater nova at 0.8x + the burning patch ticking 0.3x
	"debtmark":    2.4, # the hit, then 4 barbs biting and each paying out
	"cinderdrag":  2.4, # the maul's hits, and the embers BURN now (0.22x each)
	"watchfire":   4.0, # WATCH_RECOVER 1.1 -> 0.78: it flares oftener
	# ---- T6 batch 2 ----
	"horizonpike": 2.6, # three staged lengths, 1.0 / 0.84 / 0.68 down one line
	"deluge":      3.9, # re-hits across a 6.2s run now, and still pays in shove
	"lodestar":    2.3, # the strike, then the gathered crowd eats one 0.8x nova
	"secondmoon":  1.5, # ONE moon only, so a recast renews rather than stacks:
	                    # the sky adds ~half the swing's dps, it does not multiply
	"shatterhymn": 1.8, # the note, then the GLASS cuts everything near it
	"longtongue":  1.6, # pierces the row and grows, so ~2 bodies a swing
	# ---- T6 batch 3 ----
	"anviltoll":   2.7, # FOUR tolls at 0.55x, each heavier: 1.0/1.15/1.30/1.45
	"horizonrend": 1.7, # two halves on one cast, but they overlap on the row
	"silentchoir": 1.3, # 5 near-silent shafts at 0.2x, then one 1.15x*5 chord
	"sunpiece":    3.4, # ~12 sweeps at 0.5x over 3.6s, then a 0.8x nova
	"permafrost":  3.6, # 11 bites over 5s escalating 0.5x -> 1.4x, one cast
	"novaburst":   2.2, # the hit plus two delayed 0.6x novas in a radius
	# ---- T6 batch 4: the last ten ----
	"hollowwheel": 2.2, # ONE guard wheel, 3.6s of 0.22s bites; recast renews
	"direportent": 1.6, # a 0.35x prick, then the omen falls for a 0.8x nova
	"lastcourier": 2.5, # four deliveries, no decay -- but to four DIFFERENT bodies
	"griffinvolley": 2.4, # 3 birds, and each picks a DIFFERENT body
	"meteorquill": 2.6, # 5 quills, but they RAIN across a lane -- one body
	"ashherd":     3.0, # 3 clouds down the lane; a body stands in ONE of them
	"cindershelf": 1.7, # ONE ledge (recast moves it); ~10 ticks over its 4s
	"griefcollect": 3.4, # 4 stops, each heavier: 1.0 + 1.3 + 1.6 + 1.9
	"nightlash":   2.4, # the crack, then a 0.65x echo out of the dark
	"middaysun":   3.2, # seven abreast; a body catches maybe three of them
	"asphodel":    5.8, # the post sends ~12 wisps over its 9s life (POST_GAP 0.78)
	# ---- T5 batch 1 ----
	"seawall":     2.4, # a 3.2s barrier re-hitting every 0.3s at 0.6x, but it
	                    # only pays when they keep pushing into it
	"serpentsermon": 3.2, # the strike, then ~6 bites at 0.5x while coiled
	"twinburst":   2.2, # two bolts, and a crossing burst roughly every 0.42s
	"deepbeacon":  4.0, # ONE beacon (recast moves it): ~5 pulses over 6.5s
	"starfall":    2.0, # 3 stars, but they SPREAD where they land
	"worldtoll":   1.5, # a 0.35x rumble in passing, then the 0.8x eruption
	# ---- T5 batch 2 ----
	"glacierwrit": 2.8, # a drifting slab re-hitting every 0.28s as it grows
	"owlremembers": 2.7, # three passes at 1.0 / 1.45 / 1.9 on ONE body
	"quillrain":   1.8, # 2 quills a shot on a 0.16s cadence; they SPREAD
	"kingsransom": 1.0, # the seal barely stings -- it pays in GOLD, not damage
	"gallows":     1.8, # the swing, then the 0.8x drop when the floor returns
	"pilgrimscourge": 1.6, # pierces the row; the waymarks heal, they do not hurt
	# ---- T5 batch 3 ----
	"quietwheel":  3.0, # ~9 silent 0.34x bites over 2.8s, billed as one total
	"midwinterwheel": 2.4, # ONE wheel (recast renews): 0.26s bites on its circuit
	"skyquills":   2.2, # 5 quills hang and drop, but they SPREAD down the lane
	"eventide":    2.0, # 3 shafts out and back -- two tolls on a single body
	"tomeofrains": 5.0, # ~28 drops over 4.6s, one body each, wide area denial
	"wardenwatch": 4.5, # ONE post: ~6 lane shots over 9s at 1.35x, all piercing
	# ---- THE SUMMONER (batch 1) ----
	"minion":      2.4, # a standing minion strikes on its own cadence forever;
	                    # the slot budget is the real limiter, not this number
	"whipcrack":   1.0, # a modest lash -- the value is the TAG it paints
	"post":        3.0, # a permanent post firing on its own gap
	"rowsickle":   2.2, # a long slow blade re-cutting every 0.4s down the row
	# ---- T4 batch 1 ----
	"howlpiece":   2.4, # the blade plus ~5 howl rings at 0.45x down its lane
	"winterwheel": 2.0, # it rolls THROUGH, re-hitting every 0.3s, and chills
	"reaperrebuke": 2.8, # 4 stops, each heavier, then home
	"prismbreak":  1.9, # the bolt plus three 0.55x colours, which fan apart
	"cometflail":  1.8, # the maul's contacts plus the fire it sheds
	"falconoath":  1.2, # one shaft at 1.15x -- the value is the REPOSITION
	# ---- T4 batch 2 ----
	"gloamlash":   1.9, # two tines, but they bow APART -- rarely both on one
	"owlwheel":    2.6, # ONE eye (recast renews): ~7 blinks over its 3.4s
	"riverrender": 2.2, # it swells as it runs, re-hitting every 0.26s
	"smokelash":   2.4, # ~6 ticks in the pall at 0.55x if they stand in it
	"driftwheel":  2.5, # 3s of wandering, re-hitting every 0.34s
	# ---- T4 batch 3: the last ten ----
	"nightbolt":   1.2, # one bolt at 1.2x -- the value is being unreadable
	"wispwarden":  4.8, # ~12 wisps now -- it shares _tick_asphodel, whose gap
	                    # went 1.15 -> 0.78 in an earlier batch. The declaration
	                    # was never updated to match the code it points at.
	"candlekeeper": 4.6, # the keeper burns longer now (zone duration 6.2)
	"covenledger": 5.0, # ~14 ticks over 6.2s inside the ring (duration+gap)
	"gloamburst":  2.4, # the hit plus six 0.4x motes that seek
	"howlbolt":    2.6, # 4 bounces, each with a 0.45x howl ring
	"deepdebt":    2.8, # 4 bookings, each ticking and coming due
	"huntword":    2.0, # two stoops, and they pick DIFFERENT bodies
	"stormdebt":   3.8, # the bolt plus FOUR delayed beats, each heavier
	# ---- T5 batch 4: the last eleven ----
	"omenseek":    2.6, # a slow read, then every marked body eats a 1.3x nova
	"ironomen":    2.2, # 4 bounces, each planting a spike that ticks its zone
	"thirdomen":   1.8, # two 1.0x warnings then a 2.6x third, averaged
	"stormherd":   3.0, # 4 beasts running the lane; they SPREAD across it
	"kestrelcourt": 2.8, # 4 kestrels, staggered stoops, each picking a body
	"thunderhead": 2.5, # 4 bolts from a parked cloud at 0.62x
	"midnightpost": 2.4, # the IMPLOSION on the gathered pile, then one spoke out
	"sirensong":   4.6, # ~6 bites while singing plus the shut, and it GATHERS
	"starsplinter": 2.4, # 8 splinters out and back; a body catches ~3 passes
	"emberhymn":   2.8, # ~5 ticks in the column, taller the longer you sing
	"saintsreward": 2.6, # ~12 halo bites over 4s, and it pays HP back
	# ---- THE MONARCH ELEVEN: apex weapons, deliberately near the ceiling ----
	"patientknife": 3.6, # 12 knives on the storm engine, ~5 bites over 1.05s
	"kingdomturning": 3.2, # 6 crowned shades wheeling, biting every 0.2s
	"rumor":       3.0, # 1 -> 2 -> 4 across three generations, no decay
	"skymeasure":  1.4, # MEASURED 1: six columns SPREAD, a body is under one
	# MEASURED 1 at every range (test_realhits_node): the five pillars march
	# AWAY down the hall, so one body stands in exactly one of them. The old 2.4
	# was a guess that assumed a body catches two, and nothing checked.
	"unbentcolumn": 1.2, # 5 pillars down the hall; a body stands in ONE
	"choirofone":  2.6, # the shaft plus 4 harmonics at 0.8x, fanning
	"thronestrings": 3.0, # 7 strings; a body standing in the span crosses ~3
	# MEASURED 10-11 at EVERY range: the tears seek, so nearly the whole flight
	# converges on a lone body. Declared 4.0 -- this weapon was carrying more
	# than twice the output the ladder was crediting it with, which is one half
	# of the dev's "huge dps difference between weapons".
	"worldsgrief": 8.0, # 12 tears that SEEK; most of them find one body
	"skycharges":  3.4, # 8 bolts over 1.5s, half aimed at whoever is nearest
	"worldcut":    1.0, # ONE cut -- but it is the whole lane, every body once
	"deepcourt":   5.0, # 5 drowned courtiers striking on their own
	# --- pre-existing multi-hit verbs, for a fair comparison ---
	"volley":     2.0,
	"jab_volley": 3.0,
	"cluster":    2.5,
	"ricochet":   1.8,
	"lash":       2.0,
	"orbiter":    2.5,
	"chain_maul": 2.0,
	"crescent":   1.6,   # the swing AND the thrown crescent
	"tome":       4.2,   # a zone that ticks -- strike_gap 0.4 -> 0.28, a downpour
	"sentry":     4.1,   # fire_gap 0.85 -> 0.62
	# a homing shaft SPLITS on impact into two lesser seekers (arrow.split_gen)
	"seeker":     1.6,
	"paleseek":   2.2, # the shaft, plus a child that returns to a lone body
	"haleseek":   1.8, # even-pierce through 2; NO split -- that is the Pale one
	"souls":      3.9,   # SEVEN homing souls at 0.55x (the verb it never had)
	# MEASURED, not estimated (test_realhits_node, 2026-07-30): 8 hits at 90px,
	# 5 at 170px, 0 at 280px. 6.0 is the honest middle of its useful band. The
	# old 4.0 was a guess made when the blades rode one thin ring and actually
	# landed one or two -- the number flattered a weapon the dev called weak.
	"zenith":     6.0, # THE STORM: 12 blades on staggered radii over 1.15s,
	"ink":        3.4,   # the stream SLOWS as it falls, so its 0.22s re-cut lands
	                     # -- and at 55% speed it FORKS into three, each raking
	                     # (2.2 for the parent, plus two children at 0.6 damage)
	"wake":       2.8,   # the scythe wakes, cuts, and RETURNS through the row
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
		# A PERSISTENT SUMMON IS NOT A SWING. For every other weapon the
		# cooldown is how fast you attack, so dmg/cd is its rate. For a scepter
		# or a totem the cooldown is only how fast you can CAST -- the thing
		# you bought then attacks forever on its own cadence. Running them
		# through the swing model read The Clinging Choir as a dud and dragged
		# the whole T8 median down far enough to trip The Patient Knife.
		var ex_row: Dictionary = row[7]
		var eff: float = 0.0
		if behavior == "minion":
			eff = dmg / maxf(0.3, float(ex_row.get("m_gap", 1.8)))
		elif behavior == "post":
			eff = dmg / maxf(0.3, float(ex_row.get("p_gap", 1.1)))
		else:
			eff = (dmg / cd) * hits_for(behavior)
		# SUMMONS ARE THEIR OWN ECONOMY and must not share a band with swings.
		# One minion sustains ~16 dps while a crown sword bursts ~250; mixing
		# them dragged the T8 median down until The Patient Knife looked like a
		# runaway, and made every T1 minion look like a dud. A summoner's real
		# output is minions x slots + whip, which no per-weapon audit can see --
		# so the two families are measured against themselves.
		# A WHIP IS A THIRD ECONOMY. Its own damage is deliberately small -- the
		# power is the TAG it paints, which every minion then cashes in. Scored
		# against swords, all nine whips read as the weakest weapons at their
		# rung; scored against each other, the ladder is honest. Same reasoning
		# as summons, one line below.
		var fam: String = "swing"
		if behavior in ["minion", "post"]:
			fam = "summon"
		elif behavior == "whipcrack":
			fam = "whip"
		rows[id] = {"name": str(row[1]), "tier": tier, "behavior": behavior,
			"dmg": dmg, "cd": cd, "eff": eff, "fam": fam}
		var bucket: String = "%s%d" % [fam, tier]
		if not by_tier.has(bucket):
			by_tier[bucket] = []
		by_tier[bucket].append(eff)

	# --- report the bands so a human can eyeball the curve ---
	var buckets := by_tier.keys()
	buckets.sort()
	var medians := {}
	for t in buckets:
		var arr: Array = by_tier[t]
		arr.sort()
		var med: float = arr[arr.size() / 2]
		medians[t] = med
		say("  %-9s n=%2d   min %6.1f   median %6.1f   max %6.1f   SPREAD %.1fx"
			% [t, arr.size(), arr[0], med, arr[arr.size() - 1],
				arr[arr.size() - 1] / maxf(0.1, arr[0])])

	# DPS_DETAIL=1 names every weapon in a tier, weakest first. The band summary
	# above hides the thing that matters: which specific weapons are the dead
	# ones. (dev, 2026-07-30: "some are pretty weak, some are really useless")
	if OS.get_environment("DPS_DETAIL") == "1":
		for want_t in range(8, 0, -1):
			var rows_t := []
			for r0 in rows.values():      # rows is keyed by id -- take the records
				if int((r0 as Dictionary)["tier"]) == want_t:
					rows_t.append(r0)
			if rows_t.is_empty():
				continue
			rows_t.sort_custom(func(a, b): return float(a["eff"]) < float(b["eff"]))
			say("\n--- TIER %d (%s), %d weapons, weakest first ---"
				% [want_t, str(WeaponRoster.TIER_GRADE[want_t]), rows_t.size()])
			for r1 in rows_t:
				# COMPARE INSIDE THE FAMILY. Judging a summon against the swing
				# median called the four Monarch summons the weakest weapons in
				# the game when they sit dead-centre of their own band -- a
				# scepter's number is sustained, a sword's is burst.
				var fam_med: float = float(medians.get(
					"%s%d" % [str(r1["fam"]), want_t], 0.0))
				var ratio: float = (float(r1["eff"]) / fam_med) if fam_med > 0.0 else 1.0
				var flag := ""
				if ratio < 0.5:
					flag = "<-- %.2fx its %s median" % [ratio, str(r1["fam"])]
				say("   %7.1f dps  %-28s %-14s %s"
					% [float(r1["eff"]), str(r1["name"]), str(r1["behavior"]), flag])

	# --- 1. each family's ladder must ASCEND on its own ---
	var ascending := true
	var broke := ""
	for fam2 in ["swing", "summon", "whip"]:
		var last := -1.0
		for t2 in range(1, 9):
			var key2: String = "%s%d" % [fam2, t2]
			if not medians.has(key2):
				continue
			var m2: float = float(medians[key2])
			if last >= 0.0 and m2 <= last:
				ascending = false
				broke = "%s (%.1f) <= the tier below (%.1f)" % [key2, m2, last]
			last = m2
	check("effective dps ascends tier by tier, within each family", ascending, broke)

	# --- 2. no weapon may run away from its own tier ---
	# A wide net on purpose: verbs SHOULD differ, and a spectacle weapon is
	# allowed to be the best in its tier. Past the ceiling, one weapon stops
	# being a choice and becomes the only answer.
	#
	# MONARCH IS DELIBERATELY WIDER. The dev's direction for tier 8 is that it
	# should feel overwhelming -- "crazy op", Zenith-scale -- with the power in
	# the VERB rather than in stat riders. A 3.2x ceiling was written before
	# that call and was pulling the apex tier back toward the middle. What this
	# check is really for is catching ACCIDENTS (it caught Second Moon and
	# Cindershelf stacking themselves to 3-4x their tier through a lifetime
	# longer than their cooldown), and an accident still shows up against 4.6x.
	var runaways := []
	for id in rows:
		var r: Dictionary = rows[id]
		var med: float = float(medians.get("%s%d" % [r["fam"], r["tier"]], 0.0))
		var ceiling: float = 4.6 if int(r["tier"]) == 8 else 3.2
		if med > 0.0 and r["eff"] > med * ceiling:
			runaways.append("%s T%d %s: %.0f dps vs T%d median %.0f (ceiling %.1fx)"
				% [r["name"], r["tier"], r["behavior"], r["eff"], r["tier"], med, ceiling])
	check("no weapon runs away from its tier (3.2x, monarch 4.6x)",
		runaways.is_empty(), "; ".join(runaways))

	# --- THE LADDER LAW -----------------------------------------------------
	# NO WEAPON MAY LOSE TO THE TIER BENEATH IT (dev, 2026-07-30, after playing
	# the monarch chest: "some are pretty weak, some are really useless").
	#
	# The old floor -- 0.3x your OWN tier's median -- is what let this through.
	# At Monarch it permits anything above 26.6 dps, so `Grief Wears a Crown`
	# sat at 30.9 and passed, while being beaten by the TIER 3 RARE median
	# (29.1) and losing to the Tier-5 Legendary median (57.1) by nearly half.
	# A gold weapon that only drops on floor 88 was worse than a blue one from
	# floor 12, and the audit called it fine.
	#
	# A floor measured against your own tier can never catch this: if a whole
	# tier sags, its median sags with it and everything still "passes". The
	# floor has to be anchored to the tier BELOW. Rarity is a promise that the
	# next rung is better; this is that promise, written down.
	# THE ONE EXEMPTION, AND ITS RULE. A weapon may sit under the ladder only if
	# its payoff is explicitly NOT damage and something else in the repo pays
	# it. King's Ransom brands a foe and pays GOLD when they die still wearing
	# it (embedded_stack.gd, ransom_gold) -- buffing it to clear a dps floor
	# would delete the only weapon in the game that trades damage for money.
	# The bar for joining this list is a real, readable, non-damage payoff.
	var PAYS_ELSEWHERE := {
		"kingsransom": "pays in GOLD on death, not damage (embedded_stack ransom_gold)",
	}
	for b3 in PAYS_ELSEWHERE:
		var stack_src := FileAccess.get_file_as_string("res://embedded_stack.gd")
		check("the '%s' exemption is still paid for somewhere" % b3,
			stack_src.contains("ransom"), "nothing pays it -- the exemption is now a hole")

	var LADDER_FLOOR := 0.85     # you may be a weak Monarch, never a good Ascended
	var regressions := []
	for id3 in rows:
		var r3: Dictionary = rows[id3]
		var t3: int = int(r3["tier"])
		if t3 <= 1 or PAYS_ELSEWHERE.has(str(r3["behavior"])):
			continue
		var below: float = float(medians.get("%s%d" % [r3["fam"], t3 - 1], 0.0))
		if below <= 0.0:
			continue
		if float(r3["eff"]) < below * LADDER_FLOOR:
			regressions.append("%s (T%d %s, %s) %.0f dps < T%d median %.0f"
				% [r3["name"], t3, str(WeaponRoster.TIER_GRADE[t3]), r3["behavior"],
					r3["eff"], t3 - 1, below])
	regressions.sort()
	check("no weapon is weaker than the tier below it (%d violations)"
		% regressions.size(), regressions.is_empty(),
		"\n        " + "\n        ".join(regressions))

	# --- 3. nor may it be so weak it is a trap pick ---
	var duds := []
	for id in rows:
		var r: Dictionary = rows[id]
		var med: float = float(medians.get("%s%d" % [r["fam"], r["tier"]], 0.0))
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
