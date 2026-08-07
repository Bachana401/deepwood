# WEAPON LAB — findings (2026-08-07)

Dept: Weapon Lab. Territory touched: `weapon_projectile.gd`, `test_erupt_node.gd`
(new + its `.gd.uid`), `all_test_files.txt`. No file outside territory was edited;
one `player.gd` note below is informational (no patch needed).

The dev's report, verbatim:

> "weapon unbent column's projectiles or behavior are not really affecting
> enemies, some of them are some of them are not, fix it."

## TL;DR — one root cause, nine verbs

"Unbent Column" is a specific weapon — **The Unbent Column** (`wpn_unbentcolumn`),
a Monarch staff whose verb is a five-pillar colonnade that erupts from the floor.
It was not the only one broken the same way.

**Root cause.** A whole family of verbs deals its damage **by hand**, a beat after
the cast, from an `Area2D` node that spawns a short distance in front of the
caster (colonnades, plucked strings, falling columns, tolling rings, growing
lightning, storms, planted posts). Every one of those nodes was left
`monitoring = true` with a live default hitbox. So when an enemy stood where the
node spawned — **a crowd at your feet, the normal case in a fight** —
`body_entered` fired, the non-pierce default arm (`weapon_projectile.gd:2523`
`if not pierce and kind != "boomerang": queue_free()`) paid **one stray hit and
freed the node before the verb ever ran.** Enemies at range saw the full verb; a
crowd at the spawn ate the projectile and got a single tap. That is exactly "some
of them are, some of them are not."

None of these nodes appears in `_on_body_entered`'s match, so the collider only
ever HURT them. **The fix is one line — `monitoring = false` — in each verb's
`_build_`/dispatch arm**, so the verb's own hand-rolled damage is the only thing
that fires. Nine verbs, nine identical lines. No damage number was touched
(project rule: power is in the verb).

A **second, colonnade-specific** geometry bug also stood between the pillars even
when it did erupt (§2).

## 1. The broken behaviours (measured, root-caused, fixed)

| behavior | weapon | class | declares | spawns at | fires after | fixed |
|---|---|---|---|---|---|---|
| `unbentcolumn` (colonnade) | The Unbent Column | staff | 1.2 | aim·70 | 0.14s | ✅ |
| `thronestrings` (harp_string) | Throne of Strings | bow | 3.0 | aim·40 | 0.10s | ✅ |
| `skymeasure` (sky_measure) | Staff That Measures the Sky | staff | 1.4 | aim·120 | 0.42s | ✅ |
| `anviltoll` (anvil_toll) | The World-Anvil | melee | 2.7 | aim·82 | tolls | ✅ |
| `forktree` (fork_tree) | Stormsliver | wand | 2.2 | aim·34 | 0.02s | ✅ |
| `skycharges` (sky_charge) | What the Sky Charges | wand | 3.4 | aim·120 | bolts | ✅ |
| `wispwarden` (wisp_post) | Wisp Warden | wand | — | aim·120 | 0.78s | ✅ |
| `candlekeeper` (candle_row) | Candlekeeper | wand | — | aim·120 | 0.78s | ✅ |
| `covenledger` (coven_ring) | The Coven's Ledger | wand | — | aim·120 | 0.46s | ✅ |

The first six erupt once; the last three are planted posts that tick over time
(`_tick_asphodel` / `_tick_standing_zone`). Their sibling `asphodel_post` already
set `monitoring = false`; these three, sitting on the same arms of the same match,
never got the line — a copy-paste omission.

### Why the hits sweep did NOT catch it — the important part

I ran the full survey (`tool_hitsweep`, all 209 behaviors × 3 ranges):

```
SUMMARY: 209 behaviors | 0 DEAD | 0 OVERSTATED | 160 understated | 49 honest
```

**Zero dead.** The sweep seats ONE dummy along the aim line, and the premature
free needs a body sitting ON the spawn — a crowd, not a lone target. At close
range the lone dummy sometimes overlapped the spawn and the resulting **one stray
hit happened to equal the declared 1–1.4**, so the verb read "honest." This is a
crowd-only, position-dependent failure. No grep, no single-target sweep, no DPS
table could see it — only a purpose-built crowd rig (or the dev's own play) does.
That is the whole finding: the measurement that exists in this repo was blind to
this bug by construction, which is why it survived every green run.

## 2. The colonnade's own second bug (geometry)

Even once it erupted, `_raise_colonnade` had two coverage holes, both live-play
"some enemies aren't hit":

1. **Dead lanes.** Pillars stood `COL_GAP = 88` apart but each reached only ±30px,
   leaving a 28px lane between neighbours where a body took nothing. The
   declaration is explicit — "a body stands in ONE pillar" — so it has to actually
   stand in one. `COL_HALF = 46` now tiles the gap (46·2 = 92 > 88): the five
   pillars form a continuous eruption, no gaps.
2. **The lift.** Pillars marched along `direction` (the full aim vector), so any
   up/down aim carried the whole colonnade off the floor and the far pillars ended
   hundreds of px above a ground-standing enemy. It now marches on the aim's
   HORIZONTAL only, anchored to the caster's floor line (`origin_y` from `source`),
   so it always "comes up out of the floor" whatever the vertical aim. Vertical
   band lower bound relaxed 34 → 40 to seat a standing body given the spawn offset.

Declared 1.2 still holds; the fix only makes that 1 land on every body in the hall.

## 3. Implementation notes

- `monitoring = false` is a **direct** assignment in `_ready`/`_build_`, NOT
  `set_deferred` — the node must be un-monitoring on its FIRST frame or a crowd
  still frees it before a deferred disable applies. These verbs are cast from
  `perform_attack`/`cast_wand_projectile` in an input/process context, never
  inside a physics flush, so setting monitoring in `_ready` is safe (confirmed: the
  eruption test runs clean, no "can't change state while flushing queries").

## 4. Proof

**`test_erupt_node.gd`** (new; registered in `all_test_files.txt`, `.gd.uid`
committed). Seats a CROWDER on the exact spawn and FAR WITNESSES out in each
verb's zone (past melee reach; the harp's witnesses off-axis so its bow shaft
can't be mistaken for the pluck), and asserts the verb reaches them. Carries a
**positive control** — a straight Orchard Bow shot must strike a witness in the
same run, so a witness reading 0 means the weapon, not the harness.

5 checks, all PASS:
- positive control (Orchard Bow) — strikes its witness
- The Unbent Column — erupts past a crowder
- Throne of Strings — plucks past a crowder (off-axis witnesses)
- Staff That Measures the Sky — columns fall past a crowder
- The Coven's Ledger — planted ring keeps ticking on a body at the plant point
  (measured ~10 hits/2s; stands in for Wisp Warden & Candlekeeper, same tick)

**Guard-proof:** reintroducing `monitoring = true` on the colonnade alone makes
exactly that assertion FAIL while the positive control and the others still pass —
a real guard, not a tautology. (Verified by hand this session.)

The three first-frame eruptions (toll/fork/storm) share the identical one-line
fix but fire on frame 1, so a freed node still lands its first hit and a crowd
assertion would race it; they are covered by measurement + the sweep, not asserted
here. Measured post-fix, all three land their multi-hit verb.

Suite (each via the `MONARCH_TEST` hook):
- `test_erupt_node` — ALL PASS (FAILs correctly when the bug is reintroduced)
- `test_realhits_node`, `test_weapondps_node`, `test_weaponfx_node`,
  `test_weapons2_node`, `test_melee_node` — ALL PASS
- planted-post spot-measure: Wisp Warden 2, Candlekeeper 4, Coven's Ledger 10
  hits on a body at the plant point (pre-fix: ~1)

## 5. Handed over / noted, NOT fixed

- **PRE-EXISTING, separate bug (Gloamburst), my territory — flagged, not fixed
  this pass.** `_gloam_motes` (`weapon_projectile.gd:~11278`) is called from
  `_on_body_entered` (inside a physics flush) and spawns 6 child `grief_tear`
  motes; each child's `_ready` sets monitoring / adds a collision shape and the
  engine throws `Can't change this state while flushing queries` (seen ~200× in
  the sweep log). The bolt's primary hit still lands; the dusk motes may not
  register. **Fix shape:** the motes are already added with `call_deferred`, but
  the child's `_ready` still touches monitoring during the same flush — spawn them
  a frame later or set the child's monitoring deferred. Left out to keep the
  colonnade change reviewable; recommend a follow-up ticket.
- **`player.gd` (Mechanics territory) — informational, no patch needed.** The
  eruption verbs spawn at `player + aim·{34..120}` in `perform_attack` /
  `cast_wand_projectile`. No change required there — the fix lives entirely in the
  projectile. Noted only because those spawn offsets are load-bearing for the crowd
  geometry.

## 6. Definition of done

- [x] exhaustive list of broken behaviours — nine, §1, all one shared root cause
- [x] every one fixed and re-measured landing real damage (crowd rig + posts probe)
- [x] the sweep's blind spot documented (0 DEAD; the bug is crowd-only by nature)
- [x] positive-control-backed regression test that catches a future dead eruption
- [x] no file outside territory edited (one informational note handed over)
- [x] weapon suite green (six tests) — full-suite run left to QA's runner on merge
