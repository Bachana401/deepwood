# WEAPON VERB REFERENCE (Terraria-sourced, mechanics only — never text/names)
Calibration library for the attack-verb overhaul (dev order 2026-07-28: every
weapon a unique VISIBLE attack, Terra-Blade standard at the top, rarity-scaled).

## MEASURED YARDSTICKS (frame-surgery with the ruler; player-height = unit)
MEOWMERE (crown melee): swung blade 1.7 players long; projectile head 0.4
players dragging a 7-9 player RIBBON trail crossing 5+ targets; FULL base
damage per pierce (215-288 numbers on 200 base). RAZORBLADE TYPHOON (crown
magic): discs a FULL player-height, swarming, rapid repeat hits (84-103
ticks + kilo-crits). STAR WRATH: 3 stars/hit at full damage each, 0.5-player
heads, 3-4 player trails. CALIBRATION LAW: crown fx pay FULL price per
projectile; trails 4-9 players; projectile heads 0.3-1.0 players; spectacle
scales with tier while raw base stays modest.

## EXTRACTED MOTION RECIPES (GIF frame-surgery; the FOREVER method)
STAR WRATH (302 frames studied) → A Borrowed Star's starfall upgrade:
swing itself sheds sparkles; stars enter DIAGONALLY (~60-70°) from above
the screen at staggered heights/x-offsets (cascade, not volley); each is a
star-glyph head dragging a long TAPERING additive trail (hot→dim fade);
impact = sparkle FOUNTAIN erupting upward + lingering field; fast autoswing
= near-continuous rain. Deepwood build: borrowed-gold/amber palette,
2-3 staggered comets per hit, procedural star Polygon2D heads + fading
Line2D streaks + tweened particle bursts. NEXT weapon to frame-study when
its verb builds: Zenith (The Last Word), Meowmere trail, Solar Eruption.

## THE ZENITH STANDARD (dev: "top of the class" — the APEX weapon's shape)
The Last Word (T8) graduates from on-hit rider to FULL VERB, the ladder's
culmination: every swing hurls 2-3 blade-sprites toward the CURSOR in arcing
return paths — through terrain, homing near the cursor, piercing with the
decay rule — each blade a tinted echo of a real famous roster weapon (grade
palette), rapid autoswing, modest damage + elevated crit. CRAFT: forged at
the Forge from the ladder's famous crown blades + a rare catalyst (the
Zenith-culmination recipe at the top of the fusion-chain system). The swing
should FILL THE SCREEN and still never one-shot bosses (house rule).

### BUILT (bf572e3, GIF frame-study 403 frames, 300x103):
Measured: 2-3 differently-tinted sword-comets in flight at once; whirl arc
~2.5-3 player heights across, blade ~1 player height; sparkle residue on
retract; ~0.55s per image out-whirl-home. Deepwood build: "zenith" behavior →
"zenith_blade" kind (weapon_projectile): swoop UP AND OVER (bow 88px, minus
perp — Godot +y is down) to the NEAREST FOE ahead of the swing (cursor→foe
translation), one whirl loop r=66 re-cutting every 0.2s, home to the
wielder's current position cutting on return; LEGACY_TINTS cycle per swing
(static _zenith_cycle); additive trail + sparkle burst per landing. The Terra
slash upgrade landed with it: 34px tinted crescent + wake + lip, 44x58
hitbox, 25% pierce-decay, roster "tint" extra (Edge of the World = emerald).

## THE TERRA STANDARD (from Terra Blade, the dev's dropped example)
- Swing-aura BIGGER than the weapon (multi-hit cap ~3), autoswing, fast.
- EVERY swing also fires a signature traveling slash: infinite pierce with
  25%-damage decay per body, ~1.5s life, dies on walls.
- MODEST raw damage (85 at endgame!) — power lives in the verb. It glows.

## MAGIC VERB LIBRARY (76 from the wiki sweep; use as inspiration pool)
Pre-HM: sparks that ignite; through-block vine thorns (Vilethorn); CONTROLLABLE
explosive missile you steer (Magic Missile/Flamelash/Rainbow Rod); homing mini
tornado; bouncing fireball; erratic zig-zag beam (Zapinator); rapid lasers; a
swarm of homing bees; accelerating scythe disc (Demon Scythe); flying skull;
slow RICOCHETING bolt that lives long (Water Bolt); rain cloud (Crimson/Nimbus).
Early HM: three sword-shaped projectiles per cast (Sky Fracture); meteor called
from the sky at cursor; bolt that SPLITS into shards (Crystal Serpent); cursor-
area drain that heals the caster (Life Drain); poison fan spread; bouncing frost
ball; fast trident; through-wall piercing shards; big explosive fireball; homing
ghost bolt; rapid homing bats.
Late HM: boulder summon (rolls!); triple explosive fireballs; laser cone
minigun; short-range bubble spread; ricocheting cursed fireballs; PIERCING
golden stream (arcs with gravity); rapid tiny ricochet crystals; slow orb that
ZAPS everything near it as it drifts (Magnet Sphere); big fast homing disc
(Razorblade Typhoon); LASTING RAINBOW trail-wall (Rainbow Gun); instant-hit
beam (Heat Ray).
Endgame: three sky-flares exploding at cursor (Lunar Flare); temporary SOLID
ICE BLOCK summon (terrain!); lasting WALL of clinging flame (Clinger Staff);
homing explosive spirit flame; three erratic curving shadow bolts; four homing
crystals (Nightglow); ricocheting explosive orb that releases seekers (Nebula
Arcanum); converging multi-beam prism (Last Prism); harp notes that pierce and
bounce (Magical Harp); toxic lobbed flask splash; petrifying head beam.

## DEEPWOOD MAPPING RULES
- Tomes (12): each gets ONE distinct zone/cast verb — storm cloud (stormdebt,
  the classic), creeping bog (mirebook, mire_mode IN BUILD), inward-pulsing
  sigil ring (covenbook, coven_mode IN BUILD), ink jet piercing stream
  (inkbook), twin flanking clouds (grandrains), luring pull-wave (sirensbook),
  accelerating wake-scythe (wakebook), marching sky columns (deluge), sweeping
  tide wall (tidebook), rising knockup flood (highflood), homing soul stream
  (soulflood), walking storm + sky flares (skysfare, keeps walker rider).
- Wand bolts/fire/frost/cluster/ricochet/sentry families: splinter using the
  library above (controllable missile, zapinator zigzag, magnet orb, splitting
  bolts, boulder, ice block, clinger wall, bee/bat swarms, life drain...).
- Melee T8/T7: Terra duals (aura + signature slash, pierce-decay), each aura
  shape + projectile DIFFERENT. First: wpn_worldslash "A Cut Across the World"
  = emerald Terra cousin. Implementation: flying_slash maps to projectile kind
  "slash" (player.gd:3998); crescents fire at player.gd:3661; aura = scaled
  $AttackArea for the swing; decay in weapon_projectile slash hit path.
- Rarity scaling (dev): T8 full dual big aura; T7 dual smaller; T6 aura OR
  every-swing projectile; T5- enhanced single verbs. Raw damage DOWN as verb
  power UP, Terra-style.
## MELEE VERB LIBRARY (60+ from the wiki sweep)
Swords: sword-beam firers; star called from the sky on hit (Starfury); random-
direction phantom slash on projectile hit (Muramasa); spinning sickle shots;
through-block death sickle; explosive seed shots (Seedler); homing pumpkin
heads (Horseman's); arcing orb drops (Claymore); spore clouds (Saber); shield
shots through walls (Flying Dragon); MULTI falling stars (Star Wrath); bouncing
rainbow-trail shot (Meowmere); ornament-dropper (Christmas Tree Sword).
Yoyos: dwell-orbit family — bee-spawner on hit (Hive-Five), aura-projectile
spinner at endgame (Terrarian).
Flails: thrown/spinning family — confusion-inflictor (Dao of Pow), petal-
shooter (Flower Pow), CONTINUOUS grind anchor, homing bubbles (Flairon).
Boomerangs: multi-throw stacking (Trimarang x3, Bananarang x10, Light Disc x6);
cursor-orbiting knife you steer (Flying Knife); chaining shield (Sergeant
United); through-enemy hammer (Paladin's); homing hatchet (Possessed).
Spears: bolt-firing thrusts (Storm Spear); mushroom-spawning sweep (Mushroom
Spear); dragon-head ghost (Ghastly Glaive); snowflake-raining ice shot (North
Pole); spore cloud partisan; retracting joust lance.
Unusual: through-wall lash w/ explosions (Solar Eruption); returning solar
javelins (Daybreak); ultra-fast claw flurry (Fetid Baghnakhs); rapid hidden-
blade flurry (Arkhalis); healing knife fan (Vampire Knives); the Zenith.

## ACCESSORY → RELIC LIBRARY (30+; COMBINATION CHAINS are the big lesson)
Chains (Tinkerer-style: A+B→C→...): boots speed line → Frostspark → Terraspark
(water-walk+lava+flight fusion); Ankh Shield (charm + EVERY debuff immunity →
one shield); Master Ninja Gear (climb+dash+auto-dodge); Celestial Shell (form
shifts + stat suite); Cell Phone (all info trinkets); glove line Power→Titan→
Fire Gauntlet (knockback→autoswing→fire); Obsidian→Molten Skull; Lava Charm→
Molten Charm. Singles worth cousins: class emblems (+15% per class, stackable);
Sniper Scope (ranged crit); Yoyo Bag (dual orbiters!); minion-count scrolls;
Charm of Myths (regen+potion cooldown); Star Veil (longer i-frames); Worm
Scarf (flat 17% DR); Brain of Confusion (dodge-proc on hit); Frozen Turtle
Shell (thorns+slow); Frog Leg (jump); wings tiers; Angler Earring/Tackle Box
(fishing power — ties to OUR fishing!).

## DEEPWOOD ADAPTATION QUEUE (dev: pick best, similar-but-different)
1. ✅ Verb overhaul — DONE (task #20 closed at a136a20): 12/12 tomes, zenith
   crown, Terra slash, tier girth. See the BUILT notes above.
2. ✅ WEAPON FUSION CHAINS — the culmination landed (f6018db): The Last Word
   forges from worldsedge + afterlight + novatongue + 8 void essence, the
   same three blades its zenith tints remember. Further lineages (ranged/
   wand culminations) remain open ideas.
3. ✅ RELIC COMBINATION CHAINS — landed (1217ead): the Unbroken Seal
   (ward+aegis+phoenix) and the Wayfarer's Passage (wings+feather+blink),
   "relic_powers" plural in the engine. More fusions remain open ideas
   (info-trinket compendium etc.).
4. ✅ ARMOR SET BONUSES — landed (80b4e73): TEMPER / DEADEYE / SOULTHREAD
   triggered set-souls on the full-armor tier, audit-enforced card lines.
5. ✅ COMPANIONS (light summoner, dev call) — landed (e3a49cd): companion.gd
   blade/wisp/beast on three existing carriers + The Standing Star relic.
   Open ideas from the sweep below: merging-beast scaling, whip tag-loop.
## MELEE DEEP SCAN 2026-07-29 — YOYOS / FLAILS / BOOMERANGS / ODDBALLS
(67 pages opened individually; full stats + GIF filenames in the scan digest.
This section = the adaptation-grade essence.)

THE THREE FAMILY CONTROL SCHEMES (the real prizes):
- YOYO: thrown orb DWELLS at the aim inside a reach radius for a spin
  duration, steerable while held, returns on release. Progression = reach +
  dwell growing until dwell is INFINITE. Crown: Terrarian (reach 25 tiles,
  while spinning fires bouncing orbs every 0.1s at foes within 25 tiles).
- FLAIL: HOLD = ball orbits the player (close shredder); TAP = launch on
  chain, retract on impact. Launched subtype (Chain Knife/KO Cannon/Golem
  Fist) is throw-only, fire rate scales with proximity.
- BOOMERANG: flies ~0.5s, returns fast — and the RETURN pass gains infinite
  pierce and phases through blocks (park at max range for the sweet spot).

TOP VERBS TO ADAPT (ranked by the scan):
1. Solar Eruption — segmented lash sweeping a 33-tile ellipse THROUGH WALLS,
   every hit spawns explosions + a stacking burn (Daybroken 100/s).
2. Terrarian — the parked dwell-point becomes a bullet fountain.
3. Flairon — swing/launch mode toggle + constant ~15/sec homing bubbles;
   every miss still productive.
4. Daybreak — spears STICK and tick, stack to 8 (800 DPS), 9th pops the
   oldest as an explosion — a debuff meter you can SEE sticking out of the boss.
5. Sergeant United Shield — 5-hop ricochet throw + 0.33s parry that reflects
   200% and grants +500% next melee (defense-into-offense timing).
6. Jousting Lance line — damage scales with the PLAYER'S OWN SPEED.
7. Flower Pow — flail head RESTED ON THE GROUND becomes a petal turret
   (0.33s→0.17s fire when planted).
8. Scourge of the Corruptor — javelin bursts into ~3 homing larvae that
   bounce 5x and chase within 50 tiles.
9. Vampire Knives — 4-8 knife fan, every hit heals 7.5% as VISIBLE red
   life-threads flying home.
10. Golem Fist — rocket punch; past 9.4 tiles every impact detonates a
    through-wall 12.5-tile shockwave (KB 12, "Insane").
11. Flying Knife — held blade that orbits the aim drunkenly, up to 1 min.
12. Hive-Five / Terragrim — on-hit bee summons on a starter yoyo; and the
    12-hit/sec cursor-aimed flurry (melee as a held shredder cone, 5-frame
    i-frames as the rate limiter).

Also worth stealing: Blue Moon + Sunfury INVENTORY-PAIR synergy (both fire
mirrored when the twin is carried, 80% each); Anchor's block-impact
shockwave through walls (33% confuse); Dao of Pow's 80% Confuse roll per
swing; Paladin's Hammer block-impact explosion + Broken Armor; Amarok's
frostbite-on-most-hits; Cascade/Hel-Fire as light-source weapons; Bloody
Machete's gravity arc that returns only after a hit; Thorn Chakram corridor
pinball; Light Disc x6 / Bananarang x10 multi-throw ceilings; KO Cannon's
proximity-scaled fire rate; Sleepy Octopod's slam-on-block 300% explosion;
Flint's charged ground-crawling 13-pillar flame wave; Ale Tosser as the
joke-weapon slot ("69% chance to save ammo").

## MELEE DEEP SCAN 2026-07-29 — SPEARS + ENDGAME (every page opened)
ALL of these are adaptation candidates (not just the ranked ones):
- Storm Spear: thrust fires a 160%-dmg electric bolt (short, tile-blocked).
- Rotted Fork / Dark Lance / Gungnir: tip SHOCKWAVE stretching reach
  (11.5 → 13.5 → 16.8 tiles); Dark Lance adds shadowflame; Gungnir lit.
- Trident: weapon that is ALSO a traversal item (water mobility while held).
- Slime Spear: 100% sticky-slime debuff starter.
- Obsidian Swordfish: stubby reach but 24% CRIT + 1-3 gravity embers/thrust.
- Chlorophyte Partisan: thrust apex exhales a spore cloud that drifts
  THROUGH WALLS ~1.7s, infinite pierce.
- Mushroom Spear: each thrust leaves SEVEN hovering mushroom mines along
  the thrust line (~1s, 33% each) — melee minefield.
- Ghastly Glaive: curved thrust; every hit summons a ghast NEXT TO a random
  other enemy within 50 tiles (spear the front, haunt the back).
- North Pole: thrown icy spear sheds a CURTAIN of falling snowflakes (70%
  each, every 0.15s, persist 4s) — one input, two damage zones.
- Influx Waver: sword beam that TELEPORT-RE-STRIKES 2 extra times on hit,
  seeking within 15 tiles of the vanish point.
- Horseman's Blade: swing aura (3 targets) + every struck enemy summons a
  flaming pumpkin head diving in FROM OFF-SCREEN through blocks, retargeting.
- Christmas Tree Sword: star projectile that SHEDS ball ornaments every
  0.17s which hang then fall (projectile dripping projectiles).
- Starlight: melee rapier machine-gunning piercing light beams ~15 hits/s
  (tiny i-frames = the anti-armor DPS drill), reach ~13.7 tiles.
- Flying Dragon: every swing a huge crescent through walls, pierce 4, 1s.
- Sky Dragon's Fury: TWO verbs — 360° spin blender / 3-orb fan bursting
  into lingering electrospheres (melee alt-fire pattern).
- Solar Eruption + Daybreak: (already in the family digest above).
- First Fractal (cut content): dye-stripped player-copies swinging a
  15-sword flying barrage — legally safe to homage since it never shipped.
- Fun bones: True Copper Shortsword (Zenith joke-variant via shimmer),
  Scourge's 1% FIFTEEN-eater jackpot (built-in slot machine).

## MELEE DEEP SCAN 2026-07-29 — SWORDS (74 pages; scan complete, all 3 slices)
ALL adaptation candidates. The verbs:
- Starfury: swing calls a STAR down from the sky to the aim point (1.5x,
  phases through blocks until open air) — sword as artillery.
- Seedler: lobbed nut bursts into 4-7 homing thorns (guided cluster).
- Horseman's Blade: every hit summons pumpkin heads diving from OFF-SCREEN.
- Brand of the Inferno: right-click PARRY → reflect 200% + next melee 500%.
- Psycho Knife: stand still 0.83s → stealth: +300% dmg +30% crit opener.
- Bee Keeper: hits burst 1-3 homing bees + Confuse.
- Phaseblade/saber + Keybrand: release mid-swing to THROW; embeds as a
  ground trap (75-125%), recall on demand, return path damages.
- Breaker Blade 250% vs FULL-HP / Keybrand up to 2x vs NEAR-DEAD — the
  opener/finisher weapon-swap pair.
- Bladetongue: contact spits ricochet ichor stream (defense shred).
- Slap Hand: KB 20 "Insane" — the LAUNCH is the reward.
- Night's Edge→Terra line: 4 themed blades fused → aura sword → beam sword
  (the craft arc is the fantasy; we have chains + the culmination already).
- Ham Bat: damage scales with FOOD buff tier; kills grant regen (perfect
  Deepwood fit — village cooking feeds your sword).
- Exotic Scimitar/Falcon/Cutlass: shared RAMP family (+12%/hit cap +50%,
  decays 30%/s) — frenzy that must be fed.
- Blood Butcherer/Tentacle Spike: DoT that STACKS TO 5 embeds.
- Volcano: first hit per swing = 10x10 fire burst (3 targets).
- Death Sickle: spinning sickle drifts THROUGH WALLS then hangs 3s.
- Ice Blade/Enchanted/Beam Sword/Frostbrand: cooldown-metered bolt swords
  with an audible "reload" cue; Chlorophyte Saber/Claymore spore/orb kin.
- Light's Bane (tip slash, crit doubles) / Muramasa (echo slash) — the
  fusion ingredients each have a micro-verb.
- Gladius/Ruler: MULTI-STAB per click (3-4 fanned stabs).
- Katana 19% / Slap 19% / Obsidian Swordfish 24% crit as identity.
- Classy Cane: struck enemies DROP COINS (1-49 copper, luck-scaled).
- Zombie Arm/Flymeal/Waffle's Iron: the joke slots.
- Umbrella/Breathing Reed/Trident: weapon-tool hybrids whose utility
  SUSPENDS while attacking (clean tension); Cactus = reach identity.
- Psycho/Bladed Glove/Fetid Baghnakhs: use-8 claw class, reach traded
  for absurd rate (25-50% speed-bonus scaling as the limiter).

## SUMMONS / WHIPS / SENTRIES (agent sweep, 50+ mechanics)
Minions: divebombing bird; bouncing slime; stinger hornet; fireball imp;
latching venom spiders; dash-orbit crimson bats (fly out, slash, return to a
FIXED SLOT formation); flying dagger ignoring 25 defense through walls; mini
twin pair (one rams, one lasers); MERGING tiger — more summons = ONE bigger
beast with form breaks at 4/7 stacks; saw-sphere rams; teleporting UFO with
unmissable lasers; stationary sharknado spitting homing mini-sharks; cells
that latch AND seeker-shoot what the PLAYER hits; segmented dragon that GROWS
per summon instead of multiplying; Terraprisma's blinding formation dashes.
Sentries: eye-bolt statue; egg-lobbing spider queen spawning spiderlings;
frost-breathing hydra; portal sweeping an infinite-pierce beam; crystal
raining homing rainbow bursts; the four defender archetypes (lightning aura
zone ignoring defense / fireball tower / ground mine / piercing ballista).
Whips (tag loop): hit tags a foe → pets refocus + flat bonus vs it. Standouts:
next-minion-hit EXPLODES 2.75x (Firecracker); meteors fall on the tagged;
snowflake mini-minion spawner; tag CRIT donor; dark-energy AoE chains; petals
with armor pen; stacking whip-speed frenzy on consecutive hits.

## ARMOR SET BONUSES (30 sets swept; TOP 12 ranked for adaptation)
1. Kill-drop stacking boosters (Nebula): kills drop dmg/regen/mana pickups
   stacking x3 — a momentum loop. 2. Regenerating shield charges SPENT as an
   exploding dash (Solar). 3. One set, two ramp identities: hit-to-stack-dmg
   OR get-hit-to-stack-DR (Beetle fork). 4. One helmet swap flips the set
   support↔damage: magic-to-healing-orbs vs extra damage orbs (Spectre).
   5. The set IS a companion: repositionable taunting guardian (Stardust).
   6. Stealth-while-still ramps damage + sheds aggro (Shroomite). 7. EARNED
   dodge: striking arms a guaranteed dodge of the next hit (Hallowed).
   8. Thorns 200% + taunt = the tank enabler (Turtle). 9. The whip-tag pet
   economy (+ its enabler sets). 10. Gear that upgrades a SPECIFIC sentry
   archetype (Old One's sets). 11. Set bonus as a CASTABLE (double-tap storm
   at cursor, Forbidden). 12. On-strike proc trio: absorb-shard barrier /
   regen burst / homing petal (Titanium/Palladium/Orichalcum family).
Also: 0-mana for ONE signature weapon (Meteor); melee-hits-inflict-frost;
striking-grants-regen; accel/movespeed identity sets.

## DEEPWOOD SET-BONUS MAPPING (our armor already has set bonuses — extend)
Natural fits: Nebula loop → a Mage set; Solar dash-shields → Warrior set;
Beetle fork → two heavy sets; Spectre swap → Sage healer/damage helmets;
Stardust guardian → ties into our adventurer/defender fantasy; Shroomite
stealth → Archer set; whip-tag → future pet system hook (defer if no pets).

## RANGED VERB LIBRARY (agent sweep, 60+; TOP 15 ranked)
Bows: ammo-CONVERTERS (wooden arrows become flame/bats/bees — cheap ammo, the
bow IS the identity); sky-rain (Daedalus: nothing leaves the bow, 2-4 arrows
fall from screen-top at cursor; Blood Rain streams down); every-3rd-shot giant
phoenix that pierces then explodes (rhythm shot); teal bolt ricocheting off
walls 5x and hugging slopes (Pulse); 5-arrow vertical stack per 1 ammo
(Tsunami); split-on-hit into 90° downward fan up to 36 shots (Aerial Bane);
cursor-distance controls spread — close=shotgun far=focused (Eventide); on-hit
phantom flurry homing through walls onto the target (Phantasm, snowball DPS).
Guns: spread family (3-4 → autofire 6 → absurd 8-pellet wall); spread + dark
orb that detonates 10 tiles (Onyx); bullet-hose lineage with ammo-save % as
the knob (33→50→66); 3-round burst per 1 ammo; scoped zoom one-shot sniper;
bubbles that pop into perfectly-aimed bullets (Xenopopper); stream + free
homing rocket every 0.6s (Vortex Beater); money-as-damage Coin Gun; farmed
star-stream (Star Cannon).
Launchers/oddballs: bouncing lobbed grenades; mines that lie DORMANT until
walked near; nails that EMBED then explode 1.5s later, re-seeking on death;
flak that splits into pieces that EACH explode again (Stynger); homing
snowman missiles; rocket that stops at cursor and becomes a 5s ticking
electric ZONE (Electrosphere); 7-color random rocket slot machine (Mk2);
piranha that LATCHES and gnaws while held; tethered harpoon; sand that
becomes real terrain on impact.
Ammo lesson (THE trick): behavior lives in the AMMO — holy arrows call
falling stars per hit; crystal shatters into shards; chlorophyte homes;
meteor wall-bounces; ichor dart splits mid-air 2-5; cursed dart drips flames
BELOW its path; golden mints coins; rockets = {blast size}×{destroys tiles}.
TOP 15: sky-rain; one-ammo-many-shots; ammo-defines-behavior; split-on-
impact; homing swarm; bullet-hose w/ ammo-save; ricochet; blast×terrain
matrix; embed-detonate; shot-becomes-a-ZONE; plain-ammo converters; periodic
special shot; trap-laying; on-hit bonus flurry; resource-as-ammo gag.
⭐ ORTHOGONALITY (the genius): weapon verbs (spread/burst/rain/hose) MULTIPLY
against ammo verbs (home/split/bounce/ignite) — 30 weapons × 20 ammos feels
like hundreds. Deepwood cousin: QUIVERS/CHARGES as an ammo-like slot for
bows+wands (craftable, behavior-carrying) = variety multiplier without new
weapons. Craft chains found: Handgun→Phoenix Blaster; Minishark forks into
Megashark AND Star Cannon→Super Star Shooter; Shotgun→Onyx; bows ladder by
material only (no bow-into-bow).

## COMBINATION-CHAIN ATLAS (agent sweep — the relic/craft blueprint)
TOP CHAIN DESIGNS: (1) Ankh pattern — 11 trinkets from 11 different
tormentors, EACH blocking its donor's own debuff, tiering into one shield;
collection-becomes-power gold standard. (2) Terraspark pattern — two
independently-useful chains (speed line, lava line) that finally fuse; zero
wasted steps, every intermediate equippable NOW. (3) Info-pyramid pattern —
13 gadgets → 4 tools → one slot (and sources force play breadth: fishing
quests, rare enemies). (4) Emblem hub — one boss drop flows into THREE class
finals via later-boss souls; bosses as currency. (5) Parallel mini-chains +
capstone (three bottle+balloon pairs → quad jump). (6) Old-junk-matters —
pre-HM chest trinkets ride until an elite upgrades them into 10% dodge.
(7) Alternate recipes converge on one item (forgives RNG). (8) Build-defining
FORKS from one base (Mana Flower → stealth/cloak/magnet futures; shield →
tank/aggro pair; quiver → fire/stealth).
STATION GATING: each crafting station is itself loot/boss/NPC-gated (the
combiner NPC must be RESCUED — our Forge/Tinker cousin should be too);
recipes double as progression checkpoints.
MATERIAL LOOPS: boss → material → station/tool → new biome/ore → next boss;
paired light/dark souls; flight-gating soul; regrowing endgame ore; per-boss
signature bars. Deepwood already half-has this (iron/ember/void/relic ladder,
Forge depth-gate) — extend with per-boss signature materials + a rescued
Tinker NPC for RELIC COMBINATION chains.
DEEPWOOD RELIC-CHAIN QUEUE (adapt, similar-not-copy): an Ankh-cousin (status
immunities collected from the enemies that INFLICT them → one bulwark relic);
a Terraspark-cousin (move-speed line + hazard line → one stride relic); an
info-compendium relic (ties to Whisperstone); class-emblem hub fed by boss
materials; balloon-style jump line; forks from our existing relics.

SCAN COMPLETE: ~350+ mechanics banked (magic 76, melee 60+, ranged 60+,
summons/whips/sentries 50+, armor sets 30, accessory chains 40+, ammo 25+,
materials 15, stations, craft lineages). The picking + adaptation phase now
runs on this library alone — no more fetching needed for the build.

## RANGED DEEP SCAN 2026-07-29 — BOWS/REPEATERS/LAUNCHERS (51 pages, all opened)
Top verbs (ALL are candidates): Daedalus Stormbow (shots FALL FROM THE SKY at
the aim; useless under a roof = built-in balance); Celebration Mk2 (7-color
random rocket table — slot-machine weapon); Phantasm (wind-up fire rate +
on-hit 3 target-locked spectral homers; 66% ammo save); Proximity Mine
Launcher (lays armed 300% traps, cap 20, oldest expires); Nail Gun (15% now,
embedded 135% blast 1.5s later; nails EJECT and re-stick on kill); Stynger
(direct-hit double + 2-5 FULL-dmg shrapnel); Aerial Bane (6 arrows each
split 5 downward; +50% vs airborne); Electrosphere (missile becomes 5s zone
at cursor, new replaces old); Bee's Knees (recursive homing bee swarm);
Eventide (4 chaff + 1 lance 200%; CHEAP ammo upcycled); Pulse Bow (5-bounce
ricochet geometry toy); Phantom Phoenix (every 3rd shot = 200% phoenix —
metronome design); Barrel Launcher (no ammo; +33% if bounced first — pays
for bank shots); Blood Rain (sky-rain at low tier); Jack O Lantern (bouncy
rolling contact bombs); Tsunami (5 flat parallel); Hellwing (inaccurate
infinite-pierce bats = identity); Marrow (identity from raw velocity);
Chlorophyte Shotbow (2-3-for-1).
PATTERNS: verbs are saved for drops/bosses (24 stat-stick rungs pace the
reward); unique bows are AMMO CONVERTERS (cheap ammo stays relevant);
launchers differentiate by what they DO to shared ammo; shared i-frames tax
every multishot/pierce design.
## RANGED DEEP SCAN 2026-07-29 — GUNS/THROWN/ODDBALLS (64 pages, all opened)
Top verbs (ALL candidates): Xenopopper (harmless bubbles that each SNAP-FIRE
a real shot at the cursor 0.5s later — plant then steer); Piranha Gun (3
latch-and-chew fish, hold to sustain, re-home on kill); Coin Gun (fires
MONEY, damage by denomination — economy as emergency DPS, perfect for a
colony game); Sandgun (shots are BLOCKS that stay — combat terraforms);
Revolver (perfect-timing trigger stacks +100% speed +20% crit — rhythm
skill); Onyx Blaster (spread + delayed 200% crystal nuke in one pull);
Harpoon (chained spear pierces OUT then AGAIN on reel-back); Pew-matic
(random junk ammo 0.1-2.0x — jackpot projectiles); Bone Javelin (stacks 6
embedded, flat DoT ignoring defense — countable spears); Beenade (explosion
IS 15-24 homing bees); Clockwork (3-burst, only first bills ammo); Slime/
Water Gun (0-dmg sprayers priming fire vulnerability + toggling LIGHTS);
Toxikarp (flat-then-skyward bubbles own vertical shafts); Sniper (200 dmg,
29% crit, right-click ZOOM); Quad-Barrel (8 pellets, ONE always true);
Blowpipe (holding it makes plants drop ammo); Spiky Ball (thrown ground
trap ~80s); Sticky/Bouncy grenade physics variants; dart guns = identity
lives in AMMO (ricochet/split/ground-flame); Star Cannon (power gated by
unbuyable ammo); Molotov (6 lingering fire patches); Gatligator (inaccuracy
AS identity); Chain Gun (UT4, 15/s).
## SUMMONS DEEP SCAN 2026-07-29 — MINIONS/SENTRIES/WHIPS (60 weapons, all opened)
Top verbs (ALL candidates): Stardust Dragon (ONE pet GROWS per re-cast —
visible segments = levels; noclip coiling); Desert Tiger (stack-to-EVOLVE
cub→adult→armored + cross-terrain pounce); Terraprisma (skill-gated flawless
drop; never whiffs); THE WHIP TAG SYSTEM (player swing MARKS target, all
pets focus it + flat/crit tag per pet hit — summoner made ACTIVE; Kaleidoscope
= 20 tag +10% crit flagship); Firecracker (mark detonates next pet hit 2.75x
— favors heavy pets); Electric Eel (marks ARC between tagged enemies, scales
with count painted); Sanguine bats (fixed-period elliptical loop = metronome
reliability archetype); Stardust Cells (latching stacking DoT 10x20/s);
Foxparks (HOLD to grab your pet and fire it as a flamethrower); Cattiva
(combat pet that MINES and chops — worker crossover); Lunar Portal (beams
SWEEP 60° for ~1s); Queen Spider (eggs hatch homing spiderlings — two-stage
sentry ammo); Lightning Aura (defense-ignoring tick ZONE, explicit 50% tag
tax); Abigail (ONE ghost empowered per cast, immobile while attacking);
Barnacle (balloon sentry anchors on ceilings); Xeno (teleport-snipe UFO);
Mushroom (divebomb 133% then teleport home); Blade Staff (6 dmg, 25 pen —
hit-RATE thesis, whips double it); Ballista Panic (turret goes berserk when
the PLAYER takes a hit — defender fantasy); Explosive Trap (self-rearming
mines); Snapthorn/Durendal/Dark Harvest (whip-speed ramp while hitting).
## MAGIC DEEP SCAN 2026-07-29 — ALL 76 WEAPONS (scan complete; ALL FOUR CATEGORIES DONE)
Top verbs (ALL candidates): Last Prism (6 beams CONVERGE over 3.4s into one
annihilation ray; mana cost climbs as it focuses — commitment dial); Charged
Blaster (4 verbs by HOLD duration: tap/burst/heavy orb/sweeping death beam);
Nebula Arcanum (mothership orb accretes orbiting drones then bursts into
10-16 seekers); Killing Deck (stick cards then RECALL all through walls at
150% — set up, then harvest); Magnet Sphere (drifting orb auto-zaps nearest
— projectile that is a turret); Zapinators (chaos table: teleport/reverse/
x10 jackpots); Ice Rod (conjures SOLID terrain midair — spell as bridge);
Rainbow Gun (paints a 40s persistent damaging arc IN THE WORLD); Blood
Thorn (attacks erupt FROM terrain at the cursor); Magical Harp (cursor
DISTANCE sets projectile speed; infinite pierce+bounce); Stellar Tune
(stars arrive at cursor in fixed 0.5s, lead targets); Life Drain (channeled
drain aura, healing scales with enemies drained); Magic Missile family
(hold-to-STEER, home on release — one mechanic maturing 3 tiers); Clinger
(15-tile standing firewall 5min); Nimbus (2 placeable rainclouds 5min);
Water Bolt (10-pierce 30s ricochet ball + lava supercharge); Shadowbeam
(instant beam FOLDS around the room off walls); Nebula Blaze (1-in-5
jackpot bolt at 300%); Medusa Head (held gaze aura, mana only ON HIT);
Staff of Earth (physics boulder, damage scales with ROLL SPEED); Vilethorn→
CrystalVile→Nettle (wall-phasing lance family = 3-tier upgrade chain model);
Demon Scythe (stationary then accelerating buzzsaw); Weather Pain (parked
grinder tornado); Inferno Fork (lingering firestorm); Tome of Infinite
Wisdom (right-click terrain-crawling tornado); Spirit Flame (aimless wrath
finds targets); Razorpine (zero-gimmick hose DONE WELL earns a slot);
Betsy's Wrath/Golden Shower (defense-shred sticks defining loadouts);
Sky Fracture (3 swords from mini-portals); Blizzard/Meteor/Lunar Flare
(sky-rain ladder, Lunar phases through terrain to cursor depth).
## ITEM-SPACE SCAN 2026-07-29 — MATERIALS / POTIONS / ECONOMY (complete)
Systems (ALL candidates, colony-game hooks noted by the scan):
- ALTAR-SMASH ORE BLESSING: new resource tiers SUMMONED into explored ground
  by a ritual act — old floors worth re-mining. PICKAXE-POWER TIER LOCK: the
  tool is the key to the next tier (progression spine; we have this partly).
- HERB BLOOM CONDITIONS: each plant harvests best under time/weather/event
  (rain/night/blood-moon) — weather as farm scheduling. CHLOROPHYTE: the ore
  that GROWS — cultivate metal in planted beds (farming+mining merge).
- POTION SICKNESS: sustain balanced by ONE 60s heal-lockout number; relics
  shave it. FOOD AS REGEN LICENSE: 3-tier single food buff, top-difficulty
  regen only while fed — the cook becomes a progression NPC.
- FLASK IMBUES: alchemist coats weapons (armor-shred vs unquenchable-DoT
  choice), one active. ICHOR vs CURSED FLAME world asymmetry: mirrored
  biomes export different combat verbs — trade for the missing one.
- INFO POTIONS: knowledge as consumables (ore/trap/enemy glow, sonar).
- LUCK: hidden stat fed by small rituals (right torch +0.2, ladybug, gnome),
  read only via NPC fortune-teller prose. Shimmer coin-luck = money→RNG altar.
- TREASURE BAGS: per-player instanced boss loot; expert-exclusive uniques
  CHANGE MECHANICS (dash shield, permanent 7th accessory slot) not stats.
- BIOME KEYS: 1/2500 anywhere-in-biome dream drop + cursed chests that
  refuse to open until the story gate — visible future loot as motivation.
- SOULS: light/dark essence from ANY enemy in themed depths, glue for
  summons/wings/keys; player prints their own boss refights (we have kin).
- DEFENDER MEDALS: event-only scrip buying siege turrets/armor, insulated
  from gold. DEATH COIN-DROP + BANKING: carried wealth is risk, the Bank
  building earns its place. Coin Gun / Flask of Gold greed-build subeconomy.
- Numeric anchors: 100:1 coin steps, 20% soul rate, 1/2500 keys, 60s heal
  lockout, +8 def Ironskin baseline, 33% ingredient-save station, 3:1→5:1
  ore-bar creep, souls-from-all-three convergence gates (Drax pattern).
## ITEM-SPACE SCAN 2026-07-29 — ARMOR, ALL 50+ SETS (complete)
Top set-bonus verbs (ALL candidates): STARDUST GUARDIAN (armor grants a
free stationed bodyguard — double-tap to post him at a spot; village-
defense gold); NEBULA BOOSTERS (your hits DROP stacking buff pickups you
must run over — DPS as movement minigame, allies can grab); BEETLE
Shell/Might (visible orbiting beetles = ablative DR eaten per hit, OR
decaying melee ramp — stacks as diegetic UI); SPECTRE Hood/Mask (headpiece
flips the set healer↔selfish: lifesteal orbs fly to LOWEST-HP ally, hidden
throttle meters); SOLAR (shield charges = bonus DR AND dash ammo, spent
only on contact); METEOR lock-and-key (set zeroes ONE weapon's cost —
hunt combos not stats); VORTEX toggle-stealth vs SHROOMITE stand-still
stealth (stance systems); OOA SETS = TOWER-MOD CARDS (each boosts one
sentry; Squire's turrets ENRAGE when wearer is hit; Huntress OILED combo-
debuff); ORICHALCUM (every hit fires screen-crossing wall-piercing petal,
0.33s metronome); CHLOROPHYTE leaf crystal (orbiting auto-turret snipes
through walls at YOUR tagged targets); HALLOWED (striking ARMS a
guaranteed dodge, 30s re-arm); PALLADIUM (hits refresh 5s regen —
aggro-vampire); TURTLE/CACTUS taunt-thorns line (+750 aggro, 200%
reflect); FROST (dual-class chassis coats ALL hits with 25dps frostbite).
META-PATTERNS: ore twins fork stats-vs-toys per world; interchangeable-
piece families; class helmets on shared chassis (4-way at Chlorophyte);
utility sets as wearable MODES (Angler suppresses spawns); same-tier
siblings tuned to playstyle not power (Tiki whips vs Spooky raw).
## ITEM-SPACE SCAN 2026-07-29 — ACCESSORIES + ALL TINKER TREES (~60 pages; FULL-TERRARIA SCAN COMPLETE)
Top verbs (ALL candidates): ANKH SHIELD (11 scattered single-debuff charms
fuse via 5 pairs into one immunity capstone — the collect-a-thon relic
model; we built the light version already); SHIELD OF CTHULHU (first boss
pays out a MOVEMENT VERB — dash with ram+i-frames); CELL PHONE tree (13
junk trinkets each showing one HUD stat fuse into the all-knower — UI
unlocked as ITEMS); TERRASPARK (two long parallel boot lines merge; hoard
intermediates); SOARING INSIGNIA (endgame DELETES the flight meter — "the
rule stops applying" reward); BRAIN OF CONFUSION (dodge triggers a crit
window — defense as offense); BUNDLE OF BALLOONS (jump TYPES stack:
spin/thrust/blast → quadruple); CELESTIAL SHELL (day/night/water
shapeshifts + stat brick); MASTER NINJA GEAR (climb+dash+dodge = fantasy
kit); PAPYRUS SCARAB (stacks WITH its own ingredients); GRAVITY GLOBE;
SHINY STONE (huge regen only standing still); GREEDY RING (economy build
path from pirates); STAR CLOAK forks (one proc forked 3 ways by fusion);
PALADIN/HERO/FROZEN SHIELD (absorb ally damage + aggro — tank role as an
accessory); ROYAL GEL (boss reward pacifies its minion family — rescue-
fantasy gold); RAM RUNE (ground-pound, height-scaled damage — fits our
92px jump game); on-hurt bee/panic family; MUSIC BOX (records world music);
STRESS BALL (auto-attack idle); expert-bag uniques (Worm Scarf -17%,
Volatile Gelatin, Spore Sac, Bone Helm shadow hands, Demon Heart +1 slot);
YOYO BAG (counterweight+string+glove = the family's mastery item); boot/
glove/quiver/scope/emblem/cuff chains all mapped in the scan digest.