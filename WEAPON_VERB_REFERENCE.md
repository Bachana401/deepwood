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
1. Verb overhaul (task #20, in-flight) — melee/magic libraries above feed it.
2. WEAPON FUSION CHAINS at the Forge: 4-blade fusion → an Edge; True ancestors
   + rare catalyst → Terra-cousin; The Last Word = Zenith-culmination of the
   ladder's famous blades. Ranged/wand lineages from the ranged agent's sweep.
3. RELIC COMBINATION CHAINS (the Ankh lesson): our relics gain tinker-fusions
   (e.g. all status-immunity trinkets → one Bulwark Locket; speed line →
   all-terrain stride; info trinkets → a Whisperstone-tier compendium relic).
4. ARMOR SET BONUSES (awaiting summon/armor agent report): sets with MECHANIC
   bonuses (guardian minion, stacking kill-buffs, stealth-while-still, ramping
   defense), rarity-scaled.
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
