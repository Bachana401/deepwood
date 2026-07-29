# GIF MOTION STUDY — MAGIC SLICE (2026-07-29)
Method: wiki demo GIFs → 8 keyframes each (incl. consecutive triplet) → 2-3x NN contact
sheets → measured in SOURCE px with player height ≈ 48 px = 1.0 PL (player-length unit).
Cadence from GIF frame-delay tables (cs = centiseconds). NO pixels copied — numbers and
motion grammar only. Sources: terraria.wiki.gg pages (mirrored originals via Fandom CDN).

## Last Prism (crown beam)
MEASURED (401x278, 164f, 7.95s): t=0-410ms windup; t≈1.7s SIX separate thin beams
(each ~4 px = 0.08 PL wide) fanned across ~55-60°, individually colored, each ticking
~100-145 per hit; by t≈2.9s all six have CONVERGED into ONE white-core beam ~38 px
(0.8 PL) wide with rainbow fringe — per-tick numbers jump 288 → 329 → 435 → 846 as
focus completes. Beam is hitscan: full 8+ PL screen length every frame, re-aimable
while channeling (frames show 30-40° swings with no lag). Convergence ≈ 2.5-3.4s of
continuous channel; damage scales roughly 3x from spread to focused.
MOTION: channel starts as a weak wide CONE of skinny beams that slowly squeeze
together; the reward for holding still is a screen-long annihilation pillar.
DEEPWOOD: channel wand — 6 skinny rays (0.08 PL) lerp their spread angle 60°→0° over
~3s; on full merge swap to one 0.8 PL beam, tick rate x2, mana cost climbing per second.

## Charged Blaster Cannon (hold-to-escalate)
MEASURED (335x148, 122f): mode 1 rapid bolt: 0.2-0.25 PL blue orb, ~80 px per 50 ms
(~1600 px/s ≈ 33 PL/s), small 0.6 PL cyan splash on hit, ~100 ticks. Mode 2 charged
orb: pierces the whole 5-dummy line, sparkle shower ~4 PL wide drifting past, ticks
258-424. Mode 3 death beam (t≈4.4s hold): instant full-screen beam, core 15 px
(0.3 PL), continuous 116-317 ticks on everything in the line + big terminal splash;
sparkle rain persists ~1s after release.
MOTION: one input, three silhouettes — pellet, piercing comet, screen beam — each
clearly bigger/louder; the beam visibly hoses the whole lane.
DEEPWOOD: HOLD dial: tap = cheap bolt; 1s = piercing orb (infinite pierce, decay);
2.5s+ = 0.3 PL sweeping beam that drains mana per tick. One weapon, three verbs.

## Nebula Arcanum (mothership orb)
MEASURED (800x253, 458f, 30fps): main orb 0.4 PL purple sphere, drifts ~375 px/s
(≈ 8 PL/s) with slight wobble, phases past bodies; on detonation (t≈1.6s, at target
cluster) bursts into a firework ~1.4 PL radius plus a SWARM of small dark seekers
(~0.13-0.16 PL each, pink micro-trails) that scatter wide (seen 4+ PL from burst)
then curve back to strike — each seeker ticks small (40-78 vs orb's 146). Second
detonation at t≈6.6s shows the same double-stage: white core streaks + petal swarm.
MOTION: slow fat orb you shepherd; the payoff is the AFTER-burst — a cloud of
fireflies converging on whatever survived.
DEEPWOOD: lobbed 0.4 PL orb at 8 PL/s; on first hit spawns 10-14 seekers (0.15 PL)
that fan out 3-4 PL then home over ~1.5s at 25-35% orb damage each.

## Nebula Blaze (jackpot bolt)
MEASURED (600x388, 334f, 50fps): bolt = white-hot head ~0.3 PL dragging a 1.2-1.5 PL
magenta comet trail, mild homing curve visible over 4+ PL flights; base hits 114-144.
JACKPOT frame t=4.8s: one bolt lands as a BLUE-white crystal blast ~1.9 PL wide with
X-flash, hitting 437 (≈ 3x base = the 1-in-5 empowered roll); the empowered bolt is
recolored the moment it spawns, so the player sees the jackpot coming.
MOTION: fast comet spam with occasional visibly-different super-bolt — slot machine
telegraphed in flight, not just on the hit number.
DEEPWOOD: rapid homing bolt (0.3 PL head, long additive trail); 20% rolls an
empowered variant at spawn — different color + 1.9 PL burst + 300% damage.

## Magnet Sphere (projectile-turret)
MEASURED (400x194, 264f): cyan translucent sphere ~0.8 PL diameter, drifts in a
straight line at only ~2-3 PL/s and lives the whole 5+ s demo; while drifting it
auto-fires thin jagged zap arcs at the nearest target within ~3+ PL — zaps land in
clusters (3-4 ticks of 28-39 close together, roughly every 0.3-0.5s), and it keeps
zapping BEHIND itself after passing the targets. The sphere ignores terrain contact
in flight and never accelerates.
MOTION: fire-and-forget lantern; the projectile itself is the turret, range circle
implied by where arcs stop reaching.
DEEPWOOD: slow 0.8 PL orb (3 PL/s, 5s life) that zaps nearest foe in 3.5 PL every
0.4s for modest damage — cast it down a corridor and fight around it.

## Orange / Gray Zapinator (chaos lasers)
MEASURED (494x160, ~105f each): thin horizontal laser streaks, visible body
~1-1.5 PL long, very fast (~15-20 PL/s), cadence ~8-10/s. The chaos table is ON
CAMERA: bolt streaks appear at heights and positions unrelated to the muzzle
(teleported bolts at floor level, far behind the player), and hit numbers swing
wildly — Gray: base 17-52 with a 303 spike (~10x); Orange: base 42-104 with 208+
overlapping jackpot stacks. Some bolts visibly reverse direction.
MOTION: laser pea-shooter where every shot is a dice roll — position, direction,
and damage all mutate mid-flight.
DEEPWOOD: rapid thin bolt with per-shot rolls: 10% teleport 2-3 PL toward a foe,
10% reverse once, 5% x5-x10 jackpot with fattened sprite — chaos as identity.

## Ice Rod (spell as terrain)
MEASURED (325x257, 440f, 9s): cast sends a small blue diamond bolt to the cursor
point where it SOLIDIFIES into a 0.33 PL (1-tile) translucent ice block midair;
demo stacks them into a ~3 PL tall pillar that STANDS for the full remaining 6-8s,
sparkling; a zombie is shown physically blocked/climbing at the pillar — enemies
path around it. Blocks do no damage (stray ticks of 20-23 are the bolt itself).
MOTION: the spell's output is architecture — instant scaffold/bridge/valve wherever
the cursor points.
DEEPWOOD: conjure a 1-tile frost block at target point (stackable, ~8-10s life,
enemy-blocking, stand-on-able) — mage bridges the 92px jump gaps and plugs corridors.

## Rainbow Gun (persistent painted arc)
MEASURED (799x375, 80f, 30fps): the shot PAINTS a parabolic rainbow ribbon forward
from the muzzle at ~13 PL/s (arc reaches 2 dummies by 540ms, full 16 PL screen by
860ms); ribbon is ~0.25 PL thick with full color banding, apex ~3 PL above launch
height. Once painted the arc STAYS PUT for the rest of the demo (in-game 40s),
ticking every dummy it intersects 40-54 about 2-3 times per second, no pierce limit.
MOTION: artillery that leaves its own trajectory behind as a damage fence — you
sculpt a rainbow wall into the arena and herd enemies through it.
DEEPWOOD: paint a ballistic arc (0.25 PL thick) that persists 15-30s as a static
damage ribbon ticking ~2/s; one arc at a time, recast repaints.

## Blood Thorn (terrain eruptions)
MEASURED (300x366, 265f, 50fps): cast at a cursor point makes thorn tendrils ERUPT
OUT OF THE NEAREST TERRAIN — floor and alcove walls sprout ragged red columns
~0.6-0.8 PL wide and up to 4 PL tall, sweeping through targets for stacked ticks
(29-38 x5-8 per eruption); eruption lives ~0.5s; recast every ~0.9s. Eruptions
reach targets standing in an enclosed alcove the player has no line of sight to.
MOTION: the world itself attacks — ground and walls grow teeth at the point you
mark; cover is no defense.
DEEPWOOD: cursor-targeted floor/wall spike eruption (0.7 PL wide, up to 4 PL reach,
5-hit multitick), ignores line of sight — the anti-camping mage tool.

## Magical Harp (infinite-pierce note stream)
MEASURED (550x194, 562f, ~30fps, 11.5s): stream of note glyphs ~0.2 PL each fired
~6-8/s into a 20-dummy line; single notes visibly cross 15+ bodies (ticks 12-58
raining across the whole 20 PL row at once) and keep going — infinite pierce, and
notes bounce off surfaces. Note SPACING changes between passages (tight ~1.6 PL
apart early, wide ~2.5+ PL later) = projectile speed is a live dial (cursor
distance sets it); slow notes stack more ticks into the same bodies.
MOTION: a woodwind machine gun — the player tunes note speed to the fight: slow
fat chords for a boss hugging you, fast darts for a corridor.
DEEPWOOD: piercing bouncing note, speed mapped to cursor distance (0.3x-1.5x),
unlimited pierce with NO decay but modest base — the corridor-clearing hum.

## Stellar Tune (cursor-arrival stars)
MEASURED (360x185, 146f): each strum sends a PAIR of star-comets that detonate
EXACTLY at the cursor point — every burst frame is centered on the cursor arrow
even as it moves (chests, mid-air, statues). Burst = pink/white starburst ~1.6-2 PL
wide, ticks 53-102; flight trail is a thin pink streak; arrival time reads as a
fixed short beat (~0.5s) regardless of distance, so far shots fly faster.
MOTION: rhythm artillery — the cursor is a conductor's baton and explosions land on
the beat wherever it points; leading targets is trivial, timing is everything.
DEEPWOOD: twin star bolts that always arrive at the marked point in 0.5s (speed
scales with distance) and burst 1.8 PL — pre-place bursts on a dodging boss.

## Life Drain (channeled leech zone)
MEASURED (299x289, 264f, 6.6s): channel projects a drain zone at the cursor covering
a crowd ~4 PL wide below the player; every enemy inside ticks tiny numbers (5-18)
continuously while RED MOTES stream from the crowd up the channel line to the
caster; demo HUD life counter climbs 31→53 over ~6s (≈ +3.7 HP/s on a ~10-enemy
crowd) — heal rate visibly scales with how many bodies are being drained. Ticks
continue on survivors as the crowd thins, at a slower heal pace.
MOTION: a vampiric spotlight — hold the beam on the mob, watch your health crawl
back as red fireflies flow home.
DEEPWOOD: channel a 2 PL-radius drain circle at cursor: small fast ticks on all
inside, caster heals X per enemy per tick (count-scaled, capped) — sustain wand
that wants dense pulls.

## Magic Missile (hold-to-steer)
MEASURED (350x365, 388f, 50fps): while the button is held the comet FOLLOWS the
cursor at a lazy ~4 PL/s with a curved sparkle trail — frames show it parked
mid-air above the dummy line, then walked left, then dived into a statue on a
platform; on release (or contact) it strikes for one hit (22-29). The projectile
is the cursor's pet: no gravity, no lifetime shown, full mid-air direction changes.
MOTION: slow obedient drone — the player drags one bright bead around corners and
into the target of choice.
DEEPWOOD: hold = projectile lerps toward cursor (4-6 PL/s max turn-free chase);
release = homes at nearest foe. One live at a time; damage modest, control total.

## Flamelash (steered fireball + burn)
MEASURED (350x277, 478f): same steering grammar as Magic Missile but faster and
armed — explosion bursts ~1.4 PL wide land on the far RIGHT dummy at t=1.7s and the
far LEFT dummy at t=3.3s (steered across the whole screen between casts); every
victim keeps ticking "1" burn numbers for seconds afterward (lingering ignite);
f239 shows the fireball mid-curve with a flame trail while previous victims still
burn. Cadence ~1 cast/1.5s.
MOTION: a leashed will-o-wisp — you paint targets one by one, each pass leaves
them smoldering.
DEEPWOOD: steerable fire orb (6-8 PL/s), 1.4 PL blast, applies burn DoT; the steer
family's tier-2 — same verb maturing (missile → flame → rainbow).

## Rainbow Rod (steer, precision tier)
MEASURED (465x271, 394f): top of the steer family — bolt is a small white crescent
head dragging a thin (~0.15 PL) rainbow-gradient ribbon 2-3 PL long; fast and
precise enough to be walked INTO a dummy cluster (sparkle bursts + 44-51 ticks on
three targets in sequence) then up onto a statue platform (42-49) — repeated
mid-flight redirection with kills between. Recast ~1s. The ribbon path lingers a
beat, drawing the flight curve in the air.
MOTION: the master's brush — same steering verb, now fast, pretty, and surgical.
DEEPWOOD: steer tier-3: 10-12 PL/s chase speed, rainbow additive ribbon, higher
damage per strike; the visible upgrade is CONTROL AND SPEED, not girth.

## Clinger Staff (standing firewall)
MEASURED (400x275, 483f, 9.7s): cast raises a vertical WALL of sickly yellow-green
flame ~0.6 PL wide and 5+ PL tall (floor to screen top in the demo) rooted at the
target floor point; it STANDS there for the whole demo, ticking 40-48 on anything
inside plus a lingering "10" cursed-burn DoT after targets step out (unicorn enemy
shown walking through and burning down across multiple frames). Recast moves the
wall; one wall at a time.
MOTION: area denial as a picket line — you place a burning fence and let enemies
pay toll through it.
DEEPWOOD: conjure a flame curtain (0.6 PL wide, ~4 PL tall, 20-30s) at target
ground; contact ticks + burn DoT that persists after exit; one active, recast moves.

## Nimbus Rod (placeable rainclouds)
MEASURED (470x327, 340f): places a small white cloud (~0.85 PL wide) AT THE CURSOR
high in the air; after ~1s it rains a thin blue column straight down, full height,
ticking 31-41 (occasional 80 crit) on every dummy stacked in the column — TWO
clouds shown active at once covering two dummy towers, raining for the entire demo
(in-game minutes). The rain hits through multiple bodies and platforms.
MOTION: weather as a turret — park storms over lanes and let them mow; the whole
fight becomes zone control.
DEEPWOOD: place up to 2 rainclouds (0.85 PL) that rain a full-height damage column
~2 ticks/s for 60s+ — the sustained-siege tome verb (our stormdebt kin, validated).

## Crimson Rod (cloud family tier-1)
MEASURED (350x224, 373f): single smaller blood-red cloud (~0.75 PL), same
place-at-cursor grammar, thin red rain column ticking 11-14 (26 crit) on the dummy
below; only ONE cloud allowed, damage small, duration long. The family reads as:
Crimson (1 weak cloud) → Nimbus (2 strong clouds) — count and tick both grow.
MOTION: the starter version of rain-zone control; identical verb, humbler numbers.
DEEPWOOD: tier-1 cloud wand: one cloud, small ticks — teaches the zone verb early;
its Nimbus upgrade is the SAME spell with +1 cloud and fatter rain.

## Water Bolt (long-lived ricochet ball)
MEASURED (294x124, 124f, 25fps): slow glittering blue bolt (~6 PL/s) fired down a
10-dummy line — ONE bolt pierces all ten (ticks 16-22 strung along the row as it
travels), exits the screen, and a later frame shows a bolt ricocheting back at the
player's own position (vertical splash) — bounces off walls and keeps going for
its long life (30s in-game). Trail is a sparkling water ribbon ~1.5 PL.
MOTION: a patient pinball — cast once into a corridor and let geometry do the
work; slowness IS the multi-hit feature.
DEEPWOOD: slow piercing water orb (6 PL/s, 10 pierce, 3-5 wall bounces, 10s+ life)
that shines in our tunnel dungeons; low tick, huge total.

## Shadowbeam Staff (folding instant beam)
MEASURED (372x295, 68f, 1.9s demo): each cast draws the ENTIRE reflected beam path
in one frame — a thin (~0.15 PL) white-violet line zigzagging staff → ceiling →
floor → ceiling across the whole room (4+ bounces, two full diamond shapes
visible); the path then decays into drifting purple sparkle dust over ~0.5-1s.
Repeat casts every ~0.5s redraw a fresh fold; hits (56-62) land anywhere the line
crosses a body.
MOTION: geometry weapon — the room's shape IS the spread pattern; corridors turn
it into a laser cage.
DEEPWOOD: hitscan bolt reflecting up to 4-5 times off terrain, whole path flashes
at once then afterglows; damage per crossing — rewards firing down our tunnels.

## Medusa Head (held gaze aura)
MEASURED (425x315, 262f): while held aloft, 5-6 golden god-rays radiate from the
head in a star pattern reaching ~3-4 PL in all aimed directions; everything the
rays wash over ticks 19-31 repeatedly (mimics, chests, dummies at different
heights simultaneously); stone-dust particles shed off victims (petrify flavor).
Re-aiming swings the whole ray fan; it is an aura, not a projectile — zero travel
time, constant cost while held (in-game: mana only on hit).
MOTION: you BECOME the turret — a lighthouse of stone-light sweeping the room.
DEEPWOOD: channel: radiate 5 short rays in a 3.5 PL star that tick + briefly slow
(petrify-lite) everything caught; mana only charged on ticks that hit.

## Staff of Earth (physics boulder)
MEASURED (400x276, 362f): summons a 0.5 PL molten boulder that ROLLS down the
dummy line grinding 108-260 per touch; later frames show it LOBBED in an arc,
bouncing — and the numbers spike (244-280) at high-speed impacts vs ~110-140 on
slow grind: damage visibly scales with roll speed. Impact bursts white smoke;
the boulder lives for seconds, plowing an entire 15-dummy row per cast.
MOTION: dumb heavy physics as spectacle — aim is approximate, momentum is the
damage stat, terrain slope is your ally.
DEEPWOOD: summon a rolling boulder with real gravity/bounce; damage = f(speed)
(x1 slow to x2.5 fast); shines in our sloped dungeon floors and shaft drops.

## Vilethorn (wall-phasing lance, family tier-1)
MEASURED (287x146, 84f, 25fps): cast EXTENDS a jagged vine lance from the staff to
~4.8 PL length over ~0.3s, passing straight THROUGH two stone pillars and 5
dummies, ticking 8-12 on every body along its length, then retracts; recast ~0.8s.
The lance is a fixed-angle piercing line — no travel, no projectile to dodge.
MOTION: a spear of the deep garden — pokes through walls to hit what hides.
DEEPWOOD: extending thorn lance (4-5 PL, wall-phasing, multi-tick) as tier-1 of a
3-tier lance family (see Crystal Vile Shard / Nettle Burst below).

## Crystal Vile Shard (lance tier-2)
MEASURED (600x201, 529f): same extend-retract lance verb as Vilethorn but
CRYSTALLINE and ~10+ PL long — one cast spears through EIGHT dummies plus the
room's wall pillar, ticks 22-31 (44-52 crits) along the whole shaft; fired left
and right on alternating casts. Roughly double Vilethorn's reach and damage.
MOTION: the same spear, grown into a glass skewer of the whole corridor.
DEEPWOOD: tier-2 lance: 8-10 PL, crystal palette, fatter ticks — the upgrade is
pure REACH so the player feels the family growing.

## Nettle Burst (lance tier-3)
MEASURED (800x217, 481f): the capstone lance — a thorn vine ~14+ PL long crossing
the ENTIRE two-room arena through the dividing wall, ticking 29-40 (74-80 crits)
on nine bodies at once, recast ~1s, both directions. Same verb three tiers up:
Vilethorn 4.8 PL → Crystal Vile 10 PL → Nettle 14+ PL.
MOTION: a hedge of spears through the map — the upgrade-chain model where ONE
mechanic matures by length/damage/cadence instead of changing shape.
DEEPWOOD: run our wand-lance family exactly like this: identical code path, three
escalating reach/damage tunings — players read the lineage instantly.

## Demon Scythe (accelerating buzzsaw)
MEASURED (450x205, 249f): sickle disc ~0.4 PL spawns AT the caster nearly
stationary, swirling violet sparks; by t≈1.8s it has drifted only ~7 PL, then it
ACCELERATES hard, crossing the remaining ~8 PL in under 0.8s (end speed 10+ PL/s),
piercing every dummy with 31-38 ticks (62-80 crits) and a sparkle wake. Pierce
does not slow it; it exits the screen still gaining speed.
MOTION: slow menace → sudden violence; enemies close to the caster get multi-hit
by the slow phase, far ones get sniped by the fast phase.
DEEPWOOD: disc starts at 1 PL/s, accel ~8 PL/s² after 0.5s windup, infinite
pierce with our decay rule — placement near your feet IS the aiming skill.

## Weather Pain (parked grinder tornado)
MEASURED (500x313, 264f): summons a small tornado (0.6 x 0.95 PL) that drifts
forward slowly and PARKS inside the enemy pack for ~3-4s, grinding rapid small
ticks (12-24) — frames show a zombie pack shredded to bone piles while skeletons
just outside the funnel stand untouched. One tornado at a time; expires quietly.
MOTION: a pet storm you bowl into the scrum — tight radius, relentless cadence,
zero reach beyond its funnel.
DEEPWOOD: lobbed mini-cyclone: drifts 2 PL/s, parks 3s on first contact, ticks
5/s in a 1 PL radius — the melee-range mage zone with a clear silhouette.

## Inferno Fork (fireball into firestorm)
MEASURED (350x266, 250f): fast fireball whose impact blooms into a ~2 PL explosion
(40-66 ticks) that does NOT end — it swells into a lingering FIRESTORM cloud
~3 x 2.5 PL parked over the impact cluster, still ticking 36-48 at t+1.7s, then
decays into individual burn flames (steady "1"s) on each victim for seconds more.
Three damage stages from one cast: burst → storm zone → per-target burn.
MOTION: artillery that leaves weather behind — the explosion is a place, not an
event.
DEEPWOOD: fireball with 2 PL burst that leaves a 2.5 PL flame field for ~2.5s
(tick 3/s) plus burn DoT on everything it touched; our inferno-tier wand verb.

## Tome of Infinite Wisdom (terrain-crawling tornado)
MEASURED (536x254, 116f): primary is a fast piercing bolt (sparkle bursts walking
through the dummy line, 22-28); the ALT cast conjures a dust tornado ~1 x 3.3 PL
that GROUNDS ITSELF and crawls along the floor contour — frames show it climbing
the arena's stair steps dummy by dummy, ticking 24-54 as it passes. It hugs
terrain instead of flying, so slopes and stairs steer it.
MOTION: two verbs in one book: a sniper line and a shambling column of wind that
sweeps your floor for you.
DEEPWOOD: alt-fire tornado that walks the ground at ~3 PL/s, climbs steps, lives
~4s, multi-ticks — made for our side-scroller floor topology.

## Spirit Flame (aimless wrath)
MEASURED (385x158, 94f): casting with no valid target spawns 3-5 violet wisps that
DRIFT LAZILY around and above the caster (frames show them wandering at ceiling
height, unhurried); the moment a mimic appears, every wisp converges and slams it
with stacked 62-77 hits in under a second. The spell holds its anger until
something deserves it.
MOTION: patient homing — projectiles idle as ambient decoration, then become a
firing squad when a target enters the room.
DEEPWOOD: wisps orbit the caster up to 5s waiting for a foe (cap 4-5 live), then
dive at 12+ PL/s; casting into an empty corridor pre-loads the ambush.

## Razorpine (the honest hose)
MEASURED (350x170, 102f, 29fps): pine-needle flurry — 2-3 dark-green needles
(~0.4 PL) in flight per frame at slightly jittered angles, continuous ~8-10/s
cadence, stacking 41-58 ticks on a single dummy nonstop for the whole demo. No
pierce, no gimmick, no burst: just relentless single-target throughput.
MOTION: a chainsaw disguised as a Christmas tree — the design lesson is that ONE
slot in the roster is allowed to be a pure, well-tuned hose.
DEEPWOOD: keep one zero-gimmick magic hose (tight spread, high sustain, mana
hungry) as the roster's honest-DPS benchmark.

## Razorblade Typhoon (crown homing discs — motion detail)
MEASURED (300x239, 294f): 2-3 cyan vortex discs live at once (cast ~1/s), each a
FULL player-height (1.0 PL) spinning ring; they weave through the dummy line
hitting 77-104 (158 crits) on several bodies per pass, PAUSE briefly to grind
(multi-tick same target), then arc away — one frame shows a disc curving up onto
a statue pedestal, full homing. Discs outlive several seconds each.
MOTION: lazy hurricanes — big, unhurried, unavoidable; the screen fills with
spinning threats that never stop working.
DEEPWOOD: (already our crown reference) keep: 1 PL disc, 2-3 live cap, homing
with grind-pause on contact, full damage per re-hit.

## Bubble Gun (short-range pop shotgun)
MEASURED (350x240, 139f, 29fps): sprays ~8-10 bubbles (0.25 PL each) per volley in
a loose cone that reaches only ~3.75 PL before the bubbles slow and POP (~0.8s
life); inside that envelope every bubble hits (60-79, 120 crit) so point-blank
volleys stack 6+ ticks per beat on all three dummies. Beyond the envelope: zero.
MOTION: a champagne flamethrower — absurd close-range density bought with a hard
range ceiling.
DEEPWOOD: cone of 8 slow bubbles/cast, damage full inside 4 PL then despawn —
the brawler-mage option whose weakness is literally distance.

## Toxic Flask (lobbed gas field)
MEASURED (239x153, 101f, 25fps): lobbed flask bursts on the top dummy into a
~1.9 PL gas blob that EXPANDS into scattered puffs covering a 5+ PL wide field
over ~1.3s; the field drifts downward and ticks 39-53 (82 crits) on all four
dummies; after the visual dissipates, victims KEEP ticking (poison DoT outlives
the cloud). One flask = area + duration + residue.
MOTION: chemistry as terrain — throw once, own the room's air for seconds.
DEEPWOOD: lobbed vial: 2 PL burst growing to a 4-5 PL cloud (3s), tick + poison
DoT that persists 3s after exit; the alchemist-wand verb.

## Bat Scepter (erratic homing swarm)
MEASURED (350x398, 387f): each cast releases 2-3 small bats (0.25 PL) that fly
visibly WRONG — jinking up/down in wavy zigzags, overshooting and circling back —
yet always arrive, stacking 38-51 (90-94 crits); sustained casting keeps 6+ bats
airborne weaving different paths. Burst frames show them mobbing a mimic chest.
MOTION: living ammunition — the drunken flight makes the swarm read as creatures,
not bullets, and spreads arrival times into a damage drizzle.
DEEPWOOD: cast = 2-3 bats with sine-jitter homing (arrive 0.4-0.9s staggered);
crowds the air with familiars — pairs with our bat-cave dungeon floors.

## Blizzard Staff (diagonal icicle rain)
MEASURED (350x459, 273f): hold-to-channel rains icicle shards (0.45 PL, sparkle
tails) from ABOVE the screen at a steep ~65-70° diagonal onto the cursor area,
~8-10 shards/s, randomized x-stagger so the fall reads as weather; sustained ticks
49-66 across three adjacent dummies for the whole hold. Shards die on the floor.
MOTION: a personal hailstorm angled like wind-driven sleet — area saturation
bought with "needs open sky."
DEEPWOOD: channel: icicles rain diagonally into a 3 PL cursor zone (8/s, small
ticks); blocked by ceilings — outdoor/boss-arena payoff, useless in low tunnels.

## Lunar Flare (phasing sky volleys)
MEASURED (350x427, 492f): each cast sends a volley of ~3 cyan flares plunging
near-VERTICALLY from screen top onto the cursor point, arriving through a
platform overhang (terrain-phasing confirmed — hits land under a ledge); impacts
overlap into a ~2 PL starburst with stacked 92-124 ticks. Volleys land ~0.4s
after cast; repeated volleys every ~1.5s in the demo.
MOTION: orbital strike — the ONLY sky-rain that ignores roofs, which is exactly
what makes it endgame.
DEEPWOOD: crown sky verb: 3 flares phase through terrain to the marked point
(0.4s delay, 2 PL bursts) — the underground-viable artillery upgrade.

## Meteor Staff (called meteor)
MEASURED (341x371, 83f, 2.3s): one meteor per cast — 0.7 PL flaming rock diving at
~75° with a 3-4 PL spark tail, ~0.5s from screen top to impact; hit blooms a
~2 PL smoke/flame burst ticking 49-60 on everything adjacent; casts chain ~1/s so
consecutive meteors walk across the target area. Needs open sky (dive starts
above the screen).
MOTION: point-and-bombard — the mid-tier sky verb with real arrival delay to lead.
DEEPWOOD: cursor-called meteor: 0.5s fall, 2 PL blast, 1/s cadence, roof-blocked;
sits below Lunar Flare in the sky-rain ladder (rain → meteor → phasing flares).

## Crystal Serpent (mid-flight splitter)
MEASURED (350x206, 214f): pink bolt that POPS ~4-5 PL out of the muzzle into a fan
of 4-6 glittering shard-streams arcing outward and down like a firework, blanketing
the far half of the dummy line; main bolt ticks 28-36, shards add 29-36 (62-66
crits) across three targets simultaneously. The split point tracks partway to the
cursor, so range control aims the shotgun.
MOTION: a rifle that becomes a fireworks shell — single-target up close, cone
coverage at distance.
DEEPWOOD: bolt splits at 60% of cursor distance into 5 arcing shards (each ~35%
damage) — one weapon whose spread the player TUNES by where they aim.

## Sky Fracture (portal swords)
MEASURED (451x152, 122f): each cast flashes 2-3 small cyan PORTALS at staggered
offsets around the caster's shoulders, each launching a sword-projectile (0.85 PL
long) toward the aim point at ~25 PL/s; swords arrive milliseconds apart at
slightly different heights (36-43 ticks, 70 crits, sparkle bursts). The portals
are the flourish — ammunition arrives from nowhere.
MOTION: the caster conducts, the sky supplies — staggered multi-angle arrivals
make a single cast read as a volley.
DEEPWOOD: cast = 3 sword-bolts from mini-portals ringing the player, 60-120ms
stagger, converging on cursor; our "arcane armory" mid-tier verb.

## Crystal Storm (ricochet crystal hose)
MEASURED (285x147, 171f): machine-gun stream (~10/s) of tiny 0.15 PL pink shards
with slight vertical scatter; shards that miss BOUNCE off floor/walls in falling
arcs and can still connect (curved shard trails visible short of and behind the
dummy); sustained ticks 23-29 with 44-60 crits stacking fast at short-mid range.
MOTION: a glitter sandblaster — the bounce turns misses into floor-level chip
damage and fills corners with sparkling shrapnel.
DEEPWOOD: rapid mini-crystal hose (10/s, 1 bounce each, short life) — the spray
weapon that gets BETTER in tight rooms.

## Golden Shower (piercing debuff stream)
MEASURED (500x154, 190f): continuous golden ribbon arcing gently downward across
the full 10+ PL room, piercing all three dummies; while streaming, every body
ticks 18-24 ~2/s — and hits KEEP appearing after the stream stops (the
defense-shred debuff carries); the stream's end dissolves into falling gold spray.
MOTION: a hose you sweep across the lane; modest numbers, but its real product
is the debuff painted on everything it crosses.
DEEPWOOD: piercing stream (10 PL, slight gravity droop) applying ARMOR SHRED
(-X defense, 8s) — the support-mage verb that multiplies the whole party's
damage; numbers stay small on purpose.

## Cursed Flames (bouncing unquenchable fire)
MEASURED (500x280, 841f, 17s): lime-green fireball that BOUNCES off terrain —
one flight shown ricocheting into a high parabola over the platform before
landing; each burst (46-56, 88-100 crits) ignites victims with green flame that
ticks 10/s and visibly KEEPS BURNING 5-10s later (burn stacks still ticking at
t=12s and t=15s on separate dummies). Fireballs live long enough for 2-3 bounces.
MOTION: fire that refuses rules — bounces where it likes and cannot be put out;
the DoT outlasts the fight.
DEEPWOOD: 2-bounce green fireball, 1.5 PL burst, applies "witchfire" (unremovable
5s DoT, our cursed-inferno kin); ricochet geometry makes it a corridor weapon.

## Bee Gun (accumulating micro-swarm)
MEASURED (600x350, 492f): each cast releases a handful of TINY bees (~0.1 PL dots)
that wander forward in loose arcs, loosely homing; sustained casting builds a
CLOUD — the seven-dummy row shows 15-20 tiny ticks (8-12 each) airborne at once,
and stray bees are still flying 3s after the last cast (visible crossing the
right half of the room alone). Damage per sting is trivial; the swarm total is
the weapon.
MOTION: death by paperwork — dozens of near-worthless projectiles that refuse to
miss forever; the screen hums.
DEEPWOOD: cast = 3-4 bees (0.1 PL, weak homing, 3s life, tiny tick); DPS lives in
sustained cast overlap — our hive-tier starter swarm verb.

## Book of Skulls (slow piercing skull)
MEASURED (536x270, 381f): lobs a flaming skull ~0.6 PL with a fire wake at a slow
~5 PL/s; it pierces — both dummies in its lane tick 25-33 as it passes — and casts
chain ~1/s so two skulls can share the lane. Impact frames show a compact flame
burst; the skull's slow float makes it readable and dodgeable, its pierce makes
it queue-punishing.
MOTION: a grim lantern drifting down the hallway — slow, inevitable, through
everything in the line.
DEEPWOOD: slow piercing skull (5 PL/s, infinite pierce w/ decay, flame wake) —
the corridor-punisher whose weakness is anything that side-steps.

## Aqua Scepter (gravity water jet)
MEASURED (525x170, 137f): continuous water ribbon sprayed across the full ~10 PL
room, drooping under gravity at the far end into falling spray; pierces all four
dummies with steady 14-18 ticks (30-32 crits) ~2-3/s each while the stream is
held on them. The stream renders as hundreds of sparkling droplets, not a solid
beam — misty, alive.
MOTION: a firehose you sweep like a scythe; the droop gives it an aiming skill
(lift the muzzle to reach far targets).
DEEPWOOD: hold-to-spray piercing water arc (10 PL with droop, small fast ticks,
knockback trickle) — the early-game sweeper; upgrade path into Golden Shower's
debuff stream shape.

## Heat Ray (instant needle beam)
MEASURED (400x192, 204f): hitscan — every firing frame shows the COMPLETE thin
beam (~0.17 PL wide, faint flame texture) from muzzle to target with zero travel;
sustained hold ticks 68-91 (174 crit) in rapid cadence; no splash, no pierce
shown, just a straight hot line and stacked numbers. Beam re-aims instantly with
the cursor.
MOTION: a welding torch at rifle range — the no-nonsense hitscan magic that
trades all spectacle-verbs for immediacy.
DEEPWOOD: thin instant beam, short bursts (0.5s) with tick 4/s, modest width —
our laser-tier precision option; contrast piece to the fat Last Prism channel.

## Starfury (sky-call grammar, the magic-kin reference)
MEASURED (572x562, 178f, 50fps): each swing calls ONE star (0.6 PL glyph head,
long sparkle tail) that enters from ABOVE THE SCREEN at a steep diagonal and
arrives ~0.5s later at the strike point, passing through the dungeon roof
(phases until open air near the target); vertical pink flash column on impact,
ticks 21-42 (76 crit). Successive swings stagger stars at different x-offsets —
the cascade grammar Star Wrath matures (see yardsticks at top).
MOTION: the sky answers the sword — one falling star per beat, arrival delayed
just enough to lead moving targets.
DEEPWOOD: our Borrowed Star already builds on this; reuse the same entry-angle/
stagger numbers for any future sky-call wand (60-70° entry, 0.5s arrival).

## Laser Machinegun (spin-up bolt hose)
MEASURED (417x150, 244f): ~0.9-1s SPIN-UP (muzzle sparks, zero output), then a
hose of long cyan laser bolts — beam segments 5-8 PL long streaking at high
speed with slight per-shot angle jitter (frames show two bolts diverging several
degrees); sustained ticks 55-70 with 122-142 crits stacking. Stopping fire means
paying the windup again.
MOTION: commitment weapon — you trade the first second for a screaming sustained
stream; the jitter paints a shallow cone at range.
DEEPWOOD: hold-to-fire: 0.8s windup, then 8/s long bolt stream with 3-5° random
spread; mana drain continuous — our gatling-arcana verb.

## Betsy's Wrath (arcing debuff comets)
MEASURED (781x389, 128f): each cast lofts THREE 0.75 PL fireball comets in a
fanned ARC — they rise toward the screen top with long violet spark tails, then
rain down past the apex onto the far dummy trio; impact bursts purple flame with
ticks 58-73 (118 crit) and leave violet residue burning on victims. In-game the
signature is the defense-MELT debuff on everything splashed.
MOTION: mortar fire from a dragon's throat — the arc lets you shell targets
behind cover, and the debuff makes every landed volley a setup.
DEEPWOOD: 3-comet arcing volley (rise 4-5 PL then fall), 1.5 PL purple bursts
applying armor-melt (-defense, 6s) — the boss-opener wand.

## Resonance Scepter (ring-pulse detonations)
MEASURED (374x196, 296f, 50fps): sends a small pink wisp that DETONATES at the
target into expanding CONCENTRIC RINGS — double ring visible growing to ~1.9 PL
outer diameter over ~0.3s, ticking 53-72 (136 crit) on everything the rings
sweep; successive pulses centered on different dummies, one pulse landing
BETWEEN two targets and hitting both. Sparkle shimmer fills the ring interior.
MOTION: sonar warfare — damage as a visible pressure wave; placement between
enemies pays double.
DEEPWOOD: bolt that blooms a 2 PL double-ring shockwave at impact (sweep tick as
the ring expands) — our sound/holy-mage verb, gorgeous and readable.

## Shadowflame Hex Doll (wavy tendril fan)
MEASURED (491x317, 115f): channel whips 3-4 SHADOW TENDRILS from the caster in a
fan — wavy purple ribbon streams reaching 7+ PL, each snaking on its own sine
path to a DIFFERENT target (three stacked dummies engaged simultaneously);
direct ticks 37-48 plus steady "5" shadowflame DoT trailing on every victim.
Sustained channel keeps the tendrils writhing and re-hitting.
MOTION: the room grows dark ivy — multi-target reach with organic, unsettling
motion; the DoT keeps working after the whip passes.
DEEPWOOD: channel 3 sine-wave tendrils that auto-spread across up to 3 targets
in a 7 PL fan, each applying a stacking shadow DoT — the warden/DoT-mage verb.

---
## COVERAGE NOTE
Studied 52 weapons / 53 demo GIFs (Orange + Gray Zapinator both pulled).
FAILED: Killing Deck — no demo GIF on the accessible mirror after 3 attempts
(wiki.gg-only page; its images host serves a challenge page to scripted
clients). Its verb (stick cards, recall through walls at 150%) stays described
in WEAPON_VERB_REFERENCE.md from the text scan; adapt from that spec.
Not separately pulled: Weather Pain/Starfury covered above; "Starfury-kin"
sky ladder = Starfury→Meteor→Blizzard→Lunar Flare entries here.

