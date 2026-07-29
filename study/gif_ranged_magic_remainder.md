# GIF MOTION STUDY — RANGED + MAGIC REMAINDER (43 weapons, 2026-07-29)

Method: same as gif_ranged.md / gif_magic.md. Fandom mirror demo GIFs resolved via
terraria.fandom.com/api.php (File:<Name> (demo).gif), downloaded from
static.wikia.nocookie.net with `&format=original`. Per weapon: 5 evenly-spread
keyframes + a consecutive 3-frame triplet at the midpoint (for px/frame velocity),
redrawn 1.5-3x NearestNeighbor into one labeled contact sheet with a 48px = 1.0
player-length (PL) grid overlay. Cadence read off the GIF's native per-frame delay
table. NO pixels copied — numbers and motion grammar only. This file covers the
slice NOT already in gif_ranged.md or gif_magic.md (cross-checked against both;
Quad-Barrel Shotgun/Dart Rifle/Molotov Cocktail/Aqua Scepter/Heat Ray/Laser
Machinegun were already done and skipped here).

---

## RANGED — GUNS (starter/mid tier)

### Musket (300x211, 159f @20ms, 3.22s)
Measured: no visible projectile in any sampled frame — the ball is too small/fast
to catch even in the consecutive triplet, reading as near-hitscan; hits land
~800ms apart (1 shot/~0.8s); damage 32-34 base, 42-44 on crit (~+30%).
Motion: raise, aim, bang — the pose holds through a slow single-action cadence
with nothing to show for the actual bullet; the crit bump is modest, not flashy.
Deepwood: baseline slow single-shot musket — hitscan-flavored (no rendered
projectile), crit a modest bump not a spike; teaches "aim and wait" cadence
before hose-class guns take over.

### The Undertaker (370x180, 74f @33ms, 2.46s)
Measured: short orange tracer dash ~0.3-0.5 PL; a volley always lands as TWO
near-simultaneous ticks (24+22, later 25+22); cadence ~600-650ms between pulls
(~1.6 shots/s).
Motion: a sawed-off double-barrel that always pays out in pairs — one trigger
pull, two numbers stacked on the same instant, stubby recoil pose between shots.
Deepwood: double-pellet sawed-off — every pull fires 2 simultaneous pellets that
both tick; compact, no gimmick beyond the guaranteed double hit.

### Boomstick (350x315, 201f @20ms, 4.08s)
Measured: 3 dummies at different heights (2 elevated pedestals + 1 ground) all
take ticks from one pull (18-25 range); shots ~1000ms apart (~1/s).
Motion: one wide pump-blast per second whose vertical spread is tall enough to
clip ledges above AND below the aim line in the same pull.
Deepwood: early tall-spread shotgun — a mini version of the already-documented
Tactical Shotgun's vertical coverage, one slow pump instead of autofire.

### Phoenix Blaster (370x180, 69f @33ms, 2.3s)
Measured: consecutive triplet (f33-35, ~30ms apart) shows the tracer advancing
toward the target each frame — a genuinely fast little pistol; base 24-26,
crit 31-34 (crit lands often); second volley ~540-600ms after the first
(~1.7-2 shots/s sustained).
Motion: a peppy compact sidearm — quick recoil pose, short bright tracer, crits
almost as common as normal hits.
Deepwood: reliable early backup pistol — quick auto-fire (~2/s), short tracer,
above-average crit frequency; the "always in your pocket" gun.

### Shotgun (681x606 canvas, 161f @20ms, 3.28s)
Measured: one pull tags 3 separated dummies (2 stacked near + 1 further) at
once — near pair takes 27-35, the lone far dummy eats a single clean 48-52;
cadence ~1.1-1.5s (single pump, not auto).
Motion: a pump shotgun that doesn't spray so much as slap the whole room at
once — no visible pellet tracers at this range, the read is entirely the
numbers landing simultaneously on every body present.
Deepwood: base pump shotgun — one full-width blast per ~1.2s hitting the whole
vertical column simultaneously; the honest workhorse before Boomstick/Tactical
variants add rate.

### Red Ryder (370x180, 77f @33ms, 2.56s)
Measured: short recoil pose, no real projectile art, ticks land ~630-640ms
apart (~1.6 rounds/s), flat unchanging damage ~26-27, one graze/miss "*" mark.
Motion: a plinky BB rifle — steady metronome cadence, no crits, no drama, the
tutorial-tier plink.
Deepwood: joke/starter rifle — flat low-damage plinker at a steady clip, cheap
ammo, no gimmick; the tier before Musket-class guns matter.

### Gatligator (400x377, 223f @20ms, 4.52s)
Measured: 3 dummies at different heights again; sustained autofire cone stacks
many ticks (22-39) fastest on whichever body sits mid-cone; one big cluster of
6 different numbers piles onto a single target within ~150ms.
Motion: an alligator-jawed machine gun that opens a tall autofire cone — three
elevated dummies all catch pellets, but whichever one is dead-center racks up
numbers fastest.
Deepwood: auto-cone hose with alligator flair — sustained autofire in a TALL
cone for multi-level rooms; the gun's jaw-clack IS the joke, numbers pile fast
center-cone.

### Venus Magnum (401x178, 195f @40ms, 7.8s)
Measured: a vertical stack of 4 dummies all take near-simultaneous hits from one
shot (38-53 across all four); brief green muzzle glimmer/particle between casts.
Motion: a shimmering high-end pistol whose bullet threads an entire vertical
stack for near-equal damage on every body, muzzle flashing a small green
glimmer as its tell.
Deepwood: piercing shimmer pistol — one bullet threads a whole vertical column
for even damage each; premium late-game sidearm identity is pierce + crit, not
rate.

### Candy Corn Rifle (240x288, 151f @34ms, 5.1s)
Measured: 2 dummies elevated + 2 flanking + 1 ground, all in view; one shot's
numbers cascade across up to 5 bodies at once (108, 96, 59, 48, 56, 17...),
each with a small kernel-debris fleck; volleys ~1.2-1.3s apart.
Motion: a candy corn projectile ricochets from body to body almost instantly,
tagging everyone present in one throw before the debris settles.
Deepwood: multi-ricochet bouncer — one shot chains between every visible
target, leaving corn-kernel debris pips at each bounce; great "clear the room"
novelty gun.

### Blowgun (400x205, 202f @20ms, 4.04s)
Measured: single flat dart, ~1 shot/s; direct hit ~68 plus two smaller lingering
ticks (31, 29) trailing after — a poison-flavored follow-up; later volley rolls
lower (34/31).
Motion: a slim dart flies flat and fast, lands a solid punch, then the wound
keeps dripping a beat or two after.
Deepwood: poison delivery tube — flat fast dart, modest direct hit + 2-3
lingering poison ticks; ammo-flavor-defines-poison, pre-hardmode cousin to the
already-documented Dart Rifle idea.

### Elf Melter (500x182, 335f @20ms, 6.76s)
Measured: press-and-hold ignites the ENTIRE 4-dummy lane simultaneously (many
overlapping ticks per body: 58/65/51, 43/34/56, 122/64/63/16, 46/43/46/47);
release leaves every victim independently burning with tiny "1" ticks still
firing at t=6.74s (5+ seconds after the beam stopped).
Motion: a held flame column floods the whole lane at once, and letting go
doesn't end it — every scorched body keeps smoldering long after the trigger's
released.
Deepwood: whole-lane held flame nova — same held-cone verb as our documented
Flamethrower, but the burn DoT tail is even longer (5+s); the "premium" flame
hose upgrade.

### Snowball Cannon (426x182, 72f @46ms, 3.31s)
Measured: small slow visible snowball puff, ice-splash on contact; cadence
~800-900ms (~1.2 shots/s); damage 16-21 base, one 31 crit spike.
Motion: a squat cannon lobbing visible snowball puffs at a steady clip, each
splashing into a brief ice-splash on contact.
Deepwood: festive basic launcher — slow visible projectile, small ice-splash
FX, steady damage with the occasional crit; a cute seasonal starter gun.

### Paintball Gun (316x162, 187f @27ms, 5.03s)
Measured: each pull sprays a cluster of small paintball pellets in a
color-cycling burst (cyan then blue, shown via a small colored ammo-gauge bar);
each burst registers 5-6 SEPARATE small ticks (6-19) rather than one number;
cadence ~1150-1200ms (~0.85/s).
Motion: a splattery multi-pellet sprayer — colors cycle per shot, and the
payoff is a flurry of tiny chip-damage numbers instead of one clean hit.
Deepwood: paint-splatter multi-pellet spray — ~5-6 tiny pellets per pull,
color cycling as the ammo-type tell; a visual burst standing in for one big
number.

### Water Gun (301x80 canvas, 71f @40ms, 2.84s)
Measured: a thin continuous water stream bridges the whole gap instantly and
just makes the target visibly wet (droplet/puddle FX); no damage number ever
appears across any sampled frame in the whole 2.84s clip.
Motion: harmless by design — the stream is all flavor, soaking the target with
zero real combat presence.
Deepwood: the intentional non-weapon — continuous jet that only applies a
Soaked/wet status, no meaningful damage; a comic-relief or utility tool (put
out our fire zones?), never a combat option.

### Slime Gun (226x122, 60f @54ms, 3.22s)
Measured: a short arcing spray of slime droplets coats the target; slime then
visibly DRIPS off the target for seconds after the spray stops (still dripping
at f59/3.15s); no clear damage numbers observed.
Motion: the spray itself is brief but the residue lingers far longer than the
attack — a status/marking gun more than a damage dealer.
Deepwood: utility slime-coat sprayer — brief arc that leaves a dripping-slime
visual for several seconds; pairs well with a "marked" or "slowed" status idea.

### Molten Fury (550x209, 285f @20ms, 5.7s)
Measured: fired arrow's entire flight (full ~9-10 PL screen width) reads as a
single dotted ember trail lasting under a frame gap — near-instant arrival;
direct hit 37/31, then the target keeps ticking "1" burn for several seconds
(still smoldering past 4.26s, out by 5.68s).
Motion: fire-and-forget — the whole flight flashes across the screen at once,
then the payload is the multi-second burn it leaves behind, not the arrow.
Deepwood: near-instant flaming arrow — the trail draws itself across the whole
screen in a blink, then hands off to a multi-second burn DoT; the arrow is
just the delivery flash.

---

## RANGED — BOWS

### Ice Bow (500x185, 163f @20ms, 3.26s)
Measured: full-flight sparkle trail visible the whole ~10 PL crossing; hits
pair up (38+48, or 44+48) — a main arrow plus a bonus ice-shard tick; target
left visibly dripping meltwater for several seconds after.
Motion: a frost bow that leaves a sparkling trail the entire flight, striking
with a main hit plus a bonus ice tick, and the target keeps dripping cold water
long after.
Deepwood: paired-arrow frost bow — each pull fires a main arrow + bonus ice
shard (two near-simultaneous ticks), full-flight sparkle trail, target visibly
chilled/dripping for a few seconds.

### Shadowflame Bow (610x226, 141f @33ms, 4.7s)
Measured: 5-dummy diagonal formation; one shot ignites a spreading violet
shadowflame that ticks small (5) on EVERY nearby dummy simultaneously while the
directly-struck ones also take a big hit (50-94); the small ticks persist for
several seconds after the direct hits stop (still going at 3.5s, clear by
4.66s).
Motion: a cursed bow whose arrows infect the whole cluster — one struck target
spreads shadowflame to everyone nearby, all ticking together while the violet
sparkle envelops the group.
Deepwood: contagion-DoT bow — arrow ignites shadowflame that SPREADS to all
enemies within range, everyone ticking small simultaneously for several
seconds while the direct hit stays large; a crowd-curse archer weapon.

### Demon Bow (610x180, 60f @33ms, 2s)
Measured: flat arrow crosses the ~9-10 PL gap in under a second; steady ~19
damage, hits land roughly every 500ms (~2 shots/s); no special effect beyond a
faint red tip.
Motion: a plain demon-forged bow — flat, moderately fast arrows, steady
half-second cadence, pure fundamentals.
Deepwood: baseline demonic arrow — flat flight, ~2 shots/sec, zero gimmick; a
mid-early bow that's pure mechanics, a contrast piece to the gimmick bows
already documented.

---

## RANGED — LAUNCHERS

### Rocket Launcher (423x226, 132f @32ms, 4.16s)
Measured: smoke-trailed rocket visible advancing across consecutive frames
(~13 PL/s estimated from the triplet); detonation tags an entire pedestal
cluster simultaneously for big numbers (196, 97, 83); cadence roughly 1
rocket/second.
Motion: a slow arcing rocket trailing smoke the whole flight, detonating in a
chunky white-smoke blast that hits everyone clustered together at once.
Deepwood: multi-target rocket volley — one lobbed rocket per second, smoke
trail the whole way, single detonation hitting a whole huddle simultaneously;
distinct from Grenade Launcher's bounce-then-fuse and Snowman Cannon's homing
arc — this one is a straight smoky lob with a wide simultaneous-hit blast.

### Celebration (230x233, 174f @40ms, 6.96s)
Measured: one trigger pull blooms into a multi-ring expanding firework spiral
that swallows nearly the whole screen; color shifts pink then cyan across the
volley; rings visibly still spinning outward 3+ seconds after the blast.
Motion: a single shot detonates into a slowly expanding double/triple ring of
sparkle that lingers as pure spectacle for several seconds after landing.
Deepwood: whole-screen firework ring — each shot blooms into a multi-ring
expanding spiral lingering 3+s as spectacle; the base rung below Celebration
Mk2's random-personality upgrade (same detonation grammar, one consistent
ring pattern instead of a rolled table).

### Grenade (270x200, 93f @33ms, 3.1s)
Measured: grenade off-screen mid-arc (apex above frame), lands a single clean
detonation (~63 damage) with a double-lobed smoke cloud that dissipates within
about a second; no bounce, no residue after.
Motion: a simple lobbed grenade that vanishes mid-arc then erupts once in a
chunky bang — no lingering effect, no gimmick.
Deepwood: baseline lobbed grenade — one clean detonation (~60+), quick-
dissipating smoke, no bounce/lingering; the plain explosive before Molotov/
Beenade-style bonus effects layer on.

---

## RANGED — THROWN

### Shuriken (300x164, 45f @33ms, 1.5s)
Measured: a single throw bounces between ALL dummies present (a close cluster
of 3 plus one standalone further away), each landing a similar small hit
(9-11), the far one taking 11 too — full ricochet coverage from one throw.
Motion: one shuriken thrown flat instantly tags the near cluster then bounces
onward to also clip the far target, near-equal damage each contact.
Deepwood: ricochet throwing star — flat instant throw that bounces off
multiple enemies for near-equal small hits; cheapest "hits the whole room"
tool in the pre-hardmode thrown kit.

### Throwing Knife (286x164, 42f @33ms, 1.4s)
Measured: knife visibly embeds (small stuck-knife sprite) in each body along
its flight for a beat before vanishing; two dummies at different distances
both take a hit in the same throw (11 near, 12 far) — consistent modest
damage regardless of position.
Motion: a slim knife thrown flat and fast, sticking visibly in every body it
threads through, similar modest damage on each.
Deepwood: piercing throwing knife — flat instant throw, visibly embeds
momentarily in every pierced body, consistent modest damage; the reliable
"ranged melee" thrown option.

### Spiky Ball (372x164, 63f @33ms, 2.1s)
Measured: a small grey spiked ball visibly lodges in the target for a beat
(debris sparks) before dropping away; repeated throws land 11-17, one throw
crits up to 17.
Motion: a spiked ball lobbed flat, sticking visibly for a moment in whatever
it hits before falling, modest damage with the occasional crit spike.
Deepwood: bouncy embed-ball — thrown weapon that visibly lodges in the target
each throw (readable "stuck" tell), modest damage; cheap earlygame sibling to
Throwing Knife/Shuriken.

### Frost Daggerfish (450x404, 308f @20ms, 6.2s)
Measured: a small icy fish TUMBLES as it falls in a shallow arc (visible
diagonal descent across the consecutive triplet) rather than flying flat;
one throw can splash 2 nearby dummies at once (15/15/17 left cluster,
19/38/18 right cluster); slow cadence (~1.5s+ between throws).
Motion: an icy little fish lobbed in a shallow arc, tumbling as it falls, that
can clip more than one target for a bonus splash tick.
Deepwood: lobbed frost-fish — arcing tumble-toss with a splash bonus on
adjacent targets, slow cadence, novelty-fish flavor; the arcing cousin to Bone
Javelin's flat-embed idea.

### Javelin (500x226, 140f @21ms, 2.88s)
Measured: one throw pierces ALL 3 dummies in the row simultaneously for
similar damage regardless of position (18-36 each); a fresh javelin launches
roughly every ~700ms.
Motion: a spear thrown dead flat that skewers straight through every body in
the lane at once, near-equal damage on each; a new one flies out every 0.7s.
Deepwood: full-pierce thrown spear — flat throw instantly threads the whole
lane for near-equal damage; "the whole hallway, one motion" thrown weapon.

### Paper Airplanes (360x164, 139f @51ms, 7.13s)
Measured: the plane glides out flat, then visibly REVERSES direction mid-air
and boomerangs back toward the player once it runs out of range; damage is a
flat "1" per hit (Water Gun-tier joke damage); two planes can be aloft at once
(one out, one returning).
Motion: paper airplanes glide out and auto-return to the thrower's hand after
their range runs out; near-harmless, pure comic-relief flight path.
Deepwood: boomerang joke-dart — near-harmless plane that flies out and
auto-returns, up to 2 aloft at once; a utility/comedy slot alongside Water
Gun's "intentional non-weapon" niche.

---

## MAGIC — PIERCING BOLT STAVES (family)

### Diamond Staff (350x194, 209f @21ms, 4.3s)
Measured: a fast crystal bolt instantly threads both dummies in the lane at
once (20-26 each hit), brief white impact puff, no big variance; cadence a
steady ~1 cast/second.
Motion: a clean piercing bolt that threads the whole lane for even damage on
everyone hit, no flourish beyond a small impact puff.
Deepwood: clean piercing bolt staff — fast crystal shard threads the lane for
even damage, ~1 cast/sec, minimal FX; the "reliable pierce" staff before
showier elemental ones.

### Ruby Staff (346x157, 53f @28ms, 1.47s)
Measured: fireball pierces 2 dummies with a stepped-down damage falloff — first
body takes 48, the second only 19 (repeats identically on the next cast); pink
ember trail marks the path; cadence ~1 shot/second.
Motion: a ruby-tipped staff lobs a fireball that hits the first body hard then
carries on to tap the second for much less — damage visibly steps down each
body it threads.
Deepwood: falloff-pierce staff — first target pays full, later pierced targets
take a fixed lower cut (~40% of first hit); contrast piece to Diamond Staff's
even piercing.

### Frost Staff (350x196, 205f @20ms, 4.1s)
Measured: wide dotted ice-crystal bolt punches through both dummies at once
for matching damage (40-52), with an occasional big crit spike (92, ~2x);
cadence ~1 cast/second.
Motion: a frost bolt that threads both bodies for solid matching damage, with
rare crit spikes nearly doubling the number.
Deepwood: even piercing frost bolt — twin-cousin of Diamond Staff (same
even-pierce grammar, frost palette, occasional big crit); reinforces sharing
one pierce-bolt codepath across the family.

### Unholy Trident (303x139, 90f @40ms, 3.6s)
Measured: a fast trident-shaped bolt instantly threads all 3 targets in the
lane for VERY high simultaneous damage (65-97 per body!), no lingering DoT;
cadence ~840-880ms (~1.2 casts/s).
Motion: a flat, near-instant bolt that skewers every body in the lane for huge
matching numbers — no debuff, no lingering effect, just a hard clean punch
through the whole row.
Deepwood: heavy-hitting pierce bolt — the "big number, no gimmick" premium
staff; raw burst through the whole lane instead of the family's usual DoT
focus, a deliberate contrast piece to Poison/Venom Staff below.

---

## MAGIC — POISON/DoT STAVES (family)

### Poison Staff (470x274, 149f @31ms, 4.63s)
Measured: one bolt pierces all 3 targets in the row, each taking a direct hit
(24-49 depending on position) PLUS a shared poison DoT (small "1" ticks) that
keeps firing on every struck body for several seconds after (still ticking at
4.6s).
Motion: a piercing poison bolt threads the whole row, tagging each body with a
solid hit and leaving all of them dripping poison long after the shot passed.
Deepwood: piercing poison lane-bolt — one cast threads the row for a direct
hit + shared poison DoT on everyone struck; cheap sustained group damage, the
pre-hardmode "crowd poison" staff.

### Venom Staff (295x188, 151f @40ms, 6.04s)
Measured: two 5-dummy rows (10 targets); one cast blankets nearly the ENTIRE
crowd with a uniform poison tick (~15/target) that is STILL ticking on
survivors at the full 6.0s demo length, plus a few bigger direct hits (20-49)
on the directly-struck bodies.
Motion: a single cast blooms into a mist that tags an entire two-row crowd at
once — most bodies get a uniform poison drip while a few nearby ones eat a
bigger direct hit, and the whole crowd keeps dripping for the entire fight.
Deepwood: crowd-poison bloom — one cast coats up to 10 enemies in a
near-permanent poison DoT plus bigger direct hits on the ones it centers on;
the premium "poison the whole room" upgrade from Poison Staff's single-lane
version.

---

## MAGIC — FLORAL LOB FAMILY

### Flower of Fire (400x282, 524f @21ms, 10.78s)
Measured: a rose/flower ornament near the caster lobs a single fireball in a
curling sparkle-trail arc; lands one heavy hit (42-50) then leaves the target
quietly burning — still ticking "1" at 8.02s, gone by 10.74s (a very long
burn tail); only one real volley observed across the whole 10.78s clip (slow
cadence).
Motion: a floating flower companion lobs a fireball in a gentle arc, then goes
quiet while the target smolders for several seconds — slow, deliberate, one
big payoff per cast.
Deepwood: floral fireball lobber — conjures a small flower ornament that arcs
a single heavy fireball with a long burn tail (3+s); slow cadence, big
per-cast commitment, cute cosmetic-caster flavor.

### Flower of Frost (380x200, 122f @33ms, 4.06s)
Measured: same curved sparkle-trail lob grammar as Flower of Fire but ice-blue;
lands one solid hit (48) then a decaying chill DoT (22 stepping down to 2)
that persists ~2-3 seconds before clearing.
Motion: the frost twin of Flower of Fire — identical gentle arcing lob, one
solid hit, then a numbing chill that steps down and fades over a couple of
seconds.
Deepwood: floral frost lobber — same arc-toss grammar as Flower of Fire but
ice-flavored with a shorter decaying DoT; the two "flower" wands should share
one lob/decay codepath, differing only in VFX color and DoT type.

---

## MAGIC — RAY GUNS

### Space Gun (376x154, 106f @28ms, 2.93s)
Measured: a fast green laser streak threads all 3 dummies in one pull for
near-identical modest damage (16-22 each); consecutive triplet shows the beam
advancing rapidly frame to frame; cadence ~1.3s between volleys.
Motion: a compact ray gun spitting a fast green streak clean through the whole
row, tagging every body for similar modest damage in one pull.
Deepwood: even-pierce laser pistol — one fast bolt threads every target in the
lane for similar modest damage each pull (~1.3s cadence); the compact
"no-frills laser" sidearm.

### Laser Rifle (400x167, 220f @20ms, 4.4s)
Measured: each pull channels a short rapid burst of violet beam segments that
land 3-4 SEPARATE ticks per target across the whole pierced row (25-32
typical, one 62 crit spike); cadence roughly 1 burst/second.
Motion: a heavier laser that pours a rapid multi-tick beam through the whole
row at once — each body racks up several numbers per burst rather than one
clean hit.
Deepwood: multi-tick pierce beam rifle — each pull channels a short rapid
burst landing several ticks per target across the pierced line; the upgrade
rung above Space Gun's single clean bolt (same pierce-everyone identity, now a
burst).

---

## MAGIC — UTILITY / SWARM / CHAIN

### Wand of Sparking (492x150, 199f @40ms, 7.96s)
Measured: a spark can strike targets at very different ranges within the same
demo (a far dummy and near dummies both shown taking hits: 15, 16, 12, 28),
each hit followed by a tiny "1" ember tick.
Motion: an unassuming spark wand — works at both point-blank and long range,
modest single-target damage with a minor ignite tag-along ember.
Deepwood: baseline spark wand — single spark shot, modest hit + tiny burn
tick; the tutorial-tier magic weapon before elemental staves specialize.

### Thunder Zapper (371x160, 65f @49ms, 3.17s)
Measured: bolt hits the nearest enemy for a flurry of small ticks (6, 6, 8);
once that target is defeated, the SAME charge visibly arcs onward via a curved
dotted trail to a second target further away (10 damage) — a genuine chain-
on-kill jump.
Motion: a bolt zaps the nearest body for a quick flurry, then on its death the
charge arcs onward in a curved dotted trail to jump onto the next enemy down
the line.
Deepwood: chain-lightning wand — kills propagate the bolt automatically to the
next nearest enemy in a visible dotted arc; great crowd-thinning identity.

### Leaf Blower (445x166, 116f @33ms, 3.78s)
Measured: each pull releases 2-3 independent leaf projectiles that drift at
their own pace across the gap and land as a ragged cluster of hits (44-52
each, one crit to 88) rather than one clean number; volleys roughly ~900ms-1s
apart.
Motion: a garden leaf-blower puffing out several slow independent leaves per
pull that thump the target in a staggered little flurry.
Deepwood: multi-leaf puff caster — each cast releases several slow independent
leaf projectiles landing as a staggered cluster of hits; comedic garden-tool
flavor for an early support/utility mage.

### Wasp Gun (580x230, 195f @33ms, 6.5s)
Measured: releases a swarm of tiny wasps that scatter and roam across the
ENTIRE wide arena rather than flying straight — near zombies get stung first
(10-22 range) then, several seconds later, the swarm is shown stinging
statues clear on the opposite side of the map (20-23); one bigger 40 hit
observed mid-swarm.
Motion: freeing the trigger releases a little swarm that doesn't fly straight
— it drifts and hunts across the whole room, stinging whatever it encounters
near AND far over several seconds.
Deepwood: roaming wasp swarm — cast frees several independent homing wasps
that scatter over the whole arena and sting anything in their path over
several seconds; the ultimate "set it loose and let it hunt" summon-flavored
gun.

### Spectre Staff (894x449, 267f @20ms, 5.34s)
Measured: a drifting skull-shaped bolt crosses a very wide room (894px, far
wider than most demo canvases) tagging bodies along its unhurried flight (63,
70, 57, 72, 74, 66 seen on a near cluster) before finally striking the
farthest target for a clean hit (42-48) and puffing into smoke.
Motion: a ghostly skull drifts the entire length of a long room, tagging
bodies as it goes before finally striking home — slow, unhurried, built for
long rooms.
Deepwood: long-range drifting skull bolt with lifesteal — fires a slow
spectral skull the FULL length of the room, damaging anything along its path
(pairs in the real game with life-drain healing back to the caster); the
go-to sustain wand for outlasting rather than out-bursting a fight.

---

## FAILED
- Killing Deck: no demo GIF exists on any of the 3 accessible sources tried —
  (1) terraria.fandom.com mirror page is a bare `{{stub}}` with only the item
  icon (`File:Killing Deck.png`), no `(demo).gif`; (2) Wayback Machine has a
  2026-07-25 HTML snapshot of the wiki.gg page referencing
  `Killing_Deck_(demo).gif`, but the image itself was never separately
  archived (CDX lookup returns zero image captures, both full-size and thumb
  paths 404 from web.archive.org); (3) direct wiki.gg image host still
  Cloudflare-blocks scripted clients (403). This is a 1.4.5 item (per the
  Fandom stub's `[[Category:1.4.5 items]]`), consistent with no gameplay
  footage existing anywhere yet. Verb stays text-only per
  WEAPON_VERB_REFERENCE.md (sticks cards, recalls through walls at 150%).

## COVERAGE NOTE
Studied 43 weapons (28 ranged + 15 magic) / 43 demo GIFs pulled successfully.
Cross-checked against gif_ranged.md (46 weapons) and gif_magic.md (52 weapons)
before starting — Quad-Barrel Shotgun, Dart Rifle, Molotov Cocktail, Aqua
Scepter, Heat Ray, and Laser Machinegun were already covered there and
skipped here despite appearing in the assigned slice list. Combined with the
two prior files, 43 + 46 + 52 = 141 weapon-GIF studies now exist across the
three documents (Killing Deck the sole unstudied weapon, confirmed
unreachable rather than skipped).

## CROSS-CUTTING MEASUREMENTS (this slice)
- Even-pierce bolt family (Diamond/Frost/Space Gun/Unholy Trident): one shot
  threads 2-3 stacked/lined targets for equal or near-equal damage each —
  distinct from Ruby Staff's stepped falloff pierce.
- DoT persistence measured: Elf Melter burn 5+s after release, Venom Staff
  poison still active at the full 6s demo, Poison Staff DoT going at 4.6s,
  Molten Fury burn 4+s, Flower of Fire/Frost burn/chill 2-3s decaying tail.
  Long DoT tails are a recurring magic-family signature in this slice.
- Roam/chain mechanics: Wasp Gun swarm crosses the ENTIRE arena over several
  seconds; Thunder Zapper explicitly chains bolt-to-next-enemy on kill;
  Spectre Staff's skull drifts the FULL room length before landing.
- Joke/utility-tier non-weapons: Water Gun (zero visible damage numbers),
  Paper Airplanes (flat "1" per hit, boomerangs back), Slime Gun (no clear
  damage, just a lingering slime-coat visual) — a consistent "intentional
  non-weapon" design lane worth keeping distinct from real damage options.
- Multi-projectile-per-cast clusters: Candy Corn Rifle (up to 5 bodies tagged
  from one bounce-shot), Paintball Gun (5-6 tiny pellets per pull), Leaf
  Blower (2-3 independent drifting leaves per pull) — all render as a ragged
  burst of several small numbers rather than one clean hit.
