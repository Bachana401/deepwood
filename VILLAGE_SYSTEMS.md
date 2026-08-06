# Deepwood — Village Systems & Endgame Design

> ✅ **THE CITY MACHINE IS NOW IN THIS FILE — §12** (added 2026-08-06). Everything built 2026-07-29 → 2026-08-06 — the three placement rules (adjacency / districts / special plots), auras, the level-4 named building powers and their **leader gate**, the automation ladder, the closed population loop (schooling policy + lodging), the **patrols**, **sickness**, **fire** and **the eclipse** — is written up there, at design depth and against the code. The **numbers** live in **[`GAME_MECHANICS.md` §8.7–8.15](GAME_MECHANICS.md)**; the **canon** lives in **[`GAME_BIBLE.md` §4.5, §5.1a, §5.11–§5.16](GAME_BIBLE.md)**. Where any of the three disagree, **the code wins, then the Bible.**
>
> ⚠️ **Sections 1–11 below are the ORIGINAL intent (2026-07-13 → 07-15) and several parts of them have been overtaken by what shipped.** They are kept because the reasoning is still worth reading; where a section is superseded it now says so inline and points at §12.
>
> ⚠️ **SUPERSEDED by [`GAME_BIBLE.md`](GAME_BIBLE.md) (2026-07-15) — where this file disagrees, the Bible wins.** The finale (§8 here) was updated: the Ten hero-hostages resist the Harvest and fight beside the player, and victory ends with the **Shadow Army** reviving all fallen villagers (Bible §8–9). "Necromancer" is renamed **Shadow Monarch** throughout. This file remains as deep-design reference for the village machine.

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

> ⚠️ **Step 1 is SUPERSEDED — see §12.6.** The player no longer walks to a cottage and picks a Male and a Female out of the street. **The roof comes first:** an adult with nowhere to live is given a door, and *moving in* is what makes the couple. There is no separate matchmaking step, and the child's destination (School or Barracks) is now a policy dial, not a per-child decision (§12.5). The *spirit* of this section — manual and tedious first, automated later — is exactly what shipped; the *verbs* changed.

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

> ⏸ **2026-07-13: temporarily DISABLED** (developer call, during testing) via `GameState.CORRUPTION_ENABLED = false` — villager HP floors at 1 (sick but alive), nobody dies or turns. Flip the flag to reactivate.

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

### 8b. The Shadow Monarch — the player's true nature 🔒 (foundation built)

The hero is secretly the **Shadow Monarch**; nobody knows. A **hidden 7-stage passive** (never in the skill tree — it just happens) tied to **character level** (cap 100). Each stage: **bigger shadow aura + paler skin + a stacking shadow power.** The two kings mirror each other — the player Shadow Monarch vs the Wizard's fully-fed **Monarch of Despair** (§8).

| Stage | Lv | Look | Power |
|---|---|---|---|
| 1/7 | 5 | wisps | **Umbral Touch** lifesteal |
| 2/7 | 15 | growing, faint pallor | +shadow damage, dash trail |
| 3/7 | 30 | tendrils, pale | **Shadowstep** (dash i-frames) |
| 4/7 | 45 | tendrils wrap him | **Dread** fear aura (slow/weaken) |
| 5/7 | 60 | so pale the **hood rises** — face hidden, no eyes, only dark under the cowl | 🔥 **Rise, Shade** — kills raise a temporary shade to fight for you |
| 6/7 | 80 | living shadow cloak | 🔥 **The Long Dark** — lethal hit → shadow-form (invuln+heal), not death |
| 7/7 | 100 | **2× size, shadow armor, god** | 🔥 all amplified: permanent shades, 2× lifesteal, shadow nova |

- **Finale reveal 🔒:** 7/7 fully manifests only when the whole village is **dead** (the Harvest, §8) — so **only Orin (Monarch of Despair)** ever sees the true form.
- **Villagers react at 5–6:** deathly-pale hero → afraid / shy / lost / confused / awed mood lines (`npc.gd`).
- **Built (v1, commit `2d5da18`):** stage system + `monarch_bonus()` folded into `get_bonus_total` (Shadow Armor 5/7+, +shadow dmg 2/7+, swiftness 3/7+, 7/7 spike), growing shadow-tendril aura + paling shader, ominous per-stage toasts, villager reactions.
- **Built (v2, commit `28a1726`):** the OP powers — Shadowstep dash i-frames + torn-shadow trail (3/7), 170px dread slow aura (4/7), **Rise-Shade** army (`shade.gd` wraiths, cap 2, 12s — permanent army of 4 at 7/7), **Long-Dark** undying (lethal hit → invulnerable shadow-form, 40% heal, 75s cd), and the **7/7 true form** (1.6× visual scale, aura ×1.7, doubled lifesteal, 5s shadow novas) gated behind `GameState.monarch_true_form()` — no living villager, or the admin P-panel force. Headless suite: `MONARCH_TEST` hook + `test_monarch_node.gd`.
- **Built (v3):** the **hooded hero** (5/7+). Dev's brief: *"5/7 6/7 and 7/7 models to have hoodie and eyes covered — he's becoming so pale that he wants to hide himself, especially his face."* From 5/7 the hero wears a separate hooded skin (`art/hooded/player_*`): hood up, face a lightless void, no eyes. Same coat, same palette, same silhouette height — it's a PixelLab **character state** off the shipped hero (`Monarch Hero v2`), so identity is preserved rather than re-invented. **The base art is never touched**; `player.gd refresh_monarch_skin` swaps the skin folder at the 5/7 line and back down again, and if `art/hooded/` is absent he simply stays bare-headed forever. The existing pallor shader still runs on top, so he keeps paling through 6/7 → 7/7, and the true form still scales him 1.6× hood and all.

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
4. ✅ **Barracks defenders (v1)** — trained warriors spawn as visible Soldier units that sally out and fight raiders during a live siege (commit `9d651ab`; 2-shift day/night patrol + manual wall assignment still to add).
5. **Stat / School / mating pipeline (manual).**
6. **Government automation layer** (turns the manual chores off, scaling).
7. 🔵 Economy depth (Marketplace/Bank/wages), Shrine, then the **Finale**.

Steps **1–2** together are the flagship slice: *a village that starves into monsters if you neglect it.*

> ✅ **All seven slices are built** (as of 2026-08-06) — Hospital/no-regen/paid healing (3), the stat/School/pairing pipeline (5), the management automation layer (6, now spread across the rescued leaders rather than a single Government scaler), and economy depth + Shrine + the Finale (7). The machine then grew a second storey nobody planned for in this list: placement, powers, patrols, and the town's own disasters — **§12**.

---

## 11. Execution guardrails — READ BEFORE CODING

**Build on what already exists — do not rebuild or duplicate:**
- **Morale** lives in `game_state.gd`: `village_morale()`, death-shock, despair + `villager_hp`, high/low-morale rewards, tribute. Hunger, mood, and mating-depression must **extend `villager_needs()` / the morale inputs**, not spawn a parallel morale system.
- **Villagers** are `npc.gd` (avatars) + the `rescued_villagers` roster + `villager_hp`. Hunger/health hook into the **existing per-villager HP + despair** machinery. Transformation reuses `npc.die()` and the existing enemy-spawn path — a demon is a dungeon-type enemy, not a new framework.
- **Buildings** are `building.gd` + roles in `building_roles.gd`; construction stages + operational check already exist (`is_building_operational`). New services attach to these.
- **Existing systems to reuse:** mating/cottages/gestation, School/Barracks enrollment + graduation timers, `village_life.gd` (decor/celebration/cheer), `morale_meter.gd`, `admin_panel.gd`, save/load in `game_state.gd`.
- **The City Machine layer (§12) is also load-bearing now.** Anything that produces a resource must multiply by `building_output_multiplier()` or it silently opts out of the whole placement layer. Anything spatial that has to survive the player going into the dungeon must read the **cached** layout (`building_neighbors` / `building_districts` / `building_plots` / `building_x`), never the live scene tree. Anything that measures distance to a *person* must use `villager_places()` — homes and workplaces — never an NPC avatar, which does not exist while the surface is unloaded. And any new named power must be gated through `has_building_power()` so the leader gate (§12.3) cannot be bypassed by accident.

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

## 12. THE CITY MACHINE — what the village actually became (2026-07-29 → 2026-08-06)

*Sections 1–11 designed a village that must be **kept alive**. What got built on top of it is a village that must be **laid out**, **grown**, **defended outward**, and **rescued from itself** — the settlement half of the game finally having as many verbs as the dungeon half.*

*Everything below is written against the code (`game_state.gd`, plus `assign_ui.gd` for the player-facing controls and `special_plot.gd` for the ground). Where a behaviour depends on a constant, the constant is named rather than its current value written down — this document has been wrong about numbers before, and it will not be again.*

### 12.0 The two standing LAWS 🔒

Everything in §12 is downstream of these. They are the dev's own rules and they are binding, not advisory.

**LAW I — THE AUTOMATION LADDER.** *Every chore the player does by hand early must eventually be taken over by a building or a leader.* The player starts hands-on and deliberately annoyed; by roughly **character level 80** Deepwood should be a nearly self-running city. This is §1's "three stages of every task" promoted from a description into an **acceptance test**: if you add a manual verb, you owe it an heir, and a chore with no successor is a design bug.

The ladder is paced by **rescue depth** — no separate unlock system, because the person who takes a chore off you is a hostage lying at a fixed floor. Pairing → the Bar's Publican at **20**; selling surplus → the Marketplace's Merchant Prince at **25**; wages → the Bank's Treasurer at **35**; schooling → the School's Principal at **45/50**; raising cottages → the Builderhouse's Master Builder at **55**; and the last one, deciding who trains, → the **Chancellor at 95**. The family loop therefore runs itself by the deep 50s.

> The obvious objection — *"then the late game is empty"* — is answered by §12.9: a town that runs itself starts producing **emergencies**, which is a different job, not the same job automated.

**LAW II — THE LEADER GATE.** *A building power requires its leader seated,* or the leader has lost its value (dev, 2026-07-30). This law was written **after** the mistake: as first built, ten of the fifteen level-4 powers did the seated leader's own job — the Standing Order staffed the town *"without a Chancellor"*, the Open Doors schooled children *"no Principal needed"* — so gold spent on an upgrade bought past the rarest content in the game **and** past Law I's entire pacing, which is measured in exactly those rescue depths. Four powers had to be re-scoped into something their leader could never do alone. See §12.3.

### 12.1 Placement — the three rules 🔒 built

The village is a **1-D strip**, so all three rules read off one x coordinate. They are **positive-only** and they **stack**, folding into a single term:

```gdscript
building_output_multiplier(name) =
    1 + (building_level(name) - 1) * BUILDING_OUTPUT_PER_LEVEL
      + adjacency_bonus(name) + district_bonus(name) + plot_bonus(name)
```

**Why positive-only, always.** A penalty layer would retro-fine every town laid down before the rule existed — the player is punished for a decision they were never offered. The same reasoning fixes district boundaries in **absolute** distance from the west gate (`DISTRICT_GATEFRONT_DEPTH` / `DISTRICT_HEART_DEPTH`) instead of as fractions of the row: fractional thirds would redraw themselves every time the town grew eastward and quietly move a building out of the quarter it was paying for.

| Rule | Asks | Strength | Keys |
|---|---|---|---|
| **Adjacency** | *who do you stand beside?* — the immediate left/right neighbour, not a radius | 8 pairs, capped at `ADJACENCY_BONUS_CAP` | `ADJACENCY_PAIRS`, `adjacency_links()` |
| **Districts** | *where on the map do you stand?* — Gatefront (war) / The Heart (civic) / Outskirts (working land) | `DISTRICT_BONUS` | `DISTRICT_HOME`, `district_at()` |
| **Special plots** | *what does the ground itself want?* — 7 exact patches, one building each | `PLOT_BONUS` within `PLOT_RADIUS` — richest, because a plot is one spot and often nowhere convenient | `SPECIAL_PLOTS`, `plot_at()` |

- **The adjacency pairs are the §5.7 Building Web made physical:** Mine↔Blacksmith and Bank↔Marketplace pay most; then Mine↔Builderhouse, Blacksmith↔Barracks, Farm↔Fishing Dock, Science Lab↔School, Bar↔Tavern, Hospital↔Shrine. Physical adjacency counts every building **body** — a ruin between two halls really does separate them — but a synergy only *fires* when both halves are operational.
- **The plots:** The Muster Yard (Barracks) · The Old Market Square (Marketplace) · The Black Soil (Farm) · The Spring (Fishing Dock) · The Quarry Shelf (Builderhouse) · The Ore Vein (Mine) · The Sorrow-Touched Stones (Shrine). Every plot lies **inside the quarter its building already belongs to**, so district and plot can never pull against each other. **Adjacency is the one thing you trade away** — and two "perfect corners" (Farm+Dock, Builderhouse+Mine) are set close enough that a careful player can have plot *and* neighbour, while the Mine's forge pairing and the Shrine's ward pairing stay genuinely impossible to combine with their plots.
- **`refresh_layout()` caches everything** — `building_neighbors`, `building_districts`, `building_plots`, `building_x` — because the surface scene is **unloaded** while the player is in the deep and the away ticks still have to know the row. Buildings cannot move while you are away, so the last known layout stays true. Anything spatial written from here on must read the cache, never the scene tree.

**Three traps this layer paid for in bugs, kept as warnings:**
1. **Fractional banking (`_store_accum`) is load-bearing.** Yields accrue as floats and land as whole units only when they cross 1.0. Without it, one miner hauling 1 stone/day × a 1.20 adjacency bonus rounds straight back to `1` — a well-placed early Mine gained *literally nothing* and the entire synergy layer was invisible until crews got big.
2. **Four of the seven plots were unbuildable** — the live placer rejected the ground — and no amount of arithmetic showed it. Only **probing the placer** did.
3. **All seven plots were invisible** at `z_index = -4`, drawn behind the terrain. Terrain earth sits at z 0 and the grass cap at z 1; anything the player must see goes **above**. A unit test asserted the marker nodes existed and passed the whole time. Only a screenshot found it.

### 12.2 Auras — the first rule that points outward 🔒 built

Placement rules 1–3 all change what a building produces **for itself**. An aura changes life for everything **around** it, so for the first time *where* you build decides *who benefits*. Three buildings carry one, each riding a system that was **already spatial** — no aura was invented to give a building something to do.

| Building | Aura | What it does in range |
|---|---|---|
| **Bar** | *The Sound of It* | `+AURA_BAR_MORALE` to personal morale target |
| **Hospital** | *The Ward's Shadow* | `+AURA_WARD_REGEN` HP/hour to the wounded — and it is the only standing defence against the sickness (§12.9) |
| **Shrine** | *Hallowed Ground* | despair cannot take root in range |

**The design decision that makes auras work: they are measured against homes and workplaces, never wandering bodies** (`villager_places()`, `in_aura()`). A villager's NPC avatar exists only while the surface is loaded and it walks about all day; their **cottage** and their **job** stand still and persist into the deep. So an aura asks *"is this person's home or work inside the circle?"* — stable, saves correctly, keeps working while the player is away, and, the real prize, it makes **cottage placement** part of the puzzle for the first time. A soul with neither home nor job is reached by nothing, which is its own quiet argument for housing them.

### 12.3 Building levels → named powers 🔒 built (and THE LEADER GATE)

Under the dev's law *"stats should not be important at all — transfer their importance to unique behaviour,"* per-level output was cut to `BUILDING_OUTPUT_PER_LEVEL` (it was five times that) and the **reason** to raise a building moved entirely to the **named power** that wakes at `BUILDING_POWER_LEVEL`.

```gdscript
has_building_power(name) := BUILDING_POWERS.has(name)
    and is_building_operational(name)
    and building_level(name) >= BUILDING_POWER_LEVEL
    and building_power_staffed(name)      # LAW II: the leader must be in the chair
```

`building_power_staffed()` requires a seated leader for every building that has a leadership post; the **Shrine** is the single exception, since its Lightkeepers are Hospital-trained keepers rather than a rescued VIP, so the keepers at their posts answer for it.

All fifteen: The Night Forge · The Open Doors · The Standing Order · The Standing Crew · The Standing Watch · The Standing Harvest · The Long Haul · The Deep Seam · The Ward That Never Sleeps · The Matchmaker's Round · The Long Night · The Unbroken Light · The Ledger That Pays · The Caravan Road · The Whisper Network. **Four leaders carry named powers of their own** (`LEADER_POWERS` — the Harvestmaster's *Full Table*, the Harbormaster's *Tide Table*, the Pitmaster's *Sounding*, the Warchief's *Muster*), each deliberately chosen **not** to overlap the building power standing beside it. *A power is that leader's masterwork, not a substitute for them.*

### 12.4 The stores, and who fills them 🔒 built

The town keeps its **own** stockpile (`village_stockpile`: wood, stone, iron_shard), separate from the player's bag — Mine crews and Builderhouse crews fill it daily, the player can hand over what they are carrying at the Builderhouse panel (`donate_to_stores`), and repairs, forged arms and auto-raised cottages spend it. The **Science Lab is the tech rung**: `research_yield_multiplier()` multiplies *every* store yield per seated Lead Researcher, so the Lab finally feeds the machine instead of only identifying loot. A staffed **Bank** banks a share of the tax take into `village_treasury`, and **payday draws from that purse before the player's pocket** — the first rung of the city funding itself. *(Numbers: `GAME_MECHANICS.md` §8.7.)*

### 12.5 Schooling — the one decision nobody can make for you 🔒 built

The hinge the whole population loop turns on, and the clearest single illustration of Law I.

- **By hand, crudely.** At the Government you set `school_share` — a number out of `SCHOOL_SHARE_MAX`. Four means four children in every ten learn a trade and six take a spear; `_kid_intake` walks the block of ten so the ratio is honoured child by child. A blunt instrument on purpose: it is what you have before you have anyone better.
- **Then the Chancellor takes it.** `schooling_is_delegated()` flips the moment that chair is filled and the dial is retired from the UI. `chancellor_wants_warriors()` weighs `village_defense_power()` against `current_siege_tier() × CHANCELLOR_DEFENSE_MARGIN` — so **a siege that costs defenders pulls the next cohort into the drill yard on its own.** Self-balancing, with no dial to tend, and strictly better than the player's guess.
- **It can never strand a child.** `next_schooling_destination()` falls back to whichever hall actually stands, and the Principal's automation sends a child to the *other* hall rather than turning them away when one is full.
- **The bug this closed, worth remembering:** the Barracks' Recruit slot was **Male-only** until 2026-07-30, which capped the warrior corps at roughly half the birth rate and made this entire policy a lie for every daughter born. A dial that silently applies to half the population is worse than no dial.

### 12.6 Lodging — the roof comes first 🔒 built *(supersedes §4 step 1)*

The dev's shape, and it is deliberately not a matchmaking screen:

- A cottage may hold **one** person waiting for someone to share it with (`cottage_homes` entries stay `{a, b}`; a lodger is simply an entry whose other slot is `""`).
- An adult with nowhere to live is given a door — preferably one with a **single of the opposite sex** already behind it, failing that an empty cottage where they wait for company (`house_unpaired_adults`).
- **Moving in is what makes the couple** (`pair_housemates`). There is no separate pairing step. The Publican's round runs the two in that order: house them, *then* match them.
- Guards: a same-sex arrival takes their own cottage; a lone occupant can **never** conceive; children and anyone still in training are not housed as adults; a widow(er) waits out `WIDOW_MOURN_HOURS` first. Occupancy is **for life** — only death frees a cottage.
- Read-out helpers `cottage_occupant_ids()` / `cottage_is_pair()` / `cottage_lone_occupant()` back the door text: *"lives here alone, and would not mind company."*
- The Master Builder raises a new cottage **only when a couple is actually waiting and no home stands empty**, paid out of the village stores — so housing draws on the same Mine→stone→Builderhouse chain as everything else, and the flywheel keeps its brake.

### 12.7 The Patrols — the town reaches into the deep 🔒 built

*The first thing the village does that is not defensive. Until this, a warrior had exactly one job: stand on the wall and wait.*

- **By blocks of ten floors** (`PATROL_BLOCK_SIZE`, `PATROL_BLOCKS`) — ten posts to manage instead of a hundred, matching the Deep Shrine cadence that already existed. A block opens only once **you** have personally swept every floor in it (`block_is_cleared`).
- **The cost is the point.** `village_defense_power()` subtracts the posted warriors **off the top**, before shifts, armoury bonuses or the Warchief. You cannot hold the deep and the gate with the same soldier — and that trade is the entire reason this system exists.
- **Hold it or lose it.** Creep on a swept block rises at `CREEP_BASE_PER_HOUR` + `CREEP_DEPTH_PER_HOUR` per block deeper and is pushed back at `PATROL_SUPPRESS_PER_WARRIOR` per posted warrior. At 1.0 the block **falls** (`_block_falls`): those ten floors are erased from `floors_cleared` — genuinely wild again, for you too — everyone posted there is driven home, and the road down through them is cut. **Waystones still reach a woken shrine beyond a fallen block**, so it isolates rather than strands; the shrine network is what a fallen block makes valuable.
- **What comes home: coin and materials, and depth is the whole point.** `PATROL_COIN_PER_WARRIOR_DAY` and `PATROL_MATS_PER_WARRIOR_DAY`, paid once per in-game day, scaled by `PATROL_DEPTH_BONUS` per block deeper. Dev, 2026-07-30: *"you believe materials and gold are that important… when their village might get crushed?"* Correct — shallow coin never justified taking a soldier off a wall whose loss ends the run, so the deep has to pay.
- **The find is self-balancing with no percentage to tune.** `_patrol_find_gear` draws only from what the floors it holds would have yielded, using the game's own `WeaponRoster.TIER_FLOORS` brackets. Since a stretch can only be patrolled once you swept it, a find is always **behind your own progress**: floors 1–10 send up things you would sell; only a deep watch — which costs many warriors off the wall — turns up anything you would wear.
- **The standing rule:** warriors produce **bulk**, the player produces **meaning**. Never relics, never blueprints, never rescued people.

### 12.8 Fire — the second face of adjacency 🔒 built

Every placement rule up to here was pure upside, which meant the optimal economic layout was also the only sane one and the "puzzle" had exactly one answer. **Fire spreads along the same `building_neighbors` map the synergies read** — so the tight, perfectly-paired row that earns the most is now also the row that burns whole. That is the tension the placement layer was missing, and it is why fire belongs in this document rather than in a hazards appendix.

- Scales with the town: nothing below `FIRE_MIN_BUILDINGS`, then `FIRE_CHANCE_PER_DAY` per standing hall, multiplied by `FIRE_HEARTH_MULT` for the buildings that carry a real flame (`FIRE_HEARTHS` — Blacksmith, Tavern, Bar, Barracks). **One ignition at a time:** a town does not combust at once.
- Burns the hall it is in at `FIRE_DAMAGE_PER_HOUR`, jumps to an **immediate neighbour** at `FIRE_SPREAD_CHANCE_PER_DAY`, and can also simply burn itself out (`FIRE_OUT_CHANCE_PER_DAY`).
- **Fighting it is the Builderhouse's job** — every hand suppresses at `FIRE_CREW_SUPPRESS`, cutting the damage *and* raising the chance it goes out. This finally gives that crew something urgent to do. But a big blaze outruns a small crew, so it is the player's emergency too.
- Unfought, `_fire_guts()` knocks the building **back down its build stages** to be raised again — costly, never unrecoverable.

### 12.9 The Sickness — the town's own problem 🔒 built

*Everything else the village produces, it produces **for** you. This it produces **at** you. It is the answer to "what is there to do once it runs itself" (Law I's own consequence): a grown town does not become quiet, it becomes consequential.*

- **It is not corruption.** §7's demon transformation is a **morale** failure that produces a monster. This is physical, contagious, and it simply kills. They meet only in the death-shock they both feed.
- **It scales with size and tightness.** Below `OUTBREAK_MIN_POP` there is nobody to catch it from; past that, the daily odds climb per soul (`OUTBREAK_CHANCE_PER_DAY` + `OUTBREAK_CHANCE_PER_SOUL`). **The reward for growing is that your town can now hurt.**
- **It spreads house to house**, along the very same homes-and-workplaces the auras read (`_lives_touch`, within `SICK_SPREAD_RADIUS`). Cottages packed in a row pass it along fast; a town spread down the road resists it. Cottage placement gets a **second** meaning, and **where you set the Hospital becomes the most consequential placement in the game.**
- **The ward is the only standing defence:** inside *The Ward's Shadow* the drain is cut (`SICK_WARD_DRAIN_RELIEF`), recovery odds jump (`SICK_WARD_CURE_BONUS`), and neighbours in range catch it far less often. A staffed Hospital helps even at range, at a fraction of the strength. Untreated, `SICK_DRAIN_PER_HOUR` is set to **outrun the passive village mend on purpose**, and `_reap_the_sick()` can finish someone — walking the same death road as every other loss, so the town grieves properly.
- **It cannot be automated away, and that is the design.** A ward dampens it; an outbreak in a big town outruns a ward; and the news **pierces the away-fog** so the player knows to come home. Not a chore — an emergency.
- **Exemptions:** the unbreakable (the Ten) and the pledged shadows, as with every other loss path — a legend sickens to the brink and never past. **Warriors are not exempt**, unlike corruption: plague does not care that you can fight.

### 12.10 The Eclipse — the sky's rarest hour 🔒 built

Not a village system, but it lands *in the village*, so it belongs beside them.

- The moon takes the sun **whole**: the world drops to black silhouette lit by one burning red ring (`eclipse_progress()` — 0 at first contact, 1 at totality, 0 as it lets go). Deliberately a **ring**, not a red filter: the tint goes deep red-*dark* so everything reads as outline lit **by** the eclipse.
- **Never to be confused with the daily dusk crossing** that Nihil's older Duskmoon rite reads (`_sun_moon_both_up`). A true eclipse keeps its own flag, `is_true_eclipse()`.
- **Rare, recurring, never missable:** a flat `ECLIPSE_CHANCE_PER_DAY`, never within `ECLIPSE_COOLDOWN_DAYS` of the last, holding for `ECLIPSE_DURATION_HOURS`. It **always begins at dawn** (`ECLIPSE_START_HOUR`) — rolled at midnight and started on the spot it would be a red night with no sun to take — so the span lands exactly on the daylight: contact at dawn, totality at noon, release at dusk. It is announced **through the away-fog**, because nobody can be asked to be ready for a thing they were never told about.
- **What it gates:** raising the **Hollow Signet** during a true eclipse calls **The Hollow Sun** (`evt_hollowsun`) — the hardest fight in the game, standing outside the ten-boss hunt, and **the only boss fought in your own streets**, so every trick it owns is one your town is standing inside. Because calling it endangers everything you have built, it is **repeatable by design**.
- 🟡 **Open:** nothing currently grants the Hollow Signet — no drop, no recipe, no vendor. Until that exists the fight is unreachable in honest play.

---

*Living document — update as decisions in §9 are made. §12 added 2026-08-06 and verified against the code; §§1–11 remain the original intent, annotated where shipped behaviour overtook them. Original code restore point: commit `2c65fb0`.*
