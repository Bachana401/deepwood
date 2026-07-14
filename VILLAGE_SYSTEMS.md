# Deepwood — Village Systems & Endgame Design

> **Purpose.** The master plan for Deepwood's living-village: the survival needs, the
> morale-driven building machine, the corruption mechanic, and the finale. This is a
> shared reference — a design bible for the developer **and** an execution guardrail so
> that when we build, we extend the right systems and don't touch unrelated ones.
>
> **Status legend:** 🔒 Locked (developer decided) · 🟡 Proposed (needs a decision) · 🔵 Later phase (agreed, not first).
>
> Sibling docs: `GAME_OVERVIEW.md`, `PROJECT_SNAPSHOT.md`, `ROADMAP.md`. This doc does **not** duplicate them; it is the deep design for the village/morale/corruption/finale arc.

---

## 0. The one-line vision

**The village lives. Neglect breeds monsters. The final evil is the despair you allowed.**

Every system below serves that sentence. The whole game is the story of building something you can lose — and, in the end, of it being turned against you.

---

## 1. The Grammar — how every building works 🔒

One reusable pattern. If every building obeys it, the village reads as one interdependent machine.

> A building serves a **NEED** → it employs **STAFF** (who cost daily wages) → skilled staff need
> **KNOWLEDGE** (taught at School) → the building runs an automatic **SERVICE** → if it is destroyed,
> unstaffed, or unpaid, the service **STOPS** → that triggers a **CONSEQUENCE** → which moves **MORALE**.

### The three stages of every task (manual → automated) 🔒
1. **Do-it-yourself** (early / building ruined or unstaffed): the player physically performs the task.
2. **Delegated** (built + partly staffed): workers handle routine; player fills gaps; slower.
3. **Automated** (built + fully staffed + upgraded + wages paid): hands-off.

The tension that keeps it a game: **automation costs daily wages.** Can't pay → workers quit → back to manual.

### Two layers of automation 🔒
- **Building-level automation:** staffing a building runs *its own* service (farmers farm, nurses heal, builders repair). **Buildings do NOT all automate the same way** — some need inputs from other buildings, some are self-contained.
- **Management-level automation (Government):** automates the *player's chores* — routing kids to school, then to jobs; assigning wall shifts; collecting taxes. The **Government** is a mid→late-game building whose level **scales global automation up by a significant %**. Early game the player does the managing by hand.

---

## 2. Villager needs (per-NPC meters) — applies to ALL village NPCs except the Wizard 🔒

| Need | Filled by | Empty consequence | Phase |
|---|---|---|---|
| **Hunger** 🔒 | Farm / Fishing Dock (visible food) | mood text → morale drop → **death in ~2–3 days** | **First** |
| **Health** 🔒 | Hospital (nurses) | wounds/illness persist; can kill | Second |
| **Wages** 🔒 (the player's meter) | player income; deducted manually early | unpaid → workers quit → services stop | With economy |
| **Mood** 🔵 | Bar / fun in the village | low mood if no bar/entertainment | Later |
| **Mating-depression** 🔵 | pairing (cottages) | too many long-single villagers → depression | Later |

**Explicitly NOT in scope yet:** generic "no-work depression." (Statless/jobless depression is separate — see §3.)

### Hunger loop (first build) 🔒
- Farm/Dock produce **visible food** in the world.
- Villagers walk over, **pick up food, eat** (hunger refills), the food **despawns**, and regrows/restocks on a timer.
- Starving too long → mood lines → morale falls → **death after ~2–3 in-game days**.

### Healing, potions & regen 🔒
- **No HP regeneration for anyone** — villagers *or* player — **except** via a relic/item (relics grant HP and/or regen).
- After a siege, warriors sit at low HP and **do not recover** on their own — they must be healed at/by the Hospital.
- **Potions:** HP and mana potions drop **only from the wave(s) immediately before a boss, and from boss fights** — nowhere else — so the player enters every boss fully stocked. No other potion source (prevents potion-spam trivializing normal floors).
- **In the village, the Hospital is the only healer.** **Nurses roam like builders**, leaving the Hospital to heal injured villagers **from range** as part of its service. The **player heals at the Hospital for a solid gold cost** — a deliberate money sink (replaces the earlier free self-heal idea).

---

## 3. Villager stats & professions 🔒

- Every NPC carries **0–5 profession stats**. Rarity at rescue: **1 = common, 2 = rare, 3–4 = very rare, 5 = extremely rare.**
- **Statless NPCs** (adult or kid) can be sent to **School** or **Barracks**.
  - **School** grants a stat (skill), unlocking employment in that stat's field.
  - **Barracks** grants **warrior knowledge**, which **deletes all existing stats** and makes them a **warrior for life, until death.** (One-way — burning a rare multi-stat NPC into a soldier is a real sacrifice.)
- **How many stats a villager needs:** **1 is the bar.** A villager with **≥ 1 stat** can be employed **and** is safe from stat-depression. Extra stats are pure bonus.
  - **0 stats (statless)** = the problem: can't work, and slowly becomes **depressed** → must gain a stat (School) or become a Warrior (Barracks).
  - **2nd & 3rd stats = optional versatility** — they let one villager work several building types. Never required; a convenience for the player who wants a jack-of-all-trades.
- **Retraining at School for extra stats** (only NPCs with **< 3** stats), each *additional* stat is random and costs progressively more time:
  - 1st stat: **1×** base time
  - 2nd stat: **5×** base time
  - 3rd stat: **10×** base time
  - **Hard cap: 3 stats via School.** (Naturally-rescued 4–5-stat NPCs are rare elite finds you can't manufacture.)
- **Stat → job mapping (approved):** one profession per building — see the table in §9a. A villager works a building only if they hold its profession stat.

---

## 4. The lifecycle pipeline: mate → child → school → job 🔒

**Manual (early — deliberately tedious):**
1. Player goes to a **cottage**, picks a **Male + Female**, pairs them.
2. **~25 in-game hours** later, a **kid** is born.
3. Player returns, goes to **School**, and enrolls the kid.
4. **~24 in-game hours** later, the kid **graduates as an adult** with a knowledge stat.
5. Player walks to the relevant **building** and employs them (E/F). *(Now imagine doing this for every child.)*

**Automated (Government):** kids **route themselves to School**, and on graduation **go straight to a job** — the adult leaves School and starts working with **no player input**.

> This chain is the flagship example of "manual is annoying → automation is the reward."

---

## 5. Defense: Barracks shifts 🔒

- Barracks runs **two shifts — day and night — that swap**, so the off-shift can **sleep and heal in the village's safety for 12h** (healing via nurses, since there's no passive regen). A relief after brutal sieges where you just need to survive the wave.
- **Manual early:** the player **assigns wall defenders by hand**. Skip it → **empty walls → breach.**
- **Automated later:** **Government** (jobs/defense control) auto-assigns shifts.
- Note: a shift-change landing mid-siege, and scarier **night sieges** (darkness + day-shift asleep), are intentional tension hooks tied to the day/night cycle.

---

## 6. Building roster — the machine

Each entry: **what it serves → the chore you do by hand → what automates it → its signature visual → what breaks if it falls → what it depends on.**

### Enabler
- **School** 🔒 — *Serves:* skilled workforce. *Manual:* villagers stay unskilled. *Auto:* teachers train stats/professions (see §3–4). *Visual:* a class, graduation. *Breaks:* skilled workers die out and can't be replaced — the whole automation web unravels. *The keystone.*

### Survival
- **Farm** 🔒 — food #1. *Manual:* harvest & hand-feed. *Auto:* farmers grow it, villagers self-serve. *Breaks:* starvation.
- **Fishing Dock** 🔒 — food #2 + resilience/variety. *Manual:* rod-fish. *Auto:* fishers stock it. *Breaks:* no backup if the Farm burns; variety morale lost.
- **Hospital** 🔒 — health + births. *Manual:* potions / (🟡 rest). *Auto:* roaming nurses heal; doctors deliver babies. *Breaks:* wounds/illness kill; no new births.

### Protection
- **Barracks** 🔒 — defense (see §5). *Auto:* trained soldiers patrol/repel routine raids. *Breaks:* every siege is on the player; losses spike.
- **Blacksmith** 🔒 — arms & tools. *Manual:* craft/buy one at a time. *Auto:* smiths forge armor (defense + the existing "armor" morale factor) and tools (workers faster). *Breaks:* weak defense, slow workers.

### Infrastructure
- **Builderhouse** 🔒 — repair/construction. *Manual:* hold-hammer each broken wall/building (slow). *Auto:* builders roam and auto-fix after sieges. *Breaks:* rebuild everything by hand.
- **Science Lab** 🔒 — research/upgrades. *Manual:* spend materials by hand (existing skill-tree research). *Auto:* scholars research passively; unlocks upgrades that improve **every other building**. *Breaks:* no progression.

### Economy
- **Marketplace** 🔒 — trade. *Manual:* sell loot/surplus by hand. *Auto:* merchants auto-sell; traders bring gold. *Breaks:* production can't become gold → can't pay wages.
- **Bank** 🔒 — treasury. *Auto:* safe storage, interest, holds the payroll. *Breaks:* no interest; gold vulnerable. (Wages themselves are **manual tax deduction** early — see §1/§7.)
- **Government** 🔒 — the management brain (see §1, two-layer automation). *Auto:* taxes, wage policy, village-wide orders, and the **global automation scaler** that grows toward late game.

### Spirit
- **Tavern (inn)** 🔒 — food, rest, and **lodging**. Rescued/new villagers **arrive here and stay until given a cottage** (starter/overflow housing — seed of a later housing need). *Auto:* innkeeper/cook serve meals & beds. *Breaks:* newcomers have nowhere to be.
- **Bar** 🔒 — drink, music, fun → morale (the existing `bar_morale` buff). *Auto:* barkeep keeps spirits up. *Breaks:* mood sags, despair comes faster.
- **Shrine / Chapel** 🔒 — *redemption.* Lets the player **capture & cleanse a transformed demon back into a living villager**. **Unlocks only at dungeon level 30** (mid-game). Makes despair not always a death sentence and gives the spirit side a hard purpose.

---

## 7. Corruption — the demon transformation 🔒 (concept locked; details 🟡)

**Lore:** the source of the evil is depression / deep negative emotion. A villager in terror — no food, no home, no fun — whose **morale hits 0** turns **demonic**, the same kind of enemy as in the dungeon, and **attacks the village from the inside** (villagers, buildings, the player).

**Rules 🔒**
- Transformation happens **only at morale 0**.
- **Domino by proximity:** witnessing a nearby transformation costs a villager **−2 morale** (e.g., a 5 → 3). So a healthy town shrugs off one loss; a broadly miserable town is a **powder keg** that chains.

**Built — v1 (commit `e9359a9`) ✅**
- Neglect (empty larder or rock-bottom morale) drains a villager's HP past a grace window; at 0 they **turn demonic** instead of dying — a reskinned `siege_enemy` spawns at their avatar (wall nulled) and hunts the town from within. Purged from the roster; toast on each turning.
- **Telegraph/grace = the existing HP-drain + grey "rot" visual.** Fixing food/morale reverses the drain → **redemption** (nobody turns).
- **Domino (v1) = town-wide dread:** each turning adds `CORRUPTION_MORALE_SHOCK`, so a miserable village chains. Away in the dungeon, a lost villager is simply removed (no demon).

**Still to refine 🟡**
- **Proximity domino:** the true "−2 to *nearby* witnesses" (currently a town-wide morale shock instead).
- **Richer telegraph:** shaking/darkening/whispering distinct from the generic starving tint.
- **Redemption via the Shrine** (§6) once it exists.
- **Demon flavour:** distinct look/behaviour vs. a normal besieger (currently just a red tint).

> **This answers "who are the enemies?"** — they are *fallen humans*. The dungeon and the village share one villain: **untended despair.**

---

## 8. The Finale — "The Harvest" 🔒

**The twist:** the Wizard is the true evil but appears only at the end, with real storytelling. The reveal: **he planned all of it.** He *made* the adventurer build an immense, thriving village so that at the climax he could **force its morale to 0 with his magic** and turn the whole town against you. You are attacked by the very village you spent the game building.

**The gate 🔒** — **Level 100 stays LOCKED** until the player has:
- built **100% of all buildings**, **and**
- **fully employed everyone** in every slot, **and**
- reached **10/10 morale**.

Only a maxed, perfect village opens the final floor. (The gate is *why* the harvest is total — he needs the peak to reap it.)

**The turn 🔒** — Wizard mini-dialogue → the **entire village transforms** — **everyone**, including your own soldiers (no survivors, no loyal holdouts) — into strong, level-100-tier demons that attack you. You face your whole town **alone**.
- **Population estimate:** ~55% staffing ≈ 84 villagers in test, so full staffing ≈ **~150**, and with extra unemployed + children you bred, realistically **~150–200+**. Exact count computed from building role-slots at build time.
- **Performance 🔒:** never spawn 150+ actors at once — **stream them as waves**. You *feel* the whole town turning; the engine stays smooth.

**The Wizard as a Devourer 🔒** — his fully-fed final form is named the **Monarch of Despair**. He starts **weak** (nerfed personal attacks); his power is **earned by eating the horde**:
- Every **5% of the population he consumes = +1 power tier** (bigger size, more HP, more damage). ~20 tiers possible; uncapped in feel → a slow fight makes him a titan.
- **It's a race with agency:** every transformed villager **you** kill is one he **can't** eat — so clearing the mob fast both saves you *and* **starves his growth**. Turtle → he balloons; rush → you deny fuel but leave the horde on your back.
- **Fuel model 🔒:** he devours the *living* transformed over time — **your kills deny him fuel**, so killing fast keeps him weak (pure player agency). *(Alt considered and rejected: kills also feed him.)*
- **Balance guardrail:** tune so a strong player downs him at ~30–50% absorbed; a slow one faces a monster — but it stays **winnable**.
- **Theme:** the bigger the village you built, the bigger the monster it can become. You built your own final boss.

**Foreshadowing 🟡** — plant seeds so it feels planned: suspiciously generous tribute/rewards, cryptic dungeon notes, a taunt that the Wizard *wants* you to grow.

**Endgame — New Game+ 🔒** — on victory the player finds **time-reversal loot**. **The player and their loot are immune to the rewind** — the world resets but you keep yourself and all your gear. You replay, now able to choose the **Necromancer** (the hidden "???" class already in `skill_tree.gd`). Clean prestige loop; power carries over. *(Finer aftergame detail — e.g. a "true ending" that breaks the cycle — TBD later.)*

### 8a. Signature item — Soul Split Wand 🔒 (a joke that turns clutch)

A quest-reward novelty weapon that is *deliberately useless* almost everywhere, then becomes the answer to the one fight it was made for.

- **Effect:** fires a bolt; whatever it hits **splits into 7 mini-clones** (~0.38× scale — "proportional to full size"), scattered with a spin, that **snap back together after 4 seconds.** Single-target on hit (not a crowd splash — avoids 7×N clones lagging the game).
- **Visual method 🔒:** `duplicate()` the target's procedural node tree ×7, scale + scatter + spin, tween back, restore the original. Works uniformly because every enemy/boss is a plain `ColorRect`/`Polygon2D` tree (no baked textures/rigs). *(Not jigsaw shards — mini-clones read fine on blocky mobs and are far cheaper.)*
- **Targets:** regular **enemies & mobs** — and, where cheap, *anything* splittable (props/loot for fun); no-op on things that can't. **Not** normal bosses.
- **Damage rule 🔒:** while split, the target is **invulnerable — never damageable.** On every normal mob the wand is **purely visual**: they disco-split and reassemble unharmed. Useless on purpose.
- **The sole exception — the Monarch of Despair (final boss):** its 7 fragments **are** damageable, so the split opens a **4-second burst window.** This is the *only* time the wand matters in combat — the "joke item" you hoarded becomes clutch when the boss is too big to handle head-on.
- **Cost:** 20-second cooldown, ~15 mana (novelty-cheap).
- **Status:** design locked; not yet built. Not in the current build order — slot it whenever (it's self-contained and touches only the weapon/`special` system + a split VFX helper).

---

## 9. Decisions — RESOLVED

1. ✅ **Tavern & Bar split** (Tavern = inn/food/rest, Bar = drink/morale/fun). §6
2. ✅ **Shrine added**, unlocks at **dungeon level 30**. §6
3. ✅ **Healing:** boss-gated potions + paid Hospital healing + relic regen. §2
4. ✅ **Finale:** gate (100% built + fully employed + 10/10 morale) → full transform → **Devourer** boss. §8
5. ✅ **Endgame:** time-reversal loot NG+ (player + loot immune) → Necromancer. §8
6. ✅ **Devourer fuel model:** he devours the *living* transformed — **your kills deny him fuel** (agency: killing fast keeps him weak). §8
7. ✅ **Profession list** (§9a) — approved as written.
8. ✅ **Stat requirement:** 1 stat = employable + no depression; 2nd/3rd stats optional versatility (never required). §3

*(All design decisions locked. Nothing left open before execution.)*

## 9a. Profession list 🔒

One skilled profession per building; School grants these, each unlocks its building's work. Barracks' **Warrior** is special (deletes all other stats, permanent).

| Profession | Works at |
|---|---|
| Farmer | Farm |
| Fisher | Fishing Dock |
| Doctor / Nurse | Hospital |
| Smith | Blacksmith |
| Builder | Builderhouse |
| Scholar | Science Lab |
| Merchant | Marketplace |
| Banker | Bank |
| Official | Government |
| Teacher | School |
| Innkeeper | Tavern |
| Barkeep | Bar |
| **Warrior** | Barracks *(deletes other stats, permanent)* |

---

## 10. Build order (vertical slices)

1. ✅ **Hunger loop** — visible food, eating, starvation, morale hooks (commits `d1e4c6c`/`3fc887d`/`e44604e`). *(Proves the grammar.)*
2. ✅ **Morale → transformation (v1)** — the demon turn + town-wide domino + rot telegraph (commit `e9359a9`; proximity domino + shrine redemption still to refine). *(The keystone; makes hunger matter and is the killer demo moment.)*
3. **Hospital + no-regen + roaming nurses + paid player healing + boss-gated potions.**
4. **Barracks shifts + manual wall defense.**
5. **Stat / School / mating pipeline (manual).**
6. **Government automation layer** (turns the manual chores off, scaling).
7. 🔵 Economy depth (Marketplace/Bank/wages), Shrine, then the **Finale**.

Steps **1–2** together are the flagship slice: *a village that starves into monsters if you neglect it.*

---

## 11. Execution guardrails — READ BEFORE CODING

**Build on what already exists — do not rebuild or duplicate:**
- **Morale** lives in `game_state.gd`: `village_morale()`, death-shock, despair + `villager_hp`, high/low-morale rewards, tribute. Hunger, mood, and mating-depression must **extend `villager_needs()` / the morale inputs**, not spawn a parallel morale system.
- **Villagers** are `npc.gd` (avatars) + the `rescued_villagers` roster + `villager_hp`. Hunger/health hook into the **existing per-villager HP + despair** machinery. Transformation reuses `npc.die()` and the existing enemy-spawn path — a demon is a dungeon-type enemy, not a new framework.
- **Buildings** are `building.gd` + roles in `building_roles.gd`; construction stages + operational check already exist (`is_building_operational`). New services attach to these.
- **Existing systems to reuse:** mating/cottages/gestation, School/Barracks enrollment + graduation timers, `village_life.gd` (decor/celebration/cheer), `morale_meter.gd`, `admin_panel.gd`, save/load in `game_state.gd`.

**Do NOT touch unless the task explicitly says so:**
- Dungeon combat balance and the L100 boss curves (see the endgame-balance notes).
- The working **save format** — extend it additively and carefully (new keys with defaults), never rewrite it.
- Admin/test flags (`TEST_*`) and the admin panel wiring, except to add new test buttons.
- Existing player/villager **art** — back up originals before replacing (import-cache lesson learned).

**Every change:**
- Headless-verify the specific behavior before calling it done.
- Delete temp test files and don't leave `_*.gd/_*.tscn` scaffolding.
- Commit a checkpoint at each good stopping point.

---

*Living document — update as decisions in §9 are made. Current code restore point: commit `2c65fb0`.*
