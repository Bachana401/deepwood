# VISUAL FIDELITY PUNCH-LIST — the crown ten vs their measured sources
Dev asked (2026-07-29) that the after-effects LOOK close to the reference.
The recipes were measured before building; this is the pass that checks the
BUILT thing against them, which had not been done. Each item is a real gap,
with the measurement that proves it.

## 1. THE FINAL EDICT vs Solar Eruption — blooms must DAMAGE
Measured: "EVERY pass spawned explosion bursts on all three dummies spread
across ~9.5 PH — hit points erupt BEYOND the visible lash (AoE procs)".
Built: `_edict_bloom()` is decoration only. The explosions in the source are
damage that reaches past the arm; ours reach nothing.
FIX: bloom deals a small AoE tick (~35% of the lash hit) in a short radius,
so bodies NEAR the arm are caught, not only bodies on it.

## 2. REGICIDE vs Daybreak — the spear has no trail, the pop is too small
Measured: "~2.5 PH flame streak" behind each thrown javelin; "~1.5 PH
diameter ring blast when a stack pops".
Built: `_build_crownspear()` has glow/shaft/head/fletch and NO streak, and
the overflow ring scales to roughly a third of the measured diameter.
This breaks our own law (DESIGN_LAWS 6: THE TRAIL IS THE SIGNATURE).
FIX: add a tapering additive streak behind the spear; grow the pop ring.

## 3. THRONE OF EMBERS vs Flower Pow — the chain must bite
Measured: "chain hits everything along its length (3 dummies at once:
146/133/113)".
Built: the rope is a Line2D drawn between wielder and head; it deals
nothing. This breaks the guardrail written in our own DESIGN_LAWS 8:
"flail launches must damage along the whole chain, not just the head."
FIX: while the head is out (hurl/seated), damage bodies within a band of
the wielder->head segment on a re-hit timer, as the edict does.

## 4. A SMALL PERSONAL SUN vs Last Prism — the column reads thin
Measured: six beams at 0.08 PL (4px) each, fanned 55-60 deg TOTAL, that
CONVERGE by ~2.9s into ONE beam 0.8 PL (38px) wide, white core, rainbow
fringe; per-tick numbers 288 -> 846 across the focus.
Built: 3.5 -> 13px per beam, gold throughout. Six overlapping 13px beams do
not read as one 38px column, and there is no white core or fringe.
NOTE: our fan is deliberately narrower (18 deg half vs their ~28) because
the player stands ON a floor and a wide fan buries itself — that stays.
FIX: widen the converged width and add a white core line + a faint colour
fringe so full focus reads as ONE pillar rather than six wires.

## 5. THE MOUNTAIN THAT KNEELS vs Staff of Earth — no impact smoke
Measured: "impact bursts white smoke"; boulder "plows an entire 15-dummy
row per cast"; damage visibly 110-140 slow vs 244-280 fast.
Built: speed-scaled damage is in (good), but there are no smoke bursts and
no dust on ground contact — specced, then not implemented.
FIX: white smoke puff on each body hit; small dust kick on ground contact.

## NOT GAPS (checked, and correct)
- Grief Wears a Crown's wave speed (1400 px/s) matches Golem Fist's measured
  ~23 PH/s launch, the fastest in the study.
- The Whole Court's tint cycling matches the "individually coloured" law
  the Prism and Zenith both show.
- The Hollow King's Rain's spawn scatter (+/-72px, 7 deg tilt) matches
  Daedalus' measured +/-1.5 PH jitter and 8-15 deg.
