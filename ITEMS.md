# DEEPWOOD — The Item Catalog

> **The complete inventory of everything in the game**, extracted from
> `inventory.gd` (`ITEM_DEFS` + `ITEM_GRADES`, 2026-07-17). **139 items total.**
> This is the reference for itemization review, balance, and gap-hunting. When an
> item is added/changed in code, update this file.
>
> **⚠ Mid-overhaul (WEAPONS.md).** Since first capture: +18 grade-fill weapons
> (common/uncommon), a creative relic **Gorgon's Gaze** (petrify), and a **+15%**
> weapon-damage pass. The tables below still show the pre-overhaul base numbers
> for the original items — the [live catalog artifact] is the current view; this
> md will be fully re-synced when the weapon-dial batches land.

## The grade ladder (6 tiers) — `GRADE_DEFS`
Every equippable carries a grade; a wielded weapon's grade also passively buffs
*everything* (`GRADE_PASSIVES`) — so a higher-grade weapon lifts your whole kit.

| # | Grade | Colour | Passive bundle (wielded weapon) |
|---|---|---|---|
| 1 | **Common** | grey | +5 HP |
| 2 | **Uncommon** | green | +10 HP, +2% move |
| 3 | **Rare** | blue | +18 HP, +3% move, +3% all damage |
| 4 | **Epic** | purple | +30 HP, +15 mana, +5% move/damage/gold |
| 5 | **Legendary** | orange | +45 HP, +25 mana, +8% move/damage/gold/xp |
| 6 | **Mythic** | red-pink | +70 HP, +40 mana, +10-12% everything |

---

# EQUIPPABLE

## Weapons (48) — hotbar / wielded
Three classes route damage: **melee** (sword/spear share melee scaling), **bow**,
**wand**. "Special" = a projectile special-attack; "Excellent" (`exc_`) = the
legendary/mythic loot-only tier.

### Starter & basic
| id | name | type | base dmg | grade |
|---|---|---|---|---|
| `wpn_sword` | Sword | melee | 8 | common |
| `wpn_spear` | Spear | spear | 24 | common |
| `wpn_bow` | Bow | bow | 15 | common |
| `wpn_club` | Wooden Club | melee | 11 | common |
| `wpn_dagger` | Iron Dagger | melee | 7 | uncommon |
| `wpn_mace` | Iron Mace | melee | 18 | uncommon |
| `wpn_javelin` | Javelin | spear | 16 | uncommon |
| `wpn_shortbow` | Short Bow | bow | 12 | uncommon |
| `wpn_apprentice_wand` | Apprentice Wand | wand | 10 | uncommon |

### Gathering tools (common) — non-combat, work harvest nodes
| id | name | type | dmg | node |
|---|---|---|---|---|
| `tool_axe` | Woodsman's Axe | melee | 5 | trees → wood/resin/herb |
| `tool_pickaxe` | Miner's Pickaxe | melee | 5 | rocks → stone/metal |

### Rare tier (incl. special-attack weapons)
| id | name | type | dmg | note |
|---|---|---|---|---|
| `wpn_greatsword` | Greatsword | melee | 22 | |
| `wpn_katana` | Katana | melee | 13 | |
| `wpn_warhammer` | Warhammer | melee | 30 | heaviest basic |
| `wpn_harpoon` | Harpoon | melee | 14 | |
| `wpn_windcutter` | Windcutter | melee | 10 | special: wind-slash crescent |
| `wpn_sunderer` | Sunderer | melee | 20 | special |
| `wpn_stormlance` | Stormlance | spear | 10 | special: spectral javelin |
| `wpn_stormvolley` | Stormvolley Bow | bow | 9 | special: multi-shot |
| `wpn_seeker` | Seeker Bow | bow | 13 | special: **homing** arrows |
| `wpn_emberstaff` | Emberstaff | wand | 24 | special: fireball / **burn** |
| `wpn_iciclewand` | Icicle Wand | wand | 14 | special: frost shard / **slow** |

### Epic — the three class SET weapons (top on each armour set)
| id | name | type | dmg | set |
|---|---|---|---|---|
| `wpn_claymore` | Bulwark Claymore | melee | 16 | Sword / Bulwark |
| `wpn_recurve` | Windstalker Recurve | bow | 19 | Archer / Windstalker |
| `wpn_scepter` | Runeweave Scepter | wand | 0 base / **220 nuke** | Mage / Runeweave (special: high-burst "nuke", 20 mana) |

### Legendary — "Excellent" weapons (loot-only)
| id | name | type | dmg |
|---|---|---|---|
| `exc_vampiric` | Vampiric Fang | melee | 12 |
| `exc_thunder` | Thundercaller | melee | 14 |
| `exc_midas` | Midas Edge | melee | 10 |
| `exc_echo` | Echo Rift | melee | 13 |
| `exc_soul` | Soulthirst | melee | 11 |
| `exc_hook` | Leviathan Hook | melee | 8 |
| `exc_boomerang` | Galewing Glaive | melee | 11 |
| `exc_chrono` | Chrono Edge | melee | 12 |
| `exc_shadowblade` | Shadowblade | melee | 12 |
| `exc_dawnbreaker` | Dawnbreaker | melee | 15 |
| `wpn_tempest` | Tempest Bow | bow | 14 |

### Mythic — the apex "Excellent" weapons
| id | name | type | dmg | note |
|---|---|---|---|---|
| `exc_wizardsbane` | Wizardsbane | melee | 22 | **anti-boss** (Orin killer) |
| `exc_ragnarok` | Ragnarok Blade | melee | 16 | |
| `exc_doom` | Doombringer | melee | 18 | |
| `exc_singularity` | Singularity Edge | melee | 15 | |
| `exc_worldsplitter` | Worldsplitter | melee | 20 | |
| `exc_earthshaker` | Earthshaker Maul | melee | 24 | |
| `exc_gungnir` | Gungnir | spear | 16 | special |
| `exc_frostmourne` | Frostmourne | melee | 18 | **slow** |
| `exc_voidcaller` | Voidcaller | wand | 42 | **poison** |
| `exc_stormfury` | Stormfury Bow | bow | 16 | special |

### Admin / test (not real drops)
| id | name | type | note |
|---|---|---|---|
| `wpn_wand` | Magic Wand (Admin) | wand | 1g admin/test tool — never a real spell |
| `wpn_admin_ruin` | Ruin Wand (Admin) | wand | mythic-tagged admin burst |

## Armour (28) — 5 slots: helm · chest · pants · gloves · boots
### The class sets (helm + chest + pants; two stacking set-bonus tiers)
| Set | grade | role | pieces |
|---|---|---|---|
| **Leather** | uncommon | starter | `helm_leather` `armor_leather` `pants_leather` |
| **Bulwark** | epic | Sword / tank | `helm_bulwark` `armor_bulwark` `pants_bulwark` |
| **Windstalker** | epic | Archer | `helm_windstalker` `armor_windstalker` `pants_windstalker` |
| **Runeweave** | epic | Mage | `helm_runeweave` `armor_runeweave` `pants_runeweave` |
| **Ranger** | rare | (archer-flavour) | `helm_ranger` `armor_ranger` `pants_ranger` |
| **Dragonscale** | mythic | full 5-piece | `helm_dragon` `armor_dragon` `pants_dragon` `gloves_dragon` `boots_dragon` |

### Gloves (slot of its own)
| id | name | grade |
|---|---|---|
| `gloves_leather` | Leather Gloves | uncommon |
| `gloves_iron` | Ironclad Gauntlets | rare |
| `gloves_assassin` | Assassin's Grips | epic |
| `gloves_titan` | Titanfell Fists | mythic |
| `gloves_dragon` | Dragonscale Gauntlets | mythic |

### Boots (slot of its own)
| id | name | grade |
|---|---|---|
| `boots_leather` | Leather Boots | uncommon |
| `boots_swift` | Swift Treads | rare |
| `boots_storm` | Stormrunner Boots | epic |
| `boots_titan` | Titanfell Sabatons | mythic |
| `boots_dragon` | Dragonscale Sabatons | mythic |

## Relics (25) — accessory slots
| id | name | grade | id | name | grade |
|---|---|---|---|---|---|
| `relic_vigor` | Relic of Vigor | uncommon | `relic_thorns` | Thornmail | epic |
| `relic_swiftness` | Relic of Swiftness | uncommon | `relic_aegis` | Aegis Ward | epic |
| `relic_greed` | Relic of Greed | uncommon | `relic_wings` | Aetherwing (flight) | legendary |
| `relic_wisdom` | Relic of Wisdom | uncommon | `relic_fortune` | Crown of Fortune | legendary |
| `relic_berserker` | Relic of the Berserker | rare | `relic_vampire` | Vampire Lord's Signet | legendary |
| `relic_hawk` | Relic of the Hawk | rare | `relic_juggernaut` | Juggernaut Idol | legendary |
| `relic_archon` | Relic of the Archon | rare | `relic_reaper` | Reaper's Toll | legendary |
| `relic_wellspring` | Relic of the Wellspring | rare | `relic_godheart` | Godheart | mythic |
| `relic_mountain` | Heart of the Mountain | rare | `relic_warlord` | Sigil of the Warlord | mythic |
| `relic_sylvan` | Sylvan Charm | rare | `relic_celerity` | Idol of Celerity | mythic |
| `relic_feather` | Featherfall Charm | rare | `relic_phoenix` | Phoenix Heart | mythic |
| `relic_blink` | Shadowstep Sigil | rare | `relic_steward` | Steward's Chain | rare |
| `relic_ward` | Wardstone | rare | | | |

*(Gathering-exclusive relics: `relic_mountain` from rocks, `relic_sylvan` from trees — never dungeon loot.)*

---

# NON-EQUIPPABLE

## Materials (10) — stack, never worn
### Skill-tree materials (5) — dungeon-only drops, **researched at the Science Lab** before spending
| id | name | depth bracket |
|---|---|---|
| `slime` | Slime | shallow |
| `iron_shard` | Iron Shard | early |
| `ember_crystal` | Ember Crystal | mid |
| `void_essence` | Void Essence | deep |
| `ancient_relic` | Ancient Relic | deepest |

### Construction materials (3) — building repair/upgrade + the Mine chain (§5.7 Bible)
| id | name | source |
|---|---|---|
| `wood` | Wood | trees (axe) + enemy drops |
| `stone` | Stone | rocks (pickaxe) + Mine |
| `resin` | Resin | trees (axe) |

### Crafting ingredients (2)
| id | name | source |
|---|---|---|
| `herb` | Wild Herb | chopping trees |
| `raw_meat` | Raw Meat | hunting |

## Consumables (6)
| id | name | effect | source |
|---|---|---|---|
| `potion_health` | Health Potion | restore HP | **drop-only** (pre-boss waves + bosses) |
| `potion_mana` | Mana Potion | restore mana | **drop-only** |
| `food_stew` | Hearty Stew | buff | craft: 2 herb + 1 raw_meat |
| `food_feast` | Warrior's Feast | buff | craft: 3 raw_meat + 1 herb |
| `food_sage` | Sage's Supper | buff | craft: 3 herb + 1 slime |
| `potion_reset` | Reset Potion | refund skill points + class | craft: 2 void_essence + 5 slime |

## Currency (3)
| id | name |
|---|---|
| `coin_gold` | Gold Coin |
| `coin_silver` | Silver Coin |
| `coin_bronze` | Bronze Coin |

---

## Crafting recipes — `CRAFT_RECIPES`
`food_stew` = 2 herb + 1 raw_meat · `food_feast` = 3 raw_meat + 1 herb ·
`food_sage` = 3 herb + 1 slime · `potion_reset` = 2 void_essence + 5 slime.
**HP/Mana potions are deliberately NOT craftable — drop-only.**

## Notes & observations for review
- **The `dmg` column is the BASE weapon hit.** Special-attack weapons (windcutter,
  emberstaff, scepter, the `exc_` line, etc.) deal most of their damage through
  their **special projectile**, whose numbers live in each `"special"` dict — e.g.
  the Runeweave Scepter is 0 base + a **220 "nuke"** for 20 mana. So a low base
  number doesn't mean a weak weapon; read it with the special.
- **Two admin weapons** (`wpn_wand`, `wpn_admin_ruin`) sit in the same table as
  real loot — confirm they can never drop or be vendored (Bible: the 1g Magic
  Wand stays admin-only).
- **Set coverage:** Sword/Archer/Mage each get a 3-piece set + a set weapon;
  **Dragonscale is the only full 5-slot set** (helm/chest/pants/gloves/boots).
  Gloves and boots otherwise mix-and-match by grade.
- **Possible gaps worth a design look:** no dedicated **spear** set weapon (spears
  ride the melee sets); the **Ranger** set (rare) overlaps Windstalker's archer
  niche — is it a distinct identity or a lower-tier stand-in?; several relics
  (`relic_steward`, `relic_ward`) sit outside the core families — verify effects.
