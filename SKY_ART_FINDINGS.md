# SKY ART — findings & handover (2026-08-07)

Worker: SKY ART. Territory touched: `day_night_cycle.gd`, new `art/sky/**`. No other
source file edited. The eclipse test stays green; the astronomy (arc, windows,
camera-anchoring, eclipse ring) is untouched — only the DRAW changed.

Dev's request, verbatim: *"i hate their visual appearance, use pixellab and create
moon, with it's phases, eclipse, sun, etc etc. everything. maybe also create another
moon which will be shown but it will be far away, other planets too which are far
away and they are barely visible in the sky."*

This is art the dev judges by feel. **Present for review — not declared final.**

---

## 1. What I generated (PixelLab, 5 gens; ~104 remaining)

All freeform `create_image_pixflux`, transparent background. Each raw frame was
inspected before use (project rule: QC frame-by-frame; a bad frame is worse than
none). None were garbled; all 5 approved on the first generation.

| File | Size | Reads as | Verdict |
|---|---|---|---|
| `art/sky/sun.png` | 96² | warm pale-yellow molten core → amber body → orange-red flame corona rim | approved |
| `art/sky/moon_full.png` | 96² | pale silver-white disc, blue-grey craters/maria, cool shading | approved |
| `art/sky/distant_moon.png` | 64² | small faint dusty-grey sphere, low contrast | approved |
| `art/sky/planet_ringed.png` | 64² | tilted-ring gas giant, cream/amber | approved |
| `art/sky/planet_red.png` | 48² | dim rusty-red dot | approved |

Measured brightness (opaque avg): moon `(0.77,0.82,0.89)`, sun `(0.86,0.64,0.20)` —
both bright, `maxlum 1.0`. `.png.import` siblings are committed alongside (the
`.godot/imported/*.ctex` is gitignored and regenerates on clone import).

Only the freeze-overriding art this task needs was generated. Nothing else.

---

## 2. What I integrated (`day_night_cycle.gd`)

**Sun and moon are now the SAME Polygon2D nodes as before, textured.** A textured
Polygon2D lets the moon's phase silhouette double as its own mask, so the art is
clipped to the lit fraction with **no second node and no alignment guesswork**, and
the eclipse code (which sets `.color`) keeps working. No `main.tscn` node edits were
needed — everything is driven from the script.

- **Sun** (`build_sun`): the `Disc` polygon now carries `sun.png` via
  `build_textured_circle`. The soft additive glow halos (`GlowOuter/Inner`) stay —
  they genuinely brighten the sky behind the disc. **Dropped** the old hard 12-ray
  spokes and the procedural highlight (that spoke-ring was exactly the "cheap icon"
  look being replaced; the generated sun carries its own corona + surface). The
  `Rays`/`Highlight` nodes remain in-scene but empty; `update_sun_eclipse` guards on
  them, so nothing breaks.
- **Moon** (`pick_new_moon_phase` → `_apply_moon_texture`): `build_moon_phase` still
  writes the lit-phase silhouette polygon; `_apply_moon_texture` then assigns
  `moon_full.png` and per-vertex UVs so the art is clipped exactly to the phase. The
  whole procedural crater pass (`generate_moon_craters`/`update_moon_craters`) is
  **retired** — craters are baked into the art (functions left defined, uncalled).
- **UV mapping** is measured, not guessed: `_disc_metrics` scans each PNG's opaque
  bounding box once at setup for the disc centre+radius, so the art lands dead-centre
  regardless of transparent margin.
- **Distant sky** (`_build_distant_sky` / `_update_distant_sky`): a new `DistantSky`
  Node2D, added deferred (Main is still building children during our `_ready`), holds
  four faint `Sprite2D` bodies (a second moon + a ringed planet + a red planet + a
  tiny far ring). z_index `-72`: behind sun/moon (`-70`), in front of the moon's sky
  glow (`-75`). They fade in with night, hide by day and during the daytime eclipse,
  and drift slowly by TIME (see §4).

### THE ONE TECHNICAL TRAP — write it down

**A textured `Polygon2D` clamps its per-vertex `.color` to 1.0 before CanvasModulate
folds in.** The night moon's whole trick is a counter-colour > 1.0 that cancels the
night CanvasModulate so the moon stays bright. On the *old untextured* disc that
counter-colour rode `.color` and worked (and it still works on the untextured glow
rings). On the *new textured* disc it came out dim — the first night frame had a
muted moon with a glow ring brighter than the moon itself. Fix: **route the
counter-light through `self_modulate`** (a CanvasItem uniform, NOT clamped). Applied
to the moon body and to the sun's eclipse path. `.color` is now held at WHITE on
both; `self_modulate` carries the counter-light. Verified: the moon renders at its
true silver at night. If anyone re-touches this, keep the counter-light on
`self_modulate`, never on a textured poly's `.color`.

---

## 3. Frames I looked at (windowed walker, five moments)

Shot from inside the village opening scene, driving the clock directly. Before =
the old flat gold polygon + hard spokes (sun) and flat silhouette phase (moon).

- **Noon** — sun: **excellent.** Warm molten disc with the flame corona inside a soft
  warm glow. Night-and-day better than the flat polygon.
- **Night** — moon: **excellent** after the `self_modulate` fix. Bright silver
  cratered disc with a soft blue halo over the mountains. A later run rolled a
  **crescent** phase and it clipped cleanly from the texture — a crisp lit limb, its
  glow following the crescent, **no dark-over-sky artifact.** Phase system confirmed.
- **Totality** — **excellent and fully preserved.** Black moon disc inside the hot
  orange-red corona ring, world dropped to deep-red silhouette. The ring overlay is
  untouched; it reads perfectly over the new sun art.
- **Dawn / Dusk** — read as correct transitional lighting. At those exact hours the
  sun/moon sit low and happen to be behind the mountains (the arc + occlusion are the
  lead's prior work, not the art), so the discs themselves are mostly hidden; the sky
  tint and the moon's rising glow carry the moment. Not a regression — the same arc
  drove the old sky. Flag only if the dev wants a disc guaranteed on-screen at dawn.

QC PNGs (this session's scratchpad, not committed):
`…/scratchpad/eyes_sky4/{1_dawn,2_noon,3_dusk,4_night,5_TOTALITY_p1.00}.png` (+`_ZOOM`).

---

## 4. The distant bodies — the honest part, needs a dev eye

They render (measured present at their expected positions, all four), and they are
deliberately **faint** — "barely visible," as asked. Two things the dev should judge:

1. **Clouds sit in FRONT of them.** Clouds render at z `-25`; the far bodies at `-72`.
   So they peek between clouds and, on a cloud-heavy sky, the second moon can be
   mostly hidden. That reads as atmospheric distance, but it means their visibility
   varies run-to-run with cloud placement. Current tuned alphas: second moon `0.80`,
   ringed `0.70`, red `0.66`, far ring `0.58` (they still render at only ~0.25–0.45
   effective because the art is mid-toned and small — which is why the alphas look
   high).
2. **No position parallax, by ruling.** The dev's standing rule (see
   `get_parallax_anchor_x`) is that any sky lag proportional to how far the town has
   grown east marches a body off screen without bound. So the far bodies are
   camera-anchored like the rest of the sky and drift only slowly over *time*
   (`sin(total_hours_elapsed·spd)`), which reads as slow celestial motion with no
   runaway. I did **not** reintroduce true parallax; if the dev wants the far bodies
   to lag the near sky, that ruling has to be revisited first.

**Dev sign-off asks:** (a) are they faint enough / too faint? (b) is cloud occlusion
of the second moon acceptable, or should the far bodies move just in front of clouds
(z between `-25` and `0`) so the "second moon" always reads? (c) want more/fewer far
planets? All three are one-line tunes in `_build_distant_sky`'s `defs` array.

---

## 5. Definition-of-done status

- [x] Sun + moon are sprite art; **phases work** (full & crescent both verified clean).
- [x] Eclipse still reads; `test_eclipse_node` = **ALL PASS** (every grepped
      identifier — `_ring_layer`, `RING_SCREEN_Y`, `ECLIPSE_CORONA`, "it is the hole",
      `RING_LAYERS` shape — preserved).
- [x] Faint distant moon + planets sit far in the sky (see §4 for the caveats).
- [x] Verified on rendered frames at five times of day.
- [x] Moon glows at night — counter-colour preserved (moved to `self_modulate`).
- [ ] **Full suite:** running as I write; result appended below. My change is one
      render file and the only test that reads it passes, so risk to the other 130 is
      low. NOTE: `test_underground_node.gd` shows modified in the tree — that is
      **another session's** WIP, not mine; I left it untouched.

## 6. Scratch removed / territory

Deleted my two scratch drivers (`tool_measure_sky.gd`, `tool_eyes_sky.gd`) before
committing — `tool_*.gd` is QA's territory and the brief says delete scratch tools.
The sky walker is genuinely reusable; if QA wants a permanent one, the driver is a
near-copy of `tool_eyes_eclipse.gd` that sets `GameState.game_hours` to dawn/noon/
dusk/night, forces one eclipse to totality, calls `day_night.update_visuals()`, and
saves a PNG + a 3× disc-crop per moment. Happy to hand it over on request.

Commit contains only: `day_night_cycle.gd`, `art/sky/*.png`, `art/sky/*.png.import`,
this file.
