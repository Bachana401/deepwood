# DEEPWOOD — Mechanics Reference

_What the code actually does, as of 2026-07-17 (HEAD `1d719bd`). Every number here was read out of the source, not from design docs._

**How this differs from the other docs:** `GAME_BIBLE.md` and `VILLAGE_SYSTEMS.md` describe the *intended* design (much of it still 📋 planned). This file describes only **what is built and running**. Where a system is partially wired, it says so.

**Scope:** mechanics only. No art, no audio, no story prose.

---

## 1. Core loop

```
Dungeon floor → kill things → loot + XP + materials → return to village
→ spend (repair, assign villagers, breed, research, skills) → deeper floor → repeat
```

Two scenes: **`main.tscn`** (village overworld, side-scrolling) and **`dungeon_interior.tscn`** (a generated floor). Currency, inventory, equipment, health and the master clock all carry across both. Village position is restored on exit.

---

## 2. Player

### 2.1 Movement

| Property | Value |
|---|---|
| Move speed | `200.0` px/s (modified by `move_speed` bonuses) |
| Jump velocity | `-400.0` |
| Gravity | `900.0` |
| Dash speed / duration | `600.0` / `0.15s` |
| Dash cooldown | `0.5s` |
| Double-tap window | `0.3s` |

- **Fall damage**: free below `300px` of drop; beyond that, `0.15` damage per pixel. Jumping never hurts — only real drops.
- **Flight**: `10.0s` max, rise speed `-300`. Gated behind god-mode / monarch form.

### 2.2 Vitals

| Property | Value |
|---|---|
| Base max health | `160` |
| Base max mana | `90.0` |
| Mana regen | `4.0`/sec |
| Default wand cost | `30` mana |
| Invincibility after hit | `1.0s` |
| Inventory capacity | `55` slots |
| Hotbar | `10` slots |
| Starting gold / silver / bronze | `50` / `20` / `15` |

### 2.3 Damage pipeline (order matters)

Incoming damage resolves in this exact order in `player.take_damage()`:

1. **Dodge** — `dodge_chance` roll; on success the hit is negated entirely (no damage, no effects).
2. **Mana shield** — `mana_shield` fraction (clamped `0.0–0.8`) is paid from Mana instead of HP.
3. **Damage reduction** — `damage_reduction` applied.
4. **Undying** — if `undying > 0` and not yet used this life, a lethal hit instead snaps you back to **20% HP**. Once per life (`undying_used`).

### 2.4 Crit

```
crit_chance = clamp(0.05 + bonuses + buffs, 0.0, 1.0)
crit_damage = 0.5 + bonuses
on crit:  damage = base * (1 + crit_damage)
```

Base is **5% chance / +50% damage**. Everything else is additive from gear, relics, sets and skills.

### 2.5 Death

- Drops **77%** of carried gold at the death spot as a recoverable pickup.
- `7.0s` countdown, then respawn.
- **Difficulty** (chosen once at New Game, saved): `"Medium"` is the default. Medium additionally loses a random villager on death; Hard also loses a skill material.

### 2.6 Levitate

Innate to every class (`*_levitate` node, `default_unlocked: true`, cost 0). You telekinetically float an equipped weapon around you rather than swinging it by hand. Base reach `26.0px`; the Mage's **Sage** spec is the only path that meaningfully extends it (`levitate_range` +120/+160/+120 across Far Hand → Distant Hand → Transcendence).

---

## 3. Progression

### 3.1 XP & levels

Kills grant XP scaled by enemy strength (bosses far more). Each level = **+1 skill point**.

### 3.2 The Shadow Monarch passive (hidden, 7 stages)

A passive that grows purely with **player level** — no player input, no UI toggle.

```
MONARCH_STAGE_LEVELS = [5, 15, 30, 45, 60, 80, 100]
```

| Stage | Level | Name |
|---|---|---|
| 1/7 | 5 | Stirring |
| 2/7 | 15 | Creeping Dark |
| 3/7 | 30 | Shadowstep |
| 4/7 | 45 | Dread Sovereign |
| 5/7 | 60 | Veiled |
| 6/7 | 80 | Ascendant |
| 7/7 | 100 | Shadow Sovereign |

- `monarch_stage()` counts how many thresholds your level has passed.
- `monarch_intensity()` = `(stage + progress) / 7`, clamped `0–1` — drives the aura and the pallor shader continuously, not in steps.
- `monarch_bonus(key)` folds shadow power **into the normal `get_bonus_total` math**, so it flows through combat with no separate hooks.
- Each stage fires a one-time announce line (`MONARCH_AWAKEN_LINES`, tracked by `monarch_stage_announced`).
- At stage **5/7** the hood + corpse-pale skin swap engages (`HOOD_STAGE = 5`); the 7/7 true form gets its own `monarchidle` animation.

---

## 4. Skill tree

Four classes: **Sword**, **Archer**, **Mage**, and **Shadow Monarch** (locked — visible teaser, all nodes `???`, unlockable only after finishing the game).

### 4.1 Shape

Each class is **one tree that genuinely branches**:

- A **root** trunk (tier 0, +5% to that class's core stat).
- Splits into **3 named specs** (branch 0/1/2), each a spine of **tiers 1–7**.
- At **tier 4** every spec **forks** into a mutually-exclusive **keystone** pair (`exclusive` group). Pick one — the other locks **forever**. This is enforced even in the dev sandbox; the opportunity cost is the point.
- The fork **reconverges** at tier 5 (`prereq` is an Array = "any of these").
- **Tier 7 is an ULTIMATE**: a triggered/conditional mechanic, not a stat bundle.

| Class | Specs |
|---|---|
| Sword | Berserker, Guardian, Warlord |
| Archer | Marksman, Ranger, Warden |
| Mage | Elementalist, Sage, Mystic |

### 4.2 Costs

- Tiers 1–2: skill points only (1 pt).
- Tier 3+: points **and materials**, escalating.
- Typical capstone (tier 7): **6 points + 3 Void Essence + 2 Ancient Relic**.
- Materials must be **researched at the Science Lab** before they can be spent.

### 4.3 Effect keys

**Stats:** `melee_damage`/`melee_cooldown`, `bow_damage`/`bow_cooldown`, `wand_damage`/`wand_cooldown`, `max_health`, `max_mana`, `mana_regen`, `move_speed`, `crit_chance`, `crit_damage`, `damage_reduction`, `status_resistance`, `levitate_range`.

**Mechanics** (read by `player.gd` / `arrow.gd` / `weapon_projectile.gd`):

| Key | Effect |
|---|---|
| `lifesteal` | heal % of melee damage dealt |
| `thorns` | reflect % of damage taken to nearby foes |
| `dodge_chance` | chance to negate a hit outright |
| `execute_threshold` | instakill non-boss below this % HP |
| `execute_heal` | heal this % max HP on execute |
| `low_hp_damage_mult` | bonus damage while under 40% HP |
| `on_kill_rampage` | each kill stacks bonus damage (5s, ×10 max) |
| `undying` | survive one lethal hit per life at 20% HP |
| `multishot` | extra arrows per draw |
| `arrow_pierce` | arrows pass through N enemies |
| `arrow_homing` | arrows steer toward foes |
| `poison_spread` | arrows poison foes near the one hit |
| `on_hit_burn` / `on_hit_poison` | DoT per second applied on hit |
| `on_hit_slow` | chills the target |
| `combustion` | burns leap to nearby foes on hit |
| `mana_shield` | % of a hit paid from Mana |
| `mana_to_damage` | adds `(value × max_mana)` to wand damage multiplier |

### 4.4 Design notes worth preserving

- **Warden (Archer/2)** is the pure elemental-DoT spec: venom → (frost **or** flame) → contagion. Its tier-4 fork is Frost (control) vs Flame (stacking DoT).
- **Sage (Mage/1)** is the only reach-extension path.
- **Mystic (Mage/2)** ends in `mana_to_damage` — wand damage scaling off max Mana (Spellblade `+0.2%/point`, Avatar of Magic `+0.1%/point`).
- The **Reset Potion** refunds all points and clears the class (free re-pick). Spent materials are **not** refunded. It is craftable: `2 Void Essence + 5 Slime`.

---

## 5. Itemization

### 5.1 Categories

`currency`, `material`, `armor`, `relic`, `weapon`, `consumable`, `misc`.

### 5.2 Grades (6-rank rarity ladder)

| Grade | Rank |
|---|---|
| Common | 1 |
| Uncommon | 2 |
| Rare | 3 |
| Epic | 4 |
| Legendary | 5 |
| Mythic | 6 |

Grade drives **two** things: the rarity colour, and a passive bundle.

### 5.3 Grade passives (the "weapons buff everything" rule)

A **wielded weapon** grants a passive stat bundle based on its grade — so a higher-grade weapon makes you universally stronger, not just via its attack. A weapon may override with its own `passive` dict; otherwise it inherits its grade's. Folded in via `get_weapon_passive_total()`. **Materials and currency are ungraded.**

| Grade | Passive bundle |
|---|---|
| Common | +5 HP |
| Uncommon | +10 HP, +2% move |
| Rare | +18 HP, +3% move, +3% melee/bow/wand |
| Epic | +30 HP, +15 mana, +5% move, +5% melee/bow/wand, +5% gold |
| Legendary | +45 HP, +25 mana, +7% move, +8% melee/bow/wand, +8% gold, +8% XP |
| Mythic | +70 HP, +40 mana, +10% move, +12% melee/bow/wand, +10% gold, +10% XP |

### 5.4 Sets

Wearing every armour piece of a set grants its `bonus`. Sets may also define a **`weapon`**: wielding it *while the armour set is complete* stacks a greater `full_bonus` on top — a full class set pays out **both tiers at once**. Some sets have a `bonus_2pc` partial tier.

| Set | Pieces | Weapon synergy |
|---|---|---|
| Leather Set | 3 | — |
| Bulwark of the Warlord | 3 | `wpn_claymore` |
| Windstalker's Garb | 3 | `wpn_recurve` |
| Runeweave Vestments | 3 | `wpn_scepter` |
| Ranger's Leathers | 3 (Rare mid-tier gap-filler) | — |
| Dragonscale Panoply | **5** (helm/chest/pants/gloves/boots, Mythic) | — |

### 5.5 Equipment slots

`ARMOUR_SLOTS = [helmet, chest, pants, gloves, boots]`; `GEAR_SLOTS` adds `weapon`. Relics: **`RELIC_MAX_SLOTS = 6`**.

### 5.6 Crafting

Only these are craftable (`CRAFT_RECIPES`, via `GameState.try_craft`):

| Item | Recipe |
|---|---|
| Stew | 2 Herb + 1 Raw Meat |
| Feast | 3 Raw Meat + 1 Herb |
| Sage food | 3 Herb + 1 Slime |
| Reset Potion | 2 Void Essence + 5 Slime |

**HP/Mana potions are deliberately drop-only** — not craftable.

### 5.7 Materials & research

Materials display as **"Unknown Substance"** until researched at the Science Lab (`get_display_name` gates on `researched_materials`). Unresearched materials cannot be spent. Default stack size `99`.

---

## 6. Enemies

### 6.1 Base enemy

| Property | Value |
|---|---|
| Speed | `100.0` |
| Max health | `60` |
| Detection range | `225.0` |
| Arrow range | `460.0` |
| Jump velocity / cooldown | `-380.0` / `1.2s` |
| Respawn delay | `3.0s` |
| **Growth per respawn** | **`1.085`** (each respawn is 8.5% stronger) |
| Random jump chance | `0.006`/tick |

Weapon types: `sword`, `spear`, `bow`. Bow AI has a retreat range (`90`) and hold range (`180`).

### 6.2 AI texture (the anti-robot details)

- **Hesitation**: every `1.8–4.5s` an enemy pauses `0.35s` — breaks lockstep pursuit.
- **Jump desync**: enemies within `260px` in groups of `3` stagger their jumps by `0.05–0.45s`, so a pack doesn't hop in unison.
- **Wall handling**: turn duration `0.8s`, notice duration `3.5s`, `+120` detection bonus near walls.

### 6.3 Hostile groups

`HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]` — the three families the player's attacks recognise.

---

## 7. Dungeon

### 7.1 Geometry

| Property | Value |
|---|---|
| Width | `2600.0` |
| Ground Y / Ceiling Y | `-39.0` / `-480.0` |
| Entry X | `140.0` |
| Platform height | `20.0` |

100 levels. Regular layouts cycle; **every 5th level is a boss level** with a bespoke arena (`BOSS_ARENAS`).

### 7.2 Scaling (with softcaps)

```
HP    : +15%  per level, softcap at level 20 → +2% per level after
Damage: +10%  per level, softcap at level 30
Speed : +7.5% per level, hard cap at level 25
```

The softcaps are what stop levels 50–100 from becoming arithmetically impossible.

### 7.3 Mines

| Level type | Count |
|---|---|
| Regular | `8–14` |
| Boss | `10–16` |

Safe zone `220px` — never spawned near doorways.

### 7.4 Boss roster

- **Cycling bosses**: `gravewarden`, `frost_monarch`, `cinder_colossus`, `weaver`, `stormcaller`, `void_sovereign`.
- **Finale gauntlet** (reserved, back-to-back):

| Level | Boss |
|---|---|
| 95 | Seraph |
| 98 | Leviathan |
| 99 | Eclipse |
| 100 | **The Fallen Wizard** |

- `COUNTER_IMMUNE_TAIL = 12` — the per-boss weapon-counter system stops applying in the last stretch, so the finale can't be trivialised by counter-picking.

### 7.5 Gates

- **LEFT gate** (blue): always usable. On level 1 it exits the dungeon; deeper it **retreats one level** — an escape hatch that works mid-fight.
- **RIGHT gate**: opens only once the level is cleared. Advancing is **always** a manual step, never automatic.

### 7.6 Drops by depth

| Depth | Material |
|---|---|
| 1–5 | Slime |
| 6–10 | Iron Shard |
| 11–20 | Ember Crystal |
| 21–40 | Void Essence |
| 41+ | Ancient Relic |

Enemies ~25% chance, bosses 100%.

---

## 8. The village

### 8.1 Building state machine

| Property | Value |
|---|---|
| Max health | `400` |
| Build stages | `3` (`TOTAL_BUILD_STAGES`) |
| Output per level | `+25%` per level above 1 (`BUILDING_OUTPUT_PER_LEVEL = 0.25`) |

Buildings have a health/ruin state, a repair requirement (gold + materials), and an upgrade path. `STARTING_BUILDINGS` defines which exist at the start of a real (non-dev) game.

Construction material drops: `wood 35%`, `stone 25%`, `resin 15%` (`CONSTRUCTION_DROP_TABLE`).

**Blacksmith / Forge** unlocks at **dungeon depth 35** (`BLACKSMITH_UNLOCK_DEPTH`).

### 8.2 The role grammar

Every building's roles are defined in `building_roles.gd`. A role entry carries: `title`, `slots`, `required_stat`, `requires_sex`, `requires_kid`, `is_enrollment`, `grants_stat`, `leadership`.

**Three kinds of role:**

1. **Leadership** (the top role of every building) — a unique named post (Chancellor, Harvestmaster, Harbormaster, Forgemaster, Warchief, Principal, Chief Physician, Lead Researcher…). Each requires a `required_stat` **equal to its own title**. These stats are deliberately **absent from `REGULAR_STATS`**, so **School can never graduate a leader** — a leader is *always* a rescued VIP (`VillagerQuests.IMPORTANT_FIGURES`, the boss-level "important NPC" rescues). Code keys off the `leadership` flag, not the title.
2. **Worker** — requires a matching profession stat (Farmer needs `Farm`).
3. **Enrollment** (`is_enrollment`) — taking the slot doesn't assign a worker, it **starts a graduation timer** (`GameState.enroll_villager`). School's *Student* (`requires_kid`, `grants_stat: "random"`); Barracks' *Recruit* (`requires_sex: "Male"`, `grants_stat: "Warrior"`).

Example — Government: Chancellor ×1 (leadership), Party ×10 (open). School: Principal ×2, Teachers ×10, Student ×20.

### 8.3 Professions

```
REGULAR_STATS = [Farm, Hospital, Fishing, Scientist, Financist,
                 Blacksmith, Tavern, Marketplace]
```

Every regular stat has exactly one building whose **worker** role matches it — so every School graduate has a real job to go to.

### 8.4 Economy

Passive income ticks every **`20.0s`** (`INCOME_INTERVAL_SECONDS`).

```
INCOME_ROLES = { Farm: Farmer, Hospital: Doctors, Fishing Dock: Fisherman,
                 Science Lab: Scientist, Bank: Financist,
                 Blacksmith: Blacksmith, Tavern: Barman, Marketplace: Trader }
```

- A worker generates gold equal to their **stat value**.
- Government **Party** members pay a flat `PARTY_MEMBER_INCOME = 1.0`.
- **Bond multiplier**: a villager whose personal quest is complete works at **×1.5** income (`BOND_INCOME_MULT`).
- **Leader bonus**: `+15%` per holder (`LEADER_BONUS_PER_HOLDER`), stacking (School's 2 Principals = +30%). Deliberately **separate multipliers per building**, not one generic bonus:

| Building | Leader bonus |
|---|---|
| Government | village-wide passive income |
| Farm | Farm's own income (on top of village-wide) |
| Hospital | childbirth (gestation) speed |
| School | graduation speed |
| Barracks | recruit training speed |

*Not yet mapped:* couple mating speed, material generation speed.

### 8.5 Villager lifecycle

```
mate → cottage (1h) → gestation (24h) → child born at Hospital
     → School enrollment (24h) → graduates adult with a random REGULAR_STAT → job
```

| Timer | Value |
|---|---|
| Cottage occupancy | `1.0` in-game hour |
| Gestation | `24.0` in-game hours |
| Education | `24.0` in-game hours |

Barracks always grants `Warrior` regardless of input.

### 8.6 Morale

`GameState.village_morale()` drives `village_life.gd`:
- Ambient critters scale with morale (`morale/100 × 7` targets).
- At peak (10/10) a **celebration** fires — an **event**, not a permanent state: `CELEBRATION_DURATION = 20.0s`, tracked on the rising edge (`was_at_peak`).

---

## 9. Defense / siege

| Property | Value |
|---|---|
| First siege | `6.0` in-game hours |
| Siege interval | `12.0` in-game hours |
| Wizard defense value | `4.0` |
| Defense per warrior | `1.0` |
| Wizard respawn | `12.0` in-game hours |

Warriors (Barracks graduates) and the Wizard contribute defense value against scheduled sieges.

---

## 10. Time

| Property | Value |
|---|---|
| Day length | `600.0s` (10 real minutes = 24 in-game hours) |
| Hours per second | `24 / 600` |
| Start time of day | `8.0` (08:00) |

**Critical architecture note:** the master clock is owned by the **`GameState` autoload**, *not* by `main.tscn`'s day/night node. This means time passes in **every** scene — village and dungeon alike. The day/night visual merely *mirrors* `game_hours`. Villager timers (mating, school, pregnancy) and the siege schedule all read the autoload clock, so **nothing freezes when the player teleports into a dungeon**.

Time-skip debug keys (`[` `]` `\`) move the clock, and because everything reads the same clock, they correctly accelerate **and rewind** mating, school, pregnancy and sieges together. `last_tick` measures *in-game* hours elapsed (which can be **negative** on a rewind), not real seconds.

---

## 11. Persistence

- JSON save at `user://savegame.json`.
- Side files: `user://deepest_level.dat`, `user://game_completed.dat`.
- Saved: player stats/inventory/position, difficulty, all villagers, chests, breeding state, enrollments, dungeon unlocks, XP/class/skills, researched materials.
- Saving **inside a dungeon** stores your village return-point instead of your dungeon position.

---

## 12. Dev mode

The game **defaults to the real, honest playthrough**: weak start, no free gold, gated skills, empty village.

All testing conveniences sit behind **`GameState.dev_mode`**, enabled by launching with **`--dev`**. It drives `TEST_UNLOCK_ALL_LEVELS`, `TEST_INSTANT_RESPAWN`, and the village auto-populate (`POPULATE_STAFF_FRACTION = 0.55`, `POPULATE_NAMES`). **God mode** (admin panel, `P`) is one switch granting flight + roam; its invulnerability is deliberately only a short dodge i-frame (`0.6s`), not permanent immortality.

---

## 13. Test & tooling suite

Not gameplay, but part of the machine:

- **`test_*_node.gd`** — headless in-game tests (`test_save_node`, `test_craft_node`, `test_god_node`, `test_monarch_node`, `test_world_node`, `test_workers_node`, `test_ground_node`, `test_hood_node`, `test_lights_node`, `test_audit_node`).
- **`tool_*.gd`** — headless art-QC kit (`tool_art_audit`, `tool_art_sweep`, `tool_fit_check`, `tool_ground_qc`, `tool_void_check`, `tool_crop`, `tool_sheet`, …).

---

## 14. Known gaps in THIS document

I verified everything above directly in source. These areas I documented structurally but did **not** exhaustively enumerate — they'd need another pass:

- **Full weapon/relic/armour stat tables** (`ITEM_DEFS` is ~400 lines; ~70 graded items exist. Individual damage numbers, cooldowns, and the `excellent`-tier unique effects are not listed here).
- **Per-boss mechanics** (`boss.gd` is 1,923 lines — attack patterns, phase/enrage thresholds, the per-boss weapon counters, Mirror Legion / Soul Ward specifics).
- **Special mob behaviours** (`special_mob.gd`, 921 lines — flyer/bomber/charger/spitter/teleporter, the three mage variants, elite modifiers).
- **`village_life` needs/hunger loop** and the exact `village_morale()` formula.
- **Villager quest (bond) definitions** (`villager_quests.gd` — the 4 kinds and the `IMPORTANT_FIGURES` VIP registry).
- **XP curve constants** and the exact per-enemy XP formula.
- **Corruption system** (per `GAME_BIBLE.md` it exists as v1 but is **disabled by a flag**).

Say the word and I'll extend any of these into full tables.
