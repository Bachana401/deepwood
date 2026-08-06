# DEEPWOOD — Mechanics Reference

_What the code actually does. Every number here was read out of the source, not from design docs._

_Base pass 2026-07-17 (HEAD `1d719bd`). **§8.7–8.12 (the City Machine — supply chain, placement, auras, building powers, the automation ladder, the population loop) added 2026-08-03**, read out of `game_state.gd` at HEAD `7869d0b`. **§8.13–8.15 (the patrols, the sickness, fire) and §10.1 (the eclipse) added 2026-08-06**, read out of `game_state.gd` / `assign_ui.gd` / `event_boss.gd` while Mechanics was mid-edit — the constants and behaviour are current; treat only exact numbers as needing a re-check if that session moved them._

_**Correction + expansion pass 2026-08-06 (evening), HEAD `d6c7b9e`.** Corrected where the code had moved out from under the text: **§5.3** (grade passives were retired, not merely re-tuned), **§8.13** (a fallen block does cut the road now), **§8.14** (rewritten — two strains, immunity, and a contact graph that reads homes only), **§10.1** (the Hollow Signet has a recipe), **§14** (corruption is live). Added: **§8.16** condition and mending, the Warchief's watch in §8.13, the sky in §10, **§10.2** The Hollow Sun. Read out of `game_state.gd`, `boss.gd`, `event_boss.gd`, `inventory.gd`, `day_night_cycle.gd` and `level_select_ui.gd`._

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

### 5.3 Grade passives — **RETIRED** (2026-07-30)

A wielded weapon used to grant a passive stat bundle by grade, so a higher-grade weapon made you universally stronger without its attack ever mattering. **That rule is gone.** `GRADE_PASSIVES` still exists and every one of its eight entries — common, uncommon, rare, epic, legendary, mythic, ascended, monarch — is an **empty dict**.

The line it now draws: **weapons do things, armour gives stats.** Armour sets, relics and the skill tree still grant `max_health`, `max_mana`, `move_speed` and the damage multipliers — that is their whole job. A weapon earns its grade entirely through its **verb** (§`WEAPON_VERB_REFERENCE.md`).

`get_weapon_passive()` and `tool_promise_audit` both still read the map, which is why it was emptied rather than deleted: an empty bundle is the honest expression of *"a weapon grants no passive stats"* instead of a special case to guard at every call site. A weapon may still override with its own `passive` dict; almost none do. **Materials and currency remain ungraded.**

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
| Max health | `400` (`BUILDING_MAX_HEALTH`) |
| Build stages | `3` (`TOTAL_BUILD_STAGES`) |
| Output per level | `+5%` per level above 1 (`BUILDING_OUTPUT_PER_LEVEL = 0.05`) |
| Named power at | level `4` (`BUILDING_POWER_LEVEL`) — see §8.10 |
| Condition floor | `CONDITION_FLOOR = 0.35` — see §8.16 |

> The per-level trickle is deliberately **small**. Levels are not bought for the percentage; they are bought for the **named power** that wakes at level 4. See §8.10.

Buildings have a health/ruin state, a repair requirement (gold + materials), and an upgrade path. `STARTING_BUILDINGS` defines which exist at the start of a real (non-dev) game.

**Health and build stage are two separate dictionaries** (`building_health`, `building_stage`), and plenty of paths raise a hall by writing only the stage — restore paths, the build menu, older saves, tests standing a building up to check something else. A standing hall that records **no** health reads as whole, not as a wreck (`building.gd`'s own `_ready` has always applied the same rule).

Construction material drops: `wood 35%`, `stone 25%`, `resin 15%` (`CONSTRUCTION_DROP_TABLE`).

**Blacksmith / Forge** unlocks at **dungeon depth 35** (`BLACKSMITH_UNLOCK_DEPTH`).

### 8.2 The role grammar

Every building's roles are defined in `building_roles.gd`. A role entry carries: `title`, `slots`, `required_stat`, `requires_sex`, `requires_kid`, `is_enrollment`, `grants_stat`, `leadership`.

**Three kinds of role:**

1. **Leadership** (the top role of every building) — a unique named post (Chancellor, Harvestmaster, Harbormaster, Forgemaster, Warchief, Principal, Chief Physician, Lead Researcher…). Each requires a `required_stat` **equal to its own title**. These stats are deliberately **absent from `REGULAR_STATS`**, so **School can never graduate a leader** — a leader is *always* a rescued VIP (`VillagerQuests.IMPORTANT_FIGURES`, the boss-level "important NPC" rescues). Code keys off the `leadership` flag, not the title.
2. **Worker** — requires a matching profession stat (Farmer needs `Farm`).
3. **Enrollment** (`is_enrollment`) — taking the slot doesn't assign a worker, it **starts a graduation timer** (`GameState.enroll_villager`). School's *Student* (`requires_kid`, `grants_stat: "random"`); Barracks' *Recruit* (open to **any** adult, `grants_stat: "Warrior"`).

> **Recruit was Male-only until 2026-07-30.** That quietly capped the warrior corps at roughly half the birth rate and made the Government's schooling policy (§8.12) a lie for every daughter born — "send the children to the Barracks" could never apply to half of them. `requires_sex` still exists as a field; nothing uses it now.

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

**Leader powers** (`LEADER_POWERS`, dev law 2026-07-29). Four leaders were *pure stat* — Harvestmaster `+60%` food, Harbormaster `+60%`, Pitmaster `+50%` ore, Warchief `+15%` training — while every other leader already **did** something (the Chancellor staffs, the Publican pairs, the Master Builder builds). Their flat percentages shrank to connective tissue and each gained a **named behaviour**, deliberately chosen not to overlap the building power sitting alongside it:

| Leader | Power | What it does |
|---|---|---|
| **Harvestmaster** (Farm) | *The Full Table* | works the fields alone — the Farm feeds Deepwood with **no farmhands seated** (`MASTER_ALONE_CREW = 2`) |
| **Harbormaster** (Fishing Dock) | *The Tide Table* | the boats land a sealed crate from deep water roughly every `3` days (`TIDE_TABLE_*`) |
| **Pitmaster** (Mine) | *The Sounding* | the crew cuts ore **matched to the deepest floor you have reached** — iron → resin (15) → ember crystal (35) → void essence (60) |
| **Warchief** (Barracks) | *The Muster* | the horn calls **every able adult** to the wall, not only the trained |

`has_leader_power()` requires the named title seated **and** the building operational. Compare §8.10: a *building* power is that leader's masterwork, never a replacement for them.

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

### 8.7 The supply chain — the village's own stores

*(The City Machine, pillar A. Before this, buildings each produced gold in isolation and repairs were conjured out of nothing.)*

The town keeps its **own** stockpile, separate from the player's bag:

```
village_stockpile = { wood, stone, iron_shard }
```

| Who fills it | What, per day |
|---|---|
| **Mine** crews | `+1` stone and `+1` iron_shard **per miner** (`MINE_VILLAGE_*_PER_MINER`) — *on top of* the player's unchanged personal haul |
| **Builderhouse** workers | `+1` wood per builder (`WOOD_PER_BUILDER_PER_DAY`), plus quarried stone at half the crew size |
| **The player** | `donate_to_stores()` — hand over what you're carrying at the Builderhouse panel |

| Who spends it | What, per unit |
|---|---|
| **Builderhouse** repair crew | `2` wood + `1` stone per repair stage (`REPAIR_STAGE_*`) |
| **Blacksmith** smiths | `1` iron_shard per armory arm (`FORGE_IRON_PER_ARM`) |
| **Builderhouse** auto-cottages | `8` wood + `4` stone per cottage (`AUTO_COTTAGE_*`) |

**Science Lab is the tech rung:** `research_yield_multiplier()` = `+15%` per seated Lead Researcher (`RESEARCH_YIELD_PER_SEAT`), multiplying **every** store yield. The Lab finally feeds the machine instead of only identifying loot.

> **Fractional banking (`_store_accum`).** Yields accrue as floats and only land as whole units when they cross 1.0. Without it every multiplier vanished at small scale — one miner hauling 1 stone/day × a 1.20 adjacency bonus rounds straight back to `1`, so a well-placed early Mine gained *literally nothing* and the whole synergy layer stayed invisible until the crews got big. Now the 0.2 accrues and lands as a whole stone on the fifth day.

**The treasury (the Bank slice).** A staffed Bank banks `TREASURY_TAX_SHARE = 25%` of the tax take into `village_treasury`, and **payday draws from that purse before the player's pocket** (`tick_wages`). A fully-funded payday sets `_bank_paid_full_payroll` — the first rung of the city funding itself.

### 8.8 Placement — where you build matters

The village is a **1-D strip**, so all three placement rules read off a single x coordinate. They are **positive-only** (nothing is ever penalised for standing in the wrong place) and they **stack**, folding into one term:

```gdscript
func building_output_multiplier(name) -> float:
    return (1.0 + (building_level(name) - 1) * BUILDING_OUTPUT_PER_LEVEL
        + adjacency_bonus(name) + district_bonus(name) + plot_bonus(name)) \
        * building_condition(name)
```

The three placement terms **add**; **condition multiplies the sum** (§8.16). Everything before it is investment and layout; the last term is how battered the hall is right now.

`refresh_layout()` caches `building_neighbors`, `building_districts`, `building_plots` and `building_x` — **all four must resolve while the surface scene is unloaded** (the player is in the deep and the town still runs).

**Phase 1 — Adjacency** (`ADJACENCY_PAIRS`, 8 pairs, capped at `ADJACENCY_BONUS_CAP = 0.30`). "Adjacent" means the **immediate left/right neighbour**, not a radius.

| Pair | Bonus | Why |
|---|---|---|
| Mine ↔ Blacksmith | `+20%` | ore goes straight from the seam to the forge |
| Bank ↔ Marketplace | `+20%` | the counting house sits beside the carts |
| Mine ↔ Builderhouse | `+15%` | stone lands at the masons' door |
| Blacksmith ↔ Barracks | `+15%` | arms carried straight to the drill yard |
| Farm ↔ Fishing Dock | `+15%` | one larder, filled from field and water both |
| Science Lab ↔ School | `+15%` | the lab's findings are taught the same day |
| Bar ↔ Tavern | `+15%` | a bed waits directly above the music |
| Hospital ↔ Shrine | `+15%` | healing and mercy keep one threshold |

**Phase 2 — Districts** (`DISTRICT_HOME`, `+DISTRICT_BONUS = 10%` for standing in your own quarter). Measured **east of the west gate**, so the quarters move with the wall:

| Quarter | Range | Home to |
|---|---|---|
| **Gatefront** — the war quarter | gate → `+4500` | Barracks, Blacksmith, Hospital |
| **The Heart** — the civic quarter | `+4500` → `+9500` | Government, Bank, Marketplace, School, Science Lab, Bar, Tavern |
| **Outskirts** — the working land | beyond `+9500` | Farm, Fishing Dock, Mine, Builderhouse, Shrine |

**Phase 3 — Special plots** (`SPECIAL_PLOTS`, 7 of them, `+PLOT_BONUS = 15%` within `PLOT_RADIUS = 260px` of the centre). Richer than a quarter because a plot is **one spot** and often far from anywhere convenient: The Muster Yard (Barracks), The Old Market Square (Marketplace), The Black Soil (Farm), The Spring (Fishing Dock), The Quarry Shelf (Builderhouse), The Ore Vein (Mine), The Sorrow-Touched Stones (Shrine). Painted into the world by `special_plot.gd`.

> **Two lessons paid for in bugs.** (1) Four of the seven plots were **unbuildable** — the live placer rejected the ground — and arithmetic never showed it; only *probing the placer* did. (2) All seven were **invisible** at `z_index = -4`, behind the terrain, and only a screenshot found it. Terrain earth sits at `z 0`, the grass cap at `z 1`; anything the player must see goes **above**.

### 8.9 Auras — the rule that points outward

Phases 1–3 all change what a building produces **for itself**. An aura changes life for everything **around** it — so for the first time, where you build decides *who benefits*.

| Building | Aura | Radius | Effect |
|---|---|---|---|
| **Bar** | *The Sound of It* | `1600` | `+0.8` personal morale target (`AURA_BAR_MORALE`) |
| **Shrine** | *Hallowed Ground* | `1400` | despair cannot take root in range |
| **Hospital** | *The Ward's Shadow* | `1500` | `+2.5` HP/hour for the wounded (`AURA_WARD_REGEN`) |

**Auras are measured against homes and workplaces, never wandering bodies.** A villager's NPC avatar only exists while the surface is loaded and it walks about all day; their **cottage** and their **job** stand still and survive into the deep. So an aura asks *"is this person's home or work inside the circle?"* (`villager_places()`) — stable, saves correctly, keeps working while the player is away, and (the real prize) makes **cottage placement** part of the puzzle. A home built in the Bar's light is a happier home for as long as it stands. Nobody homeless and jobless is reached by any aura — which is its own quiet argument for housing them.

Only three buildings carry one, and each rides a system that was **already spatial**. No aura was invented to give a building something to do.

### 8.10 Building powers — what a level is actually for

At `BUILDING_POWER_LEVEL = 4` every building wakes a **named power** that changes what it *does*. The numeric ladder (§8.1) shrank to `+5%` to make room for this: *"stats should not be important at all — transfer their importance to unique behaviour."*

```gdscript
has_building_power(name) := BUILDING_POWERS.has(name)
    and is_building_operational(name)
    and building_level(name) >= 4
    and building_power_staffed(name)      # <-- the leader must be IN the chair
```

> **⚠ THE LEADER GATE (dev call 2026-07-30: "leader loses its value").** Four powers originally read *"…with no Forgemaster / no Principal / no Chancellor / no Master Builder"* — they **replaced the very person they belonged to**, making the hardest rescues in the game redundant the moment you paid for an upgrade. Now a power **requires its leader seated**, and those four had to be re-scoped into something that leader could never do alone, or level 4 would have bought nothing at all. `building_power_staffed()` reads `seated_leaders() > 0`, except the **Shrine**, whose Lightkeepers are Hospital-trained keepers rather than a rescued VIP — there, the keepers at their posts answer for it.

| Building | Power | What it does |
|---|---|---|
| Blacksmith | The Night Forge | twice the arms a day-shift could turn out |
| School | The Open Doors | no child waits for a seat — intake past every desk |
| Government | The Standing Order | the wrongly-placed are moved to work that fits |
| Builderhouse | The Standing Crew | repairs cost the village stores **nothing** |
| Barracks | The Standing Watch | every warrior holds the wall at full worth, on shift or not |
| Farm | The Standing Harvest | a held-back reserve opens rather than let Deepwood starve |
| Fishing Dock | The Long Haul | a deep catch comes in daily, unbidden |
| Mine | The Deep Seam | ore the shallow workings never reach (`DEEP_SEAM_MATERIALS`) |
| Hospital | The Ward That Never Sleeps | whoever is carried in leaves whole — no trickle |
| Bar | The Matchmaker's Round | matches made unbidden, and a home raised for the waiting couple |
| Tavern | The Long Night | grief burns off twice as fast; morale floors at `25` |
| Shrine | The Unbroken Light | despair can no longer take root in anyone |
| Bank | The Ledger That Pays | payday never touches your purse again |
| Marketplace | The Caravan Road | traders come far more often, and never stop |
| Science Lab | The Whisper Network | every material known on sight, nothing waits to be identified |

### 8.11 The automation ladder 🔒 *(standing law)*

> **Every chore the player does by hand early must eventually be taken over by a building.** The player starts hands-on and deliberately annoyed; by roughly character level 80 the village should run itself.

| Chore | By hand (early) | Taken over by | Unlocked at depth |
|---|---|---|---|
| Pairing a couple | E on a cottage | the Bar's **Publican** (Fenn Merriman) | **20** |
| Selling surplus | hand-sell each stack | the Marketplace's **Merchant Prince** | **25** |
| Paying wages | out of your own purse | the Bank's **Treasurer** | **35** |
| Schooling a child | the assign UI, one at a time | the School's **Principal** (`auto_enroll_children`) | **45 / 50** |
| Raising a cottage | the B build menu | the Builderhouse's **Master Builder** | **55** |
| Deciding who trains | the Government dial | the **Chancellor** | **95** |

The **rescue depths pace the ladder on their own** — no separate unlock system. The family loop runs itself by the deep 50s; the last chore leaves your hands at 95.

### 8.12 The population loop — how the town grows without you

The closed cycle, in order:

```
couple in a cottage → child born → schooling policy routes them
    → School (a trade) or Barracks (a warrior)
    → graduate is given a ROOF → moving in makes the match → child
```

**Schooling policy (§ the hinge).** By hand you write a number out of ten at the Government: `school_share = 4` sends four children in every ten to the School and six to the drill yard (`_kid_intake` walks the block of ten). It is a blunt instrument on purpose — it is what you have before you have anyone better. Once the **Chancellor** is seated, `schooling_is_delegated()` flips and they stop asking you: `chancellor_wants_warriors()` compares `village_defense_power()` against `current_siege_tier() × CHANCELLOR_DEFENSE_MARGIN (1.25)`, so **a siege that costs defenders pulls the next cohort into the yard on its own**. `next_schooling_destination()` falls back to whichever hall actually stands, so a policy can never strand a child nowhere.

**Lodging — the roof comes first.** A cottage may hold **one** person waiting for someone to share it with:

- An adult with nowhere to live takes an **empty** cottage, or one already holding a **single of the opposite sex** (`house_unpaired_adults`).
- **Moving in is what makes the couple** (`pair_housemates`) — there is no separate matchmaking step.
- A same-sex arrival takes their own cottage instead; a lone occupant can **never** conceive; children and villagers still in training are never housed as adults.
- The Publican's round runs `house_unpaired_adults()` **then** `pair_housemates()` — house them, *then* match them.
- Helpers: `cottage_occupant_ids()`, `cottage_is_pair()`, `cottage_lone_occupant()`. A lone occupant reads at the door as *"lives here alone, and would not mind company."*

**Once housed, occupancy is for life** — only death frees a cottage (`cottage_homes`).

### 8.13 The patrols — the town posted into the deep

Warriors are posted **by block of ten floors** (`PATROL_BLOCK_SIZE = 10`, `PATROL_BLOCKS = 10`, so floors 1–100). A block can only be posted once the player has personally cleared **every** floor in it (`block_is_cleared`).

| Property | Value |
|---|---|
| Creep per hour, base | `CREEP_BASE_PER_HOUR = 0.0030` |
| ...plus, per block deeper | `CREEP_DEPTH_PER_HOUR = 0.0011` |
| Pushed back per posted warrior/hour | `PATROL_SUPPRESS_PER_WARRIOR = 0.011` |
| Coin per warrior per day | `PATROL_COIN_PER_WARRIOR_DAY = 3.0` |
| Material per warrior per day | `PATROL_MATS_PER_WARRIOR_DAY = 0.9` (`PATROL_MATS` = stone / iron_shard / wood, one kind picked per payout day) |
| Depth multiplier | `1 + PATROL_DEPTH_BONUS (0.35) × (block − 1)` — block 10 pays **4.15×** block 1 |
| Gear find | `PATROL_FIND_CHANCE_PER_WARRIOR_DAY = 0.012`, rolled per posted warrior per day |

- Earnings settle **once per in-game day** (`_patrol_earnings`, `_patrol_accum`); materials go through the same fractional store banking as everything else (`_add_to_store`).
- **`village_defense_power()` subtracts `posted_warriors()` off the top**, before shift worth, `ARMED_WARRIOR_BONUS`, `WARCHIEF_DEFENSE` or the Muster militia. A posted warrior is worth exactly 0 on the wall.
- At creep `>= 1.0` the block falls (`_block_falls`): every floor in it is erased from `floors_cleared`, the posts are cleared, creep resets to 0. Since `shrine_revealed()` derives from `floors_cleared`, a fallen block also **darkens the Deep Shrine inside it** — shrines *beyond* it stay lit, which is what makes the network the answer to a fallen block.
- **The find is depth-gated, not percentage-tuned** (`_patrol_find_gear`): the pool is every weapon/armor/relic whose grade rank opens at or before `block × PATROL_BLOCK_SIZE` under `WeaponRoster.TIER_FLOORS`, minus `WANDERER_NEVER_SOLD`.
- Player-facing control: `assign_ui.add_patrol_section()` — one row per cleared block, ± buttons, creep shown as a **word** (quiet / restless / stirring / OVERRUN SOON at 0.15 / 0.4 / 0.75), never a number.

- **A fallen block really does cut the road.** `level_select_ui.gd` refuses any descent to a floor below the first hole (`floor_is_road_blocked(level)` → *"The stair ends at floors %d-%d"*), and a woken Waystone shrine is the only thing that reaches past it. `first_fallen_block()` is **derived from `floors_cleared`** — the shallowest block that is *not* swept while something deeper still is — and stores nothing, so it survives a save for free.

> The creep-based version of that check was dead the day it was wired: it looked for a block sitting at creep `1.0`, and `_block_falls` resets that creep to `0.0` in the very next statement. The condition could not survive the instant that creates it, and the test asserting it was asserting a state the game cannot produce.

#### The Warchief posts the watch — the floor-65 automation rung

The manual half of this system has an heir (`_warchief_posts_the_watch`, called at the top of `tick_patrols`). It wakes with **any** Warchief holding a Barracks seat (`warchief_holds_the_deep()` = `count_leader_holders("Barracks", "Warchief") > 0`), which lands at **rescue depth 65** — in the middle of the stretch from floor 56 to 95 where the ladder previously automated nothing new.

- **The minimum, never more.** `garrison_needed(b)` = `ceil((CREEP_BASE_PER_HOUR + CREEP_DEPTH_PER_HOUR × (b − 1)) / PATROL_SUPPRESS_PER_WARRIOR)`, floored at 1 — exactly enough suppression to out-pace that block's creep.
- **Shallowest first.** It walks blocks `1 → PATROL_BLOCKS`. A shallow block is the one whose loss cuts the road; a deep block held beyond a cut road is worth nothing.
- **It never overrides you.** A block already at or above `garrison_needed()` is skipped, so a watch the player set by hand is left exactly as they set it.
- **It never empties the wall.** It posts out of `warriors_available_to_post()` and **returns** the moment that reaches 0, leaving whatever it cannot cover. It relieves the bookkeeping; it does not decide how much to risk.

### 8.14 The sickness — two strains

Physical, contagious, and distinct from corruption (§8.6 / the rot). Ticked from `tick_sickness`, which is **deliberately not gated on `CORRUPTION_ENABLED`** — despair turns people into demons, this is a disease, and the tick used to turn itself off with the corruption kill-switch anyway. No live effect today (the flag is `true`), but the next person to flip it for a test would have silently disabled the plague as well.

One system, two strains. `sick` holds every case; `plague_ids` is the subset carrying the virulent one.

| Property | Value |
|---|---|
| Population floor for any outbreak | `OUTBREAK_MIN_POP = 12` |
| Daily outbreak chance at that floor | `OUTBREAK_CHANCE_PER_DAY = 0.05` |
| ...plus per soul above it | `OUTBREAK_CHANCE_PER_SOUL = 0.0016` |
| Spread reach, **home to home** | `SICK_SPREAD_RADIUS = 900.0` |
| Daily spread chance per touching pair | `SICK_SPREAD_CHANCE_PER_DAY = 0.22` (×`0.4` for a target inside the ward aura) |
| Daily chance from a **shared workplace** alone | `WORKMATE_INFECT_PER_DAY = 0.045` |
| Daily unaided recovery | `SICK_CURE_CHANCE_PER_DAY = 0.10` |
| ...inside the ward aura | `+SICK_WARD_CURE_BONUS = 0.55`; a staffed Hospital at range adds `0.55 × 0.35` |
| Morale drag per ordinary case | `SICK_MORALE_PER_CASE = 0.18` |
| Morale drag per plague case | `PLAGUE_MORALE_PER_CASE = 0.5`, both capped at `SICK_MORALE_CAP = 2.5` |
| Immunity after recovery | `IMMUNITY_DAYS = 90.0` |

**THE ILLNESS — the early strain, and it cannot kill.** It carries **no HP drain at all**. Its entire cost is that a sick body does not mend and that the town's mood sours. At the point in the game where this first appears the player has no staffed Hospital, no doctors and no leader to answer it with, so a strain that took people then would punish being early rather than pose a problem.

- The "does not mend" half is expressed as **regen suppression in two places**, not as a drain tuned to cancel the regen: the hourly passive regen in `tick_morale_effects` and `auto_heal_villagers` on the other clock surface both `continue` on `villager_is_sick(id)`. A fixed cancelling number would let a well-staffed town (doctors multiply regen, the ward aura adds to it) heal straight through the illness while an unstaffed one slowly died of it. Fixing only one of the two healers leaves the disease exactly as toothless, for a subtler reason.

**THE PLAGUE — the late strain, and only it reaps.**

| Property | Value |
|---|---|
| Depth gate | `PLAGUE_MIN_DEPTH = 30` — `plague_is_possible()` is `deepest_level_reached >= 30` |
| Share of outbreaks that turn virulent, once deep | `PLAGUE_SHARE_ONCE_DEEP = 0.35` |
| HP drain | `PLAGUE_DRAIN_PER_HOUR = 0.6` (×`1 − SICK_WARD_DRAIN_RELIEF (0.55)` inside the ward aura) |
| Spread multiplier | `PLAGUE_SPREAD_MULT = 1.7` |
| Unaided cure multiplier | `PLAGUE_CURE_MULT = 0.4` |

- **The strain travels with the carrier.** Catch it off a plague case and you have the plague; catch it off an ordinary case and you have the illness. An outbreak cannot quietly escalate into the late strain, and below `PLAGUE_MIN_DEPTH` the virulent one does not exist at all.
- `_reap_the_sick()` guards on **the strain**, not on the HP alone — so a villager sitting at zero for some other reason (a siege wound, a starving week) is never recorded as a plague death while merely having a cold. An `unbreakable` is floored at `1.0` HP instead of taken.
- Death walks the same road as every other loss: `remove_villager_by_id()` **already** calls `register_villager_deaths(1, death_pos)` itself. Calling it a second time here charged the town two funerals for one body — double morale shock, a doubled log line, and the Grief-Eater armed at two dead instead of three.
- Because only the plague reaps, the toast can name it: *"✝ %s is gone. The plague, not the deep."*

**IMMUNITY — the thing that lets an outbreak end.** Stamped on **recovery**, never on infection (`_grant_immunity`, checked by `villager_is_immune` inside `_can_sicken`), so it is earned by living through it.

Without it the plague was a settlement-ender, and not for the reason you would guess. Balance measured one case into a cared-for town of eighty: **73 of 80 dead**; a staffed Hospital standing on the cottage row still lost 55. Per-case survival was already fine — inside the ward aura a case runs ~543 hours, about 22.6 daily cure rolls, so never being cured is roughly one in a thousand. What killed them was that a cured villager was re-infected the same night by a saturated town and re-rolled until a roll killed them: there was no such thing as *having had it*. Raising the cure alone gets 80 dead to 66.7; immunity alone to 63.5; the two together to **7.8**. Neither lever works without the other.

> **The principle: IMMUNITY MUST OUTLAST THE OUTBREAK.** A typical outbreak in a packed row runs ~36 in-game days, so a 14-day window hands the survivors back as fuel before the thing can starve. Measured at 20 souls on a 100px row, stamping each window once, 10 trials of 1200 days each:
>
> | Window | Outbreaks that ended | Mean | Worst |
> |---|---|---|---|
> | 14 days | **0 / 10** — permanently endemic | — | — |
> | 30 days | 10 / 10 | 79 days | 603 |
> | 60 days | 9 / 10 | 35 days | still running at 1200 |
> | **90 days** | **10 / 10** | 38 days | 52 |
> | 180 days | 10 / 10 | 36 days | 54 — no better than 90 |
>
> 90 is the first reliably clean value and nothing improves past it; the outbreak's own length is the floor. The window barely changes how long an outbreak *lasts* — it decides whether one ever **ends**. Every recovery permanently shrinks the pool the sickness can burn through, so it runs out of fuel and stops. An unprepared town pays a toll, never the settlement.

**THE CONTACT GRAPH — homes only.** `_lives_touch(a, b, r)` compares `_home_x(a)` against `_home_x(b)`; a villager with no roof (`INF`) touches nobody, and a child is measured at its parents' door.

It used to read `villager_places()`, which returns the cottage **and** the workplace — so everyone rostered to the same hall stood at **distance zero** from each other. Balance measured the consequence in a staffed town of eighty: every soul touched all seventy-nine others, and spacing the cottage row twenty-seven times further apart changed the graph by exactly nothing. That falsified three things at once — this system's own claim that a spread-out town resists it, the claim that the Hospital's placement is the most consequential one you make (its aura radius was competing against a graph with no distance in it), and the spatial half of the settlement design generally. Homes-only restores it: **contacts per soul 79.0 → 22.9**, and saturation slows from two in-game days to seven.

A shared bench is kept as a **separate, weaker vector**: `_share_a_workplace()` compares `role_key`, and a pair who share only that infect at `WORKMATE_INFECT_PER_DAY` — about a fifth of the house-to-house rate. Real, but never a zero-distance edge that flattens the map.

**Order and exemptions.**

- The hourly drain runs first, then the **day rolls, then the reaper**. Reaping first meant a villager whose HP crossed zero inside a time chunk was buried without ever being offered the cure roll that same chunk would have given them — worst on the paths that advance the clock in a lump, where the ward's ~65%-a-day recovery never fired at all.
- `_can_sicken()` excludes `unbreakable` (the Ten), `shadow` (the pledged), anyone already sick, and **anyone still immune**. **Warriors are not excluded** — unlike `tick_rot`, which exempts them.
- No avatar positions are involved anywhere, so the whole system runs correctly while the surface is unloaded.
- Both the outbreak and each spread event raise an **urgent** notification, which crosses the away-fog by design, and the two strains are written to read differently: the illness stays domestic (beds, shivering, coming through it), the plague goes institutional (marked doors, counting, burial). The morale panel shows the plague count separately — a town with three colds and a town with three plague cases used to look identical, and the one worth coming home for was the invisible one.

### 8.15 Fire

Spreads along `building_neighbors` — the *same* map §8.8's synergies read, which is the entire point: the tightest, best-paying row is also the most flammable one. Ticked from `tick_fire`.

| Property | Value |
|---|---|
| Standing buildings before anything can ignite | `FIRE_MIN_BUILDINGS = 5` |
| Daily ignition chance per standing hall | `FIRE_CHANCE_PER_DAY = 0.018` |
| ...multiplier for a hearth building | `FIRE_HEARTH_MULT = 3.0` — `FIRE_HEARTHS` = Blacksmith, Tavern, Bar, Barracks |
| Daily jump to an immediate neighbour | `FIRE_SPREAD_CHANCE_PER_DAY = 0.30` |
| Damage | `FIRE_DAMAGE_PER_HOUR = 26.0`, scaled by `1 − suppression` |
| Suppression per Builderhouse hand | `FIRE_CREW_SUPPRESS = 0.22` (workers + seated leaders; damage reduction clamped at 0.9) |
| Daily chance it goes out | `FIRE_OUT_CHANCE_PER_DAY = 0.18` **+ suppression** |

- **At most one new ignition per day**, and only when nothing is already alight — a town does not combust at once.
- `_fire_guts()` (health hits 0): the building drops **one build stage** and its health resets; at stage 0 it is rubble again. `refresh_visual()` is pushed to the live node so it reads as burned in front of you.
- A building that is no longer operational is dropped from `burning` — there is nothing left to burn.
- Surfaced in the morale panel with the crew count, or `NOBODY IS FIGHTING IT`.
- **The hourly burn resyncs the live node.** It writes `building_health` into `GameState`, and for a while it did so without telling the building node — so the health bar never moved and the next hit from anything else wrote the stale value back over the blaze. `_fire_guts` already resynced; the half that runs for *hours* did not.
- What the fire leaves behind is now repairable: a hall that still stands but is badly hurt is mended by the crew (§8.16).

### 8.16 Condition and mending

**A battered hall works badly.** `is_building_operational()` reads the build **stage** and never the health, so until 2026-08-06 a building beaten down to a fraction produced at full rate, taxed normally and counted for the finale gate. Fire could gut a hall and the Hollow Sun could stand on the town smashing it, and the only cost was a cosmetic scar.

```gdscript
func building_condition(name) -> float:
    # a ruin produces nothing anyway; not this term's job
    if not is_building_operational(name): return 1.0
    if hp <= 0.0: return 1.0          # stands but records no health -> whole
    return clampf(CONDITION_FLOOR + (1.0 - CONDITION_FLOOR) * (hp / BUILDING_MAX_HEALTH),
        CONDITION_FLOOR, 1.0)
```

- `CONDITION_FLOOR = 0.35`. A hall at 40% health does roughly 40% of its work **and keeps doing it** — scaled, never a cliff, so this can never soft-lock a save, strand the finale gate behind a building nobody can repair, or turn a bad fight into an unrecoverable one.
- The `hp <= 0.0` clause matters: stage and health are two dictionaries (§8.1), and without matching `building.gd`'s own rule this term read every stage-only building as a wreck and quietly docked a third of the output of a town that had taken no damage at all.

**Mending** (`_auto_mend_one`) is the Builderhouse crew's second job. `auto_repair_one()` looks for the most-ruined *unfinished* building first; when nothing is in ruins it falls through to mending the **lowest-health standing** hall instead.

| Property | Value |
|---|---|
| Health restored per repair pass | `MEND_PER_PASS = 45` |
| Cost per pass | `MEND_WOOD = 1`, `MEND_STONE = 1` from `village_stockpile` |

- Cheaper than a build stage (`REPAIR_STAGE_WOOD` / `REPAIR_STAGE_STONE`) because this is patching, not raising — but deliberately **slow**, so a fight or a fire leaves a mark the player watches heal over the following days.
- The **Master Builder's** power (`has_building_power("Builderhouse")`) scavenges the materials, exactly as it does for a rebuild stage: with it, a mend costs the stores nothing.
- Reaching full health logs *"The builders have made the %s whole again."*; every pass calls `_resync_building_node()` so the health bar moves in front of you.
- **This closed a real hole.** A building only loses a stage when its health reaches zero, and health was only restored by *finishing* that last stage — so a hall knocked to a fraction and left standing had no route back to whole at all. It went unnoticed because nothing used to leave a building alive and hurt: sieges either razed a hall or missed it. Then fire arrived, and then the Hollow Sun, **whose damage is floored precisely so it never destroys anything** (§10.2) — which meant it could never be repaired either. The mercy floor was making its own damage permanent.

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

**The sky the clock drives** (`day_night_cycle.gd`). Sun window 06:00–18:00, moon 18:00–06:00, each widened by `SUN_MOON_OVERLAP_HOURS` around the rise/set point so both share the sky briefly at dawn and dusk — that overlap is what `is_sun_moon_overlap()` reports and what `_sun_moon_both_up()` reads for Nihil's rite (§10.1). Both bodies ride one shared `arc_position(progress, anchor_x)`: horizontal `lerp` across `±ARC_SWING_X = 700.0`, height a sine from `SKY_HORIZON_Y = -430.0` to `SKY_PEAK_Y = -600.0`.

Two fixes on 2026-08-06 are worth recording, because between them **the player had never seen the sun or the moon from their own town, at any hour**:

- **The sky is at infinity — `get_parallax_anchor_x()` now returns the live camera's screen centre.** It used to return `player.global_position.x * PARALLAX_FACTOR (0.12)` while the camera sat at `player.x`, so the sky fell behind by 88% of however far the player had walked: measured at about **3,000 screen px off the left edge at the west gate and 7,250 at the Bar** — six screen-widths. The error scales linearly with x and the village row already runs past 20,000, so **no smaller factor fixes it**; any value below 1.0 leaves a drift that grows without bound. Parallax belongs to the ridgelines, which already have it.
- **The arc came down.** The view top sits near world y `-630`, the mountain peaks top out near `-380`, and the HUD banner covers the top ~233 world px — so anything above about `-590` is behind the banner at screen centre. Noon at the old `-760` was off the frame even at world origin, i.e. the sun was off screen for the middle 70% of every day. `ARC_SWING_X` was widened at the same time: the sun previously crossed only ~270 screen px, which read as a lamp nudging sideways rather than a day passing.

### 10.1 The eclipse

The rare sky event, and the gate on The Hollow Sun (`event_boss.gd`, `evt_hollowsun`). Ticked from `tick_eclipse`.

| Property | Value |
|---|---|
| Chance per day | `ECLIPSE_CHANCE_PER_DAY = 0.03`, rolled once per in-game day |
| Cooldown after one ends | `ECLIPSE_COOLDOWN_DAYS = 7.0` — no roll at all inside it |
| Duration | `ECLIPSE_DURATION_HOURS = 12.0` (~5 real minutes) |
| Start hour | `ECLIPSE_START_HOUR = 6.0` — the roll picks the **day**, `hours_until_time_of_day()` snaps it to dawn |

- Expect roughly one every forty-odd in-game days. Contact at dawn, totality at noon, release at dusk — the 12h span is exactly the daylight.
- `eclipse_progress()` = `sin(t × PI)` over the span: 0 → 1 → 0. `day_night_cycle.gd` is its only consumer, tinting the world red-dark and riding the moon onto the sun.
- `eclipse_is_active()` / `eclipse_is_pending()` / `hours_since_eclipse()` (returns `1e9` when there has never been one, so a fresh or legacy save is free to roll immediately) / `eclipses_seen`.
- **`is_true_eclipse()` is a deliberately separate gate from `_sun_moon_both_up()`.** The latter is the ordinary dusk/dawn crossing that Nihil's Duskmoon Effigy reads and happens twice daily; `summon_event_boss(..., require_eclipse, require_true_eclipse)` keeps them as two independent flags so they can never be conflated.
- Onset raises an **urgent** notification and a Village Log line — it crosses the away-fog on purpose.
- **The pair is pulled down into a visible band while an eclipse runs**, in proportion to `eclipse_progress()`, measured off the live camera (`ECLIPSE_VIEW_MARGIN`, falling back to `ECLIPSE_SKY_Y_FALLBACK` when there is no camera). The eclipse peaks at *noon*, which was the one moment the whole feature exists for and the one moment the ordinary arc put it past the top edge. The everyday sky is left as the dev approved it.
- Persisted as `eclipse_at_hours`, `eclipses_seen` and `eclipse_roll_accum` — the accumulator too, or quitting discarded progress toward the daily roll. `_eclipse_announced` is set from `eclipse_is_active()` **after `game_hours` is restored**, not where the other eclipse fields load: `eclipse_is_active()` reads the clock, and computing it early judged the loaded window against the *outgoing* clock.

**The Hollow Signet** (`Inventory.CRAFT_RECIPES["hollow_signet"]`) — `2× mat_unmade`, `2× mat_crownshard`, `1× mat_sableichor`, `4× void_essence`, `3× ancient_relic`. Costed like the Hunter's Horn because it stands beside it, but out of **deep materials rather than trophies**: the Horn is the reward for knowing every secret, the Signet is the reward for going far enough down. Nothing drops it — the recipe is the only source, and until it existed the whole eclipse chain was a dead end.

### 10.2 The Hollow Sun

The apex event boss the Signet calls (`evt_hollowsun` in `boss.gd`, `EVENTS["hollowsun"]` in `event_boss.gd`), and the only boss in the game fought **in the village**.

| Property | Value |
|---|---|
| Base HP / speed / body | `1700` · `100.0` · `Vector2(200, 290)`, `shape: "titan"`, `apex: true` |
| Abilities | `black_sun`, `meteors`, `pillars`, `beam`, `judgment`, `teleport` |
| Passives | `phase`, `sidestep` |
| Difficulty tier | `"eclipse"` — `hp ×14.0`, `dmg ×2.15`, `floor: 100` |
| Rewards | Ringbreaker, Corona Edge, the Hollow Crown, Eclipsed Plate, Ringlight |

- **Two independent gates.** `summon_event_boss(id, delay, require_eclipse, require_true_eclipse)` keeps them separate flags, and the Signet's `use_effect` sets `true_eclipse: true`. `_sun_moon_both_up()` is the ordinary dusk/dawn crossing that Nihil's Duskmoon Effigy reads and happens **twice a day**; `is_true_eclipse()` is the rare hour. They can never be conflated.
- **It stands outside the ten-boss hunt** (`outside_hunt: true`, read by `hunt_ids()`), so the Hunter's Horn capstone is never gated behind a 3%-a-day sky.
- **Repeatable by design**, because calling it endangers everything the player has built. The `"eclipse"` tier sits **above** the `REMATCH_LADDER` rather than on it — `find()` returned `-1`, and `-1 + ups` landed on index 0, so every *re-summoned* Hollow Sun was staged at `hp ×2.2 / dmg ×1.0` instead of `×14.0 / ×2.15`: the hardest fight in Deepwood came back as the easiest one in it.
- **It breaks the town it is standing in.** `razes_buildings: true` in its `BOSSES` entry is read by `_raze_ground_at(x)`, called from the impact loops of **`pillars` and `meteors`** — its ground attacks only.

| Property | Value |
|---|---|
| Damage per impact | `BOSS_RAZE_DAMAGE = 34` |
| Reach from the impact x | `BOSS_RAZE_RADIUS = 190.0` |
| Floor | `BOSS_RAZE_FLOOR = 0.15` of `BUILDING_MAX_HEALTH` |

- The damage is **deliberately not scaled by `damage_multiplier`**. A floor-100 curve would flatten a hall in a single volley and turn the fight into *watch your town die while you are busy not dying*. The stake is that you cannot ignore the town, not that the town is already gone.
- The floor is applied as `take_damage(mini(BOSS_RAZE_DAMAGE, hp - floor_hp))`, so a building can be brought to the brink and **never destroyed** by this fight. What that costs it in output, and how it gets back to whole, is §8.16 — the mercy floor used to make its own damage permanent.

---

## 11. Persistence

- JSON save at `user://savegame.json`.
- Side files: `user://deepest_level.dat`, `user://game_completed.dat`.
- Saved: player stats/inventory/position, difficulty, all villagers, chests, breeding state, enrollments, dungeon unlocks, XP/class/skills, researched materials, `plague_immune_until`, the eclipse clock (§10.1), and both daily-roll accumulators (`eclipse_roll_accum`, `patrol_accum`).
- Saving **inside a dungeon** stores your village return-point instead of your dungeon position.

> **`DEEPEST_LEVEL_PATH` is sidecarred under `MONARCH_TEST`, exactly like the save.** It was not, and `user://` resolves by project *name* rather than by checkout — so every clone of Deepwood on one machine reads the same file, and this machine's real high-water mark (100) was read into every test process. Since `plague_is_possible()` is `deepest_level_reached >= PLAGUE_MIN_DEPTH`, the entire plague half of §8.14 was permanently **on** for the dev and permanently **off** on a fresh checkout, on CI, or for a second developer. A clean clone does not catch this; only a fresh machine or a wiped `app_userdata` does.

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
- **Corruption system** — v2 and **live** (`CORRUPTION_ENABLED = true` since 2026-07-19). The two fates, the rot window, the infection firewall and the witness waves are canon in `GAME_BIBLE.md` §10; their exact constants are not tabulated here.

Say the word and I'll extend any of these into full tables.
