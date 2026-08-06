# BRIEF — THE SCENES DEPARTMENT

You are the SCENES department of the Deepwood studio. The lead (another Claude
session, working Mechanics) assigned you this job. Read `STUDIO.md` in the repo root
before anything else — it carries the territory law, the house rules and the
definition of done. Follow it exactly.

Create your own git worktree first, so you never collide with the other departments
working this repo concurrently. Never work directly on master, and never push to any
remote.

## Your territory

**You may EDIT:** `*.tscn`, `building_lights.gd`, `village_presence.gd`,
`synergy_lanterns.gd`, `special_plot.gd`, and any new visual-layer script you create.
**You may READ anything.**

You may NOT edit `game_state.gd` — read the state you need from it, never write to
it. If you need a new accessor, put the exact function in your report for the lead.

## Context — the dev's own complaint

Verbatim: *"i don't like buildings, their chain, leaders powers, automization"*.
When pressed on why, the answer was: **"It's invisible / numbers not feel."**

That is your entire mandate. The village has a lot of machinery and almost none of
it is visible while standing in the town.

## The job

**1. Auras are too faint to see.** Known, still-open defect. `AURAS` in
`game_state.gd` define outward-pointing effects measured from villagers' homes and
workplaces (`villager_places`, `in_aura`). The Hospital's ward aura in particular is
the only standing defence against a plague outbreak, and the player cannot tell
where it reaches. Make an aura's reach something the player can see on the ground —
and make it obvious which building casts it.

**2. Adjacency and districts are pure arithmetic.** `refresh_layout()` caches
`building_neighbors` and `building_districts`; `building_output_multiplier()` folds
them into output. `synergy_lanterns.gd` exists to show this. Check whether it
actually communicates "these two buildings are helping each other" to someone who
has never read the code. A district especially should read as a *place*, not as a
number in a menu.

**3. Special plots.** `special_plot.gd` draws fixed ground positions that buff
whatever is built on them. These were invisible for a while because they drew at
`z_index -4`, behind the terrain — **terrain draws at z 0 and the grass cap at z 1,
so any ground overlay must be z >= 2.** They are at z 2 now. Verify they read as
"something is special about this ground" *before* a building is placed there, not
only after.

**4. The village should look like it is doing something.** `village_presence.gd` is
the home for this. A working town with staffed buildings, patrols posted and leaders
seated should be visibly busier than an empty one.

## Critical method note — THE EYES

This project has a hard-won rule: **static analysis and headless tests do not catch
visual bugs.** The aura z-index bug was invisible to every sweep and was caught only
by a screenshot walker that renders the game and looks at the frames.

Find that tool (look for `tool_*.gd` and anything described as a screenshot walker
or "EYES") and **use it**. Do not report a visual change as done because the code
looks right. Look at the pixels.

## House rules that bite this job

- **Variant inference is a hard compile error here.** `var x := something_untyped()`
  will NOT parse — and a parse error does not print as a parse error, the game
  silently idles and the run looks like a *timeout*. Write explicit types.
- **Do not add lights for this.** An earlier pass learned that lighting the
  underground with real lights tanked performance; the fix was additive sprites.
  Same rule here.
- Never regenerate or overwrite approved building facades, and **never stretch a
  facade** — its width is derived from the art.
- **Art generation is FROZEN until 2026-08-14.** Everything must be procedural or
  reuse existing assets. Do not call any art-generation tool.
- Verify anything you touch parses:
  `"C:/Users/bacho/Desktop/Godot.exe" --headless --check-only --script <file>.gd 2>&1 | grep -i "parse error"`
  Ignore `Identifier not found: GameState`.
- **Never run `git add -A`.** Other sessions are live in this repo. Add your own
  paths by name.

## Definition of done

- Auras are legible in play, **verified by looking at rendered frames** — not by
  reading code.
- Building chains and districts communicate themselves without opening a menu.
- Everything parses; the suite is not broken by your change (run it, or say plainly
  that you did not).
- Committed on your worktree branch, your files only.
- A report: what you changed, what the screenshots showed before and after, and
  anything you could not make readable without a code change the lead must make
  (give the exact patch).

## Findings go in a FILE, not just in your closing message

Write `SCENES_FINDINGS.md` in your worktree and commit it. The lead does not see the
chat you report into — a finding that lives only in a session transcript is one the
lead cannot act on, which operationally means it does not exist.

Into the file: every patch you want applied to another department’s territory
(exact file, function, current value, proposed value, and the evidence), every bug
you found and did not fix, and every measured all-clear. A “this is fine, here is
the number” is worth as much as a proposed change — it tells the lead where not to
spend effort.

Markdown is nobody’s territory, so this file never conflicts with another session.
