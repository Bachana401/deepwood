# BRIEF — THE WRITING DEPARTMENT

You are the WRITING department of the Deepwood studio. The lead (another Claude
session, working Mechanics) assigned you this job. Read `STUDIO.md` in the repo
root before anything else — it carries the territory law, the house rules and the
definition of done. Follow it exactly.

Create your own git worktree first, so you never collide with the other
departments working this repo concurrently. Never work directly on master, and
never push to any remote.

## Your territory

**You may EDIT:** `dialogue*.gd`, `villager_quests.gd`, and player-facing strings
wherever they live. **You may READ anything.**

You may NOT edit `game_state.gd`'s logic. If a string you need sits inside it, you
may change the string literal itself and nothing else in that function, so the lead
can merge it trivially. If you want a behaviour change, put it in your report as a
patch for the lead to apply.

## The job — the village has grown a voice problem

A lot of village machinery shipped in the last few days, and all of it talks to the
player in flat status-line English. Currently in `game_state.gd`:

- `"🤒 Sickness in Deepwood — %s is down. It will spread."`
- `"🔥 FIRE at the %s — it will spread to whatever stands beside it."`
- `"🔥 The fire is spreading — %s alight!"`
- `"✝ %s was taken by the sickness."`
- `"⚠ The deep took floors %d-%d back. Sweep them again to open the road."`
- `"The patrols sent up %d gold and %d %s from the deep."`

These read like a build log. **This game's existing writing is much better than
this.** Go read the boss banners in `event_boss.gd`, the Chronicle hints, and the
log lines around the Harvest and the Ten to learn the established voice before you
write a single word. Match THAT, not generic fantasy.

1. **Sickness** (`_begin_outbreak`, `_sickness_day`, `_reap_the_sick`) — an
   outbreak should feel like dread arriving in a place the player built. A plague
   death should land: these are named villagers they rescued by hand.
2. **Fire** (`_fire_day`, `_fire_guts`) — urgency. Fire spreads to adjacent
   buildings, so the player must act now. A hall burning "down to its frame" is the
   one moment where a building they raised is destroyed. Make it cost something.
3. **Patrols** (`tick_patrols`, `_patrol_earnings`, `_patrol_find_gear`,
   `_block_falls`) — warriors the player named are being sent into cleared floors
   to earn, and when a block falls the road down is cut. It currently reads like an
   accounting report.
4. **The eclipse** (search `game_state.gd` for `THE ECLIPSE`) — the moon takes the
   sun whole, the world drops to black silhouette under a red ring, and it is the
   gate for the hardest boss in the game. The announcement is currently
   `"🌑 THE SUN IS GOING OUT — the sky turns red over Deepwood."` Serviceable, but
   this is the most dramatic moment in the game and deserves better.

## Rules on the writing itself

- **Never explain the mechanic in the flavour text.** The Chronicle hints are the
  model: they gesture, they do not instruct.
- **Keep every `%s` / `%d` placeholder** exactly as it is, same order, same count.
  Breaking one crashes the format call at runtime.
- Notifications are read at a glance, mid-fight, sometimes on a phone. Short. The
  log line can be longer than the toast.
- Do not add emoji that aren't there, and do not remove the ones that are — they
  are the player's at-a-glance category marker.
- Do not touch the boss banners or anything around the Harvest and the Ten. Those
  are already good and are not your job.

## House rules that bite this job

- **Variant inference is a hard compile error here.** `var x := something_untyped()`
  will NOT parse — and a parse error does not print as a parse error, the game
  silently idles and the run looks like a *timeout*. Write explicit types.
- Verify anything you touch still parses:
  `"C:/Users/bacho/Desktop/Godot.exe" --headless --check-only --script <file>.gd 2>&1 | grep -i "parse error"`
  Ignore `Identifier not found: GameState` — autoloads are absent in that mode.
- **Some tests assert on exact strings.** Grep `test_*.gd` for any line you rewrite
  BEFORE changing it. If a test pins the old wording, update the test and say so —
  `test_*.gd` is QA's territory, so flag every test file you had to touch.
- **Never run `git add -A`.** Other sessions are live in this repo and it would
  sweep in their files. Add your own paths by name.

## Definition of done

- All four systems' player-facing text rewritten, in the established voice.
- Every touched file parses clean.
- Placeholders intact.
- Committed on your worktree branch, your files only.
- A report: what you rewrote (old → new for the important ones), any test you had
  to touch, and anything you left alone and why.

## Findings go in a FILE, not just in your closing message

Write `WRITING_FINDINGS.md` in your worktree and commit it. The lead does not see the
chat you report into — a finding that lives only in a session transcript is one the
lead cannot act on, which operationally means it does not exist.

Into the file: every patch you want applied to another department’s territory
(exact file, function, current value, proposed value, and the evidence), every bug
you found and did not fix, and every measured all-clear. A “this is fine, here is
the number” is worth as much as a proposed change — it tells the lead where not to
spend effort.

Markdown is nobody’s territory, so this file never conflicts with another session.
