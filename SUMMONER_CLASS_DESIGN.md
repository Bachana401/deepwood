# DEEPWOOD — THE SUMMONER (4th class) — full design blueprint

> **Status: DESIGN — nothing here is built.** Written 2026-07-29 for dev review;
> the build follows this document batch by batch (the BOSSES.md / WEAPONS.md
> method: vocabulary first, each piece implemented uniquely, each proven
> headless before moving on).
>
> Sources studied for this design: `companion.gd` (the light-summoner engine this
> class extends), `weapon_roster.gd` (row format, tiers, fx/rider system),
> `skill_tree.gd` (branching-graph rules: tier-4 exclusive forks, evolving
> keystones, triggered ultimates, Wukong roads), `inventory.gd` (SET_DEFS,
> relic_power, GRADE_PASSIVES), `game_state.gd` (get_bonus_total pipeline,
> chosen_class, equipment), `player.gd` (_reconcile_companions, plant_sentry,
> skill hooks), `WEAPON_VERB_REFERENCE.md` §SUMMONS DEEP SCAN (60 weapons),
> `tool_marathon_sim.gd` / `tool_balance_sim.gd`, and the audit kit.
>
> **House rules that bind every section:** similar-never-1:1 (Terraria is the
> mechanical reference, never the text); difficulty from mechanics, never
> one-shots; every effect key must have a READER (the named-but-never-read
> passive is the known trap — tool_promise_audit gates it); art is last
> (procedural Polygon2D bodies first, PixelLab skins later with frame-by-frame
> QC); the working tree lies — clean-clone verify every landed batch.

---

## 1. Class identity & fantasy

Deepwood's story is a rescue: the taken are *named people* whose hope would not
die, and every rescue is a light coming back on. A summoner belongs in this
world only if the summons ARE that story. Three identity options:

### Option A — **The Bondcaller** (hope answers) ⭐ RECOMMENDED
The Bondcaller carries the village with them. Their summons are **wardens woven
from answered hope** — every creature at their side is a promise made flesh: a
hound with a farmer's patience, a candle with a doctor's vigil, a serpent that
grows one coil for every soul brought home. Where the **Shadow Monarch binds
the dead** (endgame, army of shades), the Bondcaller is **answered by the
living** — the two summon fantasies never overlap: one is a king commanding
the fallen, the other a shepherd the village fights *beside*.

- Narrative hook: the class reads as the village-rescue pillar personified —
  "you never descend alone, because Deepwood goes with you."
- Mechanical hook: whip-and-pack play (mark the foe, the bond answers) is the
  ACTIVE summoner — never an idle turret watcher.
- The word "Bondcaller" is display flavor; the code key stays `"Summoner"`
  (TREES / chosen_class / marathon sim all use the plain key, like "Sword").

### Option B — The Beastwright of the Wilds
A tamer of Deepwood's own fauna — the east-road wilds and the Underdark supply
the bestiary (hounds, cave bats, thornmothers). Grounded and legible, but the
weakest narrative tie: the wilds are Despair's ground, and taming its creatures
muddies the Law of Despair (monsters are fallen PEOPLE — befriending them
undercuts the lore).

### Option C — The Lantern-Shepherd
Herds candle-spirits of the village hearths; light-vs-despair made literal.
Beautiful, but collides with imagery already spent: wands own the
candle/wisp/lantern space (Wisp Warden, Candlekeeper, Watchfire, the wisp
companion), and building_lights owns hearth-fire at home.

**Recommendation: Option A wearing Option B's shapes.** The bonds of hope take
beast forms (hound, bat, serpent, spider) — Deepwood-mythic bodies, none of
them "tamed monsters," all of them summoned promises. Class color: worn amber /
bone-ivory `Color(0.82, 0.62, 0.3)` — hearth-gold against the Mage's violet and
the Monarch's green-black.

---

## 2. The weapon class — summon items in the roster

### 2.1 The three summon families (new roster `class` strings)

The roster row format (`[id, name, class, tier, behavior, damage, cooldown,
extras]`) extends with three new class strings and three new behaviors. Note
`"staff"` is TAKEN (the Wukong melee staff) — the summon caller is a
**scepter**.

| roster class | behavior | weapon_type | what it does |
|---|---|---|---|
| `scepter` | `minion` | `summon` | Cast (mana) to summon a **persistent minion** into a slot. Re-cast fills the next free slot (or re-flavors an occupied one). Minions persist across weapon swaps and floors — the scepter only needs to stay in your bag. |
| `whip` | `whipcrack` | `whip` | The **active weapon**: a long thin arc swing (reuses the melee swing path with a whip-shaped hitbox + Line2D ribbon visual). Every hit **TAGS** the target — the pack refocuses and hits harder (§2.2). |
| `totem` | `post` | `summon` | A **stationed guardian** planted where you stand, permanent until replaced (vs. the existing WAND `sentry` behavior, which stays a *timed* totem — the two families coexist and differ exactly there). Posts occupy their own post slots (§4.2). |

**Engine base:** `companion.gd` is already the minion chassis — hover slots,
strike-out/come-home states, `_find_mark` over the three hostile groups, damage
through `take_damage` like everything else. The class extends it (new kinds,
slot economy, tag priority, damage from the pipeline instead of a static def
value) rather than forking it. `player._reconcile_companions` grows from
"carriers only" into the summon ledger: carriers (existing behavior, unchanged)
+ the cast-summon roster (new).

### 2.2 THE TAG SYSTEM (the whip loop — the class's active heart)

Adapted from the scan's whip-tag economy, never 1:1:

- A whip hit paints **the BOND-MARK** on the struck foe: an amber sigil ring
  (reuses the golden_gaze/brand marker visual path with its own color).
- **One mark at a time** — a new tag moves the mark (choosing the target IS the
  skill). Duration 4s, refreshed by hitting the same foe.
- While a foe is marked: **all your summons prefer it** (`_find_mark` checks the
  mark first, distance second) and every summon hit gains **+tag damage
  (flat, from the whip) and +tag crit chance** (whip- and tree-donated).
- Bosses are taggable — the mark is damage-focus, not CC (respects the boss
  rule: DoT yes, hard CC no).
- Per-whip **tag riders** make each whip a different verb (§2.4): detonate the
  next summon hit, chain lightning off the mark, chill it, shake coin loose...
- The Shadow Monarch's shades also *prefer* the marked foe (the Golden Gaze
  precedent: "everything that serves you") but do **not** receive the flat tag
  damage — the Monarch's balance stays untouched (never-nerf rule).

### 2.3 Damage & pacing philosophy

Terraria's law, Deepwood's numbers: **whip raw damage stays modest** (a fast
melee at ~70% of its tier's sword) — the power lives in the tag and the army.
Minion dps per slot lands near a same-tier wand bolt's dps × 0.6, so a 3-slot
pack + whip ≈ one geared melee of the tier, and slot growth is the power curve.
Nothing may one-shot; a full 8-slot endgame horde must still respect the L100
soft-cap curves (never touch those).

### 2.4 The T1–T8 roster slice — 38 weapons

All names fresh, all cousins of scanned verbs, similar-never-1:1. Row extras
use new knobs: `m_kind` (minion body), `m_gap` (attack cadence), `tag_dmg` /
`tag_crit` (whip donation), `tag_fx` (whip rider), `s_kind` (post archetype).
Cards carry a readable soul line each (the `_fx_desc` rule).

#### SCEPTERS — 17 (persistent minions)

| id | name | tier | verb (cousin of) | dmg | gap |
|---|---|---|---|---|---|
| `smn_smallloyalty` | A Small Loyalty | 1 | clay mudling hops and bodies into foes (bouncing slime) | 5 | 1.9 |
| `smn_fledgling` | The Fledgling | 1 | finch that divebombs and loops home (divebombing bird) | 6 | 2.0 |
| `smn_quietpair` | The Quiet Congregation | 2 | chapel-bat on a FIXED elliptical loop — metronome reliability, never chases (dash-orbit bats) | 7 | 1.6 |
| `smn_keeperofone` | Keeper of One | 2 | ONE ghost-warden; each re-cast EMPOWERS her instead of adding; roots while striking (empowered single ghost) | 11 | 1.8 |
| `smn_emberward` | Emberward | 3 | hearth-imp lobbing embers that burn (fireball imp) | 9 | 1.7 |
| `smn_thestray` | The Stray | 3 | shade-hound pouncer, stays low, ground-runner (beast kin — the existing body, promoted) | 12 | 1.8 |
| `smn_broodmother` | Thornmother's Brood | 4 | spiderlings LATCH and drip venom, hang on for seconds (latching venom spiders) | 6×2 | 1.5 |
| `smn_ferrytoll` | The Ferryman's Toll | 4 | drifting lantern-wisp lobbing slow seeking motes (soul_stream — the wisp, promoted) | 12 | 1.7 |
| `smn_growinghunt` | The Growing Hunt | 5 | cast again to EVOLVE, not multiply: cub → hound → dire at 2/4 casts, form breaks visible (merging tiger / stack-to-evolve) | 16→ | 1.6 |
| `smn_twinsorrows` | Twin Sorrows | 5 | a twin pair — one rams, one lances light from above (mini twin pair) | 10+10 | 1.7 |
| `smn_blinklantern` | The Lantern That Blinks | 6 | lantern-eye TELEPORTS above the mark and snipes — never out of position (teleport-snipe UFO) | 21 | 1.5 |
| `smn_sawpsalm` | Sawtooth Psalm | 6 | whirring saw-sphere that rams through bodies, pierce identity (saw-sphere ram) | 18 | 1.4 |
| `smn_clingchoir` | The Clinging Choir | 7 | cells that LATCH the mark, stack a DoT, and seeker-shoot whatever YOU whip (latching cells + shoot-what-player-hits) | 8/s | — |
| `smn_deepkennel` | Kennel of the Deep | 7 | a dire pack of two hounds with cross-terrain pounce (cross-terrain pouncer) | 20×2 | 1.6 |
| `smn_procession` | The Long Procession | 8 | ONE grave-serpent that GROWS a coil per cast — visible segments are its level; noclip coiling through terrain (growing segmented dragon) | 24/coil | — |
| `smn_unerring` | The Unerring | 8 | blades of light in formation that NEVER whiff — flagship `rider`; drops only from a boss killed without taking a hit (skill-gated flawless drop) | 26 | 1.3 |
| `smn_hundredthname` | The Hundredth Name | 8 | for every 10 villagers currently ALIVE at home, +4% minion damage — the village literally fights with you (colony-native, no cousin) | 22 | 1.5 |

#### WHIPS — 13 (the active weapon)

| id | name | tier | tag rider (cousin of) | dmg | cd |
|---|---|---|---|---|---|
| `whp_firstlesson` | First Lesson | 1 | starter switch; consecutive hits quicken your swing +8%/hit ×3 (whip-speed ramp) | 6 | 0.5 |
| `whp_willowword` | The Willow Word | 2 | longer reach, tag_dmg 3 — the plain teacher | 8 | 0.48 |
| `whp_wordofiron` | A Word of Iron | 3 | tag_dmg 4, tag_crit +5% — the first crit donor (tag crit donor) | 10 | 0.46 |
| `whp_droversanswer` | The Drover's Answer | 3 | wide slow arc, heavy knockback — herds the pack's prey into place | 14 | 0.7 |
| `whp_candlewick` | Candlewick | 4 | the marked foe's NEXT summon hit DETONATES ×2.4 (mark-detonation; favors heavy minions) | 12 | 0.5 |
| `whp_coldrein` | The Cold Rein | 4 | tags CHILL; a frost-sprite mini-minion forms on tag, 3 max (snowflake spawner) | 11 | 0.5 |
| `whp_stormlash` | Stormlash | 5 | hits on the mark build charge; at 3, lightning CHAINS off it to the near (dark-energy chains) | 14 | 0.48 |
| `whp_tallystring` | The Tallyman's String | 5 | tagged foes killed by summons shake coin loose (goldtouch economy, colony-native) | 13 | 0.46 |
| `whp_sunderpsalm` | Sundering Psalm | 6 | consecutive hits ramp whip SPEED to double — frenzy that must be fed (stacking whip-speed) | 15 | 0.5 |
| `whp_mothersmercy` | Mother's Mercy | 6 | summon hits on your mark MEND the pack (and the Bond first) | 14 | 0.48 |
| `whp_reapingverse` | The Reaping Verse | 7 | kills on the mark ERUPT dark energy that leaps to and tags the next foe (on-kill AoE chains — the tag propagates itself) | 17 | 0.46 |
| `whp_morningbell` | Morning Bell | 7 | tag_dmg 12, tag_crit +8% — the heavy donor; its crack RINGS (audible metronome) | 18 | 0.52 |
| `whp_tencourt` | The Ten-Tongued Court | 8 | flagship `rider`: ten-tailed ribbon, tag_dmg 18, tag_crit +10%, and the mark persists 6s — the Kaleidoscope-kin crown | 20 | 0.44 |

#### TOTEMS — 8 (stationed posts; permanent until replaced)

| id | name | tier | verb (cousin of) | dmg |
|---|---|---|---|---|
| `pst_watchingstone` | The Watching Stone | 2 | eye-carved stone loosing straight bolts (eye-bolt statue) | 8 |
| `pst_bramblepost` | The Bramble Post | 3 | sows self-rearming ground snares (self-rearming mines) | 14 |
| `pst_standingthorn` | The Standing Thorn | 4 | ballista post; goes BERSERK (×3 rate, 4s) when the PLAYER is struck — the defender fantasy (panic turret) | 16 |
| `pst_stormbell` | The Storm Bell | 5 | a tolling zone of standing lightning that ignores armor; tag bonus applies at half inside it (defense-ignoring tick zone, 50% tag tax) | 7/tick |
| `pst_eggkeeper` | The Egg-Keeper | 6 | lobs eggs that HATCH into brief spiderlings — a post that feeds the horde (egg-lobbing spider queen) | 12+ |
| `pst_wintersthree` | Winter's Three Mouths | 7 | three-headed frost fount, cones that chill and stack (frost hydra) | 18 |
| `pst_doorwatches` | The Door That Watches | 8 | a standing rift sweeping a slow infinite-pierce beam through a 60° arc (portal beam sweep) | 24 |
| `pst_quietsister` | The Quiet Sister | 5 | heals YOU and your minions in a small radius instead of striking — the doctor's promise, standing (no cousin; colony-native) | mend 3/s |

**Tier spread of the slice** (drops ride `TIER_FLOORS` unchanged): T1 ×3,
T2 ×4, T3 ×5, T4 ×5, T5 ×6, T6 ×5, T7 ×5, T8 ×5 = **38**. The 80%-replacement
wave later grows the class to full parity (§5).

**Mana costs:** scepters `10 + 3×tier` per cast, posts `14 + 3×tier` per plant
(the standing army is paid for up front — no upkeep, §4.4). Whips cost nothing.

---

## 3. The skill tree — "Summoner", the full branching graph

Per the house rules: ONE tree that branches into 3 specs; every spec forks at
**tier 4 into a mutually-exclusive keystone pair** (exclusive groups `sm0/sm1/
sm2` — pick one, the other locks forever, enforced even in sandbox); keystones
**evolve** the earlier mechanic; **tier 7 is a triggered ultimate**, not a stat
bundle; plus two Wukong-style `road` side nodes. Materials follow the standard
ladder (slime → iron_shard → ember_crystal → void_essence → ancient_relic).

```
BRANCH_NAMES  "Summoner": ["Hordecaller", "Bondmaster", "Wallwarden"]
CLASS_COLORS  "Summoner": Color(0.82, 0.62, 0.3)
```

**Root** — `sm_root` (col 2.5, tier 0, cost 1): *"The First Calling"* — +8%
summon damage, +5% whip damage. `{summon_damage: 0.08, whip_damage: 0.05}`

### Spec 0 — HORDECALLER (col 0.5 spine; the swarm-count spec)

| id | tier | col | name / mechanic | cost | prereq | materials | effect |
|---|---|---|---|---|---|---|---|
| sm_h1 | 1 | 0.5 | **Open Kennels** — +1 minion slot | 1 | sm_root | — | `summon_cap: 1` |
| sm_h2 | 2 | 0.5 | **Sharpened Pack** — +20% summon damage | 1 | sm_h1 | — | `summon_damage: 0.20` |
| sm_h3 | 3 | 0.5 | KEYSTONE **The Full Kennel** — +1 slot, casts cost 20% less mana | 2 | sm_h2 | slime 3 | `summon_cap: 1, summon_mana_cut: 0.20` |
| sm_h4a | 4 | 0.0 | FORK **The Numberless** — +2 slots: overwhelm with bodies | 3 | sm_h3 | iron_shard 2 | `summon_cap: 2` ⊗sm0 |
| sm_h4b | 4 | 1.0 | FORK **Pack Law** — +8% summon damage per living minion: fewer, hungrier | 3 | sm_h3 | iron_shard 2 | `pack_law: 0.08` ⊗sm0 |
| sm_h5 | 5 | 0.5 | **Fed and Furious** — +25% summon damage, +25 HP | 2 | [sm_h4a, sm_h4b] | ember_crystal 1 | `summon_damage: 0.25, max_health: 25` |
| sm_h6 | 6 | 0.5 | KEYSTONE **Tide of Teeth** (evolves the kennel) — +1 slot, and your pack FRENZIES at the mark: +30% strike rate vs tagged foes | 4 | sm_h5 | void_essence 2 | `summon_cap: 1, tag_frenzy: 0.30` |
| sm_h7 | 7 | 0.5 | ULTIMATE **The Hundred Hands** (triggered) — a summon's kill has a 35% chance to call a short-lived ECHO-minion (8s, up to 4 standing). +30% summon damage. The horde refuses arithmetic. | 6 | sm_h6 | void_essence 3, ancient_relic 2 | `horde_echo: 0.35, summon_damage: 0.30` |

### Spec 1 — BONDMASTER (col 2.5 spine; the single-evolving-companion spec)

| id | tier | col | name / mechanic | cost | prereq | materials | effect |
|---|---|---|---|---|---|---|---|
| sm_b1 | 1 | 2.5 | **A Steady Hand** — +15% summon damage, +10% whip damage | 1 | sm_root | — | `summon_damage: 0.15, whip_damage: 0.10` |
| sm_b2 | 2 | 2.5 | **Longer Leash** — minions range and return 25% farther/faster | 1 | sm_b1 | — | `leash_bonus: 0.25` |
| sm_b3 | 3 | 2.5 | KEYSTONE **The First Bond** — your first slot becomes THE BOND: one named companion that GROWS with its kills this run (+2% damage each, ×25) | 2 | sm_b2 | slime 3 | `bond_unlock: 1, bond_growth: 0.02` |
| sm_b4a | 4 | 2.0 | FORK **Fang of the Bond** — the Bond EXECUTES tagged non-bosses below 12% HP | 3 | sm_b3 | ember_crystal 2 | `bond_execute: 0.12` ⊗sm1 |
| sm_b4b | 4 | 3.0 | FORK **Shield of the Bond** — the Bond guards: intercepts 15% of damage aimed at you, +40 HP | 3 | sm_b3 | ember_crystal 2 | `bond_guard: 0.15, max_health: 40` ⊗sm1 |
| sm_b5 | 5 | 2.5 | **Two of One Mind** — +20% summon damage, +6% crit for summon hits | 2 | [sm_b4a, sm_b4b] | ember_crystal 1 | `summon_damage: 0.20, tag_crit: 0.06` |
| sm_b6 | 6 | 2.5 | KEYSTONE **Form Break** (evolves the Bond) — at 10/20 kills the Bond BREAKS FORM: bigger body, +40% damage, and its strikes splash | 4 | sm_b5 | void_essence 2 | `bond_form: 1, bond_damage: 0.40` |
| sm_b7 | 7 | 2.5 | ULTIMATE **No Grave for the Faithful** (triggered) — when YOU are struck, the Bond instantly avenges at 250%; when the Bond falls, it is REBORN at your side in 3s, +25% (stacks ×3 per fight). | 6 | sm_b6 | void_essence 3, ancient_relic 2 | `bond_avenge: 2.5, bond_reborn: 1` |

### Spec 2 — WALLWARDEN (col 4.5 spine; sentries + village-defense synergy)

| id | tier | col | name / mechanic | cost | prereq | materials | effect |
|---|---|---|---|---|---|---|---|
| sm_w1 | 1 | 4.5 | **Groundwork** — +20% post damage | 1 | sm_root | — | `post_damage: 0.20` |
| sm_w2 | 2 | 4.5 | **Deep Footings** — posts take 50% less damage from bosses' zone abilities, +25 HP | 1 | sm_w1 | — | `post_tough: 0.50, max_health: 25` |
| sm_w3 | 3 | 4.5 | KEYSTONE **The Second Post** — +1 standing post (2 total) | 2 | sm_w2 | slime 3 | `post_cap: 1` |
| sm_w4a | 4 | 4.0 | FORK **Bastion Row** — enemies near your posts are SLOWED; +40 HP: ground you hold | 3 | sm_w3 | iron_shard 2 | `post_bastion: 0.35, max_health: 40` ⊗sm2 |
| sm_w4b | 4 | 5.0 | FORK **The Long Shot** — +35% post damage and post shots PIERCE: artillery | 3 | sm_w3 | iron_shard 2 | `post_damage: 0.35, post_pierce: 1` ⊗sm2 |
| sm_w5 | 5 | 4.5 | **Garrison Discipline** — +20% post damage, +15% summon damage | 2 | [sm_w4a, sm_w4b] | ember_crystal 1 | `post_damage: 0.20, summon_damage: 0.15` |
| sm_w6 | 6 | 4.5 | KEYSTONE **The Watch Eternal** (evolves posts) — +1 post (3), posts REDEPLOY themselves when you change floors, and during a LIVE siege your posts auto-man the rampart | 4 | sm_w5 | void_essence 2 | `post_cap: 1, post_persist: 1, post_garrison: 1` |
| sm_w7 | 7 | 4.5 | ULTIMATE **The Posts Do Not Sleep** (triggered) — when you OR the wall takes a hit, every post goes BERSERK: double rate for 5s. +25% post damage. | 6 | sm_w6 | void_essence 3, ancient_relic 2 | `post_berserk: 5.0, post_damage: 0.25` |

### The two roads (side nodes, the Wukong pattern — `road: true`)

| id | tier | col | name / mechanic | cost | prereq | materials | effect |
|---|---|---|---|---|---|---|---|
| sm_rd1 | 2 | 1.5 | **The Cracking Rhythm** — consecutive whip hits quicken your arm: +10% whip speed per hit, ×3, decays in 2s. The whip is a drum. | 2 | sm_h1 | slime 2 | `whip_frenzy: 0.10` |
| sm_rd2 | 3 | 5.5 | **The Shepherd's Whistle** — press Z: RECALL the pack to orbit you as a 1.5s ward that eats enemy projectiles, then they lash outward. (12s cooldown) | 2 | sm_w1 | iron_shard 2 | `whistle: 1.0` |

*(Z is free for non-Mage classes — Riftweaving is a Mage road; per-class
binding, same key, no conflict.)*

---

## 4. Systems integration

### 4.1 New effect keys and their READERS (the promise-audit contract)

Every key below lands in `GameState.get_skill_total` via node effects and flows
through **`get_bonus_total`** (skill + equipment + set bonus + weapon grade
passive + monarch bonus — no new pipeline). The reader column is binding:
a key without its reader may not merge.

| effect key | read by |
|---|---|
| `summon_damage`, `summon_cooldown` | `companion.gd` `_land`/`_loose_mote` (damage computed at strike time: `base × (1 + get_bonus_total("summon_damage"))`), post scripts |
| `whip_damage`, `whip_cooldown` | `player.skill_damage_mult` / `skill_cooldown_mult` — new `"whip"` weapon_type branch beside melee/bow/wand |
| `summon_cap`, `post_cap` | `player._reconcile_companions` (slot budget), `plant_post` |
| `tag_damage`, `tag_crit`, `tag_frenzy` | `companion._land` when target carries the bond-mark |
| `summon_mana_cut` | scepter/totem cast cost in `player.perform_attack` |
| `pack_law` | `companion._land` (multiplier from living-minion count) |
| `leash_bonus` | `companion` LEASH / return speed |
| `bond_unlock`, `bond_growth`, `bond_execute`, `bond_guard`, `bond_form`, `bond_damage`, `bond_avenge`, `bond_reborn` | `companion.gd` bond branch + `player.take_damage` (guard/avenge hooks) |
| `post_damage`, `post_tough`, `post_bastion`, `post_pierce`, `post_persist`, `post_garrison`, `post_berserk` | the post script (one script, `s_kind`-branched, modeled on `sentry_totem.gd`) + `siege_manager` (garrison) |
| `horde_echo` | `companion.die`/kill hook |
| `whip_frenzy`, `whistle` | `player.gd` (swing cadence; Z handler) |

### 4.2 The minion slot economy

| source | slots |
|---|---|
| base (any scepter in the bag, class chosen) | 1 |
| tree: sm_h1 / sm_h3 / sm_h6 | +1 / +1 / +1 |
| tree fork sm_h4a (Numberless) | +2 |
| class relic (§4.5) | +1 |
| armor set full-soul (§4.6) | +1 |
| T8 scepter native (`The Long Procession` counts coils, not slots; others +1) | +1 |
| **hard cap** (`MINION_HARD_CAP`, perf + readability) | **9** |

A non-Horde build sits at 2–4 slots; full-send Horde reaches 8–9. **Posts are a
separate budget:** 1 base → 3 with the Wallwarden keystones. Carrier companions
(the existing blade/wisp/beast items) keep working for every class and do NOT
consume Summoner slots — they are guests, not subjects.

Perf note: a minion is a non-colliding Node2D with Polygon2D children (the
companion chassis) — 9 of them is nothing. **The 92-pixel rule is untouched:**
minions never collide with terrain or the player; beasts hug the ground line
via slot offset only. Nothing the class summons can ever block a jump lane.

### 4.3 Summon persistence & reconciliation

`player._reconcile_companions` becomes the one ledger with two sources:
1. **Carriers** (unchanged): wielded/equipped items with a `companion` field.
2. **The summon roster** (new): `GameState.active_summons` — an array of
   `{scepter_id, kind}` written by casting, capped by the slot budget,
   reaped when the scepter leaves the inventory (source_id discipline,
   exactly like carriers today).

Save: `active_summons` rides `capture_player_state` + `save_game`/`load_game`
with a `[]` default — **old saves load clean** (missing-key defaults are the
house save-compat pattern). On load, minions re-summon silently and free.

### 4.4 Mana, or a new resource?

**Recommendation: MANA, cast-cost only — no new resource, no upkeep, no
reservation.**
- The game's whole economy of casting already runs on the mana orb
  (`hud_orb`); a second bar fights the Terraria-tight HUD for no design win.
- Upfront cost + slot budget is the summoner's real limiter (Terraria's own
  model); upkeep/reservation punishes exactly the fantasy (a standing army)
  and would poison the Mage-tree mana keys' meaning.
- Rejected alternative, recorded: a "Bond charge" meter fed by whip hits that
  pays for summons. It double-taxes the active loop (whip already feeds tags)
  and adds a bar. If the class ever needs a late-game sink, revisit as a
  T8-only mechanic — not at launch.

### 4.5 Class-aligned relic

`relic_kennelbrand` — **The Kennel Brand** (epic; The Standing Star's big
sibling): `equip_effect {max_health: 30}`, `summon_cap +1`, and a relic_power
`packmend` — *"when a summon strikes your marked foe, you heal 1"* (the
active-summoner sustain loop, tag-gated so it never idles). Grade evolution per
the WEAPONS.md relic rule: higher-grade versions found deeper heal harder and
add +tag_damage.

### 4.6 Class armor set + set-soul

`SET_DEFS["bondwarden"]` — **The Bondwarden's Vestments** (epic, 3-piece:
`helm_bondwarden / armor_bondwarden / pants_bondwarden`):
- 2pc: `{summon_damage: 0.10}` — "+10% Summon DMG"
- 3pc: `{summon_damage: 0.15, max_health: 30}` + set-soul **PACKLAW** (the
  TEMPER/DEADEYE/SOULTHREAD pattern, triggered and readable on the card):
  *"when you TAG a foe, every summon you command instantly strikes it once"*
  — the alpha-strike that makes tagging feel like a command word.
- set weapon: `whp_candlewick` (the detonation whip — set + soul + whip =
  the burst combo you can read).
- full_bonus (set + weapon wielded): `{summon_cap: 1, tag_damage: 4}`.

### 4.7 Class picker, reset potion, starter kit

- `skill_tree_ui.rebuild_class_choice` list becomes
  `["Sword", "Archer", "Mage", "Summoner", "Shadow Monarch"]` — Summoner is a
  **launch class**, never gated (only the Monarch stays completion-locked).
- `SkillTreeData.BRANCH_NAMES/CLASS_COLORS/TREES` gain the "Summoner" entries
  (§3). The reset potion and free class-switch flows need **zero changes** —
  `chosen_class` is already a plain string and `reset_skills` is generic.
- On first choosing Summoner, `_on_class_chosen` grants the starter bundle:
  `whp_firstlesson` + `smn_smallloyalty` (the other classes' starters already
  exist in the world; the Summoner's tools must exist to play the class at
  all). Both are also ordinary T1 drops for everyone.

### 4.8 Sims and audits (the measuring instruments learn the class)

- `tool_marathon_sim.gd`: add `run_marathon("Summoner", false)` — the 4.5h
  dev-report per class must include the new tree's material chokepoints (the
  slime/ember checks that caught Mage's).
- `tool_balance_sim.gd`: model the class dps as
  `whip_dps + Σ(minion_dps × 0.85 uptime) + tag_amplification`, tier by tier,
  against the same curves the other three face.
- `tool_weapon_audit.gd`: scepters/whips/totems enter the dominance scan
  (whips are `gimmick` rows — tag power excuses modest raw numbers, same as
  javelin_volley today).
- `tool_promise_audit.gd`: every §4.1 key + every card line must be READ
  somewhere — the named-but-never-read passive is the class's biggest build
  risk (16 new keys) and this audit is the gate.

### 4.9 Village synergy boundaries (so the colony sim stays honest)

- Wallwarden's `post_garrison` acts in **LIVE sieges only** — offline siege
  resolution (`resolve_siege_offline`) must NOT count posts, or the away-report
  math silently inflates (the lifetime-vs-per-run lesson).
- `The Hundredth Name` (T8 scepter) reads living villager count at strike
  time — read-only, no new coupling into village state.
- Posts may never be plantable inside the village outside sieges (no free
  standing defense that trivializes §3b early pressure).

---

## 5. The 4-class roster math (the 80%-replacement wave)

Today's census: **350 weapons** (271 generated roster rows — melee 91, spear
38, bow 59, wand 63, staff 20 — plus ~79 hand-authored legacy/exc/starters).
When the 80%-replacement wave lands, it should land as **four classes from the
start** so the Summoner is never a bolt-on. Proposed shape — **360 total**:

| tier | Sword (melee+spear+staff) | Archer (bow) | Mage (wand) | Summoner (scepter+whip+totem) | total |
|---|---|---|---|---|---|
| T1 | 10 | 7 | 7 | 6 | 30 |
| T2 | 12 | 9 | 11 | 8 | 40 |
| T3 | 17 | 13 | 14 | 11 | 55 |
| T4 | 18 | 13 | 16 | 11 | 58 |
| T5 | 16 | 12 | 14 | 10 | 52 |
| T6 | 14 | 11 | 13 | 10 | 48 |
| T7 | 13 | 10 | 10 | 9 | 42 |
| T8 | 11 | 8 | 9 | 7 | 35 |
| **totals** | **111** | **83** | **94** | **72** | **360** |

- The Summoner's 72 = the 38-weapon launch slice (§2.4) + 34 in the wave —
  proportional parity (~20%) with the three elder classes, not equality:
  a summon weapon carries more mechanics per row, so fewer rows carry the
  same variety (the wand class learned this with tomes).
- Within-Summoner split at 72: scepters 32, whips 24, totems 16.
- Flagship (`rider`) budget stays ~1 per class per top tier: the Summoner's
  are `smn_unerring`, `smn_procession`, `whp_tencourt`.
- Drop plumbing is untouched: rows ride `pool_for_level` and
  `roll_gear_drop` the moment they exist.

---

## 6. Implementation plan — ordered batches with gates

Every batch: headless suite green (baseline + the batch's new registered
tests — `all_test_files.txt` is static, REGISTER new files), audits 0,
then commit. EYES where a human-visible surface changed. Clean-clone verify
at the two marked points. Art is LAST (procedural bodies throughout;
PixelLab skins are a separate later session under the frame-QC forever-rule).

**Batch 1 — The engine (no content):**
`weapon_type "summon"/"whip"` in player.gd (swing path, cast path, mana costs),
the bond-mark primitive (apply/expire/visual on enemy+boss+special_mob via the
existing marker path), companion.gd extensions (slot budget, mark-first
targeting, pipeline damage, new `m_kind` bodies as stubs), the post script
(`s_kind`-branched, plant/replace/persist), `GameState.active_summons` +
save/load defaults.
*Gate:* new `test_summoner_node` (slots, tag focus+flat damage, persistence
across a floor swap, save round-trip, old-save default) + suite + save audit.

**Batch 2 — The roster slice (38 rows):**
the three class strings in weapon_roster.gd (`scepter/whip/totem` expansion
branches, palette `Color(0.85, 0.72, 0.45)`-family), all §2.4 rows with card
soul-lines, tag riders wired (`tag_fx`), the three flagship riders.
*Gate:* tool_weapon_audit + tool_promise_audit + fx audit clean; a per-verb
smoke test (every `m_kind`/`s_kind` spawns, strikes, and dies clean headless).

**Batch 3 — The tree:**
"Summoner" in TREES/BRANCH_NAMES/CLASS_COLORS, class picker + starter bundle,
the two roads, all §4.1 keys READ where the table says.
*Gate:* exclusive-fork test (sm0/sm1/sm2 lock correctly, sandbox included),
promise audit (16 keys), suite. **Clean-clone verify #1.**

**Batch 4 — Gear parity:**
The Kennel Brand relic, the Bondwarden set + PACKLAW set-soul + full_bonus,
craft recipes if the set follows the Forge pattern.
*Gate:* set/soul trigger test, tooltip/card audit, EYES armor walker rerun.

**Batch 5 — The instruments:**
marathon sim 4th run + balance sim class model; tune the slice's numbers from
the sim report (chokepoint materials, tier dps curve vs the soft-cap rule).
*Gate:* sim report reviewed; no tier where Summoner dps strays >15% from the
class median; L100 curves untouched.

**Batch 6 — The seams:**
`tool_eyes_summoner.gd` (hover slots, strike arcs, tag sigil, post plant, the
Bond's form break — screenshot walk), firstsession + fullarc walker reruns
(class-select now offers four), siege garrison LIVE-only check.
*Gate:* EYES pass reviewed by the dev, full suite, **clean-clone verify #2.**

Estimated shape: 6 batches, each commit-sized like the challenge-pass batches;
Batches 1–2 are the long poles (engine + 38 verbs); nothing in Batch 3+ blocks
parallel art sessions later.

---

*End of blueprint. Dev sign-offs wanted before Batch 1: (1) identity Option A
recommendation, (2) mana-not-new-resource call (§4.4), (3) the 360-roster split
(§5), (4) Summoner as a launch class vs. any unlock gating (§4.7 assumes
launch).*
