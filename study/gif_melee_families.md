# GIF Motion Study — Melee Families (yoyos / flails / boomerangs / oddballs / spears)
2026-07-29. Method: official-wiki demo GIFs (Fandom mirror originals), 8 keyframes each
extracted via System.Drawing at native pixel scale, measured against a 48px grid.
UNITS: 1 PH = 1 player-height = 48px = 3 tiles. Speeds from keyframe displacement /
frame timestamps. Measurements only — no pixels copied. 42/43 studied; Flint (1.4.5-only)
has no obtainable demo GIF (wiki.gg blocks fetches, not on Fandom or Wayback) — skipped.

Shared family control schemes (confirmed on screen):
- YOYO: orb DWELLS at the aim point on a visible string, wanders/bounces ±0.5-1 PH
  around the target, hits ~5-8/s, returns on release. Particles = the identity.
- FLAIL: HOLD = orbit shredder at ~0.8-1 PH radius; TAP = launch out 4-6 PH on a chain
  that damages along its whole length, retract on impact. Launch cycle ~0.75-1.2s.
- BOOMERANG: outbound ~10-15 PH/s, hits on both passes, multi-throw stacking is the
  progression axis.

## YOYOS

### Terrarian
- Yoyo orb ~0.2 PH; demo dwell at cursor 2.2 PH out (real cap far higher); string drawn hand-to-orb.
- While spinning, fires green bolts every ~0.1s: 4-5 alive at once, teardrop trails ~2x bolt length, radiating in all directions and bouncing.
- Pattern: park the orb at the aim; the dwell-point itself becomes a bullet fountain; on release the orb returns but the launched bolts keep flying for ~0.5-1s.
- Deepwood: endgame yoyo whose parked dwell-point machine-guns bouncing motes at anything within a wide radius — a turret you steer.

### The Eye of Cthulhu (yoyo)
- Orb ~0.29 PH (white-red eye); throw reach 3.9 PH in demo; dwell ON a single target 2.6s+ continuously.
- Hit stream ~7-8/s (fastest of the family measured; 4-5 damage numbers per 0.6s window), orb bounces off the target ±0.4 PH and re-sticks.
- Pattern: pure single-target lawnmower; no particles, no status — the identity is raw contact rate.
- Deepwood: the "sticks to one enemy and saws" yoyo; highest hit cadence, no frills, boss-shredder niche.

### Hive-Five
- Orb ~0.25 PH; throw reach ~2.5 PH; dwell hold ~3s in demo; hits ~4-6/s (21-28 stream).
- On-hit chance spawns bees (small seeker motes) that harass nearby targets — starter-tier yoyo with a summon rider.
- Pattern: standard dwell-wander close to the player; the value-add rides along passively on hits.
- Deepwood: early yoyo that procs a tiny chasing sting-mote on ~1/3 of hits; teaches "on-hit rider" before the big yoyos.

### Cascade
- Orb ~0.33 PH fire-ring; dwell 2.2-3.2 PH (bounces off target, re-approaches); demo hold 5s+.
- Ignites targets: burn DoT ticks visibly ~1/s for 1s+ after release; crits ~2x (50-62 vs 23-30); light-source fire particles shed constantly.
- Pattern: dwell shredder + fire starter; flame column persists on the victim after the yoyo leaves.
- Deepwood: the burn-brand yoyo — every dwell paints a lingering ignite; doubles as a walking torch (light source while spinning).

### Kraken
- Orb ~0.33 PH dark disc; dwell ~3.3 PH; hits ~5/s (79-103).
- Fast wander: overshoots THROUGH the target with motion-blur smears 2-3x its size, then whips back — the most violent dwell movement measured.
- Pattern: no status, no particles; identity = wide erratic dwell orbit that clips things adjacent to the main target.
- Deepwood: the "wide thresh" yoyo — dwell hitbox effectively ~1 PH wide from overshoot passes, best vs packs around one anchor.

### Amarok
- Orb ~0.3 PH ice cube; dwell 1.7-3.3 PH wander; hits ~5/s (37-48) + frost "2" DoT ticks.
- Ice-crystal burst particles engulf the target (snowflake sparkles ~1 PH cloud); frost persists ~1s after release.
- Pattern: like Cascade but cold: on-most-hits frostbite, big readable freeze-sparkle feedback.
- Deepwood: the freeze-line yoyo — stacks chill/frostbite on nearly every hit; pairs with our freeze status.

### Hel-Fire
- Orb ~0.33 PH fireball; dwell 2.5-3.3 PH; hits ~5/s (36-48) + On Fire "1" ticks.
- Embers scatter and BOUNCE ON THE FLOOR under the dwell point — ground-level splash feedback Cascade lacks; long burn tail after release.
- Pattern: hardmode Cascade sibling; burn + floor-ember shower; also a light source.
- Deepwood: mid-tier fire yoyo whose dwell sheds bouncing embers that hit low crawlers under the orbit.

## FLAILS

### Flairon
- Head ~0.4 PH fish-jaw on a blue segmented chain; launch reach ~4.5 PH; retract-relaunch cycle ~1s.
- Sheds homing bubbles the WHOLE time it moves (~10 alive at once, each ~0.3 PH ring, life ~1.5-2s); bubbles drift then lock onto targets and pop on contact.
- Pattern: every swing/launch is productive even on a miss — the bubble swarm cleans up; measured bubbles chasing a crawler 3 PH below the swing line.
- Deepwood: the "misses still work" flail — constant seeker-mote shed while the head is in motion.

### Flower Pow
- Head ~0.5 PH flower on a chain of flower links; PLANTS at up to ~7.5 PH and stays parked 4s+ while held.
- Parked head = turret: fires petals at targets 2-3 PH beyond itself (measured damage on a dummy at ~9.5 PH); chain hits everything along its length (3 dummies at once: 146/133/113).
- Pattern: launch, park, hold — the flail becomes a deployed pylon; faster petal rate when planted on ground per the page scan.
- Deepwood: park-the-head flail; while planted it autofires; the chain is a persistent damage line back to you.

### Golem Fist
- Fist ~0.4 PH; launch is a rocket: ~9.5 PH covered in <0.42s = ~23 PH/s (fastest launch measured in the study).
- Throw-only (no orbit); punch-retract cycle ~0.8s; hits 138-180 with big knockback; modern version adds a through-wall shockwave on far impacts.
- Pattern: straight-line piston — point, delete, reload.
- Deepwood: the rocket-punch: longest, fastest single-hit launch flail; past mid-range every impact detonates a small quake.

### Anchor
- Head ~0.6 PH anchor; reach ~5-5.5 PH; cycle ~1.5-2s (heavy, slow).
- Pierces everything on the flight path (SIX dummies hit by one throw: 71/74/74/74/73/138); when thrown low it LIES ON THE GROUND with the chain slack until recalled — an area denial pose.
- Pattern: lob, drag, everything in the line pays; block-impact shockwave in the modern version.
- Deepwood: the lane-clearer flail — infinite pierce along the throw, can be left grounded as a brief barricade.

### Dao of Pow
- Ball ~0.33 PH yin-yang; held orbit = close shredder (hits both flanks); launch reach ~5.3 PH flat, cycle ~1s; chain path hits every target crossed (5 numbers in one throw).
- Confusion proc SEEN: struck unicorn gets "?!" icon and walks the wrong way for 2s+.
- Pattern: standard hold/launch flail whose identity is the mass-confuse roll (80% per the page scan).
- Deepwood: crowd-scrambler flail — launches through a pack and flips their AI direction; our confusion status hook.

### Sunfury
- Fire head ~0.4 PH; held spin radius ~0.8-1 PH igniting both flanks; launch ~4-4.3 PH with a comet tail streak that lies along the whole path.
- Every touched target ignites; burn "1" ticks measured 2.7s+ after the last swing; impact burst at max extension.
- Pattern: every launch paints a temporary line of fire; melee-range spin is a bonfire.
- Deepwood: the burn-line flail; pairs with Blue Moon as an INVENTORY-PAIR (each fires a mirrored ghost twin at 80% when the other is carried — from the page scan; not visible in these old demos).

### Blue Moon
- Spiked ball ~0.3 PH on a chain of blue star links; held spin hits flanks; launch ~4.5-5.3 PH, cycle ~1.2s.
- Blue starburst sparkle shower on every impact and at max extension; chain-path multi-hit confirmed (3 dummies: 54/62/49/31/29).
- Pattern: the pretty one — identity is the sparkle burst + pair synergy with Sunfury (see above).
- Deepwood: the twin-flail set piece: carrying both makes each throw mirror the other.

### KO Cannon
- NOT swung: a handheld cannon that FIRES a boxing glove ~0.3 PH on a rope; reach ~2.5-3 PH; ~2 shots/s at close range.
- Fire rate scales with proximity (closer target = faster reload, per scan); glove visibly droops mid-rope at extension.
- Pattern: launched-subtype flail as a ranged-feeling melee: aim, jab, jab.
- Deepwood: the piston-glove sidearm — melee weapon with gun handling; fire rate ramps as enemies close in.

### Chain Guillotines
- TWO blade heads on chains, launched alternately or both out at once; reach measured to ~7.3 PH (the longest launch reach of the flails studied); each throw ~0.8s.
- Full-diagonal freedom demonstrated (down, flat, up-right ~5.5-6.5 PH); numbers land along the chain line (4 hits per throw).
- Pattern: rapid alternating twin harpoons rather than one heavy ball.
- Deepwood: dual-head flail — two independent heads with offset timing, so something is always in flight.

### Drippler Crippler
- Held spin = ~1 PH orbit ball of red orbs shredding both flanks (~6 numbers/s); launch ~5.5 PH flat, cycle ~0.75s; the chain body is a string of ~12 orbs damaging along the line.
- On hits, blood droplets fly OFF as secondary projectiles — measured damage (53s) on elevated dummies ~7 PH up-right that the flail never touched.
- Pattern: grinder that leaks seeking droplets to off-line targets.
- Deepwood: the splatter-flail — every contact sprays 1-2 short-range homing droplets upward/outward.

## BOOMERANGS

### Light Disc
- Disc ~0.38 PH; THREE in flight at once measured (stack ceiling ~5-6); outbound ~11 PH/s; reach ~8.7 PH.
- Continuous cycling: as one returns the next launches; hits on both passes.
- Pattern: laser-frisbee juggling; the air is never empty.
- Deepwood: the multi-disc keeper — throw cap grows with tier; return pass pierces.

### Bananarang
- Banana ~0.25 PH; measured FIVE simultaneously (cap x10); reach past 10 PH with overshoot beyond the target before returning.
- Hits 44-63 stacking continuously from staggered returns.
- Pattern: spam-cloud boomerang — individual damage modest, saturation is the weapon.
- Deepwood: the swarm-rang: cheap per-hit, absurd uptime when all copies cycle.

### Possessed Hatchet
- Hatchet ~0.4 PH; ~10 PH/s; throw cycle ~0.7s.
- HOMING confirmed: curved up and around a wall lip to chase a slime on a platform the throw never aimed at; multi-curve pursuit until the kill, then returns.
- Pattern: fire-and-forget — it picks the enemy, not the aim line; sparkle trail marks its path.
- Deepwood: the seeker-axe: ignores aim once an enemy is in range; great "lazy clear" endgame rang.

### Paladin's Hammer
- Hammer ~0.5 PH; ≥12 PH/s (5 PH in ~0.4s); pierced FIVE dummies in one line pass (numbers on all simultaneously).
- Golden impact flash at each contact; near-zero cadence gap (1.47s demo loops one throw).
- Pattern: heavy line-driver — a freight train with a return trip.
- Deepwood: the wall-hammer: infinite pierce, block-impact burst, Broken-Armor-style debuff on crits.

### Sergeant United Shield
- Shield disc ~0.38 PH; RICOCHET: one throw chained between two separated enemies (bounce path visible mid-air, 5-hop cap per scan); ~0.4s to first chain.
- PARRY: holding the shield during a unicorn charge reflected the hit (enemy ends up behind the player, takes 53, player takes zero) — reflect+buff window ~0.3-0.5s.
- Pattern: two verbs in one item — pinball throw and a timed defensive stance that converts defense into a next-hit bonus.
- Deepwood: the parry-rang: our first defense-into-offense timing item; throw chains, hold to parry for a 1-hit reflect + damage surge.

### Flying Knife
- Knife ~0.4 PH, HELD in flight up to a minute; follows the cursor with drunken loops ~1-1.5 PH around the aim point.
- Measured weaving through a 7-dummy line: 10-15 damage numbers alive at once at ~4-6 hits/s across everything near the loop.
- Pattern: not a throw — a steered pet blade; release recalls it.
- Deepwood: the steered blade: hold to fly it like a cursor-familiar, loops damage everything it grazes.

### Thorn Chakram
- Ring ~0.45 PH; reach ~6 PH; throw-to-catch ~1.6s; sheds green thorn particles along the path.
- Poisons on hit (DoT "1" ticks measured 2.4s after catch); return pass hit a SECOND dummy the outbound missed.
- Pattern: early rang with a status rider and true two-pass value; corridor pinball per scan (bounces walls).
- Deepwood: the venom-ring starter: bounces off dungeon walls, poisons most hits — teaches return-pass aiming.

### Trimarang
- THREE boomerangs cycling simultaneously (all three airborne measured at once); ~12 PH/s; reach ~4.5 PH; a hit lands every ~0.4s sustained.
- Pattern: fused starter-rang teaching the multi-throw fantasy early; short reach, relentless cadence.
- Deepwood: the fusion-rang — literally our chain-fusion story (3 starters forged into one that throws all three).

## ODDBALLS

### Solar Eruption
- Segmented lash: visible extension to ~6 PH hugging any aim angle, sweep pass ~0.5s, continuous while held.
- EVERY pass spawned explosion bursts on all three dummies spread across ~9.5 PH — hit points erupt beyond the visible lash (AoE procs), plus stacking burn ticks ("25"s) for 1s+ after release.
- Through-wall per scan (33-tile ellipse); the demo shows the whip-like segmented body flattening along the ground and diagonals.
- Pattern: melee weapon with artillery coverage: sweep, everything in the lane detonates, DoT keeps ringing.
- Deepwood: the endgame lash — segmented through-wall sweep whose every contact explodes; our "room verb".

### Daybreak
- Solar javelin ~15 PH/s flat flight w/ ~2.5 PH flame streak; ~1 throw/0.5s.
- Spears STICK and tick (fire bursts on the stuck target), stack, then DETONATE: measured ~1.5 PH diameter ring blast when a stack pops; two simultaneous burn sites held at once; residual "25" ticks for seconds.
- Pattern: a visible debuff meter — spears sticking out of the boss ARE the UI; pop = payoff.
- Deepwood: the stake-stacker: embed up to N suns in a target, the N+1th detonates the oldest for AoE.

### Terragrim
- No visible blade: cyan crescent slash arcs flick around the player, radius ~0.8-1 PH, ~120° arcs re-aimed toward the cursor each swing.
- ~12 hits/s claimed; measured 3-6 fresh numbers per second on all three surrounding targets including one 1.5 PH above.
- Pattern: melee as a held shredder cone; i-frames are the real rate limiter.
- Deepwood: the hidden-blade flurry: hold to blur, arcs auto-track aim side, hits everything in a ~1 PH shell.

### Arkhalis
- Terragrim's big sibling: arc radius ~1.2 PH, taller coverage (hits 1.8 PH up), purple-blue arcs, 22-28 per hit with 44+ crits, same continuous flurry.
- Pattern: identical verb, bigger shell + damage — a clean upgrade rung on one identity.
- Deepwood: keep both as one family: flurry radius/damage grows by tier, visual arc color shifts.

### Vampire Knives
- Fan of 4-8 knives (~0.2 PH each) per throw, cone ~30-40°, ranges 3-5 PH, ~1 throw/0.6s.
- LIFE THREADS SEEN: bright red streak drawn from the wounded enemy back to the player (~3.5 PH long) with green +1/+2 heal ticks landing on the player synced to hits.
- Pattern: shotgun fan + visible vampirism — the heal is drawn in the world, not just a number.
- Deepwood: the leech-fan: every knife hit flies a red thread home and heals; visual = the fantasy, keep threads.

### Scourge of the Corruptor
- Javelin ~15 PH/s flat with a green ribbon trail spanning ~9 PH; impact splits into 2-3 eater larvae (~0.17 PH).
- Eaters home at ~6 PH/s with strong curls: measured converging on a slime ~10 PH away, then ricocheting around a doorway hitting 4 spots (bounce up to 5x each).
- Pattern: spear the front, the brood cleans the back rooms.
- Deepwood: the brood-javelin: throw spawns bouncing seekers that chase anything within a big radius; jackpot roll spawns a swarm.

### Sky Dragon's Fury
- Verb 1 HOLD: 360° staff blender around the player, ring radius ~1.3 PH, multi-target (two dummies at once, 130-160s).
- Verb 2 ALT: 3-orb fan; orbs burst into lingering electrosphere rings ~1.2 PH diameter that tick ~4/s for ~1.5-2s (three stacked spheres measured hitting a pedestal target repeatedly).
- Pattern: melee mode for the swarm, ranged field mode for statics — one weapon, two firing modes.
- Deepwood: our first true alt-fire melee: spin blender on hold, sphere-field volley on alt.

### Sleepy Octopod
- Pole swing cadence ~1 swing/0.7s, head reach ~1.3 PH; flank coverage both sides.
- SLAM on ground-pound: ~1.5 PH smoke/star burst + 300%-style big hit (136 vs 45-58 normals) + green Zzz sleep particles blanketing the target.
- Pattern: rhythm weapon — regular swings, then the deliberate slam beat for the burst + soft-CC.
- Deepwood: the dozing maul: slam attack (down-input) trades speed for a stun/drowsy AoE burst.

### Jousting Lance
- Couched lance, tip ~2.3 PH ahead, hits along the shaft; STANDING pokes = 4-6 damage; AT SPRINT = 45-64 (≈10x) with speed dust + afterimages visible.
- Damage scales with the PLAYER'S velocity; charge-through hits the whole line crossed.
- Pattern: the weapon is your movement — braking kills it, momentum is ammo.
- Deepwood: the charge-lance: damage multiplier reads current move speed; synergizes with dash relics/mounts; knight fantasy.

### Flint (1.4.5)
- NO DEMO OBTAINABLE (wiki.gg fetch-blocked; absent from Fandom mirror and Wayback). From the page scan only: charged ground-crawling flame wave, ~13 pillars marching along terrain.
- Deepwood note if adapted blind: hold-to-charge, release a terrain-following wave of sequential fire pillars; tune pillar spacing ~0.7 PH, march speed ~6 PH/s.

## SPEARS

### Storm Spear
- Thrust reach ~2 PH, ~1 thrust/0.9s; each thrust fires an electric bolt (~0.7 PH zigzag) from the tip.
- Bolt travels ~3-4 PH at ~10 PH/s, tile-blocked, can clip two lined-up targets; early-game numbers (11-17).
- Pattern: melee poke + free short ranged follow-through on the same input.
- Deepwood: starter storm-pike: every thrust spits a stubby spark bolt; teaches "spear with a projectile rider".

### Dark Lance
- Thrust ~2.5 PH horizontal, ~3.5 PH vertical span through stacked targets; ~1 thrust/0.7s.
- Shadowflame wisps swirl ~0.7 PH beyond the metal tip and LINGER as a particle column (~2.5 PH tall vertical) with number rain after the thrust retracts.
- Pattern: reach visually stretched by the flame aura; lingering tick zone where you stabbed.
- Deepwood: the shadow-pike: thrust leaves a brief damaging wisp cloud at the apex; vertical coverage is its niche.

### Gungnir
- Longest thrust measured: shaft spans to ~8 PH visible extension, golden head flare mid-shaft; ~1 thrust/0.8s.
- One thrust hit FIVE dummies across 7 PH simultaneously; frequent big crits (108-114); emits light (lit weapon).
- Pattern: the line-spear: everything on the lane is hit every thrust; muzzle-flash-like burst at the head.
- Deepwood: the god-pike: tip shockwave extends true reach ~2x the art; full-lane pierce each thrust.

### Obsidian Swordfish
- STUBBY: total reach ~1.6 PH (shortest studied); ~2 thrusts/s; vertical thrust hits platforms 1.5 PH up.
- Crit identity visible: big-font crits (130-152) roughly every 3rd-4th hit vs 72-78 normals (24% crit); 1-3 gravity embers per thrust per scan (faint in demo).
- Pattern: point-blank knife-fight spear — danger-close range traded for crit density.
- Deepwood: the shiv-spear: worst reach in class, highest crit; reward for face-tanking range.

### Chlorophyte Partisan
- Thrust ~2.5 PH; ~1 thrust/0.5s; at the apex EXHALES a spore cloud ~0.5 PH.
- Cloud drifts forward ~1.5 PH/s for ~1.7s (through walls per scan), infinite pierce: measured clouds at 2.3/3.5/5.3 PH hitting a 4th target at ~5.5 PH the metal never reached.
- Pattern: stab the front rank, the breath rolls on into the second.
- Deepwood: the spore-partisan: every thrust exhales a slow drifting damage cloud that keeps marching.

### Mushroom Spear
- Thrust ~2.6 PH (long extension ~4 PH); ~1 thrust/0.5s; each thrust leaves 5-10 glowing mushroom mines hovering ALONG the thrust line.
- Mines linger ~0.7-1s and pop individually on contact (approaching zombie eaten by the leftover field).
- Pattern: melee minefield — the stab is also area denial for the next second.
- Deepwood: the mine-layer spear: thrust plants a fading picket line of spore-caps; great door-holding verb.

### Ghastly Glaive
- Thrust ~2.2 PH with a flaming ghost-head (~1.3 PH long) riding the shaft; ~1 thrust/0.6s.
- Ghost-heads DETACH and drift/curl for ~1s (measured a second head curling 2.8 PH out above a different dummy — the "haunt another enemy" spawn), adding 1-2 PH of roaming coverage per swing.
- Pattern: spear the front, ghosts wander to harass the flank.
- Deepwood: the haunt-glaive: hits spawn short-lived phantoms NEXT TO other nearby enemies; spreads pressure off-line.

### North Pole
- One thrust launches an icy spear projectile ~14+ PH in a shallow arc; along the flight path it sheds a snowflake every ~0.5 PH.
- Snowflake curtain: flakes fall ~2 PH/s, persist ~4s, damaging everything under the whole path — measured hits marching across 9 dummies over 2.3s after ONE input.
- Pattern: one thrust = a lane shot AND a delayed rain zone; the sky keeps fighting for you.
- Deepwood: the blizzard-pike capstone: thrust fires a sky-writing spear whose wake rains frost; one input, two damage zones, huge readable payoff.

## CROSS-FAMILY MEASUREMENT TABLE (quick tuning reference)
| verb            | typical reach | cycle      | notes                       |
|-----------------|---------------|------------|------------------------------|
| yoyo dwell      | 2.2-3.9 PH    | 5-8 hits/s | wander ±0.5-1 PH             |
| flail hold-spin | 0.8-1 PH      | ~6 hits/s  | hits both flanks             |
| flail launch    | 4.5-7.3 PH    | 0.75-2s    | chain damages whole line     |
| rocket launch   | 9.5 PH        | 0.8s       | Golem Fist outlier, 23 PH/s  |
| boomerang       | 4.5-10 PH     | 10-15 PH/s | both passes hit              |
| spear thrust    | 1.6-8 PH      | 0.5-0.9s   | riders define identity       |
| flurry shell    | 0.8-1.2 PH    | ~12 hits/s | Terragrim/Arkhalis           |

Adaptation guardrails (from the measurements): keep yoyo dwell wander ≥0.5 PH so it
reads alive; flail launches must damage along the chain, not just the head; boomerang
return pass should pierce even if the outbound doesn't; spear riders (bolt/cloud/mine/
ghost/snow) all spawn AT THE APEX of the thrust, never at the player.
