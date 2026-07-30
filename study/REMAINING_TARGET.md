# What is actually left (measured 2026-07-29, after T7 closed)

An earlier estimate in conversation said "~130 weapons stay plain, so ~90-100
verbs left." **That was wrong on both halves** and this file replaces it.

## The correction

Only **30 rows in the entire roster** use a generic behavior. Distinctness by
behavior-name is already 245/275. But behavior-name distinctness was never the
real measure — the original diagnosis was *many weapons sharing one motion*,
and that is still true:

**238 of 275 weapons sit on a verb shared with 5+ other weapons.**
58 behaviors exist; 21 of them carry those 238.

## Where the roster still collapses

| behavior | weapons | tiers |
|---|---|---|
| arc | 25 | T1–T6, T8 |
| thrust | 22 | T1–T7 |
| staff | 18 | T1–T6, T8 |
| ricochet | 17 | T2–T8 |
| cleave | 13 | T1–T6 |
| orbiter | 12 | T2–T6, T8 |
| shot | 12 | T1–T5 |
| volley / jab_volley / rapid | 11 each | T1–T6, T8 |
| cluster / lob_a | 10 each | T2–T7 |
| lash / tome | 9 each | T3–T8 |
| seeker / bolt | 8 each | T1–T6 |
| sentry / chain_maul / crescent | 7 each | T1–T8 |
| fire | 6 | T2–T6 |
| frost | 5 | T2–T7 |

## Percentage of each tier still on a crowded verb

| tier | weapons | crowded | % |
|---|---|---|---|
| T1 | 20 | 20 | 100% |
| T2 | 29 | 29 | 100% |
| T3 | 45 | 44 | 98% |
| T4 | 49 | 48 | 98% |
| T5 | 41 | 41 | 100% |
| T6 | 38 | 37 | 97% |
| **T7** | **30** | **8** | **27%** |
| T8 | 23 | 11 | 48% |

T7 and T8 are the finished shape. Everything below still collapses.

## The target — and what should NOT be built

The study's own ladder law says **low tiers are supposed to share a motion**.
A copper sword and an iron sword swing identically and differ by numbers; that
IS the ladder, and giving 20 T1 weapons 20 bespoke verbs would be noise, not
depth. Individuality belongs at the top.

So the real remaining build is **T6 then T5** — 78 weapons, of which 78 are on
crowded verbs. Realistic target after reuse (shared ticks, riders, the
embedded-stack system): roughly **45–55 new verbs**, since several weapons per
tier can share a NEW verb honestly (e.g. the three T6 `arc` swords can become
three flavours of one new sweep rather than three unrelated engines).

T4 and below: leave the shared motion, differentiate by fx rider, numbers, and
card text. Revisit only if the tiers still feel flat in play.

---

# PROGRESS: T6 CLOSED (2026-07-29)

Re-measured after four T6 batches. The roster now carries **86 distinct
behaviors**, up from 58.

| tier | weapons | crowded | % | |
|---|---|---|---|---|
| T1 | 20 | 20 | 100% | |
| T2 | 29 | 28 | 97% | |
| T3 | 45 | 44 | 98% | |
| T4 | 49 | 47 | 96% | |
| T5 | 41 | 40 | 98% | **next** |
| **T6** | **38** | **9** | **24%** | **done** |
| T7 | 30 | 7 | 23% | done |
| T8 | 23 | 11 | 48% | |

T6 went 97% -> 24%, matching T7. The 9 that remain crowded are exactly the
9 pinned plain ladder rungs, which are *supposed* to share a motion.

## The plain-row rule (learned the hard way, twice)

`{"plain": true}` rows are pinned: the fx audit fixes the count at exactly
129 and validates craft chains between them. **Converting one breaks two
invariants.** Ghost Repeater and Horizon Pike were both caught mid-batch
this way.

Enumerate them with BALANCED BRACKET parsing, never a fixed line window --
a 4-line window bleeds into neighbouring rows and wrongly flagged
Cindershelf, Requiem Edge and Sorrowfang as plain when they are not.

## The stacking trap (caught twice by the dps gate)

A persistent zone or minion whose lifetime exceeds its cooldown can be
stacked indefinitely. Second Moon (6s life / 0.85s cd) read 233 dps and
Cindershelf (4s / 0.8s) read 360, against a tier median of ~80. Both needed
a **design** fix, not a tuning one: cap to one instance via a group, and let
a recast renew rather than add. Any future persistent verb needs this cap.

## Declaring hits-per-use honestly

The audit's factor means damage instances on ONE body, not on the room.
Batch 4 initially declared whole-room damage (a courier's four deliveries, a
seven-shaft wall) as if it all landed on one target, which pushed T6's
median ABOVE T7's. Crowd damage is a feature; do not bill it as single-target
throughput.

---

# FINAL STATE (2026-07-29, overnight pass)

Measured across all 275 weapons. **146 distinct behaviors**, up from 58.

| tier | weapons | crowded | % | |
|---|---|---|---|---|
| **T8 monarch** | 23 | **0** | **0%** | every crown weapon has a verb of its own |
| T7 | 30 | 3 | 10% | |
| T6 | 38 | 9 | 24% | |
| T5 | 41 | 12 | 29% | |
| T4 | 49 | 26 | 53% | all 21 convertible done; the rest are pinned plain |
| T3 | 45 | 31 | 69% | plain ladder by design |
| T2 | 29 | 23 | 79% | plain ladder by design |
| T1 | 20 | 19 | 95% | plain ladder by design |

That descending curve IS the ladder law working. The crown is entirely
singular; the low tiers stay shared on purpose, because a copper sword and an
iron sword should swing the same and differ by numbers. What remains
"crowded" at T1-T4 is overwhelmingly the pinned plain rungs.

## Verified

- **Clean clone**: 108/108 of the full suite, plus all five weapon audits.
  A green working tree has lied in this repo before; this is the committed
  tree.
- **The dispatch audit** (new) proves every one of the 179 weapons that
  declares a verb actually fires it, and that a verb promising a count
  delivers it.

## Still open

1. **The Summoner class** — `SUMMONER_CLASS_DESIGN.md`, still entirely
   unbuilt. The largest single remaining piece.
2. **T1-T3 taste pass** — the ladder law says leave them shared, but the dev
   has since said they want effects over stats at EVERY level. Worth asking
   rather than assuming.
3. **Item space** — relics/armour/materials adaptations from the scans.

## Order

1. **T6** (38 weapons, 37 crowded) — the tier directly under the finished ones,
   so the seam between T6 and T7 is where flatness would show most.
2. **T5** (41 weapons, 41 crowded).
3. Re-measure this table. Stop when T5/T6 crowding is under ~30%, matching T7.
4. The Summoner class (`SUMMONER_CLASS_DESIGN.md`) — still entirely unbuilt.
