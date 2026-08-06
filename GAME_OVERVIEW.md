# DEEPWOOD — Full Game Overview

> **Current implementation snapshot (2026-07-20).** This describes the game as it EXISTS IN CODE today — every system below is built and headless-tested. Design truth lives in [`GAME_BIBLE.md`](GAME_BIBLE.md); where this file and the bible disagree, the bible was amended (decisions of 2026-07-20 are marked "delegated" there). Engine: Godot 4.7, GDScript, Windows. PixelLab sprite art for characters/mobs/buildings, procedural fallbacks everywhere.

---

## 1. What the game is

A 2D side-scroller that is TWO games feeding each other: a **dungeon crawler** (100 floors down, bosses every 5th, loot and levels) and a **village life-sim** (rebuild a ruined town, feed and house and employ its people, hold its walls at night). The dungeon funds and staffs the village; the village heals, arms, and researches for the player. The clock never stops for either: while you delve, the village lives — and sometimes dies — on its own, and you come home to read what happened in its diary.

The secret spine: **you are the Shadow Monarch**, sealed and amnesiac. The beloved wizard defending the village is **Orin, the Monarch of Despair**, farming the town's hope for one perfect harvest. The whole game is his trap; winning means growing the perfect village anyway, taking his harvest to the face, and killing the unkillable.

## 2. The story, start to finish

1. **The plea.** A new game opens with one of the taken — lucid enough to beg — pleading with you in the ruins (rumour of a wizard included).
2. **The arrival battle.** The plea flows straight into combat: three adventurers — **Roland, Wren, Castor** — are already fighting a small Despair wave at the west gate. You join; your first fight is in company.
3. **The trap explained.** Wave broken, the trio tells you the truth: they've been stuck for weeks. *"It's not a siege. It's a cage."* Every road out grows an army to meet whoever walks it. The only way out is down.
4. **The failed escape.** Walk west anyway and you're mauled to 20% HP and thrown back (scripted, once). Every LATER attempt spawns a real wave that DOUBLES (4→8→16→24 cap) — clearable, pointless, the arithmetic of the cage.
5. **The Doctor.** Maren Hollis — the town's doctor before it fell — heals you (escalating daily price) and tells the Law of Despair: the strong-willed were dragged below as hostages; the weak-willed *became* the enemy. She also mourns a wizard who went down to save them and never returned.
6. **Orin returns (~floor 15 cleared).** The "lost wizard" walks out whole, introduces himself, and joins the nightly defense with meteors. The pact scene commits everyone to one plan: rebuild Deepwood, free the taken, grow strong. (Every word of his is a lie shaped like your own story.)
7. **The long middle.** Descend, rescue, rebuild. Plants are seeded for the twist: a dying raider bows to the horizon once (~depth 35); Orin says almost plainly he wants the village at its peak (~depth 40); Ilo's unfinished songs; Elenwe's Monarch lore; your own creeping pallor.
8. **The gate of 100** opens only to a PERFECT village (see §10). At the gate: the reveal — the dungeon kneels to Orin, and **THE HARVEST**: every villager you saved turns at once into his army. Only the Ten stand. Wren and Castor walk in the horde, turned; Roland alone arrives at your side.
9. **The fight**: Orin starts weak and EATS the transformed to grow (the Devourer race — every kill of yours denies him fuel). He cannot die — an undivided soul cannot be destroyed — until you fire the **Soul Split Wand** (the "joke item" the Ten gifted you) and strike inside the 4-second mortal window.
10. **Victory**: your seal breaks — memory, throne, true form. First royal act: **SHADOW ARMY** — every fallen villager rises as themselves, continued, in shadow. Deepwood stands, and it is yours.

## 3. The player

- **Classes**: Sword / Archer / Mage, chosen at the skill tree; each class tree is a branching GRAPH with mutually-exclusive keystone forks (pick one path per crossroads, forever), evolving keystones and triggered ultimates. **Shadow Monarch** is a 4th, permanently unlocked class after beating the game (meta-unlock, own save file) — playable from floor 1 of any run.
- **The hidden passive**: the Monarch stirs in stages as you level (5/15/30/45/60/80/100) — shadow effects, and at the deepest stages the hooded, pale look. 7/7 manifests only at the Harvest.
- **Combat**: mouse-directional swings (cursor = direction), per-weapon unique sizes/hitboxes derived from cooldown (bigger = slower), swing after-effects and trails, combo strings with finishers, crit with floating numbers, launched slash projectiles on high grades ("melee you can comfortably use as ranged"), unique weapon abilities that charge on SWINGS (hits and projectile hits trigger them). Sage = channeled beam. Body levitation costs mana for all classes (Mage pays less, has more).
- **No passive HP regen.** Healing is the Doctor (early, escalating price), the Hospital ward (12g flat, staffed), potions (see Potions rule), and lifesteal builds.
- **Gear**: 6-grade ladder (common→mythic) with grade passives (a wielded weapon buffs everything by its grade), 3 class armor sets with 2-tier bonuses, relics, gloves/boots, 30+ special-attack weapons, crafting, gathering tools. Bosses drop level-gated, always-unowned loot. The Forge (Blacksmith, depth 35) vendors up to Rare (Epic with Toren freed) — loot stays king.
- **The Potions rule**: HP/mana potions drop ONLY on the two floors before each boss (richer rates) and from a guaranteed boss cache (2+1). No potion-spam on ordinary floors; you enter every boss stocked.

## 4. The dungeon

- 100 floors; every 5th is a boss (22 unique bosses, each differing in arena, mechanics, behavior profile and signature ability; phase transitions; stagger-guard with honest "GUARDED" labels). Mob variety ramps inside each 5-floor block; elites at 12.5%.
- **Rescues are Sorrow-Crystals**: hostages hang frozen inside a breathing crystal that drains their hope. The crystal's guard must die first; then shatter it (E). Payout: the freed person (stats HIDDEN until they thaw at home — every rescue is a wrapped gift), plus **Sorrowshards** (1; 2 from strong souls).
- Who's down there: 21 named leadership VIPs at fixed floors (the only source of leadership stats), 9 of the 12 adventurers (floors 7–78), and **the Ten** in Trophy Vaults (floors 52–97).
- Floor access is per-run (`highest_unlocked_level`); clearing a floor unlocks the next. The lifetime record only feeds the menu label and the Monarch meta-unlock.
- **The eclipse** is the rarest hour in the sky: a small flat chance per in-game day, never twice inside a week, always opening at dawn so contact/totality/release land on the daylight. The world drops to black silhouette lit by one burning red ring. It is announced through the away-fog, and it is **not** the ordinary twice-daily dusk crossing that Nihil's Duskmoon rite answers to — the two are separate flags on purpose.
- **The Hollow Sun** is what the eclipse is for: raise the crafted **Hollow Signet** during a true one and an apex boss comes down **into your village**. It stands outside the ten-boss hunt, it is repeatable by design because calling it risks everything you built, and its ground attacks damage the buildings it is fighting among — floored so it can wound a hall to the brink but never level one.

## 5. The village — one connected machine

**The Grammar (every building obeys it):** serves a NEED → employs STAFF (daily wages) → runs a SERVICE → unstaffed/unpaid/destroyed, the service STOPS → consequence → morale moves. Everything starts in ruins and is repaired in stages (F key / Builderhouse).

The 15 roster buildings, what each actually does in code:

| Building | Service (live in code) |
|---|---|
| **Government** | The tax engine: with a working, staffed Government, every employed villager at a working building is taxed (bonded villagers at 1.5×, Party members add flat, morale scales the take 0.75–1.25×). Chancellor auto-staffs the town. Without it: the dungeon is your only income. |
| **School** | The role roll: graduates roll a profession from a weighted table (Farm 25/Fishing 20/Tavern 20 common; Smith/Merchant/Miner 8; Doctor 7/Scholar/Banker 6; leadership never). From level 2, the hands-on key sets a FAVOURED calling (weight climbs per level, hard cap 40% — the dice never leave). Principal auto-enrolls kids. |
| **Farm** | Food #1: 6 food/farmer/day; hold-to-hand-harvest early; Harvestmaster & Sylvara multiply. |
| **Fishing Dock** | Food #2, PREMIUM: 4 food/fisher/day, plus fish-on-the-table lifts every villager's spirit +0.3 while staffed and fed; Kaldos adds a daily material per staffed dock. |
| **Hospital** | Health: staffed doctors slow the hunger-withering (÷(1+0.3n)) and speed all recovery (×(1+0.5n)); off-shift warriors heal here; births happen here; hands-on key = player heal for 12g; Chief Physician auto-heals. |
| **Barracks** | Defense: drafts Warriors (one-way, deletes other stats, can't corrupt); the corps splits into DAWN/DUSK 12h watches; armed by `barracks_arms` (Blacksmith). HEROES (0.5% births) train only here and emerge adult, triple-strength, with a personal named power. |
| **Mine** | The delegated pickaxe: each staffed Miner hauls 2 stone + 1 iron shard into your bag daily — the Blacksmith/Builderhouse supply line. |
| **Blacksmith** | Arms the Barracks (deposit gear as arms; Forgemaster auto-supplies) + the depth-35 Forge vendor + village armor-morale (+1.4 to every spirit while it stands). |
| **Builderhouse** | Repairs: a staffed Worker crew rebuilds the most-ruined building on its own at half pace, and when nothing is in ruins it **mends the most battered hall that is still standing** — the only route back to full health after a fire or the Hollow Sun. The crew is also what fights a fire. Master Builder/Foreman run it every tick, and the Master Builder's power scavenges the materials so both jobs cost the stores nothing. |
| **Science Lab** | Research: identifying materials (needed to spend them in the skill tree) requires a staffed Scientist; Lead Researchers auto-research. |
| **Marketplace** | The Wanderer's Post: rotating treasure-sellers whose stay length (6–24h) and markdown (up to −25%) are set by village morale; stock rarity escalates with visits; a staffed Merchant adds a slot and haggles 10% off. Pure gold sink. |
| **Bank** | Interest on your gold (staffed Financist half-rate, Treasurer full, Dorian ×2), payroll efficiency (wages ×0.85), death insurance. |
| **Tavern** | Lodging: the unhoused sleep here (+0.8 spirit vs the street's −1.0); seated hosts lift morale. |
| **Bar** | The morale cushion: +1.0 to every spirit while it stands, drink-sales gold trickle per Barkeep. |
| **Shrine** | Corruption's only mercy (service at depth 30): a put-down demon that was once a villager is cleansed BACK for 3 Sorrowshards by staffed Lightkeepers (Hospital stat). Seraphel: they return steadier. |

**Standalone structures:** two **ramparts** (west gatehouse + east wall past the cottage row — sieges hit BOTH), the **Watchtower** (3 paid tiers: none→1h→2h→24h warning; until tier 1 there is NO siege countdown anywhere), **cottages** (5 + up to 15 raised at the staked plot, 8 wood + 6 stone each), and the **escape ward** at the west world-edge.

**Where you build matters, and a hall's *condition* is part of it.** Output folds adjacency, district and special-plot bonuses into one positive-only term — then multiplies the lot by how battered the building is. A hall at 40% health does about 40% of its work (floored, so a wreck still contributes and nothing can soft-lock the finale gate), and the Builderhouse crew mends it back slowly out of the village stores.

**The town reaches into the deep, and produces its own emergencies:**

- **Patrols.** Sweep all ten floors of a block and you may post warriors to hold it; they send home coin, materials and the occasional find, scaled hard by depth. A posted warrior is worth **zero** on the wall, which is the whole decision. Let a block's creep fill and those ten floors revert to uncleared — **and the road down through them is cut**, reachable only by a woken Waystone. At rescue depth 65 the **Warchief** takes the posting over: minimum garrison per block, shallowest first, never overriding a watch you set by hand and never emptying the wall.
- **Sickness, in two strains.** The early **illness cannot kill** — it stops a body mending and sours the town's mood, and that is its whole cost. The **plague** is gated behind real depth and is the one that reaps: it drains, spreads harder and resists an unaided recovery. Both spread **house to house** (a shared workplace is a separate, much weaker vector), so cottage spacing and the Hospital's position are real decisions. Surviving it grants long **immunity**, which is what lets an outbreak burn through its fuel and end; without it a single case could take a whole town.
- **Fire** spreads along the same neighbour map the placement synergies read — the tightest, best-paying row is also the one that burns whole. The Builderhouse crew fights it; a big blaze outruns a small crew.
- Both emergencies pierce the away-fog. A grown town does not get quiet; it gets consequential.

## 6. The people

- **Personal morale** (the core substrate): every villager carries their own spirit 0–10, drifting hourly toward what their life deserves: alive 1.4 + fed 2.0 + employed 2.2 + housed 1.6 + armed town 1.4 + bar 1.0 + full streets 0.4 = a perfect 10.0. Children weigh home-and-play instead of work-and-marriage. Loneliness is a standing −2; widowhood −3 decaying over 48h of mourning; the street −1. Boons (Ilo's songs +1, seated hosts, dock fish +0.3) are slack on top. **The village meter is nothing but the plain average** — it feeds the HUD, the shop prices, and the finale gate.
- **Housing**: a cottage holds ONE PAIR, for life — the cottage they unite in becomes their home; only death frees it. Housed couples keep conceiving on their own (pauses in famine/despair). Children live under their parents' roof. Population growth is hard-capped by the homes you raise.
- **Lifecycle**: pair → cottage → ~25h → child → School (~24h) → adult with a rolled profession → employ → they want a pair of their own. Rescues arrive with REAL professions (the only guaranteed rare/leadership source).
- **Wages**: every employed villager draws 1.5g/day from your purse (Bank staffed: ×0.85). An empty purse means workers QUIT on the spot, named in the Log.
- **Corruption (ENABLED — the Law of Despair, mechanical)**: TWO fates. An empty larder KILLS (starvation, the only HP-death left; Seraphel halves the withering). A spirit at ZERO opens the ROT — a grey pulsing window (6h; 3h for children) in which fixing their life REDEEMS them; if it closes they turn into a demon loose inside the walls. A turning infects neighbours by THEIR state: the already-low are dragged under, the strained pushed, the well-kept RESIST — healthy villagers are the firewall. Death-shock spreads from the body as a diminishing wave (−1.5 close, halving outward, children ×1.5, stacks). Loose demons trickle-sap hope; a fallen rampart is a −0.5 omen. Warriors never corrupt — they die in battle.
- **The Village Log (press L, anywhere)**: the town's diary — births, deaths, rescues, quits, sieges and their outcomes, buildings rising, spirits failing/mending, cleansings — timestamped, filterable, in plain words. It's how you catch up after every delve.
- **The 12 adventurers**: 3 starters + 9 rescued in the dungeon, each with a NAMED signature ability. Station them at the **wall** (1.5 defense, split across both ramparts), in the **city** (1.0), or safe in a **house** (0). They fight live sieges beside soldiers and heroes. **PERMADEATH — they never re-enlist**; in away-sieges they die IN PLACE of villagers (the shield), and the Log names them.

## 7. Defense — the nightly war

- Sieges scale with prosperity × depth (a living village insults Despair) and hit from **both flanks at once** — you can stand at one gate; the other rests on what you posted there.
- **Live** (you're home): raiders spawn at both standoffs, soldiers of the ON-DUTY watch sally (half of them if the horn catches the shift change ±1h of 6:00/18:00), heroes sally on top at triple strength, adventurers fight from their stations, Orin drops meteors (after his arrival). Wall holds = non-event, repaired after. Wall breaks = the horde is in the streets, omen on every spirit, deaths make death-shock waves.
- **Away** (you're delving): the siege auto-resolves as defense-power vs tier — warriors (on-duty full, off-duty half), heroes ×3, armed bonus, stationed adventurers, Orin. Shortfall kills adventurers first (the shield), then Maera saves one, then villagers die. Everything lands in the Log; the game never yanks you home.
- **Foresight is earned**: no Watchtower = no countdown, anywhere ("The night keeps its own counsel"). Tier 1 shows the clock + 1h bell; tier 3 gives a full day.
- After victory over Orin, **sieges end forever** — the raiders were his apparatus.

## 8. Economy — the loops

- **Gold in**: dungeon loot (primary, always), Government taxes (needs the working staffed Government), Bank interest, Bar trickle. Nothing else prints money.
- **Gold out**: wages daily, repairs, the Doctor/ward, the Forge, the Wanderer's Post, cottages/Watchtower materials (bought with gathered mats, not gold — but the Mine staff costs wages).
- **Materials**: wood/stone/resin (gathering + Mine), iron/ember (mining + Mine + Kaldos), skill materials (dungeon only, Lab-identified), Sorrowshards (crystals only — the Shrine's reagent).
- **The flywheel**: rescue → house → employ → tax → wages → services → morale → cheaper Post prices, stronger defense, faster everything → deeper dives → more rescues. The anti-flywheel is corruption: neglect anywhere and the town eats itself.

## 9. The Ten (floors 52–97)

Ten legends Orin could never break, kept as trophies in gilded vaults past the fighting. Each freed one joins the village as an unbreakable Legend AND supercharges one chain: Brannoc (wall ×1.5 + barracks grads ×2), Maera (doctor decay ×0.5 + one siege save), Toren (craft costs ×0.75 + Forge sells Epic), Sylvara (farm ×2), Kaldos (dock materials), Dorian (interest ×2), Mirielle (leader terms ×2), Seraphel (withering ×0.5, death-shock decay ×2, cleansed return steadier), Elenwe (all research), Ilo (+1 every spirit). The 10th freeing gifts the **Soul Split Wand** — a 0-damage "joke" that splits ordinary enemies into 7 harmless ghosts... and is the only thing that can make Orin mortal. At the Harvest they fight beside you and CANNOT die (beaten down, they fall back and return).

## 10. The finale gate & the Chronicle

Floor 100 opens only to: every building repaired (Mine and Shrine included), every base role slot staffed, morale 100 (= every single villager at 10), all Ten freed. The door lists what's missing. **The Chronicle** (pause menu) is the 100% ledger — seven deeds with live tallies: every named soul home (21 figures + 12 adventurers), every bond honored, the Ten, the full skill graph (one path per crossroads), the village at its peak, Despair destroyed, the Shadow Army raised. Closing the book is a one-shot celebration.

## 11. Post-game & NG+

- **The Shadow Court**: sieges are over; shadow villagers work their old jobs; the Ten live on; the Shadow Monarch class is yours in any future run; remaining bonds completable.
- **THE REWOUND HOUR**: among the victory spoils, a mythic hourglass. Use it twice within 5 seconds and the world rewinds for a fresh run — village in ruins, Ten caged, Orin a rumour — but YOU are immune: level, class, skills, research, gear, everything carried. Cycles are counted; a new hourglass drops only if the last was spent.

## 12. Meta

- **Saves**: one JSON save (additive format, never rewritten); lifetime records (deepest floor, game-completed) in separate files so they survive New Game. New Game rewinds EVERYTHING per-run (enforced by a standing audit).
- **Dev mode**: launch with `--dev` for the sandbox (full hotbar, admin wand, gates bypassed, skill sandbox). Honest mode is the default.
- **Verification**: 16+ headless suites + 6 standing audits (promises, gaps, wiring, save round-trip, new-game reset, weapon geometry) — all must report 0/PASS; every change is clean-clone verified (the committed tree, not the working tree).

## 13. Deliberately open (the short list)

Mood & mating-depression needs ("later" by design), the siege-tier curve and global numbers pass, targeted re-education + pity floor, shadow-villager special mechanics, the true ending that breaks the NG+ cycle, per-legend ally kits, §12.2 wand-quest placement.
