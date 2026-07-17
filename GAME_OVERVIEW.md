# DEEPWOOD — Full Game Overview

> ⚠️ **Point-in-time implementation snapshot (2026-07-11) — STALE in places.** For design truth read [`GAME_BIBLE.md`](GAME_BIBLE.md) (2026-07-15); for current code state verify against the live code. Known-stale here: buildings-start-destroyed and siege/defense ARE built; itemization/loot IS built; "Necromancer" is now the **Shadow Monarch**; the enemy identity IS settled (undead/deepwood).

_A complete text description of the game as it exists right now. Written 2026-07-11 to hand to another AI assistant (or anyone) with zero prior context. Engine: Godot 4.7, GDScript, all visuals procedural (no image assets — polygons/rects only), Windows. Project root: `C:\Users\bacho\Documents\deepwood`. Not a git repo. Developer is a solo hobbyist who iterates conversationally; every change is expected to be verified via headless Godot test runs (`Godot.exe --headless --path . res://_test_runner.tscn` pattern, temp files deleted after) — see PROJECT_SNAPSHOT.md §7 for the exact methodology._

## Premise

A lone adventurer arrives at Deepwood — a once-thriving village, now nearly empty. The same evil that destroyed half of mankind raided it and took almost everyone hostage, leaving captives "neither alive nor dead." The adventurer has hunted this enemy for years and finally traced it here. The plan: raid the dungeon where the evil nests, rescue every villager, rebuild the village, destroy the threat at its root. (Enemy identity — zombie/vampire/other — is deliberately still undecided; don't assume one.)

## Core Loop

**Dungeon crawl → gather loot/XP/materials & rescue villagers → return to village → spend (repair, assign, breed, upgrade skills) → re-enter dungeon deeper → repeat.**

## The Village (main.tscn — the overworld)

A long side-scrolling 2D map: combat course on the left (10 patrol enemies with sword/spear/bow AI, explosive traps, elevated platforms), village on the right (x≈4900+).

- **12 buildings** (procedurally drawn): Government, School, Farm, Hospital, Barracks, Fishing Dock, Science Lab, Bank, Blacksmith, Tavern, Marketplace, Builderhouse. Press E at any building → role-assignment window.
- **Roles & slots**: each building has titled roles with slot limits (e.g. Farm: Leader ×1, Farmer ×10). Worker roles require a matching villager stat (Farmer needs "Farm" stat). Leadership roles (Leader/Principal/Warchief) can NEVER be learned in school — only rescued hostages who already carry that exact stat qualify.
- **Economy**: assigned workers at the 8 profession buildings generate passive gold every 20s equal to their stat value. Government "Party" members pay flat tax. **Leader bonuses** (+15%/holder): Government Leader = village-wide income, Farm Leader = farm income, Hospital Leader = faster childbirth, School Principal = faster graduation (×2 slots stack to +30%), Barracks Warchief = faster recruit training.
- **School**: enroll kids → 24 in-game hours → graduate as adults with a RANDOM profession stat (Farm/Hospital/Fishing/Scientist/Financist/Blacksmith/Tavern/Marketplace). **Barracks**: kids or adult males → always graduate as Warrior (for the future defense system).
- **Breeding**: 5 cottages. Pair an unpaired male + female → 1 in-game hour in the cottage (cottage then frees up) → 24 in-game hours gestation → child born at the Hospital as a walking kid NPC. Time-skip debug keys correctly accelerate/rewind all of this.
- **Villager NPCs**: every rescued/born villager has a persistent walking avatar. Hover shows name/age/sex/stat/job tooltip; Press E shows same info. Employed villagers wander only near their workplace and periodically go inside (0-5×/24h, 30-60 in-game min). Avatars survive save/reload.
- **Hostages**: 2 placed so far (Elin the farmer, Milo the fisherman), frozen/pulsing until rescued via Press E, with backstory flavor lines. Rescue registers them permanently.
- **Chests** (2): persistent storage. Drag-and-drop items between inventory/chest, right-click-hold to split stacks 1-by-1. Inventory (Tab) is 15 slots, left-anchored; chest UI right-anchored so both fit onscreen.
- **Day/night cycle**: 10 real minutes = 24h. Moving sun (rays, glow, highlight) and moon (5 phases, phase-accurate craters, additive glow) with parallax; night darkening; clock HUD; `[` `]` `\` debug time keys (+1h/-1h/+24h).
- **Shop** near spawn: Dash 30g, Double Jump 20g, Spear 40g, Bow 35g, Magic Wand 1g (placeholder instant-kill-all — needs rework). Single-click buy, denied-purchase sound.

## The Dungeon (dungeon_interior.tscn — separate scene)

Entered via the red zone near spawn: Press F → level select grid (1-100). Only unlocked levels clickable — clearing level N permanently unlocks N+1; fresh saves start with only Level 1. Selecting a level **teleports** (real scene transition) into the dungeon interior; currency/inventory/weapons/health carry over both ways, and your village position is restored on exit.

- **Structure**: 100 levels. Each is ~half the overworld width, cave-styled: layered jagged rock walls, stalactites, flickering torches, dark palette, its own tense drone music. Enemy count/HP/damage/speed scale with level number.
- **Layouts**: 4 distinct platform arrangements cycling by `(level-1)%5`; every 5th level is a BOSS level with its own unique arena layout and a red-tinted background. Boss = slam/charge/barrage attacker, enrages at 50%.
- **Mines**: 8-14 random explosive mines per level (10-16 on boss levels), never near the doorways.
- **Two gates**: LEFT gate (blue) always usable — on level 1 it exits the dungeon, deeper it retreats one level (escape hatch, works mid-fight). RIGHT gate (green when armed, grey when locked) — only opens once the level is cleared; advancing is ALWAYS this manual step, never automatic. On level 100 it exits with a completion message.
- **Drops**: enemies 25% / bosses 100% chance to drop a skill material by depth bracket: L1-5 Slime, L6-10 Iron Shard, L11-20 Ember Crystal, L21-40 Void Essence, L41+ Ancient Relic.
- Exit Dungeon button (bottom-right) and pause-menu exit also work anytime.

## XP & Skill Tree

- Kills grant XP (scaled by enemy strength; bosses ~7×). XP bar bottom-left. Each level-up = +1 skill point. Curve: 50 XP for level 2, +30 per level after.
- **Press K** → skill tree. First open = class choice: **Sword** (red, melee damage/HP), **Archer** (green, bow/mobility/gold), **Mage** (purple, wand cooldown/XP/utility), **Necromancer** (visible but LOCKED until the game is finished — no ending exists yet).
- 9 nodes per class in 5 tiers with prereq chains. **Progressive reveal**: only 2 tiers past your deepest unlock are visible; deeper shows "???".
- Tiers 1-2 cost points only. **Tier 3+ also costs materials**, escalating to tier-5 capstones (e.g. Warlord: +40% melee dmg +40 HP for 5pts + 2 Void Essence + 1 Ancient Relic).
- **Research**: materials show as "Unknown Substance" until researched at the Science Lab (Press E → Research section). Only researched materials are spendable.
- Effects are real: damage %, cooldowns, max HP, move speed, gold/XP gain all live in combat.
- **Reset Potion** (150g button in the tree UI): refunds ALL points, clears class (free re-pick). Spent materials not refunded.

## Player & Combat

A/D move, Space jump (double jump purchasable), double-tap dash (purchasable), mouse-aimed omnidirectional attacks (LMB), weapons 1-4, E interact, Tab inventory, K skill tree, Esc pause. Death: drop 77% of gold at death spot (recoverable pickup), 7s countdown, respawn; Medium difficulty also loses a random villager, Hard additionally a skill material (difficulty picked once at New Game). Admin/dev keys: T = 7× dash + 10s invincibility, U = instant self-kill, time keys above.

## Persistence

JSON save (`user://savegame.json`): player stats/inventory/position, difficulty, all villagers, chests, breeding state, enrollments, dungeon unlocks, XP/class/skills/researched materials. Save via pause menu. New Game fully resets; Continue restores everything including villager avatars. Saving inside a dungeon stores your village return-point instead.

## NOT built yet (agreed direction)

1. **Village siege/defense**: walls with HP on both sides, enemies attack the village, deploy up to 10 trained Warriors to defend, rebuild walls with materials.
2. **Buildings start visually DESTROYED** and non-functional until repaired with gold+materials (Builderhouse's real job).
3. **Dungeon loot**: weapons/armor/relics/potions as real items (loot > shop; skill tree stays the "upper edge").
4. Hostage quests (hidden stats revealed via quests) + many more hostages; rescues should eventually happen INSIDE dungeons per the loop.
5. Game ending/final boss (holds 10 special hostages) → unlocks Necromancer.
6. Smaller: wand rework (placeholder 1g instant-kill), How to Play panel stale, reset potion should become a real item, mating-speed & material-generation leader bonuses unmapped, enemy identity undecided, no multiplayer ever (explicit non-goal).
