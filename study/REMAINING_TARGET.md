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

## Order

1. **T6** (38 weapons, 37 crowded) — the tier directly under the finished ones,
   so the seam between T6 and T7 is where flatness would show most.
2. **T5** (41 weapons, 41 crowded).
3. Re-measure this table. Stop when T5/T6 crowding is under ~30%, matching T7.
4. The Summoner class (`SUMMONER_CLASS_DESIGN.md`) — still entirely unbuilt.
