# GIF MOTION STUDY — MELEE SWORDS (Terraria wiki demo GIFs, frame-surgery)
Slice: ~40 verb-bearing swords. Method: official demo GIF per weapon, 8 keyframes
(3 spread + 5-consecutive mid-run) extracted at nearest-neighbor scale, measured
with the PLAYER SPRITE HEIGHT (~48px native, "P") as the unit. Delays from GIF
metadata (mode/avg per frame). Measurements + motion descriptions ONLY — no pixels
copied. Deepwood note = one-line adaptation hook.

<!-- RECIPES -->

## STARFURY
- GIF: 472x542, 617 frames @ 20ms (13.0s). Player ~0.9P blade, swung arc small.
- Measured: star heads ~0.25P (larger "comet" variant ~0.4P with flame tail ~0.6-0.8P);
  sparkle trail behind each star short, ~0.7-1.3P (much shorter than Star Wrath's 3-4P);
  stars enter STEEP-diagonally (~60-70 deg) from screen top, 1 star per swing; fall is
  fast — crosses ~5P of screen in roughly 0.3s (~15P/s). Impact = compact yellow/pink
  sparkle burst (~0.6P wide), no lingering field.
- Motion: The sword swing itself is small and unremarkable (arc ~1.1P); the show is
  overhead. Each swing summons one star that streaks in on a steep diagonal aimed at
  the cursor point, leaving a thin sparkle wake. It bursts into a short sparkle pop on
  the target and vanishes — punchy, not lingering. Reads as "artillery ping", the
  single-star little brother of Star Wrath's cascade.
- Deepwood: early-tier "sky ping" sword — 1 small amber comet per swing at cursor/foe,
  short wake, sparkle pop; save cascades + lingering fields for the Star Wrath tier.

## SEEDLER
- GIF: 492x175, 144 frames @ 20-30ms (3.6s).
- Measured: green blade ~1.2P; nut projectile ~0.2P flying flat-ish with slight drop,
  ~0.3P/frame (~13-15P/s); nut detonation = white smoke puff ~0.8P + yellow sparks;
  burst releases a spray of TINY (~0.1P) red-pink seeds visible as a dotted line ~2P
  long fanning from the impact; seeds then curve toward targets (homing).
- Motion: Swing lobs one chunky nut that flies mostly flat with a slight arc. On
  contact it pops in a smoke puff and shotguns a handful of tiny glinting seeds that
  scatter, then bend toward nearby enemies. Two damage beats per swing: nut slap, then
  seed pepper. The seeds being near-invisible specks with glints is what sells it.
- Deepwood: cluster-verb sword — lobbed pod, pop, 4-6 pin-head homing seeds with glint
  sparkles; great forest/greenwood tier identity.

## THE HORSEMAN'S BLADE
- GIF: 300x300, 436 frames @ 20ms (8.9s).
- Measured: swing aura is a HUGE flaming crescent ~5.5-6P across (nearly fills the
  300px frame), sweeping over the player's head front-to-down in ~5-6 frames
  (~100-120ms); repeat swings near-continuous (autoswing). Pumpkin head projectile
  ~0.35P with a fire trail ~0.8P, diving diagonally from off-screen at ~0.4P/frame.
- Motion: Every swing paints a giant pumpkin-orange crescent that hangs as a smear for
  a few frames after the blade passes — the afterimage is most of the visual mass. On
  hit, flaming pumpkin heads dive in from outside the frame on steep diagonals,
  trailing fire, curving to retarget other enemies. Kill payouts (coins) land amid the
  dives, so the screen reads swing-smear + meteor-like heads at once.
- Deepwood: on-hit summoner sword — oversized lingering crescent smear + off-screen
  diving heads that retarget; cap dives/sec, heads phase through terrain.

## BRAND OF THE INFERNO
- GIF: 330x280, 356 frames @ 20ms (7.3s).
- Measured: blade ~1.5-1.6P long (huge, mottled fire/purple), held in a raised guard
  pose between swings; ignited targets burn with a flame column ~1P tall persisting
  the whole mid-run (5s+ of continuous burn frames); hit numbers ramp (5→35→78→100).
- Motion: Slow, weighty single swings from a raised two-hand guard; the blade itself
  is the spectacle (longer than the player). Struck targets IGNITE and keep burning
  visibly for seconds — the demo's midsection is just victims wreathed in flame while
  the player stands ready. The raised static guard pose doubles as the parry stance
  (right-click Striking Moment) — defense visibly readable as a held pose.
- Deepwood: parry sword — held guard pose sprite state; successful block flashes,
  reflects, and buffs next swing; every hit applies a long visible burn column.

## PSYCHO KNIFE
- GIF: 205x160, 179 frames @ 20-30ms (5.6s).
- Measured: knife blade only ~0.55P (smallest weapon in the slice); during stealth the
  PLAYER SPRITE IS FULLY INVISIBLE — only the bloody knife floats faintly, tilting as
  the unseen player walks (~4 distinct knife angles across the mid-run); stealth
  approach lasts seconds; the opener burst prints a cluster of big numbers (82-96)
  vs the small normal hits.
- Motion: The whole show is absence: stand still, fade out completely, and creep — a
  lone knife glinting midair is the only tell. First strike from stealth re-materializes
  the player mid-stab with a fat multi-number crit burst. Then it is just a fast
  short-reach dagger until stealth is rebuilt. Readability comes from the floating
  knife, not from any projectile.
- Deepwood: stealth-opener dagger — stand-still fade (keep a faint weapon glint as the
  honest tell), first-hit +300%/crit window, breaks on attack; pure state-machine, no
  projectiles needed.

## BEE KEEPER
- GIF: 371x200, 316 frames @ 20ms (6.5s).
- Measured: amber/blue blade ~1.2P; released bees are TINY ~0.08-0.1P golden specks,
  6-10 visible at once, jittering in a loose ~1P cloud around the struck target;
  bee ticks print small 5-6s continuously while swing hits print 28-52.
- Motion: Ordinary-looking swing, but every hit shakes loose a handful of bee-specks
  that swarm the victim in a Brownian cloud, each landing chip damage on its own
  cadence. The bees hug the target rather than travel — the cloud IS the effect, and
  it persists after the player stops swinging. Two number streams (big swing + tiny
  bee ticks) sell the weapon instantly.
- Deepwood: on-hit swarm sword — spawn 2-3 jitter-particles per hit that orbit-chase
  the victim ~2s dealing chip ticks; cap the cloud, reuse for wasp/spirit reskins.

## LIGHT'S BANE
- GIF: 244x244, 96 frames @ 30ms (2.9s).
- Measured: demon blade ~1.05P; each swing leaves a DARK VIOLET SMEAR at/beyond the
  blade tip — smear ~2P long, ~0.5P wide, extending effective reach to ~2.2P; the
  afterimage hangs ~4-6 frames (~150ms) after the blade passes; swing repeat ~0.3s.
- Motion: A short demonic sword whose swing paints a lingering shadow-slash past its
  own tip — the smear is offset INTO the enemy space, so the visual reach is nearly
  double the steel. The smear fades in place (no travel), a purple bruise stamped on
  the air along the arc. Small damage numbers, fast rhythm; the identity is the
  reach-extending shadow stamp.
- Deepwood: shadow-stamp sword — swing spawns a static tip-hitbox smear (fade 0.15s)
  extending reach ~2x; crits double per its micro-verb; cheap: one Polygon2D + tween.

## MURAMASA
- GIF: 331x200, 235 frames @ 20ms (4.8s).
- Measured: blue katana; swing crescent trail broad + smooth, ~1.4-1.6P across;
  8-12 blue sparkle motes shed per swing, drifting down ~0.4-0.5s; very fast autoswing
  (3+ damage numbers stacked at once: 22-27s); no traveling projectile in the demo.
- Motion: A speed-identity katana: wide glossy blue arc after arc with barely a pause,
  each swing shedding a fall of blue glitter that outlives the arc. The crescent reads
  bigger than the blade, and consecutive swings overlap so the air stays painted.
  Impact is just numbers + sparkle scatter — the weapon's verb is cadence itself
  (plus its occasional phantom echo slash on hit, per the wiki mechanics).
- Deepwood: speed katana — highest swing rate in tier, overlapping crescent trails +
  glitter residue; give its fusion micro-verb as a 1-in-N phantom echo arc on hit.

## BLOOD BUTCHERER
- GIF: 300x303, 629 frames @ 20ms (12.6s).
- Measured: jagged crimson blade ~1.2P; every swing flings an arc of blood droplets
  (~0.05P each, dozens) spanning ~3-4P that fall with gravity ~0.15P/frame; bleeding
  target streams its own droplet trail; DoT prints steady 20-22 ticks for seconds
  after swings stop (stacking embeds); victim HP bar visibly grinds down between hits.
- Motion: Wet and heavy — each overhead chop throws a rooster-tail of blood that rains
  to the ground, and stuck targets keep bleeding streams of droplets on their own.
  The DoT is legible as a metronome of same-sized numbers continuing between swings.
  With stacks built, the passive tick output rivals the swing damage. Gore particles
  doing the storytelling, zero glow.
- Deepwood: stacking-embed DoT sword — up to 5 visible barbs stick in the target, each
  adding a tick stream + droplet emitter; droplet arcs on every swing for weight.

## BLADE OF GRASS
- GIF: 413x300, 591 frames @ 20ms (12.0s).
- Measured: mossy blade ~1.4P; swing sheds green leaf-flecks along a ~2P arc; a small
  green leaf-glyph projectile ~0.3P appears ~2P out; afterward EVERY touched dummy
  ticks tiny poison numbers (1/8/11) in rising columns for 4+ seconds — at f293-472
  (3.5s apart) the whole field is still ticking with no further swings.
- Motion: The swing is a green smear that molts leaves, and it plants a slow venom
  rather than big hits. The signature image is the aftermath: five targets quietly
  dripping tiny numbers simultaneously long after the player stops moving. Damage-
  over-time as a field state, not an effect on one enemy. Leaf glint projectile is
  subtle and short-range.
- Deepwood: venom field sword — weak direct hit, long (4-6s) poison on everything the
  arc grazes; sell it with leaf-fleck swing particles + rising tick columns.

## VOLCANO (Fiery Greatsword)
- GIF: 300x302, 442 frames @ 20ms (8.9s).
- Measured: blade ~1.5P with a constant flame aura ~0.3P beyond the steel; first hit
  per swing triggers an ERUPTION: white-hot core ~1P, spark shower radius ~2-2.5P,
  debris chunks arcing out; burn columns ~1P tall persist on victims for seconds;
  ember motes rain and drift across the whole frame continuously.
- Motion: The sword is on fire at rest — even idle it smokes and sheds embers. Each
  swing's first contact detonates a localized explosion that blooms over 3-4 frames
  (core flash → spark fan → smoke), peppering neighbors. Struck targets stay wreathed
  in their own flame columns, so a working session turns the screen into a bonfire.
  Numbers: solid mid hits (29-41) plus burn 1s everywhere.
- Deepwood: eruption greatsword — once-per-swing on-first-contact AoE burst + standing
  burn columns; screen-space ember rain while drawn = the "carrying a furnace" feel.

## NIGHT'S EDGE
- GIF: 660x342, 390 frames @ 20ms (8.7s).
- Measured: swing paints a DARK VIOLET DISC ~3-3.5P diameter centered just ahead of
  the player (semi-transparent body + brighter crescent rim), persisting the whole
  swing (~5-6 frames); white 4-point glint ~0.6P stamps each struck target; 5-6 damage
  numbers (38-57) print simultaneously across the dummy cluster per swing; fast
  autoswing keeps the disc up nearly continuously.
- Motion: Not a slash but an ECLIPSE — a huge round shadow blooms around the player
  and everything inside it takes a hit at once. The disc's crescent rim gives it a
  moon identity; the interior swallows lighting. No projectile, no travel: pure
  oversized aura with multi-hit. Impact glints are pure white for contrast against
  the violet.
- Deepwood: eclipse aura sword — swing = one big disc hitbox (multi-hit cap), violet
  body + bright rim, white glints; the "aura sword" rung of the fusion ladder.

## TRUE NIGHT'S EDGE
- GIF: 684x378, 447 frames @ 20ms (9.6s).
- Measured: aura grown to ~4P — violet crescent swirl with green tinge + orbiting
  sparkles; the crescent DETACHES as a projectile: a full-size copy gliding forward,
  seen sitting over three dummies ~6P away printing 7 numbers at once (30-83);
  sparkle residue everywhere; autoswing cadence unchanged from base.
- Motion: Same eclipse, two upgrades: bigger, and it LEAVES. Each swing's disc slides
  off the blade and sails ahead as a slow drifting moon that keeps grinding whatever
  it overlaps, while the next swing is already painting a new one at the player. Two
  discs alive at once (one held, one traveling) is the tier jump made visible.
  Glitter field persists along the traveled path.
- Deepwood: the "beam sword" rung — aura disc + detached traveling copy at ~40% speed
  of an arrow, infinite pierce w/ decay; cap 1-2 live discs.

## EXCALIBUR
- GIF: 350x369, 172 frames @ 20ms (3.6s).
- Measured: GOLD crescent aura ~3-3.5P per swing; blade-contact flare = 4-point white-
  gold star ~0.8-1P; one strike showed a vertical light shaft ~0.4P wide x ~2P tall on
  the victim; gold sparkle fall persists ~0.5s after each arc; 6-7 numbers (62-88)
  per swing across the cluster; near-continuous autoswing.
- Motion: The holy twin of Night's Edge: same oversized crescent verb, but radiant —
  brighter rim, golden glitter rain, and starburst flares stamped on every contact.
  Reads triumphant rather than ominous purely through palette + additive glow.
  Multi-target numbers land in unison, and back-to-back swings keep a permanent
  gold shimmer in the air.
- Deepwood: radiant aura sword — reuse the eclipse disc rig, gold/additive palette,
  starburst contact flares; light-pillar flare on crits for the holy accent.

## TRUE EXCALIBUR
- GIF: 483x356, 259 frames @ 20ms (5.6s).
- Measured: LAYERED double crescent — magenta/pink outer arc over a gold inner arc,
  composite ~5P wide (largest aura in this study); arcs persist and fade over ~5+
  frames; starburst impacts ~0.8P; 12+ simultaneous numbers in the mid-run; crits
  ~2x visible (148/126 vs 64-81 normals); dense white sparkle rain throughout.
- Motion: Excalibur's crescent gains a second skin: every swing is a two-tone rainbow
  of pink over gold, and the pink layer PEELS OFF and travels as the "true" slash
  while the gold half stays with the blade. Old arcs linger as fading ghosts while
  new ones spawn, so 2-3 crescent layers overlap at any moment. The screen reads as
  continuous aurora with starbursts punching through it.
- Deepwood: two-layer verb — aura arc + detaching tinted twin per swing; layer-lag
  (aura fades slower than the traveling copy spawns) is what makes it feel royal.

## TERRA BLADE
- GIF: 1069x337 (widest demo — long-range showcase), 325 frames @ 20ms (7.1s).
- Measured: swing smear ~2P; signature slash = GREEN CRESCENT ~1.5P tall x ~0.5P
  thick with a white-green sparkle wake ~2P long; travels FLAT and FAST, ~1-1.2P per
  frame (~50-60P/s), crossing the full 22P-wide frame; fired EVERY swing; a 15-dummy
  crowd shows cascading numbers as one beam pierces everything (45/22/11/6/2... with
  pierce-decay), plus 120/126 crits near the muzzle.
- Motion: The reference standard: modest green swing plus a screen-crossing crescent
  every single swing. The crescent stays blade-shaped (not a ball), keeps constant
  speed, sheds glitter, and mows through an entire crowd with visibly shrinking
  numbers the deeper it goes. Autoswing keeps 2-3 beams alive across a long room.
  Nothing homes; the joy is the straight unbroken lawn-mower line.
- Deepwood: already built as the Terra standard (wpn_worldslash) — these numbers
  confirm: ~1P crescent, ~1P/frame speed, every-swing fire, 25% pierce decay.

## BEAM SWORD
- GIF: 444x300, 234 frames @ 30-40ms (8.2s).
- Measured: silver blade ~1.3P; projectile is a GOLD SWORD-SHAPED bolt ~0.8P long
  flying point-first, speed ~1-1.5P/frame (fast, flat), thin gold spark wake;
  consecutive frames show it at 2.5P → 3.5P → 5P from the player; hits 50-60,
  crit 108; up-swings release it along the aim direction; steady but unhurried
  swing rhythm (30-40ms frames, ~0.5s/swing feel).
- Motion: Every swing throws a golden phantom of the sword itself — a blade-shaped
  bolt that keeps the weapon's silhouette while the real steel stays in hand. It
  flies dead straight with a modest glitter tail and no arc, and the sword-shape
  makes it read as "the weapon leaving" rather than generic energy. Clean, elegant,
  single-target-per-flight (dies on first hit at this tier).
- Deepwood: the honest beam-sword rung — projectile IS the weapon sprite tinted
  gold/ghostly; one per swing, fast flat flight, no pierce below T6.

## FROSTBRAND
- GIF: 500x230, 409 frames @ 20ms (8.2s).
- Measured: icy blade ~1.2P with frost smear; the frostbolt detonates into an ICE
  CRYSTAL CLOUD engulfing each struck target (~1P per dummy, overlapping into a ~3P
  frost bank across a cluster); cloud shimmer persists 2+ seconds (visible across
  5 consecutive frames AND a frame 2.4s later); frostburn ticks print steady 10s
  under the big hits (43-104).
- Motion: The cold cousin of the beam swords: its bolt matters less than the AFTERMATH
  — struck enemies disappear inside sparkling frost banks that keep shimmering and
  ticking long after the swing. Multiple coated enemies merge into one glittering
  drift. The bolt itself is metered (not every swing), giving a cast-reload rhythm.
- Deepwood: frost-bank sword — metered bolt that wraps victims in a persistent
  crystal-particle shroud with slow ticks + slow debuff; the shroud IS the identity.

## ICE BLADE
- GIF: 400x171, 173 frames @ 20ms (3.8s).
- Measured: pale blade ~1.1P; bolt is a small cyan shard ~0.3P trailing a string of
  5-6 star-twinkles (~0.15P each) over ~1.5P; flight ~0.5P/frame (medium); chip
  numbers 14-19; twinkle residue drifts around struck targets for ~0.5s; relaxed
  swing rhythm with the bolt on a visible cooldown cadence.
- Motion: The starter bolt-sword: a modest swing flicks a glinting ice sliver whose
  trail is a dotted line of twinkles rather than a solid streak. Everything about it
  is small — shard, numbers, residue — but the dotted-twinkle wake makes even this
  early weapon feel enchanted. Cooldown between bolts gives it a "reload chime"
  rhythm rather than a stream.
- Deepwood: tier-2 bolt sword — tiny shard + dotted twinkle wake, metered fire;
  the baby rung of the bolt-sword ladder (Ice Blade → Frostbrand → Beam Sword).

## ENCHANTED SWORD
- GIF: 400x171, 276 frames @ 20ms (5.5s).
- Measured: cyan sword-shaped bolt ~0.6P, ~1P/frame flat flight; the trail is the
  star: MULTICOLOR CONFETTI TWINKLES (pink/cyan/yellow dots ~0.05P) strung along the
  entire flight path (~9P player-to-target), persisting and twinkling for 1+ second
  after the bolt is gone (visible across 5 consecutive frames + 1.6s later); chip
  numbers 21-26.
- Motion: Fires a modest sword-phantom whose passage paints a rainbow dotted line
  across the room that OUTLIVES the projectile — the air remembers the shot. New
  swings re-draw the line before the old one fades, keeping a permanent glitter
  corridor between player and target. Damage is small; the identity is 100% the
  lingering confetti wake.
- Deepwood: relic-tier starter beam — bolt + persistent multicolor twinkle corridor
  (1s fade Line2D of star sprites); pure charm, cheap to build.

## STARLIGHT
- GIF: 300x181, 186 frames @ 20ms (3.7s).
- Measured: hold-to-shred flurry: magenta/violet/blue LENS-FLARE RAYS crisscrossing a
  ~6-7P swath ahead of the player, covering 4 dummies at once; hit rate extreme —
  roughly 100+ damage numbers over ~1.7s (~15 hits/s spread over the row), numbers
  60-91 with 142-184 crits; afterward the number wall itself IS the visual (fills
  the upper half-frame); twin-blade weapon sprite barely readable in the blur.
- Motion: Not a swing — a held light-blender. Radial pink flare streaks strobe across
  everything in reach so fast that individual attacks are unreadable; what the eye
  gets is a shimmering ray-field plus an avalanche of overlapping numbers. When the
  trigger releases, the field vanishes instantly — no residue. The damage-number
  cascade is deliberately part of the spectacle.
- Deepwood: held-beam melee ("light drill") — while held, strobe additive rays in a
  cone, tick every 0.07s with tiny i-frames; numbers themselves sell the DPS.

## FLYING DRAGON
- GIF: 500x280, 307 frames @ 20ms (6.2s).
- Measured: ornate glaive ~1.5P; every swing launches a PINK CRESCENT WAVE ~2P tall,
  ~0.7P thick, concave-forward, with 3-4 ghost after-images smearing ~1.5P behind;
  speed ~0.5-0.7P/frame (slower than Terra beam, reads stately); pierces everything
  (6+ numbers per pass: 155-205 + crits 320/414); exits the frame ~10P out still
  alive; pink sparkle burst on each body it crosses.
- Motion: A slow royal wall of a projectile: the crescent is taller than the player,
  glides rather than zips, and its ghost-trail makes it look like it is dragging
  copies of itself. It plows through a whole row of dummies AND a platform target
  without stopping, sparkling at each pass. Fewer, heavier, statelier — the
  anti-Terra-Blade cadence.
- Deepwood: wall-crescent sword — big slow through-everything wave with after-image
  ghosts; long cooldown feel per shot, damage loaded into pierce hits.

## KEYBRAND
- GIF: 1013x503, 598 frames @ 30-40ms (21.8s — longest demo, two verbs shown).
- Measured: key-sword ~1.3P; melee sweep stamps GOLD RING outlines (~0.8P circles,
  the key-ring motif) on 5 contact points along a row; damage RISES vs wounded
  targets (92-113 opener → 228 crit on hurt dummies — the near-dead 2x); THROW mode:
  the key leaves the hand tumbling end-over-end ~0.7P/frame, covering 15+P
  downrange, finally bursting on a distant enemy (116/170 + sparkles).
- Motion: Two-verb weapon. In hand it is a row-sweeper whose every contact is stamped
  with a golden key-ring flare — 5 rings in a line per swing. Released mid-swing it
  becomes a thrown tumbling key that spins across the whole arena, lands its payload
  at extreme range, and (per mechanics) embeds as a ground trap until recalled.
  Execute scaling (bigger numbers on hurt targets) is visible in the demo's numbers.
- Deepwood: finisher key — damage scales with missing HP + throw-release alt verb
  (tumbling sprite, embed as trap, recall damages on return path).

## PHASEBLADE (Blue)
- GIF: 987x469, 360 frames @ 40ms (13.7s).
- Measured: energy blade ~1.2P, flat glow, no swing trail; THROW verb: the saber
  plants itself VERTICALLY point-down at the aim point and stays there GLOWING for
  5-8 seconds (visible planted across frames 8s apart), sparkles at the embed point;
  enemies touching it take chip ticks (14-17); melee numbers 23-36.
- Motion: In hand it is a clean neon bar with zero particle fuss — the glow IS the
  effect. Released mid-swing it flies off and STANDS in the world as a planted light-
  trap, quietly humming with sparkles while the player fights elsewhere; an imp
  wandering into it just ticks damage. One weapon, one held glow, one standing glow.
- Deepwood: plantable light-saber — throw sticks a vertical glowing blade trap
  (long lifetime, weak ticks), recall on demand; recolor family by ore/gem.

## PHASESABER (Blue)
- GIF: 915x296, 741 frames @ 20ms (15.1s).
- Measured: upgraded saber ~1.4P; same plant-trap verb but louder: embed point emits
  a CONTINUOUS white sparkle fountain (~0.5P plume) the whole time it is planted
  (4+ s); trap ticks ~25 (vs 14-17 on Phaseblade); melee sweep numbers 46-81 across
  a 5-dummy row; a unicorn walking onto the planted blade bleeds steady 25/27 ticks.
- Motion: The Phaseblade's verb matured: bigger bar, harder sweeps, and the planted
  blade now advertises itself — a standing saber with a permanent spark fountain that
  functions as area denial. The demo's money shot is passive: the player stands idle
  while a charging enemy impales itself on the parked blade. Trap-as-turret clarity.
- Deepwood: tier-up of the plant verb — brighter fountain, stronger ticks; the
  upgrade is legible purely through the trap's particle budget.

## BREAKER BLADE
- GIF: 389x290, 559 frames @ 20ms (11.4s).
- Measured: serrated slab ~1.9P long x ~0.35P wide — the longest plain steel in this
  study; level sweeps carve through 3+ targets at once; FRESH targets take 163-189
  while worn ones take 55-63 (the 250%-vs-full-HP opener made visible in numbers);
  slow deliberate cadence; kills end in a white dust-puff burst ~0.8P.
- Motion: Pure mass. No projectiles, no glow — a bus-length saw of a sword whose
  identity is silhouette and the delta between its opener hit and its follow-ups.
  The wind-up poses (blade held high diagonal, then level skewer) read across the
  room. Demo garnish: fighting a mimic, debris and coins flying, targets erupting
  into smoke when the slab finishes them.
- Deepwood: opener greatsword — 2x-class bonus vs full-HP foes, huge sprite, slow
  swing, dust-burst kills; pairs as the swap-partner of the Keybrand finisher.

## CHLOROPHYTE SABER
- GIF: 339x178, 241 frames @ 20ms (5.9s).
- Measured: techno-leaf saber ~1.3P, fast autoswing; every swing exhales a LIME SPORE
  CLOUD ~0.7-0.8P that settles ON the struck target and roils in place 1-2s, ticking
  ~10/s (steady 34-44 chip streams from two clouds at once); short effective range
  (~2-3P — the cloud spawns just past the tip).
- Motion: Swing, and the air around the victim turns to boiling green spores that
  keep biting after the blade is gone. Clouds do not travel — they cling where the
  cut landed, so juggling two enemies paints two simultaneous roiling colonies. The
  cloud persisting through 5 consecutive frames (and numbers continuing) is the
  weapon's whole pitch: melee that leaves gas behind.
- Deepwood: spore-cloud saber — per-swing stationary DoT cloud on the contact point
  (cap 2-3 clouds), ticks + slow; jungle/greenwood tier partner of the Claymore.

## CHLOROPHYTE CLAYMORE
- GIF: 450x282, 358 frames @ 20ms (7.2s).
- Measured: leafy claymore ~1.6P; every swing lobs a GLOWING GREEN ORB ~0.5P with a
  soft halo on an arcing trajectory, ~0.5P/frame; the orb sails far (seen 13P out
  still flying) and bursts in a ~0.6-0.8P green sparkle explosion on contact;
  numbers 89-109 with 168 crits; deliberate two-handed swing rhythm.
- Motion: The heavy sibling: instead of clinging gas it throws a slow luminous seed
  that arcs over the field like a mortar round, popping on whatever it lands on.
  The lob is readable and dodgeable — artillery-with-gravity as a melee rider.
  Saber = close sustained gas; Claymore = ranged single burst; one material, two
  clearly different verbs.
- Deepwood: orb-lobber greatsword — arcing glow-seed per swing with burst AoE;
  the lob arc (not straight flight) is the identity, tune ~45 deg launch.

## CHRISTMAS TREE SWORD
- GIF: 392x329, 151 frames @ 30-40ms (5.0s).
- Measured: tree-shaped blade ~1.3P; the fired star sheds ORNAMENT BAUBLES along its
  path — 10-12 live at once, each ~0.25P in festive colors (red/green/blue/orange)
  with a tiny sparkle; baubles HANG at their spawn height ~0.5-1s then fall slowly
  (~0.05-0.1P/frame); each bursts into a colored sparkle puff ~0.5P on contact or
  landing; numbers 79-99 + 150 crit.
- Motion: A projectile that drips projectiles: the star crosses the field leaving a
  drifting garland of hanging ornaments at staggered heights, and for the next
  second the whole area intermittently pops with color as they drop and burst one
  by one. The delay between shot and payoff spreads one input over ~2s of scattered
  detonations. The screen looks decorated, then explodes politely.
- Deepwood: garland sword (festival/relic tier) — main shot spawns hang-then-fall
  bomblets at 0.17s intervals; stagger fuse times so pops arrive as a drumroll.

## HAM BAT
- GIF: 200x241, 303 frames @ 20ms (6.1s).
- Measured: glazed ham ~1.1-1.2P; ZERO particles, trails, or glows in the entire
  demo — the only visuals are the swing arc and numbers (48-80); ordinary autoswing.
- Motion: The anti-spectacle: a giant ham swung with full sincerity and no effects
  whatsoever, hitting respectably hard. The comedy IS the absence — every other
  endgame sword glows, and the ham simply does not. Its real verb (damage scales
  with the food buff tier; kills feed regen) lives in the stat sheet, invisible
  here by design.
- Deepwood: cooking-scaled bludgeon — damage tier reads from the active meal buff,
  kills extend it; keep it 100% particle-free on purpose (village kitchen synergy).

## SLAP HAND
- GIF: 973x221, 628 frames @ 20ms (12.9s — wide frame to fit the launches).
- Measured: open palm ~0.8P; knockback LAUNCH 6-9P horizontal per slap (vs <1P for
  normal swords) — victims skid/fly across a third of the arena and land in a
  separated pair far from their pack; a killed skeleton flies apart ~3P UP with
  bone scatter; damage modest (52-92); relaxed cadence.
- Motion: The damage numbers are a footnote; the LAUNCH is the payload. Each slap
  picks enemies up and mails them across the room — the demo's composition (packs
  at left, lonely displaced zombies far right, dropped weapons in between) is
  entirely knockback storytelling. Kill hits turn into airborne ragdoll bursts.
- Deepwood: launcher joke-weapon — KB stat an order of magnitude up, victims get
  real velocity + tumble; pairs hilariously with hazards/pits (bounce off walls).

## BLADETONGUE
- GIF: 400x314, 232 frames @ 20ms (4.7s).
- Measured: fanged coral blade ~1.4P; on contact an ICHOR JET fires FROM THE STRUCK
  ENEMY — a golden liquid ribbon (bolt head ~0.3P + droplet trail) at ~1P/frame,
  arcing/sagging with gravity over a 5-6P range, splashing or striking a SECOND
  target (102 on the downstream dummy); jets visibly bend and ricochet off surfaces;
  numbers 33-62 direct, 102 on the jet's victim.
- Motion: Hit one enemy and the wound itself spits a golden stream at the next —
  damage that visibly CHAINS out of contact points as arcing liquid ropes across
  the room. The gravity sag and splash-on-miss make it read as fluid, not laser.
  Two-stage numbers (bite, then downstream splash) every swing.
- Deepwood: chain-spit sword — on-hit secondary bolt from the victim toward the
  nearest other foe, arcing ribbon w/ droplets + armor-shred debuff.

## DEATH SICKLE
- GIF: 450x268, 174 frames @ 20ms (3.7s).
- Measured: black scythe ~1.3P with glowing magenta edge; every swing launches a
  detached VIOLET CRESCENT ~0.8P (white-hot core, additive glow) at only ~0.3-0.4P
  per frame — a slow glide; the crescent passes THROUGH enemies (and terrain, per
  mechanics) grinding continuous number streams (55-66) as it overlaps them,
  staying alive ~1.5-3s; 2 crescents often airborne at once.
- Motion: The reaper cadence: swing, and a lazy spinning moon of violet light drifts
  downrange, mowing everything it slides through — slow enough to feel inevitable
  rather than ballistic. Numbers pour out of whatever it is currently inside.
  Overlapping crescents from autoswing fill corridors wall-to-wall.
- Deepwood: through-all glide crescent — slow, infinite-pierce, terrain-ignoring,
  re-hit every 0.15s while overlapping; THE corridor/undead-tier verb.

## ICE SICKLE
- GIF: 308x168, 97 frames @ 30-40ms (3.7s).
- Measured: icy scythe ~1.1P; launches a SPINNING CYAN CRESCENT ~0.6P at ~0.3-0.4P
  per frame (slow glide, orientation rotating frame-to-frame); pierces (number
  streams 33-57 as it overlaps targets); 2+ crescents alive at once from autoswing;
  frost sparkle residue on pass-through; 32-54 hits.
- Motion: The apprentice Death Sickle: same lazy gliding crescent verb, smaller,
  colder, and stopped by walls. The visible SPIN of the icy arc plus snow-mote
  residue distinguish it from a generic bolt, and the slow speed means the player
  outruns their own projectiles — swings layer crescents into a drifting picket.
- Deepwood: mid-tier glide crescent — the Death Sickle's rung-below: same code path,
  smaller size/tick rate, blocked by terrain; ice palette + spin.

## INFLUX WAVER
- GIF: 500x294, 261 frames @ 20ms (5.3s).
- Measured: techno blade ~1.3P; beam = a glowing cyan silhouette of the sword ~0.9P
  at ~1P/frame; ON HIT IT VANISHES AND TELEPORT-RE-STRIKES — sparkle trail shows two
  separated path segments with a clean gap, and single targets collect 5-number
  clusters (85-99) from one launch (up to 2 re-strikes, seeking nearby); melee crit
  190 point-blank.
- Motion: Fires a sword-ghost that hits, blinks out, and re-materializes already
  mid-strike on the same or a nearby target — the trail's visible GAP is the tell
  that it teleported rather than traveled. One input becomes a stutter of 2-3
  impacts around the aim area. Reads sci-fi purely through the blink.
- Deepwood: blink-beam sword — projectile re-strikes 2x on hit within a radius
  (teleport, no travel between), trail segments + reappear flash sell it.

## MEOWMERE
- GIF: 917x387, 221 frames @ 30-40ms (7.4s).
- Measured: projectile head tiny (~0.2P) but drags a FULL-SPECTRUM RAINBOW RIBBON
  ~0.25P thick that BOUNCES off floor and ceiling in a W-zigzag spanning 8+P with
  3+ bounces; dense white star-sparkle clouds (~1P) erupt at every bounce vertex
  and impact; ribbon persists ~0.5-1s fading; normals 192-285, crits 436-560; a
  ~3P sparkle RING blooms on big kills.
- Motion: The crown jester: each swing launches a small head whose rainbow wake
  ricochets around the room geometry, folding the space into a zigzag of color
  with starbursts stamped at every fold. The ribbon is the weapon — the head is
  almost invisible. Confirms the yardstick's 7-9P trail figure; bounces make
  enclosed arenas the best showcase.
- Deepwood: bounce-ribbon crown verb — reflecting projectile with a long RGB-cycling
  Line2D wake + vertex starbursts; cap 2 live ribbons, tune for corridors.

## ARKHALIS
- GIF: 300x319, 449 frames @ 20ms (9.0s).
- Measured: no discrete blade ever visible — a VIOLET SLASH RIBBON ~1.3-1.5P wraps
  the player's front and REDRAWS IN A NEW SHAPE EVERY FRAME (up-arc, over-arc,
  down-sweep: 12+ distinct shapes/sec); chip numbers 22-28 with 44-48 crits landing
  3-5 AT ONCE continuously; pure melee reach (~1.5P), zero projectiles.
- Motion: A held blender: while attacking, the weapon is an ever-reshaping ribbon of
  violet light that never repeats a silhouette two frames running. Damage arrives as
  a continuous drizzle of small numbers rather than discrete hits. The hidden-blade
  fantasy is entirely carried by particle choreography plus number density.
- Deepwood: hidden-flurry weapon — replace swing anim with per-frame random arc
  sprites from a 6-8 pose set + 12 ticks/s at short reach; i-frames as rate limit.

## TERRAGRIM
- GIF: 300x285, 308 frames @ 20ms (6.2s).
- Measured: Arkhalis' verb in mint-cyan at starter numbers: ~1.2P ribbons redrawn
  every frame, chip ticks 15-19, crits 30 (one 130 spike), number CLOUDS of a dozen+
  digits hovering over the melee zone; teal mote residue; same zero-projectile
  held-flurry pattern.
- Motion: Identical choreography to Arkhalis with a weaker paint job and weaker
  ticks — proof the flurry verb scales purely by number size and palette. The
  spectacle (shapeshifting ribbon + digit cloud) works even at tier-1 damage,
  making it a perfect early "secret rare" feel-weapon.
- Deepwood: the flurry verb's low rung — same rig as the Arkhalis cousin, mint
  palette, small ticks; secret-find rarity rather than power.

## TENTACLE SPIKE
- GIF: 250x260, 289 frames @ 20ms (6.0s).
- Measured: stubby tentacle-blade only ~0.6P (shortest reach in the slice); dark
  tendril fragments visibly STUCK ON the victim after stabs; tick stream 13-17
  printing every ~2 frames continuously while the victim's HP bar drains WITHOUT
  further swings; kill state reached almost entirely via ticks.
- Motion: A gross little stabber: jab, leave writhing black barbs in the wound, and
  watch the health bar melt on its own. The demo's drama is a bar draining while
  the player stands still — embedded DoT as the whole identity, damage numbers as
  a metronome. Blood Butcherer's cousin with reach traded for stack speed.
- Deepwood: embed-stack dagger — visible barb sprites stick (stack 5), each a tick
  emitter; short reach + fast stab as the balance lever.

## EXOTIC SCIMITAR
- GIF: 289x218, 431 frames @ 20ms (9.8s).
- Measured: thin elegant crescent blade ~1.2P; RAMP visible on film: early-demo swing
  cycle ~8+ frames, late-demo full cycle ~4 frames (~80ms ≈ 12 swings/s) once the
  frenzy is fed; numbers stay modest (18-28) — the ramp raises RATE not size;
  kill = red gib shower bursting sideways (48/47 finish).
- Motion: A duelist blade that accelerates as it feeds: the same swing animation
  simply plays faster and faster while hits land, until the blade is a near-blur
  cycling multiple sweeps a second. Stop hitting and it cools back down. All the
  power is in cadence; the visual story is acceleration, not size.
- Deepwood: frenzy scimitar — +12%/hit stacking attack speed (cap +50%), decays
  30%/s out of combat; sell it purely with anim-speed scaling + pitch-up whoosh.

## CLASSY CANE
- GIF: 230x194, 250 frames @ 30-40ms (8.3s).
- Measured: slim cane ~0.9P (black shaft, gold tip); every hit ejects GOLD GLINTS —
  1-3 coin sparkles (~0.1P) popping out of the victim and landing as pickups;
  numbers 24-44; gold mote rain around the target after sustained beating; no other
  effects.
- Motion: Percussion for profit: an ordinary-speed thwack whose victims leak actual
  currency — each contact knocks glinting coins loose that bounce to the floor and
  wait to be picked up. The aftermath frame (slumped victim, scattered gold, drifting
  sparkle motes) is a robbery scene. Weapon-as-economy-faucet, visualized.
- Deepwood: coin-knocker joke/economy weapon — hits drop 1-49 copper scaled by luck;
  ties straight into the Bank/greed loop; keep numbers mediocre on purpose.

## GLADIUS
- GIF: 195x196, 202 frames @ 20ms (4.4s).
- Measured: short blade ~0.9P; each click delivers 3-4 FANNED THRUSTS within ~100ms
  (consecutive frames show distinct lunge poses at level/up/down angles inside a
  ~30 deg fan); each stab lands its own number (13-17), clustering 4-6 digits per
  click; zero arc swings — pure straight-line lunges.
- Motion: A drumroll in sword form: one input, a rapid rat-tat-tat of angled stabs
  that read as separate lunge poses rather than a blur. The fan spread gives it a
  little vertical coverage despite the stubby reach. Small numbers arriving in
  bursts of four feel entirely different from one 60 — cadence as identity.
- Deepwood: multi-stab shortsword — 3-4 sequential thrust hitboxes per swing input,
  fanned +-15 deg; the "duelist" rung under the ramp scimitar family.

---
## CROSS-CUTTING MEASUREMENTS (the slice's laws)
- Player sprite = ~48px in native demo footage; all sizes above in P (player-heights).
- AURA LADDER measured: Night's Edge disc 3-3.5P → Excalibur 3-3.5P gold → True
  Night's Edge 4P + traveling copy → True Excalibur ~5P double-layer + traveling
  copy → Terra Blade drops the giant aura for the every-swing 22P-crossing beam.
  Auras persist 5-6 frames (~100-120ms) and multi-hit everything inside once.
- PROJECTILE SPEED BANDS: glide crescents 0.3-0.4P/frame (Death/Ice Sickle, the
  inevitability feel); stately waves 0.5-0.7P/frame (Flying Dragon, Chlorophyte orb);
  standard bolts ~1P/frame (Terra, Bladetongue ichor, Influx, Enchanted); fast bolts
  1-1.5P/frame (Beam Sword). Trails: 1.5P dotted (Ice Blade) → 2P sparkle (Terra) →
  full-path confetti (Enchanted) → 8P bouncing rainbow (Meowmere).
- CADENCE IDENTITIES: flurries tick 12-15/s (Arkhalis/Terragrim/Starlight/Gladius);
  frenzy ramps double swing rate (Exotic); heavies sell one swing per ~0.5-0.8s
  (Breaker, Volcano, Flying Dragon).
- AFTERMATH VERBS (damage that outlives the swing): poison field 4-6s (Blade of
  Grass), burn columns (Volcano/Brand), frost banks 2s+ (Frostbrand), spore clouds
  1-2s (Chloro Saber), embedded barbs (Blood Butcherer/Tentacle Spike), planted
  blade traps 5-8s (Phaseblade/saber), hanging ornaments ~2s (Christmas Tree).
- NUMBER THEATER: Terraria uses the damage numbers themselves as spectacle —
  flurry number-clouds, execute deltas (Keybrand 92→228, Breaker 189→63), pierce
  decay staircases (Terra crowd), DoT metronomes. Deepwood's floating numbers
  should be tuned as part of each verb's look, not an afterthought.
- NOT STUDIED (no GIF needed): stat-stick rungs; Star Wrath + Zenith already
  measured in WEAPON_VERB_REFERENCE.md.

STUDY COMPLETE: 42 weapons, 42 demo GIFs downloaded (100% success), ~13,000 frames
surveyed via 8-keyframe contact sheets (3 spread + 5 consecutive per weapon).
