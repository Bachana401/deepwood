# GIF MOTION STUDY — RANGED SLICE (46 weapons, frame-surgery 2026-07-29)

Method: demo GIFs → 8 labeled keyframes each (timestamps kept), measured against
the 48px = 1 player-height (ph) grid. Numbers below are read off the frames:
projectile sizes in ph, speeds in px/frame at the GIF's native delay (noted),
volley counts, blast widths, trail lengths, cadence. NO pixels copied — these
are behavior recipes for original Deepwood art.
Source GIFs: 156f/36ms daedalus, 196f/20ms bloodrain, 193f/33ms celebmk2, etc.
(per-weapon frame/delay in header lines). "tick" = one damage number instance.

---

## SKY-RAIN BOWS

### Daedalus Stormbow  (156f @36ms, 300x360)
Measured: nothing leaves the bow — arrows SPAWN at screen-top; 2-3 aloft per
frame; fall near-vertical with 8-15 deg tilt toward the aim; a full 7.5ph
screen drop takes ~0.4-0.5s (~18-20 px/frame); spawn x staggered within
±1.5ph of the aim point; hit ticks 41-55 continuous while held.
Motion: the bow aims up and the sky answers. Arrows materialize above the
visible screen and rain down in a loose column centered on the cursor,
each drop staggered in time and x so the rain never looks like a volley.
Impacts kick up debris; the stream is continuous at fast autofire.
Deepwood: "storm-called" bow verb — shots fall from above the camera at the
aim point (useless under a ceiling = built-in balance), 2-3 staggered drops
per draw with slight tilt jitter.

### Blood Rain Bow  (196f @20ms, 400x441)
Measured: 1-2 thin vertical droplet COLUMNS (~0.2ph wide) from screen-top;
droplets 2-4px spaced ~15-25px; column persists 3-5 frames per draw like a
faucet; drop crosses ~7ph in ~0.3-0.4s; ticks 16-22 rapid on the one dummy
under the column.
Motion: not arrows — a drizzle. Red streams pour from the sky in a tight
line above the cursor, wiggling slightly, soaking a single target zone.
Reads as weather, not projectiles; damage arrives as a steady tick stream.
Deepwood: low-tier sky-rain cousin — narrow crimson drip-column at the aim,
tick-based, cheap-feeling versus Daedalus' full storm.

## RHYTHM / METRONOME BOWS

### Phantasm  (136f @26ms, 526x172)
Measured: 4-arrow cluster per draw (vertical stagger ~0.3ph), flat and fast
(cluster crosses 4ph in ~2 frames); 2+ clusters aloft at high wind-up rate;
on-hit spawns cyan PHANTOM bolts with 1.5-2ph streak trails homing to the
target; ticks: arrows 33-66 + phantom 6s piling in bursts; cyan muzzle
flare while winding.
Motion: a tight flight of arrows with a wind-up cadence that keeps
accelerating, then ghostly cyan blades materialize behind the shooter and
snap onto whatever was struck, streaking through everything in between.
The phantom flurry is what fills the screen, not the arrows.
Deepwood: on-hit echo-flurry — landing N arrows on a target summons spectral
bolts that home through walls; snowball DPS while sustained on one foe.

### Phantom Phoenix  (128f @31ms, 484x175)
Measured: plain arrows tick 57-82; every 3rd shot = PHOENIX ~1ph tall bird
with 1.5-2ph flame wake, flat flight, pierces all 6 dummies in a row,
terminal white puff ~1.5ph at the wall; leaves every victim burning
(1-tick flames persisting seconds).
Motion: two normal twangs, then the third draw releases a burning bird that
sails the whole lane at chest height, igniting the entire row and bursting
against the far wall. The rhythm is visible and audible — players count
to three.
Deepwood: metronome shot — every 3rd fire is a 200% flying beast that
pierces + applies burn; count-up pips on the weapon sprite.

## GEOMETRY BOWS

### Pulse Bow  (145f @26ms, 512x216)
Measured: teal bolt = bright head + solid light-line trail 2-3ph; crosses
half the screen per frame (fastest thing measured); ricochets with sharp
mirror angles (V shapes off walls/floor, 4-5 bounces); full brightness kept
after each bounce; ticks 36-79, crit 146, hits whole row via bounce paths.
Motion: a laser that thinks it's an arrow. The bolt draws visible chevrons
around the room, folding off walls and floor at crisp angles, threading
back through the dummy line from behind. The trail IS the readability —
a glowing polyline of everywhere it has been.
Deepwood: ricochet geometry toy — 5-bounce light bolt with a persistent
polyline trail; slopes redirect it; rewards firing into closed rooms.

### Eventide  (203f @20ms, 400x209)
Measured: per shot 4 pink chaff bolts + 1 LANCE; lance is a 4ph long streak
crossing 5-6 dummies at once, color alternates gold/cyan; chaff ticks 47-63
on near targets, lance 108-208 down the row; ~2 volleys/s.
Motion: a soft pastel spray up close and a huge piercing lance through the
middle of it. The chaff peppers whatever is adjacent while the lance runs
the whole lane in a frame, so point-blank feels like a shotgun and long
range feels like a railgun.
Deepwood: distance-personality bow — close = wide chaff burst, far = single
massive lance; upcycles cheap ammo (chaff is free filler).

### Tsunami  (46f @33ms, 414x200)
Measured: 5 arrows per draw in a flat vertical stack ~0.6ph tall; flat
trajectory, 4ph crossed in ~2 frames; all 5 land near-simultaneously;
ticks 61-71 marching down the row (pierce); ~2 draws in 1.5s.
Motion: one string pull, five parallel arrows in a ruler-straight stack
that stays tight the whole flight. No fan, no arc — a flying fence slat
that shears through a row and reads instantly as "one ammo, five shots."
Deepwood: stacked volley — 5 flat parallel shots per single ammo/charge,
tight spacing kept by zero gravity on the volley.

### Aerial Bane  (221f @20ms, 400x462)
Measured: 6-arrow arcing fan per draw; at apex each SPLITS into ~5 downward
comets → umbrella canopy ~8ph wide of flame starbursts; descent columns at
45-90 deg; number spam 36-92 everywhere + 336-846 stacks on an airborne
target (+50% vs airborne); residue sparkles ~1.5s.
Motion: fires upward like a firework shell; the sky blooms into dozens of
falling embers that curtain the whole arena. The split happens above the
target so the delivery is a canopy of descending flame columns, murder on
anything flying through it.
Deepwood: split-canopy shot — arrows burst at apex into a downward fan;
bonus vs airborne foes; area-denial umbrella.

### Hellwing Bow  (336f @21ms, 300x318)
Measured: flaming BAT ~0.3ph head, short flame trail + spark dots; wavy
erratic path (±0.5ph vertical wander); infinite pierce — one bat crosses a
3x3 dummy grid hitting 24-31 each and exits; ~2 bats/s, aim scatter is the
identity (bats leave at visibly different heights).
Motion: loose out of the bow, drunk in the air, unstoppable through bodies.
Each bat wobbles its own path through the crowd trailing sparks, punching
through all nine targets without slowing. Inaccuracy plus infinite pierce
= fires into crowds, not at targets.
Deepwood: swarm-pierce shot — wavy infinite-pierce fire-bats with random
launch jitter; anti-crowd, hopeless vs single small targets.

### Marrow  (147f @21ms, 300x229)
Measured: bone arrow with dusty streak ~2.5ph long (longest gun-class
streak measured); crosses 4ph inside 1-2 frames; flat, no drop visible;
ticks 47-63; bone-chip debris on hit; fast cadence.
Motion: the arrow is basically a streak. You see the launch pose, a long
pale smear, and chips flying off the target in the same instant. Identity
is pure velocity — no gimmick, no curve, just the shortest time-to-target
in the bow family.
Deepwood: velocity identity — near-hitscan arrow whose 2.5ph motion streak
IS the visual; no drop, flat power.

### Chlorophyte Shotbow  (160f @28ms, 538x209)
Measured: 2-3 arrows per draw in a slight fan (~0.5ph spread at 4ph range);
hits 2 dummies on separate platforms simultaneously; ticks 34-46;
~2 volleys/s.
Motion: a repeater that pays one ammo and looses a small fan every pull.
The spread is narrow enough to double-tap one target up close and wide
enough to clip neighbors at range. Workhorse rhythm, no theatrics.
Deepwood: 2-3-for-1 repeater — every shot duplicates with slight fan;
the reliable mid-tier multiplier.

### The Bee's Knees  (126f @26ms, 348x160)
Measured: shot = a wavy LINE of bees (~8-10 dots strung over 3ph); arrow
tick 23-27 + bee ticks 4-6 swirling around the impact for 1-2s; bees
wander/home loosely to nearby foes.
Motion: the arrow is a swarm in single file. It flexes like a ribbon in
flight, and on arrival the file breaks formation into a cloud that keeps
stinging whatever stands near. One shot leaves a lingering hazard where
it landed.
Deepwood: line-of-familiars shot — projectile is a chain of critters that
scatter into a brief homing swarm on impact.

## LAUNCHERS

### Celebration Mk2  (193f @33ms, 565x311)
Measured: fires PAIRS; observed rocket personalities per pull: straight
green-line rocket, high-arcing gold sparkle rocket, corkscrew yellow dotted
rocket; firework ring bursts ~4ph across with radial streamers + white puff
clusters + gold star showers; ticks 76-89, crit 164; residue rain 1-2s.
Motion: a slot machine. Each trigger pull ejects two rockets whose colors
and flight styles are rolled from a table — one may fly true while its twin
loops overhead — and every detonation is a different firework. The reward
is watching which pair you got.
Deepwood: random-table launcher — 5-7 rocket personalities (straight/arc/
corkscrew/slow-boom...), two per shot, festival blasts; damage steady,
CHAOS visual only (house rule: never one-shots).

### Proximity Mine Launcher  (225f @38ms, 533x128)
Measured: mine launched flat with smoke trail, skids and settles on the
floor; becomes a barely-visible speck (near-invisible dormancy across
~100 frames); triggers when a zombie WALKS NEAR: multi-puff smoke blast
~2.5-3ph wide, 311 dmg.
Motion: fire and forget — literally. The shell rattles across the floor,
dies into the tile, and the room looks empty until something walks over
the spot and the floor detonates. The entire fantasy is the wait.
Deepwood: trap-laying launcher — armed floor mines (cap N, oldest fades),
visible only as a faint glint; huge triggered blast; siege/defense synergy.

### Nail Gun  (294f @21ms, 400x274)
Measured: nails near-invisible in flight (too fast); visible EMBEDDED as
light sticks poking out of the target (3+ at once); embed tick 16-18, then
~1.5s later each nail pops: gold starburst 1.5-2ph, tick 135-170 (~8x the
embed). Sparkle residue drifts.
Motion: tap-tap-tap and the target grows a porcupine coat; then the coat
detonates in sequence. The delay separates the sowing from the reaping —
sustained fire on one enemy stacks a payment that arrives all at once.
Deepwood: embed-detonate — small hit now, stuck charge pays 8x after 1.5s;
visible stuck nails are the count UI; on-kill nails eject and re-stick.

### Stynger  (314f @26ms, 515x190)
Measured: flat bolt → impact puff + 4-6 shrapnel pieces scattering in a
downward/outward umbrella up to 3-4ph from impact, EACH exploding again in
~0.7-1ph puffs; direct hit 117-137 (double), shrapnel 53-71 apiece;
~1 shot/1.2s.
Motion: one bang buys a cluster. The first explosion is just the seed —
fragments hop away in shallow arcs and pop where they land, so the damage
pattern is a splash zone that outlives the aim point by half a second.
Deepwood: flak launcher — impact spawns 2-5 full-damage bomblets with their
own secondary blasts; anti-cluster crowd weapon.

### Electrosphere Launcher  (459f @21ms, 234x350)
Measured: missile flies to aim → becomes a crackling SPHERE ZONE ~2ph
diameter; irregular wobbling electric ring, lightning filaments inside,
sparks flying off; lasts ~5s; ticks 68-92 at ~4-6/s per target inside;
2-3 spheres visible concurrently in demo.
Motion: the rocket doesn't explode, it PARKS. At the cursor it unfolds
into a standing ball of lightning that chews everything inside its ring,
edges redrawn every frame with electric jitter. You aim zones, not hits.
Deepwood: shot-becomes-a-zone — projectile converts to a 5s tick sphere at
the aim point; new cast replaces the oldest; control-space weapon.

### Snowman Cannon  (161f @26ms, 411x384)
Measured: small snowman-head missile, orange spark trail; HOMING arc —
visible curved dotted flight path up-and-over onto the target; blast
2-2.5ph fiery burst; ticks 126-149; dotted trail persists marking the
whole flight curve.
Motion: launches sideways, thinks better of it, and climbs into a lazy
homing arc that dives onto the mark. The lingering dotted trail draws the
whole journey like a comic panel. Blast is honest AoE.
Deepwood: homing missile with path-ink — the trail lingers as a drawn
curve; arcs over cover onto the locked target.

### Grenade Launcher  (431f @20ms, 350x330)
Measured: red-tip grenade, high 60 deg arc, smoke-dot trail marks flight;
BOUNCES on the floor before fuse; starburst 2.5-3ph gold-white, ticks
99-107 multi-target; ~1 shot/2s in demo.
Motion: a mortar lob that skips once or twice before the bang, so the shot
plays in three beats: launch arc, bounce hop, boom. Smoke dots hang along
the whole trajectory as the aiming feedback.
Deepwood: bouncing lobbed shell — fuse detonation after bounces, dotted
arc feedback; skill = banking the hop into the crowd.

### Jack 'O Lantern Launcher  (105f @33ms, 454x180)
Measured: spinning pumpkin ~0.5ph, tumbling; bounces to ~2ph height,
rolls along the ground toward the target; ~3-4 px/frame horizontal; contact
explosion: gold sparkle + smoke ~2ph, 101 dmg.
Motion: a lit pumpkin cartwheels out of the barrel, hops the terrain and
keeps rolling until it kisses something and pops. It's a ground-hugging
contact bomb — the floor does your aiming for you.
Deepwood: rolling contact bomb — bouncy grinning projectile that follows
terrain; detonates on touch; goofy Halloween energy.

## GUNS — SPREAD FAMILY

### Tactical Shotgun  (175f @20ms, 686x588)
Measured: 6 pellets/pull, auto ~2 pulls/s; spread covers ~1.5ph at 4ph
range; blue muzzle sparkle; ticks arrive as vertical stacks of 5-6 x 33-41
across 2-3 dummies on different platforms simultaneously.
Motion: a disciplined cone. Every pull posts a column of numbers on
everything inside the fan — vertical coverage is the point, clipping
targets on ledges above and below the aim line at once.
Deepwood: wide auto-cone — 6 pellets, tall spread that sweeps multi-level
rooms; steady military cadence.

### Quad-Barrel Shotgun  (139f @34ms, 360x274)
Measured: 8 pellets in a WILD fan (tracers at ±25 deg); ticks 21-28 small
+ 42 crits; ONE pellet always flies true to the cursor; ~1 pull/0.65s;
cheap-blast feel, big muzzle.
Motion: four barrels of chaos with one honest bullet hidden inside. The
fan sprays the whole doorway, pellets visibly diverging at silly angles,
but the guaranteed true pellet means the aim still matters.
Deepwood: chaos-spread + one-true-pellet — 8 wild tracers, exactly one
locked to the cursor; hallway eraser with a skill hook.

### Onyx Blaster  (218f @20ms, 776x556)
Measured: per pull: shotgun spread (ticks 26-71 on 2-3 targets, purple
muzzle) + DARK ORB ~0.5ph, slower (crosses 4ph in ~0.6s), purple sparkle
wake; orb detonates: BLACK smoke ring ~2ph + purple sparkles, 106 tick;
~1 pull/s.
Motion: two payments per trigger — the pellets land now, and a black
sphere floats down-range like a slow curse and erases the far end of the
lane a beat later. The staggered double-hit rhythm is the identity.
Deepwood: spread + delayed traveling nuke — every shot ships instant
pellets and a slow dark orb that detonates deeper in.

## GUNS — HOSE FAMILY (rate ladder)

### Minishark  (169f @20ms, 350x177)
Measured: dash tracers ~0.4ph; ~6-7 rounds/s; ticks 11-15; slight aim
wobble; muzzle flash every frame pair.
Motion: the entry-level hose — a purring stream of tiny dashes with damage
numbers stacking politely. Nothing special per bullet; the stream IS the
weapon.
Deepwood: hose baseline — lowest per-hit, highest uptime; ammo-save %
is the invisible upgrade knob.

### Uzi  (178f @20ms, 500x152)
Measured: ~8 rounds/s; ticks 22-40; one frame shows a full 4ph YELLOW line
tracer (high-velocity round); tight spread.
Motion: same hose, angrier — occasionally a round draws a complete line
from muzzle to target in a single frame, selling extreme muzzle velocity.
Deepwood: fast hose w/ velocity-line flourish — some bullets render as
full-lane tracers.

### Megashark  (142f @20ms, 350x175)
Measured: 2ph-long shark gun; red dash tracers ~0.5ph; ~7-8/s; ticks
27-37; recoil bob; 50% ammo-save invisible.
Motion: the hose grown up — bigger gun than player torso, steady stream,
numbers marching. Spectacle economy: all identity in the weapon silhouette
and the unbroken cadence.
Deepwood: mid hose — silhouette does the talking; give it a huge
distinctive gun sprite, plain fast stream.

### S.D.M.G.  (86f @33ms, 370x180)
Measured: ~10/s; ticks 73-95 + 144 crits; short dash tracers; minimal
extra fx (space-shark silhouette carries it); 66% ammo save.
Motion: endgame hose — nothing but rate and numbers, deliberately clean.
The restraint reads as confidence at the top of the ladder.
Deepwood: crown hose — highest rate, clean tracer stream, best ammo-save;
resist the urge to add particles (the ladder's other rungs own gimmicks).

### Chain Gun  (147f @20ms, 450x295)
Measured: ~15 rounds/s (tracer dashes visible EVERY frame, several aloft);
wild spread ±20 deg wobble; ticks 33-44 pouring on 3 dummies at once.
Motion: rate so high accuracy dies — the stream hoses the whole cone like
a pressure washer, tracers scattering across three bodies simultaneously.
You point in a direction, not at a thing.
Deepwood: max-rate + max-scatter — DPS spread across a cone; inaccuracy
AS identity (Gatligator cousin lower tier).

## GUNS — BURST / RHYTHM / SNIPER

### Clockwork Assault Rifle  (175f @20ms, 300x170)
Measured: 3-round bursts (orange dash tracers ~1ph; tick triplets 21-27
clustered), ~0.5s between bursts; crit 44-52; only first round bills ammo.
Motion: tap — three tracers chase each other down the lane and three
numbers pop as one clump — pause — tap. The triplet clumping of the
numbers makes the burst readable at a glance.
Deepwood: 3-burst-for-1 — one ammo/charge per burst; triplet number
clump = signature.

### Revolver  (87f @33ms, 370x180)
Measured: single shots ~2/s; short orange tracer dash ~0.5ph; ticks 27-31;
recoil pose; screen crossed in <2 frames.
Motion: the plain single-action baseline — bang, dash, number. Deliberate
cadence with visible re-aim between shots.
Deepwood: rhythm skill hook (wiki: perfect-timing re-trigger) — pulls timed
to the recoil beat stack fire-rate/crit; the tracer flashes brighter on a
perfect beat.

### Sniper Rifle  (179f @43ms, 507x217)
Measured: no visible projectile (hitscan-fast); 400 base / 173-204 body /
314-366 crit; ~1 shot/2s; final frames show the CAMERA PANNED toward the
distant target group (scope view); whole-screen reach.
Motion: nothing travels — the target simply takes 400. The spectacle is
the camera: the view slides toward wherever the scope looks, and the shot
lands across a distance no other gun can even render.
Deepwood: scoped one-shot — right-click shifts the camera toward the aim
(POV extend), slow bolt cycle, biggest single number in the gun roster.

## GUNS — ODDBALLS

### Xenopopper  (191f @25ms, 494x309)
Measured: 3-5 purple bubbles drift from muzzle (~2-3 px/frame, ~0.5-1ph
travel, slight scatter); after ~0.5s each POPS and snap-fires an instant
bolt at the cursor: far target takes simultaneous 50-59 x4 + 110 crits;
purple sparkle at pop.
Motion: plant, then punch. The bubbles wobble out harmlessly like spat
gum, hang a beat, and the entire cluster fires as one synchronized volley
at wherever the cursor is NOW — aim is sampled at pop time, not shot time.
Deepwood: plant-then-steer volley — slow decoy orbs that all snap-fire at
the current aim after a beat; re-aiming mid-flight steers the salvo.

### Piranha Gun  (272f @26ms, 282x162)
Measured: 3 piranhas fly out (~0.5ph fish), LATCH onto the target and chew
while trigger held: continuous ticks 17-28 streaming; on kill they re-home
to the next target (seen migrating between victims); return on release.
Motion: hold-to-gnaw. The fish stay clamped and wiggling on the enemy like
angry pennants, the number stream never stopping while you hold. Killing
one victim sends the school hunting the next without a re-fire.
Deepwood: latch-and-chew — held-beam-as-pets; sustained tick stream, auto
target hop on kill, recall on release.

### Coin Gun  (1459f @20ms, 470x169)
Measured: streams a horizontal chain of gold coin discs (4-6 visible in a
line, spacing ~0.4ph); fast flat flight; ticks 22-48 (silver-grade) and
89-224 (gold-grade) — damage = denomination; coins scatter as debris.
Motion: literally firing your wallet — a glittering conveyor of currency
streaks across the lane, hits scale with what you loaded, and the misses
bounce on the floor like spilled change.
Deepwood: economy-as-ammo panic gun — fires gold, damage scales with coin
tier; perfect colony-game emergency lever + gold-sink.

### Sandgun  (288f @51ms, 445x194)
Measured: sand clump arcs with gravity; where it lands it BECOMES TERRAIN —
tan piles visibly accrete into ledges/mounds across sequential frames
(persistent for the whole 14.7s demo); ticks 25-31 en route.
Motion: combat terraforming. Each shot is a fistful of world that hurts on
the way down and then STAYS, stacking into ramps and burying targets.
The battlefield is different after every trigger pull.
Deepwood: terrain-shot — projectile leaves real (temp?) tiles on impact;
bridges gaps / buries foes; ties into our mining-world Underdark plans.

### Pew-matic Horn  (291f @20ms, 700x238)
Measured: every shot a DIFFERENT junk sprite (fish, balloon-blob, tiny
plane, gray bits observed); flat fast flight; damage lottery ticks 2, 11-13,
15-17, 23-33, 45 (≈0.1-2.0x roll); ~2/s.
Motion: a toy horn that spits the junk drawer. The projectile sprite and
the number are re-rolled every pull, so the fun is the slot-machine readout
— sometimes a wet fish for 2, sometimes a jackpot 45.
Deepwood: jackpot junk-shooter — randomized projectile sprite + damage
multiplier table; pure personality weapon.

### Harpoon  (331f @20ms, 1000x188)
Measured: harpoon head + visible dotted CHAIN back to the gun; max reach
~8ph (taut) with rope sag/curve on the way out (~5ph arcs); pierces the
row going OUT (ticks 22-28) and AGAIN on reel-back (second tick wave);
can't refire till returned (~1.5-2s cycle).
Motion: throw, then drag. The chain stays connected the entire flight,
sagging like real rope, and the return pass re-cuts everything the exit
pass touched. One tool, two damage sweeps and a tether fantasy.
Deepwood: tethered spear — out-pierce + reel-back re-hit, sag physics on
the chain visual, single-projectile discipline.

### Toxikarp  (236f @40ms, 364x159)
Measured: green bubbles fly flat ~2-4ph then WANDER UPWARD in a drifting
column (1-2 px/frame); linger seconds; chains of ~8 bubbles curving up
across the top of the screen; slow steady emission.
Motion: spits a stream of toxin bubbles that lose interest in going
forward and float away upward, owning the airspace above the fight.
Vertical shafts and ceilings become kill boxes; open sky wastes it.
Deepwood: rising-bubble stream — projectiles convert to slow upward
drifters; the anti-Daedalus (owns vertical shafts, weak in the open).

### Bone Javelin  (406f @21ms, 300x243)
Measured: thrown spear ~1.5ph LONG; flat with slight droop; EMBEDS —
javelins visibly stuck horizontal in the target for seconds (2-3 at once
at different heights), mid-flight + stuck coexist; DoT ticks 18-23
continuous per stuck spear (defense-ignoring flat).
Motion: the spear stays where it lands, jutting out of the victim like a
scoreboard. Each additional throw adds another protruding shaft and
another tick stream — the enemy becomes a countable pincushion.
Deepwood: stacking embed DoT — up to N visible stuck spears, flat ticks
ignoring armor; the stuck sprites ARE the stack counter.

### Beenade  (434f @20ms, 300x374)
Measured: lobbed green grenade arc; blast = white puff + 8-10 bees
scattering radially; bees then wander/home across the WHOLE arena for
several seconds ticking 11-14 on every dummy in all corners.
Motion: the explosion is alive. The bang itself is small — what matters is
the swarm it frees, which spreads out and keeps working the room long
after the throw, finding targets the blast never touched.
Deepwood: explosion-is-a-swarm — grenade converts to N homing critters on
detonation; room-clear over 3-4s instead of instant AoE.

### Molotov Cocktail  (581f @21ms, 400x272)
Measured: bottle arcs high with tumbling sparkle trace; shatter → main
burst + 5-6 fire PATCHES spread over 4-5ph of floor/platform (~0.4-0.7ph
flames); burn ~5-8s, ticking 1s + 10-26; patches flicker w/ rising sparks;
patches land on BOTH the platform and floor below.
Motion: throw fire, get territory. The shatter splashes burning puddles
across every surface under the arc, and the zone keeps paying ticks while
you do something else. Ground-holding in a bottle.
Deepwood: lingering fire patches — throwable that seeds 5-6 independent
flame zones; area denial for sieges (walls/gates synergy).

## STAR CANNON LINE

### Star Cannon  (238f @20ms, 974x180)
Measured: star-glyph shots ~0.4ph with blue-purple glow wash; flat,
infinite pierce — a 25-dummy row lights up end to end (band of glow ~1ph
tall); ticks 46-62 everywhere + 112-120 crits; ~6-8 shots/s.
Motion: a hose that fires SKY. Stars scream down the lane leaving a
continuous blue ribbon of light, every body in the line paying per star.
The screen-wide glow band is the most spectacle-per-second of any gun
studied.
Deepwood: farmed-ammo super hose — power gated by unbuyable star ammo;
infinite pierce + lane-wide glow ribbon.

### Super Star Shooter  (67f @53ms, 370x179)
Measured: star muzzle flash; stars drag a thick GOLD comet streak ~2ph;
pierce 3 targets; sparkle residue scatter; ticks 32-79 + 158 crits;
~3-4/s.
Motion: the same idea grown into artillery — each star is now a golden
comet with a fat tail, fewer per second but each one a small event with
its own splash of residue.
Deepwood: the upgrade rung — slower, heavier star-comets (2ph tails)
replacing the ribbon with per-shot spectacle.

## DART / FLAME / VORTEX

### Dart Rifle  (317f @20ms, 400x237)
Measured: small finned dart visible mid-flight; flat fast; ticks 61-69
~1/s; demo dart leaves the target dripping green + lingering 1-ticks for
seconds (poison-family ammo behavior).
Motion: one precise thwip per second, and the ammo does the storytelling —
the wound keeps dripping after the dart lands. The gun is a delivery
system; the dart type is the weapon.
Deepwood: ammo-defines-behavior showcase — dart variants (split/ricochet/
ground-flame/drip) on one slow precise rifle; pairs with our quiver/charge
slot idea.

### Flamethrower  (247f @20ms, 400x150)
Measured: continuous flame column 7-8ph long x ~1ph tall while held,
engulfing 4-5 targets; stream has wavy bulge pulses; ticks 20-39 rapid;
on release targets STAY burning 3+s (1-ticks, per-target flame overlays).
Motion: not a projectile — a place where everything is on fire. The
corridor fills wall-to-wall with rolling flame while held, and the burn
outlives the trigger on every body it licked.
Deepwood: held-stream + persistent ignite — corridor-filling cone, burn
DoT continues after release; fuel/mana drain while held.

### Vortex Beater  (162f @25ms, 453x203)
Measured: bullet stream ~10/s (orange dashes, ticks 52-85) + every
~0.6-1s a homing ROCKET with wavy teal dotted trail; rocket detonation =
cyan cross/plus-shaped particle burst 2-2.5ph, ticks 116-178; cyan
residue drifts outward.
Motion: two weapons sharing a trigger — a steady bullet hose underneath
and a periodic guided firework on top. The teal rocket wanders its own
dotted path before slamming in with the big cross-flash that punctuates
the stream.
Deepwood: hose + free periodic seeker — every Nth second ships a homing
bomb at no ammo cost; the punctuation-rhythm hose.

---

## FAILED
- Barrel Launcher: NO demo GIF exists anywhere (unreleased 1.4.5 announce
  item; wiki has static art only). Behavior known from text digest (no
  ammo; +33% after a bounce) — motion unstudied, 3 source attempts made.

## CROSS-CUTTING MEASUREMENTS (the ranged calibration constants)
- Tracer dashes: 0.4-0.6ph (hoses), 1ph (bursts), 2-2.5ph streaks
  (velocity-identity), full-lane lines (sniper/pulse tier).
- Blasts: 1.5-2ph (per-bomblet/nail), 2-2.5ph (rockets/zones), 3ph
  (mines/grenades), 4ph ring (celebration crown fireworks).
- Zones: sphere 2ph/5s (electro), fire patches 0.4-0.7ph/5-8s (molotov),
  flame column 7-8ph held (flamethrower).
- Sky-rain: spawn above camera, ±1.5ph x-jitter around aim, 8-15 deg tilt,
  full-screen drop 0.4-0.5s.
- Hose rate ladder: 6-7/s → 8/s → 10/s → 15/s; per-hit damage compresses
  as rate climbs; crown rung goes CLEANER not busier.
- Multishot economy: 5-stack (tsunami), 2-3 fan (shotbow), 6-8 pellets
  (shotguns, one-true-pellet trick), 4+lance (eventide).
- Delayed payoffs measured: nail pop 1.5s at ~8x embed; onyx orb ~0.6s
  behind pellets; xeno bubbles 0.5s; mines indefinite.
