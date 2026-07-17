# DEEPWOOD — The Game Bible

> **THE single source of truth for the entire game.** Written 2026-07-15 with the developer,
> consolidating and superseding the design content of `STORY.md`, `VILLAGE_SYSTEMS.md`,
> `GAME_OVERVIEW.md`, and `ROADMAP.md`. Where any other document disagrees with this one,
> **this one wins.**
>
> The rule of this phase: **no new code until this book is polished to 100%.** Every feature,
> every story beat, every system — decided here first, built second.
>
> **Status legend:** ✅ BUILT (exists in code) · 🔨 PARTIAL (started, incomplete) · 📋 PLANNED
> (decided, not built) · 🟡 OPEN (needs a developer decision — all of these live in §12, nowhere else)

---

## 0. The Vision

**One line:** *The village lives. Neglect breeds monsters. The final evil is the despair you allowed — and the final hope is what you became while fighting it.*

**Logline:** A fallen god-king, hollowed into a nameless mortal, hunts an evil he cannot remember losing to — and finds it wearing the mask of a hero.

**Tone:** **Epic & mythic.** Solemn, grand, the weight of fallen god-kings. Serious and sweeping — not horror, not cozy, not comedic. Every line of dialogue, every enemy name, every boss design is measured against this.

**Genre shape:** single-player 2D side-scrolling action RPG + village colony-sim. Dungeon-crawl combat feeds a living-village rebuilding loop; the two halves squeeze each other harder as the game goes on, and collide completely at the finale.

---

## 1. What this game IS — and IS NOT

### The five pillars (everything must serve one of these)
1. **Descend** — a 100-level dungeon with a boss every 5th floor; the root of the evil is at the bottom.
2. **Free them** — the taken are *named people*, frozen neither-alive-nor-dead; every rescue is a light coming back on.
3. **Rebuild** — ruined buildings repaired, roles staffed, chores done by hand until you earn automation.
4. **Grow strong enough** — village output → gear, skills, militia; the village feeds you as you feed it.
5. **The squeeze** — the healthier the village, the harder Orin's sieges; every hour rescuing is an hour the walls stand thin.

### Explicitly NOT in this game (hard non-goals)
- **No multiplayer, ever** — not co-op, not competitive waves, not matchmaking. Do not architect for it. (Possible expansion only after the base game ships and sells 5,000+ units.)
- **The Monarch of War never appears.** He is backstory and a sequel hook only — a dangling thread, deliberately off-screen in another dimension.
- **No horror tone, no cozy tone** — mythic only.
- **No generic "no-work depression"** for villagers (statless-depression exists, see §7; jobless-but-skilled villagers are fine).
- **No passive HP regeneration** for anyone — player or villager — except via relics/items.
- **The protagonist stays blank.** No fixed name, face, history, or voice. Players self-insert. Never write dialogue that gives him a past (his past is the *secret* — see §2).

---

## 2. The Story — full canon

### 2.1 The Age of Monarchs (deep backstory)
Before Deepwood, three great powers ruled — the **Monarchs**:
- The **Monarch of Despair** — who unmakes the living, leaving them neither alive nor dead.
- The **Monarch of War** — whose domain now lies in another realm. *(Sequel hook. Never on screen.)*
- The **Shadow Monarch** — a power of shadow and death, equal to the other two. **This is the player.**

Ages ago, Despair and War **allied against the Shadow Monarch** and defeated him in a battle that broke the world. Dying, he cast one last forbidden spell: he unwove his power and poured his soul into a **mortal shell**. It worked — but the price was everything: throne, power, name, and memory, sealed inside an ordinary human who woke with nothing. Since then, War withdrew to another dimension; **Despair went on alone and turned his hunger on mankind.**

### 2.2 The world now — and the Law of Despair (refined 2026-07-15)
The world itself is drowning in **despair**. The Monarch of Despair has **killed half of humanity and razed whole countries** — but worse than what he destroys is what he *converts*.

**The Law of Despair (core lore):** no one in this world is born evil — **evil is a broken person.** A soul falls in exactly one way: its **hope dies**. Morale, everywhere in this game, *is* hope. When it reaches **0**, a person becomes hopeless; the hopeless fall into despair; and despair converts them into the very evil that broke them. Every monster in the dungeon was once someone whose hope died. (§10 makes this law mechanical.)

**And then there are the unbroken.** Scattered through mankind are people who never lose hope — who do not break, no matter what is done to them. Despair cannot convert them. So the Monarch does the only thing left to him: he **freezes them** between breath and grave and **feeds them despair and constant sorrow**, patiently, for years, trying to crack the one thing he cannot take by force. **The taken are not his food — they are his unfinished victims.** Every frozen hostage the player finds is, by definition, someone who refused to fall.

**Degrees of hope (keeps the lore consistent with the game's systems):** resisting the fall of your whole world once is rare strength — but it is not absolute immunity. A rescued villager who is afterwards starved, unhoused, and joyless for long enough *can* still be ground down to 0 back in the village (§10 corruption): hope that survived a catastrophe can still be eroded by neglect. Only the **Ten** (§8) are truly unbreakable — which is exactly what makes them the Ten.

### 2.3 The one who comes (the player)
You are the Shadow Monarch — but you don't know it, and the game never tells you outright. You are a **nameless, blank mortal** who has wandered lifetimes as a hunter, pulled toward the evil by an instinct you can't explain. It is *as a man*, not a king, that you choose to help Deepwood — and that choice is who you are when the god-power finally returns. **Your true nature and memories return only at the very end.**

The trail ends at Deepwood.

### 2.4 Deepwood
A once-thriving village, now almost empty. Buildings broken and ruined — farm fallow, dock rotted, bank and school silent. A handful of survivors starve in the wreckage. Scattered through the ruins and the dungeon below are **the taken**: villagers frozen mid-motion, pulsing faintly like a held breath — the people whose hope would not die when Deepwood fell, imprisoned mid-breaking and force-fed sorrow until it does. A rescue doesn't just free a body; it **interrupts a breaking**. One still has enough of himself left to beg you for help. *(This plea is the game's opening — ✅ wired via `Story.OPENING`.)*

### 2.5 Orin — the enemy wearing a hero's face
**Orin** appears as a stranded defender-mage: the last thing standing between Deepwood and the dark, hurling meteors at the nightly horde, dying for the village and rising each dawn. The survivors love him. **You fight beside him for most of the game.**

It is a mask. **Orin is the Monarch of Despair.** The horde is his; the "defense" is theater — a slow harvest dressed as heroism. He is genuinely **undying**: struck down, he collapses to an ember and reforms *stronger*, forever (✅ built — his death-escalation loop is intentional and must never be nerfed).

- **Why he lets you live:** he thinks you're nobody — a stray adventurer, beneath killing. If you ever drew on your true power he would recognize a rival monarch and destroy you instantly. *Your disguise is your survival* — this is the in-fiction reason the Shadow Monarch class stays locked all game.
- **Why he can't die:** *an undivided soul cannot be destroyed.* This is the lock on the entire game — and its key.
- **Why he waits (the full truth):** Orin has been **waiting for you to build the village to its maximum.** The tribute, the breathing room between sieges, the survivable nights — all calculated generosity. He wants Deepwood at its peak so that, with one sweep of his hand, he can turn *everything you built* against you. It isn't just harvest. **He wants to play with his food** — to watch the builder's face as the built thing turns. Despair is his nature; manufacturing the *perfect* despair is his art.

### 2.6 The shape of the journey
The story is *earned* through the loop, not told in cutscenes: descend → free them → rebuild → grow strong → the siege tightens. The village growing brighter and the nights growing worse are **the same story told from both ends.** (The act-by-act player experience is §3; the finale is §9.)

### 2.7 How it ends (summary — full beat-by-beat in §9)
At the gates of Level 100 the mask falls: the dungeon kneels to Orin, and something in your sealed memory *flashes* — you have lost to this power before. Then **the Harvest**: the revelation itself is the weapon — the savior they loved was the devil all along, and that betrayal, driven home by Orin's magic, shatters the whole village's hope to 0 in a single breath; everyone you saved falls to despair and transforms into his army — except **the Ten** (§8), the truly unbreakable, who stand with you. Orin devours the transformed to grow into a titan; you race to deny him fuel; and you kill the unkillable by **dividing his soul** and striking while it's scattered. Victory breaks your seal: memory, throne, true form return — and your first royal act is **Shadow Army**: you raise every fallen villager as a shadow, and the village *continues*, alive in a new way, yours to lead. One Monarch is destroyed. Somewhere beyond, the Monarch of War still waits. *(Another story. A future game.)*

---

## 3. The Player's Responsibility — the whole game, act by act

What the player is actually *doing and worrying about* at every stage. This is the spine the content hangs on.

### Act I — The Ashes (dungeon floors ~1–15)
- **Survive.** Weak start: basic weapon, no gold, gated skills, empty ruined village (✅ honest-start mode is the default; the old sandbox lives behind `--dev`).
- **Learn the loop:** enter the dungeon, clear floors, take the first boss (floor 5), carry loot home.
- **First rescues** (Elin, Milo, early taken) and **first repairs** — done poor: every coin hurts.
- **Everything is manual:** you hand-feed villagers, hand-assign the first workers, hammer walls yourself.
- **Responsibility:** keep a handful of people alive with your own hands.

### Act II — The Rebuilding (floors ~15–50)
- **The village machine starts turning:** Farm/Dock feed people, School teaches stats, first cottage pairings, first children.
- **Class identity:** the player commits to Sword / Archer / Mage; tier 1–3 skills; first set-armor pieces from bosses.
- **Sieges begin and scale** — walls, warriors, the day/night shift rhythm.
- **The corruption threat becomes real:** neglect starves villagers → morale 0 → they turn demonic *inside the walls* (§10). The player learns the Law of Despair firsthand: *morale is hope, and hope is the thing you are actually defending.*
- **Blacksmith Forge unlocks at depth 35** (✅) — first purchasable full-slot gear up to Rare.
- **Shrine unlocks at depth 30** (📋) — corruption stops being always-fatal.
- **Responsibility:** build an economy; keep morale up; balance dungeon time vs. defense time.

### Act III — The Squeeze (floors ~50–95)
- **Escalation on both ends:** deep floors are brutal; sieges are brutal; the player *cannot* be everywhere.
- **Automation is the reward:** Government scales chore-automation (kids route to school → jobs; wall shifts auto-assigned; taxes collected) — earned relief from Act I–II's manual grind.
- **The Ten** (§8) — the capstone rescue arc: one legendary hostage hidden in a vault every ~5 floors from 52 to 99, each permanently transforming one village system.
- **Keystone skills, exclusive specs, ultimates; Excellent-grade weapons; full set bonuses.** The player becomes a monster — and pales, literally, as the hidden Shadow Monarch passive stages tick up (§6).
- **Foreshadowing beats** (📋): Orin's suspiciously generous tribute; cryptic dungeon notes; a taunt that he *wants* you to grow; Ilo the Bard's fragments of the Age of Monarchs.
- **Responsibility:** perfect the village (the finale gate demands it) while surviving the worst the dungeon has.

### Act IV — The Harvest (the gate + floor 100)
- Full sequence in §9. **Responsibility inverts:** everything you built becomes the boss. Your job is no longer to protect the village — it's to *end the thing that made protecting it impossible*, and then to bring them all back.

### Post-game — The Shadow Court (§11)
- Lead the shadow-village; play the unlocked **Shadow Monarch** class; NG+.

---

## 4. Combat, Player & Dungeon — systems inventory

### 4.1 Player & combat ✅ (built, still balancing)
- Side-scroller controls: move, jump/double-jump, dash, mouse-aimed omnidirectional attacks, weapon hotbar, E interact, Tab inventory, K skill tree.
- **Mana pool** (base 50 → up to 90 endgame) powering wands/specials; HP up to 160 endgame.
- **Crits + floating damage numbers**; **status effects** (burn / poison / freeze / slow); **fall damage** past a safe distance (negated by fall-immunity relics); **flight** (Aetherwing relic — 10s budget, glide).
- **Death penalty by difficulty** (Easy/Medium/Hard, chosen once per save, permanent): gold drop always; + a random villager lost on Medium; + a skill material on Hard.
- **No passive HP regen** — healing = potions (boss-gated, §7.4), paid Hospital healing, or relic effects. 🔨 (rule decided; hospital-paid-healing and potion-gating not fully enforced yet)

### 4.2 The dungeon ✅
- **100 sequential floors** under Deepwood; unlock one at a time; boss every 5th floor with unique arenas; enemy stats scale with depth; mines, twin gates (blue retreat / green advance), exit button anytime.
- **Enemy identity — SETTLED:** undead/evil/deepwood-themed across all mobs and bosses; **archetypes + elites** with distinct behaviors; **all apex bosses have combo AI** (multi-skill chains with punish windows — the L100 Fallen Wizard's five-combo brain is the template).
- **Lore layer on the same enemies:** they are *fallen humans* — people whose hope died (morale 0 → hopeless → despair → evil; the Law of Despair, §2.2; §10 makes it mechanical, not just flavor).
- **Rescues inside the dungeon** ✅: 19 leadership VIPs freed at bosses 5–95, + the earlier deep figures. **The Ten (§8) are separate and deeper.**

### 4.3 Itemization ✅
- **6-tier grade ladder** (ITEM_GRADES) + **grade passives** (any wielded weapon passively buffs everything by its grade).
- **3 class armor sets** (Bulwark/Sword, Windstalker/Archer, Runeweave/Mage) with two stacking bonus tiers (3 armor pieces; + the set weapon on top).
- **Relics** (class relics, gathering relics, flight/featherfall, crit/on-kill/ward/economy relics), **gloves/boots slots**, damage reduction.
- **Special-attack weapons** (projectile "special" dict system): Windcutter, Sunderer, Stormlance, Stormvolley, Seeker Bow, Emberstaff, Icicle Wand, Leviathan Hook, Galewing Glaive, Chrono Edge, Midas Edge, Echo Rift, Soulthirst, Wizardsbane (anti-boss), and more — 30+ weapons total.
- **Consumables + crafting** (`try_craft`), **gathering tools** (Woodsman's Axe → wood/resin; Miner's Pickaxe → stone/iron/ember) with overworld harvest nodes.
- **Loot rules:** bosses drop level-gated gear (relics L3+, set armor L6+, set weapons L15+, Excellents rare L25+), always something unowned. Set/variant gear is never granted at start.
- **Blacksmith Forge** ✅: gated to depth 35, vendors every slot up to **Rare** only (loot stays king above that).
- **Standing rule:** every item's inventory icon must closely match its in-hand/equipped appearance.
- 📋 Still to do: **Reset Potion becomes a real inventory item** (currently a UI button); **1g Magic Wand stays admin-only** (label/gate it — it is a test tool, never a real spell).

### 4.4 Skill tree & classes ✅ (redesigned as a graph)
- Three main classes — **Sword, Archer, Mage** — each tree a **branching graph**: at tier 4 every spec **forks into mutually-exclusive keystones** (exclusive groups, enforced everywhere), keystones **evolve**, ultimates are **triggered actives**. Warden spec = pure DoT.
- Tier 1–2 cost points; tier 3+ also cost **materials** (Slime → Iron Shard → Ember Crystal → Void Essence → Ancient Relic by depth), which must be **researched at the Science Lab** before spending — skill progression is tied to which village roles actually function.
- **Reset Potion** refunds points and class choice (materials not refunded).
- The fourth tree — **Shadow Monarch** — is visible but locked until the game is completed (§11). *(Renamed from "Necromancer" everywhere; never use the old name.)*
- 🟡 The Shadow Monarch class's actual *kit* is still undesigned → §12.

---

## 5. The Village — the living machine

### 5.1 The Grammar (the law every building obeys) ✅ decided
> A building serves a **NEED** → employs **STAFF** (daily wages) → skilled staff need **KNOWLEDGE** (School) → the building runs an automatic **SERVICE** → destroyed/unstaffed/unpaid, the service **STOPS** → **CONSEQUENCE** → **MORALE** moves.

**Three stages of every task:** do-it-yourself (early) → delegated (staffed, slower) → automated (staffed + upgraded + wages paid). **Automation costs wages; can't pay → workers quit → back to manual.** Two layers: building-level automation (farmers farm, nurses heal) and **management-level automation (Government)** — the mid→late building that scales automation of the *player's own chores*.

### 5.2 The building roster (14) — status mixed ✅/🔨/📋
| Building | Serves | Falls → breaks |
|---|---|---|
| **School** (keystone) | skilled workforce — teaches stats | the whole automation web unravels |
| **Farm** | food #1 | starvation |
| **Fishing Dock** | food #2, variety | no backup food, variety morale lost |
| **Hospital** | healing + births | wounds kill; no new children |
| **Barracks** | defense — day/night shifts (§7.5) | every siege is on the player |
| **Blacksmith** | arms & tools + the depth-35 Forge | weak defense, slow workers |
| **Builderhouse** | repair/construction | rebuild everything by hand |
| **Science Lab** | research (materials, upgrades) | no progression |
| **Marketplace** | trade — production → gold | can't pay wages |
| **Bank** | treasury, interest, payroll | gold vulnerable, no interest |
| **Government** | the management brain; global automation scaler | back to manual chores |
| **Tavern** (inn) | lodging — newcomers arrive here until housed | newcomers have nowhere to be |
| **Bar** | drink, music, fun → morale | despair comes faster |
| **Shrine** 📋 | *redemption* — capture & cleanse a transformed demon back into a villager; unlocks at depth 30 | despair is always a death sentence |

All buildings start **visually destroyed** and non-functional; repair costs gold + materials in stages (✅ built, incl. siege damage/repair).

### 5.3 Professions ✅ decided
One profession stat per building (Farmer, Fisher, Doctor/Nurse, Smith, Builder, Scholar, Merchant, Banker, Official, Teacher, Innkeeper, Barkeep) + **Warrior** (Barracks — deletes all other stats, permanent, one-way sacrifice). Leadership roles (Leader / Principal / Warchief) can **never** be taught — only rescued hostages who already carry them qualify. Leader bonuses (+15% class-appropriate boosts) ✅.

### 5.4 Villager stats & the school pipeline ✅ decided / 🔨 partial
- Every NPC carries **0–5 profession stats** (1 common → 5 extremely rare). **1 stat = employable + safe from depression.** Extra stats = pure versatility.
- **Statless NPCs** slowly become depressed → fix via School (gain a stat) or Barracks (become a Warrior).
- School retraining: 2nd stat 5× time, 3rd stat 10× time, **hard cap 3 via School** — natural 4–5-stat rescues stay elite finds.
- **Lifecycle pipeline:** pair at cottage → ~25h → child → enroll → ~24h → adult with a stat → employ. Manual early (deliberately tedious); **Government automates the whole chain** (kids self-route to school → straight to a job).
- **Villager bonds** ✅: per-villager personal quests (gather/slay/reach-level/reunite) that reveal a hidden stat + reward + 1.5× income from that villager.

### 5.5 Needs ✅ decided / 🔨 partially built
| Need | Filled by | Empty → | Status |
|---|---|---|---|
| **Hunger** | Farm/Dock visible food (walk-up eating) | morale drop → death in ~2–3 days | ✅ v1 |
| **Health** | Hospital nurses (roaming, ranged heals); player heals there for gold | wounds/illness kill | 📋 |
| **Wages** | player income; manual early, Bank/Govt later | workers quit → services stop | 📋 |
| **Mood** | Bar / village fun | low mood | 📋 later |
| **Mating-depression** | cottage pairing | long-single villagers sadden | 📋 later |

**Potions rule** 📋: HP/mana potions drop **only** from pre-boss waves and boss fights — the player enters every boss stocked, and can't potion-spam normal floors.

### 5.6 Economy ✅ core / 📋 depth
Assigned workers generate passive gold scaled by stat; Government taxes; leader bonuses; tribute; morale rewards. 📋 Depth pass: wages as a real drain, Marketplace auto-selling, Bank interest/payroll. Morale meter ✅ (unlocks once every building has been repaired).

---

## 6. The Hidden Passive — the Shadow Monarch stirring ✅ v1 / 🔨

A **7-stage hidden passive** — never shown in the skill tree, it just *happens* — tied to character level (cap 100). Each stage: bigger shadow aura, paler skin, a stacking power. The player slowly becomes something the village notices and can't name.

| Stage | Lv | Look | Power |
|---|---|---|---|
| 1/7 | 5 | wisps | **Umbral Touch** lifesteal |
| 2/7 | 15 | growing aura, faint pallor | +shadow damage, dash trail |
| 3/7 | 30 | tendrils, pale | **Shadowstep** (dash i-frames) 🔨 |
| 4/7 | 45 | tendrils wrap him | **Dread** fear aura (slow/weaken) 🔨 |
| 5/7 | 60 | so pale the **hood rises** | **Rise, Shade** — kills raise a temporary shade 🔨 |
| 6/7 | 80 | living shadow cloak | **The Long Dark** — a lethal hit becomes shadow-form (invuln + heal), not death 🔨 |
| 7/7 | 100 | 2× size, shadow armor, god | everything amplified; permanent shades; shadow nova 🔨 |

- Villagers **react at stages 5–6** (afraid / awed / confused mood lines) ✅.
- **7/7 fully manifests only during the Harvest, when the village has fallen** — so **only Orin ever sees the true form.** This passive is the mechanical foreshadowing of §9; *Rise, Shade* at 5/7 is the seed of the ending's **Shadow Army**.

---

## 7. Defense — sieges, warriors, walls ✅ core / 🔨

- **Scheduled sieges** scale with village health — a *living* village is an insult to the Monarch of Despair; prosperity literally raises the pressure (the squeeze is the design, not a bug).
- Walls with HP on both sides; trained warriors sally out as visible soldier units ✅ v1.
- **Barracks shifts** 📋: two shifts (day/night) that swap so the off-shift can sleep and be healed for 12h (no passive regen — nurses do it). Manual wall assignment early → Government automates. Night sieges and mid-siege shift changes are intentional tension hooks.
- After a siege, wounded warriors **stay wounded** until the Hospital heals them.

---

## 8. The Ten — the capstone hostages (new canon, designed 2026-07-15)

Every frozen hostage is someone whose hope refused to die (§2.2) — but hope has degrees, and most of the rescued can still be worn down by a hard life afterwards. **The Ten are the apex: the truly unbreakable.** Deep in the dungeon, past where the leadership VIPs end, Orin keeps them as his **trophies**: ten legends of the broken age he has personally tried to break for years — and never once cracked. Despair finds no purchase in them at all, and that fascinates and enrages him. He keeps them close, still trying.

**That immunity is the point:** when the Harvest comes and every soul in Deepwood turns, **the Ten do not turn.** They are the heroes who stand with you at the end.

Each is found in a hidden **Trophy Vault** on a non-boss floor (so they're discoveries, not boss loot), one every ~5 floors from 52 to 99. Each rescue permanently transforms one village system — these are the "unusually impactful once freed" rescues the vision always promised.

| # | Name & title | Vault floor | Village boon (permanent) |
|---|---|---|---|
| 1 | **Brannoc, the Wall That Stood** — last Warchief of the old realm | 52 | Warriors train 2× faster; walls +50% max HP; he personally leads the night shift |
| 2 | **Maera, the Last Lightmender** | 58 | Nurse heal range/speed doubled; once per siege she stabilizes a villager who would have died |
| 3 | **Toren Ashvale, the Forgefather** | 63 | Blacksmith can forge **Epic**-grade (one above the Rare cap); crafting costs −25% |
| 4 | **Sylvara, Warden of the Old Groves** | 69 | Farm output doubled; rare herbs begin growing in the overworld |
| 5 | **Kaldos, the Tidecaller** | 74 | Dock deep-catches yield materials as well as food; food-variety morale bonus |
| 6 | **Elenwe, Archivist of the Broken Age** | 79 | All unknown materials auto-researched; Lab research 2× ; she speaks lore of the Monarchs |
| 7 | **Dorian Vail, the Coinbinder** | 84 | Bank interest doubled; on player death, half the dropped gold is insured (returned) |
| 8 | **Mirielle, Voice of the Old Crown** | 89 | Government automation takes a major leap; taxes no longer cost morale |
| 9 | **Seraphel, the Lightkeeper** | 94 | Shrine cleansing faster & cheaper; her aura slows corruption HP-drain village-wide |
| 10 | **Ilo, the Nameless Bard** | 99 | Bar/Tavern morale way up — and he *sings fragments of the Age of Monarchs*, the game's clearest foreshadowing; at the gate of 100, he is the one who names what stirs in you |

Status: 📋 all ten (names/floors/boons canonized here; nothing built). Rescuing **all Ten is part of the finale gate** (§9.1).

---

## 9. The Finale — "The Harvest" (full canon, updated 2026-07-15)

*This section replaces every earlier ending draft, including STORY.md's "the village corners Orin" climax. The developer's decision: the Harvest happens — and the Shadow Army answers it.*

### 9.1 The gate — Level 100 stays locked until:
1. **100% of all buildings** repaired,
2. **every role slot in the village filled** (full employment),
3. **10/10 morale**, and
4. **all Ten rescued** (§8).

Only a *perfect* village opens the final floor — because a perfect village is what Orin has been patiently farming all game. The gate is why the Harvest is total: **he needs the peak to reap it.**

### 9.2 The shiver (at the gate)
Every enemy in the dungeon stops fighting *you* and turns to kneel before Orin — the horde re-forms as *his* army, the mask falls: the beloved defender is the Monarch of Despair. And in that instant your sealed memory *flashes* — not facts, a feeling: *you have faced this power before. You have lost to it before.* A short exchange passes — quiet, almost courteous, two monarchs recognizing each other at last. Ilo, if he stands near, whispers the old name he could never finish singing. *(✅ the L100 reveal dialogue is wired via `Story.L100_REVEAL`; it will need updating to this fuller sequence.)*

### 9.3 The turn — the Harvest 📋
This was never just harvest — it's theater, staged for an audience of one. Orin wanted you to build it *so it would hurt.* And the weapon is not brute force — **it is the truth.** In one instant the village learns that the hero who bled for them every night IS the thing that took their families; the story that kept them standing collapses, and Orin's magic rides that collapse, driving every heart's hope to **0 at once** — the Law of Despair (§2.2) executed on a whole town in a single breath. Everyone — farmers you fed, children you raised, soldiers you trained — becomes hopeless, falls into despair, and transforms into strong, level-100-tier evil that attacks you. **No survivors, no loyal holdouts... except the Ten**, whose hope not even this can kill. They stand with you — ten lights in a town gone dark.
- Population at full staffing realistically **~150–200+** (computed from role slots at build time). **Never spawn them at once — stream as waves.** You *feel* the whole town turning; the engine stays smooth.

### 9.4 The Devourer race 📋
Orin's final form — the **Monarch of Despair unmasked** — starts *weak* (nerfed personal attacks). His power is **earned by eating the horde**: he devours the *living* transformed over time; every **5% of the population consumed = +1 power tier** (bigger, more HP, more damage; ~20 tiers possible).
- **Your kills deny him fuel** — every transformed villager you cut down is one he can't eat. Rush the horde and you starve his growth but drown in bodies; turtle and he becomes a titan. Pure player agency; tuned so a strong player downs him at ~30–50% absorbed, a slow one faces a monster — **but it stays winnable.**
- **The Ten hold lanes** — each fights in character (Brannoc anchors, Maera keeps you standing, Seraphel slows the tide...). They are help, not a solution.
- **Theme:** the bigger the village you built, the bigger the monster it can become. *You built your own final boss.*

### 9.5 The kill — divide the soul 📋 (mechanic partially ✅ in the L100 boss)
*An undivided soul cannot be destroyed* — so you divide it. The **Soul Split Wand** (§9.7) — the joke item that splits anything into 7 harmless mini-clones for 4 seconds — is useless against every creature in the game except one: **the Monarch of Despair's 7 fragments ARE damageable.** Splitting him opens a 4-second burst window where the deathless thing is, for the first and only time, mortal. You strike the soul itself. **Despair ends.**

### 9.6 The return — and the Shadow Army (new canon 2026-07-15)
In the final blow the seal breaks. Power floods back, memory with it — the throne, the name, the ancient war. **You reclaim your true Shadow Monarch form** (the 7/7 manifestation the fight already forced). And you look at what victory cost: the village dead around you, all but ten.

Then the Shadow Monarch's **final ability unlocks — SHADOW ARMY:** you raise **every fallen villager as a shadow.** Not husks — *themselves*, continued: they keep their names, faces, homes, jobs, and bonds, re-made in shadow-form. **The stronger the person was in life, the stronger the shadow** — a legendary Warchief rises as a greater shade than a farmhand, and shadow variants differ by who they were (worker-shades, warrior-shades, leader-shades). The village Orin murdered gets back up — as the Shadow Monarch's people. The Ten remain living, flesh and blood among the shadows — the memory of what Deepwood was.

Deepwood stands, and it is yours to lead — a god-king with a mortal's heart, ruling the first city of the dead that is still, stubbornly, *alive*. One Monarch is destroyed. Somewhere beyond this world, the **Monarch of War** waits. *(That reckoning is another story — a future game.)*

### 9.7 Signature item — the Soul Split Wand 📋 (design locked)
A quest-reward novelty weapon, *deliberately useless* everywhere, that becomes the answer to the one fight it was made for.
- Fires a bolt; the target **splits into 7 mini-clones** (~0.38× scale) that scatter, spin, and **snap back together after 4 seconds**. While split, normal targets are **invulnerable** — on every regular mob it's purely visual, a disco-split joke.
- **The sole exception:** the Monarch of Despair — his fragments are damageable (§9.5).
- Single-target on hit; `duplicate()` the procedural node tree ×7 (works on every enemy since all visuals are polygon trees); 20s cooldown, ~15 mana.
- 🟡 Where the quest that awards it lives → §12.

### 9.8 Foreshadowing checklist 📋 (plant all of these so the twist feels planned)
- Orin's tribute is suspiciously generous; his "defense" never quite ends the threat.
- Cryptic dungeon notes in the deep floors.
- A taunt (mid-game) that Orin *wants* you to grow.
- Ilo's unfinished songs (§8) + Elenwe's Monarch lore (§8).
- The hidden passive (§6): the player's own creeping pallor is foreshadowing the *other* reveal.
- The taken kneel-and-turn at the gate is pre-echoed once, small, in a mid-game siege (one enemy bows to the horizon before dying) — blink and you miss it.

---

## 10. Corruption — despair made mechanical ✅ v1 (currently disabled by flag)

**Lore (the Law of Despair, §2.2):** no one is born evil — evil is a broken person, and **morale is hope.** A villager whose morale hits **0** becomes hopeless, falls into despair, and turns **demonic** — the same kind of creature as the dungeon's — attacking the village from within. Every rescued villager already resisted the fall of Deepwood once (§2.2), but hope that survived a catastrophe can still be *eroded* by neglect — hunger, homelessness, joylessness. The dungeon and the village share one villain: *untended despair.* (And the finale, §9.3, is this same law executed on the whole town at once — the corruption system IS the foreshadowing of the ending.)

- Transformation **only at morale 0**; neglect (hunger, homelessness, no joy) drains HP past a grace window with a grey "rot" telegraph; fixing the need in time **redeems** them (nobody turns).
- **Domino:** each turning shocks morale, so a miserable town chains like a powder keg while a healthy one shrugs off a single loss. (True *proximity* domino — −2 to nearby witnesses — still to refine 🔨.)
- **Shrine redemption** 📋: from depth 30, a turned demon can be captured & cleansed back into a living villager.
- ⏸ Currently behind `GameState.CORRUPTION_ENABLED = false` (testing) — villager HP floors at 1. Flip to reactivate.

---

## 11. Post-game — the Shadow Court

- **The world continues after victory:** the shadow-village functions (shadow villagers work their old jobs), the Ten live on, sieges are over — Despair is dead. The player leads Deepwood as its Monarch. *(Peaceful sandbox; remaining bonds/quests completable.)*
- **The Shadow Monarch class unlocks permanently** (`game_completed`, own save file ✅ wired) — "the most OP class," playable from a fresh run: you, finally unmasked from floor 1.
- **NG+ (📋, framing kept from earlier design):** among the victory spoils is **time-reversal loot** — the world rewinds for a new run but **the player and their gear are immune**: you keep yourself and everything you carry. Clean prestige loop.
- **100% completion** = every villager rescued, every bond quest done, all Ten freed, full skill graph explored, village fully restored, Despair destroyed, Shadow Army raised.
- 🟡 A "true ending" that breaks the NG+ cycle — deliberately TBD (see §12).

---

## 12. OPEN — every remaining decision, in one place

*(Nothing anywhere else in this book is open. When one of these is decided, move it into its section and delete it here.)*

1. **Shadow Monarch class kit** — the actual skill graph for the unlocked class (the 7-stage passive of §6 is canon and separate; Shadow Army is canon as its finale ability — but the playable class tree needs design).
2. **Soul Split Wand quest** — which quest line awards it, and how the game teaches "this is a joke item" without spoiling that it will matter.
3. **Post-game shadow-village depth** — do shadow villagers have any new mechanics (no needs? night-strength?) or work exactly as before? Currently: exactly as before, visually shadow. Decide if that's final.
4. **"True ending" / breaking the NG+ cycle** — deliberately deferred until after the base finale is built.
5. **Numbers pass** — every 📋 system above ships with placeholder-free tuning (wages, potion drop rates, Devourer tier curve, the Ten's boon values). Balancing happens at build time against the endgame-balance curves already in code.

---

## 13. Governance — how this book is used

- **This file is the constitution.** `STORY.md` (narrative prose), `VILLAGE_SYSTEMS.md` (village deep-design), `GAME_OVERVIEW.md` / `PROJECT_SNAPSHOT.md` (implementation snapshots), and `ROADMAP.md` (director's log) remain as *references*, each carrying a banner pointing here. Where they disagree with this book, they are wrong.
- **Change protocol:** developer decides → this book is edited first → then code. A feature not in this book is not in the game.
- **Build order after this book is signed off** stays vertical-slice: finish needs/hospital/wages (§5.5) → Barracks shifts (§7) → Government automation (§5.1) → Shrine + corruption refinements (§10) → economy depth (§5.6) → the Ten (§8) → the Finale (§9) → post-game (§11).
- **Execution guardrails** (from VILLAGE_SYSTEMS §11, still binding): extend existing systems (`game_state.gd` morale, `npc.gd` villagers, `building.gd`), never fork parallel ones; never rewrite the save format (extend additively); headless-verify every change; don't touch dungeon balance or the L100 curves unless the task says so.

*Living document. Last full revision: 2026-07-15.*
