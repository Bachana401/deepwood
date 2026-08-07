# WATER_FINDINGS — SCENES / underground liquids

Territory: `underground.gd` (the live tile cave). All changes are in that one file.
Verified on rendered frames with a scratch probe (`tool_water_probe.gd`, deleted
before commit) driving `underground.tscn` on a fixed seed (777), plus the full
`test_underground_node` suite headless.

Four dev live-play asks, all addressed:

1. "water is not acting like water — it should go down whenever there's no surface underneath"
2. "water quality by visual is very cheap"
3. "too much lava and too much water — reduce their count by 40%"
4. "make some bigger make some smaller, all of them are mostly same size"

---

## 1. FLOW — water that falls when unsupported

**The mechanic already existed and works.** There is a full falling-sand liquid
automaton (`_flow_cell`/`_flow_liquid`: down-first, then spread sideways halving
the difference so a surface settles flat) driven every physics frame from
`_WaterTick` → `_water_tick` → `_flow_tick`. Mining a cell calls `_disturb`, which
wakes the water above so it drains. I confirmed on frames that **mining out the
floor beneath a pool drains it downward** (probe frames `wp_pool_intact` →
`wp_pool_draining` → `wp_pool_settled`: the surface visibly drops and re-settles
lower). The suite's own "water falls to the floor / settles flat / pours through a
breach / pours into a crater instead of hanging" checks all pass.

**The real gap:** the automaton is an ACTIVE SET — it only moves cells that
something disturbs, and **generation disturbs nothing**. So any water the generator
draws hanging over open air just SAT there. Measured at generation (seed 777):
**2.5–2.9 % of all generated water cells float directly over air** — that is the
"static fill" the dev saw: water with nothing under it that never falls.

**Fix (`_load_chunk`):** when a chunk streams in, wake any water/lava cell whose
downstairs neighbour is open and holds less liquid. It then falls on the next flow
tick. Uses only the already-computed `kinds` array + `_lv`/`_ll` lookups — no extra
`_gen_kind`. Settled lake interiors (full water below) never wake, so still lakes
stay still and cost nothing; the fix reaches a fixed point (once below ≥ above in a
column, nothing re-wakes), so no perpetual churn and no re-churn across chunk
reloads.

**Flow cap:** unchanged at `FLOW_BUDGET = 420` cells settled per frame. The
wake-on-load cells join that same queue and drain under the same 420/frame cap, so
a big pool draining or a freshly-loaded wet chunk can never stall a frame — it just
settles over a few frames, which is also how it should look.

---

## 2. VISUAL — depth-darkening, real surface line, better caustics

The old water was one flat 60%-alpha blue slab (2-row atlas: body + waterline) with
a caustic made from a PRODUCT of two axis-aligned sines — which reads as a regular
dotted grid, the main "cheap" tell. Frames `wp_look_closeup` / `survey_*` before vs
after show the difference clearly.

Changes, all procedural (no art files — art gen stays frozen):

- **Depth bands (new `WBANDS = 5`).** The water atlas is now `WLEVELS × WBANDS`:
  the y coord is how many water cells sit above a cell, capped (helper `_wband`,
  a bounded ≤4-lookup up-walk). Band 0 is the surface and the only row that carries
  the bright waterline (keeps the old "no 12px stripes" fix); bands 1..4 darken from
  a bright surface blue toward dense navy. A pool now reads as a lit surface over a
  dark floor instead of one even fill. Wired through `_draw_water` and the bulk
  `_load_chunk` draw.
- **Caustics rewritten** in both `WATER_SHADER` and `WATER_FRONT_SHADER`: two
  DIAGONAL wave-fronts summed and thresholded into thin drifting ribbons of light,
  plus a slow crossing swell — reads as light rippling through water, not a lattice.
- **Within-tile floor-deepening + band-salted mottle** so even a single band has
  body and never looks dead-flat. Front veil thinned slightly (0.38 → 0.34) so it
  stays a veil over the swimmer.

Lava's rendering was left untouched — it already reads as molten (opaque, glowing)
and the dev's "cheap" note was about water.

**Not done (visual):** a dedicated foam/rim tile where water meets a *vertical* rock
wall (the "readable edge where it meets rock" ask). It needs neighbour-masked edge
variants (another atlas axis) and is the highest-complexity / lowest-payoff of the
four visual sub-asks; the bright surface line + the depth contrast against black
cave already give a readable top edge. Flagged as an optional follow-up, not shipped.

---

## 3 & 4. COUNT −40 % and VARIED SIZES — both in `_build_lakes`

All lakes (water in biomes 0–2, lava in 3–4) come from one candidate-grid generator.
Two facts drove the tuning:

- The per-candidate chance barely moves the total on its own — smaller pools pack
  tighter past the `claimed`-bucket overlap test, so cutting the chance was offset.
  **The candidate-grid density is the real lever on count.**
- Water and lava are gatable independently because a candidate's liquid is fixed by
  its depth (`molten := _biome_of(sy) >= 3`), computed up front.

Constants changed (old → new):

| constant | old | new | why |
|---|---|---|---|
| `LAKE_STEP_X` | 54 | **68** | coarser candidate grid = fewer pools (dominant count lever) |
| `LAKE_STEP_Y` | 18 | **24** | " |
| `LAKE_CHANCE` (single, 0.74) | 0.74 | **removed** | split into the two below |
| `LAKE_CHANCE_WATER` | — | **0.33** | ~40 % fewer water pools (with the grid) |
| `LAKE_CHANCE_LAVA` | — | **0.33** | ~40–45 % fewer lava pools |
| `LAKE_BIG_CHANCE` (0.34) | 0.34 | **removed** | replaced by size roll below |
| size roll | binary big(38–90)/small(10–28) | **`pow(randf,3)` over lerp ranges** | continuous spread: many small, a few large |
| `LAKE_SIZE_BIAS` | — | **3.0** | the cube bias |

Size is rolled afresh per lake, on different ranges per liquid (water `hw`
6→96 / `d` 4→34; lava `hw` 6→82 / `d` 4→30 — lava a shade smaller, it reads
thicker), so the two fleets vary independently. `big` is kept as a derived flag
(`hw >= 40`) because downstream code (fishing/bubble spawns, tests, the eyes tool)
reads `lk.big`.

**Measured (seed 777, `tool_water_probe`):**

| | before | after | change |
|---|---|---|---|
| water cells | 510 601 | 301 858 | **−40.9 %** |
| lava cells | 345 514 | 188 189 | **−45.5 %** |
| lakes total | 1 452 | 825 | fewer |
| hw distribution `[<15,15-34,35-59,60+]` | `[375,844,137,96]` | `[451,191,114,69]` | was 58 % clustered in one band; now a continuous spread — many small, a real tail of large |

At the test's seed (0), water share of open cave: **13.8 % → 8.3 %** (−40 %).

**Eyes (before/after, identical seed & camera):**
- `survey_0` (Rootearth): a drowned wall-to-wall central lake → open cave with a
  couple of small/medium varied pools. This is the money frame.
- `survey_4` (Emberdeep): lower half fully molten → a contained, glowing lava pool.
- `wp_look_closeup` / `wp_pool_intact`: flat dotted blue → depth-graded body with a
  readable bright surface line.

Lava landed a touch past 40 % (~45 %) — the dev said "~40 %" and "never to zero";
326 lava lakes remain, plenty. The water/lava split via a shared RNG stream makes
per-liquid percentages wander a few points seed-to-seed; the parameters, not the
seed, are what I tuned, and 40 %ish holds.

**Left alone deliberately:** the 11 authored road wades (`FLOOD_CROSSINGS`) and the
sinkhole wet pockets — those are deliberate one-off swim gameplay, not the ambient
"too much" the dev meant (road-flood total is ~1.8 k cells, <0.5 % of liquid).

---

## HAND-OFF PATCH (QA territory — `test_underground_node.gd`)

One suite assertion now fails, and it SHOULD: the water-share threshold was
calibrated to the old wet underworld.

- **File:** `test_underground_node.gd`, line 234
- **Now:** `check("water fills a good share of the caves (%.1f%%)" % share, share >= 12.0)`
- **Fails at:** `8.3 %` (the intended −40 % result at seed 0)
- **Proposed:** lower the threshold to **`6.0`** — still proves water is meaningfully
  present and catches an accidental collapse to ~zero, but reflects the reduced design.
  Suggested new line:
  `check("water fills a present-but-not-drowning share of the caves (%.1f%%)" % share, share >= 6.0)`

Everything else in `test_underground_node` passes (road, sinkholes, doors, swim,
crystals, rails, sand, **all the flow/lava/quench/save-reload checks**, ropes,
platforms). No other test references `underground.gd` or the removed constants.

---

## PERF NOTE (no action needed, flagged for the record)

`_wband` is called per water cell in the bulk `_load_chunk` draw (≤4 `_wlevel`
lookups each; `_wlevel`→`_gen_kind` returns early for liquid cells, no noise). Worst
case is a fully-submerged chunk load — now rarer given −40 % water. It rides the
existing staggered one-chunk-per-frame streaming. If a perf pass ever flags it, the
drop-in optimisation is column-tracking the depth as `_load_chunk` descends each
column (O(1) per cell, seed only the top `WBANDS-1` rows). I kept the simple, plainly
correct version to avoid a banding-seam bug at chunk boundaries.

## Definition of done
- Water falls when unsupported (wake-on-load), drains when mined beneath, spreads &
  settles flat — verified on frames + suite. ✅
- Visual materially better (depth-darkening, surface line, ribbon caustics) — frames. ✅
- Water −40.9 %, lava −45.5 %, sizes varied — measured + frames. ✅
- Per-tick cap stated (`FLOW_BUDGET = 420`, unchanged). ✅
- Only `underground.gd` edited; the one test change is handed to QA above. ✅
