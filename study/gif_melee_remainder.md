# GIF Motion Study — Melee Remainder (wave 2: yoyo ladder / flail ladder / boomerang ladder / oddballs / spear ladder)
2026-07-29. Method: official demo GIFs (Fandom mirror originals; wiki.gg direct for 1.4.5-only
items), 8 keyframes each (5 spread + consecutive triplet) via System.Drawing at native pixel
scale. UNITS: 1 PH = 1 player-height = 48px = 3 tiles (task's "PL" = same unit). Speeds from
keyframe displacement / GIF frame delays. Measurements only — no pixels copied.
54/54 GIFs obtained (0 failures). ⭐ FLINT RETRY SUCCEEDED: wiki.gg Special:FilePath serves the
real GIF to a plain PowerShell fetch now (wave 1's block is gone) — that route also yielded two
1.4.5 demos nobody had: Slime Spear and Tonbogiri. Skipped as already studied in wave 1:
Gladius (swords file), Light Disc + Storm Spear (families file).

Shared stage note: the early-weapon demos use a fixed set (player left, dummy ~2.5 PH away,
30ms frames), so family rungs are directly comparable frame-for-frame.

## YOYOS (the 13 remaining rungs — orb 0.25-0.3 PH everywhere; the ladder is a NUMBER ladder)

### Wooden Yoyo
- 83f/2.5s. Orb ~0.29 PH wood-brown; demo reach ~2.3 PH; wander hand-height↔ground; ~4 hits/s; hits 8-10.
- Motion: the family verb at its plainest — throw, the orb hangs on a sagging string and potters up and down against the dummy, numbers dripping one at a time. String visibly slackens when the orb dips low. No particles, no status, no crits. It reads as a toy, which is the point of rung one.
- Deepwood: tier-1 dwell-orb — bare string + orb, small single numbers; every later rung is THIS rig plus one garnish.

### Rally
- 101f/3.0s. White-blue orb ~0.25 PH; hits 13-16 in triple stacks; dips to ankle height 1.4-2 PH out.
- Motion: identical choreography to Wooden with the tick stream tightened (~5/s) and the wander biased low — the orb spends most of the mid-run grinding at the dummy's knees, then whips back up to hand height. Stacked pairs/triples of numbers are the visible upgrade.
- Deepwood: rung two = same rig, +hit rate; bias the dwell bob toward the target's feet so it reads different from rung one.

### Malaise
- 120f/3.6s. Black-violet orb, green glint, ~0.27 PH; 15-18 with 4-stacks; wander ±0.5 PH around a mid line.
- Motion: the corruption skin of the same verb — tighter orbit, a darker orb whose single green specular glint is the only flourish. Number columns thicken (four digits airborne at once) while amplitude actually shrinks: menace by restraint.
- Deepwood: the "dark" palette rung — reduce wander, add one glint pixel; let stack density carry the tier.

### Artery
- 109f/3.3s. Bright red crystal orb ~0.27 PH; 15-19; consecutive 30ms frames show a 0.5 PH vertical whip at the dummy.
- Motion: the crimson twin: same numbers as Malaise but violent movement — the orb slams from the dummy's face to its feet between adjacent frames, the hardest dwell-bounce in the early set. Reads angry, not floaty.
- Deepwood: same rung, opposite temperament — big fast vertical bounce amplitude at the dwell point; palette + motion contrast vs the Malaise cousin.

### Amazon
- 129f/3.9s. Green woven orb ~0.27 PH, pink rim glints; 17-23 plus faint small DoT ticks; leaf-green motes shed near the orb.
- Motion: first rung with a rider — hits leave a poison that keeps printing small faded ticks above the dummy after the orb moves off. The woven-texture orb visibly rotates, shedding a leaf mote every few frames. Otherwise the standard dwell-wander.
- Deepwood: the status rung — dwell orb applies our poison on most hits; sell it with 1-2 leaf motes/s, nothing more.

### Code 1
- 144f/4.3s. White-blue techno square ~0.27 PH with the brightest glow rim of the early set; 18-23 in 5-stacks.
- Motion: the precision skin: the orb holds a nearly flat line at chest height with minimal bob, and the tick stream is the fastest so far — five digits airborne at once. Identity is glow + discipline rather than any new mechanic.
- Deepwood: the "machined" rung — clamp the wander near zero, add an additive rim glow; the steadiness itself reads as quality.

### Valor
- 161f/4.8s. Maroon ring-orb ~0.3 PH; 19-25 with the family's first big-font CRITS (44s); dwell rides at the dummy's face ~2.6 PH out.
- Motion: the first rung where the number theater changes register — fat orange 44s punch through the 19-25 drizzle roughly every second. The orb prefers head height, hammering the same spot rather than roving.
- Deepwood: the crit rung — introduce crit font/color here; face-height dwell bias makes the crits land where the eye already is.

### Format:C
- 118f/3.5s. Magenta flower-disc ~0.27 PH, petal pattern spinning; 25-31 with 52-70 crits; densest stacks yet (6+ digits at once); dips to ankle and rides back up.
- Motion: the early ladder's crescendo: highest stream rate (~6+/s), two crit tiers visible, and a disc whose spinning petal texture is legible at native scale. The number cloud over the dummy is now half the spectacle.
- Deepwood: pre-hardmode capstone yoyo — max tick rate for the tier + two-step crit table; spinning-texture orb sprite.

### Gradient
- 166f/5.0s. Gold ring, red-pink core, ~0.29 PH; 29-38 in fast triples; standard wander.
- Motion: a clean stat rung — the hardmode-entry yoyo whose demo is indistinguishable from Format:C's except every number is a third bigger. Proof the family sells tier jumps on digits alone once the rig is established.
- Deepwood: the honest stat rung — no new garnish, just the damage table and a gold palette.

### Chik
- 147f/4.4s. Magenta-violet GLOWING orb ~0.3 PH with a real halo + violet sparkle residue around the contact zone; 34-45; carries low at the dummy's feet.
- Motion: first rung with a particle budget: the orb drags a soft purple glow and leaves a couple of sparkles where it grinds. The low carry (feet-height dwell) plus halo makes it read as a hot coal being held against the target.
- Deepwood: the glow rung — additive halo + 2-3 residue sparkles/s; from here up, light is part of the family language.

### Yelets
- 173f/5.2s. Olive-black spiked ball ~0.3 PH; 51-69 with 130-165 class crits; dwell at the dummy's legs.
- Motion: mid-hardmode muscle: the spiked silhouette is readable at range, and the crit font now doubles the normal digits. Movement is workmanlike — the ladder's spectacle at this rung is purely the crit punctuation.
- Deepwood: the bruiser rung — spiked sprite, heavy crit multiplier, no glow; contrast on purpose with Chik below it.

### Red's Throw
- 138f/4.1s. Royal-blue disc, gold cross-star pattern, ~0.3 PH; 60-78 with persistent 5-6 digit columns; tight mid-body wander.
- Motion: near-endgame density — the number column over the dummy never empties across the whole mid-run. The ornate disc art does the prestige work; motion is disciplined like Code 1, which by now reads as mastery.
- Deepwood: the prestige rung — heraldic disc art + permanent number column; wander tight, stream ~6/s.

### Valkyrie Yoyo
- 137f/4.1s. Violet-blue disc, cyan core glints, ~0.3 PH; 60-80 in 5-6 stacks; held dwelling continuously through the whole demo.
- Motion: the "forever" tell — the demo never shows a return; the orb just stays parked on the dummy with cyan glints, confirming the infinite-dwell top of the family curve. Number density matches Red's Throw; the upgrade is endurance.
- Deepwood: the infinite-dwell rung (our family law already says dwell grows till infinite) — this is where the timer disappears.

## FLAILS (the 5 remaining rungs)

### Chain Knife
- 202f/4.0s. Knife head ~0.35 PH on a chain; flat launch ~2.5-3 PH; out-and-back ~0.4s; hits 10-14.
- Motion: the launched-subtype starter: no orbit at all — point, spit the knife, it's home again before most keyframes catch it (5 of 8 sheet frames show it already retracted). Feels like a melee-range pistol with a chain. Damage small, cadence the whole identity.
- Deepwood: throw-only starter flail — fastest cycle in class, shortest reach; teaches the launch verb before the orbit verb exists.

### Mace
- 161f/4.8s. Spiked ball ~0.4 PH, visible ball-link chain; held spin grinds at ground level beside the player; launches 2.8-5 PH flat; chain-line hits 8-20 across 3 dummies; cycle ~1.2s.
- Motion: the honest two-verb flail at starter numbers: hold to drag the ball around your boots, tap to send it down the row where the CHAIN, not just the head, prints numbers on everything it lies across. Slow, heavy, readable.
- Deepwood: baseline hold/launch flail — our tier-1 chain weapon; chain-line damage from day one (family guardrail).

### Flaming Mace
- 360f/7.2s. Same rig on fire; launch ~4.5 PH; every touched dummy IGNITES — 1-1.3 PH flame columns swallowing the sprites, "1" burn ticks persisting seconds after the player idles; 40-class crits.
- Motion: the Mace plus consequence: the demo's second half is just three dummies burning like candles while the ball rests. Ball sheds fire in orbit, launches paint ignition down the line, and the aftermath outlasts the input several times over.
- Deepwood: the burn rung of the mace line — identical verbs, add ignite-on-touch + standing flame columns; upgrade legible purely in aftermath.

### Ball O' Hurt
- 242f/4.8s. Violet spiked ball ~0.45 PH on a bead chain; launch ~5.5 PH reaching the FAR dummy; one throw prints 13-33 along THREE dummies at once; held spin grinds at ground level.
- Motion: the corruption rung: longest launch of the early flails, and the sheet catches the money frame — chain taut across the whole row, numbers hanging over every body it crosses plus the impact hit at the tip. Lane-clearing as one input.
- Deepwood: the reach rung — launch range grows ~2x over Mace; keep whole-chain damage so the long throw means a long cut.

### The Meatball
- 106f/3.2s. Dark-crimson ball ~0.4 PH; horde demo — launch ~4.5-5 PH through a zombie pack; clusters 15-33; kills EXPLODE into gore/bone showers mid-chain; close spin grinds with blood spray.
- Motion: the butcher's rung: same verbs as Ball O' Hurt but demoed against a crowd, and the flail carves tunnels — every launch ends with skulls and gibs raining and 5-6 numbers strung along the path. Wet particle language instead of glow.
- Deepwood: the gore-flavored crimson twin — mechanical sibling of Ball O' Hurt, splatter particles on every contact; horde-demo energy.

## BOOMERANGS (the 8 remaining rungs)

### Wooden Boomerang
- 73f/2.2s. Crescent ~0.35 PH, visibly spinning (new orientation each frame); outbound ~14 PH/s; reach ~5.5 PH; round trip ~1.2s; hits 7 (18 crit).
- Motion: the naked return verb: spin out flat, kiss the dummy, spin home along the same lane, both passes billing. Zero trail — the readable frame-to-frame rotation IS the animation. Missing the catch just means waiting.
- Deepwood: tier-1 rang — pure out-and-back with sprite spin; establish the both-passes-hit rule here.

### Enchanted Boomerang
- 81f/2.4s. Night-blue crescent ~0.4 PH; multicolor twinkle motes strung along the ENTIRE flight path, persisting ~1s after passage; 12s on both passes; reach ~6 PH.
- Motion: the Enchanted Sword's little cousin: the rang paints a dotted rainbow corridor player→target→player, and the corridor outlives the projectile — for a beat the whole route hangs in the air as confetti. Damage barely matters; the air remembering the throw is the identity.
- Deepwood: the glitter-wake rang — persistent twinkle corridor (1s fade), our relic-tier starter feel-weapon; cheap Line2D of star sprites.

### Ice Boomerang
- 88f/2.6s. Cyan crescent ~0.35 PH; dense WHITE snow-flake trail (heavier than Enchanted's confetti); struck dummy disappears in a ~1 PH frost-sparkle cloud; 14-18; reach ~8.5 PH; trip ~1.3s.
- Motion: colder and longer: the trail thickens to a snow ribbon, and impact wraps the victim in a glittering frost puff that hangs while the rang swings home. Longest early-rang reach measured — the ice line buys range plus aftermath.
- Deepwood: the frost rung — snow ribbon + impact frost shroud + chill chance; reach grows ~1.5x over wood.

### Shroomerang
- 119f/6.0s (50ms frames). Blue mushroom-cap crescent ~0.3 PH shedding glow-spore motes; 13-15; return path curls in a tight U AROUND the far dummy.
- Motion: the drunk one: it doesn't fly a straight lane — the return leg banana-curves behind the target, visibly hugging its back before swinging home, spore motes dotting the whole loop. One throw wraps a foe in a glowing horseshoe.
- Deepwood: the curl-rang — scripted U-turn apex around the first thing it passes; hits front then BACK of the same target (teaches flanking with one input).

### Fruitcake Chakram
- 231f/4.6s. Festive studded ring ~0.4 PH; loiters mid-air between player and target ~2.7-3 PH out, wanders as far as ~7 PH high before coming home; 13-15.
- Motion: the lazy patroller: instead of a crisp out-back, the ring hangs and drifts around the aim area for whole seconds, looping the room like a bored wasp while numbers tick whenever it grazes. Cadence is slow; presence is long.
- Deepwood: the loiter-rang — extended airtime with a wandering hover near the aim point before return; area-presence rather than lane damage.

### Bloody Machete
- 115f/3.5s. Machete ~0.5 PH tumbling END-OVER-END; thrown UP in a gravity arc (~3 PH apex), falls ~5 PH downrange, blood specks along the tumble; 17s; returns only after connecting.
- Motion: the mortar-rang: it leaves the hand climbing, flips like a thrown cleaver, and drops onto whatever stands under the arc's far side — then snaps home once it tastes blood. The visible gravity sag makes it aim like a lob, not a laser.
- Deepwood: the gravity-rang — arced flight + return-on-hit rule (whiffs land and wait a beat); rewards reading the drop like our lobbed weapons.

### Combat Wrench
- 402f/8.0s. Red pipe wrench ~0.5 PH; 2-3 airborne AT ONCE with red motion-smear trails; short reach ~2.5-3 PH; cycle ~0.5s; twin dummies take 21-28 in 4-6 stacks per pass.
- Motion: the spam-rang: throws leave the hand faster than they return, so the corridor fills with tumbling red blurs crossing each other in V-shaped smears. Both dummies bill on both passes of every wrench — saturation at knife range.
- Deepwood: the mechanic's swarm-rang — low reach, multi-live-copies (cap 3), smear trails; the Bananarang thesis at melee distance.

### Flamarang
- 488f/9.8s. Flaming crescent; the ENTIRE flight path is drawn in fire motes ~5.5 PH long; victim engulfed in a flame column that still ticks "1"s at the 8.5s mark; 30-34; S-snaking return visible in consecutive frames.
- Motion: the Ice Boomerang's hot twin, louder: the lane burns while the rang flies it, and the target keeps burning for most of ten seconds after one tag. Return leg weaves an S around obstacles rather than retracing exactly. One throw = lane + bonfire.
- Deepwood: the burn-rang — fire-mote lane trail + long standing ignite; pairs with Ice as the elemental fork of one rig.

## ODDBALLS (19)

### Ale Tosser
- 389f/7.9s. Gold mug ~0.3 PH; high gravity lob (~3 PH apex, ~4.5-6 PH range) with droplet spray on descent; SHATTERS into a gold-droplet + white glass-shard burst ~1.5-2 PH wide that rains to the floor and bounces; 19-21.
- Motion: pure pub artillery: the mug tumbles up and over, sheds beer on the way down, and detonates into a wet golden firework on whatever it meets — splash first, physics after, droplets bouncing off the flagstones. The joke lands entirely through the shatter.
- Deepwood: the tavern lob — consumable-flavored grenade with liquid+shard two-part burst; ties to our brewer/inn fantasy, keep damage modest.

### Shadowflame Knife
- 209f/6.3s. Thrown knives on high BOUNCING arcs spanning ~9 PH; full-path violet sparkle trails; struck dummies wreathed in purple flame with "5" shadowflame ticks 3+ s; 36-44 per hit, three dummies burning at once.
- Motion: the demo reads as calligraphy — every throw draws a tall violet arc across the room, rebounds once, and where it lands a body ignites in pink-purple fire that keeps writing small 5s. Multiple arcs overlap into a lattice of glitter with three simultaneous burn sites.
- Deepwood: the shadow-brand knife — arcing one-bounce throw + our shadowflame-style DoT; the full-path trail is mandatory, it IS the weapon on screen.

### Flint (1.4.5 — RETRY SUCCESS)
- 329f/9.9s, 597x395. Hold-to-charge visible: the flame in the raised hand grows to a ~1 PH column; release → a gold spark wave marches ALONG the terrain, climbing a stepped tower and tagging dummies at four different heights; hits 70-129. (Old-GIF disposal artifacts in some frames; wave shape read from the spark scatter.)
- Motion: charge like a torchbearer, then let the ground itself carry the attack — the wave walks up stairs and over ledges, hitting things a straight projectile never could. The charge pose doubles as a light source; the payoff is watching fire take the architecture's path.
- Deepwood: the terrain-crawler — hold-charge, release a stepped flame wave that follows floor contours (pillar spacing ~0.7 PH, march ~6 PH/s per the wave-1 blind note — now confirmed on film with real height-climbing).

### Waffle's Iron
- 105f/3.2s. Dark studded iron plate ~0.4 PH swung flail-style at close orbit; 46-59; struck zombie IGNITES with a persistent flame column + small burn ticks afterward.
- Motion: the breakfast weapon played straight: a waffle iron on a chain smacking at arm's length with real hardmode numbers, and — the punchline — victims catch fire and cook, burning for seconds while the player stands there. Joke sprite, sincere aftermath.
- Deepwood: the kitchen flail — close-orbit smacker that applies a burn ("branded"); crosses the joke slot with the cooking/village fantasy.

### Flymeal
- 91f/2.7s. Mottled brown-green blade ~0.9 PH; every struck zombie gains a clinging GREEN FLY SWARM (~0.6 PH buzzing cloud) that persists 2+ s; ticks 13-16 keep printing while swarmed.
- Motion: swing a rancid sword, and the flies do the sustain: both zombies in the demo spend the whole mid-run wrapped in their own jittering green clouds, ticking quietly with the player idle. It's the Bee Keeper verb wearing a garbage palette.
- Deepwood: the carrion blade — on-hit personal fly cloud (cap 1 per victim) ticking chip damage; comedy skin on the proven swarm rig.

### Zombie Arm
- 38f/1.1s loop. Severed arm ~0.8 PH; plain swings, 14s, zero particles; shortest GIF in the entire slice.
- Motion: a zombie's arm used as a club, animated with total sincerity and nothing else — no glow, no flecks, just meat arcs and small numbers on the fastest loop in the study. The brevity is the gag: there is nothing more to show.
- Deepwood: the trophy club — droppable from our shamblers, no-particle rule (Ham Bat law), quick swing, tiny numbers; pure early-game comedy find.

### Bat Bat
- 236f/4.7s. Purple bat-winged club ~1.3 PH; hits 29-40; GREEN "+1" heal numbers pop on the PLAYER as hits land; skeleton kill bursts into bones.
- Motion: a big floppy bat-shaped bat swung at normal melee cadence — and every connect pings a small green number on the wielder, the lifesteal drawn in the same number language as damage. Two number streams, two colors, one swing.
- Deepwood: the leech club — 1 HP visible heal tick per hit (green float on the player); teaches vampirism-as-numbers before the Vampire Knives tier does threads.

### Purple Clubberfish
- 91f/2.7s. Purple fish ~1.2-1.4 PH, full fins-and-face silhouette; 20-27; zero effects; unhurried overhead arcs.
- Motion: the Ham Bat thesis in fish form — an absurd slab swung earnestly with no particle budget whatsoever, respectable numbers, and the silhouette doing all the comedy. Every frame with the fish overhead is a punchline; nothing else is needed.
- Deepwood: the fish slab — big joke silhouette, honest mid damage, hard no-particles rule; fishing-loot crossover slot.

### Bladed Glove
- 202f/4.0s. Silver claw ~0.35 PH at the fist; 10+ hits/s — 6-8 digits airborne at once (10-14 + 24-26 crits); reach ~1.2 PH; the swing pose itself blurs.
- Motion: point-blank sewing machine: the arm flickers between up/forward poses too fast to read, and the wall of overlapping small numbers over the dummy becomes the actual visual. The claw class formula on film — reach traded for absurd cadence.
- Deepwood: the claw rung one — sub-melee reach, 10+ ticks/s with tiny i-frames; the number cloud is the render, budget nothing else.

### Stylish Scissors
- 63f/1.9s. Scissors ~0.3 PH; single clean 14-15s at relaxed cadence; no effects.
- Motion: deadpan snips — a stylist's shears poking at arm's length, one modest number at a time, in and out in under two seconds of loop. Reads as a barber humoring a customer; the restraint (vs the glove's blur beside it in the same class) is the joke.
- Deepwood: the barber's shears — Stylist-NPC vendor joke; single precise ticks, add a 1-in-N "trim" cosmetic proc (clipped-hair particles) as its one flourish.

### Mandible Blade
- 137f/2.8s. Amber serrated blade ~0.9 PH with a glowing RED gem/glint at the tip; 12-15 in doubles/triples; fast cadence; tiny gold chitin flecks along the arc.
- Motion: a starter blade that shimmers like the desert: quick honest arcs, a hot red tip-point that draws the eye through every pose, a sprinkle of gold flecks molting off the edge. No projectile, no status — just a well-dressed fast small sword.
- Deepwood: the chitin blade — early fast sword whose garnish budget is one glowing tip pixel + 2-3 arc flecks; desert-ruin loot identity.

### Ruler
- 101f/5.0s (50ms). Wooden ruler ~0.6 PH held STRAIGHT OUT flat; 11-13 in surprise clusters of five; second half vs a live zombie: 6-10, kill with debris burst.
- Motion: the funniest pose in the slice — the ruler never arcs, it just extends horizontally like the player is measuring the dummy's chest, yet clusters of five numbers pop per poke. Bureaucratic violence: flat affect, dense paperwork.
- Deepwood: the measuring stick — flat-poke animation (no arc), multi-tick per poke; hidden bonus idea: exactly-1-tile reach, and hits print their distance as flavor.

### Katana
- 158f/3.2s. Slim silver blade ~1.3 PH, gold cross-guard; 16-18 with a fat orange 28 CRIT roughly every third hit; fast full arcs (up/overhead/down); zero particles.
- Motion: the crit metronome: nothing about the swing is decorated, but the number stream alternates small-small-BIG with mechanical reliability, the oversized crit font doing the work a glow would. Cadence high, rhythm audible in the numbers alone.
- Deepwood: the duelist's blade — elevated crit chance as the whole identity (our 19%-class), crit font 1.5x + sound; keep the sprite austere.

### Cactus Sword
- 164f/3.3s. Chunky green blade ~1.1 PH studded with yellow-green needle glints; 7-9s; a level swing skewers BOTH adjacent dummies; needle flecks shed on arcs.
- Motion: the starter slab with reach: weakest numbers of the batch but the level poses show two bodies billed per swing — width as the compensation. Needle sparkles molt off the edge like the plant is still alive.
- Deepwood: the desert starter — low damage, +1 target multi-hit vs the wooden tier, needle-glint particles; "the sword that is still growing".

### Umbrella
- 155f/3.1s. Red-white umbrella ~0.9 PH; jab pose with the open canopy forward ("9"s); overhead-canopy pose WHILE FALLING down a multi-tile drop — the slow-fall on film; modest cadence.
- Motion: two tools in one sprite: leveled, it's a polite canopy-first shove; raised, the player steps off a ledge and floats down the whole shaft of the stage under it. The demo intercuts poking and parachuting — attack and utility visibly share the hand.
- Deepwood: the drifting brolly — weak jab + hold-up-to-slow-fall (fits the 92px-jump world instantly); utility suspends while attacking, the clean tension our reference already names.

### Breathing Reed
- 119f/6.0s. Green reed ~1.5-2 PH held VERTICALLY; underwater stage: player fully submerged, reed tip above the surface, breath-bubble UI row visibly held full; on land it pokes overhead for "10"s.
- Motion: the demo is mostly a player standing calmly on a flooded floor, reed up like a periscope, breath icons refusing to drain — then a brief land scene proving it also technically hits things. A tool wearing a weapon costume, and honest about it.
- Deepwood: the snorkel staff — held-item that pauses breath drain while the tip clears water + a token overhead poke; our flooded-cave layers want exactly this.

### Fetid Baghnakhs
- 151f/3.0s. Crimson-green claw ~0.5 PH; 56-69 in columns of 5-8 digits refreshing near-continuously; reach ~1.2 PH; overhead/forward pose flicker.
- Motion: the Bladed Glove grown into hardmode: same blur choreography but every tick now lands with real weight, so the number column reads like a slot machine paying out forever. Point-blank range means the player hugs the target for the whole demo.
- Deepwood: the claw rung two — same rig as Bladed Glove with the damage table swapped up; the family scales by numbers alone (yoyo-ladder law applies to claws too).

### Hallowed Jousting Lance
- 87f/4.4s (50ms). Couched red-white striped lance, tip ~2.3-2.5 PH ahead with a gold flare; standing pokes 6-14; SPRINT charge → 63-114 (10x) across all three dummies + blue star speed-dust at the feet.
- Motion: parked, it's a gilded toothpick tapping single digits; moving, the same input strafes the whole row for tenfold numbers with sparkle dust boiling off the boots. The demo's edit — poke, walk away, THEN charge — teaches the law in three beats.
- Deepwood: the holy charge-lance — velocity-scaled damage (the family law, now confirmed on the Hallowed skin too); gold tip flare + speed-dust as the "you're doing it right" tell.

### Shadow Jousting Lance
- 95f/4.8s. Violet lance ~2.5-3 PH with a glowing purple crystal tip; standing 8-11 + 24 crit; full charge → 88-95 on all three dummies + violet spark scatter + blue dust.
- Motion: the dark twin, measurably identical: same 10x velocity payoff, same three-body skewer, with the garnish swapped to purple crystal sparks. Two skins, one law — the pair proves lances scale by momentum, not palette.
- Deepwood: the shadow charge-lance — mechanical twin of the Hallowed with our void palette; ship both as faction-flavored variants of one rig.

## SPEARS (the 9 remaining)

### Spear
- 67f/2.0s. Iron spear; thrust ~1.7-2 PH; 7-9s; a level thrust bills TWO adjacent dummies; vertical thrust pokes a ledge dummy 1.5 PH above; ~1 thrust/0.55s; gold glint flare at the contact point.
- Motion: the family grammar in one demo: horizontal line-pierce, then straight-up anti-air — the same input aimed at the sky, something no sword in the study does. The tip flare is the only effect; the aim freedom is the actual content.
- Deepwood: tier-1 spear — line-pierce (2 targets) + true vertical thrust; establish up-stab as the class's exclusive right here.

### Slime Spear (1.4.5 — bonus find, wiki.gg)
- 174f/10.4s (60ms). Chain-link shaft extending ~2 PH up with a slime tail dangling below the player; slime droplets on thrusts; RED-font 16 crits; horizontal + vertical thrusts through the dummy rows; late demo: a charged launch that detonates in a yellow star burst at range.
- Motion: a spear that behaves like a living chain — thrusts read as the links stiffening, droplets raining off every poke, and the demo ends with some kind of charge-and-launch that explodes on a far platform target. (1.4.5 item; mechanics beyond the footage undocumented in our refs — measurements only.)
- Deepwood: the sticky pike idea — thrusts shed slowing slime droplets (our sticky debuff starter per the page scan), with a charge-release burst as its special; flag for re-check when 1.4.5 documentation matures.

### Trident
- 90f/2.7s. Gold trident ~2.3 PH, ornate three-prong head; 11-12 through both floor dummies per thrust; clean vertical up-thrust; ~1 thrust/0.6s; no particles.
- Motion: the Spear's rich cousin: longer, prettier, same grammar — line-pierce forward, skewer upward, the pronged head giving every pose a silhouette the plain spear lacks. (Its famous water-mobility utility isn't in this demo; the weapon side is pure fundamentals.)
- Deepwood: tier-2 spear — reach up ~15%, trident silhouette; carry the water-traversal utility from the page scan as its hidden second life.

### The Rotted Fork
- 77f/2.3s. Crimson barbed fork ~2 PH; BLOOD spray on every contact, victims visibly dripping afterward; 12-16s; one vertical thrust skewers TWO stacked platform dummies at once.
- Motion: the gore grammar: every poke is wet — red flecks jump off the wound, the impaled dummies keep shedding droplets between thrusts, and the vertical shot up a two-high dummy stack is the class's line-pierce turned 90°. Crimson identity carried entirely by fluid.
- Deepwood: the flesh pike — blood-particle contact language + 2-body vertical pierce; our crimson-flavored mid-tier spear.

### Swordfish
- 69f/2.1s. Blue swordfish ~1.6 PH (bill is half the length); 16-20s — strong for its tier; ~2 thrusts/s; both floor dummies per poke; zero effects.
- Motion: the joke that outperforms: a literal fish jabbed nose-first at double cadence, printing better numbers than the Trident above it. Silhouette comedy plus honest stats, no garnish — the fishing-rod jackpot made playable.
- Deepwood: the angler's pike — fishing-loot spear, fast cadence, fish silhouette; sits in the joke slot while quietly being the tier's DPS pick.

### Cobalt Naginata
- 308f/6.2s. Blue-steel naginata, shaft ~3 PH; a thrust bills all THREE floor dummies (27-30) with big-font 64 crits; vertical thrust runs up a 3-stack of platform dummies; ~2 thrusts/s — fast for its length.
- Motion: hardmode entry as pure geometry: the pole now spans the whole dummy row, so every input is a 3-body event both axes, at a cadence the pre-hardmode spears reserve for stubbier reach. Crit font doubles the drama at zero particle cost.
- Deepwood: ore-spear rung 1 — reach 3 PH + 3-target line-pierce + fast cadence; the hardmode handshake weapon.

### Adamantite Glaive
- 256f/5.1s. Crimson-red glaive ~3.5 PH; all three floor dummies at 32-43 per thrust; vertical column thrust 40-43 up the 3-stack; brisk cadence; white edge-flash at the tip on contact.
- Motion: rung two by pure extension: same both-axis line-pierce with another half-player of reach and a hot tip flash marking each contact point. The ladder's growth is legible as shaft length alone — the demo is Cobalt's demo, redder and longer.
- Deepwood: ore-spear rung 2 — reach 3.5 PH, tip contact flash; numbers up ~30%; nothing else changes (the restraint is the design).

### Titanium Trident
- 64f/1.9s. Silver-black pole ~3.7 PH with a pale CRYSTAL three-prong head (~0.5 PH, glowing gem prongs); 34-46 across all three dummies; stately ~1 thrust/0.8s; the ornate head visibly clears the far side of the last target.
- Motion: the ladder's crown pose: longest reach in the slice, slowest cadence, and a jeweled head so large it reads past the final victim like a standard being planted. Prestige through headgear + reach; still zero particles.
- Deepwood: ore-spear rung 3 — reach ~3.7 PH, slow heavy cycle, crystal-head sprite as the prestige tell; cap the pure-reach ladder here.

### Tonbogiri (1.4.5 — bonus find, wiki.gg)
- 98f/3.3s. Shaft ~3.5 PH, blue-violet ornate head; WHITE damage numbers 40-54 (new 1.4.5 style); a YELLOW TRIANGLE marker hangs over a chosen enemy; blue-white slash burst at the tip on hit; slain armored zombies DETONATE into bone/shrapnel showers flying ~3 PH; fought vs live enemies with HP bars.
- Motion: the legend-spear: thrusts land with a crystalline burst, one target wears a mark triangle (some targeting/priority mechanic on film), and kills don't slump — they burst into debris fountains that keep raining after the frame. The white number font alone signals a different era of the game.
- Deepwood: the named-relic spear idea — long thrust + marked-target bonus + detonating kills; treat as inspiration sketch (1.4.5 mechanics unverified), our "Dragonfly Cutter" cousin for the famous-weapon roster.

---
## CROSS-CUTTING MEASUREMENTS (wave-2 laws)
- THE STAT-RUNG LAW, PROVEN ON FILM: the 13-yoyo ladder is ONE rig re-skinned — orb size
  stays 0.25-0.3 PH and wander stays ±0.5-1 PH for five tiers while numbers climb 8→80;
  garnish enters in strict order: stacks (Rally) → status (Amazon) → crit font (Valor) →
  glow (Chik) → infinite dwell (Valkyrie). Claws obey the same law (Bladed Glove 10-14 →
  Fetid Baghnakhs 56-69, identical blur). Deepwood ladders should spend garnish this way —
  one new tell per rung, never two.
- ORE-SPEAR GEOMETRY LADDER: reach 2 PH (Spear) → 2.3 (Trident) → 3.0 (Cobalt) → 3.5
  (Adamantite) → 3.7 (Titanium); targets-per-thrust 2→3; the ladder is legible with zero
  particles. Vertical thrust is the spear class's exclusive verb in every demo — keep it ours.
- THE 10x VELOCITY LAW: both Jousting Lance skins print 6-14 standing vs 63-114 charging —
  the multiplier is the weapon; skins are free (Hallowed gold-flare vs Shadow violet-spark).
- AFTERMATH BUDGET: fire weapons spend their identity after the input — Flamarang's victim
  still ticks at 8.5s, Flaming Mace's dummies burn while the player idles, Shadowflame Knife
  runs three burn sites at once. Burn duration is the visible tier, not flame size.
- TRAIL GRAMMAR (rang family): none (Wooden) → confetti corridor (Enchanted) → snow ribbon
  (Ice) → spore curl (Shroomerang) → fire lane (Flamarang) → red smear multiples (Combat
  Wrench). The trail is the weapon's signature; the crescent sprite barely changes.
- JOKE-WEAPON RULE CONFIRMED AGAIN: Zombie Arm / Clubberfish / Ruler / Stylish Scissors ship
  ZERO particles on purpose (Ham Bat law) — while Waffle's Iron and Swordfish show the other
  joke pattern: absurd sprite, sincere (even superior) mechanics. Deepwood needs both kinds.
- 1.4.5 SIGNALS (from the two bonus GIFs): white damage font, mark-triangle targeting, kills
  that detonate into debris, charge-release specials on spears — worth a re-scan when the
  update's wiki documentation stabilizes.

STUDY COMPLETE: 54 weapons studied, 54/54 demo GIFs obtained (Flint recovered on retry;
Slime Spear + Tonbogiri are net-new finds neither wave had), ~8,600 frames surveyed via
8-keyframe contact sheets. Combined with wave 1: every verb-bearing melee weapon in the
reference now has a measured motion recipe.
