# THE PLAIN RUNGS — census and verdict
Audit of every weapon in `weapon_roster.gd` whose attack produces an **empty
special dict** — i.e. swinging it does nothing but a bare hit. Written
2026-07-30. No code was changed. Someone else implements from this document.

Method: `ROWS` (313 rows) read in full; behaviors cross-checked against the
`match` in `_special_for()` by extracting every case label and diffing it
against every behavior declared in a row. Craft chains read from
`Inventory.CRAFT_RECIPES`; invariants read from `test_weaponfx_node.gd`.

---

## 0. THE COUNT — 65 by design, 2 by accident

The 67 is right, but it is **two different problems wearing one number.**

**65 rows** declare `arc` / `thrust` / `shot` / `rapid`. Those four share one
branch that does nothing on purpose:

```gdscript
"arc", "thrust", "shot", "rapid":
    # the plain-body behaviors: their voice is stats, not a special
    pass
```

**2 more rows** declare a behavior that has **no branch at all**:

| id | name | class | tier | behavior | status |
|---|---|---|---|---|---|
| `wpn_inkbook` | Inkwell of Storms | wand | 4 | `ink` | **no case label anywhere** |
| `wpn_wakebook` | The Book of Wakes | wand | 6 | `wake` | **no case label anywhere** |

These are not plain rungs. They are **dead weapons, and they deal literally
zero damage.** `_expand` sets `"damage": dmg if wtype != "wand" else 0` — a
wand's swing damage is deliberately 0 because its whole output is supposed to
come from the special. With no special, `player.perform_attack` falls into its
fail-safe branch:

```gdscript
cast_wand_projectile({"type": "frost_shard", "damage": stats.damage, ...})
```

`stats.damage` is 0. A Mythic wand fires a zero-damage bolt for 18 mana. This
is the third instance of the same failure in this file — the comments on
`souls` and `storm_debt` document the previous two — and the reason the
dispatch audit keeps missing it is stated in the roster itself: *"a weapon with
no special is not something the dispatch audit can check."*

**Fix the two dead rows first, and fix the blind spot with them** (see §5).
Everything else in this document is about the 65.

---

## 1. THE CENSUS

`fx` column: only ONE of the 65 carries an fx rider (Apogee). `tell` = the one
thing that distinguishes this weapon from its neighbours in play — a status
rider, a pierce flag, or nothing. DPS = damage / cooldown, for the sameness
argument in §2.

### Tier 1 — COMMON, floors 1-9 (12 rows: arc 5, thrust 3, shot 3, rapid 1)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_oakcudgel` | Oak Cudgel | melee | arc | 8 | 0.55 | 14.5 | — | KEEP PLAIN |
| `wpn_mongrelknife` | Mongrel Knife | melee | arc | 5 | 0.28 | 17.9 | — | KEEP PLAIN |
| `wpn_barrelstave` | Barrel Stave | melee | arc | 7 | 0.45 | 15.6 | — | KEEP PLAIN |
| `wpn_rustfang` | Rustfang | melee | arc | 6 | 0.35 | 17.1 | poison | KEEP PLAIN |
| `wpn_hearthpoker` | Hearth Poker | melee | arc | 6 | 0.40 | 15.0 | — | KEEP PLAIN |
| `wpn_fencepike` | Fence Pike | spear | thrust | 9 | 0.80 | 11.3 | — | KEEP PLAIN |
| `wpn_eelspear` | Eelcatcher | spear | thrust | 7 | 0.60 | 11.7 | — | KEEP PLAIN |
| `wpn_haypike` | Haymaker's Pike | spear | thrust | 8 | 0.70 | 11.4 | — | KEEP PLAIN |
| `wpn_orchardbow` | Orchard Bow | bow | shot | 7 | 0.55 | 12.7 | — | KEEP PLAIN |
| `wpn_gutterbow` | Gutter Bow | bow | shot | 6 | 0.45 | 13.3 | — | KEEP PLAIN |
| `wpn_crowbow` | Crowchaser | bow | shot | 6 | 0.50 | 12.0 | — | KEEP PLAIN |
| `wpn_sparrowbow` | Sparrowhawk | bow | rapid | 4 | 0.25 | 16.0 | — | KEEP PLAIN |

### Tier 2 — UNCOMMON, floors 5-18 (13 rows: arc 5, thrust 4, shot 3, rapid 1)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_lanternblade` | Lanternblade | melee | arc | 10 | 0.45 | 22.2 | burn | KEEP PLAIN |
| `wpn_millsickle` | Mill Sickle | melee | arc | 9 | 0.32 | 28.1 | — | KEEP PLAIN |
| `wpn_bonepick` | Bonepick | melee | arc | 12 | 0.60 | 20.0 | — | KEEP PLAIN |
| `wpn_coldiron` | Cold Iron Edge | melee | arc | 11 | 0.50 | 22.0 | slow | KEEP PLAIN |
| `wpn_tannerknife` | Tanner's Long Knife | melee | arc | 9 | 0.30 | 30.0 | — | KEEP PLAIN |
| `wpn_boarspit` | Boarspit | spear | thrust | 12 | 0.75 | 16.0 | — | KEEP PLAIN |
| `wpn_wallpike` | Wallwatcher's Pike | spear | thrust | 14 | 0.95 | 14.7 | — | KEEP PLAIN |
| `wpn_ditchpike` | Ditchwarden | spear | thrust | 13 | 0.85 | 15.3 | — | KEEP PLAIN |
| `wpn_frostprong` | Frostbitten Prong | spear | thrust | 11 | 0.70 | 15.7 | slow | KEEP PLAIN |
| `wpn_ashbow` | Ashwood Bow | bow | shot | 10 | 0.50 | 20.0 | — | KEEP PLAIN |
| `wpn_bramblebow` | Bramblebow | bow | shot | 9 | 0.50 | 18.0 | poison | KEEP PLAIN |
| `wpn_emberdart` | Emberdart | bow | shot | 8 | 0.45 | 17.8 | burn | KEEP PLAIN |
| `wpn_stingerbow` | Stinger | bow | rapid | 5 | 0.22 | 22.7 | — | KEEP PLAIN |

### Tier 3 — RARE, floors 12-32 (12 rows: arc 4, thrust 4, shot 2, rapid 2)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_watchmansword` | Watchman's Justice | melee | arc | 15 | 0.50 | 30.0 | — | **VERB** |
| `wpn_adderfang` | Adderfang | melee | arc | 11 | 0.30 | 36.7 | poison | **VERB** |
| `wpn_sextonblade` | Sexton's Edge | melee | arc | 14 | 0.45 | 31.1 | — | **VERB** |
| `wpn_curseknife` | Cursewright's Knife | melee | arc | 10 | 0.28 | 35.7 | poison | **VERB** |
| `wpn_gatecleaver` | Gatecleaver | spear | thrust | 17 | 0.85 | 20.0 | — | **VERB** |
| `wpn_heronlance` | Heron Lance | spear | thrust | 14 | 0.60 | 23.3 | — | **VERB** |
| `wpn_harrowpike` | Harrower | spear | thrust | 16 | 0.80 | 20.0 | — | **VERB** |
| `wpn_lamplighter` | Lamplighter's Reach | spear | thrust | 13 | 0.60 | 21.7 | burn | **VERB** |
| `wpn_veilbow` | Veilpiercer | bow | shot | 16 | 0.60 | 26.7 | pierce | **VERB** |
| `wpn_shrikebow` | Shrikebow | bow | shot | 15 | 0.55 | 27.3 | — | **VERB** |
| `wpn_larkbow` | Lark's Reply | bow | rapid | 7 | 0.20 | 35.0 | — | **VERB** |
| `wpn_lightstep` | Lightstep | bow | rapid | 6 | 0.19 | 31.6 | — | **VERB** |

### Tier 4 — EPIC, floors 24-52 (13 rows: arc 4, thrust 4, shot 3, rapid 2)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_duskrender` | Duskrender | melee | arc | 19 | 0.45 | 42.2 | — | **VERB** |
| `wpn_vespersting` | Vesper Sting | melee | arc | 13 | 0.26 | 50.0 | poison | **VERB** |
| `wpn_eveningblade` | Evening's Empire | melee | arc | 18 | 0.42 | 42.9 | — | **VERB** |
| `wpn_palefang` | Palefang | melee | arc | 12 | 0.25 | 48.0 | slow | **VERB** |
| `wpn_sunderpike` | Sunder Pike | spear | thrust | 23 | 0.85 | 27.1 | — | **VERB** |
| `wpn_midnightlance` | Midnight Lance | spear | thrust | 19 | 0.60 | 31.7 | slow | **VERB** |
| `wpn_vigilpike` | Vigil Unbroken | spear | thrust | 22 | 0.82 | 26.8 | — | **VERB** |
| `wpn_winterreach` | Winter's Reach | spear | thrust | 18 | 0.60 | 30.0 | slow | **VERB** |
| `wpn_curfewbow` | Curfew Bow | bow | shot | 21 | 0.60 | 35.0 | pierce | **VERB** |
| `wpn_gravebow` | The Polite Reminder | bow | shot | 20 | 0.58 | 34.5 | pierce | **VERB** |
| `wpn_glasstring` | Glasstring | bow | shot | 17 | 0.50 | 34.0 | slow | **VERB** |
| `wpn_hummingbow` | Hummingbird | bow | rapid | 9 | 0.18 | 50.0 | — | **VERB** |
| `wpn_needlerain` | Needlerain | bow | rapid | 8 | 0.17 | 47.1 | — | **VERB** |

### Tier 5 — LEGENDARY, floors 42-72 (8 rows: arc 3, thrust 3, shot 1, rapid 1)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_daybreakedge` | Daybreak Edge | melee | arc | 24 | 0.42 | 57.1 | burn | **VERB** |
| `wpn_lastlantern` | The Last Lantern | melee | arc | 23 | 0.40 | 57.5 | burn | **VERB** |
| `wpn_asphodelknife` | Asphodel Kiss | melee | arc | 15 | 0.24 | 62.5 | poison | **VERB** |
| `wpn_finalverdict` | Final Verdict | spear | thrust | 29 | 0.80 | 36.3 | — | **VERB** |
| `wpn_borderpike` | Border of the Realm | spear | thrust | 28 | 0.78 | 35.9 | — | **VERB** |
| `wpn_moonreach` | Moonreach | spear | thrust | 23 | 0.58 | 39.7 | slow | **VERB** |
| `wpn_wintermark` | Wintermark | bow | shot | 26 | 0.58 | 44.8 | pierce+slow | **VERB** |
| `wpn_lastlark` | The Last Lark | bow | rapid | 11 | 0.16 | 68.8 | — | **VERB** |

### Tier 6 — MYTHIC, floors 58-88 (6 rows: arc 3, thrust 2, rapid 1)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_griefedge` | Grief Made Sharp | melee | arc | 30 | 0.40 | 75.0 | — | **VERB** |
| `wpn_requiemedge` | Requiem Edge | melee | arc | 29 | 0.38 | 76.3 | — | **VERB** |
| `wpn_sorrowfang` | Sorrowfang | melee | arc | 19 | 0.24 | 79.2 | poison | **VERB** |
| `wpn_horizonpike` | Horizon Pike | spear | thrust | 36 | 0.78 | 46.2 | — | **VERB** |
| `wpn_worldspike` | Worldspike | spear | thrust | 35 | 0.76 | 46.1 | — | **VERB** |
| `wpn_ghostrepeater` | Ghost Repeater | bow | rapid | 14 | 0.15 | 93.3 | — | **VERB** |

### Tier 7 — ASCENDED, floors 70-97 (1 row: thrust 1)

| id | name | class | beh | dmg | cd | dps | tell | verdict |
|---|---|---|---|---|---|---|---|---|
| `wpn_zenithpike` | Apogee | spear | thrust | 40 | 0.75 | 53.3 | **fx: duelist** | **VERB** |

### Tier 8 — MONARCH: none. The crown is clean.

### Totals

| tier | arc | thrust | shot | rapid | **total** | of which no tell at all |
|---|---|---|---|---|---|---|
| 1 | 5 | 3 | 3 | 1 | **12** | 11 |
| 2 | 5 | 4 | 3 | 1 | **13** | 8 |
| 3 | 4 | 4 | 2 | 2 | **12** | 8 |
| 4 | 4 | 4 | 3 | 2 | **13** | 6 |
| 5 | 3 | 3 | 1 | 1 | **8** | 3 |
| 6 | 3 | 2 | 0 | 1 | **6** | 5 |
| 7 | 0 | 1 | 0 | 0 | **1** | 0 |
| **all** | **24** | **21** | **12** | **8** | **65** | **41** |

**41 of the 65 have nothing at all** — no status, no pierce, no fx. Same
animation, same behavior, different numbers. That is the roster's honest floor.

---

## 2. THE ARGUMENT — where the line falls

### 2.1 The defence of plainness is real, and it is not what is happening

`study/DESIGN_LAWS.md` §1 is correct: a stat ladder is one animation rig
re-skinned, and it is honest **"provided each rung adds exactly ONE new
tell."** And these rows are not decorative filler — they are a *forge ladder*.
`Inventory.CRAFT_RECIPES` chains them into **23 families**, every rung
consuming its predecessor plus tier materials:

> Oak Cudgel → Gravekeeper's Spade → Adderfang → Sexton's Edge →
> Evening's Empire → The Eleventh Hour

That is a genuine progression system, and a weapon you will melt down in
twenty minutes does not need a bespoke engine. So far so good.

**The problem is that the law's condition is not being met.** 41 of 65 add
*zero* tells. The ladder law is being cited as cover for nothing happening.

### 2.2 The evidence, in two lines

The clearest way to see it is to put two *Mythic* weapons side by side.

| | dmg | cd | dps | motion |
|---|---|---|---|---|
| Grief Made Sharp (T6 melee) | 30 | 0.40 | **75.0** | plain arc |
| Requiem Edge (T6 melee) | 29 | 0.38 | **76.3** | plain arc |

| | dmg | cd | dps | motion |
|---|---|---|---|---|
| Horizon Pike (T6 spear) | 36 | 0.78 | **46.2** | plain thrust |
| Worldspike (T6 spear) | 35 | 0.76 | **46.1** | plain thrust |

Two Mythic swords 1.7% apart, two Mythic spears 0.2% apart, all four the same
animation, none carrying a tell of any kind. These are not rungs on a ladder.
They are **one object with two names, shipped twice.** No amount of ladder
theory defends that at the second-highest grade in the game.

And the longest run of it is the one a new player meets. One bow family:

> Sparrowhawk (T1) → Stinger (T2) → Shrikebow (T3) →
> The Polite Reminder (T4) → **The Last Lark (T5, Legendary)**

Five forge steps, T1 to Legendary, one bow animation the whole way, and
exactly **one** new tell across the entire run (a `pierce` flag at step 4).

### 2.3 So: the line is TIER 3

Not "T1 clubs are fine, everything else isn't" and not "rework all 65". The
useful line is the one the forge chains already draw:

> **A family may share one motion for its first two rungs. From the third
> rung on, every rung must change what you SEE.**

Which lands on tiers, because the chains climb through them:

- **T1 and T2 KEEP PLAIN — 25 weapons.** A copper sword and an iron sword
  swinging the same is the ladder law working, not laziness. The player is
  learning to jump, aim, and read the 92-pixel rule; a second weapon that
  introduces a mechanic is noise. Their input stays simple and their
  differentiation is **cadence + trail + impact**, which is art and juice,
  *not* a special dict and *not* engine work. See §3.
- **T3 and above NEED A VERB — 40 weapons.** By T3 the player has cleared
  a dozen floors, the item says *Rare*, and it costs materials to forge. A
  weapon at that price is entitled to give a reason to equip it over the last
  one, and "the number is bigger" is not a reason you can see.
- **Nothing at T5 or above may be plain, ever.** A Legendary that swings like
  a fence post is the roster's single biggest credibility hole. Fifteen
  weapons are currently in that state (8×T5, 6×T6, 1×T7).

**The owner's instinct is right, and the honest split is 25 / 40 — not 0 / 65
and not 40 / 25.** Keeping T1-T2 plain is worth defending out loud: it costs
nothing, it is the reference zero the whole ladder is measured against, and
inventing twelve gimmicks for wooden sticks would make the *first hour* busy
without making it good.

### 2.4 The spectacle budget (constraint 4, made concrete)

Every verb below is sized to its tier. This is the ladder to hold to:

| tier | scale of the effect | rule of thumb |
|---|---|---|
| T3 | **body-scale** | one extra beat, one extra shape, within a body-length |
| T4 | **lane-scale** | the effect owns the line in front of you |
| T5 | **room-scale** | the effect reaches a wall |
| T6 | **screen-scale** | the effect changes the whole fight |
| T7 | **off-screen** | the effect leaves the frame and comes back |

---

## 3. KEEP PLAIN — the 25, and what they still owe

T1 (12) and T2 (13). **No special dict. No fx. No new engine.** But the
one-tell-per-rung law still applies, and it can be paid entirely in art:

| axis | what changes per rung | cost |
|---|---|---|
| **trail** | the wake behind the swing/shaft — none → dust → soot → a thin bright line | art only (`DESIGN_LAWS` §6: "differentiate by wake, not projectile body") |
| **arc shape** | how wide and how fast the swing sweeps | one tween curve |
| **impact** | the hit-flash sprite: a puff, chips, a spark, a crack | `hit_fx.gd` variant |
| **sound** | wood thud → iron ring → a whistle | `sfx_synth.gd` |
| **cadence** | already differentiated and already readable | free |

Assign so no two weapons in one tier share the same trail. Concretely, the
five T1 melee arcs currently indistinguishable become: Oak Cudgel = a dull
dust puff · Barrel Stave = a splinter spray · Hearth Poker = an orange
ember-streak off the tip · Mongrel Knife = a thin fast glint · Rustfang = a
brown flake-off (which its poison already justifies). Five readable objects,
one animation, zero engine work.

**Names to watch, not fix.** Three T1/T2 names promise an event rather than an
object — Eelcatcher, Crowchaser, Sparrowhawk. They survive on cadence and
fiction and I would leave them. But if any T1/T2 name is ever found to promise
a verb it cannot pay, **rename it, do not build it.** The precedent is already
in this file at line 241: "Zenith" was a plain thrust rung wearing a
flagship's name, the dev went looking for the famous weapon four separate
times and found the wrong object, and the fix was a rename (→ Apogee), not an
engine.

---

## 4. NEEDS A VERB — the 40

Rules obeyed throughout: no stat bonuses; the effect is visible motion or
shape; name and material agree; readable at a glance; spectacle scales with
tier. Each entry names a suggested `behavior` key and the nearest existing
engine to reuse, so the cost is legible.

### Tier 3 — body-scale (12)

| weapon | THE VERB — what the player sees | key / reuse |
|---|---|---|
| **Watchman's Justice** | The swing throws a short bar of lantern-light straight ahead of the blade, and anything standing in the light takes the blow the steel never reached. | `lightbar` / `dawn_line` shrunk to one body-length |
| **Adderfang** | The strike is two strikes — the blade snaps out and back like a snake's head, so one swing lands a second, smaller bite a fifth of a second later. | `snakebite` / animation + delayed second tick |
| **Sexton's Edge** | The spade-edge scoops the floor as it swings and hurls a low fan of grave-dirt, chips and bone a body-length forward. | `gravefan` / `cluster` at ground level |
| **Cursewright's Knife** | Every cut writes a short glowing word in the air along the arc; the word hangs for a moment, then burns out into the wound. | `curseword` / delayed-payoff (§5, 0.5s) |
| **Gatecleaver** | The thrust is a pry — the point goes in and then levers up hard, lifting whatever it hit off the floor. | reuse the existing `knockup` extras key on a thrust |
| **Heron Lance** | The lance darts out and is *held* at full extension for a beat before it comes back, and it strikes again on the withdraw. | `heronstab` / boomerang law (the return pass hits) |
| **Harrower** | The point is driven into the floor and a short row of turned earth and stones erupts along the ground ahead of it. | `furrow` / `ground_thorn` at one-third scale |
| **Lamplighter's Reach** | The pole snaps out to twice its length in one motion, and where the wick at its tip touches, a small flame is left hanging in the air for a second or two. | `wicklight` / `stage_pike` (one stage) + `watch_fire` (tiny) |
| **Veilpiercer** | The shaft tears a thin standing slit of dark along its whole flight path, and the slit hangs for a second — anything that walks across the line it cut is cut again. | `veilslit` / aftermath line zone |
| **Shrikebow** | Arrows stick where they land, in bodies and in walls alike, and a wall bristling with shafts cuts whatever is pushed into it. | `shrikelarder` / `embedded_stack.gd` (already built) |
| **Lark's Reply** | Every shaft is answered a beat later by a second, smaller one from over your shoulder, so the stream you hear is always one longer than the stream you fired. | `larkreply` / a delayed second spawn (NOT the `echo` fx — see §5) |
| **Lightstep** | Each shot rocks you a short hop backward and the arrow leaves brighter for it, so a held stream walks you across the room in little skips. | `lightstep` / player impulse on fire (`DESIGN_LAWS` §9, player-state) |

### Tier 4 — lane-scale (13)

| weapon | THE VERB — what the player sees | key / reuse |
|---|---|---|
| **Duskrender** | The arc leaves a torn seam of dusk hanging where the blade passed, and the seam closes half a second later with a second, quieter cut along the same line. | `duskseam` / `lingering_arc` + a scheduled close |
| **Vesper Sting** | The blade strikes like an insect — three tiny stabs inside one swing, each on a slightly different line, so the wound is a cluster of punctures rather than a slash. | `vesperstab` / multi-hit swing (number-cloud, `DESIGN_LAWS` §7) |
| **Evening's Empire** | Each swing is wider than the last while you keep swinging — from a sword's length to most of the lane by the fourth blow — then it resets. | `empire` / growing swing area, the T4 ancestor of `long_tongue` |
| **Palefang** | Every hit leaves a white fang standing in the wound; when the third is set, all three shatter at once in a burst of cold. | `palefang` / `embedded_stack.gd` with a 3-cap overflow |
| **Sunder Pike** | The point strikes the *floor* instead of the body, and a crack runs forward from the impact throwing up a line of stone chips that catches everything standing on it. | `sunderline` / `sunder_wave` at one-third range |
| **Midnight Lance** | The lance goes out lit and comes back dark, and the lane it passed through stays unlit for a second — a black bar hanging in the room that keeps biting whatever stands in it. | `midnightbar` / lane aftermath zone |
| **Vigil Unbroken** | Hold the attack and the pike *stays* out, planted and unmoving; anything that walks onto the point while it is held is run through. | `vigil` / hold-channel plumbing from `prism_converge` |
| **Winter's Reach** | Frost runs out along the floor ahead of the point as it extends — a narrow tongue of ice a spear's length beyond the spear, and anything standing on it slides. | `frostreach` / `ice_sheet` narrowed |
| **Curfew Bow** | Loosing rings a curfew note, and where the arrow lands the light goes out in a circle for two seconds; nothing inside that dark can find you. | `curfew` / the existing `feared` state, in a radius |
| **The Polite Reminder** | The arrow taps — a small, apologetic hit — and then a folded paper note flutters down, settles on the body, and a second later goes off. | `politenote` / delayed payoff (`DESIGN_LAWS` §5, ~1.5s at high multiple). **This is the joke lane §10 asks for and the roster does not have.** |
| **Glasstring** | The shaft is glass and breaks on landing: a ring of glittering slivers sprays across the floor and lies there, cutting whatever walks over them. | `glassfall` / `cluster` + a floor hazard (`hazard.gd`) |
| **Hummingbird** | Hold the attack and you *hover* — the beat of the shafts holds you in the air, sinking slowly, for as long as you keep firing. | `hover` / player-state verb. Cap it: it may only slow a fall, never gain height. |
| **Needlerain** | The shafts do not fly flat — they go up in a short spray and come *down* as a drizzle of needles a body-length or two ahead of you. | `needledrizzle` / `rain_quill` at half scale. **The name has been promising rain and delivering a flat shot.** |

### Tier 5 — room-scale (8)

| weapon | THE VERB — what the player sees | key / reuse |
|---|---|---|
| **Daybreak Edge** | The first swing after a pause is a sunrise — the blade comes up from low and a bar of white light climbs with it, two body-heights, through everything in front of you. | `sunrise` / `dawn_line` at half the T7 height |
| **The Last Lantern** | Every swing sheds a drop of burning oil onto the floor, and a fight held in one spot leaves the ground under it alight. | `oilshed` / `watch_fire` pooling |
| **Asphodel Kiss** | Where the blade lands a small pale flower opens on the wound and stays; if the body dies still wearing flowers, they burst and seed the floor, and the seeded ground keeps poisoning. | `asphodelbloom` / `embedded_stack.gd` + `hazard.gd` on death |
| **Final Verdict** | The point stops dead for a moment, and then the whole thrust arrives at once as a single flat white line drawn from you to the far wall — everything on the line is judged together. | `verdictline` / instant hitscan, the T5 ancestor of `world_cut` (T8) |
| **Border of the Realm** | Each thrust plants a marker in the ground, and a line of light stretches between your last two markers and cuts everything it sweeps as it snaps taut. | `borderline` / the T5 ancestor of `harp_string` (T8) |
| **Moonreach** | The pike is driven straight *up*, and a shaft of cold moonlight comes down the line of it onto everything standing beside you. | `moonshaft` / **`DESIGN_LAWS` §8: "vertical thrust is the spear's exclusive verb" — and no Deepwood spear uses it yet.** The best untaken verb in the study. |
| **Wintermark** | The arrow paints a white frost sigil on whatever it hits, and every later arrow that lands on a marked body shatters the mark in a puff of ice. | `frostmark` / mark-and-consume as a *behavior*, not the `brand` fx |
| **The Last Lark** | The stream builds a song — every shaft a note higher than the last — and when the run reaches the top note, every arrow still in the air turns at once and dives on the nearest body. | `larksong` / `silent_note` cadence machinery. Fits the fastest bow in the game. |

### Tier 6 — screen-scale (6)

| weapon | THE VERB — what the player sees | key / reuse |
|---|---|---|
| **Grief Made Sharp** | Every blow you land pulls one more grey blade out of the air around you, up to six, and they hang in a ring copying your swing half a beat behind — until you stop, and they fall out of the air. | `griefring` / `patient_storm` (T8) accumulated instead of instant |
| **Requiem Edge** | Anything it kills stays standing a moment as a grey mourner, and your next swing passes through the mourners too — each one you cut throws its own copy of the swing outward. | `requiem` / kill-fed chorus; reuses the swing arc it already has |
| **Sorrowfang** | Every hit sheds a black drop that falls to the floor and spreads into a small pool, and the pools crawl toward each other and merge into one growing stain. | `sorrowpool` / `hazard.gd` zones that merge. The T6 ancestor of The Crown's Sorrow (T8). |
| **Horizon Pike** | The thrust does not stop — the pike telescopes out section after section until the point is at the far edge of the screen, cutting along its whole length, then folds back in one snap. | **See §5: the behavior key `horizonpike` already exists and belongs to a *different* weapon (The Kindly End). Give this engine to the weapon whose name it is.** |
| **Worldspike** | The pike is driven into the ground and the world tilts toward it — for two seconds every loose thing in the room slides toward the shaft as if it were downhill. | `worldaxis` / gravity-well as a behavior (not the `gravity` fx) |
| **Ghost Repeater** | Every shaft leaves a ghost of itself behind on the same line half a second later, so the lane fills with a second, translucent volley arriving after the first has passed. | `ghoststream` / delayed duplicate spawn. Fastest bow in the game; the name has always promised this. |

### Tier 7 — off-screen (1)

| weapon | THE VERB — what the player sees | key / reuse |
|---|---|---|
| **Apogee** | The thrust is aimed *up* and the pike leaves your hands entirely — it climbs out of the top of the screen, hangs at its apogee for a beat, and comes down point-first through everything in a wide column before returning to your grip. | `apogee` / vertical launch + `sky_pillar` descent. Keeps its `duelist` fx (T7 must carry exactly one rider). |

---

## 5. IMPLEMENTATION CONSTRAINTS — read before touching a row

These are invariants the repo already enforces. Breaking one turns the suite
red in a way that looks unrelated to the change.

**a) `PLAIN_QUOTA` is pinned at 129.** `test_weaponfx_node.gd:157` asserts the
number of `{"plain": true}` rows is *exactly* 129. Note that `plain: true` and
"plain behavior" are **not the same set**: 129 rows carry the flag, only 65
have an empty special (the other 64 have real behaviors like `cleave`,
`volley`, `bolt`). Of the 40 conversions proposed here, **39 carry the flag**
(Apogee does not). Converting all 40 means `PLAIN_QUOTA` → **90**.

**b) Converting a rung breaks its successor's craft chain.** The same test
requires every plain rung with a recipe to forge from *another plain weapon*
plus a material. These **9 links** break under the §4 conversions, because a
still-plain output would be forging from a now-verbed ingredient:

| still-plain output | ingredient being converted |
|---|---|
| `wpn_tithegather` | `wpn_curseknife` |
| `wpn_hourmaul` | `wpn_eveningblade` |
| `wpn_sapperanswer` | `wpn_curfewbow` |
| `wpn_sapperkiss` | `wpn_glasstring` |
| `wpn_larkstorm` | `wpn_veilbow` |
| `wpn_galeprong` | `wpn_harrowpike` |
| `wpn_hawkvolley` | `wpn_heronlance` |
| `wpn_marrowprong` | `wpn_lamplighter` |
| `wpn_reedvolley` | `wpn_gatecleaver` |

The clean fix is to stop conflating two ideas: add a `"rung": true` flag that
means *"belongs to a forge chain"* and survives a conversion, and point the
chain check at that instead of at `plain`. Then a rung can gain a verb without
the ladder falling apart. Do this **before** the first conversion, not after.

**c) No weapon below T7 may carry an fx rider.** `test_weaponfx_node.gd:215`
fails on any T1-T6 row with an `fx` entry ("the 80% cut holds"). Every verb in
§4 for tiers 3-6 must therefore be a **behavior**, never an fx. This is why
Lark's Reply gets a `larkreply` behavior rather than the `echo` fx, and
Wintermark a `frostmark` behavior rather than `brand`.

**d) T7-T8 must carry exactly one rider.** Apogee already has `duelist`. Keep
it at exactly one.

**e) The stacking trap.** Any persistent zone or minion whose lifetime exceeds
its cooldown can be stacked indefinitely — this already produced a 233 dps and
a 360 dps weapon against a tier median of ~80 (`study/REMAINING_TARGET.md`).
Of the verbs above, these need a one-instance cap where a recast *renews*
rather than adds: Lamplighter's Reach, Midnight Lance, Winter's Reach,
Curfew Bow, Glasstring, The Last Lantern, Asphodel Kiss, Border of the Realm,
Sorrowfang, Vigil Unbroken.

**f) Effect power scales automatically.** `verb_force(tier)` multiplies every
`damage`-suffixed key in the special by 1.0→1.6 across the ladder. Author each
verb's numbers at its own tier and let the function do the rest; do not
pre-scale.

**g) Fix the audit blind spot.** Add a static check that **every behavior
string in `ROWS` has a case label in `_special_for`**. Extracting the case
labels and diffing them against the declared behaviors takes one loop and
would have caught `ink`, `wake`, `souls` and `storm_debt` the day each shipped.
The dynamic dispatch audit structurally cannot: it only inspects weapons that
*have* a special.

**h) One naming-integrity fix, free of charge.** The behavior key
`"horizonpike"` (→ `stage_pike`, *"It does not thrust, it TELESCOPES"*) is used
by **The Kindly End**, while the weapon actually called **Horizon Pike** is a
plain thrust. This is the exact Zenith/Apogee trap again: a key named after a
weapon that does not use it. Give the telescoping engine to Horizon Pike and
author The Kindly End its own mercy verb, or rename the key. Do not leave it.

---

## 6. SUMMARY

| verdict | count |
|---|---|
| **KEEP PLAIN** (all of T1 and T2) | **25** |
| **NEEDS A VERB** (all of T3-T7) | **40** |
| **BROKEN, not plain — fix immediately** | **2** |
| total rows with an empty special | **67** |

The keeps are a real position, not a concession: 25 weapons across the first
18 floors that stay simple on purpose, differentiated by trail, impact and
cadence for zero engine cost. Everything from Rare upward earns its motion.

### The three most urgent

**1. Inkwell of Storms and The Book of Wakes deal zero damage.** Their
behavior keys (`ink`, `wake`) have no branch in `_special_for`, so the special
is empty, so `player.perform_attack` falls back to a bolt built from
`stats.damage` — which is hard-coded to 0 for wands. A T6 Mythic wand costs 18
mana and does nothing. This is a live bug, not a design question, and it is the
third time this exact failure has shipped in this file. Fix the two rows and
add the static behavior-coverage check in §5(g) so there is never a fourth.

**2. The seven high-tier hollows: the six T6 Mythics and Apogee (T7).** These
are the tiers the game is judged by, and they currently contain two pairs of
weapons that are the *same object twice* — Grief Made Sharp / Requiem Edge at
75.0 vs 76.3 dps, Horizon Pike / Worldspike at 46.2 vs 46.1 — both pairs with
no tell of any kind. Apogee is the only Ascended weapon in the game without a
verb, at a tier that is otherwise 90% done, and it is the weapon that already
sent the dev hunting four times for a flagship that turned out to be a fence
post. Six new behaviors and one vertical spear close the top of the ladder.

**3. The Sparrowhawk bow chain — five forge steps that change nothing.**
Sparrowhawk (T1) → Stinger (T2) → Shrikebow (T3) → The Polite Reminder (T4) →
The Last Lark (T5). Four crafts, T1 to Legendary, one animation, one new tell
in the entire run. It is the longest stretch in the game where upgrading is
invisible, and it is in the bow family a new player is most likely to follow.
Under §2.3 the last three rungs get verbs — the shrike's larder, the folded
note, and the lark's rising song — and the chain finally arrives somewhere.
