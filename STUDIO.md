# THE STUDIO — how Deepwood is built by a team

One lead (Claude, in the dev's main session). Several departments, each an AI
employee working its own territory, reporting to the lead. The dev talks to the
lead; the lead talks to everyone else.

This document is the thing every employee reads before touching a file. If a
department does not appear here, it does not exist yet — the lead adds it.

---

## 1. THE LAW OF TERRITORY

**Two employees must never own the same file.**

This is not a style preference, it is the entire reason a team is faster than one
worker. Deepwood keeps most of its systems in a handful of very large scripts —
`game_state.gd` above all. If four departments edit `game_state.gd` at once, the
lead spends more time merging than the four saved. Throughput goes *down*.

So departments are drawn along **file ownership lines**, not job titles.

When a department needs a change inside someone else's file, it does **not** edit
it. It writes the exact patch into its report — file, function, the lines to add —
and the owner applies it. A three-line hand-off costs seconds. A merge conflict in
a 3,000-line file costs an hour.

### Territory map

| Department | Owns | May read |
|---|---|---|
| **Mechanics** (the lead) | `game_state.gd`, `player.gd`, `boss.gd`, `event_boss.gd`, `inventory.gd` | everything |
| **Audio** | `sfx_synth.gd`, `audio/**` | everything |
| **Writing** | `dialogue*.gd`, `villager_quests.gd`, all in-game text, `art/` naming | everything |
| **Docs** | `*.md` (except this file) | everything |
| **QA** | `test_*.gd`, `all_test_files.txt`, `tool_*.gd` | everything |
| **Scenes** | `*.tscn`, `*_lights.gd`, `village_presence.gd`, `synergy_lanterns.gd` | everything |
| **Graphics** | `art/**` — **FROZEN until 2026-08-14** (gen freeze) | everything |

`STUDIO.md` is the lead's. Nobody else edits it.

---

## 2. HOUSE RULES — every employee, every time

These are not general good practice. Each one is a bug this project has already
paid for.

1. **Variant inference is a hard error here.** `var x := something_untyped()` does
   not compile. Write `var x: float = ...`. A parse error does not print as a parse
   error — the game idles at the menu and the run looks like a six-minute
   *timeout*. Two sessions have lost an hour to this exact thing.
2. **A freed object compares equal to `null`.** `if obj != null and not is_instance_valid(obj)` can never fire. Track death by instance id.
3. **`all_test_files.txt` is a static registry.** A test that is not listed never
   runs, and the suite still reports ALL PASS. Add the line, or you wrote nothing.
4. **Never `git add -A`.** Other sessions are live in this repo; a blanket add
   sweeps in their `.uid` files. Add your own paths by name.
5. **Size assertions off live constants, never magic numbers.** `roster.size() == 350`
   breaks the day someone adds a weapon; `roster.size() == WeaponRoster.ALL.size()`
   does not.
6. **A named power must require its holder.** The dev's rule: if a building power
   works without its leader seated, the leader has lost its value.
7. **A named ability that nothing reads is a lie.** If you name it, wire it, and
   have a test read it back.
8. **Ground overlays need `z_index >= 2`.** Terrain draws at 0, grass cap at 1.
   A -4 lands invisibly behind the world. This has happened.
9. **The working tree lies.** A green local run proves nothing about the committed
   tree. Verify in a clean clone before calling anything done.

---

## 3. DEFINITION OF DONE

An employee is done when **all** of these are true, and says so explicitly:

- the full suite passes (`MONARCH_TEST` harness — QA owns the runner). The env var
  must be the **full `res://` path** (`MONARCH_TEST=res://test_foo_node.gd`); a bare
  name silently fails an existence check, the menu idles, and the run looks like a
  six-minute timeout
- any new test is registered in `all_test_files.txt`
- no file outside the department's territory was edited (patches handed over instead)
- the commit contains only that department's files
- **findings are COMMITTED TO A FILE, not just reported.** Write
  `<DEPT>_FINDINGS.md` in your worktree and commit it. Markdown is nobody's
  territory, so it never conflicts.
- the report states what was **not** done and why

### Why findings must be a file (learned 2026-08-06, the hard way)

The first wave of departments delivered excellent findings **as prose to the dev's
screen** — and the lead could not act on a single one of them, because the lead
never sees that screen. A measured, correct, well-argued finding that lives only in
a session transcript is, operationally, a finding that does not exist.

So: anything you want the lead to ACT on goes in the file. That means every patch
you want applied to someone else's territory (exact file, function, current value,
proposed value, and the measurement that justifies it), every bug you found and did
not fix, and every measured all-clear — a "this is fine and here is the number" is
worth as much as a proposed change, because it tells the lead where not to spend
effort.

Your closing message to the dev is a summary for a human. The file is the work
order. They are not the same document and the file is the one that matters.

## 4. HOW WORK FLOWS

```
  dev  ──ask──▶  LEAD  ──brief──▶  employee (own worktree, own territory)
                  ▲                      │
                  └──── report ──────────┘
                  │
                  └── reviews, merges to master, reports to dev
```

- The lead writes the brief. A brief names the **territory**, the **goal**, the
  **house rules that bite this particular job**, and the **definition of done**.
- The employee works in its own git worktree. Never on master directly.
- The employee reports: what changed, what passed, what it could not do, and any
  patch it needs the owner of another file to apply.
- **The lead merges.** Employees do not merge each other's work, and nothing
  reaches master without the suite green.
- Nothing is pushed to any remote, ever, without the dev agreeing in conversation.

---

## 5. WHAT A TEAM CANNOT DO

Worth writing down so nobody plans around a fantasy.

- **No AI employee can playtest by feel.** This project's own record is blunt about
  it: the dev finds bugs in five seconds of play that no grep, no sweep and no
  test suite ever sees. Automated QA proves the game is not *broken*. Only the dev
  proves it is *good*. That pass never delegates.
- **Parallelism does not help evenly.** Audio, writing, docs, tests and scenes are
  nearly independent and scale well. Core mechanics all funnel through the same
  two files and through one reviewer, and barely scale at all.
- **Review is real work.** A lead reading six reports is not idle. The honest
  expectation is roughly two to three times the throughput of one worker, not six
  — and the ceiling is how fast the lead can review, not how many employees exist.

---

## 6. THE STANDING BACKLOG

Per department. The lead keeps this current; employees pull from it.
Last revised after the first full wave, 2026-08-06.

### For the dev only — the two that are rulings, not tasks

1. **The automation ladder is paced by DEPTH, and depth runs out before level 80
   does.** The last chore lands at floor 95, and clearing all 99 floors carries a
   player only to about level 55 — so "automatic by level 80" is structurally
   unreachable, not merely under-filled. The Warchief now fills the old 56–95 hole,
   but the pacing question is the dev's.
2. **A maxed village out-earns delving at every floor of the ladder**, inverting
   right where the player finishes paying for it (95.0 g/real-min passive vs 90.4
   delving at floor 80). Measured. Whether that is the intended payoff or a bug is
   a design call.

### Mechanics (lead)
- shortage & unrest exceptions; trade caravans; the mid-game raid-loot upgrade
- the birth flywheel doubles a town 80 → 176 in 10 in-game days (Balance §2); the
  recorded design target is 70–80 by floor 60

### QA
- `tick_fire` has no real-clock coverage, and it burns building health in the same
  pass as the auto-repair — **the same shape as the sickness bug**. QA named this
  as where they would look next.
- `tick_food` → `tick_morale_effects`, and the population loop across both clock
  surfaces, are still untested under the real clock
- 134 source-text `.contains()` assertions remain (weak, not unfalsifiable) — replace
  opportunistically, never in a mass sweep

### Balance
- measure `BOSS_RAZE_DAMAGE` per real fight (needs a combat harness they do not have)
- fire is measured nowhere
- validate the two-strain sickness now that immunity and the homes-only graph landed

### Scenes
- the Bar's beacon can read as a small sun now that a real sun exists
- aura reach is drawn for homes but `in_aura` counts workplaces too
- the muster ground saturates: a watch of 8 and a watch of 30 look alike

### Writing
- the Hollow Sun smashing the village is silent in the log
- `_reap_the_sick`'s death lines are strain-blind in the log (toast now names it)

### Audio
- the Hollow Sun's village-razing impacts have no sound
- QA holds a roster-drift test for `SfxSynth.RECIPES` vs the `match` arms

### Docs
- `GAME_MECHANICS.md:693` says `hollow_signet` has no craft recipe. It does now.
- the eclipse, immunity, the two strains, the Warchief automation and the condition
  term all postdate the last docs pass

### Graphics
- **FROZEN until 2026-08-14.** Planning only.
