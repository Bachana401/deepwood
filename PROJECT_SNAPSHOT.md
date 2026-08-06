# Deepwood — Project Snapshot

_Generated as a technical brief for a fresh AI assistant with zero prior context on this codebase. Written by the Claude instance that implemented most of the features below, across a long iterative session with the developer (a solo hobbyist, non-professional-dev, works conversationally/casually, iterates a lot on visual polish by eye rather than spec)._

**Engine:** Godot 4.7, GDScript, GL Compatibility renderer (`renderer/rendering_method = "gl_compatibility"`), Windows target (`d3d12` device driver configured but compatibility mode used).
**Project root:** `C:\Users\bacho\Documents\deepwood`
~~**Not a git repo**~~ — **it is now** (corrected 2026-08-06): master plus per-session worktrees under `.claude/worktrees/`, and several sessions commit concurrently. Rebase before you assume the tree you read is the tree that shipped.
**Boots to:** `main_menu.tscn` (`run/main_scene`). Gameplay lives in `main.tscn`.
**Autoload:** single autoload `GameState` (`res://game_state.gd`) — save/load + best-wave high score.

---

## 1. The story/premise (drives future feature direction)

This is a 2D side-scrolling platformer that started as a mechanics sandbox but now has an explicit narrative the developer wants future systems anchored to:

> A lone adventurer arrives at a small, once-thriving village now nearly empty. The few surviving villagers are starving and near death amid ruins of what used to be a working settlement (fishing dock, farmland, a bank, some kind of authority/police post, a school). Enemies — exact type (zombie/vampire/other) still **undecided** — raided the village and took almost everyone hostage, feeding on captives without fully killing them, leaving them in a "neither alive nor dead" frozen/traumatized state. A surviving villager begs the adventurer for help. The adventurer has fought this enemy before but only in small numbers, and only gradually realizes how widespread the threat is. The plan that forms: rescue every captured villager, destroy the threat at its root, restore the village, and become its leader.

**Confirmed direction (developer explicitly said "save this, I like this concept"):** rescuable NPCs scattered through the level, each tied to a location/story thread — a farmer near farmland, a fisherman near the dock, a banker near the bank, a guard near a police post, a teacher near a school. Likely shape: placed around the course similar to how `course_enemy` groups are scattered today, each in the frozen hostage state, freed via some player interaction, unlocking farming/fishing/banking systems as meta-progression gated behind story advancement (not just a flat shop).

**None of this NPC/rescue/village-restoration system is built yet.** The current game is a pure "run right, fight enemies, reach a wave-survival minigame" sandbox with zero narrative framing in the actual UI/world (no dialogue, no NPCs, no village state). This is almost certainly the single biggest gap between "what exists" and "what the developer has said they want."

---

## 2. High-level feature inventory (what's actually implemented)

- Side-scrolling platformer movement: run, jump, double jump (purchasable), dash (purchasable, double-tap A/D)
- 4 weapons: sword, spear, bow, magic wand (instant-kill AoE) — player buys spear/bow/wand and upgrades at a shop
- Enemies with AI: patrol, aggro/chase, 3 weapon types (sword/spear/bow), wall-avoidance, jump-over-obstacles, "hesitation" and jump-desync randomization so groups don't move in lockstep, respawn-with-growth on the open course
- A boss (slam / charge / barrage attacks, enrage at 50% HP)
- A wave-based "Survival Mode" minigame in a walled arena: countdown start, escalating waves, per-wave stat scaling, boss every 5th wave, best-wave persistence
- Explosive floor traps scattered across the course and on elevated platforms (armed → blinking warning → AoE explosion → rearm)
- A shop (walk into a zone, UI appears, double-click items to buy: dash, double jump, spear, bow, magic wand)
- Save/load (JSON to `user://savegame.json`) + separate best-wave high score file, wired through a main menu (Start/Continue/New Game) and a pause menu (Esc, resume/exit-survival/settings/quit)
- A full day/night cycle: 10-minute real-time day, moving sun/moon with parallax + arc motion, 5 moon phases with phase-accurate glow and craters, a brief sun/moon sky-overlap window, a clock HUD, and debug time-skip keys
- Procedurally generated mountains (6, varied size/shape/color) and drifting clouds (40, varied size/shape/speed) as background scenery
- Cosmetic juice: camera shake on impactful hits, burn-away enemy death animation, coin pickup popups, neon shop sign, ominous survival-mode sign, toast notification stack, background music loop

---

## 3. Script catalog (every `.gd` file, what it does, key numbers)

### `player.gd` — player controller
`CharacterBody2D`. `SPEED=200`, `JUMP_VELOCITY=-400`, `GRAVITY=900`, `MAX_HEALTH=100`. Starting `currency=9999` (looks like a leftover debug value — flag this to the developer if it comes up, since 9999 starting gold trivializes the shop).

Dash: `DASH_SPEED=600`, `DASH_DURATION=0.15s`, double-tap-within-`0.3s` detection, `0.5s` cooldown. Gated behind `has_dash` (shop purchase).

Double jump gated behind `has_double_jump` (shop purchase).

Weapons dict (`WEAPONS`): sword (dmg 8, cd 0.3s, kb 30-60), spear (dmg 24, cd 0.9s, kb 60-90), bow (dmg 15, cd 0.5s, kb 24-48, fires `arrow.tscn`), wand (dmg 0 direct — instead `cast_wand()` iterates groups `course_enemy`/`wave_combatant` and calls `take_damage(999999)` on all of them, i.e. a full-screen instant-kill AoE, cd 1.0s). All weapons aim omnidirectionally toward the mouse (`get_aim_direction()`), not just left/right — this was a specific past bug fix (weapons used to only face left/right).

Health/death: `take_damage()` respects 1s invincibility + red flash after a hit; `die()` does an 0.8s death pause then resets health/position to spawn point (no permadeath, no game over screen — death is just a soft reset).

No signals declared. Depends on sibling `CanvasLayer/CurrencyLabel`, own child nodes for weapon visuals, groups `course_enemy`/`wave_combatant` (read, for wand AoE), is itself in group `"player"`.

### `enemy.gd` — patrol/aggro enemy AI
`CharacterBody2D`. `SPEED=100`, `MAX_HEALTH=60`, `DETECTION_RANGE=225` (doubled for bow-type, `INF` if `instant_aggro=true` which survival-mode enemies use).

Two operating modes via exported vars:
- **Course enemies** (`respawns=true`): placed statically in `main.tscn`, respawn `RESPAWN_DELAY=3s` after death with `GROWTH_PER_RESPAWN=1.085` — each respawn generation is 8.5% stronger (HP/damage/detection scale with `generation`), and darkens color per generation. This is the course's only difficulty-ramp mechanic — an enemy you keep killing in the same spot gets tougher each time.
- **Wave combatants** (`respawns=false`, `instant_aggro=true`): spawned/destroyed per-wave by `survival_manager.gd`, external `wave_hp_multiplier`/`wave_damage_multiplier`/`wave_speed_multiplier` applied at spawn.

AI details worth knowing: wall-avoidance (detects blocked slide collisions, turns around, temporarily boosts detection range so it "notices" the player through the delay), jump logic reacts to player being above with a randomized per-enemy reaction delay so a cluster of 3+ enemies doesn't jump in perfect sync (`JUMP_DESYNC_*` consts), random "hesitation" pauses (`HESITATE_MIN/MAX_INTERVAL`) so movement doesn't look robotic, bow-type retreats/holds range instead of closing distance. `check_bump()` does soft knockback-only separation between enemy and player at close range (see §6 for why this isn't solid collision).

Death: rewards player currency, spawns a coin popup + burn-away particle/color/shrink animation, `emit signal died` (survival manager listens to this to track wave clear).

`enemy.tscn` has an unused `DamageArea` (Area2D, collision_mask=2/player) with no script connections anywhere — likely vestigial from an earlier melee-contact-damage design that got replaced by the explicit `try_deal_melee_damage()` timing-based approach. Safe to ignore or clean up.

### `boss.gd` — boss enemy
`CharacterBody2D`, `MAX_HEALTH=600`, `SPEED=70`. Three attacks chosen randomly from whichever are off-cooldown and in-range:
- **Slam**: AoE radius 170, dmg 28, kb 220, 0.55s telegraph (yellow flash), 3.5s cooldown, needs dist<187
- **Charge**: dashes at 520 speed for 0.5s, dmg 24, kb 260, 0.45s telegraph (red flash), 4.5s cooldown, needs dist>160
- **Barrage**: fires 5 arrows in a 16° fan spread, dmg 10 each, 0.35s telegraph (orange flash), 3s cooldown, range 550, arrows pierce terrain

Enrages once at ≤50% HP: darkens toward red, cooldowns multiply by 0.6 (faster attack cadence). `apply_knockback()` is a deliberate no-op — the boss cannot be staggered. Spawned by `survival_manager.gd` every 5th wave with wave-scaled `max_health`/`damage_multiplier`/`speed_multiplier`.

### `survival_manager.gd` — wave-survival orchestration
`Node`, group `"survival_manager"`. Arena is walled at `ARENA_MIN_X=-695`. Spawn logic (`get_spawn_x()`) picks a side relative to the player's *current* position (not a fixed world band — this was a deliberate fix so spawns "follow" the player around the arena), distance randomized in `[SPAWN_MIN_DISTANCE=156, SPAWN_MAX_DISTANCE=260]`, clamped so it never spawns past the containment wall.

Wave scaling (`get_wave_scaling()`): `hp_mult = 1 + (wave-1)*0.15`, `dmg_mult = 1 + (wave-1)*0.10`, `speed_mult = 1 + (min(wave,25)-1)*0.075` (speed scaling caps at wave 25 so enemies don't eventually outrun the player). Enemy count per wave: `min(2 + wave-1, 8)`. Every 5th wave (`current_wave % 5 == 0`) spawns a boss instead of a regular group.

Flow: player walks into `SurvivalZone`, presses F (`start_wave` action) → 3-2-1-FIGHT countdown (cancellable) → `hide_course_enemies()` freezes/hides all `course_enemy` group members for the duration → waves spawn/clear in a loop (`_on_combatant_died` tracks `alive_count`, 2.5s pause between waves) → `exit_survival()` (via pause menu) tears down remaining combatants and restores frozen course enemies.

Records best wave via `GameState.record_wave()` on every wave start (so "best wave" updates live, not just on death/exit).

### `game_state.gd` — autoload, save/persistence
`SAVE_PATH="user://savegame.json"`, `BEST_WAVE_PATH="user://best_wave.dat"`. Saves: currency, position, owned_weapons, equipped_weapon, has_dash, has_double_jump, health. `pending_load` flag is set by main-menu "Continue" and consumed by `main.gd` on scene ready. Best wave is a raw stored 32-bit int, separate from the JSON save (survives "New Game" which deletes the save file but not the high score).

### `main.gd` — world setup / procedural scenery
`Node2D`, root script of `main.tscn`. On `_ready()`: generates mountains, grass tufts, ground traps, platform traps, clouds, starts music, applies save data if `GameState.pending_load`.

**Mountains** (`generate_mountains()` / `generate_mountain_shape()`): 6 zones defined in `MOUNTAIN_ZONES` (x position, width, height, peak count, color) — 2 large ones near player spawn (different shapes/palettes), 2 more large ones further along the course, 2 small ones filling gaps. Shape generation blends a few random "peak" positions/heights via inverse-distance falloff, tapers to ground level at both edges via a sine envelope, plus fine per-point jitter — deliberately not pure noise, so it reads as real summits rather than random zigzag. Went through several size iterations this session (3x'd, then -25%'d) chasing a "looks like mountains not rocks" result.

**Clouds** (`generate_clouds()` / `generate_cloud_shape()`, driven each frame in `_process()`): `CLOUD_COUNT=40` (recently doubled from 20), spans `x=[-900, 5000]`, `y=[-720,-470]`, size scale `0.6x-2.4x`, bumpy-blob polygon shapes (varied point count/width/height/bumpiness), each with its own random drift speed (`3-10`) stored via `set_meta`, wraps from span-end back to span-start.

**Traps**: `generate_traps()` places 25 ground-line traps with jitter, explicitly avoiding a safe zone near spawn (`TRAP_SAFE_ZONE_MIN/MAX = -365..-85`); `generate_platform_traps()` places one trap on each of 12 named elevated-platform zones (`TRAP_PLATFORM_ZONES`), inset from platform edges.

**Grass**: cosmetic tufts along the ground line and on named platform clusters, no gameplay effect.

### `day_night_cycle.gd` — day/night cycle, sun, moon (the most iterated system this session)
`Node`, sibling of `CanvasModulate`/`SunIcon`/`MoonIcon` under `Main`. Full day = `DAY_LENGTH_SECONDS=600` (10 real minutes) = 24 in-game hours.

**Darkening**: `CanvasModulate.color` lerps `DAY_COLOR` (white) → `NIGHT_COLOR` (dark navy `0.16,0.18,0.34`) across dawn (`5:00-7:00`) and dusk (`18:00-20:00`) windows. `CanvasModulate` multiplies against *everything* sharing its canvas — including the sun/moon's own rendered color — which is why the moon needs the "counter-color" trick below to stay visible at night instead of getting crushed toward black along with everything else.

**Sun/moon motion**: both are `Node2D` siblings of `Main` (not children of the camera — that was tried first and looked "glued to the screen," see §6). Positioned each frame via a shared `arc_position(progress, anchor_x)`: rises low → peaks high → sets low (sine height curve) with a horizontal parallax anchor `anchor_x = player.global_position.x * PARALLAX_FACTOR (0.12)` so they drift slowly with the player instead of tracking 1:1 or staying fixed.

> **⚠ Superseded 2026-08-06 — this paragraph describes a bug.** That anchor put the sky **88% of the player's travel behind the camera**, measured at ~3,000 screen px off the left edge at the west gate and 7,250 at the Bar. It scales linearly with x and the village row runs past 20,000, so no smaller factor fixes it — any value below 1.0 leaves an unbounded drift. `get_parallax_anchor_x()` now returns the **live camera's screen centre** (parallax belongs to the ridgelines, which already have it), and the arc was lowered and widened (`SKY_HORIZON_Y`/`SKY_PEAK_Y`/`ARC_SWING_X`) because noon sat above the frame. Net effect of the old behaviour: **nobody had ever seen the sun or moon from their own town, at any hour.** `PARALLAX_FACTOR` survives as a dead constant. Current behaviour: `GAME_MECHANICS.md` §10. Sun window 6:00-18:00, moon window 18:00-30:00 (i.e. 18:00 to 6:00 next day). Both windows are widened by a small `SUN_MOON_OVERLAP_HOURS` (~7 real seconds worth) centered on the rise/set point, so there's a brief moment both are visible at once around dawn/dusk — `is_sun_moon_overlap()` is a public hook for gameplay to key off this — *the hidden event the developer floated here was built: `GameState._sun_moon_both_up()` reads this hook, and it is the gate on Nihil's Duskmoon Effigy. Note it is the **ordinary twice-daily crossing**, kept deliberately separate from `is_true_eclipse()` — see `GAME_MECHANICS.md` §10.1.*

**Sun visuals** (`build_sun`): radius 44.2, warm gold color, layered as glow-outer/glow-inner (additive blend, tight halo) → 12 outward rays (additive, thin/long/faint) → solid disc (normal blend) → one small white "surface highlight" dot offset toward lower-left (slightly irregular polygon, not a perfect circle). A second, earlier "inner grey dot" nested inside the highlight was added then explicitly removed per developer feedback ("delete gray dot, leave only white dot").

**Moon visuals** (radius 40, silver-with-slight-yellow-tint color `0.83,0.81,0.75`): same glow-outer/glow-inner treatment but noticeably shinier than the sun's (higher alpha) since the developer wanted the moon to visibly "shine" — plus a third, much larger three-layer "sky glow" (`SKY_GLOW_LAYERS`, radius 4x/7x/11x the moon) that lights up the open sky around it. That sky glow sits at `z_index` between the flat sky bands (-100) and all terrain/gameplay (0 default) specifically so opaque ground/platforms/mountains drawn on top mask it out of the play area automatically — it can never make enemies more visible at night, which was an explicit requirement ("moon should emit light on the sky, but that doesn't mean night gets brighter for gameplay").

**Moon phases**: 5 defined in `MOON_PHASES` — `full (k=1.0)`, `gibbous (k=0.5)`, `half (k=0.0)`, `crescent (k=-0.5)`, `thin_crescent (k=-0.85)`. A new phase is picked (`pick_new_moon_phase()`) each time night begins, never repeating `full` twice in a row. Geometry (`build_moon_phase`): a semicircle "limb" plus a terminator curve scaled by `k` (k=1 → full circle, k=0 → straight half-moon edge, k<0 → the terminator curves back INTO the lit side, producing a crescent). `k≈0` (near-exact half moon) is special-cased to close with a straight 2-point edge instead of the general sweep, because ~29 exactly-colinear points there triggered visible polygon-triangulation glitches.

**Moon craters** (`generate_moon_craters(k)`, regenerated fresh every phase change — this was the fix that just went in this turn): rather than scattering craters across the whole disc and rejecting ones that don't fit the current phase (which left crescent/thin_crescent almost bare, since a full-moon-sized crater can't fit a sliver a few px wide), craters are now sampled directly within the current phase's actual lit band, with each crater's radius fitted via binary search (`max_crater_radius_at`) to whatever that spot can hold, capped at `[MOON_CRATER_RADIUS_MIN=5, MOON_CRATER_RADIUS_MAX=11]`. Result: full/gibbous/half still get ~10 varied craters, crescent gets ~8 smaller ones, thin_crescent gets ~6 quite small ones near the limb — verified via headless test just before this snapshot was written. `is_crater_fully_in_phase()` (samples 8 points around each crater's own circumference, not just its center) guards against any crater visibly poking past a curved terminator.

**Counter-color trick**: since `CanvasModulate` darkens the moon along with the sky, `update_moon_true_colors()` sets the moon's actual node colors each frame to `true_color / canvas_color` (component-wise, legitimately >1.0) so the engine's automatic multiply cancels out and the moon renders at its true color regardless of time of day. Applies to body, both glow layers, all 3 sky-glow layers, and every crater dot (crater's true color stashed via `set_meta("crater_color", ...)` since the dot's `.color` property itself gets overwritten with the counter-adjusted value).

**Debug time controls** (for previewing the cycle without waiting 10 minutes): `[` = time_backward (-1h), `]` = time_forward (+1h), `\` = time_skip_day (+24h, also forces a new moon phase pick). These are real input actions in `project.godot`, not commented-out debug code — currently live in the shipped input map.

### `main_menu.gd` / `pause_menu.gd` — menus
Main menu: Start (only shown if no save)/Continue+New Game (only shown if save exists)/How to Play (toggles an in-place panel)/Quit. Reads `GameState.has_save()` and `GameState.best_wave`.

Pause menu: `Esc` toggles, sets `get_tree().paused`. Resume/Exit-Survival (only visible if a wave is active — calls `survival_manager.exit_survival()`)/Settings (a volume slider wired to `AudioServer` master bus)/Save&Quit-to-Menu/Quit-Game. Both quit paths call `GameState.save_game()` first.

### `shop_ui.gd` / `shop_zone.gd` / `shop_sign.gd` — shop
Walk into `ShopZone` → UI panel appears (`shop_zone.gd` toggles visibility on `body_entered`/`body_exited`). Double-click an item label to buy: Dash (30g), Double Jump (20g), Spear (40g), Bow (35g), Magic Wand (1g — priced almost free, likely intentional given wand is an instant-kill AoE and the developer may want it as a cheap "fun button" rather than balanced, but worth flagging as a possible balance oversight to a future assistant). `shop_sign.gd` procedurally builds the animated neon "SHOP" sign with a flickering bulb and lightning bolts — purely cosmetic.

### `survival_zone.gd` / `survival_sign.gd` — wave-mode entry
Same enter/exit pattern as the shop zone but shows a "Press F" prompt instead of a persistent UI, and only while the survival manager isn't already started/starting. `survival_sign.gd` procedurally builds the ominous "SURVIVAL WAVE MODE" sign with a heartbeat-pulsing label and flickering spikes.

### `trap.gd` — explosive floor traps
Armed by default. On player contact: 0.7s blinking warning (`WarningIcon`), then explodes — AoE radius 55, dmg 22, knockback 30-45 away from trap center, camera shake if player's in range — then rearms after 14s. Not currently able to hurt enemies (mask=2, player layer only) — traps are a player-only hazard, not usable against enemies.

### `arrow.gd` — shared projectile
Used by player bow, enemy bow, and boss barrage. `setup(dir, dmg, kb_min, kb_max, target_mask, pierce_terrain, custom_max_range)` — the same script handles all three cases by varying `target_mask` (4=enemy layer for player arrows, 2=player layer for enemy/boss arrows) and `pierce_terrain` (enemy/boss arrows pierce terrain with a capped range so they can still hit the player around/through geometry; player arrows don't pierce and break on any collision).

### `camera_shake.gd` — attached to Player's `Camera2D`
`shake(strength, duration)` takes the *max* of current vs incoming (so overlapping shakes don't cancel out or reduce intensity), applies random jitter to `offset` while active. Called by player (`take_damage`), boss (slam/charge hits), trap (explosion).

### `notification_stack.gd` — toast notifications
Top-right stacked labels, 2.2s hold + 0.5s fade, auto-cleanup. Used by shop purchases and survival wave/notification events.

---

## 4. Scene structure — `main.tscn` (the whole game world)

Root `Node2D` "Main", script `main.gd`. Notable direct children:

- `CanvasModulate`, `DayNightCycle`, `SunIcon`, `MoonIcon` — see day/night section above
- `Background`: 4 stacked `ColorRect` sky-gradient bands (z=-100), a static placeholder `Sun` polygon (separate from the dynamic `SunIcon`, currently hidden at runtime via `old_sun.visible=false`), and an empty `Mountains` container populated at runtime
- `Ground` — one huge `StaticBody2D` spanning the whole level (x≈-713 to 4487) as the main floor
- `Ground2` through `Ground13` — 12 elevated one-way platforms (`one_way_collision=true`, jumpable from below) forming the climbing/traversal path, ascending up to roughly y=-420 (more negative = higher)
- `Player` spawns at `(-300, -150)`, group `"player"`
- `Enemy` through `Enemy10` — 10 static course enemies, group `"course_enemy"`, spread from x=400 to x=4000 with varied `weapon_type` and `base_color` (reads as a loose difficulty/biome progression left-to-right)
- `CanvasLayer` — UI: CurrencyLabel, ClockLabel, NotificationStack, WaveLabel, CountdownLabel, ShopUI, (PauseMenu is actually its own top-level `CanvasLayer`, not nested here)
- `ShopZone` at x≈-150, `SurvivalZone` (arena entrance) at x≈-330 — both near player spawn, close together
- `SurvivalManager`, `ArenaWallLeft` (the physical containment wall at x=-700 matching `ARENA_MIN_X=-695`)
- `PauseMenu` (own `CanvasLayer`)
- `Decorations`, `Clouds`, `Traps` — empty containers in the saved scene, populated procedurally at runtime by `main.gd`

**Overall level geometry**: playable course runs left-to-right from the arena wall (x≈-700) to the right edge of the ground strip (x≈4487). Shop and survival-arena entrance both sit close to player spawn on the left. Enemies and platforming climb progressively rightward/upward. This is a single long linear level, not an open/branching map.

Other scenes (`boss.tscn`, `enemy.tscn`, `trap.tscn`, `arrow.tscn`, `main_menu.tscn`) are all simple, mostly procedurally-dressed at runtime by their scripts — see script catalog above for what each one builds.

---

## 5. Known rough edges / things worth a second look

- No git / version control on this project at all.
- Player starts with `currency=9999` — trivializes the shop unless intentional as a debug leftover.
- `buy_dash` and `start_wave` input actions are both bound to the F key (not currently conflicting in practice since they're used in different UI contexts, but worth knowing if adding new F-key interactions).
- `enemy.tscn`'s `DamageArea` node is unused dead weight (no script references it).
- Magic Wand costs 1g for an instant-kill full-screen AoE — likely undertuned/a placeholder price.
- Traps only damage the player (collision mask doesn't include enemies) — can't be used tactically against enemies.
- Debug time-skip keys (`[`, `]`, `\`) are live in the shipped input map, not gated behind any debug flag.
- `is_sun_moon_overlap()` exists as a hook but nothing consumes it yet — the developer mentioned wanting "some hidden event" tied to it but hasn't specified what.
- The standalone Windows export (`Deepwood.exe`, built earlier in the project's history) is stale relative to current source — no rebuild has been requested recently.
- Zero narrative/NPC content exists yet despite the confirmed story direction (see §1) — this is the biggest content gap, not a bug.

---

## 6. Design decisions worth preserving (so they don't get "fixed" by accident)

- **Player/enemy collision is intentionally soft-knockback-only, not solid-body collision.** Solid collision was tried once and reverted: Godot's `is_on_floor()` doesn't distinguish collider identity, so an enemy landing on the player's head would treat the player's body as solid ground and get permanently stuck floating there while pinning the player. If this comes up again, the fix direction is knockback tuning (`check_bump()`/`BUMP_THRESHOLD`), not re-enabling solid collision.
- **Sun/moon are NOT children of the camera.** That was the first implementation and looked "glued to the screen" per developer feedback — they're world-space siblings of `Main` with a small parallax factor instead.
- **CanvasModulate darkening + counter-color trick, not a separate CanvasLayer, for day/night.** A separate CanvasLayer for the moon would fully exempt it from darkening with much less code, but would also break z_index interleaving with the base canvas (the moon needs to render behind terrain via z_index, which only works within the same canvas). This tradeoff was deliberate.
- **Moon glow uses `CanvasItemMaterial` with `BLEND_MODE_ADD`, not normal alpha blending.** Established via research this session: normal alpha blending mathematically can never look like light emission, only a faded overlay — only additive blending genuinely brightens. This applies to all glow/ray layers; solid discs/bodies stay on normal blending so they still read as opaque surfaces.
- **Moon craters are regenerated per-phase now (as of this session), not generated once and filtered.** See day_night_cycle.gd section above — this was a deliberate redesign, not just a bugfix, to fix crescent phases looking "unnatural"/near-empty.

---

## 7. Testing methodology used throughout this project

All changes in this project have been verified via **headless Godot execution**, not static reasoning alone — this was an explicit, repeatedly-enforced requirement from the developer. Pattern used:

1. Write a temporary `_test_runner.gd` (extends `Node2D`, `_ready()` calls a `run_tests()` function, then `get_tree().quit()`) and a matching `_test_runner.tscn` in the project root.
2. Run: `"/c/Users/bacho/Desktop/Godot.exe" --headless --path . res://_test_runner.tscn`
3. **Must use the scene-based runner, not `--script` mode** — autoloads like `GameState` are only available when the scene tree actually boots, which `--script` mode doesn't do.
4. Always delete the temp files afterward: `rm -f _test_runner.gd _test_runner.tscn _test_runner.gd.uid`

Common gotchas hit repeatedly: a single `await get_tree().process_frame` doesn't reliably guarantee a node's own `_process()` has already run before you inspect its state — prefer direct function calls / explicit re-invocation over relying on frame timing in tests. When a test fails, always check whether it's a real bug vs. a test artifact (stale `queue_free()` timing, randomized positions colliding with an unrelated check, etc.) before concluding either way.

---

## 8. Suggested next-step framing for whoever picks this up

Given §1's story direction is the stated long-term goal but §2's feature list is 100% mechanics/sandbox with zero narrative content, the highest-leverage next conversation is probably: **decide the enemy identity (zombie/vampire/other — still explicitly undecided) and prototype the first rescuable NPC** (one NPC, frozen-hostage visual state, a simple free/rescue interaction, maybe unlocking one meta-progression hook like the farming or bank system) rather than continuing to polish existing systems (day/night, mountains, clouds have all had substantial iteration already and are in a good place per developer feedback — "sun and moon look amazing," "clouds look sick"). The developer also mentioned once having "a different approach" to meta-progression they wanted to describe later but never followed up — worth asking about before building farming/fishing/bank systems from scratch.
