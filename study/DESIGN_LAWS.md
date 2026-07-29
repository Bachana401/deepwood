# THE DESIGN LAWS — what 355 measured weapons actually taught us
Synthesis of the seven GIF studies. These are the transferable rules; the
per-weapon recipes live in the `gif_*.md` files beside this one. Unit
throughout: **PH / PL = one player-height ≈ 48px in demo footage.**

---

## 1. THE STAT-RUNG LAW (the single most useful finding)
Proven on film across 8 sampled ladders (24 rungs) and the 13-rung yoyo
ladder: **a stat ladder is ONE animation rig re-skinned.** Silver and
Platinum broadswords share the literal same demo rig; Hallowed's arrow is
visually identical to Cobalt's at 3.3x the damage; yoyo orb size stays
0.25-0.3 PH and wander stays ±0.5-1 PH across five tiers while numbers climb
8 → 80.

And the garnish enters in **strict order, one new tell per rung, never two**:
stacks → status → crit font → glow → infinite dwell.

> **Deepwood law:** plain ladders cost almost nothing to build and are
> honest, provided each rung adds exactly ONE new tell. Spend the animation
> budget on the weapons that carry a verb.

## 2. SIZE, SPEED, CADENCE — the calibration constants

**Projectile speed bands** (melee-thrown, but they generalize):
- 0.3-0.4 PH/frame — glide crescents. Reads as *inevitability* (Death Sickle).
- 0.5-0.7 — stately waves (Flying Dragon, Chlorophyte orb).
- ~1.0 — the standard bolt (Terra beam, Influx, Enchanted).
- 1.0-1.5 — fast bolts (Beam Sword). Beyond this it stops reading as an object.

**Aura ladder** (melee swing auras): 3-3.5 PH disc → 4 PH + a detaching
traveling copy → ~5 PH double-layer → and at the crown the aura is *traded
away* for an every-swing screen-crossing beam (22 PH). Auras live 5-6 frames
(~100-120ms) and multi-hit everything inside once.

**Cadence identities:** flurry 12-15 hits/s · standard attack 1-1.5s ·
heavy one swing per 0.5-0.8s · frenzy ramps *double* the swing rate.

**Reach by family:** yoyo dwell 2.2-3.9 · flail hold-spin 0.8-1 · flail
launch 4.5-7.3 · boomerang 4.5-10 · spear thrust 1.6-8 · flurry shell
0.8-1.2 · whips 2 (starter) → 13+ (crown, screen-edge to screen-edge).

**Ranged:** tracers 0.4-0.6 PH (hose) → 1 (burst) → 2-2.5 (velocity-identity
streak) → full-lane (sniper). Blasts 1.5-2 (bomblet) → 2-2.5 (rocket) → 3
(mine/grenade) → 4 (crown firework). Hose rate ladder 6-7/s → 8 → 10 → 15,
per-hit damage compressing as rate climbs.

**Summons:** minion body 0.25 PH (cell/finch) → 0.5 (UFO, dragon segment) →
0.85-0.9 (pirate, adult tiger). Sentry reach ~1 (trap trigger) → 4-5
(turret) → 8-10 (full-lane pierce/sweep).

## 3. THE CROWN RULE
**The top rung goes CLEANER, not busier.** The endgame hose (S.D.M.G.) is
tidier than the mid-tier spray; Terra Blade drops its giant aura for one
clean beam. Escalation is *clarity plus reach*, not more particles — the
opposite of the instinct to pile on effects at high tiers.

## 4. AFTERMATH IS THE SECOND HALF OF EVERY GOOD VERB
Damage that outlives the input, with measured lifetimes: poison field 4-6s ·
planted blade trap 5-8s · burn columns · frost bank 2s+ · spore cloud 1-2s ·
hanging ornaments ~2s · embedded barbs (stacking) · fire patches 5-8s ·
electro sphere 5s · held flame column 7-8 PH.

**Burn DURATION is the visible tier, not flame size** — a low-tier fire
weapon and a high-tier one look alike at the moment of impact; the
difference is that the victim is still ticking eight seconds later.

## 5. DELAYED PAYOFF TIMINGS (the "plant then harvest" family)
Measured: bubble pop 0.5s · onyx orb 0.6s behind its pellets · nail pop 1.5s
at ~8x the embed damage · mines indefinite until triggered. The pattern:
a small immediate hit, then a large scheduled one — and the *waiting* is
legible on screen (stuck nails, floating bubbles, armed mines).

## 6. THE TRAIL IS THE SIGNATURE
Across the boomerang family the crescent sprite barely changes; identity
lives entirely in the trail: none → confetti corridor → snow ribbon → spore
curl → fire lane → red smear multiples. Same for swords: 1.5 PH dotted →
2 PH sparkle → full-path confetti → 8 PH bouncing rainbow.

> **Deepwood law:** to differentiate two weapons cheaply, change the TRAIL,
> not the projectile body.

## 7. NUMBER THEATER
Terraria treats the damage numbers themselves as spectacle: flurry
number-clouds, execute deltas (92 → 228 on a wounded foe), opener deltas
(189 → 63 once the target is hurt), pierce-decay staircases, DoT metronomes,
multi-projectile clusters rendering as a *ragged burst of small numbers*
rather than one clean hit. Our floating-damage numbers should be tuned as
part of each verb's look, not treated as UI afterthought.

## 8. GEOMETRY RULES THAT MUST NOT BE VIOLATED
From the guardrails each study derived:
- **Spear riders spawn at the APEX of the thrust**, never at the player.
- **Flail launches damage along the whole chain**, not just the head.
- **The boomerang RETURN pass pierces** even when the outbound doesn't.
- **Yoyo dwell wander ≥0.5 PH** or the orb reads dead.
- **Sky-rain** spawns above the camera, ±1.5 PH jitter around the aim,
  8-15° tilt, ~0.4-0.5s to cross the screen — and whether it respects roofs
  is the entire balance dial of the family.
- **Vertical thrust is the spear's exclusive verb** in every demo.

## 9. THE PLAYER-STATE MULTIPLIER
The Jousting Lance prints 6-14 standing and 63-114 charging — a **10x swing
from the player's own velocity.** Both skins share it; the multiplier IS the
weapon and the skin is free. Same family: food tier, stillness, missing HP,
target health. These read as skill because the player controls the input.

## 10. THE TWO JOKE PATTERNS (both are load-bearing)
- **Zero particles on purpose** — Zombie Arm, Clubberfish, Ruler, Stylish
  Scissors. The absence *is* the joke.
- **Absurd sprite, sincere mechanics** — Waffle's Iron, Swordfish: silly
  object, genuinely good weapon.
And a third lane worth keeping distinct: **intentional non-weapons** (Water
Gun with no damage numbers at all, Paper Airplanes hitting for a flat "1").
A roster needs all three or it reads humorless.

## 11. PIERCE HAS TWO DISTINCT FAMILIES
**Even-pierce** (one shot threads 2-3 targets for equal damage each) versus
**stepped-falloff pierce** (each body takes a cut). They feel completely
different and should be assigned deliberately, not by default.

---

## HOW TO USE THIS
Designing a Deepwood weapon: pick the VERB first (from the scan digests in
WEAPON_VERB_REFERENCE.md), then read that weapon's measured recipe in the
`gif_*.md` file, then set numbers from the calibration constants above —
sizes in player-heights, cadence from the identity bands, aftermath lifetime
from §4. Stats last, 1-5 by rarity. Similar, never 1:1 — motion recipes
rebuilt procedurally in our own palette, never copied pixels.
