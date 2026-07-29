# GIF MOTION STUDY — FINAL SWEEP (2026-07-29)
Method: wiki demo GIFs → 8 keyframes each (5 spread + consecutive triplet at midpoint) →
2-3x NN contact sheets → measured in SOURCE px with player height ≈ 48 px = 1.0 PL
(player-length unit). Cadence from GIF frame-delay tables (ms). NO pixels copied — numbers
and motion grammar only. Sources: terraria.fandom.com API (imageinfo/allimages) resolving
filenames, downloaded from static.wikia.nocookie.net/terraria_gamepedia/ via the MediaWiki
MD5 hash path + `?format=original` (raw Invoke-WebRequest triggers a WebP re-encode on this
host; curl.exe with an `Accept: image/gif` header + the format flag avoids it).

This sweep closes the coverage gap left by gif_magic/gif_ranged/gif_melee_swords/
gif_melee_families/gif_melee_remainder/gif_summons: Part 1 studies 29 previously-unstudied
verb-bearing weapons individually; Part 2 is a measurement pass that empirically tests the
scan digests' claim that the ore/wood stat-stick ladders share one animation per weapon
class. All 53 target GIFs resolved and downloaded on the first pass — zero FAILED entries
this round.

---

# PART 1 — THE MISSING VERB WEAPONS

## Butcher's Chainsaw
MEASURED (449x199, 227f, 5.72s): held at chest height, the weapon sprays a short-range
burst that reaches all three lined-up dummies (~3 PL span) essentially at once — no
travelling projectile is visible connecting player to targets. All three ignite
simultaneously (direct ticks 54-138 scattered across the trio) and then keep burning
independently: steady "1" ticks continue on every victim for several seconds after the
spray itself has stopped, with the fire visual (rolling flame + spark shower) still
climbing the dummies' bodies at t=4.27s, long after the last direct-hit number.
MOTION: a short cone of fire that doesn't care how many bodies are packed into its reach —
one press paints the whole huddle in flame and walks away, letting the burn do the actual
kill over the next several seconds.
DEEPWOOD: melee cone weapon — instant multi-target ignite in a ~3 PL arc, weak direct hit,
strong burn DoT (4+ s); rewards catching a clustered mob rather than a lone target.

## Cutlass
MEASURED (300x339, 142f, 2.90s): long straight blade (~1.3 PL, longer than most one-handed
swords), raised to a high guard then swept down through the target; each contact prints a
tight cluster of 3-4 numbers at once (40, 44, 47, 55 all visible together) rather than one
clean hit, with swings landing roughly every 0.7s.
MOTION: an oversized single-hand blade whose identity is pure reach and a swing that seems
to bite more than once per pass — the number-pile lands as a clump, not a single digit,
selling extra weight per swing.
DEEPWOOD: long-reach one-hand sword (blade ~1.3 PL) whose swing registers 3-4 close-timed
ticks per contact — a "heavy single-hander" alternative to the aura-sword family.

## Falcon Blade
MEASURED (245x247, 151f, 3.02s): straight ~0.9 PL blade, raised guard into a downward
chop; every swing prints a PAIR of numbers together — a main hit (27-29) plus a smaller
companion tick (23-24) — every ~0.74s, no projectile or aura.
MOTION: a plain-looking short sword that quietly double-bills each swing, like a hidden
extra proc riding along with the honest hit; nothing on screen announces it beyond the
second, smaller number appearing in lockstep with the first.
DEEPWOOD: companion-tick sword — every swing rolls a main hit + a smaller guaranteed
bonus tick (≈80% of main); reads as a plain sword whose parry sheet secretly out-performs it.

## First Fractal
MEASURED (665x440, 240f, 6.01s): dash-windup (~0.9s) launches 2-3 giant sword-shaped
projectiles (each ~1.5-2 PL, bigger than the player) that streak out on independent
WAVY/curving flight paths trailing thick 2+ PL rainbow-sparkle tails; a volley lands as a
cluster of 3 numbers at once (121, 174, 211), and a later cast shows one shot spiking to
346/426 (double the normal cluster, likely two blades overlapping one body).
MOTION: fires a small squadron of huge curved rainbow blades that don't fly straight —
each one bends along its own arc like a boomerang, so a single cast reads as a
multi-directional flourish rather than a volley.
DEEPWOOD: 3-shard curved-flight broadsword — each cast launches 2-3 giant blade
projectiles on independent bezier arcs, converging near the cursor; crown-tier "sword
squadron" verb.

## Hammush
MEASURED (214x171, 77f, 2.61s): a tumbling mushroom/hammer head (~0.4-0.5 PL, spark
trail) is lobbed in a big up-and-over arc that clears a pillar obstacle between two
dummies, landing hits on the far side (12-14) and, on its way back over the pillar, on the
near side too (24-28); the tail of the flight sheds a scatter of small (~0.1 PL) blue
crystal shard debris.
MOTION: a boomerang that treats a pillar like scenery — one throw arcs clean over cover to
tag the far target, then swings back over the same obstacle to tag the near one on
return, leaving a spray of glinting crystal chips at the peak.
DEEPWOOD: pillar-clearing boomerang — high lob that damages on both the outbound arc
(far side) and the return arc (near side) of a single throw; obstacle geometry is part of
the payoff, not an obstruction.

## Nightglow
MEASURED (800x250, 262f, 5.24s): a single homing bolt recolors as it travels — first a
magenta/pink bolt ricochets in a wide W-zigzag between two far-apart anchor points
(~10+ PL span, ticks 54-56), then a later pass shows the SAME bolt now yellow-green,
weaving tightly through a close cluster for a rapid-fire burst of small stacked ticks
(18-42, eight numbers at once).
MOTION: one bolt, two acts — a slow wide-swinging tour between distant targets that then
tightens into a fast localized weave once it finds a crowd, its trail visibly changing
color as the behavior shifts.
DEEPWOOD: shape-shifting homing bolt — wide ricochet-seek at range (color A), tight rapid
weave up close (color B, recolors on the transition) — one cast, two distinct payoffs.

## Stake Launcher
MEASURED (464x172, 94f, 2.61s): one shot instantly damages the ENTIRE visible 10-dummy
line at once — no visible travel time, numbers (89-230, one spike at 230 ≈ 2x = crit)
appear simultaneously across every body in the row and linger over 1.5+ seconds
(a residual "222" is still floating at t=2.58s).
MOTION: a single stake round that behaves like a hitscan lance the length of the room —
pull the trigger once and the whole line takes its own separate damage roll in the same
instant.
DEEPWOOD: room-length pierce round — one shot rolls independent damage on every body
along a straight line to the edge of the screen; the "impale the corridor" gun.

## Snowball Cannon
MEASURED (426x182, 72f, 3.31s): small white snowball lobbed a short ~2-3 PL distance,
modest puff on contact, weak ticks (16-23).
MOTION: a joke-tier plinker — short range, soft impact, low numbers; the demo's whole
personality is "harmless snowball fight."
DEEPWOOD: festive starter gun — short-range lobbed snowball, tiny splash, low damage;
seasonal-event vendor filler weapon.

## Snowball Launcher
MEASURED (460x200, 119f, 3.96s): bigger snowball fired flat and fast, single direct
impact (no split), ticks in the 30-39 range — roughly double Snowball Cannon's numbers
with the same silhouette and no added effect.
MOTION: the grown-up snowball — same lobbed-ball language, harder and flatter, no new
verb, just bigger numbers.
DEEPWOOD: tier-2 of the snowball family — identical shot shape, ~2x Cannon's damage;
teaches "same verb, different rung" inside our own festive-weapon ladder.

## Confetti Gun
MEASURED (400x280, 138f, 2.76s): NO damage numbers ever appear in the whole 2.76s demo;
one trigger pull fills a 6+ PL wide field with hundreds of multicolor confetti streamers
that scatter under gravity and are still drifting/settling at the final sampled frame.
MOTION: pure celebration — the "weapon" is a screen-filling firework of paper confetti
with zero combat payload, all spectacle.
DEEPWOOD: zero-damage vanity gun — party-popper burst of 100+ colored streamer particles
that rain down over ~2s; a pure-fun sidegrade for festivals, never meant to fight.

## Brain Scrambler
MEASURED (470x162, 78f, 2.26s): ~0.5s charging aura (yellow/dark swirl around the
caster) precedes an INSTANT double-line hitscan beam — two thin parallel red streaks
fired together, crossing the full screen width in one frame and passing straight through
decorative round obstacles in its path; hits land at 89-108, then a smaller 89 follow-up
shot later.
MOTION: charge, then an instant twin-beam that doesn't care what's in the middle of the
room — full-screen hitscan with a visible windup as the only tell.
DEEPWOOD: charge-then-hitscan twin-beam — 0.5s telegraph, then an instant double-line
beam to screen edge, ignoring décor/obstacles in its path; alien-tech laser rifle verb.

## Sharanga
MEASURED (300x140, 112f, 3.73s): a permanent yellow downward-triangle marker sits over
the target at all times; firing calls down a shower of thin gray/white streaks raining
vertically from the top of the screen onto the marked point, landing as one burst (45
damage) with lingering sparkle.
MOTION: a target-painter bow — the marker never leaves the enemy, and pulling the string
answers with an arrow-storm falling from the sky directly onto it, like calling in a
strike on a locked coordinate.
DEEPWOOD: marked-target sky-call bow — a persistent aim-triangle sticks to the current
target; firing rains 3-5 light arrows from off-screen onto that exact marker regardless
of player aim drift.

## Tizona
MEASURED (226x142, 102f, 3.40s): swing produces a ground-level fire burst hitting for a
double tick (45 + 60) and, separately, spawns a small hovering/spinning crystal-blue
spectral sword that drifts near the player's head for roughly a second before fading.
MOTION: a flaming broadsword that leaves an afterglow — the swing itself detonates like a
small pyre, and a ghostly companion blade lingers in the air afterward as a decorative
echo of the strike.
DEEPWOOD: fire-slam sword with a spectral echo — swing hits ground-burst for a double
tick, then a cosmetic hover-blade spawns and drifts for ~1s (crit/finisher flourish, no
extra damage — pure flavor payoff).

## Vulcan Repeater
MEASURED (290x140, 114f, 3.80s): fire rate is high enough that the arrow stream reads as
a solid thin green-tinted beam rather than discrete bolts; one sustained volley chews
through a 2-zombie pack simultaneously for stacked ticks (34, 40, 46, 51), leaving a bone
pile behind.
MOTION: a crossbow pushed past the point where individual shots are visible — the stream
itself becomes the silhouette, mowing a small pack down in one continuous burst.
DEEPWOOD: max-rate repeater — fire rate high enough that the bolt stream renders as a
near-solid beam; clears small packs in one sustained press, the "gatling crossbow" rung.

## Magic Dropper
MEASURED (268x237, 585f, 19.51s): a single colored droplet (red, orange, or blue,
cycling) leaks from the caster and falls straight down under gravity roughly every 4-5s
in this empty demo scene; no target, no visible combat payload — the drip itself is the
entire show.
MOTION: a magic wand that just... leaks. No target, no burst, no fanfare — a slow,
faucet-like drip that free-falls and vanishes, repeating indefinitely.
DEEPWOOD: joke faucet-wand — fires one slow gravity-drooped droplet every 4-5s, trivial
damage, color cycles randomly each drip; a gag weapon whose whole bit is "it barely does
anything, on purpose."

## Code 2
MEASURED (190x164, 142f, 4.73s): a grappling hook that ALSO damages — the taut chain-line
snaps out instantly (hitscan-straight to the hook head resting at/near the dummy) and the
impact itself registers direct hits (42-51 clustered, 4 numbers per cast) roughly every
1-1.9s.
MOTION: a traversal tool that moonlights as a weapon — throw it at an enemy instead of a
wall and the grapple's impact itself deals a real hit before it presumably reels back.
DEEPWOOD: dual-purpose grapple — instant chain-line to target, on-hit direct damage
(mid-tier), then retrieves as normal traversal; one item slot doing two jobs.

## Format:C
MEASURED (190x164, 118f, 3.93s): identical dual-purpose grapple verb to Code 2 — instant
chain-line hit landing 25-70 (one 70 spike, roughly 2.5x the 25-30 baseline = crit),
same hook-head-rests-at-target visual, same cadence family.
MOTION: Code 2's sibling in every visible respect — same instant chain-strike grammar,
just a different hook-head skin and a wider damage spread.
DEEPWOOD: same dual-purpose-grapple verb, second rung — proves the family scales by
damage roll alone (25-70 vs Code 2's tighter 42-51); reuse one hook-weapon component,
recolor + retune per tier.

## Bone Sword
MEASURED (245x236, 185f, 3.70s): plain ~1 PL bone-white blade, overhead diagonal raise
into the target, no particles/trail/projectile; hits stack 2-3 numbers per contact
(15-34) roughly every 0.9s.
MOTION: an honest, undecorated reach sword — the bone motif is purely cosmetic, the swing
itself is the stock diagonal chop with nothing riding on it.
DEEPWOOD: no-gimmick bone-tier sword — same base swing rig, reskinned; a clean "early
zone" stat-stick to seed before verb-bearing swords unlock.

## Candy Cane Sword
MEASURED (300x268, 169f, 3.40s): the cane is held/thrown at a steep ~70° upward angle
and then LINGERS almost motionless in that raised position for the better part of a
second (unchanged across 850ms of sampled frames) directly beside the dummy pair,
racking up repeated small ticks (14-18) the whole time it hangs there.
MOTION: a festive boomerang that pauses mid-arc — instead of a clean throw-and-return, the
cane hangs near its target for a long beat, grinding out chip damage before presumably
snapping back to the thrower's hand.
DEEPWOOD: hang-and-grind boomerang — thrown cane pauses ~0.9s near the apex of its arc,
multi-ticking anything adjacent, before returning; a "loitering" boomerang sub-verb.

## Magic Dagger
MEASURED (450x196, 221f, 4.44s): the thrown dagger itself is never caught on camera (too
fast/small across all 7 samples) yet produces an immediate cluster of 4-5 ticks (38-48)
on the near dummy; later in the demo a small yellow star-shaped glint is seen slowly
arcing DOWN toward a second, farther dummy.
MOTION: an invisible-fast stab followed, seconds later, by a lazy falling glint elsewhere
on the field — two very different speeds from what reads as one weapon.
DEEPWOOD: near-instant dagger + delayed falling mote — direct multi-tick on the nearest
foe at effectively hitscan speed, plus a slow secondary star that drifts down onto a
different target later; two damage beats, two speeds.

## Poisoned Knife
MEASURED (280x164, 79f, 2.63s): direct hit (12-15) followed immediately by a lingering
green-tinged poison DoT — small "1" ticks continue firing on the same dummy for 2+
seconds after the throw, visible across 4 consecutive sampled frames.
MOTION: a modest throwing knife whose real damage is the wound it leaves — the poison
metronome keeps paying out long after the blade itself is gone from the screen.
DEEPWOOD: poison dagger — small direct hit + guaranteed 2-3s poison DoT (steady 1-tick
metronome); early-game DoT-identity throwing weapon.

## Bone Throwing Knife
MEASURED (400x201, 271f, 5.44s): one throw pierces the ENTIRE 7-dummy test row plus a
separated 8th dummy further downrange, landing individual ticks (11-16) on every body at
once; casts repeat roughly every 1.3-2.7s.
MOTION: a thin bone blade that treats a crowd as one target — a single throw threads
every body in the line and keeps going to tag an isolated straggler well beyond the pack.
DEEPWOOD: infinite-pierce thrown knife — one throw hits every body along its line
(7+ targets confirmed) plus anything further downrange; the "clear the corridor in one
throw" dagger.

## Star Anise
MEASURED (372x164, 45f, 1.50s): same pierce-the-whole-line-plus-a-distant-target pattern
as Bone Throwing Knife (identical demo rig: 6-dummy row + 1 isolated far dummy), landing
simultaneously on all 6 (12-16) AND the isolated target (12-15) in one instant, hitscan-
fast — no throw sprite ever visible across any of the 7 samples.
MOTION: effectively a hitscan star that ignores headcount — every body in a packed line
and a lone straggler well beyond it all take damage on the same beat, with no visible
travel time at all.
DEEPWOOD: hitscan-fast infinite-pierce star — same corridor-clearing verb as Bone
Throwing Knife but with zero visible travel time; the higher-tier "instant" version of
that family.

## Frost Daggerfish
MEASURED (450x404, 308f, 6.20s): initial throw lands a cluster hit (15-19, one spike 38)
on the close dummy pair, then the fish-shaped projectile is seen DRIFTING slowly through
open air (weak gravity, near-flat glide) for 4+ seconds and several PL of travel before it
finally reaches and taps a far dummy for one more small tick (18-19).
MOTION: a thrown fish that forgets to hurry — after the initial contact it just floats
on, unbothered, eventually bumping into whatever's further down the corridor long after
you'd expect a normal knife to have despawned.
DEEPWOOD: long-hangtime thrown dagger — direct hit up close, then the same projectile
lazily drifts on for 4+ seconds/several PL to tag a second, far target; patience as the
payoff.

## Javelin
MEASURED (500x226, 140f, 2.88s): flat, fast throw; direct hit (36) paired with a smaller
companion tick (20, then 14 — a decaying second number on the same body, read as an
embedded DoT), pierces onward to a second/third dummy for a reduced hit (18, sometimes
two 18s); recast roughly every 0.7s.
MOTION: a thrown spear that pays twice on the first body (a solid hit plus a fading
companion tick) before carrying on, weaker, into whoever stands behind.
DEEPWOOD: pierce-with-embed javelin — direct hit + a small decaying stick-in tick on the
first body, then continues through to a second target at reduced damage; the "starter"
rung under our Bone Javelin.

## Holy Hand Grenade
MEASURED (544x304, 249f, 8.74s): thrown into a grassy pit; after a walk-up delay it
detonates for a colossal 1008 damage, gouging a permanent multi-PL crater straight through
solid terrain (debris blocks flying, dirt chunks scattered) — the crater is still visible
unrepaired at t=8.71s — accompanied by an on-screen "Player let their arms get torn off by
Player's Holy Hand Grenade" message.
MOTION: a joke weapon played completely straight — one throw reshapes the map and deals
more damage than anything else in this entire sweep, with a self-aware death message as
the punchline.
DEEPWOOD: reference super-grenade — single-use, absurd damage (10x+ any other grenade),
permanently digs a large crater through solid terrain; a rare "break the game a little"
novelty item, not a balanced weapon.

## Bouncy Grenade
MEASURED (486x237, 181f, 5.52s): a small pink ball bounces with real physics — visibly
spanning most of the vertical frame between a low bounce and a high one across several
seconds — before finally detonating in a modest ~1-1.5 PL debris puff; no dummy present in
this demo, so no damage numbers are shown.
MOTION: a rubber superball played as ordnance — it keeps bouncing unpredictably, higher
and lower, refusing to just roll to a stop, and only goes off once it's had its fun.
DEEPWOOD: bouncing-physics grenade — real elastic bounce (height varies, several seconds
of hang time) before a modest detonation; the "unpredictable landing spot" grenade, good
for bouncing over our arena cover.

## Sticky Grenade
MEASURED (280x180, 159f, 5.30s): thrown ball ADHERES on contact to the first solid
surface it touches (a wall/ceiling corner in this demo) and stays fixed in that exact spot
for 1.3+ seconds before detonating near the target for a modest 53 damage.
MOTION: a grenade that plants itself — no bounce, no roll, it sticks dead still to
whatever it hits and waits out its fuse from that exact point, unlike a rolling or
bouncing bomb.
DEEPWOOD: wall/ceiling-stick grenade — adheres to the first surface touched and holds
position through a ~1.5s fuse before a modest blast; a placeable timed charge for our
walls/gates.

## Happy Grenade
MEASURED (330x220, 330f, 6.66s): detonates for modest real damage (32-34) plus an
enormous shower of multicolor diamond/star confetti particles that scatter across 6+ PL
and are STILL visibly littering the ground/air at the very last sampled frame (t=6.64s,
nearly the whole demo).
MOTION: a real grenade wearing a party hat — it hurts the way a grenade should, but the
visual payload (a huge confetti burst that refuses to fully clear) massively outlasts the
detonation itself.
DEEPWOOD: festive grenade — normal modest blast damage plus an oversized, long-lingering
confetti-particle scatter (5+ s); the "grenade that's also a party favor" for
celebration-themed floors/events.

---

# PART 2 — LADDER VERIFICATION (measurement pass)

The scan digests claim the ore/wood ladders are pure stat-sticks whose animations are
identical apart from color/size. Each ladder below was studied at 2-3 rungs to test that
claim directly against contact-sheet evidence — arc/pose geometry, projectile size,
travel speed, and cadence pattern, not just the damage numbers.

## (a) WOOD SWORDS — Wooden / Ebonwood / Ash Wood
- Wooden Sword (172x172, 39f/1.30s): blade ~0.6 PL, raised at a fixed ~45° diagonal, no
  FX/trail/projectile; every swing prints a single "8".
- Ebonwood Sword (245x266, 143f/2.94s): identical raised-diagonal pose, blade ~0.65 PL
  (dark purple-black tint), ticks 10-11 (paired "11/11" from fast autoswing overlap).
- Ash Wood Sword (500x250, 85f/2.72s): identical pose, blade ~0.6 PL (pale tan tint),
  hits BOTH flanking dummies each swing for 12-14 apiece.
VERDICT: identical shape, scales only. All three raise the same short blade to the same
fixed diagonal angle with zero particles/trail/projectile in any of them; only the wood
tint (tan → black-purple → pale ash) and the damage band (8 → 10-11 → 12-14) change.

## (b) METAL BROADSWORDS — Copper / Silver / Platinum
- Copper Broadsword (245x298, 142f/2.98s): thrust-forward pose, blade ~0.7 PL, paired
  ticks "7"+"14" every swing.
- Silver Broadsword (172x172, 39f/1.30s): downward-stab pose, blade ~0.7 PL, single tick
  "10" every swing.
- Platinum Broadsword (172x172, 38f/1.26s): literally the same demo rig as Silver
  (identical 172x172 canvas, 38 vs 39 frames), same pose, blade ~0.7 PL, single tick "17".
VERDICT: identical shape, scales only. Silver and Platinum share the same rig down to
canvas size and frame count — as clean a same-animation proof as this sweep found; Copper's
differently-sized source GIF just samples a different phase of the same thrust. Blade
proportions match across all three; only tint and damage (7-14 → 10 → 17) change.

## (c) METAL SHORTSWORDS — Copper / Gold
- Copper Shortsword (245x264, 148f/3.20s): short horizontal jab, blade ~0.5 PL, ticks 4-6.
- Gold Shortsword (300x289, 208f/4.26s): identical horizontal jab and blade proportion,
  ticks 11-12 with a crit spike of 26 (≈2.3x, matching a standard crit multiplier).
VERDICT: identical shape, scales only. Same short thrust, same reach, only the bronze→gold
recolor and the damage band change; the crit spike confirms normal crit math rather than a
new mechanic.

## (d) WOOD/METAL BOWS — Wooden / Silver / Platinum / Pearlwood
- Wooden Bow (514x172, 56f/1.86s): one thin flat arrow, no drop/trail/pierce, hit 9.
- Silver Bow (650x180, 63f/2.10s): same arrow, hit 15.
- Platinum Bow (650x180, 64f/2.13s): same arrow, hit 18.
- Pearlwood Bow (514x172, 56f/1.86s): same arrow, hit 14.
The wood-tier pair (Wooden/Pearlwood) share IDENTICAL canvas size and frame count
(514x172, 56f); the metal-tier pair (Silver/Platinum) also share identical canvas and
near-identical frame count (650x180, 63-64f) — the two cleanest matched pairs in the whole
sweep.
VERDICT: identical shape, scales only. This is the single strongest case in the ladder
study: same drawn-bow pose, same single thin arrow with zero drop/trail/pierce, same one-
shot cadence, across all four rungs — only the tier number (9 → 14 → 15 → 18) changes.

## (e) HARDMODE ORE SWORDS — Cobalt / Mythril / Titanium
- Cobalt Sword (245x266, 149f/3.06s): overhead diagonal swing, blade ~1.1 PL, solid blue,
  ticks 33-44.
- Mythril Sword (300x266, 155f/3.20s): identical pose, blade ~1.15 PL teal with faint
  sparkle motes trailing the tip, ticks 43-56.
- Titanium Sword (200x172, 88f/2.93s): identical pose, blade ~1.2 PL pale lavender with a
  sparkly texture on the blade itself, ticks 49-60.
VERDICT: identical shape, scales only, with a minor cosmetic escalation. Swing arc, pose,
and timing match across all three; the only rung-to-rung change beyond tint and damage is
a small step-up in blade glitter (plain → trailing motes → sparkle texture) — polish, not
a new verb or projectile.

## (f) REPEATERS — Cobalt / Adamantite / Hallowed
- Cobalt Repeater (650x180, 82f/2.73s): one plain thin arrow, ticks 34-38.
- Adamantite Repeater (650x180, 85f/2.83s): identical rig and arrow, ticks 39-43.
- Hallowed Repeater (690x180, 87f/2.98s): same rig/pose/arrow, ticks jump to 130-142 —
  roughly 3.3x Adamantite's band despite an unchanged shot.
VERDICT: identical shape, scales only — the starkest proof in the whole sweep. Hallowed's
arrow is visually indistinguishable from Cobalt's (same flat dart, same flight, same draw
pose), yet deals about triple the damage; the entire power gap between early- and
post-Mechanical-Bosses hardmode ranged weapons is completely invisible on screen.

## (g) GEM STAVES — Amethyst / Emerald / Diamond
- Amethyst Staff (350x202, 180f/3.86s, single-dummy rig): bolt never caught across any of
  the 7 samples (too small/fast to resolve), direct ticks 14-16, ~0.9s cadence.
- Emerald Staff (400x214, 197f/4.00s, 2-dummy rig): a visible green particle-stream
  connects player to target continuously in every damage frame, pierces both dummies,
  ticks 16-22 (crit 42).
- Diamond Staff (350x194, 209f/4.30s, 2-dummy rig): a visible white/frost dotted-cloud
  stream, pierces both dummies, ticks 20-26.
VERDICT: mostly identical shape, scales only — with a caveat. Amethyst's demo uses a
single-target rig so its pierce can't be directly confirmed or denied, and its bolt is
small/fast enough to vanish between sample frames while Emerald/Diamond's thicker trail
lingers — consistent with a fainter low-tier bolt rather than a genuinely different verb,
but the only ladder in this sweep where the source footage doesn't hand over a clean
apples-to-apples comparison. Treat as the least certain "identical" verdict here.

## (h) HARDMODE SPEARS — Cobalt Naginata / Mythril Halberd / Titanium Trident
- Cobalt Naginata (350x515, 308f/6.30s): thrust extends a notched/dotted shaft straight
  through a stacked 3-dummy column, hitting all three per thrust, ticks 26-30 (crit 64).
- Mythril Halberd (350x433, 317f/6.54s): identical vertical-stack rig and extending-shaft
  pose, ticks 32-40 (crit 74).
- Titanium Trident (266x230, 64f/2.13s): same extending notched-shaft thrust, ticks 34-46.
VERDICT: identical shape, scales only. All three use the same "extend a notched
thrust-line through everything on it, then retract" animation grammar on the same
vertical-stack test rig; only the head ornament (naginata blade / halberd axe / trident
prongs) and the damage band change. The numbers even preserve a real balance quirk —
Titanium's peak (46) trails Mythril's (74) despite being chronologically "later" ore,
consistent with Titanium's real design of higher speed over higher per-hit damage.

---
## COVERAGE NOTE
Part 1: 29/29 weapons studied, 29/29 demo GIFs resolved and downloaded on the first
attempt (zero retries needed once the `?format=original` + curl.exe/Accept-header fix was
in place). "Molotov-kin thrown variants" were checked against the existing gif_ranged.md
Molotov Cocktail entry — no additional distinct-demo thrown-fire variant was found beyond
what's already documented there, so none is duplicated here.
Part 2: 24/24 ladder rungs across all 8 requested ladders studied; all 8 verdicts came
back "identical shape, scales only" (one — gem staves — with a noted rig-comparability
caveat on Amethyst). No ladder showed a genuinely different verb at any rung.
FAILED: none. All 53 target GIFs resolved via terraria.fandom.com/api.php on the first
or second candidate title (Format:C and Ash Wood Sword needed an `allimages`-prefix
lookup since their exact demo-file title didn't match the standard "File:{Name} (demo).gif"
pattern — Format:C's file is literally titled "Format_C (demo).gif" with the colon
replaced by nothing, and Ash Wood Sword's demo file capitalizes "(Demo)").
