# REWORK — THE FROST-SHARD ELEVEN AND THE CLEAVE TEN
Twenty-one weapons, twenty-one new verbs. Written 2026-07-30 against
`weapon_roster.gd` @ 246 rows. **Design document only — no code was touched.**

---

## THE PROBLEM, PRECISELY

`weapon_roster._special_for()` collapses distinct roster behaviors onto shared
projectile types. Two collapses are the worst offenders in the whole roster:

| special type | fed by behaviors | weapons | what the player sees |
|---|---|---|---|
| `frost_shard` | `"bolt"` (8 rows) + `"frost"` (3 rows) | **11** | the same icy dart, every time |
| `cleave` | `"cleave"` (10 rows) | **10** | the same heavy swing + the same generic CARVE crescent |

The frost group is the more embarrassing of the two, because eight of the
eleven are `"bolt"` — weapons named for **chalk, tallow, moss, leeches, salt,
hollowness and storm** that all fire *ice*. Rule 2 (name = material = effect)
is violated eleven times over by a single `match` arm.

The cleave group is subtler. Its shared arc — *hit every body in the swing* —
is honest and worth keeping. What is dishonest is the follow-through:
`player.gd:4799` throws the identical `flying_slash` (0.55x dmg, 430 speed,
150 range) off all ten. A shovel, a bell, a scythe and a clock all shed the
same wind-crescent.

**So the fix is asymmetric:**
- **Frost eleven** → eleven genuinely new projectile kinds. Nothing is shared
  except a muzzle flash.
- **Cleave ten** → keep the multi-body arc (it *is* the family), and replace
  the one generic CARVE with ten different follow-throughs.

---

## STANDING CONSTRAINTS EVERY SPEC BELOW OBEYS

1. **The whiff rule** (dev, 2026-07-30 — enforced by `test_dispatch_node.gd`
   with `DISPATCH_WHIFF=1`): the verb must produce something visible on the
   *click*, not only on a hit. Every spec names its whiff behaviour
   explicitly. `cleave` is currently listed in that test's
   `NO_NODE_EXPECTED` — after this rework, **all ten come off that list**.
2. **Never hard-CC a boss.** Freeze / root / bind / topple apply to ordinary
   bodies only; a boss gets the damage and a flinch on the same schedule, and
   the rest of the verb still plays out around it. (`deepwood_boss_rule`.)
3. **Power lives in the verb.** No spec below moves a damage or cooldown
   number. The `damage` / `cooldown` columns in the roster stay exactly as
   they are; all multipliers quoted (0.55x, 1.4x…) are *internal* to the new
   verb, not buffs to the row.
4. **Everything is Polygon2D / Line2D.** No sprites. Additive =
   `CanvasItemMaterial.BLEND_MODE_ADD`, used for *light* only; earth, stone,
   wood and salt are drawn solid on purpose — half the readability in this
   document comes from which weapons glow and which stubbornly don't.
5. **Motion is eased, never popped.** Where a spec says "over 0.25s" it means
   a tween; where it says "instant" (lightning, the coffin's shut) the snap is
   the point and the *geometry* still grows so the eye can follow it.
6. **Every behavior needs a `HITS_PER_USE` line** in `test_weapondps_node.gd`
   or the audit fails. Declared per weapon below and collected in one table
   at the end.

---

# FAMILY A — THE CLEAVE TEN
*Melee. Heavy. Slow. The arc takes the room, not one target.*

**What stays shared:** `player.gd:4738` — the loop that damages **every** body
in `$AttackArea`, with knockback per body and `apply_omnivamp(total)`. That is
the family's honest common ground and all ten keep it verbatim.

**What is replaced:** `player.gd:4799-4804` — the one-size CARVE. Delete it,
and dispatch on the row's new behavior key instead.

The ten verbs, one line each, so the family reads at a glance:

> dig · shunt · **excavate** · topple · reap · toll · score-and-split ·
> count-down · call-up · stop-the-clock

---

## A1 — Pit Shovel
`wpn_pitshovel` · **T1 common** · dmg 11 · cd 0.85 · behavior key `spadespray`

**Verb:** the swing scoops the floor and flings a low spray of dirt and gravel
forward, and swinging with your feet on the ground throws twice the spray that
swinging in mid-air does.

**Motion (0.30s total).** Overhead-to-low scoop over 0.18s; the blade bites the
ground at the arc's bottom (a 0.04s hitch — the shovel *catches*); then a 0.12s
flick launches the debris forward and low. Clods leave at 15-40° above
horizontal at 260-340 px/s with `arc_gravity` ≈ 620, land 90-130 px out,
bounce once at 30% and stop. Total life ≤ 0.45s.

**Visual.** 7 irregular pebble `Polygon2D`s, 3-5 px, four-to-six-point blobs in
three muddy tones — `(0.35,0.28,0.20)`, `(0.28,0.23,0.18)`, `(0.42,0.36,0.26)`
— each rotating on its own 1.5-3 rad/s spin. Under them, one dust wedge
`Polygon2D` (a trapezoid) widening 20 → 46 px and fading over 0.25s at
`(0.55,0.50,0.42, a 0.35)`. **Nothing additive.** This is the one weapon in the
document that emits no light at all, and that absence is its tier-1 identity.

**Grounded/airborne dial.** Feet on floor → 7 clods. Airborne → 2, and no dust
wedge. (`DESIGN_LAWS §9`, the player-state multiplier — the cheapest kind of
skill expression, and it teaches new players to fight planted.)

**Whiff:** clods fly regardless. The verb *is* the spray.

**Hits on one body: ~1.7** (the arc, plus one clod — the spray overlaps, so a
body catches one, rarely two).

**Distinct because:** it is the only gravity-affected debris throw, the only
unlit verb, and the only one whose output is gated on the player's own footing.

---

## A2 — Cellar Mallet
`wpn_cellarmallet` · **T1 common** · dmg 10 · cd 0.9 · behavior key `hoopshunt`

**Verb:** a flat cooper's blow that shunts everything in the arc backwards as
one group — and anything that slams into a wall (or into another body) at the
end of the shunt takes a second thud.

**Motion (0.24s).** Short high-to-low chop, 0.14s down, **dead stop on
contact** — no follow-through, mallets don't have one — then a 0.10s hold at
the bottom before recovery. The shunt is a *shared* vector: every body hit
travels the same direction and the same 70 px, so a group stays a group. Slam
resolution happens at the end of the shunt, ~0.18s later.

**Visual.** One squat impact ring: a `Line2D` ellipse (x-radius 12 → 40 px,
y-radius 40% of that — a ground-plane circle read in side view), width 4 → 1,
dull oak `(0.55,0.40,0.26)`, **not additive**, over 0.18s. Four straight
shock-lines (`Line2D`, 10 px, width 2, same colour) stab outward at 30° / 150°
/ 210° / 330°. On a slam: a 5-point white star `Polygon2D` (10 px) drawn at the
contact point for 0.12s plus three chip pebbles.

**Whiff:** the ring and shock-lines draw on every swing. The slam is the bonus,
not the verb.

**Hits on one body: ~1.5** (arc 1.0 + a 0.6x slam thud, which only pays when
you fight with your back to the room and theirs to the wall).

**Distinct because:** it is the only verb whose second hit is *supplied by the
level geometry*. It rewards fighting near walls, and it herds — one blow moves
a whole knot of bodies together instead of scattering them.

---

## A3 — Gravekeeper's Spade
`wpn_gravespade` · **T2 uncommon** · dmg 14 · cd 0.8 · behavior key `opengrave`

**Verb:** the swing takes a spadeful out of the world — leaving an open grave
in the floor that anything walking in falls into and has to climb out of —
and the sod flies over your shoulder to land behind you as a step you can
stand on.

**Motion (0.55s incl. the sod's flight).** Low scooping sweep along the ground
over 0.20s. At the arc's end the hole *opens*: the floor polygon shrinks
downward over 0.12s (eased, so the earth reads as being lifted out, not
deleted). The sod leaves the blade on a clean ballistic arc — up over the
player's head, 0.35s, one full tumble (rotation tween `0 → TAU`) — and lands
~60 px behind, squashing on impact over 0.08s into a low mound.

**Visual.** *Hole:* a dark trapezoid `Polygon2D` `(0.10,0.09,0.08)`, 56 px
wide × 26 px deep, with a lighter earth lip `(0.36,0.30,0.22)` drawn as a
4 px band along its top edge, and two crossed root `Line2D`s (1.5 px,
`(0.30,0.24,0.16)`) hanging into it. *Sod:* one rounded brown block
`(0.32,0.26,0.19)` with a 3 px grass-green top edge `(0.38,0.55,0.28)`.
*Mound:* the same block, y-scaled to 0.55.

**Effect.** Hole lives 4.5s. Any ordinary body entering takes 0.8x from the
lip and is held 0.7s while it climbs out (the climb is a visible bob, not a
freeze). The mound behind you is a genuine 20 px standable step for the same
4.5s. A boss steps over the hole and takes the lip bite only.

**Whiff:** this is the family's *best* whiff — the hole and the mound exist
whether or not anything was in the arc. You can dig defensively.

**Hits on one body: ~1.7** (arc 1.0 + the 0.8x lip, once per entry).

**Distinct because:** it is the only verb that **edits the terrain** — a trap
in front and cover behind, both from one swing. Nothing else in the roster
gives the player a floor tile.

---

## A4 — Orchard Feller
`wpn_orchardaxe` · **T2 uncommon** · dmg 15 · cd 0.95 · behavior key `fellblow`

**Verb:** the axe notches whatever it hits, and a beat later that body **tips
over like a felled tree**, falling in the swing's direction and crushing
anything it lands across.

**Motion (0.22s swing + 0.55s fall).** A big committed round-house from over
the shoulder, the head describing ~200° in 0.22s — the widest arc in the
family. The fell plays out **on the victim**: lean to 12° over 0.15s, a
0.10s *hang* at ~30° (the beat that sells it), then over in 0.30s with an
ease-in, and a 0.06s ground-bounce settle.

**Visual.** *Notch:* two overlapping wedge `Polygon2D`s in pale birch
`(0.86,0.80,0.66)` drawn on the struck body, held 0.5s. *Chips:* three
6 px flakes spinning off the notch with gravity. *Landing:* a horizontal dust
`Line2D` (width 3 → 1, `(0.60,0.55,0.45)`) snapping outward 70 px each way
from where the body lands, over 0.12s.

**Effect.** Bodies within 60 px of the landing take 0.7x crush damage. The
felled body is prone 0.8s. **Bosses do not topple** — they take the notch and
a stagger flinch, and the dust line still fires off the notch point so the
verb still reads.

**Whiff:** the axe bites the floor at the arc's end — three chips, a notch
decal left on the ground for 2s, and the same dust line at half length.

**Hits on one body: ~1.6** (arc 1.0 + a 0.7x crush from a neighbour going
over — averaged across "is there anyone next to it", which is often).

**Distinct because:** it is the only verb that **uses enemies as the weapon**.
Its damage scales with how tightly packed the room is, and it is the only
knockdown in the family (everything else here lifts or shoves).

---

## A5 — Furrow Scythe
`wpn_furrowscythe` · **T3 rare** · dmg 19 · cd 0.9 · behavior key `reaprow`

**Verb:** the cut leaves the blade and keeps running along the floor as a
low reaping line, taking every body in the row at full strength — but it
cannot climb, so a knee-high ledge stops the harvest.

**Motion (0.26s swing + 0.4s run).** The slowest wind-up in the family: a very
low, nearly flat horizontal sweep held at ankle height. The line then advances
260 px in 0.40s at ~650 px/s, **hugging the floor** — it steps *down* over
ledges (falls, then resumes on the surface below) and **dies against any
obstruction taller than 24 px**. It never tilts: the crescent stays horizontal
the entire flight, which is what makes it read as a harvest and not a slash.

**Visual.** A thin, long crescent — `Line2D`, 3 px, ~90 px across, harvest-gold
`(0.82,0.74,0.42)` with a darker under-edge line (2 px, `(0.48,0.40,0.20)`)
offset 2 px down. Behind it, a stubble trail: 5 tiny standing triangles
`(0.66,0.60,0.34)` left at 40 px intervals, each flattening to the floor over
0.2s in the order the line passed them (a wave, not a pop). No glow — brass-
gold pigment, not light.

**Effect.** **Even-pierce** (`DESIGN_LAWS §11`): every body in the row takes
the full 0.75x, no falloff. This is the family's only even-pierce and it is
deliberate — the scythe's identity is *width*, not depth.

**Whiff:** the line leaves the blade every swing regardless.

**Hits on one body: ~2.0** (arc 1.0 + the row-line 0.75x; the value is that
it does that to six bodies at once).

**Distinct because:** it is the only floor-following, terrain-reading
horizontal line, and the only even-pierce. Its weakness — one step of
elevation defeats it — is as legible as its strength.

---

## A6 — Bell Hammer
`wpn_bellhammer` · **T3 rare** · dmg 22 · cd 1.0 · `knockup` · behavior key `belltoll`

**Verb:** the strike doesn't push, it **rings** — three brass rings leave the
impact point one after another, each wider and quieter; the first lifts
everyone it catches off their feet, the second and third only daze.

**Motion (0.26s + 0.9s of rings).** Overhead strike, 0.16s down, and on contact
the hammer **rebounds** 20 px upward over 0.10s (bells push back — that recoil
is the tell that distinguishes this from every other maul in the family).
Rings depart at t = 0.00 / 0.28 / 0.56s, each expanding over 0.30s.

**Visual.** Three concentric `Line2D` circles from the contact point, radii
30 / 58 / 90 px, widths 3 / 2 / 1, brass `(0.86,0.72,0.36)` fading alpha
0.9 → 0 across their expansion. **No fill** — a ring of sound is empty. One
vertical shimmer bar (`Polygon2D`, 4 × 26 px, additive, `(1.0,0.94,0.7)`) over
the hammer head at the instant of contact and gone in 0.10s.

**Effect.** Ring 1 = 0.0x + the row's `knockup` (the lift *is* its payload).
Ring 2 = 0.5x + `slow` 1.2s ("dazed"). Ring 3 = 0.35x + `slow` 1.2s.

**Whiff:** all three rings expand from wherever the head landed, on every
swing.

**Hits on one body: ~1.9** (arc 1.0 + 0.5 + 0.35).

**Distinct because:** it is the only expanding-ring verb, the only one whose
damage grows *quieter* over time, and — importantly — it is a **spatial** bell
where A8 below is a **temporal** one. Bell Hammer's payload is a shape that
exists NOW; Toll of the End's is a clock. See "Shared engines" for the one
primitive they may legitimately share.

---

## A7 — Quarry Maul
`wpn_quarrymaul` · **T3 rare** · dmg 21 · cd 1.05 · `knockup` · behavior key `scoresplit`

**Verb:** the first blow **scores** a foe — a white stone-fracture web spreads
across its body — and the next blow on a scored foe **splits** it, bursting
into shards that fly out and cut everything nearby.

**Motion.** Both swings are the same slow two-handed overhead slam (0.20s
down, hard stop). The *split* swing adds a 0.06s freeze-frame at contact — the
world hitches, then the shards go. Shards leave at 180-260 px/s in a 200°
upward fan with gravity, land, and fade over 0.3s.

**Visual.** *Web:* 4 thin `Line2D` branches, 1.5 px, `(0.86,0.86,0.90)`, drawn
across the body's bounds, each growing from a shared origin over 0.25s (the
branches unzip in sequence, 0.06s apart) and holding ~4s at alpha 0.75.
*Split:* 8 wedge `Polygon2D` shards, 6-10 px, `(0.60,0.58,0.60)` with a
lighter top facet `(0.78,0.77,0.80)`, each with its own spin.

**Effect.** Split = 0.9x in a 90 px radius, and the row's `knockup` rides on
the **split**, not the swing. Web lasts 4s, so the rhythm is forgiving.

**Whiff:** the maul cracks the *floor* — a fracture web decal on the ground,
2.5s, and the first foe to step on it is scored for free. A whiffed swing is
therefore a trap you laid.

**Hits on one body: ~1.5** (averaged over the two-swing rhythm: swing one is
1.0, swing two is 1.0 + 0.9).

**Distinct because:** it is the only **set-up-then-payoff rhythm** in the ten —
the only cleave that asks you to focus one target instead of spreading. It is
the family's counter-argument to itself.

---

## A8 — Toll of the End
`wpn_tolloftheend` · **T4 epic** · dmg 28 · cd 1.05 · `knockup` · behavior key `deathcount`

**Verb:** every body the swing touches is given an hour of death — a bronze
gauge closes over its head for 2.5s, and when it runs out the toll lands; if
the toll kills, the count **jumps to the nearest living foe with one stroke
already spent**.

**Motion (0.45s swing).** A slow, ceremonial pendulum: back 0.25s, through
0.20s, and then the bell head **swings on past the arc**, hanging behind the
player for 0.30s before settling. That long follow-through is the family's
most distinctive silhouette — every other maul stops dead.

**Visual.** Over each marked body: a bell-arc outline `Line2D` (2 px, bronze
`(0.78,0.60,0.30)`) drawn as an arc-gauge that closes from 360° to 0° over the
count. At zero it snaps to a solid bell `Polygon2D` silhouette that flashes
white for 0.06s and drops out of frame downward. On a spread, one thin bronze
thread `Line2D` (1 px) connects the dead body to the newly marked one for
0.20s. **The gauge is the only UI-like element in the document and that is
deliberate — it is a clock, the player must be able to read it.**

**Effect.** Toll = 1.1x, and the row's `knockup` fires with it. A jump inherits
a 1.7s count instead of 2.5s, so a chain accelerates visibly. Bosses get the
gauge and the toll on the same schedule; they simply aren't lifted.

**Whiff:** the note hangs where the arc ended — a floating bronze gauge, 1.5s
— and the first foe to touch it takes the mark.

**Hits on one body: ~2.1** (arc 1.0 + the 1.1x toll; the spread is crowd
value, not single-target value).

**Distinct because:** it is the only **delayed execution** and the only verb
that makes the *first* kill matter mechanically. Against a lone target it is
only a slow heavy maul; against a room it is a wave of deaths, and the player
can hear it coming.

---

## A9 — Barrow King's Maul
`wpn_barrowmaul` · **T4 epic** · dmg 26 · cd 1.0 · `knockup` · behavior key `barrowhands`

**Verb:** the swing wakes the household — a dead hand punches up out of the
floor under every body the arc touched, hits a beat later, and holds them
there while it sinks back.

**Motion (0.22s swing + 0.65s hands).** A heavy sideways sweep trailing grave
dust. At t = +0.25s the hands erupt: each rises 22 px over 0.12s with a small
overshoot (26 px, then settle to 22 — the overshoot is what makes it feel like
something *pushed through*), clenches over 0.08s, holds 0.20s, and sinks over
0.40s. The hands rise **in the order the arc touched their owners**, 0.05s
apart, so a crowd produces a running wave down the line.

**Visual.** Hand = a 5-finger silhouette `Polygon2D` in dark slate
`(0.20,0.22,0.28)` — solid, not translucent; these are *bodies*. Around its
wrist, a pale rim `Line2D` (1 px, `(0.60,0.66,0.75)`, **additive**) — the only
lit part, so the hand reads as dead-but-woken. At its base, three small loose
earth polygons pushed aside and settling.

**Effect.** Hand = 0.7x and roots the body 1.0s (ordinary bodies only; a boss
gets the hit and a 0.3s stagger). The row's `knockup` fires when the hand
*releases*, so bodies are lifted at the end, not the start.

**Whiff:** one hand rises at the arc's far point regardless — the household
answers the *call*, not the hit.

**Hits on one body: ~1.7** (arc 1.0 + the hand's 0.7x).

**Distinct because:** it is the only **summoned assist** in the melee family —
the only cleave where something other than the player deals part of the blow.
It shares grave-dirt flavour with A3, but A3 removes floor and A9 sends
something up through it: opposite directions, opposite payloads (trap vs. hit).

---

## A10 — The Eleventh Hour
`wpn_hourmaul` · **T5 legendary** · dmg 34 · cd 1.08 · `knockup` · behavior key `heldhour`

*The family's apex. Crown Rule: cleaner, not busier.*

**Verb:** everything the arc touches **stops** — held mid-motion, colour
drained — for 0.8s, while the maul's own damage keeps accruing unseen; then
the hour restarts and all of it lands at once.

**Motion (0.30s swing, 0.8s held, 0.15s release).** The swing is the slowest in
the family, deliberately. At contact, the struck bodies freeze *instantly* —
and the maul's own follow-through continues at completely normal speed. **That
contrast is the entire effect**: one object still moving in a stopped world.
At 0.8s, one crisp click, and everything resumes.

**Visual.** On each held body: a single brass clock-hand `Line2D` (2 px,
`(0.86,0.74,0.40)`, 18 px long) pivoting from 12 o'clock to 11 over the 0.8s —
one hand, nothing else. The body's `modulate` tweens toward grey
`(0.62,0.62,0.66)` over 0.15s and back over 0.10s on release. At release: a
ring of **eleven** tiny brass tick-marks (2 × 5 px `Polygon2D`s) flashing
outward from radius 34 → 70 px in 0.15s, then gone. The stored damage prints as
**one number**, not a stack (`DESIGN_LAWS §7` — the number theatre is the
payoff).

**Effect.** `freeze` 0.8s (ordinary bodies), then a stored delivery at 1.4x +
the row's `knockup`. **Bosses are never frozen**: a boss takes the clock-hand
mark and eats the 1.4x on the same schedule, unheld.

**Whiff:** the hour still stops. The sweep leaves a 100 px "held" bubble at the
arc's end for 0.5s (a faint grey lens `Polygon2D`, alpha 0.12, with the same
clock hand at its centre); anything entering it is caught for the remainder.

**Hits on one body: ~2.2** (arc 1.0 + the 1.4x release). The highest in the
family, correctly — it is the tier-5 rung.

**Distinct because:** it is the only **time** verb, the only stored-damage
payoff, and the visually *simplest* thing in this document — one clock hand and
a pause. That is what "apex" is supposed to look like (`DESIGN_LAWS §3`).

---

# FAMILY B — THE FROST-SHARD ELEVEN
*Wands. Eight of them are not cold at all and never should have been.*

**What stays shared:** the muzzle flash on `cast_wand_projectile`
(`player.gd:5591` — the existing 1.4x icon punch) and the grade girth/range
multipliers. Nothing else.

**What is replaced:** the `"bolt"` and `"frost"` arms of `_special_for()`
(`weapon_roster.gd:760-765`), split into eleven behavior keys. The
`frost_shard` kind itself **stays** — six hand-authored `inventory.gd` weapons
still use it legitimately (they are actual ice weapons), and it remains the
right default for a plain icy dart.

The eleven verbs, one line each:

> draw · drip · misfire · seed · drink · pour · bind · empty · fork ·
> write · **bury**

---

## B1 — Chalk Wand
`wpn_chalkwand` · **T1 common** · dmg 7 · cd 0.45 (the fastest wand here) ·
behavior key `chalkline`

**Verb:** it draws. Each cast puts a short chalk stroke on the air that hangs
there for 1.2s and cuts anything crossing it — and strokes drawn end-to-end
join into one longer line.

**Motion (0.12s draw, 1.2s life).** No travel at all. The stroke **draws
itself** from the wand tip outward to 96 px over 0.12s (append points to the
`Line2D` per frame, so the eye follows the hand), holds 0.8s, then **crumbles
from the far end back toward the origin** over the last 0.3s — points removed
in reverse order. The wand tip flicks like a pen: a 0.08s 20° rotation and
back.

**Visual.** `Line2D` width 4, near-white `(0.95,0.95,0.92)`, alpha 0.9, with a
second "grain" line under it at width 6, alpha 0.25, points jittered ±1.5 px so
the stroke is visibly *hand-drawn* rather than ruled. Three 2 px square chalk-
dust `Polygon2D` motes fall from random points along it with gravity. Not
additive — chalk is powder, not light.

**Effect.** Damages any body crossing the stroke, once per body per stroke. If
a new stroke starts within 24 px of an existing stroke's end, they merge into
one polyline (and the merged line's remaining life resets to 1.2s), so a
patient player can wall off a corridor.

**Whiff:** the stroke is the entire product. There is nothing to miss.

**Hits on one body: ~1.2.**

**Distinct because:** it is the only **static, zero-velocity** wand — a piece
of geometry the player places, not a thing they throw. At world zoom that
silhouette is unmistakable against ten travelling projectiles.

---

## B2 — Tallow Wand
`wpn_tallowwand` · **T1 common** · dmg 9 · cd 0.6 · behavior key `tallowdrip`

**Verb:** it throws a fat gob of hot candle-fat in a lazy arc; it splats where
it lands and stands up a small flame that burns for 3s.

**Motion (0.5s flight, 3.2s puddle).** A slow mortar lob — ~300 px/s launch,
`arc_gravity` 620 (the existing `lob` feel). The gob **squash-stretches along
its velocity** (scale x1.25 / y0.8 at speed, back to round at the apex), which
is the whole reason it reads as liquid. On landing it flattens over 0.08s and
spreads 14 → 28 px, and the flame rises out of it over 0.20s.

**Visual.** *Gob:* a rounded 7 px `Polygon2D` in warm wax `(0.94,0.86,0.62)`
with a darker underside crescent `(0.72,0.62,0.40)`. *Puddle:* a low ellipse
`(0.90,0.82,0.58, a 0.80)`. *Flame:* one 3-point additive teardrop
`(1.00,0.78,0.35)` leaning and flickering on a 0.2s looping scale
(1.0 → 1.15) + rotation (±8°) tween — smooth, never strobing.

**Effect.** The puddle applies `burn` to anything standing in it, ticking 0.3x
every 0.7s for 3s. **Burn duration is this family's tier ladder**
(`DESIGN_LAWS §4`), so a later tallow-kin weapon should extend the puddle, not
enlarge the flame.

**Whiff:** the puddle is the product; it lands and burns whether or not
anything was there.

**Hits on one body: ~2.2** (the splat + ~4 ticks at 0.3x).

**Distinct because:** it is the only **lobbed, gravity-bound** wand and the
only one that leaves a burning floor. It is slow and short — the honest
counterweight to the Chalk Wand's speed.

---

## B3 — Stubwand
`wpn_stubwand` · **T1 common** · dmg 8 · cd 0.55 · behavior key `stubmisfire`

**Verb:** it is a broken wand. Every cast coughs out 2-4 ragged sparks in a
random spread — and about one cast in six it produces a single **fat** spark
instead, which hits for triple and shoves *you* back a step.

**Motion.** Sparks leave in a 34° fan at 700 px/s but die at 150 px — the
shortest reach of any wand here, and the honest price of the jackpot. The fat
spark is slower (420 px/s), travels 300 px, and the player visibly recoils
12 px over 0.10s with a small camera nudge.

**Visual.** *Spark:* a 6 px jagged 4-point `Polygon2D` sliver, pale lilac
`(0.80,0.74,0.98)`, **no trail** — it pops out of existence rather than fading.
*Fat spark:* 16 px, white core `(1.0,1.0,1.0)` inside a lilac shell, with a
3-segment crackling `Line2D` trail and a 10 px puff at the muzzle. **The
jackpot is recoloured at spawn**, so the player sees it coming down the lane —
never a surprise number (`DESIGN_LAWS §7` / the Nebula-Blaze lesson).

**Effect.** Normal spark 0.5x each. Fat spark 3.0x, pierces two bodies.

**Whiff:** sparks always fly. Chaos doesn't need a target.

**Hits on one body: ~1.4** (2-4 sparks that spread; one or two land).

**Distinct because:** it is the only **random-output** wand, the only one with
self-knockback, and the only one whose cast-to-cast silhouette changes.

---

## B4 — Mosslight Wand
`wpn_mosswand` · **T2 uncommon** · dmg 12 · cd 0.55 · behavior key `sporepatch`

**Verb:** it seeds. A slow drifting spore-light sticks to the first surface or
body it touches and unfurls into a glowing moss patch that pulses; patches that
grow near each other **join up and pulse harder**.

**Motion (drift ~1.5s, patch 5s).** Drifts at 260 px/s, bobbing ±6 px on a
0.5s sine — slow enough to be shepherded. On contact it flattens against the
surface over 0.15s (scale toward the surface normal) and unfurls: five frond
triangles unfolding **one after another, 0.05s apart**, which is what makes a
static decal feel alive.

**Visual.** *Spore:* an 8 px soft disc `(0.55,0.85,0.50)` with a paler core and
a faint additive halo at alpha 0.25. *Patch:* a low irregular blob `Polygon2D`
`(0.30,0.62,0.34)` with five frond triangles `(0.60,0.90,0.55)`, pulsing scale
1.00 → 1.12 on every tick and easing back. *Link:* between joined patches, a
thin root `Line2D` (1.5 px, `(0.34,0.55,0.30)`) that grows across the gap in
0.2s.

**Effect.** Patch lives 5s, ticks 0.25x every 0.6s. Two patches within 70 px
link, and linked patches tick at 0.4x. Sticks to walls and ceilings too.

**Whiff:** the spore lands somewhere and grows. Always.

**Hits on one body: ~3.0** (the stick + ~8 ticks at 0.25x for a body that
holds its ground).

**Distinct because:** it is the only **stick-and-grow area denial** in the
eleven, and the only wand that rewards clustering your own casts. It is also
the only one that meaningfully uses walls and ceilings.

---

## B5 — Leechlight
`wpn_leechwand` · **T2 uncommon** · dmg 10 · cd 0.5 · `poison_w` · behavior key `drinkthread`

**Verb:** it drinks. Nothing is thrown — a thin red thread snaps taut between
you and the nearest foe in range and pulls for 0.8s, ticking damage and giving
a little of it back to you as health.

**Motion (0.8s).** The thread snaps taut **instantly** (that snap is the
impact), then sags into a shallow catenary and pulses: four bead-lights travel
along it *from the foe to you*, one every 0.2s, each accelerating slightly as
it arrives. On expiry the thread recoils toward your hand over 0.12s and
vanishes.

**Visual.** *Thread:* `Line2D` width 2, dark carmine `(0.55,0.10,0.16)`, five
points with the mid-point sagging 10 px (sag tweened, so it breathes).
*Beads:* 4 px additive circles `(0.90,0.30,0.35)` sliding along it. *Your end:*
a small pale glow `(1.0,0.6,0.6, a 0.4)` that brightens by 30% each time a bead
arrives and settles back — the heal, made visible.

**Effect.** Four ticks of 0.35x, each returning 1 HP through the existing
`apply_omnivamp` path. The row's `poison_w` is applied once, at the snap, so
the foe keeps rotting after the thread breaks. Range 320 px; breaking line of
sight or walking out snaps it early with a visible recoil.

**Whiff:** the thread reaches out ~200 px, finds nothing, curls, and coils back
over 0.3s. Visible, costed, harmless — the honest whiff.

**Hits on one body: ~1.6** (4 × 0.35x + the poison).

**Distinct because:** it is the only **tether** and the only **self-heal** in
the eleven, and the only wand with no projectile node at all. Its weakness is
structural: it needs a target already in range, so it cannot open a fight.

---

## B6 — Brookwand
`wpn_brookwand` · **T2 uncommon** · dmg 10 · cd 0.5 · `slow_w` · behavior key `brookflow`
*(currently `frost` — keeps a cold identity, but as **water**, which is what a
brook is)*

**Verb:** it pours. A running band of brook-water flows forward along the
ground, over ledges and **down holes**, soaking and slowing everything it runs
across for as long as it keeps running.

**Motion (1.2s).** The head advances at 340 px/s **hugging the floor**: where
the floor ends it falls under gravity and resumes running on whatever surface
it lands on. A tail follows 0.5s behind the head, so the water reads as a
moving **band** ~170 px long, not an ever-growing line. It stops against a wall
taller than 40 px, pooling briefly before dying.

**Visual.** A 10 px-tall ribbon `Polygon2D` strip whose **top edge is a sine
offset animated along its length** (2 cycles/s, amplitude 3 px) — that
travelling wave is the entire reason it reads as flow. Colour
`(0.45,0.72,0.90, a 0.75)`, with a brighter crest `Line2D` (2 px,
`(0.72,0.90,1.00)`) along the top and three white spray triangles at the head,
kicked upward and falling back.

**Effect.** Re-hits a body every 0.4s while the band passes it, at 0.6x, and
applies the row's `slow_w`. Marks bodies **wet** for 3s: while wet, `burn`
duration on them is halved. (Cheap, and it makes the water elementally real.)

**Whiff:** the stream runs regardless. It is a scouting tool as much as a
weapon — it shows you where the floor ends.

**Hits on one body: ~1.8.**

**Distinct because:** it is the only **terrain-following fluid** and the only
projectile in the roster that deliberately goes *down holes*. In a
Terraria-shaped world that reads instantly.

---

## B7 — Saltbinder
`wpn_saltwand` · **T3 rare** · dmg 16 · cd 0.55 · behavior key `saltring`

**Verb:** it binds. A handful of salt scatters into a ring of grains on the
ground; anything inside the ring cannot leave it — it is shoved back at the
edge — and the salt burns it each time it tries.

**Motion (0.45s to assemble, 3.5s life).** A wide underhand scatter: grains fly
out in a 60° fan over 0.20s, and each **arcs to its own place on the ring**,
arriving staggered over 0.25s so the circle assembles clockwise from the
throw side. It dies grain by grain in the same order over the last 0.4s.

**Visual.** ~16 tiny white squares (2 px `Polygon2D`, `(0.98,0.98,0.94)`) laid
on a 78 px-radius ellipse **flattened to 0.35 vertical** — a ground circle read
correctly in side view, which is the geometry rule that makes or breaks this
weapon. A faint additive white arc `Line2D` (1 px, alpha 0.20) threads the
grains, brightening to 0.8 along the segment a body is touching. On a touch: a
12 px white flare `Polygon2D` and four grain-sparks.

**Effect.** Ordinary bodies inside are shoved back inward at the boundary for
0.4x per contact. Bodies *outside* are not kept out — this is a prison, not a
wall. **Bosses are never bound**; they cross freely and take the 0.4x burn on
the way through.

**Whiff:** the ring lands and holds regardless. Cast it on a doorway ahead of
the fight.

**Hits on one body: ~2.4** (the scatter + several edge-burns from anything
that keeps pushing).

**Distinct because:** it is the only **containment** verb — the only weapon in
either family whose job is to keep enemies *somewhere* rather than to move,
hurt or kill them. Salt-as-binding is folklore-correct, so the name, the
material and the effect all agree.

---

## B8 — Hollowbolt
`wpn_hollowbolt` · **T3 rare** · dmg 15 · cd 0.5 · behavior key `hollowring`

**Verb:** it is empty. The bolt is a ring with nothing inside; it passes
through bodies *and through terrain* without hurting anything — and when it
reaches its end it **collapses**, and everything it passed through takes the
whole flight at once.

**Motion (up to 1.1s).** Flies straight and slow (300 px/s), phasing through
everything, `monitoring` off in the collision sense — it only *records* who it
overlapped. At max range (or the moment you cast again) it implodes to a point
over 0.10s, and the recorded bodies take their hits **in the order it passed
them, 0.04s apart** — a run of damage numbers down the lane
(`DESIGN_LAWS §7`).

**Visual.** An annulus: a 14 px-radius `Line2D` circle, width 3, bruised
violet-grey `(0.42,0.38,0.50)`, **no fill whatsoever**. Behind it, an
afterimage ring at 30% alpha spawned every 0.12s and fading over 0.25s — a
**stuttering** trail, not a smooth one, because the thing is hollow. Collapse:
the ring lerps radius 14 → 0 over 0.10s and one 6 px white dot flashes for
0.06s.

**Effect.** 1.0x per recorded body, **even-pierce**, no falloff, no cap.
Terrain is genuinely ignored — this is the family's through-wall weapon.

**Whiff:** the ring flies its full length and collapses on nothing. Legible,
and the reason the weapon needs its range to be visible.

**Hits on one body: ~1.3** (one body takes exactly one hit; the number is
raised slightly because a body can be re-recorded on a second bolt in flight).

**Distinct because:** it is the only **delayed, through-wall, non-colliding**
wand. Its cost is that nothing happens for up to a second — the waiting *is*
the weapon, and shooting through a floor at what you cannot see is its joy.

---

## B9 — Stormsliver
`wpn_stormsliver` · **T4 epic** · dmg 21 · cd 0.5 · behavior key `forktree`

**Verb:** it splinters the air. One thin white sliver leaves the wand, forks
into two, and each fork forks again — a single cast arriving as a small
lightning tree that rakes a whole slice of the lane.

**Motion (0.28s total, and it is essentially instant to the eye).** Trunk runs
90 px in 0.06s → forks at ±16°; each branch runs 70 px in 0.06s → forks at
±22°; four tips run 60 px and stop. The whole tree holds at full extent for
0.10s and then **fades from the trunk outward** over 0.12s, so the last thing
you see is the tips. Lightning does not ease — each segment appears at
constant speed — but drawing them as growing `Line2D`s (not popped-in
segments) is what keeps it readable at this speed.

**Visual.** Per branch: a `Line2D` core, width 3, pure white `(1,1,1)`, over a
wider additive under-line, width 7, `(0.66,0.78,1.00, a 0.40)`. Every fork
point gets a 5 px white flare `Polygon2D` that blooms and dies in 0.08s.
Segments are drawn with a 2-point mid-kink (±4 px perpendicular jitter) so
nothing in the tree is a straight line.

**Effect.** Each of the seven segments damages once per body, at 0.45x — so a
body standing deep in the tree eats three or four, and a body clipped by one
tip eats one. **Stepped-falloff is wrong here; each segment is a separate
instance** (`DESIGN_LAWS §11`).

**Whiff:** the tree grows into empty air. Best-looking whiff in the document.

**Hits on one body: ~2.2.**

**Distinct because:** it is the only **branching geometry** and the only wand
that arrives effectively instantly. Against every travelling projectile in this
family, "it's already there" is a silhouette all its own.

---

## B10 — Frost Writ
`wpn_frostwrit` · **T4 epic** · dmg 19 · cd 0.55 · `slow_w` · behavior key `writglyph`
*(a **writ** is a written order — so it should be written, and then it should
be carried out)*

**Verb:** it writes a sentence in frost across the air ahead of you — five
ice-glyphs hanging where written — and a beat later every glyph **executes**,
dropping an icicle straight down from itself.

**Motion (0.30s writing, 0.60s pause, 0.35s fall).** The glyphs are written
left-to-right along the aim direction, 40 px apart, each scaling in over 0.06s
with a small overshoot. Then the pause — long enough to be a real tell.
Then the icicles drop **in the same order, 0.05s apart**, falling up to 200 px
in 0.15s each and shattering on the floor.

**Visual.** *Glyph:* a small angular ice-rune — a 6-8 point `Polygon2D`,
`(0.72,0.90,1.00, a 0.90)`, with an additive halo at alpha 0.30 and a slow
±5° rotation while it waits. *Icicle:* a tall thin triangle, 5 px wide ×
34 px long, `(0.80,0.94,1.00)`, with a white leading edge and a 20 px
`Line2D` fall-streak behind it. *Shatter:* four 3 px shards popping outward
with gravity.

**Effect.** Icicle = 0.7x + the row's `slow_w`. The line of glyphs is placed by
**aim**, so you write it across an approaching row and the whole row is under
it when the sentence is carried out. Glyphs are unaffected by terrain; icicles
stop at the first floor beneath them.

**Whiff:** the sentence is written and executed regardless. This weapon
literally cannot whiff its verb, only its aim.

**Hits on one body: ~1.6** (a body under one glyph takes one icicle; the value
is the width of the sentence).

**Distinct because:** it is the only **write-then-execute** wand and the only
one whose damage arrives **vertically**. Where B6 flows along the floor and
B11 encloses, this one falls.

---

## B11 — Summer's Coffin
`wpn_summerscoffin` · **T7 ascended** · dmg 32 · cd 0.5 · `slow_w` ·
`rider: "coffin"` · `fx: frostbloom r160 dur 3.0` · behavior key `icecoffin`

*The family's apex. Crown Rule again: it must feel overwhelming and still be
one clean idea.*

**Verb:** it buries the season. A slab of black ice flies out and opens, mid
air, into a standing coffin of frost around the nearest foe; the box shuts, the
foe is held inside and takes the cold; then the coffin cracks, and every panel
of it flies outward as a splinter into everything else in the room, each one
standing a frost bloom where it lands.

**Motion (~1.45s, and it must flow as one continuous idea).**
- **0.00-0.18s — the throw.** The slab flies at 620 px/s, tumbling exactly
  once (rotation `0 → TAU`, eased out so it lands flat).
- **0.18-0.30s — the shut.** At contact it **stops dead** and four ice panels
  sweep in from four sides — top, bottom, front, back — meeting in 0.12s with
  a hard click. Each panel travels from 70 px out to its final face, eased
  *in* (accelerating), so the box slams rather than assembles.
- **0.30-0.90s — the hold.** The coffin stands. A slow shimmer band travels up
  its front face on a 0.6s loop. The held body is drawn **behind** the front
  panel (z-order) — you can see the shape of it through the ice, and that is
  the whole picture.
- **0.90-0.98s — the crack.** A single jagged `Line2D` runs top to bottom in
  0.08s.
- **0.98-1.45s — the burst.** Eight panel-shards fly out radially at 500 px/s,
  decelerating to a stop, each dying into a frost bloom over 0.35s.

**Visual.** *Slab:* a black-blue parallelogram `Polygon2D` `(0.12,0.16,0.28)`
with a 2 px pale rime edge `(0.78,0.90,1.00)`. *Panels:* four flat trapezoids,
face colour `(0.62,0.84,1.00, a 0.75)` over a **solid dark inner face**
`(0.10,0.14,0.24)` — this is critical: the coffin must read as *solid and
shut*, not as glow. Only the rime edges and the shimmer band are additive.
*Shards:* the panels themselves, broken into eight wedges, keeping their
colours. *Blooms:* the existing `frostbloom` fx at radius 160 — draw it as a
six-spike star `Polygon2D` lying flat on the ground (y-scaled 0.35) with a low
additive haze.

**Effect.** The held body takes three cold ticks at 0.45x while boxed, plus the
row's `slow_w`. Splinters 0.55x each, seeking the nearest bodies. Blooms slow
for 3s. **Bosses are never boxed**: the coffin closes on empty air beside the
boss and bursts on schedule, so the splinters and blooms still fly — the
spectacle is never taken away from the player, only the crowd control.

**Whiff:** the slab travels its full range, and the coffin closes on nothing
and bursts anyway. A closed empty coffin is a good look and a real area attack.

**Hits on one body: ~3.6** (3 held ticks at 0.45x + a 0.55x splinter + bloom
time). Top of this family, correctly.

**Distinct because:** it is the only **two-stage hold-then-burst** and the only
projectile in the roster that becomes **architecture**. Set against the other
cold weapons here, the three of them finally read as three different ideas:
B6 **flows**, B10 **falls**, B11 **encloses**.

---

# HITS-PER-USE, FOR THE DPS AUDIT
Paste into `HITS_PER_USE` in `test_weapondps_node.gd` (and remove `"cleave"`,
`"bolt"` and `"frost"` from the "known plain behaviors" whitelist at ~line 406
if all rows migrate).

```
# ---- the cleave ten, split (was one "cleave": 1.9) ----
"spadespray":  1.7,   # the arc + one clod; grounded-only, halved airborne
"hoopshunt":   1.5,   # the arc + a 0.6x slam, and only when terrain is behind
"opengrave":   1.7,   # the arc + the 0.8x lip, once per entry into the hole
"fellblow":    1.6,   # the arc + a 0.7x crush from the neighbour going over
"reaprow":     2.0,   # the arc + a 0.75x even-pierce row-line
"belltoll":    1.9,   # the arc + rings two and three (0.5x, 0.35x)
"scoresplit":  1.5,   # averaged over the score/split rhythm: 1.0 then 1.9
"deathcount":  2.1,   # the arc + the 1.1x toll (the spread is crowd value)
"barrowhands": 1.7,   # the arc + the hand's 0.7x
"heldhour":    2.2,   # the arc + the 1.4x stored release
# ---- the frost-shard eleven, split (was "bolt" 1.0 / "frost" 1.5) ----
"chalkline":   1.2,   # a static stroke; a body crosses it once
"tallowdrip":  2.2,   # the splat + ~4 puddle ticks at 0.3x
"stubmisfire": 1.4,   # 2-4 sparks that spread; the 1-in-6 fat spark averaged in
"sporepatch":  3.0,   # the stick + ~8 ticks at 0.25x if they hold ground
"drinkthread": 1.6,   # 4 ticks at 0.35x, and it pays back HP
"brookflow":   1.8,   # 0.6x re-hits every 0.4s as the band passes
"saltring":    2.4,   # the scatter + edge-burns from anything that keeps pushing
"hollowring":  1.3,   # one recorded body, one hit -- the value is the crowd row
"forktree":    2.2,   # 7 segments at 0.45x; a body deep in the tree eats 3-4
"writglyph":   1.6,   # one icicle per body at 0.7x; the value is the sentence
"icecoffin":   3.6,   # 3 held ticks at 0.45x + a 0.55x splinter + bloom
```

---

# SHARED ENGINES WORTH KEEPING
Being honest: **twenty-one new verbs do not need twenty-one new engines.**
Below is what should legitimately be written once and reused, and one case
where sharing should *stay* exactly as it is.

### 1. The cleave arc itself — KEEP SHARED, all ten
`player.gd:4738`'s "damage every body in `$AttackArea`" loop is not the
duplication problem; it is the family's *definition*. Ten weapons that all cut
through a crowd is correct. Only the follow-through (line 4799) splits.
**Saving: the largest single one available, and it costs nothing in feel.**

### 2. `ground_mark` — one lasting floor decal that reacts to entry
Needed by four specs: A3's grave (4.5s, bite + hold on entry), A7's whiffed
fracture web (2.5s, scores whoever steps on it), B2's tallow puddle (3.2s,
burn ticks) and B4's moss patch (5s, pulse ticks). One node — lifetime, an
`Area2D`, an `on_enter` and an `on_tick` callback, a `Polygon2D` the caller
fills in — serves all four. The repo already has `hazard_zone.gd` and the
standing-zone tick used by `sky_pillar`; extend that rather than adding a
fifth thing.

### 3. `staggered_row` — N things appear along a line, in order, hit, retract
A9's grave hands, B10's frost glyphs and icicles, and B7's salt grains all do
literally the same thing: place N children along a path, animate them in
sequence at a fixed gap, fire a hit, animate them out. Different art, identical
scheduler. **Write it once.** The 0.05s stagger is the shared soul — it is what
makes all three feel handmade instead of instanced.

### 4. The floor-follower mover — A5's reaping line and B6's brook band
Both need: advance horizontally, sample the floor beneath, step down over
ledges, fall under gravity where the floor ends, die against anything taller
than *N*. That is one mover with two skins — a gold crescent and a blue ribbon
— which is exactly `DESIGN_LAWS §6` ("to differentiate two weapons cheaply,
change the TRAIL, not the projectile body"). They will not read as the same
weapon, because one is a 3 px line and the other is a 10 px animated ribbon
that pools.

### 5. The expanding ring primitive — A2, A6, A10
One `_ring(centre, r0, r1, width0, width1, colour, additive, time)` helper.
Cellar Mallet uses it once in dull oak; Bell Hammer three times in brass at
three radii; The Eleventh Hour once as a tick-mark burst. Same call, three
unmistakably different weapons. This is a *primitive*, not an engine, and
sharing it is strictly correct.

### 6. The scheduled-payload engine — A8 and A10 SHOULD share it
Toll of the End and The Eleventh Hour are the same machine: mark a body, store
a damage number on it, run a timer, pay out. They differ in three parameters
and their art:

| | Toll of the End | The Eleventh Hour |
|---|---|---|
| delay | 2.5s (1.7s on a jump) | 0.8s |
| the body meanwhile | acts normally | frozen, desaturated |
| on payout | 1.1x, and **jumps on a kill** | 1.4x, releases |
| art | closing bronze bell-gauge | one brass clock hand |

Building these twice would be a mistake. Build the mark-and-pay engine once
with a `on_expire` callback and let the two rows pass different art and rules.
**Estimated saving: roughly half of A8 + A10.**

### 7. `frost_shard` itself — KEEP, for the six weapons that earned it
After this rework no roster row uses `frost_shard`, but six hand-authored
`inventory.gd` weapons still do (lines 232, 465, 667, 754, 784, 803) and they
are *actual ice darts*. Do not delete the kind, do not "clean it up". A plain
fast icy sliver is a perfectly good T1-T3 magic weapon; the sin was never the
dart, it was eleven weapons named chalk, tallow, moss, leech, salt, hollow and
storm being forced to fire one.

### 8. The wand muzzle flash — KEEP SHARED, all eleven
`cast_wand_projectile`'s 1.4x icon punch is the wand *class*'s signature and
should stay identical across all eleven. Differentiating the muzzle would
weaken the class read for no gain.

---

# SUGGESTED BUILD ORDER
The order minimises rework, because each block builds a shared piece the next
block needs:

1. **The two shared primitives first** — `_ring` (§5) and `ground_mark` (§2).
2. **The cheap whiff-safe cleaves** — A1, A2, A6. Small, self-contained,
   and they get `cleave` off the `NO_NODE_EXPECTED` list immediately.
3. **`staggered_row` (§3), then A9, B7, B10.**
4. **The floor-follower (§4), then A5 and B6.**
5. **The scheduled-payload engine (§6), then A8 and A10.**
6. **The remaining independents** — A3, A4, A7, B1, B2, B3, B4, B5, B8, B9.
7. **B11 last.** It is the apex, it needs the most eyes-on, and every earlier
   block teaches something it uses (the ring, the ground mark, the staggered
   row).

After each block: `test_weapondps_node.gd` (the hits-per-use declarations must
land with the behavior, never after) and `DISPATCH_WHIFF=1
test_dispatch_node.gd` (the whiff rule). Both will fail loudly if a behavior
key is added without its declaration — which is exactly what they are for.
