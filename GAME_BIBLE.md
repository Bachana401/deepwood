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

### 2.4.1 The Arrival — the opening sequence (new canon 2026-07-17) 📋

The plea (§2.4) is the first beat. The rest of the arrival, in order, is what teaches the player *where they are and why they can't just leave*:

1. **The three defenders.** Following the taken villager's plea into Deepwood, the player finds **three adventurer NPCs already in active battle** against a wave of the Despair Army. The player fights beside them and helps repel this first wave — the game's first combat, learned in company rather than alone.
2. **The trap explained.** With the wave broken, the three explain their situation: **they have been stuck in Deepwood for weeks.** They cannot leave in any direction — *every attempt to find a path out of the Deepwood makes the Despair Army swell far larger.* The way out is not blocked by a wall; it is guarded by an army that grows to meet anyone who tries. They are trapped, and now so is the player. *(This is the in-fiction answer to "the trail ends at Deepwood": the player is not merely drawn here — they are held here.)*
3. **The failed escape.** Undeterred, the player tries to cut the path out **himself** — and barely survives it, staggering back into the village near death. The lesson lands as gameplay: the exit is not an option yet; the only way out is *through* — down the dungeon, to the root.
4. **The healer.** The player is treated by a **woman tending the three wounded adventurers** — a villager who survived the latest raids, and who was **Deepwood's doctor before it fell.** She heals the player too. *(She is the anchor of the early-game healing mechanic — §5.5a.)*
5. **Her account (the Law of Despair, told by a survivor).** She tells what Deepwood was: **once mighty** — full of skilled, educated, talented people, one of the strongest villages of the age, which endured for *years* even after the Despair cataclysm began. But lately the waves grew monstrous and the village was destroyed **building by building**; the **strong-willed were dragged off as hostages**, the **weak-willed converted** into the very enemy at the gates. This is the Law of Despair (§2.2) delivered diegetically for the first time — and it names, without the player yet knowing it, exactly what the taken (§2.4) and the Ten (§8) are.

**What this sequence establishes:** the trap (why the whole game happens *here*), the stakes, the three defenders as the player's early peers, the Doctor as the early lifeline, and the world's law — all shown, not narrated. *(Character names TBD; not blocking. The three defenders' relationship to Orin is an open reconciliation — §12.)*

### 2.5 Orin — the enemy wearing a hero's face
**Orin** appears as a stranded defender-mage: the last thing standing between Deepwood and the dark, hurling meteors at the nightly horde, dying for the village and rising each dawn. The survivors love him. **You fight beside him for most of the game — but he is NOT there at the start; he enters ~floor 15 (§2.5.1).**

It is a mask. **Orin is the Monarch of Despair.** The horde is his; the "defense" is theater — a slow harvest dressed as heroism. He is genuinely **undying**: struck down, he collapses to an ember and reforms *stronger*, forever (✅ built — his death-escalation loop is intentional and must never be nerfed).

- **Why he lets you live:** he thinks you're nobody — a stray adventurer, beneath killing. If you ever drew on your true power he would recognize a rival monarch and destroy you instantly. *Your disguise is your survival* — this is the in-fiction reason the Shadow Monarch class stays locked all game.
- **Why he can't die:** *an undivided soul cannot be destroyed.* This is the lock on the entire game — and its key.
- **Why he waits (the full truth):** Orin has been **waiting for you to build the village to its maximum.** The tribute, the breathing room between sieges, the survivable nights — all calculated generosity. He wants Deepwood at its peak so that, with one sweep of his hand, he can turn *everything you built* against you. It isn't just harvest. **He wants to play with his food** — to watch the builder's face as the built thing turns. Despair is his nature; manufacturing the *perfect* despair is his art.

### 2.5.1 How Orin enters the game (new canon 2026-07-17) 📋

Orin is **absent from the village at the start.** He is *foreshadowed*, then *arrives*, then *becomes the beloved defender* the rest of the canon describes — a three-step reveal that makes his eventual betrayal land.

1. **The rumour (Act I, from the Doctor).** As the player learns about the dungeon, the Doctor (§2.4.1) tells what she saw: the enemy dragging villagers down into the dungeon as hostages weeks ago. She is sure they are dead — no one has returned. **She mentions a wizard**, too: a stranger who came wanting to save them, went down into the dungeon, and *never came back either.* *(That wizard is Orin. Dramatic irony: she mourns him as another lost hero.)*
2. **The return (~floor 15, after a boss).** The player descends, rescues a few hostages, and around floor 15 — likely **right after a boss** — **Orin appears, whole and unshattered**, as though returning from a long walk. He introduces himself as a **wandering mage** who, after the Despair cataclysm, was searching for a place to live peacefully among people; he'd heard of this famed advanced village of brilliant, talented folk, and came — only to find it near-empty, its people dead or taken. He says he **tried to save them himself**: he was down in the dungeon fighting, **cleared one of the levels, then got stuck — and that's why he's back now.** *(Every word is a lie shaped to mirror the player's own arrival.)*
3. **The introductions & the pact.** The Doctor introduces the player and the three defenders to Orin (she and Orin had met **3–4 days earlier**). Now everyone lays out their intentions: they all chased the **same rumour** of a safe, advanced haven; with the world all but destroyed, the only way to earn that safety is to **rescue the taken and outlast the evil** using the village's advanced technology and its brilliant people. Everyone commits to the same plan — **rebuild Deepwood, free its people, grow strong.** From here, Orin takes up the nightly defense and becomes the hero of §2.5.

**Starting NPC roster (Act I):** the player begins with **6 NPCs** — the **3 heroes** met on arrival (the village's defending unit), **1 Doctor** (the healer, §5.5a), and **2 Farmers** (first food). Everyone else is dead or a hostage to be rescued. *(Orin is not a village NPC in the roster sense — he is the defender/story figure who joins at ~L15.)*
The story is *earned* through the loop, not told in cutscenes: descend → free them → rebuild → grow strong → the siege tightens. The village growing brighter and the nights growing worse are **the same story told from both ends.** (The act-by-act player experience is §3; the finale is §9.)

### 2.7 How it ends (summary — full beat-by-beat in §9)
At the gates of Level 100 the mask falls: the dungeon kneels to Orin, and something in your sealed memory *flashes* — you have lost to this power before. Then **the Harvest**: the revelation itself is the weapon — the savior they loved was the devil all along, and that betrayal, driven home by Orin's magic, shatters the whole village's hope to 0 in a single breath; everyone you saved falls to despair and transforms into his army — except **the Ten** (§8), the truly unbreakable, who stand with you. Orin devours the transformed to grow into a titan; you race to deny him fuel; and you kill the unkillable by **dividing his soul** and striking while it's scattered. Victory breaks your seal: memory, throne, true form return — and your first royal act is **Shadow Army**: you raise every fallen villager as a shadow, and the village *continues*, alive in a new way, yours to lead. One Monarch is destroyed. Somewhere beyond, the Monarch of War still waits. *(Another story. A future game.)*

---

## 3. The Player's Responsibility — the whole game, act by act

What the player is actually *doing and worrying about* at every stage. This is the spine the content hangs on.

### Act I — The Ashes (dungeon floors ~1–15)
- **The arrival** (§2.4.1): the plea → fighting beside the three trapped defenders → learning you *can't leave* → the failed escape → the Doctor heals you and tells you what Deepwood was. This is the tutorial-as-story.
- **Survive.** Weak start: basic weapon, no gold, gated skills, empty ruined village (✅ honest-start mode is the default; the old sandbox lives behind `--dev`).
- **Learn the loop:** enter the dungeon, clear floors, take the first boss (floor 5), carry loot home.
- **First rescues** (Elin, Milo, early taken) and **first repairs** — done poor: every coin hurts.
- **Healing is the Doctor** (§5.5a): scarce, escalating in cost, and *losable* — every avoidable wound bleeds your economy, and she can die.
- **Sieges are pure chaos** (§7.1): no warning, random timing and size, until you can afford the Watchtower.
- **Everything is manual:** you hand-feed villagers, hand-assign the first workers, hammer walls yourself.
- **Responsibility:** keep a handful of people alive with your own hands.

### Act II — The Rebuilding (floors ~15–50)
- **Orin arrives** (~floor 15, after a boss — §2.5.1): the "wandering mage" cover story; from here he takes up the nightly defense and becomes the hero the survivors love.
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
- **Rescues inside the dungeon** ✅ v1 / 📋 reworked below: 19 leadership VIPs freed at bosses 5–95, + the earlier deep figures. **The Ten (§8) are separate and deeper.**

### 4.2a The Rescue — the Sorrow-Crystals 📋 (new canon 2026-07-17)

*How a taken person is actually freed — the mechanic behind Pillar #2 and the fuel for the whole village flywheel (§5.7 chain E).*

- **The taken are frozen, bound to a crystal.** Each hostage stands frozen mid-motion (§2.4), shackled to a **Sorrow-Crystal** (name TBD) — an artifact actively **draining their hope.** This is the *physical mechanism* of §2.2: the crystal is how Orin force-feeds despair to the unbroken for years, patiently trying to crack them. While it drains, the person is neither alive nor dead.
- **You free them by destroying the crystal — after clearing its guard.** The crystal is protected; you must clear that pocket / floor (regular hostages behind a small encounter on ordinary floors; leadership VIPs at boss floors; the **Ten** in Trophy Vaults, §8). Break the crystal and the drain stops — the breaking is *interrupted*, the person thaws.
- **Shattering it pays out three things at once:**
  1. **The freed NPC** — now yours to bring home.
  2. **An important material** — the crystallized despair/hope left behind, a genuinely valuable resource (material identity + use TBD — a premium crafting/upgrade/Shrine input).
  3. *(implicitly)* a light back on: the reveal below.
- **Stats are HIDDEN until they're home.** A frozen hostage shows **nothing** — you cannot see their profession stats until they thaw in the village. Every rescue is a wrapped gift: you might have freed a statless nobody, a rare 4–5-stat prodigy, or a rescued **leader** (the only source of leadership roles, §5.3). The rescue *gamble* mirrors the School role-roll (§5.4) — luck is woven through the whole village economy.
- **Getting them home — Orin "helps" (proposed):** once introduced (~L15, §2.5.1), **Orin teleports each freed hostage back to the village.** The dramatic irony is the point: the one who *took* them cheerfully returns your rescues — because he means to harvest the whole village at the peak (§2.5, "he wants you to build it so it hurts"). *Pre-L15 (before Orin), the crystal's shattering itself banishes them home (its own magic reversed), or they walk out with you — flag the early handling.*
- 🟡 Open (§12): the crystal's name; the "important material" identity + what it's for; regular-hostage frequency/placement; whether Orin-teleport is canon or the crystal self-returns; how a rescued **leader** surfaces (since leadership can't be schooled).

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

### 5.2 The building roster (16) — status mixed ✅/🔨/📋
| Building | Serves | Falls → breaks |
|---|---|---|
| **School** (keystone) | skilled workforce — teaches stats (the role roll §5.4) | the whole automation web unravels |
| **Farm** | food #1 | starvation |
| **Fishing Dock** | food #2 — **premium food** (more morale, sates longer than Farm) | no backup food; the morale/longevity food edge lost |
| **Hospital** | healing + births | wounds kill; no new children |
| **Barracks** | defense — day/night shifts (§7.5) | every siege is on the player |
| **Mine** 📋 (new 2026-07-17) | ore/metal + stone — the delegated form of hand-mining | Blacksmith & Builderhouse starve for raw materials |
| **Blacksmith** | arms & tools + the depth-35 Forge; **arms the Barracks** (§5.7) | weak defense, slow workers |
| **Builderhouse** | repair/construction | rebuild everything by hand |
| **Science Lab** | research (materials, upgrades) | no progression |
| **Marketplace** | trade — production → gold | can't pay wages |
| **Bank** | treasury, interest, payroll | gold vulnerable, no interest |
| **Government** | the management brain; global automation scaler | back to manual chores |
| **Tavern** (inn) | lodging — newcomers arrive here until housed | newcomers have nowhere to be |
| **Bar** | drink, music, fun → morale | despair comes faster |
| **Shrine** 📋 | *redemption* — capture & cleanse a transformed demon back into a villager; unlocks at depth 30 | despair is always a death sentence |
| **Watchtower** 📋 (§7.1) | siege foresight (none → 1h → 2h → 24h warning) | you never know when the wave hits |

All buildings start **visually destroyed** and non-functional; repair costs gold + materials in stages (✅ built, incl. siege damage/repair). **How they interlock into one system is §5.7.**

### 5.3 Professions ✅ decided
One profession stat per building (Farmer, Fisher, Doctor/Nurse, Smith, Builder, **Miner**, Scholar, Merchant, Banker, Official, Teacher, Innkeeper, Barkeep) + **Warrior** (Barracks — deletes all other stats, permanent, one-way sacrifice). Leadership roles (Leader / Principal / Warchief) can **never** be taught — only rescued hostages who already carry them qualify. Leader bonuses (+15% class-appropriate boosts) ✅.

### 5.4 Villager stats & the school pipeline — the role roll ✅ decided (model revised 2026-07-17) / 🔨 partial
- Every NPC carries **0–5 profession stats** (1 common → 5 extremely rare). **1 stat = employable + safe from depression.** Extra stats = pure versatility.
- **The role roll (revised 2026-07-17):** a graduating child — and any statless NPC put through School — does **not pick** their profession. They **roll one from a weighted table.** Weight is **inverse to the role's value/difficulty:** low-skill, low-stakes roles that mostly serve food / fun / morale (**Farmer, Fisher, Barkeep, Innkeeper**) are **common**; skilled, high-leverage roles (**Banker, Scholar, Doctor/Nurse, Official, Teacher, Smith, Merchant, Builder**) are **rare**. Leadership (Leader / Principal / Warchief) is **never on the table** — rescued only (§5.3). *Rationale: anyone can tend a field; a banker or a scholar is a rare mind. Scarcity makes the valuable roles feel valuable and keeps rescued VIPs precious.*
- **The consequence — luck + volume:** to staff the rare roles you must **produce and school many children** and accept the odds. This is the engine that gives the cottage → child → school lifecycle a real *economy*: population growth is how you eventually fill the Bank, the Lab, the Hospital. A run is partly a numbers game of "keep the cradles full."
- **Statless NPCs** slowly become depressed → fix via School (roll a role) or Barracks (become a Warrior).
- **Re-education, up to 3 total:** each re-schooling grants one **new** profession (no repeats), **rolled the same weighted way**; 2nd stat 5× time, 3rd stat 10× time; **hard cap 3 via School.** So an NPC is up to three weighted rolls — more shots at a rare role, at growing time cost. Natural 4–5-stat *rescues* stay elite finds.
- **Rescues bypass the roll:** rescued villagers arrive with their **real** professions intact — the only *guaranteed* source of rare and leadership roles. This is a major reason rescuing (and the Ten, §8) matters.
- **School weight-tuning — a *progressive* mid-game payoff (📋):** early game you live with the dice (no adjustment). **Each School upgrade grants incrementally more room to hand-adjust the role weights** — a little comfort at first, growing as you invest, until a **fully-upgraded School gives a large but still-capped bias.** The cap is the whole point: **never 100%.** Even maxed, the player might push a chosen role to something like **~40%** (illustrative — balance later) — huge, but not a guarantee, so RNG never fully leaves and the player still **picks which role to favour based on what the village needs right now.** Steerable RNG as a mastery reward (§5.1 automation spirit) and the pressure-valve for the luck economy. *(A mid-game feature that keeps deepening, not a single unlock.)*
- **Lifecycle pipeline:** pair at cottage → ~25h → child → enroll → ~24h → adult who **rolls a stat** → employ. Manual early (deliberately tedious); **Government automates the whole chain** (kids self-route to school → straight to a job).
- **Villager bonds** ✅: per-villager personal quests (gather/slay/reach-level/reunite) that reveal a hidden stat + reward + 1.5× income from that villager.
- 🟡 Open (§12): the default weight table; whether re-education stays weighted-random or may *target* a role at higher cost; the weight-tuning budget/cap; any pity/floor to soften rare-role droughts.

### 5.5 Needs ✅ decided / 🔨 partially built
| Need | Filled by | Empty → | Status |
|---|---|---|---|
| **Hunger** | Farm/Dock visible food (walk-up eating) | morale drop → death in ~2–3 days | ✅ v1 |
| **Health** | Hospital nurses (roaming, ranged heals); player heals there for gold | wounds/illness kill | 📋 |
| **Wages** | player income; manual early, Bank/Govt later | workers quit → services stop | 📋 |
| **Mood** | Bar / village fun | low mood | 📋 later |
| **Mating-depression** | cottage pairing | long-single villagers sadden | 📋 later |

**Potions rule** 📋: HP/mana potions drop **only** from pre-boss waves and boss fights — the player enters every boss stocked, and can't potion-spam normal floors.

### 5.5a The Doctor — the early-game lifeline 📋 (new canon 2026-07-17)

Before the Hospital is repaired and staffed (§5.2), the player's *only* reliable healing is **the Doctor** — the raid-survivor who healed the player on arrival (§2.4.1). She bridges story and system: she is the first Doctor/Nurse, working out of the ruined Hospital, and the game's answer to "no passive HP regen" (§4.1) in Act I.

- **Escalating heal cost.** The **first heal each in-game day is cheap** (or free); **each additional heal the same day costs steeply more**, and the price **slowly resets** over time back toward the base. She is a lifeline, not a fountain — you cannot afford to make many mistakes, and every avoidable wound is a real drain on your economy. This is the early-game tension the potion rule enforces later.
- **She can die.** She is a mortal villager in a besieged town — a siege that reaches her, or neglect that lets it, can **kill her.** Losing her means losing your only healer until the Hospital is properly staffed: a serious, felt setback, not a soft reset.
- **Replacing her (the stakes with an out).** If she dies, the *only* path back to a healer runs through the village lifecycle (§5.4): pair villagers → child → School → if the child rolls the **Doctor** stat → employ them at the Hospital. It is slow, luck-touched, and exactly the kind of hard recovery the game is about — you can come back from her death, but you will *feel* it.
- **Design intent:** healing is scarce, personal, and losable in Act I; the player learns early that people are infrastructure and mistakes cost. It also plants the Hospital's importance long before it's rebuilt.
- 🟡 Open (§12): exact cost curve + daily reset rate; whether the "first heal free vs cheap" and how her death is triggered (siege reach vs a neglect timer).

### 5.6 Economy — gold has exactly two makers (revised 2026-07-17) 📋

**The rule:** **only the Government and the Bank generate gold.** Every other building produces **goods and services, not money** — Farm makes food, Mine makes ore, Blacksmith makes arms, School makes skilled hands. The **Bar** is the one small exception: patrons pay for drinks, so it trickles a *little* gold on the side. *(This changes current code, which pays passive per-worker gold from every staffed role — that is removed; buildings now pay out in their own resource, not coin.)*

**The gold faucets:**
- **The dungeon** — the player's own income: enemy gold + boss/loot. **This is the primary faucet, especially early** — you fund the village from your delving, which is exactly why Act I's "every coin hurts."
- **Government — taxes.** A passive gold income scaled by the village's **size × prosperity** (employment + morale): a working village generates taxable wealth, and the Government skims it. This is the village's own gold engine, and it *grows as the village grows.*
- **Bank — interest + payroll + insurance.** Grows stored gold (interest), **pays the wages** out of the treasury, and insures a share of the gold you'd drop on death (Dorian, §8).
- **Bar — a small trickle** (drink sales). Minor, flavour-scaled.

**The loop:** dungeon gold + taxes + interest → **treasury** → Bank pays **wages** → workers keep buildings running → buildings produce the goods/services that keep the village prosperous → Government taxes that prosperity → more gold. **Early you subsidize the village from the dungeon; as Government + Bank scale, it approaches self-funding.** The dungeon is the faucet; the village is the multiplier.

- Morale meter ✅ (unlocks once every building has been repaired). Leader bonuses / tribute / morale rewards still apply.
- 🟡 Open (§12): exact tax / interest / wage numbers. *(The Marketplace question is now answered — §5.6a.)*

### 5.6a The Marketplace — the Wanderer's Post 📋 (new canon 2026-07-17)

The Marketplace makes **no gold**. It is the town's **guest-stall**: a stop for **wandering treasure-sellers** who drift in, set up, and sell **random loot** — and how well they treat you is a *direct function of how nice your village is to be in.* This is what turns morale from a defensive stat into an **economic lever.**

- **One seller at a time.** A wanderer arrives with a **random stock** (gear, materials, consumables, the occasional rare find) at set starting prices.
- **Hospitality decides the visit** — driven by **morale** (the 0–10 meter), plus being **fed** and **decorations / ambience**:
  - **High morale (~5–7+):** the seller likes it here — **stays the full ~24 in-game hours** and **slowly marks prices DOWN across the stay.** The happier the town, the longer they linger and the cheaper it gets the longer you wait.
  - **Low-ish morale:** prices **hold flat** and the seller **cuts the visit short** (~12h, scaling down with morale) — a gloomy town gets a quick, full-price visit and an early goodbye.
- **Rotation & escalation:** after one leaves, **the next arrives at a random later time**, and successive wanderers trend toward **better / rarer stock — but at a higher starting price** (which your morale-discount then eats into). A well-run village gradually attracts *better merchants with better loot*, and its hospitality is what makes their prices affordable.
- **Purely a gold SINK** (you spend to buy) — consistent with §5.6's "only Gov + Bank make gold." Its deeper role: the Bar, Tavern, food, and decorations you keep up for corruption-defense (§10) *also* buy you cheaper, rarer loot here. One more strand tying the web together.
- 🟡 Open (§12): the exact morale → (dwell-time, discount) curve; the loot tables + escalation; whether a **Merchant** staffer improves wanderer frequency/quality/haggling (recommendation: yes — gives the Merchant profession its purpose); whether "**decorations**" are a real sub-system or just fold into morale.

### 5.7 The Building Web — one connected system (new canon 2026-07-17) 📋

The village is **not a menu of independent buildings** — it is one machine whose parts feed each other, and the whole point is that *the connections become mandatory exactly when the difficulty demands them.*

**The core principle — independent early, interdependent under pressure.** Every building is **self-sufficient at low difficulty** and only *needs* the others as the pressure (deeper floors, bigger sieges, more mouths) rises. The Barracks example the dev gave is the template: early, the Barracks spawns warriors who fight waves *on their own*, fists and basic gear enough. As waves get stronger, that stops being enough — now the Barracks **needs the Blacksmith** to forge better weapons; the Blacksmith **needs metal**, which **needs the Mine**; the Mine needs a **Miner**, who came from the **School**, who is fed by the **Farm**, housed by the **Tavern**, kept sane by the **Bar**… Pull any link and the chain downstream weakens. That cascade *is* the game.

#### The resource types (what flows through the web)
| Resource | Made by | Consumed by |
|---|---|---|
| **Food** | Farm, Fishing Dock | every villager (starve → morale → §10) |
| **Construction** (wood/stone/resin) | gathering + **Mine** (stone) | Builderhouse (repairs, walls) |
| **Ore/metal** 📋 | **Mine** | Blacksmith (arms & tools) |
| **Skill materials** (slime→ancient_relic) | dungeon only | Science Lab research → the player's skill tree |
| **Gold** | **only** the dungeon (player loot), Government (taxes), Bank (interest), + a Bar trickle | wages, purchases, repairs |
| **Knowledge** (profession stats) | School (role roll §5.4) | staffs *every* building |
| **Morale / hope** | Bar, Tavern, food, housing | the fuel that stops villagers corrupting (§10) |
| **Defense** | Barracks warriors + walls | survives sieges (§7) |

#### The chains (the "one connected system")
- **A — The War Machine (the dev's example):** **Mine → ore → Blacksmith → forged weapons → Barracks → stronger warriors → survive harder sieges.** Support links: **Hospital** heals wounded warriors between shifts (§7); **Builderhouse** rebuilds walls after each siege; **Watchtower** (§7.1) tells you when the next one lands. When waves outscale bare warriors, this whole chain is what keeps the walls standing — and every link is a building that must be staffed, supplied, and paid.
- **B — The Population Engine:** **Food + Housing (Tavern) + Morale (Bar) keep people alive and un-corrupted → cottage pairing → child → School (role roll) → employed → staffs the buildings → more production.** This is the flywheel that fills the village; §5.4 is its heart.
- **C — The Money Loop (revised, §5.6):** **dungeon loot + Government taxes + Bank interest → treasury → Bank pays wages → workers keep buildings producing → a prosperous village is more taxable → more gold.** Gold is made by **only** the Government and the Bank (plus a Bar trickle and the player's dungeon income) — no other building prints money; they pay out in *their own resource.* No gold → workers quit → services stop → the other chains stall. Early the dungeon subsidizes the village; late, taxes + interest make it self-funding.
- **D — The Player-Power Loop:** **dungeon → skill materials + loot → Science Lab research → skill tree; Blacksmith gear → stronger player → deeper dungeon → more rescues + rarer materials.** The village makes the player; the player feeds the village.
- **E — The Rescue Flywheel (the chain reaction the dev described):** **rescue an NPC (regular ones often; an MVP/Ten every few bosses, §8) → house them (Tavern) → employ or School them → they produce → they pair → kid → School → employ → …** Each rescue is one more pair of hands, and hands compound. This is how a dead village becomes a full one.
- **F — The Corruption Cascade (the anti-flywheel — §10):** neglect one need and the flywheel **runs in reverse** — see §10 for the full chain-reaction rule. A neglected village *eats itself*.

#### Per-building purpose, inputs → outputs, and the dependency that bites
| Building | Purpose (what it's FOR) | Needs (in) | Feeds (out) | The dependency that bites under pressure |
|---|---|---|---|---|
| **Farm** | food #1 | Farmer | Food → everyone | more mouths (rescues, births) demand more Farmers/Sylvara (§8) |
| **Fishing Dock** | food #2 — **premium food** (fish gives more morale on eating and sates *longer* than Farm food); deep-catch → (Kaldos) materials | Fisher | premium food, morale, materials | backup food security + the quality-food edge is lost without it |
| **Mine** 📋 | raw ore/metal + stone | Miner | Blacksmith (metal), Builderhouse (stone) | **Blacksmith & repairs stall without it** once you stop hand-mining |
| **Blacksmith** | forge/upgrade **warrior weapons**, player gear (depth-35 Forge), gathering tools | Smith + **ore (Mine)** | Barracks arms, player gear, tools | **Barracks can't out-arm scaling waves without it**; it can't run without Mine metal |
| **Barracks** | train Warriors → fight waves + man walls | villagers → Warrior | Defense | self-sufficient early; **needs Blacksmith weapons** as waves scale; **needs Hospital** to recover the wounded |
| **Hospital** | heal wounded warriors + player (§5.5a) + births | Doctor/Nurse | fighting-fit warriors, player HP, new children | every siege leaves wounded who **don't recover without it** (no passive regen, §4.1) |
| **Builderhouse** | repair/build (incl. walls) | Builder + **construction mats** | standing buildings & walls | sieges break walls faster than you can hand-repair |
| **School** (keystone) | teach stats — the role roll (§5.4) | Teacher | the workforce for **every** building | if it falls, **nothing else can be staffed** long-term |
| **Science Lab** | research materials + building upgrades | Scholar | skill-tree access, upgrades (incl. School weight-tuning §5.4) | progression **freezes** without it |
| **Marketplace** 📋 | *(§5.6a)* the **Wanderer's Post** — hosts rotating treasure-sellers; **morale sets their prices & how long they stay.** No passive gold. | Merchant (haggling/quality) | a gold *sink*; better loot the nicer your town | without it, no wandering merchants, no loot market |
| **Bank** | **one of only two gold makers** — treasury, **interest**, payroll (pays wages), death-insurance | Banker | gold, wage automation, safe treasury | the Money Loop (C) has no payroll or growth without it |
| **Government** | **the other gold maker** — **taxes** village prosperity — AND the management brain that scales **automation** of the player's chores | Official + a rescued **Leader** | gold (taxes) + less micro across *all* systems | no passive village income, and the grown village drowns you in manual tasks |
| **Tavern** (inn) | housing — rescued/newcomers live here until homed | Innkeeper | housing → morale floor | **unhoused villagers lose morale → corruption risk (§10)** |
| **Bar** | drink/music/fun → morale (+ a **small gold trickle** from drink sales) | Barkeep | morale buffer (hope) + minor gold | the morale cushion that makes the Cascade (F) *survivable* |
| **Shrine** 📋 | cleanse a corrupted demon back to a villager (depth 30) | (Seraphel §8 boosts) | recovered villagers | before it, every corruption is a permanent loss |
| **Watchtower** 📋 | siege foresight (§7.1) | build + upgrades | warning time → planning | without it, defense is pure reaction |

**Government is the meta-connector:** it doesn't make a resource — it **automates the links** so the player isn't hand-carrying every hand-off (kids auto-route School→job, wall shifts auto-fill, taxes auto-collect). Early game you *are* the connective tissue, by hand; Government is how you earn your way out of that.

#### 5.7.1 The dependency-activation ladder — *when* each link switches on

The web's pacing spine. Every dependency is **dormant until a pressure crosses a threshold**, then it *bites*. The three pressures that turn links on: **DEPTH** (how deep the player has pushed — sets siege strength & material tiers), **POP** (how many mouths the village holds), **NEGLECT** (unmet needs). This is the schedule that makes §5.7 a *curve* instead of a switch — structure now, exact thresholds are a balance-later numbers pass (§12 #10).

| Link that switches on | Trigger (the pressure) | ≈ Act / band | If ignored |
|---|---|---|---|
| Farm alone → **+ Fishing Dock** | POP outgrows single-Farm output | II | hunger → morale → corruption |
| Barracks → **needs Hospital** | first siege that leaves warriors wounded (no passive regen §4.1) | I→II | the warrior pool bleeds out permanently |
| Builderhouse becomes **mandatory** | sieges break walls faster than you hand-repair | II | walls stay down, every siege hits the village |
| Barracks → **needs Blacksmith arms** | DEPTH: siege strength passes what basic-gear warriors can kill | II (mid) | warriors lose the wall, defense collapses onto the player |
| Blacksmith → **needs Mine metal** | you lean on the Blacksmith faster than hand-mining can supply | II (mid, right after the above) | Blacksmith idles → Barracks stops improving |
| Hand-pay → **needs Marketplace + Bank** | POP employed grows past what player gold can hand-pay | II→III | wages dry up → workers quit → cascade |
| Pre-stat'd staff → **needs School flow** | you run out of already-skilled villagers to fill new buildings | I→II (and forever) | new buildings can't be staffed |
| Skill tier 3+ / upgrades → **need Science Lab** | player hits tier-3 skills or wants building upgrades | II | progression freezes |
| Corruption is permanent → **Shrine** softens it | DEPTH 30 | II | every morale-0 loss is forever until then |
| Manual chores → **Government automation** | village complexity (buildings × villagers) overwhelms hand-management | III | the grown village drowns the player in micro |
| Blind defense → **Watchtower foresight** | player wants to plan runs around sieges (QoL, never hard-required) | II+ | defense stays pure reaction |

**Reading the ladder:** Act I is almost all independent/DIY — the only early links are Hospital (first wounded) and School (first restaffing). The web *activates through Act II*, in a deliberate order: **defense chain first** (Blacksmith→Mine, because that's the pressure the player feels most sharply — the wall), then the **money chain** (Marketplace/Bank as the payroll grows), then the **Shrine** at depth 30. Act III is total interdependence, and **Government automation is the reward** that keeps a fully-chained village from becoming unplayable micro. The Ten (§8) don't add links — each one *supercharges an existing one* (Brannoc the Barracks, Toren the Blacksmith, Sylvara the Farm…), so rescuing them is how you keep the ladder ahead of the pressure.

- 🟡 Open (§12): the exact ore/metal resource ids and whether Mine ore is a new item or reuses stone + a metal tier; the precise threshold **numbers** on this ladder (which floor/pop/siege-tier each link fires at); whether the Mine is hand-buildable from Act I or gated; Shrine staffing role.

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

- **Sieges** scale in size with village health — a *living* village is an insult to the Monarch of Despair; prosperity literally raises the pressure (the squeeze is the design, not a bug).

### 7.1 The Watchtower — earning foresight (new canon 2026-07-17) 📋

The siege *schedule* is not given to the player — it is **earned.**

- **Act I: true chaos.** Early on there is **no wave indicator at all** — sieges hit at **genuinely random times and in random amounts.** You cannot plan; you can only stay ready. This is the intended early-game dread: you never know when, or how bad.
- **Build the Watchtower** (turret / lookout — name TBD, dev doesn't mind) from gathered loot, resources, and items → you unlock **exact wave times and dates**, with a **~1 in-game hour warning** before each incoming wave. Chaos becomes something you can brace for.
- **Upgrade it → 2-hour warning.** **Upgrade again → a full 24-hour warning** — you can now schedule your dungeon runs around known siege windows, the Act III "can't be everywhere" squeeze (§3) becomes a *planned* juggling act instead of a gamble.
- **Design intent:** foresight is a reward, not a default. The progression turns defense from "react to chaos" → "manage a schedule," pacing the player's growing mastery. It also gives the day/night Barracks-shift system (§7 above) something concrete to plan against.
- 🟡 Open (§12): is the Watchtower a **15th building** in the §5.2 roster, or a standalone defensive structure? Warning tiers are locked (none → 1h → 2h → 24h); its build/upgrade costs are a numbers-pass item.
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

- Transformation **only at morale 0**; neglect (hunger, homelessness, no joy) drains HP/morale past a grace window with a grey "rot" telegraph; fixing the need in time **redeems** them (nobody turns).
- **What it turns INTO:** a villager at morale 0 becomes a **random non-boss evil** of the same kind the dungeon spawns, now loose *inside the walls* and attacking the village.
- **The chain reaction — proximity infection (refined 2026-07-17):** a fresh turning doesn't just shock morale globally — it **infects nearby villagers by their own morale state.** A neighbour whose morale is **already low** is dragged to 0 and **turns too** — which infects *their* neighbours — a spreading powder-keg cascade. A neighbour with **healthy morale resists** and does **not** turn, *unless something else is also draining them* (hunger, no home, no joy) — then the nearby turning is the push that finishes the job. So corruption spreads fastest exactly where the village is already neglected, and a well-fed, housed, entertained town **firewalls** it: healthy neighbours are the breakers that stop the chain. **This is why the player is forced to keep the whole village cared for — neglect anywhere lets the town eat itself and undo your progress.** (The finale §9.3 is this same cascade with the morale floor kicked out from under *everyone* at once.)
- 🟡 Open (§12): exact infection radius, the morale threshold that counts as "already low," and the per-tick spread rate — numbers-pass; the mechanic shape is decided.
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
5. **Numbers pass** — every 📋 system above ships with placeholder-free tuning (wages, potion drop rates, Devourer tier curve, the Ten's boon values, the Doctor's heal-cost curve §5.5a, Watchtower costs §7.1). Balancing happens at build time against the endgame-balance curves already in code.
6. **The three defenders' fate** — RESOLVED that they are separate mortal heroes (starting defenders), and Orin is absent until ~L15 (§2.5.1). Residual: **what happens to the three at the Harvest (§9.3)?** As mortal villagers their hope breaks like everyone's — the three heroes you started the game beside turning against you would be a gut-punch — *unless* one earns a place among the Ten (§8) or is written a special fate. Decide when the finale roster is finalized.
7. **"Leaving Deepwood"** (§2.4.1) — is the escalating exit-army purely narrative (a scripted failed escape), or an actually attemptable action the player can retry (an optional escalating gauntlet at the map edge that is never worth it until the endgame)? Decide before building the opening.
8. **The Doctor & the three defenders — names.** Minor; not blocking. Give the Doctor a name when the opening dialogue is written.
9. **Role-roll numbers (§5.4)** — MECHANIC shape is decided (weighted roll; progressive School weight-tuning that maxes at a large-but-capped bias, never 100%); only NUMBERS remain, balanced later: the default weighted table (food/fun common, economic/skilled rare, leadership never); the per-upgrade adjustment amounts and the final single-role cap (~40% is the working sketch); whether re-education is pure weighted-random or can *target* a role at a steep cost premium (recommendation: first-graduation random for the luck loop, targeted re-ed as the reliable-but-expensive path); whether a pity/floor softens long rare-role droughts.
10. **The Building Web wiring (§5.7)** — MECHANIC shape decided (independent early → interdependent under pressure; the chains and per-building purposes are canon). Open: the exact **ore/metal resource ids** (new item vs reuse stone + a metal tier), the **depth/pressure point each dependency "switches on"** (when bare warriors stop sufficing and the Barracks *needs* Blacksmith arms, etc.), whether the **Mine** is hand-buildable from Act I or gated, and the **Shrine's staffing role**.
11. **Corruption cascade numbers (§10)** — MECHANIC shape decided (proximity infection gated by each neighbour's morale). Open: infection radius, the "already low" morale threshold, spread rate per tick. Numbers-pass; re-enable behind `CORRUPTION_ENABLED` when tuned.
12. **Economy revision fallout (§5.6)** — DECIDED: gold is made by only Government (taxes) + Bank (interest) + a Bar trickle + the dungeon; per-building passive gold is removed (a code change). **Marketplace = the Wanderer's Post** (§5.6a); **Fishing Dock kept distinct as premium food** (§5.7). Remaining open: the Wanderer's Post morale→(dwell,discount) curve + loot tables + Merchant-staff effect; whether "**decorations**" is a real morale sub-system or folds into morale; exact tax/interest/wage/food numbers. All numbers-pass; the mechanics are decided.

### Gaps found in the village/NPC gap-audit (2026-07-17) — need a decision before building the village loop
13. **HOUSING — the biggest structural hole.** "Unhoused" is already a corruption driver (§2.2) and the Tavern only *temporarily* lodges newcomers "until housed" — but **nothing in the roster provides permanent housing**, there is no housing-capacity → population cap, and **cottages** (where pairing/mating happens, §5.4) aren't a defined structure. Decide: is there a **House/Cottage** building (or placeable) that villagers permanently live in; does housing capacity cap population; does "no home" feed the corruption drain? *(Recommendation: yes to all three — housing capacity as a soft population cap is the natural brake on the rescue/birth flywheel, and it makes the Builderhouse matter even more.)*
14. **MORALE MODEL — per-villager vs village-wide is used inconsistently.** Corruption (§10) reads **per-villager** morale ("a villager whose morale hits 0"); the Wanderer's Post (§5.6a), the morale meter (§5.6), and the finale gate "10/10 morale" (§9.1) read a **village-wide** value. These are never reconciled. Decide the model. *(Recommendation: BOTH — each NPC has personal morale that drives their own corruption; the village meter is the aggregate/average that drives shopping, the gate, and villager reaction lines. Define how personal feeds aggregate and vice-versa.)*
15. **THE VILLAGER INTERACTION VERBS — never enumerated in one place.** What exactly can the player *do* to/with an NPC? (assign to a building, send to School, draft to Barracks, pair at a cottage, feed, heal, start/turn-in a bond quest, dismiss?). Needs a single canonical list so the interaction UI has a spec.
16. **VILLAGER DEATH handling.** Starvation/siege death vs corruption-then-killed are different deaths with no defined outcome: does a body remain, does the death shock nearby morale (feeding the cascade §10), is the loss permanent, does the death penalty (§4.1) interact? Define what a dead villager *does* to the village.
17. **WARRIORS & CHILDREN as villagers.** Do Barracks Warriors still eat / need housing / risk corruption while on duty (or are they exempt)? Do children consume food + housing, and can a child corrupt at morale 0 (the finale §9.3 implies yes — "children you raised" turn)? Their participation in the needs/corruption systems is undefined.

---

## 13. Governance — how this book is used

- **This file is the constitution.** `STORY.md` (narrative prose), `VILLAGE_SYSTEMS.md` (village deep-design), `GAME_OVERVIEW.md` / `PROJECT_SNAPSHOT.md` (implementation snapshots), and `ROADMAP.md` (director's log) remain as *references*, each carrying a banner pointing here. Where they disagree with this book, they are wrong.
- **Change protocol:** developer decides → this book is edited first → then code. A feature not in this book is not in the game.
- **Build order after this book is signed off** stays vertical-slice: finish needs/hospital/wages (§5.5) → Barracks shifts (§7) → Government automation (§5.1) → Shrine + corruption refinements (§10) → economy depth (§5.6) → the Ten (§8) → the Finale (§9) → post-game (§11).
- **Execution guardrails** (from VILLAGE_SYSTEMS §11, still binding): extend existing systems (`game_state.gd` morale, `npc.gd` villagers, `building.gd`), never fork parallel ones; never rewrite the save format (extend additively); headless-verify every change; don't touch dungeon balance or the L100 curves unless the task says so.

*Living document. Last full revision: 2026-07-15. Amended 2026-07-17: the arrival/opening sequence (§2.4.1), Orin's three-step introduction at ~L15 + starting NPC roster (§2.5.1), the Doctor early-healing mechanic (§5.5a), the Watchtower wave-warning progression (§7.1), and the School "role roll" — weighted-random professions with late-game weight-tuning (§5.4); the Building Web — every building's purpose + the dependency chains as one connected system, plus the new **Mine** (§5.7, roster now 16); and the corruption **proximity chain-reaction** (§10); the dependency-activation ladder (§5.7.1); and the **economy revision** — only Government + Bank (+ a Bar trickle + the dungeon) make gold, no per-building passive income, Marketplace repurposed as the **Wanderer's Post** — morale-priced rotating treasure-sellers (§5.6a) — and the Fishing Dock kept as premium food (§5.6); the **Rescue / Sorrow-Crystal** mechanic (§4.2a); and a **village/NPC gap-audit** logging 5 holes to resolve before building the village loop — housing, the morale model, the interaction verbs, villager death, and warrior/child status (§12 #13–17); art/PixelLab frozen until the mechanical + story side is finished (dev directive).*
