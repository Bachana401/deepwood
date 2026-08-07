# MECHANICS — Torch becomes a craftable, Terraria-placed item

Dev ask (verbatim): *"i want to change using torch mechanic, i want it to be a
regular item which is craftable, and put in inventory, and then i want it to be
placed like in Terraria exactly."*

Status: **DONE.** Torch is now a craftable bag item; hold it and click to plant a
lit brazier snapped to the surface under the cursor; it consumes one torch per
placement; it does not swing like the other held items; overworld placements
persist exactly like the old G-key ones. Suite green on every affected test.

Territory touched: `inventory.gd`, `player.gd` (both mine). No file outside my
territory was edited. **No hand-off patch is needed** — everything the feature
relies on in files I don't own already works as-is (see §5).

---

## 1. What changed

### `inventory.gd` (mine)
- **New item** `torch` in `ITEM_DEFS` (category `material`, `max_stack` 99,
  `"placeable": true`, plus a `desc`). Deliberately **not** `is_material`, so its
  name reads plainly and it needs no Science-Lab research.
- **New recipe** `"torch": {"wood": 2, "resin": 1}` in `CRAFT_RECIPES` — the exact
  cost the old G-key path spent (`player.gd STANDING_TORCH_COST`), so the lighting
  economy is unchanged: one craft = one torch = one placement = 2 Wood + 1 Resin.
- **New procedural icon** `_icon_torch` + its `paint_icon` match arm, so the torch
  reads as a torch in the bag AND in the hand (paint_icon draws both). No art
  asset — procedural, like every other material icon (art gen is frozen anyway).
  This was **mandatory**: `test_icons_node` fails any item that renders a flat
  tile, and a bare `material` would have fallen through to one.
- **Tooltip** now appends a plain `desc` line for any non-weapon/non-consumable
  item that carries one (only the torch does today). Generic and harmless.

### `player.gd` (mine)
- `TORCH_ITEM_ID`, `is_holding_torch()`, `try_place_held_torch()`,
  `torch_place_point()` — the placeable-item path (added next to the old
  `try_place_torch`).
- The attack block in `_physics_process` now branches on `is_holding_torch()`
  **first**: a torch **places on click and never reaches the swing path**. See §3.

---

## 2. How placement + snapping works (Terraria-style)

`torch_place_point()`:
1. Take the cursor (`aim_world_point()` — real mouse, or the touch auto-aim).
2. **Clamp** it to within `TORCH_PLACE_REACH` (460 px) of the player's feet, so a
   torch can't be planted across the whole map. (Tunable — see §6.)
3. Cast a **short ray straight down** — from `TORCH_SNAP_UP` (40 px) above the
   cursor to `TORCH_SNAP_DOWN` (720 px) below it, `collision_mask = 1`
   (terrain/platforms, the same layer the roof/daybreak checks use), excluding
   self. The **first surface hit is the placement point**, so the torch's stone
   base (which sits at local y=0) rests on the ground/platform under the cursor.
4. **Fallback:** if nothing is below (a pit / open air), plant at the player's own
   foot height at the cursor's x — a torch never floats in the void.

`try_place_held_torch()` then spawns the existing `standing_torch.gd` brazier at
that point, spends one torch, and (overworld only) records it — see §4.
Single placement per click (`is_action_just_pressed`), so holding the button does
not spew a line of torches.

## 3. It holds, it does not swing

Selecting the torch from the hotbar routes through the existing improvised-hand
path (`wield_weapon` → `wield_improvised`, because its category isn't `weapon`), so
it is **drawn in the hand** exactly like a held log — same icon path, bag/hand
match preserved. The one difference is the click: the physics loop checks
`is_holding_torch()` **before** the normal attack branch and calls
`try_place_held_torch()` instead of `perform_attack()`. The torch therefore never
falls through to the improvised swing. `improvised_hold.can_hold("torch")` still
returns true (it's a non-weapon/non-consumable), which keeps `test_improvised_node`'s
"every non-weapon item is holdable" invariant green.

## 4. The G key — KEPT as a shortcut (not retired)

`try_place_torch()` (G / the `place_torch` action) is **unchanged**: it still
plants a torch at the player's feet straight from raw materials, for the same
2 Wood + 1 Resin. Reasons:
- It costs the same as the item, so both routes share one economy — no drift.
- Retiring it would mean editing/removing `test_placetorch_node.gd`, which is QA
  territory; keeping G means that test stays green untouched.
- The dev explicitly allowed "keep G as a shortcut, fine."

So the player has two doors to the same result: **G** = quick feet-drop from
materials; **the item** = craft it, hold it, click-to-place-anywhere (the new
Terraria flow). If the lead/dev would rather G be retired, the clean move is: drop
the G branch from `try_place_torch`, remove the `place_torch` action, and have QA
delete/repoint `test_placetorch_node.gd`. I left it live rather than half-dead.

## 5. Persistence (and the dungeon subtlety I had to guard)

Overworld placements append to `GameState.placed_torches` and are re-spawned by
`main.gd spawn_placed_torches()` on every return to the village and across
save/load — **exactly like the G-key torch today**. No change needed in `main.gd`
or `game_state.gd`; I only read them.

**Guard I added:** `placed_torches` holds *village* coordinates and is re-spawned
only into `main.tscn`. Placing a torch in a **dungeon** and recording its
dungeon-local point there would resurrect the torch mid-village on the next trip
home. So a dungeon placement spawns the live brazier (lights the current run) and
spends the item, but is **not** recorded to `placed_torches` — ephemeral, like the
dungeon's loot and layout. Overworld placement is unaffected. (The old G path
sidestepped this by simply refusing in dungeons; the new item is allowed to place
in dungeons per the brief, hence the explicit gate.)

## 6. Left for later / notes for the lead

- **Underground tile world (the one remaining piece).** `try_place_held_torch()`
  early-returns when a `tile_world` node exists, because the tile Underground has
  its **own** torch system + grid (`underground.gd _try_place_own_torch`, saved
  into the cave diff, not `placed_torches`) — and that file is locked by the water
  worker right now. Net effect today: holding the torch item **underground** and
  clicking does nothing (it does not place, and critically it does not swing);
  the Underground's own G-key torch still works there. Reconciling the torch ITEM
  with the tile grid (so the bag torch also places on the Underground's grid and
  persistence) is a **later pass** and needs coordination with whoever owns
  `underground.gd`. This is by design per the brief, not a bug.
- **Tunables** (all named consts in `player.gd`): `TORCH_PLACE_REACH` (460 px),
  `TORCH_SNAP_UP` (40), `TORCH_SNAP_DOWN` (720). Reach and snap distances were set
  by eye for the overworld's scale; the dev's feel-playtest is the real judge.
- **Craft yield.** Recipe makes **one** torch per craft to keep the economy
  identical to the G path. Terraria yields 3 per craft; if the dev wants that
  feel, bump the yield — but that changes the economy, so I did not.

## 7. Verification

Proved live under the `MONARCH_TEST` hook with two scratch probes (both deleted
before commit): crafted a torch (2 Wood + 1 Resin spent, one torch banked), held
it (`is_holding_torch()` true, drawn in hand), placed it (a `standing_torch` node
appeared at the snapped point, `placed_torches` grew by one, one torch spent),
spending the last torch emptied the hand; and the dungeon gate (spawns + spends
but does not touch the village list). All checks PASS.

Registered suite — the must-stay-green set and every test my changes touch:

| Test | Result |
|---|---|
| `test_improvised_node` | ALL PASS |
| `test_melee_node` (asserts craft-row count == recipe count) | ALL PASS |
| `test_save_node` | ALL PASS |
| `test_placetorch_node` (the G-key path) | ALL PASS |
| `test_icons_node` (every item draws a symbol) | ALL PASS |
| `test_craft_node` | ALL PASS |
| `test_items_node` | ALL PASS |
| `test_tooltip_node` | ALL PASS |

No new test was added (the feature is covered by the existing improvised/icons/
craft/placetorch tests once the item exists), so `all_test_files.txt` is
unchanged. If QA wants a dedicated `test_torchitem_node`, the two probes above are
the ready-made body.
