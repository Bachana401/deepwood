# DEEPWOOD — Itemization Overhaul (design)

> **Status: DESIGN — the plan the build follows, batch by batch, like BOSSES.md.**
> Nothing here is built yet. Written 2026-07-17 with the developer, whose brief:
> *"all weapons should be unique in many ways… shape / hitbox / combo / precision /
> amount / crit / auto-aim / etc., and graded accordingly. ~2× more weapons, fill
> the grades that need it, and everything ~15% stronger. Relics: no more plain
> vitality/mana/XP — creative effects that get better with grade."*
>
> The rule of the phase (from BOSSES.md): **design the vocabulary first, then
> implement each piece uniquely, each proven headless before moving on.**

The current catalog is [ITEMS.md](ITEMS.md) (120 items). This doc is how it grows.

---

## 1. The problem, measured

**Grade distribution is lopsided and bottom-starved:**

| grade | now | early-game feel |
|---|---|---|
| common | **7** | almost nothing but starters/tools/admin — no early variety |
| uncommon | 14 | thin |
| rare | 26 | bloated |
| epic | 16 | ok |
| legendary | 16 | ok |
| mythic | 22 | crowded |

**Weapons within a class are near-clones.** Every sword swings the same box
(`area_size ~60×36`), every bow fires one arrow at `reach 90`, every spear is one
long thrust. Damage and a name change; the *feel* doesn't. The `exc_` line has
unique effects, but the common/uncommon/rare weapons are stat-sticks.

**Relics lean on flat passives.** Vigor (+HP), Swiftness (+move), Greed (+gold),
Wisdom (+xp) — four of the first tier are one numeric nudge each. The *good*
relics (Phoenix cheat-death, Aegis block, Leviathan-style hooks) prove the engine
already supports **triggered** effects (`relic_power` + a hook in player.gd);
the tier just isn't using them.

---

## 2. The weapon-individuality vocabulary (the actual work)

A weapon is the sum of these dials. Two weapons of the same class must differ on
**several** at once (the boss forever-rule, applied to gear). Grade decides how
many dials are turned and how far.

| dial | what it varies | already in code? |
|---|---|---|
| **hitbox shape / size** | the swing/impact area (`area_size`) — wide cleave vs narrow stab vs tall overhead | ✅ field exists, underused |
| **reach** | how far in front it lands (`range_offset`) | ✅ |
| **attack speed** | cooldown → hits/sec | ✅ |
| **combo** | a multi-swing string (e.g. 3-hit finisher on the 3rd press), each hit its own box/damage | 🔨 NEW — the biggest missing dimension |
| **projectile count** | how many shots per attack (`special.count`) | ✅ (specials) |
| **spread / precision** | tight vs scattered fan (`spread_deg`); some weapons are pinpoint, some shotgun | ✅ |
| **pierce** | passes through foes vs stops on first | ✅ |
| **auto-aim / homing** | arrows that bend toward foes; or a melee that snaps to the nearest target | ✅ (homing) / 🔨 melee-snap NEW |
| **crit chance / crit damage** | a weapon can be a low-base high-crit gambler vs steady | ✅ (per-weapon `crit_chance`/`crit_mult` field NEW) |
| **knockback** | shove vs pull vs none | ✅ |
| **on-hit proc** | burn / poison / slow / **petrify** / lifesteal / mana / gold, chance-gated | ✅ (`on_hit_status`) |
| **mana cost** | wands trade mana for burst | ✅ |
| **movement rider** | dashes forward on swing, or roots you mid-cast | 🔨 NEW |

**Grade = how loud the identity is.** Common: one dial off-baseline. Uncommon: two.
Rare: a real gimmick (a special or a proc). Epic: gimmick + a set/combo identity.
Legendary/Mythic: a *signature* that reshapes how you fight (the `exc_` line).

---

## 3. The grade-fill plan (~2× weapons, balanced)

Target: bring every grade to a healthy ~24–32 items, filling **common and
uncommon hardest** (early variety is the worst gap). Roughly +48 weapons and a
handful of relics, landing near this shape:

| grade | now → target | mostly add |
|---|---|---|
| common | 7 → **~26** | early sidegrades: light/heavy sword variants, a crossbow, a sling, a torch, throwing knives, a quarterstaff — each with ONE clear dial (fast/wide/piercing/…) |
| uncommon | 14 → **~28** | first real gimmicks: a 2-hit combo blade, a scatter bow, a boomerang starter, a channel wand |
| rare | 26 → **~30** | (already rich) a few gap-fillers only |
| epic | 16 → **~28** | set/combo capstones incl. the **Sword & Archer set weapons** (§5) |
| legendary | 16 → **~26** | more `exc_` signatures across all 4 classes |
| mythic | 22 → **~28** | a few apex build-definers |

Each new weapon ships with its dials chosen from §2 so **no two share a
silhouette + moveset**. Every class (melee-sword, melee-spear, bow, wand) gets
new entries at every grade — right now wands are thin at low grades, spears are
thin everywhere.

---

## 4. The +15% power pass

Everything ~15% stronger, applied as the overhaul lands (not a blind sweep):
- **Weapon base damage +15%** (round to clean integers).
- **Relic / passive numeric values +15%** where they're a flat stat.
- New items are authored already at the buffed level.
- **Do NOT touch** the L100 boss HP/damage soft-cap curves (dev's standing rule) —
  this buffs the *player's* kit, which the boss ladder is already tuned to survive.

---

## 5. Two known gaps to close first

- **Bulwark Claymore & Windstalker Recurve** (the Sword & Archer set weapons) have
  NO special effect, while the Runeweave Scepter clears the screen. Give each a
  signature worthy of an epic set-capstone (e.g. Claymore: a shockwave cleave that
  widens with combo; Recurve: a charged multi-shot that pierces).
- **The three basic starters** (sword/spear/bow) are deliberately plain, but the
  player should be able to find *early sidegrades* fast — that's the common-grade fill.

---

## 6. Creative relics (no more flat stat-sticks)

New relics whose effect is a *mechanic*, and which **evolve with grade** — a
higher-grade version of the same relic does the thing harder or adds a rider.
Built on the existing `relic_power` + hook system (like Phoenix/Aegis).

| relic | effect | grade evolution |
|---|---|---|
| **Gorgon's Gaze** (Gargoyle's Head) | your hits build ‘petrify charge’; at full, the next struck foe is **turned to stone for 3s** (can't act, takes bonus damage), long internal CD | rare: 3s / longer CD → mythic: 4–5s, shorter CD, petrify can *chain* to one nearby foe. **Apex/undying bosses resist** (that's the "works on some, not others"). |
| **Harpoon Chain** | a periodic auto-**hook** yanks the nearest ranged/fleeing foe into melee | rare: single pull → legendary: pulls a small cluster, +stagger on land |
| **Ember Coil** | every Nth hit chains a fire arc to nearby foes | uncommon → epic: more chains, leaves burning ground |
| **Mirror Shard** | a chance to **reflect** an incoming projectile back | rare → mythic: reflected shots are empowered, chance rises |
| **Bloodpact Idol** | you deal more damage the lower YOUR health (risk build) | epic → mythic: bigger ramp + brief overheal on kill |
| **Timeworn Hourglass** | on taking lethal damage, **rewind** 2s to your prior position + HP | legendary → mythic: shorter CD, small heal on rewind |
| **Warden's Whistle** | summons a temporary spectral ally that taunts + fights | epic → mythic: two allies / stronger / longer |
| **Static Charge** | standing still briefly builds a shock nova that releases on your next hit | uncommon → epic: bigger nova, stuns |
| **Greedy Maw** | picked-up gold briefly buffs your damage (momentum econ build) | rare → legendary: bigger/longer buff, gold heals a sliver |
| **Thundering Step** | your dash leaves a damaging shock trail | rare → mythic: trail petrifies-lite (brief root), longer |

*(The four flat starter relics — Vigor/Swiftness/Greed/Wisdom — stay as the
cheap baseline tier, but every grade above them should offer a mechanic, not a
bigger number.)*

**New enemy status required: `petrify`** (a hard freeze + stone overlay, boss
`cc_immune` flag for the undying/apex ones). Reused by Gorgon's Gaze, Thundering
Step, and any future stone-themed weapon.

---

## 7. Build order (batches, each headless-tested)

1. **Enemy `petrify` status + boss `cc_immune` flag** — the shared primitive; prove
   it stones a regular enemy and that a flagged boss resists.
2. **Creative relics batch** — Gorgon's Gaze + the §6 roster; prove each procs.
3. **The +15% pass** — weapon damage + flat relic values; a test asserts the new
   baseline and that nothing regressed.
4. **Weapon dials: the `combo` + per-weapon `crit` + melee-snap systems** — the new
   mechanical dimensions §2 marks NEW.
5. **Weapon fill, grade by grade** — common & uncommon first (biggest gap), then
   epic set-weapon signatures (§5), then legendary/mythic. Each weapon distinct on
   several dials; contact-checked so no two share silhouette+moveset.
6. **Update [ITEMS.md](ITEMS.md) + the catalog artifact** to the new roster.

**Guardrails (from BOSSES.md, still binding):** extend `inventory.gd` ITEM_DEFS /
the existing weapon_stats + relic_power systems, never fork; headless-verify every
batch; never touch the L100 boss curves; a green working tree proves nothing —
verify from a clean clone.
