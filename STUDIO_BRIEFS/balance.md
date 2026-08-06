# BRIEF — THE BALANCE DEPARTMENT

You are the BALANCE department of the Deepwood studio. The lead (another Claude
session, working Mechanics) assigned you this job. Read `STUDIO.md` in the repo root
before anything else — it carries the territory law, the house rules and the
definition of done. Follow it exactly.

Create your own git worktree first, so you never collide with the other departments
working this repo concurrently. Never work directly on master, and never push to any
remote.

## Your territory

**You may EDIT:** `tool_*.gd` simulation tooling, freely.
**You may READ anything.**

Balance CONSTANTS inside `game_state.gd` are **not** yours to change — the lead owns
that file and is editing it right now. Report every number you want changed as an
exact patch: constant name, current value, proposed value, and the reasoning. The
lead applies it.

## The job — measure, don't guess

This project already has the tools: a marathon simulator (`tool_marathon_sim.gd`,
which produces a multi-hour dev report per class and has previously caught real
material chokepoints) and a balance sim. Nobody has pointed them at the village
economy that shipped in the last week.

**1. The village economy is now a second income stream and nobody has measured it.**
Buildings produce into a shared stockpile and treasury. On top of raw output,
`building_output_multiplier()` stacks: building level (+5% per level), adjacency
bonus, district bonus, and special-plot bonus. Work out what a well-optimised late
village earns per in-game hour versus a naive one, and versus what the player earns
delving. If the optimised village trivialises the dungeon economy, that is a
finding. If the spread between a good layout and a bad one is too small to be worth
the puzzle, that is also a finding.

**2. Patrols.** The town posts warriors into already-cleared dungeon blocks to earn
passively. Deeper blocks pay roughly 35% more per block, and patrols can turn up
gear bracketed by depth (`_patrol_earnings`, `_patrol_find_gear`,
`WeaponRoster.TIER_FLOORS`). Two questions: does posting warriors ever beat delving
yourself, and can patrol finds hand the player gear well ahead of where they have
earned it?

**3. Sickness and fire are new costs and have never been measured.** Sickness stops
a sick villager healing and drags morale; a harder late-game strain also drains HP
and can kill after long neglect. Fire eats a building's HP per hour and spreads to
adjacent buildings. **Both systems were just retuned by the lead after an audit
found that sickness could not kill anyone at all and fire switched itself off
entirely once the Builderhouse was staffed — so both sets of numbers are fresh and
unvalidated. Measure them.** Specifically: how long from falling ill to death with
no intervention, how often a town of eighty loses someone, and whether a fire can
chain through a tightly-packed row and take out several buildings before a staffed
crew stops it.

**4. The automation ladder.** The design law is that the player starts doing
everything by hand and by roughly level 80 the village runs itself. Check whether
the actual unlock depths deliver that curve, or whether there is a dead stretch
where nothing new is automated.

## Method

- **Simulate.** Every claim in your report must come from a number the tooling
  produced, not from reading a constant and reasoning about it. Where the existing
  sims cannot answer a question, extend them — that tooling is yours.
- **State your assumptions.** A sim that assumes a perfectly-played village is
  measuring something different from one that assumes an average one. Say which you
  ran.
- Where you propose a change, give the current value, the proposed value, and what
  the sim says each produces.

## House rules that bite this job

- **Variant inference is a hard compile error here.** `var x := something_untyped()`
  will NOT parse — and a parse error does not print as a parse error, the game
  silently idles and the run looks like a *timeout*. **If a sim run "times out",
  suspect a parse error FIRST.** Write explicit types.
- The **`MONARCH_TEST`** env hook is the only way to run in-game headless — a plain
  `--script` run cannot see the autoloads.
  Example: `MONARCH_TEST=test_fire_node "C:/Users/bacho/Desktop/Godot.exe" --headless`
- **One in-game day is 600 real seconds.** Convert honestly when you report
  player-facing time; "seven in-game days" means seventy real minutes, and the dev
  thinks in real minutes.
- A previous ruling stands: **reforging is rejected forever.** Do not propose it.
- **Difficulty never comes from one-shot damage.** This project's rule is that
  difficulty comes from mechanics, never from a boss deleting the player in one hit.
- **Never run `git add -A`.** Other sessions are live in this repo. Add your own
  paths by name.

## Definition of done

- Each of the four questions answered with simulated numbers.
- A prioritised patch list of constant changes for the lead, each justified by a
  measurement.
- Any tooling you extended is committed on your worktree branch, your files only.
- A report that leads with the single most broken curve you found.

## Findings go in a FILE, not just in your closing message

Write `BALANCE_FINDINGS.md` in your worktree and commit it. The lead does not see the
chat you report into — a finding that lives only in a session transcript is one the
lead cannot act on, which operationally means it does not exist.

Into the file: every patch you want applied to another department’s territory
(exact file, function, current value, proposed value, and the evidence), every bug
you found and did not fix, and every measured all-clear. A “this is fine, here is
the number” is worth as much as a proposed change — it tells the lead where not to
spend effort.

Markdown is nobody’s territory, so this file never conflicts with another session.
