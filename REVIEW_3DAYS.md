# Deepwood — 3-Day Work Review

_Everything built/changed over the last three days, grouped by system, for the review session. Each item was verified via headless Godot tests (temp runners, deleted after). See GAME_OVERVIEW.md for the full always-current game description._

---

## 1. Dungeon Mode (replaced "Survival Wave Mode")

- **100 discrete levels** instead of an endless wave loop. Enter via the red zone near spawn → press **F** → a **level-select grid (1–100)** opens. Only unlocked levels are clickable; clearing level N permanently unlocks N+1. Fresh saves start with only Level 1.
- **Real teleport**: selecting a level does a scene transition into a **separate, detailed dungeon interior scene** (`dungeon_interior.tscn`) — cave visuals (layered jagged rock walls, stalactites, flickering torches, dark palette), roughly half the overworld width. Your currency/inventory/weapons/health carry over both ways; your village position is restored on exit.
- **Layouts cycle every 5 levels**: 4 distinct platform arrangements by `(level-1)%5`; every **5th level is a boss level** with its own unique arena + red-tinted background. Enemy count/HP/damage/speed scale with level number.
- **Mines**: 8–14 random explosive mines per level (10–16 on boss levels), kept clear of the doorways.
- **Two gates per level** (your latest dungeon request):
  - **Left gate (blue)** — always usable, even mid-fight: on level 1 it **exits to the village**, on deeper levels it **retreats one level** (you re-enter from the right).
  - **Right gate (green when armed / grey when locked)** — only opens once the level is **cleared**. Advancing is now **always manual** (walk through it) — clearing no longer auto-teleports you forward. On level 100 it exits with a completion message.
- **Exit** also via the bottom-right button or the pause menu, anytime.
- **Own dark background music** (re-synthesized to actually be audible — see §9).
- Main-menu high-score changed from "Best Wave" to **"Deepest Level Reached."**

## 2. Skill Tree + XP (new)

- **XP & levels**: enemies grant XP on kill (bosses ~7×). XP bar bottom-left. Each level-up = **+1 skill point** (50 XP for lvl 2, +30 each level after).
- **Press K** to open the tree. First open = **class choice**: **Sword / Archer / Mage** (each its own color), and **Necromancer** shown but **locked until the game is finished** (no ending exists yet).
- **Rendered as an actual tree**: one root card at the top (the trunk) with **connector lines fanning out to 3 branches**, each branch a descending 5-tier chain with lines linking the tiers. This was reworked twice per your feedback — first from 2 options to **3 branches per class**, then from text-columns to a real branching tree shape.
- **Progressive reveal** (per branch): you only see 2 tiers past your deepest unlock; deeper tiers show as "Tier N — ???".
- **Costs**: tiers 1–2 = points only; **tier 3+ also needs materials**, escalating to tier-5 capstones (e.g. Sword "Warlord": +40% melee dmg, +40 HP for 5 pts + Void Essence + Ancient Relic).
- **Materials & research**: drop in the dungeon by depth bracket (L1-5 Slime → L6-10 Iron Shard → L11-20 Ember Crystal → L21-40 Void Essence → L41+ Ancient Relic; 25% per enemy, bosses always). They show as **"Unknown Substance"** until **researched at the Science Lab** (Press E → Research), only then spendable.
- Effects are real (damage, cooldowns, max HP, move speed, gold/XP gain) and stack with gear.
- **Reset Potion** (button in the tree, 150g): refunds all points, clears class (free re-pick). Spent materials aren't refunded.

## 3. Equipment System (new, your latest request)

- **Item categories**: Currency / Material / Weapon / Armor / Relic.
- **Equipment panel via TAB, bottom-left** (opens alongside the inventory): **Helmet / Armor / Pants** slots, a **Weapon** slot, and a separated **Relics** row. Click a filled slot to unequip; click an empty slot to pick a matching item from a chooser popup (shows each item's bonus).
- **Relic slots scale 4 → 5 (Lv10) → 6 (Lv20)**; locked slots show the required level.
- Armor/relic bonuses (HP, move speed, gold/XP) fold into the same math as skills.
- **Excellent weapons** — classless, **no skill-tree scaling**, compensated by unique effects. Equipped in the weapon slot, used on **key 5**. Two examples: **Vampiric Fang** (heal 35% of melee damage dealt) and **Thundercaller** (each hit zaps all enemies within 150px for 12).
- Player currently gets a **temporary starter kit** (one of each armor piece, 2 relics, both Excellent weapons) so the panel is usable now — to be replaced by real dungeon loot later.

## 4. Villagers Get HP (new)

- Every walking villager has **100 HP**. **The player can NOT damage them** (they're off the hittable layer) — damage is reserved for the future village-siege enemies.
- **Health bar behavior**: hidden normally; **flashes into view briefly when hit** so you notice; at **≤30% HP it stays up and pulses red** as a danger warning.
- At 0 HP they **die permanently** (removed from the roster + world, persists through save/load).

## 5. NPC Speech (new)

- When an NPC "talks" (rescue backstory line, or Press-E introduction), the text now appears as **floating outlined text above their head that follows them**, stays long enough to read, then fades — **no window, not the top-right corner**.
- System messages (purchases, level-ups, "level cleared", research) still use the corner notification stack.

## 6. Village Economy Depth (built this window)

- **All 8 profession buildings** now generate passive gold from their workers (not just Farm). Government "Party" pays flat tax.
- **Leader bonuses** (+15%/holder): Government Leader = village income, Farm Leader = farm income, Hospital Leader = childbirth speed, School Principal = graduation speed (×2 = +30%), Barracks Warchief = recruit speed.
- **Every rescued villager now gets a persistent walking avatar** (previously only mating-born children did) — and avatars survive save/reload (a latent bug where none did).

## 7. Narrative (started)

- **Opening prologue** screen shown once on New Game (skipped on Continue).
- **Rescue flavor lines**: each hostage speaks a short backstory when freed (Elin, Milo written).

## 8. Admin/Dev keys (new)

- **T** = admin dash (7× speed) + 10s invincibility. **U** = instant self-kill (for testing death). (Plus the existing `[` `]` `\` time-skip keys.)

## 9. Bug fixes worth noting

- **Dungeon music was silent** — the track was 44100 Hz while the working village track is 22050 Hz; that mismatch (with the importer's compression) killed playback. Re-synthesized the dungeon track in the exact working format with a clear audible dark melody. **Fixed.**
- **Currency-drop crash on arrow death** — dying inside an arrow's physics callback tried to spawn a collider mid-physics-step (illegal). Deferred it. **Fixed.**
- **New Game didn't reset in-memory state** — GameState is an autoload that survives scene changes, so a New Game after a session silently kept old villagers/progress. Added a full reset. **Fixed.**
- **NPC size didn't update on graduation** — a school graduate stayed kid-sized. Now rescales sprite + hitbox to adult. **Fixed.**
- **Building/chest windows didn't auto-close** when walking away. **Fixed.**
- **Version control**: the project is now committed to **git** (a few checkpoints). You asked me to stop auto-committing — recent work (equipment, villager HP, speech tweaks, music fix) is **uncommitted** and ready to commit whenever you say.

---

## Current controls
Move A/D · Jump Space · Dash double-tap A/D · Attack LMB (mouse-aimed) · Weapons 1-4 · **5 = Excellent weapon** · E interact · **Tab = inventory + equipment** · **K = skill tree** · Esc pause · F enter dungeon · (dev: T dash, U kill, `[` `]` `\` time)

## Not built yet (agreed direction)
1. **Village siege/defense** — walls with HP, enemies attacking the village, deploy Warriors to defend, rebuild with materials.
2. **Buildings start visually destroyed** → repair with gold+materials (Builderhouse's real job).
3. **Real dungeon loot drops** (replace the temporary starter gear; weapons/armor/relics as finds).
4. Armor "defense"/damage-reduction stat (currently armor gives HP/speed).
5. Hostage quests (hidden stats), more hostages, rescues inside dungeons.
6. Game ending / final boss → unlocks Necromancer + its real kit.
7. Misc: wand rework (still 1g instant-kill placeholder), How to Play panel is stale, reset potion should become a real item, enemy identity (zombie/vampire/?) undecided.
