# THE WEAPON OVERHAUL — the plan after the study
Written 2026-07-29, after ~355 weapons were measured on film
(`study/`) and the transferable rules distilled (`study/DESIGN_LAWS.md`).
Nothing here is built yet. This is the document the dev green-lights.

---

## 1. THE DIAGNOSIS (why the roster feels samey despite "unique" effects)

Current roster: **350 weapons**. Their behavior column — the thing that
decides what the attack actually LOOKS like — collapses into ~20 values,
and ten of them carry half the roster:

| behavior | rows |
|---|---|
| arc (a plain swing) | 28 |
| thrust | 24 |
| staff | 21 |
| cleave | 15 |
| orbiter | 14 |
| jab_volley | 14 |
| lash | 11 |
| ricochet | 10 |
| chain_maul | 9 |
| crescent | 8 |

**~175 weapons share ten motions.** Every "unique soul" we authored was an
fx RIDER bolted onto one of those ten — chain lightning, echo, splinter,
brand. That is exactly why the dev kept saying the weapons repeat: they do.
The fx differ; the *verb* does not.

Meanwhile the study just gave us **~355 measured motion verbs**.

## 2. THE TARGET

**360 weapons across 4 classes**, and the number that actually matters:
**~70 distinct MOTION verbs** (up from ~20), each one traced to a measured
recipe in `study/`.

| tier | Sword | Archer | Mage | Summoner | total |
|---|---|---|---|---|---|
| T1 | 10 | 7 | 7 | 6 | 30 |
| T2 | 12 | 9 | 11 | 8 | 40 |
| T3 | 17 | 13 | 14 | 11 | 55 |
| T4 | 18 | 13 | 16 | 11 | 58 |
| T5 | 16 | 12 | 14 | 10 | 52 |
| T6 | 14 | 11 | 13 | 10 | 48 |
| T7 | 13 | 10 | 10 | 9 | 42 |
| T8 | 11 | 8 | 9 | 7 | 35 |
| **total** | **111** | **83** | **94** | **72** | **360** |

Split by kind: **~230 verb-bearing** (each a Deepwood cousin of a measured
weapon) and **~130 plain ladder rungs** — kept deliberately, because the
STAT-RUNG LAW proved ladders are honest and cheap when each rung adds
exactly ONE new tell.

## 3. THE PHASES

### PHASE A — the engine (the foundation everything else needs)
Five motion families the engine cannot currently express, plus two systems.
Each is one batch: build → fx audit → EYES walker → suite → commit.

- **A1 — YOYO / dwell family.** Thrown body that DWELLS at the aim inside a
  reach radius, steerable, returns on release. Measured: reach 2.2-3.9 PH,
  5-8 hits/s, wander ±0.5-1 PH (below 0.5 it reads dead).
- **A2 — FLAIL family.** Hold = orbit-spin (0.8-1 PH, ~6 hits/s, hits both
  flanks); tap = launch on a chain (4.5-7.3 PH) that **damages along its
  whole length**, not just the head.
- **A3 — BOOMERANG family.** Out-and-back, 4.5-10 PH, 10-15 PH/s, and the
  **return pass pierces even when the outbound doesn't** — plus the
  multi-throw ceiling (3 / 6 / 10 in flight).
- **A4 — WHIP + TAG.** The Summoner's active verb: arc swing 2 PH (starter)
  → 13 PH (crown), marking one foe at a time; the mark focuses every
  companion and adds flat tag damage. Rides `companion.gd`.
- **A5 — SUMMON SLOTS.** Persistent minions cast from scepters into a slot
  economy; permanent stationed totems distinct from wands' timed sentries.
- **A6 — AFTERMATH SYSTEM.** One shared home for damage that outlives the
  input: lingering zones, planted traps (5-8s), stacking embedded barbs,
  DoT tails where DURATION is the tier. Half the study's best verbs need it.
- **A7 — DELAYED PAYOFF.** Plant-then-harvest: a small hit now, a large
  scheduled one later (measured 0.5s bubbles / 0.6s orb / 1.5s at ~8x), with
  the waiting legible on screen.

### PHASE B — the Summoner class
Per `SUMMONER_CLASS_DESIGN.md`: identity, scepter/whip/totem families, the
three-spec skill graph with tier-4 exclusive keystones, slot economy, class
relic + armor set-soul, sims and save integration. Ships with its 72 rows.

### PHASE C — re-verb the three existing classes
Family by family, TOP-DOWN (T8 → T1, because the crown weapons are what the
dev judges the game by, and the CROWN RULE says they should get *cleaner*,
not busier). Each batch: a family's rows get real verbs from the studied
library, stats cut to 1-5 by rarity, cards rewritten, audit + EYES + suite.

Rough batch list: melee crown → melee mid → melee low → bows → guns/thrown
→ wands → tomes/staves → the joke lane (all three kinds) → the
intentional non-weapon lane.

### PHASE D — ladders, numbers, verify
The ~130 plain rungs rebuilt under the one-tell-per-rung law; a full numbers
pass (balance sim + marathon sim per class, now four); clean-clone verify;
memory updated.

## 4. THE RULES THIS OVERHAUL OBEYS
From `study/DESIGN_LAWS.md`, non-negotiable:
- Power lives in the VERB. Stats 1-5 by rarity, hard cap.
- The crown rung goes CLEANER, not busier.
- Aftermath is the second half of every good verb; burn DURATION is the tier.
- The TRAIL is the signature — differentiate by wake, not projectile body.
- Damage numbers are spectacle, tuned per verb.
- Geometry: spear riders at the thrust apex; flail chains damage their whole
  length; boomerang returns pierce; yoyo wander ≥0.5 PH; sky-rain's balance
  dial is whether it respects roofs.
- Similar, never 1:1 — motion recipes rebuilt procedurally in our palette.
  Never copied pixels (the mobile port is store-bound).

## 5. OPEN DECISIONS FOR THE DEV
1. **Roster size 360?** (or hold at 350 / go larger)
2. **Summoner ships in this wave?** — recommended YES, so the class is
   designed in rather than bolted on later.
3. **Keep ~130 plain rungs?** — recommended YES; the stat-rung law makes
   them honest, and they pace the reward curve.
4. **Names:** keep the existing Deepwood names where the weapon survives,
   or rename freely as verbs change? — recommended KEEP good names, rename
   only where the name promises a verb the weapon no longer has.
5. **Order:** top-down (crown first, recommended) or bottom-up (T1 first,
   what a new player meets first)?
