# THE CROWN TEN — build specs for #7-#10
Written while three other sessions hold the machine, so the remaining four
can be implemented mechanically (and verified in one burst) later.
Each spec is complete enough to build from without re-deriving anything.

Status of the ten:
1. The Whole Court, Spinning — BUILT + FILMED (8b264a2)
2. The Final Edict — BUILT + FILMED (affefc5)
3. A Small Personal Sun — BUILT + FILMED (c2f1043)
4. Regicide — BUILT + FILMED (4f7927a)
5. Throne of Embers — BUILT + FILMED (98bc994)
6. The Crown's Sorrow — CODE COMPLETE, EYES PENDING (417e98d)
7. Grief Wears a Crown — spec below
8. The Hollow King's Rain — spec below
9. Night Parade — spec below
10. The Mountain That Kneels — spec below

---

## #7 — GRIEF WEARS A CROWN  (melee, currently `cleave` shared with 14)
**Source:** Golem Fist. Measured: launch ~23 PH/s over 9.5 PH (the fastest
thing in the whole melee study); impacts past ~9.4 tiles detonate a
through-wall shockwave ~12.5 tiles wide, KB 12 ("Insane").

**Verb:** a slow, heavy swing whose impact sends a shockwave THROUGH terrain
for ~12 PH. The joy is hitting the wall beside them and killing them anyway.

**Build:**
- roster behavior `"sunder"` → `{"type": "sunder_wave", "damage": dmg,
  "range": 520.0}`
- new projectile kind `sunder_wave`: does NOT collide (monitoring off, like
  `edict_lash`); expands a horizontal band outward from the impact point at
  ~1400 px/s to max range, damaging each body ONCE as the front passes it
  (track hit ids; distance-from-origin test each tick).
- visual: a low crescent of displaced dust/force, widening and fading as it
  travels — additive amber over a solid dark core so it reads against rock.
- numbers: damage ~34, cooldown ~1.1 (heavy). dps audit: declare
  `"sunder": 1.0` (one pass, one hit per body).
- fx: keep ONE (`quake` suits it) — currently wears three.

**Watch for:** the wave must not stop at the first body (it is a wave, not a
projectile) and must visibly pass THROUGH terrain — that is the whole verb.

---

## #8 — THE HOLLOW KING'S RAIN  (bow, currently `lob_a`)
**Source:** Daedalus Stormbow. Measured: nothing leaves the bow; arrows
spawn ABOVE the camera with ±1.5 PH x-jitter and 8-15° tilt, crossing the
full screen in 0.4-0.5s. Its balance dial is literally "does it respect
roofs" (useless indoors).

**Verb:** the king's arrows fall from the sky onto the aim point. Firing at
a wall does nothing; firing under open sky is devastating.

**Build:**
- roster behavior `"skyfall_rain"` → `{"type": "king_rain", "damage": dmg,
  "count": 3, "range": rng}`
- player-side (like `unleash_court`): spawn N arrows per shot at
  `aim_point + Vector2(randf_range(-72,72), -560)`, direction aimed down at
  8-15° off vertical toward the aim point, speed ~1150.
- REUSE the existing `skyrain` fx comet visuals if they read well; otherwise
  a simple fletched shaft with a short trail.
- ROOF RULE (the balance dial, must be implemented): before spawning, raycast
  UP from the aim point ~560px on collision_mask 1. If it hits, the volley is
  halved and a small "the ceiling holds" puff plays. Do not silently no-op —
  the player must SEE why it did nothing.
- numbers: damage ~16 x3 arrows, cooldown ~0.62. dps audit: declare
  `"skyfall_rain": 2.0` (3 arrows, ~2 land on one body).

---

## #9 — NIGHT PARADE  (bow, currently `seeker`)
**Source:** The Horseman's Blade. Measured: every struck enemy summons a
flaming head that spawns OFF-SCREEN and dives in at ~41 mph through blocks,
retargeting within 62.5 tiles if its mark dies.

**Verb:** every arrow that lands calls one marcher of the parade — a
spectral figure that walks in from off-screen, through terrain, and strikes
the same foe. Sustained fire turns a crowd into a procession.

**Build:**
- roster behavior `"parade"` → ordinary arrow special + `{"parade": true}`
- hook: `player.on_projectile_hit` (already exists and already routes arrow
  hits) — on a parade weapon, spawn one marcher per landed arrow, capped at
  ~6 alive (cap matters: rapid bows would otherwise flood).
- marcher: reuse `companion.gd`'s chassis? NO — it is transient. Make it a
  projectile kind `marcher`: spawns at `victim.x ± 700` (off the camera
  edge, alternating side), walks/floats horizontally at ~420 px/s ignoring
  terrain, strikes its mark, then fades. Retarget on the way if the mark dies.
- visual: a hooded lantern-bearing shade (reuse the courtier cloak shapes in
  a colder palette) with a small bobbing lantern glow — the parade reads as
  PEOPLE, tying it to the rescue story like the Court does.
- numbers: damage ~14 (arrow), marcher ~60% of it, cooldown ~0.5. dps audit:
  declare `"parade": 1.8`.

---

## #10 — THE MOUNTAIN THAT KNEELS  (staff, currently `staff` shared with 20)
**Source:** Staff of Earth. Measured: boulder ticks 110-140 while slow vs
244-280 at speed — roll-speed damage scaling is visible in the numbers.

**Verb:** summons a boulder that rolls, bounces, and deals damage scaled to
its own current speed. Terrain slope becomes a damage multiplier, which
suits a side-scroller better than it suits Terraria.

**Build:**
- roster behavior `"boulder"` → `{"type": "kneeling_stone", "damage": dmg,
  "range": 900.0}`
- new projectile kind `kneeling_stone`: real gravity (`_vel_y += 1500*dt`),
  horizontal roll, floor raycast each tick to sit on ground and follow
  slopes; bounces off walls with damping; despawns after ~6s or max distance.
- DAMAGE SCALES WITH SPEED: `dealt = damage * clamp(speed/720, 0.35, 1.6)`.
  Show it — the numbers climbing as it gathers pace IS the weapon (number
  theater, per DESIGN_LAWS §7).
- visual: a rough polygon boulder that ROTATES with travel (rotation +=
  speed/radius * dt) so the roll is legible; dust puffs on each ground
  contact.
- numbers: damage ~30 base, cooldown ~1.3. dps audit: declare
  `"boulder": 1.6` (it rolls through several bodies).

---

## VERIFICATION BURST (when the machine frees)
1. `tool_eyes_crown.gd` — extend with shots for #6-#10 (it already films 1-5).
   Every weapon so far had a bug ONLY the film caught; assume these do too.
2. `test_weaponfx_node` (signatures + cards), `test_weapondps_node` (the new
   effective-dps bands), `test_melee_node`, `test_items_node`.
3. The FULL suite, single-threaded, nothing else running.
4. Clean-clone verify — the working tree lies.
