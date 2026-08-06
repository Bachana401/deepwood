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

- the full suite passes (`MONARCH_TEST` harness — QA owns the runner)
- any new test is registered in `all_test_files.txt`
- no file outside the department's territory was edited (patches handed over instead)
- the commit contains only that department's files
- the report states what was **not** done and why

"It compiles" is not done. "The tests I wrote pass" is not done.

---

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

**Mechanics** (lead) — the eclipse + the Hollow Sun; shortage & unrest exceptions;
mid-game raid-loot upgrade; trade caravans.

**Audio** — the new systems are silent: patrols leaving and returning, an outbreak
starting, a building catching fire, the eclipse beginning. All need one-shots.

**Writing** — event flavour for the new systems; sickness and fire notifications
read like status lines, not like a village in trouble.

**Docs** — `VILLAGE_SYSTEMS.md` and `GAME_BIBLE.md` describe none of adjacency,
districts, special plots, auras, schooling, lodging, patrols, sickness, fire or
the eclipse. The Bible is the source of truth and is currently out of date.

**QA** — the `test_arrival_node` launch transient (73-byte log, exit 1, never
reproduced) is characterised but unexplained.

**Scenes** — aura pools are too faint to see in play.

**Graphics** — frozen until 2026-08-14. Planning only.
