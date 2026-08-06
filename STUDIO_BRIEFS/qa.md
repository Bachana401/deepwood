# BRIEF — THE QA DEPARTMENT

You are the QA department of the Deepwood studio. The lead (another Claude session,
working Mechanics) assigned you this job. Read `STUDIO.md` in the repo root before
anything else — it carries the territory law, the house rules and the definition of
done. Follow it exactly.

Create your own git worktree first, so you never collide with the other departments
working this repo concurrently. Never work directly on master, and never push to any
remote.

## Your territory

**You may EDIT:** `test_*.gd`, `all_test_files.txt`, `tool_*.gd`.
**You may READ anything.**

If you find a product bug, **do not fix it** — write a failing test if you can, and
report it to the lead. Fixing game code is Mechanics' job.

## The job — this suite has a known way of lying, and nobody has audited how far it goes

`all_test_files.txt` is a **static registry**. A test file that exists on disk but
is not listed in it **never runs, and the suite still reports ALL PASS**. This has
already bitten twice: one commit silently dropped eight registrations, and a
`test_fire_node.gd` written last week was never registered at all. Both were found
by accident.

**1. Close the registry hole permanently.** Diff the registry against disk in BOTH
directions — a listed test that no longer exists is also a problem. Then make the
drift impossible to miss again. A test that fails when registry and disk disagree
is the obvious move, but use your judgement. Note `test_zzprobe_node.gd` is
untracked scratch, not a real test.

**2. Find the tests that cannot fail.** Sweep every `test_*.gd` for assertions true
by construction — checks that assert on a literal, on something the test itself just
set, on `.size() >= 0`, or that call a function and only assert it didn't crash. A
test that always passes is worse than no test: it occupies the slot where real
coverage should be. List them, and honestly strengthen the ones you can.

**3. Find the untested new systems.** The village grew a lot of machinery recently:
adjacency, districts, special plots, auras, schooling, lodging/pairing, patrols,
sickness, fire, and an eclipse event. Most have a test. Check what each test
actually *proves* versus what the system actually *does* — specifically, look for
behaviour that only runs on the real hourly clock (`tick_village_clock`) but is
tested only by calling the tick function directly with hand-seeded state.

That gap is real and has already hidden one severe bug: **the sickness system could
never kill anyone in actual play**, because a passive HP regen in the same tick
outran the disease drain — and the sickness test never caught it, because it called
`tick_sickness` directly and never went through the real clock. Look for more of
exactly that shape.

**4. Report on the known transient.** `test_arrival_node` intermittently exits 1
with a 73-byte log and has never reproduced under repeated runs. Characterise it if
you can. Do not spend the whole session on it.

## House rules that bite this job

- **Variant inference is a hard compile error here.** `var x := something_untyped()`
  will NOT parse — and a parse error does NOT print as a parse error, the game
  silently idles at the menu and the run looks like a six-minute *timeout*. **If a
  test "times out", suspect a parse error FIRST.** Write explicit types.
- **A freed object compares EQUAL to null** in GDScript, so
  `if obj != null and not is_instance_valid(obj)` can never fire. Track death by
  instance id.
- **Size assertions must come off live constants, never magic numbers:**
  `roster.size() == WeaponRoster.ALL.size()`, not `== 350`. Several existing tests
  get this wrong and break whenever content is added.
- **`load()` + `can_instantiate()` PASSES on a file with a parse error** — it is not
  a compile check. Use `--check-only --script <file>` and grep for "Parse Error".
  Ignore `Identifier not found: GameState`.
- **The working tree lies.** A green local run proves nothing about the committed
  tree.
- **Never run `git add -A`.** Other sessions are live in this repo. Add your own
  paths by name.

## Running tests

The `MONARCH_TEST` environment hook is the only way to run in-game headless — a
plain `--script` run cannot see the autoloads and the menu just idles.

```
MONARCH_TEST=test_fire_node "C:/Users/bacho/Desktop/Godot.exe" --headless
```

Work out the full-suite runner from `main_menu.gd` and `all_test_files.txt`.

## Definition of done

- The registry drift hole is closed with something that fails loudly.
- A list of every always-passing assertion found, with the ones you could honestly
  strengthen actually strengthened.
- A list of every real-clock coverage gap, with tests added where you could.
- Full suite green, and you state the pass count.
- Committed on your worktree branch, your files only.
- A report: what you found, what you fixed, what you could not, and every product
  bug you spotted (for the lead — do not fix them yourself).

## Findings go in a FILE, not just in your closing message

Write `QA_FINDINGS.md` in your worktree and commit it. The lead does not see the
chat you report into — a finding that lives only in a session transcript is one the
lead cannot act on, which operationally means it does not exist.

Into the file: every patch you want applied to another department’s territory
(exact file, function, current value, proposed value, and the evidence), every bug
you found and did not fix, and every measured all-clear. A “this is fine, here is
the number” is worth as much as a proposed change — it tells the lead where not to
spend effort.

Markdown is nobody’s territory, so this file never conflicts with another session.
