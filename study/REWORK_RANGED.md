# REWORK — THE RANGED DUPLICATES (27 weapons, 27 verbs)

**Scope.** Five projectile engines in `weapon_roster._special_for()` are shared
by 27 weapons that therefore look identical in play:

| special type | weapons | what the player currently sees |
|---|---|---|
| `ricochet` | 7 | one bouncing dart, damage ×0.85 per leap, snap-turn to nearest within 340px |
| `javelin_volley` | 7 | one fan of identical spectral spears, spread 10° |
| `multi_shot` | 6 | `arrow.tscn` × N, spread 12°, no dispatch branch at all |
| `homing` | 3 | a **flag** on an ordinary shaft (`arrow.homing = true`) |
| `fireball` | 4 | one orange orb, `explode()` + 5 shrapnel |

This document replaces all 27 with distinct verbs. Nothing here is a stat
change. No weapon is renamed — every verb is derived from the name and the
material the weapon already claims to be.

Source read: `weapon_roster.gd` (ROWS + `_special_for` + `_desc_for`),
`weapon_projectile.gd` (8407 lines: `_ready()` dispatch, `_physics_process`,
`_on_body_entered`, the `_art_*` kit at 8281-8407), `arrow.gd`, `player.gd`
(`spawn_arrow` 6946, `throw_javelin_volley` 5572, `launch_projectile` 5529,
`call_a_marcher` 6420), `study/DESIGN_LAWS.md`, `study/gif_ranged.md`,
`test_weapondps_node.gd` (HITS_PER_USE), `test_dispatch_node.gd` (KIND_ALIAS).

---

## 0. CALIBRATION — the numbers every entry below is measured against

**1 PL = 48px = one player height.** (`DESIGN_LAWS` §2, and the owner's
reference footage.)

**Projectile read-size by tier** — the longest dimension of the thing, or of
the *envelope* when the verb is several objects moving as one:

| tier | read size | in PL |
|---|---|---|
| T2 | 20-28px (envelope up to 90px for a spray) | 0.4-0.6 |
| T3 | 28-38px | 0.6-0.8 |
| T4 | 38-50px (envelope 68-200px) | 0.8-1.05 |
| T7 | **62-72px** | **1.3-1.5** |
| T8 | **72-82px** | **1.5-1.7** |

The T7/T8 floor is non-negotiable: a Monarch/Ascended projectile that reads
under 62px is the "too small and thin" complaint again.

**Speed bands** (px/s, from `DESIGN_LAWS` §2 converted at 60fps):
glide 260-420 · stately 420-620 · standard bolt 620-780 · fast 780-1000 ·
streak >1000 (use only as a terminal burst, never for the whole flight).

**Drawing kit already in `weapon_projectile.gd`** — use these, do not
hand-roll polygons:
`_art_orb(r, col)` bloom+body+hot core+lit rim · `_art_blade(len, wid, col)`
shade+body+lit top edge+point flare · `_art_shard(r, col, facets)` faceted
crystal · `_art_rim(outline, col, w)` the lit edge that stops dark shapes
silhouetting into the night background · `_circle(r, sides)` · `_add_mat()`
additive material.

Every kind not listed in `NO_ENRICH` automatically gets a bloom, a hot core
and a lagging global-space trail from `_enrich_visual()` (line 588). Entries
below only describe **extra** art; assume the halo and trail are there.

---

## 1. THE PIERCE RE-CUT LAW (the bug class, stated once)

The engine appends every struck body to `hit_bodies` and never clears it
unless a verb explicitly does. So `pierce = true` means *"pass through the
row"*, and it silently also means **"each body is worth exactly one hit,
forever"**. Weapons whose whole identity is *staying inside the target* —
a helix, a hanging band, a flowing molten mass — were therefore worth one
hit each, and no audit could see it.

The existing precedent for the fix is `_rehit_t` (lash 0.5s, orbiter 0.35s,
edict `EDICT_REHIT` 0.17s, `heavenpoint`/`frost` 0.22s):

```gdscript
_rehit_t += delta
if _rehit_t >= RECUT_GAP:
    _rehit_t = 0.0
    hit_bodies.clear()
```

**Rule for this rework:** every piercing verb below declares its re-cut
policy explicitly. Three legal answers only:

- **NO RE-CUT (even-pierce).** Passes through, each body once, same damage.
  Used where the fantasy is *threading a line* (`DESIGN_LAWS` §11).
- **RE-CUT at gap G.** `hit_bodies` cleared every G seconds. Used where the
  fantasy is *the target is inside the weapon*.
- **STEPPED FALLOFF.** Each body pierced costs the projectile a fraction of
  its damage (the existing `slash` rule, ×0.75). Never combined with re-cut.

Summary of what each new verb takes:

| re-cut 0.22s | re-cut 0.25-0.30s | even-pierce, no re-cut | not piercing |
|---|---|---|---|
| Galeprong (helix) | Choir of Points (band, 0.25) · Night Parade (lantern, 0.30) · Magma Writ (flow, 0.30) | Reed Javelins · Stormprong · Gullwing Prong · Finchstorm · Hale Seeker · Pale Flight (ghost) | everything else |

---

## 2. GROUP A — THE SEVEN RICOCHETS

Current shared engine: `_build_ricochet()` (3767) + the `"ricochet"` branch in
`_on_body_entered` (1570). Seven weapons, one dart.

**Design constraint discovered while reading the roster:** the leap family is
*already crowded* with bookkeeping verbs that must not be re-invented here —
`howlbolt` (T4, a ring at every bounce), `deepdebt` (T4, stacking debt),
`debtmark` (T6, a debt that transfers on death), `griefcollect` (T6, gathers
weight and brings it home), `lastcourier` (T6, a route with no decay and no
second knock), `rumor` (T8, grows in the telling). So the seven below are
differentiated by **geometry**, not by ledgers.

---

### A1 · `wpn_ratterdart` — "Ratter's Dart" — T2 melee (8 dmg, 0.7s, bounces 2)

**The verb:** a cellar-rat's dart thrown low along the floor, skipping twice
off the stone like a flat stone off water — it does not chase anything, it
goes *under* things.

**Flight path.** Leaves the hand at **560 px/s**, aimed 12° below the aim
line. Gravity **900 px/s²**. On floor contact: reflect with
`vy = -0.62 * abs(vy)`, keep 92% of horizontal speed, and stamp a grit puff.
Two skips (`bounces`), then it buries in the floor and fades over 0.3s.
Hard caps: 1.6s life, 420px total travel. On a body: full damage, the dart
stops (no pierce) and drops. **Each skip kicks two grit chips** forward and
up at 40% damage, 60px range, 300 px/s — this is the reason it is worth
firing at all, and it fires on the skip, never on a hit.

**Visual.** A **24px** iron dart: `_art_blade(24, 3.0, Color(0.72,0.75,0.80))`
plus a rust-orange twine wrap at the tail (two 5×3 quads). Grit chips are
6px triangles in `Color(0.62,0.58,0.50)`. Skip puff: one `Polygon2D` ellipse,
`Color(0.80,0.78,0.70,0.55)`, tweened `scale (1,1)→(2.4,0.5)` and alpha→0
over 0.28s. Trail: engine default, physical tint, short.

**Hits one body per use:** **1.3** (the dart, plus roughly one grit chip).

**Distinct from the other 26:** the only projectile in the roster that
ricochets off *terrain* rather than off *bodies*. It has zero targeting logic.

---

### A2 · `wpn_hookbill` — "Hookbill" — T3 melee (12 dmg, 0.65s, bounces 3)

**The verb:** a thrown billhook that does not bounce — it **catches**,
swinging a three-quarter circle around each body it hooks before being flung
on to the next.

**Flight path.** Out at **620 px/s**, straight. On the first body it enters
**hook state**: orbit that body at radius **34px**, angular speed **14 rad/s**
for **0.22s** (≈0.78 of a turn), dealing a **second hit at the halfway point
of the swing**. Release along the exit tangent toward the nearest un-hooked
body within **330px** at 620 px/s; if none, fly the tangent for 160px and
drop. Damage ×**0.90** per catch (gentler than the old ×0.85 — it earns two
hits per body). 3 catches. If the hooked body dies mid-swing, the swing
completes around its last position, then releases — never snap the arc.

**Visual.** A **32px** billhook: a `Line2D` crescent (width 5, 7 points on a
110° arc) in `Color(0.42,0.44,0.48)` with an inner `Line2D` at width 2 in
`Color(0.95,0.97,1.0,0.7)` for the edge, plus a 12×4 `Polygon2D` haft in
`Color(0.45,0.34,0.22)`. **Signature:** during the hook-swing it lays down an
arc ribbon — a `Line2D` on the parent tracing the orbit, width 6, additive,
faded to 0 over 0.25s. Spin: `spin_speed = 0`; the hook's rotation is slaved
to `direction.angle()` in flight and to the orbit tangent during the swing,
so it always reads as biting inward.

**Hits one body per use:** **2.0** (entry + the sweep round), across up to 3
bodies.

**Distinct:** the leap is a *drawn arc around the body*, not an instant angle
change. It is the only weapon here that cuts the same body twice on one stop.

---

### A3 · `wpn_finchbolt` — "Finchbolt" — T3 wand (13 dmg, 0.6s, bounces 3)

**The verb:** the bolt is one finch, and every body it touches startles it
into **two**, so a single cast becomes a flock spreading out from the first
victim.

**Flight path.** Parent at **520 px/s** with a wingbeat: lateral offset
`±7px * sin(2π * 9 * t)` — smooth, never jittered. On a body: full damage,
the parent pops into feathers and spawns **two children** at ±32° from the
parent heading, **470 px/s**, each steering at **5 rad/s** toward the nearest
body it has not touched within **280px**, life 0.75s / 300px. Children pay
**0.62×** the parent. A child on a body spawns two grandchildren by the same
rule (`gen < 2`); grandchildren just hit and pop. Hard cap **7 finches per
cast**. Whiff behaviour: at end of range the parent still splits once (a
startled bird splits whether or not it hit) — the soul fires on the click.

**Visual.** Each finch: a 16px wedge `Polygon2D` in `Color(1.0,0.86,0.42)`,
white core `_circle(3.5, 8)`, and **two 12px `Line2D` wings** whose `scale.x`
is driven by `abs(sin(t*22))` — the flap is the motion signature and the
reason it reads as alive. Parent **30px**, children **20px**. Split burst:
five 5px triangles in `Color(1.0,0.94,0.78,0.8)` drifting up with gravity
−40 and fading over 0.4s.

**Hits one body per use:** **1.6** (a lone target eats the parent and maybe
one returning child; a crowd eats seven pecks).

**Distinct:** the only one that **branches** — the projectile count grows
instead of relaying.

---

### A4 · `wpn_tithegather` — "Tithe Gatherer" — T3 melee (11 dmg, 0.65s, bounces 3)

**The verb:** a collector working door to door — the iron weight hops
**forward only**, along the ground, from body to body, and drops a tithe-weight
at every door it knocks on.

**Flight path.** Thrown at **600 px/s**. It never leaps backward: the next
target must be **further along the aim axis** than the current stop
(`(next.pos - pos).dot(aim_axis) > 0`), within **340px**. Each leap is a
**parabola, not a line**: launch the hop at 22° above the line to the target
with gravity 820 px/s², tuned so it lands on the target — the visible hop arc
is what separates this from every other leap in the game. Damage does **not**
decay per stop; the cap is the 3 hops. If no body lies further forward, it
plants in the floor and is spent.

At **every stop, including the plant**, it drops one **tithe-weight**: a 16px
iron block that falls at 900 px/s², cracks on the floor for **35% damage** in
a 55px radius, and leaves a 0.4s dust ring.

**Visual.** A **30px** iron counting-weight — a truncated-pyramid `Polygon2D`
in `Color(0.38,0.38,0.42)` with `_art_rim(..., Color(0.9,0.88,0.8), 2.0)` so
it does not vanish into the night, plus a small brass ring on top
(`_circle(4,8)`, `Color(0.86,0.72,0.32)`). It tumbles: `spin_speed = 7.0`.
Weights are 16px versions of the same silhouette. Trail: engine default,
short and low.

**Hits one body per use:** **1.8** (the hop, plus a weight cracking on or
beside it).

**Distinct:** forward-only, and the arc between stops is a real parabola with
a real object falling out of it at each stop. Not a ledger — nothing ticks.

---

### A5 · `wpn_courierrod` — "Courier's Bad News" — T3 wand (12 dmg, 0.62s, bounces 3)

**The verb:** bad news travels fast — each hop is quicker and reaches
further than the last, and the final hop crosses the room as a streak.

**Flight path.** Hop 1 at **520 px/s**, search radius **340px**. Every leap
multiplies both: speed ×**1.55**, search radius ×**1.4** →
520 / 806 / 1250 px/s and 340 / 476 / 666px. Damage stays at **0.95×** per
hop, so what escalates is *pace*, not numbers. Retarget is a smooth 0.06s
`rotate toward` rather than a snap, so even the 1250 px/s hop reads as one
deliberate movement. If nothing is in the (growing) radius, the bolt keeps
its current heading and burns out at 500px.

**Visual.** A **28px** folded-letter wedge: `Polygon2D`
`[(-14,-6),(10,-9),(14,0),(10,9),(-14,6)]` in `Color(0.92,0.90,0.82)` with a
dark red wax seal `_circle(4.5,8)` in `Color(0.70,0.16,0.18)` at the centre.
**Signature:** the shape *stretches with speed* — set
`visual.scale.x = clamp(speed / 520.0, 1.0, 2.4)` each frame, so the last hop
draws a 60px+ streak while the first is a compact letter. The engine trail's
`width_curve` already tapers; the extra length sells the acceleration.
Each retarget flashes one white chevron at the turn point (a 14px `Line2D`
"V", additive, fading in 0.18s).

**Hits one body per use:** **1.5**.

**Distinct:** velocity is the identity, and the *reach* grows with it — it
finishes targets no other T3 leap can even see.

---

### A6 · `wpn_gravecourier` — "Grave Courier" — T7 melee (27 dmg, 0.52s, bounces 7, `rider:"courier"`, fx `soulwisp`)

**The verb:** the courier serves the whole street before anyone opens the
letter — it leaves a pale shade standing on every body it visits, and when
the round ends, **all of them strike at once**.

**Flight path.** Out at **700 px/s**, leaping up to **7 bodies** within
**360px** each, damage flat at **1.0×** per stop (the escalation is the
finale, not the chain). Retarget is a 0.05s eased turn. At every stop it
plants a **marker**: a kneeling hooded shade, ~34px, standing on that body,
tracking it if it moves.

When the chain ends (7 stops, or no target in range, or 1.4s with no leap),
the courier bursts and **every marker rises and strikes simultaneously** for
**70%** of the stop damage, with one shared white flash frame across all of
them. Nothing ticks in between: the wait is silent and completely legible —
you can count the shades standing in the room.

Keep the existing `courier` rider fear (25% of departed bodies get
`slow 1.5s / 0.45`) — it explains why they are still standing there when the
letters open.

**Visual.** The courier itself must read at **66px (1.4 PL)**: a long iron
message-case — `_art_blade(58, 6.5, Color(0.30,0.32,0.38))` for the body,
`_art_rim` in `Color(0.72,0.86,1.0)` along its outline, a wax-seal disc
`_circle(7,10)` in `Color(0.86,0.24,0.26)` at the tail, and a small cold
lantern `_circle(5,8)` in `Color(0.78,0.90,1.0)` swinging under it on a 10px
`Line2D` (the swing is `sin(t*6) * 0.35` rad — smooth, and the only moving
part). Markers: a 34px hooded `Polygon2D` silhouette in
`Color(0.14,0.16,0.24,0.85)` with two pale eye dots and an `_art_rim` in
`Color(0.70,0.84,1.0,0.5)`; they stand with a slow 0.5px breathing bob.
The synchronized strike: each marker snaps to full height over 0.12s and
throws a 40px vertical `Line2D` slash, all on the same frame.

**Hits one body per use:** **2.8** (its own stop, plus the marker payout,
plus the wisps the `soulwisp` fx raises on kills).

**Distinct:** the only leap that pays out *all at once, at the end*. It is
not a ledger (`debtmark` ticks and transfers; `deepdebt` stacks;
`griefcollect` carries weight home to the player). This one is a
**synchronized delayed payoff**, `DESIGN_LAWS` §5.

---

### A7 · `wpn_finaldebt` — "The Final Debt" — T7 wand (25 dmg, 0.6s, bounces 7, fx `goldtouch`)

**The verb:** the accounts are ruled off — the bolt draws a line of gold light
between every pair of stops, and when the round ends **the whole drawn figure
snaps taut** and cuts everything standing on it, stops or not.

**Flight path.** Out at **760 px/s**, up to **7 leaps** within **380px**,
damage **0.92×** per stop. Every leap **records its segment**: the polyline
of every point it has bounced from persists on screen as a thin gold wire
(a `Line2D` on the parent, not on the projectile — it must not move with it).

When the chain ends, the ledger **closes**: over **0.18s** every segment
brightens from width 2 to width 9, and on the frame it peaks it deals
**55%** of the base damage to every hostile body within **26px of any
segment** — including bodies that were never a stop. Bodies are damaged once
by the whole figure, not once per segment (walk the segments, collect a
`Dictionary` of instance ids, then pay). The wire then fades over 0.5s.

The longer the chain, the more of the room is crossed by hot wire — the
weapon's power scales with how well the player read the crowd, not with a
number.

**Visual.** The bolt itself at **64px (1.33 PL)**: a coin-seal — an outer
`_art_shard(26, Color(1.0,0.84,0.34), 8)` reading as a milled edge, an inner
disc `_circle(16, 14)` in `Color(0.78,0.60,0.16)`, a white hot core, and a
slow counter-rotation (`visual.rotation -= 3.0 * delta`) that makes the two
rings read as a struck coin. The wire: `Line2D`, joint mode round, colour
`Color(1.0,0.86,0.40,0.55)`, additive, `z_index = 39`. At the snap, add a
second `Line2D` copy of the same points at width 14, alpha 0.35, tweened to 0
over 0.35s — a bloom on the whole figure at once.

**Hits one body per use:** **2.4** (its stop, plus the snap — most bodies sit
on at least one segment).

**Distinct:** the only weapon in the game whose **own flight path becomes a
hitbox**. Pulse-Bow-kin in feel (their polyline is only a trail), never 1:1.

---

## 3. GROUP B — THE SEVEN JAVELIN VOLLEYS

Current shared engine: `player.throw_javelin_volley()` (5572) → N ×
`launch_projectile` with `kind = "javelin"` → `_build_javelin()` (3680), which
is one call to `_art_blade(30, 3.2, beige)`. `pierce` defaults true for
javelins (5541) — and with no re-cut, **every one of these is worth exactly
one hit per body**.

Spear law (`DESIGN_LAWS` §8): riders spawn at the **apex of the thrust**,
never at the player's centre. All seven inherit that.

---

### B1 · `wpn_reedjavelin` — "Reed Javelins" — T2 spear (9 dmg, 0.9s, count 2)

**The verb:** two light reed shafts thrown as a **flat parallel pair** — no
fan at all — that snap on what they hit and throw a splinter onward.

**Flight path.** Both at **620 px/s**, **zero spread**, spawned at the thrust
apex ±**13px** perpendicular to the aim. Dead straight, no gravity, range
**450px**. **Even-pierce, no re-cut:** each shaft threads up to **2 bodies**
for the same damage, then snaps. The snap (on the 2nd body or at end of
range) throws one **26px splinter** forward at 40% damage, 90px, 700 px/s.

**Visual.** **26px** shaft: `_art_blade(26, 2.4, Color(0.78,0.86,0.55))`, a
darker node band (`Polygon2D` 4×5 in `Color(0.52,0.60,0.34)`) at one third,
and two hair-thin `Line2D` leaves at the tail. Snap: three 8px slivers
spraying forward over 0.25s.

**Hits one body per use:** **1.4** (a normal 60px-tall body catches one shaft;
a boss catches both).

**Distinct:** the only **zero-spread** throw in the family — a flying fence
slat, Tsunami-kin in feel, never 1:1.

---

### B2 · `wpn_stormprong` — "Stormprong" — T3 spear (12 dmg, 0.95s, count 3)

**The verb:** three prongs that leave as **one bundled trident** and separate
only in the last third of the flight, so it is a lance up close and a wall at
range.

**Flight path.** **700 px/s**. For the first **60% of range** all three fly
overlapping (spawn offsets ±4px) and read as one object. At 0.6×range they
**separate over 0.15s** with an ease-out to ±26°, then hold their new lines
to range **490px**. **Even-pierce, no re-cut:** 2 bodies each. At the split
instant, a **crackle** — a 3-point `Line2D` arc jumping between the three
prongs, redrawn twice, gone in 0.12s.

**Visual.** **34px** prong: `_art_blade(34, 3.6, Color(0.66,0.82,1.0))` with a
white-hot tip flare. During the bundle phase add one shared additive glow
(`_circle(18,12)`, `Color(0.70,0.86,1.0,0.28)`) centred on the group so the
three genuinely read as one lance. Crackle in `Color(0.90,0.96,1.0,0.9)`.

**Hits one body per use:** **2.2** (point blank all three land on one body;
at range, one).

**Distinct:** the **late split** is a real skill dial — this is the only
weapon whose damage concentration is set by the player's chosen distance.

---

### B3 · `wpn_gullprong` — "Gullwing Prong" — T3 spear (11 dmg, 0.9s, count 3)

**The verb:** three gliding shafts that bank out and back in long shallow
S-curves, weaving a braid down the lane and crossing each other twice.

**Flight path.** **560 px/s** (the slowest of the seven — it *glides*), range
**470px**. Lateral offset per shaft:
`46px * sin(2π * t / 0.55 + φ_i)` with `φ = 0, 2π/3, 4π/3`. Pure sine, no
noise — the motion must read as three birds, not three glitches.
**Even-pierce, no re-cut:** 2 bodies each. A body standing where two curves
cross takes two shafts in the same beat; that is the reward for reading the
braid.

**Visual.** **32px** shaft: `_art_blade(32, 3.0, Color(0.94,0.93,0.88))` with a
pale grey fletch — two 9px triangles that **fan open** by ±8° at the outer
extreme of each sine swing. **Signature is the trail:** override
`TRAIL_LEN` to 18 for this kind and drop the trail alpha to 0.35, so the
three ribbons visibly weave. `DESIGN_LAWS` §6 — the trail is the identity.

**Hits one body per use:** **1.6**.

**Distinct:** the only **woven** path. Smooth by construction.

---

### B4 · `wpn_reedvolley` — "Reedsong Volley" — T3 spear (10 dmg, 0.85s, count 4)

**The verb:** four reed pipes thrown as an ascending run of notes, one every
beat, and **every one that lands sounds a ring** — four together are a chord.

**Flight path.** Staggered in **time**, not space: one every **0.07s**. Launch
angles **−3° / −6° / −9° / −12°** above the aim, each at **640 px/s** with
gravity **260 px/s²**, range **440px** — so the run visibly rises and then
falls. Pierce **1 body** each, no re-cut.

Every shaft, **on landing on a body OR on the ground OR at end of range**,
sounds a note: an expanding ring, 0→**70px** over 0.22s, **30% damage** to
everything it passes. The ring is unconditional — it fires on a whiff, per
forever-rule 7.

**Visual.** **28px** pale reed pipe: `_art_blade(28, 2.6, Color(0.82,0.78,0.52))`
with three 2px dark fingerhole dots along it. Ring: a `Line2D` circle (20
points), width 3→1 over its life, `Color(1.0,0.96,0.82,0.7)`, additive.
When two rings overlap, let them: overlapping rings *is* the chord.

**Hits one body per use:** **2.4** (roughly two shafts plus two rings).

**Distinct:** the only **time-staggered** volley, and the only one that pays
on a miss. Not to be confused with `choirstring` (T7), which *plants* notes
that hum for seconds — these rings are instantaneous and travel nowhere.

---

### B5 · `wpn_galeprong` — "Galeprong" — T4 spear (15 dmg, 0.9s, count 4)

**The verb:** four javelins corkscrewing around the aim line as one drill,
boring down the lane and cutting whatever it is passing through, repeatedly.

**Flight path.** **720 px/s** forward, range **520px**. Perpendicular offset
per shaft: `R * cos(θ_i + ωt)` and `R * sin(θ_i + ωt)` projected onto the
aim's perpendicular, with `R = 34px` (a **68px envelope** — 1.4 PL, the
required read size at T4), `ω = 11 rad/s`, `θ_i = i * π/2`.

**RE-CUT: yes, gap 0.22s.** This is the entry that most needs it — the helix
crosses the lane centre 2-3 times per flight, so without a re-cut clock the
drill visibly passes through a body over and over and bills once. Use the
`heavenpoint`/`frost` precedent exactly.

**Visual.** **36px** shaft: `_art_blade(36, 3.4, Color(0.82,0.94,0.90))`.
Add one **axis tube**: a `Line2D` down the aim line, width 30, additive,
`Color(0.80,0.92,0.90,0.12)`, `z_index = 38` — it costs one node and turns
four separate shafts into one drill. The four engine trails braid into the
helix on their own; do not add more.

**Hits one body per use:** **3.0**.

**Distinct:** the only helix, and the only volley whose multi-hit comes from
**geometry** rather than from projectile count.

---

### B6 · `wpn_hawkvolley` — "Hawks in Formation" — T4 spear (14 dmg, 0.88s, count 4)

**The verb:** four shafts hold a rigid **V** down the lane and then the two
arms of the V sweep inward like closing shears, herding everything they
touch onto the point.

**Flight path.** **700 px/s**, range **500px**. Lead shaft on the aim line.
Three trailing shafts at **40 / 80 / 120px** behind and **±34 / ∓68 / ±102px**
lateral — an actual V, ~200px wide at the tail. Over the **last 0.3s** of
flight the trailing shafts ease their lateral offset to 0
(`ease_in_out`, smooth, no snap), converging on the axis.

A body struck by a **converging** shaft takes `apply_knockback` **toward the
axis** at 110 force (sign from which side of the axis it stands). Pierce
**2 bodies** each, no re-cut.

**Visual.** **36px** shaft: `_art_blade(36, 3.6, Color(0.34,0.30,0.26))` — dark
iron, so `_art_rim(outline, Color(0.95,0.72,0.36), 2.0)` is mandatory or it
disappears against the night. Rust-brown fletch (two 10px triangles) that
**opens 20°** at the moment convergence begins — one visible tell, one frame.

**Hits one body per use:** **2.0** (a body near the axis eats the lead plus at
least one closing arm).

**Distinct:** the formation itself is the weapon, and it is the only volley
that **moves enemies** rather than passing through them. Deliberately *not* a
stoop — `huntword` (T4 bow) already owns "two of them answer, each stooping
on a different body".

---

### B7 · `wpn_marrowprong` — "Marrowsplitter" — T4 spear (16 dmg, 0.95s, count 3)

**The verb:** three heavy bone javelins thrown hard and short that **stick
where they land**, and half a second later crack lengthwise and throw
slivers sideways.

**Flight path.** **780 px/s**, flat with a slight droop (gravity **180 px/s²**),
short range **330px**. Spread ±7° only. On a body: full damage, then
**embed** — reparent the shaft to the body, keep the impact angle, stop
processing. On the floor: plant upright. Either way, **0.5s later it
splits**: two **24px** slivers leave at **±90° to the shaft axis** at
520 px/s for 130px, **45% damage** each. The stuck halves remain for another
1.5s then fade.

**Visual.** **38px** shaft: `_art_blade(38, 4.4, Color(0.92,0.88,0.74))` with
two 1px dark marrow lines running its length and a knobbed butt
(`_circle(4,7)`). The split: a white flash frame, then the single body
polygon is replaced by two halves offset ±3px and rotated ±6° — the shaft
visibly *stays* in the wound, in two pieces.

**Hits one body per use:** **2.2** (about two shafts land; their slivers go
sideways and mostly find neighbours, not the host).

**Distinct:** the only volley that leaves **objects standing in the world**.
Bone-Javelin-kin in feel (theirs is a stacking DoT; ours is a delayed lateral
burst), never 1:1.

---

## 4. GROUP C — THE SIX MULTI-SHOTS (bows)

Current engine: `player.spawn_arrow()` (6946), N × `arrow.tscn`, spread from
`special.spread_deg`. `multi_shot` has **no dispatch branch at all** — the
dispatch audit only matches it because `KIND_ALIAS` maps it to
`script:arrow.gd`.

**Routing note, important for the implementer.** `arrow.gd` carries hooks
that `weapon_projectile.gd` does not: Killshot/Headhunter (`execute_threshold`,
`execute_heal`), Golden Gaze (`gold_mark_until`), Contagion
(`poison_spread`), the Ranger `multishot` bonus and `arrow_pierce`. Moving a
bow off `arrow.gd` silently deletes those from that bow. Recommended split:

| weapon | engine | why |
|---|---|---|
| Pale Flight | `arrow.gd` (+ `ghost` flag) | shaft-shaped; `pierces_terrain` already exists (line 111) |
| Twinnock Bow | `arrow.gd` (+ per-instance launch angle) | plain shafts, geometry only |
| Finchstorm | `arrow.gd` (+ `lateral_curve`) | plain shafts, one added lateral term |
| Ferryman's Bow | `weapon_projectile.gd` | needs a span hitbox between two siblings |
| Choir of Points | `weapon_projectile.gd` | needs a span hitbox with a re-cut clock |
| A Storm of Larks | `weapon_projectile.gd` | needs per-instance gravity; `arrow.gd` has none |

For the four that stay/partly stay on `arrow.gd`, add three optional fields
rather than four one-off flags: `accel: Vector2` (default zero),
`lateral_amp`/`lateral_hz`, and `ghost: bool`. For the three that move,
route the Ranger hooks through `source.on_projectile_hit` (player.gd 6400) so
nothing is lost.

---

### C1 · `wpn_ferrybow` — "Ferryman's Bow" — T2 bow (7 dmg, 0.65s, count 2)

**The verb:** two arrows loosed with a **rope strung between them**, and it is
the rope that cuts — you aim the gap, not the points.

**Flight path.** Both shafts at **760 px/s**, perfectly parallel, ±**20px**
perpendicular to the aim (a **40px span**), no gravity, range **420px**. The
**cord** is the damage source: any hostile body whose collision box crosses
the segment between the two shafts takes **100%** of the shot's damage, once.
If either shaft strikes a body directly, both stop and the cord snaps with a
small flash. The pair is one logical projectile — free them together.

**Visual.** Two **20px** shafts: `_art_blade(20, 2.2, Color(0.80,0.78,0.70))`.
The cord: a `Line2D` with **3 points** — the two ends and a midpoint offset
**8px backward** along the aim, so the rope **sags** and then straightens over
the first 0.15s as the pair "accelerates". Width 3,
`Color(0.80,0.86,0.92,0.80)`, round caps. Snap: the cord recoils — tween the
midpoint offset to +14px and alpha to 0 over 0.12s.

**Hits one body per use:** **1.2**.

**Distinct:** the hitbox lives **between** the projectiles. Nothing else at
T2 asks the player to aim at empty air.

---

### C2 · `wpn_paleflight` — "Pale Flight" — T2 bow (6 dmg, 0.6s, count 2)

**The verb:** one arrow, and its **pale afterimage** arriving a beat later
along the identical line — and the afterimage does not care about walls.

**Flight path.** Real shaft: **800 px/s**, ordinary. The ghost spawns at the
same origin **0.14s later**, same direction, same 800 px/s, with
`pierces_terrain = true` (already supported, `arrow.gd` line 111) and
**even-pierce through 1 body, no re-cut**. Two impacts, one trigger pull, the
second one arriving from behind cover.

**Visual.** Real shaft **22px**, ordinary pale wood. Ghost: identical
geometry at `modulate = Color(0.85,0.88,1.0,0.5)` with an additive halo —
and **no trail at all** (skip `_enrich_visual`'s trail for the ghost; a ghost
leaves no wake, and the absence is the tell, `DESIGN_LAWS` §10).

**Hits one body per use:** **2.0** (both follow the same line).

**Distinct:** the offset is **temporal**, not spatial, and the ghost half
ignores terrain. Not the melee `echo` fx (which repeats a *blow*, has no
projectile, and cannot pass through a wall).

---

### C3 · `wpn_twinnock` — "Twinnock Bow" — T3 bow (10 dmg, 0.6s, count 2)

**The verb:** two arrows off one string that **cross** at a fixed distance and
diverge again — a clean X drawn in the air, with a sweet spot at the middle.

**Flight path.** Each at **820 px/s**, straight, converging so they meet at
exactly **230px** from the bow (launch angles ±`atan(20 / 230)` ≈ ±5°, from
±20px starting offsets). They continue past the crossing on their lines to
range **480px**. Each pierces **1 body**, no re-cut. A body at the crossing
takes both. A tiny white spark (`_circle(4,8)` additive, 0.1s) marks the
crossing point every shot, whether or not anything is there — the player
learns the distance in one magazine.

**Visual.** **24px** shafts: `_art_blade(24, 2.6, Color(0.46,0.34,0.22))` with a
bright brass nock band (`Polygon2D` 4×6, `Color(0.86,0.72,0.32)`). The two
engine trails literally draw the X; that is the whole signature and it costs
nothing.

**Hits one body per use:** **1.5** (2.0 at the crossing, 1.0 elsewhere).

**Distinct:** pure geometry with a **range-control skill dial**, no gimmick
object and no bookkeeping.

---

### C4 · `wpn_finchvolley` — "Finchstorm" — T3 bow (9 dmg, 0.6s, count 3)

**The verb:** three shafts loosed in a tight stack that **scatter like
startled birds** mid-flight, each peeling onto its own smooth curve — wide,
unreliable, and impossible to stop.

**Flight path.** **780 px/s**, launch stack at −16 / 0 / +16px perpendicular,
parallel. At **200px travelled** each shaft picks a lateral drift target of
`±(60..140)px` (rolled per shaft, sign alternating so they never all go the
same way) and eases into it over **0.35s** with a smoothstep, then holds the
new line to range **520px**. **Even-pierce through 2 bodies, no re-cut** —
inaccuracy is paid for with pierce, Hellwing-kin in feel, never 1:1.

**Visual.** **22px** shafts: `_art_blade(22, 2.4, Color(0.86,0.72,0.34))` with a
warm gold fletch. At the scatter moment each puffs **three 5px feather
triangles** in `Color(1.0,0.94,0.78,0.75)` drifting up over 0.4s. The curve
must be a smoothstep, never a random walk — the target is *smooth chaos*.

**Hits one body per use:** **1.4**.

**Distinct:** the deliberately **inaccurate** bow of the six, and the exact
opposite of Twinnock's ruler-drawn X. It is a crowd weapon and useless
against a single small target — that is the design, not a flaw.

Note it does **not** clash with `wpn_finchbolt` (A3): that one *splits into
more finches on contact*; this one is three shafts that never multiply.

---

### C5 · `wpn_choirbow` — "Choir of Points" — T4 bow (12 dmg, 0.6s, count 3)

**The verb:** three shafts fly in a rigid vertical stack with a **humming band
of sound stretched between them**, and the band is the weapon — a flying
harp that shears a whole column of the room.

**Flight path.** **760 px/s**, stacked at **−34 / 0 / +34px** perpendicular
(a **68px span** = 1.4 PL, the required T4 read size), dead parallel, range
**540px**. Each shaft pierces **2 bodies**.

The **band** between the outer two shafts is a hitbox. **RE-CUT: yes, gap
0.25s** — a body inside the band is cut roughly four times as the stack
sweeps past it, and that is the entire identity. As shafts are consumed the
band **narrows to the survivors**, and with one shaft left it is an ordinary
arrow. Reward for clear lanes; punished by a crowded doorway.

**Visual.** Three **24px** shafts: `_art_blade(24, 2.8, Color(0.86,0.74,0.40))`
(brass). Band: one `Polygon2D` quad spanning the outer two shafts,
`Color(1.0,0.93,0.72,0.16)`, additive, plus two `Line2D` edges at alpha 0.35
whose points ripple with `sin(x * 0.06 + t * 9) * 3px` — smooth standing-wave,
three nodes total. Add `"choir_band"` to `NO_ENRICH`: a halo on a band reads
as a bug.

**Hits one body per use:** **2.6**.

**Distinct:** it is a **flying wall with a re-cut clock**, where Ferryman's
cord (C1) is a single-hit 40px line at a quarter of the tier. Different
scale, different lifetime, different rule.

---

### C6 · `wpn_larkstorm` — "A Storm of Larks" — T4 bow (11 dmg, 0.58s, count 3)

**The verb:** three shafts that **climb** out of the bow, tip over at the top,
and come down steeply — larks ascending and stooping, one after another,
over whatever is in the way.

**Flight path.** Launched along the aim at **700 px/s**, staggered **0.06s**
apart. Gravity is **−520 px/s²** (lift) for the first **0.35s**, then
**+900 px/s²** for the dive. Range cap **560px**. Each arrives nose-down at
roughly 60-75°. No pierce — a stoop lands. If nothing is hit, they strike the
floor and puff grass-and-feather.

**Visual.** **24px** shafts: `_art_blade(24, 2.6, Color(0.58,0.46,0.32))`.
**Signature is the turnover:** at the apex, one white flash frame plus a
2px `Line2D` chevron, and the engine trail visibly kinks. Because the shafts
are staggered, the three turnovers read as three beats.

**Hits one body per use:** **1.6**.

**Distinct:** the only shot in the six with a **vertical** answer — it clears
cover and reaches ledges. It is **not** `king_rain` (T8, which spawns above
the camera and never leaves the bow) and **not** `huntword`/`stoop_arrow`
(which acquire a target and dive at it): Larkstorm is purely ballistic and
targets nothing.

---

## 5. GROUP D — THE THREE "HOMING"

Current engine: `special_type == "homing"` sets `arrow.homing = true`
(player.gd 6977) and `arrow.steer_toward_prey()` (arrow.gd 134) bends toward
the nearest body at 5 rad/s. Both Seekers are the identical shaft; Night
Parade is the same shaft with a marcher call bolted on.

The two Seekers are differentiated by **what they hunt** and **how they
turn**. Night Parade keeps its procession — it is a good crown identity — but
gets its own body and stops being gated on connecting.

---

### D1 · `wpn_paleseeker` — "Pale Seeker" — T3 bow (12 dmg, 0.7s)

**The verb:** a wan grey shaft that ignores the healthy and bends,
continuously and unhurriedly, toward whatever is already **wounded** — and
when it lands it comes apart into two smaller pale shafts that go looking for
the next wounded thing.

**Flight path.** **720 px/s**. Steering **4 rad/s** (soft, sweeping — visibly
gentler than the current 5.0), search radius **460px**. Target selection is
**lowest `health / max_health`**, not nearest; ties broken by distance. On
impact: keep the existing `_split_seekers()` (arrow.gd 34) — two children at
±0.7 rad, 50% damage, half range, `split_gen = 1`, no further splits.
Children use the same wounded-first rule.

Whiff behaviour: at end of range it splits anyway — the pale one always comes
apart.

**Visual.** **26px** shaft: `_art_blade(26, 2.6, Color(0.74,0.76,0.82))`, low
saturation, plus a faint second outline offset 2px behind at alpha 0.3 (it
reads as slightly out of focus). Trail: **long and thin** — `TRAIL_LEN` 16,
width ×0.6, alpha 0.35, so it looks *pulled* rather than thrown. The head
brightens as it closes: lerp the point flare's alpha from 0.4 to 1.0 over the
last 120px to the target. That brightening is the tell that it has chosen.

**Hits one body per use:** **2.2** (the shaft plus a child that returns to the
same body when it is alone).

**Distinct:** a **continuous curve toward the weakest**, and it multiplies on
landing.

---

### D2 · `wpn_haleseeker` — "Hale Seeker" — T3 bow (11 dmg, 0.68s)

**The verb:** a heavy ash shaft that flies dead straight and fast, makes
**exactly one hard turn** onto the biggest thing in the room, and then never
turns again.

**Flight path.** **950 px/s**, straight. At **40% of range** it takes its one
decision: over **0.16s** it snaps up to **90°** onto the **largest** body
within **420px** (priority: boss > elite > highest `max_health`; ties by
distance) and locks its heading permanently. **Even-pierce through 2 bodies,
no re-cut**, with `apply_knockback` at 150 force. **No split** — the split
belongs to Pale Seeker now, and removing it here is what makes the pair read
as two weapons.

If nothing qualifies at the decision point, it simply flies on: a committed
hunter that guessed wrong is part of the fantasy.

**Visual.** **30px** shaft, noticeably thicker:
`_art_blade(30, 4.2, Color(0.55,0.42,0.26))` (ash) with a brass point
(`_circle(4,8)`, `Color(0.90,0.78,0.40)`). **Signature is the elbow:** at the
turn, one bright chevron flash (a 16px additive `Line2D` "V" at the pivot,
0.2s) and the engine trail **kinks** — a hard corner in the ribbon that no
other projectile in the game draws.

**Hits one body per use:** **1.6**.

**Distinct:** **one hard elbow toward the biggest** versus Pale Seeker's
continuous drift toward the weakest. Same engine (`arrow.gd`), two rules —
and on screen they are unmistakably different weapons.

---

### D3 · `wpn_nightparade` — "Night Parade" — T8 bow (14 dmg, 0.5s, fx `moonlit`)

**Two problems, not one.** (a) The crown bow's projectile is *the same
ordinary shaft as the two T3 Seekers* — the most expensive bow in the game
has the cheapest body. (b) `call_a_marcher` (player.gd 6420) only runs from
`on_projectile_hit`, so the procession **cannot happen unless you connect** —
a direct violation of forever-rule 7.

**The verb:** you do not fire an arrow — you hang a **moon-lantern** in the
air, and it drifts forward calling the procession in from beyond the edge of
the world, whether or not it has touched anything.

**Flight path.** **420 px/s** (glide band — slow and inevitable), range
**620px**, with a pendulum sway of **±10px at 2 Hz** and a matching **±7°**
rotation. It pierces everything; **RE-CUT: yes, gap 0.30s** — the lantern
grinds through a body it is passing.

**It calls on a clock, not on a hit:** every **0.35s in flight**, and once
more when it settles, it runs `call_a_marcher` with the **lantern's own
position** as the mark (not a victim). Keep `MARCHERS_PER_ARROW = 3` and
`MARCHER_CAP = 9`. Marchers walk in from off-camera through terrain to the
lantern's *current* position and strike whatever stands there. At end of
range the lantern **settles to the floor**, burns for **1.2s** still calling,
then goes out.

Refactor required: `call_a_marcher(victim, dealt)` becomes
`call_a_marcher(at: Vector2, dealt: int, mark: Node2D = null)`; when `mark`
is null the marcher walks to `at` and strikes the nearest body on arrival.

**Visual — this is the crown, and it must read at 76px (1.6 PL).**
A hexagonal paper shade: `Polygon2D` hexagon **46px tall × 38px wide** in
`Color(0.86,0.90,1.00,0.85)` with `_art_rim(hex, Color(0.60,0.72,1.0), 2.5)`;
inside it a warm core `_circle(9,10)` in `Color(1.00,0.94,0.72)` on additive;
above it a 12px `Line2D` hanger and a small ring. Six **light shafts** —
thin additive quads, 34px long, `Color(0.80,0.88,1.0,0.10)` — radiating from
the core and rotating at **0.5 rad/s**; those take the silhouette from 46px
to **76px**. Trail: keep, but drop the width to 0.5× and the alpha to 0.3 —
a lantern leaves a smear of moonlight, not a comet tail.
Per `DESIGN_LAWS` §3 (the crown rule) resist adding anything else: one slow
object, one slow rotation, one sway.

**Hits one body per use:** **4.0** (≈2 from the lantern grinding through,
plus the marchers, which now arrive on every cast rather than every landed
arrow).

**Distinct:** the only projectile in the game that is a **slow moving beacon
that spawns allies on a clock**. Nothing else calls anything without hitting
something first.

---

## 6. GROUP E — THE FOUR FIREBALLS

Current engine: `_build_fireball()` (3684) — `_art_orb(9.5, orange)` + a
`CPUParticles2D` tail — flying at `spd - 40`, `explode()` (1790) on contact or
at range: AoE damage in a radius, 5 shrapnel fragments, one expanding disc.

Four wands, one orange ball. Below, only one of the four is still a ball, and
none of them explode the same way.

---

### E1 · `wpn_foxfirewand` — "Foxfire Wand" — T2 wand (12 dmg, 0.75s, aoe 60)

**The verb:** not fire at all — a cold marsh-light that drifts out at walking
pace, leans toward whatever is nearest, and **pops** into a ring of clinging
green sparks.

**Flight path.** **260 px/s** — the slowest thing in this document — with a
bob of **±9px at 1.6 Hz**. Steering **1.6 rad/s** toward the nearest body
within **220px** (a *lean*, not a hunt). Life **2.2s** or **430px**. On a body
or at end of life it **pops**: eight sparks radially at 480 px/s for **70px**,
**35% damage** each, applying **burn 3s** on contact. It never explodes —
there is no blast disc and no shrapnel.

**Flag it in the roster:** this row must drop `aoe` entirely; leaving `aoe: 60`
on it is what would tempt an implementer back into `explode()`.

**Visual.** **26px** orb: `_art_orb(13, Color(0.55,1.00,0.62))` but **override
the white hot core to `Color(0.78,1.00,0.86)`** — cold light has no white-hot
middle, and that one change is what separates it from every fire weapon on
sight. Two 4px motes orbiting at radius 15px, counter-rotating.
**Signature is the wake:** a `CPUParticles2D` with `gravity = Vector2(0,-30)`
so the trail **floats upward** like marsh gas instead of streaming backward.
Add `"foxfire"` to `NO_ENRICH` so the standard lagging trail does not fight it.

**Hits one body per use:** **1.5**.

**Distinct:** the only cold-coloured "fire" weapon, the slowest projectile in
the document, and it has no explosion of any kind.

---

### E2 · `wpn_cinderrod` — "Cinder Rod" — T2 wand (14 dmg, 0.8s, aoe 70)

**The verb:** one press throws a short wide **gout of tumbling cinders** that
arc, fall, and litter the ground ahead with small fires.

**Flight path.** **Seven embers**, no primary projectile at all. Speeds
**380-520 px/s**, launch angles **−22°..+8°** from the aim (rolled evenly, not
randomly clumped), gravity **780 px/s²**, each living until floor contact or
**0.9s**. Direct ember contact with a body: **damage / 3** (the row's number
divided across the gout), ember consumed.

On floor contact an ember becomes a **cinder patch**: a 22px flicker that
lives **2.5s** and deals **20% damage every 0.5s** to anything standing in it.
Cap **4 live patches** per cast (oldest fades early); the envelope of the
gout reads at roughly **90px** wide.

**Visual.** Each ember: an irregular 10px `Polygon2D` in
`Color(1.00,0.55,0.20)` with a dark crust rim
(`_art_rim(..., Color(0.35,0.18,0.10), 1.5)`), tumbling at
`spin_speed = randf_range(6, 12)`. Patch: three overlapping flicker polygons
whose alpha oscillates out of phase (`0.5 + 0.3 * sin(t*7 + φ)`) — smooth, no
popping — plus two rising 3px ember particles.

**Hits one body per use:** **2.0** (a couple of embers, plus a patch tick or
two if they hold their ground).

**Distinct:** no single projectile exists; it is a scatter plus a floor
hazard. Molotov-kin in feel at a quarter of the scale, never 1:1.

---

### E3 · `wpn_pyrelight` — "Pyrelight" — T3 wand (18 dmg, 0.8s, aoe 95, burn)

**The verb:** the cast does not travel — it throws a seed a short way and
**stands a pyre up** where it stops, a column of flame that holds the ground
for a beat and a half.

**Flight path.** The seed flies **480 px/s for 0.35s (≈170px)**, or until it
touches a body or the floor, whichever comes first — then it **plants**. The
column rises over **0.15s** (scale-Y tween, ease-out), **holds 1.0s**, and
collapses over **0.25s**. Dimensions: **110px tall × 40px wide** (2.3 PL — a
real column at a low tier, which is the point). It burns everything inside on
a **0.28s beat** at **45% damage** per beat and applies the row's `burn_w`.

The column is not a projectile: `monitoring = false`, it owns its own damage
loop, and it is added to `NO_ENRICH`. The plant is unconditional — a whiffed
cast still stands a pyre where the seed hit the floor.

**Visual.** Three nested flame `Polygon2D`s — outer `Color(1.00,0.42,0.12)`,
mid `Color(1.00,0.72,0.22)`, inner `Color(1.00,0.94,0.70)` — each an 8-point
vertical shape whose vertices are re-rolled on a **0.08s** clock and **lerped**
to the new values (never snapped; smoothness is the whole brief). Rising
embers via `CPUParticles2D`, `gravity = Vector2(0,-140)`. A 40px dark scorch
ellipse under it that stays 1.5s after the column dies.

**Hits one body per use:** **4.0** (the plant plus ~3.5 beats over the hold).

**Distinct:** a **standing zone at short range**. It is not `sky_pillar` (T7 —
placed at the aim point at any range, no travelling seed, daylight-white, and
twice the size); it is a thrown ember that erupts where it stops.

---

### E4 · `wpn_magmawrit` — "Magma Writ" — T4 wand (26 dmg, 0.85s, aoe 120, burn)

**The verb:** the cast **writes a sentence along the floor** — a molten mass
that falls, then flows forward following the ground, stamping glowing glyphs
behind it, and when it reaches the end of the line **the whole writ flashes at
once**.

**Flight path.** Launched at **520 px/s** with gravity **1100 px/s²** until it
meets the floor (≈0.2s), then it **glues to the ground**: each frame, raycast
down 24px and set position to the hit point, so it follows slopes and steps.
Flow speed **300 px/s**, run length **420px along the ground**.

It damages bodies it touches for **full damage** and keeps going —
**even-pierce with RE-CUT at 0.30s**, because the fantasy is that the molten
mass is *passing through* them.

Every **60px** it stamps a **glyph**: a 30px rune burned into the floor that
deals **25% damage every 0.6s for 3s**. At the end of the run — when it stops
or hits a wall — **every stamped glyph flares simultaneously** for **40%
damage** and the mass sinks into the floor. Seven glyphs on a clean run.

**Visual.** The mass reads at **44px**: a dark crust `Polygon2D`
(`Color(0.22,0.14,0.12)`) over a bright molten core
(`_art_orb(18, Color(1.00,0.48,0.10))`), with **crust cracks** — four thin
`Line2D` segments in `Color(1.00,0.66,0.20)` whose alpha pulses as it moves,
so the mass looks like it is being torn open by its own motion. Glyphs:
angular rune `Polygon2D`s (5-7 points, hand-authored set of 4 shapes, cycled)
in `Color(1.00,0.50,0.10)` with a scorched dark halo underneath; on the final
flare, all of them tween scale 1→1.6 and alpha 1→0 over 0.3s on the same
frame.

**Hits one body per use:** **3.2** (the pass with its re-cut, plus glyph ticks
and the final flare).

**Distinct:** the only fire weapon that **interacts with terrain** — it
follows the floor, and its damage is a written line that fires as one at the
end. Shares a mover with `kneeling_stone`, deliberately (see §8).

---

## 7. IMPLEMENTATION CHECKLIST — every seam a new verb must touch

For each of the 27, the implementer registers it in **eight** places. Missing
any one of these is exactly how the "verb that does not exist" bugs shipped
before (see the campaign memory: `storm_debt`, `souls`, `_shatter_note`).

1. **`weapon_roster.gd` ROWS** — change the row's `behavior` field to the new
   per-weapon string (e.g. `"ricochet"` → `"ratterskip"`). These are bespoke
   now; do not try to keep them on a shared behavior with a rider.
2. **`weapon_roster._special_for()`** — a `match` branch producing the
   special dict. Remember `verb_force(tier)` (line 1235) is applied last and
   only scales keys named `damage`, `*_dmg`, `*_damage` — name any secondary
   damage keys accordingly or they will not scale with tier.
3. **`weapon_projectile._ready()`** dispatch `match kind:` — call the new
   `_build_*`, and set `pierce` / `monitoring` here (the existing style).
4. **`weapon_projectile._physics_process()`** — a `_tick_*` for any verb that
   owns its own frames (helix, flow, hook-swing, hop arcs, lantern).
5. **`weapon_projectile._on_body_entered()`** — a branch, unless the generic
   `_:` tail is genuinely right.
6. **`weapon_roster._desc_for()`** — one line of card text, in the voice of
   the existing entries.
7. **`test_weapondps_node.HITS_PER_USE`** — the declared number from each
   entry above. All 27 new behavior strings **must** appear here or check 4
   ("every behavior has a declared hits-per-use", line 403) fails: the five
   old strings `ricochet` / `jab_volley` / `volley` / `seeker` / `fire` were
   passing via `HITS_PER_USE` or via the exempt list at line 405, and both
   references should be deleted once no row uses them.
   **Then re-run the ladder law** (no weapon below 85% of the
   median of the tier below, per family); several of these numbers move
   meaningfully (Galeprong 3.0 vs the old `jab_volley` 3.0 is flat, but
   Reed Javelins 1.4 vs 3.0 is a real cut and may drop below the T2 floor —
   raise the row's damage, never invent hits).
8. **`test_dispatch_node.KIND_ALIAS`** — if the special's `type` differs from
   the projectile's `kind`, add the mapping with a reason. And note the whiff
   pass (`DISPATCH_WHIFF=1`, empty room): every verb above is designed to
   produce something on a miss, so all 27 must pass it.

**Then measure, do not declare** (`test_realhits_node.gd`): add the 27 ids to
`PROBE_IDS` in batches and hold the declared hits against real
`take_damage` counts at 90 / 170 / 280px. Six of these verbs have a range
band (Stormprong's late split, Twinnock's crossing, Pyrelight's short plant,
Marrowsplitter's 330px, Cinder Rod's gout, Magma Writ's ground run) and will
read as dead at exactly one probe distance — that is why the probe uses three.

**Player-side routing** that must change:
- `player.throw_javelin_volley()` (5572) currently fans everything at a fixed
  spread. B1/B2/B4/B5/B6 need per-shaft offsets, launch delays and a group
  identity, so it should become a dispatcher on the special's type.
- `player.spawn_arrow()` (6946) needs the three optional `arrow.gd` fields
  (§4) and a bail-out to `launch_projectile` for the three bows that move
  engines.
- `player.call_a_marcher()` (6420) takes a position instead of a victim (D3).

---

## 8. SHARED ENGINES WORTH KEEPING

Honest cases. Sharing code is only a problem when it makes two weapons *look*
the same; these five share machinery while looking nothing alike.

**1. The relay core — one `_relay_next(radius, forward_only) -> Node2D`.**
Hookbill, Tithe Gatherer, Courier's Bad News, Grave Courier and The Final Debt
all need "find the next un-touched living body within R, re-aim, reset
`traveled`". That search is 20 lines and it is already duplicated four times
in `_on_body_entered` (`howl_bolt` 1316, `debt_deep` 1344, `ricochet` 1596,
plus `rumor`). Extract it once. The differences between the five are what
happens *around* the call — an orbit, a parabola, a speed multiplier, a
planted marker, a drawn segment — not the search itself. Keeping five copies
of a nearest-body loop is how they became identical in the first place.

**2. The re-cut clock — one `_allow_recut(gap) -> void`.**
Galeprong (0.22), Choir of Points (0.25), Night Parade (0.30) and Magma Writ
(0.30) all need `hit_bodies` cleared on a timer, and so do the four existing
verbs that already hand-roll it (lash 0.5, orbiter 0.35, edict 0.17,
heavenpoint/frost 0.22). One helper, one field, eight callers — and the
next piercing verb someone writes inherits the fix instead of the bug.

**3. The floor-follower — one `_glue_to_floor(step) -> bool`.**
Magma Writ needs exactly the raycast-down-and-follow-the-slope mover that
`kneeling_stone` (`_tick_boulder`, 3302) and `sunder_wave` already use. This
is a *legitimate* share: the weapons read completely differently (a boulder
whose damage is its gathered pace and which shatters into scree; a molten
mass that stamps glyphs and flashes them all at the end) and the shared part
is pure terrain plumbing that nobody sees. Duplicating it would just mean two
places to get slope handling wrong.

**4. The span hitbox — one small `SpanHitbox` helper.**
Ferryman's Bow (a 40px cord between two shafts, single hit, snaps) and Choir
of Points (a 68px band between three shafts, re-cut every 0.25s, narrows as
shafts die) are the same primitive: *a damaging region stretched between
sibling projectiles that is freed when its anchors are*. Two configurations of
one node. They look nothing alike — one is a taut rope you aim the gap of, the
other is a shearing wall four tiers later — and building it twice would give
us two different answers to "what happens when one anchor dies".

**5. The two Seekers stay on one engine — `arrow.gd`.**
Pale Seeker and Hale Seeker genuinely are one steering system with two
parameter sets (target rule: weakest vs largest; turn rule: continuous 4 rad/s
vs one 90° snap at 40% range; terminal: split vs pierce-2). This is the
`DESIGN_LAWS` §1 stat-rung law used *correctly*: one rig, and the identity
carried by the rule and the trail (a long pulled ribbon versus a hard kink)
rather than by a second implementation. It is only a duplication problem when
the two rungs also *behave* identically — which is precisely what the current
shared `homing` flag does, and what the D1/D2 split fixes.

**One case that is NOT worth sharing, for the record:** the four fire wands.
It is tempting to keep them all on `explode()` with different radii and colour
tints, because that is one function and four constants. That is exactly the
duplication this document exists to remove — `explode()` (1790) with a
different radius is the same event four times, and the owner will see it as
one weapon with four names.

---

## 9. HITS-PER-USE SUMMARY (feeds `test_weapondps_node.HITS_PER_USE`)

| id | weapon | tier | old | new | why |
|---|---|---|---|---|---|
| `wpn_ratterdart` | Ratter's Dart | 2 | 1.8 | **1.3** | dart stops on the first body; one grit chip |
| `wpn_hookbill` | Hookbill | 3 | 1.8 | **2.0** | entry + the swing round each body |
| `wpn_finchbolt` | Finchbolt | 3 | 1.8 | **1.6** | the flock spreads; a lone target sees 1-2 |
| `wpn_tithegather` | Tithe Gatherer | 3 | 1.8 | **1.8** | the hop plus a dropped weight |
| `wpn_courierrod` | Courier's Bad News | 3 | 1.8 | **1.5** | speed, not multi-hit |
| `wpn_gravecourier` | Grave Courier | 7 | 1.8 | **2.8** | the stop, the marker payout, the wisps |
| `wpn_finaldebt` | The Final Debt | 7 | 2.6 | **2.4** | the stop plus the ledger snap |
| `wpn_reedjavelin` | Reed Javelins | 2 | 3.0 | **1.4** | parallel pair; a normal body catches one |
| `wpn_stormprong` | Stormprong | 3 | 3.0 | **2.2** | 3 at point blank, 1 at range |
| `wpn_gullprong` | Gullwing Prong | 3 | 3.0 | **1.6** | the braid crosses a body once or twice |
| `wpn_reedvolley` | Reedsong Volley | 3 | 3.0 | **2.4** | ~2 shafts + 2 rings |
| `wpn_galeprong` | Galeprong | 4 | 3.0 | **3.0** | helix re-cuts at 0.22s |
| `wpn_hawkvolley` | Hawks in Formation | 4 | 3.0 | **2.0** | lead + one closing arm |
| `wpn_marrowprong` | Marrowsplitter | 4 | 3.0 | **2.2** | ~2 shafts; slivers go sideways |
| `wpn_ferrybow` | Ferryman's Bow | 2 | 2.0 | **1.2** | cord OR shaft, once |
| `wpn_paleflight` | Pale Flight | 2 | 2.0 | **2.0** | both follow the same line |
| `wpn_twinnock` | Twinnock Bow | 3 | 2.0 | **1.5** | 2.0 at the crossing, 1.0 elsewhere |
| `wpn_finchvolley` | Finchstorm | 3 | 2.0 | **1.4** | inaccurate by design |
| `wpn_choirbow` | Choir of Points | 4 | 2.0 | **2.6** | band re-cuts at 0.25s |
| `wpn_larkstorm` | A Storm of Larks | 4 | 2.0 | **1.6** | ballistic, no pierce |
| `wpn_paleseeker` | Pale Seeker | 3 | 1.6 | **2.2** | shaft + a returning child |
| `wpn_haleseeker` | Hale Seeker | 3 | 1.6 | **1.6** | pierce 2, no split |
| `wpn_nightparade` | Night Parade | 8 | 3.6 | **4.0** | lantern grind + marchers now unconditional |
| `wpn_foxfirewand` | Foxfire Wand | 2 | 1.0 | **1.5** | pop sparks |
| `wpn_cinderrod` | Cinder Rod | 2 | 1.0 | **2.0** | embers + a patch tick |
| `wpn_pyrelight` | Pyrelight | 3 | 1.0 | **4.0** | ~3.5 beats over a 1.0s hold |
| `wpn_magmawrit` | Magma Writ | 4 | 1.0 | **3.2** | re-cut pass + glyphs + final flare |

Nine of these go **down**. The ladder law is anchored to the tier below, so
after wiring, run `scratchpad/gate.ps1 -Tests @("test_weapondps_node")` with
`DPS_DETAIL=1` and fix any new floor violations by raising the **row's damage
number**, never by inflating a declared hit count — the whole reason
`test_realhits_node.gd` exists is that one inflated declaration made a weak
weapon read as the second-strongest Monarch in the game.
