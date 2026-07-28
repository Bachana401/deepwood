# DEEPWOOD — Complete Game Overview

> *"You're searching for Deepwood? Look around you. You're standing in it."*

**Genre:** 2D side-view action-RPG × colony-sim × 100-floor dungeon crawler × Terraria-style mining, with a slow-burn story that reframes everything you've done.
**Engine:** Godot 4.7 (GDScript). **Player:** a nameless Calamity Orphan — secretly the reincarnate soulmate of a Shadow Monarch.
**The pitch:** Descend a 100-floor dungeon to free your taken people, rebuild the ruined village of Deepwood into the brightest place in a broken world, defend it from sieges — then learn that a *perfect* village was exactly what your enemy was farming all along.

---

## 1. THE PREMISE

Deepwood was the village the whole dying world whispered about — scholars, builders, forges, full tables. When the calamity took everything else, Deepwood **held for years**. Then the waves grew *wrong*: the Despair Army dragged the **strong-willed alive** down into the deep and **turned the weak-willed** into monsters — so the horde at your gate wears your own neighbours' faces.

By the time you arrive, Deepwood is a **ruin**. The one true enemy is the **Monarch of Despair** — "the end of the living." The raiders were never random; they are his **farming apparatus**, and *the apparatus dies with the farmer*. Every road out of the village is a **cage** ("every road out, the horde grows to meet you") — the only escape is **down**, through the root of it.

**The secret** (sealed until the very end): the choking that took you at Deepwood's treeline in the prologue was not a first meeting. A Shadow Monarch's soul found you years ago, too weak to merge, and has followed you ever since — your improbable survivals "were never luck." Arriving home, the bond finally *completes*.

**The Oath** the four heroes swear together:
> *"Free the taken, raise the walls — and when Deepwood stands, I go down after the thing that did this. It lives again, or none of us leave."*

Winning means **bringing the people home** — not just killing things.

---

## 2. THE CORE LOOP

**Descend → rescue people + recover blueprints + gather materials → return, rebuild, staff, defend → descend deeper.**

- The **dungeon** (west pit) is where you fight, free hostages, and find blueprints/loot.
- The **underground** (a minable Terraria world) is the connective cave you dig and explore, holding scattered doors into every floor.
- The **village** is a full colony sim you rebuild, staff, and defend against escalating sieges.
- The master clock lives in the autoload, so **time advances in every scene** — sieges, births, wages, and school all tick while you're deep.

---

## 3. THE PLAYER

- **Movement:** run speed 200, jump −400, gravity 900. **Fall damage** past a 300px drop (0.15/px); a 2500px void-fall snaps you back (anti-fall-through net).
- **Purchased mobility:** **Double Jump** (20g), **Dash** (30g — double-tap A/D, speed 900, 0.5s cooldown, afterimages). **Flight/Levitation** (hold Space) is available to *every* class but drains **mana** (16/s, Mage discount); the Aetherwing relic grants it with wings. A **blink-dash (T)** with 0.6s i-frames comes from the Shadowstep Sigil.
- **Base stats:** 160 HP, 90 mana (regen 4/s), 5% crit / +50% crit damage. Caps: damage reduction 75%, mana shield 80%, status resistance 90%, cooldown reduction 70%.
- **The hidden Monarch passive (all classes, whole game):** 7 stages tied to character level — **5 / 15 / 30 / 45 / 60 / 80 / 100** (*Stirring → Creeping Dark → Shadowstep → Dread Sovereign → Veiled → Ascendant → Shadow Sovereign*). Stacking +all-damage, damage reduction, and move speed; **7/7 is the 2× "god-form."** Your true nature emerges as you climb — visibly manifesting only when no villager is left to witness it (the Harvest).

---

## 4. CLASSES & SKILL TREES

**Four classes**, each a branching tree with **3 spec spines** (tiers 1–7). Every spec **forks at tier 4** into a mutually-exclusive **KEYSTONE pair** (pick one, the other locks *forever*), reconverges at tier 5, and ends in a **tier-7 ULTIMATE**. You pick your class on first opening the tree (K); it's permanent unless you drink a **Reset Potion**. **Shadow Monarch is locked until you beat the game.**

Skill points: **+1 per level-up**; costs rise with tier (up to 6 for ultimates); deep nodes also spend **researched crafting materials** (slime → iron_shard → ember_crystal → void_essence → ancient_relic).

### ⚔ Sword — Berserker / Guardian / Warlord
- **Berserker** → *Bloodthirst* (lifesteal) → **Sanguine Pact** vs **Blood Rage** (+40% dmg under 40% HP) → **Avatar of Slaughter** (kills stack +dmg/lifesteal/HP).
- **Guardian** → *Spiked Armor* (thorns) → **Aegis Wall** vs **Riposte** (dodge) → **Living Fortress** (survive one lethal hit/life).
- **Warlord** → *Deathblow* → **Executioner** (instakill non-boss <15% HP) vs **Overpower** → **Headhunter** → **Godslayer**.

### 🏹 Archer — Marksman / Ranger / Warden
- **Marksman** → *Deadeye* → **Piercing Shot** vs **Killshot** (instakill non-boss <18% HP) → **Skyfall**.
- **Ranger** → *Twin Shot* (+arrow) → **Seeker Arrows** (homing) vs **Evasion** → **Tempest** (4 homing arrows).
- **Warden** (pure DoT) → *Venom Arrows* → **Frost Arrows** vs **Flame Arrows** → **Contagion** (poison spreads).

### 🔮 Mage — Elementalist / Sage / Mystic
- **Elementalist** → *Ignite* → **Overcharge** vs **Wildfire** (burns leap) → **Cataclysm**.
- **Sage** → *Mana Flow* → **Overflow** vs **Focusing Lens** (a hold-to-channel **beam** that ramps) → **Transcendence**.
- **Mystic** → *Mana Barrier* (pay 40% of hits from mana) vs **Blink Step** → **Spellblade** (wand dmg scales with max mana) → **Avatar of Magic**.
  - **Side-roads:** **Riftweaving** (Z — twin portals, drains mana while both open) and **Telepathy** (your mind reaches the village from anywhere — beats the "village fog").

### 👑 Shadow Monarch — Legion / Dominion / Ascendant *(post-game unlock)*
Root: slain foes rise as **shades**, +8% all damage.
- **Legion** → **Standing Army** (shades never fade) vs **Volatile Dead** → **Deathless Legion**.
- **Dominion** → **Sovereign's Dread** (fear aura) → **Deadly Presence** (passive nova) → **Absolute Dominion**.
- **Ascendant** → *Feast of Shadows* (lifesteal) → **Immortal Sovereign** vs **Wrath Incarnate** → **Sovereign of the Dead** (assume the TRUE FORM at will).

---

## 5. WEAPONS & TOOLS

**Base kit** (hotbar 1–0): **Sword** (start), **Spear** (40g), **Bow** (35g). Weapons carry a **grade** (Common→Mythic) that grants a passive bundle while wielded (Mythic = +70 HP, +40 mana, +10% speed, +12% dmg, +10% gold/XP).

**"Excellent" classless weapons** (unique effects, dungeon-drop only) — a sampler:
- **Vampiric Fang** (35% melee lifesteal) · **Frostmourne** (40% lifesteal + frost slow) · **Thundercaller** (chain-zap) · **Midas Edge** (hits mint gold) · **Ragnarok Blade** (every 8th strike = slash-nova + meteors + shockwave) · **Doombringer** (execute <18% HP, +50% vs bosses) · **Singularity Edge** (every 5th strike opens a black hole) · **Worldsplitter / Earthshaker Maul** (shockwaves) · **Dawnbreaker** (piercing sun-slash + heal) · **Tempest / Stormfury Bow** (homing arrows) · **Gungnir** (5 piercing spears) · **Leviathan Hook**, **Galewing Glaive** (boomerang), **Chrono Edge** (CD-reset chance), **Wizardsbane** (+150% vs bosses), **Voidcaller**, **Shadowblade**, **Echo Rift**, **Soulthirst**.

**Tools:** **Woodsman's Axe** (Wood/Resin) and three **tiered Pickaxes** that gate the deep biomes — **Miner's** (t1, given free), **Embersteel** (t2, opens Emberdeep), **Blightbreaker** (t3, breaks the Blightcore).

The **Soul Split Wand** is a story-only mythic — useless everywhere except the final boss (see §14).

---

## 6. EQUIPMENT, ITEMS & CRAFTING

- **Armor slots (5):** helmet, chest, pants, gloves, boots. **Relic slots:** 4 → 5 at level 10 → 6 at level 20.
- **Sets:** Leather, **Bulwark of the Warlord**, **Windstalker's Garb**, **Runeweave Vestments**, Ranger's Leathers, and the endgame **Dragonscale Panoply** (+80 HP, +10% DR, +25% crit dmg). Wearing the set weapon adds a greater bonus.
- **Relics:** stat relics (Vigor, Swiftness, Greed, Wisdom, Godheart…) and triggered ones — **Phoenix Heart** (auto-revive), **Thornmail**, **Aegis Ward** (block one hit/6s), **Shadowstep Sigil** (blink-dash), **Gorgon's Gaze** (petrify on hit), **Aetherwing** (flight), **Reaper's Toll**, **Heart of the Mountain** (mining).
- **Currencies:** Gold (drives everything), Silver, Bronze (carried, non-convertible). **The real game starts with no money.**
- **Materials:** research-gated **Slime → Iron Shard → Ember Crystal → Void Essence → Ancient Relic** (identified at the Science Lab); construction **Wood/Stone/Resin**; cooking **Herb/Raw Meat/Sorrowshard**.
- **Consumables:** Health/Mana Potions (drop-only), timed **food buffs** (Hearty Stew +speed, Warrior's Feast +damage, Sage's Supper +crit), the **Reset Potion**, and the endgame **Rewound Hour**.
- **Crafting:** foods + the Reset Potion; a freed member of the Ten (Toren) cuts costs 25%. **Inventory: 55 slots.**
- **Leveling:** XP curve `50 + (level−1)×30`, **cap 100**. Dungeon kills scale gold & XP by depth (`1 + 0.10×floor`).

---

## 7. THE VILLAGE — BUILDINGS

Deepwood starts **entirely in ruins** (every building destroyed). You clear rubble by hand (3 shovelfuls), then build in **3 stages** (each costs 3 Wood / 2 Stone / 1 Resin). A building only works when **fully built**. Buildings need a **blueprint** (starters: Farm, Tavern, Builderhouse, Cottage, Wall; the rest drop at fixed floors, all in hand by floor 30). Upgrades go **levels 1–6** (+2 worker slots & +25% output each; ~1,650g to max one, ~25,000g for the whole town).

| Building | Leadership (VIP) | Does |
|---|---|---|
| **Government** | Chancellor | Taxes employed workers; Chancellor also auto-staffs idle villagers |
| **Farm** | Harvestmaster | Passive food (6/farmer/day); you can also hand-harvest (H, +4) |
| **Fishing Dock** | Harbormaster | Premium food (4/fisher/day), small morale |
| **Hospital** | Chief Physician | The "Sick Road" — heals wounded villagers who walk in; childbirth |
| **School** | Principal | Educates **children** into a random profession (24h) |
| **Barracks** | Warchief | Trains **recruits** into Warriors; armory; fields Soldiers in sieges |
| **Science Lab** | Lead Researcher | Identifies materials (unlocks skill spending); builds the Whisperstone |
| **Bank** | Treasurer | Interest on the treasury (~2.4%/day); 15% leaner payroll |
| **Blacksmith (Forge)** | Forgemaster | Gear shop (up to Rare, Epic with Toren); auto-arms the Barracks. *Gated at depth 35* |
| **Tavern** | Tavernkeeper | Lodges the unhoused (+morale vs the street) |
| **Bar** | Publican | Satisfies "social" need (town-wide morale); a small drink income |
| **Marketplace** | Merchant Prince | A pure gold sink that hosts wandering merchants; auto-sells surplus |
| **Builderhouse** | Master Builder + Foreman | Powers the repair crew — **auto-rebuilds** ruins |
| **Mine** | *(leaderless)* | Miners haul 2 stone + 1 iron / miner / day (+ember every other cycle) |
| **Shrine** | *(leaderless)* | Corruption's mercy (depth 30) — cleanses a demon back to life for 3 Sorrowshards |
| **Watchtower** | — | Siege foresight in 3 paid tiers (1h / 2h / 24h warning). *Until built, no siege warning at all.* |
| **Cottage** | — | Houses a paired couple for life — the population brake |

**Only Government (taxes), Bank (interest), and the Bar make village gold** — everything else pays in food, arms, repairs, or knowledge. The design goal: approach self-funding, never a mint.

---

## 8. VILLAGER LIFE

- **Morale (0–10 personal, town = average).** Target inputs: fed (+2), employed (+2.2), housed (cottage +1.6 / Tavern +0.8 / street −1), armed town (+1.4), a Bar (+1), leaders, headcount. **Loneliness is a standing −2 (deepening to −3.5)**; widows mourn; the town's grief subtracts. Rewards: >8/10 speeds & heals the hero in town; **10/10** brings fireworks + a periodic **gold tribute**.
- **Food:** a "villager-days" stockpile; everyone eats 1/day. An empty larder past a 30h grace **starves villagers to death**.
- **The Law of Despair:** a villager whose morale hits **0 begins to ROT** — a 6-hour redeem window; miss it and they **turn into a demon that spawns inside your walls** and infects neighbours. **Two fates:** an empty larder *kills* (a grave); broken hope *corrupts* (a turning). Warriors, shadows, and the Ten are immune.
- **Births:** pair an unpaired man + woman at a **cottage** (for life) → a 24h pregnancy → a child born at the Hospital. **1-in-200 births is a HERO** (Barracks-only, graduates a powerful adult).
- **Jobs:** assigned at each building; School graduates roll a random profession weighted toward common hands. **Leadership stats are never taught** — a leader is always a rescued VIP.
- **Wages:** staff draw 1.5 gold/day; **workers you can't pay QUIT on the spot.** Taxes flow from the Government (morale-scaled), interest from the Bank.
- **Leadership automation:** seating VIP leaders makes the town **run itself** (auto-staff, auto-repair, auto-heal, auto-sell, auto-research) — a tracked **self-sufficiency %** across five chore domains is the colony-sim payoff.
- **The village fog:** away from home (or in the deep) you learn *nothing* of the town except through the **Log (L)** — unless you have **Telepathy** (Mage) or the **Whisperstone**.

---

## 9. SIEGES

- **Schedule:** first wave 24 in-game hours after the opening ends, then every 12h (resolves even while you're deep — you get an **away report**). **Siege tier = prosperity × depth**, not the calendar (`1 + 0.30·floor + 0.08·pop + 0.02·morale`); gentler until Orin is freed.
- **Live waves:** raiders (up to 12) march from the **west/dungeon pit** and hammer the wall. **Once Orin is freed (floor 15) the EAST road silently opens as a second front** — you're never told; you discover it.
- **The Black Tide:** every 6th siege (depth ≥15), tier ×2.2 + 2 — past what walls can hold. **Only stationed adventurers can turn it.** Telegraphed with an 8-hour omen that pierces the away-fog.
- **Walls (2 ramparts, tiers 1–4):** HP 350 / 650 / 1050 / 1600; trap DPS at tier 2+; station slots 2/4/6/9. They breach at 0 HP but patch back between assaults.
- **Defenders:** abstract "defense power" = Orin (4) + warriors + heroes (3 each) + stationed adventurers + Warchief + wall tier, × morale. Live: **Barracks Soldiers** (only the on-shift half answers), **Heroes** at 3× strength with rolled powers, and villagers who mostly **flee**.
- **Warrior day/night shifts:** the corps splits into two 12h shifts; a siege at the 6:00/18:00 changeover catches the wall **half-manned** — the deliberate weak window.

---

## 10. THE OPENING

1. **Empty ruins** — a new game opens at **22:00 in the rain**; you crest the road to a dead town.
2. **The arrival battle** — the three defenders (Roland/Wren/Castor) are already fighting raiders at the gate (a staged, un-killable teaching fight you join mid-swing).
3. **Survivors emerge** — once the first wave breaks, **the Doctor and two farmhands creep from the ruins** — life returning to Deepwood — and the adventurers talk with them.
4. **The tutorial (the Oath)** — a 3-step card: raise a **Wall → Farm → Cottage** (the founder's cache of 20 wood + 12 stone covers it exactly). Finishing it starts the siege clock. *(Cinematic, no HUD, until the tutorial begins; banked to save so Continue never replays it.)*

---

## 11. THE DUNGEON

- **100 floors**, a separate scene, cycling in **blocks of 5**: four regular layout families + a **boss floor** every 5th, **plus finale bosses at 98 & 99 = 22 boss floors, 22 unique bosses**.
- **Regular floors** generate from **12 themes** (Terraces, Isles, Pillared Hall, Chasm Bridges, Gauntlet, Warren, Sunken Court, Cascade…), seeded by floor number (identical every visit), always winnable on foot, flood-fill-tested so nothing is ever stranded.
- **Hazards:** 8–16 mines/floor; creative hazards (spike, flamevent, crusher@12, poison geyser@18), all telegraphed & capped below a one-shot; a seeded floor **surprise** (cache chest or trap) + a 32% chance of a mid-fight ambush.
- **Difficulty** scales with depth (softcapped): ~5.5× HP, ~5.3× damage, +speed by floor 100.
- **Entry (3 ways):** hidden **Underdark doors** (one per floor, the frontier door wears a gold beacon), the village **Waystone** (blueprint at floor 20), and **Deep Shrine → Deep Shrine** travel (a shrine wakes at every 10th cleared floor).
- **The only gate is a "leave" gate** at the entry (a mid-fight escape hatch); clearing a floor unlocks the next, and a cleared floor **stays cleared** for the run.

---

## 12. THE BOSSES (all 22)

Each has a bespoke arena, body, movement profile, a **signature ability**, and reactive **passives** (none raise damage — they gate *how* you may fight, each with counter-play).

| Floor | Boss | HP | Signature | Key passive(s) |
|---|---|---|---|---|
| 5 | **The Gravewarden** | 1000 | Grave Grasp (root) | pure pattern |
| 10 | **The Frost Monarch** | 780 | Rime Lance (tracking freeze) | stagger armour |
| 15 | **The Cinder Colossus** | 1100 | Magma Wake (fire line) | riposte |
| 20 | **The Weaver** | 720 | Web Snare (root-zone) + summon | soulbind |
| 25 | **The Stormcaller** | 880 | Thunderstrike (bolt + stun) | skyfall |
| 30 | **The Void Sovereign** | 1220 | Void Rift (pull singularity) | sidestep |
| 35 | **The Hollow Choir** | 1150 | Dissonant Scream (disorient) | false_twin, soulbind |
| 40 | **The Ashen Penitent** | 900 | Prayer Pyre (flame front) | riposte, famine |
| 45 | **The Gaoler** | 1500 | Iron Maiden (cage/root) | tether, stagger armour |
| 50 | **Sablefang** | 820 | Pounce (leap) | sidestep, rhythm_punish |
| 55 | **The Effigy** | 1750 | Splinter Burst (ring) | afterimage_trap |
| 60 | **Mourncaller** (fly) | 1050 | Keening (homing swarm) | soulbind, mirror |
| 65 | **The Unseen** (fly) | 980 | Ambush (blink behind + stun) | phase, afterimage_trap |
| 70 | **The Warden of Nails** | 1600 | Impale (tracking nail) | skyfall, dread_ward, riposte |
| 75 | **The Twin Despair** | 1250 | Pincer Lunge + clone | covenant, sidestep, phase |
| 80 | **The Cinderking** | 1900 | Eruption (spreading wave) | afterimage_trap, mirror, famine |
| 85 | **The Glass Saint** | 1450 | Refraction (5-beam) | mirror, dread_ward |
| 90 | **The Last Man** | 1300 | Riposte Stance (parry) | rhythm_punish, phase, covenant |
| 95 | **Seraphiel, the Last Light** (fly) | 2400 | Judgment (light wall sweep) | enrage/frenzy |
| 98 | **The Abyssal Leviathan** (fly) | 2800 | Tidal Crush (floor wave) | enrage/frenzy |
| 99 | **The Eclipse Titan** (biggest in game) | 3300 | Black Sun (shrinking safe ring) | false_twin |
| 100 | **The Fallen Wizard** | 4000 | Unwriting (void under you) + Mirror Legion | **soul_split** (see §14) |

**Passive vocabulary:** *sidestep* (dodges melee), *riposte* (counters your wind-up), *rhythm_punish* (every 4th quick hit), *stagger_armour* (chip bounces — heavy hits only), *phase* (intangible for 2s after your hit), *tether*, *famine* (drains mana), *afterimage_trap* (punishes standing), *dread_ward* (hurt only from behind), *mirror* (reflects projectiles), *skyfall* (anti-air), *false_twin* (fake copies), *soulbind* (your damage heals it until you break the runes), *covenant* (two bodies heal each other).

**Weapon counters** (shallower boss floors only — the deepest 12 demand mastery): each counterable boss has ONE countering weapon (+30% damage & a special edge); sword builds a stagger-stun, archer strips guards, mage hexes. **Enrage** at 50% HP (apex 60%), apex bosses **FRENZY at 25%**.

**Boss rewards:** guaranteed material + guaranteed gear (assembling class sets) + a 15% Excellent-weapon jackpot (L25+) + a potion restock every time.

---

## 13. THE BESTIARY — 56 hostile mob types

- **6 regular archetypes** (cycling by depth, mixable): **Orc, Blood Fiend, Demon, Wraith, Bone Golem, Rotfiend** — layered with behaviors (**shield, healer, summoner, caster, dasher**) and glowing **elites** (×2.4 HP, telegraphed slam, double reward).
- **27 special mobs**, each a distinct attack, curated into **5 dungeon depth-biomes** of 20 floors (rot & beasts → haunts & gazes → the warren → the arcane siege → the apex):
  - *flyer, bomber, spitter, charger, stalker, blink_archer, warlock, hexer, runecaster, weaver, leech, burrower, warper, plague, wailer, ballista, swarm, frostling,* and the newest 9 — **sentinel** (sweeping beam turret), **brood** (splits on death), **arcbinder** (chain-lightning snipe), **warchief** (rage aura), **voidling** (blink-flanker), **gazer** (freeze-gaze cone), **skycaller** (falling-strike rain), **vampire** (lifedrain leaper), **juggernaut** (guard-tank).
- **1 siege raider** (the goblin marauder; the Black Tide is the same raider, more & tougher).
- **The turned** — every villager who rots becomes a demon inside your own walls; at the Harvest the *whole* town turns.

---

## 14. THE UNDERGROUND (Terraria-style minable world)

A **4,200 × 1,200-tile** world (12px blocks), fully **minable everywhere**, chunk-streamed, and **persistent** (your digs & puzzle flags save as a diff). Entered from the village **cave mouth**, left via an **E exit** at the entry ledge.

**5 depth-biomes** (each ~240 tiles), each with a hardness and a **pickaxe tier gate:**

| Biome | Tier | Mine gate |
|---|---|---|
| Rootearth (soil) | 0 | Miner's |
| Stonewarren (stone) | 0 | Miner's |
| Fungal Hollow (mushroom) | 1 | Miner's |
| Emberdeep (magma) | 2 | **Embersteel** |
| Blightcore (corruption) | 3 | **Blightbreaker** |

- **Mining:** hold left-click (smart-cursor on Shift); tile HP by biome (+2 for ore). The **tier gate** walls off deeper *rock* for loot — but the **carved true path down is always open**, so descent never needs a better pickaxe. Each pickaxe hides in the deepest biome the previous tier can mine (earn your way down).
- **Terrain:** one switchbacking true path pierces every seal; a region field shapes **grand open caverns** vs **tight warrens**; chasms drop between levels; cellular-automata smoothing gives real cave rooms; dark textured back-walls.
- **Content per chunk:** loot chests (16%), traps (14%), depth-scaled **mixed mobs** (5–6 types/biome) + elites (10%), **lever-vaults** & **rune-vaults** (puzzles), crystal geodes, mushroom groves, **lava pools** (Emberdeep+, 7 dmg/0.4s), and the **100 scattered floor-doors** (one per dungeon floor; enter → floor → return to the door).
- **Lighting (Terraria-dim):** ambient scaled to 40% with per-biome tint, your carried **torch** (a PointLight2D), and **placed wall torches at ~30% of spots** — warm light pools with dark stretches between.

---

## 15. THE CAST

**The three opening heroes** (level-0, mortal, permadeath — station on wall/city/house):
- **Roland Ashmark** (blade, Shield Wall — canonically survives to floor 100) · **Wren Falkner** (bow, Twin Nock) · **Castor Hale** (spear, Phalanx Sweep).

**The deep nine adventurers** (chained one per marked depth, freed with E): Mira Coldbrook (7, Frostbrand), Jorun Pyke (13, +dmg per dead ally), Essa Nightbrook (18, piercing), Darvin Mott (23, kill-heal), Kessa Vayle (33, double retaliation), Brannoc Tor (43, Fifth Blade), Liselle Dray (53, poison), Hakon Vey (63, once-a-siege revive), Sorrel Ka (78, execute).

**The Ten — "Unbreakable" legends** in gilded trophy vaults (each a permanent village boon; unkillable at the Harvest; **all ten must be freed to open floor 100**):

| Name | Floor | Boon |
|---|---|---|
| Brannoc, the Wall That Stood | 22 | Warriors train 2×, wall 1.5× stronger |
| Maera, the Last Lightmender | 26 | Doctor heals 2×; once/siege pulls someone from the brink |
| Sylvara, Warden of the Old Groves | 31 | Farm output doubled |
| Kaldos, the Tidecaller | 34 | Dock hauls materials as well as food |
| Toren Ashvale, the Forgefather | 38 | Forge sells up to Epic; crafting 25% cheaper |
| Dorian Vail, the Coinbinder | 43 | Bank interest doubled; dropped gold half-insured |
| Mirielle, Voice of the Old Crown | 47 | Government runs further; leaders worth double |
| Elenwe, Archivist of the Broken Age | 53 | All materials understood at once |
| Seraphel, the Lightkeeper | 58 | Halves village withering; grief passes 2× |
| **Ilo, the Nameless Bard** | 63 | Tavern lifts the whole village |

When the last of the Ten is freed they **hand you the Soul Split Wand** (Elenwe knew what it was, Toren reforged it, Ilo remembered *why*).

**Orin** — introduced as a wandering mage who arrives at the west wall after you first reach **floor 15**, tells a story that *mirrors your own arrival*, then holds the nightly watch casting meteors, growing stronger every time he "falls" and reforms (~12h). He is **secretly the Monarch of Despair** — the farmer admiring his crop.

---

## 16. THE ENDGAME — THE HARVEST

The finale gate (floor 100) opens **only to a perfect village**: 0 ruins, every role staffed, **morale 100**, and **all Ten freed** — because a perfect village is exactly what Orin was farming. Floor 100 is an **empty throne**; you carry the false victory home.

1. **False victory + feast** — the town erupts; morale peaks; *"It's over. We won."*
2. **The reveal** — Orin reveals himself as the Monarch: *"Deepwood was never being defended. It was being **harvested**."* The people **kneel and begin to turn.**
3. **The fight** — the whole village becomes level-100 despair, streaming in from both edges **wearing their own names**. **Wren & Castor turn (real deaths); Roland holds.** The **Ten (and Roland) hold the lanes**, unkillable.
4. **The Devourer** — Orin starts weak (his power must be *eaten*), devouring the living turned to grow up to 2× size. **A race: every villager you kill is one he can't eat.**

---

## 17. THE FINALE BOSS & THE SOUL SPLIT WAND

**The Fallen Wizard** (barely taller than you — power, not bulk): a crumbling red aura (5 dmg/tick), reflex blink-on-hit, and a **Mirror Legion** of up to 6 echoes.

**"An undivided soul cannot be destroyed":**
- **Soul Ward:** with **no echoes out** he takes **only 50% damage**; each living echo cracks the ward **+25%** (up to 2× at the full legion of 6).
- Any ordinary killing blow — even a DoT — just **reforms him at 1 HP** ("THE UNDIVIDED SOUL REFORMS").
- **The Soul Split Wand is the one exception:** it **scatters his soul for exactly 4 seconds**, during which the ward vanishes and he is **mortal** ("HIS SOUL SCATTERS — STRIKE NOW!"). **The kill: let the legion grow, survive it, hit him with the wand, and burst him inside the 4-second window.**

---

## 18. THE SHADOW COURT & THE TRUE ENDING

Kill Orin and **"Despair is dead"** — sieges end forever (the apparatus dies with the farmer). Your true nature fully wakes and you perform your first royal act: the **Shadow Army** — every fallen villager **rises as a shade of themselves**, names/homes/jobs/bonds kept, raised whole and content. The Ten remain flesh among the shadows. Beating Orin **permanently unlocks the Shadow Monarch class** for all future runs.

Among the spoils is **⌛ The Rewound Hour** (one per world) — a **turn-or-shatter** choice:
- **Turn it → New Game+.** The world rewinds to ruin, but **you and everything you carry are immune** (level, class, skills, materials, equipment, Monarch stage, and your worlds-walked count). *"You remember everything. It remembers nothing."*
- **Shatter it → the True Ending.** Break the cycle forever — the one victory no Monarch before ever managed: to let a won world simply **be, and end.** *"I did not break his cycle to build my own."* Ilo names you **"the Monarch Who Let It End."**

**The Chronicle (100%):** seven lines that must all hold at once — every taken soul home, every bond honored, all Ten freed, the skill graph fully explored, Deepwood at its peak, Despair destroyed, the Shadow Army raised. *"⭐ THE CHRONICLE CLOSES COMPLETE — 100%."*

---

## APPENDIX — KEY NUMBERS

- **Player:** 160 HP · 90 mana · SPEED 200 · JUMP −400 · GRAVITY 900 · dash 900 · level cap 100.
- **Time:** 600s = 24 in-game hours · new game opens 22:00 · autosave every 180s.
- **Village:** buildings level 1–6 · construction 3 stages (3 wood/2 stone/1 resin each) · wages 1.5g/day · 55-slot inventory.
- **Dungeon:** 100 floors · 22 bosses · scaling softcapped ~5.5× HP / 5.3× dmg at L100 · enrage 50% (apex 60%) / frenzy 25%.
- **Underground:** 4,200 × 1,200 tiles (12px) · 5 biomes · pickaxe tiers 1/2/3 · lava 7 dmg/0.4s · 100 floor-doors · ambient 0.40.
- **Bestiary:** 6 archetypes + 27 special mobs (5 biomes) + 22 bosses + 1 raider = **56 hostile types**.
- **Finale:** Soul Split window 4.0s · Soul Ward 50%→100% cracked · Mirror Legion cap 6 · Wizard base HP 4000.

*Generated from the current source (`game_state.gd`, `boss.gd`, `dungeon_interior.gd`, `underground.gd`, `special_mob.gd`, `player.gd`, `skill_tree.gd`, `inventory.gd`, `the_ten.gd`, `adventurers.gd`, `harvest_director.gd`, `story.gd`, and others).*
