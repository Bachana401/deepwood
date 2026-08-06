# BOSS FINDINGS — the Hollow Sun's razing, measured

Department: Mechanics (worker), territory `boss.gd` + `event_boss.gd`.
Date: 2026-08-06. Everything below was produced by RUNNING the game headless
against a live Hollow Sun, not by reading it. The probe was a scratch script
under the `MONARCH_TEST` hook and has been deleted; the numbers are reproducible
by re-staging `GameState.summon_event_boss("hollowsun", 0.0, false, false)` in
`main.tscn`.

---

## 1. `_razed_told` — NOT BROKEN. No fix needed.

The worry was that a second summoning of the Hollow Sun could inherit a
populated ledger and fight in silence. It cannot. Measured, four ways:

| probe | result |
|---|---|
| fresh `BS.new()` boss, before any raze | `_razed_told.size() == 0` |
| second boss built while the first still lives | `0` (first still holds `1`) |
| poison boss A's dict with a junk key | A `2`, B `1`, B does **not** see the key — **not a shared dictionary** |
| the real staging path run twice, rematch level bumped between | summon 1 instance `316284082932`, summon 2 instance `318381233422`; **both arrive at size 0**, both log again |

The structural reason: `event_boss_director._spawn` always calls
`BOSS_SCENE.instantiate()`, and `configure_from_def` is called from `_ready()`
and from nowhere else in the codebase. There is no pooling, no reparent, no
revive — grep for `reparent` finds exactly one hit and it is in `arrow.gd`. A
boss node is built, fights, and frees. The rematch is a new node.

**One real hole existed and I closed it defensively:** a *copy* of a razing boss
(`is_clone` / `is_false_copy`) is a separate node with its own fresh ledger, so
N copies would re-announce every hall N times *and* multiply the town's damage
by N. No boss in the game today has both `razes_buildings` and `clone`/
`false_twin`, so this was unreachable — `_raze_ground_at` now returns early for
copies so it stays unreachable. Revert freely if you'd rather an echo broke
things too.

---

## 2. The dungeon — A REAL LATENT BUG. FIXED in `boss.gd`.

**What I proved by running it.** I changed scene to `dungeon_interior.tscn`
(`GameState.in_dungeon == true`), planted one node in the `building` group with
the minimum surface `_raze_ground_at` looks for (`health`, `take_damage`,
`building_name`), and fired a Hollow Sun's raze at it:

```
[deep] scene = res://dungeon_interior.tscn, in_dungeon = true, buildings in the group here = 0
[deep] a razes_buildings boss standing in a DUNGEON hit the group 1 time(s) for 34 damage;
       GameState.building_health['Bank'] = 366        <-- 400 - 34, written from the deep
```

The wound went straight into `GameState.building_health` — the save file — from
the bottom of a dungeon. `building.take_damage` writes there on every hit, so
this is not cosmetic; it is the town's real record.

**Why it was not bleeding yet, and why that is thin.** Only `building.gd:185`
joins the `building` group, and `building.gd` is instantiated only by `main.gd`,
so the live dungeon returns `0` group members. The one thing standing between
the deep and the save is that nobody has labelled a dungeon prop "building".

**And the fight really can happen down there.** `GameState.summon_event_boss`
gates the Signet on `is_true_eclipse()`, which is `eclipse_is_active()` — a pure
game-clock check that never asks where the player is standing. `_spawn_summoned`
then adds the director to `get_tree().current_scene`, whatever that is. A player
holding the Signet on a dungeon floor during an eclipse raises the Hollow Sun in
the dungeon today.

**The fix** (`boss.gd`, `_raze_ground_at`): gate on the boss actually standing
in the village, not on the flag.

```gdscript
func _standing_in_the_village() -> bool:
	if GameState.in_dungeon:
		return false
	var s: Node = get_tree().current_scene if get_tree() != null else null
	return s != null and ("village_right_edge" in s)
```

The village is recognised the way `arena_width()` already recognises it — it is
the scene that owns `village_right_edge`. No path literal, survives a rename,
and it keeps `test_hollowsun_node.gd` green because the harness's tester node
lives under `root` while `current_scene` is still `main.tscn`.

Re-measured after the fix: **`hit the group 0 time(s) for 0 damage`**, and every
village-side raze still lands.

### Hand-off patch for `game_state.gd` (the lead's file — I did not touch it)

Razing is now village-gated, which means a Hollow Sun summoned in a dungeon is
just a 23,800-HP boss with none of its stake — the exact opposite of its design
(`"where": "village"`, and the dev's line "he spawns on the ground, you're
endangering your whole village"). Suggest refusing the summon outright rather
than staging a defanged one. In `summon_event_boss`, after the
`require_true_eclipse` check (currently around game_state.gd:2565):

```gdscript
	# THE HOLLOW SUN IS A FIGHT IN YOUR STREETS. Its whole stake is the town it
	# is standing in, and boss.gd now refuses to raze outside the village -- so
	# raising it underground would stage a defanged one. Refuse instead, and do
	# not spend the Signet.
	if in_dungeon and str(EventBoss.get_event(id).get("where", "")) == "village":
		return "Not here. The sky cannot reach you underground."
```

(Applies to the Tallyman, the Grief-Eater and Nihil too — all three are
`"where": "village"` and all three are already condition-gated on `not
in_dungeon` in `tick_hidden_events`; only the item-summoned ones can currently
slip through.)

---

## 3. THE WHOLE-ROW NUMBER — reachable, and here it is.

**Setup.** `main.tscn`, all 15 roster halls standing at 400/400 across the row's
real 9,664 px span, one live Hollow Sun staged through the real path
(23,800 HP, dmg ×2.15, boss_floor 100), player kept alive so the fight is not cut
short. Impacts counted exactly: every `meteors` cast is 10 calls to
`_raze_ground_at`, every `pillars` cast is 6, and each cast is observed by its
own cooldown re-stamp.

### The arithmetic first

- `BUILDING_MAX_HEALTH` 400, `BOSS_RAZE_FLOOR` 0.15 → floor **60**
- `BOSS_RAZE_DAMAGE` 34 → **10 on-target impacts floor one hall**
- 15 halls × 340 hp of headroom = **5,100 hp for the whole row**

### The measurements

| pass | window | casts | impacts | impacts/min | town hp lost | hp/min | halls touched | halls AT the floor |
|---|---|---|---|---|---|---|---|---|
| player parked mid-row | 120 s | 8 meteor + 11 pillar | 146 | 73 | 1,462 / 6,000 | 731 | 5 of 15 | **4 of 15** |
| player kiting the whole row | 180 s | 16 meteor + 17 pillar | 262 | 87 | 3,842 / 6,000 | 1,280 | **15 of 15** | **5 of 15** |

Kiting-pass wounds at the 3-minute mark, every hall in the row:
`Government 230, Barracks 298, Bank 60, Marketplace 128, School 230, Farm 60,
Hospital 128, Fishing Dock 230, Science Lab 196, Blacksmith 60, Tavern 162,
Bar 128, Builderhouse 60, Mine 60, Shrine 128`.

### The answer

**Yes — about four minutes.** At the kiting rate of 1,280 town-hp/min, the
5,100 hp of headroom in a full row is gone in **4.0 minutes**. The boss's pool is
23,800, so a four-minute fight is exactly what a player doing **100 dps** has.
Below 100 dps the whole row floors *before* the boss does; above it, the fight
ends first. The equivalence, for the dev's judgement:

| player dps | fight length | share of the row floored |
|---|---|---|
| 200 | 2.0 min | ~half |
| 100 | 4.0 min | **all of it** |
| 50 | 8.0 min | all of it, twice over |

Two things the table hides and that matter more than the rate:

1. **The limit is travel, not damage.** A hall inside the fight's footprint goes
   400 → 60 in well under a minute — the parked pass floored 4 halls but only
   *touched* 5, because the fight never left a ~600 px window. The kiting pass
   touched all 15. Whether the town falls is decided by how much of it the player
   backs across, and a real player kites.
2. **The stake is narrower than it looks.** Only the 15 role halls are in the
   `building` group. Cottages are `village_structure` and the rampart is
   `village_wall`, so the Hollow Sun cannot scratch a single home or a metre of
   wall. If the intent is "your whole village is endangered", the homes are
   currently exempt — that is a design call, not a bug.

### What flooring the row actually costs the town

`CONDITION_FLOOR` is 0.35, so at the raze floor `building_condition` is
`0.35 + 0.65 × (60/400)` = **0.4475**. A fully floored row does not produce "at
roughly a third" — it produces at **44.8%**, a ~55% town-wide cut until mended.

Recovery: `MEND_PER_PASS` 45, one hall per village tick. A fully floored row is
5,100 hp = **114 mend passes** with a seated Builderhouse leader, 228 with only
workers, and each pass costs stores. That is the real length of the scar.

**`BOSS_RAZE_FLOOR` untouched, per the brief — the constant is the dev's call.**
If it ever moves, the levers in order of bluntness are `BOSS_RAZE_RADIUS` (190;
halving it roughly halves halls-per-impact), the `pillars`/`meteors` cooldowns
(6.5 s each — they are ~10 casts/min combined), and only then the floor itself.

---

## What was NOT done

- `event_boss.gd` needed no change; it is pure data and the rematch ladder
  already handles the eclipse tier correctly (verified live: both summons stage
  at 23,800 HP).
- I did not touch `game_state.gd`, `test_*.gd`, `tool_*.gd` or `sfx_synth.gd`.
  The one change I want in someone else's file is the hand-off patch in §2.
- Fight length is derived from the boss's 23,800 pool against an assumed player
  dps, because no measured endgame player dps figure exists in the repo. If the
  Weapon Lab has one, substitute it into the §3 table and the answer sharpens
  immediately.

## Verification

- `Godot --headless --check-only --script boss.gd` → no parse errors (only the
  expected `Identifier not found: GameState`).
- `MONARCH_TEST=res://test_hollowsun_node.gd` → **ALL PASS** (61 checks), before
  and after the change.
- `test_eclipse_node`, `test_eventboss_node`, `test_boss_guard_node`,
  `test_bossfree_node` → **ALL PASS**.
