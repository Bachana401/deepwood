# GIF MOTION STUDY — SUMMONS SLICE (2026-07-29)
Method: wiki demo GIFs -> 8 keyframes each (incl. consecutive triplet) -> 2-3x NN contact
sheets -> measured in SOURCE px with player height ~ 48 px = 1.0 PL (player-length unit).
Cadence read off GIF frame-delay tables. NO pixels copied — numbers and motion grammar
only. Sources: terraria.wiki.gg pages, mirrored originals via the Fandom CDN (MediaWiki
imageinfo -> static.wikia.nocookie.net, `?format=original` to dodge WebP re-encode).
Slice = every minion staff / sentry / whip named in WEAPON_VERB_REFERENCE.md's SUMMONS
DEEP SCAN section, ~50 named weapons -> 39 demo GIFs studied (rod/staff sentry pairs
share one demo write-up since they summon the identical sentry; only mana cost differs).

## Finch Staff
MEASURED (350x202, 291f, 6.5s): bird perches on the player's shoulder (~0.25 PL) at
idle; on a target appearing it dive-bombs in a single fast swoop, pecks for a tick of
7, then returns to the shoulder. Cycle repeats roughly every 1.0-1.5s — one attack,
one return, no loitering mid-air.
MOTION: a tame pet that rides the player until something needs pecking, then a quick
there-and-back dive with no hover phase.
DEEPWOOD: starter minion behavior — perches on the wielder, dive-attacks on sight,
returns to perch; cheap tell for "this is the weakest tier."

## Slime Staff
MEASURED (380x176, 170f, 5.66s): Baby Slime is a small bouncing blob (~0.35-0.4 PL)
that hops onto the target and grinds via repeated contact bounces — ticks land in
bursts of 3-5 numbers (3-5 each) within about half a second, then a short reposition
gap before the next bounce-burst.
MOTION: a rubber ball with a grudge — it doesn't hover or aim, it just keeps landing
on the enemy, each landing worth a handful of cheap hits.
DEEPWOOD: cheapest melee-contact minion archetype: no travel animation, just
bounce-into-target bursts of 3-5 small ticks, silhouette a simple ball.

## Flinx Staff
MEASURED (350x178, 338f, 6.8s): a shaggy white pet (~0.45 PL) bounces into the
NEAREST dummy for stacked ticks of 4-6 (two to three per burst), then — shown
crossing to a second, farther target — will abandon its first kill and re-engage
whatever is closest, including targets several PL away.
MOTION: same bounce-grind contact loop as the Slime, dressed as a snow critter, with
a visibly eager re-target the instant something closer appears.
DEEPWOOD: bounce-contact tier 2: same verb as Slime Staff but the AI actively
re-picks the nearest foe mid-fight instead of finishing the current one.

## Abigail's Flower
MEASURED (491x418, 344f, 6.94s): Abigail is a human-height (~0.9 PL) floating ghost
who goes IMMOBILE directly above whatever she's attacking and rains down ticks of
4-6 in a steady stream (several per second while locked on); she does not chase or
melee, only positions overhead once per target and channels.
MOTION: a hovering spectral turret — she picks a spot above the enemy, plants
herself, and just keeps raining until the target is dead, then drifts back to the
player.
DEEPWOOD: the "immobile empowered caster" minion archetype — one strong pet that
must plant itself above a target before it deals any damage at all.

## Hornet Staff
MEASURED (350x290, 405f, 8.16s): a small striped hornet (~0.3 PL) hovers near
whichever enemy is present and fires a stinger projectile at range rather than
touching it — ticks of 8-9 land roughly once per second; between fights it just
flies loops near the player.
MOTION: a gunship pet — it keeps its distance and pokes with ranged darts instead of
diving in, the only minion in this batch that never actually touches its target.
DEEPWOOD: ranged-poke minion tier: hovers at ~1-2 PL standoff and fires a slow
stinger dart, teaches "not every pet needs contact damage."

## Vampire Frog Staff
MEASURED (418x159, 127f, 6.13s): the frog fires a long TONGUE LASH that visibly
crosses the entire ~8+ PL screen width to tag a distant target for a tick of 14, then
hops in to finish with a direct bite at melee range on the same target.
MOTION: two-stage predator — a full-screen tongue snipe from wherever it's standing,
followed by a hop-in bite once the tongue has connected once.
DEEPWOOD: hybrid range+melee minion: an near-unlimited-range tongue tag that pulls
the pet into melee follow-up — good template for a "lure then pounce" summon.

## Imp Staff
MEASURED (400x221, 309f, 6.24s): a winged imp (~0.45 PL) hovers roughly HALF-WAY
between the player and target and lobs fireballs from that standoff distance
(~2.5-3 PL), each burst igniting the target for 10-13 per hit; it never closes to
melee.
MOTION: an artillery pet — parks at a comfortable mid-range and keeps lobbing fire,
happy to let the explosion do the work instead of touching anything.
DEEPWOOD: mid-range lobber archetype: hovers at a fixed standoff (~half the
player-target gap) and arcs fireballs, contrast piece to the melee-bouncer minions.

## Spider Staff
MEASURED (500x255, 384f, 8.54s): the spider independently CLIMBS terrain — walls,
steps, a side alcove the player never enters — to reach a target the player has no
direct line to, then latches on and stacks ticks of 8-15 per bite in quick bursts;
in the sampled frames it reached and killed a target sitting in a completely
separate side chamber.
MOTION: the only minion here that solves geometry — it pathfinds across walls and
ledges on its own to bite whatever the player merely walked past.
DEEPWOOD: terrain-crawling minion: pathfinds over walls/ceilings to latching-bite
range independent of the player's own line of sight — built for our vertical shafts.

## Blade Staff
MEASURED (382x186, 322f, 6.44s): a small hovering dagger (~0.25 PL) darts out from
above the player to stab a target for a modest 5-7 per hit, then returns to hover;
cycle is quick (under a second dart, roughly 1s between attacks).
MOTION: a thrown knife that never runs out — quick dart-stab-return with no
lingering engagement.
DEEPWOOD: low-damage-but-armor-piercing dagger minion: fast dart-and-return cadence,
modest numbers by design (the pitch is defense penetration, not raw damage).

## Sanguine Staff
MEASURED (451x159, 162f, 7.63s): crimson bats idle in a symmetric FIXED FORMATION on
either side of the player (heart/slash idle FX bracket the wielder at rest), then
dash out individually to slash a target for a hefty 42-61 per hit before returning
to their slot.
MOTION: a squadron holding formation until called — the visible idle symmetry (bats
parked left/right of the player) is the tell that this is a late-game "many bodies,
one home position" pet.
DEEPWOOD: fixed-slot formation minion: 2+ pets idle in symmetric home slots around
the wielder and dash-return per attack; high per-hit damage marks it a late-tier pet.

## Optic Staff
MEASURED (415x265, 106f, 3.56s): the eye minion crosses the ENTIRE screen (~8+ PL)
in a fraction of a second between targets, ramming/lasering for a very consistent
27-30 per hit, engaging a new body every beat with almost no travel time visible
between frames.
MOTION: a ping-pong bullet — it doesn't hover near one target, it teleports its own
attention across the whole line, hitting hard and constantly relocating.
DEEPWOOD: hyper-mobile ram/laser minion: near-instant full-screen repositioning
between hits, consistent high per-hit damage, no idle phase.

## Pirate Staff
MEASURED (255x220, 150f, 5.1s): a human-sized (~0.85 PL) pirate crewman minion walks
up and melees with a cutlass for a hefty 24-32 per swing, in flurries of 3-4 swings
once engaged; it reads as a small humanoid ally rather than a critter.
MOTION: a hired sword — walks to melee range and just fights like a person, no
ranged phase, no hover, straightforward flurrying melee.
DEEPWOOD: humanoid melee-crew minion: full player-adjacent height, walks-to-melee
AI, flurry damage — the "you get a companion, not a pet" archetype.

## Pygmy Staff
MEASURED (421x171, 176f, 6.65s): a squat humanoid (~0.6 PL) pygmy throws a spear at
range for 15-24 per hit, then closes the rest of the way to keep meleeing once the
target is close; ticks continue at both ranges.
MOTION: a spearman who leads with a thrown weapon and finishes in melee — the
javelin toss is the tell before it commits to contact.
DEEPWOOD: thrown-then-melee minion: ranged opener into melee follow-up on the same
target, humanoid but stocky/short silhouette (distinct from Pirate's full height).

## Desert Tiger Staff
MEASURED (450x246, 410f, 8.76s): the tiger visibly GROWS across the demo — early
hits land 20-30, later hits from a bigger-bodied form land 40-56 — with a blurred
pounce/dash effect each time it closes distance; body size reads roughly 0.5 PL as
a cub scaling toward ~0.9 PL by the later frames.
MOTION: an evolving pet — the same minion gets visibly larger and hits harder as
the fight goes on, its pounce becoming a blur-dash rather than a walk.
DEEPWOOD: stack-to-evolve minion: cub -> adult growth curve tied to (re)summon count,
pounce-dash traversal — a minion whose silhouette is its own progress bar.

## Raven Staff
MEASURED (540x175, 156f, 5.4s): a small dark bird (~0.3 PL) crosses the full ~9+ PL
screen at high speed to dive-peck a target for 28-37, then flies clear across to
the opposite corner before returning — very little hover time, mostly transit.
MOTION: a fast dive-bomber constantly repositioning corner to corner, biting hard
each time it connects.
DEEPWOOD: high-speed dive minion: near-full-screen transit speed, solid per-hit
damage (matches Optic's ram tier but reads as a bird, not a UFO).

## Tempest Staff
MEASURED (565x215, 147f, 5.13s): a teal ray/crystal-shaped flyer (~0.5 PL) darts to
a target trailing a lightning streak and connects for 39-49 per hit, cycling to a
new target roughly every 1.5-2s.
MOTION: an electric strafing run — it doesn't hover, it commits to one lightning
dash per pass and immediately looks for the next body.
DEEPWOOD: post-endgame lightning-dash minion: high flat damage per pass, visible
electric trail as the tell for its tier.

## Deadly Sphere Staff
MEASURED (500x366, 436f, 9.26s): a spiked metal ball (~0.4 PL) rams a target for
30-38 on contact, then ROCKETS off-screen at extreme speed (full ~10 PL screen
crossed in under a frame's sample gap) before circling back for its next charge —
long dead-time between charges is the tradeoff for the ram's punch.
MOTION: dumb heavy momentum, Deepwood's Staff-of-Earth-boulder cousin but airborne —
it winds up off-screen and reappears already at full speed.
DEEPWOOD: ram-charge minion: infrequent but very fast full-screen charges, all its
damage lives in the charge itself rather than a sustained attack.

## Xeno Staff
MEASURED (585x270, 155f, 5.4s): the UFO TELEPORTS directly above whichever enemy is
nearest (no travel animation, just cut) and fires a vertical dotted laser straight
down for 27-37 per tick; when a second group is closer it teleports there instead
mid-fight.
MOTION: an unmissable sniper — it doesn't fly to the target, it simply appears
overhead and beams down, relocating instantly whenever priority changes.
DEEPWOOD: teleport-beam minion: zero travel time between engagements, vertical
unmissable laser — the "no dodge, only outrange" pet tier.

## Terraprisma
MEASURED (400x164, 245f, 4.9s): color-cycling prismatic blades (~0.4 PL each)
materialize above the player and dash to a target at blinding speed for 75-88 per
hit — by far the hardest-hitting minion sampled — then hover near the player
between dashes, tint shifting each time.
MOTION: a formation of jeweled knives that blink-dash to butcher whatever's in
range and re-form at the wielder's side, never idle for long.
DEEPWOOD: crown-tier minion: near-instant dash-strike at extreme per-hit damage,
color-cycling blade tint as the "you earned this" visual signature.

## Stardust Cell Staff
MEASURED (665x205, 145f, 5.13s): small glowing cells (~0.25-0.3 PL) LATCH onto
whatever the player is currently fighting and also seek independently toward it;
once attached they tick repeatedly for 20-53 per hit while stuck, with 2+ cells
converging on the same body.
MOTION: living leeches — once one latches, the rest home in on the same mark
instead of scattering to different targets.
DEEPWOOD: latch-and-focus-fire minion: cells seek whatever the PLAYER is hitting
and stack onto it rather than spreading damage, a "assist the player's target
choice" pet.

## Stardust Dragon Staff
MEASURED (480x480, 206f, 7.03s): a long serpentine dragon noclips in a single
connected chain through the ENTIRE test room, its body trail visibly spanning most
of the room diagonally (5+ PL of visible body/trail at once) and ticking every body
it slithers past for 42-60 per contact, cycling to a new corner every ~1.2-1.5s.
MOTION: one continuous coiling body rather than a swarm — it doesn't dive and
retreat, it just keeps flowing through the room, damage landing wherever the body
currently is.
DEEPWOOD: growing-segment minion (Deepwood already has a kin note here): the body
itself is a persistent damage line rather than discrete pets, and it should grow by
segment on re-cast, not by spawning a second dragon.

---
## SENTRIES

## Houndius Shootius
MEASURED (400x202, 271f, 5.48s): a stationary gargoyle-cannon turret auto-fires a
spread of bolts at anything entering roughly a 4-5 PL radius, ticking 23-24 per
hit; needs a target in range before it fires at all, otherwise idles silently.
MOTION: the baseline defender — plant it, forget it, it handles anyone who wanders
into its bubble.
DEEPWOOD: tier-1 sentry: modest range (~4-5 PL), modest per-hit (~23-24), the
control example every other sentry should read as an upgrade from.

## Queen Spider Staff
MEASURED (534x135, 176f, 5.57s): the Queen herself stays PLANTED beside the player
and periodically hatches a small homing spiderling (~0.2 PL) that independently
seeks and latches onto whatever enemy is nearby, biting for 15-26 per tick — a
two-stage sentry where the "ammo" is a living, homing minion.
MOTION: an egg-layer, not a shooter — the sentry's own body never attacks, it just
keeps producing seekers that do the work.
DEEPWOOD: spawner-sentry archetype: the placed body doesn't fire itself, it
periodically releases a small homing minion as its actual damage delivery.

## Ballista Rod / Ballista Staff
MEASURED (Rod 658x175, 262f; Staff 590x175, 145f; both 9.3s): a mounted crossbow
turret fires a single arrow down its lane that PIERCES every body standing in line,
ticking 19-27 per body hit in the same volley; fires roughly once per second at a
line of targets up to the full ~9 PL screen width.
MOTION: a lane-clearing sniper — one shot, one line, everyone standing in it gets
hit the same volley.
DEEPWOOD: piercing-lane sentry: full-width straight-line pierce, the "control the
corridor" defender archetype (Rod and Staff are the same sentry, mana cost only
differs).

## Explosive Trap Rod / Explosive Trap Staff
MEASURED (Rod 225x280, 294f; Staff 260x190, 209f; both 11.36s): a mine sits DORMANT
on the ground until an enemy walks within roughly 1 PL, then detonates for 18-24,
and visibly re-arms itself for the next trigger a few seconds later — no active
scanning, purely proximity-triggered.
MOTION: a planted ambush, not a turret — it does nothing until stepped on, then
resets quietly to do it again.
DEEPWOOD: self-rearming proximity mine sentry: near-zero range, trigger-based
rather than aimed, rewards choke-point placement over open-field use.

## Flameburst Rod / Flameburst Staff
MEASURED (Rod 630x175, 260f; Staff 525x175, 260f; both 8.96s): a dragon-head turret
lobs an arcing fireball at a target roughly 5-6 PL away, exploding for 11-15 direct
plus a lingering "1" burn tick per second afterward; fires roughly every 1-1.5s in
a steady bombardment.
MOTION: mortar fire from a fixed muzzle — lobbed arcs rather than straight shots,
each landing leaves a small fire behind.
DEEPWOOD: lobbed-arc sentry with burn-on-hit: mid-range indirect fire, splash +
lingering DoT rather than Ballista's flat pierce.

## Lightning Aura Rod / Lightning Aura Staff
MEASURED (Rod 330x280, 344f; Staff 330x280, 249f; both 11.8s): a stationary emitter
arcs continuous lightning down a roughly 1-1.5 PL wide column beneath it, ticking
everything standing inside for a tiny 3-5 per tick but multiple times per second —
several small numbers stack in nearly every sampled frame once a target is caught.
MOTION: a defense-ignoring downpour rather than a shot — it doesn't aim or reload,
it just keeps the column live and lets dwell time do the damage.
DEEPWOOD: defense-ignoring tick-zone sentry: tiny per-tick numbers offset by very
high tick rate in a narrow fixed column — the "stand in it and it adds up" sentry.

## Staff of the Frost Hydra
MEASURED (500x246, 337f, 7.14s): a hydra head breathes a sustained icy stream that
reaches the FULL screen width (~10 PL) while active, ticking for a heavy 73-119 per
hit during the breath, then retracts and pauses for a few seconds before breathing
again.
MOTION: an on/off firehose — full-width, full-commitment breath cycling with an
idle gap, rather than a continuous trickle.
DEEPWOOD: full-width breath sentry: highest per-tick damage of the sentry set,
paid for with a duty-cycle gap between breaths — a "big periodic hose" archetype.

## Rainbow Crystal Staff
MEASURED (358x346, 269f, 7.81s): a suspended crystal periodically fires 3-4 fanned
beams in a color that changes every burst (purple, then orange/pink, then green,
then blue across the sample), hitting BOTH flanking target clusters simultaneously
for a huge 112-148 per beam.
MOTION: a chandelier that detonates — it doesn't track a single target, it
periodically blooms a colored fan that blankets both sides of the room at once.
DEEPWOOD: bilateral fan-burst sentry: hits multiple clusters in one simultaneous
volley, color-cycling bursts as the visual tell, highest raw numbers of any sentry
sampled here.

## Lunar Portal Staff
MEASURED (400x398, 330f, 6.6s): an aerial portal channels a beam that SWEEPS across
roughly a 60 degree arc over about a second, catching an entire row of targets in
sequence (numbers 32-56 scattered across up to 6 different bodies in one sweep)
before pausing and repeating.
MOTION: a searchlight of damage — one continuous beam painted across a whole row
rather than discrete shots at individual targets.
DEEPWOOD: sweeping-beam sentry: one beam, one arc, many bodies tagged per sweep —
matches the crown "Lunar Portal" reference note (beams sweep ~60 deg for ~1s)
exactly.

---
## WHIPS

## Leather Whip
MEASURED (662x591, 250f, 5.0s): the crack itself is too fast to catch mid-frame in
this sample; ticks land at a modest 6-16 per hit with no visible sustained effect,
consistent with the starter tier of the family.
MOTION: a simple tag-and-swing — no visible hook, dart, or lingering FX, just the
weakest numbers in the whip set.
DEEPWOOD: whip-family floor: minimal reach/FX, low flat numbers — the baseline
every other whip in this ladder should visibly outclass.

## Snapthorn
MEASURED (363x150, 318f, 9.52s): a green thorny tendril visibly hooks a target, and
on that tag EVERY nearby pet converges to strike simultaneously — one sampled crack
produced eight-plus numbers at once (3-29) across the crowd, versus scattered
single "1" ticks between tags.
MOTION: the tag IS the trigger — a quiet hook shot followed by a synchronized
group pile-on the instant it connects.
DEEPWOOD: the whip-tag system in its clearest form: one thorn-hook, then every
minion answers at once on the tagged target — the reference recipe for our own
tag-loop mechanic.

## Spinal Tap
MEASURED (360x134, 253f, 12.65s): crack lands for 12-44 on the tagged target, with
small "3-5" ticks lingering afterward suggesting a short residual debuff rather than
a one-shot tag; reach covers both a near ally and a farther statue-enemy in the same
demo.
MOTION: a mid-tier crack with an aftertaste — the hit itself is solid, and the
tagged target keeps taking chip damage briefly after.
DEEPWOOD: whip with a lingering minor DoT on top of the tag — a step up from
Leather's flat numbers without going full elemental.

## Firecracker
MEASURED (350x224, 238f, 4.76s): a single crack visibly arcs over the whole 5-dummy
line (~4 PL reach) and detonates EVERY struck body at once — one cast produced
simultaneous bursts of 8-44 across all five targets plus lingering "1" burn ticks
on each, repeating every crack.
MOTION: one whip, one line, one explosion — one tag turns the whole row into
fireworks rather than picking a single target.
DEEPWOOD: the detonation-whip archetype: next-hit-explodes across every tagged body
at once, favors big single hits over sustained pets — matches "Firecracker" exactly.

## Cool Whip
MEASURED (450x362, 316f, 6.4s): the crack draws a visible curved frost arc roughly
4+ PL long reaching a target; on contact it applies a chill burst (icy particle
cloud) and ticks of 9-37 continue to land on the frosted target for several beats
afterward.
MOTION: a whip that leaves winter behind — the frost visual persists on the target
well past the actual crack.
DEEPWOOD: elemental-coat whip: modest arc, applies a lingering chill rather than an
explosion — the frost-family sibling to Firecracker's fire-family burst.

## Durendal
MEASURED (400x505, 260f, 5.32s): the crack arcs UP through a stacked column of six
targets AND across a horizontal row of five in the same demo, landing 15-57 per
body across as many as seven simultaneous numbers per crack (one outlier spike of
306 suggests a crit/proc); a small orbiting blade lingers briefly at the impact
point.
MOTION: the whip covers the whole test rig, vertical and horizontal both, in one
motion — reach reads as roughly double Firecracker's line-length.
DEEPWOOD: long-reach multi-axis whip: hits stacked AND lined targets in one crack,
a small orbiting-blade flourish at the tip — a "your reach has grown" tier whip.

## Morning Star
MEASURED (595x172, 476f, 16.35s): rather than big single cracks, the whip mostly
ticks a steady stream of tiny "1"s on the tagged target (a sustained burn/DoT
reading) for the whole 16s demo, with only occasional bigger hits (14) breaking the
pattern; both flanking targets die slowly rather than quickly.
MOTION: a smolder, not a slash — this whip's real damage lives in a long grinding
DoT rather than the crack itself.
DEEPWOOD: DoT-carrier whip: low per-tick numbers traded for very long uptime — the
patient-burn sibling in the whip family, good for an ignite-on-tag variant.

## Dark Harvest
MEASURED (500x483, 477f, 10.02s): a single proc unleashes a SYNCHRONIZED volley
across every tagged body at once — one sampled burst produced eighteen simultaneous
numbers ranging 31-110 spanning both the 8-target vertical stack and the 8-target
horizontal row, repeating on a roughly 1.5-2s cycle.
MOTION: a harvest of meteors, not a whip crack — the screen fills with damage
numbers on every visible target simultaneously rather than one at a time.
DEEPWOOD: the strongest burst in the whip set: meteor-style AoE hitting everything
tagged at once — matches "Dark Harvest (meteors fall on the tagged)" precisely,
reserve this shape for the whip family's top rung.

## Kaleidoscope
MEASURED (615x192, 492f, 14.72s): the demo places targets at OPPOSITE edges of an
unusually wide arena (~13+ PL apart) and the whip's own tag effect is shown reaching
both across the whole 14.7s test, mixing small "1" pokes with solid 8-24 hits;
one flanking target dies well before the other, showing per-target independence.
MOTION: the flagship's whole point is proven by the test rig itself — the demo
wouldn't need a screen this wide unless the whip's tag genuinely reaches that far.
DEEPWOOD: crown-tier whip: effectively unlimited practical reach plus a flat
tag/crit bonus shared by every pet — matches "Kaleidoscope = 20 tag +10% crit
flagship," the ceiling every other whip in the ladder builds toward.

---
## FAILED
Seven named weapons had no demo GIF to pull (confirmed via direct MediaWiki
imageinfo/wikitext checks, not just a failed guess at the filename):
- **Mushroom Staff** — real pre-Hardmode summon (Mushroom Boi minion, 1.4.5 content);
  page is a bare `{{Stub}}` infobox with no animated media uploaded yet.
- **Cobwhip**, **Slime Whip**, **Possession**, **Electric Eel** — all confirmed real
  1.4.5-era whips (wikitext shows `damagetype=Summon`/`type=whip`, correct
  categories), every one a `{{Stub}}` page with only a static icon, no demo GIF.
- **Constellation** — the wiki title is a redirect to the Paintings page (a
  decorative item), not a whip; no matching whip page exists under this or any
  disambiguated title on this wiki.
- **Vulgar Display of Flower** — no page exists under this title at all; not
  findable via search or redirect. Likely lives on a different (mod) wiki than the
  vanilla Fandom mirror this method targets.
Each was checked past the 3-attempt budget (title variants, `prop=images`,
`list=search`, and raw wikitext) before being marked failed — these are asset gaps
on the source wiki, not naming mistakes on this end.

---
## CALIBRATION TABLES

### Minion size ladder (approx body diameter, low -> high)
| ~PL | Minion |
|---|---|
| 0.25 | Stardust Cell, Finch, Blade |
| 0.3 | Hornet, Raven, Optic (eye) |
| 0.35 | Sanguine bat |
| 0.4 | Vampire Frog, Spider, Slime, Deadly Sphere |
| 0.45 | Flinx, Imp |
| 0.5 | Xeno (UFO), Tempest, Stardust Dragon (per segment), Tiger (cub) |
| 0.6 | Pygmy |
| 0.85-0.9 | Pirate (crewman), Abigail (ghost), Tiger (adult form) |

### Cadence ladder (attack rhythm, slow -> fast)
| Pattern | Examples |
|---|---|
| Long charge/cooldown cycle (~2s+) | Deadly Sphere (ram+recharge), Desert Tiger (pounce) |
| Single attack ~1-1.5s | Finch, Imp, Raven, Pygmy, Hornet, Terraprisma, Tempest |
| Two-stage per engagement | Vampire Frog (tongue then bite), Pygmy (throw then melee) |
| Burst-then-pause (3-5 hits in <0.5s, then gap) | Slime, Flinx, Spider |
| Near-continuous while attached | Stardust Cell, Lightning Aura zone |
| Instant reposition, no travel time | Optic (ram/laser pair), Xeno (teleport+beam) |

### Sentry range ladder (approx reach, short -> long)
| ~PL reach | Sentry |
|---|---|
| ~1 (trigger radius) | Explosive Trap |
| ~1-1.5 (column) | Lightning Aura |
| ~4-5 | Houndius Shootius, Rainbow Crystal (fan) |
| ~5-6 | Flameburst (lobbed arc), Queen Spider (seeker roam) |
| ~8-10 (full lane/row) | Ballista (pierce line), Lunar Portal (sweep), Staff of the Frost Hydra (breath) |

### Whip arc ladder (reach, weak -> flagship)
| ~PL reach | Whip |
|---|---|
| ~2 | Leather Whip |
| ~2.5 | Spinal Tap |
| ~3 | Snapthorn |
| ~3-4 | Firecracker, Cool Whip |
| ~4-5 | Morning Star |
| ~6-8 | Durendal (multi-axis: stack + row) |
| ~8+ | Dark Harvest (whole-arena proc) |
| ~13+ | Kaleidoscope (screen-edge to screen-edge) |
