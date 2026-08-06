# BALANCE — measured findings for the lead

Branch `claude/hungry-swirles-e2dc05`. Every number below came out of a sim run,
not out of reading a constant. Tools: `tool_econ_sim.gd`, `tool_patrol_sim.gd`,
`tool_peril_sim.gd`, `tool_ladder_sim.gd`, `tool_plague_sim.gd`.

Conversions used throughout: **1 in-game day = 600 real seconds**, so 1 in-game
hour = 25 real seconds and 1 real minute = 2.4 in-game hours.

---

## 0. TWO HARNESS BUGS — read these before trusting any village sim

Both produced confident, wrong answers. Both were caught by tracing hour-by-hour
instead of reading the summary line.

**(a) Starvation and sickness share one HP pool.** `tick_morale_effects` is the
only thing that moves `villager_hp`, and it serves hunger *and* the sickness. My
first peril run reported a town of 80 wiped out and blamed the sickness. The
hour-by-hour trace said otherwise: HP sat pinned at 100 for nine straight days
and fell off a cliff the hour the larder emptied. **To measure either, you must
hold the other at zero.** Every peril sim here force-feeds the town every hour
(`keep_fed`). Without that line the sim measures famine and calls it plague.

**(b) `village_morale()` is not a live read of a morale change.**
`SICK_MORALE_PER_CASE` moves the personal morale *target*; the meter drifts
toward it. Infecting all 80 souls and reading the meter on the same frame reports
**+0** — I published that number internally before catching it. Read it again
after ~72 in-game hours of drift and the same town reads **−40**. Any sim that
sets a morale input and reads the meter immediately is measuring nothing.

A third, smaller one worth knowing: `generate_passive_income` fires on a
**20-real-second** timer (0.8 in-game hours), not once per in-game hour. The old
`tool_balance_sim` calls it hourly and therefore under-reports every gold figure
by 20%. `tool_econ_sim` drives the real cadence.

---

## 1. THE MOST BROKEN CURVE — the plague kills the town, and the ward can't stop it

⚠ **This is on `claude/gifted-murdock-786925`, not master.** Master still carries
the single-strain model. Measured with `tool_plague_sim.gd` run from a throwaway
worktree at that branch.

One plague case seeded into a cared-for town of 80, larder held full, 20 trials:

| setup | saturates in | reached whole town | **dead of 80** | outbreak over in |
|---|---|---|---|---|
| live graph (home+work) | 49 h | 20 of 20 | **73.2** | 337 h (14 d) |
| homes-only graph | 168 h | 20 of 20 | **75.6** | 360 h (15 d) |
| live + staffed ward *in aura* | 48 h | 15 of 20 | **54.9** | 411 h (17 d) |
| homes-only + ward in aura | 182 h | 16 of 20 | **56.5** | 572 h (24 d) |

A single case ends the settlement. The best case I could construct — a staffed
Hospital standing directly on the cottage row — still loses **55 of 80 souls**.

**The cause is not the drain and not the spread. It is that there is no immunity.**
Per-case arithmetic says the ward should save nearly everyone: in the aura a case
lasts 543 h = 22.6 daily cure rolls at 0.26, so P(never cured) ≈ 0.1%. It loses 55
anyway because a cured villager is re-infected the same night by a saturated town,
and is re-rolled until one of the rolls kills them. Cure rate is close to
irrelevant while re-infection is unbounded.

Modelled, calibrated against the measured 73.2 above (model gives 80.0 on the same
inputs — it tracks, slightly pessimistic):

| graph | cure/day | immunity after recovery | dead of 80 |
|---|---|---|---|
| live | 0.04 (shipped) | none | 80.0 |
| live | 0.26 (ward) | none | 66.7 |
| live | 0.04 | 14 days | 63.5 |
| **live** | **0.26 (ward)** | **14 days** | **7.8** |
| homes-only | 0.04 | 14 days | 61.3 |
| homes-only | 0.26 (ward) | 14 days | 12.9 |

**Neither lever works alone. Together they land it.** And note what that table
does to the design: with no immunity the ward takes the toll from 73 → 55 (barely
worth building). With immunity it takes it from 63.5 → 7.8. **Immunity is the
change that makes the Hospital matter**, which is what the system's own header
says it is for.

**Recommendation:** add a post-recovery immunity window before touching any
constant. It is a design change, so it is argued rather than tabled — but no
combination of `PLAGUE_CURE_MULT` / `PLAGUE_DRAIN_PER_HOUR` fixes this, because
the failure is repeated exposure, not per-case survival.

### Measured all-clears on the new model

- **The ordinary illness cannot kill.** Held on one villager for 100 in-game days:
  alive, HP 100/100. The dev's ruling holds. ✅
- **The plague's own clock is well-judged.** No intervention: dead at **167 h
  (7.0 in-game days / 70 real minutes)**. Staffed ward too far to reach: 177 h.
  Ward in aura: **543 h (22.6 days / 226 real min)** — a 3.3× stay of execution
  for placing the Hospital well. That is a good curve; leave it alone.
- **The morale bill is bigger than the cap reads.** Healthy town of 80 sits at 82.
  All 80 with the ordinary strain: **65 (−17)**. All 80 with the plague: **42
  (−40)**. `SICK_MORALE_CAP` is 2.5 on the 0–10 personal scale, which a naive
  reading translates to 25 meter points; measured it lands 40. Flagging, not
  diagnosing — the composite meter amplifies it somewhere.

### Which of my old sickness numbers survive your rewrite

| old finding | survives? |
|---|---|
| "the sickness cannot kill: drain 2.4 < regen 3.0, net **+0.60 HP/h**" | **Dead.** You fixed it exactly right — by suppressing the regen (`game_state.gd:4850`) rather than raising a drain. My sweep said drain ≥3.6 was needed to out-run regen; regen suppression makes that moot. |
| "no-passive-regen alternative kills in 42 h" | **Survives as the mechanism you shipped**, re-scaled: at `PLAGUE_DRAIN_PER_HOUR` 0.6 it is 167 h instead of 42 h. |
| S5 sweep: "spread/cure has no middle — either everyone has it or everyone dies" | **Survives and is the finding above.** The sweep row *"ships + no sick regen" → 69.6 deaths/100 days* predicted the 73.2 I later measured on your real code. |
| S2 table (drain 2.4/3.6/5.5 × ward) | **Stale.** Those constants no longer exist. |
| S3 "an illness lasts 398 h with no ward, 96 h with a distant ward, 37 h in the aura" | **Survives** — driven by `SICK_CURE_CHANCE_PER_DAY` / `SICK_WARD_CURE_BONUS`, both unchanged. |
| S2b spacing table | **Survives**, and is the contact-graph argument in §5. |

---

## 2. THE VILLAGE ECONOMY OUT-EARNS THE DUNGEON

`tool_econ_sim.gd`. **Assumption: a perfectly-played town** — 80 souls, all 15
halls up, staffed and led, larder deep, everyone housed and paired, sieges pinned
off, same seed and same painted town in every row. **Population pinned at 80** so
layout and level are isolated from the birth rate. An average town earns strictly
less than this.

Gold per real minute, player **away in the deep** (the passive stream):

| town | mean output multiplier | gold/in-game hour | **gold/real-minute** |
|---|---|---|---|
| naive row, L1 | 1.020 | 14.7 | 35.3 |
| naive row, L6 | 1.270 | 23.2 | 55.7 |
| tuned row, L1 | 1.300 | 25.6 | 61.5 |
| **tuned row, L6** | **1.550** | **39.6** | **95.0** |
| mid-game town (~floor 35, naive, L2, 38 souls) | 1.070 | 6.6 | 15.9 |

Against delving the same real minute (kill+boss coin, plus every scrap of the
floor's loot liquidated at `Inventory.sell_value` — the delve's absolute ceiling):

| floor | coin/min | loot/min | total | vs tuned-L6 village (95.0) |
|---|---|---|---|---|
| 10 | 35.4 | 10.4 | 45.9 | village x2.07 |
| 30 | 56.7 | 8.5 | 65.2 | village x1.46 |
| 50 | 70.8 | 6.8 | 77.6 | village x1.22 |
| 70 | 81.0 | 5.8 | 86.7 | village x1.10 |
| 90 | 88.5 | 5.1 | 93.6 | village x1.02 |
| 99 | 60.3 | 6.0 | 66.2 | village x1.44 |

**The maxed village out-earns delving at every floor of the ladder.** Even the
deepest floor in the game loses to a town that is doing nothing.

**But the honest framing is the arc**, because nobody has that town at floor 10:

- mid town at the depth a player would actually be (floor ~35): **15.9 passive vs
  65.2 delving — the deep wins x4.10.**
- late town at its depth (floor ~80): **95.0 passive vs 90.4 delving — the town
  wins x0.95.**

So the dungeon economy is not trivialised across the arc; it **inverts at the very
end**, right where the player has finished paying the 24,750 g town ladder. Whether
that is a bug or the intended payoff is your call — but at floor 80+ there is
currently no gold reason to descend, and a tuned town pays back the entire
upgrade ladder in **26 in-game days (260 real minutes)**.

### The spatial puzzle is worth the puzzle — and its ceiling is unreachable

- Constants allow **1.55×** per building at L1 (`1.0 + 0.30 adjacency + 0.10
  district + 0.15 plot`).
- Naive row (one clump west of the gate): **1.020**.
- Best row an 80-restart hill-climb can find: **1.300** — and a hand-constructed
  "textbook" row scores 1.297, so the search is at the real optimum, not stuck.
- **Layout alone is +27.5% output, which the chain compounds into +74% gold**
  (14.7 → 25.6 g/h). Levels alone are +58%. **The layout puzzle is worth slightly
  more than the entire 24,750 g upgrade ladder.** That is a good ratio; the spread
  is emphatically not too small. ✅

**Nobody can reach 1.55× because district and adjacency fight each other.** The
best row banks 5 of 7 plots and 14 of 15 quarters, but only 6 of the 8
`ADJACENCY_PAIRS` — `Mine`+`Blacksmith` (0.20, the richest pair in the table) is
*unreachable at all* while both take their own quarter, since the Mine is
outskirts and the Blacksmith gatefront. Not proposing a change; you should just
know the top of the range is decorative.

### Secondary finding: the birth flywheel doubles the town in 10 in-game days

Same tuned-L6 town with the cradles left running: **80 → 176 souls in 10 in-game
days (100 real minutes)** — one new soul per couple per 4.2 in-game days. Memory
records the design target as 70–80 villagers by floor 60. This is outside my four
questions and I have not chased it, but it inflates every economy figure and it is
why the pinned-population runs above exist.

---

## 3. PATROLS — measured all-clear on both questions

`tool_patrol_sim.gd`. Nothing to patch. Both brief questions come back clean.

**Does posting warriors ever beat delving yourself? No, by a wide margin.**

| corps posted at block 10 | gold/real-min | vs delving floor 100 | vs floor 50 |
|---|---|---|---|
| 12 | 14.9 | x0.16 | x0.21 |
| 30 | 37.4 | x0.41 | x0.53 |
| 40 | 49.8 | x0.54 | x0.70 |

A single warrior at the deepest block is **x76 worse** than the player walking the
same floors. Even a 40-warrior corps — more warriors than the design targets —
reaches 70% of floor-50 delving. ✅

**And the trade genuinely bites:** 40 warriors home = 30.0 defense; post 20 of
them = 15.0 (**−50%**). Holding all ten blocks costs **12 warriors off the wall**. ✅

**Can a find hand gear ahead of where it was earned? No — the depth gate is exact.**
For every block 1–10, the patrol pool's best grade equals the dungeon's own best
grade at floor `b×10`. Not one block is out of step. ✅

| block | deepest floor | patrol best | dungeon best at that floor | share of finds at top grade |
|---|---|---|---|---|
| 3 | 30 | rank 4 | rank 4 | 32.7% |
| 5 | 50 | rank 5 | rank 5 | 22.5% |
| 7 | 70 | rank 7 | rank 7 | 2.8% |
| 9–10 | 90–100 | rank 8 | rank 8 | 4.3% |

**And a find stays a delight:** 12 warriors posted = one find per 6.9 in-game days
(69 real minutes); 30 posted = one per 2.8 days. ✅

**Creep pacing is sound:** an abandoned block gives 334 h (block 1) down to 78 h
(block 10) before it falls — 13.9 down to 3.3 in-game days. Blocks 1–8 need 1
warrior to hold, blocks 9–10 need 2. ✅

---

## 4. THE AUTOMATION LADDER — a 40-floor dead stretch

`tool_ladder_sim.gd`. The design law is hands-on at the start, self-running by
"roughly level 80". Measured against the actual unlock depths:

Chores handed over, by the depth that grants them:

```
floor  1   food, repairs, wood          floor 25   sell your haul (Merchant Prince)
floor 10   fishing, patrols             floor 30   carry arms (Forgemaster)
floor 13   mining                       floor 40   carry the hurt (Chief Physician)
floor 20   pair couples (Publican)      floor 45   enrol children (Principal)
floor 22   wages (staffed Bank)         floor 55   raise cottages (Master Builder)
                                        floor 75   identify materials (Lead Researcher)
                                        floor 95   assign rescues (Chancellor)
```

- **LONGEST DEAD STRETCH: floors 56–95. Forty floors in which nothing new is
  automated.** Two 10+ floor gaps sit inside it (56–74, 76–94). This is the finding.
- **The last chore lands at floor 95** — and `tool_balance_sim` S6c says clearing
  all 99 floors lands a player in the **mid-to-high 50s**, so "by level 80" is
  never reached inside the game. **The ladder is paced entirely by depth, and
  depth runs out before level 80 does.**
- At floor 100 with every VIP freed, `chore_domains()` reports **5 of 7 automated
  (71%)**, not ~100%.
- Caveat on that 71%: the "Payroll" domain reads `_bank_paid_full_payroll`, a
  runtime flag that only trips when the treasury actually covers a whole payday.
  It is genuinely reachable from floor 22 (my L2 table credits it there); it
  cannot be attributed to a rescue depth, so the L1 mapping shows it as "never".
  Do not read that row as a missing feature.
- **Measured all-clear:** every hand chore listed has a wired automation — no
  chore is orphaned — and all 15 named building powers are gated behind a rescue
  depth rather than gold alone. ✅

The dead stretch is structural: floors 56–95 hand out `Foreman` (60), `Warchief`
(65/70) and four `Lead Researcher` duplicates (75/80/85/90), none of which
*unlocks a new chore* — they are second holders of seats already filled. The
cheapest fix is to move one un-granted automation into the 60s–80s rather than to
retune a constant, which is why there is no table row for it.

---

## 5. THE CONTACT GRAPH — `_lives_touch` should read homes only

Argued, as asked, rather than proposed.

`_lives_touch` reads `villager_places()`, which returns the cottage **and** the
workplace. Everyone rostered to the same hall therefore stands at **distance 0**
to each other. Measured on a painted town of 80 (`tool_plague_sim.gd` G2, using
the real `_lives_touch` against rosters that differ only in whether `role_key` is
set — the function is never edited):

| town | contacts per soul (of 79) |
|---|---|
| employed, cottage row **150** apart | **79.0** |
| employed, cottage row **4000** apart | **79.0** |
| no jobs, row 150 apart | 22.9 |
| no jobs, row 4000 apart | 1.0 |

**Spacing the cottage row 27× further apart changes the contact graph by exactly
nothing while anyone is employed.** The town is one fully-connected blob. The
spread design's own header — *"cottages packed in a row pass it along fast; a town
spread down the road resists it"* — is currently false in every staffed town, and
"where you put the Hospital is the most consequential thing you ever placed" is
false with it, because the ward's aura radius is competing against a graph with no
distance in it.

Confirmed downstream on the old single-strain model (`tool_peril_sim.gd` S2b),
souls infected per outbreak-day:

| setup | caught/day |
|---|---|
| row 150 apart, all at one Farm | 7.50 |
| row 4000 apart, all at one Farm | **7.50** |
| row 150 apart, nobody employed | 2.52 |
| row 4000 apart, nobody employed | **0.10** |

Identical while employed; a 25× difference once the graph is homes-only. **The
spacing lever exists and is strong — the workplace term is switching it off.**

**What it does to saturation:** live graph saturates (90% of the town ill at once)
in **49 h**; homes-only takes **168 h** — 2 in-game days versus 7. Both still
reached the whole town in 20 of 20 trials.

**What it does NOT do, and I want to be straight about this:** homes-only is
**not** a lethality fix. Deaths were 73.2 live vs 75.6 homes-only — slightly
*worse*, because the slower burn means more total daily death-rolls. And with
immunity + a ward in place, homes-only gives 12.9 dead against the live graph's
7.8. I raised this in my first report as though it were a cure; it is not.

**So the case for it is design, not survival:** it is the only thing that makes
cottage placement and Hospital placement mean anything, which is what three
separate systems (auras, the spread header, `villager_places`' own comment) are
built on. Pair it with the immunity window from §1, which is the lethality fix.

**What I think it should read:** `_lives_touch` should compare **homes only** —
the first entry `villager_places()` returns. If workplace contagion is wanted for
flavour, it should be a *separate, weaker* term (a fixed small per-workmate
chance) rather than a distance-0 edge that collapses the geometry.

---

## 6. THE HOLLOW SUN — partial answer, and one thing worth checking

`BOSS_RAZE_DAMAGE` 34, `BOSS_RAZE_RADIUS` 190, `BOSS_RAZE_FLOOR` 0.15 of
`BUILDING_MAX_HEALTH` 400. Read off `claude/focused-pike-23c680`.

What I can say with numbers:

- **10 impacts to floor one building** (400 → 60 is 340 HP; 34 per hit).
- **One building per impact, in practice.** Radius 190 covers a 380-unit window;
  the tightest gap in the best row my optimiser found is 420 units, and the real
  plot spacing is 850–2000. Even the deliberately-clumped naive row I test with
  sits at 220. A volley cannot chain down a row.

**What I cannot say:** impacts per fight. That needs a live boss run, which is
outside this tooling — I have no combat harness.

**The thing worth checking before you tune the number.** I traced the repair path
and could not find one:

- `building.take_damage` only knocks a building back a stage when `health <= 0`
  (`building.gd:351`). The 15% floor guarantees it never reaches 0.
- `advance_build_stage` is the only thing that restores health, and only on
  completing the **last** stage (`building.gd:442`).
- `auto_repair_one` returns early unless `worst_stage < TOTAL_BUILD_STAGES`
  (`game_state.gd:6492`) — it only ever works on **ruins**.

So a hall the Hollow Sun leaves at 60/400 is at **full stage with no route back to
full health** — not the crew, not the player's staged repair. Only the admin
`restore_full()`, or a fire knocking it to 0 so it can be rebuilt.

The mercy floor appears to be what makes the damage permanent: it blocks the only
mechanism (health → 0 → stage knock-back → rebuild → health restored) that would
ever heal it. Against that, the cost of a full fight is **nothing functional** —
`is_building_operational` reads `build_stage` only, never health, so a 15%
building still produces, still taxes, still counts for the finale gate. The fight
costs the town a permanent cosmetic scar and nothing else. That is probably not
what you picked 34 for. I would fix the repair path before tuning the damage.

---

## 7. PATCH LIST

Ordered by what I would do first. Confidence is mine, stated plainly.

| # | constant / change | file | current | proposed | measured justification | Q | confidence |
|---|---|---|---|---|---|---|---|
| 1 | **post-recovery immunity window** (new; design change, not a constant) | `game_state.gd` `_sickness_day` | none | ~14 in-game days | live graph + ward: **54.9 dead of 80 → 7.8**. Without it no constant works: cure alone 66.7, immunity alone 63.5. | 3 | **High** — model calibrated against the measured 73.2 |
| 2 | **`_lives_touch` reads homes only** (design change) | `game_state.gd:4565` | home **or** workplace | home only | contacts/soul 79.0 → 22.9; spacing the row 27× further apart currently changes the graph by **0.0**; saturation 49 h → 168 h | 3 | **High** for the diagnosis, **medium** for the fix shape — see §5, it is not a lethality lever |
| 3 | **repair path for a damaged full-stage building** (missing mechanism) | `building.gd` / `game_state.gd:6492` | none | any | a Hollow-Sun hall sits at 60/400 permanently; nothing but admin `restore_full()` restores it | — | **High** — traced three call sites, no live-fight confirmation |
| 4 | `BUILDING_OUTPUT_PER_LEVEL` **or** the tax chain — the late-game inversion | `game_state.gd:1121` | 0.05 | see note | tuned-L6 town pays **95.0 g/real-min** passive vs **90.4** delving floor 80 and **93.6** at floor 90. Village wins at every floor 1–99. | 1 | **Medium** — the inversion is measured; which constant should absorb it is your call |
| 5 | birth rate (`COTTAGE_OCCUPANCY_HOURS` / gestation) | `game_state.gd` | — | — | maxed town grows **80 → 176 souls in 10 in-game days**; one soul per couple per 4.2 days. Design target on record is 70–80 by floor 60. | — | **Medium** — measured on a synthetic town where all 40 couples are paired at once |
| 6 | one automation moved into floors 56–95 | rescue depths | — | — | **40-floor dead stretch, floors 56–95**; last chore at floor 95; 5 of 7 domains automated at floor 100 | 4 | **High** |

**Explicitly NOT proposing a change** (measured all-clears — do not spend effort here):

- Patrol earnings. 40 warriors at the deepest block reach 0.70× floor-50 delving; one warrior is x76 worse than delving. `PATROL_COIN_PER_WARRIOR_DAY` and `PATROL_DEPTH_BONUS` are fine.
- Patrol gear finds. The depth gate is exact at all 10 blocks; find rate is one per 6.9 in-game days at 12 posted.
- The creep clock. 334 h → 78 h across the blocks; 12 warriors to hold all ten.
- The plague's own death clock. 167 h unwarded → 543 h in the ward aura is a good 3.3× reward for placement.
- The ordinary illness's inability to kill. Verified over 100 in-game days.
- The layout spread. +27.5% output → +74% gold; worth more than the whole upgrade ladder.
- `ADJACENCY_BONUS_CAP` 0.30. Unreachable anyway — nothing can bank more than 6 of the 8 pairs.

---

## 8. WHAT I DID NOT DO

- **No live-combat measurement.** Hollow Sun impacts-per-fight is unanswered.
- **Fire is measured nowhere.** It does not exist on master or on my branch; it
  landed on `claude/focused-pike-23c680` (`FIRE_DAMAGE_PER_HOUR` 26.0,
  `FIRE_SPREAD_CHANCE_PER_DAY` 0.30, `FIRE_CREW_SUPPRESS` 0.22,
  `FIRE_OUT_CHANCE_PER_DAY` 0.18 capped 0.85) **after** my brief was written. My
  peril sim's S4 correctly reports "not present" for the tree it runs in — that is
  not an all-clear, it is an un-measured system. `tool_peril_sim.gd`'s `paint()`
  already stands a packed row, so the harness is ready for it.
- **The economy sim assumes a perfectly-played town.** An average one earns less;
  I did not measure how much less beyond the single mid-game row.
- **`tool_plague_sim.gd` cannot run on master** — it references
  `PLAGUE_DRAIN_PER_HOUR`, which only exists on the two-strain branches. Header
  says so and gives the worktree recipe.
