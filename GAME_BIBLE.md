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
- **No UNCONDITIONAL passive HP regeneration** for anyone — player or villager — except via relics/items and the earned high-morale village mend (§4.1).
- **The protagonist stays blank.** No fixed name, face, history, or voice. Players self-insert. Never write dialogue that gives him a past (his past is the *secret* — see §2).

---

## 2. The Story — full canon

### 2.1 The Age of Monarchs (deep backstory)
Before Deepwood, three great powers ruled — the **Monarchs**:
- The **Monarch of Despair** — who unmakes the living, leaving them neither alive nor dead.
- The **Monarch of War** — whose domain now lies in another realm. *(Sequel hook. Never on screen.)*
- The **Shadow Monarch** — a power of shadow and death, equal to the other two. **This is the player.**

> **Naming note (decided 2026-07-17): "Monarch" is deliberately KEPT** — considered vs Solo Leveling and retained. Reasons: (1) the whole Monarch layer is *hidden* — it surfaces only mid/late (the reveal §9), and the player's own **Shadow Monarch** identity is an **endgame-only** reveal, so the term never fronts the early theme; (2) **"Monarch of Despair" is original to Deepwood** (Solo Leveling's Monarchs are Destruction/Frost/Beasts/Plagues/etc., never Despair). **Design constraint that keeps this safe: do NOT over-expose "Monarch" in early-game copy** — early dialogue talks about "the evil / the Despair," not "the Monarch." Guard the word so its late reveal keeps its weight.

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

### 2.4.1 The Arrival — the opening sequence ✅ built (all five beats)

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

### 2.5.1 How Orin enters the game ✅ built (rumour → return → pact)

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
- **Shrine unlocks at depth 30** ✅ — corruption stops being always-fatal.
- **Responsibility:** build an economy; keep morale up; balance dungeon time vs. defense time.

### Act III — The Squeeze (floors ~50–95)
- **Escalation on both ends:** deep floors are brutal; sieges are brutal; the player *cannot* be everywhere.
- **Automation is the reward:** Government scales chore-automation (kids route to school → jobs; wall shifts auto-assigned; taxes collected) — earned relief from Act I–II's manual grind.
- **The Ten** (§8) — the capstone rescue arc: one legendary hostage hidden in a vault across floors 22–63 (moved earlier 2026-07-20, dev call: the automated village must be *enjoyed*, not unwrapped at the finale's door), each permanently transforming one village system.
- **Keystone skills, exclusive specs, ultimates; Excellent-grade weapons; full set bonuses.** The player becomes a monster — and pales, literally, as the hidden Shadow Monarch passive stages tick up (§6).
- **Foreshadowing beats** ✅ planted: Orin's suspiciously generous tribute; cryptic dungeon notes; a taunt that he *wants* you to grow; Ilo the Bard's fragments of the Age of Monarchs.
- **Responsibility:** perfect the village (the finale gate demands it) while surviving the worst the dungeon has.

### Act IV — The Harvest (the gate + floor 100)
- Full sequence in §9. **Responsibility inverts:** everything you built becomes the boss. Your job is no longer to protect the village — it's to *end the thing that made protecting it impossible*, and then to bring them all back.

### Post-game — The Shadow Court (§11)
- Lead the shadow-village; play the unlocked **Shadow Monarch** class; NG+.

---

## 4. Combat, Player & Dungeon — systems inventory

> ✅ DECIDED (2026-07-21, dev): **THE UNDERDARK — how the deep is entered.** The surface "DUNGEON door + level scroll" is retired. The ONLY way underground is **the cave**: a mouth in the earth where the old sign stood, sloping gently down into an **open underground world** that runs beneath the whole map — Terraria-built: tunnels, chambers, shafts, dark rock lit by braziers, its own mobs and ore seams, in **four depth bands** that get meaner the deeper you go.
> The 100 floors remain exactly as built (bosses every 5th, blueprints, the Ten's vaults, the Harvest gate — nothing moves). They are reached through **hidden stone doors** found in the underdark's niches: each door is sealed onto one floor; **the deeper the band, the higher the floors its doors open onto** (band 1 → floors 1–15 … band 4 → floors 60–100). A door only opens if that floor is unlocked (the same ladder as ever — clear N to unlock N+1; the in-floor gates still descend). Entering through a door returns you to that door when you leave. Exploration is the reward loop: pushing deeper through the caves finds doors that skip you straight to the deep floors, richer seams, and worse company.
- Side-scroller controls: move, jump/double-jump, dash, mouse-aimed omnidirectional attacks, weapon hotbar, E interact, Tab inventory, K skill tree.
- **Mana pool** (base 50 → up to 90 endgame) powering wands/specials; HP up to 160 endgame.
- **Crits + floating damage numbers**; **status effects** (burn / poison / freeze / slow); **fall damage** past a safe distance (negated by fall-immunity relics); **flight** (Aetherwing relic — 10s budget, glide).
- **Death penalty by difficulty** (Easy/Medium/Hard, chosen once per save, permanent): gold drop always; + a random villager lost on Medium; + a skill material on Hard.
- **No UNCONDITIONAL passive HP regen** ✅ (rule refined + enforced, dev call 2026-07-28) — healing = potions (boss-gated, §7.4), **Doctor Maren's escalating ledger** (§5.5a), **THE WARD** (the staffed Hospital's paid full heal: flat price, talked down by every extra nurse, floor 20g — Maren's scaling successor, undercutting her right where leaning on one mortal woman stops being a plan), relic effects, and the one EARNED exception: **a thriving village slowly mends its hero** (up to +2 HP/s at 10/10 morale — the town itself as your healer; care is the cost).

### 4.2 The dungeon ✅
- **100 sequential floors** under Deepwood; unlock one at a time; boss every 5th floor with unique arenas; enemy stats scale with depth; mines, twin gates (blue retreat / green advance), exit button anytime.
- **Enemy identity — SETTLED:** undead/evil/deepwood-themed across all mobs and bosses; **archetypes + elites** with distinct behaviors; **all apex bosses have combo AI** (multi-skill chains with punish windows — the L100 Fallen Wizard's five-combo brain is the template).
- **Every boss transforms** ✅ (2026-07-28): a unique, NAMED **phase two** per boss (THE GRAVES OPEN, ABSOLUTE ZERO, NEVER THERE...), entered at the enrage threshold — heard as well as seen. Terraria-style **restless movement** scales with depth (reflex steps, noclip flight, swoops); phase-tell = the body ghosting toward its magic colour. FOREVER RULE: every boss differs in MANY ways at once; difficulty is mechanics, never one-shots.
- **HIDDEN EVENT BOSSES** ✅ (2026-07-28): eleven secret hunts (`event_boss.gd`) woken by the player quietly DOING something — hoarding gold, over-harvesting, digging too deep, six floors without dying — no quest marker ever. Each pays EXCLUSIVE loot with a 50/50 weapon coin-flip so one run can never assemble the whole armoury. Each has its own phase two and distinct combos (the guards enforce it).
- **Lore layer on the same enemies:** they are *fallen humans* — people whose hope died (morale 0 → hopeless → despair → evil; the Law of Despair, §2.2; §10 makes it mechanical, not just flavor).
- **Rescues inside the dungeon** ✅ (Sorrow-Crystal rework built, 4.2a): 19 leadership VIPs freed at bosses 5–95, + the earlier deep figures. **The Ten (§8) are separate and deeper.**

### 4.2b THE BESTIARY — a species is a VERB, not a skin ✅ built (2026-07-29)

*The bosses got named phase twos; the ordinary horde you fight for a hundred floors did not. This closes it — and it is the mob-side mirror of the weapon overhaul's thesis: identity from mechanics, never from stat bumps.*

**The diagnosis it fixes:** the six rosters differed only in colour, scale and three multipliers, and the floor drew its specials from ONE shared five-item bag — so an Orc was exactly as likely to be a *healer* as a Rotfiend, and a floor-3 mob fought identically to a floor-97 mob at a different HP total.

- **Every species now has its own NAMED signature**, keyed in `enemy.gd`'s `ENEMY_ROSTERS` and always on:
  - **Orc — "War Cry."** Plants its feet, roars: every orc within 300px runs *and* swings faster for 6s. Deals no damage at all; the threat is a loose pack suddenly moving like a unit. **Counter:** kill the crier, or break away and let the window lapse.
  - **Blood Fiend — "Bloodscent."** Frenzies while the hero is under half health (faster, sight doubled) and settles again past 62%. **Counter:** healing is now a tactical act, not a number going up.
  - **Demon — "Emberburst."** The corpse keeps burning: a ring swells for 0.7s (the readable tell), then a burning patch for 3s. Punishes standing on what you just killed. Hard-capped at **2% of max HP per tick** and it can **never land the killing blow**.
  - **Wraith — "Fade."** Goes incorporeal for 1.1s: untouchable, and unable to strike back. A timing lesson, and the exact counter to dumping a committed channel into the first thing you see.
  - **Bone Golem — "Reassemble."** Killed, it drops into a rattling heap and rises **once** at 35% HP. **Counter is in your hands:** the heap is still a target, and any hit inside the window smashes it for good.
  - **Rotfiend — "Miasma."** Poisons the *ground* it stood on rather than bursting. **Counter:** stop standing still; kite it off its own gas.
- **The generic specials now suit the face wearing them** (`affinity` per roster): a healer is a plague-priest Rotfiend, a shield is an Orc or a Bone Golem, a summoner raises bones or spectres. **Balance is untouched by design** — the same share of mobs becomes special (`dungeon_interior.assign_enemy_behavior` keeps its curve), and no signature touches the floor's hp/dmg/speed multipliers.
- **Identity follows the FACE, not the floor.** Since floors field mixed hordes (a grunt can wear a neighbour's skin), the signature comes from the *visual* block — a grunt wearing a golem's bones reassembles like one.
- **The three laws every signature obeys:** telegraphed before it can cost anything; capped so it can never one-shot; and differing in *kind*, not in numbers. `test_bestiary_node.gd` (33 assertions) holds each promise, including every counter-play above and the invariant that a golem heaps **however** it died (poison as surely as a sword — `die()` is the one door both walk through).

### 4.2a The Rescue — the Sorrow-Crystals ✅ built (guard-gated shatter, wrapped stats, Sorrowshard)

*How a taken person is actually freed — the mechanic behind Pillar #2 and the fuel for the whole village flywheel (§5.7 chain E).*

- **The taken are frozen, bound to a crystal.** Each hostage stands frozen mid-motion (§2.4), shackled to a **Sorrow-Crystal** (name TBD) — an artifact actively **draining their hope.** This is the *physical mechanism* of §2.2: the crystal is how Orin force-feeds despair to the unbroken for years, patiently trying to crack them. While it drains, the person is neither alive nor dead.
- **You free them by destroying the crystal — after clearing its guard.** The crystal is protected; you must clear that pocket / floor (regular hostages behind a small encounter on ordinary floors; leadership VIPs at boss floors; the **Ten** in Trophy Vaults, §8). Break the crystal and the drain stops — the breaking is *interrupted*, the person thaws.
- **Shattering it pays out three things at once:**
  1. **The freed NPC** — now yours to bring home.
  2. **An important material** — ✅ DECIDED (2026-07-20, delegated): the **SORROWSHARD**, crystallized despair left behind by the shattering (1 per crystal; a strong soul's crystal — stat 5+ — leaves 2). Its use: **the Shrine consumes 3 Sorrowshards per cleansing** — despair, captured and inverted, is the reagent that undoes despair.
  3. *(implicitly)* a light back on: the reveal below.
- **Stats are HIDDEN until they're home.** A frozen hostage shows **nothing** — you cannot see their profession stats until they thaw in the village. Every rescue is a wrapped gift: you might have freed a statless nobody, a rare 4–5-stat prodigy, or a rescued **leader** (the only source of leadership roles, §5.3). The rescue *gamble* mirrors the School role-roll (§5.4) — luck is woven through the whole village economy.
- **Getting them home — Orin "helps" (proposed):** once introduced (~L15, §2.5.1), **Orin teleports each freed hostage back to the village.** The dramatic irony is the point: the one who *took* them cheerfully returns your rescues — because he means to harvest the whole village at the peak (§2.5, "he wants you to build it so it hurts"). *Pre-L15 (before Orin), the crystal's shattering itself banishes them home (its own magic reversed), or they walk out with you — flag the early handling.*
- 🟡 Open (§12): the crystal's name; the "important material" identity + what it's for; regular-hostage frequency/placement; whether Orin-teleport is canon or the crystal self-returns; how a rescued **leader** surfaces (since leadership can't be schooled).

### 4.3 Itemization ✅ (Terraria-scale overhaul, 2026-07-28 — dev-directed)
- **EXACTLY 350 wieldable weapons** (dev's locked number, census-proven in-engine by `tool_roster_report.gd` — never hand-count). ~75 hand-authored in ITEM_DEFS + **the generated ladder** (`weapon_roster.gd`): compact rows expanding lazily into full defs; drops ride overlapping per-tier floor brackets (a lucky shallow run tastes the next tier early), proven gapless 1–100.
- **EIGHT-tier grade ladder** (dev 2026-07-28): common → uncommon → rare → epic → legendary → mythic → **ascended** (cyan, 70+) → **monarch** (ember, the peak). Grade passives unchanged. Armor and relics drop **depth-gated by grade** (lower bound only, so nothing becomes unobtainable).
- **19 behavior families** (orbiters, lashes, ricochets, clusters, mortars, tome-storms, sentries, the **chain-maul flail**, the Wukong **staff combo** — landed beats DRAW IT LONGER, the last strikes the earth as a pillar) + **11 flagship crowns**, each with a NAMED bespoke rider (The Rumor grows in the telling; A Small Personal Sun leaves its sunlet; Second Moon's whirl has a tide...). The card states each weapon's own promise.
- **Terraria-exact armor** (dev: "EXACTLY like in Terraria"): helmet / breastplate / leggings ONLY — gloves/boots are RETIRED slots (their old pieces are bag curios; never drop, never sold). **12 relic slots**, 6 open at start, one more per 10 levels.
- **Armor sets** now reach the ladder's peaks: the three class sets + Ranger's Leathers + Dragonscale Panoply (its full bonus BURNS) + **Voidwalker Raiment** (ascended) + **The Sovereign's Regalia** (monarch). Every set has 2pc/3pc tiers and a set-weapon FULL tier, spelled out in the equipment window.
- **Consumables + crafting** (`try_craft`), **gathering tools** (Woodsman's Axe → wood/resin; Miner's Pickaxe → stone/iron/ember) with overworld harvest nodes.
- **Loot rules:** bosses drop level-gated gear, always something unowned; Excellents rare L25+. Set/variant gear is never granted at start.
- **Blacksmith Forge** ✅: gated to depth 35, vendors up to **Rare** — and takes **DAILY IMPORTS**: eight roster weapons dealt fresh each in-game dawn (seeded by the day, stable all day; set weapons stay dungeon-drop only).
- **Sound** ✅ (audio pass 2026-07-28): procedural chiptune one-shots (`sfx_synth.gd` — crack/pop/thump/whoosh/chime/tear, PCM synthesized once, played from where each effect happens). Every mechanic speaks: storm strikes, ward pops, ricochet pings that climb, the phase-two roar, the tolling death countdown.
- **Standing rules:** every item's icon must closely match its in-hand look; every combat visual must READ at world zoom against the night palette (full alpha + a soft halo — "the faint-dot disease" is a named bug class).
- ✅ Both closed: the Reset Potion is a real consumable item, and the admin wand is unobtainable in honest play (excluded from the starter kit, the Forge, the shop, and the Wanderer's Post — only --dev grants it).

### 4.4 Skill tree & classes ✅ (redesigned as a graph)
- Three main classes — **Sword, Archer, Mage** — each tree a **branching graph**: at tier 4 every spec **forks into mutually-exclusive keystones** (exclusive groups, enforced everywhere), keystones **evolve**, ultimates are **triggered actives**. Warden spec = pure DoT.
- Tier 1–2 cost points; tier 3+ also cost **materials** (Slime → Iron Shard → Ember Crystal → Void Essence → Ancient Relic by depth), which must be **researched at the Science Lab** before spending — skill progression is tied to which village roles actually function.
- **Reset Potion** refunds points and class choice (materials not refunded).
- The fourth tree — **Shadow Monarch** — is visible but locked until the game is completed (§11). *(Renamed from "Necromancer" everywhere; never use the old name.)* Its kit is ✅ BUILT: Legion / Dominion / Ascendant (shades, fear-novas, the true form).
- **The Wukong roads** ✅ (2026-07-28, dev: "add wukong elements, don't copy 1-1"): twelve SIDE-ROAD nodes drawn as jade detour cards — Sword: Somersault Cut + The Immovable Pillar; Archer: The Golden Gaze + Cloud Step; Mage: Stillness + The Plucked Hair (plus the older Riftweaving/Telepathy roads); Monarch: The Splitting Dark + The Sky Is His Road. Three relic-runes join the pool: Circle of Sanctuary, Stone Guise, The Riddle Staff.
- **Tree guards** ✅: `test_skilltree_node` proves all four trees as graphs — every prereq resolves and points up, every effect key is READ by game code, forks are matched pairs, no grid collisions, every node root-reachable.

### 4.5 THE ECLIPSE — the hour the sun goes out ✅ built (2026-08-06)

*The rarest event in the sky, and the gate on the hardest fight in the game.*

- **What it is.** The moon takes the sun **whole** and the world drops to black silhouette lit by one burning red ring. Deliberately **not** a red filter over a normal day: the global tint goes deep red-*dark*, so everything reads as outline lit **by** the eclipse, and the moon rides onto the sun so what survives is the corona. `eclipse_progress()` is the one number the sky draws from — 0 at first contact, 1 at totality, 0 again as it lets go.
- **It is NOT the dusk crossing.** Sun and moon share the sky twice a day, every day; that ordinary crossing is what Nihil's older Duskmoon rite reads (`_sun_moon_both_up`). A **true** eclipse is a far rarer thing and is kept behind its own flag (`is_true_eclipse()`) precisely so the two can never be confused.
- **Rare, recurring, and never missable** 🔒 (dev call). Each day carries a flat `ECLIPSE_CHANCE_PER_DAY`, and never within `ECLIPSE_COOLDOWN_DAYS` of the last one — so it cannot fall twice in a row, and it cannot be farmed by idling. It holds for `ECLIPSE_DURATION_HOURS`: long enough to waystone home, **not** long enough to go and fetch what you should already have been carrying. Caught in the deep without the Signet, you have lost *this* one and nothing more — another will come. That is what keeps a once-a-campaign spectacle from becoming a once-a-campaign punishment.
- **It always begins at dawn.** The roll picks the *day*; the sky picks the hour (`ECLIPSE_START_HOUR`). An eclipse rolled at midnight and started on the spot would be a red *night* — no sun to take, no ring, nothing to look at. Snapped to sunrise, the span lands exactly on the daylight: first contact at dawn, totality at noon, the sun let go at dusk.
- **It pierces the away-fog** (§5.9) on purpose, announced the moment it begins wherever the player is standing. Nobody can be asked to be ready for a thing they were never told about.
- **What it is FOR — The Hollow Sun.** Raising the **Hollow Signet** during a true eclipse calls `evt_hollowsun`: an apex event boss that stands **outside** the ten-boss hunt (§4.2) and is the only boss in the game fought **in your own streets**, so every trick it owns is one your town is standing inside. Difficulty is mechanics, never one-shots (forever rule) — its damage sits barely past the Master of the Hunt's, its health half again. It pays the **Eclipse set**, the top of the item ladder: Ringbreaker, Corona Edge, the Hollow Crown, Eclipsed Plate, Ringlight. And because calling it endangers the whole village, it is **repeatable by design** — dev, 2026-08-06: *"you're endangering your whole village + progress… it would be very unfair to give 1 chance."*
- 🟡 Open (§12): **how the player obtains the Hollow Signet.** The item exists and its use is wired; as of 2026-08-06 nothing drops, crafts or sells it, so the fight is unreachable in honest play. Flagged to Mechanics.

---

## 5. The Village — the living machine

### 5.1 The Grammar (the law every building obeys) ✅ decided
> A building serves a **NEED** → employs **STAFF** (daily wages) → skilled staff need **KNOWLEDGE** (School) → the building runs an automatic **SERVICE** → destroyed/unstaffed/unpaid, the service **STOPS** → **CONSEQUENCE** → **MORALE** moves.

**Three stages of every task:** do-it-yourself (early) → delegated (staffed, slower) → automated (staffed + upgraded + wages paid). **Automation costs wages; can't pay → workers quit → back to manual.** Two layers: building-level automation (farmers farm, nurses heal) and **management-level automation (Government)** — the mid→late building that scales automation of the *player's own chores*.

### 5.1a THE AUTOMATION LADDER 🔒 *(standing law — the dev's own rule)*

> **Every chore the player does by hand early must eventually be taken over by a building or a leader.** The player starts hands-on and deliberately annoyed; by roughly **character level 80** Deepwood should be a nearly self-running city.

This is not an aspiration, it is the acceptance test on every manual verb in the game: **if you add a chore, you owe it an heir.** A chore with no successor is a design bug, not a difficulty choice — and a system that never stops demanding the player's hands is the thing this law exists to forbid.

The ladder is **paced by rescue depth**, not by a separate unlock track — the person who takes a chore off you is a hostage lying at a fixed floor, so pushing deeper *is* how you buy your own time back:

| Chore | By hand (early) | Taken over by | Rescue depth |
|---|---|---|---|
| Pairing a couple | E on a cottage | the Bar's **Publican** (Fenn Merriman) | **20** |
| Selling surplus | hand-sell each stack | the Marketplace's **Merchant Prince** | **25** |
| Paying wages | out of your own purse | the Bank's **Treasurer** | **35** |
| Schooling a child | one at a time in the assign panel | the School's **Principal** (`auto_enroll_children`) | **45 / 50** |
| Raising a cottage | the B build menu | the Builderhouse's **Master Builder** | **55** |
| Deciding who trains | the Government dial (§5.14) | the **Chancellor** | **95** |

So the family loop runs itself by the deep 50s and the last decision leaves your hands at 95. **What replaces the chores is not idleness** — a town that runs itself starts generating emergencies of its own (§5.16). That is the answer to "what is there to do once it works."

### 5.2 The building roster (16) — status mixed ✅/🔨/📋
| Building | Serves | Falls → breaks |
|---|---|---|
| **School** (keystone) | skilled workforce — teaches stats (the role roll §5.4) | the whole automation web unravels |
| **Farm** | food #1 | starvation |
| **Fishing Dock** | food #2 — **premium food** (more morale, sates longer than Farm) | no backup food; the morale/longevity food edge lost |
| **Hospital** | healing + births | wounds kill; no new children |
| **Barracks** | defense — day/night shifts (§7.5) | every siege is on the player |
| **Mine** ✅ | ore/metal + stone — the delegated form of hand-mining | Blacksmith & Builderhouse starve for raw materials |
| **Blacksmith** | arms & tools + the depth-35 Forge; **arms the Barracks** (§5.7) | weak defense, slow workers |
| **Builderhouse** | repair/construction | rebuild everything by hand |
| **Science Lab** | research (materials, upgrades) | no progression |
| **Marketplace** | trade — production → gold | can't pay wages |
| **Bank** | treasury, interest, payroll | gold vulnerable, no interest |
| **Government** | the management brain; global automation scaler | back to manual chores |
| **Tavern** (inn) | lodging — newcomers arrive here until housed | newcomers have nowhere to be |
| **Bar** | drink, music, fun → morale | despair comes faster |
| **Shrine** ✅ | *redemption* — capture & cleanse a transformed demon back into a villager; unlocks at depth 30 | despair is always a death sentence |
| **Watchtower** ✅ (§7.1; standalone structure, not roster) | siege foresight (none → 1h → 2h → 24h warning) | you never know when the wave hits |

All buildings start **visually destroyed** and non-functional; repair costs gold + materials in stages (✅ built, incl. siege damage/repair). **How they interlock into one system is §5.7.**

> ✅ DECIDED (2026-07-20, dev): **BLUEPRINTS** — a ruin cannot be raised until its blueprint is FOUND in the deep. The survival basics (Farm, Tavern, Builderhouse) are known from the start; the other twelve lie at fixed floors paced by the dependency ladder — Hospital 2, School 4, Dock 6, Barracks 8, Bar 11, Mine 13, Blacksmith 16, Marketplace 19, Bank 22, Government 26, Shrine 30 (matching its own service depth). Everything is in hand by floor 30 — deliberately EARLIER than the floated ~40, so no building ever arrives too late to matter. Old saves know everything.
> ✅ DECIDED (2026-07-20, dev): **BUILDINGS ARE MOVABLE** — the assign panel offers Relocate (25g + 4 wood): the building packs up, you walk to the new ground and press H to plant it. Spacing and the two ramparts are respected; positions persist. Cottages, walls and the Watchtower keep their ground (the row, the flanks and the plot ARE their identity).
> ✅ DECIDED (2026-07-21, dev): **RUBBLE FIRST** — a fresh ruin is a *nameless heap*: no label floats over it. The player clears it by hand (E three times, 1/3 → 3/3, a dust puff per shovelful, grey mounds shrinking on the ground), and only the last shovelful reveals what stood there. Then blueprints/F-build proceed as before. Anything already part-built predates the rubble and never demands a shovel; clearing persists per run and resets on New Game (built ✅, test_rubble_node).
> ✅ DECIDED (2026-07-21, dev): **THE BUILDER'S LEDGER (B)** — one window listing every site: uncleared heaps stay "an unrecognisable ruin" (no purpose leaked), cleared sites show their name, state (cleared / plans lost / ready to build / stage N/3 / standing) and a ONE-LINE purpose. Deliberately not an encyclopedia — numbers stay in each building's own E-panel (built ✅).

### 5.3 Professions ✅ decided
One profession stat per building (Farmer, Fisher, Doctor/Nurse, Smith, Builder, **Miner**, Scholar, Merchant, Banker, Official, Teacher, Innkeeper, Barkeep) + **Warrior** (Barracks — deletes all other stats, permanent, one-way sacrifice). Leadership roles (Leader / Principal / Warchief) can **never** be taught — only rescued hostages who already carry them qualify. Leader bonuses (+15% class-appropriate boosts) ✅.

### 5.4 Villager stats & the school pipeline — the role roll ✅ decided (model revised 2026-07-17) / 🔨 partial
- Every NPC carries **0–5 profession stats** (1 common → 5 extremely rare). **1 stat = employable + safe from depression.** Extra stats = pure versatility.
- **The role roll (revised 2026-07-17):** a graduating child — and any statless NPC put through School — does **not pick** their profession. They **roll one from a weighted table.** Weight is **inverse to the role's value/difficulty:** low-skill, low-stakes roles that mostly serve food / fun / morale (**Farmer, Fisher, Barkeep, Innkeeper**) are **common**; skilled, high-leverage roles (**Banker, Scholar, Doctor/Nurse, Official, Teacher, Smith, Merchant, Builder**) are **rare**. Leadership (Leader / Principal / Warchief) is **never on the table** — rescued only (§5.3). *Rationale: anyone can tend a field; a banker or a scholar is a rare mind. Scarcity makes the valuable roles feel valuable and keeps rescued VIPs precious.*
- **The consequence — luck + volume:** to staff the rare roles you must **produce and school many children** and accept the odds. This is the engine that gives the cottage → child → school lifecycle a real *economy*: population growth is how you eventually fill the Bank, the Lab, the Hospital. A run is partly a numbers game of "keep the cradles full."
- **Statless NPCs** slowly become depressed → fix via School (roll a role) or Barracks (become a Warrior).
- **Re-education, up to 3 total:** each re-schooling grants one **new** profession (no repeats), **rolled the same weighted way**; 2nd stat 5× time, 3rd stat 10× time; **hard cap 3 via School.** So an NPC is up to three weighted rolls — more shots at a rare role, at growing time cost. Natural 4–5-stat *rescues* stay elite finds.
- **Rescues bypass the roll:** rescued villagers arrive with their **real** professions intact — the only *guaranteed* source of rare and leadership roles. This is a major reason rescuing (and the Ten, §8) matters.
- **School weight-tuning — a *progressive* mid-game payoff ✅ built (favour-a-calling, capped 40%):** early game you live with the dice (no adjustment). **Each School upgrade grants incrementally more room to hand-adjust the role weights** — a little comfort at first, growing as you invest, until a **fully-upgraded School gives a large but still-capped bias.** The cap is the whole point: **never 100%.** Even maxed, the player might push a chosen role to something like **~40%** (illustrative — balance later) — huge, but not a guarantee, so RNG never fully leaves and the player still **picks which role to favour based on what the village needs right now.** Steerable RNG as a mastery reward (§5.1 automation spirit) and the pressure-valve for the luck economy. *(A mid-game feature that keeps deepening, not a single unlock.)*
- **Lifecycle pipeline:** pair at cottage → ~25h → child (lives in the parents' cottage, eats ~half, **corrupts easily** §10) → enroll → ~24h → adult who **rolls a stat** → employ, and who then **slowly wants a pair** of their own (you pair + house them, §5.8). Manual early (deliberately tedious); **Government automates the whole chain** (kids self-route to school → straight to a job).
- **Villager bonds** ✅: per-villager personal quests (gather/slay/reach-level/reunite) that reveal a hidden stat + reward + 1.5× income from that villager.
- 🟡 Open (§12): the default weight table; whether re-education stays weighted-random or may *target* a role at higher cost; the weight-tuning budget/cap; any pity/floor to soften rare-role droughts.

### 5.5 Needs ✅ decided / 🔨 partially built
| Need | Filled by | Empty → | Status |
|---|---|---|---|
| **Hunger** | Farm/Dock visible food (walk-up eating) — **everyone eats; a child eats ~half an adult's share** | morale drop → death in ~2–3 days | ✅ v1 |
| **Housing** | a **Cottage** (§5.8); Tavern lodges the unhoused temporarily | unhoused → morale drain → corruption risk; caps population | ✅ |
| **Health** | Hospital nurses (roaming, ranged heals); player heals there for gold | wounds/illness kill | ✅ |
| **Wages** | player income; manual early, Bank/Govt later | workers quit → services stop | ✅ |
| **Mood** | Bar / village fun (Bar +1.0, Ilo's songs, Bar/Tavern hosts, dock fish, 10/10 celebration) | no fun → no lift | ✅ (served by the spirit stack) |
| **Mating-depression** | cottage pairing | long-single adults sadden: the −2 loneliness DEEPENS toward −3.5 over ~5 days single, pairing lifts it | ✅ (`single_since_hours`, `personal_morale_target`) |

**Potions rule** ✅ built: HP/mana potions drop **only** from pre-boss waves and boss fights — the player enters every boss stocked, and can't potion-spam normal floors.

**Beyond the needs:** a town can also simply be *struck*. Outbreaks and fires are not unmet needs — they are emergencies a village generates **by being large**, and they are the reason a self-running city still wants its Monarch home (§5.16).

### 5.5a The Doctor — the early-game lifeline ✅ built

Before the Hospital is repaired and staffed (§5.2), the player's *only* reliable healing is **the Doctor** — the raid-survivor who healed the player on arrival (§2.4.1). She bridges story and system: she is the first Doctor/Nurse, working out of the ruined Hospital, and the game's answer to "no passive HP regen" (§4.1) in Act I.

- **Escalating heal cost.** The **first heal each in-game day is cheap** (or free); **each additional heal the same day costs steeply more**, and the price **slowly resets** over time back toward the base. She is a lifeline, not a fountain — you cannot afford to make many mistakes, and every avoidable wound is a real drain on your economy. This is the early-game tension the potion rule enforces later.
- **She can die.** She is a mortal villager in a besieged town — a siege that reaches her, or neglect that lets it, can **kill her.** Losing her means losing your only healer until the Hospital is properly staffed: a serious, felt setback, not a soft reset.
- **Replacing her (the stakes with an out).** If she dies, the *only* path back to a healer runs through the village lifecycle (§5.4): pair villagers → child → School → if the child rolls the **Doctor** stat → employ them at the Hospital. It is slow, luck-touched, and exactly the kind of hard recovery the game is about — you can come back from her death, but you will *feel* it.
- **Design intent:** healing is scarce, personal, and losable in Act I; the player learns early that people are infrastructure and mistakes cost. It also plants the Hospital's importance long before it's rebuilt.
- 🟡 Open (§12): exact cost curve + daily reset rate; whether the "first heal free vs cheap" and how her death is triggered (siege reach vs a neglect timer).

### 5.5b Morale — personal vs the meter (decided 2026-07-17)

Resolves the old ambiguity (morale was read two ways). There are **two layers, and they are the same numbers seen at two scales:**

- **Personal morale (per villager, 0–10)** — every NPC carries their own. Their needs (food, housing, mood, wages) raise or drain *their* number. **A villager's own morale hitting 0 is what corrupts or kills *that* villager** (§10). This is the layer the simulation runs on.
- **The village meter (the aggregate)** — the morale bar shown near HP/mana, the number the **Wanderer's Post** reads (§5.6a), and the **10/10 finale gate** (§9.1) are all the **plain average of every villager's personal morale.** Nothing separate — just the mean.

**Why the average is the right model (the dev's example):** 30 villagers, 28 fed and content, 2 who haven't eaten in two days. The two starving ones **do** pull the meter down — but only *proportionally* (2 of 30), a small dip, not a cliff. Meanwhile those two are individually sliding toward 0 and will **die or corrupt** on their own timer regardless of the healthy average. So the meter tells you the village's *overall* health while the danger is always **local** — a serene average can still hide two people about to turn (and the corruption cascade §10 is exactly how those two can become twenty). The player reads the meter for the shop/gate, but must still *look* for the individuals in the red.

- The finale gate's "10/10 morale" therefore means **every villager at max** (an average of 10 requires no one below it) — which is why it's a *perfect*-village gate (§9.1).

### 5.6 Economy — gold has exactly two makers ✅ built (taxes + interest + wages; per-worker gold removed)

**The rule:** **only the Government and the Bank generate gold.** Every other building produces **goods and services, not money** — Farm makes food, Mine makes ore, Blacksmith makes arms, School makes skilled hands. The **Bar** is the one small exception: patrons pay for drinks, so it trickles a *little* gold on the side. *(This changes current code, which pays passive per-worker gold from every staffed role — that is removed; buildings now pay out in their own resource, not coin.)*

**The gold faucets:**
- **The dungeon** — the player's own income: enemy gold + boss/loot. **This is the primary faucet, especially early** — you fund the village from your delving, which is exactly why Act I's "every coin hurts."
- **Government — taxes.** A passive gold income scaled by the village's **size × prosperity** (employment + morale): a working village generates taxable wealth, and the Government skims it. This is the village's own gold engine, and it *grows as the village grows.*
- **Bank — interest + payroll + insurance.** Grows stored gold (interest), **pays the wages** out of the treasury, and insures a share of the gold you'd drop on death (Dorian, §8).
- **Bar — a small trickle** (drink sales). Minor, flavour-scaled.

**The loop:** dungeon gold + taxes + interest → **treasury** → Bank pays **wages** → workers keep buildings running → buildings produce the goods/services that keep the village prosperous → Government taxes that prosperity → more gold. **Early you subsidize the village from the dungeon; as Government + Bank scale, it approaches self-funding.** The dungeon is the faucet; the village is the multiplier.

- Morale meter ✅ (unlocks once every building has been repaired). Leader bonuses / tribute / morale rewards still apply.
- 🟡 Open (§12): exact tax / interest / wage numbers. *(The Marketplace question is now answered — §5.6a.)*

### 5.6a The Marketplace — the Wanderer's Post ✅ built (morale-priced sellers, live counter)

The Marketplace makes **no gold**. It is the town's **guest-stall**: a stop for **wandering treasure-sellers** who drift in, set up, and sell **random loot** — and how well they treat you is a *direct function of how nice your village is to be in.* This is what turns morale from a defensive stat into an **economic lever.**

- **One seller at a time.** A wanderer arrives with a **random stock** (gear, materials, consumables, the occasional rare find) at set starting prices.
- **Hospitality decides the visit** — driven by **morale** (the 0–10 meter), plus being **fed** and **decorations / ambience**:
  - **High morale (~5–7+):** the seller likes it here — **stays the full ~24 in-game hours** and **slowly marks prices DOWN across the stay.** The happier the town, the longer they linger and the cheaper it gets the longer you wait.
  - **Low-ish morale:** prices **hold flat** and the seller **cuts the visit short** (~12h, scaling down with morale) — a gloomy town gets a quick, full-price visit and an early goodbye.
- **Rotation & escalation:** after one leaves, **the next arrives at a random later time**, and successive wanderers trend toward **better / rarer stock — but at a higher starting price** (which your morale-discount then eats into). A well-run village gradually attracts *better merchants with better loot*, and its hospitality is what makes their prices affordable.
- **Purely a gold SINK** (you spend to buy) — consistent with §5.6's "only Gov + Bank make gold." Its deeper role: the Bar, Tavern, food, and decorations you keep up for corruption-defense (§10) *also* buy you cheaper, rarer loot here. One more strand tying the web together.
- 🟡 Open (§12): the exact morale → (dwell-time, discount) curve; the loot tables + escalation; whether a **Merchant** staffer improves wanderer frequency/quality/haggling (recommendation: yes — gives the Merchant profession its purpose); whether "**decorations**" are a real sub-system or just fold into morale.

### 5.7 The Building Web — one connected system ✅ built (Mine + Shrine in the roster; ladder numbers = balance pass)

The village is **not a menu of independent buildings** — it is one machine whose parts feed each other, and the whole point is that *the connections become mandatory exactly when the difficulty demands them.*

**The core principle — independent early, interdependent under pressure.** Every building is **self-sufficient at low difficulty** and only *needs* the others as the pressure (deeper floors, bigger sieges, more mouths) rises. The Barracks example the dev gave is the template: early, the Barracks spawns warriors who fight waves *on their own*, fists and basic gear enough. As waves get stronger, that stops being enough — now the Barracks **needs the Blacksmith** to forge better weapons; the Blacksmith **needs metal**, which **needs the Mine**; the Mine needs a **Miner**, who came from the **School**, who is fed by the **Farm**, housed by the **Tavern**, kept sane by the **Bar**… Pull any link and the chain downstream weakens. That cascade *is* the game.

#### The resource types (what flows through the web)
| Resource | Made by | Consumed by |
|---|---|---|
| **Food** | Farm, Fishing Dock | every villager (starve → morale → §10) |
| **Construction** (wood/stone/resin) | gathering + **Mine** (stone) | Builderhouse (repairs, walls) |
| **Ore/metal** ✅ (stone + iron shards) | **Mine** | Blacksmith (arms & tools) |
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
| **Mine** ✅ | raw ore/metal + stone | Miner | Blacksmith (metal), Builderhouse (stone) | **Blacksmith & repairs stall without it** once you stop hand-mining |
| **Blacksmith** | forge/upgrade **warrior weapons**, player gear (depth-35 Forge), gathering tools | Smith + **ore (Mine)** | Barracks arms, player gear, tools | **Barracks can't out-arm scaling waves without it**; it can't run without Mine metal |
| **Barracks** | train Warriors → fight waves + man walls | villagers → Warrior | Defense | self-sufficient early; **needs Blacksmith weapons** as waves scale; **needs Hospital** to recover the wounded |
| **Hospital** | heal wounded warriors + player (§5.5a) + births | Doctor/Nurse | fighting-fit warriors, player HP, new children | every siege leaves wounded who **don't recover without it** (no passive regen, §4.1) |
| **Builderhouse** | repair/build (incl. walls) | Builder + **construction mats** | standing buildings & walls | sieges break walls faster than you can hand-repair |
| **School** (keystone) | teach stats — the role roll (§5.4) | Teacher | the workforce for **every** building | if it falls, **nothing else can be staffed** long-term |
| **Science Lab** | research materials + building upgrades | Scholar | skill-tree access, upgrades (incl. School weight-tuning §5.4) | progression **freezes** without it |
| **Marketplace** ✅ | *(§5.6a)* the **Wanderer's Post** — hosts rotating treasure-sellers; **morale sets their prices & how long they stay.** No passive gold. | Merchant (haggling/quality) | a gold *sink*; better loot the nicer your town | without it, no wandering merchants, no loot market |
| **Bank** | **one of only two gold makers** — treasury, **interest**, payroll (pays wages), death-insurance | Banker | gold, wage automation, safe treasury | the Money Loop (C) has no payroll or growth without it |
| **Government** | **the other gold maker** — **taxes** village prosperity — AND the management brain that scales **automation** of the player's chores | Official + a rescued **Leader** | gold (taxes) + less micro across *all* systems | no passive village income, and the grown village drowns you in manual tasks |
| **Tavern** (inn) | housing — rescued/newcomers live here until homed | Innkeeper | housing → morale floor | **unhoused villagers lose morale → corruption risk (§10)** |
| **Bar** | drink/music/fun → morale (+ a **small gold trickle** from drink sales) | Barkeep | morale buffer (hope) + minor gold | the morale cushion that makes the Cascade (F) *survivable* |
| **Shrine** ✅ | cleanse a corrupted demon back to a villager (depth 30) | (Seraphel §8 boosts) | recovered villagers | before it, every corruption is a permanent loss |
| **Watchtower** ✅ (standalone) | siege foresight (§7.1) | build + upgrades | warning time → planning | without it, defense is pure reaction |

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

- ✅ DECIDED (2026-07-20, delegated): **Mine ore reuses the existing ids** — staffed Miners haul **stone + iron shards** (the mats the Blacksmith and Builderhouse already eat; no new resource, the chains just connect). The Mine is **hand-buildable from Act I** like every ruin (it's the delegated form of hand-mining; its cost is the gate). **The Shrine is staffed by the Hospital stat** — its keepers are called **Lightkeepers** — because cleansing a broken soul is healing at its apex, and it is Seraphel the *Lightkeeper* who boosts it. Ladder threshold **numbers** remain a balance-later pass.

### 5.8 Housing & Cottages — where villagers live ✅ built (pair-homes for life, the plot, widowhood)

Housing was the biggest hole in the village loop: "unhoused" drives corruption (§2.2) but nothing gave villagers a home. Fixed.

- **Housing is a NEED** (added to §5.5). A villager with no home slowly loses morale like any unmet need → corruption risk (§10). Housing is *the* natural brake on the rescue/birth flywheel (§5.7 chain E): you cannot grow the population faster than you can house it.
- **The Cottage — the pair-home.** A **Cottage holds exactly one PAIR** (two villagers). Housing only happens **in pairs**: you pair two villagers, then **assign the pair to any free Cottage — that becomes their home.** Once housed they **cannot be separated; only death parts them**, and the cottage stays occupied while both live. The Cottage is also the cradle (§5.4) — home and mating-house are the same building.
- **Single = a standing morale penalty.** An unpaired adult is lonely: **−2 morale, permanent, for as long as they stay single.** This is the push that makes you pair everyone off — singles pile up in the Tavern (temporary lodging) dragging the average down until you house them.
- **Widowhood.** When one of a pair dies, the survivor takes a **−3 morale hit that decays back to 0 over time**; after **~48 in-game hours** they can be **re-paired** with another villager and assigned a cottage again. The freed cottage can take a new pair.
- **Built, not free.** Cottages cost construction materials and are raised by the Builderhouse (or by hand early) — so **housing capacity is something you must keep building**, tying straight into the Mine→stone / Builderhouse chain (§5.7). More people ⇒ more cottages ⇒ more materials ⇒ more Builder pressure. *This is the hard brake on the flywheel: you cannot out-rescue/out-breed your cottages.*
- **Children live with their parents.** A child is **auto-housed in its parents' cottage** (no separate slot) until it grows up. On reaching adulthood it **slowly wants to pair** — the player then pairs it with another single and assigns them a free cottage. (So a child costs no housing while young, but *will* demand a cottage once grown — plan ahead.)
- **Warriors house like anyone** — a Barracks Warrior is still a person who pairs and needs a cottage (and eats), and suffers the −2 single penalty; they are only special in that they **cannot corrupt** (§10, they die in battle instead).
- 🟡 Open (§12): whether a cottage visibly shows its couple + kids; the exact single/widow morale numbers are set (−2 / −3 / 48h) but the decay rate is a numbers-pass.

### 5.9 The Village Log — press **L** ✅ built

> **THE VILLAGE FOG (dev decision 2026-07-20):** away from the village the player learns NOTHING of it — no morale meter, no toasts, no diary. The Log still records everything; coming home and reading it is how you find out. **Telepathy** (Mage, Mystic branch, mid-game) lifts the fog entirely: meter, diary, every cry, and the Watchtower bell reach the mage anywhere — the mage becomes the only class that can watch home from the deep.

A running, **timestamped journal of everything that matters in the village**, opened with **L**. The village runs on background simulation (births, deaths, rescues arriving, a villager corrupting, a wanderer showing up, a building finishing, a siege hitting) — much of it while the player is down in the dungeon. The Log is how the player *catches up on what happened while they were away* without having to watch it live.

- **Logs every notable event** with an in-game timestamp (day + hour): births, deaths, corruptions, rescues returned, employment/graduation, building repairs/upgrades finished, siege start/outcome, wanderer arrivals & departures, morale milestones, someone entering the grey "rot" danger window (§10).
- **Newest first**, scannable at a glance; ideally lightly **categorised/filterable** (village / combat / people / economy) so a returning player can jump to "who died while I was gone."
- **Design bar (dev directive): comforting to the eye, pleasant, and easy for a new player.** Plain language ("Milo and Elin had a child," not a system code), clear timestamps, no wall of noise — only things worth surfacing. It should feel like reading the village's diary, not a debug console. *(This is UX/readability design, not art — it obeys the art-freeze; it's about clarity and information design.)*
- 🟡 Open (§12): the full event taxonomy + which events are "worth logging" vs noise; retention (last N entries / last M days); whether critical entries (a death, a corruption) also raise a passive toast so the player isn't blindsided.

### 5.10 Villager interactions — the verbs (decided 2026-07-17) — closes the village audit

The canonical list of **everything the player can do to/with an NPC** — the spec the interaction UI is built from (approach or click a villager → a clean, readable menu; same new-player-friendly bar as the Log §5.9). Each verb, its effect, and its gate:

| Verb | What it does | Gate / rule |
|---|---|---|
| **Inspect** | see their name, morale, role/stats (if known), needs, pair + home, bond status | stats are hidden until a hostage is rescued & thawed (§4.2a) |
| **Assign / Reassign** | put them to work in a building matching a stat they hold (or pull & move them) | needs the building repaired, staffed-slot free, and a matching stat |
| **Send to School** | educate — roll a new weighted profession (§5.4) | costs time (2nd stat 5×, 3rd 10×); **hard cap 3**; leadership can't be taught |
| **Draft to Barracks** | make them a **Warrior** | **one-way, permanent** — deletes all other stats (§5.3); can't corrupt after (§10) |
| **Pair** | pair two single adults (enables a home + children) | both must be single adults; removes the −2 single penalty once housed |
| **Assign to a Cottage** | house a pair — that cottage becomes their home | needs a free cottage (§5.8) |
| **Re-pair** | re-marry a widow(er) | only after ~48h of mourning (§5.8) |
| **Heal** | send to the Hospital / Doctor for treatment | costs gold (Doctor's escalating price early, §5.5a) |
| **Start / Turn in a Bond quest** | the per-villager personal quest — reveals a hidden stat + reward + 1.5× income | one active bond per villager (§5.4) |

- **Not a verb:** you can't "dismiss/exile" a villager (this is a rescue fantasy — you don't throw people out), you can't separate a living pair (only death parts them, §5.8), and you can't feed by hand — food is walk-up/auto (§5.5). Early game these verbs are all **manual**; **Government automation** (§5.1) progressively performs the routine ones (assign graduates, fill wall shifts) for you.
- 🟡 Open (§12): whether **Inspect** is a hover-tooltip vs a full panel; whether **Pair** is player-arranged only or villagers can auto-court (recommendation: player-arranged, so pairing stays a deliberate housing/vibe decision).

*Village audit complete: all five gaps (§12 #13–17) resolved; the village half of the design is hole-free pending the numbers pass.*

### 5.11 Where you build — the three placement rules ✅ built (adjacency, districts, plots)

Deepwood is a **1-D strip**, so every spatial rule reads off a single x coordinate: readable at a glance, no grid to puzzle over. All three rules are **positive-only** — a plain row is never fined, so no town laid down before these existed is retroactively punished — and they **stack**, folding into the one term every producer in the chain multiplies by:

```
building_output_multiplier(name) =
    1 + (level − 1) × BUILDING_OUTPUT_PER_LEVEL
      + adjacency_bonus + district_bonus + plot_bonus
```

`refresh_layout()` reads the layout off the standing bodies and **caches** it — `building_neighbors`, `building_districts`, `building_plots`, `building_x`. All four must resolve while the surface scene is *unloaded*: the player is in the deep and the town keeps running on the last known row (buildings cannot move while you are away, so it stays true).

**1 — Adjacency: who you stand beside.** "Adjacent" means the **immediate left/right neighbour**, not a radius. Eight pairs (`ADJACENCY_PAIRS`), each a link of the Building Web (§5.7) made physical, capped at `ADJACENCY_BONUS_CAP` so a lucky cluster of six can't run away with the economy. Physical adjacency counts every building **body** — a ruin standing between two halls really does separate them, and raising or moving it is how you fix that — but a synergy only *fires* when both halves are operational.

| Pair | Why it pays |
|---|---|
| **Mine ↔ Blacksmith** (largest) | ore goes straight from the seam to the forge |
| **Bank ↔ Marketplace** (largest) | the counting house sits beside the carts |
| Mine ↔ Builderhouse | stone lands at the masons' door |
| Blacksmith ↔ Barracks | arms are carried straight to the drill yard |
| Farm ↔ Fishing Dock | one larder, filled from field and water both |
| Science Lab ↔ School | the lab's findings are taught the same day |
| Bar ↔ Tavern | a bed waits directly above the music |
| Hospital ↔ Shrine | healing and mercy keep one threshold |

**2 — Districts: where on the map you stand.** The road runs west (the gate the sieges come from) to east (open working land), giving three natural quarters, each paying `DISTRICT_BONUS` to the buildings that belong in it (`DISTRICT_HOME`):

- **Gatefront** — the war quarter, the exposed ground the waves reach first: **Barracks, Blacksmith, Hospital.**
- **The Heart** — the civic quarter: **Government, Bank, Marketplace, School, Science Lab, Bar, Tavern.**
- **Outskirts** — the working land: **Farm, Fishing Dock, Mine, Builderhouse, Shrine.**

Boundaries are **absolute distances east of the west gate** (`DISTRICT_GATEFRONT_DEPTH`, `DISTRICT_HEART_DEPTH`), never fractions of the row. Fractional thirds would silently redraw every boundary each time the town grew eastward — quietly moving a building out of its quarter and taking away a bonus the player never spent. **Only moving a building changes its district.**

**3 — Special plots: where the map has an opinion.** Seven fixed patches of ground (`SPECIAL_PLOTS`), each suiting exactly one building, granting `PLOT_BONUS` within `PLOT_RADIUS` of the centre — **richer than a quarter**, because a plot is one exact spot and often nowhere convenient: The Muster Yard (Barracks) · The Old Market Square (Marketplace) · The Black Soil (Farm) · The Spring (Fishing Dock) · The Quarry Shelf (Builderhouse) · The Ore Vein (Mine) · The Sorrow-Touched Stones (Shrine). They are **painted into the world** (`special_plot.gd`, each with its own idiom — a seam of ore, furrows, ripples, cut blocks, standing stones): a plot the player cannot see is a guessing game, not a decision.

Three rules the plots obey:
1. **Purely additive.** The Dock still works anywhere; on a real spring it works *better*.
2. **Plot agrees with district.** Every plot lies inside the quarter its building already belongs to, so two of the three rules can never fight. Three spatial demands pulling against each other stops being a puzzle and starts being unsolvable — **adjacency is the one thing you trade away.**
3. **The row rewards planning.** The Black Soil and the Spring are set close enough (as are the Quarry Shelf and the Ore Vein) that a careful player can stand *both* buildings on their own ground **and** keep them neighbours. Those two perfect corners are earned. The Mine's forge pairing and the Shrine's ward pairing stay genuinely impossible to combine with their plots, and that is the point.

### 5.12 Auras — the rule that points outward ✅ built

Placement rules 1–3 change what a building produces **for itself**. An aura changes life for everything **around** it — so for the first time, where you build decides *who benefits*.

| Building | Aura | Effect in range |
|---|---|---|
| **Bar** | *The Sound of It* | `+AURA_BAR_MORALE` to personal morale target — music carries down the row |
| **Hospital** | *The Ward's Shadow* | `+AURA_WARD_REGEN` HP/hour to the wounded, without ever being carried in; also blunts the sickness (§5.16) |
| **Shrine** | *Hallowed Ground* | despair cannot take root within sight of the stones |

**Auras are measured against homes and workplaces, never wandering bodies** 🔒. A villager's NPC avatar only exists while the surface is loaded and it walks about all day; their **cottage** and their **job** stand still and survive into the deep. So an aura asks *"is this person's home or work inside the circle?"* (`villager_places`, `in_aura`) — which is stable, saves correctly, keeps working while the player is away, and (the real prize) finally makes **cottage placement part of the puzzle**: a home built in the Bar's light is a happier home for as long as it stands. Nobody homeless and jobless is reached by any aura, which is its own quiet argument for housing them.

Only three buildings carry one, and each rides a system that was **already spatial**. No aura was invented to give a building something to do.

### 5.13 Building levels and the named powers ✅ built — **THE LEADER GATE** 🔒

> **A building power REQUIRES its leader seated.** *(Standing law, dev call 2026-07-30: "leader loses its value.")* A power that works without the person it belongs to has deleted the rarest content in the game — one named VIP per post, each lying at a specific depth — and walked straight past the automation ladder's pacing (§5.1a), which is measured in exactly those rescue depths.

- **A level is not bought for the percentage.** Per-level output shrank to `BUILDING_OUTPUT_PER_LEVEL` — connective tissue only — under the dev's law *"stats should not be important at all; transfer their importance to unique behaviour."* At `BUILDING_POWER_LEVEL` every building instead wakes a **NAMED power** that changes what it *does*.
- **The gate is threefold:** the hall must be operational, at level 4 or above, **and** have the right person in the chair (`has_building_power` → `building_power_staffed`). The one exception is the **Shrine**, whose Lightkeepers are Hospital-trained keepers rather than a rescued VIP — there the keepers at their posts answer for it.
- **A power is that leader's masterwork, never their replacement.** Four powers originally read *"…with no Forgemaster / no Principal / no Chancellor / no Master Builder."* Under the law they had to be re-scoped into something that leader **could never do alone**, or level 4 would have bought nothing at all.
- The fifteen powers: **The Night Forge** (Blacksmith) · **The Open Doors** (School) · **The Standing Order** (Government) · **The Standing Crew** (Builderhouse) · **The Standing Watch** (Barracks) · **The Standing Harvest** (Farm) · **The Long Haul** (Fishing Dock) · **The Deep Seam** (Mine) · **The Ward That Never Sleeps** (Hospital) · **The Matchmaker's Round** (Bar) · **The Long Night** (Tavern) · **The Unbroken Light** (Shrine) · **The Ledger That Pays** (Bank) · **The Caravan Road** (Marketplace) · **The Whisper Network** (Science Lab). Exact behaviours: `BUILDING_POWERS`, tabulated in `GAME_MECHANICS.md` §8.10.
- **Leaders carry their own named powers too** (`LEADER_POWERS`), deliberately chosen not to overlap the building power beside them: the Harvestmaster's *The Full Table* works the fields with no farmhands seated; the Harbormaster's *The Tide Table* lands a sealed crate from deep water; the Pitmaster's *The Sounding* cuts ore matched to the deepest floor **you** have reached; the Warchief's *The Muster* calls every able adult to the wall.

### 5.14 The population loop, closed ✅ built (schooling policy + lodging)

The cycle, in order — and it now closes without the player in it:

```
couple in a cottage → child born → the schooling policy routes them
    → School (a trade) or Barracks (a warrior)
    → the graduate is given a ROOF → moving in makes the match → child
```

**The schooling policy — the hinge.** What becomes of the children is the one decision in that cycle nobody can make for you, and it is deliberately crude by hand: at the Government you write a number out of ten (`school_share`, capped by `SCHOOL_SHARE_MAX`). Four means four children in every ten learn a trade and six take a spear; `_kid_intake` walks the block of ten so the ratio is honoured child by child. It is a blunt instrument on purpose — it is what you have before you have anyone better.

**Then the Chancellor takes it over** (§5.1a, depth 95). Once that chair is filled `schooling_is_delegated()` flips and the dial is retired: `chancellor_wants_warriors()` weighs `village_defense_power()` against `current_siege_tier() × CHANCELLOR_DEFENSE_MARGIN`, so **a siege that costs defenders pulls the next cohort into the drill yard on its own** — self-balancing, with no dial to tend. Either way `next_schooling_destination()` falls back to whichever hall actually stands, so a policy can never strand a child nowhere, and a full hall sends the child to the other one rather than turning them away.

**Lodging — the roof comes first** 🔒 *(dev design 2026-07-30, and it supersedes §4's "player picks a Male and a Female and pairs them")*. There is no matchmaker pairing two strangers in the street:

- A cottage may hold **one** person waiting for someone to share it with.
- An adult with nowhere to live takes an **empty** cottage, or one already holding a **single of the opposite sex** (`house_unpaired_adults`).
- **Moving in is what makes the couple** (`pair_housemates`) — there is no separate matchmaking step. The Publican's round runs the two in that order: house them, *then* match them.
- A same-sex arrival takes their own cottage instead; a lone occupant can **never** conceive; children and anyone still in training are never housed as adults; a widow(er) is not looking again until the mourning has passed (§5.8).
- Helpers `cottage_occupant_ids()` / `cottage_is_pair()` / `cottage_lone_occupant()` back the door text — a lone occupant reads as *"lives here alone, and would not mind company."*
- **Once housed, occupancy is for life** (§5.8): only death frees a cottage. Housing therefore stays the hard brake on the flywheel — and the Master Builder raises new cottages only when a couple is actually waiting and no home stands empty, out of the village stores (§5.7), never on spec.

### 5.15 The Patrols — the town reaches into the deep ✅ built (2026-07-30)

*The village's first move **outward**. Until now warriors did exactly one thing: stand on the wall and wait.*

- **By blocks of ten floors**, not floor by floor (`PATROL_BLOCK_SIZE`, `PATROL_BLOCKS`) — ten posts to think about instead of a hundred, matching the Deep Shrine cadence that already exists. A block opens for posting only once **you** have personally swept every floor in it.
- **The cost IS the decision.** A posted warrior is **not on the wall**: `village_defense_power()` counts the posted straight off the top before any shift or armoury bonus. You cannot hold the deep and the gate with the same soldier — which is the first time warrior *count* has meant anything beyond the siege clock.
- **Hold it or lose it.** An unpatrolled swept block **sours**: creep climbs at `CREEP_BASE_PER_HOUR` plus `CREEP_DEPTH_PER_HOUR` per block deeper, and each posted warrior pushes back at `PATROL_SUPPRESS_PER_WARRIOR`. Let creep fill and those ten floors **revert to uncleared** — the monsters are genuinely back for you too, everyone posted there is driven home, and the road down through them is cut. Waystones still reach a woken shrine beyond a fallen block, so it **isolates rather than strands** — which is exactly what makes the shrine network valuable.
- **What they send home: coin and materials** (`PATROL_COIN_PER_WARRIOR_DAY`, `PATROL_MATS_PER_WARRIOR_DAY`, paid out once per in-game day), and **depth is the whole point** — earnings scale by `PATROL_DEPTH_BONUS` per block deeper. Dev, 2026-07-30: *"you believe materials and gold are that important… when their village might get crushed?"* He was right: shallow coin and timber never justified taking a warrior off a wall that losing means losing the run, so the deep has to pay.
- **The find.** A patrol occasionally turns something up on the bodies (`PATROL_FIND_CHANCE_PER_WARRIOR_DAY` — a delight, never a supply line). It is **self-balancing with no percentage to tune**: `_patrol_find_gear` draws only from what the floors it holds would have yielded, using the game's own `WeaponRoster.TIER_FLOORS` brackets — and since a stretch can only be patrolled once **you** swept it, a find is always behind your own progress. Floors 1–10 send up things you would sell; only a deep watch, which costs many warriors off the wall, turns up anything you would wear.
- **The standing rule it must never break:** warriors produce **bulk**, the player produces **meaning**. No relics, no blueprints, no rescued people — ever.

### 5.16 The town's own emergencies — sickness and fire ✅ built (2026-08-06)

*Everything else the village produces, it produces **for** you. These two it produces **at** you — and they are the answer to "what is there to do once it runs itself." A grown town does not become quiet; it becomes consequential.*

**THE SICKNESS.** Physical, contagious, and it kills — **it is not corruption** (§10). Despair turns people into demons; this simply takes them.
- **It scales with size and tightness.** Below `OUTBREAK_MIN_POP` there is nobody to catch it from and a hamlet never sickens; past that the daily odds climb per soul (`OUTBREAK_CHANCE_PER_DAY` + `OUTBREAK_CHANCE_PER_SOUL`). **The reward for growing is not idleness — it is that your town can now hurt.**
- **It spreads house to house**, along the very same homes-and-workplaces the auras read (`villager_places`, within `SICK_SPREAD_RADIUS`). Cottages packed in a row pass it along fast; a town spread down the road resists it. That gives cottage placement a **second** meaning and makes **where you put the Hospital the most consequential placement in the game** — its ward aura is the only standing defence.
- **What the ward does:** inside *The Ward's Shadow* the drain is cut (`SICK_WARD_DRAIN_RELIEF`), the odds of throwing it off jump (`SICK_WARD_CURE_BONUS`), and neighbours in range catch it far less. A staffed Hospital helps even at range, at a fraction of the strength. Untended, the sick drain at `SICK_DRAIN_PER_HOUR` — set to **outrun the passive village mend on purpose** — and can die (`_reap_the_sick`), which then carries the ordinary death-shock into morale (§10).
- **It cannot be fully automated away, and that is the point.** A ward dampens an outbreak; a big town outruns a ward. The news **pierces the away-fog** so you know to come home. That is the player's job — not a chore, an emergency.
- **Exempt:** the Ten and the pledged shadows, as they are from every other loss path (a legend sickens to the brink, never past). Warriors are **not** exempt — unlike corruption, plague does not care that you can fight.

**FIRE — the second face of adjacency.** Every placement rule so far was pure upside, so the optimal economic layout was also the only sane one and the "puzzle" had one answer. **Fire spreads along the same neighbour map the synergies use** (`building_neighbors`) — so the tight, perfectly-paired row that earns the most is now also the row that burns whole. That is the tension the placement layer was missing.
- **It scales with the town** (`FIRE_MIN_BUILDINGS`, then `FIRE_CHANCE_PER_DAY` per standing hall), and the buildings that carry a real flame start most of them — `FIRE_HEARTHS` (Blacksmith, Tavern, Bar, Barracks) at `FIRE_HEARTH_MULT`. **One at a time:** a town does not combust at once.
- **It eats the hall it is in** at `FIRE_DAMAGE_PER_HOUR` and jumps to an immediate neighbour at `FIRE_SPREAD_CHANCE_PER_DAY`. Left alone it **guts** the building (`_fire_guts`) — knocked back down its build stages, to be raised again. Costly; never unrecoverable.
- **Fighting it is the Builderhouse's job**, which finally gives that crew something *urgent* to do: every hand suppresses at `FIRE_CREW_SUPPRESS`, reducing the burn and raising the chance the blaze goes out (`FIRE_OUT_CHANCE_PER_DAY`). But a big blaze outruns a small crew, so it is your emergency too.
- Both emergencies are shouted at the top of the morale panel — how many are burning and whether anyone is fighting it, how many are ill and whether a ward is holding it — because a disaster you cannot see is just a silent tax on a town you thought was running itself.

---

## 6. The Hidden Passive — the Shadow Monarch stirring ✅ v1 / 🔨

A **7-stage hidden passive** — never shown in the skill tree, it just *happens* — tied to character level (cap 100). Each stage: bigger shadow aura, paler skin, a stacking power. The player slowly becomes something the village notices and can't name.

| Stage | Lv | Look | Power |
|---|---|---|---|
| 1/7 | 5 | wisps | **Umbral Touch** lifesteal |
| 2/7 | 15 | growing aura, faint pallor | +shadow damage, dash trail |
| 3/7 | 30 | tendrils, pale | **Shadowstep** (dash i-frames) ✅ |
| 4/7 | 45 | tendrils wrap him | **Dread** fear aura (slow/weaken) ✅ |
| 5/7 | 60 | so pale the **hood rises** | **Rise, Shade** — kills raise a temporary shade ✅ |
| 6/7 | 80 | living shadow cloak | **The Long Dark** — a lethal hit becomes shadow-form (invuln + heal), not death ✅ |
| 7/7 | 100 | 2× size, shadow armor, god | everything amplified; permanent shades; shadow nova ✅ |

*(All seven stage powers ✅ built 2026-07-16 — the 🔨 marks above were stale for months. Only the hooded true-form ART stays ⛔ dev-gated: the protected main character.)*

- Villagers **react at stages 5–6** (afraid / awed / confused mood lines) ✅.
- **7/7 fully manifests only during the Harvest, when the village has fallen** — so **only Orin ever sees the true form.** This passive is the mechanical foreshadowing of §9; *Rise, Shade* at 5/7 is the seed of the ending's **Shadow Army**.

---

## 7. Defense — sieges, warriors, walls ✅ core / 🔨

- **Sieges** scale in size with village health — a *living* village is an insult to the Monarch of Despair; prosperity literally raises the pressure (the squeeze is the design, not a bug).

### 7.1 The Watchtower — earning foresight ✅ built (standalone, three paid tiers, true-chaos tier 0)

The siege *schedule* is not given to the player — it is **earned.**

- **Act I: true chaos.** Early on there is **no wave indicator at all** — sieges hit at **genuinely random times and in random amounts.** You cannot plan; you can only stay ready. This is the intended early-game dread: you never know when, or how bad.
- **Build the Watchtower** (turret / lookout — name TBD, dev doesn't mind) from gathered loot, resources, and items → you unlock **exact wave times and dates**, with a **~1 in-game hour warning** before each incoming wave. Chaos becomes something you can brace for.
- **Upgrade it → 2-hour warning.** **Upgrade again → a full 24-hour warning** — you can now schedule your dungeon runs around known siege windows, the Act III "can't be everywhere" squeeze (§3) becomes a *planned* juggling act instead of a gamble.
- **Design intent:** foresight is a reward, not a default. The progression turns defense from "react to chaos" → "manage a schedule," pacing the player's growing mastery. It also gives the day/night Barracks-shift system (§7 above) something concrete to plan against.
- ✅ DECIDED (2026-07-20, delegated): the Watchtower is a **standalone defensive structure**, not a roster building — the roster's Grammar is NEED→STAFF→SERVICE and the tower has neither staff nor need; it is built infrastructure like the walls and the cottage plots. It rises from a staked plot beside the west rampart in three paid tiers (wood 10 + stone 8 → 1h warning & the visible schedule; + iron 6 + wood 8 → 2h; + ember crystal 2 + stone 12 → 24h). Until tier 1, **no countdown exists anywhere** — the siege banner keeps its own counsel and the pre-descent warning can only say "you cannot know when."
### 7.2 The attack — the wall, and what gets in ✅ built (both flanks, east rampart)

Sieges come **out of the Deepwood** — the same wild the player can't fight their way out of (§2.4.1) — and break against the village's **defensive walls.**

- **From BOTH flanks (decided 2026-07-17).** The village is besieged from **both sides at once** — a wall/gate at each end. You cannot turtle behind one wall; **your defense must be split across two fronts**, which is the "can't be everywhere" squeeze happening *inside a single siege*, not just dungeon-vs-village. The player can only stand at one gate at a time, so the other front rests entirely on the heroes and warriors you posted there — every siege is a bet on how you divided them.
- **The walls have HP** (both faces ✅). The wave batters them while defenders fight at and outside the gates. Two outcomes, and they are night-and-day different:
  - **Wall HOLDS → the wave is repelled at the gate.** The ideal: the village itself is never touched, no buildings hurt, no villagers lost. A siege you were ready for is a non-event — that readiness *is* the win.
  - **Wall BREAKS → the horde pours INTO the village.** Inside, enemies attack **nearest-first (decided 2026-07-17)** — whatever building or villager is closest, no priority logic — which means **where the wall breaks matters enormously**: a breach beside the cottages or the Hospital is a bloodbath, a breach at a bare edge buys you time. Buildings hit → that service STOPS until repaired (§5.7); villagers hit → **death-shock morale crash** (§10). A breach turns a fight into a catastrophe; you and every defender must clear the streets before the town is gutted.
- **The wall is rebuilt/reinforced by the Builderhouse** (+ construction materials, §5.7) between sieges. A breach *mid*-siege can't be patched in time — once it's open, you fight in the streets until the wave is dead.

### 7.3 The defenders — who holds the line ✅ built (dawn/dusk watches, on-shift no-regen)

- **The three heroes** (§2.5.1) — your **starting elite defenders**, strong and always available. They are the backbone of Act I defense *before* you can field warriors, and the reason a fresh village can survive its first nights at all.
- **Barracks Warriors** (§5.3) — villagers drafted to Warrior (one-way, deletes other stats). They sally from the wall as visible units (✅ v1, up to 6 in code) and hold the line. **Their strength rides on the Blacksmith** (§5.7 War Machine chain): bare-fisted warriors fall behind as sieges scale, so the Mine→Blacksmith→arms chain is what keeps them lethal.
- **The player** — the strongest single defender when home… but usually *not* home (the squeeze, §7.4).
- **Day/night shifts** ✅: warriors split into two 12h shifts — the on-shift mans the wall, the off-shift **sleeps and is healed at the Hospital** (no passive regen, §4.1). Night sieges therefore hit the *tired/other* shift, and a **mid-siege shift change** is a deliberate vulnerability window. Manual wall-assignment early → **Government automates** it (§5.1).
- **The Hospital is the recovery half of defense** (§5.2): wounded warriors **stay wounded until healed**, so a siege's cost lingers into your readiness for the *next* one. No Hospital → your warrior pool bleeds down permanently, siege after siege.
- **Every warrior posted into the deep is a warrior off this wall** (§5.15). Patrol strength is subtracted from `village_defense_power()` before anything else, so holding the deep and holding the gate are the same budget spent twice. That trade is the whole reason the patrol system exists.

### 7.4 Home vs away — the squeeze, made mechanical ✅ built (auto-resolve + the Log)

The player is usually **deep in the dungeon** when a siege lands. That collision is the whole point of the game (§3), so how an *absent* player's siege resolves is load-bearing:

- **Present (live):** the siege plays out in the village in real time; the player fights beside the heroes and warriors (✅ the live siege exists in `siege_manager`).
- **Away → AUTO-RESOLVE + report (decided 2026-07-17):** if the player is in the dungeon, the siege **resolves on its own** as a fair contest of your defense (warrior count × Blacksmith arms × wall HP × the three heroes) vs the wave, and the **outcome is written to the Village Log** (§5.9): *repelled*, or *breached — N dead, M buildings damaged.* You come home to the consequences — the game **never yanks you out of the dungeon and never pauses it.** That is the squeeze in its purest form: you *chose* to be down here, and the village lived or died on the defense you left behind. The **Watchtower** (§7.1) is how you buy the foresight to time your delves between known sieges; without it, every run is a blind gamble against a wall you can't see.

### 7.5 Aftermath — and the doom-spiral ✅ built (death-shock waves + corruption live)

- **Repelled:** repair any wall damage (Builderhouse), heal the wounded (Hospital), pay the small morale cost of any losses, and you're back to the loop stronger.
- **Breached:** deaths trigger the **death-shock morale crash** (§10) across the survivors → the shaken may **corrupt** → the loss compounds into the **corruption cascade**. A catastrophic siege can tip a stressed town over the edge and unravel real, hours-earned progress. **This failure state is the reason the entire village machine exists** — every chain in §5.7 is ultimately about making sure the wall holds and, when it doesn't, that the town is healthy enough to absorb the blow rather than eat itself.

### 7.6 The squeeze scaling — why prosperity raises the pressure (✅ core / 📋 curve)

- Siege **size and strength scale with village health/prosperity** (a *living* village insults Despair, §2.5) **and with depth** (how far the player has pushed). The healthier and deeper you are, the worse the nights — *the squeeze is the design, not a bug.*
- This is the **DEPTH pressure on the dependency ladder** (§5.7.1): rising siege strength is exactly what forces the Barracks→Blacksmith→Mine chain online, then the day/night shifts, then Government automation. **The siege is the clock the whole village races.** It is, in effect, the *boss fight of the village sim* — it tests every chain you've built at once.
- Numbers live in code (`siege_manager`: BASE_COUNT 3 → MAX_COUNT 12, HP/DMG per tier); the curve is a balance-pass, but the rule never changes: **always winnable for an attentive player, always punishing for a neglectful one.**
- 🟡 Open (§12): only the **numbers** now — the exact health×depth → siege-tier curve. (Directionality = **both flanks**, breach targeting = **nearest-first**, away resolution = **auto-resolve + Log** are all decided, §7.2/§7.4.)

---

## 8. The Ten — the capstone hostages (new canon, designed 2026-07-15)

Every frozen hostage is someone whose hope refused to die (§2.2) — but hope has degrees, and most of the rescued can still be worn down by a hard life afterwards. **The Ten are the apex: the truly unbreakable.** Deep in the dungeon, past where the leadership VIPs end, Orin keeps them as his **trophies**: ten legends of the broken age he has personally tried to break for years — and never once cracked. Despair finds no purchase in them at all, and that fascinates and enrages him. He keeps them close, still trying.

**That immunity is the point:** when the Harvest comes and every soul in Deepwood turns, **the Ten do not turn.** They are the heroes who stand with you at the end.

Each is found in a hidden **Trophy Vault** on a non-boss floor (so they're discoveries, not boss loot), spread across **floors 22–63**. *(Moved earlier from 52–99, dev decision 2026-07-20: boons that automate and transform the village must arrive with half the game left to enjoy them. Balance-first order: defense and healing first, Toren right after his Forge unlocks at depth 35, the gold engines in the 40s, Mirielle's automation at 47, and Ilo still LAST — his unfinished songs remain the foreshadowing nearest the reveal.)* Each rescue permanently transforms one village system — these are the "unusually impactful once freed" rescues the vision always promised.

> **Why Orin keeps his trophies this shallow:** leaving them findable is part of the calculated generosity (§2.5). The Ten are village-peak fuel — he *wants* them found.

| # | Name & title | Vault floor | Village boon (permanent) |
|---|---|---|---|
| 1 | **Brannoc, the Wall That Stood** — last Warchief of the old realm | 22 | Warriors train 2× faster; walls +50% max HP; he personally leads the night shift |
| 2 | **Maera, the Last Lightmender** | 26 | Nurse heal range/speed doubled; once per siege she stabilizes a villager who would have died |
| 3 | **Toren Ashvale, the Forgefather** | 38 | Blacksmith can forge **Epic**-grade (one above the Rare cap); crafting costs −25% |
| 4 | **Sylvara, Warden of the Old Groves** | 31 | Farm output doubled; rare herbs begin growing in the overworld |
| 5 | **Kaldos, the Tidecaller** | 34 | Dock deep-catches yield materials as well as food; food-variety morale bonus |
| 6 | **Elenwe, Archivist of the Broken Age** | 53 | All unknown materials auto-researched; Lab research 2× ; she speaks lore of the Monarchs |
| 7 | **Dorian Vail, the Coinbinder** | 43 | Bank interest doubled; on player death, half the dropped gold is insured (returned) |
| 8 | **Mirielle, Voice of the Old Crown** | 47 | Government automation takes a major leap; taxes no longer cost morale |
| 9 | **Seraphel, the Lightkeeper** | 58 | Shrine cleansing faster & cheaper; her aura slows corruption HP-drain village-wide |
| 10 | **Ilo, the Nameless Bard** | 63 | Bar/Tavern morale way up — and he *sings fragments of the Age of Monarchs*, the game's clearest foreshadowing; at the gate of 100, he is the one who names what stirs in you |

Status: ✅ ALL TEN BUILT (vaults on canon floors, boons live at real hooks). Rescuing **all Ten is part of the finale gate** (§9.1).

---

## 9. The Finale — "The Harvest" (full canon, updated 2026-07-15)

*This section replaces every earlier ending draft, including STORY.md's "the village corners Orin" climax. The developer's decision: the Harvest happens — and the Shadow Army answers it.*

### 9.1 The trigger — the empty throne and the feast ✅ REBUILT (canon rework 2026-07-20, dev decision)
*The old perfect-village checklist gate is gone.* Floor 100 opens like any floor once 99 is cleared — **and stands EMPTY.** No horde, no throne-guard; the player searches the silent hall and carries the only possible conclusion home: *the evil is finished.*

The **false victory** is the trigger, and it is Orin's final move of theater: the village erupts, tables drag into the square, and hope hits its true peak — **the feast fires only when the deep is truly empty: floors cleared AND all Ten home** (nobody celebrates while their brother still hangs below — and this guarantees the Soul Split Wand, gifted on the tenth rescue, is in hand; Elenwe returns it at the reveal if it was ever set down). The peak is no longer demanded by a menu — **Orin engineers it, because the higher the hope, the harder the fall.**

### 9.2 The reveal — at the feast ✅ built (`Story.REVEAL_AT_FEAST`, harvest_director.gd)
Lightning kills the lanterns at the height of the joy. Orin, the only figure still smiling, names himself — the Monarch of Despair, the harvest, the whole patient theater. Your bond *flashes* — not facts, a feeling: *you have faced this power before. You have lost to it before.* A short exchange passes — quiet, almost courteous, two monarchs recognizing each other at last. And around you, the people of Deepwood **kneel to him as their hope dies** — and begin to turn. **The Harvest is fought in the village: through your own streets, past your own buildings.** (Mid-Harvest, the dungeon refuses entry — you cannot run from this.)

### 9.3 The turn — the Harvest ✅ built
This was never just harvest — it's theater, staged for an audience of one. Orin wanted you to build it *so it would hurt.* And the weapon is not brute force — **it is the truth.** In one instant the village learns that the hero who bled for them every night IS the thing that took their families; the story that kept them standing collapses, and Orin's magic rides that collapse, driving every heart's hope to **0 at once** — the Law of Despair (§2.2) executed on a whole town in a single breath. Everyone — farmers you fed, children you raised, soldiers you trained — becomes hopeless, falls into despair, and transforms into strong, level-100-tier evil that attacks you. **No survivors, no loyal holdouts... except the Ten**, whose hope not even this can kill. They stand with you — ten lights in a town gone dark.
- Population at full staffing realistically **~150–200+** (computed from role slots at build time). **Never spawn them at once — stream as waves.** You *feel* the whole town turning; the engine stays smooth.

### 9.4 The Devourer race ✅ built
Orin's final form — the **Monarch of Despair unmasked** — starts *weak* (nerfed personal attacks). His power is **earned by eating the horde**: he devours the *living* transformed over time; every **5% of the population consumed = +1 power tier** (bigger, more HP, more damage; ~20 tiers possible).
- **Your kills deny him fuel** — every transformed villager you cut down is one he can't eat. Rush the horde and you starve his growth but drown in bodies; turtle and he becomes a titan. Pure player agency; tuned so a strong player downs him at ~30–50% absorbed, a slow one faces a monster — **but it stays winnable.**
- **The Ten hold lanes** — each fights in character (Brannoc anchors, Maera keeps you standing, Seraphel slows the tide...). They are help, not a solution.
- **Theme:** the bigger the village you built, the bigger the monster it can become. *You built your own final boss.*

### 9.5 The kill — divide the soul ✅ built (the wand, the window, the reform)
*An undivided soul cannot be destroyed* — so you divide it. The **Soul Split Wand** (§9.7) — the joke item that splits anything into 7 harmless mini-clones for 4 seconds — is useless against every creature in the game except one: **the Monarch of Despair's 7 fragments ARE damageable.** Splitting him opens a 4-second burst window where the deathless thing is, for the first and only time, mortal. You strike the soul itself. **Despair ends.**

### 9.6 The return — and the Shadow Army (new canon 2026-07-15)
In the final blow the seal breaks. Power floods back, memory with it — the throne, the name, the ancient war. **You reclaim your true Shadow Monarch form** (the 7/7 manifestation the fight already forced). And you look at what victory cost: the village dead around you, all but ten.

Then the Shadow Monarch's **final ability unlocks — SHADOW ARMY:** you raise **every fallen villager as a shadow.** Not husks — *themselves*, continued: they keep their names, faces, homes, jobs, and bonds, re-made in shadow-form. **The stronger the person was in life, the stronger the shadow** — a legendary Warchief rises as a greater shade than a farmhand, and shadow variants differ by who they were (worker-shades, warrior-shades, leader-shades). The village Orin murdered gets back up — as the Shadow Monarch's people. The Ten remain living, flesh and blood among the shadows — the memory of what Deepwood was.

Deepwood stands, and it is yours to lead — a god-king with a mortal's heart, ruling the first city of the dead that is still, stubbornly, *alive*. One Monarch is destroyed. Somewhere beyond this world, the **Monarch of War** waits. *(That reckoning is another story — a future game.)*

### 9.7 Signature item — the Soul Split Wand ✅ built (gifted by the Ten; §12.2 quest placement open)
A quest-reward novelty weapon, *deliberately useless* everywhere, that becomes the answer to the one fight it was made for.
- Fires a bolt; the target **splits into 7 mini-clones** (~0.38× scale) that scatter, spin, and **snap back together after 4 seconds**. While split, normal targets are **invulnerable** — on every regular mob it's purely visual, a disco-split joke.
- **The sole exception:** the Monarch of Despair — his fragments are damageable (§9.5).
- Single-target on hit; `duplicate()` the procedural node tree ×7 (works on every enemy since all visuals are polygon trees); 20s cooldown, ~15 mana.
- 🟡 Where the quest that awards it lives → §12.

### 9.8 Foreshadowing checklist ✅ planted (kneel echo, the taunt, songs, lore, pallor, the candle)
- Orin's tribute is suspiciously generous; his "defense" never quite ends the threat.
- Cryptic dungeon notes in the deep floors.
- A taunt (mid-game) that Orin *wants* you to grow.
- Ilo's unfinished songs (§8) + Elenwe's Monarch lore (§8).
- The hidden passive (§6): the player's own creeping pallor is foreshadowing the *other* reveal.
- The taken kneel-and-turn at the gate is pre-echoed once, small, in a mid-game siege (one enemy bows to the horizon before dying) — blink and you miss it.

---

## 10. Corruption — despair made mechanical ✅ v2 ENABLED (2026-07-19: two fates, the rot window, infection firewalls, witness waves)

**Lore (the Law of Despair, §2.2):** no one is born evil — evil is a broken person, and **morale is hope.** A villager whose morale hits **0** becomes hopeless, falls into despair, and turns **demonic** — the same kind of creature as the dungeon's — attacking the village from within. Every rescued villager already resisted the fall of Deepwood once (§2.2), but hope that survived a catastrophe can still be *eroded* by neglect — hunger, homelessness, joylessness. The dungeon and the village share one villain: *untended despair.* (And the finale, §9.3, is this same law executed on the whole town at once — the corruption system IS the foreshadowing of the ending.)

- Transformation **only at morale 0**; neglect (hunger, homelessness, no joy) drains HP/morale past a grace window with a grey "rot" telegraph; fixing the need in time **redeems** them (nobody turns).
- **What it turns INTO:** a villager at morale 0 becomes a **random non-boss evil** of the same kind the dungeon spawns, now loose *inside the walls* and attacking the village.
- **The chain reaction — proximity infection (refined 2026-07-17):** a fresh turning doesn't just shock morale globally — it **infects nearby villagers by their own morale state.** A neighbour whose morale is **already low** is dragged to 0 and **turns too** — which infects *their* neighbours — a spreading powder-keg cascade. A neighbour with **healthy morale resists** and does **not** turn, *unless something else is also draining them* (hunger, no home, no joy) — then the nearby turning is the push that finishes the job. So corruption spreads fastest exactly where the village is already neglected, and a well-fed, housed, entertained town **firewalls** it: healthy neighbours are the breakers that stop the chain. **This is why the player is forced to keep the whole village cared for — neglect anywhere lets the town eat itself and undo your progress.** (The finale §9.3 is this same cascade with the morale floor kicked out from under *everyone* at once.)
- **Death shock — the other despair vector (decided 2026-07-17):** a villager **dying near others hits their morale HARD** (not instantly fatal, but heavy), and the shock **spreads slowly outward** — from the witnesses to *their* nearby neighbours, a diminishing wave. It stacks: a *single* death is a bad day, but **~5–6 deaths close to a 10/10 villager drop them to roughly 1–2** (≈ −1.5 each to close witnesses, TBD). That is how a lost siege becomes a corruption cascade — the deaths crush morale, the crushed morale corrupts the survivors, which kills more. The doom spiral is intentional. Distinct from infection above: death-shock is a **morale hit that lands regardless of the witness's current morale** (it can *set up* a corruption), whereas infection (above) only converts the already-low.
- **The presence of the fallen drains hope — but SLOWLY:** a **corrupted villager loose among the living**, or the dead left lying in the village, steadily **saps the morale of nearby villagers** just by being there. This drain is **deliberately gentle — a trickle, not an accelerant** — precisely so a *single* death or one loose demon can **never** chain-wipe the whole town; it's a reason to clean up (put the turned down / Shrine-cleanse them, clear the dead) with some urgency, not an instant spiral. The *sharp* morale damage is the death-shock above; this is the lingering unease that follows if you leave a mess.
- **A destroyed wall costs morale — but modestly:** each wall side fully broken is a morale hit to the village, *not too much* on its own (a bad omen, not a catastrophe); the real morale damage is the **deaths** that a breached wall then lets happen.
- **Children corrupt far more easily than adults:** they scare easier and feel harder, so a child's morale drains faster under neglect/shock and they hit 0 (corrupt) sooner. Raising kids is powerful (§5.4) but they are the **fragile** hearts a careless siege breaks first.
- **Warriors cannot corrupt** — they don't break, they **die in battle.** A Barracks Warrior is exempt from the corruption path entirely; their failure state is a soldier's death (which then death-shocks the town, above).
- **Corruption is not sickness** (§5.16). Despair is a morale failure that produces a *demon*; the sickness is physical, contagious, spreads by proximity of homes rather than by morale, and simply kills. They share only the death-shock they both feed. Warriors are exempt from the first and **not** from the second.
- 🟡 Open (§12): exact infection radius + "already low" threshold + spread rate; the per-death morale hit and its outward-falloff; the corrupted-presence drain rate; the wall-break morale cost; how much faster children drain — all numbers-pass; the mechanic shapes are decided.
- **Shrine redemption** ✅ built: from depth 30, a put-down demon that was once a villager is cleansed back by staffed Lightkeepers for 3 Sorrowshards (Seraphel: they return steadier).
- ✅ `CORRUPTION_ENABLED = true` since 2026-07-19 — every support system it needed (needs, personal morale, nurses, the Log) shipped first.

---

## 11. Post-game — the Shadow Court

- **The world continues after victory:** the shadow-village functions (shadow villagers work their old jobs), the Ten live on, sieges are over — Despair is dead. The player leads Deepwood as its Monarch. *(Peaceful sandbox; remaining bonds/quests completable.)*
- **The Shadow Monarch class unlocks permanently** (`game_completed`, own save file ✅ wired) — "the most OP class," playable from a fresh run: you, finally unmasked from floor 1.
- **NG+ ✅ built (THE REWOUND HOUR):** among the victory spoils is **time-reversal loot** — the world rewinds for a new run but **the player and their gear are immune**: you keep yourself and everything you carry. Clean prestige loop.
- **100% completion** = every villager rescued, every bond quest done, all Ten freed, full skill graph explored, village fully restored, Despair destroyed, Shadow Army raised.
- ✅ A "true ending" that breaks the NG+ cycle — **built** (2026-07-25): the Rewound Hour offers **turn it** (rewind) or **shatter it** (end the cycle for good → `GameState.cycle_broken`, no future hourglass, `Story.TRUE_ENDING`). See §12.4.

---

## 12. OPEN — every remaining decision, in one place

*(Nothing anywhere else in this book is open. When one of these is decided, move it into its section and delete it here.)*

1. **Shadow Monarch class kit** — ✅ BUILT & VERIFIED (2026-07-28): the `nc_*` graph (Legion / Dominion / Ascendant) wired to real effects, structurally guarded by `test_skilltree_node`, plus its two Wukong roads (§4.4). Closed.
2. **Soul Split Wand quest** — which quest line awards it, and how the game teaches "this is a joke item" without spoiling that it will matter.
3. **Post-game shadow-village depth** — ✅ DECIDED & BUILT (2026-07-25): shadow villagers are **needless** — morale fixed at 10, never hungry, never rot, never wither, immune to a neighbour's turning; raised whole (full HP, no rot clock). Fully pledged to the Monarch. (`game_state.gd`: gated on `v.get("shadow")` in `personal_morale_target`, `food_consumption_per_hour`, `tick_rot`, the starve/wither loop, `_spread_infection`, `raise_shadow_army`.)
4. **"True ending" / breaking the NG+ cycle** — ✅ DECIDED & BUILT (2026-07-25): the Rewound Hour, used post-victory, opens a two-road `ChoicePrompt` — **turn it** (rewind/NG+, the existing loop) or **shatter it** (a doubled confirm → `GameState.break_the_cycle`: `cycle_broken` saved, both hourglass-grant sites guarded so none ever drops again, `Story.TRUE_ENDING` plays, and Deepwood stands un-rewound forever). New `choice_prompt.gd`.
5. **Numbers pass** — ✅ DONE (2026-07-28): `tool_balance_sim.gd` scenarios S1–S13 measure every deferred constant against this book's stated intent and stand permanent guard. Tuned to intent: the **death-shock** (six funerals now take a 10/10 town to a ~2 trough — §12.16's exact shape — healing by day five) and **children's half-rations** (§12.17, decided-but-never-built until S12 caught it). Proven right as built: economy/wages/interest, the siege health×depth curve (attentive holds at five depths, neglected breaches at all), upgrade sink, tree costs, the Doctor's ledger, the Watchtower's act-priced tiers, the corruption firewall, the Wanderer's welcome. The Devourer curve and the Ten's boons stand as hand-set canon.
6. **The three defenders' fate** — ✅ DECIDED (2026-07-20, delegated): **Wren and Castor turn at the Harvest; Roland alone holds.** The two who named the cage become its proof — they walk in the horde at floor 100 as named, outsized transformed, and their deaths are real (the corps loses them). Roland — the one who said *"we hold this village"* — proves that hope can be FORGED by the player's campaign: he arrives at the gate of 100 as an eleventh ally beside the Ten, mortal and outmatched and standing anyway. The gut-punch lands twice and the thesis survives once.
7. **"Leaving Deepwood"** — ✅ DECIDED (2026-07-20, delegated): the exit is an **actually attemptable, escalating gauntlet**. The first attempt stays the scripted near-death (§2.4.1 beat 3). Every retry after it spawns a REAL wave that doubles (4 → 8 → 16 → 24 cap, scaled to siege tier) — clearable, and clearing it only teaches the lesson in second person: *"the dark ahead of it has already doubled."* The road never opens; once Despair is dead, the ward is simply gone.
8. **The Doctor & the three defenders — names.** ✅ DONE: the Doctor is **Maren Hollis**; the defenders are **Roland, Wren and Castor** (their fates: §12.6).
9. **Role-roll numbers (§5.4)** — ✅ MOSTLY DECIDED (2026-07-20, delegated): the default table ships (Farm 25 / Fishing 20 / Tavern 20 / Smith, Merchant, Miner 8 / Doctor 7 / Scholar, Banker 6). **Weight-tuning is FAVOUR-A-CALLING:** from School level 2, the hands-on key at the School cycles one favoured calling; its weight runs ×(1 + 0.5 per level above 1), hard-capped at **40% of the table — never 100%**, so the dice never fully leave. Residual (open): targeted re-education and a pity floor.
10. **The Building Web wiring (§5.7)** — MECHANIC shape decided (independent early → interdependent under pressure; the chains and per-building purposes are canon). Open: the exact **ore/metal resource ids** (new item vs reuse stone + a metal tier), the **depth/pressure point each dependency "switches on"** (when bare warriors stop sufficing and the Barracks *needs* Blacksmith arms, etc.), whether the **Mine** is hand-buildable from Act I or gated, and the **Shrine's staffing role**.
11. **Corruption cascade numbers (§10)** — ✅ DONE (2026-07-28): ENABLED and proven as-built by sim S9 — a cared-for town resists a turning outright; a strained town chains (three dragged under by one). Radius 240 / "already low" < 3.0 / push −2 stand as canon, guarded.
12. **Economy revision fallout (§5.6)** — DECIDED: gold is made by only Government (taxes) + Bank (interest) + a Bar trickle + the dungeon; per-building passive gold is removed (a code change). **Marketplace = the Wanderer's Post** (§5.6a); **Fishing Dock kept distinct as premium food** (§5.7). Remaining open: the Wanderer's Post morale→(dwell,discount) curve + loot tables + Merchant-staff effect; whether "**decorations**" is a real morale sub-system or folds into morale; exact tax/interest/wage/food numbers. All numbers-pass; the mechanics are decided.

### Gaps found in the village/NPC gap-audit (2026-07-17) — need a decision before building the village loop
13. **HOUSING — ✅ DECIDED (§5.8).** Cottage = one pair, occupied until death, built from materials, caps population; Tavern lodges the unhoused temporarily; Housing added as a Need (§5.5). Residual (§5.8): where singles/children sleep, family-cottage upgrades, Warrior housing.
14. **MORALE MODEL — ✅ DECIDED (§5.5b).** Personal morale per villager (drives that villager's own corruption/death); the displayed meter + Wanderer's Post + finale gate all read the **plain average** of everyone's personal morale — proportional, so a few in the red dip the mean only slightly while still dying/corrupting locally. Only numbers remain.
15. **VILLAGER INTERACTION VERBS — ✅ DECIDED (§5.10).** Canonical verb list written (Inspect, Assign/Reassign, Send to School, Draft to Barracks, Pair, Assign to Cottage, Re-pair, Heal, Bond quest), each with its gate; non-verbs noted (no exile, no separating a living pair, no hand-feeding). Open: Inspect as tooltip vs panel; player-arranged vs auto-courting pairing.
16. **VILLAGER DEATH — ✅ DECIDED (§10).** A death near others is a **hard morale hit that spreads outward** as a diminishing wave and stacks (~5–6 deaths ≈ a 10/10 → 1–2); it lands regardless of the witness's morale, so it *sets up* corruption — the doom spiral. Corrupted-presence and the dead lying around also drain nearby morale; a broken wall costs a modest morale hit. Only numbers remain (per-death hit, falloff, drain rates).
17. **WARRIORS & CHILDREN — ✅ DECIDED (§5.8, §10, §5.4).** Warriors: house + pair + eat like anyone, but **cannot corrupt — they die in battle**. Children: **eat ~half**, live in their parents' cottage until adult (then want a pair), and **corrupt far more easily** than adults. Only numbers remain (child drain multiplier).
18. **The Village Log (§5.9)** — feature DECIDED (press L, timestamped, newest-first, plain-language, new-player-friendly). Open: the exact event taxonomy (what's worth logging vs noise), retention window, and whether critical entries also raise a passive toast.
19. **The siege loop (§7.2–7.6)** — ✅ DECIDED. Wall holds = non-event / breaks = horde in the streets, **nearest-first**, → buildings + villagers → death-shock; besieged from **both flanks** (split your defense); away-sieges **auto-resolve + report to the Log** (never force-home, never pause the dungeon); three heroes + warriors + player defend; day/night shifts; Hospital recovery; scales with health × depth. Only the numbers curve (health×depth → siege tier, split of the wave between the two flanks) remains.

---

## 13. Governance — how this book is used

- **This file is the constitution.** `STORY.md` (narrative prose), `VILLAGE_SYSTEMS.md` (village deep-design), `GAME_OVERVIEW.md` / `PROJECT_SNAPSHOT.md` (implementation snapshots), and `ROADMAP.md` (director's log) remain as *references*, each carrying a banner pointing here. Where they disagree with this book, they are wrong.
- **Change protocol:** developer decides → this book is edited first → then code. A feature not in this book is not in the game.
- **Build order after this book is signed off** stays vertical-slice: finish needs/hospital/wages (§5.5) → Barracks shifts (§7) → Government automation (§5.1) → Shrine + corruption refinements (§10) → economy depth (§5.6) → the Ten (§8) → the Finale (§9) → post-game (§11).
- **Execution guardrails** (from VILLAGE_SYSTEMS §11, still binding): extend existing systems (`game_state.gd` morale, `npc.gd` villagers, `building.gd`), never fork parallel ones; never rewrite the save format (extend additively); headless-verify every change; don't touch dungeon balance or the L100 curves unless the task says so.

***Amended 2026-08-06 — THE CITY MACHINE.*** *Recorded after the fact under the change protocol; every item was dev-directed in-session and is verified against `game_state.gd` / `assign_ui.gd` / `special_plot.gd` / `event_boss.gd`. Two **standing laws** written down as law rather than intent: the **automation ladder** (§5.1a — every manual chore owes an heir; hands-on start, near self-running city by ~level 80, paced by rescue depth) and the **leader gate** (§5.13 — a building power requires its leader seated). New canon: the three **placement rules** (§5.11 — adjacency, districts, special plots, all positive-only and stacking through `building_output_multiplier`); **auras** (§5.12 — the first outward-pointing rule, measured off homes and workplaces, never wandering bodies); **building levels → named powers** (§5.13 — the numeric ladder shrunk deliberately to make room); the **closed population loop** (§5.14 — the `school_share` dial, the Chancellor who retires it, and roof-before-match lodging); **the Patrols** (§5.15 — the town's first reach outward, paid for in wall strength, with block creep that can take ten floors back); **sickness and fire** (§5.16 — the town's own emergencies, the first things a grown village produces *at* you, and fire as the second face of adjacency); and **THE ECLIPSE** (§4.5 — the rare recurring sky event and the gate on The Hollow Sun, the hardest fight in the game, fought in your own streets).*

*Living document. Last full revision: 2026-07-15. **Amended 2026-07-28** (the Terraria arc, recorded after the fact under the change protocol — every item below was dev-directed in-session): itemization rebuilt at scale (§4.3 — the 350-weapon census, the 8-tier ladder, Terraria-exact 3-slot armor + 12 relic slots, flagship riders, the Forge's daily imports, the procedural-chiptune audio pass); the Wukong roads + tree guards (§4.4); every boss's named phase two, depth-scaled restlessness, and the eleven hidden event bosses (§4.2); the Shadow Monarch stage table's stale 🔨 marks cleared (§6 — all seven powers long built; only the true-form art stays dev-gated); and the NUMBERS PASS closed (§12.5 — S1–S13 stand guard; death-shock and child rations tuned to this book's own stated shapes, the §12.1/#8/#11 items closed).*

*Previous revision trail: Last full revision 2026-07-15. Amended 2026-07-17: the arrival/opening sequence (§2.4.1), Orin's three-step introduction at ~L15 + starting NPC roster (§2.5.1), the Doctor early-healing mechanic (§5.5a), the Watchtower wave-warning progression (§7.1), and the School "role roll" — weighted-random professions with late-game weight-tuning (§5.4); the Building Web — every building's purpose + the dependency chains as one connected system, plus the new **Mine** (§5.7, roster now 16); and the corruption **proximity chain-reaction** (§10); the dependency-activation ladder (§5.7.1); and the **economy revision** — only Government + Bank (+ a Bar trickle + the dungeon) make gold, no per-building passive income, Marketplace repurposed as the **Wanderer's Post** — morale-priced rotating treasure-sellers (§5.6a) — and the Fishing Dock kept as premium food (§5.6); the **Rescue / Sorrow-Crystal** mechanic (§4.2a); and a **village/NPC gap-audit** logging 5 holes (§12 #13–17), of which **housing (§5.8 — cottages, one pair each, occupied until death) and the morale model (§5.5b — personal morale; the meter is the plain average) are now resolved**, plus the new **Village Log** (press L, §5.9); and the final three village gaps resolved — **death-shock morale** (§10, a spreading hit that stacks into the corruption doom-spiral), **warriors** (can't corrupt, die in battle) and **children** (eat half, live with parents, corrupt easily), and the **pairing/housing** numbers (single −2, widow −3 over 48h) (§5.8); and the **villager interaction verb list** (§5.10) — **completing the village gap-audit (all of §12 #13–17 resolved)**; the **siege loop** moment-to-moment (§7.2–7.6 — wall holds/breaks, defenders, home-vs-away, aftermath doom-spiral, the squeeze scaling); and the decision to **keep "Monarch"** as a guarded late reveal (§2.1); art/PixelLab frozen until the mechanical + story side is finished (dev directive).*
