# ANIMATION STUDY — COVERAGE LEDGER
How much of Terraria's weapon space has a MEASURED motion recipe, measured
against ground truth rather than against our own reading lists.

## Ground truth
Every animated demo on the wiki was enumerated through the MediaWiki API
(`list=allimages`, 51 pages, 25,470 image names) and filtered for `(demo)`:

    619 demo animations exist wiki-wide

That 619 includes non-weapons — armor sets, accessories, traps, furniture,
mounts, light pets, block/liquid demos, UI and parallax test clips.

## Studied (each = GIF downloaded, keyframes extracted at 2-3x, contact
## sheet READ, measured against player-height = 48px = 1.0 PL)

| file | weapons | scope |
|---|---|---|
| gif_melee_swords.md | 42 | verb-bearing swords, pre-Moon-Lord + endgame |
| gif_melee_families.md | 42 | yoyos, flails, boomerangs, oddballs, spears |
| gif_melee_remainder.md | 54 | the rest of melee (Flint recovered on retry) |
| gif_ranged.md | 46 | bows, repeaters, launchers, guns, thrown |
| gif_magic.md | 52 | wands, tomes, the uncategorized |
| gif_summons.md | 43 | minions, sentries, whips |
| gif_final_sweep.md | ~30 | the closing gap + ladder verification |

Melee is complete: every verb-bearing melee weapon in the reference has a
measured recipe.

## What is deliberately NOT studied individually

**Stat-stick ladders (~70 rows).** The copper→platinum bows/broadswords/
shortswords, the wood ladder, the hardmode ore swords/repeaters/halberds,
the gem staves. The scan digests record these as pure number ladders with
no unique verb. Rather than take that on faith, `gif_final_sweep.md`
Part 2 samples 3 rungs from each of 8 ladders and reports a measured
verdict per ladder (identical shape + scale only, or a genuine verb
appearing at some rung). One proven claim replaces 70 redundant studies.

**Non-weapons.** Armor/accessory/trap/furniture demos are outside this
study's scope; the accessory and armor SYSTEMS are covered in text form in
WEAPON_VERB_REFERENCE.md's item-space scan sections.

**Confirmed-unavailable (verified via API `imageinfo`, not guessed):**
Barrel Launcher (unreleased 1.4.5 announcement item, static art only);
Mushroom Staff, Cobwhip, Slime Whip, Possession, Electric Eel (real
1.4.5 items, stub pages, no media uploaded); Vulgar Display of Flower (no
page on the mirror); Killing Deck (wiki.gg-only, anti-bot challenge).
These carry text-derived recipes from the scan digests instead.

## Method (the FOREVER method — see the design-language memory)
1. Resolve filename via `terraria.fandom.com/api.php`.
2. Download the original from `static.wikia.nocookie.net/terraria_gamepedia/`
   via the MD5 hash path + `?format=original` (bypasses WebP re-encode).
   wiki.gg's image host hard-blocks scripted clients — do not fight it.
3. Extract 8 keyframes (5 spread + a consecutive triplet at the midpoint for
   px/frame velocity) with System.Drawing `SelectActiveFrame`, redraw at
   2-3x NearestNeighbor, composite into one labeled contact sheet.
4. READ the sheet and measure: sizes in player-heights, speeds in PL/s,
   cadence from frame delays, arc geometry, trail length, blast width,
   lingering-zone duration.
5. Write the recipe. NEVER copy pixels — the mobile port is store-bound, so
   only motion recipes rebuilt procedurally in Deepwood's own palette.
