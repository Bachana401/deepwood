# SCENES — findings

Department: Scenes. Branch: `claude/reverent-sutherland-0f6939`. Commit: `3ee98f1`.
Written at the lead's instruction (`*.md` is normally Docs' territory — this file
is a hand-off, not a claim on it).

Brief: the dev's complaint was *"i don't like buildings, their chain, leaders
powers, automization"*, and when pressed: **"It's invisible / numbers not feel."**

Every visual claim below was checked on rendered frames from the EYES walker, at
the shipping camera zoom, at **night and at noon**. Nothing here is signed off on
"the code looks right" — that is the exact failure mode this project has a record
of, and it caught me twice in this pass alone (§6).

---

## 1. The root cause, which was not what it looked like

The aura pools were drawn as five stacked bands at alpha 0.03–0.09. The walker
photographed the player standing *inside* the Bar's 1600px aura and there was
nothing on the frame at all.

The reason is not the alpha. **`main.tscn`'s `CanvasModulate` multiplies every
CanvasItem in the world by the hour's colour, and at midnight that is
`(0.16, 0.18, 0.34)`.** A 3% wash therefore lands at roughly half a percent of
screen contrast. Raising the alpha could never have fixed it — alpha only
interpolates toward a colour the modulate is about to crush anyway.

The proof was in the same frame: the lantern ropes read fine, because they are
small **solid** shapes at alpha ~1.

`presence_light.gd` (new) applies the fix `day_night_cycle.gd` already uses for
the moon — divide by the canvas colour before drawing, and the engine's multiply
puts it back. With one rule, written into the file:

> **Lift what EMITS. Never lift what merely EXISTS.**
> A town that goes dark at night is correct. A ward that goes out at night is a
> lie about the rules.

So ward lights, lantern flames, burning sigils and the letters on a lit sign are
countered; stone, wood, earth, cloth and crates are not.

**This is reusable.** Any future layer that must stay readable after dark should
go through `presence_light.lift()` rather than inventing its own alpha.

---

## 2. What was made legible, and what the pixels showed

Screenshots referenced are from the EYES walker described in §7. The **after**
frames were re-rendered from a **clean clone of the committed branch**, not from
my working tree.

### Auras — `village_presence.gd`, `village_crests.gd`

| | |
|---|---|
| **Before** (`02_auras_bar`) | Player standing inside the Bar's aura at night. Nothing on the ground. Indistinguishable from a town with no Bar. |
| **After** (`03_ward_midreach`, `01_ward_edge_east`, `02_ward_source`) | A line of lit ward stones walking out from the caster, brightest at the source, dimmest at the rim; a painted line along the whole reach; the rim marked with a post, a pennant, a curtain of light and the aura's **name on a board** ("THE WARD'S SHADOW"). |

The "which building casts it" problem is answered by a **beacon on the caster's
roof in the same colour as the ground light**. That shared colour *is* the
explanation — follow the stones toward the bright end and you are looking at the
Hospital. Confirmed on `02_ward_source`: green beacon on the ridge, green stones
on the road, one continuous read.

Cottages inside a reach wear a ring (`05_blessed_cottages`) — drawn as an outline,
not a filled dot, because the ward stones already fill the town with glowing dots
and the first version was indistinguishable from them.

### Chains — `synergy_lanterns.gd`

| | |
|---|---|
| **Before** (`01_stores_yard`) | A thin wire strung **across the front of the buildings** at a flat `ROOF_Y = -150`, while a village hall stands 230–345px tall. It read as cable nailed to a wall. Tiny lanterns. No indication of what the pair was *for*. |
| **After** (`10_chain_mine_builder`) | Rope hung at each building's real roofline (read per-building from `eff_h()`), with **goods riding it** — ore to the forge, coin to the carts, casks to the beds — more of them on a richer pairing. |

The change I would defend hardest: **a dead pair is now drawn.** Two buildings
standing adjacent but not both operational used to show *nothing* — identical, on
screen, to two buildings with no synergy at all. That is precisely the
information the player needs in order to act. It now hangs slack and unlit with
its lanterns out (`15_dead_chain` vs `10_chain_mine_builder` — same pair, Mine
rubbled).

### Quarters — `village_presence.gd`, `village_crests.gd`

Before: nothing whatsoever. `district_at()` binned an x into a name and
`building_output_multiplier` folded in 10%. Standing in the road there was no
edge, no character, no sign you had crossed anything.

After: each quarter has its own ground character (caltrops / cobbles / grass
tufts), and a **waymarker with the quarter's name** at the exact x the bonus
changes (`06_boundary_heart`, `13_day_boundary`).

The half I nearly missed: knowing you are in the Gatefront never told you that
the **Barracks belongs there**. A hall standing in its own quarter now flies that
quarter's colours off the ridge, in the same red/gold/green as the boundary
boards (`13_day_boundary` — red bunting on the Hospital; `09_plot_square_unbuilt`
— gold on the Bank and Tavern, and correctly *nothing* on the Blacksmith, which
is in the Heart but belongs to the Gatefront). Positive-only, matching the rule.

### Special plots — `special_plot.gd`

The brief asked specifically whether they read *before* a building is placed.
They did not. A 26px-tall tinted patch reads as slightly different dirt, and the
13px label rendered about **8 screen pixels tall** at 0.6 zoom.

After (`08_plot_stones_unbuilt`, `14_day_plot_stones`): a surveyed cordon between
two stakes, drifting motes over the worked ground, and a signpost tall enough to
clear a roof — "THE SORROW-TOUCHED STONES / WANTS THE SHRINE". Claimed state
verified separately (`16_plot_claimed`): "THE ORE VEIN / **WORKED BY THE MINE**"
with a lit ring.

### Presence — `village_presence.gd`, `village_crests.gd`

Standards on halls with a leader seated, wearing a **burning ring the moment that
leader's power wakes** (`has_building_power` already demands both level 4 and the
leader in the chair, which is the dev's own rule). Work yards that grow with the
hands in them. A muster ground whose watch-fire climbs with the size of the watch
and flies one pennant per patrol block held, pole height scaling with depth.

**The control frame matters more than any of the above:** `17_empty_town` — no
leaders, no workers, no patrols, nothing built. It comes back **bare**. Every
mark in these layers is gated on a fact, so this is information, not decoration.

---

## 3. Patches needed in `game_state.gd`

**None.** Every accessor I needed already existed: `AURAS`, `building_x`,
`in_aura`, `villager_places`, `ADJACENCY_PAIRS`, `building_neighbors`,
`in_home_district`, `building_district`, `on_home_plot`, `seated_leaders`,
`has_building_power`, `building_power_name`, `count_workers`, `posted_warriors`,
`patrol_at`, `extra_cottage_positions`.

I am not inventing one to fill this section.

---

## 4. Still not legible, and why

Most useful section. None of these are smoothed over.

1. **The sun and moon are invisible from the village.** Measured, not inferred —
   see §5. Not mine to fix.
2. **The size of an adjacency bonus cannot be read.** A richer pairing runs more
   crates, so 0.20 is *visibly busier* than 0.15, but nobody could tell you which
   is which. Deliberate — the dev asked for feel, not numbers — but if the lead
   ever wants the magnitude legible, this layer will not deliver it.
3. **Aura reach is shown for homes, not workplaces.** `in_aura` counts a
   villager's cottage **or their job**; the rings mark only cottages. That was a
   scope choice (cottage placement is the decision the player actually makes) but
   the visual is narrower than the predicate. If that gap matters, the fix is
   mine and small.
4. **Quarter ground character fades at night.** The motifs are dirt, not light,
   so they are not countered. After dark a quarter reads only from its waymarkers
   and the roof bunting. I think that is correct, but it is a real reduction.
5. **The special-plot patch itself is still dark at night.** The cordon, motes and
   signpost carry the read; the tinted ground does not. Same reasoning as (4).
6. **The muster ground saturates.** Four spears per block maximum, and the
   watch-fire clamps at 2× scale. A watch of 8 and a watch of 30 look similar.
7. **⚠ My own beacon can be mistaken for a sun.** The Bar's amber beacon is a
   glowing orb with eight radiating rays; in `village_13h` it is the brightest
   thing in a daytime sky and, at a glance, reads as a small sun. Today that is
   harmless because there *is* no real sun in the village (§5) — but **if the sky
   is fixed, these two will compete.** Mitigation if wanted: drop the beacon to
   six shorter rays, or bias them downward so it reads as casting rather than
   shining. One constant in `village_crests._draw_beacon`; I did not change it in
   this pass because it is only a problem in the world where the sky gets fixed,
   and that is the dev's call.

---

## 5. The sky — measured

The lead's read is **correct**, and worse than estimated in one direction. I
probed it rather than trusting the arithmetic. Viewport 1152×648, zoom 0.6, so
the camera sees 1920×1080 world px.

| Where | Hour | Sun screen pos | Verdict |
|---|---|---|---|
| origin (x 700) | 07:00 | — | below horizon |
| origin | 10:00 | (86, **−10**) | off top |
| origin | 13:00 | (176, **−73**) | off top |
| origin | 16:00 | (266, **−65**) | off top |
| origin | 19:00 | (356, 12) | on screen, **under the HUD bar** |
| village (x 14762) | 10:00 | (**−7338**, −28) | off left |
| village | 13:00 | (**−7248**, −70) | off left |
| village | 19:00 | (**−7068**, 17) | off left |

Two independent faults:

- **Horizontal.** `anchor_x = player.x * 0.12` while the camera sits at
  `player.x`, so the sky falls behind by 88% of however far you have walked.
  That is ~**3,000** screen px at the west gate (x ≈ 5,600) and ~**7,250** at the
  Bar (x ≈ 14,762) — six screen-widths. It scales linearly with x, so it gets
  worse the further east the town grows.
- **Vertical, and separate.** `SKY_PEAK_Y = −760` against a view top of about
  −630. The sun is above the frame for roughly the middle 70% of the day *even at
  world origin*. `origin_19h` shows it on screen but jammed behind the HUD banner.

**Net: the player has never seen the sun or moon from their own town, at any
hour. Near world origin they see it at dawn and dusk, partly behind the HUD.**

### Is it a problem in play? Yes — and it is the same problem I was sent to fix.

Nobody will ever file a bug about a sun they have not seen, which is exactly why
it survived. But the day/night cycle drives real systems — sieges, the lantern
night, the `CanvasModulate` that made my auras invisible in the first place — and
right now the player reads the hour **only from a clock string in the HUD**. That
is "numbers not feel", one level up from the dev's original complaint. A day/night
cycle nobody can see from the place they spend most of their time is a lot of
machinery going to waste, and it is cheap to recover.

### What I would do

**Anchor the sky to the camera, and lower the arc.** Not raise `PARALLAX_FACTOR`.

My reasoning, from a session of looking at frames: **any factor below 1.0 leaves a
drift that grows without bound with world x.** The row already runs past 20,000
and the design keeps pushing east, so 0.5 or 0.8 only moves the failure further
out — it does not remove it. And parallax on a celestial body is wrong anyway:
the sun is at infinity, it should not slide against the mountains. Parallax
belongs to the ridgelines, which already have it.

Suggested starting values for `day_night_cycle.gd` (yours; and this wants a real
eyeball pass, these are a starting point not a prescription):

```gdscript
func get_parallax_anchor_x() -> float:
    var cam: Camera2D = get_viewport().get_camera_2d()
    if cam != null:
        return cam.global_position.x        # the sky is at infinity: no parallax
    return 0.0

const ARC_SWING_X = 700.0     # was 300 -- the sun crossed only ~270 screen px
const SKY_HORIZON_Y = -430.0  # was -540
const SKY_PEAK_Y = -600.0     # was -760 -- noon sat above the view top
```

Measured constraints those numbers come from: the view top sits near world
y −630; the mountain peaks top out near y −380; the HUD occupies the top ~140
screen px (≈233 world px), so anything above about y −590 is behind the banner at
the centre of the screen. That leaves a genuinely narrow usable band, which is
the real reason to *lower* the arc rather than just re-centre it.

**Bonus, and worth checking before you commit to it:** you anchored the eclipse
ring to the screen because an eclipse is overhead by definition. If the sky
becomes camera-anchored, the ring and the sun end up in the same coordinate
space, and the eclipse could sit **on** the sun instead of near it. That is
strictly better, but it means the eclipse work and this change should be
eyeballed together.

**Caveat I cannot resolve:** this changes the look of every ordinary day in the
game. It is a design call, not a bug fix, and it should go to the dev before it
goes in.

---

## 6. Two things the EYES caught that no static check would have

Recorded because the method is the point.

- **The aura z-index history is only half the story.** The known rule is "ground
  overlays need z ≥ 2; terrain draws at 0, grass cap at 1, building frame 3, door
  4." True — but **art-facade buildings put their sprite in a `gfx` node with no
  `z_index` at all, so the facade draws at z 0.** A z-2 ground layer therefore
  draws *over* art facades, not under them. That is why the district waymarker
  boards are legible across the Hospital's wall. It is fine here, and it is why
  the tall plot signposts survive a building being placed on them — but the
  documented "stays under the building bodies" only holds for procedurally-drawn
  buildings. Worth correcting wherever that rule is written down.
- **I broke my own verification and it looked like a draw bug.** I moved the
  roster queries onto a slow cache; the walker then photographed state from
  *before* the town was staged. Beacons rendered, standards did not — from the
  same cache line. The frame looked exactly like a z-order or a gating bug. If a
  layer caches, **the walker must outwait the cache**; the fix was a real timer in
  the walker plus dropping the interval to 0.3s. Anyone adding caching to a drawn
  layer will hit this.

Also caught only by looking: standards floating 66px above their roofs; the plot
signboard and the aura board colliding into mush; and — after I "fixed" that by
dropping the aura board — it landing inside the Builderhouse's woodpile. The town
now keeps three sign bands: **plot names high, aura edges at head height, ground
clutter below.**

---

## 7. Measured all-clear

Things I checked and found already fine — recorded so nobody re-checks them.

- **The aura work reads at the shipping zoom.** All 17 walker frames were shot
  with the real player camera, zoom untouched at `(0.6, 0.6)` — confirmed by the
  sky probe printing `zoom=(0.6,0.6)`. Crops were used for *diagnosis* only;
  every verdict in this document was taken from a full 1152×648 frame.
- **Special plots at `z_index = 2`** genuinely clear the grass cap. Verified on
  frames, day and night, built and unbuilt.
- **The stores yard** (pre-existing) reads correctly at 0.6 and needed no change.
- **`in_aura` and the drawn reach agree.** Ward stones stop inside `r`, the rim
  marker sits exactly at `±r`, and `_draw_blessed_homes` uses the same
  `absf(hx - wx) > r` test the predicate does. The picture cannot lie about where
  the ward ends.
- **No `Light2D` anywhere.** All glow is drawn primitives, per the underground
  performance lesson.
- **No art generated.** Everything procedural; gen freeze respected.
- **No state written.** These layers read `GameState` and never assign to it.
  Delete all four files and the game is unchanged.
- **Per-frame roster queries are gone.** `count_workers` and `has_building_power`
  walk the villager roster and were being asked of 15 halls at draw rate
  (~1,200+ roster steps a frame in a grown town). Now cached on a 0.3s clock;
  `_draw` only animates.
- **Suite: 125/125 `RESULT: ALL PASS`, 0 `Parse Error`** on the final tree —
  counted, not trusted to an "ALL PASS" string.
- **Clean clone of the committed branch** imports, passes the key tests
  (`plots`, `auras`, `districts`, `adjacency`, `world`, `firstsession`) and
  renders correctly. The after-frames in §2 came from it.
- **No test registered** in `all_test_files.txt` — tests are QA's.

---

## 8. Hand-off to QA

The EYES walker used for all of this is **not committed** — `tool_*.gd` is QA's
territory, so I used it and removed it. It is worth adopting. It stages a town
with all four spatial rules live and shoots 17 frames: aura edge, aura source,
aura mid-reach, blessed cottages, both district boundaries, an unbuilt plot, a
claimed plot, a live chain, a dead chain, the muster ground, three daylight
repeats, and the **empty-town control**. It found every defect in §6.

A second probe (`tool_eyes_sky.gd`) prints sun/moon screen coordinates per hour
per location and is what produced the table in §5. It would make a good
regression guard if the sky is ever fixed.

Both are in this session's scratchpad; the lead has the paths.

---

## 9. What I cannot tell you

Whether any of this is *good*. It reads correctly on rendered frames at midnight
and at noon, and the empty village comes back bare. Whether the town now feels
like a place rather than a spreadsheet is the dev's call, and that pass does not
delegate.
