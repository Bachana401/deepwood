# WRITING — findings & handover

Department: Writing. Branch: `claude/ecstatic-liskov-8512f4`.
Brief: the village machinery (sickness, fire, patrols, the eclipse) was talking to
the player in flat status-line English. Rewrite it in the voice the boss banners
and the Chronicle already speak.

**Committed here:** `game_state.gd` (12 string literals), `assign_ui.gd` (1 string).
**Not committed here, handed over below:** fire, the eclipse, the plague strain,
the road-cut notification, the Hollow Sun. Those strings sit in code that is not
on `master` — see §5.

---

## 1. The rule I wrote to

The Chronicle hints and the event-boss banners gesture; they never instruct. So:

- No line explains its own mechanic. `"It will spread."`, `"Sweep them again to
  open the road."` and `"This one kills."` are the exact failure mode.
- Concrete image, then a consequence stated as fact. Not a status field.
- The toast is read at a glance, mid-fight, sometimes on a phone. **Short.** The
  log can be longer, and carries the half the toast had no room for.
- Placeholders unchanged in count and order. Emoji category markers untouched.

---

## 2. SICKNESS — done, committed

`_begin_outbreak`, `_sickness_day`, `_reap_the_sick`.

| Where | Old | New |
|---|---|---|
| onset toast | `🤒 Sickness in Deepwood — %s is down. It will spread.` | `🤒 Sickness in Deepwood — %s is down with fever. It never stops at one.` |
| onset log | `%s has fallen ill — and it does not look like grief.` | `%s has taken to their bed, and it is not grief that keeps them there.` |
| spread toast | `🤒 The sickness spreads — %d more are down.` | `🤒 It went house to house in the night — %d more down.` |
| spread log | `The sickness spread to %d more in the night.` | `Another %d woke shivering. Nobody can say who carried it.` |
| cure log | `%s has thrown off the sickness.` | `%s came through the fever. Thin, and standing.` |
| death toast | `✝ %s was taken by the sickness.` | `✝ %s is gone. The fever, not the deep.` |
| death log | `%s was taken by the sickness. Deepwood grieves.` | `%s did not come through it. Not every grave here was dug by the dark.` |

`"It will spread."` was the mechanic read aloud. `"It never stops at one."` is the
same information as dread. `"Deepwood grieves"` was telling the player what to
feel; the replacement instead lands the system's actual point — **this death was
the town's own, not the dungeon's.**

Two time-of-day claims were cut late in the pass: `_reap_the_sick` runs hourly,
not on the day boundary, so a death line reading *"did not come through the
night"* could contradict the log's own hour stamp.

---

## 3. PATROLS — done, committed

`tick_patrols`, `_patrol_earnings`, `_patrol_find_gear`, `_block_falls`.

| Where | Old | New |
|---|---|---|
| earnings log | `The patrols sent up %d gold and %d %s from the deep.` | `The patrols traded a night in the dark for %d gold and %d %s.` |
| block-fall toast | `⚠ The deep took floors %d-%d back. Sweep them again to open the road.` | `⚠ The deep took floors %d-%d back. The road down ends there.` |
| block-fall log | `Floors %d-%d have fallen back to the dark — the road down is cut there.` | `Floors %d-%d have gone back to the dark. Nothing of ours walks past them now.` |
| find log | `The patrol on floors %d-%d found something on the bodies: %s.` | `The watch on floors %d-%d came home carrying %s. Nobody asked whose it was.` |
| find toast | `⚔ Your patrol sends up a find: %s` | `⚔ Your patrol brings something up out of the dark: %s` |

The earnings line was an accounting entry for a system about **named warriors the
player posted by hand**. Naming the trade — a night in the dark, for this — is the
whole decision the patrol system exists to pose.

### 3a. The contradiction — confirmed, and it was mine

The lead was right, and I had missed it: I read the patrol panel only as far as
its controls and stopped short of the note beneath them.

`assign_ui.gd:947` promised the player, in plain text:

> `They send up coin and material — never gear.`

`_patrol_find_gear` hands out weapons, armour **and** relics. Fixed:

> `They send up coin and material, and now and then something off a body.`

Truthful, quotes no percentage, and matches the find log's *"Nobody asked whose it
was."* **Two stale references remain and are not mine:**

- `game_state.gd:2615` (comment, Mechanics'): *"coins and materials, and nothing
  else, ever. No gear, no relics…"* — the same comment then predicts the exact
  feature that broke it (*"a mid-game upgrade may later add a fraction-of-a-percent
  gear chance"*). Only the absolute **"ever"** is now wrong.
- `test_patrols_node.gd:69` (comment, QA's): *"what they send up: bulk, never gear"*.

---

## 4. Tests

**No test pinned any wording I changed.** I grepped every literal before touching
it. **I edited no test file.** Two things QA should know anyway:

1. **`test_sickness_node.gd` is flaky on untouched `master`.** The committed
   baseline failed **1 run in 12** on `it spreads through homes packed together
   (0 in the row)`. It seeds no RNG and rolls four unseeded `_sickness_day` days;
   patient zero can be *cured* by `SICK_CURE_CHANCE_PER_DAY` before infecting
   anyone, giving `packed == 0`. Fix: `seed()` the case, or run more days. I
   verified this before and after my change — it is not mine.
2. **`test_patrols_node.gd:74` captures `bag_before` and never asserts on it** —
   dead leftover from when "never gear" was true. Harmless, but it means nothing
   currently guards patrol drops in either direction.
3. Two test `.uid` files are untracked: `test_patrols_node.gd.uid`,
   `test_sickness_node.gd.uid`. 123 of 125 test `.uid`s **are** tracked and `.uid`
   is not gitignored, so these were dropped when those tests were committed.

**Suite: 125/125 ALL PASS** on the final text. Parse output byte-identical to the
committed baseline (the `--check-only` "Identifier not declared" flood is autoload
noise present on untouched `master` too).

---

## 5. Lines I could not change — apply these

These sit in code that is not on `master`. At the time of writing they are
committed on `claude/gifted-murdock-786925` (fire, eclipse, plague, road-cut) or
not yet written anywhere I can see (the Hollow Sun). **My commit does not touch
any of them, so it merges cleanly.**

### 5a. FIRE — `_fire_day` / `_fire_guts`

| Old | New |
|---|---|
| `🔥 FIRE at the %s — it will spread to whatever stands beside it.` | `🔥 FIRE at the %s — and Deepwood is built shoulder to shoulder.` |
| `Fire has broken out at the %s!` | `Fire in the %s. The roof caught before anyone reached the door.` |
| `🔥 The fire is spreading — %s alight!` | `🔥 It jumped the gap — %s alight!` |
| `The fire jumped to the %s — they are built too close.` | `The %s caught from its neighbour. They were raised close enough to share the heat.` |
| `The fire at the %s is out.` | `The %s is black and smoking, and still standing.` |
| `The %s has burned down to its frame.` | `The %s burned down to its frame. Every hand that raised it stood and watched.` |
| `🔥 The %s burned down. The builders will have to raise it again.` | `🔥 The %s is gone. It went down faster than it went up.` |

The first line stated the adjacency rule outright. The replacement makes the
player's own tight-packed layout the villain instead — same information, no
tutorial. The last two are the destruction beat: the log says who watched, the
toast says what it cost.

`%s` in the spread toast is a **joined list** — the new phrasing reads correctly
for one name or several.

### 5b. THE ECLIPSE

| Old | New |
|---|---|
| `🌑 THE SUN IS GOING OUT — the sky turns red over Deepwood.` | `🌑 THE SUN IS GOING OUT — the ring is lit, and Deepwood is only an outline.` |
| `The moon took the sun whole. The world stood in red dark.` | `The moon took the sun whole. Deepwood lost its colours and kept its shapes.` |

**"The ring is lit" is deliberate.** The Hollow Signet's refusal already reads
*"The ring is cold. The moon has not taken the sun."* Naming the ring here pays
that off for any player who tried the Signet early and was turned away. *"Only an
outline"* describes the silhouette render without explaining it.

### 5c. THE TWO STRAINS — illness vs plague

The problem is real: they currently share almost every line, and `☠` is doing all
the work alone. Fixing it needs **register**, not an explanatory clause.

- **Illness stays domestic and household-scale** — beds, shivering, coming
  through it. Nobody dies, and nothing in its wording should suggest anyone might.
- **Plague goes institutional and ritual** — marked doors, counting, burial. It
  never says it kills; it behaves like something people already know to fear.

| Where | Old | New |
|---|---|---|
| plague onset toast | `☠ PLAGUE in Deepwood — %s is down. This one kills.` | `☠ PLAGUE in Deepwood — %s is down, and the door is marked.` |
| plague onset log | `%s has fallen ill, and it is not the usual sickness.` | `%s fell ill, and one of the old hands went quiet and started marking doors.` |

A marked door *is* the plague signal, historically. It tells the player this is
the bad one without ever saying so.

**Three lines are currently strain-blind and need a branch to carry these** — the
branch is Mechanics', the strings are mine. `_sickness_day` already computes
`fresh_plague`, so the spread pair only needs `if not fresh_plague.is_empty()`:

| Where | Illness (already committed by me) | Plague variant to add |
|---|---|---|
| spread toast | `🤒 It went house to house in the night — %d more down.` | `☠ The plague has the row — %d more marked.` |
| spread log | `Another %d woke shivering. Nobody can say who carried it.` | `Another %d marked by morning. It is moving faster than feet.` |
| cure log | `%s came through the fever. Thin, and standing.` | `%s came through the plague. Thin, and standing, and lucky.` |

**One adjustment to a line I already committed.** Now that *only* the plague
reaps, the death toast should name it:

> `✝ %s is gone. The fever, not the deep.` → `✝ %s is gone. The plague, not the deep.`

The death log — *"Not every grave here was dug by the dark."* — needs no change.

### 5d. THE ROAD IS CUT — `level_select_ui.gd:118`

| Old | New |
|---|---|
| `⛔ The road is cut at floors %d-%d. Take them back, or reach past by Waystone.` | `⛔ The stair ends at floors %d-%d. Nothing walks past that stretch — only a Waystone reaches beyond it.` |

This is the moment the Waystone network justifies itself, so the Waystone has to
be **named** — but as a property of the world, not as a step in a list. *"Take
them back, or reach past by"* is an instruction with two options; *"only a
Waystone reaches beyond it"* is the same fact told as a limit of the world, and it
lands harder because it sounds like something the player just lost.

### 5e. THE HOLLOW SUN smashing the village

I could not find this code in any worktree, so I have nothing to anchor to — the
line is written, the wiring is yours. Fire it when a building takes damage from
the boss, **rate-limited to once per building**, or a long fight will bury the log.

- log: `Deepwood paid part of that fight in stone — the %s took the worst of it.`
- toast (optional; the fight is busy): `☀ The %s takes the blow meant for you.`

`☀` is a **new** emoji, not one I inherited — the Hollow Sun's own mark, distinct
from the eclipse's `🌑`. Say the word if you'd rather it match `🌑`.

---

## 6. Left alone deliberately

- **Boss banners, the Harvest, the Ten, the Chronicle.** Out of scope, and they
  are the standard I wrote everything else to.
- **The Signet refusals** — *"The ring is cold. The moon has not taken the sun."*,
  *"Nothing happens. The sky is not yet wrong."* Already exactly right; 5b was
  written to pay them off rather than to replace them.
- **`morale_meter.gd:142`** — `🤒 %d SICK — NO WARD — staff the Hospital`. A HUD
  status readout, where instructing the player **is** the job. That register is
  correct and the no-instruction rule does not apply to it. (It will want a plague
  row of its own once 5c lands — that one is worth being blunt in.)
- **The rest of the patrol panel** — `"Patrols — hold the deep, or lose it"`, and
  creep rendered as a *word* (`quiet` / `restless` / `stirring` / `OVERRUN SOON`)
  rather than a number. That is already good writing; I changed only the sentence
  that was factually false.
- **`game_state.gd` logic, everywhere.** Only quoted text was edited, so every
  change is a one-line merge.
