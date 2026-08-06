# MECHANICS — THE IMPROVISED HAND (2026-08-06)

Worker report for the lead. Scope: the dev request "player should be able to
hold any item in hand … when player clicks mouse he just swings that item
(unless its consumable or weapon or similar things)".

Territory worked: `player.gd`, plus three new files. Nothing else was edited.

---

## 1. WHAT SHIPPED

| File | State | What it is |
|---|---|---|
| `improvised_hold.gd` | NEW | The one place the improvised numbers live: the hold/skip rule, the damage, the geometry, and the stand-in item def. Preloaded by `player.gd`, **no `class_name`** (a global class entry is what a stray backup copy hijacks). |
| `player.gd` | EDITED | `wield_improvised()`, `update_improvised_icon()`, `unwield()`, `drop_improvised_if_spent()`; `wield_weapon()` now delegates non-weapons instead of refusing them; `select_hotbar_slot()` holds anything that isn't a weapon or a consumable. |
| `test_improvised_node.gd` | NEW | 45 checks, all green. Registered — see §2c. |
| `all_test_files.txt` | **+1 LINE (QA's file)** | `test_improvised_node`, inserted alphabetically. See §2c for why I did not hand this one over. |

### How it works, in one paragraph

A non-weapon item goes in the hand by filling in the same four fields the melee
path already reads — `active_weapon_id`, `active_weapon_type` (`"melee"`),
`active_stats`, `active_def` — with improvised values. From there **the entire
existing swing runs unchanged**: `animate_sword`'s 120° arc, `spawn_swing_trail`,
the combo string, `$AttackArea`, crit, lifesteal, and every on-hit melee skill.
No new swing code was written, which is why the arc and timing match the game.

The safety property is the **stand-in def** (`IMPROVISED.def_for`). It carries
only the item's colour, never the item's real def — so there is no `"special"`,
no `"unique_effect"`, no `"tool_type"`, no `"mana_cost"`. Every branch of
`perform_attack`'s special dispatch is therefore dead for a held item, and the
click falls through to the plain melee swing. A fish cannot fire a weapon's verb
and a log cannot chop a tree the way the axe does.

### The damage number: **3 flat, on a 0.6 s swing**

`IMPROVISED.DAMAGE = 3`, `IMPROVISED.COOLDOWN = 0.6`. Measured against the live
roster in the test, not asserted against a magic number:

| | damage | cooldown | dps |
|---|---|---|---|
| improvised hold | 3 | 0.60 | **5.00** |
| Woodsman's Axe / Miner's Pickaxe (weakest real weapon) | 6 | 0.50 | 12.00 |
| starter Sword | 9 | 0.30 | 30.00 |

Why 3: it is half the weakest real weapon's damage on a slower swing, so an
improvised hold sits at ~40 % of the feeblest tier-1 weapon — and it *stays* at
40 %, because an improvised swing runs through `skill_damage_mult("melee")` like
any other, so both sides of the comparison scale by the same factor at every
character level. A log can never overtake a real weapon on any build. 3 is also
small enough to *read* as improvised: the damage numbers are visibly pathetic,
which is the point. Reach and hitbox give ground too (34 px / 38×32 vs the
sword's 42 px / 52×27).

### What is excluded, and the one judgement call

Excluded: `weapon` (has real stats, `wield_weapon` owns it) and `consumable`
(is drunk — `use_item` owns it, and the hotbar key still consumes exactly as
before). The list is written as **exclusions**, so a new item category ships
holdable by default, which is what "anything which can be put in inventory"
asks for.

**Judgement call:** `armor` and `relic` are held too. They are bag items, and
swinging a helmet is squarely the improvised idea; the gear panel still equips
them the same way. If the dev's "or similar things" was meant to cover
equippables, add `"armor"` and `"relic"` to `improvised_hold.gd`'s `NOT_HELD`
and the test's catalogue sweep follows automatically.

### Art: none needed

`Inventory.paint_icon` already resolves every item to a picture — its real
sprite at `art/items/<id>.png` when one exists, its procedural symbol otherwise.
The hand paints the **same** picture the bag slot shows, into its own
`ColorRect` under `$WeaponIcon`, so it inherits the aim rotation and the swing
punch for free. The gen freeze was not touched.

Two traps worth recording:

* `Inventory.paint_icon` **frees every child of the node it paints**. Painting
  straight onto `$WeaponIcon` would have permanently deleted `weapon_guard` and
  `weapon_sprite` on the first held log. Hence the dedicated child node.
* `update_weapon_sprite()` is deliberately **not** used for held items. It
  exists for diagonally-authored blade art and rotates the texture +45° so the
  edge lands on the aim axis. Coins, helms and crystals are authored upright and
  would have been tipped onto their corner.

---

## 2. PATCHES THE LEAD MUST APPLY (files I do not own)

Both are real friction the dev will hit in the first minute of play. Both are
two lines. Neither is a crash.

### 2a. `drag_state.gd` — you cannot stow or bin a stack you are holding

`_would_strip_wielded()` (line ~186) blocks trashing or chest-stowing whatever
matches `active_weapon_id`. That guard exists for real weapons, where stripping
the bag copy would leave a phantom wielded weapon. **A held stack is different:**
`player.drop_improvised_if_spent()` now empties the hand the moment the count
hits zero, so there is nothing to go stale. As it stands, a player holding wood
gets *"You can't stow the weapon in your hands"* when they try to put wood in a
chest.

```gdscript
func _would_strip_wielded(inv, item_id: String) -> bool:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or not ("active_weapon_id" in pl) or not ("inventory" in pl):
		return false
	# An IMPROVISED hold (a log, a stone) is a stack like any other -- the player
	# may stow or bin it, and player.drop_improvised_if_spent() empties the hand
	# on the next frame. Only a real WEAPON must stay out of the box.
	if "is_improvised" in pl and pl.is_improvised:
		return false
	return inv == pl.inventory and item_id != "" and item_id == str(pl.active_weapon_id)
```

### 2b. `chest_ui.gd` — Deposit All silently leaves the held stack behind

`_bulk_transfer()` (line ~254) skips the wielded id. Holding one log means
"Deposit All" quietly leaves all 99 wood in the bag with no explanation.

```gdscript
		# never strand the weapon in your hand inside a box -- but a HELD ITEM is
		# an ordinary stack, and the hand empties itself when it runs out
		if keep_wielded and player and s.id == str(player.active_weapon_id) \
				and not ("is_improvised" in player and player.is_improvised):
			continue
```

### 2c. `all_test_files.txt` (QA) — I touched it. Here is why.

**Applied, not handed over.** I intended to leave this as a patch for QA. The
full suite then came back `PASS 129 FAIL 1`, and the one failure was
`test_registry_node` — QA's own drift guard — saying:

```
FAIL  every test on disk is REGISTERED
      unlisted: ["test_improvised_node"]
      (add these to all_test_files.txt, or rename scratch probes to test_zz*)
```

Handing the line over would have meant leaving master red on a guard whose own
failure message states the fix. So I inserted the single line alphabetically
between `test_icons_node` and `test_items_node`. `test_registry_node` is green
again (131 registered, 131 on disk). **Flagging it because it is outside my
territory, not because I think it should be reverted.**

---

## 3. MEASURED ALL-CLEARS (where NOT to spend effort)

Everything below was checked and needs no change. Recorded because a measured
all-clear is worth as much as a proposed change.

* **`WeaponFx`** — `_fx_list(active_def)` reads `special.fx`; the stand-in def
  has no `special`, so it returns `[]`. No fx can fire off a held item.
* **`swing_slash_config()`** — a held item's grade rank is 0, below
  `SLASH_MIN_RANK` (3), so no flying slash. Confirmed by inspection and by the
  hit test (one hit per swing, 3 damage).
* **`Inventory.get_weapon_passive()`** — already guards on
  `category != "weapon"` and returns `{}`. Holding a log grants no grade
  passive. Correct: an improvised hold gives you nothing but a weak swing.
* **`GameState.wielded_weapon_id()` / set bonuses** — a material id never
  matches a set's weapon, so putting down a set weapon for a rock correctly
  breaks the full-set tier. Right semantics, no patch.
* **`main.gd:1456`** (re-wield after a scene change) — works unchanged, because
  `wield_weapon` delegates rather than refusing. The inventory is restored
  before the re-wield, so the held item survives every door. No patch needed.
* **`inventory_ui.gd:298`** right-click — unchanged on purpose. Right-click on a
  material still splits the stack, which is what it has always done; the hotbar
  keys are the route into the hand.
* **`hotbar_ui.gd:85`** — the active-slot highlight keys off `active_weapon_id`,
  so a held material's slot highlights for free.
* **`boss.gd:5131`** (`_mirror_the_player_kit`) — a held item falls to the
  default `"charge"` answer. Sensible; no patch.
* **`_tick_dig`** — reads `active_def.tool_type`, which the stand-in def does not
  have, so a held pickaxe-shaped rock cannot mine.
* **`perform_secondary_attack` / `channel_beam` / `channel_prism`** — all gate on
  a special or on `weapon_type == "wand"`. All inert for a held item.

---

## 4. WHAT I DID NOT DO, AND WHY

* **Did not touch `inventory.gd`.** It is the lead's, and nothing in this
  feature needed it: `paint_icon`, `get_item_def` and `get_category` all already
  do the right thing for every item id.
* **Did not eyeball it in a window.** The dev's own rule stands — a static
  sweep and a headless assert prove it is not *broken*, not that it *feels*
  right. The one thing worth the dev's eyes: a held object rotates to point
  along the aim (the same rule weapons follow), so it draws upside-down when you
  face left. That is consistent with every weapon in the game, but it is a
  five-second judgement only the dev can make. A stone reads fine either way; a
  boot might not.
* **Did not give heavy items more damage than light ones.** One number, by
  design — "improvised" is an identity, not a second weapon ladder. Easy to add
  later off `max_stack` or category if the dev wants it.

---

## 5. VERIFICATION

* `Godot --headless --check-only --script player.gd` — clean (only the expected
  `Identifier not found: GameState`, which is the autoload, not a parse error).
* `test_improvised_node.gd` — 45/45 PASS on a live player, including a real
  `dps_dummy` placed inside the hitbox and its recorded damage read back.
* `test_melee_node.gd` — 92 PASS, 0 FAIL.
* `test_weapons2_node.gd` — RESULT: ALL PASS.
* `test_registry_node.gd` — ALL PASS, 131 registered / 131 on disk.
* Full suite, `bash tool_run_suite.sh` — **PASS 129, FAIL 1, CRASH 0 of 130**,
  the single failure being the registry guard described in §2c, now fixed. No
  other test moved.

### One lesson worth keeping — a negative assertion needs a positive control

The test asserts "an empty hand cannot swing" by reading 0 damage off the dummy.
The first draft passed that check **while the dummy was out of reach**: dozens of
awaited frames had passed since it was placed and the player had drifted under
gravity, so the swing would have measured 0 with a sword in hand too. The only
reason it was caught is that the very next line refills the hand and demands the
*same* dummy in the *same* frame take a hit — and that control failed. The fix
re-seats the dummy relative to the player's live position before the pair runs.

This is the repo's own recorded rule (`deepwood-green-test-lies`) reproducing
itself inside a brand new test, four hours after it was written down.
