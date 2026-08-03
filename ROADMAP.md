# Deepwood — Director's Roadmap

> ⚠️ **Design decisions now live in [`GAME_BIBLE.md`](GAME_BIBLE.md) (2026-07-15) — the single source of truth.** As of 2026-07-15 the project is in a **documentation-first phase**: no new gameplay code until the Bible is polished to 100%. This file stays as the director's log + process notes.

_Maintained by Claude in a project-director/PM capacity (role started 2026-07-13, developer's request). This file is forward-looking only — decisions to make, what's next, what's at risk. It does NOT describe current game state; see `GAME_OVERVIEW.md` for that, `PROJECT_SNAPSHOT.md` for implementation detail, `REVIEW_3DAYS.md` for the last dated review. Re-read those before trusting this file's "current state" framing if it's been a while._

---

## Open decisions awaiting developer input

Don't build toward these without asking first — flagged in the project's own docs/memory as explicitly undecided:

1. ~~Enemy species/identity~~ — **de facto settled**: developer chose undead/evil/deepwood-themed, already implemented across every mob and boss (per boss-design session, 2026-07-13).
2. **How to permanently stop the undying Wizard** (final-final boss, see `wizard.gd`) — still not decided, but a mechanical/lore seed now exists: the L100 Fallen Wizard's **Soul Ward** (near-invulnerable while his soul is whole, only killable once split across his Mirror Legion clones) gives a ready-made answer — "an undivided soul cannot be destroyed" — that could extend to the ember-revival immortality too. Flag this convergence to the developer next time endgame design comes up; don't build toward it unprompted.
3. **Full list of village roles** beyond the ones already named (Government, School, Farm, Hospital, Barracks, Fishing Dock, Science Lab, Bank, Blacksmith, Tavern, Marketplace, Builderhouse) — is this set final or is more planned?
4. **Specific class kits** beyond Sword/Archer/Mage (e.g. bruiser, others TBD) and the Necromancer's real kit once unlocked.

---

## Priority backlog (corrected 2026-07-13 after verifying against live code — see note below)

**Doc-drift correction:** GAME_OVERVIEW.md's "not built yet" list (written 2026-07-11) is stale on two items — verified against actual code on 2026-07-13:
- ~~Buildings start destroyed, repair with materials~~ — **already fully built** (`building.gd`: `State` enum PRISTINE/SLIGHT/HALF/DESTROYED, `build_stage`/`TOTAL_BUILD_STAGES`, `REPAIR_MATERIALS`, `try_build()`, persisted in save data).
- ~~Village siege/defense~~ — **already fully built** (`siege_manager.gd`: scheduled tiers, live battle staging, wall repair on repel, off-screen resolution via GameState).
- Itemization/loot (armor sets, relics, Excellent weapons) — also already built per 2026-07-13 memory notes, contradicting the still-open item on this in GAME_OVERVIEW.md.

**Uncommitted work, identified 2026-07-13** (author: the "Code debugging" session — misleading title, it's actually been building this system; not yet renamed):
- `village_life.gd` (Node2D in main.tscn, village only) — cosmetic "town feels alive" layer, holds no gameplay state. Ambient decor scales with rebuilt-building count (flower boxes/lanterns/garlands/banners, fountain+maypole at full rebuild); birds/butterflies scale with morale. Also a 10/10-morale celebration event (~20s fireworks/confetti/cheering villagers).
- `morale_meter.gd` (Control) — village morale bar in the TAB overlay below the mana bar. Hidden until `GameState.morale_meter_unlocked` (unlocks permanently once every building is repaired, even if a later siege damages one again). Bar color + face (frown→neutral→grin) track fill level.
- `admin_panel.gd` (CanvasLayer, toggle key **P**) — dev/test console: morale nudges, build-all, populate, god mode, kill/heal, gold, time-skips, level unlock. In the esc_window group (closes on Esc).

**Also uncommitted, unattributed:** a ~159-line `boss.gd` delta (Wizard combo system: 5 named ability chains with a punish/recovery window, faster/teleporting clones, denser auras) and new `relic_wings`/`relic_feather` entries in `dungeon_interior.gd`'s loot table. Reviewed by the boss-design session as coherent and cleanly integrated with its own Soul Ward/clone systems, but not authored by that session. Source unconfirmed — flag before it gets committed as part of an unrelated blob.

**Remaining real backlog**, re-verified:
1. **Hostage rescues inside dungeons** (currently only in the village) + more hostages + hidden-stat quests.
2. **Game ending / final boss** (Wizard reveal + the "how to stop an undying being" mechanic) → unlocks Necromancer.
3. ~~How to Play panel~~ — **DONE 2026-07-13** (background agent fixed the stale "Wave Survival" text, added missing E/Tab/K/weapon-5 controls, resized panel to fit). Uncommitted, ready to review.
4. **"Wand rework" — reframed 2026-07-13, not a rework.** The 1g shop Magic Wand's instant-kill AoE is intentionally an admin/test tool (developer confirmed) — fix is to gate/label it admin-only like the existing Ruin Wand, not design a new spell. See `deepwood-admin-wand` memory. Relayed to the "Weapons, armor, and item sets" session (owns inventory.gd/item-catalog context right now).
5. **Reset potion as a real inventory item** (currently a UI button) — also relayed to the "Weapons, armor, and item sets" session alongside #4, since both touch the item catalog. Must follow the new standing rule: inventory icon should closely match in-hand appearance (see `deepwood-item-visual-rule` memory) — applies to all future items, not just this one.

**Lesson applied:** verify against live code before assigning/parallelizing backlog items — don't trust "not built yet" lists once they age. Also: route a task to whichever session already owns the relevant file's context rather than forking a competing background agent, when there's no true isolation available (see "Process notes" below).

## Process notes

- ~~This director session runs from `C:\Users\bacho\Documents\lazy`~~ — **obsolete since the 2026-07-28 consolidation:** `Documents\deepwood` is the one project home, and `lazy` was renamed to `clicker-prototype` (it never was a Deepwood folder). Open every session from the repo itself.
- **Run the audits the way each one is written.** Most are Node tools driven by the `MONARCH_TEST` hook, but `tool_art_audit.gd` `extends SceneTree` and must be run as `--script res://tool_art_audit.gd`. Under the hook it attaches nothing, the menu idles, and the run looks like a hang until the timeout — a false alarm that costs seven minutes each time.
- The developer's 3 other sessions (weapons/armor/item-sets, enemy/boss design, code debugging) stay manually-driven — reserved for taste-heavy/iterative work. This director session handles well-scoped mechanical tasks + cross-session coordination + the standing backlog/decision log.

---

## Risk flags

- ~~**Uncommitted work (as of 2026-07-13):** 10 modified files + untracked `admin_panel.gd`, `morale_meter.gd`, `village_life.gd`~~ — **RESOLVED long since;** all of it is on master. (Left struck through as the standing reminder that this file's "current state" claims age badly.)
- ~~**Abandoned worktrees on disk (2026-08-03).**~~ **CLEARED 2026-08-03.** `.claude/worktrees/bestiary` and `.claude/worktrees/gifted-murdock-786925` are removed and pruned; `.claude/worktrees` is empty. Everything of value was landed first — `gifted-murdock`'s whole session of finished fixes (see the log entry below), and `bestiary`'s untracked `tool_eyes_projectiles.gd`, which existed nowhere else and was committed on its own (`4f89191`) before deletion. Three branch pointers remain — `claude/bestiary`, `claude/gifted-murdock-786925`, `terraria-underground` — all fully contained in master (0 commits master lacks), kept as harmless history.
- **The standing lesson from that clean-up:** a worktree branch pointing at master's own commit is invisible to `git log` and `git status` from the repo root. Before any bug hunt, run `git worktree list` and `git -C <each> status --short` — a session's last uncommitted hour lives there and nothing else will show it to you.

---

## Active parallel threads (snapshot — will go stale, not auto-updated)

As of 2026-07-13: sessions in flight on weapons/armor/item sets, enemy models/boss design, and general code debugging, all against this same repo.

---

## Director's log

- **2026-08-03 — PM role re-affirmed as standing, and a full repair pass.** Ran the whole standing kit (10 audits + all 119 registered suites) and fixed what it found, changing no design:
  - **ESC did nothing over either fullscreen map.** `underground.gd` and `world_map.gd` joined `esc_window` with only half its contract, and `pause_menu.close_open_windows()` called the missing half unguarded — so the sweep threw mid-loop, the pause menu never opened, and the chart stayed stranded. Both halves implemented, and the sweep now skips (and warns about) a half-implemented member instead of dying on it.
  - **The Standing Star could not be found by anyone.** A finished legendary companion relic in no drop pool and no recipe; added to the boss gear-relic pool, where `_gear_in_depth` puts it at a legendary's depth.
  - **Three slow clocks were never saved** — the Lumberyard's timber day, the Dock's Tide Table, and the store's fractional banking. A Continue threw their progress away. Now saved, restored, and reset on New Game (that last one caught by the reset audit *after* the fix — the audit earning its keep).
  - **The EYES bestiary tool filmed at midnight.** It set `day_night_cycle.time_of_day`, which that node re-derives from the master clock every frame; it drives `GameState.game_hours` now.
  - **Audit accuracy:** the gap audit cried wolf over the starting six (it knew only two of the three spawn sources), over flavour prose containing "every", and over the retired gloves/boots slots; the wiring audit called every test/EYES handle dead bookkeeping. 4 gap + 5 wiring false alarms gone. Gap, save, reset and promise audits all read **0**; wiring is down to **7**, all of them true dead group joins left in place deliberately (`speech_text`, `training_dummy`, `ug_rope`, `ug_door`, `ug_elite`, `ug_hazard`, `dungeon_manager`) — inert, and deleting them buys nothing a reader doesn't already get from this line.
  - **Rescued a stranded session.** Most of the above was independently found and fixed weeks ago inside `.claude/worktrees/gifted-murdock-786925` and never committed. Landed, after trimming a double-save it introduced (four of its seven clocks were already persisted under other key names) and tightening one over-broad regex.
- **2026-07-13** — Role established at developer's request (director/PM for Deepwood specifically, not the unrelated "lazy" clicker prototype). Did first full briefing: reviewed GAME_OVERVIEW.md, PROJECT_SNAPSHOT.md, REVIEW_3DAYS.md, git log/status, and memory. Created this file.
- **2026-07-13** — Spawned background agent for the How-to-Play panel fix (done, uncommitted). Discovered building-repair and siege/defense were already built, corrected the backlog. Relayed the wand-admin-label + reset-potion-as-item task to the weapons/armor session (owns inventory.gd right now). Identified the "Code debugging" session as the actual author of village_life.gd/morale_meter.gd/admin_panel.gd (title is stale). A user-started background task is renaming the stale `BestWaveLabel` node, running independently.
