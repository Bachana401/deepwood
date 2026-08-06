# QA FINDINGS — the audit of the suite itself

**Department:** QA · **Branch:** `claude/focused-pike-23c680` · **Base:** `86b2c9d`
**Suite state at time of writing:** 130 registered, 130 accounted for, **128 green**,
2799 assertions passed. Both reds are one fact: `test_fire_node.gd` was never committed (§4).

The brief was: this suite has a known way of lying, and nobody has audited how far it
goes. This is how far it goes.

---

## 0. THE TAXONOMY

Six distinct ways a green test can mean nothing. Naming them matters more than the
individual fixes, because the fixes are done and the next one is not.

| # | Name | Shape | Caught by |
|---|---|---|---|
| 1 | **Never runs** | The file exists; `all_test_files.txt` does not list it. Suite still prints ALL PASS. | `test_registry_node.gd` |
| 2 | **Cannot fail** | The assertion is true by construction: a literal, a type that cannot be otherwise, a loop over an empty table. | eyeballs; §1 |
| 3 | **Unexercised negative** | Asserts nothing bad happened, with nothing forcing the bad thing to have had its chance. | eyeballs; §1.6 |
| 4 | **Never reached by the clock** | Tests a sub-tick by hand that, in play, runs alongside twenty-four others that can undo it. | `test_realclock_node.gd` |
| 5 | **Asserted by a test, called by nothing** | Pins a function no shipping code calls — a promise the UI makes and the game does not keep. | the sweep in §3.1 / §3.3 |
| 6 | **Exit 0 with nothing run** | The autoloads never instantiate, the driver is never attached, and the process still exits 0. Every test reports ok having run none of them. | `tool_run_suite.sh` (§7.1) |

Varieties 3, 5 and 6 are new to this document. Variety 3 came from the lead's own
`test_hollowsun_node` rewrite and is, I suspect, the most common of the six in any suite
that observes a live AI. Variety 6 is the worst of them — it is the whole suite at once —
and it was found by accident, from a command left running since the first minute of this
session (§7.1).

---

## 1. ASSERTIONS THAT COULD NOT FAIL

### 1.1 Strengthened — asserted the literal `true` (8 sites)

Line numbers are where the defect **was**.

| Site | Claimed to test | Why it could not fail | Now asserts |
|---|---|---|---|
| `test_adventurer_node.gd:194` | adventurers survive the save round-trip | literal `true`, with the note *"tool_save_audit enforces"* — but `tool_save_audit` is hand-run, so **nothing in the suite enforced it** | `game_state.gd` writes `"adventurers": adventurers` **and** reads it back via `parsed.has(...)` / `adventurers = parsed[...]` |
| `test_audit_node.gd:47` | `get_bonus_total(k)` works on a fresh game | literal `true`, **×8 keys** — eight always-passing slots from one line | `is_finite(v)`. A NAN out of here poisons every stat it touches and compares false against everything |
| `test_bossfree_node.gd:65` | no coroutine resumed on a freed boss | literal `true`. Reaching the line *is* real evidence (an unguarded resume kills the process) — but it also passed in the case that makes the whole test worthless: **the bosses never being freed at all** | every boss was freed, **by instance id**. A freed object compares equal to `null`, so the obvious form of this check is dead code |
| `test_melee_node.gd:391` | crit character applies only to melee | literal `true` — a section heading wearing an assertion's clothes | deleted; it is a comment now. The bow check on the next line was always the real claim |
| `test_saveload_node.gd:74` | gold survives to the coin | literal `true`, noted *"key checked below"* | what `load_game()` genuinely owes at that point: `in_dungeon` / `harvest_at_home` / `feast_glow` all cleared |
| `test_saveload_node.gd:149` | **the dev's real save was restored byte-for-byte** | literal `true`. The one check in the suite that must never be a literal | actually compares the bytes; asserts absence in the no-save branch |
| `test_underground_node.gd:552` | the dig stopped inside rock | literal `true` in an `else:` — a "not applicable" note **scoring as a PASS** | no water was left inside solid rock (a real invariant that holds on that branch) |
| `test_wavesides_node.gd:60` | siege_manager + both walls present | literal `true`, unreachable-if-false (the guard above early-returns) | west really is west of east, and both joined `village_wall` |

### 1.2 Strengthened — tautology by type (1 site)

**`test_plots_node.gd:190`** claimed *"refresh reads which building works which ground"* and asserted:

```gdscript
GameState.building_plots != null and typeof(GameState.building_plots) == TYPE_DICTIONARY
```

`building_plots` is declared `var building_plots: Dictionary = {}` — statically typed, so it
can never be null and `typeof` can never be anything else. **The check was true before
`refresh_layout()` ever ran**, and the test had hand-forced `{"Mine": "vein"}` a few lines
earlier with no Mine anywhere near the vein. It now recomputes the expected map from where
the buildings actually stand and demands equality, so the stale hand-forced value must be
gone for it to pass.

### 1.3 Strengthened — vacuous loops (2 sites)

`test_eventboss_node.gd:122` and `:170` set a flag, looped `ev.get("extras", [])`, and
cleared the flag on a miss. An empty or missing `extras` key means the loop never runs and
the flag stays `true` — a refactor that dropped every guaranteed extra would leave both
green. Non-emptiness is now pinned first.

*Audited and found already guarded:* ~40 other flag-loop sites. This idiom is otherwise
disciplined in this suite — `test_districts`, `test_plots`, `test_lights`, `test_arena` and
the rest all assert non-emptiness immediately before the flag check. Worth knowing so
nobody re-audits it.

### 1.4 Strengthened — the audio check (the lead's specimen), 4 holes in one block

`test_weapons2_node.gd:296`. Every one of these is a different variety:

1. **Never runs (variety 1, in miniature).** It walked a hardcoded `["crack","pop","thump","whoosh","chime","tear"]` while the roster grew to 14. The eight village sounds were untested. Now walks `SfxSynth.RECIPES`.
2. **Cannot fail (variety 2).** `_bank(r).data.size() > 0` **structurally cannot** catch the bug the block exists to catch: an unknown recipe falls through `match` to a default arm returning silence, so a name that does not exist passes. `"thud"` for `"thump"` shipped mute at two real call sites with this green.
3. **The trap is now pinned in place.** An explicit assertion that `_bank("definitely_not_a_recipe")` *does* return a non-empty buffer while `has_recipe` rejects it — so the next person to reach for sample count as an existence test hits a comment explaining why it isn't one.
4. **My own sweep could not fail.** The call-site regex sweep reports "no bad names" whether the repo is clean or the pattern matched nothing. It now asserts it matched ≥20 real call sites. This one nearly shipped, in the file whose whole subject is checks that cannot fail.

**Deliberate deviation from the patch you sent:** the sweep is **repo-wide** (root `.gd`,
skipping `test_*`/`tool_*`), not the hand-written file list. A hand-kept list of files to
check drifts exactly the way the recipe list did — using one to fix static-list drift would
have reintroduced the disease one level up. It also matches only `play_at|ui|village`:
`play_stream_at` takes an `AudioStream`, not a recipe, and the looser pattern misreads it.
Roster-vs-`match` drift is now checked in both directions, with arm count equal to
`RECIPES.size()`. Result: 0 bad names across 38 literal call sites.

### 1.5 Strengthened — magic numbers (4 sites)

`test_eventboss_node.gd:23, 51, 220` read `ids.size() == 12`, `weps.size() == 24`,
`hunt.size() == 12`. **They read 11 and 22 last week.** That is the tell: they pinned the
roster's *size*, not its *shape*, so they go stale every time content lands. Replaced with
the design's actual promises — the hunt is ten, everything beyond it is item-summoned only,
every event carries its own pair (`weps.size() == ids.size() * 2`), the Chronicle lists
`ids.size()`. Those cannot go stale.

### 1.6 The unexercised negative (variety 3) — your `test_hollowsun_node` case

This deserves its own name and it is not in the four categories above.

> *"not one building was harmed by the fight"* passed — **not because the town was safe,
> but because the boss's meteors happened not to fall near a building during the
> observation window.**

It is not a literal, and it is not unregistered. It is a **negative assertion with no proof
the mechanism was ever given its chance**. It can fail — just never for the reason in its
name. Any suite that observes a live AI is full of these, because "I watched and nothing
happened" is the cheapest thing to write and the least it can mean.

**The rule, stated so it can be applied:** *a negative assertion needs a positive control.*
Before asserting X did not happen, force the conditions under which X **would** happen, and
prove the mechanism fires at all. Your rewrite does exactly this — it drives
`_raze_ground_at` deliberately, then checks the reverse (an ordinary boss still cannot touch
a building). That is the pattern; it should be the house response to variety 3.

I applied the same rule to my own work: `test_realclock_node`'s
*"a wounded but healthy villager still mends"* exists solely as the positive control for
*"a sick body does not mend"* — without it, a regen that silently broke for **everyone**
would read as the sick-exemption working.

**One small note on the rewrite, offered as an observation, not a defect:**
`test_hollowsun_node.gd:532` asserts
`BS.BOSS_RAZE_DAMAGE * 4 < GameState.BUILDING_MAX_HEALTH` under the name *"the damage is NOT
scaled by the floor-100 curve"*. It compares two constants, so it can fail — but only if
someone edits a constant, never if a runtime multiplier appears, which is what the name
claims to guard. Call it **misaimed rather than unfalsifiable**. The behaviour is already
covered by the neighbouring 41-hit floor check, so nothing is missing; the name just
promises more than the line does.

### 1.7 On the two flakes you fixed in `test_sickness_node.gd`

**I agree with the approach, and it is the one I want as house policy.** Isolating the
property under test beats seeding the RNG, for a reason worth writing down: a seeded RNG
makes the test deterministic *and* makes it pass for a reason that has nothing to do with
the property — the moment the production code changes how many times it calls `randf()`,
the seed shifts and the test breaks without any behaviour changing. It converts a flake
into a brittle, and brittle tests get deleted.

I used the same rule rather than seeding: every measurement window in
`test_realclock_node` is kept **under 24 in-game hours**, because `_sickness_day` rolls the
cure at the day boundary. Your reorder (cure before reaper) is precisely why — a stray
boundary inside a window would turn a death assertion into a coin flip.

### 1.8 Left alone, with reasons

- **Source-text assertions — 134 of 894 checks (15%)** read a `.gd` file and assert
  `.contains("...")`. They are weak (they prove wiring exists, not that it works) but they
  are **not** unfalsifiable — a refactor genuinely breaks them, and several are the only
  guard on a save key. Concentrated in `test_arrival_node` (24), `test_adventurer_node`
  (24), `test_construction_node` (15). **Recommendation:** do not mass-convert. Replace one
  when you are already editing that behaviour, and prefer a real round-trip where cheap.
- **`test_save_node.gd:68` / `test_summoner_node.gd:109`** use `is Dictionary` — flagged by
  the same scan as §1.2 but **legitimate**: both operate on `JSON.parse_string` output,
  which genuinely can be a non-Dictionary.
- **`test_underground_node.gd`'s `check()` takes only 2 arguments** where every other driver
  takes 3. Not a defect, but it is a trap: a 3-argument call there is a **parse error**,
  which in this project presents as a six-minute timeout. It cost me one. Left as-is
  because changing a signature used 113 times is churn, not coverage.

---

## 2. REAL-CLOCK COVERAGE GAPS

### 2.1 The finding

**Every one of the ten new village systems is tested by calling its own sub-tick directly
with hand-seeded state. Not one drove `tick_village_clock()`.**

```
test_adjacency_node   -> tick_mine_yield(240.5)          test_patrols_node   -> tick_patrols(24.0), _patrol_earnings(24.5)
test_plots_node       -> tick_mine_yield(240.5)          test_sickness_node  -> tick_sickness(...)
test_auras_node       -> tick_rot(1.0), tick_morale_effects(1.0)
test_lodging_node     -> update_cottage_families(...)    test_schooling_node -> auto_enroll_children(99)
test_districts_node   -> building_output_multiplier()    test_eclipse_node   -> tick_eclipse(24.0)
```

In play, `tick_village_clock()` calls **twenty-five sub-ticks in a fixed order, every
frame**, with `hours_passed ≈ 0.0025` (`HOURS_PER_SECOND` is 0.04 — an in-game hour is 25
real seconds). Two things only the real clock can show:

- **ORDER.** A later sub-tick can undo an earlier one in the same pass.
- **WIRING.** A sub-tick that works perfectly when called by hand proves nothing about
  whether the clock still calls it.

### 2.2 The confirmed instance (now fixed — measurements kept for the record)

`tick_sickness` ran at line 2250; `tick_morale_effects` regenerated HP at 2264, with **no
exemption for the sick**. `SICK_DRAIN_PER_HOUR` 2.4 against `DESPAIR_HP_REGEN_PER_HOUR` 3.0.

| setup | 8 in-game hours, before the fix |
|---|---|
| sick, no ward | 50.00 → **54.80** HP |
| sick, inside the Hospital aura | 50.00 → **85.36** HP |
| the same 8h via `tick_sickness` alone — how the suite tested it | 50.00 → **30.80** HP |

Net **+0.6 HP/hour while ill**; `_reap_the_sick()` could never fire. The ward *cured* a
plague victim faster than the plague hurt. The constant's own comment claimed it "outruns
the passive regen on purpose". Two tests each passed and the combination was broken:
`test_sickness_node` never ran the regen, `test_auras_node` never ran the drain.

### 2.3 What is covered now

`test_realclock_node.gd` drives `tick_village_clock()` in 0.25h steps. Assertions are chosen
so that **none of them can be made by a direct-call test**:

- an ordinary illness **stops the mending** — a fact about `tick_morale_effects`, a different sub-tick from `tick_sickness`
- **(positive control)** a wounded but healthy villager still mends
- an ordinary illness never takes anyone (1 HP, 20 hours)
- the plague drains, kills, and is softened-but-not-cured by the ward
- **wiring:** patrol pay, block creep, the Mine's day cycle all still reached by the clock
- a tick with no time in it is free (`hours_passed` is a difference, not a per-call charge)

### 2.4 Still uncovered, ranked by how much a bug could hide there

1. **`tick_fire`** *(clock line 2251)* — no real-clock coverage, and `test_fire_node.gd` is not in the tree at all (§4), so it currently has **no** coverage. It burns building health in the same pass as the Builderhouse auto-repair, which is the *same shape* as the sickness bug: one tick damages, another heals. **This is where I would look next.**
2. **`tick_eclipse`** *(2252)* — `test_eclipse_node` calls `tick_eclipse(24.0)` and `(0.5)` directly. Lower risk (it mostly sets flags) but the day-length interaction with `day_night_cycle.gd` is unproven under real steps.
3. **`tick_food` → `tick_morale_effects`** — the starve drain and the regen are in the same `if hours_passed > 0.0:` block. The sick exemption is now there; the starving branch and the regen branch are mutually exclusive by construction, so this looks sound, but it is untested under the real clock.
4. **`update_cottage_families` / `auto_pair_couples`** — the population loop crosses both clock surfaces (`tick_village_clock` and the income-timer `apply_leadership_automation`) and nothing drives both together.

### 2.5 Cleared

- **`apply_leadership_automation()`** — the *other* clock surface (income timer, not the village clock) — **is** driven for real by `test_autoladder_node` and `test_economy_node`.
- **Schooling graduation** is driven through `tick_village_clock()` by `test_clock_node`.

---

## 3. PRODUCT BUGS — Mechanics' queue

### 3.1 🔴 `villager_has_plague()` is read by nothing but a test

**Variety 5.** *(Found by the dead-accessor sweep, §3.3; the same shape as the `floor_is_road_blocked()` case
you already wired.)*

- **File:** `game_state.gd:4546`
- **Current:** `morale_meter.gd:143-147` shows a single `🤒 %d SICK — %s` line built from
  `sick_count()`. `village_morale()` (`game_state.gd:4053-4054`) *does* weigh `plague_count()`
  separately at `PLAGUE_MORALE_PER_CASE` vs `SICK_MORALE_PER_CASE` — **so the model knows
  the difference and the player has no way to.**
- **Why it matters:** a town with three colds and a town with three plague cases read
  identically. The cold cannot kill; the plague can, and is depth-30 gated so it only ever
  appears once the player is far from home. The whole design of the outbreak is *"the town
  asking you to come home"* — and the one strain worth coming home for is invisible.
- **Proposed change** (`morale_meter.gd`, the block at :143):

```gdscript
var ill: int = GameState.sick_count()
var pl: int = GameState.plague_count()
if ill > 0:
    if pl > 0:
        lines.append("☠ %d PLAGUE, %d sick — %s" % [pl, ill - pl, ward_note])
    else:
        lines.append("🤒 %d SICK — %s" % [ill, ward_note])
```

  …and, if the villager sheet lists health, `villager_has_plague(id)` is the flag that tells
  a player which body to carry to the ward.

### 3.2 🟠 Machine state leaks into every test run — `deepest_level.dat` is not sidecarred

**This one is invisible to clean-clone verification, which is why it has survived.**

- **File:** `game_state.gd:15` — `const DEEPEST_LEVEL_PATH = "user://deepest_level.dat"`
- **Current:** `active_save_path()` (`game_state.gd:11`) correctly redirects the save to
  `user://savegame_test.json` under `MONARCH_TEST`. **`DEEPEST_LEVEL_PATH` has no such
  branch.** `load_deepest_level()` is called from `GameState._ready` (:2149) on every test
  process, and **`reset_for_new_game()` does not clear `deepest_level_reached`.**
- **Measured on this machine** (scratch probe, run today):

```
deepest_level_reached at test start = 100
plague_is_possible()                = true   (PLAGUE_MIN_DEPTH = 30)
plague_is_possible() after reset    = true
```

- **Why it matters:** `plague_is_possible()` is `deepest_level_reached >= 30`. On the dev's
  machine that is **permanently true in every test**. On a fresh machine, on CI, or for a
  second developer, the file does not exist, the value is 0, and it is **permanently false**.
  The plague half of the new sickness system is silently on for one person and silently off
  for everyone else, and any test that does not set `deepest_level_reached` explicitly
  behaves differently in the two environments. Six tests do set it (`test_sickness`,
  `test_autoladder`, `test_caravan`, `test_eventstorm`, `test_lantern`, `test_weeping`) —
  the rest inherit whatever the machine happens to hold.
- **Why the clean clone does not catch it:** `user://` resolves by **project name**, not by
  checkout, so every clone of Deepwood on this machine reads the same
  `app_userdata/Deepwood/deepest_level.dat`. My clean-clone verification read 100 too. Only
  a fresh machine, or wiping `app_userdata`, exposes it.
- **Proposed change** (`game_state.gd`, alongside `active_save_path()`):

```gdscript
func deepest_level_path() -> String:
    if OS.has_environment("MONARCH_TEST"):
        return "user://deepest_level_test.dat"
    return DEEPEST_LEVEL_PATH
```

  …used by `load_deepest_level()` (:7234) and `record_level_reached()` (:7240). Also worth
  deciding whether `reset_for_new_game()` should zero `deepest_level_reached` — it is
  documented as a high-score stat that survives runs, so possibly not, but the test harness
  needs a clean floor either way.
- **Latent, not yet live:** `record_level_reached()` is called only from
  `dungeon_interior.gd:2030`. No current test reaches it — `deepest_level.dat` has not been
  written since 12 Jul across roughly 400 test launches today. But any future test that
  enters a dungeon level would permanently raise the dev's own record.

### 3.3 ⚪ Dead accessors — low priority, listed for completeness

Functions with zero non-test callers. Most are probably benign; two I verified as **false
alarms and not worth your time**: `eclipse_is_pending` (`day_night_cycle.gd` reads the
eclipse via `eclipse_progress()`) and `building_power_name` (`assign_ui.gd:253` reads
`BUILDING_POWERS` directly). Remaining, unverified:

`all_loot_ids` · `any_live_mob` · `doctor_alive` · `get_weapon_stats` · `go_to_level` ·
`live_count` · `restore_building` · `build_legacy_strip`

---

## 4. THE REGISTRY — both directions

### 4.1 The state found

`all_test_files.txt` is a static registry: a test that exists and is not listed **never
runs, and the suite still prints ALL PASS**. Both directions are dangerous, and the second
is the one nobody expects:

- **On disk, not listed** → dead coverage. Silent.
- **Listed, not on disk** → `main_menu.gd:51` guards the hook on
  `ResourceLoader.exists()`, so a dead name **attaches no driver at all**, the menu idles,
  and the run presents as a **six-minute timeout** rather than a missing test.

### 4.2 What is in place

**`test_registry_node.gd`** diffs the registry against the disk in both directions and also
refuses: duplicate entries, garbage lines (a path, a `.gd`, a comment), an out-of-order
list, and a registered slot holding a stub that is not a `Node` with `_ready` and
`get_tree().quit()`. Scratch probes are exempt by **one documented prefix, `test_zz*`** —
that is the only escape hatch, and it sorts to the end of a directory listing so it stays
visible.

**`test_audit_node.gd:82`** asserts that `test_registry_node` is still *in* the registry.
A guard nobody registers is no guard; disarming it now takes two files going red rather
than one line going missing.

**`tool_run_suite.sh`** checks the same thing from outside the engine, reports
`NO SUCH FILE` in under a second instead of burning the timeout, and asserts that the number
of tests **run** equals the number **registered**.

### 4.3 Live catches

1. Its own two new tests, on first run — before they were registered.
2. **🔴 `test_fire_node` is registered and `test_fire_node.gd` is not in the tree.** It
   exists on disk in the `gifted-murdock-786925` worktree, so the suite is green for its
   author and broken for everyone else. This is the second time this exact thing has
   happened in this repo. **Fix: `git add test_fire_node.gd`.** Both current suite reds
   clear the moment it lands.

### 4.4 The same drift, one file over — `.gd.uid`

329 `.uid` files are tracked, so a test committed without its sibling leaves every clean
clone with a dirty tree on first import. The runner's pre-flight has now caught **four**,
i.e. every recent test commit: `test_patrols_node`, `test_sickness_node`,
`test_eclipse_node`, `test_hollowsun_node`. All four are included in this branch.

---

## 5. THE `test_arrival_node` TRANSIENT

**Characterised. Not reproduced.** Both are results.

- **73 bytes is exactly the engine banner plus the blank line after it.** Measured against
  the suite's logs; the smallest *normal* log in the whole suite is 117 bytes.
- So the process exits 1 having printed **nothing of its own** — not even
  `TouchControls: active=false`, which is the first line every run prints. **The test never
  reported; it may never have started.**
- **It is not the missing-script path.** A name `ResourceLoader.exists()` cannot resolve
  idles at the menu and times out; it does not exit 1 in seconds.
- **Mechanism that fits the evidence:** stderr redirected to a file is **fully buffered**
  (~4 KB). A complete arrival log is 2306–2555 bytes — *under* the buffer. An abnormal exit
  discards the whole buffer and leaves only the banner, which the engine flushes at startup.
  If that is right, **the fault is at shutdown, after every check has already passed.**
- **Supporting:** 74 of 107 baseline logs end with `ObjectDB instances were leaked at exit`
  + `resources still in use at exit`. Arrival leaks 6 objects / 3 resources — and in **3 of
  14** repeat runs the warning did not appear at all, so the shutdown path itself varies run
  to run. (Leaking is the norm here, not arrival-specific — so this predicts **any** test
  can hit it, and arrival is simply the one that got noticed.)
- **14 consecutive runs under deliberate concurrent load: 14 passes, 0 reproductions**,
  identical 36 checks each time.
- **Mitigated regardless:** `tool_run_suite.sh` classifies a non-zero exit with **no
  `RESULT:` line** as `CRASH`, not `FAIL`, and retries once. A shutdown fault can no longer
  turn a green suite red or be mistaken for a broken test.
- **To settle it for good:** run the suite once with stderr line-buffered (`stdbuf -eL`).
  If the log then contains the full run *and* exit 1, the shutdown theory is confirmed and
  the fix is an engine-level cleanup, not a test change.

---

## 6. MEASURED ALL-CLEAR — where not to spend effort

Everything here was checked and found sound. Listed so nobody re-checks it.

| Checked | Method | Result |
|---|---|---|
| `.size() >= 0` / `>= -1` tautologies | regex over all 894 `check()` call sites | **zero instances.** The five `size() > 0` checks are real non-emptiness assertions |
| "asserts what the test just set" | script: check condition reads a field assigned within 3 lines above | **12 candidates, 12 false positives.** Every one sets the *opposite* value first, then runs the system under test — correct practice |
| Silently skipped assertions | declared `check(` sites vs `PASS`/`FAIL` lines in all 125 baseline logs | **largest gap: 2** (`test_mech2`, `test_dungeon_layout`), both legitimate branch guards. This suite runs essentially every assertion it declares |
| Flag-set-in-loop vacuity | ~40 sites audited by hand | all but the 2 in §1.3 already assert non-emptiness first |
| Registry drift, both directions | `test_registry_node` | in sync apart from `test_fire_node` (§4.3) |
| Test file shape | `test_registry_node` | all 129 are `extends Node` + `_ready` + `quit()`. No stubs, no dead slots |
| Leadership automation coverage | caller trace | driven for real by `test_autoladder_node` + `test_economy_node` |
| Committed tree ≠ working tree | clean clone of the branch, fresh import, targeted re-run | identical behaviour. *(Note the limit: this cannot catch §3.2, because `user://` is keyed by project name, not by checkout.)* |
| Suite baseline before any QA edit | full run on `afc8b15` | 125/125 green — nothing in this branch broke anything that was working |

---

## 7. THE RUNNER — `tool_run_suite.sh`

```bash
bash tool_run_suite.sh              # everything
bash tool_run_suite.sh sickness     # substring filter
SUITE_LOGS=/some/dir bash tool_run_suite.sh
```

### 7.1 Variety 6 — the whole suite passing with nothing run

Found by accident, and it is the most complete lie the harness can tell. The very first
command of this session was a single smoke test on a **fresh worktree with no `.godot`
import cache**. It appeared to hang; I moved on and imported explicitly. It finally
reported hours later, and this is the chain in its log:

```
ERROR: Cannot open file 'res://.godot/imported/PixelifySans.ttf-….fontdata'
SCRIPT ERROR: Parse Error: Could not preload resource file "res://art/fonts/PixelifySans.ttf"
SCRIPT ERROR: Parse Error: Cannot infer the type of "GAME_FONT" constant …
ERROR: Failed to load script "res://mobile/touch_controls.gd" with error "Parse error"
ERROR: Failed to instantiate an autoload, script 'res://mobile/touch_controls.gd' …
SCRIPT ERROR: Invalid call. Nonexistent function 'has_save'            in base 'Nil'
SCRIPT ERROR: Invalid access to property 'deepest_level_reached'       on base 'Nil'
SCRIPT ERROR: Invalid call. Nonexistent function 'reset_for_new_game'  in base 'Nil'
EXIT=0
```

Read it in order. An **unimported font** makes a `preload` fail; the failed preload makes
`const GAME_FONT` untyped, which is **house rule 1 — variant inference is a hard error
here** — triggered by a missing resource rather than by anything anyone wrote. That script
is an **autoload**, so every autoload dies with it and `GameState` becomes `Nil`.
`main_menu.gd:52` calls `GameState.reset_for_new_game()` and throws **before it can attach
the test driver**. Nothing runs. **And the process exits 0.**

A runner that trusts the exit code reports `ok` for all 130 tests having executed none of
them. Mine did. Two changes:

- **A pass is a *reported* pass.** Exit 0 now also requires a `RESULT:` line in the log —
  every driver ends by printing one. Without it the run is classed `CRASH`, not `ok`, and
  the first parse/autoload/`Nil` lines are printed. *(Verified against the real log above:
  the predicate correctly rejects it and prints the three lines that explain why.)*
- **The runner imports first if `.godot` is absent**, so that state cannot be what gets
  measured.

This is also the honest answer to why "it looked like a hang": a cold tree spends a very
long time before it fails, so the first symptom is indistinguishable from a slow test — the
same confusion the project already documents for parse errors, one level further out.

**Timing.** A full run is **~17.5 minutes** for 129 tests (measured end-to-end from log
timestamps). Median test ≈ 4 s. The distribution is extremely lopsided:

| test | time |
|---|---|
| `test_realhits_node` | **244 s** — 23% of the entire suite |
| `test_underground_node` | 84 s |
| `test_hollowsun_node` | 39 s |
| `test_weapons2_node` | 31 s |
| everything else | ≤ 26 s |

If the run ever needs to be faster, `test_realhits_node` is the whole conversation.

### 7.2 Order dependence

**None — but it is not parallel-safe, and that is not the same thing.**

- Each test is **its own Godot process**, so no in-process state survives between tests.
  Order genuinely does not matter.
- But every process shares two on-disk paths: `user://savegame_test.json` (the
  `MONARCH_TEST` sidecar) and `user://deepest_level.dat` (**not** sidecarred — §3.2). Two
  tests running concurrently would clobber each other's save. **Keep the runner serial**
  until §3.2 is fixed and the sidecar is made per-process.
- The `.godot` import cache is also shared; a first run on a fresh checkout must
  `--import` once before anything will pass -- the runner now does this itself (§7.1),
  because the state it prevents reports as a green suite, not as an error.

### 7.3 What it knows that a bare loop does not

1. A **parse error is not a timeout.** A test that does not compile attaches nothing, the
   menu idles, and it looks like a six-minute hang. The runner caps each test and, on a
   timeout, re-checks with `--check-only` and says `PARSE ERROR` or `HANG`. *(This is not
   theoretical — it cost me a run today: a 3-argument `check()` in a file whose `check()`
   takes 2.)*
2. A **registered name with no file** is neither of those, and is reported instantly.
3. A **crash at exit is not a test failure** (§5): non-zero exit with no `RESULT:` line is
   `CRASH`, retried once.
4. **Tests run must equal tests registered**, or it exits 3.
5. It warns on test scripts committed without their `.gd.uid` sibling (§4.4).

**Judgement call for the lead to veto:** QA's territory is `tool_*.gd`; this is
`tool_*.sh`. `build_mobile.sh` and `gen_codemap.sh` set the precedent for shell scripts at
the repo root, and a suite runner cannot usefully live inside the engine it launches. Say
the word and it moves.

---

## 8. WHAT I DID NOT DO

- **Did not fix any product bug.** §3 is Mechanics' — `game_state.gd`, `morale_meter.gd`
  and the rest are not QA's files. Both entries are written as exact patches.
- **Did not codify the variety-5 sweep as a test.** Between bare callables passed to
  `.connect()`, `call()` by string, and `.tscn` references, the naive version has a high
  false-positive rate — my own first pass returned 22 candidates and 10 survived correction.
  A red nobody trusts is its own disease. The method is recorded in §3.3; say the
  word and it becomes a hand-run `tool_`.
- **Did not touch `test_fire_node` or the eclipse/fire real-clock gap** — the fire system
  has no committed test to extend (§4.3), and I will not write one against code I cannot
  see fail.
- **Did not mass-convert the 134 source-text assertions** (§1.8). Deliberate; the reasoning
  is there.

---
---

# QA FINDINGS — 2026-08-06, second pass: FIRE UNDER THE REAL CLOCK

**Department:** QA · **Branch:** `master` · **Base:** `d6c7b9e`
**Suite:** 130 registered, 130 run, green. `test_realclock_node.gd` grew from 11
assertions to 23; no new file, no new registry line.

Last pass ended with a prediction: *`tick_fire` burns building health in the same pass
the Builderhouse auto-repair heals it — the same shape as the sickness bug.* This is that
measurement. **The prediction was right, and the real answer is worse than the shape
suggested**, because the two halves are not even in the same function.

---

## 9. THE FIRE IS A NET HEAL IN ANY STAFFED TOWN — Mechanics' queue

### 9.1 What was measured

`_process` runs **two** things per frame, not one:

```gdscript
if income_timer >= INCOME_INTERVAL_SECONDS:      # 20 REAL seconds
    income_timer -= INCOME_INTERVAL_SECONDS
    generate_passive_income()
    apply_leadership_automation()               # <- the crew's MEND lives here
tick_village_clock()                            # <- the fire's BURN lives here
```

The burn is billed per **in-game hour**. The mend is billed per **real second**. Nothing
in the suite had ever driven both, so `run_clock_full()` was added to
`test_realclock_node.gd` (and `run_frame()` to `tool_peril_sim.gd`) to drive the whole
frame the way `_process` does.

Measured, one hall alight at half health, 6 in-game hours, identical windows
(`tool_peril_sim.gd`, section F4):

| Builderhouse hands | burn after suppression | end health (from 200) | net per in-game hour |
|---|---|---|---|
| 0 | 26.0/hr | 44.0 | **-26.00** |
| 1 | 20.3/hr | 255.9 | **+9.31** |
| 2 | 14.6/hr | 246.8 | **+7.80** |
| 4 | 3.1/hr | 359.4 | **+26.57** |
| 8 | 2.6/hr | 318.8 | **+19.79** |

**A single hand on the crew flips fire from a cost into a gain.** The hall does not merely
survive the blaze; it comes out of it healthier than it went in.

### 9.2 Why — the arithmetic, in the unit that decides it

An in-game hour is 25 real seconds (`HOURS_PER_SECOND = 0.04`), so the honest comparison
is per real minute:

* fire: `FIRE_DAMAGE_PER_HOUR 26.0` -> **62.4 health per real minute**
* mend: `MEND_PER_PASS 45` every `INCOME_INTERVAL_SECONDS 20` -> **135.0 health per real minute**

The repair beats an **unsuppressed** blaze **2.2 to 1 before a drop of water is thrown**,
and `_auto_mend_one` picks the *most badly hurt standing hall* — which, during a fire, is
always the hall that is on fire. Each hand then also subtracts `FIRE_CREW_SUPPRESS 0.22`
from the burn, so the gap widens with every worker seated.

This is the same failure the douse-roll clamp already had to fix once: **a system that
switches itself off the moment the crew is staffed.** The clamp fixed the daily roll; the
hourly half still has it.

### 9.3 The patch — `game_state.gd`, `_auto_mend_one()` (currently line 6832)

Two lines. No crew patches a roof that is still alight:

```gdscript
 func _auto_mend_one() -> void:
 	var hurt := ""
 	var lowest := BUILDING_MAX_HEALTH
 	for bn in STARTING_BUILDINGS:
 		if not is_building_operational(bn):
 			continue
+		# NOT WHILE IT BURNS. _auto_mend_one always targets the most badly hurt
+		# standing hall, which during a fire is the hall that is on fire -- and the
+		# mend (45 per pass, every 20 real seconds = 135/real-min) is worth more than
+		# twice the burn (26/in-game-hour = 62.4/real-min). One Builderhouse hand
+		# turned a blaze into +9.31 health an in-game hour. Measured: QA_FINDINGS 9.1.
+		if building_is_burning(bn):
+			continue
 		if get_tree() != null and get_tree().get_first_node_in_group("building_role_" + bn) == null:
 			continue
```

`building_is_burning()` already exists (`game_state.gd:4498`) and is already read by
`morale_meter.gd`, so nothing new is introduced.

**The design question that comes with it (the lead's, not QA's):** the crew's water alone
already makes fire survivable — 4 hands stretch a hall's life from 15.5 in-game hours to
128.3 (6.5 real minutes -> 53.4). With the guard applied, that is what fire costs a staffed
town, which reads as the intent of the code's own comment (*"a big blaze outruns a small
crew, so it is your emergency too"*). QA is not proposing a number change.

### 9.4 The second-order number, for Balance

Even with the guard, **the aftermath is nearly free**: 135 health of mending per real
minute puts a hall gutted down to 5% back at full in well under three real minutes, for
`MEND_WOOD 1` + `MEND_STONE 1` per pass. The scar the `building_condition()` term was
added to make matter is erased faster than the player can walk to it. That is a tuning
call, not a bug, and it is stated here so nobody has to measure it twice.

---

## 10. WHAT THE REAL CLOCK SAYS IS **CORRECT** ABOUT FIRE — measured all-clear

Everything else in `tick_fire` survived the wiring audit. Do not spend effort here.

* **The burn is real and nothing hands it back.** A hall alight lost exactly
  `FIRE_DAMAGE_PER_HOUR x hours` across 24 quarter-hour clock steps (400 -> 244.0 over 6
  in-game hours, predicted 244.0). Its unlit neighbour, same window, lost nothing.
* **The live node hears about it while it burns**, not only when the hall falls —
  `_resync_building_health` fires every hour and the node's cached `health` tracked
  GameState to within 1. (This was a real bug last round; it is fixed, and now guarded
  under the clock rather than only under a hand-called `tick_fire`.)
* **A blaze bills by the HOUR, not by the tick.** 40 ticks with zero in-game time in them
  cost the hall nothing; one step with time in it did. If this ever inverts, every fire in
  the game runs at frame rate.
* **The daily roll rides the same clock as the burn.** 24 quarter-hour steps advanced
  `_fire_accum` by exactly 6.000 in-game hours — the spread/douse roll cannot fire 60 times
  a second.
* **Gutting works through the clock**, knocks the hall back one stage, never below zero,
  and puts the fire out; the identically-wounded hall beside it that was not alight kept
  its stage.
* **The hamlet gate holds.** 4 standing halls, 400 trials, up to 4,000 in-game days each:
  never once caught. `FIRE_MIN_BUILDINGS` is real.
* **The suppression clamp holds.** 6 hands and 8 hands both cap at 2.6 health/hour
  (`0.9`), so a large crew makes fire survivable rather than impossible.

### 10.1 Fire's shipped feel, measured for the first time (`tool_peril_sim.gd`)

`STUDIO.md`'s Balance backlog says "fire is measured nowhere". It is now:

| how often a town catches | mean in-game days | real hours of play |
|---|---|---|
| 4 halls, no hearth | never | never |
| 6 plain halls | 9.1 | 1.5 |
| 6 halls, one Blacksmith | 7.1 | 1.2 |
| full town, every hearth standing | 3.0 | **0.5** |

**A finished town catches fire every half hour of play.** Whether that is the intended
drumbeat is the dev's call; it is stated here because until today it was unmeasured.

And what one fire takes with it, in a row of eight halls each standing next to the next
(300 trials each):

| hands | mean in-game days alight | mean halls that ever caught | worst seen |
|---|---|---|---|
| 0 | 43.1 | 4.72 | 8 of 8 |
| 1 | 4.7 | 2.31 | 8 of 8 |
| 2 | 2.2 | 1.67 | 7 of 8 |
| 4 | 1.4 | 1.32 | 5 of 8 |

The design claim — *the row that earns most is the row that burns whole* — is true, and
an unfought fire really can take all eight. One Builderhouse hand cuts a 43-day blaze to
under 5 days. The crew's **water** is doing exactly its job; it is only the **hammer**
(section 9) that is broken.

---

## 11. TWO MEASUREMENT BUGS IN THE SIM TOOLING — fixed, QA's own

### 11.1 Every headless sim seeded a battered town — **all economy figures were ~half**

`BUILDING_MAX_HEALTH` is **400**. Thirty seeding sites across twelve `test_*.gd` and
`tool_*.gd` files wrote `building_health[b] = 100`. That was harmless until
`building_condition()` landed and began multiplying `building_output_multiplier()`:

```
condition(100/400) = 0.35 + 0.65 x 0.25 = 0.5125
```

**Every simulated economy figure produced by this studio's tooling since the condition
term landed was scaled by 0.5125** — anything routed through
`building_output_multiplier()` was reported at just over half its true value.

That includes the numbers behind `STUDIO.md`'s standing ruling *"a maxed village
out-earns delving at every floor (95.0 g/real-min passive vs 90.4 delving at floor 80)"*.
The village half of that comparison was measured on a town that read as battered. **The
gap is wider than the ruling says, not narrower** — the ruling's direction is safe, its
magnitude is not. Re-running `tool_balance_sim.gd` / `tool_econ_sim.gd` is now worth doing.

Fixed at all 30 sites: `= 100` -> `= GameState.BUILDING_MAX_HEALTH` (plus one
`tool_eyes_fishing.gd` site that seeded `10000.0`, above max). Sites that deliberately
seed `0` for "this hall does not stand" were left alone.

### 11.2 `tool_peril_sim.gd` did not resolve at all

It read `GameState.SICK_DRAIN_PER_HOUR` in eight places. That constant was deleted by the
two-strain split: the ordinary illness now costs **no HP at all** (it suppresses the
passive regen), and only the plague drains, via `PLAGUE_DRAIN_PER_HOUR`. The file
therefore did not compile, which in this harness presents as **the menu idling and a
six-minute timeout** — house rule 1, paid for again.

Its sickness half was also dead science: every sweep in it tuned a constant that no longer
exists, and `tool_plague_sim.gd` already owns the two-strain measurement. So the file was
**retargeted at fire**, the one system the Balance backlog says is measured nowhere. It now
drives the whole frame (sections 9 and 10.1) and carries **one deliberate FAILING check** —
`F4: a fire in a STAFFED town still costs that town health`. Tools are not in
`all_test_files.txt`, so the red lives where it can be honest without breaking the suite.
It turns green the day 9.3 is applied.

### 11.3 A harness bug the fire measurement found in itself — worth knowing

`wage_accum_hours` is a member that survives every other reset, so a payroll left
part-counted by an earlier block lands inside a later measurement window — and **an unpaid
worker walks out mid-window** (`tick_wages`, `game_state.gd:6054`). The first run of the
fire sim read the one-hand row as a *completely unfought* fire, because that single hand
had quit in the first in-game hour. A crew that quits is indistinguishable from a crew that
never worked, and which it is depends on which block ran first.

`quiet_town()` in `test_realclock_node.gd` and `quiet()` in `tool_peril_sim.gd` now both
zero `wage_accum_hours` and fill `village_treasury`. **Any future village measurement must
do the same**, or it is secretly a wage test. This also removes a latent flake from the
existing patrol and mine blocks, whose 25-hour windows always crossed a payday.

---

## 12. THE DEAD-ACCESSOR SWEEP — variety 5, verified

All eight candidates from last round's unverified list, checked for non-test callers
across `*.gd` and `*.tscn`. **All eight have zero product callers.** They are not equally
interesting, and the difference is the point:

| accessor | defined | verdict |
|---|---|---|
| `restore_building` | `game_state.gd:1639` | **Dead, and a test proves the wrong path** — 12.1 |
| `go_to_level` | `dungeon_interior.gd:1538` | **Dead, and has DRIFTED from the live path** — 12.2 |
| `doctor_alive` | `game_state.gd:7487` | **Dead gate; the rule it names is enforced elsewhere** — 12.3 |
| `build_legacy_strip` | `underdark.gd:178` | Deliberate, documented test-only affordance — 12.4 |
| `live_count` | `underdark.gd:989` | **Fully dead — not even a test calls it.** Safe to delete. |
| `live_count` | `wilderness.gd:218` | Dead in product; a test-only handle. Harmless. |
| `any_live_mob` | `wilderness.gd:226` | Dead in product; a test-only handle. Harmless. |
| `get_weapon_stats` | `player.gd:170` | Dead one-line wrapper over `active_stats`, which the product reads directly. Harmless. |
| `all_loot_ids` | `event_boss.gd:237` | Test-only **aggregator over live data**. Keep — it cannot go stale, and the four tests using it assert real invariants. |

### 12.1 `restore_building` — the real re-place path is somewhere else

`build_placer.gd:222` does the erase inline:

```gdscript
GameState.removed_buildings.erase(build_name)
```

...so re-placing a razed building **does** work — but it works without ever touching
`GameState.restore_building()`, whose entire body is that one line.
`test_buildmenu_node.gd:29,42` calls the dead one. **The test exercises a path the game
never takes**, which is precisely the shape the road-cut gate had.

*Patch (build_placer.gd is not QA's):* line 222 becomes
`GameState.restore_building(build_name)`. One line, and the test starts meaning something.
Or delete `restore_building` and have the test call `removed_buildings.erase()` — either
is fine, but the two must not stay forked.

### 12.2 `go_to_level` — a dead duplicate that has since drifted

Floor-to-floor movement was removed; `dungeon_interior.gd:1530` says so in its own words
(*"floors are reached only by their doors"*). The live entry sequence is inside `_ready()`
at lines 464-474 and does **seven** things:

```gdscript
GameState.quest_event("reach_level", "", current_level)
_ensure_ambient()
build_level_visuals(current_level)
place_player_at_entry(false)
update_level_label()
setup_exit_button()
spawn_level_combat()
# ...plus the deep-shrine re-placement
```

`go_to_level()` does **three** of them. `test_cleared_node.gd:92` descends with it — so
that test builds its floor by a path that has already drifted from the real one (no quest
event, no ambient, no level label, no shrine). It has not produced a false green yet, but
this is exactly how one gets manufactured.

*Recommendation:* delete `go_to_level`; QA reworks `test_cleared_node` onto the live
sequence. Not done this pass — see section 13.

### 12.3 `doctor_alive` — the named rule is real, this function is not what keeps it

The design line is *"if she dies in a siege, the service dies with her."* That **is**
enforced — but by `npc.gd:913`, which returns false when `find_villager_data()` comes back
empty, not by `doctor_alive()`. Nothing in the product calls `doctor_alive()`.

And `test_adventurer_node.gd:264` "proves" the rule with
`check("the heal service dies with her (doctor_alive reads the roster)", GameState.has_method("doctor_alive"))`
— a **variety-2 assertion** (cannot fail) about a **variety-5 function** (nothing calls
it). The one real use is line 482, which reads it to verify an old-save migration; that use
is legitimate.

*Patch:* either have `try_doctor_heal()` gate on `doctor_alive()` (making house rule 7 true
of it), or delete it and rewrite the line-264 assertion against the real gate. QA did not
touch it — see section 13.

### 12.4 `build_legacy_strip` — honest, but three tests prove a world nobody walks

`underdark.gd:168` says it plainly: the legacy deep is no longer built, the cave mouth
routes to `underground.tscn`, and the strip is "kept for the suites that prove the layout's
contracts". `test_deepreach_node`, `test_doorloop_node` and `test_underdark_node` all build
it first. That is not a lie — but it is **three tests' worth of green spent on a layout no
player can reach**, and it should be a conscious choice rather than an inherited one. The
lead's call; QA changed nothing.

---

## 13. WHAT I DID NOT DO

- **Did not fix a single product bug.** 9.3, 12.1, 12.2 and 12.3 are written as exact
  patches for the file's owner. `game_state.gd` and `building.gd` were being edited by the
  lead during this pass and were never touched.
- **Did not make the suite red.** The fire finding is *pinned* in
  `test_realclock_node.gd` as an assertion of what is measurably true today, with the
  branch that should replace it written directly beneath it. When 9.3 lands, that pinned
  check fails — **that failure is the signal**, and the file says so at the failure site.
  The honest red lives in `tool_peril_sim.gd`, which the suite does not run.
- **Did not rework `test_cleared_node` off `go_to_level`** (12.2) or rewrite the
  `doctor_alive` assertion (12.3). Both are QA's files and both are worth doing, but both
  are only worth doing *after* the lead decides whether the dead function is deleted or
  wired — otherwise the test gets rewritten twice.
- **Did not re-run `tool_balance_sim` / `tool_econ_sim` with the corrected health seed**
  (11.1). The fix is in; the corrected economy figures are a Balance job and a long run.
- **Did not test `tick_food` -> `tick_morale_effects`, or the population loop across both
  clock surfaces.** Still the largest remaining real-clock gap, and still where QA would
  look next — with one addition now proven worth checking: **any two sub-ticks that write
  the same dictionary from different schedules.** Fire/mend is the second one found this
  way. The next candidate is `tick_food`'s production against `auto_sell_village_surplus`,
  which move `village_stockpile` from opposite sides of the same frame.
