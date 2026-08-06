# AUDIO + WRITING — findings & handover

Department: Audio (+ the Writing half of one beat). Branch: `master`.

**Brief:** the Hollow Sun fights inside the village and smashes it, and that beat
— the most dramatic in the game — had no sound and no line. A hall the player
spent an hour raising takes a meteor and the game says nothing at all.

**Committed here:** `sfx_synth.gd` only (2 new recipes, 2 mix entries, 1 new
playback entry point, 1 shared gate helper). Nothing else was touched.

**Handed over below (§4):** 2 trigger lines in `boss.gd`, 2 in `game_state.gd`,
3 written lines, 1 member var. Every one of them is exact text with an anchor.
**All of it has been through the compiler — see §5.**

---

## 1. The two sounds

Both are in `SfxSynth`, both on `RECIPES`, both with a `match` arm, both with a
`VILLAGE_MIX` entry. Constants exist because these are called from files owned by
another department, and a mistyped bare string does not fail — it falls through
`_:` and plays 50ms of silence.

| Constant | Recipe | Length | Peak | RMS | What it is |
|---|---|---|---|---|---|
| `SfxSynth.SFX_RAZE_HIT` | `raze_hit` | 0.30s | 0.82 | 0.104 | A meteor or pillar taking a piece out of a hall |
| `SfxSynth.SFX_MEND_DONE` | `mend_done` | 0.86s | 0.55 | 0.125 | The builders finishing a repair |

Measured by rendering the actual buffers, not by reading the source.

### `raze_hit` — why it sounds the way it does

Four layers, all in the file's existing vocabulary (sine, square, noise, power
envelopes, phase-continuous sweeps written as integrals):

1. **THE BLOW** (0–0.045s) — hard noise, no pitch. The strike itself.
2. **THE MASS** (0–0.16s) — a sub sweeping 104 → 58 Hz.
3. **THE TIMBER** (0–0.12s) — a narrow-duty square falling 196 → 124 Hz. Wood
   cracks; a sine only sags.
4. **THE RUBBLE** (0.05–0.26s) — nine dry grains scattering after.

**Distinct from `fire_alarm`, by construction.** The alarm is bright and high (a
swung bell at 880/622 with two dozen sparks) because it is a *warning* and a
warning has to carry across a town. This is a *result*: low, blunt, over almost
before it starts. Nothing in it rings and nothing in it repeats a pattern.

**Distinct from `thump`, which was the nearer trap.** `thump` is the earth
answering — one material, a low sine and a click, no aftermath. `raze_hit` has
three materials and a debris tail, and the timber layer is the voice `thump` has
not got. This is a building being hit, not the ground.

**It stacks without turning to mud, which was a stated requirement.** A meteor
storm lands six of these inside half a second, so: the whole recipe is 0.30s; the
sub — the only part that could ever smear — is done in 0.16s, so no more than
about three ever overlap; and all the long-tail energy is noise grains, which
layer into a collapse rather than into a drone. Its RMS is 0.104 against
`fire_alarm`'s 0.362, so four of them stacked are still less dense than one
alarm bell.

### `mend_done` — why it sounds the way it does

Written as `raze_hit`'s negative on every axis the ear reads: quiet not loud, mid
not low, tonal not noisy, patient not instant, and it **resolves**.

1. **Two mallet taps** (0.00, 0.115) — the last peg going home. A short wooden
   body at 330 Hz easing down, with a grain of contact noise on the front of
   each. This is the domestic part: a hand and a tool, not an event. It is also
   the only noise in the recipe, and there are twelve milliseconds of it.
2. **A fourth that closes** (0.28 → 0.42) — D5 falling to G4, with G3 underneath
   so it sits in a room instead of in the air.

That interval is deliberate. `patrol_out` climbs a fourth and **leaves it
hanging**, because an order has been given and not yet answered. This is the same
interval walked the other way and landed on: the thing that was owed has been
paid. A player who has heard the gate open a dozen times gets that for free.

No fanfare and none wanted — `fire_doused` already established that the good news
is only ever *"it is still standing"*. Normalised to 0.55 and mixed at −13, it is
the softest entry in the whole set. A repair finishing is a thing you notice, not
a thing that interrupts you.

---

## 2. The mix, and the one gap measured in frames

```gdscript
"raze_hit":  [-6.0, 0.05],
"mend_done": [-13.0, 1.5],
```

**−6.0** is deliberately one dB under `fire_alarm` (−5.0, "the loudest thing the
village is allowed" by the standing comment) and level with the loudest combat
one-shots already in `boss.gd` (`"tear", -6.0` at boss.gd:4598). It has to cut
through a boss fight and must still not out-shout the bell.

**0.05s** is the interesting number. Every other entry in `VILLAGE_MIX` is
throttled because the town clock resolves a whole day in one frame and twenty
alarm bells at once are a wall of mud. This one is throttled for the *opposite*
reason: **one strike legitimately hits several buildings in the same frame**, and
the player should hear one impact, not four.

50ms was chosen against the actual call sites in `boss.gd`:

- `do_pillars` fires every pillar in **one frame** → collapses to a single crash.
  Correct: one blow looks like one blow.
- `do_meteors` spaces its meteors **0.06s apart** (`await ... create_timer(0.06)`)
  → every meteor passes the gate. Correct: a storm reads as a barrage.

So the gate turns "one strike hit four buildings" into one sound while leaving a
rolling barrage audible as a barrage, and it does it without either department
needing to know the other's numbers.

---

## 3. New API: `play_village_at`

```gdscript
SfxSynth.play_village_at(host, at, recipe, volume_db := NAN, min_gap := NAN, pitch := 1.0)
```

Same mix table, same throttle, **but positional**. Every other village event is
reported to a player who may be a hundred floors down — there is no place in the
world for it to come from, so `play_village` goes through `play_ui`. The razing is
the exception: the player is *standing in it*, and an impact on the hall behind
you and an impact on the hall across the square are not the same information.

`play_village` and `play_village_at` now share one `_village_gate()` helper that
resolves the mix and stamps `_last_played`, so the stamp cannot be forgotten on
one of the two paths. **`play_village`'s behaviour is byte-for-byte unchanged** —
same order of operations, same defaults, same early-out.

---

## 4. THE PATCH LIST

Three files, none of them mine. Line numbers are given as *of this writing only* —
`game_state.gd` moved 49 lines under me during this session — so **anchor on the
quoted text, not the number.**

### 4a. `boss.gd` — declare the told-set

**Anchor:** the line `const BOSS_RAZE_FLOOR = 0.15        # never below this share of a building's max`
(currently boss.gd:4274, immediately above `func _raze_ground_at`).

**Insert directly after it:**

```gdscript

# ONE LINE PER HALL PER FIGHT. A meteor storm calls _raze_ground_at six times and
# each call can reach several buildings, so "log every impact" writes twenty
# identical lines into the village log for one volley and the beat stops reading
# as a beat. Keyed by building name: the first blow a hall takes is worth saying,
# and the blow that puts it on the floor is worth saying once more. Per-instance,
# so a rematch starts the story again.
var _razed_told: Dictionary = {}
```

### 4b. `boss.gd` — `_raze_ground_at`, the sound and the two lines

**Anchor:** the last line of the function,
`		node.take_damage(mini(BOSS_RAZE_DAMAGE, hp - floor_hp))` (currently boss.gd:4288).

**Replace that single line with:**

```gdscript
		node.take_damage(mini(BOSS_RAZE_DAMAGE, hp - floor_hp))
		SfxSynth.play_village_at(self, node.global_position, SfxSynth.SFX_RAZE_HIT)
		var bname: String = str(node.building_name) if "building_name" in node else ""
		if bname == "":
			continue
		if not _razed_told.has(bname):
			_razed_told[bname] = true
			GameState.log_event("village", "The %s took a blow meant for you. Nothing out there aims at houses — they only stand where it lands." % bname)
		var left: int = int(node.health) if "health" in node else 0
		if left <= floor_hp and not _razed_told.has(bname + "|floor"):
			_razed_told[bname + "|floor"] = true
			GameState.log_event("village", "The %s is down to its bones. It still opens in the morning, and it is not worth much when it does." % bname)
			GameState.notify_urgent("☀ The %s is down to its bones — standing, and not much more than that." % bname)
```

`left` is read **after** `take_damage`, so it is the post-hit health and the floor
test fires on the blow that actually lands the hall on 15%.

### 4c. `game_state.gd` — `_auto_mend_one`, the relief beat

**Anchor:** `		log_event("village", "The builders have made the %s whole again." % hurt)`
(currently game_state.gd:6905).

**Replace that single line with:**

```gdscript
		log_event("village", "The builders made the %s whole again — you would have to know where to look." % hurt)
		SfxSynth.play_village(self, SfxSynth.SFX_MEND_DONE)
```

Non-positional on purpose: this fires off the town clock and reaches a player who
may be deep underground, exactly like the rest of the village set. It only fires
when the hall reaches **full** health, not once per mend pass, which is the right
rarity for a sound.

---

## 5. What I verified, and how

- `sfx_synth.gd` parses clean:
  `Godot.exe --headless --check-only --script sfx_synth.gd` → no parse errors.
- **Both recipes actually synthesise** (a parse check cannot tell you this — an
  unknown name returns a non-empty buffer of silence and passes every size test).
  Rendered and measured: the table in §1 is real numbers off the real buffers.
- **Roster drift: zero.** Every name on `RECIPES` has a `match` arm and every arm
  is on `RECIPES` — 16 and 16.
- **The full SFX suite is green**:
  `MONARCH_TEST=res://test_weapons2_node.gd Godot.exe --headless --path .` →
  `RESULT: ALL PASS`. (The `ERROR: no recipe named "definitely_not_a_recipe"` in
  that run is the suite's own deliberate probe of the unknown-recipe path, not a
  regression.)
- **The hand-off patch in §4 has been through the compiler**, not just proofread.
  I built a scratch probe containing the exact text of 4a/4b/4c and ran it under
  the `MONARCH_TEST` hook so the live autoloads were present:
  `PROBE COMPILED OK`. That type-checks `play_village_at`, both `SFX_*`
  constants, `GameState.log_event`, `GameState.notify_urgent`, and every explicit
  type in the patch. The probe was deleted; it is not in the commit.

---

## 6. TWO THINGS THE LEAD HAS TO DECIDE

### 6a. The other Writing session already wrote this beat, blind

`WRITING_FINDINGS.md` §5e (branch `claude/ecstatic-liskov-8512f4`) contains lines
for this exact moment, written without access to the code — it says so: *"I could
not find this code in any worktree, so I have nothing to anchor to."* Their
proposals:

- log: `Deepwood paid part of that fight in stone — the %s took the worst of it.`
- toast: `☀ The %s takes the blow meant for you.`

**Both are good and I am not overwriting them silently.** Where we agree, I
deferred to them: **I adopted their `☀`** as the Hollow Sun's mark rather than
introducing a second new emoji (I had drafted `🏚`). Where we differ:

- Their log line fires on the first hit but says *"took the worst of it"*, which
  reads as final — and the first hit is not the worst, the floor is. Mine splits
  the beat into two moments the code can actually distinguish, which is only
  possible now that there is code to anchor to.
- Their toast is tighter than anything I wrote and I would use it **if** you want
  a toast on the first hit. I recommend **not** having one: this is the hardest
  fight in the game and the player is busy. Log on the first hit, toast only on
  the floor moment — that toast is the one carrying new information.

**Decision needed:** whose first-hit log line ships. Everything else composes.

Small caveat on `☀`: the raze is driven by the generic `razes_buildings` flag, so
a sun mark on a mechanic any future boss could carry is a slight stretch. It is
right today (the Hollow Sun is the only holder) and `🏚` is the neutral fallback.

### 6b. The call-site typo-catcher does not see `play_village_at`

`test_weapons2_node.gd:329` sweeps the repo for `SfxSynth.play_*` calls and holds
every literal recipe name against the roster. Its regex is:

```gdscript
rx.compile('SfxSynth\\.play_(?:at|ui|village)\\([^\n]*?"([a-z_0-9]+)"')
```

`play_village_at(` never matches: the alternation takes `village` and then demands
`\(`, finds `_`, and fails with nothing to backtrack to. **This is not biting
today** — the patch in §4 passes `SfxSynth.SFX_RAZE_HIT`, a constant, which the
compiler checks, and that test's own comment says constants are safe by
construction. It bites the day someone writes a bare string into the new call.

**One-word fix for QA** (order matters — the longer alternative must come first):

```gdscript
rx.compile('SfxSynth\\.play_(?:village_at|village|at|ui)\\([^\n]*?"([a-z_0-9]+)"')
```

I did not apply it: `test_*.gd` is QA's territory.

---

## 7. What I did NOT do

- **I did not hear either sound.** No AI employee in this studio can. The
  measurements in §1 are real, the design reasoning is sound, and both are still
  unheard until the dev plays the fight. `raze_hit` in particular is tuned against
  numbers (RMS, peak, dB relative to `fire_alarm`) and against call-site timing —
  if it turns out to disappear under the boss's own attacks, the fix is
  `VILLAGE_MIX["raze_hit"][0]` in `sfx_synth.gd` and nothing else.
- **I did not add a test.** A roster-drift test for `RECIPES` vs the `match` arms
  already exists and already covers both new recipes (`test_weapons2_node.gd`,
  green). QA's standing backlog item for it is therefore already satisfied — that
  is a measured all-clear, not a gap.
- **I did not touch `boss.gd`, `game_state.gd`, `building.gd` or
  `day_night_cycle.gd`.** All of it is §4.
- **`day_night_cycle.gd` turned out not to need anything** from this brief — the
  eclipse already has its own recipe and trigger from the previous pass. Noted so
  nobody goes looking.
